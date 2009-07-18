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
		[collations addObjectsFromArray:[self _getDatabaseDataForQuery:@"SELECT * FROM information_schema.collations ORDER BY collation_name ASC"]];
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
		
		[characterSetCollations addObjectsFromArray:[self _getDatabaseDataForQuery:[NSString stringWithFormat:@"SELECT * FROM information_schema.collations WHERE character_set_name = '%@' ORDER BY collation_name ASC", characterSetEncoding]]];
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
		[characterSetEncodings addObjectsFromArray:[self _getDatabaseDataForQuery:@"SELECT * FROM information_schema.character_sets ORDER BY character_set_name ASC"]];
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
	if (![[connection getLastErrorMessage] isEqualToString:@""]) {
		NSLog(@"Error executing query in %@. MySQL said: %@", [self className], [connection getLastErrorMessage]);
	}
	else {
		[result dataSeek:0];
		
		for (int i = 0; i < [result numOfRows]; i++)
		{		
			[array addObject:[result fetchRowAsDictionary]];		
		}
	}
	
	return array;
}

@end
