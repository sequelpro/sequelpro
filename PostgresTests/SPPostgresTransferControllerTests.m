#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import <PostgresKit/PostgresKit.h>
#import "SPPostgresTestServers.h"
#import "../Source/SPWindowController.h"
#import "../Source/SPToolbarTransferItem.h"
#import "../Source/Postgres/SPPostgresDocument.h"
#import "../Source/Postgres/SPPostgresConnector.h"
#import "../Source/Postgres/SPPostgresFavorite.h"
#import "../Source/Postgres/SPPostgresSidebarController.h"
#import "../Source/Postgres/SPPostgresExportController.h"
#import "../Source/Postgres/SPPostgresTransferController.h"
#import "../Source/Postgres/SPPostgresTransfer.h"
#import "../Source/Postgres/SPPostgresCheckList.h"
#import "../Source/Postgres/SPPostgresProgressSheet.h"
#import "../Source/Postgres/SPPostgresErrors.h"
#import "../Source/Postgres/SPPostgresFavoritesStore.h"

static NSString * const SPTestTransferIdentifier = @"TransferToolbarItemIdentifier";

/// The Transfer sheet (SPPostgresTransferController) and the Transfer toolbar item of a Postgres tab connected to
/// pgkit_io_src (io_source.sql), copying into pgkit_io_dst (or an sp_t7_% database it creates), on PG 12 and 18. The
/// favorites and targetConnect are the test's (the favorites store and the Keychain are never read); the dump goes to
/// a test-owned directory.
@interface SPPostgresTransferControllerTests : XCTestCase
@property (strong) SPWindowController *windowController;
@property (strong) SPPostgresDocument *document;
@property (strong) NSNumber *port;
@property (strong) NSMutableArray<NSString *> *providedDatabases;
/// "<favorite name>|<password or (none)>|<database>|<session, or the session token for a transfer connection>" per
/// targetConnect call
@property (strong) NSMutableArray<NSString *> *targetRequests;
/// The sessions targetConnect opened, and their tokens ("token <n>")
@property (strong) NSMutableArray<PGPostgresConnection *> *sessionConnections;
@property (strong) NSMutableArray<NSString *> *sessionTokens;
/// targetConnect answers PasswordRequired unless given this password (nil: none needed)
@property (copy) NSString *requiredPassword;
/// targetConnect fails (not a password or SSH error)
@property BOOL failConnects;
/// Non-nil: targetConnect's answers wait here (run them to answer); nil: answered on the next run loop turn
@property (strong) NSMutableArray *heldConnects;
@property (strong) NSMutableArray<PGPostgresConnection *> *providedConnections;
@property (strong) NSMutableArray<NSAlert *> *alerts;
@property (strong) NSMutableArray<PGPostgresConnection *> *openConnections;
@property (copy) NSString *directory;
@property (strong) SPPostgresTransferController *controller;
@property BOOL ended;
@end

/// Stands in for SPSSHTunnel as the owner of its SSHQuestionDialog nib (its real password and host-key sheets, buttons
/// and actions), without starting a tunnel: records how each sheet was answered and ends it as the tunnel does.
@interface SPTestTunnelSheetOwner : NSObject
@property (strong) IBOutlet NSWindow *sshQuestionDialog;
@property (strong) IBOutlet NSTextField *sshQuestionText;
@property (strong) IBOutlet NSButton *sshPasswordKeychainCheckbox;
@property (strong) IBOutlet NSWindow *sshPasswordDialog;
@property (strong) IBOutlet NSTextField *sshPasswordText;
@property (strong) IBOutlet NSSecureTextField *sshPasswordField;
@property (strong) NSArray *topLevelObjects;
/// "password yes/no", "question yes/no" per answer
@property (strong) NSMutableArray<NSString *> *answers;
@end

@implementation SPTestTunnelSheetOwner

- (instancetype)init
{
	if ((self = [super init])) {
		_answers = [NSMutableArray array];
		NSArray *objects = nil;
		if (![[NSBundle mainBundle] loadNibNamed:@"SSHQuestionDialog" owner:self topLevelObjects:&objects]) return nil;
		_topLevelObjects = objects;
	}
	return self;
}

- (void)_answer:(NSString *)kind sender:(id)sender dialog:(NSWindow *)dialog
{
	[self.answers addObject:[NSString stringWithFormat:@"%@ %@", kind, [sender tag] == 1 ? @"yes" : @"no"]];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	[NSApp endSheet:dialog];
#pragma clang diagnostic pop
	[dialog orderOut:nil];
}

- (IBAction)closeSSHQuestionSheet:(id)sender { [self _answer:@"question" sender:sender dialog:self.sshQuestionDialog]; }
- (IBAction)closeSSHPasswordSheet:(id)sender { [self _answer:@"password" sender:sender dialog:self.sshPasswordDialog]; }

/// Shows a dialog on window as SPSSHTunnel does.
- (void)show:(NSWindow *)dialog on:(NSWindow *)window
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	[NSApp beginSheet:dialog modalForWindow:window modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
#pragma clang diagnostic pop
}

@end

@implementation SPPostgresTransferControllerTests

- (void)setUp
{
	self.continueAfterFailure = NO;
	self.openConnections = [NSMutableArray array];
	self.directory = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
	[[NSFileManager defaultManager] createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil error:NULL];
}

- (void)tearDown
{
	[self closeDocument];
	for (PGPostgresConnection *connection in self.openConnections) [connection disconnect];
	self.openConnections = nil;
	[self dropTestDatabases];
	[[NSFileManager defaultManager] removeItemAtPath:self.directory error:NULL];
	[super tearDown];
}

#pragma mark - Helpers

/// Drops every sp_t7_% database the tests created (test code only: app code never drops databases).
- (void)dropTestDatabases
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		PGPostgresConnection *connection = [SPPostgresTestServers connectedConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_test"];
		PGPostgresResult *result = [connection execute:@"SELECT datname::text AS n FROM pg_database WHERE datname LIKE 'sp\\_t7\\_%'"];
		for (NSDictionary *row in result) {
			NSString *quoted = [NSString stringWithFormat:@"\"%@\"", [row[@"n"] stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
			XCTAssertNotNil([connection execute:[@"DROP DATABASE IF EXISTS " stringByAppendingString:quoted]], @"%@", connection.lastError.errorPrimaryMessage);
		}
		[connection disconnect];
	}
}

- (BOOL)spinUntil:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout
{
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
	while (!condition() && [deadline timeIntervalSinceNow] > 0) {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
	}
	return condition();
}

- (void)run:(NSString *)sql on:(PGPostgresConnection *)connection
{
	XCTAssertNotNil([connection execute:sql], @"%@: %@", sql, connection.lastError.errorPrimaryMessage);
}

- (NSString *)value:(NSString *)sql on:(PGPostgresConnection *)connection
{
	PGPostgresResult *result = [connection execute:sql];
	XCTAssertNotNil(result, @"%@: %@", sql, connection.lastError.errorPrimaryMessage);
	id value = result.numberOfRows ? [result textValueAtRow:0 column:0] : nil;
	return [value isKindOfClass:[NSString class]] ? value : nil;
}

- (NSWindow *)window
{
	return [self.windowController window];
}

- (SPPostgresFavorite *)favoriteNamed:(NSString *)name database:(NSString *)database
{
	SPPostgresFavorite *favorite = [[SPPostgresFavorite alloc] init];
	favorite.name = name;
	favorite.type = SPPostgresTCPIPConnection;
	favorite.host = @"127.0.0.1";
	favorite.port = self.port.unsignedIntegerValue;
	favorite.user = @"pgkit_test";
	favorite.database = database;
	return favorite;
}

/// pgkit_io_src loaded with io_source.sql, pgkit_io_dst emptied (held open, for checks), and a Postgres tab connected to
/// pgkit_io_src whose connectionProvider hands out test-server connections.
- (PGPostgresConnection *)buildDocumentOn:(NSNumber *)port
{
	self.port = port;
	PGPostgresConnection *loader = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_src"];
	XCTAssertNotNil(loader);
	[SPPostgresTestServers loadFixtureNamed:@"io_source" onPort:port.unsignedIntegerValue];
	[loader disconnect];
	PGPostgresConnection *target = [SPPostgresTestServers ioConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_dst"];
	XCTAssertNotNil(target);
	[self.openConnections addObject:target];

	SPPostgresFavorite *favorite = [self favoriteNamed:[NSString stringWithFormat:@"pg %@ source", port] database:@"pgkit_io_src"];

	self.windowController = [[SPWindowController alloc] initWithWindowNibName:@"MainWindow"];
	XCTAssertNotNil([self window]);

	SPPostgresConnector *connector = [[SPPostgresConnector alloc] initWithFavorite:favorite password:@"pgkit" sshPassword:nil parentWindow:nil];
	__block PGPostgresConnection *connection = nil;
	__block NSError *connectError = nil;
	__block BOOL done = NO;
	[connector connectWithCompletion:^(PGPostgresConnection *theConnection, NSError *error) {
		connection = theConnection;
		connectError = error;
		done = YES;
	}];
	XCTAssertTrue([self spinUntil:^BOOL{ return done; } timeout:20]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	XCTAssertNotNil(connection, @"%@", connectError);

	self.document = [[SPPostgresDocument alloc] initWithConnection:connection connector:connector favorite:favorite];
	NSMutableArray *alerts = [NSMutableArray array];
	self.alerts = alerts;
	self.document.alertPresenter = ^(NSAlert *alert) { [alerts addObject:alert]; };

	NSMutableArray *databases = [NSMutableArray array];
	NSMutableArray *connections = [NSMutableArray array];
	self.providedDatabases = databases;
	self.providedConnections = connections;
	self.targetRequests = [NSMutableArray array];
	NSUInteger thePort = port.unsignedIntegerValue;
	self.document.connectionProvider = ^(NSString *database, void (^completion)(PGPostgresConnection *, NSError *)) {
		[databases addObject:database];
		PGPostgresConnection *provided = [SPPostgresTestServers connectedConnectionOnPort:thePort database:database];
		if (provided) [connections addObject:provided];
		completion(provided, provided ? nil : [NSError errorWithDomain:@"test" code:1 userInfo:@{NSLocalizedDescriptionKey: @"no connection"}]);
	};

	[self.windowController addTabDocument:self.document atIndex:0 select:YES];
	// The first loads run on the tab's runner
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	[[self window] setFrameOrigin:NSMakePoint(-10000, -10000)];
	[self.windowController showWindow:nil];
	return target;
}

- (void)closeDocument
{
	if (!self.windowController) return;
	NSWindow *window = [self window];
	if (self.controller && !self.ended) {
		[self.controller cancel:nil];
		[self spinUntil:^BOOL{ return self.ended; } timeout:20];
	}
	self.controller = nil;
	if (window.attachedSheet) [window endSheet:window.attachedSheet];
	NSTabView *tabView = [self.windowController valueForKey:@"tabView"];
	for (NSTabViewItem *item in [tabView tabViewItems]) [tabView removeTabViewItem:item];
	[window orderOut:nil];
	self.document = nil;
	self.windowController = nil;
	for (PGPostgresConnection *connection in self.providedConnections) [connection disconnect];
	self.providedConnections = nil;
	self.sessionConnections = nil;
}

/// Runs body once per test server, with a fresh document each time (body gets a connection to pgkit_io_dst).
- (void)onEachPort:(void (^)(NSNumber *port, PGPostgresConnection *target))body
{
	for (NSNumber *port in [SPPostgresTestServers ports]) {
		PGPostgresConnection *target = [self buildDocumentOn:port];
		body(port, target);
		[self closeDocument];
	}
}

/// Sets the test's favorites (default: "Test target" for pgkit_io_dst), targetConnect and dump directory.
- (void)configure:(SPPostgresTransferController *)controller favorites:(NSArray *)favorites
{
	controller.favorites = favorites ?: @[[self favoriteNamed:@"Test target" database:@"pgkit_io_dst"]];
	controller.temporaryDirectory = self.directory;
	self.sessionConnections = [NSMutableArray array];
	self.sessionTokens = [NSMutableArray array];
	NSMutableArray *requests = self.targetRequests;
	NSMutableArray *connections = self.providedConnections;
	NSMutableArray *sessions = self.sessionConnections;
	NSMutableArray *tokens = self.sessionTokens;
	NSUInteger thePort = self.port.unsignedIntegerValue;
	__weak SPPostgresTransferControllerTests *weakSelf = self;
	controller.targetConnect = ^(SPPostgresFavorite *favorite, NSString *database, NSString *password, id sessionToken, void (^completion)(PGPostgresConnection *, id, NSError *)) {
		XCTAssertTrue([NSThread isMainThread]);
		[requests addObject:[NSString stringWithFormat:@"%@|%@|%@|%@", favorite.name, password.length ? password : @"(none)", database, sessionToken ?: @"session"]];
		NSMutableArray *held = weakSelf.heldConnects;
		void (^answer)(void) = ^{
			if (weakSelf.failConnects) {
				completion(nil, nil, SPPostgresMakeError(SPPostgresErrorConnectionFailed, @"test: could not connect", nil));
				return;
			}
			NSString *required = weakSelf.requiredPassword;
			if (required && ![password isEqualToString:required]) {
				completion(nil, nil, SPPostgresMakeError(SPPostgresErrorPasswordRequired, @"password authentication failed for user \"pgkit_test\"", nil));
				return;
			}
			// Only the databases the tests may touch
			if (!([database isEqualToString:@"pgkit_io_src"] || [database isEqualToString:@"pgkit_io_dst"] || [database hasPrefix:@"sp_t7_"])) {
				completion(nil, nil, SPPostgresMakeError(SPPostgresErrorConnectionFailed, [NSString stringWithFormat:@"test: no database %@", database], nil));
				return;
			}
			PGPostgresConnection *provided = [SPPostgresTestServers connectedConnectionOnPort:thePort database:database];
			if (provided) [connections addObject:provided];
			id token = sessionToken;
			if (provided && !token) {
				token = [NSString stringWithFormat:@"token %lu", (unsigned long)tokens.count + 1];
				[sessions addObject:provided];
				[tokens addObject:token];
			}
			completion(provided, token, provided ? nil : SPPostgresMakeError(SPPostgresErrorConnectionFailed, @"no connection", nil));
		};
		if (held) [held addObject:[answer copy]];
		else dispatch_async(dispatch_get_main_queue(), answer);
	};
	controller.didEnd = ^{ weakSelf.ended = YES; };
}

/// A Transfer sheet with the test's favorites and targetConnect; waits for its session unless connects are held.
- (SPPostgresTransferController *)openSheetWithFavorites:(NSArray *)favorites
{
	// The tab's loads first (the sheet opens only while the tab isn't busy)
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	SPPostgresTransferController *controller = [[SPPostgresTransferController alloc] initWithDocument:self.document];
	self.controller = controller;
	self.ended = NO;
	[self configure:controller favorites:favorites];
	[controller beginSheet];
	XCTAssertEqual([self window].attachedSheet, controller.sheet, @"the Transfer sheet is shown");
	if (!self.heldConnects && controller.favorites.count) [self waitForSession:controller];
	return controller;
}

/// Waits until the session's connect has ended (the menu no longer says "Connecting…").
- (void)waitForSession:(SPPostgresTransferController *)controller
{
	XCTAssertTrue([self spinUntil:^BOOL{ return ![controller.databasePopup.titleOfSelectedItem isEqualToString:@"Connecting…"] && controller.databasePopup.numberOfItems > 0; } timeout:20]);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
}

/// The database menu's titles, the separator as "-".
- (NSArray<NSString *> *)menuTitles:(SPPostgresTransferController *)controller
{
	NSMutableArray *titles = [NSMutableArray array];
	for (NSMenuItem *item in controller.databasePopup.itemArray) [titles addObject:item.isSeparatorItem ? @"-" : item.title];
	return titles;
}

/// Chooses a database menu item by title (as the user would).
- (void)chooseDatabase:(NSString *)title in:(SPPostgresTransferController *)controller
{
	NSPopUpButton *popup = controller.databasePopup;
	XCTAssertGreaterThanOrEqual([popup indexOfItemWithTitle:title], 0, @"%@ is listed", title);
	[popup selectItemWithTitle:title];
	[NSApp sendAction:popup.action to:popup.target from:popup];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
}

/// Runs the held targetConnect answer at index.
- (void)answerHeld:(NSUInteger)index
{
	XCTAssertGreaterThan(self.heldConnects.count, index);
	void (^answer)(void) = self.heldConnects[index];
	answer();
}

- (SPPostgresTransferController *)openSheet
{
	return [self openSheetWithFavorites:nil];
}

- (void)click:(NSButton *)button
{
	XCTAssertTrue(button.isEnabled, @"%@ is enabled", button.title);
	[button performClick:nil];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
}

- (void)chooseFavorite:(NSInteger)index in:(SPPostgresTransferController *)controller
{
	NSPopUpButton *popup = controller.favoritePopup;
	[popup selectItemAtIndex:index];
	[NSApp sendAction:popup.action to:popup.target from:popup];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
}

- (void)uncheckAll:(SPPostgresTransferController *)controller
{
	for (id item in controller.tablesList.checkedItems) [controller.tablesList setChecked:NO item:item];
}

/// Starts the transfer and waits until the controller has ended.
- (void)transferWith:(SPPostgresTransferController *)controller
{
	XCTAssertTrue(controller.transferButton.isEnabled);
	[controller transfer:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return self.ended && [self window].attachedSheet == nil; } timeout:120],
				  @"the transfer ends (%@)", controller.lastErrorMessage);
}

- (NSDictionary *)rowsOf:(PGPostgresConnection *)connection
{
	[self run:@"RESET search_path" on:connection];
	NSDictionary *description = [SPPostgresTestServers describeDatabase:connection];
	NSMutableDictionary *rows = [NSMutableDictionary dictionary];
	for (NSString *key in description) if ([key hasPrefix:@"rows "]) rows[key] = description[key];
	return rows;
}

- (void)assertTemporaryDirectoryEmpty
{
	XCTAssertEqualObjects([[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.directory error:NULL], @[], @"the dump is deleted");
}

/// A one-row table public.marker on the target.
- (void)addMarkerTo:(PGPostgresConnection *)target
{
	[self run:@"CREATE TABLE public.marker (note text)" on:target];
	[self run:@"INSERT INTO public.marker VALUES ('still here')" on:target];
}

#pragma mark - The sheet

- (void)testDefaults
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		SPPostgresTransferController *controller = [self openSheet];
		XCTAssertEqual(controller.wholeDatabaseRadio.state, NSControlStateValueOn);
		XCTAssertEqual(controller.selectedTablesRadio.state, NSControlStateValueOff);
		XCTAssertEqualObjects(controller.wholeDatabaseRadio.title, @"Whole database “pgkit_io_src”");
		XCTAssertEqualObjects(controller.selectedTablesRadio.title, @"Selected tables");
		XCTAssertEqual(controller.emptyModeRadio.state, NSControlStateValueOn);
		XCTAssertEqual(controller.overwriteModeRadio.state, NSControlStateValueOff);
		XCTAssertEqualObjects(controller.emptyModeRadio.title, @"Empty the target database first");
		XCTAssertEqualObjects(controller.overwriteModeRadio.title, @"Overwrite tables that already exist on the target");
		XCTAssertEqualObjects(controller.favoritePopup.titleOfSelectedItem, @"Test target");
		XCTAssertTrue(controller.favoritePopup.isEnabled);
		XCTAssertEqualObjects(controller.targetDescriptionField.stringValue, ([NSString stringWithFormat:@"pgkit_test@127.0.0.1:%@", port]));
		XCTAssertEqualObjects(controller.databasePopup.titleOfSelectedItem, @"pgkit_io_dst", @"the favorite's database");
		XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_dst");
		XCTAssertEqualObjects(controller.targetStatusField.stringValue, @"");
		XCTAssertTrue(controller.retryButton.isHidden);
		XCTAssertEqualObjects(controller.retryButton.title, @"Retry");
		XCTAssertEqualObjects(controller.transferButton.title, @"Transfer");
		XCTAssertTrue(controller.transferButton.isEnabled);
		XCTAssertEqual(self.providedDatabases.count, 0u, @"the source isn't connected while the sheet is open");
		XCTAssertEqualObjects(self.targetRequests, @[@"Test target|(none)|pgkit_io_dst|session"], @"only the session");
		XCTAssertFalse([controller respondsToSelector:NSSelectorFromString(@"passwordField")], @"no Password field");
		XCTAssertFalse([controller respondsToSelector:NSSelectorFromString(@"databaseField")], @"a menu, not a field");
	}];
}

- (void)testTargetDescriptions
{
	SPPostgresFavorite *favorite = [[SPPostgresFavorite alloc] init];
	favorite.user = @"ann";
	favorite.host = @"db.example.com";
	favorite.port = 5433;
	XCTAssertEqualObjects([SPPostgresTransferController targetDescriptionForFavorite:favorite], @"ann@db.example.com:5433");
	favorite.port = 0;
	XCTAssertEqualObjects([SPPostgresTransferController targetDescriptionForFavorite:favorite], @"ann@db.example.com:5432");
	favorite.type = SPPostgresSocketConnection;
	XCTAssertEqualObjects([SPPostgresTransferController targetDescriptionForFavorite:favorite], @"ann@local socket");
	favorite.socketPath = @"/tmp";
	XCTAssertEqualObjects([SPPostgresTransferController targetDescriptionForFavorite:favorite], @"ann@/tmp");
	favorite.type = SPPostgresSSHConnection;
	favorite.host = @"127.0.0.1";
	favorite.sshUser = @"bob";
	favorite.sshHost = @"gate.example.com";
	XCTAssertEqualObjects([SPPostgresTransferController targetDescriptionForFavorite:favorite], @"ann@127.0.0.1:5432 via SSH bob@gate.example.com");
}

/// A catalog error while the tables list loads is shown (an alert), not just an empty list.
- (void)testTablesListErrorIsShown
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		// The tab's session in a failed transaction: the catalog queries fail
		PGPostgresConnection *tab = self.document.connection;
		[self run:@"BEGIN" on:tab];
		XCTAssertNil([tab execute:@"SELECT 1/0"]);
		[self.alerts removeAllObjects];
		SPPostgresTransferController *controller = [self openSheet];
		XCTAssertEqual(self.alerts.count, 1u, @"%@", [self.alerts valueForKey:@"messageText"]);
		NSAlert *alert = self.alerts.firstObject;
		XCTAssertEqualObjects(alert.messageText, @"The tables couldn't be read");
		XCTAssertTrue([alert.informativeText containsString:@"current transaction is aborted"], @"%@", alert.informativeText);
		XCTAssertEqualObjects(controller.lastErrorMessage, alert.informativeText);
		XCTAssertEqual(controller.tablesList.rows.count, 0u);
		[self run:@"ROLLBACK" on:tab];

		[controller cancel:nil];
		XCTAssertTrue([self spinUntil:^BOOL{ return self.ended && [self window].attachedSheet == nil; } timeout:5]);
		XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);

		// Readable again: no alert
		[self.alerts removeAllObjects];
		controller = [self openSheet];
		XCTAssertEqual(self.alerts.count, 0u);
		XCTAssertGreaterThan(controller.tablesList.rows.count, 0u);
		[controller cancel:nil];
		XCTAssertTrue([self spinUntil:^BOOL{ return self.ended && [self window].attachedSheet == nil; } timeout:5]);
		XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	}];
}

- (void)testTransferDisabledWithoutTablesOrDatabase
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		SPPostgresTransferController *controller = [self openSheet];
		[self click:controller.selectedTablesRadio];
		XCTAssertEqual(controller.selectedTablesRadio.state, NSControlStateValueOn);
		XCTAssertEqual(controller.wholeDatabaseRadio.state, NSControlStateValueOff);
		[self uncheckAll:controller];
		XCTAssertFalse(controller.transferButton.isEnabled, @"no table checked");
		[controller.tablesList setChecked:YES item:@[@"Sales Data", @"order_lines"]];
		XCTAssertTrue(controller.transferButton.isEnabled);
		[self uncheckAll:controller];
		XCTAssertFalse(controller.transferButton.isEnabled);
		[self click:controller.wholeDatabaseRadio];
		XCTAssertTrue(controller.transferButton.isEnabled, @"the whole database needs no table checked");

		[controller cancel:nil];
		XCTAssertTrue([self spinUntil:^BOOL{ return self.ended && [self window].attachedSheet == nil; } timeout:5]);
		XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);

		NSUInteger requests = self.targetRequests.count;
		controller = [self openSheetWithFavorites:@[]];
		XCTAssertFalse(controller.favoritePopup.isEnabled, @"no favorites");
		XCTAssertFalse(controller.databasePopup.isEnabled);
		XCTAssertFalse(controller.transferButton.isEnabled);
		XCTAssertNil(controller.selectedDatabase);
		[controller transfer:nil];
		XCTAssertEqual(self.targetRequests.count, requests, @"no favorite: nothing connects");
		[controller cancel:nil];
		XCTAssertTrue([self spinUntil:^BOOL{ return self.ended && [self window].attachedSheet == nil; } timeout:5]);
		XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	}];
}

/// The target line and the menu follow the favorite (a session per favorite, the previous one closed).
- (void)testDatabaseMenuFollowsFavorite
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		SPPostgresFavorite *first = [self favoriteNamed:@"Test target" database:@"pgkit_io_dst"];
		SPPostgresFavorite *second = [self favoriteNamed:@"Other target" database:@"pgkit_io_src"];
		second.user = @"someone";
		SPPostgresTransferController *controller = [self openSheetWithFavorites:@[first, second]];
		XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_dst");

		[self chooseFavorite:1 in:controller];
		XCTAssertEqualObjects(controller.targetDescriptionField.stringValue, ([NSString stringWithFormat:@"someone@127.0.0.1:%@", port]));
		[self waitForSession:controller];
		XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_src");
		XCTAssertFalse(self.sessionConnections[0].isConnected, @"the first favorite's session is closed");
		XCTAssertTrue(self.sessionConnections[1].isConnected);

		[self chooseFavorite:0 in:controller];
		[self waitForSession:controller];
		XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_dst");
		XCTAssertFalse(self.sessionConnections[1].isConnected);
		XCTAssertEqualObjects(self.targetRequests, (@[@"Test target|(none)|pgkit_io_dst|session", @"Other target|(none)|pgkit_io_src|session", @"Test target|(none)|pgkit_io_dst|session"]));
	}];
}

- (void)testPopupSkipsThisTabsFavorite
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		self.document.favorite.favoriteID = @"this-tab";
		SPPostgresFavorite *mine = [self.document.favorite copy];
		mine.name = @"A this tab";
		SPPostgresFavorite *other = [self favoriteNamed:@"B other" database:@"pgkit_io_dst"];
		other.favoriteID = @"other";
		SPPostgresTransferController *controller = [self openSheetWithFavorites:@[mine, other]];
		XCTAssertEqualObjects(controller.favoritePopup.titleOfSelectedItem, @"B other");
		XCTAssertEqual(controller.favoritePopup.numberOfItems, 2, @"this tab's favorite is offered too (another database)");
	}];
}

#pragma mark - Filters

/// The titles a pop-up's menu shows (hidden items left out), the separator as "-".
- (NSArray<NSString *> *)visibleTitles:(NSPopUpButton *)popup
{
	NSMutableArray *titles = [NSMutableArray array];
	for (NSMenuItem *item in popup.itemArray) if (!item.isHidden) [titles addObject:item.isSeparatorItem ? @"-" : item.title];
	return titles;
}

- (void)typeFilter:(NSString *)text in:(NSSearchField *)field
{
	XCTAssertNotNil(field);
	field.stringValue = text;
	[NSApp sendAction:field.action to:field.target from:field];
}

- (void)testFavoriteFilterNarrowsTheMenu
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		SPPostgresFavorite *prod = [self favoriteNamed:@"Prod main" database:@"pgkit_io_dst"];
		SPPostgresFavorite *staging = [self favoriteNamed:@"Staging" database:@"pgkit_io_src"];
		SPPostgresFavorite *replica = [self favoriteNamed:@"prod replica" database:@"pgkit_io_src"];
		SPPostgresTransferController *controller = [self openSheetWithFavorites:@[prod, staging, replica]];
		XCTAssertEqualObjects(controller.favoriteFilterField.placeholderString, @"Filter");
		XCTAssertEqualObjects([self visibleTitles:controller.favoritePopup], (@[@"Prod main", @"Staging", @"prod replica"]));
		NSUInteger requests = self.targetRequests.count;

		// Case-insensitive, anywhere in the name; the choice and its session stay as they are
		[self typeFilter:@"PROD" in:controller.favoriteFilterField];
		XCTAssertEqualObjects([self visibleTitles:controller.favoritePopup], (@[@"Prod main", @"prod replica"]));
		[self typeFilter:@"ag" in:controller.favoriteFilterField];
		XCTAssertEqualObjects([self visibleTitles:controller.favoritePopup], (@[@"Staging"]));
		XCTAssertEqualObjects(controller.favoritePopup.titleOfSelectedItem, @"Prod main", @"the choice stays while typing");
		XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_dst");
		XCTAssertEqual(self.targetRequests.count, requests, @"no connection opened while typing");

		[self typeFilter:@"nothing like it" in:controller.favoriteFilterField];
		XCTAssertEqualObjects([self visibleTitles:controller.favoritePopup], (@[]));
		[self typeFilter:@"" in:controller.favoriteFilterField];
		XCTAssertEqualObjects([self visibleTitles:controller.favoritePopup], (@[@"Prod main", @"Staging", @"prod replica"]));

		// Choosing a match still opens its session
		[self typeFilter:@"replica" in:controller.favoriteFilterField];
		[self chooseFavorite:2 in:controller];
		[self waitForSession:controller];
		XCTAssertEqualObjects(controller.favoritePopup.titleOfSelectedItem, @"prod replica");
		XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_src");
	}];
}

- (void)testDatabaseFilterNarrowsTheMenu
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		SPPostgresFavorite *first = [self favoriteNamed:@"Test target" database:@"pgkit_io_dst"];
		SPPostgresFavorite *second = [self favoriteNamed:@"Other target" database:@"pgkit_io_src"];
		SPPostgresTransferController *controller = [self openSheetWithFavorites:@[first, second]];
		XCTAssertEqualObjects(controller.databaseFilterField.placeholderString, @"Filter");

		[self typeFilter:@"IO_SRC" in:controller.databaseFilterField];
		XCTAssertEqualObjects([self visibleTitles:controller.databasePopup], (@[@"pgkit_io_src", @"-", @"New Database…"]), @"New Database… stays");
		XCTAssertEqualObjects(controller.databasePopup.titleOfSelectedItem, @"pgkit_io_dst", @"the choice stays while typing");
		XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_dst");
		XCTAssertTrue(controller.transferButton.isEnabled);

		[self chooseDatabase:@"pgkit_io_src" in:controller];
		XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_src");

		// The databases of another favorite are filtered too
		[self chooseFavorite:1 in:controller];
		[self waitForSession:controller];
		XCTAssertEqualObjects([self visibleTitles:controller.databasePopup], (@[@"pgkit_io_src", @"-", @"New Database…"]));

		[self typeFilter:@"" in:controller.databaseFilterField];
		NSArray *all = [self visibleTitles:controller.databasePopup];
		XCTAssertTrue([all containsObject:@"pgkit_io_dst"], @"%@", all);
		XCTAssertEqualObjects(all, [self menuTitles:controller]);
	}];
}

#pragma mark - Empty mode's confirmation

- (void)testEmptyConfirmationNeedsExactName
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		SPPostgresTransferController *controller = [self openSheet];
		NSString *description = [NSString stringWithFormat:@"“Test target” (pgkit_test@127.0.0.1:%@)", port];
		NSAlert *alert = [controller emptyConfirmationAlertForDatabase:@"pgkit_io_dst" targetDescription:description];
		XCTAssertEqualObjects(alert.messageText, @"Empty “pgkit_io_dst” and transfer into it?");
		XCTAssertEqualObjects(alert.informativeText, ([NSString stringWithFormat:@"Everything in database “pgkit_io_dst” on %@ will be deleted: all schemas (including public), tables, views, functions, types and extensions. Other databases on that server aren't touched.\n\nType the database's name to confirm.", description]));
		XCTAssertTrue([alert.accessoryView isKindOfClass:[NSTextField class]]);
		NSTextField *field = (NSTextField *)alert.accessoryView;
		NSButton *button = alert.buttons.firstObject;
		XCTAssertEqualObjects(button.title, @"Empty and Transfer");
		XCTAssertTrue(button.hasDestructiveAction);
		XCTAssertEqualObjects(alert.buttons[1].title, @"Cancel");
		XCTAssertFalse(button.isEnabled, @"empty at first");
		for (NSString *text in @[@"", @"pgkit_io_ds", @"PGKIT_IO_DST", @"pgkit_io_dst ", @" pgkit_io_dst", @"pgkit_io_dstx"]) {
			field.stringValue = text;
			XCTAssertFalse(button.isEnabled, @"“%@”", text);
		}
		field.stringValue = @"pgkit_io_dst";
		XCTAssertTrue(button.isEnabled);
		// As typed (the field's text did change)
		field.stringValue = @"pgkit_io_ds";
		[field textDidChange:[NSNotification notificationWithName:NSTextDidChangeNotification object:[[NSTextView alloc] init]]];
		XCTAssertFalse(button.isEnabled);

		// Declined: nothing starts, no connection is asked for, the sheet stays
		__block NSUInteger asked = 0;
		__block NSString *askedDatabase = nil, *askedDescription = nil;
		controller.emptyConfirmation = ^(NSString *database, NSString *targetDescription, void (^answer)(BOOL)) {
			asked++;
			askedDatabase = database;
			askedDescription = targetDescription;
			answer(NO);
		};
		[controller transfer:nil];
		XCTAssertEqual(asked, 1u);
		XCTAssertEqualObjects(askedDatabase, @"pgkit_io_dst");
		XCTAssertEqualObjects(askedDescription, description);
		[self spinUntil:^BOOL{ return NO; } timeout:0.5];
		XCTAssertEqual(self.providedDatabases.count, 0u, @"no source connection");
		XCTAssertEqual(self.targetRequests.count, 1u, @"no target connection but the session");
		XCTAssertNil(controller.progressSheet);
		XCTAssertFalse(self.ended);
		XCTAssertEqual([self window].attachedSheet, controller.sheet);
		XCTAssertTrue(controller.transferButton.isEnabled);

		// Overwrite mode asks nothing
		asked = 0;
		[self click:controller.overwriteModeRadio];
		XCTAssertEqual(controller.emptyModeRadio.state, NSControlStateValueOff);
		XCTAssertEqual(asked, 0u);
	}];
}

/// Without the seam the alert is a sheet on the Transfer sheet; Cancel there starts nothing.
- (void)testConfirmationSheetCancelStartsNothing
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		SPPostgresTransferController *controller = [self openSheet];
		[controller transfer:nil];
		XCTAssertTrue([self spinUntil:^BOOL{ return controller.sheet.attachedSheet != nil; } timeout:5], @"the confirmation is a sheet on the Transfer sheet");
		XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
		NSWindow *alertWindow = controller.sheet.attachedSheet;
		[controller.sheet endSheet:alertWindow returnCode:NSAlertSecondButtonReturn];
		XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
		[self spinUntil:^BOOL{ return NO; } timeout:0.5];
		XCTAssertEqual(self.providedDatabases.count, 0u);
		XCTAssertEqual(self.targetRequests.count, 1u, @"the session only");
		XCTAssertFalse(self.ended);
		XCTAssertEqual([self window].attachedSheet, controller.sheet);
	}];
}

#pragma mark - Transfers

- (void)testWholeDatabaseTransferEndToEnd
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		[self addMarkerTo:target];
		SPPostgresTransferController *controller = [self openSheet];
		controller.emptyConfirmation = ^(NSString *database, NSString *targetDescription, void (^answer)(BOOL)) { answer(YES); };
		NSMutableArray *statuses = [NSMutableArray array];
		NSMutableArray *fractions = [NSMutableArray array];
		controller.progressObserver = ^(SPPostgresProgressSheet *sheet) {
			// On the job's thread, right after the status was set there
			NSString *status = [sheet valueForKey:@"pendingStatus"];
			@synchronized (statuses) {
				if (status && ![statuses.lastObject isEqualToString:status]) [statuses addObject:status];
				[fractions addObject:[sheet valueForKey:@"pendingFraction"]];
			}
		};
		[self transferWith:controller];

		XCTAssertNil(controller.lastErrorMessage);
		XCTAssertTrue([controller.completionNote hasPrefix:@"Copied"], @"%@", controller.completionNote);
		XCTAssertTrue([controller.completionNote containsString:@"Copied 5 tables to “pgkit_io_dst” on “Test target”."], @"%@", controller.completionNote);
		XCTAssertEqual(self.alerts.count, 1u);
		XCTAssertEqualObjects(self.alerts.firstObject.messageText, @"Transfer complete");
		XCTAssertEqualObjects(self.alerts.firstObject.informativeText, controller.completionNote);

		XCTAssertEqualObjects(self.providedDatabases, @[@"pgkit_io_src"]);
		XCTAssertEqualObjects(self.targetRequests, (@[@"Test target|(none)|pgkit_io_dst|session", @"Test target|(none)|pgkit_io_dst|token 1"]), @"through the session");
		for (PGPostgresConnection *provided in self.providedConnections) XCTAssertFalse(provided.isConnected, @"the job's connections and the session are closed");
		[self assertTemporaryDirectoryEmpty];

		PGPostgresConnection *source = [SPPostgresTestServers connectedConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_src"];
		[self.openConnections addObject:source];
		NSDictionary *expected = [self rowsOf:source];
		XCTAssertGreaterThan(expected.count, 3u);
		XCTAssertEqualObjects([self rowsOf:target], expected, @"port %@", port);
		XCTAssertEqualObjects([self value:@"SELECT (to_regclass('public.marker') IS NULL)::text" on:target], @"true", @"emptied first");

		XCTAssertEqualObjects(statuses.firstObject, @"Checking the target…", @"%@", statuses);
		// Every table the dump reads, the partitioned parent public.events included
		XCTAssertEqual([[statuses filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF MATCHES 'Reading table 1 of 6: .+'"]] count], 1u, @"%@", statuses);
		XCTAssertEqual([[statuses filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF MATCHES 'Reading table 6 of 6: .+'"]] count], 1u, @"%@", statuses);
		XCTAssertEqualObjects(statuses.lastObject, @"Writing to “pgkit_io_dst”…", @"%@", statuses);
		for (NSNumber *fraction in fractions) XCTAssertTrue(fraction.doubleValue >= 0 && fraction.doubleValue <= 1);
		XCTAssertEqualWithAccuracy([fractions.lastObject doubleValue], 1.0, 0.001);
	}];
}

- (void)testSelectedTablesOverwriteEndToEnd
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		[self addMarkerTo:target];
		SPPostgresTransferController *controller = [self openSheet];
		controller.emptyConfirmation = ^(NSString *database, NSString *targetDescription, void (^answer)(BOOL)) {
			XCTFail(@"Overwrite isn't confirmed");
			answer(NO);
		};
		[self click:controller.selectedTablesRadio];
		[self uncheckAll:controller];
		// order_lines references "Orders 2026": both go
		[controller.tablesList setChecked:YES item:@[@"Sales Data", @"Orders 2026"]];
		[controller.tablesList setChecked:YES item:@[@"Sales Data", @"order_lines"]];
		[self click:controller.overwriteModeRadio];
		[self transferWith:controller];

		XCTAssertNil(controller.lastErrorMessage);
		XCTAssertTrue([controller.completionNote hasPrefix:@"Copied 2 tables to “pgkit_io_dst” on “Test target”.\n\nAlso created, as the tables need them: "], @"%@", controller.completionNote);
		XCTAssertTrue([controller.completionNote containsString:@"type public.mood"], @"%@", controller.completionNote);
		XCTAssertEqualObjects(self.targetRequests, (@[@"Test target|(none)|pgkit_io_dst|session", @"Test target|(none)|pgkit_io_dst|token 1"]));
		XCTAssertEqualObjects([self value:@"SELECT string_agg(note, ',') FROM public.marker" on:target], @"still here", @"left alone");
		PGPostgresConnection *source = [SPPostgresTestServers connectedConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_src"];
		[self.openConnections addObject:source];
		NSDictionary *expected = [self rowsOf:source], *actual = [self rowsOf:target];
		for (NSString *key in @[@"rows \"Sales Data\".\"Orders 2026\"", @"rows \"Sales Data\".order_lines"]) {
			XCTAssertNotNil(expected[key], @"%@", key);
			XCTAssertEqualObjects(actual[key], expected[key], @"port %@: %@", port, key);
		}
		[self assertTemporaryDirectoryEmpty];
	}];
}

/// The default targetConnect (no seam): the session is a connector with the Keychain's password (a stand-in here:
/// SPKeychain's lookup is replaced, so the real Keychain is never read) on the Transfer sheet; the transfer's
/// connection shares it (its password, no parent window, no second Keychain read).
- (void)testDefaultTargetConnectUsesTheSession
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		Class keychainClass = NSClassFromString(@"SPKeychain");
		XCTAssertNotNil(keychainClass);
		Method lookup = class_getInstanceMethod(keychainClass, NSSelectorFromString(@"getPasswordForName:account:"));
		__block NSUInteger lookups = 0;
		IMP original = method_setImplementation(lookup, imp_implementationWithBlock(^NSString *(id me, NSString *name, NSString *account) {
			lookups++;
			return @"pgkit";
		}));
		@try {
			SPPostgresTransferController *controller = [[SPPostgresTransferController alloc] initWithDocument:self.document];
			self.controller = controller;
			self.ended = NO;
			[self configure:controller favorites:nil];
			controller.targetConnect = nil;
			controller.emptyConfirmation = ^(NSString *database, NSString *targetDescription, void (^answer)(BOOL)) { answer(YES); };
			[controller beginSheet];
			[self waitForSession:controller];
			XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_dst", @"%@", controller.targetStatusField.stringValue);
			XCTAssertEqual(lookups, 1u, @"the Keychain's password, read as the session connects");
			XCTAssertTrue([[self menuTitles:controller] containsObject:@"pgkit_io_src"]);

			[controller transfer:nil];
			XCTAssertNotNil(controller.progressSheet);
			SPPostgresConnector *connector = controller.pendingConnector;
			XCTAssertNotNil(connector, @"the transfer's connection is connecting");
			XCTAssertEqualObjects(connector.password, @"pgkit", @"the session's password");
			XCTAssertNil(connector.parentWindow);
			XCTAssertTrue([self spinUntil:^BOOL{ return self.ended && [self window].attachedSheet == nil; } timeout:120]);
			XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
			XCTAssertNil(controller.lastErrorMessage);
			XCTAssertNil(controller.pendingConnector);
			XCTAssertTrue([controller.completionNote hasPrefix:@"Copied 5 tables"], @"%@", controller.completionNote);
			XCTAssertEqualObjects(self.providedDatabases, @[@"pgkit_io_src"]);
			XCTAssertEqual(lookups, 1u, @"no second Keychain read");
		}
		@finally {
			method_setImplementation(lookup, original);
		}
	}];
}

- (void)testOverwriteBlockedShowsWhatIsInTheWay
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		// An older copy of "Orders 2026" on the target, a view over it and a table referencing it
		PGPostgresConnection *source = [SPPostgresTestServers connectedConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_src"];
		[self.openConnections addObject:source];
		SPPostgresTransfer *earlier = [[SPPostgresTransfer alloc] initWithSource:source target:target];
		earlier.temporaryDirectory = self.directory;
		earlier.tables = @[@[@"Sales Data", @"Orders 2026"]];
		NSError *error = nil;
		XCTAssertTrue([earlier run:&error], @"%@", error.localizedDescription);
		[self run:@"RESET search_path" on:target];
		[self run:@"CREATE VIEW public.report AS SELECT id FROM \"Sales Data\".\"Orders 2026\"" on:target];
		[self run:@"CREATE TABLE public.refs (order_id int REFERENCES \"Sales Data\".\"Orders 2026\" (id))" on:target];
		NSDictionary *before = [self rowsOf:target];

		SPPostgresTransferController *controller = [self openSheet];
		[self click:controller.selectedTablesRadio];
		[self uncheckAll:controller];
		[controller.tablesList setChecked:YES item:@[@"Sales Data", @"Orders 2026"]];
		[self click:controller.overwriteModeRadio];
		[self transferWith:controller];

		XCTAssertNil(controller.completionNote);
		XCTAssertTrue([controller.lastErrorMessage containsString:@"wasn't changed"], @"%@", controller.lastErrorMessage);
		XCTAssertTrue([controller.lastErrorMessage containsString:@"“pgkit_io_dst” on “Test target”"], @"%@", controller.lastErrorMessage);
		XCTAssertTrue([controller.lastErrorMessage containsString:@"public.report"], @"%@", controller.lastErrorMessage);
		XCTAssertTrue([controller.lastErrorMessage containsString:@"public.refs"], @"%@", controller.lastErrorMessage);
		XCTAssertEqual(self.alerts.count, 1u);
		XCTAssertEqualObjects(self.alerts.firstObject.messageText, @"The transfer failed. “pgkit_io_dst” on “Test target” wasn't changed.");
		XCTAssertTrue([self.alerts.firstObject.informativeText containsString:@"public.report"]);
		XCTAssertEqualObjects([self rowsOf:target], before);
		[self assertTemporaryDirectoryEmpty];
	}];
}

- (void)testCancelDuringTransfer
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		[self addMarkerTo:target];
		NSDictionary *before = [self rowsOf:target];
		SPPostgresTransferController *controller = [self openSheet];
		controller.emptyConfirmation = ^(NSString *database, NSString *targetDescription, void (^answer)(BOOL)) { answer(YES); };
		__block BOOL cancelledWhileReading = NO;
		__block SPPostgresProgressSheet *seen = nil;
		controller.progressObserver = ^(SPPostgresProgressSheet *sheet) {
			NSString *status = [sheet valueForKey:@"pendingStatus"];
			if (!cancelledWhileReading && [status hasPrefix:@"Reading table "]) {
				cancelledWhileReading = YES;
				seen = sheet;
				[sheet cancel:nil];
			}
		};
		[self transferWith:controller];

		XCTAssertTrue(cancelledWhileReading);
		XCTAssertTrue(seen.cancelled);
		XCTAssertNil(seen.panel.sheetParent, @"the progress sheet ended");
		XCTAssertEqualObjects(controller.lastErrorMessage, @"The transfer was cancelled.");
		XCTAssertNil(controller.completionNote);
		XCTAssertEqual(self.alerts.count, 0u, @"a cancel isn't an error");
		XCTAssertEqualObjects([self rowsOf:target], before, @"the target is unchanged");
		XCTAssertEqualObjects([self value:@"SELECT string_agg(note, ',') FROM public.marker" on:target], @"still here");
		[self assertTemporaryDirectoryEmpty];
	}];
}

/// Cancel right after Transfer, before the Transfer sheet's completion handler could have run: the job never starts
/// (when the progress sheet hasn't begun yet) and the controller ends cleanly.
- (void)testCancelRightAfterTransferEndsCleanly
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		__weak SPPostgresTransferController *weakController = nil;
		@autoreleasepool {
			SPPostgresTransferController *controller = [self openSheet];
			weakController = controller;
			controller.emptyConfirmation = ^(NSString *database, NSString *targetDescription, void (^answer)(BOOL)) { answer(YES); };
			[controller transfer:nil];
			BOOL progressBegan = controller.progressSheet != nil;
			[controller cancel:nil];
			if (!progressBegan) XCTAssertEqual(self.targetRequests.count, 1u, @"no transfer connection asked for");
			self.controller = nil;
		}
		XCTAssertTrue([self spinUntil:^BOOL{ return self.ended && [self window].attachedSheet == nil; } timeout:30]);
		XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
		XCTAssertNil([self window].attachedSheet, @"no progress sheet attached");
		XCTAssertTrue([self spinUntil:^BOOL{ @autoreleasepool { return weakController == nil; } } timeout:10], @"the controller deallocates");
		XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	}];
}

- (void)testControllerDeallocatesAfterCancel
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		__weak SPPostgresTransferController *weakController = nil;
		@autoreleasepool {
			SPPostgresTransferController *controller = [self openSheet];
			weakController = controller;
			[self click:controller.selectedTablesRadio];
			[controller cancel:nil];
			self.controller = nil;
		}
		XCTAssertTrue([self spinUntil:^BOOL{ return self.ended && [self window].attachedSheet == nil; } timeout:5]);
		XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
		XCTAssertTrue([self spinUntil:^BOOL{ @autoreleasepool { return weakController == nil; } } timeout:5], @"no retain cycle through stored blocks");
		XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	}];
}

- (void)testControllerDeallocatesAfterTransfer
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		__weak SPPostgresTransferController *weakController = nil;
		@autoreleasepool {
			SPPostgresTransferController *controller = [self openSheet];
			weakController = controller;
			[self click:controller.overwriteModeRadio];
			[self transferWith:controller];
			XCTAssertNil(controller.lastErrorMessage);
			self.controller = nil;
		}
		XCTAssertTrue([self spinUntil:^BOOL{ @autoreleasepool { return weakController == nil; } } timeout:5], @"no retain cycle through stored blocks");
		XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	}];
}

#pragma mark - The target database menu

- (void)testMenuListsTargetDatabases
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		SPPostgresTransferController *controller = [self openSheet];
		NSArray *titles = [self menuTitles:controller];
		XCTAssertTrue([titles containsObject:@"pgkit_io_src"], @"%@", titles);
		XCTAssertTrue([titles containsObject:@"pgkit_io_dst"], @"%@", titles);
		XCTAssertFalse([titles containsObject:@"template0"], @"%@", titles);
		XCTAssertFalse([titles containsObject:@"template1"], @"%@", titles);
		XCTAssertEqualObjects(titles.lastObject, @"New Database…");
		XCTAssertEqualObjects(titles[titles.count - 2], @"-", @"a separator before New Database…");
		NSArray *names = [titles subarrayWithRange:NSMakeRange(0, titles.count - 2)];
		XCTAssertEqualObjects(names, [names sortedArrayUsingSelector:@selector(compare:)], @"by name");
		XCTAssertEqualObjects(controller.databasePopup.titleOfSelectedItem, @"pgkit_io_dst");
		XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_dst");
		XCTAssertTrue(controller.transferButton.isEnabled);

		// Another database chosen: it is the target
		[self chooseDatabase:@"pgkit_io_src" in:controller];
		XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_src");
		XCTAssertTrue(controller.transferButton.isEnabled);
	}];
}

- (void)testConnectingAndFailureStates
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		self.heldConnects = [NSMutableArray array];
		SPPostgresTransferController *controller = [self openSheet];
		XCTAssertEqualObjects([self menuTitles:controller], @[@"Connecting…"]);
		XCTAssertFalse(controller.databasePopup.itemArray.firstObject.isEnabled);
		XCTAssertNil(controller.selectedDatabase);
		XCTAssertFalse(controller.transferButton.isEnabled);
		XCTAssertTrue(controller.retryButton.isHidden);
		[controller transfer:nil];
		XCTAssertNil(controller.progressSheet, @"nothing to transfer into yet");

		// It fails: one retry on postgres, which fails too
		self.failConnects = YES;
		[self answerHeld:0];
		XCTAssertEqualObjects(self.targetRequests, (@[@"Test target|(none)|pgkit_io_dst|session", @"Test target|(none)|postgres|session"]));
		[self answerHeld:1];
		XCTAssertEqualObjects([self menuTitles:controller], @[@"Not connected"]);
		XCTAssertFalse(controller.databasePopup.itemArray.firstObject.isEnabled);
		XCTAssertTrue([controller.targetStatusField.stringValue containsString:@"test: could not connect"], @"%@", controller.targetStatusField.stringValue);
		XCTAssertFalse(controller.retryButton.isHidden);
		XCTAssertFalse(controller.transferButton.isEnabled);
		XCTAssertNil(controller.selectedDatabase);

		// Retry connects again
		self.failConnects = NO;
		self.heldConnects = nil;
		// (-performClick: may run the run loop, which would answer already)
		XCTAssertTrue(controller.retryButton.isEnabled);
		[NSApp sendAction:controller.retryButton.action to:controller.retryButton.target from:controller.retryButton];
		XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
		XCTAssertEqualObjects([self menuTitles:controller], @[@"Connecting…"]);
		XCTAssertTrue(controller.retryButton.isHidden);
		[self waitForSession:controller];
		XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_dst");
		XCTAssertEqualObjects(controller.targetStatusField.stringValue, @"");
		XCTAssertTrue(controller.transferButton.isEnabled);
		XCTAssertEqual(self.targetRequests.count, 3u);
	}];
}

/// The favorite's database isn't listed (it has none, or it is gone and the session fell back to postgres): nothing is
/// chosen for the user, Transfer stays disabled (in either mode) until a database is picked.
- (void)testUnlistedFavoriteDatabaseSelectsNothing
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		SPPostgresTransferController *controller = [[SPPostgresTransferController alloc] initWithDocument:self.document];
		self.controller = controller;
		self.ended = NO;
		SPPostgresFavorite *none = [self favoriteNamed:@"No database" database:@""];
		SPPostgresFavorite *gone = [self favoriteNamed:@"Gone" database:@"sp_t7_gone"];
		[self configure:controller favorites:@[none, gone]];
		// The tests never touch postgres: the session's fallback lands on pgkit_io_dst instead (it only lists names)
		void (^connect)(SPPostgresFavorite *, NSString *, NSString *, id, void (^)(PGPostgresConnection *, id, NSError *)) = controller.targetConnect;
		// and sp_t7_gone fails as a missing database does
		NSMutableArray *requests = self.targetRequests;
		controller.targetConnect = ^(SPPostgresFavorite *favorite, NSString *database, NSString *password, id sessionToken, void (^completion)(PGPostgresConnection *, id, NSError *)) {
			if ([database isEqualToString:@"sp_t7_gone"]) {
				[requests addObject:[NSString stringWithFormat:@"%@|(none)|%@|session", favorite.name, database]];
				dispatch_async(dispatch_get_main_queue(), ^{
					completion(nil, nil, SPPostgresMakeError(SPPostgresErrorConnectionFailed, @"database \"sp_t7_gone\" does not exist", nil));
				});
				return;
			}
			connect(favorite, [database isEqualToString:@"postgres"] ? @"pgkit_io_dst" : database, password, sessionToken, completion);
		};
		[controller beginSheet];
		[self waitForSession:controller];
		XCTAssertEqualObjects(self.targetRequests, (@[@"No database|(none)|pgkit_io_dst|session"]), @"postgres, as pgkit_io_dst");

		for (NSUInteger index = 0; index < 2; index++) {
			if (index == 1) {
				// sp_t7_gone doesn't exist: one retry on postgres
				[self chooseFavorite:1 in:controller];
				[self waitForSession:controller];
				XCTAssertEqualObjects([self.targetRequests subarrayWithRange:NSMakeRange(1, self.targetRequests.count - 1)], (@[@"Gone|(none)|sp_t7_gone|session", @"Gone|(none)|pgkit_io_dst|session"]));
			}
			NSArray *titles = [self menuTitles:controller];
			XCTAssertTrue([titles containsObject:@"pgkit_io_dst"], @"%@", titles);
			XCTAssertEqualObjects(titles.lastObject, @"New Database…");
			XCTAssertNil(controller.selectedDatabase, @"no database chosen for the user");
			XCTAssertEqual(controller.databasePopup.indexOfSelectedItem, -1, @"no item selected");
			XCTAssertFalse(controller.transferButton.isEnabled);
			[NSApp sendAction:controller.overwriteModeRadio.action to:controller.overwriteModeRadio.target from:controller.overwriteModeRadio];
			XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
			XCTAssertFalse(controller.transferButton.isEnabled, @"Overwrite mode too");
			NSUInteger requests = self.targetRequests.count;
			[controller transfer:nil];
			XCTAssertNil(controller.progressSheet, @"nothing to transfer into");
			XCTAssertEqual(self.targetRequests.count, requests);
			[NSApp sendAction:controller.emptyModeRadio.action to:controller.emptyModeRadio.target from:controller.emptyModeRadio];
			XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);

			// Picked: it is the target
			[self chooseDatabase:@"pgkit_io_dst" in:controller];
			XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_dst");
			XCTAssertTrue(controller.transferButton.isEnabled);
		}
	}];
}

/// Favorite A's connect answers after B was chosen: its connection is closed, the menu is B's.
- (void)testSwitchingFavoriteIgnoresLateResult
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		self.heldConnects = [NSMutableArray array];
		SPPostgresFavorite *a = [self favoriteNamed:@"A" database:@"pgkit_io_dst"];
		SPPostgresFavorite *b = [self favoriteNamed:@"B" database:@"pgkit_io_src"];
		SPPostgresTransferController *controller = [self openSheetWithFavorites:@[a, b]];
		[self chooseFavorite:1 in:controller];
		XCTAssertEqualObjects([self menuTitles:controller], @[@"Connecting…"]);
		XCTAssertEqualObjects(self.targetRequests, (@[@"A|(none)|pgkit_io_dst|session", @"B|(none)|pgkit_io_src|session"]));

		[self answerHeld:1];
		XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_src");
		NSArray *titles = [self menuTitles:controller];
		[self answerHeld:0];
		XCTAssertEqual(self.sessionConnections.count, 2u);
		PGPostgresConnection *late = self.sessionConnections[1];
		XCTAssertFalse(late.isConnected, @"A's late connection is closed");
		XCTAssertTrue(self.sessionConnections[0].isConnected, @"B's session stays");
		XCTAssertEqualObjects([self menuTitles:controller], titles);
		XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_src");
		XCTAssertTrue(controller.transferButton.isEnabled);
		XCTAssertEqual(self.targetRequests.count, 2u, @"no retry for the late one");
	}];
}

/// A wrong (no) password, then the right one: one prompt; the transfer uses it through the session without asking.
- (void)testPasswordPromptThenTransfer
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		self.requiredPassword = @"pgkit";
		__block NSUInteger prompts = 0;
		__block SPPostgresFavorite *prompted = nil;
		SPPostgresTransferController *controller = [[SPPostgresTransferController alloc] initWithDocument:self.document];
		self.controller = controller;
		self.ended = NO;
		[self configure:controller favorites:nil];
		controller.passwordPrompt = ^(SPPostgresFavorite *favorite, void (^answer)(NSString *)) {
			prompts++;
			prompted = favorite;
			answer(@"pgkit");
		};
		controller.emptyConfirmation = ^(NSString *database, NSString *targetDescription, void (^answer)(BOOL)) { answer(YES); };
		[controller beginSheet];
		[self waitForSession:controller];
		XCTAssertEqual(prompts, 1u);
		XCTAssertEqualObjects(prompted.name, @"Test target");
		XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_dst", @"%@", controller.targetStatusField.stringValue);
		XCTAssertEqualObjects(self.targetRequests, (@[@"Test target|(none)|pgkit_io_dst|session", @"Test target|pgkit|pgkit_io_dst|session"]), @"no retry on postgres for a password");

		[self transferWith:controller];
		XCTAssertNil(controller.lastErrorMessage);
		XCTAssertTrue([controller.completionNote hasPrefix:@"Copied 5 tables"], @"%@", controller.completionNote);
		XCTAssertEqual(prompts, 1u, @"asked once");
		XCTAssertEqualObjects(self.targetRequests.lastObject, ([NSString stringWithFormat:@"Test target|pgkit|pgkit_io_dst|%@", self.sessionTokens.lastObject]));
		XCTAssertEqual(self.targetRequests.count, 3u);
		XCTAssertFalse(self.sessionConnections.lastObject.isConnected, @"the session closes when the controller ends");
		self.requiredPassword = nil;
	}];
}

/// Cancel at the password prompt: not connected, Retry asks again.
- (void)testPasswordPromptCancel
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		self.requiredPassword = @"pgkit";
		SPPostgresTransferController *controller = [[SPPostgresTransferController alloc] initWithDocument:self.document];
		self.controller = controller;
		self.ended = NO;
		[self configure:controller favorites:nil];
		__block NSString *reply = nil;
		__block NSUInteger prompts = 0;
		controller.passwordPrompt = ^(SPPostgresFavorite *favorite, void (^answer)(NSString *)) { prompts++; answer(reply); };
		[controller beginSheet];
		[self waitForSession:controller];
		XCTAssertEqual(prompts, 1u);
		XCTAssertEqualObjects([self menuTitles:controller], @[@"Not connected"]);
		XCTAssertTrue([controller.targetStatusField.stringValue containsString:@"password authentication failed"], @"%@", controller.targetStatusField.stringValue);
		XCTAssertFalse(controller.retryButton.isHidden);
		reply = @"pgkit";
		[self click:controller.retryButton];
		[self waitForSession:controller];
		XCTAssertEqual(prompts, 2u);
		XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_dst");
		self.requiredPassword = nil;

		// The default prompt
		NSAlert *alert = [controller passwordAlertForFavorite:[self favoriteNamed:@"Test target" database:@"pgkit_io_dst"]];
		XCTAssertEqualObjects(alert.messageText, @"Password for pgkit_test on “Test target”");
		XCTAssertTrue([alert.accessoryView isKindOfClass:[NSSecureTextField class]]);
		XCTAssertEqualObjects(alert.buttons[0].title, @"Connect");
		XCTAssertEqualObjects(alert.buttons[1].title, @"Cancel");
	}];
}

#pragma mark - New Database…

- (void)testNewDatabaseCreatesAndSelects
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		SPPostgresTransferController *controller = [self openSheet];
		__block NSUInteger prompts = 0;
		controller.newDatabasePrompt = ^(SPPostgresFavorite *favorite, void (^answer)(NSString *)) {
			prompts++;
			XCTAssertEqualObjects(favorite.name, @"Test target");
			answer(@"sp_t7_made");
		};
		controller.emptyConfirmation = ^(NSString *database, NSString *targetDescription, void (^answer)(BOOL)) {
			XCTFail(@"a database created in this sheet isn't confirmed");
			answer(NO);
		};
		[self chooseDatabase:@"New Database…" in:controller];
		XCTAssertEqual(prompts, 1u);
		XCTAssertEqualObjects(controller.selectedDatabase, @"sp_t7_made");
		XCTAssertEqualObjects(controller.databasePopup.titleOfSelectedItem, @"sp_t7_made");
		NSArray *titles = [self menuTitles:controller];
		XCTAssertTrue([titles containsObject:@"sp_t7_made"], @"%@", titles);
		XCTAssertEqualObjects(titles.lastObject, @"New Database…");
		XCTAssertEqual(self.alerts.count, 0u);

		[self transferWith:controller];
		XCTAssertNil(controller.lastErrorMessage);
		XCTAssertTrue([controller.completionNote containsString:@"Copied 5 tables to “sp_t7_made” on “Test target”."], @"%@", controller.completionNote);
		PGPostgresConnection *made = [SPPostgresTestServers connectedConnectionOnPort:port.unsignedIntegerValue database:@"sp_t7_made"];
		[self.openConnections addObject:made];
		PGPostgresConnection *source = [SPPostgresTestServers connectedConnectionOnPort:port.unsignedIntegerValue database:@"pgkit_io_src"];
		[self.openConnections addObject:source];
		NSDictionary *expected = [self rowsOf:source];
		XCTAssertGreaterThan(expected.count, 3u);
		XCTAssertEqualObjects([self rowsOf:made], expected, @"port %@", port);
		[made disconnect];
		[self assertTemporaryDirectoryEmpty];
	}];
}

/// A name that exists: the server's error, the selection back, nothing created.
- (void)testNewDatabaseExistingNameShowsError
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		SPPostgresTransferController *controller = [self openSheet];
		NSArray *before = [self menuTitles:controller];
		controller.newDatabasePrompt = ^(SPPostgresFavorite *favorite, void (^answer)(NSString *)) { answer(@"pgkit_io_dst"); };
		[self chooseDatabase:@"New Database…" in:controller];
		XCTAssertEqual(self.alerts.count, 1u);
		XCTAssertEqualObjects(self.alerts.firstObject.messageText, @"“pgkit_io_dst” couldn't be created on “Test target”");
		XCTAssertTrue([self.alerts.firstObject.informativeText containsString:@"already exists"], @"%@", self.alerts.firstObject.informativeText);
		XCTAssertEqualObjects(controller.databasePopup.titleOfSelectedItem, @"pgkit_io_dst");
		XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_dst");
		XCTAssertEqualObjects([self menuTitles:controller], before);
		XCTAssertTrue(controller.transferButton.isEnabled);
		// Still a database the sheet didn't create: Empty mode asks
		__block NSUInteger asked = 0;
		controller.emptyConfirmation = ^(NSString *database, NSString *targetDescription, void (^answer)(BOOL)) { asked++; answer(NO); };
		[controller transfer:nil];
		XCTAssertEqual(asked, 1u);
	}];
}

- (void)testNewDatabaseCancelRestoresSelection
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		SPPostgresTransferController *controller = [self openSheet];
		NSArray *before = [self menuTitles:controller];
		[self chooseDatabase:@"pgkit_io_src" in:controller];
		controller.newDatabasePrompt = ^(SPPostgresFavorite *favorite, void (^answer)(NSString *)) { answer(nil); };
		[self chooseDatabase:@"New Database…" in:controller];
		XCTAssertEqualObjects(controller.databasePopup.titleOfSelectedItem, @"pgkit_io_src");
		XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_src");
		XCTAssertEqualObjects([self menuTitles:controller], before);
		XCTAssertEqual(self.alerts.count, 0u);

		// The default prompt: a sheet on the Transfer sheet; Cancel there restores the selection too
		controller.newDatabasePrompt = nil;
		[self chooseDatabase:@"New Database…" in:controller];
		XCTAssertTrue([self spinUntil:^BOOL{ return controller.sheet.attachedSheet != nil; } timeout:5]);
		XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
		[controller.sheet endSheet:controller.sheet.attachedSheet returnCode:NSAlertSecondButtonReturn];
		XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
		[self spinUntil:^BOOL{ return controller.sheet.attachedSheet == nil; } timeout:5];
		XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_src");
		XCTAssertEqualObjects(controller.databasePopup.titleOfSelectedItem, @"pgkit_io_src");

		// Its Create button: a name of 1 to 63 bytes in UTF-8, sent as typed
		NSAlert *alert = [controller createDatabaseAlertForFavorite:[self favoriteNamed:@"Test target" database:@"pgkit_io_dst"]];
		XCTAssertEqualObjects(alert.messageText, @"New database on “Test target”");
		XCTAssertEqualObjects(alert.buttons[0].title, @"Create");
		XCTAssertEqualObjects(alert.buttons[1].title, @"Cancel");
		NSTextField *field = (NSTextField *)alert.accessoryView;
		XCTAssertTrue([field isKindOfClass:[NSTextField class]]);
		NSButton *create = alert.buttons[0];
		XCTAssertFalse(create.isEnabled);
		NSString *e = @"é";
		NSDictionary<NSString *, NSNumber *> *cases = @{
			@"": @NO, @"a": @YES, @"a b": @YES,
			// Whitespace around the name (or only whitespace): never trimmed silently, so not accepted
			@" ": @NO, @"\t": @NO, @" a": @NO, @"a ": @NO, @"a\n": @NO, @"\u00A0a": @NO,
			[@"" stringByPaddingToLength:63 withString:@"x" startingAtIndex:0]: @YES,
			[@"" stringByPaddingToLength:64 withString:@"x" startingAtIndex:0]: @NO,
			[[@"" stringByPaddingToLength:31 withString:e startingAtIndex:0] stringByAppendingString:@"x"]: @YES,
			[@"" stringByPaddingToLength:32 withString:e startingAtIndex:0]: @NO,
		};
		for (NSString *name in cases) {
			field.stringValue = name;
			XCTAssertEqual(create.isEnabled, cases[name].boolValue, @"“%@”", name);
		}
	}];
}

/// Closing the tab while the sheet's session is connected closes the session.
- (void)testTeardownClosesSession
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		// The document opens the sheet; the test's seams are set as it begins
		Method begin = class_getInstanceMethod([SPPostgresTransferController class], @selector(beginSheet));
		IMP original = method_getImplementation(begin);
		__weak SPPostgresTransferControllerTests *weakSelf = self;
		method_setImplementation(begin, imp_implementationWithBlock(^(SPPostgresTransferController *me) {
			void (^documentDidEnd)(void) = me.didEnd;
			[weakSelf configure:me favorites:nil];
			me.didEnd = ^{ weakSelf.ended = YES; if (documentDidEnd) documentDidEnd(); };
			((void (*)(id, SEL))original)(me, @selector(beginSheet));
		}));
		@try {
			self.ended = NO;
			[self.document showTransfer:nil];
		}
		@finally {
			method_setImplementation(begin, original);
		}
		SPPostgresTransferController *controller = self.document.transferController;
		XCTAssertNotNil(controller);
		[self waitForSession:controller];
		XCTAssertEqualObjects(controller.selectedDatabase, @"pgkit_io_dst");
		PGPostgresConnection *session = self.sessionConnections.firstObject;
		XCTAssertTrue(session.isConnected);
		controller = nil;

		NSTabView *tabView = [self.windowController valueForKey:@"tabView"];
		[tabView removeTabViewItem:self.document.parentTabViewItem];
		XCTAssertTrue([self spinUntil:^BOOL{ return self.ended; } timeout:5]);
		XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
		XCTAssertFalse(session.isConnected, @"the session is closed");
		XCTAssertNil(self.document.transferController);
	}];
}

/// Cancel (e.g. the tab closing) while the session's SSH password or host-key sheet is up on the Transfer sheet: the
/// sheet is answered as Cancel/No through its own action (the tunnel's worker waits for that answer), and every sheet
/// ends.
- (void)testCancelAnswersTheTunnelsSheet
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		for (NSString *kind in @[@"password", @"question"]) {
			self.heldConnects = [NSMutableArray array]; // still connecting, as while the tunnel asks
			SPPostgresTransferController *controller = [self openSheet];
			SPTestTunnelSheetOwner *tunnel = [[SPTestTunnelSheetOwner alloc] init];
			XCTAssertNotNil(tunnel);
			NSWindow *dialog = [kind isEqualToString:@"password"] ? tunnel.sshPasswordDialog : tunnel.sshQuestionDialog;
			XCTAssertNotNil(dialog);
			[tunnel show:dialog on:controller.sheet];
			XCTAssertTrue([self spinUntil:^BOOL{ return controller.sheet.attachedSheet == dialog; } timeout:5]);
			XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);

			[controller cancel:nil];
			XCTAssertEqualObjects(tunnel.answers, (@[[kind stringByAppendingString:@" no"]]), @"answered once, as Cancel/No");
			XCTAssertTrue([self spinUntil:^BOOL{ return self.ended && controller.sheet.attachedSheet == nil && [self window].attachedSheet == nil; } timeout:5]);
			XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
			XCTAssertFalse(dialog.isVisible);
			self.controller = nil;
			self.heldConnects = nil;
		}
	}];
}

#pragma mark - The toolbar item

- (void)testToolbarTransferItemEnabledOnPostgresTab
{
	[self onEachPort:^(NSNumber *port, PGPostgresConnection *target) {
		NSToolbar *toolbar = [self.document toolbar];
		NSToolbarItem *item = [self.document toolbar:toolbar itemForItemIdentifier:SPTestTransferIdentifier willBeInsertedIntoToolbar:NO];
		XCTAssertNotNil(item);
		XCTAssertFalse([item isKindOfClass:[SPDisabledToolbarItem class]]);
		XCTAssertEqualObjects(item.label, @"Transfer");
		XCTAssertNotNil(item.image);
		XCTAssertEqual(item.target, self.document);
		XCTAssertEqual(item.action, NSSelectorFromString(@"showTransfer:"));
		XCTAssertTrue([self.document respondsToSelector:NSSelectorFromString(@"showTransfer:")]);
		XCTAssertTrue([self.document validateToolbarItem:item], @"connected, no sheet");
		NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:@"Transfer…" action:NSSelectorFromString(@"showTransfer:") keyEquivalent:@""];
		XCTAssertTrue([self.document validateMenuItem:menuItem]);

		// The one in the window's toolbar is the same kind
		NSToolbarItem *inToolbar = nil;
		for (NSToolbarItem *candidate in toolbar.items) if ([candidate.itemIdentifier isEqualToString:SPTestTransferIdentifier]) inToolbar = candidate;
		XCTAssertNotNil(inToolbar);
		XCTAssertFalse([inToolbar isKindOfClass:[SPDisabledToolbarItem class]]);
		XCTAssertEqual(inToolbar.action, NSSelectorFromString(@"showTransfer:"));

		// Not while Export is up
		[self.document export:nil];
		XCTAssertNotNil(self.document.exportController);
		XCTAssertFalse([self.document validateToolbarItem:item]);
		XCTAssertFalse([self.document validateMenuItem:menuItem]);
		[self.document.exportController cancel:nil];
		XCTAssertTrue([self spinUntil:^BOOL{ return self.document.exportController == nil && [self window].attachedSheet == nil; } timeout:5]);
		XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
		XCTAssertTrue([self.document validateToolbarItem:item]);
		XCTAssertFalse(item.isBordered, @"as MySQL's");

		// Clicking it opens the Transfer sheet (the favorites come from a test-owned in-memory store, never the real tree)
		SPPostgresFavoritesStore *store = [[SPPostgresFavoritesStore alloc] initInMemory];
		Method shared = class_getClassMethod([SPPostgresFavoritesStore class], @selector(sharedStore));
		IMP original = method_setImplementation(shared, imp_implementationWithBlock(^id(id me) { return store; }));
		@try {
			XCTAssertTrue([NSApp sendAction:inToolbar.action to:inToolbar.target from:inToolbar]);
			SPPostgresTransferController *opened = self.document.transferController;
			XCTAssertNotNil(opened);
			XCTAssertEqual([self window].attachedSheet, opened.sheet);
			XCTAssertEqualObjects(opened.favorites, @[]);
			XCTAssertFalse([self.document validateToolbarItem:item], @"not while Transfer is up");
			[opened cancel:nil];
			XCTAssertTrue([self spinUntil:^BOOL{ return self.document.transferController == nil && [self window].attachedSheet == nil; } timeout:5]);
			XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
		}
		@finally {
			method_setImplementation(shared, original);
		}
	}];

	// MySQL's Transfer item stays a never-enabled SPDisabledToolbarItem
	SPWindowController *windowController = [[SPWindowController alloc] initWithWindowNibName:@"MainWindow"];
	XCTAssertNotNil([windowController window]);
	id mysql = [windowController addNewConnection];
	NSToolbar *toolbar = [[windowController window] toolbar];
	NSToolbarItem *mysqlItem = [mysql toolbar:toolbar itemForItemIdentifier:SPTestTransferIdentifier willBeInsertedIntoToolbar:NO];
	XCTAssertTrue([mysqlItem isKindOfClass:[SPDisabledToolbarItem class]]);
	XCTAssertTrue(mysqlItem.action == NULL);
	[mysqlItem setEnabled:YES];
	XCTAssertFalse(mysqlItem.isEnabled);
	// A MySQL tab's filter editor resizes itself 0.2 s after it is built: let that run while the tab is alive
	[self spinUntil:^BOOL{ return NO; } timeout:0.4];
	NSTabView *tabView = [windowController valueForKey:@"tabView"];
	for (NSTabViewItem *tabItem in [tabView tabViewItems]) [tabView removeTabViewItem:tabItem];
	[[windowController window] orderOut:nil];
}

@end
