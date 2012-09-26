//
//  $Id: PGPostgresConnectionEncoding.m 3825 2012-09-09 00:43:58Z stuart02 $
//
//  PGPostgresConnectionEncoding.m
//  PostgresKit
//
//  Created by Stuart Connolly (stuconnolly.com) on August 4, 2012.
//  Copyright (c) 2012 Stuart Connolly. All rights reserved.
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

#import "PGPostgresConnectionEncoding.h"
#import "PGPostgresKitPrivateAPI.h"

@implementation PGPostgresConnection (PGPostgresConnectionEncoding)

/**
 * Set the current connection's encoding.
 *
 * @param encoding The name of the encoding to use.
 *
 * @return A BOOL indicating the success of the operation. NO means there was either no connection or the
 *         encoding name wasn't recognised by the server.
 */
- (BOOL)setEncoding:(NSString *)encoding
{
	if (![self isConnected]) return NO;
	
	if ([_encoding isEqualToString:encoding]) return YES;

	if (PQsetClientEncoding(_connection, [encoding UTF8String]) != 0) return NO;
	
	[_encoding release], _encoding = [[NSString alloc] initWithString:encoding];
	
	_stringEncoding = [PGPostgresConnection stringEncodingForPostgreSQLCharset:[encoding UTF8String]];
	
	return YES;
}

/**
 * Translates the supplied encoding name to it's corresponding string encoding identifier.
 *
 * @param charset The character set as a char array.
 *
 * @return The string encoding identifier. 
 */
+ (NSStringEncoding)stringEncodingForPostgreSQLCharset:(const char *)charset
{
	if (!strcmp(charset, "UNICODE") || !strcmp(charset, "MULE_INTERNAL")) {
		return NSUTF8StringEncoding;
	} 
	else if (!strcmp(charset, "LATIN1")) {
		return NSISOLatin1StringEncoding;
	} 
	else if (!strcmp(charset, "LATIN2")) {
		return NSISOLatin2StringEncoding;
	}
	else if (!strcmp(charset, "LATIN3")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatin3);
	}
	else if (!strcmp(charset, "LATIN4")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatin4);
	}
	else if (!strcmp(charset, "LATIN5")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatin5);
	}
	else if (!strcmp(charset, "LATIN6")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatin6);
	}
	else if (!strcmp(charset, "LATIN7")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatin7);
	}
	else if (!strcmp(charset, "LATIN8")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatin8);
	}
	else if (!strcmp(charset, "LATIN9")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatin9);
	}
	else if (!strcmp(charset, "LATIN10")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatin10);
	}
	else if (!strcmp(charset, "SQL_ASCII")) {
		return NSASCIIStringEncoding;
	}
	else if (!strcmp(charset, "EUC_JP")) {
		return NSJapaneseEUCStringEncoding;
	} 
	else if (!strcmp(charset, "EUC_CN")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_CN);
	} 
	else if (!strcmp(charset, "EUC_KR")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_KR);
	} 
	else if (!strcmp(charset, "JOHAB")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsKoreanJohab);
	}
	else if (!strcmp(charset, "EUC_TW")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_TW);
	}
	else if (!strcmp(charset, "ISO_8859_5")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinCyrillic);
	} 
	else if (!strcmp(charset, "ISO_8859_6")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinArabic);
	} 
	else if (!strcmp(charset, "ISO_8859_7")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinGreek);
	} 
	else if (!strcmp(charset, "ISO_8859_8")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinHebrew);
	} 
	else if (!strcmp(charset, "KOI8")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingKOI8_R);
	} 
	else if (!strcmp(charset, "ALT")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSRussian);
	}
	else if (!strcmp(charset, "WIN")) {
		return NSWindowsCP1251StringEncoding;
	}
	else if (!strcmp(charset, "WIN1256")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsArabic);
	}
	else if (!strcmp(charset, "TCVN")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsVietnamese);
	}
	else if (!strcmp(charset, "WIN874")) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSThai);
	}
	
	NSLog(@"PostgresKit: Warning: Unable to process unknown PostgreSQL encoding '%s'; falling back to UTF8.", charset);
	
	return PGPostgresConnectionDefaultStringEncoding;
}

/**
 * Translates the supplied encoding identifier to it's corresponding encoding name.
 *
 * @param stringEncoding The string encoding to translate
 *
 * @return The encoding name as a string or nil if there's no mapping.
 */
+ (NSString *)postgreSQLCharsetForStringEncoding:(NSStringEncoding)stringEncoding
{
	switch (stringEncoding) 
	{
		case NSASCIIStringEncoding:
			return @"SQL_ASCII";
			
		case NSJapaneseEUCStringEncoding:
			return @"EUC_JP";
			
		case NSUTF8StringEncoding:
		case NSNonLossyASCIIStringEncoding:
			return @"UNICODE";
			
		case NSISOLatin1StringEncoding:
		case NSWindowsCP1252StringEncoding:
			return @"LATIN1";
			
		case NSISOLatin2StringEncoding:
		case NSWindowsCP1250StringEncoding:
			return @"LATIN2";
			
		case NSWindowsCP1251StringEncoding:
			return @"WIN";
			
		case NSWindowsCP1253StringEncoding:
			return @"ISO_8859_7";
			
		case NSWindowsCP1254StringEncoding:
			return @"LATIN5";
	}
	
	return nil;
}

@end
