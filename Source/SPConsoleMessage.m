//
//  $Id$
//
//  SPConsoleMessage.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Mar 12, 2009.
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPConsoleMessage.h"

@implementation SPConsoleMessage

@synthesize isError;
@synthesize messageDate;
@synthesize message;
@synthesize messageConnection;

/**
 * Returns a new console message instance using the suppled message, date and connection.
 */
+ (SPConsoleMessage *)consoleMessageWithMessage:(NSString *)message date:(NSDate *)date connection:(NSString *)connection
{
	return [[[SPConsoleMessage alloc] initWithMessage:message date:date connection:connection] autorelease];
}

/**
 * Initializes a new console message instance using the suppled message, date and connection.
 */
- (id)initWithMessage:(NSString *)consoleMessage date:(NSDate *)date connection:(NSString *)connection
{
	if ((self = [super init])) {
		[self setMessageDate:date];
		[self setMessage:consoleMessage];
		[self setMessageConnection:connection];
	}
	
	return self;
}

#pragma mark -

- (void)dealloc
{
	[message release], message = nil;
	[messageDate release], messageDate = nil;
	[messageConnection release], messageConnection = nil;
	
	[super dealloc];
}

@end
