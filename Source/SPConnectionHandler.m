//
//  $Id$
//
//  SPConnectionHandler.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 15, 2010
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

#import "SPConnectionHandler.h"
#import "SPAlertSheets.h"

@implementation SPConnectionController (SPConnectionHandler)

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
	sshTunnel = [[SPSSHTunnel alloc] initToHost:[self sshHost] port:[[self sshPort] integerValue] login:[self sshUser] tunnellingToPort:([[self port] length]?[[self port] integerValue]:3306) onHost:[self host]];
	[sshTunnel setParentWindow:[dbDocument parentWindow]];
	
	// Add keychain or plaintext password as appropriate - note the checks in initiateConnection.
	if (connectionSSHKeychainItemName) {
		[sshTunnel setPasswordKeychainName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount];
	} else if (sshPassword) {
		[sshTunnel setPassword:[self sshPassword]];
	}
	
	// Set the public key path if appropriate
	if (sshKeyLocationEnabled && sshKeyLocation) {
		[sshTunnel setKeyFilePath:sshKeyLocation];
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
		[dbDocument setTitlebarStatus:NSLocalizedString(@"SSH Disconnected", @"SSH disconnected titlebar marker")];
		
		[self failConnectionWithTitle:NSLocalizedString(@"SSH connection failed!", @"SSH connection failed title") errorMessage:[theTunnel lastError] detail:[sshTunnel debugMessages]];
	} 
	else if (newState == PROXY_STATE_CONNECTED) {
		[dbDocument setTitlebarStatus:NSLocalizedString(@"SSH Connected", @"SSH connected titlebar marker")];
		
		[self initiateMySQLConnection];
	} 
	else {
		[dbDocument setTitlebarStatus:NSLocalizedString(@"SSH Connecting…", @"SSH connecting titlebar marker")];
	}
}

/*
 * Set up the MySQL connection, either through a successful tunnel or directly in the background.
 */
- (void)initiateMySQLConnection
{
	// Disable the favorites table view to prevent further connections attempts
	[favoritesOutlineView setEnabled:NO];
	
	if (sshTunnel) {
		[progressIndicatorText setStringValue:NSLocalizedString(@"MySQL connecting...", @"MySQL connecting very short status message")];
	}
	else {
		[progressIndicatorText setStringValue:NSLocalizedString(@"Connecting...", @"Generic connecting very short status message")];
	}
	
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
	[dbDocument clearStatusIcon];
	
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
	
	// Only display the connection error message if there is a window visible and the connection attempt
	// wasn't cancelled even though it failed.
	if ([[dbDocument parentWindow] isVisible] && (!mySQLConnectionCancelled)) {
		SPBeginAlertSheet(theTitle, NSLocalizedString(@"OK", @"OK button"), (errorDetail) ? NSLocalizedString(@"Show Detail", @"Show detail button") : nil, (isSSHTunnelBindError) ? NSLocalizedString(@"Use Standard Connection", @"use standard connection button") : nil, [dbDocument parentWindow], self, @selector(connectionFailureSheetDidEnd:returnCode:contextInfo:), @"connect", theErrorMessage);
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
	NSArray *toolbarItems = [[[dbDocument parentWindow] toolbar] items];
	
	for (NSInteger i = 0; i < [toolbarItems count]; i++) [[toolbarItems objectAtIndex:i] setEnabled:YES];
	
	// Set keychain id for saving SPF files
	if ([self valueForKeyPath:@"selectedFavorite.id"]) {
		[dbDocument setKeychainID:[[self valueForKeyPath:@"selectedFavorite.id"] stringValue]];
	}
	else {
		[dbDocument setKeychainID:@""];
	}
	
	// Pass the connection to the table document, allowing it to set
	// up the other classes and the rest of the interface.
	[dbDocument setConnection:mySQLConnection];
}

@end
