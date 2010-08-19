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
#import "SPDatabaseDocument.h"
#import "SPConnectionController.h"
#import "SPColorAdditions.h"
#import "SPColorWellCell.h"

@interface SPPreferenceController (PrivateAPI)

- (void)_setupToolbar;
- (void)_sortFavorites;
- (void)_resizeWindowForContentView:(NSView *)view;

@end

#pragma mark -

@implementation SPPreferenceController

/**
 * init.
 */
- (id)init
{
	if (self = [super initWithWindowNibName:@"Preferences"]) {
		prefs = [NSUserDefaults standardUserDefaults];
		
		[self applyRevisionChanges];

		currentFavorite = nil;
		keychain = nil;
		favoriteNameFieldWasTouched = YES;
		favoriteType = 0;
		fontChangeTarget = 0;
		reverseFavoritesSort = NO;

		previousSortItem = SPFavoritesSortNameItem;

		[NSColor setIgnoresAlpha:NO];

		themePath = [[[NSString stringWithString:@"~/Library/Application Support/Sequel Pro/Themes"] stringByExpandingTildeInPath] retain];
		editThemeListItems = [[NSArray arrayWithArray:[self getAvailableThemes]] retain];
	}

	return self;
}

/**
 * Sets up various interface controls once the window is loaded.
 */
- (void)windowDidLoad
{	
	[self _setupToolbar];
	
	keychain = [[SPKeychain alloc] init];
	
	// Set sort items
	currentSortItem = [prefs integerForKey:SPFavoritesSortedBy];
	reverseFavoritesSort = [prefs boolForKey:SPFavoritesSortedInReverse];
	
	[tableCell setImage:[NSImage imageNamed:@"database"]];
	
	// Replace column's NSTextFieldCell with custom SWProfileTextFieldCell
	[[[favoritesTableView tableColumns] objectAtIndex:0] setDataCell:tableCell];
	
	[favoritesTableView registerForDraggedTypes:[NSArray arrayWithObject:SPFavoritesPasteboardDragType]];
	
	[favoritesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	[favoritesTableView reloadData];
	
	// Hide the tabs on the favorites tab view - left visible in IB for easy use
	[favoritesTabView setTabViewType:NSNoTabsNoBorder];
	
	// Set the button bar delegate 
	[splitViewButtonBar setSplitViewDelegate:self];

	[self updateDefaultFavoritePopup];
	
	[prefs synchronize];
	
	if (currentSortItem > -1) {
		[self _sortFavorites];
	}	


	NSTableColumn *column;
	SPColorWellCell *colorCell;
	NSTextFieldCell *textCell;
	column = [[colorSettingTableView tableColumns] objectAtIndex: 0];
	textCell = [[[NSTextFieldCell alloc] init] autorelease];
	[textCell setFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorFont]]];
	column = [[colorSettingTableView tableColumns] objectAtIndex: 1];
	colorCell = [[[SPColorWellCell alloc] init] autorelease];
	[colorCell setEditable: YES];
	[colorCell setTarget: self];
	[colorCell setAction:@selector(colorClick:)];
	[column setDataCell:colorCell];
	
	editorColors = [[NSArray arrayWithObjects:
		SPCustomQueryEditorTextColor,
		SPCustomQueryEditorBackgroundColor,
		SPCustomQueryEditorCaretColor,
		SPCustomQueryEditorCommentColor,
		SPCustomQueryEditorSQLKeywordColor,
		SPCustomQueryEditorNumericColor,
		SPCustomQueryEditorQuoteColor,
		SPCustomQueryEditorBacktickColor,
		SPCustomQueryEditorVariableColor,
		SPCustomQueryEditorHighlightQueryColor,
		SPCustomQueryEditorSelectionColor,
		nil
		] retain];
	editorNameForColors = [[NSArray arrayWithObjects:
		NSLocalizedString(@"Text",@"text lable for color table"),
		NSLocalizedString(@"Background",@"background lable for color table"),
		NSLocalizedString(@"Caret",@"caret lable for color table"),
		NSLocalizedString(@"Comment",@"comment lable for color table"),
		NSLocalizedString(@"Keyword",@"keyword lable for color table"),
		NSLocalizedString(@"Numeric",@"numeric lable for color table"),
		NSLocalizedString(@"Quote",@"quote lable for color table"),
		NSLocalizedString(@"Backtick Quote",@"backtick quote lable for color table"),
		NSLocalizedString(@"Variable",@"variable lable for color table"),
		NSLocalizedString(@"Query Background",@"query background lable for color table"),
		NSLocalizedString(@"Selection",@"selection lable for color table"),
		nil
		] retain];

}

#pragma mark -
#pragma mark Preferences upgrade routine

/**
 * Checks the revision number, applies any preference upgrades, and updates to latest revision.
 * Currently uses both lastUsedVersion and LastUsedVersion for <0.9.5 compatibility.
 */
- (void)applyRevisionChanges
{
	NSInteger i;
	NSInteger currentVersionNumber, recordedVersionNumber = 0;

	// Get the current bundle version number (the SVN build number) for per-version upgrades
	currentVersionNumber = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] integerValue];

	// Get the current revision
	if ([prefs objectForKey:@"lastUsedVersion"]) recordedVersionNumber = [[prefs objectForKey:@"lastUsedVersion"] integerValue];
	if ([prefs objectForKey:SPLastUsedVersion]) recordedVersionNumber = [[prefs objectForKey:SPLastUsedVersion] integerValue];

	// Skip processing if the current version matches or is less than recorded version
	if (currentVersionNumber <= recordedVersionNumber) return;

	// If no recorded version, update to current revision and skip processing
	if (!recordedVersionNumber) {
		[prefs setObject:[NSNumber numberWithInteger:currentVersionNumber] forKey:SPLastUsedVersion];
		return;
	}

	// For versions prior to r336 (0.9.4), where column widths have been saved, walk through them and remove
	// any table widths set to 15 or less (fix for mangled columns caused by Issue #140)
	if (recordedVersionNumber < 336 && [prefs objectForKey:SPTableColumnWidths] != nil) {
		NSEnumerator *databaseEnumerator, *tableEnumerator, *columnEnumerator;
		NSString *databaseKey, *tableKey, *columnKey;
		NSMutableDictionary *newDatabase, *newTable;
		CGFloat columnWidth;
		NSMutableDictionary *newTableColumnWidths = [[NSMutableDictionary alloc] init];

		databaseEnumerator = [[prefs objectForKey:SPTableColumnWidths] keyEnumerator];
		while (databaseKey = [databaseEnumerator nextObject]) {
			newDatabase = [[NSMutableDictionary alloc] init];
			tableEnumerator = [[[prefs objectForKey:SPTableColumnWidths] objectForKey:databaseKey] keyEnumerator];
			while (tableKey = [tableEnumerator nextObject]) {
				newTable = [[NSMutableDictionary alloc] init];
				columnEnumerator = [[[[prefs objectForKey:SPTableColumnWidths] objectForKey:databaseKey] objectForKey:tableKey] keyEnumerator];
				while (columnKey = [columnEnumerator nextObject]) {
					columnWidth = [[[[[prefs objectForKey:SPTableColumnWidths] objectForKey:databaseKey] objectForKey:tableKey] objectForKey:columnKey] doubleValue];
					if (columnWidth >= 15) {
						[newTable setObject:[NSNumber numberWithDouble:columnWidth] forKey:[NSString stringWithString:columnKey]];
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
			@"fetchRowCount", @"FetchCorrectRowCount",
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
			[favorite setObject:[NSNumber numberWithInteger:[[NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]] hash]] forKey:@"id"];
			keychainName = [NSString stringWithFormat:@"Sequel Pro : %@", [favorite objectForKey:@"name"]];
			keychainAccount = [NSString stringWithFormat:@"%@@%@/%@",
								[favorite objectForKey:@"user"], [favorite objectForKey:@"host"], [favorite objectForKey:@"database"]];
			password = [upgradeKeychain getPasswordForName:keychainName account:keychainAccount];
			[upgradeKeychain deletePasswordForName:keychainName account:keychainAccount];
			if (password && [password length]) {
				keychainName = [NSString stringWithFormat:@"Sequel Pro : %@ (%ld)", [favorite objectForKey:@"name"], (long)[[favorite objectForKey:@"id"] integerValue]];
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
				|| ([favorite objectForKey:@"socket"] && [(NSString *)[favorite objectForKey:@"socket"] length]))
			{
				[favorite setObject:[NSNumber numberWithInteger:1] forKey:@"type"];
			
			// If SSH details are set, set to tunnel connection
			} else if ([favorite objectForKey:@"useSSH"] && [[favorite objectForKey:@"useSSH"] integerValue]) {
				[favorite setObject:[NSNumber numberWithInteger:2] forKey:@"type"];

			// Default to TCP/IP
			} else {
				[favorite setObject:[NSNumber numberWithInteger:0] forKey:@"type"];
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

	// For versions prior to r1636 (<0.9.8), remove the old "Fetch correct row count" pref
	if (recordedVersionNumber < 1636 && [prefs objectForKey:@"FetchCorrectRowCount"]) {
		[prefs removeObjectForKey:@"FetchCorrectRowCount"];
	}

	// For versions prior to r2057 (~0.9.8), reset the Sparkle prefs so the user is prompted about submitting information
	if (recordedVersionNumber < 2057 && [prefs objectForKey:@"SUEnableAutomaticChecks"]) {
		[prefs removeObjectForKey:@"SUEnableAutomaticChecks"];
		[prefs removeObjectForKey:@"SUSendProfileInfo"];
	}

	// For versions prior to 2325 (<0.9.9), convert the old encoding pref string into the new localizable constant
	if  (recordedVersionNumber < 2325 && [prefs objectForKey:@"DefaultEncoding"] && [[prefs objectForKey:@"DefaultEncoding"] isKindOfClass:[NSString class]]) {
		NSDictionary *encodingMap = [NSDictionary dictionaryWithObjectsAndKeys:
											[NSNumber numberWithInt:SPEncodingAutodetect], @"Autodetect",
											[NSNumber numberWithInt:SPEncodingUCS2], @"UCS-2 Unicode (ucs2)",
											[NSNumber numberWithInt:SPEncodingUTF8], @"UTF-8 Unicode (utf8)",
											[NSNumber numberWithInt:SPEncodingUTF8viaLatin1], @"UTF-8 Unicode via Latin 1",
											[NSNumber numberWithInt:SPEncodingASCII], @"US ASCII (ascii)",
											[NSNumber numberWithInt:SPEncodingLatin1], @"ISO Latin 1 (latin1)",
											[NSNumber numberWithInt:SPEncodingMacRoman], @"Mac Roman (macroman)",
											[NSNumber numberWithInt:SPEncodingCP1250Latin2], @"Windows Latin 2 (cp1250)",
											[NSNumber numberWithInt:SPEncodingISOLatin2], @"ISO Latin 2 (latin2)",
											[NSNumber numberWithInt:SPEncodingCP1256Arabic], @"Windows Arabic (cp1256)",
											[NSNumber numberWithInt:SPEncodingGreek], @"ISO Greek (greek)",
											[NSNumber numberWithInt:SPEncodingHebrew], @"ISO Hebrew (hebrew)",
											[NSNumber numberWithInt:SPEncodingLatin5Turkish], @"ISO Turkish (latin5)",
											[NSNumber numberWithInt:SPEncodingCP1257WinBaltic], @"Windows Baltic (cp1257)",
											[NSNumber numberWithInt:SPEncodingCP1251WinCyrillic], @"Windows Cyrillic (cp1251)",
											[NSNumber numberWithInt:SPEncodingBig5Chinese], @"Big5 Traditional Chinese (big5)",
											[NSNumber numberWithInt:SPEncodingShiftJISJapanese], @"Shift-JIS Japanese (sjis)",
											[NSNumber numberWithInt:SPEncodingEUCJPJapanese], @"EUC-JP Japanese (ujis)",
											[NSNumber numberWithInt:SPEncodingEUCKRKorean], @"EUC-KR Korean (euckr)",
											nil];
		NSNumber *newMappedValue = [encodingMap valueForKey:[prefs objectForKey:@"DefaultEncoding"]];
		if (newMappedValue == nil) newMappedValue = [NSNumber numberWithInt:0];
		[prefs setObject:newMappedValue forKey:@"DefaultEncodingTag"];
	}

	// Update the prefs revision
	[prefs setObject:[NSNumber numberWithInteger:currentVersionNumber] forKey:SPLastUsedVersion];	
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
	NSMutableDictionary *favorite = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"New Favorite", [NSNumber numberWithInteger:0], @"", @"", @"", @"", @"", @"", @"", @"", favoriteid, nil] 
																	   forKeys:[NSArray arrayWithObjects:@"name", @"type", @"host", @"socket", @"user", @"port", @"database", @"sshHost", @"sshUser", @"sshPort", @"id", nil]];
	
	[favoritesController addObject:favorite];
	[favoritesController setSelectedObjects:[NSArray arrayWithObject:favorite]];

	[favoritesTableView reloadData];
	[favoritesTableView scrollRowToVisible:[favoritesTableView selectedRow]];
	
	[self updateDefaultFavoritePopup];
	
	favoriteNameFieldWasTouched = NO;
	
	[[self window] makeFirstResponder:favoriteHostTextField];
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

		[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"removeFavorite"];
	}
}

/**
 * Duplicates the selected connection favorite.
 */
- (IBAction)duplicateFavorite:(id)sender
{
	if ([favoritesTableView numberOfSelectedRows] == 1) {
		NSString *keychainName, *keychainAccount, *password, *keychainSSHName, *keychainSSHAccount, *sshPassword;
		NSMutableDictionary *favorite = [NSMutableDictionary dictionaryWithDictionary:[[favoritesController arrangedObjects] objectAtIndex:[favoritesTableView selectedRow]]];
		NSNumber *favoriteid = [NSNumber numberWithInteger:[[NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]] hash]];
		NSInteger duplicatedFavoriteType = [[favorite objectForKey:@"type"] integerValue];

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
		
		[self updateDefaultFavoritePopup];

		[[self window] makeFirstResponder:favoriteNameTextField];
	}
}

/**
 * Updates the default favorite.
 */ 
- (IBAction)updateDefaultFavorite:(id)sender
{
	[prefs setBool:([defaultFavoritePopup indexOfSelectedItem] == 0) forKey:SPSelectLastFavoriteUsed];

	// Minus 2 from index to account for the "Last Used" and separator items
	[prefs setInteger:([defaultFavoritePopup indexOfSelectedItem] - 2) forKey:SPDefaultFavorite];
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
	
	if (previousSortItem > -1) [[[sender menu] itemAtIndex:previousSortItem] setState:NSOffState];
	
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
	// Minus 2 from index to account for the "Last Used" and separator items
	[prefs setInteger:[favoritesTableView selectedRow] forKey:SPDefaultFavorite];
	
	[favoritesTableView reloadData];
	
	[self updateDefaultFavoritePopup];
}

- (IBAction)exportColorScheme:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setRequiredFileType:SPColorThemeFileExtension];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:NO];
	[panel setCanSelectHiddenExtension:YES];
	[panel setCanCreateDirectories:YES];

	[panel beginSheetForDirectory:nil 
							 file:[NSString stringWithFormat:@"myTheme.%@", SPColorThemeFileExtension] 
				   modalForWindow:[self window] 
					modalDelegate:self 
				   didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) 
					  contextInfo:@"exportColorScheme"];
}

- (IBAction)importColorScheme:(id)sender
{

	if(![self checkForUnsavedTheme]) return;


	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanSelectHiddenExtension:YES];
	[panel setDelegate:self];
	[panel setCanChooseDirectories:NO];
	[panel setAllowsMultipleSelection:NO];
	
	[panel beginSheetForDirectory:nil 
						   file:@"" 
						  types:[NSArray arrayWithObjects:SPColorThemeFileExtension, @"tmTheme", nil] 
				 modalForWindow:[self window]
				  modalDelegate:self 
				 didEndSelector:@selector(panelDidEnd:returnCode:contextInfo:) 
					contextInfo:@"importColorScheme"];

}

- (IBAction)loadColorScheme:(id)sender
{

	if(![self checkForUnsavedTheme]) return;

	if([self loadColorSchemeFromFile:[NSString stringWithFormat:@"%@/%@.%@", themePath, [sender title], SPColorThemeFileExtension]]) {
		[prefs setObject:[sender title] forKey:SPCustomQueryEditorThemeName];
		[self updateDisplayColorThemeName];
	}

}

- (IBAction)saveAsColorScheme:(id)sender
{

	[[NSColorPanel sharedColorPanel] close];

	[enterNameAlertField setHidden:YES];
	[enterNameInputField setStringValue:@""];
	[enterNameLabel setStringValue:NSLocalizedString(@"Theme Name:", @"theme name label")];

	[NSApp beginSheet:enterNameWindow
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:@"saveTheme"];

}

- (IBAction)duplicateTheme:(id)sender
{
	if([editThemeListTable numberOfSelectedRows] != 1) return;
	
	NSString *selectedPath = [NSString stringWithFormat:@"%@/%@_copy.%@", themePath, [editThemeListItems objectAtIndex:[editThemeListTable selectedRow]], SPColorThemeFileExtension];

	NSFileManager *fm = [NSFileManager defaultManager];
	if(![fm fileExistsAtPath:selectedPath isDirectory:nil]) {
		if([fm copyItemAtPath:[NSString stringWithFormat:@"%@/%@.%@", themePath, [editThemeListItems objectAtIndex:[editThemeListTable selectedRow]], SPColorThemeFileExtension] toPath:selectedPath error:nil]) {
			
			if(editThemeListItems) [editThemeListItems release], editThemeListItems = nil;
			editThemeListItems = [[NSArray arrayWithArray:[self getAvailableThemes]] retain];
			[editThemeListTable reloadData];
			[self updateDisplayColorThemeName];
			[self updateColorSchemeSelectionMenu];
			return;

		}
	}

	NSBeep();
	[editThemeListTable reloadData];

}

- (IBAction)removeTheme:(id)sender
{
	if([editThemeListTable numberOfSelectedRows] != 1) return;
	
	NSString *selectedPath = [NSString stringWithFormat:@"%@/%@.%@", themePath, [editThemeListItems objectAtIndex:[editThemeListTable selectedRow]], SPColorThemeFileExtension];
	NSFileManager *fm = [NSFileManager defaultManager];
	if([fm fileExistsAtPath:selectedPath isDirectory:nil]) {
		if([fm removeItemAtPath:selectedPath error:nil]) {

			// Refresh current color theme setting name
			if([[[prefs objectForKey:SPCustomQueryEditorThemeName] lowercaseString] isEqualToString:[[editThemeListItems objectAtIndex:[editThemeListTable selectedRow]] lowercaseString]]) {
				[prefs setObject:@"User-defined" forKey:SPCustomQueryEditorThemeName];
			}

			if(editThemeListItems) [editThemeListItems release], editThemeListItems = nil;
			editThemeListItems = [[NSArray arrayWithArray:[self getAvailableThemes]] retain];
			[editThemeListTable reloadData];
			[self updateDisplayColorThemeName];
			[self updateColorSchemeSelectionMenu];
			return;

		}
	}

	NSBeep();
	[editThemeListTable reloadData];

}

- (IBAction)closePanelSheet:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
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
	
	[toolbar setSelectedItemIdentifier:SPPreferenceToolbarGeneral];
	[self _resizeWindowForContentView:generalView];
}

// -------------------------------------------------------------------------------
// displayTablePreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayTablePreferences:(id)sender
{
	[[self window] setMinSize:NSMakeSize(0, 0)];
	[[self window] setShowsResizeIndicator:NO];
	
	[toolbar setSelectedItemIdentifier:SPPreferenceToolbarTables];
	NSFont *nf = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPGlobalResultTableFont]];
	[globalResultTableFontName setStringValue:[NSString stringWithFormat:@"%@, %.1f pt", [nf displayName], [nf pointSize]]];
	[self _resizeWindowForContentView:tablesView];
}

// -------------------------------------------------------------------------------
// displayEditorPreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayEditorPreferences:(id)sender
{

	[self updateColorSchemeSelectionMenu];
	[self updateDisplayColorThemeName];

	[[self window] setMinSize:NSMakeSize(0, 0)];
	[[self window] setShowsResizeIndicator:NO];
	
	[toolbar setSelectedItemIdentifier:SPPreferenceToolbarEditor];
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
	
	[toolbar setSelectedItemIdentifier:SPPreferenceToolbarFavorites];
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
	
	[toolbar setSelectedItemIdentifier:SPPreferenceToolbarNotifications];
	[self _resizeWindowForContentView:notificationsView];
}

// -------------------------------------------------------------------------------
// displayAutoUpdatePreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayAutoUpdatePreferences:(id)sender
{
	[[self window] setMinSize:NSMakeSize(0, 0)];
	[[self window] setShowsResizeIndicator:NO];
	
	[toolbar setSelectedItemIdentifier:SPPreferenceToolbarAutoUpdate];
	[self _resizeWindowForContentView:autoUpdateView];
}

// -------------------------------------------------------------------------------
// displayNetworkPreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayNetworkPreferences:(id)sender
{
	[[self window] setMinSize:NSMakeSize(0, 0)];
	[[self window] setShowsResizeIndicator:NO];
	
	[toolbar setSelectedItemIdentifier:SPPreferenceToolbarNetwork];
	[self _resizeWindowForContentView:networkView];
}

#pragma mark -
#pragma mark TableView datasource methods

// -------------------------------------------------------------------------------
// numberOfRowsInTableView:
// -------------------------------------------------------------------------------
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if(aTableView == colorSettingTableView)
		return [editorColors count];
	else if(aTableView == editThemeListTable)
		return [editThemeListItems count];

	return [[favoritesController arrangedObjects] count];
}

// -------------------------------------------------------------------------------
// tableView:objectValueForTableColumn:row:
// -------------------------------------------------------------------------------
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if(tableView == colorSettingTableView) {
		if ([[tableColumn identifier] isEqualToString:@"name"])
			return [editorNameForColors objectAtIndex:rowIndex];
		else
			return [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:[editorColors objectAtIndex:rowIndex]]];
	} else if(tableView == editThemeListTable) {
		return [editThemeListItems objectAtIndex:rowIndex];
	} else {
		if ([[tableColumn identifier] isEqualToString:@"default"] && (rowIndex == [prefs integerForKey:SPDefaultFavorite])) {
			return [NSImage imageNamed:@"blue-tick"];
		}
		else {
			return [[[favoritesController arrangedObjects] objectAtIndex:rowIndex] objectForKey:[tableColumn identifier]];
		}
	}
	return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if(tableView == editThemeListTable) {

		// Theme name editing
		NSString *newName = (NSString*)anObject;

		// Check for non-valid names
		if(![newName length] || [[newName lowercaseString] isEqualToString:@"default"] || [[newName lowercaseString] isEqualToString:@"user-defined"]) {
			NSBeep();
			[editThemeListTable reloadData];
			return;
		}

		// Check if new name already exists
		for(NSString* item in editThemeListItems) {
			if([[item lowercaseString] isEqualToString:newName]) {
				NSBeep();
				[editThemeListTable reloadData];
				return;
			}
		}

		// Rename theme file
		NSFileManager *fm = [NSFileManager defaultManager];
		if(![fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@.%@", themePath, [editThemeListItems objectAtIndex:rowIndex], SPColorThemeFileExtension] toPath:[NSString stringWithFormat:@"%@/%@.%@", themePath, newName, SPColorThemeFileExtension] error:nil]) {
			NSBeep();
			[editThemeListTable reloadData];
			return;
		}

		// Refresh current color theme setting name
		if([[[prefs objectForKey:SPCustomQueryEditorThemeName] lowercaseString] isEqualToString:[[editThemeListItems objectAtIndex:rowIndex] lowercaseString]]) {
			[prefs setObject:newName forKey:SPCustomQueryEditorThemeName];
		}

		// Reload everything needed
		if(editThemeListItems) [editThemeListItems release], editThemeListItems = nil;
		editThemeListItems = [[NSArray arrayWithArray:[self getAvailableThemes]] retain];
		[editThemeListTable reloadData];
		[self updateDisplayColorThemeName];
		[self updateColorSchemeSelectionMenu];
		
	}
}

#pragma mark -
#pragma mark TableView drag & drop delegate methods

// -------------------------------------------------------------------------------
// tableView:writeRowsWithIndexes:toPasteboard:
// -------------------------------------------------------------------------------
- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rows toPasteboard:(NSPasteboard*)pboard
{

	if(aTableView == colorSettingTableView) return;

	if ([rows count] == 1) {
		[pboard declareTypes:[NSArray arrayWithObject:SPFavoritesPasteboardDragType] owner:nil];
		[pboard setString:[[NSNumber numberWithInteger:[rows firstIndex]] stringValue] forType:SPFavoritesPasteboardDragType];
		
		return YES;
	} 
	else {
		return NO;
	}
}

// -------------------------------------------------------------------------------
// tableView:validateDrop:proposedRow:proposedDropOperation:
// -------------------------------------------------------------------------------
- (NSDragOperation)tableView:(NSTableView *)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{

	if(tv == colorSettingTableView) return NSDragOperationNone;

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

// -------------------------------------------------------------------------------
// tableView:acceptDrop:row:dropOperation:
// -------------------------------------------------------------------------------
- (BOOL)tableView:(NSTableView *)tv acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{

	if(tv == colorSettingTableView) return NO;

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

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if(aTableView == colorSettingTableView) {

			NSColorPanel* panel;

			colorRow = rowIndex;
			panel = [NSColorPanel sharedColorPanel];
			[panel setTarget:self];
			[panel setAction:@selector(colorChanged:)];
			[panel setColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:[editorColors objectAtIndex:colorRow]]]];
			[colorSettingTableView deselectAll:nil];
			[panel makeKeyAndOrderFront:self];

			return NO;

	}
	
	return YES;
}

// -------------------------------------------------------------------------------
// tableView:willDisplayCell:forTableColumn:row:
// -------------------------------------------------------------------------------
- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)index
{

	if(tableView == colorSettingTableView && [[tableColumn identifier] isEqualToString:@"name"]) {
		if ([cell isKindOfClass:[NSTextFieldCell class]]) {
			[cell setDrawsBackground:YES];
			NSFont *nf = [NSFont fontWithName:[[[NSFontPanel sharedFontPanel] panelConvertFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorFont]]] fontName] size:13.0f];
			[cell setFont:nf];
			switch(index) {
				case 1:
				[cell setTextColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorTextColor]]];
				[cell setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorBackgroundColor]]];
				break;
				case 9:
				[cell setTextColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorTextColor]]];
				[cell setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorHighlightQueryColor]]];
				break;
				case 10:
				[cell setTextColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorTextColor]]];
				[cell setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorSelectionColor]]];
				break;
				default:
				[cell setTextColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:[editorColors objectAtIndex:index]]]];
				[cell setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorBackgroundColor]]];
			}
		}
	} else {

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
}

// -------------------------------------------------------------------------------
// tableViewSelectionDidChange:
// -------------------------------------------------------------------------------
- (void)tableViewSelectionDidChange:(NSNotification *)notification
{

	if([notification object] == colorSettingTableView) return;

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
	NSString *keychainAccount = [keychain accountForUser:[currentFavorite objectForKey:@"user"] host:(([[currentFavorite objectForKey:@"type"] integerValue] == SPSocketConnection)?@"localhost":[currentFavorite objectForKey:@"host"]) database:[currentFavorite objectForKey:@"database"]];
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
    if ([itemIdentifier isEqualToString:SPPreferenceToolbarGeneral]) {
        return generalItem;
    }
	else if ([itemIdentifier isEqualToString:SPPreferenceToolbarTables]) {
		return tablesItem;
	}
	else if ([itemIdentifier isEqualToString:SPPreferenceToolbarFavorites]) {
		return favoritesItem;
	}
	else if ([itemIdentifier isEqualToString:SPPreferenceToolbarNotifications]) {
		return notificationsItem;
	}
	else if ([itemIdentifier isEqualToString:SPPreferenceToolbarAutoUpdate]) {
		return autoUpdateItem;
	}
	else if ([itemIdentifier isEqualToString:SPPreferenceToolbarNetwork]) {
		return networkItem;
	}
	else if ([itemIdentifier isEqualToString:SPPreferenceToolbarEditor]) {
		return editorItem;
	}
	else if ([itemIdentifier isEqualToString:SPPreferenceToolbarShortcuts]) {
		return shortcutItem;
	}
	
    return [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
}

// -------------------------------------------------------------------------------
// toolbarAllowedItemIdentifiers:
// -------------------------------------------------------------------------------
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:SPPreferenceToolbarGeneral, SPPreferenceToolbarTables, SPPreferenceToolbarFavorites, SPPreferenceToolbarNotifications, SPPreferenceToolbarEditor, SPPreferenceToolbarShortcuts, SPPreferenceToolbarAutoUpdate, SPPreferenceToolbarNetwork, nil];
}

// -------------------------------------------------------------------------------
// toolbarDefaultItemIdentifiers:
// -------------------------------------------------------------------------------
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:SPPreferenceToolbarGeneral, SPPreferenceToolbarTables, SPPreferenceToolbarFavorites, SPPreferenceToolbarNotifications, SPPreferenceToolbarEditor, SPPreferenceToolbarShortcuts, SPPreferenceToolbarAutoUpdate, SPPreferenceToolbarNetwork, nil];
}

// -------------------------------------------------------------------------------
// toolbarSelectableItemIdentifiers:
// -------------------------------------------------------------------------------
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:SPPreferenceToolbarGeneral, SPPreferenceToolbarTables, SPPreferenceToolbarFavorites, SPPreferenceToolbarNotifications, SPPreferenceToolbarEditor, SPPreferenceToolbarShortcuts, SPPreferenceToolbarAutoUpdate, SPPreferenceToolbarNetwork, nil];
}

#pragma mark -
#pragma mark SplitView delegate methods

// -------------------------------------------------------------------------------
// splitView:constrainMaxCoordinate:ofSubviewAt:
// -------------------------------------------------------------------------------
- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
	return (proposedMax - 220);
}

// -------------------------------------------------------------------------------
// splitView:constrainMinCoordinate:ofSubviewAt:
// -------------------------------------------------------------------------------
- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
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

	// Validate 'Save' button for entering a valid theme name
	if(field == enterNameInputField) {
		NSString *name = [[enterNameInputField stringValue] lowercaseString];

		if(![name length] || [name isEqualToString:@"default"] || [name isEqualToString:@"user-defined"]) {
			[themeNameSaveButton setEnabled:NO];
		} else {
			BOOL hide = YES;
			for(NSString* item in [self getAvailableThemes]) {
				if([[item lowercaseString] isEqualToString:name]) {
					hide = NO;
					break;
				}
			}
			[enterNameAlertField setHidden:hide];
			[themeNameSaveButton setEnabled:YES];
		}

		return;

	}
	
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

	[[NSColorPanel sharedColorPanel] close];

	// Mark the currently selected field in the window as having finished editing, to trigger saves.
	if ([preferencesWindow firstResponder])
		[preferencesWindow endEditingFor:[preferencesWindow firstResponder]];
}

// -------------------------------------------------------------------------------
// windowWillResize:toSize:
// Trap window resize notifications and use them to disable resizing on most tabs
// - except for the favourites tab.
// -------------------------------------------------------------------------------
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize
{

	[[NSColorPanel sharedColorPanel] close];

	if ([sender showsResizeIndicator])
		return frameSize;
	else
		return [sender frame].size;
}

#pragma mark -
#pragma mark Other

- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{

	// Order out current sheet to suppress overlapping of sheets
	if ([sheet respondsToSelector:@selector(orderOut:)])
		[sheet orderOut:nil];
	else if ([sheet respondsToSelector:@selector(window)])
		[[sheet window] orderOut:nil];

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
			
			[self updateDefaultFavoritePopup];
		}
	} else if([contextInfo isEqualToString:@"saveTheme"]) {
		if (returnCode == NSOKButton) {
			NSFileManager *fm = [NSFileManager defaultManager];
			if(![fm fileExistsAtPath:themePath isDirectory:nil]) {
				if(![fm createDirectoryAtPath:themePath withIntermediateDirectories:YES attributes:nil error:nil]) {
					NSBeep();
					return;
				}
			}
			[self saveColorThemeAtPath:[NSString stringWithFormat:@"%@/%@.%@", themePath, [enterNameInputField stringValue], SPColorThemeFileExtension]];
			[self updateColorSchemeSelectionMenu];
			[prefs setObject:[enterNameInputField stringValue] forKey:SPCustomQueryEditorThemeName];
			[self updateDisplayColorThemeName];
		}
	}
	
}

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

- (void)editThemeList
{
	[[NSColorPanel sharedColorPanel] close];

	if(editThemeListItems) [editThemeListItems release], editThemeListItems = nil;
	editThemeListItems = [[NSArray arrayWithArray:[self getAvailableThemes]] retain];
	[editThemeListTable reloadData];

	[NSApp beginSheet:editThemeListWindow
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];

}

- (NSArray *)getAvailableThemes
{
	// Read ~/Library/Application Support/Sequel Pro/Themes
	NSFileManager *fm = [NSFileManager defaultManager];
	if([fm fileExistsAtPath:themePath isDirectory:nil]) {
		NSArray *allItemsRaw = [fm contentsOfDirectoryAtPath:themePath error:NULL];
		if(!allItemsRaw) return [NSArray array];

		// Filter out all themes
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF ENDSWITH %@", [NSString stringWithFormat:@".%@", SPColorThemeFileExtension]];
		NSMutableArray *allItems = [NSMutableArray arrayWithArray:allItemsRaw];
		[allItems filterUsingPredicate:predicate];

		allItemsRaw = [NSArray arrayWithArray:allItems];
		[allItems removeAllObjects];

		// Remove file extension
		for(NSString* item in allItemsRaw)
			[allItems addObject:[item substringToIndex:[item length]-[SPColorThemeFileExtension length]-1]];

		return (NSArray *)allItems;
	}
	return [NSArray array];
}

- (void)updateColorSchemeSelectionMenu
{

	// Build theme selection submenu
	[themeSelectionMenu removeAllItems];
	[themeSelectionMenu setAutoenablesItems:YES];
	[themeSelectionMenu setShowsStateColumn:YES];
	[themeSelectionMenu addItemWithTitle:NSLocalizedString(@"Default", @"default color scheme label") action:@selector(setDefaultColors:) keyEquivalent:@""];
	[themeSelectionMenu addItem:[NSMenuItem separatorItem]];
	
	NSArray *foundThemes = [self getAvailableThemes];
	if([foundThemes count]) {
		for(NSString* item in foundThemes)
			[themeSelectionMenu addItemWithTitle:item action:@selector(loadColorScheme:) keyEquivalent:@""];
		[themeSelectionMenu addItem:[NSMenuItem separatorItem]];
	}
	[themeSelectionMenu addItemWithTitle:NSLocalizedString(@"Edit Theme List…", @"edit theme list label") action:@selector(editThemeList) keyEquivalent:@""];
	
}

- (void)updateDisplayColorThemeName
{

	if(![prefs objectForKey:SPCustomQueryEditorThemeName]) {
		[colorThemeName setHidden:YES];
		[colorThemeNameLabel setHidden:YES];
		return;
	}

	if([[[prefs objectForKey:SPCustomQueryEditorThemeName] lowercaseString] isEqualToString:@"user-defined"]) {
		[colorThemeName setHidden:YES];
		[colorThemeNameLabel setHidden:YES];
		return;
	}

	NSString *currentThemeName = [[prefs objectForKey:SPCustomQueryEditorThemeName] lowercaseString];
	if([currentThemeName isEqualToString:@"default"]) {
		[colorThemeName setHidden:NO];
		[colorThemeNameLabel setHidden:NO];
		return;
	}

	BOOL nameValid = NO;
	for(NSString* item in [self getAvailableThemes]) {
		if([[item lowercaseString] isEqualToString:currentThemeName]) {
			nameValid = YES;
			break;
		}
	}

	if(nameValid) {
		[colorThemeName setHidden:NO];
		[colorThemeNameLabel setHidden:NO];
		return;
	} else {
		[prefs setObject:@"User-defined" forKey:SPCustomQueryEditorThemeName];
		[colorThemeName setHidden:YES];
		[colorThemeNameLabel setHidden:YES];
		[self updateColorSchemeSelectionMenu];
		return;
	}

	[colorThemeName setHidden:NO];
	[colorThemeNameLabel setHidden:NO];

}
// -------------------------------------------------------------------------------
// updateDefaultFavoritePopup:
//
// Build the default favorite popup button
// -------------------------------------------------------------------------------
- (void)updateDefaultFavoritePopup
{
	[defaultFavoritePopup removeAllItems];
	
	// Use the last used favorite
	[defaultFavoritePopup addItemWithTitle:NSLocalizedString(@"Last Used", @"Last Used entry in favorites menu")];
	[[defaultFavoritePopup menu] addItem:[NSMenuItem separatorItem]];
	
	// Add all favorites to the menu
	for (NSString *favorite in [[favoritesController arrangedObjects] valueForKeyPath:@"name"])
	{
		NSMenuItem *favoriteMenuItem = [[NSMenuItem alloc] initWithTitle:favorite action:NULL keyEquivalent:@""];
		
		[[defaultFavoritePopup menu] addItem:favoriteMenuItem];
		
		[favoriteMenuItem release];
	}
	
	// Add item to switch to edit favorites pane
	[[defaultFavoritePopup menu] addItem:[NSMenuItem separatorItem]];
	
	NSMenuItem *editMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Edit Favorites…", @"edit favorites menu item") action:@selector(displayFavoritePreferences:) keyEquivalent:@""];
	
	[editMenuItem setTarget:self];
	
	[[defaultFavoritePopup menu] addItem:editMenuItem];
	
	[editMenuItem release];
	
	// Select the default favorite from prefs
	[defaultFavoritePopup selectItemAtIndex:(![prefs boolForKey:SPSelectLastFavoriteUsed]) ? ([prefs integerForKey:SPDefaultFavorite] + 2) : 0];
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
// global table font selection
// -------------------------------------------------------------------------------
// show the font panel
- (IBAction)showGlobalResultTableFontPanel:(id)sender
{
	fontChangeTarget = 1;
	[[NSFontPanel sharedFontPanel] setPanelFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPGlobalResultTableFont]] isMultiple:NO];
	[[NSFontPanel sharedFontPanel] makeKeyAndOrderFront:self];
}

// -------------------------------------------------------------------------------
// query editor font selection
// -------------------------------------------------------------------------------
// show the font panel
- (IBAction)showCustomQueryFontPanel:(id)sender
{
	fontChangeTarget = 2;
	[[NSFontPanel sharedFontPanel] setPanelFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorFont]] isMultiple:NO];
	[[NSFontPanel sharedFontPanel] makeKeyAndOrderFront:self];
}

// reset syntax highlighting colors
- (IBAction)setDefaultColors:(id)sender
{

	if(![self checkForUnsavedTheme]) return;

	[[NSColorPanel sharedColorPanel] close];
	[prefs setObject:@"Default" forKey:SPCustomQueryEditorThemeName];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.000 green:0.455 blue:0.000 alpha:1.000]] forKey:SPCustomQueryEditorCommentColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.769 green:0.102 blue:0.086 alpha:1.000]] forKey:SPCustomQueryEditorQuoteColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.200 green:0.250 blue:1.000 alpha:1.000]] forKey:SPCustomQueryEditorSQLKeywordColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.000 green:0.000 blue:0.658 alpha:1.000]] forKey:SPCustomQueryEditorBacktickColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.506 green:0.263 blue:0.000 alpha:1.000]] forKey:SPCustomQueryEditorNumericColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.500 green:0.500 blue:0.500 alpha:1.000]] forKey:SPCustomQueryEditorVariableColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.950 green:0.950 blue:0.950 alpha:1.000]] forKey:SPCustomQueryEditorHighlightQueryColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithDeviceRed:0.7098 green:0.8352 blue:1.000 alpha:1.000]] forKey:SPCustomQueryEditorSelectionColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor blackColor]] forKey:SPCustomQueryEditorTextColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor blackColor]] forKey:SPCustomQueryEditorCaretColor];
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor whiteColor]] forKey:SPCustomQueryEditorBackgroundColor];
	[colorSettingTableView reloadData];
	[self updateDisplayColorThemeName];
}

- (void)colorClick:(id)sender
{
	NSColorPanel* panel;

	colorRow = [sender clickedRow];
	panel = [NSColorPanel sharedColorPanel];
	[panel setTarget:self];
	[panel setAction:@selector(colorChanged:)];
	[panel setColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:[editorColors objectAtIndex:colorRow]]]];
	[colorSettingTableView deselectAll:nil];
	[panel makeKeyAndOrderFront:self];
}

- (void)colorChanged:(id)sender
{

	if(![[NSColorPanel sharedColorPanel] isVisible]) return;
	[prefs setObject:[NSArchiver archivedDataWithRootObject:[sender color]] forKey:[editorColors objectAtIndex:colorRow]];
	[colorSettingTableView reloadData];
	[prefs setObject:@"User-defined" forKey:SPCustomQueryEditorThemeName];
	[self updateDisplayColorThemeName];

}

// Set font panel's valid modes
- (NSUInteger)validModesForFontPanel:(NSFontPanel *)fontPanel
{
	return (NSFontPanelSizeModeMask|NSFontPanelCollectionModeMask);
}

// Action receiver for a font change in the font panel
- (void)changeFont:(id)sender
{
	NSFont *nf;
	
	switch(fontChangeTarget) 
	{
		case 1:
			nf = [[NSFontPanel sharedFontPanel] panelConvertFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPGlobalResultTableFont]]];
			[prefs setObject:[NSArchiver archivedDataWithRootObject:nf] forKey:SPGlobalResultTableFont];
			[globalResultTableFontName setStringValue:[NSString stringWithFormat:@"%@, %.1f pt", [nf displayName], [nf pointSize]]];
			break;
		case 2:
			nf = [[NSFontPanel sharedFontPanel] panelConvertFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorFont]]];
			[prefs setObject:[NSArchiver archivedDataWithRootObject:nf] forKey:SPCustomQueryEditorFont];
			[editorFontName setStringValue:[NSString stringWithFormat:@"%@, %.1f pt", [nf displayName], [nf pointSize]]];
			break;
	}
	[colorSettingTableView reloadData];
}

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
			[item setState:([[menuItem menu] indexOfItem:item] == currentSortItem) ? NSOnState : NSOffState];
		}
		
		// Check or uncheck the reverse sort item
		if (action == @selector(reverseFavoritesSortOrder:)) {
			[menuItem setState:reverseFavoritesSort];
		}
		
		return [[toolbar selectedItemIdentifier] isEqualToString:SPPreferenceToolbarFavorites];
	}
	
	return YES;
}

- (void)saveColorThemeAtPath:(NSString*)path
{
	// Build plist dictionary
	NSMutableDictionary *scheme = [NSMutableDictionary dictionary];
	NSMutableDictionary *mainsettings = [NSMutableDictionary dictionary];
	NSMutableArray *settings = [NSMutableArray array];

	CGFloat red, green, blue, alpha;
	NSInteger redInt, greenInt, blueInt, alphaInt;
	NSString *redHexValue, *greenHexValue, *blueHexValue, *alphaHexValue;

	[prefs synchronize];

	NSColor *aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorBackgroundColor]];
	[mainsettings setObject:[aColor rgbHexString] forKey:@"background"];

	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorCaretColor]];
	[mainsettings setObject:[aColor rgbHexString] forKey:@"caret"];

	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorTextColor]];
	[mainsettings setObject:[aColor rgbHexString] forKey:@"foreground"];

	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorHighlightQueryColor]];
	[mainsettings setObject:[aColor rgbHexString] forKey:@"lineHighlight"];

	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorSelectionColor]];
	[mainsettings setObject:[aColor rgbHexString] forKey:@"selection"];

	[settings addObject:[NSDictionary dictionaryWithObjectsAndKeys:mainsettings, @"settings", nil]];

	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorCommentColor]];
	[settings addObject:[NSDictionary dictionaryWithObjectsAndKeys:
	@"Comment", @"name",
		[NSDictionary dictionaryWithObjectsAndKeys:
	[aColor rgbHexString], @"foreground",
		nil
		], @"settings",
		nil
		]];

	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorQuoteColor]];
	[settings addObject:[NSDictionary dictionaryWithObjectsAndKeys:
	@"String", @"name",
		[NSDictionary dictionaryWithObjectsAndKeys:
	[aColor rgbHexString], @"foreground",
		nil
		], @"settings",
		nil
		]];

	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorSQLKeywordColor]];
	[settings addObject:[NSDictionary dictionaryWithObjectsAndKeys:
	@"Keyword", @"name",
		[NSDictionary dictionaryWithObjectsAndKeys:
	[aColor rgbHexString], @"foreground",
		nil
		], @"settings",
		nil
		]];

	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorBacktickColor]];
	[settings addObject:[NSDictionary dictionaryWithObjectsAndKeys:
	@"User-defined constant", @"name",
		[NSDictionary dictionaryWithObjectsAndKeys:
	[aColor rgbHexString], @"foreground",
		nil
		], @"settings",
		nil
		]];

	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorNumericColor]];
	[settings addObject:[NSDictionary dictionaryWithObjectsAndKeys:
	@"Number", @"name",
		[NSDictionary dictionaryWithObjectsAndKeys:
	[aColor rgbHexString], @"foreground",
		nil
		], @"settings",
		nil
		]];

	aColor = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorVariableColor]];
	[settings addObject:[NSDictionary dictionaryWithObjectsAndKeys:
	@"Variable", @"name",
		[NSDictionary dictionaryWithObjectsAndKeys:
	[aColor rgbHexString], @"foreground",
		nil
		], @"settings",
		nil
		]];

	[scheme setObject:settings forKey:@"settings"];

	NSString *err = nil;
	NSData *plist = [NSPropertyListSerialization dataFromPropertyList:scheme
		format:NSPropertyListXMLFormat_v1_0
		errorDescription:&err];

	if(err != nil) {
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while converting color scheme data", @"error while converting color scheme data")]
			defaultButton:NSLocalizedString(@"OK", @"OK button") 
			alternateButton:nil 
			otherButton:nil 
			informativeTextWithFormat:err];

		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
		return;
	}

	NSError *error = nil;
	[plist writeToFile:path options:NSAtomicWrite error:&error];
	if (error) [[NSAlert alertWithError:error] runModal];
}

- (void)checkForUnsavedThemeDidEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[[sheet window] orderOut:self];
	checkForUnsavedThemeSheetStatus = returnCode;
}


- (BOOL)checkForUnsavedTheme
{

	if(![prefs objectForKey:SPCustomQueryEditorThemeName] || [[[prefs objectForKey:SPCustomQueryEditorThemeName] lowercaseString] isEqualToString:@"user-defined"]) {

		[[NSColorPanel sharedColorPanel] close];

		checkForUnsavedThemeSheetStatus = -1;

		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert addButtonWithTitle:NSLocalizedString(@"Proceed", @"proceed button")];
		[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];
		[alert addButtonWithTitle:nil];
		[alert setMessageText:NSLocalizedString(@"Warning", @"warning")];
		[alert setInformativeText:NSLocalizedString(@"Current color theme is unsaved. Do you want to proceed without saving it?", @"Current color theme is unsaved. Do you want to proceed without saving it message")];
		[alert setAlertStyle:NSWarningAlertStyle];
		[alert setShowsHelp:NO];
		[alert setShowsSuppressionButton:NO];

		[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(checkForUnsavedThemeDidEndSheet:returnCode:contextInfo:) contextInfo:nil];

		// wait for the sheet
		NSModalSession session = [NSApp beginModalSessionForWindow:[alert window]];
		for (;;) {

			if(checkForUnsavedThemeSheetStatus != -1)
				break;

			// Execute code on DefaultRunLoop
			[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode 
									 beforeDate:[NSDate distantFuture]];

			// Break the run loop if sheet was closed
			if ([NSApp runModalSession:session] != NSRunContinuesResponse 
				|| ![[alert window] isVisible]) 
				break;

			// Execute code on DefaultRunLoop
			[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode 
									 beforeDate:[NSDate distantFuture]];

		}
		[NSApp endModalSession:session];
		[NSApp endSheet:[alert window]];

		if(checkForUnsavedThemeSheetStatus == NSAlertFirstButtonReturn) {
			return YES;
		}

		return NO;
	}
	[[NSColorPanel sharedColorPanel] close];
	return YES;
}

- (BOOL)loadColorSchemeFromFile:(NSString*)filename
{
	NSError *readError = nil;
	NSString *convError = nil;
	NSPropertyListFormat format;

	NSDictionary *theme = nil;

	NSData *pData = [NSData dataWithContentsOfFile:filename options:NSUncachedRead error:&readError];

	theme = [[NSPropertyListSerialization propertyListFromData:pData 
			mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError] retain];

	if(!theme || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while reading data file", @"error while reading data file")]
										 defaultButton:NSLocalizedString(@"OK", @"OK button") 
									   alternateButton:nil 
										  otherButton:nil 
							informativeTextWithFormat:NSLocalizedString(@"File couldn't be read.", @"error while reading data file")];

		[alert setAlertStyle:NSCriticalAlertStyle];
		[alert runModal];
		if (theme) [theme release];
		[self updateDisplayColorThemeName];
		return NO;
	}

	if([theme objectForKey:@"settings"] 
		&& [[theme objectForKey:@"settings"] isKindOfClass:[NSArray class]] 
		&& [[theme objectForKey:@"settings"] count] 
		&& [[[theme objectForKey:@"settings"] objectAtIndex:0] isKindOfClass:[NSDictionary class]]
		&& [[[theme objectForKey:@"settings"] objectAtIndex:0] objectForKey:@"settings"]) {

		NSInteger counter = 0;
		for(NSDictionary *dict in [theme objectForKey:@"settings"]) {
			if(counter == 0) {
				if([dict objectForKey:@"settings"]) {
					NSDictionary *dic = [dict objectForKey:@"settings"];
					if([dic objectForKey:@"background"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithRGBHexString:[dic objectForKey:@"background"]]] forKey:SPCustomQueryEditorBackgroundColor];
					if([dic objectForKey:@"caret"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithRGBHexString:[dic objectForKey:@"caret"]]] forKey:SPCustomQueryEditorCaretColor];
					if([dic objectForKey:@"foreground"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithRGBHexString:[dic objectForKey:@"foreground"]]] forKey:SPCustomQueryEditorTextColor];
					if([dic objectForKey:@"lineHighlight"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithRGBHexString:[dic objectForKey:@"lineHighlight"]]] forKey:SPCustomQueryEditorHighlightQueryColor];
					if([dic objectForKey:@"selection"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:[NSColor colorWithRGBHexString:[dic objectForKey:@"selection"]]] forKey:SPCustomQueryEditorSelectionColor];
				} else {
					continue;
				}
			} else {
				if([dict objectForKey:@"name"] && [dict objectForKey:@"settings"] && [[dict objectForKey:@"settings"] isKindOfClass:[NSDictionary class]] && [[dict objectForKey:@"settings"] objectForKey:@"foreground"]) {
					if([[dict objectForKey:@"name"] isEqualToString:@"Comment"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:
							[NSColor colorWithRGBHexString:[[dict objectForKey:@"settings"] objectForKey:@"foreground"]]] 
							forKey:SPCustomQueryEditorCommentColor];
					else if([[dict objectForKey:@"name"] isEqualToString:@"String"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:
							[NSColor colorWithRGBHexString:[[dict objectForKey:@"settings"] objectForKey:@"foreground"]]] 
							forKey:SPCustomQueryEditorQuoteColor];
					else if([[dict objectForKey:@"name"] isEqualToString:@"Keyword"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:
							[NSColor colorWithRGBHexString:[[dict objectForKey:@"settings"] objectForKey:@"foreground"]]] 
							forKey:SPCustomQueryEditorSQLKeywordColor];
					else if([[dict objectForKey:@"name"] isEqualToString:@"User-defined constant"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:
							[NSColor colorWithRGBHexString:[[dict objectForKey:@"settings"] objectForKey:@"foreground"]]] 
							forKey:SPCustomQueryEditorBacktickColor];
					else if([[dict objectForKey:@"name"] isEqualToString:@"Number"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:
							[NSColor colorWithRGBHexString:[[dict objectForKey:@"settings"] objectForKey:@"foreground"]]] 
							forKey:SPCustomQueryEditorNumericColor];
					else if([[dict objectForKey:@"name"] isEqualToString:@"Variable"])
						[prefs setObject:[NSArchiver archivedDataWithRootObject:
							[NSColor colorWithRGBHexString:[[dict objectForKey:@"settings"] objectForKey:@"foreground"]]] 
							forKey:SPCustomQueryEditorVariableColor];
				}
			}
			counter++;
		}

		[theme release];
		[colorSettingTableView reloadData];

	} else {

		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while reading data file", @"error while reading data file")]
										 defaultButton:NSLocalizedString(@"OK", @"OK button") 
									   alternateButton:nil 
										  otherButton:nil 
							informativeTextWithFormat:NSLocalizedString(@"No color theme data found.", @"error that no color theme found")];

		[alert setAlertStyle:NSInformationalAlertStyle];
		[alert runModal];
		[theme release];
		return NO;

	}
	return YES;
}

/**
 * Save panel did end method.
 */
- (void)panelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{

	if([contextInfo isEqualToString:@"exportColorScheme"]) {
		if (returnCode == NSOKButton) {
			[self saveColorThemeAtPath:[panel filename]];
		}
	}
	else if([contextInfo isEqualToString:@"importColorScheme"]) {
		if (returnCode == NSOKButton) {
			if([self loadColorSchemeFromFile:[[panel filenames] objectAtIndex:0]]) {
				[prefs setObject:@"User-defined" forKey:SPCustomQueryEditorThemeName];
				[self updateDisplayColorThemeName];
			}
		}
	}
}
#pragma mark -

/**
 * Dealloc.
 */
- (void)dealloc
{
	if(themePath) [themePath release], themePath = nil;
	if(editThemeListItems) [editThemeListItems release], editThemeListItems = nil;
	if(editorColors) [editorColors release], editorColors = nil;
	if(editorNameForColors) [editorNameForColors release], editorNameForColors = nil;
	if (keychain) [keychain release], keychain = nil;
	if (currentFavorite) [currentFavorite release];

	[super dealloc];
}

#pragma mark -
#pragma mark Private API

// -------------------------------------------------------------------------------
// _setupToolbar
//
// Constructs the preferences' window toolbar.
// -------------------------------------------------------------------------------
- (void)_setupToolbar
{
	toolbar = [[[NSToolbar alloc] initWithIdentifier:@"Preference Toolbar"] autorelease];

	// General preferences
	generalItem = [[NSToolbarItem alloc] initWithItemIdentifier:SPPreferenceToolbarGeneral];

	[generalItem setLabel:NSLocalizedString(@"General", @"")];
	[generalItem setImage:[NSImage imageNamed:@"toolbar-preferences-general"]];
	[generalItem setTarget:self];
	[generalItem setAction:@selector(displayGeneralPreferences:)];

	// Table preferences
	tablesItem = [[NSToolbarItem alloc] initWithItemIdentifier:SPPreferenceToolbarTables];

	[tablesItem setLabel:NSLocalizedString(@"Tables", @"")];
	[tablesItem setImage:[NSImage imageNamed:@"toolbar-preferences-tables"]];
	[tablesItem setTarget:self];
	[tablesItem setAction:@selector(displayTablePreferences:)];

	// Favorite preferences
	favoritesItem = [[NSToolbarItem alloc] initWithItemIdentifier:SPPreferenceToolbarFavorites];

	[favoritesItem setLabel:NSLocalizedString(@"Favorites", @"")];
	[favoritesItem setImage:[NSImage imageNamed:@"toolbar-preferences-favorites"]];
	[favoritesItem setTarget:self];
	[favoritesItem setAction:@selector(displayFavoritePreferences:)];

	// Notification preferences
	notificationsItem = [[NSToolbarItem alloc] initWithItemIdentifier:SPPreferenceToolbarNotifications];

	[notificationsItem setLabel:NSLocalizedString(@"Alerts & Logs", @"")];
	[notificationsItem setImage:[NSImage imageNamed:@"toolbar-preferences-notifications"]];
	[notificationsItem setTarget:self];
	[notificationsItem setAction:@selector(displayNotificationPreferences:)];

	// Editor preferences
	editorItem = [[NSToolbarItem alloc] initWithItemIdentifier:SPPreferenceToolbarEditor];
	
	[editorItem setLabel:NSLocalizedString(@"Query Editor", @"")];
	[editorItem setImage:[NSImage imageNamed:@"toolbar-preferences-queryeditor"]];
	[editorItem setTarget:self];
	[editorItem setAction:@selector(displayEditorPreferences:)];
	
	// Shortcut preferences
	/*shortcutItem = [[NSToolbarItem alloc] initWithItemIdentifier:SPPreferenceToolbarShortcuts];
	
	[shortcutItem setLabel:NSLocalizedString(@"Shortcuts", @"")];
	[shortcutItem setImage:[NSImage imageNamed:@"toolbar-preferences-shortcuts"]];
	[shortcutItem setTarget:self];
	[shortcutItem setAction:@selector(NSBeep)];*/
	
	// AutoUpdate preferences
	autoUpdateItem = [[NSToolbarItem alloc] initWithItemIdentifier:SPPreferenceToolbarAutoUpdate];

	[autoUpdateItem setLabel:NSLocalizedString(@"Auto Update", @"")];
	[autoUpdateItem setImage:[NSImage imageNamed:@"toolbar-preferences-autoupdate"]];
	[autoUpdateItem setTarget:self];
	[autoUpdateItem setAction:@selector(displayAutoUpdatePreferences:)];

	// Network preferences
	networkItem = [[NSToolbarItem alloc] initWithItemIdentifier:SPPreferenceToolbarNetwork];

	[networkItem setLabel:NSLocalizedString(@"Network", @"")];
	[networkItem setImage:[NSImage imageNamed:@"toolbar-preferences-network"]];
	[networkItem setTarget:self];
	[networkItem setAction:@selector(displayNetworkPreferences:)];

	[toolbar setDelegate:self];
	[toolbar setSelectedItemIdentifier:SPPreferenceToolbarGeneral];
	[toolbar setAllowsUserCustomization:NO];

	[preferencesWindow setToolbar:toolbar];
	[preferencesWindow setShowsToolbarButton:NO];

	[self displayGeneralPreferences:nil];
}

/**
 * Sorts the connection favorites based on the selected criteria.
 */
- (void)_sortFavorites
{		
	NSString *sortKey = @"";
	
	switch (currentSortItem)
	{
		case SPFavoritesSortNameItem:
			sortKey = @"name";
			break;
		case SPFavoritesSortHostItem:
			sortKey = @"host";
			break;
		case SPFavoritesSortTypeItem:
			sortKey = @"type";
			break;
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
	
	[self updateDefaultFavoritePopup];
}

/**
 * Resizes the window to the size of the supplied view.
 */
- (void)_resizeWindowForContentView:(NSView *)view
{
	// Remove all current views
	NSEnumerator *en = [[[preferencesWindow contentView] subviews] objectEnumerator];
	NSView *subview;
  
	while (subview = [en nextObject]) 
	{
		[subview removeFromSuperview];
	}
  
	// Resize window
	[preferencesWindow resizeForContentView:view titleBarVisible:YES];
  
	// Add view
	[[preferencesWindow contentView] addSubview:view];
	[view setFrameOrigin:NSMakePoint(0, 0)];
}

@end
