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
		if ([tableListInstance tableType] == SP_TABLETYPE_VIEW) {
			[self updateInformationForCurrentView];
		} else {
			[self updateInformationForCurrentTable];
		}
	}
	return [NSString stringWithString:tableEncoding];
}


/*
 * Retrieve all columns for the current table as an array, using or refreshing the cache as appropriate.
 */
- (NSArray *) columns
{
	if ([columns count] == 0) {
		if ([tableListInstance tableType] == SP_TABLETYPE_VIEW) {
			[self updateInformationForCurrentView];
		} else {
			[self updateInformationForCurrentTable];
		}
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
		if ([tableListInstance tableType] == SP_TABLETYPE_VIEW) {
			[self updateInformationForCurrentView];
		} else {
			[self updateInformationForCurrentTable];
		}
	}
	return columnNames;
}


/*
 * Retrieve a specified column for the current table as a dictionary, using or refreshing the cache as appropriate.
 */
- (NSDictionary *) columnAtIndex:(int)index
{
	if ([columns count] == 0) {
		if ([tableListInstance tableType] == SP_TABLETYPE_VIEW) {
			[self updateInformationForCurrentView];
		} else {
			[self updateInformationForCurrentTable];
		}
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
- (BOOL) updateInformationForCurrentTable
{
	NSDictionary *tableData = [self informationForTable:[tableListInstance tableName]];
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
- (NSDictionary *) informationForTable:(NSString *)tableName
{
	SPSQLParser *createTableParser, *fieldsParser, *fieldParser;
	NSMutableArray *tableColumns, *fieldStrings, *definitionParts;
	NSMutableDictionary *tableColumn, *tableData;
	NSString *encodingString;
	unsigned i, stringStart;

	// Catch unselected tables and return nil
	if ([tableName isEqualToString:@""] || !tableName) return nil;

	// Retrieve the CREATE TABLE syntax for the table
	CMMCPResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE TABLE `%@`", tableName]];

	// Check for any errors, but only display them if a connection still exists
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		if (![mySQLConnection isConnected]) {
			NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"An error occured while retrieving table information:\n\n%@", [mySQLConnection getLastErrorMessage]], @"OK", nil, nil);
		}
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

			// Split the remaining field definition string by spaces and process
			[tableColumn addEntriesFromDictionary:[self parseFieldDefinitionStringParts:[fieldsParser splitStringByCharacter:' ' skippingBrackets:YES]]];

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
 * Retrieves the information for the current view and stores it in cache.
 * Returns a boolean indicating success.
 */
- (BOOL) updateInformationForCurrentView
{
	NSDictionary *viewData = [self informationForView:[tableListInstance tableName]];
	NSDictionary *columnData;
	NSEnumerator *enumerator;

	if (viewData == nil) {
		[columns removeAllObjects];
		[columnNames removeAllObjects];
		return FALSE;
	}

	[columns addObjectsFromArray:[viewData objectForKey:@"columns"]];

	enumerator = [columns objectEnumerator];
	while (columnData = [enumerator nextObject]) {
		[columnNames addObject:[NSString stringWithString:[columnData objectForKey:@"name"]]];
	}
	
	if (tableEncoding != nil) {
		[tableEncoding release];
	}
	tableEncoding = [[NSString alloc] initWithString:[viewData objectForKey:@"encoding"]];

	return TRUE;
}


/*
 * Retrieve information which can be used to display views.  Unlike tables, all the information
 * for views cannot be extracted from the CREATE ALGORITHM syntax without selecting all the info
 * from the referenced tables.  For the time being we therefore use the column information for
 * SHOW COLUMNS (subsequently parsed), and derive the encoding from the database as no other source
 * is available.
 * Returns a boolean indicating success.
 */
- (NSDictionary *) informationForView:(NSString *)viewName
{
	SPSQLParser *fieldParser;
	NSMutableArray *tableColumns;
	NSDictionary *resultRow;
	NSMutableDictionary *tableColumn, *viewData;
	unsigned i;

	// Catch unselected views and return nil
	if ([viewName isEqualToString:@""] || !viewName) return nil;

	// Retrieve the SHOW COLUMNS syntax for the table
	CMMCPResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW COLUMNS FROM `%@`", viewName]];

	// Check for any errors, but only display them if a connection still exists
	if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		if (![mySQLConnection isConnected]) {
			NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"An error occured while retrieving view information:\n\n%@", [mySQLConnection getLastErrorMessage]], @"OK", nil, nil);
		}
		return nil;
	}

	// Loop through the fields and capture details
	if ([theResult numOfRows]) [theResult dataSeek:0];
	tableColumns = [[NSMutableArray alloc] init];
	tableColumn = [[NSMutableDictionary alloc] init];
	fieldParser = [[SPSQLParser alloc] init];
	for ( i = 0; i < [theResult numOfRows] ; i++ ) {
		[tableColumn removeAllObjects];
		resultRow = [theResult fetchRowAsDictionary];

		// Add the column name
		[tableColumn setObject:[NSString stringWithString:[resultRow objectForKey:@"Field"]] forKey:@"name"];

		// Populate type, length, and other available details from the Type columns
		[fieldParser setString:[resultRow objectForKey:@"Type"]];
		[tableColumn addEntriesFromDictionary:[self parseFieldDefinitionStringParts:[fieldParser splitStringByCharacter:' ' skippingBrackets:YES]]];

		// If there's a null column, use the details from it
		if ([resultRow objectForKey:@"Null"]) {
			if ([[[resultRow objectForKey:@"Null"] uppercaseString] isEqualToString:@"NO"]) {
				[tableColumn setValue:[NSNumber numberWithBool:NO] forKey:@"null"];
			} else {
				[tableColumn setValue:[NSNumber numberWithBool:YES] forKey:@"null"];
			}
		}

		// Select the column default if available
		if ([resultRow objectForKey:@"Default"]) {
			if ([[resultRow objectForKey:@"Default"] isNSNull]) {
				[tableColumn setValue:[NSString stringWithString:[[NSUserDefaults standardUserDefaults] objectForKey:@"nullValue"]] forKey:@"default"];			
			} else {
				[tableColumn setValue:[NSString stringWithString:[resultRow objectForKey:@"Default"]] forKey:@"default"];
			}
		}

		// Add the column to the list
		[tableColumns addObject:[NSDictionary dictionaryWithDictionary:tableColumn]];
	}
	[fieldParser release];
	[tableColumn release];

	// The character set has to be guessed at via the database encoding.
	// Add the details to the data object.
	viewData = [NSMutableDictionary dictionary];
	[viewData setObject:[NSString stringWithString:[tableDocumentInstance databaseEncoding]] forKey:@"encoding"];
	[viewData setObject:[NSArray arrayWithArray:tableColumns] forKey:@"columns"];

	[tableColumns release];

	return viewData;
}



/*
 * Retrieve the status of a table as a dictionary and add it to the local cache for reuse.
 */
- (BOOL)updateStatusInformationForCurrentTable
{

	// Catch unselected tables and return false
	if ([[tableListInstance tableName] isEqualToString:@""] || ![tableListInstance tableName])
		return FALSE;

	// When views are selected, populate the table with a default dictionary - all values, including comment, return no
	// meaningful information for views so we may as well skip the query.
	if ([tableListInstance tableType] == SP_TABLETYPE_VIEW) {
		
		[status setDictionary:[NSDictionary dictionaryWithObjectsAndKeys:@"View", @"Engine", @"No status information is available for views.", @"Comment", [tableListInstance tableName], @"Name", nil]];
		return TRUE;
	}

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


/*
 * Parse an array of field definition parts - not including name but including type and optionally unsigned/zerofill/null
 * and so forth - into a dictionary of parsed details.  Intended for use both with CREATE TABLE syntax - with fuller
 * details - and with the "type" column from SHOW COLUMNS.
 * Returns a dictionary of details with lowercase keys.
 */
- (NSDictionary *) parseFieldDefinitionStringParts:(NSArray *)definitionParts
{
	SPSQLParser *detailParser;
	SPSQLParser *fieldParser = [[SPSQLParser alloc] init];
	NSMutableDictionary *fieldDetails = [[NSMutableDictionary alloc] init];
	NSMutableArray *detailParts;
	NSString *detailString;
	int i, partsArrayLength;

	if (![definitionParts count]) return [NSDictionary dictionary];

	// The first item is always the data type.
	[fieldParser setString:[definitionParts objectAtIndex:0]];

	// If no field length definition is present, store only the type
	if ([fieldParser firstOccurrenceOfCharacter:'(' ignoringQuotedStrings:YES] == NSNotFound) {
		[fieldDetails setObject:[fieldParser uppercaseString] forKey:@"type"];

	// Otherwise separate out the length definition for processing
	} else {
		detailParser = [[SPSQLParser alloc] initWithString:[[fieldParser stringToCharacter:'(' inclusively:NO] uppercaseString]];
		[fieldDetails setObject:[NSString stringWithString:detailParser] forKey:@"type"];

		// For ENUMs and SETs, capture the field value options into an array for storage
		if ([detailParser isEqualToString:@"ENUM"] || [detailParser isEqualToString:@"SET"]) {
			[detailParser setString:[fieldParser stringFromCharacter:'(' toCharacter:')' inclusively:NO]];
			detailParts = [[NSMutableArray alloc] initWithArray:[detailParser splitStringByCharacter:',']];
			for (i = 0; i < [detailParts count]; i++) {
				[detailParser setString:[detailParts objectAtIndex:i]];
				[detailParts replaceObjectAtIndex:i withObject:[detailParser unquotedString]];
			}
			[fieldDetails setObject:[NSArray arrayWithArray:detailParts] forKey:@"values"];
			[detailParts release];

		// For types with required or optional decimals, store as appropriate
		} else if ([detailParser isEqualToString:@"REAL"] || [detailParser isEqualToString:@"DOUBLE"] || [detailParser isEqualToString:@"FLOAT"] || [detailParser isEqualToString:@"DECIMAL"] || [detailParser isEqualToString:@"NUMERIC"]) {
			[detailParser setString:[fieldParser stringFromCharacter:'(' toCharacter:')' inclusively:NO]];
			detailParts = [[NSMutableArray alloc] initWithArray:[detailParser splitStringByCharacter:',']];
			[detailParser setString:[detailParts objectAtIndex:0]];
			[fieldDetails setObject:[detailParser unquotedString] forKey:@"length"];
			if ([detailParts count] > 1) {
				[detailParser setString:[detailParts objectAtIndex:1]];
				[fieldDetails setObject:[detailParser unquotedString] forKey:@"decimals"];
			}
			[detailParts release];

		// Otherwise capture the length only.
		} else {
			[detailParser setString:[fieldParser stringFromCharacter:'(' toCharacter:')' inclusively:NO]];
			[fieldDetails setObject:[detailParser unquotedString] forKey:@"length"];
		}
		[detailParser release];
	}
	[fieldParser release];

	// Also capture a general column type "group" to allow behavioural switches
	detailString = [[NSString alloc] initWithString:[fieldDetails objectForKey:@"type"]];
	if ([detailString isEqualToString:@"BIT"]) {
		[fieldDetails setObject:@"bit" forKey:@"typegrouping"];
	} else if ([detailString isEqualToString:@"TINYINT"] || [detailString isEqualToString:@"SMALLINT"] || [detailString isEqualToString:@"MEDIUMINT"]
				|| [detailString isEqualToString:@"INT"] || [detailString isEqualToString:@"INTEGER"] || [detailString isEqualToString:@"BIGINT"]) {
		[fieldDetails setObject:@"integer" forKey:@"typegrouping"];
	} else if ([detailString isEqualToString:@"REAL"] || [detailString isEqualToString:@"DOUBLE"] || [detailString isEqualToString:@"FLOAT"]
				|| [detailString isEqualToString:@"DECIMAL"] || [detailString isEqualToString:@"NUMERIC"]) {
		[fieldDetails setObject:@"float" forKey:@"typegrouping"];
	} else if ([detailString isEqualToString:@"DATE"] || [detailString isEqualToString:@"TIME"] || [detailString isEqualToString:@"TIMESTAMP"]
				|| [detailString isEqualToString:@"DATETIME"] || [detailString isEqualToString:@"YEAR"]) {
		[fieldDetails setObject:@"date" forKey:@"typegrouping"];
	} else if ([detailString isEqualToString:@"CHAR"] || [detailString isEqualToString:@"VARCHAR"]) {
		[fieldDetails setObject:@"string" forKey:@"typegrouping"];
	} else if ([detailString isEqualToString:@"BINARY"] || [detailString isEqualToString:@"VARBINARY"]) {
		[fieldDetails setObject:@"binary" forKey:@"typegrouping"];
	} else if ([detailString isEqualToString:@"ENUM"] || [detailString isEqualToString:@"SET"]) {
		[fieldDetails setObject:@"enum" forKey:@"typegrouping"];
	} else if ([detailString isEqualToString:@"TINYTEXT"] || [detailString isEqualToString:@"TEXT"]
				|| [detailString isEqualToString:@"MEDIUMTEXT"] || [detailString isEqualToString:@"LONGTEXT"]) {
		[fieldDetails setObject:@"textdata" forKey:@"typegrouping"];

	// Default to "blobdata".  This means that future and currently unsupported types - including spatial extensions -
	// will be preserved unmangled.
	} else {
		[fieldDetails setObject:@"blobdata" forKey:@"typegrouping"];
	}
	[detailString release];

	// Set up some column defaults for all columns
	[fieldDetails setValue:[NSNumber numberWithBool:YES] forKey:@"null"];
	[fieldDetails setValue:[NSNumber numberWithBool:NO] forKey:@"unsigned"];
	[fieldDetails setValue:[NSNumber numberWithBool:NO] forKey:@"binary"];
	[fieldDetails setValue:[NSNumber numberWithBool:NO] forKey:@"zerofill"];
	[fieldDetails setValue:[NSNumber numberWithBool:NO] forKey:@"autoincrement"];

	// Walk through the remaining column definition parts storing recognised details
	partsArrayLength = [definitionParts count];
	for (i = 1; i < partsArrayLength; i++) {
		detailString = [[NSString alloc] initWithString:[[definitionParts objectAtIndex:i] uppercaseString]];

		// Whether numeric fields are unsigned
		if ([detailString isEqualToString:@"UNSIGNED"]) {
			[fieldDetails setValue:[NSNumber numberWithBool:YES] forKey:@"unsigned"];

		// Whether numeric fields are zerofill
		} else if ([detailString isEqualToString:@"ZEROFILL"]) {
			[fieldDetails setValue:[NSNumber numberWithBool:YES] forKey:@"zerofill"];

		// Whether text types are binary
		} else if ([detailString isEqualToString:@"BINARY"]) {
			[fieldDetails setValue:[NSNumber numberWithBool:YES] forKey:@"binary"];

		// Whether text types have a different encoding to the table
		} else if ([detailString isEqualToString:@"CHARSET"] && (i + 1 < partsArrayLength)) {
			if (![[[definitionParts objectAtIndex:i+1] uppercaseString] isEqualToString:@"DEFAULT"]) {
				[fieldDetails setValue:[definitionParts objectAtIndex:i+1] forKey:@"encoding"];
			}
			i++;
		} else if ([detailString isEqualToString:@"CHARACTER"] && (i + 2 < partsArrayLength)
					&& [[[definitionParts objectAtIndex:i+1] uppercaseString] isEqualToString:@"SET"]) {
			if (![[[definitionParts objectAtIndex:i+2] uppercaseString] isEqualToString:@"DEFAULT"]) {;
				[fieldDetails setValue:[definitionParts objectAtIndex:i+2] forKey:@"encoding"];
			}
			i = i + 2;

		// Whether text types have a different collation to the table
		} else if ([detailString isEqualToString:@"COLLATE"] && (i + 1 < partsArrayLength)) {
			if (![[[definitionParts objectAtIndex:i+1] uppercaseString] isEqualToString:@"DEFAULT"]) {
				[fieldDetails setValue:[definitionParts objectAtIndex:i+1] forKey:@"collation"];
			}
			i++;

		// Whether fields are NOT NULL
		} else if ([detailString isEqualToString:@"NOT"] && (i + 1 < partsArrayLength)
					&& [[[definitionParts objectAtIndex:i+1] uppercaseString] isEqualToString:@"NULL"]) {
			[fieldDetails setValue:[NSNumber numberWithBool:NO] forKey:@"null"];
			i++;

		// Whether fields are NULL
		} else if ([detailString isEqualToString:@"NULL"]) {
			[fieldDetails setValue:[NSNumber numberWithBool:YES] forKey:@"null"];

		// Whether fields should auto-increment
		} else if ([detailString isEqualToString:@"AUTO_INCREMENT"]) {
			[fieldDetails setValue:[NSNumber numberWithBool:YES] forKey:@"autoincrement"];

		// Field defaults
		} else if ([detailString isEqualToString:@"DEFAULT"] && (i + 1 < partsArrayLength)) {
			detailParser = [[SPSQLParser alloc] initWithString:[definitionParts objectAtIndex:i+1]];
			[fieldDetails setValue:[detailParser unquotedString] forKey:@"default"];
			[detailParser release];
			i++;
		}

		// TODO: Currently unhandled: [UNIQUE | PRIMARY] KEY | COMMENT 'foo' | COLUMN_FORMAT bar | STORAGE q | REFERENCES...

		[detailString release];
	}

	return [fieldDetails autorelease];
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
