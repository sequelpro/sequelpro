//
//  mcpKitTest.m
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

#import "mcpKitTest.h"

@implementation mcpKitTest

- (void)setUp
{
	// For now, we try an find the following database in the local connection.
	// If the connection fails for any reasons, tests are not run.
	// http://downloads.mysql.com/docs/sakila-db.zip
	//
	// Set up a user called 'sakila' with no password that has all privs on the 
	// database 'sakila'.
	
	connection = [[MCPConnection alloc] initToSocket:@"/var/mysql/mysql.sock" withLogin:@"sakila"];
	
	// Set the 'sakila' user's password
	[connection setPassword:@""];
	
	if (![connection isConnected]) {
		[connection dealloc];
		connection = nil;
		STFail(@"Error connecting to database server. No tests were run.");
	} 
	else {
		if (![connection selectDB:@"sakila"]) {
			[connection dealloc];
			connection = nil;
			STFail(@"Error selecting database 'sakila'. No tests were run.");
		}
	}
}

- (void)tearDown
{
	if (connection != nil) {
		[connection disconnect];
		[connection dealloc];
	}
}

- (void)testServerVersion
{
	if (connection == nil) return;
	
	STAssertTrue([connection serverMajorVersion] != 0, @"server version");
	STAssertTrue([connection serverMajorVersion] != 0, @"server version");
}

- (void)testTableList
{
	if (connection == nil) return;

	MCPResult *queryResult = [connection queryString:@"SELECT * FROM actor"];
	
	STAssertEquals([queryResult numOfRows], (my_ulonglong)200, @"actors table count");
}

@end
