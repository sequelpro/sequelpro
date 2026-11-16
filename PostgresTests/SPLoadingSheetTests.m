#import <XCTest/XCTest.h>
#import "../Source/SPLoadingSheet.h"

/// SPLoadingSheet ("Loading users…" before the User Manager): on a window of its own.
@interface SPLoadingSheetTests : XCTestCase
@property (strong) NSWindow *window;
@end

@implementation SPLoadingSheetTests

- (BOOL)spinUntil:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout
{
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
	while (!condition() && [deadline timeIntervalSinceNow] > 0) {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
	}
	return condition();
}

- (void)setUp
{
	self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(-10000, -10000, 600, 400) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
	self.window.releasedWhenClosed = NO;
}

- (void)tearDown
{
	while (self.window.attachedSheet) [self.window endSheet:self.window.attachedSheet];
	[self.window orderOut:nil];
	self.window = nil;
}

- (void)testShowsTheMessageWithASpinner
{
	SPLoadingSheet *sheet = [SPLoadingSheet beginOnWindow:self.window message:@"Loading users…" cancelHandler:nil];
	XCTAssertTrue(sheet.shown);
	XCTAssertEqual(self.window.attachedSheet, sheet.panel);
	XCTAssertEqualObjects(sheet.messageField.stringValue, @"Loading users…");
	XCTAssertEqual(sheet.spinner.style, NSProgressIndicatorStyleSpinning);
	XCTAssertTrue(sheet.spinner.usesThreadedAnimation, @"spins while the main thread waits");
	XCTAssertNil(sheet.cancelButton, @"no Cancel without a handler");

	[sheet end];
	XCTAssertFalse(sheet.shown);
	XCTAssertTrue([self spinUntil:^BOOL{ return self.window.attachedSheet == nil; } timeout:2]);
	[sheet end]; // again: nothing
}

- (void)testCancelEndsItThenCallsTheHandlerOnce
{
	__block NSUInteger calls = 0;
	__block NSWindow *sheetDuringHandler = (NSWindow *)[NSNull null];
	__weak SPLoadingSheetTests *weakSelf = self;
	SPLoadingSheet *sheet = [SPLoadingSheet beginOnWindow:self.window message:@"Loading users…" cancelHandler:^{
		calls++;
		sheetDuringHandler = weakSelf.window.attachedSheet;
	}];
	XCTAssertEqualObjects(sheet.cancelButton.title, @"Cancel");
	XCTAssertEqualObjects(sheet.cancelButton.keyEquivalent, @"\e");

	[sheet.cancelButton performClick:nil];
	XCTAssertEqual(calls, 1u);
	XCTAssertNil(sheetDuringHandler, @"ended before the handler runs");
	XCTAssertFalse(sheet.shown);
	[sheet cancel:nil];
	XCTAssertEqual(calls, 1u);
}

- (void)testEndDropsTheHandler
{
	__block NSUInteger calls = 0;
	SPLoadingSheet *sheet = [SPLoadingSheet beginOnWindow:self.window message:@"x" cancelHandler:^{ calls++; }];
	[sheet end];
	[sheet cancel:nil];
	XCTAssertEqual(calls, 0u);
}

- (void)testNotShownOnAWindowWithASheetOrNoWindow
{
	SPLoadingSheet *first = [SPLoadingSheet beginOnWindow:self.window message:@"first" cancelHandler:nil];
	SPLoadingSheet *second = [SPLoadingSheet beginOnWindow:self.window message:@"second" cancelHandler:nil];
	XCTAssertTrue(first.shown);
	XCTAssertFalse(second.shown);
	XCTAssertEqual(self.window.attachedSheet, first.panel);
	[second end];
	XCTAssertEqual(self.window.attachedSheet, first.panel, @"ending one never shown leaves the other");
	[first end];

	SPLoadingSheet *none = [SPLoadingSheet beginOnWindow:nil message:@"x" cancelHandler:nil];
	XCTAssertFalse(none.shown);
	[none end];
}

@end
