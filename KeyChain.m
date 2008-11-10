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
//  Or mail to <lorenz@textor.ch>

#import "KeyChain.h"
#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>

@implementation KeyChain

- (void)addPassword:(NSString *)password forName:(NSString *)name account:(NSString *)account
{
	OSStatus status;
	status = SecKeychainAddGenericPassword(
											NULL,						// default keychain
											[name cStringLength],		// length of service name
											[name cString],				// service name
											[account cStringLength],	// length of account name
											[account cString],			// account name
											[password cStringLength],	// length of password
											[password cString],			// pointer to password data
											NULL						// the item reference
											);
	
    if ( status != noErr )
		NSLog(@"Error (%i) while trying to add password for name: %@ account: %@", status, name, account);
}

- (NSString *)getPasswordForName:(NSString *)name account:(NSString *)account
{
	OSStatus status;
	
	void *passwordData = nil;
	UInt32 passwordLength = nil;
	SecKeychainItemRef itemRef = nil;
	NSString *password = @"";
	
	status = SecKeychainFindGenericPassword (
											NULL,						// default keychain
											[name cStringLength],		// length of service name
											[name cString],				// service name
											[account cStringLength],	// length of account name
											[account cString],			// account name
											&passwordLength,			// length of password
											&passwordData,				// pointer to password data
											&itemRef					// the item reference
											);
	
	if ( status == noErr ) {
		password = [NSString stringWithCString:passwordData length:passwordLength];
		
		//Free the data allocated by SecKeychainFindGenericPassword:
		status = SecKeychainItemFreeContent (
											NULL,           //No attribute data to release
											passwordData    //Release data
											 );
	}

	return password;
}

- (void)deletePasswordForName:(NSString *)name account:(NSString *)account
{
	OSStatus status;
	SecKeychainItemRef itemRef = nil;

	status = SecKeychainFindGenericPassword (
											 NULL,						// default keychain
											 [name cStringLength],		// length of service name
											 [name cString],			// service name
											 [account cStringLength],	// length of account name
											 [account cString],			// account name
											 nil,						// length of password
											 nil,						// pointer to password data
											 &itemRef					// the item reference
											 );

//	if ( status != noErr )
		NSLog(@"Error (%i) while trying to find password for name: %@ account: %@", status, name, account);
	
	status = SecKeychainItemDelete(itemRef);
//	if ( status != noErr )
		NSLog(@"Error (%i) while trying to delete password for name: %@ account: %@", status, name, account);
	
	CFRelease(itemRef);
}

@end
