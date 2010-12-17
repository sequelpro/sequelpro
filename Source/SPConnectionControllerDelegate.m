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
#import "SPGroupNode.h"

#define CELL(cell) (SPTableTextFieldCell *)cell

@implementation SPConnectionController (SPConnectionControllerDelegate)

#pragma mark -
#pragma mark SplitView delegate methods

/**
 * When the split view is resized, trigger a resize in the hidden table
 * width as well, to keep the connection view and connected view in synch.
 * Use this rather than splitViewDidResizeSubviews: as the latter is not
 * forwarded by the BWAnchoredButtonBar.
 */
- (CGFloat)splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)dividerIndex
{
	[databaseConnectionView setPosition:[[[connectionSplitView subviews] objectAtIndex:0] frame].size.width ofDividerAtIndex:0];
	
	return proposedPosition;
}

/**
 * Return the maximum possible size of the splitview.
 */
- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
	return (proposedMax - 445);
}

/**
 * Return the minimum possible size of the splitview.
 */
- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
	return (proposedMin + 80);
}

#pragma mark -
#pragma mark Outline view datasource methods

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

#pragma mark -
#pragma mark Outline view delegate methods

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{	
	return ([[(SPTreeNode *)item parentNode] parentNode] == nil);
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{			
	NSInteger selected = [favoritesOutlineView numberOfSelectedRows];
	
	if (selected == 1) {

		SPTreeNode *node = [self selectedFavoriteNode];
		
		if (![node isGroup]) {
			[self updateFavoriteSelection:self];
			
			[addToFavoritesButton setEnabled:NO];
			
			favoriteNameFieldWasTouched = YES;
			
			[connectionResizeContainer setHidden:NO];
			[connectionInstructionsTextField setStringValue:NSLocalizedString(@"Enter connection details below, or choose a favorite", @"enter connection details label")];
		}
		else {
			[connectionResizeContainer setHidden:YES];
			[connectionInstructionsTextField setStringValue:NSLocalizedString(@"Please choose a favorite", @"please choose a favorite connection view label")];
		}
	}
	else if (selected > 1) {
		[connectionResizeContainer setHidden:YES];
		[connectionInstructionsTextField setStringValue:NSLocalizedString(@"Please choose a favorite", @"please choose a favorite connection view label")];		
	}
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	SPTreeNode *node = (SPTreeNode *)item;
	
	[CELL(cell) setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	
	[CELL(cell) setTextColor:([favoritesOutlineView isEnabled]) ? [NSColor blackColor] : [NSColor grayColor]];
	
	if (![[node parentNode] parentNode]) {
		[CELL(cell) setImage:nil];
	}
	else {
		[CELL(cell) setImage:(![node isGroup]) ? [NSImage imageNamed:@"database-small"] : folderImage];
	}	
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	return ((SPTreeNode *)[[item parentNode] parentNode] == nil) ? 22 : 17;
}

- (NSString *)outlineView:(NSOutlineView *)outlineView toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn item:(id)item mouseLocation:(NSPoint)mouseLocation
{
	SPTreeNode *node = (SPTreeNode *)item;
	
	if (![node isGroup]) {
		return [[[node representedObject] nodeFavorite] objectForKey:SPFavoriteNameKey];
	}
	else {
		NSUInteger favCount = [[node childNodes] count];
		
		return [NSString stringWithFormat:@"%@ - %d %@", [[node representedObject] nodeName], favCount, (favCount == 1) ? NSLocalizedString(@"favorite", @"favorite singular label") : NSLocalizedString(@"favorites", @"favorites plural label")];
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{	
	return ([[item parentNode] parentNode] != nil);
}

#pragma mark -
#pragma mark Outline view drag & drop

/*- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{	
	[pboard declareTypes:[NSArray arrayWithObject:SPFavoritesPasteboardDragType] owner:self];
	[pboard setData:[NSData data] forType:SPFavoritesPasteboardDragType];
	
	return YES;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index
{
	NSDragOperation result = NSDragOperationNone;
	
	if ([info draggingSource] == outlineView) {
		[outlineView setDropItem:item dropChildIndex:index];
		
		result = NSDragOperationMove;
	}
	
	return result;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index
{
	BOOL acceptedDrop = NO;
	
	if ((!item) || ([info draggingSource] != outlineView)) return acceptedDrop;
	
	SPTreeNode *node = (item) ? item : [[[[favoritesRoot childNodes] objectAtIndex:0] childNodes] objectAtIndex:0];
 		
	// TODO: Fix me
	
	// Disable all automatic sorting
	//currentSortItem = -1;
	//reverseFavoritesSort = NO;
	
	//[prefs setInteger:currentSortItem forKey:SPFavoritesSortedBy];
	//[prefs setBool:NO forKey:SPFavoritesSortedInReverse];
	
	// Remove sort descriptors
	//[favorites sortUsingDescriptors:[NSArray array]];
	
	// Uncheck sort by menu items
	for (NSMenuItem *menuItem in [[favoritesSortByMenuItem submenu] itemArray])
	{
		[menuItem setState:NSOffState];
	}
	
	NSArray *nodes = [self selectedFavoriteNodes];
		
	if ([node isGroup]) {		
		if (index == NSOutlineViewDropOnItemIndex) {
			index = 0;
		}
		else {
			SPTreeNode *oldNode = node;
			
			node = [node parentNode];
			index = ([[node childNodes] indexOfObject:oldNode] + 1);
		}
	}
	else {
		if (index == NSOutlineViewDropOnItemIndex) {
			index = 0;
		}
	}
		
	NSMutableArray *childNodeArray = [node mutableChildNodes];
	
    for (SPTreeNode *treeNode in nodes) 
	{
        // Remove the node from its old location
        NSInteger oldIndex = [childNodeArray indexOfObject:treeNode];
        NSInteger newIndex = index;
        
		if (oldIndex != NSNotFound) {
			
            [childNodeArray removeObjectAtIndex:oldIndex];
            
			if (index > oldIndex) {
                newIndex--;
            }
        } 
		else {
            [[[treeNode parentNode] mutableChildNodes] removeObject:treeNode];
        }
		        
		[childNodeArray insertObject:treeNode atIndex:newIndex];
        
		newIndex++;
    }
	
	[favoritesController saveFavorites];
	
	[self _reloadFavoritesViewData];
	
	[[[[NSApp delegate] preferenceController] generalPreferencePane] updateDefaultFavoritePopup];
	
	acceptedDrop = YES;
	
	return acceptedDrop;
}*/

#pragma mark -
#pragma mark Textfield delegate methods

/**
 * Trap and control the 'name' field of the selected favorite. If the user pressed
 * 'Add Favorite' the 'name' field is set to 'New Favorite'. If the user did not
 * change the 'name' field or delete that field it will be set to user@host automatically.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	id field = [notification object];
				
	if ([self selectedFavoriteNode]) {
		
		BOOL nameFieldIsEmpty = [[field stringValue] isEqualToString:@""];
		
		switch (previousType) 
		{
			case SPTCPIPConnection:
				
				nameFieldIsEmpty = (nameFieldIsEmpty || [[standardNameField stringValue] isEqualToString:@""]);
				
				if (nameFieldIsEmpty || (!favoriteNameFieldWasTouched && (field == standardUserField || field == standardSQLHostField))) {
					[standardNameField setStringValue:[NSString stringWithFormat:@"%@@%@", [standardUserField stringValue], [standardSQLHostField stringValue]]];
					
					// Trigger KVO update
					[self setName:[standardNameField stringValue]];
					
					// If name field is empty enable user@host update
					if (nameFieldIsEmpty) favoriteNameFieldWasTouched = NO;
				}
				
				break;
			case SPSocketConnection:
				
				nameFieldIsEmpty = (nameFieldIsEmpty || [[socketNameField stringValue] isEqualToString:@""]);
				
				if (nameFieldIsEmpty || (!favoriteNameFieldWasTouched && field == socketUserField)) {
					[socketNameField setStringValue:[NSString stringWithFormat:@"%@@localhost", [socketUserField stringValue]]];
					
					// Trigger KVO update
					[self setName:[socketNameField stringValue]];
					
					// If name field is empty enable user@host update
					if (nameFieldIsEmpty) favoriteNameFieldWasTouched = NO;
				}
				
				break;
			case SPSSHTunnelConnection:
				
				nameFieldIsEmpty = (nameFieldIsEmpty || [[sshNameField stringValue] isEqualToString:@""]);
				
				if (nameFieldIsEmpty || (!favoriteNameFieldWasTouched && (field == sshUserField || field == sshSQLHostField))) {
					[sshNameField setStringValue:[NSString stringWithFormat:@"%@@%@", [sshUserField stringValue], [sshSQLHostField stringValue]]];
					
					// Trigger KVO update
					[self setName:[sshNameField stringValue]];
					
					// If name field is empty enable user@host update
					if (nameFieldIsEmpty) favoriteNameFieldWasTouched = NO;
				}
				
				break;
			default:
				break;
		}
		
		if ((field == standardNameField) || (field == socketNameField) || (field == sshNameField)) favoriteNameFieldWasTouched = YES;
	}
}

/**
 * When a host field finishes editing, ensure that it hasn't been set to "localhost"
 * to ensure that socket connections don't inadvertently occur.
 */
- (void)controlTextDidEndEditing:(NSNotification *)notification
{
	if ([notification object] == standardSQLHostField || [notification object] == sshSQLHostField) {
		[self _checkHost];
	}
}

/**
 * Trap editing end notifications and use them to update the keychain password
 * appropriately when name, host, user, password or database changes.
 */
- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
	// Request a password refresh to keep keychain references in synch with favorites, but only if a favorite
	// is selected, meaning we're editing an existing one, not a new one.
	if ((control != favoritesOutlineView) && ([self selectedFavoriteNode])) {
		[self _updateFavoritePasswordsFromField:control];
	}
	
	// Proceed with editing
	return YES;
}

#pragma mark -
#pragma mark Tab bar delegate methods

/**
 * Trigger a resize action whenever the tab view changes. The connection
 * detail forms are held within container views, which are of a fixed width;
 * the tabview and buttons are contained within a resizable view which
 * is set to dimensions based on the container views, allowing the view
 * to be sized according to the detail type.
 */
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	NSInteger selectedTabView = [tabView indexOfTabViewItem:tabViewItem];
		
	// Deselect any selected favorite for manual changes
	if (!automaticFavoriteSelection) [favoritesOutlineView deselectAll:self];
	automaticFavoriteSelection = NO;
	
	if (selectedTabView == previousType) return;
	
	[self resizeTabViewToConnectionType:selectedTabView animating:YES];
	
	// Update the host as appropriate
	if ((selectedTabView != SPSocketConnection) && [[self host] isEqualToString:@"localhost"]) {
		[self setHost:@""];
	}
	
	previousType = selectedTabView;
	
	// Enable the add to favorites button
	[addToFavoritesButton setEnabled:YES];
	
	[self _favoriteTypeDidChange];
}

#pragma mark -
#pragma mark Scroll view notifications

/**
 * As the scrollview resizes, keep the details centered within it if
 * the detail frame is larger than the scrollview size; otherwise, pin
 * the detail frame to the top of the scrollview.
 */
- (void)scrollViewFrameChanged:(NSNotification *)aNotification
{
	NSRect scrollViewFrame = [connectionDetailsScrollView frame];
	NSRect scrollDocumentFrame = [[connectionDetailsScrollView documentView] frame];
	NSRect connectionDetailsFrame = [connectionResizeContainer frame];
	
	// Scroll view is smaller than contents - keep positioned at top.
	if (scrollViewFrame.size.height < connectionDetailsFrame.size.height + 10) {
		if (connectionDetailsFrame.origin.y != 0) {
			connectionDetailsFrame.origin.y = 0;
			[connectionResizeContainer setFrame:connectionDetailsFrame];
			scrollDocumentFrame.size.height = connectionDetailsFrame.size.height + 10;
			[[connectionDetailsScrollView documentView] setFrame:scrollDocumentFrame];
		}
	}
	// Otherwise, center
	else {
		connectionDetailsFrame.origin.y = (scrollViewFrame.size.height - connectionDetailsFrame.size.height)/3;
		[connectionResizeContainer setFrame:connectionDetailsFrame];
		scrollDocumentFrame.size.height = scrollViewFrame.size.height;
		[[connectionDetailsScrollView documentView] setFrame:scrollDocumentFrame];
	}
}

#pragma mark -
#pragma mark Menu Validation

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    SEL action = [menuItem action];
	
	SPTreeNode *node = [self selectedFavoriteNode];
	
    if ((action == @selector(sortFavorites:)) || (action == @selector(reverseSortFavorites:))) {
		
		// TODO: Fix me
		return NO;
		
		// Loop all the items in the sort by menu only checking the currently selected one
		for (NSMenuItem *item in [[menuItem menu] itemArray])
		{
			[item setState:([[menuItem menu] indexOfItem:item] == currentSortItem) ? NSOnState : NSOffState];
		}
		
		// Check or uncheck the reverse sort item
		if (action == @selector(reverseSortFavorites:)) {
			[menuItem setState:reverseFavoritesSort];
		}
    }
	
	// Remove the selected favorite
	if (action == @selector(removeNode:)) {
		return ([favoritesOutlineView numberOfSelectedRows] == 1);
	}
	
	// Duplicate and make the selected favorite the default
	if (action == @selector(duplicateFavorite:)) {
		return (([favoritesOutlineView numberOfSelectedRows] == 1) && (![node isGroup]));
	}
	
	// Make selected favorite the default
	if (action == @selector(makeSelectedFavoriteDefault:)) {
		NSInteger favoriteID = [[[self selectedFavorite] objectForKey:SPFavoriteIDKey] integerValue];
				
		return (([favoritesOutlineView numberOfSelectedRows] == 1) && (![node isGroup]) && (favoriteID != [prefs integerForKey:SPDefaultFavorite]));
	}
	
	// Rename selected favorite/group
	if (action == @selector(renameFavorite:)) {
		return ([favoritesOutlineView numberOfSelectedRows] == 1);
	}
	
	// Favorites export
	if (action == @selector(exportFavorites:)) {
		
		NSInteger rows = [favoritesOutlineView numberOfSelectedRows];
		
		if (rows > 1) {
			[menuItem setTitle:NSLocalizedString(@"Export Selected...", @"export selected favorites menu item")];
		}
		else if (rows == 1) {
			return (![[self selectedFavoriteNode] isGroup]);
		}
		
		return YES;
	}
		
    return YES;
}

@end
