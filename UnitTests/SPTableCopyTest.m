//
//  $Id$
//
//  SPTableCopyTest.m
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

#import "SPTableCopy.h"
#import "SPTableCopyTest.h"

#import <OCMock/OCMock.h>
#import <SPMySQL/SPMySQL.h>

@implementation SPTableCopyTest

- (id)mockConnection 
{
	return [[OCMockObject niceMockForClass:[SPMySQLConnection class]] autorelease];
}

- (id)mockResult 
{
	return [[OCMockObject niceMockForClass:[SPMySQLResult class]] autorelease];
}

/*- (void)testCopyTableFromToWithData 
{
	id mockResult = [self mockResult];
	
	unsigned long long varOne = 1;
	NSValue *valueOne = [NSValue value:&varOne withObjCType:@encode(__typeof__(varOne))];
	BOOL varNo = NO;
	
	NSValue *valueNo = [NSValue value:&varNo withObjCType:@encode(BOOL)];
	NSArray *resultArray = [[NSArray alloc] initWithObjects:@"", @"CREATE TABLE `table_name` ()", nil];
	
	id mockConnection = [self mockConnection];
	
	[(SPMySQLResult *)[[mockResult expect] andReturn:valueOne] numberOfRows];
	[[[mockResult expect] andReturn:resultArray] getRowAsArray];
	
	[[[mockConnection expect] andReturn:mockResult] queryString:@"SHOW CREATE TABLE `source_db`.`table_name`"];
	[[mockConnection expect] queryString:@"CREATE TABLE `target_db`.`table_name` ()"];
	[[mockConnection expect] queryString:@"INSERT INTO `target_db`.`table_name` SELECT * FROM `source_db`.`table_name`"];
	[[[mockConnection stub] andReturnValue:valueNo] queryErrored];

	SPTableCopy *tableCopy = [[SPTableCopy alloc] init];
	
	[tableCopy setConnection:mockConnection];
	[tableCopy copyTable:@"table_name" from:@"source_db" to:@"target_db" withContent:YES];
	
	[mockResult verify];
	[mockConnection verify];
	
	[tableCopy release];
	[resultArray release];
}*/

@end
