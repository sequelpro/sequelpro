//
//  $Id: PGPostgresTypeDateTimeHandler.m 3866 2012-09-26 01:30:28Z stuart02 $
//
//  PGPostgresTypeDateTimeHandler.m
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

#import "PGPostgresTypeDateTimeHandler.h"
#import "PGPostgresTypeNumberHandler.h"
#import "PGPostgresConnectionParameters.h"
#import "PGPostgresConnection.h"
#import "PGPostgresConnectionTypeHandling.h"
#import "PGPostgresTimeTZ.h"
#import "PGPostgresTimeInterval.h"
#import "PGPostgresKitPrivateAPI.h"

static PGPostgresOid PGPostgresTypeDateTimeTypes[] = 
{
	PGPostgresOidDate,
	PGPostgresOidTime,
	PGPostgresOidTimeTZ,
	PGPostgresOidAbsTime,
	PGPostgresOidTimestamp,
	PGPostgresOidTimestampTZ,
	PGPostgresOidInterval,
	0 
};

@interface PGPostgresTypeDateTimeHandler ()

- (id)_timeFromResult;
- (id)_timestmpFromResult;
- (id)_timeIntervalFromResult;

- (NSDate *)_dateFromResult;
- (NSDate *)_dateFromComponents:(NSDateComponents *)components;

@end

@implementation PGPostgresTypeDateTimeHandler

@synthesize row = _row;
@synthesize type = _type;
@synthesize column = _column;
@synthesize result = _result;

#pragma mark -
#pragma mark Protocol Implementation

- (PGPostgresOid *)remoteTypes 
{
	return PGPostgresTypeDateTimeTypes;
}

- (Class)nativeClass 
{
	return [NSDate class];
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
		case PGPostgresOidDate:
			return [self _dateFromResult];
		case PGPostgresOidTime:
		case PGPostgresOidTimeTZ:
		case PGPostgresOidAbsTime:
			return [self _timeFromResult];
		case PGPostgresOidTimestamp:
		case PGPostgresOidTimestampTZ:
			return [self _timestmpFromResult];
		case PGPostgresOidInterval:
			return [self _timeIntervalFromResult];
	}
	
	return [NSNull null];
}

#pragma mark -
#pragma mark Private API

/**
 * Returns an NSDate created from a date value.
 * 
 * @return The NSDate representation.
 */
- (id)_dateFromResult
{	
	PGdate date;
	
	if (!PQgetf(_result, (int)_row, PGPostgresResultValueDate, (int)_column, &date)) return [NSNull null];
		
	NSDateComponents *components = [[NSDateComponents alloc] init];
	
	[components setDay:date.mday];
	[components setMonth:date.mon + 1]; // Months are indexed from 0
	[components setYear:date.year];
	
	return [self _dateFromComponents:components];
}

/**
 * Converts a time interval value to a PGPostgresTimeInterval instance.
 * 
 * @return The PGPostgresTimeInterval representation.
 */
- (id)_timeIntervalFromResult
{
	PGinterval interval;
		
	if (!PQgetf(_result, (int)_row, PGPostgresResultValueInterval, (int)_column, &interval)) return [NSNull null];
	
	return [PGPostgresTimeInterval intervalWithPGInterval:&interval];
}

/**
 * Returns a native object created from a time value.
 *
 * @note The date part should be ignored as it's set to a default value.
 *
 * @return The object representation.
 */
- (id)_timeFromResult
{
	PGtime pgTime;
	
	BOOL hasTimeZone = _type == PGPostgresOidTimeTZ;
	
	if (!PQgetf(_result, (int)_row, hasTimeZone ? PGPostgresResultValueTimeTZ : PGPostgresResultValueTime, (int)_column, &pgTime)) return [NSNull null];
	
	NSDateComponents *components = [[NSDateComponents alloc] init];
	
	// Default date values; should be ignored
	[components setDay:1];
	[components setMonth:1];
	[components setYear:2000];
	
	[components setHour:pgTime.hour];
	[components setMinute:pgTime.min];
	[components setSecond:pgTime.sec];
	
	NSDate *date = [self _dateFromComponents:components];

	return hasTimeZone ? (id)[PGPostgresTimeTZ timeWithDate:date timeZoneGMTOffset:pgTime.gmtoff] : date;
}

/**
 * Returns a native object created from a timestamp value.
 *
 * @return The object representation.
 */
- (id)_timestmpFromResult
{
	PGtimestamp timestamp;
	
	BOOL hasTimeZone = _type == PGPostgresOidTimestampTZ;
	
	if (!PQgetf(_result, (int)_row, hasTimeZone ? PGPostgresResultValueTimestmpTZ : PGPostgresResultValueTimestamp, (int)_column, &timestamp)) return [NSNull null];
	
	PGPostgresTimeTZ *timestampTZ = nil;
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp.epoch];
	
	if (hasTimeZone) {
		timestampTZ = [PGPostgresTimeTZ timeWithDate:date timeZoneGMTOffset:timestamp.time.gmtoff];
		
		[timestampTZ setHasDate:YES];
	}
	
	return hasTimeZone ? (id)timestampTZ : date;
}

/**
 * Returns an NSDate created from the supplied components.
 *
 * @param The components to create the date from.
 *
 * @return The NSDate created.
 */
- (NSDate *)_dateFromComponents:(NSDateComponents *)components
{
	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	
	NSDate *date = [gregorian dateFromComponents:components];
	
	[gregorian release];
	
	return date;
}

@end
