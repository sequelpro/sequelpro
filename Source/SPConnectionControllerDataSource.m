//
//  $Id$
//
//  SPConnectionControllerDataSource.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on February 20, 2011
//  Copyright (c) 2011 Stuart Connolly. All rights reserved.
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

#import "SPConnectionControllerDataSource.h"
#import "SPFavoritesController.h"
#import "SPFavoriteNode.h"
#import "SPGroupNode.h"
#import "SPTreeNode.h"

@interface SPConnectionController (PrivateAPI)

- (void)_reloadFavoritesViewData;
- (void)_updateFavoritePasswordsFromField:(NSControl *)control;

@end

@implementation SPConnectionController (SPConnectionControllerDataSource)

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{	
	SPTreeNode *node = (item == nil ? favoritesRoot : (SPTreeNode *)item);
	
	return [[node childNodes] count];
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	SPTreeNode *node = (item == nil ? favoritesRoot : (SPTreeNode *)item);
	
	return NSArrayObjectAtIndex([node childNodes], index);
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
	// Trim whitespace
	NSString *newName = [object stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	if ([newName length]) {
		
		// Get the node that was renamed
		SPTreeNode *node = [self selectedFavoriteNode];
		
		if (![node isGroup]) {			
			// Updating the name triggers a KVO update 
			[self setName:newName];
			
			// Update associated Keychain items
			[self _updateFavoritePasswordsFromField:nil];
		}
		else {
			[[node representedObject] setNodeName:newName];
			
			[favoritesController saveFavorites];
			
			[self _reloadFavoritesViewData];
		}
	}
}

- (id)outlineView:(NSOutlineView *)outlineView itemForPersistentObject:(id)object
{
	return [NSKeyedUnarchiver unarchiveObjectWithData:object];
}

- (id)outlineView:(NSOutlineView *)outlineView persistentObjectForItem:(id)item
{
	return [NSKeyedArchiver archivedDataWithRootObject:item];
}

@end
