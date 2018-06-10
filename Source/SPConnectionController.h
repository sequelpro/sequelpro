//
//  SPConnectionController.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 15, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <https://github.com/sequelpro/sequelpro>

#import "SPConnectionControllerDelegateProtocol.h"
#import "SPFavoritesExportProtocol.h"
#import "SPFavoritesImportProtocol.h"

#import <SPMySQL/SPMySQL.h>

@class SPDatabaseDocument, 
	   SPFavoritesController, 
	   SPSSHTunnel,
	   SPTreeNode,
	   SPFavoritesOutlineView,
       SPMySQLConnection,
	   SPSplitView
#ifndef SP_CODA /* class decl */
	   ,SPKeychain, 
	   SPFavoriteNode,
	   SPFavoriteTextFieldCell,
       SPColorSelectorView
#endif
;

@interface SPConnectionController : NSViewController <SPMySQLConnectionDelegate, NSOpenSavePanelDelegate, SPFavoritesImportProtocol, SPFavoritesExportProtocol, NSSplitViewDelegate>
{
	id <SPConnectionControllerDelegateProtocol, NSObject> delegate;
	
	SPDatabaseDocument *dbDocument;
	SPSSHTunnel *sshTunnel;
	SPMySQLConnection *mySQLConnection;
	
#ifndef SP_CODA	/* ivars */
	SPKeychain *keychain;
	NSView *databaseConnectionSuperview;
	NSSplitView *databaseConnectionView;
#endif
	NSOpenPanel *keySelectionPanel;
	NSUserDefaults *prefs;

	BOOL cancellingConnection;
	BOOL isConnecting;
	BOOL isEditingConnection;
	BOOL isTestingConnection;
	
	// Standard details
	NSInteger previousType;
	NSInteger type;
	NSString *name;
	NSString *host;
	NSString *user;
	NSString *password;
	NSString *database;
	NSString *socket;
	NSString *port;
	NSInteger colorIndex;
	BOOL useCompression;
	
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
	NSString *connectionKeychainItemAccount;
	NSString *connectionSSHKeychainItemName;
	NSString *connectionSSHKeychainItemAccount;

	NSMutableArray *nibObjectsToRelease;

	IBOutlet NSView *connectionView;
	IBOutlet SPSplitView *connectionSplitView;
	IBOutlet NSScrollView *connectionDetailsScrollView;
	IBOutlet NSTextField *connectionInstructionsTextField;
	IBOutlet SPFavoritesOutlineView *favoritesOutlineView;

	IBOutlet NSWindow *errorDetailWindow;
	IBOutlet NSTextView *errorDetailText;

	IBOutlet NSView *connectionResizeContainer;
	IBOutlet NSView *standardConnectionFormContainer;
	IBOutlet NSView *standardConnectionSSLDetailsContainer;
	IBOutlet NSView *socketConnectionFormContainer;
	IBOutlet NSView *socketConnectionSSLDetailsContainer;
	IBOutlet NSView *sshConnectionFormContainer;
	IBOutlet NSView *sshConnectionSSLDetailsContainer;
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
	IBOutlet SPColorSelectorView *standardColorField;
	IBOutlet SPColorSelectorView *sshColorField;
	IBOutlet SPColorSelectorView *socketColorField;
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
	IBOutlet NSButton *sslOverSSHKeyFileButton;
	IBOutlet NSButton *sslOverSSHCertificateButton;
	IBOutlet NSButton *sslOverSSHCACertButton;

	IBOutlet NSButton *connectButton;
	IBOutlet NSButton *testConnectButton;
	IBOutlet NSButton *helpButton;
	IBOutlet NSButton *saveFavoriteButton;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSTextField *progressIndicatorText;
    IBOutlet NSMenuItem *favoritesSortByMenuItem;
	IBOutlet NSView *exportPanelAccessoryView;
	IBOutlet NSView *editButtonsView;
	
	BOOL isEditingItemName;
    BOOL reverseFavoritesSort;
	BOOL initComplete;
	BOOL favoriteNameFieldWasAutogenerated;

#ifndef SP_CODA	/* ivars */
	NSArray *draggedNodes;
	NSImage *folderImage;
	
	SPTreeNode *favoritesRoot;
	SPTreeNode *quickConnectItem;

	SPFavoriteTextFieldCell *quickConnectCell;

	NSDictionary *currentFavorite;
	SPFavoritesController *favoritesController;
	SPFavoritesSortItem currentSortItem;
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
@property (readwrite, assign) NSInteger colorIndex;
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
@property (readwrite, copy, nonatomic) NSString *connectionKeychainID;
@property (readwrite, retain) NSString *connectionKeychainItemName;
@property (readwrite, retain) NSString *connectionKeychainItemAccount;
@property (readwrite, retain) NSString *connectionSSHKeychainItemName;
@property (readwrite, retain) NSString *connectionSSHKeychainItemAccount;
@property (readwrite, assign) BOOL useCompression;

#ifdef SP_CODA
@property (readwrite, assign) SPDatabaseDocument *dbDocument;
#endif

@property (readonly, assign) BOOL isConnecting;
@property (readonly, assign) BOOL isEditingConnection;

- (NSString *)keychainPassword;
- (NSString *)keychainPasswordForSSH;

// Connection processes
- (IBAction)initiateConnection:(id)sender;
- (IBAction)cancelConnection:(id)sender;
#ifdef SP_CODA
- (BOOL)cancellingConnection;
#endif

#ifndef SP_CODA
// Interface interaction
- (void)nodeDoubleClicked:(id)sender;
- (IBAction)chooseKeyLocation:(id)sender;
- (IBAction)showHelp:(id)sender;
- (IBAction)updateSSLInterface:(id)sender;
- (IBAction)updateKeyLocationFileVisibility:(id)sender;
- (void)updateSplitViewSize;

- (void)resizeTabViewToConnectionType:(NSUInteger)theType animating:(BOOL)animate;

- (IBAction)sortFavorites:(id)sender;
- (IBAction)reverseSortFavorites:(NSMenuItem *)sender;

// Favorites interaction
- (void)updateFavoriteSelection:(id)sender;
- (void)updateFavoriteNextKeyView;
- (NSMutableDictionary *)selectedFavorite;
- (SPTreeNode *)selectedFavoriteNode;
- (NSArray *)selectedFavoriteNodes;

- (IBAction)saveFavorite:(id)sender;
- (IBAction)addFavorite:(id)sender;
- (IBAction)addFavoriteUsingCurrentDetails:(id)sender;
- (IBAction)addGroup:(id)sender;
- (IBAction)removeNode:(id)sender;
- (IBAction)duplicateFavorite:(id)sender;
- (IBAction)renameNode:(id)sender;
- (IBAction)makeSelectedFavoriteDefault:(id)sender;
- (void)selectQuickConnectItem;

// Import/export favorites
- (IBAction)importFavorites:(id)sender;
- (IBAction)exportFavorites:(id)sender;

// Accessors
- (SPFavoritesOutlineView *)favoritesOutlineView;

#endif

#pragma mark - SPConnectionHandler

- (void)initiateMySQLConnection;
- (void)initiateMySQLConnectionInBackground;
- (void)initiateSSHTunnelConnection;

- (void)mySQLConnectionEstablished;
- (void)sshTunnelCallback:(SPSSHTunnel *)theTunnel;

- (void)addConnectionToDocument;

- (void)failConnectionWithTitle:(NSString *)theTitle errorMessage:(NSString *)theErrorMessage detail:(NSString *)errorDetail rawErrorText:(NSString *)rawErrorText;

#pragma mark - SPConnectionControllerInitializer

- (id)initWithDocument:(SPDatabaseDocument *)document;

- (void)loadNib;
- (void)registerForNotifications;
- (void)setUpFavoritesOutlineView;
- (void)setUpSelectedConnectionFavorite;

@end
