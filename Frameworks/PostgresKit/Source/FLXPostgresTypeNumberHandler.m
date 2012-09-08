//
//  $Id$
//
//  FLXPostgresTypeNumberHandler.m
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

#import "FLXPostgresTypeNumberHandler.h"

static FLXPostgresOid FLXPostgresTypeNumberTypes[] = 
{ 
	FLXPostgresOidInt8,
	FLXPostgresOidInt2,
	FLXPostgresOidInt4,
	FLXPostgresOidFloat4,
	FLXPostgresOidFloat8,
	FLXPostgresOidBool,  
	0 
};

@interface FLXPostgresTypeNumberHandler ()

- (SInt16)_int16FromBytes:(const void *)bytes;
- (SInt32)_int32FromBytes:(const void *)bytes;
- (SInt64)_int64FromBytes:(const void *)bytes;

- (Float32)_float32FromBytes:(const void *)bytes;
- (Float64)_float64FromBytes:(const void *)bytes;

@end

@implementation FLXPostgresTypeNumberHandler

#pragma mark -
#pragma mark Integer

- (NSNumber *)_integerObjectFromBytes:(const void *)bytes length:(NSUInteger)length 
{	
	switch (length) 
	{
		case 2:
			return [NSNumber numberWithShort:[self _int16FromBytes:bytes]];
		case 4:
			return [NSNumber numberWithInteger:[self _int32FromBytes:bytes]];
		case 8:
			return [NSNumber numberWithLongLong:[self _int64FromBytes:bytes]];
	}
	
	return nil;
}

- (SInt16)_int16FromBytes:(const void *)bytes 
{	
	return EndianS16_BtoN(*((SInt16 *)bytes));
}

- (SInt32)_int32FromBytes:(const void *)bytes 
{
	return EndianS32_BtoN(*((SInt32 *)bytes));
}

- (SInt64)_int64FromBytes:(const void *)bytes 
{	
	return EndianS64_BtoN(*((SInt64 *)bytes));		
}

#pragma mark -
#pragma mark Floating Point

- (NSNumber *)_floatObjectFromBytes:(const void *)bytes length:(NSUInteger)length 
{	
	switch (length) 
	{
		case 4:
			return [NSNumber numberWithFloat:[self _float32FromBytes:bytes]];
		case 8:
			return [NSNumber numberWithDouble:[self _float64FromBytes:bytes]];
	}
	
	return nil;
}

- (Float32)_float32FromBytes:(const void *)bytes 
{
    union { Float32 r; UInt32 i; } u32;
	
	u32.r = *((Float32 *)bytes);		
	u32.i = CFSwapInt32HostToBig(u32.i);			
	
	return u32.r;
}

- (Float64)_float64FromBytes:(const void *)bytes 
{	
    union { Float64 r; UInt64 i; } u64;
	
	u64.r = *((Float64 *)bytes);		
	u64.i = CFSwapInt64HostToBig(u64.i);			
	
	return u64.r;		
}

#pragma mark -
#pragma mark Boolean

- (NSNumber *)_booleanObjectFromBytes:(const void *)bytes length:(NSUInteger)length 
{
	if (length != 1) return nil;
	
	return [NSNumber numberWithBool:*((const int8_t *)bytes) ? YES : NO];
}

#pragma mark -
#pragma mark Protocol Implementation

- (FLXPostgresOid *)remoteTypes 
{
	return FLXPostgresTypeNumberTypes;
}

- (Class)nativeClass 
{
	return [NSNumber class];
}

- (NSArray *)classAliases
{
	return nil;
}

- (id)objectFromResult:(const PGresult *)result atRow:(unsigned int)row column:(unsigned int)column
{	
	FLXPostgresOid type = PQftype(result, column);
	NSUInteger length = PQgetlength(result, row, column);
	const void *bytes = PQgetvalue(result, row, column);
	
	if (!bytes || !length) return nil;
	
	switch (type) 
	{
		case FLXPostgresOidInt8:
		case FLXPostgresOidInt2:
		case FLXPostgresOidInt4:
			return [self _integerObjectFromBytes:bytes length:length];
		case FLXPostgresOidFloat4:
		case FLXPostgresOidFloat8:
			return [self _floatObjectFromBytes:bytes length:length];
		case FLXPostgresOidBool:
			return [self _booleanObjectFromBytes:bytes length:length];
		default:
			return nil;
	}
}

@end
