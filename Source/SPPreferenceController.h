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

#import <Cocoa/Cocoa.h>

@class KeyChain;

@interface SPPreferenceController : NSWindowController
{
	IBOutlet NSWindow *preferencesWindow;
	
	IBOutlet NSView *generalView;
	IBOutlet NSView *notificationsView;
	IBOutlet NSView *tablesView;
	IBOutlet NSView *favoritesView;
	IBOutlet NSView *autoUpdateView;
	IBOutlet NSView *networkView;
	IBOutlet NSView *editorView;
	
	IBOutlet NSPopUpButton *defaultFavoritePopup;
	
	IBOutlet NSTableView *favoritesTableView;
	IBOutlet NSArrayController *favoritesController;
	
	IBOutlet NSTabView *favoritesTabView;
	IBOutlet NSTextField *nameField;
	IBOutlet NSTextField *standardSQLHostField;
	IBOutlet NSTextField *standardUserField;
	IBOutlet NSSecureTextField *standardPasswordField;
	IBOutlet NSTextField *standardDatabaseField;
	IBOutlet NSTextField *socketUserField;
	IBOutlet NSSecureTextField *socketPasswordField;
	IBOutlet NSTextField *socketDatabaseField;
	IBOutlet NSTextField *sshSQLHostField;
	IBOutlet NSTextField *sshSQLUserField;
	IBOutlet NSSecureTextField *sshSQLPasswordField;
	IBOutlet NSTextField *sshDatabaseField;
	IBOutlet NSTextField *sshHostField;
	IBOutlet NSTextField *sshUserField;
	IBOutlet NSSecureTextField *sshPasswordField;
	KeyChain *keychain;

	IBOutlet NSTextField *editorFontName;

	NSToolbar *toolbar;
	
	NSToolbarItem *generalItem;
	NSToolbarItem *notificationsItem;
	NSToolbarItem *tablesItem;
	NSToolbarItem *favoritesItem;
	NSToolbarItem *autoUpdateItem;
	NSToolbarItem *networkItem;
	NSToolbarItem *editorItem;
	NSToolbarItem *shortcutItem;

	NSUserDefaults *prefs;
}

- (void)applyRevisionChanges;

// IBAction methods
- (IBAction)addFavorite:(id)sender;
- (IBAction)removeFavorite:(id)sender;
- (IBAction)duplicateFavorite:(id)sender;
- (IBAction)saveFavorite:(id)sender;
- (IBAction)updateDefaultFavorite:(id)sender;
- (IBAction)showCustomQueryFontPanel:(id)sender;
- (IBAction)setDefaultColors:(id)sender;

// Toolbar item IBAction methods
- (IBAction)displayGeneralPreferences:(id)sender;
- (IBAction)displayTablePreferences:(id)sender;
- (IBAction)displayFavoritePreferences:(id)sender;
- (IBAction)displayNotificationPreferences:(id)sender;
- (IBAction)displayAutoUpdatePreferences:(id)sender;
- (IBAction)displayNetworkPreferences:(id)sender;
- (IBAction)displayEditorPreferences:(id)sender;

// Other
- (void)updateDefaultFavoritePopup;
- (void)selectFavorites:(NSArray *)favorite;
- (void)selectFavoriteAtIndex:(unsigned int)theIndex;
- (void)changeFont:(id)sender;
- (IBAction)favoriteTypeDidChange:(id)sender;

@end
