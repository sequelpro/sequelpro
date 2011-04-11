//
//  $Id$
//
//  SPDatabaseDocument.h
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed May 01 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//  
//  Forked by Abhi Beckert (abhibeckert.com) 2008-04-04
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import <MCPKit/MCPKit.h>
#ifndef SP_REFACTOR /* headers */
#import <WebKit/WebKit.h>
#endif

@class SPConnectionController,
#ifndef SP_REFACTOR /* class forward decls */
SPProcessListController, SPServerVariablesController, SPUserManager, SPWindowController,
#endif
SPTablesList, SPTableStructure, SPTableContent, SPTableData, SPServerSupport;

#import "SPConnectionControllerDelegateProtocol.h"

/**
 * The SPDatabaseDocument class controls the primary database view window.
 */
@interface SPDatabaseDocument : NSObject <SPConnectionControllerDelegateProtocol>
{
#ifdef SP_REFACTOR /* patch */
	id delegate;
#endif

	// IBOutlets
	SPTablesList* tablesListInstance;
	SPTableStructure* tableSourceInstance;				
	SPTableContent* tableContentInstance;
	IBOutlet id tableRelationsInstance;
	IBOutlet id tableTriggersInstance;
	IBOutlet id customQueryInstance;
	IBOutlet id tableDumpInstance;
	SPTableData* tableDataInstance;
	IBOutlet id extendedTableInfoInstance;
	IBOutlet id databaseDataInstance;
	IBOutlet id spHistoryControllerInstance;
	IBOutlet id exportControllerInstance;
	
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

	IBOutlet id queryProgressBar;
	IBOutlet NSBox *taskProgressLayer;
	IBOutlet id taskProgressIndicator;
	IBOutlet id taskDescriptionText;
	IBOutlet NSButton *taskCancelButton;

	IBOutlet id favoritesButton;

	IBOutlet id databaseNameField;
	IBOutlet id databaseEncodingButton;
	IBOutlet id addDatabaseButton;

	IBOutlet id databaseCopyNameField;
	IBOutlet id copyDatabaseDataButton;
	IBOutlet id copyDatabaseMessageField;
	IBOutlet id copyDatabaseButton;

	IBOutlet id databaseRenameNameField;
	IBOutlet id renameDatabaseMessageField;
	IBOutlet id renameDatabaseButton;

	IBOutlet id chooseDatabaseButton;
	IBOutlet id historyControl;
	IBOutlet NSTabView *tableTabView;
	
	IBOutlet NSTableView *tableInfoTable;
	IBOutlet NSButton *tableInfoCollapseButton;
	IBOutlet NSSplitView *tableListSplitter;
	IBOutlet NSSplitView *contentViewSplitter;
	IBOutlet id sidebarGrabber;
	
	IBOutlet NSPopUpButton *encodingPopUp;
	
	IBOutlet NSTextView *customQueryTextView;
	
	IBOutlet NSTableView *dbTablesTableView;

	IBOutlet NSTextField *createTableSyntaxTextField;
	IBOutlet NSTextView *createTableSyntaxTextView;
	IBOutlet NSWindow *createTableSyntaxWindow;
	IBOutlet NSWindow *connectionErrorDialog;

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
	
	// Controllers
	SPConnectionController *connectionController;
#ifndef SP_REFACTOR /* ivars */
	SPProcessListController *processListController;
	SPServerVariablesController *serverVariablesController;
#endif
	MCPConnection *mySQLConnection;
#ifndef SP_REFACTOR /* ivars */

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
#ifndef SP_REFACTOR /* ivars */
	NSUserDefaults *prefs;
	NSMutableArray *nibObjectsToRelease;
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
	
#ifndef SP_REFACTOR /* ivars */
	WebView *printWebView;
#endif
	
	NSMutableArray *allDatabases;
	NSMutableArray *allSystemDatabases;
	
	NSString *queryEditorInitString;
	
	NSURL *spfFileURL;
	NSDictionary *spfSession;
	NSMutableDictionary *spfPreferences;
	NSMutableDictionary *spfDocData;

	NSMutableArray *runningActivitiesArray;

	NSString *keyChainID;
	
#ifndef SP_REFACTOR /* ivars */
	NSThread *printThread;
	
	id statusValues;

	NSInteger saveDocPrefSheetStatus;

	// Properties
	SPWindowController *parentWindowController;
	NSWindow *parentWindow;
	NSTabViewItem *parentTabViewItem;
#endif
	BOOL isProcessing;
#ifndef SP_REFACTOR /* ivars */
	NSString *processID;
#endif
}

#ifdef SP_REFACTOR /* ivars */
@property (readwrite, assign) id delegate;
@property (readonly) NSMutableArray* allDatabases;
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

#ifndef SP_REFACTOR /* method decls */
- (BOOL)isUntitled;
- (BOOL)couldCommitCurrentViewActions;

- (void)initQueryEditorWithString:(NSString *)query;

// Connection callback and methods
#endif
- (void)setConnection:(MCPConnection *)theConnection;
- (MCPConnection *)getConnection;
- (void)setKeychainID:(NSString *)theID;

// Database methods
- (IBAction)setDatabases:(id)sender;
#ifndef SP_REFACTOR /* method decls */
- (IBAction)chooseDatabase:(id)sender;
#endif
- (void)selectDatabase:(NSString *)aDatabase item:(NSString *)anItem;
#ifndef SP_REFACTOR /* method decls */
- (IBAction)addDatabase:(id)sender;
- (IBAction)removeDatabase:(id)sender;
- (IBAction)refreshTables:(id)sender;
- (IBAction)copyDatabase:(id)sender;
- (IBAction)renameDatabase:(id)sender;
- (IBAction)showMySQLHelp:(id)sender;
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
- (IBAction)focusOnTableListFilter:(id)sender;
- (IBAction)export:(id)sender;

- (IBAction)exportSelectedTablesAs:(id)sender;

// Other methods
- (void) setQueryMode:(NSInteger)theQueryMode;
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
- (NSString *)tabTitleForTooltip;
- (BOOL)isSaveInBundle;
- (NSURL *)fileURL;
- (NSString *)displayName;
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

// Toolbar methods
- (void)updateWindowTitle:(id)sender;
- (void)setupToolbar;
- (NSString *)selectedToolbarItemIdentifier;
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;
- (void)updateChooseDatabaseToolbarItemWidth;

// Tab methods
- (void)makeKeyDocument;
- (BOOL)parentTabShouldClose;
- (void)parentTabDidClose;
- (void)willResignActiveTabInWindow;
- (void)didBecomeActiveTabInWindow;
- (void)tabDidBecomeKey;
- (void)tabDidResize;
#endif

- (void)setIsProcessing:(BOOL)value;
- (BOOL)isProcessing;
#ifndef SP_REFACTOR /* method decls */
- (void)setParentWindow:(NSWindow *)aWindow;
- (NSWindow *)parentWindow;

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
- (void)setStateFromConnectionFile:(NSString *)path;
- (void)restoreSession;
#endif

#ifdef SP_REFACTOR /* method decls */
- (SPConnectionController*)createConnectionController;
- (void)connect;
- (NSArray*)allTableNames;
- (SPTablesList*)tablesListInstance;
- (SPTableData*)tableDataInstance;
- (void)setTableSourceInstance:(SPTableStructure*)source;
- (void)setTableContentInstance:(SPTableContent*)content;
- (void)setTableDataInstance:(SPTableData*)data;
#endif

@end
