//
//  PGDataTypeTests.m
//  PostgresKit
//
//  Created by Stuart Connolly (stuconnolly.com) on September 26, 2012.
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

#import "PGDataTypeTests.h"

@interface PGDataTypeTests ()

+ (void)_addTestForField:(NSString *)field 
	  withExpectedResult:(id)result 
			  connection:(PGPostgresConnection *)connection 
			 toTestSuite:(XCTestSuite *)testSuite;

@end

@implementation PGDataTypeTests

@synthesize field = _field;
@synthesize result = _result;
@synthesize expectedResult = _expectedResult;

#pragma mark -
#pragma mark Initialisation

+ (id)defaultTestSuite
{
    XCTestSuite *testSuite = [[XCTestSuite alloc] initWithName:[self className]];
	
	PGPostgresConnection *connection = [[PGPostgresConnection alloc] init];
	
	[self _addTestForField:@"int" withExpectedResult:[NSNumber numberWithInt:12345] connection:connection toTestSuite:testSuite];
	[self _addTestForField:@"smallint" withExpectedResult:[NSNumber numberWithInt:2] connection:connection toTestSuite:testSuite];
	[self _addTestForField:@"bigint" withExpectedResult:[NSNumber numberWithInt:123456789] connection:connection toTestSuite:testSuite];
	[self _addTestForField:@"bool" withExpectedResult:[NSNumber numberWithInteger:1] connection:connection toTestSuite:testSuite];
	[self _addTestForField:@"float" withExpectedResult:[NSNumber numberWithFloat:12345.678] connection:connection toTestSuite:testSuite];
	[self _addTestForField:@"numeric" withExpectedResult:[NSNumber numberWithDouble:12345.678] connection:connection toTestSuite:testSuite];
	[self _addTestForField:@"char" withExpectedResult:@"CHAR" connection:connection toTestSuite:testSuite];
	[self _addTestForField:@"varchar" withExpectedResult:@"VARCHAR" connection:connection toTestSuite:testSuite];
	[self _addTestForField:@"date" withExpectedResult:[NSDate dateWithTimeIntervalSince1970:544834800] connection:connection toTestSuite:testSuite];
	[self _addTestForField:@"time" withExpectedResult:[NSDate dateWithTimeIntervalSince1970:946692122] connection:connection toTestSuite:testSuite];
	[self _addTestForField:@"timestamp" withExpectedResult:[NSDate dateWithTimeIntervalSince1970:544845722] connection:connection toTestSuite:testSuite];
	
	PGPostgresTimeTZ *timeTz = [PGPostgresTimeTZ timeWithDate:[NSDate dateWithTimeIntervalSince1970:946692122] timeZoneGMTOffset:36000];
	PGPostgresTimeTZ *timestampTz = [PGPostgresTimeTZ timeWithDate:[NSDate dateWithTimeIntervalSince1970:544845722] timeZoneGMTOffset:3600];
	
	[timeTz setHasDate:YES];
	[timestampTz setHasDate:YES];
	
	[self _addTestForField:@"timetz" withExpectedResult:timeTz connection:connection toTestSuite:testSuite];
	[self _addTestForField:@"timestamptz" withExpectedResult:timestampTz connection:connection toTestSuite:testSuite];
	
	[connection release];
	
    return [testSuite autorelease];
}

- (id)initWithInvocation:(NSInvocation *)invocation 
			  connection:(PGPostgresConnection *)connection 
		  expectedResult:(id)result 
				   field:(NSString *)field
{
	if ((self = [super initWithInvocation:invocation])) {
		[self setConnection:connection];
		[self setExpectedResult:result];
		[self setField:field];
    }
	
    return self;
}

#pragma mark -
#pragma mark Setup & Teardown

- (void)setUp
{	
	[super setUp];
	
	PGPostgresResult *queryResult = [[self connection] executeWithFormat:@"SELECT \"%@_field\" FROM \"data_types\"", _field];
	
	[self setResult:[[queryResult row] objectForKey:[NSString stringWithFormat:@"%@_field", _field]]];
}

#pragma mark -
#pragma mark Tests

- (void)testResultValueIsNotNil
{
	XCTAssertNotNil(_result);
}

- (void)testResultIsOfCorrectTypeAndValue
{		
	XCTAssertEqualObjects(_result, _expectedResult);
}

#pragma mark -
#pragma mark Private API

+ (void)_addTestForField:(NSString *)field 
	  withExpectedResult:(id)result 
			  connection:(PGPostgresConnection *)connection 
			 toTestSuite:(XCTestSuite *)testSuite
{		
    for (NSInvocation *invocation in [self testInvocations]) 
	{
		XCTestCase *test = [[[self class] alloc] initWithInvocation:invocation connection:connection expectedResult:result field:field];
		
		[testSuite addTest:test];
		
        [test release];
    }
}

#pragma mark -

- (void)dealloc
{	
	if (_result) [_result release], _result = nil;
	if (_field) [_field release], _field = nil;
	
	[super dealloc];
}

@end
