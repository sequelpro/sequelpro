//
//  $Id$
//
//  QKSelectQueryOrderByTests.m
//  QueryKit
//
//  Created by Stuart Connolly (stuconnolly.com) on February 25, 2012
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

#import "QKSelectQueryOrderByTests.h"
#import "QKTestConstants.h"

@implementation QKSelectQueryOrderByTests

#pragma mark -
#pragma mark Setup

- (void)setUp
{
	_query = [QKQuery selectQueryFromTable:QKTestTableName];
	
	[_query addField:QKTestFieldOne];
	[_query addField:QKTestFieldTwo];
}

#pragma mark -
#pragma mark Tests

- (void)testSelectQueryTypeIsCorrect
{
	STAssertTrue([[_query query] hasPrefix:@"SELECT"], @"select query type");
}

- (void)testSelectQueryOrderByAscendingIsCorrect
{	
	[_query orderByField:QKTestFieldOne descending:NO];
	
	NSString *query = [NSString stringWithFormat:@"ORDER BY `%@` ASC", QKTestFieldOne];
	
	STAssertTrue([[_query query] hasSuffix:query], @"select query order by");
}

- (void)testSelectQueryOrderByAscendingWithoutQuotesIsCorrect
{	
	[_query setUseQuotes:NO];
	[_query orderByField:QKTestFieldOne descending:NO];
	
	NSString *query = [NSString stringWithFormat:@"ORDER BY %@ ASC", QKTestFieldOne];
	
	STAssertTrue([[_query query] hasSuffix:query], @"select query order by without quotes");
}

- (void)testSelectQueryOrderByMultipleFieldsAscendingIsCorrect
{	
	[_query orderByFields:[NSArray arrayWithObjects:QKTestFieldOne, QKTestFieldTwo, nil] descending:NO];
	
	NSString *query = [NSString stringWithFormat:@"ORDER BY `%@`, `%@` ASC", QKTestFieldOne, QKTestFieldTwo];
	
	STAssertTrue([[_query query] hasSuffix:query], @"select query order by multiple fields ascending when quoted");
}

- (void)testSelectQueryOrderByMultipleFieldsAscendingWithoutQuotesIsCorrect
{	
	[_query setUseQuotes:NO];
	[_query orderByFields:[NSArray arrayWithObjects:QKTestFieldOne, QKTestFieldTwo, nil] descending:NO];
	
	NSString *query = [NSString stringWithFormat:@"ORDER BY %@, %@ ASC", QKTestFieldOne, QKTestFieldTwo];
	
	STAssertTrue([[_query query] hasSuffix:query], @"select query order by multiple fields ascending without quotes");
}

- (void)testSelectQueryOrderByDescendingIsCorrect
{	
	[_query orderByField:QKTestFieldOne descending:YES];
	
	NSString *query = [NSString stringWithFormat:@"ORDER BY `%@` DESC", QKTestFieldOne];
	
	STAssertTrue([[_query query] hasSuffix:query], @"select query order by descending");
}

- (void)testSelectQueryOrderByDescendingWithoutQuotesIsCorrect
{	
	[_query setUseQuotes:NO];
	[_query orderByField:QKTestFieldOne descending:YES];
	
	NSString *query = [NSString stringWithFormat:@"ORDER BY %@ DESC", QKTestFieldOne];
		
	STAssertTrue([[_query query] hasSuffix:query], @"select query order by descending without quotes");
}

- (void)testSelectQueryOrderByMultipleFieldsDescendingIsCorrect
{	
	[_query orderByFields:[NSArray arrayWithObjects:QKTestFieldOne, QKTestFieldTwo, nil] descending:YES];
	
	NSString *query = [NSString stringWithFormat:@"ORDER BY `%@`, `%@` DESC", QKTestFieldOne, QKTestFieldTwo];
	
	STAssertTrue([[_query query] hasSuffix:query], @"select query order by multiple fields descending");
}

- (void)testSelectQueryOrderByMultipleFieldsDescendingWithoutQuotesIsCorrect
{	
	[_query setUseQuotes:NO];
	[_query orderByFields:[NSArray arrayWithObjects:QKTestFieldOne, QKTestFieldTwo, nil] descending:YES];
	
	NSString *query = [NSString stringWithFormat:@"ORDER BY %@, %@ DESC", QKTestFieldOne, QKTestFieldTwo];
	
	STAssertTrue([[_query query] hasSuffix:query], @"select query order by multiple fields descending without quotes");
}

@end
