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
#import "SPAppController.h"
#import "SPPreferenceController.h"
#import "ImageAndTextCell.h"
#import "RegexKitLite.h"
#import "SPConstants.h"
#import "SPAlertSheets.h"

@interface SPConnectionController (PrivateAPI)

- (void)_sortFavorites;
- (void)_restoreConnectionInterface;
- (void)_mySQLConnectionEstablished;
- (void)_initiateMySQLConnectionInBackground;

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
@synthesize sshHost;
@synthesize sshUser;
@synthesize sshPassword;
@synthesize sshPort;

@synthesize connectionKeychainItemName;
@synthesize connectionKeychainItemAccount;
@synthesize connectionSSHKeychainItemName;
@synthesize connectionSSHKeychainItemAccount;

@synthesize isConnecting;

#pragma mark -

/**
 * Initialise the connection controller, linking it to the
 * parent document and setting up the parent window.
 */
- (id) initWithDocument:(SPDatabaseDocument *)theTableDocument
{
	if (self = [super init]) {
		tableDocument = theTableDocument;
		databaseConnectionSuperview = [tableDocument parentView];
		databaseConnectionView = [tableDocument valueForKey:@"contentViewSplitter"];
		connectionKeychainItemName = nil;
		connectionKeychainItemAccount = nil;
		connectionSSHKeychainItemName = nil;
		connectionSSHKeychainItemAccount = nil;
		mySQLConnection = nil;
		sshTunnel = nil;
		cancellingConnection = NO;
		isConnecting = NO;
		mySQLConnectionCancelled = NO;
        favoritesPBoardType = @"FavoritesPBoardType";

		// Load the connection nib, keeping references to the top-level objects for later release
		nibObjectsToRelease = [[NSMutableArray alloc] init];
		NSArray *connectionViewTopLevelObjects = nil;
		NSNib *nibLoader = [[NSNib alloc] initWithNibNamed:@"ConnectionView" bundle:[NSBundle mainBundle]];
		[nibLoader instantiateNibWithOwner:self topLevelObjects:&connectionViewTopLevelObjects];
		[nibObjectsToRelease addObjectsFromArray:connectionViewTopLevelObjects];
		[nibLoader release];
		
		// Hide the main view and position and display the connection view
		[databaseConnectionView setHidden:YES];
		[connectionView setFrame:[databaseConnectionView frame]];
		[databaseConnectionSuperview addSubview:connectionView];
		[connectionSplitView setPosition:[[tableDocument valueForKey:@"dbTablesTableView"] frame].size.width-6 ofDividerAtIndex:0];
		[connectionSplitViewButtonBar setSplitViewDelegate:self];
		
		// Set up a keychain instance and preferences reference, and create the initial favorites list
		keychain = [[SPKeychain alloc] init];
		prefs = [[NSUserDefaults standardUserDefaults] retain];
		favorites = nil;
		[self updateFavorites];
        
		// Register an observer for changes within the favorites
		[prefs addObserver:self forKeyPath:SPFavorites options:NSKeyValueObservingOptionNew context:NULL];

        // Set sort items
        currentSortItem = [prefs integerForKey:SPFavoritesSortedBy];
        reverseFavoritesSort = [prefs boolForKey:SPFavoritesSortedInReverse];
        
		// Register double click for the favorites view (double click favorite to connect)
		[favoritesTable setTarget:self];
		[favoritesTable setDoubleAction:@selector(initiateConnection:)];
        [favoritesTable registerForDraggedTypes:[NSArray arrayWithObject:favoritesPBoardType]];
        [favoritesTable setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES];

		// Sort the favourites to match prefs and select the appropriate row
		if (currentSortItem > -1) [self _sortFavorites];
		
		NSInteger tableRow = ([prefs integerForKey:[prefs boolForKey:SPSelectLastFavoriteUsed] ? SPLastFavoriteIndex : SPDefaultFavorite] + 1);
		
		if (tableRow < [favorites count]) {
			previousType = [[[favorites objectAtIndex:tableRow] objectForKey:@"type"] integerValue];
			[self resizeTabViewToConnectionType:[[[favorites objectAtIndex:tableRow] objectForKey:@"type"] integerValue] animating:NO];
			[favoritesTable selectRowIndexes:[NSIndexSet indexSetWithIndex:tableRow] byExtendingSelection:NO];
			[favoritesTable scrollRowToVisible:[favoritesTable selectedRow]];
		} else {
			previousType = SPTCPIPConnection;
			[self resizeTabViewToConnectionType:SPTCPIPConnection animating:NO];
		}
	}
	return self;
}

- (void) dealloc
{
    [prefs removeObserver:self forKeyPath:SPFavorites];
    [keychain release];
    [prefs release];

	for (id retainedObject in nibObjectsToRelease) [retainedObject release];
	[nibObjectsToRelease release];

	if (favorites) [favorites release];
	if (mySQLConnection) [mySQLConnection release];
	if (sshTunnel) [sshTunnel setConnectionStateChangeSelector:nil delegate:nil], [sshTunnel disconnect], [sshTunnel release];
	if (connectionKeychainItemName) [connectionKeychainItemName release];
	if (connectionKeychainItemAccount) [connectionKeychainItemAccount release];
	if (connectionSSHKeychainItemName) [connectionSSHKeychainItemName release];
	if (connectionSSHKeychainItemAccount) [connectionSSHKeychainItemAccount release];
    
    [super dealloc];
}

#pragma mark -
#pragma mark Connection processes

/*
 * Starts the connection process; invoked when user hits the connect button
 * or double-clicks on a favourite.
 * Error-checks fields as required, and triggers connection of MySQL or any
 * connection proxies in use.
 */
- (IBAction)initiateConnection:(id)sender
{	
	// Ensure that host is not empty if this is a TCP/IP or SSH connection
	if (([self type] == SPTCPIPConnection || [self type] == SPSSHTunnelConnection) && ![[self host] length]) {
		SPBeginAlertSheet(NSLocalizedString(@"Insufficient connection details", @"insufficient details message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [tableDocument parentWindow], self, nil, nil, NSLocalizedString(@"Insufficient details provided to establish a connection. Please enter at least the hostname.", @"insufficient details informative message"));		
		return;
	}
	
	// If SSH is enabled, ensure that the SSH host is not nil
	if ([self type] == SPSSHTunnelConnection && ![[self sshHost] length]) {
		SPBeginAlertSheet(NSLocalizedString(@"Insufficient connection details", @"insufficient details message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [tableDocument parentWindow], self, nil, nil, NSLocalizedString(@"Insufficient details provided to establish a connection. Please enter the hostname for the SSH Tunnel, or disable the SSH Tunnel.", @"insufficient SSH tunnel details informative message"));
		return;
	}

	// Ensure that a socket connection is not inadvertently used
	if (![self checkHost]) return;
	
	// Basic details have validated - start the connection process animating
	isConnecting = YES;
	cancellingConnection = NO;
	
	[addToFavoritesButton setHidden:YES];
	[addToFavoritesButton display];
	[helpButton setHidden:YES];
	[helpButton display];
	[connectButton setEnabled:NO];
	[connectButton display];
	[progressIndicator startAnimation:self];
	[progressIndicator display];
	[progressIndicatorText setHidden:NO];
	[progressIndicatorText display];
	
	// Start the current tab's progress indicator
	[tableDocument setIsProcessing:YES];

	// If the password(s) are marked as having been originally sourced from a keychain, check whether they
	// have been changed or not; if not, leave the mark in place and remove the password from the field
	// for increased security.
	if (connectionKeychainItemName) {
		if ([[keychain getPasswordForName:connectionKeychainItemName account:connectionKeychainItemAccount] isEqualToString:[self password]]) {
			[self setPassword:[[NSString string] stringByPaddingToLength:[[self password] length] withString:@"sp" startingAtIndex:0]];
			[[standardPasswordField undoManager] removeAllActionsWithTarget:standardPasswordField];
			[[socketPasswordField undoManager] removeAllActionsWithTarget:socketPasswordField];
			[[sshPasswordField undoManager] removeAllActionsWithTarget:sshPasswordField];
		} else {
			[connectionKeychainItemName release], connectionKeychainItemName = nil;
			[connectionKeychainItemAccount release], connectionKeychainItemAccount = nil;
		}
	}
	if (connectionSSHKeychainItemName) {
		if ([[keychain getPasswordForName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount] isEqualToString:[self sshPassword]]) {
			[self setSshPassword:[[NSString string] stringByPaddingToLength:[[self sshPassword] length] withString:@"sp" startingAtIndex:0]];
			[[sshSSHPasswordField undoManager] removeAllActionsWithTarget:sshSSHPasswordField];
		} else {
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
	[progressIndicatorText setStringValue:NSLocalizedString(@"Cancelling...", @"cancelling task status message")];
	[progressIndicatorText display];
	
	mySQLConnectionCancelled = YES;
}

/*
 * Initiate the SSH connection process.
 * This should only be called as part of initiateConnection:, and will indirectly
 * call initiateMySQLConnection if it's successful.
 */
- (void)initiateSSHTunnelConnection
{
	[progressIndicatorText setStringValue:NSLocalizedString(@"SSH connecting...", @"SSH connecting very short status message")];
	[progressIndicatorText display];
	
	// Trim whitespace and newlines from the SSH host field before attempting to connect
	[self setSshHost:[[self sshHost] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];

	// Set up the tunnel details
	sshTunnel = [[SPSSHTunnel alloc] initToHost:[self sshHost] port:([[self sshPort] length]?[[self sshPort] integerValue]:22) login:[self sshUser] tunnellingToPort:([[self port] length]?[[self port] integerValue]:3306) onHost:[self host]];
	[sshTunnel setParentWindow:[tableDocument parentWindow]];
	
	// Add keychain or plaintext password as appropriate - note the checks in initiateConnection.
	if (connectionSSHKeychainItemName) {
		[sshTunnel setPasswordKeychainName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount];
	} else if (sshPassword) {
		[sshTunnel setPassword:[self sshPassword]];
	}

	// Set the callback function on the tunnel
	[sshTunnel setConnectionStateChangeSelector:@selector(sshTunnelCallback:) delegate:self];

	// Ask the tunnel to connect.  This will call the callback below on success or failure, passing
	// itself as an argument - retain count should be one at this point.
	[sshTunnel connect];
}

/*
 * Cancel connection.
 * Currently only cleans up the SSH connection (MySQL connection isn't threaded)
 */
- (void)cancelConnection
{
	if (!sshTunnel) return;
	cancellingConnection = YES;
	[sshTunnel disconnect];
	[sshTunnel release];
	sshTunnel = nil;
}

/*
 * A callback function for the SSH Tunnel setup process - will be called on a connection
 * state change, allowing connection to fail or proceed as appropriate.  If successful,
 * will call initiateMySQLConnection.
 */
- (void)sshTunnelCallback:(SPSSHTunnel *)theTunnel
{
	if (cancellingConnection) return;
	NSInteger newState = [theTunnel state];

	if (newState == PROXY_STATE_IDLE) {
		[tableDocument setTitlebarStatus:@"SSH Disconnected"];
		[self failConnectionWithTitle:NSLocalizedString(@"SSH connection failed!", @"SSH connection failed title") errorMessage:[theTunnel lastError] detail:[sshTunnel debugMessages]];
	} else if (newState == PROXY_STATE_CONNECTED) {
		[tableDocument setTitlebarStatus:@"SSH Connected"];
		[self initiateMySQLConnection];
	} else {
		[tableDocument setTitlebarStatus:@"SSH Connecting…"];
	}
}

/*
 * Set up the MySQL connection, either through a successful tunnel or directly in the background.
 */
- (void)initiateMySQLConnection
{
	// Disable the favorites table view to prevent further connections attempts
	[favoritesTable setEnabled:NO];
	
	if (sshTunnel)
		[progressIndicatorText setStringValue:NSLocalizedString(@"MySQL connecting...", @"MySQL connecting very short status message")];
	else
		[progressIndicatorText setStringValue:NSLocalizedString(@"Connecting...", @"Generic connecting very short status message")];
	
	[progressIndicatorText display];

	[connectButton setTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	[connectButton setAction:@selector(cancelMySQLConnection:)];
	[connectButton setEnabled:YES];
	[connectButton display];
	
	[NSThread detachNewThreadSelector:@selector(_initiateMySQLConnectionInBackground) toTarget:self withObject:nil];
}

/*
 * Ends a connection attempt by stopping the connection animation and
 * displaying a specified error message.
 */
- (void)failConnectionWithTitle:(NSString *)theTitle errorMessage:(NSString *)theErrorMessage detail:(NSString *)errorDetail
{
	BOOL isSSHTunnelBindError = NO;
	
	// Clean up the interface
	[progressIndicator stopAnimation:self];
	[progressIndicator display];
	[progressIndicatorText setHidden:YES];
	[progressIndicatorText display];
	[addToFavoritesButton setHidden:NO];
	[addToFavoritesButton display];
	[connectButton setEnabled:YES];
	[tableDocument clearStatusIcon];
	
	// Release as appropriate
	if (sshTunnel) {
		[sshTunnel disconnect], [sshTunnel release], sshTunnel = nil;
		
		// If the SSH tunnel connection failed because the port it was trying to bind to was already in use take note
		// of it so we can give the user the option of connecting via standard connection and use the existing tunnel. 
		if ([theErrorMessage rangeOfString:@"bind"].location != NSNotFound) {
			isSSHTunnelBindError = YES;
		}
	}
	
	if (errorDetail) [errorDetailText setString:errorDetail];
	
	// Inform the delegate that the connection attempt failed
	if (delegate && [delegate respondsToSelector:@selector(connectionControllerConnectAttemptFailed:)]) {
		[delegate connectionControllerConnectAttemptFailed:self];
	}

	// Only display the connection error message if there is a window visible
	if ([[tableDocument parentWindow] isVisible]) {
		SPBeginAlertSheet(theTitle, NSLocalizedString(@"OK", @"OK button"), (errorDetail) ? NSLocalizedString(@"Show Detail", @"Show detail button") : nil, (isSSHTunnelBindError) ? NSLocalizedString(@"Use Standard Connection", @"use standard connection button") : nil, [tableDocument parentWindow], self, @selector(connectionFailureSheetDidEnd:returnCode:contextInfo:), @"connect", theErrorMessage);
	}
}

/**
 * Alert sheet callback method - invoked when an error sheet is closed.
 */
- (void)connectionFailureSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{	
	
	// Restore the passwords from keychain for editing if appropriate
	if (connectionKeychainItemName) {
		[self setPassword:[keychain getPasswordForName:connectionKeychainItemName account:connectionKeychainItemAccount]];
	}
	if (connectionSSHKeychainItemName) {
		[self setSshPassword:[keychain getPasswordForName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount]];
	}
	
	if (returnCode == NSAlertAlternateReturn) {
		[errorDetailText setFont:[NSFont userFontOfSize:12]];
		[errorDetailText setAlignment:NSLeftTextAlignment];
		[errorDetailWindow makeKeyAndOrderFront:self];
	}
	// Currently only SSH port bind errors offer a 3rd option in the error dialog, but if this ever changes
	// this will definitely need to be updated.
	else if (returnCode == NSAlertOtherReturn) {
		// Extract the local port number that SSH attempted to bind to from the debug output
		NSString *tunnelPort = [[[errorDetailText string] componentsMatchedByRegex:@"LOCALHOST:([0-9]+)" capture:1L] lastObject];
		
		// Change the connection type to standard TCP/IP
		[self setType:SPTCPIPConnection];
				
		// Change connection details
		[self setPort:tunnelPort];
		[self setHost:@"127.0.0.1"];
				
		// Change to standard TCP/IP connection view
		[self resizeTabViewToConnectionType:SPTCPIPConnection animating:YES];
		
		// Initiate the connection after half a second to give the connection view a chance to resize
		[self performSelector:@selector(initiateConnection:) withObject:self afterDelay:0.5];				
	}
}

/**
 * Add the connection to the parent document and restore the
 * interface, allowing the application to run as normal.
 */
- (void)addConnectionToDocument
{
	
	// Hide the connection view and restore the main view
	[connectionView removeFromSuperviewWithoutNeedingDisplay];
	[databaseConnectionView setHidden:NO];

	// Restore the toolbar icons
	NSArray *toolbarItems = [[[tableDocument parentWindow] toolbar] items];
	for (NSInteger i = 0; i < [toolbarItems count]; i++) [[toolbarItems objectAtIndex:i] setEnabled:YES];

	// Set keychain id for saving SPF files
	if([self valueForKeyPath:@"selectedFavorite.id"])
		[tableDocument setKeychainID:[[self valueForKeyPath:@"selectedFavorite.id"] stringValue]];
	else
		[tableDocument setKeychainID:@""];

	// Pass the connection to the table document, allowing it to set
	// up the other classes and the rest of the interface.
	[tableDocument setConnection:mySQLConnection];

}

#pragma mark -
#pragma mark Interface interaction

/**
 * Opens the preferences window, or brings it to the front, and switch to the favorites tab.
 * If a favorite is selected in the connection sheet, it is also select in the prefs window.
 */
- (IBAction)editFavorites:(id)sender
{
	SPPreferenceController *prefsController = [[NSApp delegate] preferenceController];
	
	[prefsController showWindow:self];
	[prefsController displayFavoritePreferences:self];
		
	if ([favoritesTable numberOfSelectedRows]) [prefsController selectFavorites:[NSArray arrayWithObject:[self valueForKeyPath:@"selectedFavorite"]]];	
}

/**
 * Show connection help.
 */
- (IBAction)showHelp:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:SPGettingConnectedDocURL]];
}

#pragma mark -
#pragma mark Connection details interaction and display

/**
 * Trigger a resize action whenever the tab view changes.  The connection
 * detail forms are held within container views, which are of a fixed width;
 * the tabview and buttons are contained within a resizable view which
 * is set to dimensions based on the container views, allowing the view
 * to be sized according to the detail type.
 */
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	NSInteger selectedTabView = [tabView indexOfTabViewItem:tabViewItem];

	// Deselect any selected favorite for manual changes
	if (!automaticFavoriteSelection) [favoritesTable deselectAll:self];
	automaticFavoriteSelection = NO;

	if (selectedTabView == previousType) return;
	
	[self resizeTabViewToConnectionType:selectedTabView animating:YES];
	
	// Update the host as appropriate
	if ((selectedTabView != SPSocketConnection) && [[self host] isEqualToString:@"localhost"]) {
		[self setHost:@""];
	}

	previousType = selectedTabView;
}

/**
 * When a favorite is selected, and the connection details are edited, deselect the favorite;
 * this is clearer and also prevents a failed connection from being repopulated with the
 * favorite's details instead of the last used details.
 */
- (void)controlTextDidChange:(NSNotification *)aNotification
{
	[favoritesTable deselectAll:self];
}

/**
 * When a host field finishes editing, ensure that it hasn't been set to "localhost"
 * to ensure that socket connections don't inadvertently occur.
 */
- (void)controlTextDidEndEditing:(NSNotification *)notification
{
	if ([notification object] == standardSQLHostField || [notification object] == sshSQLHostField) {
		[self checkHost];
	}
}

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
			break;
		case SPSocketConnection:
			targetResizeRect = [socketConnectionFormContainer frame];
			break;
		case SPSSHTunnelConnection:
			targetResizeRect = [sshConnectionFormContainer frame];
			break;
	} 

	frameRect.size.height = targetResizeRect.size.height + additionalFormHeight;

	if (animate) {
		[[connectionResizeContainer animator] setFrame:frameRect];
	} else {
		[connectionResizeContainer setFrame:frameRect];	
	}
}

/**
 * Check the host field and ensure it isn't set to "localhost" for
 * non-socket connections.
 */
- (BOOL)checkHost
{
	if ([self type] != SPSocketConnection && [[self host] isEqualToString:@"localhost"]) {
		SPBeginAlertSheet(NSLocalizedString(@"You have entered 'localhost' for a non-socket connection", @"title of error when using 'localhost' for a network connection"),
							NSLocalizedString(@"Use 127.0.0.1", @"Use 127.0.0.1 button"),	// Main button
							NSLocalizedString(@"Connect via socket", @"Connect via socket button"),	// Alternate button
							nil,	// Other button
							[tableDocument parentWindow],	// Window to attach to
							self,	// Modal delegate
							@selector(localhostErrorSheetDidEnd:returnCode:contextInfo:),	// Did end selector
							nil,	// Contextual info for selectors
							NSLocalizedString(@"To MySQL, 'localhost' is a special host and means that a socket connection should be used.\n\nDid you mean to use a socket connection, or to connect to the local machine via a port?  If you meant to connect via a port, '127.0.0.1' should be used instead of 'localhost'.", @"message of error when using 'localhost' for a network connection"));
		return NO;
	}

	return YES;
}

/**
 * Alert sheet callback method - invoked when the error sheet is closed.
 */
- (void)localhostErrorSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{	
	if (returnCode == NSAlertAlternateReturn) {
		[self setType:SPSocketConnection];
		[self setHost:@""];
	} else {
		[self setHost:@"127.0.0.1"];
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
	
	if (previousSortItem > -1) [[[sender menu] itemAtIndex:previousSortItem] setState:NSOffState];
	
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
	
	[sender setState:reverseFavoritesSort]; 
}

/**
 * Updates the local favorites array from the user defaults
 */
- (void)updateFavorites
{
	[favoritesTable deselectAll:self];
	if (favorites) [favorites release];
	if ([prefs objectForKey:SPFavorites]) {
		favorites = [[NSMutableArray alloc] initWithArray:[prefs objectForKey:SPFavorites]];
	} else {
		favorites = [[NSMutableArray alloc] init];
	}
	[favorites insertObject:[NSDictionary dictionaryWithObject:@"FAVORITES" forKey:@"name"] atIndex:0];
	[favoritesTable reloadData];
}

/**
 * Sets fields for the chosen favorite.
 */
- (void)updateFavoriteSelection:(id)sender
{

	// If nothing is selected, return without updating the interface
	if (![self selectedFavorite]) return;

	automaticFavoriteSelection = YES;

	// Clear the keychain referral items as appropriate
	if (connectionKeychainItemName) [connectionKeychainItemName release], connectionKeychainItemName = nil;
	if (connectionKeychainItemAccount) [connectionKeychainItemAccount release], connectionKeychainItemAccount = nil;
	if (connectionSSHKeychainItemName) [connectionSSHKeychainItemName release], connectionSSHKeychainItemName = nil;
	if (connectionSSHKeychainItemAccount) [connectionSSHKeychainItemAccount release], connectionSSHKeychainItemAccount = nil;
	
	// Update key-value properties from the selected favourite, using empty strings where not found
	[self setType:([self valueForKeyPath:@"selectedFavorite.type"] ? [[self valueForKeyPath:@"selectedFavorite.type"] integerValue] : SPTCPIPConnection)];
	[self setName:([self valueForKeyPath:@"selectedFavorite.name"] ? [self valueForKeyPath:@"selectedFavorite.name"] : @"")];
	[self setHost:([self valueForKeyPath:@"selectedFavorite.host"] ? [self valueForKeyPath:@"selectedFavorite.host"] : @"")];
	[self setSocket:([self valueForKeyPath:@"selectedFavorite.socket"] ? [self valueForKeyPath:@"selectedFavorite.socket"] : @"")];
	[self setUser:([self valueForKeyPath:@"selectedFavorite.user"] ? [self valueForKeyPath:@"selectedFavorite.user"] : @"")];
	[self setPort:([self valueForKeyPath:@"selectedFavorite.port"] ? [self valueForKeyPath:@"selectedFavorite.port"] : @"")];
	[self setDatabase:([self valueForKeyPath:@"selectedFavorite.database"] ? [self valueForKeyPath:@"selectedFavorite.database"] : @"")];
	[self setSshHost:([self valueForKeyPath:@"selectedFavorite.sshHost"] ? [self valueForKeyPath:@"selectedFavorite.sshHost"] : @"")];
	[self setSshUser:([self valueForKeyPath:@"selectedFavorite.sshUser"] ? [self valueForKeyPath:@"selectedFavorite.sshUser"] : @"")];
	[self setSshPort:([self valueForKeyPath:@"selectedFavorite.sshPort"] ? [self valueForKeyPath:@"selectedFavorite.sshPort"] : @"")];

	// Check whether the password exists in the keychain, and if so add it; also record the
	// keychain details so we can pass around only those details if the password doesn't change
	connectionKeychainItemName = [[keychain nameForFavoriteName:[self valueForKeyPath:@"selectedFavorite.name"] id:[self valueForKeyPath:@"selectedFavorite.id"]] retain];
	connectionKeychainItemAccount = [[keychain accountForUser:[self valueForKeyPath:@"selectedFavorite.user"] host:(([self type] == SPSocketConnection)?@"localhost":[self valueForKeyPath:@"selectedFavorite.host"]) database:[self valueForKeyPath:@"selectedFavorite.database"]] retain];
	[self setPassword:[keychain getPasswordForName:connectionKeychainItemName account:connectionKeychainItemAccount]];
	if (![[self password] length]) {
		[self setPassword:nil];
		[connectionKeychainItemName release], connectionKeychainItemName = nil;
		[connectionKeychainItemAccount release], connectionKeychainItemAccount = nil;
	}

	// And the same for the SSH password
	connectionSSHKeychainItemName = [[keychain nameForSSHForFavoriteName:[self valueForKeyPath:@"selectedFavorite.name"] id:[self valueForKeyPath:@"selectedFavorite.id"]] retain];
	connectionSSHKeychainItemAccount = [[keychain accountForSSHUser:[self valueForKeyPath:@"selectedFavorite.sshUser"] sshHost:[self valueForKeyPath:@"selectedFavorite.sshHost"]] retain];
	[self setSshPassword:[keychain getPasswordForName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount]];
	if (![[self sshPassword] length]) {
		[self setSshPassword:nil];
		[connectionSSHKeychainItemName release], connectionSSHKeychainItemName = nil;
		[connectionSSHKeychainItemAccount release], connectionSSHKeychainItemAccount = nil;
	}
	
	[prefs setInteger:([favoritesTable selectedRow] - 1) forKey:SPLastFavoriteIndex];


	// Set first responder to password field if it is empty
	switch([self type]) {
		case SPTCPIPConnection:
		if(![[standardPasswordField stringValue] length])
			[[tableDocument parentWindow] makeFirstResponder:standardPasswordField];
		break;
		case SPSocketConnection:
		if(![[socketPasswordField stringValue] length])
			[[tableDocument parentWindow] makeFirstResponder:socketPasswordField];
		break;
		case SPSSHTunnelConnection:
		if(![[sshPasswordField stringValue] length])
			[[tableDocument parentWindow] makeFirstResponder:sshPasswordField];
		break;
	}
}

/**
 * Returns a KVC-compliant proxy to the currently selected favorite, or nil if nothing selected.
 */
- (id)selectedFavorite
{
	if ([favoritesTable selectedRow] == -1)
		return nil;
	
	return [favorites objectAtIndex:[favoritesTable selectedRow]];
}

/**
 * Adds the current details as a new favorite, select it, and scroll the selected
 * row to visible.
 */
- (IBAction)addFavorite:(id)sender
{
	NSString *thePassword, *theSSHPassword;
	NSNumber *favoriteid = [NSNumber numberWithInteger:[[NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]] hash]];
	NSString *favoriteName = [[self name] length]?[self name]:[NSString stringWithFormat:@"%@@%@", ([self user] && [[self user] length])?[self user]:@"anonymous", (([self type] == SPSocketConnection)?@"localhost":[self host])];
	if (![[self name] length] && [self database] && ![[self database] isEqualToString:@""])
		favoriteName = [NSString stringWithFormat:@"%@ %@", [self database], favoriteName];
	
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
	if (![self checkHost]) return;
	
	// Construct the favorite details - cannot use only dictionaryWithObjectsAndKeys for possible nil values.
	NSMutableDictionary *newFavorite = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithInteger:[self type]], @"type",
										favoriteName, @"name",
										favoriteid, @"id",
										nil];
	if ([self host]) [newFavorite setObject:[self host] forKey:@"host"];
	if ([self socket]) [newFavorite setObject:[self socket] forKey:@"socket"];
	if ([self user]) [newFavorite setObject:[self user] forKey:@"user"];
	if ([self port]) [newFavorite setObject:[self port] forKey:@"port"];
	if ([self database]) [newFavorite setObject:[self database] forKey:@"database"];
	if ([self sshHost]) [newFavorite setObject:[self sshHost] forKey:@"sshHost"];
	if ([self sshUser]) [newFavorite setObject:[self sshUser] forKey:@"sshUser"];
	if ([self sshPort]) [newFavorite setObject:[self sshPort] forKey:@"sshPort"];

	// Add the new favorite to the user defaults array
	NSMutableArray *currentFavorites;
	if ([prefs objectForKey:SPFavorites]) {
		currentFavorites = [[NSMutableArray alloc] initWithArray:[prefs objectForKey:SPFavorites]];
	} else {
		currentFavorites = [[NSMutableArray alloc] init];
	}
	[currentFavorites addObject:newFavorite];
	[prefs setObject:[NSArray arrayWithArray:currentFavorites] forKey:SPFavorites];
	[currentFavorites release];

	// Add the password to keychain as appropriate
	thePassword = [self password];
	if (mySQLConnection && connectionKeychainItemName) {
		thePassword = [keychain getPasswordForName:connectionKeychainItemName account:connectionKeychainItemAccount];
	}
	if (thePassword && ![thePassword isEqualToString:@""]) {
		[keychain addPassword:thePassword
					  forName:[keychain nameForFavoriteName:favoriteName id:[NSString stringWithFormat:@"%lld", [favoriteid longLongValue]]]
					  account:[keychain accountForUser:[self user] host:(([self type] == SPSocketConnection)?@"localhost":[self host]) database:[self database]]];
	}

	// Add the SSH password to keychain as appropriate
	theSSHPassword = [self sshPassword];
	if (mySQLConnection && connectionSSHKeychainItemName) {
		theSSHPassword = [keychain getPasswordForName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount];
	}
	if (theSSHPassword && ![theSSHPassword isEqualToString:@""]) {
		[keychain addPassword:theSSHPassword
					  forName:[keychain nameForSSHForFavoriteName:favoriteName id:[NSString stringWithFormat:@"%lld", [favoriteid longLongValue]]]
					  account:[keychain accountForSSHUser:[self sshUser] sshHost:[self sshHost]]];
	}

	// Update the favorites list and selection
	[self updateFavorites];
	[favoritesTable selectRowIndexes:[NSIndexSet indexSetWithIndex:[favorites count]-1] byExtendingSelection:NO];
	[favoritesTable scrollRowToVisible:[favoritesTable selectedRow]];

	[[[NSApp delegate] preferenceController] updateDefaultFavoritePopup];
}

/**
 * If the favorites list in the preferences change, trigger a reload of
 * the favorites table data.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	if ([keyPath isEqualToString:SPFavorites]) {
		[self updateFavorites];
	}
}

#pragma mark -
#pragma mark TableView drag & drop delegate methods

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    NSData *archivedData = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    [pboard declareTypes:[NSArray arrayWithObject:favoritesPBoardType] owner:self];
    [pboard setData:archivedData forType:favoritesPBoardType];
    return YES;
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    if (row == 0) return NSDragOperationNone;
    if ([info draggingSource] == aTableView)
    {
        [aTableView setDropRow:row dropOperation:NSTableViewDropAbove];
        return NSDragOperationMove;
    }
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
    BOOL acceptedDrop = NO;
    
	if ((row == 0) || ([info draggingSource] != aTableView))  return acceptedDrop;
	
	// Disable all automatic sorting
	currentSortItem = -1;
	reverseFavoritesSort = NO;
	
	[prefs setInteger:currentSortItem forKey:SPFavoritesSortedBy];
	[prefs setBool:NO forKey:SPFavoritesSortedInReverse];
	
	// Remove sort descriptors
	[favorites sortUsingDescriptors:[NSArray array]];
	
	// Uncheck sort by menu items
	for (NSMenuItem *menuItem in [[favoritesSortByMenuItem submenu] itemArray])
	{
		[menuItem setState:NSOffState];
	}
	
    NSPasteboard* pboard = [info draggingPasteboard];
    NSData* rowData = [pboard dataForType:favoritesPBoardType];
    NSIndexSet* rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
    NSInteger dragRow = [rowIndexes firstIndex];
    NSInteger defaultConnectionRow = [prefs integerForKey:SPLastFavoriteIndex];
    if (defaultConnectionRow == dragRow)
    {
        [prefs setInteger:row forKey:SPLastFavoriteIndex];
    }
    NSMutableDictionary *draggedFavorite = [favorites objectAtIndex:dragRow];
    [favorites removeObjectAtIndex:dragRow];
    if (row > [favorites count])
    {
        row--;
    }
    [favorites insertObject:draggedFavorite atIndex:row];
    [aTableView reloadData];
    [aTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    
	// reset the prefs with the new order
    NSMutableArray *reorderedFavorites = [[NSMutableArray alloc] initWithArray:favorites];
    [reorderedFavorites removeObjectAtIndex:0];
    [prefs setObject:reorderedFavorites forKey:SPFavorites];
	
	[[[NSApp delegate] preferenceController] updateDefaultFavoritePopup];
    
	[reorderedFavorites release];
    
	[self updateFavorites];
    
	acceptedDrop = YES;
	
    return acceptedDrop;
}

#pragma mark -
#pragma mark Favorites tableview datasource methods

/**
 * Returns the number of favorites to display
 */
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [favorites count];
}

/**
 * Returns the favorite names to be displayed in the table
 */
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return [[favorites objectAtIndex:rowIndex] objectForKey:@"name"];
}

#pragma mark -
#pragma mark Favorites tableview delegate methods

/**
 * Loads a favorite, if any are selected.
 */
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	if ([favoritesTable numberOfSelectedRows] == 1) {
		[self updateFavoriteSelection:self];
		[addToFavoritesButton setEnabled:NO];
	} else {
		[addToFavoritesButton setEnabled:YES];
	}
}

/**
 * Display the title row
 */
- (BOOL)tableView:(NSTableView *)aTableView isGroupRow:(NSInteger)rowIndex
{
	return (rowIndex == 0);	
}

/**
 * Don't allow the title row to be selected
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
	return (rowIndex != 0);
}

/**
 * Set the title row to display with extra height
 */
- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
	return (row == 0) ? 25 : 17;
}

/**
 * Control the display of rows within the favorites table
 */
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	[(ImageAndTextCell*)aCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];			
	if (rowIndex == 0) {
		[(ImageAndTextCell *)aCell setIndentationLevel:0];
	} else {
		[(ImageAndTextCell *)aCell setIndentationLevel:1];
	}
	if([favoritesTable isEnabled])
		[(ImageAndTextCell *)aCell setTextColor:[NSColor blackColor]];
	else
		[(ImageAndTextCell *)aCell setTextColor:[NSColor grayColor]];
}


#pragma mark -
#pragma mark SplitView delegate methods

/**
 * When the split view is resized, trigger a resize in the hidden table
 * width as well, to keep the connection view and connected view in synch.
 * Use this rather than splitViewDidResizeSubviews: as the latter is not
 * forwarded by the BWAnchoredButtonBar.
 */
- (CGFloat)splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)dividerIndex
{
	[databaseConnectionView setPosition:[[[connectionSplitView subviews] objectAtIndex:0] frame].size.width ofDividerAtIndex:0];
	
	return proposedPosition;
}

/**
 * Return the maximum possible size of the splitview.
 */
- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
	return (proposedMax - 445);
}

/**
 * Return the minimum possible size of the splitview.
 */
- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
	return (proposedMin + 80);
}

#pragma mark -
#pragma mark Menu Validation

-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    SEL action = [menuItem action];
    if ((action == @selector(sortFavorites:)) || (action == @selector(reverseSortFavorites:))) {
		
		// Loop all the items in the sort by menu only checking the currently selected one
		for (NSMenuItem *item in [[menuItem menu] itemArray])
		{
			[item setState:([[menuItem menu] indexOfItem:item] == currentSortItem) ? NSOnState : NSOffState];
		}
		
		// Check or uncheck the reverse sort item
		if (action == @selector(reverseSortFavorites:)) {
			[menuItem setState:reverseFavoritesSort];
		}
    }
    return YES;
    
}

#pragma mark -
#pragma mark Private API

/**
 * Sorts the connection favorites based on the selected criteria.
 */
- (void)_sortFavorites
{
    NSString *sortKey = @"";
	
	switch (currentSortItem)
	{
		case SPFavoritesSortNameItem:
			sortKey = @"name";
			break;
		case SPFavoritesSortHostItem:
			sortKey = @"host";
			break;
		case SPFavoritesSortTypeItem:
			sortKey = @"type";
			break;
		default:
			sortKey = @"name";
			break;
	}
	
	NSSortDescriptor *sortDescriptor = nil;
	
	if (currentSortItem == SPFavoritesSortTypeItem) {
		sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:sortKey ascending:(!reverseFavoritesSort)] autorelease];
	}
	else {
		sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:sortKey ascending:(!reverseFavoritesSort) selector:@selector(caseInsensitiveCompare:)] autorelease];
	}
	
	NSDictionary *first = [[favorites objectAtIndex:0] retain];
    
	[favorites removeObjectAtIndex:0];
	[favorites sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
	[favorites insertObject:first atIndex:0];
	[favoritesTable reloadData];
    
	[first release];
}

/**
 * Restores the connection interface to its original state.
 */
- (void)_restoreConnectionInterface
{
	// Must be performed on the main thread
	if (![NSThread isMainThread]) return [[self onMainThread] _restoreConnectionInterface];
	
	// Stop the current tab's progress indicator
	[tableDocument setIsProcessing:NO];
	
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
	[favoritesTable setEnabled:YES];
	[favoritesTable display];
	
	mySQLConnectionCancelled = NO;
	
	// Revert the connect button back to its original selector
	[connectButton setAction:@selector(initiateConnection:)];
}

/**
 * Called on the main thread once the MySQL connection is established on the background thread. Either the
 * connection was cancelled or it was successful. 
 */
- (void)_mySQLConnectionEstablished
{	
	isConnecting = NO;
	
	// If the user hit cancel during the connection attempt, kill the connection once 
	// established and reset the UI.
	if (mySQLConnectionCancelled) {		
		if ([mySQLConnection isConnected]) {
			[mySQLConnection disconnect];
			[mySQLConnection release], mySQLConnection = nil;
		}
		
		// Kill the SSH connection if present
		[self cancelConnection];
		
		[self _restoreConnectionInterface];
		
		return;
	}
	
	[progressIndicatorText setStringValue:NSLocalizedString(@"Connected", @"connection established message")];
	[progressIndicatorText display];
	
	// Stop the current tab's progress indicator
	[tableDocument setIsProcessing:NO];
	
	// Successful connection!
	[connectButton setEnabled:NO];
	[connectButton display];
	[progressIndicator stopAnimation:self];
	[progressIndicatorText setHidden:YES];
	[addToFavoritesButton setHidden:NO];
	
	// Re-enable favorites table view
	[favoritesTable setEnabled:YES];
	[favoritesTable display];
	
	// Release the tunnel if set - will now be retained by the connection
	if (sshTunnel) [sshTunnel release], sshTunnel = nil;
	
	// Pass the connection to the document and clean up the interface
	[self addConnectionToDocument];
}

/**
 * Initiates the core of the MySQL connection process on a background thread.
 */
- (void)_initiateMySQLConnectionInBackground
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
	// Initialise to socket if appropriate.
	if ([self type] == SPSocketConnection) {
		mySQLConnection = [[MCPConnection alloc] initToSocket:[self socket] withLogin:[self user]];
		
		// Otherwise, initialise to host, using tunnel if appropriate
	} else {
		if ([self type] == SPSSHTunnelConnection) {
			mySQLConnection = [[MCPConnection alloc] initToHost:@"127.0.0.1"
													  withLogin:[self user]
													  usingPort:[sshTunnel localPort]];
			[mySQLConnection setConnectionProxy:sshTunnel];
		} else {
			mySQLConnection = [[MCPConnection alloc] initToHost:[self host]
													  withLogin:[self user]
													  usingPort:([[self port] length]?[[self port] integerValue]:3306)];
		}
	}
	
	// Only set the password if there is no Keychain item set. The connection will ask the delegate for passwords in the Keychain.	
	if (!connectionKeychainItemName && [self password]) {
		[mySQLConnection setPassword:[self password]];
	}
	
	// Connection delegate must be set before actual connection attempt is made
	[mySQLConnection setDelegate:tableDocument];
	
	// Set whether or not we should enable delegate logging according to the prefs
	[mySQLConnection setDelegateQueryLogging:[prefs boolForKey:SPConsoleEnableLogging]];
	
	// Set options from preferences
	[mySQLConnection setConnectionTimeout:[[prefs objectForKey:SPConnectionTimeoutValue] integerValue]];
	[mySQLConnection setUseKeepAlive:[[prefs objectForKey:SPUseKeepAlive] boolValue]];
	[mySQLConnection setKeepAliveInterval:[[prefs objectForKey:SPKeepAliveInterval] doubleValue]];
	
	// Connect
	[mySQLConnection connect];
	
	if (![mySQLConnection isConnected]) {
		if (sshTunnel) {
			
			// If an SSH tunnel is running, temporarily block to allow the tunnel to register changes in state
			[[NSRunLoop currentRunLoop] runMode:NSModalPanelRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
			
			// If the state is connection refused, attempt the MySQL connection again with the host using the hostfield value.
			if ([sshTunnel state] == PROXY_STATE_FORWARDING_FAILED) {
				if ([sshTunnel localPortFallback]) {
					[mySQLConnection setPort:[sshTunnel localPortFallback]];
					[mySQLConnection connect];
					if (![mySQLConnection isConnected]) {
						[[NSRunLoop currentRunLoop] runMode:NSModalPanelRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
					}
				}
			}
		}
		
		if (![mySQLConnection isConnected]) {
			NSString *errorMessage = @"";
			if (sshTunnel && [sshTunnel state] == PROXY_STATE_FORWARDING_FAILED) {
				errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to host %@ because the port connection via SSH was refused.\n\nPlease ensure that your MySQL host is set up to allow TCP/IP connections (no --skip-networking) and is configured to allow connections from the host you are tunnelling via.\n\nYou may also want to check the port is correct and that you have the necessary privileges.\n\nChecking the error detail will show the SSH debug log which may provide more details.\n\nMySQL said: %@", @"message of panel when SSH port forwarding failed"), [self host], [mySQLConnection getLastErrorMessage]];
				[[self onMainThread] failConnectionWithTitle:NSLocalizedString(@"SSH port forwarding failed", @"title when ssh tunnel port forwarding failed") errorMessage:errorMessage detail:[sshTunnel debugMessages]];
			} else if ([mySQLConnection getLastErrorID] == 1045) { // "Access denied" error
				errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to host %@ because access was denied.\n\nDouble-check your username and password and ensure that access from your current location is permitted.\n\nMySQL said: %@", @"message of panel when connection to host failed due to access denied error"), [self host], [mySQLConnection getLastErrorMessage]];
				[[self onMainThread] failConnectionWithTitle:NSLocalizedString(@"Access denied!", @"connection failed due to access denied title") errorMessage:errorMessage detail:nil];
			} else if ([self type] == SPSocketConnection && (![self socket] || ![[self socket] length]) && ![mySQLConnection findSocketPath]) {
				errorMessage = [NSString stringWithFormat:NSLocalizedString(@"The socket file could not be found in any common location. Please supply the correct socket location.\n\nMySQL said: %@", @"message of panel when connection to socket failed because optional socket could not be found"), [mySQLConnection getLastErrorMessage]];
				[[self onMainThread] failConnectionWithTitle:NSLocalizedString(@"Socket not found!", @"socket not found title") errorMessage:errorMessage detail:nil];
			} else if ([self type] == SPSocketConnection) {
				errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Unable to connect via the socket, or the request timed out.\n\nDouble-check that the socket path is correct and that you have the necessary privileges, and that the server is running.\n\nMySQL said: %@", @"message of panel when connection to host failed"), [mySQLConnection getLastErrorMessage]];
				[[self onMainThread] failConnectionWithTitle:NSLocalizedString(@"Socket connection failed!", @"socket connection failed title") errorMessage:errorMessage detail:nil];
			} else {
				errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to host %@, or the request timed out.\n\nBe sure that the address is correct and that you have the necessary privileges, or try increasing the connection timeout (currently %ld seconds).\n\nMySQL said: %@", @"message of panel when connection to host failed"), [self host], (long)[[prefs objectForKey:SPConnectionTimeoutValue] integerValue], [mySQLConnection getLastErrorMessage]];
				[[self onMainThread] failConnectionWithTitle:NSLocalizedString(@"Connection failed!", @"connection failed title") errorMessage:errorMessage detail:nil];
			}
			
			// Tidy up
			isConnecting = NO;
			
			if (sshTunnel) [sshTunnel release], sshTunnel = nil;
			
			[mySQLConnection release], mySQLConnection = nil;
			[self _restoreConnectionInterface];
			[pool release];
			
			return;
		}
	}
	
	if ([self database] && ![[self database] isEqualToString:@""]) {
		if (![mySQLConnection selectDB:[self database]]) {
			[[self onMainThread] failConnectionWithTitle:NSLocalizedString(@"Could not select database", @"message when database selection failed") errorMessage:[NSString stringWithFormat:NSLocalizedString(@"Connected to host, but unable to connect to database %@.\n\nBe sure that the database exists and that you have the necessary privileges.\n\nMySQL said: %@", @"message of panel when connection to db failed"), [self database], [mySQLConnection getLastErrorMessage]] detail:nil];
			
			// Tidy up
			isConnecting = NO;
			
			if (sshTunnel) [sshTunnel release], sshTunnel = nil;
			
			[mySQLConnection release], mySQLConnection = nil;
			[self _restoreConnectionInterface];
			[pool release];
			
			return;
		}
	}
	
	// Connection established
	[self performSelectorOnMainThread:@selector(_mySQLConnectionEstablished) withObject:nil waitUntilDone:NO];
		
	[pool release];
}

@end

#pragma mark -
#pragma mark NSView subclass - flipped view for simpler drawing

/**
 * Add an implementation of a flipped view to simplify drawing.
 */
@implementation SPFlippedView: NSView

- (BOOL)isFlipped
{
    return YES;
}

@end
