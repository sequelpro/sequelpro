#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <PostgresKit/PostgresKit.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>
#import <stdatomic.h>
#import "SPTestPrefsGuard.h"
#import "SPPostgresTestServers.h"
#import "../Source/NSWindow+SPCompactChrome.h"
#import "../Source/SPToolbarTransferItem.h"
// SPMainToolbar.h
extern NSImage *SPUsersToolbarImage(void);
#import "../Source/SPWindowController.h"
#import "../Source/Postgres/SPPostgresDocument.h"
#import "../Source/Postgres/SPPostgresConnector.h"
#import "../Source/Postgres/SPPostgresFavorite.h"

static const NSUInteger SPToolbarParityTestPort = 55418;

// The app's identifiers (its constants aren't exported to the test bundle)
static NSString * const SPParityDatabase = @"DatabaseSelectToolbarItemIdentifier";
static NSString * const SPParityHistory = @"HistoryNavigationToolbarItemIdentifier";
static NSString * const SPParityShowConsole = @"ShowConsoleIdentifier";
static NSString * const SPParityClearConsole = @"ClearConsoleIdentifier";
static NSString * const SPParityStructure = @"SwitchToTableStructureToolbarItemIdentifier";
static NSString * const SPParityContent = @"SwitchToTableContentToolbarItemIdentifier";
static NSString * const SPParityQuery = @"SwitchToRunQueryToolbarItemIdentifier";
static NSString * const SPParityTableInfo = @"SwitchToTableInfoToolbarItemIdentifier";
static NSString * const SPParityRelations = @"SwitchToTableRelationsToolbarItemIdentifier";
static NSString * const SPParityTriggers = @"SwitchToTableTriggersToolbarItemIdentifier";
static NSString * const SPParityUsers = @"SwitchToUserManagerToolbarItemIdentifier";
static NSString * const SPParityTransfer = @"TransferToolbarItemIdentifier";

@interface NSObject (SPToolbarParityTestsMySQL)
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)flag;
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar;
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar;
@end

#pragma mark - Window capture

typedef CGImageRef (*SPWindowListCreateImageFunction)(CGRect, CGWindowListOption, CGWindowID, CGWindowImageOption);

/// CGWindowListCreateImage is obsoleted in the macOS 15 SDK, but still exported: look it up at run time.
static CGImageRef SPCreateWindowImage(NSWindow *window)
{
	static SPWindowListCreateImageFunction function = NULL;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		function = (SPWindowListCreateImageFunction)dlsym(RTLD_DEFAULT, "CGWindowListCreateImage");
	});
	if (!function) return NULL;
	return function(CGRectNull, kCGWindowListOptionIncludingWindow, (CGWindowID)[window windowNumber], kCGWindowImageBoundsIgnoreFraming | kCGWindowImageBestResolution);
}

static BOOL SPWritePNG(CGImageRef image, NSString *path)
{
	if (!image) return NO;
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:image];
	return [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
}

/// RGBA bytes of an image, for pixel comparison.
static NSData *SPPixels(CGImageRef image, size_t *outWidth, size_t *outHeight)
{
	size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
	NSMutableData *data = [NSMutableData dataWithLength:width * height * 4];
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate([data mutableBytes], width, height, 8, width * 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
	CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
	CGContextRelease(context);
	CGColorSpaceRelease(space);
	*outWidth = width;
	*outHeight = height;
	return data;
}

/// The bounding box (in image pixels, origin top left) of the pixels that differ, or CGRectNull if none do.
static CGRect SPDifference(NSData *a, NSData *b, size_t width, size_t height)
{
	if ([a length] != [b length]) return CGRectInfinite;
	const uint8_t *pa = [a bytes], *pb = [b bytes];
	size_t minX = SIZE_MAX, minY = SIZE_MAX, maxX = 0, maxY = 0;
	BOOL any = NO;
	for (size_t y = 0; y < height; y++) {
		for (size_t x = 0; x < width; x++) {
			size_t i = (y * width + x) * 4;
			int d = abs(pa[i] - pb[i]) + abs(pa[i + 1] - pb[i + 1]) + abs(pa[i + 2] - pb[i + 2]);
			if (d <= 24) continue;
			any = YES;
			if (x < minX) minX = x;
			if (y < minY) minY = y;
			if (x > maxX) maxX = x;
			if (y > maxY) maxY = y;
		}
	}
	return any ? CGRectMake(minX, minY, maxX - minX + 1, maxY - minY + 1) : CGRectNull;
}

#pragma mark -

/**
 * Toolbar parity between MySQL and PostgreSQL tabs of one window: the same items, picker and
 * left-pane width, and the evidence (window captures) for switching between them.
 */
@interface SPToolbarParityTests : XCTestCase
@property (strong) SPWindowController *controller;
@property (strong) NSMutableArray *postgresDocuments;
@end

@implementation SPToolbarParityTests

- (void)setUp
{
	self.continueAfterFailure = NO;

	// As -[SPAppController newWindow] does. The window's delegate is deliberately not set: its
	// -windowWillClose: autoreleases the controller, which this (ARC) test owns.
	self.controller = [[SPWindowController alloc] initWithWindowNibName:@"MainWindow"];
	XCTAssertNotNil([self.controller window]);
	self.postgresDocuments = [NSMutableArray array];
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
	self.postgresDocuments = nil;
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

/// A MySQL tab on its connection screen, selected (its delayed filter resize already run).
- (id)addMySQLTab
{
	id mysql = [self.controller addNewConnection];
	XCTAssertNotNil(mysql);
	[self spinFor:0.4];
	return mysql;
}

/// A connected Postgres tab, added at the end and selected.
- (SPPostgresDocument *)addPostgresTab
{
	SPPostgresFavorite *favorite = [[SPPostgresFavorite alloc] init];
	favorite.name = @"pg18 parity";
	favorite.type = SPPostgresTCPIPConnection;
	favorite.host = @"127.0.0.1";
	favorite.port = SPToolbarParityTestPort;
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

	SPPostgresDocument *document = [[SPPostgresDocument alloc] initWithConnection:connection connector:connector favorite:favorite];
	[self.postgresDocuments addObject:document];
	[self.controller addTabDocument:document atIndex:(NSUInteger)[[self tabView] numberOfTabViewItems] select:YES];
	XCTAssertEqual([self.controller selectedDocument], document);
	XCTAssertTrue([SPPostgresTestServers waitForRunner:document.taskRunner timeout:30]);
	return document;
}

- (NSToolbarItem *)itemWithIdentifier:(NSString *)identifier
{
	for (NSToolbarItem *item in [[[self.controller window] toolbar] items]) {
		if ([[item itemIdentifier] isEqualToString:identifier]) return item;
	}
	return nil;
}

- (void)selectTabAtIndex:(NSInteger)index
{
	[[self tabView] selectTabViewItemAtIndex:index];
}

#pragma mark - MySQL items are unchanged

/// The image drawn at 24 x 24 pt, 2x (PNG): compares what is shown, not how the image is cached.
static NSData *SPImageData(NSImage *image)
{
	if (!image) return nil;
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:48 pixelsHigh:48 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
	[rep setSize:NSMakeSize(24, 24)];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:rep]];
	[image drawInRect:NSMakeRect(0, 0, 24, 24)];
	[NSGraphicsContext restoreGraphicsState];
	return [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
}

/**
 * MySQL's image items, exactly as built before the items were shared with PostgreSQL tabs
 * (-[SPDatabaseDocument toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:] at 848a8d2).
 */
- (void)testMySQLImageItemsAreUnchanged
{
	id mysql = [self addMySQLTab];
	NSToolbar *toolbar = [mysql valueForKey:@"mainToolbar"];

	// identifier: label, palette label, tooltip, image name, action
	NSDictionary *expected = @{
		SPParityShowConsole: @[@"Console", @"Show Console", @"Show the console which shows all MySQL commands performed by Sequel Pro", @"hideconsole", @"showConsole:"],
		SPParityClearConsole: @[@"Clear Console", @"Clear Console", @"Clear the console which shows all MySQL commands performed by Sequel Pro", @"clearconsole", @"clearConsole:"],
		SPParityStructure: @[@"Structure", @"Edit Table Structure", @"Switch to the Table Structure tab", @"toolbar-switch-to-structure", @"viewStructure:"],
		SPParityContent: @[@"Content", @"Browse & Edit Table Content", @"Switch to the Table Content tab", @"toolbar-switch-to-browse", @"viewContent:"],
		SPParityQuery: @[@"Query", @"Run Custom Query", @"Switch to the Run Query tab", @"toolbar-switch-to-sql", @"viewQuery:"],
		SPParityTableInfo: @[@"Table Info", @"Table Info", @"Switch to the Table Info tab", @"toolbar-switch-to-table-info", @"viewStatus:"],
		SPParityRelations: @[@"Relations", @"Table Relations", @"Switch to the Table Relations tab", @"toolbar-switch-to-table-relations", @"viewRelations:"],
		SPParityTriggers: @[@"Triggers", @"Table Triggers", @"Switch to the Table Triggers tab", @"toolbar-switch-to-table-triggers", @"viewTriggers:"],
	};

	for (NSString *identifier in expected) {
		NSArray *values = expected[identifier];
		NSToolbarItem *item = [mysql toolbar:toolbar itemForItemIdentifier:identifier willBeInsertedIntoToolbar:NO];
		XCTAssertEqualObjects([item class], [NSToolbarItem class], @"%@", identifier);
		XCTAssertEqualObjects([item label], values[0], @"%@", identifier);
		XCTAssertEqualObjects([item paletteLabel], values[1], @"%@", identifier);
		XCTAssertEqualObjects([item toolTip], values[2], @"%@", identifier);
		XCTAssertEqualObjects(SPImageData([item image]), SPImageData(SPCompactToolbarImage([NSImage imageNamed:values[3]])), @"%@", identifier);
		XCTAssertTrue(NSEqualSizes([[item image] size], NSMakeSize(24, 24)), @"%@", identifier);
		XCTAssertEqual([item target], mysql, @"%@", identifier);
		XCTAssertEqualObjects(NSStringFromSelector([item action]), values[4], @"%@", identifier);
		XCTAssertNil([item view], @"%@", identifier);
	}

	// Users: its own drawing (two people in black, a template image), unbordered at 28 points as Transfer
	NSToolbarItem *users = [mysql toolbar:toolbar itemForItemIdentifier:SPParityUsers willBeInsertedIntoToolbar:NO];
	XCTAssertEqualObjects([users class], [NSToolbarItem class]);
	XCTAssertEqualObjects([users label], @"Users");
	XCTAssertEqualObjects([users paletteLabel], @"Users");
	XCTAssertEqualObjects([users toolTip], @"Switch to the User Manager tab");
	XCTAssertEqualObjects(SPImageData([users image]), SPImageData(SPCompactToolbarImage(SPUsersToolbarImage())));
	XCTAssertNotEqualObjects(SPImageData([users image]), SPImageData(SPCompactToolbarImage([NSImage imageNamed:NSImageNameEveryone])));
	XCTAssertTrue(NSEqualSizes([[users image] size], NSMakeSize(24, 24)));
	XCTAssertTrue([[users image] isTemplate]);
	XCTAssertEqual([users target], mysql);
	XCTAssertEqualObjects(NSStringFromSelector([users action]), @"showUserManager:");
	XCTAssertFalse([users isBordered]);
	XCTAssertNil([users view]);

	// Transfer: MySQL → MySQL (the document's -showTransfer:), unbordered at 28 points as on PostgreSQL tabs
	NSToolbarItem *transfer = [mysql toolbar:toolbar itemForItemIdentifier:SPParityTransfer willBeInsertedIntoToolbar:NO];
	XCTAssertEqualObjects([transfer class], [NSToolbarItem class]);
	XCTAssertEqualObjects([transfer label], @"Transfer");
	XCTAssertEqualObjects([transfer paletteLabel], @"Transfer");
	XCTAssertEqualObjects([transfer toolTip], @"Copy this database, or some of its tables, to another connection");
	XCTAssertEqualObjects(SPImageData([transfer image]), SPImageData(SPCompactToolbarImage(SPTransferToolbarImage())));
	XCTAssertEqual([transfer target], mysql);
	XCTAssertEqualObjects(NSStringFromSelector([transfer action]), @"showTransfer:");
	XCTAssertFalse([transfer isBordered]);

	XCTAssertNil([mysql toolbar:toolbar itemForItemIdentifier:@"SPNoSuchItem" willBeInsertedIntoToolbar:NO]);
}

/// MySQL's view items, as before: the nib's picker (200 wide until the left pane sets it) and history control.
- (void)testMySQLViewItemsAreUnchanged
{
	id mysql = [self addMySQLTab];

	NSToolbarItem *database = [self itemWithIdentifier:SPParityDatabase];
	XCTAssertEqual([database view], [mysql valueForKey:@"chooseDatabaseButton"]);
	XCTAssertEqualObjects([database label], @"Select Database");
	XCTAssertEqualObjects([database paletteLabel], @"Select Database");
	XCTAssertEqual([(NSControl *)[database view] target], mysql);
	XCTAssertEqualObjects(NSStringFromSelector([(NSControl *)[database view] action]), @"chooseDatabase:");

	NSToolbarItem *history = [self itemWithIdentifier:SPParityHistory];
	XCTAssertEqual([history view], [mysql valueForKey:@"historyControl"]);
	XCTAssertEqualObjects([history label], @"Table History");
	XCTAssertEqualObjects([history paletteLabel], @"Table History");

	XCTAssertEqualObjects([NSSet setWithArray:[mysql toolbarSelectableItemIdentifiers:[mysql valueForKey:@"mainToolbar"]]],
						  ([NSSet setWithArray:@[SPParityStructure, SPParityContent, SPParityQuery, SPParityTableInfo, SPParityRelations, SPParityTriggers]]));
}

#pragma mark - Parity

/// A MySQL connection-screen tab and a connected Postgres tab, both built in the window.
- (NSArray *)mysqlAndPostgres
{
	NSWindow *window = [self.controller window];
	[window setFrame:NSMakeRect(80, 120, 1180, 720) display:NO];
	id mysql = [self addMySQLTab];
	SPPostgresDocument *postgres = [self addPostgresTab];
	[self spinFor:0.2];

	// In the app both tabs restore the shared saved left pane width as they move into the window; the
	// test guard keeps that out of the preferences, so give both the same width here
	[self selectTabAtIndex:0];
	[[mysql valueForKey:@"contentViewSplitter"] setPosition:250 ofDividerAtIndex:0];
	[self spinFor:0.1];
	[self selectTabAtIndex:1];
	[(NSSplitView *)[postgres databaseView] setPosition:250 ofDividerAtIndex:0];
	[self spinFor:0.1];
	return @[mysql, postgres];
}

- (void)testPostgresImageItemsMatchMySQL
{
	NSArray *documents = [self mysqlAndPostgres];
	id mysql = documents[0];
	SPPostgresDocument *postgres = documents[1];

	XCTAssertEqualObjects([[postgres toolbar].delegate toolbarSelectableItemIdentifiers:[postgres toolbar]], [mysql toolbarSelectableItemIdentifiers:[mysql valueForKey:@"mainToolbar"]]);

	for (NSString *identifier in [mysql toolbarAllowedItemIdentifiers:[mysql valueForKey:@"mainToolbar"]]) {
		if ([identifier hasPrefix:@"NSToolbar"] || [identifier isEqualToString:SPParityDatabase] || [identifier isEqualToString:SPParityHistory]) continue;

		NSToolbarItem *mine = [mysql toolbar:[mysql valueForKey:@"mainToolbar"] itemForItemIdentifier:identifier willBeInsertedIntoToolbar:NO];
		NSToolbarItem *theirs = [[postgres toolbar].delegate toolbar:[postgres toolbar] itemForItemIdentifier:identifier willBeInsertedIntoToolbar:NO];
		XCTAssertEqualObjects([theirs label], [mine label], @"%@", identifier);
		XCTAssertEqualObjects(SPImageData([theirs image]), SPImageData([mine image]), @"%@", identifier);
		XCTAssertEqualObjects([theirs paletteLabel], [mine paletteLabel], @"%@", identifier);
		XCTAssertEqual([theirs isBordered], [mine isBordered], @"%@", identifier);
		XCTAssertEqualObjects([theirs class], [mine class], @"%@", identifier);
		XCTAssertEqual([theirs action] == NULL, [mine action] == NULL, @"%@: both have an action, or neither", identifier);

		// The console items say which commands they show
		if (![identifier isEqualToString:SPParityShowConsole] && ![identifier isEqualToString:SPParityClearConsole]) {
			XCTAssertEqualObjects([theirs toolTip], [mine toolTip], @"%@", identifier);
		}
	}

	// The Console image follows the console window on both
	NSToolbarItem *console = [self itemWithIdentifier:SPParityShowConsole];
	[postgres validateToolbarItem:console];
	NSData *postgresConsole = SPImageData([console image]);
	[mysql validateToolbarItem:console];
	XCTAssertEqualObjects(SPImageData([console image]), postgresConsole);
}

/// Every item of the installed toolbar takes the same size, so switching tabs doesn't move anything.
- (void)testInstalledToolbarsMatch
{
	NSArray *documents = [self mysqlAndPostgres];
	NSWindow *window = [self.controller window];

	NSMutableArray *layouts = [NSMutableArray array];
	NSMutableArray *frames = [NSMutableArray array];
	for (NSInteger i = 0; i < 2; i++) {
		[self selectTabAtIndex:i];
		[self spinFor:0.2];
		XCTAssertEqual([self.controller selectedDocument], documents[i]);
		NSMutableArray *layout = [NSMutableArray array];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		for (NSToolbarItem *item in [[window toolbar] items]) {
			// Transfer's class differs (enabled on Postgres tabs only); everything else about it must match
			NSString *className = [[item itemIdentifier] isEqualToString:SPParityTransfer] ? @"(Transfer)" : NSStringFromClass([item class]);
			[layout addObject:[NSString stringWithFormat:@"%@ %@ %@ %@ %@", [item itemIdentifier], className, NSStringFromSize([item minSize]), NSStringFromSize([item maxSize]), [item view] ? NSStringFromRect([[item view] convertRect:[[item view] bounds] toView:nil]) : @""]];
		}
#pragma clang diagnostic pop
		[layouts addObject:layout];
		[frames addObject:[NSString stringWithFormat:@"%@ %@ %@", NSStringFromRect([window frame]), NSStringFromRect([[window contentView] frame]), NSStringFromRect([window contentLayoutRect])]];
	}

	// Element by element (a failing array comparison is very slow to describe)
	XCTAssertEqual([layouts[1] count], [layouts[0] count]);
	for (NSUInteger i = 0; i < [layouts[0] count]; i++) XCTAssertEqualObjects(layouts[1][i], layouts[0][i]);
	XCTAssertEqualObjects(frames[1], frames[0], @"the window and its content keep their place");
}

- (void)testPostgresPickerMatchesMySQL
{
	NSArray *documents = [self mysqlAndPostgres];
	NSPopUpButton *mine = [documents[0] valueForKey:@"chooseDatabaseButton"];
	NSPopUpButton *theirs = (NSPopUpButton *)[self itemWithIdentifier:SPParityDatabase].view;
	XCTAssertTrue([theirs isKindOfClass:[NSPopUpButton class]]);
	XCTAssertNotEqual(theirs, mine);

	XCTAssertEqual([theirs bezelStyle], [mine bezelStyle]);
	XCTAssertEqual([theirs isBordered], [mine isBordered]);
	XCTAssertEqual([theirs controlSize], [mine controlSize]);
	XCTAssertEqualObjects([theirs font], [mine font]);
	XCTAssertEqual([theirs autoresizingMask], [mine autoresizingMask]);
	XCTAssertEqual([theirs pullsDown], [mine pullsDown]);
	XCTAssertEqual([[theirs cell] alignment], [[mine cell] alignment]);
	XCTAssertEqual([[theirs cell] lineBreakMode], [[mine cell] lineBreakMode]);
	XCTAssertEqual([[theirs cell] arrowPosition], [[mine cell] arrowPosition]);
	XCTAssertEqual([[theirs cell] highlightsBy], [[mine cell] highlightsBy]);
	XCTAssertEqual([[theirs cell] showsStateBy], [[mine cell] showsStateBy]);
	XCTAssertEqualObjects(NSStringFromSize([theirs frame].size), NSStringFromSize([mine frame].size), @"same width (shared left pane) and height");
}

- (void)testPostgresHistoryControlMatchesMySQL
{
	NSArray *documents = [self mysqlAndPostgres];
	NSSegmentedControl *mine = [documents[0] valueForKey:@"historyControl"];
	NSSegmentedControl *theirs = (NSSegmentedControl *)[self itemWithIdentifier:SPParityHistory].view;
	XCTAssertTrue([theirs isKindOfClass:[NSSegmentedControl class]]);

	XCTAssertEqual([theirs segmentStyle], [mine segmentStyle]);
	XCTAssertEqual([theirs trackingMode], [mine trackingMode]);
	XCTAssertEqual([theirs controlSize], [mine controlSize]);
	XCTAssertEqualObjects([theirs font], [mine font]);
	XCTAssertEqual([theirs isEnabled], [mine isEnabled], @"as MySQL's on its connection screen: the control enabled, its segments not");
	XCTAssertEqual([theirs segmentCount], [mine segmentCount]);
	for (NSInteger i = 0; i < [mine segmentCount]; i++) {
		XCTAssertEqualObjects([[theirs imageForSegment:i] name], [[mine imageForSegment:i] name]);
		XCTAssertEqual([theirs widthForSegment:i], [mine widthForSegment:i]);
		XCTAssertEqualObjects([theirs toolTipForSegment:i], [mine toolTipForSegment:i]);
		XCTAssertFalse([theirs isEnabledForSegment:i], @"no history on Postgres tabs yet");
		XCTAssertFalse([mine isEnabledForSegment:i], @"no history on a connection screen");
	}
	XCTAssertEqualObjects(NSStringFromSize([theirs frame].size), NSStringFromSize([mine frame].size));
}

/// The left pane width is shared: the Postgres split view saves under MySQL's name and starts as MySQL's does.
- (void)testLeftPaneWidthIsShared
{
	NSArray *documents = [self mysqlAndPostgres];
	NSSplitView *mine = [documents[0] valueForKey:@"contentViewSplitter"];
	NSSplitView *theirs = (NSSplitView *)[documents[1] databaseView];

	XCTAssertEqualObjects([theirs sp_requestedAutosaveName], [mine sp_requestedAutosaveName]);
	XCTAssertEqualObjects([theirs sp_requestedAutosaveName], @"DBViewSplitter");
	XCTAssertNil([theirs autosaveName], @"the test guard keeps it out of the preferences");

	// In the app both restore the saved (shared) width as they move into the window (SPSplitView
	// -viewDidMoveToWindow); here, where nothing is saved, give both the same width as that does.
	// The pickers then match too, also after switching back and forth.
	for (CGFloat width = 180; width <= 420; width += 120) {
		[self selectTabAtIndex:0];
		[self spinFor:0.05];
		[mine setPosition:width ofDividerAtIndex:0];
		[self spinFor:0.1];
		[self selectTabAtIndex:1];
		[self spinFor:0.05];
		[theirs setPosition:width ofDividerAtIndex:0];
		[self spinFor:0.1];
		XCTAssertEqualWithAccuracy(NSWidth([[[theirs subviews] firstObject] frame]), NSWidth([[[mine subviews] firstObject] frame]), 0.5);

		CGFloat postgresPicker = NSWidth([[self itemWithIdentifier:SPParityDatabase].view frame]);
		[self selectTabAtIndex:0];
		[self spinFor:0.05];
		CGFloat mysqlPicker = NSWidth([[self itemWithIdentifier:SPParityDatabase].view frame]);
		XCTAssertEqualWithAccuracy(postgresPicker, mysqlPicker, 0.5, @"left pane %.0f", width);
		XCTAssertEqualWithAccuracy(mysqlPicker, MIN(MAX(NSWidth([[[mine subviews] firstObject] frame]) - 9, 130), 360), 0.5);
	}
}

/// The Console item is MySQL's original artwork, drawn like Table Info or Query (no capsule), on both engines.
- (void)testConsoleItemUsesOriginalArtworkOnBothEngines
{
	NSArray *documents = [self mysqlAndPostgres];
	NSWindow *window = [self.controller window];
	NSData *off = SPImageData(SPCompactToolbarImage([NSImage imageNamed:@"hideconsole"]));
	NSData *on = SPImageData(SPCompactToolbarImage([NSImage imageNamed:@"showconsole"]));
	NSWindow *console = [[NSClassFromString(@"SPQueryController") performSelector:@selector(sharedQueryController)] window];
	BOOL consoleWasVisible = [console isVisible];
	[console orderOut:nil];

	NSMutableArray *sizes = [NSMutableArray array];
	for (NSInteger i = 0; i < 2; i++) {
		[self selectTabAtIndex:i];
		[self spinFor:0.1];
		id document = documents[i];
		NSToolbarItem *item = [self itemWithIdentifier:SPParityShowConsole];
		XCTAssertNotNil(item);
		XCTAssertFalse([item isBordered], @"%@: no capsule", [document class]);
		XCTAssertNil([item view]);
		XCTAssertFalse([[item image] isTemplate]);

		// A MySQL tab updates the image once connected (stubbed: no MySQL server in the test servers)
		BOOL mysql = ![document isKindOfClass:[SPPostgresDocument class]];
		if (mysql) [document setValue:@YES forKey:@"_isConnected"];

		[document validateToolbarItem:item];
		XCTAssertEqualObjects(SPImageData([item image]), off, @"%@: console off", [document class]);
		[console orderFront:nil];
		[document validateToolbarItem:item];
		XCTAssertEqualObjects(SPImageData([item image]), on, @"%@: console on", [document class]);
		[console orderOut:nil];
		[document validateToolbarItem:item];
		if (mysql) [document setValue:@NO forKey:@"_isConnected"];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		[sizes addObject:NSStringFromSize([item minSize])];
		// As big as the other image items (Query)
		XCTAssertEqualObjects(NSStringFromSize([item minSize]), NSStringFromSize([[self itemWithIdentifier:SPParityQuery] minSize]), @"%@", [document class]);
#pragma clang diagnostic pop
	}
	XCTAssertEqualObjects(sizes[1], sizes[0]);
	XCTAssertEqualObjects(window, [self.controller window]);
	if (consoleWasVisible) [console orderFront:nil];
}

/// Every shared item looks the same on both engines in the window: bordered, size, template, class.
- (void)testInstalledItemsMatchInKind
{
	[self mysqlAndPostgres];
	NSMutableArray *kinds = [NSMutableArray array];
	for (NSInteger i = 0; i < 2; i++) {
		[self selectTabAtIndex:i];
		[self spinFor:0.1];
		NSMutableDictionary *kind = [NSMutableDictionary dictionary];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		for (NSToolbarItem *item in [[[self.controller window] toolbar] items]) {
			NSString *className = [[item itemIdentifier] isEqualToString:SPParityTransfer] ? @"(Transfer)" : NSStringFromClass([item class]);
			kind[[item itemIdentifier]] = [NSString stringWithFormat:@"%@ bordered=%d template=%d min=%@ max=%@ view=%@", className, [item isBordered], [[item image] isTemplate], NSStringFromSize([item minSize]), NSStringFromSize([item maxSize]), [[item view] class]];
		}
#pragma clang diagnostic pop
		[kinds addObject:kind];
	}
	XCTAssertEqualObjects([NSSet setWithArray:[kinds[1] allKeys]], [NSSet setWithArray:[kinds[0] allKeys]]);
	for (NSString *identifier in kinds[0]) {
		if ([identifier isEqualToString:SPParityDatabase]) continue; // its width follows the left pane (see -testLeftPaneWidthIsShared)
		XCTAssertEqualObjects(kinds[1][identifier], kinds[0][identifier], @"%@", identifier);
	}
}

/// Switching tabs keeps a hidden toolbar hidden, and doesn't touch the visibility when it doesn't change.
- (void)testSwitchingKeepsToolbarVisibility
{
	[self mysqlAndPostgres];
	NSWindow *window = [self.controller window];
	[[window toolbar] setVisible:NO];
	[self selectTabAtIndex:0];
	XCTAssertFalse([[window toolbar] isVisible]);
	[self selectTabAtIndex:1];
	XCTAssertFalse([[window toolbar] isVisible]);
	[[window toolbar] setVisible:YES];
	[self selectTabAtIndex:0];
	XCTAssertTrue([[window toolbar] isVisible]);
}

#pragma mark - Capture (SP_CAPTURE_TOOLBAR=1)

/**
 * A description of every toolbar item of the window, for comparing the engines in text.
 */
- (NSString *)describeToolbar
{
	NSMutableString *text = [NSMutableString string];
	NSToolbar *toolbar = [[self.controller window] toolbar];
	[text appendFormat:@"toolbar %p visible=%d displayMode=%ld\n", toolbar, [toolbar isVisible], (long)[toolbar displayMode]];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	for (NSToolbarItem *item in [toolbar items]) {
		[text appendFormat:@"  %@ class=%@ label=%@ palette=%@ enabled=%d min=%@ max=%@", [item itemIdentifier], [item class], [item label], [item paletteLabel], [item isEnabled], NSStringFromSize([item minSize]), NSStringFromSize([item maxSize])];
		if ([item image]) [text appendFormat:@" image=%@ size=%@ template=%d", [[item image] name], NSStringFromSize([[item image] size]), [[item image] isTemplate]];
		NSView *view = [item view];
		if (view) {
			NSRect inWindow = [view convertRect:[view bounds] toView:nil];
			[text appendFormat:@" view=%@ frame=%@ inWindow=%@", [view class], NSStringFromRect([view frame]), NSStringFromRect(inWindow)];
			if ([view isKindOfClass:[NSControl class]]) {
				NSControl *control = (NSControl *)view;
				[text appendFormat:@" font=%@ %.1f controlSize=%ld enabled=%d", [[control font] fontName], [[control font] pointSize], (long)[control controlSize], [control isEnabled]];
			}
			if ([view isKindOfClass:[NSPopUpButton class]]) {
				NSPopUpButton *popup = (NSPopUpButton *)view;
				NSPopUpButtonCell *cell = [popup cell];
				[text appendFormat:@" bezel=%ld bordered=%d alignment=%ld lineBreak=%ld arrow=%ld", (long)[popup bezelStyle], [popup isBordered], (long)[cell alignment], (long)[cell lineBreakMode], (long)[cell arrowPosition]];
			}
			if ([view isKindOfClass:[NSSegmentedControl class]]) {
				NSSegmentedControl *segmented = (NSSegmentedControl *)view;
				[text appendFormat:@" segmentStyle=%ld tracking=%ld", (long)[segmented segmentStyle], (long)[segmented trackingMode]];
				for (NSInteger i = 0; i < [segmented segmentCount]; i++) {
					[text appendFormat:@" [%ld image=%@ width=%.1f enabled=%d]", (long)i, [[segmented imageForSegment:i] name], [segmented widthForSegment:i], [segmented isEnabledForSegment:i]];
				}
			}
		}
		[text appendString:@"\n"];
	}
#pragma clang diagnostic pop

	return text;
}

/**
 * Captures the window during a tab switch, from a background thread in a tight loop, until it has
 * settled. Returns a report of every distinct frame that reached the screen and where it differs
 * from the settled state. Frames are saved as <prefix>-NN.png.
 */
- (NSString *)recordSwitchToTabAtIndex:(NSInteger)index directory:(NSString *)directory prefix:(NSString *)prefix
{
	NSWindow *window = [self.controller window];
	NSMutableArray *frames = [NSMutableArray array];
	NSMutableArray *times = [NSMutableArray array];
	NSLock *lock = [[NSLock alloc] init];
	__block atomic_bool stop = NO;
	CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();

	dispatch_semaphore_t finished = dispatch_semaphore_create(0);
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
		while (!atomic_load(&stop)) {
			CGImageRef image = SPCreateWindowImage(window);
			if (image) {
				[lock lock];
				[frames addObject:(__bridge_transfer id)image];
				[times addObject:@(CFAbsoluteTimeGetCurrent() - start)];
				[lock unlock];
			}
		}
		dispatch_semaphore_signal(finished);
	});

	// Let the recorder get going, switch, and let everything deferred run
	[self spinFor:0.15];
	CFAbsoluteTime switchStart = CFAbsoluteTimeGetCurrent() - start;
	[self selectTabAtIndex:index];
	CFAbsoluteTime switchEnd = CFAbsoluteTimeGetCurrent() - start;
	[self spinFor:0.8];
	atomic_store(&stop, YES);
	dispatch_semaphore_wait(finished, DISPATCH_TIME_FOREVER);

	NSMutableString *report = [NSMutableString stringWithFormat:@"%@: switch call %.3f-%.3f s, %lu captures\n", prefix, switchStart, switchEnd, (unsigned long)[frames count]];
	if (![frames count]) return report;

	size_t width = 0, height = 0;
	NSData *settled = SPPixels((__bridge CGImageRef)[frames lastObject], &width, &height);
	NSData *previous = nil;
	NSUInteger distinct = 0;
	for (NSUInteger i = 0; i < [frames count]; i++) {
		size_t w = 0, h = 0;
		NSData *pixels = SPPixels((__bridge CGImageRef)frames[i], &w, &h);
		if (previous && CGRectIsNull(SPDifference(previous, pixels, w, h))) continue;
		previous = pixels;
		CGRect fromSettled = SPDifference(pixels, settled, w, h);
		NSString *name = [NSString stringWithFormat:@"%@-%02lu.png", prefix, (unsigned long)distinct];
		SPWritePNG((__bridge CGImageRef)frames[i], [directory stringByAppendingPathComponent:name]);
		[report appendFormat:@"  frame %lu at %.3f s (%@, %zux%zu px): differs from settled in %@\n", (unsigned long)distinct, [times[i] doubleValue], name, w, h, CGRectIsNull(fromSettled) ? @"nothing" : NSStringFromRect(NSRectFromCGRect(fromSettled))];
		distinct++;
	}
	[report appendFormat:@"  %lu distinct frames (the first is the old tab; any between it and the settled one are intermediate)\n", (unsigned long)distinct];
	return report;
}

/**
 * Renders a window with a MySQL connection-screen tab, a connected Postgres tab and a second MySQL
 * tab; saves each as <SP_CAPTURE_PREFIX>-mysql.png, -postgres.png, -mysql2.png in SP_CAPTURE_DIR,
 * the toolbar items as text, and frame-by-frame recordings of switching between them.
 */
- (void)testCaptureToolbars
{
	NSDictionary *environment = [[NSProcessInfo processInfo] environment];
	if (![environment[@"SP_CAPTURE_TOOLBAR"] isEqualToString:@"1"]) {
		XCTSkip(@"Set SP_CAPTURE_TOOLBAR=1 (TEST_RUNNER_SP_CAPTURE_TOOLBAR=1 for xcodebuild) to capture");
	}
	NSString *directory = environment[@"SP_CAPTURE_DIR"] ?: NSTemporaryDirectory();
	NSString *prefix = environment[@"SP_CAPTURE_PREFIX"] ?: @"capture";
	[[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];

	NSWindow *window = [self.controller window];
	[window setFrame:NSMakeRect(80, 120, 1180, 720) display:YES];
	[window makeKeyAndOrderFront:nil];

	id mysql = [self addMySQLTab];
	SPPostgresDocument *postgres = [self addPostgresTab];
	id mysql2 = [self addMySQLTab];
	[self spinFor:0.5];

	// In the app every tab restores the saved left pane width as it moves into the window; the test
	// guard keeps that out of the preferences. SP_CAPTURE_LEFT_PANE=<width> gives every tab that width.
	CGFloat leftPane = [environment[@"SP_CAPTURE_LEFT_PANE"] doubleValue];
	if (leftPane > 0) {
		NSArray *splitViews = @[[mysql valueForKey:@"contentViewSplitter"], [postgres databaseView], [mysql2 valueForKey:@"contentViewSplitter"]];
		for (NSInteger i = 0; i < 3; i++) {
			[self selectTabAtIndex:i];
			[splitViews[i] setPosition:leftPane ofDividerAtIndex:0];
			[self spinFor:0.2];
		}
	}
	XCTAssertTrue(SPCreateWindowImage(window) != NULL, @"CGWindowListCreateImage is available");

	NSMutableString *text = [NSMutableString string];
	NSArray *names = @[@"mysql", @"postgres", @"mysql2"];
	for (NSInteger i = 0; i < 3; i++) {
		[self selectTabAtIndex:i];
		[self spinFor:0.8];
		CGImageRef image = SPCreateWindowImage(window);
		XCTAssertTrue(SPWritePNG(image, [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@.png", prefix, names[i]]]));
		CGImageRelease(image);
		[text appendFormat:@"== %@ (%@)\n%@\n", names[i], [[self.controller selectedDocument] class], [self describeToolbar]];
	}

	// Switching: MySQL -> MySQL is the baseline; then MySQL -> Postgres and Postgres -> MySQL
	NSString *frameDirectory = [directory stringByAppendingPathComponent:[prefix stringByAppendingString:@"-frames"]];
	[[NSFileManager defaultManager] createDirectoryAtPath:frameDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
	[self selectTabAtIndex:2];
	[self spinFor:0.8];
	[text appendString:[self recordSwitchToTabAtIndex:0 directory:frameDirectory prefix:@"mysql2-to-mysql"]];
	[text appendString:[self recordSwitchToTabAtIndex:2 directory:frameDirectory prefix:@"mysql-to-mysql2"]];
	[text appendString:[self recordSwitchToTabAtIndex:1 directory:frameDirectory prefix:@"mysql2-to-postgres"]];
	[text appendString:[self recordSwitchToTabAtIndex:0 directory:frameDirectory prefix:@"postgres-to-mysql"]];
	[text appendString:[self recordSwitchToTabAtIndex:1 directory:frameDirectory prefix:@"mysql-to-postgres"]];
	[text appendString:[self recordSwitchToTabAtIndex:2 directory:frameDirectory prefix:@"postgres-to-mysql2"]];

	XCTAssertTrue([text writeToFile:[directory stringByAppendingPathComponent:[prefix stringByAppendingString:@"-toolbar.txt"]] atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
}

@end
