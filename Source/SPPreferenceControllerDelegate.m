//
//  $Id$
//
//  SPPreferenceControllerDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 31, 2010
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

#import "SPPreferenceControllerDelegate.h"

@implementation SPPreferenceController (SPPreferenceControllerDelegate)

#pragma mark -
#pragma mark Window delegate methods

/**
 * Trap window close notifications and use them to ensure changes are saved.
 */
- (void)windowWillClose:(NSNotification *)notification
{
	[[NSColorPanel sharedColorPanel] close];
	
	// Mark the currently selected field in the window as having finished editing, to trigger saves.
	if ([[self window] firstResponder]) {
		[[self window] endEditingFor:[[self window] firstResponder]];
	}
}

/**
 * Trap window resize notifications and use them to disable resizing on most tabs
 * - except for the favourites tab.
 */
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize
{
	[[NSColorPanel sharedColorPanel] close];
	
	return ([sender showsResizeIndicator]) ? frameSize : [sender frame].size;
}

#pragma mark -
#pragma mark Toolbar delegate methods

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{		
    if ([itemIdentifier isEqualToString:SPPreferenceToolbarGeneral]) {
        return generalItem;
    }
	else if ([itemIdentifier isEqualToString:SPPreferenceToolbarTables]) {
		return tablesItem;
	}
	else if ([itemIdentifier isEqualToString:SPPreferenceToolbarFavorites]) {
		return favoritesItem;
	}
	else if ([itemIdentifier isEqualToString:SPPreferenceToolbarNotifications]) {
		return notificationsItem;
	}
	else if ([itemIdentifier isEqualToString:SPPreferenceToolbarAutoUpdate]) {
		return autoUpdateItem;
	}
	else if ([itemIdentifier isEqualToString:SPPreferenceToolbarNetwork]) {
		return networkItem;
	}
	else if ([itemIdentifier isEqualToString:SPPreferenceToolbarEditor]) {
		return editorItem;
	}
	else if ([itemIdentifier isEqualToString:SPPreferenceToolbarShortcuts]) {
		return shortcutItem;
	}
	
    return [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:
			SPPreferenceToolbarGeneral, 
			SPPreferenceToolbarTables, 
			SPPreferenceToolbarFavorites, 
			SPPreferenceToolbarNotifications, 
			SPPreferenceToolbarEditor, 
			SPPreferenceToolbarShortcuts, 
			SPPreferenceToolbarAutoUpdate, 
			SPPreferenceToolbarNetwork, 
			nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:
			SPPreferenceToolbarGeneral, 
			SPPreferenceToolbarTables, 
			SPPreferenceToolbarFavorites, 
			SPPreferenceToolbarNotifications, 
			SPPreferenceToolbarEditor, 
			SPPreferenceToolbarShortcuts, 
			SPPreferenceToolbarAutoUpdate, 
			SPPreferenceToolbarNetwork, 
			nil];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:
			SPPreferenceToolbarGeneral, 
			SPPreferenceToolbarTables, 
			SPPreferenceToolbarFavorites, 
			SPPreferenceToolbarNotifications, 
			SPPreferenceToolbarEditor, 
			SPPreferenceToolbarShortcuts, 
			SPPreferenceToolbarAutoUpdate, 
			SPPreferenceToolbarNetwork, 
			nil];
}

@end
