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
#import "FLXTimeTZ.h"

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

- (NSDate *)_dateFromResult:(const PGresult *)result atRow:(NSUInteger)row column:(NSUInteger)column;
- (id)_timeFromResult:(const PGresult *)result atRow:(NSUInteger)row column:(NSUInteger)column type:(FLXPostgresOid)type;
- (id)_timestmpFromResult:(const PGresult *)result atRow:(NSUInteger)row column:(NSUInteger)column type:(FLXPostgresOid)type;

- (NSDate *)_dateFromComponents:(NSDateComponents *)components;

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

- (id)objectFromResult:(const PGresult *)result atRow:(unsigned int)row column:(unsigned int)column 
{		
	FLXPostgresOid type = PQftype(result, column);
	
	switch (type) 
	{
		case FLXPostgresOidDate:
			return [self _dateFromResult:result atRow:row column:column];
		case FLXPostgresOidTime:
		case FLXPostgresOidTimeTZ:
		case FLXPostgresOidAbsTime:
			return [self _timeFromResult:result atRow:row column:column type:type];
		case FLXPostgresOidTimestamp:
		case FLXPostgresOidTimestampTZ:
			return [self _timestmpFromResult:result atRow:row column:column type:type];
		default:
			return nil;
	}
}

#pragma mark -
#pragma mark Private API

/**
 * Returns an NSDate created from a date value.
 *
 * @param result The result to extract the value from.
 * @param row    The row to extract the value from.
 * @param column The column to extract the value from.
 * 
 * @return The NSDate representation.
 */
- (NSDate *)_dateFromResult:(const PGresult *)result atRow:(NSUInteger)row column:(NSUInteger)column
{	
	PGdate date;
	
	PQgetf(result, row, "%date", column, &date);
		
	NSDateComponents *components = [[NSDateComponents alloc] init];
	
	[components setDay:date.mday];
	[components setMonth:date.mon + 1]; // Months are indexed from 0
	[components setYear:date.year];
	
	return [self _dateFromComponents:components];
}

/**
 * Returns a native object created from a time value.
 *
 * @note The date part should be ignored as it's set to a default value.
 *
 * @param result The result to extract the value from.
 * @param row    The row to extract the value from.
 * @param column The column to extract the value from.
 * @type  type   The type to be converted from (handles times and times with a time zone).
 *
 * @return The object representation.
 */
- (id)_timeFromResult:(const PGresult *)result atRow:(NSUInteger)row column:(NSUInteger)column type:(FLXPostgresOid)type
{
	PGtime time;
	
	BOOL hasTimeZone = type == FLXPostgresOidTimeTZ;
	
	PQgetf(result, row, hasTimeZone ? "%timetz" : "%time", column, &time);
	
	NSDateComponents *components = [[NSDateComponents alloc] init];
	
	// Default date values; should be ignored
	[components setDay:1];
	[components setMonth:1];
	[components setYear:2000];
	
	[components setHour:time.hour];
	[components setMinute:time.min];
	[components setSecond:time.sec];
	
	NSDate *date = [self _dateFromComponents:components];

	return hasTimeZone ? [FLXTimeTZ timeWithDate:date timeZoneGMTOffset:time.gmtoff] : date;
}

/**
 * Returns a native object created from a timestamp value.
 *
 * @param result The result to extract the value from.
 * @param row    The row to extract the value from.
 * @param column The column to extract the value from.
 * @type  type   The type to be converted from (handles timestamps and timestamps with a time zone).
 *
 * @return The object representation.
 */
- (id)_timestmpFromResult:(const PGresult *)result atRow:(NSUInteger)row column:(NSUInteger)column type:(FLXPostgresOid)type
{
	PGtimestamp timestamp;
	
	BOOL hasTimeZone = type == FLXPostgresOidTimestampTZ;
	
	PQgetf(result, row, hasTimeZone ? "%timstamptz" : "%timestamp", column, &timestamp);
	
	FLXTimeTZ *timestampTZ = nil;
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp.epoch];
	
	if (hasTimeZone) {
		timestampTZ = [FLXTimeTZ timeWithDate:date timeZoneGMTOffset:timestamp.time.gmtoff];
		
		[timestampTZ setHasDate:YES];
	}
	
	return hasTimeZone ? timestampTZ : date;
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
