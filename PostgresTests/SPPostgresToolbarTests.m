#import <XCTest/XCTest.h>
#import <PostgresKit/PostgresKit.h>
#import "SPPostgresTestServers.h"
#import "SPTestPrefsGuard.h"
#import "../Source/SPWindowController.h"
#import "../Source/SPToolbarTransferItem.h"
#import "../Source/Postgres/SPPostgresDocument.h"
#import "../Source/Postgres/SPPostgresConnector.h"
#import "../Source/Postgres/SPPostgresFavorite.h"

static const NSUInteger SPPostgresToolbarTestPort = 55418;

// The app's constants aren't exported to the test bundle: their values, spelled out
static NSString * const SPTestToolbarIdentifier = @"TableWindowToolbar";
static NSString * const SPTestTransfer = @"TransferToolbarItemIdentifier";
static NSString * const SPTestDatabase = @"DatabaseSelectToolbarItemIdentifier";
static NSString * const SPTestHistory = @"HistoryNavigationToolbarItemIdentifier";
static NSString * const SPTestShowConsole = @"ShowConsoleIdentifier";
static NSString * const SPTestClearConsole = @"ClearConsoleIdentifier";
static NSString * const SPTestStructure = @"SwitchToTableStructureToolbarItemIdentifier";
static NSString * const SPTestContent = @"SwitchToTableContentToolbarItemIdentifier";
static NSString * const SPTestQuery = @"SwitchToRunQueryToolbarItemIdentifier";
static NSString * const SPTestTableInfo = @"SwitchToTableInfoToolbarItemIdentifier";
static NSString * const SPTestRelations = @"SwitchToTableRelationsToolbarItemIdentifier";
static NSString * const SPTestTriggers = @"SwitchToTableTriggersToolbarItemIdentifier";
static NSString * const SPTestUsers = @"SwitchToUserManagerToolbarItemIdentifier";

#pragma mark - Test helpers

/// In-memory defaults: reads and writes never reach a preferences domain.
@interface SPToolbarTestsDefaults : NSUserDefaults
@property (strong) NSMutableDictionary *values;
@end

@implementation SPToolbarTestsDefaults

- (instancetype)init
{
	if ((self = [super init])) _values = [NSMutableDictionary dictionary];
	return self;
}

- (id)objectForKey:(NSString *)key { return self.values[key]; }
- (void)setObject:(id)value forKey:(NSString *)key { if (value) self.values[key] = value; else [self.values removeObjectForKey:key]; }
- (void)removeObjectForKey:(NSString *)key { [self.values removeObjectForKey:key]; }
- (BOOL)boolForKey:(NSString *)key { return [self.values[key] boolValue]; }
- (void)setBool:(BOOL)value forKey:(NSString *)key { self.values[key] = @(value); }

@end

/// A toolbar delegate with a fixed layout (standing in for a saved layout) that serves every identifier.
@interface SPToolbarTestsDelegate : NSObject <NSToolbarDelegate>
@property (copy) NSArray *layout;
@end

@implementation SPToolbarTestsDelegate

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar { return self.layout; }
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar { return [self.layout arrayByAddingObject:SPTestTransfer]; }

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)flag
{
	NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
	[item setLabel:identifier];
	return item;
}

@end

// Not in the public headers
@interface NSObject (SPPostgresToolbarTestsMySQL)
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar;
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar;
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)flag;
- (BOOL)validateToolbarItem:(NSToolbarItem *)item;
- (id)tablesListInstance;
@end

#pragma mark - Tests

@interface SPPostgresToolbarTests : XCTestCase
@property (strong) SPWindowController *controller;
@property (strong) SPPostgresDocument *postgres;
@property (strong) NSMutableArray<NSWindow *> *toolbarWindows;
@end

@implementation SPPostgresToolbarTests

+ (void)setUp
{
	[super setUp];
	[SPPostgresTestServers loadFixtureNamed:@"catalog" onPort:SPPostgresToolbarTestPort];
}

- (void)setUp
{
	self.continueAfterFailure = NO;

	// The test-run-wide guard (SPTestPrefsGuard.m) is in place: nothing in these tests may write the real preferences
	XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] volatileDomainForName:NSArgumentDomain][SPTestTransferAddedKey], @YES);
	XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] volatileDomainForName:NSArgumentDomain][SPTestTransferMovedKey], @YES);
	// MySQL tabs preselect no saved favorite, so they never read a password from the keychain
	XCTAssertFalse([[NSUserDefaults standardUserDefaults] boolForKey:SPTestSelectLastFavoriteUsedKey]);
	XCTAssertEqual([[NSUserDefaults standardUserDefaults] integerForKey:SPTestDefaultFavoriteKey], 0);
	XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] volatileDomainForName:NSArgumentDomain][SPTestSelectLastFavoriteUsedKey], @NO);
	XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] volatileDomainForName:NSArgumentDomain][SPTestDefaultFavoriteKey], @0);
	NSToolbar *probe = [[NSToolbar alloc] initWithIdentifier:@"SPPrefsGuardProbe"];
	[probe setAutosavesConfiguration:YES];
	XCTAssertFalse([probe autosavesConfiguration], @"toolbars never autosave in tests");
	XCTAssertTrue([probe sp_requestedAutosave]);

	// As -[SPAppController newWindow] does. The window's delegate is deliberately not set: its
	// -windowWillClose: autoreleases the controller, which this (ARC) test owns.
	self.controller = [[SPWindowController alloc] initWithWindowNibName:@"MainWindow"];
	XCTAssertNotNil([self.controller window]);

	self.toolbarWindows = [NSMutableArray array];
}

- (void)tearDown
{
	NSTabView *tabView = [self tabView];

	// A MySQL tab's filter editor resizes itself 0.2 s after it is built (SPRuleFilterController -_resize);
	// let that run while the MySQL document is still alive.
	if ([tabView numberOfTabViewItems]) [self spinFor:0.4];

	for (NSTabViewItem *item in [tabView tabViewItems]) {
		[tabView removeTabViewItem:item];
	}
	[[self.controller window] orderOut:nil];
	for (NSWindow *window in self.toolbarWindows) {
		[window setToolbar:nil];
		[window close];
	}
	self.toolbarWindows = nil;
	self.postgres = nil;
	self.controller = nil;
	[super tearDown];
}

- (NSTabView *)tabView
{
	return [self.controller valueForKey:@"tabView"];
}

- (void)spinFor:(NSTimeInterval)seconds
{
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

/// A connected Postgres tab, added at `index` and selected.
- (SPPostgresDocument *)addPostgresTabAtIndex:(NSUInteger)index
{
	SPPostgresFavorite *favorite = [[SPPostgresFavorite alloc] init];
	favorite.name = @"pg18 toolbar";
	favorite.type = SPPostgresTCPIPConnection;
	favorite.host = @"127.0.0.1";
	favorite.port = SPPostgresToolbarTestPort;
	favorite.user = @"pgkit_test";
	favorite.database = @"pgkit_test";

	SPPostgresConnector *connector = [[SPPostgresConnector alloc] initWithFavorite:favorite password:@"pgkit" sshPassword:nil parentWindow:nil];
	__block PGPostgresConnection *connection = nil;
	__block NSError *error = nil;
	__block BOOL done = NO;
	[connector connectWithCompletion:^(PGPostgresConnection *theConnection, NSError *theError) {
		connection = theConnection;
		error = theError;
		done = YES;
	}];
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:20];
	while (!done && [deadline timeIntervalSinceNow] > 0) [self spinFor:0.05];
	XCTAssertNotNil(connection, @"%@", error);

	self.postgres = [[SPPostgresDocument alloc] initWithConnection:connection connector:connector favorite:favorite];
	[self.controller addTabDocument:self.postgres atIndex:index select:YES];
	XCTAssertEqual([self.controller selectedDocument], self.postgres);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.postgres.taskRunner timeout:30]);
	return self.postgres;
}

- (NSToolbarItem *)itemWithIdentifier:(NSString *)identifier inToolbar:(NSToolbar *)toolbar
{
	for (NSToolbarItem *item in [toolbar items]) {
		if ([[item itemIdentifier] isEqualToString:identifier]) return item;
	}
	return nil;
}

/// MySQL's validation with the document stubbed as connected, with a table selected.
- (BOOL)validate:(NSToolbarItem *)item asConnectedMySQLDocument:(id)mysql
{
	id tablesList = [mysql tablesListInstance];
	XCTAssertNotNil(tablesList);
	[mysql setValue:@YES forKey:@"_isConnected"];
	[tablesList setValue:@0 forKey:@"selectedTableType"]; // SPTableTypeTable
	BOOL valid = [mysql validateToolbarItem:item];
	[tablesList setValue:@(-1) forKey:@"selectedTableType"]; // SPTableTypeNone
	[mysql setValue:@NO forKey:@"_isConnected"];
	return valid;
}

#pragma mark MySQL

- (void)testMySQLDefaultItemsGainOnlyTransfer
{
	id mysql = [self.controller addNewConnection];
	NSToolbar *toolbar = [[self.controller window] toolbar];

	// -toolbarDefaultItemIdentifiers: at base commit 72190e4
	NSArray *before = @[SPTestDatabase, SPTestStructure, SPTestContent, SPTestRelations, SPTestTriggers,
						SPTestTableInfo, SPTestQuery, NSToolbarFlexibleSpaceItemIdentifier, SPTestHistory,
						SPTestUsers, SPTestShowConsole];
	NSMutableArray *expected = [before mutableCopy];
	[expected insertObject:SPTestTransfer atIndex:[before indexOfObject:SPTestQuery] + 1];
	XCTAssertEqualObjects([mysql toolbarDefaultItemIdentifiers:toolbar], expected);

	// -toolbarAllowedItemIdentifiers: at base commit 72190e4, plus Transfer
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	NSArray *allowedBefore = @[SPTestDatabase, SPTestHistory, SPTestShowConsole, SPTestClearConsole, SPTestStructure,
							   SPTestContent, SPTestQuery, SPTestTableInfo, SPTestRelations, SPTestTriggers, SPTestUsers,
							   NSToolbarCustomizeToolbarItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
							   NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier];
#pragma clang diagnostic pop
	XCTAssertEqualObjects([NSSet setWithArray:[mysql toolbarAllowedItemIdentifiers:toolbar]], [NSSet setWithArray:[allowedBefore arrayByAddingObject:SPTestTransfer]]);
	XCTAssertEqual([[mysql toolbarAllowedItemIdentifiers:toolbar] count], [allowedBefore count] + 1);

	// The rest of the toolbar is as before
	XCTAssertEqualObjects([toolbar identifier], SPTestToolbarIdentifier);
	XCTAssertTrue([toolbar allowsUserCustomization]);
	XCTAssertTrue([toolbar sp_requestedAutosave]);
	XCTAssertEqualObjects([[toolbar items] valueForKey:@"itemIdentifier"], expected, @"no saved layout in tests: the defaults");
}

/// MySQL → MySQL Transfer: the document's -showTransfer:, enabled only when connected to a database (with one, on a
/// live server: SPMySQLTransferControllerTests).
- (void)testMySQLToolbarTransferNeedsADatabase
{
	id mysql = [self.controller addNewConnection];
	NSToolbar *toolbar = [[self.controller window] toolbar];

	NSToolbarItem *created = [mysql toolbar:toolbar itemForItemIdentifier:SPTestTransfer willBeInsertedIntoToolbar:NO];
	XCTAssertNotNil(created);
	XCTAssertEqualObjects([created label], @"Transfer");
	XCTAssertNotNil([created image]);
	XCTAssertEqual([created target], mysql);
	XCTAssertEqualObjects(NSStringFromSelector([created action]), @"showTransfer:");

	// Not connected: NO; connected (stubbed) but no database selected: NO
	XCTAssertFalse([mysql validateToolbarItem:created]);
	XCTAssertFalse([self validate:created asConnectedMySQLDocument:mysql]);
	XCTAssertTrue([self validate:[self itemWithIdentifier:SPTestContent inToolbar:toolbar] asConnectedMySQLDocument:mysql]);
}

#pragma mark One-time insertion into a saved layout

/**
 * A toolbar that never autosaves, with a unique identifier (so it doesn't sync with any other
 * toolbar), in a window that is never shown: a toolbar loads its items once it is in a window.
 */
- (NSToolbar *)toolbarWithLayout:(NSArray *)layout delegate:(SPToolbarTestsDelegate * __autoreleasing *)outDelegate
{
	SPToolbarTestsDelegate *delegate = [[SPToolbarTestsDelegate alloc] init];
	delegate.layout = layout;
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:[@"SPToolbarTests-" stringByAppendingString:[[NSUUID UUID] UUIDString]]];
	[toolbar setAutosavesConfiguration:NO];
	[toolbar setDelegate:delegate];

	// Before it is in a window it has no items, and the insertion neither inserts nor records anything
	SPToolbarTestsDefaults *untouched = [[SPToolbarTestsDefaults alloc] init];
	XCTAssertFalse(SPInsertTransferToolbarItemIfNeeded(toolbar, untouched));
	XCTAssertEqual([untouched.values count], 0u);

	NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 900, 200) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
	[window setReleasedWhenClosed:NO];
	[window setToolbar:toolbar];
	[self.toolbarWindows addObject:window];

	*outDelegate = delegate;
	return toolbar;
}

- (void)testTransferInsertedOnceIntoSavedLayout
{
	SPToolbarTestsDelegate *delegate = nil;
	NSArray *saved = @[SPTestDatabase, SPTestStructure, NSToolbarFlexibleSpaceItemIdentifier, SPTestHistory, SPTestUsers, SPTestShowConsole];
	NSToolbar *toolbar = [self toolbarWithLayout:saved delegate:&delegate];
	SPToolbarTestsDefaults *defaults = [[SPToolbarTestsDefaults alloc] init];

	// No Query: inserted right after Users, and recorded
	XCTAssertTrue(SPInsertTransferToolbarItemIfNeeded(toolbar, defaults));
	NSArray *expected = @[SPTestDatabase, SPTestStructure, NSToolbarFlexibleSpaceItemIdentifier, SPTestHistory, SPTestUsers, SPTestTransfer, SPTestShowConsole];
	XCTAssertEqualObjects([[toolbar items] valueForKey:@"itemIdentifier"], expected);
	XCTAssertEqualObjects(defaults.values[SPTestTransferAddedKey], @YES);

	// Not again
	XCTAssertFalse(SPInsertTransferToolbarItemIfNeeded(toolbar, defaults));
	XCTAssertEqualObjects([[toolbar items] valueForKey:@"itemIdentifier"], expected);

	// Removed by the user (Customize Toolbar): not re-added
	[toolbar removeItemAtIndex:(NSInteger)[expected indexOfObject:SPTestTransfer]];
	XCTAssertFalse(SPInsertTransferToolbarItemIfNeeded(toolbar, defaults));
	XCTAssertFalse([[[toolbar items] valueForKey:@"itemIdentifier"] containsObject:SPTestTransfer]);

	// A later window with the recorded key: not inserted either
	SPToolbarTestsDelegate *laterDelegate = nil;
	NSToolbar *later = [self toolbarWithLayout:saved delegate:&laterDelegate];
	XCTAssertFalse(SPInsertTransferToolbarItemIfNeeded(later, defaults));
	XCTAssertEqualObjects([[later items] valueForKey:@"itemIdentifier"], saved);
}

- (void)testTransferInsertedAfterQuery
{
	SPToolbarTestsDelegate *delegate = nil;
	NSArray *saved = @[SPTestDatabase, SPTestStructure, SPTestQuery, NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, SPTestHistory, SPTestUsers, SPTestShowConsole];
	NSToolbar *toolbar = [self toolbarWithLayout:saved delegate:&delegate];
	SPToolbarTestsDefaults *defaults = [[SPToolbarTestsDefaults alloc] init];

	XCTAssertTrue(SPInsertTransferToolbarItemIfNeeded(toolbar, defaults));
	NSArray *expected = @[SPTestDatabase, SPTestStructure, SPTestQuery, SPTestTransfer, NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, SPTestHistory, SPTestUsers, SPTestShowConsole];
	XCTAssertEqualObjects([[toolbar items] valueForKey:@"itemIdentifier"], expected);

	// Then the move has nothing to do (only records)
	XCTAssertFalse(SPMoveTransferToolbarItemAfterQueryIfNeeded(toolbar, defaults));
	XCTAssertEqualObjects([[toolbar items] valueForKey:@"itemIdentifier"], expected);
	XCTAssertEqualObjects(defaults.values[SPTestTransferMovedKey], @YES);
}

- (void)testTransferInsertedBeforeConsoleWithoutQueryOrUsers
{
	SPToolbarTestsDelegate *delegate = nil;
	NSArray *saved = @[SPTestDatabase, SPTestStructure, NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, SPTestHistory, SPTestShowConsole];
	NSToolbar *toolbar = [self toolbarWithLayout:saved delegate:&delegate];
	SPToolbarTestsDefaults *defaults = [[SPToolbarTestsDefaults alloc] init];

	XCTAssertTrue(SPInsertTransferToolbarItemIfNeeded(toolbar, defaults));
	NSArray *expected = @[SPTestDatabase, SPTestStructure, NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, SPTestHistory, SPTestTransfer, SPTestShowConsole];
	XCTAssertEqualObjects([[toolbar items] valueForKey:@"itemIdentifier"], expected);

	// Neither Users nor Console: at the end
	SPToolbarTestsDelegate *otherDelegate = nil;
	NSToolbar *other = [self toolbarWithLayout:@[SPTestDatabase, SPTestHistory] delegate:&otherDelegate];
	XCTAssertTrue(SPInsertTransferToolbarItemIfNeeded(other, [[SPToolbarTestsDefaults alloc] init]));
	XCTAssertEqualObjects([[other items] valueForKey:@"itemIdentifier"], (@[SPTestDatabase, SPTestHistory, SPTestTransfer]));
}

- (void)testLayoutWithTransferIsOnlyRecorded
{
	SPToolbarTestsDelegate *delegate = nil;
	NSArray *saved = @[SPTestDatabase, SPTestUsers, SPTestTransfer, SPTestShowConsole];
	NSToolbar *toolbar = [self toolbarWithLayout:saved delegate:&delegate];
	SPToolbarTestsDefaults *defaults = [[SPToolbarTestsDefaults alloc] init];

	XCTAssertFalse(SPInsertTransferToolbarItemIfNeeded(toolbar, defaults));
	XCTAssertEqualObjects([[toolbar items] valueForKey:@"itemIdentifier"], saved);
	XCTAssertEqualObjects(defaults.values[SPTestTransferAddedKey], @YES);
}

#pragma mark One-time move to after Query

- (void)testTransferMovedOnceFromAfterUsersToAfterQuery
{
	// The owner's saved layout (Transfer inserted after Users by an earlier build)
	SPToolbarTestsDelegate *delegate = nil;
	NSArray *saved = @[SPTestDatabase, SPTestStructure, SPTestContent, SPTestQuery, NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
					   SPTestHistory, SPTestTransfer, SPTestShowConsole];
	NSToolbar *toolbar = [self toolbarWithLayout:saved delegate:&delegate];
	SPToolbarTestsDefaults *defaults = [[SPToolbarTestsDefaults alloc] init];
	defaults.values[SPTestTransferAddedKey] = @YES;

	XCTAssertFalse(SPInsertTransferToolbarItemIfNeeded(toolbar, defaults));
	XCTAssertTrue(SPMoveTransferToolbarItemAfterQueryIfNeeded(toolbar, defaults));
	NSArray *expected = @[SPTestDatabase, SPTestStructure, SPTestContent, SPTestQuery, SPTestTransfer, NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
						  SPTestHistory, SPTestShowConsole];
	XCTAssertEqualObjects([[toolbar items] valueForKey:@"itemIdentifier"], expected);
	XCTAssertEqualObjects(defaults.values[SPTestTransferMovedKey], @YES);

	// Placed elsewhere by the user (Customize Toolbar) afterwards: not moved back
	[toolbar removeItemAtIndex:4];
	[toolbar insertItemWithItemIdentifier:SPTestTransfer atIndex:0];
	XCTAssertFalse(SPMoveTransferToolbarItemAfterQueryIfNeeded(toolbar, defaults));
	XCTAssertEqualObjects([[toolbar items] valueForKey:@"itemIdentifier"][0], SPTestTransfer);
}

- (void)testTransferBeforeQueryMovesAfterIt
{
	SPToolbarTestsDelegate *delegate = nil;
	NSToolbar *toolbar = [self toolbarWithLayout:@[SPTestTransfer, SPTestDatabase, SPTestQuery, SPTestUsers] delegate:&delegate];
	XCTAssertTrue(SPMoveTransferToolbarItemAfterQueryIfNeeded(toolbar, [[SPToolbarTestsDefaults alloc] init]));
	XCTAssertEqualObjects([[toolbar items] valueForKey:@"itemIdentifier"], (@[SPTestDatabase, SPTestQuery, SPTestTransfer, SPTestUsers]));
}

- (void)testLayoutWithoutTransferOrQueryIsOnlyRecorded
{
	// Transfer removed by the user: not re-added
	SPToolbarTestsDelegate *delegate = nil;
	NSArray *saved = @[SPTestDatabase, SPTestQuery, SPTestUsers];
	NSToolbar *toolbar = [self toolbarWithLayout:saved delegate:&delegate];
	SPToolbarTestsDefaults *defaults = [[SPToolbarTestsDefaults alloc] init];
	XCTAssertFalse(SPMoveTransferToolbarItemAfterQueryIfNeeded(toolbar, defaults));
	XCTAssertEqualObjects([[toolbar items] valueForKey:@"itemIdentifier"], saved);
	XCTAssertEqualObjects(defaults.values[SPTestTransferMovedKey], @YES);

	// Query removed by the user: Transfer stays
	SPToolbarTestsDelegate *otherDelegate = nil;
	NSArray *otherSaved = @[SPTestDatabase, SPTestUsers, SPTestTransfer];
	NSToolbar *other = [self toolbarWithLayout:otherSaved delegate:&otherDelegate];
	XCTAssertFalse(SPMoveTransferToolbarItemAfterQueryIfNeeded(other, [[SPToolbarTestsDefaults alloc] init]));
	XCTAssertEqualObjects([[other items] valueForKey:@"itemIdentifier"], otherSaved);
}

- (void)testStandardDefaultsInTestsNeverInsert
{
	// The volatile argument-domain override (see SPToolbarTestsPrefsGuard) reads YES, so the real
	// preferences are never written by the insertion in tests
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	XCTAssertTrue([prefs boolForKey:SPTestTransferAddedKey]);

	SPToolbarTestsDelegate *delegate = nil;
	NSArray *saved = @[SPTestDatabase, SPTestUsers, SPTestShowConsole];
	NSToolbar *toolbar = [self toolbarWithLayout:saved delegate:&delegate];
	XCTAssertFalse(SPInsertTransferToolbarItemIfNeeded(toolbar, prefs));
	XCTAssertEqualObjects([[toolbar items] valueForKey:@"itemIdentifier"], saved);

	// Nor by the move
	XCTAssertTrue([prefs boolForKey:SPTestTransferMovedKey]);
	SPToolbarTestsDelegate *movedDelegate = nil;
	NSArray *withTransfer = @[SPTestDatabase, SPTestQuery, SPTestUsers, SPTestTransfer];
	NSToolbar *moved = [self toolbarWithLayout:withTransfer delegate:&movedDelegate];
	XCTAssertFalse(SPMoveTransferToolbarItemAfterQueryIfNeeded(moved, prefs));
	XCTAssertEqualObjects([[moved items] valueForKey:@"itemIdentifier"], withTransfer);
}

#pragma mark PostgreSQL

- (void)testPostgresToolbarSharesIdentifierAndItems
{
	id mysql = [self.controller addNewConnection];
	NSToolbar *mysqlToolbar = [[self.controller window] toolbar];
	SPPostgresDocument *postgres = [self addPostgresTabAtIndex:1];
	NSToolbar *toolbar = [postgres toolbar];

	XCTAssertEqualObjects([toolbar identifier], SPTestToolbarIdentifier);
	XCTAssertEqual([[self.controller window] toolbar], toolbar);
	XCTAssertTrue([toolbar allowsUserCustomization], @"the saved layout is shared, so is customizing it");
	XCTAssertTrue([toolbar sp_requestedAutosave]);

	NSArray *allowed = [[toolbar delegate] toolbarAllowedItemIdentifiers:toolbar];
	NSMutableSet *mysqlAllowed = [NSMutableSet setWithArray:[mysql toolbarAllowedItemIdentifiers:mysqlToolbar]];
	[mysqlAllowed addObject:SPTestTransfer];
	XCTAssertTrue([mysqlAllowed isSubsetOfSet:[NSSet setWithArray:allowed]], @"%@", allowed);
	XCTAssertEqualObjects([NSSet setWithArray:allowed], mysqlAllowed, @"identical to MySQL's");

	NSArray *expected = @[SPTestDatabase, SPTestStructure, SPTestContent, SPTestRelations, SPTestTriggers, SPTestTableInfo,
						  SPTestQuery, SPTestTransfer, NSToolbarFlexibleSpaceItemIdentifier, SPTestHistory, SPTestUsers, SPTestShowConsole];
	XCTAssertEqualObjects([[toolbar delegate] toolbarDefaultItemIdentifiers:toolbar], expected);
	XCTAssertEqualObjects([mysql toolbarDefaultItemIdentifiers:mysqlToolbar], expected);
	XCTAssertEqualObjects([[toolbar items] valueForKey:@"itemIdentifier"], expected);

	// Every identifier MySQL serves, the Postgres tab serves too (toolbars with one identifier sync their items)
	for (NSString *identifier in mysqlAllowed) {
		if ([identifier hasPrefix:@"NSToolbar"]) continue;
		// View items are checked in the toolbar above (a second item would take their view)
		if ([identifier isEqualToString:SPTestDatabase] || [identifier isEqualToString:SPTestHistory]) continue;
		NSToolbarItem *item = [[toolbar delegate] toolbar:toolbar itemForItemIdentifier:identifier willBeInsertedIntoToolbar:NO];
		XCTAssertNotNil(item, @"%@", identifier);
		XCTAssertTrue([[item label] length], @"%@", identifier);
		XCTAssertTrue([[item paletteLabel] length], @"%@", identifier);
		XCTAssertNotNil([item image], @"%@", identifier);
	}
}

- (BOOL)isEnabled:(NSToolbarItem *)item forDocument:(SPPostgresDocument *)document
{
	if ([[item view] isKindOfClass:[NSSegmentedControl class]]) {
		// As MySQL's history control: enabled, with its segments enabled as history allows
		NSSegmentedControl *control = (NSSegmentedControl *)[item view];
		BOOL anySegment = NO;
		for (NSInteger i = 0; i < [control segmentCount]; i++) anySegment = anySegment || [control isEnabledForSegment:i];
		return [item isEnabled] && [control isEnabled] && anySegment;
	}
	if ([item view]) return [item isEnabled] && [(NSControl *)[item view] isEnabled];
	return [document validateToolbarItem:item];
}

- (void)testPostgresEnablement
{
	SPPostgresDocument *postgres = [self addPostgresTabAtIndex:0];
	NSToolbar *toolbar = [postgres toolbar];

	NSMutableArray *items = [[toolbar items] mutableCopy];
	// Not in the default layout
	[items addObject:[[toolbar delegate] toolbar:toolbar itemForItemIdentifier:SPTestClearConsole willBeInsertedIntoToolbar:NO]];

	NSMutableArray *enabled = [NSMutableArray array];
	for (NSToolbarItem *item in items) {
		if ([[item itemIdentifier] hasPrefix:@"NSToolbar"]) continue;
		if ([self isEnabled:item forDocument:postgres]) [enabled addObject:[item itemIdentifier]];
	}
	// Content needs a selected table; Query works without one; Users opens the Users sheet, Transfer the Transfer sheet
	XCTAssertEqualObjects(enabled, (@[SPTestDatabase, SPTestQuery, SPTestTransfer, SPTestUsers, SPTestShowConsole]));

	// History is a view item with both segments disabled (as on a MySQL connection screen)
	NSToolbarItem *history = [self itemWithIdentifier:SPTestHistory inToolbar:toolbar];
	NSSegmentedControl *historyControl = (NSSegmentedControl *)[history view];
	XCTAssertTrue([historyControl isKindOfClass:[NSSegmentedControl class]]);
	XCTAssertFalse([historyControl isEnabledForSegment:0]);
	XCTAssertFalse([historyControl isEnabledForSegment:1]);

	// Transfer has the stage-1 image
	XCTAssertNotNil([[self itemWithIdentifier:SPTestTransfer inToolbar:toolbar] image]);
}

- (void)testSwitchingTabsSwapsToolbarState
{
	SPPostgresDocument *postgres = [self addPostgresTabAtIndex:0];
	id mysql = [self.controller addNewConnection];
	NSWindow *window = [self.controller window];

	// MySQL tab: its toolbar, Content enabled when connected with a table selected (stubbed: no live MySQL in the test servers)
	XCTAssertEqual([self.controller selectedDocument], mysql);
	XCTAssertNotEqual([window toolbar], [postgres toolbar]);
	XCTAssertEqualObjects([[window toolbar] identifier], SPTestToolbarIdentifier);
	NSToolbarItem *content = [self itemWithIdentifier:SPTestContent inToolbar:[window toolbar]];
	XCTAssertEqual([content target], mysql);
	XCTAssertTrue([self validate:content asConnectedMySQLDocument:mysql]);
	XCTAssertFalse([mysql validateToolbarItem:[self itemWithIdentifier:SPTestTransfer inToolbar:[window toolbar]]], @"no database");

	// Postgres tab: same identifier, Content disabled
	[[self tabView] selectTabViewItem:postgres.parentTabViewItem];
	XCTAssertEqual([self.controller selectedDocument], postgres);
	XCTAssertEqual([window toolbar], [postgres toolbar]);
	XCTAssertEqualObjects([[window toolbar] identifier], SPTestToolbarIdentifier);
	content = [self itemWithIdentifier:SPTestContent inToolbar:[window toolbar]];
	XCTAssertEqual([content target], postgres);
	XCTAssertFalse([postgres validateToolbarItem:content]);
	XCTAssertTrue([postgres validateToolbarItem:[self itemWithIdentifier:SPTestShowConsole inToolbar:[window toolbar]]]);

	// And back
	[[self tabView] selectTabViewItem:[[self tabView] tabViewItemAtIndex:1]];
	XCTAssertEqual([self.controller selectedDocument], mysql);
	content = [self itemWithIdentifier:SPTestContent inToolbar:[window toolbar]];
	XCTAssertEqual([content target], mysql);
	XCTAssertTrue([self validate:content asConnectedMySQLDocument:mysql]);
}

@end
