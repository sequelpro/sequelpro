//
//  SPStringAdditions.h
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

/**
 * NSStringUTF8String(@"a String") function can be used to speed up
 * the convertion from a NSString to NSData or const char* resp.
 * NSData *d = [aStr UTF8String];  :== NSData *d = NSStringUTF8String(aStr);
 */
static inline const char *NSStringUTF8String(NSString *self) 
{
	typedef const char* (*SPUTF8StringMethodPtr)(NSString*, SEL);
	static SPUTF8StringMethodPtr SPNSStringGetUTF8String;
	if (!SPNSStringGetUTF8String) SPNSStringGetUTF8String = (SPUTF8StringMethodPtr)[NSString instanceMethodForSelector:@selector(UTF8String)];
	const char* to_return = SPNSStringGetUTF8String(self, @selector(UTF8String));
	return to_return;
}

static inline void NSMutableAttributedStringAddAttributeValueRange(NSMutableAttributedString *self, NSString *aStr, id aValue, NSRange aRange) 
{
	typedef void (*SPMutableAttributedStringAddAttributeValueRangeMethodPtr)(NSMutableAttributedString*, SEL, NSString*, id, NSRange);
	static SPMutableAttributedStringAddAttributeValueRangeMethodPtr SPMutableAttributedStringAddAttributeValueRange;
	if (!SPMutableAttributedStringAddAttributeValueRange) SPMutableAttributedStringAddAttributeValueRange = (SPMutableAttributedStringAddAttributeValueRangeMethodPtr)[self methodForSelector:@selector(addAttribute:value:range:)];
	SPMutableAttributedStringAddAttributeValueRange(self, @selector(addAttribute:value:range:), aStr, aValue, aRange);
	return;
}

static inline id NSMutableAttributedStringAttributeAtIndex(NSMutableAttributedString *self, NSString *aStr, NSUInteger anIndex, NSRangePointer aRange) 
{
	typedef id (*SPMutableAttributedStringAttributeAtIndexMethodPtr)(NSMutableAttributedString*, SEL, NSString*, NSUInteger, NSRangePointer);
	static SPMutableAttributedStringAttributeAtIndexMethodPtr SPMutableAttributedStringAttributeAtIndex;
	if (!SPMutableAttributedStringAttributeAtIndex) SPMutableAttributedStringAttributeAtIndex = (SPMutableAttributedStringAttributeAtIndexMethodPtr)[self methodForSelector:@selector(attribute:atIndex:effectiveRange:)];
	id r = SPMutableAttributedStringAttributeAtIndex(self, @selector(attribute:atIndex:effectiveRange:), aStr, anIndex, aRange);
	return r;
}

@interface NSString (SPStringAdditions)

+ (NSString *)stringForByteSize:(long long)byteSize;
+ (NSString *)stringForTimeInterval:(double)timeInterval;
+ (NSString *)stringWithNewUUID;

- (NSString *)rot13;
- (NSString *)HTMLEscapeString;
- (NSString *)backtickQuotedString;
- (NSString *)tickQuotedString;
- (NSString *)replaceUnderscoreWithSpace;
- (NSArray *)lineRangesForRange:(NSRange)aRange;
- (NSString *)createViewSyntaxPrettifier;

- (NSString *)getGeomFromTextString;

- (NSString *)stringByRemovingCharactersInSet:(NSCharacterSet *)charSet;
- (NSString *)stringByRemovingCharactersInSet:(NSCharacterSet *)charSet options:(NSUInteger)mask;
/**
 * Replace all occurances of any character in set with the replacement string
 * @param set    Characters to look for (MUST NOT be nil)
 * @param string A replacement string (can be nil == empty string)
 * @return A string with replacements applied
 */
- (NSString *)stringByReplacingCharactersInSet:(NSCharacterSet *)set withString:(NSString *)string;

- (CGFloat)levenshteinDistanceWithWord:(NSString *)stringB;

/**
 * Checks if the string other is contained in self on a per-character basis.
 * In regex-speak that would mean "abc" is matched as /a.*b.*c/ (not anchored).
 * This is a SEARCH function, NOT a MATCHING function! 
 * Namely the following options will be applied when matching: 
 *   NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch|NSWidthInsensitiveSearch
 * Additionaly this method might match even when it should not.
 * A regular substring test is always included. Therefore looking e.g. for "abc" in
 * "axbxabc" would match as (axbx,"abc") and NOT as ("a",x,"b",xab,"c").
 * Partial submatches will likewise be optimized to return as few matches as possible.
 * E.g. ".123" in "a._1_12_123" will return (a,".",_1_12_,"123") NOT (a,".",_,"1",_1,"2",_12,"3")
 *
 * @param other      String to match against self
 * @param submatches Pass the pointer to a variable that will be set to an NSArray *
 *                   of NSValue *s of NSRanges. This will only be the case if
 *                   the method also returns YES. The variable will not be modified
 *                   otherwise.
 *                   Pass NULL if you don't care for the ranges.
 *                   The object will be set to autorelase.
 * @return YES if self contains all characters from other in the order given in other
 * @warning This method is NOT thread-safe (probably), NOT constant-time and DOES NOT check binary equivalence
 */
- (BOOL)nonConsecutivelySearchString:(NSString *)other matchingRanges:(NSArray **)submatches;
@end

@interface NSMutableString (SPStringAdditions)
/**
 * nil-safe variant of setString:
 * nil will be interpreted as @"" instead of throwing an exception
 */
- (void)setStringOrNil:(NSString *)aString;

/**
 * nil-safe variant of appendString: 
 * nil will be interpreted as @"" instead of throwing an exception
 */
- (void)appendStringOrNil:(NSString *)aString;
@end
