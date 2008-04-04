//
//  CMMCPConnection.m
//  CocoaMySQL
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed Sept 21 2005.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
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
//  More info at <http://cocoamysql.sourceforge.net/>
//  Or mail to <lorenz@textor.ch>

#import "CMMCPConnection.h"


@implementation CMMCPConnection

/*
+ (NSStringEncoding) encodingForMySQLEncoding:(const char *) mysqlEncoding
	Gets a proper NSStringEncoding according to the given MySQL charset.
	 
	 MySQL 4.0 offers this charsets:
	 big5 cp1251 cp1257 croat czech danish dec8 dos estonia euc_kr gb2312 gbk german1 greek hebrew hp8 hungarian koi8_ru koi8_ukr latin1 latin1_de latin2 latin5 sjis swe7 tis620 ujis usa7 win1250 win1251ukr
	 
	 WARNING : incomplete implementation. Please, send your fixes.
{
// unicode
	if (!strncmp(mysqlEncoding, "utf8", 4)) {
		return NSUTF8StringEncoding;
	}
	if (!strncmp(mysqlEncoding, "ucs2", 4)) {
		return NSUnicodeStringEncoding;
	}
// west european
	if (!strncmp(mysqlEncoding, "ascii", 5)) {
		return NSASCIIStringEncoding;
	}
	if (!strncmp(mysqlEncoding, "latin1", 6)) {
		return NSISOLatin1StringEncoding;
	}
	if (!strncmp(mysqlEncoding, "macroman", 8)) {
		return NSMacOSRomanStringEncoding;
	}
// central european
	if (!strncmp(mysqlEncoding, "cp1250", 6)) {
		return NSWindowsCP1250StringEncoding;
	}
	if (!strncmp(mysqlEncoding, "latin2", 6)) {
		return NSISOLatin2StringEncoding;
	}
// south european and middle east
	if (!strncmp(mysqlEncoding, "cp1256", 6)) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsArabic);
	}
	if (!strncmp(mysqlEncoding, "greek", 5)) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinGreek);
	}
	if (!strncmp(mysqlEncoding, "hebrew", 6)) {
		CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinHebrew);
	}
	if (!strncmp(mysqlEncoding, "latin5", 6)) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatin5);
	}
// baltic
	if (!strncmp(mysqlEncoding, "cp1257", 6)) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsBalticRim);
	}
// cyrillic
	if (!strncmp(mysqlEncoding, "cp1251", 6)) {
		return NSWindowsCP1251StringEncoding;
	}
// asian
	if (!strncmp(mysqlEncoding, "big5", 4)) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5);
	}
	if (!strncmp(mysqlEncoding, "ujis", 4)) {
		return NSJapaneseEUCStringEncoding;
	}
	if (!strncmp(mysqlEncoding, "sjis", 4)) {
		return  NSShiftJISStringEncoding;
	}
	
// default to iso latin 1, even if it is not exact (throw an exception?)
	NSLog(@"warning: unknown encoding %s! falling back to latin1.", mysqlEncoding);
	return NSISOLatin1StringEncoding;
}
*/

- (CMMCPResult *) queryString:(NSString *) query
/*
modified version of queryString to be used in CocoaMySQL
*/
{
    CMMCPResult     *theResult;
    const char    *theCQuery = [self cStringFromString:query];
    int           theQueryCode;

//[DIFF]: check connection
    if ( ![self checkConnection] ) {
        NSLog(@"Connection was gone, but should be reestablished now!");
    }
//end [DIFF]

//[DIFF]: inform the delegate about the query
	if ( delegate && [delegate respondsToSelector:@selector(willQueryString:)] )
		[delegate willQueryString:query];
//end [DIFF]

	if (0 == (theQueryCode = mysql_query(mConnection, theCQuery))) {
		if (mysql_field_count(mConnection) != 0) {
//[DIFF]: use CMMCPResult instad of MCPResult
			theResult = [[CMMCPResult alloc] initWithMySQLPtr:mConnection encoding:mEncoding timeZone:mTimeZone];
//end [DIFF]
		}
		else {
			return nil;
		}
    }
    else {
//       NSLog (@"Problem in queryString error code is : %d, query is : %s -in ObjC : %@-\n", theQueryCode, theCQuery, query);
//       NSLog(@"Error message is : %@\n", [self getLastErrorMessage]);
//        theResult = [theResult init]; // Old version...
//       theResult = nil;
//[DIFF]: inform the delegate about errors
		if ( delegate && [delegate respondsToSelector:@selector(queryGaveError:)] )
			[delegate queryGaveError:[self getLastErrorMessage]];
//end [DIFF]
		return nil;
    }
	return [theResult autorelease];
}

- (void)setDelegate:(id)object
/*
sets the delegate
*/
{
    delegate = object;
}





- (NSTimeZone *) timeZone
/*" Getting the currently used time zone (in communication with the DB server). "*/
/* fixes mysql 4.1.14 problem, can be deleted as soon as fixed in the framework */
{
	if ([self checkConnection]) {
		MCPResult		*theSessionTZ = [self queryString:@"SHOW VARIABLES LIKE '%time_zone'"];
		NSArray			*theRow;
// diff
		id			theTZName;
// end diff
		NSTimeZone		*theTZ;
		
		[theSessionTZ dataSeek:1ULL];
		theRow = [theSessionTZ fetchRowAsArray];
		theTZName = [theRow objectAtIndex:1];
// diff
		if ( [theTZName isKindOfClass:[NSData class]] ) {
		// MySQL 4.1.14 returns the mysql variables as nsdata
			theTZName = [self stringWithText:theTZName];
		}
// end diff
		if ([theTZName isEqualToString:@"SYSTEM"]) {
			[theSessionTZ dataSeek:0ULL];
			theRow = [theSessionTZ fetchRowAsArray];
			theTZName = [theRow objectAtIndex:1];
// diff
			if ( [theTZName isKindOfClass:[NSData class]] ) {
			// MySQL 4.1.14 returns the mysql variables as nsdata
				theTZName = [self stringWithText:theTZName];
			}
// end diff
		}
		if (theTZName) { // Old versions of the server does not support there own time zone ?
			theTZ = [NSTimeZone timeZoneWithName:theTZName];
		}
		else { // By default set the time zone to the local one..
			// Try to get the name using the previously available variable:
//			NSLog(@"Fecthing time-zone on 'old' DB server : variable name is : timezone");
			theSessionTZ = [self queryString:@"SHOW VARIABLES LIKE 'timezone'"];
			[theSessionTZ dataSeek:0ULL];
			theRow = [theSessionTZ fetchRowAsArray];
			theTZName = [theRow objectAtIndex:1];
			if (theTZName) { // Finally we found one ...
//				NSLog(@"Result is : %@", theTZName);
				theTZ = [NSTimeZone timeZoneWithName:theTZName];
			}
			else {
				theTZ = [NSTimeZone defaultTimeZone];
//			theTZ = [NSTimeZone systemTimeZone];
				NSLog(@"The time zone is not defined on the server, set it to the default one : %@", theTZ);
			}
		}
		if (theTZ != mTimeZone) {
			[mTimeZone release];
			mTimeZone = [theTZ retain];
		}
	}
	return mTimeZone;
}





@end
