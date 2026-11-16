#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "../Source/SPWindowController.h"
#import "../Source/SPMySQLTransferController.h"
#import "../Source/SPMySQLFavoriteConnector.h"
#import "../Source/Postgres/SPPostgresProgressSheet.h"
#import "../Source/Postgres/SPPostgresCheckList.h"

@interface NSObject (SPMySQLTransferControllerTests)
- (id)connectionController;
- (void)initiateConnection:(id)sender;
- (id)getConnection;
- (BOOL)isConnected;
- (BOOL)isWorking;
- (id)queryString:(NSString *)query;
- (BOOL)queryErrored;
- (NSString *)lastErrorMessage;
- (NSArray *)getRowAsArray;
- (void)setReturnDataAsStrings:(BOOL)flag;
- (void)updateTables:(id)sender;
- (void)selectDatabase:(NSString *)database item:(NSString *)item;
- (NSString *)database;
- (BOOL)validateToolbarItem:(NSToolbarItem *)item;
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)flag;
@end

/**
 * The MySQL Transfer sheet on a real MySQL tab (docker sp-mysql8, 127.0.0.1:55438, root / sptest; skipped when it
 * isn't running): the tab on sp_tr_src, the target favorite on the same server, its session through
 * SPMySQLFavoriteConnector with the password given (the keychain is never read).
 */
@interface SPMySQLTransferControllerTests : XCTestCase
@property (strong) SPWindowController *windowController;
@property (strong) id document;
@property (strong) SPMySQLTransferController *controller;
@property BOOL ended;
@end

@implementation SPMySQLTransferControllerTests

- (BOOL)spinUntil:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout
{
	NSDate *end = [NSDate dateWithTimeIntervalSinceNow:timeout];
	while (!condition()) {
		if ([end timeIntervalSinceNow] < 0) return NO;
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
	}
	return YES;
}

- (void)spin:(NSTimeInterval)seconds
{
	[self spinUntil:^BOOL{ return NO; } timeout:seconds];
}

- (void)run:(NSString *)sql
{
	id connection = [self.document getConnection];
	[connection queryString:sql];
	XCTAssertFalse([connection queryErrored], @"%@: %@", sql, [connection lastErrorMessage]);
}

- (NSString *)value:(NSString *)sql
{
	id connection = [self.document getConnection];
	id result = [connection queryString:sql];
	XCTAssertFalse([connection queryErrored], @"%@: %@", sql, [connection lastErrorMessage]);
	[result setReturnDataAsStrings:YES];
	return [[result getRowAsArray] firstObject];
}

- (void)setUp
{
	self.continueAfterFailure = NO;
	SPWindowController *controller = [[SPWindowController alloc] initWithWindowNibName:@"MainWindow"];
	self.windowController = controller;
	[controller showWindow:nil];
	[[controller window] setFrameOrigin:NSMakePoint(-10000, -10000)];
	id mysql = [controller addNewConnection];
	self.document = mysql;
	[self spin:0.3];
	__weak SPMySQLTransferControllerTests *weakSelf = self;
	[self addTeardownBlock:^{
		SPMySQLTransferControllerTests *me = weakSelf;
		if (me.controller && !me.ended) {
			[me.controller cancel:nil];
			[me spinUntil:^BOOL{ return me.ended; } timeout:20];
		}
		NSWindow *window = [controller window];
		while (window.attachedSheet) [window endSheet:window.attachedSheet];
		if ([[mysql getConnection] isConnected]) {
			for (NSString *database in @[@"sp_tr_src", @"sp_tr_dst", @"sp_tr_made"]) [[mysql getConnection] queryString:[NSString stringWithFormat:@"DROP DATABASE IF EXISTS %@", database]];
		}
		NSTabView *tabView = [controller valueForKey:@"tabView"];
		for (NSTabViewItem *item in [tabView tabViewItems]) [tabView removeTabViewItem:item];
		[window orderOut:nil];
		[me spin:0.5];
	}];

	// The source database, made over a first connection to the server (as root, no database)
	id form = [mysql connectionController];
	[form setValue:@0 forKey:@"type"];
	[form setValue:@"127.0.0.1" forKey:@"host"];
	[form setValue:@"55438" forKey:@"port"];
	[form setValue:@"root" forKey:@"user"];
	[form setValue:@"sptest" forKey:@"password"];
	[form setValue:@"mysql" forKey:@"database"];
	[form initiateConnection:nil];
	if (![self spinUntil:^BOOL{ return [[mysql getConnection] isConnected] && ![mysql isWorking]; } timeout:20]) {
		for (NSWindow *window in [NSApp windows]) if ([window attachedSheet]) [window endSheet:[window attachedSheet]];
		self.document = nil;
		return;
	}
	for (NSString *database in @[@"sp_tr_src", @"sp_tr_dst", @"sp_tr_made"]) [self run:[NSString stringWithFormat:@"DROP DATABASE IF EXISTS %@", database]];
	[self run:@"CREATE DATABASE sp_tr_src CHARACTER SET utf8mb4"];
	[self run:@"CREATE DATABASE sp_tr_dst CHARACTER SET utf8mb4"];
	[self run:@"CREATE TABLE sp_tr_src.parent (id INT PRIMARY KEY, name VARCHAR(50))"];
	[self run:@"CREATE TABLE sp_tr_src.child (id INT PRIMARY KEY, parent_id INT, CONSTRAINT child_parent FOREIGN KEY (parent_id) REFERENCES sp_tr_src.parent (id))"];
	[self run:@"INSERT INTO sp_tr_src.parent VALUES (1, 'one'), (2, 'two')"];
	[self run:@"INSERT INTO sp_tr_src.child VALUES (10, 1), (11, 2), (12, NULL)"];
	[self run:@"CREATE VIEW sp_tr_src.names AS SELECT name FROM sp_tr_src.parent"];
	[self run:@"CREATE TABLE sp_tr_dst.leftover (id INT)"];
	// The tab on the source database
	[mysql selectDatabase:@"sp_tr_src" item:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return [[mysql database] isEqualToString:@"sp_tr_src"] && ![mysql isWorking]; } timeout:20]);
	[[mysql valueForKey:@"tablesListInstance"] updateTables:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return ![mysql isWorking]; } timeout:20]);
}

- (NSDictionary *)favoriteNamed:(NSString *)name identifier:(NSInteger)identifier database:(NSString *)database
{
	return @{@"id": @(identifier), @"name": name, @"type": @0, @"host": @"127.0.0.1", @"port": @"55438", @"user": @"root", @"database": database ?: @""};
}

- (SPMySQLTransferController *)openSheetWithFavorites:(NSArray *)favorites
{
	SPMySQLTransferController *controller = [[SPMySQLTransferController alloc] initWithDocument:self.document];
	self.controller = controller;
	self.ended = NO;
	__weak SPMySQLTransferControllerTests *weakSelf = self;
	controller.didEnd = ^{ weakSelf.ended = YES; };
	controller.favorites = favorites;
	controller.ownFavoriteID = @"500";
	controller.filteredMenuOpener = ^(NSPopUpButton *popup) {};
	// The session with the password given: no keychain
	__block SPMySQLFavoriteConnector *connector = nil;
	controller.targetConnect = ^(NSDictionary *favorite, NSString *password, void (^completion)(id connection, NSError *error)) {
		connector = [[SPMySQLFavoriteConnector alloc] initWithFavorite:favorite password:@"sptest" parentWindow:nil];
		SPMySQLFavoriteConnector *theConnector = connector;
		[theConnector connectWithCompletion:^(id connection, NSError *error) {
			(void)theConnector; // kept until it answers
			completion(connection, error);
		}];
	};
	[controller beginSheet];
	XCTAssertTrue([self spinUntil:^BOOL{ return controller.selectedDatabase != nil || controller.targetStatusField.stringValue.length > 0; } timeout:20], @"the session opens");
	return controller;
}

- (void)testSheetOffersTheTablesAndTheOtherFavorites
{
	if (!self.document) { XCTSkip(@"no MySQL test server on 127.0.0.1:55438 (docker sp-mysql8)"); }
	NSArray *favorites = @[[self favoriteNamed:@"This tab" identifier:500 database:@"sp_tr_src"], [self favoriteNamed:@"Test target" identifier:501 database:@"sp_tr_dst"]];
	SPMySQLTransferController *controller = [self openSheetWithFavorites:favorites];
	XCTAssertEqual([self.windowController window].attachedSheet, controller.sheet);
	XCTAssertEqualObjects(controller.wholeDatabaseRadio.title, @"Whole database “sp_tr_src”");
	XCTAssertEqualObjects([NSSet setWithArray:controller.tablesList.rows], ([NSSet setWithArray:@[@"parent", @"child"]]), @"tables, not views");
	XCTAssertEqualObjects(controller.favoritePopup.titleOfSelectedItem, @"Test target", @"not this tab's favorite");
	XCTAssertEqualObjects(controller.targetDescriptionField.stringValue, @"root@127.0.0.1:55438");
	XCTAssertTrue([controller.ownershipNoteField.stringValue containsString:@"“root”"], @"%@", controller.ownershipNoteField.stringValue);
	XCTAssertEqualObjects(controller.selectedDatabase, @"sp_tr_dst", @"the favorite's database");
	NSMutableArray *listed = [NSMutableArray array];
	for (NSMenuItem *item in controller.databasePopup.itemArray) if (item.representedObject) [listed addObject:item.representedObject];
	XCTAssertTrue([listed containsObject:@"sp_tr_src"]);
	XCTAssertFalse([listed containsObject:@"mysql"], @"no system databases");
	XCTAssertFalse([listed containsObject:@"information_schema"]);
	XCTAssertEqualObjects(controller.databasePopup.lastItem.title, @"New Database…");
	XCTAssertTrue(controller.transferButton.isEnabled);

	// The filter hides and unsets the favorite
	controller.favoriteFilterField.stringValue = @"nothing like it";
	[NSApp sendAction:controller.favoriteFilterField.action to:controller.favoriteFilterField.target from:controller.favoriteFilterField];
	XCTAssertNil(controller.favoritePopup.selectedItem);
	XCTAssertNil(controller.selectedDatabase);
	XCTAssertFalse(controller.transferButton.isEnabled);
}

- (void)testWholeDatabaseThroughTheSheet
{
	if (!self.document) { XCTSkip(@"no MySQL test server on 127.0.0.1:55438 (docker sp-mysql8)"); }
	SPMySQLTransferController *controller = [self openSheetWithFavorites:@[[self favoriteNamed:@"Test target" identifier:501 database:@"sp_tr_dst"]]];
	__block NSString *confirmedDatabase = nil;
	controller.emptyConfirmation = ^(NSString *database, NSString *description, void (^answer)(BOOL)) {
		confirmedDatabase = database;
		XCTAssertEqualObjects(description, @"“Test target” (root@127.0.0.1:55438)");
		answer(YES);
	};
	[controller transfer:nil];
	XCTAssertEqualObjects(confirmedDatabase, @"sp_tr_dst");
	XCTAssertTrue([self spinUntil:^BOOL{ return self.ended && controller.progressSheet.finished; } timeout:60], @"%@", controller.lastErrorMessage);

	SPPostgresProgressSheet *progress = controller.progressSheet;
	NSNumber *done = @(SPPostgresTaskDone);
	XCTAssertEqualObjects(progress.taskStates, (@[done, done, done, done, done, done, done]), @"%@", controller.lastErrorMessage);
	XCTAssertEqualObjects(progress.taskTitles[5], @"Empty “sp_tr_dst” and swap the tables in");
	XCTAssertEqualObjects(progress.resultMessageField.stringValue, @"Transfer complete");
	XCTAssertTrue([controller.completionNote hasPrefix:@"Copied 2 tables (5 rows) to “sp_tr_dst” on “Test target”."], @"%@", controller.completionNote);
	XCTAssertEqualObjects([progress.taskDetailFields[4] stringValue], @"2 tables, 5 rows copied");
	XCTAssertTrue([[progress.taskDetailFields[5] stringValue] containsString:@"leftover"], @"%@", [progress.taskDetailFields[5] stringValue]);
	[progress close:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return [self.windowController window].attachedSheet == nil; } timeout:10]);

	XCTAssertEqualObjects([self value:@"SELECT GROUP_CONCAT(TABLE_NAME ORDER BY TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'sp_tr_dst'"], @"child,names,parent");
	XCTAssertEqualObjects([self value:@"SELECT COUNT(*) FROM sp_tr_dst.child"], @"3");
	XCTAssertEqualObjects([self value:@"SELECT GROUP_CONCAT(name ORDER BY name) FROM sp_tr_dst.names"], @"one,two");
	XCTAssertEqualObjects([self value:@"SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS WHERE CONSTRAINT_SCHEMA = 'sp_tr_dst'"], @"1");
}

- (void)testNewDatabaseIsMadeAndNeedsNoConfirmation
{
	if (!self.document) { XCTSkip(@"no MySQL test server on 127.0.0.1:55438 (docker sp-mysql8)"); }
	SPMySQLTransferController *controller = [self openSheetWithFavorites:@[[self favoriteNamed:@"Test target" identifier:501 database:@"sp_tr_dst"]]];
	controller.newDatabasePrompt = ^(NSDictionary *favorite, void (^answer)(NSString *)) { answer(@"sp_tr_made"); };
	controller.emptyConfirmation = ^(NSString *database, NSString *description, void (^answer)(BOOL)) {
		XCTFail(@"a database made in the sheet isn't confirmed");
		answer(NO);
	};
	[controller.databasePopup selectItem:controller.databasePopup.lastItem];
	[NSApp sendAction:controller.databasePopup.action to:controller.databasePopup.target from:controller.databasePopup];
	XCTAssertEqualObjects(controller.selectedDatabase, @"sp_tr_made");
	XCTAssertEqualObjects(controller.databasePopup.titleOfSelectedItem, @"sp_tr_made");
	[controller.selectedTablesRadio performClick:nil];
	[controller.tablesList setChecked:YES item:@"parent"];
	XCTAssertTrue(controller.transferButton.isEnabled);
	[controller transfer:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return self.ended && controller.progressSheet.finished; } timeout:60], @"%@", controller.lastErrorMessage);
	XCTAssertEqualObjects(controller.progressSheet.resultMessageField.stringValue, @"Transfer complete", @"%@", controller.lastErrorMessage);
	[controller.progressSheet close:nil];
	XCTAssertEqualObjects([self value:@"SELECT GROUP_CONCAT(TABLE_NAME) FROM information_schema.TABLES WHERE TABLE_SCHEMA = 'sp_tr_made'"], @"parent");
}

- (void)testToolbarTransferIsEnabledOnAConnectedTabWithADatabase
{
	if (!self.document) { XCTSkip(@"no MySQL test server on 127.0.0.1:55438 (docker sp-mysql8)"); }
	NSToolbar *toolbar = [self.windowController window].toolbar;
	NSToolbarItem *transfer = nil;
	for (NSToolbarItem *item in toolbar.items) if ([item.itemIdentifier isEqualToString:@"TransferToolbarItemIdentifier"]) transfer = item;
	XCTAssertNotNil(transfer);
	XCTAssertEqual(transfer.action, NSSelectorFromString(@"showTransfer:"));
	XCTAssertEqual(transfer.target, self.document);
	XCTAssertTrue([self.document validateToolbarItem:transfer]);
	// Clicking it shows the sheet
	[NSApp sendAction:transfer.action to:transfer.target from:transfer];
	XCTAssertTrue([self spinUntil:^BOOL{ return [self.windowController window].attachedSheet != nil; } timeout:5]);
	XCTAssertFalse([self.document validateToolbarItem:transfer], @"not while a sheet is up");
	NSWindow *attached = [self.windowController window].attachedSheet;
	NSButton *cancel = nil;
	for (NSView *view in attached.contentView.subviews) if ([view isKindOfClass:[NSButton class]] && [[(NSButton *)view title] isEqualToString:@"Cancel"]) cancel = (NSButton *)view;
	XCTAssertNotNil(cancel);
	[cancel performClick:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return [self.windowController window].attachedSheet == nil; } timeout:10]);
}

@end
