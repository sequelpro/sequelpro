//
//  $Id$
//
//  SPTableCopyTest.m
//  sequel-pro
//
//  Created by David Rekowski
//  Copyright (c) 2010 David Rekowski. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import <OCMock/OCMock.h>
#import "SPTableCopy.h"
#import "SPTableCopyTest.h"


@implementation SPTableCopyTest

- (id) getMockConnection {
	id mockConnection = [OCMockObject niceMockForClass:[MCPConnection class]];
	return [mockConnection autorelease];
}

- (id) getMockResult {
	id mockResult = [OCMockObject niceMockForClass:[MCPResult class]];
	return mockResult;
}

- (SPTableCopy *) getTableCopyFixture {
    SPTableCopy *tableCopy = [[SPTableCopy alloc] init];
	return [tableCopy autorelease];
}

- (void)testCopyTableFromToWithData {
	id mockResult = [self getMockResult];
	unsigned long long varOne = 1;
	NSValue *valueOne = [NSValue value:&varOne withObjCType:@encode(__typeof__(varOne))];
	BOOL varNo = NO;
	NSValue *valueNo = [NSValue value:&varNo withObjCType:@encode(BOOL)];
	NSArray *resultArray = [[NSArray alloc] initWithObjects:@"", @"CREATE TABLE `table_name` ()", nil];
	[[[mockResult expect] andReturnValue:valueOne] numOfRows];
	[[[mockResult expect] andReturn:resultArray] fetchRowAsArray];
	
	id mockConnection = [self getMockConnection];
	[[[mockConnection expect] andReturn:mockResult] queryString:@"SHOW CREATE TABLE `source_db`.`table_name`"];
	[[mockConnection expect] queryString:@"CREATE TABLE `target_db`.`table_name` ()"];
	[[mockConnection expect] queryString:@"INSERT INTO `target_db`.`table_name` SELECT * FROM `source_db`.`table_name`"];
	[[[mockConnection stub] andReturnValue:valueNo] queryErrored];

	id tableCopy = [self getTableCopyFixture];
	[tableCopy setConnection:mockConnection];
	[tableCopy copyTable: @"table_name" from: @"source_db" to: @"target_db" withContent: YES];
	[mockResult verify];
	[mockConnection verify];
	[resultArray release];
}

@end
