//
//  $Id$
//
//  SPStringAdditions.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Jan 28, 2009
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

#import <Cocoa/Cocoa.h>

/*
 * NSStringUTF8String(@"a String") function can be used to speed up
 * the convertion from a NSString to NSData or const char* resp.
 * NSData *d = [aStr UTF8String];  :== NSData *d = NSStringUTF8String(aStr);
 */
static inline const char* NSStringUTF8String(NSString* self) {
	typedef const char* (*SPUTF8StringMethodPtr)(NSString*, SEL);
	static SPUTF8StringMethodPtr SPNSStringGetUTF8String;
	if (!SPNSStringGetUTF8String) SPNSStringGetUTF8String = (SPUTF8StringMethodPtr)[NSString instanceMethodForSelector:@selector(UTF8String)];
	const char* to_return = SPNSStringGetUTF8String(self, @selector(UTF8String));
	return to_return;
}

@interface NSString (SPStringAdditions)

+ (NSString *)stringForByteSize:(int)byteSize;
+ (NSString *)stringForTimeInterval:(float)timeInterval;

- (NSString *)backtickQuotedString;
- (NSString *)tickQuotedString;
- (NSString *)replaceUnderscoreWithSpace;
- (NSArray *)lineRangesForRange:(NSRange)aRange;
- (NSString *)createViewSyntaxPrettifier;

- (NSString *)stringByRemovingCharactersInSet:(NSCharacterSet*) charSet options:(unsigned) mask;
- (NSString *)stringByRemovingCharactersInSet:(NSCharacterSet*) charSet;

- (float)levenshteinDistanceWithWord:(NSString *)stringB;

#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_5
	- (NSArray *)componentsSeparatedByCharactersInSet:(NSCharacterSet *)set;
#endif

@end
