//
//  $Id$
//
//  SPPreferenceControllerDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 31, 2010.
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
	
	return [sender showsResizeIndicator] ? frameSize : [sender frame].size;
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
			SPPreferenceToolbarNotifications, 
			SPPreferenceToolbarEditor, 
			SPPreferenceToolbarShortcuts, 
			SPPreferenceToolbarAutoUpdate, 
			SPPreferenceToolbarNetwork, 
			nil];
}

@end
