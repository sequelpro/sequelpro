//
//  $Id$
//
//  MCPResult.h
//  MCPKit
//
//  Created by Serge Cohen (serge.cohen@m4x.org) on 08/12/2002.
//  Copyright (c) 2001 Serge Cohen. All rights reserved.
//
//  Forked by the Sequel Pro team (sequelpro.com), April 2009
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
//  More info at <http://mysql-cocoa.sourceforge.net/>
//  More info at <http://code.google.com/p/sequel-pro/>

#import <Foundation/Foundation.h>
#import "mysql.h"
#import "MCPConstants.h"

typedef struct st_our_charset
{
	unsigned int	nr;
	const char		*name;
	const char		*collation;
	unsigned int	char_minlen;
	unsigned int	char_maxlen;
} OUR_CHARSET;

@interface MCPResult : NSObject 
{
@protected
	MYSQL_RES		 *mResult;		 /* The MYSQL_RES structure of the C API. */
	NSArray			 *mNames;		 /* An NSArray holding the name of the columns. */
	NSDictionary	 *mMySQLLocales; /* A Locales dictionary to define the locales of MySQL. */
	NSStringEncoding mEncoding;		 /* The encoding used by MySQL server, to ISO-1 default. */
	unsigned int	 mNumOfFields;	 /* The number of fields in the result. */
	NSTimeZone		 *mTimeZone;	 /* The time zone of the connection when the query was made. */
}

/**
 * Initialization
 */
- (id)initWithMySQLPtr:(MYSQL *)mySQLPtr encoding:(NSStringEncoding)theEncoding timeZone:(NSTimeZone *)iTimeZone;
- (id)initWithResPtr:(MYSQL_RES *)mySQLResPtr encoding:(NSStringEncoding)theEncoding timeZone:(NSTimeZone *)iTimeZone;

/**
 * Result info
 */
- (my_ulonglong)numOfRows;
- (unsigned int)numOfFields;

/**
 * Rows
 */
- (void)dataSeek:(my_ulonglong) row;
- (id)fetchRowAsType:(MCPReturnType) aType;
- (NSArray *)fetchRowAsArray;
- (NSDictionary *)fetchRowAsDictionary;

/**
 * Columns
 */
- (NSArray *)fetchFieldNames;
- (id)fetchTypesAsType:(MCPReturnType)aType;
- (NSArray *)fetchTypesAsArray;
- (NSDictionary *)fetchTypesAsDictionary;
- (NSArray *)fetchResultFieldsStructure;

- (unsigned int)fetchFlagsAtIndex:(unsigned int)index;
- (unsigned int)fetchFlagsForKey:(NSString *)key;

- (BOOL)isBlobAtIndex:(unsigned int)index;
- (BOOL)isBlobForKey:(NSString *)key;

/**
 * Conversion
 */
- (NSString *)stringWithText:(NSData *)theTextData;
- (const char *)cStringFromString:(NSString *)theString;
- (NSString *)stringWithCString:(const char *)theCString;

/**
 * Other
 */
- (NSString *)mysqlTypeToStringForType:(unsigned int)type withCharsetNr:(unsigned int)charsetnr withFlags:(unsigned int)flags withLength:(unsigned long long)length;
- (NSString *)mysqlTypeToGroupForType:(unsigned int)type withCharsetNr:(unsigned int)charsetnr withFlags:(unsigned int)flags;
- (NSString *)find_charsetName:(unsigned int)charsetnr;
- (NSString *)find_charsetCollation:(unsigned int)charsetnr;
- (unsigned int)find_charsetMaxByteLengthPerChar:(unsigned int)charsetnr;

@end
