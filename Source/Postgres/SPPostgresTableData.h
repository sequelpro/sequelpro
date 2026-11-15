#import <Foundation/Foundation.h>

@class PGPostgresConnection;
@class PGPostgresResult;
@class PGPostgresError;

/// Quotes a PostgreSQL identifier: wraps it in double quotes and doubles any embedded double quote.
extern NSString *SPPostgresQuoteIdentifier(NSString *identifier) __attribute__((visibility("default")));

/// A string literal for SQL that takes no parameters (DDL, COMMENT ON): correct whatever standard_conforming_strings is.
extern NSString *SPPostgresQuoteLiteral(NSString *value) __attribute__((visibility("default")));

/// The server error's DETAIL and HINT as lines to append to its message (each "\nDETAIL: …" / "\nHINT: …", as
/// psql and the Query view show them), or @"" when it has neither.
extern NSString *SPPostgresErrorDetailLines(PGPostgresError *error) __attribute__((visibility("default")));

/// Runs sql with values ($n parameters); on failure returns nil with SPPostgresErrorQueryFailed and the server's
/// message (or libpq's, when the connection is gone).
extern PGPostgresResult *SPPostgresExecute(PGPostgresConnection *connection, NSString *sql, NSArray *values, NSError **error) __attribute__((visibility("default")));

/// As SPPostgresExecute, but a server error's message is followed by its DETAIL and HINT lines
/// (SPPostgresErrorDetailLines).
extern PGPostgresResult *SPPostgresExecuteWithDetails(PGPostgresConnection *connection, NSString *sql, NSArray *values, NSError **error) __attribute__((visibility("default")));

/// As SPPostgresExecuteWithDetails, for sql holding several statements, sent in one round trip (no parameters, no
/// COPY): nil with the failing statement's error when one fails (those after it aren't run).
extern PGPostgresResult *SPPostgresExecuteStatementsWithDetails(PGPostgresConnection *connection, NSString *sql, NSError **error) __attribute__((visibility("default")));

/**
 * Runs body all or nothing on a connection that may be shared with the Query view, where the user may have a
 * transaction open: when idle, in a transaction of its own (BEGIN, then COMMIT, or ROLLBACK if body fails);
 * inside the user's transaction, in the savepoint `savepoint` (a plain identifier), released on success and
 * rolled back to (and released) on failure, so the user's transaction stays open either way; inside an aborted
 * transaction, nothing is sent and it fails with abortedMessage (SPPostgresErrorQueryFailed). body returns NO
 * (setting its error) to undo.
 */
extern BOOL SPPostgresRunAtomically(PGPostgresConnection *connection, NSString *savepoint, NSString *abortedMessage,
									BOOL (^body)(NSError **error), NSError **error) __attribute__((visibility("default")));

/**
 * Runs body, one read, so that its failure doesn't abort the user's transaction: inside it, in the savepoint
 * `savepoint` (a plain identifier), released on success and rolled back to (and released) on failure; when idle, as
 * is; inside an aborted transaction it is still sent, and a failure there is reported as abortedMessage
 * (SPPostgresErrorQueryFailed). As the Content view's loads.
 */
extern BOOL SPPostgresRunGuardedRead(PGPostgresConnection *connection, NSString *savepoint, NSString *abortedMessage,
									 BOOL (^body)(NSError **error), NSError **error) __attribute__((visibility("default")));

/// One column of a table or view, as described by pg_attribute.
__attribute__((visibility("default")))
@interface SPPostgresColumn : NSObject
{
	NSString *_name;
	NSString *_typeName;
	NSString *_castTypeName;
	NSString *_defaultExpression;
	NSInteger _primaryKeyPosition;
	BOOL _nullable;
	BOOL _isGenerated;
	BOOL _isAutoNumbered;
}

@property (readonly, copy) NSString *name;
/// format_type(atttypid, atttypmod), e.g. @"numeric(20,6)" or @"text[]".
@property (readonly, copy) NSString *typeName;
/// format_type(atttypid, -1): the type without its modifier, used to cast parameters (e.g. @"bpchar", @"\"bit\"",
/// @"character varying"). Casting to it (rather than to typeName) leaves the modifier to the assignment, which
/// errors instead of silently truncating (an explicit ::varchar(3) cast truncates). Not format_type(…, NULL):
/// that gives @"character" / @"bit", which the parser reads as character(1) / bit(1).
@property (readonly, copy) NSString *castTypeName;
@property (readonly) BOOL nullable;
/// The column default as SQL text, or nil if there is none (generated columns have none).
@property (readonly, copy) NSString *defaultExpression;
@property (readonly) BOOL isPrimaryKey;
/// 1-based position in the primary key, 0 if the column is not part of it.
@property (readonly) NSInteger primaryKeyPosition;
/// YES for identity ALWAYS columns and generated columns.
@property (readonly) BOOL isGenerated;
/// YES for identity columns (ALWAYS or BY DEFAULT) and serial ones (whose default starts with "nextval("): the columns a
/// copied row takes a new value for (as MySQL's auto_increment).
@property (readonly) BOOL isAutoNumbered;

@end

/// One condition of the Content view's filter bar.
__attribute__((visibility("default")))
@interface SPPostgresFilter : NSObject
{
	NSString *_column;
	NSString *_comparison;
	NSString *_value;
}

+ (instancetype)filterWithColumn:(NSString *)column comparison:(NSString *)comparison value:(NSString *)value;

@property (readwrite, copy) NSString *column;
/// One of @"=", @"≠" (sent as <>), @">", @"<", @">=", @"<=", @"LIKE", @"NOT LIKE", @"ILIKE",
/// @"IS NULL", @"IS NOT NULL", @"IN".
@property (readwrite, copy) NSString *comparison;
/// The value, sent as a parameter (ignored for IS NULL / IS NOT NULL). For IN, a comma-separated list whose
/// items (trimmed of surrounding whitespace; empty items dropped) are sent as separate parameters.
@property (readwrite, copy) NSString *value;

@end

/**
 * Data access for the Content view of one table or view.
 *
 * Values are read as PostgreSQL text ("col"::text) and written as text parameters cast to the column type
 * ($n::<type>), so every type displays in Postgres's own format and round-trips exactly. Identifiers are
 * always quoted and values always sent as parameters. Rows are NSArrays of NSString, or NSNull for SQL NULL,
 * in column (attnum) order.
 *
 * Rows can be changed only when the relation is a table (or partitioned table) with a primary key; edits
 * identify the row by its full primary key, so an UPDATE or DELETE can never match more than one row.
 * The column list is read once and cached.
 *
 * The connection may be shared with the Query view. Inside a transaction the user opened there, each load and
 * edit runs in a savepoint, so a failed one (a bad value, a bad filter) leaves the user's transaction open and its
 * earlier work intact; when idle, statements are sent as is. Inside an aborted transaction edits are refused and
 * loads fail with a message saying to roll it back.
 *
 * Errors use SPPostgresErrorDomain: SPPostgresErrorQueryFailed (the server's message), SPPostgresErrorNotEditable
 * (refused before any SQL is sent) and SPPostgresErrorRowChanged (an edit matched no row).
 */
__attribute__((visibility("default")))
@interface SPPostgresTableData : NSObject
{
	PGPostgresConnection *_connection;
	NSString *_schema;
	NSString *_table;
	NSArray *_columns;
	NSString *_relationKind;
}

- (instancetype)initWithConnection:(PGPostgresConnection *)connection schema:(NSString *)schema table:(NSString *)table;

@property (readonly, copy) NSString *schema;
@property (readonly, copy) NSString *table;

/// SPPostgresColumn objects in attnum order (dropped columns excluded), or nil on failure.
- (NSArray *)columns:(NSError **)error;

/// YES when the relation is a table or partitioned table with a primary key.
- (BOOL)isEditable;

/// Why the rows can't be edited, or nil when they can.
- (NSString *)readOnlyReason;

/// A page of rows; limit 0 means no limit. column may be nil for no explicit sort; rows are then in primary-key order (if any), and the
/// primary key also breaks ties after the sort column, so paging is stable. filter may be nil.
- (NSArray *)rowsWithFilter:(SPPostgresFilter *)filter sortColumn:(NSString *)column ascending:(BOOL)ascending
					 offset:(NSUInteger)offset limit:(NSUInteger)limit error:(NSError **)error;

/// Exact count(*) of the rows matching filter (nil for all), or -1 on failure.
- (NSInteger)countRowsWithFilter:(SPPostgresFilter *)filter error:(NSError **)error;

/// Sets one column of the row identified by originalRow's primary-key values. value is an NSString or NSNull.
/// Fails with SPPostgresErrorRowChanged when no row matched.
- (BOOL)updateRow:(NSArray *)originalRow column:(NSString *)column value:(id)value error:(NSError **)error;

/// Inserts a row; columns missing from valuesByColumn (name -> NSString/NSNull) get their defaults.
/// Returns the inserted row (via RETURNING) in the same format as -rowsWithFilter:…, or nil on failure.
- (NSArray *)insertRowWithValues:(NSDictionary *)valuesByColumn error:(NSError **)error;

/// Inserts a copy of row (as returned by -rowsWithFilter:…): its values for every column, except generated and
/// auto-numbered ones (see SPPostgresColumn), which get their defaults. Returns the inserted row, as
/// -insertRowWithValues:error:, or nil on failure (a plain primary key the copy repeats fails with the server's error).
- (NSArray *)insertCopyOfRow:(NSArray *)row error:(NSError **)error;

/// Deletes the rows (as returned by -rowsWithFilter:…) by primary key, all or nothing; rows repeating a key are
/// deleted once. If any row is already gone, nothing is deleted and the error is SPPostgresErrorRowChanged.
/// Inside an open transaction on the connection it uses a savepoint, leaving that transaction open; inside an
/// aborted transaction it refuses.
- (BOOL)deleteRows:(NSArray *)rows error:(NSError **)error;

@end
