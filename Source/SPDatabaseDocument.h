//
//  SPDatabaseDocument.h
//  sequel-pro
//
//  Created by Lorenz Textor (lorenz@textor.ch) on May 1, 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//  Copyright (c) 2012 Sequel Pro Team. All rights reserved.
//  
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <https://github.com/sequelpro/sequelpro>

@class SPConnectionController;
@class SPProcessListController;
@class SPServerVariablesController;
@class SPUserManager;
@class SPWindowController;
@class SPSplitView;
@class SPDatabaseData;
@class SPTablesList;
@class SPTableStructure;
@class SPTableContent;
@class SPTableData;
@class SPServerSupport;
@class SPCustomQuery;
@class SPDatabaseStructure;
@class SPMySQLConnection;
@class SPCharsetCollationHelper;
@class SPGotoDatabaseController;
@class SPCreateDatabaseInfo;
@class SPExtendedTableInfo;
@class SPTableTriggers;
@class SPTableRelations;
@class SPHelpViewerClient;
@class SPDataImport;

#import "SPDatabaseContentViewDelegate.h"
#import "SPConnectionControllerDelegateProtocol.h"
#import "SPThreadAdditions.h"

#import <WebKit/WebKit.h>
#import <SPMySQL/SPMySQLConnectionDelegate.h>

/**
 * The SPDatabaseDocument class controls the primary database view window.
 */
@interface SPDatabaseDocument : NSObject <SPConnectionControllerDelegateProtocol, SPMySQLConnectionDelegate, NSTextFieldDelegate, NSToolbarDelegate, SPCountedObject, WebFrameLoadDelegate>
{
	// IBOutlets
	IBOutlet SPTablesList *tablesListInstance;
	IBOutlet SPTableStructure *tableSourceInstance;
	IBOutlet SPTableContent <SPDatabaseContentViewDelegate> *tableContentInstance;
	IBOutlet SPTableRelations *tableRelationsInstance;
	IBOutlet SPTableTriggers *tableTriggersInstance;
	IBOutlet SPCustomQuery *customQueryInstance;
	IBOutlet SPDataImport *tableDumpInstance;
	IBOutlet SPTableData *tableDataInstance;
	IBOutlet SPExtendedTableInfo *extendedTableInfoInstance;
	IBOutlet SPDatabaseData *databaseDataInstance;
#ifndef SP_CODA
	IBOutlet id spHistoryControllerInstance;
	IBOutlet id exportControllerInstance;
#endif
	IBOutlet SPHelpViewerClient *helpViewerClientInstance;

	IBOutlet id statusTableAccessoryView;
	IBOutlet id statusTableView;
	IBOutlet id statusTableCopyChecksum;
	
#ifndef SP_CODA /* ivars */
    SPUserManager *userManagerInstance;
#endif
	SPServerSupport *serverSupport;
	
	IBOutlet NSSearchField *listFilterField;

	IBOutlet NSScrollView *tableInfoScrollView;
	IBOutlet NSScrollView *documentActivityScrollView;

	IBOutlet NSView *parentView;
	
	IBOutlet NSView *titleAccessoryView;
	IBOutlet id titleImageView;
	IBOutlet id titleStringView;
	
	IBOutlet id databaseSheet;
	IBOutlet id databaseCopySheet;
	IBOutlet id databaseRenameSheet;
	
	IBOutlet id databaseAlterSheet;
	IBOutlet NSPopUpButton *databaseAlterEncodingButton;
	IBOutlet NSPopUpButton *databaseAlterCollationButton;
	
	SPCharsetCollationHelper *alterDatabaseCharsetHelper;

	IBOutlet NSProgressIndicator* queryProgressBar;
#ifndef SP_CODA
	IBOutlet NSBox *taskProgressLayer;
	IBOutlet id taskProgressIndicator;
	IBOutlet id taskDescriptionText;
	IBOutlet id taskDurationTime;
	IBOutlet NSButton *taskCancelButton;
#endif
	
	IBOutlet id databaseNameField;
	IBOutlet id databaseEncodingButton;
	IBOutlet id databaseCollationButton;
	IBOutlet id addDatabaseButton;
	
	SPCharsetCollationHelper *addDatabaseCharsetHelper;

#ifndef SP_CODA
	IBOutlet id databaseCopyNameField;
	IBOutlet NSButton *copyDatabaseDataButton;
	IBOutlet id copyDatabaseMessageField;
	IBOutlet id copyDatabaseButton;
#endif
	
	IBOutlet id databaseRenameNameField;
	IBOutlet id renameDatabaseMessageField;
	IBOutlet id renameDatabaseButton;

	IBOutlet NSPopUpButton *chooseDatabaseButton;
#ifndef SP_CODA
	IBOutlet NSSegmentedControl *historyControl;
	IBOutlet NSTabView *tableTabView;
	
	IBOutlet NSTableView *tableInfoTable;
	IBOutlet SPSplitView *contentViewSplitter;
	IBOutlet SPSplitView *tableInfoSplitView;
	
	IBOutlet NSPopUpButton *encodingPopUp;
#endif
	
	IBOutlet NSTextView *customQueryTextView;
	
	IBOutlet NSTableView *dbTablesTableView;

	IBOutlet NSTextField *createTableSyntaxTextField;
	IBOutlet NSTextView *createTableSyntaxTextView;
	IBOutlet NSWindow *createTableSyntaxWindow;
	IBOutlet NSWindow *connectionErrorDialog;

#ifndef SP_CODA
	IBOutlet id saveConnectionAccessory;
	IBOutlet NSButton *saveConnectionIncludeData;
	IBOutlet NSButton *saveConnectionIncludeQuery;
	IBOutlet NSButton *saveConnectionSavePassword;
	IBOutlet id saveConnectionSavePasswordAlert;
	IBOutlet NSButton *saveConnectionEncrypt;
	IBOutlet NSButton *saveConnectionAutoConnect;
	IBOutlet NSSecureTextField *saveConnectionEncryptString;
	
	IBOutlet id inputTextWindow;
	IBOutlet id inputTextWindowHeader;
	IBOutlet id inputTextWindowMessage;
	IBOutlet id inputTextWindowSecureTextField;
	NSInteger passwordSheetReturnCode;
#endif
	
	// Master connection
	SPMySQLConnection *mySQLConnection;

	// Controllers
	SPConnectionController *connectionController;
#ifndef SP_CODA /* ivars */
	SPProcessListController *processListController;
	SPServerVariablesController *serverVariablesController;
#endif
	NSString *selectedTableName;
	SPTableType selectedTableType;

	BOOL structureLoaded;
	BOOL contentLoaded;
	BOOL statusLoaded;
	BOOL triggersLoaded;
	BOOL relationsLoaded;

	NSString *selectedDatabase;
	NSString *mySQLVersion;
	NSString *selectedDatabaseEncoding;
#ifndef SP_CODA /* ivars */
	NSUserDefaults *prefs;
	NSMutableArray *nibObjectsToRelease;
	NSUndoManager *undoManager;
#endif

	NSMenu *selectEncodingMenu;
	BOOL _supportsEncoding;
	BOOL _isConnected;
	NSInteger _isWorkingLevel;
#ifndef SP_CODA /* ivars */
	BOOL _mainNibLoaded;
#endif
	BOOL databaseListIsSelectable;
	NSInteger _queryMode;
	BOOL _isSavedInBundle;

	BOOL _workingTimeout;

#ifndef SP_CODA
	NSWindow *taskProgressWindow;
	BOOL taskDisplayIsIndeterminate;
	CGFloat taskProgressValue;
	CGFloat taskDisplayLastValue;
	CGFloat taskProgressValueDisplayInterval;
	NSTimer *taskDrawTimer;
	NSTimer *queryExecutionTimer;
	NSDate *taskFadeInStartDate;
	NSDate *queryStartDate;
	BOOL taskCanBeCancelled;
	id taskCancellationCallbackObject;
	SEL taskCancellationCallbackSelector;
	
	NSToolbar *mainToolbar;
	NSToolbarItem *chooseDatabaseToolbarItem;
	
	WebView *printWebView;
#endif
	
	NSMutableArray *allDatabases;
	NSMutableArray *allSystemDatabases;
	
	NSString *queryEditorInitString;
	
#ifndef SP_CODA /* ivars */
	NSURL *sqlFileURL;
	NSStringEncoding sqlFileEncoding;
	NSURL *spfFileURL;
	NSDictionary *spfSession;
	NSMutableDictionary *spfPreferences;
	NSMutableDictionary *spfDocData;

	NSMutableArray *runningActivitiesArray;
#endif

#ifndef SP_CODA /* ivars */
	NSThread *printThread;
	
	NSArray *statusValues;

	// Alert return codes
	NSInteger saveDocPrefSheetStatus;
	NSInteger confirmCopyDatabaseReturnCode;

	// Properties
	SPWindowController *parentWindowController;
#endif
	NSWindow *parentWindow;
#ifndef SP_CODA /* ivars */
	NSTabViewItem *parentTabViewItem;
#endif
	BOOL isProcessing;
#ifndef SP_CODA /* ivars */
	NSString *processID;
	BOOL windowTitleStatusViewIsVisible;
#endif
	SPDatabaseStructure *databaseStructureRetrieval;
	SPGotoDatabaseController *gotoDatabaseController;
	
	int64_t instanceId;
}

@property (nonatomic, assign) NSTableView *dbTablesTableView;
@property (readwrite, retain) NSURL *sqlFileURL;
@property (readwrite, assign) NSStringEncoding sqlFileEncoding;
@property (readwrite, assign) SPWindowController *parentWindowController;
@property (readwrite, assign) NSTabViewItem *parentTabViewItem;
@property (readwrite, assign) BOOL isProcessing;
@property (readwrite, retain) NSString *processID;

@property (readonly) SPServerSupport *serverSupport;
@property (readonly) SPDatabaseStructure *databaseStructureRetrieval;
@property (readonly) SPDataImport *tableDumpInstance;
@property (readonly) SPTablesList *tablesListInstance;
@property (readonly) SPCustomQuery *customQueryInstance;
@property (readonly) SPTableContent <SPDatabaseContentViewDelegate> *tableContentInstance;

@property (readonly) int64_t instanceId;

- (SPHelpViewerClient *)helpViewerClient;

#ifndef SP_CODA /* method decls */
- (BOOL)isUntitled;
#endif
- (BOOL)couldCommitCurrentViewActions;

#ifndef SP_CODA /* method decls */
- (void)initQueryEditorWithString:(NSString *)query;
#endif

// Connection callback and methods
- (void)setConnection:(SPMySQLConnection *)theConnection;
- (SPMySQLConnection *)getConnection;

// Database methods
- (IBAction)setDatabases:(id)sender;
#ifndef SP_CODA /* method decls */
- (IBAction)chooseDatabase:(id)sender;
#endif
- (void)selectDatabase:(NSString *)aDatabase item:(NSString *)anItem;
- (IBAction)addDatabase:(id)sender;
- (IBAction)alterDatabase:(id)sender;
- (IBAction)removeDatabase:(id)sender;
- (IBAction)refreshTables:(id)sender;
#ifndef SP_CODA /* method decls */
- (IBAction)copyDatabase:(id)sender;
#endif
- (IBAction)renameDatabase:(id)sender;
#ifndef SP_CODA /* method decls */
- (IBAction)showMySQLHelp:(id)sender;
- (IBAction)makeTableListFilterHaveFocus:(id)sender;
- (IBAction)showServerVariables:(id)sender;
- (IBAction)showServerProcesses:(id)sender;
- (IBAction)shutdownServer:(id)sender;
- (IBAction)openCurrentConnectionInNewWindow:(id)sender;
- (IBAction)showGotoDatabase:(id)sender;
#endif
- (NSArray *)allDatabaseNames;
- (NSArray *)allSystemDatabaseNames;
- (NSDictionary *)getDbStructure;
- (NSArray *)allSchemaKeys;

// Task progress and notification methods
- (void)startTaskWithDescription:(NSString *)description;
- (void)fadeInTaskProgressWindow:(NSTimer *)theTimer;
- (void)setTaskDescription:(NSString *)description;
- (void)setTaskPercentage:(CGFloat)taskPercentage;
- (void)setTaskProgressToIndeterminateAfterDelay:(BOOL)afterDelay;
- (void)endTask;
- (void)enableTaskCancellationWithTitle:(NSString *)buttonTitle callbackObject:(id)callbackObject callbackFunction:(SEL)callbackFunction;
- (void)disableTaskCancellation;
- (IBAction)cancelTask:(id)sender;
- (BOOL)isWorking;
- (void)setDatabaseListIsSelectable:(BOOL)isSelectable;
- (void)centerTaskWindow;
- (void)setTaskIndicatorShouldAnimate:(BOOL)shouldAnimate;

// Encoding methods
- (void)setConnectionEncoding:(NSString *)mysqlEncoding reloadingViews:(BOOL)reloadViews;
- (NSString *)databaseEncoding;
- (void)detectDatabaseEncoding;
- (IBAction)chooseEncoding:(id)sender;
- (BOOL)supportsEncoding;
- (void)updateEncodingMenuWithSelectedEncoding:(NSNumber *)encodingTag;
- (NSNumber *)encodingTagFromMySQLEncoding:(NSString *)mysqlEncoding;
- (NSString *)mysqlEncodingFromEncodingTag:(NSNumber *)encodingTag;
#ifndef SP_CODA /* method decls */

// Table methods
- (IBAction)showCreateTableSyntax:(id)sender;
- (IBAction)copyCreateTableSyntax:(id)sender;
- (IBAction)checkTable:(id)sender;
- (IBAction)analyzeTable:(id)sender;
- (IBAction)optimizeTable:(id)sender;
- (IBAction)repairTable:(id)sender;
- (IBAction)flushTable:(id)sender;
- (IBAction)checksumTable:(id)sender;
- (IBAction)saveCreateSyntax:(id)sender;
- (IBAction)copyCreateTableSyntaxFromSheet:(id)sender;
- (IBAction)focusOnTableContentFilter:(id)sender;
- (IBAction)showFilterTable:(id)sender;
- (IBAction)export:(id)sender;
- (IBAction)exportSelectedTablesAs:(id)sender;

// Other methods
- (IBAction)closeSheet:(id)sender;
- (IBAction)closePanelSheet:(id)sender;
- (IBAction)validateSaveConnectionAccessory:(id)sender;
- (IBAction)closePasswordSheet:(id)sender;
- (IBAction)backForwardInHistory:(id)sender;
- (IBAction)showUserManager:(id)sender;
- (IBAction)copyChecksumFromSheet:(id)sender;
- (IBAction)showNavigator:(id)sender;
- (IBAction)toggleNavigator:(id)sender;

- (void)setQueryMode:(NSInteger)theQueryMode;
- (void)doPerformQueryService:(NSString *)query;
- (void)doPerformLoadQueryService:(NSString *)query;
- (void)flushPrivileges:(id)sender;
- (void)closeConnection;
- (NSWindow *)getCreateTableSyntaxWindow;

#endif
- (void)refreshCurrentDatabase;
#ifndef SP_CODA /* method decls */

- (void)saveConnectionPanelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode  contextInfo:(void  *)contextInfo;
- (BOOL)saveDocumentWithFilePath:(NSString *)fileName inBackground:(BOOL)saveInBackground onlyPreferences:(BOOL)saveOnlyPreferences contextInfo:(NSDictionary*)contextInfo;
- (void)setIsSavedInBundle:(BOOL)savedInBundle;
- (void)setFileURL:(NSURL *)fileURL;
- (void)connect;
- (void)showConsole:(id)sender;
#endif

// Accessor methods
- (NSString *)host;
- (NSString *)name;
- (NSString *)database;
- (NSString *)port;
- (NSString *)mySQLVersion;
- (NSString *)user;
- (NSString *)connectionID;
#ifndef SP_CODA /* method decls */
- (NSString *)tabTitleForTooltip;
- (BOOL)isSaveInBundle;
- (NSURL *)fileURL;
- (NSString *)displayName;
- (NSUndoManager *)undoManager;
#endif
- (NSArray *)allTableNames;
- (SPCreateDatabaseInfo *)createDatabaseInfo;
- (SPTableViewType) currentlySelectedView;

#ifndef SP_CODA /* method decls */
// Notification center methods
- (void)willPerformQuery:(NSNotification *)notification;
- (void)hasPerformedQuery:(NSNotification *)notification;
- (void)applicationWillTerminate:(NSNotification *)notification;

// Menu methods
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;
- (IBAction)openDatabaseInNewTab:(id)sender;
- (IBAction)saveConnectionSheet:(id)sender;
- (IBAction)import:(id)sender;
- (IBAction)importFromClipboard:(id)sender;
- (IBAction)addConnectionToFavorites:(id)sender;
- (BOOL)isCustomQuerySelected;

// Titlebar methods
- (void)setStatusIconToImageWithName:(NSString *)imagePath;
- (void)setTitlebarStatus:(NSString *)status;
- (void)clearStatusIcon;
- (void)updateTitlebarStatusVisibilityForcingHide:(BOOL)forceHide;

// Toolbar methods
- (void)updateWindowTitle:(id)sender;
- (void)setupToolbar;
- (NSString *)selectedToolbarItemIdentifier;
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;
- (void)updateChooseDatabaseToolbarItemWidth;

// Tab methods
- (void)makeKeyDocument;
#endif
- (BOOL)parentTabShouldClose;
- (void)parentTabDidClose;
#ifndef SP_CODA
- (void)willResignActiveTabInWindow;
- (void)didBecomeActiveTabInWindow;
- (void)tabDidBecomeKey;
- (void)tabDidResize;
#endif

- (void)setIsProcessing:(BOOL)value;
- (BOOL)isProcessing;
- (void)setParentWindow:(NSWindow *)aWindow;
- (NSWindow *)parentWindow;

#ifndef SP_CODA /* method decls */
// Scripting
- (void)handleSchemeCommand:(NSDictionary*)commandDict;
- (void)registerActivity:(NSDictionary*)commandDict;
- (void)removeRegisteredActivity:(NSInteger)pid;
- (void)setActivityPaneHidden:(NSNumber*)hide;
- (NSArray*)runningActivities;
- (NSDictionary*)shellVariables;

// State saving and setting
- (NSDictionary *) stateIncludingDetails:(NSDictionary *)detailsToReturn;
- (BOOL)setState:(NSDictionary *)stateDetails;
- (BOOL)setState:(NSDictionary *)stateDetails fromFile:(BOOL)spfBased;
- (BOOL)setStateFromConnectionFile:(NSString *)path;
- (void)restoreSession;
#endif

- (SPConnectionController*)connectionController;

#ifdef SP_CODA /* method decls */
- (SPConnectionController*)createConnectionController;
- (void)connect;
- (void)setTableSourceInstance:(SPTableStructure*)source;
- (void)setTableContentInstance:(SPTableContent*)content;
#endif

#pragma mark - SPDatabaseViewController

// Accessors
- (NSString *)table;
- (SPTableType)tableType;

- (BOOL)structureLoaded;
- (BOOL)contentLoaded;
- (BOOL)statusLoaded;

#ifndef SP_CODA /* method decls */
// Tab view control
- (IBAction)viewStructure:(id)sender;
- (IBAction)viewContent:(id)sender;
- (IBAction)viewQuery:(id)sender;
- (IBAction)viewStatus:(id)sender;
- (IBAction)viewRelations:(id)sender;
- (IBAction)viewTriggers:(id)sender;
#endif

- (void)setStructureRequiresReload:(BOOL)reload;
- (void)setContentRequiresReload:(BOOL)reload;
- (void)setStatusRequiresReload:(BOOL)reload;
- (void)setRelationsRequiresReload:(BOOL)reload;

// Table control
- (void)loadTable:(NSString *)aTable ofType:(SPTableType)aTableType;

#ifndef SP_CODA /* method decls */
- (NSView *)databaseView;
#endif

#pragma mark - SPPrintController

- (void)startPrintDocumentOperation;
- (void)generateHTMLForPrinting;
- (void)generateTableInfoHTMLForPrinting;

- (NSArray *)columnNames;
- (NSMutableDictionary *)connectionInformation;

@end
