//
//  $Id$
//
//  SPConnectionController.m
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

#import "SPConnectionController.h"
#import "SPDatabaseDocument.h"
#import "SPAppController.h"
#import "SPPreferenceController.h"
#import "ImageAndTextCell.h"
#import "RegexKitLite.h"
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

- (BOOL)_checkHost;
- (void)_sortFavorites;
- (void)_sortTreeNode:(SPTreeNode *)node usingKey:(NSString *)key;
- (void)_favoriteTypeDidChange;
- (void)_reloadFavoritesViewData;
- (void)_restoreConnectionInterface;
- (void)_selectNode:(SPTreeNode *)node;
- (void)_removeNode:(SPTreeNode *)node;

- (NSNumber *)_createNewFavoriteID;
- (SPTreeNode *)_favoriteNodeForFavoriteID:(NSInteger)favoriteID;
- (NSString *)_stripInvalidCharactersFromString:(NSString *)subject;

- (void)_updateFavoritePasswordsFromField:(NSControl *)control;

static NSComparisonResult _compareFavoritesUsingKey(id favorite1, id favorite2, void *key);

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

@synthesize connectionKeychainItemName;
@synthesize connectionKeychainItemAccount;
@synthesize connectionSSHKeychainItemName;
@synthesize connectionSSHKeychainItemAccount;

@synthesize isConnecting;

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
	
	// Disable the favorites outline view to prevent further connections attempts
	[favoritesOutlineView setEnabled:NO];
	
	[addToFavoritesButton setHidden:YES];
	[helpButton setHidden:YES];
	[connectButton setEnabled:NO];
	[progressIndicator startAnimation:self];
	[progressIndicatorText setHidden:NO];
	
	// Start the current tab's progress indicator
	[dbDocument setIsProcessing:YES];

	// If the password(s) are marked as having been originally sourced from a keychain, check whether they
	// have been changed or not; if not, leave the mark in place and remove the password from the field
	// for increased security.
	if (connectionKeychainItemName) {
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
	
	if (connectionSSHKeychainItemName) {
		if ([[keychain getPasswordForName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount] isEqualToString:[self sshPassword]]) {
			[self setSshPassword:[[NSString string] stringByPaddingToLength:[[self sshPassword] length] withString:@"sp" startingAtIndex:0]];
			[[sshSSHPasswordField undoManager] removeAllActionsWithTarget:sshSSHPasswordField];
		} 
		else {
			[connectionSSHKeychainItemName release], connectionSSHKeychainItemName = nil;
			[connectionSSHKeychainItemAccount release], connectionSSHKeychainItemAccount = nil;
		}
	}
	
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
 * Cancels (or rather marks) the current connection is to be cancelled once established.
 *
 * Note, that once called this method does not mark the connection attempt to be immediately cancelled as
 * there is no reliable way to actually cancel connection attempts via the MySQL client libs. Once the
 * connection is established it will be immediately killed.
 */
- (IBAction)cancelMySQLConnection:(id)sender
{
	[connectButton setEnabled:NO];
	
	[progressIndicatorText setStringValue:NSLocalizedString(@"Cancelling...", @"cancelling task status message")];
	[progressIndicatorText display];
	
	mySQLConnectionCancelled = YES;
}

#pragma mark -
#pragma mark Interface interaction

/**
 * Registered to be the double click action of the favorites outline view.
 */
- (IBAction)nodeDoubleClicked:(id)sender
{
	SPTreeNode *node = [self selectedFavoriteNode];
	
	if (node) {
		// Only proceed to initiate a connection if a leaf node (i.e. a favorite and not a group) was double clicked.
		if (![node isGroup]) {
			[self initiateConnection:self];
		}
		// Otherwise start editing the group node's name
		else {
			[favoritesOutlineView editColumn:0 row:[favoritesOutlineView selectedRow] withEvent:nil select:YES];
		}
	}
}

/**
 * Opens the SSH/SSL key selection window, ready to select a key file.
 */
- (IBAction)chooseKeyLocation:(id)sender
{
	[favoritesOutlineView deselectAll:self];
	NSString *directoryPath = nil;
	NSString *filePath = nil;
	NSArray *permittedFileTypes = nil;
	keySelectionPanel = [NSOpenPanel openPanel];
	[keySelectionPanel setShowsHiddenFiles:[prefs boolForKey:SPHiddenKeyFileVisibilityKey]];

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
}

/**
 * Toggle hidden file visiblity in response to accessory view changes
 */
- (IBAction)updateKeyLocationFileVisibility:(id)sender
{
	[keySelectionPanel setShowsHiddenFiles:[prefs boolForKey:SPHiddenKeyFileVisibilityKey]];
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
	NSInteger additionalFormHeight = 55;

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

	if (animate) {
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
    previousSortItem = currentSortItem;
	currentSortItem  = [[sender menu] indexOfItem:sender];
	
	[prefs setInteger:currentSortItem forKey:SPFavoritesSortedBy];
	
	// Perform sorting
	[self _sortFavorites];
	
	if (previousSortItem > SPFavoritesSortUnsorted) [[[sender menu] itemAtIndex:previousSortItem] setState:NSOffState];
	
	[[[sender menu] itemAtIndex:currentSortItem] setState:NSOnState];
}

/**
 * Reverses the favorites table view sorting based on the selected criteria.
 */
- (void)reverseSortFavorites:(id)sender
{
    reverseFavoritesSort = (![sender state]);
    
	[prefs setBool:reverseFavoritesSort forKey:SPFavoritesSortedInReverse];
	
	// Perform re-sorting
	[self _sortFavorites];
	
	[(NSMenuItem *)sender setState:reverseFavoritesSort]; 
}

/**
 * Sets fields for the chosen favorite.
 */
- (void)updateFavoriteSelection:(id)sender
{
	automaticFavoriteSelection = YES;

	// Clear the keychain referral items as appropriate
	if (connectionKeychainItemName) [connectionKeychainItemName release], connectionKeychainItemName = nil;
	if (connectionKeychainItemAccount) [connectionKeychainItemAccount release], connectionKeychainItemAccount = nil;
	if (connectionSSHKeychainItemName) [connectionSSHKeychainItemName release], connectionSSHKeychainItemName = nil;
	if (connectionSSHKeychainItemAccount) [connectionSSHKeychainItemAccount release], connectionSSHKeychainItemAccount = nil;
	
	SPTreeNode *node = [self selectedFavoriteNode];
	
	// Update key-value properties from the selected favourite, using empty strings where not found
	NSDictionary *fav = [[node representedObject] nodeFavorite];
	
	// Keep a copy of the favorite as it currently stands
	if (currentFavorite) [currentFavorite release], currentFavorite = nil;
	
	currentFavorite = [[node representedObject] copy];
	
	[connectionResizeContainer setHidden:NO];
	
	// Standard details
	[self setType:([fav objectForKey:SPFavoriteTypeKey] ? [[fav objectForKey:SPFavoriteTypeKey] integerValue] : SPTCPIPConnection)];
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
	[self resizeTabViewToConnectionType:[self type] animating:YES];
	
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
	switch ([self type]) 
	{
		case SPTCPIPConnection:
			if (![[standardPasswordField stringValue] length]) [[dbDocument parentWindow] makeFirstResponder:standardPasswordField];
			break;
		case SPSocketConnection:
			if (![[socketPasswordField stringValue] length]) [[dbDocument parentWindow] makeFirstResponder:socketPasswordField];
			break;
		case SPSSHTunnelConnection:
			if (![[sshPasswordField stringValue] length]) [[dbDocument parentWindow] makeFirstResponder:sshPasswordField];
			break;
	}
}

/**
 * Returns the selected favorite data dictionary or nil if nothing is selected.
 */
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
	
	SPTreeNode *parent = ([selectedNode isGroup]) ? selectedNode : (SPTreeNode *)[selectedNode parentNode];
	
	SPTreeNode *node = [favoritesController addFavoriteNodeWithData:favorite asChildOfNode:parent];
	
	[self _reloadFavoritesViewData];
    [self _selectNode:node];
	
    [[[[NSApp delegate] preferenceController] generalPreferencePane] updateDefaultFavoritePopup];

	favoriteNameFieldWasTouched = NO;
		
	[favoritesOutlineView editColumn:0 row:[favoritesOutlineView selectedRow] withEvent:nil select:YES];
}

/**
 * Adds the current details as a new connection favorite, selects it, and scrolls the selected
 * row to be visible.
 */
- (IBAction)addFavoriteUsingCurrentDetails:(id)sender
{
	NSString *thePassword, *theSSHPassword;
	NSNumber *favoriteid = [self _createNewFavoriteID];
	NSString *favoriteName = [[self name] length] ? [self name] : [NSString stringWithFormat:@"%@@%@", ([self user] && [[self user] length])?[self user] : @"anonymous", (([self type] == SPSocketConnection) ? @"localhost" : [self host])];
	
	if (![[self name] length] && [self database] && ![[self database] isEqualToString:@""]) {
		favoriteName = [NSString stringWithFormat:@"%@ %@", [self database], favoriteName];
	}
	
	// Ensure that host is not empty if this is a TCP/IP or SSH connection
	if (([self type] == SPTCPIPConnection || [self type] == SPSSHTunnelConnection) && ![[self host] length]) {
		NSRunAlertPanel(NSLocalizedString(@"Insufficient connection details", @"insufficient details message"), NSLocalizedString(@"Insufficient details provided to establish a connection. Please provide at least a host.", @"insufficient details informative message"), NSLocalizedString(@"OK", @"OK button"), nil, nil);
		return;
	}
	
	// If SSH is enabled, ensure that the SSH host is not nil
	if ([self type] == SPSSHTunnelConnection && ![[self sshHost] length]) {
		NSRunAlertPanel(NSLocalizedString(@"Insufficient connection details", @"insufficient details message"), NSLocalizedString(@"Please enter the hostname for the SSH Tunnel, or disable the SSH Tunnel.", @"message of panel when ssh details are incomplete"), NSLocalizedString(@"OK", @"OK button"), nil, nil);
		return;
	}

	// Ensure that a socket connection is not inadvertently used
	if (![self _checkHost]) return;
	
	// Construct the favorite details - cannot use only dictionaryWithObjectsAndKeys for possible nil values.
	NSMutableDictionary *newFavorite = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithInteger:[self type]], SPFavoriteTypeKey,
										favoriteName, SPFavoriteNameKey,
										favoriteid, SPFavoriteIDKey,
										nil];
	
	// Standard details
	if ([self host])     [newFavorite setObject:[self host] forKey:SPFavoriteHostKey];
	if ([self socket])   [newFavorite setObject:[self socket] forKey:SPFavoriteSocketKey];
	if ([self user])     [newFavorite setObject:[self user] forKey:SPFavoriteUserKey];
	if ([self port])     [newFavorite setObject:[self port] forKey:SPFavoritePortKey];
	if ([self database]) [newFavorite setObject:[self database] forKey:SPFavoriteDatabaseKey];
	
	// SSL details
	if ([self useSSL]) [newFavorite setObject:[NSNumber numberWithInt:[self useSSL]] forKey:SPFavoriteUseSSLKey];
	[newFavorite setObject:[NSNumber numberWithInt:[self sslKeyFileLocationEnabled]] forKey:SPFavoriteSSLKeyFileLocationEnabledKey];
	if ([self sslKeyFileLocation]) [newFavorite setObject:[self sslKeyFileLocation] forKey:SPFavoriteSSLKeyFileLocationKey];
	[newFavorite setObject:[NSNumber numberWithInt:[self sslCertificateFileLocationEnabled]] forKey:SPFavoriteSSLCertificateFileLocationEnabledKey];
	if ([self sslCertificateFileLocation]) [newFavorite setObject:[self sslCertificateFileLocation] forKey:SPFavoriteSSLCertificateFileLocationKey];
	[newFavorite setObject:[NSNumber numberWithInt:[self sslCACertFileLocationEnabled]] forKey:SPFavoriteSSLCACertFileLocationEnabledKey];
	if ([self sslCACertFileLocation]) [newFavorite setObject:[self sslCACertFileLocation] forKey:SPFavoriteSSLCACertFileLocationKey];
	
	// SSH details
	if ([self sshHost]) [newFavorite setObject:[self sshHost] forKey:SPFavoriteSSHHostKey];
	if ([self sshUser]) [newFavorite setObject:[self sshUser] forKey:SPFavoriteSSHUserKey];
	if ([self sshPort]) [newFavorite setObject:[self sshPort] forKey:SPFavoriteSSHPortKey];
	[newFavorite setObject:[NSNumber numberWithInt:[self sshKeyLocationEnabled]] forKey:SPFavoriteSSHKeyLocationEnabledKey];
	if ([self sshKeyLocation]) [newFavorite setObject:[self sshKeyLocation] forKey:SPFavoriteSSHKeyLocationKey];

	// Add the password to keychain as appropriate
	thePassword = [self password];
	
	if (mySQLConnection && connectionKeychainItemName) {
		thePassword = [keychain getPasswordForName:connectionKeychainItemName account:connectionKeychainItemAccount];
	}
	
	if (thePassword && (![thePassword isEqualToString:@""])) {
		[keychain addPassword:thePassword
					  forName:[keychain nameForFavoriteName:favoriteName id:[NSString stringWithFormat:@"%lld", [favoriteid longLongValue]]]
					  account:[keychain accountForUser:[self user] host:(([self type] == SPSocketConnection) ? @"localhost" : [self host]) database:[self database]]];
	}

	// Add the SSH password to keychain as appropriate
	theSSHPassword = [self sshPassword];
	
	if (mySQLConnection && connectionSSHKeychainItemName) {
		theSSHPassword = [keychain getPasswordForName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount];
	}
	
	if (theSSHPassword && (![theSSHPassword isEqualToString:@""])) {
		[keychain addPassword:theSSHPassword
					  forName:[keychain nameForSSHForFavoriteName:favoriteName id:[NSString stringWithFormat:@"%lld", [favoriteid longLongValue]]]
					  account:[keychain accountForSSHUser:[self sshUser] sshHost:[self sshHost]]];
	}
	
	SPTreeNode *node = [favoritesController addFavoriteNodeWithData:newFavorite asChildOfNode:nil];
	
	[self _reloadFavoritesViewData];
	[self _selectNode:node];

	// Update the favorites popup button in the preferences
	[[[[NSApp delegate] preferenceController] generalPreferencePane] updateDefaultFavoritePopup];
}

/**
 * Adds a new group node to the favorites tree with a default name. Once added it is selected for editing.
 */
- (IBAction)addGroup:(id)sender
{
	SPTreeNode *selectedNode = [self selectedFavoriteNode];
	
	SPTreeNode *parent = ([selectedNode isGroup]) ? selectedNode : (SPTreeNode *)[selectedNode parentNode];
	
	SPTreeNode *node = [favoritesController addGroupNodeWithName:NSLocalizedString(@"New Folder", @"new folder placeholder name") asChildOfNode:parent];
	
	[self _reloadFavoritesViewData];
	[self _selectNode:node];
	
	isEditing = YES;
	
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
			NSString *keychainName        = [keychain nameForFavoriteName:[favorite objectForKey:SPFavoriteNameKey] id:[favorite objectForKey:SPFavoriteIDKey]];
			NSString *keychainAccount     = [keychain accountForUser:[favorite objectForKey:SPFavoriteUserKey] host:((duplicatedFavoriteType == SPSocketConnection) ? @"localhost" : [favorite objectForKey:SPFavoriteHostKey]) database:[favorite objectForKey:SPFavoriteDatabaseKey]];
			NSString *favoritePassword    = [keychain getPasswordForName:keychainName account:keychainAccount];
			
			keychainName = [keychain nameForFavoriteName:[favorite objectForKey:SPFavoriteNameKey] id:[favorite objectForKey:SPFavoriteIDKey]];
			
			[keychain addPassword:favoritePassword forName:keychainName account:keychainAccount];
			
			favoritePassword = nil;
		}
		
		if (sshPassword && [sshPassword length]) {
			NSString *keychainSSHName     = [keychain nameForSSHForFavoriteName:[favorite objectForKey:SPFavoriteNameKey] id:[favorite objectForKey:SPFavoriteIDKey]];
			NSString *keychainSSHAccount  = [keychain accountForSSHUser:[favorite objectForKey:SPFavoriteSSHUserKey] sshHost:[favorite objectForKey:SPFavoriteSSHHostKey]];
			NSString *favoriteSSHPassword = [keychain getPasswordForName:keychainSSHName account:keychainSSHAccount];
			
			keychainSSHName = [keychain nameForSSHForFavoriteName:[favorite objectForKey:SPFavoriteNameKey] id:[favorite objectForKey:SPFavoriteIDKey]];
			
			[keychain addPassword:favoriteSSHPassword forName:keychainSSHName account:keychainSSHAccount];
		
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
	id oldObject = [change objectForKey:NSKeyValueChangeOldKey];
	id newObject = [change objectForKey:NSKeyValueChangeNewKey];
		
	if (oldObject != newObject) {
		[[self selectedFavorite] setObject:(newObject) ? newObject : @"" forKey:keyPath];
			
		// Save the new data to disk
		[favoritesController saveFavorites];
		
		[self _reloadFavoritesViewData];
	}
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
}

/**
 * Called when the user dismisses either the import of export favorites panels.
 */
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
			break;
	}
	
	[self _sortTreeNode:[[favoritesRoot childNodes] objectAtIndex:0] usingKey:sortKey];
			
	[favoritesController saveFavorites];
	 
	[self _reloadFavoritesViewData];
}

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
	if (([nodes count] == 1) && (![[nodes objectAtIndex:0] isGroup])) return;
	
	for (SPTreeNode *treeNode in nodes)
	{
		if ([treeNode isGroup]) {
			[self _sortTreeNode:treeNode usingKey:key];
		}
	}
	
	NSMutableIndexSet *indexes = [[NSMutableIndexSet alloc] init]; 
	NSMutableArray *groupNodes = [[NSMutableArray alloc] init];
	
	for (SPTreeNode *innerNode in nodes)
	{
		if ([innerNode isGroup]) {
			[groupNodes addObject:innerNode];
			[indexes addIndex:[nodes indexOfObject:innerNode]];
		}
	}
	
	NSUInteger i = [indexes firstIndex];
	
	while (i != NSNotFound)
	{
		[nodes removeObjectAtIndex:i];
		
		i = [indexes indexGreaterThanIndex:i];
	}
	
	[indexes release];
	
	[nodes sortUsingFunction:_compareFavoritesUsingKey context:key];
	
	[nodes addObjectsFromArray:groupNodes];
	
	if (reverseFavoritesSort) [nodes reverse];
	
	[[node mutableChildNodes] setArray:nodes];
	
	[groupNodes release];
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
	
	id value1 = [[(SPFavoriteNode *)[(SPTreeNode *)favorite1 representedObject] nodeFavorite] objectForKey:dictKey];
	id value2 = [[(SPFavoriteNode *)[(SPTreeNode *)favorite2 representedObject] nodeFavorite] objectForKey:dictKey];
	
	return [value1 compare:value2];
}

/**
 * Updates the favorite's host when the type changes.
 */
- (void)_favoriteTypeDidChange
{	
	NSDictionary *favorite = [[[self selectedFavoriteNode] representedObject] nodeFavorite];
	
	// If either socket or host is localhost, clear.
	if ((previousType != SPSocketConnection) && [[favorite objectForKey:SPFavoriteHostKey] isEqualToString:@"localhost"]) {
		[self setHost:@""];
	}
	
	// Update the name for newly added favorites if not already touched by the user, by triggering a KVO update
	if (!favoriteNameFieldWasTouched) {
		[self setName:[NSString stringWithFormat:@"%@@%@", 
					   ([favorite objectForKey:SPFavoriteUserKey]) ? [favorite objectForKey:SPFavoriteUserKey] : @"", 
						((previousType == SPSocketConnection) ? @"localhost" :
						(([favorite objectForKey:SPFavoriteHostKey]) ? [favorite valueForKeyPath:SPFavoriteHostKey] : @""))
					   ]];
	}
}

/**
 * Convenience method for reloading the outline view, expanding the root item and scrolling to the selected item.
 */
- (void)_reloadFavoritesViewData
{	
	[favoritesOutlineView reloadData];
	[favoritesOutlineView expandItem:[[favoritesRoot childNodes] objectAtIndex:0] expandChildren:YES];
	[favoritesOutlineView scrollRowToVisible:[favoritesOutlineView selectedRow]];
}

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
	[addToFavoritesButton setHidden:NO];
	[addToFavoritesButton display];
	[helpButton setHidden:NO];
	[helpButton display];
	[connectButton setTitle:NSLocalizedString(@"Connect", @"connect button")];
	[connectButton setEnabled:YES];
	[connectButton display];
	[progressIndicator stopAnimation:self];
	[progressIndicator display];
	[progressIndicatorText setHidden:YES];
	[progressIndicatorText display];
	
	// Re-enable favorites table view
	[favoritesOutlineView setEnabled:YES];
	[(NSView *)favoritesOutlineView display];
	
	mySQLConnectionCancelled = NO;
	
	// Revert the connect button back to its original selector
	[connectButton setAction:@selector(initiateConnection:)];
}

/**
 * Selected the supplied node in the favorites outline view.
 *
 * @param node The node to select
 */
- (void)_selectNode:(SPTreeNode *)node
{
	[favoritesOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:[favoritesOutlineView rowForItem:node]] byExtendingSelection:NO];
	[favoritesOutlineView scrollRowToVisible:[favoritesOutlineView selectedRow]];
}

/**
 * Removes the supplied tree node.
 *
 * @param node The node to remove
 */
- (void)_removeNode:(SPTreeNode *)node
{
	if (![node isGroup]) {
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
	
	[favoritesController removeFavoriteNode:node];
	
	[self _reloadFavoritesViewData];
	
	[connectionResizeContainer setHidden:NO];
	[connectionInstructionsTextField setStringValue:NSLocalizedString(@"Enter connection details below, or choose a favorite", @"enter connection details label")];
	
	[[(SPPreferenceController *)[[NSApp delegate] preferenceController] generalPreferencePane] updateDefaultFavoritePopup];
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
		
	for (SPTreeNode *node in [favoritesRoot allChildLeafs]) 
	{						
		if ([[[[node representedObject] nodeFavorite] objectForKey:SPFavoriteIDKey] integerValue] == favoriteID) {
			favoriteNode = node;
		} 
	}
	
	return favoriteNode;
}

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
 * Check all fields used in the keychain names against the old values for that
 * favorite, and update the keychain names to match if necessary.
 * If an (optional) recognised password field is supplied, that field is assumed
 * to have changed and is used to supply the new value.
 */
- (void)_updateFavoritePasswordsFromField:(NSControl *)control
{
	if (!currentFavorite) return;
	
	NSDictionary *oldFavorite = [currentFavorite nodeFavorite];
	NSDictionary *newFavorite = [[[self selectedFavoriteNode] representedObject] nodeFavorite];
	
	NSString *passwordValue;
	NSString *oldKeychainName, *newKeychainName;
	NSString *oldKeychainAccount, *newKeychainAccount;
	NSString *oldHostnameForPassword = ([[oldFavorite objectForKey:SPFavoriteTypeKey] integerValue] == SPSocketConnection) ? @"localhost" : [oldFavorite objectForKey:SPFavoriteHostKey];
	NSString *newHostnameForPassword = ([[newFavorite objectForKey:SPFavoriteTypeKey] integerValue] == SPSocketConnection) ? @"localhost" : [newFavorite objectForKey:SPFavoriteHostKey];
	
	// SQL passwords are indexed by name, host, user and database.  If any of these
	// have changed, or a standard password field has, alter the keychain item to match.
	if (![[oldFavorite objectForKey:SPFavoriteNameKey] isEqualToString:[newFavorite objectForKey:SPFavoriteNameKey]] ||
		![oldHostnameForPassword isEqualToString:newHostnameForPassword] ||
		![[oldFavorite objectForKey:SPFavoriteUserKey] isEqualToString:[newFavorite objectForKey:SPFavoriteUserKey]] ||
		![[oldFavorite objectForKey:SPFavoriteDatabaseKey] isEqualToString:[newFavorite objectForKey:SPFavoriteDatabaseKey]] ||
		control == standardPasswordField || control == socketPasswordField || control == sshPasswordField)
	{
		// Determine the correct password field to read the password from, defaulting to standard
		if (control == socketPasswordField) {
			passwordValue = [socketPasswordField stringValue];
		} 
		else if (control == sshPasswordField) {
			passwordValue = [sshPasswordField stringValue];
		} 
		else {
			passwordValue = [standardPasswordField stringValue];
		}
		
		// Get the old keychain name and account strings
		oldKeychainName = [keychain nameForFavoriteName:[oldFavorite objectForKey:SPFavoriteNameKey] id:[newFavorite objectForKey:SPFavoriteIDKey]];
		oldKeychainAccount = [keychain accountForUser:[oldFavorite objectForKey:SPFavoriteUserKey] host:oldHostnameForPassword database:[oldFavorite objectForKey:SPFavoriteDatabaseKey]];
		
		// Delete the old keychain item
		[keychain deletePasswordForName:oldKeychainName account:oldKeychainAccount];
		
		// Set up the new keychain name and account strings
		newKeychainName = [keychain nameForFavoriteName:[newFavorite objectForKey:SPFavoriteNameKey] id:[newFavorite objectForKey:SPFavoriteIDKey]];
		newKeychainAccount = [keychain accountForUser:[newFavorite objectForKey:SPFavoriteUserKey] host:newHostnameForPassword database:[newFavorite objectForKey:SPFavoriteDatabaseKey]];
		
		// Add the new keychain item if the password field has a value
		if ([passwordValue length]) {
			[keychain addPassword:passwordValue forName:newKeychainName account:newKeychainAccount];
		}
		
		// Synch password changes
		[standardPasswordField setStringValue:passwordValue];
		[socketPasswordField setStringValue:passwordValue];
		[sshPasswordField setStringValue:passwordValue];
		
		passwordValue = @"";
	}
	
	// If SSH account/password details have changed, update the keychain to match
	if (![[oldFavorite objectForKey:SPFavoriteNameKey] isEqualToString:[newFavorite objectForKey:SPFavoriteNameKey]] ||
		![[oldFavorite objectForKey:SPFavoriteSSHHostKey] isEqualToString:[newFavorite objectForKey:SPFavoriteSSHHostKey]] ||
		![[oldFavorite objectForKey:SPFavoriteSSHUserKey] isEqualToString:[newFavorite objectForKey:SPFavoriteSSHUserKey]] ||
		control == sshSSHPasswordField) 
	{
		// Get the old keychain name and account strings
		oldKeychainName = [keychain nameForSSHForFavoriteName:[oldFavorite objectForKey:SPFavoriteNameKey] id:[newFavorite objectForKey:SPFavoriteIDKey]];
		oldKeychainAccount = [keychain accountForSSHUser:[oldFavorite objectForKey:SPFavoriteSSHUserKey] sshHost:[oldFavorite objectForKey:SPFavoriteSSHHostKey]];
		
		// Delete the old keychain item
		[keychain deletePasswordForName:oldKeychainName account:oldKeychainAccount];
		
		// Set up the new keychain name and account strings
		newKeychainName = [keychain nameForSSHForFavoriteName:[newFavorite objectForKey:SPFavoriteNameKey] id:[newFavorite objectForKey:SPFavoriteIDKey]];
		newKeychainAccount = [keychain accountForSSHUser:[newFavorite objectForKey:SPFavoriteSSHUserKey] sshHost:[newFavorite objectForKey:SPFavoriteSSHHostKey]];
		
		// Add the new keychain item if the password field has a value
		if ([[sshPasswordField stringValue] length]) {
			[keychain addPassword:[sshSSHPasswordField stringValue] forName:newKeychainName account:newKeychainAccount];
		}
	}
	
	// Update the current favorite
	if (currentFavorite) [currentFavorite release], currentFavorite = nil;
	
	if ([[favoritesOutlineView selectedRowIndexes] count]) {
		currentFavorite = [[[self selectedFavoriteNode] representedObject] copy];
	}
}

#pragma mark -

- (void)dealloc
{
    [keychain release];
    [prefs release];
	
	[folderImage release], folderImage = nil;
	
	for (id retainedObject in nibObjectsToRelease) [retainedObject release];
	
	[nibObjectsToRelease release];
	
	if (mySQLConnection) [mySQLConnection release];
	if (sshTunnel) [sshTunnel setConnectionStateChangeSelector:nil delegate:nil], [sshTunnel disconnect], [sshTunnel release];
	if (connectionKeychainItemName) [connectionKeychainItemName release];
	if (connectionKeychainItemAccount) [connectionKeychainItemAccount release];
	if (connectionSSHKeychainItemName) [connectionSSHKeychainItemName release];
	if (connectionSSHKeychainItemAccount) [connectionSSHKeychainItemAccount release];
	if (currentFavorite) [currentFavorite release], currentFavorite = nil;
	if (favoritesRoot) [favoritesRoot release], favoritesRoot = nil;
    
    [super dealloc];
}

@end
