//
//  $Id: SPConnectionController.h 802 2009-06-03 20:46:57Z stuart02 $
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

#import <Cocoa/Cocoa.h>
#import <MCPKit/MCPKit.h>

#import "TableDocument.h"
#import "KeyChain.h"
#import "SPSSHTunnel.h"

enum spconnection_types
{
	SP_CONNECTION_TCPIP = 0,
	SP_CONNECTION_SOCKET = 1,
	SP_CONNECTION_SSHTUNNEL = 2
};

@interface SPConnectionController : NSObject {
	TableDocument *tableDocument;
	NSWindow *documentWindow;
	NSSplitView *contentView;
	KeyChain *keychain;
	NSUserDefaults *prefs;
	NSMutableArray *favorites;
	SPSSHTunnel *sshTunnel;
	MCPConnection *mySQLConnection;
	BOOL automaticFavoriteSelection;

	int previousType;
	int type;
	NSString *name;
	NSString *host;
	NSString *user;
	NSString *password;
	NSString *database;
	NSString *socket;
	NSString *port;
	NSString *sshHost;
	NSString *sshUser;
	NSString *sshPassword;
	NSString *sshPort;

	NSString *connectionKeychainItemName;
	NSString *connectionKeychainItemAccount;
	NSString *connectionSSHKeychainItemName;
	NSString *connectionSSHKeychainItemAccount;

	IBOutlet NSView *connectionView;
	IBOutlet NSSplitView *connectionSplitView;
	IBOutlet NSTableView *favoritesTable;
	
	IBOutlet NSWindow *errorDetailWindow;
	IBOutlet NSTextView *errorDetailText;
	
	IBOutlet NSView *connectionResizeContainer;
	IBOutlet NSView *standardConnectionFormContainer;
	IBOutlet NSView *socketConnectionFormContainer;
	IBOutlet NSView *sshConnectionFormContainer;
	
	IBOutlet NSTextField *standardSQLHostField;
	IBOutlet NSTextField *sshSQLHostField;
	IBOutlet NSSecureTextField *standardPasswordField;
	IBOutlet NSSecureTextField *socketPasswordField;
	IBOutlet NSSecureTextField *sshPasswordField;
	IBOutlet NSSecureTextField *sshSSHPasswordField;
	
	IBOutlet NSButton *addToFavoritesButton;
	IBOutlet NSButton *connectButton;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSTextField *progressIndicatorText;
}

@property (readwrite, assign) int type;
@property (readwrite, retain) NSString *name;
@property (readwrite, retain) NSString *host;
@property (readwrite, retain) NSString *user;
@property (readwrite, retain) NSString *password;
@property (readwrite, retain) NSString *database;
@property (readwrite, retain) NSString *socket;
@property (readwrite, retain) NSString *port;
@property (readwrite, retain) NSString *sshHost;
@property (readwrite, retain) NSString *sshUser;
@property (readwrite, retain) NSString *sshPassword;
@property (readwrite, retain) NSString *sshPort;

- (id) initWithDocument:(TableDocument *)theTableDocument;

// Connection processes
- (IBAction)initiateConnection:(id)sender;
- (void)initiateSSHTunnelConnection;
- (void)sshTunnelCallback:(SPSSHTunnel *)theTunnel;
- (void)initiateMySQLConnection;
- (void)failConnectionWithTitle:(NSString *)theTitle errorMessage:(NSString *)theErrorMessage detail:(NSString *)errorDetail;
- (void)errorSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo;
- (void) addConnectionToDocument;

// Interface interaction
- (IBAction) editFavorites:(id)sender;
- (IBAction) showHelp:(id)sender;
- (void) resizeTabViewToConnectionType:(unsigned int)theType animating:(BOOL)animate;

// Connection details interaction
- (BOOL) checkHost;

// Favorites interaction
- (void) updateFavorites;
- (void) updateFavoriteSelection:(id)sender;
- (id) selectedFavorite;
- (IBAction) addFavorite:(id)sender;

- (void) splitViewDidResizeSubviews:(NSNotification *)aNotification;

@end


@interface SPFlippedView: NSView
{
}
- (BOOL)isFlipped;
@end
