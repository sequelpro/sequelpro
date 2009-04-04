//
//  MCPResult.m
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
// $Id: MCPResult.m 348 2006-02-26 18:55:32Z serge $
// $Author: serge $


#import "MCPConnection.h"
#import "MCPNull.h"
#import "MCPNumber.h"

#import "MCPResult.h"

NSCalendarDate		*MCPYear0000;

@implementation MCPResult
/*"
!{ $Id: MCPResult.m 348 2006-02-26 18:55:32Z serge $ }
 
 Hold the results of a query to a MySQL database server. It correspond to the MYSQL_RES structure of the C API, and to the statement handle of the PERL DBI/DBD.
 
 Uses the !{mysql_store_result()} function from the C API. 
 
 This object is generated only by a MCPConnection object, in this way (see #{MCPConnection} documentation):
 
 !{
	 MCPConnection	*theConnec = [MCPConnection alloc];
	 MCPResult	*theRes;
	 NSDictionary	*theDict;
	 NSArray		*theColNames;
	 int		i, j;
	 
	 theConnec = [theConnec initToHost:@"albert.com" withLogin:@"toto" password:@"albert" usingPort:0];
	 [theConnec selectDB:@"db1"];
	 theRes = [theConnec queryString:@"select * from table1"];
	 theColNames = [theRes fetchFiedlsName];
	 i = 0;
	 while (theDict = [theRes fetchRowAsDictionary]){
		 NSLog(@"Row : %d\n", i);
		 for (j=0; j<[theColNames count]; j++) {
			 NSLog(@"  Field : %@, contain : %@\n", [theColNames objectAtIndex:j], [theDict objectForKey:[theColNames objectAtIndex:j]]);
		 }
		 i++;
	 }
 }
 
 "*/

+ (void) initialize
	/*"
	Initialize the class version to 3.0.1
	 "*/
{
	if (self = [MCPResult class]) {
		[self setVersion:030001]; // Ma.Mi.Re -> MaMiRe
		MCPYear0000 = [[NSCalendarDate dateWithTimeIntervalSinceReferenceDate:-63146822400.0] retain];
		[MCPYear0000 setCalendarFormat:@"%Y"];
	}
	return;
}


- (id) initWithMySQLPtr:(MYSQL *) mySQLPtr encoding:(NSStringEncoding) iEncoding timeZone:(NSTimeZone *) iTimeZone
/*"
initialise a MCPResult, it is used internally by MCPConnection !{queryString:} method: the only proper way to get a running MCPResult object.
"*/
{
	self = [super init];
	mEncoding = iEncoding;
	mTimeZone = [iTimeZone retain];
	if (mResult) {
		mysql_free_result(mResult);
		mResult = NULL;
	}
	if (mNames) {
		[mNames release];
		mNames = NULL;
	}
	mResult = mysql_store_result(mySQLPtr);
	if (mResult) {
		mNumOfFields = mysql_num_fields(mResult);
	}
	else {
		mNumOfFields = 0;
	}
	/*
	 if (mResult == NULL) {
		 [self autorelease];
		 return nil;
	 }
	 */
	if (mMySQLLocales == NULL) {
		mMySQLLocales = [[MCPConnection getMySQLLocales] retain];
	}
	return self;
}


- (id) initWithResPtr:(MYSQL_RES *) mySQLResPtr encoding:(NSStringEncoding) iEncoding timeZone:(NSTimeZone *) iTimeZone
/*"
This metod is used internally by MCPConnection object when it have already a MYSQL_RES object to initialise MCPResult object.
Initialise a MCPResult with the MYSQL_RES pointer (returned by such a function as mysql_list_dbs).
NB: MCPResult should be made by using one of the method of MCPConnection.
"*/
{
	self = [super init];
	mEncoding = iEncoding;
	mTimeZone = [iTimeZone retain];
	if (mResult) {
		mysql_free_result(mResult);
		mResult = NULL;
	}
	if (mNames) {
		[mNames release];
		mNames = NULL;
	}
	mResult = mySQLResPtr;
	if (mResult) {
		mNumOfFields = mysql_num_fields(mResult);
	}
	else {
		mNumOfFields = 0;
	}
	/*
	 if (mResult == NULL) {
		 [self autorelease];
		 return nil;
    }
	 */
	if (mMySQLLocales == NULL) {
		mMySQLLocales = [[MCPConnection getMySQLLocales] retain];
	}
	return self;    
}

- (id) init
	/*"
	Empty init, normaly of NO use to the user, again, MCPResult should be made through calls to MCPConnection
	 "*/
{
	self = [super init];
	mEncoding = [MCPConnection defaultMySQLEncoding];
	if (mResult) {
		mysql_free_result(mResult);
		mResult = NULL;
	}
	if (mNames) {
		[mNames release];
		mNames = NULL;
	}
	if (mMySQLLocales == NULL) {
		mMySQLLocales = [[MCPConnection getMySQLLocales] retain];
	}
	mNumOfFields = 0;
	return self;    
}


- (my_ulonglong) numOfRows
	/*"
	Return the number of rows selected by the query.
	 "*/
{
	if (mResult) {
		return mysql_num_rows(mResult);
	}
	return 0;
}


- (unsigned int) numOfFields
	/*"
	Return the number of fields selected by the query. As a side effect it forces an update of the number of fields.
	 "*/
{
	if (mResult) {
		return mNumOfFields = mysql_num_fields(mResult);
	}
	return mNumOfFields = 0;
}


- (void) dataSeek:(my_ulonglong) row
	/*"
	Go to a precise row in the selected result. 0 is the very first row
	 "*/
{
	my_ulonglong	theRow = (row < 0)? 0 : row;
	theRow = (theRow < [self numOfRows])? theRow : ([self numOfRows]-1);
	mysql_data_seek(mResult,theRow);
	return;
}


- (id) fetchRowAsType:(MCPReturnType) aType
	/*"
	Return the next row of the result as a collection of type defined by aType (namely MCPTypeArray or MCPTypeDictionary). Each field of the row is made into a proper object to hold the info (NSNumber -indeed MCPNumber, to keep signedness-, NSString...).
	 
	 This method returned directly the #{mutable} object generated while going through all the columns
	 "*/
{
	MYSQL_ROW			theRow;
	unsigned long		*theLengths;
	MYSQL_FIELD		*theField;
	int					i;
	id					theReturn;
	
	if (mResult == NULL) {
// If there is no results, returns nil, as after the last row...
		return nil;
	}
	
	theRow = mysql_fetch_row(mResult);
	if (theRow == NULL) {
		return nil;
	}
	
	switch (aType) {
		case MCPTypeArray:
			theReturn = [NSMutableArray arrayWithCapacity:mNumOfFields];
			break;
		case MCPTypeDictionary:
			if (mNames == nil) {
				[self fetchFieldNames];
			}
			theReturn = [NSMutableDictionary dictionaryWithCapacity:mNumOfFields];
			break;
		default :
			NSLog (@"Unknown type : %d, will return an Array!\n", aType);
			theReturn = [NSMutableArray arrayWithCapacity:mNumOfFields];
			break;
	}
	
	theLengths = mysql_fetch_lengths(mResult);
	theField = mysql_fetch_fields(mResult);
	for (i=0; i<mNumOfFields; i++) {
		id	theCurrentObj;
		
		if (theRow[i] == NULL) {
			theCurrentObj = [NSNull null];
		}
		else {
			char	*theData = calloc(sizeof(char),theLengths[i]+1);
//			   char  *theUselLess;
			memcpy(theData, theRow[i],theLengths[i]);
			theData[theLengths[i]] = '\0';
			
			switch (theField[i].type) {
				case FIELD_TYPE_TINY:
				case FIELD_TYPE_SHORT:
				case FIELD_TYPE_INT24:
				case FIELD_TYPE_LONG:
					theCurrentObj = (theField[i].flags & UNSIGNED_FLAG) ? [MCPNumber numberWithUnsignedLong:strtoul(theData, NULL, 0)] : [MCPNumber numberWithLong:strtol(theData, NULL, 0)];
					/*
					 if (theField[i].flags & UNSIGNED_FLAG) { // Signed integer (32b or less)
						 theCurrentObj = [NSNumber numberWithUnsignedLong:strtoul(theData, NULL, 0)];
					 }
					 else { // Signed integer (32b or less)
							  //                       theCurrentObj = [NSNumber numberWithLong:atol(theData)];
						 theCurrentObj = [NSNumber numberWithLong:strtol(theData, NULL, 0)];
					 }
#warning Should check for UNSIGNED (using theField[i].flag UNSIGNED_FLAG)
					 */
					break;
				case FIELD_TYPE_LONGLONG:
					theCurrentObj = (theField[i].flags & UNSIGNED_FLAG) ? [MCPNumber numberWithUnsignedLongLong:strtoull(theData, NULL, 0)] : [MCPNumber numberWithLongLong:strtoll(theData, NULL, 0)];
					/*
					 theCurrentObj = [NSNumber numberWithLongLong:strtoq(theData, &theUselLess, 0)];
#warning Should check for UNSIGNED (using theField[i].flag UNSIGNED_FLAG)
					 */
					break;
				case FIELD_TYPE_DECIMAL:
					theCurrentObj = [NSDecimalNumber decimalNumberWithString:[self stringWithCString:theData]];
					break;
				case FIELD_TYPE_FLOAT:
					theCurrentObj = [MCPNumber numberWithFloat:atof(theData)];
					break;
				case FIELD_TYPE_DOUBLE:
					theCurrentObj = [MCPNumber numberWithDouble:atof(theData)];
					break;
				case FIELD_TYPE_TIMESTAMP:
// Indeed one should check which format it is (14,12...2) and get the corresponding format string
// a switch on theLength[i] would do that...
// Here it will crash if it's not default presentation : TIMESTAMP(14)
					theCurrentObj = [NSCalendarDate dateWithString:[NSString stringWithFormat:@"%@ %@",[self stringWithCString:theData], [mTimeZone name]] calendarFormat:@"%Y-%m-%d %H:%M:%S %Z"];
					[theCurrentObj setCalendarFormat:@"%Y-%m-%d %H:%M:%S"];
					break;
				case FIELD_TYPE_DATE:
					theCurrentObj = [NSCalendarDate dateWithString:[NSString stringWithCString:theData] calendarFormat:@"%Y-%m-%d"];
					[theCurrentObj setCalendarFormat:@"%Y-%m-%d"];
					break;
				case FIELD_TYPE_TIME:
// Pass them back as string for the moment... no TIME object in Cocoa (so far)
					theCurrentObj = [NSString stringWithUTF8String:theData];
					break;
				case FIELD_TYPE_DATETIME:
					theCurrentObj = [NSCalendarDate dateWithString:[NSString stringWithCString:theData] calendarFormat:@"%Y-%m-%d %H:%M:%S"];
					[theCurrentObj setCalendarFormat:@"%Y-%m-%d %H:%M:%S"];
					break;
				case FIELD_TYPE_YEAR:
					theCurrentObj = [NSCalendarDate dateWithString:[NSString stringWithCString:theData] calendarFormat:@"%Y"];
					[theCurrentObj setCalendarFormat:@"%Y"];
// MySQL is not able to save years before 1900, and then gives a column of 0000, unfortunately, NSCalendarDate
//  doesn't accept the string @"0000" in the method datewithString: calendarFormat:@"%Y"...
					if (! theCurrentObj) {
						theCurrentObj = MCPYear0000;
					}
						break;
				case FIELD_TYPE_VAR_STRING:
				case FIELD_TYPE_STRING:
					theCurrentObj = [self stringWithCString:theData];
					break;
				case FIELD_TYPE_TINY_BLOB:
				case FIELD_TYPE_BLOB:
				case FIELD_TYPE_MEDIUM_BLOB:
				case FIELD_TYPE_LONG_BLOB:
					theCurrentObj = [NSData dataWithBytes:theData length:theLengths[i]];
					if (!(theField[i].flags & BINARY_FLAG)) { // It is TEXT and NOT BLOB...
						theCurrentObj = [self stringWithText:theCurrentObj];
					}
					break;
				case FIELD_TYPE_SET:
					theCurrentObj = [self stringWithCString:theData];
					break;
				case FIELD_TYPE_ENUM:
					theCurrentObj = [self stringWithCString:theData];
					break;
				case FIELD_TYPE_NULL:
				   theCurrentObj = [NSNull null];
					break;
				case FIELD_TYPE_NEWDATE:
// Don't know what the format for this type is...
					theCurrentObj = [self stringWithCString:theData];
					break;
				default:
					NSLog (@"in fetchRowAsDictionary : Unknown type : %d for column %d, send back a NSData object", (int)theField[i].type, (int)i);
					theCurrentObj = [NSData dataWithBytes:theData length:theLengths[i]];
					break;
			}
			free(theData);
// Some of the creators return nil object...
			if (theCurrentObj == nil) {
				theCurrentObj = [NSNull null];
			}
		}
		switch (aType) {
			case MCPTypeArray :
				[theReturn addObject:theCurrentObj];
				break;
			case MCPTypeDictionary :
				[theReturn setObject:theCurrentObj forKey:[mNames objectAtIndex:i]];
				break;
			default :
				[theReturn addObject:theCurrentObj];
				break;
		}
	}
	
	return theReturn;
}


- (NSArray *) fetchRowAsArray
	/*"
	Return the next row of the result as an array, the index in select field order, the object a proper object for handling the information in the field (NSString, NSNumber ...).
	 
	 Just a #{typed} wrapper for method !{fetchRosAsType:} (with arg MCPTypeArray).
	 
	 
	 NB: Returned object is immutable.
	 "*/
{
	NSMutableArray		*theArray = [self fetchRowAsType:MCPTypeArray];
	if (theArray) {
		return [NSArray arrayWithArray:theArray];
	}
	else {
		return nil;
	}
}


- (NSDictionary *) fetchRowAsDictionary
	/*"
	Return the next row of the result as a dictionary, the key being the field name, the object a proper object for handling the information in the field (NSString, NSNumber ...).
	 
	 Just a #{typed} wrapper for method !{fetchRosAsType:} (with arg MCPTypeDictionary).
	 
	 
	 NB: Returned object is immutable.
	 "*/
{
	NSMutableDictionary		*theDict = [self fetchRowAsType:MCPTypeDictionary];
	if (theDict) {
		return [NSDictionary dictionaryWithDictionary:theDict];
	}
	else {
		return nil;
	}
}


- (NSArray *) fetchFieldNames
/*" Generate the mNames if not already generated, and return it.

mNames is a NSArray holding the names of the fields(columns) of the results
"*/
{
	unsigned int		theNumFields;
	int				i;
	NSMutableArray		*theNamesArray;
	MYSQL_FIELD			*theField;
	
	if (mNames) {
		return mNames;
	}
	if (mResult == NULL) {
// If no results, give an empty array. Maybe it's better to give a nil pointer?
		return (mNames = [[NSArray array] retain]);
	}
	
	theNumFields = [self numOfFields];
	theNamesArray = [NSMutableArray arrayWithCapacity: theNumFields];
	theField = mysql_fetch_fields(mResult);    
	for (i=0; i<theNumFields; i++) {
		NSString	*theName = [self stringWithCString:theField[i].name];
		if ((theName) && (![theName isEqualToString:@""])) {
			[theNamesArray addObject:theName];
		}
		else {
			[theNamesArray addObject:[NSString stringWithFormat:@"Column %d", i]];
		}
	}
	
	return (mNames = [[NSArray arrayWithArray:theNamesArray] retain]);
}


- (id) fetchTypesAsType:(MCPReturnType) aType
/*" Return a collection of the fields's type. The type of collection is choosen by the aType variable (MCPTypeArray or MCPTypeDictionary).
	 
This method returned directly the #{mutable} object generated while going through all the columns
"*/
{
	int				i;
	id				theTypes;
	MYSQL_FIELD			*theField;
	
	if (mResult == NULL) {
// If no results, give an empty array. Maybe it's better to give a nil pointer?
		return nil;
	}
	
	switch (aType) {
		case MCPTypeArray:
			theTypes = [NSMutableArray arrayWithCapacity:mNumOfFields];
			break;
		case MCPTypeDictionary:
			if (mNames == nil) {
				[self fetchFieldNames];
			}
			theTypes = [NSMutableDictionary dictionaryWithCapacity:mNumOfFields];
			break;
		default :
			NSLog (@"Unknown type : %d, will return an Array!\n", aType);
			theTypes = [NSMutableArray arrayWithCapacity:mNumOfFields];
			break;
	}
	theField = mysql_fetch_fields(mResult);
	for (i=0; i<mNumOfFields; i++) {
		NSString	*theType;
		switch (theField[i].type) {
			case FIELD_TYPE_TINY:
				theType = @"tiny";
				break;
			case FIELD_TYPE_SHORT:
				theType = @"short";
				break;
			case FIELD_TYPE_LONG:
				theType = @"long";
				break;
			case FIELD_TYPE_INT24:
				theType = @"int24";
				break;
			case FIELD_TYPE_LONGLONG:
				theType = @"longlong";
				break;
			case FIELD_TYPE_DECIMAL:
				theType = @"decimal";
				break;
			case FIELD_TYPE_FLOAT:
				theType = @"float";
				break;
			case FIELD_TYPE_DOUBLE:
				theType = @"double";
				break;
			case FIELD_TYPE_TIMESTAMP:
				theType = @"timestamp";
				break;
			case FIELD_TYPE_DATE:
				theType = @"date";
				break;
			case FIELD_TYPE_TIME:
				theType = @"time";
				break;
			case FIELD_TYPE_DATETIME:
				theType = @"datetime";
				break;
			case FIELD_TYPE_YEAR:
				theType = @"year";
				break;
			case FIELD_TYPE_VAR_STRING:
				theType = @"varstring";
				break;
			case FIELD_TYPE_STRING:
				theType = @"string";
				break;
			case FIELD_TYPE_TINY_BLOB:
				theType = @"tinyblob";
				break;
			case FIELD_TYPE_BLOB:
				theType = @"blob";
				break;
			case FIELD_TYPE_MEDIUM_BLOB:
				theType = @"mediumblob";
				break;
			case FIELD_TYPE_LONG_BLOB:
				theType = @"longblob";
				break;
			case FIELD_TYPE_SET:
				theType = @"set";
				break;
			case FIELD_TYPE_ENUM:
				theType = @"enum";
				break;
			case FIELD_TYPE_NULL:
				theType = @"null";
				break;
			case FIELD_TYPE_NEWDATE:
				theType = @"newdate";
				break;
			default:
				theType = @"unknown";
				NSLog (@"in fetchTypesAsArray : Unknown type for column %d of the MCPResult, type = %d", (int)i, (int)theField[i].type);
				break;
		}
		switch (aType) {
			case MCPTypeArray :
				[theTypes addObject:theType];
				break;
			case MCPTypeDictionary :
				[theTypes setObject:theType forKey:[mNames objectAtIndex:i]];
				break;
			default :
				[theTypes addObject:theType];
				break;
		}
	}
	
	return theTypes;
}


- (NSArray *) fetchTypesAsArray
	/*"
	Return an array of the fields' types.
	 
	 NB: Returned object is immutable.
	 "*/
{
	NSMutableArray		*theArray = [self fetchTypesAsType:MCPTypeArray];
	if (theArray) {
		return [NSArray arrayWithArray:theArray];
	}
	else {
		return nil;
	}
}


- (NSDictionary*) fetchTypesAsDictionary
	/*"
	Return a dictionnary of the fields' types (keys are the fields' names).
	 
	 NB: Returned object is immutable.
	 "*/
{
	NSMutableDictionary		*theDict = [self fetchTypesAsType:MCPTypeDictionary];
		
	if (theDict) {
		return [NSDictionary dictionaryWithDictionary:theDict];
	}
	else {
		return nil;
	}
}


- (unsigned int) fetchFlagsAtIndex:(unsigned int) index
	/*" Return the MySQL flags of the column at the given index... Can be used to check if a number is signed or not...
	"*/
{
   unsigned int      theRet;
   unsigned int		theNumFields;
   MYSQL_FIELD			*theField;
   
   if (mResult == NULL) {
// If no results, give an empty array. Maybe it's better to give a nil pointer?
      return (0);
   }
   
   theNumFields = [self numOfFields];
   theField = mysql_fetch_fields(mResult);
   if (index >= theNumFields) {
// Out of range... should raise an exception
      theRet = 0;
   }
   else {
      theRet = theField[index].flags;
   }
   return theRet;
}

- (unsigned int) fetchFlagsForKey:(NSString *) key
{
   unsigned int      theRet;
   unsigned int		theNumFields, index;
   MYSQL_FIELD			*theField;
	
   if (mResult == NULL) {
// If no results, give an empty array. Maybe it's better to give a nil pointer?
      return (0);
   }
	
   if (mNames == NULL) {
      [self fetchFieldNames];
   }
	
   theNumFields = [self numOfFields];
   theField = mysql_fetch_fields(mResult);
   if ((index = [mNames indexOfObject:key]) == NSNotFound) {
// Non existent key... should raise an exception
      theRet = 0;
   }
   else {
      theRet = theField[index].flags;
   }
   return theRet;
}

- (BOOL) isBlobAtIndex:(unsigned int) index
	/*"
	Return YES if the field with the given index is a BLOB. It should be used to discriminates between BLOBs and TEXTs.
	 
#{DEPRECATED}, This method is not consistent with the C API which is supposed to return YES for BOTH text and blob (and BTW is also deprecated)...
	 
#{NOTE} That the current version handles properly TEXT, and returns those as NSString (and not NSData as it used to be).
	 "*/
{
	BOOL			theRet;
	unsigned int		theNumFields;
	MYSQL_FIELD			*theField;
	
	if (mResult == NULL) {
// If no results, give an empty array. Maybe it's better to give a nil pointer?
		return (NO);
	}
	
	theNumFields = [self numOfFields];
	theField = mysql_fetch_fields(mResult);
	if (index >= theNumFields) {
// Out of range... should raise an exception
		theRet = NO;
	}
	else {
		switch(theField[index].type) {
			case FIELD_TYPE_TINY_BLOB:
			case FIELD_TYPE_BLOB:
			case FIELD_TYPE_MEDIUM_BLOB:
			case FIELD_TYPE_LONG_BLOB:
//                theRet = YES;
				theRet = (theField[index].flags & BINARY_FLAG);
				break;
			default:
				theRet = NO;
				break;
		}
	}
	return theRet;
}

- (BOOL) isBlobForKey:(NSString *) key
	/*"
	Return YES if the field (by name) with the given index is a BLOB. It should be used to discriminates between BLOBs and TEXTs.
	 
#{DEPRECATED}, This method is not consistent with the C API which is supposed to return YES for BOTH text and blob (and BTW is also deprecated)...
	 
#{NOTE} That the current version handles properly TEXT, and returns those as NSString (and not NSData as it used to be).
	 "*/
{
	BOOL			theRet;
	unsigned int		theNumFields, index;
	MYSQL_FIELD			*theField;
	
	if (mResult == NULL) {
// If no results, give an empty array. Maybe it's better to give a nil pointer?
		return (NO);
	}
	
	if (mNames == NULL) {
		[self fetchFieldNames];
	}
	
	theNumFields = [self numOfFields];
	theField = mysql_fetch_fields(mResult);
	if ((index = [mNames indexOfObject:key]) == NSNotFound) {
// Non existent key... should raise an exception
		theRet = NO;
	}
	else {
		switch(theField[index].type) {
			case FIELD_TYPE_TINY_BLOB:
			case FIELD_TYPE_BLOB:
			case FIELD_TYPE_MEDIUM_BLOB:
			case FIELD_TYPE_LONG_BLOB:
//                theRet = YES;
				theRet = (theField[index].flags & BINARY_FLAG);
				break;
			default:
				theRet = NO;
				break;
		}
	}
	return theRet;
}


- (NSString *) stringWithText:(NSData *) theTextData
	/*"
	Use the string encoding to convert the returned NSData to a string (for a TEXT field)
	 "*/
{
	NSString		* theString;
	
	if (theTextData == nil) {
		return nil;
	}
	theString = [[NSString alloc] initWithData:theTextData encoding:mEncoding];
	if (theString) {
		[theString autorelease];
	}
	return theString;
}


- (NSString *) description
/*"
Return a (long) string containing the table of results, first line being the fields name, next line(s) the row(s). Useful to have NSLog logging a MCPResult (example).
"*/
{
	if (mResult == NULL) {
		return @"This is an empty MCPResult\n";
	}
	else {
		NSMutableString		*theString = [NSMutableString stringWithCapacity:0];
		int						i;
		NSArray					*theRow;
		MYSQL_ROW_OFFSET		thePosition;
		BOOL						trunc = [MCPConnection truncateLongField];
		
// First line, saying we are displaying a MCPResult
		[theString appendFormat:@"MCPResult: (encoding : %d, dim %d x %d)\n", (long)mEncoding, (long)mNumOfFields, (long)[self numOfRows]];
// Second line: the field names, tab separated
		[self fetchFieldNames];
		for (i=0; i<(mNumOfFields-1); i++) {
			[theString appendFormat:@"%@\t", [mNames objectAtIndex:i]];
		}
		[theString appendFormat:@"%@\n", [mNames objectAtIndex:i]];
// Next lines, the records (saving current position to put it back after the full display)
		thePosition = mysql_row_tell(mResult);
		[self dataSeek:0];
		while (theRow = [self fetchRowAsArray]) {
			id			theField = [theRow objectAtIndex:i];
			
			if (trunc) {
				if (([theField isKindOfClass:[NSString class]]) && (kLengthOfTruncationForLog < [(NSString *)theField length])) {
					theField = [theField substringToIndex:kLengthOfTruncationForLog];
				}
				else if (([theField isKindOfClass:[NSData class]]) && (kLengthOfTruncationForLog < [(NSData *)theField length])) {
					theField = [NSData dataWithBytes:[theField bytes] length:kLengthOfTruncationForLog];
				}
			}
				
			for (i=0; i<(mNumOfFields - 1); i++) {
				[theString appendFormat:@"%@\t", theField];
			}
			[theString appendFormat:@"%@\n", theField];
		}
// Returning to the proper row
		mysql_row_seek(mResult,thePosition);
		return theString;
	}
}


- (void) dealloc
	/*
	 Do one really needs an explanation for this method? Which by the way you should not use...
	 */
{
	if (mResult) {
		mysql_free_result(mResult);
	}
	if (mNames) {
		[mNames autorelease];
	}
	if (mMySQLLocales) {
		[mMySQLLocales autorelease];
	}
	
	[super dealloc];
	return;
}

- (const char *) cStringFromString:(NSString *) theString
	/*"
	For internal use only. Transform a NSString to a C type string (ended with \0) using ethe character set from the MCPConnection.
	 Lossy conversions are enabled.
	 "*/
{
	NSMutableData	*theData;
	
	if (! theString) {
		return (const char *)NULL;
	}
	
	theData = [NSMutableData dataWithData:[theString dataUsingEncoding:mEncoding allowLossyConversion:YES]];
	[theData increaseLengthBy:1];
	return (const char *)[theData bytes];
}


- (NSString *) stringWithCString:(const char *) theCString
	/*"
	Return a NSString from a C style string encoded with the character set of theMCPConnection.
	 "*/
{
	NSData		* theData;
	NSString		* theString;
	
	if (theCString == NULL) {
		return @"";
	}
	theData = [NSData dataWithBytes:theCString length:(strlen(theCString))];
	theString = [[NSString alloc] initWithData:theData encoding:mEncoding];
	if (theString) {
		[theString autorelease];
	}
	return theString;
}


@end
