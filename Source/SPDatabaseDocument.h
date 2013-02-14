//
//  $Id$
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
//  More info at <http://code.google.com/p/sequel-pro/>

#ifndef SP_REFACTOR /* headers */
#import <WebKit/WebKit.h>
#endif

@class SPConnectionController;

#ifdef SP_REFACTOR 
@class BottomBarSegmentedControl;
#else
@class SPProcessListController;
@class SPServerVariablesController;
@class SPUserManager;
@class SPWindowController;
@class SPSplitView;
#endif

@class SPDatabaseData;
@class SPTablesList;
@class SPTableStructure;
@class SPTableContent;
@class SPTableData;
@class SPServerSupport;
@class SPCustomQuery;
@class SPDatabaseStructure;
@class SPMySQLConnection;

#import "SPConnectionControllerDelegateProtocol.h"

#import <SPMySQL/SPMySQLConnectionDelegate.h>

/**
 * The SPDatabaseDocument class controls the primary database view window.
 */
@interface SPDatabaseDocument : NSObject <SPConnectionControllerDelegateProtocol, SPMySQLConnectionDelegate, NSTextFieldDelegate, NSToolbarDelegate>
{
#ifdef SP_REFACTOR /* patch */
	id delegate;
#endif

	// IBOutlets
	IBOutlet SPTablesList* tablesListInstance;
	IBOutlet SPTableStructure* tableSourceInstance;				
	IBOutlet SPTableContent* tableContentInstance;
	IBOutlet id tableRelationsInstance;
	IBOutlet id tableTriggersInstance;
	IBOutlet id customQueryInstance;
	IBOutlet id tableDumpInstance;
	IBOutlet SPTableData* tableDataInstance;
	IBOutlet id extendedTableInfoInstance;
	IBOutlet id databaseDataInstance;
#ifndef SP_REFACTOR
	IBOutlet id spHistoryControllerInstance;
	IBOutlet id exportControllerInstance;
#endif
	
	IBOutlet id statusTableAccessoryView;
	IBOutlet id statusTableView;
	IBOutlet id statusTableCopyChecksum;
	
#ifndef SP_REFACTOR /* ivars */
    SPUserManager *userManagerInstance;
#endif
	SPServerSupport *serverSupport;
	
	IBOutlet NSSearchField *listFilterField;

	IBOutlet NSScrollView *tableInfoScrollView;
	IBOutlet NSScrollView *documentActivityScrollView;

	IBOutlet NSView *parentView;
	
	IBOutlet id titleAccessoryView;
	IBOutlet id titleImageView;
	IBOutlet id titleStringView;
	
	IBOutlet id databaseSheet;
	IBOutlet id databaseCopySheet;
	IBOutlet id databaseRenameSheet;

	IBOutlet NSProgressIndicator* queryProgressBar;
#ifndef SP_REFACTOR
	IBOutlet NSBox *taskProgressLayer;
	IBOutlet id taskProgressIndicator;
	IBOutlet id taskDescriptionText;
	IBOutlet NSButton *taskCancelButton;

	IBOutlet id favoritesButton;
#endif

	IBOutlet id databaseNameField;
	IBOutlet id databaseEncodingButton;
	IBOutlet id addDatabaseButton;

#ifndef SP_REFACTOR
	IBOutlet id databaseCopyNameField;
	IBOutlet NSButton *copyDatabaseDataButton;
	IBOutlet id copyDatabaseMessageField;
	IBOutlet id copyDatabaseButton;
#endif

	IBOutlet id databaseRenameNameField;
	IBOutlet id renameDatabaseMessageField;
	IBOutlet id renameDatabaseButton;

	IBOutlet id chooseDatabaseButton;
#ifndef SP_REFACTOR
	IBOutlet id historyControl;
	IBOutlet NSTabView *tableTabView;
	
	IBOutlet NSTableView *tableInfoTable;
	IBOutlet SPSplitView *contentViewSplitter;
	
	IBOutlet NSPopUpButton *encodingPopUp;
#endif
	
	IBOutlet NSTextView *customQueryTextView;
	
	IBOutlet NSTableView *dbTablesTableView;

	IBOutlet NSTextField *createTableSyntaxTextField;
	IBOutlet NSTextView *createTableSyntaxTextView;
	IBOutlet NSWindow *createTableSyntaxWindow;
	IBOutlet NSWindow *connectionErrorDialog;

#ifndef SP_REFACTOR
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
#ifndef SP_REFACTOR /* ivars */
	SPProcessListController *processListController;
	SPServerVariablesController *serverVariablesController;

	NSInteger currentTabIndex;
#endif
	NSString *selectedTableName;
	SPTableType selectedTableType;

	BOOL structureLoaded;
	BOOL contentLoaded;
	BOOL statusLoaded;
	BOOL triggersLoaded;

	NSString *selectedDatabase;
	NSString *mySQLVersion;
	NSString *selectedDatabaseEncoding;
#ifndef SP_REFACTOR /* ivars */
	NSUserDefaults *prefs;
	NSMutableArray *nibObjectsToRelease;
	NSUndoManager *undoManager;
#endif

	NSMenu *selectEncodingMenu;
	BOOL _supportsEncoding;
	BOOL _isConnected;
	NSInteger _isWorkingLevel;
#ifndef SP_REFACTOR /* ivars */
	BOOL _mainNibLoaded;
#endif
	BOOL databaseListIsSelectable;
	NSInteger _queryMode;
	BOOL _isSavedInBundle;

	BOOL _workingTimeout;

#ifndef SP_REFACTOR
	NSWindow *taskProgressWindow;
	BOOL taskDisplayIsIndeterminate;
	CGFloat taskProgressValue;
	CGFloat taskDisplayLastValue;
	CGFloat taskProgressValueDisplayInterval;
	NSTimer *taskDrawTimer;
	NSDate *taskFadeInStartDate;
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
	
#ifndef SP_REFACTOR /* ivars */
	NSURL *spfFileURL;
	NSDictionary *spfSession;
	NSMutableDictionary *spfPreferences;
	NSMutableDictionary *spfDocData;

	NSMutableArray *runningActivitiesArray;
#endif

	NSString *keyChainID;
	
#ifndef SP_REFACTOR /* ivars */
	NSThread *printThread;
	
	NSArray *statusValues;

	NSInteger saveDocPrefSheetStatus;

	// Properties
	SPWindowController *parentWindowController;
#endif
	NSWindow *parentWindow;
#ifndef SP_REFACTOR /* ivars */
	NSTabViewItem *parentTabViewItem;
#endif
	BOOL isProcessing;
#ifndef SP_REFACTOR /* ivars */
	NSString *processID;
	BOOL windowTitleStatusViewIsVisible;
#endif
	SPDatabaseStructure *databaseStructureRetrieval;
}

#ifdef SP_REFACTOR /* ivars */
@property (assign) SPDatabaseData* databaseDataInstance;
@property (assign) SPTableData* tableDataInstance;
@property (assign) SPCustomQuery* customQueryInstance;
@property (assign) BottomBarSegmentedControl* structureContentSwitcher;

@property (assign) id databaseNameField;
@property (assign) id databaseEncodingButton;
@property (assign) id addDatabaseButton;
@property (assign) id chooseDatabaseButton;

@property (assign) id databaseRenameNameField;
@property (assign) id renameDatabaseButton;
@property (assign) id databaseRenameSheet;
#endif

#ifdef SP_REFACTOR /* ivars */
@property (assign) id delegate;
@property (readonly) NSMutableArray* allDatabases;
@property (assign) NSProgressIndicator* queryProgressBar;
@property (assign) NSWindow* databaseSheet;
#endif

#ifndef SP_REFACTOR /* ivars */
@property (readwrite, assign) SPWindowController *parentWindowController;
@property (readwrite, assign) NSTabViewItem *parentTabViewItem;
#endif
@property (readwrite, assign) BOOL isProcessing;
#ifndef SP_REFACTOR /* ivars */
@property (readwrite, retain) NSString *processID;
#endif
@property (readonly) SPServerSupport *serverSupport;
@property (readonly) SPDatabaseStructure *databaseStructureRetrieval;

#ifndef SP_REFACTOR /* method decls */
- (BOOL)isUntitled;
#endif
- (BOOL)couldCommitCurrentViewActions;

#ifndef SP_REFACTOR /* method decls */
- (void)initQueryEditorWithString:(NSString *)query;

// Connection callback and methods
#endif
- (void)setConnection:(SPMySQLConnection *)theConnection;
- (SPMySQLConnection *)getConnection;
- (void)setKeychainID:(NSString *)theID;

// Database methods
- (IBAction)setDatabases:(id)sender;
#ifndef SP_REFACTOR /* method decls */
- (IBAction)chooseDatabase:(id)sender;
#endif
- (void)selectDatabase:(NSString *)aDatabase item:(NSString *)anItem;
- (IBAction)addDatabase:(id)sender;
- (IBAction)removeDatabase:(id)sender;
- (IBAction)refreshTables:(id)sender;
#ifndef SP_REFACTOR /* method decls */
- (IBAction)copyDatabase:(id)sender;
#endif
- (IBAction)renameDatabase:(id)sender;
#ifndef SP_REFACTOR /* method decls */
- (IBAction)showMySQLHelp:(id)sender;
- (IBAction) makeTableListFilterHaveFocus:(id)sender;
- (IBAction)showServerVariables:(id)sender;
- (IBAction)showServerProcesses:(id)sender;
- (IBAction)openCurrentConnectionInNewWindow:(id)sender;
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
#ifndef SP_REFACTOR /* method decls */

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
- (void)setQueryMode:(NSInteger)theQueryMode;
- (IBAction)closeSheet:(id)sender;
- (IBAction)closePanelSheet:(id)sender;
- (void)doPerformQueryService:(NSString *)query;
- (void)doPerformLoadQueryService:(NSString *)query;
- (void)flushPrivileges:(id)sender;
- (void)closeConnection;
- (NSWindow *)getCreateTableSyntaxWindow;
#endif
- (void)refreshCurrentDatabase;
#ifndef SP_REFACTOR /* method decls */
- (void)saveConnectionPanelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode  contextInfo:(void  *)contextInfo;
- (IBAction)validateSaveConnectionAccessory:(id)sender;
- (BOOL)saveDocumentWithFilePath:(NSString *)fileName inBackground:(BOOL)saveInBackground onlyPreferences:(BOOL)saveOnlyPreferences contextInfo:(NSDictionary*)contextInfo;
- (IBAction)closePasswordSheet:(id)sender;
- (IBAction)backForwardInHistory:(id)sender;
- (IBAction)showUserManager:(id)sender;
- (void)userManagerSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void*)context;
- (IBAction)copyChecksumFromSheet:(id)sender;
- (void)setIsSavedInBundle:(BOOL)savedInBundle;
- (void)setFileURL:(NSURL *)fileURL;
- (void)connect;
- (void)showConsole:(id)sender;
- (IBAction)showNavigator:(id)sender;
- (IBAction)toggleNavigator:(id)sender;
#endif

// Accessor methods
- (NSString *)host;
- (NSString *)name;
- (NSString *)database;
- (NSString *)port;
- (NSString *)mySQLVersion;
- (NSString *)user;
- (NSString *)keyChainID;
- (NSString *)connectionID;
#ifndef SP_REFACTOR /* method decls */
- (NSString *)tabTitleForTooltip;
- (BOOL)isSaveInBundle;
- (NSURL *)fileURL;
- (NSString *)displayName;
- (NSUndoManager *)undoManager;
#endif
- (NSArray *)allTableNames;
- (SPTablesList *)tablesListInstance;

#ifndef SP_REFACTOR /* method decls */
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
#ifndef SP_REFACTOR
- (void)willResignActiveTabInWindow;
- (void)didBecomeActiveTabInWindow;
- (void)tabDidBecomeKey;
- (void)tabDidResize;
#endif

- (void)setIsProcessing:(BOOL)value;
- (BOOL)isProcessing;
- (void)setParentWindow:(NSWindow *)aWindow;
- (NSWindow *)parentWindow;

#ifndef SP_REFACTOR /* method decls */
// Scripting
- (void)handleSchemeCommand:(NSDictionary*)commandDict;
- (void)registerActivity:(NSDictionary*)commandDict;
- (void)removeRegisteredActivity:(NSInteger)pid;
- (void)setActivityPaneHidden:(NSNumber*)hide;
- (NSArray*)runningActivities;
- (NSDictionary*)shellVariables;

// State saving and setting
- (NSDictionary *)stateIncludingDetails:(NSDictionary *)detailsToReturn;
- (BOOL)setState:(NSDictionary *)stateDetails;
- (BOOL)setStateFromConnectionFile:(NSString *)path;
- (void)restoreSession;
#endif

#ifdef SP_REFACTOR /* method decls */
- (SPConnectionController*)createConnectionController;
- (SPConnectionController*)connectionController;
- (void)connect;
- (void)setTableSourceInstance:(SPTableStructure*)source;
- (void)setTableContentInstance:(SPTableContent*)content;

#endif

@end
