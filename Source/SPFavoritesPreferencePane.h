//
//  $Id$
//
//  SPFavoritesPreferencePane.h
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

#import "SPPreferencePane.h"

@class SPKeychain, BWAnchoredButtonBar;

/**
 * @class SPFavoritesPreferencePane SPFavoritesPreferencePane.h
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * Favorites preference pane controller.
 */
@interface SPFavoritesPreferencePane : SPPreferencePane <SPPreferencePaneProtocol> 
{
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
	
	IBOutlet NSButton *sshSSHKeyButton;
	IBOutlet NSButton *standardSSLKeyFileButton;
	IBOutlet NSButton *standardSSLCertificateButton;
	IBOutlet NSButton *standardSSLCACertButton;
	IBOutlet NSButton *socketSSLKeyFileButton;
	IBOutlet NSButton *socketSSLCertificateButton;
	IBOutlet NSButton *socketSSLCACertButton;
	
	IBOutlet NSView *sshKeyLocationHelp;
	IBOutlet NSView *sslKeyFileLocationHelp;
	IBOutlet NSView *sslCertificateLocationHelp;
	IBOutlet NSView *sslCACertLocationHelp;
	
	IBOutlet NSTextFieldCell *tableCell;

	IBOutlet NSMenuItem *favoritesSortByMenuItem;
	
	IBOutlet BWAnchoredButtonBar *splitViewButtonBar;
	
	SPKeychain *keychain;

	NSOpenPanel *keySelectionPanel;
	
	NSInteger favoriteType;
	NSDictionary *currentFavorite;
	BOOL favoriteNameFieldWasTouched;
	
	// Sorting
	BOOL reverseFavoritesSort;
	SPFavoritesSortItem previousSortItem, currentSortItem;
}

- (IBAction)addFavorite:(id)sender;
- (IBAction)removeFavorite:(id)sender;
- (IBAction)duplicateFavorite:(id)sender;
- (IBAction)makeSelectedFavoriteDefault:(id)sender;
- (IBAction)sortFavorites:(id)sender;
- (IBAction)reverseFavoritesSortOrder:(id)sender;
- (IBAction)chooseKeyLocation:(id)sender;
- (IBAction)favoriteTypeDidChange:(id)sender;
- (IBAction)chooseKeyLocation:(id)sender;
- (IBAction)updateKeyLocationFileVisibility:(id)sender;

- (void)selectFavorites:(NSArray *)favorites;

@end
