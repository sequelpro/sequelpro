#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "../Source/SPWindowController.h"

@interface NSObject (SPMySQLContentEditingTests)
- (id)connectionController;
- (void)closeEditSheet:(id)sender;
- (void)initiateConnection:(id)sender;
- (id)getConnection;
- (BOOL)isConnected;
- (BOOL)isWorking;
- (id)queryString:(NSString *)query;
- (NSArray *)getRowAsArray;
- (BOOL)queryErrored;
- (NSString *)lastErrorMessage;
- (void)loadTable:(NSString *)table ofType:(NSInteger)type;
- (void)viewContent:(id)sender;
- (id)tableContentInstance;
- (void)reloadTable:(id)sender;
- (void)updateTables:(id)sender;
- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)column row:(NSInteger)row;
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)column row:(NSInteger)row;
@end

static NSString * const SPTestEditInSheetEnabled = @"EditInSheetEnabled";

/**
 * Editing cells of a MySQL table's Content grid, on a real server: the throwaway docker container sp-mysql8
 * (`docker run -d --name sp-mysql8 -p 127.0.0.1:55438:3306 -e MYSQL_ROOT_PASSWORD=sptest -e MYSQL_DATABASE=sp_test
 * -e MYSQL_USER=sp_test -e MYSQL_PASSWORD=sptest mysql:8.0.44`). Skipped when it isn't running.
 *
 * Table `content_edit`: id INT PRIMARY KEY, a VARCHAR(300), t TEXT, n VARCHAR(50) (holding a line break), b VARCHAR(50).
 */
@interface SPMySQLFieldEditorSheetTests : XCTestCase
@property (strong) id document;
@property (strong) id content;
@property (strong) NSTableView *grid;
@end

@implementation SPMySQLFieldEditorSheetTests

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
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

/// Types `characters` as a real key event, dequeued so it is NSApp's current event while it is handled (as the
/// table content re-sends it to the sheet it opens).
- (void)typeKey:(NSString *)characters
{
	NSWindow *window = [self.grid window];
	NSEvent *key = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:[[NSProcessInfo processInfo] systemUptime] windowNumber:[window windowNumber] context:nil characters:characters charactersIgnoringModifiers:characters isARepeat:NO keyCode:7];
	[NSApp postEvent:key atStart:YES];
	NSEvent *event = [NSApp nextEventMatchingMask:NSEventMaskKeyDown untilDate:[NSDate dateWithTimeIntervalSinceNow:1] inMode:NSDefaultRunLoopMode dequeue:YES];
	XCTAssertNotNil(event);
	[window sendEvent:event];
	[self spin:0.3];
}

- (NSTableColumn *)column:(NSString *)name
{
	for (NSTableColumn *column in [self.grid tableColumns]) {
		if ([[[column headerCell] stringValue] isEqualToString:name]) return column;
	}
	return nil;
}

- (NSInteger)gridIndexOf:(NSString *)name
{
	return [[self.grid tableColumns] indexOfObject:[self column:name]];
}

- (id)savedValueOf:(NSString *)name
{
	return [[[[self.document getConnection] queryString:[NSString stringWithFormat:@"SELECT CAST(%@ AS CHAR) FROM content_edit", name]] getRowAsArray] firstObject];
}

/// A window with a MySQL tab on sp_test, showing content_edit's one row (nothing when there's no server).
- (void)setUp
{
	[super setUp];
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	BOOL sheetPref = [prefs boolForKey:SPTestEditInSheetEnabled];
	[prefs setBool:NO forKey:SPTestEditInSheetEnabled];

	SPWindowController *controller = [[SPWindowController alloc] initWithWindowNibName:@"MainWindow"];
	[controller showWindow:nil];
	id mysql = [controller addNewConnection];
	self.document = mysql;
	[self spin:0.3];
	__weak SPMySQLFieldEditorSheetTests *weakSelf = self;
	[self addTeardownBlock:^{
		[prefs setBool:sheetPref forKey:SPTestEditInSheetEnabled];
		NSWindow *window = [controller window];
		while (window.attachedSheet) [window endSheet:window.attachedSheet];
		if ([[mysql getConnection] isConnected]) [[mysql getConnection] queryString:@"DROP TABLE IF EXISTS content_edit"];
		NSTabView *tabView = [controller valueForKey:@"tabView"];
		for (NSTabViewItem *item in [tabView tabViewItems]) [tabView removeTabViewItem:item];
		[window orderOut:nil];
		[weakSelf spin:0.5];
	}];

	id form = [mysql connectionController];
	[form setValue:@0 forKey:@"type"]; // SPTCPIPConnection
	[form setValue:@"127.0.0.1" forKey:@"host"];
	[form setValue:@"55438" forKey:@"port"];
	[form setValue:@"sp_test" forKey:@"user"];
	[form setValue:@"sptest" forKey:@"password"];
	[form setValue:@"sp_test" forKey:@"database"];
	[form initiateConnection:nil];
	if (![self spinUntil:^BOOL{ return [[mysql getConnection] isConnected] && ![mysql isWorking]; } timeout:20]) {
		for (NSWindow *window in [NSApp windows]) if ([window attachedSheet]) [window endSheet:[window attachedSheet]];
		return;
	}

	id connection = [mysql getConnection];
	[connection queryString:@"DROP TABLE IF EXISTS content_edit"];
	[connection queryString:@"CREATE TABLE content_edit (id INT PRIMARY KEY, a VARCHAR(300), t TEXT, n VARCHAR(50), b VARCHAR(50))"];
	[connection queryString:@"INSERT INTO content_edit VALUES (1, 'old a', 'old t', 'old\\nn', 'old b')"];
	XCTAssertFalse([connection queryErrored], @"%@", [connection lastErrorMessage]);
	[[mysql valueForKey:@"tablesListInstance"] updateTables:nil];

	[mysql loadTable:@"content_edit" ofType:0]; // SPTableTypeTable
	[mysql viewContent:nil];
	self.content = [mysql tableContentInstance];
	self.grid = [self.content valueForKey:@"tableContentView"];
	XCTAssertTrue([self spinUntil:^BOOL{ return ![mysql isWorking] && [weakSelf.grid numberOfRows] == 1; } timeout:20]);
	[[controller window] makeKeyAndOrderFront:nil];
	[self.grid selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
}

- (BOOL)connected
{
	return [[self.document getConnection] isConnected] && self.grid;
}

/// The grid in another order than the table's: `t` (TEXT) dragged in front of `a`, so a's grid position is t's index.
- (void)moveTextColumnToTheFront
{
	[self.grid moveColumn:[self gridIndexOf:@"t"] toColumn:1];
	XCTAssertEqual([self gridIndexOf:@"t"], 1);
	XCTAssertEqual([self gridIndexOf:@"a"], 2);
}

- (void)testTypingInACellBesideAMovedTextColumnEditsInPlace
{
	if (![self connected]) { XCTSkip(@"no MySQL test server on 127.0.0.1:55438 (docker sp-mysql8)"); }
	[self moveTextColumnToTheFront];

	// Typing into a's in-place editor: a is a single-line VARCHAR, so it stays in place (the TEXT column whose
	// index is a's grid position must not decide that: that cancelled the edit and dropped the key)
	NSInteger a = [self gridIndexOf:@"a"];
	[self.grid editColumn:a row:0 withEvent:nil select:YES];
	[self typeKey:@"x"];
	XCTAssertNil([self.content valueForKey:@"fieldEditor"], @"no sheet");
	XCTAssertEqual([self.grid editedColumn], a, @"still editing a in place");
	XCTAssertEqualObjects([[[self.grid window] fieldEditor:NO forObject:self.grid] string], @"x", @"the key typed");

	// Saved as typed
	[[self.grid window] makeFirstResponder:self.grid];
	[self.grid deselectAll:nil];
	[self spin:0.3];
	XCTAssertEqualObjects([self savedValueOf:@"a"], @"x");
	XCTAssertEqualObjects([self savedValueOf:@"t"], @"old t");
}

- (void)testInPlaceEditOfAMovedColumnStartsFromTheWholeValue
{
	if (![self connected]) { XCTSkip(@"no MySQL test server on 127.0.0.1:55438 (docker sp-mysql8)"); }
	// A value longer than the grid's 150-character preview
	NSString *longValue = [@"" stringByPaddingToLength:200 withString:@"0123456789" startingAtIndex:0];
	[[self.document getConnection] queryString:[NSString stringWithFormat:@"UPDATE content_edit SET a = '%@'", longValue]];
	[self.content reloadTable:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return ![self.document isWorking] && [self.grid numberOfRows] == 1; } timeout:20]);
	[self.grid selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	[self moveTextColumnToTheFront];

	[self.grid editColumn:[self gridIndexOf:@"a"] row:0 withEvent:nil select:YES];
	XCTAssertEqualObjects([[[self.grid window] fieldEditor:NO forObject:self.grid] string], longValue, @"the whole value, not the preview");

	// Ending the edit unchanged saves nothing shorter
	[[self.grid window] makeFirstResponder:self.grid];
	[self.grid deselectAll:nil];
	[self spin:0.3];
	XCTAssertEqualObjects([self savedValueOf:@"a"], longValue);
}

- (void)testSheetEditOfAValueWithALineBreakSurvivesClickingAnotherField
{
	if (![self connected]) { XCTSkip(@"no MySQL test server on 127.0.0.1:55438 (docker sp-mysql8)"); }
	// n holds a line break, so typing into it opens the pop-up sheet (with "Edit All Fields in Pop-up Sheet" off)
	NSTableColumn *n = [self column:@"n"];
	[self.grid editColumn:[self gridIndexOf:@"n"] row:0 withEvent:nil select:YES];
	[self typeKey:@"x"];
	id sheet = [self.content valueForKey:@"fieldEditor"];
	XCTAssertNotNil(sheet);
	NSTextView *text = [sheet valueForKey:@"editTextView"];
	[[text window] makeFirstResponder:text];
	[text selectAll:nil];
	[text deleteBackward:nil];
	NSString *value = @"new\nn";
	for (NSUInteger c = 0; c < [value length]; c++) [text insertText:[value substringWithRange:NSMakeRange(c, 1)] replacementRange:[text selectedRange]];
	[sheet closeEditSheet:[sheet valueForKey:@"editSheetOkButton"]];
	[self spin:0.3];
	XCTAssertEqualObjects([self.content tableView:self.grid objectValueForTableColumn:n row:0], value);

	// A click on b of the same row: asked, then edited in place, which ends n's edit
	NSTableColumn *b = [self column:@"b"];
	XCTAssertTrue([self.content tableView:self.grid shouldEditTableColumn:b row:0]);
	[self.grid editColumn:[self gridIndexOf:@"b"] row:0 withEvent:nil select:YES];
	[self spin:0.3];
	XCTAssertEqualObjects([self.content tableView:self.grid objectValueForTableColumn:n row:0], value);

	[[self.grid window] makeFirstResponder:self.grid];
	[self.grid deselectAll:nil];
	[self spin:0.3];
	XCTAssertEqualObjects([self savedValueOf:@"n"], value);
}

@end
