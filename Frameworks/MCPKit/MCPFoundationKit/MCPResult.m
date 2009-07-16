//
//  $Id$
//
//  MCPResult.m
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

#import "MCPConnection.h"
#import "MCPNull.h"
#import "MCPNumber.h"
#import "MCPResult.h"

NSCalendarDate *MCPYear0000;

const OUR_CHARSET our_charsets60[] =
{
	{1,   "big5","big5_chinese_ci", 1, 2},
	{3,   "dec8", "dec8_swedisch_ci", 1, 1},
	{4,   "cp850", "cp850_general_ci", 1, 1},
	{6,   "hp8", "hp8_english_ci", 1, 1},
	{7,   "koi8r", "koi8r_general_ci", 1, 1},
	{8,   "latin1", "latin1_swedish_ci", 1, 1},
	{9,   "latin2", "latin2_general_ci", 1, 1},
	{10,  "swe7", "swe7_swedish_ci", 1, 1},
	{11,  "ascii", "ascii_general_ci", 1, 1},
	{12,  "ujis", "ujis_japanese_ci", 1, 3},
	{13,  "sjis", "sjis_japanese_ci", 1, 2},
	{16,  "hebrew", "hebrew_general_ci", 1, 1},
	{18,  "tis620", "tis620_thai_ci", 1, 1},
	{19,  "euckr", "euckr_korean_ci", 1, 2},
	{22,  "koi8u", "koi8u_general_ci", 1, 1},
	{24,  "gb2312", "gb2312_chinese_ci", 1, 2},
	{25,  "greek", "greek_general_ci", 1, 1},
	{26,  "cp1250", "cp1250_general_ci", 1, 1},
	{28,  "gbk", "gbk_chinese_ci", 1, 2},
	{30,  "latin5", "latin5_turkish_ci", 1, 1},
	{32,  "armscii8", "armscii8_general_ci", 1, 1},
	{33,  "utf8", "utf8_general_ci", 1, 3},
	{35,  "ucs2", "ucs2_general_ci", 2, 2},
	{36,  "cp866", "cp866_general_ci", 1, 1},
	{37,  "keybcs2", "keybcs2_general_ci", 1, 1},
	{38,  "macce", "macce_general_ci", 1, 1},
	{39,  "macroman", "macroman_general_ci", 1, 1},
	{40,  "cp852", "cp852_general_ci", 1, 1},
	{41,  "latin7", "latin7_general_ci", 1, 1},
	{51,  "cp1251", "cp1251_general_ci", 1, 1},
	{57,  "cp1256", "cp1256_general_ci", 1, 1},
	{59,  "cp1257", "cp1257_general_ci", 1, 1},
	{63,  "binary", "binary", 1, 1},
	{92,  "geostd8", "geostd8_general_ci", 1, 1},
	{95,  "cp932", "cp932_japanese_ci", 1, 2},
	{97,  "eucjpms", "eucjpms_japanese_ci", 1, 3},
	{2,   "latin2", "latin2_czech_cs", 1, 1},
	{5,   "latin1", "latin1_german_ci", 1, 1},
	{14,  "cp1251", "cp1251_bulgarian_ci", 1, 1},
	{15,  "latin1", "latin1_danish_ci", 1, 1},
	{17,  "filename", "filename", 1, 5},
	{20,  "latin7", "latin7_estonian_cs", 1, 1},
	{21,  "latin2", "latin2_hungarian_ci", 1, 1},
	{23,  "cp1251", "cp1251_ukrainian_ci", 1, 1},
	{27,  "latin2", "latin2_croatian_ci", 1, 1},
	{29,  "cp1257", "cp1257_lithunian_ci", 1, 1},
	{31,  "latin1", "latin1_german2_ci", 1, 1},
	{34,  "cp1250", "cp1250_czech_cs", 1, 1},
	{42,  "latin7", "latin7_general_cs", 1, 1},
	{43,  "macce", "macce_bin", 1, 1},
	{44,  "cp1250", "cp1250_croatian_ci", 1, 1},
	{45,  "utf8", "utf8_general_ci", 1, 1},
	{46,  "utf8", "utf8_bin", 1, 1},
	{47,  "latin1", "latin1_bin", 1, 1},
	{48,  "latin1", "latin1_general_ci", 1, 1},
	{49,  "latin1", "latin1_general_cs", 1, 1},
	{50,  "cp1251", "cp1251_bin", 1, 1},
	{52,  "cp1251", "cp1251_general_cs", 1, 1},
	{53,  "macroman", "macroman_bin", 1, 1},
	{58,  "cp1257", "cp1257_bin", 1, 1},
	{60,  "armascii8", "armascii8_bin", 1, 1},
	{65,  "ascii", "ascii_bin", 1, 1},
	{66,  "cp1250", "cp1250_bin", 1, 1},
	{67,  "cp1256", "cp1256_bin", 1, 1},
	{68,  "cp866", "cp866_bin", 1, 1},
	{69,  "dec8", "dec8_bin", 1, 1},
	{70,  "greek", "greek_bin", 1, 1},
	{71,  "hebew", "hebrew_bin", 1, 1},
	{72,  "hp8", "hp8_bin", 1, 1},
	{73,  "keybcs2", "keybcs2_bin", 1, 1},
	{74,  "koi8r", "koi8r_bin", 1, 1},
	{75,  "koi8u", "koi8u_bin", 1, 1},
	{77,  "latin2", "latin2_bin", 1, 1},
	{78,  "latin5", "latin5_bin", 1, 1},
	{79,  "latin7", "latin7_bin", 1, 1},
	{80,  "cp850", "cp850_bin", 1, 1},
	{81,  "cp852", "cp852_bin", 1, 1},
	{82,  "swe7", "swe7_bin", 1, 1},
	{93,  "geostd8", "geostd8_bin", 1, 1},
	{83,  "utf8", "utf8_bin", 1, 3},
	{84,  "big5", "big5_bin", 1, 2},
	{85,  "euckr", "euckr_bin", 1, 2},
	{86,  "gb2312", "gb2312_bin", 1, 2},
	{87,  "gbk", "gbk_bin", 1, 2},
	{88,  "sjis", "sjis_bin", 1, 2},
	{89,  "tis620", "tis620_bin", 1, 1},
	{90,  "ucs2", "ucs2_bin", 2, 2},
	{91,  "ujis", "ujis_bin", 1, 3},
	{94,  "latin1", "latin1_spanish_ci", 1, 1},
	{96,  "cp932", "cp932_bin", 1, 2},
	{99,  "cp1250", "cp1250_polish_ci", 1, 1},
	{98,  "eucjpms", "eucjpms_bin", 1, 3},
	{128, "ucs2", "ucs2_unicode_ci", 2, 2},
	{129, "ucs2", "ucs2_icelandic_ci", 2, 2},
	{130, "ucs2", "ucs2_latvian_ci", 2, 2},
	{131, "ucs2", "ucs2_romanian_ci", 2, 2},
	{132, "ucs2", "ucs2_slovenian_ci", 2, 2},
	{133, "ucs2", "ucs2_polish_ci", 2, 2},
	{134, "ucs2", "ucs2_estonian_ci", 2, 2},
	{135, "ucs2", "ucs2_spanish_ci", 2, 2},
	{136, "ucs2", "ucs2_swedish_ci", 2, 2},
	{137, "ucs2", "ucs2_turkish_ci", 2, 2},
	{138, "ucs2", "ucs2_czech_ci", 2, 2},
	{139, "ucs2", "ucs2_danish_ci", 2, 2},
	{140, "ucs2", "ucs2_lithunian_ci", 2, 2},
	{141, "ucs2", "ucs2_slovak_ci", 2, 2},
	{142, "ucs2", "ucs2_spanish2_ci", 2, 2},
	{143, "ucs2", "ucs2_roman_ci", 2, 2},
	{144, "ucs2", "ucs2_persian_ci", 2, 2},
	{145, "ucs2", "ucs2_esperanto_ci", 2, 2},
	{146, "ucs2", "ucs2_hungarian_ci", 2, 2},
	{147, "ucs2", "ucs2_sinhala_ci", 2, 2},
	{192, "utf8mb3", "utf8mb3_general_ci", 1, 3},
	{193, "utf8mb3", "utf8mb3_icelandic_ci", 1, 3},
	{194, "utf8mb3", "utf8mb3_latvian_ci", 1, 3},
	{195, "utf8mb3", "utf8mb3_romanian_ci", 1, 3},
	{196, "utf8mb3", "utf8mb3_slovenian_ci", 1, 3},
	{197, "utf8mb3", "utf8mb3_polish_ci", 1, 3},
	{198, "utf8mb3", "utf8mb3_estonian_ci", 1, 3},
	{119, "utf8mb3", "utf8mb3_spanish_ci", 1, 3},
	{200, "utf8mb3", "utf8mb3_swedish_ci", 1, 3},
	{201, "utf8mb3", "utf8mb3_turkish_ci", 1, 3},
	{202, "utf8mb3", "utf8mb3_czech_ci", 1, 3},
	{203, "utf8mb3", "utf8mb3_danish_ci", 1, 3},
	{204, "utf8mb3", "utf8mb3_lithunian_ci", 1, 3},
	{205, "utf8mb3", "utf8mb3_slovak_ci", 1, 3},
	{206, "utf8mb3", "utf8mb3_spanish2_ci", 1, 3},
	{207, "utf8mb3", "utf8mb3_roman_ci", 1, 3},
	{208, "utf8mb3", "utf8mb3_persian_ci", 1, 3},
	{209, "utf8mb3", "utf8mb3_esperanto_ci", 1, 3},
	{210, "utf8mb3", "utf8mb3_hungarian_ci", 1, 3},
	{211, "utf8mb3", "utf8mb3_sinhala_ci", 1, 3},
	{224, "utf8", "utf8_unicode_ci", 1, 3},
	{225, "utf8", "utf8_icelandic_ci", 1, 3},
	{226, "utf8", "utf8_latvian_ci", 1, 3},
	{227, "utf8", "utf8_romanian_ci", 1, 3},
	{228, "utf8", "utf8_slovenian_ci", 1, 3},
	{229, "utf8", "utf8_polish_ci", 1, 3},
	{230, "utf8", "utf8_estonian_ci", 1, 3},
	{231, "utf8", "utf8_spanish_ci", 1, 3},
	{232, "utf8", "utf8_swedish_ci", 1, 3},
	{233, "utf8", "utf8_turkish_ci", 1, 3},
	{234, "utf8", "utf8_czech_ci", 1, 3},
	{235, "utf8", "utf8_danish_ci", 1, 3},
	{236, "utf8", "utf8_lithuanian_ci", 1, 3},
	{237, "utf8", "utf8_slovak_ci", 1, 3},
	{238, "utf8", "utf8_spanish2_ci", 1, 3},
	{239, "utf8", "utf8_roman_ci", 1, 3},
	{240, "utf8", "utf8_persian_ci", 1, 3},
	{241, "utf8", "utf8_esperanto_ci", 1, 3},
	{242, "utf8", "utf8_hungarian_ci", 1, 3},
	{243, "utf8", "utf8_sinhala_ci", 1, 3},
	{254, "utf8mb3", "utf8mb3_general_cs", 1, 3},
	{0, NULL, NULL, 0, 0}
};

@implementation MCPResult

/**
 * Hold the results of a query to a MySQL database server. It correspond to the MYSQL_RES structure of the C API, and to the statement handle of the PERL DBI/DBD.
 *
 * Uses the !{mysql_store_result()} function from the C API. 
 *
 * This object is generated only by a MCPConnection object, in this way (see #{MCPConnection} documentation):
 *
 *	 MCPConnection *theConnec = [MCPConnection alloc];
 *	 MCPResult *theRes;
 *	 NSDictionary *theDict; 
 *	 NSArray *theColNames; 
 *	 int i, j; 
 *	 
 *	 theConnec = [theConnec initToHost:@"albert.com" withLogin:@"toto" password:@"albert" usingPort:0]; 
 *	 [theConnec selectDB:@"db1"];
 *	 theRes = [theConnec queryString:@"select * from table1"];
 *	 theColNames = [theRes fetchFiedlsName];
 *	 i = 0;
 *
 * 	 while (theDict = [theRes fetchRowAsDictionary]) {
 *		 NSLog(@"Row : %d\n", i); 
 *		 for (j=0; j<[theColNames count]; j++) {
 *			 NSLog(@"  Field : %@, contain : %@\n", [theColNames objectAtIndex:j], [theDict objectForKey:[theColNames objectAtIndex:j]]);
 * 		 }
 *		 i++; 
 *	 }
 */

/**
 * Initialize the class version to 3.0.1
 */
+ (void)initialize
{
	if (self = [MCPResult class]) {
		[self setVersion:030001]; // Ma.Mi.Re -> MaMiRe
		MCPYear0000 = [[NSCalendarDate dateWithTimeIntervalSinceReferenceDate:-63146822400.0] retain];
		[MCPYear0000 setCalendarFormat:@"%Y"];
	}
}

#pragma mark -
#pragma mark Initialisation

/**
 * Empty init, normaly of NO use to the user, again, MCPResult should be made through calls to MCPConnection
 */
- (id)init
{
	if ((self = [super init])) {
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
	}
	
	return self;    
}

/**
 * Initialise a MCPResult, it is used internally by MCPConnection !{queryString:} method: the only proper 
 * way to get a running MCPResult object.
 */
- (id)initWithMySQLPtr:(MYSQL *)mySQLPtr encoding:(NSStringEncoding)iEncoding timeZone:(NSTimeZone *)iTimeZone
{
	if ((self = [super init])) {
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
		
		if (mMySQLLocales == NULL) {
			mMySQLLocales = [[MCPConnection getMySQLLocales] retain];
		}
	}
	
	return self;
}

/**
 * This metod is used internally by MCPConnection object when it have already a MYSQL_RES object to initialise 
 * MCPResult object. Initialise a MCPResult with the MYSQL_RES pointer (returned by such a function as mysql_list_dbs).
 * NB: MCPResult should be made by using one of the method of MCPConnection.
 */
- (id)initWithResPtr:(MYSQL_RES *)mySQLResPtr encoding:(NSStringEncoding)iEncoding timeZone:(NSTimeZone *)iTimeZone
{
	if ((self = [super init])) {
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

		if (mMySQLLocales == NULL) {
			mMySQLLocales = [[MCPConnection getMySQLLocales] retain];
		}
	}
	
	return self;    
}

#pragma mark -
#pragma mark Result info

/**
 * Return the number of rows selected by the query.
 */
- (my_ulonglong)numOfRows
{
	if (mResult) {
		return mysql_num_rows(mResult);
	}
	
	return 0;
}

/**
 * Return the number of fields selected by the query. As a side effect it forces an update of the number of fields.
 */
- (unsigned int)numOfFields
{
	if (mResult) {
		return mNumOfFields = mysql_num_fields(mResult);
	}
	
	return mNumOfFields = 0;
}

#pragma mark -
#pragma mark Rows

/**
 * Go to a precise row in the selected result. 0 is the very first row.
 */
- (void)dataSeek:(my_ulonglong)row
{
	my_ulonglong theRow = (row < 0)? 0 : row;
	theRow = (theRow < [self numOfRows]) ? theRow : ([self numOfRows] - 1);
	mysql_data_seek(mResult,theRow);
}

/**
 *
 */
- (id)fetchRowAsType:(MCPReturnType)aType
{
	MYSQL_ROW		theRow;
	unsigned long	*theLengths;
	MYSQL_FIELD		*theField;
	int				i;
	id				theReturn;
	
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
		} else {
			char *theData = calloc(sizeof(char),theLengths[i]+1);
			//char *theUselLess;
			memcpy(theData, theRow[i],theLengths[i]);
			theData[theLengths[i]] = '\0';
			
			switch (theField[i].type) {
				case FIELD_TYPE_TINY:
				case FIELD_TYPE_SHORT:
				case FIELD_TYPE_INT24:
				case FIELD_TYPE_LONG:
				case FIELD_TYPE_LONGLONG:
				case FIELD_TYPE_DECIMAL:
				case FIELD_TYPE_FLOAT:
				case FIELD_TYPE_DOUBLE:
				case FIELD_TYPE_TIMESTAMP:
				case FIELD_TYPE_DATE:
				case FIELD_TYPE_TIME:
				case FIELD_TYPE_DATETIME:
				case FIELD_TYPE_YEAR:
				case FIELD_TYPE_VAR_STRING:
				case FIELD_TYPE_STRING:
				case FIELD_TYPE_SET:
				case FIELD_TYPE_ENUM:
				case FIELD_TYPE_NEWDATE: // Don't know what the format for this type is...
					theCurrentObj = [self stringWithCString:theData];
					break;
					
				case FIELD_TYPE_BIT:
					theCurrentObj = [NSString stringWithFormat:@"%u", theData[0]];
					break;
					
				case FIELD_TYPE_TINY_BLOB:
				case FIELD_TYPE_BLOB:
				case FIELD_TYPE_MEDIUM_BLOB:
				case FIELD_TYPE_LONG_BLOB:
					theCurrentObj = [NSData dataWithBytes:theData length:theLengths[i]];
					if (!(theField[i].flags & BINARY_FLAG)) { // It is TEXT and NOT BLOB...
						theCurrentObj = [self stringWithText:theCurrentObj];
					} // #warning Should check for TEXT (using theField[i].flag BINARY_FLAG)
					break;
					
				case FIELD_TYPE_NULL:
					theCurrentObj = [NSNull null];
					break;
					
				default:
					NSLog (@"in fetchRowAsType : Unknown type : %d for column %d, send back a NSData object", (int)theField[i].type, (int)i);
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
			case MCPTypeDictionary :
				[theReturn setObject:theCurrentObj forKey:[mNames objectAtIndex:i]];
				break;
				
			case MCPTypeArray :
			default :
				[theReturn addObject:theCurrentObj];
				break;
		}
	}
	
	return theReturn;
}

/**
 * Return the next row of the result as an array, the index in select field order, the object a proper object 
 * for handling the information in the field (NSString, NSNumber ...).
 *
 * Just a #{typed} wrapper for method !{fetchRosAsType:} (with arg MCPTypeArray).
 *
 * NB: Returned object is immutable.
 */
- (NSArray *)fetchRowAsArray
{
	NSMutableArray *theArray = [self fetchRowAsType:MCPTypeArray];
			
	return (theArray) ? [NSArray arrayWithArray:theArray] : nil;
}

/**
 * Return the next row of the result as a dictionary, the key being the field name, the object a proper object 
 * for handling the information in the field (NSString, NSNumber ...).
 *
 * Just a #{typed} wrapper for method !{fetchRosAsType:} (with arg MCPTypeDictionary).
 *
 * NB: Returned object is immutable.
 */
- (NSDictionary *)fetchRowAsDictionary
{
	NSMutableDictionary	*theDict = [self fetchRowAsType:MCPTypeDictionary];

	return (theDict) ? [NSDictionary dictionaryWithDictionary:theDict] : nil;
}

#pragma mark -
#pragma mark Columns

/**
 * Generate the mNames if not already generated, and return it.
 *
 * mNames is a NSArray holding the names of the fields(columns) of the results.
 */
- (NSArray *)fetchFieldNames
{
	int	i;
	unsigned int theNumFields;
	NSMutableArray *theNamesArray;
	MYSQL_FIELD	*theField;
	
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

/**
 * Return a collection of the fields's type. The type of collection is choosen by the aType variable 
 * (MCPTypeArray or MCPTypeDictionary).
 *
 * This method returned directly the #{mutable} object generated while going through all the columns
 */
- (id)fetchTypesAsType:(MCPReturnType)aType
{
	int i;
	id theTypes;
	MYSQL_FIELD	*theField;
	
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

/**
 * Return an array of the fields' types.
 *
 * NB: Returned object is immutable.
 */
- (NSArray *)fetchTypesAsArray
{
	NSMutableArray *theArray = [self fetchTypesAsType:MCPTypeArray];
	
	return (theArray) ? [NSArray arrayWithArray:theArray] : nil;
}

/**
 * Return a dictionnary of the fields' types (keys are the fields' names).
 *
 * NB: Returned object is immutable.
 */
- (NSDictionary*) fetchTypesAsDictionary
{
	NSMutableDictionary *theDict = [self fetchTypesAsType:MCPTypeDictionary];
		
	return (theDict) ? [NSDictionary dictionaryWithDictionary:theDict] : nil;
}

/**
 * Return an array of dicts containg column data of the last executed query
 */
- (NSArray *)fetchResultFieldsStructure
{
	MYSQL_FIELD *theField;
	
	NSMutableArray *structureResult = [NSMutableArray array];
	
	unsigned int i;
	unsigned int numFields = mysql_num_fields(mResult);
	
	if (mResult == NULL) return nil;
	
	theField = mysql_fetch_fields(mResult);
	
	for (i=0; i < numFields; i++)
	{
		NSMutableDictionary *fieldStructure = [NSMutableDictionary dictionaryWithCapacity:39];
		
		/* Original column position */
		[fieldStructure setObject:[NSNumber numberWithInt:i] forKey:@"datacolumnindex"];
		
		/* Name of column */
		[fieldStructure setObject:[self stringWithCString:theField[i].name] forKey:@"name"];
		// [fieldStructure setObject:[NSNumber numberWithUnsignedInt:theField[i].name_length] forKey:@"name_length"];
		
		/* Original column name, if an alias */ 
		[fieldStructure setObject:[self stringWithCString:theField[i].org_name] forKey:@"org_name"];
		// [fieldStructure setObject:[NSNumber numberWithUnsignedInt:theField[i].org_name_length] forKey:@"org_name_length"];
		
		/* Table of column if column was a field */
		[fieldStructure setObject:[self stringWithCString:theField[i].table] forKey:@"table"];
		// [fieldStructure setObject:[NSNumber numberWithUnsignedInt:theField[i].table_length] forKey:@"table_length"];
		
		/* Org table name, if table was an alias */
		[fieldStructure setObject:[self stringWithCString:theField[i].org_table] forKey:@"org_table"];
		// [fieldStructure setObject:[NSNumber numberWithUnsignedInt:theField[i].org_table_length] forKey:@"org_table_length"];
		
		/* Database for table */
		[fieldStructure setObject:[self stringWithCString:theField[i].db] forKey:@"db"];
		// [fieldStructure setObject:[NSNumber numberWithUnsignedInt:theField[i].db_length] forKey:@"db_length"];
		
		/* Catalog for table */
		// [fieldStructure setObject:[self stringWithCString:theField[i].catalog] forKey:@"catalog"];
		// [fieldStructure setObject:[NSNumber numberWithUnsignedInt:theField[i].catalog_length] forKey:@"catalog_length"];
		
		/* Default value (set by mysql_list_fields) */
		// [fieldStructure setObject:[self stringWithCString:theField[i].def] forKey:@"def"];
		// [fieldStructure setObject:[NSNumber numberWithUnsignedInt:theField[i].def_length] forKey:@"def_length"];
		
		/* Width of column (real length in bytes) */
		[fieldStructure setObject:[NSNumber numberWithUnsignedLongLong:theField[i].length] forKey:@"byte_length"];
		/* Width of column (as in create)*/
		[fieldStructure setObject:[NSNumber numberWithUnsignedLongLong:theField[i].length/[self find_charsetMaxByteLengthPerChar:theField[i].charsetnr]] 
						   forKey:@"char_length"];
		/* Max width (bytes) for selected set */
		[fieldStructure setObject:[NSNumber numberWithUnsignedLongLong:theField[i].max_length] forKey:@"max_byte_length"];
		/* Max width (chars) for selected set */
		// [fieldStructure setObject:[NSNumber numberWithUnsignedLongLong:theField[i].max_length/[self find_charsetMaxByteLengthPerChar:theField[i].charsetnr]] 
		// 		forKey:@"max_char_length"];
		
		/* Div flags */
		[fieldStructure setObject:[NSNumber numberWithUnsignedInt:theField[i].flags] forKey:@"flags"];
		[fieldStructure setObject:[NSNumber numberWithBool:(theField[i].flags & NOT_NULL_FLAG) ? YES : NO] forKey:@"null"];
		[fieldStructure setObject:[NSNumber numberWithBool:(theField[i].flags & PRI_KEY_FLAG) ? YES : NO] forKey:@"PRI_KEY_FLAG"];
		[fieldStructure setObject:[NSNumber numberWithBool:(theField[i].flags & UNIQUE_KEY_FLAG) ? YES : NO] forKey:@"UNIQUE_KEY_FLAG"];
		[fieldStructure setObject:[NSNumber numberWithBool:(theField[i].flags & MULTIPLE_KEY_FLAG) ? YES : NO] forKey:@"MULTIPLE_KEY_FLAG"];
		[fieldStructure setObject:[NSNumber numberWithBool:(theField[i].flags & BLOB_FLAG) ? YES : NO] forKey:@"BLOB_FLAG"];
		[fieldStructure setObject:[NSNumber numberWithBool:(theField[i].flags & UNSIGNED_FLAG) ? YES : NO] forKey:@"UNSIGNED_FLAG"];
		[fieldStructure setObject:[NSNumber numberWithBool:(theField[i].flags & ZEROFILL_FLAG) ? YES : NO] forKey:@"ZEROFILL_FLAG"];
		[fieldStructure setObject:[NSNumber numberWithBool:(theField[i].flags & BINARY_FLAG) ? YES : NO] forKey:@"BINARY_FLAG"];
		[fieldStructure setObject:[NSNumber numberWithBool:(theField[i].flags & ENUM_FLAG) ? YES : NO] forKey:@"ENUM_FLAG"];
		[fieldStructure setObject:[NSNumber numberWithBool:(theField[i].flags & AUTO_INCREMENT_FLAG) ? YES : NO] forKey:@"AUTO_INCREMENT_FLAG"];
		[fieldStructure setObject:[NSNumber numberWithBool:(theField[i].flags & SET_FLAG) ? YES : NO] forKey:@"SET_FLAG"];
		[fieldStructure setObject:[NSNumber numberWithBool:(theField[i].flags & NUM_FLAG) ? YES : NO] forKey:@"NUM_FLAG"];
		[fieldStructure setObject:[NSNumber numberWithBool:(theField[i].flags & PART_KEY_FLAG) ? YES : NO] forKey:@"PART_KEY_FLAG"];
		// [fieldStructure setObject:[NSNumber numberWithInt:(theField[i].flags & GROUP_FLAG) ? 1 : 0] forKey:@"GROUP_FLAG"];
		// [fieldStructure setObject:[NSNumber numberWithInt:(theField[i].flags & UNIQUE_FLAG) ? 1 : 0] forKey:@"UNIQUE_FLAG"];
		// [fieldStructure setObject:[NSNumber numberWithInt:(theField[i].flags & BINCMP_FLAG) ? 1 : 0] forKey:@"BINCMP_FLAG"];
		
		/* Number of decimals in field */
		[fieldStructure setObject:[NSNumber numberWithUnsignedInt:theField[i].decimals] forKey:@"decimals"];
		
		/* Character set */
		[fieldStructure setObject:[NSNumber numberWithUnsignedInt:theField[i].charsetnr] forKey:@"charsetnr"];
		[fieldStructure setObject:[self find_charsetName:theField[i].charsetnr] forKey:@"charset_name"];
		[fieldStructure setObject:[self find_charsetCollation:theField[i].charsetnr] forKey:@"charset_collation"];
		
		/* Table type */
		[fieldStructure setObject:[self mysqlTypeToStringForType:theField[i].type 
												   withCharsetNr:theField[i].charsetnr 
													   withFlags:theField[i].flags
													  withLength:theField[i].length 
								   ] forKey:@"type"];
		
		/* Table type group*/
		[fieldStructure setObject:[self mysqlTypeToGroupForType:theField[i].type 
												  withCharsetNr:theField[i].charsetnr 
													  withFlags:theField[i].flags
								   ] forKey:@"typegrouping"];
		
		[structureResult addObject:fieldStructure];
		
	}
	
	return structureResult;
	
}

/**
 * Return the MySQL flags of the column at the given index... Can be used to check if a number is signed or not...
 */
- (unsigned int)fetchFlagsAtIndex:(unsigned int)index
{
   unsigned int theRet;
   unsigned int theNumFields;
   MYSQL_FIELD *theField;
   
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

/**
 *
 */
- (unsigned int)fetchFlagsForKey:(NSString *)key
{
   unsigned int theRet;
   unsigned int theNumFields, index;
   MYSQL_FIELD *theField;
	
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

/**
 * Return YES if the field with the given index is a BLOB. It should be used to discriminates between BLOBs 
 * and TEXTs.
 *
 * #{DEPRECATED}, This method is not consistent with the C API which is supposed to return YES for BOTH 
 * text and blob (and BTW is also deprecated)...
 *
 * #{NOTE} That the current version handles properly TEXT, and returns those as NSString (and not NSData as 
 * it used to be).
 */
- (BOOL)isBlobAtIndex:(unsigned int)index
{
	BOOL theRet;
	unsigned int theNumFields;
	MYSQL_FIELD	*theField;
	
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
				theRet = (theField[index].flags & BINARY_FLAG);
				break;
			default:
				theRet = NO;
				break;
		}
	}
	
	return theRet;
}

/**
 * Return YES if the field (by name) with the given index is a BLOB. It should be used to discriminates 
 * between BLOBs and TEXTs.
 *
 * #{DEPRECATED}, This method is not consistent with the C API which is supposed to return YES for BOTH 
 * text and blob (and BTW is also deprecated)...
 *
 * #{NOTE} That the current version handles properly TEXT, and returns those as NSString (and not NSData 
 * as it used to be).
 */
- (BOOL)isBlobForKey:(NSString *)key
{
	BOOL theRet;
	unsigned int theNumFields, index;
	MYSQL_FIELD *theField;
	
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
				theRet = (theField[index].flags & BINARY_FLAG);
				break;
			default:
				theRet = NO;
				break;
		}
	}
	
	return theRet;
}

#pragma mark -
#pragma mark Conversion

/**
 * Use the string encoding to convert the returned NSData to a string (for a TEXT field).
 */
- (NSString *)stringWithText:(NSData *)theTextData
{
	NSString *theString;
	
	if (theTextData == nil) {
		return nil;
	}
	
	theString = [[NSString alloc] initWithData:theTextData encoding:mEncoding];
	
	if (theString) {
		[theString autorelease];
	}
	
	return theString;
}

/**
 * Return a (long) string containing the table of results, first line being the fields name, next line(s) 
 * the row(s). Useful to have NSLog logging a MCPResult (example).
 */
- (NSString *)description
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
		
		while (theRow = [self fetchRowAsArray]) 
		{
			id theField = [theRow objectAtIndex:i];
			
			if (trunc) {
				if (([theField isKindOfClass:[NSString class]]) && (kLengthOfTruncationForLog < [(NSString *)theField length])) {
					theField = [theField substringToIndex:kLengthOfTruncationForLog];
				}
				else if (([theField isKindOfClass:[NSData class]]) && (kLengthOfTruncationForLog < [(NSData *)theField length])) {
					theField = [NSData dataWithBytes:[theField bytes] length:kLengthOfTruncationForLog];
				}
			}
				
			for (i=0; i<(mNumOfFields - 1); i++) 
			{
				[theString appendFormat:@"%@\t", theField];
			}
			
			[theString appendFormat:@"%@\n", theField];
		}
		
		// Returning to the proper row
		mysql_row_seek(mResult, thePosition);
		
		return theString;
	}
}

/**
 * For internal use only. Transform a NSString to a C type string (ended with \0) using ethe character set 
 * from the MCPConnection. Lossy conversions are enabled.
 */
- (const char *)cStringFromString:(NSString *)theString
{
	NSMutableData *theData;
	
	if (!theString) {
		return (const char *)NULL;
	}
	
	theData = [NSMutableData dataWithData:[theString dataUsingEncoding:mEncoding allowLossyConversion:YES]];
	[theData increaseLengthBy:1];
	
	return (const char *)[theData bytes];
}

/**
 * Return a NSString from a C style string encoded with the character set of theMCPConnection.
 */
- (NSString *)stringWithCString:(const char *)theCString
{
	NSData *theData;
	NSString *theString;
	
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

#pragma mark -
#pragma mark Other

/**
 * Convert a mysql_type to a string
 */
- (NSString *)mysqlTypeToStringForType:(unsigned int)type withCharsetNr:(unsigned int)charsetnr withFlags:(unsigned int)flags withLength:(unsigned long long)length
{
	// BOOL isUnsigned = (flags & UNSIGNED_FLAG) != 0;
	// BOOL isZerofill = (flags & ZEROFILL_FLAG) != 0;
	
	switch (type) {
		case FIELD_TYPE_BIT:
			return @"BIT";
		case MYSQL_TYPE_DECIMAL:
			//return isUnsigned ? (isZerofill? @"DECIMAL UNSIGNED ZEROFILL" : @"DECIMAL UNSIGNED"): 
			return @"DECIMAL";
		case MYSQL_TYPE_TINY:
			// return isUnsigned ? (isZerofill? @"TINYINT UNSIGNED ZEROFILL" : @"TINYINT UNSIGNED"): 
			return @"TINYINT";
		case MYSQL_TYPE_SHORT:
			// return isUnsigned ? (isZerofill? @"SMALLINT UNSIGNED ZEROFILL" : @"SMALLINT UNSIGNED"): 
			return @"SMALLINT";
		case MYSQL_TYPE_LONG:
			// return isUnsigned ? (isZerofill? @"INT UNSIGNED ZEROFILL" : @"INT UNSIGNED"): 
			return @"INT";
		case MYSQL_TYPE_FLOAT:
			// return isUnsigned ? (isZerofill? @"FLOAT UNSIGNED ZEROFILL" : @"FLOAT UNSIGNED"): 
			return @"FLOAT";
		case MYSQL_TYPE_DOUBLE:
			// return isUnsigned ? (isZerofill? @"DOUBLE UNSIGNED ZEROFILL" : @"DOUBLE UNSIGNED"): 
			return @"DOUBLE";
		case MYSQL_TYPE_NULL:
			return @"NULL";
		case MYSQL_TYPE_TIMESTAMP:
			return @"TIMESTAMP";
		case MYSQL_TYPE_LONGLONG:
			// return isUnsigned ? (isZerofill? @"BIGINT UNSIGNED ZEROFILL" : @"BIGINT UNSIGNED") : 
			return @"BIGINT";
		case MYSQL_TYPE_INT24:
			// return isUnsigned ? (isZerofill? @"MEDIUMINT UNSIGNED ZEROFILL" : @"MEDIUMINT UNSIGNED") : 
			return @"MEDIUMINT";
		case MYSQL_TYPE_DATE:
			return @"DATE";
		case MYSQL_TYPE_TIME:
			return @"TIME";
		case MYSQL_TYPE_DATETIME:
			return @"DATETIME";
		case MYSQL_TYPE_TINY_BLOB:// should no appear over the wire
		case MYSQL_TYPE_MEDIUM_BLOB:// should no appear over the wire
		case MYSQL_TYPE_LONG_BLOB:// should no appear over the wire
		case MYSQL_TYPE_BLOB:
		{
			BOOL isBlob = (charsetnr == MAGIC_BINARY_CHARSET_NR);
			switch ((int)length/[self find_charsetMaxByteLengthPerChar:charsetnr]) {
				case 255: return isBlob? @"TINYBLOB":@"TINYTEXT";
				case 65535: return isBlob? @"BLOB":@"TEXT";
				case 16777215: return isBlob? @"MEDIUMBLOB":@"MEDIUMTEXT";
				case 4294967295: return isBlob? @"LONGBLOB":@"LONGTEXT";
				default:
					switch (length) {
						case 255: return isBlob? @"TINYBLOB":@"TINYTEXT";
						case 65535: return isBlob? @"BLOB":@"TEXT";
						case 16777215: return isBlob? @"MEDIUMBLOB":@"MEDIUMTEXT";
						case 4294967295: return isBlob? @"LONGBLOB":@"LONGTEXT";
						default:
							return @"UNKNOWN";
					}
			}
		}
		case MYSQL_TYPE_VAR_STRING:
			if (flags & ENUM_FLAG) {
				return @"ENUM";
			}
			if (flags & SET_FLAG) {
				return @"SET";
			}
			if (charsetnr == MAGIC_BINARY_CHARSET_NR) {
				return @"VARBINARY";
			}
			return @"VARCHAR";
		case MYSQL_TYPE_STRING:
			if (flags & ENUM_FLAG) {
				return @"ENUM";
			}
			if (flags & SET_FLAG) {
				return @"SET";
			}
			if ((flags & BINARY_FLAG) && charsetnr == MAGIC_BINARY_CHARSET_NR) {
				return @"BINARY";
			}
			return @"CHAR";
		case MYSQL_TYPE_ENUM:
			/* This should never happen */
			return @"ENUM";
		case MYSQL_TYPE_YEAR:
			return @"YEAR";
		case MYSQL_TYPE_SET:
			/* This should never happen */
			return @"SET";
		case MYSQL_TYPE_GEOMETRY:
			return @"GEOMETRY";
		default:
			return @"UNKNOWN";
	}
}

/**
 * Merge mysql_types into type groups
 */
- (NSString *)mysqlTypeToGroupForType:(unsigned int)type withCharsetNr:(unsigned int)charsetnr withFlags:(unsigned int)flags
{
	switch(type){
		case FIELD_TYPE_BIT:
			return @"bit";
		case MYSQL_TYPE_TINY:
		case MYSQL_TYPE_SHORT:
		case MYSQL_TYPE_LONG:
		case MYSQL_TYPE_LONGLONG:
		case MYSQL_TYPE_INT24:
			return @"integer";
		case MYSQL_TYPE_FLOAT:
		case MYSQL_TYPE_DOUBLE:
		case MYSQL_TYPE_DECIMAL:
			return @"float";
		case MYSQL_TYPE_YEAR:
		case MYSQL_TYPE_DATETIME:
		case MYSQL_TYPE_TIME:
		case MYSQL_TYPE_DATE:
		case MYSQL_TYPE_TIMESTAMP:
			return @"date";
		case MYSQL_TYPE_VAR_STRING:
			if (flags & ENUM_FLAG) {
				return @"enum";
			}
			if (flags & SET_FLAG) {
				return @"enum";
			}
			if (charsetnr == MAGIC_BINARY_CHARSET_NR) {
				return @"binary";
			}
			return @"string";
		case MYSQL_TYPE_STRING:
			if (flags & ENUM_FLAG) {
				return @"enum";
			}
			if (flags & SET_FLAG) {
				return @"enum";
			}
			if ((flags & BINARY_FLAG) && charsetnr == MAGIC_BINARY_CHARSET_NR) {
				return @"binary";
			}
			return @"string";
		case MYSQL_TYPE_TINY_BLOB:   // should no appear over the wire
		case MYSQL_TYPE_MEDIUM_BLOB: // should no appear over the wire
		case MYSQL_TYPE_LONG_BLOB:   // should no appear over the wire
		case MYSQL_TYPE_BLOB:
		{
			if (charsetnr == MAGIC_BINARY_CHARSET_NR) {
				return @"blobdata";
			} else {
				return @"textdata";
			}
		}
		case MYSQL_TYPE_GEOMETRY:
			return @"geometry";
		default:
			return @"blobdata";
			
	}
}

/**
 * Convert a mysql_charsetnr into a charset name as string
 */
- (NSString *)find_charsetName:(unsigned int)charsetnr
{
	const OUR_CHARSET * c = our_charsets60;
	
	do {
		if (c->nr == charsetnr)
			return [self stringWithCString:c->name];
		++c;
	} while (c[0].nr != 0);
	
	return @"UNKNOWN";
}

/**
 * Convert a mysql_charsetnr into a collation name as string
 */
- (NSString *)find_charsetCollation:(unsigned int)charsetnr
{
	const OUR_CHARSET * c = our_charsets60;
	
	do {
		if (c->nr == charsetnr)
			return [self stringWithCString:c->collation];
		++c;
	} while (c[0].nr != 0);
	
	return @"UNKNOWN";
}

/**
 * Return the max byte length to store a char by using
 * a specific mysql_charsetnr
 */
- (unsigned int)find_charsetMaxByteLengthPerChar:(unsigned int)charsetnr
{
	const OUR_CHARSET * c = our_charsets60;
	
	do {
		if (c->nr == charsetnr)
			return c->char_maxlen;
		++c;
	} while (c[0].nr != 0);
	
	return 1;
}

#pragma mark -

/**
 * Do one really needs an explanation for this method? Which by the way you should not use...
 */
- (void) dealloc
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
}

@end
