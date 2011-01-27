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
 * Set up the MySQL connection, either through a successful tunnel or directly in the background.
 */
- (void)initiateMySQLConnection
{	
	[progressIndicatorText setStringValue:(sshTunnel) ? NSLocalizedString(@"MySQL connecting...", @"MySQL connecting very short status message") : NSLocalizedString(@"Connecting...", @"Generic connecting very short status message")];
	[progressIndicatorText display];
	
	[connectButton setTitle:NSLocalizedString(@"Cancel", @"cancel button")];
	[connectButton setAction:@selector(cancelMySQLConnection:)];
	[connectButton setEnabled:YES];
	[connectButton display];
	
	[NSThread detachNewThreadSelector:@selector(initiateMySQLConnectionInBackground) toTarget:self withObject:nil];
}

/**
 * Initiates the core of the MySQL connection process on a background thread.
 */
- (void)initiateMySQLConnectionInBackground
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Initialise to socket if appropriate.
	if ([self type] == SPSocketConnection) {
		mySQLConnection = [[MCPConnection alloc] initToSocket:[self socket] withLogin:[self user]];
		
		// Otherwise, initialise to host, using tunnel if appropriate
	} 
	else {
		if ([self type] == SPSSHTunnelConnection) {
			mySQLConnection = [[MCPConnection alloc] initToHost:@"127.0.0.1"
													  withLogin:[self user]
													  usingPort:[sshTunnel localPort]];
			[mySQLConnection setConnectionProxy:sshTunnel];
		} 
		else {
			mySQLConnection = [[MCPConnection alloc] initToHost:[self host]
													  withLogin:[self user]
													  usingPort:([[self port] length] ? [[self port] integerValue] : 3306)];
		}
	}
	
	// Only set the password if there is no Keychain item set. The connection will ask the delegate for passwords in the Keychain.	
	if (!connectionKeychainItemName && [self password]) {
		[mySQLConnection setPassword:[self password]];
	}
	
	// Enable SSL if set
	if ([self useSSL]) {
		[mySQLConnection setSSL:YES
			   usingKeyFilePath:[self sslKeyFileLocationEnabled] ? [self sslKeyFileLocation] : nil
				certificatePath:[self sslCertificateFileLocationEnabled] ? [self sslCertificateFileLocation] : nil
certificateAuthorityCertificatePath:[self sslCACertFileLocationEnabled] ? [self sslCACertFileLocation] : nil];
	}
	
	// Connection delegate must be set before actual connection attempt is made
	[mySQLConnection setDelegate:dbDocument];
	
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
			} 
			else if ([mySQLConnection getLastErrorID] == 1045) { // "Access denied" error
				errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Unable to connect to host %@ because access was denied.\n\nDouble-check your username and password and ensure that access from your current location is permitted.\n\nMySQL said: %@", @"message of panel when connection to host failed due to access denied error"), [self host], [mySQLConnection getLastErrorMessage]];
				[[self onMainThread] failConnectionWithTitle:NSLocalizedString(@"Access denied!", @"connection failed due to access denied title") errorMessage:errorMessage detail:nil];
			} 
			else if ([self type] == SPSocketConnection && (![self socket] || ![[self socket] length]) && ![mySQLConnection findSocketPath]) {
				errorMessage = [NSString stringWithFormat:NSLocalizedString(@"The socket file could not be found in any common location. Please supply the correct socket location.\n\nMySQL said: %@", @"message of panel when connection to socket failed because optional socket could not be found"), [mySQLConnection getLastErrorMessage]];
				[[self onMainThread] failConnectionWithTitle:NSLocalizedString(@"Socket not found!", @"socket not found title") errorMessage:errorMessage detail:nil];
			} 
			else if ([self type] == SPSocketConnection) {
				errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Unable to connect via the socket, or the request timed out.\n\nDouble-check that the socket path is correct and that you have the necessary privileges, and that the server is running.\n\nMySQL said: %@", @"message of panel when connection to host failed"), [mySQLConnection getLastErrorMessage]];
				[[self onMainThread] failConnectionWithTitle:NSLocalizedString(@"Socket connection failed!", @"socket connection failed title") errorMessage:errorMessage detail:nil];
			} 
			else {
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
	[self performSelectorOnMainThread:@selector(mySQLConnectionEstablished) withObject:nil waitUntilDone:NO];
	
	[pool release];
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

/**
 * Called on the main thread once the MySQL connection is established on the background thread. Either the
 * connection was cancelled or it was successful. 
 */
- (void)mySQLConnectionEstablished
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
	[dbDocument setIsProcessing:NO];
	
	// Successful connection!
	[connectButton setEnabled:NO];
	[connectButton display];
	[progressIndicator stopAnimation:self];
	[progressIndicatorText setHidden:YES];
	[addToFavoritesButton setHidden:NO];
	
	// If SSL was enabled, check it was established correctly
	if (useSSL && ([self type] == SPTCPIPConnection || [self type] == SPSocketConnection)) {
		if (![mySQLConnection isConnectedViaSSL]) {
			SPBeginAlertSheet(NSLocalizedString(@"SSL connection not established", @"SSL requested but not used title"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [dbDocument parentWindow], nil, nil, nil, NSLocalizedString(@"You requested that the connection should be established using SSL, but MySQL made the connection without SSL.\n\nThis may be because the server does not support SSL connections, or has SSL disabled; or insufficient details were supplied to establish an SSL connection.\n\nThis connection is not encrypted.", @"SSL connection requested but not established error detail"));
		} 
		else {
			[dbDocument setStatusIconToImageWithName:@"titlebarlock"]; 
		}
	}
	
	// Re-enable favorites table view
	[favoritesOutlineView setEnabled:YES];
	[favoritesOutlineView display];
	
	// Release the tunnel if set - will now be retained by the connection
	if (sshTunnel) [sshTunnel release], sshTunnel = nil;
	
	// Pass the connection to the document and clean up the interface
	[self addConnectionToDocument];
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
	
		[self _restoreConnectionInterface];
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
	
	if (connectionKeychainID) [dbDocument setKeychainID:connectionKeychainID];
	
	// Pass the connection to the table document, allowing it to set
	// up the other classes and the rest of the interface.
	[dbDocument setConnection:mySQLConnection];
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

@end
