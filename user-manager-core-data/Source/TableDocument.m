//
//  $Id$
//
//  TableDocument.m
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

#import "TableDocument.h"
#import "TablesList.h"
#import "TableSource.h"
#import "TableContent.h"
#import "CustomQuery.h"
#import "TableDump.h"
#import "ImageAndTextCell.h"
#import "SPGrowlController.h"
#import "SPExportController.h"
#import "SPQueryConsole.h"
#import "SPSQLParser.h"
#import "SPTableData.h"
#import "SPDatabaseData.h"
#import "SPStringAdditions.h"
#import "SPArrayAdditions.h"
#import "MainController.h"
#import "SPExtendedTableInfo.h"
#import "SPConnectionController.h"
#import "SPHistoryController.h"
#import "SPPreferenceController.h"
#import "SPPrintAccessory.h"
#import "QLPreviewPanel.h"
#import "SPUserManager.h"

// Used for printing
#import "MGTemplateEngine.h"
#import "ICUTemplateMatcher.h"

@implementation TableDocument

- (id)init
{
	if ((self = [super init])) {
		
		_mainNibLoaded = NO;
		_encoding = [[NSString alloc] initWithString:@"utf8"];
		_isConnected = NO;
		chooseDatabaseButton = nil;
		chooseDatabaseToolbarItem = nil;
		connectionController = nil;
		selectedDatabase = nil;
		mySQLConnection = nil;
		mySQLVersion = nil;
		variables = nil;
		
		printWebView = [[WebView alloc] init];
		[printWebView setFrameLoadDelegate:self];
		
		prefs = [NSUserDefaults standardUserDefaults];

	}

	return self;
}

- (void)awakeFromNib
{
	if (_mainNibLoaded) return;
	_mainNibLoaded = YES;

	// The first window should use autosaving; subsequent windows should cascade
	BOOL usedAutosave = [tableWindow setFrameAutosaveName:[self windowNibName]];
	if (!usedAutosave) {
		[tableWindow setFrameUsingName:[self windowNibName]];
		NSArray *documents = [[NSDocumentController sharedDocumentController] documents];
		NSRect previousFrame = [[[documents objectAtIndex:(([documents count] > 1)?[documents count]-2:[documents count]-1)] valueForKey:@"tableWindow"] frame];
		NSPoint topLeftPoint = previousFrame.origin;
		topLeftPoint.y += previousFrame.size.height;
		[tableWindow setFrameTopLeftPoint:[tableWindow cascadeTopLeftFromPoint:topLeftPoint]];
	}

	// Set up the toolbar
	[self setupToolbar];

	// Set up the connection controller
	connectionController = [[SPConnectionController alloc] initWithDocument:self];

	// Register observers for when the DisplayTableViewVerticalGridlines preference changes
	[prefs addObserver:tableSourceInstance forKeyPath:@"DisplayTableViewVerticalGridlines" options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:tableContentInstance forKeyPath:@"DisplayTableViewVerticalGridlines" options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:customQueryInstance forKeyPath:@"DisplayTableViewVerticalGridlines" options:NSKeyValueObservingOptionNew context:NULL];

	// Register observers for when the logging preference changes
	[prefs addObserver:[SPQueryConsole sharedQueryConsole] forKeyPath:@"ConsoleEnableLogging" options:NSKeyValueObservingOptionNew context:NULL];
	
	// Register a second observer for when the logging preference changes so we can tell the current connection about it
	[prefs addObserver:self forKeyPath:@"ConsoleEnableLogging" options:NSKeyValueObservingOptionNew context:NULL];

	// Find the Database -> Database Encoding menu (it's not in our nib, so we can't use interface builder)
	selectEncodingMenu = [[[[[NSApp mainMenu] itemWithTag:1] submenu] itemWithTag:1] submenu];
	
	// Hide the tabs in the tab view (we only show them to allow switching tabs in interface builder)
	[tableTabView setTabViewType:NSNoTabsNoBorder];

	// Add the icon accessory view to the title bar
	NSView *windowFrame = [[tableWindow contentView] superview];
	NSRect av = [titleAccessoryView frame];
	NSRect initialAccessoryViewFrame = NSMakeRect(
											[windowFrame frame].size.width - av.size.width - 30,
											[windowFrame frame].size.height - av.size.height,
											av.size.width,
											av.size.height);
	[titleAccessoryView setFrame:initialAccessoryViewFrame];
	[windowFrame addSubview:titleAccessoryView];	

	// Load additional nibs
	if (![NSBundle loadNibNamed:@"ConnectionErrorDialog" owner:self]) {
		NSLog(@"Connection error dialog could not be loaded; connection failure handling will not function correctly.");
	}
}

#pragma mark -
#pragma mark Connection callback and methods

- (void) setConnection:(MCPConnection *)theConnection
{
	MCPResult *theResult;
	id version;

	_isConnected = YES;
	mySQLConnection = [theConnection retain];
	
	// Set the connection encoding
	NSString *encodingName = [prefs objectForKey:@"DefaultEncoding"];
	if ( [encodingName isEqualToString:@"Autodetect"] ) {
		[self setConnectionEncoding:[self databaseEncoding] reloadingViews:NO];
	} else {
		[self setConnectionEncoding:[self mysqlEncodingFromDisplayEncoding:encodingName] reloadingViews:NO];
	}

	// Get the mysql version
	theResult = [mySQLConnection queryString:@"SHOW VARIABLES LIKE 'version'"];
	version = [[theResult fetchRowAsArray] objectAtIndex:1];
	if (mySQLVersion) [mySQLVersion release], mySQLVersion = nil;
	if ( [version isKindOfClass:[NSData class]] ) {
		// starting with MySQL 4.1.14 the mysql variables are returned as nsdata
		mySQLVersion = [[NSString alloc] initWithData:version encoding:[mySQLConnection encoding]];
	} else {
		mySQLVersion = [[NSString alloc] initWithString:version];
	}

	// Update the selected database if appropriate
	if ([connectionController database] && ![[connectionController database] isEqualToString:@""]) {
		if (selectedDatabase) [selectedDatabase release], selectedDatabase = nil;
		selectedDatabase = [[NSString alloc] initWithString:[connectionController database]];
		[spHistoryControllerInstance updateHistoryEntries];
	}

	// Update the database list
	[self setDatabases:self];

	// For each of the main controllers, assign the current connection
	[tablesListInstance setConnection:mySQLConnection];
	[tableSourceInstance setConnection:mySQLConnection];
	[tableContentInstance setConnection:mySQLConnection];
	[tableRelationsInstance setConnection:mySQLConnection];
	[customQueryInstance setConnection:mySQLConnection];
	[tableDumpInstance setConnection:mySQLConnection];
	[spExportControllerInstance setConnection:mySQLConnection];
	[tableDataInstance setConnection:mySQLConnection];
	[extendedTableInfoInstance setConnection:mySQLConnection];
	[databaseDataInstance setConnection:mySQLConnection];

	// Set the cutom query editor's MySQL version
	[customQueryInstance setMySQLversion:mySQLVersion];

	[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/%@", mySQLVersion, [self name], ([self database]?[self database]:@"")]];
	[self viewStructure:self];

	// Connected Growl notification		
	[[SPGrowlController sharedGrowlController] notifyWithTitle:@"Connected"
												   description:[NSString stringWithFormat:NSLocalizedString(@"Connected to %@",@"description for connected growl notification"), [tableWindow title]]
											  notificationName:@"Connected"];

}

/**
 * Set whether the connection controller should automatically start
 * connecting; called by maincontroller, but only for first window.
 */
- (void)setShouldAutomaticallyConnect:(BOOL)shouldAutomaticallyConnect
{
	_shouldOpenConnectionAutomatically = shouldAutomaticallyConnect;
}

/**
 * Allow the connection controller to determine whether connection should
 * be automatically triggered.
 */
- (BOOL)shouldAutomaticallyConnect
{
	return _shouldOpenConnectionAutomatically;
}

#pragma mark -
#pragma mark Printing

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame 
{	
	//because I need the webFrame loaded (for preview), I've moved the actuall printing here.
	NSPrintInfo *printInfo = [self printInfo];
	[printInfo setHorizontalPagination:NSFitPagination];
	[printInfo setVerticalPagination:NSAutoPagination];
	[printInfo setVerticallyCentered:NO];
	[printInfo setTopMargin:30];
	[printInfo setBottomMargin:30];
	[printInfo setLeftMargin:10];
	[printInfo setRightMargin:10];
	
	NSPrintOperation *op = [NSPrintOperation
							printOperationWithView:[[[printWebView mainFrame] frameView] documentView]
							printInfo:printInfo];
	
	//add ability to select orientation to print panel
	NSPrintPanel *printPanel = [op printPanel];
	[printPanel setOptions:[printPanel options] + NSPrintPanelShowsOrientation + NSPrintPanelShowsScaling + NSPrintPanelShowsPaperSize];
	
	SPPrintAccessory *printAccessory = [[SPPrintAccessory alloc] init];
	[printAccessory initWithNibName:@"printAccessory" bundle:nil];
	[printAccessory setPrintView:printWebView];
	[printPanel addAccessoryController:printAccessory];
	
	NSPageLayout *pageLayout = [NSPageLayout pageLayout];
	[pageLayout addAccessoryController:printAccessory];
    [printAccessory release];
	
	[op setPrintPanel:printPanel];
	
    [op runOperationModalForWindow:tableWindow
						  delegate:self
					didRunSelector:
	 @selector(printOperationDidRun:success:contextInfo:)
					   contextInfo:NULL];

}

- (IBAction)printDocument:(id)sender
{
	//here load the printing document. The actual printing is done in the doneLoading delegate.
	[[printWebView mainFrame] loadHTMLString:[self getHTMLforPrint] baseURL:nil];
}

- (void)printOperationDidRun:(NSPrintOperation *)printOperation
					 success:(BOOL)success
				 contextInfo:(void *)info
{
	//selector for print... maybe we can get rid of this?
}

- (NSString *)getHTMLforPrint
{
	// Set up template engine with your chosen matcher.
	MGTemplateEngine *engine = [MGTemplateEngine templateEngine];
	[engine setMatcher:[ICUTemplateMatcher matcherWithTemplateEngine:engine]];
	
	NSString *versionForPrint = [NSString stringWithFormat:@"%@ %@ (build %@)",
		[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"],
		[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"],
		[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]
	];
	
	NSMutableDictionary *connection = [[NSMutableDictionary alloc] init];
	if([[self user] length])
		[connection setValue:[self user] forKey:@"username"];
	[connection setValue:[self host] forKey:@"hostname"];
	if([connectionController port] &&[[connectionController port] length])
		[connection setValue:[connectionController port] forKey:@"port"];
	[connection setValue:selectedDatabase forKey:@"database"];
	[connection setValue:versionForPrint forKey:@"version"];
	
	NSArray *columns, *rows;
	columns = rows = nil;
	columns = [self columnNames];

	if ( [tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 0 ){
		if([[tableSourceInstance tableStructureForPrint] count] > 1)
			rows = [[NSArray alloc] initWithArray:
					[[tableSourceInstance tableStructureForPrint] objectsAtIndexes:
					 [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [[tableSourceInstance tableStructureForPrint] count]-1)]
					 ]
					];
	}
	else if ( [tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 1 ){
		if([[tableContentInstance currentResult] count] > 1)
			rows = [[NSArray alloc] initWithArray:
					[[tableContentInstance currentDataResult] objectsAtIndexes:
					 [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [[tableContentInstance currentResult] count]-1)]
					 ]
					];
		[connection setValue:[tableContentInstance usedQuery] forKey:@"query"];
	}
	else if ( [tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 2 ){
		if([[customQueryInstance currentResult] count] > 1)
			rows = [[NSArray alloc] initWithArray:
					[[customQueryInstance currentResult] objectsAtIndexes:
					 [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [[customQueryInstance currentResult] count]-1)]
					 ]
					];
		[connection setValue:[customQueryInstance usedQuery] forKey:@"query"];
	}
	
	[engine setObject:connection forKey:@"c"];
	// Get path to template.
	NSString *templatePath = [[NSBundle mainBundle] pathForResource:@"sequel-pro-print-template" ofType:@"html"];
	NSDictionary *print_data = [NSDictionary dictionaryWithObjectsAndKeys: 
			columns, @"columns",
			rows, @"rows",
			nil];

    [connection release];
    if (rows) [rows release];

	// Process the template and display the results.
	NSString *result = [engine processTemplateInFileAtPath:templatePath withVariables:print_data];
	//NSLog(@"result %@", result);

	return result;
}

#pragma mark -
#pragma mark Database methods

/**
 * sets up the database select toolbar item
 */
- (IBAction)setDatabases:(id)sender;
{
	if (!chooseDatabaseButton)
		return;
	
	[chooseDatabaseButton removeAllItems];
	
	[chooseDatabaseButton addItemWithTitle:NSLocalizedString(@"Choose Database...", @"menu item for choose db")];
	[[chooseDatabaseButton menu] addItem:[NSMenuItem separatorItem]];
	[[chooseDatabaseButton menu] addItemWithTitle:NSLocalizedString(@"Add Database...", @"menu item to add db") action:@selector(addDatabase:) keyEquivalent:@""];
	[[chooseDatabaseButton menu] addItemWithTitle:NSLocalizedString(@"Refresh Databases", @"menu item to refresh databases") action:@selector(setDatabases:) keyEquivalent:@""];
	[[chooseDatabaseButton menu] addItem:[NSMenuItem separatorItem]];
	
	MCPResult *queryResult = [mySQLConnection listDBs];
	
	if ([queryResult numOfRows]) {
		[queryResult dataSeek:0];
	}
	
	// if([allDatabases count])
	// 	[allDatabases removeAllObjects];

	if(allDatabases)
		[allDatabases release];
		
	allDatabases = [[NSMutableArray alloc] initWithCapacity:[queryResult numOfRows]];

	for (int i = 0 ; i < [queryResult numOfRows] ; i++)
		[allDatabases addObject:NSArrayObjectAtIndex([queryResult fetchRowAsArray], 0)];

	for (id db in allDatabases)
		[chooseDatabaseButton addItemWithTitle:db];
	
	(![self database]) ? [chooseDatabaseButton selectItemAtIndex:0] : [chooseDatabaseButton selectItemWithTitle:[self database]];
}

/**
 * selects the database choosen by the user
 * errorsheet if connection failed
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

	// Save existing scroll position and details
	[spHistoryControllerInstance updateHistoryEntries];

	// show error on connection failed
	if ( ![mySQLConnection selectDB:[chooseDatabaseButton titleOfSelectedItem]] ) {
		if ( [mySQLConnection isConnected] ) {
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil, [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to database %@.\nBe sure that you have the necessary privileges.", @"message of panel when connection to db failed after selecting from popupbutton"), [chooseDatabaseButton titleOfSelectedItem]]);
			[self setDatabases:self];
		}
		return;
	}
	
	//setConnection of TablesList and TablesDump to reload tables in db
	if (selectedDatabase) [selectedDatabase release], selectedDatabase = nil;
	selectedDatabase = [[NSString alloc] initWithString:[chooseDatabaseButton titleOfSelectedItem]];
	[tablesListInstance setConnection:mySQLConnection];
	[tableDumpInstance setConnection:mySQLConnection];
	[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/%@", mySQLVersion, [self name], [self database]]];

	// Add a history entry
	[spHistoryControllerInstance updateHistoryEntries];
}

/**
 * opens the add-db sheet and creates the new db
 */
- (IBAction)addDatabase:(id)sender
{
	int code = 0;
	
	if (![tablesListInstance selectionShouldChangeInTableView:nil]) {
		return;
	}
	
	[databaseNameField setStringValue:@""];
	
	[NSApp beginSheet:databaseSheet
	   modalForWindow:tableWindow
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
	
	code = [NSApp runModalForWindow:databaseSheet];
	
	[NSApp endSheet:databaseSheet];
	[databaseSheet orderOut:nil];
	
	if (!code) {
		(![self database]) ? [chooseDatabaseButton selectItemAtIndex:0] : [chooseDatabaseButton selectItemWithTitle:[self database]];
		return;
	}
	
	// This check is not necessary anymore as the add database button is now only enabled if the name field
	// has a length greater than zero. We'll leave it in just in case.
	if ([[databaseNameField stringValue] isEqualToString:@""]) {
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil, NSLocalizedString(@"Database must have a name.", @"message of panel when no db name is given"));
		return;
	}
	
	NSString *createStatement = [NSString stringWithFormat:@"CREATE DATABASE %@", [[databaseNameField stringValue] backtickQuotedString]];
	
	// If there is an encoding selected other than the default we must specify it in CREATE DATABASE statement
	if ([databaseEncodingButton indexOfSelectedItem] > 0) {
		createStatement = [NSString stringWithFormat:@"%@ DEFAULT CHARACTER SET %@", createStatement, [[self mysqlEncodingFromDisplayEncoding:[databaseEncodingButton title]] backtickQuotedString]];
	}
	
	// Create the database
	[mySQLConnection queryString:createStatement];
	
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		//error while creating db
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil, [NSString stringWithFormat:NSLocalizedString(@"Couldn't create database.\nMySQL said: %@", @"message of panel when creation of db failed"), [mySQLConnection getLastErrorMessage]]);
		return;
	}
	
	if (![mySQLConnection selectDB:[databaseNameField stringValue]] ) { //error while selecting new db (is this possible?!)
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil, [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to database %@.\nBe sure that you have the necessary privileges.", @"message of panel when connection to db failed after selecting from popupbutton"),
																																					  [databaseNameField stringValue]]);
		[self setDatabases:self];
		return;
	}
	
	//select new db
	if (selectedDatabase) [selectedDatabase release], selectedDatabase = nil;
	selectedDatabase = [[NSString alloc] initWithString:[databaseNameField stringValue]];
	[self setDatabases:self];
	[tablesListInstance setConnection:mySQLConnection];
	[tableDumpInstance setConnection:mySQLConnection];
	[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/%@", mySQLVersion, [self name], selectedDatabase]];
}

/**
 * closes the add-db sheet and stops modal session
 */
- (IBAction)closeDatabaseSheet:(id)sender
{
	[NSApp stopModalWithCode:[sender tag]];
}

/**
 * opens sheet to ask user if he really wants to delete the db
 */
- (IBAction)removeDatabase:(id)sender
{
	if ([chooseDatabaseButton indexOfSelectedItem] == 0)
		return;
	
	if (![tablesListInstance selectionShouldChangeInTableView:nil])
		return;
	
	NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Delete database '%@'?", @"delete database message"), [self database]]
									 defaultButton:NSLocalizedString(@"Delete", @"delete button") 
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button") 
									  otherButton:nil 
						informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the database '%@'. This operation cannot be undone.", @"delete database informative message"), [self database]]];
	
	[alert setAlertStyle:NSCriticalAlertStyle];
	
	[alert beginSheetModalForWindow:tableWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"removedatabase"];
}

/*
 * Returns an array of all available database names
 */
- (NSArray *)allDatabaseNames
{
	return allDatabases;
}

/**
 * alert sheets method
 * invoked when alertSheet get closed
 * if contextInfo == removedatabase -> tries to remove the selected database
 */
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{		
	if ([contextInfo isEqualToString:@"removedatabase"]) {
		if (returnCode != NSAlertDefaultReturn)
			return;
		
		[mySQLConnection queryString:[NSString stringWithFormat:@"DROP DATABASE %@", [[self database] backtickQuotedString]]];
		if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
			// error while deleting db
			[self performSelector:@selector(showErrorSheetWith:) 
				withObject:[NSArray arrayWithObjects:NSLocalizedString(@"Error", @"error"),
								[NSString stringWithFormat:NSLocalizedString(@"Couldn't remove database.\nMySQL said: %@", @"message of panel when removing db failed"), 
									[mySQLConnection getLastErrorMessage]],
							nil] 
				afterDelay:0.3];
			return;
		}
		
		// db deleted with success
		if (selectedDatabase) [selectedDatabase release], selectedDatabase = nil;
		[self setDatabases:self];
		[tablesListInstance setConnection:mySQLConnection];
		[tableDumpInstance setConnection:mySQLConnection];
		[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/", mySQLVersion, [self name]]];
	}
}

/*
 * Show Error sheet (can be called from inside of a endSheet selector)
 * via [self performSelector:@selector(showErrorSheetWithTitle:) withObject: afterDelay:]
 */
-(void)showErrorSheetWith:(id)error
{
	// error := first object is the title , second the message, only one button OK
	NSBeginAlertSheet([error objectAtIndex:0], NSLocalizedString(@"OK", @"OK button"), 
			nil, nil, tableWindow, self, nil, nil, nil,
			[error objectAtIndex:1]);
}


/*
 * Reset the current selected database name
 */
- (void) refreshCurrentDatabase
{
	NSString *dbName;

	// Notify listeners that a query has started
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];
	
	MCPResult *theResult = [mySQLConnection queryString:@"SELECT DATABASE()"];
	if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
		int i;
		int r = [theResult numOfRows];
		if (r) [theResult dataSeek:0];
		for ( i = 0 ; i < r ; i++ ) {
			dbName = NSArrayObjectAtIndex([theResult fetchRowAsArray], 0);
		}
		if(![dbName isKindOfClass:[NSNull class]]) {
			if(![dbName isEqualToString:selectedDatabase]) {
				if (selectedDatabase) [selectedDatabase release], selectedDatabase = nil;
				selectedDatabase = [[NSString alloc] initWithString:dbName];
				[chooseDatabaseButton selectItemWithTitle:selectedDatabase];
				[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/%@", mySQLVersion, [self name], selectedDatabase]];
			}
		} else {
			if (selectedDatabase) [selectedDatabase release], selectedDatabase = nil;
			[chooseDatabaseButton selectItemAtIndex:0];
			[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/", mySQLVersion, [self name]]];
		}
	}
	
	//query finished
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
	
}

#pragma mark -
#pragma mark Console methods

/**
 * Shows or hides the console
 */
- (void)toggleConsole:(id)sender
{
	BOOL isConsoleVisible = [[[SPQueryConsole sharedQueryConsole] window] isVisible];

	// If the Console window is not visible data are not reloaded (for speed).
	// Due to that update list if user opens the Console window.
	if(!isConsoleVisible) {
		[[SPQueryConsole sharedQueryConsole] updateEntries];
	}

	// Show or hide the console
	[[[SPQueryConsole sharedQueryConsole] window] setIsVisible:(!isConsoleVisible)];
	
	// Get the menu item for showing and hiding the console. This is isn't the best way to get it as any 
	// changes to the menu structure will result in the wrong item being selected.
	NSMenuItem *menuItem = [[[[NSApp mainMenu] itemAtIndex:3] submenu] itemAtIndex:5];
	
	// Only update the menu item title if its the menu item and not the toolbar
	[menuItem setTitle:(!isConsoleVisible) ? NSLocalizedString(@"Hide Console", @"Hide Console") : NSLocalizedString(@"Show Console", @"Show Console")];
}

/**
 * Brings the console to the fron
 */
- (void)showConsole:(id)sender
{
	BOOL isConsoleVisible = [[[SPQueryConsole sharedQueryConsole] window] isVisible];

	if (!isConsoleVisible) {
		[self toggleConsole:sender];
	} else {
		[[[SPQueryConsole sharedQueryConsole] window] makeKeyAndOrderFront:self];
	}
}

/**
 * Clears the console by removing all of its messages
 */
- (void)clearConsole:(id)sender
{
	[[SPQueryConsole sharedQueryConsole] clearConsole:sender];
}

#pragma mark -
#pragma mark Encoding Methods

/**
 * Set the encoding for the database connection
 */
- (void)setConnectionEncoding:(NSString *)mysqlEncoding reloadingViews:(BOOL)reloadViews
{
	_encodingViaLatin1 = NO;

	// Special-case UTF-8 over latin 1 to allow viewing/editing of mangled data.
	if ([mysqlEncoding isEqualToString:@"utf8-"]) {
		_encodingViaLatin1 = YES;
		mysqlEncoding = @"utf8";
	}
	
	// set encoding of connection and client
	[mySQLConnection queryString:[NSString stringWithFormat:@"SET NAMES '%@'", mysqlEncoding]];
	
	if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
		if (_encodingViaLatin1)
			[mySQLConnection queryString:@"SET CHARACTER_SET_RESULTS=latin1"];
		[mySQLConnection setEncoding:[MCPConnection encodingForMySQLEncoding:[mysqlEncoding UTF8String]]];
		[_encoding release];
		_encoding = [[NSString alloc] initWithString:mysqlEncoding];
	} else {
		[mySQLConnection queryString:[NSString stringWithFormat:@"SET NAMES '%@'", [self databaseEncoding]]];
		_encodingViaLatin1 = NO;
		if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
			NSLog(@"Error: could not set encoding to %@ nor fall back to database encoding on MySQL %@", mysqlEncoding, [self mySQLVersion]);
			return;
		}
	}
		
	// update the selected menu item
	if (_encodingViaLatin1) {
		[self updateEncodingMenuWithSelectedEncoding:[self encodingNameFromMySQLEncoding:[NSString stringWithFormat:@"%@-", mysqlEncoding]]];
	} else {
		[self updateEncodingMenuWithSelectedEncoding:[self encodingNameFromMySQLEncoding:mysqlEncoding]];
	}

	// Reload stuff as appropriate
	[tableDataInstance resetAllData];
	if (reloadViews) {
		if ([tablesListInstance structureLoaded]) [tableSourceInstance reloadTable:self];
		if ([tablesListInstance contentLoaded]) [tableContentInstance reloadTable:self];
		if ([tablesListInstance statusLoaded]) [extendedTableInfoInstance reloadTable:self];
	}
}

/**
 * returns the current mysql encoding for this object
 */
- (NSString *)connectionEncoding
{
	return _encoding;
}

/**
 * Returns whether the current encoding should display results via Latin1 transport for backwards compatibility.
 * This is a delegate method of MCPKit's MCPConnection class.
 */
- (BOOL)connectionEncodingViaLatin1:(id)connection
{
	return _encodingViaLatin1;
}

/**
 * updates the currently selected item in the encoding menu
 * 
 * @param NSString *encoding - the title of the menu item which will be selected
 */
- (void)updateEncodingMenuWithSelectedEncoding:(NSString *)encoding
{
	NSEnumerator *dbEncodingMenuEn = [[selectEncodingMenu itemArray] objectEnumerator];
	id menuItem;
	int correctStateForMenuItem;
	while (menuItem = [dbEncodingMenuEn nextObject]) {
		correctStateForMenuItem = [[menuItem title] isEqualToString:encoding] ? NSOnState : NSOffState;
		
		if ([menuItem state] == correctStateForMenuItem) // don't re-apply state incase it causes performance issues
			continue;
		
		[menuItem setState:correctStateForMenuItem];
	}
}

/**
 * Returns the display name for a mysql encoding
 */
- (NSString *)encodingNameFromMySQLEncoding:(NSString *)mysqlEncoding
{
	NSDictionary *translationMap = [NSDictionary dictionaryWithObjectsAndKeys:
									@"UCS-2 Unicode (ucs2)", @"ucs2",
									@"UTF-8 Unicode (utf8)", @"utf8",
									@"UTF-8 Unicode via Latin 1", @"utf8-",
									@"US ASCII (ascii)", @"ascii",
									@"ISO Latin 1 (latin1)", @"latin1",
									@"Mac Roman (macroman)", @"macroman",
									@"Windows Latin 2 (cp1250)", @"cp1250",
									@"ISO Latin 2 (latin2)", @"latin2",
									@"Windows Arabic (cp1256)", @"cp1256",
									@"ISO Greek (greek)", @"greek",
									@"ISO Hebrew (hebrew)", @"hebrew",
									@"ISO Turkish (latin5)", @"latin5",
									@"Windows Baltic (cp1257)", @"cp1257",
									@"Windows Cyrillic (cp1251)", @"cp1251",
									@"Big5 Traditional Chinese (big5)", @"big5",
									@"Shift-JIS Japanese (sjis)", @"sjis",
									@"EUC-JP Japanese (ujis)", @"ujis",
									@"EUC-KR Korean (euckr)", @"euckr",
									nil];
	NSString *encodingName = [translationMap valueForKey:mysqlEncoding];
	
	if (!encodingName)
		return [NSString stringWithFormat:@"Unknown Encoding (%@)", mysqlEncoding, nil];
	
	return encodingName;
}

/**
 * Returns the mysql encoding for an encoding string that is displayed to the user
 */
- (NSString *)mysqlEncodingFromDisplayEncoding:(NSString *)encodingName
{
	NSDictionary *translationMap = [NSDictionary dictionaryWithObjectsAndKeys:
									@"ucs2", @"UCS-2 Unicode (ucs2)",
									@"utf8", @"UTF-8 Unicode (utf8)",
									@"utf8-", @"UTF-8 Unicode via Latin 1",
									@"ascii", @"US ASCII (ascii)",
									@"latin1", @"ISO Latin 1 (latin1)",
									@"macroman", @"Mac Roman (macroman)",
									@"cp1250", @"Windows Latin 2 (cp1250)",
									@"latin2", @"ISO Latin 2 (latin2)",
									@"cp1256", @"Windows Arabic (cp1256)",
									@"greek", @"ISO Greek (greek)",
									@"hebrew", @"ISO Hebrew (hebrew)",
									@"latin5", @"ISO Turkish (latin5)",
									@"cp1257", @"Windows Baltic (cp1257)",
									@"cp1251", @"Windows Cyrillic (cp1251)",
									@"big5", @"Big5 Traditional Chinese (big5)",
									@"sjis", @"Shift-JIS Japanese (sjis)",
									@"ujis", @"EUC-JP Japanese (ujis)",
									@"euckr", @"EUC-KR Korean (euckr)",
									nil];
	NSString *mysqlEncoding = [translationMap valueForKey:encodingName];
	
	if (!mysqlEncoding)
		return @"utf8";
	
	return mysqlEncoding;
}

/**
 * Detect and return the database connection encoding.
 * TODO: See http://code.google.com/p/sequel-pro/issues/detail?id=134 - some question over why this [historically] uses _connection not _database...
 */
- (NSString *)databaseEncoding
{
	// MySQL > 4.0
	id mysqlEncoding = [[[mySQLConnection queryString:@"SHOW VARIABLES LIKE 'character_set_connection'"] fetchRowAsDictionary] objectForKey:@"Value"];
	_supportsEncoding = (mysqlEncoding != nil);
	
	if ( [mysqlEncoding isKindOfClass:[NSData class]] ) { // MySQL 4.1.14 returns the mysql variables as nsdata
		mysqlEncoding = [mySQLConnection stringWithText:mysqlEncoding];
	}
	if ( !mysqlEncoding ) { // mysql 4.0 or older -> only default character set possible, cannot choose others using "set names xy"
		mysqlEncoding = [[[mySQLConnection queryString:@"SHOW VARIABLES LIKE 'character_set'"] fetchRowAsDictionary] objectForKey:@"Value"];
	}
	if ( !mysqlEncoding ) { // older version? -> set encoding to mysql default encoding latin1
		NSLog(@"Error: no character encoding found, mysql version is %@", [self mySQLVersion]);
		mysqlEncoding = @"latin1";
	}
	
	return mysqlEncoding;
}

/**
 * When sent by an NSMenuItem, will set the encoding based on the title of the menu item
 */
- (IBAction)chooseEncoding:(id)sender
{
	[self setConnectionEncoding:[self mysqlEncodingFromDisplayEncoding:[(NSMenuItem *)sender title]] reloadingViews:YES];
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

/**
 * Displays the CREATE TABLE syntax of the selected table to the user via a HUD panel.
 */
- (IBAction)showCreateTableSyntax:(id)sender
{
	//Create the query and get results
	NSString *query = nil;
	NSString *createWindowTitle;
	int colOffs = 1;
	
	if( [tablesListInstance tableType] == SP_TABLETYPE_TABLE ) {
		query = [NSString stringWithFormat:@"SHOW CREATE TABLE %@", [[self table] backtickQuotedString]];
		createWindowTitle = @"Create Table Syntax";
	}
	else if( [tablesListInstance tableType] == SP_TABLETYPE_VIEW ) {
		query = [NSString stringWithFormat:@"SHOW CREATE VIEW %@", [[self table] backtickQuotedString]];
		createWindowTitle = @"Create View Syntax";
	}
	else if( [tablesListInstance tableType] == SP_TABLETYPE_PROC ) {
		query = [NSString stringWithFormat:@"SHOW CREATE PROCEDURE %@", [[self table] backtickQuotedString]];
		createWindowTitle = @"Create Procedure Syntax";
		colOffs = 2;
	}
	else if( [tablesListInstance tableType] == SP_TABLETYPE_FUNC ) {
		query = [NSString stringWithFormat:@"SHOW CREATE FUNCTION %@", [[self table] backtickQuotedString]];
		createWindowTitle = @"Create Function Syntax";
		colOffs = 2;
	}

	if( query == nil )
		return;
	
	MCPResult *theResult = [mySQLConnection queryString:query];
	
	// Check for errors, only displaying if the connection hasn't been terminated
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		if ([mySQLConnection isConnected]) {
			NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"An error occured while creating table syntax.\n\n: %@",[mySQLConnection getLastErrorMessage]], @"OK", nil, nil);
		}
		return;
	}
	
	id tableSyntax = [[theResult fetchRowAsArray] objectAtIndex:colOffs];
	
	if ([tableSyntax isKindOfClass:[NSData class]])
		tableSyntax = [[NSString alloc] initWithData:tableSyntax encoding:[mySQLConnection encoding]];

	if([tablesListInstance tableType] == SP_TABLETYPE_VIEW)
		[syntaxViewContent setString:[tableSyntax createViewSyntaxPrettifier]];
	else
		[syntaxViewContent setString:tableSyntax];

	[syntaxViewContent setEditable:NO];
	
	[createTableSyntaxWindow setTitle:createWindowTitle];

	if(![createTableSyntaxWindow isVisible])
		[createTableSyntaxWindow makeKeyAndOrderFront:self];
}

/**
 * Copies the CREATE TABLE syntax of the selected table to the pasteboard.
 */
- (IBAction)copyCreateTableSyntax:(id)sender
{
	// Create the query and get results	
	NSString *query = nil;
	int colOffs = 1;
	
	if( [tablesListInstance tableType] == SP_TABLETYPE_TABLE ) {
		query = [NSString stringWithFormat:@"SHOW CREATE TABLE %@", [[self table] backtickQuotedString]];
	}
	else if( [tablesListInstance tableType] == SP_TABLETYPE_VIEW ) {
		query = [NSString stringWithFormat:@"SHOW CREATE VIEW %@", [[self table] backtickQuotedString]];
	}
	else if( [tablesListInstance tableType] == SP_TABLETYPE_PROC ) {
		query = [NSString stringWithFormat:@"SHOW CREATE PROCEDURE %@", [[self table] backtickQuotedString]];
		colOffs = 2;
	}
	else if( [tablesListInstance tableType] == SP_TABLETYPE_FUNC ) {
		query = [NSString stringWithFormat:@"SHOW CREATE FUNCTION %@", [[self table] backtickQuotedString]];
		colOffs = 2;
	}
	
	if( query == nil )
		return;	
	
	MCPResult *theResult = [mySQLConnection queryString:query];
	
	// Check for errors, only displaying if the connection hasn't been terminated
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		if ([mySQLConnection isConnected]) {
			NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"An error occured while creating table syntax.\n\n: %@",[mySQLConnection getLastErrorMessage]], @"OK", nil, nil);
		}
		return;
	}
	
	id tableSyntax = [[theResult fetchRowAsArray] objectAtIndex:colOffs];
	
	if ([tableSyntax isKindOfClass:[NSData class]])
		tableSyntax = [[[NSString alloc] initWithData:tableSyntax encoding:[mySQLConnection encoding]] autorelease];
	
	// copy to the clipboard
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	[pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
	if([tablesListInstance tableType] == SP_TABLETYPE_VIEW)
		[pb setString:[tableSyntax createViewSyntaxPrettifier] forType:NSStringPboardType];
	else
		[pb setString:tableSyntax forType:NSStringPboardType];

	// Table syntax copied Growl notification
	[[SPGrowlController sharedGrowlController] notifyWithTitle:@"Syntax Copied"
                                                   description:[NSString stringWithFormat:NSLocalizedString(@"Syntax for %@ table copied",@"description for table syntax copied growl notification"), [self table]] 
                                              notificationName:@"Syntax Copied"];
}

- (NSArray *)columnNames
{
	NSArray *columns = nil;
	if ( [tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 0
		&& [[tableSourceInstance tableStructureForPrint] count] > 0 ){
		columns = [[NSArray alloc] initWithArray:[[tableSourceInstance tableStructureForPrint] objectAtIndex:0] copyItems:YES];
	}
	else if ( [tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 1
		&& [[tableContentInstance currentResult] count] > 0 ){
		columns = [[NSArray alloc] initWithArray:[[tableContentInstance currentResult] objectAtIndex:0] copyItems:YES];
	}
	else if ( [tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 2
		&& [[customQueryInstance currentResult] count] > 0 ){
		columns = [[NSArray alloc] initWithArray:[[customQueryInstance currentResult] objectAtIndex:0] copyItems:YES];
	}
	
	if(columns) {
		[columns autorelease];
	}
	return columns;
}

/**
 * Performs a MySQL check table on the selected table and presents the result to the user via an alert sheet.
 */
- (IBAction)checkTable:(id)sender
{	
	MCPResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"CHECK TABLE %@", [[self table] backtickQuotedString]]];
	
	// Check for errors, only displaying if the connection hasn't been terminated
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		if ([mySQLConnection isConnected]) {
			
			[[NSAlert alertWithMessageText:@"Unable to check table" 
							 defaultButton:@"OK" 
						   alternateButton:nil 
							   otherButton:nil 
				 informativeTextWithFormat:[NSString stringWithFormat:@"An error occurred while trying to check the table '%@'. Please try again.\n\n%@", [self table], [mySQLConnection getLastErrorMessage]]] 
				  beginSheetModalForWindow:tableWindow 
							 modalDelegate:self 
							didEndSelector:NULL 
							   contextInfo:NULL];			
		}
		
		return;
	}
	
	// Process result
	NSDictionary *result = [[theResult fetch2DResultAsType:MCPTypeDictionary] lastObject];
	
	NSString *message = @"";
	
	message = ([[result objectForKey:@"Msg_type"] isEqualToString:@"status"]) ? @"Check table successfully passed." : @"Check table failed.";
	
	message = [NSString stringWithFormat:@"%@\n\nMySQL said: %@", message, [result objectForKey:@"Msg_text"]];
	
	[[NSAlert alertWithMessageText:[NSString stringWithFormat:@"Check table '%@'", [self table]] 
					 defaultButton:@"OK" 
				   alternateButton:nil 
					   otherButton:nil 
		 informativeTextWithFormat:message] 
		  beginSheetModalForWindow:tableWindow 
					 modalDelegate:self 
					didEndSelector:NULL 
					   contextInfo:NULL];	
}

/**
 * Analyzes the selected table and presents the result to the user via an alert sheet.
 */
- (IBAction)analyzeTable:(id)sender
{
	MCPResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"ANALYZE TABLE %@", [[self table] backtickQuotedString]]];
	
	// Check for errors, only displaying if the connection hasn't been terminated
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		if ([mySQLConnection isConnected]) {
			
			[[NSAlert alertWithMessageText:@"Unable to analyze table" 
							 defaultButton:@"OK" 
						   alternateButton:nil 
							   otherButton:nil 
				 informativeTextWithFormat:[NSString stringWithFormat:@"An error occurred while trying to analyze the table '%@'. Please try again.\n\n%@", [self table], [mySQLConnection getLastErrorMessage]]] 
				  beginSheetModalForWindow:tableWindow 
							 modalDelegate:self 
							didEndSelector:NULL 
							   contextInfo:NULL];			
		}
		
		return;
	}
	
	// Process result
	NSDictionary *result = [[theResult fetch2DResultAsType:MCPTypeDictionary] lastObject];
	
	NSString *message = @"";
	
	message = ([[result objectForKey:@"Msg_type"] isEqualToString:@"status"]) ? @"Successfully analyzed table" : @"Analyze table failed.";
	
	message = [NSString stringWithFormat:@"%@\n\nMySQL said: %@", message, [result objectForKey:@"Msg_text"]];
	
	[[NSAlert alertWithMessageText:[NSString stringWithFormat:@"Analyze table '%@'", [self table]] 
					 defaultButton:@"OK" 
				   alternateButton:nil 
					   otherButton:nil 
		 informativeTextWithFormat:message] 
		  beginSheetModalForWindow:tableWindow 
					 modalDelegate:self 
					didEndSelector:NULL 
					   contextInfo:NULL];
}

/**
 * Optimizes the selected table and presents the result to the user via an alert sheet.
 */
- (IBAction)optimizeTable:(id)sender
{
	MCPResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"OPTIMIZE TABLE %@", [[self table] backtickQuotedString]]];
	
	// Check for errors, only displaying if the connection hasn't been terminated
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		if ([mySQLConnection isConnected]) {
			
			[[NSAlert alertWithMessageText:@"Unable to optimize table" 
							 defaultButton:@"OK" 
						   alternateButton:nil 
							   otherButton:nil 
				 informativeTextWithFormat:[NSString stringWithFormat:@"An error occurred while trying to optimize the table '%@'. Please try again.\n\n%@", [self table], [mySQLConnection getLastErrorMessage]]] 
				  beginSheetModalForWindow:tableWindow 
							 modalDelegate:self 
							didEndSelector:NULL 
							   contextInfo:NULL];			
		}
		
		return;
	}
	
	// Process result
	NSDictionary *result = [[theResult fetch2DResultAsType:MCPTypeDictionary] lastObject];
	
	NSString *message = @"";
	
	message = ([[result objectForKey:@"Msg_type"] isEqualToString:@"status"]) ? @"Successfully optimized table" : @"Optimize table failed.";
	
	message = [NSString stringWithFormat:@"%@\n\nMySQL said: %@", message, [result objectForKey:@"Msg_text"]];
	
	[[NSAlert alertWithMessageText:[NSString stringWithFormat:@"Optimize table '%@'", [self table]] 
					 defaultButton:@"OK" 
				   alternateButton:nil 
					   otherButton:nil 
		 informativeTextWithFormat:message] 
		  beginSheetModalForWindow:tableWindow 
					 modalDelegate:self 
					didEndSelector:NULL 
					   contextInfo:NULL];
}

/**
 * Repairs the selected table and presents the result to the user via an alert sheet.
 */
- (IBAction)repairTable:(id)sender
{
	MCPResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"REPAIR TABLE %@", [[self table] backtickQuotedString]]];
	
	// Check for errors, only displaying if the connection hasn't been terminated
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		if ([mySQLConnection isConnected]) {
			
			[[NSAlert alertWithMessageText:@"Unable to repair table" 
							 defaultButton:@"OK" 
						   alternateButton:nil 
							   otherButton:nil 
				 informativeTextWithFormat:[NSString stringWithFormat:@"An error occurred while trying to repair the table '%@'. Please try again.\n\n%@", [self table], [mySQLConnection getLastErrorMessage]]] 
				  beginSheetModalForWindow:tableWindow 
							 modalDelegate:self 
							didEndSelector:NULL 
							   contextInfo:NULL];			
		}
		
		return;
	}
	
	// Process result
	NSDictionary *result = [[theResult fetch2DResultAsType:MCPTypeDictionary] lastObject];
	
	NSString *message = @"";
	
	message = ([[result objectForKey:@"Msg_type"] isEqualToString:@"status"]) ? @"Successfully repaired table" : @"Repair table failed.";
	
	message = [NSString stringWithFormat:@"%@\n\nMySQL said: %@", message, [result objectForKey:@"Msg_text"]];
	
	[[NSAlert alertWithMessageText:[NSString stringWithFormat:@"Repair table '%@'", [self table]] 
					 defaultButton:@"OK" 
				   alternateButton:nil 
					   otherButton:nil 
		 informativeTextWithFormat:message] 
		  beginSheetModalForWindow:tableWindow 
					 modalDelegate:self 
					didEndSelector:NULL 
					   contextInfo:NULL];
}

/**
 * Flush the selected table and inform the user via a dialog sheet.
 */
- (IBAction)flushTable:(id)sender
{
	[mySQLConnection queryString:[NSString stringWithFormat:@"FLUSH TABLE %@", [[self table] backtickQuotedString]]];
	
	// Check for errors, only displaying if the connection hasn't been terminated
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		if ([mySQLConnection isConnected]) {
			
			[[NSAlert alertWithMessageText:@"Unable to flush table" 
							 defaultButton:@"OK" 
						   alternateButton:nil 
							   otherButton:nil 
				 informativeTextWithFormat:[NSString stringWithFormat:@"An error occurred while trying to flush the table '%@'. Please try again.\n\n%@", [self table], [mySQLConnection getLastErrorMessage]]] 
				  beginSheetModalForWindow:tableWindow 
							 modalDelegate:self 
							didEndSelector:NULL 
						       contextInfo:NULL];			
		}
		
		return;
	}
		
	[[NSAlert alertWithMessageText:[NSString stringWithFormat:@"Flush table '%@'", [self table]] 
					 defaultButton:@"OK" 
				   alternateButton:nil 
					   otherButton:nil 
		 informativeTextWithFormat:@"Table was successfully flushed"] 
		  beginSheetModalForWindow:tableWindow 
					 modalDelegate:self 
					didEndSelector:NULL 
					   contextInfo:NULL];
}

/**
 * Runs a MySQL checksum on the selected table and present the result to the user via an alert sheet.
 */
- (IBAction)checksumTable:(id)sender
{	
	MCPResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"CHECKSUM TABLE %@", [[self table] backtickQuotedString]]];
	
	// Check for errors, only displaying if the connection hasn't been terminated
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		if ([mySQLConnection isConnected]) {
			
			[[NSAlert alertWithMessageText:@"Unable to perform checksum" 
							 defaultButton:@"OK" 
						   alternateButton:nil 
							   otherButton:nil 
				 informativeTextWithFormat:[NSString stringWithFormat:@"An error occurred while performing the checksum on table '%@'. Please try again.\n\n%@", [self table], [mySQLConnection getLastErrorMessage]]] 
				  beginSheetModalForWindow:tableWindow 
							 modalDelegate:self 
							didEndSelector:NULL 
							   contextInfo:NULL];			
		}
		return;
	}
	
	// Process result
	NSString *result = [[[theResult fetch2DResultAsType:MCPTypeDictionary] lastObject] objectForKey:@"Checksum"];
	
	[[NSAlert alertWithMessageText:[NSString stringWithFormat:@"Checksum table '%@'", [self table]] 
					 defaultButton:@"OK" 
				   alternateButton:nil 
					   otherButton:nil 
		 informativeTextWithFormat:[NSString stringWithFormat:@"Table checksum: %@", result]] 
		  beginSheetModalForWindow:tableWindow 
					 modalDelegate:self 
					didEndSelector:NULL 
					   contextInfo:NULL];		
}

#pragma mark -
#pragma mark Other Methods

/**
 * Invoked when user hits the cancel button or close button in
 * dialogs such as the variableSheet or the createTableSyntaxSheet
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp stopModalWithCode:0];
}

/**
 * Invoked when user dismisses the error sheet displayed as a result of the current connection being lost.
 */
- (IBAction)closeErrorConnectionSheet:(id)sender
{
	[NSApp stopModalWithCode:[sender tag]];
}

/**
 * Passes query to tablesListInstance
 */
- (void)doPerformQueryService:(NSString *)query
{
	[tableWindow makeKeyAndOrderFront:self];
	[tablesListInstance doPerformQueryService:query];
}

/**
 * Flushes the mysql privileges
 */
- (void)flushPrivileges:(id)sender
{
	[mySQLConnection queryString:@"FLUSH PRIVILEGES"];
	
	if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
		//flushed privileges without errors
		NSBeginAlertSheet(NSLocalizedString(@"Flushed Privileges", @"title of panel when successfully flushed privs"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil, NSLocalizedString(@"Successfully flushed privileges.", @"message of panel when successfully flushed privs"));
	} else {
		//error while flushing privileges
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil, [NSString stringWithFormat:NSLocalizedString(@"Couldn't flush privileges.\nMySQL said: %@", @"message of panel when flushing privs failed"),
																																					  [mySQLConnection getLastErrorMessage]]);
	}
}

/**
 * Shows the MySQL server variables
 */
- (void)showVariables:(id)sender
{
	MCPResult *theResult;
	NSMutableArray *tempResult = [NSMutableArray array];
	int i;
	
	if ( variables ) {
		[variables release];
		variables = nil;
	}
	//get variables
	theResult = [mySQLConnection queryString:@"SHOW VARIABLES"];
	if ([theResult numOfRows]) [theResult dataSeek:0];
	for ( i = 0 ; i < [theResult numOfRows] ; i++ ) {
		[tempResult addObject:[theResult fetchRowAsDictionary]];
	}
	variables = [[NSArray arrayWithArray:tempResult] retain];
	[variablesTableView reloadData];
	//show variables sheet
	[NSApp beginSheet:variablesSheet
	   modalForWindow:tableWindow modalDelegate:self
	   didEndSelector:nil contextInfo:nil];
	[NSApp runModalForWindow:variablesSheet];
	
	[NSApp endSheet:variablesSheet];
	[variablesSheet orderOut:nil];
}

- (void)closeConnection
{
	[mySQLConnection disconnect];

    // Disconnected Growl notification
    [[SPGrowlController sharedGrowlController] notifyWithTitle:@"Disconnected" 
                                                   description:[NSString stringWithFormat:NSLocalizedString(@"Disconnected from %@",@"description for disconnected growl notification"), [tableWindow title]] 
                                              notificationName:@"Disconnected"];
}

/**
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	if ([keyPath isEqualToString:@"ConsoleEnableLogging"]) {
		[mySQLConnection setDelegateQueryLogging:[[change objectForKey:NSKeyValueChangeNewKey] boolValue]];
	}
}

#pragma mark -
#pragma mark Getter methods

/**
 * Returns the host
 */
- (NSString *)host
{
	if ([connectionController type] == SP_CONNECTION_SOCKET) return @"localhost";
	NSString *theHost = [connectionController host];
	if (!theHost) theHost = @"";
	return theHost;
}

/**
 * Returns the name
 */
- (NSString *)name
{
	if ([connectionController name] && [[connectionController name] length]) {
		return [connectionController name];
	}
	if ([connectionController type] == SP_CONNECTION_SOCKET) {
		return [NSString stringWithFormat:@"%@@localhost", [connectionController user]?[connectionController user]:@""];
	}
	return [NSString stringWithFormat:@"%@@%@", [connectionController user]?[connectionController user]:@"", [connectionController host]?[connectionController host]:@""];
}

/**
 * Returns the currently selected database
 */
- (NSString *)database
{
	return selectedDatabase;
}

/**
 * Returns the currently selected table (passing the request to TablesList)
 */
- (NSString *)table
{
	return [tablesListInstance tableName];
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

#pragma mark -
#pragma mark Notification center methods

/**
 * Invoked before a query is performed
 */
- (void)willPerformQuery:(NSNotification *)notification
{
	// Only start the progress indicator if this document window is key. 
	// Because we are starting the progress indicator based on the notification
	// of a query being started, we have to prevent other windows from 
	// starting theirs. The same is also true for the below hasPerformedQuery:
	// method.
	//
	// This code should be removed. Updating user interface elements based on 
	// notifications is bad practice as notifications are global to the application.
	if ([tableWindow isKeyWindow]) {
		[queryProgressBar startAnimation:self];
	}
}

/**
 * Invoked after a query has been performed
 */
- (void)hasPerformedQuery:(NSNotification *)notification
{
	if ([tableWindow isKeyWindow]) {
		[queryProgressBar stopAnimation:self];
	}
}

/**
 * Invoked when the application will terminate
 */
- (void)applicationWillTerminate:(NSNotification *)notification
{
	[tablesListInstance selectionShouldChangeInTableView:nil];
}

#pragma mark -
#pragma mark Menu methods

/**
 * Passes the request to the tableDump object
 */
- (IBAction)import:(id)sender
{
	[tableDumpInstance importFile];
}

/**
 * Passes the request to the tableDump object
 */
- (IBAction)export:(id)sender
{
	if ([sender tag] == -1) {
		//[tableDumpInstance export];
		
		[spExportControllerInstance export];
	} else {
		[tableDumpInstance exportFile:[sender tag]];
	}
}

- (IBAction)exportTable:(id)sender
{
	return [self export:sender];
}

- (IBAction)exportMultipleTables:(id)sender
{
	return [self export:sender];
}

/*
 * Show the MySQL Help TOC of the current MySQL connection
 * Invoked by the MainMenu > Help > MySQL Help
 */
- (IBAction)showMySQLHelp:(id)sender
{
	[customQueryInstance showHelpFor:SP_HELP_TOC_SEARCH_STRING addToHistory:YES];
	[[customQueryInstance helpWebViewWindow] makeKeyWindow];
}

/**
 * Saves the server variables to the selected file.
 */
- (IBAction)saveServerVariables:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setRequiredFileType:@"cnf"];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:YES];
	[panel setCanSelectHiddenExtension:YES];
	
	[panel beginSheetForDirectory:nil file:@"Variables" modalForWindow:variablesSheet modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

/**
 * Menu validation
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (!_isConnected) {
		if ([menuItem action] == @selector(newDocument:) ||
			[menuItem action] == @selector(terminate:))
		{
			return YES;
		} else {
			return NO;
		}
	}
	if ([menuItem action] == @selector(import:) ||
		[menuItem action] == @selector(export:) ||
		[menuItem action] == @selector(exportMultipleTables:) ||
		[menuItem action] == @selector(removeDatabase:))
	{
		return ([self database] != nil);
	}
	
	if ([menuItem action] == @selector(exportTable:))
	{
		return ([self database] != nil && [self table] != nil);
	}
	
	if ([menuItem action] == @selector(chooseEncoding:)) {
		return [self supportsEncoding];
	}
	
	// table menu items
	if ([menuItem action] == @selector(showCreateTableSyntax:) ||
		[menuItem action] == @selector(copyCreateTableSyntax:) ||
		[menuItem action] == @selector(checkTable:) || 
		[menuItem action] == @selector(analyzeTable:) || 
		[menuItem action] == @selector(optimizeTable:) || 
		[menuItem action] == @selector(repairTable:) || 
		[menuItem action] == @selector(flushTable:) ||
		[menuItem action] == @selector(checksumTable:)) 
	{
		return ([self table] != nil && [[self table] isNotEqualTo:@""]);
	}
	
	if ([menuItem action] == @selector(addConnectionToFavorites:)) {
		return ([connectionController selectedFavorite]?NO:YES);
	}
	
	return [super validateMenuItem:menuItem];
}

- (IBAction)viewStructure:(id)sender
{
	// Cancel the selection if currently editing a content row and unable to save
	if ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 1
		&& ![tableContentInstance saveRowOnDeselect]) {
		[mainToolbar setSelectedItemIdentifier:@"SwitchToTableContentToolbarItemIdentifier"];
		return;
	}

	[tableTabView selectTabViewItemAtIndex:0];
	[mainToolbar setSelectedItemIdentifier:@"SwitchToTableStructureToolbarItemIdentifier"];
	[spHistoryControllerInstance updateHistoryEntries];
}

- (IBAction)viewContent:(id)sender
{
	// Cancel the selection if currently editing structure/a field and unable to save
	if ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 0
		&& ![tableSourceInstance saveRowOnDeselect]) {
		[mainToolbar setSelectedItemIdentifier:@"SwitchToTableStructureToolbarItemIdentifier"];
		return;
	}

	[tableTabView selectTabViewItemAtIndex:1];
	[mainToolbar setSelectedItemIdentifier:@"SwitchToTableContentToolbarItemIdentifier"];
	[spHistoryControllerInstance updateHistoryEntries];
}

- (IBAction)viewQuery:(id)sender
{
	// Cancel the selection if currently editing structure/a field and unable to save
	if ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 0
		&& ![tableSourceInstance saveRowOnDeselect]) {
		[mainToolbar setSelectedItemIdentifier:@"SwitchToTableStructureToolbarItemIdentifier"];
		return;
	}

	// Cancel the selection if currently editing a content row and unable to save
	if ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 1
		&& ![tableContentInstance saveRowOnDeselect]) {
		[mainToolbar setSelectedItemIdentifier:@"SwitchToTableContentToolbarItemIdentifier"];
		return;
	}

	[tableTabView selectTabViewItemAtIndex:2];
	[mainToolbar setSelectedItemIdentifier:@"SwitchToRunQueryToolbarItemIdentifier"];
	[spHistoryControllerInstance updateHistoryEntries];

	// Set the focus on the text field if no query has been run
	if (![[customQueryTextView string] length]) [tableWindow makeFirstResponder:customQueryTextView];
}

- (IBAction)viewStatus:(id)sender
{
	// Cancel the selection if currently editing structure/a field and unable to save
	if ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 0
		&& ![tableSourceInstance saveRowOnDeselect]) {
		[mainToolbar setSelectedItemIdentifier:@"SwitchToTableStructureToolbarItemIdentifier"];
		return;
	}

	// Cancel the selection if currently editing a content row and unable to save
	if ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 1
		&& ![tableContentInstance saveRowOnDeselect]) {
		[mainToolbar setSelectedItemIdentifier:@"SwitchToTableContentToolbarItemIdentifier"];
		return;
	}

	[tableTabView selectTabViewItemAtIndex:3];
	[mainToolbar setSelectedItemIdentifier:@"SwitchToTableInfoToolbarItemIdentifier"];
	[spHistoryControllerInstance updateHistoryEntries];
}

- (IBAction)viewRelations:(id)sender
{
	// Cancel the selection if currently editing structure/a field and unable to save
	if ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 0
		&& ![tableSourceInstance saveRowOnDeselect]) {
		[mainToolbar setSelectedItemIdentifier:@"SwitchToTableStructureToolbarItemIdentifier"];
		return;
	}
	
	// Cancel the selection if currently editing a content row and unable to save
	if ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == 1
		&& ![tableContentInstance saveRowOnDeselect]) {
		[mainToolbar setSelectedItemIdentifier:@"SwitchToTableContentToolbarItemIdentifier"];
		return;
	}
	
	[tableTabView selectTabViewItemAtIndex:4];
	[mainToolbar setSelectedItemIdentifier:@"SwitchToTableRelationsToolbarItemIdentifier"];
	[spHistoryControllerInstance updateHistoryEntries];
}


/**
 * Adds the current database connection details to the user's favorites if it doesn't already exist.
 */
- (IBAction)addConnectionToFavorites:(id)sender
{
	// Obviously don't add if it already exists. We shouldn't really need this as the menu item validation
	// enables or disables the menu item based on the same method. Although to be safe do the check anyway
	// as we don't know what's calling this method.
	if ([connectionController selectedFavorite]) {
		return;
	}
	
	// Request the connection controller to add its details to favorites
	[connectionController addFavorite:self];
}

/**
 * Called when the NSSavePanel sheet ends. Writes the server variables to the selected file if required.
 */
- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		if (variables) {
			NSMutableString *variablesString = [NSMutableString stringWithFormat:@"# MySQL server variables for %@\n\n", [self host]];
			
			for (NSDictionary *variable in variables) 
			{
				[variablesString appendString:[NSString stringWithFormat:@"%@ = %@\n", [variable objectForKey:@"Variable_name"], [variable objectForKey:@"Value"]]];
			}
			
			[variablesString writeToFile:[sheet filename] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
		}
	}
}

/*
 * Return the createTableSyntaxWindow
 */
- (NSWindow *)getCreateTableSyntaxWindow
{
	return createTableSyntaxWindow;
}

#pragma mark -
#pragma mark Titlebar Methods

/**
 * Set the connection status icon in the titlebar
 */
- (void)setStatusIconToImageWithName:(NSString *)imageName
{
	NSString *imagePath = [[NSBundle mainBundle] pathForResource:imageName ofType:@"png"];
	if (!imagePath) return;

	NSImage *image = [[[NSImage alloc] initByReferencingFile:imagePath] autorelease];
	[titleImageView setImage:image];
}

- (void)setTitlebarStatus:(NSString *)status
{
	[self clearStatusIcon];
	[titleStringView setStringValue:status];
}

/**
 * Clear the connection status icon in the titlebar
 */
- (void)clearStatusIcon
{
	[titleImageView setImage:nil];
}





#pragma mark -
#pragma mark Toolbar Methods

/**
 * set up the standard toolbar
 */
- (void)setupToolbar
{
	// create a new toolbar instance, and attach it to our document window 
	mainToolbar = [[[NSToolbar alloc] initWithIdentifier:@"TableWindowToolbar"] autorelease];
	
	// set up toolbar properties
	[mainToolbar setAllowsUserCustomization:YES];
	[mainToolbar setAutosavesConfiguration:YES];
	[mainToolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
	
	// set ourself as the delegate
	[mainToolbar setDelegate:self];
	
	// attach the toolbar to the document window
	[tableWindow setToolbar:mainToolbar];

	// update the toolbar item size
	[self updateChooseDatabaseToolbarItemWidth];
}

/**
 * toolbar delegate method
 */
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)willBeInsertedIntoToolbar
{
	NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
	
	if ([itemIdentifier isEqualToString:@"DatabaseSelectToolbarItemIdentifier"]) {
		[toolbarItem setLabel:NSLocalizedString(@"Select Database", @"toolbar item for selecting a db")];
		[toolbarItem setPaletteLabel:[toolbarItem label]];
		[toolbarItem setView:chooseDatabaseButton];
		[toolbarItem setMinSize:NSMakeSize(200,26)];
		[toolbarItem setMaxSize:NSMakeSize(200,32)];
		[chooseDatabaseButton setTarget:self];
		[chooseDatabaseButton setAction:@selector(chooseDatabase:)];
		
		if (willBeInsertedIntoToolbar) {
			chooseDatabaseToolbarItem = toolbarItem;
			[self updateChooseDatabaseToolbarItemWidth];
		} 

	} else if ([itemIdentifier isEqualToString:@"HistoryNavigationToolbarItemIdentifier"]) {
		[toolbarItem setLabel:NSLocalizedString(@"Table History", @"toolbar item for navigation history")];
		[toolbarItem setPaletteLabel:[toolbarItem label]];
		[toolbarItem setView:historyControl];

	} else if ([itemIdentifier isEqualToString:@"ShowConsoleIdentifier"]) {
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Show Console", @"toolbar item for show console")];
		[toolbarItem setToolTip:NSLocalizedString(@"Show the console which shows all MySQL commands performed by Sequel Pro", @"tooltip for toolbar item for show console")];
		
		[toolbarItem setLabel:NSLocalizedString(@"Console", @"Console")];
		[toolbarItem setImage:[NSImage imageNamed:@"hideconsole"]];
		
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(showConsole:)];
		
	} else if ([itemIdentifier isEqualToString:@"ClearConsoleIdentifier"]) {
		//set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel:NSLocalizedString(@"Clear Console", @"toolbar item for clear console")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Clear Console", @"toolbar item for clear console")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Clear the console which shows all MySQL commands performed by Sequel Pro", @"tooltip for toolbar item for clear console")];
		[toolbarItem setImage:[NSImage imageNamed:@"clearconsole"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(clearConsole:)];
		
	} else if ([itemIdentifier isEqualToString:@"SwitchToTableStructureToolbarItemIdentifier"]) {
		[toolbarItem setLabel:NSLocalizedString(@"Structure", @"toolbar item label for switching to the Table Structure tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Edit Table Structure", @"toolbar item label for switching to the Table Structure tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the Table Structure tab", @"tooltip for toolbar item for switching to the Table Structure tab")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar-switch-to-structure"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(viewStructure:)];
		
	} else if ([itemIdentifier isEqualToString:@"SwitchToTableContentToolbarItemIdentifier"]) {
		[toolbarItem setLabel:NSLocalizedString(@"Content", @"toolbar item label for switching to the Table Content tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Browse & Edit Table Content", @"toolbar item label for switching to the Table Content tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the Table Content tab", @"tooltip for toolbar item for switching to the Table Content tab")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar-switch-to-browse"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(viewContent:)];
		
	} else if ([itemIdentifier isEqualToString:@"SwitchToRunQueryToolbarItemIdentifier"]) {
		[toolbarItem setLabel:NSLocalizedString(@"Query", @"toolbar item label for switching to the Run Query tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Run Custom Query", @"toolbar item label for switching to the Run Query tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the Run Query tab", @"tooltip for toolbar item for switching to the Run Query tab")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar-switch-to-sql"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(viewQuery:)];
		
	} else if ([itemIdentifier isEqualToString:@"SwitchToTableInfoToolbarItemIdentifier"]) {
		[toolbarItem setLabel:NSLocalizedString(@"Table Info", @"toolbar item label for switching to the Table Info tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Table Info", @"toolbar item label for switching to the Table Info tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the Table Info tab", @"tooltip for toolbar item for switching to the Table Info tab")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar-switch-to-table-info"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(viewStatus:)];

	} else if ([itemIdentifier isEqualToString:@"SwitchToTableRelationsToolbarItemIdentifier"]) {
		[toolbarItem setLabel:NSLocalizedString(@"Relations", @"toolbar item label for switching to the Table Relations tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Table Relations", @"toolbar item label for switching to the Table Relations tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the Table Relations tab", @"tooltip for toolbar item for switching to the Table Relations tab")];
		[toolbarItem setImage:[NSImage imageNamed:@"toolbar-switch-to-table-relations"]];
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(viewRelations:)];
		
	} else if ([itemIdentifier isEqualToString:@"SwitchToUserManagerToolbarItemIdentifier"]) {
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

/**
 * toolbar delegate method
 */
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
	return [NSArray arrayWithObjects:
			@"DatabaseSelectToolbarItemIdentifier",
			@"HistoryNavigationToolbarItemIdentifier",
			@"ShowConsoleIdentifier",
			@"ClearConsoleIdentifier",
			@"FlushPrivilegesIdentifier",
			@"SwitchToTableStructureToolbarItemIdentifier",
			@"SwitchToTableContentToolbarItemIdentifier",
			@"SwitchToRunQueryToolbarItemIdentifier",
			@"SwitchToTableInfoToolbarItemIdentifier",
			@"SwitchToTableRelationsToolbarItemIdentifier",
			@"SwitchToUserManagerToolbarItemIdentifier",
			NSToolbarCustomizeToolbarItemIdentifier,
			NSToolbarFlexibleSpaceItemIdentifier,
			NSToolbarSpaceItemIdentifier,
			NSToolbarSeparatorItemIdentifier,
			nil];
}

/**
 * toolbar delegate method
 */
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
	return [NSArray arrayWithObjects:
			@"DatabaseSelectToolbarItemIdentifier",
			@"SwitchToTableStructureToolbarItemIdentifier",
			@"SwitchToTableContentToolbarItemIdentifier",
			@"SwitchToTableRelationsToolbarItemIdentifier",
			@"SwitchToTableInfoToolbarItemIdentifier",
			@"SwitchToRunQueryToolbarItemIdentifier",
			NSToolbarFlexibleSpaceItemIdentifier,
			@"HistoryNavigationToolbarItemIdentifier",
			@"SwitchToUserManagerToolbarItemIdentifier",			
			@"ShowConsoleIdentifier",
			nil];
}

/**
 * toolbar delegate method
 */
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:
			@"SwitchToTableStructureToolbarItemIdentifier",
			@"SwitchToTableContentToolbarItemIdentifier",
			@"SwitchToRunQueryToolbarItemIdentifier",
			@"SwitchToTableInfoToolbarItemIdentifier",
			@"SwitchToTableRelationsToolbarItemIdentifier",
			nil];
	
}

/**
 * Validates the toolbar items
 */
- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem;
{
	if (!_isConnected) return NO;

	NSString *identifier = [toolbarItem itemIdentifier];
	
	// Show console item
	if ([identifier isEqualToString:@"ShowConsoleIdentifier"]) {
		if ([[[SPQueryConsole sharedQueryConsole] window] isVisible]) {
			[toolbarItem setImage:[NSImage imageNamed:@"showconsole"]];
		} else {
			[toolbarItem setImage:[NSImage imageNamed:@"hideconsole"]];
		}
		if ([[[SPQueryConsole sharedQueryConsole] window] isKeyWindow]) {
			return NO;
		} else {
			return YES;
		}
	}
	
	// Clear console item
	if ([identifier isEqualToString:@"ClearConsoleIdentifier"]) {
		return ([[SPQueryConsole sharedQueryConsole] consoleMessageCount] > 0);
	}
	
	return YES;
}

#pragma mark -
#pragma mark NSDocument methods

/**
 * Returns the name of the nib file
 */
- (NSString *)windowNibName
{
	return @"DBView";
}

/**
 * Code that need to be executed once the windowController has loaded the document's window
 * sets upt the interface (small fonts).
 */
- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
	[aController setShouldCascadeWindows:YES];
	[super windowControllerDidLoadNib:aController];
	
	NSEnumerator *theCols = [[variablesTableView tableColumns] objectEnumerator];
	NSTableColumn *theCol;
	
	//register for notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willPerformQuery:)
												 name:@"SMySQLQueryWillBePerformed" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hasPerformedQuery:)
												 name:@"SMySQLQueryHasBeenPerformed" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)
												 name:@"NSApplicationWillTerminateNotification" object:nil];
	
	//set up interface
	if ( [prefs boolForKey:@"UseMonospacedFonts"] ) {
		[[SPQueryConsole sharedQueryConsole] setConsoleFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
		[syntaxViewContent setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
		
		while ( (theCol = [theCols nextObject]) ) {
			[[theCol dataCell] setFont:[NSFont fontWithName:@"Monaco" size:10]];
		}
	} else {
		[[SPQueryConsole sharedQueryConsole] setConsoleFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		[syntaxViewContent setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		while ( (theCol = [theCols nextObject]) ) {
			[[theCol dataCell] setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}
	}
}

// NSWindow delegate methods

/**
 * Invoked when the document window is about to close
 */
- (void)windowWillClose:(NSNotification *)aNotification
{
	[mySQLConnection setDelegate:nil];
	if ([mySQLConnection isConnected]) [self closeConnection];
	if ([[[SPQueryConsole sharedQueryConsole] window] isVisible]) [self toggleConsole:self];
	[createTableSyntaxWindow orderOut:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

/**
 * Invoked when the document window should close
 */
- (BOOL)windowShouldClose:(id)sender
{
	if ( ![tablesListInstance selectionShouldChangeInTableView:nil] ) {
		return NO;
	} else {
		return YES;
	}
}

/**
 * Don't show the document "changed" dot in the close button, or show a
 * "save?" dialog when closing the document.
 */
- (BOOL)isDocumentEdited
{
	return NO;
}

/**
 * The window title for this document.
 */
- (NSString *)displayName
{
	if (!_isConnected) return @"Connecting...";
	
	return [NSString stringWithFormat:@"(MySQL %@) %@/%@", mySQLVersion, [self name], ([self database]?[self database]:@"")];
}


#pragma mark -
#pragma mark MCPKit connection delegate methods

/**
 * Invoked when the framework is about to perform a query.
 */
- (void)willQueryString:(NSString *)query connection:(id)connection
{		
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ConsoleEnableLogging"]) {
		[[SPQueryConsole sharedQueryConsole] showMessageInConsole:query];
	}
}

/**
 * Invoked when the query just executed by the framework resulted in an error. 
 */
- (void)queryGaveError:(NSString *)error connection:(id)connection
{	
	[[SPQueryConsole sharedQueryConsole] showErrorInConsole:error];
}

/**
 * Invoked when the framework is in the process of reconnecting to the server and needs to know 
 * which database to select.
 */
- (NSString *)onReconnectShouldSelectDatabase:(id)connection
{
	return selectedDatabase;
}

/**
 * Invoked when the framework is in the process of reconnecting to the server and needs to know 
 * what encoding to use for the connection.
 */
- (NSString *)onReconnectShouldUseEncoding:(id)connection
{
	return _encoding;
}

/**
 * Invoked when the current connection needs a password from the Keychain.
 */
- (NSString *)keychainPasswordForConnection:(MCPConnection *)connection
{	
	KeyChain *keychain = [[KeyChain alloc] init];
	
	NSString *password = [keychain getPasswordForName:[connectionController connectionKeychainItemName] account:[connectionController connectionKeychainItemAccount]];
	
	[keychain release];
		
	return password;
}

/**
 * Invoked when the connection fails and the framework needs to know how to proceed.
 */
- (MCPConnectionCheck)connectionLost:(id)connection
{
	[NSApp beginSheet:connectionErrorDialog modalForWindow:tableWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	int connectionErrorCode = [NSApp runModalForWindow:connectionErrorDialog];

	[NSApp endSheet:connectionErrorDialog];
	[connectionErrorDialog orderOut:nil];

	// If "disconnect" was selected, trigger a window close.
	if (connectionErrorCode == 2) {
		[self windowWillClose:nil];
		if (connectionErrorCode == MCPConnectionCheckDisconnect) 
			[tableWindow performSelector:@selector(close) withObject:nil afterDelay:0.0];
	}

	return connectionErrorCode;
}

#pragma mark -
#pragma mark Database name field delegate methods

/**
 * When adding a database, enable the button only if the new name has a length.
 */
- (void)controlTextDidChange:(NSNotification *)aNotification
{
	if ([aNotification object] == databaseNameField) {
		[addDatabaseButton setEnabled:([[databaseNameField stringValue] length] > 0)]; 
	}
}

#pragma mark -
#pragma mark SplitView delegate methods

/**
 * tells the splitView that it can collapse views
 */
- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{

	return subview == [[tableInfoTable superview] superview];
}

/**
 * defines max position of splitView
 */
//- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
//{
//	if (sender == contentViewSplitter) {
//		return 300;
//	} else {
//		// 
//		return proposedMax;//([tableInfoTable rowHeight] * [tableInfoTable numberOfRows] + 25);
//	}
//}

/**
 * defines min position of splitView
 */
//- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
//{
//	if (sender == tableListSplitter) {
//		return [sender frame].size.height - [sender dividerThickness] - 145;
//		//return [sender frame].size.height - [sender dividerThickness] - ([tableInfoTable rowHeight] * [tableInfoTable numberOfRows] + 25);
//	} else {
//		return 160;
//	}
//}

//-(void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
//{
//	[sender adjustSubviews];
//	
//	if (sender == tableListSplitter && 
//		![tableListSplitter isSubviewCollapsed:[[sender subviews] objectAtIndex:1]]) {
//		
//		CGFloat dividerThickness = [sender dividerThickness];
//		NSRect topRect = [[[sender subviews] objectAtIndex:0] frame];
//		NSRect bottomRect = [[[sender subviews] objectAtIndex:1] frame];
//		NSRect newFrame = [sender frame];
//		
//		topRect.size.height = newFrame.size.height - 145 - dividerThickness;
//		topRect.size.width = newFrame.size.width;
//		topRect.origin = NSMakePoint(0, 0);
//		
//		bottomRect.size.height = newFrame.size.height - topRect.size.height - dividerThickness;
//		bottomRect.size.width = newFrame.size.width;
//		bottomRect.origin.y = topRect.size.height + dividerThickness;
//		
//		[[[sender subviews] objectAtIndex:0] setFrame:topRect];
//		[[[sender subviews] objectAtIndex:1] setFrame:bottomRect];
//	}
//}


//- (BOOL)splitView:(NSSplitView *)splitView shouldHideDividerAtIndex:(NSInteger)dividerIndex
//{
//	return splitView == tableListSplitter;
//}

- (void)splitViewDidResizeSubviews:(NSNotification *)notification
{
	[self updateChooseDatabaseToolbarItemWidth];
}

- (NSRect)splitView:(NSSplitView *)splitView additionalEffectiveRectOfDividerAtIndex:(int)dividerIndex
{
	if (sidebarGrabber != nil) {
		return [sidebarGrabber convertRect:[sidebarGrabber bounds] toView:splitView];
	} else {
		return NSZeroRect;
	}
}

- (void)updateChooseDatabaseToolbarItemWidth
{
	// make sure the toolbar item is actually in the toolbar
	if (!chooseDatabaseToolbarItem)
		return;
	
	// grab the width of the left pane
	float leftPaneWidth = [[[contentViewSplitter subviews] objectAtIndex:0] frame].size.width;
	
	// subtract some pixels to allow for misc stuff
	leftPaneWidth -= 12;
	
	// make sure it's not too small or to big
	if (leftPaneWidth < 130)
		leftPaneWidth = 130;
	if (leftPaneWidth > 360)
		leftPaneWidth = 360;
	
	// apply the size
	[chooseDatabaseToolbarItem setMinSize:NSMakeSize(leftPaneWidth, 26)];
	[chooseDatabaseToolbarItem setMaxSize:NSMakeSize(leftPaneWidth, 32)];
}

#pragma mark -
#pragma mark TableView datasource methods

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [variables count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	id theValue;
	
	theValue = [[variables objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
	
	if ( [theValue isKindOfClass:[NSData class]] ) {
		theValue = [[NSString alloc] initWithData:theValue encoding:[mySQLConnection encoding]];
		if (theValue == nil) {
			[[NSString alloc] initWithData:theValue encoding:NSASCIIStringEncoding];
		}
		if (theValue) [theValue autorelease];
	}
	
	return theValue;
}

- (void)dealloc
{
	[_encoding release];
	[printWebView release];
	if (connectionController) [connectionController release];
	if (mySQLConnection) [mySQLConnection release];
	if (variables) [variables release];
	if (selectedDatabase) [selectedDatabase release];
	if (mySQLVersion) [mySQLVersion release];
	[allDatabases release];
	[super dealloc];
}
		
- (void)showUserManager:(id)sender
{
	if (userManagerInstance == nil)
	{
		userManagerInstance = [[SPUserManager alloc] initWithConnection:mySQLConnection];
	} else {
		[userManagerInstance show];
	}
}

@end