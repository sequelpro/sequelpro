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
#import "TableStatus.h"
#import "ImageAndTextCell.h"
#import "SPGrowlController.h"
#import "SPQueryConsole.h"
#import "SPSQLParser.h"
#import "SPTableData.h"
#import "SPStringAdditions.h"
#import "SPQueryConsole.h"
#import "CMMCPConnection.h"
#import "CMMCPResult.h"

NSString *TableDocumentFavoritesControllerSelectionIndexDidChange = @"TableDocumentFavoritesControllerSelectionIndexDidChange";
NSString *TableDocumentFavoritesControllerFavoritesDidChange = @"TableDocumentFavoritesControllerFavoritesDidChange";

@implementation TableDocument

- (id)init
{
	if (![super init])
		return nil;
	
	_encoding = [@"utf8" retain];
	chooseDatabaseButton = nil;
	chooseDatabaseToolbarItem = nil;
		
	return self;
}

- (void)awakeFromNib
{
	// register selection did change handler for favorites controller (used in connect sheet)
	[favoritesController addObserver:self forKeyPath:@"selectionIndex" options:NSKeyValueChangeInsertion context:TableDocumentFavoritesControllerSelectionIndexDidChange];
	
	// register value change handler for favourites, so we can save them to preferences
	[self addObserver:self forKeyPath:@"favorites" options:0 context:TableDocumentFavoritesControllerFavoritesDidChange];
	
	// register double click for the favorites view (double click favorite to connect)
	[connectFavoritesTableView setTarget:self];
	
	// find the Database -> Database Encoding menu (it's not in our nib, so we can't use interface builder)
	selectEncodingMenu = [[[[[NSApp mainMenu] itemWithTag:1] submenu] itemWithTag:1] submenu];
	
	// hide the tabs in the tab view (we only show them to allow switching tabs in interface builder)
	[tableTabView setTabViewType:NSNoTabsNoBorder];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == TableDocumentFavoritesControllerSelectionIndexDidChange) {
		[self chooseFavorite:self];
		return;
	}
	
	if (context == TableDocumentFavoritesControllerFavoritesDidChange) {
		[prefs setObject:[self favorites] forKey:@"favorites"];
		return;
	}
	
	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)ps error:(NSError **)e
{
	
	NSPrintInfo *printInfo = [self printInfo];
	[printInfo setHorizontalPagination:NSFitPagination];
	[printInfo setVerticalPagination:NSAutoPagination];
	NSPrintOperation *printOp = [NSPrintOperation printOperationWithView:[[tableTabView selectedTabViewItem] view] printInfo:printInfo];
	return printOp;
}

- (CMMCPConnection *)sharedConnection
{
	return mySQLConnection;
}


//start sheet

/**
 * tries to connect to a database server, shows connect sheet prompting user to
 * enter details/select favorite and shoows alert sheets on failure.
 */
- (IBAction)connectToDB:(id)sender
{
	
	// load the details of the curretnly selected favorite into the text boxes in connect sheet
	[self chooseFavorite:self];
	
	// run the connect sheet (modal)
	[NSApp beginSheet:connectSheet
	   modalForWindow:tableWindow
		modalDelegate:self
	   didEndSelector:@selector(connectSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];
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

	// Save the favourites - commits any unsaved changes ie favourite renames
	[prefs setObject:[self favorites] forKey:@"favorites"];
	[prefs synchronize];
	
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
		NSString *encodingName = [prefs objectForKey:@"encoding"];
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
		[tablesListInstance setConnection:mySQLConnection];
		[tableSourceInstance setConnection:mySQLConnection];
		[tableContentInstance setConnection:mySQLConnection];
		[customQueryInstance setConnection:mySQLConnection];
		[tableDumpInstance setConnection:mySQLConnection];
		[tableStatusInstance setConnection:mySQLConnection];
		[tableDataInstance setConnection:mySQLConnection];
		[self setFileName:[NSString stringWithFormat:@"(MySQL %@) %@@%@ %@", mySQLVersion, [userField stringValue],
						   [hostField stringValue], [databaseField stringValue]]];
		[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@@%@/%@", mySQLVersion, [userField stringValue],
							   [hostField stringValue], [databaseField stringValue]]];
		
		// Connected Growl notification		
        [[SPGrowlController sharedGrowlController] notifyWithTitle:@"Connected"
                                                       description:[NSString stringWithFormat:NSLocalizedString(@"Connected to %@",@"description for connected growl notification"), [tableWindow title]]
                                                  notificationName:@"Connected"];
		
	} else if (code == 2) {
		//can't connect to host
		NSBeginAlertSheet(NSLocalizedString(@"Connection failed!", @"connection failed"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil,
						  @selector(sheetDidEnd:returnCode:contextInfo:), @"connect",
						  [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to host %@, or the request timed out.\n\nBe sure that the address is correct and that you have the necessary privileges, or try increasing the connection timeout (currently %i seconds).\n\nMySQL said: %@", @"message of panel when connection to host failed"), [hostField stringValue], [[prefs objectForKey:@"connectionTimeout"] intValue], [mySQLConnection getLastErrorMessage]]);
	} else if (code == 3) {
		//can't connect to db
		NSBeginAlertSheet(NSLocalizedString(@"Connection failed!", @"connection failed"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil,
						  @selector(sheetDidEnd:returnCode:contextInfo:), @"connect",
						  [NSString stringWithFormat:NSLocalizedString(@"Connected to host, but unable to connect to database %@.\n\nBe sure that the database exists and that you have the necessary privileges.\n\nMySQL said: %@", @"message of panel when connection to db failed"), [databaseField stringValue], [mySQLConnection getLastErrorMessage]]);
	} else if (code == 4) {
		//no host is given
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil,
						  @selector(sheetDidEnd:returnCode:contextInfo:), @"connect", NSLocalizedString(@"Please enter at least a host or socket.", @"message of panel when host/socket are missing"));
	}
	
}

- (IBAction)cancelConnectSheet:(id)sender
{
	[NSApp endSheet:connectSheet];
	[tableWindow close];
}

- (IBAction)closeSheet:(id)sender
/*
 invoked when user hits the cancel button of the connectSheet
 stops modal session with code 0
 reused when user hits the close button of the variablseSheet or of the createTableSyntaxSheet
 */
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
	
	[hostField setStringValue:[self valueForKeyPath:@"selectedFavorite.host"]];
	[socketField setStringValue:[self valueForKeyPath:@"selectedFavorite.socket"]];
	[userField setStringValue:[self valueForKeyPath:@"selectedFavorite.user"]];
	[portField setStringValue:[self valueForKeyPath:@"selectedFavorite.port"]];
	[databaseField setStringValue:[self valueForKeyPath:@"selectedFavorite.database"]];
	[passwordField setStringValue:[self selectedFavoritePassword]];
	
	[prefs setInteger:[favoritesController selectionIndex] forKey:@"lastFavoriteIndex"];
}

/**
 * Remove the selected favourite. Instead of calling the remove: method of the Favorites NSArrayController
 * directly in the XIB we do it here because we also need to remove the keychain password.
 */
- (IBAction)removeFavorite:(id)sender
{
	if (![self selectedFavorite]) {
		return;
	}
	
	NSString *name     = [self valueForKeyPath:@"selectedFavorite.name"];
	NSString *user     = [self valueForKeyPath:@"selectedFavorite.user"];
	NSString *host     = [self valueForKeyPath:@"selectedFavorite.host"];
	NSString *database = [self valueForKeyPath:@"selectedFavorite.database"];
	
	[keyChainInstance deletePasswordForName:[NSString stringWithFormat:@"Sequel Pro : %@", name]
									account:[NSString stringWithFormat:@"%@@%@/%@", user, host, database]];
	[keyChainInstance deletePasswordForName:[NSString stringWithFormat:@"Sequel Pro SSHTunnel : %@", name]
									account:[NSString stringWithFormat:@"%@@%@/%@", user, host, database]];
	
	// Remove from favorites array controller
	[favoritesController remove:[self selectedFavorite]];

}

/**
 * Return the favorites array.
 */
- (NSMutableArray *)favorites
{
	// if no favorites, load from user defaults
	if (!favorites) {
		favorites = [[NSMutableArray alloc] initWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"favorites"]];
	}
	
	// if no favorites in user defaults, load empty ones
	if (!favorites) {
		favorites = [[NSMutableArray array] retain];
	}
	
	return favorites;
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
	
	NSString *keychainName = [NSString stringWithFormat:@"Sequel Pro : %@", [self valueForKeyPath:@"selectedFavorite.name"]];
	NSString *keychainAccount = [NSString stringWithFormat:@"%@@%@/%@",
								 [self valueForKeyPath:@"selectedFavorite.user"],
								 [self valueForKeyPath:@"selectedFavorite.host"],
								 [self valueForKeyPath:@"selectedFavorite.database"]];
	
	return [keyChainInstance getPasswordForName:keychainName account:keychainAccount];
}

- (void)connectSheetAddToFavorites:(id)sender
{
	[self addToFavoritesHost:[hostField stringValue] socket:[socketField stringValue] user:[userField stringValue] password:[passwordField stringValue] port:[portField stringValue] database:[databaseField stringValue] useSSH:false sshHost:@"" sshUser:@"" sshPassword:@"" sshPort:@""];
}

/**
 * add actual connection to favorites
 */
- (void)addToFavoritesHost:(NSString *)host socket:(NSString *)socket 
					  user:(NSString *)user password:(NSString *)password
					  port:(NSString *)port database:(NSString *)database
					useSSH:(BOOL)useSSH // no-longer in use
				   sshHost:(NSString *)sshHost // no-longer in use
				   sshUser:(NSString *)sshUser // no-longer in use
			   sshPassword:(NSString *)sshPassword // no-longer in use
				   sshPort:(NSString *)sshPort // no-longer in use
{
	NSString *favoriteName = [NSString stringWithFormat:@"%@@%@", user, host];
	if (![database isEqualToString:@""])
		favoriteName = [NSString stringWithFormat:@"%@ %@", database, favoriteName];
	
	// test if host and socket are not nil
	if ([host isEqualToString:@""] && [socket isEqualToString:@""]) {
		NSRunAlertPanel(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"Please enter at least a host or socket.", @"message of panel when host/socket are missing"), NSLocalizedString(@"OK", @"OK button"), nil, nil);
		return;
	}
	
	[self willChangeValueForKey:@"favorites"];
	
	// write favorites and password
	NSMutableDictionary *newFavorite = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:favoriteName, host,	socket,	user,	port,	database,	nil]
															forKeys:[NSArray arrayWithObjects:@"name",	  @"host", @"socket", @"user", @"port", @"database", nil]];
	[favorites addObject:newFavorite];
	
	if (![password isEqualToString:@""]) {
		[keyChainInstance addPassword:password
							  forName:[NSString stringWithFormat:@"Sequel Pro : %@", favoriteName]
							  account:[NSString stringWithFormat:@"%@@%@/%@", user, host, database]];
	}
	
	[self didChangeValueForKey:@"favorites"];
	[favoritesController setSelectedObjects:[NSArray arrayWithObject:newFavorite]];
}

/**
 * alert sheets method
 * invoked when alertSheet get closed
 * if contextInfo == connect -> reopens the connectSheet
 * if contextInfo == removedatabase -> tries to remove the selected database
 */
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{
	[sheet orderOut:self];
	
	if ([contextInfo isEqualToString:@"connect"]) {
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
		[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@@%@/", mySQLVersion, [userField stringValue], [hostField stringValue]]];
	}
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
	[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@@%@/%@", mySQLVersion, [userField stringValue], [hostField stringValue], [self database]]];
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
	[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@@%@/%@", mySQLVersion, [userField stringValue], [hostField stringValue], selectedDatabase]];
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
	
	NSBeginAlertSheet(NSLocalizedString(@"Warning", @"warning"), NSLocalizedString(@"Delete", @"delete button"), NSLocalizedString(@"Cancel", @"cancel button"), nil, tableWindow, self, nil, @selector(sheetDidEnd:returnCode:contextInfo:), @"removedatabase", [NSString stringWithFormat:NSLocalizedString(@"Do you really want to delete the database %@?", @"message of panel asking for confirmation for deleting db"), [self database]]);
}

#pragma mark Console methods

/**
 * Shows or hides the console
 */
- (void)toggleConsole:(id)sender
{
	[[[SPQueryConsole sharedQueryConsole] window] setIsVisible:![[[SPQueryConsole sharedQueryConsole] window] isVisible]];
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
	BOOL uselatin1results = NO;

	// Special-case UTF-8 over latin 1 to allow viewing/editing of mangled data.
	if ([mysqlEncoding isEqualToString:@"utf8-"]) {
		uselatin1results = YES;
		mysqlEncoding = @"utf8";
	}
	
	// set encoding of connection and client
	[mySQLConnection queryString:[NSString stringWithFormat:@"SET NAMES '%@'", mysqlEncoding]];
	
	if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
		if (uselatin1results)
			[mySQLConnection queryString:@"SET CHARACTER_SET_RESULTS=latin1"];
		[mySQLConnection setEncoding:[CMMCPConnection encodingForMySQLEncoding:[mysqlEncoding UTF8String]]];
		[_encoding autorelease];
		_encoding = [mysqlEncoding retain];
	} else {
		[mySQLConnection queryString:[NSString stringWithFormat:@"SET NAMES '%@'", [self databaseEncoding]]];
		if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
			NSLog(@"Error: could not set encoding to %@ nor fall back to database encoding on MySQL %@", mysqlEncoding, [self mySQLVersion]);
			return;
		}
	}
		
	// update the selected menu item
	if (uselatin1results) {
		[self updateEncodingMenuWithSelectedEncoding:[self encodingNameFromMySQLEncoding:[NSString stringWithFormat:@"%@-", mysqlEncoding]]];
	} else {
		[self updateEncodingMenuWithSelectedEncoding:[self encodingNameFromMySQLEncoding:mysqlEncoding]];
	}

	// Reload stuff as appropriate
	[tableDataInstance resetAllData];
	if (reloadViews) {
		if ([tablesListInstance structureLoaded]) [tableSourceInstance reloadTable:self];
		if ([tablesListInstance contentLoaded]) [tableContentInstance reloadTable:self];
		if ([tablesListInstance statusLoaded]) [tableStatusInstance reloadTable:self];
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

- (IBAction)showCreateTableSyntax:(id)sender
{
	//Create the query and get results
	NSString *query = [NSString stringWithFormat:@"SHOW CREATE TABLE %@", [[self table] backtickQuotedString]];
	CMMCPResult *theResult = [mySQLConnection queryString:query];
	
	// Check for errors, only displaying if the connection hasn't been terminated
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		if ([mySQLConnection isConnected]) {
			NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"An error occured while creating table syntax.\n\n: %@",[mySQLConnection getLastErrorMessage]], @"OK", nil, nil);
		}
		return;
	}
	
	id tableSyntax = [[theResult fetchRowAsArray] objectAtIndex:1];
	
	if ([tableSyntax isKindOfClass:[NSData class]])
		tableSyntax = [[NSString alloc] initWithData:tableSyntax encoding:[mySQLConnection encoding]];
	
	[syntaxViewContent setString:tableSyntax];
	[createTableSyntaxWindow makeKeyAndOrderFront:self];
}

- (IBAction)copyCreateTableSyntax:(id)sender
{
	// Create the query and get results
	NSString *query = [NSString stringWithFormat:@"SHOW CREATE TABLE %@", [[self table] backtickQuotedString]];
	CMMCPResult *theResult = [mySQLConnection queryString:query];
	
	// Check for errors, only displaying if the connection hasn't been terminated
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		if ([mySQLConnection isConnected]) {
			NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"An error occured while creating table syntax.\n\n: %@",[mySQLConnection getLastErrorMessage]], @"OK", nil, nil);
		}
		return;
	}
	
	id tableSyntax = [[theResult fetchRowAsArray] objectAtIndex:1];
	
	if ([tableSyntax isKindOfClass:[NSData class]])
		tableSyntax = [[NSString alloc] initWithData:tableSyntax encoding:[mySQLConnection encoding]];
	
	// copy to the clipboard
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	[pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
	[pb setString:tableSyntax forType:NSStringPboardType];
    
    // Table syntax copied Growl notification
    [[SPGrowlController sharedGrowlController] notifyWithTitle:@"Table Syntax Copied"
                                                   description:[NSString stringWithFormat:NSLocalizedString(@"Syntax for %@ table copied",@"description for table syntax copied growl notification"), [self table]] 
                                              notificationName:@"Table Syntax Copied"];
}

- (IBAction)checkTable:(id)sender
{
	NSString *query;
	CMMCPResult *theResult;
	NSDictionary *theRow;
	
	//Create the query and get results
	query = [NSString stringWithFormat:@"CHECK TABLE %@", [[self table] backtickQuotedString]];
	theResult = [mySQLConnection queryString:query];
	
	// Check for errors, only displaying if the connection hasn't been terminated
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		if ([mySQLConnection isConnected]) {
			NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"An error occured while checking table.\n\n: %@",[mySQLConnection getLastErrorMessage]], @"OK", nil, nil);
		}
		return;
	}
	
	// Process result
	theRow = [[theResult fetch2DResultAsType:MCPTypeDictionary] lastObject];
	NSRunInformationalAlertPanel([NSString stringWithFormat:@"Check '%@' table", [self table]], [NSString stringWithFormat:@"Check: %@", [theRow objectForKey:@"Msg_text"]], @"OK", nil, nil);
}

- (IBAction)analyzeTable:(id)sender
{
	NSString *query;
	CMMCPResult *theResult;
	NSDictionary *theRow;
	
	//Create the query and get results
	query = [NSString stringWithFormat:@"ANALYZE TABLE %@", [[self table] backtickQuotedString]];
	theResult = [mySQLConnection queryString:query];
	
	// Check for errors, only displaying if the connection hasn't been terminated
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		if ([mySQLConnection isConnected]) {
			NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"An error occured while analyzing table.\n\n: %@",[mySQLConnection getLastErrorMessage]], @"OK", nil, nil);
		}
		return;
	}
	
	// Process result
	theRow = [[theResult fetch2DResultAsType:MCPTypeDictionary] lastObject];
	NSRunInformationalAlertPanel([NSString stringWithFormat:@"Analyze '%@' table", [self table]], [NSString stringWithFormat:@"Analyze: %@", [theRow objectForKey:@"Msg_text"]], @"OK", nil, nil);
}

- (IBAction)optimizeTable:(id)sender
{
	NSString *query;
	CMMCPResult *theResult;
	NSDictionary *theRow;
	
	//Create the query and get results
	query = [NSString stringWithFormat:@"OPTIMIZE TABLE %@", [[self table] backtickQuotedString]];
	theResult = [mySQLConnection queryString:query];
	
	// Check for errors, only displaying if the connection hasn't been terminated
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
		if ([mySQLConnection isConnected]) {
			NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"An error occured while optimizing table.\n\n: %@",[mySQLConnection getLastErrorMessage]], @"OK", nil, nil);
		}
		return;
	}
	
	// Process result
	theRow = [[theResult fetch2DResultAsType:MCPTypeDictionary] lastObject];
	NSRunInformationalAlertPanel([NSString stringWithFormat:@"Optimize '%@' table", [self table]], [NSString stringWithFormat:@"Optimize: %@", [theRow objectForKey:@"Msg_text"]], @"OK", nil, nil);
}

- (IBAction)repairTable:(id)sender
{
	NSString *query;
	CMMCPResult *theResult;
	NSDictionary *theRow;
	
	//Create the query and get results
	query = [NSString stringWithFormat:@"REPAIR TABLE %@", [[self table] backtickQuotedString]];
	theResult = [mySQLConnection queryString:query];
	
	// Check for errors, only displaying if the connection hasn't been terminated
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		if ([mySQLConnection isConnected]) {
			NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"An error occured while repairing table.\n\n: %@",[mySQLConnection getLastErrorMessage]], @"OK", nil, nil);
		}
		return;
	}
	
	// Process result
	theRow = [[theResult fetch2DResultAsType:MCPTypeDictionary] lastObject];
	NSRunInformationalAlertPanel([NSString stringWithFormat:@"Repair '%@' table", [self table]], [NSString stringWithFormat:@"Repair: %@", [theRow objectForKey:@"Msg_text"]], @"OK", nil, nil);
}

- (IBAction)flushTable:(id)sender
{
	NSString *query;
	CMMCPResult *theResult;
	
	//Create the query and get results
	query = [NSString stringWithFormat:@"FLUSH TABLE %@", [[self table] backtickQuotedString]];
	theResult = [mySQLConnection queryString:query];
	
	// Check for errors, only displaying if the connection hasn't been terminated
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		if ([mySQLConnection isConnected]) {
			NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"An error occured while flushing table.\n\n: %@",[mySQLConnection getLastErrorMessage]], @"OK", nil, nil);
		}
		return;
	}
	
	// Process result
	NSRunInformationalAlertPanel([NSString stringWithFormat:@"Flush '%@' table", [self table]], @"Flushed", @"OK", nil, nil);
}

- (IBAction)checksumTable:(id)sender
{
	NSString *query;
	CMMCPResult *theResult;
	NSDictionary *theRow;
	
	//Create the query and get results
	query = [NSString stringWithFormat:@"CHECKSUM TABLE %@", [[self table] backtickQuotedString]];
	theResult = [mySQLConnection queryString:query];
	
	// Check for errors, only displaying if the connection hasn't been terminated
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		if ([mySQLConnection isConnected]) {
			NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"An error occured while performming checksum on table.\n\n: %@",[mySQLConnection getLastErrorMessage]], @"OK", nil, nil);
		}
		return;
	}
	
	// Process result
	theRow = [[theResult fetch2DResultAsType:MCPTypeDictionary] lastObject];
	NSRunInformationalAlertPanel([NSString stringWithFormat:@"Checksum '%@' table", [self table]], [NSString stringWithFormat:@"Checksum: %@", [theRow objectForKey:@"Checksum"]], @"OK", nil, nil);
}


#pragma mark Other Methods
/**
 * returns the host
 */
- (NSString *)host
{
	return [hostField stringValue];
}

/**
 * passes query to tablesListInstance
 */
- (void)doPerformQueryService:(NSString *)query
{
	[tableWindow makeKeyAndOrderFront:self];
	[tablesListInstance doPerformQueryService:query];
}

/**
 * flushes the mysql privileges
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

- (void)showVariables:(id)sender
/*
 shows the mysql variables
 */
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


//getter methods
- (NSString *)database
/*
 returns the currently selected database
 */
{
	return selectedDatabase;
}

- (NSString *)table
/*
 returns the currently selected table (passing the request to TablesList)
 */
{
	return [tablesListInstance tableName];
}

- (NSString *)mySQLVersion
/*
 returns the mysql version
 */
{
	return mySQLVersion;
}

- (NSString *)user
/*
 returns the mysql version
 */
{
	return [userField stringValue];
}


//notification center methods
- (void)willPerformQuery:(NSNotification *)notification
/*
 invoked before a query is performed
 */
{
	// Only start the progress indicator is this document window is key. 
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

- (void)hasPerformedQuery:(NSNotification *)notification
/*
 invoked after a query has been performed
 */
{
	if ([tableWindow isKeyWindow]) {
		[queryProgressBar stopAnimation:self];
	}
}

- (void)applicationWillTerminate:(NSNotification *)notification
/*
 invoked when the application will terminate
 */
{
	[tablesListInstance selectionShouldChangeInTableView:nil];
}

- (void)tunnelStatusChanged:(NSNotification *)notification
/*
 the status of the tunnel has changed
 */
{
}

//menu methods
- (IBAction)import:(id)sender
/*
 passes the request to the tableDump object
 */
{
	[tableDumpInstance importFile];
}

- (IBAction)export:(id)sender
/*
 passes the request to the tableDump object
 */
{
	[tableDumpInstance exportFile:[sender tag]];
}

- (IBAction)exportTable:(id)sender
{
	return [self export:sender];
}

- (IBAction)exportMultipleTables:(id)sender
{
	return [self export:sender];
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
	[mainToolbar setSelectedItemIdentifier:@"SwitchToTableStatusToolbarItemIdentifier"];
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
	[mainToolbar setAllowsUserCustomization: YES];
	[mainToolbar setAutosavesConfiguration: YES];
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
			[toolbarItem setLabel:NSLocalizedString(@"Hide Console", @"toolbar item for hide console")];
			[toolbarItem setImage:[NSImage imageNamed:@"hideconsole"]];
		} else {
			[toolbarItem setLabel:NSLocalizedString(@"Show Console", @"toolbar item for showconsole")];
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
		[toolbarItem setTarget:[SPQueryConsole sharedQueryConsole]];
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
		
	} else if ([itemIdentifier isEqualToString:@"SwitchToTableStatusToolbarItemIdentifier"]) {
		[toolbarItem setLabel:NSLocalizedString(@"Table Status", @"toolbar item label for switching to the Table Status tab")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Table Status", @"toolbar item label for switching to the Table Status tab")];
		//set up tooltip and image
		[toolbarItem setToolTip:NSLocalizedString(@"Switch to the Table Status tab", @"tooltip for toolbar item for switching to the Table Status tab")];
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
			@"SwitchToTableStatusToolbarItemIdentifier",
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
			NSToolbarFlexibleSpaceItemIdentifier,
			nil];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:
			@"SwitchToTableStructureToolbarItemIdentifier",
			@"SwitchToTableContentToolbarItemIdentifier",
			@"SwitchToRunQueryToolbarItemIdentifier",
			@"SwitchToTableStatusToolbarItemIdentifier",
			nil];
	
}

/**
 * validates the toolbar items
 */
- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem;
{
	if ([[toolbarItem itemIdentifier] isEqualToString:@"ToggleConsoleIdentifier"]) {
		if ([[[SPQueryConsole sharedQueryConsole] window] isVisible]) {
			[toolbarItem setLabel:@"Hide Console"];
			[toolbarItem setImage:[NSImage imageNamed:@"hideconsole"]];
		} else {
			[toolbarItem setLabel:@"Show Console"];
			[toolbarItem setImage:[NSImage imageNamed:@"showconsole"]];
		}
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
	
	prefs = [[NSUserDefaults standardUserDefaults] retain];
	
	//register for notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willPerformQuery:)
												 name:@"SMySQLQueryWillBePerformed" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hasPerformedQuery:)
												 name:@"SMySQLQueryHasBeenPerformed" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)
												 name:@"NSApplicationWillTerminateNotification" object:nil];
	
	//set up interface
	if ( [prefs boolForKey:@"useMonospacedFonts"] ) {
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
	//	[self connectToDB:nil];
	[self performSelector:@selector(connectToDB:) withObject:tableWindow afterDelay:0.0f];
	
	if([prefs boolForKey:@"selectLastFavoriteUsed"] == YES){
		[favoritesController setSelectionIndexes:[NSIndexSet indexSetWithIndex:[prefs integerForKey:@"lastFavoriteIndex"]]];
	}
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	//reset print settings, so we're not prompted about saving them
	[self setPrintInfo:[NSPrintInfo sharedPrintInfo]];
	
	if ([mySQLConnection isConnected]) [self closeConnection];
	if ([[[SPQueryConsole sharedQueryConsole] window] isVisible]) [self toggleConsole:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

//NSWindow delegate methods
- (BOOL)windowShouldClose:(id)sender
/*
 invoked when the document window should close
 */
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
 * This method allows the password to be changed without altering the selection.
 */
- (void) controlTextDidChange:(NSNotification *)aNotification
{
	if ([aNotification object] == hostField || [aNotification object] == userField || [aNotification object] == databaseField
		|| [aNotification object] == socketField || [aNotification object] == portField) {
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


//tableView datasource methods
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [variables count];
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
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
	[favorites release];
	[variables release];
	[selectedDatabase release];
	[mySQLVersion release];
	[prefs release];
	
	[super dealloc];
}

@end
