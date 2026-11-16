#import "SPPostgresDocument.h"
#import "SPPostgresSidebarController.h"
#import "SPPostgresContentController.h"
#import "SPPostgresStructureController.h"
#import "SPPostgresRelationsController.h"
#import "SPPostgresTriggersController.h"
#import "SPPostgresTableInfoController.h"
#import "SPPostgresSequenceController.h"
#import "SPPostgresExtensionController.h"
#import "SPPostgresExtensions.h"
#import "SPPostgresInstallExtensionSheet.h"
#import "SPPostgresUsersController.h"
#import "SPPostgresExportController.h"
#import "SPPostgresImportController.h"
#import "SPPostgresTransferController.h"
#import "SPPostgresBackgroundJob.h"
#import "SPPostgresTaskRunner.h"
#import "SPPostgresTaskDisplay.h"
#import "SPPostgresSequences.h"
#import "SPPostgresTableStructure.h"
#import "SPPostgresQueryController.h"
#import "SPQueryScriptStore.h"
#import "SPPostgresFavoritesStore.h"
#import "SPPostgresTextView.h"
#import "SPPostgresHelp.h"
#import "SPPostgresHistory.h"
#import "SPPostgresTableDuplicator.h"
#import "SPPostgresTableActions.h"
#import "SPPostgresCreateStatement.h"
#import "SPPostgresSidebarInfoPane.h"
#import "SPPostgresFeatureScope.h"
#import "SPPostgresConsoleLogger.h"
#import "SPPostgresCatalog.h"
#import "SPPostgresNameSheet.h"
#import "SPPostgresAlterDatabaseSheet.h"
#import "SPPostgresSchemaSheet.h"
#import "SPPostgresServerListSheet.h"
#import "SPGotoDatabaseController.h"
#import "SPPostgresConnector.h"
#import "SPPostgresFavorite.h"
#import "SPPostgresErrors.h"
#import "SPWindowController.h"
#import "SPSplitView.h"
#import "SPQueryController.h"
#import "SPFavoriteColorSupport.h"
#import "NSWindow+SPCompactChrome.h"
#import "SPToolbarTransferItem.h"
#import "SPMainToolbar.h"
#import "SPConstants.h"
#import <PostgresKit/PostgresKit.h>

// MySQL's left pane name (DBView.xib): one left pane width for both engines, so the database pickers match
static NSString * const SPPostgresSplitterName = @"DBViewSplitter";
// Shared with MySQL tabs, and so is the saved layout (see -[SPDatabaseDocument setupToolbar])
static NSString * const SPPostgresDocumentToolbarIdentifier = @"TableWindowToolbar";

// The MySQL split view's size in DBView.xib, so both panes start (and grow with the window) alike
static const CGFloat SPPostgresSidebarDefaultWidth = 214;
static const NSSize SPPostgresSplitViewSize = {943, 549};
/// Seconds Reduce Storage waits for a table's lock before failing (as the other structure changes)
static const NSTimeInterval SPPostgresReduceStorageLockTimeout = 5;

/// The KVO context for observing the tab's runner (isProcessing follows its busy)
static void *SPPostgresDocumentRunnerContext = &SPPostgresDocumentRunnerContext;

NSString * const SPPostgresPaneStructure = @"structure";
NSString * const SPPostgresPaneContent = @"content";
NSString * const SPPostgresPaneRelations = @"relations";
NSString * const SPPostgresPaneTriggers = @"triggers";
NSString * const SPPostgresPaneInfo = @"info";
NSString * const SPPostgresPaneQuery = @"query";
NSString * const SPPostgresPaneSequence = @"sequence";
NSString * const SPPostgresPaneExtension = @"extension";

@interface SPPostgresDocument () <SPPostgresSidebarControllerDelegate, SPPostgresExtensionControllerDelegate>

@property (readwrite) BOOL isProcessing;
@property (readwrite, assign) SPWindowController *parentWindowController;
@property (readwrite, assign) NSWindow *parentWindow;
@property (readwrite, assign) NSTabViewItem *parentTabViewItem;

- (void)_attachCurrentConnection;
- (void)_setTaskRunner:(SPPostgresTaskRunner *)runner;
- (void)_updateIsProcessing;
- (void)_buildContent;
- (void)_installContentController;
- (void)_installStructureController;
- (void)_installRelationsController;
- (void)_installTriggersController;
- (void)_refreshRelationsIfStale;
- (void)_refreshTriggersIfStale;
- (void)_installInfoController;
- (void)_refreshInfoIfStale;
- (void)_installSequenceController;
- (void)_refreshSequenceIfStale;
- (void)_sequenceDidChange:(NSString *)name;
- (void)_createSequence:(SPPostgresSequenceDefinition *)definition inSchema:(NSString *)schema;
- (void)_dropSequence:(NSString *)name inSchema:(NSString *)schema;
- (void)_installExtensionController;
- (void)_refreshExtensionIfStale;
- (void)_extensionsDidChange;
- (void)_extensionsDidChange:(void (^)(void))then;
- (void)_dropExtension:(NSString *)name;
- (void)_extensionInstalled:(NSString *)name;
- (void)_installQueryController;
- (NSString *)_queryScriptKey;
- (NSDictionary *)_completionNames;
- (void)_showHelpFor:(NSString *)searchString autoHelp:(BOOL)autoHelp;
- (void)_closeHelpViewer;
- (void)_queryRunChangedSchema:(BOOL)schemaChanged data:(BOOL)dataChanged;
- (void)_structureDidChange:(BOOL)columnsChanged;
- (void)_rereadCompletionColumns;
- (void)_reloadSidebarKeepingSelection;
- (void)_reloadSidebarKeepingSelection:(void (^)(void))then;
- (void (^)(BOOL))_quietSidebarCompletion:(void (^)(BOOL loaded))completion;
- (void)_installSidebarRunner;
- (void)_selectHistoryEntry:(NSDictionary *)entry;
- (void)_reloadDeferredSidebar;
- (void)_relationsDidChange;
- (void)_tableInfoDidChange;
- (void)_refreshContentIfStale;
- (void)_refreshStructureIfStale;
- (void)_refreshCurrentPaneIfStale;
- (NSView *)_viewForPane:(NSString *)pane;
- (BOOL)_endEditingInPane:(NSString *)pane;
- (BOOL)_canShowPane:(NSString *)pane;
- (void)_updatePaneToolbarSelection;
- (void)_updateEmptyStates;
- (NSView *)_rightPane;
- (void)_showSelectedTable;
- (void)_buildToolbar;
- (void)_reloadDatabasePopup;
- (void)_applyWindowTitle;
- (void)_updateDatabaseToolbarItemWidth;
- (void)_tearDown;
- (BOOL)_isSelectedTab;
- (BOOL)_canPresentSheet;
- (void)_presentPendingSheets;
- (void)_presentPendingConfirmation;
- (void)_presentPendingCreateSyntax;
- (void)_dropPendingCreateSyntax;
- (NSString *)_connectionName;
- (void)_reportCatalogError:(NSError *)error;
- (void)_presentAlert:(NSAlert *)alert;
- (void)_presentPendingAlert;
- (void)_databaseSwitchBy:(SPPostgresConnector *)theConnector favorite:(SPPostgresFavorite *)theFavorite finishedWithConnection:(PGPostgresConnection *)newConnection error:(NSError *)error;
- (void)_switchToDatabase:(NSString *)database forHistory:(BOOL)forHistory;
- (void)_recordHistory;
- (void)_updateHistoryControl;
- (void)_goBackInHistory:(BOOL)back;
- (void)_applyHistoryEntry:(NSDictionary *)entry;
- (void)_abandonHistoryRestore;
- (BOOL)_endPaneEditing;
- (void)_confirmLeavingSession:(void (^)(BOOL proceed))completion;
- (void)_showDuplicateTableSheetForTable:(NSString *)table;
- (void)_duplicateTable:(NSString *)table inSchema:(NSString *)schema toName:(NSString *)newName withContent:(BOOL)withContent;
- (void)_showRenameTableSheetForTable:(NSString *)table;
- (NSString *)_addTableName;
- (void)_renameTable:(NSString *)table inSchema:(NSString *)schema toName:(NSString *)newName;
- (void)_validateNameSheets;
- (BOOL)_refuseWriteWhileBusy;
- (void)_showDatabaseNames:(NSArray *)names error:(NSError *)error;

@end

@implementation SPPostgresDocument
{
	PGPostgresConnection *connection;
	SPPostgresConnector *connector;
	SPPostgresFavorite *favorite;
	SPPostgresCatalog *catalog;
	SPPostgresConsoleLogger *logger;
	SPPostgresSidebarController *sidebar;
	SPPostgresContentController *contentController;
	SPPostgresStructureController *structureController;
	SPPostgresRelationsController *relationsController;
	SPPostgresTriggersController *triggersController;
	SPPostgresTableInfoController *infoController;
	SPPostgresSequenceController *sequenceController;
	SPPostgresExtensionController *extensionController;
	SPPostgresQueryController *queryController;
	// Saves the Query editor's text for this connection (see -_installQueryController)
	SPQueryScriptAutosaver *queryScriptAutosaver;
	NSString *queryScriptKey;
	SPPostgresHistory *history;
	/// The pane shown in the right pane (an SPPostgresPane… name)
	NSString *currentPane;
	/// The pane shown when a sequence was selected (instead of a table, a view or nothing): shown again when no
	/// sequence is selected any more
	NSString *paneBeforeSequence;
	/// A sequence was selected when the selection last changed
	BOOL sequenceSelected;
	/// The same for an extension: the pane shown before one was selected (a table's, nothing's or Query, never the
	/// Sequence pane), and whether one was selected when the selection last changed
	NSString *paneBeforeExtension;
	BOOL extensionSelected;

	NSString *serverVersion;
	NSString *currentDatabase;

	/// The Query editor's help (MySQL's help window), made when it is first shown; closed on teardown
	SPPostgresHelpViewerController *helpViewerController;
	SPPostgresHelpDataSource *helpDataSource;

	/// A database switch in progress (see -switchToDatabase:), and what to call when it is done (-_switchToDatabase:then:)
	SPPostgresConnector *pendingConnector;
	void (^pendingSwitchCompletion)(BOOL switched);
	/// What runs once the tab is no longer processing (-_whenIdle:), in order
	NSMutableArray *idleActions;
	/// An Open Table in New Tab or Window connecting (see -openRelation:inSchema:inNewWindow:), and what makes its
	/// connector
	SPPostgresConnector *pendingOpenConnector;
	SPPostgresConnector *(^openRelationConnectorFactory)(SPPostgresFavorite *, NSString *, NSString *, NSWindow *);

	/// The current connection's runner, observed (its busy) while observingRunner, and its task display
	SPPostgresTaskRunner *taskRunner;
	BOOL observingRunner;
	SPPostgresTaskDisplay *taskDisplay;

	/// The history entry to show once the database switch in progress is done (a back/forward to another database)
	NSDictionary *pendingHistoryEntry;
	/// That move was back (else forward): undone if the switch fails
	BOOL pendingHistoryWentBack;
	/// Showing a history entry: the changes it makes aren't recorded
	BOOL restoringHistory;
	/// Sidebar reloads asked for and not yet completed whose selection changes aren't places the user went to
	/// (see -_quietSidebarCompletion:)
	NSUInteger quietSidebarReloads;
	/// Waiting for the user to confirm a database switch that rolls back their transaction
	BOOL confirmingSwitch;
	/// The Query view changed tables or schemas while the lists couldn't be reloaded (aborted transaction)
	BOOL listsNeedReload;
	/// The Query view may have changed rows (contentNeedsReload) or tables (contentNeedsReset) since the
	/// Content view last loaded: it reloads when it is next shown
	BOOL contentNeedsReload;
	BOOL contentNeedsReset;
	/// The Structure view shows another table than the selected one, or the Query view (or a rename) may have
	/// changed it: it is built again, from the sidebar's selection, when it is next shown
	BOOL structureNeedsReset;
	/// The same for the Relations and Triggers views: built again from the sidebar's selection when next shown
	BOOL relationsNeedReset;
	BOOL triggersNeedReset;
	/// The same for Table Info, which also reads again (sizes, estimate) each time it is shown
	BOOL infoNeedsReset;
	/// The same for the Sequence view (the selected sequence), which also reads again each time it is shown
	BOOL sequenceNeedsReset;
	/// The same for the Extension view (the selected extension), which also reads again each time it is shown
	BOOL extensionNeedsReset;
	/// (A table pane whose table switch was cancelled is stale too, by its controller's isStale: the pane loads the table
	/// when it is next shown, or its table selected again, as with these flags.)

	/// Inside the sidebar's should-change callback (the outline has already taken the row the user clicked or moved
	/// to): the sidebar isn't reloaded meanwhile, which would put another item at that row. The reload waits until
	/// the selection has changed (-_reloadDeferredSidebar).
	BOOL deferringSidebarReloads;
	/// A reload waits (see deferringSidebarReloads)
	BOOL sidebarReloadDeferred;
	/// The schema shown when the reload was deferred: it is for that schema's lists only
	NSString *deferredReloadSchema;
	/// The sequence renamed meanwhile, its old and new names: if the old name is still the selection when the reload
	/// comes, the new name is selected
	NSString *deferredRenameFrom;
	NSString *deferredRenameTo;

	/// The Add Sequence sheet while it is shown
	NSWindow *addSequenceSheet;
	NSWindow *installExtensionSheet;

	/// The Duplicate Table sheet while it is shown, and its controls
	NSWindow *duplicateSheet;
	NSTextField *duplicateNameField;
	NSButton *duplicateContentSwitch;
	NSButton *duplicateButton;

	/// The Rename Table sheet while it is shown, and its controls
	NSWindow *renameSheet;
	NSTextField *renameNameField;
	NSButton *renameButton;
	NSString *renameOriginalName;

	/// The New Table sheet while it is shown, its controls, and the schema the table is added to
	NSWindow *addTableSheet;
	NSTextField *addTableNameField;
	NSButton *addTableButton;
	NSString *addTableSchema;

	SPSplitView *splitView;
	NSToolbar *toolbar;
	NSPopUpButton *databasePopup;
	NSSegmentedControl *historyControl;
	NSToolbarItem *databaseToolbarItem; // not retained; owned by the toolbar

	/// An alert that came up while the tab couldn't show it (presented once the tab is active in a visible window)
	NSAlert *pendingAlert;
	/// A Truncate or Remove question, or the New Table sheet, waiting for the runner to be idle and the tab to be in
	/// front (see -_presentWhenIdle:)
	void (^pendingConfirmation)(void);

	/// The Users sheet while it is shown (or connecting)
	SPPostgresUsersController *usersController;
	SPPostgresExportController *exportController;
	SPPostgresImportController *importController;
	SPPostgresTransferController *transferController;

	/// The Show Create Syntax sheet while it is shown, and its text view (see -_showCreateSyntax:title:)
	NSPanel *createSyntaxSheet;
	NSTextView *createSyntaxTextView;
	NSPasteboard *createSyntaxPasteboard;
	/// A Create Syntax sheet whose read completed while another sheet was attached or another tab was in front:
	/// @[syntax, title], shown when that sheet ends or this tab is in front again (see -_showCreateSyntax:title:)
	NSArray *pendingCreateSyntax;

	BOOL tornDown;
}

@synthesize sidebar;
@synthesize contentController;
@synthesize structureController;
@synthesize relationsController;
@synthesize triggersController;
@synthesize infoController;
@synthesize sequenceController;
@synthesize extensionController;
@synthesize currentPane;
@synthesize queryController;
@synthesize history;
@synthesize connection;
@synthesize favorite;
@synthesize alertPresenter;
@synthesize confirmationPresenter;
@synthesize connectionProvider;
@synthesize openRelationConnectorFactory;
@synthesize usersController;
@synthesize exportController;
@synthesize importController;
@synthesize transferController;
@synthesize createSyntaxPasteboard;
@synthesize currentDatabase;
@synthesize isProcessing;
@synthesize taskRunner;
@synthesize parentWindowController;
@synthesize parentWindow;
@synthesize parentTabViewItem;

#pragma mark - Setup

- (instancetype)initWithConnection:(PGPostgresConnection *)theConnection connector:(SPPostgresConnector *)theConnector favorite:(SPPostgresFavorite *)theFavorite
{
	if ((self = [super init])) {
		connection = [theConnection retain];
		connector = [theConnector retain];
		favorite = [theFavorite copy];
		history = [[SPPostgresHistory alloc] init];
		currentPane = [SPPostgresPaneContent copy];

		[self _attachCurrentConnection];

		sidebar = [[SPPostgresSidebarController alloc] initWithCatalog:catalog];
		[sidebar setDelegate:self];
		if ([sidebar lastError]) [self _reportCatalogError:[sidebar lastError]];
		[self _installSidebarRunner];

		[self _buildContent];
		[self _buildToolbar];
		[taskDisplay setBlockedView:splitView];

		// Where the tab starts is the first history entry
		[self _recordHistory];
	}

	return self;
}

- (void)dealloc
{
	// Normally torn down by -parentTabDidClose already. If not, the (unretained) window may be gone:
	// don't touch it, just close the connection.
	parentWindowController = nil;
	parentWindow = nil;
	parentTabViewItem = nil;
	[self _tearDown];

	[connection release];
	[connector release];
	[favorite release];
	[catalog release];
	[logger release];
	[sidebar release];
	[contentController release];
	[structureController release];
	[relationsController release];
	[triggersController release];
	[infoController release];
	[sequenceController release];
	[extensionController release];
	[queryController release];
	[queryScriptAutosaver release];
	[queryScriptKey release];
	[history release];
	[currentPane release];
	[paneBeforeSequence release];
	[paneBeforeExtension release];
	[addSequenceSheet release];
	[installExtensionSheet release];
	[deferredRenameFrom release];
	[deferredRenameTo release];
	[deferredReloadSchema release];
	[renameSheet release];
	[renameNameField release];
	[renameButton release];
	[renameOriginalName release];
	[pendingHistoryEntry release];
	[duplicateSheet release];
	[duplicateNameField release];
	[duplicateContentSwitch release];
	[duplicateButton release];
	[addTableSheet release];
	[addTableNameField release];
	[addTableButton release];
	[addTableSchema release];
	[serverVersion release];
	[currentDatabase release];
	[helpViewerController release];
	[helpDataSource release];
	[splitView release];
	[toolbar release];
	[databasePopup release];
	[historyControl release];
	[pendingAlert release];
	[pendingConfirmation release];
	[idleActions release];
	[pendingSwitchCompletion release];
	[alertPresenter release];
	[confirmationPresenter release];
	[connectionProvider release];
	[openRelationConnectorFactory release];
	[usersController release];
	[exportController release];
	[importController release];
	[transferController release];
	[createSyntaxSheet release];
	[createSyntaxTextView release];
	[createSyntaxPasteboard release];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidEndSheetNotification object:nil];
	[pendingCreateSyntax release];
	[taskRunner release];
	[taskDisplay release];

	[super dealloc];
}

/// Catalog, console logger, database name and server version for the current connection.
- (void)_attachCurrentConnection
{
	[currentDatabase release];
	currentDatabase = nil;

	if ([[favorite database] length]) {
		currentDatabase = [[favorite database] copy];
	}
	else {
		// No database in the favorite: the server picked the default one
		PGPostgresResult *result = [connection execute:@"SELECT current_database()"];
		if ([result numberOfRows]) currentDatabase = [[[result rowAsArray] firstObject] copy];
		if (![currentDatabase isKindOfClass:[NSString class]]) [currentDatabase release], currentDatabase = nil;
		if (!currentDatabase) currentDatabase = [([connection database] ?: @"") copy];
	}

	[logger release];
	logger = [[SPPostgresConsoleLogger alloc] initWithConnectionName:[self _connectionName] database:currentDatabase];
	[logger attachToConnection:connection];

	[catalog release];
	catalog = [[SPPostgresCatalog alloc] initWithConnection:connection];

	// server_version may carry a build suffix ("18.6 (Debian 18.6-1.pgdg13+2)"): the title shows the number
	NSString *version = [[[catalog serverVersionString] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] firstObject];
	if (![version length] && [connection isConnected]) {
		// The query failed: libpq knows the version from the connection (e.g. 180006, or 90624 before 10)
		NSInteger number = (NSInteger)[connection serverVersion];
		if (number >= 100000) version = [NSString stringWithFormat:@"%ld.%ld", (long)(number / 10000), (long)(number % 10000)];
		else if (number > 0) version = [NSString stringWithFormat:@"%ld.%ld.%ld", (long)(number / 10000), (long)(number / 100 % 100), (long)(number % 100)];
	}
	[serverVersion release];
	serverVersion = [([version length] ? version : @"unknown") copy];

	SPPostgresTaskRunner *runner = [[SPPostgresTaskRunner alloc] initWithConnection:connection];
	[self _setTaskRunner:runner];
	[runner release];
}

/**
 * Makes runner the tab's (observing its busy for isProcessing) with a task display of its own. The previous runner,
 * if any, is no longer observed: the caller has invalidated it.
 */
- (void)_setTaskRunner:(SPPostgresTaskRunner *)runner
{
	if (observingRunner) {
		[taskRunner removeObserver:self forKeyPath:@"busy" context:SPPostgresDocumentRunnerContext];
		observingRunner = NO;
	}
	[taskDisplay invalidate];
	[taskDisplay release];
	taskDisplay = nil;
	// A question waiting for the previous runner (another database's tables) is not asked, nor their Create Syntax shown
	[self _dropPendingConfirmation];
	[self _dropPendingCreateSyntax];
	[taskRunner release];
	taskRunner = [runner retain];

	if (taskRunner) {
		[taskRunner addObserver:self forKeyPath:@"busy" options:0 context:SPPostgresDocumentRunnerContext];
		observingRunner = YES;

		taskDisplay = [[SPPostgresTaskDisplay alloc] initWithRunner:taskRunner];
		[taskDisplay setBlockedView:splitView];
		[taskDisplay setParentWindow:[self _isSelectedTab] ? parentWindow : nil];
	}

	[self _updateIsProcessing];
}

/// isProcessing: the runner is busy, or a database switch or an Open Table in New Tab/Window is connecting (never once
/// torn down).
- (void)_updateIsProcessing
{
	BOOL processing = !tornDown && ([taskRunner isBusy] || pendingConnector || pendingOpenConnector);
	if (processing == isProcessing) return;
	[self setIsProcessing:processing];

	// As MySQL's database pop-up during a task
	[databasePopup setEnabled:!processing];
	// The table list bar's Add, gear and Refresh (they start queries)
	[sidebar setActionsEnabled:!processing];

	// What isProcessing disables (as MySQL's task start and end revalidate the toolbar)
	[self _updateHistoryControl];
	if (!tornDown && [parentWindow toolbar] == toolbar) [toolbar validateVisibleItems];
	// The New Table sheet's Add (it writes)
	[self _validateNameSheets];

	// A Truncate or Remove question, or the New Table sheet, waiting for the tab to be idle (see -_presentWhenIdle:)
	if (!processing && pendingConfirmation) [self performSelector:@selector(_presentPendingConfirmation) withObject:nil afterDelay:0];
	// The Database menu's next steps (a switch once a change is made)
	if (!processing && [idleActions count]) [self performSelector:@selector(_runIdleActions) withObject:nil afterDelay:0];
}

/// Runs action once the tab isn't processing: now when it isn't, else on the run loop turn after processing ends.
- (void)_whenIdle:(void (^)(void))action
{
	if (tornDown || !action) return;
	if (!idleActions) idleActions = [[NSMutableArray alloc] init];
	[idleActions addObject:[[action copy] autorelease]];
	if (!isProcessing) [self performSelector:@selector(_runIdleActions) withObject:nil afterDelay:0];
}

- (void)_runIdleActions
{
	while (!tornDown && !isProcessing && [idleActions count]) {
		void (^action)(void) = [[[idleActions objectAtIndex:0] retain] autorelease];
		[idleActions removeObjectAtIndex:0];
		action();
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == SPPostgresDocumentRunnerContext) {
		if (object == taskRunner) [self _updateIsProcessing];
		return;
	}
	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (NSString *)_connectionName
{
	if ([[favorite name] length]) return [favorite name];
	if ([[favorite user] length] && [[favorite host] length]) return [NSString stringWithFormat:@"%@@%@", [favorite user], [favorite host]];
	return [favorite host] ?: @"PostgreSQL";
}

/// Left panel | content, as MySQL's DBViewSplitter. The window's tab bar is used; the tab has none of its own.
- (void)_buildContent
{
	NSRect splitFrame = NSMakeRect(0, 0, SPPostgresSplitViewSize.width, SPPostgresSplitViewSize.height);
	splitView = [[SPSplitView alloc] initWithFrame:splitFrame];
	[splitView setVertical:YES];
	[splitView setDividerStyle:NSSplitViewDividerStyleThin];
	[splitView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

	NSView *sidebarView = [sidebar view];
	[sidebarView setFrame:NSMakeRect(0, 0, SPPostgresSidebarDefaultWidth, NSHeight(splitFrame))];
	[sidebarView setAutoresizingMask:NSViewHeightSizable]; // keeps its width as the window resizes
	[splitView addSubview:sidebarView];
	// The bar's handle drags the divider, as MySQL's table list bar handle does
	[splitView setAdditionalDragHandleView:[sidebar splitHandleView]];

	// The right pane: the Content view of the selected table
	CGFloat contentX = SPPostgresSidebarDefaultWidth + [splitView dividerThickness];
	NSView *mainView = [[[NSView alloc] initWithFrame:NSMakeRect(contentX, 0, NSWidth(splitFrame) - contentX, NSHeight(splitFrame))] autorelease];
	[mainView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[splitView addSubview:mainView];
	[self _installQueryController];
	[self _installStructureController];
	[self _installRelationsController];
	[self _installTriggersController];
	[self _installInfoController];
	[self _installSequenceController];
	[self _installExtensionController];
	[self _installContentController];

	// Constrained, and resized with the window, as MySQL's left pane (see -[SPDatabaseDocument splitView:constrain...])
	[splitView setCollapsibleSubviewIndex:0];
	[splitView setDelegate:self];
	[splitView adjustSubviews];
	[splitView setAutosaveName:SPPostgresSplitterName];
}

/// The right pane (holding the shown pane's view), or nil before it is built.
- (NSView *)_rightPane
{
	if ([[splitView subviews] count] < 2) return nil;
	return [[splitView subviews] lastObject];
}

/// The sidebar's runner for the current connection.
- (void)_installSidebarRunner
{
	// The tab's background runner, as every pane's: one statement at a time on the connection, off the main thread
	[sidebar setTaskRunner:taskRunner];
}

/**
 * Wraps a sidebar reload's completion: until it has run, the selection changes the reload makes are not places the
 * user went to (History), as restoringHistory around a synchronous reload did. Call it when asking for the reload.
 */
- (void (^)(BOOL))_quietSidebarCompletion:(void (^)(BOOL loaded))completion
{
	quietSidebarReloads++;
	void (^then)(BOOL) = [[completion copy] autorelease];
	return [[^(BOOL loaded) {
		quietSidebarReloads--;
		if (then && !tornDown) then(loaded);
	} copy] autorelease];
}

/**
 * A Content controller on the current connection (replacing the previous one, which is on the previous
 * connection), in the right pane while the Content view is showing, showing the selected table.
 */
- (void)_installContentController
{
	NSView *pane = [self _rightPane];
	if (!pane) return;

	if (contentController) {
		[[contentController view] removeFromSuperview];
		[contentController invalidate];
		[contentController release];
	}

	contentController = [[SPPostgresContentController alloc] initWithConnection:connection];
	// Its loads run on the tab's background runner (as every pane's and the sidebar's: one at a time on the connection)
	[contentController setTaskRunner:taskRunner];

	// Through the tab's own presenter (a test's, or a sheet once the tab is visible). Unretained: the
	// controller is this document's, and -_tearDown drops the block.
	__block SPPostgresDocument *document = self;
	[contentController setAlertPresenter:^(NSAlert *alert) {
		[document _presentAlert:alert];
	}];

	NSView *contentView = [contentController view];
	[contentView setFrame:[pane bounds]];
	[contentView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	if ([currentPane isEqualToString:SPPostgresPaneContent]) [pane addSubview:contentView];

	[self _showSelectedTable];
}

/**
 * A Structure controller on the current connection (replacing the previous one, which is on the previous
 * connection), in the right pane while the Structure view is showing. It shows the selected table when it is
 * next shown.
 */
- (void)_installStructureController
{
	NSView *pane = [self _rightPane];
	if (!pane) return;

	if (structureController) {
		[[structureController view] removeFromSuperview];
		[structureController invalidate];
		[structureController release];
	}

	structureController = [[SPPostgresStructureController alloc] initWithConnection:connection];
	[structureController setTaskRunner:taskRunner]; // the tab's, as Content's

	// Unretained, as the Content controller's presenter: -invalidate (on replace or teardown) drops the blocks
	__block SPPostgresDocument *document = self;
	[structureController setAlertPresenter:^(NSAlert *alert) {
		[document _presentAlert:alert];
	}];
	[structureController setConfirmationPresenter:^(NSAlert *alert, void (^completion)(BOOL confirmed)) {
		[document _confirm:alert completion:completion];
	}];
	[structureController setStructureDidChange:^(BOOL columnsChanged) {
		[document _structureDidChange:columnsChanged];
	}];

	NSView *structureView = [structureController view];
	[structureView setFrame:[pane bounds]];
	[structureView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	if ([currentPane isEqualToString:SPPostgresPaneStructure]) [pane addSubview:structureView];

	structureNeedsReset = YES;
	if ([currentPane isEqualToString:SPPostgresPaneStructure]) [self _refreshStructureIfStale];
}

/**
 * A Relations controller on the current connection (replacing the previous one, which is on the previous
 * connection), in the right pane while the Relations view is showing. It shows the selected table when it is
 * next shown.
 */
- (void)_installRelationsController
{
	NSView *pane = [self _rightPane];
	if (!pane) return;

	if (relationsController) {
		[[relationsController view] removeFromSuperview];
		[relationsController invalidate];
		[relationsController release];
	}

	relationsController = [[SPPostgresRelationsController alloc] initWithConnection:connection];
	[relationsController setTaskRunner:taskRunner]; // the tab's, as Content's

	// Unretained, as the Content controller's presenter: -invalidate (on replace or teardown) drops the blocks
	__block SPPostgresDocument *document = self;
	[relationsController setAlertPresenter:^(NSAlert *alert) {
		[document _presentAlert:alert];
	}];
	[relationsController setConfirmationPresenter:^(NSAlert *alert, void (^completion)(BOOL confirmed)) {
		[document _confirm:alert completion:completion];
	}];
	[relationsController setRelationsDidChange:^{
		[document _relationsDidChange];
	}];

	NSView *relationsView = [relationsController view];
	[relationsView setFrame:[pane bounds]];
	[relationsView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	if ([currentPane isEqualToString:SPPostgresPaneRelations]) [pane addSubview:relationsView];

	relationsNeedReset = YES;
	[self _updateEmptyStates];
	if ([currentPane isEqualToString:SPPostgresPaneRelations]) [self _refreshRelationsIfStale];
}

/**
 * A Triggers controller on the current connection (replacing the previous one, which is on the previous
 * connection), in the right pane while the Triggers view is showing. It shows the selected table when it is
 * next shown.
 */
- (void)_installTriggersController
{
	NSView *pane = [self _rightPane];
	if (!pane) return;

	if (triggersController) {
		[[triggersController view] removeFromSuperview];
		[triggersController invalidate];
		[triggersController release];
	}

	triggersController = [[SPPostgresTriggersController alloc] initWithConnection:connection];
	[triggersController setTaskRunner:taskRunner]; // the tab's, as Content's

	// Unretained, as the Content controller's presenter: -invalidate (on replace or teardown) drops the blocks
	__block SPPostgresDocument *document = self;
	[triggersController setAlertPresenter:^(NSAlert *alert) {
		[document _presentAlert:alert];
	}];
	[triggersController setConfirmationPresenter:^(NSAlert *alert, void (^completion)(BOOL confirmed)) {
		[document _confirm:alert completion:completion];
	}];

	NSView *triggersView = [triggersController view];
	[triggersView setFrame:[pane bounds]];
	[triggersView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	if ([currentPane isEqualToString:SPPostgresPaneTriggers]) [pane addSubview:triggersView];

	triggersNeedReset = YES;
	[self _updateEmptyStates];
	if ([currentPane isEqualToString:SPPostgresPaneTriggers]) [self _refreshTriggersIfStale];
}

/**
 * A Table Info controller on the current connection (replacing the previous one, which is on the previous
 * connection), in the right pane while the Table Info view is showing. It shows the selected table when it is
 * next shown.
 */
- (void)_installInfoController
{
	NSView *pane = [self _rightPane];
	if (!pane) return;

	if (infoController) {
		[[infoController view] removeFromSuperview];
		[infoController invalidate];
		[infoController release];
	}

	infoController = [[SPPostgresTableInfoController alloc] initWithConnection:connection];
	[infoController setTaskRunner:taskRunner]; // the tab's, as Content's

	// Unretained, as the Content controller's presenter: -invalidate (on replace or teardown) drops the blocks
	__block SPPostgresDocument *document = self;
	[infoController setAlertPresenter:^(NSAlert *alert) {
		[document _presentAlert:alert];
	}];
	[infoController setTableInfoDidChange:^{
		[document _tableInfoDidChange];
	}];

	NSView *infoView = [infoController view];
	[infoView setFrame:[pane bounds]];
	[infoView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	if ([currentPane isEqualToString:SPPostgresPaneInfo]) [pane addSubview:infoView];

	infoNeedsReset = YES;
	if ([currentPane isEqualToString:SPPostgresPaneInfo]) [self _refreshInfoIfStale];
}

/**
 * A Sequence controller on the current connection (replacing the previous one, which is on the previous
 * connection), in the right pane while the Sequence view is showing. It shows the selected sequence when it is
 * next shown.
 */
- (void)_installSequenceController
{
	NSView *pane = [self _rightPane];
	if (!pane) return;

	if (sequenceController) {
		[[sequenceController view] removeFromSuperview];
		[sequenceController invalidate];
		[sequenceController release];
	}

	sequenceController = [[SPPostgresSequenceController alloc] initWithConnection:connection];
	[sequenceController setTaskRunner:taskRunner]; // the tab's, as Content's

	// Unretained, as the Content controller's presenter: -invalidate (on replace or teardown) drops the blocks
	__block SPPostgresDocument *document = self;
	[sequenceController setAlertPresenter:^(NSAlert *alert) {
		[document _presentAlert:alert];
	}];
	[sequenceController setSequenceDidChange:^(NSString *name) {
		[document _sequenceDidChange:name];
	}];

	NSView *sequenceView = [sequenceController view];
	[sequenceView setFrame:[pane bounds]];
	[sequenceView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	if ([currentPane isEqualToString:SPPostgresPaneSequence]) [pane addSubview:sequenceView];

	sequenceNeedsReset = YES;
	if ([currentPane isEqualToString:SPPostgresPaneSequence]) [self _refreshSequenceIfStale];
}

/**
 * An Extension controller on the current connection (replacing the previous one, which is on the previous
 * connection), in the right pane while the Extension view is showing. It shows the selected extension when it is
 * next shown.
 */
- (void)_installExtensionController
{
	NSView *pane = [self _rightPane];
	if (!pane) return;

	if (extensionController) {
		[[extensionController view] removeFromSuperview];
		[extensionController invalidate];
		[extensionController release];
	}

	extensionController = [[SPPostgresExtensionController alloc] initWithConnection:connection];
	[extensionController setTaskRunner:taskRunner]; // the tab's, as Content's
	[extensionController setDelegate:self];

	// Unretained, as the Content controller's presenter: -invalidate (on replace or teardown) drops the block
	__block SPPostgresDocument *document = self;
	[extensionController setAlertPresenter:^(NSAlert *alert) {
		[document _presentAlert:alert];
	}];

	NSView *extensionView = [extensionController view];
	[extensionView setFrame:[pane bounds]];
	[extensionView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	if ([currentPane isEqualToString:SPPostgresPaneExtension]) [pane addSubview:extensionView];

	extensionNeedsReset = YES;
	if ([currentPane isEqualToString:SPPostgresPaneExtension]) [self _refreshExtensionIfStale];
}

/**
 * A Query controller on the current connection (replacing the previous one, which is on the previous
 * connection), keeping the editor's text; in the right pane while the Query view is showing.
 */
- (void)_installQueryController
{
	NSView *pane = [self _rightPane];
	if (!pane) return;

	// An edit not saved yet goes to this connection's script before the editor goes
	[queryScriptAutosaver invalidate];
	[queryScriptAutosaver release], queryScriptAutosaver = nil;

	NSString *text = [[[[queryController editor] string] copy] autorelease];

	if (queryController) {
		[[queryController view] removeFromSuperview];
		[queryController invalidate];
		[queryController release];
	}

	queryController = [[SPPostgresQueryController alloc] initWithConnection:connection];
	[queryController setTaskRunner:taskRunner]; // the tab's, as Content's
	if ([text length]) [[queryController editor] setString:text];

	// The editor's text is saved for this connection as it is edited; a new tab's empty editor gets what was saved
	queryScriptAutosaver = [[SPQueryScriptAutosaver alloc] initWithTextView:[queryController editor] store:[SPQueryScriptStore sharedStore] key:[self _queryScriptKey]];
	if (![text length]) [queryScriptAutosaver loadIntoEmptyEditorUsing:nil];

	// Unretained, as the Content controller's presenter: -invalidate (on replace or teardown) drops the block
	__block SPPostgresDocument *document = self;
	[queryController setRunDidChangeDatabase:^(BOOL schemaChanged, BOOL dataChanged) {
		[document _queryRunChangedSchema:schemaChanged data:dataChanged];
	}];
	[queryController setExportResultHandler:^{
		[document exportQueryResult:nil];
	}];
	// The editor's help, in the tab's PostgreSQL help window
	[queryController setHelpHandler:^(NSString *searchString, BOOL autoHelp) {
		[document _showHelpFor:searchString autoHelp:autoHelp];
	}];
	// Completion's names, from what the tab lists (never a query: the runner may be using the connection)
	[(SPPostgresTextView *)[queryController editor] setCompletionNamesProvider:^NSDictionary *{
		return [document _completionNames];
	}];

	NSView *queryView = [queryController view];
	[queryView setFrame:[pane bounds]];
	[queryView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	if ([currentPane isEqualToString:SPPostgresPaneQuery]) [pane addSubview:queryView];
}

/**
 * This connection's key for its saved Query editor text: its saved favorite's, else (Quick Connect) its server
 * details. Fixed for the tab's life, so moving to another database keeps the same script.
 */
- (NSString *)_queryScriptKey
{
	if (queryScriptKey) return queryScriptKey;

	NSString *favoriteID = [favorite favoriteID];
	BOOL saved = NO;
	if ([favoriteID length]) {
		for (SPPostgresFavorite *each in [[SPPostgresFavoritesStore sharedStore] favorites]) {
			if ([[each favoriteID] isEqualToString:favoriteID]) { saved = YES; break; }
		}
	}

	if (saved) {
		queryScriptKey = [[SPQueryScriptStore keyForEngine:SPQueryScriptEnginePostgreSQL favoriteID:favoriteID] copy];
	}
	else {
		queryScriptKey = [[SPQueryScriptStore keyForEngine:SPQueryScriptEnginePostgreSQL type:[favorite type] host:[favorite host]
		                                              port:[NSString stringWithFormat:@"%lu", (unsigned long)[favorite port]] user:[favorite user]
		                                            socket:[favorite socketPath] sshHost:[favorite sshHost] sshUser:[favorite sshUser]] copy];
	}
	return queryScriptKey;
}

#pragma mark - Help

- (NSWindowController *)helpViewerController
{
	return helpViewerController;
}

/**
 * Shows the help for searchString in the tab's help window (MySQL's, see SPPostgresHelp), made the first time, for
 * the server's major version (read from the version the tab read when it connected: no query).
 */
- (void)_showHelpFor:(NSString *)searchString autoHelp:(BOOL)autoHelp
{
	if (tornDown) return;

	NSString *major = [SPPostgresHelpDataSource majorVersionFromServerVersion:serverVersion];
	if (!helpViewerController) {
		helpDataSource = [[SPPostgresHelpDataSource alloc] initWithServerMajorVersion:major];
		helpViewerController = [[SPPostgresHelpViewerController alloc] init];
		[helpViewerController setDataSource:(id<SPHelpViewerDataSource>)helpDataSource]; // conforms (SPPostgresHelp.m)
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_helpViewerClosedByUser:) name:SPUserClosedHelpViewerNotification object:helpViewerController];
	}
	[helpDataSource setServerMajorVersion:major];
	[helpViewerController showHelpFor:searchString addToHistory:YES calledByAutoHelp:autoHelp];
}

/// As MySQL's -helpWindowClosedByUser:: the Query view turns Update Help while typing off.
- (void)_helpViewerClosedByUser:(NSNotification *)notification
{
	if (tornDown || [notification object] != helpViewerController) return;
	[queryController helpWindowClosedByUser:notification];
}

/// The help window closes (no notification: that is the user's close only) and is let go of.
- (void)_closeHelpViewer
{
	if (!helpViewerController) return;
	[[NSNotificationCenter defaultCenter] removeObserver:self name:SPUserClosedHelpViewerNotification object:helpViewerController];
	[helpViewerController setDataSource:nil];
	[helpViewerController close];
	[helpViewerController release];
	helpViewerController = nil;
	[helpDataSource release];
	helpDataSource = nil;
}

/**
 * Reads the shown schema's column names again for completion (after a column change the sidebar's lists don't
 * follow), on the tab's runner, silently; applied if the sidebar still shows that schema. A failure keeps the old ones.
 */
- (void)_rereadCompletionColumns
{
	NSString *schema = [[[sidebar selectedSchema] copy] autorelease];
	if (tornDown || !taskRunner || ![schema length]) return;

	[taskRunner runTaskWithDescription:nil cancelTitle:nil work:^id(PGPostgresConnection *theConnection, NSError **error) {
		SPPostgresCatalog *reader = [[[SPPostgresCatalog alloc] initWithConnection:theConnection] autorelease];
		return [reader columnNamesByRelationInSchema:schema error:error];
	} completion:^(id result, NSError *error, BOOL cancelled) {
		if (tornDown || ![result isKindOfClass:[NSDictionary class]] || ![[sidebar selectedSchema] isEqualToString:schema]) return;
		[sidebar setRelationColumns:result];
	}];
}

/**
 * The Query editor's completion names, from the lists the tab holds (read on the main thread, at once): the databases
 * of the database pop-up, the schemas of the sidebar's schema pop-up, the shown schema (@"schema") and its tables and
 * views, the columns the Content view loaded for the selected table (none while it shows another table or has not
 * loaded them), and (@"relationColumns") the shown schema's columns by table or view, as the sidebar read them with
 * its lists.
 */
- (NSDictionary *)_completionNames
{
	if (tornDown) return @{};


	NSArray *databases = [self _listedDatabaseNames];

	NSArray *columns = @[];
	NSString *table = [sidebar selectedTableName];
	if (table && [[contentController table] isEqualToString:table] && [[contentController schema] isEqualToString:[sidebar selectedSchema]]) {
		columns = [contentController columnNames];
	}

	return @{@"databases": databases,
			 @"schemas": [sidebar schemaNames] ?: @[],
			 @"schema": [sidebar selectedSchema] ?: @"",
			 @"relationColumns": [sidebar relationColumns] ?: @{},
			 @"tables": [sidebar itemTitlesInSection:@"TABLES"] ?: @[],
			 @"views": [sidebar itemTitlesInSection:@"VIEWS"] ?: @[],
			 @"columns": columns ?: @[]};
}

/// The feature a pane belongs to (see SPPostgresFeatureScope.h): unknown names are Content's.
static SPPostgresFeature SPPostgresFeatureForPane(NSString *pane)
{
	if ([pane isEqualToString:SPPostgresPaneStructure]) return SPPostgresFeatureStructure;
	if ([pane isEqualToString:SPPostgresPaneRelations]) return SPPostgresFeatureRelations;
	if ([pane isEqualToString:SPPostgresPaneTriggers]) return SPPostgresFeatureTriggers;
	if ([pane isEqualToString:SPPostgresPaneInfo]) return SPPostgresFeatureTableInfo;
	if ([pane isEqualToString:SPPostgresPaneSequence]) return SPPostgresFeatureSequences;
	if ([pane isEqualToString:SPPostgresPaneExtension]) return SPPostgresFeatureExtensions;
	if ([pane isEqualToString:SPPostgresPaneQuery]) return SPPostgresFeatureQuery;
	return SPPostgresFeatureContent;
}

/// Whether this build's scope has the pane (SPPostgresFeatureIsAvailable): a pane it holds back is never shown.
static BOOL SPPostgresPaneIsInScope(NSString *pane)
{
	return SPPostgresFeatureIsAvailable(SPPostgresFeatureForPane(pane));
}

/// The known pane names, in toolbar order.
- (NSArray *)_paneNames
{
	return @[SPPostgresPaneStructure, SPPostgresPaneContent, SPPostgresPaneRelations, SPPostgresPaneTriggers, SPPostgresPaneInfo, SPPostgresPaneQuery, SPPostgresPaneSequence, SPPostgresPaneExtension];
}

/// The view a pane shows, or nil for an unknown name.
- (NSView *)_viewForPane:(NSString *)pane
{
	if ([pane isEqualToString:SPPostgresPaneStructure]) return [structureController view];
	if ([pane isEqualToString:SPPostgresPaneRelations]) return [relationsController view];
	if ([pane isEqualToString:SPPostgresPaneTriggers]) return [triggersController view];
	if ([pane isEqualToString:SPPostgresPaneInfo]) return [infoController view];
	if ([pane isEqualToString:SPPostgresPaneContent]) return [contentController view];
	if ([pane isEqualToString:SPPostgresPaneQuery]) return [queryController view];
	if ([pane isEqualToString:SPPostgresPaneSequence]) return [sequenceController view];
	if ([pane isEqualToString:SPPostgresPaneExtension]) return [extensionController view];
	return nil;
}

/// The toolbar item of a pane (SPMainToolbar.m), or nil.
- (NSString *)_toolbarIdentifierForPane:(NSString *)pane
{
	NSDictionary *identifiers = @{SPPostgresPaneStructure: SPMainToolbarTableStructure, SPPostgresPaneContent: SPMainToolbarTableContent,
								  SPPostgresPaneRelations: SPMainToolbarTableRelations, SPPostgresPaneTriggers: SPMainToolbarTableTriggers,
								  SPPostgresPaneInfo: SPMainToolbarTableInfo, SPPostgresPaneQuery: SPMainToolbarCustomQuery};
	return [identifiers objectForKey:pane];
}

/// The pane a toolbar item shows, or nil.
- (NSString *)_paneForToolbarIdentifier:(NSString *)identifier
{
	for (NSString *pane in [self _paneNames]) {
		if ([[self _toolbarIdentifierForPane:pane] isEqualToString:identifier]) return pane;
	}
	return nil;
}

/**
 * Whether a pane's toolbar item and View menu item are enabled: Query always; Structure, Content and Table Info
 * for any selected table or view; Relations and Triggers for a table (or partitioned table) only; Sequence (no
 * item) for a selected sequence, Extension (no item) for a selected extension. While a sequence or an extension
 * is selected there is no table: only Query is enabled, and Structure (⌘1), which shows the Sequence or Extension
 * pane (-showPane: redirects it).
 */
- (BOOL)_canShowPane:(NSString *)pane
{
	if (tornDown || !pane) return NO;
	// A pane this build's scope holds back (SPPostgresFeatureScope) is never enabled
	if (!SPPostgresPaneIsInScope(pane)) return NO;
	if ([pane isEqualToString:SPPostgresPaneQuery]) return YES;
	if ([pane isEqualToString:SPPostgresPaneSequence]) return [[sidebar selectedSequenceName] length] > 0;
	if ([pane isEqualToString:SPPostgresPaneExtension]) return [[sidebar selectedExtensionName] length] > 0;
	// With a sequence selected, Structure (⌘1) is the way back to its pane (-showPane: shows it instead)
	if ([pane isEqualToString:SPPostgresPaneStructure] && [[sidebar selectedSequenceName] length]) return YES;
	// The same for a selected extension and its pane
	if ([pane isEqualToString:SPPostgresPaneStructure] && [[sidebar selectedExtensionName] length]) return YES;
	if (![[sidebar selectedTableName] length]) return NO;
	if ([pane isEqualToString:SPPostgresPaneRelations] || [pane isEqualToString:SPPostgresPaneTriggers]) return [sidebar selectionIsTable];
	return YES;
}

/**
 * Whether a pane's toolbar item and View menu item can switch to it now: as -_canShowPane:, and not while the tab is
 * processing (as MySQL's controls during a task): the pane's load would queue behind the running one, and a Stop
 * would cancel both.
 */
- (BOOL)_canSwitchToPane:(NSString *)pane
{
	return !isProcessing && [self _canShowPane:pane];
}

/**
 * Ends an edit in progress in a pane's view (saving it), and saves a Structure draft column. NO if it couldn't
 * (e.g. the value or the column was refused): the tab should stay where it is.
 */
- (BOOL)_endEditingInPane:(NSString *)pane
{
	NSView *paneView = [self _viewForPane:pane];
	NSWindow *window = [[self _rightPane] window];

	if ([paneView superview] && window) {
		NSResponder *responder = [window firstResponder];
		BOOL editingInPane = [responder isKindOfClass:[NSView class]] && [(NSView *)responder isDescendantOf:paneView];
		if (editingInPane && ![window makeFirstResponder:nil]) return NO;
	}

	if ([pane isEqualToString:SPPostgresPaneStructure] && ![structureController commitPendingEdits]) return NO;
	// A Table Info comment edit (normally saved as the box loses the focus, above)
	if ([pane isEqualToString:SPPostgresPaneInfo] && ![infoController commitPendingEdits]) return NO;
	// Sequence edits not applied yet (Ruling R9: applied on leaving; a failure keeps the user there)
	if ([pane isEqualToString:SPPostgresPaneSequence] && ![sequenceController commitPendingEdits]) return NO;
	return YES;
}

/// Ends an edit in progress in the shown pane (see -_endEditingInPane:).
- (BOOL)_endPaneEditing
{
	return [self _endEditingInPane:currentPane];
}

/**
 * YES (after NSBeep) while the tab's runner is busy: the tab's own changes (add, drop, rename, duplicate) run on the
 * main thread, so never while a load uses the connection. Their menus check isProcessing first; this covers a change
 * confirmed (a sheet or an alert answered) after something was queued meanwhile.
 */
- (BOOL)_refuseWriteWhileBusy
{
	if (![taskRunner isBusy]) return NO;
	NSBeep();
	return YES;
}

/**
 * Shows a pane in the right pane, as MySQL's tab view does. The other panes' views are taken out of the window
 * (keeping their state), so their key equivalents don't apply meanwhile. An edit in progress in the pane being
 * left is ended (saved) first; if it can't end, nothing changes.
 */
- (void)showPane:(NSString *)pane
{
	if (tornDown) return;
	if (![[self _paneNames] containsObject:pane]) pane = SPPostgresPaneContent;

	// A selected sequence has its own pane (and Query); without one, the Sequence pane gives way to the pane before it
	BOOL hasSequence = [[sidebar selectedSequenceName] length] > 0;
	if (hasSequence && ![pane isEqualToString:SPPostgresPaneQuery]) pane = SPPostgresPaneSequence;
	if (!hasSequence && [pane isEqualToString:SPPostgresPaneSequence]) pane = paneBeforeSequence ?: SPPostgresPaneContent;
	// The same for a selected extension and its pane
	BOOL hasExtension = [[sidebar selectedExtensionName] length] > 0;
	if (hasExtension && ![pane isEqualToString:SPPostgresPaneQuery]) pane = SPPostgresPaneExtension;
	if (!hasExtension && [pane isEqualToString:SPPostgresPaneExtension]) pane = paneBeforeExtension ?: SPPostgresPaneContent;
	// A pane this build's scope holds back (SPPostgresFeatureScope; e.g. from History, Add Table, Open in New Tab)
	// shows Content instead: the tab is never left on a disabled pane
	if (!SPPostgresPaneIsInScope(pane)) pane = SPPostgresPaneContent;

	NSView *container = [self _rightPane];
	if (!container) return;

	NSView *showing = [self _viewForPane:pane];
	NSView *hiding = [self _viewForPane:currentPane];

	if (hiding != showing && ![self _endEditingInPane:currentPane]) return;

	if (pane != currentPane) {
		[currentPane release];
		currentPane = [pane copy];
	}

	// Table Info reads again each time it comes up: its sizes and row estimate change with the data
	if (hiding != showing && [pane isEqualToString:SPPostgresPaneInfo]) infoNeedsReset = YES;
	// So does the Sequence view (its current value moves)
	if (hiding != showing && [pane isEqualToString:SPPostgresPaneSequence]) sequenceNeedsReset = YES;
	// And the Extension view (the Query view may have changed it)
	if (hiding != showing && [pane isEqualToString:SPPostgresPaneExtension]) extensionNeedsReset = YES;

	if (hiding != showing) [hiding removeFromSuperview];
	if ([showing superview] != container) {
		[showing setFrame:[container bounds]];
		[container addSubview:showing];
	}

	[self _updatePaneToolbarSelection];
	[self _refreshCurrentPaneIfStale];
	[self _updateEmptyStates];

	[self _recordHistory];
}

/// The shown pane's toolbar item is selected (none for a table pane without a table), and the items revalidated.
- (void)_updatePaneToolbarSelection
{
	BOOL hasTable = [[sidebar selectedTableName] length] > 0;
	BOOL needsTable = ![currentPane isEqualToString:SPPostgresPaneQuery];
	NSString *identifier = (needsTable && !hasTable) ? nil : [self _toolbarIdentifierForPane:currentPane];
	// The Sequence and Extension panes have no item of their own: Structure (which shows them) is highlighted
	if ([currentPane isEqualToString:SPPostgresPaneSequence] || [currentPane isEqualToString:SPPostgresPaneExtension]) identifier = [self _toolbarIdentifierForPane:SPPostgresPaneStructure];
	[toolbar setSelectedItemIdentifier:identifier];
	[toolbar validateVisibleItems];
}

/// A pane whose item is disabled for the selection (Relations or Triggers on a view) says so in its empty state.
- (void)_updateEmptyStates
{
	BOOL isView = [[sidebar selectedTableName] length] && ![sidebar selectionIsTable];
	NSDictionary *texts = @{
		SPPostgresPaneRelations: isView ? NSLocalizedString(@"Relations aren't available for views.", @"PostgreSQL relations pane: view selected") : @"",
		SPPostgresPaneTriggers: isView ? NSLocalizedString(@"Triggers aren't available for views.", @"PostgreSQL triggers pane: view selected") : @"",
	};
	[relationsController setEmptyStateText:[texts objectForKey:SPPostgresPaneRelations]];
	[triggersController setEmptyStateText:[texts objectForKey:SPPostgresPaneTriggers]];
}

/**
 * After a Query run that may have changed things (as MySQL's Query tab reloads its tables list after CREATE,
 * ALTER, DROP or RENAME): reloads the lists keeping the selection (a dropped selected table empties the Content
 * view) and the database pop-up, and has the Content view reload when it is next shown. Inside an aborted
 * transaction the catalog can't be read, so the lists wait for a later run.
 */
- (void)_queryRunChangedSchema:(BOOL)schemaChanged data:(BOOL)dataChanged
{
	if (tornDown) return;

	if (schemaChanged) listsNeedReload = YES;
	if (dataChanged) contentNeedsReload = YES;

	// The Structure view is built again from the sidebar's selection: a statement may have altered the table, and
	// a transaction's end (COMMIT/END count as data changes, ROLLBACK/ABORT as schema changes) may have undone a
	// rename the structure object followed
	structureNeedsReset = YES;
	// The same for Relations and Triggers (CREATE TRIGGER, ALTER TABLE … ADD CONSTRAINT, …)
	relationsNeedReset = YES;
	triggersNeedReset = YES;
	infoNeedsReset = YES;
	// And the Sequence view (ALTER SEQUENCE, setval, …), and the Extension view (ALTER EXTENSION, …)
	sequenceNeedsReset = YES;
	extensionNeedsReset = YES;

	// The status the run's work read on the runner's thread (libpq's, read here, could be a later task's: ACTIVE)
	if (listsNeedReload && [queryController lastRunTransactionStatus] != PGPostgresTransactionInError) {
		listsNeedReload = NO;
		contentNeedsReset = YES; // its columns may have changed

		// Not a place the user went to (history); the rest once the lists are shown
		[sidebar reloadKeepingSelection:[self _quietSidebarCompletion:^(BOOL loaded) {
			[self _reloadDatabasePopup];
			[self updateWindowTitle:self];
			[self _refreshCurrentPaneIfStale];
		}]];
		return;
	}

	[self _refreshCurrentPaneIfStale];
}

/// The Structure view changed the table: the Content view shows its new columns, and Relations and Triggers (a
/// renamed column, a foreign key added or dropped there) the server's state, when they are next shown.
- (void)_structureDidChange:(BOOL)columnsChanged
{
	if (tornDown) return;
	if (columnsChanged) contentNeedsReset = YES;
	else contentNeedsReload = YES;
	// The sidebar's completion columns (its lists, and so its columns, aren't reloaded for a column change)
	if (columnsChanged) [self _rereadCompletionColumns];
	relationsNeedReset = YES;
	triggersNeedReset = YES;
	infoNeedsReset = YES;

	// A serial or identity column added brings a sequence, and one dropped takes its owned sequence with it: the
	// SEQUENCES list follows (the selection and pane stay)
	if (columnsChanged) [self _reloadSidebarKeepingSelection];
}

/// Lists the schema's relations again, keeping the selection, the pane and History as they are; inside the sidebar's
/// should-change callback, once the selection has changed (see deferringSidebarReloads).
- (void)_reloadSidebarKeepingSelection
{
	[self _reloadSidebarKeepingSelection:nil];
}

/// The same, then `then` once the lists are shown (at once if the reload waits for a selection change, or if torn down).
- (void)_reloadSidebarKeepingSelection:(void (^)(void))then
{
	if (tornDown) return;
	if (deferringSidebarReloads) {
		[self _deferSidebarReload];
		if (then) then();
		return;
	}

	// Not a place the user went to
	void (^after)(void) = [[then copy] autorelease];
	[sidebar reloadKeepingSelection:[self _quietSidebarCompletion:^(BOOL loaded) {
		if (after) after();
	}]];
}

/// A sidebar reload waits for the selection change (see deferringSidebarReloads), for the schema shown now.
- (void)_deferSidebarReload
{
	if (!sidebarReloadDeferred) {
		[deferredReloadSchema release];
		deferredReloadSchema = [[sidebar selectedSchema] copy];
	}
	sidebarReloadDeferred = YES;
}

/// The sidebar reload that waited for the selection change (see deferringSidebarReloads): the item the user went
/// to stays selected; a renamed sequence still selected is selected under its new name. When the change was to
/// another schema (shown, or being loaded), it is dropped: that schema's lists are read fresh, and a rename's History
/// entries were rewritten already.
- (void)_reloadDeferredSidebar
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reloadDeferredSidebar) object:nil];
	if (tornDown || !sidebarReloadDeferred || deferringSidebarReloads) return;
	sidebarReloadDeferred = NO;

	NSString *renamedFrom = [deferredRenameFrom autorelease];
	NSString *renamedTo = [deferredRenameTo autorelease];
	NSString *forSchema = [deferredReloadSchema autorelease];
	deferredRenameFrom = nil;
	deferredRenameTo = nil;
	deferredReloadSchema = nil;

	NSString *schemaNext = [sidebar pendingSchema] ?: [sidebar selectedSchema];
	if (forSchema != schemaNext && ![forSchema isEqualToString:schemaNext]) return;

	if (renamedFrom && renamedTo && [renamedFrom isEqualToString:[sidebar selectedSequenceName]]) {
		// As a rename applied without leaving (-_sequenceDidChange:)
		[sidebar reloadSchema:[sidebar selectedSchema] selectingSequence:renamedTo];
		return;
	}
	[self _reloadSidebarKeepingSelection];
}

/// The Relations view added or dropped a foreign key: the Structure view's constraints follow when it is next shown.
- (void)_relationsDidChange
{
	if (tornDown) return;
	structureNeedsReset = YES;
	infoNeedsReset = YES;
}

/**
 * The Sequence view changed the sequence `name` is now: a column's default naming it reads afresh (Structure, Table
 * Info), and a rename is listed (and stays selected) in the sidebar.
 */
- (void)_sequenceDidChange:(NSString *)name
{
	if (tornDown) return;
	structureNeedsReset = YES;
	infoNeedsReset = YES;

	NSString *oldName = [sidebar selectedSequenceName];
	if (![name length] || [name isEqualToString:oldName]) return;

	// Renamed: History's entries for it name it by its new name (going back to them finds it, and the new name's
	// entry isn't a place of its own)
	[history renameTable:oldName to:name inDatabase:currentDatabase schema:[sidebar selectedSchema]];

	// Inside the sidebar's should-change callback: listed again once the selection has changed
	if (deferringSidebarReloads) {
		[self _deferSidebarReload];
		if (!deferredRenameFrom) deferredRenameFrom = [oldName copy];
		[deferredRenameTo release];
		deferredRenameTo = [name copy];
		return;
	}

	// Listed again, going straight from the old name to the new one (no other pane on the way)
	[sidebar reloadSchema:[sidebar selectedSchema] selectingSequence:name];
}

/// Table Info changed the table's comment: the Structure view is built again when it is next shown.
- (void)_tableInfoDidChange
{
	if (tornDown) return;
	structureNeedsReset = YES;
	// The information pane under the table list shows the saved comment (patched: nothing is read)
	[[sidebar infoPane] setComment:[[infoController commentView] string] forRelation:[infoController table] inSchema:[infoController schema]];
}

/// The shown pane reloads if it may be stale.
- (void)_refreshCurrentPaneIfStale
{
	if ([currentPane isEqualToString:SPPostgresPaneContent]) [self _refreshContentIfStale];
	else if ([currentPane isEqualToString:SPPostgresPaneStructure]) [self _refreshStructureIfStale];
	else if ([currentPane isEqualToString:SPPostgresPaneRelations]) [self _refreshRelationsIfStale];
	else if ([currentPane isEqualToString:SPPostgresPaneTriggers]) [self _refreshTriggersIfStale];
	else if ([currentPane isEqualToString:SPPostgresPaneInfo]) [self _refreshInfoIfStale];
	else if ([currentPane isEqualToString:SPPostgresPaneSequence]) [self _refreshSequenceIfStale];
	else if ([currentPane isEqualToString:SPPostgresPaneExtension]) [self _refreshExtensionIfStale];
}

/// Builds the Structure view again for the selected table (a new structure object, so a rename the server undid is forgotten).
- (void)_refreshStructureIfStale
{
	if (!structureNeedsReset && ![structureController isStale]) return;
	structureNeedsReset = NO;
	[structureController showTable:[sidebar selectedTableName] inSchema:[sidebar selectedSchema]];
}

/// Shows the selected table's foreign keys again; a view (or nothing) shows none (the pane has its empty state).
- (void)_refreshRelationsIfStale
{
	if (!relationsNeedReset && ![relationsController isStale]) return;
	relationsNeedReset = NO;
	BOOL isTable = [sidebar selectionIsTable];
	[relationsController showTable:isTable ? [sidebar selectedTableName] : nil inSchema:isTable ? [sidebar selectedSchema] : nil];
}

/// Shows the selected table's triggers again; a view (or nothing) shows none (the pane has its empty state).
- (void)_refreshTriggersIfStale
{
	if (!triggersNeedReset && ![triggersController isStale]) return;
	triggersNeedReset = NO;
	BOOL isTable = [sidebar selectionIsTable];
	[triggersController showTable:isTable ? [sidebar selectedTableName] : nil inSchema:isTable ? [sidebar selectedSchema] : nil];
}

/// Shows the selected table's or view's information again (nothing selected: empty).
- (void)_refreshInfoIfStale
{
	if (!infoNeedsReset && ![infoController isStale]) return;
	infoNeedsReset = NO;
	[infoController showTable:[sidebar selectedTableName] inSchema:[sidebar selectedSchema]];
}

/// Shows the selected sequence again (nothing selected: empty), dropping edits that weren't applied.
- (void)_refreshSequenceIfStale
{
	if (!sequenceNeedsReset && ![sequenceController isStale]) return;
	sequenceNeedsReset = NO;
	[sequenceController showSequence:[sidebar selectedSequenceName] inSchema:[sidebar selectedSchema]];
}

/// Shows the selected extension again (nothing selected: empty).
- (void)_refreshExtensionIfStale
{
	if (!extensionNeedsReset && ![extensionController isStale]) return;
	extensionNeedsReset = NO;
	[extensionController showExtension:[sidebar selectedExtensionName]];
}

/// Reloads the Content view if the Query view may have changed its table: afresh after DDL, else keeping its filter, sort
/// and page (a table switch that was cancelled: its table, from -reload).
- (void)_refreshContentIfStale
{
	if (!contentNeedsReload && !contentNeedsReset && ![contentController isStale]) return;
	BOOL reset = contentNeedsReset;
	contentNeedsReload = NO;
	contentNeedsReset = NO;

	if (reset) [contentController showTable:[sidebar selectedTableName] inSchema:[sidebar selectedSchema]];
	else [contentController reload];
}

/// The Content view (and the Structure view when shown) show the table or view selected in the sidebar (or nothing), and the pane's toolbar item is selected with it.
- (void)_showSelectedTable
{
	NSString *table = [sidebar selectedTableName];
	NSString *schema = [sidebar selectedSchema];

	// A switch to this table that was cancelled (the view is stale) loads it again
	if (![table isEqualToString:[contentController table]] || ![schema isEqualToString:[contentController schema]] || !table || [contentController isStale]) {
		[contentController showTable:table inSchema:schema];
		contentNeedsReload = NO;
		contentNeedsReset = NO;
	}

	// The Structure view follows when it is shown (or next time it is)
	if (!table || ![table isEqualToString:[structureController table]] || ![schema isEqualToString:[structureController schema]] || [structureController isStale]) structureNeedsReset = YES;
	if ([currentPane isEqualToString:SPPostgresPaneStructure]) [self _refreshStructureIfStale];

	// So do Relations and Triggers (for a table only)
	NSString *paneTable = [sidebar selectionIsTable] ? table : nil;
	if (!paneTable || ![paneTable isEqualToString:[relationsController table]] || ![schema isEqualToString:[relationsController schema]] || [relationsController isStale]) relationsNeedReset = YES;
	if (!paneTable || ![paneTable isEqualToString:[triggersController table]] || ![schema isEqualToString:[triggersController schema]] || [triggersController isStale]) triggersNeedReset = YES;
	if ([currentPane isEqualToString:SPPostgresPaneRelations]) [self _refreshRelationsIfStale];
	if ([currentPane isEqualToString:SPPostgresPaneTriggers]) [self _refreshTriggersIfStale];

	// So does Table Info (for a table or view)
	if (!table || ![table isEqualToString:[infoController table]] || ![schema isEqualToString:[infoController schema]] || [infoController isStale]) infoNeedsReset = YES;
	if ([currentPane isEqualToString:SPPostgresPaneInfo]) [self _refreshInfoIfStale];

	// A sequence has its own pane, shown whenever one is selected; when none is selected any more, the pane before
	// it comes back (its edits were applied, or vetoed the change, before the selection moved)
	NSString *sequence = [sidebar selectedSequenceName];
	NSString *extension = [sidebar selectedExtensionName];

	// Where to go back to from an extension (from one extension to another, it stays; from a sequence, the pane
	// before the sequence), noted before the Sequence pane gives way below
	if ([extension length] && !extensionSelected) {
		NSString *before = [currentPane isEqualToString:SPPostgresPaneSequence] ? (paneBeforeSequence ?: SPPostgresPaneContent) : currentPane;
		if (![before isEqualToString:SPPostgresPaneExtension]) {
			[paneBeforeExtension release];
			paneBeforeExtension = [before copy];
		}
	}

	if ([sequence length]) {
		// Where to go back to (from one sequence to another, it stays; from an extension, the pane before it)
		if (!sequenceSelected && ![currentPane isEqualToString:SPPostgresPaneSequence]) {
			[paneBeforeSequence release];
			paneBeforeSequence = [([currentPane isEqualToString:SPPostgresPaneExtension] ? (paneBeforeExtension ?: SPPostgresPaneContent) : currentPane) copy];
		}
		sequenceSelected = YES;
		BOOL sameSequence = [sequence isEqualToString:[sequenceController sequenceName]] && [schema isEqualToString:[sequenceController schema]];
		if (!sameSequence || [sequenceController isStale]) sequenceNeedsReset = YES;
		// The sequence the pane shows, listed again (renamed by Apply, or on leaving for the Query view, whose list
		// reload runs after the pane changed): the Query view stays
		if ([currentPane isEqualToString:SPPostgresPaneSequence]) [self _refreshSequenceIfStale];
		else if (!(sameSequence && [currentPane isEqualToString:SPPostgresPaneQuery])) [self showPane:SPPostgresPaneSequence];
	}
	else {
		sequenceSelected = NO;
		if ([sequenceController sequenceName]) [sequenceController showSequence:nil inSchema:nil];
		sequenceNeedsReset = NO;
		if ([currentPane isEqualToString:SPPostgresPaneSequence]) [self showPane:paneBeforeSequence ?: SPPostgresPaneContent];
	}

	// An extension has its own pane too, shown whenever one is selected (it has no edits to apply)
	if ([extension length]) {
		extensionSelected = YES;
		if (![extension isEqualToString:[extensionController extensionName]] || [extensionController isStale]) extensionNeedsReset = YES;
		if (![currentPane isEqualToString:SPPostgresPaneExtension]) [self showPane:SPPostgresPaneExtension];
		else [self _refreshExtensionIfStale];
	}
	else {
		extensionSelected = NO;
		if ([extensionController extensionName]) [extensionController showExtension:nil];
		extensionNeedsReset = NO;
		if ([currentPane isEqualToString:SPPostgresPaneExtension]) [self showPane:paneBeforeExtension ?: SPPostgresPaneContent];
	}

	// The pane stays when the selection changes (as MySQL's Query tab); one whose item is now disabled
	// (Relations or Triggers on a view) shows its empty state
	[self _updatePaneToolbarSelection];
	[self _updateEmptyStates];
}

- (void)_buildToolbar
{
	// As MySQL's picker and history control (DBView.xib), see SPMainToolbar.m
	databasePopup = [SPCreateDatabaseToolbarPopUpButton() retain];
	[databasePopup setToolTip:NSLocalizedString(@"Select a database to view", @"PostgreSQL window: database picker tooltip")];
	[databasePopup setTarget:self];
	[databasePopup setAction:@selector(chooseDatabase:)];
	[databasePopup setEnabled:!isProcessing];
	[self _reloadDatabasePopup];

	// Back and forward through the tab's history, as MySQL's control (SPHistoryController)
	historyControl = [SPCreateHistoryToolbarControl() retain];
	[historyControl setTarget:self];
	[historyControl setAction:@selector(historyControlClicked:)];

	// Installed in the window while this tab is active (see -didBecomeActiveTabInWindow). Set up as
	// MySQL's toolbar, so the user's saved layout and customizing it apply to both engines.
	toolbar = [[NSToolbar alloc] initWithIdentifier:SPPostgresDocumentToolbarIdentifier];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setAutosavesConfiguration:YES];
	[toolbar setShowsBaselineSeparator:NO];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
	[toolbar setDelegate:self];
}

- (NSToolbar *)toolbar
{
	return toolbar;
}

- (NSView *)databaseView
{
	return splitView;
}

#pragma mark - Tab document

- (BOOL)_isSelectedTab
{
	return parentWindowController && (id)[parentWindowController selectedDocument] == self;
}

/// Whether this tab may attach a sheet (an alert, a question, the New Table or Create Syntax sheet) to the window
/// now: it is the tab in front of a shown window. Otherwise the sheet waits (see -_presentPendingSheets).
- (BOOL)_canPresentSheet
{
	return [self _isSelectedTab] && [parentWindow isVisible];
}

/// What waited for this tab to be in front: an alert, then a Truncate/Remove question or the New Table sheet, then the
/// Create Syntax sheet (each re-checks that it can come up now).
- (void)_presentPendingSheets
{
	[self _presentPendingAlert];
	[self _presentPendingConfirmation];
	[self _presentPendingCreateSyntax];
}

/**
 * Installs this tab's toolbar (keeping the window's toolbar visibility, as MySQL tabs do), the
 * compact chrome and the window title.
 */
- (void)didBecomeActiveTabInWindow
{
	if (tornDown) return;

	BOOL toolbarVisible = ![parentWindow toolbar] || [[parentWindow toolbar] isVisible];
	[parentWindow setToolbar:toolbar];
	[[parentWindow toolbar] setVisible:toolbarVisible];

	// A layout saved before Transfer existed gets it once (the toolbar has its items once in a window)
	SPInsertTransferToolbarItemIfNeeded(toolbar, [NSUserDefaults standardUserDefaults]);
	// and, once, a saved layout's Transfer moves from after Users to right after Query
	SPMoveTransferToolbarItemAfterQueryIfNeeded(toolbar, [NSUserDefaults standardUserDefaults]);

	// Compact title and toolbar layout, kept centered as the window resizes
	[parentWindow sp_useExpandedCompactToolbar];

	// A MySQL tab shows its .spf file as the window's proxy icon; this tab has none
	[parentWindow setRepresentedURL:nil];

	[self _applyWindowTitle];
	[self _updateDatabaseToolbarItemWidth];
	[self _updateHistoryControl];

	// The task display is shown in this window while the tab is active (as MySQL's progress window)
	[taskDisplay setParentWindow:parentWindow];

	[self _presentPendingSheets];
}

- (void)willResignActiveTabInWindow
{
	// The next tab installs its own toolbar and title; the task display goes, as MySQL's progress window
	[taskDisplay setParentWindow:nil];
}

- (void)tabDidBecomeKey
{
	[self _presentPendingSheets];
}

- (NSString *)tabToolTip
{
	return [self windowTitleString];
}

/// The other open Postgres tabs of this window with the same connection name.
- (NSArray *)_namesakeTabs
{
	NSMutableArray *namesakes = [NSMutableArray array];
	NSString *name = [self _connectionName];

	for (id document in [parentWindowController tabDocuments]) {
		if (document == self || ![document isKindOfClass:[SPPostgresDocument class]]) continue;
		SPPostgresDocument *other = document;
		if (other->tornDown) continue;
		if ([[other _connectionName] isEqualToString:name]) [namesakes addObject:other];
	}

	return namesakes;
}

/**
 * The favorite name, plus @"/<database>" while another Postgres tab of the window has the same name
 * (as MySQL tabs add the database to tell connections to the same server apart).
 */
- (NSString *)tabLabel
{
	NSString *name = [self _connectionName];
	if ([currentDatabase length] && [[self _namesakeTabs] count]) return [NSString stringWithFormat:@"%@/%@", name, currentDatabase];
	return name;
}

/// Tab label (see -tabLabel) and colour (favorite colour); the window title too when this tab is selected.
- (void)updateWindowTitle:(id)sender
{
	if (tornDown) return;

	[parentTabViewItem setLabel:[self tabLabel]];
	[parentTabViewItem setColor:[[SPFavoriteColorSupport sharedInstance] colorForIndex:[favorite colorIndex]]];

	// Namesakes need the database in their labels too, also when this tab was added without being
	// selected (the window controller then only asks this tab to update)
	for (SPPostgresDocument *other in [self _namesakeTabs]) {
		if (![[[other parentTabViewItem] label] isEqualToString:[other tabLabel]]) [other updateWindowTitle:parentWindowController];
	}

	[parentWindowController updateTabBar];

	if ([self _isSelectedTab]) [self _applyWindowTitle];

	// As MySQL tabs: a change of our own may change other tabs' titles
	if (![sender isKindOfClass:[SPWindowController class]]) [parentWindowController updateAllTabTitles:self];
}

/// As MySQL's (couldCommitCurrentViewActions): an edit or Structure draft column that can't be saved keeps the tab
/// open, while connected; without a connection nothing could be saved, so it closes (dropping the draft), as MySQL's.
- (BOOL)parentTabShouldClose
{
	if (tornDown || ![connection isConnected]) return YES;
	return [self _endPaneEditing];
}

/// The tab was closed: disconnects (closing the SSH tunnel too) and detaches from the window.
- (void)parentTabDidClose
{
	NSArray *namesakes = [[[self _namesakeTabs] retain] autorelease];

	[self _tearDown];

	// A namesake left alone no longer needs the database in its label (this tab is out of the window's tabs by now)
	for (SPPostgresDocument *other in namesakes) [other updateWindowTitle:[other parentWindowController]];
}

#pragma mark - Title

- (NSString *)windowTitleString
{
	NSMutableString *title = [NSMutableString stringWithFormat:@"(PostgreSQL %@) %@/%@", serverVersion, [self _connectionName], currentDatabase ?: @""];

	NSString *table = [sidebar selectedTableName] ?: [sidebar selectedSequenceName];
	if ([table length]) [title appendFormat:@"/%@.%@", [sidebar selectedSchema], table];

	return title;
}

- (void)_applyWindowTitle
{
	if (!parentWindow) return;
	[parentWindow setTitle:[self windowTitleString]];
	[parentWindow sp_applyCompactTitle];
}

#pragma mark - Alerts

- (void)_presentAlert:(NSAlert *)alert
{
	if (tornDown) return;

	if (alertPresenter) {
		alertPresenter(alert);
		return;
	}

	// Not shown yet, or another tab is in front: show it when this tab is active again
	if (![self _canPresentSheet]) {
		if (!pendingAlert) pendingAlert = [alert retain];
		return;
	}

	// With a sheet already attached (e.g. a job's progress sheet still ending), AppKit queues this one behind it
	[alert beginSheetModalForWindow:parentWindow completionHandler:nil];
}

- (void)_presentPendingAlert
{
	if (!pendingAlert || ![self _canPresentSheet]) return;

	NSAlert *alert = pendingAlert;
	pendingAlert = nil;
	[self _presentAlert:alert];
	[alert release];
}

/// Asks alert's question (first button: proceed); completion runs exactly once.
- (void)_confirm:(NSAlert *)alert completion:(void (^)(BOOL confirmed))completion
{
	// A heap copy, so a presenter may keep it (even without copying it) until the answer comes. It runs once
	// and then balances its own Block_copy (deferred to the autorelease pool, as it is still running).
	void (^original)(BOOL) = completion;
	__block BOOL done = NO;
	__block void (^once)(BOOL) = nil;
	once = Block_copy(^(BOOL confirmed) {
		if (done) return;
		done = YES;
		original(confirmed);
		[(id)once autorelease];
	});

	if (confirmationPresenter) {
		confirmationPresenter(alert, once);
		return;
	}
	if (!parentWindow) {
		once([alert runModal] == NSAlertFirstButtonReturn);
		return;
	}
	[alert beginSheetModalForWindow:parentWindow completionHandler:^(NSModalResponse response) {
		once(response == NSAlertFirstButtonReturn);
	}];
}

/**
 * A catalog query failed (the lists keep what they showed). Shown once per failed reload; when the
 * connection is gone, says so (reconnecting is not offered in this version).
 */
- (void)_reportCatalogError:(NSError *)error
{
	NSString *detail = [[error localizedDescription] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setAlertStyle:NSAlertStyleWarning];

	NSString *advice;
	if (![connection isConnected]) {
		[alert setMessageText:NSLocalizedString(@"The connection to the PostgreSQL server was lost", @"PostgreSQL window: connection lost title")];
		advice = NSLocalizedString(@"The lists show what was loaded before the connection was lost. Close this tab and connect again.", @"PostgreSQL tab: connection lost advice");
	}
	else {
		[alert setMessageText:NSLocalizedString(@"Could not load the database objects", @"PostgreSQL window: catalog query failed title")];
		advice = NSLocalizedString(@"The lists show what was loaded before.", @"PostgreSQL window: catalog query failed advice");
	}
	[alert setInformativeText:[detail length] ? [NSString stringWithFormat:@"%@\n\n%@", detail, advice] : advice];

	[self _presentAlert:alert];
}

#pragma mark - Teardown

/// Closes the connection and detaches everything that points back at this document. Idempotent.
- (void)_tearDown
{
	if (tornDown) return;
	tornDown = YES;

	// A deferred sidebar reload's fallback (it retains self)
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reloadDeferredSidebar) object:nil];
	sidebarReloadDeferred = NO;
	[deferredReloadSchema release];
	deferredReloadSchema = nil;

	// The Database menu's waiting steps, and a switch's completion (both retain self)
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_runIdleActions) object:nil];
	[idleActions release];
	idleActions = nil;
	[pendingSwitchCompletion release];
	pendingSwitchCompletion = nil;
	// The Database menu's sheets on this window (their blocks retain self)
	if ([[[SPPostgresNameSheet currentSheet] sheet] sheetParent] == parentWindow) [[SPPostgresNameSheet currentSheet] cancel:nil];
	if ([[[SPPostgresAlterDatabaseSheet currentSheet] sheet] sheetParent] == parentWindow) [[SPPostgresAlterDatabaseSheet currentSheet] cancel:nil];
	if ([[[SPPostgresSchemaSheet currentSheet] sheet] sheetParent] == parentWindow) [[SPPostgresSchemaSheet currentSheet] cancel:nil];
	if ([[[SPPostgresServerListSheet currentSheet] sheet] sheetParent] == parentWindow) [[SPPostgresServerListSheet currentSheet] close:nil];

	// A pending database switch completes (cancelled) and lets go of its block, which retains self
	SPPostgresConnector *pending = pendingConnector;
	pendingConnector = nil;
	[pending cancel];
	[pending release];
	// The same for an Open Table in New Tab or Window: nothing is opened
	SPPostgresConnector *pendingOpen = pendingOpenConnector;
	pendingOpenConnector = nil;
	[pendingOpen cancel];
	[pendingOpen release];
	[openRelationConnectorFactory release];
	openRelationConnectorFactory = nil;
	[self _updateIsProcessing]; // NO from now on
	[pendingHistoryEntry release];
	pendingHistoryEntry = nil;

	// The Users sheet (or its connecting): ended as Cancel, its connections closed
	[usersController endSheet];

	// The Export sheet ends; an export running is cancelled (it deletes what it wrote)
	[exportController cancel:nil];

	// The Import panel or sheets end; an import running is cancelled (rolled back)
	[importController cancel];

	// The Transfer sheet ends; a transfer running is cancelled (the target's transaction rolls back)
	[transferController cancel:nil];

	// The Show Create Syntax sheet
	[self closeCreateSyntaxSheet:nil];
	[self _dropPendingCreateSyntax];

	// A Duplicate Table sheet still up (its completion sees tornDown)
	if (duplicateSheet) [[duplicateSheet sheetParent] endSheet:duplicateSheet returnCode:NSModalResponseCancel];

	// A load still running is cancelled and its completion never called; the connection (and SSH tunnel) is closed
	// once the worker has left it, without waiting here. The block keeps the connector.
	[taskDisplay invalidate];
	if (observingRunner) {
		[taskRunner removeObserver:self forKeyPath:@"busy" context:SPPostgresDocumentRunnerContext];
		observingRunner = NO;
	}
	SPPostgresConnector *theConnector = connector;
	[taskRunner invalidateWithCompletion:^{
		[theConnector disconnect];
	}];

	[sidebar invalidate];
	[sidebar setDelegate:nil];
	// A Rename Table sheet still up (its completion sees tornDown)
	if (renameSheet) [[renameSheet sheetParent] endSheet:renameSheet returnCode:NSModalResponseCancel];
	// A New Table sheet still up
	if (addTableSheet) [[addTableSheet sheetParent] endSheet:addTableSheet returnCode:NSModalResponseCancel];
	// An Add Sequence sheet still up (its completion sees tornDown)
	if (addSequenceSheet) [[addSequenceSheet sheetParent] endSheet:addSequenceSheet returnCode:NSModalResponseCancel];
	// An Install Extension sheet still up (an alert on it first; its completion sees tornDown)
	if (installExtensionSheet) {
		if ([installExtensionSheet attachedSheet]) [installExtensionSheet endSheet:[installExtensionSheet attachedSheet]];
		[[installExtensionSheet sheetParent] endSheet:installExtensionSheet returnCode:NSModalResponseCancel];
	}

	[contentController invalidate];
	[structureController invalidate];
	[relationsController invalidate];
	[triggersController invalidate];
	[infoController invalidate];
	[sequenceController invalidate]; // ends a Set Value sheet still up
	[extensionController invalidate];
	[queryScriptAutosaver invalidate]; // saves an edit not saved yet
	[queryController invalidate];
	[self _closeHelpViewer];
	[splitView setDelegate:nil];
	[databasePopup setTarget:nil];
	[historyControl setTarget:nil];
	[self _updateHistoryControl];

	for (NSToolbarItem *item in [toolbar items]) [item setTarget:nil];
	[toolbar setDelegate:nil];
	databaseToolbarItem = nil;
	if ([parentWindow toolbar] == toolbar) [parentWindow setToolbar:nil];

	// A presenter block may capture this document
	[alertPresenter release];
	alertPresenter = nil;
	[confirmationPresenter release];
	confirmationPresenter = nil;
	[pendingAlert release];
	pendingAlert = nil;
	// A question waiting for the tab to be idle (it retains self)
	[self _dropPendingConfirmation];

	// The window, its controller and the tab item may go away before this document does
	parentWindowController = nil;
	parentWindow = nil;
	parentTabViewItem = nil;
}

#pragma mark - Sidebar

- (void)sidebarSelectionDidChange:(SPPostgresSidebarController *)theSidebar
{
	if (tornDown) return;

	// While a quiet reload (see -_quietSidebarCompletion:) is outstanding, its selection changes aren't recorded
	BOOL wasRestoring = restoringHistory;
	if (quietSidebarReloads) restoringHistory = YES;
	[self _showSelectedTable];
	[self updateWindowTitle:self];
	[self _recordHistory];
	restoringHistory = wasRestoring;

	// The lists the edits saved on leaving changed, now that the selection the user chose is made
	[self _reloadDeferredSidebar];
}

/**
 * Another table or schema only once an edit in progress (or a Structure draft column) is saved, as MySQL's.
 *
 * The outline has already taken the row the user clicked (or moved to with the keyboard) when it asks: the sidebar
 * isn't reloaded until the selection has changed (-sidebarSelectionDidChange:), or else the run loop's next turn if
 * it doesn't change (e.g. the selected row clicked again).
 */
- (BOOL)sidebarShouldChangeSelection:(SPPostgresSidebarController *)theSidebar
{
	if (tornDown) return YES;

	BOOL wasDeferring = deferringSidebarReloads;
	deferringSidebarReloads = YES;
	BOOL ended = [self _endPaneEditing];
	deferringSidebarReloads = wasDeferring;

	if (sidebarReloadDeferred && !deferringSidebarReloads) {
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_reloadDeferredSidebar) object:nil];
		[self performSelector:@selector(_reloadDeferredSidebar) withObject:nil afterDelay:0];
	}
	return ended;
}

/// The bar's Refresh: the lists reload keeping the selection (not recorded in History), once an edit in progress is
/// saved. Refused while the tab is processing.
- (void)sidebarRefresh:(SPPostgresSidebarController *)theSidebar
{
	if (tornDown) return;
	if (isProcessing) {
		NSBeep();
		return;
	}
	if (![self _endPaneEditing]) return;
	[sidebar reloadKeepingSelection:[self _quietSidebarCompletion:nil]];
}

- (void)sidebar:(SPPostgresSidebarController *)theSidebar didFailToLoadWithError:(NSError *)error
{
	[self _reportCatalogError:error];
}

- (void)sidebar:(SPPostgresSidebarController *)theSidebar duplicateTableNamed:(NSString *)table
{
	[self _showDuplicateTableSheetForTable:table];
}

- (void)sidebar:(SPPostgresSidebarController *)theSidebar renameTableNamed:(NSString *)table
{
	[self _showRenameTableSheetForTable:table];
}

/// "Add Sequence…": the sheet (after the shown pane's edits are applied); on Add, the sequence is created and selected.
- (void)sidebar:(SPPostgresSidebarController *)theSidebar addSequenceInSchema:(NSString *)schema
{
	if (!SPPostgresFeatureIsAvailable(SPPostgresFeatureSequences)) return;
	if (tornDown || addSequenceSheet || duplicateSheet || renameSheet || ![schema length] || !parentWindow || isProcessing || [parentWindow attachedSheet]) return;
	if (![self _endPaneEditing] || ![parentWindow makeFirstResponder:nil]) return;

	NSString *theSchema = [[schema copy] autorelease];
	NSWindow *sheet = [SPPostgresSequenceSheet beginInSchema:theSchema connection:connection window:parentWindow completion:^(SPPostgresSequenceDefinition *definition) {
		[addSequenceSheet release];
		addSequenceSheet = nil;
		if (definition && !tornDown) [self _createSequence:definition inSchema:theSchema];
	}];
	[addSequenceSheet release];
	addSequenceSheet = [sheet retain];
}

/// Creates the sequence; on success lists and selects it, else shows the server's message.
- (void)_createSequence:(SPPostgresSequenceDefinition *)definition inSchema:(NSString *)schema
{
	if ([self _refuseWriteWhileBusy]) return;
	SPPostgresSequences *sequences = [[[SPPostgresSequences alloc] initWithConnection:connection schema:schema] autorelease];
	NSError *error = nil;
	if (![sequences createSequence:definition error:&error]) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setAlertStyle:NSAlertStyleWarning];
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Could not add the sequence “%@”", @"PostgreSQL add sequence failed"), [definition name]]];
		[alert setInformativeText:[error localizedDescription] ?: @""];
		[self _presentAlert:alert];
		return;
	}

	// The schema the sidebar shows (the sheet was modal)
	if (![schema isEqualToString:[sidebar selectedSchema]]) return;
	// Straight to the new sequence (no empty selection, so no other pane, on the way)
	[sidebar reloadSchema:schema selectingSequence:[definition name]];
}

/// "Delete Sequence…": asked first (after the shown pane's edits are applied); a sequence that columns use is not
/// dropped, and they are listed.
- (void)sidebar:(SPPostgresSidebarController *)theSidebar deleteSequenceNamed:(NSString *)name
{
	if (!SPPostgresFeatureIsAvailable(SPPostgresFeatureSequences)) return;
	if (tornDown || ![name length] || isProcessing) return;
	if (![self _endPaneEditing]) return;

	NSString *schema = [[[sidebar selectedSchema] copy] autorelease];
	NSString *sequence = [[name copy] autorelease];

	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"Delete", @"delete button")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	[[[alert buttons] objectAtIndex:0] setKeyEquivalent:@"\r"];
	[[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\033"];
	[alert setAlertStyle:NSAlertStyleCritical];
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Delete sequence \"%@\"?", @"PostgreSQL delete sequence confirmation"), sequence]];
	[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the sequence \"%@\"? This action cannot be undone.", @"PostgreSQL delete sequence confirmation detail"), sequence]];

	// The document stays alive until the answer comes (a sheet's or a presenter's)
	[self retain];
	[self _confirm:alert completion:^(BOOL confirmed) {
		if (confirmed && !tornDown) [self _dropSequence:sequence inSchema:schema];
		[self release];
	}];
}

/// Drops the sequence (never CASCADE); on success the lists reload (the selection is kept unless it was the one).
- (void)_dropSequence:(NSString *)name inSchema:(NSString *)schema
{
	if ([self _refuseWriteWhileBusy]) return;
	SPPostgresSequences *sequences = [[[SPPostgresSequences alloc] initWithConnection:connection schema:schema] autorelease];
	NSError *error = nil;
	if (![sequences dropSequence:name error:&error]) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setAlertStyle:NSAlertStyleWarning];
		if ([[error domain] isEqualToString:SPPostgresErrorDomain] && [error code] == SPPostgresErrorHasDependents) {
			// The columns, one per line
			[alert setMessageText:[error localizedDescription]];
			[alert setInformativeText:[[[error userInfo] objectForKey:SPPostgresDependentsErrorKey] componentsJoinedByString:@"\n"] ?: @""];
		}
		else {
			[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Could not delete the sequence “%@”", @"PostgreSQL delete sequence failed"), name]];
			[alert setInformativeText:[error localizedDescription] ?: @""];
		}
		[self _presentAlert:alert];
		return;
	}

	// A column default may have named it (Structure), and the lists change
	structureNeedsReset = YES;
	if (![schema isEqualToString:[sidebar selectedSchema]]) return;
	[sidebar reloadKeepingSelection:[self _quietSidebarCompletion:nil]];
}

#pragma mark - Truncate and Remove

/// A Truncate or Remove confirmation as MySQL's (critical; the action first, ⌘ + key, then Cancel, Return).
- (NSAlert *)_tableActionAlert:(NSString *)action key:(NSString *)key message:(NSString *)message informativeText:(NSString *)informativeText
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:action];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	NSButton *actionButton = [[alert buttons] objectAtIndex:0];
	[actionButton setHasDestructiveAction:YES];
	[actionButton setKeyEquivalent:key];
	[actionButton setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
	[[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\r"];
	[alert setAlertStyle:NSAlertStyleCritical];
	[alert setMessageText:message];
	[alert setInformativeText:informativeText];
	return alert;
}

/**
 * Runs present (a Truncate or Remove question, or the New Table sheet) once the tab's runner is idle and the tab is in
 * front of a shown window: at once if both hold, else when processing ends (see -_updateIsProcessing) or the tab comes
 * to the front (see -_presentPendingSheets). Saving an edit before the question may have queued a list reload, and a
 * write confirmed while it runs would be refused; another tab in front shares the window. One question waits at a
 * time (a second is ignored); it is dropped on teardown and when the runner is replaced.
 */
- (void)_presentWhenIdle:(void (^)(void))present
{
	if (![taskRunner isBusy] && [self _canPresentSheet]) {
		present();
		return;
	}
	if (pendingConfirmation) return;
	pendingConfirmation = [present copy];
}

/// The waiting question, on the run loop turn after processing ended (not inside the runner's notification), or when
/// the tab comes to the front.
- (void)_presentPendingConfirmation
{
	if (!pendingConfirmation || tornDown || isProcessing || ![self _canPresentSheet]) return;
	void (^present)(void) = pendingConfirmation;
	pendingConfirmation = nil;
	present();
	[present release];
}

- (void)_dropPendingConfirmation
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_presentPendingConfirmation) object:nil];
	[pendingConfirmation release];
	pendingConfirmation = nil;
}

/// Whether a waiting question can still be asked: nothing changed under it (the tab, a sheet, the schema, the names listed).
- (BOOL)_canAskAbout:(NSArray *)names inSchema:(NSString *)schema sections:(NSArray *)sections
{
	if (tornDown || !parentWindow || [parentWindow attachedSheet] || isProcessing) return NO;
	if (![schema isEqualToString:[sidebar selectedSchema]]) return NO;
	NSMutableArray *listed = [NSMutableArray array];
	for (NSString *section in sections) [listed addObjectsFromArray:[sidebar itemTitlesInSection:section] ?: @[]];
	for (NSString *name in names) {
		if (![listed containsObject:name]) return NO;
	}
	return YES;
}

/// The change was confirmed while a load had started meanwhile: nothing was done, and the user is told.
- (void)_presentBusyRefusal:(NSString *)message
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setAlertStyle:NSAlertStyleWarning];
	[alert setMessageText:message];
	[self _presentAlert:alert];
}

/// "Truncate Table(s)": MySQL's question (after the shown pane's edits are applied, once the tab is idle), with a
/// Restart identity checkbox (off), then every row of the tables is deleted in one TRUNCATE (never CASCADE; RESTART
/// IDENTITY when checked): all of them or, on an error, none.
- (void)sidebar:(SPPostgresSidebarController *)theSidebar truncateTables:(NSArray<NSString *> *)tables
{
	if (tornDown || ![tables count] || isProcessing || !parentWindow || [parentWindow attachedSheet]) return;
	if (![self _endPaneEditing]) return;

	NSString *schema = [[[sidebar selectedSchema] copy] autorelease];
	NSArray *names = [[tables copy] autorelease];

	NSString *message, *informativeText;
	if ([names count] == 1) {
		NSString *name = [names firstObject];
		message = [NSString stringWithFormat:NSLocalizedString(@"Truncate table '%@'?", @"truncate table message"), name];
		informativeText = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete ALL records in the table '%@'? This operation cannot be undone.", @"truncate table informative message"), name];
	}
	else {
		message = NSLocalizedString(@"Truncate selected tables?", @"truncate tables message");
		informativeText = NSLocalizedString(@"Are you sure you want to delete ALL records in the selected tables? This operation cannot be undone.", @"truncate tables informative message");
	}
	NSAlert *alert = [self _tableActionAlert:NSLocalizedString(@"Truncate", @"truncate button") key:@"t" message:message informativeText:informativeText];

	// Whether the tables' serial and identity columns start again (TRUNCATE … RESTART IDENTITY); off by default
	NSButton *restartIdentity = [NSButton checkboxWithTitle:NSLocalizedString(@"Restart identity (reset serial and identity counters)", @"PostgreSQL truncate: restart identity checkbox") target:nil action:NULL];
	[restartIdentity setIdentifier:@"restartIdentity"];
	[restartIdentity setState:NSControlStateValueOff];
	[restartIdentity setToolTip:NSLocalizedString(@"Adds RESTART IDENTITY: the sequences owned by the tables' columns are reset", @"PostgreSQL truncate: restart identity checkbox tooltip")];
	[restartIdentity sizeToFit];
	[alert setAccessoryView:restartIdentity];

	[self _presentWhenIdle:^{
		// Something changed under it meanwhile: dropped, with a beep (as a refused action)
		if (![self _canAskAbout:names inSchema:schema sections:@[@"TABLES"]]) {
			NSBeep();
			return;
		}
		// The document stays alive until the answer comes (a sheet's or a presenter's)
		[self retain];
		[self _confirm:alert completion:^(BOOL confirmed) {
			if (confirmed && !tornDown) [self _truncateTables:names inSchema:schema restartIdentity:[restartIdentity state] == NSControlStateValueOn];
			[self release];
		}];
	}];
}

- (void)_truncateTables:(NSArray *)tables inSchema:(NSString *)schema restartIdentity:(BOOL)restartIdentity
{
	if ([self _refuseWriteWhileBusy]) {
		[self _presentBusyRefusal:NSLocalizedString(@"The tab is busy, so nothing was truncated.", @"PostgreSQL truncate refused while the tab is busy")];
		return;
	}
	NSError *error = nil;
	if (![SPPostgresTableActions truncateTables:tables inSchema:schema restartIdentity:restartIdentity connection:connection error:&error]) {
		[self _presentTableActionError:error title:NSLocalizedString(@"Error truncating table", @"error truncating table message")];
		return;
	}

	// The rows (and the sizes and row estimate) are gone from Content and Table Info if they show one of the tables
	if ([schema isEqualToString:[contentController schema]] && [tables containsObject:[contentController table] ?: @""]) contentNeedsReset = YES;
	if ([schema isEqualToString:[infoController schema]] && [tables containsObject:[infoController table] ?: @""]) infoNeedsReset = YES;
	[self _relationsDidChangeInSchema:schema];
}

/**
 * "Reduce Storage…": a question (after the shown pane's edits are applied, once the tab is idle) saying what it does
 * and that the tables are locked meanwhile, then `VACUUM (FULL, ANALYZE)` on each table in the tab's runner (Cancel
 * stops it on the server), then each table's size before and after. Plain VACUUM keeps the space for new rows; FULL
 * rewrites the table and gives the space back to the disk.
 */
- (void)sidebar:(SPPostgresSidebarController *)theSidebar reduceStorageOfTables:(NSArray<NSString *> *)tables
{
	[self _askToReduceStorageOfTables:tables all:NO];
}

/// "Reduce Storage of All Tables…": the same for every table of the schema; a table the user doesn't own (or that is
/// gone by then) is skipped and listed in the result, rather than stopping the others.
- (void)sidebar:(SPPostgresSidebarController *)theSidebar reduceStorageOfAllTables:(NSArray<NSString *> *)tables
{
	[self _askToReduceStorageOfTables:tables all:YES];
}

- (void)_askToReduceStorageOfTables:(NSArray<NSString *> *)tables all:(BOOL)all
{
	if (tornDown || ![tables count] || isProcessing || !parentWindow || [parentWindow attachedSheet]) return;
	if (![self _endPaneEditing]) return;

	NSString *schema = [[[sidebar selectedSchema] copy] autorelease];
	NSArray *names = [[tables copy] autorelease];

	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"Reduce Storage", @"PostgreSQL reduce storage button")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	[[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\r"];
	[alert setAlertStyle:NSAlertStyleWarning];
	if (all) {
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Reduce the storage of all %lu tables in schema '%@'?", @"PostgreSQL reduce storage of all tables message"), (unsigned long)[names count], schema]];
	}
	else if ([names count] == 1) {
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Reduce the storage of table '%@'?", @"PostgreSQL reduce storage message"), [names firstObject]]];
	}
	else {
		[alert setMessageText:NSLocalizedString(@"Reduce the storage of the selected tables?", @"PostgreSQL reduce storage tables message")];
	}
	[alert setInformativeText:NSLocalizedString(@"The space left by deleted and updated rows is given back to the disk, and the statistics are updated (VACUUM FULL, ANALYZE). No rows are changed.\n\nEach table is rewritten and locked while that happens: nothing can read or write it until it is done, which can take a long time for a big table. The rewrite needs free disk space about the size of the table.", @"PostgreSQL reduce storage informative message")];

	[self _presentWhenIdle:^{
		if (![self _canAskAbout:names inSchema:schema sections:@[@"TABLES"]]) {
			NSBeep();
			return;
		}
		[self retain];
		[self _confirm:alert completion:^(BOOL confirmed) {
			if (confirmed && !tornDown) [self _reduceStorageOfTables:names inSchema:schema all:all];
			[self release];
		}];
	}];
}

- (void)_reduceStorageOfTables:(NSArray *)tables inSchema:(NSString *)schema all:(BOOL)all
{
	if ([self _refuseWriteWhileBusy]) {
		[self _presentBusyRefusal:NSLocalizedString(@"The tab is busy, so the storage was not reduced.", @"PostgreSQL reduce storage refused while the tab is busy")];
		return;
	}
	NSArray *theTables = [[tables copy] autorelease];
	NSString *theSchema = [[schema copy] autorelease];
	NSString *description;
	if (all) description = [NSString stringWithFormat:NSLocalizedString(@"Reducing the storage of all tables in '%@'...", @"PostgreSQL reduce storage of all tables task"), theSchema];
	else if ([theTables count] == 1) description = [NSString stringWithFormat:NSLocalizedString(@"Reducing the storage of '%@'...", @"PostgreSQL reduce storage task"), [theTables firstObject]];
	else description = NSLocalizedString(@"Reducing the storage of the selected tables...", @"PostgreSQL reduce storage tables task");
	[taskRunner runTaskWithDescription:description cancelTitle:NSLocalizedString(@"Cancel", @"cancel button") work:^id(PGPostgresConnection *theConnection, NSError **error) {
		return [SPPostgresTableActions reduceStorageOfTables:theTables inSchema:theSchema skippingTablesNotAllowed:all lockTimeout:SPPostgresReduceStorageLockTimeout connection:theConnection error:error];
	} completion:^(id result, NSError *error, BOOL cancelled) {
		if (tornDown) return;
		// Sizes and statistics changed (also for the tables done before a failure or a cancel)
		if ([theSchema isEqualToString:[infoController schema]] && [theTables containsObject:[infoController table] ?: @""]) infoNeedsReset = YES;
		[self _relationsDidChangeInSchema:theSchema];
		if (cancelled) return;
		if (!result) {
			[self _presentTableActionError:error title:NSLocalizedString(@"Error reducing storage", @"PostgreSQL reduce storage error title")];
			return;
		}

		NSMutableArray *lines = [NSMutableArray array];
		NSMutableArray *skipped = [NSMutableArray array];
		long long before = 0, after = 0;
		for (NSDictionary *size in result) {
			NSString *reason = [size objectForKey:@"skipped"];
			if (reason) {
				[skipped addObject:[NSString stringWithFormat:NSLocalizedString(@"%@: skipped (%@)", @"PostgreSQL reduce storage result line: table skipped, reason"), [size objectForKey:@"table"], reason]];
				continue;
			}
			before += [[size objectForKey:@"before"] longLongValue];
			after += [[size objectForKey:@"after"] longLongValue];
			[lines addObject:[NSString stringWithFormat:NSLocalizedString(@"%@: %@ → %@", @"PostgreSQL reduce storage result line: table, size before, size after"),
							  [size objectForKey:@"table"],
							  [SPPostgresCatalog stringForSize:[[size objectForKey:@"before"] longLongValue]],
							  [SPPostgresCatalog stringForSize:[[size objectForKey:@"after"] longLongValue]]]];
		}
		BOOL anyReduced = ([lines count] > 0);
		NSAlert *done = [[[NSAlert alloc] init] autorelease];
		[done setAlertStyle:NSAlertStyleInformational];
		[done setMessageText:anyReduced ? NSLocalizedString(@"Storage reduced", @"PostgreSQL reduce storage done title") : NSLocalizedString(@"No table's storage was reduced", @"PostgreSQL reduce storage: every table skipped")];
		// Several tables: the total first; the skipped ones last
		if ([lines count] > 1) {
			[lines insertObject:[NSString stringWithFormat:NSLocalizedString(@"Total: %@ → %@", @"PostgreSQL reduce storage result total: size before, size after"), [SPPostgresCatalog stringForSize:before], [SPPostgresCatalog stringForSize:after]] atIndex:0];
			[lines insertObject:@"" atIndex:1];
		}
		if ([skipped count]) {
			if ([lines count]) [lines addObject:@""];
			[lines addObjectsFromArray:skipped];
		}
		[done setInformativeText:[lines componentsJoinedByString:@"\n"]];
		[self _presentAlert:done];
	}];
}

/// "Delete Table/View/Tables/Views/Items": MySQL's question (after the shown pane's edits are applied, once the tab
/// is idle), then the tables and views are dropped in one structure change (never CASCADE): all of them or, on an
/// error, none.
- (void)sidebar:(SPPostgresSidebarController *)theSidebar removeRelations:(NSArray<NSString *> *)names
{
	if (tornDown || ![names count] || isProcessing || !parentWindow || [parentWindow attachedSheet]) return;
	if (![self _endPaneEditing]) return;

	NSString *schema = [[[sidebar selectedSchema] copy] autorelease];
	NSArray *relations = [[names copy] autorelease];

	NSUInteger views = 0;
	for (NSString *name in relations) {
		if ([sidebar relationIsView:name]) views++;
	}

	NSString *message, *informativeText;
	if ([relations count] == 1) {
		NSString *name = [relations firstObject];
		NSString *kind = views ? NSLocalizedString(@"view", @"view") : NSLocalizedString(@"table", @"table");
		message = [NSString stringWithFormat:NSLocalizedString(@"Delete %@ '%@'?", @"delete table/view message"), kind, name];
		informativeText = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the %@ '%@'? This operation cannot be undone.", @"delete table/view informative message"), kind, name];
	}
	else {
		NSString *kinds;
		if (!views) kinds = NSLocalizedString(@"tables", @"tables");
		else if (views == [relations count]) kinds = NSLocalizedString(@"views", @"views");
		else kinds = NSLocalizedString(@"items", @"items");
		message = [NSString stringWithFormat:NSLocalizedString(@"Delete selected %@?", @"delete tables/views message"), kinds];
		informativeText = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the selected %@? This operation cannot be undone.", @"delete tables/views informative message"), kinds];
	}
	NSAlert *alert = [self _tableActionAlert:NSLocalizedString(@"Delete", @"delete button") key:@"d" message:message informativeText:informativeText];

	[self _presentWhenIdle:^{
		// Something changed under it meanwhile: dropped, with a beep (as a refused action)
		if (![self _canAskAbout:relations inSchema:schema sections:@[@"TABLES", @"VIEWS"]]) {
			NSBeep();
			return;
		}
		// The document stays alive until the answer comes (a sheet's or a presenter's)
		[self retain];
		[self _confirm:alert completion:^(BOOL confirmed) {
			if (confirmed && !tornDown) [self _removeRelations:relations inSchema:schema];
			[self release];
		}];
	}];
}

/**
 * Drops the tables and views; on success the lists reload, and a removed relation that was selected leaves nothing
 * selected (the panes show no table). History keeps its entries: going to a removed table's selects nothing, as for
 * any table that has gone.
 */
- (void)_removeRelations:(NSArray *)names inSchema:(NSString *)schema
{
	if ([self _refuseWriteWhileBusy]) {
		[self _presentBusyRefusal:NSLocalizedString(@"The tab is busy, so nothing was deleted.", @"PostgreSQL delete tables refused while the tab is busy")];
		return;
	}
	NSError *error = nil;
	if (![SPPostgresTableActions dropRelations:names inSchema:schema connection:connection error:&error]) {
		[self _presentTableActionError:error title:NSLocalizedString(@"Error deleting table", @"error deleting table message")];
		return;
	}

	// A dropped table takes its owned sequences with it (a shown Sequence pane reads afresh)
	contentNeedsReset = YES;
	infoNeedsReset = YES;
	sequenceNeedsReset = YES;
	[self _relationsDidChangeInSchema:schema];
}

/// After a Truncate or Remove: the table panes read afresh and the lists reload keeping the selection (if still
/// listed), not as a place the user went to; then the shown pane is refreshed.
- (void)_relationsDidChangeInSchema:(NSString *)schema
{
	structureNeedsReset = YES;
	relationsNeedReset = YES;
	triggersNeedReset = YES;
	if (![schema isEqualToString:[sidebar selectedSchema]]) return;
	[sidebar reloadKeepingSelection:[self _quietSidebarCompletion:^(BOOL loaded) {
		[self updateWindowTitle:self];
		[self _refreshCurrentPaneIfStale];
	}]];
}

/// The lines of error's message before its HINT (the message's last part, see SPPostgresErrorDetailLines). The HINT
/// is left out of the table actions' errors: it may suggest CASCADE, never offered here.
- (NSArray<NSString *> *)_messageLinesWithoutHint:(NSError *)error
{
	NSString *hintLabel = NSLocalizedString(@"HINT:", @"Postgres query: error hint label");
	NSMutableArray *lines = [NSMutableArray array];
	for (NSString *line in [[error localizedDescription] ?: @"" componentsSeparatedByString:@"\n"]) {
		if ([line hasPrefix:hintLabel]) break;
		[lines addObject:line];
	}
	return lines;
}

/**
 * A Truncate or Remove error as MySQL's: its title, then the server's message without its HINT (which suggests
 * CASCADE, never offered here); objects that depend on a table are listed one per line after the message.
 */
- (void)_presentTableActionError:(NSError *)error title:(NSString *)title
{
	NSArray *lines = [self _messageLinesWithoutHint:error];
	NSString *text = [lines componentsJoinedByString:@"\n"];

	if ([[error domain] isEqualToString:SPPostgresErrorDomain] && [error code] == SPPostgresErrorHasDependents) {
		NSString *serverMessage = [lines firstObject] ?: @"";
		NSString *dependents = [[[error userInfo] objectForKey:SPPostgresDependentsErrorKey] componentsJoinedByString:@"\n"];
		text = [dependents length] ? [NSString stringWithFormat:@"%@\n\n%@", serverMessage, dependents] : serverMessage;
	}

	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setAlertStyle:NSAlertStyleCritical];
	[alert setMessageText:title];
	[alert setInformativeText:text];
	[self _presentAlert:alert];
}

#pragma mark - Export and Create Syntax from the table list

/**
 * Export ▸ "As SQL dump…" (format 0) or "As CSV file…" (1) from the table list: the Export sheet (as File ▸ Export…,
 * when it can open), its Selected tables source with exactly these tables checked and the format chosen. A view can't
 * be exported as a table: it is left unchecked.
 */
- (void)sidebar:(SPPostgresSidebarController *)theSidebar exportRelations:(NSArray<NSString *> *)names format:(NSInteger)format
{
	if (!SPPostgresFeatureIsAvailable(SPPostgresFeatureImportExport)) return;
	if (tornDown || ![names count]) return;

	SPPostgresExportController *previous = exportController;
	[self export:nil];
	SPPostgresExportController *controller = exportController;
	// Not opened (a sheet job couldn't run), or it ended at once
	if (!controller || controller == previous || ![controller sheet]) return;

	NSString *schema = [sidebar selectedSchema];
	for (NSArray *pair in [[[controller checkedTables] copy] autorelease]) {
		[controller setChecked:NO table:[pair objectAtIndex:1] schema:[pair objectAtIndex:0]];
	}
	for (NSString *name in names) {
		if ([sidebar relationIsView:name]) continue;
		[controller setChecked:YES table:name schema:schema];
	}

	// Selected tables (the source popup's third item), and the format: the controls follow through their actions
	NSPopUpButton *source = [controller sourcePopup];
	[source selectItemAtIndex:2];
	[source sendAction:[source action] to:[source target]];
	NSSegmentedControl *formatControl = [controller formatControl];
	[formatControl setSelectedSegment:(format == 1) ? 1 : 0];
	[formatControl sendAction:[formatControl action] to:[formatControl target]];
}

- (NSPasteboard *)createSyntaxPasteboard
{
	return createSyntaxPasteboard ?: [NSPasteboard generalPasteboard];
}

/**
 * "Show Create … Syntax…" (copy NO: a sheet) or "Copy Create … Syntax" (copy YES: createSyntaxPasteboard), as MySQL's:
 * the statements are read in a task of the tab's runner (SPPostgresCreateStatement), each headed "-- Create syntax for
 * TABLE|VIEW 'name'" when there are several. A failure shows MySQL's alert with the server's message.
 */
- (void)sidebar:(SPPostgresSidebarController *)theSidebar showCreateSyntaxForRelations:(NSArray<NSString *> *)names copy:(BOOL)copy
{
	if (!SPPostgresFeatureIsAvailable(SPPostgresFeatureCreateSyntax)) return;
	if (tornDown || ![names count] || isProcessing) return;
	// An edit in progress is saved first, so the statements include it (as the other table actions)
	if (![self _endPaneEditing]) return;

	NSString *schema = [[[sidebar selectedSchema] copy] autorelease];
	NSArray *relations = [[names copy] autorelease];
	NSMutableArray *types = [NSMutableArray arrayWithCapacity:[relations count]];
	for (NSString *name in relations) [types addObject:[sidebar relationIsView:name] ? @"VIEW" : @"TABLE"];
	NSArray *typeStrings = [[types copy] autorelease];

	[taskRunner runTaskWithDescription:NSLocalizedString(@"Loading...", @"Postgres create syntax: loading task") cancelTitle:NSLocalizedString(@"Cancel", @"cancel button") work:^id(PGPostgresConnection *theConnection, NSError **error) {
		NSMutableArray *parts = [NSMutableArray arrayWithCapacity:[relations count]];
		for (NSUInteger i = 0; i < [relations count]; i++) {
			NSString *statement = [SPPostgresCreateStatement createStatementForTable:[relations objectAtIndex:i] inSchema:schema connection:theConnection error:error];
			if (!statement) return nil;
			if ([relations count] > 1) {
				statement = [NSString stringWithFormat:@"-- Create syntax for %@ '%@'\n%@", [typeStrings objectAtIndex:i], [relations objectAtIndex:i], statement];
			}
			[parts addObject:statement];
		}
		return [parts componentsJoinedByString:@"\n"];
	} completion:^(id result, NSError *error, BOOL cancelled) {
		if (tornDown || cancelled) return;
		if (!result) {
			[self _presentTableActionError:error title:NSLocalizedString(@"An error occured while creating table syntax.", @"Postgres create syntax error message")];
			return;
		}
		if (copy) {
			NSPasteboard *pasteboard = [self createSyntaxPasteboard];
			[pasteboard clearContents];
			[pasteboard setString:result forType:NSPasteboardTypeString];
			return;
		}
		NSString *title = ([relations count] == 1)
			? [NSString stringWithFormat:NSLocalizedString(@"Create syntax for %@ '%@'", @"Create syntax label"), [typeStrings firstObject], [relations firstObject]]
			: NSLocalizedString(@"Create syntaxes for selected items", @"Create syntaxes for selected items label");
		[self _showCreateSyntax:result title:title];
	}];
}

/// MySQL's Create Syntax sheet (createTableSyntaxWindow), built in code: its label, a non-editable monospaced text
/// view, Copy and Close.
- (void)_showCreateSyntax:(NSString *)syntax title:(NSString *)title
{
	if (tornDown || !parentWindow) return;
	// Another sheet is up, or another tab is in front: shown once that sheet has ended or this tab is in front again
	// (the latest result only)
	if ([parentWindow attachedSheet] || ![self _canPresentSheet]) {
		BOOL observing = (pendingCreateSyntax != nil);
		[pendingCreateSyntax release];
		pendingCreateSyntax = [@[syntax, title] retain];
		if (!observing) [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_sheetDidEndWhileCreateSyntaxPending:) name:NSWindowDidEndSheetNotification object:parentWindow];
		return;
	}

	NSRect frame = NSMakeRect(0, 0, 620, 420);
	NSPanel *panel = [[NSPanel alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:YES];
	[panel setReleasedWhenClosed:NO];
	[panel setTitle:title];
	[panel setMinSize:NSMakeSize(400, 250)];
	NSView *content = [panel contentView];

	NSTextField *label = [NSTextField labelWithString:title];
	[label setFrame:NSMakeRect(20, NSHeight(frame) - 36, NSWidth(frame) - 40, 17)];
	[label setFont:[NSFont boldSystemFontOfSize:[NSFont systemFontSize]]];
	[label setLineBreakMode:NSLineBreakByTruncatingMiddle];
	[label setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
	[label setIdentifier:@"createSyntaxLabel"];
	[content addSubview:label];

	NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(20, 60, NSWidth(frame) - 40, NSHeight(frame) - 108)] autorelease];
	[scrollView setBorderType:NSBezelBorder];
	[scrollView setHasVerticalScroller:YES];
	[scrollView setHasHorizontalScroller:YES];
	[scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	NSTextView *textView = [[[NSTextView alloc] initWithFrame:[[scrollView contentView] bounds]] autorelease];
	[textView setIdentifier:@"createSyntaxText"];
	[textView setRichText:NO];
	[textView setFont:[NSFont monospacedSystemFontOfSize:[NSFont systemFontSize] weight:NSFontWeightRegular]];
	[textView setAutomaticQuoteSubstitutionEnabled:NO];
	[textView setAutomaticDashSubstitutionEnabled:NO];
	[textView setString:syntax];
	[textView setEditable:NO];
	[textView setSelectable:YES];
	// No wrapping: long lines scroll sideways
	[textView setHorizontallyResizable:YES];
	[textView setMaxSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
	[[textView textContainer] setWidthTracksTextView:NO];
	[[textView textContainer] setContainerSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
	[textView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[scrollView setDocumentView:textView];
	[content addSubview:scrollView];

	NSButton *close = [NSButton buttonWithTitle:NSLocalizedString(@"Close", @"close button") target:self action:@selector(closeCreateSyntaxSheet:)];
	[close setFrame:NSMakeRect(NSWidth(frame) - 20 - 100, 14, 100, 32)];
	[close setKeyEquivalent:@"\r"];
	[close setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
	[close setIdentifier:@"createSyntaxCloseButton"];
	[content addSubview:close];

	NSButton *copyButton = [NSButton buttonWithTitle:NSLocalizedString(@"Copy", @"copy button") target:self action:@selector(copyCreateSyntax:)];
	[copyButton setFrame:NSMakeRect(NSWidth(frame) - 20 - 100 - 100, 14, 100, 32)];
	[copyButton setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
	[copyButton setIdentifier:@"createSyntaxCopyButton"];
	[content addSubview:copyButton];

	// As MySQL's hidden "Close via ESC" button: out of sight, Escape closes the sheet
	NSButton *escape = [NSButton buttonWithTitle:@"" target:self action:@selector(closeCreateSyntaxSheet:)];
	[escape setFrame:NSMakeRect(-200, -200, 10, 10)];
	[escape setKeyEquivalent:@"\e"];
	[escape setRefusesFirstResponder:YES];
	[escape setIdentifier:@"createSyntaxEscapeButton"];
	[content addSubview:escape];

	[createSyntaxSheet release];
	createSyntaxSheet = panel; // takes the alloc's reference
	[createSyntaxTextView release];
	createSyntaxTextView = [textView retain];
	[parentWindow beginSheet:panel completionHandler:nil];
}

/// A sheet ended on the window: the waiting Create Syntax sheet comes up on the next run loop turn (once the ended
/// sheet is off the window), unless another sheet is attached by then (it waits for that one).
- (void)_sheetDidEndWhileCreateSyntaxPending:(NSNotification *)notification
{
	[self performSelector:@selector(_presentPendingCreateSyntax) withObject:nil afterDelay:0];
}

- (void)_presentPendingCreateSyntax
{
	if (!pendingCreateSyntax || tornDown || [parentWindow attachedSheet] || ![self _canPresentSheet]) return;
	NSArray *pending = [[pendingCreateSyntax retain] autorelease];
	[self _dropPendingCreateSyntax];
	[self _showCreateSyntax:[pending objectAtIndex:0] title:[pending objectAtIndex:1]];
}

- (void)_dropPendingCreateSyntax
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_presentPendingCreateSyntax) object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidEndSheetNotification object:nil];
	[pendingCreateSyntax release];
	pendingCreateSyntax = nil;
}

/// The sheet's Copy: the statements to createSyntaxPasteboard.
- (IBAction)copyCreateSyntax:(id)sender
{
	if (!createSyntaxTextView) return;
	NSPasteboard *pasteboard = [self createSyntaxPasteboard];
	[pasteboard clearContents];
	[pasteboard setString:[createSyntaxTextView string] forType:NSPasteboardTypeString];
}

/// The sheet's Close (also on teardown).
- (IBAction)closeCreateSyntaxSheet:(id)sender
{
	if (!createSyntaxSheet) return;
	NSPanel *panel = createSyntaxSheet;
	createSyntaxSheet = nil;
	if ([panel sheetParent]) [[panel sheetParent] endSheet:panel];
	[panel orderOut:nil];
	[panel release];
	[createSyntaxTextView release];
	createSyntaxTextView = nil;
}

#pragma mark - Open Table in New Tab or Window

- (void)sidebar:(SPPostgresSidebarController *)theSidebar openRelation:(NSString *)name inNewWindow:(BOOL)newWindow
{
	[self openRelation:name inSchema:[theSidebar selectedSchema] inNewWindow:newWindow];
}

- (void)openRelation:(NSString *)name inSchema:(NSString *)schema inNewWindow:(BOOL)newWindow
{
	if (![name length]) return;
	[self _openInNewTabRelation:name inSchema:schema inNewWindow:newWindow];
}

/// -openRelation:inSchema:inNewWindow:, or (name nil) the database alone: the new tab shows the same pane and schema.
- (void)_openInNewTabRelation:(NSString *)name inSchema:(NSString *)schema inNewWindow:(BOOL)newWindow
{
	if (tornDown) return;
	// Also while one is connecting already (isProcessing)
	if (isProcessing) {
		NSBeep();
		return;
	}

	// The favorite on this tab's database, and the passwords this session was opened with (as a database switch's), so
	// nothing is asked again or read from the Keychain that this session didn't need; an SSH favorite's connector opens
	// a tunnel of its own (its sheets, if any, on this window)
	SPPostgresFavorite *target = [[favorite copy] autorelease];
	[target setDatabase:currentDatabase];
	NSString *thePassword = [connector password] ?: [connection password];
	NSString *theSSHPassword = [connector sshPassword];
	SPPostgresConnector *newConnector = openRelationConnectorFactory
		? [openRelationConnectorFactory(target, thePassword, theSSHPassword, parentWindow) retain]
		: [[SPPostgresConnector alloc] initWithFavorite:target password:thePassword sshPassword:theSSHPassword parentWindow:parentWindow];
	if (!newConnector) return;

	pendingOpenConnector = newConnector;
	[self _updateIsProcessing]; // the tab shows it is connecting

	// The connector keeps the completion until it is called (always exactly once), which keeps self alive meanwhile;
	// the connector is captured unretained (no connector -> block -> connector cycle)
	__block SPPostgresConnector *blockConnector = newConnector;
	NSString *theName = [[name copy] autorelease];
	NSString *theSchema = [[schema copy] autorelease];
	// As MySQL's (which duplicates the session): the new tab shows the pane shown here, and the Query editor's text
	NSString *thePane = [[currentPane copy] autorelease];
	NSString *theQueryText = [[[[queryController editor] string] copy] autorelease];
	[newConnector connectWithCompletion:^(PGPostgresConnection *newConnection, NSError *error) {
		[self _openRelation:theName inSchema:theSchema pane:thePane queryText:theQueryText inNewWindow:newWindow favorite:target by:blockConnector finishedWithConnection:newConnection error:error];
	}];
}

- (void)_openRelation:(NSString *)name inSchema:(NSString *)schema pane:(NSString *)pane queryText:(NSString *)queryText inNewWindow:(BOOL)newWindow favorite:(SPPostgresFavorite *)theFavorite by:(SPPostgresConnector *)theConnector finishedWithConnection:(PGPostgresConnection *)newConnection error:(NSError *)error
{
	// Cancelled by the tab closing (the teardown let go of it)
	if (tornDown || theConnector != pendingOpenConnector) return;

	SPPostgresConnector *newConnector = pendingOpenConnector; // takes over our reference
	pendingOpenConnector = nil;
	[self _updateIsProcessing];

	SPWindowController *windowController = newWindow ? nil : parentWindowController;
	if (!newConnection || (!newWindow && !windowController)) {
		[newConnector disconnect];
		[newConnector release];
		if (!newConnection && ([error code] != SPPostgresErrorCancelled || ![[error domain] isEqualToString:SPPostgresErrorDomain])) {
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert setAlertStyle:NSAlertStyleWarning];
			[alert setMessageText:[NSString stringWithFormat:(newWindow
				? NSLocalizedString(@"Could not open “%@” in a new window", @"PostgreSQL open table in new window failed (table)")
				: NSLocalizedString(@"Could not open “%@” in a new tab", @"PostgreSQL open table in new tab failed (table)")), name ?: [theFavorite database]]];
			[alert setInformativeText:[error localizedDescription] ?: @""];
			[self _presentAlert:alert];
		}
		return;
	}

	// The new tab takes over the connector (and disconnects it when it closes)
	SPPostgresDocument *document = [[[SPPostgresDocument alloc] initWithConnection:newConnection connector:newConnector favorite:theFavorite] autorelease];
	[newConnector release];

	if (newWindow) {
		// As -[SPAppController newWindow]: the window's delegate is its controller, which lets go of itself when the
		// window closes (-windowWillClose:)
		windowController = [[SPWindowController alloc] initWithWindowNibName:@"MainWindow"];
		NSWindow *window = [windowController window];
		if (parentWindow) {
			// This window's size (without its toolbar, which the new tab installs), cascaded from it
			NSRect frame = [parentWindow frame];
			if ([[parentWindow toolbar] isVisible]) {
				NSRect content = [NSWindow contentRectForFrameRect:frame styleMask:[parentWindow styleMask]];
				frame.size.height -= content.size.height - [[parentWindow contentView] frame].size.height;
			}
			[window setFrame:frame display:NO];
			NSPoint next = [window cascadeTopLeftFromPoint:NSMakePoint(NSMinX([parentWindow frame]), NSMaxY([parentWindow frame]))];
			[window setFrameTopLeftPoint:next];
		}
		[window setDelegate:windowController];
		[windowController addTabDocument:document atIndex:0 select:YES];
		[windowController showWindow:self];
	}
	else {
		// Right after this tab, selected
		NSUInteger index = [[windowController tabDocuments] indexOfObjectIdenticalTo:self];
		NSInteger position = (index == NSNotFound) ? (NSInteger)[[windowController tabDocuments] count] : (NSInteger)index + 1;
		[windowController addTabDocument:document atIndex:position select:YES];
	}

	if ([queryText length]) [[[document queryController] editor] setString:queryText];
	if ([name length]) [document selectRelationAfterLoad:name inSchema:schema pane:pane];
	else [document showSchemaAfterLoad:schema pane:pane];
}

/// The new tab of Open Database in New Tab: the schema (when given) and the pane (Query, or a table's pane, which shows
/// nothing until a table is selected), once the lists are loaded.
- (void)showSchemaAfterLoad:(NSString *)schema pane:(NSString *)pane
{
	if (tornDown) return;
	NSString *thePane = [@[SPPostgresPaneStructure, SPPostgresPaneContent, SPPostgresPaneRelations, SPPostgresPaneTriggers, SPPostgresPaneInfo, SPPostgresPaneQuery] containsObject:pane] ? [[pane copy] autorelease] : nil;
	void (^show)(BOOL) = ^(BOOL loaded) {
		if (!thePane || [thePane isEqualToString:currentPane]) return;
		BOOL wasRestoring = restoringHistory;
		restoringHistory = YES;
		[self showPane:thePane];
		restoringHistory = wasRestoring;
	};
	if ([schema length]) [sidebar reloadSchema:schema completion:[self _quietSidebarCompletion:show]];
	else show(YES);
}

- (void)selectRelationAfterLoad:(NSString *)name inSchema:(NSString *)schema
{
	[self selectRelationAfterLoad:name inSchema:schema pane:nil];
}

- (void)selectRelationAfterLoad:(NSString *)name inSchema:(NSString *)schema pane:(NSString *)pane
{
	if (tornDown || ![name length]) return;

	// A table's or view's pane, or Query (not a sequence's or an extension's)
	NSArray *panes = @[SPPostgresPaneStructure, SPPostgresPaneContent, SPPostgresPaneRelations, SPPostgresPaneTriggers, SPPostgresPaneInfo, SPPostgresPaneQuery];
	NSString *thePane = [panes containsObject:pane] ? [[pane copy] autorelease] : nil;

	// The reload queues on the runner behind the loads asked for so far (the first ones of a new tab), and its
	// selection changes on the way aren't places the user went to. Then the pane (first, so another pane doesn't
	// show the table on the way; not a place the user went to either), and the table or view once its schema is shown
	NSString *theName = [[name copy] autorelease];
	NSString *theSchema = [[schema copy] autorelease];
	void (^select)(BOOL) = ^(BOOL loaded) {
		if (thePane && ![thePane isEqualToString:currentPane]) {
			BOOL wasRestoring = restoringHistory;
			restoringHistory = YES;
			[self showPane:thePane];
			restoringHistory = wasRestoring;
		}
		if ([theSchema length] && ![theSchema isEqualToString:[sidebar selectedSchema]]) return;
		[sidebar selectTableNamed:theName];
	};
	if ([theSchema length]) [sidebar reloadSchema:theSchema completion:[self _quietSidebarCompletion:select]];
	else [sidebar reloadKeepingSelection:[self _quietSidebarCompletion:select]];
}

#pragma mark - Extensions

/// "Install Extension…": the sheet (after the shown pane's edits are applied), its install schema starting at the
/// schema selected in the left panel; on Install, the lists reload and the new extension is selected.
- (IBAction)showInstallExtensionSheet:(id)sender
{
	if (!SPPostgresFeatureIsAvailable(SPPostgresFeatureExtensions)) return;
	if (tornDown || installExtensionSheet || addSequenceSheet || duplicateSheet || renameSheet || !parentWindow || isProcessing || [parentWindow attachedSheet]) return;
	if (![self _endPaneEditing] || ![parentWindow makeFirstResponder:nil]) return;

	[SPPostgresInstallExtensionSheet beginWithConnection:connection schema:[sidebar selectedSchema] window:parentWindow completion:^(NSString *name) {
		[installExtensionSheet release];
		installExtensionSheet = nil;
		if (name && !tornDown) [self _extensionInstalled:name];
	}];
	NSWindow *sheet = [parentWindow attachedSheet];
	if (!sheet) return;
	[installExtensionSheet release];
	installExtensionSheet = [sheet retain];
	// The tab's alerts go where its other alerts go (tests)
	if (alertPresenter) [[SPPostgresInstallExtensionSheet currentSheet] setAlertPresenter:alertPresenter];
	// It reads and installs on the main thread: not while the tab's runner is busy
	[[SPPostgresInstallExtensionSheet currentSheet] setTaskRunner:taskRunner];
}

/// After an install: the lists reload (it may have brought tables, views, types), and the new extension is selected
/// and shown.
- (void)_extensionInstalled:(NSString *)name
{
	NSString *extension = [[name copy] autorelease];
	[self _extensionsDidChange:^{
		[sidebar selectExtensionNamed:extension];
	}];
}

/// "Install Extension…" in the sidebar's menu.
- (void)sidebarInstallExtension:(SPPostgresSidebarController *)theSidebar
{
	[self showInstallExtensionSheet:theSidebar];
}

/// "Drop Extension…" in the sidebar's menu: asked first; an extension other objects depend on is not dropped, and
/// they are listed.
- (void)sidebar:(SPPostgresSidebarController *)theSidebar dropExtensionNamed:(NSString *)name
{
	if (!SPPostgresFeatureIsAvailable(SPPostgresFeatureExtensions)) return;
	if (tornDown || ![name length] || isProcessing) return;
	if (![self _endPaneEditing]) return;

	NSString *extension = [[name copy] autorelease];

	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"Drop", @"PostgreSQL drop extension confirmation: drop button")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	[[[alert buttons] objectAtIndex:0] setHasDestructiveAction:YES];
	[[[alert buttons] objectAtIndex:0] setKeyEquivalent:@"\r"];
	[[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\033"];
	[alert setAlertStyle:NSAlertStyleCritical];
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Drop extension “%@”?", @"PostgreSQL drop extension confirmation"), extension]];
	[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to drop the extension “%@” from this database? This action cannot be undone.", @"PostgreSQL drop extension confirmation detail"), extension]];

	// The document stays alive until the answer comes (a sheet's or a presenter's)
	[self retain];
	[self _confirm:alert completion:^(BOOL confirmed) {
		if (confirmed && !tornDown) [self _dropExtension:extension];
		[self release];
	}];
}

/// Drops the extension (never CASCADE); on success the lists reload (nothing selected if it was the selection), else the server's
/// message (or the objects that depend on it, one per line) is shown.
- (void)_dropExtension:(NSString *)name
{
	if ([self _refuseWriteWhileBusy]) return;
	// Only the dropped extension's own selection goes (a table, sequence or another extension stays selected)
	BOOL wasSelected = [name isEqualToString:[sidebar selectedExtensionName]];

	SPPostgresExtensions *extensions = [[[SPPostgresExtensions alloc] initWithConnection:connection] autorelease];
	NSError *error = nil;
	if (![extensions dropExtension:name error:&error]) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setAlertStyle:NSAlertStyleWarning];
		if ([[error domain] isEqualToString:SPPostgresErrorDomain] && [error code] == SPPostgresErrorHasDependents) {
			// The dependents, one per line
			[alert setMessageText:[error localizedDescription]];
			[alert setInformativeText:[[[error userInfo] objectForKey:SPPostgresDependentsErrorKey] componentsJoinedByString:@"\n"] ?: @""];
		}
		else {
			[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Could not drop the extension “%@”", @"PostgreSQL drop extension failed"), name]];
			[alert setInformativeText:[error localizedDescription] ?: @""];
		}
		[self _presentAlert:alert];
		return;
	}

	[self _extensionsDidChange:^{
		if (!wasSelected) return;

		// Nothing is selected after the selected extension's drop (not a place the user went to)
		BOOL wasRestoring = restoringHistory;
		restoringHistory = YES;
		[sidebar selectTableNamed:nil];
		restoringHistory = wasRestoring;
	}];
}

/**
 * An extension was installed, updated or dropped: it may have brought or taken tables, views, types and functions,
 * so the lists reload keeping the selection (if still listed), and the panes read afresh, as after Query-view DDL.
 */
- (void)_extensionsDidChange
{
	[self _extensionsDidChange:nil];
}

/// The same, then `then` once the lists are shown and the shown pane refreshed (not if torn down).
- (void)_extensionsDidChange:(void (^)(void))then
{
	if (tornDown) return;
	contentNeedsReset = YES;
	structureNeedsReset = YES;
	relationsNeedReset = YES;
	triggersNeedReset = YES;
	infoNeedsReset = YES;
	sequenceNeedsReset = YES;
	extensionNeedsReset = YES;

	void (^after)(void) = [[then copy] autorelease];
	[self _reloadSidebarKeepingSelection:^{
		[self _refreshCurrentPaneIfStale];
		if (after) after();
	}];
}

- (void)extensionController:(SPPostgresExtensionController *)controller didChangeExtension:(NSString *)name
{
	[self _extensionsDidChange];
}

- (void)extensionController:(SPPostgresExtensionController *)controller wantsToDropExtension:(NSString *)name
{
	[self sidebar:sidebar dropExtensionNamed:name];
}

#pragma mark - Databases

/// Lists the databases again, through the tab's runner (one task, "Reloading...", not cancellable on its own; a cancel of
/// everything queued keeps what is listed).
- (void)_reloadDatabasePopup
{
	if (tornDown) return;
	// The connection's option: only its database (the tab's, always listed), not the others
	if (![favorite showAllDatabases]) {
		[self _showDatabaseNames:@[] error:nil];
		return;
	}
	SPPostgresCatalog *theCatalog = catalog;
	[taskRunner runTaskWithDescription:NSLocalizedString(@"Reloading...", @"Reloading table task string") cancelTitle:nil work:^id(PGPostgresConnection *theConnection, NSError **error) {
		return [theCatalog databaseNames:error];
	} completion:^(id names, NSError *error, BOOL cancelled) {
		if (tornDown || cancelled || theCatalog != catalog) return;
		[self _showDatabaseNames:names error:error];
	}];
}

/// The pop-up lists names (nil: they couldn't be read: the error is reported, and the databases listed stay), the
/// tab's database selected.
- (void)_showDatabaseNames:(NSArray *)names error:(NSError *)error
{
	if (!names) {
		// Keep the databases that were listed
		names = [self _listedDatabaseNames];
		[self _reportCatalogError:error];
	}

	// As MySQL's (-[SPDatabaseDocument setDatabases:]): "Choose Database...", Add Database... and Refresh Databases,
	// then the databases
	[databasePopup removeAllItems];
	NSMenu *menu = [databasePopup menu];
	[databasePopup addItemWithTitle:NSLocalizedString(@"Choose Database...", @"menu item for choose db")];
	[menu addItem:[NSMenuItem separatorItem]];
	[[menu addItemWithTitle:NSLocalizedString(@"Add Database...", @"menu item to add db") action:@selector(addDatabase:) keyEquivalent:@""] setTarget:self];
	[[menu addItemWithTitle:NSLocalizedString(@"Refresh Databases", @"menu item to refresh databases") action:@selector(refreshDatabases:) keyEquivalent:@""] setTarget:self];
	[menu addItem:[NSMenuItem separatorItem]];

	// Items, not -addItemsWithTitles: (which drops a title already in the menu)
	for (NSString *name in names) [menu addItemWithTitle:name action:NULL keyEquivalent:@""];
	if ([currentDatabase length] && ![names containsObject:currentDatabase]) [menu addItemWithTitle:currentDatabase action:NULL keyEquivalent:@""];

	[self _selectCurrentDatabaseInPopup];
}

/// Index of the first database in the pop-up (after its second separator), or the item count when none.
- (NSInteger)_firstDatabaseIndexInPopup
{
	NSInteger separators = 0;
	NSArray *items = [databasePopup itemArray];
	for (NSUInteger i = 0; i < [items count]; i++) {
		if ([[items objectAtIndex:i] isSeparatorItem] && ++separators == 2) return (NSInteger)i + 1;
	}
	return (NSInteger)[items count];
}

- (void)refreshDatabases:(id)sender
{
	if (tornDown) return;
	// Chosen in the pop-up: it shows the tab's database again
	[self _selectCurrentDatabaseInPopup];
	// A cell or field edit is saved first, while nothing else uses the connection (the busy state would end it)
	if (![self _endPaneEditing]) {
		[self _selectCurrentDatabaseInPopup];
		return;
	}
	[self _reloadDatabasePopup];
}

- (void)chooseDatabase:(id)sender
{
	// "Choose Database...": nothing to switch to
	if ([databasePopup indexOfSelectedItem] < [self _firstDatabaseIndexInPopup]) {
		[self _selectCurrentDatabaseInPopup];
		return;
	}
	NSString *database = [databasePopup titleOfSelectedItem];
	if ([database isEqualToString:currentDatabase]) return;
	[self switchToDatabase:database];
}

/// The pop-up shows the database the tab is in (after a switch that didn't start).
- (void)_selectCurrentDatabaseInPopup
{
	NSInteger first = [self _firstDatabaseIndexInPopup];
	NSArray *items = [databasePopup itemArray];
	for (NSInteger i = first; i < (NSInteger)[items count]; i++) {
		if ([currentDatabase length] && [[[items objectAtIndex:(NSUInteger)i] title] isEqualToString:currentDatabase]) {
			[databasePopup selectItemAtIndex:i];
			return;
		}
	}
	if ([databasePopup numberOfItems]) [databasePopup selectItemAtIndex:0];
}

- (void)switchToDatabase:(NSString *)database
{
	if (tornDown || confirmingSwitch || ![database length]) {
		[self _selectCurrentDatabaseInPopup];
		return;
	}
	// Not while the tab is processing (the pop-up is disabled then): a load runs, or a switch is connecting
	if (isProcessing) {
		NSBeep();
		[self _selectCurrentDatabaseInPopup];
		return;
	}

	// As MySQL's (couldCommitCurrentViewActions): an edit in progress in the shown pane is saved first
	if (![self _endPaneEditing]) {
		[self _selectCurrentDatabaseInPopup];
		return;
	}

	[self _confirmLeavingSession:^(BOOL proceed) {
		if (proceed) [self _switchToDatabase:database forHistory:NO];
		else [self _selectCurrentDatabaseInPopup];
	}];
}

/**
 * Closing this session (a database switch) rolls back a transaction the user opened in the Query view:
 * when one is open (or aborted) they are asked first. completion(YES) when the switch may go ahead.
 */
- (void)_confirmLeavingSession:(void (^)(BOOL proceed))completion
{
	// Read on the tab's runner, once what is queued (e.g. a reload after saving an edit) is done: libpq's status isn't
	// the session's while a statement runs. Cancelled: no switch.
	void (^then)(BOOL) = [[completion copy] autorelease];
	confirmingSwitch = YES;
	[self _updateHistoryControl];
	[taskRunner runTaskWithDescription:nil cancelTitle:nil work:^id(PGPostgresConnection *theConnection, NSError **error) {
		return @([theConnection transactionStatus]);
	} completion:^(id status, NSError *error, BOOL cancelled) {
		confirmingSwitch = NO;
		[self _updateHistoryControl];
		if (tornDown || cancelled) {
			then(NO);
			return;
		}
		[self _confirmLeavingSessionWithStatus:(PGPostgresTransactionStatus)[status integerValue] completion:then];
	}];
}

/// The rest of -_confirmLeavingSession: with the session's transaction status.
- (void)_confirmLeavingSessionWithStatus:(PGPostgresTransactionStatus)status completion:(void (^)(BOOL proceed))completion
{
	if (status != PGPostgresTransactionInTransaction && status != PGPostgresTransactionInError) {
		completion(YES);
		return;
	}

	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:NSLocalizedString(@"Switch", @"PostgreSQL database switch with open transaction: switch button")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	[[[alert buttons] objectAtIndex:0] setKeyEquivalent:@"\r"];
	[[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\033"];
	[alert setAlertStyle:NSAlertStyleWarning];
	[alert setMessageText:NSLocalizedString(@"You have an open transaction.", @"PostgreSQL database switch with open transaction: title")];
	[alert setInformativeText:NSLocalizedString(@"Switching database will roll it back. Are you sure you want to continue?", @"PostgreSQL database switch with open transaction: message")];

	confirmingSwitch = YES;
	[self _updateHistoryControl];

	// The document stays alive until the answer comes (a sheet's or a presenter's)
	[self retain];
	void (^after)(BOOL) = [[completion copy] autorelease];
	[after retain];
	[self _confirm:alert completion:^(BOOL confirmed) {
		confirmingSwitch = NO;
		[self _updateHistoryControl];
		after(confirmed && !tornDown);
		[after release];
		[self release];
	}];
}

/// forHistory: to show pendingHistoryEntry; else (the user's choice) a history move waiting for a switch is given up.
- (void)_switchToDatabase:(NSString *)database forHistory:(BOOL)forHistory
{
	if (tornDown || ![database length]) return;
	if (!forHistory && pendingHistoryEntry) [self _abandonHistoryRestore];
	if ([database isEqualToString:currentDatabase] && !pendingConnector) return;

	SPPostgresFavorite *target = [[favorite copy] autorelease];
	[target setDatabase:database];

	// Same favorite and the passwords the current session was opened with, so an SSH favorite isn't asked
	// again (without one, SSH passwords come from the Keychain or the tunnel's prompt on this window)
	NSString *thePassword = [connector password] ?: [connection password];
	SPPostgresConnector *newConnector = [[SPPostgresConnector alloc] initWithFavorite:target password:thePassword sshPassword:[connector sshPassword] parentWindow:parentWindow];

	// Only the latest request counts: an earlier pending one is abandoned (its completion is then ignored, and what
	// asked for it is told it didn't happen)
	void (^abandoned)(BOOL) = [pendingSwitchCompletion autorelease];
	pendingSwitchCompletion = nil;
	if (abandoned) [self _whenIdle:^{ abandoned(NO); }];
	SPPostgresConnector *previous = pendingConnector;
	pendingConnector = newConnector;
	[previous cancel];
	[previous release];

	[self _updateIsProcessing]; // disables the pop-up
	[self _updateHistoryControl];

	// The connector keeps the completion until it is called (always exactly once), which also keeps self
	// alive meanwhile; the connector itself is captured unretained to avoid a connector -> block -> connector cycle.
	__block SPPostgresConnector *blockConnector = newConnector;
	[newConnector connectWithCompletion:^(PGPostgresConnection *newConnection, NSError *error) {
		[self _databaseSwitchBy:blockConnector favorite:target finishedWithConnection:newConnection error:error];
	}];
}

- (void)_databaseSwitchBy:(SPPostgresConnector *)theConnector favorite:(SPPostgresFavorite *)theFavorite finishedWithConnection:(PGPostgresConnection *)newConnection error:(NSError *)error
{
	// Superseded, or cancelled by the tab closing
	if (theConnector != pendingConnector) return;

	SPPostgresConnector *newConnector = pendingConnector; // takes over our reference
	pendingConnector = nil;
	[self _updateIsProcessing]; // the pop-up follows

	// What asked for this switch (-_switchToDatabase:then:)
	void (^switched)(BOOL) = [pendingSwitchCompletion autorelease];
	pendingSwitchCompletion = nil;

	if (!newConnection) {
		[newConnector release];
		[self _selectCurrentDatabaseInPopup];
		if (switched) [self _whenIdle:^{ switched(NO); }];

		// A history move to that database didn't happen: back where it was, so it can be tried again
		if (pendingHistoryEntry) [self _abandonHistoryRestore];
		[self _updateHistoryControl];

		if ([error code] != SPPostgresErrorCancelled || ![[error domain] isEqualToString:SPPostgresErrorDomain]) {
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			[alert setAlertStyle:NSAlertStyleWarning];
			[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Could not open database “%@”", @"PostgreSQL window: database switch failed (database)"), [theFavorite database]]];
			[alert setInformativeText:[error localizedDescription] ?: @""];
			[self _presentAlert:alert];
		}
		return;
	}

	SPPostgresConnector *oldConnector = connector;

	// The previous session's loads are cancelled (their completions never called), and it is closed once its worker
	// has left it (the block keeps the connector). -_attachCurrentConnection gives the new connection a runner.
	SPPostgresTaskRunner *oldRunner = [[taskRunner retain] autorelease];
	[self _setTaskRunner:nil];
	quietSidebarReloads = 0; // their completions are never called now
	confirmingSwitch = NO;   // nor a transaction check's
	[oldRunner invalidateWithCompletion:^{
		[oldConnector disconnect];
	}];

	connector = newConnector;
	[connection release];
	connection = [newConnection retain];
	[favorite release];
	favorite = [theFavorite retain];

	[self _attachCurrentConnection];
	listsNeedReload = NO; // all reloaded below, from the new session

	// A history move: the reload's default schema is not a place the user went to
	NSDictionary *historyEntry = [[pendingHistoryEntry retain] autorelease];
	[pendingHistoryEntry release];
	pendingHistoryEntry = nil;

	// The panes on the new connection, and the history entry, once the new database's lists are shown
	void (^listsShown)(BOOL) = ^(BOOL loaded) {
		if (tornDown) return;
		// A history move's panes aren't places the user went to either (its entry is recorded already)
		BOOL wasRestoring = restoringHistory;
		if (historyEntry) restoringHistory = YES;
		[self _installQueryController];
		[self _installStructureController];
		[self _installRelationsController];
		[self _installTriggersController];
		[self _installInfoController];
		[self _installSequenceController];
		[self _installExtensionController];
		[self _installContentController];
		[self _reloadDatabasePopup];

		// Not against lists that couldn't be read (the sidebar shows them empty; the failure is reported already)
		if (historyEntry && loaded) [self _applyHistoryEntry:historyEntry];
		restoringHistory = wasRestoring;

		[self updateWindowTitle:self];
		[self _updateHistoryControl];
		if (switched) [self _whenIdle:^{ switched(YES); }];
	};
	[self _installSidebarRunner];
	// Not cancellable (database switches keep their Stage 2 flow), and none of the previous database's lists stays
	[sidebar reloadWithNewCatalog:catalog completion:historyEntry ? [self _quietSidebarCompletion:listsShown] : listsShown];

	[oldConnector release];
}

#pragma mark - History

/// Records where the tab is now (database, schema, table, pane), unless a history entry is being shown.
- (void)_recordHistory
{
	if (tornDown || restoringHistory || pendingHistoryEntry || ![currentDatabase length]) return;
	// Extensions are the database's, and History entries a schema's: an extension (and its pane) isn't recorded
	if ([[sidebar selectedExtensionName] length] || [currentPane isEqualToString:SPPostgresPaneExtension]) return;
	// Nor is a selection of several tables and views (the panes show none of them)
	if ([[sidebar selectedRelationNames] count] > 1) return;
	// A selected sequence is recorded as the entry's table (names are unique among a schema's relations)
	NSString *table = [sidebar selectedTableName] ?: [sidebar selectedSequenceName];
	[history recordDatabase:currentDatabase schema:[sidebar selectedSchema] table:table pane:currentPane];
	[self _updateHistoryControl];
}

/// The History control's segments follow canGoBack/canGoForward (both off while a database switch connects).
- (void)_updateHistoryControl
{
	// Off for good while this build's scope holds Table History back (SPPostgresFeatureScope); entries are still recorded
	BOOL enabled = !tornDown && !isProcessing && !confirmingSwitch && SPPostgresFeatureIsAvailable(SPPostgresFeatureTableHistory);
	[historyControl setEnabled:enabled && [history canGoBack] forSegment:0];
	[historyControl setEnabled:enabled && [history canGoForward] forSegment:1];
}

/// The History toolbar control: segment 0 goes back, 1 forward.
- (IBAction)historyControlClicked:(NSSegmentedControl *)sender
{
	switch ([sender selectedSegment]) {
		case 0: [self _goBackInHistory:YES]; break;
		case 1: [self _goBackInHistory:NO]; break;
	}
}

/// View > Back In History (tag 0) and Forward In History (tag 1), as on MySQL tabs.
- (IBAction)backForwardInHistory:(id)sender
{
	switch ([sender tag]) {
		case 0: [self _goBackInHistory:YES]; break;
		case 1: [self _goBackInHistory:NO]; break;
	}
}

/// Shows the previous (back) or next history entry, switching database first if it is in another one.
- (void)_goBackInHistory:(BOOL)back
{
	if (!SPPostgresFeatureIsAvailable(SPPostgresFeatureTableHistory)) return;
	if (tornDown || isProcessing || confirmingSwitch) return;

	// As MySQL's (couldCommitCurrentViewActions): an edit in progress in the shown pane is ended (saved) first. A list
	// reload that saving asks for (a sequence renamed) runs once the entry is shown, so it can't select the renamed
	// sequence after the entry's selection is made (it keeps the entry's).
	BOOL wasDeferring = deferringSidebarReloads;
	deferringSidebarReloads = YES;
	BOOL ended = [self _endPaneEditing];
	deferringSidebarReloads = wasDeferring;
	if (!ended) {
		[self _reloadDeferredSidebar];
		return;
	}

	NSDictionary *entry = back ? [history goBack] : [history goForward];
	if (!entry) {
		[self _reloadDeferredSidebar];
		return;
	}

	NSString *database = [entry objectForKey:@"database"];
	if ([database length] && ![database isEqualToString:currentDatabase]) {
		// Shown once the switch is done (see -_databaseSwitchBy:…), or undone if it fails or isn't confirmed
		[pendingHistoryEntry release];
		pendingHistoryEntry = [entry retain];
		pendingHistoryWentBack = back;
		[self _confirmLeavingSession:^(BOOL proceed) {
			if (proceed) [self _switchToDatabase:database forHistory:YES];

			// No switch was started (cancelled, or torn down): the entry mustn't stay pending, which would stop
			// recording for good
			if (!pendingConnector) [self _abandonHistoryRestore];
			[self _updateHistoryControl];
		}];
	}
	else {
		[self _applyHistoryEntry:entry undoingMove:^{
			if (back) [history goForward];
			else [history goBack];
		}];
	}
	[self _reloadDeferredSidebar];
	[self _updateHistoryControl];
}

/// Selects the entry's schema, table (none if it had none) and pane (an unknown one: Content), without recording that as a new entry.
- (void)_applyHistoryEntry:(NSDictionary *)entry
{
	[self _applyHistoryEntry:entry undoingMove:nil];
}

/**
 * The same; undoMove (may be nil) puts History back where it was when the entry's schema couldn't be shown (its
 * reload cancelled or failed): the tab stays where it is, and the entry can be gone to again.
 */
- (void)_applyHistoryEntry:(NSDictionary *)entry undoingMove:(void (^)(void))undoMove
{
	NSString *schema = [entry objectForKey:@"schema"];
	if ([schema length] && ![schema isEqualToString:[sidebar selectedSchema]]) {
		// The entry's schema first (its empty selection on the way not recorded), then its table and pane
		NSDictionary *theEntry = [[entry copy] autorelease];
		NSString *theSchema = [[schema copy] autorelease];
		void (^undo)(void) = [[undoMove copy] autorelease];
		[sidebar reloadSchema:schema completion:[self _quietSidebarCompletion:^(BOOL loaded) {
			if (!loaded && undo && ![theSchema isEqualToString:[sidebar selectedSchema]]) {
				undo();
				[self _updateHistoryControl];
				return;
			}
			[self _selectHistoryEntry:theEntry];
		}]];
		return;
	}
	[self _selectHistoryEntry:entry];
}

/// The entry's table (in the schema shown) and pane, without recording that as a new entry.
- (void)_selectHistoryEntry:(NSDictionary *)entry
{
	BOOL wasRestoring = restoringHistory;
	restoringHistory = YES;

	NSString *schema = [entry objectForKey:@"schema"];

	// A table, view or sequence of the entry's schema only (a schema that can't be loaded any more leaves nothing
	// selected); a Sequence pane entry is a sequence's
	NSString *table = [entry objectForKey:@"table"];
	BOOL sameSchema = ![schema length] || [schema isEqualToString:[sidebar selectedSchema]];
	BOOL isSequence = [[entry objectForKey:@"pane"] isEqualToString:SPPostgresPaneSequence];
	BOOL selected = NO;
	if ([table length] && sameSchema) {
		selected = isSequence ? [sidebar selectSequenceNamed:table] : ([sidebar selectTableNamed:table] || [sidebar selectSequenceNamed:table]);
	}
	if (!selected) [sidebar selectTableNamed:nil];

	[self showPane:[entry objectForKey:@"pane"]];

	restoringHistory = wasRestoring;
}

/// A history move waiting for a database switch is given up: the history goes back to where it was.
- (void)_abandonHistoryRestore
{
	if (!pendingHistoryEntry) return;
	[pendingHistoryEntry release];
	pendingHistoryEntry = nil;
	if (pendingHistoryWentBack) [history goForward];
	else [history goBack];
	[self _updateHistoryControl];
}

#pragma mark - Duplicate Table

/// A sheet as MySQL's Duplicate Table sheet (DBView.xib): the new name (<table>_copy), "Duplicate table content", Cancel/Duplicate.
- (void)_showDuplicateTableSheetForTable:(NSString *)table
{
	if (tornDown || duplicateSheet || ![table length] || !parentWindow || isProcessing) return;

	// An edit in progress (and a Structure draft column) is ended (saved) first, as MySQL's
	if (![self _endPaneEditing] || ![parentWindow makeFirstResponder:nil]) return;

	NSString *schema = [[[sidebar selectedSchema] copy] autorelease];
	if (![schema length]) return;

	NSRect frame = NSMakeRect(0, 0, 260, 127);
	duplicateSheet = [[NSWindow alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:YES];
	[duplicateSheet setReleasedWhenClosed:NO];
	[duplicateSheet setTitle:NSLocalizedString(@"Duplicate Table", @"PostgreSQL duplicate table sheet title")];
	[duplicateSheet setContentMinSize:NSMakeSize(260, 127)];
	[duplicateSheet setContentMaxSize:NSMakeSize(600, 127)];
	NSView *content = [duplicateSheet contentView];
	NSFont *smallFont = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];

	NSTextField *message = [NSTextField labelWithString:[NSString stringWithFormat:NSLocalizedString(@"Duplicate %@ '%@' to:", @"duplicate object message"), NSLocalizedString(@"table", @"table"), table]];
	[message setFrame:NSMakeRect(17, 93, 226, 14)];
	[message setFont:smallFont];
	[message setLineBreakMode:NSLineBreakByTruncatingMiddle];
	[message setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
	[content addSubview:message];

	duplicateNameField = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 66, 222, 19)];
	[duplicateNameField setIdentifier:@"duplicateTableName"];
	[[duplicateNameField cell] setControlSize:NSControlSizeSmall];
	[duplicateNameField setFont:smallFont];
	[[duplicateNameField cell] setUsesSingleLineMode:YES];
	[[duplicateNameField cell] setScrollable:YES];
	[duplicateNameField setStringValue:[table stringByAppendingString:@"_copy"]];
	[duplicateNameField setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
	[duplicateNameField setDelegate:(id<NSTextFieldDelegate>)self];
	[content addSubview:duplicateNameField];

	duplicateContentSwitch = [[NSButton checkboxWithTitle:NSLocalizedString(@"Duplicate table content", @"PostgreSQL duplicate table sheet: copy content checkbox") target:nil action:NULL] retain];
	[duplicateContentSwitch setIdentifier:@"duplicateTableContent"];
	[duplicateContentSwitch setFrame:NSMakeRect(17, 43, 227, 18)];
	[duplicateContentSwitch setControlSize:NSControlSizeSmall];
	[duplicateContentSwitch setFont:smallFont];
	// MySQL's preference for this checkbox (read only: the sheet doesn't change it)
	[duplicateContentSwitch setState:[[NSUserDefaults standardUserDefaults] boolForKey:SPCopyContentOnTableCopy] ? NSControlStateValueOn : NSControlStateValueOff];
	[duplicateContentSwitch setAutoresizingMask:NSViewMaxXMargin | NSViewMaxYMargin];
	[content addSubview:duplicateContentSwitch];

	NSButton *cancel = [NSButton buttonWithTitle:NSLocalizedString(@"Cancel", @"cancel button") target:self action:@selector(closeDuplicateTableSheet:)];
	[cancel setFrame:NSMakeRect(61, 13, 91, 28)];
	[cancel setControlSize:NSControlSizeSmall];
	[cancel setFont:smallFont];
	[cancel setTag:NSModalResponseCancel];
	[cancel setKeyEquivalent:@"\e"];
	[cancel setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
	[content addSubview:cancel];

	duplicateButton = [[NSButton buttonWithTitle:NSLocalizedString(@"Duplicate", @"PostgreSQL duplicate table sheet: duplicate button") target:self action:@selector(closeDuplicateTableSheet:)] retain];
	[duplicateButton setIdentifier:@"duplicateTableButton"];
	[duplicateButton setFrame:NSMakeRect(150, 13, 97, 28)];
	[duplicateButton setControlSize:NSControlSizeSmall];
	[duplicateButton setFont:smallFont];
	[duplicateButton setTag:NSModalResponseOK];
	[duplicateButton setKeyEquivalent:@"\r"];
	[duplicateButton setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
	[content addSubview:duplicateButton];

	[duplicateSheet setInitialFirstResponder:duplicateNameField];
	[self _validateNameSheets];

	[parentWindow beginSheet:duplicateSheet completionHandler:^(NSModalResponse returnCode) {
		NSString *newName = [[[duplicateNameField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
		BOOL withContent = ([duplicateContentSwitch state] == NSControlStateValueOn);

		[duplicateNameField setDelegate:nil];
		[duplicateSheet orderOut:nil];
		[duplicateSheet release], duplicateSheet = nil;
		[duplicateNameField release], duplicateNameField = nil;
		[duplicateContentSwitch release], duplicateContentSwitch = nil;
		[duplicateButton release], duplicateButton = nil;

		if (returnCode == NSModalResponseOK && !tornDown && [newName length]) {
			[self _duplicateTable:table inSchema:schema toName:newName withContent:withContent];
		}
		[newName release];
	}];
}

/// The sheet's name, trimmed.
- (NSString *)_duplicateTableName
{
	return [[duplicateNameField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

/// Duplicate (and Rename) is enabled while the name is one PostgreSQL keeps as given (not empty, at most 63 bytes).
- (void)controlTextDidChange:(NSNotification *)notification
{
	[self _validateNameSheets];
}

- (void)_validateNameSheets
{
	// Add also waits for the tab to be idle: it writes as soon as it is clicked
	if (addTableSheet) [addTableButton setEnabled:!isProcessing && [SPPostgresTableDuplicator isValidTableName:[self _addTableName]]];
	if (duplicateSheet) [duplicateButton setEnabled:[SPPostgresTableDuplicator isValidTableName:[self _duplicateTableName]]];
	if (renameSheet) {
		NSString *name = [self _renameTableName];
		[renameButton setEnabled:[SPPostgresTableDuplicator isValidTableName:name] && ![name isEqualToString:renameOriginalName]];
	}
}

- (void)closeDuplicateTableSheet:(id)sender
{
	if (!duplicateSheet) return;
	if ([sender tag] == NSModalResponseOK && ![SPPostgresTableDuplicator isValidTableName:[self _duplicateTableName]]) {
		NSBeep();
		return;
	}
	[parentWindow endSheet:duplicateSheet returnCode:[sender tag]];
}

/// Duplicates the table; on success lists and selects the copy, else shows the server's message.
- (void)_duplicateTable:(NSString *)table inSchema:(NSString *)schema toName:(NSString *)newName withContent:(BOOL)withContent
{
	if ([self _refuseWriteWhileBusy]) return;
	NSError *error = nil;
	if (![SPPostgresTableDuplicator duplicateTable:table inSchema:schema toName:newName withContent:withContent connection:connection error:&error]) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setAlertStyle:NSAlertStyleWarning];
		[alert setMessageText:NSLocalizedString(@"Error", @"error")];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Couldn't duplicate '%@'.\nPostgreSQL said: %@", @"PostgreSQL duplicate table failed"), table, [error localizedDescription] ?: @""]];
		[self _presentAlert:alert];
		return;
	}

	// The copy is in the schema the sidebar shows (the sheet was modal)
	if (![schema isEqualToString:[sidebar selectedSchema]]) return;

	// The reload's empty selection on the way is not a place the user went to (history); the copy, selected once listed, is
	NSString *copyName = [[newName copy] autorelease];
	[sidebar reloadSchema:schema completion:[self _quietSidebarCompletion:^(BOOL loaded) {
		[sidebar selectTableNamed:copyName];
	}]];
}

#pragma mark - Rename Table

/// A sheet as the Duplicate Table one (and MySQL's Rename Table sheet): the new name, Cancel/Rename.
- (void)_showRenameTableSheetForTable:(NSString *)table
{
	if (tornDown || renameSheet || duplicateSheet || ![table length] || !parentWindow || isProcessing) return;

	// An edit in progress (and a Structure draft column) is ended (saved) first
	if (![self _endPaneEditing] || ![parentWindow makeFirstResponder:nil]) return;

	NSString *schema = [[[sidebar selectedSchema] copy] autorelease];
	if (![schema length]) return;

	NSRect frame = NSMakeRect(0, 0, 260, 106);
	renameSheet = [[NSWindow alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:YES];
	[renameSheet setReleasedWhenClosed:NO];
	[renameSheet setTitle:NSLocalizedString(@"Rename Table", @"PostgreSQL rename table sheet title")];
	[renameSheet setContentMinSize:NSMakeSize(260, 106)];
	[renameSheet setContentMaxSize:NSMakeSize(600, 106)];
	NSView *content = [renameSheet contentView];
	NSFont *smallFont = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];

	NSTextField *message = [NSTextField labelWithString:[NSString stringWithFormat:NSLocalizedString(@"Rename table '%@' to:", @"PostgreSQL rename table sheet message"), table]];
	[message setFrame:NSMakeRect(17, 72, 226, 14)];
	[message setFont:smallFont];
	[message setLineBreakMode:NSLineBreakByTruncatingMiddle];
	[message setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
	[content addSubview:message];

	renameNameField = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 45, 222, 19)];
	[renameNameField setIdentifier:@"renameTableName"];
	[[renameNameField cell] setControlSize:NSControlSizeSmall];
	[renameNameField setFont:smallFont];
	[[renameNameField cell] setUsesSingleLineMode:YES];
	[[renameNameField cell] setScrollable:YES];
	[renameNameField setStringValue:table];
	[renameNameField setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
	[renameNameField setDelegate:(id<NSTextFieldDelegate>)self];
	[content addSubview:renameNameField];

	NSButton *cancel = [NSButton buttonWithTitle:NSLocalizedString(@"Cancel", @"cancel button") target:self action:@selector(closeRenameTableSheet:)];
	[cancel setFrame:NSMakeRect(61, 10, 91, 28)];
	[cancel setControlSize:NSControlSizeSmall];
	[cancel setFont:smallFont];
	[cancel setTag:NSModalResponseCancel];
	[cancel setKeyEquivalent:@"\e"];
	[cancel setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
	[content addSubview:cancel];

	renameButton = [[NSButton buttonWithTitle:NSLocalizedString(@"Rename", @"PostgreSQL rename table sheet: rename button") target:self action:@selector(closeRenameTableSheet:)] retain];
	[renameButton setIdentifier:@"renameTableButton"];
	[renameButton setFrame:NSMakeRect(150, 10, 97, 28)];
	[renameButton setControlSize:NSControlSizeSmall];
	[renameButton setFont:smallFont];
	[renameButton setTag:NSModalResponseOK];
	[renameButton setKeyEquivalent:@"\r"];
	[renameButton setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
	[content addSubview:renameButton];

	[renameOriginalName release];
	renameOriginalName = [table copy];
	[renameSheet setInitialFirstResponder:renameNameField];
	[self _validateNameSheets];

	[parentWindow beginSheet:renameSheet completionHandler:^(NSModalResponse returnCode) {
		NSString *newName = [[[renameNameField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];

		[renameNameField setDelegate:nil];
		[renameSheet orderOut:nil];
		[renameSheet release], renameSheet = nil;
		[renameNameField release], renameNameField = nil;
		[renameButton release], renameButton = nil;
		[renameOriginalName release], renameOriginalName = nil;

		if (returnCode == NSModalResponseOK && !tornDown && [newName length] && ![newName isEqualToString:table]) {
			[self _renameTable:table inSchema:schema toName:newName];
		}
		[newName release];
	}];
}

/// The sheet's name, trimmed.
- (NSString *)_renameTableName
{
	return [[renameNameField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)closeRenameTableSheet:(id)sender
{
	if (!renameSheet) return;
	if ([sender tag] == NSModalResponseOK && ![renameButton isEnabled]) {
		NSBeep();
		return;
	}
	[parentWindow endSheet:renameSheet returnCode:[sender tag]];
}

/// Renames the table (ALTER TABLE … RENAME TO, as a structure change); on success the lists reload, keeping the selection on it.
- (void)_renameTable:(NSString *)table inSchema:(NSString *)schema toName:(NSString *)newName
{
	if ([self _refuseWriteWhileBusy]) return;
	SPPostgresTableStructure *tableStructure = [[[SPPostgresTableStructure alloc] initWithConnection:connection schema:schema table:table] autorelease];
	NSError *error = nil;
	if (![tableStructure renameTableTo:newName error:&error]) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setAlertStyle:NSAlertStyleWarning];
		[alert setMessageText:NSLocalizedString(@"Error", @"error")];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Couldn't rename '%@'.\nPostgreSQL said: %@", @"PostgreSQL rename table failed"), table, [error localizedDescription] ?: @""]];
		[self _presentAlert:alert];
		return;
	}

	// Its columns' table name changed: the Content and Structure views load it afresh
	contentNeedsReset = YES;
	structureNeedsReset = YES;

	// History's entries for it name it by its new name (going back to them finds it, and the new name's entry
	// isn't a place of its own)
	[history renameTable:table to:newName inDatabase:currentDatabase schema:schema];

	// The renamed table stays selected (another selection, including several tables and views, is kept); the reload on
	// the way is not a place the user went to
	if (![schema isEqualToString:[sidebar selectedSchema]]) return;
	NSMutableArray *reselect = [NSMutableArray array];
	for (NSString *selected in [sidebar selectedRelationNames]) {
		[reselect addObject:[selected isEqualToString:table] ? newName : selected];
	}
	NSString *selectedSequence = [[[sidebar selectedSequenceName] copy] autorelease];
	if (![reselect count] && selectedSequence) {
		// Straight back to the sequence (no empty selection, so no other pane, on the way), not recorded
		[sidebar reloadSchema:schema selectingSequence:selectedSequence completion:[self _quietSidebarCompletion:nil]];
		return;
	}
	[sidebar reloadSchema:schema completion:[self _quietSidebarCompletion:^(BOOL loaded) {
		if ([reselect count]) [sidebar selectRelationsNamed:reselect];
	}]];
}

#pragma mark - Add Schema

/**
 * The + after the schema pop-up: the shown pane's edits are saved, the server's roles and the connected user are read,
 * then a sheet asks for the name and the owner (the connected user selected). CREATE SCHEMA … AUTHORIZATION is sent,
 * and the table list then lists and shows the new schema. A server error (e.g. the schema exists) is shown.
 */
- (void)sidebarAddSchema:(SPPostgresSidebarController *)theSidebar
{
	if (tornDown || !parentWindow || isProcessing || [parentWindow attachedSheet]) return;
	if (![self _endPaneEditing]) return;
	NSString *database = [[currentDatabase copy] autorelease];
	[taskRunner runTaskWithDescription:NSLocalizedString(@"Loading...", @"PostgreSQL add schema: loading task") cancelTitle:nil work:^id(PGPostgresConnection *theConnection, NSError **error) {
		SPPostgresCatalog *reader = [[[SPPostgresCatalog alloc] initWithConnection:theConnection] autorelease];
		NSArray *roles = [reader roleNames:error];
		if (!roles) return nil;
		id user = [[[theConnection execute:@"SELECT current_user::text"] rowAsArray] firstObject];
		return @{@"roles": roles, @"user": [user isKindOfClass:[NSString class]] ? user : @""};
	} completion:^(id result, NSError *error, BOOL cancelled) {
		if (tornDown || cancelled) return;
		if (!result) {
			[self _alertTitle:NSLocalizedString(@"Could not read the server's roles", @"PostgreSQL add schema: roles read failed") error:error];
			return;
		}
		NSString *user = result[@"user"];
		[self _whenIdle:^{
			if (tornDown || !parentWindow || [parentWindow attachedSheet]) return;
			[SPPostgresSchemaSheet beginAddOnWindow:parentWindow database:database owner:user roles:result[@"roles"] completion:^(NSDictionary *values) {
				if (!values || tornDown) return;
				// The connected user owns a new schema anyway: AUTHORIZATION only for another owner
				NSString *owner = [values[@"owner"] isEqualToString:user] ? nil : values[@"owner"];
				[self _createSchema:values[@"name"] owner:owner];
			}];
		}];
	}];
}

- (void)_createSchema:(NSString *)name owner:(NSString *)owner
{
	if ([self _refuseWriteWhileBusy]) return;
	NSString *theName = [[name copy] autorelease];
	NSString *theOwner = [[owner copy] autorelease];
	[taskRunner runTaskWithDescription:NSLocalizedString(@"Adding schema...", @"PostgreSQL add schema task") cancelTitle:nil work:^id(PGPostgresConnection *theConnection, NSError **error) {
		SPPostgresCatalog *writer = [[[SPPostgresCatalog alloc] initWithConnection:theConnection] autorelease];
		return [writer createSchema:theName owner:theOwner error:error] ? @YES : nil;
	} completion:^(id result, NSError *error, BOOL cancelled) {
		if (tornDown || cancelled) return;
		if (!result) {
			[self _alertTitle:[NSString stringWithFormat:NSLocalizedString(@"Could not add the schema “%@”", @"PostgreSQL add schema failed"), theName] error:error];
			return;
		}
		// The schema list is read again (with the new schema), then the new schema is shown
		[self _whenIdle:^{
			[sidebar reloadKeepingSelection:^(BOOL loaded) {
				if (tornDown) return;
				[self _whenIdle:^{ [sidebar reloadSchema:theName]; }];
			}];
		}];
	}];
}

#pragma mark - Edit Schema

/**
 * The pencil before the +: the shown pane's edits are saved, the shown schema's owner and the server's roles are read,
 * then a sheet offers its owner. Save sends ALTER SCHEMA … OWNER TO; a server error is shown.
 */
- (void)sidebarEditSchema:(SPPostgresSidebarController *)theSidebar
{
	if (tornDown || !parentWindow || isProcessing || [parentWindow attachedSheet]) return;
	NSString *schema = [[[sidebar selectedSchema] copy] autorelease];
	if (![schema length]) return;
	if (![self _endPaneEditing]) return;
	[taskRunner runTaskWithDescription:NSLocalizedString(@"Loading...", @"PostgreSQL edit schema: loading task") cancelTitle:nil work:^id(PGPostgresConnection *theConnection, NSError **error) {
		SPPostgresCatalog *reader = [[[SPPostgresCatalog alloc] initWithConnection:theConnection] autorelease];
		NSString *owner = [reader ownerOfSchema:schema error:error];
		if (!owner) return nil;
		NSArray *roles = [reader roleNames:error];
		if (!roles) return nil;
		return @{@"owner": owner, @"roles": roles};
	} completion:^(id result, NSError *error, BOOL cancelled) {
		if (tornDown || cancelled) return;
		if (!result) {
			[self _alertTitle:[NSString stringWithFormat:NSLocalizedString(@"Could not read the schema “%@”", @"PostgreSQL edit schema: read failed"), schema] error:error];
			return;
		}
		[self _whenIdle:^{
			if (tornDown || !parentWindow || [parentWindow attachedSheet]) return;
			[SPPostgresSchemaSheet beginEditOnWindow:parentWindow schema:schema owner:result[@"owner"] roles:result[@"roles"] completion:^(NSDictionary *values) {
				if (values && !tornDown) [self _setOwner:values[@"owner"] ofSchema:schema];
			}];
		}];
	}];
}

- (void)_setOwner:(NSString *)owner ofSchema:(NSString *)schema
{
	if ([self _refuseWriteWhileBusy]) return;
	NSString *theOwner = [[owner copy] autorelease];
	NSString *theSchema = [[schema copy] autorelease];
	[taskRunner runTaskWithDescription:NSLocalizedString(@"Changing owner...", @"PostgreSQL edit schema task") cancelTitle:nil work:^id(PGPostgresConnection *theConnection, NSError **error) {
		SPPostgresCatalog *writer = [[[SPPostgresCatalog alloc] initWithConnection:theConnection] autorelease];
		return [writer setOwner:theOwner ofSchema:theSchema error:error] ? @YES : nil;
	} completion:^(id result, NSError *error, BOOL cancelled) {
		if (tornDown || cancelled || result) return;
		[self _alertTitle:[NSString stringWithFormat:NSLocalizedString(@"Could not change the owner of the schema “%@”", @"PostgreSQL edit schema failed"), theSchema] error:error];
	}];
}

#pragma mark - Add Table

/**
 * The bar's Add, as MySQL's: the shown pane's edits are saved, then (once the tab is idle: saving may have queued a
 * list reload) MySQL's New Table sheet asks for the name of a table to add to the selected schema.
 */
- (void)sidebarAddTable:(SPPostgresSidebarController *)theSidebar
{
	if (tornDown || addTableSheet || !parentWindow || isProcessing || [parentWindow attachedSheet]) return;

	NSString *schema = [[[sidebar selectedSchema] copy] autorelease];
	if (![schema length]) return;

	// An edit in progress (and a Structure draft column) is ended (saved) first, as MySQL's
	if (![self _endPaneEditing] || ![parentWindow makeFirstResponder:nil]) return;

	[self _presentWhenIdle:^{
		// Nothing changed under it meanwhile (the tab, a sheet, the schema); else dropped, with a beep
		if (tornDown || addTableSheet || !parentWindow || isProcessing || [parentWindow attachedSheet] || ![schema isEqualToString:[sidebar selectedSchema]]) {
			if (!tornDown) NSBeep();
			return;
		}
		[self _showAddTableSheetInSchema:schema];
	}];
}

/// A sheet as MySQL's New Table sheet (DBView.xib), with its name row only (PostgreSQL has no engine or table
/// charset): "Table Name:", then Cancel (Escape) and Add (Return, enabled for a name PostgreSQL keeps as given).
- (void)_showAddTableSheetInSchema:(NSString *)schema
{
	NSRect frame = NSMakeRect(0, 0, 425, 87);
	addTableSheet = [[NSWindow alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:YES];
	[addTableSheet setReleasedWhenClosed:NO];
	[addTableSheet setTitle:NSLocalizedString(@"New Table", @"PostgreSQL new table sheet title")];
	[addTableSheet setContentMinSize:NSMakeSize(425, 87)];
	[addTableSheet setContentMaxSize:NSMakeSize(600, 87)];
	NSView *content = [addTableSheet contentView];
	NSFont *smallFont = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];

	NSTextField *label = [NSTextField labelWithString:NSLocalizedString(@"Table Name:", @"PostgreSQL new table sheet: table name label")];
	[label setFrame:NSMakeRect(5, 50, 128, 14)];
	[label setFont:smallFont];
	[label setAlignment:NSTextAlignmentRight];
	[label setAutoresizingMask:NSViewMaxXMargin | NSViewMinYMargin];
	[content addSubview:label];

	addTableNameField = [[NSTextField alloc] initWithFrame:NSMakeRect(138, 49, 267, 18)];
	[addTableNameField setIdentifier:@"addTableName"];
	[[addTableNameField cell] setControlSize:NSControlSizeSmall];
	[addTableNameField setFont:smallFont];
	[[addTableNameField cell] setUsesSingleLineMode:YES];
	[[addTableNameField cell] setScrollable:YES];
	[addTableNameField setAutoresizingMask:NSViewWidthSizable | NSViewMinYMargin];
	[addTableNameField setDelegate:(id<NSTextFieldDelegate>)self];
	[content addSubview:addTableNameField];

	NSButton *cancel = [NSButton buttonWithTitle:NSLocalizedString(@"Cancel", @"cancel button") target:self action:@selector(closeAddTableSheet:)];
	[cancel setFrame:NSMakeRect(250, 13, 84, 28)];
	[cancel setControlSize:NSControlSizeSmall];
	[cancel setFont:smallFont];
	[cancel setTag:NSModalResponseCancel];
	[cancel setKeyEquivalent:@"\e"];
	[cancel setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
	[content addSubview:cancel];

	addTableButton = [[NSButton buttonWithTitle:NSLocalizedString(@"Add", @"PostgreSQL new table sheet: add button") target:self action:@selector(closeAddTableSheet:)] retain];
	[addTableButton setIdentifier:@"addTableButton"];
	[addTableButton setFrame:NSMakeRect(332, 13, 78, 28)];
	[addTableButton setControlSize:NSControlSizeSmall];
	[addTableButton setFont:smallFont];
	[addTableButton setTag:NSModalResponseOK];
	[addTableButton setKeyEquivalent:@"\r"];
	[addTableButton setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
	[content addSubview:addTableButton];

	[addTableSchema release];
	addTableSchema = [schema copy];
	[addTableSheet setInitialFirstResponder:addTableNameField];
	[self _validateNameSheets];

	[parentWindow beginSheet:addTableSheet completionHandler:^(NSModalResponse returnCode) {
		[addTableNameField setDelegate:nil];
		[addTableSheet orderOut:nil];
		[addTableSheet release], addTableSheet = nil;
		[addTableNameField release], addTableNameField = nil;
		[addTableButton release], addTableButton = nil;
		[addTableSchema release], addTableSchema = nil;
	}];
}

/// The sheet's name, trimmed.
- (NSString *)_addTableName
{
	return [[addTableNameField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

/**
 * Cancel ends the sheet. Add (or Return) runs only while it is enabled (a valid name, the tab idle); otherwise the
 * sheet stays up with the name, to try again. The table is created before the sheet ends, so nothing can start in
 * between; then, as MySQL's, it is listed, selected and shown in Structure, or the server's message is shown.
 */
- (void)closeAddTableSheet:(id)sender
{
	if (!addTableSheet) return;
	if ([sender tag] != NSModalResponseOK) {
		[parentWindow endSheet:addTableSheet returnCode:NSModalResponseCancel];
		return;
	}
	if (tornDown || ![addTableButton isEnabled]) {
		NSBeep();
		return;
	}
	if ([self _refuseWriteWhileBusy]) return;

	NSString *name = [[[self _addTableName] copy] autorelease];
	NSString *schema = [[addTableSchema copy] autorelease];
	NSError *error = nil;
	BOOL created = [SPPostgresTableActions createTableNamed:name inSchema:schema connection:connection error:&error];
	[parentWindow endSheet:addTableSheet returnCode:NSModalResponseOK];

	if (!created) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setAlertStyle:NSAlertStyleWarning];
		[alert setMessageText:NSLocalizedString(@"Error adding new table", @"error adding new table message")];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to add the new table '%@'.\n\nPostgreSQL said: %@", @"PostgreSQL error adding new table informative message"), name, [[self _messageLinesWithoutHint:error] componentsJoinedByString:@"\n"]]];
		[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK button")];
		[self _presentAlert:alert];
		return;
	}

	// The table is in the schema the sidebar shows (the sheet was modal). The reload's empty selection on the way is
	// not a place the user went to; selecting the new table is, and so is its Structure view (as MySQL's).
	if (![schema isEqualToString:[sidebar selectedSchema]]) return;
	[sidebar reloadSchema:schema completion:[self _quietSidebarCompletion:^(BOOL loaded) {
		if ([sidebar selectTableNamed:name]) [self showPane:SPPostgresPaneStructure];
	}]];
}

#pragma mark - Split view

- (void)splitViewDidResizeSubviews:(NSNotification *)notification
{
	[self _updateDatabaseToolbarItemWidth];
}

/// The database picker is as wide as the left panel, as in the MySQL window.
- (void)_updateDatabaseToolbarItemWidth
{
	if (!databaseToolbarItem || [[splitView subviews] count] < 1) return;

	CGFloat width = NSWidth([[[splitView subviews] objectAtIndex:0] frame]) - 9;
	width = MIN(MAX(width, 130), 360);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	[databaseToolbarItem setMinSize:NSMakeSize(width, 26)];
	[databaseToolbarItem setMaxSize:NSMakeSize(width, 32)];
#pragma clang diagnostic pop
}

// The left pane width is shared with MySQL tabs (same autosave name): constrained as theirs

- (CGFloat)splitView:(NSSplitView *)theSplitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	return (dividerIndex == 0 && proposedMinimumPosition < 40) ? 40 : proposedMinimumPosition;
}

- (CGFloat)splitView:(NSSplitView *)theSplitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	return (dividerIndex == 0) ? proposedMaximumPosition - 505 : proposedMaximumPosition;
}

#pragma mark - Menus

/**
 * Asked by the window controller for every item it would send to this tab, and for the window's own
 * items: those (tabs, New Tab, Close Tab) stay enabled, and so do this tab's own actions. Everything
 * else (the MySQL-only items) is disabled.
 */
/// View > Filter Tables (⌃⌥⌘F), as on MySQL tabs: the table list's filter field takes the keyboard.
- (IBAction)makeTableListFilterHaveFocus:(id)sender
{
	if (tornDown) return;
	[sidebar focusFilterField];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
	SEL action = [item action];

	// Show/hide console, worded as for MySQL tabs
	if (action == @selector(toggleConsole:)) {
		[item setTitle:([[[SPQueryController sharedQueryController] window] isVisible] && [[[NSApp keyWindow] windowController] isKindOfClass:[SPQueryController class]]) ? NSLocalizedString(@"Hide Console", @"hide console") : NSLocalizedString(@"Show Console", @"show console")];
	}

	if (!action || action == @selector(unavailableInThisVersion:)) return NO;

	if ([SPWindowController instancesRespondToSelector:action]) return YES;

	if (tornDown) return NO;

	// As the pane toolbar items
	if (action == @selector(viewStructure:)) return [self _canSwitchToPane:SPPostgresPaneStructure];
	if (action == @selector(viewContent:)) return [self _canSwitchToPane:SPPostgresPaneContent];
	if (action == @selector(viewRelations:)) return [self _canSwitchToPane:SPPostgresPaneRelations];
	if (action == @selector(viewTriggers:)) return [self _canSwitchToPane:SPPostgresPaneTriggers];
	if (action == @selector(viewStatus:)) return [self _canSwitchToPane:SPPostgresPaneInfo];
	if (action == @selector(viewQuery:)) return [self _canSwitchToPane:SPPostgresPaneQuery];

	if (action == @selector(showUserManager:)) return [self _canShowUsers];
	// The Database menu (Flush Privileges, View Using Encoding and Shutdown Server have no PostgreSQL equivalent: not
	// implemented, so disabled)
	if (action == @selector(refreshTables:) || action == @selector(setDatabases:)) return !isProcessing && [connection isConnected];
	if (action == @selector(showGotoDatabase:) || action == @selector(addDatabase:) || action == @selector(renameDatabase:)
		|| action == @selector(copyDatabase:) || action == @selector(removeDatabase:) || action == @selector(openDatabaseInNewTab:)
		|| action == @selector(alterDatabase:)
		|| action == @selector(showServerVariables:) || action == @selector(showServerProcesses:)) {
		return [self _canRunDatabaseAction];
	}
	if (action == @selector(export:) || action == @selector(exportQueryResult:)) return [self _canImportExport];
	if (action == @selector(import:)) return [self _canImportExport];
	if (action == @selector(showTransfer:)) return [self _canShowTransfer];
	if (action == @selector(showInstallExtensionSheet:)) return !isProcessing && SPPostgresFeatureIsAvailable(SPPostgresFeatureExtensions);
	// View > Filter Tables: the table list's filter field (MySQL tabs word it so with more than 20 tables)
	if (action == @selector(makeTableListFilterHaveFocus:)) {
		[item setTitle:NSLocalizedString(@"Filter Tables", @"filter tables menu item")];
		return [[sidebar filterField] window] != nil;
	}

	// View > Back/Forward In History (tags 0 and 1), as MySQL's
	if (action == @selector(backForwardInHistory:)) {
		if (isProcessing || !SPPostgresFeatureIsAvailable(SPPostgresFeatureTableHistory)) return NO;
		return ([item tag] == 0) ? [history canGoBack] : [history canGoForward];
	}

	return [self respondsToSelector:action];
}

#pragma mark - Toolbar

/**
 * The same identifiers as the MySQL document's toolbar (SPMainToolbar.m): both use the toolbar
 * identifier TableWindowToolbar and share its saved layout, and toolbars with one identifier sync
 * their items, so this tab must serve every item a MySQL tab can show.
 */
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)theToolbar
{
	return SPMainToolbarAllowedItemIdentifiers();
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)theToolbar
{
	return SPMainToolbarDefaultItemIdentifiers();
}

/// As MySQL's: these items are drawn without a button bezel (and are a few points taller)
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)theToolbar
{
	return SPMainToolbarSelectableItemIdentifiers();
}

/// The database picker, Table History, the console and the pane items work on Postgres tabs so far
- (NSArray *)_availableToolbarItemIdentifiers
{
	return @[SPMainToolbarDatabaseSelection, SPMainToolbarHistoryNavigation, SPMainToolbarShowConsole, SPMainToolbarTableStructure,
			 SPMainToolbarTableContent, SPMainToolbarTableRelations, SPMainToolbarTableTriggers, SPMainToolbarTableInfo, SPMainToolbarCustomQuery,
			 SPMainToolbarUserManager, SPMainToolbarTransfer];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)theToolbar itemForItemIdentifier:(NSString *)identifier willBeInsertedIntoToolbar:(BOOL)flag
{
	// Transfer: a plain item that looks exactly like MySQL's (label, tooltip, image, no bezel, size), so switching tabs
	// moves nothing. AppKit would border an image item with an action, making it wider
	if ([identifier isEqualToString:SPMainToolbarTransfer]) {
		NSToolbarItem *transfer = [[[NSToolbarItem alloc] initWithItemIdentifier:identifier] autorelease];
		SPConfigureTransferToolbarItem(transfer);
		[transfer setImage:SPCompactToolbarImage([transfer image])];
		[transfer setBordered:NO];
		// An item with an action gets a larger frame than MySQL's actionless one even without a bezel (32 instead of
		// 28 points): give it MySQL's (SPToolbarParityTests compare the installed sizes)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		[transfer setMinSize:NSMakeSize(28, 28)];
		[transfer setMaxSize:NSMakeSize(28, 28)];
#pragma clang diagnostic pop
		[transfer setTarget:self];
		[transfer setAction:@selector(showTransfer:)];
		return transfer;
	}

	// The items MySQL tabs show (SPMainToolbar.m): same images, labels, sizes and item kinds
	NSToolbarItem *item = SPCreateMainToolbarItem(identifier);
	if (!item) return nil;

	// The items of features Postgres tabs don't have yet keep an action (as MySQL's do, which is what
	// sizes them), validated off
	SEL action = @selector(unavailableInThisVersion:);

	if ([identifier isEqualToString:SPMainToolbarDatabaseSelection]) {
		[item setView:databasePopup];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		// As MySQL's picker: an explicit width that follows the left panel (see -_updateDatabaseToolbarItemWidth)
		[item setMinSize:NSMakeSize(200, 26)];
		[item setMaxSize:NSMakeSize(200, 32)];
#pragma clang diagnostic pop
		if (flag) {
			databaseToolbarItem = item;
			[self _updateDatabaseToolbarItemWidth];
		}
		action = NULL;
	}
	else if ([identifier isEqualToString:SPMainToolbarHistoryNavigation]) {
		[historyControl sizeToFit];
		[item setView:historyControl];
		action = NULL;
	}
	else if ([identifier isEqualToString:SPMainToolbarShowConsole]) {
		[item setToolTip:NSLocalizedString(@"Show the console which shows all PostgreSQL commands performed by Sequel Pro", @"PostgreSQL toolbar: console tooltip")];
		action = @selector(toggleConsole:);
	}
	else if ([identifier isEqualToString:SPMainToolbarTableStructure]) {
		action = @selector(viewStructure:);
	}
	else if ([identifier isEqualToString:SPMainToolbarTableContent]) {
		action = @selector(viewContent:);
	}
	else if ([identifier isEqualToString:SPMainToolbarTableRelations]) {
		action = @selector(viewRelations:);
	}
	else if ([identifier isEqualToString:SPMainToolbarTableTriggers]) {
		action = @selector(viewTriggers:);
	}
	else if ([identifier isEqualToString:SPMainToolbarTableInfo]) {
		action = @selector(viewStatus:);
	}
	else if ([identifier isEqualToString:SPMainToolbarCustomQuery]) {
		action = @selector(viewQuery:);
	}
	else if ([identifier isEqualToString:SPMainToolbarUserManager]) {
		action = @selector(showUserManager:);
	}
	else if ([identifier isEqualToString:SPMainToolbarClearConsole]) {
		[item setToolTip:NSLocalizedString(@"Clear the console which shows all PostgreSQL commands performed by Sequel Pro", @"PostgreSQL toolbar: clear console tooltip")];
	}

	if (action) {
		[item setTarget:self];
		[item setAction:action];
	}

	return item;
}

- (void)toolbarDidRemoveItem:(NSNotification *)notification
{
	if ([[notification userInfo] objectForKey:@"item"] == databaseToolbarItem) databaseToolbarItem = nil;
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)item
{
	NSString *identifier = [item itemIdentifier];

	if (![[self _availableToolbarItemIdentifiers] containsObject:identifier]) return NO;

	if ([identifier isEqualToString:SPMainToolbarShowConsole]) {
		NSWindow *consoleWindow = [[SPQueryController sharedQueryController] window];
		[item setImage:SPCompactToolbarImage([NSImage imageNamed:[consoleWindow isVisible] ? @"showconsole" : @"hideconsole"])];
		return ![consoleWindow isKeyWindow];
	}

	if ([identifier isEqualToString:SPMainToolbarUserManager]) return [self _canShowUsers];
	if ([identifier isEqualToString:SPMainToolbarTransfer]) return [self _canShowTransfer];
	// The control's segments follow -_updateHistoryControl; the item itself is off while the scope holds History back
	if ([identifier isEqualToString:SPMainToolbarHistoryNavigation]) return !tornDown && SPPostgresFeatureIsAvailable(SPPostgresFeatureTableHistory);

	// The pane items: see -_canSwitchToPane:
	NSString *pane = [self _paneForToolbarIdentifier:identifier];
	if (pane) return [self _canSwitchToPane:pane];

	return !tornDown;
}

/// Shows a pane its item allows (see -_canSwitchToPane:), and gives its main view the keyboard focus.
- (void)_viewPane:(NSString *)pane
{
	if (![self _canShowPane:pane]) return;
	if (isProcessing) {
		NSBeep();
		return;
	}
	[self showPane:pane];
	if (![currentPane isEqualToString:pane]) return;

	NSView *focus = nil;
	if ([pane isEqualToString:SPPostgresPaneContent]) {
		[self _showSelectedTable];
		focus = [contentController tableView];
	}
	else if ([pane isEqualToString:SPPostgresPaneStructure]) focus = [structureController columnsView];
	else if ([pane isEqualToString:SPPostgresPaneRelations]) focus = [relationsController relationsView];
	else if ([pane isEqualToString:SPPostgresPaneTriggers]) focus = [triggersController triggersView];
	else if ([pane isEqualToString:SPPostgresPaneQuery]) focus = [queryController editor];
	if (focus) [[focus window] makeFirstResponder:focus];
}

/// Shows the Structure view of the selected table or view.
- (IBAction)viewStructure:(id)sender
{
	[self _viewPane:SPPostgresPaneStructure];
}

/// Shows the Content view of the selected table.
- (IBAction)viewContent:(id)sender
{
	[self _viewPane:SPPostgresPaneContent];
}

/// Shows the Relations pane of the selected table.
- (IBAction)viewRelations:(id)sender
{
	[self _viewPane:SPPostgresPaneRelations];
}

/// Shows the Triggers pane of the selected table.
- (IBAction)viewTriggers:(id)sender
{
	[self _viewPane:SPPostgresPaneTriggers];
}

/// Shows the Table Info pane of the selected table or view (MySQL's View > Table Info).
- (IBAction)viewStatus:(id)sender
{
	[self _viewPane:SPPostgresPaneInfo];
}

/// Shows the Query view, the editor focused.
- (IBAction)viewQuery:(id)sender
{
	[self _viewPane:SPPostgresPaneQuery];
}

#pragma mark - Database menu

/// The databases the pop-up lists (after "Choose Database...", Add Database... and Refresh Databases).
- (NSArray<NSString *> *)_listedDatabaseNames
{
	NSMutableArray *names = [NSMutableArray array];
	NSArray *items = [databasePopup itemArray];
	for (NSInteger i = [self _firstDatabaseIndexInPopup]; i < (NSInteger)[items count]; i++) [names addObject:[[items objectAtIndex:(NSUInteger)i] title]];
	return names;
}

/// A Database menu action can start: connected to a database, not processing, no sheet up, no switch being confirmed.
- (BOOL)_canRunDatabaseAction
{
	return !tornDown && !isProcessing && !confirmingSwitch && [connection isConnected] && [currentDatabase length] && parentWindow && ![parentWindow attachedSheet];
}

/// Shows an alert titled title with error's message.
- (void)_alertTitle:(NSString *)title error:(NSError *)error
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setAlertStyle:NSAlertStyleWarning];
	[alert setMessageText:title];
	[alert setInformativeText:[error localizedDescription] ?: @""];
	[self _presentAlert:alert];
}

/**
 * Switches the tab to database as the pop-up does (an edit is saved first; an open transaction is confirmed), then
 * calls then (on a later run loop turn, once the tab is idle) with whether the tab is now on it; YES at once when it
 * is already.
 */
- (void)_switchToDatabase:(NSString *)database then:(void (^)(BOOL switched))then
{
	void (^done)(BOOL) = [[then copy] autorelease];
	if ([database isEqualToString:currentDatabase] && !pendingConnector) {
		[self _whenIdle:^{ done(YES); }];
		return;
	}
	if (tornDown || isProcessing || confirmingSwitch || ![database length] || ![self _endPaneEditing]) {
		done(NO);
		return;
	}
	[self _confirmLeavingSession:^(BOOL proceed) {
		if (!proceed || tornDown) {
			[self _selectCurrentDatabaseInPopup];
			done(NO);
			return;
		}
		[self _switchToDatabase:database forHistory:NO];
		if (!pendingConnector) {
			done([database isEqualToString:currentDatabase]);
			return;
		}
		[pendingSwitchCompletion release];
		pendingSwitchCompletion = [done copy];
	}];
}

/// Database ▸ Refresh Tables (⌘R): the table list, as its Refresh button.
- (IBAction)refreshTables:(id)sender
{
	if (tornDown || isProcessing) return;
	[self sidebarRefresh:sidebar];
}

/// Database ▸ Refresh Databases (⇧⌘R): the database pop-up.
- (IBAction)setDatabases:(id)sender
{
	if (tornDown || isProcessing) return;
	[self refreshDatabases:sender];
}

/// Database ▸ Go to Database… (⇧⌘D): MySQL's dialog on the listed databases; the chosen one is switched to.
- (IBAction)showGotoDatabase:(id)sender
{
	if (![self _canRunDatabaseAction]) return;
	SPGotoDatabaseController *controller = [[[SPGotoDatabaseController alloc] init] autorelease];
	[controller setDatabaseList:[[[self _listedDatabaseNames] mutableCopy] autorelease]];
	if (![controller runModal]) return;
	NSString *database = [controller selectedDatabase];
	if ([database length] && ![database isEqualToString:currentDatabase]) [self switchToDatabase:database];
}

/// Database ▸ Add Database…: asks for the name, sends CREATE DATABASE, then switches to the new database.
- (IBAction)addDatabase:(id)sender
{
	// Chosen in the pop-up: it shows the tab's database again
	[self _selectCurrentDatabaseInPopup];
	if (![self _canRunDatabaseAction] || ![self _endPaneEditing]) return;
	[SPPostgresNameSheet beginOnWindow:parentWindow
								 title:NSLocalizedString(@"Add Database", @"PostgreSQL add database sheet title")
							   message:NSLocalizedString(@"Enter the name of the new database:", @"PostgreSQL add database sheet message")
						   initialName:@""
						   buttonTitle:NSLocalizedString(@"Add", @"add button")
						  requiredText:nil
							completion:^(NSString *name) {
		if (name && !tornDown) [self _createDatabase:name];
	}];
}

- (void)_createDatabase:(NSString *)name
{
	if ([self _refuseWriteWhileBusy]) return;
	NSString *theName = [[name copy] autorelease];
	[taskRunner runTaskWithDescription:NSLocalizedString(@"Adding database...", @"PostgreSQL add database task") cancelTitle:nil work:^id(PGPostgresConnection *theConnection, NSError **error) {
		SPPostgresCatalog *writer = [[[SPPostgresCatalog alloc] initWithConnection:theConnection] autorelease];
		return [writer createDatabase:theName error:error] ? @YES : nil;
	} completion:^(id result, NSError *error, BOOL cancelled) {
		if (tornDown || cancelled) return;
		if (!result) {
			[self _alertTitle:[NSString stringWithFormat:NSLocalizedString(@"Could not add the database “%@”", @"PostgreSQL add database failed"), theName] error:error];
			return;
		}
		// The switch reloads the pop-up (with the new database) once the tab is idle
		[self _whenIdle:^{ [self _switchToDatabase:theName then:^(BOOL switched) { if (!switched) [self _reloadDatabasePopup]; }]; }];
	}];
}

/// A database the tab can be on while `database` is renamed, copied or dropped (the server refuses while a session is
/// connected to it): postgres, else the first other listed one; nil when there is none.
- (NSString *)_databaseAwayFrom:(NSString *)database
{
	NSArray *names = [self _listedDatabaseNames];
	if (![database isEqualToString:@"postgres"] && [names containsObject:@"postgres"]) return @"postgres";
	for (NSString *name in names) {
		if (![name isEqualToString:database]) return name;
	}
	return nil;
}

/**
 * Runs change (on the tab's runner, with a catalog on the tab's connection) with the tab on another database than
 * `database` (the server refuses to rename, copy or drop a database a session is connected to). Then the tab goes to
 * openOnSuccess (nil: it stays where it is) or, when the change failed, back to `database`, after the server's message.
 */
- (void)_changeDatabase:(NSString *)database description:(NSString *)description failureTitle:(NSString *)failureTitle change:(BOOL (^)(SPPostgresCatalog *writer, NSError **error))change openOnSuccess:(NSString *)openOnSuccess
{
	NSString *away = [self _databaseAwayFrom:database];
	if (!away) {
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setAlertStyle:NSAlertStyleWarning];
		[alert setMessageText:failureTitle];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"PostgreSQL can't change “%@” while this window is connected to it, and there is no other database to connect to meanwhile.", @"PostgreSQL database change: no other database"), database]];
		[self _presentAlert:alert];
		return;
	}

	BOOL (^theChange)(SPPostgresCatalog *, NSError **) = [[change copy] autorelease];
	NSString *theDatabase = [[database copy] autorelease];
	NSString *theTarget = [[openOnSuccess copy] autorelease];
	NSString *theDescription = [[description copy] autorelease];
	NSString *theTitle = [[failureTitle copy] autorelease];
	[self _switchToDatabase:away then:^(BOOL switched) {
		if (!switched || tornDown) return;
		[taskRunner runTaskWithDescription:theDescription cancelTitle:nil work:^id(PGPostgresConnection *theConnection, NSError **error) {
			SPPostgresCatalog *writer = [[[SPPostgresCatalog alloc] initWithConnection:theConnection] autorelease];
			return theChange(writer, error) ? @YES : nil;
		} completion:^(id result, NSError *error, BOOL cancelled) {
			if (tornDown) return;
			NSString *next = result ? theTarget : theDatabase;
			if (!result && !cancelled) [self _alertTitle:theTitle error:error];
			[self _whenIdle:^{
				if (next) [self _switchToDatabase:next then:^(BOOL done) { if (!done) [self _reloadDatabasePopup]; }];
				else [self _reloadDatabasePopup];
			}];
		}];
	}];
}

/// Database ▸ Rename Database…: the tab's database, renamed (ALTER DATABASE … RENAME TO) from another database.
- (IBAction)renameDatabase:(id)sender
{
	if (![self _canRunDatabaseAction] || ![self _endPaneEditing]) return;
	NSString *database = [[currentDatabase copy] autorelease];
	[SPPostgresNameSheet beginOnWindow:parentWindow
								 title:NSLocalizedString(@"Rename Database", @"PostgreSQL rename database sheet title")
							   message:[NSString stringWithFormat:NSLocalizedString(@"Rename database “%@” to:\n\nThis window connects to another database while it is renamed. PostgreSQL refuses while other sessions are connected to it.", @"PostgreSQL rename database sheet message"), database]
						   initialName:database
						   buttonTitle:NSLocalizedString(@"Rename", @"rename button")
						  requiredText:nil
							completion:^(NSString *name) {
		if (!name || tornDown) return;
		[self _changeDatabase:database
				  description:NSLocalizedString(@"Renaming database...", @"PostgreSQL rename database task")
				 failureTitle:[NSString stringWithFormat:NSLocalizedString(@"Could not rename the database “%@”", @"PostgreSQL rename database failed"), database]
					   change:^BOOL(SPPostgresCatalog *writer, NSError **error) { return [writer renameDatabase:database toName:name error:error]; }
				openOnSuccess:name];
	}];
}

/// Database ▸ Duplicate Database…: a copy of the tab's database (CREATE DATABASE … TEMPLATE), made from another database.
- (IBAction)copyDatabase:(id)sender
{
	if (![self _canRunDatabaseAction] || ![self _endPaneEditing]) return;
	NSString *database = [[currentDatabase copy] autorelease];
	[SPPostgresNameSheet beginOnWindow:parentWindow
								 title:NSLocalizedString(@"Duplicate Database", @"PostgreSQL duplicate database sheet title")
							   message:[NSString stringWithFormat:NSLocalizedString(@"Duplicate database “%@” to:\n\nThis window connects to another database while it is copied. PostgreSQL refuses while other sessions are connected to it.", @"PostgreSQL duplicate database sheet message"), database]
						   initialName:[database stringByAppendingString:@"_copy"]
						   buttonTitle:NSLocalizedString(@"Duplicate", @"duplicate button")
						  requiredText:nil
							completion:^(NSString *name) {
		if (!name || tornDown) return;
		[self _changeDatabase:database
				  description:NSLocalizedString(@"Duplicating database...", @"PostgreSQL duplicate database task")
				 failureTitle:[NSString stringWithFormat:NSLocalizedString(@"Could not duplicate the database “%@”", @"PostgreSQL duplicate database failed"), database]
					   change:^BOOL(SPPostgresCatalog *writer, NSError **error) { return [writer copyDatabase:database toName:name error:error]; }
				openOnSuccess:name];
	}];
}

/// Database ▸ Delete Database…: the tab's database, dropped (DROP DATABASE) from another database once its name is typed.
- (IBAction)removeDatabase:(id)sender
{
	if (![self _canRunDatabaseAction] || ![self _endPaneEditing]) return;
	NSString *database = [[currentDatabase copy] autorelease];
	[SPPostgresNameSheet beginOnWindow:parentWindow
								 title:NSLocalizedString(@"Delete Database", @"PostgreSQL delete database sheet title")
							   message:[NSString stringWithFormat:NSLocalizedString(@"Delete database “%@”? Everything in it is permanently deleted. This can't be undone.\n\nType the database's name to confirm:", @"PostgreSQL delete database sheet message"), database]
						   initialName:@""
						   buttonTitle:NSLocalizedString(@"Delete", @"delete button")
						  requiredText:database
							completion:^(NSString *name) {
		if (![name isEqualToString:database] || tornDown) return;
		[self _changeDatabase:database
				  description:NSLocalizedString(@"Deleting database...", @"PostgreSQL delete database task")
				 failureTitle:[NSString stringWithFormat:NSLocalizedString(@"Could not delete the database “%@”", @"PostgreSQL delete database failed"), database]
					   change:^BOOL(SPPostgresCatalog *writer, NSError **error) { return [writer dropDatabase:database error:error]; }
				openOnSuccess:nil];
	}];
}

/**
 * Database ▸ Alter Database…: the tab's database's name, owner and comment (read on the tab's runner, with the server's
 * roles). Owner and comment are changed on this connection (ALTER DATABASE … OWNER TO, COMMENT ON DATABASE); a new
 * name then goes through Rename Database's flow (from another database). The first failure is shown and stops the rest.
 */
- (IBAction)alterDatabase:(id)sender
{
	if (![self _canRunDatabaseAction] || ![self _endPaneEditing]) return;
	NSString *database = [[currentDatabase copy] autorelease];
	[taskRunner runTaskWithDescription:NSLocalizedString(@"Loading...", @"PostgreSQL alter database: loading task") cancelTitle:nil work:^id(PGPostgresConnection *theConnection, NSError **error) {
		SPPostgresCatalog *reader = [[[SPPostgresCatalog alloc] initWithConnection:theConnection] autorelease];
		NSDictionary *details = [reader databaseDetails:database error:error];
		if (!details) return nil;
		NSArray *roles = [reader roleNames:error];
		if (!roles) return nil;
		return @{@"details": details, @"roles": roles};
	} completion:^(id result, NSError *error, BOOL cancelled) {
		if (tornDown || cancelled) return;
		if (!result) {
			[self _alertTitle:[NSString stringWithFormat:NSLocalizedString(@"Could not read the database “%@”", @"PostgreSQL alter database: read failed"), database] error:error];
			return;
		}
		NSDictionary *details = result[@"details"];
		[self _whenIdle:^{
			if (tornDown || !parentWindow || [parentWindow attachedSheet] || ![database isEqualToString:currentDatabase]) return;
			[SPPostgresAlterDatabaseSheet beginOnWindow:parentWindow database:database owner:details[@"owner"] comment:details[@"comment"] roles:result[@"roles"] completion:^(NSDictionary *values) {
				if (values && !tornDown) [self _alterDatabase:database from:details to:values];
			}];
		}];
	}];
}

- (void)_alterDatabase:(NSString *)database from:(NSDictionary *)details to:(NSDictionary *)values
{
	if ([self _refuseWriteWhileBusy]) return;
	NSString *owner = values[@"owner"];
	NSString *comment = values[@"comment"];
	NSString *newName = values[@"name"];
	BOOL ownerChanged = [owner length] && ![owner isEqualToString:details[@"owner"]];
	BOOL commentChanged = ![comment isEqualToString:details[@"comment"]];

	void (^rename)(void) = ^{
		if ([newName length] && ![newName isEqualToString:database]) {
			[self _changeDatabase:database
					  description:NSLocalizedString(@"Renaming database...", @"PostgreSQL rename database task")
					 failureTitle:[NSString stringWithFormat:NSLocalizedString(@"Could not rename the database “%@”", @"PostgreSQL rename database failed"), database]
						   change:^BOOL(SPPostgresCatalog *writer, NSError **error) { return [writer renameDatabase:database toName:newName error:error]; }
					openOnSuccess:newName];
		}
	};
	if (!ownerChanged && !commentChanged) {
		rename();
		return;
	}

	void (^then)(void) = [[rename copy] autorelease];
	[taskRunner runTaskWithDescription:NSLocalizedString(@"Altering database...", @"PostgreSQL alter database task") cancelTitle:nil work:^id(PGPostgresConnection *theConnection, NSError **error) {
		SPPostgresCatalog *writer = [[[SPPostgresCatalog alloc] initWithConnection:theConnection] autorelease];
		if (ownerChanged && ![writer setOwner:owner ofDatabase:database error:error]) return nil;
		if (commentChanged && ![writer setComment:comment ofDatabase:database error:error]) return nil;
		return @YES;
	} completion:^(id result, NSError *error, BOOL cancelled) {
		if (tornDown || cancelled) return;
		if (!result) {
			[self _alertTitle:[NSString stringWithFormat:NSLocalizedString(@"Could not alter the database “%@”", @"PostgreSQL alter database failed"), database] error:error];
			return;
		}
		[self _whenIdle:then];
	}];
}

/// Database ▸ Open Database in New Tab: this database (its shown schema and pane, and the Query text) in a new tab.
- (IBAction)openDatabaseInNewTab:(id)sender
{
	if (![self _canRunDatabaseAction]) return;
	[self _openInNewTabRelation:nil inSchema:[sidebar selectedSchema] inNewWindow:NO];
}

/// Database ▸ Show Server Variables… (⇧⌘V): pg_settings, read on the tab's runner.
- (IBAction)showServerVariables:(id)sender
{
	if (![self _canRunDatabaseAction] || ![self _endPaneEditing]) return;
	[taskRunner runTaskWithDescription:NSLocalizedString(@"Loading...", @"Postgres server variables: loading task") cancelTitle:nil work:^id(PGPostgresConnection *theConnection, NSError **error) {
		return [[[[SPPostgresCatalog alloc] initWithConnection:theConnection] autorelease] serverSettings:error];
	} completion:^(id rows, NSError *error, BOOL cancelled) {
		if (tornDown || cancelled) return;
		if (!rows) {
			[self _alertTitle:NSLocalizedString(@"Could not read the server variables", @"Postgres server variables failed") error:error];
			return;
		}
		[self _whenIdle:^{
			if (!parentWindow || [parentWindow attachedSheet]) return;
			[SPPostgresServerListSheet beginOnWindow:parentWindow
											   title:NSLocalizedString(@"Server Variables", @"Postgres server variables sheet title")
											 columns:@[@{@"key": @"name", @"title": NSLocalizedString(@"Variable Name", @"Postgres server variables: name column"), @"width": @220},
													   @{@"key": @"setting", @"title": NSLocalizedString(@"Value", @"Postgres server variables: value column"), @"width": @160},
													   @{@"key": @"unit", @"title": NSLocalizedString(@"Unit", @"Postgres server variables: unit column"), @"width": @50},
													   @{@"key": @"category", @"title": NSLocalizedString(@"Category", @"Postgres server variables: category column"), @"width": @180},
													   @{@"key": @"description", @"title": NSLocalizedString(@"Description", @"Postgres server variables: description column"), @"width": @300}]
												rows:rows refresh:nil processAction:nil completion:nil];
		}];
	}];
}

/// Reads pg_stat_activity on the tab's runner into the open process list.
- (void)_reloadServerProcesses:(SPPostgresServerListSheet *)list
{
	if (tornDown || !list) return;
	[taskRunner runTaskWithDescription:nil cancelTitle:nil work:^id(PGPostgresConnection *theConnection, NSError **error) {
		return [[[[SPPostgresCatalog alloc] initWithConnection:theConnection] autorelease] serverProcesses:error];
	} completion:^(id rows, NSError *error, BOOL cancelled) {
		if (tornDown || cancelled || [SPPostgresServerListSheet currentSheet] != list) return;
		if (rows) [list setRows:rows];
		else NSBeep();
	}];
}

/// Asks, then cancels the process's query or ends its connection, and reloads the list.
- (void)_signalServerProcess:(NSDictionary *)row terminate:(BOOL)terminate list:(SPPostgresServerListSheet *)list
{
	NSInteger pid = [[row objectForKey:@"pid"] integerValue];
	if (tornDown || pid <= 0) return;

	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setAlertStyle:NSAlertStyleWarning];
	[alert setMessageText:[NSString stringWithFormat:(terminate
		? NSLocalizedString(@"Kill the connection of process %ld?", @"Postgres process list: kill connection question")
		: NSLocalizedString(@"Cancel the query of process %ld?", @"Postgres process list: cancel query question")), (long)pid]];
	[alert setInformativeText:terminate
		? NSLocalizedString(@"The session is ended (pg_terminate_backend); an open transaction is rolled back.", @"Postgres process list: kill connection detail")
		: NSLocalizedString(@"The statement it is running is cancelled (pg_cancel_backend).", @"Postgres process list: cancel query detail")];
	[alert addButtonWithTitle:terminate ? NSLocalizedString(@"Kill Connection", @"Postgres process list: kill connection button") : NSLocalizedString(@"Cancel Query", @"Postgres process list: cancel query button")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	[alert beginSheetModalForWindow:[list sheet] completionHandler:^(NSModalResponse response) {
		if (response != NSAlertFirstButtonReturn || tornDown || [SPPostgresServerListSheet currentSheet] != list) return;
		[self _signalProcess:pid terminate:terminate list:list];
	}];
}

/// Sends the signal (no question), then reloads the list; a refusal is shown on the list's sheet.
- (void)_signalProcess:(NSInteger)pid terminate:(BOOL)terminate list:(SPPostgresServerListSheet *)list
{
	if (tornDown) return;
	[taskRunner runTaskWithDescription:nil cancelTitle:nil work:^id(PGPostgresConnection *theConnection, NSError **error) {
		return [[[[SPPostgresCatalog alloc] initWithConnection:theConnection] autorelease] signalProcess:pid terminate:terminate error:error] ? @YES : nil;
	} completion:^(id result, NSError *error, BOOL cancelled) {
		if (tornDown || cancelled || [SPPostgresServerListSheet currentSheet] != list) return;
		if (!result) {
			NSAlert *failure = [[[NSAlert alloc] init] autorelease];
			[failure setAlertStyle:NSAlertStyleWarning];
			[failure setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Could not signal process %ld", @"Postgres process list: signal failed"), (long)pid]];
			[failure setInformativeText:[error localizedDescription] ?: @""];
			if (alertPresenter) alertPresenter(failure);
			else [failure beginSheetModalForWindow:[list sheet] completionHandler:nil];
		}
		[self _reloadServerProcesses:list];
	}];
}

/// Database ▸ Show Server Processes… (⌥⌘P): pg_stat_activity, with Refresh, Cancel Query and Kill Connection.
- (IBAction)showServerProcesses:(id)sender
{
	if (![self _canRunDatabaseAction] || ![self _endPaneEditing]) return;
	[taskRunner runTaskWithDescription:NSLocalizedString(@"Loading...", @"Postgres server processes: loading task") cancelTitle:nil work:^id(PGPostgresConnection *theConnection, NSError **error) {
		return [[[[SPPostgresCatalog alloc] initWithConnection:theConnection] autorelease] serverProcesses:error];
	} completion:^(id rows, NSError *error, BOOL cancelled) {
		if (tornDown || cancelled) return;
		if (!rows) {
			[self _alertTitle:NSLocalizedString(@"Could not read the server processes", @"Postgres server processes failed") error:error];
			return;
		}
		[self _whenIdle:^{
			if (!parentWindow || [parentWindow attachedSheet]) return;
			// The sheet is set once it exists (its blocks only run while it is up)
			__block SPPostgresServerListSheet *list = nil;
			list = [SPPostgresServerListSheet beginOnWindow:parentWindow
													  title:NSLocalizedString(@"Server Processes", @"Postgres server processes sheet title")
													columns:@[@{@"key": @"pid", @"title": NSLocalizedString(@"PID", @"Postgres server processes: pid column"), @"width": @60},
															  @{@"key": @"user", @"title": NSLocalizedString(@"User", @"Postgres server processes: user column"), @"width": @90},
															  @{@"key": @"database", @"title": NSLocalizedString(@"Database", @"Postgres server processes: database column"), @"width": @100},
															  @{@"key": @"client", @"title": NSLocalizedString(@"Client", @"Postgres server processes: client column"), @"width": @90},
															  @{@"key": @"application", @"title": NSLocalizedString(@"Application", @"Postgres server processes: application column"), @"width": @110},
															  @{@"key": @"state", @"title": NSLocalizedString(@"State", @"Postgres server processes: state column"), @"width": @80},
															  @{@"key": @"started", @"title": NSLocalizedString(@"Query Start", @"Postgres server processes: query start column"), @"width": @130},
															  @{@"key": @"query", @"title": NSLocalizedString(@"Query", @"Postgres server processes: query column"), @"width": @300}]
													   rows:rows
													refresh:^{ [self _reloadServerProcesses:list]; }
											  processAction:^(NSDictionary *row, BOOL terminate) { [self _signalServerProcess:row terminate:terminate list:list]; }
												 completion:nil];
		}];
	}];
}

#pragma mark - Users

/// The Users sheet can open: connected, not processing (a database switch), and no sheet is attached.
- (BOOL)_canShowUsers
{
	return SPPostgresFeatureIsAvailable(SPPostgresFeatureUsers) && [self _canRunSheetJob];
}

/// File ▸ Import… and Export… (and the table list's and Query view's exports) can open: a sheet job can, and this
/// build's scope has Import/Export (SPPostgresFeatureScope).
- (BOOL)_canImportExport
{
	return SPPostgresFeatureIsAvailable(SPPostgresFeatureImportExport) && [self _canRunSheetJob];
}

/// The sheet of a job (Users, Export, Import, Transfer) can open: connected, not processing (a database switch), no sheet
/// attached, and no other job's sheet pending.
- (BOOL)_canRunSheetJob
{
	return !tornDown && !isProcessing && !confirmingSwitch && !usersController && !exportController && !importController && !transferController && [connection isConnected] && parentWindow && ![parentWindow attachedSheet];
}

/**
 * The default connection provider: a new SPPostgresConnector per call, for the favorite with the database asked for
 * and the passwords this session was opened with (as -_switchToDatabase:forHistory:), with the console logger
 * attached. adopt (may be nil) is handed each connector as it is made, and keeps it; without one, the connector is
 * kept until the background job on its connection ends (SPPostgresBackgroundJob). sheetWindow (may be nil) gives the
 * window the connector's SSH sheets go to, else this tab's window. connecting (may be nil) is handed each connector as
 * its attempt starts (e.g. to -cancel it), and called with nil once the attempt is over.
 */
- (SPPostgresConnectionProvider)_defaultConnectionProviderAdopting:(void (^)(SPPostgresConnector *theConnector))adopt sheetWindow:(NSWindow *(^)(void))sheetWindow connecting:(void (^)(SPPostgresConnector *theConnector))connecting
{
	SPPostgresFavorite *base = [[favorite copy] autorelease];
	NSString *thePassword = [connector password] ?: [connection password];
	NSString *theSSHPassword = [connector sshPassword];
	NSString *connectionName = [self _connectionName];
	NSWindow *window = parentWindow;
	void (^theAdopt)(SPPostgresConnector *) = [[adopt copy] autorelease];
	NSWindow *(^theSheetWindow)(void) = [[sheetWindow copy] autorelease];
	void (^theConnecting)(SPPostgresConnector *) = [[connecting copy] autorelease];

	SPPostgresConnectionProvider provider = ^(NSString *database, void (^completion)(PGPostgresConnection *, NSError *)) {
		SPPostgresFavorite *target = [[base copy] autorelease];
		[target setDatabase:database];
		NSWindow *host = (theSheetWindow ? theSheetWindow() : nil) ?: window;
		SPPostgresConnector *newConnector = [[[SPPostgresConnector alloc] initWithFavorite:target password:thePassword sshPassword:theSSHPassword parentWindow:host] autorelease];
		if (theAdopt) theAdopt(newConnector);
		if (theConnecting) theConnecting(newConnector);
		void (^done)(PGPostgresConnection *, NSError *) = [[completion copy] autorelease];
		// The completion block keeps the connector during the attempt (the connector lets go of it once called)
		[newConnector connectWithCompletion:^(PGPostgresConnection *theConnection, NSError *error) {
			// The statements go to the Console as this tab's do (COPY data never does; passwords only as verifiers)
			if (theConnection) {
				SPPostgresConsoleLogger *jobLogger = [[[SPPostgresConsoleLogger alloc] initWithConnectionName:connectionName database:database] autorelease];
				[jobLogger attachToConnection:theConnection];
				if (!theAdopt) [SPPostgresBackgroundJob keepOwner:newConnector untilJobEndsOnConnection:theConnection];
			}
			if (theConnecting) theConnecting(nil);
			done(theConnection, error);
		}];
	};
	return [[provider copy] autorelease];
}

- (SPPostgresConnectionProvider)effectiveConnectionProvider
{
	return [self connectionProviderForJobWithSheetWindow:nil connecting:nil];
}

- (SPPostgresConnectionProvider)connectionProviderForJobWithSheetWindow:(NSWindow *(^)(void))sheetWindow connecting:(void (^)(SPPostgresConnector *connector))connecting
{
	if (connectionProvider) return [[connectionProvider retain] autorelease];
	return [self _defaultConnectionProviderAdopting:nil sheetWindow:sheetWindow connecting:connecting];
}

- (void)presentAlert:(NSAlert *)alert
{
	[self _presentAlert:alert];
}

- (IBAction)showUserManager:(id)sender
{
	if (![self _canShowUsers] || ![currentDatabase length]) return;

	SPPostgresConnectionProvider provider = connectionProvider;
	__block SPPostgresUsersController *owner = nil; // not retained by the blocks (MRC __block)
	NSString *connectionName = [self _connectionName];
	if (!provider) {
		// The sheet keeps its connectors until it ends; once it is up, the SSH tunnel's sheets (passphrase, host key)
		// can only attach to it
		provider = [self _defaultConnectionProviderAdopting:^(SPPostgresConnector *theConnector) {
			[owner adoptConnector:theConnector];
		} sheetWindow:^NSWindow *{
			return [owner windowForConnectorSheets];
		} connecting:nil];
	}

	SPPostgresUsersController *controller = [[SPPostgresUsersController alloc] initWithDatabase:currentDatabase connectionProvider:provider];
	owner = controller;
	usersController = controller; // released when the sheet ends
	if (alertPresenter) [controller setAlertPresenter:alertPresenter];
	[controller setServerName:connectionName];

	// The roles load asynchronously: only attach the sheet if this tab is still the one its window shows
	__block SPPostgresDocument *document = self; // retained until the sheet ends (below)
	NSWindow *window = parentWindow;
	[controller setCanPresent:^BOOL{
		return !document->tornDown && [document parentWindow] == window && [document _isSelectedTab];
	}];

	[self retain]; // until the sheet ends
	[controller beginSheetForWindow:parentWindow completion:^(BOOL applied) {
		if (usersController == controller) {
			usersController = nil;
			[controller autorelease];
		}
		[self autorelease];
	}];
}

#pragma mark - Export

- (IBAction)export:(id)sender
{
	[self _beginExportChoosingQueryResult:NO];
}

- (IBAction)exportQueryResult:(id)sender
{
	[self _beginExportChoosingQueryResult:YES];
}

- (void)_beginExportChoosingQueryResult:(BOOL)queryResult
{
	if (![self _canImportExport] || ![currentDatabase length]) return;

	SPPostgresExportController *controller = [[SPPostgresExportController alloc] initWithDocument:self];
	exportController = controller; // released when it ends
	[controller setDidEnd:^{
		if (exportController == controller) {
			exportController = nil;
			[controller autorelease];
		}
	}];
	if (queryResult) [controller beginSheetWithQueryResultSource];
	else [controller beginSheet];
}

#pragma mark - Transfer

/// The Transfer sheet can open: a sheet job can (see -_canRunSheetJob) and a database is selected (the one copied).
- (BOOL)_canShowTransfer
{
	return SPPostgresFeatureIsAvailable(SPPostgresFeatureTransfer) && [self _canRunSheetJob] && [currentDatabase length] > 0;
}

- (IBAction)showTransfer:(id)sender
{
	if (![self _canShowTransfer]) return;

	SPPostgresTransferController *controller = [[SPPostgresTransferController alloc] initWithDocument:self];
	transferController = controller; // released when it ends
	[controller setDidEnd:^{
		if (transferController == controller) {
			transferController = nil;
			[controller autorelease];
		}
	}];
	[controller beginSheet];
}

#pragma mark - Import

- (IBAction)import:(id)sender
{
	if (![self _canImportExport] || ![currentDatabase length]) return;
	// An edit in progress is saved first: the import's end reloads the lists and panes (see -importDidChangeDatabase)
	if (![self _endPaneEditing]) return;

	SPPostgresImportController *controller = [[SPPostgresImportController alloc] initWithDocument:self];
	importController = controller; // released when it ends
	[controller setDidEnd:^{
		if (importController == controller) {
			importController = nil;
			[controller autorelease];
		}
	}];
	[controller beginImport];
}

- (void)importDidChangeDatabase
{
	if (tornDown) return;
	contentNeedsReset = YES;
	structureNeedsReset = YES;
	relationsNeedReset = YES;
	triggersNeedReset = YES;
	infoNeedsReset = YES;
	sequenceNeedsReset = YES;
	extensionNeedsReset = YES;

	// Inside the tab's aborted transaction the catalog can't be read: the lists wait for the Query view's next run. The
	// status is read on the runner (after what is queued; libpq's, read on the main thread, could be a task's: ACTIVE).
	listsNeedReload = YES;
	[taskRunner runTaskWithDescription:nil cancelTitle:nil work:^id(PGPostgresConnection *theConnection, NSError **error) {
		return @([theConnection transactionStatus]);
	} completion:^(id status, NSError *error, BOOL cancelled) {
		if (tornDown) return;
		if (!cancelled && [status integerValue] != PGPostgresTransactionInError) {
			listsNeedReload = NO;
			[self _reloadSidebarKeepingSelection:^{
				[self _reloadDatabasePopup];
				[self updateWindowTitle:self];
				[self _refreshCurrentPaneIfStale];
			}];
			return;
		}
		[self _refreshCurrentPaneIfStale];
	}];
}

- (void)unavailableInThisVersion:(id)sender
{
	// Never enabled (see -validateToolbarItem:): the items of features Postgres tabs don't have yet
}

/// Shows the shared console, or hides it when it is the key window (as MySQL's Toggle Console).
- (void)toggleConsole:(id)sender
{
	SPQueryController *console = [SPQueryController sharedQueryController];
	NSWindow *consoleWindow = [console window];

	if ([consoleWindow isVisible] && [consoleWindow isKeyWindow]) {
		[consoleWindow setIsVisible:NO];
		return;
	}

	// Entries aren't reloaded while the console is hidden
	if (![consoleWindow isVisible]) [console updateEntries];
	[consoleWindow makeKeyAndOrderFront:self];
}

@end
