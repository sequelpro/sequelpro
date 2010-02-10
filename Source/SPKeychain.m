//
//  $Id$
//
//  SPKeychain.m
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

#import "SPKeychain.h"

#import <CoreFoundation/CoreFoundation.h>
#import <Security/Security.h>

@implementation SPKeychain

/**
 * Add the supplied password to the user's Keychain using the supplied name and account.
 */
- (void)addPassword:(NSString *)password forName:(NSString *)name account:(NSString *)account
{
	[self addPassword:password forName:name account:account withLabel:name];
}

/**
 * Add the supplied password to the user's Keychain using the supplied name, account, and label.
 */
- (void)addPassword:(NSString *)password forName:(NSString *)name account:(NSString *)account withLabel:(NSString *)label;
{
	OSStatus status;
	SecTrustedApplicationRef sequelProRef, sequelProHelperRef;
	SecAccessRef passwordAccessRef = NULL;
	SecKeychainAttribute attributes[4];
	SecKeychainAttributeList attList;

	// Check supplied variables and replaces nils with empty strings
	if (!name) name = @"";
	if (!account) account = @"";
	if (!label) label = @"";

	// Check if password already exists before adding
	if (![self passwordExistsForName:name account:account]) {

		// Create a trusted access list with two items - ourselves and the SSH pass app.
		NSString *helperPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"SequelProTunnelAssistant"];
		if ((SecTrustedApplicationCreateFromPath(NULL, &sequelProRef) == noErr) &&
			(SecTrustedApplicationCreateFromPath([helperPath UTF8String], &sequelProHelperRef) == noErr)) {

			NSArray *trustedApps = [NSArray arrayWithObjects:(id)sequelProRef, (id)sequelProHelperRef, nil];
			status = SecAccessCreate((CFStringRef)name, (CFArrayRef)trustedApps, &passwordAccessRef);
			if (status != noErr) {
				NSLog(@"Error (%i) while trying to create access list for name: %@ account: %@", status, name, account);
				passwordAccessRef = NULL;
			}
		}
		
		// Set up the item attributes
		attributes[0].tag = kSecGenericItemAttr;
		attributes[0].data = "application password";
		attributes[0].length = 20;
		attributes[1].tag = kSecLabelItemAttr;
		attributes[1].data = (unichar *)[label UTF8String];
		attributes[1].length = strlen([label UTF8String]);
		attributes[2].tag = kSecAccountItemAttr;
		attributes[2].data = (unichar *)[account UTF8String];
		attributes[2].length = strlen([account UTF8String]);
		attributes[3].tag = kSecServiceItemAttr;
		attributes[3].data = (unichar *)[name UTF8String];
		attributes[3].length = strlen([name UTF8String]);
		attList.count = 4;
		attList.attr = attributes;

		// Create the keychain item
		status = SecKeychainItemCreateFromContent(
			kSecGenericPasswordItemClass,			// Generic password type
			&attList,								// The attribute list created for the keychain item
			strlen([password UTF8String]),			// Length of password
			[password UTF8String],					// Password data
			NULL,									// Default keychain
			passwordAccessRef,						// Access list for this keychain
			NULL);									// The item reference

		if (passwordAccessRef) CFRelease(passwordAccessRef);
		
		if (status != noErr) {
			NSLog(@"Error (%i) while trying to add password for name: %@ account: %@", status, name, account);
			
			NSBeginAlertSheet(NSLocalizedString(@"Error adding password to Keychain", @"error adding password to keychain message"), 
							  NSLocalizedString(@"OK", @"OK button"), 
							  nil, nil, [NSApp mainWindow], self, nil, nil, nil,
							  NSLocalizedString(@"An error occured while trying to add the password to your Keychain. Repairing your Keychain might resolve this, but if it doesn't please report it to the Sequel Pro team, supplying the error code %i.", @"error adding password to keychain informative message"), status);
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

	// Check supplied variables and replaces nils with empty strings
	if (!name) name = @"";
	if (!account) account = @"";

	status = SecKeychainFindGenericPassword(
											NULL,						// default keychain
											strlen([name UTF8String]),		// length of service name (bytes)
											[name UTF8String],				// service name
						
											strlen([account UTF8String]),	// length of account name (bytes)
											[account UTF8String],			// account name
											&passwordLength,			// length of password
											&passwordData,				// pointer to password data
											&itemRef					// the item reference
											);
	
	if (status == noErr) {
		// Create a \0 terminated cString out of passwordData
		char passwordBuf[passwordLength + 1];
		strncpy(passwordBuf, passwordData, (size_t)passwordLength);
		passwordBuf[passwordLength] = '\0';

		password = [NSString stringWithCString:passwordBuf encoding:NSUTF8StringEncoding];

		// Free the data allocated by SecKeychainFindGenericPassword:
		SecKeychainItemFreeContent(
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

	// Check supplied variables and replaces nils with empty strings
	if (!name) name = @"";
	if (!account) account = @"";

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
		
		if (itemRef) CFRelease(itemRef);
	}
}

/**
 * Checks the user's Keychain to see if a password for the supplied name and account exists.
 */
- (BOOL)passwordExistsForName:(NSString *)name account:(NSString *)account
{
	SecKeychainItemRef item;
	SecKeychainSearchRef search = NULL;
    NSInteger numberOfItemsFound = 0;
	SecKeychainAttributeList list;
	SecKeychainAttribute attributes[2];

	// Check supplied variables and replaces nils with empty strings
	if (!name) name = @"";
	if (!account) account = @"";

	attributes[0].tag    = kSecAccountItemAttr;
	attributes[0].data   = (void *)[account UTF8String];	// Account name
	attributes[0].length = strlen([account UTF8String]);	// Length of account name (bytes)
	
	attributes[1].tag    = kSecServiceItemAttr;
    attributes[1].data   = (void *)[name UTF8String];	// Service name
    attributes[1].length = strlen([name UTF8String]);	// Length of service name (bytes)
	
    list.count = 2;
    list.attr  = attributes;
	
    if (SecKeychainSearchCreateFromAttributes(NULL, kSecGenericPasswordItemClass, &list, &search) == noErr) {
		while (SecKeychainSearchCopyNext(search, &item) == noErr) {
			CFRelease(item);
			numberOfItemsFound++;
		}
	}
	
    if (search) CFRelease(search);
	
	return (numberOfItemsFound > 0);
}

/**
 * Retrieve the keychain item name for a supplied name and id.
 */
- (NSString *)nameForFavoriteName:(NSString *)theName id:(NSString *)theID
{
	NSString *keychainItemName;

	// Look up the keychain name using long longs to support 64-bit > 32-bit keychain usage
	keychainItemName = [NSString stringWithFormat:@"Sequel Pro : %@ (%lld)",
							theName?theName:@"",
							[theID longLongValue]];

	return keychainItemName;
}

/**
 * Retrieve the keychain item account for a supplied user, host, and database - which can be nil.
 */
- (NSString *)accountForUser:(NSString *)theUser host:(NSString *)theHost database:(NSString *)theDatabase
{
	NSString *keychainItemAccount;

	keychainItemAccount = [NSString stringWithFormat:@"%@@%@/%@",
								theUser?theUser:@"",
								theHost?theHost:@"",
								theDatabase?theDatabase:@""];

	return keychainItemAccount;
}

/**
 * Retrieve the keychain SSH item name for a supplied name and id.
 */
- (NSString *)nameForSSHForFavoriteName:(NSString *)theName id:(NSString *)theID
{
	NSString *sshKeychainItemName;

	// Look up the keychain name using long longs to support 64-bit > 32-bit keychain usage
	sshKeychainItemName = [NSString stringWithFormat:@"Sequel Pro SSHTunnel : %@ (%lld)",
							theName?theName:@"",
							[theID longLongValue]];

	return sshKeychainItemName;
}

/**
 * Retrieve the keychain SSH item account for a supplied SSH user and host - which can be nil.
 */
- (NSString *)accountForSSHUser:(NSString *)theSSHUser sshHost:(NSString *)theSSHHost
{
	NSString *sshKeychainItemAccount;

	sshKeychainItemAccount = [NSString stringWithFormat:@"%@@%@",
								theSSHUser?theSSHUser:@"",
								theSSHHost?theSSHHost:@""];

	return sshKeychainItemAccount;
}

@end
