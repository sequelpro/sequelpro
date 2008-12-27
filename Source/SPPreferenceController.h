//
//  SPPreferenceController.h
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

#import <Cocoa/Cocoa.h>

@interface SPPreferenceController : NSWindowController
{
	IBOutlet NSView *generalView;
	IBOutlet NSView *notificationsView;
	IBOutlet NSView *tablesView;
	IBOutlet NSView *favoritesView;
	IBOutlet NSView *advancedView;
	IBOutlet NSView *blankView;
	
	IBOutlet NSTableView *favoritesTableView;
	
	NSToolbar *toolbar;
	
	NSToolbarItem *generalItem;
	NSToolbarItem *notificationsItem;
	NSToolbarItem *tablesItem;
	NSToolbarItem *favoritesItem;
	NSToolbarItem *advancedItem;
	
	NSMutableArray *favorites;
	NSUserDefaults *prefs;
}

// Toolbar item IB action methods
- (IBAction)displayGeneralPreferences:(id)sender;
- (IBAction)displayTablePreferences:(id)sender;
- (IBAction)displayFavoritePreferences:(id)sender;
- (IBAction)displayNotificationPreferences:(id)sender;
- (IBAction)displayAdvancedPreferences:(id)sender;

@end
