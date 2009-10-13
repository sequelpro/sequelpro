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

@implementation SPConnectionController

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

/**
 * Initialise the connection controller, linking it to the
 * parent document and setting up the parent window.
 */
- (id) initWithDocument:(TableDocument *)theTableDocument
{
	if (self = [super init]) {
		tableDocument = theTableDocument;
		documentWindow = [tableDocument valueForKey:@"tableWindow"];
		contentView = [tableDocument valueForKey:@"contentViewSplitter"];
		connectionKeychainItemName = nil;
		connectionKeychainItemAccount = nil;
		connectionSSHKeychainItemName = nil;
		connectionSSHKeychainItemAccount = nil;
		mySQLConnection = nil;
		sshTunnel = nil;

		// Load the connection nib
		[NSBundle loadNibNamed:@"ConnectionView" owner:self];
		
		// Hide the main view and position and display the connection view
		[contentView setHidden:YES];
		[connectionView setFrame:[contentView frame]];
		[[documentWindow contentView] addSubview:connectionView];
		[connectionSplitView setPosition:[[tableDocument valueForKey:@"dbTablesTableView"] frame].size.width ofDividerAtIndex:0];
		[connectionSplitViewButtonBar setSplitViewDelegate:self];
		
		// Disable the toolbar icons
		NSArray *toolbarItems = [[documentWindow toolbar] items];
		for (int i = 0; i < [toolbarItems count]; i++) [[toolbarItems objectAtIndex:i] setEnabled:NO];
		
		// Set up a keychain instance and preferences reference, and create the initial favorites list
		keychain = [[SPKeychain alloc] init];
		prefs = [[NSUserDefaults standardUserDefaults] retain];
		favorites = nil;
		[self updateFavorites];

		// Register an observer for changes within the favorites
		[prefs addObserver:self forKeyPath:@"favorites" options:NSKeyValueObservingOptionNew context:NULL];

		// Register double click for the favorites view (double click favorite to connect)
		[favoritesTable setTarget:self];
		[favoritesTable setDoubleAction:@selector(initiateConnection:)];

		// Set the focus to the favorites table and select the appropriate row
		[documentWindow setInitialFirstResponder:favoritesTable];
		int tableRow;
		if ([prefs boolForKey:@"SelectLastFavoriteUsed"] == YES) {
			tableRow = [prefs integerForKey:@"LastFavoriteIndex"] + 1;
		} else {
			tableRow = [prefs integerForKey:@"DefaultFavorite"] + 1;
		}
		if (tableRow < [favorites count]) {
			previousType = [[[favorites objectAtIndex:tableRow] objectForKey:@"type"] intValue];
			[self resizeTabViewToConnectionType:[[[favorites objectAtIndex:tableRow] objectForKey:@"type"] intValue] animating:NO];
			[favoritesTable selectRowIndexes:[NSIndexSet indexSetWithIndex:tableRow] byExtendingSelection:NO];
			[favoritesTable scrollRowToVisible:[favoritesTable selectedRow]];
		} else {
			previousType = SP_CONNECTION_TCPIP;
			[self resizeTabViewToConnectionType:SP_CONNECTION_TCPIP animating:NO];
		}

		// If the document is set to automatically connect, do so.
		if ([tableDocument shouldAutomaticallyConnect]) {
			[self performSelector:@selector(initiateConnection:) withObject:self afterDelay:0.0];
		}
	}
	
	return self;
}

- (void) dealloc
{    
    [keychain release];
    [prefs release];
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
	if (([self type] == SP_CONNECTION_TCPIP || [self type] == SP_CONNECTION_SSHTUNNEL) && ![[self host] length]) {
		NSRunAlertPanel(NSLocalizedString(@"Insufficient connection details", @"insufficient details message"), NSLocalizedString(@"Insufficient details provided to establish a connection. Please provide at least a host.", @"insufficient details informative message"), NSLocalizedString(@"OK", @"OK button"), nil, nil);
		return;
	}
	
	// If SSH is enabled, ensure that the SSH host is not nil
	if ([self type] == SP_CONNECTION_SSHTUNNEL && ![[self sshHost] length]) {
		NSRunAlertPanel(NSLocalizedString(@"Insufficient connection details", @"insufficient details message"), NSLocalizedString(@"Please enter the hostname for the SSH Tunnel, or disable the SSH Tunnel.", @"message of panel when ssh details are incomplete"), NSLocalizedString(@"OK", @"OK button"), nil, nil);
		return;
	}

	// Ensure that a socket connection is not inadvertently used
	if (![self checkHost]) return;

	// Basic details have validated - start the connection process animating
	[addToFavoritesButton setHidden:YES];
	[helpButton setHidden:YES];
	[connectButton setEnabled:NO];
	[progressIndicator startAnimation:self];
	[progressIndicatorText setHidden:NO];
	[progressIndicatorText display];

	// If the password(s) are marked as having been originally sourced from a keychain, check whether they
	// have been changed or not; if not, leave the mark in place and remove the password from the field
	// for increased security.
	if (connectionKeychainItemName) {
		if ([[keychain getPasswordForName:connectionKeychainItemName account:connectionKeychainItemAccount] isEqualToString:[self password]]) {
			[self setPassword:[[NSString string] stringByPaddingToLength:[[self password] length] withString:@"sp" startingAtIndex:0]];
			[[tableDocument undoManager] removeAllActionsWithTarget:standardPasswordField];
			[[tableDocument undoManager] removeAllActionsWithTarget:socketPasswordField];
			[[tableDocument undoManager] removeAllActionsWithTarget:sshPasswordField];
		} else {
			[connectionKeychainItemName release], connectionKeychainItemName = nil;
			[connectionKeychainItemAccount release], connectionKeychainItemAccount = nil;
		}
	}
	if (connectionSSHKeychainItemName) {
		if ([[keychain getPasswordForName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount] isEqualToString:[self sshPassword]]) {
			[self setSshPassword:[[NSString string] stringByPaddingToLength:[[self sshPassword] length] withString:@"sp" startingAtIndex:0]];
			[[tableDocument undoManager] removeAllActionsWithTarget:sshSSHPasswordField];
		} else {
			[connectionSSHKeychainItemName release], connectionSSHKeychainItemName = nil;
			[connectionSSHKeychainItemAccount release], connectionSSHKeychainItemAccount = nil;
		}
	}

	// Initiate the SSH connection process for tunnels
	if ([self type] == SP_CONNECTION_SSHTUNNEL) {
		[self performSelector:@selector(initiateSSHTunnelConnection) withObject:nil afterDelay:0.0];
		return;
	}

	// ...or start the MySQL connection process directly	
	[self performSelector:@selector(initiateMySQLConnection) withObject:nil afterDelay:0.0];
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

	// Set up the tunnel details
	sshTunnel = [[SPSSHTunnel alloc] initToHost:[self sshHost] port:([[self sshPort] length]?[[self sshPort] intValue]:22) login:[self sshUser] tunnellingToPort:([[self port] length]?[[self port] intValue]:3306) onHost:[self host]];
	[sshTunnel setParentWindow:documentWindow];
	
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
 * A callback function for the SSH Tunnel setup process - will be called on a connection
 * state change, allowing connection to fail or proceed as appropriate.  If successful,
 * will call initiateMySQLConnection.
 */
- (void)sshTunnelCallback:(SPSSHTunnel *)theTunnel
{
	int newState = [theTunnel state];

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
 * Set up the MySQL connection, either through a successful tunnel or directly.
 */
- (void)initiateMySQLConnection
{
	if (sshTunnel)
		[progressIndicatorText setStringValue:NSLocalizedString(@"MySQL connecting...", @"MySQL connecting very short status message")];
	else
		[progressIndicatorText setStringValue:NSLocalizedString(@"Connecting...", @"Generic connecting very short status message")];
	
	[progressIndicatorText display];

	// Initialise to socket if appropriate.
	if ([self type] == SP_CONNECTION_SOCKET) {
		mySQLConnection = [[MCPConnection alloc] initToSocket:[self socket] withLogin:[self user]];

	// Otherwise, initialise to host, using tunnel if appropriate
	} else {
		if ([self type] == SP_CONNECTION_SSHTUNNEL) {
			mySQLConnection = [[MCPConnection alloc] initToHost:@"127.0.0.1"
														withLogin:[self user]
														usingPort:[sshTunnel localPort]];
			[mySQLConnection setConnectionProxy:sshTunnel];
		} else {
			mySQLConnection = [[MCPConnection alloc] initToHost:[self host]
														withLogin:[self user]
														usingPort:([[self port] length]?[[self port] intValue]:3306)];
		}
	}

	// Only set the password if there is no Keychain item set. The connection will ask the delegate for passwords in the Keychain.	
	if (!connectionKeychainItemName && [self password]) {
		[mySQLConnection setPassword:[self password]];
	}
	
	// Connection delegate must be set before actual connection attempt is made
	[mySQLConnection setDelegate:tableDocument];
	
	// Set whether or not we should enable delegate logging according to the prefs
	[mySQLConnection setDelegateQueryLogging:[prefs boolForKey:@"ConsoleEnableLogging"]];

	// Set options from preferences
	[mySQLConnection setConnectionTimeout:[[prefs objectForKey:@"ConnectionTimeoutValue"] intValue]];
	[mySQLConnection setUseKeepAlive:[[prefs objectForKey:@"UseKeepAlive"] boolValue]];
	[mySQLConnection setKeepAliveInterval:[[prefs objectForKey:@"KeepAliveInterval"] floatValue]];

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
			NSString *errorMessage;
			if (sshTunnel && [sshTunnel state] == PROXY_STATE_FORWARDING_FAILED) {
				errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to host %@ because the port connection via SSH was refused.\n\nPlease ensure that your MySQL host is set up to allow TCP/IP connections (no --skip-networking) and is configured to allow connections from the host you are tunnelling via.\n\nYou may also want to check the port is correct and that you have the necessary privileges.\n\nChecking the error detail will show the SSH debug log which may provide more details.\n\nMySQL said: %@", @"message of panel when SSH port forwarding failed"), [self host], [mySQLConnection getLastErrorMessage]];
				[self failConnectionWithTitle:NSLocalizedString(@"SSH port forwarding failed", @"title when ssh tunnel port forwarding failed") errorMessage:errorMessage detail:[sshTunnel debugMessages]];
			} else if ([mySQLConnection getLastErrorID] == 1045) { // "Access denied" error
				errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to host %@ because access was denied.\n\nDouble-check your username and password and ensure that access from your current location is permitted.\n\nMySQL said: %@", @"message of panel when connection to host failed due to access denied error"), [self host], [mySQLConnection getLastErrorMessage]];
				[self failConnectionWithTitle:NSLocalizedString(@"Access denied!", @"connection failed due to access denied title") errorMessage:errorMessage detail:nil];
			} else if ([self type] == SP_CONNECTION_SOCKET && (![self socket] || ![[self socket] length]) && ![mySQLConnection findSocketPath]) {
				errorMessage = [NSString stringWithFormat:NSLocalizedString(@"The socket file could not be found in any common location. Please supply the correct socket location.\n\nMySQL said: %@", @"message of panel when connection to socket failed because optional socket could not be found"), [mySQLConnection getLastErrorMessage]];
				[self failConnectionWithTitle:NSLocalizedString(@"Socket not found!", @"socket not found title") errorMessage:errorMessage detail:nil];
			} else if ([self type] == SP_CONNECTION_SOCKET) {
				errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Unable to connect via the socket, or the request timed out.\n\nDouble-check that the socket path is correct and that you have the necessary privileges, and that the server is running.\n\nMySQL said: %@", @"message of panel when connection to host failed"), [mySQLConnection getLastErrorMessage]];
				[self failConnectionWithTitle:NSLocalizedString(@"Socket connection failed!", @"socket connection failed title") errorMessage:errorMessage detail:nil];
			} else {
				errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to host %@, or the request timed out.\n\nBe sure that the address is correct and that you have the necessary privileges, or try increasing the connection timeout (currently %i seconds).\n\nMySQL said: %@", @"message of panel when connection to host failed"), [self host], [[prefs objectForKey:@"ConnectionTimeoutValue"] intValue], [mySQLConnection getLastErrorMessage]];
				[self failConnectionWithTitle:NSLocalizedString(@"Connection failed!", @"connection failed title") errorMessage:errorMessage detail:nil];
			}
			
			if (sshTunnel) [sshTunnel release], sshTunnel = nil;
			[mySQLConnection release], mySQLConnection = nil;
			return;
		}
	}
	if ([self database] && ![[self database] isEqualToString:@""]) {
		if (![mySQLConnection selectDB:[self database]]) {
			[self failConnectionWithTitle:NSLocalizedString(@"Could not select database", @"message when database selection failed") errorMessage:[NSString stringWithFormat:NSLocalizedString(@"Connected to host, but unable to connect to database %@.\n\nBe sure that the database exists and that you have the necessary privileges.\n\nMySQL said: %@", @"message of panel when connection to db failed"), [self database], [mySQLConnection getLastErrorMessage]] detail:nil];
			if (sshTunnel) [sshTunnel release], sshTunnel = nil;
			[mySQLConnection release], mySQLConnection = nil;
			return;
		}
	}
	
	// Successful connection!
	[progressIndicator stopAnimation:self];
	[progressIndicatorText setHidden:YES];
	[addToFavoritesButton setHidden:NO];
	[connectButton setEnabled:YES];

	// Release the tunnel if set - will now be retained by the connection
	if (sshTunnel) [sshTunnel release], sshTunnel = nil;

	// Pass the connection to the document and clean up the interface
	[self addConnectionToDocument];
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

	// Display the connection error message
	NSBeginAlertSheet(theTitle, NSLocalizedString(@"OK", @"OK button"), (errorDetail) ? NSLocalizedString(@"Show Detail", @"Show detail button") : nil, (isSSHTunnelBindError) ? NSLocalizedString(@"Use Standard Connection", @"use standard connection button") : nil, documentWindow, self, nil, @selector(errorSheetDidEnd:returnCode:contextInfo:), @"connect", theErrorMessage);
}

/**
 * Alert sheet callback method - invoked when an error sheet is closed.
 */
- (void)errorSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{	
	[sheet orderOut:self];
	
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
		[self setType:SP_CONNECTION_TCPIP];
				
		// Change connection details
		[self setPort:tunnelPort];
		[self setHost:@"127.0.0.1"];
				
		// Change to standard TCP/IP connection view
		[self resizeTabViewToConnectionType:SP_CONNECTION_TCPIP animating:YES];
		
		// Initiate the connection after half a second to give the connection view a chance to resize
		[self performSelector:@selector(initiateConnection:) withObject:self afterDelay:0.5];				
	}
}

/**
 * Add the connection to the parent document and restore the
 * interface, allowing the application to run as normal.
 */
- (void) addConnectionToDocument
{
	
	// Hide the connection view and restore the main view
	[connectionView removeFromSuperviewWithoutNeedingDisplay];
	[contentView setHidden:NO];

	// Restore the toolbar icons
	NSArray *toolbarItems = [[documentWindow toolbar] items];
	for (int i = 0; i < [toolbarItems count]; i++) [[toolbarItems objectAtIndex:i] setEnabled:YES];

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
- (IBAction) editFavorites:(id)sender
{
	SPPreferenceController *prefsController = [[NSApp delegate] preferenceController];
	
	[prefsController showWindow:self];
	[prefsController displayFavoritePreferences:self];
	[prefsController selectFavoriteAtIndex:([favoritesTable selectedRow] - 1)];	
}

/**
 * Show connection help.
 */
- (IBAction) showHelp:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.sequelpro.com/docs/Getting_Connected"]];
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
	int selectedTabView = [tabView indexOfTabViewItem:tabViewItem];

	// Deselect any selected favorite for manual changes
	if (!automaticFavoriteSelection) [favoritesTable deselectAll:self];
	automaticFavoriteSelection = NO;

	if (selectedTabView == previousType) return;
	
	[self resizeTabViewToConnectionType:selectedTabView animating:YES];
	
	// Update the host as appropriate
	if ((selectedTabView != SP_CONNECTION_SOCKET) && [[self host] isEqualToString:@"localhost"]) {
		[self setHost:@""];
	}

	previousType = selectedTabView;
}

/**
 * When a favorite is selected, and the connection details are edited, deselect the favorite;
 * this is clearer and also prevents a failed connection from being repopulated with the
 * favorite's details instead of the last used details.
 */
- (void) controlTextDidChange:(NSNotification *)aNotification
{
	[favoritesTable deselectAll:self];
}

/**
 * When a host field finishes editing, ensure that it hasn't been set to "localhost"
 * to ensure that socket connections don't inadvertently occur.
 */
- (void) controlTextDidEndEditing:(NSNotification *)notification
{
	if ([notification object] == standardSQLHostField || [notification object] == sshSQLHostField) {
		[self checkHost];
	}
}

/**
 * Control tab view resizing based on the supplied connection type,
 * with an option defining whether it should be animated or not.
 */
- (void) resizeTabViewToConnectionType:(unsigned int)theType animating:(BOOL)animate
{
	NSRect frameRect, targetResizeRect;
	int additionalFormHeight = 55;

	frameRect = [connectionResizeContainer frame];

	switch (theType) {
		case SP_CONNECTION_TCPIP:
			targetResizeRect = [standardConnectionFormContainer frame];
			break;
		case SP_CONNECTION_SOCKET:
			targetResizeRect = [socketConnectionFormContainer frame];
			break;
		case SP_CONNECTION_SSHTUNNEL:
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
- (BOOL) checkHost
{
	if ([self type] != SP_CONNECTION_SOCKET && [[self host] isEqualToString:@"localhost"]) {
		NSBeginAlertSheet(NSLocalizedString(@"You have entered 'localhost' for a non-socket connection", @"title of error when using 'localhost' for a network connection"),
							NSLocalizedString(@"Use 127.0.0.1", @"Use 127.0.0.1 button"),	// Main button
							NSLocalizedString(@"Connect via socket", @"Connect via socket button"),	// Alternate button
							nil,	// Other button
							documentWindow,	// Window to attach to
							self,	// Modal delegate
							@selector(localhostErrorSheetDidEnd:returnCode:contextInfo:),	// Did end selector
							nil,	// Did dismiss selector
							nil,	// Contextual info for selectors
							NSLocalizedString(@"To MySQL, 'localhost' is a special host and means that a socket connection should be used.\n\nDid you mean to use a socket connection, or to connect to the local machine via a port?  If you meant to connect via a port, '127.0.0.1' should be used instead of 'localhost'.", @"message of error when using 'localhost' for a network connection"));
		return NO;
	}

	return YES;
}

/**
 * Alert sheet callback method - invoked when the error sheet is closed.
 */
- (void)localhostErrorSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{	
	[sheet orderOut:self];
	if (returnCode == NSAlertAlternateReturn) {
		[self setType:SP_CONNECTION_SOCKET];
		[self setHost:@""];
	} else {
		[self setHost:@"127.0.0.1"];
	}
}

#pragma mark -
#pragma mark Favorites interaction

/**
 * Updates the local favorites array from the user defaults
 */
- (void) updateFavorites
{
	[favoritesTable deselectAll:self];
	if (favorites) [favorites release];
	if ([prefs objectForKey:@"favorites"]) {
		favorites = [[NSMutableArray alloc] initWithArray:[prefs objectForKey:@"favorites"]];
	} else {
		favorites = [[NSMutableArray alloc] init];
	}
	[favorites insertObject:[NSDictionary dictionaryWithObject:@"FAVORITES" forKey:@"name"] atIndex:0];
	[favoritesTable reloadData];
}

/**
 * Sets fields for the chosen favorite.
 */
- (void) updateFavoriteSelection:(id)sender
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
	[self setType:([self valueForKeyPath:@"selectedFavorite.type"] ? [[self valueForKeyPath:@"selectedFavorite.type"] intValue] : SP_CONNECTION_TCPIP)];
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
	connectionKeychainItemAccount = [[keychain accountForUser:[self valueForKeyPath:@"selectedFavorite.user"] host:(([self type] == SP_CONNECTION_SOCKET)?@"localhost":[self valueForKeyPath:@"selectedFavorite.host"]) database:[self valueForKeyPath:@"selectedFavorite.database"]] retain];
	[self setPassword:[keychain getPasswordForName:connectionKeychainItemName account:connectionKeychainItemAccount]];
	if (![[self password] length]) {
		[connectionKeychainItemName release], connectionKeychainItemName = nil;
		[connectionKeychainItemAccount release], connectionKeychainItemAccount = nil;
	}

	// And the same for the SSH password
	connectionSSHKeychainItemName = [[keychain nameForSSHForFavoriteName:[self valueForKeyPath:@"selectedFavorite.name"] id:[self valueForKeyPath:@"selectedFavorite.id"]] retain];
	connectionSSHKeychainItemAccount = [[keychain accountForSSHUser:[self valueForKeyPath:@"selectedFavorite.sshUser"] sshHost:[self valueForKeyPath:@"selectedFavorite.sshHost"]] retain];
	[self setSshPassword:[keychain getPasswordForName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount]];
	if (![[self sshPassword] length]) {
		[connectionSSHKeychainItemName release], connectionSSHKeychainItemName = nil;
		[connectionSSHKeychainItemAccount release], connectionSSHKeychainItemAccount = nil;
	}
	
	[prefs setInteger:([favoritesTable selectedRow] - 1) forKey:@"LastFavoriteIndex"];
}

/**
 * Returns a KVC-compliant proxy to the currently selected favorite, or nil if nothing selected.
 */
- (id) selectedFavorite
{
	if ([favoritesTable selectedRow] == -1)
		return nil;
	
	return [favorites objectAtIndex:[favoritesTable selectedRow]];
}

/**
 * Adds the current details as a new favorite, select it, and scroll the selected
 * row to visible.
 */
- (IBAction) addFavorite:(id)sender
{
	NSString *thePassword, *theSSHPassword;
	NSNumber *favoriteid = [NSNumber numberWithInt:[[NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]] hash]];
	NSString *favoriteName = [[self name] length]?[self name]:[NSString stringWithFormat:@"%@@%@", ([self user] && [[self user] length])?[self user]:@"anonymous", (([self type] == SP_CONNECTION_SOCKET)?@"localhost":[self host])];
	if (![[self name] length] && [self database] && ![[self database] isEqualToString:@""])
		favoriteName = [NSString stringWithFormat:@"%@ %@", [self database], favoriteName];
	
	// Ensure that host is not empty if this is a TCP/IP or SSH connection
	if (([self type] == SP_CONNECTION_TCPIP || [self type] == SP_CONNECTION_SSHTUNNEL) && ![[self host] length]) {
		NSRunAlertPanel(NSLocalizedString(@"Insufficient connection details", @"insufficient details message"), NSLocalizedString(@"Insufficient details provided to establish a connection. Please provide at least a host.", @"insufficient details informative message"), NSLocalizedString(@"OK", @"OK button"), nil, nil);
		return;
	}
	
	// If SSH is enabled, ensure that the SSH host is not nil
	if ([self type] == SP_CONNECTION_SSHTUNNEL && ![[self sshHost] length]) {
		NSRunAlertPanel(NSLocalizedString(@"Insufficient connection details", @"insufficient details message"), NSLocalizedString(@"Please enter the hostname for the SSH Tunnel, or disable the SSH Tunnel.", @"message of panel when ssh details are incomplete"), NSLocalizedString(@"OK", @"OK button"), nil, nil);
		return;
	}

	// Ensure that a socket connection is not inadvertently used
	if (![self checkHost]) return;
	
	// Construct the favorite details - cannot use only dictionaryWithObjectsAndKeys for possible nil values.
	NSMutableDictionary *newFavorite = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithInt:[self type]], @"type",
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
	if ([prefs objectForKey:@"favorites"]) {
		currentFavorites = [[NSMutableArray alloc] initWithArray:[prefs objectForKey:@"favorites"]];
	} else {
		currentFavorites = [[NSMutableArray alloc] init];
	}
	[currentFavorites addObject:newFavorite];
	[prefs setObject:[NSArray arrayWithArray:currentFavorites] forKey:@"favorites"];
	[currentFavorites release];

	// Add the password to keychain as appropriate
	thePassword = [self password];
	if (mySQLConnection && connectionKeychainItemName) {
		thePassword = [keychain getPasswordForName:connectionKeychainItemName account:connectionKeychainItemAccount];
	}
	if (thePassword && ![thePassword isEqualToString:@""]) {
		[keychain addPassword:thePassword
					  forName:[keychain nameForFavoriteName:favoriteName id:[NSString stringWithFormat:@"%i", [favoriteid intValue]]]
					  account:[keychain accountForUser:[self user] host:(([self type] == SP_CONNECTION_SOCKET)?@"localhost":[self host]) database:[self database]]];
	}

	// Add the SSH password to keychain as appropriate
	theSSHPassword = [self sshPassword];
	if (mySQLConnection && connectionSSHKeychainItemName) {
		theSSHPassword = [keychain getPasswordForName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount];
	}
	if (theSSHPassword && ![theSSHPassword isEqualToString:@""]) {
		[keychain addPassword:theSSHPassword
					  forName:[keychain nameForSSHForFavoriteName:favoriteName id:[NSString stringWithFormat:@"%i", [favoriteid intValue]]]
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
	if ([keyPath isEqualToString:@"favorites"]) {
		[self updateFavorites];
	}
}

#pragma mark -
#pragma mark Favorites tableview datasource and delegate methods

/**
 * Returns the number of favorites to display
 */
- (int) numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [favorites count];
}

/**
 * Returns the favorite names to be displayed in the table
 */
- (id) tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	return [[favorites objectAtIndex:rowIndex] objectForKey:@"name"];
}

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
- (BOOL)tableView:(NSTableView *)aTableView isGroupRow:(int)rowIndex
{
	return (rowIndex == 0);	
}

/**
 * Don't allow the title row to be selected
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(int)rowIndex
{
	return (rowIndex != 0);
}

/**
 * Set the title row to display with extra height
 */
- (float)tableView:(NSTableView *)tableView heightOfRow:(int)row
{
	return (row == 0) ? 25 : 17;
}

/**
 * Control the display of rows within the favorites table
 */
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
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
#pragma mark NSSplitView delegate methods

/**
 * When the split view is resized, trigger a resize in the hidden table
 * width as well, to keep the connection view and connected view in synch.
 */
- (void) splitViewDidResizeSubviews:(NSNotification *)aNotification
{
	[contentView setPosition:[[[connectionSplitView subviews] objectAtIndex:0] frame].size.width ofDividerAtIndex:0];
}

/**
 * Return the maximum possible size of the splitview.
 */
- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
{
	return (proposedMax - 445);
}

/**
 * Return the minimum possible size of the splitview.
 */
- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
{
	return (proposedMin + 80);
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
