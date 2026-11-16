#import <XCTest/XCTest.h>
#import "../Source/SPMySQLTransfer.h"

// SPMySQL's headers aren't visible to the test bundle: what the tests use, declared
@interface NSObject (SPMySQLTransferTests)
- (BOOL)connect;
- (BOOL)isConnected;
- (void)disconnect;
- (id)queryString:(NSString *)query;
- (BOOL)queryErrored;
- (NSString *)lastErrorMessage;
- (void)setReturnDataAsStrings:(BOOL)flag;
- (NSArray *)getRowAsArray;
@end

static NSString * const SPTransferSource = @"sp_tr_src";
static NSString * const SPTransferTarget = @"sp_tr_dst";

/**
 * MySQL → MySQL transfers on a real server: the throwaway docker container sp-mysql8 (127.0.0.1:55438, root / sptest;
 * see SPMySQLFieldEditorSheetTests). Skipped when it isn't running. The test databases sp_tr_src and sp_tr_dst are
 * created and dropped here.
 */
@interface SPMySQLTransferTests : XCTestCase
@property (strong) id admin;
@property (strong) NSMutableArray *connections;
@end

@implementation SPMySQLTransferTests

- (id)connection
{
	id connection = [[NSClassFromString(@"SPMySQLConnection") alloc] init];
	[connection setValue:@"127.0.0.1" forKey:@"host"];
	[connection setValue:@55438 forKey:@"port"];
	[connection setValue:@"root" forKey:@"username"];
	[connection setValue:@"sptest" forKey:@"password"];
	[connection setValue:@5 forKey:@"timeout"];
	if (![connection connect] || ![connection isConnected]) return nil;
	[self.connections addObject:connection];
	return connection;
}

- (void)run:(NSString *)sql
{
	[self.admin queryString:sql];
	XCTAssertFalse([self.admin queryErrored], @"%@: %@", sql, [self.admin lastErrorMessage]);
}

- (NSArray *)rows:(NSString *)sql on:(id)connection
{
	id result = [connection queryString:sql];
	XCTAssertFalse([connection queryErrored], @"%@: %@", sql, [connection lastErrorMessage]);
	[result setReturnDataAsStrings:YES];
	NSMutableArray *rows = [NSMutableArray array];
	NSArray *row = nil;
	while ((row = [result getRowAsArray])) [rows addObject:row];
	return rows;
}

- (NSArray *)rows:(NSString *)sql
{
	return [self rows:sql on:self.admin];
}

- (void)setUp
{
	self.continueAfterFailure = NO;
	self.connections = [NSMutableArray array];
	self.admin = [self connection];
	if (!self.admin) return;
	[self run:@"SET SESSION sql_mode = 'NO_AUTO_VALUE_ON_ZERO'"];
	for (NSString *database in @[SPTransferSource, SPTransferTarget]) {
		[self run:[NSString stringWithFormat:@"DROP DATABASE IF EXISTS %@", database]];
		[self run:[NSString stringWithFormat:@"CREATE DATABASE %@ CHARACTER SET utf8mb4", database]];
	}

	// The source
	[self run:@"USE sp_tr_src"];
	[self run:@"CREATE TABLE parent (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(50) NOT NULL, CONSTRAINT parent_chk_1 CHECK (name <> ''))"];
	[self run:@"CREATE TABLE child (id INT AUTO_INCREMENT PRIMARY KEY, parent_id INT, note TEXT, data BLOB, flags BIT(5), price DECIMAL(10,2),"
			  " seen TIMESTAMP NULL, doubled DECIMAL(12,2) GENERATED ALWAYS AS (price * 2) STORED, KEY (parent_id),"
			  " CONSTRAINT child_parent FOREIGN KEY (parent_id) REFERENCES parent (id) ON DELETE CASCADE)"];
	[self run:@"INSERT INTO parent (id, name) VALUES (1, 'one'), (2, '日本語 ✓'), (3, 'it''s \\\\ \"q\"')"];
	[self run:@"INSERT INTO child (parent_id, note, data, flags, price, seen) VALUES"
			  " (1, 'line\\nbreak', 0x00FF27, b'10101', 12.50, '2026-11-16 01:02:03'),"
			  " (2, NULL, NULL, NULL, NULL, NULL),"
			  " (3, '', '', b'0', -0.01, '1999-12-31 23:59:59')"];
	[self run:@"CREATE TABLE big (id INT PRIMARY KEY, v VARCHAR(40))"];
	[self run:@"SET SESSION cte_max_recursion_depth = 10000"];
	[self run:@"INSERT INTO big WITH RECURSIVE n (i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n WHERE i < 5000) SELECT i, MD5(i) FROM n"];
	// a_view reads z_view: created in dependency order, not by name
	[self run:@"CREATE VIEW z_view AS SELECT id, name FROM parent"];
	[self run:@"CREATE VIEW a_view AS SELECT id FROM z_view WHERE id > 1"];
	[self run:@"CREATE DEFINER = `nobody_here`@`localhost` SQL SECURITY INVOKER VIEW invoker_view AS SELECT COUNT(*) AS n FROM child"];
	[self run:@"CREATE TRIGGER child_bi BEFORE INSERT ON child FOR EACH ROW SET NEW.note = IFNULL(NEW.note, 'none')"];
	[self run:@"CREATE PROCEDURE p_count(OUT n INT) BEGIN SELECT COUNT(*) INTO n FROM parent; END"];
	[self run:@"CREATE FUNCTION f_double(x INT) RETURNS INT DETERMINISTIC RETURN x * 2"];
	[self run:@"CREATE EVENT e_daily ON SCHEDULE EVERY 1 DAY DISABLE DO DELETE FROM big WHERE id < 0"];

	// The target holds other things
	[self run:@"USE sp_tr_dst"];
	[self run:@"CREATE TABLE parent (old_column INT)"];
	[self run:@"INSERT INTO parent VALUES (42)"];
	[self run:@"CREATE TABLE stale (id INT)"];
	[self run:@"CREATE VIEW old_view AS SELECT 1 AS one"];
	[self run:@"CREATE PROCEDURE old_proc() SELECT 1"];
	[self run:@"USE mysql"];
}

- (void)tearDown
{
	if (self.admin) {
		for (NSString *database in @[SPTransferSource, SPTransferTarget]) [self.admin queryString:[NSString stringWithFormat:@"DROP DATABASE IF EXISTS %@", database]];
	}
	for (id connection in self.connections) [connection disconnect];
	self.connections = nil;
	self.admin = nil;
}

- (SPMySQLTransfer *)transfer
{
	id source = [self connection], target = [self connection];
	return [[SPMySQLTransfer alloc] initWithSource:source database:SPTransferSource target:target database:SPTransferTarget];
}

/// "name kind" of every table and view, and of routines, events and triggers.
- (NSArray *)objectsIn:(NSString *)database
{
	NSMutableArray *objects = [NSMutableArray array];
	for (NSArray *row in [self rows:[NSString stringWithFormat:@"SELECT TABLE_NAME, TABLE_TYPE FROM information_schema.TABLES WHERE TABLE_SCHEMA = '%@' ORDER BY 1", database]]) [objects addObject:[NSString stringWithFormat:@"%@ %@", row[0], row[1]]];
	for (NSArray *row in [self rows:[NSString stringWithFormat:@"SELECT ROUTINE_NAME, ROUTINE_TYPE FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = '%@' ORDER BY 1", database]]) [objects addObject:[NSString stringWithFormat:@"%@ %@", row[0], row[1]]];
	for (NSArray *row in [self rows:[NSString stringWithFormat:@"SELECT EVENT_NAME FROM information_schema.EVENTS WHERE EVENT_SCHEMA = '%@' ORDER BY 1", database]]) [objects addObject:[NSString stringWithFormat:@"%@ EVENT", row[0]]];
	for (NSArray *row in [self rows:[NSString stringWithFormat:@"SELECT TRIGGER_NAME, EVENT_OBJECT_TABLE FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = '%@' ORDER BY 1", database]]) [objects addObject:[NSString stringWithFormat:@"%@ TRIGGER ON %@", row[0], row[1]]];
	return objects;
}

- (NSString *)checksumOf:(NSString *)table inDatabase:(NSString *)database
{
	NSArray *rows = [self rows:[NSString stringWithFormat:@"CHECKSUM TABLE %@.%@ EXTENDED", database, table]];
	return rows.count ? rows[0][1] : nil;
}

- (NSString *)firstValue:(NSString *)sql
{
	NSArray *rows = [self rows:sql];
	return rows.count ? rows[0][0] : nil;
}

#pragma mark - Statements

- (void)testCreateStatementLeavesOutForeignKeysAndChecks
{
	NSString *create = @"CREATE TABLE `child` (\n  `id` int NOT NULL AUTO_INCREMENT,\n  `parent_id` int DEFAULT NULL,\n  PRIMARY KEY (`id`),\n"
					   "  KEY `parent_id` (`parent_id`),\n  CONSTRAINT `child_parent` FOREIGN KEY (`parent_id`) REFERENCES `parent` (`id`) ON DELETE CASCADE,\n"
					   "  CONSTRAINT `child_chk_1` CHECK ((`id` > 0))\n) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4";
	NSString *alter = nil;
	NSString *temporary = [SPMySQLTransfer createStatement:create forTable:@"child" asTemporary:@"__spn_1" addingBack:&alter];
	XCTAssertEqualObjects(temporary, @"CREATE TABLE `__spn_1` (\n  `id` int NOT NULL AUTO_INCREMENT,\n  `parent_id` int DEFAULT NULL,\n  PRIMARY KEY (`id`),\n"
						  "  KEY `parent_id` (`parent_id`)\n) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4");
	XCTAssertEqualObjects(alter, @"ALTER TABLE `child` ADD CONSTRAINT `child_parent` FOREIGN KEY (`parent_id`) REFERENCES `parent` (`id`) ON DELETE CASCADE, ADD CONSTRAINT `child_chk_1` CHECK ((`id` > 0))");

	// None to add back
	alter = @"x";
	XCTAssertEqualObjects([SPMySQLTransfer createStatement:@"CREATE TABLE `a``b` (\n  `id` int\n)" forTable:@"a`b" asTemporary:@"__spn_2" addingBack:&alter], @"CREATE TABLE `__spn_2` (\n  `id` int\n)");
	XCTAssertNil(alter);
}

- (void)testStatementWithoutDefiner
{
	XCTAssertEqualObjects([SPMySQLTransfer statementWithoutDefiner:@"CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`%` SQL SECURITY DEFINER VIEW `v` AS select 1"],
						  @"CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `v` AS select 1");
	XCTAssertEqualObjects([SPMySQLTransfer statementWithoutDefiner:@"CREATE DEFINER='a b'@'localhost' PROCEDURE `p`() SELECT 1"], @"CREATE PROCEDURE `p`() SELECT 1");
	XCTAssertEqualObjects([SPMySQLTransfer statementWithoutDefiner:@"CREATE PROCEDURE `p`() SELECT 'DEFINER'"], @"CREATE PROCEDURE `p`() SELECT 'DEFINER'");
}

#pragma mark - Transfers

- (void)testWholeDatabaseIntoAnEmptiedTarget
{
	if (!self.admin) { XCTSkip(@"no MySQL test server on 127.0.0.1:55438 (docker sp-mysql8)"); }
	SPMySQLTransfer *transfer = [self transfer];
	transfer.wholeDatabase = YES;
	NSMutableArray *steps = [NSMutableArray array];
	NSMutableArray *finished = [NSMutableArray array];
	__weak SPMySQLTransfer *engine = transfer;
	transfer.progress = ^BOOL(SPMySQLTransferStep step, NSString *detail) {
		if (![steps.lastObject isEqual:@(step)]) [steps addObject:@(step)];
		if (step == SPMySQLTransferFinishing && detail) [finished addObject:detail];
		XCTAssertLessThanOrEqual(engine.stepIndex, engine.stepCount);
		return YES;
	};
	NSError *error = nil;
	XCTAssertTrue([transfer run:&error], @"%@ %@", error.localizedDescription, error.userInfo);
	XCTAssertEqualObjects(steps, (@[@(SPMySQLTransferChecking), @(SPMySQLTransferReading), @(SPMySQLTransferCreatingTables),
									@(SPMySQLTransferCopyingData), @(SPMySQLTransferSwapping), @(SPMySQLTransferFinishing)]));
	XCTAssertEqual(transfer.tablesCopied, 3u);
	XCTAssertEqual(transfer.rowsCopied, 5006ull);

	// The same objects, nothing else left (the target's own are gone, no temporary tables)
	XCTAssertEqualObjects([self objectsIn:SPTransferTarget], [self objectsIn:SPTransferSource]);
	XCTAssertEqualObjects(transfer.tablesReplaced, (@[@"parent", @"stale"]));
	XCTAssertTrue([transfer.objectsDropped containsObject:@"view `old_view`"], @"%@", transfer.objectsDropped);
	XCTAssertTrue([transfer.objectsDropped containsObject:@"procedure `old_proc`"], @"%@", transfer.objectsDropped);
	XCTAssertEqual(transfer.objectsNotCreated.count, 0u);
	// a_view (tried first, by name) is created after z_view, which it reads
	XCTAssertLessThan([finished indexOfObject:@"view `a_view`"], [finished indexOfObject:@"view `z_view`"], @"%@", finished);
	XCTAssertLessThan([transfer.objectsCreated indexOfObject:@"view `z_view`"], [transfer.objectsCreated indexOfObject:@"view `a_view`"], @"%@", transfer.objectsCreated);
	XCTAssertTrue([transfer.objectsCreated containsObject:@"view `a_view`"]);

	// The rows, exactly (binary, BIT, NULL, quotes, line breaks, Unicode, the generated column)
	for (NSString *table in @[@"parent", @"child", @"big"]) {
		XCTAssertEqualObjects([self checksumOf:table inDatabase:SPTransferTarget], [self checksumOf:table inDatabase:SPTransferSource], @"%@", table);
	}
	XCTAssertEqualObjects([self firstValue:@"SELECT GROUP_CONCAT(IFNULL(doubled, 'n') ORDER BY id) FROM sp_tr_dst.child"], @"25.00,n,-0.02");
	XCTAssertEqualObjects([self firstValue:@"SELECT HEX(data) FROM sp_tr_dst.child WHERE id = 1"], @"00FF27");
	XCTAssertEqualObjects([self firstValue:@"SELECT BIN(flags) FROM sp_tr_dst.child WHERE id = 1"], @"10101");
	XCTAssertEqualObjects([self firstValue:@"SELECT seen FROM sp_tr_dst.child WHERE id = 1"], @"2026-11-16 01:02:03");
	XCTAssertEqualObjects([self firstValue:@"SELECT name FROM sp_tr_dst.parent WHERE id = 2"], @"日本語 ✓");

	// Constraints back, the counter kept, the views and routines working
	XCTAssertEqualObjects([self firstValue:@"SELECT GROUP_CONCAT(CONSTRAINT_NAME) FROM information_schema.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = 'sp_tr_dst'"], @"child_parent");
	XCTAssertEqualObjects([self firstValue:@"SELECT GROUP_CONCAT(CONSTRAINT_NAME) FROM information_schema.CHECK_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = 'sp_tr_dst'"], @"parent_chk_1");
	XCTAssertEqualObjects([self firstValue:@"SELECT AUTO_INCREMENT FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'sp_tr_dst' AND TABLE_NAME = 'child'"],
						  [self firstValue:@"SELECT AUTO_INCREMENT FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'sp_tr_src' AND TABLE_NAME = 'child'"]);
	XCTAssertEqualObjects([self firstValue:@"SELECT COUNT(*) FROM sp_tr_dst.a_view"], @"2");
	XCTAssertEqualObjects([self firstValue:@"SELECT sp_tr_dst.f_double(21)"], @"42");
	// The view reads the target's tables, not the source's
	XCTAssertEqualObjects([self firstValue:@"SELECT COUNT(*) FROM information_schema.VIEWS WHERE TABLE_SCHEMA = 'sp_tr_dst' AND VIEW_DEFINITION LIKE '%sp_tr_src%'"], @"0");
	// DEFINER left out: the target's user defines them
	XCTAssertEqualObjects([self firstValue:@"SELECT DEFINER FROM information_schema.VIEWS WHERE TABLE_SCHEMA = 'sp_tr_dst' AND TABLE_NAME = 'invoker_view'"],
						  [self firstValue:@"SELECT CURRENT_USER()"]);
	// The trigger runs
	[self run:@"INSERT INTO sp_tr_dst.child (parent_id) VALUES (1)"];
	XCTAssertEqualObjects([self firstValue:@"SELECT note FROM sp_tr_dst.child ORDER BY id DESC LIMIT 1"], @"none");
	// The foreign key holds
	[self.admin queryString:@"INSERT INTO sp_tr_dst.child (parent_id) VALUES (99)"];
	XCTAssertTrue([self.admin queryErrored], @"the foreign key is checked");
}

- (void)testOverwriteReplacesOnlyTheCopiedTables
{
	if (!self.admin) { XCTSkip(@"no MySQL test server on 127.0.0.1:55438 (docker sp-mysql8)"); }
	SPMySQLTransfer *transfer = [self transfer];
	transfer.tables = @[@"parent", @"child"];
	transfer.mode = SPMySQLTransferOverwrite;
	NSError *error = nil;
	XCTAssertTrue([transfer run:&error], @"%@ %@", error.localizedDescription, error.userInfo);
	XCTAssertEqualObjects(transfer.tablesReplaced, @[@"parent"]);
	XCTAssertEqual(transfer.objectsDropped.count, 0u);
	NSArray *objects = [self objectsIn:SPTransferTarget];
	for (NSString *kept in @[@"stale BASE TABLE", @"old_view VIEW", @"old_proc PROCEDURE"]) XCTAssertTrue([objects containsObject:kept], @"%@: %@", kept, objects);
	for (NSString *copied in @[@"parent BASE TABLE", @"child BASE TABLE", @"child_bi TRIGGER ON child"]) XCTAssertTrue([objects containsObject:copied], @"%@: %@", copied, objects);
	for (NSString *notCopied in @[@"big BASE TABLE", @"a_view VIEW", @"p_count PROCEDURE", @"e_daily EVENT"]) XCTAssertFalse([objects containsObject:notCopied], @"%@: %@", notCopied, objects);
	XCTAssertEqualObjects([self checksumOf:@"parent" inDatabase:SPTransferTarget], [self checksumOf:@"parent" inDatabase:SPTransferSource]);
	XCTAssertEqualObjects([self firstValue:@"SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'sp_tr_dst' AND TABLE_NAME LIKE '\\_\\_sp%'"], @"0");
}

/// Cancelled while the data is copied (before the swap): the target is as it was, its temporary tables gone.
- (void)testCancelBeforeTheSwapLeavesTheTargetUnchanged
{
	if (!self.admin) { XCTSkip(@"no MySQL test server on 127.0.0.1:55438 (docker sp-mysql8)"); }
	NSArray *before = [self objectsIn:SPTransferTarget];
	NSString *parentBefore = [self checksumOf:@"parent" inDatabase:SPTransferTarget];
	SPMySQLTransfer *transfer = [self transfer];
	transfer.wholeDatabase = YES;
	__block BOOL cancelled = NO;
	__weak SPMySQLTransfer *engine = transfer;
	transfer.progress = ^BOOL(SPMySQLTransferStep step, NSString *detail) {
		// Partway through big's rows
		if (step == SPMySQLTransferCopyingData && [detail isEqualToString:@"big"] && engine.tableRowsCopied >= 2000) {
			cancelled = YES;
			return NO;
		}
		return YES;
	};
	NSError *error = nil;
	XCTAssertFalse([transfer run:&error]);
	XCTAssertTrue(cancelled);
	XCTAssertEqualObjects(error.domain, SPMySQLTransferErrorDomain);
	XCTAssertEqual(error.code, SPMySQLTransferErrorCancelled);
	XCTAssertEqualObjects([self objectsIn:SPTransferTarget], before);
	XCTAssertEqualObjects([self checksumOf:@"parent" inDatabase:SPTransferTarget], parentBefore);
}

/// The target fails a statement while the data is copied (its temporary table dropped from under it): the
/// temporary tables made so far go and the target is unchanged; the error is the target's.
- (void)testTargetFailureBeforeTheSwapLeavesTheTargetUnchanged
{
	if (!self.admin) { XCTSkip(@"no MySQL test server on 127.0.0.1:55438 (docker sp-mysql8)"); }
	NSArray *before = [self objectsIn:SPTransferTarget];
	NSString *parentBefore = [self checksumOf:@"parent" inDatabase:SPTransferTarget];
	SPMySQLTransfer *transfer = [self transfer];
	transfer.wholeDatabase = YES;
	__weak SPMySQLTransfer *engine = transfer;
	__block NSString *dropped = nil;
	transfer.progress = ^BOOL(SPMySQLTransferStep step, NSString *detail) {
		// child's temporary table (the tables go in name order: big, child, parent)
		if (step == SPMySQLTransferCopyingData && [detail isEqualToString:@"child"] && !dropped) {
			dropped = [NSString stringWithFormat:@"__spn_%lu", (unsigned long)engine.stepIndex];
			[self run:[NSString stringWithFormat:@"DROP TABLE sp_tr_dst.%@", dropped]];
		}
		return YES;
	};
	NSError *error = nil;
	XCTAssertFalse([transfer run:&error]);
	XCTAssertEqualObjects(dropped, @"__spn_2");
	XCTAssertEqualObjects(error.domain, SPMySQLTransferErrorDomain);
	XCTAssertEqual(error.code, SPMySQLTransferErrorFailed, @"%@", error.localizedDescription);
	XCTAssertTrue([error.localizedDescription hasPrefix:@"The target refused a statement: "], @"%@", error.localizedDescription);
	XCTAssertEqualObjects([self objectsIn:SPTransferTarget], before);
	XCTAssertEqualObjects([self checksumOf:@"parent" inDatabase:SPTransferTarget], parentBefore);
}

/// Rows go in INSERTs no longer than batchSize: many statements, every row arrives.
- (void)testSmallBatchesCopyEveryRow
{
	if (!self.admin) { XCTSkip(@"no MySQL test server on 127.0.0.1:55438 (docker sp-mysql8)"); }
	SPMySQLTransfer *transfer = [self transfer];
	transfer.tables = @[@"big", @"child", @"parent"];
	transfer.mode = SPMySQLTransferOverwrite;
	transfer.batchSize = 2000;
	NSError *error = nil;
	XCTAssertTrue([transfer run:&error], @"%@", error.localizedDescription);
	XCTAssertEqualObjects([self checksumOf:@"big" inDatabase:SPTransferTarget], [self checksumOf:@"big" inDatabase:SPTransferSource]);
	XCTAssertEqualObjects([self checksumOf:@"child" inDatabase:SPTransferTarget], [self checksumOf:@"child" inDatabase:SPTransferSource]);
}

/// Leftovers of a transfer that stopped (a lost connection before the swap) are dropped first.
- (void)testLeftoverTemporaryTablesAreDropped
{
	if (!self.admin) { XCTSkip(@"no MySQL test server on 127.0.0.1:55438 (docker sp-mysql8)"); }
	[self run:@"CREATE TABLE sp_tr_dst.__spn_7 (id INT)"];
	[self run:@"CREATE TABLE sp_tr_dst.__spo_3 (id INT)"];
	SPMySQLTransfer *transfer = [self transfer];
	transfer.tables = @[@"parent"];
	transfer.mode = SPMySQLTransferOverwrite;
	NSError *error = nil;
	XCTAssertTrue([transfer run:&error], @"%@", error.localizedDescription);
	XCTAssertEqualObjects([self firstValue:@"SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'sp_tr_dst' AND TABLE_NAME LIKE '\\_\\_sp%'"], @"0");
}

- (void)testSameDatabaseIsRefused
{
	if (!self.admin) { XCTSkip(@"no MySQL test server on 127.0.0.1:55438 (docker sp-mysql8)"); }
	SPMySQLTransfer *transfer = [[SPMySQLTransfer alloc] initWithSource:[self connection] database:SPTransferSource target:[self connection] database:SPTransferSource];
	transfer.wholeDatabase = YES;
	NSError *error = nil;
	XCTAssertFalse([transfer run:&error]);
	XCTAssertEqual(error.code, SPMySQLTransferErrorRefused);
	XCTAssertEqualObjects(error.localizedDescription, @"The target is the database being copied.");
	XCTAssertEqualObjects([self firstValue:@"SELECT COUNT(*) FROM sp_tr_src.parent"], @"3");
}

@end
