//
//  SPPreferenceController.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Dec 10, 2008
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

#import "SPPreferenceController.h"
#import "SPWindowAdditions.h"

#define PREFERENCE_TOOLBAR_GENERAL       @"Preference Toolbar General"
#define PREFERENCE_TOOLBAR_TABLES        @"Preference Toolbar Tables"
#define PREFERENCE_TOOLBAR_FAVORITES     @"Preference Toolbar Favorites"
#define PREFERENCE_TOOLBAR_NOTIFICATIONS @"Preference Toolbar Notifications"
#define PREFERENCE_TOOLBAR_ADVANCED      @"Preference Toolbar Advanced"

@interface SPPreferenceController (PrivateAPI)

- (void)_setupToolbar;
- (void)_resizeWindowForContentView:(NSView *)view;

@end

@implementation SPPreferenceController

// -------------------------------------------------------------------------------
// init
// -------------------------------------------------------------------------------
- (id)init
{
	return [super initWithWindowNibName:@"Preferences"];
}

// -------------------------------------------------------------------------------
// windowDidLoad
// -------------------------------------------------------------------------------
- (void)windowDidLoad
{	
	[self _setupToolbar];
	
	prefs = [NSUserDefaults standardUserDefaults];
	
	favorites = [[NSMutableArray alloc] initWithArray:[prefs objectForKey:@"favorites"]];
	
	if (favorites == nil) {
		favorites = [NSMutableArray array];
	}
	
	[favoritesTableView reloadData];
}

#pragma mark -
#pragma mark Toolbar item IB action methods

// -------------------------------------------------------------------------------
// displayGeneralPreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayGeneralPreferences:(id)sender
{
	[self _resizeWindowForContentView:generalView];
}

// -------------------------------------------------------------------------------
// displayTablePreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayTablePreferences:(id)sender
{
	[self _resizeWindowForContentView:tablesView];
}

// -------------------------------------------------------------------------------
// displayFavoritePreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayFavoritePreferences:(id)sender
{
	[self _resizeWindowForContentView:favoritesView];
}

// -------------------------------------------------------------------------------
// displayNotificationPreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayNotificationPreferences:(id)sender
{
	[self _resizeWindowForContentView:notificationsView];
}

// -------------------------------------------------------------------------------
// displayAdvancedPreferences:
// -------------------------------------------------------------------------------
- (IBAction)displayAdvancedPreferences:(id)sender
{
	[self _resizeWindowForContentView:advancedView];
}

#pragma mark -
#pragma mark TableView datasource methods

// -------------------------------------------------------------------------------
// numberOfRowsInTableView:
// -------------------------------------------------------------------------------
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [favorites count];
}

// -------------------------------------------------------------------------------
// tableView:objectValueForTableColumn:row:
// -------------------------------------------------------------------------------
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	return [[favorites objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
}

#pragma mark -
#pragma mark Toolbar delegate methods

// -------------------------------------------------------------------------------
// toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:
// -------------------------------------------------------------------------------
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{		
    if ([itemIdentifier isEqualToString:PREFERENCE_TOOLBAR_GENERAL]) {
        return generalItem;
    }
	else if ([itemIdentifier isEqualToString:PREFERENCE_TOOLBAR_TABLES]) {
		return tablesItem;
	}
	else if ([itemIdentifier isEqualToString:PREFERENCE_TOOLBAR_FAVORITES]) {
		return favoritesItem;
	}
	else if ([itemIdentifier isEqualToString:PREFERENCE_TOOLBAR_NOTIFICATIONS]) {
		return notificationsItem;
	}
	else if ([itemIdentifier isEqualToString:PREFERENCE_TOOLBAR_ADVANCED]) {
		return advancedItem;
	}
	
    return [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
}

// -------------------------------------------------------------------------------
// toolbarAllowedItemIdentifiers:
// -------------------------------------------------------------------------------
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:PREFERENCE_TOOLBAR_GENERAL, PREFERENCE_TOOLBAR_TABLES, PREFERENCE_TOOLBAR_FAVORITES, PREFERENCE_TOOLBAR_NOTIFICATIONS, PREFERENCE_TOOLBAR_ADVANCED, nil];
}

// -------------------------------------------------------------------------------
// toolbarDefaultItemIdentifiers:
// -------------------------------------------------------------------------------
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:PREFERENCE_TOOLBAR_GENERAL, PREFERENCE_TOOLBAR_TABLES, PREFERENCE_TOOLBAR_FAVORITES, PREFERENCE_TOOLBAR_NOTIFICATIONS, PREFERENCE_TOOLBAR_ADVANCED, nil];
}

// -------------------------------------------------------------------------------
// toolbarDefaultItemIdentifiers:
// -------------------------------------------------------------------------------
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:PREFERENCE_TOOLBAR_GENERAL, PREFERENCE_TOOLBAR_TABLES, PREFERENCE_TOOLBAR_FAVORITES, PREFERENCE_TOOLBAR_NOTIFICATIONS, PREFERENCE_TOOLBAR_ADVANCED, nil];
}

@end

@implementation SPPreferenceController (PrivateAPI)

// -------------------------------------------------------------------------------
// _setupToolbar
//
// Constructs the preferences' window toolbar.
// -------------------------------------------------------------------------------
- (void)_setupToolbar
{
	toolbar = [[[NSToolbar alloc] initWithIdentifier:@"Preference Toolbar"] autorelease];
	
	// General preferences
	generalItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_GENERAL];
    
	[generalItem setLabel:NSLocalizedString(@"General", @"")];
    [generalItem setImage:[NSImage imageNamed:NSImageNamePreferencesGeneral]];
    [generalItem setTarget:self];
    [generalItem setAction:@selector(displayGeneralPreferences:)];
	
	// Table preferences
	tablesItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_TABLES];
	
	[tablesItem setLabel:NSLocalizedString(@"Tables", @"")];
	[tablesItem setImage:[NSImage imageNamed:@"tables-new"]];
	[tablesItem setTarget:self];
	[tablesItem setAction:@selector(displayTablePreferences:)];
	
	// Favorite preferences
	favoritesItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_FAVORITES];
	
	[favoritesItem setLabel:NSLocalizedString(@"Favorites", @"")];
    [favoritesItem setImage:[NSImage imageNamed:@"favorites"]];
    [favoritesItem setTarget:self];
    [favoritesItem setAction:@selector(displayFavoritePreferences:)];
	
	// Notification preferences
	notificationsItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_NOTIFICATIONS];
	
	[notificationsItem setLabel:NSLocalizedString(@"Notifications", @"")];
    [notificationsItem setImage:[NSImage imageNamed:@"notifications"]];
    [notificationsItem setTarget:self];
    [notificationsItem setAction:@selector(displayNotificationPreferences:)];
	
	// Adavanced preferences
	advancedItem = [[NSToolbarItem alloc] initWithItemIdentifier:PREFERENCE_TOOLBAR_ADVANCED];
	
	[advancedItem setLabel:NSLocalizedString(@"Advanced", @"")];
    [advancedItem setImage:[NSImage imageNamed:NSImageNameAdvanced]];
    [advancedItem setTarget:self];
    [advancedItem setAction:@selector(displayAdvancedPreferences:)];
    
    [toolbar setDelegate:self];
	[toolbar setSelectedItemIdentifier:PREFERENCE_TOOLBAR_GENERAL];
    
	[[self window] setToolbar:toolbar];
	[[self window] setContentView:generalView];
	[[self window] setShowsToolbarButton:NO];
}

// -------------------------------------------------------------------------------
// _resizeWindowForContentView:
//
// Resizes the window to the size of the supplied view.
// -------------------------------------------------------------------------------
- (void)_resizeWindowForContentView:(NSView *)view
{
	[[self window] setContentView:blankView];
	[[self window] resizeForContentView:view titleBarVisible:YES];
}

@end
