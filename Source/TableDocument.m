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
#import "KeyChain.h"
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
#import "SPQueryConsole.h"
#import "CMMCPConnection.h"
#import "CMMCPResult.h"
#import "MainController.h"
#import "SPExtendedTableInfo.h"
#import "SPPreferenceController.h"

// Used for printing
#import "MGTemplateEngine.h"
#import "ICUTemplateMatcher.h"

NSString *TableDocumentFavoritesControllerSelectionIndexDidChange = @"TableDocumentFavoritesControllerSelectionIndexDidChange";

@interface TableDocument (PrivateAPI)

- (BOOL)_favoriteAlreadyExists:(NSString *)database host:(NSString *)host user:(NSString *)user;

@end

@implementation TableDocument

- (id)init
{
	if ((self = [super init])) {
		
		_encoding = [@"utf8" retain];
		chooseDatabaseButton = nil;
		chooseDatabaseToolbarItem = nil;
		
		printWebView = [[WebView alloc] init];
		[printWebView setFrameLoadDelegate:self];
		
		prefs = [NSUserDefaults standardUserDefaults];
	}
		
	return self;
}

- (void)awakeFromNib
{
	// Register selection did change handler for favorites controller (used in connect sheet)
	[favoritesController addObserver:self forKeyPath:@"selectionIndex" options:NSKeyValueChangeInsertion context:TableDocumentFavoritesControllerSelectionIndexDidChange];
	
	// Register observers for when the DisplayTableViewVerticalGridlines preference changes
	[prefs addObserver:tableSourceInstance forKeyPath:@"DisplayTableViewVerticalGridlines" options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:tableContentInstance forKeyPath:@"DisplayTableViewVerticalGridlines" options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:customQueryInstance forKeyPath:@"DisplayTableViewVerticalGridlines" options:NSKeyValueObservingOptionNew context:NULL];
	
	// Register double click for the favorites view (double click favorite to connect)
	[connectFavoritesTableView setTarget:self];
	[connectFavoritesTableView setDoubleAction:@selector(connect:)];
	
	// Find the Database -> Database Encoding menu (it's not in our nib, so we can't use interface builder)
	selectEncodingMenu = [[[[[NSApp mainMenu] itemWithTag:1] submenu] itemWithTag:1] submenu];
	
	// Hide the tabs in the tab view (we only show them to allow switching tabs in interface builder)
	[tableTabView setTabViewType:NSNoTabsNoBorder];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == TableDocumentFavoritesControllerSelectionIndexDidChange) {
		[self chooseFavorite:self];
		return;
	}

	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

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
	if([[portField stringValue] length])
		[connection setValue:[portField stringValue] forKey:@"port"];
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
					[[tableContentInstance currentResult] objectsAtIndexes:
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

	// Process the template and display the results.
	NSString *result = [engine processTemplateInFileAtPath:templatePath withVariables:print_data];
	return result;
}

- (CMMCPConnection *)sharedConnection
{
	return mySQLConnection;
}

//start sheet

/**
 * Set whether the connection sheet should automaticall start connecting
 */
- (void)setShouldAutomaticallyConnect:(BOOL)shouldAutomaticallyConnect
{
	_shouldOpenConnectionAutomatically = shouldAutomaticallyConnect;
}

/**
 * tries to connect to a database server, shows connect sheet prompting user to
 * enter details/select favorite and shoows alert sheets on failure.
 */
- (IBAction)connectToDB:(id)sender
{
	
	// load the details of the currently selected favorite into the text boxes in connect sheet
	[self chooseFavorite:self];
	
	// run the connect sheet (modal)
	[NSApp beginSheet:connectSheet
	   modalForWindow:tableWindow
		modalDelegate:self
	   didEndSelector:@selector(connectSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];

	// Connect automatically to the last used or default favourite
	// connectSheet must open first.
	if (_shouldOpenConnectionAutomatically) {
		_shouldOpenConnectionAutomatically = false;
		[self connect:self];
	}
}


/*
 invoked when user hits the connect-button of the connectSheet
 stops modal session with code:
 1 when connected with success
 2 when no connection to host
 3 when no connection to db
 4 when hostField and socketField are empty
 */
- (IBAction)connect:(id)sender
{
	int code;
	
	[connectProgressBar startAnimation:self];
	[connectProgressStatusText setHidden:NO];
	[connectProgressStatusText display];
	
	[selectedDatabase autorelease];
	selectedDatabase = nil;
	
	code = 0;
	if ( [[hostField stringValue] isEqualToString:@""]  && [[socketField stringValue] isEqualToString:@""] ) {
		code = 4;
	} else {
		if ( ![[socketField stringValue] isEqualToString:@""] ) {
			//connect to socket
			mySQLConnection = [[CMMCPConnection alloc] initToSocket:[socketField stringValue]
														  withLogin:[userField stringValue]
														   password:[passwordField stringValue]];
			[hostField setStringValue:@"localhost"];
		} else {
			//connect to host
			mySQLConnection = [[CMMCPConnection alloc] initToHost:[hostField stringValue]
														withLogin:[userField stringValue]
														 password:[passwordField stringValue]
														usingPort:[portField intValue]];
		}
		[mySQLConnection setParentWindow:tableWindow];

		if ( ![mySQLConnection isConnected] )
			code = 2;
		if ( !code && ![[databaseField stringValue] isEqualToString:@""] ) {
			if ([mySQLConnection selectDB:[databaseField stringValue]]) {
				selectedDatabase = [[databaseField stringValue] retain];
			} else {
				code = 3;
			}
		}
		if ( !code )
			code = 1;
	}
	
	// close sheet
	[connectSheet orderOut:nil];
	[NSApp endSheet:connectSheet returnCode:code];	
	[connectProgressBar stopAnimation:self];
	[connectProgressStatusText setHidden:YES];
}

-(void)connectSheetDidEnd:(NSWindow*)sheet returnCode:(int)code contextInfo:(void*)contextInfo
{
	[sheet orderOut:self];
	
	CMMCPResult *theResult;
	id version;
	
	if ( code == 1) {
		//connected with success
		//register as delegate
		[mySQLConnection setDelegate:self];
		// set encoding
		NSString *encodingName = [prefs objectForKey:@"DefaultEncoding"];
		if ( [encodingName isEqualToString:@"Autodetect"] ) {
			[self setConnectionEncoding:[self databaseEncoding] reloadingViews:NO];
		} else {
			[self setConnectionEncoding:[self mysqlEncodingFromDisplayEncoding:encodingName] reloadingViews:NO];
		}
		//get mysql version
		theResult = [mySQLConnection queryString:@"SHOW VARIABLES LIKE 'version'"];
		version = [[theResult fetchRowAsArray] objectAtIndex:1];
		if ( [version isKindOfClass:[NSData class]] ) {
			// starting with MySQL 4.1.14 the mysql variables are returned as nsdata
			mySQLVersion = [[NSString alloc] initWithData:version encoding:[mySQLConnection encoding]];
		} else {
			mySQLVersion = [[NSString stringWithString:version] retain];
		}
		
		[self setDatabases:self];
		
		// For each of the main controllers assigned the current connection
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
		
		[self setFileName:[NSString stringWithFormat:@"(MySQL %@) %@@%@ %@", mySQLVersion, [userField stringValue],
						   [hostField stringValue], [databaseField stringValue]]];
		[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/%@", mySQLVersion, [self name], [databaseField stringValue]]];
		
		// Connected Growl notification		
        [[SPGrowlController sharedGrowlController] notifyWithTitle:@"Connected"
                                                       description:[NSString stringWithFormat:NSLocalizedString(@"Connected to %@",@"description for connected growl notification"), [tableWindow title]]
                                                  notificationName:@"Connected"];
		
	} else if (code == 2) {
		//can't connect to host
		NSBeginAlertSheet(NSLocalizedString(@"Connection failed!", @"connection failed"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil,
						  @selector(sheetDidEnd:returnCode:contextInfo:), @"connect",
						  [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to host %@, or the request timed out.\n\nBe sure that the address is correct and that you have the necessary privileges, or try increasing the connection timeout (currently %i seconds).\n\nMySQL said: %@", @"message of panel when connection to host failed"), [hostField stringValue], [[prefs objectForKey:@"ConnectionTimeoutValue"] intValue], [mySQLConnection getLastErrorMessage]]);
	} else if (code == 3) {
		//can't connect to db
		NSBeginAlertSheet(NSLocalizedString(@"Connection failed!", @"connection failed"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil,
						  @selector(sheetDidEnd:returnCode:contextInfo:), @"connect",
						  [NSString stringWithFormat:NSLocalizedString(@"Connected to host, but unable to connect to database %@.\n\nBe sure that the database exists and that you have the necessary privileges.\n\nMySQL said: %@", @"message of panel when connection to db failed"), [databaseField stringValue], [mySQLConnection getLastErrorMessage]]);
	} else if (code == 4) {
		//no host is given
		NSBeginAlertSheet(NSLocalizedString(@"Insufficient connection details", @"insufficient details message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil,
						  @selector(sheetDidEnd:returnCode:contextInfo:), @"connect", NSLocalizedString(@"Insufficient details provided to establish a connection. Please provide at least a host or socket.", @"insufficient details informative message"));
	}
	
}

- (IBAction)cancelConnectSheet:(id)sender
{
	[NSApp endSheet:connectSheet];
	[tableWindow close];
}

/**
 * Invoked when user hits the cancel button of the connectSheet
 * stops modal session with code 0
 * reused when user hits the close button of the variablseSheet or of the createTableSyntaxSheet
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp stopModalWithCode:0];
}

/**
 * sets fields for the chosen favorite.
 */
- (IBAction)chooseFavorite:(id)sender
{
	if (![self selectedFavorite])
		return;
	
	[nameField		setStringValue:([self valueForKeyPath:@"selectedFavorite.name"]		? [self valueForKeyPath:@"selectedFavorite.name"]		: @"")];
	[hostField		setStringValue:([self valueForKeyPath:@"selectedFavorite.host"]		? [self valueForKeyPath:@"selectedFavorite.host"]		: @"")];
	[userField		setStringValue:([self valueForKeyPath:@"selectedFavorite.user"]		? [self valueForKeyPath:@"selectedFavorite.user"]		: @"")];
	[passwordField	setStringValue:([self selectedFavoritePassword]						? [self selectedFavoritePassword]						: @"")];
	[databaseField	setStringValue:([self valueForKeyPath:@"selectedFavorite.database"]	? [self valueForKeyPath:@"selectedFavorite.database"]	: @"")];
	[socketField	setStringValue:([self valueForKeyPath:@"selectedFavorite.socket"]	? [self valueForKeyPath:@"selectedFavorite.socket"]		: @"")];
	[portField		setStringValue:([self valueForKeyPath:@"selectedFavorite.port"]		? [self valueForKeyPath:@"selectedFavorite.port"]		: @"")];
	
	[prefs setInteger:[favoritesController selectionIndex] forKey:@"LastFavoriteIndex"];
}

/**
 * Opens the preferences window, or brings it to the front, and switch to the favorites tab.
 * If a favorite is selected in the connection sheet, it is also select in the prefs window.
 */
- (IBAction)editFavorites:(id)sender
{
	SPPreferenceController *prefsController = [[NSApp delegate] preferenceController];
	
	[prefsController showWindow:self];
	[prefsController displayFavoritePreferences:self];
	[prefsController selectFavorites:[favoritesController selectedObjects]];	
}

/**
 * returns a KVC-compliant proxy to the currently selected favorite, or nil if nothing selected.
 * 
 * see [NSObjectController selection]
 */
- (id)selectedFavorite
{
	if ([favoritesController selectionIndex] == NSNotFound)
		return nil;
	
	return [favoritesController selection];
}

/**
 * fetches the password [self selectedFavorite] from the keychain, returns nil if no selection.
 */
- (NSString *)selectedFavoritePassword
{
	if (![self selectedFavorite])
		return nil;
	
	NSString *keychainName = [NSString stringWithFormat:@"Sequel Pro : %@ (%i)", [self valueForKeyPath:@"selectedFavorite.name"], [[self valueForKeyPath:@"selectedFavorite.id"] intValue]];
	NSString *keychainAccount = [NSString stringWithFormat:@"%@@%@/%@",
								 [self valueForKeyPath:@"selectedFavorite.user"],
								 [self valueForKeyPath:@"selectedFavorite.host"],
								 [self valueForKeyPath:@"selectedFavorite.database"]];
	
	return [keyChainInstance getPasswordForName:keychainName account:keychainAccount];
}

- (void)connectSheetAddToFavorites:(id)sender
{
	[self addToFavoritesName:[nameField stringValue] host:[hostField stringValue] socket:[socketField stringValue] user:[userField stringValue] password:[passwordField stringValue] port:[portField stringValue] database:[databaseField stringValue] useSSH:false sshHost:@"" sshUser:@"" sshPassword:@"" sshPort:@""];
}

/**
 * add actual connection to favorites
 */
- (void)addToFavoritesName:(NSString *)name host:(NSString *)host socket:(NSString *)socket 
					 user:(NSString *)user password:(NSString *)password
					 port:(NSString *)port database:(NSString *)database
				   useSSH:(BOOL)useSSH // no-longer in use
				  sshHost:(NSString *)sshHost // no-longer in use
				  sshUser:(NSString *)sshUser // no-longer in use
			  sshPassword:(NSString *)sshPassword // no-longer in use
				  sshPort:(NSString *)sshPort // no-longer in use
{
	NSString *favoriteName = [name length]?name:[NSString stringWithFormat:@"%@@%@", user, host];
	NSNumber *favoriteid = [NSNumber numberWithInt:[[NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]] hash]];
	if (![name length] && ![database isEqualToString:@""])
		favoriteName = [NSString stringWithFormat:@"%@ %@", database, favoriteName];
	
	// test if host and socket are not nil
	if ([host isEqualToString:@""] && [socket isEqualToString:@""]) {
		NSRunAlertPanel(NSLocalizedString(@"Insufficient connection details", @"insufficient details message"), NSLocalizedString(@"Insufficient details provided to establish a connection. Please provide at least a host or socket.", @"insufficient details informative message"), NSLocalizedString(@"OK", @"OK button"), nil, nil);
		
		return;
	}
	
	// write favorites and password
	NSMutableDictionary *newFavorite = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:favoriteName, host,	socket,	user,	port,	database,	favoriteid, nil]
															forKeys:[NSArray arrayWithObjects:@"name",	  @"host", @"socket", @"user", @"port", @"database", @"id", nil]];
	if (![password isEqualToString:@""]) {
		[keyChainInstance addPassword:password
							  forName:[NSString stringWithFormat:@"Sequel Pro : %@ (%i)", favoriteName, [favoriteid intValue]]
							  account:[NSString stringWithFormat:@"%@@%@/%@", user, host, database]];
	}
	
	[favoritesController addObject:newFavorite];
	[favoritesController setSelectedObjects:[NSArray arrayWithObject:newFavorite]];
	[[[NSApp delegate] preferenceController] updateDefaultFavoritePopup];
}

/**
 * alert sheets method
 * invoked when alertSheet get closed
 * if contextInfo == connect -> reopens the connectSheet
 * if contextInfo == removedatabase -> tries to remove the selected database
 */
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{	
	if ([contextInfo isEqualToString:@"connect"]) {
		[sheet orderOut:self];
		[self connectToDB:nil];
		return;
	}
	
	if ([contextInfo isEqualToString:@"removedatabase"]) {
		if (returnCode != NSAlertDefaultReturn)
			return;
		
		[mySQLConnection queryString:[NSString stringWithFormat:@"DROP DATABASE %@", [[self database] backtickQuotedString]]];
		if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
			// error while deleting db
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil, [NSString stringWithFormat:NSLocalizedString(@"Couldn't remove database.\nMySQL said: %@", @"message of panel when removing db failed"), [mySQLConnection getLastErrorMessage]]);
			return;
		}
		
		// db deleted with success
		selectedDatabase = nil;
		[self setDatabases:self];
		[tablesListInstance setConnection:mySQLConnection];
		[tableDumpInstance setConnection:mySQLConnection];
		[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/", mySQLVersion, [self name]]];
	}
}

- (IBAction)connectSheetShowHelp:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.sequelpro.com/docs/Getting_Connected"]];
}


#pragma mark database methods

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
	
	int i;
	
	for (i = 0 ; i < [queryResult numOfRows] ; i++) 
	{
		[chooseDatabaseButton addItemWithTitle:[[queryResult fetchRowAsArray] objectAtIndex:0]];
	}
	
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
	
	// show error on connection failed
	if ( ![mySQLConnection selectDB:[chooseDatabaseButton titleOfSelectedItem]] ) {
		if ( [mySQLConnection isConnected] ) {
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil, [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to database %@.\nBe sure that you have the necessary privileges.", @"message of panel when connection to db failed after selecting from popupbutton"), [chooseDatabaseButton titleOfSelectedItem]]);
			[self setDatabases:self];
		}
		return;
	}
	
	//setConnection of TablesList and TablesDump to reload tables in db
	[selectedDatabase release];
	selectedDatabase = nil;
	selectedDatabase = [[chooseDatabaseButton titleOfSelectedItem] retain];
	[tablesListInstance setConnection:mySQLConnection];
	[tableDumpInstance setConnection:mySQLConnection];
	[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/%@", mySQLVersion, [self name], [self database]]];
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
	[selectedDatabase release];
	selectedDatabase = nil;
	selectedDatabase = [[databaseNameField stringValue] retain];
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

#pragma mark Console methods

/**
 * Shows or hides the console
 */
- (void)toggleConsole:(id)sender
{
	BOOL isConsoleVisible = [[[SPQueryConsole sharedQueryConsole] window] isVisible];
	
	// Show or hide the console
	[[[SPQueryConsole sharedQueryConsole] window] setIsVisible:(!isConsoleVisible)];
	
	// Get the menu item for showing and hiding the console. This is isn't the best way to get it as any 
	// changes to the menu structure will result in the wrong item being selected.
	NSMenuItem *menuItem = [[[[NSApp mainMenu] itemAtIndex:3] submenu] itemAtIndex:5];
	
	// Only update the menu item title if its the menu item and not the toolbar
	[menuItem setTitle:(!isConsoleVisible) ? NSLocalizedString(@"Hide Console", @"Hide Console") : NSLocalizedString(@"Show Console", @"Show Console")];
}

/**
 * Clears the console by removing all of its messages
 */
- (void)clearConsole:(id)sender
{
	[[SPQueryConsole sharedQueryConsole] clearConsole:sender];
}

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
		[mySQLConnection setEncoding:[CMMCPConnection encodingForMySQLEncoding:[mysqlEncoding UTF8String]]];
		[_encoding autorelease];
		_encoding = [mysqlEncoding retain];
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
 * Returns whether the current encoding should display results via Latin1 transport for backwards compatibility
 */
- (BOOL)connectionEncodingViaLatin1
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
	
	CMMCPResult *theResult = [mySQLConnection queryString:query];
	
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

	[createTableSyntaxWindow setTitle:createWindowTitle];
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
	
	CMMCPResult *theResult = [mySQLConnection queryString:query];
	
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
	CMMCPResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"CHECK TABLE %@", [[self table] backtickQuotedString]]];
	
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
	CMMCPResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"ANALYZE TABLE %@", [[self table] backtickQuotedString]]];
	
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
	CMMCPResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"OPTIMIZE TABLE %@", [[self table] backtickQuotedString]]];
	
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
	CMMCPResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"REPAIR TABLE %@", [[self table] backtickQuotedString]]];
	
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
	CMMCPResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"CHECKSUM TABLE %@", [[self table] backtickQuotedString]]];
	
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

#pragma mark Other Methods

/**
 * Returns the host
 */
- (NSString *)host
{
	return [hostField stringValue];
}

/**
 * Returns the name
 */
- (NSString *)name
{
	if ([[nameField stringValue] length]) {
		return [nameField stringValue];
	}
		return [NSString stringWithFormat:@"%@@%@", [userField stringValue], [hostField stringValue]];
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
	CMMCPResult *theResult;
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

// Getter methods

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
	return [userField stringValue];
}

// Notification center methods

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

/**
 * The status of the tunnel has changed
 */
- (void)tunnelStatusChanged:(NSNotification *)notification
{
}

// Menu methods

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
		return (![self _favoriteAlreadyExists:[self database] host:[self host] user:[self user]]);
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
	[mainToolbar setSelectedItemIdentifier:@"SwitchToTableInfoToolbarItemIdentifier"];
}


/**
 * Adds the current database connection details to the user's favorites if it doesn't already exist.
 */
- (IBAction)addConnectionToFavorites:(id)sender
{
	// Obviously don't add if it already exists. We shouldn't really need this as the menu item validation
	// enables or disables the menu item based on the same method. Although to be safe do the check anyway
	// as we don't know what's calling this method.
	if ([self _favoriteAlreadyExists:[self database] host:[self host] user:[self user]]) {
		return;
	}
	
	// Add current connection to favorites using the same method as used on the connection sheet to provide consistency.
	[self connectSheetAddToFavorites:self];
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
	
	// select the structure toolbar item
	[self viewStructure:self];
	
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
		
	} else if ([itemIdentifier isEqualToString:@"ToggleConsoleIdentifier"]) {
		//set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Show/Hide Console", @"toolbar item for show/hide console")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Show or hide the console which shows all MySQL commands performed by Sequel Pro", @"tooltip for toolbar item for show/hide console")];
		
		if ([[[SPQueryConsole sharedQueryConsole] window] isVisible]) {
			[toolbarItem setLabel:NSLocalizedString(@"Hide Console", @"Hide Console")];
			[toolbarItem setImage:[NSImage imageNamed:@"hideconsole"]];
		} else {
			[toolbarItem setLabel:NSLocalizedString(@"Show Console", @"Show Console")];
			[toolbarItem setImage:[NSImage imageNamed:@"showconsole"]];
		}
		
		//set up the target action
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(toggleConsole:)];
		
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
			@"ToggleConsoleIdentifier",
			@"ClearConsoleIdentifier",
			@"FlushPrivilegesIdentifier",
			@"SwitchToTableStructureToolbarItemIdentifier",
			@"SwitchToTableContentToolbarItemIdentifier",
			@"SwitchToRunQueryToolbarItemIdentifier",
			@"SwitchToTableInfoToolbarItemIdentifier",
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
			NSToolbarSeparatorItemIdentifier,
			@"SwitchToTableStructureToolbarItemIdentifier",
			@"SwitchToTableContentToolbarItemIdentifier",
			@"SwitchToRunQueryToolbarItemIdentifier",
			@"SwitchToTableInfoToolbarItemIdentifier",
			NSToolbarFlexibleSpaceItemIdentifier,
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
			nil];
	
}

/**
 * Validates the toolbar items
 */
- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem;
{
	NSString *identifier = [toolbarItem itemIdentifier];
	
	// Toggle console item
	if ([identifier isEqualToString:@"ToggleConsoleIdentifier"]) {
		if ([[[SPQueryConsole sharedQueryConsole] window] isVisible]) {
			[toolbarItem setLabel:@"Hide Console"];
			[toolbarItem setImage:[NSImage imageNamed:@"hideconsole"]];
		} 
		else {
			[toolbarItem setLabel:@"Show Console"];
			[toolbarItem setImage:[NSImage imageNamed:@"showconsole"]];
		}
	}
	
	// Clear console item
	if ([identifier isEqualToString:@"ClearConsoleIdentifier"]) {
		return ([[SPQueryConsole sharedQueryConsole] consoleMessageCount] > 0);
	}
	
	return YES;
}

// NSDocument methods

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
	
	//set up toolbar
	[self setupToolbar];
	// [self connectToDB:nil];
	[self performSelector:@selector(connectToDB:) withObject:tableWindow afterDelay:0.0f];
	
	if([prefs boolForKey:@"SelectLastFavoriteUsed"] == YES){
		[favoritesController setSelectionIndex:[prefs integerForKey:@"LastFavoriteIndex"]];
	} else {
		[favoritesController setSelectionIndex:[prefs integerForKey:@"DefaultFavorite"]];
	}
}

// NSWindow delegate methods

/**
 * Invoked when the document window is about to close
 */
- (void)windowWillClose:(NSNotification *)aNotification
{	
	if ([mySQLConnection isConnected]) [self closeConnection];
	if ([[[SPQueryConsole sharedQueryConsole] window] isVisible]) [self toggleConsole:self];
	[[customQueryInstance helpWebViewWindow] release];
	[createTableSyntaxWindow release];
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

#pragma mark SMySQL delegate methods

/**
 * Invoked when framework will perform a query
 */
- (void)willQueryString:(NSString *)query
{		
	[[SPQueryConsole sharedQueryConsole] showMessageInConsole:query];
}

/**
 * Invoked when query gave an error
 */
- (void)queryGaveError:(NSString *)error
{	
	[[SPQueryConsole sharedQueryConsole] showErrorInConsole:error];
}

#pragma mark -
#pragma mark Connection sheet delegate methods

/**
 * When a favorite is selected, and the connection details are edited, deselect the favorite;
 * this is clearer and also prevents a failed connection from being repopulated with the
 * favorite's details instead of the last used details.
 */
- (void) controlTextDidChange:(NSNotification *)aNotification
{
	if ([aNotification object] == nameField || [aNotification object] == hostField
		|| [aNotification object] == userField || [aNotification object] == passwordField
		|| [aNotification object] == databaseField || [aNotification object] == socketField
		|| [aNotification object] == portField) {
		[favoritesController setSelectionIndexes:[NSIndexSet indexSet]];
	}
	else if ([aNotification object] == databaseNameField) {
		[addDatabaseButton setEnabled:([[databaseNameField stringValue] length] > 0)]; 
	}
}

#pragma mark SplitView delegate methods

/**
 * tells the splitView that it can collapse views
 */
- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	return NO;
}

/**
 * defines max position of splitView
 */
- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
{
	return proposedMax - 600;
}

/**
 * defines min position of splitView
 */
- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
{
	return proposedMin + 140;
}

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
	float leftPaneWidth = [dbTablesTableView frame].size.width;
	
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
	}
	
	return theValue;
}

- (IBAction)terminate:(id)sender
{
	[[NSApp orderedDocuments] makeObjectsPerformSelector:@selector(cancelConnectSheet:) withObject:nil];
	[NSApp terminate:sender];
}

- (void)dealloc
{
	[chooseDatabaseButton release];
	[mySQLConnection release];
	[variables release];
	[selectedDatabase release];
	[mySQLVersion release];
	
	[super dealloc];
}

@end

@implementation TableDocument (PrivateAPI)

/**
 * Checks to see if a favorite with the supplied details already exists.
 */
- (BOOL)_favoriteAlreadyExists:(NSString *)database host:(NSString *)host user:(NSString *)user
{
	NSArray *favorites = [favoritesController arrangedObjects];

	// Ensure database, host, and user match prefs format
	if (!database) database = @"";
	if (!host) host = @"";
	if (!user) user = @"";

	// Loop the favorites and check their details
	for (NSDictionary *favorite in favorites)
	{
		if ([[favorite objectForKey:@"database"] isEqualToString:database] &&
			[[favorite objectForKey:@"host"] isEqualToString:host] &&
			[[favorite objectForKey:@"user"] isEqualToString:user]) {
			return YES;
		}
	}
	
	return NO;
}

@end
