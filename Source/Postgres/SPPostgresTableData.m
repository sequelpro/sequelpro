#import "SPPostgresTableData.h"
#import "SPPostgresErrors.h"
#import <PostgresKit/PostgresKit.h>

NSString *SPPostgresQuoteIdentifier(NSString *identifier)
{
	return [NSString stringWithFormat:@"\"%@\"", [identifier ?: @"" stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
}

NSString *SPPostgresQuoteLiteral(NSString *value)
{
	NSString *quoted = [value ?: @"" stringByReplacingOccurrencesOfString:@"'" withString:@"''"];
	if ([quoted rangeOfString:@"\\"].location == NSNotFound) return [NSString stringWithFormat:@"'%@'", quoted];
	return [NSString stringWithFormat:@"E'%@'", [quoted stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]];
}

NSString *SPPostgresErrorDetailLines(PGPostgresError *error)
{
	NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSString *detail = [[error errorDetailMessage] stringByTrimmingCharactersInSet:whitespace];
	NSString *hint = [[error errorMessageHint] stringByTrimmingCharactersInSet:whitespace];
	NSMutableString *lines = [NSMutableString string];
	if ([detail length]) [lines appendFormat:@"\n%@ %@", NSLocalizedString(@"DETAIL:", @"Postgres query: error detail label"), detail];
	if ([hint length]) [lines appendFormat:@"\n%@ %@", NSLocalizedString(@"HINT:", @"Postgres query: error hint label"), hint];
	return lines;
}

static PGPostgresResult *SPPostgresReportingFailure(PGPostgresConnection *connection, PGPostgresResult *result, BOOL withDetails, NSError **error);

static PGPostgresResult *SPPostgresExecuteReporting(PGPostgresConnection *connection, NSString *sql, NSArray *values, BOOL withDetails, NSError **error)
{
	return SPPostgresReportingFailure(connection, [connection execute:sql values:values ?: @[]], withDetails, error);
}

PGPostgresResult *SPPostgresExecuteStatementsWithDetails(PGPostgresConnection *connection, NSString *sql, NSError **error)
{
	return SPPostgresReportingFailure(connection, [connection executeStatements:sql], YES, error);
}

/// result; when it is nil, *error says why (the server's message, with its DETAIL / HINT lines when withDetails).
static PGPostgresResult *SPPostgresReportingFailure(PGPostgresConnection *connection, PGPostgresResult *result, BOOL withDetails, NSError **error)
{
	if (!result && error) {
		NSString *message = nil;
		if ([connection isConnected]) {
			message = [[connection lastError] errorPrimaryMessage];
			if (![message length]) message = NSLocalizedString(@"The query failed.", @"Postgres content query failure");
			if (withDetails) message = [message stringByAppendingString:SPPostgresErrorDetailLines([connection lastError])];
		}
		else {
			// The connection is gone: libpq's message says why. The last query error may be older than that.
			message = [connection libpqErrorMessage];
			if (![message length]) message = NSLocalizedString(@"There is no connection to the server.", @"Postgres content query without a connection");
		}
		// The server's SQLSTATE, for callers that tell kinds of failure apart
		NSString *state = [connection isConnected] ? [[connection lastError] errorStateCode] : nil;
		*error = SPPostgresMakeError(SPPostgresErrorQueryFailed, message, [state length] ? @{SPPostgresSQLStateErrorKey: state} : nil);
	}
	return result;
}

PGPostgresResult *SPPostgresExecute(PGPostgresConnection *connection, NSString *sql, NSArray *values, NSError **error)
{
	return SPPostgresExecuteReporting(connection, sql, values, NO, error);
}

PGPostgresResult *SPPostgresExecuteWithDetails(PGPostgresConnection *connection, NSString *sql, NSArray *values, NSError **error)
{
	return SPPostgresExecuteReporting(connection, sql, values, YES, error);
}

/// How SPPostgresRunGuarded protects the user's transaction around body.
typedef NS_ENUM(NSInteger, SPPostgresGuardMode) {
	SPPostgresGuardAtomic, // several statements: when idle, wrapped in a transaction of our own
	SPPostgresGuardWrite,  // one statement: when idle, run as is (it is its own transaction)
	SPPostgresGuardRead    // one read: as Write, but inside an aborted transaction it is still sent
};

/**
 * The shared core of SPPostgresRunAtomically and the Content view's single-statement edits and loads. The
 * connection may be shared with the Query view, where the user may have a transaction open; a failure inside
 * it would abort that transaction, so there body runs in the savepoint `savepoint`, released on success and
 * rolled back to (then released) on failure. When idle, Atomic wraps body in BEGIN / COMMIT (ROLLBACK on
 * failure) and the others run it as is. Inside an aborted transaction nothing can succeed: Atomic and Write
 * send nothing and fail with abortedMessage; Read sends body anyway (as before) and, if it fails while the
 * transaction is still aborted, reports abortedMessage instead of the server's terser message.
 */
static BOOL SPPostgresRunGuarded(PGPostgresConnection *connection, SPPostgresGuardMode mode, NSString *savepoint,
								 NSString *abortedMessage, BOOL (^body)(NSError **error), NSError **error)
{
	NSString *begin = nil, *finish = nil;
	NSArray *undo = nil;
	switch ([connection transactionStatus]) {
		case PGPostgresTransactionInError:
			if (mode == SPPostgresGuardRead) {
				if (body(error)) return YES;
				if (error && [connection transactionStatus] == PGPostgresTransactionInError) {
					*error = SPPostgresMakeError(SPPostgresErrorQueryFailed, abortedMessage, nil);
				}
				return NO;
			}
			if (error) *error = SPPostgresMakeError(SPPostgresErrorQueryFailed, abortedMessage, nil);
			return NO;
		case PGPostgresTransactionInTransaction:
			begin = [NSString stringWithFormat:@"SAVEPOINT %@", savepoint];
			finish = [NSString stringWithFormat:@"RELEASE SAVEPOINT %@", savepoint];
			undo = @[[NSString stringWithFormat:@"ROLLBACK TO SAVEPOINT %@", savepoint], finish];
			break;
		default: // idle (or no connection, which the first statement reports)
			if (mode != SPPostgresGuardAtomic) return body(error);
			begin = @"BEGIN";
			finish = @"COMMIT";
			undo = @[@"ROLLBACK"];
			break;
	}

	if (!SPPostgresExecute(connection, begin, nil, error)) return NO;

	if (!body(error) || !SPPostgresExecute(connection, finish, nil, error)) {
		// Quietly: a failure here must not replace the error being reported
		for (NSString *sql in undo) [connection execute:sql values:@[]];
		return NO;
	}
	return YES;
}

BOOL SPPostgresRunAtomically(PGPostgresConnection *connection, NSString *savepoint, NSString *abortedMessage,
							 BOOL (^body)(NSError **error), NSError **error)
{
	return SPPostgresRunGuarded(connection, SPPostgresGuardAtomic, savepoint, abortedMessage, body, error);
}

BOOL SPPostgresRunGuardedRead(PGPostgresConnection *connection, NSString *savepoint, NSString *abortedMessage,
							  BOOL (^body)(NSError **error), NSError **error)
{
	return SPPostgresRunGuarded(connection, SPPostgresGuardRead, savepoint, abortedMessage, body, error);
}

#pragma mark - SPPostgresColumn

@interface SPPostgresColumn ()
- (instancetype)initWithName:(NSString *)name typeName:(NSString *)typeName castTypeName:(NSString *)castTypeName
					nullable:(BOOL)nullable defaultExpression:(NSString *)defaultExpression
		  primaryKeyPosition:(NSInteger)primaryKeyPosition isGenerated:(BOOL)isGenerated isAutoNumbered:(BOOL)isAutoNumbered;
@end

@implementation SPPostgresColumn

@synthesize name = _name;
@synthesize typeName = _typeName;
@synthesize castTypeName = _castTypeName;
@synthesize nullable = _nullable;
@synthesize defaultExpression = _defaultExpression;
@synthesize primaryKeyPosition = _primaryKeyPosition;
@synthesize isGenerated = _isGenerated;
@synthesize isAutoNumbered = _isAutoNumbered;

- (instancetype)initWithName:(NSString *)name typeName:(NSString *)typeName castTypeName:(NSString *)castTypeName
					nullable:(BOOL)nullable defaultExpression:(NSString *)defaultExpression
		  primaryKeyPosition:(NSInteger)primaryKeyPosition isGenerated:(BOOL)isGenerated isAutoNumbered:(BOOL)isAutoNumbered
{
	if ((self = [super init])) {
		_name = [name copy];
		_typeName = [typeName copy];
		_castTypeName = [castTypeName copy];
		_nullable = nullable;
		_defaultExpression = [defaultExpression copy];
		_primaryKeyPosition = primaryKeyPosition;
		_isGenerated = isGenerated;
		_isAutoNumbered = isAutoNumbered;
	}
	return self;
}

- (void)dealloc
{
	[_name release];
	[_typeName release];
	[_castTypeName release];
	[_defaultExpression release];
	[super dealloc];
}

- (BOOL)isPrimaryKey
{
	return _primaryKeyPosition > 0;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@ %@%@>", [self class], _name, _typeName, _primaryKeyPosition ? @" PK" : @""];
}

@end

#pragma mark - SPPostgresFilter

@implementation SPPostgresFilter

@synthesize column = _column;
@synthesize comparison = _comparison;
@synthesize value = _value;

+ (instancetype)filterWithColumn:(NSString *)column comparison:(NSString *)comparison value:(NSString *)value
{
	SPPostgresFilter *filter = [[[self alloc] init] autorelease];
	filter.column = column;
	filter.comparison = comparison;
	filter.value = value;
	return filter;
}

- (void)dealloc
{
	[_column release];
	[_comparison release];
	[_value release];
	[super dealloc];
}

@end

#pragma mark - SPPostgresTableData

@implementation SPPostgresTableData

@synthesize schema = _schema;
@synthesize table = _table;

- (instancetype)initWithConnection:(PGPostgresConnection *)connection schema:(NSString *)schema table:(NSString *)table
{
	if ((self = [super init])) {
		_connection = [connection retain];
		_schema = [schema copy];
		_table = [table copy];
	}
	return self;
}

- (void)dealloc
{
	[_connection release];
	[_schema release];
	[_table release];
	[_columns release];
	[_relationKind release];
	[super dealloc];
}

#pragma mark - Helpers

- (PGPostgresResult *)run:(NSString *)sql values:(NSArray *)values error:(NSError **)error
{
	return SPPostgresExecute(_connection, sql, values, error);
}

/// Runs one read so that, inside the user's transaction, its failure doesn't abort that transaction.
- (BOOL)guardRead:(BOOL (^)(NSError **error))body error:(NSError **)error
{
	NSString *aborted = NSLocalizedString(@"The current transaction is aborted, so the rows can't be read. Roll it back first (ROLLBACK in the Query view).", @"Postgres content: load inside an aborted transaction");
	return SPPostgresRunGuarded(_connection, SPPostgresGuardRead, @"sp_content_read", aborted, body, error);
}

/// Runs one change so that, inside the user's transaction, its failure doesn't abort that transaction; inside an
/// aborted transaction it is refused with abortedMessage.
- (BOOL)guardWrite:(NSString *)abortedMessage body:(BOOL (^)(NSError **error))body error:(NSError **)error
{
	return SPPostgresRunGuarded(_connection, SPPostgresGuardWrite, @"sp_content_write", abortedMessage, body, error);
}

- (NSString *)qualifiedName
{
	return [NSString stringWithFormat:@"%@.%@", SPPostgresQuoteIdentifier(_schema), SPPostgresQuoteIdentifier(_table)];
}

/// "schema"."table"."column": always the table's column, never an output column of the same name.
- (NSString *)qualifiedColumn:(SPPostgresColumn *)column
{
	return [NSString stringWithFormat:@"%@.%@", [self qualifiedName], SPPostgresQuoteIdentifier([column name])];
}

- (BOOL)loadMetadata:(NSError **)error
{
	if (_columns) return YES;

	// One row per column (LEFT JOIN, so a relation without columns still yields its relkind).
	PGPostgresResult *result = [self run:
		@"SELECT c.relkind::text AS kind, a.attname::text AS name, "
		 "format_type(a.atttypid, a.atttypmod) AS type, format_type(a.atttypid, -1) AS casttype, "
		 "(NOT a.attnotnull)::text AS nullable, "
		 "CASE WHEN a.attgenerated = '' THEN pg_get_expr(d.adbin, d.adrelid) END AS def, "
		 // indkey is an int2vector, whose subscripts start at 0, so the 1-based position comes from WITH ORDINALITY.
		 "COALESCE((SELECT k.ord FROM unnest(i.indkey::int2[]) WITH ORDINALITY AS k(attnum, ord) WHERE k.attnum = a.attnum), 0)::text AS pkpos, "
		 "(a.attidentity = 'a' OR a.attgenerated <> '')::text AS generated, "
		 "(a.attidentity <> '' OR COALESCE(pg_get_expr(d.adbin, d.adrelid) LIKE 'nextval(%', false))::text AS autonumbered "
		 "FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace "
		 "LEFT JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped "
		 "LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum "
		 "LEFT JOIN pg_index i ON i.indrelid = c.oid AND i.indisprimary "
		 "WHERE n.nspname = $1::text AND c.relname = $2::text "
		 "ORDER BY a.attnum"
								  values:@[_schema ?: @"", _table ?: @""] error:error];
	if (!result) return NO;

	if ([result numberOfRows] == 0) {
		if (error) {
			*error = SPPostgresMakeError(SPPostgresErrorQueryFailed,
				[NSString stringWithFormat:NSLocalizedString(@"The table %@ was not found.", @"Postgres content: table missing"), [self qualifiedName]], nil);
		}
		return NO;
	}

	NSMutableArray *columns = [NSMutableArray array];
	NSString *kind = nil;
	for (NSDictionary *row in result) {
		id value = [row objectForKey:@"kind"];
		if ([value isKindOfClass:[NSString class]]) kind = value;

		NSString *name = [row objectForKey:@"name"];
		if (![name isKindOfClass:[NSString class]]) continue;

		id def = [row objectForKey:@"def"];
		SPPostgresColumn *column = [[SPPostgresColumn alloc] initWithName:name
																 typeName:[row objectForKey:@"type"]
															 castTypeName:[row objectForKey:@"casttype"]
																 nullable:[[row objectForKey:@"nullable"] isEqual:@"true"]
														defaultExpression:[def isKindOfClass:[NSString class]] ? def : nil
													   primaryKeyPosition:[[row objectForKey:@"pkpos"] integerValue]
															  isGenerated:[[row objectForKey:@"generated"] isEqual:@"true"]
														   isAutoNumbered:[[row objectForKey:@"autonumbered"] isEqual:@"true"]];
		[columns addObject:column];
		[column release];
	}

	_columns = [columns copy];
	_relationKind = [kind copy];
	return YES;
}

- (NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *)foreignKeyReferences:(NSError **)error
{
	// conkey and confkey are int2[] (1-based subscripts): their first entries pair the first column with the one it references
	PGPostgresResult *result = [self run:
		@"SELECT a.attname::text AS col, rn.nspname::text AS refschema, rc.relname::text AS reftable, ra.attname::text AS refcol "
		 "FROM pg_constraint con "
		 "JOIN pg_class c ON c.oid = con.conrelid JOIN pg_namespace n ON n.oid = c.relnamespace "
		 "JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = con.conkey[1] "
		 "JOIN pg_class rc ON rc.oid = con.confrelid JOIN pg_namespace rn ON rn.oid = rc.relnamespace "
		 "JOIN pg_attribute ra ON ra.attrelid = con.confrelid AND ra.attnum = con.confkey[1] "
		 "WHERE con.contype = 'f' AND n.nspname = $1::text AND c.relname = $2::text "
		 "ORDER BY con.conname"
								  values:@[_schema ?: @"", _table ?: @""] error:error];
	if (!result) return nil;

	NSMutableDictionary *references = [NSMutableDictionary dictionary];
	for (NSDictionary *row in result) {
		NSString *column = [row objectForKey:@"col"];
		NSString *refSchema = [row objectForKey:@"refschema"];
		NSString *refTable = [row objectForKey:@"reftable"];
		NSString *refColumn = [row objectForKey:@"refcol"];
		if (![column isKindOfClass:[NSString class]] || ![refSchema isKindOfClass:[NSString class]]
			|| ![refTable isKindOfClass:[NSString class]] || ![refColumn isKindOfClass:[NSString class]]) continue;
		if ([references objectForKey:column]) continue;
		[references setObject:@{@"schema" : refSchema, @"table" : refTable, @"column" : refColumn} forKey:column];
	}
	return references;
}

- (SPPostgresColumn *)columnNamed:(NSString *)name error:(NSError **)error
{
	for (SPPostgresColumn *column in _columns) {
		if ([[column name] isEqualToString:name]) return column;
	}
	if (error) {
		*error = SPPostgresMakeError(SPPostgresErrorQueryFailed,
			[NSString stringWithFormat:NSLocalizedString(@"There is no column named %@.", @"Postgres content: unknown column"), SPPostgresQuoteIdentifier(name)], nil);
	}
	return nil;
}

/// Primary-key columns in key order.
- (NSArray *)primaryKeyColumns
{
	NSMutableArray *keys = [NSMutableArray array];
	for (SPPostgresColumn *column in _columns) {
		if ([column isPrimaryKey]) [keys addObject:column];
	}
	[keys sortUsingComparator:^NSComparisonResult(SPPostgresColumn *a, SPPostgresColumn *b) {
		return [@([a primaryKeyPosition]) compare:@([b primaryKeyPosition])];
	}];
	return keys;
}

/// "c1"::text, "c2"::text, … in column order.
- (NSString *)textSelectList
{
	NSMutableArray *items = [NSMutableArray arrayWithCapacity:[_columns count]];
	for (SPPostgresColumn *column in _columns) {
		[items addObject:[NSString stringWithFormat:@"%@::text", SPPostgresQuoteIdentifier([column name])]];
	}
	return [items componentsJoinedByString:@", "];
}

/// Converts a result to rows of NSString / NSNull.
- (NSArray *)rowsFromResult:(PGPostgresResult *)result
{
	NSMutableArray *rows = [NSMutableArray arrayWithCapacity:(NSUInteger)[result numberOfRows]];
	NSArray *row;
	while ((row = [result rowAsArray])) [rows addObject:row];
	return rows;
}

/// " WHERE …" for the filter (or @"" for none), appending its parameters to values. Nil with *error if invalid.
- (NSString *)whereClauseForFilter:(SPPostgresFilter *)filter values:(NSMutableArray *)values error:(NSError **)error
{
	if (!filter) return @"";

	SPPostgresColumn *column = [self columnNamed:[filter column] error:error];
	if (!column) return nil;

	NSString *quoted = SPPostgresQuoteIdentifier([column name]);
	NSString *op = [filter comparison];
	if (![op length]) {
		if (error) *error = SPPostgresMakeError(SPPostgresErrorQueryFailed, NSLocalizedString(@"No filter operator was chosen.", @"Postgres content: missing filter operator"), nil);
		return nil;
	}
	NSString *value = [filter value] ?: @"";

	if ([op isEqualToString:@"IS NULL"] || [op isEqualToString:@"IS NOT NULL"]) {
		return [NSString stringWithFormat:@" WHERE %@ %@", quoted, op];
	}

	if ([op isEqualToString:@"LIKE"] || [op isEqualToString:@"NOT LIKE"] || [op isEqualToString:@"ILIKE"]) {
		[values addObject:value];
		return [NSString stringWithFormat:@" WHERE %@::text %@ $%lu::text", quoted, op, (unsigned long)[values count]];
	}

	if ([op isEqualToString:@"IN"]) {
		// Items are trimmed; empty items (e.g. from a trailing comma) are dropped.
		NSMutableArray *placeholders = [NSMutableArray array];
		for (NSString *item in [value componentsSeparatedByString:@","]) {
			NSString *trimmed = [item stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			if (![trimmed length]) continue;
			[values addObject:trimmed];
			[placeholders addObject:[NSString stringWithFormat:@"$%lu::%@", (unsigned long)[values count], [column castTypeName]]];
		}
		if (![placeholders count]) {
			if (error) *error = SPPostgresMakeError(SPPostgresErrorQueryFailed, NSLocalizedString(@"Enter at least one value for IN, separated by commas.", @"Postgres content: empty IN list"), nil);
			return nil;
		}
		return [NSString stringWithFormat:@" WHERE %@ IN (%@)", quoted, [placeholders componentsJoinedByString:@", "]];
	}

	// Only these fixed operators are ever placed in the SQL; ≠ is sent as <>.
	NSDictionary *comparisons = @{@"=": @"=", @"≠": @"<>", @">": @">", @"<": @"<", @">=": @">=", @"<=": @"<="};
	NSString *sqlOperator = [comparisons objectForKey:op];
	if (!sqlOperator) {
		if (error) {
			*error = SPPostgresMakeError(SPPostgresErrorQueryFailed,
				[NSString stringWithFormat:NSLocalizedString(@"The filter operator “%@” is not supported.", @"Postgres content: unknown filter operator"), op], nil);
		}
		return nil;
	}
	[values addObject:value];
	return [NSString stringWithFormat:@" WHERE %@ %@ $%lu::%@", quoted, sqlOperator, (unsigned long)[values count], [column castTypeName]];
}

/// "pk1" = $n::type AND … (without a leading WHERE): identifies row by its full primary key.
- (NSString *)keyConditionForRow:(NSArray *)row values:(NSMutableArray *)values error:(NSError **)error
{
	NSArray *keys = [self primaryKeyColumns];
	if (![keys count] || [row count] != [_columns count]) {
		if (error) {
			*error = SPPostgresMakeError(SPPostgresErrorQueryFailed,
				NSLocalizedString(@"The row doesn't match the table's columns, so it can't be identified.", @"Postgres content: row shape mismatch"), nil);
		}
		return nil;
	}

	NSMutableArray *conditions = [NSMutableArray arrayWithCapacity:[keys count]];
	for (SPPostgresColumn *key in keys) {
		[values addObject:[row objectAtIndex:[_columns indexOfObjectIdenticalTo:key]]];
		[conditions addObject:[NSString stringWithFormat:@"%@ = $%lu::%@", SPPostgresQuoteIdentifier([key name]), (unsigned long)[values count], [key castTypeName]]];
	}
	return [conditions componentsJoinedByString:@" AND "];
}

/// Loads metadata and refuses (without sending any SQL beyond the cached catalog query) when not editable.
- (BOOL)checkEditable:(NSError **)error
{
	if (![self loadMetadata:error]) return NO;
	if ([self isEditable]) return YES;
	if (error) *error = SPPostgresMakeError(SPPostgresErrorNotEditable, [self readOnlyReason], nil);
	return NO;
}

- (NSError *)rowChangedError
{
	return SPPostgresMakeError(SPPostgresErrorRowChanged,
		NSLocalizedString(@"The row was changed or deleted by someone else since it was loaded, so it wasn't changed. Reload the table to see its current contents.",
						  @"Postgres content: edit affected no rows"), nil);
}

#pragma mark - Public API

- (NSArray *)columns:(NSError **)error
{
	if (![self loadMetadata:error]) return nil;
	return [[_columns retain] autorelease];
}

- (BOOL)isEditable
{
	if (![self loadMetadata:NULL]) return NO;
	BOOL isTable = [_relationKind isEqualToString:@"r"] || [_relationKind isEqualToString:@"p"];
	return isTable && [[self primaryKeyColumns] count] > 0;
}

- (NSString *)readOnlyReason
{
	if ([self isEditable]) return nil;
	if (!_columns) return NSLocalizedString(@"The table's columns couldn't be read, so its rows can't be edited.", @"Postgres content: metadata failed");
	if ([_relationKind isEqualToString:@"v"] || [_relationKind isEqualToString:@"m"]) {
		return NSLocalizedString(@"This is a view, so its rows can't be edited.", @"Postgres content: view is read-only");
	}
	if (![_relationKind isEqualToString:@"r"] && ![_relationKind isEqualToString:@"p"]) {
		return NSLocalizedString(@"This is not a table, so its rows can't be edited.", @"Postgres content: non-table is read-only");
	}
	return NSLocalizedString(@"This table has no primary key, so its rows can't be edited.", @"Postgres content: no primary key");
}

- (NSArray *)rowsWithFilter:(SPPostgresFilter *)filter sortColumn:(NSString *)column ascending:(BOOL)ascending
					 offset:(NSUInteger)offset limit:(NSUInteger)limit error:(NSError **)error
{
	if (![self loadMetadata:error]) return nil;

	NSMutableArray *values = [NSMutableArray array];
	NSString *where = [self whereClauseForFilter:filter values:values error:error];
	if (!where) return nil;

	// Order by the sort column, then the primary key, so pages are stable. The names are qualified: a bare
	// ORDER BY "id" would sort by the output column "id" (the ::text value) rather than the table column.
	NSMutableArray *order = [NSMutableArray array];
	SPPostgresColumn *sortColumn = nil;
	if (column) {
		sortColumn = [self columnNamed:column error:error];
		if (!sortColumn) return nil;
		[order addObject:[NSString stringWithFormat:@"%@ %@", [self qualifiedColumn:sortColumn], ascending ? @"ASC" : @"DESC"]];
	}
	for (SPPostgresColumn *key in [self primaryKeyColumns]) {
		if (key != sortColumn) [order addObject:[self qualifiedColumn:key]];
	}
	NSString *orderBy = [order count] ? [@" ORDER BY " stringByAppendingString:[order componentsJoinedByString:@", "]] : @"";

	// limit 0 means no limit: LIMIT NULL is the same as LIMIT ALL.
	unsigned long long maxBigint = (unsigned long long)LLONG_MAX;
	[values addObject:limit ? (id)[NSString stringWithFormat:@"%llu", MIN((unsigned long long)limit, maxBigint)] : (id)[NSNull null]];
	[values addObject:[NSString stringWithFormat:@"%llu", MIN((unsigned long long)offset, maxBigint)]];
	NSString *sql = [NSString stringWithFormat:@"SELECT %@ FROM %@%@%@ LIMIT $%lu::bigint OFFSET $%lu::bigint",
					 [self textSelectList], [self qualifiedName], where, orderBy,
					 (unsigned long)[values count] - 1, (unsigned long)[values count]];

	__block NSArray *rows = nil;
	BOOL ok = [self guardRead:^BOOL(NSError **bodyError) {
		PGPostgresResult *result = [self run:sql values:values error:bodyError];
		if (result) rows = [self rowsFromResult:result];
		return result != nil;
	} error:error];
	return ok ? rows : nil;
}

- (NSInteger)countRowsWithFilter:(SPPostgresFilter *)filter error:(NSError **)error
{
	if (![self loadMetadata:error]) return -1;

	NSMutableArray *values = [NSMutableArray array];
	NSString *where = [self whereClauseForFilter:filter values:values error:error];
	if (!where) return -1;

	NSString *sql = [NSString stringWithFormat:@"SELECT count(*)::text AS n FROM %@%@", [self qualifiedName], where];
	__block NSInteger count = -1;
	BOOL ok = [self guardRead:^BOOL(NSError **bodyError) {
		PGPostgresResult *result = [self run:sql values:values error:bodyError];
		if (result) count = [[[result rowAsArray] firstObject] integerValue];
		return result != nil;
	} error:error];
	return ok ? count : -1;
}

- (BOOL)updateRow:(NSArray *)originalRow column:(NSString *)column value:(id)value error:(NSError **)error
{
	if (![self checkEditable:error]) return NO;

	SPPostgresColumn *target = [self columnNamed:column error:error];
	if (!target) return NO;
	if (![value isKindOfClass:[NSString class]] && ![value isKindOfClass:[NSNull class]]) {
		if (error) *error = SPPostgresMakeError(SPPostgresErrorQueryFailed, NSLocalizedString(@"The value must be text or NULL.", @"Postgres content: bad value class"), nil);
		return NO;
	}

	NSMutableArray *values = [NSMutableArray arrayWithObject:value];
	NSString *key = [self keyConditionForRow:originalRow values:values error:error];
	if (!key) return NO;

	NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = $1::%@ WHERE %@",
					 [self qualifiedName], SPPostgresQuoteIdentifier([target name]), [target castTypeName], key];
	NSString *aborted = NSLocalizedString(@"The current transaction is aborted, so the row was not changed. Roll it back first.", @"Postgres content: edit inside an aborted transaction");
	return [self guardWrite:aborted body:^BOOL(NSError **bodyError) {
		if (![self run:sql values:values error:bodyError]) return NO;

		// The WHERE clause is the full primary key, so at most one row can match.
		if ([_connection lastQueryAffectedRowCount] == 0) {
			if (bodyError) *bodyError = [self rowChangedError];
			return NO;
		}
		return YES;
	} error:error];
}

- (NSArray *)insertRowWithValues:(NSDictionary *)valuesByColumn error:(NSError **)error
{
	if (![self checkEditable:error]) return nil;

	for (NSString *name in valuesByColumn) {
		if (![self columnNamed:name error:error]) return nil;
	}

	NSMutableArray *names = [NSMutableArray array];
	NSMutableArray *placeholders = [NSMutableArray array];
	NSMutableArray *values = [NSMutableArray array];
	for (SPPostgresColumn *column in _columns) { // column order, so the SQL doesn't depend on dictionary order
		id value = [valuesByColumn objectForKey:[column name]];
		if (!value) continue;
		if (![value isKindOfClass:[NSString class]] && ![value isKindOfClass:[NSNull class]]) {
			if (error) *error = SPPostgresMakeError(SPPostgresErrorQueryFailed, NSLocalizedString(@"The value must be text or NULL.", @"Postgres content: bad value class"), nil);
			return nil;
		}
		[values addObject:value];
		[names addObject:SPPostgresQuoteIdentifier([column name])];
		[placeholders addObject:[NSString stringWithFormat:@"$%lu::%@", (unsigned long)[values count], [column castTypeName]]];
	}

	NSString *sql = [names count]
		? [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@) RETURNING %@", [self qualifiedName],
		   [names componentsJoinedByString:@", "], [placeholders componentsJoinedByString:@", "], [self textSelectList]]
		: [NSString stringWithFormat:@"INSERT INTO %@ DEFAULT VALUES RETURNING %@", [self qualifiedName], [self textSelectList]];

	NSString *aborted = NSLocalizedString(@"The current transaction is aborted, so the row was not added. Roll it back first.", @"Postgres content: insert inside an aborted transaction");
	__block NSArray *row = nil;
	BOOL ok = [self guardWrite:aborted body:^BOOL(NSError **bodyError) {
		PGPostgresResult *result = [self run:sql values:values error:bodyError];
		if (result) row = [[self rowsFromResult:result] firstObject];
		return result != nil;
	} error:error];
	return ok ? row : nil;
}

- (NSArray *)insertCopyOfRow:(NSArray *)row error:(NSError **)error
{
	if (![self checkEditable:error]) return nil;
	if ([row count] != [_columns count]) {
		if (error) {
			*error = SPPostgresMakeError(SPPostgresErrorQueryFailed,
				NSLocalizedString(@"The row doesn't match the table's columns, so it can't be copied.", @"Postgres content: copied row shape mismatch"), nil);
		}
		return nil;
	}

	// Generated and auto-numbered columns are left out, so they get their defaults (a new serial or identity value)
	NSMutableDictionary *valuesByColumn = [NSMutableDictionary dictionary];
	[_columns enumerateObjectsUsingBlock:^(SPPostgresColumn *column, NSUInteger index, BOOL *stop) {
		if (![column isGenerated] && ![column isAutoNumbered]) [valuesByColumn setObject:[row objectAtIndex:index] forKey:[column name]];
	}];
	return [self insertRowWithValues:valuesByColumn error:error];
}

- (BOOL)deleteRows:(NSArray *)rows error:(NSError **)error
{
	if (![self checkEditable:error]) return NO;
	if (![rows count]) return YES;

	// Build every statement first, so a malformed row is refused before anything is sent. Rows with the same
	// primary key are deleted once (a second DELETE would match nothing and look like a concurrent change).
	NSMutableArray *statements = [NSMutableArray arrayWithCapacity:[rows count]];
	NSMutableArray *parameters = [NSMutableArray arrayWithCapacity:[rows count]];
	NSMutableSet *seenKeys = [NSMutableSet set];
	for (NSArray *row in rows) {
		NSMutableArray *values = [NSMutableArray array];
		NSString *key = [self keyConditionForRow:row values:values error:error];
		if (!key) return NO;
		if ([seenKeys containsObject:values]) continue;
		[seenKeys addObject:values];
		[statements addObject:[NSString stringWithFormat:@"DELETE FROM %@ WHERE %@", [self qualifiedName], key]];
		[parameters addObject:values];
	}

	// All or nothing. Outside a transaction, use one of our own; inside the user's (shared connection), use a
	// savepoint so the user's transaction is neither committed nor rolled back.
	NSString *aborted = NSLocalizedString(@"The current transaction is aborted, so no rows were deleted. Roll it back first.", @"Postgres content: delete inside an aborted transaction");
	return SPPostgresRunAtomically(_connection, @"sp_content_delete", aborted, ^BOOL(NSError **bodyError) {
		for (NSUInteger i = 0; i < [statements count]; i++) {
			if (![self run:[statements objectAtIndex:i] values:[parameters objectAtIndex:i] error:bodyError]) return NO;
			if ([_connection lastQueryAffectedRowCount] == 0) {
				if (bodyError) *bodyError = [self rowChangedError];
				return NO;
			}
		}
		return YES;
	}, error);
}

@end
