#import <XCTest/XCTest.h>
#import <PostgresKit/PostgresKit.h>
#import "SPPostgresTestServers.h"
#import "../Source/SPWindowController.h"
#import "../Source/Postgres/SPPostgresDocument.h"
#import "../Source/Postgres/SPPostgresSidebarController.h"
#import "../Source/Postgres/SPPostgresConnector.h"
#import "../Source/Postgres/SPPostgresFavorite.h"
#import "../Source/Postgres/SPPostgresContentController.h"
#import "../Source/Postgres/SPPostgresTableData.h"
#import "../Source/Postgres/SPPostgresTaskRunner.h"
#import "../Source/Postgres/SPPostgresHistory.h"

static const NSUInteger SPLinkTestPort = 55418;

/// SPTextAndLinkCell (the header isn't ARC-clean here)
@interface NSObject (SPLinkTestCell)
- (BOOL)linkActive;
@end

/**
 * The Content view's foreign key links (as MySQL's link arrows): an arrow after a non-NULL value of a column that
 * starts a FOREIGN KEY; following it shows the referenced table with an "=" filter on the referenced column.
 * Tables in two schemas of their own, dropped afterwards.
 */
@interface SPPostgresForeignKeyLinkTests : XCTestCase
@property (strong) SPWindowController *controller;
@property (strong) SPPostgresDocument *document;
@property (strong) PGPostgresConnection *other;
@property (strong) NSMutableArray<NSAlert *> *alerts;
@end

@implementation SPPostgresForeignKeyLinkTests

- (BOOL)spinUntil:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout
{
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
	while (!condition() && [deadline timeIntervalSinceNow] > 0) {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
	}
	return condition();
}

- (void)run:(NSString *)sql
{
	XCTAssertNotNil([self.other execute:sql], @"%@: %@", sql, [[self.other lastError] errorPrimaryMessage]);
}

- (void)setUp
{
	self.continueAfterFailure = NO;

	// The filter bar hidden and no page limit, in the volatile argument domain (never the saved preferences)
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	NSDictionary *original = [prefs volatileDomainForName:NSArgumentDomain] ?: @{};
	NSMutableDictionary *domain = [original mutableCopy];
	[domain addEntriesFromDictionary:@{@"LimitResults": @NO, @"RuleFilterEditorLastVisibilityChoice": @NO, @"EditInSheetEnabled": @NO}];
	[prefs removeVolatileDomainForName:NSArgumentDomain];
	[prefs setVolatileDomain:domain forName:NSArgumentDomain];
	[self addTeardownBlock:^{
		[prefs removeVolatileDomainForName:NSArgumentDomain];
		[prefs setVolatileDomain:original forName:NSArgumentDomain];
	}];

	self.other = [SPPostgresTestServers connectedConnectionOnPort:SPLinkTestPort];
	XCTAssertNotNil(self.other);
	[self run:@"DROP SCHEMA IF EXISTS sp_fk_a CASCADE"];
	[self run:@"DROP SCHEMA IF EXISTS sp_fk_b CASCADE"];
	[self run:@"CREATE SCHEMA sp_fk_a"];
	[self run:@"CREATE SCHEMA sp_fk_b"];
	[self run:@"CREATE TABLE sp_fk_b.region (code text PRIMARY KEY, label text)"];
	[self run:@"INSERT INTO sp_fk_b.region VALUES ('eu', 'Europe'), ('as', 'Asia')"];
	[self run:@"CREATE TABLE sp_fk_a.customer (id int PRIMARY KEY, name text, region text REFERENCES sp_fk_b.region (code))"];
	[self run:@"INSERT INTO sp_fk_a.customer VALUES (1, 'Ann', 'eu'), (2, 'Bob', 'as'), (3, 'Cy', NULL), (4, 'Di', 'eu')"];
	// A self-reference, and a two-column key (its first column links)
	[self run:@"CREATE TABLE sp_fk_a.orders (id int PRIMARY KEY, customer_id int REFERENCES sp_fk_a.customer (id), "
			   "parent_id int REFERENCES sp_fk_a.orders (id), note text, UNIQUE (id, note))"];
	[self run:@"INSERT INTO sp_fk_a.orders VALUES (10, 2, NULL, 'a'), (11, 1, 10, 'b'), (12, NULL, 10, 'c')"];
	[self run:@"CREATE TABLE sp_fk_a.line (order_id int, order_note text, qty int, FOREIGN KEY (order_id, order_note) REFERENCES sp_fk_a.orders (id, note))"];
	[self run:@"INSERT INTO sp_fk_a.line VALUES (11, 'b', 5)"];

	SPPostgresFavorite *favorite = [[SPPostgresFavorite alloc] init];
	favorite.name = @"pg18 links";
	favorite.type = SPPostgresTCPIPConnection;
	favorite.host = @"127.0.0.1";
	favorite.port = SPLinkTestPort;
	favorite.user = @"pgkit_test";
	favorite.database = @"pgkit_test";

	self.controller = [[SPWindowController alloc] initWithWindowNibName:@"MainWindow"];
	XCTAssertNotNil([self.controller window]);

	SPPostgresConnector *connector = [[SPPostgresConnector alloc] initWithFavorite:favorite password:@"pgkit" sshPassword:nil parentWindow:nil];
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

	self.document = [[SPPostgresDocument alloc] initWithConnection:connection connector:connector favorite:favorite];
	NSMutableArray *alerts = [NSMutableArray array];
	self.alerts = alerts;
	self.document.alertPresenter = ^(NSAlert *alert) { [alerts addObject:alert]; };
	[self.controller addTabDocument:self.document atIndex:0 select:YES];
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
	[self.document showPane:@"SwitchToTableContentToolbarItemIdentifier"];
}

- (void)tearDown
{
	NSWindow *window = [self.controller window];
	if (window.attachedSheet) [window endSheet:window.attachedSheet];
	[SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30];
	NSTabView *tabView = [self.controller valueForKey:@"tabView"];
	for (NSTabViewItem *item in [tabView tabViewItems]) [tabView removeTabViewItem:item];
	[window orderOut:nil];
	self.document = nil;
	self.controller = nil;
	[self.other execute:@"DROP SCHEMA IF EXISTS sp_fk_a CASCADE"];
	[self.other execute:@"DROP SCHEMA IF EXISTS sp_fk_b CASCADE"];
	[self.other disconnect];
	self.other = nil;
	[super tearDown];
}

#pragma mark - Helpers

- (SPPostgresContentController *)content
{
	return self.document.contentController;
}

- (NSTableView *)grid
{
	return self.content.tableView;
}

- (void)waitForTab
{
	XCTAssertTrue([SPPostgresTestServers waitForRunner:self.document.taskRunner timeout:30]);
}

- (void)selectTable:(NSString *)table inSchema:(NSString *)schema
{
	[self.document.sidebar reloadSchema:schema];
	[self waitForTab];
	XCTAssertTrue([self.document.sidebar selectTableNamed:table], @"%@", table);
	[self waitForTab];
	XCTAssertEqualObjects(self.content.table, table);
}

- (NSUInteger)indexOfColumn:(NSString *)name
{
	NSUInteger index = [self.content.columnNames indexOfObject:name];
	XCTAssertNotEqual(index, (NSUInteger)NSNotFound, @"%@", name);
	return index;
}

- (NSTableColumn *)tableColumnNamed:(NSString *)name
{
	for (NSTableColumn *column in [[self grid] tableColumns]) {
		if ([[[column headerCell] stringValue] isEqualToString:name]) return column;
	}
	XCTFail(@"No column %@", name);
	return nil;
}

- (NSInteger)rowWhereColumn:(NSString *)name is:(NSString *)value
{
	NSTableColumn *column = [self tableColumnNamed:name];
	for (NSInteger row = 0; row < [[self grid] numberOfRows]; row++) {
		id cell = [[[self grid] dataSource] tableView:[self grid] objectValueForTableColumn:column row:row];
		if ([cell isEqual:value]) return row;
	}
	XCTFail(@"No row with %@ = %@", name, value);
	return -1;
}

- (NSArray *)valuesOfColumn:(NSString *)name
{
	NSTableColumn *column = [self tableColumnNamed:name];
	NSMutableArray *values = [NSMutableArray array];
	for (NSInteger row = 0; row < [[self grid] numberOfRows]; row++) {
		[values addObject:[[[self grid] dataSource] tableView:[self grid] objectValueForTableColumn:column row:row]];
	}
	return values;
}

/// The cell as the grid would draw it (willDisplayCell: applied).
- (NSCell *)preparedCellAtRow:(NSInteger)row column:(NSString *)name
{
	NSInteger columnIndex = [[[self grid] tableColumns] indexOfObject:[self tableColumnNamed:name]];
	return [[self grid] preparedCellAtColumn:columnIndex row:row];
}

- (NSString *)filterBarText
{
	NSPopUpButton *column = [self.content valueForKey:@"filterColumnPopup"];
	NSPopUpButton *comparison = [self.content valueForKey:@"filterComparisonPopup"];
	NSTextField *value = [self.content valueForKey:@"filterValueField"];
	return [NSString stringWithFormat:@"%@ %@ %@", [column titleOfSelectedItem], [comparison titleOfSelectedItem], [value stringValue]];
}

#pragma mark - Data layer

- (void)testForeignKeyReferencesNameTheReferencedTableAndColumn
{
	SPPostgresTableData *orders = [[SPPostgresTableData alloc] initWithConnection:self.other schema:@"sp_fk_a" table:@"orders"];
	NSError *error = nil;
	NSDictionary *references = [orders foreignKeyReferences:&error];
	XCTAssertNotNil(references, @"%@", error);
	NSDictionary *expected = @{@"customer_id": @{@"schema": @"sp_fk_a", @"table": @"customer", @"column": @"id"},
							   @"parent_id": @{@"schema": @"sp_fk_a", @"table": @"orders", @"column": @"id"}};
	XCTAssertEqualObjects(references, expected);

	// Another schema; a two-column key links its first column
	SPPostgresTableData *customer = [[SPPostgresTableData alloc] initWithConnection:self.other schema:@"sp_fk_a" table:@"customer"];
	NSDictionary *expectedCustomer = @{@"region": @{@"schema": @"sp_fk_b", @"table": @"region", @"column": @"code"}};
	XCTAssertEqualObjects([customer foreignKeyReferences:NULL], expectedCustomer);
	SPPostgresTableData *line = [[SPPostgresTableData alloc] initWithConnection:self.other schema:@"sp_fk_a" table:@"line"];
	NSDictionary *expectedLine = @{@"order_id": @{@"schema": @"sp_fk_a", @"table": @"orders", @"column": @"id"}};
	XCTAssertEqualObjects([line foreignKeyReferences:NULL], expectedLine);

	// None
	SPPostgresTableData *region = [[SPPostgresTableData alloc] initWithConnection:self.other schema:@"sp_fk_b" table:@"region"];
	XCTAssertEqualObjects([region foreignKeyReferences:NULL], @{});
}

#pragma mark - Arrows

- (void)testKeyColumnsShowAnArrowOnValuesButNotOnNull
{
	[self selectTable:@"orders" inSchema:@"sp_fk_a"];
	XCTAssertEqual([self.content.foreignKeyReferences count], 2u);

	XCTAssertEqualObjects(NSStringFromClass([[[self tableColumnNamed:@"customer_id"] dataCell] class]), @"SPTextAndLinkCell");
	XCTAssertEqualObjects(NSStringFromClass([[[self tableColumnNamed:@"parent_id"] dataCell] class]), @"SPTextAndLinkCell");
	XCTAssertFalse([NSStringFromClass([[[self tableColumnNamed:@"note"] dataCell] class]) isEqualToString:@"SPTextAndLinkCell"]);
	XCTAssertFalse([NSStringFromClass([[[self tableColumnNamed:@"id"] dataCell] class]) isEqualToString:@"SPTextAndLinkCell"]);

	NSInteger withCustomer = [self rowWhereColumn:@"id" is:@"10"];
	NSInteger withoutCustomer = [self rowWhereColumn:@"id" is:@"12"];
	XCTAssertTrue([(id)[self preparedCellAtRow:withCustomer column:@"customer_id"] linkActive]);
	XCTAssertFalse([(id)[self preparedCellAtRow:withoutCustomer column:@"customer_id"] linkActive]);
	XCTAssertFalse([(id)[self preparedCellAtRow:withCustomer column:@"parent_id"] linkActive]);
	XCTAssertTrue([(id)[self preparedCellAtRow:withoutCustomer column:@"parent_id"] linkActive]);

	// The column is wider by the arrow than a plain one with the same values would be
	XCTAssertGreaterThanOrEqual([[self tableColumnNamed:@"customer_id"] width], [[self tableColumnNamed:@"id"] width]);
}

- (void)testATableWithoutKeysHasNoArrows
{
	[self selectTable:@"region" inSchema:@"sp_fk_b"];
	XCTAssertEqualObjects(self.content.foreignKeyReferences, @{});
	for (NSTableColumn *column in [[self grid] tableColumns]) {
		XCTAssertFalse([NSStringFromClass([[column dataCell] class]) isEqualToString:@"SPTextAndLinkCell"], @"%@", [[column headerCell] stringValue]);
	}
}

#pragma mark - Following

- (void)testFollowingOpensTheReferencedTableFilteredToTheRow
{
	[self selectTable:@"orders" inSchema:@"sp_fk_a"];
	NSInteger row = [self rowWhereColumn:@"id" is:@"10"];

	[self.content followForeignKeyAtRow:row column:[self indexOfColumn:@"customer_id"]];
	[self waitForTab];

	XCTAssertEqualObjects(self.document.sidebar.selectedTableName, @"customer");
	XCTAssertEqualObjects(self.content.table, @"customer");
	XCTAssertEqualObjects(self.content.schema, @"sp_fk_a");
	XCTAssertEqualObjects([self valuesOfColumn:@"id"], @[@"2"]);
	XCTAssertEqualObjects([self valuesOfColumn:@"name"], @[@"Bob"]);
	XCTAssertTrue(self.content.filterBarVisible);
	XCTAssertEqualObjects([self filterBarText], @"id = 2");
	XCTAssertEqualObjects(self.content.countText, @"1 row of 4 matches filter");
	// The preference isn't changed
	XCTAssertFalse([[NSUserDefaults standardUserDefaults] boolForKey:@"RuleFilterEditorLastVisibilityChoice"]);
	XCTAssertEqual([self.alerts count], 0u);

	// Clearing the filter shows every row again
	NSTextField *value = [self.content valueForKey:@"filterValueField"];
	[value setStringValue:@""];
	[self.content applyFilter:nil];
	[self waitForTab];
	XCTAssertEqual([[self valuesOfColumn:@"id"] count], 4u);
}

- (void)testFollowingIntoAnotherSchemaSwitchesTheSidebar
{
	[self selectTable:@"customer" inSchema:@"sp_fk_a"];
	NSInteger row = [self rowWhereColumn:@"id" is:@"4"];

	[self.content followForeignKeyAtRow:row column:[self indexOfColumn:@"region"]];
	[self waitForTab];
	XCTAssertTrue([self spinUntil:^BOOL{ return [self.content.table isEqualToString:@"region"]; } timeout:10]);
	[self waitForTab];

	XCTAssertEqualObjects(self.document.sidebar.selectedSchema, @"sp_fk_b");
	XCTAssertEqualObjects(self.document.sidebar.selectedTableName, @"region");
	XCTAssertEqualObjects(self.content.schema, @"sp_fk_b");
	XCTAssertEqualObjects([self valuesOfColumn:@"code"], @[@"eu"]);
	XCTAssertEqualObjects([self filterBarText], @"code = eu");
	XCTAssertEqual([self.alerts count], 0u);
}

- (void)testASelfReferenceFiltersTheSameTable
{
	[self selectTable:@"orders" inSchema:@"sp_fk_a"];
	NSInteger row = [self rowWhereColumn:@"id" is:@"11"];

	[self.content followForeignKeyAtRow:row column:[self indexOfColumn:@"parent_id"]];
	[self waitForTab];

	XCTAssertEqualObjects(self.content.table, @"orders");
	XCTAssertEqualObjects([self valuesOfColumn:@"id"], @[@"10"]);
	XCTAssertEqualObjects([self filterBarText], @"id = 10");
	XCTAssertTrue(self.content.filterBarVisible);
}

- (void)testATwoColumnKeyFollowsItsFirstColumn
{
	[self selectTable:@"line" inSchema:@"sp_fk_a"];
	[self.content followForeignKeyAtRow:0 column:[self indexOfColumn:@"order_id"]];
	[self waitForTab];

	XCTAssertEqualObjects(self.content.table, @"orders");
	XCTAssertEqualObjects([self valuesOfColumn:@"id"], @[@"11"]);
}

- (void)testNullAndPlainColumnsDoNothing
{
	[self selectTable:@"orders" inSchema:@"sp_fk_a"];
	NSInteger row = [self rowWhereColumn:@"id" is:@"12"];

	[self.content followForeignKeyAtRow:row column:[self indexOfColumn:@"customer_id"]];
	[self.content followForeignKeyAtRow:row column:[self indexOfColumn:@"note"]];
	[self waitForTab];

	XCTAssertEqualObjects(self.content.table, @"orders");
	XCTAssertEqual([[self valuesOfColumn:@"id"] count], 3u);
	XCTAssertFalse(self.content.filterBarVisible);
}

- (void)testFollowingIsAPlaceInHistory
{
	[self selectTable:@"orders" inSchema:@"sp_fk_a"];
	[self.content followForeignKeyAtRow:[self rowWhereColumn:@"id" is:@"11"] column:[self indexOfColumn:@"customer_id"]];
	[self waitForTab];
	XCTAssertEqualObjects(self.content.table, @"customer");

	// A place in History, as a click in the sidebar: the one before it is the table the link was followed from
	XCTAssertEqualObjects([self.document.history.currentEntry objectForKey:@"table"], @"customer");
	XCTAssertTrue(self.document.history.canGoBack);
	NSDictionary *previous = [self.document.history goBack];
	XCTAssertEqualObjects([previous objectForKey:@"table"], @"orders");
}

#pragma mark - The real arrow

- (void)testClickingTheArrowFollowsTheLink
{
	[[self.controller window] makeKeyAndOrderFront:nil];
	[self selectTable:@"orders" inSchema:@"sp_fk_a"];
	NSInteger row = [self rowWhereColumn:@"id" is:@"10"];
	NSTableColumn *tableColumn = [self tableColumnNamed:@"customer_id"];
	NSInteger columnIndex = [[[self grid] tableColumns] indexOfObject:tableColumn];
	[[self grid] scrollRowToVisible:row];
	[[self grid] scrollColumnToVisible:columnIndex];
	[[self grid] displayIfNeeded];

	// The arrow is drawn in the last 18 pt of the cell
	NSRect cellFrame = [[self grid] frameOfCellAtColumn:columnIndex row:row];
	NSPoint inGrid = NSMakePoint(NSMaxX(cellFrame) - 9, NSMidY(cellFrame));
	NSPoint inWindow = [[self grid] convertPoint:inGrid toView:nil];
	NSWindow *window = [self.controller window];

	NSEvent *down = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:inWindow modifierFlags:0 timestamp:[NSProcessInfo processInfo].systemUptime
								   windowNumber:[window windowNumber] context:nil eventNumber:1 clickCount:1 pressure:1];
	NSEvent *up = [NSEvent mouseEventWithType:NSEventTypeLeftMouseUp location:inWindow modifierFlags:0 timestamp:[NSProcessInfo processInfo].systemUptime
								 windowNumber:[window windowNumber] context:nil eventNumber:2 clickCount:1 pressure:0];
	[NSApp postEvent:up atStart:NO];
	[[self grid] mouseDown:down];
	[self waitForTab];

	XCTAssertEqualObjects(self.content.table, @"customer");
	XCTAssertEqualObjects([self valuesOfColumn:@"id"], @[@"2"]);
}

@end
