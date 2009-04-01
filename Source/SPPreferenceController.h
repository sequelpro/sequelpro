//
//  SPPreferenceController.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Dec 10, 2008
//  Modified by Ben Perry (benperry.com.au) on Mar 28, 2009
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

#import <Cocoa/Cocoa.h>

@class KeyChain;

@interface SPPreferenceController : NSWindowController
{
	IBOutlet NSWindow *preferencesWindow;
	
	IBOutlet NSView *generalView;
	IBOutlet NSView *notificationsView;
	IBOutlet NSView *tablesView;
	IBOutlet NSView *favouritesView;
	IBOutlet NSView *autoUpdateView;
	IBOutlet NSView *advancedView;
	IBOutlet NSView *blankView;
	
	IBOutlet NSPopUpButton *defaultFavouritePopup;
	
	IBOutlet NSTableView *favouritesTableView;
	IBOutlet NSArrayController *favouritesController;
	
	KeyChain *keychain;
	
	NSToolbar *toolbar;
	
	NSToolbarItem *generalItem;
	NSToolbarItem *notificationsItem;
	NSToolbarItem *tablesItem;
	NSToolbarItem *favouritesItem;
	NSToolbarItem *autoUpdateItem;
	NSToolbarItem *advancedItem;

	NSUserDefaults *prefs;
}

// IBAction methods
- (IBAction)addFavourite:(id)sender;
- (IBAction)removeFavourite:(id)sender;
- (IBAction)duplicateFavourite:(id)sender;
- (IBAction)updateDefaultFavourite:(id)sender;

// Toolbar item IBAction methods
- (IBAction)displayGeneralPreferences:(id)sender;
- (IBAction)displayTablePreferences:(id)sender;
- (IBAction)displayFavouritePreferences:(id)sender;
- (IBAction)displayNotificationPreferences:(id)sender;
- (IBAction)displayAutoUpdatePreferences:(id)sender;
- (IBAction)displayAdvancedPreferences:(id)sender;

@end
