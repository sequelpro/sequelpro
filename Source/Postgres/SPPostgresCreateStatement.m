#import "SPPostgresCreateStatement.h"
#import "SPPostgresTableData.h"
#import "SPPostgresErrors.h"
#import <PostgresKit/PostgresKit.h>

/// The value as an NSString, or nil for NULL.
static NSString *SPPostgresCreateText(id value)
{
	return [value isKindOfClass:[NSString class]] ? value : nil;
}

static BOOL SPPostgresCreateIsTrue(id value)
{
	return [SPPostgresCreateText(value) isEqualToString:@"true"];
}

/// A json_agg as an NSArray (empty for NULL).
static NSArray *SPPostgresCreateJSONArray(id value)
{
	NSString *text = SPPostgresCreateText(value);
	if (!text) return @[];
	id array = [NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
	return [array isKindOfClass:[NSArray class]] ? array : @[];
}

/// Every row of the query as arrays of NSString / NSNull (the query selects text), or nil on failure.
static NSArray *SPPostgresCreateRows(PGPostgresConnection *connection, NSString *sql, NSArray *values, NSError **error)
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

/// "schema"."name"
static NSString *SPPostgresCreateQualified(NSString *schema, NSString *name)
{
	return [NSString stringWithFormat:@"%@.%@", SPPostgresQuoteIdentifier(schema ?: @""), SPPostgresQuoteIdentifier(name ?: @"")];
}

/// The text without trailing whitespace and semicolons (pg_get_viewdef ends with one).
static NSString *SPPostgresCreateWithoutTerminator(NSString *text)
{
	NSCharacterSet *trailing = [NSCharacterSet characterSetWithCharactersInString:@" \t\r\n;"];
	NSUInteger end = [text length];
	while (end > 0 && [trailing characterIsMember:[text characterAtIndex:end - 1]]) end--;
	return [text substringToIndex:end];
}

/// The statements, each ended by `;`, separated by blank lines; @"" for none.
static NSString *SPPostgresCreateJoined(NSArray *statements)
{
	if (![statements count]) return @"";
	return [[statements componentsJoinedByString:@";\n\n"] stringByAppendingString:@";\n"];
}

NSString * const SPPostgresCreatePartTable = @"SPPostgresCreatePartTable";
NSString * const SPPostgresCreatePartIndexes = @"SPPostgresCreatePartIndexes";
NSString * const SPPostgresCreatePartForeignKeys = @"SPPostgresCreatePartForeignKeys";
NSString * const SPPostgresCreatePartTriggers = @"SPPostgresCreatePartTriggers";

@implementation SPPostgresCreateStatement

+ (NSString *)createStatementForTable:(NSString *)table inSchema:(NSString *)schema connection:(PGPostgresConnection *)connection error:(NSError **)error
{
	NSDictionary *parts = [self _partsForTable:table inSchema:schema materializedViewWithNoData:NO connection:connection error:error];
	return parts ? SPPostgresCreateJoined(parts[@"all"]) : nil;
}

+ (NSDictionary *)partsForTable:(NSString *)table inSchema:(NSString *)schema connection:(PGPostgresConnection *)connection error:(NSError **)error
{
	return [self partsForTable:table inSchema:schema materializedViewWithNoData:NO connection:connection error:error];
}

+ (NSDictionary *)partsForTable:(NSString *)table inSchema:(NSString *)schema materializedViewWithNoData:(BOOL)noData connection:(PGPostgresConnection *)connection error:(NSError **)error
{
	NSDictionary *parts = [self _partsForTable:table inSchema:schema materializedViewWithNoData:noData connection:connection error:error];
	if (!parts) return nil;
	return @{
		SPPostgresCreatePartTable: SPPostgresCreateJoined(parts[SPPostgresCreatePartTable]),
		SPPostgresCreatePartIndexes: SPPostgresCreateJoined(parts[SPPostgresCreatePartIndexes]),
		SPPostgresCreatePartForeignKeys: SPPostgresCreateJoined(parts[SPPostgresCreatePartForeignKeys]),
		SPPostgresCreatePartTriggers: SPPostgresCreateJoined(parts[SPPostgresCreatePartTriggers])
	};
}

/// @"all" (every statement, in createStatementForTable:'s order) and the four parts, as arrays of statements
/// without their `;`; nil on failure.
+ (NSDictionary *)_partsForTable:(NSString *)table inSchema:(NSString *)schema materializedViewWithNoData:(BOOL)noData connection:(PGPostgresConnection *)connection error:(NSError **)error
{
	NSArray *key = @[schema ?: @"", table ?: @""];
	NSDictionary *all = [self _partsForTables:@[key] materializedViewWithNoData:noData connection:connection error:error];
	return all ? all[key] : nil;
}

+ (NSDictionary *)partsForTables:(NSArray *)tables materializedViewWithNoData:(BOOL)noData connection:(PGPostgresConnection *)connection error:(NSError **)error
{
	NSDictionary *all = [self _partsForTables:tables materializedViewWithNoData:noData connection:connection error:error];
	if (!all) return nil;
	NSMutableDictionary *joined = [NSMutableDictionary dictionaryWithCapacity:[all count]];
	for (NSArray *key in all) {
		NSDictionary *parts = all[key];
		joined[key] = @{
			SPPostgresCreatePartTable: SPPostgresCreateJoined(parts[SPPostgresCreatePartTable]),
			SPPostgresCreatePartIndexes: SPPostgresCreateJoined(parts[SPPostgresCreatePartIndexes]),
			SPPostgresCreatePartForeignKeys: SPPostgresCreateJoined(parts[SPPostgresCreatePartForeignKeys]),
			SPPostgresCreatePartTriggers: SPPostgresCreateJoined(parts[SPPostgresCreatePartTriggers])
		};
	}
	return joined;
}

/// -_partsForTable:… for every @[schema, table] pair at once: each catalog query runs once for them all.
+ (NSDictionary *)_partsForTables:(NSArray *)tables materializedViewWithNoData:(BOOL)noData connection:(PGPostgresConnection *)connection error:(NSError **)error
{
	NSString *aborted = NSLocalizedString(@"The current transaction is aborted, so the CREATE statement can't be read. Roll it back first (ROLLBACK in the Query view).", @"Postgres create statement: inside an aborted transaction");

	__block NSDictionary *statement = nil;
	BOOL read = SPPostgresRunAtomically(connection, @"sp_create_statement", aborted, ^BOOL(NSError **bodyError) {
		// An empty search_path (as pg_dump's) has the server qualify every name outside pg_catalog. It is set with
		// SET LOCAL and back to its previous value before the end (inside the user's transaction it would last to
		// the end of theirs; a failure undoes it with the savepoint).
		PGPostgresResult *previous = SPPostgresExecute(connection, @"SELECT pg_catalog.current_setting('search_path')::text", nil, bodyError);
		if (!previous) return NO;
		NSString *previousValue = SPPostgresCreateText([previous textValueAtRow:0 column:0]) ?: @"";

		NSString *set = @"SELECT pg_catalog.set_config('search_path', $1::text, true)";
		if (!SPPostgresExecute(connection, set, @[@""], bodyError)) return NO;
		NSDictionary *result = [self _statementsForTables:tables materializedViewWithNoData:noData connection:connection error:bodyError];
		if (!result) return NO;
		if (!SPPostgresExecute(connection, set, @[previousValue], bodyError)) return NO;
		statement = result; // autoreleased in this pool, which outlives the block
		return YES;
	}, error);

	return read ? statement : nil;
}

/// Rows of a query whose first column is a relation's oid, grouped by it (each row without that column), in order.
static NSDictionary *SPPostgresCreateRowsByOid(PGPostgresConnection *connection, NSString *sql, NSString *oids, NSError **error)
{
	NSArray *rows = SPPostgresCreateRows(connection, sql, @[oids], error);
	if (!rows) return nil;
	NSMutableDictionary *grouped = [NSMutableDictionary dictionary];
	for (NSArray *row in rows) {
		NSString *oid = SPPostgresCreateText(row[0]) ?: @"";
		NSMutableArray *group = grouped[oid];
		if (!group) grouped[oid] = group = [NSMutableArray array];
		[group addObject:[row subarrayWithRange:NSMakeRange(1, [row count] - 1)]];
	}
	return grouped;
}

/// The statements of every @[schema, table] pair, keyed by the pair: each catalog query runs once for them all (their
/// oids as a $1 array), then each relation's statements are built from its rows.
+ (NSDictionary *)_statementsForTables:(NSArray *)tables materializedViewWithNoData:(BOOL)noData connection:(PGPostgresConnection *)connection error:(NSError **)error
{
	if (![tables count]) return @{};
	NSMutableArray *pairs = [NSMutableArray arrayWithCapacity:[tables count]];
	for (NSArray *pair in tables) [pairs addObject:@[pair[0] ?: @"", pair[1] ?: @""]];
	NSData *json = [NSJSONSerialization dataWithJSONObject:pairs options:0 error:NULL];
	NSString *pairsJSON = json ? [[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] autorelease] : @"[]";

	NSArray *relationRows = SPPostgresCreateRows(connection,
		@"SELECT n.nspname::text, c.relname::text, c.oid::text, c.relkind::text, c.relpersistence::text, c.relispartition::text,"
		" pg_catalog.array_to_string(c.reloptions, ', ')::text,"
		" CASE WHEN c.relkind = 'p' THEN pg_catalog.pg_get_partkeydef(c.oid) END::text,"
		" CASE WHEN c.relispartition THEN pg_catalog.pg_get_expr(c.relpartbound, c.oid) END::text,"
		" (SELECT pg_catalog.json_agg(pg_catalog.json_build_array(pn.nspname::text, pc.relname::text) ORDER BY i.inhseqno)"
		"   FROM pg_catalog.pg_inherits i JOIN pg_catalog.pg_class pc ON pc.oid = i.inhparent"
		"   JOIN pg_catalog.pg_namespace pn ON pn.oid = pc.relnamespace WHERE i.inhrelid = c.oid)::text,"
		" pg_catalog.obj_description(c.oid, 'pg_class')::text,"
		" CASE WHEN c.relkind IN ('v', 'm') THEN pg_catalog.pg_get_viewdef(c.oid, true) END::text,"
		" c.relispopulated::text, pg_catalog.current_setting('server_version_num')::text,"
		" (SELECT fs.srvname::text FROM pg_catalog.pg_foreign_table ft JOIN pg_catalog.pg_foreign_server fs ON fs.oid = ft.ftserver WHERE ft.ftrelid = c.oid),"
		" (SELECT pg_catalog.json_agg(o.option_name || ' ' || pg_catalog.quote_literal(o.option_value))"
		"   FROM pg_catalog.pg_foreign_table ft, pg_catalog.pg_options_to_table(ft.ftoptions) o WHERE ft.ftrelid = c.oid)::text"
		" FROM pg_catalog.json_array_elements($1::json) e"
		" JOIN pg_catalog.pg_namespace n ON n.nspname = (e->>0)"
		" JOIN pg_catalog.pg_class c ON c.relnamespace = n.oid AND c.relname = (e->>1)", @[pairsJSON], error);
	if (!relationRows) return nil;
	NSMutableDictionary *relations = [NSMutableDictionary dictionary];
	NSMutableArray *oids = [NSMutableArray array];
	NSInteger serverVersion = 0;
	for (NSArray *row in relationRows) {
		NSArray *key = @[SPPostgresCreateText(row[0]) ?: @"", SPPostgresCreateText(row[1]) ?: @""];
		NSArray *relation = [row subarrayWithRange:NSMakeRange(2, [row count] - 2)];
		relations[key] = relation;
		[oids addObject:SPPostgresCreateText(relation[0]) ?: @"0"];
		serverVersion = [SPPostgresCreateText(relation[11]) integerValue];
	}
	for (NSArray *pair in pairs) {
		if (relations[pair]) continue;
		if (error) *error = SPPostgresMakeError(SPPostgresErrorQueryFailed, [NSString stringWithFormat:NSLocalizedString(@"There is no table “%@” in schema “%@”.", @"Postgres structure: no such relation"), pair[1], pair[0]], nil);
		return nil;
	}
	NSString *oidArray = [NSString stringWithFormat:@"{%@}", [oids componentsJoinedByString:@","]];

	// The columns (also for views: their comments)
	NSDictionary *columns = SPPostgresCreateRowsByOid(connection,
		@"SELECT a.attrelid::text, a.attname::text, pg_catalog.format_type(a.atttypid, a.atttypmod)::text, a.attnotnull::text,"
		" pg_catalog.pg_get_expr(d.adbin, d.adrelid)::text, a.attidentity::text, a.attgenerated::text,"
		" CASE WHEN a.attcollation <> 0 AND a.attcollation <> t.typcollation THEN cn.nspname END::text,"
		" CASE WHEN a.attcollation <> 0 AND a.attcollation <> t.typcollation THEN co.collname END::text,"
		" pg_catalog.col_description(a.attrelid, a.attnum)::text, a.attislocal::text, a.attnum::text"
		" FROM pg_catalog.pg_attribute a JOIN pg_catalog.pg_type t ON t.oid = a.atttypid"
		" LEFT JOIN pg_catalog.pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum"
		" LEFT JOIN pg_catalog.pg_collation co ON co.oid = a.attcollation"
		" LEFT JOIN pg_catalog.pg_namespace cn ON cn.oid = co.collnamespace"
		" WHERE a.attrelid = ANY ($1::oid[]) AND a.attnum > 0 AND NOT a.attisdropped ORDER BY a.attrelid, a.attnum", oidArray, error);
	if (!columns) return nil;
	NSDictionary *constraints = SPPostgresCreateRowsByOid(connection,
		@"SELECT con.conrelid::text, con.conname::text, pg_catalog.pg_get_constraintdef(con.oid)::text, con.convalidated::text, con.contype::text"
		" FROM pg_catalog.pg_constraint con WHERE con.conrelid = ANY ($1::oid[]) AND con.contype IN ('p', 'u', 'c', 'f', 'x') AND con.conislocal"
		" ORDER BY con.conrelid, CASE con.contype WHEN 'p' THEN 0 WHEN 'u' THEN 1 WHEN 'c' THEN 2 WHEN 'x' THEN 3 ELSE 4 END, con.conname COLLATE \"C\"", oidArray, error);
	if (!constraints) return nil;
	// PostgreSQL 18's NOT NULL constraints (contype 'n'; none before), by attnum: their name, NO INHERIT and
	// NOT VALID, which attnotnull alone doesn't tell
	NSDictionary *notNulls = SPPostgresCreateRowsByOid(connection,
		@"SELECT con.conrelid::text, con.conkey[1]::text, con.conname::text, pg_catalog.pg_get_constraintdef(con.oid)::text, con.connoinherit::text, con.convalidated::text"
		" FROM pg_catalog.pg_constraint con WHERE con.conrelid = ANY ($1::oid[]) AND con.contype = 'n' AND con.conislocal", oidArray, error);
	if (!notNulls) return nil;
	// Indexes backing no constraint; a partition's copies of its parent's indexes come with PARTITION OF
	NSDictionary *indexes = SPPostgresCreateRowsByOid(connection,
		@"SELECT i.indrelid::text, pg_catalog.pg_get_indexdef(i.indexrelid)::text, pg_catalog.quote_ident(ic.relname)::text"
		" FROM pg_catalog.pg_index i JOIN pg_catalog.pg_class ic ON ic.oid = i.indexrelid"
		" WHERE i.indrelid = ANY ($1::oid[])"
		" AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_constraint con WHERE con.conindid = i.indexrelid AND con.conrelid = i.indrelid AND con.contype IN ('p', 'u', 'x'))"
		" AND NOT EXISTS (SELECT 1 FROM pg_catalog.pg_inherits ih WHERE ih.inhrelid = i.indexrelid)"
		" ORDER BY i.indrelid, ic.relname COLLATE \"C\"", oidArray, error);
	if (!indexes) return nil;
	// Triggers: not the internal ones (a foreign key's), nor, from PostgreSQL 13 (tgparentid), a partition's
	// copies of its parent's (internal before 15)
	NSDictionary *triggers = SPPostgresCreateRowsByOid(connection, [NSString stringWithFormat:
		@"SELECT t.tgrelid::text, pg_catalog.pg_get_triggerdef(t.oid)::text, t.tgenabled::text, t.tgname::text"
		" FROM pg_catalog.pg_trigger t WHERE t.tgrelid = ANY ($1::oid[]) AND NOT t.tgisinternal%@"
		" ORDER BY t.tgrelid, t.tgname COLLATE \"C\"", serverVersion >= 130000 ? @" AND t.tgparentid = 0" : @""], oidArray, error);
	if (!triggers) return nil;

	NSMutableDictionary *statements = [NSMutableDictionary dictionaryWithCapacity:[pairs count]];
	for (NSArray *pair in pairs) {
		NSArray *relation = relations[pair];
		NSString *oid = SPPostgresCreateText(relation[0]) ?: @"";
		NSDictionary *built = [self _statementForTable:pair[1] inSchema:pair[0] relation:relation columns:columns[oid] ?: @[]
										  constraints:constraints[oid] ?: @[] notNulls:notNulls[oid] ?: @[] indexes:indexes[oid] ?: @[]
											 triggers:triggers[oid] ?: @[] materializedViewWithNoData:noData error:error];
		if (!built) return nil;
		statements[pair] = built;
	}
	return statements;
}

/// One relation's statements, from its catalog rows (as the queries above select them, without the oid column).
+ (NSDictionary *)_statementForTable:(NSString *)table inSchema:(NSString *)schema relation:(NSArray *)relation columns:(NSArray *)columns
						 constraints:(NSArray *)constraints notNulls:(NSArray *)notNullRows indexes:(NSArray *)indexes
							triggers:(NSArray *)triggers materializedViewWithNoData:(BOOL)noData error:(NSError **)error
{
	NSString *relkind = SPPostgresCreateText(relation[1]) ?: @"";
	BOOL unlogged = [SPPostgresCreateText(relation[2]) isEqualToString:@"u"];
	BOOL isPartition = SPPostgresCreateIsTrue(relation[3]);
	NSString *options = SPPostgresCreateText(relation[4]);
	NSString *partitionKey = SPPostgresCreateText(relation[5]);
	NSString *partitionBound = SPPostgresCreateText(relation[6]);
	NSArray *parents = SPPostgresCreateJSONArray(relation[7]);
	NSString *tableComment = SPPostgresCreateText(relation[8]);
	NSString *viewDefinition = SPPostgresCreateText(relation[9]);
	BOOL populated = SPPostgresCreateIsTrue(relation[10]);
	NSString *foreignServer = SPPostgresCreateText(relation[12]);
	NSArray *foreignOptions = SPPostgresCreateJSONArray(relation[13]);

	NSDictionary *keywords = @{@"r": @"TABLE", @"p": @"TABLE", @"v": @"VIEW", @"m": @"MATERIALIZED VIEW", @"f": @"FOREIGN TABLE"};
	NSString *keyword = keywords[relkind];
	if (!keyword) {
		if (error) *error = SPPostgresMakeError(SPPostgresErrorQueryFailed, [NSString stringWithFormat:NSLocalizedString(@"“%@” is not a table or view.", @"Postgres structure: unsupported relation kind"), table], nil);
		return nil;
	}

	NSString *name = SPPostgresCreateQualified(schema, table);
	NSMutableArray *statements = [NSMutableArray array]; // everything, in createStatementForTable:'s order
	NSMutableArray *tablePart = [NSMutableArray array];
	NSMutableArray *indexPart = [NSMutableArray array];
	NSMutableArray *foreignKeyPart = [NSMutableArray array];
	NSMutableArray *triggerPart = [NSMutableArray array];


	BOOL isView = [relkind isEqualToString:@"v"] || [relkind isEqualToString:@"m"];

	if (isView) {
		NSMutableString *create = [NSMutableString stringWithFormat:@"CREATE %@ %@", keyword, name];
		NSMutableArray *withOptions = [NSMutableArray array];
		NSString *checkOption = nil;
		for (NSString *option in [options length] ? [options componentsSeparatedByString:@", "] : @[]) {
			if ([option hasPrefix:@"check_option="]) checkOption = [[option substringFromIndex:[@"check_option=" length]] uppercaseString];
			else [withOptions addObject:option];
		}
		if ([withOptions count]) [create appendFormat:@" WITH (%@)", [withOptions componentsJoinedByString:@", "]];
		[create appendFormat:@" AS\n%@", SPPostgresCreateWithoutTerminator(viewDefinition ?: @"")];
		if (checkOption) [create appendFormat:@"\nWITH %@ CHECK OPTION", checkOption];
		if ([relkind isEqualToString:@"m"] && !populated) [create appendString:@"\nWITH NO DATA"];
		[statements addObject:create];
		if ([relkind isEqualToString:@"m"] && populated && noData) [tablePart addObject:[create stringByAppendingString:@"\nWITH NO DATA"]];
		else [tablePart addObject:create];
	}
	else {
		NSMutableDictionary *notNulls = [NSMutableDictionary dictionary];
		for (NSArray *row in notNullRows) {
			if (SPPostgresCreateText(row[0])) notNulls[SPPostgresCreateText(row[0])] = row;
		}

		NSMutableArray *lines = [NSMutableArray array];
		NSMutableArray *linesWithoutForeignKeys = [NSMutableArray array];
		NSMutableArray *notValid = [NSMutableArray array];

		// A partition's columns are its parent's; an inheritance child's inherited ones, its parents'
		if (!isPartition) {
			for (NSArray *column in columns) {
				if (!SPPostgresCreateIsTrue(column[9])) continue; // inherited only (attislocal false)
				NSMutableString *line = [NSMutableString stringWithFormat:@"%@ %@", SPPostgresQuoteIdentifier(SPPostgresCreateText(column[0]) ?: @""), SPPostgresCreateText(column[1]) ?: @""];

				NSString *collationSchema = SPPostgresCreateText(column[6]);
				NSString *collation = SPPostgresCreateText(column[7]);
				if (collation) {
					if ([collationSchema isEqualToString:@"pg_catalog"]) [line appendFormat:@" COLLATE %@", SPPostgresQuoteIdentifier(collation)];
					else [line appendFormat:@" COLLATE %@", SPPostgresCreateQualified(collationSchema, collation)];
				}

				NSString *expression = SPPostgresCreateText(column[3]);
				NSString *identity = SPPostgresCreateText(column[4]) ?: @"";
				NSString *generated = SPPostgresCreateText(column[5]) ?: @"";
				if ([generated isEqualToString:@"s"]) [line appendFormat:@" GENERATED ALWAYS AS (%@) STORED", expression ?: @""];
				else if ([generated isEqualToString:@"v"]) [line appendFormat:@" GENERATED ALWAYS AS (%@) VIRTUAL", expression ?: @""];
				else if ([identity isEqualToString:@"a"]) [line appendString:@" GENERATED ALWAYS AS IDENTITY"];
				else if ([identity isEqualToString:@"d"]) [line appendString:@" GENERATED BY DEFAULT AS IDENTITY"];
				else if (expression) [line appendFormat:@" DEFAULT %@", expression];

				NSArray *notNull = notNulls[SPPostgresCreateText(column[10]) ?: @""];
				if (notNull) {
					NSString *constraintName = SPPostgresCreateText(notNull[1]) ?: @"";
					if (!SPPostgresCreateIsTrue(notNull[4])) {
						// NOT VALID: the rows may hold NULLs, so not on the column line (CREATE TABLE can't take it)
						[notValid addObject:[NSString stringWithFormat:@"ALTER TABLE %@ ADD CONSTRAINT %@ %@", name, SPPostgresQuoteIdentifier(constraintName), SPPostgresCreateText(notNull[2]) ?: @""]];
					}
					else {
						// The server's own name (table_column_not_null) is left to it again
						NSString *defaultName = [NSString stringWithFormat:@"%@_%@_not_null", table, SPPostgresCreateText(column[0]) ?: @""];
						if (![constraintName isEqualToString:defaultName]) [line appendFormat:@" CONSTRAINT %@", SPPostgresQuoteIdentifier(constraintName)];
						[line appendString:@" NOT NULL"];
						if (SPPostgresCreateIsTrue(notNull[3])) [line appendString:@" NO INHERIT"];
					}
				}
				else if (SPPostgresCreateIsTrue(column[2])) [line appendString:@" NOT NULL"];
				[lines addObject:line];
				[linesWithoutForeignKeys addObject:line];
			}
		}

		for (NSArray *constraint in constraints) {
			NSString *line = [NSString stringWithFormat:@"CONSTRAINT %@ %@", SPPostgresQuoteIdentifier(SPPostgresCreateText(constraint[0]) ?: @""), SPPostgresCreateText(constraint[1]) ?: @""];
			// NOT VALID is for ALTER TABLE … ADD CONSTRAINT only
			if (SPPostgresCreateIsTrue(constraint[2])) {
				[lines addObject:line];
				if ([SPPostgresCreateText(constraint[3]) isEqualToString:@"f"]) [foreignKeyPart addObject:[NSString stringWithFormat:@"ALTER TABLE %@ ADD %@", name, line]];
				else [linesWithoutForeignKeys addObject:line];
			}
			else [notValid addObject:[NSString stringWithFormat:@"ALTER TABLE %@ ADD %@", name, line]];
		}

		NSString *(^createWithLines)(NSArray *) = ^NSString *(NSArray *columnLines) {
			NSMutableString *create = [NSMutableString stringWithFormat:@"CREATE %@%@ %@", unlogged ? @"UNLOGGED " : @"", keyword, name];
			if (isPartition && [parents count]) {
				NSArray *parent = [parents firstObject];
				[create appendFormat:@" PARTITION OF %@", SPPostgresCreateQualified([parent firstObject], [parent lastObject])];
				if ([columnLines count]) [create appendFormat:@" (\n    %@\n)", [columnLines componentsJoinedByString:@",\n    "]];
				[create appendFormat:@"\n%@", partitionBound ?: @"DEFAULT"];
			}
			else {
				[create appendString:@" ("];
				if ([columnLines count]) [create appendFormat:@"\n    %@", [columnLines componentsJoinedByString:@",\n    "]];
				[create appendString:@"\n)"];
				if ([parents count]) {
					NSMutableArray *names = [NSMutableArray array];
					for (NSArray *parent in parents) [names addObject:SPPostgresCreateQualified([parent firstObject], [parent lastObject])];
					[create appendFormat:@"\nINHERITS (%@)", [names componentsJoinedByString:@", "]];
				}
			}
			if (partitionKey) [create appendFormat:@"\nPARTITION BY %@", partitionKey];
			if (foreignServer) {
				[create appendFormat:@"\nSERVER %@", SPPostgresQuoteIdentifier(foreignServer)];
				if ([foreignOptions count]) [create appendFormat:@"\nOPTIONS (%@)", [foreignOptions componentsJoinedByString:@", "]];
			}
			if ([options length]) [create appendFormat:@"\nWITH (%@)", options];
			return create;
		};
		[statements addObject:createWithLines(lines)];
		[statements addObjectsFromArray:notValid];
		[tablePart addObject:createWithLines(linesWithoutForeignKeys)];
		// A constraint that isn't validated is still checked on new rows, so a dump adds it after the data
		[foreignKeyPart addObjectsFromArray:notValid];
	}

	// Indexes backing no constraint; a partition's copies of its parent's indexes come with PARTITION OF
	if (![relkind isEqualToString:@"v"]) {
		for (NSArray *index in indexes) {
			NSString *definition = SPPostgresCreateText(index[0]) ?: @"";
			// A partitioned table's index reads ON ONLY (its partitions' indexes attached one by one); created
			// before its partitions, plain ON makes them get it
			NSString *only = [NSString stringWithFormat:@"INDEX %@ ON ONLY ", SPPostgresCreateText(index[1]) ?: @""];
			NSRange range = [definition rangeOfString:only];
			if ([relkind isEqualToString:@"p"] && range.location != NSNotFound) {
				definition = [definition stringByReplacingCharactersInRange:range withString:[NSString stringWithFormat:@"INDEX %@ ON ", SPPostgresCreateText(index[1]) ?: @""]];
			}
			[statements addObject:definition];
			[indexPart addObject:definition];
		}
	}

	// Comments
	NSMutableArray *comments = [NSMutableArray array];
	if (tableComment) [comments addObject:[NSString stringWithFormat:@"COMMENT ON %@ %@ IS %@", keyword, name, SPPostgresQuoteLiteral(tableComment)]];
	for (NSArray *column in columns) {
		NSString *comment = SPPostgresCreateText(column[8]);
		if (!comment) continue;
		[comments addObject:[NSString stringWithFormat:@"COMMENT ON COLUMN %@.%@ IS %@", name, SPPostgresQuoteIdentifier(SPPostgresCreateText(column[0]) ?: @""), SPPostgresQuoteLiteral(comment)]];
	}
	[statements addObjectsFromArray:comments];
	[tablePart addObjectsFromArray:comments];

	// Triggers
	// ENABLE / DISABLE TRIGGER is an ALTER TABLE (ALTER FOREIGN TABLE) subcommand
	NSString *alterKeyword = [relkind isEqualToString:@"f"] ? @"FOREIGN TABLE" : @"TABLE";
	NSDictionary *states = @{@"D": @"DISABLE TRIGGER", @"R": @"ENABLE REPLICA TRIGGER", @"A": @"ENABLE ALWAYS TRIGGER"};
	for (NSArray *trigger in triggers) {
		[statements addObject:SPPostgresCreateText(trigger[0]) ?: @""];
		[triggerPart addObject:SPPostgresCreateText(trigger[0]) ?: @""];
		NSString *state = states[SPPostgresCreateText(trigger[1]) ?: @""];
		if (state) {
			NSString *alter = [NSString stringWithFormat:@"ALTER %@ %@ %@ %@", alterKeyword, name, state, SPPostgresQuoteIdentifier(SPPostgresCreateText(trigger[2]) ?: @"")];
			[statements addObject:alter];
			[triggerPart addObject:alter];
		}
	}

	return @{@"all": statements, SPPostgresCreatePartTable: tablePart, SPPostgresCreatePartIndexes: indexPart,
			 SPPostgresCreatePartForeignKeys: foreignKeyPart, SPPostgresCreatePartTriggers: triggerPart};
}

@end
