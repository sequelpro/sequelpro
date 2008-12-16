//
//  MainController.m
//  sequel-pro
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
//  More info at <http://code.google.com/p/sequel-pro/>
//  Or mail to <lorenz@textor.ch>

#import "MainController.h"
#import "KeyChain.h"
#import "TableDocument.h"

@implementation MainController

/*
opens the preferences window
*/
- (IBAction)openPreferences:(id)sender
{
	//get favorites if they exist
	[favorites release];
	if ( [prefs objectForKey:@"favorites"] != nil ) {
		favorites = [[NSMutableArray alloc] initWithArray:[prefs objectForKey:@"favorites"]];
	} else {
		favorites = [[NSMutableArray array] retain];
	}
	[tableView reloadData];

	if ( [prefs boolForKey:@"reloadAfterAdding"] ) {
		[reloadAfterAddingSwitch setState:NSOnState];
	} else {
		[reloadAfterAddingSwitch setState:NSOffState];
	}
	if ( [prefs boolForKey:@"reloadAfterEditing"] ) {
		[reloadAfterEditingSwitch setState:NSOnState];
	} else {
		[reloadAfterEditingSwitch setState:NSOffState];
	}
	if ( [prefs boolForKey:@"reloadAfterRemoving"] ) {
		[reloadAfterRemovingSwitch setState:NSOnState];
	} else {
		[reloadAfterRemovingSwitch setState:NSOffState];
	}
	if ( [prefs boolForKey:@"showError"] ) {
		[showErrorSwitch setState:NSOnState];
	} else {
		[showErrorSwitch setState:NSOffState];
	}
	if ( [prefs boolForKey:@"dontShowBlob"] ) {
		[dontShowBlobSwitch setState:NSOnState];
	} else {
		[dontShowBlobSwitch setState:NSOffState];
	}
	if ( [prefs boolForKey:@"limitRows"] ) {
		[limitRowsSwitch setState:NSOnState];
	} else {
		[limitRowsSwitch setState:NSOffState];
	}
	if ( [prefs boolForKey:@"useMonospacedFonts"] ) {
		[useMonospacedFontsSwitch setState:NSOnState];
	} else {
		[useMonospacedFontsSwitch setState:NSOffState];
	}
	if ( [prefs boolForKey:@"fetchRowCount"] ) {
		[fetchRowCountSwitch setState:NSOnState];
	} else {
		[fetchRowCountSwitch setState:NSOffState];
	}
	[nullValueField setStringValue:[prefs stringForKey:@"nullValue"]];
	[limitRowsField setStringValue:[prefs stringForKey:@"limitRowsValue"]];
	[self chooseLimitRows:self];
	[encodingPopUpButton selectItemWithTitle:[prefs stringForKey:@"encoding"]];

	[preferencesWindow makeKeyAndOrderFront:self];
}

/*
adds a favorite
*/
- (IBAction)addFavorite:(id)sender
{
	int code;

	isNewFavorite = YES;

	[nameField setStringValue:@""];
	[hostField setStringValue:@""];
	[socketField setStringValue:@""];
	[userField setStringValue:@""];
	[passwordField setStringValue:@""];
	[portField setStringValue:@""];
	[databaseField setStringValue:@""];
	[sshCheckbox setState:NSOffState];
	[sshUserField setEnabled:NO];
	[sshPasswordField setEnabled:NO];
	[sshHostField setEnabled:NO];
	[sshPortField setEnabled:NO];
	[sshHostField setStringValue:@""];
	[sshUserField setStringValue:@""];
	[sshPortField setStringValue:@"8888"];
	[sshPasswordField setStringValue:@""];

	[NSApp beginSheet:favoriteSheet
	   modalForWindow:preferencesWindow
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
	
	code = [NSApp runModalForWindow:favoriteSheet];
	
	[NSApp endSheet:favoriteSheet];
	[favoriteSheet orderOut:nil];
	
	if ( code == 1 ) {
		if ( ![[socketField stringValue] isEqualToString:@""] ) {
			//set host to localhost if socket is used
			[hostField setStringValue:@"localhost"];
		}
		
		// get ssh settings
		NSString *sshHost, *sshUser, *sshPassword, *sshPort;
		NSNumber *ssh;
		if ( [sshCheckbox state] == NSOnState ) {
			if ( [[sshHostField stringValue] isEqualToString:@""] ) {
				sshHost = [hostField stringValue];
			} else {
				sshHost = [sshHostField stringValue];
			}
			if ( [[sshUserField stringValue] isEqualToString:@""] ) {
				sshUser = [userField stringValue];
			} else {
				sshUser = [sshUserField stringValue];
			}
			if ( [[sshPasswordField stringValue] isEqualToString:@""] ) {
				sshPassword = [passwordField stringValue];
			} else {
				sshPassword = [sshPasswordField stringValue];
			}
			if ( [[sshPortField stringValue] isEqualToString:@""] ) {
				sshPort = [portField stringValue];
			} else {
				sshPort = [sshPortField stringValue];
			}
			ssh = [NSNumber numberWithInt:1];
		} else {
			sshHost = @"";
			sshUser = @"";
			sshPassword = @"";
			sshPort = @"";
			ssh = [NSNumber numberWithInt:0];
		}
		
		NSDictionary *favorite = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[nameField stringValue], [hostField stringValue], [socketField stringValue], [userField stringValue], [portField stringValue], [databaseField stringValue], ssh, sshHost, sshUser, sshPort, nil]
															 forKeys:[NSArray arrayWithObjects:@"name", @"host", @"socket", @"user", @"port", @"database", @"useSSH", @"sshHost", @"sshUser", @"sshPort", nil]];
		[favorites addObject:favorite];
		
		if ( ![[passwordField stringValue] isEqualToString:@""] )
			[keyChainInstance addPassword:[passwordField stringValue]
								  forName:[NSString stringWithFormat:@"Sequel Pro : %@", [nameField stringValue]]
								  account:[NSString stringWithFormat:@"%@@%@/%@", [userField stringValue], [hostField stringValue], [databaseField stringValue]]];
		
		if ( ![sshPassword isEqualToString:@""] )
			[keyChainInstance addPassword:sshPassword
								  forName:[NSString stringWithFormat:@"Sequel Pro SSHTunnel : %@", [nameField stringValue]]
								  account:[NSString stringWithFormat:@"%@@%@/%@", [userField stringValue], [hostField stringValue],	[databaseField stringValue]]];
		
		[tableView reloadData];
		[tableView selectRow:[tableView numberOfRows]-1 byExtendingSelection:NO];
	}
	
	isNewFavorite = NO;
}

/*
removes a favorite
*/
- (IBAction)removeFavorite:(id)sender
{
	if ( ![tableView numberOfSelectedRows] )
		return;

	NSString *name = [[favorites objectAtIndex:[tableView selectedRow]] objectForKey:@"name"];
	NSString *user = [[favorites objectAtIndex:[tableView selectedRow]] objectForKey:@"user"];
	NSString *host = [[favorites objectAtIndex:[tableView selectedRow]] objectForKey:@"host"];
	NSString *database = [[favorites objectAtIndex:[tableView selectedRow]] objectForKey:@"database"];
	
	[keyChainInstance deletePasswordForName:[NSString stringWithFormat:@"Sequel Pro : %@", name]
									account:[NSString stringWithFormat:@"%@@%@/%@", user, host, database]];
	[keyChainInstance deletePasswordForName:[NSString stringWithFormat:@"Sequel Pro SSHTunnel : %@", name]
									account:[NSString stringWithFormat:@"%@@%@/%@", user, host, database]];
	[favorites removeObjectAtIndex:[tableView selectedRow]];
	[tableView reloadData];
}

/*
copies a favorite
*/
- (IBAction)copyFavorite:(id)sender
{
	if ( ![tableView numberOfSelectedRows] )
		return;
		
	NSMutableDictionary *tempDictionary = [NSMutableDictionary dictionaryWithDictionary:[favorites objectAtIndex:[tableView selectedRow]]];
	[tempDictionary setObject:[NSString stringWithFormat:@"%@Copy", [tempDictionary objectForKey:@"name"]] forKey:@"name"];
//	[tempDictionary setObject:[NSString stringWithFormat:@"%@Copy", [tempDictionary objectForKey:@"user"]] forKey:@"user"];

	[favorites insertObject:tempDictionary atIndex:[tableView selectedRow]+1];
	[tableView selectRow:[tableView selectedRow]+1 byExtendingSelection:NO];

	[tableView reloadData];
}

/*
enables or disables limitRowsField (depending on the state of limitRowsSwitch)
*/
- (IBAction)chooseLimitRows:(id)sender
{
	if ( [limitRowsSwitch state] == NSOnState ) {
		[limitRowsField setEnabled:YES];
		[limitRowsField selectText:self];
	} else {
		[limitRowsField setEnabled:NO];
	}
}

/*
close the favoriteSheet and save favorite if user hit save
*/
- (IBAction)closeFavoriteSheet:(id)sender
{
	NSEnumerator *enumerator = [favorites objectEnumerator];
	id favorite;
	int count;

	//test if user has entered at least name and host/socket
	if ( [sender tag] &&
			([[nameField stringValue] isEqualToString:@""] || ([[hostField stringValue] isEqualToString:@""] && [[socketField stringValue] isEqualToString:@""])) ) {
		NSRunAlertPanel(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"Please enter at least name and host or socket!", @"message of panel when name/host/socket are missing"), NSLocalizedString(@"OK", @"OK button"), nil, nil);
		return;
	}
	
	//test if favorite name isn't used by another favorite
	count = 0;
	if ( [sender tag] ) {
		while ( (favorite = [enumerator nextObject]) ) {
			if ( [[favorite objectForKey:@"name"] isEqualToString:[nameField stringValue]] )
			{
				if ( isNewFavorite || (!isNewFavorite && (count != [tableView selectedRow])) ) {
					NSRunAlertPanel(NSLocalizedString(@"Error", @"error"), [NSString stringWithFormat:NSLocalizedString(@"Favorite %@ has already been saved!\nPlease specify another name.", @"message of panel when favorite name has already been used"), [nameField stringValue]], NSLocalizedString(@"OK", @"OK button"), nil, nil);
					return;
				}
			}
/*
			if ( [[favorite objectForKey:@"host"] isEqualToString:[hostField stringValue]] &&
					[[favorite objectForKey:@"user"] isEqualToString:[userField stringValue]] &&
					[[favorite objectForKey:@"database"] isEqualToString:[databaseField stringValue]] ) {
				if ( isNewFavorite || (!isNewFavorite && (count != [tableView selectedRow])) ) {
					NSRunAlertPanel(@"Error", @"There is already a favorite with the same host, user and database!", @"OK", nil, nil);
					return;
				}
			}
*/
			count++;
		}
	}

	[NSApp stopModalWithCode:[sender tag]];
}

/*
enables/disables ssh tunneling
*/
- (IBAction)toggleUseSSH:(id)sender
{
	if ( [sshCheckbox state] == NSOnState ) {
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

#pragma mark Services menu methods

/*
passes the query to the last created document
*/
- (void)doPerformQueryService:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error
{
	NSString *pboardString;
	NSArray *types;

	types = [pboard types];

	if (![types containsObject:NSStringPboardType] || !(pboardString = [pboard stringForType:NSStringPboardType])) {
		*error = @"Pasteboard couldn't give string.";
		return;
	}

	//check if there exists a document
	if ( ![[[NSDocumentController sharedDocumentController] documents] count] ) {
		*error = @"No Documents open!";
		return;
	}

	//pass query to last created document
//	[[[NSDocumentController sharedDocumentController] currentDocument] doPerformQueryService:pboardString];
	[[[[NSDocumentController sharedDocumentController] documents] objectAtIndex:[[[NSDocumentController sharedDocumentController] documents] count]-1] doPerformQueryService:pboardString];

	return;
}


#pragma mark Sequel Pro menu methods

/*
opens donate link in default browser
*/
- (IBAction)donate:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://code.google.com/p/sequel-pro/wiki/Donations"]];
}

/*
opens website link in default browser
*/
- (IBAction)visitWebsite:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://code.google.com/p/sequel-pro"]];
}

/*
opens help link in default browser
*/
- (IBAction)visitHelpWebsite:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://code.google.com/p/sequel-pro/wiki/FAQ"]];
}

/*
checks for updates and opens download page in default browser
*/
- (IBAction)checkForUpdates:(id)sender
{
	NSLog(@"[MainController checkForUpdates:] is not currently functional.");
}


#pragma mark TableView datasource methods

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [favorites count];
}

- (id)tableView:(NSTableView *)aTableView
			objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
	return [[favorites objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
}


#pragma mark TableView drag & drop datasource methods

- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard
{
	int originalRow;
	NSArray *pboardTypes;

	if ( [rows count] == 1 ) {
		pboardTypes=[NSArray arrayWithObjects:@"SequelProPreferencesPasteboard", nil];
		originalRow = [[rows objectAtIndex:0] intValue];

	[pboard declareTypes:pboardTypes owner:nil];
	[pboard setString:[[NSNumber numberWithInt:originalRow] stringValue] forType:@"SequelProPreferencesPasteboard"];

		return YES;
	} else {
		return NO;
	}
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row
	proposedDropOperation:(NSTableViewDropOperation)operation
{
	NSArray *pboardTypes = [[info draggingPasteboard] types];
	int originalRow;

	if ([pboardTypes count] == 1 && row != -1)
	{
		if ([[pboardTypes objectAtIndex:0] isEqualToString:@"SequelProPreferencesPasteboard"]==YES && operation==NSTableViewDropAbove)
		{
			originalRow = [[[info draggingPasteboard] stringForType:@"SequelProPreferencesPasteboard"] intValue];

			if (row != originalRow && row != (originalRow+1))
			{
				return NSDragOperationMove;
			}
		}
	}

	return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	int originalRow;
	int destinationRow;
	NSMutableDictionary *draggedRow;

	originalRow = [[[info draggingPasteboard] stringForType:@"SequelProPreferencesPasteboard"] intValue];
	destinationRow = row;

	if ( destinationRow > originalRow )
		destinationRow--;

	draggedRow = [NSMutableDictionary dictionaryWithDictionary:[favorites objectAtIndex:originalRow]];
	[favorites removeObjectAtIndex:originalRow];
	[favorites insertObject:draggedRow atIndex:destinationRow];
	
	[tableView reloadData];
	[tableView selectRow:destinationRow byExtendingSelection:NO];

	return YES;
}

/*
 opens sheet to edit favorite and saves favorite if user hit OK
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	int code;
	NSDictionary *favorite = [favorites objectAtIndex:rowIndex];

	// set up fields
	[nameField setStringValue:[favorite objectForKey:@"name"]];
	[hostField setStringValue:[favorite objectForKey:@"host"]];
	[socketField setStringValue:[favorite objectForKey:@"socket"]];
	[userField setStringValue:[favorite objectForKey:@"user"]];
	[portField setStringValue:[favorite objectForKey:@"port"]];
	[databaseField setStringValue:[favorite objectForKey:@"database"]];
	[passwordField setStringValue:[keyChainInstance	getPasswordForName:[NSString stringWithFormat:@"Sequel Pro : %@", [nameField stringValue]]
															   account:[NSString stringWithFormat:@"%@@%@/%@", [userField stringValue], [hostField stringValue], [databaseField stringValue]]]];
	
	// set up ssh fields
	if ( [[favorite objectForKey:@"useSSH"] intValue] == 1 ) {
		[sshCheckbox setState:NSOnState];
		[sshUserField setEnabled:YES];
		[sshPasswordField setEnabled:YES];
		[sshHostField setEnabled:YES];
		[sshPortField setEnabled:YES];
		[sshHostField setStringValue:[favorite objectForKey:@"sshHost"]];
		[sshUserField setStringValue:[favorite objectForKey:@"sshUser"]];
		[sshPortField setStringValue:[favorite objectForKey:@"sshPort"]];
		[sshPasswordField setStringValue:[keyChainInstance getPasswordForName:[NSString stringWithFormat:@"Sequel Pro SSHTunnel : %@", [nameField stringValue]]
																	  account:[NSString stringWithFormat:@"%@@%@/%@", [userField stringValue], [hostField stringValue], [databaseField stringValue]]]];
	} else {
		[sshCheckbox setState:NSOffState];
		[sshUserField setEnabled:NO];
		[sshPasswordField setEnabled:NO];
		[sshHostField setEnabled:NO];
		[sshPortField setEnabled:NO];
		[sshHostField setStringValue:@""];
		[sshUserField setStringValue:@""];
		[sshPortField setStringValue:@""];
		[sshPasswordField setStringValue:@""];
	}

	// run sheet
	[NSApp beginSheet:favoriteSheet
	   modalForWindow:preferencesWindow
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
	
	code = [NSApp runModalForWindow:favoriteSheet];

	[NSApp endSheet:favoriteSheet];
	[favoriteSheet orderOut:nil];

	if ( code == 1 ) {
		if ( ![[socketField stringValue] isEqualToString:@""] ) {
			//set host to localhost if socket is used
			[hostField setStringValue:@"localhost"];
		}
		
		//get ssh settings
		NSString *sshHost, *sshUser, *sshPassword, *sshPort;
		NSNumber *ssh;
		if ( [sshCheckbox state] == NSOnState ) {
			if ( [[sshHostField stringValue] isEqualToString:@""] ) {
				sshHost = [hostField stringValue];
			} else {
				sshHost = [sshHostField stringValue];
			}
			if ( [[sshUserField stringValue] isEqualToString:@""] ) {
				sshUser = [userField stringValue];
			} else {
				sshUser = [sshUserField stringValue];
			}
			if ( [[sshPasswordField stringValue] isEqualToString:@""] ) {
				sshPassword = [passwordField stringValue];
			} else {
				sshPassword = [sshPasswordField stringValue];
			}
			if ( [[sshPortField stringValue] isEqualToString:@""] ) {
				sshPort = [portField stringValue];
			} else {
				sshPort = [sshPortField stringValue];
			}
			ssh = [NSNumber numberWithInt:1];
		} else {
			sshHost = @"";
			sshUser = @"";
			sshPassword = @"";
			sshPort = @"";
			ssh = [NSNumber numberWithInt:0];
		}
		
		//replace password
		[keyChainInstance deletePasswordForName:[NSString stringWithFormat:@"Sequel Pro : %@", [favorite objectForKey:@"name"]]
										account:[NSString stringWithFormat:@"%@@%@/%@", [favorite objectForKey:@"user"], [favorite objectForKey:@"host"], [favorite objectForKey:@"database"]]];
		
		if ( ![[passwordField stringValue] isEqualToString:@""] )
			[keyChainInstance addPassword:[passwordField stringValue]
								  forName:[NSString stringWithFormat:@"Sequel Pro : %@", [nameField stringValue]]
								  account:[NSString stringWithFormat:@"%@@%@/%@", [userField stringValue], [hostField stringValue], [databaseField stringValue]]];
		
		//replace ssh password
		[keyChainInstance deletePasswordForName:[NSString stringWithFormat:@"Sequel Pro SSHTunnel : %@", [favorite objectForKey:@"name"]]
										account:[NSString stringWithFormat:@"%@@%@/%@", [favorite objectForKey:@"user"], [favorite objectForKey:@"host"], [favorite objectForKey:@"database"]]];
		
		if ( ([sshCheckbox state] == NSOnState) && ![sshPassword isEqualToString:@""] ) {
			[keyChainInstance addPassword:sshPassword
				forName:[NSString stringWithFormat:@"Sequel Pro SSHTunnel : %@", [nameField stringValue]]
				account:[NSString stringWithFormat:@"%@@%@/%@", [userField stringValue], [hostField stringValue],
							[databaseField stringValue]]];
		}
		
		//replace favorite
		favorite = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[nameField stringValue], [hostField stringValue], [socketField stringValue], [userField stringValue], [portField stringValue], [databaseField stringValue], ssh, sshHost, sshUser, sshPort, nil]
											   forKeys:[NSArray arrayWithObjects:@"name", @"host", @"socket", @"user", @"port", @"database", @"useSSH", @"sshHost", @"sshUser", @"sshPort", nil]];
		[favorites replaceObjectAtIndex:rowIndex withObject:favorite];
		[tableView reloadData];
	}

	return NO;
}


#pragma mark Window delegate methods

/*
 saves the preferences
 */
- (BOOL)windowShouldClose:(id)sender
{
	if ( sender == preferencesWindow ) {
		if ( [reloadAfterAddingSwitch state] == NSOnState ) {
			[prefs setBool:YES forKey:@"reloadAfterAdding"];
		} else {
			[prefs setBool:NO forKey:@"reloadAfterAdding"];
		}
		if ( [reloadAfterEditingSwitch state] == NSOnState ) {
			[prefs setBool:YES forKey:@"reloadAfterEditing"];
		} else {
			[prefs setBool:NO forKey:@"reloadAfterEditing"];
		}
		if ( [reloadAfterRemovingSwitch state] == NSOnState ) {
			[prefs setBool:YES forKey:@"reloadAfterRemoving"];
		} else {
			[prefs setBool:NO forKey:@"reloadAfterRemoving"];
		}
		if ( [showErrorSwitch state] == NSOnState ) {
			[prefs setBool:YES forKey:@"showError"];
		} else {
			[prefs setBool:NO forKey:@"showError"];
		}
		if ( [dontShowBlobSwitch state] == NSOnState ) {
			[prefs setBool:YES forKey:@"dontShowBlob"];
		} else {
			[prefs setBool:NO forKey:@"dontShowBlob"];
		}
		if ( [limitRowsSwitch state] == NSOnState ) {
			[prefs setBool:YES forKey:@"limitRows"];
		} else {
			[prefs setBool:NO forKey:@"limitRows"];
		}
		if ( [useMonospacedFontsSwitch state] == NSOnState ) {
			[prefs setBool:YES forKey:@"useMonospacedFonts"];
		} else {
			[prefs setBool:NO forKey:@"useMonospacedFonts"];
		}
		if ( [fetchRowCountSwitch state] == NSOnState ) {
			[prefs setBool:YES forKey:@"fetchRowCount"];
		} else {
			[prefs setBool:NO forKey:@"fetchRowCount"];
		}
		[prefs setObject:[nullValueField stringValue] forKey:@"nullValue"];
		if ( [limitRowsField intValue] > 0 ) {
			[prefs setInteger:[limitRowsField intValue] forKey:@"limitRowsValue"];
		} else {
			[prefs setInteger:1 forKey:@"limitRowsValue"];	
		}
		[prefs setObject:[encodingPopUpButton titleOfSelectedItem] forKey:@"encoding"];
	
		[prefs setObject:favorites forKey:@"favorites"];
	}
	return YES;
}


#pragma mark Other methods

- (void)awakeFromNib
{
	NSEnumerator *enumerator;
	id favorite;
	NSString *name, *host, *user, *database, *password;
	//int code;

	//register MainController as services provider
	[NSApp setServicesProvider:self];

	//register MainController for AppleScript events
	[[ NSScriptExecutionContext sharedScriptExecutionContext] setTopLevelObject: self ];
	
	prefs = [[NSUserDefaults standardUserDefaults] retain];
	isNewFavorite = NO;
	[prefs registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
							 [NSNumber numberWithBool:YES], @"limitRows",
							 [NSNumber numberWithInt:1000], @"limitRowsValue",
							 nil]];

	//set standard preferences if no preferences are found
	if ( [prefs objectForKey:@"reloadAfterAdding"] == nil )
	{
		[prefs setObject:@"0.3" forKey:@"version"];
		[prefs setBool:YES forKey:@"reloadAfterAdding"];
		[prefs setBool:YES forKey:@"reloadAfterEditing"];
		[prefs setBool:NO forKey:@"reloadAfterRemoving"];
		[prefs setObject:@"NULL" forKey:@"nullValue"];
		//[prefs setBool:YES forKey:@"showError"];
		//[prefs setBool:NO forKey:@"dontShowBlob"];
		//[prefs setBool:NO forKey:@"limitRows"];
		//[prefs setInteger:100 forKey:@"limitRowsValue"];
		//[prefs setObject:[NSString stringWithString:NSHomeDirectory()] forKey:@"savePath"];
		//[prefs setObject:[NSString stringWithString:NSHomeDirectory()] forKey:@"openPath"];
	}

	//new preferences and changes in v0.4
	if ( [prefs objectForKey:@"showError"] == nil )	{
		[prefs setObject:@"0.4" forKey:@"version"];
		
		//set standard values for new preferences
		[prefs setBool:YES forKey:@"showError"];
		[prefs setBool:NO forKey:@"dontShowBlob"];
		//[prefs setBool:NO forKey:@"limitRows"];
		//[prefs setInteger:100 forKey:@"limitRowsValue"];
		[prefs setObject:[NSString stringWithString:NSHomeDirectory()] forKey:@"savePath"];
		[prefs setObject:[NSString stringWithString:NSHomeDirectory()] forKey:@"openPath"];
		
		//remove old preferences
		[prefs removeObjectForKey:@"allowDragAndDropReordering"];
		
		//rewrite passwords to keychain (with new format)
		if ( [prefs objectForKey:@"favorites"] ) {
			NSRunAlertPanel(NSLocalizedString(@"Warning", @"warning"), NSLocalizedString(@"With version 0.4 Sequel Pro has introduced a new format to save passwords in the Keychain.\nPlease allow Sequel Pro to decrypt all passwords of your favorites. Otherwise you have to reenter all passwords of your saved favorites in the Preferences.", @"message of panel when passwords have to be updated for v0.4"), NSLocalizedString(@"OK", @"OK button"), nil, nil);
			enumerator = [[prefs objectForKey:@"favorites"] objectEnumerator];

			while ( (favorite = [enumerator nextObject]) ) {
				//replace password
				name = [favorite objectForKey:@"name"];
				host = [favorite objectForKey:@"host"];
				user = [favorite objectForKey:@"user"];
				database = [favorite objectForKey:@"database"];
				password = [keyChainInstance getPasswordForName:[NSString stringWithFormat:@"%@/%@", host, database]
								account:user];
				[keyChainInstance deletePasswordForName:[NSString stringWithFormat:@"%@/%@", host, database] account:user];
				if ( ![password isEqualToString:@""] )
					[keyChainInstance addPassword:password
						forName:[NSString stringWithFormat:@"Sequel Pro : %@", name]
						account:[NSString stringWithFormat:@"%@@%@/%@", user, host, database]];
			}
		}
	}
	
	//new preferences and changes in v0.5
	if ( [[prefs objectForKey:@"version"] isEqualToString:@"0.4"] )	{
		[prefs setObject:@"0.5" forKey:@"version"];
		
		//set standard values for new preferences
		[prefs setObject:@"ISO Latin 1" forKey:@"encoding"];
		[prefs setBool:NO forKey:@"useMonospacedFonts"];
		
		//add socket field to favorites
		if ( [prefs objectForKey:@"favorites"] ) {
			NSMutableArray *tempFavorites = [NSMutableArray array];
			NSMutableDictionary *tempFavorite;
			enumerator = [[prefs objectForKey:@"favorites"] objectEnumerator];
			while ( (favorite = [enumerator nextObject]) ) {
				tempFavorite = [NSMutableDictionary dictionaryWithDictionary:favorite];
				[tempFavorite setObject:@"" forKey:@"socket"];
				[tempFavorites addObject:[NSDictionary dictionaryWithDictionary:tempFavorite]];
			}
			[prefs setObject:tempFavorites forKey:@"favorites"];
		}
	}
	
	//new preferences and changes in v0.7
	if ( [[prefs objectForKey:@"version"] isEqualToString:@"0.5"] ||
			[[prefs objectForKey:@"version"] isEqualToString:@"0.6beta"] ||
			[[prefs objectForKey:@"version"] isEqualToString:@"0.7b2"] )
	{
		[prefs setObject:@"0.7b3" forKey:@"version"];
		[prefs setObject:@"Autodetect" forKey:@"encoding"];
		[prefs setBool:YES forKey:@"fetchRowCount"];
	}

//set up interface
/*
	enumerator = [tableColumns objectEnumerator];
	while ( (column = [enumerator nextObject]) )
	{
		[[column dataCell] setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}
*/
	[tableView registerForDraggedTypes:[NSArray arrayWithObjects:@"SequelProPreferencesPasteboard", nil]];
	[tableView reloadData];
}


// SSHTunnel methods
- (id)authenticate:(NSScriptCommand *)command {
	NSDictionary *args = [command evaluatedArguments];
	NSString *givenQuery = [ args objectForKey:@"query"];
	NSString *tunnelName = [ args objectForKey:@"tunnelName"];
	NSString *fifo = [ args objectForKey:@"fifo"];
	
	NSLog(@"tunnel: %@ / query: %@ / fifo: %@",tunnelName,givenQuery,fifo);
	NSFileHandle *fh = [ NSFileHandle fileHandleForWritingAtPath: fifo ];
	[ fh writeData: [ @"xy" dataUsingEncoding: NSASCIIStringEncoding]];
	[ fh closeFile ];
	
	NSLog(@"password written");
	return @"OK";

/*
	[ query setStringValue: givenQuery ];
	[NSApp beginSheet: alertSheet
			modalForWindow: mainWindow
			modalDelegate: nil
			didEndSelector: nil
			contextInfo: nil];
	[NSApp runModalForWindow: alertSheet];
	// Sheet is up here.
	[NSApp endSheet: alertSheet];
	[alertSheet orderOut: self];
	if ( sheetStatus ==  0)
	{
		password = [ passwd stringValue ];
		[ passwd setStringValue: @"" ];
		return password ;
	}
	else
	{
		[[tunnelTask objectForKey: @"task" ] terminate ];
	}
	sheetStatus = nil;
	return @"";
*/
}

- (id)handleQuitScriptCommand:(NSScriptCommand *)command
/* what exactly is this for? */
{
	[ NSApp terminate: self ];
	return nil;
}

@end
