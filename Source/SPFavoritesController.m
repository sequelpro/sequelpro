//
//  $Id$
//
//  SPFavoritesController.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 10, 2010
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

#import "SPFavoritesController.h"

static SPFavoritesController *sharedFavoritesController = nil;

@interface SPFavoritesController (PrivateAPI)

- (void)_loadFavorites;

@end

@implementation SPFavoritesController

@synthesize favorites;

#pragma mark -
#pragma mark Initialisation

+ (id)allocWithZone:(NSZone *)zone
{    
    @synchronized(self) {
		return [[self sharedFavoritesController] retain]; 
    }    
}

- (id)init
{
    if ((self = [super init])) {
		
		favorites = nil;
		
        [self _loadFavorites];
    }
    
    return self;
}

#pragma mark -
#pragma mark Public API

/**
 * Returns the shared favorites controller.
 */
+ (SPFavoritesController *)sharedFavoritesController
{
    @synchronized(self) {
        if (sharedFavoritesController == nil) {
            sharedFavoritesController = [[super allocWithZone:NULL] init];
        }
    }
    
    return sharedFavoritesController;
}

/**
 * Saves the current favorites dictionary in memory to disk. Note that the current favorites data file is moved
 * rather than overwritten in the event that we can't write the new file, the original can simply be restored.
 * This method also does a lot of error checking to ensure we don't lose the user's favorites data.
 */
- (void)saveFavorites
{
	NSError *error = nil;
	NSString *errorString = nil;
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	NSString *dataPath = [fileManager applicationSupportDirectoryForSubDirectory:SPDataSupportFolder error:&error];
	
	if (error) {
		NSLog(@"Error retrieving data directory path: %@", [error localizedDescription]);
		return;
	}
	
	NSString *favoritesFile = [dataPath stringByAppendingPathComponent:SPFavoritesDataFile];
	NSString *favoritesBackupFile = [dataPath stringByAppendingPathComponent:[@"~" stringByAppendingString:SPFavoritesDataFile]];
	
	// If the favorites data file already exists, attempt to move it to keep as a backup
	if ([fileManager fileExistsAtPath:favoritesFile]) {
		[fileManager moveItemAtPath:favoritesFile toPath:favoritesBackupFile error:&error];
	}
	
	if (error) {
		NSLog(@"Unable to backup (move) existing favorites data file during save. Deleting instead: %@", [error localizedDescription]);
		
		error = nil;
		
		// We can't move it so try and delete it
		if (![fileManager removeItemAtPath:favoritesFile error:&error] && error) {
			NSLog(@"Unable to delete existing favorites data file during save. Something is wrong, permissions perhaps: %@", [error localizedDescription]);
			return;
		}
	}
	else {
		NSData *plistData = [NSPropertyListSerialization dataFromPropertyList:favorites
																	   format:NSPropertyListXMLFormat_v1_0
															 errorDescription:&errorString];
		
		if (plistData) {
			[plistData writeToFile:favoritesFile options:NSAtomicWrite error:&error];
			
			if (error) {
				NSLog(@"Error writing favorites data. Restoring backup if available: %@", [error localizedDescription]);
				
				// Restore the original data file
				[fileManager moveItemAtPath:favoritesBackupFile toPath:favoritesFile error:NULL];
			}
			else {
				// Remove the original backup
				[fileManager removeItemAtPath:favoritesBackupFile error:NULL];
			}
		}
		else if (errorString) {
			NSLog(@"Error converting favorites data to plist format: %@", errorString);
			
			[errorString release];
		}
	}
}

/**
 * Reloads the favorites data from disk with the option to save before doing so.
 *
 * @param save Indicates whether the current favorites data in memory should be saved to disk before being
 *             reloaded. Specifying NO effectively discards any changes since the last save operation.
 */
- (void)reloadFavoritesWithSave:(BOOL)save
{
	if (save) [self saveFavorites];
	
	if (favorites) [self _loadFavorites];
}

#pragma mark -
#pragma mark Private API

/**
 * Attempts to load the users connection favorites from ~/Library/Application Support/Sequel Pro/Data/Favorites.plist
 * If the 'Data' directory doesn't already exist it will be created, as well as an empty favorites plist.
 */
- (void)_loadFavorites
{
	NSError *error = nil;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if (favorites) [favorites release], favorites = nil;
	
	NSString *dataPath = [fileManager applicationSupportDirectoryForSubDirectory:SPDataSupportFolder error:&error];
	
	if (error) {
		NSLog(@"Error retrieving data directory path: %@", [error localizedDescription]);
		return;
	}
	
	NSString *favoritesFile = [dataPath stringByAppendingPathComponent:SPFavoritesDataFile];
	
	// If the favorites data file already exists use it, otherwise create an empty one
	if ([fileManager fileExistsAtPath:favoritesFile]) {
		favorites = [[NSDictionary alloc] initWithContentsOfFile:favoritesFile];
	}
	else {
		NSDictionary *newFavorites = [NSDictionary dictionaryWithObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Favorites", @"favorites label"), SPFavoritesGroupNameKey, [NSArray array], SPFavoriteChildrenKey, nil] forKey:SPFavoritesRootKey];
		
		NSError *error = nil;
		NSString *errorString = nil;
		
		NSData *plistData = [NSPropertyListSerialization dataFromPropertyList:newFavorites
																	   format:NSPropertyListXMLFormat_v1_0
															 errorDescription:&errorString];
		if (plistData) {
			[plistData writeToFile:favoritesFile options:NSAtomicWrite error:&error];
			
			if (error) {
				NSLog(@"Error writing default favorites data: %@", [error localizedDescription]);
			}
		}
		else if (errorString) {
			NSLog(@"Error converting default favorites data to plist format: %@", errorString);
			
			[errorString release];
			return;
		}
		
		favorites = newFavorites;
	}
}

#pragma mark -

/**
 * Dealloc.
 */
- (void)dealloc
{
	if (favorites) [favorites release], favorites = nil;
	
	[super dealloc];
}

@end
