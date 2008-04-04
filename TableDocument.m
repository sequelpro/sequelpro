//
//  TableDocument.m
//  CocoaMySQL
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed May 01 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
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
//  More info at <http://cocoamysql.sourceforge.net/>
//  Or mail to <lorenz@textor.ch>

#import "TableDocument.h"
#import "KeyChain.h"
#import "TablesList.h"
#import "TableSource.h"
#import "TableContent.h"
#import "CustomQuery.h"
#import "TableDump.h"
#import "TableStatus.h"

NSString *TableDocumentFavoritesControllerSelectionIndexDidChange = @"TableDocumentFavoritesControllerSelectionIndexDidChange";

@implementation TableDocument

- (void)awakeFromNib
{
  [favoritesController addObserver:self forKeyPath:@"selectionIndex" options:NSKeyValueChangeInsertion context:TableDocumentFavoritesControllerSelectionIndexDidChange];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if (context == TableDocumentFavoritesControllerSelectionIndexDidChange) {
    [self chooseFavorite:self];
  }
  else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}



//start sheet
- (IBAction)toggleUseSSH:(id)sender
/*
enables/disables ssh tunneling
*/
{
  if ([sshCheckbox state] == NSOnState) {
		[sshUserField setEnabled:YES];
		[sshPasswordField setEnabled:YES];
		[sshHostField setEnabled:YES];
		[sshPortField setEnabled:YES];
	} else {
		[sshUserField setEnabled:NO];
		[sshPasswordField setEnabled:NO];
		[sshHostField setEnabled:NO];
		[sshPortField setEnabled:NO];
	}
}

- (IBAction)connectToDB:(id)sender
/*
tries to connect to the db
alert-sheets when no success
*/
{
    CMMCPResult *theResult;
	NSString *encoding;
    int code;
	id version;

    [self setFavorites];

    [NSApp beginSheet:connectSheet
            modalForWindow:tableWindow modalDelegate:self
            didEndSelector:nil contextInfo:nil];
    code = [NSApp runModalForWindow:connectSheet];
    
    [NSApp endSheet:connectSheet];
    [connectSheet orderOut:nil];
    
    if ( code == 1) {
//connected with success
        //register as delegate
        [mySQLConnection setDelegate:self];
		// set encoding
		encoding = [prefs objectForKey:@"encoding"];
		if ( [encoding isEqualToString:@"Autodetect"] ) {
			[self detectEncoding];
		} else {
			[chooseEncodingButton selectItemWithTitle:encoding];
			[self setEncoding:[self getSelectedEncoding]];
		}
		// get selected db
        if ( ![[databaseField stringValue] isEqualToString:@""] )
            selectedDatabase = [[databaseField stringValue] retain];
        //get mysql version
//        theResult = [mySQLConnection queryString:@"SHOW VARIABLES LIKE \"version\""];
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
        [self setFileName:[NSString stringWithFormat:@"(MySQL %@) %@@%@ %@", mySQLVersion, [userField stringValue],
                                    [hostField stringValue], [databaseField stringValue]]];
        [tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@@%@/%@", mySQLVersion, [userField stringValue],
                                    [hostField stringValue], [databaseField stringValue]]];
    } else if (code == 2) {
//can't connect to host
        NSBeginAlertSheet(NSLocalizedString(@"Connection failed!", @"connection failed"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil,
                @selector(sheetDidEnd:returnCode:contextInfo:), @"connect",
                [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to host %@.\nBe sure that the address is correct and that you have the necessary privileges.\nMySQL said: %@", @"message of panel when connection to host failed"), [hostField stringValue], [mySQLConnection getLastErrorMessage]]);
    } else if (code == 3) {
//can't connect to db
        NSBeginAlertSheet(NSLocalizedString(@"Connection failed!", @"connection failed"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil,
                @selector(sheetDidEnd:returnCode:contextInfo:), @"connect",
                [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to database %@.\nBe sure that the database exists and that you have the necessary privileges.\nMySQL said: %@", @"message of panel when connection to db failed"), [databaseField stringValue], [mySQLConnection getLastErrorMessage]]);
    } else if (code == 4) {
//no host is given
        NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil,
                @selector(sheetDidEnd:returnCode:contextInfo:), @"connect", NSLocalizedString(@"Please enter at least a host or socket.", @"message of panel when host/socket are missing"));
    } else {
//cancel button was pressed
        //since the window is getting ready to be toast ignore events for awhile
        //so as not to crash, this happens to me when hitten esc key instead of
        //cancel button, but with this code it does not crash
        [[NSApplication sharedApplication] discardEventsMatchingMask:NSAnyEventMask 
                                                         beforeEvent:[[NSApplication sharedApplication] nextEventMatchingMask:NSLeftMouseDownMask | NSLeftMouseUpMask |NSRightMouseDownMask | NSRightMouseUpMask | NSFlagsChangedMask | NSKeyDownMask | NSKeyUpMask untilDate:[NSDate distantPast] inMode:NSEventTrackingRunLoopMode dequeue:YES]];
        [tableWindow close];
    }
}


- (IBAction)connect:(id)sender
/*
invoked when user hits the connect-button of the connectSheet
stops modal session with code:
1 when connected with success
2 when no connection to host
3 when no connection to db
4 when hostField and socketField are empty
*/
{
    int code;

    [connectProgressBar startAnimation:self];

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
        if ( ![mySQLConnection isConnected] )
            code = 2;
        if ( !code && ![[databaseField stringValue] isEqualToString:@""] )
            if ( ![mySQLConnection selectDB:[databaseField stringValue]] )
                code = 3;
        if ( !code )
            code = 1;
    }
    [NSApp stopModalWithCode:code];
    
    [connectProgressBar stopAnimation:self];
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

- (IBAction)chooseFavorite:(id)sender
/*
 sets fields for the choosen favorite
 */
{
	/*
  BOOL useSSH = NO;
  
  if ( [favoritesButton indexOfSelectedItem] == 0 ) {
    [hostField setStringValue:@""];
    [socketField setStringValue:@""];
    [userField setStringValue:@""];
    [portField setStringValue:@""];
    [databaseField setStringValue:@""];
    [passwordField setStringValue:@""];
		[sshCheckbox setState:NSOffState];
		[sshUserField setEnabled:NO];
		[sshPasswordField setEnabled:NO];
		[sshHostField setEnabled:NO];
		[sshPortField setEnabled:NO];
		[sshHostField setStringValue:@""];
		[sshUserField setStringValue:@""];
		[sshPasswordField setStringValue:@""];
		[sshPortField setStringValue:@"8888"];
    [hostField selectText:self];
    [selectedFavorite release];
    selectedFavorite = [[favoritesButton titleOfSelectedItem] retain];
  } else if ( [favoritesButton indexOfSelectedItem] == 1 ) {
    if ( ![[socketField stringValue] isEqualToString:@""] ) {
      [hostField setStringValue:@"localhost"];
    }
		if ( [sshCheckbox state] == NSOnState ) {
			useSSH = YES;
		} else {
			useSSH = NO;
		}
    [self addToFavoritesHost:[hostField stringValue]
                      socket:[socketField stringValue]
                        user:[userField stringValue]
                    password:[passwordField stringValue]
                        port:[portField stringValue]
                    database:[databaseField stringValue]
                      useSSH:useSSH
                     sshHost:[sshHostField stringValue]
                     sshUser:[sshUserField stringValue]
                 sshPassword:[sshPasswordField stringValue]
                     sshPort:[sshPortField stringValue]];
    //    } else if ( [favoritesButton indexOfSelectedItem] == 2 ) {
    //        [favoritesButton selectItemWithTitle:selectedFavorite];
  } else {*/
  NSDictionary *favorite = [[prefs objectForKey:@"favorites"] objectAtIndex:[favoritesController selectionIndex]];
  NSString *name = [favorite objectForKey:@"name"];
  NSString *host = [favorite objectForKey:@"host"];
  NSString *socket = [favorite objectForKey:@"socket"];
  NSString *user = [favorite objectForKey:@"user"];
  NSString *port = [favorite objectForKey:@"port"];
  NSString *database = [favorite objectForKey:@"database"];
  int useSSH = [[favorite objectForKey:@"useSSH"] intValue];
  NSString *sshHost = [favorite objectForKey:@"sshHost"];
  NSString *sshUser = [favorite objectForKey:@"sshUser"];
  NSString *sshPort = [favorite objectForKey:@"sshPort"];
  
    [hostField setStringValue:host];
    [socketField setStringValue:socket];
    [userField setStringValue:user];
    [portField setStringValue:port];
    [databaseField setStringValue:database];
    [passwordField setStringValue:[keyChainInstance
                                   getPasswordForName:[NSString stringWithFormat:@"CocoaMySQL : %@", name]
                                   account:[NSString stringWithFormat:@"%@@%@/%@", user, host, database]]];
		if ( useSSH ) {
			[sshCheckbox setState:NSOnState];
			[sshHostField setStringValue:sshHost];
			[sshUserField setStringValue:sshUser];
			[sshPortField setStringValue:sshPort];
			[sshPasswordField setStringValue:[keyChainInstance
                                        getPasswordForName:[NSString stringWithFormat:@"CocoaMySQL SSHTunnel : %@", name]
                                        account:[NSString stringWithFormat:@"%@@%@/%@", user, host, database]]];
			[sshUserField setEnabled:YES];
			[sshPasswordField setEnabled:YES];
			[sshHostField setEnabled:YES];
			[sshPortField setEnabled:YES];
		} else {
			[sshCheckbox setState:NSOffState];
			[sshHostField setStringValue:@""];
			[sshUserField setStringValue:@""];
			[sshPortField setStringValue:@""];
			[sshPasswordField setStringValue:@""];
			[sshUserField setEnabled:NO];
			[sshPasswordField setEnabled:NO];
			[sshHostField setEnabled:NO];
			[sshPortField setEnabled:NO];
		}
    
    [selectedFavorite release];
    selectedFavorite = [[favoritesButton titleOfSelectedItem] retain];
  /*}*/
}

- (NSArray *)favorites
{
  return favorites;
}

- (void)setFavorites
/*
 set up the favorites popUpButton and notifiy bindings that it's changed
 */
{
  [self willChangeValueForKey:@"favorites"];
  [self didChangeValueForKey:@"favorites"];
  
  NSEnumerator *enumerator = [favorites objectEnumerator];
  id favorite;
  
  [favoritesButton removeAllItems];
  [favoritesButton addItemWithTitle:NSLocalizedString(@"Custom", @"menu item for custom connection")];
  [favoritesButton addItemWithTitle:NSLocalizedString(@"Save to favorites...", @"menu item for saving connection to favorites")];
  //    [favoritesButton addItemWithTitle:@""];
  [[favoritesButton menu] addItem:[NSMenuItem separatorItem]];
  while ( (favorite = [enumerator nextObject]) ) {
    [favoritesButton addItemWithTitle:[favorite objectForKey:@"name"]];
  }
}

- (void)addToFavoritesHost:(NSString *)host socket:(NSString *)socket 
                      user:(NSString *)user password:(NSString *)password
                      port:(NSString *)port database:(NSString *)database
					  useSSH:(BOOL)useSSH sshHost:(NSString *)sshHost
					  sshUser:(NSString *)sshUser sshPassword:(NSString *)sshPassword
					  sshPort:(NSString *)sshPort
/*
add actual connection to favorites
*/
{
    NSEnumerator *enumerator = [favorites objectEnumerator];
    id favorite;
    NSString *favoriteName = [NSString stringWithFormat:@"%@@%@/%@", user, host, database];
	NSNumber *ssh;

//test if host and socket are not nil
    if ( [host isEqualToString:@""] && [socket isEqualToString:@""] )
    {
        NSRunAlertPanel(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"Please enter at least a host or socket.", @"message of panel when host/socket are missing"), NSLocalizedString(@"OK", @"OK button"), nil, nil);
        [favoritesButton selectItemWithTitle:selectedFavorite];
        return;
    }
//test if all fields are specified for ssh tunnel
	if ( useSSH ) {
		if ( [sshHost isEqualToString:@""] ) {
			sshHost = host;
		}
		if ( [sshUser isEqualToString:@""] ) {
			sshUser = user;
		}
		if ( [sshPassword isEqualToString:@""] ) {
			sshPassword = password;
		}
		if ( [sshPort isEqualToString:@""] ) {
			sshPort = port;
		}
		ssh = [NSNumber numberWithInt:1];
	} else {
		sshHost = @"";
		sshUser = @"";
		sshPassword = @"";
		sshPort = @"";
		ssh = [NSNumber numberWithInt:0];
	}

//test if favorite name isn't used by another favorite and if no favorite with the same host, user and db exists
    while ( (favorite = [enumerator nextObject]) ) {
        if ( [[favorite objectForKey:@"name"] isEqualToString:favoriteName] )
        {
            NSRunAlertPanel(NSLocalizedString(@"Error", @"error"), [NSString stringWithFormat:NSLocalizedString(@"Favorite %@ has already been saved!\nOpen Preferences to change the names of the favorites.", @"message of panel when favorite name has already been used"), favoriteName], NSLocalizedString(@"OK", @"OK button"), nil, nil);
            [favoritesButton selectItemWithTitle:selectedFavorite];
            return;
        }
/*
        if ( [[favorite objectForKey:@"host"] isEqualToString:host] &&
               [[favorite objectForKey:@"user"] isEqualToString:user] &&
               [[favorite objectForKey:@"database"] isEqualToString:database] ) {
            NSRunAlertPanel(@"Error", @"There is already a favorite with the same host, user and database!", @"OK", nil, nil);
            [favoritesButton selectItemWithTitle:selectedFavorite];
            return;
        }
*/
    }

//write favorites and password
    NSDictionary *newFavorite = [NSDictionary
                        dictionaryWithObjects:[NSArray arrayWithObjects:favoriteName, host, socket, user, port, database, ssh, sshHost, sshUser, sshPort, nil]
                        forKeys:[NSArray arrayWithObjects:@"name", @"host", @"socket", @"user", @"port", @"database", @"useSSH", @"sshHost", @"sshUser", @"sshPort", nil]];
    favorites = [[favorites arrayByAddingObject:newFavorite] retain];
    if ( ![password isEqualToString:@""] )
        [keyChainInstance addPassword:password forName:[NSString stringWithFormat:@"CocoaMySQL : %@", favoriteName]
                account:[NSString stringWithFormat:@"%@@%@/%@", user, host, database]];
    if ( ![sshPassword isEqualToString:@""] )
        [keyChainInstance addPassword:sshPassword forName:[NSString stringWithFormat:@"CocoaMySQL SSHTunnel : %@", favoriteName]
                account:[NSString stringWithFormat:@"%@@%@/%@", user, host, database]];
    [prefs setObject:favorites forKey:@"favorites"];

//reload favorites and select new favorite
    [self setFavorites];
    [favoritesButton selectItemWithTitle:favoriteName];
    selectedFavorite = [favoriteName retain];
}


//alert sheets method
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
/*
invoked when alertSheet get closed
if contextInfo == connect -> reopens the connectSheet
if contextInfo == removedatabase -> tries to remove the selected database
*/
{
    [sheet orderOut:self];

    if ( [contextInfo isEqualToString:@"connect"] ) {
        [self connectToDB:nil];
    } else if ( [contextInfo isEqualToString:@"removedatabase"] ) {
        if ( returnCode == NSAlertDefaultReturn ) {
            [mySQLConnection queryString:[NSString stringWithFormat:@"DROP DATABASE `%@`", [self database]]];
            if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
            //db deleted with success
                selectedDatabase = nil;
                [self setDatabases:self];
                [tablesListInstance setConnection:mySQLConnection];
                [tableDumpInstance setConnection:mySQLConnection];
                [tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@@%@/",
                                    mySQLVersion, [userField stringValue], [hostField stringValue]]];
            } else {
            //error while deleting db
                NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
                        [NSString stringWithFormat:NSLocalizedString(@"Couldn't remove database.\nMySQL said: %@", @"message of panel when removing db failed"), [mySQLConnection getLastErrorMessage]]);
            }
        }
    }
}


//database methods
- (IBAction)setDatabases:(id)sender;
/*
sets up the chooseDatabaseButton (adds all databases)
*/
{
    CMMCPResult *queryResult;
    int i;

    [chooseDatabaseButton removeAllItems];
    [chooseDatabaseButton addItemWithTitle:NSLocalizedString(@"Choose database...", @"menu item for choose db")];
    queryResult = [mySQLConnection listDBs];
    for ( i = 0 ; i < [queryResult numOfRows] ; i++ ) {
        [queryResult dataSeek:i];
        [chooseDatabaseButton addItemWithTitle:[[queryResult fetchRowAsArray] objectAtIndex:0]];
    }
    if ( ![self database] ) {
        [chooseDatabaseButton selectItemWithTitle:NSLocalizedString(@"Choose database...", @"menu item for choose db")];
    } else {
        [chooseDatabaseButton selectItemWithTitle:[self database]];
    }
}

- (IBAction)chooseDatabase:(id)sender
/*
selects the database choosen by the user
errorsheet if connection failed
*/
{
    if ( ![tablesListInstance selectionShouldChangeInTableView:nil] ) {
        [chooseDatabaseButton selectItemWithTitle:[self database]];
        return;
    }

    if ( [chooseDatabaseButton indexOfSelectedItem] == 0 ) {
        if ( ![self database] ) {
            [chooseDatabaseButton selectItemWithTitle:NSLocalizedString(@"Choose database...", @"menu item for choose db")];
        } else {
            [chooseDatabaseButton selectItemWithTitle:[self database]];
        }
        return;
    }

    if ( ![mySQLConnection selectDB:[chooseDatabaseButton titleOfSelectedItem]] ) {
//connection failed
        NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
                [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to database %@.\nBe sure that you have the necessary privileges.", @"message of panel when connection to db failed after selecting from popupbutton"),
                    [chooseDatabaseButton titleOfSelectedItem]]);
        [self setDatabases:self];
    } else {
//changed database with success
//setConnection of TablesList and TablesDump to reload tables in db
        [selectedDatabase release];
        selectedDatabase = nil;
        selectedDatabase = [[chooseDatabaseButton titleOfSelectedItem] retain];
        [tablesListInstance setConnection:mySQLConnection];
        [tableDumpInstance setConnection:mySQLConnection];
        [tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@@%@/%@", mySQLVersion, [userField stringValue],
                                    [hostField stringValue], [self database]]];
    }
}

- (IBAction)addDatabase:(id)sender
/*
opens the add-db sheet and creates the new db
*/
{
    int code = 0;

    if ( ![tablesListInstance selectionShouldChangeInTableView:nil] )
        return;

    [databaseNameField setStringValue:@""];
    [NSApp beginSheet:databaseSheet
            modalForWindow:tableWindow modalDelegate:self
            didEndSelector:nil contextInfo:nil];
    code = [NSApp runModalForWindow:databaseSheet];
    
    [NSApp endSheet:databaseSheet];
    [databaseSheet orderOut:nil];

    if ( code ) {
        if ( [[databaseNameField stringValue] isEqualToString:@""] ) {
            NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil, NSLocalizedString(@"Database must have a name.", @"message of panel when no db name is given"));
        } else {
            [mySQLConnection queryString:[NSString stringWithFormat:@"CREATE DATABASE `%@`", [databaseNameField stringValue]]];
            if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
            //db created with success
                if ( ![mySQLConnection selectDB:[databaseNameField stringValue]] ) {
                //error while selecting new db (is this possible?!)
                    NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
                        [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to database %@.\nBe sure that you have the necessary privileges.", @"message of panel when connection to db failed after selecting from popupbutton"),
                            [databaseNameField stringValue]]);
                    [self setDatabases:self];
                } else {
                //select new db
                    [selectedDatabase release];
                    selectedDatabase = nil;
                    selectedDatabase = [[databaseNameField stringValue] retain];
                    [self setDatabases:self];
                    [tablesListInstance setConnection:mySQLConnection];
                    [tableDumpInstance setConnection:mySQLConnection];
                    [tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@@%@/%@",
                                        mySQLVersion, [userField stringValue], [hostField stringValue],
                                        selectedDatabase]];
                }
            } else {
            //error while creating db
                NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
                        [NSString stringWithFormat:NSLocalizedString(@"Couldn't create database.\nMySQL said: %@", @"message of panel when creation of db failed"), [mySQLConnection getLastErrorMessage]]);
            }
        }
    }
}

- (IBAction)closeDatabaseSheet:(id)sender
/*
closes the add-db sheet and stops modal session
*/
{
    [NSApp stopModalWithCode:[sender tag]];
}

- (IBAction)removeDatabase:(id)sender
/*
opens sheet to ask user if he really wants to delete the db
*/
{
    if ( [chooseDatabaseButton indexOfSelectedItem] == 0 )
        return;
    if ( ![tablesListInstance selectionShouldChangeInTableView:nil] )
        return;

    NSBeginAlertSheet(NSLocalizedString(@"Warning", @"warning"), NSLocalizedString(@"Delete", @"delete button"), NSLocalizedString(@"Cancel", @"cancel button"), nil, tableWindow, self, nil,
            @selector(sheetDidEnd:returnCode:contextInfo:), @"removedatabase",
            [NSString stringWithFormat:NSLocalizedString(@"Do you really want to delete the database %@?", @"message of panel asking for confirmation for deleting db"), [self database]] );
}


//console methods
- (void)toggleConsole
/*
shows or hides the console
*/
{
    NSDrawerState state = [consoleDrawer state];
    if (NSDrawerOpeningState == state || NSDrawerOpenState == state) {
        [consoleDrawer close];
    } else {
        [consoleTextView scrollRangeToVisible:[consoleTextView selectedRange]];
        [consoleDrawer openOnEdge:NSMinYEdge];
    }
}

- (void)clearConsole
/*
clears the console
*/
{
    [consoleTextView setString:@""];
}

- (BOOL)consoleIsOpened
/*
returns YES if the console is visible
*/
{
    if ( [consoleDrawer state] == NSDrawerOpeningState || [consoleDrawer state] == NSDrawerOpenState )
    {
        return YES;
    } else {
        return NO;
    }
}

- (void)showMessageInConsole:(NSString *)message
/*
shows a message in the console
*/
{
    int begin, end;

    [consoleTextView setSelectedRange:NSMakeRange([[consoleTextView string] length],0)];
    begin = [[consoleTextView string] length];
    [consoleTextView replaceCharactersInRange:NSMakeRange(begin,0)
            withString:message];
    end = [[consoleTextView string] length];
    [consoleTextView setTextColor:[NSColor blackColor] range:NSMakeRange(begin,end-begin)];
    if ( [self consoleIsOpened] ) {
/*
        NSClipView *clipView = [consoleTextView superview]; 
        if (![clipView isKindOfClass:[NSClipView class]]) return; 
        [clipView scrollToPoint:[clipView constrainScrollPoint:NSMakePoint(0,[consoleTextView frame].size.height)]]; 
        [[clipView superview] reflectScrolledClipView:clipView];
*/
        [consoleTextView displayIfNeeded];
        [consoleTextView scrollRangeToVisible:[consoleTextView selectedRange]];
    }
}

- (void)showErrorInConsole:(NSString *)error
/*
shows an error in the console (red)
*/
{
    int begin, end;
    
    [consoleTextView setSelectedRange:NSMakeRange([[consoleTextView string] length],0)];
    begin = [[consoleTextView string] length];
    [consoleTextView replaceCharactersInRange:NSMakeRange(begin,0)
            withString:error];
    end = [[consoleTextView string] length];
    [consoleTextView setTextColor:[NSColor redColor] range:NSMakeRange(begin,end-begin)];
    if ( [self consoleIsOpened] ) {
/*
        NSClipView *clipView = [consoleTextView superview]; 
        if (![clipView isKindOfClass:[NSClipView class]]) return; 
        [clipView scrollToPoint:[clipView constrainScrollPoint:NSMakePoint(0,[consoleTextView frame].size.height)]]; 
        [[clipView superview] reflectScrolledClipView:clipView];
*/
        [consoleTextView displayIfNeeded];
        [consoleTextView scrollRangeToVisible:[consoleTextView selectedRange]];
    }
}


//encoding methods
- (void)setEncoding:(NSString *)encoding
/*
set the encoding for the database
*/
{
// set encoding of connection and client
    [mySQLConnection queryString:[NSString stringWithFormat:@"SET NAMES '%@'", encoding]];
	if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
		[mySQLConnection setEncoding:[CMMCPConnection encodingForMySQLEncoding:[encoding cString]]];
	} else {
		[self detectEncoding];
	}
//NSLog(@"set encoding to %@", encoding);
		
    [tableSourceInstance reloadTable:self];
    [tableContentInstance reloadTable:self];
    [tableStatusInstance reloadTable:self];

//    int encodingCode;

/*    if( [encoding isEqualToString:@"ISO Latin 1"] ) {
        encodingCode = NSISOLatin1StringEncoding;
    } else if( [encoding isEqualToString:@"ISO Latin 2"] ) {
        encodingCode = NSISOLatin2StringEncoding;
    } else if( [encoding isEqualToString:@"Win Latin 1"] ) {
        encodingCode = NSWindowsCP1252StringEncoding;
    } else if( [encoding isEqualToString:@"Win Latin 2"] ) {
        encodingCode = NSWindowsCP1250StringEncoding;	
    } else if( [encoding isEqualToString:@"Cyrillic"] ) {
        encodingCode = NSWindowsCP1251StringEncoding;
    } else if( [encoding isEqualToString:@"Greek"] ) {
        encodingCode = NSWindowsCP1253StringEncoding;
    } else if( [encoding isEqualToString:@"Turkish"] ) {
        encodingCode = NSWindowsCP1254StringEncoding;
    } else if ( [encoding isEqualToString:@"Shift-JIS"] ) {
        encodingCode = NSShiftJISStringEncoding;
    } else if ( [encoding isEqualToString:@"EUC-JP"] ) {
        encodingCode = NSJapaneseEUCStringEncoding;
    } else if ( [encoding isEqualToString:@"ISO 2022-JP"] ) {
        encodingCode = NSISO2022JPStringEncoding;
    } else if ( [encoding isEqualToString:@"UTF-8"] ) {
        encodingCode = NSUTF8StringEncoding;
*/
/*
    if( [encoding isEqualToString:@"ISO Latin 1"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatin1);
    } else if( [encoding isEqualToString:@"ISO Latin 2"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatin2);
    } else if ( [encoding isEqualToString:@"ISO Cyrillic"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinCyrillic);
    } else if ( [encoding isEqualToString:@"ISO Greek"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinGreek);
    } else if ( [encoding isEqualToString:@"ISO Turkish"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatin5);
    } else if ( [encoding isEqualToString:@"ISO Arabic"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinArabic);
    } else if ( [encoding isEqualToString:@"ISO Hebrew"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinHebrew);
    } else if ( [encoding isEqualToString:@"ISO Thai"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinThai);

    } else if( [encoding isEqualToString:@"Win Latin 1"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsLatin1);
    } else if( [encoding isEqualToString:@"Win Latin 2"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsLatin2);
    } else if( [encoding isEqualToString:@"Win Cyrillic"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsCyrillic);
    } else if( [encoding isEqualToString:@"Win Greek"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsGreek);
    } else if( [encoding isEqualToString:@"Win Turkish"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsLatin5);
    } else if( [encoding isEqualToString:@"Win Arabic"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsArabic);
    } else if( [encoding isEqualToString:@"Win Baltic Rim"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsBalticRim);
    } else if( [encoding isEqualToString:@"Win Korean"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsKoreanJohab);
    } else if( [encoding isEqualToString:@"Win Vietnamese"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsVietnamese);

    } else if ( [encoding isEqualToString:@"Shift-JIS"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingShiftJIS);
    } else if ( [encoding isEqualToString:@"EUC-JP"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_JP);
    } else if ( [encoding isEqualToString:@"ISO 2022-JP"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISO_2022_JP);

    } else if ( [encoding isEqualToString:@"EUC-CN"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_CN);
    } else if ( [encoding isEqualToString:@"EUC-TW"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_TW);
    } else if ( [encoding isEqualToString:@"EUC-KR"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_KR);

    } else if ( [encoding isEqualToString:@"ISO 2022-KR"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISO_2022_KR);
    } else if ( [encoding isEqualToString:@"ISO 2022-CN"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISO_2022_CN);

    } else if ( [encoding isEqualToString:@"KOI8-R"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingKOI8_R);
    } else if ( [encoding isEqualToString:@"HZ"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingHZ_GB_2312);

    } else if ( [encoding isEqualToString:@"UTF-8"] ) {
        encodingCode = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF8);

    } else {
        encodingCode = NSISOLatin1StringEncoding; // default is ISO Latin 1
    }
    
    if(encodingCode == kCFStringEncodingInvalidId)
        encodingCode = NSISOLatin1StringEncoding;
*/
}

- (void)detectEncoding
/*
autodetects the connection encoding and sets the encoding dropdown
*/
{
	id mysqlEncoding;
	
	// mysql > 4.0
	mysqlEncoding = [[[mySQLConnection queryString:@"SHOW VARIABLES LIKE 'character_set_connection'"] fetchRowAsDictionary] objectForKey:@"Value"];
	if ( [mysqlEncoding isKindOfClass:[NSData class]] ) {
	// MySQL 4.1.14 returns the mysql variables as nsdata
		mysqlEncoding = [mySQLConnection stringWithText:mysqlEncoding];
	}
	if ( !mysqlEncoding ) {
	// mysql 4.0 or older -> only default character set possible, cannot choose others using "set names xy"
		mysqlEncoding = [[[mySQLConnection queryString:@"SHOW VARIABLES LIKE 'character_set'"] fetchRowAsDictionary] objectForKey:@"Value"];
		[chooseEncodingButton setEnabled:NO];
	}
	if ( !mysqlEncoding ) {
	// older version? -> set encoding to mysql default encoding latin1, chooseEncodingButton is already disabled
		NSLog(@"error: no character encoding found, mysql version is %@", [self mySQLVersion]);
		mysqlEncoding = @"latin1";
	}
	[mySQLConnection setEncoding:[CMMCPConnection encodingForMySQLEncoding:[mysqlEncoding cString]]];	

//NSLog(@"autodetected %@", mysqlEncoding);

	if ( [mysqlEncoding isEqualToString:@"ucs2"] ) {
		[chooseEncodingButton selectItemWithTitle:@"UCS-2 Unicode (ucs2)"];
	} else if ( [mysqlEncoding isEqualToString:@"utf8"] ) {
		[chooseEncodingButton selectItemWithTitle:@"UTF-8 Unicode (utf8)"];
	} else if ( [mysqlEncoding isEqualToString:@"ascii"] ) {
		[chooseEncodingButton selectItemWithTitle:@"US ASCII (ascii)"];
	} else if ( [mysqlEncoding isEqualToString:@"latin1"] ) {
		[chooseEncodingButton selectItemWithTitle:@"ISO Latin 1 (latin1)"];
	} else if ( [mysqlEncoding isEqualToString:@"macroman"] ) {
		[chooseEncodingButton selectItemWithTitle:@"Mac Roman (macroman)"];
	} else if ( [mysqlEncoding isEqualToString:@"cp1250"] ) {
		[chooseEncodingButton selectItemWithTitle:@"Windows Latin 2 (cp1250)"];
	} else if ( [mysqlEncoding isEqualToString:@"latin2"] ) {
		[chooseEncodingButton selectItemWithTitle:@"ISO Latin 2 (latin2)"];
	} else if ( [mysqlEncoding isEqualToString:@"cp1256"] ) {
		[chooseEncodingButton selectItemWithTitle:@"Windows Arabic (cp1256)"];
	} else if ( [mysqlEncoding isEqualToString:@"greek"] ) {
		[chooseEncodingButton selectItemWithTitle:@"ISO Greek (greek)"];
	} else if ( [mysqlEncoding isEqualToString:@"hebrew"] ) {
		[chooseEncodingButton selectItemWithTitle:@"ISO Hebrew (hebrew)"];
	} else if ( [mysqlEncoding isEqualToString:@"latin5"] ) {
		[chooseEncodingButton selectItemWithTitle:@"ISO Turkish (latin5)"];
	} else if ( [mysqlEncoding isEqualToString:@"cp1257"] ) {
		[chooseEncodingButton selectItemWithTitle:@"Windows Baltic (cp1257)"];
	} else if ( [mysqlEncoding isEqualToString:@"cp1251"] ) {
		[chooseEncodingButton selectItemWithTitle:@"Windows Cyrillic (cp1251)"];
	} else if ( [mysqlEncoding isEqualToString:@"big5"] ) {
		[chooseEncodingButton selectItemWithTitle:@"Big5 Traditional Chinese (big5)"];
	} else if ( [mysqlEncoding isEqualToString:@"sjis"] ) {
		[chooseEncodingButton selectItemWithTitle:@"Shift-JIS Japanese (sjis)"];
	} else if ( [mysqlEncoding isEqualToString:@"ujis"] ) {
		[chooseEncodingButton selectItemWithTitle:@"EUC-JP Japanese (ujis)"];
	} else {
		NSLog(@"unsupported encoding %@! falling back to utf8.", mysqlEncoding);
		[chooseEncodingButton selectItemWithTitle:@"UTF-8 Unicode (utf8)"];
		[self setEncoding:[self getSelectedEncoding]];
	}
}

- (NSString *)getSelectedEncoding
/*
gets the selected mysql encoding
*/
{
	NSString *mysqlEncoding;
	NSString *encoding = [chooseEncodingButton titleOfSelectedItem];

// unicode
	if ( [encoding isEqualToString:@"UCS-2 Unicode (ucs2)"] ) {
		mysqlEncoding = @"ucs2";
	} else if ( [encoding isEqualToString:@"UTF-8 Unicode (utf8)"] ) {
		mysqlEncoding = @"utf8";
// west european
	} else if( [encoding isEqualToString:@"US ASCII (ascii)"] ) {
		mysqlEncoding = @"ascii";
	} else if ( [encoding isEqualToString:@"ISO Latin 1 (latin1)"] ) {
		mysqlEncoding = @"latin1";
	} else if ( [encoding isEqualToString:@"Mac Roman (macroman)"] ) {
		mysqlEncoding = @"macroman";
// central european
	} else if ( [encoding isEqualToString:@"Windows Latin 2 (cp1250)"] ) {
		mysqlEncoding = @"cp1250";
	} else if ( [encoding isEqualToString:@"ISO Latin 2 (latin2)"] ) {
		mysqlEncoding = @"latin2";
// south european and middle east
	} else if ( [encoding isEqualToString:@"Windows Arabic (cp1256)"] ) {
		mysqlEncoding = @"cp1256";
	} else if ( [encoding isEqualToString:@"ISO Greek (greek)"] ) {
		mysqlEncoding = @"greek";
	} else if ( [encoding isEqualToString:@"ISO Hebrew (hebrew)"] ) {
		mysqlEncoding = @"hebrew";
	} else if ( [encoding isEqualToString:@"ISO Turkish (latin5)"] ) {
		mysqlEncoding = @"latin5";
// baltic
	} else if ( [encoding isEqualToString:@"Windows Baltic (cp1257)"] ) {
		mysqlEncoding = @"cp1257";
// cyrillic
	} else if ( [encoding isEqualToString:@"Windows Cyrillic (cp1251)"] ) {
		mysqlEncoding = @"cp1251";
// asian
	} else if ( [encoding isEqualToString:@"Big5 Traditional Chinese (big5)"] ) {
		mysqlEncoding = @"big5";
	} else if ( [encoding isEqualToString:@"Shift-JIS Japanese (sjis)"] ) {
		mysqlEncoding = @"sjis";
	} else if ( [encoding isEqualToString:@"EUC-JP Japanese (ujis)"] ) {
		mysqlEncoding = @"ujis";
	} else {
// unknown encoding
		NSLog(@"error: unknown encoding %@", encoding);
		mysqlEncoding = @"utf8";
	}
	
	return [mysqlEncoding autorelease];
}

- (IBAction)chooseEncoding:(id)sender
/*
choose encoding
*/
{
    // Set encoding
    [self setEncoding:[self getSelectedEncoding]];
}

- (BOOL)supportsEncoding
/*
returny YES if MySQL server supports choosing connection and table encodings (MySQL 4.1 and newer)
*/
{
	return [chooseEncodingButton isEnabled];
}


//other methods
- (NSString *)host
/*
returns the host
*/
{
    return [hostField stringValue];
}

- (void)doPerformQueryService:(NSString *)query
/*
passes query to tablesListInstance
*/
{
    [tableWindow makeKeyAndOrderFront:self];
    [tablesListInstance doPerformQueryService:query];
}

- (void)flushPrivileges
/*
flushes the mysql privileges
*/
{
    [mySQLConnection queryString:@"FLUSH PRIVILEGES"];
    
    if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
    //flushed privileges without errors
        NSBeginAlertSheet(NSLocalizedString(@"Flushed Privileges", @"title of panel when successfully flushed privs"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
                NSLocalizedString(@"Succesfully flushed privileges.", @"message of panel when successfully flushed privs"));
    } else {
    //error while flushing privileges
        NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
                [NSString stringWithFormat:NSLocalizedString(@"Couldn't flush privileges.\nMySQL said: %@", @"message of panel when flushing privs failed"),
                                [mySQLConnection getLastErrorMessage]]);
    }
}

- (void)openTableOperationsSheet
/*
opens the sheet for table operations (check/analyze/optimize/repair/flush) and performs desired operation
*/
{
	int code, operation;
    CMMCPResult *theResult;
    NSDictionary *theRow;
	NSString *query;
    NSString *operationText;
    NSString *messageType;
    NSString *messageText;

    [NSApp beginSheet:tableOperationsSheet
            modalForWindow:tableWindow modalDelegate:self
            didEndSelector:nil contextInfo:nil];
    code = [NSApp runModalForWindow:tableOperationsSheet];
    
    [NSApp endSheet:tableOperationsSheet];
    [tableOperationsSheet orderOut:nil];
NSLog(@"%d",code);
	if ( !code )
		return;

	// get operation
	operation = [[chooseTableOperationButton selectedItem] tag];
	switch ( operation ) {
		case 0:
		// check table
			query = [NSString stringWithFormat:@"CHECK TABLE `%@`", [self table]];
			break;
		case 1:
		// analyze table
			query = [NSString stringWithFormat:@"ANALYZE TABLE `%@`", [self table]];
			break;
		case 2:
		// optimize table
			query = [NSString stringWithFormat:@"OPTIMIZE TABLE `%@`", [self table]];
			break;
		case 3:
		// repair table
			query = [NSString stringWithFormat:@"REPAIR TABLE `%@`", [self table]];
			break;
		case 4:
		// flush table
			query = [NSString stringWithFormat:@"FLUSH TABLE `%@`", [self table]];
			break;
	}

    // perform operation
    theResult = [mySQLConnection queryString:query];

    if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
    // no errors
		if ( operation == 4 ) {
		// flushed -> no return values
			operationText = [NSString stringWithString:@"flush"];
			messageType = [NSString stringWithString:@"-"];
			messageText = [NSString stringWithString:@"-"];
		} else {
		// other operations -> get return values
			theRow = [[theResult fetch2DResultAsType:MCPTypeDictionary] lastObject];
			operationText = [NSString stringWithString:[theRow objectForKey:@"Op"]];
			messageType = [NSString stringWithString:[theRow objectForKey:@"Msg_type"]];
			messageText = [NSString stringWithString:[theRow objectForKey:@"Msg_text"]];
		}
		NSBeginAlertSheet(NSLocalizedString(@"Successfully performed table operation", @"title of panel when successfully performed table operation"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
				[NSString stringWithFormat:NSLocalizedString(@"Operation: %@\nMsg_type: %@\nMsg_text: %@", @"message of panel when successfully performed table operation"),
										operationText, messageType, messageText]);
    } else {
    // error
        NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
                [NSString stringWithFormat:NSLocalizedString(@"Couldn't perform table operation.\nMySQL said: %@", @"message of panel when table operation failed"),
                                [mySQLConnection getLastErrorMessage]]);
    }
}

- (IBAction)doTableOperation:(id)sender
/*
closes the sheet and ends modal with 0 if cancel and 1 if ok
*/
{
	[NSApp stopModalWithCode:[sender tag]];
}

- (void)showVariables
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
    for ( i = 0 ; i < [theResult numOfRows] ; i++ ) {
        [theResult dataSeek:i];
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

- (void)showCreateTable
/*
shows the mysql command used to create the selected table
*/
{
	id createTableSyntax;

    CMMCPResult *result = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE TABLE `%@`",
                                                            [self table]]];
	createTableSyntax = [[result fetchRowAsArray] objectAtIndex:1];
    if ( [createTableSyntax isKindOfClass:[NSData class]] ) {
        createTableSyntax = [[NSString alloc] initWithData:createTableSyntax encoding:[mySQLConnection encoding]];
    }

    [createTableSyntaxView setString:createTableSyntax];
    [createTableSyntaxView selectAll:self];

    //show createTableSyntaxSheet
    [NSApp beginSheet:createTableSyntaxSheet
            modalForWindow:tableWindow modalDelegate:self
            didEndSelector:nil contextInfo:nil];
    [NSApp runModalForWindow:createTableSyntaxSheet];
    
    [NSApp endSheet:createTableSyntaxSheet];
    [createTableSyntaxSheet orderOut:nil];
}

- (void)closeConnection
{
    [mySQLConnection disconnect];
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
    return [tablesListInstance table];
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
    [queryProgressBar startAnimation:self];
}

- (void)hasPerformedQuery:(NSNotification *)notification
/*
invoked after a query has been performed
*/
{
    [queryProgressBar stopAnimation:self];
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
	NSLog([tunnel status]);
}

//menu methods
- (IBAction)import:(id)sender
/*
passes the request to the tableDump object
*/
{
    [tableDumpInstance importFile:[sender tag]];
}

- (IBAction)export:(id)sender
/*
passes the request to the tableDump object
*/
{
    [tableDumpInstance exportFile:[sender tag]];
}

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
/*
do menu validation
*/
{
    switch ( [anItem tag] ) {
        case 1:
        //import dump
            if ( ![self database] ) {
                return NO;
            }
        break;
        case 2:
        //import CSV
            if ( ![self database] || ![self table] ) {
                return NO;
            }
        break;
        case 5:
        //export dump
            if ( ![self database] ) {
                return NO;
            }
        break;
        case 6:
        //export table content as CSV
            if ( ![self database] || ![self table] ) {
                return NO;
            }
        break;
        case 7:
        //export table content as XML
            if ( ![self database] || ![self table] ) {
                return NO;
            }
        break;
        case 8:
        //export custom result as CSV
            return YES;
        break;
        case 9:
        //export custom result as XML
            return YES;
        break;
        case 10:
        //export multiple tables as CSV
            if ( ![self database] ) {
                return NO;
            }
        break;
        case 11:
        //export multiple tables as XML
            if ( ![self database] ) {
                return NO;
            }
        break;
    }
    return YES;
}

- (IBAction)viewStructure:(id)sender
{
    [tableTabView selectTabViewItemAtIndex:0];
}

- (IBAction)viewContent:(id)sender
{
    [tableTabView selectTabViewItemAtIndex:1];
}

- (IBAction)viewQuery:(id)sender
{
    [tableTabView selectTabViewItemAtIndex:2];
}

- (IBAction)viewStatus:(id)sender
{
    [tableTabView selectTabViewItemAtIndex:3];
}


//toolbar methods
- (void)setupToolbar
/*
set up the standard toolbar
*/
{
    //create a new toolbar instance, and attach it to our document window 
    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"TableWindowToolbar"] autorelease];

    //set up toolbar properties
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];

    //set ourself as the delegate
    [toolbar setDelegate:self];

    //attach the toolbar to the document window
    [tableWindow setToolbar:toolbar];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
/*
toolbar delegate method
*/
{
    NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
    
    if ([itemIdentifier isEqualToString:@"ToggleConsoleIdentifier"]) {
	//set the text label to be displayed in the toolbar and customization palette 
	[toolbarItem setPaletteLabel:NSLocalizedString(@"Show/Hide Console", @"toolbar item for show/hide console")];
	//set up tooltip and image
	[toolbarItem setToolTip:NSLocalizedString(@"Show or hide the console which shows all MySQL commands performed by CocoaMySQL", @"tooltip for toolbar item for show/hide console")];
        if ( [self consoleIsOpened] ) {
            [toolbarItem setLabel:NSLocalizedString(@"Hide Console", @"toolbar item for hide console")];
            [toolbarItem setImage:[NSImage imageNamed:@"hideconsole"]];
        } else {
            [toolbarItem setLabel:NSLocalizedString(@"Show Console", @"toolbar item for showconsole")];
            [toolbarItem setImage:[NSImage imageNamed:@"showconsole"]];
        }
	//set up the target action
	[toolbarItem setTarget:self];
	[toolbarItem setAction:@selector(toggleConsole)];
    } else if ([itemIdentifier isEqualToString:@"ClearConsoleIdentifier"]) {
	//set the text label to be displayed in the toolbar and customization palette 
	[toolbarItem setLabel:NSLocalizedString(@"Clear Console", @"toolbar item for clear console")];
	[toolbarItem setPaletteLabel:NSLocalizedString(@"Clear Console", @"toolbar item for clear console")];
	//set up tooltip and image
	[toolbarItem setToolTip:NSLocalizedString(@"Clear the console which shows all MySQL commands performed by CocoaMySQL", @"tooltip for toolbar item for clear console")];
	[toolbarItem setImage:[NSImage imageNamed:@"clearconsole"]];
	//set up the target action
	[toolbarItem setTarget:self];
	[toolbarItem setAction:@selector(clearConsole)];
    } else if ([itemIdentifier isEqualToString:@"FlushPrivilegesIdentifier"]) {
	//set the text label to be displayed in the toolbar and customization palette 
	[toolbarItem setLabel:NSLocalizedString(@"Flush Privileges", @"toolbar item for flush privileges")];
	[toolbarItem setPaletteLabel:NSLocalizedString(@"Flush Privileges", @"toolbar item for flush privileges")];
	//set up tooltip and image
	[toolbarItem setToolTip:NSLocalizedString(@"Reload the MySQL privileges saved in the mysql database", @"tooltip for toolbar item for flush privileges")];
	[toolbarItem setImage:[NSImage imageNamed:@"flushprivileges"]];
	//set up the target action
	[toolbarItem setTarget:self];
	[toolbarItem setAction:@selector(flushPrivileges)];
    } else if ([itemIdentifier isEqualToString:@"OptimizeTableIdentifier"]) {
	//set the text label to be displayed in the toolbar and customization palette 
	[toolbarItem setLabel:NSLocalizedString(@"Table Operations", @"toolbar item for perform table operations")];
	[toolbarItem setPaletteLabel:NSLocalizedString(@"Table Operations", @"toolbar item for perform table operations")];
	//set up tooltip and image
	[toolbarItem setToolTip:NSLocalizedString(@"Perform table operations for the selected table", @"tooltip for toolbar item for perform table operations")];
	[toolbarItem setImage:[NSImage imageNamed:@"optimizetable"]];
	//set up the target action
	[toolbarItem setTarget:self];
	[toolbarItem setAction:@selector(openTableOperationsSheet)];
    } else if ([itemIdentifier isEqualToString:@"ShowVariablesIdentifier"]) {
	//set the text label to be displayed in the toolbar and customization palette 
	[toolbarItem setLabel:NSLocalizedString(@"Show Variables", @"toolbar item for show variables")];
	[toolbarItem setPaletteLabel:NSLocalizedString(@"Show Variables", @"toolbar item for show variables")];
	//set up tooltip and image
	[toolbarItem setToolTip:NSLocalizedString(@"Show the MySQL Variables", @"tooltip for toolbar item for show variables")];
	[toolbarItem setImage:[NSImage imageNamed:@"showvariables"]];
	//set up the target action
	[toolbarItem setTarget:self];
	[toolbarItem setAction:@selector(showVariables)];
    } else if ([itemIdentifier isEqualToString:@"ShowCreateTableIdentifier"]) {
	//set the text label to be displayed in the toolbar and customization palette 
	[toolbarItem setLabel:NSLocalizedString(@"Create Table Syntax", @"toolbar item for create table syntax")];
	[toolbarItem setPaletteLabel:NSLocalizedString(@"Create Table Syntax", @"toolbar item for create table syntax")];
	//set up tooltip and image
	[toolbarItem setToolTip:NSLocalizedString(@"Show the MySQL command used to create the selected table", @"tooltip for toolbar item for create table syntax")];
	[toolbarItem setImage:[NSImage imageNamed:@"createtablesyntax"]];
	//set up the target action
	[toolbarItem setTarget:self];
	[toolbarItem setAction:@selector(showCreateTable)];
    } else {
	//itemIdentifier refered to a toolbar item that is not provided or supported by us or cocoa 
	toolbarItem = nil;
    }
    
    return toolbarItem;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
/*
toolbar delegate method
*/
{
    return [NSArray arrayWithObjects:@"ToggleConsoleIdentifier", @"ClearConsoleIdentifier", @"ShowVariablesIdentifier", @"FlushPrivilegesIdentifier", @"OptimizeTableIdentifier", @"ShowCreateTableIdentifier", NSToolbarCustomizeToolbarItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier, nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
/*
toolbar delegate method
*/
{
    return [NSArray arrayWithObjects:@"ToggleConsoleIdentifier", @"ClearConsoleIdentifier",  NSToolbarSeparatorItemIdentifier, @"ShowVariablesIdentifier", @"FlushPrivilegesIdentifier", NSToolbarSeparatorItemIdentifier, @"OptimizeTableIdentifier", @"ShowCreateTableIdentifier", nil];
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem;
/*
validates the toolbar items
*/
{
    if ( [[toolbarItem itemIdentifier] isEqualToString:@"OptimizeTableIdentifier"] ) {
        if ( ![self table] )
            return NO;
    } else if ( [[toolbarItem itemIdentifier] isEqualToString:@"ShowCreateTableIdentifier"] ) {
        if ( ![self table] )
            return NO;
    } else if ( [[toolbarItem itemIdentifier] isEqualToString:@"ToggleConsoleIdentifier"] ) {
        if ( [self consoleIsOpened] ) {
            [toolbarItem setLabel:@"Hide Console"];
            [toolbarItem setImage:[NSImage imageNamed:@"hideconsole"]];
        } else {
            [toolbarItem setLabel:@"Show Console"];
            [toolbarItem setImage:[NSImage imageNamed:@"showconsole"]];
        }
    }
    
    return YES;
}


//NSDocument methods
- (NSString *)windowNibName
/*
returns the name of the nib file
*/
{
    return @"DBView";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
/*
code that need to be executed once the windowController has loaded the document's window
sets upt the interface (small fonts)
*/
{
    [aController setShouldCascadeWindows:NO];
    [super windowControllerDidLoadNib:aController];

    NSEnumerator *theCols = [[variablesTableView tableColumns] objectEnumerator];
    NSTableColumn *theCol;

//    [tableWindow makeKeyAndOrderFront:self];

    prefs = [[NSUserDefaults standardUserDefaults] retain];
    if ( [prefs objectForKey:@"favorites"] != nil ) {
        favorites = [[NSArray alloc] initWithArray:[prefs objectForKey:@"favorites"]];
    } else {
        favorites = [[NSArray array] retain];
    }
    selectedFavorite = [[NSString alloc] initWithString:NSLocalizedString(@"Custom", @"menu item for custom connection")];
    
    //register for notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willPerformQuery:)
            name:@"SMySQLQueryWillBePerformed" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hasPerformedQuery:)
            name:@"SMySQLQueryHasBeenPerformed" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)
            name:@"NSApplicationWillTerminateNotification" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tunnelStatusChanged:) 
						  name: @"STMStatusChanged" object: nil];

    //set up interface
    if ( [prefs boolForKey:@"useMonospacedFonts"] ) {
        [consoleTextView setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
        [createTableSyntaxView setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
        while ( (theCol = [theCols nextObject]) ) {
            [[theCol dataCell] setFont:[NSFont fontWithName:@"Monaco" size:10]];
        }
    } else {
        [consoleTextView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
        [createTableSyntaxView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
        while ( (theCol = [theCols nextObject]) ) {
            [[theCol dataCell] setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
        }
    }
    [consoleDrawer setContentSize:NSMakeSize(110,110)];

    //set up toolbar
    [self setupToolbar];



//tunnel test
/*
NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:@"CocoaMySQL Tunnel",@"connName",
				@"xy",@"connUser",
				@"textor.ch",@"connHost",
				[NSNumber numberWithBool:YES],@"connAuth",
				[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:@"8888",@"port",
							@"textor.ch",@"host",
							@"3306",@"hostport",
							nil]],@"tunnelsLocal",
				nil];
tunnel = [[SSHTunnel alloc] initWithDictionary:args];
[tunnel startTunnel];
*/
//sleep(3);
//[tunnel startTunnelWithArguments:args];
//end tunnel test


    [self connectToDB:nil];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
    [self closeConnection];

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


//SMySQL delegate methods
- (void)willQueryString:(NSString *)query
/*
invoked when framework will perform a query
*/
{
    NSString *currentTime = [[NSDate date] descriptionWithCalendarFormat:@"%H:%M:%S" timeZone:nil locale:nil];
    
    [self showMessageInConsole:[NSString stringWithFormat:@"/* MySQL %@ */ %@;\n", currentTime, query]];
}

- (void)queryGaveError:(NSString *)error
/*
invoked when query gave an error
*/
{
    NSString *currentTime = [[NSDate date] descriptionWithCalendarFormat:@"%H:%M:%S" timeZone:nil locale:nil];
    
    [self showErrorInConsole:[NSString stringWithFormat:@"/* ERROR %@ */ %@;\n", currentTime, error]];
}


//splitView delegate methods
- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
/*
tells the splitView that it can collapse views
*/
{
    return YES;
}

- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
/*
defines max position of splitView
*/
{
        return proposedMax - 600;
}

- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
/*
defines min position of splitView
*/
{
        return proposedMin + 160;
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
    }

    return theValue;
}


//for freeing up memory
- (void)dealloc
{
//    NSLog(@"TableDocument dealloc");

    [mySQLConnection release];
    [favorites release];
    if (nil != variables )
    {
        [variables release];
    }
    [selectedDatabase release];
    [selectedFavorite release];
    [mySQLVersion release];
    [prefs release];
    
    [super dealloc];
}

@end
