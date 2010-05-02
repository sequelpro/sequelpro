//
//  $Id$
//
//  TableDocument.h
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

#import <Cocoa/Cocoa.h>
#import <MCPKit/MCPKit.h>
#import <WebKit/WebKit.h>

@class SPConnectionController, SPProcessListController, SPServerVariablesController, SPUserManager;

/**
 * The TableDocument class controls the primary database view window.
 */
@interface TableDocument : NSDocument
{
	// IBOutlets
	IBOutlet id tablesListInstance;
	IBOutlet id tableSourceInstance;
	IBOutlet id tableContentInstance;
	IBOutlet id tableRelationsInstance;
	IBOutlet id tableTriggersInstance;
	IBOutlet id customQueryInstance;
	IBOutlet id tableDumpInstance;
	IBOutlet id tableDataInstance;
	IBOutlet id extendedTableInfoInstance;
	IBOutlet id databaseDataInstance;
	IBOutlet id spHistoryControllerInstance;
	IBOutlet id exportControllerInstance;
	
	IBOutlet id statusTableAccessoryView;
	IBOutlet id statusTableView;
	IBOutlet id statusTableCopyChecksum;
	
	IBOutlet SPUserManager *userManagerInstance;
	
	IBOutlet NSSearchField *listFilterField;

	IBOutlet NSWindow *tableWindow;
	
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
	IBOutlet id saveConnectionIncludeData;
	IBOutlet id saveConnectionIncludeQuery;
	IBOutlet id saveConnectionSavePassword;
	IBOutlet id saveConnectionSavePasswordAlert;
	IBOutlet id saveConnectionEncrypt;
	IBOutlet id saveConnectionAutoConnect;
	IBOutlet NSSecureTextField *saveConnectionEncryptString;
	
	IBOutlet id inputTextWindow;
	IBOutlet id inputTextWindowHeader;
	IBOutlet id inputTextWindowMessage;
	IBOutlet id inputTextWindowSecureTextField;
	NSInteger passwordSheetReturnCode;
	
	// Controllers
	SPConnectionController *connectionController;
	SPProcessListController *processListController;
	SPServerVariablesController *serverVariablesController;
	
	MCPConnection *mySQLConnection;

	NSString *selectedDatabase;
	NSString *mySQLVersion;
	NSUserDefaults *prefs;

	NSMenu *selectEncodingMenu;
	BOOL _supportsEncoding;
	NSString *_encoding;
	BOOL _encodingViaLatin1;
	BOOL _shouldOpenConnectionAutomatically;
	BOOL _isConnected;
	NSInteger _isWorkingLevel;
	BOOL _mainNibLoaded;
	BOOL databaseListIsSelectable;
	NSInteger _queryMode;

	NSWindow *taskProgressWindow;
	BOOL taskDisplayIsIndeterminate;
	CGFloat taskProgressValue;
	CGFloat taskDisplayLastValue;
	CGFloat taskProgressValueDisplayInterval;
	NSTimer *taskDrawTimer;
	NSViewAnimation *taskFadeAnimator;
	BOOL taskCanBeCancelled;
	id taskCancellationCallbackObject;
	SEL taskCancellationCallbackSelector;

	NSToolbar *mainToolbar;
	NSToolbarItem *chooseDatabaseToolbarItem;
	
	WebView *printWebView;
	
	NSMutableArray *allDatabases;
	NSMutableArray *allSystemDatabases;
	
	NSString *queryEditorInitString;
	
	NSDictionary *spfSession;
	NSMutableDictionary *spfPreferences;
	NSMutableDictionary *spfDocData;
	
	NSString *keyChainID;
	
	NSThread *printThread;
	
	id statusValues;
}

- (BOOL)isUntitled;
- (BOOL)couldCommitCurrentViewActions;

- (void)initQueryEditorWithString:(NSString *)query;
- (void)initWithConnectionFile:(NSString *)path;
// Connection callback and methods
- (void)setConnection:(MCPConnection *)theConnection;
- (MCPConnection *) getConnection;
- (void)setShouldAutomaticallyConnect:(BOOL)shouldAutomaticallyConnect;
- (BOOL)shouldAutomaticallyConnect;
- (void)setKeychainID:(NSString *)theID;

// Database methods
- (IBAction)setDatabases:(id)sender;
- (IBAction)chooseDatabase:(id)sender;
- (void)selectDatabase:(NSString *)aDatabase item:(NSString *)anItem;
- (IBAction)addDatabase:(id)sender;
- (IBAction)removeDatabase:(id)sender;
- (IBAction)copyDatabase:(id)sender;
- (IBAction)renameDatabase:(id)sender;
- (IBAction)showMySQLHelp:(id)sender;
- (IBAction)showServerVariables:(id)sender;
- (IBAction)showServerProcesses:(id)sender;
- (IBAction)openCurrentConnectionInNewWindow:(id)sender;
- (NSArray *)allDatabaseNames;
- (NSArray *)allSystemDatabaseNames;
- (BOOL)navigatorSchemaPathExistsForDatabase:(NSString*)dbname;
- (NSDictionary *)getDbStructure;
- (NSArray *)allSchemaKeys;

// Task progress and notification methods
- (void)startTaskWithDescription:(NSString *)description;
- (void)showTaskProgressWindow:(NSTimer *)theTimer;
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

// Encoding methods
- (void)setConnectionEncoding:(NSString *)mysqlEncoding reloadingViews:(BOOL)reloadViews;
- (NSString *)databaseEncoding;
- (NSString *)connectionEncoding;
- (BOOL)connectionEncodingViaLatin1:(id)connection;
- (IBAction)chooseEncoding:(id)sender;
- (BOOL)supportsEncoding;
- (void)updateEncodingMenuWithSelectedEncoding:(NSString *)encoding;
- (NSString *)encodingNameFromMySQLEncoding:(NSString *)mysqlEncoding;
- (NSString *)mysqlEncodingFromDisplayEncoding:(NSString *)encodingName;

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
- (void)refreshCurrentDatabase;
- (void)saveConnectionPanelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode  contextInfo:(void  *)contextInfo;
- (IBAction)validateSaveConnectionAccessory:(id)sender;
- (BOOL)saveDocumentWithFilePath:(NSString *)fileName inBackground:(BOOL)saveInBackground onlyPreferences:(BOOL)saveOnlyPreferences;
- (IBAction)closePasswordSheet:(id)sender;
- (IBAction)backForwardInHistory:(id)sender;
- (IBAction)showUserManager:(id)sender;
- (IBAction)copyChecksumFromSheet:(id)sender;

- (void)showConsole:(id)sender;
- (IBAction)showNavigator:(id)sender;
- (IBAction)toggleNavigator:(id)sender;

// Accessor methods
- (NSString *)host;
- (NSString *)name;
- (NSString *)database;
- (NSString *)table;
- (NSString *)port;
- (NSString *)mySQLVersion;
- (NSString *)user;
- (NSString *)displaySPName;
- (NSString *)keyChainID;
- (NSString *)connectionID;

// Notification center methods
- (void)willPerformQuery:(NSNotification *)notification;
- (void)hasPerformedQuery:(NSNotification *)notification;
- (void)applicationWillTerminate:(NSNotification *)notification;

// Menu methods
- (BOOL)validateMenuItem:(NSMenuItem *)anItem;
- (IBAction)saveConnectionSheet:(id)sender;
- (IBAction)import:(id)sender;
- (IBAction)importFromClipboard:(id)sender;
- (IBAction)export:(id)sender;
- (IBAction)exportTable:(id)sender;
- (IBAction)exportMultipleTables:(id)sender;
- (IBAction)viewStructure:(id)sender;
- (IBAction)viewContent:(id)sender;
- (IBAction)viewQuery:(id)sender;
- (IBAction)viewStatus:(id)sender;
- (IBAction)viewRelations:(id)sender;
- (IBAction)viewTriggers:(id)sender;
- (IBAction)addConnectionToFavorites:(id)sender;

// Titlebar methods
- (void)setStatusIconToImageWithName:(NSString *)imagePath;
- (void)setTitlebarStatus:(NSString *)status;
- (void)clearStatusIcon;

// Toolbar methods
- (void)setupToolbar;
- (NSString *)selectedToolbarItemIdentifier;
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;
- (void)updateChooseDatabaseToolbarItemWidth;

@end
