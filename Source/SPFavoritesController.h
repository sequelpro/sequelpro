//
//  SPFavoritesController.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 10, 2010.
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

#import "SPSingleton.h"

@class SPTreeNode;

/**
 * @class SPFavoritesController SPFavoritesController.h
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * Connection favorites controller that provides a single point of access for managing the user's connection
 * favorites in memory and on disk.
 */
@interface SPFavoritesController : SPSingleton 
{
	SPTreeNode *favoritesTree;
	NSMutableDictionary *favoritesData;
	
	pthread_mutex_t writeLock;
	pthread_mutex_t favoritesLock;
}

/**
 * @property favoritesTree The current favorites tree
 */
@property (readonly) SPTreeNode *favoritesTree;

/**
 * @property favoritesData Favorites data dictionary
 */
@property (readonly) NSMutableDictionary *favoritesData;

+ (SPFavoritesController *)sharedFavoritesController;

- (void)saveFavorites;
- (void)saveFavoritesSynchronously;
- (void)reloadFavoritesWithSave:(BOOL)save;

- (SPTreeNode *)addGroupNodeWithName:(NSString *)name asChildOfNode:(SPTreeNode *)parent;
- (SPTreeNode *)addFavoriteNodeWithData:(NSMutableDictionary *)data asChildOfNode:(SPTreeNode *)parent;

- (void)removeFavoriteNode:(SPTreeNode *)node;

@end
