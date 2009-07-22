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
	{  1, "big5","big5_chinese_ci"},
	{  3, "dec8", "dec8_swedisch_ci"},
	{  4, "cp850", "cp850_general_ci"},
	{  6, "hp8", "hp8_english_ci"},
	{  7, "koi8r", "koi8r_general_ci"},
	{  8, "latin1", "latin1_swedish_ci"},
	{  9, "latin2", "latin2_general_ci"},
	{ 10, "swe7", "swe7_swedish_ci"},
	{ 11, "ascii", "ascii_general_ci"},
	{ 12, "ujis", "ujis_japanese_ci"},
	{ 13, "sjis", "sjis_japanese_ci"},
	{ 16, "hebrew", "hebrew_general_ci"},
	{ 18, "tis620", "tis620_thai_ci"},
	{ 19, "euckr", "euckr_korean_ci"},
	{ 22, "koi8u", "koi8u_general_ci"},
	{ 24, "gb2312", "gb2312_chinese_ci"},
	{ 25, "greek", "greek_general_ci"},
	{ 26, "cp1250", "cp1250_general_ci"},
	{ 28, "gbk", "gbk_chinese_ci"},
	{ 30, "latin5", "latin5_turkish_ci"},
	{ 32, "armscii8", "armscii8_general_ci"},
	{ 33, "utf8", "utf8_general_ci"},
	{ 35, "ucs2", "ucs2_general_ci"},
	{ 36, "cp866", "cp866_general_ci"},
	{ 37, "keybcs2", "keybcs2_general_ci"},
	{ 38, "macce", "macce_general_ci"},
	{ 39, "macroman", "macroman_general_ci"},
	{ 40, "cp852", "cp852_general_ci"},
	{ 41, "latin7", "latin7_general_ci"},
	{ 51, "cp1251", "cp1251_general_ci"},
	{ 57, "cp1256", "cp1256_general_ci"},
	{ 59, "cp1257", "cp1257_general_ci"},
	{ 63, "binary", "binary"},
	{ 92, "geostd8", "geostd8_general_ci"},
	{ 95, "cp932", "cp932_japanese_ci"},
	{ 97, "eucjpms", "eucjpms_japanese_ci"},
	{  2, "latin2", "latin2_czech_cs"},
	{  5, "latin1", "latin1_german_ci"},
	{ 14, "cp1251", "cp1251_bulgarian_ci"},
	{ 15, "latin1", "latin1_danish_ci"},
	{ 17, "filename", "filename"},
	{ 20, "latin7", "latin7_estonian_cs"},
	{ 21, "latin2", "latin2_hungarian_ci"},
	{ 23, "cp1251", "cp1251_ukrainian_ci"},
	{ 27, "latin2", "latin2_croatian_ci"},
	{ 29, "cp1257", "cp1257_lithunian_ci"},
	{ 31, "latin1", "latin1_german2_ci"},
	{ 34, "cp1250", "cp1250_czech_cs"},
	{ 42, "latin7", "latin7_general_cs"},
	{ 43, "macce", "macce_bin"},
	{ 44, "cp1250", "cp1250_croatian_ci"},
	{ 45, "utf8", "utf8_general_ci"},
	{ 46, "utf8", "utf8_bin"},
	{ 47, "latin1", "latin1_bin"},
	{ 48, "latin1", "latin1_general_ci"},
	{ 49, "latin1", "latin1_general_cs"},
	{ 50, "cp1251", "cp1251_bin"},
	{ 52, "cp1251", "cp1251_general_cs"},
	{ 53, "macroman", "macroman_bin"},
	{ 58, "cp1257", "cp1257_bin"},
	{ 60, "armascii8", "armascii8_bin"},
	{ 65, "ascii", "ascii_bin"},
	{ 66, "cp1250", "cp1250_bin"},
	{ 67, "cp1256", "cp1256_bin"},
	{ 68, "cp866", "cp866_bin"},
	{ 69, "dec8", "dec8_bin"},
	{ 70, "greek", "greek_bin"},
	{ 71, "hebew", "hebrew_bin"},
	{ 72, "hp8", "hp8_bin"},
	{ 73, "keybcs2", "keybcs2_bin"},
	{ 74, "koi8r", "koi8r_bin"},
	{ 75, "koi8u", "koi8u_bin"},
	{ 77, "latin2", "latin2_bin"},
	{ 78, "latin5", "latin5_bin"},
	{ 79, "latin7", "latin7_bin"},
	{ 80, "cp850", "cp850_bin"},
	{ 81, "cp852", "cp852_bin"},
	{ 82, "swe7", "swe7_bin"},
	{ 93, "geostd8", "geostd8_bin"},
	{ 83, "utf8", "utf8_bin"},
	{ 84, "big5", "big5_bin"},
	{ 85, "euckr", "euckr_bin"},
	{ 86, "gb2312", "gb2312_bin"},
	{ 87, "gbk", "gbk_bin"},
	{ 88, "sjis", "sjis_bin"},
	{ 89, "tis620", "tis620_bin"},
	{ 90, "ucs2", "ucs2_bin"},
	{ 91, "ujis", "ujis_bin"},
	{ 94, "latin1", "latin1_spanish_ci"},
	{ 96, "cp932", "cp932_bin"},
	{ 99, "cp1250", "cp1250_polish_ci"},
	{ 98, "eucjpms", "eucjpms_bin"},
	{128, "ucs2", "ucs2_unicode_ci"},
	{129, "ucs2", "ucs2_icelandic_ci"},
	{130, "ucs2", "ucs2_latvian_ci"},
	{131, "ucs2", "ucs2_romanian_ci"},
	{132, "ucs2", "ucs2_slovenian_ci"},
	{133, "ucs2", "ucs2_polish_ci"},
	{134, "ucs2", "ucs2_estonian_ci"},
	{135, "ucs2", "ucs2_spanish_ci"},
	{136, "ucs2", "ucs2_swedish_ci"},
	{137, "ucs2", "ucs2_turkish_ci"},
	{138, "ucs2", "ucs2_czech_ci"},
	{139, "ucs2", "ucs2_danish_ci"},
	{140, "ucs2", "ucs2_lithunian_ci"},
	{141, "ucs2", "ucs2_slovak_ci"},
	{142, "ucs2", "ucs2_spanish2_ci"},
	{143, "ucs2", "ucs2_roman_ci"},
	{144, "ucs2", "ucs2_persian_ci"},
	{145, "ucs2", "ucs2_esperanto_ci"},
	{146, "ucs2", "ucs2_hungarian_ci"},
	{147, "ucs2", "ucs2_sinhala_ci"},
	{192, "utf8mb3", "utf8mb3_general_ci"},
	{193, "utf8mb3", "utf8mb3_icelandic_ci"},
	{194, "utf8mb3", "utf8mb3_latvian_ci"},
	{195, "utf8mb3", "utf8mb3_romanian_ci"},
	{196, "utf8mb3", "utf8mb3_slovenian_ci"},
	{197, "utf8mb3", "utf8mb3_polish_ci"},
	{198, "utf8mb3", "utf8mb3_estonian_ci"},
	{119, "utf8mb3", "utf8mb3_spanish_ci"},
	{200, "utf8mb3", "utf8mb3_swedish_ci"},
	{201, "utf8mb3", "utf8mb3_turkish_ci"},
	{202, "utf8mb3", "utf8mb3_czech_ci"},
	{203, "utf8mb3", "utf8mb3_danish_ci"},
	{204, "utf8mb3", "utf8mb3_lithunian_ci"},
	{205, "utf8mb3", "utf8mb3_slovak_ci"},
	{206, "utf8mb3", "utf8mb3_spanish2_ci"},
	{207, "utf8mb3", "utf8mb3_roman_ci"},
	{208, "utf8mb3", "utf8mb3_persian_ci"},
	{209, "utf8mb3", "utf8mb3_esperanto_ci"},
	{210, "utf8mb3", "utf8mb3_hungarian_ci"},
	{211, "utf8mb3", "utf8mb3_sinhala_ci"},
	{224, "utf8", "utf8_unicode_ci"},
	{225, "utf8", "utf8_icelandic_ci"},
	{226, "utf8", "utf8_latvian_ci"},
	{227, "utf8", "utf8_romanian_ci"},
	{228, "utf8", "utf8_slovenian_ci"},
	{229, "utf8", "utf8_polish_ci"},
	{230, "utf8", "utf8_estonian_ci"},
	{231, "utf8", "utf8_spanish_ci"},
	{232, "utf8", "utf8_swedish_ci"},
	{233, "utf8", "utf8_turkish_ci"},
	{234, "utf8", "utf8_czech_ci"},
	{235, "utf8", "utf8_danish_ci"},
	{236, "utf8", "utf8_lithuanian_ci"},
	{237, "utf8", "utf8_slovak_ci"},
	{238, "utf8", "utf8_spanish2_ci"},
	{239, "utf8", "utf8_roman_ci"},
	{240, "utf8", "utf8_persian_ci"},
	{241, "utf8", "utf8_esperanto_ci"},
	{242, "utf8", "utf8_hungarian_ci"},
	{243, "utf8", "utf8_sinhala_ci"},
	{254, "utf8mb3", "utf8mb3_general_cs"},
	{  0, NULL, NULL}
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
		[characterSetEncoding release]; 
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
		
		// Check the information_schema.collations table is accessible
		MCPResult *result = [connection queryString:@"SHOW TABLES IN information_schema LIKE 'collations'"];
		
		if ([result numOfRows] == 1) {
			// Table is accessible so get available collations
			[collations addObjectsFromArray:[self _getDatabaseDataForQuery:@"SELECT * FROM information_schema.collations ORDER BY collation_name ASC"]];	
		}
		else {
			// Get the list of collations from our hard coded list
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
	if ((characterSetEncoding == nil) || (![characterSetEncoding isEqualToString:encoding]) || ([characterSetCollations count] == 0)) {
		
		[characterSetEncoding release];
		[characterSetCollations removeAllObjects];
		
		characterSetEncoding = [[NSString alloc] initWithString:encoding];
		
		// Check the information_schema.collations table is accessible
		MCPResult *result = [connection queryString:@"SHOW TABLES IN information_schema LIKE 'collations'"];
		
		if ([result numOfRows] == 1) {
			// Table is accessible so get available collations for the supplied encoding
			[characterSetCollations addObjectsFromArray:[self _getDatabaseDataForQuery:[NSString stringWithFormat:@"SELECT * FROM information_schema.collations WHERE character_set_name = '%@' ORDER BY collation_name ASC", characterSetEncoding]]];	
		}
		else {
			// Get the list of collations matching the supplied encoding from our hard coded list
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
				MCPResult *result = [connection queryString:@"SHOW TABLES IN information_schema LIKE 'engines'"];
				
				if ([result numOfRows] == 1) {
					// Table is accessible so get available storage engines
					[storageEngines addObjectsFromArray:[self _getDatabaseDataForQuery:@"SELECT Engine, Support FROM information_schema.engines WHERE support IN ('DEFAULT', 'YES');"]];				
				}
			}
			else {				
				// Get storage engines
				NSMutableArray *engines = [self _getDatabaseDataForQuery:@"SHOW STORAGE ENGINES"];
				
				// We only want to include engines that are supported
				for (int i = 0; i < [engines count]; i++) 
				{
					NSDictionary *engine = [engines objectAtIndex:i];
				
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
		
		// Check the information_schema.collations table is accessible
		MCPResult *result = [connection queryString:@"SHOW TABLES IN information_schema LIKE 'character_sets'"];
		
		if ([result numOfRows] == 1) {
			// Table is accessible so get available encodings for the supplied encoding
			[characterSetEncodings addObjectsFromArray:[self _getDatabaseDataForQuery:@"SELECT * FROM information_schema.character_sets ORDER BY character_set_name ASC"]];	
		}
		else {
			// Get the list of collations matching the supplied encoding from our hard coded list
			const CHAR_SETS *c = charsets;
			
			do {				
				[characterSetEncodings addObject:[NSDictionary dictionaryWithObject:[NSString stringWithCString:c->name encoding:NSUTF8StringEncoding] forKey:@"CHARACTER_SET_NAME"]];
				
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
		
		for (int i = 0; i < [result numOfRows]; i++)
		{		
			[array addObject:[result fetchRowAsDictionary]];		
		}
	}
	
	return array;
}

@end
