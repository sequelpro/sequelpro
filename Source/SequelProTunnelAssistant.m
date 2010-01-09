//
//  $Id$
//
//  SequelProTunnelAssistant.m
//  sequel-pro
//
//  Created by Rowan Beentje on May 4, 2009.
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
#import "SPKeychain.h"
#import "SPSSHTunnel.h"
#import "RegexKitLite.h"

int main(int argc, const char *argv[])
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSDictionary *environment = [[NSProcessInfo processInfo] environment];
	NSString *argument = nil;
	SPSSHTunnel *sequelProTunnel;
	NSString *connectionName = [environment objectForKey:@"SP_CONNECTION_NAME"];
	NSString *verificationHash = [environment objectForKey:@"SP_CONNECTION_VERIFY_HASH"];

	if (![environment objectForKey:@"SP_PASSWORD_METHOD"]) {
		[pool release];
		return 1;
	}

	if (argc > 1) {
		argument = [[[NSString alloc] initWithCString:argv[1] encoding:NSUTF8StringEncoding] autorelease];
	}

	// Check if we're being asked a question and respond if so
	if (argument && [argument rangeOfString:@" (yes/no)?"].location != NSNotFound) {
		sequelProTunnel = (SPSSHTunnel *)[NSConnection rootProxyForConnectionWithRegisteredName:connectionName host:nil];
		if (!sequelProTunnel) {
			NSLog(@"SSH Tunnel: unable to connect to Sequel Pro to show SSH question");
			[pool release];
			return 1;
		}
		BOOL response = [sequelProTunnel getResponseForQuestion:argument];
		if (response) {
			printf("yes\n");
		} else {
			printf("no\n");
		}
		[pool release];
		return 0;
	}
	
	// Check whether we're being asked for a standard SSH password - if so, use the app-entered value.
	if (argument && [[argument lowercaseString] rangeOfString:@"password:"].location != NSNotFound ) {

		// If the password method is set to use the keychain, use the supplied keychain name to
		// request the password
		if ([[environment objectForKey:@"SP_PASSWORD_METHOD"] integerValue] == SPSSH_PASSWORD_USES_KEYCHAIN) {
			SPKeychain *keychain;
			NSString *keychainName = [environment objectForKey:@"SP_KEYCHAIN_ITEM_NAME"];
			NSString *keychainAccount = [environment objectForKey:@"SP_KEYCHAIN_ITEM_ACCOUNT"];

			if (!keychainName || !keychainAccount) {
				NSLog(@"SSH Tunnel: keychain authentication specified but insufficient internal details supplied");
				[pool release];
				return 1;
			}

			keychain = [[SPKeychain alloc] init];
			if (![keychain passwordExistsForName:keychainName account:keychainAccount]) {
				NSLog(@"SSH Tunnel: specified keychain password not found");
				[keychain release];
				[pool release];
				return 1;
			}

			printf("%s\n", [[keychain getPasswordForName:keychainName account:keychainAccount] UTF8String]);
			[keychain release];
			[pool release];
			return 0;
		}

		// If the password method is set to request the password from the tunnel instance, do so.
		if ([[environment objectForKey:@"SP_PASSWORD_METHOD"] integerValue] == SPSSH_PASSWORD_ASKS_UI) {
			NSString *password;
			
			if (!connectionName || !verificationHash) {
				NSLog(@"SSH Tunnel: internal authentication specified but insufficient details supplied");
				[pool release];
				return 1;
			}

			sequelProTunnel = (SPSSHTunnel *)[NSConnection rootProxyForConnectionWithRegisteredName:connectionName host:nil];
			if (!sequelProTunnel) {
				NSLog(@"SSH Tunnel: unable to connect to Sequel Pro for internal authentication");
				[pool release];
				return 1;
			}
			
			password = [sequelProTunnel getPasswordWithVerificationHash:verificationHash];
			if (!password) {
				NSLog(@"SSH Tunnel: unable to successfully request password from Sequel Pro for internal authentication");
				[pool release];
				return 1;
			}

			printf("%s\n", [password UTF8String]);
			[pool release];
			return 0;
		}
	}

	// Check whether we're being asked for a SSH key passphrase
	if (argument && [[argument lowercaseString] rangeOfString:@"enter passphrase for"].location != NSNotFound ) {
		NSString *passphrase;
		NSString *keyName = [argument stringByMatching:@"^\\s*Enter passphrase for key \\'(.*)\\':\\s*$" capture:1L];

		if (keyName) {
		
			// Check whether the passphrase is in the keychain, using standard OS X sshagent name and account
			SPKeychain *keychain = [[SPKeychain alloc] init];
			if ([keychain passwordExistsForName:@"SSH" account:keyName]) {
				printf("%s\n", [[keychain getPasswordForName:@"SSH" account:keyName] UTF8String]);
				[keychain release];
				[pool release];
				return 0;
			}
			[keychain release];
		}
		
		// Not found in the keychain - we need to ask the GUI.

		if (!verificationHash) {
			NSLog(@"SSH Tunnel: key passphrase authentication required but insufficient details supplied to connect to GUI");
			[pool release];
			return 1;
		}

		sequelProTunnel = (SPSSHTunnel *)[NSConnection rootProxyForConnectionWithRegisteredName:connectionName host:nil];
		if (!sequelProTunnel) {
			NSLog(@"SSH Tunnel: unable to connect to Sequel Pro to show SSH question");
			[pool release];
			return 1;
		}
		passphrase = [sequelProTunnel getPasswordForQuery:argument verificationHash:verificationHash];
		if (!passphrase) {
			[pool release];
			return 1;
		}

		printf("%s\n", [passphrase UTF8String]);
		[pool release];
		return 0;
	}

	[pool release];
	return 1;
}
