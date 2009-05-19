//
//  $Id$
//
//  KeyChain.m
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed Dec 25 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
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

#import "KeyChain.h"
#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>

@implementation KeyChain

/**
 * Add the supplied password to the user's Keychain using the supplied name and account.
 */
- (void)addPassword:(NSString *)password forName:(NSString *)name account:(NSString *)account
{
	OSStatus status;
	
	// Check if password already exists before adding
	if (![self passwordExistsForName:name account:account]) {
		status = SecKeychainAddGenericPassword(
											   NULL,						// default keychain
											   strlen([name UTF8String]),		// length of service name
											   [name UTF8String],				// service name
											   strlen([account UTF8String]),		// length of account name
											   [account UTF8String],			// account name
											   strlen([password UTF8String]),	// length of password
											   [password UTF8String],			// pointer to password data
											   NULL							// the item reference
											   );
		
		if (status != noErr) {
			NSLog(@"Error (%i) while trying to add password for name: %@ account: %@", status, name, account);
		}
	}
}

/**
 * Get a password from the user's Keychain for the supplied name and account.
 */
- (NSString *)getPasswordForName:(NSString *)name account:(NSString *)account
{
	OSStatus status;
	
	void *passwordData;
	UInt32 passwordLength;
	SecKeychainItemRef itemRef;
	NSString *password = @"";
	
	status = SecKeychainFindGenericPassword(
											NULL,						// default keychain
											strlen([name UTF8String]),		// length of service name
											[name UTF8String],				// service name
											strlen([account UTF8String]),	// length of account name
											[account UTF8String],			// account name
											&passwordLength,			// length of password
											&passwordData,				// pointer to password data
											&itemRef					// the item reference
											);
	
	if (status == noErr) {
		password = [NSString stringWithCString:passwordData length:passwordLength];
		
		// Free the data allocated by SecKeychainFindGenericPassword:
		status = SecKeychainItemFreeContent(
											NULL,           // No attribute data to release
											passwordData    // Release data
											);
	}

	return password;
}

/**
 * Delete a password from the user's Keychain for the supplied name and account.
 */
- (void)deletePasswordForName:(NSString *)name account:(NSString *)account
{
	OSStatus status;
	SecKeychainItemRef itemRef = nil;

	// Check if password already exists before deleting
	if ([self passwordExistsForName:name account:account]) {
		status = SecKeychainFindGenericPassword(
												NULL,						// default keychain
												strlen([name UTF8String]),		// length of service name
												[name UTF8String],				// service name
												strlen([account UTF8String]),	// length of account name
												[account UTF8String],			// account name
												nil,						// length of password
												nil,						// pointer to password data
												&itemRef					// the item reference
												);
		
		if (status == noErr) {
			status = SecKeychainItemDelete(itemRef);
			
			if (status != noErr) {
				NSLog(@"Error (%i) while trying to delete password for name: %@ account: %@", status, name, account);
			}
		}
		
		CFRelease(itemRef);
	}
}

/**
 * Checks the user's Keychain to see if a password for the supplied name and account exists.
 */
- (BOOL)passwordExistsForName:(NSString *)name account:(NSString *)account
{
	SecKeychainItemRef item;
	SecKeychainSearchRef search;
    int numberOfItemsFound = 0;
	
	SecKeychainAttributeList list;
	SecKeychainAttribute attributes[2];
	
	attributes[0].tag    = kSecAccountItemAttr;
	attributes[0].data   = (void *)[account UTF8String];
	attributes[0].length = [account length];
	
	attributes[1].tag    = kSecLabelItemAttr;
    attributes[1].data   = (void *)[name UTF8String];
    attributes[1].length = [name length];
	
    list.count = 2;
    list.attr  = attributes;
	
    if (SecKeychainSearchCreateFromAttributes(NULL, kSecGenericPasswordItemClass, &list, &search) == noErr) {
		while (SecKeychainSearchCopyNext(search, &item) == noErr) {
			CFRelease(item);
			numberOfItemsFound++;
		}
	}
	
    CFRelease(search);
	
	return (numberOfItemsFound > 0);
}

@end
