//
//  $Id$
//
//  SPDatabaseData.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on May 20, 2009
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPDatabaseData.h"
#import "SPStringAdditions.h"

@interface SPDatabaseData (PrivateAPI)

- (NSMutableArray *)_getDatabaseDataForQuery:(NSString *)query;

@end

const CHAR_SETS charsets[] =
{
	{  1, "big5","big5_chinese_ci", "Big5 Traditional Chinese"},
	{  3, "dec8", "dec8_swedisch_ci", "DEC West European"},
	{  4, "cp850", "cp850_general_ci", "DOS West European"},
	{  6, "hp8", "hp8_english_ci", "HP West European"},
	{  7, "koi8r", "koi8r_general_ci", "KOI8-R Relcom Russian"},
	{  8, "latin1", "latin1_swedish_ci", "cp1252 West European"},
	{  9, "latin2", "latin2_general_ci", "ISO 8859-2 Central European"},
	{ 10, "swe7", "swe7_swedish_ci", "7bit Swedish"},
	{ 11, "ascii", "ascii_general_ci", "US ASCII"},
	{ 12, "ujis", "ujis_japanese_ci", "EUC-JP Japanese"},
	{ 13, "sjis", "sjis_japanese_ci", "Shift-JIS Japanese"},
	{ 16, "hebrew", "hebrew_general_ci", "ISO 8859-8 Hebrew"},
	{ 18, "tis620", "tis620_thai_ci", "TIS620 Thai"},
	{ 19, "euckr", "euckr_korean_ci", "EUC-KR Korean"},
	{ 22, "koi8u", "koi8u_general_ci", "KOI8-U Ukrainian"},
	{ 24, "gb2312", "gb2312_chinese_ci", "GB2312 Simplified Chinese"},
	{ 25, "greek", "greek_general_ci", "ISO 8859-7 Greek"},
	{ 26, "cp1250", "cp1250_general_ci", "Windows Central European"},
	{ 28, "gbk", "gbk_chinese_ci", "GBK Simplified Chinese"},
	{ 30, "latin5", "latin5_turkish_ci", "ISO 8859-9 Turkish"},
	{ 32, "armscii8", "armscii8_general_ci", "ARMSCII-8 Armenian"},
	{ 33, "utf8", "utf8_general_ci", "UTF-8 Unicode"},
	{ 35, "ucs2", "ucs2_general_ci", "UCS-2 Unicode"},
	{ 36, "cp866", "cp866_general_ci", "DOS Russian"},
	{ 37, "keybcs2", "keybcs2_general_ci", "DOS Kamenicky Czech-Slovak"},
	{ 38, "macce", "macce_general_ci", "Mac Central European"},
	{ 39, "macroman", "macroman_general_ci", "Mac West European"},
	{ 40, "cp852", "cp852_general_ci", "DOS Central European"},
	{ 41, "latin7", "latin7_general_ci", "ISO 8859-13 Baltic"},
	{ 51, "cp1251", "cp1251_general_ci", "Windows Cyrillic"},
	{ 57, "cp1256", "cp1256_general_ci", "Windows Arabic"},
	{ 59, "cp1257", "cp1257_general_ci", "Windows Baltic"},
	{ 63, "binary", "binary", "Binary pseudo charset"},
	{ 92, "geostd8", "geostd8_general_ci", "GEOSTD8 Georgian"},
	{ 95, "cp932", "cp932_japanese_ci", "SJIS for Windows Japanese"},
	{ 97, "eucjpms", "eucjpms_japanese_ci", "UJIS for Windows Japanese"},
	{  2, "latin2", "latin2_czech_cs", "ISO 8859-2 Central European"},
	{  5, "latin1", "latin1_german_ci", "cp1252 West European"},
	{ 14, "cp1251", "cp1251_bulgarian_ci", "Windows Cyrillic"},
	{ 15, "latin1", "latin1_danish_ci", "cp1252 West European"},
	{ 17, "filename", "filename", "File Name"},
	{ 20, "latin7", "latin7_estonian_cs", "ISO 8859-13 Baltic"},
	{ 21, "latin2", "latin2_hungarian_ci", "ISO 8859-2 Central European"},
	{ 23, "cp1251", "cp1251_ukrainian_ci", "Windows Cyrillic"},
	{ 27, "latin2", "latin2_croatian_ci", "ISO 8859-2 Central European"},
	{ 29, "cp1257", "cp1257_lithunian_ci", "Windows Baltic"},
	{ 31, "latin1", "latin1_german2_ci", "cp1252 West European"},
	{ 34, "cp1250", "cp1250_czech_cs", "Windows Central European"},
	{ 42, "latin7", "latin7_general_cs", "ISO 8859-13 Baltic"},
	{ 43, "macce", "macce_bin", "Mac Central European"},
	{ 44, "cp1250", "cp1250_croatian_ci", "Windows Central European"},
	{ 45, "utf8", "utf8_general_ci", "UTF-8 Unicode"},
	{ 46, "utf8", "utf8_bin", "UTF-8 Unicode"},
	{ 47, "latin1", "latin1_bin", "cp1252 West European"},
	{ 48, "latin1", "latin1_general_ci", "cp1252 West European"},
	{ 49, "latin1", "latin1_general_cs", "cp1252 West European"},
	{ 50, "cp1251", "cp1251_bin", "Windows Cyrillic"},
	{ 52, "cp1251", "cp1251_general_cs", "Windows Cyrillic"},
	{ 53, "macroman", "macroman_bin", "Mac West European"},
	{ 58, "cp1257", "cp1257_bin", "Windows Baltic"},
	{ 60, "armascii8", "armascii8_bin", "armascii8"},
	{ 65, "ascii", "ascii_bin", "US ASCII"},
	{ 66, "cp1250", "cp1250_bin", "Windows Central European"},
	{ 67, "cp1256", "cp1256_bin", "Windows Arabic"},
	{ 68, "cp866", "cp866_bin", "DOS Russian"},
	{ 69, "dec8", "dec8_bin", "DEC West European"},
	{ 70, "greek", "greek_bin", "ISO 8859-7 Greek"},
	{ 71, "hebew", "hebrew_bin", "ISO 8859-8 Hebrew"},
	{ 72, "hp8", "hp8_bin", "HP West European"},
	{ 73, "keybcs2", "keybcs2_bin", "DOS Kamenicky Czech-Slovak"},
	{ 74, "koi8r", "koi8r_bin", "KOI8-R Relcom Russian"},
	{ 75, "koi8u", "koi8u_bin", "KOI8-U Ukrainian"},
	{ 77, "latin2", "latin2_bin", "ISO 8859-2 Central European"},
	{ 78, "latin5", "latin5_bin", "ISO 8859-9 Turkish"},
	{ 79, "latin7", "latin7_bin", "ISO 8859-13 Baltic"},
	{ 80, "cp850", "cp850_bin", "DOS West European"},
	{ 81, "cp852", "cp852_bin", "DOS Central European"},
	{ 82, "swe7", "swe7_bin", "7bit Swedish"},
	{ 93, "geostd8", "geostd8_bin", "GEOSTD8 Georgian"},
	{ 83, "utf8", "utf8_bin", "UTF-8 Unicode"},
	{ 84, "big5", "big5_bin", "Big5 Traditional Chinese"},
	{ 85, "euckr", "euckr_bin", "EUC-KR Korean"},
	{ 86, "gb2312", "gb2312_bin", "GB2312 Simplified Chinese"},
	{ 87, "gbk", "gbk_bin", "GBK Simplified Chinese"},
	{ 88, "sjis", "sjis_bin", "Shift-JIS Japanese"},
	{ 89, "tis620", "tis620_bin", "TIS620 Thai"},
	{ 90, "ucs2", "ucs2_bin", "UCS-2 Unicode"},
	{ 91, "ujis", "ujis_bin", "EUC-JP Japanese"},
	{ 94, "latin1", "latin1_spanish_ci", "cp1252 West European"},
	{ 96, "cp932", "cp932_bin", "SJIS for Windows Japanese"},
	{ 99, "cp1250", "cp1250_polish_ci", "Windows Central European"},
	{ 98, "eucjpms", "eucjpms_bin", "UJIS for Windows Japanese"},
	{128, "ucs2", "ucs2_unicode_ci", "UCS-2 Unicode"},
	{129, "ucs2", "ucs2_icelandic_ci", "UCS-2 Unicode"},
	{130, "ucs2", "ucs2_latvian_ci", "UCS-2 Unicode"},
	{131, "ucs2", "ucs2_romanian_ci", "UCS-2 Unicode"},
	{132, "ucs2", "ucs2_slovenian_ci", "UCS-2 Unicode"},
	{133, "ucs2", "ucs2_polish_ci", "UCS-2 Unicode"},
	{134, "ucs2", "ucs2_estonian_ci", "UCS-2 Unicode"},
	{135, "ucs2", "ucs2_spanish_ci", "UCS-2 Unicode"},
	{136, "ucs2", "ucs2_swedish_ci", "UCS-2 Unicode"},
	{137, "ucs2", "ucs2_turkish_ci", "UCS-2 Unicode"},
	{138, "ucs2", "ucs2_czech_ci", "UCS-2 Unicode"},
	{139, "ucs2", "ucs2_danish_ci", "UCS-2 Unicode"},
	{140, "ucs2", "ucs2_lithunian_ci", "UCS-2 Unicode"},
	{141, "ucs2", "ucs2_slovak_ci", "UCS-2 Unicode"},
	{142, "ucs2", "ucs2_spanish2_ci", "UCS-2 Unicode"},
	{143, "ucs2", "ucs2_roman_ci", "UCS-2 Unicode"},
	{144, "ucs2", "ucs2_persian_ci", "UCS-2 Unicode"},
	{145, "ucs2", "ucs2_esperanto_ci", "UCS-2 Unicode"},
	{146, "ucs2", "ucs2_hungarian_ci", "UCS-2 Unicode"},
	{147, "ucs2", "ucs2_sinhala_ci", "UCS-2 Unicode"},
	{192, "utf8mb3", "utf8mb3_general_ci", "UTF-8mb3 Unicode"},
	{193, "utf8mb3", "utf8mb3_icelandic_ci", "UTF-8mb3 Unicode"},
	{194, "utf8mb3", "utf8mb3_latvian_ci", "UTF-8mb3 Unicode"},
	{195, "utf8mb3", "utf8mb3_romanian_ci", "UTF-8mb3 Unicode"},
	{196, "utf8mb3", "utf8mb3_slovenian_ci", "UTF-8mb3 Unicode"},
	{197, "utf8mb3", "utf8mb3_polish_ci", "UTF-8mb3 Unicode"},
	{198, "utf8mb3", "utf8mb3_estonian_ci", "UTF-8mb3 Unicode"},
	{119, "utf8mb3", "utf8mb3_spanish_ci", "UTF-8mb3 Unicode"},
	{200, "utf8mb3", "utf8mb3_swedish_ci", "UTF-8mb3 Unicode"},
	{201, "utf8mb3", "utf8mb3_turkish_ci", "UTF-8mb3 Unicode"},
	{202, "utf8mb3", "utf8mb3_czech_ci", "UTF-8mb3 Unicode"},
	{203, "utf8mb3", "utf8mb3_danish_ci", "UTF-8mb3 Unicode"},
	{204, "utf8mb3", "utf8mb3_lithunian_ci", "UTF-8mb3 Unicode"},
	{205, "utf8mb3", "utf8mb3_slovak_ci", "UTF-8mb3 Unicode"},
	{206, "utf8mb3", "utf8mb3_spanish2_ci", "UTF-8mb3 Unicode"},
	{207, "utf8mb3", "utf8mb3_roman_ci", "UTF-8mb3 Unicode"},
	{208, "utf8mb3", "utf8mb3_persian_ci", "UTF-8mb3 Unicode"},
	{209, "utf8mb3", "utf8mb3_esperanto_ci", "UTF-8mb3 Unicode"},
	{210, "utf8mb3", "utf8mb3_hungarian_ci", "UTF-8mb3 Unicode"},
	{211, "utf8mb3", "utf8mb3_sinhala_ci", "UTF-8mb3 Unicode"},
	{224, "utf8", "utf8_unicode_ci", "UTF-8 Unicode"},
	{225, "utf8", "utf8_icelandic_ci", "UTF-8 Unicode"},
	{226, "utf8", "utf8_latvian_ci", "UTF-8 Unicode"},
	{227, "utf8", "utf8_romanian_ci", "UTF-8 Unicode"},
	{228, "utf8", "utf8_slovenian_ci", "UTF-8 Unicode"},
	{229, "utf8", "utf8_polish_ci", "UTF-8 Unicode"},
	{230, "utf8", "utf8_estonian_ci", "UTF-8 Unicode"},
	{231, "utf8", "utf8_spanish_ci", "UTF-8 Unicode"},
	{232, "utf8", "utf8_swedish_ci", "UTF-8 Unicode"},
	{233, "utf8", "utf8_turkish_ci", "UTF-8 Unicode"},
	{234, "utf8", "utf8_czech_ci", "UTF-8 Unicode"},
	{235, "utf8", "utf8_danish_ci", "UTF-8 Unicode"},
	{236, "utf8", "utf8_lithuanian_ci", "UTF-8 Unicode"},
	{237, "utf8", "utf8_slovak_ci", "UTF-8 Unicode"},
	{238, "utf8", "utf8_spanish2_ci", "UTF-8 Unicode"},
	{239, "utf8", "utf8_roman_ci", "UTF-8 Unicode"},
	{240, "utf8", "utf8_persian_ci", "UTF-8 Unicode"},
	{241, "utf8", "utf8_esperanto_ci", "UTF-8 Unicode"},
	{242, "utf8", "utf8_hungarian_ci", "UTF-8 Unicode"},
	{243, "utf8", "utf8_sinhala_ci", "UTF-8 Unicode"},
	{254, "utf8mb3", "utf8mb3_general_cs", "UTF-8mb3 Unicode"},
	{  0, NULL, NULL, NULL}
};

@implementation SPDatabaseData

@synthesize connection;

/**
 * Initialize cache arrays.
 */
- (id)init
{
	if ((self = [super init])) {
		characterSetEncoding = nil;
		
		collations             = [[NSMutableArray alloc] init];
		characterSetCollations = [[NSMutableArray alloc] init];
		storageEngines         = [[NSMutableArray alloc] init];
		characterSetEncodings  = [[NSMutableArray alloc] init];
	}
	
	return self;
}

/**
 * Reset all the cached values.
 */
- (void)resetAllData
{
	if (characterSetEncoding != nil) {
		[characterSetEncoding release], characterSetEncoding = nil; 
	}
	
	[collations removeAllObjects];
	[characterSetCollations removeAllObjects];
	[storageEngines removeAllObjects];
	[characterSetEncodings removeAllObjects];
}

/**
 * Returns all of the database's currently available collations by querying information_schema.collations.
 */
- (NSArray *)getDatabaseCollations
{
	if ([collations count] == 0) {
		
		// Try to retrieve the available collations from the database
		if ([connection serverMajorVersion] >= 5)
			[collations addObjectsFromArray:[self _getDatabaseDataForQuery:@"SELECT * FROM `information_schema.collations` ORDER BY `collation_name` ASC"]];	

		// If that failed, get the list of collations from the hard-coded list
		if (![collations count]) {
			const CHAR_SETS *c = charsets;
			
			do {
				[collations addObject:[NSString stringWithCString:c->collation encoding:NSUTF8StringEncoding]];
				
				++c;
			} 
			while (c[0].nr != 0);
		}
	}
		
	return collations;
}

/**
 * Returns all of the database's currently available collations allowed for the supplied encoding by 
 * querying information_schema.collations.
 */ 
- (NSArray *)getDatabaseCollationsForEncoding:(NSString *)encoding
{
	if (encoding && ((characterSetEncoding == nil) || (![characterSetEncoding isEqualToString:encoding]) || ([characterSetCollations count] == 0))) {
		
		[characterSetEncoding release];
		[characterSetCollations removeAllObjects];
		
		characterSetEncoding = [[NSString alloc] initWithString:encoding];
		
		// Try to retrieve the available collations for the supplied encoding from the database
		if ([connection serverMajorVersion] >= 5)
			[characterSetCollations addObjectsFromArray:[self _getDatabaseDataForQuery:[NSString stringWithFormat:@"SELECT * FROM `information_schema`.`collations` WHERE character_set_name = '%@' ORDER BY `collation_name` ASC", characterSetEncoding]]];	

		// If that failed, get the list of collations matching the supplied encoding from the hard-coded list
		if (![characterSetCollations count]) {
			const CHAR_SETS *c = charsets;
			
			do {
				NSString *charSet = [NSString stringWithCString:c->name encoding:NSUTF8StringEncoding];
				
				if ([charSet isEqualToString:characterSetEncoding]) {
					[characterSetCollations addObject:[NSDictionary dictionaryWithObject:[NSString stringWithCString:c->collation encoding:NSUTF8StringEncoding] forKey:@"COLLATION_NAME"]];
				}
				
				++c;
			} 
			while (c[0].nr != 0);
		}		
	}
	
	return characterSetCollations;
}

/**
 * Returns all of the database's available storage engines.
 */
- (NSArray *)getDatabaseStorageEngines
{	
	if ([storageEngines count] == 0) {
		if ([connection serverMajorVersion] < 5) {
			[storageEngines addObject:[NSDictionary dictionaryWithObject:@"MyISAM" forKey:@"Engine"]];
			
			// Check if InnoDB support is enabled
			MCPResult *result = [connection queryString:@"SHOW VARIABLES LIKE 'have_innodb'"];
			[result setReturnDataAsStrings:YES];
			
			if ([result numOfRows] == 1) {
				if ([[[result fetchRowAsDictionary] objectForKey:@"Value"] isEqualToString:@"YES"]) {
					[storageEngines addObject:[NSDictionary dictionaryWithObject:@"InnoDB" forKey:@"Engine"]];
				}
			}
			
			// Before MySQL 4.1 the MEMORY engine was known as HEAP and the ISAM engine was included
			if (([connection serverMajorVersion] <= 4) && ([connection serverMinorVersion] < 100)) {
				[storageEngines addObject:[NSDictionary dictionaryWithObject:@"HEAP" forKey:@"Engine"]];
				[storageEngines addObject:[NSDictionary dictionaryWithObject:@"ISAM" forKey:@"Engine"]];
			}
			else {
				[storageEngines addObject:[NSDictionary dictionaryWithObject:@"MEMORY" forKey:@"Engine"]];
			}
			
			// BLACKHOLE storage engine was added in MySQL 4.1.11
			if (([connection serverMajorVersion]   >= 4) &&
				([connection serverMinorVersion]   >= 1) &&
				([connection serverReleaseVersion] >= 11))
			{
				[storageEngines addObject:[NSDictionary dictionaryWithObject:@"BLACKHOLE" forKey:@"Engine"]];
				
				// ARCHIVE storage engine was added in MySQL 4.1.3
				if ([connection serverReleaseVersion] >= 3) {
					[storageEngines addObject:[NSDictionary dictionaryWithObject:@"ARCHIVE" forKey:@"Engine"]];
				}
				
				// CSV storage engine was added in MySQL 4.1.4
				if ([connection serverReleaseVersion] >= 4) {
					[storageEngines addObject:[NSDictionary dictionaryWithObject:@"CSV" forKey:@"Engine"]];
				}
			}			
		}
		// The table information_schema.engines didn't exist until MySQL 5.1.5
		else {
			if (([connection serverMajorVersion]   >= 5) &&
				([connection serverMinorVersion]   >= 1) &&
				([connection serverReleaseVersion] >= 5))
			{
				// Check the information_schema.engines table is accessible
				MCPResult *result = [connection queryString:@"SHOW TABLES IN information_schema LIKE 'ENGINES'"];
				
				if ([result numOfRows] == 1) {
					// Table is accessible so get available storage engines
					[storageEngines addObjectsFromArray:[self _getDatabaseDataForQuery:@"SELECT Engine, Support FROM information_schema.engines WHERE support IN ('DEFAULT', 'YES');"]];				
				}
			}
			else {				
				// Get storage engines
				NSMutableArray *engines = [self _getDatabaseDataForQuery:@"SHOW STORAGE ENGINES"];
				
				// We only want to include engines that are supported
				for (NSDictionary *engine in engines) 
				{				
					if (([[engine objectForKey:@"Support"] isEqualToString:@"DEFAULT"]) ||
						([[engine objectForKey:@"Support"] isEqualToString:@"YES"]))
					{
						[storageEngines addObject:engine];
					}
				}				
			}
		}
	}
	
	return storageEngines;
}

/**
 * Returns all of the database's currently available character set encodings by querying 
 * information_schema.character_sets.
 */ 
- (NSArray *)getDatabaseCharacterSetEncodings
{
	if ([characterSetEncodings count] == 0) {
		
		// Try to retrieve the available character set encodings from the database
		// Check the information_schema.character_sets table is accessible
		if ([connection serverMajorVersion] >= 5)
			[characterSetEncodings addObjectsFromArray:[self _getDatabaseDataForQuery:@"SELECT * FROM `information_schema`.`character_sets` ORDER BY `character_set_name` ASC"]];	

		// If that failed, get the list of character set encodings from the hard-coded list
		if (![characterSetEncodings count]) {
			const CHAR_SETS *c = charsets;

			do {
				[characterSetEncodings addObject:[NSDictionary dictionaryWithObjectsAndKeys:
					[NSString stringWithCString:c->name encoding:NSUTF8StringEncoding], @"CHARACTER_SET_NAME",
					[NSString stringWithCString:c->description encoding:NSUTF8StringEncoding], @"DESCRIPTION",
				nil]];

				++c;
			} 
			while (c[0].nr != 0);
		}
	}
	
	return characterSetEncodings;
}

/**
 * Deallocate ivars.
 */
- (void)dealloc
{
	if (characterSetEncoding != nil) {
		[characterSetEncoding release], characterSetEncoding = nil;
	}
	
	[collations release], collations = nil;
	[characterSetCollations release], characterSetCollations = nil;
	[storageEngines release], storageEngines = nil;
	[characterSetEncodings release], characterSetEncodings = nil;
	
	[super dealloc];
}

@end

@implementation SPDatabaseData (PrivateAPI)

/**
 * Executes the supplied query against the current connection and returns the result as an array of 
 * NSDictionarys, one for each row.
 */
- (NSMutableArray *)_getDatabaseDataForQuery:(NSString *)query
{
	NSMutableArray *array = [NSMutableArray array];

	MCPResult *result = [connection queryString:query];

	// Log any errors
	if ([[connection getLastErrorMessage] isEqualToString:@""]) {
		[result dataSeek:0];

		for (NSInteger i = 0; i < [result numOfRows]; i++)
		{
			[array addObject:[result fetchRowAsDictionary]];
		}
	}

	return array;
}

@end
