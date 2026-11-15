#import "SPPostgresProgressSheet.h"

/// At most about 10 updates a second
static const NSTimeInterval SPPostgresProgressSheetUpdateInterval = 0.1;

@interface SPPostgresProgressSheet ()
- (void)_buildWithTitle:(NSString *)title;
- (void)_buildWithTitle:(NSString *)title tasks:(NSArray *)tasks;
- (void)_showState:(SPPostgresTaskState)state ofTask:(NSUInteger)index;
- (void)_attachToWindow:(NSWindow *)window;
- (void)_applyPendingUpdate;
@end

@implementation SPPostgresProgressSheet
{
	NSPanel *panel;
	NSTextField *titleField;
	NSTextField *statusField;
	NSProgressIndicator *progressIndicator;
	NSButton *cancelButton;
	/// The window the sheet was begun on (retained until -end)
	NSWindow *parentWindow;

	/// Guards everything below (touched from any thread)
	NSLock *lock;
	BOOL cancelled;
	BOOL ended;
	BOOL updateScheduled;
	NSString *pendingStatus;
	double pendingFraction;
	NSTimeInterval lastUpdate;

	NSInteger pendingTask; // -1: none
	NSString *lastStatus;  // guarded by lock

	/// Main thread only
	void (^cancelHandler)(void);

	// The task list (nil without one); main thread only
	NSArray *taskTitles;
	NSMutableArray *taskTitleFields;
	NSMutableArray *taskDetailFields;
	NSMutableDictionary *summaries;        // task index -> summary shown once it's done (main thread)
	NSMutableDictionary *pendingSummaries; // guarded by lock
	NSMutableIndexSet *alongside;          // tasks running beside the main sequence (main thread)
	NSMutableDictionary *pendingAlongsideStatuses; // guarded by lock
	NSMutableIndexSet *pendingAlongsideDone;       // guarded by lock
	NSMutableArray *taskIconViews;
	NSMutableArray *taskSpinners;
	NSMutableArray *states;
	NSInteger currentTask; // -1: none started
	BOOL finished;
	NSTextField *resultMessageField;
	NSScrollView *resultScrollView;
	NSTextView *resultTextView;
}

@synthesize panel;
@synthesize titleField;
@synthesize statusField;
@synthesize progressIndicator;
@synthesize cancelButton;
@synthesize cancelHandler;
@synthesize taskTitles;
@synthesize taskTitleFields;
@synthesize taskDetailFields;
@synthesize finished;
@synthesize resultMessageField;
@synthesize resultTextView;

+ (instancetype)beginOnWindow:(NSWindow *)window title:(NSString *)title tasks:(NSArray<NSString *> *)tasks
{
	SPPostgresProgressSheet *sheet = [[[self alloc] init] autorelease];
	[sheet _buildWithTitle:title tasks:tasks ?: @[]];
	[sheet retain]; // until -end
	[sheet _attachToWindow:window];
	return sheet;
}

+ (instancetype)beginOnWindow:(NSWindow *)window title:(NSString *)title
{
	SPPostgresProgressSheet *sheet = [[[self alloc] init] autorelease];
	[sheet _buildWithTitle:title];
	[sheet retain]; // until -end
	[sheet _attachToWindow:window];
	return sheet;
}

- (instancetype)init
{
	if ((self = [super init])) {
		lock = [[NSLock alloc] init];
		pendingFraction = -1;
		pendingTask = -1;
		currentTask = -1;
	}
	return self;
}

- (void)dealloc
{
	[cancelButton setTarget:nil];
	[panel release];
	[titleField release];
	[statusField release];
	[progressIndicator release];
	[cancelButton release];
	[parentWindow release];
	[pendingStatus release];
	[lastStatus release];
	[cancelHandler release];
	for (NSProgressIndicator *spinner in taskSpinners) [spinner stopAnimation:nil];
	[taskTitles release];
	[taskTitleFields release];
	[taskDetailFields release];
	[summaries release];
	[pendingSummaries release];
	[alongside release];
	[pendingAlongsideStatuses release];
	[pendingAlongsideDone release];
	[taskIconViews release];
	[taskSpinners release];
	[states release];
	[resultMessageField release];
	[resultScrollView release];
	[resultTextView release];
	[lock release];
	[super dealloc];
}

- (NSTextField *)_labelWithFrame:(NSRect)frame font:(NSFont *)font
{
	NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
	[label setEditable:NO];
	[label setSelectable:NO];
	[label setBezeled:NO];
	[label setDrawsBackground:NO];
	[label setFont:font];
	[label setLineBreakMode:NSLineBreakByTruncatingMiddle];
	[label setAutoresizingMask:NSViewWidthSizable];
	return label;
}

- (void)_buildWithTitle:(NSString *)title
{
	CGFloat width = 440, height = 128;
	panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, width, height) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
	[panel setReleasedWhenClosed:NO];
	NSView *content = [panel contentView];

	titleField = [[self _labelWithFrame:NSMakeRect(20, height - 36, width - 40, 18) font:[NSFont boldSystemFontOfSize:[NSFont systemFontSize]]] retain];
	[titleField setStringValue:title ?: @""];
	[content addSubview:titleField];

	statusField = [[self _labelWithFrame:NSMakeRect(20, height - 58, width - 40, 16) font:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]] retain];
	[statusField setStringValue:@""];
	[content addSubview:statusField];

	progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(20, height - 82, width - 40, 20)];
	[progressIndicator setStyle:NSProgressIndicatorStyleBar];
	[progressIndicator setIndeterminate:NO];
	[progressIndicator setMinValue:0];
	[progressIndicator setMaxValue:1];
	[progressIndicator setDoubleValue:0];
	[progressIndicator setAutoresizingMask:NSViewWidthSizable];
	[content addSubview:progressIndicator];

	cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(width - 20 - 96, 12, 96, 32)];
	[cancelButton setBezelStyle:NSBezelStyleRounded];
	[cancelButton setTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	[cancelButton setKeyEquivalent:@"\e"];
	[cancelButton setTarget:self];
	[cancelButton setAction:@selector(cancel:)];
	[cancelButton setAutoresizingMask:NSViewMinXMargin];
	[content addSubview:cancelButton];
}

/// Rows of tasks under the title, then the running task's status line and bar, then Cancel.
- (void)_buildWithTitle:(NSString *)title tasks:(NSArray *)tasks
{
	CGFloat width = 480, rowHeight = 38;
	CGFloat rowsBottom = 90, rowsTop = rowsBottom + rowHeight * [tasks count];
	CGFloat height = rowsTop + 10 + 18 + 18;
	panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, width, height) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
	[panel setReleasedWhenClosed:NO];
	NSView *content = [panel contentView];

	titleField = [[self _labelWithFrame:NSMakeRect(20, height - 36, width - 40, 18) font:[NSFont boldSystemFontOfSize:[NSFont systemFontSize]]] retain];
	[titleField setStringValue:title ?: @""];
	[titleField setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
	[content addSubview:titleField];

	taskTitles = [tasks copy];
	taskTitleFields = [[NSMutableArray alloc] init];
	taskDetailFields = [[NSMutableArray alloc] init];
	summaries = [[NSMutableDictionary alloc] init];
	pendingSummaries = [[NSMutableDictionary alloc] init];
	alongside = [[NSMutableIndexSet alloc] init];
	pendingAlongsideStatuses = [[NSMutableDictionary alloc] init];
	pendingAlongsideDone = [[NSMutableIndexSet alloc] init];
	taskIconViews = [[NSMutableArray alloc] init];
	taskSpinners = [[NSMutableArray alloc] init];
	states = [[NSMutableArray alloc] init];
	[tasks enumerateObjectsUsingBlock:^(NSString *task, NSUInteger index, BOOL *stop) {
		CGFloat y = rowsTop - rowHeight * (index + 1);
		NSImageView *icon = [[[NSImageView alloc] initWithFrame:NSMakeRect(24, y + 19, 16, 16)] autorelease];
		[icon setImageScaling:NSImageScaleProportionallyUpOrDown];
		[icon setAutoresizingMask:NSViewMinYMargin];
		[content addSubview:icon];
		[taskIconViews addObject:icon];

		NSProgressIndicator *spinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(24, y + 19, 16, 16)] autorelease];
		[spinner setStyle:NSProgressIndicatorStyleSpinning];
		[spinner setControlSize:NSControlSizeSmall];
		[spinner setDisplayedWhenStopped:NO];
		[spinner setHidden:YES];
		[spinner setAutoresizingMask:NSViewMinYMargin];
		[content addSubview:spinner];
		[taskSpinners addObject:spinner];

		NSTextField *field = [self _labelWithFrame:NSMakeRect(48, y + 18, width - 48 - 20, 17) font:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
		[field setStringValue:task];
		[field setLineBreakMode:NSLineBreakByTruncatingTail];
		[field setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
		[content addSubview:field];
		[taskTitleFields addObject:field];

		// What the task is doing while it runs; what it did once done (or what it was doing when it failed)
		NSTextField *detail = [self _labelWithFrame:NSMakeRect(48, y + 3, width - 48 - 20, 15) font:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		[detail setStringValue:@""];
		[detail setTextColor:[NSColor secondaryLabelColor]];
		[detail setLineBreakMode:NSLineBreakByTruncatingMiddle];
		[detail setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
		[content addSubview:detail];
		[taskDetailFields addObject:detail];

		[states addObject:@(SPPostgresTaskPending)];
		[self _showState:SPPostgresTaskPending ofTask:index];
	}];

	// The running task's row shows the status; this line stays hidden (it holds the status too)
	statusField = [[self _labelWithFrame:NSMakeRect(20, 82, width - 40, 16) font:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]] retain];
	[statusField setStringValue:@""];
	[statusField setHidden:YES];
	[content addSubview:statusField];

	progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(20, 56, width - 40, 20)];
	[progressIndicator setStyle:NSProgressIndicatorStyleBar];
	[progressIndicator setIndeterminate:NO];
	[progressIndicator setMinValue:0];
	[progressIndicator setMaxValue:1];
	[progressIndicator setDoubleValue:0];
	[progressIndicator setAutoresizingMask:NSViewWidthSizable];
	[content addSubview:progressIndicator];

	cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(width - 20 - 96, 12, 96, 32)];
	[cancelButton setBezelStyle:NSBezelStyleRounded];
	[cancelButton setTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	[cancelButton setKeyEquivalent:@"\e"];
	[cancelButton setTarget:self];
	[cancelButton setAction:@selector(cancel:)];
	[cancelButton setAutoresizingMask:NSViewMinXMargin];
	[content addSubview:cancelButton];
}

#pragma mark - Tasks

- (NSArray<NSNumber *> *)taskStates
{
	return [[states copy] autorelease];
}

- (void)_showState:(SPPostgresTaskState)state ofTask:(NSUInteger)index
{
	if (index >= [states count]) return;
	[states replaceObjectAtIndex:index withObject:@(state)];

	NSImageView *icon = [taskIconViews objectAtIndex:index];
	NSProgressIndicator *spinner = [taskSpinners objectAtIndex:index];
	NSTextField *field = [taskTitleFields objectAtIndex:index];

	NSString *symbol = nil;
	NSColor *tint = nil;
	NSString *description = nil;
	switch (state) {
		case SPPostgresTaskPending:
			symbol = @"circle"; tint = [NSColor tertiaryLabelColor];
			description = NSLocalizedString(@"Not started", @"Postgres task list: task state");
			break;
		case SPPostgresTaskRunning:
			description = NSLocalizedString(@"In progress", @"Postgres task list: task state");
			break;
		case SPPostgresTaskDone:
			symbol = @"checkmark.circle.fill"; tint = [NSColor systemGreenColor];
			description = NSLocalizedString(@"Done", @"Postgres task list: task state");
			break;
		case SPPostgresTaskFailed:
			symbol = @"xmark.circle.fill"; tint = [NSColor systemRedColor];
			description = NSLocalizedString(@"Failed", @"Postgres task list: task state");
			break;
		case SPPostgresTaskNotRun:
			symbol = @"minus.circle"; tint = [NSColor tertiaryLabelColor];
			description = NSLocalizedString(@"Not run", @"Postgres task list: task state");
			break;
	}

	if (state == SPPostgresTaskRunning) {
		[icon setHidden:YES];
		[spinner setHidden:NO];
		[spinner startAnimation:nil];
	}
	else {
		[spinner stopAnimation:nil];
		[spinner setHidden:YES];
		[icon setImage:[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:description]];
		[icon setContentTintColor:tint];
		[icon setHidden:NO];
	}
	NSTextField *detail = [taskDetailFields objectAtIndex:index];
	if (state == SPPostgresTaskPending || state == SPPostgresTaskNotRun) [detail setStringValue:@""];
	else if (state == SPPostgresTaskDone) [detail setStringValue:[summaries objectForKey:@(index)] ?: @""];
	[detail setToolTip:[detail stringValue]];
	[field setTextColor:(state == SPPostgresTaskPending || state == SPPostgresTaskNotRun) ? [NSColor secondaryLabelColor] : [NSColor labelColor]];
	[field setFont:(state == SPPostgresTaskRunning) ? [NSFont boldSystemFontOfSize:[NSFont systemFontSize]] : [NSFont systemFontOfSize:[NSFont systemFontSize]]];
	[field setToolTip:description];
}

/// Main thread: the tasks before index are done, index runs (never back to an earlier task).
- (void)_startTask:(NSInteger)index
{
	if (index <= currentTask || index >= (NSInteger)[states count]) return;
	for (NSInteger i = MAX(currentTask, 0); i < index; i++) {
		// A task running alongside is done when it says so
		if ([alongside containsIndex:(NSUInteger)i]) continue;
		[self _showState:SPPostgresTaskDone ofTask:(NSUInteger)i];
	}
	currentTask = index;
	[self _showState:SPPostgresTaskRunning ofTask:(NSUInteger)index];
}

- (void)setSummary:(NSString *)summary forTask:(NSUInteger)index
{
	[lock lock];
	[pendingSummaries setObject:[[summary copy] autorelease] ?: @"" forKey:@(index)];
	[lock unlock];
	[self setStatus:nil fraction:-1];
}

/// Main thread: the summaries asked for, shown on the tasks already done.
- (void)_applySummaries:(NSDictionary *)newSummaries
{
	for (NSNumber *index in newSummaries) {
		[summaries setObject:[newSummaries objectForKey:index] forKey:index];
		NSUInteger i = [index unsignedIntegerValue];
		if (i < [states count] && [[states objectAtIndex:i] integerValue] == SPPostgresTaskDone) [self _showState:SPPostgresTaskDone ofTask:i];
	}
}

- (NSString *)lastStatus
{
	[lock lock];
	NSString *status = [[lastStatus retain] autorelease];
	[lock unlock];
	return status;
}

- (void)setTaskRunsAlongside:(NSUInteger)index
{
	[alongside addIndex:index];
}

- (void)setStatus:(NSString *)status forTaskAlongside:(NSUInteger)index
{
	[lock lock];
	[pendingAlongsideStatuses setObject:[[status copy] autorelease] ?: @"" forKey:@(index)];
	[lastStatus release];
	lastStatus = [status copy];
	[lock unlock];
	[self setStatus:nil fraction:-1];
}

- (void)finishTaskAlongside:(NSUInteger)index
{
	[lock lock];
	[pendingAlongsideDone addIndex:index];
	[lock unlock];
	[self setStatus:nil fraction:-1];
}

/// Main thread: what the tasks running alongside asked for.
- (void)_applyAlongsideStatuses:(NSDictionary *)statuses done:(NSIndexSet *)done
{
	for (NSNumber *index in statuses) {
		NSUInteger i = [index unsignedIntegerValue];
		if (i >= [states count] || [done containsIndex:i]) continue;
		SPPostgresTaskState state = [[states objectAtIndex:i] integerValue];
		if (state == SPPostgresTaskDone || state == SPPostgresTaskFailed) continue;
		if (state != SPPostgresTaskRunning) [self _showState:SPPostgresTaskRunning ofTask:i];
		NSTextField *detail = [taskDetailFields objectAtIndex:i];
		[detail setStringValue:[statuses objectForKey:index]];
		[detail setToolTip:[detail stringValue]];
	}
	[done enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) {
		if (i < [states count]) [self _showState:SPPostgresTaskDone ofTask:i];
	}];
}

- (void)setTask:(NSUInteger)index status:(NSString *)status fraction:(double)fraction
{
	[lock lock];
	if ((NSInteger)index > pendingTask) pendingTask = (NSInteger)index;
	[lock unlock];
	[self setStatus:status fraction:fraction];
}

- (void)finishWithSuccess:(BOOL)success message:(NSString *)message text:(NSString *)text
{
	[self finishWithSuccess:success failedTask:-1 message:message text:text];
}

- (void)finishWithSuccess:(BOOL)success failedTask:(NSInteger)failedIndex message:(NSString *)message text:(NSString *)text
{
	if (finished || !taskTitles) return;
	[lock lock];
	BOOL isEnded = ended;
	NSInteger latest = pendingTask;
	NSDictionary *newSummaries = [[pendingSummaries copy] autorelease];
	[pendingSummaries removeAllObjects];
	NSString *latestStatus = [[pendingStatus retain] autorelease];
	NSDictionary *alongsideStatuses = [[pendingAlongsideStatuses copy] autorelease];
	[pendingAlongsideStatuses removeAllObjects];
	NSIndexSet *alongsideDone = [[pendingAlongsideDone copy] autorelease];
	[pendingAlongsideDone removeAllIndexes];
	[lock unlock];
	if (isEnded) return;
	for (NSNumber *index in newSummaries) [summaries setObject:[newSummaries objectForKey:index] forKey:index];
	[self _applyAlongsideStatuses:alongsideStatuses done:alongsideDone];
	finished = YES;

	// The latest task asked for, even if its update hasn't been shown yet
	if (latest > currentTask) [self _startTask:latest];
	NSInteger failedTask = (failedIndex >= 0) ? failedIndex : MAX(currentTask, 0);
	// The failed task keeps what it was doing (one running alongside: its own last status, already shown)
	if (!success && latestStatus && failedTask == MAX(currentTask, 0) && failedTask < (NSInteger)[taskDetailFields count]) [[taskDetailFields objectAtIndex:(NSUInteger)failedTask] setStringValue:latestStatus];
	NSArray *before = [[states copy] autorelease];
	for (NSUInteger i = 0; i < [states count]; i++) {
		SPPostgresTaskState state = SPPostgresTaskDone;
		if (!success) {
			// Done stays done; the rest (later tasks, one stopped alongside) didn't run to the end
			if ((NSInteger)i == failedTask) state = SPPostgresTaskFailed;
			else if ([[before objectAtIndex:i] integerValue] != SPPostgresTaskDone) state = SPPostgresTaskNotRun;
		}
		// (a failed task's line stays as it is)
		[self _showState:state ofTask:i];
	}

	// Room for the outcome where the status line and bar were
	CGFloat extra = 110;
	[statusField setHidden:YES];
	[progressIndicator setHidden:YES];
	NSRect frame = [panel frame];
	frame.size.height += extra;
	frame.origin.y -= extra;
	[panel setFrame:frame display:YES animate:NO];

	NSView *content = [panel contentView];
	CGFloat width = NSWidth([content bounds]);
	CGFloat rowsBottom = [taskDetailFields count] ? NSMinY([[taskDetailFields lastObject] frame]) - 3 : NSMaxY([statusField frame]) + extra;
	CGFloat messageY = rowsBottom - 10 - 18;

	resultMessageField = [[self _labelWithFrame:NSMakeRect(20, messageY, width - 40, 18) font:[NSFont boldSystemFontOfSize:[NSFont systemFontSize]]] retain];
	[resultMessageField setStringValue:message ?: @""];
	[resultMessageField setLineBreakMode:NSLineBreakByTruncatingTail];
	[resultMessageField setTextColor:success ? [NSColor labelColor] : [NSColor systemRedColor]];
	[resultMessageField setToolTip:message];
	[content addSubview:resultMessageField];

	CGFloat scrollBottom = 52;
	resultScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, scrollBottom, width - 40, messageY - 6 - scrollBottom)];
	[resultScrollView setHasVerticalScroller:YES];
	[resultScrollView setAutohidesScrollers:YES];
	[resultScrollView setBorderType:NSBezelBorder];
	[resultScrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	NSSize contentSize = [resultScrollView contentSize];
	resultTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, contentSize.width, contentSize.height)];
	[resultTextView setEditable:NO];
	[resultTextView setSelectable:YES];
	[resultTextView setRichText:NO];
	[resultTextView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[resultTextView setTextContainerInset:NSMakeSize(4, 4)];
	[resultTextView setVerticallyResizable:YES];
	[resultTextView setHorizontallyResizable:NO];
	[resultTextView setAutoresizingMask:NSViewWidthSizable];
	[[resultTextView textContainer] setWidthTracksTextView:YES];
	[resultTextView setString:text ?: @""];
	[resultScrollView setDocumentView:resultTextView];
	[content addSubview:resultScrollView];

	[cancelHandler release];
	cancelHandler = nil;
	[cancelButton setEnabled:YES];
	[cancelButton setTitle:NSLocalizedString(@"Close", @"Postgres task list: close the finished sheet")];
	[cancelButton setKeyEquivalent:@"\r"];
	[cancelButton setAction:@selector(close:)];
}

- (IBAction)close:(id)sender
{
	if (!finished) return;
	[self end];
}

- (void)_attachToWindow:(NSWindow *)window
{
	if (!window) return;
	parentWindow = [window retain];
	[window beginSheet:panel completionHandler:nil];
}

#pragma mark - Status

- (void)setStatus:(NSString *)status fraction:(double)fraction
{
	NSTimeInterval delay = 0;
	BOOL schedule = NO;

	[lock lock];
	if (!ended) {
		if (status) {
			[pendingStatus release];
			pendingStatus = [status copy];
			[lastStatus release];
			lastStatus = [status copy];
		}
		if (fraction >= 0) pendingFraction = MIN(fraction, 1.0);
		if (!updateScheduled) {
			updateScheduled = YES;
			schedule = YES;
			NSTimeInterval since = [NSDate timeIntervalSinceReferenceDate] - lastUpdate;
			delay = (since >= SPPostgresProgressSheetUpdateInterval) ? 0 : SPPostgresProgressSheetUpdateInterval - since;
		}
	}
	[lock unlock];

	if (!schedule) return;

	// The block keeps the sheet until it has run
	[self retain];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self _applyPendingUpdate];
		[self release];
	});
}

/// On the main thread: shows the latest status and fraction.
- (void)_applyPendingUpdate
{
	[lock lock];
	updateScheduled = NO;
	lastUpdate = [NSDate timeIntervalSinceReferenceDate];
	NSString *status = [[pendingStatus retain] autorelease];
	double fraction = pendingFraction;
	BOOL isEnded = ended;
	BOOL isCancelled = cancelled;
	NSInteger task = pendingTask;
	NSDictionary *newSummaries = [[pendingSummaries copy] autorelease];
	[pendingSummaries removeAllObjects];
	NSDictionary *alongsideStatuses = [[pendingAlongsideStatuses copy] autorelease];
	[pendingAlongsideStatuses removeAllObjects];
	NSIndexSet *alongsideDone = [[pendingAlongsideDone copy] autorelease];
	[pendingAlongsideDone removeAllIndexes];
	[lock unlock];

	if (isEnded || finished) return;
	if (taskTitles && task > currentTask) [self _startTask:task];
	if (taskTitles && ([alongsideStatuses count] || [alongsideDone count])) [self _applyAlongsideStatuses:alongsideStatuses done:alongsideDone];
	if ([newSummaries count]) [self _applySummaries:newSummaries];
	// The running task's row shows the status
	if (taskTitles && currentTask >= 0 && status && !isCancelled) {
		NSTextField *detail = [taskDetailFields objectAtIndex:(NSUInteger)currentTask];
		[detail setStringValue:status];
		[detail setToolTip:status];
	}
	// "Cancelling…" stays once Cancel was clicked
	if (status && !isCancelled) [statusField setStringValue:status];
	if (fraction >= 0) [progressIndicator setDoubleValue:fraction];
}

#pragma mark - Cancel

- (BOOL)cancelled
{
	[lock lock];
	BOOL result = cancelled;
	[lock unlock];
	return result;
}

- (IBAction)cancel:(id)sender
{
	// A finished task list has nothing to cancel (its button is Close)
	if (finished) return;
	[lock lock];
	BOOL already = cancelled || ended;
	cancelled = YES;
	[lock unlock];
	if (already) return;

	void (^show)(void) = ^{
		[cancelButton setEnabled:NO];
		[statusField setStringValue:NSLocalizedString(@"Cancelling…", @"Postgres progress sheet: cancelling")];
		if (taskTitles && currentTask >= 0) [[taskDetailFields objectAtIndex:(NSUInteger)currentTask] setStringValue:[statusField stringValue]];
		void (^handler)(void) = [[cancelHandler retain] autorelease];
		if (handler) handler();
	};
	if ([NSThread isMainThread]) show();
	else {
		[self retain];
		dispatch_async(dispatch_get_main_queue(), ^{
			show();
			[self release];
		});
	}
}

#pragma mark - End

- (void)end
{
	[lock lock];
	BOOL already = ended;
	ended = YES;
	[lock unlock];
	if (already) return;

	[cancelHandler release];
	cancelHandler = nil;
	for (NSProgressIndicator *spinner in taskSpinners) [spinner stopAnimation:nil];

	// A sheet still queued behind another isn't attached yet: AppKit removes it from the queue too
	if (parentWindow) [parentWindow endSheet:panel];
	[panel orderOut:nil];
	[parentWindow release];
	parentWindow = nil;
	[self autorelease]; // balances +beginOnWindow:title:
}

@end
