#import <XCTest/XCTest.h>
#import <PostgresKit/PostgresKit.h>
#import "SPPostgresTestServers.h"
#import "SPTestPrefsGuard.h"
#import "../Source/SPWindowController.h"
#import "../Source/Postgres/SPPostgresNameSheet.h"
#import "../Source/Postgres/SPPostgresDocument.h"
#import "../Source/Postgres/SPPostgresSidebarController.h"
#import "../Source/Postgres/SPPostgresStructureController.h"
#import "../Source/Postgres/SPPostgresContentController.h"
#import "../Source/Postgres/SPPostgresRelationsController.h"
#import "../Source/Postgres/SPPostgresTriggersController.h"
#import "../Source/Postgres/SPPostgresTableInfoController.h"
#import "../Source/Postgres/SPPostgresHistory.h"
#import "../Source/Postgres/SPPostgresQueryController.h"
#import "../Source/Postgres/SPPostgresConnector.h"
#import "../Source/Postgres/SPPostgresFavorite.h"
#import "../Source/Postgres/SPQueryScriptStore.h"
#import "../Source/Postgres/SPPostgresExtensionController.h"
#import "../Source/Postgres/SPPostgresInstallExtensionSheet.h"
#import "../Source/Postgres/SPPostgresTaskRunner.h"
#import "../Source/Postgres/SPPostgresTaskDisplay.h"
#import "../Source/Postgres/SPPostgresSequenceController.h"
#import "../Source/Postgres/SPPostgresCatalog.h"
#import "../Source/Postgres/SPPostgresSidebarInfoPane.h"

static const NSUInteger SPPostgresDocumentTestPort = 55418;

// Not in the public headers
@interface SPPostgresDocument (SPPostgresDocumentTestsActions)
- (void)refreshDatabases:(id)sender;
- (void)toggleConsole:(id)sender;
- (void)_applyHistoryEntry:(NSDictionary *)entry;
- (IBAction)backForwardInHistory:(id)sender;
- (void)closeRenameTableSheet:(id)sender;
- (BOOL)sidebarShouldChangeSelection:(SPPostgresSidebarController *)sidebar;
- (void)sidebar:(SPPostgresSidebarController *)sidebar dropExtensionNamed:(NSString *)name;
- (void)sidebar:(SPPostgresSidebarController *)sidebar truncateTables:(NSArray<NSString *> *)tables;
- (void)sidebar:(SPPostgresSidebarController *)sidebar reduceStorageOfTables:(NSArray<NSString *> *)tables;
- (void)sidebar:(SPPostgresSidebarController *)sidebar reduceStorageOfAllTables:(NSArray<NSString *> *)tables;
- (void)sidebar:(SPPostgresSidebarController *)sidebar removeRelations:(NSArray<NSString *> *)names;
- (void)closeAddTableSheet:(id)sender;
@end

@interface SPWindowController (SPPostgresDocumentTests)
- (IBAction)showServerVariables:(id)sender;
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;
@end

@interface NSObject (SPPostgresDocumentTestsColors)
- (NSColor *)colorForIndex:(NSInteger)colorIndex;
@end

@interface SPPostgresDocumentTests : XCTestCase
@property (strong) SPWindowController *controller;
@property (strong) SPPostgresDocument *document;
@property (strong) PGPostgresConnection *connection;
@property (strong) SPPostgresFavorite *favorite;
/// What the pgkit_ext documents (see -extensionDocumentOnPort:installing:) were asked and shown
@property (strong) NSMutableArray<NSAlert *> *extensionAlerts;
@property (strong) NSMutableArray<NSAlert *> *extensionConfirmations;
@property (assign) BOOL extensionConfirmAnswer;
@end

@implementation SPPostgresDocumentTests

+ (void)setUp
{
	[super setUp];
	[SPPostgresTestServers loadFixtureNamed:@"catalog" onPort:SPPostgresDocumentTestPort];
}

- (BOOL)spinUntil:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout
{
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
	while (!condition() && [deadline timeIntervalSinceNow] > 0) {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
	}
	return condition();
}

/// A connected connector for `favorite`, or nil (with a failure).
- (SPPostgresConnector *)connectorForFavorite:(SPPostgresFavorite *)favorite sshPassword:(NSString *)sshPassword connection:(PGPostgresConnection * __autoreleasing *)outConnection
{
	SPPostgresConnector *connector = [[SPPostgresConnector alloc] initWithFavorite:favorite password:@"pgkit" sshPassword:sshPassword parentWindow:nil];
	__block PGPostgresConnection *connection = nil;
	__block NSError *error = nil;
	__block BOOL done = NO;
	[connector connectWithCompletion:^(PGPostgresConnection *theConnection, NSError *theError) {
		connection = theConnection;
		error = theError;
		done = YES;
	}];
	XCTAssertTrue([self spinUntil:^BOOL{ return done; } timeout:20]);
	XCTAssertNotNil(connection, @"%@", error);
	*outConnection = connection;
	return connector;
}

- (void)setUp
{
	self.continueAfterFailure = NO;

	SPPostgresFavorite *favorite = [[SPPostgresFavorite alloc] init];
	favorite.name = @"pg18 test";
	favorite.colorIndex = 2;
	favorite.type = SPPostgresTCPIPConnection;
	favorite.host = @"127.0.0.1";
	favorite.port = SPPostgresDocumentTestPort;
	favorite.user = @"pgkit_test";
	favorite.database = @"pgkit_test";
	self.favorite = favorite;

	// As -[SPAppController newWindow] does. The window's delegate is deliberately not set: its
	// -windowWillClose: autoreleases the controller, which this (ARC) test owns.
	self.controller = [[SPWindowController alloc] initWithWindowNibName:@"MainWindow"];
	XCTAssertNotNil([self.controller window]);

	// The document takes a connected connection and the connector that owns it
	PGPostgresConnection *connection = nil;
	SPPostgresConnector *connector = [self connectorForFavorite:favorite sshPassword:nil connection:&connection];
	self.connection = connection;

	self.document = [[SPPostgresDocument alloc] initWithConnection:connection connector:connector favorite:favorite];
	[self.controller addTabDocument:self.document atIndex:0 select:YES];
	XCTAssertEqual([self.controller selectedDocument], self.document);
	// The first loads (the Content view, the database pop-up) run on the tab's runner
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
}

- (void)tearDown
{
	NSWindow *window = [self.controller window];
	if (window.attachedSheet) [window endSheet:window.attachedSheet];

	// Close every tab the way the tab bar does, so documents get -parentTabDidClose
	NSTabView *tabView = [self.controller valueForKey:@"tabView"];

	// A MySQL tab's filter editor resizes itself 0.2 s after it is built (SPRuleFilterController -_resize);
	// let that run while the MySQL document is still alive, or it messages freed objects in the next test.
	if ([tabView numberOfTabViewItems] > 1) [self spinUntil:^BOOL{ return NO; } timeout:0.4];

	for (NSTabViewItem *item in [tabView tabViewItems]) {
		[tabView removeTabViewItem:item];
	}
	[window orderOut:nil];

	// Windows a test opened (Open Table in New Window): closing one closes its tabs and lets go of its controller
	for (NSWindow *other in [NSApp windows]) {
		if (other != window && other.isVisible && [other.windowController isKindOfClass:[SPWindowController class]]) [other close];
	}
	self.document = nil;
	self.controller = nil;
	self.connection = nil;
	[super tearDown];
}

- (NSWindow *)window
{
	return [self.controller window];
}

- (NSTabView *)tabView
{
	return [self.controller valueForKey:@"tabView"];
}

#pragma mark - Hosting

- (void)testDocumentIsHostedInTheWindow
{
	XCTAssertEqual(self.document.parentWindowController, self.controller);
	XCTAssertEqual(self.document.parentWindow, [self window]);
	XCTAssertEqual([self.document.parentTabViewItem identifier], self.document);
	XCTAssertNil([self.controller selectedTableDocument], @"MySQL-only code sees no document");

	// The tab's view is the split view (left panel | content), with no tab bar of its own
	NSView *view = [self.document databaseView];
	XCTAssertTrue([view isKindOfClass:[NSSplitView class]], @"%@", view);
	XCTAssertEqual([self.document.parentTabViewItem view], view);
	// The app saves the divider under MySQL's "DBViewSplitter" (one left pane width for both engines);
	// in tests the name is recorded, not set (SPTestPrefsGuard)
	XCTAssertEqualObjects([(NSSplitView *)view sp_requestedAutosaveName], @"DBViewSplitter");
	XCTAssertNil([(NSSplitView *)view autosaveName]);
	XCTAssertNil([(NSSplitView *)view autosaveName]);
	XCTAssertEqual([[view subviews] count], 2u);
	XCTAssertEqual([[view subviews] firstObject], [self.document.sidebar view]);
	NSMutableArray *queue = [NSMutableArray arrayWithObject:view];
	while (queue.count) {
		NSView *v = queue.firstObject; [queue removeObjectAtIndex:0];
		XCTAssertFalse([NSStringFromClass([v class]) hasPrefix:@"PSMTabBar"], @"no tab bar inside the tab");
		[queue addObjectsFromArray:v.subviews];
	}
}

/// Split views in tests never save their divider positions into the real preferences (SPTestPrefsGuard).
- (void)testSplitViewAutosaveNeverReachesPreferences
{
	NSString *name = @"SPTestPrefsGuardSplitProbe";
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	NSArray *keys = @[[@"NSSplitView Subview Frames " stringByAppendingString:name], [@"SPSplitView Lengths " stringByAppendingString:name]];
	for (NSString *key in keys) XCTAssertNil([prefs objectForKey:key]);

	NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400, 300) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
	[window setReleasedWhenClosed:NO];
	NSSplitView *splitView = [[NSClassFromString(@"SPSplitView") alloc] initWithFrame:NSMakeRect(0, 0, 400, 300)];
	[splitView setVertical:YES];
	[splitView addSubview:[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 150, 300)]];
	[splitView addSubview:[[NSView alloc] initWithFrame:NSMakeRect(151, 0, 249, 300)]];
	[[window contentView] addSubview:splitView];
	[splitView setAutosaveName:name];
	XCTAssertEqualObjects([splitView sp_requestedAutosaveName], name);
	XCTAssertNil([splitView autosaveName]);

	[splitView adjustSubviews];
	[splitView setPosition:200 ofDividerAtIndex:0];
	[splitView resizeSubviewsWithOldSize:NSMakeSize(380, 300)];
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	[splitView removeFromSuperview];
	[window close];

	for (NSString *key in keys) XCTAssertNil([prefs objectForKey:key], @"%@", key);
}

- (void)testTabLabelAndColourComeFromFavorite
{
	NSTabViewItem *item = self.document.parentTabViewItem;
	XCTAssertEqualObjects([item label], @"pg18 test");

	id colors = [NSClassFromString(@"SPFavoriteColorSupport") valueForKey:@"sharedInstance"];
	NSColor *expected = [colors colorForIndex:2];
	XCTAssertNotNil(expected);
	XCTAssertEqualObjects([item color], expected);
}

/// A second tab for the same favorite on another database (not selected).
- (SPPostgresDocument *)addNamesakeOnDatabase:(NSString *)database select:(BOOL)select
{
	SPPostgresFavorite *other = [self.favorite copy];
	other.database = database;
	PGPostgresConnection *connection = nil;
	SPPostgresConnector *connector = [self connectorForFavorite:other sshPassword:nil connection:&connection];
	SPPostgresDocument *document = [[SPPostgresDocument alloc] initWithConnection:connection connector:connector favorite:other];
	[self.controller addTabDocument:document atIndex:1 select:select];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
	return document;
}

- (void)testQueryEditorTextIsSavedPerConnectionAndReloaded
{
	// Typed in this tab's Query editor, then the tab closes
	NSTextView *editor = [self.document.queryController editor];
	[editor setSelectedRange:NSMakeRange(0, 0)];
	[editor insertText:@"SELECT 42 AS answer;" replacementRange:NSMakeRange(0, 0)];
	[self.document parentTabDidClose];
	NSString *key = [SPQueryScriptStore keyForEngine:SPQueryScriptEnginePostgreSQL type:SPPostgresTCPIPConnection host:@"127.0.0.1"
	                                             port:[NSString stringWithFormat:@"%lu", (unsigned long)SPPostgresDocumentTestPort]
	                                             user:@"pgkit_test" socket:nil sshHost:nil sshUser:nil];
	XCTAssertEqualObjects([[SPQueryScriptStore sharedStore] scriptForKey:key], @"SELECT 42 AS answer;", @"saved for the server (no saved favorite)");

	// A new tab on the same connection (another database too) opens with it
	SPPostgresDocument *again = [self addNamesakeOnDatabase:@"postgres" select:YES];
	XCTAssertEqualObjects([[again.queryController editor] string], @"SELECT 42 AS answer;");

	// Moving to another database keeps the editor and the connection's script
	NSTextView *againEditor = [again.queryController editor];
	[againEditor insertText:@" -- more" replacementRange:NSMakeRange([[againEditor string] length], 0)];
	[again switchToDatabase:@"pgkit_test"];
	XCTAssertTrue([self spinUntil:^BOOL{ return [again.queryController editor] != againEditor; } timeout:30], @"the Query editor is replaced on the new connection");
	XCTAssertTrue([SPPostgresTestServers waitForRunner:again.taskRunner timeout:30]);
	XCTAssertEqualObjects([[SPQueryScriptStore sharedStore] scriptForKey:key], @"SELECT 42 AS answer; -- more", @"the old editor's edit saved as it was replaced");
	XCTAssertEqualObjects([[again.queryController editor] string], @"SELECT 42 AS answer; -- more");

	// Another user on the same server: its own (empty) script
	SPPostgresFavorite *otherUser = [self.favorite copy];
	otherUser.user = @"postgres";
	NSString *otherKey = [SPQueryScriptStore keyForEngine:SPQueryScriptEnginePostgreSQL type:SPPostgresTCPIPConnection host:@"127.0.0.1"
	                                                  port:[NSString stringWithFormat:@"%lu", (unsigned long)SPPostgresDocumentTestPort]
	                                                  user:@"postgres" socket:nil sshHost:nil sshUser:nil];
	XCTAssertNotEqualObjects(otherKey, key);
	XCTAssertNil([[SPQueryScriptStore sharedStore] scriptForKey:otherKey]);
}

- (void)testTabLabelsAddDatabaseForNamesakes
{
	XCTAssertEqualObjects([self.document.parentTabViewItem label], @"pg18 test", @"alone: the favorite name");

	// Added in the background: both labels gain their database
	SPPostgresDocument *second = [self addNamesakeOnDatabase:@"pgkit_nopublic" select:NO];
	XCTAssertEqual([self.controller selectedDocument], self.document);
	XCTAssertEqualObjects([self.document.parentTabViewItem label], @"pg18 test/pgkit_test");
	XCTAssertEqualObjects([second.parentTabViewItem label], @"pg18 test/pgkit_nopublic");

	// A database switch renames that tab
	[self.document switchToDatabase:@"postgres"];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([self spinUntil:^BOOL{ return [[self.document.parentTabViewItem label] isEqualToString:@"pg18 test/postgres"]; } timeout:20],
				  @"%@", [self.document.parentTabViewItem label]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects([second.parentTabViewItem label], @"pg18 test/pgkit_nopublic");

	// Closing one leaves the other alone again
	[[self tabView] removeTabViewItem:second.parentTabViewItem];
	XCTAssertEqualObjects([self.document.parentTabViewItem label], @"pg18 test");
}

- (void)testTabLabelsAddDatabaseForSelectedNamesake
{
	SPPostgresDocument *second = [self addNamesakeOnDatabase:@"pgkit_nopublic" select:YES];
	XCTAssertEqual([self.controller selectedDocument], second);
	XCTAssertEqualObjects([self.document.parentTabViewItem label], @"pg18 test/pgkit_test");
	XCTAssertEqualObjects([second.parentTabViewItem label], @"pg18 test/pgkit_nopublic");
}

- (void)testActivationClearsProxyIcon
{
	id mysql = [self.controller addNewConnection];
	XCTAssertEqual([self.controller selectedDocument], mysql);
	[[self window] setRepresentedURL:[NSURL fileURLWithPath:NSTemporaryDirectory()]];
	XCTAssertNotNil([self window].representedURL);

	[[self tabView] selectTabViewItem:self.document.parentTabViewItem];
	XCTAssertNil([self window].representedURL);
}

- (void)testConsoleMenuItemTitle
{
	NSWindow *console = [[NSClassFromString(@"SPQueryController") valueForKey:@"sharedQueryController"] window];
	[console orderOut:nil];

	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Console" action:@selector(toggleConsole:) keyEquivalent:@""];
	XCTAssertTrue([self.document validateMenuItem:item]);
	XCTAssertEqualObjects(item.title, @"Show Console");
}

- (void)testClosingTabDisconnects
{
	PGPostgresConnection *connection = self.connection;
	XCTAssertTrue(connection.isConnected);
	[[self tabView] removeTabViewItem:self.document.parentTabViewItem];
	XCTAssertTrue([self spinUntil:^BOOL{ return !connection.isConnected; } timeout:2]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertNil([self.controller selectedDocument]);
}

#pragma mark - Background tasks

- (void)testIsProcessingFollowsRunner
{
	SPPostgresTaskRunner *runner = self.document.taskRunner;
	XCTAssertNotNil(runner);
	XCTAssertFalse(runner.isInline);
	XCTAssertEqual(runner.connection, self.document.connection);
	XCTAssertFalse(self.document.isProcessing);

	XCTestExpectation *on = [[XCTKVOExpectation alloc] initWithKeyPath:@"isProcessing" object:self.document expectedValue:@YES];
	[runner runTaskWithDescription:@"Loading..." cancelTitle:nil work:^id(PGPostgresConnection *connection, NSError **error) {
		return [connection execute:@"SELECT pg_sleep(0.3)"];
	} completion:nil];
	XCTAssertTrue(self.document.isProcessing, @"the tab shows progress while its runner is busy");
	[self waitForExpectations:@[on] timeout:0];

	XCTAssertTrue([SPPostgresTestServers waitForRunner:runner timeout:10]);
	XCTAssertFalse(self.document.isProcessing);
}

- (void)testDatabaseSwitchReplacesRunner
{
	SPPostgresTaskRunner *oldRunner = self.document.taskRunner;
	[self.document switchToDatabase:@"pgkit_nopublic"];
	XCTAssertTrue([self spinUntil:^BOOL{ return [[self.document windowTitleString] hasSuffix:@"/pgkit_nopublic"] && !self.document.isProcessing; } timeout:20]);
	SPPostgresTaskRunner *newRunner = self.document.taskRunner;
	XCTAssertNotEqual(newRunner, oldRunner);
	XCTAssertEqual(newRunner.connection, self.document.connection);

	// isProcessing follows the new runner, not the old one
	[newRunner runTaskWithDescription:@"Loading..." cancelTitle:nil work:^id(PGPostgresConnection *connection, NSError **error) {
		return [connection execute:@"SELECT pg_sleep(0.2)"];
	} completion:nil];
	XCTAssertTrue(self.document.isProcessing);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:newRunner timeout:10]);
	XCTAssertFalse(self.document.isProcessing);
}

/// Closing the tab while a load runs: no wait, the connection closed only once the worker has left libpq (the
/// statement cancelled), and the load's completion never runs.
- (void)testCloseTabDuringLoadClosesConnectionAfterWorker
{
	PGPostgresConnection *connection = self.connection;
	NSUInteger pid = [connection serverProcessId];
	XCTAssertGreaterThan(pid, 0u);

	__block BOOL completed = NO;
	[self.document.taskRunner runTaskWithDescription:@"Loading..." cancelTitle:@"Cancel" work:^id(PGPostgresConnection *theConnection, NSError **error) {
		return [theConnection execute:@"SELECT pg_sleep(30)"];
	} completion:^(id result, NSError *error, BOOL cancelled) {
		completed = YES;
	}];
	[self spinUntil:^BOOL{ return NO; } timeout:0.3]; // the statement is running

	NSDate *start = [NSDate date];
	[[self tabView] removeTabViewItem:self.document.parentTabViewItem];
	XCTAssertLessThan(-[start timeIntervalSinceNow], 0.5, @"closing doesn't wait for the worker");
	XCTAssertFalse(self.document.isProcessing);

	// The document may go now; the connection is closed after the worker
	self.document = nil;
	PGPostgresConnection *admin = [SPPostgresTestServers connectedConnectionOnPort:SPPostgresDocumentTestPort];
	NSString *query = [NSString stringWithFormat:@"SELECT count(*) FROM pg_stat_activity WHERE pid = %lu", (unsigned long)pid];
	BOOL gone = [self spinUntil:^BOOL{
		PGPostgresResult *result = [admin execute:query];
		return [[[[result rowAsArray] firstObject] description] isEqualToString:@"0"];
	} timeout:5];
	[admin disconnect];
	XCTAssertTrue(gone, @"the server backend is gone");
	XCTAssertFalse(connection.isConnected);

	[self spinUntil:^BOOL{ return NO; } timeout:0.3];
	XCTAssertFalse(completed, @"no completion touches the torn-down tab");
}

- (void)testMenuValidationDisablesUnsupportedActions
{
	// Flush Privileges has no PostgreSQL equivalent (Show Server Variables… is supported since the Database menu was)
	NSMenuItem *flush = [[NSMenuItem alloc] initWithTitle:@"Flush Privileges" action:@selector(flushPrivileges:) keyEquivalent:@""];
	XCTAssertFalse([self.document validateMenuItem:flush]);
	XCTAssertFalse([self.controller validateMenuItem:flush], @"the window asks the selected Postgres tab");
	XCTAssertFalse([self.controller respondsToSelector:@selector(flushPrivileges:)], @"not forwarded to the Postgres tab");

	// The window's own items and the tab's own actions stay enabled
	NSMenuItem *closeTab = [[NSMenuItem alloc] initWithTitle:@"Close Tab" action:@selector(closeTab:) keyEquivalent:@""];
	XCTAssertTrue([self.controller validateMenuItem:closeTab]);
	NSMenuItem *newTab = [[NSMenuItem alloc] initWithTitle:@"New Tab" action:@selector(addNewConnection:) keyEquivalent:@""];
	XCTAssertTrue([self.controller validateMenuItem:newTab]);
	NSMenuItem *refresh = [[NSMenuItem alloc] initWithTitle:@"Refresh Databases" action:@selector(refreshDatabases:) keyEquivalent:@""];
	XCTAssertTrue([self.document validateMenuItem:refresh]);
}

- (void)testSwitchingTabsSwapsToolbarAndTitle
{
	NSToolbar *postgresToolbar = [self.document toolbar];
	XCTAssertEqual([self window].toolbar, postgresToolbar);

	// A MySQL tab takes the window over...
	id mysql = [self.controller addNewConnection];
	XCTAssertEqual([self.controller selectedDocument], mysql);
	XCTAssertNotEqual([self window].toolbar, postgresToolbar);
	XCTAssertNotEqualObjects([self window].title, [self.document windowTitleString]);

	// ...and selecting the Postgres tab gives it back, keeping the toolbar's visibility
	[[self window].toolbar setVisible:NO];
	[[self tabView] selectTabViewItem:self.document.parentTabViewItem];
	XCTAssertEqual([self.controller selectedDocument], self.document);
	XCTAssertEqual([self window].toolbar, postgresToolbar);
	XCTAssertFalse([postgresToolbar isVisible]);
	XCTAssertEqualObjects([self window].title, [self.document windowTitleString]);
	XCTAssertEqualObjects([self.document.parentTabViewItem label], @"pg18 test");
}

#pragma mark - Toolbar

- (void)testToolbarOrderMatchesSpec
{
	// MySQL's identifiers (the app's constants aren't exported to the test bundle)
	NSString *database = @"DatabaseSelectToolbarItemIdentifier", *history = @"HistoryNavigationToolbarItemIdentifier",
		*console = @"ShowConsoleIdentifier", *structure = @"SwitchToTableStructureToolbarItemIdentifier",
		*content = @"SwitchToTableContentToolbarItemIdentifier", *query = @"SwitchToRunQueryToolbarItemIdentifier",
		*tableInfo = @"SwitchToTableInfoToolbarItemIdentifier", *relations = @"SwitchToTableRelationsToolbarItemIdentifier",
		*triggers = @"SwitchToTableTriggersToolbarItemIdentifier", *users = @"SwitchToUserManagerToolbarItemIdentifier",
		*transfer = @"TransferToolbarItemIdentifier";
	NSArray *expected = @[database, structure, content, relations, triggers, tableInfo, query, transfer, users,
						  NSToolbarFlexibleSpaceItemIdentifier, history, console];
	NSToolbar *toolbar = [self window].toolbar;
	XCTAssertNotNil(toolbar);
	XCTAssertEqual(toolbar, [self.document toolbar]);
	XCTAssertEqualObjects([toolbar identifier], @"TableWindowToolbar");
	XCTAssertEqualObjects([self.document toolbarDefaultItemIdentifiers:toolbar], expected);
	XCTAssertEqualObjects([toolbar.items valueForKey:@"itemIdentifier"], expected);

	// Everything but the database picker, Query, Users, Transfer and the console is present but disabled (Content until a table is selected)
	NSArray *disabled = @[structure, content, relations, triggers, tableInfo, history];
	for (NSToolbarItem *item in toolbar.items) {
		if ([disabled containsObject:item.itemIdentifier]) {
			BOOL enabled = item.view ? [(NSControl *)item.view isEnabled] && item.isEnabled : [self.document validateToolbarItem:item];
			if ([item.view isKindOfClass:[NSSegmentedControl class]]) {
				NSSegmentedControl *control = (NSSegmentedControl *)item.view;
				enabled = enabled && ([control isEnabledForSegment:0] || [control isEnabledForSegment:1]);
			}
			XCTAssertFalse(enabled, @"%@ should be disabled", item.itemIdentifier);
		}
	}
	NSToolbarItem *queryItem = toolbar.items[[expected indexOfObject:query]];
	XCTAssertTrue([self.document validateToolbarItem:queryItem]);
	NSToolbarItem *usersItem = toolbar.items[[expected indexOfObject:users]];
	XCTAssertTrue([self.document validateToolbarItem:usersItem]);
	XCTAssertEqual(usersItem.action, NSSelectorFromString(@"showUserManager:"));
	NSToolbarItem *transferItem = toolbar.items[[expected indexOfObject:transfer]];
	XCTAssertTrue([self.document validateToolbarItem:transferItem]);
	XCTAssertEqual(transferItem.action, NSSelectorFromString(@"showTransfer:"));
	NSToolbarItem *consoleItem = toolbar.items.lastObject;
	XCTAssertTrue([self.document validateToolbarItem:consoleItem]);
	XCTAssertNotNil(consoleItem.image);
}

/// With no database selected the Transfer item and menu item are disabled (showTransfer: would do nothing); Export's
/// validation is unchanged.
- (void)testTransferNeedsADatabase
{
	NSToolbarItem *transferItem = nil;
	for (NSToolbarItem *item in [self window].toolbar.items) {
		if ([item.itemIdentifier isEqualToString:@"TransferToolbarItemIdentifier"]) transferItem = item;
	}
	XCTAssertNotNil(transferItem);
	NSMenuItem *transferMenuItem = [[NSMenuItem alloc] initWithTitle:@"Transfer" action:NSSelectorFromString(@"showTransfer:") keyEquivalent:@""];
	NSMenuItem *exportMenuItem = [[NSMenuItem alloc] initWithTitle:@"Export" action:NSSelectorFromString(@"export:") keyEquivalent:@""];
	XCTAssertTrue([self.document validateToolbarItem:transferItem]);
	XCTAssertTrue([self.document validateMenuItem:transferMenuItem]);

	NSString *database = self.document.currentDatabase;
	XCTAssertEqualObjects(database, @"pgkit_test");
	[(id)self.document setValue:@"" forKey:@"currentDatabase"];
	[self addTeardownBlock:^{ [(id)self.document setValue:database forKey:@"currentDatabase"]; }];
	XCTAssertFalse([self.document validateToolbarItem:transferItem]);
	XCTAssertFalse([self.document validateMenuItem:transferMenuItem]);
	XCTAssertTrue([self.document validateMenuItem:exportMenuItem], @"Export's validation is unchanged");

	[(id)self.document setValue:database forKey:@"currentDatabase"];
	XCTAssertTrue([self.document validateToolbarItem:transferItem]);
	XCTAssertTrue([self.document validateMenuItem:transferMenuItem]);
}

#pragma mark - Title

- (void)testTitleIncludesVersionFavoriteAndDatabase
{
	NSString *title = [self.document windowTitleString];
	XCTAssertTrue([title hasPrefix:@"(PostgreSQL 18."], @"%@", title);
	XCTAssertTrue([title hasSuffix:@") pg18 test/pgkit_test"], @"%@", title);
	XCTAssertNotEqual([title rangeOfString:@"^\\(PostgreSQL 18\\.[0-9]+\\) pg18 test/pgkit_test$" options:NSRegularExpressionSearch].location, NSNotFound,
					  @"version number only, no build suffix: %@", title);
	XCTAssertEqualObjects([self window].title, title);
}

- (void)testTitleIncludesSelectedTable
{
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	XCTAssertTrue([sidebar selectTableNamed:@"customers"]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects(sidebar.selectedTableName, @"customers");
	XCTAssertTrue([[self.document windowTitleString] hasSuffix:@"/pgkit_test/public.customers"], @"%@", [self.document windowTitleString]);
	XCTAssertEqualObjects([self window].title, [self.document windowTitleString]);
}

#pragma mark - Sidebar

- (void)testSidebarSectionsEndWithExtensions
{
	XCTAssertEqualObjects([self.document.sidebar sectionTitles], (@[@"TABLES", @"VIEWS", @"SEQUENCES", @"EXTENSIONS"]));
}

- (void)testSidebarListsTablesViewsAndExtensionsForPublic
{
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	XCTAssertEqualObjects(sidebar.selectedSchema, @"public");
	XCTAssertTrue([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"customers"]);
	XCTAssertEqualObjects([sidebar itemTitlesInSection:@"VIEWS"], (@[@"v_customers"]));
	XCTAssertTrue([[sidebar itemTitlesInSection:@"EXTENSIONS"] containsObject:@"pg_trgm"]);

	// The view: schema picker on top of the outline
	NSView *view = [sidebar view];
	XCTAssertNotNil(view);
	NSPopUpButton *popup = nil;
	NSOutlineView *outline = nil;
	NSMutableArray *queue = [NSMutableArray arrayWithObject:view];
	while (queue.count) {
		NSView *v = queue.firstObject; [queue removeObjectAtIndex:0];
		// The first pop-up is the schema's (the bar's gear pop-up comes after it)
		if (!popup && [v isKindOfClass:[NSPopUpButton class]]) popup = (NSPopUpButton *)v;
		if ([v isKindOfClass:[NSOutlineView class]]) outline = (NSOutlineView *)v;
		[queue addObjectsFromArray:v.subviews];
	}
	XCTAssertNotNil(popup);
	XCTAssertNotNil(outline);
	XCTAssertEqualObjects(popup.titleOfSelectedItem, @"public");
	XCTAssertTrue([popup.itemTitles containsObject:@"Sales Data"]);
	XCTAssertGreaterThan(NSMinY([popup convertRect:popup.bounds toView:nil]), NSMaxY([outline.enclosingScrollView convertRect:outline.enclosingScrollView.bounds toView:nil]) - 1);

	// Section rows appear in order with Extensions last (sections but TABLES start collapsed: expanded to see their rows)
	for (NSString *section in @[@"TABLES", @"VIEWS", @"SEQUENCES", @"EXTENSIONS"]) XCTAssertTrue([sidebar setSection:section collapsed:NO]);
	NSMutableArray *groupTitles = [NSMutableArray array];
	for (NSInteger row = 0; row < outline.numberOfRows; row++) {
		id item = [outline itemAtRow:row];
		if ([outline.delegate outlineView:outline isGroupItem:item]) [groupTitles addObject:[item valueForKey:@"title"]];
	}
	XCTAssertEqualObjects(groupTitles, (@[@"TABLES", @"VIEWS", @"SEQUENCES", @"EXTENSIONS"]));
	id lastItem = [outline itemAtRow:outline.numberOfRows - 1];
	XCTAssertTrue([[sidebar itemTitlesInSection:@"EXTENSIONS"] containsObject:[lastItem valueForKey:@"title"]]);
}

- (void)testSwitchingSchemaReloadsTables
{
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	[sidebar reloadSchema:@"Sales Data"];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects(sidebar.selectedSchema, @"Sales Data");
	XCTAssertEqualObjects([sidebar itemTitlesInSection:@"TABLES"], (@[@"Orders 2026"]));
	XCTAssertEqualObjects([sidebar itemTitlesInSection:@"VIEWS"], (@[]));
	XCTAssertTrue([[sidebar itemTitlesInSection:@"EXTENSIONS"] containsObject:@"pg_trgm"], @"extensions are per database");

	XCTAssertTrue([sidebar selectTableNamed:@"Orders 2026"]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([[self.document windowTitleString] hasSuffix:@"/pgkit_test/Sales Data.Orders 2026"], @"%@", [self.document windowTitleString]);
	XCTAssertEqualObjects([self window].title, [self.document windowTitleString]);
}

#pragma mark - Duplicate Table

- (id)viewWithIdentifier:(NSString *)identifier in:(NSView *)root
{
	NSMutableArray *queue = [NSMutableArray arrayWithObject:root];
	while (queue.count) {
		NSView *v = queue.firstObject; [queue removeObjectAtIndex:0];
		if ([v.identifier isEqualToString:identifier]) return v;
		[queue addObjectsFromArray:v.subviews];
	}
	return nil;
}

- (void)testDuplicateTableFromSidebarMenuSelectsCopy
{
	PGPostgresConnection *admin = [SPPostgresTestServers connectedConnectionOnPort:SPPostgresDocumentTestPort];
	[admin execute:@"DROP TABLE IF EXISTS public.customers_copy, public.\"cust copy\""];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self.controller showWindow:nil];

	SPPostgresSidebarController *sidebar = self.document.sidebar;
	NSMenu *menu = sidebar.tableMenu;
	NSMenuItem *duplicate = [menu itemAtIndex:[menu indexOfItemWithTarget:sidebar andAction:NSSelectorFromString(@"duplicateTable:")]];
	XCTAssertEqualObjects(duplicate.title, @"Duplicate Table…");

	// Only for a table: not a view, not without a selection
	XCTAssertFalse([(id<NSMenuItemValidation>)duplicate.target validateMenuItem:duplicate]);
	XCTAssertTrue([sidebar selectTableNamed:@"v_customers"]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertFalse([(id<NSMenuItemValidation>)duplicate.target validateMenuItem:duplicate]);
	XCTAssertTrue([sidebar selectTableNamed:@"customers"]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([(id<NSMenuItemValidation>)duplicate.target validateMenuItem:duplicate]);

	// The sheet: <table>_copy, the content checkbox, Duplicate/Cancel
	[menu performActionForItemAtIndex:[menu indexOfItem:duplicate]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	NSWindow *sheet = [self window].attachedSheet;
	XCTAssertNotNil(sheet);
	NSTextField *name = [self viewWithIdentifier:@"duplicateTableName" in:sheet.contentView];
	NSButton *content = [self viewWithIdentifier:@"duplicateTableContent" in:sheet.contentView];
	NSButton *button = [self viewWithIdentifier:@"duplicateTableButton" in:sheet.contentView];
	XCTAssertEqualObjects(name.stringValue, @"customers_copy");
	XCTAssertNotNil(content);
	XCTAssertTrue(button.isEnabled);

	// Cancel does nothing
	[[self window] endSheet:sheet returnCode:NSModalResponseCancel];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([self spinUntil:^BOOL{ return [self window].attachedSheet == nil; } timeout:5]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertFalse([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"customers_copy"]);

	// Duplicate, with an odd name and the content
	[menu performActionForItemAtIndex:[menu indexOfItem:duplicate]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	sheet = [self window].attachedSheet;
	name = [self viewWithIdentifier:@"duplicateTableName" in:sheet.contentView];
	content = [self viewWithIdentifier:@"duplicateTableContent" in:sheet.contentView];
	button = [self viewWithIdentifier:@"duplicateTableButton" in:sheet.contentView];
	name.stringValue = @"cust copy";
	content.state = NSControlStateValueOn;
	[button performClick:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([self spinUntil:^BOOL{ return [sidebar.selectedTableName isEqualToString:@"cust copy"]; } timeout:5], @"%@ %@", sidebar.selectedTableName, alerts);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"cust copy"]);
	XCTAssertTrue([[self.document windowTitleString] hasSuffix:@"/pgkit_test/public.cust copy"]);
	XCTAssertEqualObjects([[admin execute:@"SELECT ((SELECT count(*) FROM public.\"cust copy\") = (SELECT count(*) FROM public.customers))::text"] rowAsArray].firstObject, @"true");
	XCTAssertEqual(alerts.count, 0u);

	// A name that is taken: the server's message, as MySQL's "Couldn't duplicate" alert
	[menu performActionForItemAtIndex:[menu indexOfItem:duplicate]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	sheet = [self window].attachedSheet;
	name = [self viewWithIdentifier:@"duplicateTableName" in:sheet.contentView];
	button = [self viewWithIdentifier:@"duplicateTableButton" in:sheet.contentView];
	XCTAssertEqualObjects(name.stringValue, @"cust copy_copy");

	// Longer than PostgreSQL's 63-byte names: refused in the sheet, which stays up
	name.stringValue = [@"" stringByPaddingToLength:64 withString:@"n" startingAtIndex:0];
	[[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidChangeNotification object:name];
	XCTAssertFalse(button.isEnabled);
	[button performClick:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	[self spinUntil:^BOOL{ return NO; } timeout:0.3];
	XCTAssertEqual([self window].attachedSheet, sheet);
	XCTAssertEqual(alerts.count, 0u);

	name.stringValue = @"customers";
	[[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidChangeNotification object:name];
	XCTAssertTrue(button.isEnabled);
	[button performClick:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([self spinUntil:^BOOL{ return alerts.count == 1; } timeout:5]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([alerts.firstObject.informativeText containsString:@"already exists"], @"%@", alerts.firstObject.informativeText);

	[admin execute:@"DROP TABLE IF EXISTS public.customers_copy, public.\"cust copy\""];
	[admin disconnect];
}

#pragma mark - Structure

/// The Structure fixture on this test's server, dropped when the test ends; structure_test.<table> selected.
- (void)selectStructureTable:(NSString *)table
{
	[SPPostgresTestServers loadStructureFixtureOnPort:SPPostgresDocumentTestPort];
	[self addTeardownBlock:^{
		[SPPostgresTestServers dropStructureFixtureOnPort:SPPostgresDocumentTestPort];
	}];
	[self.document.sidebar reloadSchema:@"structure_test"];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([self.document.sidebar selectTableNamed:table]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
}

- (void)testRenameTableFromSidebarMenuReloadsAndKeepsSelection
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self.controller showWindow:nil];
	[self selectStructureTable:@"child"];
	[self.document viewStructure:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);

	SPPostgresSidebarController *sidebar = self.document.sidebar;
	NSMenu *menu = sidebar.tableMenu;
	NSMenuItem *rename = [menu itemAtIndex:[menu indexOfItemWithTarget:sidebar andAction:NSSelectorFromString(@"renameTable:")]];
	XCTAssertEqualObjects(rename.title, @"Rename Table…");

	// Only for a table
	XCTAssertTrue([sidebar selectTableNamed:@"t_view"]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertFalse([(id<NSMenuItemValidation>)rename.target validateMenuItem:rename]);
	XCTAssertTrue([sidebar selectTableNamed:@"t"]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([(id<NSMenuItemValidation>)rename.target validateMenuItem:rename]);

	// The sheet, prefilled with the name; Cancel does nothing
	[menu performActionForItemAtIndex:[menu indexOfItem:rename]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	NSWindow *sheet = [self window].attachedSheet;
	XCTAssertNotNil(sheet);
	NSTextField *name = [self viewWithIdentifier:@"renameTableName" in:sheet.contentView];
	NSButton *button = [self viewWithIdentifier:@"renameTableButton" in:sheet.contentView];
	XCTAssertEqualObjects(name.stringValue, @"t");
	[[self window] endSheet:sheet returnCode:NSModalResponseCancel];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([self spinUntil:^BOOL{ return [self window].attachedSheet == nil; } timeout:5]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects(sidebar.selectedTableName, @"t");

	// Renamed: listed under its new name, still selected, and the Structure view follows
	[menu performActionForItemAtIndex:[menu indexOfItem:rename]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	sheet = [self window].attachedSheet;
	name = [self viewWithIdentifier:@"renameTableName" in:sheet.contentView];
	button = [self viewWithIdentifier:@"renameTableButton" in:sheet.contentView];

	// Longer than PostgreSQL's 63-byte names: Rename is off, and Return (its key equivalent) is refused
	name.stringValue = [@"" stringByPaddingToLength:64 withString:@"n" startingAtIndex:0];
	[[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidChangeNotification object:name];
	XCTAssertFalse(button.isEnabled);
	[button performClick:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	[self.document closeRenameTableSheet:button];
	[self spinUntil:^BOOL{ return NO; } timeout:0.3];
	XCTAssertEqual([self window].attachedSheet, sheet);
	XCTAssertEqualObjects(sidebar.selectedTableName, @"t");

	name.stringValue = @"t renamed";
	[[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidChangeNotification object:name];
	XCTAssertTrue(button.isEnabled);
	[button performClick:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([self spinUntil:^BOOL{ return [sidebar.selectedTableName isEqualToString:@"t renamed"]; } timeout:5], @"%@ %@", sidebar.selectedTableName, alerts.firstObject.informativeText);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"t renamed"]);
	XCTAssertFalse([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"t"]);
	XCTAssertEqualObjects(self.document.structureController.table, @"t renamed");
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneStructure);
	XCTAssertTrue([[self.document windowTitleString] hasSuffix:@"/structure_test.t renamed"]);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);

	// A name that is taken: the server's message, nothing renamed
	[menu performActionForItemAtIndex:[menu indexOfItem:rename]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	sheet = [self window].attachedSheet;
	name = [self viewWithIdentifier:@"renameTableName" in:sheet.contentView];
	button = [self viewWithIdentifier:@"renameTableButton" in:sheet.contentView];
	name.stringValue = @"child";
	[[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidChangeNotification object:name];
	[button performClick:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([self spinUntil:^BOOL{ return alerts.count == 1; } timeout:5]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([alerts.firstObject.informativeText containsString:@"already exists"], @"%@", alerts.firstObject.informativeText);
	XCTAssertEqualObjects(sidebar.selectedTableName, @"t renamed");
}

/// History follows a table renamed from the sidebar menu: the entries before and after the current one name it by
/// its new name, so Back and Forward both find it (with their panes).
- (void)testRenameTableFromSidebarMenuUpdatesHistory
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self.controller showWindow:nil];
	[self selectStructureTable:@"t"];
	[self.document viewContent:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	[self.document viewStructure:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([self.document.sidebar selectTableNamed:@"child"]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneStructure);
	[self.document backForwardInHistory:[self historyMenuItemWithTag:0]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects(self.document.sidebar.selectedTableName, @"t");
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneStructure);

	// Rename Table… t to t2
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	NSMenu *menu = sidebar.tableMenu;
	NSMenuItem *rename = [menu itemAtIndex:[menu indexOfItemWithTarget:sidebar andAction:NSSelectorFromString(@"renameTable:")]];
	XCTAssertEqualObjects(rename.title, @"Rename Table…");
	[menu performActionForItemAtIndex:[menu indexOfItem:rename]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	NSWindow *sheet = [self window].attachedSheet;
	XCTAssertNotNil(sheet);
	NSTextField *name = [self viewWithIdentifier:@"renameTableName" in:sheet.contentView];
	NSButton *button = [self viewWithIdentifier:@"renameTableButton" in:sheet.contentView];
	name.stringValue = @"t2";
	[[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidChangeNotification object:name];
	[button performClick:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([self spinUntil:^BOOL{ return [sidebar.selectedTableName isEqualToString:@"t2"]; } timeout:5], @"%@ %@", sidebar.selectedTableName, alerts.firstObject.informativeText);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects(self.document.history.currentEntry[@"table"], @"t2");
	XCTAssertTrue(self.document.history.canGoForward, @"the rename isn't a new place: the entries ahead stay");

	// Back: t2's Content
	[self.document backForwardInHistory:[self historyMenuItemWithTag:0]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects(sidebar.selectedTableName, @"t2");
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneContent);

	// Forward: t2's Structure, then child's
	[self.document backForwardInHistory:[self historyMenuItemWithTag:1]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects(sidebar.selectedTableName, @"t2");
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneStructure);
	XCTAssertEqualObjects(self.document.structureController.table, @"t2");
	[self.document backForwardInHistory:[self historyMenuItemWithTag:1]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects(sidebar.selectedTableName, @"child");
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

/// R4: a rename inside the user's transaction, rolled back in Query, leaves no stale structure behind.
- (void)testRollbackAfterRenameRebuildsStructure
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self.controller showWindow:nil];
	[self selectStructureTable:@"t"];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	SPPostgresQueryController *query = self.document.queryController;

	[self.document viewQuery:nil];
	[[query editor] setString:@"BEGIN"];
	[query runAllQueries:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqual([self.document.connection transactionStatus], PGPostgresTransactionInTransaction);

	// Rename Table… from the sidebar, inside that transaction
	NSMenu *menu = sidebar.tableMenu;
	[menu performActionForItemAtIndex:[menu indexOfItemWithTarget:sidebar andAction:NSSelectorFromString(@"renameTable:")]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	NSWindow *sheet = [self window].attachedSheet;
	XCTAssertNotNil(sheet);
	NSTextField *name = [self viewWithIdentifier:@"renameTableName" in:sheet.contentView];
	name.stringValue = @"t renamed";
	[[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidChangeNotification object:name];
	[(NSButton *)[self viewWithIdentifier:@"renameTableButton" in:sheet.contentView] performClick:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([self spinUntil:^BOOL{ return [sidebar.selectedTableName isEqualToString:@"t renamed"]; } timeout:5], @"%@", alerts.firstObject.informativeText);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	[self.document viewStructure:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects(self.document.structureController.table, @"t renamed");

	// ROLLBACK undoes it: the lists show t again, and its Structure reads without an error
	[self.document viewQuery:nil];
	[[query editor] setString:@"ROLLBACK"];
	[query runAllQueries:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqual([self.document.connection transactionStatus], PGPostgresTransactionIdle);
	XCTAssertTrue([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"t"]);
	XCTAssertFalse([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"t renamed"]);
	XCTAssertTrue([sidebar selectTableNamed:@"t"]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	[self.document viewStructure:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneStructure);
	XCTAssertEqualObjects(self.document.structureController.table, @"t");
	XCTAssertEqual([self.document.structureController.columnsView numberOfRows], 8);
	XCTAssertEqualObjects(self.document.structureController.noticeText, @"");
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

- (void)testStructureChangeMarksContentStale
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self selectStructureTable:@"t"];
	[self.document viewContent:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	NSArray *before = [[self.document.contentController.tableView tableColumns] valueForKeyPath:@"headerCell.stringValue"];
	XCTAssertFalse([before containsObject:@"fresh_col"]);

	[self.document viewStructure:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	SPPostgresStructureController *structure = self.document.structureController;
	[structure addColumn:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	NSTableView *columns = structure.columnsView;
	[[columns currentEditor] setString:@"fresh_col"];
	[(id)[columns delegate] control:columns textView:(NSTextView *)[columns currentEditor] doCommandBySelector:@selector(insertNewline:)];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertFalse(structure.hasDraftColumn);

	[self.document viewContent:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	NSArray *after = [[self.document.contentController.tableView tableColumns] valueForKeyPath:@"headerCell.stringValue"];
	XCTAssertTrue([after containsObject:@"fresh_col"], @"%@", after);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);

	// A draft not saved yet is saved before leaving the pane
	[self.document viewStructure:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	[structure addColumn:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	[[columns currentEditor] setString:@"leaving_col"];
	[self.document viewContent:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneContent);
	XCTAssertFalse(structure.hasDraftColumn);
	XCTAssertTrue([[[self.document.contentController.tableView tableColumns] valueForKeyPath:@"headerCell.stringValue"] containsObject:@"leaving_col"]);

	// One that can't be saved keeps the tab on Structure
	[self.document viewStructure:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	[structure addColumn:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	[[columns currentEditor] setString:@"leaving_col"]; // taken
	[self.document viewContent:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneStructure);
	XCTAssertTrue(structure.hasDraftColumn);
	XCTAssertEqual(alerts.count, 1u);
}

- (void)testHistoryRecordsAndRestoresStructurePane
{
	[self selectStructureTable:@"t"];
	[self.document viewStructure:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects(self.document.history.currentEntry[@"pane"], @"structure");
	XCTAssertEqualObjects(self.document.history.currentEntry[@"table"], @"t");

	[self.document viewQuery:nil];
	XCTAssertEqualObjects(self.document.history.currentEntry[@"pane"], @"query");
	XCTAssertTrue([self.document.sidebar selectTableNamed:@"child"]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	[self.document viewRelations:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects(self.document.history.currentEntry[@"pane"], @"relations");

	// Back: Query, then Structure of t
	[self.document backForwardInHistory:[self historyMenuItemWithTag:0]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneQuery);
	XCTAssertEqualObjects(self.document.sidebar.selectedTableName, @"child");
	[self.document backForwardInHistory:[self historyMenuItemWithTag:0]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	[self.document backForwardInHistory:[self historyMenuItemWithTag:0]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneStructure);
	XCTAssertEqualObjects(self.document.sidebar.selectedTableName, @"t");
	XCTAssertEqualObjects(self.document.structureController.table, @"t");

	// Forward to Relations
	[self.document backForwardInHistory:[self historyMenuItemWithTag:1]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	[self.document backForwardInHistory:[self historyMenuItemWithTag:1]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	[self.document backForwardInHistory:[self historyMenuItemWithTag:1]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneRelations);
	XCTAssertEqualObjects(self.document.sidebar.selectedTableName, @"child");

	// Every pane name restores; an unknown one as Content
	for (NSString *pane in @[@"structure", @"content", @"relations", @"triggers", @"info", @"query"]) {
		[self.document _applyHistoryEntry:@{@"database": @"pgkit_test", @"schema": @"structure_test", @"table": @"t", @"pane": pane}];
		XCTAssertEqualObjects(self.document.currentPane, pane);
	}
	[self.document _applyHistoryEntry:@{@"database": @"pgkit_test", @"schema": @"structure_test", @"table": @"t", @"pane": @"no such pane"}];
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneContent);
}

- (NSMenuItem *)historyMenuItemWithTag:(NSInteger)tag
{
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"History" action:@selector(backForwardInHistory:) keyEquivalent:@""];
	item.tag = tag;
	return item;
}

- (void)testMySQLTabUnaffected
{
	[self selectStructureTable:@"t"];
	NSMenuItem *structureItem = [[NSMenuItem alloc] initWithTitle:@"Structure" action:@selector(viewStructure:) keyEquivalent:@"1"];
	XCTAssertTrue([self.controller validateMenuItem:structureItem]);

	// A MySQL tab (not connected) answers for itself, through SPDatabaseDocument
	id mysql = [self.controller addNewConnection];
	XCTAssertEqual([self.controller selectedDocument], mysql);
	XCTAssertTrue([mysql isKindOfClass:NSClassFromString(@"SPDatabaseDocument")]);
	XCTAssertEqual([self.controller validateMenuItem:structureItem], [mysql validateMenuItem:structureItem]);
	XCTAssertFalse([self.controller validateMenuItem:structureItem], @"no database on the MySQL tab");
	NSToolbarItem *mysqlStructure = nil;
	for (NSToolbarItem *item in [[self window].toolbar items]) {
		if ([item.itemIdentifier isEqualToString:@"SwitchToTableStructureToolbarItemIdentifier"]) mysqlStructure = item;
	}
	XCTAssertNotNil(mysqlStructure);
	XCTAssertEqual([mysqlStructure target], mysql);
	XCTAssertEqualObjects(NSStringFromSelector([mysqlStructure action]), @"viewStructure:");
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneContent, @"the Postgres tab isn't touched");

	// Only the Postgres tab answers on its own tab
	[[self tabView] selectTabViewItem:self.document.parentTabViewItem];
	XCTAssertTrue([self.controller validateMenuItem:structureItem]);
	[self.controller performSelector:@selector(viewStructure:) withObject:structureItem];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneStructure);
}

#pragma mark - Console

- (void)testConsoleLoggerForwardsQueries
{
	// The console reads these with -boolForKey:, so the volatile argument domain is enough: nothing is
	// written to the app's saved preferences, and the teardown block restores the domain even on failure.
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	NSDictionary *original = [prefs volatileDomainForName:NSArgumentDomain] ?: @{};
	NSMutableDictionary *domain = [original mutableCopy];
	domain[@"ConsoleEnableLogging"] = @YES;
	domain[@"ConsoleEnableInterfaceLogging"] = @YES;
	[prefs removeVolatileDomainForName:NSArgumentDomain];
	[prefs setVolatileDomain:domain forName:NSArgumentDomain];
	[self addTeardownBlock:^{
		[prefs removeVolatileDomainForName:NSArgumentDomain];
		[prefs setVolatileDomain:original forName:NSArgumentDomain];
	}];
	XCTAssertTrue([prefs boolForKey:@"ConsoleEnableLogging"]);
	XCTAssertTrue([prefs boolForKey:@"ConsoleEnableInterfaceLogging"]);

	XCTAssertNotNil([self.connection execute:@"SELECT 4242"]);

	// Test-only read of the console's existing storage (no public accessor)
	id queryController = [(id)NSClassFromString(@"SPQueryController") valueForKey:@"sharedQueryController"];
	NSArray *messages = [queryController valueForKey:@"messagesFullSet"];
	id found = nil;
	for (id message in messages) {
		if ([[message valueForKey:@"message"] hasPrefix:@"SELECT 4242"]) found = message;
	}
	XCTAssertNotNil(found);
	XCTAssertEqualObjects([found valueForKey:@"messageConnection"], @"pg18 test");
	XCTAssertEqualObjects([found valueForKey:@"messageDatabase"], @"pgkit_test");
}

#pragma mark - Database switching

- (void)testSwitchingDatabaseReconnects
{
	PGPostgresConnection *oldConnection = self.connection;
	[self.document switchToDatabase:@"pgkit_nopublic"];
	XCTAssertTrue(self.document.isProcessing, @"the tab shows progress while the new session connects");

	XCTAssertTrue([self spinUntil:^BOOL{ return [[self.document windowTitleString] hasSuffix:@"/pgkit_nopublic"]; } timeout:20],
				  @"%@ (sheet: %@)", [self.document windowTitleString], [self window].attachedSheet);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertFalse(self.document.isProcessing);
	XCTAssertTrue([self spinUntil:^BOOL{ return !oldConnection.isConnected; } timeout:5], @"the previous connection is closed");
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertFalse([[self.document.sidebar itemTitlesInSection:@"TABLES"] containsObject:@"customers"]);
	XCTAssertNotEqualObjects(self.document.sidebar.selectedSchema, @"public");
	XCTAssertEqualObjects([self window].title, [self.document windowTitleString]);
	XCTAssertEqualObjects(self.document.favorite.database, @"pgkit_nopublic");
	XCTAssertNotEqual(self.document.connection, oldConnection);
	XCTAssertEqualObjects([self.document.parentTabViewItem label], @"pg18 test");
}

/// Answers the tab's confirmations with `answer`, collecting the alerts asked.
- (NSMutableArray<NSAlert *> *)answerConfirmationsWith:(BOOL)answer
{
	NSMutableArray<NSAlert *> *asked = [NSMutableArray array];
	self.document.confirmationPresenter = ^(NSAlert *alert, void (^completion)(BOOL)) {
		[asked addObject:alert];
		completion(answer);
	};
	return asked;
}

/// Picks database in the toolbar's database pop-up, as the user does.
- (void)chooseInDatabasePopup:(NSString *)database
{
	NSPopUpButton *popup = [self databasePopup];
	XCTAssertNotEqual([popup indexOfItemWithTitle:database], -1, @"%@ not listed", database);
	[popup selectItemWithTitle:database];
	[popup sendAction:[popup action] to:[popup target]];
}

- (void)testDatabaseSwitchWhenIdleIsNotConfirmed
{
	NSMutableArray<NSAlert *> *asked = [self answerConfirmationsWith:NO];
	[self chooseInDatabasePopup:@"pgkit_nopublic"];
	XCTAssertTrue([self spinUntil:^BOOL{ return [[self.document windowTitleString] hasSuffix:@"/pgkit_nopublic"] && !self.document.isProcessing; } timeout:20]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqual(asked.count, 0u);
}

- (void)testDatabaseSwitchWithOpenTransactionCancelKeepsIt
{
	NSMutableArray<NSAlert *> *asked = [self answerConfirmationsWith:NO];
	XCTAssertNotNil([self.connection execute:@"BEGIN"]);
	XCTAssertNotNil([self.connection execute:@"CREATE TEMP TABLE sp_switch_tx (a int)"]);

	[self chooseInDatabasePopup:@"pgkit_nopublic"];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqual(asked.count, 1u, @"the user is asked before the transaction is rolled back");
	XCTAssertTrue([asked[0].messageText containsString:@"transaction"], @"%@", asked[0].messageText);
	XCTAssertEqualObjects(asked[0].buttons[0].title, @"Switch");
	XCTAssertEqualObjects(asked[0].buttons[1].title, @"Cancel");

	// Cancelled: same session, transaction still open, pop-up back on the current database
	XCTAssertFalse(self.document.isProcessing);
	XCTAssertEqual(self.document.connection, self.connection);
	XCTAssertTrue(self.connection.isConnected);
	XCTAssertEqual([self.connection transactionStatus], PGPostgresTransactionInTransaction);
	XCTAssertEqualObjects([[self databasePopup] titleOfSelectedItem], @"pgkit_test");
	XCTAssertTrue([[self.document windowTitleString] hasSuffix:@"/pgkit_test"]);

	// An aborted transaction is asked about too
	XCTAssertNil([self.connection execute:@"SELECT 1/0"]);
	[self.document switchToDatabase:@"pgkit_nopublic"];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqual(asked.count, 2u);
	XCTAssertEqual(self.document.connection, self.connection);
	XCTAssertNotNil([self.connection execute:@"ROLLBACK"]);
}

- (void)testDatabaseSwitchWithOpenTransactionConfirmedSwitches
{
	NSMutableArray<NSAlert *> *asked = [self answerConfirmationsWith:YES];
	PGPostgresConnection *oldConnection = self.connection;
	XCTAssertNotNil([oldConnection execute:@"BEGIN"]);

	[self chooseInDatabasePopup:@"pgkit_nopublic"];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqual(asked.count, 1u);
	XCTAssertTrue([self spinUntil:^BOOL{ return [[self.document windowTitleString] hasSuffix:@"/pgkit_nopublic"] && !self.document.isProcessing; } timeout:20]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertNotEqual(self.document.connection, oldConnection);
	// Closed once the old runner's worker is idle (from a later run loop turn)
	XCTAssertTrue([self spinUntil:^BOOL{ return !oldConnection.isConnected; } timeout:5]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
}

- (void)testFailedDatabaseSwitchKeepsConnectionAndShowsSheet
{
	[self.controller showWindow:nil];
	[self.document switchToDatabase:@"sp_no_such_database"];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);

	XCTAssertTrue([self spinUntil:^BOOL{ return [self window].attachedSheet != nil; } timeout:20]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertFalse(self.document.isProcessing);
	XCTAssertTrue(self.connection.isConnected);
	XCTAssertEqual(self.document.connection, self.connection);
	XCTAssertTrue([[self.document windowTitleString] hasSuffix:@"/pgkit_test"]);
	XCTAssertTrue([[self.document.sidebar itemTitlesInSection:@"TABLES"] containsObject:@"customers"]);
}

#pragma mark - Catalog errors

- (NSPopUpButton *)databasePopup
{
	for (NSToolbarItem *item in [self.document toolbar].items) {
		if ([item.itemIdentifier isEqualToString:@"DatabaseSelectToolbarItemIdentifier"]) return (NSPopUpButton *)item.view;
	}
	return nil;
}

/// As MySQL's: "Choose Database...", Add Database... and Refresh Databases above the databases. Choosing one of the
/// first three leaves the tab in its database (the pop-up shows it again); Add Database... asks for the name.
- (void)testDatabasePopupHasAddAndRefreshAsMySQL
{
	NSPopUpButton *popup = [self databasePopup];
	NSArray *items = popup.itemArray;
	XCTAssertGreaterThan(items.count, 5u);
	XCTAssertEqualObjects([items[0] title], @"Choose Database...");
	XCTAssertTrue([items[1] isSeparatorItem]);
	XCTAssertEqualObjects([items[2] title], @"Add Database...");
	XCTAssertEqual([items[2] action], @selector(addDatabase:));
	XCTAssertEqual([items[2] target], self.document);
	XCTAssertEqualObjects([items[3] title], @"Refresh Databases");
	XCTAssertEqual([items[3] action], @selector(refreshDatabases:));
	XCTAssertEqual([items[3] target], self.document);
	XCTAssertTrue([items[4] isSeparatorItem]);
	NSArray *databases = [[popup itemTitles] subarrayWithRange:NSMakeRange(5, items.count - 5)];
	XCTAssertTrue([databases containsObject:@"pgkit_test"]);
	XCTAssertTrue([databases containsObject:@"pgkit_nopublic"]);
	XCTAssertEqualObjects(popup.titleOfSelectedItem, @"pgkit_test");
	XCTAssertTrue([self.document validateMenuItem:items[2]], @"Add Database... is enabled when idle");
	XCTAssertTrue([self.document validateMenuItem:items[3]]);

	// "Choose Database...": no switch, the tab's database shown again
	[popup selectItemAtIndex:0];
	[popup sendAction:[popup action] to:[popup target]];
	XCTAssertFalse(self.document.isProcessing);
	XCTAssertEqualObjects(popup.titleOfSelectedItem, @"pgkit_test");

	// Refresh Databases, as chosen in the pop-up: the list read again, the tab's database shown
	[popup selectItemAtIndex:3];
	[NSApp sendAction:[items[3] action] to:[items[3] target] from:items[3]];
	XCTAssertEqualObjects(popup.titleOfSelectedItem, @"pgkit_test");
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects([[popup itemTitles] subarrayWithRange:NSMakeRange(5, popup.numberOfItems - 5)], databases);
	XCTAssertEqualObjects(popup.titleOfSelectedItem, @"pgkit_test");

	// Add Database..., as chosen in the pop-up: the name sheet, the tab's database shown
	[popup selectItemAtIndex:2];
	[NSApp sendAction:[popup.itemArray[2] action] to:[popup.itemArray[2] target] from:popup.itemArray[2]];
	XCTAssertEqualObjects(popup.titleOfSelectedItem, @"pgkit_test");
	SPPostgresNameSheet *sheet = [SPPostgresNameSheet currentSheet];
	XCTAssertNotNil(sheet, @"the Add Database sheet");
	XCTAssertEqualObjects(sheet.sheet.title, @"Add Database");
	[sheet cancel:nil];
	XCTAssertNil([SPPostgresNameSheet currentSheet]);
	XCTAssertFalse(self.document.isProcessing, @"cancelled: nothing created");
}

/// The connection's "Show all databases" off: the database selector lists only the tab's database.
- (void)testDatabasePopupListsOnlyTheConnectionsDatabaseWhenNotShowingAll
{
	NSArray *all = [[self databasePopup] itemTitles];
	XCTAssertTrue([all containsObject:@"pgkit_nopublic"], @"%@", all);

	[(SPPostgresFavorite *)[self.document valueForKey:@"favorite"] setShowAllDatabases:NO];
	[self.document refreshDatabases:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	NSPopUpButton *popup = [self databasePopup];
	XCTAssertEqualObjects([popup itemTitles], (@[@"Choose Database...", @"", @"Add Database...", @"Refresh Databases", @"", @"pgkit_test"]));
	XCTAssertEqualObjects([popup titleOfSelectedItem], @"pgkit_test");

	[(SPPostgresFavorite *)[self.document valueForKey:@"favorite"] setShowAllDatabases:YES];
	[self.document refreshDatabases:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects([[self databasePopup] itemTitles], all);
}

/// Collects what the tab would show as sheets.
- (NSMutableArray<NSAlert *> *)captureAlerts
{
	NSMutableArray<NSAlert *> *alerts = [NSMutableArray array];
	self.document.alertPresenter = ^(NSAlert *alert) { [alerts addObject:alert]; };
	return alerts;
}

/// The connection goes away under the tab (as after a server restart or an idle-killed tunnel):
/// reloading reports the loss once per reload and keeps the lists that were shown.
- (void)testCatalogFailuresAfterDisconnectAreReportedAndListsKept
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	NSArray *tables = [sidebar itemTitlesInSection:@"TABLES"];
	NSArray *views = [sidebar itemTitlesInSection:@"VIEWS"];
	NSArray *extensions = [sidebar itemTitlesInSection:@"EXTENSIONS"];
	NSArray *databases = [[self databasePopup] itemTitles];
	XCTAssertTrue([tables containsObject:@"customers"]);
	XCTAssertTrue([databases containsObject:@"pgkit_nopublic"]);
	XCTAssertEqual(alerts.count, 0u);

	[self.connection disconnect];

	// Schema change: tables and views both fail, reported once
	[sidebar reloadSchema:@"public"];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertNotNil(sidebar.lastError);
	XCTAssertEqual(alerts.count, 1u);
	XCTAssertTrue([alerts.lastObject.messageText.lowercaseString containsString:@"lost"], @"%@", alerts.lastObject.messageText);
	XCTAssertEqualObjects([sidebar itemTitlesInSection:@"TABLES"], tables, @"lists are kept");
	XCTAssertEqualObjects([sidebar itemTitlesInSection:@"VIEWS"], views);
	XCTAssertEqualObjects(sidebar.selectedSchema, @"public");

	// Full sidebar reload (schemas, extensions, tables): once
	[sidebar reloadWithCatalog:[sidebar valueForKey:@"catalog"]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqual(alerts.count, 2u);
	XCTAssertEqualObjects([sidebar itemTitlesInSection:@"TABLES"], tables);
	XCTAssertEqualObjects([sidebar itemTitlesInSection:@"EXTENSIONS"], extensions);

	// Refresh Databases: reported, and the picker keeps its databases
	[self.document refreshDatabases:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqual(alerts.count, 3u);
	XCTAssertTrue([alerts.lastObject.messageText.lowercaseString containsString:@"lost"], @"%@", alerts.lastObject.messageText);
	XCTAssertEqualObjects([[self databasePopup] itemTitles], databases);
	XCTAssertEqualObjects([[self databasePopup] titleOfSelectedItem], @"pgkit_test");
}

/// A backend killed on the server: the next catalog query fails, the connection is then not connected,
/// and the server's reason is included.
- (void)testServerTerminatedConnectionIsReportedAsLost
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	NSUInteger pid = [self.connection serverProcessId];

	PGPostgresConnection *admin = [SPPostgresTestServers connectedConnectionOnPort:SPPostgresDocumentTestPort];
	NSString *terminate = [NSString stringWithFormat:@"SELECT pg_terminate_backend(%lu)", (unsigned long)pid];
	XCTAssertNotNil([admin execute:terminate]);
	[admin disconnect];

	[self.document.sidebar reloadSchema:@"public"];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertFalse(self.connection.isConnected);
	XCTAssertEqual(alerts.count, 1u);
	NSAlert *alert = alerts.firstObject;
	XCTAssertTrue([alert.messageText.lowercaseString containsString:@"lost"], @"%@", alert.messageText);
	XCTAssertTrue([alert.informativeText containsString:@"terminat"] || [alert.informativeText containsString:@"closed"],
				  @"the server's reason is included: %@", alert.informativeText);
	XCTAssertTrue([[self.document.sidebar itemTitlesInSection:@"TABLES"] containsObject:@"customers"]);
}

/// Without a presenter the error is a sheet on the tab's window.
- (void)testCatalogFailureShowsSheetOnWindow
{
	[self.controller showWindow:nil];
	[self.connection disconnect];
	[self.document refreshDatabases:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([self spinUntil:^BOOL{ return [self window].attachedSheet != nil; } timeout:5]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
}

/// An error while the tab is in the background waits until the tab is active again.
- (void)testCatalogFailureInBackgroundTabWaitsUntilActive
{
	[self.controller showWindow:nil];
	[self.controller addNewConnection];
	XCTAssertNotEqual([self.controller selectedDocument], self.document);

	[self.connection disconnect];
	[self.document refreshDatabases:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	(void)[self spinUntil:^BOOL{ return NO; } timeout:0.3];
	XCTAssertNil([self window].attachedSheet);

	[[self tabView] selectTabViewItem:self.document.parentTabViewItem];
	XCTAssertTrue([self spinUntil:^BOOL{ return [self window].attachedSheet != nil; } timeout:5]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
}

#pragma mark - Database switch passwords

/// The switch connector gets the passwords the tab's connector was given, so an SSH favorite
/// isn't asked for its SSH password again.
- (void)testDatabaseSwitchReusesPasswords
{
	PGPostgresConnection *connection = nil;
	SPPostgresConnector *connector = [self connectorForFavorite:self.favorite sshPassword:@"ssh secret" connection:&connection];
	XCTAssertEqualObjects(connector.password, @"pgkit");
	XCTAssertEqualObjects(connector.sshPassword, @"ssh secret");

	SPPostgresDocument *document = [[SPPostgresDocument alloc] initWithConnection:connection connector:connector favorite:self.favorite];
	[self.controller addTabDocument:document atIndex:1 select:YES];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);

	[document switchToDatabase:@"pgkit_nopublic"];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
	SPPostgresConnector *pending = [document valueForKey:@"pendingConnector"];
	XCTAssertNotNil(pending);
	XCTAssertEqualObjects(pending.password, @"pgkit");
	XCTAssertEqualObjects(pending.sshPassword, @"ssh secret");

	XCTAssertTrue([self spinUntil:^BOOL{ return [[document windowTitleString] hasSuffix:@"/pgkit_nopublic"]; } timeout:20]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);

	// ...and the next switch still has them
	[document switchToDatabase:@"pgkit_test"];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
	pending = [document valueForKey:@"pendingConnector"];
	XCTAssertEqualObjects(pending.password, @"pgkit");
	XCTAssertEqualObjects(pending.sshPassword, @"ssh secret");
	XCTAssertTrue([self spinUntil:^BOOL{ return [[document windowTitleString] hasSuffix:@"/pgkit_test"]; } timeout:20]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
}

#pragma mark - Extensions

// MySQL's identifiers (the app's constants aren't exported to the test bundle)
static NSString * const SPDocumentTestToolbarStructure = @"SwitchToTableStructureToolbarItemIdentifier";
static NSString * const SPDocumentTestToolbarContent = @"SwitchToTableContentToolbarItemIdentifier";
static NSString * const SPDocumentTestToolbarRelations = @"SwitchToTableRelationsToolbarItemIdentifier";
static NSString * const SPDocumentTestToolbarTriggers = @"SwitchToTableTriggersToolbarItemIdentifier";
static NSString * const SPDocumentTestToolbarInfo = @"SwitchToTableInfoToolbarItemIdentifier";
static NSString * const SPDocumentTestToolbarQuery = @"SwitchToRunQueryToolbarItemIdentifier";

/**
 * A document on database pgkit_ext (prepared by extensionTestConnectionOnPort:, then `sql` run there), in a new
 * tab of the window, selected; its alerts and confirmations are recorded (extensionAlerts, extensionConfirmations,
 * answered with extensionConfirmAnswer).
 */
- (SPPostgresDocument *)extensionDocumentOnPort:(NSUInteger)port running:(NSArray<NSString *> *)sql
{
	PGPostgresConnection *prepare = [SPPostgresTestServers extensionTestConnectionOnPort:port];
	XCTAssertNotNil(prepare);
	for (NSString *statement in sql) XCTAssertNotNil([prepare execute:statement], @"%@: %@", statement, prepare.lastError.errorPrimaryMessage);
	[prepare disconnect];
	[self addTeardownBlock:^{ [[SPPostgresTestServers extensionTestConnectionOnPort:port] disconnect]; }];

	SPPostgresFavorite *favorite = [self.favorite copy];
	favorite.name = [NSString stringWithFormat:@"pg%lu extensions", (unsigned long)port];
	favorite.port = port;
	favorite.database = @"pgkit_ext";
	PGPostgresConnection *connection = nil;
	SPPostgresConnector *connector = [self connectorForFavorite:favorite sshPassword:nil connection:&connection];
	SPPostgresDocument *document = [[SPPostgresDocument alloc] initWithConnection:connection connector:connector favorite:favorite];

	if (!self.extensionAlerts) self.extensionAlerts = [NSMutableArray array];
	if (!self.extensionConfirmations) self.extensionConfirmations = [NSMutableArray array];
	[self.extensionAlerts removeAllObjects];
	[self.extensionConfirmations removeAllObjects];
	self.extensionConfirmAnswer = YES;
	NSMutableArray *alerts = self.extensionAlerts;
	NSMutableArray *confirmations = self.extensionConfirmations;
	__weak SPPostgresDocumentTests *weakSelf = self;
	document.alertPresenter = ^(NSAlert *alert) { [alerts addObject:alert]; };
	document.confirmationPresenter = ^(NSAlert *alert, void (^completion)(BOOL)) {
		[confirmations addObject:alert];
		completion(weakSelf.extensionConfirmAnswer);
	};
	[self.controller addTabDocument:document atIndex:[[self tabView] numberOfTabViewItems] select:YES];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
	XCTAssertEqual([self.controller selectedDocument], document);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
	return document;
}

/// Selects an extension as a click would (asking the tab first).
- (void)selectExtension:(NSString *)name in:(SPPostgresDocument *)document
{
	XCTAssertTrue([document sidebarShouldChangeSelection:document.sidebar]);
	XCTAssertTrue([document.sidebar selectExtensionNamed:name], @"%@", name);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
}

- (NSToolbarItem *)toolbarItem:(NSString *)identifier of:(SPPostgresDocument *)document
{
	for (NSToolbarItem *item in [[document toolbar] items]) {
		if ([[item itemIdentifier] isEqualToString:identifier]) return item;
	}
	XCTFail(@"No toolbar item %@", identifier);
	return nil;
}

- (NSMenuItem *)menuItem:(SEL)action key:(NSString *)key
{
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSStringFromSelector(action) action:action keyEquivalent:key];
	[item setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
	return item;
}

- (NSInteger)rowTitled:(NSString *)title group:(BOOL)group in:(SPPostgresSidebarController *)sidebar
{
	NSOutlineView *outline = [self outlineOf:sidebar];
	for (NSInteger row = 0; row < outline.numberOfRows; row++) {
		id item = [outline itemAtRow:row];
		if ([[item valueForKey:@"title"] isEqualToString:title] && [outline.delegate outlineView:outline isGroupItem:item] == group) return row;
	}
	XCTFail(@"No row %@", title);
	return -1;
}

- (NSOutlineView *)outlineOf:(SPPostgresSidebarController *)sidebar
{
	NSMutableArray *queue = [NSMutableArray arrayWithObject:[sidebar view]];
	while (queue.count) {
		NSView *v = queue.firstObject; [queue removeObjectAtIndex:0];
		if ([v isKindOfClass:[NSOutlineView class]]) return (NSOutlineView *)v;
		[queue addObjectsFromArray:v.subviews];
	}
	return nil;
}

- (void)testSelectingExtensionShowsExtensionPane
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresDocument *document = [self extensionDocumentOnPort:port.unsignedIntegerValue running:@[@"CREATE EXTENSION citext", @"CREATE TABLE public.sp_t5_items (id int)"]];
		SPPostgresSidebarController *sidebar = document.sidebar;
		XCTAssertTrue([[sidebar itemTitlesInSection:@"EXTENSIONS"] containsObject:@"citext"], @"%@", port);
		XCTAssertTrue([sidebar selectTableNamed:@"sp_t5_items"]);
		XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
		[document viewStructure:nil];
		XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
		NSDictionary *entry = document.history.currentEntry;

		[self selectExtension:@"citext" in:document];
		XCTAssertEqualObjects(sidebar.selectedExtensionName, @"citext");
		XCTAssertNil(sidebar.selectedTableName);
		XCTAssertNil(sidebar.selectedSequenceName);
		XCTAssertEqualObjects(document.currentPane, SPPostgresPaneExtension);
		XCTAssertNotNil([[document.extensionController view] window], @"in the window");
		XCTAssertEqualObjects(document.extensionController.nameField.stringValue, @"citext");
		XCTAssertEqualObjects(document.history.currentEntry, entry, @"not recorded in History");

		// As with a sequence: only Structure (which is the Extension pane here), Query and the document's own items
		for (NSString *identifier in @[SPDocumentTestToolbarContent, SPDocumentTestToolbarRelations, SPDocumentTestToolbarTriggers, SPDocumentTestToolbarInfo]) {
			XCTAssertFalse([document validateToolbarItem:[self toolbarItem:identifier of:document]], @"%@", identifier);
		}
		XCTAssertTrue([document validateToolbarItem:[self toolbarItem:SPDocumentTestToolbarStructure of:document]]);
		XCTAssertTrue([document validateToolbarItem:[self toolbarItem:SPDocumentTestToolbarQuery of:document]]);
		XCTAssertEqualObjects([[document toolbar] selectedItemIdentifier], SPDocumentTestToolbarStructure, @"the Extension pane highlights Structure");
		for (NSValue *selector in @[[NSValue valueWithPointer:@selector(viewContent:)], [NSValue valueWithPointer:@selector(viewRelations:)],
									[NSValue valueWithPointer:@selector(viewTriggers:)], [NSValue valueWithPointer:@selector(viewStatus:)]]) {
			NSMenuItem *item = [self menuItem:(SEL)[selector pointerValue] key:@""];
			XCTAssertFalse([self.controller validateMenuItem:item], @"%@", item.title);
		}
		XCTAssertTrue([self.controller validateMenuItem:[self menuItem:@selector(viewQuery:) key:@"6"]]);

		// ⌘1 goes back to the Extension pane from Query, as with sequences
		[document viewQuery:nil];
		XCTAssertEqualObjects(document.currentPane, SPPostgresPaneQuery);
		NSMenuItem *structureItem = [self menuItem:@selector(viewStructure:) key:@"1"];
		XCTAssertTrue([self.controller validateMenuItem:structureItem]);
		[self.controller performSelector:@selector(viewStructure:) withObject:structureItem];
		XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
		XCTAssertEqualObjects(document.currentPane, SPPostgresPaneExtension);
		XCTAssertEqualObjects([[document toolbar] selectedItemIdentifier], SPDocumentTestToolbarStructure);
		XCTAssertEqualObjects(document.history.currentEntry, entry, @"not recorded in History");

		// So does the Structure toolbar item
		[document viewQuery:nil];
		NSToolbarItem *structureToolbarItem = [self toolbarItem:SPDocumentTestToolbarStructure of:document];
		XCTAssertTrue([document validateToolbarItem:structureToolbarItem]);
		[NSApp sendAction:structureToolbarItem.action to:structureToolbarItem.target from:structureToolbarItem];
		XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
		XCTAssertEqualObjects(document.currentPane, SPPostgresPaneExtension);
		XCTAssertEqualObjects(document.history.currentEntry, entry, @"not recorded in History");

		// Back to the table: the pane before the extension (Structure)
		XCTAssertTrue([document sidebarShouldChangeSelection:sidebar]);
		XCTAssertTrue([sidebar selectTableNamed:@"sp_t5_items"]);
		XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
		XCTAssertNil(sidebar.selectedExtensionName);
		XCTAssertEqualObjects(document.currentPane, SPPostgresPaneStructure);
		XCTAssertEqual(self.extensionAlerts.count, 0u, @"%@", self.extensionAlerts.firstObject.informativeText);
	}
}

- (void)testDropExtensionConfirmsAndDrops
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresDocument *document = [self extensionDocumentOnPort:port.unsignedIntegerValue running:@[@"CREATE EXTENSION citext"]];
		SPPostgresSidebarController *sidebar = document.sidebar;
		[self selectExtension:@"citext" in:document];

		// From the sidebar's menu, answered Cancel: nothing happens
		self.extensionConfirmAnswer = NO;
		NSMenu *menu = sidebar.extensionMenu;
		NSMenuItem *drop = [menu itemWithTitle:@"Drop Extension…"];
		XCTAssertNotNil(drop);
		[menu performActionForItemAtIndex:[menu indexOfItem:drop]];
		XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
		XCTAssertEqual(self.extensionConfirmations.count, 1u, @"%@", port);
		NSAlert *confirmation = self.extensionConfirmations.lastObject;
		XCTAssertEqualObjects(confirmation.messageText, @"Drop extension “citext”?");
		XCTAssertEqualObjects([confirmation.buttons valueForKey:@"title"], (@[@"Drop", @"Cancel"]));
		XCTAssertTrue(confirmation.buttons.firstObject.hasDestructiveAction);
		XCTAssertTrue([[sidebar itemTitlesInSection:@"EXTENSIONS"] containsObject:@"citext"]);
		XCTAssertEqualObjects(sidebar.selectedExtensionName, @"citext");

		// From the pane's button, answered Drop: dropped, unlisted, nothing selected
		self.extensionConfirmAnswer = YES;
		[document.extensionController.dropButton performClick:nil];
		XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
		XCTAssertEqual(self.extensionConfirmations.count, 2u);
		XCTAssertEqualObjects(self.extensionConfirmations.lastObject.messageText, @"Drop extension “citext”?");
		XCTAssertEqual(self.extensionAlerts.count, 0u, @"%@", self.extensionAlerts.firstObject.informativeText);
		XCTAssertFalse([[sidebar itemTitlesInSection:@"EXTENSIONS"] containsObject:@"citext"]);
		XCTAssertNil(sidebar.selectedExtensionName);
		XCTAssertNil(sidebar.selectedTableName);
		XCTAssertNil(sidebar.selectedSequenceName);
		XCTAssertNotEqualObjects(document.currentPane, SPPostgresPaneExtension);
		XCTAssertEqual(document.connection.transactionStatus, PGPostgresTransactionIdle);
	}
}

- (void)testDropWithDependentsShowsList
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresDocument *document = [self extensionDocumentOnPort:port.unsignedIntegerValue running:@[@"CREATE EXTENSION hstore", @"CREATE TABLE public.sp_t5_items (tags hstore)"]];
		SPPostgresSidebarController *sidebar = document.sidebar;
		[self selectExtension:@"hstore" in:document];

		[document sidebar:sidebar dropExtensionNamed:@"hstore"];
		XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
		XCTAssertEqual(self.extensionConfirmations.count, 1u, @"%@", port);
		XCTAssertEqual(self.extensionAlerts.count, 1u);
		NSAlert *alert = self.extensionAlerts.lastObject;
		XCTAssertEqualObjects(alert.messageText, @"\"hstore\" can't be dropped because other objects depend on it.");
		XCTAssertTrue([alert.informativeText containsString:@"sp_t5_items"], @"%@", alert.informativeText);
		XCTAssertTrue([[sidebar itemTitlesInSection:@"EXTENSIONS"] containsObject:@"hstore"]);
		XCTAssertEqualObjects(sidebar.selectedExtensionName, @"hstore");
		XCTAssertEqualObjects(document.currentPane, SPPostgresPaneExtension);
	}
}

- (void)testExtensionMenuItems
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresDocument *document = [self extensionDocumentOnPort:port.unsignedIntegerValue running:@[@"CREATE EXTENSION citext", @"CREATE TABLE public.sp_t5_items (id int)"]];
		SPPostgresSidebarController *sidebar = document.sidebar;
		[self selectExtension:@"citext" in:document];
		NSMenu *menu = sidebar.extensionMenu;
		XCTAssertEqualObjects([menu.itemArray valueForKey:@"title"], (@[@"Install Extension…", @"Drop Extension…"]), @"%@", port);

		// On an extension: both, enabled
		XCTAssertEqual([sidebar menuForRow:[self rowTitled:@"citext" group:NO in:sidebar]], menu);
		for (NSMenuItem *item in menu.itemArray) {
			XCTAssertFalse(item.hidden, @"%@", item.title);
			XCTAssertTrue([(id<NSMenuItemValidation>)item.target validateMenuItem:item], @"%@", item.title);
		}

		// On the EXTENSIONS header (and empty space below it): Install only
		XCTAssertEqual([sidebar menuForRow:[self rowTitled:@"EXTENSIONS" group:YES in:sidebar]], menu);
		XCTAssertFalse([menu itemWithTitle:@"Install Extension…"].hidden);
		XCTAssertTrue([menu itemWithTitle:@"Drop Extension…"].hidden);
		XCTAssertEqual([sidebar menuForRow:-1], menu);
		XCTAssertTrue([menu itemWithTitle:@"Drop Extension…"].hidden);

		// On a table: the table menu, unchanged (TABLES expanded, as it starts)
		XCTAssertTrue([sidebar setSection:@"TABLES" collapsed:NO]);
		XCTAssertEqual([sidebar menuForRow:[self rowTitled:@"sp_t5_items" group:NO in:sidebar]], sidebar.tableMenu);
		XCTAssertEqual([sidebar.tableMenu indexOfItemWithTarget:sidebar andAction:NSSelectorFromString(@"renameTable:")], 0);
		XCTAssertEqual([sidebar.tableMenu indexOfItemWithTarget:sidebar andAction:NSSelectorFromString(@"duplicateTable:")], 1);

		// Drop validates on an extension only
		NSMenuItem *drop = [menu itemWithTitle:@"Drop Extension…"];
		XCTAssertTrue([sidebar selectTableNamed:@"sp_t5_items"]);
		XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
		XCTAssertFalse([(id<NSMenuItemValidation>)drop.target validateMenuItem:drop]);
	}
}

/// "Install Extension…" opens the sheet; installing citext there lists it, selects it and shows the Extension pane.
- (void)testInstallSelectsNewExtension
{
	// A sheet attaches to the nib's window once it has been shown (kept off screen)
	[[self window] setFrameOrigin:NSMakePoint(-10000, -10000)];
	[self.controller showWindow:nil];

	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresDocument *document = [self extensionDocumentOnPort:port.unsignedIntegerValue running:@[@"CREATE TABLE public.sp_t5_items (id int)"]];
		SPPostgresSidebarController *sidebar = document.sidebar;
		XCTAssertFalse([[sidebar itemTitlesInSection:@"EXTENSIONS"] containsObject:@"citext"], @"%@", port);
		XCTAssertTrue([sidebar selectTableNamed:@"sp_t5_items"]);
		XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
		[document viewStructure:nil];
		XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);

		NSMenu *menu = sidebar.extensionMenu;
		NSMenuItem *install = [menu itemWithTitle:@"Install Extension…"];
		XCTAssertTrue([(id<NSMenuItemValidation>)install.target validateMenuItem:install]);
		[menu performActionForItemAtIndex:[menu indexOfItem:install]];
		XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);

		SPPostgresInstallExtensionSheet *sheet = [SPPostgresInstallExtensionSheet currentSheet];
		XCTAssertNotNil(sheet);
		XCTAssertNotNil([self window].attachedSheet);
		XCTAssertEqualObjects(sheet.schemaPopup.titleOfSelectedItem, @"public", @"the schema selected in the left panel");
		XCTAssertTrue([sheet selectExtensionNamed:@"citext"]);
		[sheet install:sheet.installButton];

		XCTAssertTrue([self spinUntil:^BOOL{ return [self window].attachedSheet == nil; } timeout:5]);
		XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
		XCTAssertNil([SPPostgresInstallExtensionSheet currentSheet]);
		XCTAssertEqual(self.extensionAlerts.count, 0u, @"%@", self.extensionAlerts.firstObject.informativeText);
		XCTAssertTrue([[sidebar itemTitlesInSection:@"EXTENSIONS"] containsObject:@"citext"]);
		XCTAssertEqualObjects(sidebar.selectedExtensionName, @"citext");
		XCTAssertNil(sidebar.selectedTableName);
		XCTAssertEqualObjects(document.currentPane, SPPostgresPaneExtension);
		XCTAssertEqualObjects(document.extensionController.nameField.stringValue, @"citext");
		XCTAssertEqual(document.connection.transactionStatus, PGPostgresTransactionIdle);

		// Cancel: nothing changes
		[document showInstallExtensionSheet:nil];
		sheet = [SPPostgresInstallExtensionSheet currentSheet];
		XCTAssertNotNil(sheet);
		[sheet cancel:nil];
		XCTAssertTrue([self spinUntil:^BOOL{ return [self window].attachedSheet == nil; } timeout:5]);
		XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
		XCTAssertEqualObjects(sidebar.selectedExtensionName, @"citext");
		XCTAssertEqualObjects(document.currentPane, SPPostgresPaneExtension);
	}
}

/// Dropping an extension that isn't the selection (from the sidebar's menu) leaves the selected table and its pane.
- (void)testDropOtherExtensionKeepsSelectedTable
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresDocument *document = [self extensionDocumentOnPort:port.unsignedIntegerValue running:@[@"CREATE EXTENSION citext", @"CREATE TABLE public.sp_t5_items (id int)"]];
		SPPostgresSidebarController *sidebar = document.sidebar;
		XCTAssertTrue([document sidebarShouldChangeSelection:sidebar]);
		XCTAssertTrue([sidebar selectTableNamed:@"sp_t5_items"]);
		XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
		[document viewStructure:nil];
		XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
		XCTAssertEqualObjects(document.currentPane, SPPostgresPaneStructure);

		[document sidebar:sidebar dropExtensionNamed:@"citext"];
		XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
		XCTAssertEqual(self.extensionConfirmations.count, 1u, @"%@", port);
		XCTAssertEqual(self.extensionAlerts.count, 0u, @"%@", self.extensionAlerts.firstObject.informativeText);
		XCTAssertFalse([[sidebar itemTitlesInSection:@"EXTENSIONS"] containsObject:@"citext"]);
		XCTAssertEqualObjects(sidebar.selectedTableName, @"sp_t5_items");
		XCTAssertEqualObjects(document.currentPane, SPPostgresPaneStructure);
	}
}

/// Extensions don't depend on the schema picker: choosing another schema keeps the selected extension and its pane.
- (void)testSchemaChangeKeepsSelectedExtension
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		SPPostgresDocument *document = [self extensionDocumentOnPort:port.unsignedIntegerValue running:@[@"CREATE EXTENSION citext", @"DROP SCHEMA IF EXISTS sp_t5_other", @"CREATE SCHEMA sp_t5_other"]];
		[self addTeardownBlock:^{
			PGPostgresConnection *cleanup = [SPPostgresTestServers extensionTestConnectionOnPort:port.unsignedIntegerValue];
			[cleanup execute:@"DROP SCHEMA IF EXISTS sp_t5_other"];
			[cleanup disconnect];
		}];
		SPPostgresSidebarController *sidebar = document.sidebar;
		[self selectExtension:@"citext" in:document];
		XCTAssertEqualObjects(document.currentPane, SPPostgresPaneExtension);

		// As the user picks it in the schema pop-up
		NSPopUpButton *popup = nil;
		NSMutableArray *queue = [NSMutableArray arrayWithObject:[sidebar view]];
		while (queue.count && !popup) {
			NSView *v = queue.firstObject; [queue removeObjectAtIndex:0];
			if ([v isKindOfClass:[NSPopUpButton class]]) popup = (NSPopUpButton *)v;
			[queue addObjectsFromArray:v.subviews];
		}
		XCTAssertNotNil([popup itemWithTitle:@"sp_t5_other"], @"%@", popup.itemTitles);
		[popup selectItemWithTitle:@"sp_t5_other"];
		[NSApp sendAction:popup.action to:popup.target from:popup];
		XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);

		XCTAssertEqualObjects(sidebar.selectedSchema, @"sp_t5_other", @"%@", port);
		XCTAssertEqualObjects(sidebar.selectedExtensionName, @"citext");
		XCTAssertEqualObjects(document.currentPane, SPPostgresPaneExtension);
		XCTAssertEqualObjects(document.extensionController.nameField.stringValue, @"citext");
		XCTAssertEqual(self.extensionAlerts.count, 0u, @"%@", self.extensionAlerts.firstObject.informativeText);
	}
}

#pragma mark - Table list in the background

/// The sidebar's runner and the tab's (the same one) are idle.
- (void)waitForLists
{
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.sidebar.taskRunner timeout:30]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
}

- (NSPopUpButton *)schemaPopupOf:(SPPostgresSidebarController *)sidebar
{
	NSMutableArray *queue = [NSMutableArray arrayWithObject:[sidebar view]];
	while (queue.count) {
		NSView *v = queue.firstObject; [queue removeObjectAtIndex:0];
		if ([v isKindOfClass:[NSPopUpButton class]]) return (NSPopUpButton *)v;
		[queue addObjectsFromArray:v.subviews];
	}
	return nil;
}

/// A history move to another database: the new database's lists load, then the entry's schema, then its table.
- (void)testDatabaseSwitchAppliesHistoryAfterListLoads
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	[sidebar reloadSchema:@"Sales Data"];
	[self waitForLists];
	XCTAssertTrue([sidebar selectTableNamed:@"Orders 2026"]);
	[self waitForLists];

	[self.document switchToDatabase:@"pgkit_nopublic"];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([self spinUntil:^BOOL{ return [[self.document windowTitleString] hasSuffix:@"/pgkit_nopublic"]; } timeout:20], @"%@", [self.document windowTitleString]);
	[self waitForLists];
	XCTAssertEqualObjects(sidebar.selectedSchema, @"app");

	// Back: pgkit_test, "Sales Data"."Orders 2026"
	[self.document backForwardInHistory:[self historyMenuItemWithTag:0]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([self spinUntil:^BOOL{ return [[self.document windowTitleString] containsString:@"/pgkit_test"]; } timeout:20], @"%@", [self.document windowTitleString]);
	[self waitForLists];
	XCTAssertEqualObjects(sidebar.selectedSchema, @"Sales Data");
	XCTAssertEqualObjects(sidebar.selectedTableName, @"Orders 2026");
	XCTAssertEqualObjects([sidebar itemTitlesInSection:@"TABLES"], (@[@"Orders 2026"]));
	XCTAssertTrue([[self.document windowTitleString] hasSuffix:@"/pgkit_test/Sales Data.Orders 2026"], @"%@", [self.document windowTitleString]);
	XCTAssertEqualObjects(self.document.contentController.table, @"Orders 2026");

	// Restoring added no entry: forward goes back to pgkit_nopublic
	XCTAssertTrue(self.document.history.canGoForward);
	XCTAssertEqualObjects(self.document.history.currentEntry[@"table"], @"Orders 2026");
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

/// DDL in the Query view lists the new table once the lists have reloaded, keeping the selected table.
- (void)testQueryDDLReloadsListKeepingSelection
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	PGPostgresConnection *admin = [SPPostgresTestServers connectedConnectionOnPort:SPPostgresDocumentTestPort];
	[admin execute:@"DROP TABLE IF EXISTS public.sp_t8_new"];
	[self addTeardownBlock:^{
		[admin execute:@"DROP TABLE IF EXISTS public.sp_t8_new"];
		[admin disconnect];
	}];

	SPPostgresSidebarController *sidebar = self.document.sidebar;
	XCTAssertTrue([sidebar selectTableNamed:@"customers"]);
	[self waitForLists];
	XCTAssertFalse([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"sp_t8_new"]);

	[self.document viewQuery:nil];
	SPPostgresQueryController *query = self.document.queryController;
	[[query editor] setString:@"CREATE TABLE sp_t8_new(a int)"];
	[query runAllQueries:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:query.taskRunner timeout:30]);
	[self waitForLists];

	XCTAssertTrue([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"sp_t8_new"], @"%@", [sidebar itemTitlesInSection:@"TABLES"]);
	XCTAssertEqualObjects(sidebar.selectedSchema, @"public");
	XCTAssertEqualObjects(sidebar.selectedTableName, @"customers");
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneQuery);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

/// Choosing another schema while a load runs, then Cancel: the lists and the pop-up stay as they were, no alert.
- (void)testCancelSchemaSwitchKeepsList
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	// The tab's background runner; nothing else uses the connection until it is idle
	SPPostgresTaskRunner *runner = self.document.taskRunner;
	XCTAssertFalse(runner.isInline);
	SPPostgresTaskRunner *previous = sidebar.taskRunner;
	sidebar.taskRunner = runner;
	[self addTeardownBlock:^{
		sidebar.taskRunner = previous;
	}];

	NSArray *tables = [sidebar itemTitlesInSection:@"TABLES"];
	NSArray *views = [sidebar itemTitlesInSection:@"VIEWS"];
	NSPopUpButton *popup = [self schemaPopupOf:sidebar];
	XCTAssertEqualObjects(popup.titleOfSelectedItem, @"public");

	[runner runTaskWithDescription:@"Loading..." cancelTitle:@"Cancel" work:^id(PGPostgresConnection *connection, NSError **error) {
		return [connection execute:@"SELECT pg_sleep(1)"];
	} completion:nil];

	// As the user picks it in the schema pop-up: queued behind the sleep
	[popup selectItemWithTitle:@"Sales Data"];
	[NSApp sendAction:popup.action to:popup.target from:popup];
	XCTAssertTrue(runner.isBusy);
	XCTAssertEqualObjects(sidebar.selectedSchema, @"public", @"nothing is applied before the load completes");

	[runner cancelAll];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:runner timeout:10]);
	[self spinUntil:^BOOL{ return NO; } timeout:0.2];

	XCTAssertEqualObjects(sidebar.selectedSchema, @"public");
	XCTAssertEqualObjects([sidebar itemTitlesInSection:@"TABLES"], tables);
	XCTAssertEqualObjects([sidebar itemTitlesInSection:@"VIEWS"], views);
	XCTAssertEqualObjects(popup.titleOfSelectedItem, @"public");
	XCTAssertNil(sidebar.lastError);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);

	// The pop-up works again afterwards
	[popup selectItemWithTitle:@"Sales Data"];
	[NSApp sendAction:popup.action to:popup.target from:popup];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:runner timeout:10]);
	XCTAssertEqualObjects(sidebar.selectedSchema, @"Sales Data");
	XCTAssertEqualObjects([sidebar itemTitlesInSection:@"TABLES"], (@[@"Orders 2026"]));
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

/// On a background runner a reload returns at once and applies the lists before its completion is called.
- (void)testSchemaReloadAppliesBeforeCompletionOnBackgroundRunner
{
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	SPPostgresTaskRunner *runner = self.document.taskRunner;
	SPPostgresTaskRunner *previous = sidebar.taskRunner;
	sidebar.taskRunner = runner;
	[self addTeardownBlock:^{
		sidebar.taskRunner = previous;
	}];

	__block NSString *schemaSeen = nil;
	__block NSArray *tablesSeen = nil;
	__block BOOL loadedSeen = NO;
	__block NSUInteger calls = 0;
	[sidebar reloadSchema:@"Sales Data" selectingSequence:nil completion:^(BOOL loaded) {
		calls++;
		loadedSeen = loaded;
		schemaSeen = sidebar.selectedSchema;
		tablesSeen = [sidebar itemTitlesInSection:@"TABLES"];
	}];
	XCTAssertTrue(runner.isBusy);
	XCTAssertEqualObjects(runner.currentDescription, @"Reloading...");
	XCTAssertEqualObjects(runner.currentCancelTitle, @"Cancel");
	XCTAssertEqualObjects(sidebar.selectedSchema, @"public");
	XCTAssertEqual(calls, 0u);

	XCTAssertTrue([SPPostgresTestServers waitForRunner:runner timeout:10]);
	XCTAssertEqual(calls, 1u);
	XCTAssertTrue(loadedSeen);
	XCTAssertEqualObjects(schemaSeen, @"Sales Data");
	XCTAssertEqualObjects(tablesSeen, (@[@"Orders 2026"]));

	// Keeping the selection: the completion sees the table still selected
	XCTAssertTrue([sidebar selectTableNamed:@"Orders 2026"]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:runner timeout:10]);
	__block NSString *tableSeen = nil;
	[sidebar reloadKeepingSelection:^(BOOL loaded) {
		loadedSeen = loaded;
		tableSeen = sidebar.selectedTableName;
	}];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:runner timeout:10]);
	XCTAssertTrue(loadedSeen);
	XCTAssertEqualObjects(tableSeen, @"Orders 2026");
	XCTAssertEqualObjects(sidebar.selectedTableName, @"Orders 2026");
}

/// Rename Table…: the list reloads, then the renamed table is selected.
- (void)testRenameSelectsRenamedTableAfterReload
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self.controller showWindow:nil];
	[self selectStructureTable:@"child"];
	[self waitForLists];
	SPPostgresSidebarController *sidebar = self.document.sidebar;

	NSMenu *menu = sidebar.tableMenu;
	NSMenuItem *rename = [menu itemAtIndex:[menu indexOfItemWithTarget:sidebar andAction:NSSelectorFromString(@"renameTable:")]];
	XCTAssertEqualObjects(rename.title, @"Rename Table…");
	[menu performActionForItemAtIndex:[menu indexOfItem:rename]];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	NSWindow *sheet = [self window].attachedSheet;
	XCTAssertNotNil(sheet);
	NSTextField *name = [self viewWithIdentifier:@"renameTableName" in:sheet.contentView];
	name.stringValue = @"child renamed";
	[[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidChangeNotification object:name];
	[(NSButton *)[self viewWithIdentifier:@"renameTableButton" in:sheet.contentView] performClick:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertTrue([self spinUntil:^BOOL{ return [self window].attachedSheet == nil; } timeout:5]);
	[self waitForLists];

	XCTAssertEqualObjects(sidebar.selectedSchema, @"structure_test");
	XCTAssertEqualObjects(sidebar.selectedTableName, @"child renamed", @"%@", alerts.firstObject.informativeText);
	XCTAssertTrue([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"child renamed"]);
	XCTAssertFalse([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"child"]);
	XCTAssertEqualObjects(self.document.contentController.table, @"child renamed");
	XCTAssertEqualObjects(self.document.history.currentEntry[@"table"], @"child renamed");
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

/// The sidebar on a background runner of its own over a connection to pgkit_nopublic (the database switched to); the
/// runner is idle before anything else uses that connection, and is let go of (and the connection closed) at the end.
- (SPPostgresTaskRunner *)switchRunnerFor:(SPPostgresSidebarController *)sidebar connection:(PGPostgresConnection *)other
{
	SPPostgresTaskRunner *runner = [[SPPostgresTaskRunner alloc] initWithConnection:other];
	SPPostgresTaskRunner *previous = sidebar.taskRunner;
	sidebar.taskRunner = runner;
	[self addTeardownBlock:^{
		sidebar.taskRunner = previous;
		[runner invalidateWithCompletion:^{
			[other disconnect];
		}];
	}];
	return runner;
}

/// A database switch's reload has no Cancel button, and when it fails the previous database's lists don't stay.
- (void)testNewCatalogReloadFailureKeepsNoPreviousLists
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	XCTAssertTrue([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"customers"]);

	// The new database's connection, gone before its lists are read
	PGPostgresConnection *other = [SPPostgresTestServers connectedConnectionOnPort:SPPostgresDocumentTestPort database:@"pgkit_nopublic"];
	PGPostgresConnection *admin = [SPPostgresTestServers connectedConnectionOnPort:SPPostgresDocumentTestPort];
	NSString *terminate = [NSString stringWithFormat:@"SELECT pg_terminate_backend(%lu)", (unsigned long)[other serverProcessId]];
	XCTAssertNotNil([admin execute:terminate]);
	[admin disconnect];
	SPPostgresTaskRunner *runner = [self switchRunnerFor:sidebar connection:other];

	__block NSUInteger calls = 0;
	__block BOOL loadedSeen = YES;
	[sidebar reloadWithNewCatalog:[[SPPostgresCatalog alloc] initWithConnection:other] completion:^(BOOL loaded) {
		calls++;
		loadedSeen = loaded;
	}];
	XCTAssertTrue(runner.isBusy);
	XCTAssertEqualObjects(runner.currentDescription, @"Reloading...");
	XCTAssertNil(runner.currentCancelTitle, @"a database switch's reload isn't cancellable");
	XCTAssertTrue([SPPostgresTestServers waitForRunner:runner timeout:10]);

	XCTAssertEqual(calls, 1u);
	XCTAssertFalse(loadedSeen);
	XCTAssertNotNil(sidebar.lastError);
	XCTAssertGreaterThanOrEqual(alerts.count, 1u, @"the failure is reported as for any reload");
	XCTAssertNil(sidebar.selectedSchema);
	XCTAssertNil(sidebar.selectedTableName);
	for (NSString *section in @[@"TABLES", @"VIEWS", @"SEQUENCES", @"EXTENSIONS"]) {
		XCTAssertEqualObjects([sidebar itemTitlesInSection:section], (@[]), @"%@: none of pgkit_test's", section);
	}
	XCTAssertEqual([self schemaPopupOf:sidebar].numberOfItems, 0);
}

/// Cancelled all the same (cancelAll cancels everything queued): the previous database's lists go, with no alert.
- (void)testNewCatalogReloadCancelledKeepsNoPreviousLists
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	XCTAssertTrue([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"customers"]);

	PGPostgresConnection *other = [SPPostgresTestServers connectedConnectionOnPort:SPPostgresDocumentTestPort database:@"pgkit_nopublic"];
	SPPostgresTaskRunner *runner = [self switchRunnerFor:sidebar connection:other];
	[runner runTaskWithDescription:@"Loading..." cancelTitle:@"Cancel" work:^id(PGPostgresConnection *connection, NSError **error) {
		return [connection execute:@"SELECT pg_sleep(1)"];
	} completion:nil];

	__block NSUInteger calls = 0;
	__block BOOL loadedSeen = YES;
	[sidebar reloadWithNewCatalog:[[SPPostgresCatalog alloc] initWithConnection:other] completion:^(BOOL loaded) {
		calls++;
		loadedSeen = loaded;
	}];
	[runner cancelAll];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:runner timeout:10]);

	XCTAssertEqual(calls, 1u);
	XCTAssertFalse(loadedSeen);
	XCTAssertNil(sidebar.selectedSchema);
	for (NSString *section in @[@"TABLES", @"VIEWS", @"SEQUENCES", @"EXTENSIONS"]) {
		XCTAssertEqualObjects([sidebar itemTitlesInSection:section], (@[]), @"%@: none of pgkit_test's", section);
	}
	XCTAssertEqual([self schemaPopupOf:sidebar].numberOfItems, 0);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);

	// The same reload, not cancelled: pgkit_nopublic's lists
	[sidebar reloadWithNewCatalog:[[SPPostgresCatalog alloc] initWithConnection:other] completion:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:runner timeout:10]);
	XCTAssertEqualObjects(sidebar.selectedSchema, @"app");
	XCTAssertTrue([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"items"]);
	XCTAssertFalse([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"customers"]);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

#pragma mark - Panes in the background

/// The table panes on the tab's background runner (as the tab does), put back on their own when the test ends. The test waits for the runner before anything else uses the connection.
- (void)putPanesOnTabRunner
{
	SPPostgresTaskRunner *runner = self.document.taskRunner;
	XCTAssertFalse(runner.isInline);
	NSArray *panes = @[self.document.contentController, self.document.structureController, self.document.relationsController,
					   self.document.triggersController, self.document.infoController];
	for (id pane in panes) {
		SPPostgresTaskRunner *previous = [pane taskRunner];
		[pane setTaskRunner:runner];
		[self addTeardownBlock:^{
			[pane setTaskRunner:previous];
		}];
	}
}

- (void)waitForTab
{
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
}

/// Selects structure_test.<table> while a one-second statement runs, then cancels: the switch's loads are cancelled.
- (void)cancelSwitchTo:(NSString *)table
{
	SPPostgresTaskRunner *runner = self.document.taskRunner;
	[SPPostgresTestServers queueSleep:1 onRunner:runner];
	XCTAssertTrue([self.document.sidebar selectTableNamed:table], @"%@", table);
	XCTAssertTrue(runner.isBusy);
	[runner cancelAll];
	[self waitForTab];
}

/// Shows a pane (by its menu action) and waits for its load.
- (void)show:(SEL)action
{
	[NSApp sendAction:action to:self.document from:nil];
	[self waitForTab];
}

/// A table switch cancelled leaves the shown pane empty, without an alert, and stale: it loads the table when it is
/// next shown. Content (which loads on every switch) too.
- (void)testCancelledPaneReloadsWhenShownAgain
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self selectStructureTable:@"child"];
	[self putPanesOnTabRunner];
	SPPostgresDocument *document = self.document;

	// Structure (and Content, behind it)
	[self show:@selector(viewStructure:)];
	XCTAssertEqual([document.structureController.columnsView numberOfRows], 2);
	[self cancelSwitchTo:@"t"];
	XCTAssertEqualObjects(document.structureController.table, @"t");
	XCTAssertEqual([document.structureController.columnsView numberOfRows], 0);
	XCTAssertEqualObjects(document.contentController.table, @"t");
	XCTAssertEqual([document.contentController.tableView numberOfRows], 0);
	[self show:@selector(viewContent:)];
	XCTAssertEqual([document.contentController.tableView numberOfRows], 2, @"Content loads the table when shown");
	[self show:@selector(viewStructure:)];
	XCTAssertEqual([document.structureController.columnsView numberOfRows], 8, @"Structure loads the table when shown again");

	// Relations
	[self show:@selector(viewRelations:)];
	XCTAssertEqualObjects(document.relationsController.noticeText, @"Relations for table: t");
	[self cancelSwitchTo:@"child"];
	XCTAssertEqualObjects(document.relationsController.table, @"child");
	XCTAssertEqualObjects(document.relationsController.noticeText, @"");
	XCTAssertEqual([document.relationsController.relationsView numberOfRows], 0);
	[self show:@selector(viewStructure:)];
	[self show:@selector(viewRelations:)];
	XCTAssertEqual([document.relationsController.relationsView numberOfRows], 1);

	// Triggers
	[self show:@selector(viewTriggers:)];
	XCTAssertEqualObjects(document.triggersController.noticeText, @"Triggers for table: child");
	[self cancelSwitchTo:@"t"];
	XCTAssertEqualObjects(document.triggersController.table, @"t");
	XCTAssertEqualObjects(document.triggersController.noticeText, @"");
	XCTAssertEqual([document.triggersController.triggersView numberOfRows], 0);
	[self show:@selector(viewStructure:)];
	[self show:@selector(viewTriggers:)];
	XCTAssertEqual([document.triggersController.triggersView numberOfRows], 2);

	// Table Info
	[self show:@selector(viewStatus:)];
	XCTAssertEqualObjects([document.infoController.commentView string], @"the t table");
	[self cancelSwitchTo:@"child"];
	XCTAssertEqualObjects(document.infoController.table, @"child");
	XCTAssertEqualObjects([document.infoController.typeField stringValue], @"");
	[self show:@selector(viewStructure:)];
	[self show:@selector(viewStatus:)];
	XCTAssertEqualObjects([document.infoController.typeField stringValue], @"table");
	XCTAssertTrue([[document.infoController.createSyntaxView string] containsString:@"child"]);

	// Content
	[self show:@selector(viewContent:)];
	XCTAssertEqualObjects(document.contentController.table, @"child");
	[self cancelSwitchTo:@"t"];
	XCTAssertEqualObjects(document.contentController.table, @"t");
	XCTAssertEqual([document.contentController.tableView numberOfRows], 0);
	[self show:@selector(viewStructure:)];
	[self show:@selector(viewContent:)];
	XCTAssertEqual([document.contentController.tableView numberOfRows], 2, @"Content loads the table when shown again");

	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

#pragma mark - Every load on the tab's runner (Stage 8 Task 7)

/// Every pane, the Query view and the sidebar load on the tab's background runner (no inline runner is left).
- (void)testEveryControllerUsesTheTabsRunner
{
	SPPostgresTaskRunner *runner = self.document.taskRunner;
	XCTAssertFalse(runner.isInline);
	NSArray *controllers = @[self.document.sidebar, self.document.contentController, self.document.structureController, self.document.relationsController,
							 self.document.triggersController, self.document.infoController, self.document.sequenceController,
							 self.document.extensionController, self.document.queryController];
	for (id controller in controllers) XCTAssertEqual([controller taskRunner], runner, @"%@", controller);

	// So after a database switch (the new session's runner)
	[self.document switchToDatabase:@"pgkit_nopublic"];
	XCTAssertTrue([self spinUntil:^BOOL{ return [[self.document windowTitleString] hasSuffix:@"/pgkit_nopublic"] && !self.document.isProcessing; } timeout:20]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertNotEqual(self.document.taskRunner, runner);
	controllers = @[self.document.sidebar, self.document.contentController, self.document.structureController, self.document.relationsController,
					self.document.triggersController, self.document.infoController, self.document.sequenceController,
					self.document.extensionController, self.document.queryController];
	for (id controller in controllers) XCTAssertEqual([controller taskRunner], self.document.taskRunner, @"%@", controller);
}

/// Selecting a table returns at once: the tab is busy (MySQL's "Reloading..." on its display) until the shown pane
/// and Content have loaded.
- (void)testSelectingTableLoadsInBackground
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self selectStructureTable:@"child"];
	[self.document viewStructure:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqual([self.document.structureController.columnsView numberOfRows], 2);

	XCTAssertTrue([self.document.sidebar selectTableNamed:@"t"]);
	XCTAssertTrue(self.document.taskRunner.isBusy, @"the selection returns while the panes load");
	XCTAssertTrue(self.document.isProcessing);
	XCTAssertNotNil(self.document.taskRunner.currentDescription);
	XCTAssertEqualObjects(self.document.structureController.table, @"t");
	XCTAssertEqual([self.document.structureController.columnsView numberOfRows], 0, @"the previous table's columns go at once");

	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertFalse(self.document.isProcessing);
	XCTAssertEqual([self.document.structureController.columnsView numberOfRows], 8);
	XCTAssertEqualObjects(self.document.contentController.table, @"t");
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

/// The task display's Cancel stops a pane's load: the pane is empty, without an alert, and loads when shown again.
- (void)testCancelFromTaskDisplayStopsPaneLoad
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self.controller showWindow:nil];
	[self selectStructureTable:@"child"];
	[self.document viewStructure:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);

	SPPostgresTaskRunner *runner = self.document.taskRunner;
	SPPostgresTaskDisplay *display = [self.document valueForKey:@"taskDisplay"];
	XCTAssertNotNil(display);
	[SPPostgresTestServers queueSleep:1 onRunner:runner];
	XCTAssertTrue([self.document.sidebar selectTableNamed:@"t"]);
	XCTAssertTrue(runner.isBusy);
	XCTAssertEqualObjects(runner.currentCancelTitle, @"Cancel");
	NSDate *start = [NSDate date];
	[display cancelTask:display.cancelButton];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:runner timeout:30]);
	XCTAssertLessThan(-[start timeIntervalSinceNow], 0.9, @"the sleep was interrupted");

	XCTAssertEqualObjects(self.document.structureController.table, @"t");
	XCTAssertEqual([self.document.structureController.columnsView numberOfRows], 0);
	XCTAssertTrue(self.document.structureController.stale);
	XCTAssertEqual(alerts.count, 0u, @"a cancelled load shows no alert");

	// Shown again: loaded
	[self.document viewQuery:nil];
	[self.document viewStructure:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:runner timeout:30]);
	XCTAssertEqual([self.document.structureController.columnsView numberOfRows], 8);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

/// A cancelled switch to a sequence leaves its pane empty and stale; selecting it again loads it.
- (void)testCancelledSequenceSwitchReloadsWhenSelectedAgain
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self selectStructureTable:@"t"];
	SPPostgresTaskRunner *runner = self.document.taskRunner;
	XCTAssertTrue([self.document.sidebar selectSequenceNamed:@"seq_free"]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:runner timeout:30]);
	XCTAssertEqualObjects(self.document.sequenceController.incrementField.stringValue, @"5");

	[SPPostgresTestServers queueSleep:1 onRunner:runner];
	XCTAssertTrue([self.document.sidebar selectSequenceNamed:@"seq_used"]);
	[runner cancelAll];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:runner timeout:30]);
	XCTAssertEqualObjects(self.document.sequenceController.sequenceName, @"seq_used");
	XCTAssertNil(self.document.sequenceController.sequence);
	XCTAssertTrue(self.document.sequenceController.stale);

	// The same sequence again (another, then back): loaded
	XCTAssertTrue([self.document.sidebar selectTableNamed:@"t"]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:runner timeout:30]);
	XCTAssertTrue([self.document.sidebar selectSequenceNamed:@"seq_used"]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:runner timeout:30]);
	XCTAssertNotNil(self.document.sequenceController.sequence);
	XCTAssertFalse(self.document.sequenceController.stale);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

/// The database list is read on the tab's runner (never on the main thread beside a load).
- (void)testRefreshDatabasesReadsOnTheRunner
{
	NSPopUpButton *popup = [self databasePopup];
	NSArray *databases = [popup itemTitles];
	XCTAssertTrue([databases containsObject:@"pgkit_nopublic"]);
	[popup removeAllItems];
	[self.document refreshDatabases:nil];
	XCTAssertTrue(self.document.taskRunner.isBusy);
	XCTAssertFalse(popup.isEnabled, @"as MySQL's, the pop-up is off during a task");
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertEqualObjects([popup itemTitles], databases);
	XCTAssertEqualObjects([popup titleOfSelectedItem], @"pgkit_test");
	XCTAssertTrue(popup.isEnabled);
}

/// While the tab's runner is busy, the pane items (toolbar and View menu) are off, as MySQL's controls during a task:
/// a pane switched to meanwhile would queue its load behind the running one, and a Stop would cancel both. The console
/// stays available. Once idle, they are on again.
- (void)testPaneItemsDisabledWhileBusy
{
	[self selectStructureTable:@"t"];
	NSArray *identifiers = @[SPDocumentTestToolbarStructure, SPDocumentTestToolbarContent, SPDocumentTestToolbarRelations,
							 SPDocumentTestToolbarTriggers, SPDocumentTestToolbarInfo, SPDocumentTestToolbarQuery];
	NSArray *menuItems = @[[self menuItem:@selector(viewStructure:) key:@"1"], [self menuItem:@selector(viewContent:) key:@"2"],
						   [self menuItem:@selector(viewRelations:) key:@"3"], [self menuItem:@selector(viewTriggers:) key:@"4"],
						   [self menuItem:@selector(viewStatus:) key:@"5"], [self menuItem:@selector(viewQuery:) key:@"6"]];
	for (NSString *identifier in identifiers) XCTAssertTrue([self.document validateToolbarItem:[self toolbarItem:identifier of:self.document]], @"%@ idle", identifier);
	for (NSMenuItem *item in menuItems) XCTAssertTrue([self.controller validateMenuItem:item], @"%@ idle", item.title);

	SPPostgresTaskRunner *runner = self.document.taskRunner;
	[SPPostgresTestServers queueSleep:1 onRunner:runner];
	XCTAssertTrue(self.document.isProcessing);
	for (NSString *identifier in identifiers) XCTAssertFalse([self.document validateToolbarItem:[self toolbarItem:identifier of:self.document]], @"%@ busy", identifier);
	for (NSMenuItem *item in menuItems) XCTAssertFalse([self.controller validateMenuItem:item], @"%@ busy", item.title);
	XCTAssertTrue([self.document validateToolbarItem:[self toolbarItem:@"ShowConsoleIdentifier" of:self.document]], @"the console stays available");
	XCTAssertTrue([self.document validateMenuItem:[self menuItem:@selector(toggleConsole:) key:@""]]);

	// A pane switch asked for meanwhile (a direct call) does nothing
	NSString *pane = self.document.currentPane;
	[self.document viewQuery:nil];
	XCTAssertEqualObjects(self.document.currentPane, pane);

	XCTAssertTrue([SPPostgresTestServers waitForRunner:runner timeout:30]);
	for (NSString *identifier in identifiers) XCTAssertTrue([self.document validateToolbarItem:[self toolbarItem:identifier of:self.document]], @"%@ idle again", identifier);
	for (NSMenuItem *item in menuItems) XCTAssertTrue([self.controller validateMenuItem:item], @"%@ idle again", item.title);
}

#pragma mark - Truncate and Remove

/// An admin connection that has run sql (throwaway sp9_* tables and views in public); they are dropped (views
/// first, never CASCADE) when the test ends. The window is shown and the tab's lists are reloaded to show them.
- (PGPostgresConnection *)sp9AdminRunning:(NSArray<NSString *> *)sql
{
	PGPostgresConnection *admin = [SPPostgresTestServers connectedConnectionOnPort:SPPostgresDocumentTestPort];
	NSArray *cleanup = @[@"DROP VIEW IF EXISTS public.sp9_v, public.sp9_dep",
						 @"DROP TABLE IF EXISTS public.sp9_a, public.sp9_b, public.sp9_keep, public.sp9_base, public.sp9_other"];
	for (NSString *statement in cleanup) XCTAssertNotNil([admin execute:statement], @"%@", statement);
	for (NSString *statement in sql) XCTAssertNotNil([admin execute:statement], @"%@", statement);
	[self addTeardownBlock:^{
		for (NSString *statement in cleanup) [admin execute:statement];
		[admin disconnect];
	}];
	// Truncate and Remove ask only in the front tab of a shown window
	[self.controller showWindow:nil];
	[self.document.sidebar reloadKeepingSelection];
	[self waitForTab];
	return admin;
}

- (NSString *)value:(NSString *)sql on:(PGPostgresConnection *)connection
{
	return [[connection execute:sql] rowAsArray].firstObject;
}

/// The confirmation's texts, buttons and style, as MySQL's.
- (void)assertConfirmation:(NSAlert *)alert message:(NSString *)message informative:(NSString *)informative action:(NSString *)action
{
	XCTAssertEqualObjects(alert.messageText, message);
	XCTAssertEqualObjects(alert.informativeText, informative);
	XCTAssertEqualObjects([alert.buttons valueForKey:@"title"], (@[action, @"Cancel"]));
	XCTAssertEqual(alert.alertStyle, NSAlertStyleCritical);
	XCTAssertTrue(alert.buttons.firstObject.hasDestructiveAction);
	// MySQL's keys: ⌘T / ⌘D for the action, Return for Cancel
	XCTAssertEqualObjects(alert.buttons[0].keyEquivalent, [action isEqualToString:@"Truncate"] ? @"t" : @"d");
	XCTAssertEqual(alert.buttons[0].keyEquivalentModifierMask, NSEventModifierFlagCommand);
	XCTAssertEqualObjects(alert.buttons[1].keyEquivalent, @"\r");
}

/// The tab idle, and a question that waited for it (asked on the run loop turn after) asked.
- (void)waitForTabAndQuestions
{
	[self waitForTab];
	[self spinUntil:^BOOL{ return NO; } timeout:0.1];
	[self waitForTab];
}

- (void)testTruncateConfirmedEmptiesTable
{
	PGPostgresConnection *admin = [self sp9AdminRunning:@[@"CREATE TABLE public.sp9_a (id integer)", @"INSERT INTO public.sp9_a VALUES (1), (2), (3)",
														  @"CREATE TABLE public.sp9_b (id integer)", @"INSERT INTO public.sp9_b VALUES (1), (2)"]];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	NSMutableArray<NSAlert *> *asked = [self answerConfirmationsWith:YES];
	SPPostgresSidebarController *sidebar = self.document.sidebar;

	// One table, shown in Content: emptied, and Content shows it empty
	XCTAssertTrue([sidebar selectTableNamed:@"sp9_a"]);
	[self waitForTab];
	XCTAssertEqual([self.document.contentController.tableView numberOfRows], 3);
	[self.document sidebar:sidebar truncateTables:@[@"sp9_a"]];
	[self waitForTab];
	XCTAssertEqual(asked.count, 1u);
	[self assertConfirmation:asked[0] message:@"Truncate table 'sp9_a'?"
				 informative:@"Are you sure you want to delete ALL records in the table 'sp9_a'? This operation cannot be undone." action:@"Truncate"];
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM public.sp9_a" on:admin], @"0");
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM public.sp9_b" on:admin], @"2");
	XCTAssertEqualObjects(sidebar.selectedTableName, @"sp9_a");
	XCTAssertEqualObjects(self.document.contentController.table, @"sp9_a");
	XCTAssertEqual([self.document.contentController.tableView numberOfRows], 0);

	// Two tables
	XCTAssertNotNil([admin execute:@"INSERT INTO public.sp9_a VALUES (4)"]);
	XCTAssertTrue(([sidebar selectRelationsNamed:@[@"sp9_a", @"sp9_b"]]));
	[self waitForTab];
	[self.document sidebar:sidebar truncateTables:sidebar.selectedRelationNames];
	[self waitForTab];
	XCTAssertEqual(asked.count, 2u);
	[self assertConfirmation:asked[1] message:@"Truncate selected tables?"
				 informative:@"Are you sure you want to delete ALL records in the selected tables? This operation cannot be undone." action:@"Truncate"];
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM public.sp9_a" on:admin], @"0");
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM public.sp9_b" on:admin], @"0");
	XCTAssertEqualObjects(sidebar.selectedRelationNames, (@[@"sp9_a", @"sp9_b"]));
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
	XCTAssertEqual(self.document.connection.transactionStatus, PGPostgresTransactionIdle);
}

- (void)testTruncateFreesStorageShownInInfoPanes
{
	PGPostgresConnection *admin = [self sp9AdminRunning:@[@"CREATE TABLE public.sp9_a (id integer PRIMARY KEY, v text)",
														  @"INSERT INTO public.sp9_a SELECT g, repeat('x', 200) FROM generate_series(1, 20000) g",
														  @"ANALYZE public.sp9_a"]];
	[self captureAlerts];
	[self answerConfirmationsWith:YES];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	XCTAssertTrue([sidebar selectTableNamed:@"sp9_a"]);
	[self waitForTab];
	[self.document showPane:SPPostgresPaneInfo];
	[self waitForTab];
	XCTAssertEqualObjects(self.document.infoController.totalSizeField.stringValue, @"5 MB");
	XCTAssertTrue([sidebar.infoPane.lines containsObject:@"total size: 5 MB"], @"%@", sidebar.infoPane.lines);

	// The server frees the storage at once, and Table Info and the sidebar's pane show it
	[self.document sidebar:sidebar truncateTables:@[@"sp9_a"]];
	[self waitForTabAndQuestions];
	NSString *serverTotal = [SPPostgresCatalog stringForSize:[[self value:@"SELECT pg_total_relation_size('public.sp9_a')::text" on:admin] longLongValue]];
	XCTAssertEqualObjects(serverTotal, @"16 kB");
	XCTAssertEqualObjects(self.document.infoController.totalSizeField.stringValue, serverTotal);
	XCTAssertTrue([sidebar.infoPane.lines containsObject:[@"total size: " stringByAppendingString:serverTotal]], @"%@", sidebar.infoPane.lines);

	// Again from Content: switching to Table Info shows the sizes after the truncate
	XCTAssertNotNil([admin execute:@"INSERT INTO public.sp9_a SELECT g, repeat('x', 200) FROM generate_series(1, 20000) g"]);
	[self.document.infoController reload];
	[self waitForTab];
	XCTAssertEqualObjects(self.document.infoController.totalSizeField.stringValue, @"5 MB");
	[self.document showPane:SPPostgresPaneContent];
	[self waitForTab];
	[self.document sidebar:sidebar truncateTables:@[@"sp9_a"]];
	[self waitForTabAndQuestions];
	[self.document showPane:SPPostgresPaneInfo];
	[self waitForTab];
	XCTAssertEqualObjects(self.document.infoController.totalSizeField.stringValue, @"16 kB");
}

/// The question's Restart identity checkbox (off unless ticked).
- (NSButton *)restartIdentityCheckboxOf:(NSAlert *)alert
{
	NSButton *checkbox = (NSButton *)alert.accessoryView;
	XCTAssertTrue([checkbox isKindOfClass:[NSButton class]]);
	XCTAssertEqualObjects(checkbox.identifier, @"restartIdentity");
	return checkbox;
}

- (void)testTruncateRestartsIdentityOnlyWhenChecked
{
	PGPostgresConnection *admin = [self sp9AdminRunning:@[@"CREATE TABLE public.sp9_a (id serial PRIMARY KEY, v text)",
														  @"CREATE TABLE public.sp9_b (id integer GENERATED ALWAYS AS IDENTITY, v text)",
														  @"INSERT INTO public.sp9_a (v) VALUES ('a'), ('b'), ('c')",
														  @"INSERT INTO public.sp9_b (v) VALUES ('a'), ('b')"]];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	__block BOOL tick = NO;
	NSMutableArray<NSAlert *> *asked = [NSMutableArray array];
	self.document.confirmationPresenter = ^(NSAlert *alert, void (^completion)(BOOL)) {
		[asked addObject:alert];
		NSButton *checkbox = (NSButton *)alert.accessoryView;
		if (tick && [checkbox isKindOfClass:[NSButton class]]) [checkbox setState:NSControlStateValueOn];
		completion(YES);
	};
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	XCTAssertTrue([sidebar selectTableNamed:@"sp9_a"]);
	[self waitForTab];

	// Unchecked (the default): the rows go, the numbering goes on
	[self.document sidebar:sidebar truncateTables:@[@"sp9_a"]];
	[self waitForTabAndQuestions];
	XCTAssertEqual(asked.count, 1u);
	NSButton *checkbox = [self restartIdentityCheckboxOf:asked[0]];
	XCTAssertEqual(checkbox.state, NSControlStateValueOff);
	XCTAssertEqualObjects(checkbox.title, @"Restart identity (reset serial and identity counters)");
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM public.sp9_a" on:admin], @"0");
	XCTAssertEqualObjects([self value:@"INSERT INTO public.sp9_a (v) VALUES ('d') RETURNING id::text" on:admin], @"4");

	// Checked, two tables (serial and identity): both start again from 1
	tick = YES;
	XCTAssertTrue(([sidebar selectRelationsNamed:@[@"sp9_a", @"sp9_b"]]));
	[self waitForTab];
	[self.document sidebar:sidebar truncateTables:sidebar.selectedRelationNames];
	[self waitForTabAndQuestions];
	XCTAssertEqual(asked.count, 2u);
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM public.sp9_a" on:admin], @"0");
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM public.sp9_b" on:admin], @"0");
	XCTAssertEqualObjects([self value:@"INSERT INTO public.sp9_a (v) VALUES ('e') RETURNING id::text" on:admin], @"1");
	XCTAssertEqualObjects([self value:@"INSERT INTO public.sp9_b (v) VALUES ('e') RETURNING id::text" on:admin], @"1");

	// Each question starts unchecked again
	tick = NO;
	XCTAssertTrue([sidebar selectTableNamed:@"sp9_a"]);
	[self waitForTab];
	[self.document sidebar:sidebar truncateTables:@[@"sp9_a"]];
	[self waitForTabAndQuestions];
	XCTAssertEqual(asked.count, 3u);
	XCTAssertEqual([self restartIdentityCheckboxOf:asked[2]].state, NSControlStateValueOff);
	XCTAssertEqualObjects([self value:@"INSERT INTO public.sp9_a (v) VALUES ('f') RETURNING id::text" on:admin], @"2");
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
	XCTAssertEqual(self.document.connection.transactionStatus, PGPostgresTransactionIdle);
}

- (void)testReduceStorageGivesSpaceBackAndShowsSizes
{
	PGPostgresConnection *admin = [self sp9AdminRunning:@[@"CREATE TABLE public.sp9_a (id integer PRIMARY KEY, v text)",
														  @"INSERT INTO public.sp9_a SELECT g, repeat('x', 200) FROM generate_series(1, 20000) g",
														  @"DELETE FROM public.sp9_a WHERE id % 20 <> 0",
														  @"VACUUM public.sp9_a",
														  @"CREATE VIEW public.sp9_v AS SELECT id FROM public.sp9_a"]];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	NSMutableArray<NSAlert *> *asked = [self answerConfirmationsWith:YES];
	SPPostgresSidebarController *sidebar = self.document.sidebar;

	// In the right-click menu after Truncate; tables only
	NSMenu *menu = sidebar.tableMenu;
	NSInteger truncateIndex = [menu indexOfItemWithTarget:sidebar andAction:NSSelectorFromString(@"truncateTables:")];
	NSMenuItem *reduce = [menu itemAtIndex:truncateIndex + 1];
	XCTAssertEqual(reduce.action, NSSelectorFromString(@"reduceStorage:"));
	XCTAssertTrue([sidebar selectTableNamed:@"sp9_v"]);
	[self waitForTab];
	XCTAssertFalse([sidebar validateMenuItem:reduce]);
	XCTAssertTrue(reduce.hidden);
	XCTAssertTrue([sidebar selectTableNamed:@"sp9_a"]);
	[self waitForTab];
	XCTAssertTrue([sidebar validateMenuItem:reduce]);
	XCTAssertFalse(reduce.hidden);
	XCTAssertEqualObjects(reduce.title, @"Reduce Storage…");

	[self.document showPane:SPPostgresPaneInfo];
	[self waitForTab];
	NSString *before = self.document.infoController.totalSizeField.stringValue;
	long long beforeBytes = [[self value:@"SELECT pg_total_relation_size('public.sp9_a')::text" on:admin] longLongValue];

	[NSApp sendAction:reduce.action to:reduce.target from:reduce];
	[self waitForTabAndQuestions];
	[self waitForTab];
	XCTAssertEqual(asked.count, 1u);
	XCTAssertEqualObjects(asked[0].messageText, @"Reduce the storage of table 'sp9_a'?");
	XCTAssertTrue([asked[0].informativeText containsString:@"VACUUM FULL"]);
	XCTAssertEqualObjects([asked[0].buttons valueForKey:@"title"], (@[@"Reduce Storage", @"Cancel"]));
	XCTAssertEqualObjects(asked[0].buttons[1].keyEquivalent, @"\r");

	// Done: the rows stay, the space is given back, the sizes shown are the new ones
	long long afterBytes = [[self value:@"SELECT pg_total_relation_size('public.sp9_a')::text" on:admin] longLongValue];
	XCTAssertLessThan(afterBytes, beforeBytes / 5);
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM public.sp9_a" on:admin], @"1000");
	NSString *after = [SPPostgresCatalog stringForSize:afterBytes];
	XCTAssertEqual(alerts.count, 1u);
	XCTAssertEqualObjects(alerts[0].messageText, @"Storage reduced");
	XCTAssertEqualObjects(alerts[0].informativeText, ([NSString stringWithFormat:@"sp9_a: %@ → %@", [SPPostgresCatalog stringForSize:beforeBytes], after]));
	XCTAssertNotEqualObjects(before, after);
	XCTAssertEqualObjects(self.document.infoController.totalSizeField.stringValue, after);
	XCTAssertTrue([sidebar.infoPane.lines containsObject:[@"total size: " stringByAppendingString:after]], @"%@", sidebar.infoPane.lines);
	XCTAssertEqualObjects(sidebar.selectedTableName, @"sp9_a");
	XCTAssertEqual(self.document.connection.transactionStatus, PGPostgresTransactionIdle);
}

- (void)testReduceStorageOfAllTables
{
	PGPostgresConnection *admin = [self sp9AdminRunning:@[@"CREATE TABLE public.sp9_a (id integer PRIMARY KEY, v text)",
														  @"INSERT INTO public.sp9_a SELECT g, repeat('x', 200) FROM generate_series(1, 20000) g",
														  @"DELETE FROM public.sp9_a WHERE id % 20 <> 0",
														  @"CREATE TABLE public.sp9_b (id integer)",
														  @"CREATE VIEW public.sp9_v AS SELECT id FROM public.sp9_a"]];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	NSMutableArray<NSAlert *> *asked = [self answerConfirmationsWith:YES];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	NSArray<NSString *> *tables = [sidebar itemTitlesInSection:@"TABLES"];
	XCTAssertTrue([tables containsObject:@"sp9_a"] && [tables containsObject:@"sp9_b"], @"%@", tables);
	XCTAssertFalse([tables containsObject:@"sp9_v"]);

	// After Reduce Storage…; offered whatever is selected, a view included
	NSMenu *menu = sidebar.tableMenu;
	NSInteger reduceIndex = [menu indexOfItemWithTarget:sidebar andAction:NSSelectorFromString(@"reduceStorage:")];
	NSMenuItem *all = [menu itemAtIndex:reduceIndex + 1];
	XCTAssertEqual(all.action, NSSelectorFromString(@"reduceStorageOfAllTables:"));
	XCTAssertEqualObjects(all.title, @"Reduce Storage of All Tables…");
	XCTAssertTrue([sidebar selectTableNamed:@"sp9_v"]);
	[self waitForTab];
	XCTAssertTrue([sidebar validateMenuItem:all]);
	XCTAssertFalse(all.hidden);
	long long beforeBytes = [[self value:@"SELECT pg_total_relation_size('public.sp9_a')::text" on:admin] longLongValue];

	[NSApp sendAction:all.action to:all.target from:all];
	[self waitForTabAndQuestions];
	[self waitForTab];
	XCTAssertEqual(asked.count, 1u);
	XCTAssertEqualObjects(asked[0].messageText, ([NSString stringWithFormat:@"Reduce the storage of all %lu tables in schema 'public'?", (unsigned long)tables.count]));
	XCTAssertEqualObjects([asked[0].buttons valueForKey:@"title"], (@[@"Reduce Storage", @"Cancel"]));

	// Every table done: the total first, then each table; the view stays selected
	long long afterBytes = [[self value:@"SELECT pg_total_relation_size('public.sp9_a')::text" on:admin] longLongValue];
	XCTAssertLessThan(afterBytes, beforeBytes / 5);
	XCTAssertEqual(alerts.count, 1u);
	XCTAssertEqualObjects(alerts[0].messageText, @"Storage reduced");
	NSArray<NSString *> *lines = [alerts[0].informativeText componentsSeparatedByString:@"\n"];
	XCTAssertTrue([lines[0] hasPrefix:@"Total: "], @"%@", lines);
	XCTAssertEqualObjects(lines[1], @"");
	XCTAssertEqual(lines.count, tables.count + 2, @"%@", lines);
	XCTAssertTrue([lines containsObject:([NSString stringWithFormat:@"sp9_a: %@ → %@", [SPPostgresCatalog stringForSize:beforeBytes], [SPPostgresCatalog stringForSize:afterBytes]])], @"%@", lines);
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM public.sp9_a" on:admin], @"1000");
	XCTAssertEqualObjects(sidebar.selectedTableName, @"sp9_v");
	XCTAssertEqual(self.document.connection.transactionStatus, PGPostgresTransactionIdle);
}

- (void)testReduceStorageCancelledOrInsideTransaction
{
	PGPostgresConnection *admin = [self sp9AdminRunning:@[@"CREATE TABLE public.sp9_a (id integer)", @"INSERT INTO public.sp9_a VALUES (1), (2)"]];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	NSMutableArray<NSAlert *> *asked = [self answerConfirmationsWith:NO];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	XCTAssertTrue([sidebar selectTableNamed:@"sp9_a"]);
	[self waitForTab];
	NSString *relfilenode = [self value:@"SELECT relfilenode::text FROM pg_class WHERE oid = 'public.sp9_a'::regclass" on:admin];

	// Cancel in the question: nothing is sent
	[self.document sidebar:sidebar reduceStorageOfTables:@[@"sp9_a"]];
	[self waitForTabAndQuestions];
	XCTAssertEqual(asked.count, 1u);
	XCTAssertEqualObjects([self value:@"SELECT relfilenode::text FROM pg_class WHERE oid = 'public.sp9_a'::regclass" on:admin], relfilenode);
	XCTAssertEqual(alerts.count, 0u);

	// A transaction open on the tab's connection: refused with the reason, the transaction kept
	asked = [self answerConfirmationsWith:YES];
	XCTAssertNotNil([self.document.connection execute:@"BEGIN"]);
	[self.document sidebar:sidebar reduceStorageOfTables:@[@"sp9_a"]];
	[self waitForTabAndQuestions];
	[self waitForTab];
	XCTAssertEqual(asked.count, 1u);
	XCTAssertEqual(alerts.count, 1u);
	XCTAssertEqualObjects(alerts[0].messageText, @"Error reducing storage");
	XCTAssertTrue([alerts[0].informativeText containsString:@"A transaction is open"], @"%@", alerts[0].informativeText);
	XCTAssertEqual(self.document.connection.transactionStatus, PGPostgresTransactionInTransaction);
	XCTAssertNotNil([self.document.connection execute:@"ROLLBACK"]);
	XCTAssertEqualObjects([self value:@"SELECT relfilenode::text FROM pg_class WHERE oid = 'public.sp9_a'::regclass" on:admin], relfilenode);
}

- (void)testTruncateCancelledKeepsRows
{
	PGPostgresConnection *admin = [self sp9AdminRunning:@[@"CREATE TABLE public.sp9_a (id integer)", @"INSERT INTO public.sp9_a VALUES (1), (2), (3)",
														  @"CREATE TABLE public.sp9_b (id integer)", @"INSERT INTO public.sp9_b VALUES (1), (2)"]];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	NSMutableArray<NSAlert *> *asked = [self answerConfirmationsWith:NO];
	SPPostgresSidebarController *sidebar = self.document.sidebar;

	[self.document sidebar:sidebar truncateTables:@[@"sp9_b"]];
	[self waitForTab];
	XCTAssertEqual(asked.count, 1u);
	[self assertConfirmation:asked[0] message:@"Truncate table 'sp9_b'?"
				 informative:@"Are you sure you want to delete ALL records in the table 'sp9_b'? This operation cannot be undone." action:@"Truncate"];

	[self.document sidebar:sidebar truncateTables:@[@"sp9_a", @"sp9_b"]];
	[self waitForTab];
	XCTAssertEqual(asked.count, 2u);
	[self assertConfirmation:asked[1] message:@"Truncate selected tables?"
				 informative:@"Are you sure you want to delete ALL records in the selected tables? This operation cannot be undone." action:@"Truncate"];

	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM public.sp9_a" on:admin], @"3");
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM public.sp9_b" on:admin], @"2");
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

- (void)testRemoveTwoItemsDropsBothAndClearsSelection
{
	PGPostgresConnection *admin = [self sp9AdminRunning:@[@"CREATE TABLE public.sp9_keep (id integer)", @"CREATE TABLE public.sp9_a (id integer)",
														  @"CREATE TABLE public.sp9_b (id integer)", @"CREATE VIEW public.sp9_v AS SELECT 1 AS x"]];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	__block BOOL answer = NO;
	NSMutableArray<NSAlert *> *asked = [NSMutableArray array];
	self.document.confirmationPresenter = ^(NSAlert *alert, void (^completion)(BOOL)) {
		[asked addObject:alert];
		completion(answer);
	};
	SPPostgresSidebarController *sidebar = self.document.sidebar;

	// The kind words, answered Cancel: table, view, tables, views
	[self.document sidebar:sidebar removeRelations:@[@"sp9_a"]];
	[self.document sidebar:sidebar removeRelations:@[@"sp9_v"]];
	[self.document sidebar:sidebar removeRelations:@[@"sp9_a", @"sp9_b"]];
	[self waitForTab];
	XCTAssertEqual(asked.count, 3u);
	[self assertConfirmation:asked[0] message:@"Delete table 'sp9_a'?"
				 informative:@"Are you sure you want to delete the table 'sp9_a'? This operation cannot be undone." action:@"Delete"];
	[self assertConfirmation:asked[1] message:@"Delete view 'sp9_v'?"
				 informative:@"Are you sure you want to delete the view 'sp9_v'? This operation cannot be undone." action:@"Delete"];
	[self assertConfirmation:asked[2] message:@"Delete selected tables?"
				 informative:@"Are you sure you want to delete the selected tables? This operation cannot be undone." action:@"Delete"];
	XCTAssertTrue([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"sp9_a"]);
	XCTAssertTrue([[sidebar itemTitlesInSection:@"VIEWS"] containsObject:@"sp9_v"]);

	// History: sp9_keep, then sp9_a (the one shown before the multiple selection)
	XCTAssertTrue([sidebar selectTableNamed:@"sp9_keep"]);
	[self waitForTab];
	XCTAssertTrue([sidebar selectTableNamed:@"sp9_a"]);
	[self waitForTab];
	XCTAssertTrue(([sidebar selectRelationsNamed:@[@"sp9_a", @"sp9_v"]]));
	[self waitForTab];

	// A table and a view, confirmed: both dropped, unlisted, nothing selected
	answer = YES;
	[self.document sidebar:sidebar removeRelations:sidebar.selectedRelationNames];
	[self waitForTab];
	XCTAssertEqual(asked.count, 4u);
	[self assertConfirmation:asked[3] message:@"Delete selected items?"
				 informative:@"Are you sure you want to delete the selected items? This operation cannot be undone." action:@"Delete"];
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
	XCTAssertFalse([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"sp9_a"]);
	XCTAssertFalse([[sidebar itemTitlesInSection:@"VIEWS"] containsObject:@"sp9_v"]);
	XCTAssertTrue([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"sp9_keep"]);
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM pg_class WHERE relname IN ('sp9_a', 'sp9_v')" on:admin], @"0");
	XCTAssertEqual(sidebar.selectedRelationNames.count, 0u);
	XCTAssertNil(sidebar.selectedTableName);
	XCTAssertNil(self.document.contentController.table);
	XCTAssertEqual(self.document.connection.transactionStatus, PGPostgresTransactionIdle);

	// Back: sp9_keep; Forward: sp9_a, gone, selects nothing (no alert)
	[self.document backForwardInHistory:[self historyMenuItemWithTag:0]];
	[self waitForTab];
	XCTAssertEqualObjects(sidebar.selectedTableName, @"sp9_keep");
	[self.document backForwardInHistory:[self historyMenuItemWithTag:1]];
	[self waitForTab];
	XCTAssertNil(sidebar.selectedTableName);
	XCTAssertNil(self.document.contentController.table);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

/// Review Focus 2: a table a view depends on isn't dropped, nor is anything else of the selection; the server's message
/// names the view.
- (void)testRemoveDependencyErrorShowsServerMessage
{
	PGPostgresConnection *admin = [self sp9AdminRunning:@[@"CREATE TABLE public.sp9_base (id integer)", @"CREATE VIEW public.sp9_dep AS SELECT id FROM public.sp9_base",
														  @"CREATE TABLE public.sp9_other (id integer)"]];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	NSMutableArray<NSAlert *> *asked = [self answerConfirmationsWith:YES];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	XCTAssertTrue(([sidebar selectRelationsNamed:@[@"sp9_base", @"sp9_other"]]));
	[self waitForTab];
	NSArray *tables = [sidebar itemTitlesInSection:@"TABLES"], *views = [sidebar itemTitlesInSection:@"VIEWS"];

	[self.document sidebar:sidebar removeRelations:@[@"sp9_other", @"sp9_base"]];
	[self waitForTab];
	XCTAssertEqual(asked.count, 1u);
	XCTAssertEqualObjects(asked[0].messageText, @"Delete selected tables?");
	XCTAssertEqual(alerts.count, 1u);
	XCTAssertEqualObjects(alerts[0].messageText, @"Error deleting table");
	XCTAssertTrue([alerts[0].informativeText containsString:@"sp9_dep"], @"%@", alerts[0].informativeText);
	XCTAssertFalse([alerts[0].informativeText containsString:@"CASCADE"], @"%@", alerts[0].informativeText);
	// The server's message (the tables are dropped in one statement: its message for several objects), a blank line,
	// then the dependents one per line
	NSArray<NSString *> *lines = [alerts[0].informativeText componentsSeparatedByString:@"\n"];
	XCTAssertEqual(lines.count, 3u, @"%@", lines);
	XCTAssertEqualObjects(lines[0], @"cannot drop desired object(s) because other objects depend on them");
	XCTAssertEqualObjects(lines[1], @"");
	XCTAssertTrue([lines[2] containsString:@"sp9_dep"], @"%@", lines[2]);

	XCTAssertEqualObjects([sidebar itemTitlesInSection:@"TABLES"], tables);
	XCTAssertEqualObjects([sidebar itemTitlesInSection:@"VIEWS"], views);
	XCTAssertEqualObjects(sidebar.selectedRelationNames, (@[@"sp9_base", @"sp9_other"]));
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM pg_class WHERE relname IN ('sp9_base', 'sp9_dep', 'sp9_other')" on:admin], @"3");
	XCTAssertEqual(self.document.connection.transactionStatus, PGPostgresTransactionIdle);
}

/// Review Focus 3: while the tab's runner is busy nothing is asked or dropped; a confirmation answered after a load
/// was queued meanwhile drops nothing either.
- (void)testRemoveRefusedWhileBusy
{
	PGPostgresConnection *admin = [self sp9AdminRunning:@[@"CREATE TABLE public.sp9_a (id integer)", @"INSERT INTO public.sp9_a VALUES (1)"]];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	NSMutableArray<NSAlert *> *asked = [self answerConfirmationsWith:YES];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	SPPostgresTaskRunner *runner = self.document.taskRunner;

	[SPPostgresTestServers queueSleep:1 onRunner:runner];
	XCTAssertTrue(self.document.isProcessing);
	[self.document sidebar:sidebar removeRelations:@[@"sp9_a"]];
	[self.document sidebar:sidebar truncateTables:@[@"sp9_a"]];
	XCTAssertEqual(asked.count, 0u);
	[self waitForTab];
	XCTAssertEqual(asked.count, 0u);
	XCTAssertEqual(alerts.count, 0u);

	// Busy again by the time the answer comes
	self.document.confirmationPresenter = ^(NSAlert *alert, void (^completion)(BOOL)) {
		[asked addObject:alert];
		[SPPostgresTestServers queueSleep:1 onRunner:runner];
		completion(YES);
	};
	[self.document sidebar:sidebar removeRelations:@[@"sp9_a"]];
	[self.document sidebar:sidebar truncateTables:@[@"sp9_a"]];
	XCTAssertEqual(asked.count, 1u, @"the second is refused while the first's sleep runs");
	[self waitForTabAndQuestions];
	XCTAssertEqual(asked.count, 1u);

	XCTAssertTrue([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"sp9_a"]);
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM public.sp9_a" on:admin], @"1");
	XCTAssertEqual(alerts.count, 1u);
	XCTAssertEqualObjects(alerts[0].messageText, @"The tab is busy, so nothing was deleted.");
}

/// Truncate confirmed after a load was queued meanwhile: nothing truncated, and the user is told.
- (void)testTruncateRefusedWhenBusyAtConfirm
{
	PGPostgresConnection *admin = [self sp9AdminRunning:@[@"CREATE TABLE public.sp9_a (id integer)", @"INSERT INTO public.sp9_a VALUES (1), (2)"]];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	NSMutableArray<NSAlert *> *asked = [NSMutableArray array];
	SPPostgresTaskRunner *runner = self.document.taskRunner;
	self.document.confirmationPresenter = ^(NSAlert *alert, void (^completion)(BOOL)) {
		[asked addObject:alert];
		[SPPostgresTestServers queueSleep:1 onRunner:runner];
		completion(YES);
	};

	[self.document sidebar:self.document.sidebar truncateTables:@[@"sp9_a"]];
	XCTAssertEqual(asked.count, 1u);
	[self waitForTabAndQuestions];
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM public.sp9_a" on:admin], @"2");
	XCTAssertEqual(alerts.count, 1u);
	XCTAssertEqualObjects(alerts[0].messageText, @"The tab is busy, so nothing was truncated.");
}

/// A table other tables reference isn't truncated (never CASCADE): the server's message and DETAIL, without its HINT
/// (which suggests CASCADE).
- (void)testTruncateReferencedTableShowsMessageWithoutHint
{
	PGPostgresConnection *admin = [self sp9AdminRunning:@[@"CREATE TABLE public.sp9_base (id integer PRIMARY KEY)", @"INSERT INTO public.sp9_base VALUES (1)",
														  @"CREATE TABLE public.sp9_other (base_id integer REFERENCES public.sp9_base (id))", @"INSERT INTO public.sp9_other VALUES (1)"]];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	NSMutableArray<NSAlert *> *asked = [self answerConfirmationsWith:YES];

	[self.document sidebar:self.document.sidebar truncateTables:@[@"sp9_base"]];
	[self waitForTabAndQuestions];
	XCTAssertEqual(asked.count, 1u);
	XCTAssertEqual(alerts.count, 1u);
	XCTAssertEqualObjects(alerts[0].messageText, @"Error truncating table");
	NSString *text = alerts[0].informativeText;
	XCTAssertTrue([text hasPrefix:@"cannot truncate a table referenced in a foreign key constraint"], @"%@", text);
	XCTAssertTrue([text containsString:@"sp9_other"], @"%@", text);
	XCTAssertFalse([text containsString:@"HINT"], @"%@", text);
	XCTAssertFalse([text containsString:@"CASCADE"], @"%@", text);
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM public.sp9_base" on:admin], @"1");
	XCTAssertEqual(self.document.connection.transactionStatus, PGPostgresTransactionIdle);
}

/// Review Focus 3: a Structure draft on the shown table is saved before the confirmation is asked; one that can't be
/// saved asks nothing and drops nothing. The removed shown table leaves the panes showing no table.
- (void)testRemoveShownTableCommitsEditFirst
{
	PGPostgresConnection *admin = [self sp9AdminRunning:@[@"CREATE TABLE public.sp9_a (id integer)", @"CREATE TABLE public.sp9_b (id integer)"]];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	SPPostgresStructureController *structure = self.document.structureController;
	NSString *addedColumn = @"SELECT count(*)::text FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'sp9_a' AND column_name = 'added_col'";

	// What was saved when the question came; answered at once (as a quick ⌘D would)
	NSMutableArray<NSAlert *> *asked = [NSMutableArray array];
	__block NSString *savedWhenAsked = nil;
	__block BOOL draftWhenAsked = YES;
	self.document.confirmationPresenter = ^(NSAlert *alert, void (^completion)(BOOL)) {
		[asked addObject:alert];
		savedWhenAsked = [self value:addedColumn on:admin];
		draftWhenAsked = structure.hasDraftColumn;
		completion(YES);
	};

	XCTAssertTrue([sidebar selectTableNamed:@"sp9_a"]);
	[self waitForTab];
	[self.document viewStructure:nil];
	[self waitForTab];
	[structure addColumn:nil];
	[self waitForTab];
	[[structure.columnsView currentEditor] setString:@"added_col"];

	[self.document sidebar:sidebar removeRelations:@[@"sp9_a"]];
	[self waitForTabAndQuestions];
	XCTAssertEqual(asked.count, 1u);
	XCTAssertEqualObjects(savedWhenAsked, @"1");
	XCTAssertFalse(draftWhenAsked);
	XCTAssertEqualObjects(asked[0].messageText, @"Delete table 'sp9_a'?");
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM pg_class WHERE relname = 'sp9_a'" on:admin], @"0");
	XCTAssertFalse([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"sp9_a"]);
	XCTAssertNil(sidebar.selectedTableName);
	XCTAssertNil(self.document.contentController.table);
	XCTAssertNil(structure.table);

	// A draft that can't be saved (the name is taken): its error, no question, nothing dropped
	XCTAssertTrue([sidebar selectTableNamed:@"sp9_b"]);
	[self waitForTab];
	[self.document viewStructure:nil];
	[self waitForTab];
	XCTAssertEqualObjects(structure.table, @"sp9_b");
	[structure addColumn:nil];
	[self waitForTab];
	[[structure.columnsView currentEditor] setString:@"id"];
	[self.document sidebar:sidebar removeRelations:@[@"sp9_b"]];
	[self waitForTabAndQuestions];
	XCTAssertEqual(asked.count, 1u);
	XCTAssertEqual(alerts.count, 1u);
	XCTAssertTrue(structure.hasDraftColumn);
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM pg_class WHERE relname = 'sp9_b'" on:admin], @"1");
	XCTAssertTrue([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"sp9_b"]);
	XCTAssertEqualObjects(sidebar.selectedTableName, @"sp9_b");
}

/// Saving an edit before the question queues a list reload: the question waits until the tab is idle (so a quick
/// answer isn't refused as busy), and a second request meanwhile is ignored.
- (void)testConfirmationWaitsForIdleAfterCommit
{
	PGPostgresConnection *admin = [self sp9AdminRunning:@[@"CREATE TABLE public.sp9_a (id integer)", @"CREATE TABLE public.sp9_b (id integer)"]];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	SPPostgresStructureController *structure = self.document.structureController;
	NSMutableArray<NSAlert *> *asked = [NSMutableArray array];
	__block BOOL busyWhenAsked = YES;
	self.document.confirmationPresenter = ^(NSAlert *alert, void (^completion)(BOOL)) {
		[asked addObject:alert];
		busyWhenAsked = self.document.taskRunner.isBusy;
		completion(YES);
	};

	XCTAssertTrue([sidebar selectTableNamed:@"sp9_a"]);
	[self waitForTab];
	[self.document viewStructure:nil];
	[self waitForTab];
	[structure addColumn:nil];
	[self waitForTab];
	[[structure.columnsView currentEditor] setString:@"added_col"];

	[self.document sidebar:sidebar removeRelations:@[@"sp9_b"]];
	XCTAssertFalse(structure.hasDraftColumn);
	XCTAssertTrue(self.document.isProcessing, @"saving the column queued a list reload");
	XCTAssertEqual(asked.count, 0u, @"not asked while busy");
	[self.document sidebar:sidebar truncateTables:@[@"sp9_a"]];

	[self waitForTabAndQuestions];
	XCTAssertEqual(asked.count, 1u, @"asked once idle; the second request was ignored");
	XCTAssertFalse(busyWhenAsked);
	XCTAssertEqualObjects(asked[0].messageText, @"Delete table 'sp9_b'?");
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.messageText);
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM pg_class WHERE relname = 'sp9_b'" on:admin], @"0");
	XCTAssertFalse([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"sp9_b"]);
	XCTAssertEqualObjects(sidebar.selectedTableName, @"sp9_a");
}

/// A question that waits for the tab to be idle isn't asked over another tab brought to the front meanwhile: it is
/// asked when this tab is in front again. The same for one asked while another tab is in front.
- (void)testDeferredQuestionWaitsForItsTab
{
	PGPostgresConnection *admin = [self sp9AdminRunning:@[@"CREATE TABLE public.sp9_a (id integer)", @"CREATE TABLE public.sp9_b (id integer)"]];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	NSMutableArray<NSAlert *> *asked = [self answerConfirmationsWith:NO];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	SPPostgresStructureController *structure = self.document.structureController;

	// Saving a Structure draft queues a reload: the question waits; another tab comes to the front meanwhile
	XCTAssertTrue([sidebar selectTableNamed:@"sp9_a"]);
	[self waitForTab];
	[self.document viewStructure:nil];
	[self waitForTab];
	[structure addColumn:nil];
	[self waitForTab];
	[[structure.columnsView currentEditor] setString:@"added_col"];
	[self.document sidebar:sidebar removeRelations:@[@"sp9_b"]];
	XCTAssertTrue(self.document.isProcessing);
	[self.controller addNewConnection];
	XCTAssertNotEqual([self.controller selectedDocument], self.document);
	[self waitForTabAndQuestions];
	[self spinUntil:^BOOL{ return NO; } timeout:0.2];
	XCTAssertEqual(asked.count, 0u, @"not asked over another tab");

	[[self tabView] selectTabViewItem:self.document.parentTabViewItem];
	XCTAssertTrue([self spinUntil:^BOOL{ return asked.count == 1; } timeout:5]);
	XCTAssertEqualObjects(asked[0].messageText, @"Delete table 'sp9_b'?");

	// Asked (idle) while another tab is in front: asked once this tab is
	[self.controller addNewConnection];
	XCTAssertNotEqual([self.controller selectedDocument], self.document);
	[self.document sidebar:sidebar truncateTables:@[@"sp9_a"]];
	[self spinUntil:^BOOL{ return NO; } timeout:0.2];
	XCTAssertEqual(asked.count, 1u);
	[[self tabView] selectTabViewItem:self.document.parentTabViewItem];
	XCTAssertTrue([self spinUntil:^BOOL{ return asked.count == 2; } timeout:5]);
	XCTAssertEqualObjects(asked[1].messageText, @"Truncate table 'sp9_a'?");

	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM pg_class WHERE relname IN ('sp9_a', 'sp9_b')" on:admin], @"2");
}

#pragma mark - Add Table

/// An admin connection; the throwaway sp9_added table (and sp9_a, which some tests use) is dropped before and after the test.
- (PGPostgresConnection *)sp9AddAdmin
{
	PGPostgresConnection *admin = [SPPostgresTestServers connectedConnectionOnPort:SPPostgresDocumentTestPort];
	NSString *cleanup = @"DROP TABLE IF EXISTS public.sp9_added, public.sp9_a";
	XCTAssertNotNil([admin execute:cleanup]);
	[self addTeardownBlock:^{
		[admin execute:cleanup];
		[admin disconnect];
	}];
	return admin;
}

/// Clicks the table list bar's Add and returns the New Table sheet (once the tab is idle).
- (NSWindow *)openAddTableSheet
{
	NSButton *add = self.document.sidebar.addButton;
	XCTAssertTrue(add.isEnabled);
	[add performClick:nil];
	[self waitForTabAndQuestions];
	NSWindow *sheet = [self window].attachedSheet;
	XCTAssertNotNil(sheet);
	return sheet;
}

- (void)typeName:(NSString *)name inSheet:(NSWindow *)sheet
{
	NSTextField *field = [self viewWithIdentifier:@"addTableName" in:sheet.contentView];
	field.stringValue = name;
	[[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidChangeNotification object:field];
}

- (void)testAddTableCreatesSelectsAndShowsStructure
{
	PGPostgresConnection *admin = [self sp9AddAdmin];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self.controller showWindow:nil];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	XCTAssertTrue([sidebar selectTableNamed:@"customers"]);
	[self waitForTab];
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneContent);

	// MySQL's New Table sheet, with the name only
	NSWindow *sheet = [self openAddTableSheet];
	XCTAssertEqualObjects(sheet.title, @"New Table");
	NSTextField *field = [self viewWithIdentifier:@"addTableName" in:sheet.contentView];
	NSButton *add = [self viewWithIdentifier:@"addTableButton" in:sheet.contentView];
	XCTAssertEqualObjects(field.stringValue, @"");
	XCTAssertEqualObjects(add.title, @"Add");
	XCTAssertFalse(add.isEnabled);
	NSMutableArray *labels = [NSMutableArray array];
	for (NSView *view in sheet.contentView.subviews) {
		if ([view isKindOfClass:[NSTextField class]] && !((NSTextField *)view).isEditable) [labels addObject:((NSTextField *)view).stringValue];
	}
	XCTAssertEqualObjects(labels, @[@"Table Name:"]);

	[self typeName:@"sp9_added" inSheet:sheet];
	XCTAssertTrue(add.isEnabled);
	[add performClick:nil];
	[self waitForTab];
	XCTAssertTrue([self spinUntil:^BOOL{ return [sidebar.selectedTableName isEqualToString:@"sp9_added"]; } timeout:5], @"%@ %@", sidebar.selectedTableName, alerts.firstObject.informativeText);
	[self waitForTab];
	XCTAssertNil([self window].attachedSheet);

	// The table, with the spec's id column; listed, selected and shown in Structure
	XCTAssertEqualObjects([self value:@"SELECT string_agg(a.attname || ' ' || format_type(a.atttypid, a.atttypmod) || ' ' || a.attidentity::text || ' ' || a.attnotnull::text, ',') "
									  @"FROM pg_attribute a WHERE a.attrelid = 'public.sp9_added'::regclass AND a.attnum > 0 AND NOT a.attisdropped" on:admin], @"id integer d true");
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM pg_constraint WHERE conrelid = 'public.sp9_added'::regclass AND contype = 'p'" on:admin], @"1");
	XCTAssertTrue([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"sp9_added"]);
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneStructure);
	XCTAssertEqualObjects(self.document.structureController.table, @"sp9_added");
	XCTAssertTrue([[self.document windowTitleString] hasSuffix:@"/pgkit_test/public.sp9_added"]);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);

	// History: the new table is a place the user went to, as a selection then Structure (as MySQL's)
	XCTAssertEqualObjects(self.document.history.currentEntry[@"table"], @"sp9_added");
	XCTAssertEqualObjects(self.document.history.currentEntry[@"pane"], SPPostgresPaneStructure);
	[self.document backForwardInHistory:[self historyMenuItemWithTag:0]];
	[self waitForTab];
	XCTAssertEqualObjects(sidebar.selectedTableName, @"sp9_added");
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneContent);
	[self.document backForwardInHistory:[self historyMenuItemWithTag:0]];
	[self waitForTab];
	XCTAssertEqualObjects(sidebar.selectedTableName, @"customers");
}

- (void)testAddButtonDisabledForBlankName
{
	PGPostgresConnection *admin = [self sp9AddAdmin];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self.controller showWindow:nil];

	NSWindow *sheet = [self openAddTableSheet];
	NSButton *add = [self viewWithIdentifier:@"addTableButton" in:sheet.contentView];
	XCTAssertFalse(add.isEnabled);

	// Blank after trimming, or longer than PostgreSQL's 63 bytes: disabled
	[self typeName:@"   " inSheet:sheet];
	XCTAssertFalse(add.isEnabled);
	[self typeName:[@"" stringByPaddingToLength:64 withString:@"n" startingAtIndex:0] inSheet:sheet];
	XCTAssertFalse(add.isEnabled);
	[self typeName:@" sp9_added " inSheet:sheet];
	XCTAssertTrue(add.isEnabled);
	// Return: Add is the sheet's default button (AppKit keeps its Return key equivalent there)
	XCTAssertEqual(sheet.defaultButtonCell, add.cell);
	[self typeName:@"\t" inSheet:sheet];
	XCTAssertFalse(add.isEnabled);

	// Return (Add's action, sent anyway) does nothing while Add is disabled: the sheet stays
	[self.document closeAddTableSheet:add];
	[self waitForTab];
	XCTAssertEqual([self window].attachedSheet, sheet);

	// Cancel (Escape) ends the sheet, adding nothing
	NSButton *cancel = nil;
	for (NSView *view in sheet.contentView.subviews) {
		if ([view isKindOfClass:[NSButton class]] && [((NSButton *)view).title isEqualToString:@"Cancel"]) cancel = (NSButton *)view;
	}
	XCTAssertEqualObjects(cancel.keyEquivalent, @"\e");
	[self typeName:@"sp9_added" inSheet:sheet];
	[cancel performClick:nil];
	[self waitForTab];
	XCTAssertTrue([self spinUntil:^BOOL{ return [self window].attachedSheet == nil; } timeout:5]);
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM pg_class WHERE relname = 'sp9_added'" on:admin], @"0");
	XCTAssertEqual(alerts.count, 0u);

	// The next sheet starts empty
	sheet = [self openAddTableSheet];
	XCTAssertEqualObjects(((NSTextField *)[self viewWithIdentifier:@"addTableName" in:sheet.contentView]).stringValue, @"");
}

- (void)testAddExistingNameShowsError
{
	[self sp9AddAdmin];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self.controller showWindow:nil];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	XCTAssertTrue([sidebar selectTableNamed:@"customers"]);
	[self waitForTab];
	NSArray *tables = [sidebar itemTitlesInSection:@"TABLES"];
	NSDictionary *entry = self.document.history.currentEntry;

	NSWindow *sheet = [self openAddTableSheet];
	[self typeName:@"customers" inSheet:sheet];
	[[self viewWithIdentifier:@"addTableButton" in:sheet.contentView] performClick:nil];
	[self waitForTab];
	XCTAssertTrue([self spinUntil:^BOOL{ return alerts.count == 1; } timeout:5]);
	[self waitForTab];

	XCTAssertEqualObjects(alerts[0].messageText, @"Error adding new table");
	XCTAssertTrue([alerts[0].informativeText hasPrefix:@"An error occurred while trying to add the new table 'customers'.\n\nPostgreSQL said: "], @"%@", alerts[0].informativeText);
	XCTAssertTrue([alerts[0].informativeText containsString:@"already exists"], @"%@", alerts[0].informativeText);
	XCTAssertEqualObjects([alerts[0].buttons valueForKey:@"title"], @[@"OK"]);

	// Nothing changed: the sheet is gone, the lists, the selection, the pane and History are as they were
	XCTAssertNil([self window].attachedSheet);
	XCTAssertEqualObjects([sidebar itemTitlesInSection:@"TABLES"], tables);
	XCTAssertEqualObjects(sidebar.selectedTableName, @"customers");
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneContent);
	XCTAssertEqualObjects(self.document.history.currentEntry, entry);
	XCTAssertFalse(self.document.history.canGoForward);
}

/// The server's HINT isn't shown under the error (as for Truncate and Remove).
- (void)testAddTableErrorOmitsHint
{
	PGPostgresConnection *admin = [self sp9AddAdmin];
	XCTAssertNotNil([admin execute:@"DROP TYPE IF EXISTS public.sp9_added"]);
	XCTAssertNotNil([admin execute:@"CREATE TYPE public.sp9_added AS ENUM ('a')"]);
	[self addTeardownBlock:^{
		[admin execute:@"DROP TYPE IF EXISTS public.sp9_added"];
	}];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self.controller showWindow:nil];

	// The type's name is taken: the server says so, with a HINT
	NSWindow *sheet = [self openAddTableSheet];
	[self typeName:@"sp9_added" inSheet:sheet];
	[[self viewWithIdentifier:@"addTableButton" in:sheet.contentView] performClick:nil];
	[self waitForTab];
	XCTAssertTrue([self spinUntil:^BOOL{ return alerts.count == 1; } timeout:5]);
	[self waitForTab];

	XCTAssertEqualObjects(alerts[0].messageText, @"Error adding new table");
	NSString *text = alerts[0].informativeText;
	XCTAssertTrue([text hasPrefix:@"An error occurred while trying to add the new table 'sp9_added'.\n\nPostgreSQL said: "], @"%@", text);
	XCTAssertTrue([text containsString:@"already exists"], @"%@", text);
	XCTAssertFalse([text containsString:@"HINT:"], @"%@", text);
	XCTAssertFalse([text containsString:@"associated type"], @"%@", text);
}

/// The New Table sheet asked for while another tab is in front comes up when this tab is in front again.
- (void)testDeferredAddSheetWaitsForItsTab
{
	[self sp9AddAdmin];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self.controller showWindow:nil];
	[self.controller addNewConnection];
	XCTAssertNotEqual([self.controller selectedDocument], self.document);

	[[self sidebarDelegate] sidebarAddTable:self.document.sidebar];
	[self waitForTabAndQuestions];
	XCTAssertNil([self window].attachedSheet, @"not over another tab");

	[[self tabView] selectTabViewItem:self.document.parentTabViewItem];
	XCTAssertTrue([self spinUntil:^BOOL{ return [[self window].attachedSheet.title isEqualToString:@"New Table"]; } timeout:5]);
	[self.document closeAddTableSheet:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return [self window].attachedSheet == nil; } timeout:5]);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

/// A load started while the sheet is up: Add is disabled (and Return refused) until the tab is idle, the sheet keeps
/// the name, and Add then creates the table.
- (void)testAddRefusedWhileBusyKeepsSheet
{
	PGPostgresConnection *admin = [self sp9AddAdmin];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self.controller showWindow:nil];

	NSWindow *sheet = [self openAddTableSheet];
	NSButton *add = [self viewWithIdentifier:@"addTableButton" in:sheet.contentView];
	[self typeName:@"sp9_added" inSheet:sheet];
	XCTAssertTrue(add.isEnabled);

	[SPPostgresTestServers queueSleep:1 onRunner:self.document.taskRunner];
	XCTAssertTrue(self.document.isProcessing);
	XCTAssertFalse(add.isEnabled);
	[self.document closeAddTableSheet:add];
	XCTAssertEqual([self window].attachedSheet, sheet);
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM pg_class WHERE relname = 'sp9_added'" on:admin], @"0");

	[self waitForTab];
	XCTAssertTrue(add.isEnabled);
	XCTAssertEqualObjects(((NSTextField *)[self viewWithIdentifier:@"addTableName" in:sheet.contentView]).stringValue, @"sp9_added");
	[add performClick:nil];
	[self waitForTab];
	XCTAssertTrue([self spinUntil:^BOOL{ return [self.document.sidebar.selectedTableName isEqualToString:@"sp9_added"]; } timeout:5]);
	[self waitForTab];
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM pg_class WHERE relname = 'sp9_added'" on:admin], @"1");
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

/// Saving an edit before the sheet queues a list reload: the sheet comes up once the tab is idle.
- (void)testAddSheetWaitsForIdleAfterCommit
{
	PGPostgresConnection *admin = [self sp9AddAdmin];
	XCTAssertNotNil([admin execute:@"CREATE TABLE public.sp9_a (id integer)"]);
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self.controller showWindow:nil];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	SPPostgresStructureController *structure = self.document.structureController;
	[sidebar reloadKeepingSelection];
	[self waitForTab];

	XCTAssertTrue([sidebar selectTableNamed:@"sp9_a"]);
	[self waitForTab];
	[self.document viewStructure:nil];
	[self waitForTab];
	[structure addColumn:nil];
	[self waitForTab];
	[[structure.columnsView currentEditor] setString:@"added_col"];

	[sidebar.addButton performClick:nil];
	XCTAssertFalse(structure.hasDraftColumn);
	XCTAssertTrue(self.document.isProcessing, @"saving the column queued a list reload");
	XCTAssertNil([self window].attachedSheet, @"not shown while busy");

	[self waitForTabAndQuestions];
	NSWindow *sheet = [self window].attachedSheet;
	XCTAssertNotNil(sheet);
	XCTAssertEqualObjects(sheet.title, @"New Table");
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.messageText);
	XCTAssertEqualObjects([self value:@"SELECT count(*)::text FROM pg_attribute WHERE attrelid = 'public.sp9_a'::regclass AND attname = 'added_col'" on:admin], @"1");
}

#pragma mark - Create Syntax and the information pane from the table list

/// A private pasteboard as the tab's createSyntaxPasteboard (the user's clipboard is never touched), released after.
- (NSPasteboard *)privateCreateSyntaxPasteboard
{
	NSPasteboard *pasteboard = [NSPasteboard pasteboardWithName:[NSString stringWithFormat:@"SPPostgresStage9Tests-%@", [NSUUID UUID].UUIDString]];
	[pasteboard clearContents];
	self.document.createSyntaxPasteboard = pasteboard;
	[self addTeardownBlock:^{
		[pasteboard releaseGlobally];
	}];
	return pasteboard;
}

- (id<SPPostgresSidebarControllerDelegate>)sidebarDelegate
{
	return (id<SPPostgresSidebarControllerDelegate>)self.document;
}

- (void)testCopyCreateSyntaxPutsStatementOnPasteboard
{
	XCTAssertEqual(self.document.createSyntaxPasteboard, [NSPasteboard generalPasteboard], @"the general pasteboard by default (only read)");
	NSPasteboard *pasteboard = [self privateCreateSyntaxPasteboard];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	XCTAssertTrue([sidebar selectTableNamed:@"customers"]);
	[self waitForTab];

	[[self sidebarDelegate] sidebar:sidebar showCreateSyntaxForRelations:@[@"customers"] copy:YES];
	XCTAssertTrue(self.document.isProcessing, @"read in a task of the tab's runner");
	[self waitForTab];

	NSString *copied = [pasteboard stringForType:NSPasteboardTypeString];
	XCTAssertTrue([copied hasPrefix:@"CREATE TABLE \"public\".\"customers\""], @"%@", copied);
	XCTAssertFalse([copied containsString:@"-- Create syntax for"], @"one item: no header");
	XCTAssertNil([self window].attachedSheet);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

- (void)testShowCreateSyntaxSheetForTwo
{
	NSPasteboard *pasteboard = [self privateCreateSyntaxPasteboard];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self.controller showWindow:nil];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	XCTAssertTrue(([sidebar selectRelationsNamed:@[@"customers", @"v_customers"]]));
	[self waitForTab];

	[[self sidebarDelegate] sidebar:sidebar showCreateSyntaxForRelations:sidebar.selectedRelationNames copy:NO];
	[self waitForTab];
	XCTAssertTrue([self spinUntil:^BOOL{ return [self window].attachedSheet != nil; } timeout:5]);
	NSWindow *sheet = [self window].attachedSheet;
	XCTAssertEqualObjects(sheet.title, @"Create syntaxes for selected items");
	XCTAssertEqualObjects([(NSTextField *)[self viewWithIdentifier:@"createSyntaxLabel" in:sheet.contentView] stringValue], @"Create syntaxes for selected items");

	NSTextView *text = [self viewWithIdentifier:@"createSyntaxText" in:sheet.contentView];
	XCTAssertTrue([text isKindOfClass:[NSTextView class]]);
	XCTAssertFalse(text.isEditable);
	XCTAssertTrue(text.font.fixedPitch, @"%@", text.font);
	XCTAssertTrue([text.string hasPrefix:@"-- Create syntax for TABLE 'customers'\nCREATE TABLE \"public\".\"customers\""], @"%@", text.string);
	XCTAssertTrue([text.string containsString:@"\n-- Create syntax for VIEW 'v_customers'\nCREATE VIEW \"public\".\"v_customers\""], @"%@", text.string);
	XCTAssertNil([pasteboard stringForType:NSPasteboardTypeString], @"shown, not copied");

	// Copy, then Close
	[(NSButton *)[self viewWithIdentifier:@"createSyntaxCopyButton" in:sheet.contentView] performClick:nil];
	XCTAssertEqualObjects([pasteboard stringForType:NSPasteboardTypeString], text.string);
	[(NSButton *)[self viewWithIdentifier:@"createSyntaxCloseButton" in:sheet.contentView] performClick:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return [self window].attachedSheet == nil; } timeout:5]);

	// One view: MySQL's label, no header
	[[self sidebarDelegate] sidebar:sidebar showCreateSyntaxForRelations:@[@"v_customers"] copy:NO];
	[self waitForTab];
	XCTAssertTrue([self spinUntil:^BOOL{ return [self window].attachedSheet != nil; } timeout:5]);
	sheet = [self window].attachedSheet;
	XCTAssertEqualObjects(sheet.title, @"Create syntax for VIEW 'v_customers'");
	text = [self viewWithIdentifier:@"createSyntaxText" in:sheet.contentView];
	XCTAssertTrue([text.string hasPrefix:@"CREATE VIEW \"public\".\"v_customers\""], @"%@", text.string);
	[(NSButton *)[self viewWithIdentifier:@"createSyntaxCloseButton" in:sheet.contentView] performClick:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return [self window].attachedSheet == nil; } timeout:5]);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

/// A table dropped behind the tab's back: MySQL's error with the server's message, nothing copied.
- (void)testCreateSyntaxErrorShowsServerMessage
{
	PGPostgresConnection *admin = [self sp9AdminRunning:@[@"CREATE TABLE public.sp9_a (id integer)"]];
	NSPasteboard *pasteboard = [self privateCreateSyntaxPasteboard];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	XCTAssertTrue([[sidebar itemTitlesInSection:@"TABLES"] containsObject:@"sp9_a"]);
	XCTAssertNotNil([admin execute:@"DROP TABLE public.sp9_a"]);

	[[self sidebarDelegate] sidebar:sidebar showCreateSyntaxForRelations:@[@"customers", @"sp9_a"] copy:YES];
	[self waitForTab];
	XCTAssertTrue([self spinUntil:^BOOL{ return alerts.count == 1; } timeout:5]);
	XCTAssertEqualObjects(alerts[0].messageText, @"An error occured while creating table syntax.");
	XCTAssertGreaterThan(alerts[0].informativeText.length, 0u);
	XCTAssertFalse([alerts[0].informativeText containsString:@"HINT:"], @"%@", alerts[0].informativeText);
	XCTAssertNil([pasteboard stringForType:NSPasteboardTypeString]);
	XCTAssertNil([self window].attachedSheet);
}

/// A comment saved in Table Info is patched into the information pane under the table list: nothing is read.
- (void)testCommentSaveUpdatesInfoPaneWithoutRead
{
	[self sp9AdminRunning:@[@"CREATE TABLE public.sp9_a (id integer)"]];
	// Expanded whatever the real preferences hold (a scratch suite, only read)
	NSUserDefaults *scratch = [[NSUserDefaults alloc] initWithSuiteName:@"SPPostgresStage9Tests"];
	[self addTeardownBlock:^{
		[[NSUserDefaults standardUserDefaults] removePersistentDomainForName:@"SPPostgresStage9Tests"];
	}];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	sidebar.defaults = scratch;
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self.controller showWindow:nil];

	XCTAssertTrue([sidebar selectTableNamed:@"sp9_a"]);
	[self waitForTab];
	[self.document viewStatus:nil];
	[self waitForTab];
	NSArray *facts = sidebar.infoPane.lines;
	XCTAssertEqualObjects(facts[0], @"TABLE INFORMATION");
	XCTAssertFalse([[facts lastObject] hasPrefix:@"comment: "]);

	// From here the pane's reads would show on a runner of its own
	SPPostgresTaskRunner *probe = [[SPPostgresTaskRunner alloc] initWithConnection:[SPPostgresTestServers connectedConnectionOnPort:SPPostgresDocumentTestPort]];
	sidebar.infoPane.taskRunner = probe;
	[self addTeardownBlock:^{
		[probe invalidateWithCompletion:nil];
	}];

	SPPostgresTableInfoController *info = self.document.infoController;
	NSTextView *box = info.commentView;
	void (^save)(NSString *) = ^(NSString *text) {
		XCTAssertTrue([[box window] makeFirstResponder:box]);
		NSRange all = NSMakeRange(0, box.string.length);
		[box setSelectedRange:all];
		[box insertText:text replacementRange:all];
		XCTAssertTrue([info commitPendingEdits]);
	};

	// Added: the line appears, and neither runner is busy (no input blocker, the next change isn't refused)
	save(@"pane note");
	XCTAssertFalse(probe.isBusy);
	XCTAssertFalse(self.document.taskRunner.isBusy);
	XCTAssertFalse(self.document.isProcessing);
	XCTAssertEqualObjects([sidebar.infoPane.lines lastObject], @"comment: pane note");
	XCTAssertEqual(sidebar.infoPane.lines.count, facts.count + 1);

	// Changed, then removed
	save(@"other note");
	XCTAssertEqualObjects([sidebar.infoPane.lines lastObject], @"comment: other note");
	XCTAssertEqual(sidebar.infoPane.lines.count, facts.count + 1);
	save(@"");
	XCTAssertEqualObjects(sidebar.infoPane.lines, facts);
	XCTAssertFalse(probe.isBusy);
	XCTAssertFalse(self.document.isProcessing);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);

	// Another relation shown in the pane: left as it is
	[sidebar.infoPane setComment:@"stray" forRelation:@"customers" inSchema:@"public"];
	XCTAssertEqualObjects(sidebar.infoPane.lines, facts);
}

/// The read completed while another sheet was attached: the Create Syntax sheet comes up once that sheet ends.
- (void)testCreateSyntaxSheetWaitsForAttachedSheet
{
	[self privateCreateSyntaxPasteboard];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self.controller showWindow:nil];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	XCTAssertTrue([sidebar selectTableNamed:@"customers"]);
	[self waitForTab];

	[[self sidebarDelegate] sidebar:sidebar showCreateSyntaxForRelations:@[@"customers"] copy:NO];
	NSPanel *other = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 200, 100) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
	other.releasedWhenClosed = NO;
	[[self window] beginSheet:other completionHandler:nil];
	[self waitForTab];
	[self spinUntil:^BOOL{ return NO; } timeout:0.2];
	XCTAssertEqual([self window].attachedSheet, other, @"not shown over the other sheet");

	[[self window] endSheet:other];
	[other orderOut:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return [[self window].attachedSheet.title isEqualToString:@"Create syntax for TABLE 'customers'"]; } timeout:5]);
	NSWindow *sheet = [self window].attachedSheet;
	NSTextView *text = [self viewWithIdentifier:@"createSyntaxText" in:sheet.contentView];
	XCTAssertTrue([text.string hasPrefix:@"CREATE TABLE \"public\".\"customers\""], @"%@", text.string);
	[(NSButton *)[self viewWithIdentifier:@"createSyntaxCloseButton" in:sheet.contentView] performClick:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return [self window].attachedSheet == nil; } timeout:5]);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

/// Escape closes the Create Syntax sheet, as MySQL's hidden "Close via ESC" button does.
- (void)testEscapeClosesCreateSyntaxSheet
{
	[self privateCreateSyntaxPasteboard];
	[self.controller showWindow:nil];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	XCTAssertTrue([sidebar selectTableNamed:@"customers"]);
	[self waitForTab];

	[[self sidebarDelegate] sidebar:sidebar showCreateSyntaxForRelations:@[@"customers"] copy:NO];
	[self waitForTab];
	XCTAssertTrue([self spinUntil:^BOOL{ return [self window].attachedSheet != nil; } timeout:5]);
	NSWindow *sheet = [self window].attachedSheet;
	NSEvent *escape = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:sheet.windowNumber context:nil characters:@"\e" charactersIgnoringModifiers:@"\e" isARepeat:NO keyCode:53];
	XCTAssertTrue([sheet performKeyEquivalent:escape]);
	XCTAssertTrue([self spinUntil:^BOOL{ return [self window].attachedSheet == nil; } timeout:5]);
}

/// The read finished while another tab was in front: the sheet comes up when this tab is in front again.
- (void)testDeferredCreateSyntaxWaitsForItsTab
{
	[self privateCreateSyntaxPasteboard];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self.controller showWindow:nil];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	XCTAssertTrue([sidebar selectTableNamed:@"customers"]);
	[self waitForTab];

	// The result arrives on the main thread after the other tab is in front
	[[self sidebarDelegate] sidebar:sidebar showCreateSyntaxForRelations:@[@"customers"] copy:NO];
	[self.controller addNewConnection];
	XCTAssertNotEqual([self.controller selectedDocument], self.document);
	[self waitForTab];
	[self spinUntil:^BOOL{ return NO; } timeout:0.2];
	XCTAssertNil([self window].attachedSheet, @"not over another tab");

	[[self tabView] selectTabViewItem:self.document.parentTabViewItem];
	XCTAssertTrue([self spinUntil:^BOOL{ return [[self window].attachedSheet.title isEqualToString:@"Create syntax for TABLE 'customers'"]; } timeout:5]);
	NSWindow *sheet = [self window].attachedSheet;
	[(NSButton *)[self viewWithIdentifier:@"createSyntaxCloseButton" in:sheet.contentView] performClick:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return [self window].attachedSheet == nil; } timeout:5]);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

/// The shown pane's edit is saved before the statements are read (they include it); one that can't be saved reads
/// nothing.
- (void)testCreateSyntaxCommitsEditFirst
{
	[self sp9AdminRunning:@[@"CREATE TABLE public.sp9_a (id integer)"]];
	NSPasteboard *pasteboard = [self privateCreateSyntaxPasteboard];
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	SPPostgresStructureController *structure = self.document.structureController;

	XCTAssertTrue([sidebar selectTableNamed:@"sp9_a"]);
	[self waitForTab];
	[self.document viewStructure:nil];
	[self waitForTab];
	[structure addColumn:nil];
	[self waitForTab];
	[[structure.columnsView currentEditor] setString:@"added_col"];

	[[self sidebarDelegate] sidebar:sidebar showCreateSyntaxForRelations:@[@"sp9_a"] copy:YES];
	[self waitForTab];
	XCTAssertFalse(structure.hasDraftColumn);
	NSString *copied = [pasteboard stringForType:NSPasteboardTypeString];
	XCTAssertTrue([copied containsString:@"added_col"], @"%@", copied);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);

	// A draft that can't be saved (the name is taken): its error, nothing read or copied
	[pasteboard clearContents];
	[structure addColumn:nil];
	[self waitForTab];
	[[structure.columnsView currentEditor] setString:@"id"];
	[[self sidebarDelegate] sidebar:sidebar showCreateSyntaxForRelations:@[@"sp9_a"] copy:YES];
	XCTAssertFalse(self.document.isProcessing, @"nothing queued");
	[self waitForTab];
	XCTAssertTrue(structure.hasDraftColumn);
	XCTAssertNil([pasteboard stringForType:NSPasteboardTypeString]);
	XCTAssertEqual(alerts.count, 1u);
}

#pragma mark - Open Table in New Tab / Window

/// "Sales Data"."Orders 2026" selected in the tab.
- (void)selectOrders2026
{
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	[sidebar reloadSchema:@"Sales Data"];
	[self waitForTab];
	XCTAssertTrue([sidebar selectTableNamed:@"Orders 2026"]);
	[self waitForTab];
}

/// The tab view items' documents, in tab order.
- (NSArray *)tabDocumentsIn:(SPWindowController *)controller
{
	NSMutableArray *documents = [NSMutableArray array];
	for (NSTabViewItem *item in [[controller valueForKey:@"tabView"] tabViewItems]) [documents addObject:item.identifier];
	return documents;
}

/// Waits until `document` has selected `table` of `schema` once its first loads and the selection's loads are done.
- (void)waitForDocument:(SPPostgresDocument *)document toSelect:(NSString *)table inSchema:(NSString *)schema
{
	XCTAssertTrue([self spinUntil:^BOOL{
		return [document.sidebar.selectedSchema isEqualToString:schema] && [document.sidebar.selectedTableName isEqualToString:table];
	} timeout:30], @"%@ %@", document.sidebar.selectedSchema, document.sidebar.selectedTableName);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
}

- (void)testOpenInNewTabSelectsSameTable
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	// Another tab after the source: the new one goes between them
	PGPostgresConnection *otherConnection = nil;
	SPPostgresConnector *otherConnector = [self connectorForFavorite:self.favorite sshPassword:nil connection:&otherConnection];
	SPPostgresDocument *other = [[SPPostgresDocument alloc] initWithConnection:otherConnection connector:otherConnector favorite:self.favorite];
	[self.controller addTabDocument:other atIndex:1 select:NO];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:other.taskRunner timeout:30]);
	[self selectOrders2026];

	[self.document openRelation:@"Orders 2026" inSchema:@"Sales Data" inNewWindow:NO];
	XCTAssertTrue(self.document.isProcessing, @"the source tab shows it is connecting");
	XCTAssertTrue([self spinUntil:^BOOL{ return [self tabView].numberOfTabViewItems == 3; } timeout:20]);
	XCTAssertFalse(self.document.isProcessing);

	NSArray *documents = [self tabDocumentsIn:self.controller];
	XCTAssertEqual(documents[0], self.document);
	XCTAssertEqual(documents[2], other);
	SPPostgresDocument *opened = documents[1];
	XCTAssertTrue([opened isKindOfClass:[SPPostgresDocument class]]);
	XCTAssertEqual([self.controller selectedDocument], opened, @"the new tab is selected");
	[self waitForDocument:opened toSelect:@"Orders 2026" inSchema:@"Sales Data"];

	XCTAssertEqualObjects(opened.favorite.name, self.favorite.name);
	XCTAssertEqualObjects(opened.currentDatabase, self.document.currentDatabase);
	XCTAssertEqualObjects(opened.sidebar.selectedSchema, @"Sales Data");
	XCTAssertEqualObjects(opened.sidebar.selectedTableName, @"Orders 2026");
	XCTAssertNotNil(opened.connection);
	XCTAssertNotEqual(opened.connection, self.document.connection, @"a session of its own");
	XCTAssertTrue(opened.connection.isConnected);
	XCTAssertTrue([[opened windowTitleString] hasSuffix:@"/pgkit_test/Sales Data.Orders 2026"], @"%@", [opened windowTitleString]);
	// The source tab is as it was
	XCTAssertEqualObjects(self.document.sidebar.selectedTableName, @"Orders 2026");
	XCTAssertTrue(self.connection.isConnected);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

/// A view opens as a table does (from the sidebar's delegate method, in the schema shown).
- (void)testOpenViewInNewTabFromSidebar
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	SPPostgresSidebarController *sidebar = self.document.sidebar;
	XCTAssertTrue([sidebar selectTableNamed:@"v_customers"]);
	[self waitForTab];

	[[self sidebarDelegate] sidebar:sidebar openRelation:@"v_customers" inNewWindow:NO];
	XCTAssertTrue([self spinUntil:^BOOL{ return [self tabView].numberOfTabViewItems == 2; } timeout:20]);
	SPPostgresDocument *opened = [self tabDocumentsIn:self.controller][1];
	[self waitForDocument:opened toSelect:@"v_customers" inSchema:@"public"];
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

- (void)testOpenInNewWindowOpensWindow
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self selectOrders2026];
	NSArray *windowsBefore = [NSApp windows];

	[self.document openRelation:@"Orders 2026" inSchema:@"Sales Data" inNewWindow:YES];
	XCTAssertTrue(self.document.isProcessing);
	__block NSWindow *newWindow = nil;
	XCTAssertTrue([self spinUntil:^BOOL{
		for (NSWindow *window in [NSApp windows]) {
			if (![windowsBefore containsObject:window] && [window.windowController isKindOfClass:[SPWindowController class]]) newWindow = window;
		}
		return newWindow != nil;
	} timeout:20]);
	XCTAssertFalse(self.document.isProcessing);

	SPWindowController *newController = newWindow.windowController;
	XCTAssertNotEqual(newController, self.controller);
	XCTAssertTrue(newWindow.isVisible);
	XCTAssertEqual([self tabView].numberOfTabViewItems, 1, @"no tab added to the source window");
	NSArray *documents = [self tabDocumentsIn:newController];
	XCTAssertEqual(documents.count, 1u);
	SPPostgresDocument *opened = (SPPostgresDocument *)[newController selectedDocument];
	XCTAssertEqual(opened, documents.firstObject);
	XCTAssertEqual(opened.parentWindowController, newController);
	[self waitForDocument:opened toSelect:@"Orders 2026" inSchema:@"Sales Data"];
	XCTAssertEqualObjects(opened.favorite.name, self.favorite.name);
	XCTAssertEqualObjects(opened.currentDatabase, self.document.currentDatabase);
	XCTAssertNotEqual(opened.connection, self.document.connection);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);

	[newWindow close];
	XCTAssertTrue([self spinUntil:^BOOL{ return ![[NSApp windows] containsObject:newWindow] || !newWindow.isVisible; } timeout:5]);
}

- (void)testOpenFailureOpensNothing
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self selectOrders2026];
	NSArray *windowsBefore = [NSApp windows];
	__block NSUInteger made = 0;
	self.document.openRelationConnectorFactory = ^SPPostgresConnector *(SPPostgresFavorite *favorite, NSString *password, NSString *sshPassword, NSWindow *parentWindow) {
		made++;
		XCTAssertEqualObjects(password, @"pgkit", @"the tab's password");
		XCTAssertEqualObjects(favorite.database, @"pgkit_test");
		SPPostgresFavorite *broken = [favorite copy];
		broken.port = 1; // nothing listens there
		return [[SPPostgresConnector alloc] initWithFavorite:broken password:password sshPassword:sshPassword parentWindow:parentWindow];
	};

	[self.document openRelation:@"Orders 2026" inSchema:@"Sales Data" inNewWindow:NO];
	XCTAssertTrue(self.document.isProcessing);
	XCTAssertTrue([self spinUntil:^BOOL{ return alerts.count > 0; } timeout:20]);
	[self spinUntil:^BOOL{ return NO; } timeout:0.3];
	XCTAssertEqual(made, 1u);
	XCTAssertEqual(alerts.count, 1u);
	XCTAssertTrue([alerts.firstObject.messageText containsString:@"Orders 2026"], @"%@", alerts.firstObject.messageText);
	XCTAssertGreaterThan(alerts.firstObject.informativeText.length, 0u);
	XCTAssertFalse(self.document.isProcessing);
	XCTAssertEqual([self tabView].numberOfTabViewItems, 1, @"no tab opened");
	XCTAssertEqual([self.controller selectedDocument], self.document);

	// Nor a window
	[self.document openRelation:@"Orders 2026" inSchema:@"Sales Data" inNewWindow:YES];
	XCTAssertTrue([self spinUntil:^BOOL{ return alerts.count > 1; } timeout:20]);
	[self spinUntil:^BOOL{ return NO; } timeout:0.3];
	XCTAssertEqual(alerts.count, 2u);
	for (NSWindow *window in [NSApp windows]) {
		XCTAssertFalse(![windowsBefore containsObject:window] && [window.windowController isKindOfClass:[SPWindowController class]], @"no window opened");
	}
	XCTAssertTrue(self.connection.isConnected);
	XCTAssertEqualObjects(self.document.sidebar.selectedTableName, @"Orders 2026");
}

/// Closing the tab while the new session connects cancels it: nothing is opened.
- (void)testCloseTabWhileOpeningOpensNothing
{
	[self selectOrders2026];
	NSArray *windowsBefore = [NSApp windows];
	[self.document openRelation:@"Orders 2026" inSchema:@"Sales Data" inNewWindow:NO];
	XCTAssertTrue(self.document.isProcessing);
	// Refused while the first one connects: the pending connector stays the first one's
	id pending = [self.document valueForKey:@"pendingOpenConnector"];
	XCTAssertNotNil(pending);
	[self.document openRelation:@"Orders 2026" inSchema:@"Sales Data" inNewWindow:YES];
	XCTAssertEqual([self.document valueForKey:@"pendingOpenConnector"], pending);

	[[self tabView] removeTabViewItem:self.document.parentTabViewItem];
	XCTAssertFalse(self.document.isProcessing);
	[self spinUntil:^BOOL{ return NO; } timeout:1.5];
	XCTAssertEqual([self tabView].numberOfTabViewItems, 0);
	for (NSWindow *window in [NSApp windows]) {
		XCTAssertFalse(![windowsBefore containsObject:window] && [window.windowController isKindOfClass:[SPWindowController class]], @"no window opened");
	}
}

/// The new tab shows the pane shown in the source tab, shown before the table is selected (so History has no entry of
/// the table in Content: it was never shown there).
- (void)testOpenInNewTabKeepsPane
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self selectOrders2026];
	[self.document showPane:SPPostgresPaneStructure];
	[self waitForTab];
	XCTAssertEqualObjects(self.document.currentPane, SPPostgresPaneStructure);

	[self.document openRelation:@"Orders 2026" inSchema:@"Sales Data" inNewWindow:NO];
	XCTAssertTrue([self spinUntil:^BOOL{ return [self tabView].numberOfTabViewItems == 2; } timeout:20]);
	SPPostgresDocument *opened = [self tabDocumentsIn:self.controller][1];
	[self waitForDocument:opened toSelect:@"Orders 2026" inSchema:@"Sales Data"];

	XCTAssertEqualObjects(opened.currentPane, SPPostgresPaneStructure);
	XCTAssertEqualObjects(opened.structureController.table, @"Orders 2026");
	XCTAssertEqualObjects(opened.structureController.schema, @"Sales Data");
	XCTAssertNil([[opened.contentController view] superview], @"Content isn't shown");
	XCTAssertEqualObjects(opened.history.currentEntry[@"pane"], SPPostgresPaneStructure);
	XCTAssertEqualObjects(opened.history.currentEntry[@"table"], @"Orders 2026");
	// Before it: where the tab started (no table), not the table in Content, nor Structure with no table
	NSDictionary *previous = [opened.history goBack];
	XCTAssertNil(previous[@"table"], @"%@", previous);
	XCTAssertEqualObjects(previous[@"pane"], SPPostgresPaneContent);
	XCTAssertFalse(opened.history.canGoBack);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

/// From the Query view: the new tab shows Query with the editor's text (the table selected behind it).
- (void)testOpenInNewTabCopiesQueryText
{
	NSMutableArray<NSAlert *> *alerts = [self captureAlerts];
	[self selectOrders2026];
	[self.document showPane:SPPostgresPaneQuery];
	[self.document.queryController.editor setString:@"SELECT * FROM \"Sales Data\".\"Orders 2026\";"];

	[self.document openRelation:@"Orders 2026" inSchema:@"Sales Data" inNewWindow:NO];
	// Asked for: a later edit here isn't carried over
	[self.document.queryController.editor setString:@"SELECT 2;"];
	XCTAssertTrue([self spinUntil:^BOOL{ return [self tabView].numberOfTabViewItems == 2; } timeout:20]);
	SPPostgresDocument *opened = [self tabDocumentsIn:self.controller][1];
	[self waitForDocument:opened toSelect:@"Orders 2026" inSchema:@"Sales Data"];

	XCTAssertEqualObjects(opened.currentPane, SPPostgresPaneQuery);
	XCTAssertEqualObjects(opened.queryController.editor.string, @"SELECT * FROM \"Sales Data\".\"Orders 2026\";");
	XCTAssertNotEqual(opened.queryController.editor, self.document.queryController.editor);
	XCTAssertEqual(alerts.count, 0u, @"%@", alerts.firstObject.informativeText);
}

@end
