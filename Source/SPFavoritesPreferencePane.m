//
//  $Id$
//
//  SPFavoritesPreferencePane.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 31, 2010
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPFavoritesPreferencePane.h"
#import "SPFavoriteTextFieldCell.h"
#import "SPPreferenceController.h"
#import "SPKeychain.h"
#import <BWToolkitFramework/BWToolkitFramework.h>
#import "SPGeneralPreferencePane.h"

@interface SPFavoritesPreferencePane (PrivateAPI)

- (void)_sortFavorites;
- (void)_updateFavoritePasswordsFromField:(NSControl *)passwordControl;

@end

@implementation SPFavoritesPreferencePane

#pragma mark -
#pragma mark Intialisation

/**
 * Init.
 */
- (id)init
{
	if ((self = [super init])) {
		
		keychain = [[SPKeychain alloc] init];
		
		favoriteType = 0;
		reverseFavoritesSort = NO;
		favoriteNameFieldWasTouched = YES;
		
		previousSortItem = SPFavoritesSortNameItem;
	}
	
	return self;
}

/**
 * Initialise the UI, specifically the favourites table view and sort the favourites if required.
 */
- (void)awakeFromNib
{
	// Set sort items
	currentSortItem = [prefs integerForKey:SPFavoritesSortedBy];
	reverseFavoritesSort = [prefs boolForKey:SPFavoritesSortedInReverse];
	
	// Replace column's NSTextFieldCell with custom SWProfileTextFieldCell
	[[[favoritesTableView tableColumns] objectAtIndex:0] setDataCell:tableCell];
	
	[favoritesTableView registerForDraggedTypes:[NSArray arrayWithObject:SPFavoritesPasteboardDragType]];
	
	[favoritesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	[favoritesTableView reloadData];
	
	[tableCell setImage:[NSImage imageNamed:@"database"]];
	
	// Set the button bar delegate 
	[splitViewButtonBar setSplitViewDelegate:self];
	
	// Hide the tabs on the favorites tab view - left visible in IB for easy use
	[favoritesTabView setTabViewType:NSNoTabsNoBorder];
	
	// Sort favorites if a sort type has been selected
	if (currentSortItem != SPFavoritesSortUnsorted) [self _sortFavorites];
}

#pragma mark -
#pragma mark IBAction methods

/**
 * Adds a new connection favorite.
 */
- (IBAction)addFavorite:(id)sender
{
	NSNumber *favoriteid = [NSNumber numberWithInteger:[[NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]] hash]];
	
	// Create default favorite
	NSMutableDictionary *favorite = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"New Favorite", @"new favorite name"), [NSNumber numberWithInteger:0], @"", @"", @"", @"", [NSNumber numberWithInt:NSOffState], [NSNumber numberWithInt:NSOffState], [NSNumber numberWithInt:NSOffState], [NSNumber numberWithInt:NSOffState], @"", @"", @"", [NSNumber numberWithInt:NSOffState], @"", @"", favoriteid, nil] 
																	   forKeys:[NSArray arrayWithObjects:@"name", @"type", @"host", @"socket", @"user", @"port", @"useSSL", @"sslKeyFileLocationEnabled", @"sslCertificateFileLocationEnabled", @"sslCACertFileLocationEnabled", @"database", @"sshHost", @"sshUser", @"sshKeyLocationEnabled", @"sshKeyLocation", @"sshPort", @"id", nil]];
	
	[favoritesController addObject:favorite];
	[favoritesController setSelectedObjects:[NSArray arrayWithObject:favorite]];
	
	[favoritesTableView reloadData];
	[favoritesTableView scrollRowToVisible:[favoritesTableView selectedRow]];
	
	[[(SPPreferenceController *)[[[self view] window] delegate] generalPreferencePane] updateDefaultFavoritePopup];
	
	favoriteNameFieldWasTouched = NO;
	
	[[[self view] window] makeFirstResponder:favoriteHostTextField];
}

/**
 * Removes the selected connection favorite.
 */
- (IBAction)removeFavorite:(id)sender
{
	if ([favoritesTableView numberOfSelectedRows] == 1) {
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Delete favorite '%@'?", @"delete database message"), [favoritesController valueForKeyPath:@"selection.name"]]
										 defaultButton:NSLocalizedString(@"Delete", @"delete button") 
									   alternateButton:NSLocalizedString(@"Cancel", @"cancel button") 
										   otherButton:nil 
							 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the favorite '%@'? This operation cannot be undone.", @"delete database informative message"), [favoritesController valueForKeyPath:@"selection.name"]]];
		
		NSArray *buttons = [alert buttons];
		
		// Change the alert's cancel button to have the key equivalent of return
		[[buttons objectAtIndex:0] setKeyEquivalent:@"d"];
		[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
		[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
		
		[alert setAlertStyle:NSCriticalAlertStyle];
		
		[alert beginSheetModalForWindow:[[self view] window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"removeFavorite"];
	}
}

/**
 * Duplicates the selected connection favorite.
 */
- (IBAction)duplicateFavorite:(id)sender
{
	if ([favoritesTableView numberOfSelectedRows] == 1) {
		
		NSMutableDictionary *favorite = [NSMutableDictionary dictionaryWithDictionary:[[favoritesController arrangedObjects] objectAtIndex:[favoritesTableView selectedRow]]];
		NSNumber *favoriteid = [NSNumber numberWithInteger:[[NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]] hash]];
		NSInteger duplicatedFavoriteType = [[favorite objectForKey:@"type"] integerValue];
		
		// Select the keychain passwords for duplication
		NSString *keychainName       = [keychain nameForFavoriteName:[favorite objectForKey:@"name"] id:[favorite objectForKey:@"id"]];
		NSString *keychainAccount    = [keychain accountForUser:[favorite objectForKey:@"user"] host:((duplicatedFavoriteType == SPSocketConnection)?@"localhost":[favorite objectForKey:@"host"]) database:[favorite objectForKey:@"database"]];
		NSString *password           = [keychain getPasswordForName:keychainName account:keychainAccount];
		NSString *keychainSSHName    = [keychain nameForSSHForFavoriteName:[favorite objectForKey:@"name"] id:[favorite objectForKey:@"id"]];
		NSString *keychainSSHAccount = [keychain accountForSSHUser:[favorite objectForKey:@"sshUser"] sshHost:[favorite objectForKey:@"sshHost"]];
		NSString *sshPassword         = [keychain getPasswordForName:keychainSSHName account:keychainSSHAccount];
		
		// Update the unique ID
		[favorite setObject:favoriteid forKey:@"id"];
		
		// Alter the name for clarity
		[favorite setObject:[NSString stringWithFormat:NSLocalizedString(@"%@ Copy", @"Initial favourite name after duplicating a previous favourite"), [favorite objectForKey:@"name"]] forKey:@"name"];
		
		// Create new keychain items if appropriate
		if (password && [password length]) {
			keychainName = [keychain nameForFavoriteName:[favorite objectForKey:@"name"] id:[favorite objectForKey:@"id"]];
			[keychain addPassword:password forName:keychainName account:keychainAccount];
		}
		
		if (sshPassword && [sshPassword length]) {
			keychainSSHName = [keychain nameForSSHForFavoriteName:[favorite objectForKey:@"name"] id:[favorite objectForKey:@"id"]];
			[keychain addPassword:sshPassword forName:keychainSSHName account:keychainSSHAccount];
		}
		
		password = nil, sshPassword = nil;
		
		[favoritesController addObject:favorite];
		[favoritesController setSelectedObjects:[NSArray arrayWithObject:favorite]];
		
		[favoritesTableView reloadData];
		[favoritesTableView scrollRowToVisible:[favoritesTableView selectedRow]];
		
		[[(SPPreferenceController *)[[[self view] window] delegate] generalPreferencePane] updateDefaultFavoritePopup];
		
		[[[self view] window] makeFirstResponder:favoriteNameTextField];
	}
}

/**
 * Sorts the favorites table view based on the selected sort by item
 */
- (IBAction)sortFavorites:(id)sender
{	
	previousSortItem = currentSortItem;
	currentSortItem  = [[sender menu] indexOfItem:sender];
	
	[prefs setInteger:currentSortItem forKey:SPFavoritesSortedBy];
	
	// Perform sorting
	[self _sortFavorites];
	
	if ((NSInteger)previousSortItem > -1) [[[sender menu] itemAtIndex:previousSortItem] setState:NSOffState];
	
	[[[sender menu] itemAtIndex:currentSortItem] setState:NSOnState];	
}

/**
 * Reverses the favorites table view sorting based on the selected criteria
 */
- (IBAction)reverseFavoritesSortOrder:(id)sender
{	
	reverseFavoritesSort = (![sender state]);
	
	[prefs setBool:reverseFavoritesSort forKey:SPFavoritesSortedInReverse];
	
	// Perform re-sorting
	[self _sortFavorites];
	
	[sender setState:reverseFavoritesSort]; 
}

/**
 * Makes the selected favorite the default.
 */
- (IBAction)makeSelectedFavoriteDefault:(id)sender
{
	// Minus 2 from index to account for the 'Last Used' and separator items
	[prefs setInteger:[favoritesTableView selectedRow] forKey:SPDefaultFavorite];
	
	[favoritesTableView reloadData];
	
	[[(SPPreferenceController *)[[[self view] window] delegate] generalPreferencePane] updateDefaultFavoritePopup];
}

/**
 * Update the favorite host when the type changes.
 */
- (IBAction)favoriteTypeDidChange:(id)sender
{
	// If not socket and host is localhost, clear.
	if (([sender indexOfSelectedItem] != 1) && [[favoritesController valueForKeyPath:@"selection.host"] isEqualToString:@"localhost"])
	{
		[favoritesController setValue:@"" forKeyPath:@"selection.host"];
	}
	
	favoriteType = [sender indexOfSelectedItem];
	
	// Update the name for a new added favorite if not touched by the user
	if(!favoriteNameFieldWasTouched) {
		[favoriteNameTextField setStringValue:[NSString stringWithFormat:@"%@@%@", 
											   ([favoritesController valueForKeyPath:@"selection.user"]) ? [favoritesController valueForKeyPath:@"selection.user"] : @"", 
											   (([sender indexOfSelectedItem] == 1) ? @"localhost" :
												(([favoritesController valueForKeyPath:@"selection.host"]) ? [favoritesController valueForKeyPath:@"selection.host"] : @""))
											   ]];
		
		[favoritesController setValue:[favoriteNameTextField stringValue] forKeyPath:@"selection.name"];
	}
	
	// Request a password refresh to keep keychain references in synch with the favorites
	[self _updateFavoritePasswordsFromField:nil];
}

/**
 * Opens the SSH/SSL key selection window, ready to select a key file.
 */
- (IBAction)chooseKeyLocation:(id)sender
{
	NSString *directoryPath = nil;
	NSString *filePath = nil;
	NSArray *permittedFileTypes = nil;
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	
	// Switch details by sender.
	// First, SSH keys:
	if (sender == sshSSHKeyButton) {
		
		// If the custom key location is currently disabled - after the button
		// action - leave it disabled and return without showing the sheet.
		if (![favoritesController valueForKeyPath:@"selection.sshKeyLocationEnabled"]) {
			return;
		}
		
		// Otherwise open a panel at the last or default location
		NSString *sshKeyLocation = [favoritesController valueForKeyPath:@"selection.sshKeyLocation"];
		if (sshKeyLocation && [sshKeyLocation length]) {
			filePath = [sshKeyLocation lastPathComponent];
			directoryPath = [sshKeyLocation stringByDeletingLastPathComponent];
		}
		
		permittedFileTypes = [NSArray arrayWithObjects:@"pem", @"", nil];
		
		[openPanel setAccessoryView:sshKeyLocationHelp];
		
		// SSL key file location:
	} 
	else if (sender == standardSSLKeyFileButton || sender == socketSSLKeyFileButton) {
		if ([sender state] == NSOffState) {
			[favoritesController setValue:nil forKeyPath:@"selection.sslKeyFileLocation"];
			return;
		}
		
		permittedFileTypes = [NSArray arrayWithObjects:@"pem", @"key", @"", nil];
		[openPanel setAccessoryView:sslKeyFileLocationHelp];
		
		// SSL certificate file location:
	} 
	else if (sender == standardSSLCertificateButton || sender == socketSSLCertificateButton) {
		if ([sender state] == NSOffState) {
			[favoritesController setValue:nil forKeyPath:@"selection.sslCertificateFileLocation"];
			return;
		}
		
		permittedFileTypes = [NSArray arrayWithObjects:@"pem", @"cert", @"crt", @"", nil];
		[openPanel setAccessoryView:sslCertificateLocationHelp];
		
		// SSL CA certificate file location:
	} 
	else if (sender == standardSSLCACertButton || sender == socketSSLCACertButton) {
		if ([sender state] == NSOffState) {
			[favoritesController setValue:nil forKeyPath:@"selection.sslCACertFileLocation"];
			return;
		}
		
		permittedFileTypes = [NSArray arrayWithObjects:@"pem", @"cert", @"crt", @"", nil];
		[openPanel setAccessoryView:sslCACertLocationHelp];
	}
	
	[openPanel beginSheetForDirectory:directoryPath
								 file:filePath
								types:permittedFileTypes
					   modalForWindow:[[self view] window]
						modalDelegate:self
					   didEndSelector:@selector(chooseKeyLocationSheetDidEnd:returnCode:contextInfo:)
						  contextInfo:sender];
}

#pragma mark -
#pragma mark Public API

/**
 * Selects the specified favorite(s) in the favorites list.
 */
- (void)selectFavorites:(NSArray *)favorites
{
	[favoritesController setSelectedObjects:favorites];
	[favoritesTableView scrollRowToVisible:[favoritesController selectionIndex]];
}

#pragma mark -
#pragma mark TableView datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{	
	return [[favoritesController arrangedObjects] count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	return [[[favoritesController arrangedObjects] objectAtIndex:rowIndex] objectForKey:[tableColumn identifier]];
}

#pragma mark -
#pragma mark TableView drag & drop delegate methods

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rows toPasteboard:(NSPasteboard*)pboard
{
	if ([rows count] == 1) {
		[pboard declareTypes:[NSArray arrayWithObject:SPFavoritesPasteboardDragType] owner:nil];
		[pboard setString:[[NSNumber numberWithInteger:[rows firstIndex]] stringValue] forType:SPFavoritesPasteboardDragType];
		
		return YES;
	} 
	else {
		return NO;
	}
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
	NSInteger originalRow;
	NSArray *pboardTypes = [[info draggingPasteboard] types];
	
	if (([pboardTypes count] > 1) && (row != -1)) {
		if (([pboardTypes containsObject:SPFavoritesPasteboardDragType]) && (operation == NSTableViewDropAbove)) {
			originalRow = [[[info draggingPasteboard] stringForType:SPFavoritesPasteboardDragType] integerValue];
			
			if ((row != originalRow) && (row != (originalRow + 1))) {
				return NSDragOperationMove;
			}
		}
	}
	
	return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
	NSInteger originalRow;
	NSInteger destinationRow;
	NSInteger lastFavoriteIndexCached;
	NSMutableDictionary *draggedRow;
	
	// Disable all automatic sorting
	currentSortItem = -1;
	reverseFavoritesSort = NO;
	
	[prefs setInteger:currentSortItem forKey:SPFavoritesSortedBy];
	[prefs setBool:NO forKey:SPFavoritesSortedInReverse];
	
	// Remove sort descriptors
	[favoritesController setSortDescriptors:[NSArray array]];
	
	// Uncheck sort by menu items
	for (NSMenuItem *menuItem in [[favoritesSortByMenuItem submenu] itemArray])
	{
		[menuItem setState:NSOffState];
	}
	
	originalRow = [[[info draggingPasteboard] stringForType:SPFavoritesPasteboardDragType] integerValue];
	destinationRow = row;
	
	if (destinationRow > originalRow) {
		destinationRow--;
	}
	
	draggedRow = [NSMutableDictionary dictionaryWithDictionary:[[favoritesController arrangedObjects] objectAtIndex:originalRow]];
	
	// Before deleting this favorite, we need to save the current index.
	// because removeObjectAtArrangedObjectIndex will set prefs LastFavoriteIndex to 0
	lastFavoriteIndexCached = [prefs integerForKey:SPLastFavoriteIndex];
	
	[favoritesController removeObjectAtArrangedObjectIndex:originalRow];
	[favoritesController insertObject:draggedRow atArrangedObjectIndex:destinationRow];
	
	[favoritesTableView reloadData];
	[favoritesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:destinationRow] byExtendingSelection:NO];
	
	// Update default favorite to take on new value
	if (lastFavoriteIndexCached == originalRow) {
		[prefs setInteger:destinationRow forKey:SPLastFavoriteIndex];
	}
	
	// Update default favorite to take on new value
	if ([prefs integerForKey:SPDefaultFavorite] == originalRow) {
		[prefs setInteger:destinationRow forKey:SPDefaultFavorite];
	}
	
	[[(SPPreferenceController *)[[[self view] window] delegate] generalPreferencePane] updateDefaultFavoritePopup];
	
	return YES;
}

#pragma mark -
#pragma mark TableView delegate methods

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)index
{
	if ([cell isKindOfClass:[SPFavoriteTextFieldCell class]]) {
		[cell setFavoriteName:[[[favoritesController arrangedObjects] objectAtIndex:index] objectForKey:@"name"]];
		
		if ([[[[favoritesController arrangedObjects] objectAtIndex:index] objectForKey:@"type"] integerValue] == SPSocketConnection) {
			[cell setFavoriteHost:@"localhost"];
		} 
		else {
			[cell setFavoriteHost:[[[favoritesController arrangedObjects] objectAtIndex:index] objectForKey:@"host"]];
		}
	}
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{	
	if ([[favoritesTableView selectedRowIndexes] count] > 0) {
		[favoritesController setSelectionIndexes:[favoritesTableView selectedRowIndexes]];
	}
	
	// If no selection is present, blank the password fields (which can't use bindings)
	if ([[favoritesTableView selectedRowIndexes] count] == 0) {
		[standardPasswordField setStringValue:@""];
		[socketPasswordField setStringValue:@""];
		[sshSQLPasswordField setStringValue:@""];
		[sshPasswordField setStringValue:@""];
		
		return;
	}
	
	// Keep a copy of the favorite as it currently stands
	if (currentFavorite) [currentFavorite release];
	
	currentFavorite = [[[favoritesController selectedObjects] objectAtIndex:0] copy];
	
	// Retrieve and set the password.
	NSString *keychainName    = [keychain nameForFavoriteName:[currentFavorite objectForKey:@"name"] id:[currentFavorite objectForKey:@"id"]];
	NSString *keychainAccount = [keychain accountForUser:[currentFavorite objectForKey:@"user"] host:(([[currentFavorite objectForKey:@"type"] integerValue] == SPSocketConnection)?@"localhost":[currentFavorite objectForKey:@"host"]) database:[currentFavorite objectForKey:@"database"]];
	NSString *passwordValue   = [keychain getPasswordForName:keychainName account:keychainAccount];
	
	[standardPasswordField setStringValue:passwordValue];
	[socketPasswordField setStringValue:passwordValue];
	[sshSQLPasswordField setStringValue:passwordValue];
	
	// Retrieve the SSH keychain password if appropriate.
	NSString *keychainSSHName    = [keychain nameForSSHForFavoriteName:[currentFavorite objectForKey:@"name"] id:[currentFavorite objectForKey:@"id"]];
	NSString *keychainSSHAccount = [keychain accountForSSHUser:[currentFavorite objectForKey:@"sshUser"] sshHost:[currentFavorite objectForKey:@"sshHost"]];
	
	[sshPasswordField setStringValue:[keychain getPasswordForName:keychainSSHName account:keychainSSHAccount]];
	
	favoriteNameFieldWasTouched = YES;
}

#pragma mark -
#pragma mark TextField delegate methods and type change action

/**
 * Trap editing end notifications and use them to update the keychain password
 * appropriately when name, host, user, password or database changes.
 */
- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
	// Request a password refresh to keep keychain references in synch with favorites
	[self _updateFavoritePasswordsFromField:control];
	
	// Proceed with editing
	return YES;
}

/**
 * Trap and control the 'name' field of the selected favorite. If the user pressed
 * 'Add Favorite' the 'name' field is set to "New Favorite". If the user do not
 * change the 'name' field or delete that field it will be set to user@host automatically.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	id field = [notification object];
	
	BOOL nameFieldIsEmpty = ([[favoritesController valueForKeyPath:@"selection.name"] isEqualToString:@""] || 
							 [[favoriteNameTextField stringValue] isEqualToString:@""]);
	
	switch (favoriteType) 
	{
		case 0:
			if (nameFieldIsEmpty || (!favoriteNameFieldWasTouched && (field == favoriteUserTextField || field == favoriteHostTextField))) {
				[favoriteNameTextField setStringValue:[NSString stringWithFormat:@"%@@%@", [favoriteUserTextField stringValue], [favoriteHostTextField stringValue]]];
				[favoritesController setValue:[favoriteNameTextField stringValue] forKeyPath:@"selection.name"];
				[prefs synchronize];
				
				// if name field is empty enable user@host update
				if (nameFieldIsEmpty) favoriteNameFieldWasTouched = NO;
			}
			break;
		case 1:
			if (nameFieldIsEmpty || (!favoriteNameFieldWasTouched && field == favoriteUserTextFieldSocket)) {
				[favoriteNameTextField setStringValue:[NSString stringWithFormat:@"%@@localhost", [favoriteUserTextFieldSocket stringValue]]];
				[favoritesController setValue:[favoriteNameTextField stringValue] forKeyPath:@"selection.name"];
				[prefs synchronize];
				
				// if name field is empty enable user@host update
				if (nameFieldIsEmpty) favoriteNameFieldWasTouched = NO;
			}
			break;
		case 2:
			if (nameFieldIsEmpty || (!favoriteNameFieldWasTouched && (field == favoriteUserTextFieldSSH || field == favoriteHostTextFieldSSH))) {
				[favoriteNameTextField setStringValue:[NSString stringWithFormat:@"%@@%@", [favoriteUserTextFieldSSH stringValue], [favoriteHostTextFieldSSH stringValue]]];
				[favoritesController setValue:[favoriteNameTextField stringValue] forKeyPath:@"selection.name"];
				[prefs synchronize];
				
				// if name field is empty enable user@host update
				if (nameFieldIsEmpty) favoriteNameFieldWasTouched = NO;
			}
			break;
		default:
			break;
	}
	
	if (field == favoriteNameTextField) favoriteNameFieldWasTouched = YES;
}

#pragma mark -
#pragma mark SplitView delegate methods

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
	return (proposedMax - 220);
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
	return (proposedMin + 94);
}

#pragma mark -
#pragma mark Other

/**
 * Menu item validation;
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = [menuItem action];
	
	if ((action == @selector(removeFavorite:)) || (action == @selector(duplicateFavorite:))) {
		return ([favoritesTableView numberOfSelectedRows] > 0);
	}
	
	if (action == @selector(makeSelectedFavoriteDefault:)) {
		return ([favoritesTableView numberOfSelectedRows] == 1);
	}
	
	if ((action == @selector(sortFavorites:)) || (action == @selector(reverseFavoritesSortOrder:))) {
		
		// Loop all the items in the sort by menu only checking the currently selected one
		for (NSMenuItem *item in [[menuItem menu] itemArray])
		{
			[item setState:([[menuItem menu] indexOfItem:item] == currentSortItem)];
		}
		
		// Check or uncheck the reverse sort item
		if (action == @selector(reverseFavoritesSortOrder:)) {
			[menuItem setState:reverseFavoritesSort];
		}
		
		return [[[[[self view] window] toolbar] selectedItemIdentifier] isEqualToString:SPPreferenceToolbarFavorites];
	}
	
	return YES;
}

/**
 * Called after closing the SSH/SSL key selection sheet.
 */
- (void)chooseKeyLocationSheetDidEnd:(NSOpenPanel *)openPanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	NSString *abbreviatedFileName = [[openPanel filename] stringByAbbreviatingWithTildeInPath];
	
	// SSH key file selection
	if (contextInfo == sshSSHKeyButton) {
		if (returnCode == NSCancelButton) {
			[favoritesController setValue:[NSNumber numberWithInt:NSOffState] forKeyPath:@"selection.sshKeyLocationEnabled"];
			return;
		}
		
		[favoritesController setValue:abbreviatedFileName forKeyPath:@"selection.sshKeyLocation"];
		
		// SSL key file selection
	} 
	else if (contextInfo == standardSSLKeyFileButton || contextInfo == socketSSLKeyFileButton) {
		if (returnCode == NSCancelButton) {
			[favoritesController setValue:[NSNumber numberWithInt:NSOffState] forKeyPath:@"selection.sslKeyFileLocationEnabled"];
			[favoritesController setValue:nil forKeyPath:@"selection.sslKeyFileLocation"];
			return;
		}
		
		[favoritesController setValue:abbreviatedFileName forKeyPath:@"selection.sslKeyFileLocation"];
		
		// SSL certificate file selection
	} 
	else if (contextInfo == standardSSLCertificateButton || contextInfo == socketSSLCertificateButton) {
		if (returnCode == NSCancelButton) {
			[favoritesController setValue:[NSNumber numberWithInt:NSOffState] forKeyPath:@"selection.sslCertificateFileLocationEnabled"];
			[favoritesController setValue:nil forKeyPath:@"selection.sslCertificateFileLocation"];
			return;
		}
		
		[favoritesController setValue:abbreviatedFileName forKeyPath:@"selection.sslCertificateFileLocation"];
		
		// SSL CA certificate file selection
	} 
	else if (contextInfo == standardSSLCACertButton || contextInfo == socketSSLCACertButton) {
		if (returnCode == NSCancelButton) {
			[favoritesController setValue:[NSNumber numberWithInt:NSOffState] forKeyPath:@"selection.sslCACertFileLocationEnabled"];
			[favoritesController setValue:nil forKeyPath:@"selection.sslCACertFileLocation"];
			return;
		}
		
		[favoritesController setValue:abbreviatedFileName forKeyPath:@"selection.sslCACertFileLocation"];
	}
}

- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	// Order out current sheet to suppress overlapping of sheets
	if ([sheet respondsToSelector:@selector(orderOut:)]) {
		[sheet orderOut:nil];
	}
	else if ([sheet respondsToSelector:@selector(window)]) {
		[[sheet window] orderOut:nil];
	}
	
	// Remove the current database
	if ([contextInfo isEqualToString:@"removeFavorite"]) {
		if (returnCode == NSAlertDefaultReturn) {
			
			// Get selected favorite's details
			NSString *name     = [favoritesController valueForKeyPath:@"selection.name"];
			NSString *user     = [favoritesController valueForKeyPath:@"selection.user"];
			NSString *host     = [favoritesController valueForKeyPath:@"selection.host"];
			NSString *database = [favoritesController valueForKeyPath:@"selection.database"];
			NSString *sshUser  = [favoritesController valueForKeyPath:@"selection.sshUser"];
			NSString *sshHost  = [favoritesController valueForKeyPath:@"selection.sshHost"];
			NSString *favoriteid = [favoritesController valueForKeyPath:@"selection.id"];
			NSInteger type     = [[favoritesController valueForKeyPath:@"selection.type"] integerValue];
			
			// Remove passwords from the Keychain
			[keychain deletePasswordForName:[keychain nameForFavoriteName:name id:favoriteid]
									account:[keychain accountForUser:user host:((type == SPSocketConnection)?@"localhost":host) database:database]];
			[keychain deletePasswordForName:[keychain nameForSSHForFavoriteName:name id:favoriteid]
									account:[keychain accountForSSHUser:sshUser sshHost:sshHost]];
			
			// Reset last used favorite
			if ([favoritesTableView selectedRow] == [prefs integerForKey:SPLastFavoriteIndex]) {
				[prefs setInteger:0	forKey:SPLastFavoriteIndex];
			}
			
			// Reset default favorite
			if ([favoritesTableView selectedRow] == [prefs integerForKey:SPDefaultFavorite]) {
				[prefs setInteger:[prefs integerForKey:SPLastFavoriteIndex] forKey:SPDefaultFavorite];
			}
			
			[favoritesController removeObjectAtArrangedObjectIndex:[favoritesTableView selectedRow]];
			
			[favoritesTableView reloadData];
			
			[[(SPPreferenceController *)[[[self view] window] delegate] generalPreferencePane] updateDefaultFavoritePopup];
		}
	}	
}

#pragma mark -
#pragma mark Preference pane protocol methods

- (NSView *)preferencePaneView
{
	return [self view];
}

- (NSImage *)preferencePaneIcon
{
	return [NSImage imageNamed:@"toolbar-preferences-favorites"];
}

- (NSString *)preferencePaneName
{
	return NSLocalizedString(@"Favorites", @"favorites label");
}

- (NSString *)preferencePaneIdentifier
{
	return SPPreferenceToolbarFavorites;
}

- (NSString *)preferencePaneToolTip
{
	return NSLocalizedString(@"Favorite Preferences", @"favorites preference pane tooltip");
}

- (BOOL)preferencePaneAllowsResizing
{
	return YES;
}

#pragma mark -
#pragma mark Private API

/**
 * Sorts the connection favorites based on the selected criteria.
 */
- (void)_sortFavorites
{		
	NSString *sortKey = SPFavoriteNameKey;
	
	switch (currentSortItem)
	{
		case SPFavoritesSortNameItem:
			sortKey = SPFavoriteNameKey;
			break;
		case SPFavoritesSortHostItem:
			sortKey = SPFavoriteHostKey;
			break;
		case SPFavoritesSortTypeItem:
			sortKey = SPFavoriteTypeKey;
			break;
		default:
			return;
	}
	
	NSSortDescriptor *sortDescriptor = nil;
	
	if (currentSortItem == SPFavoritesSortTypeItem) {
		sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:sortKey ascending:(!reverseFavoritesSort)] autorelease];
	}
	else {
		sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:sortKey ascending:(!reverseFavoritesSort) selector:@selector(caseInsensitiveCompare:)] autorelease];
	}
	
	[favoritesController setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
	
	[favoritesTableView reloadData];
	
	[[(SPPreferenceController *)[[[self view] window] delegate] generalPreferencePane] updateDefaultFavoritePopup];
}

/**
 * Check all fields used in the keychain names against the old values for that
 * favorite, and update the keychain names to match if necessary.
 * If an (optional) recognised password field is supplied, that field is assumed
 * to have changed and is used to supply the new value.
 */
- (void)_updateFavoritePasswordsFromField:(NSControl *)passwordControl
{
	if (!currentFavorite) return;
	
	NSString *passwordValue;
	NSString *oldKeychainName, *newKeychainName;
	NSString *oldKeychainAccount, *newKeychainAccount;
	NSString *oldHostnameForPassword = ([[currentFavorite objectForKey:@"type"] integerValue] == SPSocketConnection) ? @"localhost" : [currentFavorite objectForKey:@"host"];
	NSString *newHostnameForPassword = ([[favoritesController valueForKeyPath:@"selection.type"] integerValue] == SPSocketConnection) ? @"localhost" : [favoritesController valueForKeyPath:@"selection.host"];
	
	// SQL passwords are indexed by name, host, user and database.  If any of these
	// have changed, or a standard password field has, alter the keychain item to match.
	if (![[currentFavorite objectForKey:@"name"] isEqualToString:[favoritesController valueForKeyPath:@"selection.name"]]
		|| ![oldHostnameForPassword isEqualToString:newHostnameForPassword]
		|| ![[currentFavorite objectForKey:@"user"] isEqualToString:[favoritesController valueForKeyPath:@"selection.user"]]
		|| ![[currentFavorite objectForKey:@"database"] isEqualToString:[favoritesController valueForKeyPath:@"selection.database"]]
		|| passwordControl == standardPasswordField || passwordControl == socketPasswordField || passwordControl == sshSQLPasswordField)
	{
		
		// Determine the correct password field to read the password from, defaulting to standard
		if (passwordControl == socketPasswordField) {
			passwordValue = [socketPasswordField stringValue];
		} 
		else if (passwordControl == sshSQLPasswordField) {
			passwordValue = [sshSQLPasswordField stringValue];
		} 
		else {
			passwordValue = [standardPasswordField stringValue];
		}
		
		// Get the old keychain name and account strings
		oldKeychainName = [keychain nameForFavoriteName:[currentFavorite objectForKey:@"name"] id:[favoritesController valueForKeyPath:@"selection.id"]];
		oldKeychainAccount = [keychain accountForUser:[currentFavorite objectForKey:@"user"] host:oldHostnameForPassword database:[currentFavorite objectForKey:@"database"]];
		
		// Delete the old keychain item
		[keychain deletePasswordForName:oldKeychainName account:oldKeychainAccount];
		
		// Set up the new keychain name and account strings
		newKeychainName = [keychain nameForFavoriteName:[favoritesController valueForKeyPath:@"selection.name"] id:[favoritesController valueForKeyPath:@"selection.id"]];
		newKeychainAccount = [keychain accountForUser:[favoritesController valueForKeyPath:@"selection.user"] host:newHostnameForPassword database:[favoritesController valueForKeyPath:@"selection.database"]];
		
		// Add the new keychain item if the password field has a value
		if ([passwordValue length])
			[keychain addPassword:passwordValue forName:newKeychainName account:newKeychainAccount];
		
		// Synch password changes
		[standardPasswordField setStringValue:passwordValue];
		[socketPasswordField setStringValue:passwordValue];
		[sshSQLPasswordField setStringValue:passwordValue];
		
		passwordValue = @"";
	}
	
	// If SSH account/password details have changed, update the keychain to match
	if (![[currentFavorite objectForKey:@"name"] isEqualToString:[favoritesController valueForKeyPath:@"selection.name"]]
		|| ![[currentFavorite objectForKey:@"sshHost"] isEqualToString:[favoritesController valueForKeyPath:@"selection.sshHost"]]
		|| ![[currentFavorite objectForKey:@"sshUser"] isEqualToString:[favoritesController valueForKeyPath:@"selection.sshUser"]]
		|| passwordControl == sshPasswordField) {
		
		// Get the old keychain name and account strings
		oldKeychainName = [keychain nameForSSHForFavoriteName:[currentFavorite objectForKey:@"name"] id:[favoritesController valueForKeyPath:@"selection.id"]];
		oldKeychainAccount = [keychain accountForSSHUser:[currentFavorite objectForKey:@"sshUser"] sshHost:[currentFavorite objectForKey:@"sshHost"]];
		
		// Delete the old keychain item
		[keychain deletePasswordForName:oldKeychainName account:oldKeychainAccount];
		
		// Set up the new keychain name and account strings
		newKeychainName = [keychain nameForSSHForFavoriteName:[favoritesController valueForKeyPath:@"selection.name"] id:[favoritesController valueForKeyPath:@"selection.id"]];
		newKeychainAccount = [keychain accountForSSHUser:[favoritesController valueForKeyPath:@"selection.sshUser"] sshHost:[favoritesController valueForKeyPath:@"selection.sshHost"]];
		
		// Add the new keychain item if the password field has a value
		if ([[sshPasswordField stringValue] length])
			[keychain addPassword:[sshPasswordField stringValue] forName:newKeychainName account:newKeychainAccount];
	}
	
	// Update the current favorite
	if (currentFavorite) [currentFavorite release], currentFavorite = nil;
	
	if ([[favoritesTableView selectedRowIndexes] count] > 0)
		currentFavorite = [[[favoritesController selectedObjects] objectAtIndex:0] copy];
}

#pragma mark -

- (void)dealloc
{
	[keychain release], keychain = nil;
	
	if (currentFavorite) [currentFavorite release], currentFavorite = nil;
	
	[super dealloc];
}

@end
