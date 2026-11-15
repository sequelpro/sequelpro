#import <XCTest/XCTest.h>
#import "../Source/Postgres/SPPostgresProgressSheet.h"

/// The progress sheet always ends its sheet, also when it was still queued behind another sheet.
@interface SPPostgresProgressSheetTests : XCTestCase
@end

@implementation SPPostgresProgressSheetTests

- (BOOL)spinUntil:(BOOL (^)(void))condition timeout:(NSTimeInterval)timeout
{
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
	while (!condition() && [deadline timeIntervalSinceNow] > 0) {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
	}
	return condition();
}

- (void)spinFor:(NSTimeInterval)seconds
{
	[self spinUntil:^BOOL{ return NO; } timeout:seconds];
}

- (NSWindow *)makeWindow
{
	NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(-5000, -5000, 600, 400) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
	[window setReleasedWhenClosed:NO];
	[window orderFront:nil];
	return window;
}

/// Pins the behaviour, but passes on the old code too on this macOS (sheetParent is set while the sheet is queued),
/// so it isn't a RED proof.
- (void)testEndWhileQueuedLeavesNoSheet
{
	NSWindow *window = [self makeWindow];
	NSPanel *first = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 200, 100) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
	[first setReleasedWhenClosed:NO];
	[window beginSheet:first completionHandler:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet == first; } timeout:5]);

	SPPostgresProgressSheet *progress = [SPPostgresProgressSheet beginOnWindow:window title:@"Queued"];
	[progress end];
	[window endSheet:first];

	[self spinFor:2];
	XCTAssertNil(window.attachedSheet, @"the queued progress sheet must not attach after -end");
	XCTAssertFalse([[progress panel] isVisible]);
	[window close];
}

/// Pins the behaviour, but passes on the old code too on this macOS (sheetParent is set while the sheet is queued),
/// so it isn't a RED proof.
- (void)testEndWhileQueuedAfterSpinLeavesNoSheet
{
	NSWindow *window = [self makeWindow];
	NSPanel *first = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 200, 100) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
	[first setReleasedWhenClosed:NO];
	[window beginSheet:first completionHandler:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet == first; } timeout:5]);

	SPPostgresProgressSheet *progress = [SPPostgresProgressSheet beginOnWindow:window title:@"Queued"];
	[self spinFor:0.2];
	[progress end];
	[window endSheet:first];

	[self spinFor:2];
	XCTAssertNil(window.attachedSheet, @"the queued progress sheet must not attach after -end");
	XCTAssertFalse([[progress panel] isVisible]);
	[window close];
}

- (void)testEndAfterAttachEndsSheet
{
	NSWindow *window = [self makeWindow];
	SPPostgresProgressSheet *progress = [SPPostgresProgressSheet beginOnWindow:window title:@"Attached"];
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet == [progress panel]; } timeout:5]);
	[progress end];
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet == nil; } timeout:5]);
	[window close];
}

#pragma mark - Task list

/// Tasks start in order (each earlier one done), from any thread, shown at most ~10 times a second; never back.
- (void)testTasksAreMarkedAsTheyRun
{
	NSWindow *window = [self makeWindow];
	SPPostgresProgressSheet *progress = [SPPostgresProgressSheet beginOnWindow:window title:@"Transferring" tasks:@[@"Connect", @"Check", @"Read", @"Write"]];
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet == progress.panel; } timeout:5]);
	XCTAssertEqualObjects(progress.taskTitles, (@[@"Connect", @"Check", @"Read", @"Write"]));
	XCTAssertEqualObjects([progress.taskTitleFields valueForKey:@"stringValue"], (@[@"Connect", @"Check", @"Read", @"Write"]));
	XCTAssertEqualObjects(progress.taskStates, (@[@(SPPostgresTaskPending), @(SPPostgresTaskPending), @(SPPostgresTaskPending), @(SPPostgresTaskPending)]));
	// Rows don't overlap each other, the status line or the button, and are inside the sheet
	NSRect bounds = progress.panel.contentView.bounds;
	for (NSUInteger i = 0; i < progress.taskTitleFields.count; i++) {
		NSRect row = progress.taskTitleFields[i].frame;
		XCTAssertTrue(NSContainsRect(bounds, row));
		XCTAssertFalse(NSIntersectsRect(row, progress.statusField.frame));
		XCTAssertFalse(NSIntersectsRect(row, progress.cancelButton.frame));
		if (i) XCTAssertFalse(NSIntersectsRect(row, progress.taskTitleFields[i - 1].frame));
	}

	[progress setTask:0 status:@"Connecting…" fraction:0];
	XCTAssertTrue([self spinUntil:^BOOL{ return [progress.taskStates[0] integerValue] == SPPostgresTaskRunning; } timeout:2]);
	XCTAssertEqualObjects(progress.taskDetailFields[0].stringValue, @"Connecting…", @"the running task's line shows the status");
	XCTAssertTrue(progress.statusField.isHidden);
	[progress setSummary:@"Connected" forTask:0];

	// Skipping one marks it done too; from another thread
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		[progress setTask:2 status:@"Reading table 1 of 2: t" fraction:0.5];
	});
	XCTAssertTrue([self spinUntil:^BOOL{ return [progress.taskStates[2] integerValue] == SPPostgresTaskRunning; } timeout:2]);
	XCTAssertEqualObjects(progress.taskStates, (@[@(SPPostgresTaskDone), @(SPPostgresTaskDone), @(SPPostgresTaskRunning), @(SPPostgresTaskPending)]));
	XCTAssertEqualObjects(progress.taskDetailFields[2].stringValue, @"Reading table 1 of 2: t");
	XCTAssertEqualObjects(progress.taskDetailFields[0].stringValue, @"Connected", @"a done task shows its summary");
	XCTAssertEqualObjects(progress.taskDetailFields[1].stringValue, @"", @"no summary given");
	XCTAssertEqualObjects(progress.taskDetailFields[3].stringValue, @"");
	// A summary given after the task is done shows too
	[progress setSummary:@"Checked" forTask:1];
	XCTAssertTrue([self spinUntil:^BOOL{ return [progress.taskDetailFields[1].stringValue isEqualToString:@"Checked"]; } timeout:2]);
	XCTAssertEqualWithAccuracy(progress.progressIndicator.doubleValue, 0.5, 0.001);

	// Never back
	[progress setTask:1 status:@"late" fraction:-1];
	[self spinFor:0.3];
	XCTAssertEqualObjects(progress.taskStates, (@[@(SPPostgresTaskDone), @(SPPostgresTaskDone), @(SPPostgresTaskRunning), @(SPPostgresTaskPending)]));

	[progress end];
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet == nil; } timeout:5]);
	[window close];
}

/// A failure marks the running task failed and the later ones not run; the outcome stays until Close.
- (void)testFailureStaysOpenUntilClose
{
	NSWindow *window = [self makeWindow];
	SPPostgresProgressSheet *progress = [SPPostgresProgressSheet beginOnWindow:window title:@"Transferring" tasks:@[@"Connect", @"Check", @"Read", @"Write"]];
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet == progress.panel; } timeout:5]);
	__block NSUInteger handled = 0;
	progress.cancelHandler = ^{ handled++; };
	CGFloat heightBefore = NSHeight(progress.panel.frame);

	// The latest task asked for counts, even before it was shown
	[progress setTask:0 status:@"Connecting…" fraction:0];
	[progress setTask:1 status:@"Checking…" fraction:0];
	[progress setSummary:@"Connected" forTask:0];
	[progress finishWithSuccess:NO message:@"The transfer failed." text:@"Objects are in the way:\npublic.report"];
	XCTAssertEqualObjects([progress.taskDetailFields valueForKey:@"stringValue"], (@[@"Connected", @"Checking…", @"", @""]), @"the failed task keeps what it was doing");
	XCTAssertTrue(progress.finished);
	XCTAssertEqualObjects(progress.taskStates, (@[@(SPPostgresTaskDone), @(SPPostgresTaskFailed), @(SPPostgresTaskNotRun), @(SPPostgresTaskNotRun)]));
	XCTAssertEqualObjects(progress.resultMessageField.stringValue, @"The transfer failed.");
	XCTAssertEqualObjects(progress.resultTextView.string, @"Objects are in the way:\npublic.report");
	XCTAssertTrue(progress.statusField.isHidden);
	XCTAssertTrue(progress.progressIndicator.isHidden);
	XCTAssertGreaterThan(NSHeight(progress.panel.frame), heightBefore, @"room for the outcome");
	XCTAssertEqualObjects(progress.cancelButton.title, @"Close");
	XCTAssertTrue(progress.cancelButton.isEnabled);
	// The outcome is below the rows and above the button, inside the sheet
	NSRect bounds = progress.panel.contentView.bounds;
	NSRect textFrame = progress.resultTextView.enclosingScrollView.frame;
	XCTAssertTrue(NSContainsRect(bounds, progress.resultMessageField.frame));
	XCTAssertTrue(NSContainsRect(bounds, textFrame));
	XCTAssertGreaterThan(NSMinY(progress.taskTitleFields.lastObject.frame), NSMaxY(progress.resultMessageField.frame));
	XCTAssertGreaterThanOrEqual(NSMinY(progress.resultMessageField.frame), NSMaxY(textFrame));
	XCTAssertGreaterThan(NSMinY(textFrame), NSMaxY(progress.cancelButton.frame));
	XCTAssertGreaterThan(NSHeight(textFrame), 60);

	// Later updates and Cancel do nothing; it stays open
	[progress setTask:3 status:@"late" fraction:1];
	[progress cancel:nil];
	[self spinFor:0.3];
	XCTAssertFalse(progress.cancelled);
	XCTAssertEqual(handled, 0u);
	XCTAssertEqual([progress.taskStates[3] integerValue], SPPostgresTaskNotRun);
	XCTAssertEqual(window.attachedSheet, progress.panel);

	[progress.cancelButton performClick:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet == nil; } timeout:5]);
	[window close];
}

- (void)testSuccessMarksEveryTaskDone
{
	NSWindow *window = [self makeWindow];
	SPPostgresProgressSheet *progress = [SPPostgresProgressSheet beginOnWindow:window title:@"Transferring" tasks:@[@"Connect", @"Check", @"Read", @"Write"]];
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet == progress.panel; } timeout:5]);
	[progress setTask:3 status:@"Writing…" fraction:1];
	[self spinFor:0.3];
	[progress finishWithSuccess:YES message:@"Transfer complete" text:@"Copied 5 tables."];
	XCTAssertEqualObjects(progress.taskStates, (@[@(SPPostgresTaskDone), @(SPPostgresTaskDone), @(SPPostgresTaskDone), @(SPPostgresTaskDone)]));
	XCTAssertEqualObjects(progress.resultMessageField.stringValue, @"Transfer complete");
	XCTAssertEqualObjects(progress.cancelButton.keyEquivalent, @"\r");
	[progress close:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet == nil; } timeout:5]);
	[window close];
}

/// Without tasks (Export, Import) nothing changes: no rows, and finishing does nothing.
- (void)testPlainSheetHasNoTasks
{
	NSWindow *window = [self makeWindow];
	SPPostgresProgressSheet *progress = [SPPostgresProgressSheet beginOnWindow:window title:@"Exporting"];
	XCTAssertNil(progress.taskTitles);
	XCTAssertEqual(progress.taskStates.count, 0u);
	[progress finishWithSuccess:YES message:@"x" text:@"y"];
	XCTAssertFalse(progress.finished);
	XCTAssertEqualObjects(progress.cancelButton.title, @"Cancel");
	[progress end];
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet == nil; } timeout:5]);
	[window close];
}

/// A task running alongside (the transfer's Read) runs while the main sequence moves on, is done when it says so,
/// and can be the one that failed.
- (void)testTaskAlongside
{
	NSWindow *window = [self makeWindow];
	SPPostgresProgressSheet *progress = [SPPostgresProgressSheet beginOnWindow:window title:@"Transferring" tasks:@[@"Connect", @"Read", @"Create", @"Write"]];
	[progress setTaskRunsAlongside:1];
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet == progress.panel; } timeout:5]);
	[progress setTask:0 status:@"Connecting…" fraction:0];
	[progress setStatus:@"Reading table 1 of 3: a" forTaskAlongside:1];
	XCTAssertEqualObjects(progress.lastStatus, @"Reading table 1 of 3: a");
	[progress setTask:2 status:@"1: CREATE TABLE a" fraction:0];
	NSNumber *running = @(SPPostgresTaskRunning), *done = @(SPPostgresTaskDone), *pending = @(SPPostgresTaskPending);
	XCTAssertTrue([self spinUntil:^BOOL{ return [progress.taskStates isEqualToArray:(@[done, running, running, pending])]; } timeout:2], @"%@", progress.taskStates);
	XCTAssertEqualObjects(progress.taskDetailFields[1].stringValue, @"Reading table 1 of 3: a");
	XCTAssertEqualObjects(progress.taskDetailFields[2].stringValue, @"1: CREATE TABLE a");

	// Moving on doesn't finish it; it says so itself
	[progress setTask:3 status:@"Table 1 of 3" fraction:0];
	[progress setStatus:@"Reading table 3 of 3: c" forTaskAlongside:1];
	XCTAssertTrue([self spinUntil:^BOOL{ return [progress.taskStates isEqualToArray:(@[done, running, done, running])]; } timeout:2], @"%@", progress.taskStates);
	XCTAssertEqualObjects(progress.taskDetailFields[1].stringValue, @"Reading table 3 of 3: c");

	// It fails: the main task stops (not run), the done ones stay done
	[progress finishWithSuccess:NO failedTask:1 message:@"The transfer failed." text:@"terminating connection"];
	XCTAssertEqualObjects(progress.taskStates, (@[done, @(SPPostgresTaskFailed), done, @(SPPostgresTaskNotRun)]));
	XCTAssertEqualObjects(progress.taskDetailFields[1].stringValue, @"Reading table 3 of 3: c", @"what it was doing");
	[progress close:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet == nil; } timeout:5]);

	// Done alongside, then all done
	SPPostgresProgressSheet *second = [SPPostgresProgressSheet beginOnWindow:window title:@"Transferring" tasks:@[@"Connect", @"Read", @"Create"]];
	[second setTaskRunsAlongside:1];
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet == second.panel; } timeout:5]);
	[second setTask:2 status:@"1: CREATE TABLE a" fraction:0];
	[second setStatus:@"Reading…" forTaskAlongside:1];
	[second setSummary:@"3 tables, 9 rows" forTask:1];
	[second finishTaskAlongside:1];
	XCTAssertTrue([self spinUntil:^BOOL{ return [second.taskStates[1] isEqual:done]; } timeout:2], @"%@", second.taskStates);
	XCTAssertEqualObjects(second.taskDetailFields[1].stringValue, @"3 tables, 9 rows");
	XCTAssertEqualObjects(second.taskStates[2], running);
	[second finishWithSuccess:YES message:@"Transfer complete" text:@""];
	XCTAssertEqualObjects(second.taskStates, (@[done, done, done]));
	[second close:nil];
	XCTAssertTrue([self spinUntil:^BOOL{ return window.attachedSheet == nil; } timeout:5]);
	[window close];
}

@end
