//
//  $Id$
//
//  SPConnectionDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 13, 2009
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

#import "SPConnectionDelegate.h"
#import "SPConnectionController.h"
#import "SPQueryController.h"
#import "SPKeychain.h"
#import "SPConstants.h"

@implementation TableDocument (SPConnectionDelegate)

#pragma mark -
#pragma mark MCPKit connection delegate methods

/**
 * Invoked when the framework is about to perform a query.
 */
- (void)willQueryString:(NSString *)query connection:(id)connection
{
	if ([prefs boolForKey:SPConsoleEnableLogging]) {
		if ((_queryMode == SPInterfaceQueryMode && [prefs boolForKey:SPConsoleEnableInterfaceLogging])
			|| (_queryMode == SPCustomQueryQueryMode && [prefs boolForKey:SPConsoleEnableCustomQueryLogging])
			|| (_queryMode == SPImportExportQueryMode && [prefs boolForKey:SPConsoleEnableImportExportLogging]))
		{
			[[SPQueryController sharedQueryController] showMessageInConsole:query connection:[self name]];
		}
	}
}

/**
 * Invoked when the query just executed by the framework resulted in an error. 
 */
- (void)queryGaveError:(NSString *)error connection:(id)connection
{
	if ([prefs boolForKey:SPConsoleEnableLogging] && [prefs boolForKey:SPConsoleEnableErrorLogging]) {
		[[SPQueryController sharedQueryController] showErrorInConsole:error connection:[self name]];
	}
}

/**
 * Invoked when the framework is in the process of reconnecting to the server and needs to know 
 * which database to select.
 */
- (NSString *)onReconnectShouldSelectDatabase:(id)connection
{
	return selectedDatabase;
}

/**
 * Invoked when the framework is in the process of reconnecting to the server and needs to know 
 * what encoding to use for the connection.
 */
- (NSString *)onReconnectShouldUseEncoding:(id)connection
{
	return _encoding;
}

/**
 * Invoked when the current connection needs a password from the Keychain.
 */
- (NSString *)keychainPasswordForConnection:(MCPConnection *)connection
{
	
	// If no keychain item is available, return an empty password
	if (![connectionController connectionKeychainItemName]) return @"";
	
	// Otherwise, pull the password from the keychain using the details from this connection
	SPKeychain *keychain = [[SPKeychain alloc] init];
	
	NSString *password = [keychain getPasswordForName:[connectionController connectionKeychainItemName] account:[connectionController connectionKeychainItemAccount]];
	
	[keychain release];
	
	return password;
}

/**
 * Invoked when an attempt was made to execute a query on the current connection, but the connection is not
 * actually active.
 */
- (void)noConnectionAvailable:(id)connection
{	
	NSBeginAlertSheet(NSLocalizedString(@"No connection available", @"no connection available message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil, NSLocalizedString(@"An error has occured and there doesn't seem to be a connection available.", @"no connection available informatie message"));
}

/**
 * Invoked when the connection fails and the framework needs to know how to proceed.
 */
- (MCPConnectionCheck)connectionLost:(id)connection
{
	[NSApp beginSheet:connectionErrorDialog modalForWindow:tableWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	NSInteger connectionErrorCode = [NSApp runModalForWindow:connectionErrorDialog];
	
	[NSApp endSheet:connectionErrorDialog];
	[connectionErrorDialog orderOut:nil];
	
	// If 'disconnect' was selected, trigger a window close.
	if (connectionErrorCode == MCPConnectionCheckDisconnect) {
		[self windowWillClose:nil];
		[tableWindow performSelector:@selector(close) withObject:nil afterDelay:0.0];
	}
	
	return connectionErrorCode;
}

@end
