//
//  $Id$
//
//  FLXPostgresTimeInterval.m
//  PostgresKit
//
//  Created by Stuart Connolly (stuconnolly.com) on September 9, 2012.
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

#import "FLXPostgresTimeInterval.h"
#import "FLXPostgresKitPrivateAPI.h"

@implementation FLXPostgresTimeInterval

@synthesize microseconds = _microseconds;
@synthesize seconds = _seconds;
@synthesize minutes = _minutes;
@synthesize hours = _hours;
@synthesize days = _days;
@synthesize months = _months;
@synthesize years = _years;

#pragma mark -

- (id)initWithInterval:(const PGinterval *)interval
{
	if ((self = [super init])) {
		if (interval) {
			_microseconds = interval->usecs;
			_seconds = interval->secs;
			_minutes = interval->mins;
			_hours = interval->hours;
			_days = interval->days;
			_months = interval->mons;
			_years = interval->years;
		}
	}
	
	return self;
}

#pragma mark -

- (NSString *)description
{
	return [NSString stringWithFormat:@"%d years, %d months, %d days, %d hours, %d minutes, %d seconds and %d microseconds", 
			_years, _months, _days, _hours, _minutes, _seconds, _microseconds];
}

@end
