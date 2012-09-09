//
//  $Id$
//
//  FLXTimeInterval.h
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

/**
 * @class FLXTimeInterval FLXTimeInterval.h
 *
 * @author Stuart Connolly http://stuconnolly.com
 *
 * Simple wrapper around libpqtypes' PQinterval structure.
 */
@interface FLXTimeInterval : NSObject 
{
	NSUInteger _microseconds;
	NSUInteger _seconds;
	NSUInteger _minutes;
	NSUInteger _hours;
	NSUInteger _days;
	NSUInteger _months;
	NSUInteger _years;
}

/**
 * @property microseconds The number of microseconds.
 */
@property (readonly) NSUInteger microseconds;

/**
 * @property seconds The number of seconds.
 */
@property (readonly) NSUInteger seconds;

/**
 * @property minutes The number of minutes.
 */
@property (readonly) NSUInteger minutes;

/**
 * @property hours The number of hours.
 */
@property (readonly) NSUInteger hours;

/**
 * @property days The number of days.
 */
@property (readonly) NSUInteger days;

/**
 * @property months The number of months.
 */
@property (readonly) NSUInteger months;

/**
 * @property years The number of years.
 */
@property (readonly) NSUInteger years;


@end
