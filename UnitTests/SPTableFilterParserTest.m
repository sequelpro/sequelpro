//
//  SPTableFilterParserTest.m
//  sequel-pro
//
//  Created by Max Lohrmann on 23.04.15.
//
//

#import <Foundation/Foundation.h>
#import "SPTableFilterParser.h"

#define USE_APPLICATION_UNIT_TEST 1

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

@interface SPTableFilterParserTest : XCTestCase

- (void)testFilterString;

@end

@implementation SPTableFilterParserTest

- (void)testFilterString {
	//simple zero argument case
	{
		SPTableFilterParser *p = [[[SPTableFilterParser alloc] initWithFilterClause:@" constant $BINARY string" numberOfArguments:0] autorelease];
		[p setCurrentField:@"FLD"];
		
		// binary matches as "$BINARY ", eating the one additional whitespace
		XCTAssertEqualObjects([p filterString],@"`FLD`  constant string", @"Constant replacement");
	}
	//simple one argument case with binary
	{
		SPTableFilterParser *p = [[[SPTableFilterParser alloc] initWithFilterClause:@"= FOO($BINARY ${})" numberOfArguments:1] autorelease];
		[p setCurrentField:@"FLD2"];
		[p setCaseSensitive:YES];
		[p setArgument:@"arg1"];
		
		XCTAssertEqualObjects([p filterString], @"`FLD2` = FOO(BINARY arg1)", @"One Argument, $BINARY variable");
	}
	//simple two argument case with explicit current field
	{
		SPTableFilterParser *p = [[[SPTableFilterParser alloc] initWithFilterClause:@"MIN($CURRENT_FIELD,${}) = ${}" numberOfArguments:2] autorelease];
		[p setCurrentField:@"FLD3"];
		[p setSuppressLeadingTablePlaceholder:YES];
		[p setFirstBetweenArgument:@"LA"];
		[p setSecondBetweenArgument:@"RA"];
		
		XCTAssertEqualObjects([p filterString], @"MIN(`FLD3`,LA) = RA", @"Two Arguments, $CURRENT_FIELD variable");
	}

}


@end
