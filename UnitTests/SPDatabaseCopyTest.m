//
//  SPDatabaseCopyTest.m
//  sequel-pro
//
//  Created by David Rekowski.
//  Copyright (c) 2010 David Rekowski. All rights reserved.
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
//  More info at <https://github.com/sequelpro/sequelpro>

#define USE_APPLICATION_UNIT_TEST 1

#import <OCMock/OCMock.h>
#import <SenTestingKit/SenTestingKit.h>

#import "SPAlertSheets.h"
#import "SPDatabaseCopy.h"
#import "SPTableCopy.h"
#import "SPLogger.h"

@interface SPDatabaseCopyTest : SenTestCase

- (void)testCopyDatabase;
- (void)testCreateDatabase;

@end

@implementation SPDatabaseCopyTest

- (SPDatabaseCopy *)getDatabaseCopyFixture 
{
    return [[[SPDatabaseCopy alloc] init] autorelease];
}

- (SPTableCopy *)getTableCopyFixture 
{
    return [[[SPTableCopy alloc] init] autorelease];
}

- (id)getMockConnection 
{
	return [OCMockObject niceMockForClass:[SPMySQLConnection class]];
}

- (void)testCopyDatabase 
{
	SPDatabaseCopy *dbCopy = [self getDatabaseCopyFixture];
	id mockConnection = [self getMockConnection];
	[[mockConnection expect] queryString:@"CREATE DATABASE `target_name`"];
	[[mockConnection expect] listTablesFromDB:@"source_name"];
	[[[mockConnection stub] andReturn:[[NSArray alloc] init]] listTablesFromDB:@"source_name"];
	[dbCopy setConnection:mockConnection];
	
	id mockDBInfo = [self getMockDBInfo];

	BOOL varNo = NO;
	BOOL varYes = YES;
	[[[mockDBInfo expect] andReturnValue:[NSValue value:&varYes withObjCType:@encode(BOOL)]] databaseExists:@"source_name"];

	[[[mockDBInfo expect] andReturnValue:[NSValue value:&varNo withObjCType:@encode(BOOL)]] databaseExists:@"target_name"];

	[dbCopy setDbInfo:mockDBInfo];
	
	NSString *source = [[NSString alloc] initWithString:@"source_name"];
	NSString *target = [[NSString alloc] initWithString:@"target_name"];
	STAssertTrue([dbCopy copyDatabaseFrom:source to:target withContent:YES], @"method renameDatabaseFrom:to: is supposed to return YES");
	
	[mockConnection verify];
	[source release];
	[target release];
}

- (void)testCreateDatabase 
{
	[self getDatabaseCopyFixture];
}

@end
