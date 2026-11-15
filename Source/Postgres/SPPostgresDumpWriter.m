#import "SPPostgresDumpWriter.h"
#import "SPPostgresDumpObject.h"
#import "SPPostgresCreateStatement.h"
#import "SPPostgresTableData.h"
#import "SPPostgresErrors.h"
#import "SPPostgresStatementSplitter.h"
#import <PostgresKit/PostgresKit.h>
#import <zlib.h>

/// The value as an NSString, or nil for NULL.
static NSString *SPDumpText(id value)
{
	return [value isKindOfClass:[NSString class]] ? value : nil;
}

static BOOL SPDumpIsTrue(id value)
{
	return [SPDumpText(value) isEqualToString:@"true"];
}

/// "schema"."name"
static NSString *SPDumpQualified(NSString *schema, NSString *name)
{
	return [NSString stringWithFormat:@"%@.%@", SPPostgresQuoteIdentifier(schema ?: @""), SPPostgresQuoteIdentifier(name ?: @"")];
}

/// A JSON array literal of the objects, for a $n parameter read with json_array_elements(_text).
static NSString *SPDumpJSON(NSArray *array)
{
	NSData *data = [NSJSONSerialization dataWithJSONObject:array ?: @[] options:0 error:NULL];
	return data ? [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease] : @"[]";
}

/// The items in order, each after the items it depends on (dependencies maps an item to an NSSet of items; those
/// not in items are ignored); a cycle is broken at its first item in the original order.
static NSArray *SPDumpSorted(NSArray *items, NSDictionary *dependencies)
{
	NSMutableArray *sorted = [NSMutableArray arrayWithCapacity:[items count]];
	NSMutableArray *remaining = [NSMutableArray arrayWithArray:items];
	NSMutableSet *done = [NSMutableSet set];
	NSSet *all = [NSSet setWithArray:items];
	while ([remaining count]) {
		NSUInteger next = 0;
		for (NSUInteger i = 0; i < [remaining count]; i++) {
			BOOL ready = YES;
			for (id dependency in dependencies[remaining[i]]) {
				if ([all containsObject:dependency] && ![done containsObject:dependency] && ![dependency isEqual:remaining[i]]) { ready = NO; break; }
			}
			if (ready) { next = i; break; }
		}
		id item = remaining[next];
		[sorted addObject:item];
		[done addObject:item];
		[remaining removeObjectAtIndex:next];
	}
	return sorted;
}

/// One table, view or sequence being exported.
@interface SPPostgresDumpRelation : NSObject
{
@public
	NSString *oid;
	NSString *schema;
	NSString *name;
	NSString *kind;   // relkind
	BOOL populated;
	NSDictionary *parts;
	NSArray *dataColumns; // the columns COPY writes (not generated ones), quoted, in order
}
@end

@implementation SPPostgresDumpRelation
- (void)dealloc
{
	[oid release];
	[schema release];
	[name release];
	[kind release];
	[parts release];
	[dataColumns release];
	[super dealloc];
}
@end

/// What a dump covers, as rows of the catalog: read by the same queries for -objectsInScope: and for the dump.
@interface SPPostgresDumpScope : NSObject
{
@public
	NSArray *schemaNames;    // the scope's schemas (a table scope: its tables' schemas)
	NSArray *createdSchemas; // those, and the schemas of the dependencies written
	NSArray *relationRows;   // oid, schema, name, relkind, relispopulated; foreign tables included
	NSArray *relationOids;   // the relations that aren't foreign tables
	NSArray *sequences;      // oid, schema, name, type, start, increment, min, max, cache, cycle, owner's deptype, owner,
							 // owner's column, comment
	NSArray *types;          // oid, schema, name, typtype
	NSArray *routines;       // oid, schema, name, identity arguments
	NSArray *extensions;     // name, schema
	NSArray *dependencies;   // SPPostgresDumpObjects that includeDependencies adds (skippedObjects left out)
}
@end

@implementation SPPostgresDumpScope
- (void)dealloc
{
	[schemaNames release];
	[createdSchemas release];
	[relationRows release];
	[relationOids release];
	[sequences release];
	[types release];
	[routines release];
	[extensions release];
	[dependencies release];
	[super dealloc];
}
@end

static SPPostgresDumpObject *SPDumpSequenceObject(NSArray *row)
{
	return [SPPostgresDumpObject objectWithKind:SPPostgresDumpObjectSequence schema:SPDumpText(row[1]) name:SPDumpText(row[2]) arguments:nil];
}

static SPPostgresDumpObject *SPDumpTypeObject(NSArray *row)
{
	NSString *kind = [SPDumpText(row[3]) isEqualToString:@"d"] ? SPPostgresDumpObjectDomain : SPPostgresDumpObjectType;
	return [SPPostgresDumpObject objectWithKind:kind schema:SPDumpText(row[1]) name:SPDumpText(row[2]) arguments:nil];
}

static SPPostgresDumpObject *SPDumpRoutineObject(NSArray *row)
{
	return [SPPostgresDumpObject objectWithKind:SPPostgresDumpObjectRoutine schema:SPDumpText(row[1]) name:SPDumpText(row[2]) arguments:SPDumpText(row[3]) ?: @""];
}

static SPPostgresDumpObject *SPDumpExtensionObject(NSArray *row)
{
	return [SPPostgresDumpObject objectWithKind:SPPostgresDumpObjectExtension schema:SPDumpText(row[1]) name:SPDumpText(row[0]) arguments:nil];
}

/// The object of a relation row (r, p: table; v: view; m: materialized view); nil for a foreign table.
static SPPostgresDumpObject *SPDumpRelationObject(NSArray *row)
{
	NSString *kind = @{@"r": SPPostgresDumpObjectTable, @"p": SPPostgresDumpObjectTable, @"v": SPPostgresDumpObjectView,
					   @"m": SPPostgresDumpObjectMaterializedView}[SPDumpText(row[3]) ?: @""];
	return kind ? [SPPostgresDumpObject objectWithKind:kind schema:SPDumpText(row[1]) name:SPDumpText(row[2]) arguments:nil] : nil;
}

/// A condition on an object (classid, objid) that it isn't an extension's member.
static NSString *const SPDumpNotExtensionMember = @"NOT EXISTS (SELECT 1 FROM pg_catalog.pg_depend d WHERE d.classid = '%@'::pg_catalog.regclass AND d.objid = %@ AND d.deptype = 'e')";

static NSString *SPDumpNotMember(NSString *catalog, NSString *oid)
{
	return [NSString stringWithFormat:SPDumpNotExtensionMember, catalog, oid];
}

/// A condition on the namespace n that it is a user schema.
static NSString *const SPDumpUserSchema = @"n.nspname NOT LIKE 'pg\\_%' AND n.nspname <> 'information_schema'";

@implementation SPPostgresDumpWriter

@synthesize wholeDatabase;
@synthesize schemas;
@synthesize tables;
@synthesize includeStructure;
@synthesize includeData;
@synthesize compress;
@synthesize progress;
@synthesize foreignTablesSkipped;
@synthesize includeDependencies;
@synthesize skippedObjects;
@synthesize flushesOften;

- (NSArray<NSNumber *> *)copyRowCounts
{
	[countLock lock];
	NSArray *counts = [[copyRowCounts copy] autorelease];
	[countLock unlock];
	return counts;
}

- (NSArray<NSString *> *)copyTableNames
{
	[countLock lock];
	NSArray *names = [[copyTableNames copy] autorelease];
	[countLock unlock];
	return names;
}

- (NSUInteger)partOfItemAtOrdinal:(NSUInteger)ordinal
{
	[countLock lock];
	NSUInteger part = 0;
	for (NSUInteger p = 1; p < 4; p++) if (partStarted[p] && partStarts[p] <= ordinal) part = p;
	[countLock unlock];
	return part;
}

- (NSUInteger)startOfPart:(NSUInteger)part
{
	if (part >= 4) return 0;
	[countLock lock];
	NSUInteger start = partStarted[part] ? partStarts[part] : 0;
	[countLock unlock];
	return start;
}

- (NSUInteger)itemCountOfPart:(NSUInteger)part known:(BOOL *)known
{
	if (part >= 4) return 0;
	[countLock lock];
	NSUInteger count = partItemCounts[part];
	// A part is whole once a later one has started (or the dump is written)
	BOOL whole = currentPart > part;
	[countLock unlock];
	if (known) *known = whole;
	return count;
}

- (unsigned long long)rowCountOfCopy:(NSUInteger)index known:(BOOL *)known
{
	[countLock lock];
	BOOL written = index < [copyRowCounts count];
	unsigned long long rows = written ? [copyRowCounts[index] unsignedLongLongValue] : 0;
	[countLock unlock];
	if (known) *known = written;
	return rows;
}

/// Main part changes: where the part's items start
- (void)_enterPart:(NSUInteger)part
{
	[countLock lock];
	if (part < 4 && !partStarted[part]) {
		NSUInteger total = 0;
		for (NSUInteger p = 0; p < 4; p++) total += partItemCounts[p];
		partStarts[part] = total;
		partStarted[part] = YES;
	}
	currentPart = part;
	[countLock unlock];
}

/// The parts -_write: counts items in
enum { SPDumpPartHeader = 0, SPDumpPartStructure = 1, SPDumpPartData = 2, SPDumpPartPostData = 3 };

- (NSUInteger)headerItemCount { return [self itemCountOfPart:SPDumpPartHeader known:NULL]; }
- (NSUInteger)structureItemCount { return [self itemCountOfPart:SPDumpPartStructure known:NULL]; }
- (NSUInteger)dataItemCount { return [self itemCountOfPart:SPDumpPartData known:NULL]; }
- (NSUInteger)postDataItemCount { return [self itemCountOfPart:SPDumpPartPostData known:NULL]; }

+ (NSArray *)orderedExtensions:(NSArray *)names requirements:(NSDictionary *)requirements
{
	return SPDumpSorted(names ?: @[], requirements ?: @{});
}

- (instancetype)initWithConnection:(PGPostgresConnection *)aConnection
{
	if ((self = [super init])) {
		connection = [aConnection retain];
		includeStructure = YES;
		includeData = YES;
	}
	return self;
}

- (void)dealloc
{
	[connection release];
	[schemas release];
	[tables release];
	[progress release];
	[writeError release];
	[foreignTablesSkipped release];
	[skippedObjects release];
	[copyRowCounts release];
	[copyTableNames release];
	[countLock release];
	[super dealloc];
}

#pragma mark - Output

- (BOOL)_openPath:(NSString *)path error:(NSError **)error
{
	const char *fsPath = [path fileSystemRepresentation];
	if (compress) gzipFile = gzopen(fsPath, "wb");
	else plainFile = fopen(fsPath, "wb");
	if (gzipFile || plainFile) return YES;
	if (error) {
		NSString *message = [NSString stringWithFormat:NSLocalizedString(@"“%@” can't be written: %s.", @"Postgres export: the file can't be created"), [path lastPathComponent], strerror(errno)];
		*error = SPPostgresMakeError(SPPostgresErrorQueryFailed, message, nil);
	}
	return NO;
}

- (void)_failWrite
{
	if (writeError) return;
	writeError = [SPPostgresMakeError(SPPostgresErrorQueryFailed, [NSString stringWithFormat:NSLocalizedString(@"The file can't be written: %s.", @"Postgres export: a write failed"), strerror(errno ?: EIO)], nil) retain];
}

- (BOOL)_writeBytes:(const void *)bytes length:(NSUInteger)length
{
	if (writeError) return NO;
	if (!length) return YES;
	if (gzipFile) {
		// gzwrite takes an unsigned int length
		const char *cursor = bytes;
		while (length) {
			unsigned int part = length > (1u << 30) ? (1u << 30) : (unsigned int)length;
			if (gzwrite(gzipFile, cursor, part) != (int)part) { [self _failWrite]; return NO; }
			cursor += part;
			length -= part;
		}
		return YES;
	}
	if (fwrite(bytes, 1, length, plainFile) != length) { [self _failWrite]; return NO; }
	return YES;
}

/// Writes text and counts the items (statements) it holds in the current part. The text holds whole statements.
- (BOOL)_write:(NSString *)text
{
	NSUInteger items = [[SPPostgresStatementSplitter statementsInSQL:text] count];
	NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
	BOOL written = [self _writeBytes:[data bytes] length:[data length]];
	// Counted once written, so a reader never meets an item its count doesn't hold yet
	if (written && plainFile && flushesOften && fflush(plainFile) != 0) {
		[self _failWrite];
		written = NO;
	}
	[countLock lock];
	if (currentPart < 4) partItemCounts[currentPart] += items;
	[countLock unlock];
	return written;
}

/// flushesOften: the data written so far reaches the file every 256 KiB.
- (BOOL)_flushIfDue:(NSUInteger)length force:(BOOL)force
{
	if (!flushesOften || !plainFile) return YES;
	unflushedBytes += length;
	if (!force && unflushedBytes < 256 * 1024) return YES;
	unflushedBytes = 0;
	if (fflush(plainFile) == 0) return YES;
	[self _failWrite];
	return NO;
}

/// Closes the file; NO (setting writeError) when the last writes fail.
- (BOOL)_close
{
	BOOL closed = YES;
	if (gzipFile) {
		closed = gzclose(gzipFile) == Z_OK;
		gzipFile = NULL;
	}
	if (plainFile) {
		closed = fclose(plainFile) == 0;
		plainFile = NULL;
	}
	if (!closed) [self _failWrite];
	return closed;
}

#pragma mark - Queries

/// Every row as arrays of NSString / NSNull, or nil on failure.
- (NSArray *)_rows:(NSString *)sql values:(NSArray *)values error:(NSError **)error
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

#pragma mark - Writing

/// NO, with SPPostgresErrorInvalidSettings, for settings no dump can be written with.
- (BOOL)_checkSettings:(NSError **)error
{
	NSUInteger scopes = (wholeDatabase ? 1 : 0) + (schemas ? 1 : 0) + (tables ? 1 : 0);
	if (scopes != 1) {
		if (error) *error = SPPostgresMakeError(SPPostgresErrorInvalidSettings, NSLocalizedString(@"Choose what to export: the whole database, some schemas or some tables.", @"Postgres export: no single scope"), nil);
		return NO;
	}
	if ((schemas && ![schemas count]) || (tables && ![tables count])) {
		if (error) *error = SPPostgresMakeError(SPPostgresErrorInvalidSettings, NSLocalizedString(@"Choose at least one schema or table to export.", @"Postgres export: empty scope"), nil);
		return NO;
	}
	if (!includeStructure && !includeData) {
		if (error) *error = SPPostgresMakeError(SPPostgresErrorInvalidSettings, NSLocalizedString(@"Choose the structure, the data, or both to export.", @"Postgres export: neither structure nor data"), nil);
		return NO;
	}
	return YES;
}

- (BOOL)_checkIdle:(NSError **)error
{
	if ([connection transactionStatus] == PGPostgresTransactionIdle) return YES;
	if (error) *error = SPPostgresMakeError(SPPostgresErrorQueryFailed, NSLocalizedString(@"The export needs a connection with no transaction open.", @"Postgres export: connection busy"), nil);
	return NO;
}

- (BOOL)writeToPath:(NSString *)path error:(NSError **)error
{
	if (![self _checkSettings:error] || ![self _checkIdle:error]) return NO;

	[writeError release];
	writeError = nil;
	if (![self _openPath:path error:error]) return NO;

	NSError *failure = nil;
	BOOL written = SPPostgresExecute(connection, @"BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY", nil, &failure) != nil;
	if (written) {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		written = [self _writeDump:&failure];
		// Every part is whole now
		[countLock lock];
		if (written) currentPart = 4;
		[countLock unlock];
		[failure retain];
		[pool drain];
		[failure autorelease];
	}
	if (written) written = SPPostgresExecute(connection, @"COMMIT", nil, &failure) != nil;
	if (!written) {
		// A failed COPY may leave the transaction open or aborted; a second ROLLBACK covers one a late cancel hit
		for (NSUInteger attempt = 0; attempt < 2 && [connection transactionStatus] != PGPostgresTransactionIdle; attempt++) {
			SPPostgresExecute(connection, @"ROLLBACK", nil, NULL);
		}
	}
	if (![self _close] && written) {
		written = NO;
		failure = [[writeError retain] autorelease];
	}
	if (!written) {
		unlink([path fileSystemRepresentation]);
		if (writeError && (!failure || [failure code] != SPPostgresErrorCancelled)) failure = [[writeError retain] autorelease];
		if (error) *error = failure ?: SPPostgresMakeError(SPPostgresErrorQueryFailed, NSLocalizedString(@"The export failed.", @"Postgres export: unknown failure"), nil);
	}
	return written;
}

#pragma mark - Scope objects

- (NSArray *)objectsInScope:(NSError **)error
{
	return [self _objectsInScopeDependenciesOnly:NO error:error];
}

- (NSArray *)dependenciesInScope:(NSError **)error
{
	return [self _objectsInScopeDependenciesOnly:YES error:error];
}

- (NSArray *)_objectsInScopeDependenciesOnly:(BOOL)dependenciesOnly error:(NSError **)error
{
	if (![self _checkSettings:error]) return nil;
	if (!includeStructure) return @[];
	if (![self _checkIdle:error]) return nil;

	// The dump's own reading conditions: one snapshot, and an empty search_path (the identity arguments name types as
	// the dump does)
	NSError *failure = nil;
	SPPostgresDumpScope *scope = nil;
	if (SPPostgresExecute(connection, @"BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY", nil, &failure)
		&& [self _rows:@"SELECT pg_catalog.set_config('search_path', '', true)" values:nil error:&failure]) {
		scope = [self _scope:&failure];
	}
	if ([connection transactionStatus] != PGPostgresTransactionIdle) SPPostgresExecute(connection, @"ROLLBACK", nil, NULL);
	if (!scope) {
		if (error) *error = failure ?: SPPostgresMakeError(SPPostgresErrorQueryFailed, NSLocalizedString(@"The export failed.", @"Postgres export: unknown failure"), nil);
		return nil;
	}

	NSMutableArray *objects = [NSMutableArray arrayWithArray:scope->dependencies];
	if (!dependenciesOnly) {
		[objects removeAllObjects];
		for (NSArray *row in scope->relationRows) {
			SPPostgresDumpObject *object = SPDumpRelationObject(row);
			if (object) [objects addObject:object];
		}
		// Identity sequences are created by their tables
		for (NSArray *row in scope->sequences) if (![SPDumpText(row[10]) isEqualToString:@"i"]) [objects addObject:SPDumpSequenceObject(row)];
		for (NSArray *row in scope->types) [objects addObject:SPDumpTypeObject(row)];
		for (NSArray *row in scope->routines) [objects addObject:SPDumpRoutineObject(row)];
		for (NSArray *row in scope->extensions) [objects addObject:SPDumpExtensionObject(row)];
	}
	[objects sortUsingComparator:^NSComparisonResult(SPPostgresDumpObject *a, SPPostgresDumpObject *b) {
		NSComparisonResult result = [[a kind] compare:[b kind]];
		if (result == NSOrderedSame) result = [[a schema] ?: @"" compare:[b schema] ?: @""];
		if (result == NSOrderedSame) result = [[a name] ?: @"" compare:[b name] ?: @""];
		if (result == NSOrderedSame) result = [[a arguments] ?: @"" compare:[b arguments] ?: @""];
		return result;
	}];
	return objects;
}

#pragma mark - Writing (continued)

- (NSError *)_cancelledError
{
	return SPPostgresMakeError(SPPostgresErrorCancelled, NSLocalizedString(@"The export was cancelled.", @"Postgres export: cancelled"), nil);
}

/// Writes statements (`;`-terminated text), followed by a blank line; YES for none.
- (BOOL)_writeSection:(NSString *)text
{
	if (![text length]) return YES;
	return [self _write:text] && [self _write:@"\n"];
}

- (BOOL)_writeDump:(NSError **)error
{
	if (!countLock) countLock = [[NSLock alloc] init];
	[countLock lock];
	currentPart = SPDumpPartHeader;
	memset(partItemCounts, 0, sizeof(partItemCounts));
	memset(partStarts, 0, sizeof(partStarts));
	memset(partStarted, 0, sizeof(partStarted));
	partStarted[SPDumpPartHeader] = YES;
	[copyRowCounts release];
	copyRowCounts = [[NSMutableArray alloc] init];
	[copyTableNames release];
	copyTableNames = [[NSMutableArray alloc] init];
	[countLock unlock];
	unflushedBytes = 0;

	// An empty search_path has the server qualify every name it writes; ISO dates and full float precision read back
	// the same whatever the importing session's settings (all LOCAL: they end with the transaction)
	if (![self _rows:@"SELECT pg_catalog.set_config('search_path', '', true), pg_catalog.set_config('datestyle', 'ISO', true),"
		  " pg_catalog.set_config('intervalstyle', 'postgres', true), pg_catalog.set_config('extra_float_digits', '3', true),"
		  // A table whose row-level security would hide rows from this role makes the COPY fail instead of exporting
		  // a subset
		  " pg_catalog.set_config('row_security', 'off', true)" values:nil error:error]) return NO;

	NSArray *info = [self _rows:@"SELECT pg_catalog.current_setting('server_version')::text, pg_catalog.current_database()::text,"
					 " pg_catalog.current_setting('server_version_num')::text, pg_catalog.current_setting('client_encoding')::text" values:nil error:error];
	if (!info) return NO;
	NSString *serverVersion = SPDumpText(info[0][0]) ?: @"";
	NSString *database = SPDumpText(info[0][1]) ?: @"";
	NSInteger versionNumber = [SPDumpText(info[0][2]) integerValue];
	// UNICODE is the server's other name for UTF8
	NSString *clientEncoding = [[[SPDumpText(info[0][3]) uppercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@""] stringByReplacingOccurrencesOfString:@"_" withString:@""];
	if (![clientEncoding isEqualToString:@"UTF8"] && ![clientEncoding isEqualToString:@"UNICODE"]) {
		if (error) *error = SPPostgresMakeError(SPPostgresErrorQueryFailed, [NSString stringWithFormat:NSLocalizedString(@"The connection's client encoding is %@, not UTF8.", @"Postgres export: wrong client encoding"), SPDumpText(info[0][3])], nil);
		return NO;
	}

	// 1. Header
	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	[formatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
	[formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss ZZZZZ"];
	NSString *(^oneLine)(NSString *) = ^NSString *(NSString *text) {
		return [[text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];
	};
	NSMutableString *header = [NSMutableString string];
	[header appendString:@"--\n-- PostgreSQL database dump written by Sequel Pro\n"];
	[header appendFormat:@"-- Server version: %@\n", oneLine(serverVersion)];
	[header appendFormat:@"-- Database: %@\n", oneLine(database)];
	[header appendFormat:@"-- Date: %@\n", [formatter stringFromDate:[NSDate date]]];
	// (written once the scope is known: it names the foreign tables left out)

	// The scope
	SPPostgresDumpScope *scope = [self _scope:error];
	if (!scope) return NO;
	NSMutableArray *tableRelations = [NSMutableArray array];
	NSMutableArray *viewRelations = [NSMutableArray array];
	NSMutableDictionary *relationsByOid = [NSMutableDictionary dictionary];
	NSMutableArray *foreignTables = [NSMutableArray array];
	for (NSArray *row in scope->relationRows) {
		// Foreign tables are left out (structure and data): without their server and user mapping, which aren't
		// exported, creating them would fail the whole import
		if ([SPDumpText(row[3]) isEqualToString:@"f"]) {
			[foreignTables addObject:@[SPDumpText(row[1]) ?: @"", SPDumpText(row[2]) ?: @""]];
			continue;
		}
		SPPostgresDumpRelation *relation = [[[SPPostgresDumpRelation alloc] init] autorelease];
		relation->oid = [SPDumpText(row[0]) copy];
		relation->schema = [SPDumpText(row[1]) copy];
		relation->name = [SPDumpText(row[2]) copy];
		relation->kind = [SPDumpText(row[3]) copy];
		relation->populated = SPDumpIsTrue(row[4]);
		relationsByOid[relation->oid] = relation;
		if ([relation->kind isEqualToString:@"v"] || [relation->kind isEqualToString:@"m"]) [viewRelations addObject:relation->oid];
		else [tableRelations addObject:relation->oid];
	}
	NSString *relationsJSON = SPDumpJSON([relationsByOid allKeys]);
	[foreignTablesSkipped release];
	foreignTablesSkipped = [foreignTables copy];

	// 1. Header (continued)
	if ([foreignTables count]) {
		NSMutableArray *names = [NSMutableArray array];
		for (NSArray *pair in foreignTables) [names addObject:SPDumpQualified(pair[0], pair[1])];
		[header appendFormat:@"-- Foreign tables not exported: %@\n", oneLine([names componentsJoinedByString:@", "])];
	}
	[header appendString:@"--\n\nSET client_encoding = 'UTF8';\nSET standard_conforming_strings = on;\nSET check_function_bodies = false;\n"
						 "SELECT pg_catalog.set_config('search_path', '', false);\n\n"];
	if (![self _write:header]) return NO;

	// Tables: parents before their partitions and inheritance children
	NSArray *inherits = [self _rows:@"SELECT i.inhrelid::text, i.inhparent::text FROM pg_catalog.pg_inherits i"
						 " WHERE i.inhrelid IN (SELECT pg_catalog.json_array_elements_text($1::json)::oid)" values:@[relationsJSON] error:error];
	if (!inherits) return NO;
	NSMutableDictionary *tableDependencies = [NSMutableDictionary dictionary];
	for (NSArray *row in inherits) {
		NSString *child = SPDumpText(row[0]);
		if (!tableDependencies[child]) tableDependencies[child] = [NSMutableSet set];
		[tableDependencies[child] addObject:SPDumpText(row[1]) ?: @""];
	}
	NSArray *orderedTables = SPDumpSorted(tableRelations, tableDependencies);

	// Views: after the views they read
	NSArray *viewReads = [self _rows:@"SELECT DISTINCT r.ev_class::text, d.refobjid::text FROM pg_catalog.pg_rewrite r"
						  " JOIN pg_catalog.pg_depend d ON d.classid = 'pg_catalog.pg_rewrite'::pg_catalog.regclass AND d.objid = r.oid"
						  " AND d.refclassid = 'pg_catalog.pg_class'::pg_catalog.regclass AND d.refobjid <> r.ev_class"
						  " WHERE r.ev_class IN (SELECT pg_catalog.json_array_elements_text($1::json)::oid)" values:@[SPDumpJSON(viewRelations)] error:error];
	if (!viewReads) return NO;
	NSMutableDictionary *viewDependencies = [NSMutableDictionary dictionary];
	for (NSArray *row in viewReads) {
		NSString *view = SPDumpText(row[0]);
		if (!viewDependencies[view]) viewDependencies[view] = [NSMutableSet set];
		[viewDependencies[view] addObject:SPDumpText(row[1]) ?: @""];
	}
	NSArray *orderedViews = SPDumpSorted(viewRelations, viewDependencies);

	// Each relation's parts (materialized views created WITH NO DATA, refreshed after the data), read for them all at
	// once: a few queries, whatever the number of tables (one round trip each, which over a network is what takes time)
	NSArray *allRelations = [orderedTables arrayByAddingObjectsFromArray:orderedViews];
	if ([allRelations count]) {
		NSMutableArray *pairs = [NSMutableArray arrayWithCapacity:[allRelations count]];
		for (NSString *oid in allRelations) {
			SPPostgresDumpRelation *relation = relationsByOid[oid];
			[pairs addObject:@[relation->schema ?: @"", relation->name ?: @""]];
		}
		NSDictionary *allParts = [SPPostgresCreateStatement partsForTables:pairs materializedViewWithNoData:YES connection:connection error:error];
		if (!allParts) return NO;
		for (NSString *oid in allRelations) {
			SPPostgresDumpRelation *relation = relationsByOid[oid];
			relation->parts = [allParts[@[relation->schema ?: @"", relation->name ?: @""]] retain];
		}
	}

	// The columns each table's COPY writes, for them all at once
	if (includeData && [orderedTables count]) {
		NSArray *columnRows = [self _rows:@"SELECT a.attrelid::text, a.attname::text FROM pg_catalog.pg_attribute a"
							   " WHERE a.attrelid IN (SELECT pg_catalog.json_array_elements_text($1::json)::oid) AND a.attnum > 0"
							   " AND NOT a.attisdropped AND a.attgenerated = '' ORDER BY a.attrelid, a.attnum" values:@[SPDumpJSON(orderedTables)] error:error];
		if (!columnRows) return NO;
		NSMutableDictionary *columnsByOid = [NSMutableDictionary dictionary];
		for (NSArray *row in columnRows) {
			NSString *oid = SPDumpText(row[0]) ?: @"";
			if (!columnsByOid[oid]) columnsByOid[oid] = [NSMutableArray array];
			[columnsByOid[oid] addObject:SPPostgresQuoteIdentifier(SPDumpText(row[1]) ?: @"")];
		}
		for (NSString *oid in orderedTables) {
			SPPostgresDumpRelation *relation = relationsByOid[oid];
			relation->dataColumns = [(columnsByOid[oid] ?: @[]) copy];
		}
	}

	[self _enterPart:SPDumpPartStructure];
	if (includeStructure) {
		if (![self _writeStructureBeforeDataWithScope:scope relations:relationsByOid tables:orderedTables views:orderedViews versionNumber:versionNumber error:error]) return NO;
	}

	[self _enterPart:SPDumpPartData];
	if (includeData) {
		if (![self _writeDataForTables:orderedTables relations:relationsByOid relationsJSON:relationsJSON sequences:scope->sequences error:error]) return NO;
	}
	else if (!includeStructure) {
		return YES;
	}

	[self _enterPart:SPDumpPartPostData];
	if (includeStructure) {
		if (![self _writeStructureAfterDataWithRelations:relationsByOid tables:orderedTables views:orderedViews error:error]) return NO;
		if (![self _writeCommentsWithScope:scope error:error]) return NO;
	}
	return YES;
}

/// The scope's catalog rows; a table scope fails when a table is missing. Used inside the dump's transaction and by
/// -objectsInScope:, both with an empty search_path.
- (SPPostgresDumpScope *)_scope:(NSError **)error
{
	SPPostgresDumpScope *scope = [[[SPPostgresDumpScope alloc] init] autorelease];
	NSArray *schemaNames = nil;
	NSArray *relationRows = nil;
	NSString *relationColumns = @"SELECT c.oid::text, n.nspname::text, c.relname::text, c.relkind::text, c.relispopulated::text"
								 " FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace";
	NSString *relationOrder = @" ORDER BY n.nspname COLLATE \"C\", c.relname COLLATE \"C\"";
	NSString *relationFilter = [NSString stringWithFormat:@" AND c.relkind IN ('r', 'p', 'f', 'v', 'm') AND c.relpersistence <> 't' AND %@",
								SPDumpNotMember(@"pg_catalog.pg_class", @"c.oid")];

	if (tables) {
		// A partitioned table brings its partitions, recursively (as pg_dump --table-and-children)
		NSString *sql = [NSString stringWithFormat:@"%@ WHERE c.oid IN ("
						 "SELECT g.oid FROM pg_catalog.pg_class g JOIN pg_catalog.pg_namespace gn ON gn.oid = g.relnamespace"
						 " WHERE (gn.nspname, g.relname) IN (SELECT x->>0, x->>1 FROM pg_catalog.json_array_elements($1::json) x)"
						 " UNION SELECT t.relid FROM pg_catalog.pg_class g JOIN pg_catalog.pg_namespace gn ON gn.oid = g.relnamespace,"
						 " LATERAL pg_catalog.pg_partition_tree(g.oid) t"
						 " WHERE g.relkind = 'p' AND (gn.nspname, g.relname) IN (SELECT x->>0, x->>1 FROM pg_catalog.json_array_elements($1::json) x))%@%@",
						 relationColumns, relationFilter, relationOrder];
		relationRows = [self _rows:sql values:@[SPDumpJSON(tables)] error:error];
		if (!relationRows) return nil;
		NSMutableSet *found = [NSMutableSet set];
		NSMutableArray *names = [NSMutableArray array];
		for (NSArray *row in relationRows) {
			[found addObject:@[SPDumpText(row[1]) ?: @"", SPDumpText(row[2]) ?: @""]];
			if (![names containsObject:SPDumpText(row[1]) ?: @""]) [names addObject:SPDumpText(row[1]) ?: @""];
		}
		for (NSArray *pair in tables) {
			if (![pair isKindOfClass:[NSArray class]] || [pair count] != 2 || ![found containsObject:pair]) {
				if (error) *error = SPPostgresMakeError(SPPostgresErrorQueryFailed, [NSString stringWithFormat:NSLocalizedString(@"There is no table “%@” to export.", @"Postgres export: missing table"), [pair isKindOfClass:[NSArray class]] ? [pair componentsJoinedByString:@"."] : pair], nil);
				return nil;
			}
		}
		schemaNames = [names sortedArrayUsingSelector:@selector(compare:)];
	}
	else {
		if (wholeDatabase) {
			NSString *sql = [NSString stringWithFormat:@"SELECT n.nspname::text FROM pg_catalog.pg_namespace n WHERE %@ AND %@ ORDER BY n.nspname COLLATE \"C\"",
							 SPDumpUserSchema, SPDumpNotMember(@"pg_catalog.pg_namespace", @"n.oid")];
			NSArray *rows = [self _rows:sql values:nil error:error];
			if (!rows) return nil;
			NSMutableArray *names = [NSMutableArray array];
			for (NSArray *row in rows) [names addObject:SPDumpText(row[0]) ?: @""];
			schemaNames = names;
		}
		else {
			NSArray *rows = [self _rows:@"SELECT x FROM pg_catalog.json_array_elements_text($1::json) x WHERE NOT EXISTS (SELECT 1 FROM pg_catalog.pg_namespace n WHERE n.nspname = x)" values:@[SPDumpJSON(schemas)] error:error];
			if (!rows) return nil;
			if ([rows count]) {
				if (error) *error = SPPostgresMakeError(SPPostgresErrorQueryFailed, [NSString stringWithFormat:NSLocalizedString(@"There is no schema “%@” to export.", @"Postgres export: missing schema"), SPDumpText(rows[0][0])], nil);
				return nil;
			}
			schemaNames = schemas;
		}
		NSString *sql = [NSString stringWithFormat:@"%@ WHERE n.nspname IN (SELECT pg_catalog.json_array_elements_text($1::json))%@%@", relationColumns, relationFilter, relationOrder];
		relationRows = [self _rows:sql values:@[SPDumpJSON(schemaNames)] error:error];
		if (!relationRows) return nil;
	}
	NSMutableArray *relationOids = [NSMutableArray array];
	for (NSArray *row in relationRows) {
		if (![SPDumpText(row[3]) isEqualToString:@"f"]) [relationOids addObject:SPDumpText(row[0]) ?: @""];
	}
	scope->schemaNames = [schemaNames copy];
	scope->relationRows = [relationRows retain];
	scope->relationOids = [relationOids copy];

	// Each query below takes $1: the relations (a table scope) or the schemas
	NSArray *values = @[tables ? SPDumpJSON(relationOids) : SPDumpJSON(schemaNames)];
	NSString *inSchemas = @"n.nspname IN (SELECT pg_catalog.json_array_elements_text($1::json))";
	NSString *relations = @"(SELECT pg_catalog.json_array_elements_text($1::json)::oid)";
	BOOL dependencies = tables && includeDependencies;

	// A table scope's dependencies: the user types their columns use, followed through domains' base types, composite
	// types' attributes, array element types and range subtypes (an extension's member is reached, not followed); the
	// functions their triggers call; the sequences their column defaults call (nextval records the dependency)
	NSString *usedTypes = [NSString stringWithFormat:
		@"(WITH RECURSIVE used(oid) AS ("
		"SELECT a.atttypid FROM pg_catalog.pg_attribute a WHERE a.attrelid IN %@ AND a.attnum > 0 AND NOT a.attisdropped"
		" UNION SELECT x.oid FROM used u JOIN pg_catalog.pg_type t ON t.oid = u.oid JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace,"
		" LATERAL (SELECT t.typbasetype WHERE t.typbasetype <> 0"
		"  UNION ALL SELECT t.typelem WHERE t.typelem <> 0"
		"  UNION ALL SELECT a.atttypid FROM pg_catalog.pg_class c JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid"
		"   WHERE c.oid = t.typrelid AND c.relkind = 'c' AND a.attnum > 0 AND NOT a.attisdropped"
		"  UNION ALL SELECT r.rngsubtype FROM pg_catalog.pg_range r WHERE r.rngtypid = t.oid) x(oid)"
		" WHERE %@ AND %@"
		") SELECT used.oid FROM used)", relations, SPDumpUserSchema, SPDumpNotMember(@"pg_catalog.pg_type", @"t.oid")];
	NSString *triggerFunctions = [NSString stringWithFormat:@"(SELECT tg.tgfoid FROM pg_catalog.pg_trigger tg WHERE tg.tgrelid IN %@ AND NOT tg.tgisinternal)", relations];
	NSString *defaultSequences = [NSString stringWithFormat:
		@"(SELECT ad_d.refobjid FROM pg_catalog.pg_attrdef ad JOIN pg_catalog.pg_depend ad_d ON ad_d.classid = 'pg_catalog.pg_attrdef'::pg_catalog.regclass"
		" AND ad_d.objid = ad.oid AND ad_d.refclassid = 'pg_catalog.pg_class'::pg_catalog.regclass WHERE ad.adrelid IN %@)", relations];

	// Sequences: every one in the schemas, or those of the selected tables (and, with their dependencies, those their
	// defaults call); with what owns them
	NSString *sequenceSQL = [NSString stringWithFormat:
		@"SELECT c.oid::text, n.nspname::text, c.relname::text, pg_catalog.format_type(s.seqtypid, NULL)::text, s.seqstart::text,"
		" s.seqincrement::text, s.seqmin::text, s.seqmax::text, s.seqcache::text, s.seqcycle::text, d.deptype::text, d.refobjid::text,"
		" a.attname::text, pg_catalog.obj_description(c.oid, 'pg_class')::text"
		" FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace"
		" JOIN pg_catalog.pg_sequence s ON s.seqrelid = c.oid"
		" LEFT JOIN pg_catalog.pg_depend d ON d.classid = 'pg_catalog.pg_class'::pg_catalog.regclass AND d.objid = c.oid"
		" AND d.refclassid = 'pg_catalog.pg_class'::pg_catalog.regclass AND d.deptype IN ('a', 'i')"
		" LEFT JOIN pg_catalog.pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid"
		" WHERE c.relkind = 'S' AND %@ AND %@"
		" ORDER BY n.nspname COLLATE \"C\", c.relname COLLATE \"C\"",
		SPDumpNotMember(@"pg_catalog.pg_class", @"c.oid"),
		!tables ? inSchemas : dependencies ? [NSString stringWithFormat:@"(d.refobjid IN %@ OR c.oid IN %@)", relations, defaultSequences]
		: [NSString stringWithFormat:@"d.refobjid IN %@", relations]];
	NSArray *sequences = [self _rows:sequenceSQL values:values error:error];
	if (!sequences) return nil;

	// Types: enums, standalone composites, ranges and domains
	NSArray *types = @[];
	if (!tables || dependencies) {
		NSString *sql = [NSString stringWithFormat:
			@"SELECT t.oid::text, n.nspname::text, t.typname::text, t.typtype::text"
			" FROM pg_catalog.pg_type t JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace"
			" WHERE t.typtype IN ('e', 'c', 'r', 'd')"
			" AND (t.typtype <> 'c' OR (SELECT c.relkind FROM pg_catalog.pg_class c WHERE c.oid = t.typrelid) = 'c') AND %@ AND %@"
			" ORDER BY n.nspname COLLATE \"C\", t.typname COLLATE \"C\"", SPDumpNotMember(@"pg_catalog.pg_type", @"t.oid"),
			tables ? [NSString stringWithFormat:@"t.oid IN %@ AND %@", usedTypes, SPDumpUserSchema] : inSchemas];
		types = [self _rows:sql values:values error:error];
		if (!types) return nil;
	}

	// Functions and procedures
	NSArray *routines = @[];
	if (!tables || dependencies) {
		NSString *sql = [NSString stringWithFormat:
			@"SELECT p.oid::text, n.nspname::text, p.proname::text, pg_catalog.pg_get_function_identity_arguments(p.oid)::text"
			" FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace"
			" WHERE p.prokind IN ('f', 'p') AND %@ AND %@"
			" ORDER BY n.nspname COLLATE \"C\", p.proname COLLATE \"C\", pg_catalog.pg_get_function_identity_arguments(p.oid) COLLATE \"C\"",
			SPDumpNotMember(@"pg_catalog.pg_proc", @"p.oid"),
			tables ? [NSString stringWithFormat:@"p.oid IN %@ AND %@", triggerFunctions, SPDumpUserSchema] : inSchemas];
		routines = [self _rows:sql values:values error:error];
		if (!routines) return nil;
	}

	// Extensions: a database's every one but plpgsql, a schema's those installed in it, a table's those owning its
	// types or trigger functions, with the extensions they require
	NSArray *extensions = @[];
	if (!tables || dependencies) {
		NSString *condition = inSchemas;
		if (wholeDatabase) condition = @"$1::text IS NOT NULL";
		else if (tables) condition = [NSString stringWithFormat:
			@"e.oid IN (WITH RECURSIVE needed(oid) AS ("
			"SELECT d.refobjid FROM pg_catalog.pg_depend d WHERE d.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass AND d.deptype = 'e'"
			" AND ((d.classid = 'pg_catalog.pg_type'::pg_catalog.regclass AND d.objid IN %@)"
			"  OR (d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass AND d.objid IN %@))"
			" UNION SELECT r.refobjid FROM needed JOIN pg_catalog.pg_depend r ON r.classid = 'pg_catalog.pg_extension'::pg_catalog.regclass"
			"  AND r.objid = needed.oid AND r.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass"
			") SELECT needed.oid FROM needed)", usedTypes, triggerFunctions];
		NSString *sql = [NSString stringWithFormat:
			@"SELECT e.extname::text, n.nspname::text FROM pg_catalog.pg_extension e JOIN pg_catalog.pg_namespace n ON n.oid = e.extnamespace"
			" WHERE %@ AND %@ ORDER BY e.extname COLLATE \"C\"", wholeDatabase || tables ? @"e.extname <> 'plpgsql'" : @"TRUE", condition];
		extensions = [self _rows:sql values:values error:error];
		if (!extensions) return nil;
	}

	// The dependencies, less those skipped
	NSMutableArray *createdSchemas = [NSMutableArray arrayWithArray:schemaNames];
	NSMutableArray *dependencyObjects = [NSMutableArray array];
	if (dependencies) {
		NSSet *skipped = [NSSet setWithArray:skippedObjects ?: @[]];
		BOOL (^add)(SPPostgresDumpObject *) = ^BOOL(SPPostgresDumpObject *dependency) {
			if ([skipped containsObject:dependency]) return NO;
			[dependencyObjects addObject:dependency];
			if (![createdSchemas containsObject:[dependency schema] ?: @""]) [createdSchemas addObject:[dependency schema] ?: @""];
			return YES;
		};
		NSArray *(^kept)(NSArray *, SPPostgresDumpObject *(*)(NSArray *)) = ^NSArray *(NSArray *rows, SPPostgresDumpObject *(*object)(NSArray *)) {
			NSMutableArray *written = [NSMutableArray array];
			for (NSArray *row in rows) if (add(object(row))) [written addObject:row];
			return written;
		};
		// A sequence a table in scope owns isn't a dependency; an identity sequence of a table outside the scope can't
		// be created on its own
		NSSet *inScope = [NSSet setWithArray:relationOids];
		NSMutableArray *written = [NSMutableArray array];
		for (NSArray *row in sequences) {
			if ([inScope containsObject:SPDumpText(row[11]) ?: @""]) [written addObject:row];
			else if (![SPDumpText(row[10]) isEqualToString:@"i"] && add(SPDumpSequenceObject(row))) [written addObject:row];
		}
		sequences = written;
		types = kept(types, SPDumpTypeObject);
		routines = kept(routines, SPDumpRoutineObject);
		extensions = kept(extensions, SPDumpExtensionObject);
	}
	scope->sequences = [sequences retain];
	scope->types = [types retain];
	scope->routines = [routines retain];
	scope->extensions = [extensions retain];
	scope->dependencies = [dependencyObjects copy];
	scope->createdSchemas = [(tables ? [createdSchemas sortedArrayUsingSelector:@selector(compare:)] : schemaNames) copy];
	return scope;
}

#pragma mark Structure before the data (2–8)

- (BOOL)_writeStructureBeforeDataWithScope:(SPPostgresDumpScope *)scope relations:(NSDictionary *)relations tables:(NSArray *)orderedTables views:(NSArray *)orderedViews versionNumber:(NSInteger)versionNumber error:(NSError **)error
{
	NSArray *sequences = scope->sequences;

	// 2. Schemas
	NSMutableString *section = [NSMutableString string];
	for (NSString *schema in scope->createdSchemas) {
		if ([schema isEqualToString:@"public"]) continue;
		[section appendFormat:@"CREATE SCHEMA IF NOT EXISTS %@;\n", SPPostgresQuoteIdentifier(schema)];
	}
	if (![self _writeSection:section]) return NO;

	// 3. Extensions
	if ([scope->extensions count]) {
		NSArray *rows = scope->extensions;
		// Each after the extensions it requires (CREATE EXTENSION records them in pg_depend)
		NSArray *requires = [self _rows:@"SELECT e.extname::text, r.extname::text FROM pg_catalog.pg_depend d"
							 " JOIN pg_catalog.pg_extension e ON e.oid = d.objid JOIN pg_catalog.pg_extension r ON r.oid = d.refobjid"
							 " WHERE d.classid = 'pg_catalog.pg_extension'::pg_catalog.regclass AND d.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass" values:nil error:error];
		if (!requires) return NO;
		NSMutableDictionary *requirements = [NSMutableDictionary dictionary];
		for (NSArray *row in requires) {
			NSString *extension = SPDumpText(row[0]) ?: @"";
			if (!requirements[extension]) requirements[extension] = [NSMutableSet set];
			[requirements[extension] addObject:SPDumpText(row[1]) ?: @""];
		}
		NSMutableArray *names = [NSMutableArray array];
		NSMutableDictionary *schemaOfExtension = [NSMutableDictionary dictionary];
		for (NSArray *row in rows) {
			NSString *extension = SPDumpText(row[0]) ?: @"";
			[names addObject:extension];
			schemaOfExtension[extension] = SPDumpText(row[1]) ?: @"";
		}
		section = [NSMutableString string];
		for (NSString *extension in [[self class] orderedExtensions:names requirements:requirements]) {
			[section appendFormat:@"CREATE EXTENSION IF NOT EXISTS %@ WITH SCHEMA %@;\n", SPPostgresQuoteIdentifier(extension), SPPostgresQuoteIdentifier(schemaOfExtension[extension])];
		}
		if (![self _writeSection:section]) return NO;
	}

	// 4. Types (domains without their CHECK constraints: those come after the functions they may call)
	NSMutableString *domainChecks = [NSMutableString string];
	if (![self _writeTypes:scope->types versionNumber:versionNumber domainChecks:domainChecks error:error]) return NO;

	// 5. Functions (some held back until after the views)
	NSMutableArray *heldBack = [NSMutableArray array];
	if ([scope->routines count]) {
		NSMutableArray *oids = [NSMutableArray array];
		for (NSArray *routine in scope->routines) [oids addObject:SPDumpText(routine[0]) ?: @""];
		NSString *sql = [NSString stringWithFormat:
			@"SELECT pg_catalog.pg_get_functiondef(p.oid)::text, %@,"
			" EXISTS (SELECT 1 FROM pg_catalog.pg_depend d JOIN pg_catalog.pg_type rt ON rt.oid = d.refobjid"
			"   JOIN pg_catalog.pg_class rc ON rc.oid = rt.typrelid"
			"   WHERE d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass AND d.objid = p.oid"
			"   AND d.refclassid = 'pg_catalog.pg_type'::pg_catalog.regclass AND rc.relkind <> 'c')::text"
			" FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace"
			" WHERE p.oid IN (SELECT pg_catalog.json_array_elements_text($1::json)::oid)"
			" ORDER BY n.nspname COLLATE \"C\", p.proname COLLATE \"C\", pg_catalog.pg_get_function_identity_arguments(p.oid) COLLATE \"C\"",
			versionNumber >= 140000 ? @"(p.prosqlbody IS NOT NULL)::text" : @"'false'::text"];
		NSArray *rows = [self _rows:sql values:@[SPDumpJSON(oids)] error:error];
		if (!rows) return NO;
		section = [NSMutableString string];
		for (NSArray *row in rows) {
			NSString *definition = [[SPDumpText(row[0]) ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByAppendingString:@";\n\n"];
			if (SPDumpIsTrue(row[1]) || SPDumpIsTrue(row[2])) [heldBack addObject:definition];
			else [section appendString:definition];
		}
		if (![self _write:section]) return NO;
	}

	// 6. Sequences (identity columns' come with their tables)
	section = [NSMutableString string];
	for (NSArray *sequence in sequences) {
		if ([SPDumpText(sequence[10]) isEqualToString:@"i"]) continue;
		[section appendFormat:@"CREATE SEQUENCE %@\n    AS %@\n%@;\n\n", SPDumpQualified(SPDumpText(sequence[1]), SPDumpText(sequence[2])), SPDumpText(sequence[3]) ?: @"bigint", [self _sequenceOptions:sequence prefix:@"    " separator:@"\n"]];
	}
	if (![self _write:section]) return NO;

	// 7. Tables, then the identity sequences' options and the serial sequences' owners
	for (NSString *oid in orderedTables) {
		SPPostgresDumpRelation *relation = relations[oid];
		if (!includeData && ![self _reportTable:relation index:[orderedTables indexOfObject:oid] + 1 count:[orderedTables count] error:error]) return NO;
		if (![self _writeSection:relation->parts[SPPostgresCreatePartTable]]) return NO;
	}
	section = [NSMutableString string];
	for (NSArray *sequence in sequences) {
		NSString *dependency = SPDumpText(sequence[10]);
		SPPostgresDumpRelation *owner = relations[SPDumpText(sequence[11]) ?: @""];
		if (!owner || !SPDumpText(sequence[12])) continue;
		if ([dependency isEqualToString:@"i"]) {
			[section appendFormat:@"ALTER TABLE %@ ALTER COLUMN %@ %@;\n", SPDumpQualified(owner->schema, owner->name), SPPostgresQuoteIdentifier(SPDumpText(sequence[12])), [self _sequenceOptions:sequence prefix:@"SET " separator:@" "]];
		}
		else if ([dependency isEqualToString:@"a"]) {
			[section appendFormat:@"ALTER SEQUENCE %@ OWNED BY %@.%@;\n", SPDumpQualified(SPDumpText(sequence[1]), SPDumpText(sequence[2])), SPDumpQualified(owner->schema, owner->name), SPPostgresQuoteIdentifier(SPDumpText(sequence[12]))];
		}
	}
	if (![self _writeSection:section]) return NO;

	// 8. Views and materialized views, then the functions held back, then the domains' CHECK constraints (which may
	// call any of the functions; the tables using the domains are still empty)
	for (NSString *oid in orderedViews) {
		SPPostgresDumpRelation *relation = relations[oid];
		if (![self _writeSection:relation->parts[SPPostgresCreatePartTable]]) return NO;
	}
	if (![self _write:[heldBack componentsJoinedByString:@""]]) return NO;
	return [self _write:domainChecks];
}

/// INCREMENT BY … MINVALUE … MAXVALUE … START WITH … CACHE … [NO] CYCLE, each after prefix, joined by separator.
- (NSString *)_sequenceOptions:(NSArray *)sequence prefix:(NSString *)prefix separator:(NSString *)separator
{
	NSArray *options = @[
		[NSString stringWithFormat:@"INCREMENT BY %@", SPDumpText(sequence[5]) ?: @"1"],
		[NSString stringWithFormat:@"MINVALUE %@", SPDumpText(sequence[6]) ?: @"1"],
		[NSString stringWithFormat:@"MAXVALUE %@", SPDumpText(sequence[7]) ?: @"1"],
		[NSString stringWithFormat:@"START WITH %@", SPDumpText(sequence[4]) ?: @"1"],
		[NSString stringWithFormat:@"CACHE %@", SPDumpText(sequence[8]) ?: @"1"],
		SPDumpIsTrue(sequence[9]) ? @"CYCLE" : @"NO CYCLE"
	];
	NSMutableArray *prefixed = [NSMutableArray array];
	for (NSString *option in options) [prefixed addObject:[prefix stringByAppendingString:option]];
	return [prefixed componentsJoinedByString:separator];
}

/// Writes the types (the scope's rows); the domains' CHECK constraints are appended to domainChecks instead, for later.
- (BOOL)_writeTypes:(NSArray *)types versionNumber:(NSInteger)versionNumber domainChecks:(NSMutableString *)domainChecks error:(NSError **)error
{
	if (![types count]) return YES;

	NSMutableArray *oids = [NSMutableArray array];
	NSMutableDictionary *byOid = [NSMutableDictionary dictionary];
	for (NSArray *type in types) {
		[oids addObject:SPDumpText(type[0]) ?: @""];
		byOid[SPDumpText(type[0]) ?: @""] = type;
	}

	// What each type is made of (an array's element type for an array): a domain's base, a composite's attributes,
	// a range's subtype
	NSArray *uses = [self _rows:
		@"SELECT u.type::text, CASE WHEN ut.typelem <> 0 AND ut.typlen = -1 THEN ut.typelem ELSE ut.oid END::text"
		" FROM (SELECT t.oid AS type, t.typbasetype AS used FROM pg_catalog.pg_type t WHERE t.typbasetype <> 0"
		"   UNION SELECT t.oid, a.atttypid FROM pg_catalog.pg_type t JOIN pg_catalog.pg_attribute a ON a.attrelid = t.typrelid AND a.attnum > 0 AND NOT a.attisdropped"
		"   UNION SELECT r.rngtypid, r.rngsubtype FROM pg_catalog.pg_range r) u"
		" JOIN pg_catalog.pg_type ut ON ut.oid = u.used"
		" WHERE u.type IN (SELECT pg_catalog.json_array_elements_text($1::json)::oid)" values:@[SPDumpJSON(oids)] error:error];
	if (!uses) return NO;
	NSMutableDictionary *dependencies = [NSMutableDictionary dictionary];
	for (NSArray *row in uses) {
		NSString *type = SPDumpText(row[0]);
		if (!dependencies[type]) dependencies[type] = [NSMutableSet set];
		[dependencies[type] addObject:SPDumpText(row[1]) ?: @""];
	}
	// Enums first, then ranges, then domains and composites, each after what it uses
	NSMutableArray *grouped = [NSMutableArray array];
	for (NSArray *kinds in @[@[@"e"], @[@"r"], @[@"d", @"c"]]) {
		for (NSString *oid in oids) if ([kinds containsObject:byOid[oid][3]]) [grouped addObject:oid];
	}
	NSArray *ordered = SPDumpSorted(grouped, dependencies);

	NSMutableString *section = [NSMutableString string];
	for (NSString *oid in ordered) {
		NSArray *type = byOid[oid];
		NSString *name = SPDumpQualified(SPDumpText(type[1]), SPDumpText(type[2]));
		NSString *kind = SPDumpText(type[3]);
		if ([kind isEqualToString:@"e"]) {
			NSArray *labels = [self _rows:@"SELECT e.enumlabel::text FROM pg_catalog.pg_enum e WHERE e.enumtypid = $1::oid ORDER BY e.enumsortorder" values:@[oid] error:error];
			if (!labels) return NO;
			NSMutableArray *quoted = [NSMutableArray array];
			for (NSArray *label in labels) [quoted addObject:SPPostgresQuoteLiteral(SPDumpText(label[0]))];
			[section appendFormat:@"CREATE TYPE %@ AS ENUM (%@);\n\n", name, [quoted componentsJoinedByString:@", "]];
		}
		else if ([kind isEqualToString:@"c"]) {
			NSArray *attributes = [self _rows:
				@"SELECT a.attname::text, pg_catalog.format_type(a.atttypid, a.atttypmod)::text,"
				" CASE WHEN a.attcollation <> 0 AND a.attcollation <> at.typcollation THEN pg_catalog.quote_ident(cn.nspname) || '.' || pg_catalog.quote_ident(co.collname) END::text"
				" FROM pg_catalog.pg_type t JOIN pg_catalog.pg_attribute a ON a.attrelid = t.typrelid"
				" JOIN pg_catalog.pg_type at ON at.oid = a.atttypid"
				" LEFT JOIN pg_catalog.pg_collation co ON co.oid = a.attcollation LEFT JOIN pg_catalog.pg_namespace cn ON cn.oid = co.collnamespace"
				" WHERE t.oid = $1::oid AND a.attnum > 0 AND NOT a.attisdropped ORDER BY a.attnum" values:@[oid] error:error];
			if (!attributes) return NO;
			NSMutableArray *lines = [NSMutableArray array];
			for (NSArray *attribute in attributes) {
				NSMutableString *line = [NSMutableString stringWithFormat:@"%@ %@", SPPostgresQuoteIdentifier(SPDumpText(attribute[0]) ?: @""), SPDumpText(attribute[1]) ?: @""];
				if (SPDumpText(attribute[2])) [line appendFormat:@" COLLATE %@", SPDumpText(attribute[2])];
				[lines addObject:line];
			}
			[section appendFormat:@"CREATE TYPE %@ AS (\n    %@\n);\n\n", name, [lines componentsJoinedByString:@",\n    "]];
		}
		else if ([kind isEqualToString:@"r"]) {
			NSString *rangeSQL = [NSString stringWithFormat:
				@"SELECT pg_catalog.format_type(r.rngsubtype, NULL)::text,"
				" CASE WHEN r.rngsubdiff <> 0 THEN r.rngsubdiff::pg_catalog.regproc::text END,"
				" CASE WHEN NOT opc.opcdefault THEN pg_catalog.quote_ident(opn.nspname) || '.' || pg_catalog.quote_ident(opc.opcname) END::text,"
				" CASE WHEN r.rngcollation <> 0 AND r.rngcollation <> st.typcollation THEN pg_catalog.quote_ident(cn.nspname) || '.' || pg_catalog.quote_ident(co.collname) END::text,"
				" %@"
				" FROM pg_catalog.pg_range r JOIN pg_catalog.pg_type st ON st.oid = r.rngsubtype"
				" JOIN pg_catalog.pg_opclass opc ON opc.oid = r.rngsubopc JOIN pg_catalog.pg_namespace opn ON opn.oid = opc.opcnamespace"
				" LEFT JOIN pg_catalog.pg_collation co ON co.oid = r.rngcollation LEFT JOIN pg_catalog.pg_namespace cn ON cn.oid = co.collnamespace"
				" WHERE r.rngtypid = $1::oid",
				versionNumber >= 140000 ? @"(SELECT pg_catalog.quote_ident(mn.nspname) || '.' || pg_catalog.quote_ident(mt.typname) FROM pg_catalog.pg_type mt JOIN pg_catalog.pg_namespace mn ON mn.oid = mt.typnamespace WHERE mt.oid = r.rngmultitypid)::text" : @"NULL::text"];
			NSArray *ranges = [self _rows:rangeSQL values:@[oid] error:error];
			if (!ranges) return NO;
			if (![ranges count]) continue;
			NSArray *range = ranges[0];
			NSMutableArray *options = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"SUBTYPE = %@", SPDumpText(range[0]) ?: @""]];
			if (SPDumpText(range[2])) [options addObject:[NSString stringWithFormat:@"SUBTYPE_OPCLASS = %@", SPDumpText(range[2])]];
			if (SPDumpText(range[3])) [options addObject:[NSString stringWithFormat:@"COLLATION = %@", SPDumpText(range[3])]];
			if (SPDumpText(range[1])) [options addObject:[NSString stringWithFormat:@"SUBTYPE_DIFF = %@", SPDumpText(range[1])]];
			if (SPDumpText(range[4])) [options addObject:[NSString stringWithFormat:@"MULTIRANGE_TYPE_NAME = %@", SPDumpText(range[4])]];
			[section appendFormat:@"CREATE TYPE %@ AS RANGE (\n    %@\n);\n\n", name, [options componentsJoinedByString:@",\n    "]];
		}
		else if ([kind isEqualToString:@"d"]) {
			NSArray *domains = [self _rows:
				@"SELECT pg_catalog.format_type(t.typbasetype, t.typtypmod)::text, pg_catalog.pg_get_expr(t.typdefaultbin, 0)::text, t.typnotnull::text,"
				" CASE WHEN t.typcollation <> 0 AND t.typcollation <> bt.typcollation THEN pg_catalog.quote_ident(cn.nspname) || '.' || pg_catalog.quote_ident(co.collname) END::text"
				" FROM pg_catalog.pg_type t JOIN pg_catalog.pg_type bt ON bt.oid = t.typbasetype"
				" LEFT JOIN pg_catalog.pg_collation co ON co.oid = t.typcollation LEFT JOIN pg_catalog.pg_namespace cn ON cn.oid = co.collnamespace"
				" WHERE t.oid = $1::oid" values:@[oid] error:error];
			if (!domains) return NO;
			if (![domains count]) continue;
			NSArray *domain = domains[0];
			NSMutableString *create = [NSMutableString stringWithFormat:@"CREATE DOMAIN %@ AS %@", name, SPDumpText(domain[0]) ?: @""];
			if (SPDumpText(domain[3])) [create appendFormat:@" COLLATE %@", SPDumpText(domain[3])];
			if (SPDumpText(domain[1])) [create appendFormat:@" DEFAULT %@", SPDumpText(domain[1])];
			if (SPDumpIsTrue(domain[2])) [create appendString:@" NOT NULL"];
			[section appendFormat:@"%@;\n\n", create];
			NSArray *checks = [self _rows:@"SELECT con.conname::text, pg_catalog.pg_get_constraintdef(con.oid)::text FROM pg_catalog.pg_constraint con"
							   " WHERE con.contypid = $1::oid AND con.contype = 'c' ORDER BY con.conname COLLATE \"C\"" values:@[oid] error:error];
			if (!checks) return NO;
			for (NSArray *check in checks) {
				[domainChecks appendFormat:@"ALTER DOMAIN %@ ADD CONSTRAINT %@ %@;\n\n", name, SPPostgresQuoteIdentifier(SPDumpText(check[0]) ?: @""), SPDumpText(check[1]) ?: @""];
			}
		}
	}
	return [self _write:section];
}

- (BOOL)_reportTable:(SPPostgresDumpRelation *)relation index:(NSUInteger)index count:(NSUInteger)count error:(NSError **)error
{
	if (!progress || progress(index, count, relation->name)) return YES;
	if (error) *error = [self _cancelledError];
	return NO;
}

#pragma mark Data (9–10)

- (BOOL)_writeDataForTables:(NSArray *)orderedTables relations:(NSDictionary *)relations relationsJSON:(NSString *)relationsJSON sequences:(NSArray *)sequences error:(NSError **)error
{
	// Referenced tables first (their partitions too), so the data also loads into existing tables with foreign keys
	NSArray *references = [self _rows:
		@"SELECT DISTINCT con.conrelid::text, t.relid::text FROM pg_catalog.pg_constraint con,"
		" LATERAL pg_catalog.pg_partition_tree(con.confrelid) t"
		" WHERE con.contype = 'f' AND con.conrelid IN (SELECT pg_catalog.json_array_elements_text($1::json)::oid)" values:@[relationsJSON] error:error];
	if (!references) return NO;
	NSMutableDictionary *dependencies = [NSMutableDictionary dictionary];
	for (NSArray *row in references) {
		NSString *table = SPDumpText(row[0]);
		if (!dependencies[table]) dependencies[table] = [NSMutableSet set];
		[dependencies[table] addObject:SPDumpText(row[1]) ?: @""];
	}
	NSArray *ordered = SPDumpSorted(orderedTables, dependencies);

	NSUInteger index = 0;
	for (NSString *oid in ordered) {
		SPPostgresDumpRelation *relation = relations[oid];
		index++;
		if (![self _reportTable:relation index:index count:[ordered count] error:error]) return NO;
		// Partitioned parents hold no rows (their partitions do); foreign tables' rows live elsewhere
		if (![relation->kind isEqualToString:@"r"]) continue;

		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		BOOL written = [self _writeDataOfTable:relation index:index count:[ordered count] error:error];
		if (!written && error) [*error retain];
		[pool drain];
		if (!written) {
			if (error) [*error autorelease];
			return NO;
		}
	}

	// 10. Sequence values, read a few hundred sequences per query (one round trip each)
	NSMutableArray *sequenceValues = [NSMutableArray arrayWithCapacity:[sequences count]];
	static const NSUInteger SPDumpSequencesPerQuery = 250;
	for (NSUInteger start = 0; start < [sequences count]; start += SPDumpSequencesPerQuery) {
		NSArray *batch = [sequences subarrayWithRange:NSMakeRange(start, MIN(SPDumpSequencesPerQuery, [sequences count] - start))];
		NSMutableArray *selects = [NSMutableArray arrayWithCapacity:[batch count]];
		[batch enumerateObjectsUsingBlock:^(NSArray *batchSequence, NSUInteger position, BOOL *stop) {
			[selects addObject:[NSString stringWithFormat:@"SELECT %lu AS i, last_value::text, is_called::text FROM %@", (unsigned long)position, SPDumpQualified(SPDumpText(batchSequence[1]), SPDumpText(batchSequence[2]))]];
		}];
		NSArray *rows = [self _rows:[[selects componentsJoinedByString:@" UNION ALL "] stringByAppendingString:@" ORDER BY 1"] values:nil error:error];
		if (!rows) return NO;
		for (NSArray *row in rows) [sequenceValues addObject:@[row[1], row[2]]];
	}
	NSMutableString *section = [NSMutableString string];
	NSUInteger sequenceIndex = 0;
	for (NSArray *sequence in sequences) {
		NSString *qualified = SPDumpQualified(SPDumpText(sequence[1]), SPDumpText(sequence[2]));
		NSArray *values = @[sequenceValues[sequenceIndex++]];
		NSString *target = SPPostgresQuoteLiteral(qualified);
		SPPostgresDumpRelation *owner = relations[SPDumpText(sequence[11]) ?: @""];
		if ([SPDumpText(sequence[10]) isEqualToString:@"i"]) {
			// The importing table names its identity sequence itself
			if (!owner || !SPDumpText(sequence[12])) continue;
			target = [NSString stringWithFormat:@"pg_catalog.pg_get_serial_sequence(%@, %@)", SPPostgresQuoteLiteral(SPDumpQualified(owner->schema, owner->name)), SPPostgresQuoteLiteral(SPDumpText(sequence[12]))];
		}
		[section appendFormat:@"SELECT pg_catalog.setval(%@, %@, %@);\n", target, SPDumpText(values[0][0]) ?: @"1", SPDumpIsTrue(values[0][1]) ? @"true" : @"false"];
	}
	return [self _writeSection:section];
}

/// Bytes of COPY data between two calls of progress inside one table's COPY.
static const NSUInteger SPDumpProgressInterval = 1024 * 1024;

- (BOOL)_writeDataOfTable:(SPPostgresDumpRelation *)relation index:(NSUInteger)index count:(NSUInteger)count error:(NSError **)error
{
	NSArray *quoted = relation->dataColumns ?: @[];
	NSString *target = SPDumpQualified(relation->schema, relation->name);
	if ([quoted count]) target = [NSString stringWithFormat:@"%@ (%@)", target, [quoted componentsJoinedByString:@", "]];

	// Loading into existing tables (a data-only dump): their user triggers are off while their rows load
	NSArray *triggers = @[];
	if (!includeStructure) {
		triggers = [self _rows:@"SELECT t.tgname::text, t.tgenabled::text FROM pg_catalog.pg_trigger t WHERE t.tgrelid = $1::oid AND NOT t.tgisinternal ORDER BY t.tgname COLLATE \"C\"" values:@[relation->oid] error:error];
		if (!triggers) return NO;
	}
	NSString *table = SPDumpQualified(relation->schema, relation->name);
	if ([triggers count] && ![self _write:[NSString stringWithFormat:@"ALTER TABLE %@ DISABLE TRIGGER USER;\n\n", table]]) return NO;

	if (![self _write:[NSString stringWithFormat:@"COPY %@ FROM stdin;\n", target]]) return NO;
	NSError *copyError = nil;
	__block NSUInteger sinceProgress = 0;
	__block BOOL cancelled = NO;
	BOOL (^tableProgress)(NSUInteger, NSUInteger, NSString *) = progress;
	NSString *tableName = relation->name;
	// Rows: one line each (a value's line breaks are escaped in COPY text)
	__block unsigned long long rows = 0;
	BOOL copied = [connection copyOut:[NSString stringWithFormat:@"COPY %@ TO STDOUT", target] handler:^BOOL(NSData *chunk) {
		if (![self _writeBytes:[chunk bytes] length:[chunk length]]) return NO;
		if (![self _flushIfDue:[chunk length] force:NO]) return NO;
		const char *bytes = [chunk bytes], *end = bytes + [chunk length];
		for (const char *cursor = bytes; cursor < end && (cursor = memchr(cursor, '\n', (size_t)(end - cursor))); cursor++) rows++;
		// A long table can be cancelled during its COPY: progress is asked again every SPDumpProgressInterval bytes
		sinceProgress += [chunk length];
		if (tableProgress && sinceProgress >= SPDumpProgressInterval) {
			sinceProgress = 0;
			if (!tableProgress(index, count, tableName)) {
				cancelled = YES;
				return NO;
			}
		}
		return YES;
	} error:&copyError];
	if (!copied) {
		if (error) {
			if (cancelled) *error = [self _cancelledError];
			else if (writeError) *error = [[writeError retain] autorelease];
			else *error = SPPostgresMakeError(SPPostgresErrorQueryFailed, [copyError localizedDescription] ?: NSLocalizedString(@"The export failed.", @"Postgres export: unknown failure"), nil);
		}
		return NO;
	}
	// The end of the data: not an item
	if (![self _writeBytes:"\\.\n\n" length:4]) return NO;
	if (![self _flushIfDue:4 force:YES]) return NO;
	[countLock lock];
	[copyRowCounts addObject:@(rows)];
	[copyTableNames addObject:table];
	[countLock unlock];

	if ([triggers count]) {
		NSMutableString *enable = [NSMutableString stringWithFormat:@"ALTER TABLE %@ ENABLE TRIGGER USER;\n", table];
		NSDictionary *states = @{@"D": @"DISABLE TRIGGER", @"R": @"ENABLE REPLICA TRIGGER", @"A": @"ENABLE ALWAYS TRIGGER"};
		for (NSArray *trigger in triggers) {
			NSString *state = states[SPDumpText(trigger[1]) ?: @""];
			if (state) [enable appendFormat:@"ALTER TABLE %@ %@ %@;\n", table, state, SPPostgresQuoteIdentifier(SPDumpText(trigger[0]) ?: @"")];
		}
		if (![self _writeSection:enable]) return NO;
	}
	return YES;
}

#pragma mark Structure after the data (11–12)

- (BOOL)_writeStructureAfterDataWithRelations:(NSDictionary *)relations tables:(NSArray *)orderedTables views:(NSArray *)orderedViews error:(NSError **)error
{
	NSArray *all = [orderedTables arrayByAddingObjectsFromArray:orderedViews];
	for (NSString *key in @[SPPostgresCreatePartIndexes, SPPostgresCreatePartForeignKeys, SPPostgresCreatePartTriggers]) {
		for (NSString *oid in all) {
			SPPostgresDumpRelation *relation = relations[oid];
			if (![self _writeSection:relation->parts[key]]) return NO;
		}
	}
	NSMutableString *section = [NSMutableString string];
	for (NSString *oid in orderedViews) {
		SPPostgresDumpRelation *relation = relations[oid];
		if ([relation->kind isEqualToString:@"m"] && relation->populated) [section appendFormat:@"REFRESH MATERIALIZED VIEW %@;\n", SPDumpQualified(relation->schema, relation->name)];
	}
	return [self _writeSection:section];
}

- (BOOL)_writeCommentsWithScope:(SPPostgresDumpScope *)scope error:(NSError **)error
{
	NSMutableString *section = [NSMutableString string];

	// Schemas (public's only when it isn't the server's own)
	NSArray *rows = [self _rows:@"SELECT n.nspname::text, pg_catalog.obj_description(n.oid, 'pg_namespace')::text FROM pg_catalog.pg_namespace n"
					 " WHERE n.nspname IN (SELECT pg_catalog.json_array_elements_text($1::json)) ORDER BY n.nspname COLLATE \"C\"" values:@[SPDumpJSON(scope->schemaNames)] error:error];
	if (!rows) return NO;
	for (NSArray *row in rows) {
		NSString *comment = SPDumpText(row[1]);
		if (!comment || ([SPDumpText(row[0]) isEqualToString:@"public"] && [comment isEqualToString:@"standard public schema"])) continue;
		[section appendFormat:@"COMMENT ON SCHEMA %@ IS %@;\n", SPPostgresQuoteIdentifier(SPDumpText(row[0]) ?: @""), SPPostgresQuoteLiteral(comment)];
	}

	if ([scope->types count] || [scope->routines count]) {
		// Types and functions
		NSMutableArray *typeOids = [NSMutableArray array];
		for (NSArray *type in scope->types) [typeOids addObject:SPDumpText(type[0]) ?: @""];
		NSMutableArray *routineOids = [NSMutableArray array];
		for (NSArray *routine in scope->routines) [routineOids addObject:SPDumpText(routine[0]) ?: @""];
		NSString *sql = 
			@"SELECT kind, name, comment FROM (SELECT CASE t.typtype WHEN 'd' THEN 'DOMAIN' ELSE 'TYPE' END AS kind, pg_catalog.quote_ident(n.nspname) || '.' || pg_catalog.quote_ident(t.typname) AS name,"
			"  pg_catalog.obj_description(t.oid, 'pg_type')::text AS comment"
			" FROM pg_catalog.pg_type t JOIN pg_catalog.pg_namespace n ON n.oid = t.typnamespace"
			" WHERE t.oid IN (SELECT pg_catalog.json_array_elements_text($1::json)::oid)"
			" AND pg_catalog.obj_description(t.oid, 'pg_type') IS NOT NULL"
			" UNION ALL"
			" SELECT CASE p.prokind WHEN 'p' THEN 'PROCEDURE' ELSE 'FUNCTION' END,"
			"  pg_catalog.quote_ident(n.nspname) || '.' || pg_catalog.quote_ident(p.proname) || '(' || pg_catalog.pg_get_function_identity_arguments(p.oid) || ')',"
			"  pg_catalog.obj_description(p.oid, 'pg_proc')::text"
			" FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace"
			" WHERE p.oid IN (SELECT pg_catalog.json_array_elements_text($2::json)::oid)"
			" AND pg_catalog.obj_description(p.oid, 'pg_proc') IS NOT NULL"
			") s ORDER BY name COLLATE \"C\"";
		rows = [self _rows:sql values:@[SPDumpJSON(typeOids), SPDumpJSON(routineOids)] error:error];
		if (!rows) return NO;
		for (NSArray *row in rows) {
			[section appendFormat:@"COMMENT ON %@ %@ IS %@;\n", SPDumpText(row[0]) ?: @"", SPDumpText(row[1]) ?: @"", SPPostgresQuoteLiteral(SPDumpText(row[2]))];
		}
	}

	// Sequences (not identity ones: the importing table names those itself)
	for (NSArray *sequence in scope->sequences) {
		NSString *comment = SPDumpText(sequence[13]);
		if (!comment || [SPDumpText(sequence[10]) isEqualToString:@"i"]) continue;
		[section appendFormat:@"COMMENT ON SEQUENCE %@ IS %@;\n", SPDumpQualified(SPDumpText(sequence[1]), SPDumpText(sequence[2])), SPPostgresQuoteLiteral(comment)];
	}
	return [self _writeSection:section];
}

@end
