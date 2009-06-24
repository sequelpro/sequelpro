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
//

#import "mcpKitTest.h"

@implementation mcpKitTest

- (void)setUp
{
	// for now, we try an find the following database in the local connection
	// if the connection fails for any reasons, tests are not run.
	// http://downloads.mysql.com/docs/sakila-db.zip
	// set up a user called 'sakila' with no password that has all privs on the 
	// database 'sakila'
	
	mySQLConnection = [[MCPConnection alloc] initToSocket:@"/var/mysql/mysql.sock"
												  withLogin:@"sakila"
												   password:@""];
	
	if ( ![mySQLConnection isConnected] ) {
		[mySQLConnection dealloc];
		mySQLConnection = nil;
		STFail(@"unable to connect with server. No tests run!");
	} else {
		if ( ! [mySQLConnection selectDB:@"sakila"]) {
			[mySQLConnection dealloc];
			mySQLConnection = nil;
			STFail(@"unable to use `sakila` database. No tests run!");
		}
	}
}

- (void)tearDown
{
	if( mySQLConnection != nil ) {
		[mySQLConnection disconnect];
		[mySQLConnection dealloc];
	}
}

- (void)testServerVersion
{
	if( mySQLConnection == nil )
		return;
	
	STAssertTrue( [mySQLConnection serverMajorVersion] != 0, @"server version");
	STAssertTrue( [mySQLConnection serverMajorVersion] != 0, @"server version");
}


- (void)testTableList
{
	if( mySQLConnection == nil )
		return;
	
	MCPResult *theResult;

	NSString *pQuery = @"SELECT * FROM actor";
	theResult = [mySQLConnection queryString:pQuery];
	
	STAssertEquals([theResult numOfRows],(my_ulonglong)200, @"actors table count" );
}

@end
