//
//  $Id: PGPostgresTypeNumberHandler.m 3867 2012-09-26 02:45:14Z stuart02 $
//
//  PGPostgresTypeNumberHandler.m
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

#import "PGPostgresTypeNumberHandler.h"

static PGPostgresOid PGPostgresTypeNumberTypes[] = 
{ 
	PGPostgresOidInt8,
	PGPostgresOidInt2,
	PGPostgresOidInt4,
	PGPostgresOidFloat4,
	PGPostgresOidFloat8,
	PGPostgresOidBool,
	PGPostgresOidOid,
	PGPostgresOidMoney,
	PGPostgresOidNumeric,
	0 
};

@interface PGPostgresTypeNumberHandler ()

- (id)_integerObjectFromResult;
- (id)_floatObjectFromResult;
- (id)_booleanObjectFromResult;
- (id)_numericFromResult;

@end

@implementation PGPostgresTypeNumberHandler

@synthesize row = _row;
@synthesize type = _type;
@synthesize column = _column;
@synthesize result = _result;

#pragma mark -
#pragma mark Protocol Implementation

- (PGPostgresOid *)remoteTypes 
{
	return PGPostgresTypeNumberTypes;
}

- (Class)nativeClass 
{
	return [NSNumber class];
}

- (NSArray *)classAliases
{
	return nil;
}

- (id)objectFromResult
{	
	if (!_result || !_type) return [NSNull null];
	
	switch (_type) 
	{
		case PGPostgresOidInt8:
		case PGPostgresOidInt2:
		case PGPostgresOidInt4:
			return [self _integerObjectFromResult];
		case PGPostgresOidFloat4:
		case PGPostgresOidFloat8:
			return [self _floatObjectFromResult];
		case PGPostgresOidBool:
			return [self _booleanObjectFromResult];
		case PGPostgresOidNumeric:
			return [self _numericFromResult];
	}
	
	return [NSNull null];
}

#pragma mark -
#pragma mark Integer

/**
 * Converts an integer value to an NSNumber instance.
 *
 * @return An NSNumber representation of the the value.
 */
- (id)_integerObjectFromResult
{	
	NSUInteger length = PQgetlength(_result, (int)_row, (int)_column);
	
	if (!length) return [NSNull null];
	
	PGint2 int2;
	PGint4 int4;
	PGint8 int8;
	
	switch (length) 
	{
		case 2:
			if (!PQgetf(_result, _row, PGPostgresResultValueInt2, &int2)) return [NSNull null];
			
			return [NSNumber numberWithShort:int2];
		case 4:			
			if (!PQgetf(_result, _row, PGPostgresResultValueInt4, &int4)) return [NSNull null];
			
			return [NSNumber numberWithInteger:int4];
		case 8:			
			if (!PQgetf(_result, _row, PGPostgresResultValueInt8, &int8)) return [NSNull null];
			
			return [NSNumber numberWithLongLong:int8];
	}
	
	return [NSNull null];
}

#pragma mark -
#pragma mark Floating Point

/**
 * Converts a float value to an NSNumber instance.
 *
 * @return An NSNumber representation of the the value.
 */
- (id)_floatObjectFromResult
{	
	NSUInteger length = PQgetlength(_result, (int)_row, (int)_column);
	
	if (!length) return [NSNull null];
	
	PGfloat4 float4;
	PGfloat8 float8;
	
	switch (length) 
	{
		case 4:
			if (!PQgetf(_result, _row, PGPostgresResultValueFloat4, &float4)) return [NSNull null];
			
			return [NSNumber numberWithFloat:float4];
		case 8:
			if (!PQgetf(_result, _row, PGPostgresResultValueFloat8, &float8)) return [NSNull null];
			
			return [NSNumber numberWithDouble:float8];
	}
	
	return [NSNull null];
}

#pragma mark -
#pragma mark Boolean

/**
 * Converts a boolean value to an NSNumber instance.
 *
 * @return An NSNumber representation of the the value.
 */
- (id)_booleanObjectFromResult
{
	PGbool b;
	
	if (!PQgetf(_result, _row, PGPostgresResultValueBool, &b)) return [NSNull null];
	
	return [NSNumber numberWithInt:b];
}

#pragma mark -
#pragma mark Numeric

/**
 * Converts a numeric value to a native NSNumber instance.
 *
 * @return An NSNumber representation of the the value.
 */
- (id)_numericFromResult
{
	PGnumeric numeric;
	
	if (!PQgetf(_result, (int)_row, PGPostgresResultValueNumeric, (int)_column, &numeric)) return [NSNull null];
	
	NSString *stringValue = [[NSString alloc] initWithUTF8String:numeric];
	
	double value = [stringValue doubleValue];
	
	if (value == HUGE_VAL || value == -HUGE_VAL) return [NSNull null];
	
	[stringValue release];
	
	return [NSNumber numberWithDouble:value];
}

@end
