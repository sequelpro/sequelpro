//
//  $Id$
//
//  SPConnectionDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 13, 2009.
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

#import "SPConnectionDelegate.h"
#import "SPConnectionController.h"
#import "SPQueryController.h"
#import "SPKeychain.h"
#import "SPAlertSheets.h"

#import <SPMySQL/SPMySQLConstants.h>

@implementation SPDatabaseDocument (SPConnectionDelegate)

#pragma mark -
#pragma mark SPMySQLConnection delegate methods

/**
 * Invoked when the framework is about to perform a query.
 */
- (void)willQueryString:(NSString *)query connection:(id)connection
{
#ifndef SP_CODA
	if ([prefs boolForKey:SPConsoleEnableLogging]) {
		if ((_queryMode == SPInterfaceQueryMode && [prefs boolForKey:SPConsoleEnableInterfaceLogging])
			|| (_queryMode == SPCustomQueryQueryMode && [prefs boolForKey:SPConsoleEnableCustomQueryLogging])
			|| (_queryMode == SPImportExportQueryMode && [prefs boolForKey:SPConsoleEnableImportExportLogging]))
		{
			[[SPQueryController sharedQueryController] showMessageInConsole:query connection:[self name]];
		}
	}
#endif
}

/**
 * Invoked when the query just executed by the framework resulted in an error. 
 */
- (void)queryGaveError:(NSString *)error connection:(id)connection
{
#ifndef SP_CODA
	if ([prefs boolForKey:SPConsoleEnableLogging] && [prefs boolForKey:SPConsoleEnableErrorLogging]) {
		[[SPQueryController sharedQueryController] showErrorInConsole:error connection:[self name]];
	}
#endif
}

/**
 * Invoked when the current connection needs a password from the Keychain.
 */
- (NSString *)keychainPasswordForConnection:(SPMySQLConnection *)connection
{
	
	// If no keychain item is available, return an empty password
	if (![connectionController connectionKeychainItemName]) return nil;
	
	// Otherwise, pull the password from the keychain using the details from this connection
	SPKeychain *keychain = [[SPKeychain alloc] init];
	
	NSString *password = [keychain getPasswordForName:[connectionController connectionKeychainItemName] account:[connectionController connectionKeychainItemAccount]];
	
	[keychain release];
	
	return password;
}

/**
 * Invoked when the current connection needs a ssh password from the Keychain.
 * This isn't actually part of the SPMySQLConnection delegate protocol, but is here
 * due to its similarity to the previous method.
 */
- (NSString *)keychainPasswordForSSHConnection:(SPMySQLConnection *)connection
{

	// If no keychain item is available, return an empty password
	if (![connectionController connectionKeychainItemName]) return @"";

	// Otherwise, pull the password from the keychain using the details from this connection
	SPKeychain *keychain = [[SPKeychain alloc] init];
	NSString *connectionSSHKeychainItemName = [[keychain nameForSSHForFavoriteName:[connectionController name] id:[self keyChainID]] retain];
	NSString *connectionSSHKeychainItemAccount = [[keychain accountForSSHUser:[connectionController sshUser] sshHost:[connectionController sshHost]] retain];
	NSString *sshpw = [keychain getPasswordForName:connectionSSHKeychainItemName account:connectionSSHKeychainItemAccount];
	if (!sshpw || ![sshpw length])
		sshpw = @"";

	if(connectionSSHKeychainItemName) [connectionSSHKeychainItemName release];
	if(connectionSSHKeychainItemAccount) [connectionSSHKeychainItemAccount release];
	[keychain release];
	
	return sshpw;
}

/**
 * Invoked when an attempt was made to execute a query on the current connection, but the connection is not
 * actually active.
 */
- (void)noConnectionAvailable:(id)connection
{	
	SPBeginAlertSheet(NSLocalizedString(@"No connection available", @"no connection available message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [self parentWindow], self, nil, nil, NSLocalizedString(@"An error has occured and there doesn't seem to be a connection available.", @"no connection available informatie message"));
}

/**
 * Invoked when the connection fails and the framework needs to know how to proceed.
 */
- (SPMySQLConnectionLostDecision)connectionLost:(id)connection
{
	SPMySQLConnectionLostDecision connectionErrorCode = SPMySQLConnectionLostDisconnect;
	
	// Only display the reconnect dialog if the window is visible
	if ([self parentWindow] && [[self parentWindow] isVisible]) {

		// Ensure the window isn't miniaturized
		if ([[self parentWindow] isMiniaturized]) [[self parentWindow] deminiaturize:self];

#ifndef SP_CODA
		// Ensure the window and tab are frontmost
		[self makeKeyDocument];
#endif
		
		// Display the connection error dialog and wait for the return code
		[NSApp beginSheet:connectionErrorDialog modalForWindow:[self parentWindow] modalDelegate:self didEndSelector:nil contextInfo:nil];
		connectionErrorCode = (SPMySQLConnectionLostDecision)[NSApp runModalForWindow:connectionErrorDialog];
		
		[NSApp endSheet:connectionErrorDialog];
		[connectionErrorDialog orderOut:nil];
		
		// If 'disconnect' was selected, trigger a window close.
		if (connectionErrorCode == SPMySQLConnectionLostDisconnect) {
			[self performSelectorOnMainThread:@selector(closeAndDisconnect) withObject:nil waitUntilDone:YES];
		}
	}

	return connectionErrorCode;
}

/**
 * Invoke to display an informative but non-fatal error directly to the user.
 */
- (void)showErrorWithTitle:(NSString *)theTitle message:(NSString *)theMessage
{
	if ([[self parentWindow] isVisible]) {
		SPBeginAlertSheet(theTitle, NSLocalizedString(@"OK", @"OK button"), nil, nil, [self parentWindow], self, nil, nil, theMessage);
	}
}

/**
 * Invoked when user dismisses the error sheet displayed as a result of the current connection being lost.
 */
- (IBAction)closeErrorConnectionSheet:(id)sender
{
	[NSApp stopModalWithCode:[sender tag]];
}

/**
 * Close the connection - should be performed on the main thread.
 */
- (void) closeAndDisconnect
{
#ifndef SP_CODA
	NSWindow *theParentWindow = [self parentWindow];
	
	_isConnected = NO;
	
	if ([[[self parentTabViewItem] tabView] numberOfTabViewItems] == 1) {
		[theParentWindow orderOut:self];
		[theParentWindow setAlphaValue:0.0f];
		[theParentWindow performSelector:@selector(close) withObject:nil afterDelay:1.0];
	} 
	else {
		[[[self parentTabViewItem] tabView] performSelector:@selector(removeTabViewItem:) withObject:[self parentTabViewItem] afterDelay:0.5];
		[theParentWindow performSelector:@selector(makeKeyAndOrderFront:) withObject:nil afterDelay:0.6];
	}
	
	[self parentTabDidClose];	
#endif
}

@end
