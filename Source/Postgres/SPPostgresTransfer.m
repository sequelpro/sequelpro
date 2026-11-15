#import "SPPostgresTransfer.h"
#import "SPPostgresDumpWriter.h"
#import "SPPostgresDumpObject.h"
#import "SPPostgresDumpReader.h"
#import "SPPostgresSQLImporter.h"
#import "SPPostgresTableData.h"
#import "SPPostgresErrors.h"
#import <PostgresKit/PostgresKit.h>

/// The value as an NSString, or nil for NULL.
static NSString *SPTransferText(id value)
{
	return [value isKindOfClass:[NSString class]] ? value : nil;
}

/// "schema"."name"
static NSString *SPTransferQualified(SPPostgresDumpObject *object)
{
	return [NSString stringWithFormat:@"%@.%@", SPPostgresQuoteIdentifier([object schema] ?: @""), SPPostgresQuoteIdentifier([object name] ?: @"")];
}

/// A JSON array literal, for a $n parameter read with json_array_elements.
static NSString *SPTransferJSON(NSArray *array)
{
	NSData *data = [NSJSONSerialization dataWithJSONObject:array ?: @[] options:0 error:NULL];
	return data ? [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease] : @"[]";
}

/// The table a `COPY "s"."t" (columns) FROM stdin` statement loads: "s"."t".
static NSString *SPTransferTableOfCopy(NSString *sql)
{
	NSString *summary = [SPPostgresTransfer summaryOfStatement:sql];
	if ([summary hasPrefix:@"COPY "]) summary = [summary substringFromIndex:5];
	NSRange from = [summary rangeOfString:@" FROM stdin" options:NSCaseInsensitiveSearch | NSBackwardsSearch];
	if (from.location != NSNotFound) summary = [summary substringToIndex:from.location];
	return summary;
}

@interface SPPostgresTransfer ()

- (BOOL)_runWithPath:(NSString *)path error:(NSError **)error;

@end

@implementation SPPostgresTransfer

@synthesize wholeDatabase;
@synthesize tables;
@synthesize mode;
@synthesize temporaryDirectory;
@synthesize progress;
@synthesize tablesCopied;
@synthesize replacedObjects;
@synthesize dependenciesCreated;
@synthesize foreignTablesSkipped;
@synthesize skippedSettings;
@synthesize readingTableIndex;
@synthesize readingTableCount;
@synthesize objectCount;
@synthesize readTableCount;
@synthesize readRowCount;
@synthesize emptiedSchemas;
@synthesize emptiedExtensions;
@synthesize objectsToReplace;
@synthesize structureItemCount;
@synthesize postDataItemCount;
@synthesize loadStepIndex;
@synthesize loadStepCount;
@synthesize loadRowsWritten;
@synthesize loadTableRowsWritten;
@synthesize loadTableRowCount;
@synthesize loadingTableRows;
@synthesize loadTableRowCountKnown;
@synthesize failedWhileReading;

+ (NSString *)summaryOfStatement:(NSString *)sql
{
	NSMutableArray *words = [NSMutableArray array];
	for (NSString *word in [sql ?: @"" componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]) {
		if ([word length]) [words addObject:word];
	}
	NSString *line = [words componentsJoinedByString:@" "];
	NSUInteger cut = [line length];
	NSRange paren = [line rangeOfString:@"("];
	if (paren.location != NSNotFound) cut = MIN(cut, paren.location);
	NSRange as = [line rangeOfString:@" AS " options:NSCaseInsensitiveSearch];
	if (as.location != NSNotFound) cut = MIN(cut, as.location);
	line = [[line substringToIndex:cut] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if ([line length] > 100) line = [[line substringToIndex:99] stringByAppendingString:@"…"];
	return line;
}

- (instancetype)initWithSource:(PGPostgresConnection *)theSource target:(PGPostgresConnection *)theTarget
{
	if ((self = [super init])) {
		source = [theSource retain];
		target = [theTarget retain];
		mode = SPPostgresTransferEmptyTarget;
		temporaryDirectory = [NSTemporaryDirectory() copy];
	}
	return self;
}

- (void)dealloc
{
	[source release];
	[target release];
	[tables release];
	[temporaryDirectory release];
	[progress release];
	[replacedObjects release];
	[dependenciesCreated release];
	[foreignTablesSkipped release];
	[skippedSettings release];
	[emptiedSchemas release];
	[emptiedExtensions release];
	[objectsToReplace release];
	[super dealloc];
}

#pragma mark - Statements

+ (NSArray *)emptyingStatementsForSchemas:(NSArray *)schemas extensions:(NSArray *)extensions serverVersion:(NSInteger)versionNumber
{
	NSMutableArray *statements = [NSMutableArray array];
	// CASCADE here and only here: the user typed the database's name to empty it, and it all runs in the load's
	// transaction (see the Stage 7 decisions)
	if ([extensions count]) {
		NSMutableArray *quoted = [NSMutableArray array];
		for (NSString *name in extensions) [quoted addObject:SPPostgresQuoteIdentifier(name)];
		[statements addObject:[NSString stringWithFormat:@"DROP EXTENSION IF EXISTS %@ CASCADE", [quoted componentsJoinedByString:@", "]]];
	}
	if ([schemas count]) {
		NSMutableArray *quoted = [NSMutableArray array];
		for (NSString *name in schemas) [quoted addObject:SPPostgresQuoteIdentifier(name)];
		[statements addObject:[NSString stringWithFormat:@"DROP SCHEMA IF EXISTS %@ CASCADE", [quoted componentsJoinedByString:@", "]]];
	}
	// public, as a fresh database of this version has it
	[statements addObject:@"CREATE SCHEMA public"];
	if (versionNumber >= 150000) {
		[statements addObject:@"ALTER SCHEMA public OWNER TO pg_database_owner"];
		[statements addObject:@"GRANT USAGE ON SCHEMA public TO PUBLIC"];
	}
	else {
		[statements addObject:@"GRANT CREATE, USAGE ON SCHEMA public TO PUBLIC"];
	}
	[statements addObject:[NSString stringWithFormat:@"COMMENT ON SCHEMA public IS %@", SPPostgresQuoteLiteral(@"standard public schema")]];
	return statements;
}

/// The kinds Overwrite drops, in drop order, with their DROP words.
static NSArray *SPTransferDropOrder(void)
{
	return @[@[SPPostgresDumpObjectMaterializedView, @"MATERIALIZED VIEW"], @[SPPostgresDumpObjectView, @"VIEW"],
			 @[SPPostgresDumpObjectForeignTable, @"FOREIGN TABLE"], @[SPPostgresDumpObjectTable, @"TABLE"],
			 @[SPPostgresDumpObjectSequence, @"SEQUENCE"], @[SPPostgresDumpObjectRoutine, @"ROUTINE"],
			 @[SPPostgresDumpObjectDomain, @"DOMAIN"], @[SPPostgresDumpObjectType, @"TYPE"]];
}

/// The objects of the kinds Overwrite drops, in drop order (each kind in the given order); others left out.
static NSArray *SPTransferInDropOrder(NSArray *objects)
{
	NSMutableArray *ordered = [NSMutableArray arrayWithCapacity:[objects count]];
	for (NSArray *kind in SPTransferDropOrder()) {
		for (SPPostgresDumpObject *object in objects) if ([[object kind] isEqualToString:kind[0]]) [ordered addObject:object];
	}
	return ordered;
}

+ (NSArray *)dropStatementsForObjects:(NSArray *)targetObjects
{
	NSArray *order = SPTransferDropOrder();
	NSMutableArray *statements = [NSMutableArray array];
	for (NSArray *kind in order) {
		// One statement per kind (RESTRICT): foreign keys and partitions among the objects don't get in the way
		NSMutableArray *names = [NSMutableArray array];
		for (SPPostgresDumpObject *object in targetObjects) {
			if (![[object kind] isEqualToString:kind[0]]) continue;
			NSString *name = SPTransferQualified(object);
			if ([kind[0] isEqualToString:SPPostgresDumpObjectRoutine]) name = [name stringByAppendingFormat:@"(%@)", [object arguments] ?: @""];
			[names addObject:name];
		}
		if ([names count]) [statements addObject:[NSString stringWithFormat:@"DROP %@ IF EXISTS %@", kind[1], [names componentsJoinedByString:@", "]]];
	}
	return statements;
}

#pragma mark - Helpers

/// Every row as arrays of NSString / NSNull, or nil on failure.
static NSArray *SPTransferRows(PGPostgresConnection *connection, NSString *sql, NSArray *values, NSError **error)
{
	PGPostgresResult *result = SPPostgresExecuteWithDetails(connection, sql, values, error);
	if (!result) return nil;
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:(NSUInteger)[result numberOfRows]];
	for (unsigned long long row = 0; row < [result numberOfRows]; row++) {
		NSMutableArray *fields = [NSMutableArray arrayWithCapacity:[result numberOfFields]];
		for (NSUInteger column = 0; column < [result numberOfFields]; column++) {
			id value = [result textValueAtRow:row column:column];
			[fields addObject:[value isKindOfClass:[NSString class]] ? value : [NSNull null]];
		}
		[rows addObject:fields];
	}
	return rows;
}

static void SPTransferRollBack(PGPostgresConnection *connection)
{
	// A late cancel may hit the first ROLLBACK; a second one covers it
	for (NSUInteger attempt = 0; attempt < 2 && [connection transactionStatus] != PGPostgresTransactionIdle; attempt++) {
		SPPostgresExecute(connection, @"ROLLBACK", nil, NULL);
	}
}

/// Reports come from the load and from the writer's thread: one at a time.
- (BOOL)_report:(SPPostgresTransferPhase)phase fraction:(double)fraction detail:(NSString *)detail
{
	@synchronized (self) {
		return !progress || progress(phase, MAX(0.0, MIN(1.0, fraction)), detail);
	}
}

- (NSError *)_cancelledError
{
	return SPPostgresMakeError(SPPostgresErrorCancelled, NSLocalizedString(@"The transfer was cancelled.", @"Postgres transfer: cancelled"), nil);
}

/// The writer's or importer's error, a cancel reported as the transfer's.
- (NSError *)_passedOn:(NSError *)error
{
	if ([[error domain] isEqualToString:SPPostgresErrorDomain] && [error code] == SPPostgresErrorCancelled) return [self _cancelledError];
	return error;
}

/// @[system identifier, postmaster start time, database] of the connection's database, or nil when the identifier
/// can't be read. The start time tells a physical clone (pg_basebackup, a promoted standby), which shares the system
/// identifier, from the cluster it was copied from: equal only within one running server.
- (NSArray *)_identityOf:(PGPostgresConnection *)connection
{
	NSArray *rows = SPTransferRows(connection, @"SELECT (SELECT s.system_identifier::text FROM pg_catalog.pg_control_system() s),"
								   " (EXTRACT(EPOCH FROM pg_catalog.pg_postmaster_start_time()) * 1000000)::bigint::text, pg_catalog.current_database()::text", nil, NULL);
	if ([connection transactionStatus] != PGPostgresTransactionIdle) SPTransferRollBack(connection);
	if ([rows count] != 1 || !SPTransferText(rows[0][0]) || !SPTransferText(rows[0][1]) || !SPTransferText(rows[0][2])) return nil;
	return rows[0];
}

- (NSArray *)availableExtensionsOnTarget:(NSError **)error
{
	NSArray *rows = SPTransferRows(target, @"SELECT name::text FROM pg_catalog.pg_available_extensions ORDER BY 1", nil, error);
	if (!rows) return nil;
	NSMutableArray *names = [NSMutableArray arrayWithCapacity:[rows count]];
	for (NSArray *row in rows) if (SPTransferText(row[0])) [names addObject:row[0]];
	return names;
}

/**
 * The copy's objects that exist on the target, mapped to the target's object (with the target's kind): relations by
 * schema and name (any relkind but index, TOAST and composite type), types and domains by schema and name (enum,
 * range, domain, standalone composite), routines also by identity arguments, extensions by name. Read in a READ ONLY
 * transaction of its own with an empty search_path (the arguments then read as the writer's do).
 */
- (NSDictionary *)_objectsOnTarget:(NSArray *)objects error:(NSError **)error
{
	NSArray *relationKinds = @[SPPostgresDumpObjectTable, SPPostgresDumpObjectView, SPPostgresDumpObjectMaterializedView, SPPostgresDumpObjectSequence, SPPostgresDumpObjectForeignTable];
	NSArray *typeKinds = @[SPPostgresDumpObjectType, SPPostgresDumpObjectDomain];
	NSMutableArray *relations = [NSMutableArray array], *types = [NSMutableArray array], *routines = [NSMutableArray array], *extensions = [NSMutableArray array];
	for (SPPostgresDumpObject *object in objects) {
		if ([relationKinds containsObject:[object kind]]) [relations addObject:object];
		else if ([typeKinds containsObject:[object kind]]) [types addObject:object];
		else if ([[object kind] isEqualToString:SPPostgresDumpObjectRoutine]) [routines addObject:object];
		else if ([[object kind] isEqualToString:SPPostgresDumpObjectExtension]) [extensions addObject:object];
	}

	static NSString *const elements = @"pg_catalog.json_array_elements($1::json) WITH ORDINALITY AS o(e, i)";
	static NSString *const inSchema = @" JOIN pg_catalog.pg_namespace n ON n.nspname = (o.e->>1)::name";
	NSArray *queries = @[
		@[relations, [NSString stringWithFormat:@"SELECT o.i::text, c.relkind::text FROM %@%@"
					  " JOIN pg_catalog.pg_class c ON c.relnamespace = n.oid AND c.relname = (o.e->>2)::name"
					  " WHERE c.relkind NOT IN ('i', 'I', 't', 'c')", elements, inSchema]],
		@[types, [NSString stringWithFormat:@"SELECT o.i::text, t.typtype::text FROM %@%@"
				  " JOIN pg_catalog.pg_type t ON t.typnamespace = n.oid AND t.typname = (o.e->>2)::name"
				  " WHERE t.typtype IN ('e', 'r', 'd') OR (t.typtype = 'c' AND EXISTS (SELECT 1 FROM pg_catalog.pg_class r"
				  " WHERE r.oid = t.typrelid AND r.relkind = 'c'))", elements, inSchema]],
		@[routines, [NSString stringWithFormat:@"SELECT o.i::text, NULL::text FROM %@%@"
					 " JOIN pg_catalog.pg_proc p ON p.pronamespace = n.oid AND p.proname = (o.e->>2)::name"
					 " WHERE p.prokind IN ('f', 'p') AND pg_catalog.pg_get_function_identity_arguments(p.oid) = (o.e->>3)", elements, inSchema]],
		@[extensions, [NSString stringWithFormat:@"SELECT o.i::text, n.nspname::text FROM %@"
					   " JOIN pg_catalog.pg_extension x ON x.extname = (o.e->>2)::name"
					   " JOIN pg_catalog.pg_namespace n ON n.oid = x.extnamespace", elements]],
	];
	NSDictionary *relationKindsByRelkind = @{@"r": SPPostgresDumpObjectTable, @"p": SPPostgresDumpObjectTable, @"v": SPPostgresDumpObjectView,
											 @"m": SPPostgresDumpObjectMaterializedView, @"S": SPPostgresDumpObjectSequence, @"f": SPPostgresDumpObjectForeignTable};

	NSMutableDictionary *existing = [NSMutableDictionary dictionary];
	NSError *failure = nil;
	BOOL read = SPPostgresExecute(target, @"BEGIN READ ONLY", nil, &failure)
		&& SPTransferRows(target, @"SELECT pg_catalog.set_config('search_path', '', true)", nil, &failure);
	for (NSArray *query in queries) {
		if (!read) break;
		NSArray *group = query[0];
		if (![group count]) continue;
		NSMutableArray *json = [NSMutableArray arrayWithCapacity:[group count]];
		for (SPPostgresDumpObject *object in group) [json addObject:@[[object kind], [object schema] ?: @"", [object name] ?: @"", [object arguments] ?: @""]];
		NSArray *rows = SPTransferRows(target, query[1], @[SPTransferJSON(json)], &failure);
		if (!rows) { read = NO; break; }
		for (NSArray *row in rows) {
			NSUInteger index = (NSUInteger)[SPTransferText(row[0]) integerValue];
			if (index < 1 || index > [group count]) continue;
			SPPostgresDumpObject *object = group[index - 1];
			NSString *kind = [object kind], *schema = [object schema];
			if (group == relations) kind = relationKindsByRelkind[SPTransferText(row[1]) ?: @""] ?: kind;
			else if (group == types) kind = [SPTransferText(row[1]) isEqualToString:@"d"] ? SPPostgresDumpObjectDomain : SPPostgresDumpObjectType;
			else if (group == extensions) schema = SPTransferText(row[1]) ?: schema;
			existing[object] = [SPPostgresDumpObject objectWithKind:kind schema:schema name:[object name] arguments:[object arguments]];
		}
	}
	SPTransferRollBack(target);
	if (!read) {
		if (error) *error = failure;
		return nil;
	}
	return existing;
}

/// Overwrite's dry run: BEGIN, the drops, ROLLBACK (also after a failure). A refused drop (2BP01) is
/// SPPostgresErrorHasDependents with the server's DETAIL lines.
- (BOOL)_dryRun:(NSArray *)drops error:(NSError **)error
{
	NSError *failure = nil;
	BOOL dropped = SPPostgresExecute(target, @"BEGIN", nil, &failure)
		// Fully qualified names in the server's DETAIL
		&& SPTransferRows(target, @"SELECT pg_catalog.set_config('search_path', '', true)", nil, &failure);
	for (NSString *sql in drops) {
		if (!dropped) break;
		dropped = SPPostgresExecuteWithDetails(target, sql, nil, &failure) != nil;
	}
	if (!dropped && [[failure userInfo][SPPostgresSQLStateErrorKey] isEqualToString:@"2BP01"]) {
		// Reads the DETAIL before the ROLLBACK
		failure = SPPostgresDependentsError(target, failure,
			NSLocalizedString(@"Objects on the target that the transfer doesn't replace depend on objects it would replace.", @"Postgres transfer: overwrite blocked by dependents"));
	}
	SPTransferRollBack(target);
	if (!dropped && ![self _report:SPPostgresTransferChecking fraction:0 detail:nil]) failure = [self _cancelledError];
	if (!dropped && error) *error = failure;
	return dropped;
}

/// Empty mode's statements, from the target's catalog.
- (NSArray *)_emptyingStatements:(NSError **)error
{
	NSArray *extensionRows = SPTransferRows(target, @"SELECT extname::text FROM pg_catalog.pg_extension WHERE extname <> 'plpgsql' ORDER BY 1", nil, error);
	if (!extensionRows) return nil;
	NSArray *schemaRows = SPTransferRows(target, @"SELECT nspname::text FROM pg_catalog.pg_namespace"
										 " WHERE nspname NOT LIKE 'pg\\_%' AND nspname <> 'information_schema' ORDER BY 1", nil, error);
	if (!schemaRows) return nil;
	NSMutableArray *extensions = [NSMutableArray array], *schemas = [NSMutableArray array];
	for (NSArray *row in extensionRows) if (SPTransferText(row[0])) [extensions addObject:row[0]];
	for (NSArray *row in schemaRows) if (SPTransferText(row[0])) [schemas addObject:row[0]];
	[emptiedSchemas release];
	emptiedSchemas = [schemas copy];
	[emptiedExtensions release];
	emptiedExtensions = [extensions copy];
	return [[self class] emptyingStatementsForSchemas:schemas extensions:extensions serverVersion:(NSInteger)[target serverVersion]];
}

/// The partitioned tables among the copy's tables (on the source): they get no COPY block.
- (NSUInteger)_partitionedTablesAmong:(NSArray *)objects error:(NSError **)error
{
	NSMutableArray *json = [NSMutableArray array];
	for (SPPostgresDumpObject *object in objects) {
		if ([[object kind] isEqualToString:SPPostgresDumpObjectTable]) [json addObject:@[[object schema] ?: @"", [object name] ?: @""]];
	}
	if (![json count]) return 0;
	NSArray *rows = SPTransferRows(source, @"SELECT count(*)::text FROM pg_catalog.json_array_elements($1::json) e"
								   " JOIN pg_catalog.pg_namespace n ON n.nspname = (e->>0)::name"
								   " JOIN pg_catalog.pg_class c ON c.relnamespace = n.oid AND c.relname = (e->>1)::name WHERE c.relkind = 'p'",
								   @[SPTransferJSON(json)], error);
	if (!rows) return NSNotFound;
	return (NSUInteger)[SPTransferText(rows[0][0]) integerValue];
}

#pragma mark - Running

- (BOOL)run:(NSError **)error
{
	tablesCopied = 0;
	readingTableIndex = 0;
	readingTableCount = 0;
	[replacedObjects release];
	replacedObjects = nil;
	[dependenciesCreated release];
	dependenciesCreated = nil;
	[foreignTablesSkipped release];
	foreignTablesSkipped = nil;
	[skippedSettings release];
	skippedSettings = nil;
	objectCount = readTableCount = structureItemCount = postDataItemCount = loadStepIndex = loadStepCount = 0;
	readRowCount = loadRowsWritten = loadTableRowsWritten = loadTableRowCount = 0;
	loadingTableRows = loadTableRowCountKnown = failedWhileReading = NO;
	[emptiedSchemas release];
	emptiedSchemas = nil;
	[emptiedExtensions release];
	emptiedExtensions = nil;
	[objectsToReplace release];
	objectsToReplace = nil;

	NSString *directory = [temporaryDirectory length] ? temporaryDirectory : NSTemporaryDirectory();
	NSString *path = [[directory stringByAppendingPathComponent:[NSString stringWithFormat:@"sequel-pro-transfer-%@.sql", [[NSUUID UUID] UUIDString]]] retain];

	NSError *failure = nil;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	BOOL transferred = [self _runWithPath:path error:&failure];
	[failure retain];
	// Deleted on every path (the writer deletes its own file on failure; the load leaves it)
	[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
	[pool drain];
	[failure autorelease];
	[path release];

	if (!transferred && error) *error = failure ?: SPPostgresMakeError(SPPostgresErrorQueryFailed, NSLocalizedString(@"The transfer failed.", @"Postgres transfer: unknown failure"), nil);
	return transferred;
}

- (BOOL)_runWithPath:(NSString *)path error:(NSError **)error
{
	if (![self _report:SPPostgresTransferChecking fraction:0 detail:nil]) {
		if (error) *error = [self _cancelledError];
		return NO;
	}

	// Settings and connections
	if (wholeDatabase == (tables != nil) || (tables && ![tables count])) {
		if (error) *error = SPPostgresMakeError(SPPostgresErrorInvalidSettings, NSLocalizedString(@"Choose what to transfer: the whole database or some tables.", @"Postgres transfer: no single scope"), nil);
		return NO;
	}
	if ([source transactionStatus] != PGPostgresTransactionIdle || [target transactionStatus] != PGPostgresTransactionIdle) {
		if (error) *error = SPPostgresMakeError(SPPostgresErrorInvalidSettings, NSLocalizedString(@"The transfer needs connections with no transaction open.", @"Postgres transfer: connection busy"), nil);
		return NO;
	}

	// Same database of the same running cluster (skipped when either identifier can't be read)
	NSArray *sourceIdentity = [self _identityOf:source];
	NSArray *targetIdentity = [self _identityOf:target];
	if (sourceIdentity && targetIdentity && [sourceIdentity isEqualToArray:targetIdentity]) {
		if (error) *error = SPPostgresMakeError(SPPostgresErrorTransferRefused, NSLocalizedString(@"The target is the database being copied.", @"Postgres transfer: source and target are the same database"), nil);
		return NO;
	}

	// The copy's objects and dependencies
	SPPostgresDumpWriter *writer = [[[SPPostgresDumpWriter alloc] initWithConnection:source] autorelease];
	if (wholeDatabase) [writer setWholeDatabase:YES];
	else {
		[writer setTables:tables];
		[writer setIncludeDependencies:YES];
	}
	NSArray *objects = [writer objectsInScope:error];
	if (!objects) return NO;
	NSArray *dependencies = [writer dependenciesInScope:error];
	if (!dependencies) return NO;
	NSUInteger partitioned = [self _partitionedTablesAmong:objects error:error];
	if (partitioned == NSNotFound) return NO;
	objectCount = [objects count];

	if (![self _report:SPPostgresTransferChecking fraction:0 detail:nil]) {
		if (error) *error = [self _cancelledError];
		return NO;
	}

	// Every extension the copy creates must be installed on the target or available there
	NSArray *available = [self availableExtensionsOnTarget:error];
	if (!available) return NO;
	NSMutableArray *missing = [NSMutableArray array];
	for (SPPostgresDumpObject *object in objects) {
		if ([[object kind] isEqualToString:SPPostgresDumpObjectExtension] && ![available containsObject:[object name]]) [missing addObject:[object name]];
	}
	if ([missing count]) {
		NSString *message = [NSString stringWithFormat:NSLocalizedString(@"The target can't create the extensions the copy needs: %@.", @"Postgres transfer: extensions missing on the target"), [missing componentsJoinedByString:@", "]];
		if (error) *error = SPPostgresMakeError(SPPostgresErrorTransferRefused, message, @{SPPostgresObjectsErrorKey: missing});
		return NO;
	}

	// Overwrite: what already exists on the target. Dependencies there are used as they are (same kind); the copy's
	// other objects there are replaced (dropped by the target's kind)
	NSMutableArray *skipped = [NSMutableArray array];
	NSMutableArray *drops = [NSMutableArray array];
	NSArray *statementsBeforeImport = nil;
	if (mode == SPPostgresTransferOverwrite) {
		NSDictionary *existing = [self _objectsOnTarget:objects error:error];
		if (!existing) return NO;
		for (SPPostgresDumpObject *object in objects) {
			SPPostgresDumpObject *onTarget = existing[object];
			if (!onTarget) continue;
			if ([dependencies containsObject:object]) {
				if ([[onTarget kind] isEqualToString:[object kind]]) [skipped addObject:object];
			}
			else {
				// (an extension is never replaced: the dump creates it IF NOT EXISTS; SPTransferInDropOrder leaves it out)
				[drops addObject:onTarget];
			}
		}
		[drops setArray:SPTransferInDropOrder(drops)];
		statementsBeforeImport = [[self class] dropStatementsForObjects:drops];
		[objectsToReplace release];
		objectsToReplace = [[drops valueForKey:@"displayName"] copy];

		if (![self _report:SPPostgresTransferChecking fraction:0 detail:nil]) {
			if (error) *error = [self _cancelledError];
			return NO;
		}
		// The dry run, before the source is read
		if ([statementsBeforeImport count] && ![self _dryRun:statementsBeforeImport error:error]) return NO;
	}
	NSMutableArray *created = [NSMutableArray array];
	for (SPPostgresDumpObject *object in dependencies) if (![skipped containsObject:object]) [created addObject:[object displayName]];

	// The dump and the load run at once: the source is read into the file on a thread of its own while the load
	// follows the file on this one, each waiting for the other only when it catches up. A transfer then takes about
	// as long as its slower side, not both one after the other.
	[writer setSkippedObjects:skipped];
	[writer setFlushesOften:YES];

	// Empty mode reads what the target holds first
	if (![self _report:SPPostgresTransferWriting fraction:0 detail:nil]) {
		if (error) *error = [self _cancelledError];
		return NO;
	}
	if (mode == SPPostgresTransferEmptyTarget) {
		statementsBeforeImport = [self _emptyingStatements:error];
		if (!statementsBeforeImport) return NO;
	}

	// The file, created empty: the reader opens it now, the writer fills it
	if (![[NSData data] writeToFile:path options:0 error:NULL]) {
		if (error) *error = SPPostgresMakeError(SPPostgresErrorQueryFailed, [NSString stringWithFormat:NSLocalizedString(@"The temporary file “%@” can't be created.", @"Postgres transfer: temporary file not created"), path], nil);
		return NO;
	}
	SPPostgresDumpReader *reader = [[[SPPostgresDumpReader alloc] initWithPath:path error:error] autorelease];
	if (!reader) return NO;

	// The writer's side (its thread sets these, under writerLock)
	NSLock *writerLock = [[[NSLock alloc] init] autorelease];
	__block BOOL writerFinished = NO, writerSucceeded = NO;
	__block NSError *writerError = nil; // retained
	__block volatile BOOL stopWriter = NO;
	__block NSUInteger tableCount = 0;
	[writer setProgress:^BOOL(NSUInteger tableIndex, NSUInteger count, NSString *table) {
		tableCount = count;
		readingTableIndex = tableIndex;
		readingTableCount = count;
		if (stopWriter) return NO;
		return [self _report:SPPostgresTransferReading fraction:count ? (double)(tableIndex - 1) / (double)count : 0 detail:table];
	}];
	dispatch_group_t writing = dispatch_group_create();
	dispatch_group_async(writing, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		// The structure first (Reading with no table yet), then each table's data
		BOOL go = !stopWriter && [self _report:SPPostgresTransferReading fraction:0 detail:nil];
		NSError *failure = go ? nil : [self _cancelledError];
		BOOL ok = go && [writer writeToPath:path error:&failure];
		if (ok) {
			unsigned long long rows = 0;
			NSArray *counts = [writer copyRowCounts];
			for (NSNumber *count in counts) rows += [count unsignedLongLongValue];
			readTableCount = [counts count];
			readRowCount = rows;
		}
		// Reported before the load can see the end of the file (so before it commits)
		if (ok) [self _report:SPPostgresTransferReadingDone fraction:1 detail:nil];
		[writerLock lock];
		writerFinished = YES;
		writerSucceeded = ok;
		writerError = [failure retain];
		[writerLock unlock];
		[pool drain];
	});

	SPPostgresSQLImporter *importer = [[[SPPostgresSQLImporter alloc] initWithConnection:target reader:reader] autorelease];
	[importer setSingleTransaction:YES];
	// The structure's statements go a few hundred per round trip
	[importer setBatchesStatements:YES];
	[importer setStatementsBeforeImport:statementsBeforeImport];

	// Where the load is: each item's part (header, structure, data, structure after the data) as the writer wrote it
	__block SPPostgresTransferPhase phase = SPPostgresTransferEmptying;
	NSMutableString *detail = [NSMutableString string];
	__block NSUInteger itemOrdinal = 0;
	__block NSUInteger copyIndex = 0;
	NSArray *before = statementsBeforeImport ?: @[];
	double (^fraction)(void) = ^double{
		if (phase == SPPostgresTransferLoadingData) {
			[writerLock lock];
			BOOL allRead = writerSucceeded;
			[writerLock unlock];
			if (allRead && readRowCount) return (double)loadRowsWritten / (double)readRowCount;
			double table = (loadTableRowCountKnown && loadTableRowCount) ? (double)loadTableRowsWritten / (double)loadTableRowCount : 0;
			return loadStepCount ? ((double)(loadStepIndex ? loadStepIndex - 1 : 0) + MIN(table, 1.0)) / (double)loadStepCount : 0;
		}
		return loadStepCount ? (double)(loadStepIndex ? loadStepIndex - 1 : 0) / (double)loadStepCount : 0;
	};

	// The load reads what the writer has written; at the end of what is there it waits for more, or for the end
	__block BOOL sawWriterEnd = NO;
	__block CFAbsoluteTime lastPoll = 0;
	[reader setWaitForMoreData:^BOOL(NSError **waitError) {
		[writerLock lock];
		BOOL finished = writerFinished, succeeded = writerSucceeded;
		[writerLock unlock];
		if (finished) {
			if (!succeeded) {
				if (waitError) *waitError = SPPostgresMakeError(SPPostgresErrorQueryFailed, NSLocalizedString(@"Reading the source failed.", @"Postgres transfer: the source's reading failed during the load"), nil);
				return NO;
			}
			// Once more: what was written last
			if (!sawWriterEnd) {
				sawWriterEnd = YES;
				return YES;
			}
			return NO;
		}
		// Waiting for the source: a cancel still gets through
		CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
		if (now - lastPoll > 0.25) {
			lastPoll = now;
			if (![self _report:phase fraction:fraction() detail:[detail length] ? [[detail copy] autorelease] : nil]) {
				stopWriter = YES;
				if (waitError) *waitError = [self _cancelledError];
				return NO;
			}
		}
		usleep(5000);
		return YES;
	}];

	// Reports while a statement runs can't cancel (the next one, right after it, does)
	[importer setStatementBeforeImportObserver:^(NSUInteger index) {
		phase = SPPostgresTransferEmptying;
		loadStepIndex = index + 1;
		loadStepCount = [before count];
		[detail setString:[[self class] summaryOfStatement:before[index]]];
		[self _report:phase fraction:fraction() detail:[[detail copy] autorelease]];
	}];
	[importer setItemObserver:^(SPPostgresDumpItem *item) {
		NSUInteger ordinal = itemOrdinal++;
		NSUInteger part = [writer partOfItemAtOrdinal:ordinal];
		if (part == 0) return; // the session's settings
		loadingTableRows = NO;
		NSUInteger index = ordinal - [writer startOfPart:part];
		BOOL whole = NO;
		NSUInteger count = [writer itemCountOfPart:part known:&whole];
		if (part == 1) {
			phase = SPPostgresTransferCreating;
			loadStepIndex = index + 1;
			loadStepCount = whole ? count : 0;
			if (whole) structureItemCount = count;
			[detail setString:[[self class] summaryOfStatement:[item sql]]];
		}
		else if (part == 2) {
			if (phase != SPPostgresTransferLoadingData) loadStepIndex = 0;
			phase = SPPostgresTransferLoadingData;
			// One COPY block per table but partitioned parents
			loadStepCount = tableCount > partitioned ? tableCount - partitioned : tableCount;
			loadingTableRows = [item kind] == SPPostgresDumpItemCopy;
			if (loadingTableRows) {
				loadStepIndex = ++copyIndex;
				loadTableRowsWritten = 0;
				BOOL rowsKnown = NO;
				loadTableRowCount = [writer rowCountOfCopy:copyIndex - 1 known:&rowsKnown];
				loadTableRowCountKnown = rowsKnown;
				[detail setString:SPTransferTableOfCopy([item sql])];
			}
			else {
				[detail setString:[[self class] summaryOfStatement:[item sql]]];
			}
		}
		else {
			phase = SPPostgresTransferFinishing;
			loadStepIndex = index + 1;
			loadStepCount = whole ? count : 0;
			if (whole) postDataItemCount = count;
			[detail setString:[[self class] summaryOfStatement:[item sql]]];
		}
		[self _report:phase fraction:fraction() detail:[[detail copy] autorelease]];
	}];
	[importer setCopyDataObserver:^(NSData *data) {
		const char *bytes = [data bytes], *end = bytes + [data length];
		unsigned long long rows = 0;
		for (const char *cursor = bytes; cursor < end && (cursor = memchr(cursor, '\n', (size_t)(end - cursor))); cursor++) rows++;
		loadRowsWritten += rows;
		loadTableRowsWritten += rows;
		// The table's whole count, once the writer has finished it
		if (!loadTableRowCountKnown) {
			BOOL rowsKnown = NO;
			unsigned long long tableRows = [writer rowCountOfCopy:copyIndex - 1 known:&rowsKnown];
			if (rowsKnown) {
				loadTableRowCount = tableRows;
				loadTableRowCountKnown = YES;
			}
		}
	}];
	[importer setCommitObserver:^{
		phase = SPPostgresTransferCommitting;
		loadStepIndex = loadStepCount = 0;
		loadingTableRows = NO;
		[detail setString:@""];
		[self _report:phase fraction:0 detail:nil];
	}];
	[importer setProgress:^BOOL(unsigned long long bytesRead, unsigned long long fileSize) {
		BOOL go = [self _report:phase fraction:fraction() detail:[detail length] ? [[detail copy] autorelease] : nil];
		if (!go) stopWriter = YES;
		return go;
	}];
	NSError *loadError = nil;
	BOOL loaded = [importer run:&loadError];
	[loadError retain];

	// Did the source fail first (the load then stopped short)? Then that is the error to show.
	[writerLock lock];
	BOOL readingFailed = writerFinished && !writerSucceeded;
	[writerLock unlock];
	// The writer stops at its next check when the load has failed; then it is waited for
	if (!loaded) stopWriter = YES;
	dispatch_group_wait(writing, DISPATCH_TIME_FOREVER);
	dispatch_release(writing);
	[writer setProgress:nil];
	[reader setWaitForMoreData:nil];
	[importer setProgress:nil];
	[importer setStatementBeforeImportObserver:nil];
	[importer setItemObserver:nil];
	[importer setCopyDataObserver:nil];
	[importer setCommitObserver:nil];
	[writerError autorelease];
	[loadError autorelease];
	structureItemCount = [writer structureItemCount];
	postDataItemCount = [writer postDataItemCount];

	// Committed: nothing is left to cancel
	if (loaded) [self _report:SPPostgresTransferCommitting fraction:1 detail:nil];
	if (!loaded) {
		if ([target transactionStatus] != PGPostgresTransactionIdle) SPTransferRollBack(target);
		BOOL cancelled = [[loadError domain] isEqualToString:SPPostgresErrorDomain] && [loadError code] == SPPostgresErrorCancelled;
		if (readingFailed && writerError && !cancelled) {
			failedWhileReading = YES;
			if (error) *error = [self _passedOn:writerError];
		}
		else if (error) {
			*error = [self _passedOn:loadError];
		}
		return NO;
	}

	// Results: one COPY block per table the dump read, but partitioned parents
	tablesCopied = tableCount > partitioned ? tableCount - partitioned : 0;
	replacedObjects = [[drops valueForKey:@"displayName"] copy];
	dependenciesCreated = [created copy];
	foreignTablesSkipped = [([writer foreignTablesSkipped] ?: @[]) copy];
	skippedSettings = [([importer skippedSettings] ?: @[]) copy];
	return YES;
}

@end
