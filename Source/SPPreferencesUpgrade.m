//
//  SPPreferencesUpgrade.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 29, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPPreferencesUpgrade.h"
#import "SPKeychain.h"
#import "SPFavoritesController.h"
#import "SPTreeNode.h"
#import "SPFavoriteNode.h"

static NSString *SPOldFavoritesKey       = @"favorites";
static NSString *SPOldDefaultEncodingKey = @"DefaultEncoding";

@implementation SPPreferencesUpgrade

/**
 * Checks the revision number, applies any preference upgrades, and updates to latest revision.
 * Currently uses both lastUsedVersion and LastUsedVersion for <0.9.5 compatibility.
 */
void SPApplyRevisionChanges(void)
{
	NSUInteger i;
	NSUInteger currentVersionNumber, recordedVersionNumber = 0;
	NSMutableArray *importantUpdateNotes = [NSMutableArray new];
	
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	// If this is the first run, check for a preferences with the old bundle identifier and
	// migrate them before running any preference upgrade routines
	if ([prefs boolForKey:SPFirstRun]) {
		SPMigratePreferencesFromPreviousIdentifer();
		[prefs setBool:NO forKey:SPFirstRun];
	}

	// Get the current bundle version number (the SVN build number) for per-version upgrades
	currentVersionNumber = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] integerValue];
	
	// Get the current revision
	if ([prefs objectForKey:@"lastUsedVersion"]) recordedVersionNumber = [[prefs objectForKey:@"lastUsedVersion"] integerValue];
	if ([prefs objectForKey:SPLastUsedVersion]) recordedVersionNumber = [[prefs objectForKey:SPLastUsedVersion] integerValue];

	// Skip processing if the current version matches or is less than recorded version
	if (currentVersionNumber <= recordedVersionNumber) {
		[importantUpdateNotes release];
		return;
	}
	
	// If no recorded version, update to current revision and skip processing
	if (!recordedVersionNumber) {
		[prefs setObject:[NSNumber numberWithInteger:currentVersionNumber] forKey:SPLastUsedVersion];
		[importantUpdateNotes release];
		return;
	}

	// Inform SPAppController to check installed default Bundles for available updates
	[prefs setObject:@YES forKey:@"doBundleUpdate"];

	// For versions prior to r336 (0.9.4), where column widths have been saved, walk through them and remove
	// any table widths set to 15 or less (fix for mangled columns caused by Issue #140)
	if (recordedVersionNumber < 336 && [prefs objectForKey:SPTableColumnWidths] != nil) {
		NSEnumerator *databaseEnumerator, *tableEnumerator, *columnEnumerator;
		NSString *databaseKey, *tableKey, *columnKey;
		NSMutableDictionary *newDatabase, *newTable;
		double columnWidth;
		NSMutableDictionary *newTableColumnWidths = [[NSMutableDictionary alloc] init];
		
		databaseEnumerator = [[prefs objectForKey:SPTableColumnWidths] keyEnumerator];
		
		while ((databaseKey = [databaseEnumerator nextObject])) 
		{
			newDatabase = [[NSMutableDictionary alloc] init];
			tableEnumerator = [[[prefs objectForKey:SPTableColumnWidths] objectForKey:databaseKey] keyEnumerator];
			
			while ((tableKey = [tableEnumerator nextObject])) 
			{
				newTable = [[NSMutableDictionary alloc] init];
				columnEnumerator = [[[[prefs objectForKey:SPTableColumnWidths] objectForKey:databaseKey] objectForKey:tableKey] keyEnumerator];
				
				while ((columnKey = [columnEnumerator nextObject])) 
				{
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
		NSDictionary *keysToUpgrade = @{
				SPDefaultEncoding         : @"encoding",
				SPUseMonospacedFonts      : @"useMonospacedFonts",
				SPReloadAfterAddingRow    : @"reloadAfterAdding",
				SPReloadAfterEditingRow   : @"reloadAfterEditing",
				SPReloadAfterRemovingRow  : @"reloadAfterRemoving",
				SPLoadBlobsAsNeeded       : @"dontShowBlob",
				@"FetchCorrectRowCount"   : @"fetchRowCount",
				SPLimitResults            : @"limitRows",
				SPLimitResultsValue       : @"limitRowsValue",
				SPNullValue               : @"nullValue",
				SPShowNoAffectedRowsError : @"showError",
				SPConnectionTimeoutValue  : @"connectionTimeout",
				SPKeepAliveInterval       : @"keepAliveInterval",
				SPLastFavoriteID          : @"lastFavoriteIndex"
		};
		
		keyEnumerator = [keysToUpgrade keyEnumerator];
		
		while ((newKey = [keyEnumerator nextObject])) 
		{
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
	if (recordedVersionNumber < 567 && [prefs objectForKey:SPOldFavoritesKey]) {
		NSMutableArray *favoritesArray = [NSMutableArray arrayWithArray:[prefs objectForKey:SPOldFavoritesKey]];
		NSMutableDictionary *favorite;
		NSString *password, *keychainName, *keychainAccount;
		SPKeychain *upgradeKeychain = [[SPKeychain alloc] init];
		
		// Cycle through the favorites, generating a timestamp-derived ID for each and renaming associated keychain items.
		for (i = 0; i < [favoritesArray count]; i++) 
		{
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
		
		[prefs setObject:[NSArray arrayWithArray:favoritesArray] forKey:SPOldFavoritesKey];
		[upgradeKeychain release];
		password = nil;
	}
	
	// For versions prior to r981 (~0.9.6), upgrade the favourites to include a connection type for each
	if (recordedVersionNumber < 981 && [prefs objectForKey:SPOldFavoritesKey]) {
		NSMutableArray *favoritesArray = [NSMutableArray arrayWithArray:[prefs objectForKey:SPOldFavoritesKey]];
		NSMutableDictionary *favorite;
		
		// Cycle through the favorites
		for (i = 0; i < [favoritesArray count]; i++) 
		{
			favorite = [NSMutableDictionary dictionaryWithDictionary:[favoritesArray objectAtIndex:i]];
			
			if ([favorite objectForKey:@"type"]) continue;
			
			// If the favorite has a socket, or has the host set to "localhost", set to socket-type connection
			if ([[favorite objectForKey:@"host"] isEqualToString:@"localhost"]
				|| ([favorite objectForKey:@"socket"] && [(NSString *)[favorite objectForKey:@"socket"] length]))
			{
				[favorite setObject:@1 forKey:@"type"];
				
				// If SSH details are set, set to tunnel connection
			}
			else if ([favorite objectForKey:@"useSSH"] && [[favorite objectForKey:@"useSSH"] integerValue]) {
				[favorite setObject:@2 forKey:@"type"];
				
				// Default to TCP/IP
			} 
			else {
				[favorite setObject:@0 forKey:@"type"];
			}
			
			// Remove SSH tunnel flag - no longer required
			[favorite removeObjectForKey:@"useSSH"];
			
			[favoritesArray replaceObjectAtIndex:i withObject:[NSDictionary dictionaryWithDictionary:favorite]];
		}
		
		[prefs setObject:[NSArray arrayWithArray:favoritesArray] forKey:SPOldFavoritesKey];
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
				[queryFavoritesArray replaceObjectAtIndex:i withObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithString:favoriteName], [favorite objectForKey:@"query"], nil] forKeys:@[@"name", @"query"]]];
				continue;
			}
			
			// By default make the query's name the first 32 characters of the query with '...' appended, stripping newlines
			NSMutableString *favoriteName = [NSMutableString stringWithString:[favorite stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]]];
			[favoriteName replaceOccurrencesOfString:@"\n" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, [favoriteName length])];
			
			if ([favoriteName length] > 32) {
				[favoriteName deleteCharactersInRange:NSMakeRange(32, [favoriteName length] - 32)];
				[favoriteName appendString:@"..."];
			}
			
			[queryFavoritesArray replaceObjectAtIndex:i withObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithString:favoriteName], favorite, nil] forKeys:@[@"name", @"query"]]];
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
	if  (recordedVersionNumber < 2325 && [prefs objectForKey:SPOldDefaultEncodingKey] && [[prefs objectForKey:SPOldDefaultEncodingKey] isKindOfClass:[NSString class]]) {
		NSDictionary *encodingMap = @{
				@"Autodetect"                      : @(SPEncodingAutodetect),
				@"UCS-2 Unicode (ucs2)"            : @(SPEncodingUCS2),
				@"UTF-8 Unicode (utf8)"            : @(SPEncodingUTF8),
				@"UTF-8 Unicode via Latin 1"       : @(SPEncodingUTF8viaLatin1),
				@"US ASCII (ascii)"                : @(SPEncodingASCII),
				@"ISO Latin 1 (latin1)"            : @(SPEncodingLatin1),
				@"Mac Roman (macroman)"            : @(SPEncodingMacRoman),
				@"Windows Latin 2 (cp1250)"        : @(SPEncodingCP1250Latin2),
				@"ISO Latin 2 (latin2)"            : @(SPEncodingISOLatin2),
				@"Windows Arabic (cp1256)"         : @(SPEncodingCP1256Arabic),
				@"ISO Greek (greek)"               : @(SPEncodingGreek),
				@"ISO Hebrew (hebrew)"             : @(SPEncodingHebrew),
				@"ISO Turkish (latin5)"            : @(SPEncodingLatin5Turkish),
				@"Windows Baltic (cp1257)"         : @(SPEncodingCP1257WinBaltic),
				@"Windows Cyrillic (cp1251)"       : @(SPEncodingCP1251WinCyrillic),
				@"Big5 Traditional Chinese (big5)" : @(SPEncodingBig5Chinese),
				@"Shift-JIS Japanese (sjis)"       : @(SPEncodingShiftJISJapanese),
				@"EUC-JP Japanese (ujis)"          : @(SPEncodingEUCJPJapanese),
				@"EUC-KR Korean (euckr)"           : @(SPEncodingEUCKRKorean)
		};
		
		NSNumber *newMappedValue = [encodingMap valueForKey:[prefs objectForKey:SPOldDefaultEncodingKey]];
		
		if (newMappedValue == nil) newMappedValue = @0;
		
		[prefs setObject:newMappedValue forKey:@"DefaultEncodingTag"];
	}

	// For versions prior to 3922 (<1.0), show notes for swapping the custom query buttons and signing changes
	if (recordedVersionNumber < 3922) {
		[importantUpdateNotes addObject:NSLocalizedString(@"The Custom Query \"Run\" and \"Run All\" button positions and their shortcuts have been swapped.", @"Short important release note for swap of custom query buttons")];
		[importantUpdateNotes addObject:NSLocalizedString(@"We've changed Sequel Pro's digital signature for GateKeeper compatibility; you'll have to allow access to your passwords again.", @"Short important release note for why password prompts may occur")];
	}

	// For versions prior to 4011 (~1.0), migrate the favourites across if appropriate.  This will only
	// occur once - if the target file already exists, it won't be re-created
	if (recordedVersionNumber < 4011) {
		SPMigrateConnectionFavoritesData();
	}

	// For versions prior to 4011 (~1.0), move the old plist to the trash
	if (recordedVersionNumber < 4011) {
		NSString *oldPrefPath = @"~/Library/Preferences/com.google.code.sequel-pro.plist";
		oldPrefPath = [oldPrefPath stringByExpandingTildeInPath];
		if ([[NSFileManager defaultManager] fileExistsAtPath:oldPrefPath]) {
			FSRef plistFSRef;
			if (FSPathMakeRef((const UInt8 *)[oldPrefPath fileSystemRepresentation], &plistFSRef, NULL) == noErr) {
				FSMoveObjectToTrashSync(&plistFSRef, NULL, 0);
			}
		}
	}

	// For versions prior to r4049 (~1.0.2), delete the old favourites entry in the plist now it's been migrated
	if (recordedVersionNumber < 4049) {
		[prefs removeObjectForKey:SPOldFavoritesKey];
	}
	
	// For versions prior to r4485, add a default colorIndex to fix sorting favorites by color
	if (recordedVersionNumber < 4485) {
		SPFavoritesController *ctrl = [SPFavoritesController sharedFavoritesController];
		NSMutableArray *favs = [(SPTreeNode *)[[[ctrl favoritesTree] childNodes] objectAtIndex:0] descendants];
		for(SPTreeNode *node in favs) {
			if([node isGroup])
				continue;
			NSMutableDictionary *data = [(SPFavoriteNode *)[node representedObject] nodeFavorite];
			if(![data objectForKey:SPFavoriteColorIndexKey])
				[data setObject:@(-1) forKey:SPFavoriteColorIndexKey];
		}
		[ctrl saveFavorites];
	}

	// Display any important release notes, if any.  Call this after a slight delay to prevent double help
	// menus - see http://www.cocoabuilder.com/archive/cocoa/6200-two-help-menus-why.html .
	[SPPreferencesUpgrade performSelector:@selector(showPostMigrationReleaseNotes:) withObject:importantUpdateNotes afterDelay:0.1];
	[importantUpdateNotes release];

	// Update the prefs revision
	[prefs setObject:[NSNumber numberWithInteger:currentVersionNumber] forKey:SPLastUsedVersion];
}

/**
 * Attempts to migrate the user's connection favorites from their preference file to the new favorites
 * plist in the application's support 'Data' directory.
 */
void SPMigrateConnectionFavoritesData(void)
{	
	NSError *error = nil;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	NSString *dataPath = [fileManager applicationSupportDirectoryForSubDirectory:SPDataSupportFolder error:&error];
	if (error) {
		NSLog(@"Error loading favorites: %@", [error localizedDescription]);
		return;
	}

	NSString *favoritesFile = [dataPath stringByAppendingPathComponent:SPFavoritesDataFile];

	// If the favourites file already exists, don't proceed
	if ([fileManager fileExistsAtPath:favoritesFile]) return;

	NSMutableArray *favorites = [[NSMutableArray alloc] initWithArray:[prefs objectForKey:SPOldFavoritesKey]];

	// Change the last used favorite and default favorite's indexes to be ID based
	if (![prefs objectForKey:SPLastFavoriteID] && [favorites count]) {
		
		NSInteger lastFavoriteIndex    = [prefs integerForKey:@"LastFavoriteIndex"];
		NSInteger defaultFavoriteIndex = [prefs integerForKey:SPDefaultFavorite];
		
		if ((lastFavoriteIndex >= (NSInteger)0) && ((NSUInteger)lastFavoriteIndex < [favorites count])) {
			[prefs setInteger:[[[favorites objectAtIndex:lastFavoriteIndex] objectForKey:SPFavoriteIDKey] integerValue] forKey:SPLastFavoriteID];
		}
		
		if ((defaultFavoriteIndex >= (NSInteger)0) && ((NSUInteger)defaultFavoriteIndex < [favorites count])) {
			[prefs setInteger:[[[favorites objectAtIndex:defaultFavoriteIndex] objectForKey:SPFavoriteIDKey] integerValue] forKey:SPDefaultFavorite];
		}
		
		[prefs removeObjectForKey:@"LastFavoriteIndex"];
	}

	NSDictionary *newFavorites = @{SPFavoritesRootKey : [NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Favorites", @"favorites label"), SPFavoritesGroupNameKey, favorites, SPFavoriteChildrenKey, nil]};
	
	error = nil;
	
	NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:newFavorites
																   format:NSPropertyListXMLFormat_v1_0
																  options:0
																	error:&error];

	if (error) {
		NSLog(@"Error converting migrating favorites data to plist format: %@", error);
	}
	else if (plistData) {
		[plistData writeToFile:favoritesFile options:NSAtomicWrite error:&error];
		
		if (error) {
			NSLog(@"Error migrating favorites data: %@", error);
		}
		else {
			[prefs removeObjectForKey:SPOldFavoritesKey];
		}
	}

	[favorites release];
}

/**
 * Migrates across all preferences for an old bundle identifier to the current preferences file.
 */
void SPMigratePreferencesFromPreviousIdentifer(void)
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	CFStringRef oldIdentifier = CFSTR("com.google.code.sequel-pro");
	CFArrayRef oldPrefKeys = CFPreferencesCopyKeyList(oldIdentifier, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
	
	if (!oldPrefKeys) return;

	NSDictionary *oldPrefs = (NSDictionary *)CFPreferencesCopyMultiple(oldPrefKeys, oldIdentifier, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);

	for (id eachKey in oldPrefs) 
	{
		[prefs setObject:[oldPrefs objectForKey:eachKey] forKey:eachKey];
	}

	[oldPrefs release];
	
	if (oldPrefKeys) {
		CFRelease(oldPrefKeys);
	}
}

/**
 * Displays important release notes for a new revision.
 */
+ (void)showPostMigrationReleaseNotes:(NSArray *)releaseNotes
{
	if (![releaseNotes count]) return;

	NSString *introText;
	
	if ([releaseNotes count] == 1) {
		introText = NSLocalizedString(@"We've made a few changes but we thought you should know about one particularly important one:", "Important release notes informational text, single change");	
	} 
	else {
		introText = NSLocalizedString(@"We've made a few changes but we thought you should know about some particularly important ones:", "Important release notes informational text, multiple changes");
	}

	// Create a *modal* alert to show the release notes
	NSAlert *noteAlert = [[NSAlert alloc] init];
	
	[noteAlert setAlertStyle:NSInformationalAlertStyle];
	[noteAlert setAccessoryView:[[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 450, 1)] autorelease]];
	[noteAlert setMessageText:NSLocalizedString(@"Thanks for updating Sequel Pro!", @"Release notes dialog title thanking user for upgrade")];
	[noteAlert addButtonWithTitle:NSLocalizedString(@"Continue", @"Continue button title")];
	[noteAlert addButtonWithTitle:NSLocalizedString(@"View full release notes", @"Release notes button title")];
	[noteAlert setInformativeText:[NSString stringWithFormat:@"%@\n\n • %@", introText, [releaseNotes componentsJoinedByString:@"\n\n • "]]];

	// Show the dialog
	NSInteger returnCode = [noteAlert runModal];
	[noteAlert release];

	// Show releae notes if desired
	if (returnCode == NSAlertSecondButtonReturn) {

		// Work out whether to link to the normal site or the nightly list
		NSString *releaseNotesLink = @"http://www.sequelpro.com/release-notes";
		if ([[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"] rangeOfString:@"nightly"].location != NSNotFound) {
			releaseNotesLink = @"http://nightly.sequelpro.com/release-notes";
		}

		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:releaseNotesLink]];
	}
}

@end
