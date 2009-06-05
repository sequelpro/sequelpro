//
//  $Id$
//
//  SPPreferenceController.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Dec 10, 2008
//  Modified by Ben Perry (benperry.com.au) on Mar 28, 2009
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

#import "SPPreferenceController.h"
#import "SPWindowAdditions.h"
#import "SPFavoriteTextFieldCell.h"
#import "KeyChain.h"
#import "TableDocument.h"

#define FAVORITES_PB_DRAG_TYPE @"SequelProPreferencesPasteboard"

#define PREFERENCE_TOOLBAR_GENERAL			@"Preference Toolbar General"
#define PREFERENCE_TOOLBAR_TABLES			@"Preference Toolbar Tables"
#define PREFERENCE_TOOLBAR_FAVORITES		@"Preference Toolbar Favorites"
#define PREFERENCE_TOOLBAR_NOTIFICATIONS	@"Preference Toolbar Notifications"
#define PREFERENCE_TOOLBAR_AUTOUPDATE		@"Preference Toolbar Auto Update"
#define PREFERENCE_TOOLBAR_NETWORK			@"Preference Toolbar Network"
#define PREFERENCE_TOOLBAR_EDITOR			@"Preference Toolbar Editor"
#define PREFERENCE_TOOLBAR_SHORTCUTS		@"Preference Toolbar Shortcuts"

#pragma mark -

@interface SPPreferenceController (PrivateAPI)

- (void)_setupToolbar;
- (void)_resizeWindowForContentView:(NSView *)view;

@end

#pragma mark -

@implementation SPPreferenceController

// -------------------------------------------------------------------------------
// init
// -------------------------------------------------------------------------------
- (id)init
{
	if (self = [super initWithWindowNibName:@"Preferences"]) {
		prefs = [NSUserDefaults standardUserDefaults];
		[self applyRevisionChanges];
	}

	return self;
}

// -------------------------------------------------------------------------------
// windowDidLoad
// -------------------------------------------------------------------------------
- (void)windowDidLoad
{	
	[self _setupToolbar];
	
	keychain = [[KeyChain alloc] init];
	
	SPFavoriteTextFieldCell *tableCell = [[[SPFavoriteTextFieldCell alloc] init] autorelease];
	
	[tableCell setImage:[NSImage imageNamed:@"database"]];
	
	// Replace column's NSTextFieldCell with custom SWProfileTextFieldCell
	[[[favoritesTableView tableColumns] objectAtIndex:0] setDataCell:tableCell];
	
	[favoritesTableView registerForDraggedTypes:[NSArray arrayWithObject:FAVORITES_PB_DRAG_TYPE]];
	
	[favoritesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	[favoritesTableView reloadData];
	
	[self updateDefaultFavoritePopup];
	
	[prefs synchronize];
}

#pragma mark -
#pragma mark Preferences upgrade routine

// -------------------------------------------------------------------------------
// applyRevisionChanges
// Checks the revision number, applies any preference upgrades, and updates to
// latest revision.
// Currently uses both lastUsedVersion and LastUsedVersion for <0.9.5 compatibility.
// -------------------------------------------------------------------------------
- (void)applyRevisionChanges
{
	int currentVersionNumber, recordedVersionNumber = 0;

	// Get the current bundle version number (the SVN build number) for per-version upgrades
	currentVersionNumber = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] intValue];

	// Get the current revision
	if ([prefs objectForKey:@"lastUsedVersion"]) recordedVersionNumber = [[prefs objectForKey:@"lastUsedVersion"] intValue];
	if ([prefs objectForKey:@"LastUsedVersion"]) recordedVersionNumber = [[prefs objectForKey:@"LastUsedVersion"] intValue];

	// Skip processing if the current version matches or is less than recorded version
	if (currentVersionNumber <= recordedVersionNumber) return;

	// If no recorded version, update to current revision and skip processing
	if (!recordedVersionNumber) {
		[prefs setObject:[NSNumber numberWithInt:currentVersionNumber] forKey:@"LastUsedVersion"];
		return;
	}

	// For versions prior to r336 (0.9.4), where column widths have been saved, walk through them and remove
	// any table widths set to 15 or less (fix for mangled columns caused by Issue #140)
	if (recordedVersionNumber < 336 && [prefs objectForKey:@"tableColumnWidths"] != nil) {
		NSEnumerator *databaseEnumerator, *tableEnumerator, *columnEnumerator;
		NSString *databaseKey, *tableKey, *columnKey;
		NSMutableDictionary *newDatabase, *newTable;
		float columnWidth;
		NSMutableDictionary *newTableColumnWidths = [[NSMutableDictionary alloc] init];

		databaseEnumerator = [[prefs objectForKey:@"tableColumnWidths"] keyEnumerator];
		while (databaseKey = [databaseEnumerator nextObject]) {
			newDatabase = [[NSMutableDictionary alloc] init];
			tableEnumerator = [[[prefs objectForKey:@"tableColumnWidths"] objectForKey:databaseKey] keyEnumerator];
			while (tableKey = [tableEnumerator nextObject]) {
				newTable = [[NSMutableDictionary alloc] init];
				columnEnumerator = [[[[prefs objectForKey:@"tableColumnWidths"] objectForKey:databaseKey] objectForKey:tableKey] keyEnumerator];
				while (columnKey = [columnEnumerator nextObject]) {
					columnWidth = [[[[[prefs objectForKey:@"tableColumnWidths"] objectForKey:databaseKey] objectForKey:tableKey] objectForKey:columnKey] floatValue];
					if (columnWidth >= 15) {
						[newTable setObject:[NSNumber numberWithFloat:columnWidth] forKey:[NSString stringWithString:columnKey]];
					}
				}
				if ([newTable count]) {
					[newDatabase setObject:[NSDictionary dictionaryWithDictionary:newTable] forKey:[NSString stringWithString:tableKey]];
				}
				[newTable release];
			}
			if ([newDatabase count]) {
				[newTableColumnWidths setObject:[NSDictionary dictionaryWithDictionary:newDatabase] forKey:[NSString stringWithString:databaseKey]];
			}
			[newDatabase release];
		}
		[prefs setObject:[NSDictionary dictionaryWithDictionary:newTableColumnWidths] forKey:@"tableColumnWidths"];
		[newTableColumnWidths release];
	}

	// For versions prior to r561 (0.9.5), migrate old pref keys where they exist to the new pref keys
	if (recordedVersionNumber < 561) {
		NSEnumerator *keyEnumerator;
		NSString *oldKey, *newKey;
		NSDictionary *keysToUpgrade = [NSDictionary dictionaryWithObjectsAndKeys:
			@"encoding", @"DefaultEncoding",
			@"useMonospacedFonts", @"UseMonospacedFonts",
			@"reloadAfterAdding", @"ReloadAfterAddingRow",
			@"reloadAfterEditing", @"ReloadAfterEditingRow",
			@"reloadAfterRemoving", @"ReloadAfterRemovingRow",
			@"dontShowBlob", @"LoadBlobsAsNeeded",
			@"fetchRowCount", @"FetchCorrectRowCount",
			@"limitRows", @"LimitResults",
			@"limitRowsValue", @"LimitResultsValue",
			@"nullValue", @"NullValue",
			@"showError", @"ShowNoAffectedRowsError",
			@"connectionTimeout", @"ConnectionTimeoutValue",
			@"keepAliveInterval", @"KeepAliveInterval",
			@"lastFavoriteIndex", @"LastFavoriteIndex",
			nil];

		keyEnumerator = [keysToUpgrade keyEnumerator];
		while (newKey = [keyEnumerator nextObject]) {
			oldKey = [keysToUpgrade objectForKey:newKey];
			if ([prefs objectForKey:oldKey]) {
				[prefs setObject:[prefs objectForKey:oldKey] forKey:newKey];
				[prefs removeObjectForKey:oldKey];
			}
		}

		// Remove outdated keys
		[prefs removeObjectForKey:@"lastUsedVersion"];
		[prefs removeObjectForKey:@"version"];
	}

	// For versions prior to r567 (0.9.5), add a timestamp-based identifier to favorites and keychain entries
	if (recordedVersionNumber < 567 && [prefs objectForKey:@"favorites"]) {
		int i;
		NSMutableArray *favoritesArray = [NSMutableArray arrayWithArray:[prefs objectForKey:@"favorites"]];
		NSMutableDictionary *favorite;
		NSString *password, *keychainName, *keychainAccount;
		KeyChain *upgradeKeychain = [[KeyChain alloc] init];

		// Cycle through the favorites, generating a timestamp-derived ID for each and renaming associated keychain items.
		for (i = 0; i < [favoritesArray count]; i++) {
			favorite = [NSMutableDictionary dictionaryWithDictionary:[favoritesArray objectAtIndex:i]];
			if ([favorite objectForKey:@"id"]) continue;	
			[favorite setObject:[NSNumber numberWithInt:[[NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]] hash]] forKey:@"id"];
			keychainName = [NSString stringWithFormat:@"Sequel Pro : %@", [favorite objectForKey:@"name"]];
			keychainAccount = [NSString stringWithFormat:@"%@@%@/%@",
								[favorite objectForKey:@"user"], [favorite objectForKey:@"host"], [favorite objectForKey:@"database"]];
			password = [upgradeKeychain getPasswordForName:keychainName account:keychainAccount];
			[upgradeKeychain deletePasswordForName:keychainName account:keychainAccount];
			if (password && [password length]) {
				keychainName = [NSString stringWithFormat:@"Sequel Pro : %@ (%i)", [favorite objectForKey:@"name"], [[favorite objectForKey:@"id"] intValue]];
				[upgradeKeychain addPassword:password forName:keychainName account:keychainAccount];
			}
			[favoritesArray replaceObjectAtIndex:i withObject:[NSDictionary dictionaryWithDictionary:favorite]];
		}
		[prefs setObject:[NSArray arrayWithArray:favoritesArray] forKey:@"favorites"];
		[upgradeKeychain release];
		password = nil;
	}

	// Update the prefs revision
	[prefs setObject:[NSNumber numberWithInt:currentVersionNumber] forKey:@"LastUsedVersion"];	
}

#pragma mark -
#pragma mark IBAction methods

// -------------------------------------------------------------------------------
// addFavorite:
// -------------------------------------------------------------------------------
- (IBAction)addFavorite:(id)sender
{
	NSNumber *favoriteid = [NSNumber numberWithInt:[[NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]] hash]];

	// Create default favorite
	NSMutableDictionary *favorite = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"New Favorite", @"", @"", @"", @"", @"", favoriteid, nil] 
																	   forKeys:[NSArray arrayWithObjects:@"name", @"host", @"socket", @"user", @"port", @"database", @"id", nil]];
	
	[favoritesController addObject:favorite];
	
	[favoritesTableView reloadData];
	[self updateDefaultFavoritePopup];
}

// -------------------------------------------------------------------------------
// removeFavorite:
// -------------------------------------------------------------------------------
- (IBAction)removeFavorite:(id)sender
{
	if ([favoritesTableView numberOfSelectedRows] == 1) {
		
		// Get selected favorite's details
		NSString *name     = [favoritesController valueForKeyPath:@"selection.name"];
		NSString *user     = [favoritesController valueForKeyPath:@"selection.user"];
		NSString *host     = [favoritesController valueForKeyPath:@"selection.host"];
		NSString *database = [favoritesController valueForKeyPath:@"selection.database"];
		NSString *sshUser  = [favoritesController valueForKeyPath:@"selection.sshUser"];
		NSString *sshHost  = [favoritesController valueForKeyPath:@"selection.sshHost"];
		NSString *favoriteid = [favoritesController valueForKeyPath:@"selection.id"];

		// Remove passwords from the Keychain
		[keychain deletePasswordForName:[keychain nameForFavoriteName:name id:favoriteid]
								account:[keychain accountForUser:user host:host database:database]];
		[keychain deletePasswordForName:[keychain nameForSSHForFavoriteName:name id:favoriteid]
								account:[keychain accountForSSHUser:sshUser sshHost:sshHost]];
		
		// Reset last used favorite
		if ([favoritesTableView selectedRow] == [prefs integerForKey:@"LastFavoriteIndex"]) {
			[prefs setInteger:0	forKey:@"LastFavoriteIndex"];
		}
		
		// Reset default favorite
		if ([favoritesTableView selectedRow] == [prefs integerForKey:@"DefaultFavorite"]) {
			[prefs setInteger:[prefs integerForKey:@"LastFavoriteIndex"] forKey:@"DefaultFavorite"];
		}

		[favoritesController removeObjectAtArrangedObjectIndex:[favoritesTableView selectedRow]];
		
		[favoritesTableView reloadData];
		[self updateDefaultFavoritePopup];
	}
}

// -------------------------------------------------------------------------------
// duplicateFavorite:
// -------------------------------------------------------------------------------
- (IBAction)duplicateFavorite:(id)sender
{
	if ([favoritesTableView numberOfSelectedRows] == 1) {
		NSString *keychainName, *keychainAccount, *password, *keychainSSHName, *keychainSSHAccount, *sshPassword;
		NSMutableDictionary *favorite = [NSMutableDictionary dictionaryWithDictionary:[[favoritesController arrangedObjects] objectAtIndex:[favoritesTableView selectedRow]]];
		NSNumber *favoriteid = [NSNumber numberWithInt:[[NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]] hash]];

		// Select the keychain passwords for duplication
		keychainName = [keychain nameForFavoriteName:[favorite objectForKey:@"name"] id:[favorite objectForKey:@"id"]];
		keychainAccount = [keychain accountForUser:[favorite objectForKey:@"user"] host:[favorite objectForKey:@"host"] database:[favorite objectForKey:@"database"]];
		password = [keychain getPasswordForName:keychainName account:keychainAccount];
		keychainSSHName = [keychain nameForSSHForFavoriteName:[favorite objectForKey:@"name"] id:[favorite objectForKey:@"id"]];
		keychainSSHAccount = [keychain accountForSSHUser:[favorite objectForKey:@"sshUser"] sshHost:[favorite objectForKey:@"sshHost"]];
		sshPassword = [keychain getPasswordForName:keychainSSHName account:keychainSSHAccount];

		// Update the unique ID
		[favorite setObject:favoriteid forKey:@"id"];

		// Alter the name for clarity
		[favorite setObject:[NSString stringWithFormat:@"%@ Copy", [favorite objectForKey:@"name"]] forKey:@"name"];

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
		[favoritesController setSelectionIndex:[[favoritesController arrangedObjects] count]-1];

		[favoritesTableView reloadData];
		[self updateDefaultFavoritePopup];
	}
}

// -------------------------------------------------------------------------------
// saveFavorite:
// -------------------------------------------------------------------------------
- (IBAction)saveFavorite:(id)sender
{
	
}

// -------------------------------------------------------------------------------
// updateDefaultFavorite:
// -------------------------------------------------------------------------------
- (IBAction)updateDefaultFavorite:(id)sender
{
	if ([defaultFavoritePopup indexOfSelectedItem] == 0) {
		[prefs setBool:YES forKey:@"SelectLastFavoriteUsed"];
	} else {
		[prefs setBool:NO forKey:@"SelectLastFavoriteUsed"];

		// Minus 2 from index to account for the "Last Used" and separator items
		[prefs setInteger:[defaultFavoritePopup indexOfSelectedItem]-2 forKey:@"DefaultFavorite"];
	}
}

#pragma mark -
#pragma mark Toolbar item IBAction methods

// -------------------------------------------------------------------------------
// displayGeneralPreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayGeneralPreferences:(id)sender
{
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_GENERAL];
	[self _resizeWindowForContentView:generalView];
}

// -------------------------------------------------------------------------------
// displayTablePreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayTablePreferences:(id)sender
{
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_TABLES];
	[self _resizeWindowForContentView:tablesView];
}

// -------------------------------------------------------------------------------
// displayEditorPreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayEditorPreferences:(id)sender
{
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_EDITOR];
	NSFont *nf = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:@"CustomQueryEditorFont"]];
	[editorFontName setStringValue:[NSString stringWithFormat:@"%@, %.1f pt", [nf displayName], [nf pointSize]]];
	[self _resizeWindowForContentView:editorView];
}

// -------------------------------------------------------------------------------
// displayFavoritePreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayFavoritePreferences:(id)sender
{
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_FAVORITES];
	[self _resizeWindowForContentView:favoritesView];
	
	// Set the default favorite popup back to preference
	if (sender == [defaultFavoritePopup lastItem]) {
		if (![prefs boolForKey:@"SelectLastFavoriteUsed"]) {
			[defaultFavoritePopup selectItemAtIndex:[prefs integerForKey:@"DefaultFavorite"]+2];
		} else {
			[defaultFavoritePopup selectItemAtIndex:0];
		}
	}
}

// -------------------------------------------------------------------------------
// displayNotificationPreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayNotificationPreferences:(id)sender
{
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_NOTIFICATIONS];
	[self _resizeWindowForContentView:notificationsView];
}

// -------------------------------------------------------------------------------
// displayAutoUpdatePreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayAutoUpdatePreferences:(id)sender
{
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_AUTOUPDATE];
	[self _resizeWindowForContentView:autoUpdateView];
}

// -------------------------------------------------------------------------------
// displayNetworkPreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayNetworkPreferences:(id)sender
{
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_NETWORK];
	[self _resizeWindowForContentView:networkView];
}

#pragma mark -
#pragma mark TableView datasource methods

// -------------------------------------------------------------------------------
// numberOfRowsInTableView:
// -------------------------------------------------------------------------------
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [[favoritesController arrangedObjects] count];
}

// -------------------------------------------------------------------------------
// tableView:objectValueForTableColumn:row:
// -------------------------------------------------------------------------------
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	return [[[favoritesController arrangedObjects] objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
}

#pragma mark -
#pragma mark TableView drag & drop datasource methods

// -------------------------------------------------------------------------------
// tableView:writeRows:toPasteboard:
// -------------------------------------------------------------------------------
- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
	int originalRow;
	NSArray *pboardTypes;
	
	if ([rows count] == 1) {
		pboardTypes = [NSArray arrayWithObject:FAVORITES_PB_DRAG_TYPE];
		originalRow = [[rows objectAtIndex:0] intValue];
		
		[pboard declareTypes:pboardTypes owner:nil];
		[pboard setString:[[NSNumber numberWithInt:originalRow] stringValue] forType:FAVORITES_PB_DRAG_TYPE];
		
		return YES;
	} 
	else {		
		return NO;
	}
}

// -------------------------------------------------------------------------------
// tableView:validateDrop:proposedRow:proposedDropOperation:
// -------------------------------------------------------------------------------
- (NSDragOperation)tableView:(NSTableView *)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{	
	int originalRow;
	NSArray *pboardTypes = [[info draggingPasteboard] types];
	
	if (([pboardTypes count] > 1) && (row != -1)) {
		if (([pboardTypes containsObject:FAVORITES_PB_DRAG_TYPE]) && (operation == NSTableViewDropAbove)) {
			originalRow = [[[info draggingPasteboard] stringForType:FAVORITES_PB_DRAG_TYPE] intValue];
						
			if ((row != originalRow) && (row != (originalRow + 1))) {
				return NSDragOperationMove;
			}
		}
	}
	
	return NSDragOperationNone;
}

// -------------------------------------------------------------------------------
// tableView:acceptDrop:row:dropOperation:
// -------------------------------------------------------------------------------
- (BOOL)tableView:(NSTableView *)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{	
	int originalRow;
	int destinationRow;
	NSMutableDictionary *draggedRow;
	
	originalRow = [[[info draggingPasteboard] stringForType:FAVORITES_PB_DRAG_TYPE] intValue];
	destinationRow = row;
	
	if (destinationRow > originalRow) {
		destinationRow--;
	}
	
	draggedRow = [NSMutableDictionary dictionaryWithDictionary:[[favoritesController arrangedObjects] objectAtIndex:originalRow]];
	
	[favoritesController removeObjectAtArrangedObjectIndex:originalRow];
	[favoritesController insertObject:draggedRow atArrangedObjectIndex:destinationRow];
	
	[favoritesTableView reloadData];
	[favoritesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:destinationRow] byExtendingSelection:NO];
	
	// Update default favorite to take on new value
	if ([prefs integerForKey:@"LastFavoriteIndex"] == originalRow) {
		[prefs setInteger:destinationRow forKey:@"LastFavoriteIndex"];
	}
	
	// Update default favorite to take on new value
	if ([prefs integerForKey:@"DefaultFavorite"] == originalRow) {
		[prefs setInteger:destinationRow forKey:@"DefaultFavorite"];
	}
	[self updateDefaultFavoritePopup];
	
	return YES;
}

#pragma mark -
#pragma mark TableView delegate methods
	
// -------------------------------------------------------------------------------
// tableView:willDisplayCell:forTableColumn:row:
// -------------------------------------------------------------------------------
- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(int)index
{
	if ([cell isKindOfClass:[SPFavoriteTextFieldCell class]]) {
		[cell setFavoriteName:[[[favoritesController arrangedObjects] objectAtIndex:index] objectForKey:@"name"]];
		[cell setFavoriteHost:[[[favoritesController arrangedObjects] objectAtIndex:index] objectForKey:@"host"]];
	}
}

// -------------------------------------------------------------------------------
// tableViewSelectionDidChange:
// -------------------------------------------------------------------------------
- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	if ([[favoritesTableView selectedRowIndexes] count] > 0) {
		[favoritesController setSelectionIndexes:[favoritesTableView selectedRowIndexes]];		
	}

	// If no selection is present, blank the field.
	if ([[favoritesTableView selectedRowIndexes] count] == 0) {
		[passwordField setStringValue:@""];
		[sshPasswordField setStringValue:@""];
		return;
	}

	// Otherwise retrieve and set the password.
	NSString *keychainName = [keychain nameForFavoriteName:[favoritesController valueForKeyPath:@"selection.name"] id:[favoritesController valueForKeyPath:@"selection.id"]];
	NSString *keychainAccount = [keychain accountForUser:[favoritesController valueForKeyPath:@"selection.user"] host:[favoritesController valueForKeyPath:@"selection.host"] database:[favoritesController valueForKeyPath:@"selection.database"]];

	[passwordField setStringValue:[keychain getPasswordForName:keychainName account:keychainAccount]];

	// Retrieve the SSH keychain password if appropriate.
	NSString *keychainSSHName = [keychain nameForSSHForFavoriteName:[favoritesController valueForKeyPath:@"selection.name"] id:[favoritesController valueForKeyPath:@"selection.id"]];
	NSString *keychainSSHAccount = [keychain accountForSSHUser:[favoritesController valueForKeyPath:@"selection.sshUser"] sshHost:[favoritesController valueForKeyPath:@"selection.sshHost"]];

	[sshPasswordField setStringValue:[keychain getPasswordForName:keychainSSHName account:keychainSSHAccount]];
}

#pragma mark -
#pragma mark Toolbar delegate methods

// -------------------------------------------------------------------------------
// toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:
// -------------------------------------------------------------------------------
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{		
    if ([itemIdentifier isEqualToString:PREFERENCE_TOOLBAR_GENERAL]) {
        return generalItem;
    }
	else if ([itemIdentifier isEqualToString:PREFERENCE_TOOLBAR_TABLES]) {
		return tablesItem;
	}
	else if ([itemIdentifier isEqualToString:PREFERENCE_TOOLBAR_FAVORITES]) {
		return favoritesItem;
	}
	else if ([itemIdentifier isEqualToString:PREFERENCE_TOOLBAR_NOTIFICATIONS]) {
		return notificationsItem;
	}
	else if ([itemIdentifier isEqualToString:PREFERENCE_TOOLBAR_AUTOUPDATE]) {
		return autoUpdateItem;
	}
	else if ([itemIdentifier isEqualToString:PREFERENCE_TOOLBAR_NETWORK]) {
		return networkItem;
	}
	else if ([itemIdentifier isEqualToString:PREFERENCE_TOOLBAR_EDITOR]) {
		return editorItem;
	}
	else if ([itemIdentifier isEqualToString:PREFERENCE_TOOLBAR_SHORTCUTS]) {
		return shortcutItem;
	}
	
    return [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
}

// -------------------------------------------------------------------------------
// toolbarAllowedItemIdentifiers:
// -------------------------------------------------------------------------------
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:PREFERENCE_TOOLBAR_GENERAL, PREFERENCE_TOOLBAR_TABLES, PREFERENCE_TOOLBAR_FAVORITES, PREFERENCE_TOOLBAR_NOTIFICATIONS, PREFERENCE_TOOLBAR_EDITOR, PREFERENCE_TOOLBAR_SHORTCUTS, PREFERENCE_TOOLBAR_AUTOUPDATE, PREFERENCE_TOOLBAR_NETWORK, nil];
}

// -------------------------------------------------------------------------------
// toolbarDefaultItemIdentifiers:
// -------------------------------------------------------------------------------
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:PREFERENCE_TOOLBAR_GENERAL, PREFERENCE_TOOLBAR_TABLES, PREFERENCE_TOOLBAR_FAVORITES, PREFERENCE_TOOLBAR_NOTIFICATIONS, PREFERENCE_TOOLBAR_EDITOR, PREFERENCE_TOOLBAR_SHORTCUTS, PREFERENCE_TOOLBAR_AUTOUPDATE, PREFERENCE_TOOLBAR_NETWORK, nil];
}

// -------------------------------------------------------------------------------
// toolbarSelectableItemIdentifiers:
// -------------------------------------------------------------------------------
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:PREFERENCE_TOOLBAR_GENERAL, PREFERENCE_TOOLBAR_TABLES, PREFERENCE_TOOLBAR_FAVORITES, PREFERENCE_TOOLBAR_NOTIFICATIONS, PREFERENCE_TOOLBAR_EDITOR, PREFERENCE_TOOLBAR_SHORTCUTS, PREFERENCE_TOOLBAR_AUTOUPDATE, PREFERENCE_TOOLBAR_NETWORK, nil];
}

#pragma mark -
#pragma mark SplitView delegate methods

// -------------------------------------------------------------------------------
// splitView:constrainMaxCoordinate:ofSubviewAt:
// -------------------------------------------------------------------------------
- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
{
	return (proposedMax - 220);
}

// -------------------------------------------------------------------------------
// splitView:constrainMinCoordinate:ofSubviewAt:
// -------------------------------------------------------------------------------
- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
{
	return (proposedMin + 100);
}

#pragma mark -
#pragma mark TextField delegate methods

// -------------------------------------------------------------------------------
// control:textShouldEndEditing:
// Trap editing end notifications and use them to update the keychain password
// appropriately when name, host, user, password or database changes.
// -------------------------------------------------------------------------------
- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
	NSString *oldKeychainName, *newKeychainName;
	NSString *oldKeychainAccount, *newKeychainAccount;

	// Only proceed for name, host, user or database changes, for both standard and SSH
	if (control != nameField && control != hostField && control != userField && control != passwordField && control != databaseField
		&& control != sshHostField && control != sshUserField && control != sshPasswordField)
		return YES;

	// If account/password details have changed, update the keychain to match
	if ([nameField stringValue] != [favoritesController valueForKeyPath:@"selection.name"]
		|| [hostField stringValue] != [favoritesController valueForKeyPath:@"selection.host"]
		|| [userField stringValue] != [favoritesController valueForKeyPath:@"selection.user"]
		|| [databaseField stringValue] != [favoritesController valueForKeyPath:@"selection.database"]
		|| control == passwordField) {

		// Get the current keychain name and account strings
		oldKeychainName = [keychain nameForFavoriteName:[favoritesController valueForKeyPath:@"selection.name"] id:[favoritesController valueForKeyPath:@"selection.id"]];
		oldKeychainAccount = [keychain accountForUser:[favoritesController valueForKeyPath:@"selection.user"] host:[favoritesController valueForKeyPath:@"selection.host"] database:[favoritesController valueForKeyPath:@"selection.database"]];

		// Set up the new keychain name and account strings
		newKeychainName = [keychain nameForFavoriteName:[nameField stringValue] id:[favoritesController valueForKeyPath:@"selection.id"]];
		newKeychainAccount = [keychain accountForUser:[userField stringValue] host:[hostField stringValue] database:[databaseField stringValue]];

		// Delete the old keychain item
		[keychain deletePasswordForName:oldKeychainName account:oldKeychainAccount];

		// Add the new keychain item if the password field has a value
		if ([[passwordField stringValue] length])
			[keychain addPassword:[passwordField stringValue] forName:newKeychainName account:newKeychainAccount];
	}


	// If SSH account/password details have changed, update the keychain to match
	if ([nameField stringValue] != [favoritesController valueForKeyPath:@"selection.name"]
		|| [sshHostField stringValue] != [favoritesController valueForKeyPath:@"selection.sshHost"]
		|| [sshUserField stringValue] != [favoritesController valueForKeyPath:@"selection.sshUser"]
		|| control == sshPasswordField) {

		// Get the current keychain name and account strings
		oldKeychainName = [keychain nameForSSHForFavoriteName:[favoritesController valueForKeyPath:@"selection.name"] id:[favoritesController valueForKeyPath:@"selection.id"]];
		oldKeychainAccount = [keychain accountForSSHUser:[favoritesController valueForKeyPath:@"selection.sshUser"] sshHost:[favoritesController valueForKeyPath:@"selection.sshHost"]];

		// Set up the new keychain name and account strings
		newKeychainName = [keychain nameForFavoriteName:[nameField stringValue] id:[favoritesController valueForKeyPath:@"selection.id"]];
		newKeychainAccount = [keychain accountForSSHUser:[sshUserField stringValue] sshHost:[sshHostField stringValue]];

		// Delete the old keychain item
		[keychain deletePasswordForName:oldKeychainName account:oldKeychainAccount];

		// Add the new keychain item if the password field has a value
		if ([[sshPasswordField stringValue] length])
			[keychain addPassword:[sshPasswordField stringValue] forName:newKeychainName account:newKeychainAccount];
	}

	// Proceed with editing
	return YES;
}

#pragma mark -
#pragma mark Window delegate methods

// -------------------------------------------------------------------------------
// windowWillClose:
// Trap window close notifications and use them to ensure changes are saved.
// -------------------------------------------------------------------------------
- (void)windowWillClose:(NSNotification *)notification
{
	// Mark the currently selected field in the window as having finished editing, to trigger saves.
	if ([preferencesWindow firstResponder])
		[preferencesWindow endEditingFor:[preferencesWindow firstResponder]];

}

#pragma mark -
#pragma mark Other


- (void)setGrowlEnabled:(BOOL)value
{
	if (value) {
		NSRunInformationalAlertPanel(
			NSLocalizedString(@"growl_prefs_title", "Title for Growl Notifications Alert Dialog"),
			NSLocalizedString(@"growl_prefs_msg", @"Message for Growl Notifications Alert Dialog"),
			nil,
			nil,
			nil
		);
	}
	
	[prefs setBool:value forKey:@"GrowlEnabled"];
}

- (BOOL)growlEnabled
{
	return [prefs boolForKey:@"GrowlEnabled"];
}


// -------------------------------------------------------------------------------
// updateDefaultFavoritePopup:
//
// Build the default favorite popup button
// -------------------------------------------------------------------------------
- (void)updateDefaultFavoritePopup;
{
	[defaultFavoritePopup removeAllItems];
	
	// Use the last used favorite
	[defaultFavoritePopup addItemWithTitle:@"Last Used"];
	[[defaultFavoritePopup menu] addItem:[NSMenuItem separatorItem]];
	
	// Load in current favorites
	[defaultFavoritePopup addItemsWithTitles:[[favoritesController arrangedObjects] valueForKeyPath:@"name"]];
	
	// Add item to switch to edit favorites pane
	[[defaultFavoritePopup menu] addItem:[NSMenuItem separatorItem]];
	[defaultFavoritePopup addItemWithTitle:@"Edit Favorites…"];
	[[[defaultFavoritePopup menu] itemWithTitle:@"Edit Favorites…"] setAction:@selector(displayFavoritePreferences:)];
	[[[defaultFavoritePopup menu] itemWithTitle:@"Edit Favorites…"] setTarget:self];
	
	// Select the default favorite from prefs
	if (![prefs boolForKey:@"SelectLastFavoriteUsed"]) {
		[defaultFavoritePopup selectItemAtIndex:[prefs integerForKey:@"DefaultFavorite"] + 2];
	} else {
		[defaultFavoritePopup selectItemAtIndex:0];
	}
}

// -------------------------------------------------------------------------------
// selectFavorite:
//
// Selects the specified favorite(s) in the favorites list
// -------------------------------------------------------------------------------
- (void)selectFavorites:(NSArray *)favorites
{
	[favoritesController setSelectedObjects:favorites];
}

// -------------------------------------------------------------------------------
// query editor font selection
//
// -------------------------------------------------------------------------------
// show the font panel
- (IBAction)showCustomQueryFontPanel:(id)sender
{
	[[NSFontPanel sharedFontPanel] setPanelFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:@"CustomQueryEditorFont"]] isMultiple:NO];
	[[NSFontPanel sharedFontPanel] makeKeyAndOrderFront:self];
}
// reset syntax highlighting colors
- (IBAction)setDefaultColors:(id)sender
{

	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.000 green:0.455 blue:0.000 alpha:1.000]] forKey:@"CustomQueryEditorCommentColor"];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.769 green:0.102 blue:0.086 alpha:1.000]] forKey:@"CustomQueryEditorQuoteColor"];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.200 green:0.250 blue:1.000 alpha:1.000]] forKey:@"CustomQueryEditorSQLKeywordColor"];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.000 green:0.000 blue:0.658 alpha:1.000]] forKey:@"CustomQueryEditorBacktickColor"];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.506 green:0.263 blue:0.000 alpha:1.000]] forKey:@"CustomQueryEditorNumericColor"];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.500 green:0.500 blue:0.500 alpha:1.000]] forKey:@"CustomQueryEditorVariableColor"];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.950 green:0.950 blue:0.950 alpha:1.000]] forKey:@"CustomQueryEditorHighlightQueryColor"];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor blackColor]] forKey:@"CustomQueryEditorTextColor"];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor blackColor]] forKey:@"CustomQueryEditorCaretColor"];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]] forKey:@"CustomQueryEditorBackgroundColor"];

}
// set font panel's valid modes
- (unsigned int)validModesForFontPanel:(NSFontPanel *)fontPanel
{
   return (NSFontPanelAllModesMask ^ NSFontPanelAllEffectsModeMask);
}
// Action receiver for a font change in the font panel
- (void)changeFont:(id)sender
{
	NSFont *nf = [[NSFontPanel sharedFontPanel] panelConvertFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:@"CustomQueryEditorFont"]]];	
	[prefs setObject:[NSArchiver archivedDataWithRootObject:nf] forKey:@"CustomQueryEditorFont"];
	[editorFontName setStringValue:[NSString stringWithFormat:@"%@, %.1f pt", [nf displayName], [nf pointSize]]];
}

// -------------------------------------------------------------------------------
// dealloc
// -------------------------------------------------------------------------------
- (void)dealloc
{
	[keychain release], keychain = nil;
	
	[super dealloc];
}

@end

#pragma mark -

@implementation SPPreferenceController (PrivateAPI)

// -------------------------------------------------------------------------------
// _setupToolbar
//
// Constructs the preferences' window toolbar.
// -------------------------------------------------------------------------------
- (void)_setupToolbar
{
	toolbar = [[[NSToolbar alloc] initWithIdentifier:@"Preference Toolbar"] autorelease];

	// General preferences
	generalItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_GENERAL];

	[generalItem setLabel:NSLocalizedString(@"General", @"")];
	[generalItem setImage:[NSImage imageNamed:@"toolbar-preferences-general"]];
	[generalItem setTarget:self];
	[generalItem setAction:@selector(displayGeneralPreferences:)];

	// Table preferences
	tablesItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_TABLES];

	[tablesItem setLabel:NSLocalizedString(@"Tables", @"")];
	[tablesItem setImage:[NSImage imageNamed:@"toolbar-preferences-tables"]];
	[tablesItem setTarget:self];
	[tablesItem setAction:@selector(displayTablePreferences:)];

	// Favorite preferences
	favoritesItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_FAVORITES];

	[favoritesItem setLabel:NSLocalizedString(@"Favorites", @"")];
	[favoritesItem setImage:[NSImage imageNamed:@"toolbar-preferences-favorites"]];
	[favoritesItem setTarget:self];
	[favoritesItem setAction:@selector(displayFavoritePreferences:)];

	// Notification preferences
	notificationsItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_NOTIFICATIONS];

	[notificationsItem setLabel:NSLocalizedString(@"Alerts", @"")];
	[notificationsItem setImage:[NSImage imageNamed:@"toolbar-preferences-notifications"]];
	[notificationsItem setTarget:self];
	[notificationsItem setAction:@selector(displayNotificationPreferences:)];

	// Editor preferences
	editorItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_EDITOR];
	
	[editorItem setLabel:NSLocalizedString(@"Query Editor", @"")];
	[editorItem setImage:[NSImage imageNamed:@"toolbar-preferences-queryeditor"]];
	[editorItem setTarget:self];
	[editorItem setAction:@selector(displayEditorPreferences:)];
	
	// Shortcut preferences
	shortcutItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_SHORTCUTS];
	
	[shortcutItem setLabel:NSLocalizedString(@"Shortcuts", @"")];
	[shortcutItem setImage:[NSImage imageNamed:@"toolbar-preferences-shortcuts"]];
	[shortcutItem setTarget:self];
	[shortcutItem setAction:@selector(NSBeep)];
	
	// AutoUpdate preferences
	autoUpdateItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_AUTOUPDATE];

	[autoUpdateItem setLabel:NSLocalizedString(@"Auto Update", @"")];
	[autoUpdateItem setImage:[NSImage imageNamed:@"toolbar-preferences-autoupdate"]];
	[autoUpdateItem setTarget:self];
	[autoUpdateItem setAction:@selector(displayAutoUpdatePreferences:)];

	// Network preferences
	networkItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_NETWORK];

	[networkItem setLabel:NSLocalizedString(@"Network", @"")];
	[networkItem setImage:[NSImage imageNamed:@"toolbar-preferences-network"]];
	[networkItem setTarget:self];
	[networkItem setAction:@selector(displayNetworkPreferences:)];

	[toolbar setDelegate:self];
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_GENERAL];
	[toolbar setAllowsUserCustomization:NO];

	[preferencesWindow setToolbar:toolbar];
	[preferencesWindow setShowsToolbarButton:NO];

	[self displayGeneralPreferences:nil];
}

// -------------------------------------------------------------------------------
// _resizeWindowForContentView:
//
// Resizes the window to the size of the supplied view.
// -------------------------------------------------------------------------------
- (void)_resizeWindowForContentView:(NSView *)view
{
	// remove all current views
	NSEnumerator *en = [[[preferencesWindow contentView] subviews] objectEnumerator];
	NSView *subview;
  
	while (subview = [en nextObject]) 
	{
		[subview removeFromSuperview];
	}
  
	// resize window
	[preferencesWindow resizeForContentView:view titleBarVisible:YES];
  
	// add view
	[[preferencesWindow contentView] addSubview:view];
	[view setFrameOrigin:NSMakePoint(0, 0)];
}

@end
