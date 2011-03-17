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

@interface SPGeneralPreferencePane ()

- (NSMenuItem *)_constructMenuItemForNode:(SPTreeNode *)node;

@end

@implementation SPGeneralPreferencePane

#pragma mark -
#pragma mark IB action methods

/**
 * Updates the default favorite.
 */ 
- (IBAction)updateDefaultFavorite:(id)sender
{
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
	
	// Use the last used favorite
	[defaultFavoritePopup addItemWithTitle:NSLocalizedString(@"Last Used", @"Last Used entry in favorites menu")];
	[[defaultFavoritePopup menu] addItem:[NSMenuItem separatorItem]];
	
	// Add all favorites to the menu
	for (SPTreeNode *node in [[[[[SPFavoritesController sharedFavoritesController] favoritesTree] childNodes] objectAtIndex:0] childNodes])
	{
		NSMenuItem *menuItem = [self _constructMenuItemForNode:node];
		
		[[defaultFavoritePopup menu] addItem:menuItem];
		
		[menuItem release];
	}
	
	// Select the default favorite from prefs
	if (![prefs boolForKey:SPSelectLastFavoriteUsed]) {
		[defaultFavoritePopup selectItemWithTag:[prefs integerForKey:SPDefaultFavorite]];
	}
	else {
		[defaultFavoritePopup selectItemAtIndex:0];
	}
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
- (NSMenuItem *)_constructMenuItemForNode:(SPTreeNode *)node
{
	NSMenuItem *menuItem = nil;
	
	if ([node isGroup]) {
		
		SPGroupNode *groupNode = (SPGroupNode *)[node representedObject];
		
		menuItem = [[NSMenuItem alloc] initWithTitle:[groupNode nodeName] action:NULL keyEquivalent:@""];
		
		NSMenu *subMenu = [[NSMenu alloc] initWithTitle:[groupNode nodeName]];
		
		for (SPTreeNode *childNode in [node childNodes])
		{
			NSMenuItem *innerItem = [self _constructMenuItemForNode:childNode];
			
			[subMenu addItem:innerItem];
			
			[innerItem release];
		}
		
		[menuItem setSubmenu:subMenu];
	}
	else {
		NSDictionary *favorite = [(SPFavoriteNode *)[node representedObject] nodeFavorite];
		
		menuItem = [[NSMenuItem alloc] initWithTitle:[favorite objectForKey:SPFavoriteNameKey] action:@selector(updateDefaultFavorite:) keyEquivalent:@""];
	
		[menuItem setTag:[[favorite objectForKey:SPFavoriteIDKey] integerValue]];
	
		[menuItem setTarget:self];
	}
	
	return menuItem;
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

@end
