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
//
//  More info at <https://github.com/sequelpro/sequelpro>

// This class is private to the framework.

#import "Conversion.h"

@implementation SPMySQLConnection (Conversion)

/**
 * Converts an NSString to a null-terminated C string, using the supplied encoding.
 * Uses lossy conversion, so if a string cannot be entirely converted using
 * the current encoding, a representation will be returned rather than null.
 * The returned cString will correctly preserve any nul characters within the string,
 * which prevents the use of faster functions like [NSString cStringUsingEncoding:].
 * Pass in the third parameter to receive the length of the converted string (INCLUDING
 * the terminating \0 character), or pass in NULL if you do not want this information.
 */
#warning This method doesn't make sense. It's only addition over [str dataUsingEncoding:allowLossyConversion:] is the terminating NUL byte. \
         But the "string" can already contain NUL bytes, so it's not a valid c string anyway.
+ (const char *)_cStringForString:(NSString *)aString usingEncoding:(NSStringEncoding)anEncoding returningLengthAs:(NSUInteger *)cStringLengthPointer
{

	// Don't try and convert nil strings
	if (!aString) return NULL;

	// Perform a lossy conversion, using NSData to do the hard work
	NSData *convertedData = [aString dataUsingEncoding:anEncoding allowLossyConversion:YES];
	NSUInteger convertedDataLength = [convertedData length];

	// Take the converted data - not null-terminated - and copy it to a null-terminated buffer
	char *cStringBytes = malloc(convertedDataLength + 1);
	memcpy(cStringBytes, [convertedData bytes], convertedDataLength);
	cStringBytes[convertedDataLength] = '\0';

	if (cStringLengthPointer) *cStringLengthPointer = convertedDataLength+1;

	// Ensure the memory is autoreleased when needed, and return.
	[NSData dataWithBytesNoCopy:cStringBytes length:convertedDataLength+1 freeWhenDone:YES]; 	
	return cStringBytes;
}

/**
 * Converts an NSString to a null-terminated C string, using the current
 * connection encoding.
 */
- (const char *)_cStringForString:(NSString *)aString
{

	// Use a cached reference to avoid dynamic method overhead
	return _cStringForStringWithEncoding(aString, stringEncoding, NULL);
}

/**
 * Converts a C string to an NSString using the current connection encoding.
 * This method *will not* correctly preserve nul characters within c strings; instead
 * the first nul character within the string will be treated as the line ending. This
 * is unavoidable without supplying a string length, so this method should not be widely
 * used for actual data conversion.
 */
- (NSString *)_stringForCString:(const char *)cString
{
	return _stringForCStringWithEncoding(cString, stringEncoding);
}

/**
 * @see _stringForCStringWithEncoding()
 */
+ (NSString *)_stringForCString:(const char *)cString usingEncoding:(NSStringEncoding)encoding
{
	return _stringForCStringWithEncoding(cString, encoding);
}

@end
