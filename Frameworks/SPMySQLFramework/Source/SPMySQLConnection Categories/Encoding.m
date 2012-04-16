//
//  $Id$
//
//  Encoding.m
//  SPMySQLFramework
//
//  Created by Rowan Beentje (rowan.beent.je) on January 14, 2012
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
//  More info at <http://code.google.com/p/sequel-pro/>


#import "Encoding.h"
#import "SPMySQLStringAdditions.h"

@implementation SPMySQLConnection (Encoding)

#pragma mark -
#pragma mark Current connection encoding information

/**
 * Returns the name of the current encoding - the MySQL character set - in
 * use by the connection.
 */
- (NSString *)encoding
{
	return [NSString stringWithString:encoding];
}

/**
 * Returns the NSStringEncoding currently in use by the connection to process
 * queries and results.
 */
- (NSStringEncoding)stringEncoding
{
	return stringEncoding;
}

/**
 * Returns whether the connection is set to use Latin1 transport for queries and
 * results.
 * Latin1 transport is a compatibility mode in place for compatibility with older
 * incorrect setups, where databases and clients might both be set to use UTF8 (or
 * other encodings) for storing and retrieving data, but the MySQL link was never
 * set to UTF8 mode; as a result, multibyte characters where split by the connection
 * into pairs of characters, resulting in malformed storage.  The data works
 * correctly if written and read in the same way, so this mode allows correct display
 * of that data.
 */
- (BOOL)encodingUsesLatin1Transport
{
	return encodingUsesLatin1Transport;
}

#pragma mark -
#pragma mark Setting connection encoding

/**
 * Set the name of the encoding - the MySQL character set - that the connection
 * should use.  If an encoding not recognised by the server is supplied, NO is
 * returned.
 * Calling this resets whether the connection should use Latin1 transport to NO.
 */
- (BOOL)setEncoding:(NSString *)theEncoding
{

	// MySQL versions prior to 4.1 don't support encoding changes; return NO on those
	// versions.
	if (![self serverVersionIsGreaterThanOrEqualTo:4 minorVersion:1 releaseVersion:0]) {
		return NO;
	}

	// If the supplied encoding is already set, return success
	if ([encoding isEqualToString:theEncoding] && !encodingUsesLatin1Transport) {
		return YES;
	}

	// Run a query to set the connection encoding
	[self queryString:[NSString stringWithFormat:@"SET NAMES %@", [theEncoding mySQLTickQuotedString]]];

	// If the query errored, no encoding change occurred - return failure.
	if ([self queryErrored]) return NO;

	// Connection encoding was successfully set, update the instance settings,
	// and return success.
	[encoding release];
	encoding = [[NSString alloc] initWithString:theEncoding];
	stringEncoding = [SPMySQLConnection stringEncodingForMySQLCharset:[theEncoding UTF8String]];
	encodingUsesLatin1Transport = NO;

	return YES;
}

/**
 * Sets the connection to use Latin1 transport for queries and results or not.  All
 * encodings will default to not use Latin1 transport..
 * Latin1 transport is a compatibility mode in place for compatibility with older
 * incorrect setups, where databases and clients might both be set to use UTF8 (or
 * other encodings) for storing and retrieving data, but the MySQL link was never
 * set to UTF8 mode; as a result, multibyte characters where split by the connection
 * into pairs of characters, resulting in malformed storage.  The data works
 * correctly if written and read in the same way, so this mode allows correct display
 * of that data.
 */
- (BOOL)setEncodingUsesLatin1Transport:(BOOL)useLatin1
{

	// MySQL versions prior to 4.1 don't support encoding changes; return NO on those
	// versions.
	if (![self serverVersionIsGreaterThanOrEqualTo:4 minorVersion:1 releaseVersion:0]) {
		return NO;
	}

	// If the Latin1 mode is already set, return success
	if (encodingUsesLatin1Transport == useLatin1) {
		return YES;
	}

	// If disabling Latin1 transport, just restore the connection encoding
	if (!useLatin1) {
		return [self setEncoding:encoding];
	}

	// Otherwise attempt to set Latin1 transport.  First, the result set encoding.
	[self queryString:@"SET CHARACTER_SET_RESULTS=latin1"];

	// If that failed, no encoding change occurred - return failure.
	if ([self queryErrored]) return NO;

	// Next, change the client character set, to also amend queries sent.
	[self queryString:@"SET CHARACTER_SET_CLIENT=latin1"];

	// If that failed, encoding details are in a partial state - attempt to restore
	// the original details before returning failure.
	if ([self queryErrored]) {
		[self setEncoding:encoding];
		return NO;
	}

	// Connecting encoding transport was successfully set, update the instance settings,
	// and return success.
	encodingUsesLatin1Transport = YES;
	return YES;
}

#pragma mark -
#pragma mark Encoding storage and restoration


/**
 * Store a previous encoding setting, to allow it to be easily restored
 * later - used when the encoding needs to be temporarily changed.
 */
- (void)storeEncodingForRestoration
{
	if (previousEncoding) [previousEncoding release];
	previousEncoding = [[NSString alloc] initWithString:encoding];
	previousEncodingUsesLatin1Transport = encodingUsesLatin1Transport;
}

/**
 * Restore a previously stored encoding setting, if available.  Used in
 * conjunection with -storeEncodingForRestoration for when the encoding needs
 * to be temporarily changed.
 */
- (void)restoreStoredEncoding
{
	if (!previousEncoding || state == SPMySQLDisconnected || state == SPMySQLDisconnecting) {
		return;
	}

	[self setEncoding:previousEncoding];
	[self setEncodingUsesLatin1Transport:previousEncodingUsesLatin1Transport];
}

#pragma mark -
#pragma mark Encoding conversion

/**
 * Map MySQL encodings to NSStringEncodings, using the list of encodings sourced
 * from http://dev.mysql.com/doc/refman/5.6/en/charset-charsets.html and the same
 * list on previous MySQL versions.  Older versions also had less-standard lists,
 * such as the charset options listed on
 * http://dev.mysql.com/doc/refman/4.1/en/charset-map.html .
 * For each, the equivalent NSStringEncoding, or conversion from CfStringEncoding,
 * was found.
 * If a supplied character set can not be matched, logs an error and falls back
 * to UTF8 encoding.
 */
+ (NSStringEncoding)stringEncodingForMySQLCharset:(const char *)mysqlCharset
{

	// Handle the most common cases first
	if (!strcmp(mysqlCharset, "utf8")) {
		return NSUTF8StringEncoding;
	} else if (!strcmp(mysqlCharset, "latin1")) {
		return NSISOLatin1StringEncoding;
	} else if (!strcmp(mysqlCharset, "ascii")) {
		return NSASCIIStringEncoding;

	// Work down the rest of the 4.1+ charsets
	} else if (!strcmp(mysqlCharset, "big5")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5);
	} else if (!strcmp(mysqlCharset, "dec8")) {
		return NSISOLatin1StringEncoding;	// Not exact, but very close
	} else if (!strcmp(mysqlCharset, "cp850")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSLatin1);
	} else if (!strcmp(mysqlCharset, "koi8r")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingKOI8_R);
	} else if (!strcmp(mysqlCharset, "latin2")) {
		return NSISOLatin2StringEncoding;
	} else if (!strcmp(mysqlCharset, "ujis")) {
		return NSJapaneseEUCStringEncoding;
	} else if (!strcmp(mysqlCharset, "sjis")) {
		return NSShiftJISStringEncoding;
	} else if (!strcmp(mysqlCharset, "hebrew")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinHebrew);
	} else if (!strcmp(mysqlCharset, "tis620")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinThai);
	} else if (!strcmp(mysqlCharset, "euckr")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_KR);
	} else if (!strcmp(mysqlCharset, "koi8u")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingKOI8_U);
	} else if (!strcmp(mysqlCharset, "gb2312")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_2312_80);
	} else if (!strcmp(mysqlCharset, "greek")) {
		return NSWindowsCP1253StringEncoding;
	} else if (!strcmp(mysqlCharset, "cp1250")) {
		return NSWindowsCP1250StringEncoding;
	} else if (!strcmp(mysqlCharset, "gbk")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGBK_95);
	} else if (!strcmp(mysqlCharset, "latin5")) {
		return NSWindowsCP1254StringEncoding;
	} else if (!strcmp(mysqlCharset, "ucs2")) {
		return NSUnicodeStringEncoding;
	} else if (!strcmp(mysqlCharset, "cp866")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSRussian);
	} else if (!strcmp(mysqlCharset, "macce")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacCentralEurRoman);
	} else if (!strcmp(mysqlCharset, "macroman")) {
		return NSMacOSRomanStringEncoding;
	} else if (!strcmp(mysqlCharset, "cp852")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSLatin2);
	} else if (!strcmp(mysqlCharset, "latin7")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatin7);
	} else if (!strcmp(mysqlCharset, "utf8mb4")) {
		return NSUnicodeStringEncoding;	// Is this correct?
	} else if (!strcmp(mysqlCharset, "cp1251")) {
		return NSWindowsCP1251StringEncoding;
	} else if (!strcmp(mysqlCharset, "utf16")) {
		return NSUnicodeStringEncoding;
	} else if (!strcmp(mysqlCharset, "utf16le")) {
		return NSUTF16LittleEndianStringEncoding;
	} else if (!strcmp(mysqlCharset, "cp1256")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsArabic);
	} else if (!strcmp(mysqlCharset, "cp1257")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsBalticRim);
	} else if (!strcmp(mysqlCharset, "utf32")) {
		return NSUTF32StringEncoding;
	} else if (!strcmp(mysqlCharset, "binary")) {
		return NSUTF8StringEncoding;
	} else if (!strcmp(mysqlCharset, "cp932")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSJapanese);
	} else if (!strcmp(mysqlCharset, "eucjpms")) {
		return NSJapaneseEUCStringEncoding;

	// Continue with old < 4.1 mappings
	} else if (!strcmp(mysqlCharset, "czech")) {
		return NSISOLatin2StringEncoding;
	} else if (!strcmp(mysqlCharset, "dos")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSLatin1);
	} else if (!strcmp(mysqlCharset, "german1")) {
		return NSISOLatin1StringEncoding;
	} else if (!strcmp(mysqlCharset, "usa7")) {
		return NSASCIIStringEncoding;
	} else if (!strcmp(mysqlCharset, "danish")) {
		return NSISOLatin1StringEncoding;
	} else if (!strcmp(mysqlCharset, "win1251")) {
		return NSWindowsCP1251StringEncoding;
	} else if (!strcmp(mysqlCharset, "euc_kr")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_KR);
	} else if (!strcmp(mysqlCharset, "estonia")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatin7);
	} else if (!strcmp(mysqlCharset, "hungarian")) {
		return NSISOLatin2StringEncoding;
	} else if (!strcmp(mysqlCharset, "koi8_ru")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingKOI8_R);
	} else if (!strcmp(mysqlCharset, "koi8_ukr")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingKOI8_U);
	} else if (!strcmp(mysqlCharset, "win1251ukr")) {
		return NSWindowsCP1251StringEncoding;
	} else if (!strcmp(mysqlCharset, "win1250")) {
		return NSWindowsCP1250StringEncoding;
	} else if (!strcmp(mysqlCharset, "croat")) {
		return NSISOLatin2StringEncoding;
	} else if (!strcmp(mysqlCharset, "latin1_de")) {
		return NSISOLatin1StringEncoding;
	}

	/**
	 * Finally, certain other encodings, including the following:
	 *   hp8
	 *   swe7
	 *   armscii8
	 *   keybcs2
	 *   geostd8
	 * ...don't appear to have OS X equivalents; for these and unhandled, log and
	 * fall back to UTF8 handling.
	 */
	NSLog(@"SPMySQL Framework has encountered the MySQL encoding '%s' which it is unable to process correctly; falling back to UTF8 mapping.", mysqlCharset);
	return NSUTF8StringEncoding;
}

/**
 * Match a supplied NSStringEncoding to a MySQL character set, returning the MySQL
 * name of that character set as an NSString.
 * If the supplied NSStringEncoding could not be matched, logs an error and returns nil.
 */
+ (NSString *)mySQLCharsetForStringEncoding:(NSStringEncoding)aStringEncoding
{

	// Switch through the list of NSStringEncodings from NSString, returning the most
	// appropriate encoding for each
	switch (aStringEncoding) {

		case NSASCIIStringEncoding:
			return @"ascii";

		case NSJapaneseEUCStringEncoding:
			return @"ujis";

		case NSUTF8StringEncoding:
			return @"utf8";

		case NSISOLatin1StringEncoding:
			return @"latin1";

		case NSNonLossyASCIIStringEncoding:
			return @"utf8";

		case NSShiftJISStringEncoding:
			return @"sjis";

		case NSISOLatin2StringEncoding:
			return @"latin2";

		case NSUnicodeStringEncoding:
			return @"ucs2";

		case NSWindowsCP1251StringEncoding:
			return @"cp1251";

		case NSWindowsCP1252StringEncoding:
			return @"latin1";

		case NSWindowsCP1253StringEncoding:
			return @"greek";

		case NSWindowsCP1254StringEncoding:
			return @"latin5";

		case NSWindowsCP1250StringEncoding:
			return @"cp1250";

		case NSMacOSRomanStringEncoding:
			return @"macroman";

		case NSUTF16BigEndianStringEncoding:
			return @"utf16";

		case NSUTF16LittleEndianStringEncoding:
			return @"utf16le";

		case NSUTF32StringEncoding:
			return @"utf32";

		case NSUTF32BigEndianStringEncoding:
			return @"utf32";
	}

	/**
	 * Certain string encodings, including the following:
	 *   NSNEXTSTEPStringEncoding
	 *   NSSymbolStringEncoding
	 *   NSISO2022JPStringEncoding
	 *   NSUTF32LittleEndianStringEncoding
	 *   
	 * ...don't have equivalents; similarly, many CFStringEncodings aren't yet
	 * matched.  For those, log and return nil.
	 */
	NSLog(@"SPMySQL Framework was asked for the MySQL charset for the string encoding '%llu', which is currently unhandled.", (unsigned long long)aStringEncoding);
	return nil;
}
@end