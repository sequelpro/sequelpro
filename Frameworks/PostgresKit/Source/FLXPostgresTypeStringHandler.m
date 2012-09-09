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
	FLXPostgresOidMacAddr,
	FLXPostgresOidUnknown,
	0 
};

@interface FLXPostgresTypeStringHandler ()

- (NSString *)_macAddressFromResult:(const PGresult *)result atRow:(unsigned int)row column:(unsigned int)column;

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

- (id)objectFromResult:(const PGresult *)result atRow:(unsigned int)row column:(unsigned int)column
{
	if (PQftype(result, column) == FLXPostgresOidMacAddr) {
		return [self _macAddressFromResult:result atRow:row column:column];
	}
	
	const void *bytes = PQgetvalue(result, row, column);
	NSUInteger length = PQgetlength(result, row, column);
	
	if (!bytes || !length) return nil;
	
	return [[[NSString alloc] initWithBytes:bytes length:length encoding:[_connection stringEncoding]] autorelease];
}

#pragma mark -
#pragma mark Private API

/**
 * Converts a MAC address value to a string.
 *
 * @param result The result to extract the value from.
 * @param row    The row to extract the value from.
 * @param column The column to extract the value from.
 *
 * @return A string representation of the MAC address.
 */
- (NSString *)_macAddressFromResult:(const PGresult *)result atRow:(unsigned int)row column:(unsigned int)column
{
	PGmacaddr address;
	
	if (!PQgetf(result, row, "%macaddr", column, &address)) return nil;
	
	return [NSString stringWithFormat:@"%02d:%02d:%02d:%02d:%02d:%02d", address.a, address.b, address.c, address.d, address.e, address.f];
}

@end
