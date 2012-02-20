//
//  $Id$
//
//  Encoding.m
//  SPMySQLFramework
//
//  Created by Rowan Beentje (rowan.beent.je) on January 22, 2012
//  Copyright (c) 2012 Rowan Beentje. All rights reserved.
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
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

// This class is private to the framework.

@interface SPMySQLConnection (Conversion)

+ (const char *)_cStringForString:(NSString *)aString usingEncoding:(NSStringEncoding)anEncoding returningLengthAs:(NSUInteger *)cStringLengthPointer;

- (const char *)_cStringForString:(NSString *)aString;
- (NSString *)_stringForCString:(const char *)cString;

@end


/**
 * Set up a static function to allow fast calling with cached selectors
 */
static inline const char* _cStringForStringWithEncoding(NSString* aString, NSStringEncoding anEncoding, NSUInteger *cStringLengthPointer) 
{
	static Class cachedClass;
	static IMP cachedMethodPointer;
	static SEL cachedSelector;

	if (!cachedClass) cachedClass = [SPMySQLConnection class];
	if (!cachedSelector) cachedSelector = @selector(_cStringForString:usingEncoding:returningLengthAs:);
	if (!cachedMethodPointer) cachedMethodPointer = [SPMySQLConnection methodForSelector:cachedSelector];

	return (const char *)(*cachedMethodPointer)(cachedClass, cachedSelector, aString, anEncoding, cStringLengthPointer);
}
