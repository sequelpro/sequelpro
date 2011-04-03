//
//  $Id$
//
//  MCPKitTest.m
//  sequel-pro
//
//  Created by J Knight on 17/05/09.
//  Copyright 2009 J Knight. All rights reserved.
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

#import <MCPKit/MCPKit.h>

#import "MCPKitTest.h"

static NSString *SPTestDatabaseHost     = @"127.0.0.1";
static NSString *SPTestDatabaseName     = @"sakila";
static NSString *SPTestDatabaseUser     = @"sp_tester";
static NSString *SPTestDatabasePassword = @"";

static const NSInteger SPTestDatabasePort     = 3306;

@implementation MCPKitTest

#pragma mark -
#pragma mark Setup & tear down

/**
 * Sets up the connection for use in the test cases.
 */
- (void)setUp
{
	connection = [[MCPConnection alloc] initToHost:SPTestDatabaseHost withLogin:SPTestDatabaseUser usingPort:SPTestDatabasePort];
	
	[connection setPassword:SPTestDatabasePassword];
	
	[connection setConnectionTimeout:10];
	[connection setUseKeepAlive:1];
	[connection setKeepAliveInterval:60];
	
	[connection connect];
	
	if (![connection isConnected]) {
		[connection release], connection = nil;
		
		STFail(@"Error connecting to database server. No tests were run.");
	} 
	else {
		if (![connection selectDB:SPTestDatabaseName]) {
			[connection release], connection = nil;
			
			STFail(@"Error selecting database '%@'. No tests were run.", SPTestDatabaseName);
		}
	}
}

/**
 * Disconnects the connection if connected.
 */
- (void)tearDown
{
	if (connection && [connection isConnected]) {
		[connection disconnect];
	}
	
	[connection release], connection = nil;
}

#pragma mark -
#pragma mark Tests

/**
 * Tests the connection's major version number.
 */
- (void)testServerMajorVersion
{
	if ((!connection) || (![connection isConnected])) return;
	
	STAssertTrue(([connection serverMajorVersion] != 0), @"server major version");
}

/**
 * Tests the connection's version string.
 */
- (void)testServerVersionString
{
	if ((!connection) || (![connection isConnected])) return;
	
	STAssertTrue(([[connection serverVersionString] length] > 0), @"server version string");
}

/**
 * Tests the connection query execution.
 */
- (void)testQueryExexution
{
	if ((!connection) || (![connection isConnected])) return;

	MCPResult *result = [connection queryString:@"SELECT * FROM actor"];
	
	if ([connection queryErrored]) {
		STFail(@"Query execution failed with error: %@", [connection getLastErrorMessage]);
	}
	else {
		STAssertEquals([result numOfRows], (my_ulonglong)200, @"'actors' table count");
	}
}

@end
