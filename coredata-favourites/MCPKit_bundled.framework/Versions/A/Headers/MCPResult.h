//
//  MCPResult.h
//  SMySQL
//
//  Created by serge cohen (serge.cohen@m4x.org) on Sat Dec 08 2001.
//  Copyright (c) 2001 Serge Cohen.
//
//  This code is free software; you can redistribute it and/or modify it under
//  the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or any later version.
//
//  This code is distributed in the hope that it will be useful, but WITHOUT ANY
//  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
//  details.
//
//  For a copy of the GNU General Public License, visit <http://www.gnu.org/> or
//  write to the Free Software Foundation, Inc., 59 Temple Place--Suite 330,
//  Boston, MA 02111-1307, USA.
//
//  More info at <http://mysql-cocoa.sourceforge.net/>
//
// $Id: MCPResult.h 335 2006-01-08 21:14:07Z serge $
// $Author: serge $


#import <Foundation/Foundation.h>
#import "mysql.h"
#import "MCPConstants.h"


@interface MCPResult : NSObject {
@protected
   MYSQL_RES			*mResult;		/*" The MYSQL_RES structure of the C API. "*/
	NSArray				*mNames;			/*" An NSArray holding the name of the columns. "*/
	NSDictionary		*mMySQLLocales;	/*" A Locales dictionary to define the locales of MySQL. "*/
	NSStringEncoding	mEncoding;		/*" The encoding used by MySQL server, to ISO-1 default. "*/
	unsigned int		mNumOfFields;	/*" The number of fields in the result. "*/
	NSTimeZone			*mTimeZone;		/*" The time zone of the connection when the query was made. "*/
}
/*"
Class maintenance
 "*/

+ (void) initialize;

	/*"
	Init used #{only} by #{MCPConnection} 
	 "*/

- (id) initWithMySQLPtr:(MYSQL *) mySQLPtr encoding:(NSStringEncoding) theEncoding timeZone:(NSTimeZone *) iTimeZone;
- (id) initWithResPtr:(MYSQL_RES *) mySQLResPtr encoding:(NSStringEncoding) theEncoding timeZone:(NSTimeZone *) iTimeZone;
- (id) init;

	/*"
	General info on the result
	 "*/

- (my_ulonglong) numOfRows;
- (unsigned int) numOfFields;

	/*"
	Getting the rows
	 "*/

- (void) dataSeek:(my_ulonglong) row;

- (id) fetchRowAsType:(MCPReturnType) aType;
- (NSArray *) fetchRowAsArray;
- (NSDictionary *) fetchRowAsDictionary;

	/*"
	Getting information on columns
	 "*/

- (NSArray *) fetchFieldNames;

- (id) fetchTypesAsType:(MCPReturnType) aType;
- (NSArray *) fetchTypesAsArray;
- (NSDictionary *) fetchTypesAsDictionary;

- (unsigned int) fetchFlagsAtIndex:(unsigned int) index;
- (unsigned int) fetchFlagsForKey:(NSString *) key;

- (BOOL) isBlobAtIndex:(unsigned int) index;
- (BOOL) isBlobForKey:(NSString *) key;

	/*"
	Text data convertion to string
	 "*/
- (NSString *) stringWithText:(NSData *) theTextData;

	/*"
	Utility method
	 "*/
- (NSString *) description;

	/*"
	End of the scope...
	 "*/

- (void) dealloc;

	/*"
	Private methods, internal use only
	 "*/
- (const char *) cStringFromString:(NSString *) theString;
- (NSString *) stringWithCString:(const char *) theCString;

@end
