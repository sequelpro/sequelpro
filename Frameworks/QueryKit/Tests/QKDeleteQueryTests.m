//
//  QKDeleteQueryTests.m
//  QueryKit
//
//  Created by Stuart Connolly (stuconnolly.com) on July 21, 2012
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

#import "QKDeleteQueryTests.h"
#import "QKTestConstants.h"

@implementation QKDeleteQueryTests

#pragma mark -
#pragma mark Initialisation

+ (id)defaultTestSuite
{
    XCTestSuite *testSuite = [[XCTestSuite alloc] initWithName:NSStringFromClass(self)];
	
	[self addTestForDatabase:QKDatabaseUnknown withIdentifierQuote:EMPTY_STRING toTestSuite:testSuite];
	[self addTestForDatabase:QKDatabaseMySQL withIdentifierQuote:QKMySQLIdentifierQuote toTestSuite:testSuite];
	[self addTestForDatabase:QKDatabasePostgreSQL withIdentifierQuote:QKPostgreSQLIdentifierQuote toTestSuite:testSuite];
	
    return [testSuite autorelease];
}

+ (void)addTestForDatabase:(QKQueryDatabase)database withIdentifierQuote:(NSString *)quote toTestSuite:(XCTestSuite *)testSuite
{		
    for (NSInvocation *invocation in [self testInvocations]) 
	{
		XCTestCase *test = [[QKDeleteQueryTests alloc] initWithInvocation:invocation database:database identifierQuote:quote];
		
		[testSuite addTest:test];
		
        [test release];
    }
}

#pragma mark -
#pragma mark Setup

- (void)setUp
{
	QKQuery *query = [QKQuery queryTable:QKTestTableName];
	
	[query setQueryType:QKDeleteQuery];
	
	[query setQueryDatabase:[self database]];
	[query setUseQuotedIdentifiers:[self identifierQuote] && [[self identifierQuote] length] > 0];
	
	[self setQuery:query];
}

#pragma mark -
#pragma mark Tests

- (void)testDeleteQueryTypeIsCorrect
{
	XCTAssertTrue([[[self query] query] hasPrefix:@"DELETE"]);
}

- (void)testDeleteQueryFromTableIsCorrect
{
	NSString *query = [NSString stringWithFormat:@"DELETE FROM %1$@%2$@%1$@", [self identifierQuote], QKTestTableName];
	
	XCTAssertTrue([[[self query] query] isEqualToString:query]);
}

- (void)testDeleteQueryFromDatabaseTableIsCorrect
{
	[[self query] setDatabase:QKTestDatabaseName];
	
	NSString *query = [NSString stringWithFormat:@"DELETE FROM %1$@%2$@%1$@.%1$@%3$@%1$@", [self identifierQuote], QKTestDatabaseName, QKTestTableName];
	
	XCTAssertTrue([[[self query] query] isEqualToString:query] );
}

- (void)testDeleteQueryWithSingleConstraintIsCorrect
{	
	[[self query] addParameter:QKTestFieldOne operator:QKEqualityOperator value:[NSNumber numberWithUnsignedInteger:QKTestParameterOne]];
	
	NSString *query = [NSString stringWithFormat:@"DELETE FROM %1$@%2$@%1$@ WHERE %1$@%3$@%1$@ %4$@ %5$@", [self identifierQuote], QKTestTableName, QKTestFieldOne, [QKQueryUtilities stringRepresentationOfQueryOperator:QKEqualityOperator], [NSNumber numberWithUnsignedInteger:QKTestParameterOne]];
	
	XCTAssertTrue([[[self query] query] isEqualToString:query] );
}

- (void)testDeleteQueryWithMultipleConstraintsIsCorrect
{	
	[[self query] addParameter:QKTestFieldOne operator:QKEqualityOperator value:[NSNumber numberWithUnsignedInteger:QKTestParameterOne]];
	[[self query] addParameter:QKTestFieldTwo operator:QKNotEqualOperator value:QKTestParameterTwo];
	
	NSString *opOne = [QKQueryUtilities stringRepresentationOfQueryOperator:QKEqualityOperator];
	NSString *opTwo = [QKQueryUtilities stringRepresentationOfQueryOperator:QKNotEqualOperator];
	
	NSString *query = [NSString stringWithFormat:@"DELETE FROM %1$@%2$@%1$@ WHERE %1$@%3$@%1$@ %4$@ %5$@ AND %1$@%6$@%1$@ %7$@ '%8$@'", [self identifierQuote], QKTestTableName, QKTestFieldOne, opOne, [NSNumber numberWithUnsignedInteger:QKTestParameterOne], QKTestFieldTwo, opTwo, QKTestParameterTwo];
	
	XCTAssertTrue([[[self query] query] isEqualToString:query] );
}

@end
