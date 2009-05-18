//
//  mcpKitTest.m
//  sequel-pro
//
//  Created by J Knight on 17/05/09.
//  Copyright 2009 TalonEdge Ltd.. All rights reserved.
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
	
	mySQLConnection = [[CMMCPConnection alloc] initToSocket:@"/var/mysql/mysql.sock"
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


- (void)testTableList
{
	if( mySQLConnection == nil )
		return;
	
	CMMCPResult *theResult;

	NSString *pQuery = @"SELECT * FROM actor";
	theResult = [mySQLConnection queryString:pQuery];
	
	STAssertEquals([theResult numOfRows],(my_ulonglong)200, @"actors table count" );
}

@end
