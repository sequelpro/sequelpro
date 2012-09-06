//
//  $Id$
//
//  FLXPostgresTypeDateTimeHandler.m
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

#import "FLXPostgresTypeDateTimeHandler.h"
#import "FLXPostgresTypeNumberHandler.h"
#import "FLXPostgresConnectionParameters.h"
#import "FLXPostgresConnection.h"
#import "FLXPostgresConnectionTypeHandling.h"

// Microseconds per second
#define USECS_PER_SEC 1000000

static FLXPostgresOid FLXPostgresTypeDateTimeTypes[] = 
{
	FLXPostgresOidDate,
	FLXPostgresOidTime,
	FLXPostgresOidTimeTZ,
	FLXPostgresOidAbsTime,
	FLXPostgresOidTimestamp,
	FLXPostgresOidTimestampTZ,
	0 
};

@interface FLXPostgresTypeDateTimeHandler ()

- (NSDate *)_postgresEpochDate;
- (NSDate *)_dateFromBytes:(const void *)bytes length:(NSUInteger)length;
- (NSDate *)_timeFromBytes:(const void *)bytes length:(NSUInteger)length;
- (NSDate *)_timestampFromBytes:(const void *)bytes length:(NSUInteger)length;
- (NSDate *)_dateByAddingComponents:(NSDateComponents *)components toDate:(NSDate *)date;

@end

@implementation FLXPostgresTypeDateTimeHandler

#pragma mark -
#pragma mark Protocol Implementation

- (FLXPostgresOid *)remoteTypes 
{
	return FLXPostgresTypeDateTimeTypes;
}

- (Class)nativeClass 
{
	return [NSDate class];
}

- (NSArray *)classAliases
{
	return nil;
}

- (NSData *)remoteDataFromObject:(id)object type:(FLXPostgresOid *)type 
{
	if (!object || !type || ![object isKindOfClass:[NSDate class]]) return nil;
	
	return nil;
}

- (id)objectFromRemoteData:(const void *)bytes length:(NSUInteger)length type:(FLXPostgresOid)type 
{
	if (!bytes || !type) return nil;
	
	if (!_numberHandler) {
		_numberHandler = (FLXPostgresTypeNumberHandler *)[_connection typeHandlerForClass:[NSNumber class]];
	}
	
	switch (type) 
	{
		case FLXPostgresOidDate:
			return [self _dateFromBytes:bytes length:length];
		case FLXPostgresOidTime:
		case FLXPostgresOidTimeTZ:
		case FLXPostgresOidAbsTime:
			return [self _timeFromBytes:bytes length:length];
		case FLXPostgresOidTimestamp:
		case FLXPostgresOidTimestampTZ:
			return [self _timestampFromBytes:bytes length:length];
		default:
			return nil;
	}
}

- (NSString *)quotedStringFromObject:(id)object 
{
	if (!object || ![object isKindOfClass:[NSString class]]) return nil;
	
	// TODO: Imeplement me!
	return nil;
}

#pragma mark -
#pragma mark Private API

/**
 * Returns the internal expoch date used by Postgres.
 *
 * @return The epoch date as an NSDate.
 */
- (NSDate *)_postgresEpochDate
{
	NSDateComponents *components = [[NSDateComponents alloc] init];
	
	[components setDay:1];
	[components setMonth:1];
	[components setYear:2000];
	
	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	
	NSDate *date = [gregorian dateFromComponents:components];
	
	[components release];
	[gregorian release];
	
	return date;
}

/**
 * Converts the supplied bytes representing a date to an NSDate instance.
 *
 * @param bytes  The bytes to convert.
 * @param length The number of bytes.
 *
 * @return The NSDate representation.
 */
- (NSDate *)_dateFromBytes:(const void *)bytes length:(NSUInteger)length
{	
	NSDateComponents *components = [[NSDateComponents alloc] init];
	
	[components setDay:[[_numberHandler integerObjectFromBytes:bytes length:length] integerValue]];
	
	NSDate *date = [self _dateByAddingComponents:components toDate:[self _postgresEpochDate]];
	
	[components release];
	
	return date;
}

/**
 * Converts the supplied bytes representing the time to an NSDate instance.
 *
 * @param bytes  The bytes to convert.
 * @param length The number of bytes.
 *
 * @return The NSDate representation.
 */
- (NSDate *)_timeFromBytes:(const void *)bytes length:(NSUInteger)length
{
	NSNumber *time = [_numberHandler integerObjectFromBytes:bytes length:length];
	
	return [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)[time doubleValue]];
}

/**
 * Converts the supplied bytes representing a timestamp to an NSDate instance.
 *
 * @param bytes  The bytes to convert.
 * @param length The number of bytes.
 *
 * @return The NSDate representation.
 */
- (NSDate *)_timestampFromBytes:(const void *)bytes length:(NSUInteger)length
{
	NSDate *date = nil;
	NSUInteger seconds = 0;
	
	if ([[[_connection parameters] valueForParameter:FLXPostgresParameterIntegerDateTimes] boolValue]) {		
		seconds = ([[_numberHandler integerObjectFromBytes:bytes length:length] doubleValue] / (double)USECS_PER_SEC);
	}
	else {		
		seconds = [_numberHandler float64FromBytes:bytes];
	}
	
	NSDateComponents *components = [[NSDateComponents alloc] init];
	
	[components setSecond:seconds];
	
	date = [self _dateByAddingComponents:components toDate:[self _postgresEpochDate]];
	
	[components release];
	
	return date;
}

/**
 * Returns the result of adding the supplied components to the supplied date.
 *
 * @param components The date components to add.
 * @param date       The date to add the components to.
 *
 * @return The result of the addition to the date.
 */
- (NSDate *)_dateByAddingComponents:(NSDateComponents *)components toDate:(NSDate *)date
{
	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	
	NSDate *newDate = [gregorian dateByAddingComponents:components toDate:date options:0];
	
	[gregorian release];
	
	return newDate;
}

@end
