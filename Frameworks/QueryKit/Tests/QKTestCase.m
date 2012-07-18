//
//  $Id$
//
//  QKTestCase.m
//  QueryKit
//
//  Created by Stuart Connolly (stuconnolly.com) on July 18, 2012
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

#import "QKTestCase.h"

@implementation QKTestCase

@synthesize query = _query;
@synthesize identifierQuote = _identifierQuote;
@synthesize database = _database;

- (id)initWithInvocation:(NSInvocation *)invocation database:(QKQueryDatabase)database identifierQuote:(NSString *)quote
{
    if ((self = [super initWithInvocation:invocation])) {
		[self setDatabase:database];
		[self setIdentifierQuote:quote];
    }
	
    return self;
}

- (void)dealloc
{
	if (_query) [_query release], _query = nil;
	if (_identifierQuote) [_identifierQuote release], _identifierQuote = nil;
}

@end
