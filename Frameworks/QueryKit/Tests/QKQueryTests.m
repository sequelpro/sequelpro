//
//  $Id$
//
//  QKQueryTests.m
//  QueryKit
//
//  Created by Stuart Connolly (stuconnolly.com) on July 9, 2012
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

#import "QKTestConstants.h"
#import "QKTestCase.h"

#import <QueryKit/QueryKit.h>
#import <SenTestingKit/SenTestingKit.h>

@interface QKQueryTests : QKTestCase
@end

@implementation QKQueryTests

#pragma mark -
#pragma mark Setup

- (void)setUp
{
	QKQuery *query = [QKQuery selectQueryFromTable:QKTestTableName];
	
	[query setUseQuotedIdentifiers:NO];
	[query setQueryDatabase:QKDatabaseMySQL];
	
	[query setDatabase:QKTestDatabaseName];
	
	[query addField:QKTestFieldOne];
	[query addField:QKTestFieldTwo];
	[query addField:QKTestFieldThree];
	[query addField:QKTestFieldFour];
	
	[query addParameter:QKTestFieldOne operator:QKEqualityOperator value:[NSNumber numberWithUnsignedInteger:QKTestParameterOne]];
	
	[query orderByField:QKTestFieldOne descending:NO];
	
	[self setQuery:query];
}

#pragma mark -
#pragma mark Tests

- (void)testCallingClearOnAQueryCorretlyResetsItToItsDefaultState
{
	[[self query] clear];
	
	STAssertNil([[self query] table], @"query table");
	STAssertNil([[self query] database], @"query database");
	
	STAssertTrue([[self query] useQuotedIdentifiers], @"query use quoted identifiers");
	STAssertTrue([[[self query] identifierQuote] isEqualToString:EMPTY_STRING], @"query identifier quote");
	STAssertTrue([[[self query] fields] count] == 0, @"query fields");
	STAssertTrue([[[self query] parameters] count] == 0, @"query parameters");
	STAssertTrue([[[self query] updateParameters] count] == 0, @"query update parameters");
	STAssertTrue([[[self query] groupByFields] count] == 0, @"query group by fields");
	STAssertTrue([[[self query] orderByFields] count] == 0, @"query order by fields");
	
	STAssertEquals([[self query] queryType], QKUnknownQuery, @"query type");
	STAssertEquals([[self query] queryDatabase], QKDatabaseUnknown, @"query database");
}

@end
