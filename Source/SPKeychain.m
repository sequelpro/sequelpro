//
//  $Id$
//
//  SPKeychain.m
//  sequel-pro
//
//  Created by Lorenz Textor (lorenz@textor.ch) on December 25, 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//  Copyright (c) 2012 Sequel Pro Team. All rights reserved.
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

#import "SPKeychain.h"
#import "SPAlertSheets.h"

#import <Security/Security.h>
#import <CoreFoundation/CoreFoundation.h>

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
				NSLog(@"Error (%i) while trying to create access list for name: %@ account: %@", (int)status, name, account);
				passwordAccessRef = NULL;
			}
		}
		
		// Set up the item attributes
		attributes[0].tag = kSecGenericItemAttr;
		attributes[0].data = "application password";
		attributes[0].length = 20;
		attributes[1].tag = kSecLabelItemAttr;
		attributes[1].data = (unichar *)[label UTF8String];
		attributes[1].length = (UInt32)strlen([label UTF8String]);
		attributes[2].tag = kSecAccountItemAttr;
		attributes[2].data = (unichar *)[account UTF8String];
		attributes[2].length = (UInt32)strlen([account UTF8String]);
		attributes[3].tag = kSecServiceItemAttr;
		attributes[3].data = (unichar *)[name UTF8String];
		attributes[3].length = (UInt32)strlen([name UTF8String]);
		attList.count = 4;
		attList.attr = attributes;

		// Create the keychain item
		status = SecKeychainItemCreateFromContent(
			kSecGenericPasswordItemClass,			// Generic password type
			&attList,								// The attribute list created for the keychain item
			(UInt32)strlen([password UTF8String]),	// Length of password
			[password UTF8String],					// Password data
			NULL,									// Default keychain
			passwordAccessRef,						// Access list for this keychain
			NULL);									// The item reference

		if (passwordAccessRef) CFRelease(passwordAccessRef);
		
		if (status != noErr) {
			NSLog(@"Error (%i) while trying to add password for name: %@ account: %@", (int)status, name, account);
			
			SPBeginAlertSheet(NSLocalizedString(@"Error adding password to Keychain", @"error adding password to keychain message"), 
							  NSLocalizedString(@"OK", @"OK button"), 
							  nil, nil, [NSApp mainWindow], self, nil, nil,
							  [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to add the password to your Keychain. Repairing your Keychain might resolve this, but if it doesn't please report it to the Sequel Pro team, supplying the error code %i.", @"error adding password to keychain informative message"), status]);
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
	NSString *password = nil;

	// Check supplied variables and replaces nils with empty strings
	if (!name) name = @"";
	if (!account) account = @"";

	status = SecKeychainFindGenericPassword(
											NULL,									// default keychain
											(UInt32)strlen([name UTF8String]),		// length of service name (bytes)
											[name UTF8String],						// service name

											(UInt32)strlen([account UTF8String]),	// length of account name (bytes)
											[account UTF8String],					// account name
											&passwordLength,						// length of password
											&passwordData,							// pointer to password data
											&itemRef								// the item reference
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
												NULL,									// default keychain
												(UInt32)strlen([name UTF8String]),		// length of service name
												[name UTF8String],						// service name
												(UInt32)strlen([account UTF8String]),	// length of account name
												[account UTF8String],					// account name
												nil,									// length of password
												nil,									// pointer to password data
												&itemRef								// the item reference
												);
		
		if (status == noErr) {
			status = SecKeychainItemDelete(itemRef);
			
			if (status != noErr) {
				NSLog(@"Error (%i) while trying to delete password for name: %@ account: %@", (int)status, name, account);
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
	attributes[0].data   = (void *)[account UTF8String];			// Account name
	attributes[0].length = (UInt32)strlen([account UTF8String]);	// Length of account name (bytes)
	
	attributes[1].tag    = kSecServiceItemAttr;
    attributes[1].data   = (void *)[name UTF8String];			// Service name
    attributes[1].length = (UInt32)strlen([name UTF8String]);	// Length of service name (bytes)
	
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
 * Change the password for a keychain item.  This should be used instead of
 * deleting and recreating the keychain item, as it allows preservation of
 * access lists and works around Lion cacheing issues.
 */
- (void)updateItemWithName:(NSString *)name account:(NSString *)account toPassword:(NSString *)password
{
	[self updateItemWithName:name account:account toName:password account:name password:account];
}

/**
 * Change the details for a keychain item.  This should be used instead of
 * deleting and recreating the keychain item, as it allows preservation of
 * access lists and works around Lion cacheing issues.
 */
- (void)updateItemWithName:(NSString *)name account:(NSString *)account toName:(NSString *)newName account:(NSString *)newAccount password:(NSString *)password
{
	OSStatus status;
	SecKeychainItemRef itemRef;
	SecKeychainAttribute attributes[2];
	SecKeychainAttributeList attList;

	// Retrieve a reference to the keychain item
	status = SecKeychainFindGenericPassword(NULL,														// Default keychain
											(UInt32)strlen([name UTF8String]), [name UTF8String],		// Service name and length
											(UInt32)strlen([account UTF8String]), [account UTF8String],	// Account name and length
											NULL, NULL,													// No password retrieval required
											&itemRef);													// The item reference

	if (status != noErr) {
		NSLog(@"Error (%i) while trying to find keychain item to edit for name: %@ account: %@", (int)status, name, account);
		SPBeginAlertSheet(NSLocalizedString(@"Error retrieving Keychain item to edit", @"error finding keychain item to edit message"), 
						  NSLocalizedString(@"OK", @"OK button"), 
						  nil, nil, [NSApp mainWindow], self, nil, nil,
						  [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to retrieve the Keychain item you're trying to edit. Repairing your Keychain might resolve this, but if it doesn't please report it to the Sequel Pro team, supplying the error code %i.", @"error finding keychain item to edit informative message"), status]);
		return;
	}

	// Set up the attributes to modify
	attributes[0].tag = kSecAccountItemAttr;
	attributes[0].data = (unichar *)[newAccount UTF8String];
	attributes[0].length = (UInt32)strlen([newAccount UTF8String]);
	attributes[1].tag = kSecServiceItemAttr;
	attributes[1].data = (unichar *)[newName UTF8String];
	attributes[1].length = (UInt32)strlen([newName UTF8String]);
	attList.count = 2;
	attList.attr = attributes;

	// Amend the keychain item
	status = SecKeychainItemModifyAttributesAndData(itemRef, &attList, (UInt32)strlen([password UTF8String]), [password UTF8String]);

	if (status != noErr) {

		// An error of -25299 indicates that the keychain item is a duplicate.  As connection names include a unique ID,
		// this indicates an issue when previously altering keychain items; delete the old item and try again.
		if ((int)status == -25299) {
			[self deletePasswordForName:newName account:newAccount];
			return [self updateItemWithName:name account:account toName:newName account:newAccount password:password];
		}

		NSLog(@"Error (%i) while updating keychain item for name: %@ account: %@", (int)status, name, account);
		SPBeginAlertSheet(NSLocalizedString(@"Error updating Keychain item", @"error updating keychain item message"), 
						  NSLocalizedString(@"OK", @"OK button"), 
						  nil, nil, [NSApp mainWindow], self, nil, nil,
						  [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to update the Keychain item. Repairing your Keychain might resolve this, but if it doesn't please report it to the Sequel Pro team, supplying the error code %i.", @"error updating keychain item informative message"), status]);
	}
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
