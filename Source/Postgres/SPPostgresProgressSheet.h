#import <Cocoa/Cocoa.h>

/// A task's mark in a task list sheet.
typedef NS_ENUM(NSInteger, SPPostgresTaskState) {
	SPPostgresTaskPending = 0,  // not started (an empty circle)
	SPPostgresTaskRunning = 1,  // a spinner
	SPPostgresTaskDone = 2,     // a green check
	SPPostgresTaskFailed = 3,   // a red cross
	SPPostgresTaskNotRun = 4    // after a failure: a grey dash
};

/**
 * The sheet shown while a background job (an export, an import) runs: a title, a status line, a determinate bar and
 * Cancel. Built in code. -beginOnWindow:title: and -end are for the main thread; -setStatus:fraction:, -cancelled and
 * -cancel: can be called from any thread.
 *
 * Begun with tasks (+beginOnWindow:title:tasks:, a transfer), it lists them, each with its mark and a line under it:
 * the status while it runs, its summary once done, what it was doing if it failed. The bar under the list is the
 * running task's. -finishWithSuccess:message:text: keeps it open with the outcome until Close.
 */
__attribute__((visibility("default")))
@interface SPPostgresProgressSheet : NSObject

/// Shows the sheet on window (it is attached once the window can take a sheet). The sheet keeps itself alive until -end.
+ (instancetype)beginOnWindow:(NSWindow *)window title:(NSString *)title;

/**
 * Sets the status line and the bar (fraction from 0 to 1; a negative one leaves the bar as it is). Thread-safe and
 * throttled: the sheet is updated on the main thread at most about 10 times a second, always ending with the latest
 * values.
 */
- (void)setStatus:(NSString *)status fraction:(double)fraction;

/// YES once Cancel was clicked (or -cancel: called). Thread-safe.
@property (readonly) BOOL cancelled;

/// What Cancel does: sets cancelled (the job checks it and stops) and shows "Cancelling…". Thread-safe.
- (IBAction)cancel:(id)sender;

/// Called once on the main thread when Cancel is clicked (or -cancel: called from any thread), after cancelled is set:
/// e.g. to stop a job still waiting for its connection. Cleared by -end.
@property (copy) void (^cancelHandler)(void);

/// Ends the sheet. Later status updates are ignored.
- (void)end;

#pragma mark Task list

/// Shows a task list sheet on window: every task pending until -setTask:status:fraction: starts one.
+ (instancetype)beginOnWindow:(NSWindow *)window title:(NSString *)title tasks:(NSArray<NSString *> *)tasks;

/// The tasks' titles (nil without a task list).
@property (readonly, copy) NSArray<NSString *> *taskTitles;

/// As -setStatus:fraction:, and the task at index runs: the tasks before it are done. Thread-safe and throttled with
/// the status (a task never goes back).
- (void)setTask:(NSUInteger)index status:(NSString *)status fraction:(double)fraction;

/// Main thread, before the task starts: the task runs beside the main sequence (-setTask:… never marks it done):
/// -setStatus:forTaskAlongside: shows it running with its status, -finishTaskAlongside: marks it done.
- (void)setTaskRunsAlongside:(NSUInteger)index;
/// Thread-safe.
- (void)setStatus:(NSString *)status forTaskAlongside:(NSUInteger)index;
/// The last status given (-setStatus:fraction:, -setTask:status:fraction:, -setStatus:forTaskAlongside:), as soon as it
/// is given (before it is shown). Thread-safe.
@property (readonly) NSString *lastStatus;
- (void)finishTaskAlongside:(NSUInteger)index;

/// The line under a task once it's done (e.g. what it dropped, how many rows it wrote). Thread-safe; shown with the
/// next update (or by -finishWithSuccess:message:text:).
- (void)setSummary:(NSString *)summary forTask:(NSUInteger)index;

/// Main thread. The job has ended: on success every task is done; otherwise the running task (the first if none ran)
/// failed and those after it didn't run. The status line and bar give way to message (bold) and text (selectable,
/// scrolling), Cancel becomes Close, which ends the sheet. Later status updates are ignored; Cancel no longer cancels.
- (void)finishWithSuccess:(BOOL)success message:(NSString *)message text:(NSString *)text;

/// As above; on failure failedTask (-1: the running one) failed, the tasks done stay done and every other one (later
/// ones, one stopped alongside) is marked not run.
- (void)finishWithSuccess:(BOOL)success failedTask:(NSInteger)failedTask message:(NSString *)message text:(NSString *)text;

/// YES once -finishWithSuccess:message:text: ran.
@property (readonly) BOOL finished;

/// The tasks' marks (SPPostgresTaskState numbers) as shown. Main thread.
@property (readonly) NSArray<NSNumber *> *taskStates;

/// After -finishWithSuccess:message:text:: Close (the Cancel button, retitled) ends the sheet.
- (IBAction)close:(id)sender;

#pragma mark - For tests

@property (readonly) NSPanel *panel;
@property (readonly) NSTextField *titleField;
@property (readonly) NSTextField *statusField;
@property (readonly) NSProgressIndicator *progressIndicator;
@property (readonly) NSButton *cancelButton;
/// The task list's rows' title fields and the lines under them, in task order
@property (readonly) NSArray<NSTextField *> *taskTitleFields;
@property (readonly) NSArray<NSTextField *> *taskDetailFields;
/// The outcome's message and text (hidden until finished)
@property (readonly) NSTextField *resultMessageField;
@property (readonly) NSTextView *resultTextView;

@end
