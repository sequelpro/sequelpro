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
//  More info at <https://github.com/sequelpro/sequelpro>

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

- (void)testNonConsecutivelySearchStringMatchingRanges
{
	//basic tests
	{
		NSArray *matches = nil;
		STAssertTrue([@"" nonConsecutivelySearchString:@"" matchingRanges:&matches], @"Equality of empty strings");
		STAssertTrue(([matches count] == 1) && NSEqualRanges(NSMakeRange(0, 0), [(NSValue *)[matches objectAtIndex:0] rangeValue]), @"Returned matches in empty string");
	}
	
	{
		NSArray *matches = (void *)0xdeadbeef;
		STAssertFalse([@"" nonConsecutivelySearchString:@"R" matchingRanges:&matches], @"Inequality with empty left side");
		STAssertTrue((matches == (void *)0xdeadbeef), @"out variable not touched by mismatch");
	}
	
	STAssertFalse([@"L" nonConsecutivelySearchString:@"" matchingRanges:NULL], @"Inequality with empty right side");
	
	{
		NSArray *matches = nil;
		STAssertTrue([@"left" nonConsecutivelySearchString:@"le" matchingRanges:&matches], @"Anchored match left");
		STAssertTrue(([matches count] == 1) && NSEqualRanges(NSMakeRange(0, 2), [(NSValue *)[matches objectAtIndex:0] rangeValue]), @"Returned matches in anchored left match");
	}
	
	{
		NSArray *matches = nil;
		STAssertTrue([@"right" nonConsecutivelySearchString:@"ht" matchingRanges:&matches], @"Anchored match right");
		STAssertTrue(([matches count] == 1) && NSEqualRanges(NSMakeRange(3, 2), [(NSValue *)[matches objectAtIndex:0] rangeValue]), @"Returned matches in anchroed right match");
	}
	
	STAssertFalse([@"ht" nonConsecutivelySearchString:@"right" matchingRanges:NULL], @"Left and Right are not commutative");
	
	//real tests
	{
		NSArray *matches = nil;
		STAssertTrue([@"... is not secure anymore!" nonConsecutivelySearchString:@"NSA"  matchingRanges:&matches], @"Non-consecutive match, ignoring case");
		STAssertTrue(([matches count] == 3) &&
					 (NSEqualRanges(NSMakeRange(7, 1), [(NSValue *)[matches objectAtIndex:0] rangeValue])) &&
					 (NSEqualRanges(NSMakeRange(11, 1), [(NSValue *)[matches objectAtIndex:1] rangeValue])) &&
					 (NSEqualRanges(NSMakeRange(18, 1), [(NSValue *)[matches objectAtIndex:2] rangeValue])), @"Returned matches in non-consecutive string");
	}
	
	STAssertFalse([@"Deoxyribonucleic Acid" nonConsecutivelySearchString:@"DNS"  matchingRanges:NULL], @"Non-consecutive mismatch");
	
	{
		NSArray *matches = nil;
		STAssertTrue([@"Turn left, then right at the corner" nonConsecutivelySearchString:@"left right" matchingRanges:&matches], @"Partly consecutive match");
		STAssertTrue(([matches count] == 3) &&
					 (NSEqualRanges(NSMakeRange(5, 4), [(NSValue *)[matches objectAtIndex:0] rangeValue])) &&
					 (NSEqualRanges(NSMakeRange(10, 1), [(NSValue *)[matches objectAtIndex:1] rangeValue])) &&
					 (NSEqualRanges(NSMakeRange(16, 5), [(NSValue *)[matches objectAtIndex:2] rangeValue])), @"Returned matches in partly-consecutive string");
	}
	
	//advanced tests
	
	// LATIN CAPITAL LETTER A              == LATIN SMALL LETTER A
	// LATIN SMALL LETTER O WITH DIAERESIS == LATIN SMALL LETTER O
	// FULLWIDTH LATIN SMALL LETTER b      == LATIN SMALL LETTER B
	STAssertTrue([@"A:\xC3\xB6:\xEF\xBD\x82" nonConsecutivelySearchString:@"aob" matchingRanges:NULL], @"Fuzzy matching of defined characters");
	
	//all bytes on the right are contained on the left, but on a character level "ä" is not contained in "Hütte Ф"
	STAssertFalse([@"H\xC3\xBCtte \xD0\xA4" nonConsecutivelySearchString:@"\xC3\xA4" matchingRanges:NULL], @"Mismatch of composed characters with same prefix");
	
	// ":😥:𠘄:" vs "😄" (according to wikipedia "𠘄" is the arachic variant of "印")
	// TECHNICALLY THIS SHOULD NOT MATCH!
	// However Apple doesn't correctly handle characters in the 4-Byte UTF range, so let's use this test to check for changes in Apples behaviour :)
	STAssertTrue([@":\xF0\x9F\x98\x84:\xF0\xA0\x98\x84:" nonConsecutivelySearchString:@"\xF0\x9F\x98\x84" matchingRanges:NULL], @"Mismatch of composed characters (4-byte) with same prefix");
	
}

@end
