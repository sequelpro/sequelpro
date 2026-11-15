#import <Foundation/Foundation.h>

@class PGPostgresConnection;

typedef NS_ENUM(NSInteger, SPPostgresTransferMode) {
	/// Everything in the target database is removed first (every extension but plpgsql, every schema), then public is
	/// recreated as a fresh database has it.
	SPPostgresTransferEmptyTarget = 0,
	/// The copy's objects that already exist on the target are dropped and created again; nothing else is touched.
	SPPostgresTransferOverwrite = 1
};

typedef NS_ENUM(NSInteger, SPPostgresTransferPhase) {
	SPPostgresTransferChecking = 0,
	SPPostgresTransferReading = 1,
	/// The load begins (Empty mode reads what the target holds)
	SPPostgresTransferWriting = 2,
	/// The statements before the dump: Empty mode's emptying, Overwrite's drops
	SPPostgresTransferEmptying = 3,
	/// The dump's structure before the data (schemas, types, functions, sequences, tables, views)
	SPPostgresTransferCreating = 4,
	/// The data: each table's rows, then the sequences' values
	SPPostgresTransferLoadingData = 5,
	/// The structure after the data: indexes, foreign keys, triggers, refreshes, comments
	SPPostgresTransferFinishing = 6,
	/// COMMIT (fraction 1 once committed)
	SPPostgresTransferCommitting = 7,
	/// The source has been read whole (from the reading thread, fraction 1): it reads while the load runs
	SPPostgresTransferReadingDone = 8
};

/**
 * Copies a whole database, or some tables with what they need, from one Postgres connection to another, through a
 * temporary SQL dump: SPPostgresDumpWriter reads the source into the file (in one snapshot) on a thread of its own
 * while SPPostgresSQLImporter loads the file, following it as it grows, into the target in one transaction (its
 * statements batched, a few hundred per round trip), preceded by the mode's emptying or dropping statements. A
 * failure or cancel anywhere (on either side) leaves the target unchanged; the file is deleted on every path.
 *
 * Both connections must be idle (no transaction open) and are used only by this object while -run: runs. The load
 * leaves the target session's search_path empty (the dump sets it, as pg_dump's does): disconnect it afterwards.
 */
__attribute__((visibility("default")))
@interface SPPostgresTransfer : NSObject
{
	PGPostgresConnection *source;
	PGPostgresConnection *target;
	BOOL wholeDatabase;
	NSArray *tables;
	SPPostgresTransferMode mode;
	NSString *temporaryDirectory;
	BOOL (^progress)(SPPostgresTransferPhase phase, double fraction, NSString *detail);

	NSUInteger tablesCopied;
	NSArray *replacedObjects;
	NSArray *dependenciesCreated;
	NSArray *foreignTablesSkipped;
	NSArray *skippedSettings;
	NSUInteger readingTableIndex;
	NSUInteger readingTableCount;

	NSUInteger objectCount;
	NSUInteger readTableCount;
	unsigned long long readRowCount;
	NSArray *emptiedSchemas;
	NSArray *emptiedExtensions;
	NSArray *objectsToReplace;
	NSUInteger structureItemCount;
	NSUInteger postDataItemCount;
	NSUInteger loadStepIndex;
	NSUInteger loadStepCount;
	unsigned long long loadRowsWritten;
	unsigned long long loadTableRowsWritten;
	unsigned long long loadTableRowCount;
	BOOL loadingTableRows;
	BOOL loadTableRowCountKnown;
	BOOL failedWhileReading;
}

- (instancetype)initWithSource:(PGPostgresConnection *)source target:(PGPostgresConnection *)target;

/// The scope: set exactly one (the whole database, or @[schema, table] pairs with their dependencies).
@property BOOL wholeDatabase;
@property (copy) NSArray *tables;

/// Default SPPostgresTransferEmptyTarget.
@property SPPostgresTransferMode mode;

/// Where the dump is written (sequel-pro-transfer-<UUID>.sql); default NSTemporaryDirectory().
@property (copy) NSString *temporaryDirectory;

/**
 * Called one at a time, on the caller's thread or the reading thread: Checking (fraction 0, detail nil) while the
 * source and target are checked; Writing as the load begins (fraction 0, detail nil; Empty mode then reads the
 * target). Then, at the same time: from the reading thread, Reading (fraction 0, detail nil: the structure is read),
 * before each table's data and during long COPYs (fraction (tableIndex - 1) / tableCount, detail the table's name),
 * and ReadingDone once the source is read whole; and, as the dump loads, Emptying, Creating and Finishing before and after each statement (fraction
 * (loadStepIndex - 1) / loadStepCount, or 0 while the count isn't known yet; detail the statement shortened, see
 * +summaryOfStatement:), LoadingData before
 * each table's rows and with every chunk of them (fraction of the tables, detail the table "s"."t") and around the
 * sequences' values, then Committing (fraction 0, then 1 once committed). Returning NO cancels.
 */
@property (copy) BOOL (^progress)(SPPostgresTransferPhase phase, double fraction, NSString *detail);

/// During a Reading report (read them from the progress block): the table being read, from 1, and how many tables the
/// dump reads (partitioned parents included); 0 before the first Reading report.
@property (readonly) NSUInteger readingTableIndex;
@property (readonly) NSUInteger readingTableCount;

/// Read during the run (from the progress block), once known:
/// The copy's objects (Checking done; tables with their partitions, views, sequences, routines, types, extensions…).
@property (readonly) NSUInteger objectCount;
/// The tables whose rows the dump holds, and the rows (Reading done).
@property (readonly) NSUInteger readTableCount;
@property (readonly) unsigned long long readRowCount;
/// Empty mode: the schemas and extensions dropped (Emptying).
@property (readonly) NSArray *emptiedSchemas;
@property (readonly) NSArray *emptiedExtensions;
/// Overwrite: the target's objects dropped to be created again, as displayNames (Emptying).
@property (readonly) NSArray *objectsToReplace;
/// The statements of the structure before and after the data (Creating, Finishing).
@property (readonly) NSUInteger structureItemCount;
@property (readonly) NSUInteger postDataItemCount;
/// In Emptying, Creating, LoadingData (tables) and Finishing: the step running, from 1, of how many.
@property (readonly) NSUInteger loadStepIndex;
@property (readonly) NSUInteger loadStepCount;
/// LoadingData: rows written so far (of readRowCount), and of the table being written (of loadTableRowCount).
@property (readonly) unsigned long long loadRowsWritten;
@property (readonly) unsigned long long loadTableRowsWritten;
@property (readonly) unsigned long long loadTableRowCount;
/// LoadingData: YES while a table's rows load (detail its name), NO for the sequences' values.
@property (readonly) BOOL loadingTableRows;
/// LoadingData: loadTableRowCount is known (the source's reading has finished that table; it may still be reading it).
@property (readonly) BOOL loadTableRowCountKnown;
/// After a failed -run:: reading the source failed (the load was stopped because of it), not the load.
@property (readonly) BOOL failedWhileReading;

/// A statement on one line, up to its first parenthesis or AS (CREATE TABLE public.t, CREATE INDEX i ON public.t USING
/// btree, DROP SCHEMA a CASCADE), at most 100 characters.
+ (NSString *)summaryOfStatement:(NSString *)sql;

/**
 * Runs the transfer, synchronously: same-database check, the copy's objects and dependencies on the source, the
 * extension check, the copy's objects existing on the target, (Overwrite) a dry run of the drops (BEGIN, drops,
 * ROLLBACK), the dump to the temporary file, the load (in one transaction, the mode's statements first), and the
 * file's deletion. NO with an error in SPPostgresErrorDomain: SPPostgresErrorTransferRefused (the same database;
 * missing extensions, named under SPPostgresObjectsErrorKey), SPPostgresErrorHasDependents (the dry run: the
 * server's DETAIL lines under SPPostgresDependentsErrorKey), SPPostgresErrorCancelled, SPPostgresErrorInvalidSettings,
 * or the writer's or importer's error unchanged.
 */
- (BOOL)run:(NSError **)error;

/// Results of the last successful -run:.
/// Tables and partitions whose data the dump wrote (one COPY block each; partitioned parents hold none).
@property (readonly) NSUInteger tablesCopied;
/// The target's objects that were dropped and created again (Overwrite), as displayName strings in drop order.
@property (readonly) NSArray *replacedObjects;
/// The dependencies of a table copy the transfer created (those already on the target are reused), as displayNames.
@property (readonly) NSArray *dependenciesCreated;
/// The foreign tables left out of the copy, as @[schema, table] pairs (the writer's foreignTablesSkipped).
@property (readonly) NSArray *foreignTablesSkipped;
/// Settings the target didn't know (the importer's skippedSettings).
@property (readonly) NSArray *skippedSettings;

/// The names in the target's pg_available_extensions (installed extensions are always listed there). Called once
/// per run; a test seam.
- (NSArray *)availableExtensionsOnTarget:(NSError **)error;

/// Empty mode's statements: DROP EXTENSION … CASCADE (none when extensions is empty), DROP SCHEMA … CASCADE (none
/// when schemas is empty), then public as a fresh database of that server version has it. For tests.
+ (NSArray *)emptyingStatementsForSchemas:(NSArray *)schemas extensions:(NSArray *)extensions serverVersion:(NSInteger)versionNumber;

/// Overwrite mode's statements for SPPostgresDumpObjects carrying the target's kinds: one DROP … IF EXISTS per kind
/// (RESTRICT), in the order materialized views, views, foreign tables, tables, sequences, routines, domains, types
/// (extensions are never dropped). For tests.
+ (NSArray *)dropStatementsForObjects:(NSArray *)targetObjects;

@end
