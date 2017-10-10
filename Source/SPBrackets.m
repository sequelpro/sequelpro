//
//  SPBrackets.m
//  Sequel Pro
//
//
//  Created by Piotr Marnik on 07/10/2017.
//  Copyright (c) 2017 Piotr Marnik. All rights reserved.
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

#import "SPBrackets.h"


static NSDictionary *bracketPairs;
static NSDictionary *bracketPairsReverse;
static NSSet *openingBrackets;
static NSSet *closingBrackets;



@implementation SPBrackets



+(void)initialize {
	bracketPairs = [[NSDictionary alloc] initWithDictionary:@{
														   @('{') : @('}'),
														   @('(') : @(')'),
														   @('[') : @(']')
														   } copyItems:TRUE];
	
	NSMutableDictionary *swapped = [[NSMutableDictionary alloc] init];
	[bracketPairs enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
		swapped[obj] = key;
	}];
	bracketPairsReverse = swapped;
	
	openingBrackets = [[NSSet alloc] initWithArray:[bracketPairs allKeys]];
	closingBrackets = [[NSSet alloc] initWithArray:[bracketPairs allValues]];
	
}

+(BOOL)isOpeningBracket:(unichar)aChar {
	return [openingBrackets containsObject:@(aChar)];
}

+(BOOL)isClosingBracket:(unichar)aChar {
	return [closingBrackets containsObject:@(aChar)];
}

+(NSInteger)findMatchingBracketAtPosition:(NSInteger)position inString:(NSString*)string {
	if (!(position >= 0 && position < (NSInteger) string.length)) {
		return NSNotFound;
	}
	unichar aChar = [string characterAtIndex:position];
	if ([self isOpeningBracket:aChar]) {
		return [self nextMatchingClosingBracket:string atPosition:position];
	} else if ([self isClosingBracket:aChar]) {
		return [self nextMatchingOpeningBracket:string atPosition:position];
	} else {
		return NSNotFound;
	}
}

+(BOOL)isInComment:(NSString*)string position:(NSInteger)position {
	return
	[self isInComment:string position:position open:@"/*" close:@"*/"] ||
	[self isInComment:string position:position open:@"--" close:@"\n"];
}

+(BOOL)isInComment:(NSString*)string position:(NSInteger)position open:(NSString*)open close:(NSString*)close {
	NSRange openCommentRange = [string rangeOfString:open options:NSBackwardsSearch range: NSMakeRange(0, position)];
	NSRange closeCommentRange = NSMakeRange(NSNotFound, 0);
	if (openCommentRange.location != NSNotFound) {
		closeCommentRange = [string rangeOfString:close options:kNilOptions range:NSMakeRange(openCommentRange.location, string.length - openCommentRange.location)];
	}
	
	NSInteger startLocation = openCommentRange.location;
	NSInteger endLocation = closeCommentRange.location != NSNotFound ? closeCommentRange.location + closeCommentRange.length : NSNotFound;
	
	BOOL inComment = startLocation != NSNotFound && startLocation < position && endLocation > position;
	BOOL inUnclosedComment = startLocation != NSNotFound && endLocation  == NSNotFound;
	
	return inComment || inUnclosedComment;
}


+(NSInteger)nextMatchingClosingBracket:(NSString*)string atPosition:(NSInteger)openPosition {
	unichar openingBracket = [string characterAtIndex:openPosition];
	unichar closingBracket = [[bracketPairs objectForKey:@(openingBracket)] integerValue];
	if ([self isInComment:string position:openPosition]) {
		return NSNotFound;
	}
	
	NSInteger count = 0;
	NSInteger pos = openPosition;
	for (pos = openPosition; pos < (NSInteger) string.length; pos++) {
		if ([self isInComment:string position:pos]) {
			continue;
		}
		if ([string characterAtIndex:pos] == closingBracket) {
			count++;
		}
		if ([string characterAtIndex:pos] == openingBracket) {
			count--;
		}
		if (count == 0) {
			break;
		}
	}
	return !count ? pos : NSNotFound;
	
}

+(NSInteger)nextMatchingOpeningBracket:(NSString*)string atPosition:(NSInteger)closePosition {
	unichar closingBracket = [string characterAtIndex:closePosition];
	unichar openingBracket = [[bracketPairsReverse objectForKey:@(closingBracket)] integerValue];

	if ([self isInComment:string position:closePosition]) {
		return NSNotFound;
	}
	
	NSInteger count = 0;
	NSInteger pos = closePosition;
	for (pos = closePosition; pos >= 0; pos --) {
		if ([self isInComment:string position:pos]) {
			continue;
		}
		if ([string characterAtIndex:pos] == closingBracket) {
			count ++;
		}
		if ([string characterAtIndex:pos] == openingBracket) {
			count --;
		}
		if (count == 0) {
			break;
		}
	}
	return !count ? pos : NSNotFound;
}

@end
