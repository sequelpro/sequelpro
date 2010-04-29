//
//  $Id$
//
//  SPDatabaseRenameTest.m
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
#import "SPDatabaseRenameTest.h"
#import "SPDatabaseRename.h"
#import "SPTableCopy.h"
#import "MCPConnection.h"
#import "SPDatabaseInfo.h"
#import "SPStringAdditions.h"
#import "SPLogger.h"


@implementation SPDatabaseRenameTest

- (SPDatabaseRename *) getDatabaseRenameFixture {
    SPDatabaseRename *dbRename = [[SPDatabaseRename alloc] init];
	return [dbRename autorelease];
}

- (SPTableCopy *) getTableCopyFixture {
    SPTableCopy *tableCopy = [[SPTableCopy alloc] init];
	return [tableCopy autorelease];
}

- (id) getMockConnection {
	id mockConnection = [OCMockObject niceMockForClass:[MCPConnection class]];
	return mockConnection;
}

- (id) getMockDBInfo {
	id mockDBInfo = [OCMockObject niceMockForClass:[SPDatabaseInfo class]];
	return mockDBInfo;
}

- (void) testRenameDatabase {
	
	SPDatabaseRename *dbRename = [self getDatabaseRenameFixture];

	id mockConnection = [self getMockConnection];
	[[mockConnection expect] queryString:@"CREATE DATABASE `target_name`"];
	[[mockConnection expect] listTablesFromDB:@"source_name"];
	[[[mockConnection stub] andReturn:[[NSArray alloc] init]] listTablesFromDB:@"source_name"];
	[dbRename setConnection:mockConnection];
	
	id mockDBInfo = [self getMockDBInfo];
	
	BOOL varNo = NO;
	BOOL varYes = YES;
	[[[mockDBInfo expect] andReturnValue:[NSValue value:&varYes withObjCType:@encode(BOOL)]] databaseExists:@"source_name"];
	
	[[[mockDBInfo expect] andReturnValue:[NSValue value:&varNo withObjCType:@encode(BOOL)]] databaseExists:@"target_name"];
	
	[dbRename setDbInfo:mockDBInfo];
	
	NSString *source = [[NSString alloc] initWithString:@"source_name"];
	NSString *target = [[NSString alloc] initWithString:@"target_name"];
	STAssertTrue([dbRename renameDatabaseFrom:source to:target], @"method renameDatabaseFrom:to: is supposed to return YES");
	
	[mockConnection verify];
	[source release];
	[target release];
}

- (void) testCreateDatabase {
	SPDatabaseRename *dbRename = [self getDatabaseRenameFixture];
}

@end
