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
#import "SPKeychain.h"
#import "TableDocument.h"
#import "SPConnectionController.h"
#import "SPConstants.h"

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

		currentFavorite = nil;
		keychain = nil;
		favoriteNameFieldWasTouched = YES;
		favoriteType = 0;
	}

	return self;
}

// -------------------------------------------------------------------------------
// windowDidLoad
// -------------------------------------------------------------------------------
- (void)windowDidLoad
{	
	[self _setupToolbar];
	
	keychain = [[SPKeychain alloc] init];
	
	[tableCell setImage:[NSImage imageNamed:@"database"]];
	
	// Replace column's NSTextFieldCell with custom SWProfileTextFieldCell
	[[[favoritesTableView tableColumns] objectAtIndex:0] setDataCell:tableCell];
	
	[favoritesTableView registerForDraggedTypes:[NSArray arrayWithObject:FAVORITES_PB_DRAG_TYPE]];
	
	[favoritesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	[favoritesTableView reloadData];
	
	// Hide the tabs on the favorites tab view - left visible in IB for easy use
	[favoritesTabView setTabViewType:NSNoTabsNoBorder];

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
	int i;
	int currentVersionNumber, recordedVersionNumber = 0;

	// Get the current bundle version number (the SVN build number) for per-version upgrades
	currentVersionNumber = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] intValue];

	// Get the current revision
	if ([prefs objectForKey:@"lastUsedVersion"]) recordedVersionNumber = [[prefs objectForKey:@"lastUsedVersion"] intValue];
	if ([prefs objectForKey:SPLastUsedVersion]) recordedVersionNumber = [[prefs objectForKey:SPLastUsedVersion] intValue];

	// Skip processing if the current version matches or is less than recorded version
	if (currentVersionNumber <= recordedVersionNumber) return;

	// If no recorded version, update to current revision and skip processing
	if (!recordedVersionNumber) {
		[prefs setObject:[NSNumber numberWithInt:currentVersionNumber] forKey:SPLastUsedVersion];
		return;
	}

	// For versions prior to r336 (0.9.4), where column widths have been saved, walk through them and remove
	// any table widths set to 15 or less (fix for mangled columns caused by Issue #140)
	if (recordedVersionNumber < 336 && [prefs objectForKey:SPTableColumnWidths] != nil) {
		NSEnumerator *databaseEnumerator, *tableEnumerator, *columnEnumerator;
		NSString *databaseKey, *tableKey, *columnKey;
		NSMutableDictionary *newDatabase, *newTable;
		float columnWidth;
		NSMutableDictionary *newTableColumnWidths = [[NSMutableDictionary alloc] init];

		databaseEnumerator = [[prefs objectForKey:SPTableColumnWidths] keyEnumerator];
		while (databaseKey = [databaseEnumerator nextObject]) {
			newDatabase = [[NSMutableDictionary alloc] init];
			tableEnumerator = [[[prefs objectForKey:SPTableColumnWidths] objectForKey:databaseKey] keyEnumerator];
			while (tableKey = [tableEnumerator nextObject]) {
				newTable = [[NSMutableDictionary alloc] init];
				columnEnumerator = [[[[prefs objectForKey:SPTableColumnWidths] objectForKey:databaseKey] objectForKey:tableKey] keyEnumerator];
				while (columnKey = [columnEnumerator nextObject]) {
					columnWidth = [[[[[prefs objectForKey:SPTableColumnWidths] objectForKey:databaseKey] objectForKey:tableKey] objectForKey:columnKey] floatValue];
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
		[prefs setObject:[NSDictionary dictionaryWithDictionary:newTableColumnWidths] forKey:SPTableColumnWidths];
		[newTableColumnWidths release];
	}

	// For versions prior to r561 (0.9.5), migrate old pref keys where they exist to the new pref keys
	if (recordedVersionNumber < 561) {
		NSEnumerator *keyEnumerator;
		NSString *oldKey, *newKey;
		NSDictionary *keysToUpgrade = [NSDictionary dictionaryWithObjectsAndKeys:
			@"encoding", SPDefaultEncoding,
			@"useMonospacedFonts", SPUseMonospacedFonts,
			@"reloadAfterAdding", SPReloadAfterAddingRow,
			@"reloadAfterEditing", SPReloadAfterEditingRow,
			@"reloadAfterRemoving", SPReloadAfterRemovingRow,
			@"dontShowBlob", SPLoadBlobsAsNeeded,
			@"fetchRowCount", SPFetchCorrectRowCount,
			@"limitRows", SPLimitResults,
			@"limitRowsValue", SPLimitResultsValue,
			@"nullValue", SPNullValue,
			@"showError", SPShowNoAffectedRowsError,
			@"connectionTimeout", SPConnectionTimeoutValue,
			@"keepAliveInterval", SPKeepAliveInterval,
			@"lastFavoriteIndex", SPLastFavoriteIndex,
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
	if (recordedVersionNumber < 567 && [prefs objectForKey:SPFavorites]) {
		NSMutableArray *favoritesArray = [NSMutableArray arrayWithArray:[prefs objectForKey:SPFavorites]];
		NSMutableDictionary *favorite;
		NSString *password, *keychainName, *keychainAccount;
		SPKeychain *upgradeKeychain = [[SPKeychain alloc] init];

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
		[prefs setObject:[NSArray arrayWithArray:favoritesArray] forKey:SPFavorites];
		[upgradeKeychain release];
		password = nil;
	}

	// For versions prior to r981 (~0.9.6), upgrade the favourites to include a connection type for each
	if (recordedVersionNumber < 981 && [prefs objectForKey:SPFavorites]) {
		NSMutableArray *favoritesArray = [NSMutableArray arrayWithArray:[prefs objectForKey:SPFavorites]];
		NSMutableDictionary *favorite;

		// Cycle through the favorites
		for (i = 0; i < [favoritesArray count]; i++) {
			favorite = [NSMutableDictionary dictionaryWithDictionary:[favoritesArray objectAtIndex:i]];
			if ([favorite objectForKey:@"type"]) continue;

			// If the favorite has a socket, or has the host set to "localhost", set to socket-type connection
			if ([[favorite objectForKey:@"host"] isEqualToString:@"localhost"]
				|| ([favorite objectForKey:@"socket"] && [[favorite objectForKey:@"socket"] length]))
			{
				[favorite setObject:[NSNumber numberWithInt:1] forKey:@"type"];
			
			// If SSH details are set, set to tunnel connection
			} else if ([favorite objectForKey:@"useSSH"] && [[favorite objectForKey:@"useSSH"] intValue]) {
				[favorite setObject:[NSNumber numberWithInt:2] forKey:@"type"];

			// Default to TCP/IP
			} else {
				[favorite setObject:[NSNumber numberWithInt:0] forKey:@"type"];
			}
			
			// Remove SSH tunnel flag - no longer required
			[favorite removeObjectForKey:@"useSSH"];

			[favoritesArray replaceObjectAtIndex:i withObject:[NSDictionary dictionaryWithDictionary:favorite]];
		}
		[prefs setObject:[NSArray arrayWithArray:favoritesArray] forKey:SPFavorites];
	}

	// For versions prior to r1128 (~0.9.6), reset the main window toolbar items to add new items
	if (recordedVersionNumber < 1128 && [prefs objectForKey:@"NSToolbar Configuration TableWindowToolbar"]) {
		NSMutableDictionary *toolbarDict = [NSMutableDictionary dictionaryWithDictionary:[prefs objectForKey:@"NSToolbar Configuration TableWindowToolbar"]];
		[toolbarDict removeObjectForKey:@"TB Item Identifiers"];
		[prefs setObject:[NSDictionary dictionaryWithDictionary:toolbarDict] forKey:@"NSToolbar Configuration TableWindowToolbar"];
	}
	
	// For versions prior to r1609 (~0.9.7), convert the query favorites array to an array of dictionaries
	if (recordedVersionNumber < 1609 && [prefs objectForKey:SPQueryFavorites]) {
		NSMutableArray *queryFavoritesArray = [NSMutableArray arrayWithArray:[prefs objectForKey:SPQueryFavorites]];
		
		for (i = 0; i < [queryFavoritesArray count]; i++)
		{
			id favorite = [queryFavoritesArray objectAtIndex:i];
			
			// If the favorite is already a dictionary, just make sure there's no newlines in the title
			if (([favorite isKindOfClass:[NSDictionary class]]) && ([favorite objectForKey:@"name"]) && ([favorite objectForKey:@"query"])) {
				NSMutableString *favoriteName = [NSMutableString stringWithString:[favorite objectForKey:@"name"]];
				[favoriteName replaceOccurrencesOfString:@"\n" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [favoriteName length])];
				[queryFavoritesArray replaceObjectAtIndex:i withObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithString:favoriteName], [favorite objectForKey:@"query"], nil] forKeys:[NSArray arrayWithObjects:@"name", @"query", nil]]];
				continue;
			}
			
			// By default make the query's name the first 32 characters of the query with '...' appended, stripping newlines
			NSMutableString *favoriteName = [NSMutableString stringWithString:[favorite stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]]];
			[favoriteName replaceOccurrencesOfString:@"\n" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [favoriteName length])];
			if ([favoriteName length] > 32) {
				[favoriteName deleteCharactersInRange:NSMakeRange(32, [favoriteName length] - 32)];
				[favoriteName appendString:@"..."];
			}

			[queryFavoritesArray replaceObjectAtIndex:i withObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithString:favoriteName], favorite, nil] forKeys:[NSArray arrayWithObjects:@"name", @"query", nil]]];
		}
		
		[prefs setObject:queryFavoritesArray forKey:SPQueryFavorites];
	}

	// Update the prefs revision
	[prefs setObject:[NSNumber numberWithInt:currentVersionNumber] forKey:SPLastUsedVersion];	
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
	NSMutableDictionary *favorite = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"New Favorite", [NSNumber numberWithInt:0], @"", @"", @"", @"", @"", @"", @"", @"", favoriteid, nil] 
																	   forKeys:[NSArray arrayWithObjects:@"name", @"type", @"host", @"socket", @"user", @"port", @"database", @"sshHost", @"sshUser", @"sshPort", @"id", nil]];
	
	[favoritesController addObject:favorite];
	[favoritesController setSelectionIndex:[[favoritesController arrangedObjects] count]-1];

	[favoritesTableView reloadData];
	[favoritesTableView scrollRowToVisible:[favoritesTableView selectedRow]];
	[self updateDefaultFavoritePopup];
	
	favoriteNameFieldWasTouched = NO;
	
	[[self window] makeFirstResponder:favoriteHostTextField];
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
		int type		   = [[favoritesController valueForKeyPath:@"selection.type"] intValue];

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
		int duplicatedFavoriteType = [[favorite objectForKey:@"type"] intValue];

		// Select the keychain passwords for duplication
		keychainName = [keychain nameForFavoriteName:[favorite objectForKey:@"name"] id:[favorite objectForKey:@"id"]];
		keychainAccount = [keychain accountForUser:[favorite objectForKey:@"user"] host:((duplicatedFavoriteType == SPSocketConnection)?@"localhost":[favorite objectForKey:@"host"]) database:[favorite objectForKey:@"database"]];
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
		[favoritesTableView scrollRowToVisible:[favoritesTableView selectedRow]];
		[self updateDefaultFavoritePopup];

		[[self window] makeFirstResponder:favoriteNameTextField];
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
		[prefs setBool:YES forKey:SPSelectLastFavoriteUsed];
	} else {
		[prefs setBool:NO forKey:SPSelectLastFavoriteUsed];

		// Minus 2 from index to account for the "Last Used" and separator items
		[prefs setInteger:[defaultFavoritePopup indexOfSelectedItem]-2 forKey:SPDefaultFavorite];
	}
}

#pragma mark -
#pragma mark Toolbar item IBAction methods

// -------------------------------------------------------------------------------
// displayGeneralPreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayGeneralPreferences:(id)sender
{
	[[self window] setMinSize:NSMakeSize(0, 0)];
	[[self window] setShowsResizeIndicator:NO];
	
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_GENERAL];
	[self _resizeWindowForContentView:generalView];
}

// -------------------------------------------------------------------------------
// displayTablePreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayTablePreferences:(id)sender
{
	[[self window] setMinSize:NSMakeSize(0, 0)];
	[[self window] setShowsResizeIndicator:NO];
	
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_TABLES];
	[self _resizeWindowForContentView:tablesView];
}

// -------------------------------------------------------------------------------
// displayEditorPreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayEditorPreferences:(id)sender
{
	[[self window] setMinSize:NSMakeSize(0, 0)];
	[[self window] setShowsResizeIndicator:NO];
	
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_EDITOR];
	NSFont *nf = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorFont]];
	[editorFontName setStringValue:[NSString stringWithFormat:@"%@, %.1f pt", [nf displayName], [nf pointSize]]];
	[self _resizeWindowForContentView:editorView];
}

// -------------------------------------------------------------------------------
// displayFavoritePreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayFavoritePreferences:(id)sender
{
	// To make the Favorites pane resizable give the window a minimum size and display the resize indicator. 
	// Notice that we still make all other panes non-resizable by removing the dsiplay of the indicator and
	// resetting the minimum size to zero.
	[[self window] setMinSize:NSMakeSize(500, 381)];
	[[self window] setShowsResizeIndicator:YES];
	
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_FAVORITES];
	[self _resizeWindowForContentView:favoritesView];
	
	// Set the default favorite popup back to preference
	if (sender == [defaultFavoritePopup lastItem]) {
		[defaultFavoritePopup selectItemAtIndex:(![prefs boolForKey:SPSelectLastFavoriteUsed]) ? ([prefs integerForKey:SPDefaultFavorite] + 2) : 0];
	}
}

// -------------------------------------------------------------------------------
// displayNotificationPreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayNotificationPreferences:(id)sender
{
	[[self window] setMinSize:NSMakeSize(0, 0)];
	[[self window] setShowsResizeIndicator:NO];
	
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_NOTIFICATIONS];
	[self _resizeWindowForContentView:notificationsView];
}

// -------------------------------------------------------------------------------
// displayAutoUpdatePreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayAutoUpdatePreferences:(id)sender
{
	[[self window] setMinSize:NSMakeSize(0, 0)];
	[[self window] setShowsResizeIndicator:NO];
	
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_AUTOUPDATE];
	[self _resizeWindowForContentView:autoUpdateView];
}

// -------------------------------------------------------------------------------
// displayNetworkPreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayNetworkPreferences:(id)sender
{
	[[self window] setMinSize:NSMakeSize(0, 0)];
	[[self window] setShowsResizeIndicator:NO];
	
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
	int lastFavoriteIndexCached;
	NSMutableDictionary *draggedRow;
	
	originalRow = [[[info draggingPasteboard] stringForType:FAVORITES_PB_DRAG_TYPE] intValue];
	destinationRow = row;

	if (destinationRow > originalRow) {
		destinationRow--;
	}
	
	draggedRow = [NSMutableDictionary dictionaryWithDictionary:[[favoritesController arrangedObjects] objectAtIndex:originalRow]];
	//Before deleting this favorite, we need to save the current index.
	//because removeObjectAtArrangedObjectIndex will set prefs LastFavoriteIndex to 0
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
		if ([[[[favoritesController arrangedObjects] objectAtIndex:index] objectForKey:@"type"] intValue] == SPSocketConnection) {
			[cell setFavoriteHost:@"localhost"];
		} else {
			[cell setFavoriteHost:[[[favoritesController arrangedObjects] objectAtIndex:index] objectForKey:@"host"]];
		}
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
	NSString *keychainName = [keychain nameForFavoriteName:[currentFavorite objectForKey:@"name"] id:[currentFavorite objectForKey:@"id"]];
	NSString *keychainAccount = [keychain accountForUser:[currentFavorite objectForKey:@"user"] host:(([[currentFavorite objectForKey:@"type"] intValue] == SPSocketConnection)?@"localhost":[currentFavorite objectForKey:@"host"]) database:[currentFavorite objectForKey:@"database"]];
	NSString *passwordValue = [keychain getPasswordForName:keychainName account:keychainAccount];
	[standardPasswordField setStringValue:passwordValue];
	[socketPasswordField setStringValue:passwordValue];
	[sshSQLPasswordField setStringValue:passwordValue];

	// Retrieve the SSH keychain password if appropriate.
	NSString *keychainSSHName = [keychain nameForSSHForFavoriteName:[currentFavorite objectForKey:@"name"] id:[currentFavorite objectForKey:@"id"]];
	NSString *keychainSSHAccount = [keychain accountForSSHUser:[currentFavorite objectForKey:@"sshUser"] sshHost:[currentFavorite objectForKey:@"sshHost"]];
	[sshPasswordField setStringValue:[keychain getPasswordForName:keychainSSHName account:keychainSSHAccount]];
	
	favoriteNameFieldWasTouched = YES;
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
	return (proposedMin + 94);
}

#pragma mark -
#pragma mark TextField delegate methods and type change action

// -------------------------------------------------------------------------------
// control:textShouldEndEditing:
// Trap editing end notifications and use them to update the keychain password
// appropriately when name, host, user, password or database changes.
// -------------------------------------------------------------------------------
- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{

	// Request a password refresh to keep keychain references in synch with favorites
	[self updateFavoritePasswordsFromField:control];

	// Proceed with editing
	return YES;
}

// -------------------------------------------------------------------------------
// controlTextDidChange:
// Trap and control the 'name' field of the selected favorite. If the user pressed
// 'Add Favorite' the 'name' field is set to "New Favorite". If the user do not
// change the 'name' field or delete that field it will be set to user@host automatically.
// -------------------------------------------------------------------------------
- (void)controlTextDidChange:(NSNotification *)aNotification
{

	id field = [aNotification object];
	BOOL nameFieldIsEmpty = (
		[[favoritesController valueForKeyPath:@"selection.name"] isEqualToString:@""] 
		|| [[favoriteNameTextField stringValue] isEqualToString:@""]);

	switch(favoriteType) {
		case 0:
		if(nameFieldIsEmpty || (!favoriteNameFieldWasTouched && (field == favoriteUserTextField || field == favoriteHostTextField))) {
			[favoriteNameTextField setStringValue:[NSString stringWithFormat:@"%@@%@", [favoriteUserTextField stringValue], [favoriteHostTextField stringValue]]];
			[favoritesController setValue:[favoriteNameTextField stringValue] forKeyPath:@"selection.name"];
			[prefs synchronize];
			// if name field is empty enable user@host update
			if(nameFieldIsEmpty) favoriteNameFieldWasTouched = NO;
		}
		break;
		case 1:
		if(nameFieldIsEmpty || (!favoriteNameFieldWasTouched && field == favoriteUserTextFieldSocket)) {
			[favoriteNameTextField setStringValue:[NSString stringWithFormat:@"%@@localhost", [favoriteUserTextFieldSocket stringValue]]];
			[favoritesController setValue:[favoriteNameTextField stringValue] forKeyPath:@"selection.name"];
			[prefs synchronize];
			// if name field is empty enable user@host update
			if(nameFieldIsEmpty) favoriteNameFieldWasTouched = NO;
		}
		break;
		case 2:
		if(nameFieldIsEmpty || (!favoriteNameFieldWasTouched && (field == favoriteUserTextFieldSSH || field == favoriteHostTextFieldSSH))) {
			[favoriteNameTextField setStringValue:[NSString stringWithFormat:@"%@@%@", [favoriteUserTextFieldSSH stringValue], [favoriteHostTextFieldSSH stringValue]]];
			[favoritesController setValue:[favoriteNameTextField stringValue] forKeyPath:@"selection.name"];
			[prefs synchronize];
			// if name field is empty enable user@host update
			if(nameFieldIsEmpty) favoriteNameFieldWasTouched = NO;
		}
		break;
		default:
		break;
	}
	
		
	if(field == favoriteNameTextField) {
		favoriteNameFieldWasTouched = YES;
	}

}
// -------------------------------------------------------------------------------
// favoriteTypeDidChange:
// Update the favorite host when the type changes.
// -------------------------------------------------------------------------------
- (IBAction)favoriteTypeDidChange:(id)sender
{

	// If not socket and host is localhost, clear.
	if ([sender indexOfSelectedItem] != 1
		&& [[favoritesController valueForKeyPath:@"selection.host"] isEqualToString:@"localhost"])
	{
		[favoritesController setValue:@"" forKeyPath:@"selection.host"];
	}

	favoriteType = [sender indexOfSelectedItem];
	
	// Update the name for a new added favorite if not touched by the user
	if(!favoriteNameFieldWasTouched) {
		[favoriteNameTextField setStringValue:[NSString stringWithFormat:@"%@@%@", 
			([favoritesController valueForKeyPath:@"selection.user"]) ? [favoritesController valueForKeyPath:@"selection.user"] : @"", 
			( ([sender indexOfSelectedItem] == 1) ? @"localhost" :
				(([favoritesController valueForKeyPath:@"selection.host"]) ? [favoritesController valueForKeyPath:@"selection.host"] : @""))
		]];
		[favoritesController setValue:[favoriteNameTextField stringValue] forKeyPath:@"selection.name"];
	}
	

	// Request a password refresh to keep keychain references in synch with the favorites
	[self updateFavoritePasswordsFromField:nil];
}

// -------------------------------------------------------------------------------
// updateFavoritePasswordsFromField:
// Check all fields used in the keychain names against the old values for that
// favorite, and update the keychain names to match if necessary.
// If an (optional) recognised password field is supplied, that field is assumed
// to have changed and is used to supply the new value.
// -------------------------------------------------------------------------------
- (void)updateFavoritePasswordsFromField:(NSControl *)passwordControl
{
	if (!currentFavorite) return;

	NSString *passwordValue;
	NSString *oldKeychainName, *newKeychainName;
	NSString *oldKeychainAccount, *newKeychainAccount;
	NSString *oldHostnameForPassword = ([[currentFavorite objectForKey:@"type"] intValue] == SPSocketConnection) ? @"localhost" : [currentFavorite objectForKey:@"host"];
	NSString *newHostnameForPassword = ([[favoritesController valueForKeyPath:@"selection.type"] intValue] == SPSocketConnection) ? @"localhost" : [favoritesController valueForKeyPath:@"selection.host"];

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
		} else if (passwordControl == sshSQLPasswordField) {
			passwordValue = [sshSQLPasswordField stringValue];
		} else {
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
		NSBeginInformationalAlertSheet(
			NSLocalizedString(@"Growl notification preferences", "Growl notification preferences alert title"),
			nil, nil, nil, [self window], self, nil, nil, nil,
			NSLocalizedString(@"All Growl notifications are enabled by default. To change which notifications are displayed, go to the Growl Preference Pane in the System Preferences and choose what notifications Growl should display from Sequel Pro.", @"Growl notification preferences alert message")
		);
	}
	
	[prefs setBool:value forKey:SPGrowlEnabled];
}

- (BOOL)growlEnabled
{
	return [prefs boolForKey:SPGrowlEnabled];
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
	
	int i;
	for(i=0; i<[[[favoritesController arrangedObjects] valueForKeyPath:@"name"] count]; i++ ){
		NSMenuItem *favoritePrefMenuItem = [[NSMenuItem alloc] initWithTitle:[[[favoritesController arrangedObjects] valueForKeyPath:@"name"] objectAtIndex:i] 
																	  action:NULL
															   keyEquivalent:@"" ];
		[[defaultFavoritePopup menu] addItem:favoritePrefMenuItem];
		[favoritePrefMenuItem release];
	}
	
	// Add item to switch to edit favorites pane
	[[defaultFavoritePopup menu] addItem:[NSMenuItem separatorItem]];
	[defaultFavoritePopup addItemWithTitle:@"Edit Favorites…"];
	[[[defaultFavoritePopup menu] itemWithTitle:@"Edit Favorites…"] setAction:@selector(displayFavoritePreferences:)];
	[[[defaultFavoritePopup menu] itemWithTitle:@"Edit Favorites…"] setTarget:self];
	
	// Select the default favorite from prefs
	if (![prefs boolForKey:SPSelectLastFavoriteUsed]) {
		[defaultFavoritePopup selectItemAtIndex:[prefs integerForKey:SPDefaultFavorite] + 2];
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
	[favoritesTableView scrollRowToVisible:[favoritesController selectionIndex]];
}

// -------------------------------------------------------------------------------
// selectFavoriteAtIndex:
//
// Selects the favorite at the specified index in the favorites list
// -------------------------------------------------------------------------------
- (void)selectFavoriteAtIndex:(unsigned int)theIndex
{
	[favoritesController setSelectionIndex:theIndex];
	[favoritesTableView scrollRowToVisible:theIndex];
}

// -------------------------------------------------------------------------------
// query editor font selection
//
// -------------------------------------------------------------------------------
// show the font panel
- (IBAction)showCustomQueryFontPanel:(id)sender
{
	[[NSFontPanel sharedFontPanel] setPanelFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorFont]] isMultiple:NO];
	[[NSFontPanel sharedFontPanel] makeKeyAndOrderFront:self];
}
// reset syntax highlighting colors
- (IBAction)setDefaultColors:(id)sender
{

	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.000 green:0.455 blue:0.000 alpha:1.000]] forKey:SPCustomQueryEditorCommentColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.769 green:0.102 blue:0.086 alpha:1.000]] forKey:SPCustomQueryEditorQuoteColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.200 green:0.250 blue:1.000 alpha:1.000]] forKey:SPCustomQueryEditorSQLKeywordColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.000 green:0.000 blue:0.658 alpha:1.000]] forKey:SPCustomQueryEditorBacktickColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.506 green:0.263 blue:0.000 alpha:1.000]] forKey:SPCustomQueryEditorNumericColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.500 green:0.500 blue:0.500 alpha:1.000]] forKey:SPCustomQueryEditorVariableColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.950 green:0.950 blue:0.950 alpha:1.000]] forKey:SPCustomQueryEditorHighlightQueryColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor blackColor]] forKey:SPCustomQueryEditorTextColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor blackColor]] forKey:SPCustomQueryEditorCaretColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]] forKey:SPCustomQueryEditorBackgroundColor];

}
// set font panel's valid modes
- (unsigned int)validModesForFontPanel:(NSFontPanel *)fontPanel
{
   return (NSFontPanelAllModesMask ^ NSFontPanelAllEffectsModeMask);
}
// Action receiver for a font change in the font panel
- (void)changeFont:(id)sender
{
	NSFont *nf = [[NSFontPanel sharedFontPanel] panelConvertFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorFont]]];	
	[prefs setObject:[NSArchiver archivedDataWithRootObject:nf] forKey:SPCustomQueryEditorFont];
	[editorFontName setStringValue:[NSString stringWithFormat:@"%@, %.1f pt", [nf displayName], [nf pointSize]]];
}

// -------------------------------------------------------------------------------
// dealloc
// -------------------------------------------------------------------------------
- (void)dealloc
{
	if (keychain) [keychain release], keychain = nil;
	if (currentFavorite) [currentFavorite release];

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

	[notificationsItem setLabel:NSLocalizedString(@"Alerts & Logs", @"")];
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
	/*shortcutItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_SHORTCUTS];
	
	[shortcutItem setLabel:NSLocalizedString(@"Shortcuts", @"")];
	[shortcutItem setImage:[NSImage imageNamed:@"toolbar-preferences-shortcuts"]];
	[shortcutItem setTarget:self];
	[shortcutItem setAction:@selector(NSBeep)];*/
	
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
