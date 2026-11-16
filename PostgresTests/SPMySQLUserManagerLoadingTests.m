#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "../Source/SPWindowController.h"

@interface NSObject (SPMySQLUserManagerLoadingTests)
- (id)connectionController;
- (void)initiateConnection:(id)sender;
- (id)getConnection;
- (BOOL)isConnected;
- (BOOL)isWorking;
- (void)showUserManager:(id)sender;
- (void)doCancel:(id)sender;
- (id)queryString:(NSString *)query;
- (BOOL)queryErrored;
- (NSString *)lastErrorMessage;
- (NSManagedObjectContext *)managedObjectContext;
@end

/**
 * MySQL's User Manager says "Loading users…" at once (a sheet with a spinner and Cancel), checks access to mysql.user
 * off the main thread, then shows the User Manager in its place. On a real MySQL tab (docker sp-mysql8,
 * 127.0.0.1:55438, root / sptest; skipped when it isn't running).
 */
@interface SPMySQLUserManagerLoadingTests : XCTestCase
@property (strong) SPWindowController *windowController;
@property (strong) id document;
@end

@implementation SPMySQLUserManagerLoadingTests

- (BOOL)spinUntil:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout
{
	NSDate *end = [NSDate dateWithTimeIntervalSinceNow:timeout];
	while (!condition()) {
		if ([end timeIntervalSinceNow] < 0) return NO;
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
	}
	return YES;
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
	[self spinUntil:^BOOL{ return NO; } timeout:0.3];
	__weak SPMySQLUserManagerLoadingTests *weakSelf = self;
	[self addTeardownBlock:^{
		SPMySQLUserManagerLoadingTests *me = weakSelf;
		id manager = [mysql valueForKey:@"userManagerInstance"];
		NSWindow *window = [controller window];
		if (manager && [window attachedSheet] == [manager window]) [manager doCancel:nil];
		[me spinUntil:^BOOL{ return window.attachedSheet == nil; } timeout:5];
		while (window.attachedSheet) [window endSheet:window.attachedSheet];
		NSTabView *tabView = [controller valueForKey:@"tabView"];
		for (NSTabViewItem *item in [tabView tabViewItems]) [tabView removeTabViewItem:item];
		[window orderOut:nil];
		[me spinUntil:^BOOL{ return NO; } timeout:0.5];
	}];

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

	// A user with privileges on one database (a mysql.db row, CREATE TEMPORARY TABLES among them)
	id connection = [mysql getConnection];
	for (NSString *sql in @[@"DROP USER IF EXISTS 'sp_um_user'@'%'", @"CREATE USER 'sp_um_user'@'%' IDENTIFIED BY 'Pw-sp_um1'",
							@"GRANT SELECT, CREATE TEMPORARY TABLES ON sp_um_db.* TO 'sp_um_user'@'%'"]) {
		[connection queryString:sql];
		XCTAssertFalse([connection queryErrored], @"%@: %@", sql, [connection lastErrorMessage]);
	}
	[self addTeardownBlock:^{
		if ([[mysql getConnection] isConnected]) [[mysql getConnection] queryString:@"DROP USER IF EXISTS 'sp_um_user'@'%'"];
	}];
}

- (NSWindow *)window
{
	return [self.windowController window];
}

/// The labels of a sheet's content (to recognise "Loading users…").
- (NSArray<NSString *> *)labelsIn:(NSWindow *)sheet
{
	NSMutableArray *labels = [NSMutableArray array];
	for (NSView *view in [[sheet contentView] subviews]) {
		if ([view isKindOfClass:[NSTextField class]]) [labels addObject:[(NSTextField *)view stringValue]];
	}
	return labels;
}

- (void)testLoadingSheetThenTheUserManager
{
	if (!self.document) { XCTSkip(@"sp-mysql8 isn't running"); }
	id mysql = self.document;

	[mysql showUserManager:nil];

	// At once, before any answer from the server
	NSWindow *loading = self.window.attachedSheet;
	XCTAssertNotNil(loading);
	XCTAssertTrue([[self labelsIn:loading] containsObject:@"Loading users…"], @"%@", [self labelsIn:loading]);

	// Clicking again meanwhile does nothing
	[mysql showUserManager:nil];
	XCTAssertEqual(self.window.attachedSheet, loading);

	// Then the User Manager in its place
	id manager = [mysql valueForKey:@"userManagerInstance"];
	XCTAssertNotNil(manager);
	XCTAssertTrue([self spinUntil:^BOOL{ return self.window.attachedSheet == [manager window]; } timeout:20]);
	XCTAssertFalse([loading isVisible]);
	XCTAssertEqualObjects([mysql valueForKey:@"userManagerLoading"], @NO);

	// Its users and their database privileges were read (MySQL 8's Create_tmp_table_priv among them)
	NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Privileges"];
	request.predicate = [NSPredicate predicateWithFormat:@"db == %@", @"sp_um_db"];
	NSArray *privileges = [[manager managedObjectContext] executeFetchRequest:request error:NULL];
	XCTAssertEqual(privileges.count, 1u);
	XCTAssertEqualObjects([privileges.firstObject valueForKey:@"select_priv"], @YES);
	XCTAssertEqualObjects([privileges.firstObject valueForKey:@"create_temporary_tables_priv"], @YES);
	XCTAssertEqualObjects([privileges.firstObject valueForKey:@"insert_priv"], @NO);
	NSFetchRequest *users = [NSFetchRequest fetchRequestWithEntityName:@"SPUser"];
	users.predicate = [NSPredicate predicateWithFormat:@"user == %@ AND parent == nil", @"root"];
	XCTAssertGreaterThan([[manager managedObjectContext] countForFetchRequest:users error:NULL], 0u);

	[manager doCancel:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return self.window.attachedSheet == nil && [mysql valueForKey:@"userManagerInstance"] == nil; } timeout:5]);
}

- (void)testCancelWhileLoadingShowsNothing
{
	if (!self.document) { XCTSkip(@"sp-mysql8 isn't running"); }
	id mysql = self.document;

	[mysql showUserManager:nil];
	NSWindow *loading = self.window.attachedSheet;
	NSButton *cancel = nil;
	for (NSView *view in [[loading contentView] subviews]) {
		if ([view isKindOfClass:[NSButton class]]) cancel = (NSButton *)view;
	}
	XCTAssertEqualObjects(cancel.title, @"Cancel");
	[cancel performClick:nil];

	XCTAssertTrue([self spinUntil:^BOOL{ return [[mysql valueForKey:@"userManagerLoading"] boolValue] == NO; } timeout:20]);
	[self spinUntil:^BOOL{ return NO; } timeout:0.3];
	XCTAssertNil(self.window.attachedSheet, @"the User Manager isn't shown");
	XCTAssertNil([mysql valueForKey:@"userManagerInstance"]);

	// And it can be opened again
	[mysql showUserManager:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ id manager = [mysql valueForKey:@"userManagerInstance"]; return manager && self.window.attachedSheet == [manager window]; } timeout:20]);
}

@end
