//
//  SPTableCopyTest.h
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

#import "SPTableCopy.h"
#import <SPMySQL/SPMySQL.h>

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#define USE_APPLICATION_UNIT_TEST 1

@interface SPTableCopyTest : XCTestCase

- (void)testCopyTableFromToWithData;
- (void)testCopyTableFromTo_NoPermissions;

@end

@implementation SPTableCopyTest

- (void)testCopyTableFromToWithData 
{
	id mockResult = OCMClassMock([SPMySQLResult class]);
	
	NSArray *resultArray = [[NSArray alloc] initWithObjects:@"", @"CREATE TABLE `table_name` ()", nil];
	
	id mockConnection = OCMClassMock([SPMySQLConnection class]);
	
	OCMExpect([mockResult numberOfRows]).andReturn(1);
	OCMExpect([mockResult getRowAsArray]).andReturn(resultArray);
	
	OCMExpect([mockConnection queryString:@"SHOW CREATE TABLE `source_db`.`table_name`"]).andReturn(mockResult);
	OCMExpect([mockConnection queryString:@"CREATE TABLE `target_db`.`table_name` ()"]);
	OCMExpect([mockConnection queryString:@"INSERT INTO `target_db`.`table_name` SELECT * FROM `source_db`.`table_name`"]);
	OCMStub([mockConnection queryErrored]).andReturn(NO);

	{
		SPTableCopy *tableCopy = [[SPTableCopy alloc] init];
		
		[tableCopy setConnection:mockConnection];
		[tableCopy copyTable:@"table_name" from:@"source_db" to:@"target_db" withContent:YES];
		
		[tableCopy release];
	}
	
	OCMVerifyAll(mockResult);
	OCMVerifyAll(mockConnection);
	
	[resultArray release];
}

- (void)testCopyTableFromTo_NoPermissions
{
	id mockConnection = OCMStrictClassMock([SPMySQLConnection class]);
	
	OCMExpect([mockConnection queryString:@"SHOW CREATE TABLE `source_db`.`table_name`"]).andReturn(nil);
	OCMStub([mockConnection queryErrored]).andReturn(YES);
	OCMStub([mockConnection lastErrorMessage]).andReturn(@"SHOW command denied to user 'alice'@'localhost' for table 'table_name'");
	OCMStub([mockConnection lastErrorID]).andReturn(1142);
	OCMStub([mockConnection lastSqlstate]).andReturn(@"42000");
	
	{
		SPTableCopy *tableCopy = [[SPTableCopy alloc] init];
		[tableCopy setConnection:mockConnection];
		
		XCTAssertFalse([tableCopy copyTable:@"table_name" from:@"source_db" to:@"target_db"], @"copy operation must fail.");
		
		[tableCopy release];
	}
	
	[mockConnection verify];
}

@end
