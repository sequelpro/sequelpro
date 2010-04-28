//
//  $Id$
//
//  SPDatabaseInfoTest.m
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
