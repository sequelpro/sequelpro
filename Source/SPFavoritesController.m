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
#import "SPFavoriteNode.h"
#import "SPGroupNode.h"
#import "pthread.h"

static SPFavoritesController *sharedFavoritesController = nil;

@interface SPFavoritesController (PrivateAPI)

- (void)_loadFavorites;
- (void)_constructFavoritesTree;
- (void)_saveFavoritesDataInBackground:(NSDictionary *)data;
- (void)_addNode:(SPTreeNode *)node asChildOfNode:(SPTreeNode *)parent;

- (SPTreeNode *)_constructBranchForNodeData:(NSDictionary *)nodeData;

@end

@implementation SPFavoritesController

@synthesize favoritesTree;
@synthesize favoritesData;

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
		
		favoritesTree = nil;
		favoritesData = nil;
		
		pthread_mutex_init(&writeLock, NULL);
		pthread_mutex_init(&favoritesLock, NULL);
		
        [self _loadFavorites];
		[self _constructFavoritesTree];
    }
    
    return self;
}

#pragma mark -

/**
 * Returns the shared favorites controller.
 *
 * @return The shared controller instance.
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

#pragma mark -
#pragma mark Favorites data handling

/**
 * Saves the current favorites dictionary in memory to disk. Note that the current favorites data file is moved
 * rather than overwritten in the event that we can't write the new file, the original can simply be restored.
 * This method also does a lot of error checking to ensure we don't lose the user's favorites data.
 */
- (void)saveFavorites
{
	pthread_mutex_lock(&favoritesLock);
	
	[NSThread detachNewThreadSelector:@selector(_saveFavoritesDataInBackground:) toTarget:self withObject:[[[favoritesTree childNodes] objectAtIndex:0] dictionaryRepresentation]];
	
	pthread_mutex_unlock(&favoritesLock);
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
	
	if (favoritesData) {
		[self _loadFavorites];
		[self _constructFavoritesTree];
	}
}

#pragma mark -
#pragma mark Favorites interaction

/**
 * Adds a new group node with the supplied name to the children of the supplied parent node.
 *
 * @param name   The name of the new group
 * @param parent 
 *
 * @return The node instance that was created and added
 */
- (SPTreeNode *)addGroupNodeWithName:(NSString *)name asChildOfNode:(SPTreeNode *)parent
{	
	SPTreeNode *node = [SPTreeNode treeNodeWithRepresentedObject:[SPGroupNode groupNodeWithName:name]];
		
	[node setIsGroup:YES];
	
	[self _addNode:node asChildOfNode:parent];
	
	return [node autorelease];
}

/**
 * Adds a new favorite node with the supplied data to the children of the supplied parent node.
 *
 * @param data   The data for the new favorite
 * @param 
 *
 * @return The node instance that was created and added
 */
- (SPTreeNode *)addFavoriteNodeWithData:(NSDictionary *)data asChildOfNode:(SPTreeNode *)parent
{
	SPTreeNode *node = [SPTreeNode treeNodeWithRepresentedObject:[SPFavoriteNode favoriteNodeWithDictionary:data]];
		
	[self _addNode:node asChildOfNode:parent];
	
	return [node autorelease];
}

/**
 * Removes the supplied favorite node by asking the root node to remove it from it's children (i.e. the
 * entire tree is searched.
 *
 * @param The node to be removed
 */
- (void)removeFavoriteNode:(SPTreeNode *)node
{	
	[favoritesTree removeObjectFromChildren:node];
	
	// Save data to disk
	[self reloadFavoritesWithSave:YES];
}

#pragma mark -
#pragma mark Private API

/**
 * Attempts to load the users connection favorites from ~/Library/Application Support/Sequel Pro/Data/Favorites.plist
 * If the 'Data' directory doesn't already exist it will be created, as well as an empty favorites plist.
 */
- (void)_loadFavorites
{
	pthread_mutex_lock(&favoritesLock);
	
	NSError *error = nil;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if (favoritesData) [favoritesData release], favoritesData = nil;
	
	NSString *dataPath = [fileManager applicationSupportDirectoryForSubDirectory:SPDataSupportFolder error:&error];
	
	if (error) {
		NSLog(@"Error retrieving data directory path: %@", [error localizedDescription]);
		
		pthread_mutex_unlock(&favoritesLock);
		
		return;
	}
	
	NSString *favoritesFile = [dataPath stringByAppendingPathComponent:SPFavoritesDataFile];
	
	// If the favorites data file already exists use it, otherwise create an empty one
	if ([fileManager fileExistsAtPath:favoritesFile]) {
		favoritesData = [[NSDictionary alloc] initWithContentsOfFile:favoritesFile];
	}
	else {
		NSDictionary *newFavorites = [NSMutableDictionary dictionaryWithObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Favorites", @"favorites label"), SPFavoritesGroupNameKey, [NSArray array], SPFavoriteChildrenKey, nil] forKey:SPFavoritesRootKey];
		
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
			
			pthread_mutex_unlock(&favoritesLock);
			
			return;
		}
		
		favoritesData = newFavorites;
	}
	
	pthread_mutex_unlock(&favoritesLock);
}

/**
 * Constructs the favorites tree by initialising an instance of SPFavoriteNode for every favorite and group.
 */
- (void)_constructFavoritesTree
{
	pthread_mutex_lock(&favoritesLock);
	
	if (!favoritesData) {
		pthread_mutex_unlock(&favoritesLock);
		return;
	}
		
	NSDictionary *root = [favoritesData objectForKey:SPFavoritesRootKey];
	
	SPGroupNode *rootGroupNode = [[SPGroupNode alloc] init];
	SPGroupNode *favoritesGroupNode = [[SPGroupNode alloc] initWithName:[[root objectForKey:SPFavoritesGroupNameKey] uppercaseString]];
	
	SPTreeNode *rootNode = [[SPTreeNode alloc] initWithRepresentedObject:rootGroupNode];
	SPTreeNode *favoritesNode = [[SPTreeNode alloc] initWithRepresentedObject:favoritesGroupNode];
		
	[rootNode setIsGroup:YES];
	[favoritesNode setIsGroup:YES];
	
	for (NSDictionary *favorite in [root objectForKey:SPFavoriteChildrenKey])
	{
		SPTreeNode *node = [self _constructBranchForNodeData:favorite];
				
		[[favoritesNode mutableChildNodes] addObject:node];
		
		[node release];
	}
	
	[[rootNode mutableChildNodes] addObject:favoritesNode];
	
	[rootGroupNode release];
	[favoritesGroupNode release];
	[favoritesNode release];
	
	favoritesTree = rootNode;
	
	pthread_mutex_unlock(&favoritesLock);
}

/**
 * Constructs the tree branch for the supplied favorites data. Note that depending on the contents of the 
 * branch (i.e. does it contain any groups and their depth) this method will recursively call itself.
 *
 * @param nodeData The favorites data dictionary
 *
 * @return The root node of the branch
 */
- (SPTreeNode *)_constructBranchForNodeData:(NSDictionary *)nodeData
{
	id node = nil;
	SPTreeNode *treeNode = nil;
	
	if ([nodeData objectForKey:SPFavoritesGroupNameKey] && [nodeData objectForKey:SPFavoriteChildrenKey]) {
		
		node = [[SPGroupNode alloc] initWithName:[nodeData objectForKey:SPFavoritesGroupNameKey]];
		
		treeNode = [[SPTreeNode alloc] initWithRepresentedObject:node];
		
		[treeNode setIsGroup:YES];
				
		for (NSDictionary *favorite in [nodeData objectForKey:SPFavoriteChildrenKey])
		{
			SPTreeNode *innerNode = [self _constructBranchForNodeData:favorite];
			
			[innerNode setIsGroup:YES];
			
			[[treeNode mutableChildNodes] addObject:innerNode];
			
			[innerNode release];
		}
	}
	else {
		node = [[SPFavoriteNode alloc] initWithDictionary:nodeData];
		
		treeNode = [[SPTreeNode alloc] initWithRepresentedObject:node];
	}
	
	return treeNode;
}

/**
 * Saves the supplied favorites data to disk on a background thread.
 *
 * @param data The raw plist data (serialized NSDictionary) to be saved 
 */
- (void)_saveFavoritesDataInBackground:(NSDictionary *)data
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	pthread_mutex_lock(&writeLock);
	
	if (!favoritesTree) {
		pthread_mutex_unlock(&writeLock);
		return;
	}
	
	NSError *error = nil;
	NSString *errorString = nil;
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	NSString *dataPath = [fileManager applicationSupportDirectoryForSubDirectory:SPDataSupportFolder error:&error];
	
	if (error) {
		NSLog(@"Error retrieving data directory path: %@", [error localizedDescription]);
		
		pthread_mutex_unlock(&writeLock);
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
			
			pthread_mutex_unlock(&writeLock);
			return;
		}
	}
	else {
		NSDictionary *dictionary = [NSDictionary dictionaryWithObject:data forKey:SPFavoritesRootKey];
		
		// Convert the current favorites tree to a dictionary representation to create the plist data
		NSData *plistData = [NSPropertyListSerialization dataFromPropertyList:dictionary
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
			
			[fileManager removeItemAtPath:favoritesBackupFile error:NULL];
		}
	}
	
	pthread_mutex_unlock(&writeLock);
	
	[pool release];
}

/**
 * Adds the supplied node to the children of the supplied parent and saves the tree to disk.
 *
 * @param node    The node to be added
 * @param asChild 
 */
- (void)_addNode:(SPTreeNode *)node asChildOfNode:(SPTreeNode *)parent
{
	if (parent) {
		[[parent mutableChildNodes] addObject:node];
	}
	else {
		[[[[favoritesTree mutableChildNodes] objectAtIndex:0] mutableChildNodes] addObject:node];
	}
	
	[self saveFavorites];
}

#pragma mark -

/**
 * Dealloc.
 */
- (void)dealloc
{
	if (favoritesTree) [favoritesTree release], favoritesTree = nil;
	if (favoritesData) [favoritesData release], favoritesData = nil;
	
	pthread_mutex_destroy(&writeLock);
	pthread_mutex_destroy(&favoritesLock);
	
	[super dealloc];
}

@end
