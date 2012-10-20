//
//  $Id$
//
//  SPConnectionHandler.m
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
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPConnectionController.h"
#import "SPConnectionHandler.h"
#import "SPDatabaseDocument.h"

#ifndef SP_REFACTOR /* headers */
#import "SPAppController.h"
#import "SPPreferenceController.h"
#import "ImageAndTextCell.h"
#import "RegexKitLite.h"
#endif
#import "SPAlertSheets.h"
#import "SPKeychain.h"
#import "SPSSHTunnel.h"
#import "SPTableTextFieldCell.h"
#import "SPFavoritesController.h"
#import "SPFavoriteNode.h"
#import "SPGeneralPreferencePane.h"
#import "SPDatabaseViewController.h"
#import "SPTreeNode.h"
#import "SPFavoritesExporter.h"
#import "SPFavoritesImporter.h"
#import "SPThreadAdditions.h"

#import <SPMySQL/SPMySQL.h>

// Constants
static NSString *SPRemoveNode              = @"RemoveNode";
static NSString *SPImportFavorites         = @"ImportFavorites";
static NSString *SPExportFavorites         = @"ExportFavorites";
static NSString *SPExportFavoritesFilename = @"SequelProFavorites.plist";

@interface NSSavePanel (NSSavePanel_unpublishedUntilSnowLeopardAPI)

- (void)setShowsHiddenFiles:(BOOL)flag;

@end

@interface SPConnectionController ()

// Privately redeclare as read/write to get the synthesized setter
@property (readwrite, assign) BOOL isEditingConnection;

- (void)_saveCurrentDetailsCreatingNewFavorite:(BOOL)createNewFavorite validateDetails:(BOOL)validateDetails;
- (BOOL)_checkHost;
#ifndef SP_REFACTOR
- (void)_sortFavorites;
- (void)_sortTreeNode:(SPTreeNode *)node usingKey:(NSString *)key;
- (void)_favoriteTypeDidChange;
- (void)_reloadFavoritesViewData;
- (void)_updateFavoriteFirstResponder;
- (void)_restoreConnectionInterface;
- (void)_selectNode:(SPTreeNode *)node;
- (void)_scrollToSelectedNode;
- (void)_removeNode:(SPTreeNode *)node;
- (void)_removeAllPasswordsForNode:(SPTreeNode *)node;

- (NSNumber *)_createNewFavoriteID;
- (SPTreeNode *)_favoriteNodeForFavoriteID:(NSInteger)favoriteID;
- (NSString *)_stripInvalidCharactersFromString:(NSString *)subject;

- (NSString *)_generateNameForConnection;

- (void)_startEditingConnection;

- (void)_documentWillClose:(NSNotification *)notification;

static NSComparisonResult _compareFavoritesUsingKey(id favorite1, id favorite2, void *key);
#endif

@end

@interface SPConnectionController (SPConnectionControllerDelegate)

- (void)_stopEditingConnection;

@end


@implementation SPConnectionController

@synthesize delegate;
@synthesize type;
@synthesize name;
@synthesize host;
@synthesize user;
@synthesize password;
@synthesize database;
@synthesize socket;
@synthesize port;
@synthesize useSSL;
@synthesize sslKeyFileLocationEnabled;
@synthesize sslKeyFileLocation;
@synthesize sslCertificateFileLocationEnabled;
@synthesize sslCertificateFileLocation;
@synthesize sslCACertFileLocationEnabled;
@synthesize sslCACertFileLocation;
@synthesize sshHost;
@synthesize sshUser;
@synthesize sshPassword;
@synthesize sshKeyLocationEnabled;
@synthesize sshKeyLocation;
@synthesize sshPort;

#ifdef SP_REFACTOR
@synthesize dbDocument;
#endif

@synthesize connectionKeychainItemName;
@synthesize connectionKeychainItemAccount;
@synthesize connectionSSHKeychainItemName;
@synthesize connectionSSHKeychainItemAccount;

@synthesize isConnecting;
@synthesize isEditingConnection;

#pragma mark -
#pragma mark Connection processes

/**
 * Starts the connection process; invoked when user hits the connect button
 * or double-clicks on a favourite.
 * Error-checks fields as required, and triggers connection of MySQL or any
 * connection proxies in use.
 */
- (IBAction)initiateConnection:(id)sender
{
	// If this action was triggered via a double-click on the favorites outline view,
	// ensure that one of the connections was double-clicked, not the area above or below
#ifndef SP_REFACTOR
	if (sender == favoritesOutlineView && [favoritesOutlineView clickedRow] <= 0) return;
#endif

	// If triggered via the "Test Connection" button, set the state - otherwise clear it
	isTestingConnection = (sender == testConnectButton);

	// Ensure that host is not empty if this is a TCP/IP or SSH connection
	if (([self type] == SPTCPIPConnection || [self type] == SPSSHTunnelConnection) && ![[self host] length]) {
		SPBeginAlertSheet(NSLocalizedString(@"Insufficient connection details", @"insufficient details message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [dbDocument parentWindow], self, nil, nil, NSLocalizedString(@"Insufficient details provided to establish a connection. Please enter at least the hostname.", @"insufficient details informative message"));		
		return;
	}
	
	// If SSH is enabled, ensure that the SSH host is not nil
	if ([self type] == SPSSHTunnelConnection && ![[self sshHost] length]) {
		SPBeginAlertSheet(NSLocalizedString(@"Insufficient connection details", @"insufficient details message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [dbDocument parentWindow], self, nil, nil, NSLocalizedString(@"Insufficient details provided to establish a connection. Please enter the hostname for the SSH Tunnel, or disable the SSH Tunnel.", @"insufficient SSH tunnel details informative message"));
		return;
	}

	// If an SSH key has been provided, verify it exists
	if ([self type] == SPSSHTunnelConnection && sshKeyLocationEnabled && sshKeyLocation) {
		if (![[NSFileManager defaultManager] fileExistsAtPath:[sshKeyLocation stringByExpandingTildeInPath]]) {
			[self setSshKeyLocationEnabled:NSOffState];
			SPBeginAlertSheet(NSLocalizedString(@"SSH Key not found", @"SSH key check error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [dbDocument parentWindow], self, nil, nil, NSLocalizedString(@"A SSH key location was specified, but no file was found in the specified location.  Please re-select the key and try again.", @"SSH key not found message"));
			return;
		}
	}

	// Ensure that a socket connection is not inadvertently used
	if (![self _checkHost]) return;

	// If SSL keys have been supplied, verify they exist
	if (([self type] == SPTCPIPConnection || [self type] == SPSocketConnection) && [self useSSL]) {
		
		if (sslKeyFileLocationEnabled && sslKeyFileLocation && 
			![[NSFileManager defaultManager] fileExistsAtPath:[sslKeyFileLocation stringByExpandingTildeInPath]])
		{
			[self setSslKeyFileLocationEnabled:NSOffState];
			[self setSslKeyFileLocation:nil];
			
			SPBeginAlertSheet(NSLocalizedString(@"SSL Key File not found", @"SSL key file check error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [dbDocument parentWindow], self, nil, nil, NSLocalizedString(@"A SSL key file location was specified, but no file was found in the specified location.  Please re-select the key file and try again.", @"SSL key file not found message"));
			
			return;
		}
		
		if (sslCertificateFileLocationEnabled && sslCertificateFileLocation && 
			![[NSFileManager defaultManager] fileExistsAtPath:[sslCertificateFileLocation stringByExpandingTildeInPath]])
		{
			[self setSslCertificateFileLocationEnabled:NSOffState];
			[self setSslCertificateFileLocation:nil];
			
			SPBeginAlertSheet(NSLocalizedString(@"SSL Certificate File not found", @"SSL certificate file check error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [dbDocument parentWindow], self, nil, nil, NSLocalizedString(@"A SSL certificate location was specified, but no file was found in the specified location.  Please re-select the certificate and try again.", @"SSL certificate file not found message"));
			
			return;
		}
		
		if (sslCACertFileLocationEnabled && sslCACertFileLocation && 
			![[NSFileManager defaultManager] fileExistsAtPath:[sslCACertFileLocation stringByExpandingTildeInPath]])
		{
			[self setSslCACertFileLocationEnabled:NSOffState];
			[self setSslCACertFileLocation:nil];
			
			SPBeginAlertSheet(NSLocalizedString(@"SSL Certificate Authority File not found", @"SSL certificate authority file check error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [dbDocument parentWindow], self, nil, nil, NSLocalizedString(@"A SSL Certificate Authority certificate location was specified, but no file was found in the specified location.  Please re-select the Certificate Authority certificate and try again.", @"SSL CA certificate file not found message"));
			
			return;
		}
	}

	// Basic details have validated - start the connection process animating
	isConnecting = YES;
	cancellingConnection = NO;
	
#ifndef SP_REFACTOR
	// Disable the favorites outline view to prevent further connections attempts
	[favoritesOutlineView setEnabled:NO];
	
	[helpButton setHidden:YES];
	[connectButton setEnabled:NO];
	[testConnectButton setEnabled:NO];
	[progressIndicator startAnimation:self];
	[progressIndicatorText setHidden:NO];
#endif
	
	// Start the current tab's progress indicator
	[dbDocument setIsProcessing:YES];

	// If the password(s) are marked as having been originally sourced from a keychain, check whether they
	// have been changed or not; if not, leave the mark in place and remove the password from the field
	// for increased security.
#ifndef SP_REFACTOR
	if (connectionKeychainItemName && !isTestingConnection) {
		if ([[keychain getPasswordForName:connectionKeychainItemName account:connectionKeychainItemAccount] isEqualToString:[self password]]) {
			[self setPassword:[[NSString string] stringByPaddingToLength:[[self password] length] withString:@"sp" startingAtIndex:0]];
			
			[[standardPasswordField undoManager] removeAllActionsWithTarget:standardPasswordField];
			[[socketPasswordField undoManager] removeAllActionsWithTarget:socketPasswordField];
			[[sshPasswordField undoManager] removeAllActionsWithTarget:sshPasswordField];
		} 
		else {
			[connectionKeychainItemName release], connectionKeychainItemName = nil;
			[connectionKeychainItemAccount release], connectionKeychainItemAccount = nil;
		}
	}
	
	if (connectionSSHKeychainItemName && !isTestingConnection) {
		if ([[keychain getPasswordForName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount] isEqualToString:[self sshPassword]]) {
			[self setSshPassword:[[NSString string] stringByPaddingToLength:[[self sshPassword] length] withString:@"sp" startingAtIndex:0]];
			[[sshSSHPasswordField undoManager] removeAllActionsWithTarget:sshSSHPasswordField];
		} 
		else {
			[connectionSSHKeychainItemName release], connectionSSHKeychainItemName = nil;
			[connectionSSHKeychainItemAccount release], connectionSSHKeychainItemAccount = nil;
		}
	}
#endif
	
	// Inform the delegate that we are starting the connection process
	if (delegate && [delegate respondsToSelector:@selector(connectionControllerInitiatingConnection:)]) {
		[delegate connectionControllerInitiatingConnection:self];
	}
	
	// Trim whitespace and newlines from the host field before attempting to connect
	[self setHost:[[self host] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
	
	// Initiate the SSH connection process for tunnels
	if ([self type] == SPSSHTunnelConnection) {
		[self performSelector:@selector(initiateSSHTunnelConnection) withObject:nil afterDelay:0.0];
		
		return;
	}
	
	// ...or start the MySQL connection process directly	
	[self performSelector:@selector(initiateMySQLConnection) withObject:nil afterDelay:0.0];
}

/**
 * Cancels the current connection - both SSH and MySQL.
 */
- (IBAction)cancelConnection:(id)sender
{
#ifndef SP_REFACTOR
	[connectButton setEnabled:NO];
	
	[progressIndicatorText setStringValue:NSLocalizedString(@"Cancelling...", @"cancelling task status message")];
	[progressIndicatorText display];
#endif

	cancellingConnection = YES;

	// Cancel the MySQL connection - handing it off to a background thread - if one is present
	if (mySQLConnection) {
		[mySQLConnection setDelegate:nil];
		[NSThread detachNewThreadWithName:@"SPConnectionController cancellation background disconnect" target:mySQLConnection selector:@selector(disconnect) object:nil];
		[mySQLConnection autorelease];
		mySQLConnection = nil;
	}

	// Cancel the SSH tunnel if present
	if (sshTunnel) {
		[sshTunnel disconnect];
		[sshTunnel release];
		sshTunnel = nil;
	}

#ifndef SP_REFACTOR
	// Restore the connection interface
	[self _restoreConnectionInterface];
#endif
}

#pragma mark -
#pragma mark Interface interaction

/**
 * Registered to be the double click action of the favorites outline view.
 */
- (IBAction)nodeDoubleClicked:(id)sender
{
#ifndef SP_REFACTOR
	SPTreeNode *node = [self selectedFavoriteNode];
	
	if (node) {
		if (node == quickConnectItem) {
			return;
		}

		// Only proceed to initiate a connection if a leaf node (i.e. a favorite and not a group) was double clicked.
		if (![node isGroup]) {
			[self initiateConnection:self];
		}

		// Otherwise start editing the group node's name
		else {
			[favoritesOutlineView editColumn:0 row:[favoritesOutlineView selectedRow] withEvent:nil select:YES];
		}
	}
#endif
}

/**
 * Opens the SSH/SSL key selection window, ready to select a key file.
 */
- (IBAction)chooseKeyLocation:(NSButton *)sender
{
	NSString *directoryPath = nil;
	NSString *filePath = nil;
	NSArray *permittedFileTypes = nil;
	keySelectionPanel = [NSOpenPanel openPanel];
	[keySelectionPanel setShowsHiddenFiles:[prefs boolForKey:SPHiddenKeyFileVisibilityKey]];

	// If the button was toggled off, ensure editing is ended
	if ([sender state] == NSOffState) {
		[self _startEditingConnection];
	}

	// Switch details by sender.
	// First, SSH keys:
	if (sender == sshSSHKeyButton) {

		// If the custom key location is currently disabled - after the button
		// action - leave it disabled and return without showing the sheet.
		if (!sshKeyLocationEnabled) {
			return;
		}

		// Otherwise open a panel at the last or default location
		if (sshKeyLocation && [sshKeyLocation length]) {
			filePath = [sshKeyLocation lastPathComponent];
			directoryPath = [sshKeyLocation stringByDeletingLastPathComponent];
		}

		permittedFileTypes = [NSArray arrayWithObjects:@"pem", @"", nil];
		
		[keySelectionPanel setAccessoryView:sshKeyLocationHelp];
	}
	// SSL key file location:
	else if (sender == standardSSLKeyFileButton || sender == socketSSLKeyFileButton) {
		if ([sender state] == NSOffState) {
			[self setSslKeyFileLocation:nil];
			return;
		}
		
		permittedFileTypes = [NSArray arrayWithObjects:@"pem", @"key", @"", nil];
		
		[keySelectionPanel setAccessoryView:sslKeyFileLocationHelp];
	}
	// SSL certificate file location:
	else if (sender == standardSSLCertificateButton || sender == socketSSLCertificateButton) {
		if ([sender state] == NSOffState) {
			[self setSslCertificateFileLocation:nil];
			return;
		}
		
		permittedFileTypes = [NSArray arrayWithObjects:@"pem", @"cert", @"crt", @"", nil];
		
		[keySelectionPanel setAccessoryView:sslCertificateLocationHelp];
	}
	// SSL CA certificate file location:
	else if (sender == standardSSLCACertButton || sender == socketSSLCACertButton) {
		if ([sender state] == NSOffState) {
			[self setSslCACertFileLocation:nil];
			return;
		}
		
		permittedFileTypes = [NSArray arrayWithObjects:@"pem", @"cert", @"crt", @"", nil];
		
		[keySelectionPanel setAccessoryView:sslCACertLocationHelp];
	}

	[keySelectionPanel beginSheetForDirectory:directoryPath
								 file:filePath
								types:permittedFileTypes
					   modalForWindow:[dbDocument parentWindow]
						modalDelegate:self
					   didEndSelector:@selector(chooseKeyLocationSheetDidEnd:returnCode:contextInfo:)
						  contextInfo:sender];
}

/**
 * Show connection help webpage.
 */
- (IBAction)showHelp:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:SPLOCALIZEDURL_CONNECTIONHELP]];
}

/**
 * Resize parts of the interface to reflect SSL status.
 */
- (IBAction)updateSSLInterface:(id)sender
{
	[self resizeTabViewToConnectionType:[self type] animating:YES];
	[self _startEditingConnection];
}

/**
 * Toggle hidden file visiblity in response to accessory view changes
 */
- (IBAction)updateKeyLocationFileVisibility:(id)sender
{
	[keySelectionPanel setShowsHiddenFiles:[prefs boolForKey:SPHiddenKeyFileVisibilityKey]];
}

/**
 * Update the interface in response to external split view size changes.
 */
- (void)updateSplitViewSize
{
	if ([dbDocument getConnection]) {
		return;
	}

	[connectionSplitView setDelegate:nil];
	[connectionSplitView setPosition:[[[databaseConnectionView subviews] objectAtIndex:0] frame].size.width ofDividerAtIndex:0];
	[connectionSplitView setDelegate:self];
}

#pragma mark -
#pragma mark Connection details interaction and display

/**
 * Control tab view resizing based on the supplied connection type,
 * with an option defining whether it should be animated or not.
 */
- (void)resizeTabViewToConnectionType:(NSUInteger)theType animating:(BOOL)animate
{
	NSRect frameRect, targetResizeRect;

	// Use a magic number which needs to be added to the form when calculating resizes -
	// including the height of the button areas below.
	NSInteger additionalFormHeight = 92;

	frameRect = [connectionResizeContainer frame];

	switch (theType) {
		case SPTCPIPConnection:
			targetResizeRect = [standardConnectionFormContainer frame];
			if ([self useSSL]) additionalFormHeight += [standardConnectionSSLDetailsContainer frame].size.height;
			break;
		case SPSocketConnection:
			targetResizeRect = [socketConnectionFormContainer frame];
			if ([self useSSL]) additionalFormHeight += [socketConnectionSSLDetailsContainer frame].size.height;
			break;
		case SPSSHTunnelConnection:
			targetResizeRect = [sshConnectionFormContainer frame];
			break;
	} 

	frameRect.size.height = targetResizeRect.size.height + additionalFormHeight;

	if (animate && initComplete) {
		[[connectionResizeContainer animator] setFrame:frameRect];
	} 
	else {
		[connectionResizeContainer setFrame:frameRect];	
	}
}

#pragma mark -
#pragma mark Favorites interaction

/**
 * Sorts the favorites table view based on the selected sort by item.
 */
- (void)sortFavorites:(id)sender
{	
#ifndef SP_REFACTOR
    SPFavoritesSortItem previousSortItem = currentSortItem;
	currentSortItem  = (SPFavoritesSortItem)[[sender menu] indexOfItem:sender];
	
	[prefs setInteger:currentSortItem forKey:SPFavoritesSortedBy];
	
	// Perform sorting
	[self _sortFavorites];
	
	if (previousSortItem > SPFavoritesSortUnsorted) [[[sender menu] itemAtIndex:previousSortItem] setState:NSOffState];
	
	[[[sender menu] itemAtIndex:currentSortItem] setState:NSOnState];
#endif
}

/**
 * Reverses the favorites table view sorting based on the selected criteria.
 */
- (void)reverseSortFavorites:(NSMenuItem *)sender
{
#ifndef SP_REFACTOR
    reverseFavoritesSort = (![sender state]);
    
	[prefs setBool:reverseFavoritesSort forKey:SPFavoritesSortedInReverse];
	
	// Perform re-sorting
	[self _sortFavorites];
	
	[(NSMenuItem *)sender setState:reverseFavoritesSort]; 
#endif
}

/**
 * Sets fields for the chosen favorite.
 */
- (void)updateFavoriteSelection:(id)sender
{
#ifndef SP_REFACTOR

	// Clear the keychain referral items as appropriate
	if (connectionKeychainID) [connectionKeychainID release], connectionKeychainID = nil;
	if (connectionKeychainItemName) [connectionKeychainItemName release], connectionKeychainItemName = nil;
	if (connectionKeychainItemAccount) [connectionKeychainItemAccount release], connectionKeychainItemAccount = nil;
	if (connectionSSHKeychainItemName) [connectionSSHKeychainItemName release], connectionSSHKeychainItemName = nil;
	if (connectionSSHKeychainItemAccount) [connectionSSHKeychainItemAccount release], connectionSSHKeychainItemAccount = nil;
	
	SPTreeNode *node = [self selectedFavoriteNode];
	if ([node isGroup]) node = nil;
	
	// Update key-value properties from the selected favourite, using empty strings where not found
	NSDictionary *fav = [[node representedObject] nodeFavorite];
	
	// Keep a copy of the favorite as it currently stands
	if (currentFavorite) [currentFavorite release], currentFavorite = nil;
	currentFavorite = [fav copy];
	
	[connectionResizeContainer setHidden:NO];
	[self _stopEditingConnection];

	// Set up the type, also storing it in the previous type store to prevent type "changes" triggering actions
	NSUInteger connectionType = ([fav objectForKey:SPFavoriteTypeKey] ? [[fav objectForKey:SPFavoriteTypeKey] integerValue] : SPTCPIPConnection);
	previousType = connectionType;
	[self setType:connectionType];

	// Standard details
	[self setName:([fav objectForKey:SPFavoriteNameKey] ? [fav objectForKey:SPFavoriteNameKey] : @"")];
	[self setHost:([fav objectForKey:SPFavoriteHostKey] ? [fav objectForKey:SPFavoriteHostKey] : @"")];
	[self setSocket:([fav objectForKey:SPFavoriteSocketKey] ? [fav objectForKey:SPFavoriteSocketKey] : @"")];
	[self setUser:([fav objectForKey:SPFavoriteUserKey] ? [fav objectForKey:SPFavoriteUserKey] : @"")];
	[self setPort:([fav objectForKey:SPFavoritePortKey] ? [fav objectForKey:SPFavoritePortKey] : @"")];
	[self setDatabase:([fav objectForKey:SPFavoriteDatabaseKey] ? [fav objectForKey:SPFavoriteDatabaseKey] : @"")];
	
	// SSL details
	[self setUseSSL:([fav objectForKey:SPFavoriteUseSSLKey] ? [[fav objectForKey:SPFavoriteUseSSLKey] intValue] : NSOffState)];
	[self setSslKeyFileLocationEnabled:([fav objectForKey:SPFavoriteSSLKeyFileLocationEnabledKey] ? [[fav objectForKey:SPFavoriteSSLKeyFileLocationEnabledKey] intValue] : NSOffState)];
	[self setSslKeyFileLocation:([fav objectForKey:SPFavoriteSSLKeyFileLocationKey] ? [fav objectForKey:SPFavoriteSSLKeyFileLocationKey] : @"")];
	[self setSslCertificateFileLocationEnabled:([fav objectForKey:SPFavoriteSSLCertificateFileLocationEnabledKey] ? [[fav objectForKey:SPFavoriteSSLCertificateFileLocationEnabledKey] intValue] : NSOffState)];
	[self setSslCertificateFileLocation:([fav objectForKey:SPFavoriteSSLCertificateFileLocationKey] ? [fav objectForKey:SPFavoriteSSLCertificateFileLocationKey] : @"")];
	[self setSslCACertFileLocationEnabled:([fav objectForKey:SPFavoriteSSLCACertFileLocationEnabledKey] ? [[fav objectForKey:SPFavoriteSSLCACertFileLocationEnabledKey] intValue] : NSOffState)];
	[self setSslCACertFileLocation:([fav objectForKey:SPFavoriteSSLCACertFileLocationKey] ? [fav objectForKey:SPFavoriteSSLCACertFileLocationKey] : @"")];
	
	// SSH details
	[self setSshHost:([fav objectForKey:SPFavoriteSSHHostKey] ? [fav objectForKey:SPFavoriteSSHHostKey] : @"")];
	[self setSshUser:([fav objectForKey:SPFavoriteSSHUserKey] ? [fav objectForKey:SPFavoriteSSHUserKey] : @"")];
	[self setSshKeyLocationEnabled:([fav objectForKey:SPFavoriteSSHKeyLocationEnabledKey] ? [[fav objectForKey:SPFavoriteSSHKeyLocationEnabledKey] intValue] : NSOffState)];
	[self setSshKeyLocation:([fav objectForKey:SPFavoriteSSHKeyLocationKey] ? [fav objectForKey:SPFavoriteSSHKeyLocationKey] : @"")];
	[self setSshPort:([fav objectForKey:SPFavoriteSSHPortKey] ? [fav objectForKey:SPFavoriteSSHPortKey] : @"")];
	
	// Trigger an interface update
	[self resizeTabViewToConnectionType:[self type] animating:(sender == self)];
	
	// Check whether the password exists in the keychain, and if so add it; also record the
	// keychain details so we can pass around only those details if the password doesn't change
	connectionKeychainItemName = [[keychain nameForFavoriteName:[fav objectForKey:SPFavoriteNameKey] id:[fav objectForKey:SPFavoriteIDKey]] retain];
	connectionKeychainItemAccount = [[keychain accountForUser:[fav objectForKey:SPFavoriteUserKey] host:(([self type] == SPSocketConnection) ? @"localhost" : [fav objectForKey:SPFavoriteHostKey]) database:[fav objectForKey:SPFavoriteDatabaseKey]] retain];
	
	[self setPassword:[keychain getPasswordForName:connectionKeychainItemName account:connectionKeychainItemAccount]];
	
	if (![[self password] length]) {
		[self setPassword:nil];
		[connectionKeychainItemName release], connectionKeychainItemName = nil;
		[connectionKeychainItemAccount release], connectionKeychainItemAccount = nil;
	}

	// Store the selected favorite ID for use with the document on connection
	if ([fav objectForKey:SPFavoriteIDKey]) connectionKeychainID = [[[fav objectForKey:SPFavoriteIDKey] stringValue] retain];

	// And the same for the SSH password
	connectionSSHKeychainItemName = [[keychain nameForSSHForFavoriteName:[fav objectForKey:SPFavoriteNameKey] id:[fav objectForKey:SPFavoriteIDKey]] retain];
	connectionSSHKeychainItemAccount = [[keychain accountForSSHUser:[fav objectForKey:SPFavoriteSSHUserKey] sshHost:[fav objectForKey:SPFavoriteSSHHostKey]] retain];
	
	[self setSshPassword:[keychain getPasswordForName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount]];
	
	if (![[self sshPassword] length]) {
		[self setSshPassword:nil];
		[connectionSSHKeychainItemName release], connectionSSHKeychainItemName = nil;
		[connectionSSHKeychainItemAccount release], connectionSSHKeychainItemAccount = nil;
	}
	
	[prefs setInteger:[[fav objectForKey:SPFavoriteIDKey] integerValue] forKey:SPLastFavoriteID];
	
	// Set first responder to password field if it is empty
	[self performSelector:@selector(_updateFavoriteFirstResponder) withObject:nil afterDelay:0.0];
#endif
}

/**
 * Returns the selected favorite data dictionary or nil if nothing is selected.
 */
#ifndef SP_REFACTOR
- (NSMutableDictionary *)selectedFavorite
{
	SPTreeNode *node = [self selectedFavoriteNode];
	
	return (![node isGroup]) ? [[node representedObject] nodeFavorite] : nil;
}

/**
 * Returns the selected favorite node or nil if nothing is selected.
 */
- (SPTreeNode *)selectedFavoriteNode
{
	NSArray *nodes = [self selectedFavoriteNodes];
	
	return ([nodes count]) ? (SPTreeNode *)[nodes objectAtIndex:0] : nil;
}

/**
 * Returns an array of selected favorite nodes.
 */
- (NSArray *)selectedFavoriteNodes
{
	NSMutableArray *nodes = [NSMutableArray array];
	NSIndexSet *indexes = [favoritesOutlineView selectedRowIndexes];

	NSUInteger currentIndex = [indexes firstIndex];
	
	while (currentIndex != NSNotFound)
	{
		[nodes addObject:[favoritesOutlineView itemAtRow:currentIndex]];
		
		currentIndex = [indexes indexGreaterThanIndex:currentIndex];
	}
	
	return nodes;
}

/**
 * Saves the current connection favorite.
 */
- (IBAction)saveFavorite:(id)sender
{
	[self _saveCurrentDetailsCreatingNewFavorite:NO validateDetails:YES];
}

/**
 * Adds a new connection favorite.
 */
- (IBAction)addFavorite:(id)sender
{
	NSNumber *favoriteID = [self _createNewFavoriteID];
	
	NSArray *objects = [NSArray arrayWithObjects:NSLocalizedString(@"New Favorite", @"new favorite name"), 
						[NSNumber numberWithInteger:0], @"", @"", @"", @"", 
						[NSNumber numberWithInt:NSOffState], 
						[NSNumber numberWithInt:NSOffState], 
						[NSNumber numberWithInt:NSOffState], 
						[NSNumber numberWithInt:NSOffState], @"", @"", @"", 
						[NSNumber numberWithInt:NSOffState], @"", @"", favoriteID, nil];
	
	NSArray *keys = [NSArray arrayWithObjects:
					 SPFavoriteNameKey, 
					 SPFavoriteTypeKey, 
					 SPFavoriteHostKey, 
					 SPFavoriteSocketKey, 
					 SPFavoriteUserKey, 
					 SPFavoritePortKey, 
					 SPFavoriteUseSSLKey, 
					 SPFavoriteSSLKeyFileLocationEnabledKey,
					 SPFavoriteSSLCertificateFileLocationEnabledKey, 
					 SPFavoriteSSLCACertFileLocationEnabledKey, 
					 SPFavoriteDatabaseKey, 
					 SPFavoriteSSHHostKey, 
					 SPFavoriteSSHUserKey, 
					 SPFavoriteSSHKeyLocationEnabledKey, 
					 SPFavoriteSSHKeyLocationKey, 
					 SPFavoriteSSHPortKey, 
					 SPFavoriteIDKey,
					 nil];
	
    // Create default favorite
    NSMutableDictionary *favorite = [NSMutableDictionary dictionaryWithObjects:objects forKeys:keys];
				
	SPTreeNode *selectedNode = [self selectedFavoriteNode];
	
	SPTreeNode *parent = ([selectedNode isGroup] && selectedNode != quickConnectItem) ? selectedNode : (SPTreeNode *)[selectedNode parentNode];

	// Ensure the parent is expanded
	[favoritesOutlineView expandItem:parent];
	
	SPTreeNode *node = [favoritesController addFavoriteNodeWithData:favorite asChildOfNode:parent];
	
	[self _sortFavorites];
    [self _selectNode:node];
	
    [[[[NSApp delegate] preferenceController] generalPreferencePane] updateDefaultFavoritePopup];

	favoriteNameFieldWasAutogenerated = YES;
		
	[favoritesOutlineView editColumn:0 row:[favoritesOutlineView selectedRow] withEvent:nil select:YES];
}

/**
 * Adds the current details as a new connection favorite, selects it, and scrolls the selected
 * row to be visible.
 */
- (IBAction)addFavoriteUsingCurrentDetails:(id)sender
{
	[self _saveCurrentDetailsCreatingNewFavorite:YES validateDetails:YES];
}

/**
 * Adds a new group node to the favorites tree with a default name. Once added it is selected for editing.
 */
- (IBAction)addGroup:(id)sender
{
	SPTreeNode *selectedNode = [self selectedFavoriteNode];
	
	SPTreeNode *parent = ([selectedNode isGroup]) ? selectedNode : (SPTreeNode *)[selectedNode parentNode];

	// Ensure the parent is expanded
	[favoritesOutlineView expandItem:parent];

	SPTreeNode *node = [favoritesController addGroupNodeWithName:NSLocalizedString(@"New Folder", @"new folder placeholder name") asChildOfNode:parent];
	
	[self _reloadFavoritesViewData];
	[self _selectNode:node];

	[favoritesOutlineView editColumn:0 row:[favoritesOutlineView selectedRow] withEvent:nil select:YES];
}

/**
 * Removes the selected node.
 */
- (IBAction)removeNode:(id)sender
{
	if ([favoritesOutlineView numberOfSelectedRows] == 1) {
		
		BOOL suppressWarning = NO;
		SPTreeNode *node = [self selectedFavoriteNode];
				
		NSString *message = @"";
		NSString *informativeMessage = @"";
		
		if (![node isGroup]) {
			message            = [NSString stringWithFormat:NSLocalizedString(@"Delete favorite '%@'?", @"delete database message"), [[[node representedObject] nodeFavorite] objectForKey:SPFavoriteNameKey]];
			informativeMessage = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the favorite '%@'? This operation cannot be undone.", @"delete database informative message"), [[[node representedObject] nodeFavorite] objectForKey:SPFavoriteNameKey]];
		}
		else if ([[node childNodes] count] > 0) {
			message            = [NSString stringWithFormat:NSLocalizedString(@"Delete group '%@'?", @"delete database message"), [[node representedObject] nodeName]];
			informativeMessage = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the group '%@'? All groups and favorites within this group will also be deleted. This operation cannot be undone.", @"delete database informative message"), [[node representedObject] nodeName]];
		}
		else {
			suppressWarning = YES;
		}
		
		if (!suppressWarning) {
			NSAlert *alert = [NSAlert alertWithMessageText:message
											 defaultButton:NSLocalizedString(@"Delete", @"delete button") 
										   alternateButton:NSLocalizedString(@"Cancel", @"cancel button") 
											   otherButton:nil 
								 informativeTextWithFormat:informativeMessage];
			
			NSArray *buttons = [alert buttons];
			
			// Change the alert's cancel button to have the key equivalent of return
			[[buttons objectAtIndex:0] setKeyEquivalent:@"d"];
			[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
			[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
			
			[alert setAlertStyle:NSCriticalAlertStyle];
			
			[alert beginSheetModalForWindow:[dbDocument parentWindow] 
							  modalDelegate:self 
							 didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
								contextInfo:SPRemoveNode];
		}
		else{
			[self _removeNode:node];
		}
	}
}

/**
 * Duplicates the selected connection favorite.
 */
- (IBAction)duplicateFavorite:(id)sender
{
	if ([favoritesOutlineView numberOfSelectedRows] == 1) {
		
		NSMutableDictionary *favorite = [NSMutableDictionary dictionaryWithDictionary:[self selectedFavorite]];
		
		NSNumber *favoriteID = [self _createNewFavoriteID];
		
		NSInteger duplicatedFavoriteType = [[favorite objectForKey:SPFavoriteTypeKey] integerValue];
		
		// Update the unique ID
		[favorite setObject:favoriteID forKey:SPFavoriteIDKey];
		
		// Alter the name for clarity
		[favorite setObject:[NSString stringWithFormat:NSLocalizedString(@"%@ Copy", @"Initial favourite name after duplicating a previous favourite"), [favorite objectForKey:SPFavoriteNameKey]] forKey:SPFavoriteNameKey];
		
		// Create new keychain items if appropriate
		if (password && [password length]) {
			NSString *oldKeychainName = [keychain nameForFavoriteName:[[self selectedFavorite] objectForKey:SPFavoriteNameKey] id:[[self selectedFavorite] objectForKey:SPFavoriteIDKey]];
			NSString *newKeychainName = [keychain nameForFavoriteName:[favorite objectForKey:SPFavoriteNameKey] id:[favorite objectForKey:SPFavoriteIDKey]];

			NSString *keychainAccount = [keychain accountForUser:[favorite objectForKey:SPFavoriteUserKey] host:((duplicatedFavoriteType == SPSocketConnection) ? @"localhost" : [favorite objectForKey:SPFavoriteHostKey]) database:[favorite objectForKey:SPFavoriteDatabaseKey]];

			NSString *favoritePassword = [keychain getPasswordForName:oldKeychainName account:keychainAccount];

			[keychain addPassword:favoritePassword forName:newKeychainName account:keychainAccount];

			favoritePassword = nil;
		}
		
		if (sshPassword && [sshPassword length]) {
			NSString *oldKeychainSSHName = [keychain nameForSSHForFavoriteName:[[self selectedFavorite] objectForKey:SPFavoriteNameKey] id:[[self selectedFavorite] objectForKey:SPFavoriteIDKey]];
			NSString *newKeychainSSHName = [keychain nameForSSHForFavoriteName:[favorite objectForKey:SPFavoriteNameKey] id:[favorite objectForKey:SPFavoriteIDKey]];

			NSString *keychainSSHAccount = [keychain accountForSSHUser:[favorite objectForKey:SPFavoriteSSHUserKey] sshHost:[favorite objectForKey:SPFavoriteSSHHostKey]];

			NSString *favoriteSSHPassword = [keychain getPasswordForName:oldKeychainSSHName account:keychainSSHAccount];

			[keychain addPassword:favoriteSSHPassword forName:newKeychainSSHName account:keychainSSHAccount];

			favoriteSSHPassword = nil;
		}
		
		SPTreeNode *selectedNode = [self selectedFavoriteNode];
		
		SPTreeNode *parent = ([selectedNode isGroup]) ? selectedNode : (SPTreeNode *)[selectedNode parentNode];
		
		SPTreeNode *node = [favoritesController addFavoriteNodeWithData:favorite asChildOfNode:parent];
		
		[self _reloadFavoritesViewData];
		[self _selectNode:node];
		
		[[(SPPreferenceController *)[[NSApp delegate] preferenceController] generalPreferencePane] updateDefaultFavoritePopup];
	}
}

/**
 * Switches the selected favorite/group to editing mode so it can be renamed.
 */
- (IBAction)renameNode:(id)sender
{
	if ([favoritesOutlineView numberOfSelectedRows] == 1) {
		[favoritesOutlineView editColumn:0 row:[favoritesOutlineView selectedRow] withEvent:nil select:YES];
	}
}

/**
 * Marks the selected favorite as the default.
 */
- (IBAction)makeSelectedFavoriteDefault:(id)sender
{
	NSInteger favoriteID = [[[self selectedFavorite] objectForKey:SPFavoriteIDKey] integerValue];
	
	[prefs setInteger:favoriteID forKey:SPDefaultFavorite];
}
	
#pragma mark -
#pragma mark Import/export favorites

/**
 * Displays an open panel, allowing the user to import their favorites.
 */
- (IBAction)importFavorites:(id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	
	[openPanel beginSheetForDirectory:nil
								 file:nil
								types:[NSArray arrayWithObject:@"plist"]
					   modalForWindow:[dbDocument parentWindow]
						modalDelegate:self
					   didEndSelector:@selector(importExportFavoritesSheetDidEnd:returnCode:contextInfo:)
						  contextInfo:SPImportFavorites];
}

/**
 * Displays a save panel, allowing the user to export their favorites.
 */
- (IBAction)exportFavorites:(id)sender
{
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	
	NSString *fileName = [[self selectedFavoriteNodes] count] > 1 ? SPExportFavoritesFilename : [[[self selectedFavorite] objectForKey:SPFavoriteNameKey] stringByAppendingPathExtension:@"plist"];
	
	[savePanel setAccessoryView:exportPanelAccessoryView];
	
	[savePanel beginSheetForDirectory:nil
								 file:fileName
					   modalForWindow:[dbDocument parentWindow]
						modalDelegate:self
					   didEndSelector:@selector(importExportFavoritesSheetDidEnd:returnCode:contextInfo:)
						  contextInfo:SPExportFavorites];
}

#pragma mark -
#pragma mark Accessors

/**
 * Returns the main outline view instance.
 */
- (SPFavoritesOutlineView *)favoritesOutlineView
{
	return favoritesOutlineView;
}

#pragma mark -
#pragma mark Key Value Observing

/**
 * This method is called as part of Key Value Observing.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
}


#pragma mark -
#pragma mark Sheet methods

/**
 * Called when the user dismisses the remove node sheet.
 */
- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{	
	// Remove the current favorite/group node
	if ([contextInfo isEqualToString:SPRemoveNode]) {
		if (returnCode == NSAlertDefaultReturn) {
			[self _removeNode:[self selectedFavoriteNode]];
		}
	}	
}
#endif

/**
 * Called after closing the SSH/SSL key selection sheet.
 */
- (void)chooseKeyLocationSheetDidEnd:(NSOpenPanel *)openPanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	NSString *abbreviatedFileName = [[openPanel filename] stringByAbbreviatingWithTildeInPath];
	
	// SSH key file selection
	if (contextInfo == sshSSHKeyButton) {
		if (returnCode == NSCancelButton) {
			[self setSshKeyLocationEnabled:NSOffState];
			return;
		}
		
		[self setSshKeyLocation:abbreviatedFileName];
	} 
	// SSL key file selection
	else if (contextInfo == standardSSLKeyFileButton || contextInfo == socketSSLKeyFileButton) {
		if (returnCode == NSCancelButton) {
			[self setSslKeyFileLocationEnabled:NSOffState];
			[self setSslKeyFileLocation:nil];
			return;
		}
		
		[self setSslKeyFileLocation:abbreviatedFileName];
	}
	// SSL certificate file selection
	else if (contextInfo == standardSSLCertificateButton || contextInfo == socketSSLCertificateButton) {
		if (returnCode == NSCancelButton) {
			[self setSslCertificateFileLocationEnabled:NSOffState];
			[self setSslCertificateFileLocation:nil];
			return;
		}
		
		[self setSslCertificateFileLocation:abbreviatedFileName];
	} 
	// SSL CA certificate file selection
	else if (contextInfo == standardSSLCACertButton || contextInfo == socketSSLCACertButton) {
		if (returnCode == NSCancelButton) {
			[self setSslCACertFileLocationEnabled:NSOffState];
			[self setSslCACertFileLocation:nil];
			return;
		}
		
		[self setSslCACertFileLocation:abbreviatedFileName];
	}

	[self _startEditingConnection];
}

/**
 * Called when the user dismisses either the import of export favorites panels.
 */
#ifndef SP_REFACTOR

- (void)importExportFavoritesSheetDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{	
	if (returnCode == NSOKButton) {
		if (contextInfo == SPExportFavorites) {
			SPFavoritesExporter *exporter = [[[SPFavoritesExporter alloc] init] autorelease];
			
			[exporter setDelegate:self];
			
			[exporter writeFavorites:[self selectedFavoriteNodes] toFile:[panel filename]];
		}
		else if (contextInfo == SPImportFavorites) {
			SPFavoritesImporter *importer = [[SPFavoritesImporter alloc] init];
			
			[importer setDelegate:self];
			
			[importer importFavoritesFromFileAtPath:[panel filename]];
		}
	}
}

#endif

/**
 * Alert sheet callback method - invoked when the error sheet is closed.
 */
- (void)localhostErrorSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{	
	if (returnCode == NSAlertAlternateReturn) {
		[self setType:SPSocketConnection];
		[self setHost:@""];
	} 
	else {
		[self setHost:@"127.0.0.1"];
	}
}

#pragma mark -
#pragma mark Private API

/**
 * Take the current details and either save them to the currently selected
 * favourite, or create a new connection favourite using them.
 * If creating a new favourite, also select it and ensure the selected
 * favourite is visible.
 */
- (void)_saveCurrentDetailsCreatingNewFavorite:(BOOL)createNewFavorite validateDetails:(BOOL)validateDetails
{

	// Complete any active editing
	if ([[connectionView window] firstResponder]) {
		[[connectionView window] endEditingFor:[[connectionView window] firstResponder]];
	}


	// Ensure that host is not empty if this is a TCP/IP or SSH connection
	if (validateDetails && ([self type] == SPTCPIPConnection || [self type] == SPSSHTunnelConnection) && ![[self host] length]) {
		SPBeginAlertSheet(NSLocalizedString(@"Insufficient connection details", @"insufficient details message"), 
						  NSLocalizedString(@"OK", @"OK button"), nil, nil, [dbDocument parentWindow], nil, nil, nil,
						  NSLocalizedString(@"Insufficient details provided to establish a connection. Please provide at least a host.", @"insufficient details informative message"));		
		return;
	}
	
	// If SSH is enabled, ensure that the SSH host is not nil
	if (validateDetails && [self type] == SPSSHTunnelConnection && ![[self sshHost] length]) {
		SPBeginAlertSheet(NSLocalizedString(@"Insufficient connection details", @"insufficient details message"), 
						  NSLocalizedString(@"OK", @"OK button"), nil, nil, [dbDocument parentWindow], nil, nil, nil,
						  NSLocalizedString(@"Please enter the hostname for the SSH Tunnel, or disable the SSH Tunnel.", @"message of panel when ssh details are incomplete"));		
		return;
	}

	// Ensure that a socket connection is not inadvertently used
	if (![self _checkHost]) return;


	// Set up the favourite, or get the mutable dictionary for the current favourite.
	NSMutableDictionary *theFavorite;
	if (createNewFavorite) {
		theFavorite = [NSMutableDictionary dictionary];
		[theFavorite setObject:[self _createNewFavoriteID] forKey:SPFavoriteIDKey];
	} else {
		if (!currentFavorite) {
			[NSException raise:NSInternalInconsistencyException format:@"Tried to save a current favourite with no currentFavorite"];
		}
		theFavorite = [self selectedFavorite];
	}

	// Set the name - either taking the provided name, or generating one.
	if ([[self name] length]) {
		[theFavorite setObject:[self name] forKey:SPFavoriteNameKey];
	} else {
		NSString *favoriteName = [self _generateNameForConnection];
		if (!favoriteName) {
			favoriteName = NSLocalizedString(@"Untitled", @"Name for an untitled connection");
		}
		[theFavorite setObject:favoriteName forKey:SPFavoriteNameKey];
	}

	// Set standard details for the connection
	[theFavorite setObject:[NSNumber numberWithInteger:[self type]] forKey:SPFavoriteTypeKey];
	if ([self host]) {
		[theFavorite setObject:[self host] forKey:SPFavoriteHostKey];
	}
	if ([self socket]) {
		[theFavorite setObject:[self socket] forKey:SPFavoriteSocketKey];
	}
	if ([self user]) {
		[theFavorite setObject:[self user] forKey:SPFavoriteUserKey];
	}
	if ([self port]) {
		[theFavorite setObject:[self port] forKey:SPFavoritePortKey];
	}
	if ([self database]) {
		[theFavorite setObject:[self database] forKey:SPFavoriteDatabaseKey];
	}
	
	// SSL details
	if ([self useSSL]) {
		[theFavorite setObject:[NSNumber numberWithInteger:[self useSSL]] forKey:SPFavoriteUseSSLKey];
	}
	[theFavorite setObject:[NSNumber numberWithInteger:[self sslKeyFileLocationEnabled]] forKey:SPFavoriteSSLKeyFileLocationEnabledKey];
	if ([self sslKeyFileLocation]) {
		[theFavorite setObject:[self sslKeyFileLocation] forKey:SPFavoriteSSLKeyFileLocationKey];
	}
	[theFavorite setObject:[NSNumber numberWithInteger:[self sslCertificateFileLocationEnabled]] forKey:SPFavoriteSSLCertificateFileLocationEnabledKey];
	if ([self sslCertificateFileLocation]) {
		[theFavorite setObject:[self sslCertificateFileLocation] forKey:SPFavoriteSSLCertificateFileLocationKey];
	}
	[theFavorite setObject:[NSNumber numberWithInteger:[self sslCACertFileLocationEnabled]] forKey:SPFavoriteSSLCACertFileLocationEnabledKey];
	if ([self sslCACertFileLocation]) {
		[theFavorite setObject:[self sslCACertFileLocation] forKey:SPFavoriteSSLCACertFileLocationKey];
	}
	
	// SSH details
	if ([self sshHost]) {
		[theFavorite setObject:[self sshHost] forKey:SPFavoriteSSHHostKey];
	}
	if ([self sshUser]) {
		[theFavorite setObject:[self sshUser] forKey:SPFavoriteSSHUserKey];
	}
	if ([self sshPort]) {
		[theFavorite setObject:[self sshPort] forKey:SPFavoriteSSHPortKey];
	}
	[theFavorite setObject:[NSNumber numberWithInteger:[self sshKeyLocationEnabled]] forKey:SPFavoriteSSHKeyLocationEnabledKey];
	if ([self sshKeyLocation]) {
		[theFavorite setObject:[self sshKeyLocation] forKey:SPFavoriteSSHKeyLocationKey];
	}
	

	/**
	 * Password handling for the SQL connection
	 */
	NSString *oldKeychainName, *oldKeychainAccount, *newKeychainName, *newKeychainAccount;;
	NSString *oldHostnameForPassword = ([[currentFavorite objectForKey:SPFavoriteTypeKey] integerValue] == SPSocketConnection) ? @"localhost" : [currentFavorite objectForKey:SPFavoriteHostKey];
	NSString *newHostnameForPassword = ([self type] == SPSocketConnection) ? @"localhost" : [self host];

	// Grab the password for this connection
	// Add the password to keychain as appropriate
	NSString *sqlPassword = [self password];
	if (mySQLConnection && connectionKeychainItemName) {
		sqlPassword = [keychain getPasswordForName:connectionKeychainItemName account:connectionKeychainItemAccount];
	}

	// If creating a new favourite, always add the password to the keychain if it's set
	if (createNewFavorite && [sqlPassword length]) {
		[keychain addPassword:sqlPassword
					  forName:[keychain nameForFavoriteName:[theFavorite objectForKey:SPFavoriteNameKey] id:[theFavorite objectForKey:SPFavoriteIDKey]]
					  account:[keychain accountForUser:[self user] host:newHostnameForPassword database:[self database]]];
	}

	// If not creating a new favourite...
	if (!createNewFavorite) {

		// Get the old keychain name and account strings
		oldKeychainName = [keychain nameForFavoriteName:[currentFavorite objectForKey:SPFavoriteNameKey] id:[currentFavorite objectForKey:SPFavoriteIDKey]];
		oldKeychainAccount = [keychain accountForUser:[currentFavorite objectForKey:SPFavoriteUserKey] host:oldHostnameForPassword database:[currentFavorite objectForKey:SPFavoriteDatabaseKey]];
		
		// If there's no new password, remove the old item from the keychain
		if (![sqlPassword length]) {
			[keychain deletePasswordForName:oldKeychainName account:oldKeychainAccount];

		// Otherwise, set up the new keychain name and account strings and create or edit the item
		} else {
			newKeychainName = [keychain nameForFavoriteName:[theFavorite objectForKey:SPFavoriteNameKey] id:[theFavorite objectForKey:SPFavoriteIDKey]];
			newKeychainAccount = [keychain accountForUser:[self user] host:newHostnameForPassword database:[self database]];
			if ([keychain passwordExistsForName:oldKeychainName account:oldKeychainAccount]) {
				[keychain updateItemWithName:oldKeychainName account:oldKeychainAccount toName:newKeychainName account:newKeychainAccount password:sqlPassword];
			} else {
				[keychain addPassword:sqlPassword forName:newKeychainName account:newKeychainAccount];
			}
		}
	}
	sqlPassword = nil;
	
	
	/**
	 * Password handling for the SSH connection
	 */
	NSString *theSSHPassword = [self sshPassword];
	if (mySQLConnection && connectionSSHKeychainItemName) {
		theSSHPassword = [keychain getPasswordForName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount];
	}

	// If creating a new favourite, always add the password if it's set
	if (createNewFavorite && [theSSHPassword length]) {
		[keychain addPassword:theSSHPassword
					  forName:[keychain nameForSSHForFavoriteName:[theFavorite objectForKey:SPFavoriteNameKey] id:[theFavorite objectForKey:SPFavoriteIDKey]]
					  account:[keychain accountForSSHUser:[self sshUser] sshHost:[self sshHost]]];
	}

	// If not creating a new favourite...
	if (!createNewFavorite) {

		// Get the old keychain name and account strings
		oldKeychainName = [keychain nameForSSHForFavoriteName:[currentFavorite objectForKey:SPFavoriteNameKey] id:[currentFavorite objectForKey:SPFavoriteIDKey]];
		oldKeychainAccount = [keychain accountForSSHUser:[currentFavorite objectForKey:SPFavoriteSSHUserKey] sshHost:[currentFavorite objectForKey:SPFavoriteSSHHostKey]];
		
		// If there's no new password, remove the old item from the keychain
		if (![theSSHPassword length]) {
			[keychain deletePasswordForName:oldKeychainName account:oldKeychainAccount];

		// Otherwise, set up the new keychain name and account strings and create or edit the item
		} else {
			newKeychainName = [keychain nameForSSHForFavoriteName:[theFavorite objectForKey:SPFavoriteNameKey] id:[theFavorite objectForKey:SPFavoriteIDKey]];
			newKeychainAccount = [keychain accountForSSHUser:[self sshUser] sshHost:[self sshHost]];
			if ([keychain passwordExistsForName:oldKeychainName account:oldKeychainAccount]) {
				[keychain updateItemWithName:oldKeychainName account:oldKeychainAccount toName:newKeychainName account:newKeychainAccount password:theSSHPassword];
			} else {
				[keychain addPassword:theSSHPassword forName:newKeychainName account:newKeychainAccount];
			}
		}
	}
	theSSHPassword = nil;


	/**
	 * Saving the connection
	 */

	// If creating the connection, add to the favourites tree.
	if (createNewFavorite) {
		SPTreeNode *selectedNode = [self selectedFavoriteNode];
		SPTreeNode *parentNode = nil;

		// If the current node is a group node, create the favorite as a child of it
		if ([selectedNode isGroup] && selectedNode != quickConnectItem) {
			parentNode = selectedNode;

		// Otherwise, create the new node as a sibling of the selected node if possible
		} else if ([selectedNode parentNode] && [selectedNode parentNode] != favoritesRoot) {
			parentNode = (SPTreeNode *)[selectedNode parentNode];
		}

		// Ensure the parent is expanded
		[favoritesOutlineView expandItem:parentNode];

		// Add the new node and select it
		SPTreeNode *newNode = [favoritesController addFavoriteNodeWithData:theFavorite asChildOfNode:parentNode];

		[self _sortFavorites];

		[self _selectNode:newNode];

		// Update the favorites popup button in the preferences
		[[[[NSApp delegate] preferenceController] generalPreferencePane] updateDefaultFavoritePopup];

	// Otherwise, if editing the favourite, update it
	} else {
		[[[self selectedFavoriteNode] representedObject] setNodeFavorite:theFavorite];

		// Save the new data to disk
		[favoritesController saveFavorites];

		[self _stopEditingConnection];

		if (currentFavorite) [currentFavorite release], currentFavorite = nil;
		currentFavorite = [theFavorite copy];

		[self _sortFavorites];
		[self _scrollToSelectedNode];
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:SPConnectionFavoritesChangedNotification object:self];
}

/**
 * Check the host field and ensure it isn't set to 'localhost' for non-socket connections.
 */
- (BOOL)_checkHost
{
	if ([self type] != SPSocketConnection && [[self host] isEqualToString:@"localhost"]) {
		SPBeginAlertSheet(NSLocalizedString(@"You have entered 'localhost' for a non-socket connection", @"title of error when using 'localhost' for a network connection"),
						  NSLocalizedString(@"Use 127.0.0.1", @"Use 127.0.0.1 button"),	// Main button
						  NSLocalizedString(@"Connect via socket", @"Connect via socket button"),	// Alternate button
						  nil,	// Other button
						  [dbDocument parentWindow],	// Window to attach to
						  self,	// Modal delegate
						  @selector(localhostErrorSheetDidEnd:returnCode:contextInfo:),	// Did end selector
						  nil,	// Contextual info for selectors
						  NSLocalizedString(@"To MySQL, 'localhost' is a special host and means that a socket connection should be used.\n\nDid you mean to use a socket connection, or to connect to the local machine via a port?  If you meant to connect via a port, '127.0.0.1' should be used instead of 'localhost'.", @"message of error when using 'localhost' for a network connection"));
		return NO;
	}
	
	return YES;
}

/**
 * Sorts the connection favorites based on the selected criteria.
 */

#ifndef SP_REFACTOR
- (void)_sortFavorites
{
    NSString *sortKey = SPFavoriteNameKey;
	
	switch (currentSortItem)
	{
		case SPFavoritesSortNameItem:
			sortKey = SPFavoriteNameKey;
			break;
		case SPFavoritesSortHostItem:
			sortKey = SPFavoriteHostKey;
			break;
		case SPFavoritesSortTypeItem:
			sortKey = SPFavoriteTypeKey;
			break;
		case SPFavoritesSortUnsorted:
			return;
	}

	// Store a copy of the selected nodes for re-selection
	NSArray *preSortSelection = [self selectedFavoriteNodes];

	[self _sortTreeNode:[[favoritesRoot childNodes] objectAtIndex:0] usingKey:sortKey];
			
	[favoritesController saveFavorites];
	 
	[self _reloadFavoritesViewData];

	// Update the selection to account for sorted favourites
	NSMutableIndexSet *restoredSelection = [NSMutableIndexSet indexSet];
	for (SPTreeNode *eachNode in preSortSelection) {
		[restoredSelection addIndex:[favoritesOutlineView rowForItem:eachNode]];
	}
	[favoritesOutlineView selectRowIndexes:restoredSelection byExtendingSelection:NO];

	[[NSNotificationCenter defaultCenter] postNotificationName:SPConnectionFavoritesChangedNotification object:self];
}
#endif

/**
 * Sorts the supplied tree node using the supplied sort key.
 *
 * @param node The tree node to sort
 * @param key  The sort key to sort by
 */
- (void)_sortTreeNode:(SPTreeNode *)node usingKey:(NSString *)key
{	
	NSMutableArray *nodes = [[node mutableChildNodes] mutableCopy];
	
	// If this node only has one child and it's not another group node, don't bother proceeding
	if (([nodes count] == 1) && (![[nodes objectAtIndex:0] isGroup])) {
		[nodes release];
		return;
	}
	
	for (SPTreeNode *treeNode in nodes)
	{
		if ([treeNode isGroup]) {
			[self _sortTreeNode:treeNode usingKey:key];
		}
	}
	
	NSMutableIndexSet *indexes = [[NSMutableIndexSet alloc] init]; 
		
	NSUInteger i = [indexes lastIndex];
	
	while (i != NSNotFound)
	{
		[nodes removeObjectAtIndex:i];
		
		i = [indexes indexLessThanIndex:i];
	}
	
	[indexes release];
	
	[nodes sortUsingFunction:_compareFavoritesUsingKey context:key];
		
	if (reverseFavoritesSort) [nodes reverse];
	
	[[node mutableChildNodes] setArray:nodes];
	
	[nodes release];
}

/**
 * Sort function used by NSMutableArray's sortUsingFunction:
 *
 * @param favorite1 The first of the favorites to compare (and determine sort order)
 * @param favorite2 The second of the favorites to compare
 * @param key       The sort key to perform the comparison by
 * 
 * @return An integer (NSComparisonResult) indicating the order of the comparison
 */
static NSComparisonResult _compareFavoritesUsingKey(id favorite1, id favorite2, void *key)
{
	NSString *dictKey = (NSString *)key;
	id value1, value2;

	if ([favorite1 isGroup]) {
		if ([dictKey isEqualToString:SPFavoriteNameKey] || [favorite2 isGroup]) {
			value1 = [[favorite1 representedObject] nodeName];
		} else {
			value1 = nil;
		}
	} else {
		value1 = [[(SPFavoriteNode *)[(SPTreeNode *)favorite1 representedObject] nodeFavorite] objectForKey:dictKey];
	}

	if ([favorite2 isGroup]) {
		if ([dictKey isEqualToString:SPFavoriteNameKey] || [favorite1 isGroup]) {
			value2 = [[favorite2 representedObject] nodeName];
		} else {
			value2 = nil;
		}
	} else {
		value2 = [[(SPFavoriteNode *)[(SPTreeNode *)favorite2 representedObject] nodeFavorite] objectForKey:dictKey];
	}

	if ([value1 isKindOfClass:[NSString class]]) {
		return [value1 caseInsensitiveCompare:value2];
	}
	return [value1 compare:value2];
}

/**
 * Updates the favorite's host when the type changes.
 */

#ifndef SP_REFACTOR

- (void)_favoriteTypeDidChange
{	
	NSDictionary *favorite = [self selectedFavorite];
	
	// If either socket or host is localhost, clear.
	if ((previousType != SPSocketConnection) && [[favorite objectForKey:SPFavoriteHostKey] isEqualToString:@"localhost"]) {
		[self setHost:@""];
	}
	
	// Update the name for newly added favorites if not already touched by the user, by triggering a KVO update
	if (![[self name] length] || favoriteNameFieldWasAutogenerated) {
		NSString *favoriteName = [self _generateNameForConnection];
		if (favoriteName) {
			[self setName:favoriteName];
		}
	}
}

/**
 * Convenience method for reloading the outline view, expanding the root item and scrolling to the selected item.
 */
- (void)_reloadFavoritesViewData
{	
	[favoritesOutlineView reloadData];
	[favoritesOutlineView expandItem:[[favoritesRoot childNodes] objectAtIndex:0] expandChildren:NO];
	[self _scrollToSelectedNode];
}

/**
 * Update the first responder status on password fields if they are empty and
 * some host details are set, usually as a response to favourite selection changes.
 */
- (void)_updateFavoriteFirstResponder
{

	// Skip auto-selection changes if there is no user set
	if (![[self user] length]) return;

	switch ([self type]) 
	{
		case SPTCPIPConnection:
			if (![[standardPasswordField stringValue] length]) {
				[[dbDocument parentWindow] makeFirstResponder:standardPasswordField];
			}
			break;
		case SPSocketConnection:
			if (![[socketPasswordField stringValue] length]) {
				[[dbDocument parentWindow] makeFirstResponder:socketPasswordField];
			}
			break;
		case SPSSHTunnelConnection:
			if (![[sshPasswordField stringValue] length]) {
				[[dbDocument parentWindow] makeFirstResponder:sshPasswordField];
			}
			break;
	}
}

#endif

/**
 * Restores the connection interface to its original state.
 */
- (void)_restoreConnectionInterface
{
	// Must be performed on the main thread
	if (![NSThread isMainThread]) return [[self onMainThread] _restoreConnectionInterface];
	
	// Reset the window title
	[[dbDocument parentWindow] setTitle:[dbDocument displayName]];
	
	// Stop the current tab's progress indicator
	[dbDocument setIsProcessing:NO];
	
	// Reset the UI
	[helpButton setHidden:NO];
	[helpButton display];
	[connectButton setTitle:NSLocalizedString(@"Connect", @"connect button")];
	[connectButton setEnabled:YES];
	[connectButton display];
	[testConnectButton setEnabled:YES];
	[progressIndicator stopAnimation:self];
	[progressIndicator display];
	[progressIndicatorText setHidden:YES];
	[progressIndicatorText display];
	
	// Re-enable favorites table view
	[favoritesOutlineView setEnabled:YES];
	[(NSView *)favoritesOutlineView display];

	// Revert the connect button back to its original selector
	[connectButton setAction:@selector(initiateConnection:)];
}

#ifndef SP_REFACTOR

/**
 * Selected the supplied node in the favorites outline view.
 *
 * @param node The node to select
 */
- (void)_selectNode:(SPTreeNode *)node
{
	[favoritesOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:[favoritesOutlineView rowForItem:node]] byExtendingSelection:NO];
	[self _scrollToSelectedNode];
}

/**
 * Scroll to the currently selected node.
 */
- (void)_scrollToSelectedNode
{

	// Don't scroll if no node is currently selected
	if ([favoritesOutlineView selectedRow] == -1) return;

	[favoritesOutlineView scrollRowToVisible:[favoritesOutlineView selectedRow]];
}

/**
 * Removes the supplied tree node.
 *
 * @param node The node to remove
 */
- (void)_removeNode:(SPTreeNode *)node
{
	[self _removeAllPasswordsForNode:node];

	[favoritesController removeFavoriteNode:node];
	
	[self _reloadFavoritesViewData];

	// Clear the selection and update the interface to match
	[favoritesOutlineView selectRowIndexes:nil byExtendingSelection:NO];
	[self updateFavoriteSelection:self];
	
	[connectionResizeContainer setHidden:NO];
	[connectionInstructionsTextField setStringValue:NSLocalizedString(@"Enter connection details below, or choose a favorite", @"enter connection details label")];
	
	[[(SPPreferenceController *)[[NSApp delegate] preferenceController] generalPreferencePane] updateDefaultFavoritePopup];
}

/**
 * Removes all passwords for the supplied tree node and any child nodes.
 *
 * @param node The node to remove all passwords within and for.
 */
- (void)_removeAllPasswordsForNode:(SPTreeNode *)node
{

	// If the supplied node is a group node, remove all passwords for any children
	if ([node isGroup]) {
		for (SPTreeNode *childNode in [node childNodes]) {
			[self _removeAllPasswordsForNode:childNode];
		}
		return;
	}

	// Otherwise, remove details for the supplied node.

	NSDictionary *favorite = [[node representedObject] nodeFavorite];
	
	// Get selected favorite's details
	NSString *favoriteName     = [favorite objectForKey:SPFavoriteNameKey];
	NSString *favoriteUser     = [favorite objectForKey:SPFavoriteUserKey];
	NSString *favoriteHost     = [favorite objectForKey:SPFavoriteHostKey];
	NSString *favoriteDatabase = [favorite objectForKey:SPFavoriteDatabaseKey];
	NSString *favoriteSSHUser  = [favorite objectForKey:SPFavoriteSSHUserKey];
	NSString *favoriteSSHHost  = [favorite objectForKey:SPFavoriteSSHHostKey];
	NSString *favoriteID       = [favorite objectForKey:SPFavoriteIDKey];
	
	// Remove passwords from the Keychain
	[keychain deletePasswordForName:[keychain nameForFavoriteName:favoriteName id:favoriteID]
							account:[keychain accountForUser:favoriteUser host:((type == SPSocketConnection) ? @"localhost" : favoriteHost) database:favoriteDatabase]];
	[keychain deletePasswordForName:[keychain nameForSSHForFavoriteName:favoriteName id:favoriteID]
							account:[keychain accountForSSHUser:favoriteSSHUser sshHost:favoriteSSHHost]];
	
	// Reset last used favorite
	if ([[favorite objectForKey:SPFavoriteIDKey] integerValue] == [prefs integerForKey:SPLastFavoriteID]) {
		[prefs setInteger:0	forKey:SPLastFavoriteID];
	}
	
	// If required, reset the default favorite
	if ([[favorite objectForKey:SPFavoriteIDKey] integerValue] == [prefs integerForKey:SPDefaultFavorite]) {
		[prefs setInteger:[prefs integerForKey:SPLastFavoriteID] forKey:SPDefaultFavorite];
	}
}

/**
 * Creates a new favorite ID based on the UNIX epoch time.
 */
- (NSNumber *)_createNewFavoriteID
{
	return [NSNumber numberWithInteger:[[NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]] hash]];
}

/**
 * Returns the favorite node for the conection favorite with the supplied ID.
 */
- (SPTreeNode *)_favoriteNodeForFavoriteID:(NSInteger)favoriteID
{	
	SPTreeNode *favoriteNode = nil;
	
	if (!favoritesRoot) return favoriteNode;

	if (!favoriteID) return quickConnectItem;
		
	for (SPTreeNode *node in [favoritesRoot allChildLeafs]) 
	{						
		if ([[[[node representedObject] nodeFavorite] objectForKey:SPFavoriteIDKey] integerValue] == favoriteID) {
			favoriteNode = node;
		} 
	}
	
	return favoriteNode;
}
#endif

/**
 * Strips any invalid characters form the supplied string. Invalid is defined as any characters that should
 * not be allowed to be enetered on the connection screen.
 */
- (NSString *)_stripInvalidCharactersFromString:(NSString *)subject
{
	NSString *result = [subject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	return [result stringByReplacingOccurrencesOfString:@"\n" withString:@""];
}

/**
 * Generate a name for the current connection based on any other populated details.
 * Currently uses the host and database fields.
 * If a name cannot be generated because there are insufficient other details, returns nil.
 */
- (NSString *)_generateNameForConnection
{
	NSString *aName;

	if ([self type] != SPSocketConnection && ![[self host] length]) {
		return nil;
	}

	aName = ([self type] == SPSocketConnection) ? @"localhost" : [self host];

	if ([[self database] length]) {
		aName = [NSString stringWithFormat:@"%@/%@", aName, [self database]];
	}

	return aName;
}


/**
 * If editing is not already active, mark editing as starting, triggering UI updates
 * to match.
 */
- (void)_startEditingConnection
{

	// If not connecting, hide the connection status text to reflect changes
	if (!isConnecting) {
		[progressIndicatorText setHidden:YES];
	}

	if (isEditingConnection) return;

	// Fade and move the edit button area in
	[editButtonsView setAlphaValue:0.0f];
	[editButtonsView setHidden:NO];
	[editButtonsView setFrameOrigin:NSMakePoint([editButtonsView frame].origin.x, [editButtonsView frame].origin.y - 30)];
	[[editButtonsView animator] setFrameOrigin:NSMakePoint([editButtonsView frame].origin.x, [editButtonsView frame].origin.y + 30)];
	[[editButtonsView animator] setAlphaValue:1.0f];

	// Update the "Save" button state as appropriate
	[saveFavoriteButton setEnabled:([self selectedFavorite] != nil)];

	// Show the area to allow saving the changes
	[self setIsEditingConnection:YES];
	[favoritesOutlineView setNeedsDisplayInRect:[favoritesOutlineView rectOfRow:[favoritesOutlineView selectedRow]]];
}

/**
 * If editing is active, mark editing as complete, triggering UI updates to match.
 */
- (void)_stopEditingConnection
{
	if (!isEditingConnection) return;

	[editButtonsView setHidden:YES];
	[progressIndicatorText setHidden:YES];

	[self setIsEditingConnection:NO];
}

#pragma mark -

- (void)_documentWillClose:(NSNotification *)notification
{
	cancellingConnection = YES;
	dbDocument = nil;
	if (mySQLConnection) {
		[mySQLConnection setDelegate:nil];
		[NSThread detachNewThreadWithName:@"SPConnectionController close background disconnect" target:mySQLConnection selector:@selector(disconnect) object:nil];
		[mySQLConnection autorelease];
		mySQLConnection = nil;
	}
	if (sshTunnel) [sshTunnel setConnectionStateChangeSelector:nil delegate:nil], [sshTunnel disconnect], [sshTunnel release];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self];

	// Unregister observers
#ifndef SP_REFACTOR
	[self removeObserver:self forKeyPath:SPFavoriteTypeKey];
	[self removeObserver:self forKeyPath:SPFavoriteNameKey];
	[self removeObserver:self forKeyPath:SPFavoriteHostKey];
	[self removeObserver:self forKeyPath:SPFavoriteUserKey];
	[self removeObserver:self forKeyPath:SPFavoriteDatabaseKey];
	[self removeObserver:self forKeyPath:SPFavoriteSocketKey];
	[self removeObserver:self forKeyPath:SPFavoritePortKey];
	[self removeObserver:self forKeyPath:SPFavoriteUseSSLKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSHHostKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSHUserKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSHPortKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSHKeyLocationEnabledKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSHKeyLocationKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSLKeyFileLocationEnabledKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSLKeyFileLocationKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSLCertificateFileLocationEnabledKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSLCertificateFileLocationKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSLCACertFileLocationEnabledKey];
	[self removeObserver:self forKeyPath:SPFavoriteSSLCACertFileLocationKey];
#endif

#ifndef SP_REFACTOR
	[keychain release];
#endif
	[prefs release];
	
#ifndef SP_REFACTOR
	[folderImage release], folderImage = nil;
	[quickConnectItem release], quickConnectItem = nil;
	[quickConnectCell release], quickConnectCell = nil;
#endif
	
	for (id retainedObject in nibObjectsToRelease) [retainedObject release];
	
	[nibObjectsToRelease release];

	if (connectionKeychainID) [connectionKeychainID release];
	if (connectionKeychainItemName) [connectionKeychainItemName release];
	if (connectionKeychainItemAccount) [connectionKeychainItemAccount release];
	if (connectionSSHKeychainItemName) [connectionSSHKeychainItemName release];
	if (connectionSSHKeychainItemAccount) [connectionSSHKeychainItemAccount release];

#ifndef SP_REFACTOR
	if (currentFavorite) [currentFavorite release], currentFavorite = nil;
#endif
    
	[super dealloc];
}

@end
