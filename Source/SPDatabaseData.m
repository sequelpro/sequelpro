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
#import "SPServerSupport.h"
#import "SPDatabaseCharacterSets.h"
#import "SPMySQL.h"

@interface SPDatabaseData (PrivateAPI)

- (NSArray *)_getDatabaseDataForQuery:(NSString *)query;

NSInteger _sortMySQL4CharsetEntry(NSDictionary *itemOne, NSDictionary *itemTwo, void *context);

@end

@implementation SPDatabaseData

@synthesize connection;
@synthesize serverSupport;

#pragma mark -
#pragma mark Initialization

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
		
		cachedCollationsByEncoding = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}

#pragma mark -
#pragma mark Public API

/**
 * Reset all the cached values.
 */
- (void)resetAllData
{
	if (characterSetEncoding != nil) [characterSetEncoding release], characterSetEncoding = nil; 
	
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
		if ([serverSupport supportsInformationSchema]) {
			[collations addObjectsFromArray:[self _getDatabaseDataForQuery:@"SELECT * FROM `information_schema`.`collations` ORDER BY `collation_name` ASC"]];	
		}
		
		// If that failed, get the list of collations from the hard-coded list
		if (![collations count]) {
			const SPDatabaseCharSets *c = SPGetDatabaseCharacterSets();
			
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

		if([cachedCollationsByEncoding objectForKey:characterSetEncoding] && [[cachedCollationsByEncoding objectForKey:characterSetEncoding] count])
			return [cachedCollationsByEncoding objectForKey:characterSetEncoding];

		// Try to retrieve the available collations for the supplied encoding from the database
		if ([serverSupport supportsInformationSchema]) {
			[characterSetCollations addObjectsFromArray:[self _getDatabaseDataForQuery:[NSString stringWithFormat:@"SELECT * FROM `information_schema`.`collations` WHERE character_set_name = '%@' ORDER BY `collation_name` ASC", characterSetEncoding]]];
		}

		// If that failed, get the list of collations matching the supplied encoding from the hard-coded list
		if (![characterSetCollations count]) {
			const SPDatabaseCharSets *c = SPGetDatabaseCharacterSets();
			
			do {
				NSString *charSet = [NSString stringWithCString:c->name encoding:NSUTF8StringEncoding];

				if ([charSet isEqualToString:characterSetEncoding]) {
					[characterSetCollations addObject:[NSDictionary dictionaryWithObject:[NSString stringWithCString:c->collation encoding:NSUTF8StringEncoding] forKey:@"COLLATION_NAME"]];
				}

				++c;
			} 
			while (c[0].nr != 0);
		}

		if (characterSetCollations && [characterSetCollations count]) {
			[cachedCollationsByEncoding setObject:[NSArray arrayWithArray:characterSetCollations] forKey:characterSetEncoding];
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
		if ([serverSupport isMySQL3] || [serverSupport isMySQL4]) {
			[storageEngines addObject:[NSDictionary dictionaryWithObject:@"MyISAM" forKey:@"Engine"]];
			
			// Check if InnoDB support is enabled
			SPMySQLResult *result = [connection queryString:@"SHOW VARIABLES LIKE 'have_innodb'"];
			
			[result setReturnDataAsStrings:YES];
			
			if ([result numberOfRows] == 1) {
				if ([[[result getRowAsDictionary] objectForKey:@"Value"] isEqualToString:@"YES"]) {
					[storageEngines addObject:[NSDictionary dictionaryWithObject:@"InnoDB" forKey:@"Engine"]];
				}
			}
			
			// Before MySQL 4.1 the MEMORY engine was known as HEAP and the ISAM engine was included
			if ([serverSupport supportsPre41StorageEngines]) {
				[storageEngines addObject:[NSDictionary dictionaryWithObject:@"HEAP" forKey:@"Engine"]];
				[storageEngines addObject:[NSDictionary dictionaryWithObject:@"ISAM" forKey:@"Engine"]];
			}
			else {
				[storageEngines addObject:[NSDictionary dictionaryWithObject:@"MEMORY" forKey:@"Engine"]];
			}
			
			// BLACKHOLE storage engine was added in MySQL 4.1.11
			if ([serverSupport supportsBlackholeStorageEngine]) {
				[storageEngines addObject:[NSDictionary dictionaryWithObject:@"BLACKHOLE" forKey:@"Engine"]];
			}
				
			// ARCHIVE storage engine was added in MySQL 4.1.3
			if ([serverSupport supportsArchiveStorageEngine]) {
				[storageEngines addObject:[NSDictionary dictionaryWithObject:@"ARCHIVE" forKey:@"Engine"]];
			}
			
			// CSV storage engine was added in MySQL 4.1.4
			if ([serverSupport supportsCSVStorageEngine]) {
				[storageEngines addObject:[NSDictionary dictionaryWithObject:@"CSV" forKey:@"Engine"]];
			}
		}
		// The table information_schema.engines didn't exist until MySQL 5.1.5
		else {
			if ([serverSupport supportsInformationSchemaEngines])
			{
				// Check the information_schema.engines table is accessible
				SPMySQLResult *result = [connection queryString:@"SHOW TABLES IN information_schema LIKE 'ENGINES'"];
				
				if ([result numberOfRows] == 1) {
					
					// Table is accessible so get available storage engines
					// Note, that the case of the column names specified in this query are important.
					[storageEngines addObjectsFromArray:[self _getDatabaseDataForQuery:@"SELECT Engine, Support FROM `information_schema`.`engines` WHERE SUPPORT IN ('DEFAULT', 'YES')"]];				
				}
			}
			else {				
				// Get storage engines
				NSArray *engines = [self _getDatabaseDataForQuery:@"SHOW STORAGE ENGINES"];
				
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
		if ([serverSupport supportsInformationSchema]) {
			[characterSetEncodings addObjectsFromArray:[self _getDatabaseDataForQuery:@"SELECT * FROM `information_schema`.`character_sets` ORDER BY `character_set_name` ASC"]];
		} 
		else if ([serverSupport supportsShowCharacterSet]) {
			NSArray *supportedEncodings = [self _getDatabaseDataForQuery:@"SHOW CHARACTER SET"];
			
			supportedEncodings = [supportedEncodings sortedArrayUsingFunction:_sortMySQL4CharsetEntry context:nil];
			
			for (NSDictionary *anEncoding in supportedEncodings) 
			{
				NSDictionary *convertedEncoding = [NSDictionary dictionaryWithObjectsAndKeys:
													[anEncoding objectForKey:@"Charset"], @"CHARACTER_SET_NAME",
													[anEncoding objectForKey:@"Description"], @"DESCRIPTION",
													[anEncoding objectForKey:@"Default collation"], @"DEFAULT_COLLATE_NAME",
													[anEncoding objectForKey:@"Maxlen"], @"MAXLEN",
													nil];
				
				[characterSetEncodings addObject:convertedEncoding];
			}
		}

		// If that failed, get the list of character set encodings from the hard-coded list
		if (![characterSetEncodings count]) {			
			const SPDatabaseCharSets *c = SPGetDatabaseCharacterSets();

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

#pragma mark -
#pragma mark Other

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
	[cachedCollationsByEncoding release], cachedCollationsByEncoding = nil;
	
	[super dealloc];
}

#pragma mark -
#pragma mark Private API

/**
 * Executes the supplied query against the current connection and returns the result as an array of 
 * NSDictionarys, one for each row.
 */
- (NSArray *)_getDatabaseDataForQuery:(NSString *)query
{
	SPMySQLResult *result = [connection queryString:query];

	if ([connection queryErrored]) return [NSArray array];

	[result setReturnDataAsStrings:YES];
	return [result getAllRows];
}

/**
 * Sorts a 4.1-style SHOW CHARACTER SET result by the Charset key.
 */
NSInteger _sortMySQL4CharsetEntry(NSDictionary *itemOne, NSDictionary *itemTwo, void *context)
{
	return [[itemOne objectForKey:@"Charset"] compare:[itemTwo objectForKey:@"Charset"]];
}

@end
