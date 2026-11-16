#import <Cocoa/Cocoa.h>
#import "../SPWindowTabDocument.h"

@class PGPostgresConnection;
@class SPPostgresConnector;
@class SPPostgresContentController;
@class SPPostgresQueryController;
@class SPPostgresFavorite;
@class SPPostgresHistory;
@class SPPostgresSidebarController;
@class SPPostgresStructureController;
@class SPPostgresRelationsController;
@class SPPostgresTriggersController;
@class SPPostgresTableInfoController;
@class SPPostgresSequenceController;
@class SPPostgresExtensionController;
@class SPPostgresUsersController;
@class SPWindowController;
@class SPPostgresExportController;
@class SPPostgresImportController;
@class SPPostgresTransferController;
@class SPPostgresTaskRunner;

/**
 * Hands out a connection of its own to database: calls completion exactly once, on the main thread (synchronously or
 * later), with a connected connection or nil and an error. Used by the Users sheet, Export and Import, which never use
 * the tab's own connection.
 */
typedef void (^SPPostgresConnectionProvider)(NSString *database, void (^completion)(PGPostgresConnection *connection, NSError *error));

/// The panes of a PostgreSQL tab's right side (-showPane:, -currentPane, and the tab's history entries).
extern NSString * const SPPostgresPaneStructure __attribute__((visibility("default"))); // @"structure"
extern NSString * const SPPostgresPaneContent __attribute__((visibility("default")));   // @"content"
extern NSString * const SPPostgresPaneRelations __attribute__((visibility("default"))); // @"relations"
extern NSString * const SPPostgresPaneTriggers __attribute__((visibility("default")));  // @"triggers"
extern NSString * const SPPostgresPaneInfo __attribute__((visibility("default")));      // @"info"
extern NSString * const SPPostgresPaneQuery __attribute__((visibility("default")));     // @"query"
/// Shown whenever a sequence is selected in the sidebar (it has no toolbar item; Query stays available).
extern NSString * const SPPostgresPaneSequence __attribute__((visibility("default")));  // @"sequence"
/// Shown whenever an extension is selected in the sidebar (no toolbar item: as with a sequence, Structure and ⌘1
/// show it, and Query stays available). Extensions are database-wide: this pane is not recorded in History.
extern NSString * const SPPostgresPaneExtension __attribute__((visibility("default"))); // @"extension"

/**
 * A PostgreSQL connection hosted as a tab of an SPWindowController window: the left panel (schema
 * picker, tables, views, sequences, extensions), in the right pane one of the named panes (see -showPane:): the
 * Structure view of the selected table or view (SPPostgresStructureController), its Content view
 * (SPPostgresContentController), Relations, Triggers, Table Info, the Sequence view of a selected sequence
 * (SPPostgresSequenceController; no toolbar item: while a sequence is selected only Query is enabled), the
 * Extension view of a selected extension (SPPostgresExtensionController; likewise), or the Query view
 * (SPPostgresQueryController),
 * switched by the toolbar items and View menu items (⌘1–⌘6) as on MySQL tabs, the database picker and the
 * console logger. Built in code. Use on the main thread.
 *
 * Takes over `connector` (it keeps it, and disconnects it when the tab closes) and `connection`,
 * which must be the connector's connected connection. Host it with
 * -[SPWindowController addTabDocument:atIndex:select:]; the tab view item keeps it alive.
 *
 * While its tab is active it installs its own toolbar, the window title and the compact title chrome.
 * The toolbar is MySQL's (identifier TableWindowToolbar, the same item identifiers and saved layout);
 * the items Postgres tabs don't support yet are disabled.
 */
__attribute__((visibility("default")))
@interface SPPostgresDocument : NSObject <SPWindowTabDocument, NSToolbarDelegate, NSToolbarItemValidation, NSMenuItemValidation, NSSplitViewDelegate>

- (instancetype)initWithConnection:(PGPostgresConnection *)connection connector:(SPPostgresConnector *)connector favorite:(SPPostgresFavorite *)favorite;

/// @"(PostgreSQL <serverVersion>) <favorite name>/<database>", plus @"/<schema>.<table>" when a table is selected.
- (NSString *)windowTitleString;

/**
 * Postgres can't change database within a session: connects a new connector (same favorite and
 * passwords, `database` changed) and, on success, switches the tab to it and closes the old
 * connection. On failure the current connection is kept and the error is shown (see alertPresenter).
 * An edit in progress in the Content grid is saved first (if it can't be, nothing happens). If the user
 * has a transaction open (or aborted) in this session, closing it would roll it back, so they are asked
 * first (see confirmationPresenter); Cancel leaves everything as it was.
 */
- (void)switchToDatabase:(NSString *)database;

/**
 * Open Table in New Tab (newWindow NO) and in New Window (the sidebar's table menus; the sidebar delegate method
 * forwards here with the schema shown): connects a new session for the favorite, on this tab's database, with the
 * passwords this session was opened with (nothing is written to the Keychain or the favorites; an SSH favorite opens
 * a tunnel of its own, its sheets on this window). Meanwhile this tab shows it is connecting (isProcessing). On
 * success a new tab, on the new session, is added right after this one and selected, or is the only tab of a new
 * window. It gets the Query editor's text and shows the pane shown here (as they were when asked), then selects
 * `schema` and `name` (a table or view, see -selectRelationAfterLoad:inSchema:pane:). History is not copied. On failure
 * this tab shows the error (see alertPresenter) and nothing is opened. Refused (beep) while this tab is processing.
 */
- (void)openRelation:(NSString *)name inSchema:(NSString *)schema inNewWindow:(BOOL)newWindow;

/**
 * Selects `schema`, then its table or view `name`, once the loads the tab has asked for so far are done (queued on its
 * runner, not polled). A schema that can't be loaded, or a name that isn't listed, leaves the tab as it is.
 */
- (void)selectRelationAfterLoad:(NSString *)name inSchema:(NSString *)schema;
/// A Content foreign key link: selects schema.table (switching the sidebar's schema first) and shows its rows whose
/// column equals value in Content (NSBeep when it isn't listed or the selection can't change).
- (void)showRowsOfTable:(NSString *)table inSchema:(NSString *)schema whereColumn:(NSString *)column equals:(NSString *)value;

/**
 * The same, showing `pane` (Structure, Content, Relations, Triggers, Table Info or Query; nil or another one: the pane
 * stays) before the table or view is selected. Neither the pane nor the schema on the way is recorded in History.
 */
- (void)selectRelationAfterLoad:(NSString *)name inSchema:(NSString *)schema pane:(NSString *)pane;

/**
 * Makes the connector -openRelation:inSchema:inNewWindow: connects (it may return a connector of another favorite).
 * nil (the default): a new SPPostgresConnector with these arguments. Replaceable, e.g. by tests.
 */
@property (copy) SPPostgresConnector *(^openRelationConnectorFactory)(SPPostgresFavorite *favorite, NSString *password, NSString *sshPassword, NSWindow *parentWindow);

/// The favorite name, plus @"/<database>" while another Postgres tab of the same window has the same name.
- (NSString *)tabLabel;

/// The toolbar this tab installs in its window while active.
- (NSToolbar *)toolbar;

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar;
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar;

/// NO for every action this tab doesn't implement (MySQL-only items); the window's own items stay enabled.
- (BOOL)validateMenuItem:(NSMenuItem *)item;

/**
 * Shows a pane (one of the SPPostgresPane… names) in the right pane, as MySQL's tab view does: the other panes
 * are taken out of the window, keeping their state. An edit in progress in the pane being left is ended (saved)
 * first; if it can't be, nothing changes. A pane the Query view may have made stale reloads as it is shown.
 * Unknown names show Content. While a sequence is selected, any pane but Query shows the Sequence pane; without
 * one, the Sequence pane gives way to the pane shown before it. The same goes for an extension and the Extension pane.
 */
- (void)showPane:(NSString *)pane;

/// The pane shown in the right pane (an SPPostgresPane… name).
@property (readonly) NSString *currentPane;

/// The Structure view of the selected table or view (needs one), as MySQL's Structure toolbar item and View > Structure (⌘1).
- (IBAction)viewStructure:(id)sender;

/// Shows the Content view of the selected table (needs one), as MySQL's Content toolbar item and View menu item.
- (IBAction)viewContent:(id)sender;

/// Relations (⌘3) and Triggers (⌘4): for a table or partitioned table only.
- (IBAction)viewRelations:(id)sender;
- (IBAction)viewTriggers:(id)sender;

/// Table Info (⌘5), as MySQL's View > Table Info: for any selected table or view.
- (IBAction)viewStatus:(id)sender;

/// Shows the Query view, as MySQL's Query toolbar item and View > Custom Query.
- (IBAction)viewQuery:(id)sender;

/// The Install Extension sheet (SPPostgresInstallExtensionSheet), from the sidebar's "Install Extension…": on Install the
/// sidebar reloads and the new extension is selected, its pane shown. Does nothing while a sheet is attached.
- (IBAction)showInstallExtensionSheet:(id)sender;

/**
 * The Users sheet (SPPostgresUsersController), as MySQL's Users toolbar item and Database > User Accounts…: the
 * cluster's roles, edited on connections of the sheet's own (see connectionProvider), never this tab's.
 * Enabled while connected, not processing, and no sheet is attached.
 */
- (IBAction)showUserManager:(id)sender;

/**
 * Where the Users sheet, Export and Import get their connections (see SPPostgresConnectionProvider). nil (the default)
 * opens a new SPPostgresConnector for the favorite with that database, with the session's passwords and this window
 * (as -switchToDatabase: does), with the console logger attached; the Users sheet keeps its connectors and
 * disconnects them when it ends, and a background job's connector is disconnected when the job ends (see
 * SPPostgresBackgroundJob). Replaceable, e.g. by tests.
 */
@property (copy) SPPostgresConnectionProvider connectionProvider;

/// The provider jobs use: connectionProvider, or the default one described there.
- (SPPostgresConnectionProvider)effectiveConnectionProvider;

/**
 * The provider a job uses: connectionProvider when set; otherwise the default one, whose connectors show their SSH
 * sheets (host key, passwords) on the window sheetWindow returns (e.g. the job's progress sheet: the tab's window
 * can't take another sheet then; nil or a nil result: this tab's window), and are handed to connecting as their
 * attempt starts (so a Cancel can -cancel them), then nil once it is over. Both blocks may be nil.
 */
- (SPPostgresConnectionProvider)connectionProviderForJobWithSheetWindow:(NSWindow *(^)(void))sheetWindow connecting:(void (^)(SPPostgresConnector *connector))connecting;

/// Shows an alert as the tab shows its own (alertPresenter, or a sheet on the window; held while the tab isn't shown).
- (void)presentAlert:(NSAlert *)alert;

/**
 * File ▸ Export…: the Export sheet (SPPostgresExportController). Enabled while connected, not processing and no sheet
 * is attached.
 */
- (IBAction)export:(id)sender;

/// The Query view's Export Result ▸ As CSV file…: the Export sheet (when it can open, as -export:) with its Query
/// result source chosen and the format on CSV.
- (IBAction)exportQueryResult:(id)sender;

/// The Export sheet's controller while it is shown or its export runs, else nil.
@property (readonly) SPPostgresExportController *exportController;

/// Where "Copy Create … Syntax" (and the Create Syntax sheet's Copy) puts the statements: the general pasteboard
/// unless set (tests set a private one).
@property (nonatomic, retain) NSPasteboard *createSyntaxPasteboard;

/**
 * File ▸ Import…: the open panel, then (for CSV) the mapping sheet, then the import (SPPostgresImportController).
 * Enabled while connected, not processing and no sheet is attached. Import from Clipboard stays disabled.
 */
- (IBAction)import:(id)sender;

/// The Import controller while its panel or sheets are shown or its import runs, else nil.
@property (readonly) SPPostgresImportController *importController;

/**
 * The Transfer toolbar item: the Transfer sheet (SPPostgresTransferController), copying this database (or some of its
 * tables) into a database of any Postgres favorite. Enabled while connected, not processing and no sheet is attached.
 */
- (IBAction)showTransfer:(id)sender;

/// The Transfer sheet's controller while it is shown or its transfer runs, else nil.
@property (readonly) SPPostgresTransferController *transferController;

/**
 * An import changed the database (called by SPPostgresImportController after a successful or partly successful
 * import): the sidebar reloads keeping its selection (once the tab's own transaction can read the catalog), the
 * database pop-up too, and every pane is marked stale, the shown one reloading now.
 */
- (void)importDidChangeDatabase;

/// The database this tab is connected to.
@property (readonly) NSString *currentDatabase;

/// The Users sheet's controller while it is shown (or connecting), else nil.
@property (readonly) SPPostgresUsersController *usersController;

/**
 * Shows the tab's alerts (catalog errors, a failed database switch). nil (the default) shows them as
 * sheets on the parent window while the tab is active and the window visible; otherwise they wait
 * until it is. Replaceable, e.g. by tests.
 */
@property (copy) void (^alertPresenter)(NSAlert *alert);

/**
 * Asks to confirm a database switch that would roll back the user's open transaction: call completion
 * exactly once with YES to switch (later calls are ignored). The completion is a heap block that stays valid
 * until it is called, so a presenter may store it. nil (the default) shows a sheet on the parent window.
 * Replaceable, e.g. by tests.
 */
@property (copy) void (^confirmationPresenter)(NSAlert *alert, void (^completion)(BOOL confirmed));

@property (readonly) SPPostgresSidebarController *sidebar;
/// The right pane: the Structure view of the table or view selected in the sidebar.
@property (readonly) SPPostgresStructureController *structureController;
/// The right pane: the Relations view (foreign keys) of the table selected in the sidebar.
@property (readonly) SPPostgresRelationsController *relationsController;
/// The right pane: the Triggers view of the table selected in the sidebar.
@property (readonly) SPPostgresTriggersController *triggersController;
/// The right pane: the Table Info view of the table or view selected in the sidebar.
@property (readonly) SPPostgresTableInfoController *infoController;
/// The right pane: the Sequence view of the sequence selected in the sidebar.
@property (readonly) SPPostgresSequenceController *sequenceController;
/// The right pane: the Extension view of the extension selected in the sidebar.
@property (readonly) SPPostgresExtensionController *extensionController;
/// The right pane: the Content view of the table or view selected in the sidebar.
@property (readonly) SPPostgresContentController *contentController;
/// The right pane: the Query view. Its editor's text is kept for the tab's session (also across database switches).
@property (readonly) SPPostgresQueryController *queryController;
/// The Query editor's help window (an SPPostgresHelpViewerController, MySQL's help window titled "PostgreSQL Help"):
/// nil until the help is first shown (Update Help while typing, or the editor's context menu); closed with the tab.
@property (readonly) NSWindowController *helpViewerController;
/// The tab's Table History (the toolbar's History control, View > Back/Forward In History).
@property (readonly) SPPostgresHistory *history;
@property (readonly) PGPostgresConnection *connection;
@property (readonly) SPPostgresFavorite *favorite;

/// YES while the tab's runner is busy (a load runs), or a database switch or an Open Table in New Tab/Window is
/// connecting. KVO-compliant, changes posted on the main thread (drives the tab's progress indicator).
@property (readonly) BOOL isProcessing;

/**
 * Runs the tab's loads on its connection in the background (one per connection: replaced when a database switch
 * completes, the previous one invalidated and its connection closed once its worker is idle). While it is busy the
 * tab shows MySQL's task display (SPPostgresTaskDisplay) and blocks input to its view, and isProcessing is YES. The
 * sidebar, the Query view and every pane load through it (none reads the connection on the main thread meanwhile).
 */
@property (readonly) SPPostgresTaskRunner *taskRunner;

@property (readonly, assign) SPWindowController *parentWindowController;
@property (readonly, assign) NSWindow *parentWindow;
@property (readonly, assign) NSTabViewItem *parentTabViewItem;

@end
