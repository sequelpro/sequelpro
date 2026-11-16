//
//  SPMySQLTransfer.h
//  Sequel Plus
//
//  Copies a MySQL database, or some of its tables, from one connection to another.
//

#import <Foundation/Foundation.h>

@class SPMySQLConnection;

extern NSString * const SPMySQLTransferErrorDomain __attribute__((visibility("default")));

typedef NS_ENUM(NSInteger, SPMySQLTransferErrorCode) {
	/// The settings or the target don't allow it (the same database, no tables, …)
	SPMySQLTransferErrorRefused = 1,
	/// A statement failed (before the swap: the target is unchanged)
	SPMySQLTransferErrorFailed = 2,
	SPMySQLTransferErrorCancelled = 3,
	/// The tables were swapped in, but some foreign keys, views, triggers, routines or events couldn't be created
	/// (named under SPMySQLTransferNotCreatedKey)
	SPMySQLTransferErrorIncomplete = 4
};

/// In an Incomplete error's userInfo: "view `v`: <server message>" strings.
extern NSString * const SPMySQLTransferNotCreatedKey __attribute__((visibility("default")));

typedef NS_ENUM(NSInteger, SPMySQLTransferMode) {
	/// Every table, view, routine and event in the target database is replaced by the copy.
	SPMySQLTransferEmptyTarget = 0,
	/// Only the copy's tables (and its views, routines and events) replace those of the same name; nothing else is
	/// touched.
	SPMySQLTransferOverwrite = 1
};

typedef NS_ENUM(NSInteger, SPMySQLTransferStep) {
	SPMySQLTransferChecking = 0,
	/// The source's definitions, in one consistent snapshot
	SPMySQLTransferReading = 1,
	/// Each table created in the target under a temporary name (stepIndex of stepCount, detail the table)
	SPMySQLTransferCreatingTables = 2,
	/// Each table's rows (stepIndex of stepCount tables, detail the table; tableRowsCopied of ~tableRowEstimate)
	SPMySQLTransferCopyingData = 3,
	/// One RENAME TABLE swaps the new tables in, then the replaced objects are dropped
	SPMySQLTransferSwapping = 4,
	/// Foreign keys, CHECK constraints, views, triggers, routines and events (stepIndex of stepCount, detail the object)
	SPMySQLTransferFinishing = 5
};

/**
 * A MySQL → MySQL transfer. Tables are created in the target under temporary names (`__spn_<n>`, without foreign keys
 * and CHECK constraints, whose names are schema-wide) and filled from the source, read in one consistent snapshot;
 * then one atomic RENAME TABLE swaps them in (the tables they replace move to `__spo_<n>` and are dropped). Until the
 * swap the target is unchanged: a failure or cancel drops the temporary tables. Then foreign keys, CHECK constraints,
 * views (in dependency order), triggers, routines and events are created; DEFINER clauses are left out (objects are
 * defined by the target connection's user) and views' references to the source database are made unqualified.
 *
 * Synchronous: run it on a background thread. Both connections are used only by this object while -run: runs; their
 * session settings (names, time zone, sql_mode, foreign key checks) are changed: close them afterwards.
 */
__attribute__((visibility("default")))
@interface SPMySQLTransfer : NSObject

- (instancetype)initWithSource:(SPMySQLConnection *)source database:(NSString *)sourceDatabase
						target:(SPMySQLConnection *)target database:(NSString *)targetDatabase;

/// The scope: YES, or tables (names) with their triggers (no views, routines or events).
@property BOOL wholeDatabase;
@property (copy) NSArray<NSString *> *tables;
/// Default SPMySQLTransferEmptyTarget.
@property SPMySQLTransferMode mode;

/// Largest INSERT sent (default 4 MiB; kept below the target's max_allowed_packet). For tests.
@property NSUInteger batchSize;

/// Called on the running thread at each step and object, and every few thousand rows; NO cancels (before the swap the
/// target is then unchanged; during Finishing what remains isn't created).
@property (copy) BOOL (^progress)(SPMySQLTransferStep step, NSString *detail);

/// Read from the progress block:
@property (readonly) NSUInteger stepIndex;
@property (readonly) NSUInteger stepCount;
@property (readonly) unsigned long long tableRowsCopied;
/// The server's estimate (information_schema.TABLES.TABLE_ROWS); 0 when unknown.
@property (readonly) unsigned long long tableRowEstimate;

/// Runs the transfer. NO with an error in SPMySQLTransferErrorDomain.
- (BOOL)run:(NSError **)error;

/// Results (also after an Incomplete failure):
@property (readonly) NSUInteger tablesCopied;
@property (readonly) unsigned long long rowsCopied;
/// Tables in the target that were replaced (Overwrite) or dropped (Empty mode), and other objects dropped
/// ("view `v`", "procedure `p`", …).
@property (readonly) NSArray<NSString *> *tablesReplaced;
@property (readonly) NSArray<NSString *> *objectsDropped;
/// "view `v`", "trigger `t`", … created after the swap, and those that couldn't be ("view `v`: message").
@property (readonly) NSArray<NSString *> *objectsCreated;
@property (readonly) NSArray<NSString *> *objectsNotCreated;

/// The source's CREATE TABLE without its foreign keys and CHECK constraints, for the table named name: the statement
/// creating it as temporaryName, and the ALTER TABLE adding them back (nil when none). For tests.
+ (NSString *)createStatement:(NSString *)create forTable:(NSString *)name asTemporary:(NSString *)temporaryName addingBack:(NSString **)alter;

/// statement without its DEFINER=user@host clause. For tests.
+ (NSString *)statementWithoutDefiner:(NSString *)statement;

@end
