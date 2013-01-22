//
//  $Id$
//
//  SPConnectionControllerDataSource.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on February 20, 2011.
//  Copyright (c) 2011 Stuart Connolly. All rights reserved.
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
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPConnectionControllerDataSource.h"
#import "SPFavoritesController.h"
#import "SPFavoriteNode.h"
#import "SPGroupNode.h"
#import "SPTreeNode.h"

@interface SPConnectionController ()

- (void)_reloadFavoritesViewData;
- (void)_saveCurrentDetailsCreatingNewFavorite:(BOOL)createNewFavorite validateDetails:(BOOL)validateDetails;

@end

@implementation SPConnectionController (SPConnectionControllerDataSource)

#ifndef SP_REFACTOR

/**
 * Return the number of children for the specified item in the favourites tree.
 * Note that to support the "Quick Connect" entry, the returned count is amended
 * for the top level.
 */
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{	
	SPTreeNode *node = (item == nil ? favoritesRoot : (SPTreeNode *)item);

	// If at the root, return the count plus one for the "Quick Connect" entry
	if (!item) {
		return [[node childNodes] count] + 1;
	}

	return [[node childNodes] count];
}

/**
 * Return the branch at the specified index of a supplied tree level.
 * Note that to support the "Quick Connect" entry, children of the top level
 * have their offsets amended.
 */
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)childIndex ofItem:(id)item
{
	// For the top level of the tree, return the "Quick Connect" child for position zero;
	// amend all other positions to compensate for the faked position.
	if (!item) {
		if (childIndex == 0) {
			return quickConnectItem;
		}
		
		childIndex--;
	}

	SPTreeNode *node = (item == nil ? favoritesRoot : (SPTreeNode *)item);
	
	return NSArrayObjectAtIndex([node childNodes], childIndex);
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{	
	return [(SPTreeNode *)item isGroup];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	SPTreeNode *node = (SPTreeNode *)item;

	return (![node isGroup]) ? [[[node representedObject] nodeFavorite] objectForKey:SPFavoriteNameKey] : [[node representedObject] nodeName];
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	NSString *newName = [object stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	if ([newName length]) {
		
		// Get the node that was renamed
		SPTreeNode *node = [self selectedFavoriteNode];
		
		if (![node isGroup]) {			

			// Updating the name triggers a KVO update 
			[self setName:newName];		
			[self _saveCurrentDetailsCreatingNewFavorite:NO validateDetails:NO];
		}
		else {
			[[node representedObject] setNodeName:newName];
			
			[favoritesController saveFavorites];
			
			[self _reloadFavoritesViewData];
		}
	}
}

#endif

@end
