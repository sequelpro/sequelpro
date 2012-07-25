//
//  $Id$
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
//  More info at <http://code.google.com/p/sequel-pro/>

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

- (CGFloat)levenshteinDistanceWithWord:(NSString *)stringB;

@end
