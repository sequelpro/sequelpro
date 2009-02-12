//
//  SPTableData.m
//  sequel-pro
//
//  Created by Rowan Beentje on 24/01/2009.
//  Copyright 2009 Arboreal. All rights reserved.
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

#import "CMMCPConnection.h"
#import "CMMCPResult.h"
#import <MCPKit_bundled/MCPKit_bundled.h>
#import "SPTableData.h"
#import "SPSQLParser.h"
#import "TableDocument.h"
#import "TablesList.h"


@implementation SPTableData


- (id) init
{
	if ((self = [super init])) {
		columns = [[NSMutableArray alloc] init];
		columnNames = [[NSMutableArray alloc] init];
		status = [[NSMutableDictionary alloc] init];
		tableEncoding = nil;
		mySQLConnection = nil;
	}

	return self;
}

/*
 * Set the connection for use.
 * Called by the connect sheet methods.
 */
- (void) setConnection:(CMMCPConnection *)theConnection
{
	mySQLConnection = theConnection;
	[mySQLConnection retain];
}

 
/*
 * Retrieve the encoding for the current table, using or refreshing the cache as appropriate.
 */
- (NSString *) tableEncoding
{
	if (tableEncoding == nil) {
		[self updateInformationFromCreateTableForCurrentTable];
	}
	return [NSString stringWithString:tableEncoding];
}


/*
 * Retrieve all columns for the current table as an array, using or refreshing the cache as appropriate.
 */
- (NSArray *) columns
{
	if ([columns count] == 0) {
		[self updateInformationFromCreateTableForCurrentTable];
	}
	return columns;
}


/*
 * Retrieve a column with a specified name, using or refreshing the cache as appropriate.
 */
- (NSDictionary *) columnWithName:(NSString *)colName
{
	int columnIndex = [columnNames indexOfObject:colName];
	return [columns objectAtIndex:columnIndex];
}


/*
 * Retrieve column names for the current table as an array, using or refreshing the cache as appropriate.
 */
- (NSArray *) columnNames
{
	if ([columnNames count] == 0) {
		[self updateInformationFromCreateTableForCurrentTable];
	}
	return columnNames;
}


/*
 * Retrieve a specified column for the current table as a dictionary, using or refreshing the cache as appropriate.
 */
- (NSDictionary *) columnAtIndex:(int)index
{
	if ([columns count] == 0) {
		[self updateInformationFromCreateTableForCurrentTable];
	}
	return [columns objectAtIndex:index];
}


/*
 * Retrieve the table status value for a supplied key, using or refreshing the cache as appropriate.
 */
- (NSString *) statusValueForKey:(NSString *)aKey
{
	if ([status count] == 0) {
		[self updateStatusInformationForCurrentTable];
	}
	return [status objectForKey:aKey];
}


/*
 * Retrieve all known status values as a dictionary, using or refreshing the cache as appropriate.
 */
- (NSDictionary *) statusValues
{
	if ([status count] == 0) {
		[self updateStatusInformationForCurrentTable];
	}
	return status;
}


/*
 * Flushes all caches - should be used on major changes, for example table changes.
 */
- (void) resetAllData
{
	[columns removeAllObjects];
	[columnNames removeAllObjects];
	[status removeAllObjects];
	if (tableEncoding != nil) {
		[tableEncoding release];
		tableEncoding = nil;
	}
}


/*
 * Flushes any status-related caches.
 */
- (void) resetStatusData
{
	[status removeAllObjects];
}


/*
 * Flushes any field/column-related caches.
 */
- (void) resetColumnData
{
	[columns removeAllObjects];
	[columnNames removeAllObjects];
}


/*
 * Retrieves the information for the current table and stores it in cache.
 * Returns a boolean indicating success.
 */
- (BOOL) updateInformationFromCreateTableForCurrentTable
{
	NSDictionary *tableData = [self informationFromCreateTableSyntaxForTable:[tableListInstance tableName]];
	NSDictionary *columnData;
	NSEnumerator *enumerator;

	if (tableData == nil) {
		[columns removeAllObjects];
		[columnNames removeAllObjects];
		return FALSE;
	}

	[columns addObjectsFromArray:[tableData objectForKey:@"columns"]];

	enumerator = [columns objectEnumerator];
	while (columnData = [enumerator nextObject]) {
		[columnNames addObject:[NSString stringWithString:[columnData objectForKey:@"name"]]];
	}
	
	if (tableEncoding != nil) {
		[tableEncoding release];
	}
	tableEncoding = [[NSString alloc] initWithString:[tableData objectForKey:@"encoding"]];

	return TRUE;
}


/*
 * Retrieve the CREATE TABLE string for a table and analyse it to extract the field
 * details and table encoding.
 * In future this could also be used to retrieve the majority of index information
 * assuming information like cardinality isn't needed.
 * This function is rather long due to the painful parsing required, but is fast.
 * Returns a boolean indicating success.
 */
- (NSDictionary *) informationFromCreateTableSyntaxForTable:(NSString *)tableName
{
	SPSQLParser *createTableParser, *fieldsParser, *fieldParser, *detailParser;
	NSMutableArray *tableColumns, *fieldStrings, *definitionParts, *detailParts;
	NSMutableDictionary *tableColumn, *tableData;
	NSString *detailString, *encodingString;
	unsigned i, j, stringStart, partsArrayLength;

	// Catch unselected tables and return nil
	if ([tableName isEqualToString:@""] || !tableName) return nil;

	// Retrieve the CREATE TABLE syntax for the table
	CMMCPResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE TABLE `%@`", tableName]];

	// Check for any errors
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"An error occured while retrieving table information:\n\n%@", [mySQLConnection getLastErrorMessage]], @"OK", nil, nil);
		return nil;
	}

	// Retrieve the table syntax string
	NSArray *syntaxResult = [theResult fetchRowAsArray];
	if ([[syntaxResult objectAtIndex:1] isKindOfClass:[NSData class]]) {
		createTableParser = [[SPSQLParser alloc] initWithData:[syntaxResult objectAtIndex:1] encoding:[mySQLConnection encoding]]; 
	} else {
		createTableParser = [[SPSQLParser alloc] initWithString:[syntaxResult objectAtIndex:1]];
	}

	// Extract the fields definition string from the CREATE TABLE syntax
	fieldsParser = [[SPSQLParser alloc] initWithString:[createTableParser trimAndReturnStringFromCharacter:'(' toCharacter:')' trimmingInclusively:YES returningInclusively:NO skippingBrackets:YES]];

	// Split the fields and keys string into an array of individual elements
	fieldStrings = [[NSMutableArray alloc] initWithArray:[fieldsParser splitStringByCharacter:',' skippingBrackets:YES]];

	// fieldStrings should now hold unparsed field and key strings, while tableProperty string holds unparsed
	// table information.  Proceed further by parsing the field strings.
	tableColumns = [[NSMutableArray alloc] init];
	tableColumn = [[NSMutableDictionary alloc] init];
	definitionParts = [[NSMutableArray alloc] init];
	fieldParser = [[SPSQLParser alloc] init];
	for (i = 0; i < [fieldStrings count]; i++) {

		// Take this field/key string, trim whitespace from both ends and remove comments
		[fieldsParser setString:[[fieldStrings objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
		[fieldsParser deleteComments];
		if (![fieldsParser length]) {
			continue;
		}
		[tableColumn removeAllObjects];
		[definitionParts removeAllObjects];

		// If the first character is a backtick, this is a field definition.
		if ([fieldsParser characterAtIndex:0] =='`') {

			// Capture the area between the two backticks as the name
			[tableColumn setObject:[fieldsParser trimAndReturnStringFromCharacter:'`' toCharacter:'`' trimmingInclusively:YES returningInclusively:NO ignoringQuotedStrings:NO] forKey:@"name"];

			// Split the remaining field definition string by spaces ready for processing
			[definitionParts addObjectsFromArray:[fieldsParser splitStringByCharacter:' ' skippingBrackets:YES]];

			// The first item is always the data type.
			[fieldParser setString:[definitionParts objectAtIndex:0]];

			// If no field length definition is present, store only the type
			if ([fieldParser firstOccurrenceOfCharacter:'(' ignoringQuotedStrings:YES] == NSNotFound) {
				[tableColumn setObject:[fieldParser uppercaseString] forKey:@"type"];

			// Otherwise separate out the length definition for processing
			} else {
				detailParser = [[SPSQLParser alloc] initWithString:[[fieldParser stringToCharacter:'(' inclusively:NO] uppercaseString]];
				[tableColumn setObject:[NSString stringWithString:detailParser] forKey:@"type"];

				// For ENUMs and SETs, capture the field value options into an array for storage
				if ([detailParser isEqualToString:@"ENUM"] || [detailParser isEqualToString:@"SET"]) {
					[detailParser setString:[fieldParser stringFromCharacter:'(' toCharacter:')' inclusively:NO]];
					detailParts = [[NSMutableArray alloc] initWithArray:[detailParser splitStringByCharacter:',']];
					for (j = 0; j < [detailParts count]; j++) {
						[detailParser setString:[detailParts objectAtIndex:j]];
						[detailParts replaceObjectAtIndex:j withObject:[detailParser unquotedString]];
					}
					[tableColumn setObject:[NSArray arrayWithArray:detailParts] forKey:@"values"];
					[detailParts release];

				// For types with required or optional decimals, store as appropriate
				} else if ([detailParser isEqualToString:@"REAL"] || [detailParser isEqualToString:@"DOUBLE"] || [detailParser isEqualToString:@"FLOAT"] || [detailParser isEqualToString:@"DECIMAL"] || [detailParser isEqualToString:@"NUMERIC"]) {
					[detailParser setString:[fieldParser stringFromCharacter:'(' toCharacter:')' inclusively:NO]];
					detailParts = [[NSMutableArray alloc] initWithArray:[detailParser splitStringByCharacter:',']];
					[detailParser setString:[detailParts objectAtIndex:0]];
					[tableColumn setObject:[detailParser unquotedString] forKey:@"length"];
					if ([detailParts count] > 1) {
						[detailParser setString:[detailParts objectAtIndex:1]];
						[tableColumn setObject:[detailParser unquotedString] forKey:@"decimals"];
					}
					[detailParts release];

				// Otherwise capture the length only.
				} else {
					[detailParser setString:[fieldParser stringFromCharacter:'(' toCharacter:')' inclusively:NO]];
					[tableColumn setObject:[detailParser unquotedString] forKey:@"length"];
				}
				[detailParser release];
			}

			// Also capture a general column type "group" to allow behavioural switches
			detailString = [[NSString alloc] initWithString:[tableColumn objectForKey:@"type"]];
			if ([detailString isEqualToString:@"BIT"]) {
				[tableColumn setObject:@"bit" forKey:@"typegrouping"];
			} else if ([detailString isEqualToString:@"TINYINT"] || [detailString isEqualToString:@"SMALLINT"] || [detailString isEqualToString:@"MEDIUMINT"]
						|| [detailString isEqualToString:@"INT"] || [detailString isEqualToString:@"INTEGER"] || [detailString isEqualToString:@"BIGINT"]) {
				[tableColumn setObject:@"integer" forKey:@"typegrouping"];
			} else if ([detailString isEqualToString:@"REAL"] || [detailString isEqualToString:@"DOUBLE"] || [detailString isEqualToString:@"FLOAT"]
						|| [detailString isEqualToString:@"DECIMAL"] || [detailString isEqualToString:@"NUMERIC"]) {
				[tableColumn setObject:@"float" forKey:@"typegrouping"];
			} else if ([detailString isEqualToString:@"DATE"] || [detailString isEqualToString:@"TIME"] || [detailString isEqualToString:@"TIMESTAMP"]
						|| [detailString isEqualToString:@"DATETIME"] || [detailString isEqualToString:@"YEAR"]) {
				[tableColumn setObject:@"date" forKey:@"typegrouping"];
			} else if ([detailString isEqualToString:@"CHAR"] || [detailString isEqualToString:@"VARCHAR"]) {
				[tableColumn setObject:@"string" forKey:@"typegrouping"];
			} else if ([detailString isEqualToString:@"BINARY"] || [detailString isEqualToString:@"VARBINARY"]) {
				[tableColumn setObject:@"binary" forKey:@"typegrouping"];
			} else if ([detailString isEqualToString:@"ENUM"] || [detailString isEqualToString:@"SET"]) {
				[tableColumn setObject:@"enum" forKey:@"typegrouping"];
			} else if ([detailString isEqualToString:@"TINYTEXT"] || [detailString isEqualToString:@"TEXT"]
						|| [detailString isEqualToString:@"MEDIUMTEXT"] || [detailString isEqualToString:@"LONGTEXT"]) {
				[tableColumn setObject:@"textdata" forKey:@"typegrouping"];

			// Default to "blobdata".  This means that future and currently unsupported types - including spatial extensions -
			// will be preserved unmangled.
			} else {
				[tableColumn setObject:@"blobdata" forKey:@"typegrouping"];
			}

			// Set up some column defaults for all columns
			[tableColumn setValue:[NSNumber numberWithBool:YES] forKey:@"null"];
			[tableColumn setValue:[NSNumber numberWithBool:NO] forKey:@"unsigned"];
			[tableColumn setValue:[NSNumber numberWithBool:NO] forKey:@"binary"];
			[tableColumn setValue:[NSNumber numberWithBool:NO] forKey:@"zerofill"];
			[tableColumn setValue:[NSNumber numberWithBool:NO] forKey:@"autoincrement"];

			// Walk through the remaining column definition parts storing recognised details
			partsArrayLength = [definitionParts count];
			for (j = 1; j < partsArrayLength; j++) {
				detailString = [[NSString alloc] initWithString:[[definitionParts objectAtIndex:j] uppercaseString]];

				// Whether numeric fields are unsigned
				if ([detailString isEqualToString:@"UNSIGNED"]) {
					[tableColumn setValue:[NSNumber numberWithBool:YES] forKey:@"unsigned"];

				// Whether numeric fields are zerofill
				} else if ([detailString isEqualToString:@"ZEROFILL"]) {
					[tableColumn setValue:[NSNumber numberWithBool:YES] forKey:@"zerofill"];

				// Whether text types are binary
				} else if ([detailString isEqualToString:@"BINARY"]) {
					[tableColumn setValue:[NSNumber numberWithBool:YES] forKey:@"binary"];

				// Whether text types have a different encoding to the table
				} else if ([detailString isEqualToString:@"CHARSET"] && (j + 1 < partsArrayLength)) {
					if (![[[definitionParts objectAtIndex:j+1] uppercaseString] isEqualToString:@"DEFAULT"]) {
						[tableColumn setValue:[definitionParts objectAtIndex:j+1] forKey:@"encoding"];
					}
					j++;
				} else if ([detailString isEqualToString:@"CHARACTER"] && (j + 2 < partsArrayLength)
							&& [[[definitionParts objectAtIndex:j+1] uppercaseString] isEqualToString:@"SET"]) {
					if (![[[definitionParts objectAtIndex:j+2] uppercaseString] isEqualToString:@"DEFAULT"]) {;
						[tableColumn setValue:[definitionParts objectAtIndex:j+2] forKey:@"encoding"];
					}
					j = j + 2;

				// Whether text types have a different collation to the table
				} else if ([detailString isEqualToString:@"COLLATE"] && (j + 1 < partsArrayLength)) {
					if (![[[definitionParts objectAtIndex:j+1] uppercaseString] isEqualToString:@"DEFAULT"]) {
						[tableColumn setValue:[definitionParts objectAtIndex:j+1] forKey:@"collation"];
					}
					j++;

				// Whether fields are NOT NULL
				} else if ([detailString isEqualToString:@"NOT"] && (j + 1 < partsArrayLength)
							&& [[[definitionParts objectAtIndex:j+1] uppercaseString] isEqualToString:@"NULL"]) {
					[tableColumn setValue:[NSNumber numberWithBool:NO] forKey:@"null"];
					j++;

				// Whether fields are NULL
				} else if ([detailString isEqualToString:@"NULL"]) {
					[tableColumn setValue:[NSNumber numberWithBool:YES] forKey:@"null"];

				// Whether fields should auto-increment
				} else if ([detailString isEqualToString:@"AUTO_INCREMENT"]) {
					[tableColumn setValue:[NSNumber numberWithBool:YES] forKey:@"autoincrement"];

				// Field defaults
				} else if ([detailString isEqualToString:@"DEFAULT"] && (j + 1 < partsArrayLength)) {
					detailParser = [[SPSQLParser alloc] initWithString:[definitionParts objectAtIndex:j+1]];
					[tableColumn setValue:[detailParser unquotedString] forKey:@"default"];
					[detailParser release];
					j++;
				}

				// TODO: Currently unhandled: [UNIQUE | PRIMARY] KEY | COMMENT 'foo' | COLUMN_FORMAT bar | STORAGE q | REFERENCES...

				[detailString release];
			}

			// Store the column.
			[tableColumns addObject:[NSDictionary dictionaryWithDictionary:tableColumn]];

		// TODO: Otherwise it's a key definition, constraint, check, or other 'metadata'.  Would be useful to parse/display these!
		} else {

		}
	}
	[fieldStrings release];
	[fieldsParser release];
	[definitionParts release];
	[tableColumn release];

	// Extract the encoding from the table properties string - other details come from TABLE STATUS.
	NSRange charsetDefinitionRange = [createTableParser rangeOfString:@"CHARSET=" options:NSCaseInsensitiveSearch];
	if (charsetDefinitionRange.location == NSNotFound) {
		charsetDefinitionRange = [createTableParser rangeOfString:@"CHARACTER SET=" options:NSCaseInsensitiveSearch];
	}
	if (charsetDefinitionRange.location != NSNotFound) {
		stringStart = charsetDefinitionRange.location + charsetDefinitionRange.length;
		for (i = stringStart; i < [createTableParser length]; i++) {
			if ([createTableParser characterAtIndex:i] == ' ') break;
		}

		// Catch the "default" character encoding:
		if ([[[createTableParser substringWithRange:NSMakeRange(stringStart, i-stringStart)] lowercaseString] isEqualToString:@"default"]) {
			encodingString = [[NSString alloc] initWithString:[tableDocumentInstance databaseEncoding]];
		} else {
			encodingString = [[NSString alloc] initWithString:[createTableParser substringWithRange:NSMakeRange(stringStart, i-stringStart)]];
		}

	// If no DEFAULT CHARSET is present, it's likely MySQL < 4; fall back to latin1.
	} else {
		encodingString = [[NSString alloc] initWithString:@"latin1"];
	}

	[createTableParser release];
	[fieldParser release];

	tableData = [NSMutableDictionary dictionary];
	[tableData setObject:[NSString stringWithString:encodingString] forKey:@"encoding"];
	[tableData setObject:[NSArray arrayWithArray:tableColumns] forKey:@"columns"];

	[encodingString release];
	[tableColumns release];

	return tableData;
}


/*
 * Retrieve the status of a table as a dictionary and add it to the local cache for reuse.
 */
- (BOOL) updateStatusInformationForCurrentTable
{

	// Catch unselected tables and return nil
	if ([[tableListInstance tableName] isEqualToString:@""] || ![tableListInstance tableName]) return nil;

	// Run the status query and retrieve as a dictionary.
	CMMCPResult *tableStatusResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW TABLE STATUS LIKE '%@'", [tableListInstance tableName]]];

	// Check for any errors
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"An error occured while retrieving table status:\n\n%@", [mySQLConnection getLastErrorMessage]],  @"OK", nil, nil);
		return FALSE;
	}

	// Retrieve the status as a dictionary and set as the cache
	[status setDictionary:[tableStatusResult fetchRowAsDictionary]];

	// Reassign any "Type" key - for MySQL < 4.1 - to "Engine" for consistency.
	if ([status objectForKey:@"Type"]) {
		[status setObject:[status objectForKey:@"Type"] forKey:@"Engine"];
	}

	return TRUE;
}


- (void) dealloc
{
	[columns release];
	[columnNames release];
	[status release];
	if (tableEncoding != nil) [tableEncoding release];

	[super dealloc];
}

@end
