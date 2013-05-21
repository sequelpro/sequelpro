//
//  $Id$
//
//  PGPostgresIntegrationTestCase.m
//  PostgresKit
//
//  Created by Stuart Connolly (stuconnolly.com) on May 21, 2013.
//  Copyright (c) 2013 Stuart Connolly. All rights reserved.
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

#import "PGPostgresIntegrationTestCase.h"

static NSString *PGTestDatabaseHost     = @"localhost";
static NSString *PGTestDatabaseUser     = @"pgkit_test";
static NSString *PGTestDatabaseName     = @"pgkit_test";
static NSString *PGTestDatabasePassword = @"pgkit";

static NSUInteger PGTestDatabasePort = 5432;

@interface PGPostgresIntegrationTestCase ()

- (void)_establishConnection;

@end

@implementation PGPostgresIntegrationTestCase

@synthesize connection = _connection;

#pragma mark -
#pragma mark Setup & Teardown

- (void)setUp
{		
	_connection = [[PGPostgresConnection alloc] init];
	
	[self _establishConnection];	
}

#pragma mark -
#pragma mark Private API

- (void)_establishConnection
{		
	[_connection setHost:PGTestDatabaseHost];
	[_connection setUser:PGTestDatabaseUser];
	[_connection setPort:PGTestDatabasePort];
	[_connection setDatabase:PGTestDatabaseName];
	[_connection setPassword:PGTestDatabasePassword];
	
	if (![_connection connect]) {
		STFail(@"Request to establish connection to local database failed.");
		
		exit(1);
	}	
	
	do {
		sleep(0.1);
	}
	while (![_connection isConnected]);
}

#pragma mark -

- (void)dealloc
{
	if (_connection && [_connection isConnected]) {
		[_connection disconnect];
	}
	
	if (_connection) [_connection release], _connection = nil;
	
	[super dealloc];
}

@end
