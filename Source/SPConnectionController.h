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
#import "SPConnectionControllerDelegateProtocol.h"

#ifndef SP_REFACTOR /* headers */
#import "SPFavoritesOutlineView.h"
#endif

@class SPDatabaseDocument, SPSSHTunnel, SPKeychain
#ifndef SP_REFACTOR /* class decl */
, BWAnchoredButtonBar, SPFavoriteNode
#endif
;

#ifndef SP_REFACTOR /* class decl */

@interface NSObject (BWAnchoredButtonBar)

- (NSRect)splitView:(NSSplitView *)splitView additionalEffectiveRectOfDividerAtIndex:(NSInteger)dividerIndex;

@end

@interface SPFlippedView : NSView

- (BOOL)isFlipped;

@end
#endif

@interface SPConnectionController : NSObject 
{
	id <SPConnectionControllerDelegateProtocol, NSObject> delegate;
	
	SPDatabaseDocument *tableDocument;
#ifndef SP_REFACTOR	/* ivars */
	NSView *databaseConnectionSuperview;
	NSSplitView *databaseConnectionView;
	NSOpenPanel *keySelectionPanel;
#endif
	SPKeychain *keychain;
	NSUserDefaults *prefs;
#ifndef SP_REFACTOR
	NSMutableArray *favorites;
#endif
	SPSSHTunnel *sshTunnel;
	MCPConnection *mySQLConnection;
#ifndef SP_REFACTOR	/* ivars */
	BOOL automaticFavoriteSelection;
#endif
	BOOL cancellingConnection;
	BOOL isConnecting;
#ifndef SP_REFACTOR	/* ivars */
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
	int useSSL;
	int sslKeyFileLocationEnabled;
	NSString *sslKeyFileLocation;
	int sslCertificateFileLocationEnabled;
	NSString *sslCertificateFileLocation;
	int sslCACertFileLocationEnabled;
	NSString *sslCACertFileLocation;
	NSString *sshHost;
	NSString *sshUser;
	NSString *sshPassword;
	int sshKeyLocationEnabled;
	NSString *sshKeyLocation;
	NSString *sshPort;
#ifndef SP_REFACTOR	/* ivars */
	@private NSString *favoritesPBoardType;
#endif

	NSString *connectionKeychainID;
	NSString *connectionKeychainItemName;
	NSString *connectionKeychainItemAccount;
	NSString *connectionSSHKeychainItemName;
	NSString *connectionSSHKeychainItemAccount;

#ifndef SP_REFACTOR	/* ivars */
	NSMutableArray *nibObjectsToRelease;

	IBOutlet NSView *connectionView;
	IBOutlet NSSplitView *connectionSplitView;
	IBOutlet NSScrollView *connectionDetailsScrollView;
	IBOutlet BWAnchoredButtonBar *connectionSplitViewButtonBar;
	IBOutlet SPFavoritesOutlineView *favoritesTable;

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

	IBOutlet NSTextField *standardSQLHostField;
	IBOutlet NSTextField *sshSQLHostField;
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
	
    BOOL reverseFavoritesSort;
#endif

	BOOL mySQLConnectionCancelled;
#ifndef SP_REFACTOR	/* ivars */
    SPFavoritesSortItem previousSortItem, currentSortItem;
	
	SPFavoriteNode *favoritesRoot;
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
@property (readwrite, assign) int useSSL;
@property (readwrite, assign) int sslKeyFileLocationEnabled;
@property (readwrite, retain) NSString *sslKeyFileLocation;
@property (readwrite, assign) int sslCertificateFileLocationEnabled;
@property (readwrite, retain) NSString *sslCertificateFileLocation;
@property (readwrite, assign) int sslCACertFileLocationEnabled;
@property (readwrite, retain) NSString *sslCACertFileLocation;
@property (readwrite, retain) NSString *sshHost;
@property (readwrite, retain) NSString *sshUser;
@property (readwrite, retain) NSString *sshPassword;
@property (readwrite, assign) int sshKeyLocationEnabled;
@property (readwrite, retain) NSString *sshKeyLocation;
@property (readwrite, retain) NSString *sshPort;
@property (readwrite, retain) NSString *connectionKeychainItemName;
@property (readwrite, retain) NSString *connectionKeychainItemAccount;
@property (readwrite, retain) NSString *connectionSSHKeychainItemName;
@property (readwrite, retain) NSString *connectionSSHKeychainItemAccount;

@property (readonly, assign) BOOL isConnecting;
#ifndef SP_REFACTOR	/* ivars */
@property (readonly, assign) NSString *favoritesPBoardType;
#endif

- (id)initWithDocument:(SPDatabaseDocument *)theTableDocument;

// Connection processes
- (IBAction)initiateConnection:(id)sender;
- (IBAction)cancelMySQLConnection:(id)sender;
- (void)initiateSSHTunnelConnection;
- (void)sshTunnelCallback:(SPSSHTunnel *)theTunnel;
- (void)initiateMySQLConnection;
- (void)cancelConnection;
- (void)failConnectionWithTitle:(NSString *)theTitle errorMessage:(NSString *)theErrorMessage detail:(NSString *)errorDetail;
- (void)addConnectionToDocument;

// Interface interaction
- (IBAction)chooseKeyLocation:(id)sender;
#ifndef SP_REFACTOR /* method decls */
- (IBAction)editFavorites:(id)sender;
- (IBAction)showHelp:(id)sender;
- (IBAction)updateSSLInterface:(id)sender;
- (IBAction)updateKeyLocationFileVisibility:(id)sender;
- (void)resizeTabViewToConnectionType:(NSUInteger)theType animating:(BOOL)animate;
- (IBAction)sortFavorites:(id)sender;
- (IBAction)reverseSortFavorites:(id)sender;
#endif

// Connection details interaction
- (BOOL)checkHost;

#ifndef SP_REFACTOR
// Favorites interaction
- (void)updateFavorites;
- (void)updateFavoriteSelection:(id)sender;
- (id)selectedFavorite;
- (IBAction)addFavorite:(id)sender;

- (void)scrollViewFrameChanged:(NSNotification *)aNotification;

#endif
@end
