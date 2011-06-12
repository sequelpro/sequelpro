//
//  $Id$
//
//  SPConnectionController.h
//  sequel-pro
//
//  Created by Rowan Beentje on 28/06/2009.
//  Copyright 2009 Arboreal. All rights reserved.
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

#import <MCPKit/MCPKit.h>
#import "SPFavoritesExportProtocol.h"
#import "SPConnectionControllerDelegateProtocol.h"

#ifndef SP_REFACTOR /* headers */
#endif

@class SPDatabaseDocument, 
	   SPFavoritesController, 
	   SPSSHTunnel,
	   SPTreeNode,
	   SPFavoritesOutlineView
#ifndef SP_REFACTOR /* class decl */
	   ,SPKeychain, 
	   BWAnchoredButtonBar, 
	   SPFavoriteNode
#endif
;

#ifndef SP_REFACTOR /* class decl */

@interface NSObject (BWAnchoredButtonBar)

- (NSRect)splitView:(NSSplitView *)splitView additionalEffectiveRectOfDividerAtIndex:(NSInteger)dividerIndex;

@end

#endif

@interface SPConnectionController : NSObject
{
	id <SPConnectionControllerDelegateProtocol, NSObject> delegate;
	
	SPDatabaseDocument *dbDocument;
	SPSSHTunnel *sshTunnel;
	
#ifndef SP_REFACTOR	/* ivars */
	SPKeychain *keychain;
#endif
	
	MCPConnection *mySQLConnection;
	
#ifndef SP_REFACTOR	/* ivars */
	NSView *databaseConnectionSuperview;
	NSSplitView *databaseConnectionView;
	NSUserDefaults *prefs;
	NSMutableArray *favorites;

	BOOL automaticFavoriteSelection;
#endif
	BOOL cancellingConnection;
	BOOL isConnecting;
#ifndef SP_REFACTOR	/* ivars */
	// Standard details
	NSInteger previousType;
#endif
	NSInteger type;
	NSString *name;
	NSString *host;
	NSString *user;
	NSString *password;
	NSString *database;
	NSString *socket;
	NSString *port;
	
	// SSL details
	NSInteger useSSL;
	NSInteger sslKeyFileLocationEnabled;
	NSString *sslKeyFileLocation;
	NSInteger sslCertificateFileLocationEnabled;
	NSString *sslCertificateFileLocation;
	NSInteger sslCACertFileLocationEnabled;
	NSString *sslCACertFileLocation;
	
	// SSH details
	NSString *sshHost;
	NSString *sshUser;
	NSString *sshPassword;
	NSInteger sshKeyLocationEnabled;
	NSString *sshKeyLocation;
	NSString *sshPort;

	NSString *connectionKeychainID;
	NSString *connectionKeychainItemName;
#ifndef SP_REFACTOR	/* ivars */
	NSString *connectionKeychainItemAccount;
	NSString *connectionSSHKeychainItemName;
	NSString *connectionSSHKeychainItemAccount;

	NSMutableArray *nibObjectsToRelease;

	IBOutlet NSView *connectionView;
	IBOutlet NSSplitView *connectionSplitView;
	IBOutlet NSScrollView *connectionDetailsScrollView;
	IBOutlet NSTextField *connectionInstructionsTextField;
	IBOutlet BWAnchoredButtonBar *connectionSplitViewButtonBar;
	IBOutlet SPFavoritesOutlineView *favoritesOutlineView;

	IBOutlet NSWindow *errorDetailWindow;
	IBOutlet NSTextView *errorDetailText;

	IBOutlet NSView *connectionResizeContainer;
	IBOutlet NSView *standardConnectionFormContainer;
	IBOutlet NSView *standardConnectionSSLDetailsContainer;
	IBOutlet NSView *socketConnectionFormContainer;
	IBOutlet NSView *socketConnectionSSLDetailsContainer;
	IBOutlet NSView *sshConnectionFormContainer;
	IBOutlet NSView *sshKeyLocationHelp;
	IBOutlet NSView *sslKeyFileLocationHelp;
	IBOutlet NSView *sslCertificateLocationHelp;
	IBOutlet NSView *sslCACertLocationHelp;

	IBOutlet NSTextField *standardNameField;
	IBOutlet NSTextField *sshNameField;
	IBOutlet NSTextField *socketNameField;
	IBOutlet NSTextField *standardSQLHostField;
	IBOutlet NSTextField *sshSQLHostField;
	IBOutlet NSTextField *standardUserField;
	IBOutlet NSTextField *socketUserField;
	IBOutlet NSTextField *sshUserField;
	IBOutlet NSSecureTextField *standardPasswordField;
	IBOutlet NSSecureTextField *socketPasswordField;
	IBOutlet NSSecureTextField *sshPasswordField;
	IBOutlet NSSecureTextField *sshSSHPasswordField;
	IBOutlet NSButton *sshSSHKeyButton;
	IBOutlet NSButton *standardSSLKeyFileButton;
	IBOutlet NSButton *standardSSLCertificateButton;
	IBOutlet NSButton *standardSSLCACertButton;
	IBOutlet NSButton *socketSSLKeyFileButton;
	IBOutlet NSButton *socketSSLCertificateButton;
	IBOutlet NSButton *socketSSLCACertButton;

	IBOutlet NSButton *addToFavoritesButton;
	IBOutlet NSButton *connectButton;
	IBOutlet NSButton *helpButton;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSTextField *progressIndicatorText;
    IBOutlet NSMenuItem *favoritesSortByMenuItem;
	IBOutlet NSView *exportPanelAccessoryView;
	
	BOOL isEditing;
    BOOL reverseFavoritesSort;
#endif
	BOOL mySQLConnectionCancelled;
	BOOL favoriteNameFieldWasTouched;
	
#ifndef SP_REFACTOR	/* ivars */
	NSImage *folderImage;
	
	SPTreeNode *favoritesRoot;
	SPFavoriteNode *currentFavorite;
	SPFavoritesController *favoritesController;
	SPFavoritesSortItem previousSortItem, currentSortItem;
#endif
}

@property (readwrite, assign) id <SPConnectionControllerDelegateProtocol, NSObject> delegate;
@property (readwrite, assign) NSInteger type;
@property (readwrite, retain) NSString *name;
@property (readwrite, retain) NSString *host;
@property (readwrite, retain) NSString *user;
@property (readwrite, retain) NSString *password;
@property (readwrite, retain) NSString *database;
@property (readwrite, retain) NSString *socket;
@property (readwrite, retain) NSString *port;
@property (readwrite, assign) NSInteger useSSL;
@property (readwrite, assign) NSInteger sslKeyFileLocationEnabled;
@property (readwrite, retain) NSString *sslKeyFileLocation;
@property (readwrite, assign) NSInteger sslCertificateFileLocationEnabled;
@property (readwrite, retain) NSString *sslCertificateFileLocation;
@property (readwrite, assign) NSInteger sslCACertFileLocationEnabled;
@property (readwrite, retain) NSString *sslCACertFileLocation;
@property (readwrite, retain) NSString *sshHost;
@property (readwrite, retain) NSString *sshUser;
@property (readwrite, retain) NSString *sshPassword;
@property (readwrite, assign) NSInteger sshKeyLocationEnabled;
@property (readwrite, retain) NSString *sshKeyLocation;
@property (readwrite, retain) NSString *sshPort;
#ifndef SP_REFACTOR	/* ivars */

@property (readwrite, retain) NSString *connectionKeychainItemName;
@property (readwrite, retain) NSString *connectionKeychainItemAccount;
@property (readwrite, retain) NSString *connectionSSHKeychainItemName;
@property (readwrite, retain) NSString *connectionSSHKeychainItemAccount;
#endif

@property (readonly, assign) BOOL isConnecting;

- (id)initWithDocument:(SPDatabaseDocument *)document;

// Connection processes
- (IBAction)initiateConnection:(id)sender;
#ifndef SP_REFACTOR /* method decls */
- (IBAction)cancelMySQLConnection:(id)sender;

// Interface interaction
- (IBAction)nodeDoubleClicked:(id)sender;
- (IBAction)chooseKeyLocation:(id)sender;
- (IBAction)showHelp:(id)sender;
- (IBAction)updateSSLInterface:(id)sender;
- (IBAction)sortFavorites:(id)sender;
- (IBAction)reverseSortFavorites:(id)sender;

- (void)resizeTabViewToConnectionType:(NSUInteger)theType animating:(BOOL)animate;

// Favorites interaction
- (void)updateFavoriteSelection:(id)sender;
- (NSMutableDictionary *)selectedFavorite;
- (SPTreeNode *)selectedFavoriteNode;
- (NSArray *)selectedFavoriteNodes;

- (IBAction)addFavorite:(id)sender;
- (IBAction)addFavoriteUsingCurrentDetails:(id)sender;
- (IBAction)addGroup:(id)sender;
- (IBAction)removeNode:(id)sender;
- (IBAction)duplicateFavorite:(id)sender;
- (IBAction)renameFavorite:(id)sender;
- (IBAction)makeSelectedFavoriteDefault:(id)sender;

// Import/export favorites
- (IBAction)importFavorites:(id)sender;
- (IBAction)exportFavorites:(id)sender;

// Accessors
- (SPFavoritesOutlineView *)favoritesOutlineView;

#endif
@end
