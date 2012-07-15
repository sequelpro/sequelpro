//
//  $Id$
//
//  QKQueryOrderBy.m
//  QueryKit
//
//  Created by Stuart Connolly (stuconnolly.com) on July 15, 2012
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

#import "QKQueryOrderBy.h"

@implementation QKQueryOrderBy

@synthesize _orderByField;
@synthesize _orderByDescending;

#pragma mark -
#pragma mark Initialisation

+ (QKQueryOrderBy *)orderByField:(NSString *)field descending:(BOOL)descending
{
	return [[[QKQueryOrderBy alloc] initWithField:field descending:descending] autorelease];
}

- (id)init
{
	return [self initWithField:nil descending:NO];
}

- (id)initWithField:(NSString *)field descending:(BOOL)descending
{
	if ((self = [super init])) {
		[self setOrderByField:field];
		[self setOrderByDescending:descending];
	}
	
	return self;
}

#pragma mark -

- (NSString *)description
{	
	if (!_orderByField || [_orderByField length] == 0) return EMPTY_STRING;
	
	NSString *field = [_orderByField stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
	return [NSString stringWithFormat:@"%1$@%2$@%1$@ %3$@", [self useQuotedIdentifier] ? _identiferQuote : EMPTY_STRING, field, _orderByDescending ? @"DESC" : @"ASC"];
}

#pragma mark -

- (void)dealloc
{
	if (_orderByField) [_orderByField release], _orderByField = nil;
	
	[super dealloc];
}

@end
