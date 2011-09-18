//
//  $Id$
//
//  QKSelectQueryTests.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on September 4, 2011
//  Copyright (c) 2011 Stuart Connolly. All rights reserved.
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

#import <QueryKit/QueryKit.h>
#import "QKSelectQueryTests.h"

static NSString *SPTestTableName = @"test_table";

static NSString *SPTestFieldOne   = @"test_field1";
static NSString *SPTestFieldTwo   = @"test_field2";
static NSString *SPTestFieldThree = @"test_field3";
static NSString *SPTestFieldFour  = @"test_field4";

static NSString *SPTestParameterOne = @"10";

@implementation QKSelectQueryTests

#pragma mark -
#pragma mark Setup & tear down

- (void)setUp
{
	_query = [QKQuery selectQueryFromTable:SPTestTableName];
	
	[_query addField:SPTestFieldOne];
	[_query addField:SPTestFieldTwo];
	[_query addField:SPTestFieldThree];
	[_query addField:SPTestFieldFour];
	
	[_query addParameter:SPTestFieldOne operator:QKEqualityOperator value:SPTestParameterOne];
}

#pragma mark -
#pragma mark Tests

- (void)testSelectQueryTypeIsCorrect
{
	STAssertTrue([[_query query] hasPrefix:@"SELECT"], @"query type");
}

- (void)testSelectQueryFieldsAreCorrect
{
	NSString *query = [NSString stringWithFormat:@"SELECT %@, %@, %@, %@", SPTestFieldOne, SPTestFieldTwo, SPTestFieldThree, SPTestFieldFour];
				
	STAssertTrue([[_query query] hasPrefix:query], @"query fields");
}

@end
