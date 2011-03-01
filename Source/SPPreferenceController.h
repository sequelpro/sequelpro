//
//  $Id$
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

#import "SPPreferencePane.h"

@class SPGeneralPreferencePane,
	   SPTablesPreferencePane,
	   SPFavoritesPreferencePane,
	   SPNotificationsPreferencePane,
	   SPEditorPreferencePane,
	   SPAutoUpdatePreferencePane,
	   SPNetworkPreferencePane;

/**
 * @class SPPreferenceController SPPreferenceController.h
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * Main preferences window controller.
 */
@interface SPPreferenceController : NSWindowController
{	
	// Preference pane controllers
	IBOutlet SPGeneralPreferencePane <SPPreferencePaneProtocol>       *generalPreferencePane;
	IBOutlet SPTablesPreferencePane  <SPPreferencePaneProtocol>       *tablesPreferencePane;
	IBOutlet SPFavoritesPreferencePane <SPPreferencePaneProtocol>     *favoritesPreferencePane;
	IBOutlet SPNotificationsPreferencePane <SPPreferencePaneProtocol> *notificationsPreferencePane;
	IBOutlet SPEditorPreferencePane <SPPreferencePaneProtocol>        *editorPreferencePane;
	IBOutlet SPAutoUpdatePreferencePane <SPPreferencePaneProtocol>    *autoUpdatePreferencePane;
	IBOutlet SPNetworkPreferencePane <SPPreferencePaneProtocol>       *networkPreferencePane;

	NSToolbar *toolbar;
	NSArray *preferencePanes;
	
	// Toolbar items
	NSToolbarItem *generalItem;
	NSToolbarItem *notificationsItem;
	NSToolbarItem *tablesItem;
	NSToolbarItem *favoritesItem;
	NSToolbarItem *autoUpdateItem;
	NSToolbarItem *networkItem;
	NSToolbarItem *editorItem;
	NSToolbarItem *shortcutItem;
	
	NSUInteger fontChangeTarget;
}

@property (readonly) SPGeneralPreferencePane       *generalPreferencePane;
@property (readonly) SPTablesPreferencePane        *tablesPreferencePane;
@property (readonly) SPFavoritesPreferencePane     *favoritesPreferencePane;
@property (readonly) SPNotificationsPreferencePane *notificationsPreferencePane;
@property (readonly) SPEditorPreferencePane        *editorPreferencePane;
@property (readonly) SPAutoUpdatePreferencePane    *autoUpdatePreferencePane;
@property (readonly) SPNetworkPreferencePane       *networkPreferencePane;

/**
 * @property fontChangeTarget Indicates which font was changed (1 for global table font, 2 for custom 
 * query font).
 */
@property (readwrite, assign) NSUInteger fontChangeTarget;

@end
