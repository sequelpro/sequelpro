//
//  $Id$
//
//  QKUpdateQueryTests.m
//  QueryKit
//
//  Created by Stuart Connolly (stuconnolly.com) on March 25, 2012
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

#import <QueryKit/QueryKit.h>
#import <SenTestingKit/SenTestingKit.h>

@interface QKUpdateQueryTests : SenTestCase
{
	QKQuery *_query;
}

@end

@implementation QKUpdateQueryTests

#pragma mark -
#pragma mark Setup

- (void)setUp
{
	_query = [QKQuery queryTable:QKTestTableName];
	
	[_query setQueryType:QKUpdateQuery];
	
	[_query addFieldToUpdate:QKTestFieldOne toValue:QKTestUpdateValueOne];
	[_query addFieldToUpdate:QKTestFieldTwo toValue:QKTestUpdateValueTwo];
	
	[_query addParameter:QKTestFieldOne operator:QKEqualityOperator value:[NSNumber numberWithUnsignedInteger:QKTestParameterOne]];
}

#pragma mark -
#pragma mark Tests

- (void)testUpdateQueryTypeIsCorrect
{
	STAssertTrue([[_query query] hasPrefix:@"UPDATE"], @"update query type");
}

- (void)testUpdateQueryFieldsAreCorrect
{
	NSString *query = [NSString stringWithFormat:@"UPDATE `%@` SET `%@` = '%@', `%@` = '%@'", QKTestTableName, QKTestFieldOne, QKTestUpdateValueOne, QKTestFieldTwo, QKTestUpdateValueTwo];
	
	STAssertTrue([[_query query] hasPrefix:query], @"update query fields");
}

- (void)testUpdateQueryFieldsWithoutQuotesAreCorrect
{
	[_query setUseQuotedIdentifiers:NO];
	
	NSString *query = [NSString stringWithFormat:@"UPDATE %@ SET %@ = '%@', %@ = '%@'", QKTestTableName, QKTestFieldOne, QKTestUpdateValueOne, QKTestFieldTwo, QKTestUpdateValueTwo];
			
	STAssertTrue([[_query query] hasPrefix:query], @"update query fields without quotes");
}

- (void)testUpdateQueryConstraintIsCorrect
{
	NSString *query = [NSString stringWithFormat:@"WHERE `%@` %@ %@", QKTestFieldOne, [QKQueryUtilities stringRepresentationOfQueryOperator:QKEqualityOperator], [NSNumber numberWithUnsignedInteger:QKTestParameterOne]];
		
	STAssertTrue(([[_query query] rangeOfString:query].location != NSNotFound), @"update query constraint");
}

- (void)testUpdateQueryConstraintWithoutQuotesIsCorrect
{
	[_query setUseQuotedIdentifiers:NO];
	
	NSString *query = [NSString stringWithFormat:@"WHERE %@ %@ %@", QKTestFieldOne, [QKQueryUtilities stringRepresentationOfQueryOperator:QKEqualityOperator], [NSNumber numberWithUnsignedInteger:QKTestParameterOne]];
	
	STAssertTrue(([[_query query] rangeOfString:query].location != NSNotFound), @"update query constraint without quotes");
}

@end
