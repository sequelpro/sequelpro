//
//  $Id$
//
//  PGPostgresResultTests.m
//  PostgresKit
//
//  Created by Stuart Connolly (stuconnolly.com) on May 20, 2013.
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

#import "PGPostgresResultTests.h"

static NSString *PGTestDatabaseHost     = @"localhost";
static NSString *PGTestDatabaseUser     = @"pgkit_test";
static NSString *PGTestDatabaseName     = @"pgkit_test";
static NSString *PGTestDatabasePassword = @"pgkit";

static NSUInteger PGTestDatabasePort = 5432;

@interface PGPostgresResultTests ()

- (void)_establishConnection;

@end

@implementation PGPostgresResultTests

#pragma mark -
#pragma mark Setup & Teardown

- (void)setUp
{		
	_connection = [[PGPostgresConnection alloc] init];
	
	[self _establishConnection];
	
	_result = [_connection execute:@"SELECT * FROM \"data_types\""];	
}

#pragma mark -
#pragma mark Tests

- (void)testResultDescriptionIsCorrect
{	
	// Compare the output after getting rid of newlines and spaces
	STAssertTrue([[[[_result description] stringByReplacingOccurrencesOfString:@"\n" withString:@""] stringByReplacingOccurrencesOfString:@"    " withString:@""] isEqualToString:@"{"
		"\"bigint_field\" = 123456789;"
		"\"bool_field\" = 1;"
		"\"char_field\" = CHAR;"
		"\"date_field\" = \"1987-04-08 00:00:00 +0100\";"
		"\"float_field\" = \"12345.68\";"
		"\"int_field\" = 12345;"
		"\"numeric_field\" = \"12345.678\";"
		"\"smallint_field\" = 2;"
		"\"time_field\" = \"2000-01-01 02:02:02 +0000\";"
		"\"timestamp_field\" = \"1987-04-08 03:02:02 +0100\";"
		"\"timestamptz_field\" = \"8 Apr 1987 03:02:02 GMT+01:00\";"
		"\"timetz_field\" = \"02:02:02 GMT+10:00\";"
		"\"varchar_field\" = VARCHAR;"
	"}"], nil);
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
	
	if (_result) [_result release], _result = nil;
	if (_connection) [_connection release], _connection = nil;
	
	[super dealloc];
}

@end
