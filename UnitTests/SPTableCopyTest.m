//
//  $Id$
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
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPTableCopy.h"
#import "SPTableCopyTest.h"

#import <OCMock/OCMock.h>
#import <SPMySQL/SPMySQL.h>

@implementation SPTableCopyTest

- (id)mockConnection 
{
	return [[OCMockObject niceMockForClass:[SPMySQLConnection class]] autorelease];
}

- (id)mockResult 
{
	return [[OCMockObject niceMockForClass:[SPMySQLResult class]] autorelease];
}

- (void)testCopyTableFromToWithData 
{
	id mockResult = [self mockResult];
	
	unsigned long long varOne = 1;
	NSValue *valueOne = [NSValue value:&varOne withObjCType:@encode(__typeof__(varOne))];
	BOOL varNo = NO;
	
	NSValue *valueNo = [NSValue value:&varNo withObjCType:@encode(BOOL)];
	NSArray *resultArray = [[NSArray alloc] initWithObjects:@"", @"CREATE TABLE `table_name` ()", nil];
	
	id mockConnection = [self mockConnection];
	
	[(SPMySQLResult *)[[mockResult expect] andReturn:valueOne] numberOfRows];
	[[[mockResult expect] andReturn:resultArray] getRowAsArray];
	
	[[[mockConnection expect] andReturn:mockResult] queryString:@"SHOW CREATE TABLE `source_db`.`table_name`"];
	[[mockConnection expect] queryString:@"CREATE TABLE `target_db`.`table_name` ()"];
	[[mockConnection expect] queryString:@"INSERT INTO `target_db`.`table_name` SELECT * FROM `source_db`.`table_name`"];
	[[[mockConnection stub] andReturnValue:valueNo] queryErrored];

	SPTableCopy *tableCopy = [[SPTableCopy alloc] init];
	
	[tableCopy setConnection:mockConnection];
	[tableCopy copyTable:@"table_name" from:@"source_db" to:@"target_db" withContent:YES];
	
	[mockResult verify];
	[mockConnection verify];
	
	[tableCopy release];
	[resultArray release];
}

@end
