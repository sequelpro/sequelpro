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
	FLXPostgresOidNumeric,
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

- (id)_stringFromResult:(const PGresult *)result atRow:(NSUInteger)row column:(NSUInteger)column;
- (id)_macAddressFromResult:(const PGresult *)result atRow:(NSUInteger)row column:(NSUInteger)column;
- (id)_inetAddressFromResult:(const PGresult *)result atRow:(NSUInteger)row column:(NSUInteger)column type:(FLXPostgresOid)type;

@end


@implementation FLXPostgresTypeStringHandler

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

- (id)objectFromResult:(const PGresult *)result atRow:(NSUInteger)row column:(NSUInteger)column
{
	FLXPostgresOid type = PQftype(result, column);
	
	_row = row;
	_column = column;
	_result = result;
	
	switch (type)
	{
		case FLXPostgresOidMacAddr:
			return [self _macAddressFromResult:result atRow:row column:column];
		case FLXPostgresOidInetAddr:
		case FLXPostgresOidCidrAddr:
			return [self _inetAddressFromResult:result atRow:row column:column type:type];
		case FLXPostgresOidText:
		case FLXPostgresOidChar:
		case FLXPostgresOidName:
		case FLXPostgresOidNumeric:
		case FLXPostgresOidVarChar:
		case FLXPostgresOidXML:
		case FLXPostgresOidUUID:
		case FLXPostgresOidBit:
		case FLXPostgresOidVarBit:
		case FLXPostgresOidUnknown:
			return [self _stringFromResult:result atRow:row column:column];
		default:
			return [NSNull null];
	}
}

#pragma mark -
#pragma mark Private API

/**
 * Converts a char value to a string.
 *
 * @param result The result to extract the value from.
 * @param row    The row to extract the value from.
 * @param column The column to extract the value from.
 *
 * @return A string representation of the value.
 */
- (id)_stringFromResult:(const PGresult *)result atRow:(NSUInteger)row column:(NSUInteger)column
{
	const void *bytes = PQgetvalue(result, row, column);
	NSUInteger length = PQgetlength(result, row, column);
	
	if (!bytes || !length) return [NSNull null];
	
	return [[[NSString alloc] initWithBytes:bytes length:length encoding:[_connection stringEncoding]] autorelease];
}

/**
 * Converts a MAC address value to a string.
 *
 * @param result The result to extract the value from.
 * @param row    The row to extract the value from.
 * @param column The column to extract the value from.
 *
 * @return A string representation of the MAC address.
 */
- (id)_macAddressFromResult:(const PGresult *)result atRow:(NSUInteger)row column:(NSUInteger)column
{
	PGmacaddr address;
	
	if (!PQgetf(result, row, "%macaddr", column, &address)) return [NSNull null];
	
	return [NSString stringWithFormat:@"%02d:%02d:%02d:%02d:%02d:%02d", address.a, address.b, address.c, address.d, address.e, address.f];
}

/**
 * Converts a network address value to a string.
 *
 * @param result The result to extract the value from.
 * @param row    The row to extract the value from.
 * @param column The column to extract the value from.
 * @param type   The type of the value to extract.
 *
 * @return A string representation of the network address.
 */
- (id)_inetAddressFromResult:(const PGresult *)result atRow:(NSUInteger)row column:(NSUInteger)column type:(FLXPostgresOid)type
{
	PGinet inet;
		
	if (!PQgetf(result, row, type == FLXPostgresOidInetAddr ? "%inet" : "%cidr", column, &inet)) return [NSNull null];
	
	char ip[80];
	struct sockaddr *sa = (struct sockaddr *)inet.sa_buf;
	
	NSUInteger success = getnameinfo(sa, inet.sa_buf_len, ip, sizeof(ip), NULL, 0, NI_NUMERICHOST);
	
	if (success != 0) {
		const char *error = gai_strerror(success);
		
		NSLog(@"PostgresKit: Error: Failed to convert IP address to string representation (%s)", error);
		
		return [NSNull null];
	}
	
	return [NSString stringWithUTF8String:ip];
}

@end
