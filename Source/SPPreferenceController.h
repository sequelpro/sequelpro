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

#import "SPConstants.h"

@class BWAnchoredButtonBar, SPKeychain;

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
	IBOutlet NSSecureTextField *standardPasswordField;
	IBOutlet NSSecureTextField *socketPasswordField;
	IBOutlet NSSecureTextField *sshSQLPasswordField;
	IBOutlet NSSecureTextField *sshPasswordField;
	IBOutlet NSTextField *favoriteNameTextField;
	IBOutlet NSTextField *favoriteUserTextField;
	IBOutlet NSTextField *favoriteHostTextField;
	IBOutlet NSTextField *favoriteUserTextFieldSocket;
	IBOutlet NSTextField *favoriteUserTextFieldSSH;
	IBOutlet NSTextField *favoriteHostTextFieldSSH;
	IBOutlet NSMenuItem *favoritesSortByMenuItem;
	IBOutlet NSView *sshKeyLocationHelp;

	IBOutlet NSWindow *enterNameWindow;
	IBOutlet NSTextField *enterNameLabel;
	IBOutlet NSTextField *enterNameInputField;
	IBOutlet NSTextField *enterNameAlertField;
	IBOutlet NSTextField *colorThemeName;
	IBOutlet NSTextField *colorThemeNameLabel;
	IBOutlet id themeNameSaveButton;
	IBOutlet NSTableView *editThemeListTable;
	IBOutlet NSWindow *editThemeListWindow;
	IBOutlet id removeThemeButton;
	IBOutlet id duplicateThemeButton;
	IBOutlet NSMenuItem *saveThemeMenuItem;

	IBOutlet id tableCell;

	IBOutlet NSTableView *colorSettingTableView;
	IBOutlet NSMenu *themeSelectionMenu;
	NSArray *editorColors;
	NSArray *editorNameForColors;
	NSUInteger colorRow;

	IBOutlet NSTextField *editorFontName;
	IBOutlet NSTextField *globalResultTableFontName;
	
	IBOutlet BWAnchoredButtonBar *splitViewButtonBar;

	SPKeychain *keychain;
	NSDictionary *currentFavorite;

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
	
	BOOL favoriteNameFieldWasTouched;
	NSInteger favoriteType, fontChangeTarget;
	
	BOOL reverseFavoritesSort;
	SPFavoritesSortItem previousSortItem, currentSortItem;
	
	NSString *themePath;
	NSInteger checkForUnsavedThemeSheetStatus;
	NSArray *editThemeListItems;
}

- (void)applyRevisionChanges;

// IBAction methods
- (IBAction)addFavorite:(id)sender;
- (IBAction)removeFavorite:(id)sender;
- (IBAction)duplicateFavorite:(id)sender;
- (IBAction)updateDefaultFavorite:(id)sender;
- (IBAction)showCustomQueryFontPanel:(id)sender;
- (IBAction)showGlobalResultTableFontPanel:(id)sender;
- (IBAction)setDefaultColors:(id)sender;
- (IBAction)sortFavorites:(id)sender;
- (IBAction)reverseFavoritesSortOrder:(id)sender;
- (IBAction)makeSelectedFavoriteDefault:(id)sender;
- (IBAction)exportColorScheme:(id)sender;
- (IBAction)importColorScheme:(id)sender;
- (IBAction)saveAsColorScheme:(id)sender;
- (IBAction)loadColorScheme:(id)sender;
- (IBAction)closePanelSheet:(id)sender;
- (IBAction)duplicateTheme:(id)sender;
- (IBAction)removeTheme:(id)sender;
- (IBAction)chooseSSHKey:(id)sender;

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
- (void)changeFont:(id)sender;
- (IBAction)favoriteTypeDidChange:(id)sender;
- (void)updateFavoritePasswordsFromField:(NSControl *)passwordControl;
- (void)updateColorSchemeSelectionMenu;
- (void)saveColorThemeAtPath:(NSString*)path;
- (BOOL)loadColorSchemeFromFile:(NSString*)filename;
- (BOOL)checkForUnsavedTheme;
- (void)updateDisplayColorThemeName;
- (NSArray *)getAvailableThemes;
- (void)checkForUnsavedThemeDidEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;


@end
