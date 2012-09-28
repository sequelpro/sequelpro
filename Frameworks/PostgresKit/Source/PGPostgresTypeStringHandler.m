//
//  $Id: PGPostgresTypeStringHandler.m 3866 2012-09-26 01:30:28Z stuart02 $
//
//  PGPostgresTypeStringHandler.m
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

#import "PGPostgresTypeStringHandler.h"
#import "PGPostgresConnection.h"

#import <netdb.h>

static PGPostgresOid PGPostgresTypeStringTypes[] = 
{ 
	PGPostgresOidText,
	PGPostgresOidChar,
	PGPostgresOidName,
	PGPostgresOidVarChar,
	PGPostgresOidJSON,
	PGPostgresOidXML,
	PGPostgresOidUUID,
	PGPostgresOidBit,
	PGPostgresOidVarBit,
	PGPostgresOidInetAddr,
	PGPostgresOidCidrAddr,
	PGPostgresOidMacAddr,
	PGPostgresOidUnknown,
	0 
};

@interface PGPostgresTypeStringHandler ()

- (id)_stringFromResult;
- (id)_macAddressFromResult;
- (id)_inetAddressFromResult;

@end

@implementation PGPostgresTypeStringHandler

@synthesize row = _row;
@synthesize type = _type;
@synthesize column = _column;
@synthesize result = _result;

#pragma mark -
#pragma mark Protocol Implementation

- (PGPostgresOid *)remoteTypes 
{
	return PGPostgresTypeStringTypes;
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
		case PGPostgresOidText:
		case PGPostgresOidChar:
		case PGPostgresOidName:
		case PGPostgresOidVarChar:
		case PGPostgresOidXML:
		case PGPostgresOidJSON:
		case PGPostgresOidUUID:
		case PGPostgresOidBit:
		case PGPostgresOidVarBit:
		case PGPostgresOidUnknown:
			return [self _stringFromResult];
		case PGPostgresOidMacAddr:
			return [self _macAddressFromResult];
		case PGPostgresOidInetAddr:
		case PGPostgresOidCidrAddr:
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
	
	if (!PQgetf(_result, (int)_row, PGPostgresResultValueMacAddr, (int)_column, &address)) return [NSNull null];
	
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
		
	if (!PQgetf(_result, (int)_row, _type == PGPostgresOidInetAddr ? PGPostgresResultValueInet : PGPostgresResultValueCidr, (int)_column, &inet)) return [NSNull null];
	
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
