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
#import "FLXPostgresTypes.h"

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

@implementation FLXPostgresTypeNumberHandler

#pragma mark -
#pragma mark Integer & Unsigned Integer

- (SInt16)int16FromBytes:(const void *)bytes 
{
	if (!bytes) return 0;
	
	return EndianS16_BtoN(*((SInt16 *)bytes));
}

- (SInt32)int32FromBytes:(const void *)bytes 
{
	if (!bytes) return 0;

	return EndianS32_BtoN(*((SInt32 *)bytes));
}

- (SInt64)int64FromBytes:(const void *)bytes 
{
	if (!bytes) return 0;
	
	return EndianS64_BtoN(*((SInt64 *)bytes));		
}

- (UInt16)unsignedInt16FromBytes:(const void *)bytes 
{
	if (!bytes) return 0;
	
	return EndianU16_BtoN(*((UInt16 *)bytes));
}

- (UInt32)unsignedInt32FromBytes:(const void *)bytes 
{
	if (!bytes) return 0;
	
	return EndianU32_BtoN(*((UInt32 *)bytes));		
}

- (UInt64)unsignedInt64FromBytes:(const void *)bytes 
{
	if (!bytes) return 0;
	
	return EndianU64_BtoN(*((UInt64 *)bytes));		
}

- (NSNumber *)integerObjectFromBytes:(const void *)bytes length:(NSUInteger)length 
{
	if (!bytes) return nil;
	
	switch (length) 
	{
		case 2:
			return [NSNumber numberWithShort:[self int16FromBytes:bytes]];
		case 4:
			return [NSNumber numberWithInteger:[self int32FromBytes:bytes]];
		case 8:
			return [NSNumber numberWithLongLong:[self int64FromBytes:bytes]];
	}
	
	return nil;
}

- (NSNumber *)unsignedIntegerObjectFromBytes:(const void *)bytes length:(NSUInteger)length 
{
	if (!bytes) return nil;
	
	switch (length) 
	{
		case 2:
			return [NSNumber numberWithUnsignedShort:[self unsignedInt16FromBytes:bytes]];
		case 4:
			return [NSNumber numberWithUnsignedInteger:[self unsignedInt32FromBytes:bytes]];
		case 8:
			return [NSNumber numberWithUnsignedLongLong:[self unsignedInt64FromBytes:bytes]];
	}
	
	return nil;
}

- (NSData *)remoteDataFromInt64:(SInt64)value 
{
	if (sizeof(SInt64) != 8) return nil;

	value = EndianS64_NtoB(value);

	return [NSData dataWithBytes:&value length:sizeof(value)];
}

- (NSData *)remoteDataFromInt32:(SInt32)value 
{
	if (sizeof(SInt32) != 4) return nil;

	value = EndianS32_NtoB(value);
	
	return [NSData dataWithBytes:&value length:sizeof(value)];
}

- (NSData *)remoteDataFromInt16:(SInt16)value 
{
	if (sizeof(SInt16) != 2) return nil;
	
	value = EndianS16_NtoB(value);

	return [NSData dataWithBytes:&value length:sizeof(value)];
}

#pragma mark -
#pragma mark Floating Point

- (Float32)float32FromBytes:(const void *)bytes 
{
	if (!bytes) return 0;

    union { Float32 r; UInt32 i; } u32;
	
	u32.r = *((Float32 *)bytes);		
	u32.i = CFSwapInt32HostToBig(u32.i);			
	
	return u32.r;
}

- (Float64)float64FromBytes:(const void *)bytes 
{
	if (!bytes) return 0;
	
    union { Float64 r; UInt64 i; } u64;
	
	u64.r = *((Float64 *)bytes);		
	u64.i = CFSwapInt64HostToBig(u64.i);			
	
	return u64.r;		
}

- (NSNumber *)realObjectFromBytes:(const void *)bytes length:(NSUInteger)length 
{	
	switch (length) 
	{
		case 4:
			return [NSNumber numberWithFloat:[self float32FromBytes:bytes]];
		case 8:
			return [NSNumber numberWithDouble:[self float64FromBytes:bytes]];
	}
	
	return nil;
}


- (NSData *)remoteDataFromFloat32:(Float32)value 
{
	if (sizeof(Float32) != 4) return nil;
	
	union { Float32 r; UInt32 i; } u32;
	
	u32.r = value;
	u32.i = CFSwapInt32HostToBig(u32.i);			
	
	return [NSData dataWithBytes:&u32 length:sizeof(u32)];
}

- (NSData *)remoteDataFromFloat64:(Float64)value 
{
	if (sizeof(Float64) != 8) return nil;
	
	union { Float64 r; UInt64 i; } u64;
	
	u64.r = value;
	u64.i = CFSwapInt64HostToBig(u64.i);			

	return [NSData dataWithBytes:&u64 length:sizeof(u64)];
}

#pragma mark -
#pragma mark Boolean

- (BOOL)booleanFromBytes:(const void *)bytes 
{
	if (!bytes) return NO;
	
	return (*((const int8_t *)bytes) ? YES : NO);
}

- (NSNumber *)booleanObjectFromBytes:(const void *)bytes length:(NSUInteger)length 
{
	if (!bytes || length != 1) return nil;
	
	return [NSNumber numberWithBool:[self booleanFromBytes:bytes]];
}


- (NSData *)remoteDataFromBoolean:(BOOL)value 
{
	return [NSData dataWithBytes:&value length:1];
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

- (NSData *)remoteDataFromObject:(id)object type:(FLXPostgresOid *)type 
{
	if (!object || !type || ![object isKindOfClass:[NSNumber class]]) return nil;

	NSNumber *number = (NSNumber *)object;
	
	const char *objectType = [number objCType];
	
	switch (objectType[0]) 
	{
		case 'c':
		case 'C':
		case 'B': // Boolean
			(*type) = FLXPostgresOidBool;
			return [self remoteDataFromBoolean:[(NSNumber *)object boolValue]];
		case 'i': // Integer
		case 'l': // Long
		case 'S': // Unsigned short
			(*type) = FLXPostgresOidInt4;
			return [self remoteDataFromInt32:[(NSNumber *)object shortValue]];
		case 's':
			(*type) = FLXPostgresOidInt2;
			return [self remoteDataFromInt16:[(NSNumber *)object shortValue]];
		case 'q': // Long long
		case 'Q': // Unsigned long long
		case 'I': // Unsigned integer
		case 'L': // Unsigned long
			(*type) = FLXPostgresOidInt8;
			return [self remoteDataFromInt64:[(NSNumber *)object longLongValue]];
		case 'f': // Float
			(*type) = FLXPostgresOidFloat4;
			return [self remoteDataFromFloat32:[(NSNumber *)object floatValue]];
		case 'd': // Double
			(*type) = FLXPostgresOidFloat8;
			return [self remoteDataFromFloat64:[(NSNumber *)object doubleValue]];
		default:
			return nil;
	}
}

- (id)objectFromRemoteData:(const void *)bytes length:(NSUInteger)length type:(FLXPostgresOid)type 
{	
	if (!bytes || !length || !type) return nil;
	
	switch (type) 
	{
		case FLXPostgresOidInt8:
		case FLXPostgresOidInt2:
		case FLXPostgresOidInt4:
			return [self integerObjectFromBytes:bytes length:length];
		case FLXPostgresOidFloat4:
		case FLXPostgresOidFloat8:
			return [self realObjectFromBytes:bytes length:length];
		case FLXPostgresOidBool:
			return [self booleanObjectFromBytes:bytes length:length];
		default:
			return nil;
	}
}

@end
