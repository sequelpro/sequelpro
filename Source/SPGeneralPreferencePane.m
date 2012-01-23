//
//  $Id$
//
//  SPGeneralPreferencePane.m
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

#import "SPGeneralPreferencePane.h"
#import "SPFavoritesController.h"
#import "SPTreeNode.h"
#import "SPFavoriteNode.h"
#import "SPGroupNode.h"

static NSString *SPDatabaseImage = @"database-small";

@interface SPGeneralPreferencePane ()

- (NSArray *)_constructMenuItemsForNode:(SPTreeNode *)node atLevel:(NSUInteger)level;

@end

@implementation SPGeneralPreferencePane

#pragma mark -
#pragma mark Initialisation

- (void)awakeFromNib
{
	// Generic folder image for use in the outline view's groups
	folderImage = [[[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericFolderIcon)] retain];
	
	[folderImage setSize:NSMakeSize(16, 16)];
}

#pragma mark -
#pragma mark IB action methods

/**
 * Updates the default favorite.
 */ 
- (IBAction)updateDefaultFavorite:(id)sender
{		
	for (NSMenuItem *item in [defaultFavoritePopup itemArray])
	{
		[item setState:NSOffState];
	}
	
	[sender setState:NSOnState];
	[defaultFavoritePopup setTitle:[sender title]];
	
	[prefs setBool:([defaultFavoritePopup indexOfSelectedItem] == 0) forKey:SPSelectLastFavoriteUsed];
			
	[prefs setInteger:[sender tag] forKey:SPDefaultFavorite];
}

#pragma mark -
#pragma mark Public API

/**
 * (Re)builds the default favorite popup button.
 */
- (void)updateDefaultFavoritePopup
{
	[defaultFavoritePopup removeAllItems];
	
	[defaultFavoritePopup addItemWithTitle:NSLocalizedString(@"Last Used", @"Last Used entry in favorites menu")];
	[[defaultFavoritePopup menu] addItem:[NSMenuItem separatorItem]];
	
	// Add all favorites to the menu
	for (SPTreeNode *node in [[[[[SPFavoritesController sharedFavoritesController] favoritesTree] childNodes] objectAtIndex:0] childNodes])
	{
		NSArray *items = [self _constructMenuItemsForNode:node atLevel:0];
		
		for (NSMenuItem *item in items)
		{
			[[defaultFavoritePopup menu] addItem:item];
		}
	}
	
	// Select the default favorite from prefs	
	[defaultFavoritePopup selectItemWithTag:[prefs boolForKey:SPSelectLastFavoriteUsed] ? 0 : [prefs integerForKey:SPDefaultFavorite]];
}

#pragma mark -
#pragma mark Private API

/**
 * Builds a menu item and sub-menu (if required) of the supplied tree node.
 *
 * @param node The node to build the menu item for
 *
 * @return The menu item
 */
- (NSArray *)_constructMenuItemsForNode:(SPTreeNode *)node atLevel:(NSUInteger)level
{	
	NSMutableArray *items = [NSMutableArray array];
	
	if ([node isGroup]) {
		
		level++;
		
		SPGroupNode *groupNode = (SPGroupNode *)[node representedObject];
		
		NSMenuItem *groupItem = [[NSMenuItem alloc] initWithTitle:[groupNode nodeName] action:NULL keyEquivalent:@""];
		
		NSUInteger groupLevel = (level - 1);
		
		[groupItem setEnabled:NO];
		[groupItem setImage:folderImage];
		[groupItem setIndentationLevel:groupLevel];
		
		[items addObject:groupItem];
		
		[groupItem release];
		
		for (SPTreeNode *childNode in [node childNodes])
		{
			NSArray *innerItems = [self _constructMenuItemsForNode:childNode atLevel:level];
	
			[items addObjectsFromArray:innerItems];
		}
	}
	else {
		NSDictionary *favorite = [(SPFavoriteNode *)[node representedObject] nodeFavorite];
		
		NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:[favorite objectForKey:SPFavoriteNameKey] action:@selector(updateDefaultFavorite:) keyEquivalent:@""];
	
		[menuItem setTag:[[favorite objectForKey:SPFavoriteIDKey] integerValue]];
		[menuItem setImage:[NSImage imageNamed:SPDatabaseImage]];
		[menuItem setIndentationLevel:level];
		[menuItem setTarget:self];
		
		[items addObject:menuItem];
		
		[menuItem release];
	}
	
	return items;
}

#pragma mark -
#pragma mark Preference pane protocol methods

- (NSView *)preferencePaneView
{
	return [self view];
}

- (NSImage *)preferencePaneIcon
{
	return [NSImage imageNamed:@"toolbar-preferences-general"];
}

- (NSString *)preferencePaneName
{
	return NSLocalizedString(@"General", @"general preference pane name");
}

- (NSString *)preferencePaneIdentifier
{
	return SPPreferenceToolbarGeneral;
}

- (NSString *)preferencePaneToolTip
{
	return NSLocalizedString(@"General Preferences", @"general preference pane tooltip");
}

- (BOOL)preferencePaneAllowsResizing
{
	return NO;
}

#pragma mark -

- (void)dealloc
{
	[folderImage release], folderImage = nil;
	
	[super dealloc];
}

@end
