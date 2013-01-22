//
//  $Id$
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

static NSString *PGTestDatabaseHost     = @"localhost";
static NSString *PGTestDatabaseUser     = @"pgkit_test";
static NSString *PGTestDatabaseName     = @"pgkit_test";
static NSString *PGTestDatabasePassword = @"pgkit";

static NSUInteger PGTestDatabasePort = 5432;

@interface PGDataTypeTests ()

- (void)_establishConnection;

+ (void)_addTestForField:(NSString *)field 
	  withExpectedResult:(id)result 
			  connection:(PGPostgresConnection *)connection 
			 toTestSuite:(SenTestSuite *)testSuite;

@end

@implementation PGDataTypeTests

@synthesize field = _field;
@synthesize result = _result;
@synthesize connection = _connection;
@synthesize expectedResult = _expectedResult;

#pragma mark -
#pragma mark Initialisation

+ (id)defaultTestSuite
{
    SenTestSuite *testSuite = [[SenTestSuite alloc] initWithName:[self className]];
	
	PGPostgresConnection *connection = [[PGPostgresConnection alloc] init];
	
	[self _addTestForField:@"int" withExpectedResult:[NSNumber numberWithInt:12345] connection:connection toTestSuite:testSuite];
	[self _addTestForField:@"smallint" withExpectedResult:[NSNumber numberWithInt:2] connection:connection toTestSuite:testSuite];
	[self _addTestForField:@"bigint" withExpectedResult:[NSNumber numberWithInt:123456789] connection:connection toTestSuite:testSuite];
	[self _addTestForField:@"bool" withExpectedResult:[NSNumber numberWithInteger:1] connection:connection toTestSuite:testSuite];
	[self _addTestForField:@"float" withExpectedResult:[NSNumber numberWithFloat:12345.678] connection:connection toTestSuite:testSuite];
	[self _addTestForField:@"numeric" withExpectedResult:[NSNumber numberWithDouble:12345.678] connection:connection toTestSuite:testSuite];
	[self _addTestForField:@"char" withExpectedResult:@"CHAR" connection:connection toTestSuite:testSuite];
	[self _addTestForField:@"varchar" withExpectedResult:@"VARCHAR" connection:connection toTestSuite:testSuite];
	//[self _addTestForField:@"date" withExpectedResult: connection:connection toTestSuite:testSuite];
	//[self _addTestForField:@"time" withExpectedResult: connection:connection toTestSuite:testSuite];
	//[self _addTestForField:@"timetz" withExpectedResult: connection:connection toTestSuite:testSuite];
	//[self _addTestForField:@"timestamp" withExpectedResult: connection:connection toTestSuite:testSuite];
	//[self _addTestForField:@"timestamptz" withExpectedResult: connection:connection toTestSuite:testSuite];
	
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
	[self _establishConnection];
	
	PGPostgresResult *queryResult = [_connection executeWithFormat:@"SELECT \"%@_field\" FROM \"data_types\"", _field];
	
	[self setResult:[[queryResult row] objectForKey:[NSString stringWithFormat:@"%@_field", _field]]];
}

#pragma mark -
#pragma mark Tests

- (void)testResultValueIsNotNull
{
	STAssertNotNil(_result, @"");
}

- (void)testResultIsOfCorrectType
{	
	STAssertTrue([_result isKindOfClass:[_expectedResult class]], @"Expected _result to be of type %@, but is actually %@", [_expectedResult className], [_result className]);
}

- (void)testResultHasCorrectValue
{	
	STAssertEqualObjects(_result, _expectedResult, @"");
}

#pragma mark -r
#pragma mark Private API

- (void)_establishConnection
{		
	[_connection setHost:PGTestDatabaseHost];
	[_connection setUser:PGTestDatabaseUser];
	[_connection setPort:PGTestDatabasePort];
	[_connection setDatabase:PGTestDatabaseName];
	[_connection setPassword:PGTestDatabasePassword];
	
	if (![_connection connect]) {
		STFail(@"Request to establish connection to local database failed.");
	}	
		
	do {
		sleep(0.1);
	}
	while (![_connection isConnected]);
}

+ (void)_addTestForField:(NSString *)field 
	  withExpectedResult:(id)result 
			  connection:(PGPostgresConnection *)connection 
			 toTestSuite:(SenTestSuite *)testSuite
{		
    for (NSInvocation *invocation in [self testInvocations]) 
	{
		SenTestCase *test = [[[self class] alloc] initWithInvocation:invocation connection:connection expectedResult:result field:field];
		
		[testSuite addTest:test];
		
        [test release];
    }
}

#pragma mark -

- (void)dealloc
{
	if (_connection && [_connection isConnected]) {
		[_connection disconnect];
	}
	
	if (_result) [_result release], _result = nil;
	if (_field) [_field release], _field = nil;
	if (_connection) [_connection release], _connection = nil;
	
	[super dealloc];
}

@end
