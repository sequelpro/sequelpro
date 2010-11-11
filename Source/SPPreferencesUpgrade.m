//
//  $Id$
//
//  SPPreferencesUpgrade.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 29, 2010
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

#import "SPPreferencesUpgrade.h"
#import "SPKeychain.h"

@implementation SPPreferencesUpgrade

/**
 * Checks the revision number, applies any preference upgrades, and updates to latest revision.
 * Currently uses both lastUsedVersion and LastUsedVersion for <0.9.5 compatibility.
 */
void SPApplyRevisionChanges(void)
{
	NSInteger i;
	NSInteger currentVersionNumber, recordedVersionNumber = 0;
	
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	
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
		
		while (databaseKey = [databaseEnumerator nextObject]) 
		{
			newDatabase = [[NSMutableDictionary alloc] init];
			tableEnumerator = [[[prefs objectForKey:SPTableColumnWidths] objectForKey:databaseKey] keyEnumerator];
			
			while (tableKey = [tableEnumerator nextObject]) 
			{
				newTable = [[NSMutableDictionary alloc] init];
				columnEnumerator = [[[[prefs objectForKey:SPTableColumnWidths] objectForKey:databaseKey] objectForKey:tableKey] keyEnumerator];
				
				while (columnKey = [columnEnumerator nextObject]) 
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
		
		while (newKey = [keyEnumerator nextObject]) 
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
	if (recordedVersionNumber < 567 && [prefs objectForKey:SPFavorites]) {
		NSMutableArray *favoritesArray = [NSMutableArray arrayWithArray:[prefs objectForKey:SPFavorites]];
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
		
		[prefs setObject:[NSArray arrayWithArray:favoritesArray] forKey:SPFavorites];
		[upgradeKeychain release];
		password = nil;
	}
	
	// For versions prior to r981 (~0.9.6), upgrade the favourites to include a connection type for each
	if (recordedVersionNumber < 981 && [prefs objectForKey:SPFavorites]) {
		NSMutableArray *favoritesArray = [NSMutableArray arrayWithArray:[prefs objectForKey:SPFavorites]];
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
				[favorite setObject:[NSNumber numberWithInteger:1] forKey:@"type"];
				
				// If SSH details are set, set to tunnel connection
			}
			else if ([favorite objectForKey:@"useSSH"] && [[favorite objectForKey:@"useSSH"] integerValue]) {
				[favorite setObject:[NSNumber numberWithInteger:2] forKey:@"type"];
				
				// Default to TCP/IP
			} 
			else {
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

/**
 * Attempts to migrate the user's connection favorites from their preference file to the new Favaorites
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
	
	// Only proceed if the new favorites plist doesn't already exist
	if (![fileManager fileExistsAtPath:favoritesFile]) {	
		
		NSDictionary *newFavorites = [NSDictionary dictionaryWithObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Favorites", @"favorites label"), SPFavoritesGroupNameKey, [prefs objectForKey:SPFavorites], SPFavoriteChildrenKey, nil] forKey:SPFavoritesRootKey];
		
		error = nil;
		NSString *errorString = nil;
		
		NSData *plistData = [NSPropertyListSerialization dataFromPropertyList:newFavorites
																	   format:NSPropertyListXMLFormat_v1_0
															 errorDescription:&errorString];
		if (plistData) {
			[plistData writeToFile:favoritesFile options:NSAtomicWrite error:&error];
			
			if (error) {
				NSLog(@"Error migrating favorites data: %@", [error localizedDescription]);
			}
			else {
				// Only uncomment when migration is complete
				//[prefs removeObjectForKey:SPFavorites];
			}
		}
		else if (errorString) {
			NSLog(@"Error converting migrating favorites data to plist format: %@", errorString);
			
			[errorString release];
			return;
		}
	}
}

@end
