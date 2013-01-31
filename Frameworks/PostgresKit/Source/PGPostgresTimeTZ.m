//
//  $Id: PGPostgresTimeTZ.m 3827 2012-09-09 00:51:43Z stuart02 $
//
//  PGPostgresTimeTZ.m
//  PostgresKit
//
//  Created by Stuart Connolly (stuconnolly.com) on September 8, 2012.
//  Copyright (c) 2012 Stuart Connolly. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.

#import "PGPostgresTimeTZ.h"

@implementation PGPostgresTimeTZ

@synthesize hasDate = _hasDate;
@synthesize date = _date;
@synthesize timeZone = _timeZone;

- (id)init
{
	return [self initWithDate:[NSDate date] timeZoneGMTOffset:[[NSTimeZone systemTimeZone] secondsFromGMT]];
}

+ (PGPostgresTimeTZ *)timeWithDate:(NSDate *)date timeZoneGMTOffset:(NSUInteger)offset
{
	return [[[PGPostgresTimeTZ alloc] initWithDate:date timeZoneGMTOffset:offset] autorelease];
}

/**
 * Initialise a PGPostgresTimeTZ with the supplied date and GMT offset.
 *
 * @param date   The date to use.
 * @param offset The GMT offset in seconds that the associated time zone is.
 *
 * @return The initialised instance.
 */
- (id)initWithDate:(NSDate *)date timeZoneGMTOffset:(NSUInteger)offset
{
	if ((self = [super init])) {
		_hasDate = NO;
		
		[self setDate:date];
		[self setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:offset]];
	}
	
	return self;
}

#pragma mark -

- (NSUInteger)hash
{
	return [_date hash] ^ [_timeZone hash];
}

- (BOOL)isEqual:(id)object
{
	if (object == self) return YES;
	
	if (!object || ![object isKindOfClass:[self class]]) return NO;
	
	return [_date isEqualToDate:[(PGPostgresTimeTZ *)object date]] && [_timeZone isEqualToTimeZone:[(PGPostgresTimeTZ *)object timeZone]];
}

- (NSString *)description
{
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	
	[formatter setDateStyle:_hasDate ? NSDateFormatterMediumStyle : NSDateFormatterNoStyle];
	[formatter setTimeStyle:NSDateFormatterMediumStyle];
	
	NSString *output = [formatter stringFromDate:_date];
	
	[formatter release];
	
	return [NSString stringWithFormat:@"%@ %@", output, [_timeZone abbreviation]];
}

#pragma mark -

- (void)dealloc
{
	if (_date) [_date release], _date = nil;
	if (_timeZone) [_timeZone release], _timeZone = nil;
	
	[super dealloc];
}

@end
