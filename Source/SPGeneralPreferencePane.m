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

@implementation SPGeneralPreferencePane

#pragma mark -
#pragma mark IB action methods

/**
 * Updates the default favorite.
 */ 
- (IBAction)updateDefaultFavorite:(id)sender
{
	[prefs setBool:([defaultFavoritePopup indexOfSelectedItem] == 0) forKey:SPSelectLastFavoriteUsed];
	
	// Minus 2 from index to account for the "Last Used" and separator items
	[prefs setInteger:([defaultFavoritePopup indexOfSelectedItem] - 2) forKey:SPDefaultFavorite];
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
	for (NSString *favorite in [[favoritesController arrangedObjects] valueForKeyPath:@"name"])
	{
		NSMenuItem *favoriteMenuItem = [[NSMenuItem alloc] initWithTitle:favorite action:NULL keyEquivalent:@""];
		
		[[defaultFavoritePopup menu] addItem:favoriteMenuItem];
		
		[favoriteMenuItem release];
	}
	
	// Add item to switch to edit favorites pane
	[[defaultFavoritePopup menu] addItem:[NSMenuItem separatorItem]];
	
	NSMenuItem *editMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Edit Favorites…", @"edit favorites menu item") action:@selector(displayFavoritePreferences:) keyEquivalent:@""];
	
	[editMenuItem setTarget:[[[self view] window] delegate]];
	
	[[defaultFavoritePopup menu] addItem:editMenuItem];
	
	[editMenuItem release];
	
	// Select the default favorite from prefs
	[self updateDefaultFavoritePopupSelection];
}

/**
 * Resets the default favorite popup button selection based on the user's preferences.
 */
- (void)updateDefaultFavoritePopupSelection
{
	NSUInteger index = [prefs integerForKey:SPDefaultFavorite];
	
	[defaultFavoritePopup selectItemAtIndex:(![prefs boolForKey:SPSelectLastFavoriteUsed] && index > 0 && index < [[defaultFavoritePopup itemArray] count]) ? index + 2 : 0];
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
