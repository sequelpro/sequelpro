//
//  SPTableCopyTest.m
//  sequel-pro
//
//  Created by David Rekowski on 22.04.10.
//  Copyright 2010 Papaya Software GmbH. All rights reserved.
//

#import <OCMock/OCMock.h>
#import "SPTableCopy.h"
#import "SPTableCopyTest.h"


@implementation SPTableCopyTest

- (SPTableCopy *)getTableCopyFixture {
    SPTableCopy *tableCopy = [[SPTableCopy alloc] init];
	return tableCopy;
}

- (id) getMockConnection {
	id mockConnection = [OCMockObject niceMockForClass:[MCPConnection class]];
	return mockConnection;
}

- (void)testCopyTableFromTo {
	id tableCopy = [self getTableCopyFixture];
	id mockConnection = [self getMockConnection];
	[[mockConnection expect] queryString:@"CREATE TABLE `target_db`.`table_name` LIKE `source_db`.`table_name`"];
	[tableCopy setConnection:mockConnection];
	[tableCopy copyTable: @"table_name" from: @"source_db" to: @"target_db"];
	[mockConnection verify];
}

- (void)testCopyTableFromToWithData {
	id tableCopy = [self getTableCopyFixture];
	id mockConnection = [self getMockConnection];
	[[mockConnection expect] queryString:@"CREATE TABLE `target_db`.`table_name` LIKE `source_db`.`table_name`"];
	[[mockConnection expect] queryString:@"INSERT INTO `target_db`.`table_name` SELECT * FROM `source_db`.`table_name`"];
	[tableCopy setConnection:mockConnection];
	[tableCopy copyTable: @"table_name" from: @"source_db" to: @"target_db" withContent: YES];
	[mockConnection verify];
}

@end
