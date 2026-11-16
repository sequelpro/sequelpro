//
//  SPMySQLTransfer.m
//  Sequel Plus
//

#import "SPMySQLTransfer.h"
#import <SPMySQL/SPMySQL.h>

NSString * const SPMySQLTransferErrorDomain = @"SPMySQLTransferErrorDomain";
NSString * const SPMySQLTransferNotCreatedKey = @"SPMySQLTransferNotCreated";

/// Rows between two progress reports while a table's data is copied
static const unsigned long long SPMySQLTransferRowsPerReport = 2000;

static NSError *SPMySQLTransferError(SPMySQLTransferErrorCode code, NSString *message, NSDictionary *info)
{
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:info ?: @{}];
	userInfo[NSLocalizedDescriptionKey] = message ?: @"";
	return [NSError errorWithDomain:SPMySQLTransferErrorDomain code:code userInfo:userInfo];
}

static NSString *SPQuoted(NSString *name)
{
	return [NSString stringWithFormat:@"`%@`", [name ?: @"" stringByReplacingOccurrencesOfString:@"`" withString:@"``"]];
}

/// The value as an NSString (data decoded as UTF-8), or nil for NULL.
static NSString *SPText(id value)
{
	if ([value isKindOfClass:[NSString class]]) return value;
	if ([value isKindOfClass:[NSData class]]) return [[[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding] autorelease];
	return nil;
}

@interface SPMySQLTransfer ()
{
	SPMySQLConnection *source;
	SPMySQLConnection *target;
	NSString *sourceDatabase;
	NSString *targetDatabase;
	BOOL wholeDatabase;
	NSArray *tables;
	SPMySQLTransferMode mode;
	NSUInteger batchSize;
	BOOL (^progress)(SPMySQLTransferStep, NSString *);

	NSUInteger stepIndex;
	NSUInteger stepCount;
	unsigned long long tableRowsCopied;
	unsigned long long tableRowEstimate;

	NSUInteger tablesCopied;
	unsigned long long rowsCopied;
	NSMutableArray *tablesReplaced;
	NSMutableArray *objectsDropped;
	NSMutableArray *objectsCreated;
	NSMutableArray *objectsNotCreated;

	/// The temporary tables created so far (dropped on a failure before the swap)
	NSMutableArray *temporaryTables;
}
@end

@implementation SPMySQLTransfer

@synthesize wholeDatabase;
@synthesize tables;
@synthesize mode;
@synthesize batchSize;
@synthesize progress;
@synthesize stepIndex;
@synthesize stepCount;
@synthesize tableRowsCopied;
@synthesize tableRowEstimate;
@synthesize tablesCopied;
@synthesize rowsCopied;
@synthesize tablesReplaced;
@synthesize objectsDropped;
@synthesize objectsCreated;
@synthesize objectsNotCreated;

- (instancetype)initWithSource:(SPMySQLConnection *)theSource database:(NSString *)theSourceDatabase
						target:(SPMySQLConnection *)theTarget database:(NSString *)theTargetDatabase
{
	if ((self = [super init])) {
		source = [theSource retain];
		target = [theTarget retain];
		sourceDatabase = [theSourceDatabase copy];
		targetDatabase = [theTargetDatabase copy];
		batchSize = 4 * 1024 * 1024;
		tablesReplaced = [[NSMutableArray alloc] init];
		objectsDropped = [[NSMutableArray alloc] init];
		objectsCreated = [[NSMutableArray alloc] init];
		objectsNotCreated = [[NSMutableArray alloc] init];
		temporaryTables = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[source release];
	[target release];
	[sourceDatabase release];
	[targetDatabase release];
	[tables release];
	[progress release];
	[tablesReplaced release];
	[objectsDropped release];
	[objectsCreated release];
	[objectsNotCreated release];
	[temporaryTables release];
	[super dealloc];
}

#pragma mark - Statements (pure)

+ (NSString *)statementWithoutDefiner:(NSString *)statement
{
	if (!statement) return nil;
	// DEFINER=`user`@`host`, 'user'@'host' or user@host, and the space after it
	NSRegularExpression *definer = [NSRegularExpression regularExpressionWithPattern:
		@"DEFINER\\s*=\\s*(`(?:[^`]|``)*`|'(?:[^']|'')*'|[^\\s@]+)@(`(?:[^`]|``)*`|'(?:[^']|'')*'|[^\\s]+)\\s+"
		options:NSRegularExpressionCaseInsensitive error:NULL];
	NSTextCheckingResult *match = [definer firstMatchInString:statement options:0 range:NSMakeRange(0, [statement length])];
	if (!match) return statement;
	return [statement stringByReplacingCharactersInRange:[match range] withString:@""];
}

+ (NSString *)createStatement:(NSString *)create forTable:(NSString *)name asTemporary:(NSString *)temporaryName addingBack:(NSString **)alter
{
	if (alter) *alter = nil;
	// The name, right after CREATE TABLE
	NSString *quotedName = SPQuoted(name);
	NSRange nameRange = [create rangeOfString:quotedName];
	if (nameRange.location == NSNotFound) return nil;
	NSString *statement = [create stringByReplacingCharactersInRange:nameRange withString:SPQuoted(temporaryName)];

	// One definition per line between the first "(\n" and the line starting with ")": foreign keys and CHECK
	// constraints out (added back after the swap)
	NSMutableArray *lines = [[[statement componentsSeparatedByString:@"\n"] mutableCopy] autorelease];
	NSMutableArray *kept = [NSMutableArray array];
	NSMutableArray *addBack = [NSMutableArray array];
	BOOL inDefinitions = NO;
	NSUInteger lastDefinition = NSNotFound;
	for (NSUInteger i = 0; i < [lines count]; i++) {
		NSString *line = lines[i];
		if (!inDefinitions) {
			[kept addObject:line];
			if ([line hasSuffix:@"("]) inDefinitions = YES;
			continue;
		}
		if ([line hasPrefix:@")"]) {
			inDefinitions = NO;
			[kept addObject:line];
			continue;
		}
		NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		BOOL constraint = [trimmed hasPrefix:@"CONSTRAINT "] && ([trimmed rangeOfString:@" FOREIGN KEY "].location != NSNotFound || [trimmed rangeOfString:@" CHECK ("].location != NSNotFound);
		if (constraint) {
			if ([trimmed hasSuffix:@","]) trimmed = [trimmed substringToIndex:[trimmed length] - 1];
			[addBack addObject:[@"ADD " stringByAppendingString:trimmed]];
			continue;
		}
		[kept addObject:line];
		lastDefinition = [kept count] - 1;
	}
	// The last definition left ends without a comma
	if (lastDefinition != NSNotFound && [kept[lastDefinition] hasSuffix:@","]) {
		kept[lastDefinition] = [kept[lastDefinition] substringToIndex:[kept[lastDefinition] length] - 1];
	}
	if (alter && [addBack count]) *alter = [NSString stringWithFormat:@"ALTER TABLE %@ %@", quotedName, [addBack componentsJoinedByString:@", "]];
	return [kept componentsJoinedByString:@"\n"];
}

#pragma mark - Queries

- (BOOL)_report:(SPMySQLTransferStep)step detail:(NSString *)detail
{
	return !progress || progress(step, detail);
}

- (NSError *)_cancelledError
{
	return SPMySQLTransferError(SPMySQLTransferErrorCancelled, NSLocalizedString(@"The transfer was cancelled.", @"MySQL transfer: cancelled"), nil);
}

/// Rows as arrays (strings, or NSNull), or nil with an error naming which side failed.
- (NSArray *)_rows:(NSString *)sql on:(SPMySQLConnection *)connection error:(NSError **)error
{
	SPMySQLResult *result = [connection queryString:sql];
	if ([connection queryErrored] || !result) {
		if (error) *error = [self _failure:connection statement:sql];
		return nil;
	}
	[result setReturnDataAsStrings:YES];
	NSMutableArray *rows = [NSMutableArray array];
	NSArray *row = nil;
	while ((row = [result getRowAsArray])) [rows addObject:row];
	return rows;
}

- (BOOL)_run:(NSString *)sql on:(SPMySQLConnection *)connection error:(NSError **)error
{
	[connection queryString:sql];
	if (![connection queryErrored]) return YES;
	if (error) *error = [self _failure:connection statement:sql];
	return NO;
}

- (NSError *)_failure:(SPMySQLConnection *)connection statement:(NSString *)sql
{
	NSString *side = (connection == source) ? NSLocalizedString(@"The source", @"MySQL transfer: error side") : NSLocalizedString(@"The target", @"MySQL transfer: error side");
	NSString *message = [connection lastErrorMessage];
	if (![message length]) message = [connection isConnected] ? NSLocalizedString(@"The query failed.", @"MySQL transfer: unknown query failure") : NSLocalizedString(@"The connection was lost.", @"MySQL transfer: connection lost");
	return SPMySQLTransferError(SPMySQLTransferErrorFailed, [NSString stringWithFormat:NSLocalizedString(@"%@ refused a statement: %@", @"MySQL transfer: failure (side, server message)"), side, message],
								@{@"statement": sql ?: @"", @"errorID": @([connection lastErrorID])});
}

#pragma mark - Running

- (BOOL)run:(NSError **)error
{
	tablesCopied = 0;
	rowsCopied = 0;
	[tablesReplaced removeAllObjects];
	[objectsDropped removeAllObjects];
	[objectsCreated removeAllObjects];
	[objectsNotCreated removeAllObjects];
	[temporaryTables removeAllObjects];

	NSError *failure = nil;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	BOOL swapped = NO;
	BOOL ok = [self _runSwapped:&swapped error:&failure];
	[failure retain];
	// Before the swap: the temporary tables go, the target is as it was
	if (!ok && !swapped && [temporaryTables count] && [target isConnected]) {
		NSMutableArray *quoted = [NSMutableArray array];
		for (NSString *name in temporaryTables) [quoted addObject:SPQuoted(name)];
		[target queryString:[NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", [quoted componentsJoinedByString:@", "]]];
	}
	// The source's snapshot ends
	if ([source isConnected]) [source queryString:@"COMMIT"];
	[pool drain];
	[failure autorelease];
	if (!ok && error) *error = failure ?: SPMySQLTransferError(SPMySQLTransferErrorFailed, NSLocalizedString(@"The transfer failed.", @"MySQL transfer: unknown failure"), nil);
	return ok;
}

- (BOOL)_runSwapped:(BOOL *)swapped error:(NSError **)error
{
	// Checking
	stepIndex = stepCount = 0;
	if (![self _report:SPMySQLTransferChecking detail:nil]) { if (error) *error = [self _cancelledError]; return NO; }
	if (!wholeDatabase && ![tables count]) {
		if (error) *error = SPMySQLTransferError(SPMySQLTransferErrorRefused, NSLocalizedString(@"Choose what to transfer: the whole database or some tables.", @"MySQL transfer: no scope"), nil);
		return NO;
	}

	// Sessions: UTF-8 (utf8mb4), timestamps as stored (UTC on both sides); the target loads values as given
	for (SPMySQLConnection *connection in @[source, target]) {
		if (![connection setEncoding:@"utf8mb4"]) [connection setEncoding:@"utf8"];
		if (![self _run:@"SET SESSION time_zone = '+00:00'" on:connection error:error]) return NO;
	}
	if (![self _run:@"SET SESSION FOREIGN_KEY_CHECKS = 0, UNIQUE_CHECKS = 0, SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO'" on:target error:error]) return NO;
	if (![self _run:[NSString stringWithFormat:@"USE %@", SPQuoted(targetDatabase)] on:target error:error]) return NO;

	// Not the same database of the same server
	NSArray *sourceServer = [self _rows:@"SELECT @@server_uuid, @@hostname, @@port" on:source error:error];
	NSArray *targetServer = sourceServer ? [self _rows:@"SELECT @@server_uuid, @@hostname, @@port" on:target error:error] : nil;
	if (!targetServer) return NO;
	if ([sourceServer isEqualToArray:targetServer] && [sourceDatabase isEqualToString:targetDatabase]) {
		if (error) *error = SPMySQLTransferError(SPMySQLTransferErrorRefused, NSLocalizedString(@"The target is the database being copied.", @"MySQL transfer: same database"), nil);
		return NO;
	}

	// The source's tables and views
	NSArray *relationRows = [self _rows:[NSString stringWithFormat:@"SELECT TABLE_NAME, TABLE_TYPE, IFNULL(TABLE_ROWS, 0) FROM information_schema.TABLES WHERE TABLE_SCHEMA = %@ ORDER BY TABLE_NAME", [source escapeAndQuoteString:sourceDatabase]] on:source error:error];
	if (!relationRows) return NO;
	NSMutableArray *copyTables = [NSMutableArray array];
	NSMutableArray *copyViews = [NSMutableArray array];
	NSMutableDictionary *estimates = [NSMutableDictionary dictionary];
	for (NSArray *row in relationRows) {
		NSString *name = SPText(row[0]);
		if (!name) continue;
		BOOL isView = [SPText(row[1]) isEqualToString:@"VIEW"];
		if (!wholeDatabase && (isView || ![tables containsObject:name])) continue;
		if (isView) [copyViews addObject:name];
		else {
			[copyTables addObject:name];
			estimates[name] = @(strtoull([SPText(row[2]) ?: @"0" UTF8String], NULL, 10));
		}
	}
	if (!wholeDatabase) {
		for (NSString *name in tables) {
			if ([copyTables containsObject:name]) continue;
			if (error) *error = SPMySQLTransferError(SPMySQLTransferErrorRefused, [NSString stringWithFormat:NSLocalizedString(@"There is no table “%@” in “%@”.", @"MySQL transfer: missing table (table, database)"), name, sourceDatabase], nil);
			return NO;
		}
	}

	// The target: leftovers of an earlier transfer that stopped (ours: dropped), and what is there
	NSArray *targetRows = [self _rows:[NSString stringWithFormat:@"SELECT TABLE_NAME, TABLE_TYPE FROM information_schema.TABLES WHERE TABLE_SCHEMA = %@", [target escapeAndQuoteString:targetDatabase]] on:target error:error];
	if (!targetRows) return NO;
	NSMutableDictionary *targetRelations = [NSMutableDictionary dictionary];
	NSMutableArray *leftovers = [NSMutableArray array];
	for (NSArray *row in targetRows) {
		NSString *name = SPText(row[0]);
		if (!name) continue;
		if ([name hasPrefix:@"__spn_"] || [name hasPrefix:@"__spo_"]) [leftovers addObject:SPQuoted(name)];
		else targetRelations[name] = [SPText(row[1]) isEqualToString:@"VIEW"] ? @"VIEW" : @"TABLE";
	}
	if ([leftovers count] && ![self _run:[NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", [leftovers componentsJoinedByString:@", "]] on:target error:error]) return NO;

	// Reading, in one snapshot
	stepIndex = 0;
	stepCount = [copyTables count];
	if (![self _report:SPMySQLTransferReading detail:nil]) { if (error) *error = [self _cancelledError]; return NO; }
	if (![self _run:@"SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ" on:source error:error]) return NO;
	if (![self _run:@"START TRANSACTION WITH CONSISTENT SNAPSHOT" on:source error:error]) return NO;
	NSString *qualifier = [SPQuoted(sourceDatabase) stringByAppendingString:@"."];

	NSMutableDictionary *creates = [NSMutableDictionary dictionary];
	for (NSString *name in copyTables) {
		stepIndex++;
		if (![self _report:SPMySQLTransferReading detail:name]) { if (error) *error = [self _cancelledError]; return NO; }
		NSArray *rows = [self _rows:[NSString stringWithFormat:@"SHOW CREATE TABLE %@%@", qualifier, SPQuoted(name)] on:source error:error];
		if (!rows) return NO;
		NSString *create = [rows count] ? SPText(rows[0][1]) : nil;
		if (!create) {
			if (error) *error = SPMySQLTransferError(SPMySQLTransferErrorFailed, [NSString stringWithFormat:NSLocalizedString(@"The definition of “%@” can't be read.", @"MySQL transfer: no CREATE TABLE (table)"), name], nil);
			return NO;
		}
		creates[name] = create;
	}

	// The columns each table's rows are copied into (not generated ones), and which are BIT
	NSArray *columnRows = [self _rows:[NSString stringWithFormat:@"SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = %@ AND EXTRA NOT LIKE '%%GENERATED%%' ORDER BY TABLE_NAME, ORDINAL_POSITION", [source escapeAndQuoteString:sourceDatabase]] on:source error:error];
	if (!columnRows) return NO;
	NSMutableDictionary *columns = [NSMutableDictionary dictionary];
	NSMutableDictionary *bitColumns = [NSMutableDictionary dictionary];
	for (NSArray *row in columnRows) {
		NSString *table = SPText(row[0]), *column = SPText(row[1]);
		if (!table || !column) continue;
		if (!columns[table]) {
			columns[table] = [NSMutableArray array];
			bitColumns[table] = [NSMutableIndexSet indexSet];
		}
		if ([[SPText(row[2]) lowercaseString] isEqualToString:@"bit"]) [bitColumns[table] addIndex:[columns[table] count]];
		[columns[table] addObject:column];
	}

	// Triggers of the copied tables, in their order
	NSArray *triggerRows = [self _rows:[NSString stringWithFormat:@"SELECT TRIGGER_NAME, ACTION_TIMING, EVENT_MANIPULATION, EVENT_OBJECT_TABLE, ACTION_STATEMENT, SQL_MODE FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = %@ ORDER BY EVENT_OBJECT_TABLE, ACTION_TIMING, EVENT_MANIPULATION, ACTION_ORDER", [source escapeAndQuoteString:sourceDatabase]] on:source error:error];
	if (!triggerRows) return NO;
	NSMutableArray *triggers = [NSMutableArray array]; // @[name, statement, sql_mode]
	for (NSArray *row in triggerRows) {
		NSString *table = SPText(row[3]);
		if (![copyTables containsObject:table]) continue;
		NSString *statement = [NSString stringWithFormat:@"CREATE TRIGGER %@ %@ %@ ON %@ FOR EACH ROW %@", SPQuoted(SPText(row[0])), SPText(row[1]), SPText(row[2]), SPQuoted(table), SPText(row[4]) ?: @""];
		[triggers addObject:@[SPText(row[0]) ?: @"", statement, SPText(row[5]) ?: @""]];
	}

	// Views, routines and events (the whole database only)
	NSMutableArray *views = [NSMutableArray array];      // @[name, statement]
	NSMutableArray *routines = [NSMutableArray array];   // @[kind, name, statement, sql_mode]
	if (wholeDatabase) {
		for (NSString *name in copyViews) {
			NSArray *rows = [self _rows:[NSString stringWithFormat:@"SHOW CREATE VIEW %@%@", qualifier, SPQuoted(name)] on:source error:error];
			if (!rows) return NO;
			NSString *create = [rows count] ? SPText(rows[0][1]) : nil;
			if (!create) continue;
			create = [[self class] statementWithoutDefiner:create];
			// Its tables are those of the database it is created in
			create = [create stringByReplacingOccurrencesOfString:qualifier withString:@""];
			if ([create hasPrefix:@"CREATE "]) create = [@"CREATE OR REPLACE " stringByAppendingString:[create substringFromIndex:7]];
			[views addObject:@[name, create]];
		}
		NSArray *routineRows = [self _rows:[NSString stringWithFormat:@"SELECT ROUTINE_TYPE, ROUTINE_NAME FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = %@ ORDER BY ROUTINE_TYPE, ROUTINE_NAME", [source escapeAndQuoteString:sourceDatabase]] on:source error:error];
		if (!routineRows) return NO;
		for (NSArray *row in routineRows) {
			NSString *kind = SPText(row[0]), *name = SPText(row[1]);
			if (!kind || !name) continue;
			NSArray *rows = [self _rows:[NSString stringWithFormat:@"SHOW CREATE %@ %@%@", kind, qualifier, SPQuoted(name)] on:source error:error];
			if (!rows) return NO;
			// Name, sql_mode, Create …, …
			NSString *create = [rows count] ? SPText(rows[0][2]) : nil;
			if (!create) continue;
			[routines addObject:@[kind, name, [[self class] statementWithoutDefiner:create], SPText(rows[0][1]) ?: @""]];
		}
		NSArray *eventRows = [self _rows:[NSString stringWithFormat:@"SELECT EVENT_NAME FROM information_schema.EVENTS WHERE EVENT_SCHEMA = %@ ORDER BY EVENT_NAME", [source escapeAndQuoteString:sourceDatabase]] on:source error:error];
		if (!eventRows) return NO;
		for (NSArray *row in eventRows) {
			NSString *name = SPText(row[0]);
			if (!name) continue;
			NSArray *rows = [self _rows:[NSString stringWithFormat:@"SHOW CREATE EVENT %@%@", qualifier, SPQuoted(name)] on:source error:error];
			if (!rows) return NO;
			// Event, sql_mode, time_zone, Create Event, …
			NSString *create = [rows count] ? SPText(rows[0][3]) : nil;
			if (!create) continue;
			[routines addObject:@[@"EVENT", name, [[self class] statementWithoutDefiner:create], SPText(rows[0][1]) ?: @""]];
		}
	}

	// Creating the tables under temporary names
	NSMutableDictionary *temporaryNames = [NSMutableDictionary dictionary];
	NSMutableArray *addBack = [NSMutableArray array]; // @[table, ALTER TABLE …]
	stepIndex = 0;
	stepCount = [copyTables count];
	for (NSString *name in copyTables) {
		stepIndex++;
		if (![self _report:SPMySQLTransferCreatingTables detail:name]) { if (error) *error = [self _cancelledError]; return NO; }
		NSString *temporary = [NSString stringWithFormat:@"__spn_%lu", (unsigned long)stepIndex];
		NSString *alter = nil;
		NSString *create = [[self class] createStatement:creates[name] forTable:name asTemporary:temporary addingBack:&alter];
		if (!create) {
			if (error) *error = SPMySQLTransferError(SPMySQLTransferErrorFailed, [NSString stringWithFormat:NSLocalizedString(@"The definition of “%@” can't be read.", @"MySQL transfer: no CREATE TABLE (table)"), name], nil);
			return NO;
		}
		if (![self _run:create on:target error:error]) return NO;
		[temporaryTables addObject:temporary];
		temporaryNames[name] = temporary;
		if (alter) [addBack addObject:@[name, alter]];
	}

	// Copying the data
	stepIndex = 0;
	for (NSString *name in copyTables) {
		stepIndex++;
		tableRowsCopied = 0;
		tableRowEstimate = [estimates[name] unsignedLongLongValue];
		if (![self _report:SPMySQLTransferCopyingData detail:name]) { if (error) *error = [self _cancelledError]; return NO; }
		if (![self _copyRowsOf:name into:temporaryNames[name] columns:columns[name] bits:bitColumns[name] error:error]) return NO;
		tablesCopied++;
	}

	// Swapping: one RENAME TABLE (atomic); the target's replaced tables (and views of a copied table's name) move aside
	stepIndex = stepCount = 0;
	if (![self _report:SPMySQLTransferSwapping detail:nil]) { if (error) *error = [self _cancelledError]; return NO; }
	NSMutableArray *renames = [NSMutableArray array];
	NSMutableArray *oldTables = [NSMutableArray array], *oldViews = [NSMutableArray array];
	NSUInteger oldIndex = 0;
	NSArray *replaced = (mode == SPMySQLTransferEmptyTarget) ? [[targetRelations allKeys] sortedArrayUsingSelector:@selector(compare:)] : copyTables;
	for (NSString *name in replaced) {
		NSString *kind = targetRelations[name];
		if (!kind) continue;
		// Empty mode: views are dropped after the swap (below); one in the way of a table is moved aside now
		if ([kind isEqualToString:@"VIEW"] && ![copyTables containsObject:name]) continue;
		NSString *old = [NSString stringWithFormat:@"__spo_%lu", (unsigned long)++oldIndex];
		[renames addObject:[NSString stringWithFormat:@"%@ TO %@", SPQuoted(name), SPQuoted(old)]];
		if ([kind isEqualToString:@"VIEW"]) [oldViews addObject:old];
		else [oldTables addObject:old];
		[tablesReplaced addObject:name];
	}
	for (NSString *name in copyTables) [renames addObject:[NSString stringWithFormat:@"%@ TO %@", SPQuoted(temporaryNames[name]), SPQuoted(name)]];
	if ([renames count] && ![self _run:[@"RENAME TABLE " stringByAppendingString:[renames componentsJoinedByString:@", "]] on:target error:error]) return NO;
	*swapped = YES;
	[temporaryTables removeAllObjects];

	// The replaced ones go; failures here are listed, not fatal (the copy is in place)
	if ([oldTables count]) {
		NSMutableArray *quoted = [NSMutableArray array];
		for (NSString *old in oldTables) [quoted addObject:SPQuoted(old)];
		NSError *dropError = nil;
		if (![self _run:[NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", [quoted componentsJoinedByString:@", "]] on:target error:&dropError]) {
			[objectsNotCreated addObject:[NSString stringWithFormat:NSLocalizedString(@"replaced tables (left as %@): %@", @"MySQL transfer: old tables not dropped (names, message)"), [quoted componentsJoinedByString:@", "], [dropError localizedDescription]]];
		}
	}
	for (NSString *old in oldViews) [target queryString:[NSString stringWithFormat:@"DROP VIEW IF EXISTS %@", SPQuoted(old)]];

	// Empty mode: everything else in the target goes too
	if (mode == SPMySQLTransferEmptyTarget) {
		for (NSString *name in [[targetRelations allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
			if (![targetRelations[name] isEqualToString:@"VIEW"] || [copyTables containsObject:name]) continue;
			if ([self _run:[NSString stringWithFormat:@"DROP VIEW IF EXISTS %@", SPQuoted(name)] on:target error:NULL]) [objectsDropped addObject:[NSString stringWithFormat:@"view %@", SPQuoted(name)]];
		}
		NSArray *targetRoutines = [self _rows:[NSString stringWithFormat:@"SELECT ROUTINE_TYPE, ROUTINE_NAME FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = %@", [target escapeAndQuoteString:targetDatabase]] on:target error:NULL] ?: @[];
		for (NSArray *row in targetRoutines) {
			NSString *kind = SPText(row[0]), *name = SPText(row[1]);
			if ([self _run:[NSString stringWithFormat:@"DROP %@ IF EXISTS %@", kind, SPQuoted(name)] on:target error:NULL]) [objectsDropped addObject:[NSString stringWithFormat:@"%@ %@", [kind lowercaseString], SPQuoted(name)]];
		}
		NSArray *targetEvents = [self _rows:[NSString stringWithFormat:@"SELECT EVENT_NAME FROM information_schema.EVENTS WHERE EVENT_SCHEMA = %@", [target escapeAndQuoteString:targetDatabase]] on:target error:NULL] ?: @[];
		for (NSArray *row in targetEvents) {
			NSString *name = SPText(row[0]);
			if ([self _run:[NSString stringWithFormat:@"DROP EVENT IF EXISTS %@", SPQuoted(name)] on:target error:NULL]) [objectsDropped addObject:[NSString stringWithFormat:@"event %@", SPQuoted(name)]];
		}
	}

	// Finishing: what couldn't come with the tables
	stepIndex = 0;
	stepCount = [addBack count] + [views count] + [triggers count] + [routines count];
	BOOL cancelled = NO;
	for (NSArray *item in addBack) {
		stepIndex++;
		NSString *what = [NSString stringWithFormat:NSLocalizedString(@"constraints of %@", @"MySQL transfer: foreign keys and checks of a table"), SPQuoted(item[0])];
		if (![self _report:SPMySQLTransferFinishing detail:what]) { cancelled = YES; break; }
		[self _create:item[1] named:what sqlMode:nil];
	}
	// Views: those reading other views wait for them (rounds until no progress)
	NSMutableArray *pendingViews = [[views mutableCopy] autorelease];
	NSMutableDictionary *viewErrors = [NSMutableDictionary dictionary];
	while (!cancelled && [pendingViews count]) {
		NSMutableArray *failed = [NSMutableArray array];
		for (NSArray *view in pendingViews) {
			NSString *what = [NSString stringWithFormat:@"view %@", SPQuoted(view[0])];
			if (![self _report:SPMySQLTransferFinishing detail:what]) { cancelled = YES; break; }
			NSError *viewError = nil;
			if ([self _run:view[1] on:target error:&viewError]) {
				stepIndex++;
				[objectsCreated addObject:what];
			}
			else {
				[failed addObject:view];
				viewErrors[view[0]] = [viewError localizedDescription] ?: @"";
			}
		}
		if (cancelled || [failed count] == [pendingViews count]) {
			for (NSArray *view in failed) [objectsNotCreated addObject:[NSString stringWithFormat:@"view %@: %@", SPQuoted(view[0]), viewErrors[view[0]]]];
			break;
		}
		[pendingViews setArray:failed];
	}
	for (NSArray *trigger in triggers) {
		if (cancelled) break;
		stepIndex++;
		NSString *what = [NSString stringWithFormat:@"trigger %@", SPQuoted(trigger[0])];
		if (![self _report:SPMySQLTransferFinishing detail:what]) { cancelled = YES; break; }
		// One of the same name on a table that wasn't replaced (Overwrite)
		[target queryString:[NSString stringWithFormat:@"DROP TRIGGER IF EXISTS %@", SPQuoted(trigger[0])]];
		[self _create:trigger[1] named:what sqlMode:trigger[2]];
	}
	for (NSArray *routine in routines) {
		if (cancelled) break;
		stepIndex++;
		NSString *what = [NSString stringWithFormat:@"%@ %@", [routine[0] lowercaseString], SPQuoted(routine[1])];
		if (![self _report:SPMySQLTransferFinishing detail:what]) { cancelled = YES; break; }
		[target queryString:[NSString stringWithFormat:@"DROP %@ IF EXISTS %@", routine[0], SPQuoted(routine[1])]];
		[self _create:routine[2] named:what sqlMode:routine[3]];
	}
	[target queryString:@"SET SESSION SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO'"];

	if (cancelled) {
		if (error) *error = SPMySQLTransferError(SPMySQLTransferErrorIncomplete, NSLocalizedString(@"The transfer was cancelled after the tables were copied: some views, triggers, routines or events weren't created.", @"MySQL transfer: cancelled while finishing"), @{SPMySQLTransferNotCreatedKey: [[objectsNotCreated copy] autorelease]});
		return NO;
	}
	if ([objectsNotCreated count]) {
		if (error) *error = SPMySQLTransferError(SPMySQLTransferErrorIncomplete, NSLocalizedString(@"The tables were copied, but some objects couldn't be created.", @"MySQL transfer: finishing failures"), @{SPMySQLTransferNotCreatedKey: [[objectsNotCreated copy] autorelease]});
		return NO;
	}
	return YES;
}

/// Runs a CREATE after the swap (under sqlMode when given); a failure is listed, not fatal.
- (void)_create:(NSString *)statement named:(NSString *)what sqlMode:(NSString *)sqlMode
{
	if (sqlMode) [target queryString:[NSString stringWithFormat:@"SET SESSION SQL_MODE = %@", [target escapeAndQuoteString:sqlMode]]];
	NSError *createError = nil;
	if ([self _run:statement on:target error:&createError]) [objectsCreated addObject:what];
	else [objectsNotCreated addObject:[NSString stringWithFormat:@"%@: %@", what, [createError localizedDescription]]];
}

/// The table's rows streamed from the source into multi-row INSERTs of up to batchSize bytes.
- (BOOL)_copyRowsOf:(NSString *)name into:(NSString *)temporary columns:(NSArray *)columnNames bits:(NSIndexSet *)bits error:(NSError **)error
{
	if (![columnNames count]) return YES;
	NSMutableArray *quoted = [NSMutableArray array];
	for (NSString *column in columnNames) [quoted addObject:SPQuoted(column)];
	NSString *columnList = [quoted componentsJoinedByString:@", "];
	NSString *select = [NSString stringWithFormat:@"SELECT %@ FROM %@.%@", columnList, SPQuoted(sourceDatabase), SPQuoted(name)];
	NSString *insertPrefix = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES ", SPQuoted(temporary), columnList];

	// Below the target's packet limit
	NSUInteger limit = batchSize;
	NSUInteger packet = [target maxQuerySize];
	if (packet > 1024 && packet - 1024 < limit) limit = packet - 1024;

	SPMySQLStreamingResult *result = [[source streamingQueryString:select useLowMemoryBlockingStreaming:NO] retain];
	if ([source queryErrored] || !result) {
		[result release];
		if (error) *error = [self _failure:source statement:select];
		return NO;
	}
	[result setReturnDataAsStrings:NO];

	NSMutableString *insert = [[NSMutableString alloc] initWithString:insertPrefix];
	NSUInteger rowsInInsert = 0;
	NSError *failure = nil; // retained
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSArray *row = nil;
	while ((row = [result getRowAsArray])) {
		NSMutableString *values = [NSMutableString stringWithString:rowsInInsert ? @",(" : @"("];
		for (NSUInteger i = 0; i < [row count]; i++) {
			if (i) [values appendString:@","];
			id value = row[i];
			if (value == [NSNull null]) [values appendString:@"NULL"];
			else if ([bits containsIndex:i]) [values appendFormat:@"b'%@'", [value description]];
			else if ([value isKindOfClass:[SPMySQLGeometryData class]]) [values appendString:[target escapeAndQuoteData:[(SPMySQLGeometryData *)value data]]];
			else if ([value isKindOfClass:[NSData class]]) [values appendString:[value length] ? [target escapeAndQuoteData:value] : @"''"];
			else [values appendString:[target escapeAndQuoteString:[value description]]];
		}
		[values appendString:@")"];

		// Send what is held when this row would make it too long
		if (rowsInInsert && [insert lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + [values lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > limit) {
			NSError *insertError = nil;
			if (![self _run:insert on:target error:&insertError]) {
				failure = [insertError retain];
				break;
			}
			[insert setString:insertPrefix];
			rowsInInsert = 0;
			[values deleteCharactersInRange:NSMakeRange(0, 1)];
		}
		[insert appendString:values];
		rowsInInsert++;
		tableRowsCopied++;
		rowsCopied++;
		if (tableRowsCopied % SPMySQLTransferRowsPerReport == 0) {
			[pool drain];
			pool = [[NSAutoreleasePool alloc] init];
			if (![self _report:SPMySQLTransferCopyingData detail:name]) {
				failure = [[self _cancelledError] retain];
				break;
			}
		}
	}
	if (!failure && rowsInInsert) {
		NSError *insertError = nil;
		if (![self _run:insert on:target error:&insertError]) failure = [insertError retain];
	}
	[pool drain];
	[insert release];
	if (failure) [result cancelResultLoad];
	// The source's read failing midway (a lost connection) shows here
	else if ([source queryErrored]) failure = [[self _failure:source statement:select] retain];
	[result release];
	if (failure) {
		if (error) *error = [failure autorelease];
		else [failure release];
		return NO;
	}
	return YES;
}

@end
