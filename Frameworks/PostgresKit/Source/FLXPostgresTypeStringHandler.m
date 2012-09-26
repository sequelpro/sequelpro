//
//  $Id$
//
//  FLXPostgresTypeStringHandler.m
//  PostgresKit
//
//  Copyright (c) 2008-2009 David Thorpe, djt@mutablelogic.com
//
//  Forked by the Sequel Pro Team on July 22, 2012.
// 
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not 
//  use this file except in compliance with the License. You may obtain a copy of 
//  the License at
// 
//  http://www.apache.org/licenses/LICENSE-2.0
// 
//  Unless required by applicable law or agreed to in writing, software 
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT 
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the 
//  License for the specific language governing permissions and limitations under
//  the License.

#import "FLXPostgresTypeStringHandler.h"
#import "FLXPostgresConnection.h"

#import <netdb.h>

static FLXPostgresOid FLXPostgresTypeStringTypes[] = 
{ 
	FLXPostgresOidText,
	FLXPostgresOidChar,
	FLXPostgresOidName,
	FLXPostgresOidVarChar,
	FLXPostgresOidXML,
	FLXPostgresOidUUID,
	FLXPostgresOidBit,
	FLXPostgresOidVarBit,
	FLXPostgresOidInetAddr,
	FLXPostgresOidCidrAddr,
	FLXPostgresOidMacAddr,
	FLXPostgresOidUnknown,
	0 
};

@interface FLXPostgresTypeStringHandler ()

- (id)_stringFromResult;
- (id)_macAddressFromResult;
- (id)_inetAddressFromResult;

@end

@implementation FLXPostgresTypeStringHandler

@synthesize row = _row;
@synthesize type = _type;
@synthesize column = _column;
@synthesize result = _result;

#pragma mark -
#pragma mark Protocol Implementation

- (FLXPostgresOid *)remoteTypes 
{
	return FLXPostgresTypeStringTypes;
}

- (Class)nativeClass 
{
	return [NSString class];
}

- (NSArray *)classAliases
{
	return [NSArray arrayWithObject:@"NSCFString"];
}

- (id)objectFromResult
{	
	if (!_result || !_type) return [NSNull null];
	
	switch (_type)
	{
		case FLXPostgresOidText:
		case FLXPostgresOidChar:
		case FLXPostgresOidName:
		case FLXPostgresOidVarChar:
		case FLXPostgresOidXML:
		case FLXPostgresOidUUID:
		case FLXPostgresOidBit:
		case FLXPostgresOidVarBit:
		case FLXPostgresOidUnknown:
			return [self _stringFromResult];
		case FLXPostgresOidMacAddr:
			return [self _macAddressFromResult];
		case FLXPostgresOidInetAddr:
		case FLXPostgresOidCidrAddr:
			return [self _inetAddressFromResult];
	}
	
	return [NSNull null];
}

#pragma mark -
#pragma mark Private API

/**
 * Converts a char value to a string.
 *
 * @return A string representation of the value.
 */
- (id)_stringFromResult
{
	const void *bytes = PQgetvalue(_result, (int)_row, (int)_column);
	NSUInteger length = PQgetlength(_result, (int)_row, (int)_column);
		
	if (!bytes || !length) return [NSNull null];
	
	return [[[NSString alloc] initWithBytes:bytes length:length encoding:[_connection stringEncoding]] autorelease];
}

/**
 * Converts a MAC address value to a string.
 *
 * @return A string representation of the MAC address.
 */
- (id)_macAddressFromResult
{
	PGmacaddr address;
	
	if (!PQgetf(_result, (int)_row, FLXPostgresResultValueMacAddr, (int)_column, &address)) return [NSNull null];
	
	return [NSString stringWithFormat:@"%02d:%02d:%02d:%02d:%02d:%02d", address.a, address.b, address.c, address.d, address.e, address.f];
}

/**
 * Converts a network address value to a string.
 *
 * @return A string representation of the network address.
 */
- (id)_inetAddressFromResult
{
	PGinet inet;
		
	if (!PQgetf(_result, (int)_row, _type == FLXPostgresOidInetAddr ? FLXPostgresResultValueInet : FLXPostgresResultValueCidr, (int)_column, &inet)) return [NSNull null];
	
	char ip[80];
	struct sockaddr *sa = (struct sockaddr *)inet.sa_buf;
	
	int success = getnameinfo(sa, inet.sa_buf_len, ip, sizeof(ip), NULL, 0, NI_NUMERICHOST);
	
	if (success != 0) {
		const char *error = gai_strerror(success);
		
		NSLog(@"PostgresKit: Error: Failed to convert IP address to string representation (%s)", error);
		
		return [NSNull null];
	}
	
	return [NSString stringWithUTF8String:ip];
}

@end
