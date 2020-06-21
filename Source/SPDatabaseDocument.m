//
//  SPDatabaseDocument.m
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

#import "SPDatabaseDocument.h"
#import "SPConnectionController.h"
#import "SPTablesList.h"
#import "SPDatabaseStructure.h"
#import "SPFileHandle.h"
#import "SPKeychain.h"
#import "SPTableContent.h"
#import "SPCustomQuery.h"
#import "SPDataImport.h"
#import "ImageAndTextCell.h"
#import "SPGrowlController.h"
#import "SPExportController.h"
#import "SPSplitView.h"
#import "SPQueryController.h"
#import "SPWindowController.h"
#import "SPNavigatorController.h"
#import "SPSQLParser.h"
#import "SPTableData.h"
#import "SPDatabaseData.h"
#import "SPExtendedTableInfo.h"
#import "SPHistoryController.h"
#import "SPPreferenceController.h"
#import "SPUserManager.h"
#import "SPEncodingPopupAccessory.h"
#import "YRKSpinningProgressIndicator.h"
#import "SPProcessListController.h"
#import "SPServerVariablesController.h"
#import "SPAlertSheets.h"
#import "SPLogger.h"
#import "SPDatabaseCopy.h"
#import "SPTableCopy.h"
#import "SPDatabaseRename.h"
#import "SPTableRelations.h"
#import "SPCopyTable.h"
#import "SPServerSupport.h"
#import "SPTooltip.h"
#import "SPThreadAdditions.h"
#import "RegexKitLite.h"
#import "SPTextView.h"
#import "SPFavoriteColorSupport.h"
#import "SPCharsetCollationHelper.h"
#import "SPGotoDatabaseController.h"
#import "SPFunctions.h"
#import "SPCreateDatabaseInfo.h"
#import "SPAppController.h"
#import "SPBundleHTMLOutputController.h"
#import "SPTableTriggers.h"
#import "SPTableStructure.h"
#import "SPPrintAccessory.h"
#import "MGTemplateEngine.h"
#import "ICUTemplateMatcher.h"
#import "SPFavoritesOutlineView.h"
#import "SPSSHTunnel.h"
#import "SPHelpViewerClient.h"
#import "SPHelpViewerController.h"

#import <SPMySQL/SPMySQL.h>

#include <libkern/OSAtomic.h>

// Constants
static NSString *SPCopyDatabaseAction = @"SPCopyDatabase";
static NSString *SPConfirmCopyDatabaseAction = @"SPConfirmCopyDatabase";
static NSString *SPRenameDatabaseAction = @"SPRenameDatabase";
static NSString *SPAlterDatabaseAction = @"SPAlterDatabase";
static NSString *SPSaveDocumentPreferences = @"SPSaveDocumentPreferences";
static NSString *SPNewDatabaseDetails = @"SPNewDatabaseDetails";
static NSString *SPNewDatabaseName = @"SPNewDatabaseName";
static NSString *SPNewDatabaseCopyContent = @"SPNewDatabaseCopyContent";

static int64_t SPDatabaseDocumentInstanceCounter = 0;
static BOOL isOSAtLeast10_14;

@interface SPDatabaseDocument ()

- (void)_addDatabase;
- (void)_alterDatabase;
- (void)_copyDatabase;
- (void)_renameDatabase;
- (void)_removeDatabase;
- (void)_selectDatabaseAndItem:(NSDictionary *)selectionDetails;
- (void)_processDatabaseChangedBundleTriggerActions;
- (void)_addPreferenceObservers;
- (void)_removePreferenceObservers;


#pragma mark - SPDatabaseViewControllerPrivateAPI

- (void)_loadTabTask:(NSNumber *)tabViewItemIndexNumber;
- (void)_loadTableTask;

#pragma mark - SPConnectionDelegate

- (void) closeAndDisconnect;

- (NSString *)keychainPasswordForConnection:(SPMySQLConnection *)connection;
- (NSString *)keychainPasswordForSSHConnection:(SPMySQLConnection *)connection;

@end

@implementation SPDatabaseDocument

@synthesize sqlFileURL;
@synthesize sqlFileEncoding;
@synthesize parentWindowController;
@synthesize parentTabViewItem;
@synthesize isProcessing;
@synthesize serverSupport;
@synthesize databaseStructureRetrieval;
@synthesize processID;
@synthesize instanceId;
@synthesize dbTablesTableView;
@synthesize tableDumpInstance;
@synthesize tablesListInstance;
@synthesize tableContentInstance;
@synthesize customQueryInstance;

#pragma mark -

+ (void)initialize {
	isOSAtLeast10_14 = [SPOSInfo isOSVersionAtLeastMajor:10 minor:14 patch:0];
}

- (id)init
{
	if ((self = [super init])) {
		instanceId = OSAtomicIncrement64(&SPDatabaseDocumentInstanceCounter);
#ifndef SP_CODA /* init ivars */

		_mainNibLoaded = NO;
#endif
		_isConnected = NO;
		_isWorkingLevel = 0;
		_isSavedInBundle = NO;
		_supportsEncoding = NO;
		databaseListIsSelectable = YES;
		_queryMode = SPInterfaceQueryMode;

		chooseDatabaseButton = nil;
#ifndef SP_CODA /* init ivars */
		chooseDatabaseToolbarItem = nil;
#endif
		connectionController = nil;

		selectedTableName = nil;
		selectedTableType = SPTableTypeNone;

		structureLoaded = NO;
		contentLoaded = NO;
		statusLoaded = NO;
		triggersLoaded = NO;
		relationsLoaded = NO;

		selectedDatabase = nil;
		selectedDatabaseEncoding = [[NSString alloc] initWithString:@"latin1"];
		mySQLConnection = nil;
		mySQLVersion = nil;
		allDatabases = nil;
		allSystemDatabases = nil;
		gotoDatabaseController = nil;

#ifndef SP_CODA /* init ivars */
		mainToolbar = nil;
		parentWindow = nil;
#endif
		isProcessing = NO;

#ifndef SP_CODA /* init ivars */
		printWebView = [[WebView alloc] init];
		[printWebView setFrameLoadDelegate:self];

		prefs = [NSUserDefaults standardUserDefaults];
		undoManager = [[NSUndoManager alloc] init];
#endif
		queryEditorInitString = nil;

#ifndef SP_CODA
		sqlFileURL = nil;
		spfFileURL = nil;
		spfSession = nil;
		spfPreferences = [[NSMutableDictionary alloc] init];
		spfDocData = [[NSMutableDictionary alloc] init];
		runningActivitiesArray = [[NSMutableArray alloc] init];
#endif

		titleAccessoryView = nil;

#ifndef SP_CODA /* init ivars */
		taskProgressWindow = nil;
		taskDisplayIsIndeterminate = YES;
		taskDisplayLastValue = 0;
		taskProgressValue = 0;
		taskProgressValueDisplayInterval = 1;
		taskDrawTimer = nil;
		taskFadeInStartDate = nil;
		taskCanBeCancelled = NO;
		taskCancellationCallbackObject = nil;
		taskCancellationCallbackSelector = NULL;
#endif
		alterDatabaseCharsetHelper = nil; //init in awakeFromNib
		addDatabaseCharsetHelper = nil;
		
#ifndef SP_CODA /* init ivars */
		statusValues = nil;
		printThread = nil;
		windowTitleStatusViewIsVisible = NO;
		nibObjectsToRelease = [[NSMutableArray alloc] init];

		// As this object is not an NSWindowController subclass, top-level objects in loaded nibs aren't
		// automatically released.  Keep track of the top-level objects for release on dealloc.
		NSArray *dbViewTopLevelObjects = nil;
		NSNib *nibLoader = [[NSNib alloc] initWithNibNamed:@"DBView" bundle:[NSBundle mainBundle]];
		[nibLoader instantiateNibWithOwner:self topLevelObjects:&dbViewTopLevelObjects];
		[nibLoader release];
		[nibObjectsToRelease addObjectsFromArray:dbViewTopLevelObjects];
#endif

		databaseStructureRetrieval = [[SPDatabaseStructure alloc] initWithDelegate:self];
	}
	
	return self;
}

- (void)awakeFromNib
{
	if (_mainNibLoaded) return;

	_mainNibLoaded = YES;
	
	// This one is a bit tricky: The chooseDatabaseButton is only retained
	// by its superview which is kept in "nibObjectsToRelease". However once
	// we pass the button to the NSToolbarItem with setView: the toolbar item
	// will take over the ownership as its new superview.
	//   That would mean if the toolbar item is removed from the toolbar, it
	// will be dealloc'd and so will the chooseDatabaseButton, causing havoc.
	//   The correct thing to do would be to create a new instance for each
	// call by the toolbar, but right now the other code relies on the
	// popup being a "singleton".
	[chooseDatabaseButton retain];
	[historyControl retain];
	
	// Set up the toolbar
	[self setupToolbar];

	// Set collapsible behaviour on the table list so collapsing behaviour handles resize issus
	[contentViewSplitter setCollapsibleSubviewIndex:0];
	
	// Set a minimum size on both text views on the table info page
	[tableInfoSplitView setMinSize:20 ofSubviewAtIndex:0];
	[tableInfoSplitView setMinSize:20 ofSubviewAtIndex:1];

	// Set up the connection controller
	connectionController = [[SPConnectionController alloc] initWithDocument:self];

	// Set the connection controller's delegate
	[connectionController setDelegate:self];

	// Register preference observers to allow live UI-linked preference changes
	[self _addPreferenceObservers];

	// Register for notifications
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(willPerformQuery:)
	                                             name:@"SMySQLQueryWillBePerformed"
	                                           object:self];

	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(hasPerformedQuery:)
	                                             name:@"SMySQLQueryHasBeenPerformed"
	                                           object:self];

	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(applicationWillTerminate:)
	                                             name:@"NSApplicationWillTerminateNotification"
	                                           object:nil];

#ifndef SP_CODA
	// Find the Database -> Database Encoding menu (it's not in our nib, so we can't use interface builder)
	selectEncodingMenu = [[[[[NSApp mainMenu] itemWithTag:SPMainMenuDatabase] submenu] itemWithTag:1] submenu];

	// Hide the tabs in the tab view (we only show them to allow switching tabs in interface builder)
	[tableTabView setTabViewType:NSNoTabsNoBorder];

	// Hide the activity list
	[self setActivityPaneHidden:@1];

	// Load additional nibs, keeping track of the top-level objects to allow correct release
	NSArray *connectionDialogTopLevelObjects = nil;
	NSNib *nibLoader = [[NSNib alloc] initWithNibNamed:@"ConnectionErrorDialog" bundle:[NSBundle mainBundle]];
	if (![nibLoader instantiateNibWithOwner:self topLevelObjects:&connectionDialogTopLevelObjects]) {
		NSLog(@"Connection error dialog could not be loaded; connection failure handling will not function correctly.");
	} else {
		[nibObjectsToRelease addObjectsFromArray:connectionDialogTopLevelObjects];
	}
	[nibLoader release];

	// SP_CODA can't use progress indicator because of BWToolkit dependency

	NSArray *progressIndicatorLayerTopLevelObjects = nil;
	nibLoader = [[NSNib alloc] initWithNibNamed:@"ProgressIndicatorLayer" bundle:[NSBundle mainBundle]];
	if (![nibLoader instantiateNibWithOwner:self topLevelObjects:&progressIndicatorLayerTopLevelObjects]) {
		NSLog(@"Progress indicator layer could not be loaded; progress display will not function correctly.");
	} else {
		[nibObjectsToRelease addObjectsFromArray:progressIndicatorLayerTopLevelObjects];
	}
	[nibLoader release];

	// Retain the icon accessory view to allow it to be added and removed from windows
	[titleAccessoryView retain];
#endif

#ifndef SP_CODA
	// Set up the progress indicator child window and layer - change indicator color and size
	[taskProgressIndicator setForeColor:[NSColor whiteColor]];
	NSShadow *progressIndicatorShadow = [[NSShadow alloc] init];
	[progressIndicatorShadow setShadowOffset:NSMakeSize(1.0f, -1.0f)];
	[progressIndicatorShadow setShadowBlurRadius:1.0f];
	[progressIndicatorShadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0f alpha:0.75f]];
	[taskProgressIndicator setShadow:progressIndicatorShadow];
	[progressIndicatorShadow release];
	taskProgressWindow = [[NSWindow alloc] initWithContentRect:[taskProgressLayer bounds] styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
	[taskProgressWindow setReleasedWhenClosed:NO];
	[taskProgressWindow setOpaque:NO];
	[taskProgressWindow setBackgroundColor:[NSColor clearColor]];
	[taskProgressWindow setAlphaValue:0.0f];
	[taskProgressWindow setContentView:taskProgressLayer];

	[self updateTitlebarStatusVisibilityForcingHide:NO];
#endif

	alterDatabaseCharsetHelper = [[SPCharsetCollationHelper alloc] initWithCharsetButton:databaseAlterEncodingButton CollationButton:databaseAlterCollationButton];
	addDatabaseCharsetHelper   = [[SPCharsetCollationHelper alloc] initWithCharsetButton:databaseEncodingButton CollationButton:databaseCollationButton];
}

#pragma mark -

#ifdef SP_CODA /* glue */
- (SPConnectionController*)createConnectionController
{
	// Set up the connection controller
	connectionController = [[SPConnectionController alloc] initWithDocument:self];
	
	// Set the connection controller's delegate
	[connectionController setDelegate:self];
	
	return connectionController;
}

- (void)setTableSourceInstance:(SPTableStructure*)source
{
	tableSourceInstance = source;
}

- (void)setTableContentInstance:(SPTableContent*)content
{
	tableContentInstance = content;
}

#endif

#ifndef SP_CODA /* password sheet and history navigation */
/**
 * Set the return code for entering the encryption passowrd sheet
 */
- (IBAction)closePasswordSheet:(id)sender
{
	passwordSheetReturnCode = 0;
	if([sender tag]) {
		[NSApp stopModal];
		passwordSheetReturnCode = 1;
	}
	[NSApp abortModal];
}

/**
 * Go backward or forward in the history depending on the menu item selected.
 */
- (IBAction)backForwardInHistory:(id)sender
{
	// Ensure history navigation is permitted - trigger end editing and any required saves
	if (![self couldCommitCurrentViewActions]) return;

	switch ([sender tag])
	{
		// Go backward
		case 0:
			[spHistoryControllerInstance goBackInHistory];
			break;
		// Go forward
		case 1:
			[spHistoryControllerInstance goForwardInHistory];
			break;
	}
}
#endif

#pragma mark -
#pragma mark Connection callback and methods

/**
 *
 * This method *MUST* be called from the UI thread!
 */
- (void)setConnection:(SPMySQLConnection *)theConnection
{
	if ([theConnection userTriggeredDisconnect]) {
		return;
	}

	_isConnected = YES;
	mySQLConnection = [theConnection retain];
	
	// Now that we have a connection, determine what functionality the database supports.
	// Note that this must be done before anything else as it's used by nearly all of the main controllers.
	serverSupport = [[SPServerSupport alloc] initWithMajorVersion:[mySQLConnection serverMajorVersion]
	                                                        minor:[mySQLConnection serverMinorVersion]
	                                                      release:[mySQLConnection serverReleaseVersion]];

#ifndef SP_CODA	
	// Set the fileURL and init the preferences (query favs, filters, and history) if available for that URL 
	NSURL *newURL = [[SPQueryController sharedQueryController] registerDocumentWithFileURL:[self fileURL] andContextInfo:spfPreferences];
	[self setFileURL:newURL];
	
	// ...but hide the icon while the document is temporary
	if ([self isUntitled]) [[parentWindow standardWindowButton:NSWindowDocumentIconButton] setImage:nil];
#endif

	// Get the mysql version
	mySQLVersion = [[NSString alloc] initWithString:[mySQLConnection serverVersionString]];

	// Update the selected database if appropriate
	if ([connectionController database] && ![[connectionController database] isEqualToString:@""]) {
		if (selectedDatabase) SPClear(selectedDatabase);
		selectedDatabase = [[NSString alloc] initWithString:[connectionController database]];
#ifndef SP_CODA /* [spHistoryControllerInstance updateHistoryEntries] */
		[spHistoryControllerInstance updateHistoryEntries];
#endif
	}

	// Ensure the connection encoding is set to utf8 for database/table name retrieval
	[mySQLConnection setEncoding:@"utf8"];

	// Update the database list
	[self setDatabases:self];
	
	[chooseDatabaseButton setEnabled:!_isWorkingLevel];

	// Set the connection on the database structure builder
	[databaseStructureRetrieval setConnectionToClone:mySQLConnection];

	[databaseDataInstance setConnection:mySQLConnection];
	
	// Pass the support class to the data instance
	[databaseDataInstance setServerSupport:serverSupport];

#ifdef SP_CODA /* glue */
	tablesListInstance = [[SPTablesList alloc] init];
	[tablesListInstance setDatabaseDocument:self];
	[tablesListInstance awakeFromNib];
#endif	

	// Set the connection on the tables list instance - this updates the table list while the connection
	// is still UTF8
	[tablesListInstance setConnection:mySQLConnection];

#ifndef SP_CODA /* set connection encoding from prefs */
	// Set the connection encoding if necessary
	NSNumber *encodingType = [prefs objectForKey:SPDefaultEncoding];
	
	if ([encodingType intValue] != SPEncodingAutodetect) {
		[self setConnectionEncoding:[self mysqlEncodingFromEncodingTag:encodingType] reloadingViews:NO];
	} else {
#endif
		[[self onMainThread] updateEncodingMenuWithSelectedEncoding:[self encodingTagFromMySQLEncoding:[mySQLConnection encoding]]];
#ifndef SP_CODA
	}
#endif

	// For each of the main controllers, assign the current connection
	[tableSourceInstance setConnection:mySQLConnection];
	[tableContentInstance setConnection:mySQLConnection];
	[tableRelationsInstance setConnection:mySQLConnection];
	[tableTriggersInstance setConnection:mySQLConnection];
	[customQueryInstance setConnection:mySQLConnection];
	[tableDumpInstance setConnection:mySQLConnection];
#ifndef SP_CODA
	[exportControllerInstance setConnection:mySQLConnection];
	[exportControllerInstance setServerSupport:serverSupport];
#endif
	[tableDataInstance setConnection:mySQLConnection];
	[extendedTableInfoInstance setConnection:mySQLConnection];
	
	// Set the custom query editor's MySQL version
	[customQueryInstance setMySQLversion:mySQLVersion];

	[helpViewerClientInstance setConnection:mySQLConnection];

#ifndef SP_CODA
	[self updateWindowTitle:self];
	
	// Connected Growl notification
	NSString *serverDisplayName = nil;
	if ([parentWindowController selectedTableDocument] == self) {
		serverDisplayName = [parentWindow title];
	} else {
		serverDisplayName = [parentTabViewItem label];
	}

	[[SPGrowlController sharedGrowlController] notifyWithTitle:@"Connected"
	                                               description:[NSString stringWithFormat:NSLocalizedString(@"Connected to %@", @"description for connected growl notification"), serverDisplayName]
	                                                  document:self
	                                          notificationName:@"Connected"];

	// Init Custom Query editor with the stored queries in a spf file if given.
	[spfDocData setObject:@NO forKey:@"save_editor_content"];
	
	if (spfSession != nil && [spfSession objectForKey:@"queries"]) {
		[spfDocData setObject:@YES forKey:@"save_editor_content"];
		if ([[spfSession objectForKey:@"queries"] isKindOfClass:[NSData class]]) {
			NSString *q = [[NSString alloc] initWithData:[[spfSession objectForKey:@"queries"] decompress] encoding:NSUTF8StringEncoding];
			[self initQueryEditorWithString:q];
			[q release];
		}
		else {
			[self initQueryEditorWithString:[spfSession objectForKey:@"queries"]];
		}
	}

	// Insert queryEditorInitString into the Query Editor if defined
	if (queryEditorInitString && [queryEditorInitString length]) {
		[self viewQuery:self];
		[customQueryInstance doPerformLoadQueryService:queryEditorInitString];
		SPClear(queryEditorInitString);
	}

	if (spfSession != nil) {

		// Restore vertical split view divider for tables' list and right view (Structure, Content, etc.)
		if([spfSession objectForKey:@"windowVerticalDividerPosition"]) [contentViewSplitter setPosition:[[spfSession objectForKey:@"windowVerticalDividerPosition"] floatValue] ofDividerAtIndex:0];

		// Start a task to restore the session details
		[self startTaskWithDescription:NSLocalizedString(@"Restoring session...", @"Restoring session task description")];
		
		if ([NSThread isMainThread]) [NSThread detachNewThreadWithName:SPCtxt(@"SPDatabaseDocument session load task",self) target:self selector:@selector(restoreSession) object:nil];
		else                         [self restoreSession];
	} 
	else {
		switch ([prefs integerForKey:SPDefaultViewMode] > 0 ? [prefs integerForKey:SPDefaultViewMode] : [prefs integerForKey:SPLastViewMode]) {
			default:
			case SPStructureViewMode:
				[self viewStructure:self];
				break;
			case SPContentViewMode:
				[self viewContent:self];
				break;
			case SPRelationsViewMode:
				[self viewRelations:self];
				break;
			case SPTableInfoViewMode:
				[self viewStatus:self];
				break;
			case SPQueryEditorViewMode:
				[self viewQuery:self];
				break;
			case SPTriggersViewMode:
				[self viewTriggers:self];
				break;
		}
	}

	if ([self database]) [self detectDatabaseEncoding];

	// If not on the query view, alter initial focus - set focus to table list filter
	// field if visible, otherwise set focus to Table List view
	if (![[self selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarCustomQuery]) {
		[[tablesListInstance onMainThread] makeTableListFilterHaveFocus];
	}

#endif
#ifdef SP_CODA /* glue */
	if ( delegate && [delegate respondsToSelector:@selector(databaseDocumentDidConnect:)] )
		[delegate performSelector:@selector(databaseDocumentDidConnect:) withObject:self];
#endif
}

/**
 * Returns the current connection associated with this document.
 *
 * @return The document's connection
 */
- (SPMySQLConnection *)getConnection
{
	return mySQLConnection;
}

#pragma mark -
#pragma mark Database methods

/**
 * sets up the database select toolbar item
 *
 * This method *MUST* be called from the UI thread!
 */
- (IBAction)setDatabases:(id)sender;
{
	if (!chooseDatabaseButton) return;

	[chooseDatabaseButton removeAllItems];

	[chooseDatabaseButton addItemWithTitle:NSLocalizedString(@"Choose Database...", @"menu item for choose db")];
	[[chooseDatabaseButton menu] addItem:[NSMenuItem separatorItem]];
	[[chooseDatabaseButton menu] addItemWithTitle:NSLocalizedString(@"Add Database...", @"menu item to add db") action:@selector(addDatabase:) keyEquivalent:@""];
	[[chooseDatabaseButton menu] addItemWithTitle:NSLocalizedString(@"Refresh Databases", @"menu item to refresh databases") action:@selector(setDatabases:) keyEquivalent:@""];
	[[chooseDatabaseButton menu] addItem:[NSMenuItem separatorItem]];

	if (allDatabases) SPClear(allDatabases);
	if (allSystemDatabases) SPClear(allSystemDatabases);
	
	NSArray *theDatabaseList = [mySQLConnection databases];

	allDatabases = [[NSMutableArray alloc] initWithCapacity:[theDatabaseList count]];
	allSystemDatabases = [[NSMutableArray alloc] initWithCapacity:2];
	
	for (NSString *databaseName in theDatabaseList)
	{
		// If the database is either information_schema or mysql then it is classed as a
		// system database; similarly, performance_schema in 5.5.3+ and sys in 5.7.7+
		if ([databaseName isEqualToString:SPMySQLDatabase] || 
			[databaseName isEqualToString:SPMySQLInformationSchemaDatabase] || 
			[databaseName isEqualToString:SPMySQLPerformanceSchemaDatabase] ||
			[databaseName isEqualToString:SPMySQLSysDatabase]) {
 			[allSystemDatabases addObject:databaseName];
		}
		else {
			[allDatabases addObject:databaseName];
		}
	}

	// Add system databases
	for (NSString *database in allSystemDatabases)
	{
		[chooseDatabaseButton addItemWithTitle:database];
	}
	
	// Add a separator between the system and user databases
	if ([allSystemDatabases count] > 0) {
		[[chooseDatabaseButton menu] addItem:[NSMenuItem separatorItem]];
	}

	// Add user databases
	for (NSString *database in allDatabases)
	{
		[chooseDatabaseButton addItemWithTitle:database];
	}

	(![self database]) ? [chooseDatabaseButton selectItemAtIndex:0] : [chooseDatabaseButton selectItemWithTitle:[self database]];
}

#ifndef SP_CODA /* chooseDatabase: */

/**
 * Selects the database choosen by the user, using a child task if necessary,
 * and displaying errors in an alert sheet on failure.
 */
- (IBAction)chooseDatabase:(id)sender
{
	if (![tablesListInstance selectionShouldChangeInTableView:nil]) {
		[chooseDatabaseButton selectItemWithTitle:[self database]];
		return;
	}

	if ( [chooseDatabaseButton indexOfSelectedItem] == 0 ) {
		if ([self database]) {
			[chooseDatabaseButton selectItemWithTitle:[self database]];
		}
		
		return;
	}

	// Lock editability again if performing a task
	if (_isWorkingLevel) databaseListIsSelectable = NO;

	// Select the database
	[self selectDatabase:[chooseDatabaseButton titleOfSelectedItem] item:[self table]];
}
#endif

/**
 * Select the specified database and, optionally, table.
 */
- (void)selectDatabase:(NSString *)database item:(NSString *)item
{
#ifndef SP_CODA /* update navigator controller */
	// Do not update the navigator since nothing is changed
	[[SPNavigatorController sharedNavigatorController] setIgnoreUpdate:NO];

	// If Navigator runs in syncMode let it follow the selection
	if([[SPNavigatorController sharedNavigatorController] syncMode]) {
		NSMutableString *schemaPath = [NSMutableString string];
		
		[schemaPath setString:[self connectionID]];
		
		if([chooseDatabaseButton titleOfSelectedItem] && [[chooseDatabaseButton titleOfSelectedItem] length]) {
			[schemaPath appendString:SPUniqueSchemaDelimiter];
			[schemaPath appendString:[chooseDatabaseButton titleOfSelectedItem]];
		}
		
		[[SPNavigatorController sharedNavigatorController] selectPath:schemaPath];
	}
#endif

	// Start a task
	[self startTaskWithDescription:[NSString stringWithFormat:NSLocalizedString(@"Loading database '%@'...", @"Loading database task string"), [chooseDatabaseButton titleOfSelectedItem]]];
	
	NSDictionary *selectionDetails = [NSDictionary dictionaryWithObjectsAndKeys:database, @"database", item, @"item", nil];
	
	if ([NSThread isMainThread]) {
		[NSThread detachNewThreadWithName:SPCtxt(@"SPDatabaseDocument database and table load task",self)
		                           target:self
		                         selector:@selector(_selectDatabaseAndItem:)
		                           object:selectionDetails];
	} 
	else {
		[self _selectDatabaseAndItem:selectionDetails];
	}
}

/**
 * opens the add-db sheet and creates the new db
 */
- (IBAction)addDatabase:(id)sender
{
	if (![tablesListInstance selectionShouldChangeInTableView:nil]) return;
	
	[databaseNameField setStringValue:@""];

	NSString *defaultCharset   = [databaseDataInstance getServerDefaultCharacterSet];
	NSString *defaultCollation = [databaseDataInstance getServerDefaultCollation];
	
	// Setup the charset and collation dropdowns
	[addDatabaseCharsetHelper setDatabaseData:databaseDataInstance];
	[addDatabaseCharsetHelper setDefaultCharsetFormatString:NSLocalizedString(@"Server Default (%@)", @"Add Database : Charset dropdown : default item ($1 = charset name)")];
	[addDatabaseCharsetHelper setDefaultCollationFormatString:NSLocalizedString(@"Server Default (%@)", @"Add Database : Collation dropdown : default item ($1 = collation name)")];
	[addDatabaseCharsetHelper setServerSupport:serverSupport];
	[addDatabaseCharsetHelper setPromoteUTF8:YES];
	[addDatabaseCharsetHelper setSelectedCharset:nil];
	[addDatabaseCharsetHelper setSelectedCollation:nil];
	[addDatabaseCharsetHelper setDefaultCharset:defaultCharset];
	[addDatabaseCharsetHelper setDefaultCollation:defaultCollation];
	[addDatabaseCharsetHelper setEnabled:YES];

	[NSApp beginSheet:databaseSheet
	   modalForWindow:parentWindow
	    modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
	      contextInfo:@"addDatabase"];
}


/**
 * Show UI for the ALTER DATABASE statement
 * @warning Make sure this method is only called on mysql 4.1+ servers!
 */
- (IBAction)alterDatabase:(id)sender
{
	//once the database is created the charset and collation are written
	//to the db.opt file regardless if they were explicity given or not.
	//So there is no longer a "Default" option.
	
	NSString *currentCharset   = [databaseDataInstance getDatabaseDefaultCharacterSet];
	NSString *currentCollation = [databaseDataInstance getDatabaseDefaultCollation];
	
	// Setup the charset and collation dropdowns
	[alterDatabaseCharsetHelper setDatabaseData:databaseDataInstance];
	[alterDatabaseCharsetHelper setServerSupport:serverSupport];
	[alterDatabaseCharsetHelper setPromoteUTF8:YES];
	[alterDatabaseCharsetHelper setSelectedCharset:currentCharset];
	[alterDatabaseCharsetHelper setSelectedCollation:currentCollation];
	[alterDatabaseCharsetHelper setEnabled:YES];

	[NSApp beginSheet:databaseAlterSheet
	   modalForWindow:parentWindow
	    modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
	      contextInfo:SPAlterDatabaseAction];
}

- (IBAction)compareDatabase:(id)sender
{
	/*
	 
	 
	 This method is a basic experiment to see how long it takes to read an string compare an entire database. It works,
	 well, good performance and very little memory usage.
	 
	 Next we need to ask the user to select another connection (from the favourites list) and compare chunks of ~1000 rows
	 at a time, ordered by primary key, between the two databases, using three threads (one for each database and one for
	 comparisons).
	 
	 We will the write to disk every difference that has been found and open the result in FileMerge.
	 
	 In future, add the ability to write all difference to the current database.
	 
	 
	 */
	NSLog(@"=================");
	
	SPMySQLResult *showTablesQuery = [mySQLConnection queryString:@"show tables"];
	
	NSArray *tableRow;
	while ((tableRow = [showTablesQuery getRowAsArray]) != nil) {
		@autoreleasepool {
			NSString *table = tableRow[0];
			
			NSLog(@"-----------------");
			NSLog(@"Scanning %@", table);
			
			
			NSDictionary *tableStatus = [[mySQLConnection queryString:[NSString stringWithFormat:@"SHOW TABLE STATUS LIKE %@", [table tickQuotedString]]] getRowAsDictionary];
			NSInteger rowCountEstimate = [tableStatus[@"Rows"] integerValue];
			NSLog(@"Estimated row count: %li", rowCountEstimate);
			
			
			
			SPMySQLResult *tableContentsQuery = [mySQLConnection streamingQueryString:[NSString stringWithFormat:@"select * from %@", [table backtickQuotedString]] useLowMemoryBlockingStreaming:NO];
			//NSDate *lastProgressUpdate = [NSDate date];
			time_t lastProgressUpdate = time(NULL);
			NSInteger rowCount = 0;
			NSArray *row;
			while (true) {
				@autoreleasepool {
					row = [tableContentsQuery getRowAsArray];
					if (!row) {
						break;
					}
					
					[row isEqualToArray:row]; // TODO: compare to the other database, instead of the same one (just doing that to test performance)
					
					rowCount++;
					if ((time(NULL) - lastProgressUpdate) > 0) {
						NSLog(@"Progress: %.1f%%", (((float)rowCount) / ((float)rowCountEstimate)) * 100);
						lastProgressUpdate = time(NULL);
					}
				}
			}
			NSLog(@"Done. Actual row count: %li", rowCount);
		}
	}
	
	NSLog(@"=================");
}

/**
 * Opens the copy database sheet and copies the databsae.
 */
- (IBAction)copyDatabase:(id)sender
{	
	if (![tablesListInstance selectionShouldChangeInTableView:nil]) return;

	// Inform the user that we don't support copying objects other than tables and ask them if they'd like to proceed
	if ([tablesListInstance hasNonTableObjects]) {
		[SPAlertSheets beginWaitingAlertSheetWithTitle:NSLocalizedString(@"Only Partially Supported", @"partial copy database support message")
		                                 defaultButton:NSLocalizedString(@"Continue", "continue button")
		                               alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
		                                   otherButton:nil
		                                    alertStyle:NSAlertStyleWarning
		                                     docWindow:parentWindow
		                                 modalDelegate:self
		                                didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		                                   contextInfo:SPConfirmCopyDatabaseAction
		                                      infoText:[NSString stringWithFormat:NSLocalizedString(@"Duplicating the database '%@' is only partially supported as it contains objects other tables (i.e. views, procedures, functions, etc.), which will not be copied.\n\nWould you like to continue?", @"partial copy database support informative message"), selectedDatabase]
		                                    returnCode:&confirmCopyDatabaseReturnCode];

		if (confirmCopyDatabaseReturnCode == NSAlertAlternateReturn) return;
	}

	[databaseCopyNameField setStringValue:selectedDatabase];
	[copyDatabaseMessageField setStringValue:selectedDatabase];

	[NSApp beginSheet:databaseCopySheet
	   modalForWindow:parentWindow
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:SPCopyDatabaseAction];
}

/**
 * Opens the rename database sheet and renames the databsae.
 */
- (IBAction)renameDatabase:(id)sender
{	
	if (![tablesListInstance selectionShouldChangeInTableView:nil]) return;

	// We currently don't support moving any objects other than tables (i.e. views, functions, procs, etc.) from one database to another
	// so inform the user and don't allow them to proceed. Copy/duplicate is more appropriate in this case, but with the same limitation.
	if ([tablesListInstance hasNonTableObjects]) {
		SPOnewayAlertSheet(
			NSLocalizedString(@"Database Rename Unsupported", @"databsse rename unsupported message"),
			parentWindow,
			[NSString stringWithFormat:NSLocalizedString(
					@"Ranaming the database '%@' is currently unsupported as it contains objects other than tables (i.e. views, procedures, functions, etc.).\n\nIf you would like to rename a database please use the 'Duplicate Database', move any non-table objects manually then drop the old database.",
					@"databsse rename unsupported informative message"), selectedDatabase]
		);
		return;
	}
	
	[databaseRenameNameField setStringValue:selectedDatabase];
	[renameDatabaseMessageField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Rename database '%@' to:", @"rename database message"), selectedDatabase]];

	[NSApp beginSheet:databaseRenameSheet
	   modalForWindow:parentWindow
	    modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
	      contextInfo:SPRenameDatabaseAction];
}

/**
 * opens sheet to ask user if he really wants to delete the db
 */
- (IBAction)removeDatabase:(id)sender
{
#ifndef SP_CODA
	// No database selected, bail
	if ([chooseDatabaseButton indexOfSelectedItem] == 0) return;
#endif

	if (![tablesListInstance selectionShouldChangeInTableView:nil]) return;

	NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Delete database '%@'?", @"delete database message"), [self database]]
	                                 defaultButton:NSLocalizedString(@"Delete", @"delete button")
	                               alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
	                                   otherButton:nil
	                     informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to delete the database '%@'? This operation cannot be undone.", @"delete database informative message"), [self database]];

	NSArray *buttons = [alert buttons];

#ifndef SP_CODA
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"d"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
#else
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\e"]; // Esc = Cancel
	[[buttons objectAtIndex:0] setKeyEquivalent:@"\r"]; // Return = OK
#endif

	[alert setAlertStyle:NSCriticalAlertStyle];

	[alert beginSheetModalForWindow:parentWindow
	                  modalDelegate:self
	                 didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
	                    contextInfo:@"removeDatabase"];
}

/**
 * Refreshes the tables list by calling SPTablesList's updateTables.
 */
- (IBAction)refreshTables:(id)sender
{
	[tablesListInstance updateTables:self];
}

#ifndef SP_CODA
/**
 * Displays the database server variables sheet.
 */
- (IBAction)showServerVariables:(id)sender
{
	if (!serverVariablesController) {
		serverVariablesController = [[SPServerVariablesController alloc] init];
		
		[serverVariablesController setConnection:mySQLConnection];
	}
	
	[serverVariablesController displayServerVariablesSheetAttachedToWindow:parentWindow];
}

/**
 * Displays the database process list sheet.
 */
- (IBAction)showServerProcesses:(id)sender
{
	if (!processListController) {
		processListController = [[SPProcessListController alloc] init];
		
		[processListController setConnection:mySQLConnection];
	}
	
	[processListController displayProcessListWindow];
}

- (IBAction)shutdownServer:(id)sender
{
	// confirm user action
	SPBeginAlertSheet(
		NSLocalizedString(@"Do you really want to shutdown the server?", @"shutdown server : confirmation dialog : title"),
		NSLocalizedString(@"Shutdown", @"shutdown server : confirmation dialog : shutdown button"),
		NSLocalizedString(@"Cancel", @"shutdown server : confirmation dialog : cancel button"),
		nil,
		parentWindow,
		self,
		@selector(shutdownAlertDidEnd:returnCode:contextInfo:),
		NULL,
		NSLocalizedString(@"This will wait for open transactions to complete and then quit the mysql daemon. Afterwards neither you nor anyone else can connect to this database!\n\nFull management access to the server's operating system is required to restart MySQL!", @"shutdown server : confirmation dialog : message")
	);
}

- (void)shutdownAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if(returnCode != NSAlertDefaultReturn) return; //cancelled by user
	
	if(![mySQLConnection serverShutdown]) {
		if([mySQLConnection isConnected]) {
			SPOnewayAlertSheet(
				NSLocalizedString(@"Shutdown failed!", @"shutdown server : error dialog : title"),
				parentWindow,
				[NSString stringWithFormat:NSLocalizedString(@"MySQL said:\n%@", @"shutdown server : error dialog : message"),[mySQLConnection lastErrorMessage]]
			);
		}
	}
	// shutdown successful.
	// Until s.o. has a good UI idea, do nothing. Sequel Pro should figure out the connection loss soon enough
}

#endif

/**
 * Returns an array of all available database names
 */
- (NSArray *)allDatabaseNames
{
	return allDatabases;
}

/**
 * Returns an array of all available system database names
 */
- (NSArray *)allSystemDatabaseNames
{
	return allSystemDatabases;
}

/**
 * Alert sheet method. Invoked when an alert sheet is dismissed.
 */
- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	// Those that are just setting a return code and don't need to order out the sheet. See SPAlertSheets+beginWaitingAlertSheetWithTitle:
	if ([contextInfo isEqualToString:SPSaveDocumentPreferences]) {
		saveDocPrefSheetStatus = returnCode;
		return;
	}
	else if ([contextInfo isEqualToString:SPConfirmCopyDatabaseAction]) {
		confirmCopyDatabaseReturnCode = returnCode;
		return;
	}

	// Order out current sheet to suppress overlapping of sheets
	if ([sheet respondsToSelector:@selector(orderOut:)]) {
		[sheet orderOut:nil];
	}
	else if ([sheet respondsToSelector:@selector(window)]) {
		[[sheet window] orderOut:nil];
	}

	// Remove the current database
	if ([contextInfo isEqualToString:@"removeDatabase"]) {
		if (returnCode == NSAlertDefaultReturn) {
			[self _removeDatabase];
		}
	}
	// Add a new database
	else if ([contextInfo isEqualToString:@"addDatabase"]) {
		[addDatabaseCharsetHelper setEnabled:NO];

		if (returnCode == NSOKButton) {
			[self _addDatabase];

			// Query the structure of all databases in the background (mainly for completion)
			[databaseStructureRetrieval queryDbStructureInBackgroundWithUserInfo:@{@"forceUpdate" : @YES}];
		}
		else {
			// Reset chooseDatabaseButton
			if ([[self database] length]) {
				[chooseDatabaseButton selectItemWithTitle:[self database]];
			}
			else {
				[chooseDatabaseButton selectItemAtIndex:0];
			}
		}
	}
	else if ([contextInfo isEqualToString:SPCopyDatabaseAction]) {
		if (returnCode == NSOKButton) {
			[self _copyDatabase];
		}
	}
	else if ([contextInfo isEqualToString:SPRenameDatabaseAction]) {
		if (returnCode == NSOKButton) {
			[self _renameDatabase];
		}
	}
	else if ([contextInfo isEqualToString:SPAlterDatabaseAction]) {
		[alterDatabaseCharsetHelper setEnabled:NO];
		if (returnCode == NSOKButton) {
			[self _alterDatabase];
		}
	}
	// Close error status sheet for OPTIMIZE, CHECK, REPAIR etc.
	else if ([contextInfo isEqualToString:@"statusError"]) {
		if (statusValues) SPClear(statusValues);
	}
}

#ifndef SP_CODA /* sheetDidEnd: */
/**
 * Show Error sheet (can be called from inside of a endSheet selector)
 * via [self performSelector:@selector(showErrorSheetWithTitle:) withObject: afterDelay:]
 */
-(void)showErrorSheetWith:(NSArray *)error
{
	// error := first object is the title , second the message, only one button OK
	SPOnewayAlertSheet([error objectAtIndex:0], parentWindow, [error objectAtIndex:1]);
}
#endif

/**
 * Reset the current selected database name
 *
 * This method MAY be called from UI and background threads!
 */
- (void)refreshCurrentDatabase
{
	NSString *dbName = nil;

	// Notify listeners that a query has started
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryWillBePerformed" object:self];

	SPMySQLResult *theResult = [mySQLConnection queryString:@"SELECT DATABASE()"];
	[theResult setDefaultRowReturnType:SPMySQLResultRowAsArray];
	if (![mySQLConnection queryErrored]) {

		for (NSArray *eachRow in theResult)
		{
			dbName = NSArrayObjectAtIndex(eachRow, 0);
		}

		SPMainQSync(^{
			// TODO: there have been crash reports because dbName == nil at this point. When could that happen?
			if([dbName unboxNull]) {
				if(![dbName isEqualToString:selectedDatabase]) {
					if (selectedDatabase) SPClear(selectedDatabase);
					selectedDatabase = [[NSString alloc] initWithString:dbName];
					[chooseDatabaseButton selectItemWithTitle:selectedDatabase];
					[self updateWindowTitle:self];
				}
			} else {
				if (selectedDatabase) SPClear(selectedDatabase);
				[chooseDatabaseButton selectItemAtIndex:0];
				[self updateWindowTitle:self];
			}
		});
	}

	//query finished
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryHasBeenPerformed" object:self];
}

#ifndef SP_CODA /* navigatorSchemaPathExistsForDatabase: */
- (BOOL)navigatorSchemaPathExistsForDatabase:(NSString*)dbname
{
	return [[SPNavigatorController sharedNavigatorController] schemaPathExistsForConnection:[self connectionID] andDatabase:dbname];
}
#endif

- (NSDictionary*)getDbStructure
{
	return [[SPNavigatorController sharedNavigatorController] dbStructureForConnection:[self connectionID]];
}

- (NSArray *)allSchemaKeys
{
	return [[SPNavigatorController sharedNavigatorController] allSchemaKeysForConnection:[self connectionID]];
}

- (IBAction)showGotoDatabase:(id)sender
{
	if(!gotoDatabaseController) {
		gotoDatabaseController = [[SPGotoDatabaseController alloc] init];
	}
	
	NSMutableArray *dbList = [[NSMutableArray alloc] init];
	[dbList addObjectsFromArray:[self allSystemDatabaseNames]];
	[dbList addObjectsFromArray:[self allDatabaseNames]];
	[gotoDatabaseController setDatabaseList:[dbList autorelease]];
	
	if([gotoDatabaseController runModal]) {
		[self selectDatabase:[gotoDatabaseController selectedDatabase] item:nil];
	}
}

#ifndef SP_CODA /* console and navigator methods */

#pragma mark -
#pragma mark Console methods

/**
 * Shows or hides the console
 */
- (void)toggleConsole:(id)sender
{
	// Toggle Console will show the Console window if it isn't visible or if it isn't
	// the front most window and hide it if it is the front most window 
	if ([[[SPQueryController sharedQueryController] window] isVisible] 
		&& [[[NSApp keyWindow] windowController] isKindOfClass:[SPQueryController class]]) {

		[[[SPQueryController sharedQueryController] window] setIsVisible:NO];
	}
	else {
		[self showConsole:nil];
	}
}

/**
 * Brings the console to the front
 */
- (void)showConsole:(id)sender
{
	SPQueryController *queryController = [SPQueryController sharedQueryController];
	// If the Console window is not visible data are not reloaded (for speed).
	// Due to that update list if user opens the Console window.
	if(![[queryController window] isVisible]) [queryController updateEntries];

	[[queryController window] makeKeyAndOrderFront:self];

}

/**
 * Clears the console by removing all of its messages
 */
- (void)clearConsole:(id)sender
{
	[[SPQueryController sharedQueryController] clearConsole:sender];
}

/**
 * Set a query mode, used to control logging dependant on preferences
 */
- (void) setQueryMode:(NSInteger)theQueryMode
{
	_queryMode = theQueryMode;
}

#pragma mark -
#pragma mark Navigator methods

/**
 * Shows or hides the navigator
 */
- (IBAction)toggleNavigator:(id)sender
{
	BOOL isNavigatorVisible = [[[SPNavigatorController sharedNavigatorController] window] isVisible];

	// Show or hide the navigator
	[[[SPNavigatorController sharedNavigatorController] window] setIsVisible:(!isNavigatorVisible)];

	if(!isNavigatorVisible) [[SPNavigatorController sharedNavigatorController] updateEntriesForConnection:self];

}

- (IBAction)showNavigator:(id)sender
{
	BOOL isNavigatorVisible = [[[SPNavigatorController sharedNavigatorController] window] isVisible];
	
	if (!isNavigatorVisible) {
		[self toggleNavigator:sender];
	} else {
		[[[SPNavigatorController sharedNavigatorController] window] makeKeyAndOrderFront:self];
	}
}
#endif

#pragma mark -
#pragma mark Task progress and notification methods

/**
 * Start a document-wide task, providing a short task description for
 * display to the user.  This sets the document into working mode,
 * preventing many actions, and shows an indeterminate progress interface
 * to the user.
 */
- (void) startTaskWithDescription:(NSString *)description
{
	// Ensure a call on the main thread
	if (![NSThread isMainThread]) return [[self onMainThread] startTaskWithDescription:description];

	// Set the task text. If a nil string was supplied, a generic query notification is occurring -
	// if a task is not already active, use default text.
	if (!description) {
		if (!_isWorkingLevel) [self setTaskDescription:NSLocalizedString(@"Working...", @"Generic working description")];
	
	// Otherwise display the supplied string
	} else {
		[self setTaskDescription:description];
	}

	// Increment the task level
	_isWorkingLevel++;

#ifndef SP_CODA 
	// Reset the progress indicator if necessary
	if (_isWorkingLevel == 1 || !taskDisplayIsIndeterminate) {
		taskDisplayIsIndeterminate = YES;
		[taskProgressIndicator setIndeterminate:YES];
		[taskProgressIndicator startAnimation:self];
		taskDisplayLastValue = 0;
	}
#endif
	
	// If the working level just moved to start a task, set up the interface
	if (_isWorkingLevel == 1) {
#ifndef SP_CODA 
		[taskCancelButton setHidden:YES];
#endif
		
		// Set flags and prevent further UI interaction in this window
		databaseListIsSelectable = NO;
		[[NSNotificationCenter defaultCenter] postNotificationName:SPDocumentTaskStartNotification object:self];
#ifndef SP_CODA
		[mainToolbar validateVisibleItems];
		[chooseDatabaseButton setEnabled:NO];
				
		// Schedule appearance of the task window in the near future, using a frame timer.
		taskFadeInStartDate = [[NSDate alloc] init];
		queryStartDate = [[NSDate alloc] init];
		taskDrawTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0 target:self selector:@selector(fadeInTaskProgressWindow:) userInfo:nil repeats:YES] retain];
		queryExecutionTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(showQueryExecutionTime) userInfo:nil repeats:YES] retain];

#endif
	}
}


/**
 * Show query execution time on progress window.
 */
-(void)showQueryExecutionTime{

	double timeSinceQueryStarted = [[NSDate date] timeIntervalSinceDate:queryStartDate];

	NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
	formatter.allowedUnits = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
	formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorPad;
	NSString *queryRunningTime = [formatter stringFromTimeInterval:timeSinceQueryStarted];
	
	NSShadow *textShadow = [[NSShadow alloc] init];
	[textShadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0f alpha:0.75f]];
	[textShadow setShadowOffset:NSMakeSize(1.0f, -1.0f)];
	[textShadow setShadowBlurRadius:3.0f];
	
	NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
									   [NSFont boldSystemFontOfSize:13.0f], NSFontAttributeName,
									   textShadow, NSShadowAttributeName,
									   nil];
	NSAttributedString *queryRunningTimeString = [[NSAttributedString alloc] initWithString:queryRunningTime attributes:attributes];
	
	[taskDurationTime setAttributedStringValue:queryRunningTimeString];
	
}

/**
 * Show the task progress window, after a small delay to minimise flicker.
 */
- (void) fadeInTaskProgressWindow:(NSTimer *)theTimer
{
#ifndef SP_CODA 
	double timeSinceFadeInStart = [[NSDate date] timeIntervalSinceDate:taskFadeInStartDate];

	// Keep the window hidden for the first ~0.5 secs
	if (timeSinceFadeInStart < 0.5) return;

	CGFloat alphaValue = [taskProgressWindow alphaValue];

	// If the task progress window is still hidden, center it before revealing it
	if (alphaValue == 0) [self centerTaskWindow];

	// Fade in the task window over 0.6 seconds
	alphaValue = (float)(timeSinceFadeInStart - 0.5) / 0.6f;
	if (alphaValue > 1.0f) alphaValue = 1.0f;
	[taskProgressWindow setAlphaValue:alphaValue];

	// If the window has been fully faded in, clean up the timer.
	if (alphaValue == 1.0) {
		[taskDrawTimer invalidate], SPClear(taskDrawTimer);
		SPClear(taskFadeInStartDate);
	}
#endif
}


/**
 * Updates the task description shown to the user.
 */
- (void) setTaskDescription:(NSString *)description
{
#ifndef SP_CODA 
	NSShadow *textShadow = [[NSShadow alloc] init];
	[textShadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0f alpha:0.75f]];
	[textShadow setShadowOffset:NSMakeSize(1.0f, -1.0f)];
	[textShadow setShadowBlurRadius:3.0f];

	NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
													[NSFont boldSystemFontOfSize:13.0f], NSFontAttributeName,
													textShadow, NSShadowAttributeName,
													nil];
	NSAttributedString *string = [[NSAttributedString alloc] initWithString:description attributes:attributes];

	[taskDescriptionText setAttributedStringValue:string];

	[string release];
	[attributes release];
	[textShadow release];
#endif
}

/**
 * Sets the task percentage progress - the first call to this automatically
 * switches the progress display to determinate.
 * Can be called from background threads - forwards to main thread as appropriate.
 */
- (void) setTaskPercentage:(CGFloat)taskPercentage
{
#ifndef SP_CODA 

	// If the task display is currently indeterminate, set it to determinate on the main thread.
	if (taskDisplayIsIndeterminate) {
		if (![NSThread isMainThread]) return [[self onMainThread] setTaskPercentage:taskPercentage];

		taskDisplayIsIndeterminate = NO;
		[taskProgressIndicator stopAnimation:self];
		[taskProgressIndicator setDoubleValue:0.5];
	}

	// Check the supplied progress.  Compare it to the display interval - how often
	// the interface is updated - and update the interface if the value has changed enough.
	taskProgressValue = taskPercentage;
	if (taskProgressValue >= taskDisplayLastValue + taskProgressValueDisplayInterval
		|| taskProgressValue <= taskDisplayLastValue - taskProgressValueDisplayInterval)
	{
		if ([NSThread isMainThread]) {
			[taskProgressIndicator setDoubleValue:taskProgressValue];
		} else {
			[taskProgressIndicator performSelectorOnMainThread:@selector(setNumberValue:) withObject:[NSNumber numberWithDouble:taskProgressValue] waitUntilDone:NO];
		}
		taskDisplayLastValue = taskProgressValue;
	}
#endif
}

/**
 * Sets the task progress indicator back to indeterminate (also performed
 * automatically whenever a new task is started).
 * This can optionally be called with afterDelay set, in which case the intederminate
 * switch will be made after a short pause to minimise flicker for short actions.
 * Should be called on the main thread.
 */
- (void) setTaskProgressToIndeterminateAfterDelay:(BOOL)afterDelay
{
#ifndef SP_CODA 
	if (afterDelay) {
		[self performSelector:@selector(setTaskProgressToIndeterminateAfterDelay:) withObject:nil afterDelay:0.5];
		return;
	}

	if (taskDisplayIsIndeterminate) return;
	[NSObject cancelPreviousPerformRequestsWithTarget:taskProgressIndicator];
	taskDisplayIsIndeterminate = YES;
	[taskProgressIndicator setIndeterminate:YES];
	[taskProgressIndicator startAnimation:self];
	taskDisplayLastValue = 0;
#endif
}

/**
 * Hide the task progress and restore the document to allow actions again.
 */
- (void) endTask
{
	// Ensure a call on the main thread
	if (![NSThread isMainThread]) return [[self onMainThread] endTask];

	// Decrement the working level
	_isWorkingLevel--;
	assert(_isWorkingLevel >= 0);

	// Ensure cancellation interface is reset
	[self disableTaskCancellation];

	// If all tasks have ended, re-enable the interface
	if (!_isWorkingLevel) {

#ifndef SP_CODA 
		// Cancel the draw timer if it exists
		if (taskDrawTimer) {
			[taskDrawTimer invalidate], SPClear(taskDrawTimer);
			SPClear(taskFadeInStartDate);
		}

		if (queryExecutionTimer) {
			queryStartDate = [[NSDate alloc] init];
			[self showQueryExecutionTime];
			[queryExecutionTimer invalidate], SPClear(queryExecutionTimer);
			SPClear(queryExecutionTimer);
		}
		
		// Hide the task interface and reset to indeterminate
		if (taskDisplayIsIndeterminate) [taskProgressIndicator stopAnimation:self];
		[taskProgressWindow setAlphaValue:0.0f];
		taskDisplayIsIndeterminate = YES;
		[taskProgressIndicator setIndeterminate:YES];
#endif
		
		// Re-enable window interface
		databaseListIsSelectable = YES;
		[[NSNotificationCenter defaultCenter] postNotificationName:SPDocumentTaskEndNotification object:self];
#ifndef SP_CODA 
		[mainToolbar validateVisibleItems];
#endif
		[chooseDatabaseButton setEnabled:_isConnected];
	}
}

/**
 * Allow a task to be cancelled, enabling the button with a supplied title
 * and optionally supplying a callback object and function.
 */
- (void) enableTaskCancellationWithTitle:(NSString *)buttonTitle callbackObject:(id)callbackObject callbackFunction:(SEL)callbackFunction
{
#ifndef SP_CODA 
	// Ensure call on the main thread
	if (![NSThread isMainThread]) return [[self onMainThread] enableTaskCancellationWithTitle:buttonTitle callbackObject:callbackObject callbackFunction:callbackFunction];

	// If no task is active, return
	if (!_isWorkingLevel) return;

	if (callbackObject && callbackFunction) {
		taskCancellationCallbackObject = callbackObject;
		taskCancellationCallbackSelector = callbackFunction;
	}
	taskCanBeCancelled = YES;

	[taskCancelButton setTitle:buttonTitle];
	[taskCancelButton setEnabled:YES];
	[taskCancelButton setHidden:NO];
#endif
}

/**
 * Disable task cancellation.  Called automatically at the end of a task.
 */
- (void)disableTaskCancellation
{
#ifndef SP_CODA 
	// Ensure call on the main thread
	if (![NSThread isMainThread]) return [[self onMainThread] disableTaskCancellation];

	// If no task is active, return
	if (!_isWorkingLevel) return;
	
	taskCanBeCancelled = NO;
	taskCancellationCallbackObject = nil;
	taskCancellationCallbackSelector = NULL;
	[taskCancelButton setHidden:YES];
#endif
}

/**
 * Action sent by the cancel button when it's active.
 */
- (IBAction)cancelTask:(id)sender
{
#ifndef SP_CODA 
	if (!taskCanBeCancelled) return;

	[taskCancelButton setEnabled:NO];

	// See whether there is an active database structure task and whether it can be used
	// to cancel the query, for speed (no connection overhead!)
	if (databaseStructureRetrieval && [databaseStructureRetrieval connection]) {
		[mySQLConnection setLastQueryWasCancelled:YES];
		[[databaseStructureRetrieval connection] killQueryOnThreadID:[mySQLConnection mysqlConnectionThreadId]];
	} else {
		[mySQLConnection cancelCurrentQuery];
	}

	if (taskCancellationCallbackObject && taskCancellationCallbackSelector) {
		[taskCancellationCallbackObject performSelector:taskCancellationCallbackSelector];
	}
#endif
}

/**
 * Returns whether the document is busy performing a task - allows UI or actions
 * to be restricted as appropriate.
 */
- (BOOL)isWorking
{
	return (_isWorkingLevel > 0);
}

/**
 * Set whether the database list is selectable or not during the task process.
 */
- (void)setDatabaseListIsSelectable:(BOOL)isSelectable
{
	databaseListIsSelectable = isSelectable;
}

/**
 * Reposition the task window within the main window.
 */
- (void)centerTaskWindow
{
#ifndef SP_CODA 
	NSPoint newBottomLeftPoint;
	NSRect mainWindowRect = [parentWindow frame];
	NSRect taskWindowRect = [taskProgressWindow frame];

	newBottomLeftPoint.x = roundf(mainWindowRect.origin.x + mainWindowRect.size.width/2 - taskWindowRect.size.width/2);
	newBottomLeftPoint.y = roundf(mainWindowRect.origin.y + mainWindowRect.size.height/2 - taskWindowRect.size.height/2);

	[taskProgressWindow setFrameOrigin:newBottomLeftPoint];
#endif
}

/**
 * Support pausing and restarting the task progress indicator.
 * Only works while the indicator is in indeterminate mode.
 */
- (void)setTaskIndicatorShouldAnimate:(BOOL)shouldAnimate
{
#ifndef SP_CODA 
	if (shouldAnimate) {
		[[taskProgressIndicator onMainThread] startAnimation:self];
	} else {
		[[taskProgressIndicator onMainThread] stopAnimation:self];
	}
#endif
}

#pragma mark -
#pragma mark Encoding Methods

/**
 * Set the encoding for the database connection
 */
- (void)setConnectionEncoding:(NSString *)mysqlEncoding reloadingViews:(BOOL)reloadViews
{
	BOOL useLatin1Transport = NO;

	// Special-case UTF-8 over latin 1 to allow viewing/editing of mangled data.
	if ([mysqlEncoding isEqualToString:@"utf8-"]) {
		useLatin1Transport = YES;
		mysqlEncoding = @"utf8";
	}

	// Set the connection encoding
	if (![mySQLConnection setEncoding:mysqlEncoding]) {
		NSLog(@"Error: could not set encoding to %@ nor fall back to database encoding on MySQL %@", mysqlEncoding, [self mySQLVersion]);
		return;
	}
	[mySQLConnection setEncodingUsesLatin1Transport:useLatin1Transport];

	// Update the selected menu item
	if (useLatin1Transport) {
		[[self onMainThread] updateEncodingMenuWithSelectedEncoding:[self encodingTagFromMySQLEncoding:[NSString stringWithFormat:@"%@-", mysqlEncoding]]];
	} else {
		[[self onMainThread] updateEncodingMenuWithSelectedEncoding:[self encodingTagFromMySQLEncoding:mysqlEncoding]];
	}

	// Update the stored connection encoding to prevent switches
	[mySQLConnection storeEncodingForRestoration];

	// Reload views as appropriate
	if (reloadViews) {
		[self setStructureRequiresReload:YES];
		[self setContentRequiresReload:YES];
		[self setStatusRequiresReload:YES];
	}
}

/**
 * updates the currently selected item in the encoding menu
 * 
 * @param NSString *encoding - the title of the menu item which will be selected
 */
- (void)updateEncodingMenuWithSelectedEncoding:(NSNumber *)encodingTag
{
	NSInteger itemToSelect = [encodingTag integerValue];
	NSInteger correctStateForMenuItem;

	for (NSMenuItem *aMenuItem in [selectEncodingMenu itemArray]) {
		correctStateForMenuItem = ([aMenuItem tag] == itemToSelect) ? NSOnState : NSOffState;

		if ([aMenuItem state] == correctStateForMenuItem) continue; // don't re-apply state incase it causes performance issues

		[aMenuItem setState:correctStateForMenuItem];
	}
}

/**
 * Returns the display name for a mysql encoding
 */
- (NSNumber *)encodingTagFromMySQLEncoding:(NSString *)mysqlEncoding
{
	NSDictionary *translationMap = @{
		@"ucs2"     : @(SPEncodingUCS2),
		@"utf8"     : @(SPEncodingUTF8),
		@"utf8-"    : @(SPEncodingUTF8viaLatin1),
		@"ascii"    : @(SPEncodingASCII),
		@"latin1"   : @(SPEncodingLatin1),
		@"macroman" : @(SPEncodingMacRoman),
		@"cp1250"   : @(SPEncodingCP1250Latin2),
		@"latin2"   : @(SPEncodingISOLatin2),
		@"cp1256"   : @(SPEncodingCP1256Arabic),
		@"greek"    : @(SPEncodingGreek),
		@"hebrew"   : @(SPEncodingHebrew),
		@"latin5"   : @(SPEncodingLatin5Turkish),
		@"cp1257"   : @(SPEncodingCP1257WinBaltic),
		@"cp1251"   : @(SPEncodingCP1251WinCyrillic),
		@"big5"     : @(SPEncodingBig5Chinese),
		@"sjis"     : @(SPEncodingShiftJISJapanese),
		@"ujis"     : @(SPEncodingEUCJPJapanese),
		@"euckr"    : @(SPEncodingEUCKRKorean),
		@"utf8mb4"  : @(SPEncodingUTF8MB4)
	};
	NSNumber *encodingTag = [translationMap valueForKey:mysqlEncoding];

	if (!encodingTag)
		return @(SPEncodingAutodetect);

	return encodingTag;
}

/**
 * Returns the mysql encoding for an encoding string that is displayed to the user
 */
- (NSString *)mysqlEncodingFromEncodingTag:(NSNumber *)encodingTag
{
	NSDictionary *translationMap = [NSDictionary dictionaryWithObjectsAndKeys:
									@"ucs2",     [NSString stringWithFormat:@"%i", SPEncodingUCS2],
									@"utf8",     [NSString stringWithFormat:@"%i", SPEncodingUTF8],
									@"utf8-",    [NSString stringWithFormat:@"%i", SPEncodingUTF8viaLatin1],
									@"ascii",    [NSString stringWithFormat:@"%i", SPEncodingASCII],
									@"latin1",   [NSString stringWithFormat:@"%i", SPEncodingLatin1],
									@"macroman", [NSString stringWithFormat:@"%i", SPEncodingMacRoman],
									@"cp1250",   [NSString stringWithFormat:@"%i", SPEncodingCP1250Latin2],
									@"latin2",   [NSString stringWithFormat:@"%i", SPEncodingISOLatin2],
									@"cp1256",   [NSString stringWithFormat:@"%i", SPEncodingCP1256Arabic],
									@"greek",    [NSString stringWithFormat:@"%i", SPEncodingGreek],
									@"hebrew",   [NSString stringWithFormat:@"%i", SPEncodingHebrew],
									@"latin5",   [NSString stringWithFormat:@"%i", SPEncodingLatin5Turkish],
									@"cp1257",   [NSString stringWithFormat:@"%i", SPEncodingCP1257WinBaltic],
									@"cp1251",   [NSString stringWithFormat:@"%i", SPEncodingCP1251WinCyrillic],
									@"big5",     [NSString stringWithFormat:@"%i", SPEncodingBig5Chinese],
									@"sjis",     [NSString stringWithFormat:@"%i", SPEncodingShiftJISJapanese],
									@"ujis",     [NSString stringWithFormat:@"%i", SPEncodingEUCJPJapanese],
									@"euckr",    [NSString stringWithFormat:@"%i", SPEncodingEUCKRKorean],
									@"utf8mb4",  [NSString stringWithFormat:@"%i", SPEncodingUTF8MB4],
									nil];
	NSString *mysqlEncoding = [translationMap valueForKey:[NSString stringWithFormat:@"%i", [encodingTag intValue]]];

	if (!mysqlEncoding) return @"utf8";

	return mysqlEncoding;
}

/**
 * Retrieve the current database encoding.  This will return Latin-1
 * for unknown encodings.
 */
- (NSString *)databaseEncoding
{
	return selectedDatabaseEncoding;
}

/**
 * Detect and store the encoding of the currently selected database.
 * Falls back to Latin-1 if the encoding cannot be retrieved.
 */
- (void)detectDatabaseEncoding
{
	_supportsEncoding = YES;

	NSString *mysqlEncoding = [[databaseDataInstance getDatabaseDefaultCharacterSet] retain];

	SPClear(selectedDatabaseEncoding);

	// Fallback or older version? -> set encoding to mysql default encoding latin1
	if ( !mysqlEncoding ) {
		NSLog(@"Error: no character encoding found for db, mysql version is %@", [self mySQLVersion]);
		
		selectedDatabaseEncoding = [[NSString alloc] initWithString:@"latin1"];
		
		_supportsEncoding = NO;
	} 
	else {
		selectedDatabaseEncoding = mysqlEncoding;
	}
}

/**
 * When sent by an NSMenuItem, will set the encoding based on the title of the menu item
 */
- (IBAction)chooseEncoding:(id)sender
{
	[self setConnectionEncoding:[self mysqlEncodingFromEncodingTag:[NSNumber numberWithInteger:[(NSMenuItem *)sender tag]]] reloadingViews:YES];
}

/**
 * return YES if MySQL server supports choosing connection and table encodings (MySQL 4.1 and newer)
 */
- (BOOL)supportsEncoding
{
	return _supportsEncoding;
}

#pragma mark -
#pragma mark Table Methods
#ifndef SP_CODA /* whole table operations */

/**
 * Copies if sender == self or displays or the CREATE TABLE syntax of the selected table(s) to the user .
 */
- (IBAction)showCreateTableSyntax:(id)sender
{
	NSInteger colOffs = 1;
	NSString *query = nil;
	NSString *typeString = @"";
	NSString *header = @"";
	NSMutableString *createSyntax = [NSMutableString string];

	NSIndexSet *indexes = [[tablesListInstance valueForKeyPath:@"tablesListView"] selectedRowIndexes];

	NSUInteger currentIndex = [indexes firstIndex];
	NSUInteger counter = 0;
	NSInteger type;

	NSArray *types = [tablesListInstance selectedTableTypes];
	NSArray *items = [tablesListInstance selectedTableItems];

	while (currentIndex != NSNotFound)
	{
		type = [[types objectAtIndex:counter] intValue];
		query = nil;

		if( type == SPTableTypeTable ) {
			query = [NSString stringWithFormat:@"SHOW CREATE TABLE %@", [[items objectAtIndex:counter] backtickQuotedString]];
			typeString = @"TABLE";
		}
		else if( type == SPTableTypeView ) {
			query = [NSString stringWithFormat:@"SHOW CREATE VIEW %@", [[items objectAtIndex:counter] backtickQuotedString]];
			typeString = @"VIEW";
		}
		else if( type == SPTableTypeProc ) {
			query = [NSString stringWithFormat:@"SHOW CREATE PROCEDURE %@", [[items objectAtIndex:counter] backtickQuotedString]];
			typeString = @"PROCEDURE";
			colOffs = 2;
		}
		else if( type == SPTableTypeFunc ) {
			query = [NSString stringWithFormat:@"SHOW CREATE FUNCTION %@", [[items objectAtIndex:counter] backtickQuotedString]];
			typeString = @"FUNCTION";
			colOffs = 2;
		}

		if (query == nil) {
			NSLog(@"Unknown type for selected item while getting the create syntax for '%@'", [items objectAtIndex:counter]);
			NSBeep();
			return;
		}

		SPMySQLResult *theResult = [mySQLConnection queryString:query];
		[theResult setReturnDataAsStrings:YES];

		// Check for errors, only displaying if the connection hasn't been terminated
		if ([mySQLConnection queryErrored]) {
			if ([mySQLConnection isConnected]) {
				SPOnewayAlertSheet(
					NSLocalizedString(@"Error", @"error message title"), 
					parentWindow, 
					[NSString stringWithFormat:NSLocalizedString(@"An error occured while creating table syntax.\n\n: %@", @"Error shown when unable to show create table syntax"), [mySQLConnection lastErrorMessage]]
				);
			}

			return;
		}

		NSString *tableSyntax;
		if (type == SPTableTypeProc) tableSyntax = [NSString stringWithFormat:@"DELIMITER ;;\n%@;;\nDELIMITER ", [[theResult getRowAsArray] objectAtIndex:colOffs]];
		else                         tableSyntax = [[theResult getRowAsArray] objectAtIndex:colOffs];

		// A NULL value indicates that the user does not have permission to view the syntax
		if ([tableSyntax isNSNull]) {
			SPOnewayAlertSheet(
				NSLocalizedString(@"Permission Denied", @"Permission Denied"), 
				parentWindow,
				NSLocalizedString(@"The creation syntax could not be retrieved due to a permissions error.\n\nPlease check your user permissions with an administrator.", @"Create syntax permission denied detail")
			);
			return;
		}

		if([indexes count] > 1)
			header = [NSString stringWithFormat:@"-- Create syntax for %@ '%@'\n", typeString, [items objectAtIndex:counter]];

		[createSyntax appendFormat:@"%@%@;%@", header, (type == SPTableTypeView) ? [tableSyntax createViewSyntaxPrettifier] : tableSyntax, (counter < [indexes count]-1) ? @"\n\n" : @""];

		counter++;
		
		// Get next index (beginning from the end)
		currentIndex = [indexes indexGreaterThanIndex:currentIndex];

	}
	
	// copy to the clipboard if sender was self, otherwise
	// show syntax(es) in sheet
	if (sender == self) {
		NSPasteboard *pb = [NSPasteboard generalPasteboard];
		[pb declareTypes:@[NSStringPboardType] owner:self];
		[pb setString:createSyntax forType:NSStringPboardType];

		// Table syntax copied Growl notification
		[[SPGrowlController sharedGrowlController] notifyWithTitle:@"Syntax Copied"
		                                               description:[NSString stringWithFormat:NSLocalizedString(@"Syntax for %@ table copied", @"description for table syntax copied growl notification"), [self table]]
		                                                  document:self
		                                          notificationName:@"Syntax Copied"];

		return;
	}
	
	if ([indexes count] == 1) [createTableSyntaxTextField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Create syntax for %@ '%@'", @"Create syntax label"), typeString, [self table]]];
	else                      [createTableSyntaxTextField setStringValue:NSLocalizedString(@"Create syntaxes for selected items", @"Create syntaxes for selected items label")];
		
	[createTableSyntaxTextView setEditable:YES];
	[createTableSyntaxTextView setString:@""];
	[createTableSyntaxTextView insertText:createSyntax];
	[createTableSyntaxTextView setEditable:NO];

	[createTableSyntaxWindow makeFirstResponder:createTableSyntaxTextField];

	// Show variables sheet
	[NSApp beginSheet:createTableSyntaxWindow
	   modalForWindow:parentWindow
	    modalDelegate:self
	   didEndSelector:nil
	      contextInfo:nil];

}

/**
 * Copies the CREATE TABLE syntax of the selected table to the pasteboard.
 */
- (IBAction)copyCreateTableSyntax:(id)sender
{
	[self showCreateTableSyntax:self];
	
	return;
}

/**
 * Performs a MySQL check table on the selected table and presents the result to the user via an alert sheet.
 */
- (IBAction)checkTable:(id)sender
{
	NSArray *selectedItems = [tablesListInstance selectedTableItems];
	id message = nil;
	
	if([selectedItems count] == 0) return;

	SPMySQLResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"CHECK TABLE %@", [selectedItems componentsJoinedAndBacktickQuoted]]];
	[theResult setReturnDataAsStrings:YES];

	NSString *what = ([selectedItems count]>1) ? NSLocalizedString(@"selected items", @"selected items") : [NSString stringWithFormat:@"%@ '%@'", NSLocalizedString(@"table", @"table"), [self table]];

	// Check for errors, only displaying if the connection hasn't been terminated
	if ([mySQLConnection queryErrored]) {
		NSString *mText = ([selectedItems count]>1) ? NSLocalizedString(@"Unable to check selected items", @"unable to check selected items message") : NSLocalizedString(@"Unable to check table", @"unable to check table message");
		if ([mySQLConnection isConnected]) {
			SPOnewayAlertSheet(
				mText,
				parentWindow,
				[NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to check the %@.\n\nMySQL said:%@",@"an error occurred while trying to check the %@.\n\nMySQL said:%@"), what, [mySQLConnection lastErrorMessage]]
			);
		}

		return;
	}

	NSArray *resultStatuses = [theResult getAllRows];
	BOOL statusOK = YES;
	for (NSDictionary *eachRow in theResult) {
		if (![[eachRow objectForKey:@"Msg_type"] isEqualToString:@"status"]) {
			statusOK = NO;
			break;
		}
	}

	// Process result
	if([selectedItems count] == 1) {
		NSDictionary *lastresult = [resultStatuses lastObject];

		message = ([[lastresult objectForKey:@"Msg_type"] isEqualToString:@"status"]) ? NSLocalizedString(@"Check table successfully passed.",@"check table successfully passed message") : NSLocalizedString(@"Check table failed.", @"check table failed message");

		message = [NSString stringWithFormat:NSLocalizedString(@"%@\n\nMySQL said: %@", @"Error display text, showing original MySQL error"), message, [lastresult objectForKey:@"Msg_text"]];
	} else if(statusOK) {
		message = NSLocalizedString(@"Check of all selected items successfully passed.",@"check of all selected items successfully passed message");
	}
	
	if(message) {
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Check %@", @"CHECK one or more tables - result title"), what]
		                                 defaultButton:@"OK"
		                               alternateButton:nil
		                                   otherButton:nil
		                     informativeTextWithFormat:@"%@", message];
		[alert beginSheetModalForWindow:parentWindow
		                  modalDelegate:self
		                 didEndSelector:NULL
		                    contextInfo:NULL];
	} else {
		message = NSLocalizedString(@"MySQL said:",@"mysql said message");
		if (statusValues) SPClear(statusValues);
		statusValues = [resultStatuses retain];
		NSAlert *alert = [[NSAlert new] autorelease];
		[alert setInformativeText:message];
		[alert setMessageText:NSLocalizedString(@"Error while checking selected items", @"error while checking selected items message")];
		[alert setAccessoryView:statusTableAccessoryView];
		[alert beginSheetModalForWindow:parentWindow
		                  modalDelegate:self
		                 didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		                    contextInfo:@"statusError"];
	}
}

/**
 * Analyzes the selected table and presents the result to the user via an alert sheet.
 */
- (IBAction)analyzeTable:(id)sender
{
	NSArray *selectedItems = [tablesListInstance selectedTableItems];
	id message = nil;
	
	if([selectedItems count] == 0) return;

	SPMySQLResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"ANALYZE TABLE %@", [selectedItems componentsJoinedAndBacktickQuoted]]];
	[theResult setReturnDataAsStrings:YES];

	NSString *what = ([selectedItems count]>1) ? NSLocalizedString(@"selected items", @"selected items") : [NSString stringWithFormat:@"%@ '%@'", NSLocalizedString(@"table", @"table"), [self table]];

	// Check for errors, only displaying if the connection hasn't been terminated
	if ([mySQLConnection queryErrored]) {
		NSString *mText = ([selectedItems count]>1) ? NSLocalizedString(@"Unable to analyze selected items", @"unable to analyze selected items message") : NSLocalizedString(@"Unable to analyze table", @"unable to analyze table message");
		if ([mySQLConnection isConnected]) {
			SPOnewayAlertSheet(
				mText,
				parentWindow,
				[NSString stringWithFormat:NSLocalizedString(@"An error occurred while analyzing the %@.\n\nMySQL said:%@",@"an error occurred while analyzing the %@.\n\nMySQL said:%@"), what, [mySQLConnection lastErrorMessage]]
			);
		}

		return;
	}

	NSArray *resultStatuses = [theResult getAllRows];
	BOOL statusOK = YES;
	for (NSDictionary *eachRow in resultStatuses) {
		if(![[eachRow objectForKey:@"Msg_type"] isEqualToString:@"status"]) {
			statusOK = NO;
			break;
		}
	}

	// Process result
	if([selectedItems count] == 1) {
		NSDictionary *lastresult = [resultStatuses lastObject];

		message = ([[lastresult objectForKey:@"Msg_type"] isEqualToString:@"status"]) ? NSLocalizedString(@"Successfully analyzed table.",@"analyze table successfully passed message") : NSLocalizedString(@"Analyze table failed.", @"analyze table failed message");

		message = [NSString stringWithFormat:NSLocalizedString(@"%@\n\nMySQL said: %@", @"Error display text, showing original MySQL error"), message, [lastresult objectForKey:@"Msg_text"]];
	} else if(statusOK) {
		message = NSLocalizedString(@"Successfully analyzed all selected items.",@"successfully analyzed all selected items message");
	}
	
	if(message) {
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Analyze %@", @"ANALYZE one or more tables - result title"), what]
		                                 defaultButton:@"OK"
		                               alternateButton:nil
		                                   otherButton:nil
		                     informativeTextWithFormat:@"%@", message];
		[alert beginSheetModalForWindow:parentWindow
		                  modalDelegate:self
		                 didEndSelector:NULL
		                    contextInfo:NULL];
	} else {
		message = NSLocalizedString(@"MySQL said:",@"mysql said message");
		if (statusValues) SPClear(statusValues);
		statusValues = [resultStatuses retain];
		NSAlert *alert = [[NSAlert new] autorelease];
		[alert setInformativeText:message];
		[alert setMessageText:NSLocalizedString(@"Error while analyzing selected items", @"error while analyzing selected items message")];
		[alert setAccessoryView:statusTableAccessoryView];
		[alert beginSheetModalForWindow:parentWindow
		                  modalDelegate:self
		                 didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		                    contextInfo:@"statusError"];
	}
}

/**
 * Optimizes the selected table and presents the result to the user via an alert sheet.
 */
- (IBAction)optimizeTable:(id)sender
{

	NSArray *selectedItems = [tablesListInstance selectedTableItems];
	id message = nil;

	if([selectedItems count] == 0) return;

	SPMySQLResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"OPTIMIZE TABLE %@", [selectedItems componentsJoinedAndBacktickQuoted]]];
	[theResult setReturnDataAsStrings:YES];

	NSString *what = ([selectedItems count]>1) ? NSLocalizedString(@"selected items", @"selected items") : [NSString stringWithFormat:@"%@ '%@'", NSLocalizedString(@"table", @"table"), [self table]];

	// Check for errors, only displaying if the connection hasn't been terminated
	if ([mySQLConnection queryErrored]) {
		NSString *mText = ([selectedItems count]>1) ? NSLocalizedString(@"Unable to optimze selected items", @"unable to optimze selected items message") : NSLocalizedString(@"Unable to optimze table", @"unable to optimze table message");
		if ([mySQLConnection isConnected]) {
			SPOnewayAlertSheet(
				mText,
				parentWindow,
				[NSString stringWithFormat:NSLocalizedString(@"An error occurred while optimzing the %@.\n\nMySQL said:%@",@"an error occurred while trying to optimze the %@.\n\nMySQL said:%@"), what, [mySQLConnection lastErrorMessage]]
			);
		}

		return;
	}

	NSArray *resultStatuses = [theResult getAllRows];
	BOOL statusOK = YES;
	for (NSDictionary *eachRow in resultStatuses) {
		if (![[eachRow objectForKey:@"Msg_type"] isEqualToString:@"status"]) {
			statusOK = NO;
			break;
		}
	}

	// Process result
	if([selectedItems count] == 1) {
		NSDictionary *lastresult = [resultStatuses lastObject];

		message = ([[lastresult objectForKey:@"Msg_type"] isEqualToString:@"status"]) ? NSLocalizedString(@"Successfully optimized table.",@"optimize table successfully passed message") : NSLocalizedString(@"Optimize table failed.", @"optimize table failed message");

		message = [NSString stringWithFormat:NSLocalizedString(@"%@\n\nMySQL said: %@", @"Error display text, showing original MySQL error"), message, [lastresult objectForKey:@"Msg_text"]];
	} else if(statusOK) {
		message = NSLocalizedString(@"Successfully optimized all selected items.",@"successfully optimized all selected items message");
	}

	if(message) {
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Optimize %@", @"OPTIMIZE one or more tables - result title"), what]
		                                 defaultButton:@"OK"
		                               alternateButton:nil
		                                   otherButton:nil
		                     informativeTextWithFormat:@"%@", message];
		[alert beginSheetModalForWindow:parentWindow
		                  modalDelegate:self
		                 didEndSelector:NULL
		                    contextInfo:NULL];
	} else {
		message = NSLocalizedString(@"MySQL said:",@"mysql said message");
		if (statusValues) SPClear(statusValues);
		statusValues = [resultStatuses retain];
		NSAlert *alert = [[NSAlert new] autorelease];
		[alert setInformativeText:message];
		[alert setMessageText:NSLocalizedString(@"Error while optimizing selected items", @"error while optimizing selected items message")];
		[alert setAccessoryView:statusTableAccessoryView];
		[alert beginSheetModalForWindow:parentWindow
		                  modalDelegate:self
		                 didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		                    contextInfo:@"statusError"];
	}
}

/**
 * Repairs the selected table and presents the result to the user via an alert sheet.
 */
- (IBAction)repairTable:(id)sender
{
	NSArray *selectedItems = [tablesListInstance selectedTableItems];
	id message = nil;

	if([selectedItems count] == 0) return;

	SPMySQLResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"REPAIR TABLE %@", [selectedItems componentsJoinedAndBacktickQuoted]]];
	[theResult setReturnDataAsStrings:YES];

	NSString *what = ([selectedItems count]>1) ? NSLocalizedString(@"selected items", @"selected items") : [NSString stringWithFormat:@"%@ '%@'", NSLocalizedString(@"table", @"table"), [self table]];

	// Check for errors, only displaying if the connection hasn't been terminated
	if ([mySQLConnection queryErrored]) {
		NSString *mText = ([selectedItems count]>1) ? NSLocalizedString(@"Unable to repair selected items", @"unable to repair selected items message") : NSLocalizedString(@"Unable to repair table", @"unable to repair table message");
		if ([mySQLConnection isConnected]) {
			SPOnewayAlertSheet(
				mText,
				parentWindow,
				[NSString stringWithFormat:NSLocalizedString(@"An error occurred while repairing the %@.\n\nMySQL said:%@",@"an error occurred while trying to repair the %@.\n\nMySQL said:%@"), what, [mySQLConnection lastErrorMessage]]
			);
		}

		return;
	}

	NSArray *resultStatuses = [theResult getAllRows];
	BOOL statusOK = YES;
	for (NSDictionary *eachRow in resultStatuses) {
		if (![[eachRow objectForKey:@"Msg_type"] isEqualToString:@"status"]) {
			statusOK = NO;
			break;
		}
	}

	// Process result
	if([selectedItems count] == 1) {
		NSDictionary *lastresult = [resultStatuses lastObject];

		message = ([[lastresult objectForKey:@"Msg_type"] isEqualToString:@"status"]) ? NSLocalizedString(@"Successfully repaired table.",@"repair table successfully passed message") : NSLocalizedString(@"Repair table failed.", @"repair table failed message");

		message = [NSString stringWithFormat:NSLocalizedString(@"%@\n\nMySQL said: %@", @"Error display text, showing original MySQL error"), message, [lastresult objectForKey:@"Msg_text"]];
	} else if(statusOK) {
		message = NSLocalizedString(@"Successfully repaired all selected items.",@"successfully repaired all selected items message");
	}

	if(message) {
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Repair %@", @"REPAIR one or more tables - result title"), what]
		                                 defaultButton:@"OK"
		                               alternateButton:nil
		                                   otherButton:nil
		                     informativeTextWithFormat:@"%@", message];
		[alert beginSheetModalForWindow:parentWindow
		                  modalDelegate:nil
		                 didEndSelector:NULL
		                    contextInfo:NULL];
	} else {
		message = NSLocalizedString(@"MySQL said:",@"mysql said message");
		if (statusValues) SPClear(statusValues);
		statusValues = [resultStatuses retain];
		NSAlert *alert = [[NSAlert new] autorelease];
		[alert setInformativeText:message];
		[alert setMessageText:NSLocalizedString(@"Error while repairing selected items", @"error while repairing selected items message")];
		[alert setAccessoryView:statusTableAccessoryView];
		[alert beginSheetModalForWindow:parentWindow
		                  modalDelegate:self
		                 didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		                    contextInfo:@"statusError"];
	}
}

/**
 * Flush the selected table and inform the user via a dialog sheet.
 */
- (IBAction)flushTable:(id)sender
{
	NSArray *selectedItems = [tablesListInstance selectedTableItems];
	id message = nil;

	if([selectedItems count] == 0) return;

	SPMySQLResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"FLUSH TABLE %@", [selectedItems componentsJoinedAndBacktickQuoted]]];
	[theResult setReturnDataAsStrings:YES];

	NSString *what = ([selectedItems count]>1) ? NSLocalizedString(@"selected items", @"selected items") : [NSString stringWithFormat:@"%@ '%@'", NSLocalizedString(@"table", @"table"), [self table]];

	// Check for errors, only displaying if the connection hasn't been terminated
	if ([mySQLConnection queryErrored]) {
		NSString *mText = ([selectedItems count]>1) ? NSLocalizedString(@"Unable to flush selected items", @"unable to flush selected items message") : NSLocalizedString(@"Unable to flush table", @"unable to flush table message");
		if ([mySQLConnection isConnected]) {
			SPOnewayAlertSheet(
				mText,
				parentWindow,
				[NSString stringWithFormat:NSLocalizedString(@"An error occurred while flushing the %@.\n\nMySQL said:%@",@"an error occurred while trying to flush the %@.\n\nMySQL said:%@"), what, [mySQLConnection lastErrorMessage]]
			);
		}

		return;
	}

	NSArray *resultStatuses = [theResult getAllRows];
	BOOL statusOK = YES;
	for (NSDictionary *eachRow in resultStatuses) {
		if (![[eachRow objectForKey:@"Msg_type"] isEqualToString:@"status"]) {
			statusOK = NO;
			break;
		}
	}

	// Process result
	if([selectedItems count] == 1) {
		NSDictionary *lastresult = [resultStatuses lastObject];

		message = ([[lastresult objectForKey:@"Msg_type"] isEqualToString:@"status"]) ? NSLocalizedString(@"Successfully flushed table.",@"flush table successfully passed message") : NSLocalizedString(@"Flush table failed.", @"flush table failed message");

		message = [NSString stringWithFormat:NSLocalizedString(@"%@\n\nMySQL said: %@", @"Error display text, showing original MySQL error"), message, [lastresult objectForKey:@"Msg_text"]];
	} else if(statusOK) {
		message = NSLocalizedString(@"Successfully flushed all selected items.",@"successfully flushed all selected items message");
	}

	if(message) {
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Flush %@", @"FLUSH one or more tables - result title"), what]
		                                 defaultButton:@"OK"
		                               alternateButton:nil
		                                   otherButton:nil
		                     informativeTextWithFormat:@"%@", message];
		[alert beginSheetModalForWindow:parentWindow
		                  modalDelegate:self
		                 didEndSelector:NULL
		                    contextInfo:NULL];
	} else {
		message = NSLocalizedString(@"MySQL said:",@"mysql said message");
		if (statusValues) SPClear(statusValues);
		statusValues = [resultStatuses retain];
		NSAlert *alert = [[NSAlert new] autorelease];
		[alert setInformativeText:message];
		[alert setMessageText:NSLocalizedString(@"Error while flushing selected items", @"error while flushing selected items message")];
		[alert setAccessoryView:statusTableAccessoryView];
		[alert beginSheetModalForWindow:parentWindow
		                  modalDelegate:self
		                 didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		                    contextInfo:@"statusError"];
	}
}

/**
 * Runs a MySQL checksum on the selected table and present the result to the user via an alert sheet.
 */
- (IBAction)checksumTable:(id)sender
{
	NSArray *selectedItems = [tablesListInstance selectedTableItems];
	id message = nil;

	if([selectedItems count] == 0) return;

	SPMySQLResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"CHECKSUM TABLE %@", [selectedItems componentsJoinedAndBacktickQuoted]]];

	NSString *what = ([selectedItems count]>1) ? NSLocalizedString(@"selected items", @"selected items") : [NSString stringWithFormat:@"%@ '%@'", NSLocalizedString(@"table", @"table"), [self table]];

	// Check for errors, only displaying if the connection hasn't been terminated
	if ([mySQLConnection queryErrored]) {
		if ([mySQLConnection isConnected]) {
			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Unable to perform the checksum", @"unable to perform the checksum")
			                                 defaultButton:@"OK"
			                               alternateButton:nil
			                                   otherButton:nil
			                     informativeTextWithFormat:NSLocalizedString(@"An error occurred while performing the checksum on %@.\n\nMySQL said:%@",@"an error occurred while performing the checksum on the %@.\n\nMySQL said:%@"), what, [mySQLConnection lastErrorMessage]];
			[alert beginSheetModalForWindow:parentWindow
			                  modalDelegate:nil
			                 didEndSelector:NULL
			                    contextInfo:NULL];
		}

		return;
	}

	// Process result
	NSArray *resultStatuses = [theResult getAllRows];
	if([selectedItems count] == 1) {
		message = [[resultStatuses lastObject] objectForKey:@"Checksum"];
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Checksum %@", @"checksum %@ message"), what]
		                                 defaultButton:@"OK"
		                               alternateButton:nil
		                                   otherButton:nil
		                     informativeTextWithFormat:NSLocalizedString(@"Table checksum: %@", @"table checksum: %@"), message];
		[alert beginSheetModalForWindow:parentWindow
		                  modalDelegate:nil
		                 didEndSelector:NULL
		                    contextInfo:NULL];
	} else {
		if (statusValues) SPClear(statusValues);
		statusValues = [resultStatuses retain];
		NSAlert *alert = [[NSAlert new] autorelease];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Checksums of %@",@"Checksums of %@ message"), what]];
		[alert setMessageText:NSLocalizedString(@"Table checksum",@"table checksum message")];
		[alert setAccessoryView:statusTableAccessoryView];
		[alert beginSheetModalForWindow:parentWindow
		                  modalDelegate:self
		                 didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		                    contextInfo:@"statusError"];
	}
}

/**
 * Saves the current tables create syntax to the selected file.
 */
- (IBAction)saveCreateSyntax:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];

	[panel setAllowedFileTypes:@[SPFileExtensionSQL]];

	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:YES];
	[panel setCanSelectHiddenExtension:YES];

	[panel setNameFieldStringValue:[NSString stringWithFormat:@"CreateSyntax-%@", [self table]]];
	[panel beginSheetModalForWindow:createTableSyntaxWindow completionHandler:^(NSInteger returnCode) {
		if (returnCode == NSOKButton) {
			NSString *createSyntax = [createTableSyntaxTextView string];

			if ([createSyntax length] > 0) {
				NSString *output = [NSString stringWithFormat:@"-- %@ '%@'\n\n%@\n", NSLocalizedString(@"Create syntax for", @"create syntax for table comment"), [self table], createSyntax];

				[output writeToURL:[panel URL] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
			}
		}
	}];
}

/**
 * Copy the create syntax in the create syntax text view to the pasteboard.
 */
- (IBAction)copyCreateTableSyntaxFromSheet:(id)sender
{
	NSString *createSyntax = [createTableSyntaxTextView string];

	if ([createSyntax length] > 0) {
		// Copy to the clipboard
		NSPasteboard *pb = [NSPasteboard generalPasteboard];

		[pb declareTypes:@[NSStringPboardType] owner:self];
		[pb setString:createSyntax forType:NSStringPboardType];

		// Table syntax copied Growl notification
		[[SPGrowlController sharedGrowlController] notifyWithTitle:@"Syntax Copied"
		                                               description:[NSString stringWithFormat:NSLocalizedString(@"Syntax for %@ table copied", @"description for table syntax copied growl notification"), [self table]]
		                                                  document:self
		                                          notificationName:@"Syntax Copied"];
	}
}

/**
 * Switches to the content view and makes the filter field the first responder (has focus).
 */
- (IBAction)focusOnTableContentFilter:(id)sender
{
	[self viewContent:self];
	
	[tableContentInstance performSelector:@selector(makeContentFilterHaveFocus) withObject:nil afterDelay:0.1];
}

/**
 * Switches to the content view and makes the advanced filter view the first responder
 */
- (IBAction)showFilterTable:(id)sender
{
	[self viewContent:self];
	
	[tableContentInstance performSelector:@selector(showFilterTable:) withObject:sender afterDelay:0.1];
}

/**
 * Allow Command-F to set the focus to the content view filter if that view is active
 */
- (void)performFindPanelAction:(id)sender
{
	if ([sender tag] == 1 && [[self selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableContent]) {
		[tableContentInstance makeContentFilterHaveFocus];
	}
}

/**
 * Exports the selected tables in the chosen file format.
 */
- (IBAction)exportSelectedTablesAs:(id)sender
{
	[exportControllerInstance exportTables:[tablesListInstance selectedTableItems] asFormat:[sender tag] usingSource:SPTableExport];
}

/**
 * Opens the data export dialog.
 */
- (IBAction)export:(id)sender
{
	[exportControllerInstance export:self];
}

#pragma mark -
#pragma mark Other Methods

/**
 * Set that query which will be inserted into the Query Editor
 * after establishing the connection
 */

- (void)initQueryEditorWithString:(NSString *)query
{
	queryEditorInitString = [query retain];
}
#endif

/**
 * Invoked when user hits the cancel button or close button in
 * dialogs such as the variableSheet or the createTableSyntaxSheet
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp stopModalWithCode:0];
}

/**
 * Closes either the server variables or create syntax sheets.
 */
- (IBAction)closePanelSheet:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

#ifndef SP_CODA
/**
 * Displays the user account manager.
 */
- (IBAction)showUserManager:(id)sender
{	
	if (!userManagerInstance)
	{
		userManagerInstance = [[SPUserManager alloc] init];
		
		[userManagerInstance setDatabaseDocument:self];
		[userManagerInstance setConnection:mySQLConnection];
		[userManagerInstance setServerSupport:serverSupport];
	}

	// Before displaying the user manager make sure the current user has access to the mysql.user table.
	SPMySQLResult *result = [mySQLConnection queryString:@"SELECT user FROM mysql.user LIMIT 1"];
	
	if ([mySQLConnection queryErrored] && ([result numberOfRows] == 0)) {

		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Unable to get list of users", @"unable to get list of users message")
		                                 defaultButton:NSLocalizedString(@"OK", @"OK button")
		                               alternateButton:nil
		                                   otherButton:nil
		                     informativeTextWithFormat:NSLocalizedString(@"An error occurred while trying to get the list of users. Please make sure you have the necessary privileges to perform user management, including access to the mysql.user table.", @"unable to get list of users informative message")];
		
		[alert setAlertStyle:NSCriticalAlertStyle];
		
		[alert beginSheetModalForWindow:parentWindow
		                  modalDelegate:self
		                 didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		                    contextInfo:@"cannotremovefield"];
	
		return;
	}
	
	[userManagerInstance beginSheetModalForWindow:parentWindow completionHandler:^(){
		SPClear(userManagerInstance);
	}];
}

/**
 * Passes query to tablesListInstance
 */
- (void)doPerformQueryService:(NSString *)query
{
	[parentWindow makeKeyAndOrderFront:self];
	[self viewQuery:nil];
	[customQueryInstance doPerformQueryService:query];
}

/**
 * Inserts query into the Custom Query editor
 */
- (void)doPerformLoadQueryService:(NSString *)query
{
	[self viewQuery:nil];
	[customQueryInstance doPerformLoadQueryService:query];
}

/**
 * Flushes the mysql privileges
 */
- (void)flushPrivileges:(id)sender
{
	[mySQLConnection queryString:@"FLUSH PRIVILEGES"];

	if (![mySQLConnection queryErrored]) {
		//flushed privileges without errors
		SPOnewayAlertSheet(
			NSLocalizedString(@"Flushed Privileges", @"title of panel when successfully flushed privs"),
			parentWindow,
			NSLocalizedString(@"Successfully flushed privileges.", @"message of panel when successfully flushed privs")
		);
	} else {
		//error while flushing privileges
		SPOnewayAlertSheet(
			NSLocalizedString(@"Error", @"error"),
			parentWindow,
			[NSString stringWithFormat:NSLocalizedString(@"Couldn't flush privileges.\nMySQL said: %@", @"message of panel when flushing privs failed"), [mySQLConnection lastErrorMessage]]
		);
	}
}

- (IBAction)openCurrentConnectionInNewWindow:(id)sender
{
	[SPAppDelegate newWindow:self];
	SPDatabaseDocument *newTableDocument = [SPAppDelegate frontDocument];
	[newTableDocument setStateFromConnectionFile:[[self fileURL] path]];
}

#endif

/**
 * Ask the connection controller to initiate connection, if it hasn't
 * already.  Used to support automatic connections on window open,
 */
- (void)connect
{
	if (mySQLVersion) return;
	[connectionController initiateConnection:self];
}

- (void)closeConnection
{
	[mySQLConnection disconnect];
	_isConnected = NO;

#ifndef SP_CODA /* growl */
	// Disconnected Growl notification
	[[SPGrowlController sharedGrowlController] notifyWithTitle:@"Disconnected"
	                                               description:[NSString stringWithFormat:NSLocalizedString(@"Disconnected from %@", @"description for disconnected growl notification"), [parentTabViewItem label]]
	                                                  document:self
	                                          notificationName:@"Disconnected"];
#endif
}

#ifndef SP_CODA /* observeValueForKeyPath: */
/**
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:SPConsoleEnableLogging]) {
		[mySQLConnection setDelegateQueryLogging:[[change objectForKey:NSKeyValueChangeNewKey] boolValue]];
	}
}

- (SPHelpViewerClient *)helpViewerClient
{
	return helpViewerClientInstance;
}

/**
 * Is current document Untitled?
 */
- (BOOL)isUntitled
{
	return (!_isSavedInBundle && [self fileURL] && [[self fileURL] isFileURL]) ? NO : YES;
}
#endif

/**
 * Asks any currently editing views to commit their changes;
 * returns YES if changes were successfully committed, and NO
 * if an error occurred or user interaction is required.
 */
- (BOOL)couldCommitCurrentViewActions
{
	[parentWindow endEditingFor:nil];
#ifndef SP_CODA 
	switch ([self currentlySelectedView]) {

		case SPTableViewStructure:
			return [tableSourceInstance saveRowOnDeselect];

		case SPTableViewContent:
			return [tableContentInstance saveRowOnDeselect];

		default:
			break;
	}
	
	return YES;
#else
	return [tableSourceInstance saveRowOnDeselect] && [tableContentInstance saveRowOnDeselect];
#endif
}

#pragma mark -
#pragma mark Accessor methods

/**
 * Returns the host
 */
- (NSString *)host
{
	if ([connectionController type] == SPSocketConnection) return @"localhost";

	NSString *host = [connectionController host];

	if (!host) host = @"";

	return host;
}

/**
 * Returns the name
 */
- (NSString *)name
{
	if ([connectionController name] && [[connectionController name] length]) {
		return [connectionController name];
	}

	if ([connectionController type] == SPSocketConnection) {
		return [NSString stringWithFormat:@"%@@localhost", ([connectionController user] && [[connectionController user] length])?[connectionController user]:@"anonymous"];
	}

	return [NSString stringWithFormat:@"%@@%@", ([connectionController user] && [[connectionController user] length])?[connectionController user]:@"anonymous", [connectionController host]?[connectionController host]:@""];
}

/**
 * Returns a string to identify the connection uniquely (mainly used to set up db structure with unique keys)
 */
- (NSString *)connectionID
{
	if (!_isConnected) return @"_";

	NSString *port = [[self port] length] ? [NSString stringWithFormat:@":%@", [self port]] : @"";

	switch ([connectionController type])
	{
		case SPSocketConnection:
			return [NSString stringWithFormat:@"%@@localhost%@", ([connectionController user] && [[connectionController user] length])?[connectionController user]:@"anonymous", port];
			break;
		case SPTCPIPConnection:
			return [NSString stringWithFormat:@"%@@%@%@",
			                                  ([connectionController user] && [[connectionController user] length]) ? [connectionController user] : @"anonymous",
			                                  [connectionController host] ? [connectionController host] : @"",
			                                  port];
			break;
		case SPSSHTunnelConnection:
			return [NSString stringWithFormat:@"%@@%@%@&SSH&%@@%@:%@",
			                                  ([connectionController user] && [[connectionController user] length]) ? [connectionController user] : @"anonymous",
			                                  [connectionController host] ? [connectionController host] : @"", port,
			                                  ([connectionController sshUser] && [[connectionController sshUser] length]) ? [connectionController sshUser] : @"anonymous",
			                                  [connectionController sshHost] ? [connectionController sshHost] : @"",
			                                  ([[connectionController sshPort] length]) ? [connectionController sshPort] : @"22"];
	}

	return @"_";
}

/**
 * Returns the full window title which is mainly used for tab tooltips
 */
#ifndef SP_CODA

- (NSString *)tabTitleForTooltip
{
	NSMutableString *tabTitle;

	// Determine name details
	NSString *pathName = @"";
	if ([[[self fileURL] path] length] && ![self isUntitled]) {
		pathName = [NSString stringWithFormat:@"%@ — ", [[[self fileURL] path] lastPathComponent]];
	}

	if ([connectionController isConnecting]) {
		return NSLocalizedString(@"Connecting…", @"window title string indicating that sp is connecting");
	}
	
	if ([self getConnection] == nil) return [NSString stringWithFormat:@"%@%@", pathName, @"Sequel Pro"];

	tabTitle = [NSMutableString string];

#ifndef SP_CODA /* Add the MySQL version to the window title */
	// Add the MySQL version to the window title if enabled in prefs
	if ([prefs boolForKey:SPDisplayServerVersionInWindowTitle]) [tabTitle appendFormat:@"(MySQL %@)\n", [self mySQLVersion]];
#endif

	[tabTitle appendString:[self name]];
	if ([self database]) {
		if ([tabTitle length]) [tabTitle appendString:@"/"];
		[tabTitle appendString:[self database]];
	}
	if ([[self table] length]) {
		if ([tabTitle length]) [tabTitle appendString:@"/"];
		[tabTitle appendString:[self table]];
	}
	return tabTitle;
}

#endif

/**
 * Returns the currently selected database
 */
- (NSString *)database
{
	return selectedDatabase;
}

/**
 * Returns the MySQL version
 */
- (NSString *)mySQLVersion
{
	return mySQLVersion;
}

/**
 * Returns the current user
 */
- (NSString *)user
{
	NSString *theUser = [connectionController user];
	if (!theUser) theUser = @"";
	return theUser;
}

/**
 * Returns the current host's port
 */
- (NSString *)port
{
	NSString *thePort = [connectionController port];
	if (!thePort) return @"";
	return thePort;
}

- (BOOL)isSaveInBundle
{
	return _isSavedInBundle;
}

- (NSArray *)allTableNames
{
	return [tablesListInstance allTableNames];
}

- (SPCreateDatabaseInfo *)createDatabaseInfo
{
	SPCreateDatabaseInfo *dbInfo = [[SPCreateDatabaseInfo alloc] init];
 
	[dbInfo setDatabaseName:[self database]];
	[dbInfo setDefaultEncoding:[databaseDataInstance getDatabaseDefaultCharacterSet]];
	[dbInfo setDefaultCollation:[databaseDataInstance getDatabaseDefaultCollation]];
	
	return [dbInfo autorelease];
}

/**
 * Retrieve the view that is currently selected from the database
 *
 * MUST BE CALLED ON THE UI THREAD!
 */
- (SPTableViewType)currentlySelectedView
{
	SPTableViewType theView = NSNotFound;

	// -selectedTabViewItem is a UI method according to Xcode 9.2!
	NSString *viewName = [[tableTabView selectedTabViewItem] identifier];

	if ([viewName isEqualToString:@"source"]) {
		theView = SPTableViewStructure;
	} else if ([viewName isEqualToString:@"content"]) {
		theView = SPTableViewContent;
	} else if ([viewName isEqualToString:@"customQuery"]) {
		theView = SPTableViewCustomQuery;
	} else if ([viewName isEqualToString:@"status"]) {
		theView = SPTableViewStatus;
	} else if ([viewName isEqualToString:@"relations"]) {
		theView = SPTableViewRelations;
	} else if ([viewName isEqualToString:@"triggers"]) {
		theView = SPTableViewTriggers;
	}

	return theView;
}

#pragma mark -
#pragma mark Notification center methods

/**
 * Invoked before a query is performed
 */
- (void)willPerformQuery:(NSNotification *)notification
{
	[self setIsProcessing:YES];
	[queryProgressBar startAnimation:self];
}

/**
 * Invoked after a query has been performed
 */
- (void)hasPerformedQuery:(NSNotification *)notification
{
	[self setIsProcessing:NO];
	[queryProgressBar stopAnimation:self];
}

/**
 * Invoked when the application will terminate
 */
- (void)applicationWillTerminate:(NSNotification *)notification
{
#ifndef SP_CODA /* applicationWillTerminate: */

	// Auto-save preferences to spf file based connection
	if([self fileURL] && [[[self fileURL] path] length] && ![self isUntitled]) {
		if (_isConnected && ![self saveDocumentWithFilePath:nil inBackground:YES onlyPreferences:YES contextInfo:nil]) {
			NSLog(@"Preference data for file ‘%@’ could not be saved.", [[self fileURL] path]);
			NSBeep();
		}
	}

	[tablesListInstance selectionShouldChangeInTableView:nil];

	// Note that this call does not need to be removed in release builds as leaks analysis output is only
	// dumped if [[SPLogger logger] setDumpLeaksOnTermination]; has been called first.
	[[SPLogger logger] dumpLeaks];
#endif
}

#pragma mark -
#pragma mark Menu methods

#ifndef SP_CODA 
/**
 * Saves SP session or if Custom Query tab is active the editor's content as SQL file
 * If sender == nil then the call came from [self writeSafelyToURL:ofType:forSaveOperation:error]
 */
- (IBAction)saveConnectionSheet:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	NSString *filename;
	NSString *contextInfo;

	[panel setAllowsOtherFileTypes:NO];
	[panel setCanSelectHiddenExtension:YES];

	// Save Query...
	if (sender != nil && ([sender tag] == SPMainMenuFileSaveQuery || [sender tag] == SPMainMenuFileSaveQueryAs)) {

		// If Save was invoked, check whether the file was previously opened, and if so save without the panel
		if ([sender tag] == SPMainMenuFileSaveQuery && [[[self sqlFileURL] path] length]) {
			NSError *error = nil;
			NSString *content = [NSString stringWithString:[[[customQueryInstance valueForKeyPath:@"textView"] textStorage] string]];
			[content writeToURL:sqlFileURL atomically:YES encoding:sqlFileEncoding error:&error];
			return;
		}

		// Save the editor's content as SQL file
		[panel setAccessoryView:[SPEncodingPopupAccessory encodingAccessory:[prefs integerForKey:SPLastSQLFileEncoding]
		                                                includeDefaultEntry:NO
		                                                      encodingPopUp:&encodingPopUp]];

		[panel setAllowedFileTypes:@[SPFileExtensionSQL]];

		if (![prefs stringForKey:@"lastSqlFileName"]) {
			[prefs setObject:@"" forKey:@"lastSqlFileName"];
			[prefs synchronize];
		}

		filename = [prefs stringForKey:@"lastSqlFileName"];
		contextInfo = @"saveSQLfile";

		// If no lastSqlFileEncoding in prefs set it to UTF-8
		if (![prefs integerForKey:SPLastSQLFileEncoding]) {
			[prefs setInteger:4 forKey:SPLastSQLFileEncoding];
			[prefs synchronize];
		}

		[encodingPopUp setEnabled:YES];
	}
	// Save As… or Save
	else if (sender == nil || [sender tag] == SPMainMenuFileSaveConnection || [sender tag] == SPMainMenuFileSaveConnectionAs) {

		// If Save was invoked check for fileURL and Untitled docs and save the spf file without save panel
		// otherwise ask for file name
		if (sender != nil && [sender tag] == SPMainMenuFileSaveConnection && [[[self fileURL] path] length] && ![self isUntitled]) {
			[self saveDocumentWithFilePath:nil inBackground:YES onlyPreferences:NO contextInfo:nil];
			return;
		}

		// Load accessory nib each time.
		// Note that the top-level objects aren't released automatically, but are released when the panel ends.
		if (![NSBundle loadNibNamed:@"SaveSPFAccessory" owner:self]) {
			NSLog(@"SaveSPFAccessory accessory dialog could not be loaded.");
			return;
		}

		// Save current session (open connection windows as SPF file)
		[panel setAllowedFileTypes:@[SPFileExtensionDefault]];

		//Restore accessory view settings if possible
		if ([spfDocData objectForKey:@"save_password"]) {
			[saveConnectionSavePassword setState:[[spfDocData objectForKey:@"save_password"] boolValue]];
		}
		if ([spfDocData objectForKey:@"auto_connect"]) {
			[saveConnectionAutoConnect setState:[[spfDocData objectForKey:@"auto_connect"] boolValue]];
		}
		if ([spfDocData objectForKey:@"encrypted"]) {
			[saveConnectionEncrypt setState:[[spfDocData objectForKey:@"encrypted"] boolValue]];
		}
		if ([spfDocData objectForKey:@"include_session"]) {
			[saveConnectionIncludeData setState:[[spfDocData objectForKey:@"include_session"] boolValue]];
		}
		if ([[spfDocData objectForKey:@"save_editor_content"] boolValue]) {
			[saveConnectionIncludeQuery setState:[[spfDocData objectForKey:@"save_editor_content"] boolValue]];
		}
		else {
			[saveConnectionIncludeQuery setState:NSOnState];
		}

		[saveConnectionIncludeQuery setEnabled:([[[[customQueryInstance valueForKeyPath:@"textView"] textStorage] string] length])];

		// Update accessory button states
		[self validateSaveConnectionAccessory:nil];

		// TODO note: it seems that one has problems with a NSSecureTextField inside an accessory view - ask HansJB
		[[saveConnectionEncryptString cell] setControlView:saveConnectionAccessory];
		[panel setAccessoryView:saveConnectionAccessory];

		// Set file name
		filename = ([[[self fileURL] path] length]) ? [self displayName] : [NSString stringWithFormat:@"%@", [self name]];

		contextInfo = sender == nil ? @"saveSPFfileAndClose" : @"saveSPFfile";
	}
	// Save Session or Save Session As...
	else if (sender == nil || [sender tag] == SPMainMenuFileSaveSession || [sender tag] == SPMainMenuFileSaveSessionAs)
	{
		// Save As Session
		if ([sender tag] == SPMainMenuFileSaveSession && [SPAppDelegate sessionURL]) {
			[self saveConnectionPanelDidEnd:panel returnCode:1 contextInfo:@"saveAsSession"];
			return;
		}

		// Load accessory nib each time.
		// Note that the top-level objects aren't released automatically, but are released when the panel ends.
		if (![NSBundle loadNibNamed:@"SaveSPFAccessory" owner:self]) {
			NSLog(@"SaveSPFAccessory accessory dialog could not be loaded.");
			return;
		}

		[panel setAllowedFileTypes:@[SPBundleFileExtension]];

		NSDictionary *spfSessionData = [SPAppDelegate spfSessionDocData];

		// Restore accessory view settings if possible
		if ([spfSessionData objectForKey:@"save_password"]) {
			[saveConnectionSavePassword setState:[[spfSessionData objectForKey:@"save_password"] boolValue]];
		}
		if ([spfSessionData objectForKey:@"auto_connect"]) {
			[saveConnectionAutoConnect setState:[[spfSessionData objectForKey:@"auto_connect"] boolValue]];
		}
		if ([spfSessionData objectForKey:@"encrypted"]) {
			[saveConnectionEncrypt setState:[[spfSessionData objectForKey:@"encrypted"] boolValue]];
		}
		if ([spfSessionData objectForKey:@"include_session"]) {
			[saveConnectionIncludeData setState:[[spfSessionData objectForKey:@"include_session"] boolValue]];
		}
		if ([[spfSessionData objectForKey:@"save_editor_content"] boolValue]) {
			[saveConnectionIncludeQuery setState:[[spfSessionData objectForKey:@"save_editor_content"] boolValue]];
		}
		else {
			[saveConnectionIncludeQuery setState:YES];
		}

		// Update accessory button states
		[self validateSaveConnectionAccessory:nil];
		[saveConnectionIncludeQuery setEnabled:YES];

		// TODO note: it seems that one has problems with a NSSecureTextField
		// inside an accessory view - ask HansJB
		[[saveConnectionEncryptString cell] setControlView:saveConnectionAccessory];
		[panel setAccessoryView:saveConnectionAccessory];

		// Set file name
		filename = ([SPAppDelegate sessionURL]) ? [[[SPAppDelegate sessionURL] absoluteString] lastPathComponent] : [NSString stringWithFormat:NSLocalizedString(@"Session",@"Initial filename for 'Save session' file")];

		contextInfo = @"saveSession";
	}
	else {
		return;
	}

	[panel setNameFieldStringValue:filename];

	[panel beginSheetModalForWindow:parentWindow completionHandler:^(NSInteger returnCode) {
		[self saveConnectionPanelDidEnd:panel returnCode:returnCode contextInfo:contextInfo];
	}];
}
/**
 * Control the save connection panel's accessory view
 */
- (IBAction)validateSaveConnectionAccessory:(id)sender
{
	// [saveConnectionAutoConnect setEnabled:([saveConnectionSavePassword state] == NSOnState)];
	[saveConnectionSavePasswordAlert setHidden:([saveConnectionSavePassword state] == NSOffState)];

	// If user checks the Encrypt check box set focus to password field
	if (sender == saveConnectionEncrypt && [saveConnectionEncrypt state] == NSOnState) [saveConnectionEncryptString selectText:sender];

	// Unfocus saveConnectionEncryptString
	if (sender == saveConnectionEncrypt && [saveConnectionEncrypt state] == NSOffState) {
		// [saveConnectionEncryptString setStringValue:[saveConnectionEncryptString stringValue]];
		// TODO how can one make it better ?
		[[saveConnectionEncryptString window] makeFirstResponder:[[saveConnectionEncryptString window] initialFirstResponder]];
	}
}

- (void)saveConnectionPanelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[panel orderOut:nil]; // by default OS X hides the panel only after the current method is done
	
	if (returnCode == NSFileHandlingPanelOKButton) {

		NSString *fileName = [[panel URL] path];
		NSError *error = nil;

		// Save file as SQL file by using the chosen encoding
		if(contextInfo == @"saveSQLfile") {

			[prefs setInteger:[[encodingPopUp selectedItem] tag] forKey:SPLastSQLFileEncoding];
			[prefs setObject:[fileName lastPathComponent] forKey:@"lastSqlFileName"];
			[prefs synchronize];

			NSString *content = [NSString stringWithString:[[[customQueryInstance valueForKeyPath:@"textView"] textStorage] string]];
			[content writeToFile:fileName
			          atomically:YES
			            encoding:[[encodingPopUp selectedItem] tag]
			               error:&error];

			if(error != nil) {
				NSAlert *errorAlert = [NSAlert alertWithError:error];
				[errorAlert runModal];
			}

			[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:fileName]];

			return;
		}

		// Save connection and session as SPF file
		else if(contextInfo == @"saveSPFfile" || contextInfo == @"saveSPFfileAndClose") {
			// Save changes of saveConnectionEncryptString
			[[saveConnectionEncryptString window] makeFirstResponder:[[saveConnectionEncryptString window] initialFirstResponder]];

			[self saveDocumentWithFilePath:fileName inBackground:NO onlyPreferences:NO contextInfo:nil];

			// Manually loaded nibs don't have their top-level objects released automatically - do that here.
			[saveConnectionAccessory autorelease];
			saveConnectionAccessory = nil;

			if(contextInfo == @"saveSPFfileAndClose") [self closeAndDisconnect];
		}

		// Save all open windows including all tabs as session
		else if(contextInfo == @"saveSession" || contextInfo == @"saveAsSession") {

			// Sub-folder 'Contents' will contain all untitled connection as single window or tab.
			// info.plist will contain the opened structure (windows and tabs for each window). Each connection
			// is linked to a saved spf file either in 'Contents' for unTitled ones or already saved spf files.

			if(contextInfo == @"saveAsSession" && [SPAppDelegate sessionURL]) fileName = [[SPAppDelegate sessionURL] path];

			if(!fileName || ![fileName length]) return;

			NSFileManager *fileManager = [NSFileManager defaultManager];

			// If bundle exists remove it
			if([fileManager fileExistsAtPath:fileName]) {
				[fileManager removeItemAtPath:fileName error:&error];
				if(error != nil) {
					NSAlert *errorAlert = [NSAlert alertWithError:error];
					[errorAlert runModal];
					return;
				}
			}

			[fileManager createDirectoryAtPath:fileName withIntermediateDirectories:YES attributes:nil error:&error];

			if(error != nil) {
				NSAlert *errorAlert = [NSAlert alertWithError:error];
				[errorAlert runModal];
				return;
			}

			[fileManager createDirectoryAtPath:[NSString stringWithFormat:@"%@/Contents", fileName] withIntermediateDirectories:YES attributes:nil error:&error];

			if(error != nil) {
				NSAlert *errorAlert = [NSAlert alertWithError:error];
				[errorAlert runModal];
				return;
			}

			NSMutableDictionary *info = [NSMutableDictionary dictionary];
			NSMutableArray *windows = [NSMutableArray array];

			// retrieve save panel data for passing them to each doc
			NSMutableDictionary *spfDocData_temp = [NSMutableDictionary dictionary];
			if(contextInfo == @"saveAsSession") {
				[spfDocData_temp addEntriesFromDictionary:[SPAppDelegate spfSessionDocData]];
			} else {
				[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionEncrypt state]==NSOnState) ? YES : NO ] forKey:@"encrypted"];
				if([[spfDocData_temp objectForKey:@"encrypted"] boolValue]) [spfDocData_temp setObject:[saveConnectionEncryptString stringValue] forKey:@"e_string"];
				[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionAutoConnect state]==NSOnState) ? YES : NO ] forKey:@"auto_connect"];
				[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionSavePassword state]==NSOnState) ? YES : NO ] forKey:@"save_password"];
				[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionIncludeData state]==NSOnState) ? YES : NO ] forKey:@"include_session"];
				[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionIncludeQuery state]==NSOnState) ? YES : NO ] forKey:@"save_editor_content"];

				// Save the session's accessory view settings
				[SPAppDelegate setSpfSessionDocData:spfDocData_temp];
			}

			[info setObject:[NSNumber numberWithBool:[[spfDocData_temp objectForKey:@"encrypted"] boolValue]] forKey:@"encrypted"];
			[info setObject:[NSNumber numberWithBool:[[spfDocData_temp objectForKey:@"auto_connect"] boolValue]] forKey:@"auto_connect"];
			[info setObject:[NSNumber numberWithBool:[[spfDocData_temp objectForKey:@"save_password"] boolValue]] forKey:@"save_password"];
			[info setObject:[NSNumber numberWithBool:[[spfDocData_temp objectForKey:@"include_session"] boolValue]] forKey:@"include_session"];
			[info setObject:[NSNumber numberWithBool:[[spfDocData_temp objectForKey:@"save_editor_content"] boolValue]] forKey:@"save_editor_content"];
			[info setObject:@1 forKey:SPFVersionKey];
			[info setObject:@"connection bundle" forKey:SPFFormatKey];

			// Loop through all windows
			for(NSWindow *window in [SPAppDelegate orderedDatabaseConnectionWindows]) {

				// First window is always the currently key window

				NSMutableArray *tabs = [NSMutableArray array];
				NSMutableDictionary *win = [NSMutableDictionary dictionary];
				
				// Loop through all tabs of a given window
				NSInteger tabCount = 0;
				NSInteger selectedTabItem = 0;
				for(SPDatabaseDocument *doc in [[window windowController] documents]) {

					// Skip not connected docs eg if connection controller is displayed (TODO maybe to be improved)
					if(![doc mySQLVersion]) continue;

					NSMutableDictionary *tabData = [NSMutableDictionary dictionary];
					if([doc isUntitled]) {
						// new bundle file name for untitled docs
						NSString *newName = [NSString stringWithFormat:@"%@.%@", [NSString stringWithNewUUID], SPFileExtensionDefault];
						// internal bundle path to store the doc
						NSString *filePath = [NSString stringWithFormat:@"%@/Contents/%@", fileName, newName];
						// save it as temporary spf file inside the bundle with save panel options spfDocData_temp
						[doc saveDocumentWithFilePath:filePath inBackground:NO onlyPreferences:NO contextInfo:[NSDictionary dictionaryWithDictionary:spfDocData_temp]];
						[doc setIsSavedInBundle:YES];
						[tabData setObject:@NO forKey:@"isAbsolutePath"];
						[tabData setObject:newName forKey:@"path"];
					} else {
						// save it to the original location and take the file's spfDocData
						[doc saveDocumentWithFilePath:[[doc fileURL] path] inBackground:YES onlyPreferences:NO contextInfo:nil];
						[tabData setObject:@YES forKey:@"isAbsolutePath"];
						[tabData setObject:[[doc fileURL] path] forKey:@"path"];
					}
					[tabs addObject:tabData];
					if([[window windowController] selectedTableDocument] == doc) selectedTabItem = tabCount;
					tabCount++;
				}
				if(![tabs count]) continue;
				[win setObject:tabs forKey:@"tabs"];
				[win setObject:[NSNumber numberWithInteger:selectedTabItem] forKey:@"selectedTabIndex"];
				[win setObject:NSStringFromRect([window frame]) forKey:@"frame"];
				[windows addObject:win];
			}
			[info setObject:windows forKey:@"windows"];
			
			error = nil;

			NSData *plist = [NSPropertyListSerialization dataWithPropertyList:info
			                                                           format:NSPropertyListXMLFormat_v1_0
			                                                          options:0
			                                                            error:&error];

			if(error) {
				NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error while converting session data", @"error while converting session data")
				                                 defaultButton:NSLocalizedString(@"OK", @"OK button")
				                               alternateButton:nil
				                                   otherButton:nil
				                     informativeTextWithFormat:@"%@", [error localizedDescription]];

				[alert setAlertStyle:NSCriticalAlertStyle];
				[alert runModal];
				
				return;
			}
			
			[plist writeToFile:[NSString stringWithFormat:@"%@/info.plist", fileName] options:NSAtomicWrite error:&error];
			
			if (error != nil){
				NSAlert *errorAlert = [NSAlert alertWithError:error];
				[errorAlert runModal];
				
				return;
			}

			[SPAppDelegate setSessionURL:fileName];

			// Register spfs bundle in Recent Files
			[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:fileName]];
		}
	}
}

- (BOOL)saveDocumentWithFilePath:(NSString *)fileName inBackground:(BOOL)saveInBackground onlyPreferences:(BOOL)saveOnlyPreferences contextInfo:(NSDictionary*)contextInfo
{
	// Do not save if no connection is/was available
	if (saveInBackground && ([self mySQLVersion] == nil || ![[self mySQLVersion] length])) return NO;

	NSMutableDictionary *spfDocData_temp = [NSMutableDictionary dictionary];

	if (fileName == nil) fileName = [[self fileURL] path];

	// Store save panel settings or take them from spfDocData
	if (!saveInBackground && contextInfo == nil) {
		[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionEncrypt state]==NSOnState) ? YES : NO ] forKey:@"encrypted"];
		if([[spfDocData_temp objectForKey:@"encrypted"] boolValue]) {
			[spfDocData_temp setObject:[saveConnectionEncryptString stringValue] forKey:@"e_string"];
		}
		[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionAutoConnect state]==NSOnState) ? YES : NO ] forKey:@"auto_connect"];
		[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionSavePassword state]==NSOnState) ? YES : NO ] forKey:@"save_password"];
		[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionIncludeData state]==NSOnState) ? YES : NO ] forKey:@"include_session"];
		[spfDocData_temp setObject:@NO forKey:@"save_editor_content"];
		if([[[[customQueryInstance valueForKeyPath:@"textView"] textStorage] string] length]) {
			[spfDocData_temp setObject:[NSNumber numberWithBool:([saveConnectionIncludeQuery state] == NSOnState) ? YES : NO] forKey:@"save_editor_content"];
		}
	}
	else {
		// If contextInfo != nil call came from other SPDatabaseDocument while saving it as bundle
		[spfDocData_temp addEntriesFromDictionary:(contextInfo == nil ? spfDocData : contextInfo)];
	}

	// Update only query favourites, history, etc. by reading the file again
	if (saveOnlyPreferences) {

		// Check URL for safety reasons
		if (![[[self fileURL] path] length] || [self isUntitled]) {
			NSLog(@"Couldn't save data. No file URL found!");
			NSBeep();
			return NO;
		}
		
		NSMutableDictionary *spf = [[NSMutableDictionary alloc] init];
		{
			NSError *error = nil;
			
			NSData *pData = [NSData dataWithContentsOfFile:fileName options:NSUncachedRead error:&error];
			
			if (pData && !error) {
				NSDictionary *pDict = [NSPropertyListSerialization propertyListWithData:pData
				                                                                options:NSPropertyListImmutable
				                                                                 format:NULL
				                                                                  error:&error];

				if (pDict && !error) {
					[spf addEntriesFromDictionary:pDict];
				}
			}
			
			if(![spf count] || error) {
				[SPAlertSheets beginWaitingAlertSheetWithTitle:NSLocalizedString(@"Error while reading connection data file", @"error while reading connection data file")
				                                 defaultButton:NSLocalizedString(@"OK", @"OK button")
				                               alternateButton:NSLocalizedString(@"Ignore", @"ignore button")
				                                   otherButton:nil
				                                    alertStyle:NSCriticalAlertStyle
				                                     docWindow:parentWindow
				                                 modalDelegate:self
				                                didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
				                                   contextInfo:SPSaveDocumentPreferences
				                                      infoText:[NSString stringWithFormat:NSLocalizedString(@"Connection data file “%@” couldn't be read. Please try to save the document under a different name.\n\nDetails: %@", @"message error while reading connection data file and suggesting to save it under a differnet name"), [fileName lastPathComponent], [error localizedDescription]]
				                                    returnCode:&saveDocPrefSheetStatus];
				
				if (spf) [spf release];

				return saveDocPrefSheetStatus == NSAlertAlternateReturn;
			}
		}

		// For dispatching later
		if (![[spf objectForKey:SPFFormatKey] isEqualToString:SPFConnectionContentType]) {
			NSLog(@"SPF file format is not 'connection'.");
			[spf release];
			return NO;
		}

		// Update the keys
		[spf setObject:[[SPQueryController sharedQueryController] favoritesForFileURL:[self fileURL]] forKey:SPQueryFavorites];
		[spf setObject:[[SPQueryController sharedQueryController] historyForFileURL:[self fileURL]] forKey:SPQueryHistory];
		[spf setObject:[[SPQueryController sharedQueryController] contentFilterForFileURL:[self fileURL]] forKey:SPContentFilters];

		// Save it again
		NSError *error = nil;
		NSData *plist = [NSPropertyListSerialization dataWithPropertyList:spf
		                                                           format:NSPropertyListXMLFormat_v1_0
		                                                          options:0
		                                                            error:&error];

		[spf release];

		if (error) {
			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error while converting connection data", @"error while converting connection data")
			                                 defaultButton:NSLocalizedString(@"OK", @"OK button")
			                               alternateButton:nil
			                                   otherButton:nil
			                     informativeTextWithFormat:@"%@", [error localizedDescription]];

			[alert setAlertStyle:NSCriticalAlertStyle];
			[alert runModal];
			return NO;
		}

		[plist writeToFile:fileName options:NSAtomicWrite error:&error];

		if (error != nil) {
			NSAlert *errorAlert = [NSAlert alertWithError:error];
			[errorAlert runModal];
			return NO;
		}

		[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:fileName]];

		return YES;
	}

	// Set up the dictionary to save to file, together with a data store
	NSMutableDictionary *spfStructure = [NSMutableDictionary dictionary];
	NSMutableDictionary *spfData = [NSMutableDictionary dictionary];

	// Add basic details
	[spfStructure setObject:@1 forKey:SPFVersionKey];
	[spfStructure setObject:SPFConnectionContentType forKey:SPFFormatKey];
	[spfStructure setObject:@"mysql" forKey:@"rdbms_type"];
	if([self mySQLVersion]) [spfStructure setObject:[self mySQLVersion] forKey:@"rdbms_version"];

	// Add auto-connect if appropriate
	[spfStructure setObject:[spfDocData_temp objectForKey:@"auto_connect"] forKey:@"auto_connect"];

	// Set up the document details to store
	NSMutableDictionary *stateDetailsToSave = [NSMutableDictionary dictionaryWithDictionary:@{
		@"connection": @YES,
		@"history":    @YES,
	}];

	// Include session data like selected table, view etc. ?
	if ([[spfDocData_temp objectForKey:@"include_session"] boolValue]) [stateDetailsToSave setObject:@YES forKey:@"session"];

	// Include the query editor contents if asked to
	if ([[spfDocData_temp objectForKey:@"save_editor_content"] boolValue]) {
		[stateDetailsToSave setObject:@YES forKey:@"query"];
		[stateDetailsToSave setObject:@YES forKey:@"enablecompression"];
	}

	// Add passwords if asked to
	if ([[spfDocData_temp objectForKey:@"save_password"] boolValue]) [stateDetailsToSave setObject:@YES forKey:@"password"];

	// Retrieve details and add to the appropriate dictionaries
	NSMutableDictionary *stateDetails = [NSMutableDictionary dictionaryWithDictionary:[self stateIncludingDetails:stateDetailsToSave]];
	[spfStructure setObject:[stateDetails objectForKey:SPQueryFavorites] forKey:SPQueryFavorites];
	[spfStructure setObject:[stateDetails objectForKey:SPQueryHistory] forKey:SPQueryHistory];
	[spfStructure setObject:[stateDetails objectForKey:SPContentFilters] forKey:SPContentFilters];
	[stateDetails removeObjectsForKeys:@[SPQueryFavorites, SPQueryHistory, SPContentFilters]];
	[spfData addEntriesFromDictionary:stateDetails];

	// Determine whether to use encryption when adding the data
	[spfStructure setObject:[spfDocData_temp objectForKey:@"encrypted"] forKey:@"encrypted"];

	if (![[spfDocData_temp objectForKey:@"encrypted"] boolValue]) {

		// Convert the content selection to encoded data
		if ([[spfData objectForKey:@"session"] objectForKey:@"contentSelection"]) {
			NSMutableDictionary *sessionInfo = [NSMutableDictionary dictionaryWithDictionary:[spfData objectForKey:@"session"]];
			NSMutableData *dataToEncode = [[[NSMutableData alloc] init] autorelease];
			NSKeyedArchiver *archiver = [[[NSKeyedArchiver alloc] initForWritingWithMutableData:dataToEncode] autorelease];
			[archiver encodeObject:[sessionInfo objectForKey:@"contentSelection"] forKey:@"data"];
			[archiver finishEncoding];
			[sessionInfo setObject:dataToEncode forKey:@"contentSelection"];
			[spfData setObject:sessionInfo forKey:@"session"];
		}

		[spfStructure setObject:spfData forKey:@"data"];
	}
	else {
		NSMutableData *dataToEncrypt = [[[NSMutableData alloc] init] autorelease];
		NSKeyedArchiver *archiver = [[[NSKeyedArchiver alloc] initForWritingWithMutableData:dataToEncrypt] autorelease];
		[archiver encodeObject:spfData forKey:@"data"];
		[archiver finishEncoding];
		[spfStructure setObject:[dataToEncrypt dataEncryptedWithPassword:[spfDocData_temp objectForKey:@"e_string"]] forKey:@"data"];
	}

	// Convert to plist
	NSError *error = nil;
	NSData *plist = [NSPropertyListSerialization dataWithPropertyList:spfStructure
	                                                           format:NSPropertyListXMLFormat_v1_0
	                                                          options:0
	                                                            error:&error];

	if (error) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error while converting connection data", @"error while converting connection data")
		                                 defaultButton:NSLocalizedString(@"OK", @"OK button")
		                               alternateButton:nil
		                                   otherButton:nil
		                     informativeTextWithFormat:@"%@", [error localizedDescription]];

		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
		return NO;
	}

	[plist writeToFile:fileName options:NSAtomicWrite error:&error];

	if (error != nil){
		NSAlert *errorAlert = [NSAlert alertWithError:error];
		[errorAlert runModal];
		return NO;
	}

	if (contextInfo == nil) {
		// Register and update query favorites, content filter, and history for the (new) file URL
		NSMutableDictionary *preferences = [[NSMutableDictionary alloc] init];
		[preferences setObject:[spfStructure objectForKey:SPQueryHistory] forKey:SPQueryHistory];
		[preferences setObject:[spfStructure objectForKey:SPQueryFavorites] forKey:SPQueryFavorites];
		[preferences setObject:[spfStructure objectForKey:SPContentFilters] forKey:SPContentFilters];
		[[SPQueryController sharedQueryController] registerDocumentWithFileURL:[NSURL fileURLWithPath:fileName] andContextInfo:preferences];

		NSURL *newURL = [NSURL fileURLWithPath:fileName];
		[self setFileURL:newURL];
		[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:fileName]];

		[self updateWindowTitle:self];

		// Store doc data permanently
		[spfDocData removeAllObjects];
		[spfDocData addEntriesFromDictionary:spfDocData_temp];

		[preferences release];
	}

	return YES;
}

/**
 * Open the currently selected database in a new tab, clearing any table selection.
 */
- (IBAction)openDatabaseInNewTab:(id)sender
{
	// Add a new tab to the window
	[[parentWindow windowController] addNewConnection:self];

	// Get the current state
	NSDictionary *allStateDetails = @{
		@"connection" : @YES,
		@"history"    : @YES,
		@"session"    : @YES,
		@"query"      : @YES,
		@"password"   : @YES
	};
	NSMutableDictionary *currentState = [NSMutableDictionary dictionaryWithDictionary:[self stateIncludingDetails:allStateDetails]];

	// Ensure it's set to autoconnect, and clear the table
	[currentState setObject:@YES forKey:@"auto_connect"];
	NSMutableDictionary *sessionDict = [NSMutableDictionary dictionaryWithDictionary:[currentState objectForKey:@"session"]];
	[sessionDict removeObjectForKey:@"table"];
	[currentState setObject:sessionDict forKey:@"session"];

	// Set the connection on the new tab
	[[SPAppDelegate frontDocument] setState:currentState];
}

/**
 * Passes the request to the dataImport object
 */
- (IBAction)import:(id)sender
{
	[tableDumpInstance importFile];
}

/**
 * Passes the request to the dataImport object
 */
- (IBAction)importFromClipboard:(id)sender
{
	[tableDumpInstance importFromClipboard];
}

/**
 * Show the MySQL Help TOC of the current MySQL connection
 * Invoked by the MainMenu > Help > MySQL Help
 */
- (IBAction)showMySQLHelp:(id)sender
{
	[helpViewerClientInstance showHelpFor:SPHelpViewerSearchTOC addToHistory:YES calledByAutoHelp:NO];
	[[helpViewerClientInstance helpWebViewWindow] makeKeyWindow];
}
#endif

/**
 * Forwards a responder request to set the focus to the table list filter area or table list
 */
- (IBAction) makeTableListFilterHaveFocus:(id)sender
{
	[tablesListInstance performSelector:@selector(makeTableListFilterHaveFocus) withObject:nil afterDelay:0.1];
}

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = [menuItem action];
	
	if (action == @selector(chooseDatabase:)) {
		return _isConnected && databaseListIsSelectable;
	}

	if (!_isConnected || _isWorkingLevel) {
		return (
			action == @selector(newWindow:) ||
			action == @selector(terminate:) ||
			action == @selector(closeTab:)
		);
	}

	if (action == @selector(openCurrentConnectionInNewWindow:))
	{
		if ([self isUntitled]) {
			[menuItem setTitle:NSLocalizedString(@"Open in New Window", @"menu item open in new window")];
			return NO;
		} 
		else {
			[menuItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Open “%@” in New Window", @"menu item open “%@” in new window"), [self displayName]]];
			return YES;
		}
	}
	
	// Data export
	if (action == @selector(export:)) {
		return (([self database] != nil) && ([[tablesListInstance tables] count] > 1));
	}
	
	// Selected tables data export
	if (action == @selector(exportSelectedTablesAs:)) {
		
		NSInteger tag = [menuItem tag];
		NSInteger type = [tablesListInstance tableType];
		NSInteger numberOfSelectedItems = [[[tablesListInstance valueForKeyPath:@"tablesListView"] selectedRowIndexes] count];
		
		BOOL enable = (([self database] != nil) && numberOfSelectedItems);
		
		// Enable all export formats if at least one table/view is selected
		if (numberOfSelectedItems == 1) {
			if (type == SPTableTypeTable || type == SPTableTypeView) {
				return enable;
			}
			else if ((type == SPTableTypeProc) || (type == SPTableTypeFunc)) {
				return (enable && (tag == SPSQLExport));
			}
		} 
		else {
			for (NSNumber *eachType in [tablesListInstance selectedTableTypes]) 
			{
				if ([eachType intValue] == SPTableTypeTable || [eachType intValue] == SPTableTypeView) return enable;
			}
			
			return (enable && (tag == SPSQLExport));
		}
	}
	
	// Can only be enabled on mysql 4.1+
	if (action == @selector(alterDatabase:)) {
		return (([self database] != nil) && [serverSupport supportsPost41CharacterSetHandling]);
	}
	
	// Table specific actions
	if (action == @selector(viewStructure:) ||
		action == @selector(viewContent:)   ||
		action == @selector(viewRelations:) ||
		action == @selector(viewStatus:)    ||
		action == @selector(viewTriggers:))
	{
		return [self database] != nil && [[[tablesListInstance valueForKeyPath:@"tablesListView"] selectedRowIndexes] count];
		
	}

	// Database specific actions
	if (action == @selector(import:)               ||
		action == @selector(removeDatabase:)       ||
		action == @selector(copyDatabase:)         ||
		action == @selector(renameDatabase:)       ||
		action == @selector(openDatabaseInNewTab:) ||
		action == @selector(refreshTables:))
	{
		return [self database] != nil;
	}
	
	if (action == @selector(importFromClipboard:)){
		return [self database] && [[NSPasteboard generalPasteboard] availableTypeFromArray:@[NSStringPboardType]];
	}
	
	// Change "Save Query/Queries" menu item title dynamically
	// and disable it if no query in the editor
	if (action == @selector(saveConnectionSheet:) && [menuItem tag] == 0) {
		if ([customQueryInstance numberOfQueries] < 1) {
			[menuItem setTitle:NSLocalizedString(@"Save Query…", @"Save Query…")];
			
			return NO;
		}
		else {
			[menuItem setTitle:[customQueryInstance numberOfQueries] == 1 ? NSLocalizedString(@"Save Query…", @"Save Query…") : NSLocalizedString(@"Save Queries…", @"Save Queries…")];
		}

		return YES;
	}

	if (action == @selector(printDocument:)) {
		return (
			([self database] != nil && [[tablesListInstance valueForKeyPath:@"tablesListView"] numberOfSelectedRows] == 1) ||
			// If Custom Query Tab is active the textView will handle printDocument by itself
			// if it is first responder; otherwise allow to print the Query Result table even 
			// if no db/table is selected
			[self currentlySelectedView] == SPTableViewCustomQuery
		);
	}

	if (action == @selector(chooseEncoding:)) {
		return [self supportsEncoding];
	}

	// Table actions and view switching
	if (action == @selector(analyzeTable:) || 
		action == @selector(optimizeTable:) || 
		action == @selector(repairTable:) || 
		action == @selector(flushTable:) ||
		action == @selector(checkTable:) ||
		action == @selector(checksumTable:) ||
		action == @selector(showCreateTableSyntax:) ||
		action == @selector(copyCreateTableSyntax:))
	{
		return [[[tablesListInstance valueForKeyPath:@"tablesListView"] selectedRowIndexes] count];
	}

	if (action == @selector(addConnectionToFavorites:)) {
		return ![connectionController selectedFavorite] || [connectionController isEditingConnection];
	}

	// Backward in history menu item
	if ((action == @selector(backForwardInHistory:)) && ([menuItem tag] == 0)) {
		return (([[spHistoryControllerInstance history] count]) && ([spHistoryControllerInstance historyPosition] > 0));
	}

	// Forward in history menu item
	if ((action == @selector(backForwardInHistory:)) && ([menuItem tag] == 1)) {
		return (([[spHistoryControllerInstance history] count]) && (([spHistoryControllerInstance historyPosition] + 1) < [[spHistoryControllerInstance history] count]));
	}
	
	// Show/hide console
	if (action == @selector(toggleConsole:)) {
		[menuItem setTitle:([[[SPQueryController sharedQueryController] window] isVisible] && [[[NSApp keyWindow] windowController] isKindOfClass:[SPQueryController class]]) ? NSLocalizedString(@"Hide Console", @"hide console") : NSLocalizedString(@"Show Console", @"show console")];
	}
	
	// Clear console
	if (action == @selector(clearConsole:)) {
		return ([[SPQueryController sharedQueryController] consoleMessageCount] > 0);
	}
	
	// Show/hide console
	if (action == @selector(toggleNavigator:)) {
		[menuItem setTitle:([[[SPNavigatorController sharedNavigatorController] window] isVisible]) ? NSLocalizedString(@"Hide Navigator", @"hide navigator") : NSLocalizedString(@"Show Navigator", @"show navigator")];
	}
	
	// Focus on table content filter
	if (action == @selector(focusOnTableContentFilter:) || [menuItem action] == @selector(showFilterTable:)) {
		return ([self table] != nil && [[self table] isNotEqualTo:@""]); 
	}

	// Focus on table list or filter resp.
	if (action == @selector(makeTableListFilterHaveFocus:)) {
		
		[menuItem setTitle:[[tablesListInstance valueForKeyPath:@"tables"] count] > 20 ? NSLocalizedString(@"Filter Tables", @"filter tables menu item") : NSLocalizedString(@"Change Focus to Table List", @"change focus to table list menu item")];

		return [[tablesListInstance valueForKeyPath:@"tables"] count] > 1; 
	}
	
	// If validation for the sort favorites tableview items reaches here then the preferences window isn't
	// open return NO.
	if ((action == @selector(sortFavorites:)) || ([menuItem action] == @selector(reverseSortFavorites:))) {
		return NO;
	}

	// Default to YES for unhandled menus
	return YES;
}

/**
 * Adds the current database connection details to the user's favorites if it doesn't already exist.
 */
- (IBAction)addConnectionToFavorites:(id)sender
{
#ifndef SP_CODA
	// Obviously don't add if it already exists. We shouldn't really need this as the menu item validation
	// enables or disables the menu item based on the same method. Although to be safe do the check anyway
	// as we don't know what's calling this method.
	if ([connectionController selectedFavorite] && ![connectionController isEditingConnection]) return;

	// Request the connection controller to add its details to favorites
	[connectionController addFavoriteUsingCurrentDetails:self];
#endif
}

/**
 * Return YES if Custom Query is active.
 */
- (BOOL)isCustomQuerySelected
{
#ifndef SP_CODA
	return [[self selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarCustomQuery];
#else
	return ([structureContentSwitcher selectedSegment] == 2);
#endif
}

/**
 * Return the createTableSyntaxWindow
 */
- (NSWindow *)getCreateTableSyntaxWindow
{
	return createTableSyntaxWindow;
}

#pragma mark -
#pragma mark Titlebar Methods

/**
 * Update the window title.
 */
- (void) updateWindowTitle:(id)sender
{
#ifndef SP_CODA
	// Ensure a call on the main thread
	if (![NSThread isMainThread]) return [[self onMainThread] updateWindowTitle:sender];

	NSMutableString *tabTitle;
	NSMutableString *windowTitle;
	SPDatabaseDocument *frontTableDocument = [parentWindowController selectedTableDocument];
	
	NSColor *tabColor = nil;

	// Determine name details
	NSString *pathName = @"";
	if ([[[self fileURL] path] length] && ![self isUntitled]) {
		pathName = [NSString stringWithFormat:@"%@ — ", [[[self fileURL] path] lastPathComponent]];
	}
	
	if ([connectionController isConnecting]) {
		windowTitle = [NSMutableString stringWithString:NSLocalizedString(@"Connecting…", @"window title string indicating that sp is connecting")];
		tabTitle = windowTitle;
	}
	else if (!_isConnected) {
		windowTitle = [NSMutableString stringWithFormat:@"%@%@", pathName, @"Sequel Pro"];
		tabTitle = windowTitle;
	} 
	else {
		tabColor = [[SPFavoriteColorSupport sharedInstance] colorForIndex:[connectionController colorIndex]];
		
		windowTitle = [NSMutableString string];
		tabTitle = [NSMutableString string];

		// Add the path to the window title
		[windowTitle appendString:pathName];

		// Add the MySQL version to the window title if enabled in prefs
		if ([prefs boolForKey:SPDisplayServerVersionInWindowTitle]) [windowTitle appendFormat:@"(MySQL %@) ", mySQLVersion];

		// Add the name to the window
		[windowTitle appendString:[self name]];

		// Also add to the non-front tabs if the host is different, not connected, or no db is selected
		if ([[frontTableDocument name] isNotEqualTo:[self name]] || ![frontTableDocument getConnection] || ![self database]) {
			[tabTitle appendString:[self name]];
		}

		// If a database is selected, add to the window - and other tabs if host is the same but db different or table is not set
		if ([self database]) {
			[windowTitle appendFormat:@"/%@", [self database]];
			if (frontTableDocument == self
				|| ![frontTableDocument getConnection]
				|| [[frontTableDocument name] isNotEqualTo:[self name]]
				|| [[frontTableDocument database] isNotEqualTo:[self database]]
				|| ![[self table] length])
			{
				if ([tabTitle length]) [tabTitle appendString:@"/"];
				[tabTitle appendString:[self database]];
			}
		}

		// Add the table name if one is selected
		if ([[self table] length]) {
			[windowTitle appendFormat:@"/%@", [self table]];
			if ([tabTitle length]) [tabTitle appendString:@"/"];
			[tabTitle appendString:[self table]];
		}
	}
	
	// Set the titles
	[parentTabViewItem setLabel:tabTitle];
	[parentTabViewItem setColor:tabColor];
	[parentWindowController updateTabBar];
	
	if ([parentWindowController selectedTableDocument] == self) {
		[parentWindow setTitle:windowTitle];
	}

	// If the sender wasn't the window controller, update other tabs in this window
	// for shared pathname updates
	if ([sender class] != [SPWindowController class]) [parentWindowController updateAllTabTitles:self];
#endif
}

/**
 * Set the connection status icon in the titlebar
 */
- (void)setStatusIconToImageWithName:(NSString *)imageName
{
#ifndef SP_CODA
	NSString *imagePath = [[NSBundle mainBundle] pathForResource:imageName ofType:@"png"];
	if (!imagePath) return;

	NSImage *image = [[[NSImage alloc] initByReferencingFile:imagePath] autorelease];
	[titleImageView setImage:image];
#endif
}

- (void)setTitlebarStatus:(NSString *)status
{
#ifndef SP_CODA
	[self clearStatusIcon];
	[titleStringView setStringValue:status];
#endif
}

/**
 * Clear the connection status icon in the titlebar
 */
- (void)clearStatusIcon
{
#ifndef SP_CODA
	[titleImageView setImage:nil];
#endif
}

/**
 * Update the title bar status area visibility.  The status area is visible if the tab is
 * frontmost in the window, and if the window is not fullscreen.
 */
- (void)updateTitlebarStatusVisibilityForcingHide:(BOOL)forceHide
{
#ifndef SP_CODA
	BOOL newIsVisible = !forceHide;
	if (newIsVisible && [parentWindow styleMask] & NSFullScreenWindowMask) newIsVisible = NO;
	if (newIsVisible && [parentWindowController selectedTableDocument] != self) newIsVisible = NO;
	if (newIsVisible == windowTitleStatusViewIsVisible) return;

	if (newIsVisible) {
		Class controllerClass;
		if ((controllerClass = NSClassFromString(@"NSTitlebarAccessoryViewController"))) { // OS X 10.11 and later
			[titleAccessoryView setFrame:NSMakeRect(0, 0, titleAccessoryView.frame.size.width, 120)]; // make it really tall, so that it's on the top right of the title/toolbar area, instead of the bottom right (AppKit will not prevent it from going behind the toolbar)
			
			NSTitlebarAccessoryViewController *accessoryViewController = [[[controllerClass alloc] init] autorelease];
			accessoryViewController.view = titleAccessoryView;
			accessoryViewController.layoutAttribute = NSLayoutAttributeRight;
			[parentWindow addTitlebarAccessoryViewController:accessoryViewController];
		} else {
			NSView *windowFrame = [[parentWindow contentView] superview];
			NSRect av = [titleAccessoryView frame];
			NSRect initialAccessoryViewFrame = NSMakeRect(
				[windowFrame frame].size.width - av.size.width - 30,
				[windowFrame frame].size.height - av.size.height,
				av.size.width,
				av.size.height
			);
			[titleAccessoryView setFrame:initialAccessoryViewFrame];
			[windowFrame addSubview:titleAccessoryView];
		}
	} else {
		if (NSClassFromString(@"NSTitlebarAccessoryViewController")) { // OS X 10.11 and later
			[parentWindow.titlebarAccessoryViewControllers enumerateObjectsUsingBlock:^(__kindof NSTitlebarAccessoryViewController * _Nonnull accessoryViewController, NSUInteger idx, BOOL * _Nonnull stop) {
				if (accessoryViewController.view == titleAccessoryView) {
					[parentWindow removeTitlebarAccessoryViewControllerAtIndex:idx];
				}
			}];
		} else {
			[titleAccessoryView removeFromSuperview];
		}
	}

	windowTitleStatusViewIsVisible = newIsVisible;
#endif
}

#pragma mark -
#pragma mark Toolbar Methods

#ifndef SP_CODA

/**
 * set up the standard toolbar
 */
- (void)setupToolbar
{
	// create a new toolbar instance, and attach it to our document window
	mainToolbar = [[NSToolbar alloc] initWithIdentifier:@"TableWindowToolbar"];

	// set up toolbar properties
	[mainToolbar setAllowsUserCustomization:YES];
	[mainToolbar setAutosavesConfiguration:YES];
	[mainToolbar setShowsBaselineSeparator:NO];
	[mainToolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];

	// set ourself as the delegate
	[mainToolbar setDelegate:self];

	// The history controller needs to track toolbar item state - trigger setup.
	[spHistoryControllerInstance setupInterface];
}

/**
 * Return the identifier for the currently selected toolbar item, or nil if none is selected.
 */
- (NSString *)selectedToolbarItemIdentifier
{
	return [mainToolbar selectedItemIdentifier];
}

/**
 * toolbar delegate method
 */
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar
{
	NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];

	if ([itemIdentifier isEqualToString:SPMainToolbarDatabaseSelection]) {
		[toolbarItem setLabel:NSLocalizedString(@"Select Database", @"toolbar item for selecting a db")];
		[toolbarItem setPaletteLabel:[toolbarItem label]];
		[toolbarItem setView:chooseDatabaseButton];
		[toolbarItem setMinSize:NSMakeSize(200,26)];
		[toolbarItem setMaxSize:NSMakeSize(200,32)];
		[chooseDatabaseButton setTarget:self];
		[chooseDatabaseButton setAction:@selector(chooseDatabase:)];
		[chooseDatabaseButton setEnabled:(_isConnected && !_isWorkingLevel)];

	} else if ([itemIdentifier isEqualToString:SPMainToolbarHistoryNavigation]) {
		[toolbarItem setLabel:NSLocalizedString(@"Table History", @"toolbar item for navigation history")];
		[toolbarItem setPaletteLabel:[toolbarItem label]];
		// At some point after 10.9 the sizing of NSSegmentedControl changed, resulting in clipping in newer OS X versions.
		// We can't just adjust the XIB, because then it would be wrong for older versions (possibly resulting in drawing artifacts),
		// so we have the OS determine the proper size at runtime.
		[historyControl sizeToFit];
		[toolbarItem setView:historyControl];

	} else if ([itemIdentifier isEqualToString:SPMainToolbarShowConsole]) {
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Show Console", @"show console")];
		[toolbarItem setToolTip:NSLocalizedString(@"Show the console which shows all MySQL commands performed by Sequel Pro", @"tooltip for toolbar item for show console")];

		[toolbarItem setLabel:NSLocalizedString(@"Console", @"Console")];
		[toolbarItem setImage:[NSImage imageNamed:@"hideconsole"]];

		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(showConsole:)];

	} else if ([itemIdentifier isEqualToString:SPMainToolbarClearConsole]) {
		//set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"Clear Console", @"toolbar item for clear console")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Clear Console", @"toolbar item for clear console")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Clear the console which shows all MySQL commands performed by Sequel Pro", @"tooltip for toolbar item for clear console")];
		[toolbarItem setImage:[NSImage imageNamed:@"clearconsole"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(clearConsole:)];

	} else if ([itemIdentifier isEqualToString:SPMainToolbarTableStructure]) {
		[toolbarItem setLabel:NSLocalizedString(@"Structure", @"toolbar item label for switching to the Table Structure tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Edit Table Structure", @"toolbar item label for switching to the Table Structure tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the Table Structure tab", @"tooltip for toolbar item for switching to the Table Structure tab")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar-switch-to-structure"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(viewStructure:)];

	} else if ([itemIdentifier isEqualToString:SPMainToolbarTableContent]) {
		[toolbarItem setLabel:NSLocalizedString(@"Content", @"toolbar item label for switching to the Table Content tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Browse & Edit Table Content", @"toolbar item label for switching to the Table Content tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the Table Content tab", @"tooltip for toolbar item for switching to the Table Content tab")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar-switch-to-browse"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(viewContent:)];

	} else if ([itemIdentifier isEqualToString:SPMainToolbarCustomQuery]) {
		[toolbarItem setLabel:NSLocalizedString(@"Query", @"toolbar item label for switching to the Run Query tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Run Custom Query", @"toolbar item label for switching to the Run Query tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the Run Query tab", @"tooltip for toolbar item for switching to the Run Query tab")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar-switch-to-sql"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(viewQuery:)];

	} else if ([itemIdentifier isEqualToString:SPMainToolbarTableInfo]) {
		[toolbarItem setLabel:NSLocalizedString(@"Table Info", @"toolbar item label for switching to the Table Info tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Table Info", @"toolbar item label for switching to the Table Info tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the Table Info tab", @"tooltip for toolbar item for switching to the Table Info tab")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar-switch-to-table-info"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(viewStatus:)];

	} else if ([itemIdentifier isEqualToString:SPMainToolbarTableRelations]) {
		[toolbarItem setLabel:NSLocalizedString(@"Relations", @"toolbar item label for switching to the Table Relations tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Table Relations", @"toolbar item label for switching to the Table Relations tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the Table Relations tab", @"tooltip for toolbar item for switching to the Table Relations tab")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar-switch-to-table-relations"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(viewRelations:)];

	} else if ([itemIdentifier isEqualToString:SPMainToolbarTableTriggers]) {
		[toolbarItem setLabel:NSLocalizedString(@"Triggers", @"toolbar item label for switching to the Table Triggers tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Table Triggers", @"toolbar item label for switching to the Table Triggers tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the Table Triggers tab", @"tooltip for toolbar item for switching to the Table Triggers tab")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar-switch-to-table-triggers"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(viewTriggers:)];
		
	} else if ([itemIdentifier isEqualToString:SPMainToolbarUserManager]) {
		[toolbarItem setLabel:NSLocalizedString(@"Users", @"toolbar item label for switching to the User Manager tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Users", @"toolbar item label for switching to the User Manager tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the User Manager tab", @"tooltip for toolbar item for switching to the User Manager tab")];
		[toolbarItem setImage:[NSImage imageNamed:NSImageNameEveryone]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(showUserManager:)];
		
	} else {
		//itemIdentifier refered to a toolbar item that is not provided or supported by us or cocoa 
		toolbarItem = nil;
	}

	return toolbarItem;
}

- (void)toolbarWillAddItem:(NSNotification *)notification
{
	NSToolbarItem *toAdd = [[notification userInfo] objectForKey:@"item"];
	
	if([[toAdd itemIdentifier] isEqualToString:SPMainToolbarDatabaseSelection]) {
		chooseDatabaseToolbarItem = toAdd;
		[self updateChooseDatabaseToolbarItemWidth];
	}
}

- (void)toolbarDidRemoveItem:(NSNotification *)notification
{
	NSToolbarItem *removed = [[notification userInfo] objectForKey:@"item"];
	
	if([[removed itemIdentifier] isEqualToString:SPMainToolbarDatabaseSelection]) {
		chooseDatabaseToolbarItem = nil;
	}
}

/**
 * toolbar delegate method
 */
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
	return @[
		SPMainToolbarDatabaseSelection,
		SPMainToolbarHistoryNavigation,
		SPMainToolbarShowConsole,
		SPMainToolbarClearConsole,
		SPMainToolbarTableStructure,
		SPMainToolbarTableContent,
		SPMainToolbarCustomQuery,
		SPMainToolbarTableInfo,
		SPMainToolbarTableRelations,
		SPMainToolbarTableTriggers,
		SPMainToolbarUserManager,
		NSToolbarCustomizeToolbarItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarSeparatorItemIdentifier
	];
}

/**
 * toolbar delegate method
 */
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
	return @[
		SPMainToolbarDatabaseSelection,
		SPMainToolbarTableStructure,
		SPMainToolbarTableContent,
		SPMainToolbarTableRelations,
		SPMainToolbarTableTriggers,
		SPMainToolbarTableInfo,
		SPMainToolbarCustomQuery,
		NSToolbarFlexibleSpaceItemIdentifier,
		SPMainToolbarHistoryNavigation,
		SPMainToolbarUserManager,
		SPMainToolbarShowConsole
	];
}

/**
 * toolbar delegate method
 */
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return @[
		SPMainToolbarTableStructure,
		SPMainToolbarTableContent,
		SPMainToolbarCustomQuery,
		SPMainToolbarTableInfo,
		SPMainToolbarTableRelations,
		SPMainToolbarTableTriggers
	];

}

/**
 * Validates the toolbar items
 */
- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
	if (!_isConnected || _isWorkingLevel) return NO;

	NSString *identifier = [toolbarItem itemIdentifier];

	// Show console item
	if ([identifier isEqualToString:SPMainToolbarShowConsole]) {
		NSWindow *queryWindow = [[SPQueryController sharedQueryController] window];
		if ([queryWindow isVisible]) {
			[toolbarItem setImage:[NSImage imageNamed:@"showconsole"]];
		} else {
			[toolbarItem setImage:[NSImage imageNamed:@"hideconsole"]];
		}
		if ([queryWindow isKeyWindow]) {
			return NO;
		} else {
			return YES;
		}
	}

	// Clear console item
	if ([identifier isEqualToString:SPMainToolbarClearConsole]) {
		return ([[SPQueryController sharedQueryController] consoleMessageCount] > 0);
	}

	if (![identifier isEqualToString:SPMainToolbarCustomQuery] && ![identifier isEqualToString:SPMainToolbarUserManager]) {
		return (([tablesListInstance tableType] == SPTableTypeTable) || ([tablesListInstance tableType] == SPTableTypeView));
	}

	return YES;
}

#endif


#pragma mark -
#pragma mark Tab methods

/**
 * Make this document's window frontmost in the application,
 * and ensure this tab is selected.
 */
- (void)makeKeyDocument
{
	[[[self parentWindow] onMainThread] makeKeyAndOrderFront:self];
#ifndef SP_CODA
	[[[[self parentTabViewItem] onMainThread] tabView] selectTabViewItemWithIdentifier:self];
#endif
}

/**
 * Invoked to determine whether the parent tab is allowed to close
 */
- (BOOL)parentTabShouldClose
{

	// If no connection is available, always return YES.  Covers initial setup and disconnections.
	if(!_isConnected) return YES;

	// If tasks are active, return NO to allow tasks to complete
	if (_isWorkingLevel) return NO;

	// If the table list considers itself to be working, return NO. This catches open alerts, and
	// edits in progress in various views.
	if ( ![tablesListInstance selectionShouldChangeInTableView:nil] ) return NO;

#ifndef SP_CODA
	// Auto-save spf file based connection and return if the save was not successful
	if([self fileURL] && [[[self fileURL] path] length] && ![self isUntitled]) {
		BOOL isSaved = [self saveDocumentWithFilePath:nil inBackground:YES onlyPreferences:YES contextInfo:nil];
		if (isSaved) {
			[[SPQueryController sharedQueryController] removeRegisteredDocumentWithFileURL:[self fileURL]];
		} else {
			return NO;
		}
	}

	// Terminate all running BASH commands
	for(NSDictionary* cmd in [self runningActivities]) {
		NSInteger pid = [[cmd objectForKey:@"pid"] integerValue];
		NSTask *killTask = [[NSTask alloc] init];
		[killTask setLaunchPath:@"/bin/sh"];
		[killTask setArguments:[NSArray arrayWithObjects:@"-c", [NSString stringWithFormat:@"kill -9 -%ld", (long)pid], nil]];
		[killTask launch];
		[killTask waitUntilExit];
		[killTask release];
	}

	[[SPNavigatorController sharedNavigatorController] performSelectorOnMainThread:@selector(removeConnection:) withObject:[self connectionID] waitUntilDone:YES];

	// Note that this call does not need to be removed in release builds as leaks analysis output is only
	// dumped if [[SPLogger logger] setDumpLeaksOnTermination]; has been called first.
	[[SPLogger logger] dumpLeaks];
#endif
	// Return YES by default
	return YES;
}


/**
 * Invoked when the parent tab is about to close
 */
- (void)parentTabDidClose
{
#ifndef SP_CODA
	// Cancel autocompletion trigger
	if([prefs boolForKey:SPCustomQueryAutoComplete]) {
#endif
		[NSObject cancelPreviousPerformRequestsWithTarget:[customQueryInstance valueForKeyPath:@"textView"]
		                                         selector:@selector(doAutoCompletion)
		                                           object:nil];
#ifndef SP_CODA
	}
	if([prefs boolForKey:SPCustomQueryUpdateAutoHelp]) {
#endif
		[NSObject cancelPreviousPerformRequestsWithTarget:[customQueryInstance valueForKeyPath:@"textView"]
		                                         selector:@selector(autoHelp)
		                                           object:nil];
#ifndef SP_CODA
	}
#endif

	[mySQLConnection setDelegate:nil];
	if (_isConnected) {
		[self closeConnection];
	} else {
		[connectionController cancelConnection:self];
	}
#ifndef SP_CODA
	if ([[[SPQueryController sharedQueryController] window] isVisible]) [self toggleConsole:self];
	[createTableSyntaxWindow orderOut:nil];
#endif
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self setParentWindow:nil];

}

#ifndef SP_CODA
/**
 * Invoked when the parent tab is currently the active tab in the
 * window, but is being switched away from, to allow cleaning up
 * details in the window.
 */
- (void)willResignActiveTabInWindow
{
	[self updateTitlebarStatusVisibilityForcingHide:YES];

	// Remove the task progress window
	[parentWindow removeChildWindow:taskProgressWindow];
	[taskProgressWindow orderOut:self];
}

/**
 * Invoked when the parent tab became the active tab in the window,
 * to allow the window to reflect the contents of this view.
 */
- (void)didBecomeActiveTabInWindow
{
	// Update the toolbar
	BOOL toolbarVisible = ![parentWindow toolbar] || [[parentWindow toolbar] isVisible];
	[parentWindow setToolbar:mainToolbar];
	[[parentWindow toolbar] setVisible:toolbarVisible];

	// Update the window's title and represented document
	[self updateWindowTitle:self];
	[parentWindow setRepresentedURL:(spfFileURL && [spfFileURL isFileURL] ? spfFileURL : nil)];

	[self updateTitlebarStatusVisibilityForcingHide:NO];

	// Add the progress window to this window
	[self centerTaskWindow];
	[parentWindow addChildWindow:taskProgressWindow ordered:NSWindowAbove];

#ifndef SP_CODA
	// If not connected, update the favorite selection
	if (!_isConnected) {
		[connectionController updateFavoriteNextKeyView];
	}
#endif
}

/**
 * Invoked when the parent tab became the key tab in the application;
 * the selected tab in the frontmost window.
 */
- (void)tabDidBecomeKey
{
	// Synchronize Navigator with current active document if Navigator runs in syncMode
	if([[SPNavigatorController sharedNavigatorController] syncMode] && [self connectionID] && ![[self connectionID] isEqualToString:@"_"]) {
		NSMutableString *schemaPath = [NSMutableString string];
		[schemaPath setString:[self connectionID]];
		if([self database] && [[self database] length]) {
			[schemaPath appendString:SPUniqueSchemaDelimiter];
			[schemaPath appendString:[self database]];
			if([self table] && [[self table] length]) {
				[schemaPath appendString:SPUniqueSchemaDelimiter];
				[schemaPath appendString:[self table]];
			}
		}
		[[SPNavigatorController sharedNavigatorController] selectPath:schemaPath];
	}
}

/**
 * Invoked when the document window is resized
 */
- (void)tabDidResize
{
	// Coax the main split view into actually checking its constraints
	[contentViewSplitter setPosition:[[[contentViewSplitter subviews] objectAtIndex:0] bounds].size.width ofDividerAtIndex:0];

	// If the task interface is visible, and this tab is frontmost, re-center the task child window
	if (_isWorkingLevel && [parentWindowController selectedTableDocument] == self) [self centerTaskWindow];
}
#endif

/**
 * Set the parent window
 */
- (void)setParentWindow:(NSWindow *)window
{
	NSWindow *favoritesOutlineViewWindow = [[connectionController favoritesOutlineView] window];

	// If the window is being set for the first time - connection controller is visible - update focus
	if (!parentWindow && !mySQLConnection && window == favoritesOutlineViewWindow) {
		[window makeFirstResponder:[connectionController favoritesOutlineView]];
	}

	parentWindow = window;

	SPSSHTunnel *currentTunnel = [connectionController valueForKeyPath:@"sshTunnel"];

	if (currentTunnel) [currentTunnel setParentWindow:parentWindow];
}

/**
 * Return the parent window
 */
- (NSWindow *)parentWindow
{
	return parentWindow;
}

#ifndef SP_CODA
#pragma mark -
#pragma mark NSDocument compatibility

/**
 * Set the NSURL for a .spf file for this connection instance.
 */
- (void)setFileURL:(NSURL *)theURL
{
	[theURL retain];
	[spfFileURL release];
	spfFileURL  = theURL;
	if ([parentWindowController selectedTableDocument] == self) {
		if (spfFileURL && [spfFileURL isFileURL]) [parentWindow setRepresentedURL:spfFileURL];
		else                                      [parentWindow setRepresentedURL:nil];
	}
}
#endif

/**
 * Retrieve the NSURL for the .spf file for this connection instance (if any)
 */
#ifndef SP_CODA
- (NSURL *)fileURL
{
	return [[spfFileURL copy] autorelease];
}
#endif

#ifndef SP_CODA /* writeSafelyToURL: */
/**
 * Invoked if user chose "Save" from 'Do you want save changes you made...' sheet
 * which is called automatically if [self isDocumentEdited] == YES and user wanted to close an Untitled doc.
 */
- (BOOL)writeSafelyToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError
{
	if(saveOperation == NSSaveOperation) {
		// Dummy error to avoid crashes after Canceling the Save Panel
		if (outError) *outError = [NSError errorWithDomain:@"SP_DOMAIN" code:1000 userInfo:nil];
		[self saveConnectionSheet:nil];
		return NO;
	}
	return YES;
}

/**
 * Shows "save?" dialog when closing the document if the an Untitled doc has doc-based query favorites or content filters.
 */
- (BOOL)isDocumentEdited
{
	return (
		[self fileURL] && [[[self fileURL] path] length] && [self isUntitled] && ([[[SPQueryController sharedQueryController] favoritesForFileURL:[self fileURL]] count]
		|| [[[[SPQueryController sharedQueryController] contentFilterForFileURL:[self fileURL]] objectForKey:@"number"] count]
		|| [[[[SPQueryController sharedQueryController] contentFilterForFileURL:[self fileURL]] objectForKey:@"date"] count]
		|| [[[[SPQueryController sharedQueryController] contentFilterForFileURL:[self fileURL]] objectForKey:@"string"] count])
	);
}

/**
 * The window title for this document.
 */
- (NSString *)displayName
{
	if (!_isConnected) {
		return [NSString stringWithFormat:@"%@%@", ([[[self fileURL] path] length] && ![self isUntitled]) ? [NSString stringWithFormat:@"%@ — ",[[[self fileURL] path] lastPathComponent]] : @"", @"Sequel Pro"];
	} 
	return [[[self fileURL] path] lastPathComponent];
}

- (NSUndoManager *)undoManager
{
	return undoManager;
}

#pragma mark -
#pragma mark State saving and setting

/**
 * Retrieve the current database document state for saving.  A supplied dictionary
 * determines the level of detail that is required, with the following optional keys:
 *  - connection: Connection settings (with keychain references where available) and database
 *  - password: Whether to include passwords in the returned connection details
 *  - session: Selected table and view, together with content view filter, sort, scroll position
 *  - history: query history, per-doc query favourites, and per-doc content filters
 *  - query: custom query editor content
 *	- enablecompression: large (>50k) custom query editor contents will be stored as compressed data
 * If none of these are supplied, nil will be returned.
 */
- (NSDictionary *) stateIncludingDetails:(NSDictionary *)detailsToReturn
{
	BOOL returnConnection = [[detailsToReturn objectForKey:@"connection"] boolValue];
	BOOL includePasswords = [[detailsToReturn objectForKey:@"password"] boolValue];
	BOOL returnSession    = [[detailsToReturn objectForKey:@"session"] boolValue];
	BOOL returnHistory    = [[detailsToReturn objectForKey:@"history"] boolValue];
	BOOL returnQuery      = [[detailsToReturn objectForKey:@"query"] boolValue];

	if (!returnConnection && !returnSession && !returnHistory && !returnQuery) return nil;
	NSMutableDictionary *stateDetails = [NSMutableDictionary dictionary];

	// Add connection details
	if (returnConnection) {
		NSMutableDictionary *connection = [NSMutableDictionary dictionary];

		[connection setObject:@"mysql" forKey:@"rdbms_type"];

		NSString *connectionType;
		switch ([connectionController type]) {
			case SPTCPIPConnection:
				connectionType = @"SPTCPIPConnection";
				break;
			case SPSocketConnection:
				connectionType = @"SPSocketConnection";
				if ([connectionController socket] && [[connectionController socket] length]) [connection setObject:[connectionController socket] forKey:@"socket"];
				break;
			case SPSSHTunnelConnection:
				connectionType = @"SPSSHTunnelConnection";
				[connection setObject:[connectionController sshHost] forKey:@"ssh_host"];
				[connection setObject:[connectionController sshUser] forKey:@"ssh_user"];
				[connection setObject:[NSNumber numberWithInteger:[connectionController sshKeyLocationEnabled]] forKey:@"ssh_keyLocationEnabled"];
				if ([connectionController sshKeyLocation]) [connection setObject:[connectionController sshKeyLocation] forKey:@"ssh_keyLocation"];
				if ([connectionController sshPort] && [[connectionController sshPort] length]) [connection setObject:[NSNumber numberWithInteger:[[connectionController sshPort] integerValue]] forKey:@"ssh_port"];
				break;
			default:
				connectionType = @"SPTCPIPConnection";
		}
		[connection setObject:connectionType forKey:@"type"];

		NSString *kcid = [connectionController connectionKeychainID];
		if ([kcid length]) [connection setObject:kcid forKey:@"kcid"];
		[connection setObject:[self name] forKey:@"name"];
		[connection setObject:[self host] forKey:@"host"];
		[connection setObject:[self user] forKey:@"user"];
		if([connectionController colorIndex] >= 0)                              [connection setObject:[NSNumber numberWithInteger:[connectionController colorIndex]] forKey:SPFavoriteColorIndexKey];
		if([connectionController port] && [[connectionController port] length]) [connection setObject:[NSNumber numberWithInteger:[[connectionController port] integerValue]] forKey:@"port"];
		if([[self database] length])                                            [connection setObject:[self database] forKey:@"database"];

		if (includePasswords) {
			NSString *pw = [connectionController keychainPassword];
			if (!pw) pw = [connectionController password];
			if (pw) [connection setObject:pw forKey:@"password"];

			if ([connectionController type] == SPSSHTunnelConnection) {
				NSString *sshpw = [self keychainPasswordForSSHConnection:nil];
				if(![sshpw length]) sshpw = [connectionController sshPassword];
				[connection setObject:(sshpw ? sshpw : @"") forKey:@"ssh_password"];
			}
		}

		[connection setObject:[NSNumber numberWithInteger:[connectionController useSSL]] forKey:@"useSSL"];
		[connection setObject:[NSNumber numberWithInteger:[connectionController sslKeyFileLocationEnabled]] forKey:@"sslKeyFileLocationEnabled"];
		if ([connectionController sslKeyFileLocation]) [connection setObject:[connectionController sslKeyFileLocation] forKey:@"sslKeyFileLocation"];
		[connection setObject:[NSNumber numberWithInteger:[connectionController sslCertificateFileLocationEnabled]] forKey:@"sslCertificateFileLocationEnabled"];
		if ([connectionController sslCertificateFileLocation]) [connection setObject:[connectionController sslCertificateFileLocation] forKey:@"sslCertificateFileLocation"];
		[connection setObject:[NSNumber numberWithInteger:[connectionController sslCACertFileLocationEnabled]] forKey:@"sslCACertFileLocationEnabled"];
		if ([connectionController sslCACertFileLocation]) [connection setObject:[connectionController sslCACertFileLocation] forKey:@"sslCACertFileLocation"];

		[stateDetails setObject:[NSDictionary dictionaryWithDictionary:connection] forKey:@"connection"];
	}
	
	// Add document-specific saved settings
	if (returnHistory) {
		[stateDetails setObject:[[SPQueryController sharedQueryController] favoritesForFileURL:[self fileURL]] forKey:SPQueryFavorites];
		[stateDetails setObject:[[SPQueryController sharedQueryController] historyForFileURL:[self fileURL]] forKey:SPQueryHistory];
		[stateDetails setObject:[[SPQueryController sharedQueryController] contentFilterForFileURL:[self fileURL]] forKey:SPContentFilters];
	}

	// Set up a session state dictionary for either state or custom query
	NSMutableDictionary *sessionState = [NSMutableDictionary dictionary];

	// Store session state if appropriate
	if (returnSession) {

		if ([[self table] length]) [sessionState setObject:[self table] forKey:@"table"];

		NSString *currentlySelectedViewName;
		switch ([self currentlySelectedView]) {
			case SPTableViewStructure:
				currentlySelectedViewName = @"SP_VIEW_STRUCTURE";
				break;
			case SPTableViewContent:
				currentlySelectedViewName = @"SP_VIEW_CONTENT";
				break;
			case SPTableViewCustomQuery:
				currentlySelectedViewName = @"SP_VIEW_CUSTOMQUERY";
				break;
			case SPTableViewStatus:
				currentlySelectedViewName = @"SP_VIEW_STATUS";
				break;
			case SPTableViewRelations:
				currentlySelectedViewName = @"SP_VIEW_RELATIONS";
				break;
			case SPTableViewTriggers:
				currentlySelectedViewName = @"SP_VIEW_TRIGGERS";
				break;
			default:
				currentlySelectedViewName = @"SP_VIEW_STRUCTURE";
		}
		[sessionState setObject:currentlySelectedViewName forKey:@"view"];

		[sessionState setObject:[mySQLConnection encoding] forKey:@"connectionEncoding"];

		[sessionState setObject:[NSNumber numberWithBool:[[parentWindow toolbar] isVisible]] forKey:@"isToolbarVisible"];
		[sessionState setObject:[NSNumber numberWithFloat:[tableContentInstance tablesListWidth]] forKey:@"windowVerticalDividerPosition"];

		if ([tableContentInstance sortColumnName]) [sessionState setObject:[tableContentInstance sortColumnName] forKey:@"contentSortCol"];
		[sessionState setObject:[NSNumber numberWithBool:[tableContentInstance sortColumnIsAscending]] forKey:@"contentSortColIsAsc"];
		[sessionState setObject:[NSNumber numberWithInteger:[tableContentInstance pageNumber]] forKey:@"contentPageNumber"];
		[sessionState setObject:NSStringFromRect([tableContentInstance viewport]) forKey:@"contentViewport"];
		NSDictionary *filterSettings = [tableContentInstance filterSettings];
		if (filterSettings) [sessionState setObject:filterSettings forKey:@"contentFilterV2"];

		NSDictionary *contentSelectedRows = [tableContentInstance selectionDetailsAllowingIndexSelection:YES];
		if (contentSelectedRows) {
			[sessionState setObject:contentSelectedRows forKey:@"contentSelection"];
		}
	}

	// Add the custom query editor content if appropriate
	if (returnQuery) {
		NSString *queryString = [[[customQueryInstance valueForKeyPath:@"textView"] textStorage] string];
		if ([[detailsToReturn objectForKey:@"enablecompression"] boolValue] && [queryString length] > 50000) {
			[sessionState setObject:[[queryString dataUsingEncoding:NSUTF8StringEncoding] compress] forKey:@"queries"];
		} else {
			[sessionState setObject:queryString forKey:@"queries"];
		}
	}

	// Store the session state dictionary if either state or custom queries were saved
	if ([sessionState count]) [stateDetails setObject:[NSDictionary dictionaryWithDictionary:sessionState] forKey:@"session"];

	return stateDetails;
}

- (BOOL)setState:(NSDictionary *)stateDetails
{
	return [self setState:stateDetails fromFile:YES];
}

/**
 * Set the state of the document to the supplied dictionary, which should
 * at least contain a "connection" dictionary of details.
 * Returns whether the state was set successfully.
 */
- (BOOL)setState:(NSDictionary *)stateDetails fromFile:(BOOL)spfBased
{
	NSDictionary *connection = nil;
	NSInteger connectionType = -1;
	SPKeychain *keychain = nil;

	// If this document already has a connection, don't proceed.
	if (mySQLConnection) return NO;

	// Load the connection data from the state dictionary
	connection = [NSDictionary dictionaryWithDictionary:[stateDetails objectForKey:@"connection"]];
	if (!connection) return NO;

	if ([connection objectForKey:@"kcid"]) keychain = [[SPKeychain alloc] init];

	[self updateWindowTitle:self];

	if(spfBased) {
		// Deselect all favorites on the connection controller,
		// and clear and reset the connection state.
		[[connectionController favoritesOutlineView] deselectAll:connectionController];
		[connectionController updateFavoriteSelection:self];
		
		// Suppress the possibility to choose an other connection from the favorites
		// if a connection should initialized by SPF file. Otherwise it could happen
		// that the SPF file runs out of sync.
		[[connectionController favoritesOutlineView] setEnabled:NO];
	}
	else {
		[connectionController selectQuickConnectItem];
	}

	// Set the correct connection type
	NSString *typeString = [connection objectForKey:@"type"];
	if (typeString) {
		if ([typeString isEqualToString:@"SPTCPIPConnection"])          connectionType = SPTCPIPConnection;
		else if ([typeString isEqualToString:@"SPSocketConnection"])    connectionType = SPSocketConnection;
		else if ([typeString isEqualToString:@"SPSSHTunnelConnection"]) connectionType = SPSSHTunnelConnection;
		else                                                            connectionType = SPTCPIPConnection;

		[connectionController setType:connectionType];
		[connectionController resizeTabViewToConnectionType:connectionType animating:NO];
	}

	// Set basic details
	if ([connection objectForKey:@"name"])                 [connectionController setName:[connection objectForKey:@"name"]];
	if ([connection objectForKey:@"user"])                 [connectionController setUser:[connection objectForKey:@"user"]];
	if ([connection objectForKey:@"host"])                 [connectionController setHost:[connection objectForKey:@"host"]];
	if ([connection objectForKey:@"port"])                 [connectionController setPort:[NSString stringWithFormat:@"%ld", (long)[[connection objectForKey:@"port"] integerValue]]];
	if ([connection objectForKey:SPFavoriteColorIndexKey]) [connectionController setColorIndex:[(NSNumber *)[connection objectForKey:SPFavoriteColorIndexKey] integerValue]];

	// Set SSL details
	if ([connection objectForKey:@"useSSL"])                            [connectionController setUseSSL:[[connection objectForKey:@"useSSL"] intValue]];
	if ([connection objectForKey:@"sslKeyFileLocationEnabled"])         [connectionController setSslKeyFileLocationEnabled:[[connection objectForKey:@"sslKeyFileLocationEnabled"] intValue]];
	if ([connection objectForKey:@"sslKeyFileLocation"])                [connectionController setSslKeyFileLocation:[connection objectForKey:@"sslKeyFileLocation"]];
	if ([connection objectForKey:@"sslCertificateFileLocationEnabled"]) [connectionController setSslCertificateFileLocationEnabled:[[connection objectForKey:@"sslCertificateFileLocationEnabled"] intValue]];
	if ([connection objectForKey:@"sslCertificateFileLocation"])        [connectionController setSslCertificateFileLocation:[connection objectForKey:@"sslCertificateFileLocation"]];
	if ([connection objectForKey:@"sslCACertFileLocationEnabled"])      [connectionController setSslCACertFileLocationEnabled:[[connection objectForKey:@"sslCACertFileLocationEnabled"] intValue]];
	if ([connection objectForKey:@"sslCACertFileLocation"])             [connectionController setSslCACertFileLocation:[connection objectForKey:@"sslCACertFileLocation"]];

	// Set the keychain details if available
	NSString *kcid = (NSString *)[connection objectForKey:@"kcid"];
	if ([kcid length]) {
		[connectionController setConnectionKeychainID:kcid];
		[connectionController setConnectionKeychainItemName:[keychain nameForFavoriteName:[connectionController name] id:kcid]];
		[connectionController setConnectionKeychainItemAccount:[keychain accountForUser:[connectionController user] host:[connectionController host] database:[connection objectForKey:@"database"]]];
	}

	// Set password - if not in SPF file try to get it via the KeyChain
	if ([connection objectForKey:@"password"]) {
		[connectionController setPassword:[connection objectForKey:@"password"]];
	}
	else {
		NSString *pw = [connectionController keychainPassword];
		if (pw) [connectionController setPassword:pw];
	}

	// Set the socket details, whether or not the type is a socket
	if ([connection objectForKey:@"socket"])                 [connectionController setSocket:[connection objectForKey:@"socket"]];
	// Set SSH details if available, whether or not the SSH type is currently active (to allow fallback on failure)
	if ([connection objectForKey:@"ssh_host"])               [connectionController setSshHost:[connection objectForKey:@"ssh_host"]];
	if ([connection objectForKey:@"ssh_user"])               [connectionController setSshUser:[connection objectForKey:@"ssh_user"]];
	if ([connection objectForKey:@"ssh_keyLocationEnabled"]) [connectionController setSshKeyLocationEnabled:[[connection objectForKey:@"ssh_keyLocationEnabled"] intValue]];
	if ([connection objectForKey:@"ssh_keyLocation"])        [connectionController setSshKeyLocation:[connection objectForKey:@"ssh_keyLocation"]];
	if ([connection objectForKey:@"ssh_port"])               [connectionController setSshPort:[NSString stringWithFormat:@"%ld", (long)[[connection objectForKey:@"ssh_port"] integerValue]]];

	// Set the SSH password - if not in SPF file try to get it via the KeyChain
	if ([connection objectForKey:@"ssh_password"]) {
		[connectionController setSshPassword:[connection objectForKey:@"ssh_password"]];
	}
	else {
		if ([kcid length]) {
			[connectionController setConnectionSSHKeychainItemName:[keychain nameForSSHForFavoriteName:[connectionController name] id:kcid]];
			[connectionController setConnectionSSHKeychainItemAccount:[keychain accountForSSHUser:[connectionController sshUser] sshHost:[connectionController sshHost]]];
		}
		NSString *sshpw = [self keychainPasswordForSSHConnection:nil];
		if(sshpw) [connectionController setSshPassword:sshpw];
	}

	// Restore the selected database if saved
	if ([connection objectForKey:@"database"]) [connectionController setDatabase:[connection objectForKey:@"database"]];

	// Store session details - if provided - for later setting once the connection is established
	if ([stateDetails objectForKey:@"session"]) {
		spfSession = [[NSDictionary dictionaryWithDictionary:[stateDetails objectForKey:@"session"]] retain];
	}

	// Restore favourites and history
	id o;
	if ((o = [stateDetails objectForKey:SPQueryFavorites])) [spfPreferences setObject:o forKey:SPQueryFavorites];
	if ((o = [stateDetails objectForKey:SPQueryHistory]))   [spfPreferences setObject:o forKey:SPQueryHistory];
	if ((o = [stateDetails objectForKey:SPContentFilters])) [spfPreferences setObject:o forKey:SPContentFilters];

	[connectionController updateSSLInterface:self];

	// Autoconnect if appropriate
	if ([stateDetails objectForKey:@"auto_connect"] && [[stateDetails valueForKey:@"auto_connect"] boolValue]) {
		[self connect];
	}

	if (keychain) [keychain release];

	return YES;
}

/**
 * Initialise the document with the connection file at the supplied path.
 * Returns whether the document was initialised successfully.
 */
- (BOOL)setStateFromConnectionFile:(NSString *)path
{
	NSString *encryptpw = nil;
	NSMutableDictionary *data = nil;
	NSDictionary *spf = nil;

	{
		NSError *error = nil;
		
		// Read the property list data, and unserialize it.
		NSData *pData = [NSData dataWithContentsOfFile:path options:NSUncachedRead error:&error];
		
		if(pData && !error) {
			spf = [[NSPropertyListSerialization propertyListWithData:pData
			                                                 options:NSPropertyListImmutable
			                                                  format:NULL
			                                                   error:&error] retain];
		}
		
		if (!spf || error) {
			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error while reading connection data file", @"error while reading connection data file")
			                                 defaultButton:NSLocalizedString(@"OK", @"OK button")
			                               alternateButton:nil
			                                   otherButton:nil
			                     informativeTextWithFormat:NSLocalizedString(@"Connection data file couldn't be read. (%@)", @"error while reading connection data file"), [error localizedDescription]];
			
			[alert setAlertStyle:NSCriticalAlertStyle];
			[alert runModal];
			if (spf) [spf release];
			[self closeAndDisconnect];
			return NO;
		}
	}

	// If the .spf format is unhandled, error.
	if (![[spf objectForKey:SPFFormatKey] isEqualToString:SPFConnectionContentType]) {
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Unknown file format", @"warning")]
		                                 defaultButton:NSLocalizedString(@"OK", @"OK button")
		                               alternateButton:nil
		                                   otherButton:nil
		                     informativeTextWithFormat:NSLocalizedString(@"The chosen file “%@” contains ‘%@’ data.", @"message while reading a spf file which matches non-supported formats."), path, [spf objectForKey:SPFFormatKey]];

		[alert setAlertStyle:NSWarningAlertStyle];
		[spf release];
		[self closeAndDisconnect];
		[alert runModal];
		return NO;
	}

	// Error if the expected data source wasn't present in the file
	if (![spf objectForKey:@"data"]) {
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while reading connection data file", @"error while reading connection data file")]
		                                 defaultButton:NSLocalizedString(@"OK", @"OK button")
		                               alternateButton:nil
		                                   otherButton:nil
		                     informativeTextWithFormat:NSLocalizedString(@"No data found.", @"no data found")];

		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
		[spf release];
		[self closeAndDisconnect];
		return NO;
	}

	// Ask for a password if SPF file passwords were encrypted, via a sheet
	if ([spf objectForKey:@"encrypted"] && [[spf valueForKey:@"encrypted"] boolValue]) {
		if([self isSaveInBundle] && [[SPAppDelegate spfSessionDocData] objectForKey:@"e_string"]) {
			encryptpw = [[SPAppDelegate spfSessionDocData] objectForKey:@"e_string"];
		} else {
			[inputTextWindowHeader setStringValue:NSLocalizedString(@"Connection file is encrypted", @"Connection file is encrypted")];
			[inputTextWindowMessage setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Please enter the password for ‘%@’:", @"Please enter the password"), ([self isSaveInBundle]) ? [[[SPAppDelegate sessionURL] absoluteString] lastPathComponent] : [path lastPathComponent]]];
			[inputTextWindowSecureTextField setStringValue:@""];
			[inputTextWindowSecureTextField selectText:nil];

			[NSApp beginSheet:inputTextWindow modalForWindow:parentWindow modalDelegate:self didEndSelector:nil contextInfo:nil];

			// wait for encryption password
			NSModalSession session = [NSApp beginModalSessionForWindow:inputTextWindow];
			for (;;) {

				// Execute code on DefaultRunLoop
				[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];

				// Break the run loop if editSheet was closed
				if ([NSApp runModalSession:session] != NSRunContinuesResponse || ![inputTextWindow isVisible]) break;

				// Execute code on DefaultRunLoop
				[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];

			}
			[NSApp endModalSession:session];
			[inputTextWindow orderOut:nil];
			[NSApp endSheet:inputTextWindow];

			if (passwordSheetReturnCode) {
				encryptpw = [inputTextWindowSecureTextField stringValue];
				if ([self isSaveInBundle]) {
					NSMutableDictionary *spfSessionData = [NSMutableDictionary dictionary];
					[spfSessionData addEntriesFromDictionary:[SPAppDelegate spfSessionDocData]];
					[spfSessionData setObject:encryptpw forKey:@"e_string"];
					[SPAppDelegate setSpfSessionDocData:spfSessionData];
				}
			} else {
				[self closeAndDisconnect];
				[spf release];
				return NO;
			}
		}
	}

	if ([[spf objectForKey:@"data"] isKindOfClass:[NSDictionary class]])
		data = [NSMutableDictionary dictionaryWithDictionary:[spf objectForKey:@"data"]];

		// If a content selection data key exists in the session, decode it
		if ([[[data objectForKey:@"session"] objectForKey:@"contentSelection"] isKindOfClass:[NSData class]]) {
			NSMutableDictionary *sessionInfo = [NSMutableDictionary dictionaryWithDictionary:[data objectForKey:@"session"]];
			NSKeyedUnarchiver *unarchiver = [[[NSKeyedUnarchiver alloc] initForReadingWithData:[sessionInfo objectForKey:@"contentSelection"]] autorelease];
			[sessionInfo setObject:[unarchiver decodeObjectForKey:@"data"] forKey:@"contentSelection"];
			[unarchiver finishDecoding];
			[data setObject:sessionInfo forKey:@"session"];
		}

	else if ([[spf objectForKey:@"data"] isKindOfClass:[NSData class]]) {
		NSData *decryptdata = nil;
		decryptdata = [[[NSMutableData alloc] initWithData:[(NSData *)[spf objectForKey:@"data"] dataDecryptedWithPassword:encryptpw]] autorelease];
		if (decryptdata != nil && [decryptdata length]) {
			NSKeyedUnarchiver *unarchiver = [[[NSKeyedUnarchiver alloc] initForReadingWithData:decryptdata] autorelease];
			data = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)[unarchiver decodeObjectForKey:@"data"]];
			[unarchiver finishDecoding];
		}
		if (data == nil) {
			NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while reading connection data file", @"error while reading connection data file")]
			                                 defaultButton:NSLocalizedString(@"OK", @"OK button")
			                               alternateButton:nil
			                                   otherButton:nil
			                     informativeTextWithFormat:NSLocalizedString(@"Wrong data format or password.", @"wrong data format or password")];

			[alert setAlertStyle:NSCriticalAlertStyle];
			[alert runModal];
			[self closeAndDisconnect];
			[spf release];
			return NO;
		}
	}

	// Ensure the data was read correctly, and has connection details
	if (!data || ![data objectForKey:@"connection"]) {
		NSString *informativeText;
		if (!data) {
			informativeText = NSLocalizedString(@"Wrong data format.", @"wrong data format");
		} else {
			informativeText = NSLocalizedString(@"No connection data found.", @"no connection data found");
		}
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while reading connection data file", @"error while reading connection data file")]
		                                 defaultButton:NSLocalizedString(@"OK", @"OK button")
		                               alternateButton:nil
		                                   otherButton:nil
		                     informativeTextWithFormat:@"%@", informativeText];

		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
		[self closeAndDisconnect];
		[spf release];
		return NO;
	}

	// Move favourites and history into the data dictionary to pass to setState:
	[data setObject:[spf objectForKey:SPQueryFavorites] forKey:SPQueryFavorites];
	[data setObject:[spf objectForKey:SPQueryHistory] forKey:SPQueryHistory];
	[data setObject:[spf objectForKey:SPContentFilters] forKey:SPContentFilters];

	// Ensure the encryption status is stored in the spfDocData store for future saves
	[spfDocData setObject:@NO forKey:@"encrypted"];
	if (encryptpw != nil) {
		[spfDocData setObject:@YES forKey:@"encrypted"];
		[spfDocData setObject:encryptpw forKey:@"e_string"];
	}
	encryptpw = nil;

	// If session data is available, ensure it is marked for save
	if ([data objectForKey:@"session"]) {
		[spfDocData setObject:@YES forKey:@"include_session"];
	}

	if (![self isSaveInBundle]) {
		NSURL *newURL = [NSURL fileURLWithPath:path];
		[self setFileURL:newURL];
	}

	[spfDocData setObject:[NSNumber numberWithBool:([[data objectForKey:@"connection"] objectForKey:@"password"]) ? YES : NO] forKey:@"save_password"];

	[spfDocData setObject:@NO forKey:@"auto_connect"];

	if([spf objectForKey:@"auto_connect"] && [[spf valueForKey:@"auto_connect"] boolValue]) {
		[spfDocData setObject:@YES forKey:@"auto_connect"];
		[data setObject:@YES forKey:@"auto_connect"];
	}

	// Set the state dictionary, triggering an autoconnect if appropriate
	[self setState:data];

	[spf release];

	return YES;
}

/**
 * Restore the session from SPF file if given.
 */
- (void)restoreSession
{
	@autoreleasepool {
		// Check and set the table
		NSArray *tables = [tablesListInstance tables];

		NSUInteger tableIndex = [tables indexOfObject:[spfSession objectForKey:@"table"]];

		// Restore toolbar setting
		if ([spfSession objectForKey:@"isToolbarVisible"]) {
			[[mainToolbar onMainThread] setVisible:[[spfSession objectForKey:@"isToolbarVisible"] boolValue]];
		}

		// Reset database view encoding if differs from default
		if ([spfSession objectForKey:@"connectionEncoding"] && ![[mySQLConnection encoding] isEqualToString:[spfSession objectForKey:@"connectionEncoding"]]) {
			[self setConnectionEncoding:[spfSession objectForKey:@"connectionEncoding"] reloadingViews:YES];
		}

		if (tableIndex != NSNotFound) {
			// Set table content details for restore
			if ([spfSession objectForKey:@"contentSortCol"])    [tableContentInstance setSortColumnNameToRestore:[spfSession objectForKey:@"contentSortCol"] isAscending:[[spfSession objectForKey:@"contentSortColIsAsc"] boolValue]];
			if ([spfSession objectForKey:@"contentPageNumber"]) [tableContentInstance setPageToRestore:[[spfSession objectForKey:@"pageNumber"] integerValue]];
			if ([spfSession objectForKey:@"contentViewport"])   [tableContentInstance setViewportToRestore:NSRectFromString([spfSession objectForKey:@"contentViewport"])];
			if ([spfSession objectForKey:@"contentFilterV2"])   [tableContentInstance setFiltersToRestore:[spfSession objectForKey:@"contentFilterV2"]];

			// Select table
			[[tablesListInstance onMainThread] selectTableAtIndex:@(tableIndex)];

			// Restore table selection indexes
			if ([spfSession objectForKey:@"contentSelection"]) {
				[tableContentInstance setSelectionToRestore:[spfSession objectForKey:@"contentSelection"]];
			}

			// Scroll to table
#warning Private ivar accessed from outside (#2978)
			[[[tablesListInstance valueForKeyPath:@"tablesListView"] onMainThread] scrollRowToVisible:tableIndex];
		}

		// update UI on main thread
		SPMainQSync(^{
			// Select view
			NSString *view = [spfSession objectForKey:@"view"];

			     if ([view isEqualToString:@"SP_VIEW_STRUCTURE"])   [self viewStructure:self];
			else if ([view isEqualToString:@"SP_VIEW_CONTENT"])     [self viewContent:self];
			else if ([view isEqualToString:@"SP_VIEW_CUSTOMQUERY"]) [self viewQuery:self];
			else if ([view isEqualToString:@"SP_VIEW_STATUS"])      [self viewStatus:self];
			else if ([view isEqualToString:@"SP_VIEW_RELATIONS"])   [self viewRelations:self];
			else if ([view isEqualToString:@"SP_VIEW_TRIGGERS"])    [self viewTriggers:self];

			[self updateWindowTitle:self];
		});

		// dealloc spfSession data
		SPClear(spfSession);

		// End the task
		[self endTask];
	}
}
#endif

#pragma mark -
#pragma mark Connection controller delegate methods

/**
 * Invoked by the connection controller when it starts the process of initiating a connection.
 */
- (void)connectionControllerInitiatingConnection:(SPConnectionController *)controller
{
#ifndef SP_CODA /* ui manipulation */
	// Update the window title to indicate that we are trying to establish a connection
	[parentTabViewItem setLabel:NSLocalizedString(@"Connecting…", @"window title string indicating that sp is connecting")];
	
	if ([parentWindowController selectedTableDocument] == self) {
		[parentWindow setTitle:NSLocalizedString(@"Connecting…", @"window title string indicating that sp is connecting")];
	}
#endif
}

/**
 * Invoked by the connection controller when the attempt to initiate a connection failed.
 */
- (void)connectionControllerConnectAttemptFailed:(SPConnectionController *)controller
{
#ifdef SP_CODA /* glue */
	if ( delegate && [delegate respondsToSelector:@selector(databaseDocumentConnectionFailed:)] )
		[delegate performSelector:@selector(databaseDocumentConnectionFailed:) withObject:self];
#endif

#ifndef SP_CODA /* updateWindowTitle: */
	// Reset the window title
	[self updateWindowTitle:self];
#endif
}

- (SPConnectionController*)connectionController
{
	return connectionController;
}

#ifdef SP_CODA

- (void)databaseDocumentConnectionFailed:(id)sender
{
	if ( delegate && [delegate respondsToSelector:@selector(databaseDocumentConnectionFailed:)] )
		[delegate performSelector:@selector(databaseDocumentConnectionFailed:) withObject:self];
}
#endif


#ifndef SP_CODA /* scheme scripting methods */

#pragma mark -
#pragma mark Scheme scripting methods

/** 
 * Called by handleSchemeCommand: to break a while loop
 */
- (void)setTimeout
{
	_workingTimeout = YES;
}

/** 
 * Process passed URL scheme command and wait (timeouted) for the document if it's busy or not yet connected
 */
- (void)handleSchemeCommand:(NSDictionary*)commandDict
{
	if(!commandDict) return;

	NSArray *params = [commandDict objectForKey:@"parameter"];
	if(![params count]) {
		NSLog(@"No URL scheme command passed");
		NSBeep();
		return;
	}
	
	NSString *command = [params objectAtIndex:0];
	NSString *docProcessID = [self processID];
	if(!docProcessID) docProcessID = @"";

	// Wait for self
	_workingTimeout = NO;
	// the following while loop waits maximal 5secs
	[self performSelector:@selector(setTimeout) withObject:nil afterDelay:5.0];
	while (_isWorkingLevel || !_isConnected) {
		if(_workingTimeout) break;
		// Do not block self
		NSEvent *event = [NSApp nextEventMatchingMask:NSAnyEventMask
		                                    untilDate:[NSDate distantPast]
		                                       inMode:NSDefaultRunLoopMode
		                                      dequeue:YES];
		if(event) [NSApp sendEvent:event];

	}

	if([command isEqualToString:@"SelectDocumentView"]) {
		if([params count] == 2) {
			NSString *view = [params objectAtIndex:1];
			if([view length]) {
				NSString *viewName = [view lowercaseString];
				     if([viewName hasPrefix:@"str"]) [self viewStructure:self];
				else if([viewName hasPrefix:@"con"]) [self viewContent:self];
				else if([viewName hasPrefix:@"que"]) [self viewQuery:self];
				else if([viewName hasPrefix:@"tab"]) [self viewStatus:self];
				else if([viewName hasPrefix:@"rel"]) [self viewRelations:self];
				else if([viewName hasPrefix:@"tri"]) [self viewTriggers:self];

				[self updateWindowTitle:self];
			}
		}
		return;
	}

	if([command isEqualToString:@"SelectTable"]) {
		if([params count] == 2) {
			NSString *tableName = [params objectAtIndex:1];
			if([tableName length]) {
				[tablesListInstance selectItemWithName:tableName];
			}
		}
		return;
	}

	if([command isEqualToString:@"SelectTables"]) {
		if([params count] > 1) {
			[tablesListInstance selectItemsWithNames:[params subarrayWithRange:NSMakeRange(1, [params count]-1)]];
		}
		return;
	}

	if([command isEqualToString:@"SelectDatabase"]) {
		if([params count] > 1) {
			NSString *dbName = [params objectAtIndex:1];
			NSString *tableName = nil;
			if([dbName length]) {
				if([params count] == 3) {
					tableName = [params objectAtIndex:2];
				}
				[self selectDatabase:dbName item:tableName];
			}
		}
		return;
	}

	// ==== the following commands need an authentication for safety reasons

	// Authenticate command
	if(![docProcessID isEqualToString:[commandDict objectForKey:@"id"]]) {
		SPOnewayAlertSheet(
			NSLocalizedString(@"Remote Error", @"remote error"),
			[self parentWindow],
			NSLocalizedString(@"URL scheme command couldn't authenticated", @"URL scheme command couldn't authenticated")
		);
		return;
	}

	if([command isEqualToString:@"SetSelectedTextRange"]) {
		if([params count] > 1) {
			id firstResponder = [parentWindow firstResponder];
			if([firstResponder isKindOfClass:[NSTextView class]]) {
				NSRange theRange = NSIntersectionRange(NSRangeFromString([params objectAtIndex:1]), NSMakeRange(0, [[firstResponder string] length]));
				if(theRange.location != NSNotFound) {
					[firstResponder setSelectedRange:theRange];
				}
				return;
			}
			NSBeep();
		}
		return;
	}

	if([command isEqualToString:@"InsertText"]) {
		if([params count] > 1) {
			id firstResponder = [parentWindow firstResponder];
			if([firstResponder isKindOfClass:[NSTextView class]]) {
				[firstResponder insertText:[params objectAtIndex:1]];
				return;
			}
			NSBeep();
		}
		return;
	}

	if([command isEqualToString:@"SetText"]) {
		if([params count] > 1) {
			id firstResponder = [parentWindow firstResponder];
			if([firstResponder isKindOfClass:[NSTextView class]]) {
				[firstResponder setSelectedRange:NSMakeRange(0, [[firstResponder string] length])];
				[firstResponder insertText:[params objectAtIndex:1]];
				return;
			}
			NSBeep();
		}
		return;
	}

	if([command isEqualToString:@"SelectTableRows"]) {
		id firstResponder = [[NSApp keyWindow] firstResponder];
		if([params count] > 1 && [firstResponder respondsToSelector:@selector(selectTableRows:)]) {
			[(SPCopyTable *)firstResponder selectTableRows:[params subarrayWithRange:NSMakeRange(1, [params count]-1)]];
		}
		return;
	}

	if([command isEqualToString:@"ReloadContentTable"]) {
		[tableContentInstance reloadTable:self];
		return;
	}

	if([command isEqualToString:@"ReloadTablesList"]) {
		[tablesListInstance updateTables:self];
		return;
	}

	if([command isEqualToString:@"ReloadContentTableWithWHEREClause"]) {
		NSString *queryFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryInputPathHeader, docProcessID];
		NSFileManager *fm = [NSFileManager defaultManager];
		BOOL isDir;
		if([fm fileExistsAtPath:queryFileName isDirectory:&isDir] && !isDir) {
			NSError *inError = nil;
			NSString *query = [NSString stringWithContentsOfFile:queryFileName encoding:NSUTF8StringEncoding error:&inError];
			[fm removeItemAtPath:queryFileName error:nil];
			if(inError == nil && query && [query length]) {
				[tableContentInstance filterTable:query];
			}
		}
		return;
	}

	if([command isEqualToString:@"RunQueryInQueryEditor"]) {
		NSString *queryFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryInputPathHeader, docProcessID];
		NSFileManager *fm = [NSFileManager defaultManager];
		BOOL isDir;
		if([fm fileExistsAtPath:queryFileName isDirectory:&isDir] && !isDir) {
			NSError *inError = nil;
			NSString *query = [NSString stringWithContentsOfFile:queryFileName encoding:NSUTF8StringEncoding error:&inError];
			[fm removeItemAtPath:queryFileName error:nil];
			if(inError == nil && query && [query length]) {
				[customQueryInstance performQueries:@[query] withCallback:NULL];
			}
		}
		return;
	}

	if([command isEqualToString:@"CreateSyntaxForTables"]) {

		if([params count] > 1) {

			NSString *queryFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryInputPathHeader, docProcessID];
			NSString *resultFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultPathHeader, docProcessID];
			NSString *metaFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultMetaPathHeader, docProcessID];
			NSString *statusFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultStatusPathHeader, docProcessID];
			NSFileManager *fm = [NSFileManager defaultManager];
			NSString *status = @"0";
			BOOL userTerminated = NO;
			BOOL doSyntaxHighlighting = NO;
			BOOL doSyntaxHighlightingViaCSS = NO;

			if([[params lastObject] hasPrefix:@"html"]) {
				doSyntaxHighlighting = YES;
				if([[params lastObject] hasSuffix:@"css"]) {
					doSyntaxHighlightingViaCSS = YES;
				}
			}

			if(doSyntaxHighlighting && [params count] < 3) return;

			BOOL changeEncoding = ![[mySQLConnection encoding] isEqualToString:@"utf8"];

			NSArray *items = [params subarrayWithRange:NSMakeRange(1, [params count]-( (doSyntaxHighlighting) ? 2 : 1) )];
			NSArray *availableItems = [tablesListInstance tables];
			NSArray *availableItemTypes = [tablesListInstance tableTypes];
			NSMutableString *result = [NSMutableString string];

			for(NSString* item in items) {

				NSEvent* event = [NSApp currentEvent];
				if ([event type] == NSKeyDown) {
					unichar key = [[event characters] length] == 1 ? [[event characters] characterAtIndex:0] : 0;
					if (([event modifierFlags] & NSEventModifierFlagCommand) && key == '.') {
						userTerminated = YES;
						break;
					}
				}

				NSInteger itemType = SPTableTypeNone;
				NSUInteger i;

				// Loop through the unfiltered tables/views to find the desired item
				for (i = 0; i < [availableItems count]; i++) {
					itemType = [[availableItemTypes objectAtIndex:i] integerValue];
					if (itemType == SPTableTypeNone) continue;
					if ([[availableItems objectAtIndex:i] isEqualToString:item]) {
						break;
					}
				}
				// If no match found, continue
				if (itemType == SPTableTypeNone) continue;

				NSString *itemTypeStr;
				NSInteger queryCol;

				switch(itemType) {
					case SPTableTypeTable:
					case SPTableTypeView:
						itemTypeStr = @"TABLE";
						queryCol = 1;
						break;
					case SPTableTypeProc:
						itemTypeStr = @"PROCEDURE";
						queryCol = 2;
						break;
					case SPTableTypeFunc:
						itemTypeStr = @"FUNCTION";
						queryCol = 2;
						break;
					default:
						NSLog(@"%s: Unhandled SPTableType=%ld for item=%@ (skipping)", __func__, itemType, item);
						continue;
				}

				// Ensure that queries are made in UTF8
				if (changeEncoding) {
					[mySQLConnection storeEncodingForRestoration];
					[mySQLConnection setEncoding:@"utf8"];
				}

				// Get create syntax
				SPMySQLResult *queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE %@ %@",
				                                                                                     itemTypeStr,
				                                                                                     [item backtickQuotedString]]];
				[queryResult setReturnDataAsStrings:YES];

				if (changeEncoding) [mySQLConnection restoreStoredEncoding];

				if ( ![queryResult numberOfRows] ) {
					//error while getting table structure
					SPOnewayAlertSheet(
						NSLocalizedString(@"Error", @"error"),
						[self parentWindow],
						[NSString stringWithFormat:NSLocalizedString(@"Couldn't get create syntax.\nMySQL said: %@", @"message of panel when table information cannot be retrieved"), [mySQLConnection lastErrorMessage]]
					);

					status = @"1";

				} else {
					NSString *syntaxString = [[queryResult getRowAsArray] objectAtIndex:queryCol];

					// A NULL value indicates that the user does not have permission to view the syntax
					if ([syntaxString isNSNull]) {
						SPOnewayAlertSheet(
							NSLocalizedString(@"Permission Denied", @"Permission Denied"),
							[NSApp mainWindow],
							NSLocalizedString(@"The creation syntax could not be retrieved due to a permissions error.\n\nPlease check your user permissions with an administrator.", @"Create syntax permission denied detail")
						);
						return;
					}
					if(doSyntaxHighlighting) {
						[result appendFormat:@"%@<br>", [SPAppDelegate doSQLSyntaxHighlightForString:[syntaxString createViewSyntaxPrettifier] cssLike:doSyntaxHighlightingViaCSS]];
					} else {
						[result appendFormat:@"%@\n", [syntaxString createViewSyntaxPrettifier]];
					}
				}
			}
			
			[fm removeItemAtPath:queryFileName error:nil];
			[fm removeItemAtPath:resultFileName error:nil];
			[fm removeItemAtPath:metaFileName error:nil];
			[fm removeItemAtPath:statusFileName error:nil];

			if(userTerminated)
				status = @"1";

			if(![result writeToFile:resultFileName atomically:YES encoding:NSUTF8StringEncoding error:nil])
				status = @"1";

			// write status file as notification that query was finished
			BOOL succeed = [status writeToFile:statusFileName atomically:YES encoding:NSUTF8StringEncoding error:nil];
			if(!succeed) {
				NSBeep();
				SPOnewayAlertSheet(
					NSLocalizedString(@"BASH Error", @"bash error"),
					[self parentWindow],
					NSLocalizedString(@"Status file for sequelpro url scheme command couldn't be written!", @"status file for sequelpro url scheme command couldn't be written error message")
				);
			}
			
		}
		return;
	}

	if([command isEqualToString:@"ExecuteQuery"]) {

		NSString *outputFormat = @"tab";
		if([params count] == 2)
			outputFormat = [params objectAtIndex:1];

		BOOL writeAsCsv = ([outputFormat isEqualToString:@"csv"]) ? YES : NO;

		NSString *queryFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryInputPathHeader, docProcessID];
		NSString *resultFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultPathHeader, docProcessID];
		NSString *metaFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultMetaPathHeader, docProcessID];
		NSString *statusFileName = [NSString stringWithFormat:@"%@%@", SPURLSchemeQueryResultStatusPathHeader, docProcessID];
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *status = @"0";
		BOOL isDir;
		BOOL userTerminated = NO;
		if([fm fileExistsAtPath:queryFileName isDirectory:&isDir] && !isDir) {

			NSError *inError = nil;
			NSString *query = [NSString stringWithContentsOfFile:queryFileName encoding:NSUTF8StringEncoding error:&inError];

			[fm removeItemAtPath:queryFileName error:nil];
			[fm removeItemAtPath:resultFileName error:nil];
			[fm removeItemAtPath:metaFileName error:nil];
			[fm removeItemAtPath:statusFileName error:nil];

			if(inError == nil && query && [query length]) {

				SPFileHandle *fh = [SPFileHandle fileHandleForWritingAtPath:resultFileName];
				if(!fh) NSLog(@"Couldn't create file handle to %@", resultFileName);

				SPMySQLResult *theResult = [mySQLConnection streamingQueryString:query];
				[theResult setReturnDataAsStrings:YES];
				if ([mySQLConnection queryErrored]) {
					[fh writeData:[[NSString stringWithFormat:@"MySQL said: %@", [mySQLConnection lastErrorMessage]] dataUsingEncoding:NSUTF8StringEncoding]];
					status = @"1";
				} else {

					// write header
					if(writeAsCsv)
						[fh writeData:[[[theResult fieldNames] componentsJoinedAsCSV] dataUsingEncoding:NSUTF8StringEncoding]];
					else
						[fh writeData:[[[theResult fieldNames] componentsJoinedByString:@"\t"] dataUsingEncoding:NSUTF8StringEncoding]];
					[fh writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];

					NSArray *columnDefinition = [theResult fieldDefinitions];

					// Write table meta data
					NSMutableString *tableMetaData = [NSMutableString string];
					for(NSDictionary* col in columnDefinition) {
						[tableMetaData appendFormat:@"%@\t", [col objectForKey:@"type"]];
						[tableMetaData appendFormat:@"%@\t", [col objectForKey:@"typegrouping"]];
						[tableMetaData appendFormat:@"%@\t", ([col objectForKey:@"char_length"]) ? : @""];
						[tableMetaData appendFormat:@"%@\t", [col objectForKey:@"UNSIGNED_FLAG"]];
						[tableMetaData appendFormat:@"%@\t", [col objectForKey:@"AUTO_INCREMENT_FLAG"]];
						[tableMetaData appendFormat:@"%@\t", [col objectForKey:@"PRI_KEY_FLAG"]];
						[tableMetaData appendString:@"\n"];
					}
					NSError *err = nil;
					[tableMetaData writeToFile:metaFileName
					                atomically:YES
					                  encoding:NSUTF8StringEncoding
					                     error:&err];
					if(err != nil) {
						NSLog(@"Error while writing “%@”", tableMetaData);
						NSBeep();
						return;
					}

					// write data
					NSUInteger i, j;
					NSArray *theRow;
					NSMutableString *result = [NSMutableString string];
					if(writeAsCsv) {
						for ( i = 0 ; i < [theResult numberOfRows] ; i++ ) {
							[result setString:@""];
							theRow = [theResult getRowAsArray];
							for( j = 0 ; j < [theRow count] ; j++ ) {

								NSEvent* event = [NSApp currentEvent];
								if ([event type] == NSKeyDown) {
									unichar key = [[event characters] length] == 1 ? [[event characters] characterAtIndex:0] : 0;
									if (([event modifierFlags] & NSEventModifierFlagCommand) && key == '.') {
										userTerminated = YES;
										break;
									}
								}

								if([result length]) [result appendString:@","];
								id cell = NSArrayObjectAtIndex(theRow, j);
								if([cell isNSNull])
									[result appendString:@"\"NULL\""];
								else if([cell isKindOfClass:[SPMySQLGeometryData class]])
									[result appendFormat:@"\"%@\"", [cell wktString]];
								else if([cell isKindOfClass:[NSData class]]) {
									NSString *displayString = [[NSString alloc] initWithData:cell encoding:[mySQLConnection stringEncoding]];
									if (!displayString) displayString = [[NSString alloc] initWithData:cell encoding:NSASCIIStringEncoding];
									if (displayString) {
										[result appendFormat:@"\"%@\"", [displayString stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
										[displayString release];
									} else {
										[result appendString:@"\"\""];
									}
								}
								else
									[result appendFormat:@"\"%@\"", [[cell description] stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
							}
							if(userTerminated) break;
							[result appendString:@"\n"];
							[fh writeData:[result dataUsingEncoding:NSUTF8StringEncoding]];
						}
					}
					else {
						for ( i = 0 ; i < [theResult numberOfRows] ; i++ ) {
							[result setString:@""];
							theRow = [theResult getRowAsArray];
							for( j = 0 ; j < [theRow count] ; j++ ) {

								NSEvent* event = [NSApp currentEvent];
								if ([event type] == NSKeyDown) {
									unichar key = [[event characters] length] == 1 ? [[event characters] characterAtIndex:0] : 0;
									if (([event modifierFlags] & NSEventModifierFlagCommand) && key == '.') {
										userTerminated = YES;
										break;
									}
								}

								if([result length]) [result appendString:@"\t"];
								id cell = NSArrayObjectAtIndex(theRow, j);
								if([cell isNSNull])
									[result appendString:@"NULL"];
								else if([cell isKindOfClass:[SPMySQLGeometryData class]])
									[result appendFormat:@"%@", [cell wktString]];
								else if([cell isKindOfClass:[NSData class]]) {
									NSString *displayString = [[NSString alloc] initWithData:cell encoding:[mySQLConnection stringEncoding]];
									if (!displayString) displayString = [[NSString alloc] initWithData:cell encoding:NSASCIIStringEncoding];
									if (displayString) {
										[result appendFormat:@"%@", [[displayString stringByReplacingOccurrencesOfString:@"\n" withString:@"↵"] stringByReplacingOccurrencesOfString:@"\t" withString:@"⇥"]];
										[displayString release];
									} else {
										[result appendString:@""];
									}
								}
								else
									[result appendString:[[[cell description] stringByReplacingOccurrencesOfString:@"\n" withString:@"↵"] stringByReplacingOccurrencesOfString:@"\t" withString:@"⇥"]];
							}
							if(userTerminated) break;
							[result appendString:@"\n"];
							[fh writeData:[result dataUsingEncoding:NSUTF8StringEncoding]];
						}
					}
				}
				[fh closeFile];
			}
		}

		if(userTerminated) {
			[SPTooltip showWithObject:NSLocalizedString(@"URL scheme command was terminated by user", @"URL scheme command was terminated by user") atLocation:[NSEvent mouseLocation]];
			status = @"1";
		}

		// write status file as notification that query was finished
		BOOL succeed = [status writeToFile:statusFileName atomically:YES encoding:NSUTF8StringEncoding error:nil];
		if(!succeed) {
			NSBeep();
			SPOnewayAlertSheet(
				NSLocalizedString(@"BASH Error", @"bash error"),
				[self parentWindow],
				NSLocalizedString(@"Status file for sequelpro url scheme command couldn't be written!", @"status file for sequelpro url scheme command couldn't be written error message")
			);
		}
		return;
	}

	SPOnewayAlertSheet(
		NSLocalizedString(@"Remote Error", @"remote error"),
		[self parentWindow],
		[NSString stringWithFormat:NSLocalizedString(@"URL scheme command “%@” unsupported", @"URL scheme command “%@” unsupported"), command]
	);
}

- (void)registerActivity:(NSDictionary *)commandDict
{
	[runningActivitiesArray addObject:commandDict];
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:SPActivitiesUpdateNotification object:self];

	if([runningActivitiesArray count] || [[SPAppDelegate runningActivities] count])
		[self performSelector:@selector(setActivityPaneHidden:) withObject:@0 afterDelay:1.0];
	else {
		[NSObject cancelPreviousPerformRequestsWithTarget:self
		                                         selector:@selector(setActivityPaneHidden:)
		                                           object:@0];
		[self setActivityPaneHidden:@1];
	}

}

- (void)removeRegisteredActivity:(NSInteger)pid
{

	for(id cmd in runningActivitiesArray) {
		if([[cmd objectForKey:@"pid"] integerValue] == pid) {
			[runningActivitiesArray removeObject:cmd];
			break;
		}
	}

	if([runningActivitiesArray count] || [[SPAppDelegate runningActivities] count])
		[self performSelector:@selector(setActivityPaneHidden:) withObject:@0 afterDelay:1.0];
	else {
		[NSObject cancelPreviousPerformRequestsWithTarget:self
		                                         selector:@selector(setActivityPaneHidden:)
		                                           object:@0];
		[self setActivityPaneHidden:@1];
	}

	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:SPActivitiesUpdateNotification object:self];
}

- (void)setActivityPaneHidden:(NSNumber *)hide
{
	if (hide.boolValue) {
		[documentActivityScrollView setHidden:YES];
		[tableInfoScrollView setHidden:NO];
	}
	else {
		[tableInfoScrollView setHidden:YES];
		[documentActivityScrollView setHidden:NO];
	}
}

- (NSArray *)runningActivities
{
	return runningActivitiesArray;
}

- (NSDictionary *)shellVariables
{
	if (!_isConnected) return @{};

	NSMutableDictionary *env = [NSMutableDictionary dictionary];

	if (tablesListInstance) {

		if ([tablesListInstance selectedDatabase]) {
			[env setObject:[tablesListInstance selectedDatabase] forKey:SPBundleShellVariableSelectedDatabase];
		}

		if ([tablesListInstance tableName]) {
			[env setObject:[tablesListInstance tableName] forKey:SPBundleShellVariableSelectedTable];
		}

		if ([tablesListInstance selectedTableItems]) {
			[env setObject:[[tablesListInstance selectedTableItems] componentsJoinedByString:@"\t"] forKey:SPBundleShellVariableSelectedTables];
		}

		if ([tablesListInstance allDatabaseNames]) {
			[env setObject:[[tablesListInstance allDatabaseNames] componentsJoinedByString:@"\t"] forKey:SPBundleShellVariableAllDatabases];
		}

		if ([self user]) {
			[env setObject:[self user] forKey:SPBundleShellVariableCurrentUser];
		}

		if ([self host]) {
			[env setObject:[self host] forKey:SPBundleShellVariableCurrentHost];
		}

		if ([self port]) {
			[env setObject:[self port] forKey:SPBundleShellVariableCurrentPort];
		}

		[env setObject:[[tablesListInstance allTableNames] componentsJoinedByString:@"\t"] forKey:SPBundleShellVariableAllTables];
		[env setObject:[[tablesListInstance allViewNames] componentsJoinedByString:@"\t"] forKey:SPBundleShellVariableAllViews];
		[env setObject:[[tablesListInstance allFunctionNames] componentsJoinedByString:@"\t"] forKey:SPBundleShellVariableAllFunctions];
		[env setObject:[[tablesListInstance allProcedureNames] componentsJoinedByString:@"\t"] forKey:SPBundleShellVariableAllProcedures];

		[env setObject:([self databaseEncoding]) ? : @"" forKey:SPBundleShellVariableDatabaseEncoding];
	}

	[env setObject:@"mysql" forKey:SPBundleShellVariableRDBMSType];

	if ([self mySQLVersion]) {
		[env setObject:[self mySQLVersion] forKey:SPBundleShellVariableRDBMSVersion];
	}

	return env;
}
#endif

#pragma mark -
#pragma mark Text field delegate methods

/**
 * When adding a database, enable the button only if the new name has a length.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	id object = [notification object];

	if (object == databaseNameField) {
		[addDatabaseButton setEnabled:([[databaseNameField stringValue] length] > 0 && ![allDatabases containsObject: [databaseNameField stringValue]])]; 
	}
#ifndef SP_CODA
	else if (object == databaseCopyNameField) {
		[copyDatabaseButton setEnabled:([[databaseCopyNameField stringValue] length] > 0 && ![allDatabases containsObject: [databaseCopyNameField stringValue]])]; 
	}
#endif
	else if (object == databaseRenameNameField) {
		[renameDatabaseButton setEnabled:([[databaseRenameNameField stringValue] length] > 0 && ![allDatabases containsObject: [databaseRenameNameField stringValue]])]; 
	}
#ifndef SP_CODA
	else if (object == saveConnectionEncryptString) {
		[saveConnectionEncryptString setStringValue:[saveConnectionEncryptString stringValue]];
	}
#endif
}

#pragma mark -
#pragma mark General sheet delegate methods
#ifndef SP_CODA /* window:willPositionSheet:usingRect: */

- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect {

	// Locate the sheet "Reset Auto Increment" just centered beneath the chosen index row
	// if Structure Pane is active
	if([self currentlySelectedView] == SPTableViewStructure
	    && [[sheet title] isEqualToString:@"Reset Auto Increment"]) {

		id it = [tableSourceInstance valueForKeyPath:@"indexesTableView"];
		NSRect mwrect = [[NSApp mainWindow] frame];
		NSRect ltrect = [[tablesListInstance valueForKeyPath:@"tablesListView"] frame];
		NSRect rowrect = [it rectOfRow:[it selectedRow]];
		rowrect.size.width = mwrect.size.width - ltrect.size.width;
		rowrect.origin.y -= [it rowHeight]/2.0f+2;
		rowrect.origin.x -= 8;
		return [it convertRect:rowrect toView:nil];

	}

	// Otherwise position the sheet beneath the tab bar if it's visible
#warning Private ivar accessed from outside (#2978)
	rect.origin.y -= [[parentWindowController valueForKey:@"tabBar"] frame].size.height - 1;

	return rect;
}
#endif

#pragma mark -
#pragma mark SplitView delegate methods
#ifndef SP_CODA /* SplitView delegate methods */

- (void)splitViewDidResizeSubviews:(NSNotification *)notification
{
	[self updateChooseDatabaseToolbarItemWidth];
	[connectionController updateSplitViewSize];
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	if (dividerIndex == 0 && proposedMinimumPosition < 40) {
		return 40;
	}
	return proposedMinimumPosition;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	//the right side of the SP window must be at least 505px wide or the UI will break!
	if(dividerIndex == 0) {
		return proposedMaximumPosition - 505;
	}
	return proposedMaximumPosition;
}

- (void)updateChooseDatabaseToolbarItemWidth
{
	// make sure the toolbar item is actually in the toolbar
	if (!chooseDatabaseToolbarItem) return;

	// grab the width of the left pane
	CGFloat leftPaneWidth = [[[contentViewSplitter subviews] objectAtIndex:0] frame].size.width;

	// subtract some pixels to allow for misc stuff
	leftPaneWidth -= isOSAtLeast10_14 ? 9 : 12;

	// make sure it's not too small or to big
	if (leftPaneWidth < 130) leftPaneWidth = 130;
	if (leftPaneWidth > 360) leftPaneWidth = 360;

	// apply the size
	[chooseDatabaseToolbarItem setMinSize:NSMakeSize(leftPaneWidth, 26)];
	[chooseDatabaseToolbarItem setMaxSize:NSMakeSize(leftPaneWidth, 32)];
}

#pragma mark -
#pragma mark Datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return (statusTableView && aTableView == statusTableView) ? [statusValues count] : 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if (statusTableView && aTableView == statusTableView && rowIndex < (NSInteger)[statusValues count]) {
		if ([[aTableColumn identifier] isEqualToString:@"table_name"]) {
			if([[statusValues objectAtIndex:rowIndex] objectForKey:@"table_name"])
				return [[statusValues objectAtIndex:rowIndex] objectForKey:@"table_name"];
			else if([[statusValues objectAtIndex:rowIndex] objectForKey:@"Table"])
				return [[statusValues objectAtIndex:rowIndex] objectForKey:@"Table"];
			return @"";
		}
		else if ([[aTableColumn identifier] isEqualToString:@"msg_status"]) {
			if([[statusValues objectAtIndex:rowIndex] objectForKey:@"Msg_type"])
				return [[[statusValues objectAtIndex:rowIndex] objectForKey:@"Msg_type"] capitalizedString];
			return @"";
		}
		else if ([[aTableColumn identifier] isEqualToString:@"msg_text"]) {
			if([[statusValues objectAtIndex:rowIndex] objectForKey:@"Msg_text"]) {
				[[aTableColumn headerCell] setStringValue:NSLocalizedString(@"Message",@"message column title")];
				return [[statusValues objectAtIndex:rowIndex] objectForKey:@"Msg_text"];
			}
			else if([[statusValues objectAtIndex:rowIndex] objectForKey:@"Checksum"]) {
				[[aTableColumn headerCell] setStringValue:@"Checksum"];
				return [[statusValues objectAtIndex:rowIndex] objectForKey:@"Checksum"];
			}
			return @"";
		}
	}
	return nil;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return NO;
}


#pragma mark -
#pragma mark Status accessory view

- (IBAction)copyChecksumFromSheet:(id)sender
{
	NSMutableString *tmp = [NSMutableString string];
	for(id row in statusValues) {
		if ([row objectForKey:@"Msg_type"]) {
			[tmp appendFormat:@"%@\t%@\t%@\n",
			                  [[row objectForKey:@"Table"] description],
			                  [[row objectForKey:@"Msg_type"] description],
			                  [[row objectForKey:@"Msg_text"] description]];
		} else {
			[tmp appendFormat:@"%@\t%@\n",
			                  [[row objectForKey:@"Table"] description],
			                  [[row objectForKey:@"Checksum"] description]];
		}
	}
	
	if ( [tmp length] )
	{
		NSPasteboard *pb = [NSPasteboard generalPasteboard];
	
		[pb declareTypes:@[NSTabularTextPboardType, NSStringPboardType] owner:nil];
	
		[pb setString:tmp forType:NSStringPboardType];
		[pb setString:tmp forType:NSTabularTextPboardType];
	}
}

- (void)setIsSavedInBundle:(BOOL)savedInBundle
{
	_isSavedInBundle = savedInBundle;
}

#endif

#pragma mark -
#pragma mark Private API

/**
 * Copies the current database (and optionally it's content) on a separate thread.
 *
 * This method *MUST* be called from the UI thread!
 */
- (void)_copyDatabase
{
	NSString *newDatabaseName = [databaseCopyNameField stringValue];

	if ([newDatabaseName isEqualToString:@""]) {
		SPOnewayAlertSheet(NSLocalizedString(@"Error", @"error"), parentWindow, NSLocalizedString(@"Database must have a name.", @"message of panel when no db name is given"));
		return;
	}

	NSDictionary *databaseDetails = @{
		SPNewDatabaseDetails : [self createDatabaseInfo],
		SPNewDatabaseName : newDatabaseName,
		SPNewDatabaseCopyContent : @([copyDatabaseDataButton state] == NSOnState)
	};

	[self startTaskWithDescription:[NSString stringWithFormat:NSLocalizedString(@"Copying database '%@'...", @"Copying database task description"), [self database]]];

	if ([NSThread isMainThread]) {
		[NSThread detachNewThreadWithName:SPCtxt(@"SPDatabaseDocument copy database task", self)
								   target:self
								 selector:@selector(_copyDatabaseWithDetails:)
								   object:databaseDetails];;
	}
	else {
		[self _copyDatabaseWithDetails:databaseDetails];
	}
}

- (void)_copyDatabaseWithDetails:(NSDictionary *)databaseDetails
{
	@autoreleasepool
	{
		SPDatabaseCopy *databaseCopy = [[SPDatabaseCopy alloc] init];

		[databaseCopy setConnection:[self getConnection]];

		NSString *newDatabaseName = [databaseDetails objectForKey:SPNewDatabaseName];

		BOOL success = [databaseCopy copyDatabaseFrom:[databaseDetails objectForKey:SPNewDatabaseDetails]
												   to:newDatabaseName
										  withContent:[[databaseDetails objectForKey:SPNewDatabaseCopyContent] boolValue]];

		[databaseCopy release];

		// Select newly created database
		[[self onMainThread] selectDatabase:newDatabaseName item:nil];

		// Update database list
		[[self onMainThread] setDatabases:self];

		[self endTask];

		if (!success) {
			SPOnewayAlertSheet(
				NSLocalizedString(@"Unable to copy database", @"unable to copy database message"),
				parentWindow,
				[NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to copy the database '%@' to '%@'.", @"unable to copy database message informative message"),
				 [databaseDetails[SPNewDatabaseDetails] databaseName],
				 newDatabaseName]
			);
		}
	}
}

/**
 * This method *MUST* be called from the UI thread!
 */
- (void)_renameDatabase 
{
	NSString *newDatabaseName = [databaseRenameNameField stringValue];
	
	if ([newDatabaseName isEqualToString:@""]) {
		SPOnewayAlertSheet(NSLocalizedString(@"Error", @"error"), parentWindow, NSLocalizedString(@"Database must have a name.", @"message of panel when no db name is given"));
		return;
	}
	
	SPDatabaseRename *dbActionRename = [[SPDatabaseRename alloc] init];
	
	[dbActionRename setTablesList:tablesListInstance];
	[dbActionRename setConnection:[self getConnection]];
	
	if ([dbActionRename renameDatabaseFrom:[self createDatabaseInfo] to:newDatabaseName]) {
		[self setDatabases:self];
		[self selectDatabase:newDatabaseName item:nil];
	}
	else {
		SPOnewayAlertSheet(
			NSLocalizedString(@"Unable to rename database", @"unable to rename database message"),
			parentWindow,
			[NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to rename the database '%@' to '%@'.", @"unable to rename database message informative message"), [self database], newDatabaseName]
		);
	}
	
	[dbActionRename release];
}

/**
 * Adds a new database.
 *
 * This method *MUST* be called from the UI thread!
 */
- (void)_addDatabase
{
	// This check is not necessary anymore as the add database button is now only enabled if the name field
	// has a length greater than zero. We'll leave it in just in case.
	if ([[databaseNameField stringValue] isEqualToString:@""]) {
		SPOnewayAlertSheet(NSLocalizedString(@"Error", @"error"), parentWindow, NSLocalizedString(@"Database must have a name.", @"message of panel when no db name is given"));
		return;
	}

	// As we're amending identifiers, ensure UTF8
	if (![[mySQLConnection encoding] isEqualToString:@"utf8"]) [mySQLConnection setEncoding:@"utf8"];
	
	SPDatabaseAction *dbAction = [[SPDatabaseAction alloc] init];
	[dbAction setConnection:mySQLConnection];
	BOOL res = [dbAction createDatabase:[databaseNameField stringValue]
	                       withEncoding:[addDatabaseCharsetHelper selectedCharset]
	                          collation:[addDatabaseCharsetHelper selectedCollation]];
	[dbAction release];
	
	if (!res) {
		// An error occurred
		SPOnewayAlertSheet(NSLocalizedString(@"Error", @"error"), parentWindow, [NSString stringWithFormat:NSLocalizedString(@"Couldn't create database.\nMySQL said: %@", @"message of panel when creation of db failed"), [mySQLConnection lastErrorMessage]]);
		return;
	}

	[self setDatabases:self];
#ifdef SP_CODA /* glue */
	if ( delegate && [delegate respondsToSelector:@selector(refreshDatabasePopup)] )
		[delegate performSelector:@selector(refreshDatabasePopup) withObject:nil];
#endif

	// Select the database
	[self selectDatabase:[databaseNameField stringValue] item:nil];
}

/**
 * Run ALTER statement against current db. This is the callback to alterDatabase:
 * @warning Make sure this method is only called on mysql 4.1+ servers!
 */
- (void)_alterDatabase
{
	//we'll always run the alter statement, even if old == new because after all that is what the user requested
	
	NSString *newCharset   = [alterDatabaseCharsetHelper selectedCharset];
	NSString *newCollation = [alterDatabaseCharsetHelper selectedCollation];
	
	NSString *alterStatement = [NSString stringWithFormat:@"ALTER DATABASE %@ DEFAULT CHARACTER SET %@", [[self database] backtickQuotedString],[newCharset backtickQuotedString]];

	//technically there is an issue here: If a user had a non-default collation and now wants to switch to the default collation this cannot be specidifed (default == nil).
	//However if you just do an ALTER with CHARACTER SET == oldCharset MySQL will still reset the collation therefore doing exactly what we want.
	if(newCollation) {
		alterStatement = [NSString stringWithFormat:@"%@ DEFAULT COLLATE %@",alterStatement,[newCollation backtickQuotedString]];
	}
	
	//run alter
	[mySQLConnection queryString:alterStatement];
	
	if ([mySQLConnection queryErrored]) {
		// An error occurred
		SPOnewayAlertSheet(NSLocalizedString(@"Error", @"error"), parentWindow, [NSString stringWithFormat:NSLocalizedString(@"Couldn't alter database.\nMySQL said: %@", @"Alter Database : Query Failed ($1 = mysql error message)"), [mySQLConnection lastErrorMessage]]);
		return;
	}
	
	//invalidate old cache values
	[databaseDataInstance resetAllData];
}

/**
 * Removes the current database.
 *
 * This method *MUST* be called from the UI thread!
 */
- (void)_removeDatabase
{
	// Drop the database from the server
	[mySQLConnection queryString:[NSString stringWithFormat:@"DROP DATABASE %@", [[self database] backtickQuotedString]]];
	
	if ([mySQLConnection queryErrored]) {
		// An error occurred
		[self performSelector:@selector(showErrorSheetWith:)
		           withObject:[NSArray arrayWithObjects:NSLocalizedString(@"Error", @"error"),
		                                                [NSString stringWithFormat:NSLocalizedString(@"Couldn't delete the database.\nMySQL said: %@", @"message of panel when deleting db failed"), [mySQLConnection lastErrorMessage]],
		                                                nil]
		           afterDelay:0.3];
		
		return;
	}

	// Remove db from navigator and completion list array,
	// do to threading we have to delete it from 'allDatabases' directly
	// before calling navigator
	[allDatabases removeObject:[self database]];

	// This only deletes the db and refreshes the navigator since nothing is changed
	// that's why we can run this on main thread
	[databaseStructureRetrieval queryDbStructureWithUserInfo:nil];

	if (selectedDatabase) SPClear(selectedDatabase);
	
	[self setDatabases:self];
	
	[tablesListInstance setConnection:mySQLConnection];
	
#ifndef SP_CODA
	[self updateWindowTitle:self];
#endif
#ifdef SP_CODA /* glue */
	if ( delegate && [delegate respondsToSelector:@selector(refreshDatabasePopup)] )
		[delegate performSelector:@selector(refreshDatabasePopup) withObject:nil];
		
	if ( delegate && [delegate respondsToSelector:@selector(selectDatabaseInPopup:)] )
	{
		if ( [allDatabases count] > 0 )
		{
			NSString* db = [allDatabases objectAtIndex:0];
			[delegate performSelector:@selector(selectDatabaseInPopup:) withObject:db];
		}
	}
#endif
}

/**
 * Select the specified database and, optionally, table.
 */
- (void)_selectDatabaseAndItem:(NSDictionary *)selectionDetails
{
	@autoreleasepool {
		NSString *targetDatabaseName = [selectionDetails objectForKey:@"database"];
#ifndef SP_CODA /* update history controller */
		NSString *targetItemName = [selectionDetails objectForKey:@"item"];

		// Save existing scroll position and details, and ensure no duplicate entries are created as table list changes
		BOOL historyStateChanging = [spHistoryControllerInstance modifyingState];

		if (!historyStateChanging) {
			[spHistoryControllerInstance updateHistoryEntries];
			[spHistoryControllerInstance setModifyingState:YES];
		}
#endif

		if (![targetDatabaseName isEqualToString:selectedDatabase]) {
			// Attempt to select the specified database, and abort on failure
#ifndef SP_CODA /* patch */
			if ([[chooseDatabaseButton onMainThread] indexOfItemWithTitle:targetDatabaseName] == NSNotFound || ![mySQLConnection selectDatabase:targetDatabaseName])
#else
			if ( ![mySQLConnection selectDatabase:targetDatabaseName] )
#endif
			{
				// End the task first to ensure the database dropdown can be reselected
				[self endTask];

				if ([mySQLConnection isConnected]) {

					// Update the database list
					[[self onMainThread] setDatabases:self];

					SPOnewayAlertSheet(
						NSLocalizedString(@"Error", @"error"),
						parentWindow,
						[NSString stringWithFormat:NSLocalizedString(@"Unable to select database %@.\nPlease check you have the necessary privileges to view the database, and that the database still exists.", @"message of panel when connection to db failed after selecting from popupbutton"), targetDatabaseName]
					);
				}

				return;
			}

#ifndef SP_CODA /* chooseDatabaseButton selectItemWithTitle: */
			[[chooseDatabaseButton onMainThread] selectItemWithTitle:targetDatabaseName];
#endif
			if (selectedDatabase) SPClear(selectedDatabase);
			selectedDatabase = [[NSString alloc] initWithString:targetDatabaseName];

			[databaseDataInstance resetAllData];

#ifndef SP_CODA /* update database encoding */

			// Update the stored database encoding, used for views, "default" table encodings, and to allow
			// or disallow use of the "View using encoding" menu
			[self detectDatabaseEncoding];
#endif

			// Set the connection of SPTablesList to reload tables in db
			[tablesListInstance setConnection:mySQLConnection];

#ifndef SP_CODA /* update history controller and ui manip */
			// Update the window title
			[self updateWindowTitle:self];

			// Add a history entry
			if (!historyStateChanging) {
				[spHistoryControllerInstance setModifyingState:NO];
				[spHistoryControllerInstance updateHistoryEntries];
			}
#endif
		}

#ifndef SP_CODA /* update selected table in SPTablesList */

		SPMainQSync(^{
			BOOL focusOnFilter = YES;
			if (targetItemName) focusOnFilter = NO;

			// If a the table has changed, update the selection
			if (![targetItemName isEqualToString:[self table]] && targetItemName) {
				focusOnFilter = ![tablesListInstance selectItemWithName:targetItemName];
			}

			// Ensure the window focus is on the table list or the filter as appropriate
			[tablesListInstance setTableListSelectability:YES];
			if (focusOnFilter) {
				[tablesListInstance makeTableListFilterHaveFocus];
			} else {
				[tablesListInstance makeTableListHaveFocus];
			}
			[tablesListInstance setTableListSelectability:NO];
		});

#endif
		[self endTask];
#ifndef SP_CODA /* triggered commands */
		[self _processDatabaseChangedBundleTriggerActions];
#endif

#ifdef SP_CODA /* glue */
		if (delegate && [delegate respondsToSelector:@selector(databaseDidChange:)]) {
			[delegate performSelectorOnMainThread:@selector(databaseDidChange:) withObject:self waitUntilDone:NO];
		}
#endif
	}
}

#ifndef SP_CODA
- (void)_processDatabaseChangedBundleTriggerActions
{
	NSArray *triggeredCommands = [SPAppDelegate bundleCommandsForTrigger:SPBundleTriggerActionDatabaseChanged];
	
	for (NSString* cmdPath in triggeredCommands) 
	{
		NSArray *data = [cmdPath componentsSeparatedByString:@"|"];
		NSMenuItem *aMenuItem = [[[NSMenuItem alloc] init] autorelease];
		
		[aMenuItem setTag:0];
		[aMenuItem setToolTip:[data objectAtIndex:0]];

		// For HTML output check if corresponding window already exists
		BOOL stopTrigger = NO;
		
		if ([(NSString *)[data objectAtIndex:2] length]) {
			BOOL correspondingWindowFound = NO;
			NSString *uuid = [data objectAtIndex:2];
			
			for (id win in [NSApp windows]) 
			{
				if([[[[win delegate] class] description] isEqualToString:@"SPBundleHTMLOutputController"]) {
					if([[[win delegate] windowUUID] isEqualToString:uuid]) {
						correspondingWindowFound = YES;
						break;
					}
				}
			}
			
			if(!correspondingWindowFound) stopTrigger = YES;
		}
		if(!stopTrigger) {
			id firstResponder = [[NSApp keyWindow] firstResponder];
			if([[data objectAtIndex:1] isEqualToString:SPBundleScopeGeneral]) {
				[[SPAppDelegate onMainThread] executeBundleItemForApp:aMenuItem];
			}
			else if([[data objectAtIndex:1] isEqualToString:SPBundleScopeDataTable]) {
				if ([[[firstResponder class] description] isEqualToString:@"SPCopyTable"]) {
					[[firstResponder onMainThread] executeBundleItemForDataTable:aMenuItem];
				}
			}
			else if([[data objectAtIndex:1] isEqualToString:SPBundleScopeInputField]) {
				if ([firstResponder isKindOfClass:[NSTextView class]]) {
					[[firstResponder onMainThread] executeBundleItemForInputField:aMenuItem];
				}
			}
		}
	}
}
#endif

/**
 * Add any necessary preference observers to allow live updating on changes.
 */
- (void)_addPreferenceObservers
{
	// Register observers for when the DisplayTableViewVerticalGridlines preference changes
	[prefs addObserver:self forKeyPath:SPDisplayTableViewVerticalGridlines options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:tableSourceInstance forKeyPath:SPDisplayTableViewVerticalGridlines options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:customQueryInstance forKeyPath:SPDisplayTableViewVerticalGridlines options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:tableRelationsInstance forKeyPath:SPDisplayTableViewVerticalGridlines options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:[SPQueryController sharedQueryController] forKeyPath:SPDisplayTableViewVerticalGridlines options:NSKeyValueObservingOptionNew context:NULL];

	// Register observers for the when the UseMonospacedFonts preference changes
	[prefs addObserver:tableSourceInstance forKeyPath:SPUseMonospacedFonts options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:[SPQueryController sharedQueryController] forKeyPath:SPUseMonospacedFonts options:NSKeyValueObservingOptionNew context:NULL];

	// Register observers for when the logging preference changes
	[prefs addObserver:[SPQueryController sharedQueryController] forKeyPath:SPConsoleEnableLogging options:NSKeyValueObservingOptionNew context:NULL];

	// Register a second observer for when the logging preference changes so we can tell the current connection about it
	[prefs addObserver:self forKeyPath:SPConsoleEnableLogging options:NSKeyValueObservingOptionNew context:NULL];
}

/**
 * Remove any previously added preference observers.
 */
- (void)_removePreferenceObservers
{
	[prefs removeObserver:self forKeyPath:SPConsoleEnableLogging];
	[prefs removeObserver:self forKeyPath:SPDisplayTableViewVerticalGridlines];

	[prefs removeObserver:tableSourceInstance forKeyPath:SPUseMonospacedFonts];

	[prefs removeObserver:customQueryInstance forKeyPath:SPDisplayTableViewVerticalGridlines];
	[prefs removeObserver:tableRelationsInstance forKeyPath:SPDisplayTableViewVerticalGridlines];
	[prefs removeObserver:tableSourceInstance forKeyPath:SPDisplayTableViewVerticalGridlines];

	[prefs removeObserver:[SPQueryController sharedQueryController] forKeyPath:SPUseMonospacedFonts];
	[prefs removeObserver:[SPQueryController sharedQueryController] forKeyPath:SPConsoleEnableLogging];
	[prefs removeObserver:[SPQueryController sharedQueryController] forKeyPath:SPDisplayTableViewVerticalGridlines];
}

#pragma mark - SPDatabaseViewController

#pragma mark Getters

#ifndef SP_CODA /* getters */
/**
 * Returns the master database view, containing the tables list and views for
 * table setup and contents.
 */
- (NSView *)databaseView
{
	return parentView;
}
#endif

/**
 * Returns the name of the currently selected table/view/procedure/function.
 */
- (NSString *)table
{
	return selectedTableName;
}

/**
 * Returns the currently selected table type, or -1 if no table or multiple tables are selected
 */
- (SPTableType)tableType
{
	return selectedTableType;
}

/**
 * Returns YES if table source has already been loaded
 */
- (BOOL)structureLoaded
{
	return structureLoaded;
}

/**
 * Returns YES if table content has already been loaded
 */
- (BOOL)contentLoaded
{
	return contentLoaded;
}

/**
 * Returns YES if table status has already been loaded
 */
- (BOOL)statusLoaded
{
	return statusLoaded;
}

#ifndef SP_CODA /* toolbar ibactions */

#pragma mark -
#pragma mark Tab view control and delegate methods

//WARNING: Might be called from code in background threads
- (IBAction)viewStructure:(id)sender
{
	// Cancel the selection if currently editing a view and unable to save
	if (![[self onMainThread] couldCommitCurrentViewActions]) {
		[[mainToolbar onMainThread] setSelectedItemIdentifier:*SPViewModeToMainToolbarMap[[prefs integerForKey:SPLastViewMode]]];
		return;
	}

	[[tableTabView onMainThread] selectTabViewItemAtIndex:0];
	[[mainToolbar onMainThread] setSelectedItemIdentifier:SPMainToolbarTableStructure];
	[spHistoryControllerInstance updateHistoryEntries];

	[prefs setInteger:SPStructureViewMode forKey:SPLastViewMode];
}

- (IBAction)viewContent:(id)sender
{
	// Cancel the selection if currently editing a view and unable to save
	if (![self couldCommitCurrentViewActions]) {
		[mainToolbar setSelectedItemIdentifier:*SPViewModeToMainToolbarMap[[prefs integerForKey:SPLastViewMode]]];
		return;
	}

	[tableTabView selectTabViewItemAtIndex:1];
	[mainToolbar setSelectedItemIdentifier:SPMainToolbarTableContent];
	[spHistoryControllerInstance updateHistoryEntries];

	[prefs setInteger:SPContentViewMode forKey:SPLastViewMode];
}

- (IBAction)viewQuery:(id)sender
{
	// Cancel the selection if currently editing a view and unable to save
	if (![self couldCommitCurrentViewActions]) {
		[mainToolbar setSelectedItemIdentifier:*SPViewModeToMainToolbarMap[[prefs integerForKey:SPLastViewMode]]];
		return;
	}

	[tableTabView selectTabViewItemAtIndex:2];
	[mainToolbar setSelectedItemIdentifier:SPMainToolbarCustomQuery];
	[spHistoryControllerInstance updateHistoryEntries];

	// Set the focus on the text field
	[parentWindow makeFirstResponder:customQueryTextView];

	[prefs setInteger:SPQueryEditorViewMode forKey:SPLastViewMode];
}

- (IBAction)viewStatus:(id)sender
{
	// Cancel the selection if currently editing a view and unable to save
	if (![self couldCommitCurrentViewActions]) {
		[mainToolbar setSelectedItemIdentifier:*SPViewModeToMainToolbarMap[[prefs integerForKey:SPLastViewMode]]];
		return;
	}

	[tableTabView selectTabViewItemAtIndex:3];
	[mainToolbar setSelectedItemIdentifier:SPMainToolbarTableInfo];
	[spHistoryControllerInstance updateHistoryEntries];

	if ([[self table] length]) {
		[extendedTableInfoInstance loadTable:[self table]];
	}

	[parentWindow makeFirstResponder:[extendedTableInfoInstance valueForKeyPath:@"tableCreateSyntaxTextView"]];

	[prefs setInteger:SPTableInfoViewMode forKey:SPLastViewMode];
}

- (IBAction)viewRelations:(id)sender
{
	// Cancel the selection if currently editing a view and unable to save
	if (![self couldCommitCurrentViewActions]) {
		[mainToolbar setSelectedItemIdentifier:*SPViewModeToMainToolbarMap[[prefs integerForKey:SPLastViewMode]]];
		return;
	}

	[tableTabView selectTabViewItemAtIndex:4];
	[mainToolbar setSelectedItemIdentifier:SPMainToolbarTableRelations];
	[spHistoryControllerInstance updateHistoryEntries];

	[prefs setInteger:SPRelationsViewMode forKey:SPLastViewMode];
}

- (IBAction)viewTriggers:(id)sender
{
	// Cancel the selection if currently editing a view and unable to save
	if (![self couldCommitCurrentViewActions]) {
		[mainToolbar setSelectedItemIdentifier:*SPViewModeToMainToolbarMap[[prefs integerForKey:SPLastViewMode]]];
		return;
	}

	[tableTabView selectTabViewItemAtIndex:5];
	[mainToolbar setSelectedItemIdentifier:SPMainToolbarTableTriggers];
	[spHistoryControllerInstance updateHistoryEntries];

	[prefs setInteger:SPTriggersViewMode forKey:SPLastViewMode];
}
#endif

/**
 * Mark the structure tab for refresh when it's next switched to,
 * or reload the view if it's currently active
 */
- (void)setStructureRequiresReload:(BOOL)reload
{
	BOOL reloadRequired = reload;

#ifndef SP_CODA
	if ([self currentlySelectedView] == SPTableViewStructure) {
		reloadRequired = NO;
	}
#endif

	if (reloadRequired && selectedTableName) {
		[tableSourceInstance loadTable:selectedTableName];
	}
	else {
		structureLoaded = !reload;
	}
}

/**
 * Mark the content tab for refresh when it's next switched to,
 * or reload the view if it's currently active
 */
- (void)setContentRequiresReload:(BOOL)reload
{
	if (reload && selectedTableName
#ifndef SP_CODA /* check which tab is selected */
	    && [self currentlySelectedView] == SPTableViewContent
#endif
	) {
		[tableContentInstance loadTable:selectedTableName];
	}
	else {
		contentLoaded = !reload;
	}
}

/**
 * Mark the extended tab info for refresh when it's next switched to,
 * or reload the view if it's currently active
 */
- (void)setStatusRequiresReload:(BOOL)reload
{
	if (reload && selectedTableName
#ifndef SP_CODA /* check which tab is selected */
	    && [self currentlySelectedView] == SPTableViewStatus
#endif
	) {
		[[extendedTableInfoInstance onMainThread] loadTable:selectedTableName];
	}
	else {
		statusLoaded = !reload;
	}
}

/**
 * Mark the relations tab for refresh when it's next switched to,
 * or reload the view if it's currently active
 */
- (void)setRelationsRequiresReload:(BOOL)reload
{
	if (reload && selectedTableName
#ifndef SP_CODA /* check which tab is selected */
	    && [self currentlySelectedView] == SPTableViewRelations
#endif
	) {
		[[tableRelationsInstance onMainThread] refreshRelations:self];
	}
	else {
		relationsLoaded = !reload;
	}
}

#ifndef SP_CODA /* !!! respond to tab change */
/**
 * Triggers a task to update the newly selected tab view, ensuring
 * the data is fully loaded and up-to-date.
 */
- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	[self startTaskWithDescription:[NSString stringWithFormat:NSLocalizedString(@"Loading %@...", @"Loading table task string"), [self table]]];

	// We can't pass aTabView or tabViewItem UI objects to a bg thread, but since the change should already
	// be done in *did*SelectTabViewItem we can just ask the tab view for the current selection index and use that
	SPTableViewType newView = [self currentlySelectedView];

	if ([NSThread isMainThread]) {
		[NSThread detachNewThreadWithName:SPCtxt(@"SPDatabaseDocument view load task", self)
		                           target:self
		                         selector:@selector(_loadTabTask:)
		                           object:@(newView)];
	}
	else {
		[self _loadTabTask:@(newView)];
	}
}
#endif

#pragma mark -
#pragma mark Table control

/**
 * Loads a specified table into the database view, and ensures it's selected in
 * the tables list.  Passing a table name of nil will deselect any currently selected
 * table, but will leave multiple selections intact.
 * If this method is supplied with the currently selected name, a reload rather than
 * a load will be triggered.
 */
- (void)loadTable:(NSString *)aTable ofType:(SPTableType)aTableType
{
	// Ensure a connection is still present
	if (![mySQLConnection isConnected]) return;

	// If the supplied table name was nil, clear the views.
	if (!aTable) {

		// Update the selected table name and type
		if (selectedTableName) SPClear(selectedTableName);

		selectedTableType = SPTableTypeNone;

		// Clear the views
		[[tablesListInstance onMainThread] setSelectionState:nil];
		[tableSourceInstance loadTable:nil];
		[tableContentInstance loadTable:nil];
#ifndef SP_CODA /* [extendedTableInfoInstance loadTable:] */
		[[extendedTableInfoInstance onMainThread] loadTable:nil];
		[[tableTriggersInstance onMainThread] resetInterface];
		[[tableRelationsInstance onMainThread] refreshRelations:self];
#endif
		structureLoaded = NO;
		contentLoaded = NO;
		statusLoaded = NO;
		triggersLoaded = NO;
		relationsLoaded = NO;

#ifndef SP_CODA
		// Update the window title
		[self updateWindowTitle:self];

		// Add a history entry
		[spHistoryControllerInstance updateHistoryEntries];
#endif

		// Notify listeners of the table change
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:SPTableChangedNotification object:self];

		return;
	}

	BOOL isReloading = (selectedTableName && [selectedTableName isEqualToString:aTable]);

	// Store the new name
	if (selectedTableName) [selectedTableName release];

	selectedTableName = [[NSString alloc] initWithString:aTable];
	selectedTableType = aTableType;

	// Start a task
	if (isReloading) {
		[self startTaskWithDescription:NSLocalizedString(@"Reloading...", @"Reloading table task string")];
	}
	else {
		[self startTaskWithDescription:[NSString stringWithFormat:NSLocalizedString(@"Loading %@...", @"Loading table task string"), aTable]];
	}

	// Update the tables list interface - also updates menus to reflect the selected table type
	[[tablesListInstance onMainThread] setSelectionState:[NSDictionary dictionaryWithObjectsAndKeys:aTable, @"name", [NSNumber numberWithInteger:aTableType], @"type", nil]];

	// If on the main thread, fire up a thread to deal with view changes and data loading;
	// if already on a background thread, make the changes on the existing thread.
	if ([NSThread isMainThread]) {
		[NSThread detachNewThreadWithName:SPCtxt(@"SPDatabaseDocument table load task", self)
		                           target:self
		                         selector:@selector(_loadTableTask)
		                           object:nil];
	}
	else {
		[self _loadTableTask];
	}
}

/**
 * In a threaded task, ensure that the supplied tab is loaded -
 * usually as a result of switching to it.
 */
- (void)_loadTabTask:(NSNumber *)tabViewItemIndexNumber
{
	@autoreleasepool {
		// If anything other than a single table or view is selected, don't proceed.
		if (![self table] || ([tablesListInstance tableType] != SPTableTypeTable && [tablesListInstance tableType] != SPTableTypeView)) {
			[self endTask];
			return;
		}

		// Get the tab view index and ensure the associated view is loaded
		SPTableViewType selectedTabViewIndex = (SPTableViewType)[tabViewItemIndexNumber integerValue];

		switch (selectedTabViewIndex) {
			case SPTableViewStructure:
				if (!structureLoaded) {
					[tableSourceInstance loadTable:selectedTableName];
					structureLoaded = YES;
				}
				break;
			case SPTableViewContent:
				if (!contentLoaded) {
					[tableContentInstance loadTable:selectedTableName];
					contentLoaded = YES;
				}
				break;
			case SPTableViewStatus:
				if (!statusLoaded) {
					[[extendedTableInfoInstance onMainThread] loadTable:selectedTableName];
					statusLoaded = YES;
				}
				break;
			case SPTableViewTriggers:
				if (!triggersLoaded) {
					[[tableTriggersInstance onMainThread] loadTriggers];
					triggersLoaded = YES;
				}
				break;
			case SPTableViewRelations:
				if (!relationsLoaded) {
					[[tableRelationsInstance onMainThread] refreshRelations:self];
					relationsLoaded = YES;
				}
				break;
			case SPTableViewCustomQuery:
			case SPTableViewInvalid:
				break;
		}

		[self endTask];
	}
}


/**
 * In a threaded task, load the currently selected table/view/proc/function.
 */
- (void)_loadTableTask
{
	@autoreleasepool {
		NSString *tableEncoding = nil;

#ifndef SP_CODA /* Update the window title */
		// Update the window title
		[self updateWindowTitle:self];
#endif

		// Reset table information caches and mark that all loaded views require their data reloading
		[tableDataInstance resetAllData];

		structureLoaded = NO;
		contentLoaded = NO;
		statusLoaded = NO;
		triggersLoaded = NO;
		relationsLoaded = NO;

		// Ensure status and details are fetched using UTF8
		NSString *previousEncoding = [mySQLConnection encoding];
		BOOL changeEncoding = ![previousEncoding isEqualToString:@"utf8"];

		if (changeEncoding) {
			[mySQLConnection storeEncodingForRestoration];
			[mySQLConnection setEncoding:@"utf8"];
		}

		// Cache status information on the working thread
		[tableDataInstance updateStatusInformationForCurrentTable];

		// Check the current encoding against the table encoding to see whether
		// an encoding change and reset is required.  This also caches table information on
		// the working thread.
		if( selectedTableType == SPTableTypeView || selectedTableType == SPTableTypeTable) {

			// tableEncoding == nil indicates that there was an error while retrieving table data
			tableEncoding = [tableDataInstance tableEncoding];

			// If encoding is set to Autodetect, update the connection character set encoding
			// based on the newly selected table's encoding - but only if it differs from the current encoding.
			if ([[[NSUserDefaults standardUserDefaults] objectForKey:SPDefaultEncoding] intValue] == SPEncodingAutodetect) {
				if (tableEncoding != nil && ![tableEncoding isEqualToString:previousEncoding]) {
					[self setConnectionEncoding:tableEncoding reloadingViews:NO];
					changeEncoding = NO;
				}
			}
		}

		if (changeEncoding) [mySQLConnection restoreStoredEncoding];

		// Notify listeners of the table change now that the state is fully set up.
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:SPTableChangedNotification object:self];

#ifndef SP_CODA /* [spHistoryControllerInstance restoreViewStates] */
		// Restore view states as appropriate
		[spHistoryControllerInstance restoreViewStates];
#endif

		// Load the currently selected view if looking at a table or view
		if (tableEncoding && (selectedTableType == SPTableTypeView || selectedTableType == SPTableTypeTable))
		{
#ifndef SP_CODA /* load everything */
			NSInteger selectedTabViewIndex = [[self onMainThread] currentlySelectedView];

			switch (selectedTabViewIndex) {
				case SPTableViewStructure:
#endif
					[tableSourceInstance loadTable:selectedTableName];
					structureLoaded = YES;
#ifndef SP_CODA /* load everything */
					break;
				case SPTableViewContent:
#endif
					[tableContentInstance loadTable:selectedTableName];
					contentLoaded = YES;
#ifndef SP_CODA /* load everything */
					break;
				case SPTableViewStatus:
					[[extendedTableInfoInstance onMainThread] loadTable:selectedTableName];
					statusLoaded = YES;
					break;
				case SPTableViewTriggers:
					[[tableTriggersInstance onMainThread] loadTriggers];
					triggersLoaded = YES;
					break;
				case SPTableViewRelations:
					[[tableRelationsInstance onMainThread] refreshRelations:self];
					relationsLoaded = YES;
					break;
			}
#endif
		}

		// Clear any views which haven't been loaded as they weren't visible.  Note
		// that this should be done after reloading visible views, instead of clearing all
		// views, to reduce UI operations and avoid resetting state unnecessarily.
		// Some views (eg TableRelations) make use of the SPTableChangedNotification and
		// so don't require manual clearing.
		if (!structureLoaded) [tableSourceInstance loadTable:nil];
		if (!contentLoaded) [tableContentInstance loadTable:nil];
		if (!statusLoaded) [[extendedTableInfoInstance onMainThread] loadTable:nil];
		if (!triggersLoaded) [[tableTriggersInstance onMainThread] resetInterface];

		// If the table row counts an inaccurate and require updating, trigger an update - no
		// action will be performed if not necessary
		[tableDataInstance updateAccurateNumberOfRowsForCurrentTableForcingUpdate:NO];

#ifndef SP_CODA /* show Create Table syntax */
		SPMainQSync(^{
			// Update the "Show Create Syntax" window if it's already opened
			// according to the selected table/view/proc/func
			if ([[self getCreateTableSyntaxWindow] isVisible]) {
				[self showCreateTableSyntax:self];
			}
		});

		// Add a history entry
		[spHistoryControllerInstance updateHistoryEntries];
#endif
		// Empty the loading pool and exit the thread
		[self endTask];

#ifndef SP_CODA /* triggered commands */
		NSArray *triggeredCommands = [SPAppDelegate bundleCommandsForTrigger:SPBundleTriggerActionTableChanged];

		for(NSString* cmdPath in triggeredCommands)
		{
			NSArray *data = [cmdPath componentsSeparatedByString:@"|"];
			NSMenuItem *aMenuItem = [[[NSMenuItem alloc] init] autorelease];
			[aMenuItem setTag:0];
			[aMenuItem setToolTip:[data objectAtIndex:0]];

			// For HTML output check if corresponding window already exists
			BOOL stopTrigger = NO;
			if([(NSString*)[data objectAtIndex:2] length]) {
				BOOL correspondingWindowFound = NO;
				NSString *uuid = [data objectAtIndex:2];
				for(id win in [NSApp windows]) {
					if([[[[win delegate] class] description] isEqualToString:@"SPBundleHTMLOutputController"]) {
						if([[[win delegate] windowUUID] isEqualToString:uuid]) {
							correspondingWindowFound = YES;
							break;
						}
					}
				}
				if(!correspondingWindowFound) stopTrigger = YES;
			}
			if(!stopTrigger) {
				id firstResponder = [[NSApp keyWindow] firstResponder];
				if([[data objectAtIndex:1] isEqualToString:SPBundleScopeGeneral]) {
					[[SPAppDelegate onMainThread] executeBundleItemForApp:aMenuItem];
				}
				else if([[data objectAtIndex:1] isEqualToString:SPBundleScopeDataTable]) {
					if([[[firstResponder class] description] isEqualToString:@"SPCopyTable"])
						[[firstResponder onMainThread] executeBundleItemForDataTable:aMenuItem];
				}
				else if([[data objectAtIndex:1] isEqualToString:SPBundleScopeInputField]) {
					if([firstResponder isKindOfClass:[NSTextView class]])
						[[firstResponder onMainThread] executeBundleItemForInputField:aMenuItem];
				}
			}
		}
#endif
	}
}

#pragma mark - SPMySQLConnection delegate methods

/**
 * Invoked when the framework is about to perform a query.
 */
- (void)willQueryString:(NSString *)query connection:(id)connection
{
#ifndef SP_CODA
	if ([prefs boolForKey:SPConsoleEnableLogging]) {
		if ((_queryMode == SPInterfaceQueryMode && [prefs boolForKey:SPConsoleEnableInterfaceLogging]) ||
			(_queryMode == SPCustomQueryQueryMode && [prefs boolForKey:SPConsoleEnableCustomQueryLogging]) ||
			(_queryMode == SPImportExportQueryMode && [prefs boolForKey:SPConsoleEnableImportExportLogging]))
		{
			[[SPQueryController sharedQueryController] showMessageInConsole:query connection:[self name] database:[self database]];
		}
	}
#endif
}

/**
 * Invoked when the query just executed by the framework resulted in an error.
 */
- (void)queryGaveError:(NSString *)error connection:(id)connection
{
#ifndef SP_CODA
	if ([prefs boolForKey:SPConsoleEnableLogging] && [prefs boolForKey:SPConsoleEnableErrorLogging]) {
		[[SPQueryController sharedQueryController] showErrorInConsole:error connection:[self name] database:[self database]];
	}
#endif
}

/**
 * Invoked when the current connection needs a password from the Keychain.
 */
- (NSString *)keychainPasswordForConnection:(SPMySQLConnection *)connection
{
	return [connectionController keychainPassword];
}

/**
 * Invoked when the current connection needs a ssh password from the Keychain.
 * This isn't actually part of the SPMySQLConnection delegate protocol, but is here
 * due to its similarity to the previous method.
 */
- (NSString *)keychainPasswordForSSHConnection:(SPMySQLConnection *)connection
{
	// If no keychain item is available, return an empty password
	NSString *password = [connectionController keychainPasswordForSSH];
	if (!password) return @"";

	return password;
}

/**
 * Invoked when an attempt was made to execute a query on the current connection, but the connection is not
 * actually active.
 */
- (void)noConnectionAvailable:(id)connection
{
	SPOnewayAlertSheet(
		NSLocalizedString(@"No connection available", @"no connection available message"),
		[self parentWindow],
		NSLocalizedString(@"An error has occured and there doesn't seem to be a connection available.", @"no connection available informatie message")
	);
}

/**
 * Invoked when the connection fails and the framework needs to know how to proceed.
 */
- (SPMySQLConnectionLostDecision)connectionLost:(id)connection
{
	SPMySQLConnectionLostDecision connectionErrorCode = SPMySQLConnectionLostDisconnect;

	// Only display the reconnect dialog if the window is visible
	if ([self parentWindow] && [[self parentWindow] isVisible]) {

		// Ensure the window isn't miniaturized
		if ([[self parentWindow] isMiniaturized]) [[self parentWindow] deminiaturize:self];

#ifndef SP_CODA
		// Ensure the window and tab are frontmost
		[self makeKeyDocument];
#endif

		// Display the connection error dialog and wait for the return code
		[NSApp beginSheet:connectionErrorDialog modalForWindow:[self parentWindow] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
		connectionErrorCode = (SPMySQLConnectionLostDecision)[NSApp runModalForWindow:connectionErrorDialog];

		[NSApp endSheet:connectionErrorDialog];
		[connectionErrorDialog orderOut:nil];

		// If 'disconnect' was selected, trigger a window close.
		if (connectionErrorCode == SPMySQLConnectionLostDisconnect) {
			[self performSelectorOnMainThread:@selector(closeAndDisconnect) withObject:nil waitUntilDone:YES];
		}
	}

	return connectionErrorCode;
}

/**
 * Invoke to display an informative but non-fatal error directly to the user.
 */
- (void)showErrorWithTitle:(NSString *)theTitle message:(NSString *)theMessage
{
	if ([[self parentWindow] isVisible]) {
		SPOnewayAlertSheet(theTitle, [self parentWindow], theMessage);
	}
}

/**
 * Invoked when user dismisses the error sheet displayed as a result of the current connection being lost.
 */
- (IBAction)closeErrorConnectionSheet:(id)sender
{
	[NSApp stopModalWithCode:[sender tag]];
}

/**
 * Close the connection - should be performed on the main thread.
 */
- (void) closeAndDisconnect
{
#ifndef SP_CODA
	NSWindow *theParentWindow = [self parentWindow];

	_isConnected = NO;

	if ([[[self parentTabViewItem] tabView] numberOfTabViewItems] == 1) {
		[theParentWindow orderOut:self];
		[theParentWindow setAlphaValue:0.0f];
		[theParentWindow performSelector:@selector(close) withObject:nil afterDelay:1.0];
	}
	else {
		[[[self parentTabViewItem] tabView] performSelector:@selector(removeTabViewItem:) withObject:[self parentTabViewItem] afterDelay:0.5];
		[theParentWindow performSelector:@selector(makeKeyAndOrderFront:) withObject:nil afterDelay:0.6];
	}

	[self parentTabDidClose];
#endif
}

#pragma mark - SPPrintController

/**
 * WebView delegate method.
 */
- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	// Because we need the webFrame loaded (for preview), we've moved the actual printing here
	NSPrintInfo *printInfo = [NSPrintInfo sharedPrintInfo];

	NSSize paperSize = [printInfo paperSize];
	NSRect printableRect = [printInfo imageablePageBounds];

	// Calculate page margins
	CGFloat marginL = printableRect.origin.x;
	CGFloat marginR = paperSize.width - (printableRect.origin.x + printableRect.size.width);
	CGFloat marginB = printableRect.origin.y;
	CGFloat marginT = paperSize.height - (printableRect.origin.y + printableRect.size.height);

	// Make sure margins are symetric and positive
	CGFloat marginLR = MAX(0, MAX(marginL, marginR));
	CGFloat marginTB = MAX(0, MAX(marginT, marginB));

	// Set the margins
	[printInfo setLeftMargin:marginLR];
	[printInfo setRightMargin:marginLR];
	[printInfo setTopMargin:marginTB];
	[printInfo setBottomMargin:marginTB];

	[printInfo setHorizontalPagination:NSFitPagination];
	[printInfo setVerticalPagination:NSAutoPagination];
	[printInfo setVerticallyCentered:NO];

	NSPrintOperation *op = [NSPrintOperation printOperationWithView:[[[printWebView mainFrame] frameView] documentView] printInfo:printInfo];

	// do not try to use webkit from a background thread!
	[op setCanSpawnSeparateThread:NO];

	// Add the ability to select the orientation to print panel
	NSPrintPanel *printPanel = [op printPanel];

	[printPanel setOptions:[printPanel options] + NSPrintPanelShowsOrientation + NSPrintPanelShowsScaling + NSPrintPanelShowsPaperSize];

	SPPrintAccessory *printAccessory = [[SPPrintAccessory alloc] initWithNibName:@"PrintAccessory" bundle:nil];

	[printAccessory setPrintView:printWebView];
	[printPanel addAccessoryController:printAccessory];

	[[NSPageLayout pageLayout] addAccessoryController:printAccessory];
	[printAccessory release];

	[op setPrintPanel:printPanel];

	/* -endTask has to be called first, since the toolbar caches the item enabled state before starting a sheet,
	 * disables all items and restores the cached state after the sheet ends. Because the database chooser is disabled
	 * during tasks, launching the sheet before calling -endTask first would result in the following flow:
	 * - toolbar item caches database chooser state as disabled (because of the active task)
	 * - sheet is shown
	 * - endTask reenables database chooser (has no effect because of the open sheet)
	 * - user dismisses sheet after some time
	 * - toolbar item restores cached state and disables database chooser again
	 * => Inconsistent UI: database chooser disabled when it should actually be enabled
	 */
	if ([self isWorking]) [self endTask];

	[op runOperationModalForWindow:[self parentWindow]
	                      delegate:self
	                didRunSelector:nil
	                   contextInfo:nil];
}

/**
 * Loads the print document interface. The actual printing is done in the doneLoading delegate.
 */
- (IBAction)printDocument:(id)sender
{
	// Only display warning for the 'Table Content' view
	if ([self currentlySelectedView] == SPTableViewContent) {

		NSInteger rowLimit = [prefs integerForKey:SPPrintWarningRowLimit];

		// Result count minus one because the first element is the column names
		NSInteger resultRows = ([[tableContentInstance currentResult] count] - 1);

		if (resultRows > rowLimit) {

			NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];

			[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];

			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Continue to print?", @"continue to print message")
											 defaultButton:NSLocalizedString(@"Print", @"print button")
										   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
											   otherButton:nil
								 informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to print the current content view of the table '%@'?\n\nIt currently contains %@ rows, which may take a significant amount of time to print.", @"continue to print informative message"), [self table], [numberFormatter stringFromNumber:[NSNumber numberWithLongLong:resultRows]]];

			NSArray *buttons = [alert buttons];

			// Change the alert's cancel button to have the key equivalent of return
			[[buttons objectAtIndex:0] setKeyEquivalent:@"p"];
			[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
			[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];

			[alert beginSheetModalForWindow:[self parentWindow] modalDelegate:self didEndSelector:@selector(printWarningDidEnd:returnCode:contextInfo:) contextInfo:NULL];

			return;
		}
	}

	[self startPrintDocumentOperation];
}

/**
 * Called when the print warning dialog is dismissed.
 */
- (void)printWarningDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	if (returnCode == NSAlertDefaultReturn) {
		[self startPrintDocumentOperation];
	}
}

/**
 * Starts tge print document operation by spawning a new thread if required.
 */
- (void)startPrintDocumentOperation
{
	[self startTaskWithDescription:NSLocalizedString(@"Generating print document...", @"generating print document status message")];

	BOOL isTableInformation = ([self currentlySelectedView] == SPTableViewStatus);

	if ([NSThread isMainThread]) {
		printThread = [[NSThread alloc] initWithTarget:self selector:(isTableInformation) ? @selector(generateTableInfoHTMLForPrinting) : @selector(generateHTMLForPrinting) object:nil];
		[printThread setName:@"SPDatabaseDocument document generator"];

		[self enableTaskCancellationWithTitle:NSLocalizedString(@"Cancel", @"cancel button") callbackObject:self callbackFunction:@selector(generateHTMLForPrintingCallback)];

		[printThread start];
	}
	else {
		(isTableInformation) ? [self generateTableInfoHTMLForPrinting] : [self generateHTMLForPrinting];
	}
}

/**
 * HTML generation thread callback method.
 */
- (void)generateHTMLForPrintingCallback
{
	[self setTaskDescription:NSLocalizedString(@"Cancelling...", @"cancelling task status message")];

	// Cancel the print thread
	[printThread cancel];
}

/**
 * Loads the supplied HTML string in the print WebView.
 */
- (void)loadPrintWebViewWithHTMLString:(NSString *)HTMLString
{
	[[printWebView mainFrame] loadHTMLString:HTMLString baseURL:nil];

	if (printThread) SPClear(printThread);
}

/**
 * Generates the HTML for the current view that is being printed.
 */
- (void)generateHTMLForPrinting
{
	@autoreleasepool {
		NSMutableDictionary *connection = [NSMutableDictionary dictionary];
		NSMutableDictionary *printData = [NSMutableDictionary dictionary];

		SPMainQSync(^{
			[connection setDictionary:[self connectionInformation]];
			[printData setObject:[self columnNames] forKey:@"columns"];
			SPTableViewType view = [self currentlySelectedView];

			NSString *heading = @"";

			// Table source view
			if (view == SPTableViewStructure) {

				NSDictionary *tableSource = [tableSourceInstance tableSourceForPrinting];

				NSInteger tableType = [tablesListInstance tableType];

				switch (tableType) {
					case SPTableTypeTable:
						heading = NSLocalizedString(@"Table Structure", @"table structure print heading");
						break;
					case SPTableTypeView:
						heading = NSLocalizedString(@"View Structure", @"view structure print heading");
						break;
				}

				NSArray *rows = [[NSArray alloc] initWithArray:
					[[tableSource objectForKey:@"structure"] objectsAtIndexes:
						[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [[tableSource objectForKey:@"structure"] count] - 1)]]
				];

				NSArray *indexes = [[NSArray alloc] initWithArray:
					[[tableSource objectForKey:@"indexes"] objectsAtIndexes:
						[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [[tableSource objectForKey:@"indexes"] count] - 1)]]
				];

				NSArray *indexColumns = [[tableSource objectForKey:@"indexes"] objectAtIndex:0];

				[printData setObject:rows forKey:@"rows"];
				[printData setObject:indexes forKey:@"indexes"];
				[printData setObject:indexColumns forKey:@"indexColumns"];

				if ([indexes count]) [printData setObject:@1 forKey:@"hasIndexes"];

				[rows release];
				[indexes release];
			}
				// Table content view
			else if (view == SPTableViewContent) {

				NSArray *data = [tableContentInstance currentDataResultWithNULLs:NO hideBLOBs:YES];

				heading = NSLocalizedString(@"Table Content", @"table content print heading");

				NSArray *rows = [[NSArray alloc] initWithArray:
					[data objectsAtIndexes:
						[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [data count] - 1)]]
				];

				[printData setObject:rows forKey:@"rows"];
				[connection setValue:[tableContentInstance usedQuery] forKey:@"query"];

				[rows release];
			}
				// Custom query view
			else if (view == SPTableViewCustomQuery) {

				NSArray *data = [customQueryInstance currentResult];

				heading = NSLocalizedString(@"Query Result", @"query result print heading");

				NSArray *rows = [[NSArray alloc] initWithArray:
					[data objectsAtIndexes:
						[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [data count] - 1)]]
				];

				[printData setObject:rows forKey:@"rows"];
				[connection setValue:[customQueryInstance usedQuery] forKey:@"query"];

				[rows release];
			}
				// Table relations view
			else if (view == SPTableViewRelations) {

				NSArray *data = [tableRelationsInstance relationDataForPrinting];

				heading = NSLocalizedString(@"Table Relations", @"toolbar item label for switching to the Table Relations tab");

				NSArray *rows = [[NSArray alloc] initWithArray:
					[data objectsAtIndexes:
						[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, ([data count] - 1))]]
				];

				[printData setObject:rows forKey:@"rows"];

				[rows release];
			}
				// Table triggers view
			else if (view == SPTableViewTriggers) {

				NSArray *data = [tableTriggersInstance triggerDataForPrinting];

				heading = NSLocalizedString(@"Table Triggers", @"toolbar item label for switching to the Table Triggers tab");

				NSArray *rows = [[NSArray alloc] initWithArray:
					[data objectsAtIndexes:
						[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, ([data count] - 1))]]
				];

				[printData setObject:rows forKey:@"rows"];

				[rows release];
			}

			[printData setObject:heading forKey:@"heading"];
		});

		// Set up template engine with your chosen matcher
		MGTemplateEngine *engine = [MGTemplateEngine templateEngine];

		[engine setMatcher:[ICUTemplateMatcher matcherWithTemplateEngine:engine]];

		[engine setObject:connection forKey:@"c"];

		[printData setObject:([prefs boolForKey:SPUseMonospacedFonts]) ? SPDefaultMonospacedFontName : @"Lucida Grande" forKey:@"font"];
		[printData setObject:([prefs boolForKey:SPDisplayTableViewVerticalGridlines]) ? @"1px solid #CCCCCC" : @"none" forKey:@"gridlines"];

		NSString *HTMLString = [engine processTemplateInFileAtPath:[[NSBundle mainBundle] pathForResource:SPHTMLPrintTemplate ofType:@"html"] withVariables:printData];

		// Check if the operation has been cancelled
		if ((printThread != nil) && (![NSThread isMainThread]) && ([printThread isCancelled])) {
			[self endTask];
			return;
		}

		[self performSelectorOnMainThread:@selector(loadPrintWebViewWithHTMLString:) withObject:HTMLString waitUntilDone:NO];
	}
}

/**
 * Generates the HTML for the table information view that is to be printed.
 */
- (void)generateTableInfoHTMLForPrinting
{
	@autoreleasepool {
		// Set up template engine with your chosen matcher
		MGTemplateEngine *engine = [MGTemplateEngine templateEngine];

		[engine setMatcher:[ICUTemplateMatcher matcherWithTemplateEngine:engine]];

		NSMutableDictionary *connection = [self connectionInformation];
		NSMutableDictionary *printData = [NSMutableDictionary dictionary];

		NSString *heading = NSLocalizedString(@"Table Information", @"table information print heading");

		[engine setObject:connection forKey:@"c"];
		[engine setObject:[[extendedTableInfoInstance onMainThread] tableInformationForPrinting] forKey:@"i"];

		[printData setObject:heading forKey:@"heading"];
		[printData setObject:[[NSUnarchiver unarchiveObjectWithData:[prefs objectForKey:SPCustomQueryEditorFont]] fontName] forKey:@"font"];

		NSString *HTMLString = [engine processTemplateInFileAtPath:[[NSBundle mainBundle] pathForResource:SPHTMLTableInfoPrintTemplate ofType:@"html"] withVariables:printData];

		// Check if the operation has been cancelled
		if ((printThread != nil) && (![NSThread isMainThread]) && ([printThread isCancelled])) {
			[self endTask];
			return;
		}

		[self performSelectorOnMainThread:@selector(loadPrintWebViewWithHTMLString:) withObject:HTMLString waitUntilDone:NO];
	}
}

/**
 * Returns an array of columns for whichever view is being printed.
 *
 * MUST BE CALLED ON THE UI THREAD!
 */
- (NSArray *)columnNames
{
	NSArray *columns = nil;

	SPTableViewType view = [self currentlySelectedView];

	// Table source view
	if ((view == SPTableViewStructure) && ([[tableSourceInstance tableSourceForPrinting] count] > 0)) {

		columns = [[NSArray alloc] initWithArray:[[[tableSourceInstance tableSourceForPrinting] objectForKey:@"structure"] objectAtIndex:0] copyItems:YES];
	}
	// Table content view
	else if ((view == SPTableViewContent) && ([[tableContentInstance currentResult] count] > 0)) {

		columns = [[NSArray alloc] initWithArray:[[tableContentInstance currentResult] objectAtIndex:0] copyItems:YES];
	}
	// Custom query view
	else if ((view == SPTableViewCustomQuery) && ([[customQueryInstance currentResult] count] > 0)) {

		columns = [[NSArray alloc] initWithArray:[[customQueryInstance currentResult] objectAtIndex:0] copyItems:YES];
	}
	// Table relations view
	else if ((view == SPTableViewRelations) && ([[tableRelationsInstance relationDataForPrinting] count] > 0)) {

		columns = [[NSArray alloc] initWithArray:[[tableRelationsInstance relationDataForPrinting] objectAtIndex:0] copyItems:YES];
	}
	// Table triggers view
	else if ((view == SPTableViewTriggers) && ([[tableTriggersInstance triggerDataForPrinting] count] > 0)) {

		columns = [[NSArray alloc] initWithArray:[[tableTriggersInstance triggerDataForPrinting] objectAtIndex:0] copyItems:YES];
	}

	if (columns) [columns autorelease];

	return columns;
}

/**
 * Generates a dictionary of connection information that is used for printing.
 */
- (NSMutableDictionary *)connectionInformation
{
	NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
	NSString *versionForPrint = [NSString stringWithFormat:@"%@ %@ (%@ %@)",
	                                                       [infoDict objectForKey:@"CFBundleName"],
	                                                       [infoDict objectForKey:@"CFBundleShortVersionString"],
	                                                       NSLocalizedString(@"build", @"build label"),
	                                                       [infoDict objectForKey:@"CFBundleVersion"]];

	NSMutableDictionary *connection = [NSMutableDictionary dictionary];

	if ([[self user] length]) {
		[connection setValue:[self user] forKey:@"username"];
	}

	if ([[self table] length]) {
		[connection setValue:[self table] forKey:@"table"];
	}

	if ([connectionController port] && [[connectionController port] length]) {
		[connection setValue:[connectionController port] forKey:@"port"];
	}

	[connection setValue:[self host] forKey:@"hostname"];
	[connection setValue:selectedDatabase forKey:@"database"];
	[connection setValue:versionForPrint forKey:@"version"];

	return connection;
}

#pragma mark -

- (void)dealloc
{
	NSAssert([NSThread isMainThread], @"Calling %s from a background thread is not supported!", __func__);
	
	// Tell listeners that this database document is being closed - fixes retain cycles and allows cleanup
	[[NSNotificationCenter defaultCenter] postNotificationName:SPDocumentWillCloseNotification object:self];

	// Unregister observers
	[self _removePreferenceObservers];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	// see -(void)awakeFromNib for the reasoning behind this.
	SPClear(chooseDatabaseButton);
	SPClear(historyControl);

	for (id retainedObject in nibObjectsToRelease) [retainedObject release];
	
	SPClear(nibObjectsToRelease);
	
	SPClear(databaseStructureRetrieval);
	
	SPClear(allDatabases);
	SPClear(allSystemDatabases);
	SPClear(gotoDatabaseController);
	SPClear(undoManager);
	SPClear(printWebView);
	SPClear(selectedDatabaseEncoding);

	[taskProgressWindow close];
	
	if (processListController) [processListController close];

	// #2924: The connection controller doesn't retain its delegate (us), but it may outlive us (e.g. when running a bg thread)
	[connectionController setDelegate:nil];
	SPClear(connectionController);
	
	if (selectedTableName) SPClear(selectedTableName);
	if (processListController) SPClear(processListController);
	if (serverVariablesController) SPClear(serverVariablesController);
	if (mySQLConnection) SPClear(mySQLConnection);
	if (selectedDatabase) SPClear(selectedDatabase);
	if (mySQLVersion) SPClear(mySQLVersion);
	if (taskDrawTimer) [taskDrawTimer invalidate], SPClear(taskDrawTimer);
	if (queryExecutionTimer) [queryExecutionTimer invalidate], SPClear(queryExecutionTimer);
	if (taskFadeInStartDate) SPClear(taskFadeInStartDate);
	if (queryEditorInitString) SPClear(queryEditorInitString);
	if (sqlFileURL) SPClear(sqlFileURL);
	if (spfFileURL) SPClear(spfFileURL);
	if (spfPreferences) SPClear(spfPreferences);
	if (spfSession) SPClear(spfSession);
	if (spfDocData) SPClear(spfDocData);
	if (mainToolbar) SPClear(mainToolbar);
	if (titleAccessoryView) SPClear(titleAccessoryView);
	if (taskProgressWindow) SPClear(taskProgressWindow);
	if (serverSupport) SPClear(serverSupport);
	if (processID) SPClear(processID);
	if (runningActivitiesArray) SPClear(runningActivitiesArray);
	if (alterDatabaseCharsetHelper) SPClear(alterDatabaseCharsetHelper);
	if (addDatabaseCharsetHelper) SPClear(addDatabaseCharsetHelper);
	
	[super dealloc];
}

@end
