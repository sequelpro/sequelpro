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
#import "MCPConstants.h"

#import "mysql.h"

#define MAGIC_BINARY_CHARSET_NR 63

@interface MCPResult : NSObject 
{
	MYSQL_RES		 *mResult;		 /* The MYSQL_RES structure of the C API. */
	NSArray			 *mNames;		 /* An NSArray holding the name of the columns. */
	NSStringEncoding mEncoding;		 /* The encoding used by MySQL server, to ISO-1 default. */
	NSUInteger	 mNumOfFields;	 /* The number of fields in the result. */
	NSTimeZone		 *mTimeZone;	 /* The time zone of the connection when the query was made. */
}

// Initialization
- (id)initWithMySQLPtr:(MYSQL *)mySQLPtr encoding:(NSStringEncoding)theEncoding timeZone:(NSTimeZone *)iTimeZone;
- (id)initWithResPtr:(MYSQL_RES *)mySQLResPtr encoding:(NSStringEncoding)theEncoding timeZone:(NSTimeZone *)iTimeZone;

// Result info
- (my_ulonglong)numOfRows;
- (NSUInteger)numOfFields;

// Rows
- (void)dataSeek:(my_ulonglong)row;
- (id)fetchRowAsType:(MCPReturnType) aType;
- (NSArray *)fetchRowAsArray;
- (NSDictionary *)fetchRowAsDictionary;

// Columns
- (NSArray *)fetchFieldNames;
- (id)fetchTypesAsType:(MCPReturnType)aType;
- (NSArray *)fetchTypesAsArray;
- (NSDictionary *)fetchTypesAsDictionary;
- (NSArray *)fetchResultFieldsStructure;

- (NSUInteger)fetchFlagsAtIndex:(NSUInteger)index;
- (NSUInteger)fetchFlagsForKey:(NSString *)key;

- (BOOL)isBlobAtIndex:(NSUInteger)index;
- (BOOL)isBlobForKey:(NSString *)key;

// Conversion
- (NSString *)stringWithText:(NSData *)theTextData;
- (const char *)cStringFromString:(NSString *)theString;
- (NSString *)stringWithCString:(const char *)theCString;

// Other
- (NSString *)mysqlTypeToStringForType:(NSUInteger)type withCharsetNr:(NSUInteger)charsetnr withFlags:(NSUInteger)flags withLength:(unsigned long long)length;
- (NSString *)mysqlTypeToGroupForType:(NSUInteger)type withCharsetNr:(NSUInteger)charsetnr withFlags:(NSUInteger)flags;
- (NSString *)findCharsetName:(NSUInteger)charsetnr;
- (NSString *)findCharsetCollation:(NSUInteger)charsetnr;
- (NSUInteger)findCharsetMaxByteLengthPerChar:(NSUInteger)charsetnr;

@end
