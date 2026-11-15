#import <Foundation/Foundation.h>

@class PGPostgresConnection;

/// Keys of +partsForTable:inSchema:connection:error:'s dictionary.
extern NSString * const SPPostgresCreatePartTable __attribute__((visibility("default")));
extern NSString * const SPPostgresCreatePartIndexes __attribute__((visibility("default")));
extern NSString * const SPPostgresCreatePartForeignKeys __attribute__((visibility("default")));
extern NSString * const SPPostgresCreatePartTriggers __attribute__((visibility("default")));

/**
 * The SQL that creates a table or view as it is now, as the Table Info view's "Create syntax" shows it (MySQL's
 * SHOW CREATE TABLE has no PostgreSQL counterpart). Statements end with `;` and are separated by blank lines.
 * Every name the statement writes itself is quoted (SPPostgresQuoteIdentifier); the server's own parts
 * (pg_get_constraintdef, pg_get_indexdef, pg_get_triggerdef, pg_get_viewdef, pg_get_expr, format_type) are read
 * with an empty search_path, so they qualify every name outside pg_catalog and the result runs from any
 * search_path.
 *
 * A table (also unlogged, partitioned, a partition, an inheritance child, or a foreign table):
 *   CREATE TABLE "s"."t" (
 *       one line per column, in attnum order: the quoted name, format_type, COLLATE when the collation isn't the
 *       type's default, then GENERATED ALWAYS AS (expr) STORED (VIRTUAL on PostgreSQL 18), GENERATED ALWAYS | BY
 *       DEFAULT AS IDENTITY, or DEFAULT expr, then NOT NULL (on PostgreSQL 18 from the column's NOT NULL
 *       constraint, contype 'n': CONSTRAINT "n" NOT NULL when its name isn't the server's default
 *       table_column_not_null, and NO INHERIT; a NOT VALID one is added afterwards instead, see below);
 *       one CONSTRAINT "n" <pg_get_constraintdef> line per primary key, unique, check, foreign key and exclusion
 *       constraint;
 *   )
 *   then INHERITS ("s"."parent", …) for an inheritance child (whose inherited columns and constraints come from
 *   its parents and are left out), PARTITION BY <pg_get_partkeydef> for a partitioned table, WITH (reloptions).
 *   A partition is not written as an inheritance child but as CREATE TABLE "s"."p" PARTITION OF "s"."parent"
 *   [(its own constraints)] <pg_get_expr(relpartbound)> (FOR VALUES … or DEFAULT): its columns, constraints,
 *   indexes and triggers that come from the parent are left out.
 * Then:
 *   - a constraint that isn't validated (NOT NULL included), as ALTER TABLE … ADD CONSTRAINT … NOT VALID;
 *   - one pg_get_indexdef statement per index that backs no constraint (and isn't a partition's copy of its
 *     parent's index);
 *   - COMMENT ON TABLE and COMMENT ON COLUMN;
 *   - one pg_get_triggerdef statement per trigger that isn't internal (nor a partition's copy of its parent's),
 *     followed by ALTER TABLE … DISABLE TRIGGER (or ENABLE REPLICA / ALWAYS TRIGGER) when it isn't enabled as
 *     the default.
 *
 * A serial column appears as its DEFAULT nextval('…'::regclass): no sequence DDL is written (nor an identity
 * column's sequence options), so the statement runs as is only while that sequence exists. Nor is what a
 * partition or an inheritance child sets on a column it inherits (its own SET NOT NULL, DEFAULT, …): inherited
 * columns are left to the parent.
 *
 * A view: CREATE VIEW "s"."v" AS <pg_get_viewdef(oid, true)> (with its options and CHECK OPTION); a materialized
 * view: CREATE MATERIALIZED VIEW "s"."m" AS <definition> (WITH NO DATA when it isn't populated) and its
 * indexes. Either is followed by its comments and triggers.
 *
 * Reads run as SPPostgresRunAtomically does (a savepoint inside the user's transaction), so the session is left as
 * it was; inside an aborted transaction it fails without sending anything. Use on the connection's thread.
 */
__attribute__((visibility("default")))
@interface SPPostgresCreateStatement : NSObject

/// The statement, or nil on failure (SPPostgresErrorDomain; e.g. no such table, or not a table or view).
+ (NSString *)createStatementForTable:(NSString *)table inSchema:(NSString *)schema connection:(PGPostgresConnection *)connection error:(NSError **)error;

/**
 * The same statements split for a dump, under the keys below; each value is an NSString of `;`-terminated
 * statements separated by blank lines, @"" when there are none. nil on failure, as above.
 *   SPPostgresCreatePartTable: the CREATE statement without its FOREIGN KEY constraint lines, then the table's and
 *     columns' comments (a view: CREATE VIEW and its comments);
 *   SPPostgresCreatePartIndexes: the index statements;
 *   SPPostgresCreatePartForeignKeys: ALTER TABLE … ADD CONSTRAINT "n" <def> per foreign key, then every constraint
 *     that isn't validated (ALTER TABLE … ADD CONSTRAINT … NOT VALID, NOT NULL included): those are checked on new
 *     rows all the same, so a dump adds them after the data;
 *   SPPostgresCreatePartTriggers: the trigger statements and their ENABLE / DISABLE statements.
 */
+ (NSDictionary *)partsForTable:(NSString *)table inSchema:(NSString *)schema connection:(PGPostgresConnection *)connection error:(NSError **)error;

/// As above; with noData YES a populated materialized view is created WITH NO DATA too (a dump refreshes it after
/// the data).
+ (NSDictionary *)partsForTable:(NSString *)table inSchema:(NSString *)schema materializedViewWithNoData:(BOOL)noData connection:(PGPostgresConnection *)connection error:(NSError **)error;

/// +partsForTable:inSchema:materializedViewWithNoData:connection:error: for many @[schema, table] pairs at once, keyed
/// by the pair: the catalog is read with one query of each kind for them all (not one per table), so a dump of many
/// tables costs a few round trips to the server. nil on failure (a missing table fails them all).
+ (NSDictionary *)partsForTables:(NSArray *)tables materializedViewWithNoData:(BOOL)noData connection:(PGPostgresConnection *)connection error:(NSError **)error;

@end
