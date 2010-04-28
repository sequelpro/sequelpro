//
//  SPDatabaseInfoTest.m
//  sequel-pro
//
//  Created by David Rekowski on 22.04.10.
//  Copyright 2010 Papaya Software GmbH. All rights reserved.
//

#import <OCMock/OCMock.h>
#import "SPDatabaseInfo.h"
#import "SPDatabaseInfoTest.h"


@implementation SPDatabaseInfoTest

- (SPDatabaseInfo *)getDatabaseInfoFixture {
    SPDatabaseInfo *dbInfo = [[SPDatabaseInfo alloc] init];
	return dbInfo;
}

- (id) getMockConnection {
	id mockConnection = [OCMockObject niceMockForClass:[MCPConnection class]];
	return mockConnection;
}

- (id) getMockMCPResult {
	id mockResult = [OCMockObject niceMockForClass:[MCPResult class]];
	return mockResult;
}

- (void)testDatabaseExists {
	SPDatabaseInfo *dbInfo = [self getDatabaseInfoFixture];
	
	NSArray *tables = [[NSArray alloc] initWithObjects: @"db_one", nil];
	id mockMCPResult = [self getMockMCPResult];
	[[mockMCPResult expect] numOfRows];
	[[[mockMCPResult stub] andReturn:[[NSNumber alloc] initWithInt:1]] numOfRows];
	[[mockMCPResult expect] fetchRowAsArray];
	[[[mockMCPResult stub] andReturn:tables] fetchRowAsArray];
	id mockConnection = [self getMockConnection];

	[[[mockConnection expect] andReturn:mockMCPResult] queryString:@"SHOW DATABASES"];
	[dbInfo setConnection:mockConnection];
	[dbInfo databaseExists:@"db_one"];
	[mockConnection verify];
}

- (void)testListDBs {
	SPDatabaseInfo *dbInfo = [self getDatabaseInfoFixture];
	id mockConnection = [self getMockConnection];
	[[mockConnection expect] queryString:@"SHOW DATABASES"];
	[dbInfo setConnection:mockConnection];
	[dbInfo listDBs];
	[mockConnection verify];
}

- (void)testListDBsLike {
	SPDatabaseInfo *dbInfo = [self getDatabaseInfoFixture];
	id mockConnection = [self getMockConnection];
	[[mockConnection expect] queryString:@"SHOW DATABASES LIKE `test_db`"];
	[dbInfo setConnection:mockConnection];
	[dbInfo listDBsLike:@"test_db"];
	[mockConnection verify];
}


@end
