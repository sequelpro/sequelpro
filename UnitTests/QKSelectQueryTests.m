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

#import "QKSelectQueryTests.h"

static NSString *QKTestTableName = @"test_table";

static NSString *QKTestFieldOne   = @"test_field1";
static NSString *QKTestFieldTwo   = @"test_field2";
static NSString *QKTestFieldThree = @"test_field3";
static NSString *QKTestFieldFour  = @"test_field4";

static NSUInteger QKTestParameterOne = 10;

@implementation QKSelectQueryTests

#pragma mark -
#pragma mark Setup & tear down

- (void)setUp
{
	_query = [QKQuery selectQueryFromTable:QKTestTableName];
	
	[_query addField:QKTestFieldOne];
	[_query addField:QKTestFieldTwo];
	[_query addField:QKTestFieldThree];
	[_query addField:QKTestFieldFour];
	
	[_query addParameter:QKTestFieldOne operator:QKEqualityOperator value:[NSNumber numberWithUnsignedInteger:QKTestParameterOne]];
}

#pragma mark -
#pragma mark Tests

- (void)testSelectQueryTypeIsCorrect
{
	STAssertTrue([[_query query] hasPrefix:@"SELECT"], @"query type");
}

- (void)testSelectQueryFieldsAreCorrect
{
	NSString *query = [NSString stringWithFormat:@"SELECT %@, %@, %@, %@", QKTestFieldOne, QKTestFieldTwo, QKTestFieldThree, QKTestFieldFour];
				
	STAssertTrue([[_query query] hasPrefix:query], @"query fields");
}

- (void)testSelectQueryConstraintsAreCorrect
{
	NSString *query = [NSString stringWithFormat:@"WHERE %@ %@ %@", QKTestFieldOne, [QKQueryUtilities operatorRepresentationForType:QKEqualityOperator], [NSNumber numberWithUnsignedInteger:QKTestParameterOne]];
	
	STAssertTrue(([[_query query] rangeOfString:query].location != NSNotFound), @"query constraints");
}

@end
