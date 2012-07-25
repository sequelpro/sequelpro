//
//  $Id$
//
//  SPStringAdditionsTests.m
//  sequel-pro
//
//  Created by Jim Knight on May 17, 2009.
//  Copyright (c) 2009 Jim Knight. All rights reserved.
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
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPStringAdditionsTests.h"
#import "SPStringAdditions.h"
#import "RegexKitLite.h"

@implementation SPStringAdditionsTests

/**
 * stringByRemovingCharactersInSet test case.
 */
- (void)testStringByRemovingCharactersInSet
{
	NSString *SPASCIITestString = @"this is a big, crazy test st'ring  with som'e random  spaces and quot'es";
	NSString *SPUTFTestString   = @"In der Kürze liegt die Würz";
	
	NSString *charsToRemove = @"abc',ü";
	
	NSCharacterSet *junk = [NSCharacterSet characterSetWithCharactersInString:charsToRemove];
	
	NSString *actualUTFString = SPUTFTestString;
	NSString *actualASCIIString = SPASCIITestString;
	
	NSString *expectedUTFString = @"In der Krze liegt die Wrz";
	NSString *expectedASCIIString = @"this is  ig rzy test string  with some rndom  spes nd quotes";
	
	STAssertEqualObjects([actualASCIIString stringByRemovingCharactersInSet:junk], 
						 expectedASCIIString, 
						 @"The following characters should have been removed %@", 
						 charsToRemove);
	
	STAssertEqualObjects([actualUTFString stringByRemovingCharactersInSet:junk], 
						 expectedUTFString, 
						 @"The following characters should have been removed %@", 
						 charsToRemove);
}

/**
 * stringWithNewUUID test case.
 */
- (void)testStringWithNewUUID
{	
	NSString *uuid = [NSString stringWithNewUUID];
		
	STAssertTrue([uuid isMatchedByRegex:@"[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}"], @"UUID %@ doesn't match regex", uuid);
}

/**
 * createViewSyntaxPrettifier test case.
 */
- (void)testCreateViewSyntaxPrettifier
{
	NSString *originalSyntax = @"CREATE VIEW `test_view` AS select `test_table`.`id` AS `id` from `test_table`;";
	NSString *expectedSyntax = @"CREATE VIEW `test_view`\nAS SELECT\n   `test_table`.`id` AS `id`\nFROM `test_table`;";
	
	NSString *actualSyntax = [originalSyntax createViewSyntaxPrettifier];
	
	STAssertEqualObjects([actualSyntax description], [expectedSyntax description], @"Actual view syntax '%@' does not equal expected syntax '%@'", actualSyntax, expectedSyntax);
}

@end
