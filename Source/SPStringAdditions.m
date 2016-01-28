//
//  SPStringAdditions.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on January 28, 2009.
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

#import "SPStringAdditions.h"
#import "RegexKitLite.h"
#include <stdlib.h>

static NSInteger _smallestOf(NSInteger a, NSInteger b, NSInteger c);

@implementation NSString (SPStringAdditions)

/*
 * Returns a human readable version string of the supplied byte size.
 */
+ (NSString *)stringForByteSize:(long long)byteSize
{
	double size = byteSize;
	
	NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
	
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
	
	if (size < 1023) {
		[numberFormatter setFormat:@"#,##0 B"];
		
		return [numberFormatter stringFromNumber:[NSNumber numberWithDouble:size]];
	}
	
	size = (size / 1024);
	
	if (size < 1023) {
		[numberFormatter setFormat:@"#,##0.0 KiB"];
		
		return [numberFormatter stringFromNumber:[NSNumber numberWithDouble:size]];
	}
	
	size = (size / 1024);
	
	if (size < 1023) {
		[numberFormatter setFormat:@"#,##0.0 MiB"];
		
		return [numberFormatter stringFromNumber:[NSNumber numberWithDouble:size]];
	}
	
	size = (size / 1024);
	
	if (size < 1023) {
		[numberFormatter setFormat:@"#,##0.0 GiB"];
		
		return [numberFormatter stringFromNumber:[NSNumber numberWithDouble:size]];
	}

	size = (size / 1024);
	
	[numberFormatter setFormat:@"#,##0.0 TiB"];
	
	return [numberFormatter stringFromNumber:[NSNumber numberWithDouble:size]];
}

/**
 * Returns a human readable version string of the supplied time interval.
 */ 
+ (NSString *)stringForTimeInterval:(double)timeInterval
{
	NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];

	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];

	// For time periods of less than one millisecond, display a localised "< 0.1 ms"
	if (timeInterval < 0.0001) {
		[numberFormatter setFormat:@"< #,##0.0 ms"];

		return [numberFormatter stringFromNumber:[NSNumber numberWithDouble:0.1]];
	}

	if (timeInterval < 0.1) {
		timeInterval = (timeInterval * 1000);
		[numberFormatter setFormat:@"#,##0.0 ms"];

		return [numberFormatter stringFromNumber:[NSNumber numberWithDouble:timeInterval]];
	}
	if (timeInterval < 1) {
		timeInterval = (timeInterval * 1000);
		[numberFormatter setFormat:@"#,##0 ms"];

		return [numberFormatter stringFromNumber:[NSNumber numberWithDouble:timeInterval]];
	}
	
	if (timeInterval < 10) {
		[numberFormatter setFormat:@"#,##0.00 s"];

		return [numberFormatter stringFromNumber:[NSNumber numberWithDouble:timeInterval]];
	}

	if (timeInterval < 100) {
		[numberFormatter setFormat:@"#,##0.0 s"];

		return [numberFormatter stringFromNumber:[NSNumber numberWithDouble:timeInterval]];
	}

	if (timeInterval < 300) {
		[numberFormatter setFormat:@"#,##0 s"];

		return [numberFormatter stringFromNumber:[NSNumber numberWithDouble:timeInterval]];
	}

	if (timeInterval < 3600) {
		timeInterval = (timeInterval / 60);
		[numberFormatter setFormat:@"#,##0 min"];

		return [numberFormatter stringFromNumber:[NSNumber numberWithDouble:timeInterval]];
	}

	timeInterval = (timeInterval / 3600);
	
	[numberFormatter setFormat:@"#,##0 hours"];

	return [numberFormatter stringFromNumber:[NSNumber numberWithDouble:timeInterval]];
}

/**
 * Returns a new created UUID string.
 */
+ (NSString *)stringWithNewUUID
{
	// Create a new UUID
	CFUUIDRef uuidObj = CFUUIDCreate(nil);

	// Get the string representation of the UUID
	NSString *newUUID = (NSString *)CFUUIDCreateString(nil, uuidObj);
	
	CFRelease(uuidObj);
	
	return [newUUID autorelease];
}

/**
 * Returns the ROT13 representation of self.
 */
- (NSString *)rot13
{
	unichar theChar;
	NSMutableString *holder = [[NSMutableString alloc] init];
	
	for (NSUInteger i = 0; i < [self length]; i++) 
	{
		theChar = [self characterAtIndex:i];
		
		if (theChar <= 122 && theChar >= 97) {
			if (theChar + 13 > 122) {
				theChar -= 13;
			}
			else {
				theChar += 13;
			}
			
			[holder appendFormat:@"%C", theChar];

		} 
		else if (theChar <= 90 && theChar >= 65) {
			if ((int)theChar + 13 > 90) {
				theChar -= 13;
			}
			else {
				theChar += 13;
			}

			[holder appendFormat:@"%C", theChar];
		} 
		else {
			[holder appendFormat:@"%C", theChar];
		}
	}

	NSString *result = [NSString stringWithString:holder];

	[holder release];

	return result;
}

/**
 * Escapes HTML special characters.
 */
- (NSString *)HTMLEscapeString
{
	NSMutableString *mutableString = [NSMutableString stringWithString:self];
	
	[mutableString replaceOccurrencesOfString:@"&" withString:@"&amp;"
									  options:NSLiteralSearch
										range:NSMakeRange(0, [mutableString length])];
	
	[mutableString replaceOccurrencesOfString:@"<" withString:@"&lt;"
									  options:NSLiteralSearch
										range:NSMakeRange(0, [mutableString length])];
	
	[mutableString replaceOccurrencesOfString:@">" withString:@"&gt;"
									  options:NSLiteralSearch
										range:NSMakeRange(0, [mutableString length])];
	
	[mutableString replaceOccurrencesOfString:@"\"" withString:@"&quot;"
									  options:NSLiteralSearch
										range:NSMakeRange(0, [mutableString length])];
	
	return [NSString stringWithString:mutableString];
}

/**
 * Returns the string quoted with backticks as required for MySQL identifiers.
 *
 * eg.: tablename    =>   `tablename`
 *      my`table     =>   `my``table`
 */
- (NSString *)backtickQuotedString
{
	return [NSString stringWithFormat: @"`%@`", [self stringByReplacingOccurrencesOfString:@"`" withString:@"``"]];
}

/**
 * Returns the string quoted with ticks as required for MySQL identifiers.
 *
 * eg.: tablename    =>   'tablename'
 *      my'table     =>   'my''table'
 */
- (NSString *)tickQuotedString
{
	return [NSString stringWithFormat: @"'%@'", [self stringByReplacingOccurrencesOfString:@"'" withString:@"''"]];
}

/**
 * Replaces an occurrences of underscores with a single space.
 */
- (NSString *)replaceUnderscoreWithSpace
{
	return [self stringByReplacingOccurrencesOfString:@"_" withString:@" "];
}

/**
 * Returns a more readable version of a 'CREATE VIEW SYNTAX' string.
 *
 * If the string doesn't match it returns the unchanged string.
 */
- (NSString *)createViewSyntaxPrettifier
{
	NSRange searchRange = NSMakeRange(0, [self length]);
	NSRange matchedRange;
	NSMutableString *tblSyntax = [NSMutableString stringWithCapacity:[self length]];
	NSString *re = @"(.*?) AS select (.*?) (from.*)";
	
	// Create view syntax
	matchedRange = [self rangeOfRegex:re options:(RKLMultiline|RKLDotAll) inRange:searchRange capture:1 error:nil];
	
	if (!matchedRange.length || matchedRange.length > [self length]) return [self description];
	
	[tblSyntax appendString:[self substringWithRange:matchedRange]];
	[tblSyntax appendString:@"\nAS SELECT\n   "];
	
	// Match all column definitions, split them by ',', and rejoin them by '\n'
	matchedRange = [self rangeOfRegex:re options:(RKLMultiline|RKLDotAll) inRange:searchRange capture:2 error:nil];
	
	if (!matchedRange.length || matchedRange.length > [self length]) return [self description];
	
	[tblSyntax appendString:[[[self substringWithRange:matchedRange] componentsSeparatedByString:@"`,`"] componentsJoinedByString:@"`,\n   `"]];
	
	// FROM ... on a new line
	matchedRange = [self rangeOfRegex:re options:(RKLMultiline|RKLDotAll) inRange:searchRange capture:3 error:nil];
	
	if (!matchedRange.length || matchedRange.length > [self length]) return [self description];
	
	NSMutableString *from = [[NSMutableString alloc] initWithString:[self substringWithRange:matchedRange]];
	
	// Uppercase FROM
	[from replaceCharactersInRange:NSMakeRange(0, 4) withString:@"FROM"];
	
	[tblSyntax appendString:@"\n"];
	[tblSyntax appendString:from];
	
	[from release];
	
	// Where clause at a new line if given
	[tblSyntax replaceOccurrencesOfString:@" WHERE (" withString:@"\nWHERE (" options:NSLiteralSearch range:NSMakeRange(0, [tblSyntax length])];
	
	return tblSyntax;
}

/**
 * Returns an array of serialised NSRanges, each representing a line within the string
 * which is at least partially covered by the NSRange supplied.
 * Each line includes the line termination character(s) for the line.  As per
 * lineRangeForRange, lines are split by CR, LF, CRLF, U+2028 (Unicode line separator),
 * or U+2029 (Unicode paragraph separator).
 */
- (NSArray *)lineRangesForRange:(NSRange)aRange
{
	NSRange currentLineRange;
	NSMutableArray *lineRangesArray = [NSMutableArray array];

	// Check that the range supplied is valid - if not return an empty array.
	if (aRange.location == NSNotFound || NSMaxRange(aRange) > [self length]) {
		return lineRangesArray;
	}

	// Get the range of the first string covered by the specified range, and add it to the array
	currentLineRange = [self lineRangeForRange:NSMakeRange(aRange.location, 0)];
	
	[lineRangesArray addObject:NSStringFromRange(currentLineRange)];

	// Loop through until the line end matches or surpasses the end of the specified range
	while (NSMaxRange(currentLineRange) < NSMaxRange(aRange))
	{
		currentLineRange = [self lineRangeForRange:NSMakeRange(NSMaxRange(currentLineRange), 0)];
		
		[lineRangesArray addObject:NSStringFromRange(currentLineRange)];
	}

	// Return the constructed array of ranges
	return lineRangesArray;
}

- (NSString *)stringByReplacingCharactersInSet:(NSCharacterSet *)set withString:(NSString *)string
{
	NSUInteger len = [self length];
	NSMutableString *newString = [NSMutableString string];
	
	NSRange range = NSMakeRange (0, len);
	
	while (true) {
		NSRange substringRange;
		NSUInteger pos = range.location;
		BOOL endAfterInsert = NO;
		
		range = [self rangeOfCharacterFromSet:set options:0 range:range];
		
		if(range.location == NSNotFound) {
			// insert the current substring up to the end
			substringRange = NSMakeRange(pos, len - pos);
			endAfterInsert = YES;
		}
		else {
			// insert the current substring up to range.location
			substringRange = NSMakeRange(pos, range.location - pos);
		}
		
		[newString appendString:[self substringWithRange:substringRange]];
		
		if(endAfterInsert) break;
		
		// insert the replacement character
		[newString appendStringOrNil:string];
		
		// continue after the replaced characters
		range.location += range.length;
		range.length = len - range.location;
	}
	return newString;
}

/**
 * Returns the string by removing the characters in the supplied set and options.
 */
- (NSString *)stringByRemovingCharactersInSet:(NSCharacterSet *)charSet options:(NSUInteger)mask
{
	NSUInteger len = [self length];
	NSMutableString *newString = [NSMutableString string];
	
	mask &= ~NSBackwardsSearch;
	NSRange range = NSMakeRange (0, len);
	
	while (range.length)
	{
		NSRange substringRange;
		NSUInteger pos = range.location;
		
		range = [self rangeOfCharacterFromSet:charSet options:mask range:range];
		
		if (range.location == NSNotFound) {
			range = NSMakeRange (len, 0);
		}
		
		substringRange = NSMakeRange(pos, range.location - pos);
		
		[newString appendString:[self substringWithRange:substringRange]];
		
		range.location += range.length;
		range.length = len - range.location;
	}
	
	return newString;
}

/**
 * Convenience method to access the above method with no options.
 */
- (NSString *)stringByRemovingCharactersInSet:(NSCharacterSet *)charSet
{
	return [self stringByRemovingCharactersInSet:charSet options:0];
}

/**
 * Calculate the distance between two string case-insensitively.
 */
- (CGFloat)levenshteinDistanceWithWord:(NSString *)stringB
{
	// Normalize strings
	NSString * stringA = [NSString stringWithString: self];
	
	[stringA stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	[stringB stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	stringA = [stringA lowercaseString];
	stringB = [stringB lowercaseString];

	NSInteger k, i, j, cost, * d, distance;

	NSInteger n = [stringA length];
	NSInteger m = [stringB length];	

	if (n++ != 0 && m++ != 0) 
	{
		d = calloc(m * n, sizeof(NSInteger));

		for (k = 0; k < n; k++) 
		{
			d[k] = k;
		}

		for (k = 0; k < m; k++) {
			d[ k * n ] = k;	
		}

		for (i = 1; i < n; i++)
		for (j = 1; j < m; j++) 
		{
			cost = ([stringA characterAtIndex:i - 1] == [stringB characterAtIndex:j - 1]) ? 0 : 1;

			d[j * n + i] = 
			_smallestOf(d[(j - 1) * n + i] + 1,
			            d[j * n + i - 1] +  1,
			            d[(j - 1) * n + i -1] + cost);
		}

		distance = d[n * m - 1];

		free(d);

		return distance;
	}
	
	return 0.0f;
}

/**
 * Create the GeomFromText() string according to a possible SRID value
 */
- (NSString*)getGeomFromTextString
{
	NSString *geomStr = [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	if (![self rangeOfString:@")"].length || [self length] < 5) return @"NULL";

	// No SRID
	if ([geomStr hasSuffix:@")"]) {
		return [NSString stringWithFormat:@"GeomFromText('%@')", geomStr];
	}
	else {
		NSUInteger idx = [geomStr length] - 1;
		
		while (idx > 1) 
		{
			if ([geomStr characterAtIndex:idx] == ')') break;
			
			idx--;
		}
		
		return [NSString stringWithFormat:@"GeomFromText('%@'%@)", [geomStr substringToIndex:idx + 1], [geomStr substringFromIndex:idx + 1]];
	}
}

- (BOOL)nonConsecutivelySearchString:(NSString *)other matchingRanges:(NSArray **)submatches
{
	NSStringCompareOptions opts = NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch|NSWidthInsensitiveSearch;
	BOOL recordMatches = (submatches != NULL); //for readability
	NSRange selfRange = NSMakeRange(0, [self length]);
	
	//shortcut: * a longer string can never be contained in a shorter one.
	//          * nil can never match in a string.
	//          * an empty other can never match if self is non-empty
	if(([other length] > [self length]) || (!other) || ([self length] && ![other length]))
		return NO;
	
	//handle the simple case via the default algorithm
	if ([self compare:other options:opts] == NSOrderedSame) {
		if(recordMatches) {
			*submatches = [NSArray arrayWithObject:[NSValue valueWithRange:selfRange]];
		}
		return YES;
	}
	
	// for now let's save the overhead of NSArray and NSValues
	NSRange *tmpMatchStore = recordMatches? calloc([other length], sizeof(NSRange)) : NULL;
	__block NSUInteger matchCount = 0;
	__block NSRange searchRange = selfRange;
	
	//this looks a bit silly but is basically Apples approach to handling multibyte charsets
	void (^it)(NSString *,NSRange,NSRange,BOOL *) = ^(NSString *substring,NSRange substringRange,NSRange enclosingRange,BOOL *stop) {
		//look for the current character of other in the remaining part of self
		NSRange found = [self rangeOfString:substring options:opts range:searchRange];
		if(found.location == NSNotFound) {
			matchCount = 0; //reset match count to "no match"
			*stop = YES;
			return;
		}
		if(recordMatches)
			tmpMatchStore[matchCount] = found;
		matchCount++;
		//move the next search past the current match
		searchRange.location = NSMaxRange(found);
		searchRange.length   = [self length] - searchRange.location;
	};
	
	[other enumerateSubstringsInRange:NSMakeRange(0, [other length])
							  options:NSStringEnumerationByComposedCharacterSequences
						   usingBlock:it];
	
	if(matchCount && recordMatches) {
		//we want to re-combine sub-matches that are actually consecutive
		
		//This algorithm uses a simple look-behind for merges:
		//  Object 1 checks if it continues object 0. If so, 1 and 0 will merge
		//  and be placed in the slot of 0 (slot 1 is now invalid).
		//  Then object 2 checks if it continues object 0. If it does not, it is
		//  placed in slot 1.
		//  Object 3 then checks if it continues object 1 and so on...
		NSUInteger mergeTarget = 0;
		for (NSUInteger i = 1; i < matchCount; i++ ) {
			NSRange prev = tmpMatchStore[mergeTarget];
			NSRange this = tmpMatchStore[i];
			//if the previous match ends right before this match begins we can merge them
			if(NSMaxRange(prev) == this.location) {
				NSRange mergedRange = NSMakeRange(prev.location, prev.length+this.length);
				tmpMatchStore[mergeTarget] = mergedRange;
			}
			//otherwise we have to move on to the next and make ourselves the new base
			else {
				if(++mergeTarget != i)
					tmpMatchStore[mergeTarget] = this;
			}
		}
		matchCount = mergeTarget+1;
		
		//Next we want to merge non-adjacent matches that could be adjacent. Example:
		//  Haystack:    "central_private_rabbit_park"
		//  Needle:      "centralpark"
		//  Unoptimized: "central_private_rabbit_park"
		//                ^^^^^^^ ^   ^   ^         ^ = 5
		//  Desired:     "central_private_rabbit_park"
		//                ^^^^^^^                ^^^^ = 2
		//
		//  This time we start from the end (object K) and check if object K-1 can
		//  actually be placed directly in front of K and if so, merge them both into
		//  a new K-1 and shift down K+1 to K, K+2 to K+1, ...
		for (NSUInteger k = matchCount - 1; k > 0; k--) {
			NSRange my   = tmpMatchStore[k];
			NSRange prev = tmpMatchStore[k-1];
			NSString *prevMatch = [self substringWithRange:prev];
			NSRange left = NSMakeRange(my.location - prev.length, prev.length);
			NSString *myLeftSide = [self substringWithRange:left];
			if([prevMatch compare:myLeftSide options:opts] == NSOrderedSame) {
				//yay, let's merge them
				tmpMatchStore[k-1] = NSMakeRange(left.location, my.length+prev.length);
				//we now have to shift down k+1 to k, k+2 to k+1, ...
				for (NSUInteger n = k+1; n < matchCount; n++) {
					tmpMatchStore[n-1] = tmpMatchStore[n];
				}
				//merging means one match less in total
				matchCount--;
			}
		}
		
		NSMutableArray *combinedArray = [NSMutableArray arrayWithCapacity:matchCount];
		for (NSUInteger j = 0; j < matchCount; j++) {
			[combinedArray addObject:[NSValue valueWithRange:tmpMatchStore[j]]];
		}
		
		*submatches = combinedArray;
	}
	
	free(tmpMatchStore); // free(NULL) is safe as per OS X man page
	return (matchCount > 0);
}

@end

/**
 * Returns the minimum of a, b and c.
 */
static NSInteger _smallestOf(NSInteger a, NSInteger b, NSInteger c)
{
	NSInteger min = a;
	
	if (b < min) min = b;

	if (c < min) min = c;

	return min;
}

@implementation NSMutableString (SPStringAdditions)

- (void)setStringOrNil:(NSString *)aString
{
	[self setString:(aString? aString : @"")];
}

- (void)appendStringOrNil:(NSString *)aString
{
	[self appendString:(aString? aString : @"")];
}

@end
