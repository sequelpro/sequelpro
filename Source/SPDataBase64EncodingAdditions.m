//
//  SPMutableArrayAdditions.m
//  sequel-pro
//
//  Created by Rowan Beentje on March 18, 2012.
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

#import "SPDataBase64EncodingAdditions.h"

static const char _base64EncodingTable[64] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

@implementation NSData (SPDataBase64EncodingAdditions)

/**
 * Returns a base64-encoded representation of the NSData as an NSString,
 * on a single line.
 */
- (NSString *)base64Encoding
{
	return [self base64EncodingWithLineLength:NSNotFound];
}

/**
 * Returns a base64-encoded representation of the NSData as an NSString.
 * Takes an argument for the maximum output line length; supply 0 or NSNotFound
 * to have the results on a single line.
 *
 * Derived from the MIT-licensed Quasidea Development QSUtilities implementation,
 * available in its original form at https://github.com/mikeho/QSUtilities ;
 * QSUtilities implementation author Mike Ho, Copyright (c) 2010 - 2011
 * Quasidea Development, LLC .
 *
 * That implementation is itself an implementation ported from the PHP core;
 * the PHP implementation is covered by the PHP license, a BSD-alike which
 * is available at http://www.php.net/license/3_01.txt .
 * PHP implementation author Jim Winstead <jimw@php.net>, Copyright (c) 1997-2012
 * The PHP Group.
 */
- (NSString *)base64EncodingWithLineLength:(NSUInteger)lineLength
{
	const unsigned char *objRawData = [self bytes];
	char *objPointer;
	char *strResult;

	// Line length details - record bool and tweak to account for 3-octet processing
	BOOL hasMaxLineLength = (lineLength && lineLength != NSNotFound);
	NSUInteger maxLineLengthChunks = hasMaxLineLength ? floorf(lineLength / 4) : 1;
	if (!maxLineLengthChunks) maxLineLengthChunks++;

	// Get the Raw Data length and ensure we actually have data
	size_t intLength = [self length];
	if (intLength == 0) return nil;

	// Setup the String-based result placeholder and pointer within that placeholder
	size_t encodedLength = ceilf((intLength + 2) / 3) * 4;
	if (hasMaxLineLength) encodedLength += ceilf(encodedLength / (maxLineLengthChunks * 4)) - 1;
	strResult = (char *)calloc(encodedLength, sizeof(char));
	objPointer = strResult;

	// Iterate through everything
	NSUInteger octetsOnLine = 0;
	
	while (intLength > 2) 
	{ // keep going until we have less than 24 bits
		*objPointer++ = _base64EncodingTable[objRawData[0] >> 2];
		*objPointer++ = _base64EncodingTable[((objRawData[0] & 0x03) << 4) + (objRawData[1] >> 4)];
		*objPointer++ = _base64EncodingTable[((objRawData[1] & 0x0f) << 2) + (objRawData[2] >> 6)];
		*objPointer++ = _base64EncodingTable[objRawData[2] & 0x3f];

		// we just handled 3 octets (24 bits) of data
		objRawData += 3;
		intLength -= 3;

		if (hasMaxLineLength) {
			octetsOnLine++;
			if (octetsOnLine >= maxLineLengthChunks) {
				*objPointer++ = '\n';
				octetsOnLine = 0;
			}
		}
	}

	// now deal with the tail end of things
	if (intLength != 0) {
		*objPointer++ = _base64EncodingTable[objRawData[0] >> 2];
		if (intLength > 1) {
			*objPointer++ = _base64EncodingTable[((objRawData[0] & 0x03) << 4) + (objRawData[1] >> 4)];
			*objPointer++ = _base64EncodingTable[(objRawData[1] & 0x0f) << 2];
			*objPointer++ = '=';
		} 
		else {
			*objPointer++ = _base64EncodingTable[(objRawData[0] & 0x03) << 4];
			*objPointer++ = '=';
			*objPointer++ = '=';
		}
	}

	NSString *strToReturn = [[NSString alloc] initWithBytesNoCopy:strResult length:objPointer - strResult encoding:NSASCIIStringEncoding freeWhenDone:YES];
	
	return [strToReturn autorelease];
}

@end
