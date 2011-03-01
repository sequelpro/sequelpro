//
//  $Id$
//
//  SPConnectionControllerDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 9, 2010
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

#import "SPConnectionControllerDelegate.h"
#import "SPTableTextFieldCell.h"
#import "SPFavoriteNode.h"

@implementation SPConnectionController (SPConnectionControllerDelegate)

/*#pragma mark -
 #pragma mark TableView drag & drop delegate methods
 
 - (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
 {
 NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
 [pboard declareTypes:[NSArray arrayWithObject:favoritesPBoardType] owner:self];
 [pboard setData:archivedData forType:favoritesPBoardType];
 return YES;
 }
 
 - (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
 {
 if (row == 0) return NSDragOperationNone;
 if ([info draggingSource] == aTableView)
 {
 [aTableView setDropRow:row dropOperation:NSTableViewDropAbove];
 return NSDragOperationMove;
 }
 return NSDragOperationNone;
 }
 
 - (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
 {
 BOOL acceptedDrop = NO;
 
 if ((row == 0) || ([info draggingSource] != aTableView))  return acceptedDrop;
 
 // Disable all automatic sorting
 currentSortItem = -1;
 reverseFavoritesSort = NO;
 
 [prefs setInteger:currentSortItem forKey:SPFavoritesSortedBy];
 [prefs setBool:NO forKey:SPFavoritesSortedInReverse];
 
 // Remove sort descriptors
 [favorites sortUsingDescriptors:[NSArray array]];
 
 // Uncheck sort by menu items
 for (NSMenuItem *menuItem in [[favoritesSortByMenuItem submenu] itemArray])
 {
 [menuItem setState:NSOffState];
 }
 
 NSPasteboard* pboard = [info draggingPasteboard];
 NSData* rowData = [pboard dataForType:favoritesPBoardType];
 NSIndexSet* rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
 NSInteger dragRow = [rowIndexes firstIndex];
 NSInteger defaultConnectionRow = [prefs integerForKey:SPLastFavoriteIndex];
 if (defaultConnectionRow == dragRow)
 {
 [prefs setInteger:row forKey:SPLastFavoriteIndex];
 }
 NSMutableDictionary *draggedFavorite = [favorites objectAtIndex:dragRow];
 [favorites removeObjectAtIndex:dragRow];
 if (row > dragRow)
 {
 row--;
 }
 [favorites insertObject:draggedFavorite atIndex:row];
 [aTableView reloadData];
 
 // reset the prefs with the new order
 NSMutableArray *reorderedFavorites = [[NSMutableArray alloc] initWithArray:favorites];
 [reorderedFavorites removeObjectAtIndex:0];
 [prefs setObject:reorderedFavorites forKey:SPFavorites];
 
 [[[[NSApp delegate] preferenceController] generalPreferencePane] updateDefaultFavoritePopup];
 
 [reorderedFavorites release];
 
 [self updateFavorites];
 [aTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
 
 acceptedDrop = YES;
 
 return acceptedDrop;
 }*/

#pragma mark -
#pragma mark SplitView delegate methods

- (NSRect)splitView:(NSSplitView *)splitView additionalEffectiveRectOfDividerAtIndex:(NSInteger)dividerIndex
{
	return [connectionSplitViewButtonBar splitView:splitView additionalEffectiveRectOfDividerAtIndex:dividerIndex];
}

/**
 * When the split view is resized, trigger a resize in the hidden table
 * width as well, to keep the connection view and connected view in synch.
 */
- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
	[databaseConnectionView setPosition:[[[connectionSplitView subviews] objectAtIndex:0] frame].size.width ofDividerAtIndex:0];
}

#pragma mark -
#pragma mark Outline view datasource methods

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{	
	SPFavoriteNode *node = (item == nil ? favoritesRoot : (SPFavoriteNode *)item);
	
	return [[node nodeChildren] count];
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	SPFavoriteNode *node = (item == nil ? favoritesRoot : (SPFavoriteNode *)item);
	
	return NSArrayObjectAtIndex([node nodeChildren], index);
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{	
	return [(SPFavoriteNode *)item nodeIsGroup];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	SPFavoriteNode *node = (SPFavoriteNode *)item;
	
	return ([node nodeIsGroup]) ? [node nodeName] : [[node nodeFavorite] objectForKey:SPFavoriteNameKey];
}

#pragma mark -
#pragma mark Outline view delegate methods

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
	return [(SPFavoriteNode *)item nodeIsGroup];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	if ([favoritesTable numberOfSelectedRows] == 1) {
		[self updateFavoriteSelection:self];
		
		[addToFavoritesButton setEnabled:NO];
	} 
	else {
		[addToFavoritesButton setEnabled:YES];
	}
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	[(SPTableTextFieldCell *)cell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	
	if ([favoritesTable isEnabled]) {
		[(SPTableTextFieldCell *)cell setTextColor:[NSColor blackColor]];
	}
	else {
		[(SPTableTextFieldCell *)cell setTextColor:[NSColor grayColor]];
	}
	
	[(SPTableTextFieldCell *)cell setImage:([(SPFavoriteNode *)item nodeIsGroup]) ? nil : [NSImage imageNamed:@"database-small"]];
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	return ([item nodeIsGroup]) ? 22 : 17;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	return (![item nodeIsGroup]);
}


/**
 * Double-Click opens the connection.
 */
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if (!isConnecting) [self initiateConnection:self];
	return NO;
}
@end
