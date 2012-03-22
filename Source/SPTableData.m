//
//  $Id$
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

#import "SPTableData.h"
#import "SPSQLParser.h"
#import "SPDatabaseDocument.h"
#import "SPTablesList.h"
#import "SPAlertSheets.h"
#import "RegexKitLite.h"
#import "SPServerSupport.h"
#import "SPMySQL.h"
#include <pthread.h>

@interface SPTableData (PrivateAPI)

- (void)_loopWhileWorking;

@end

@implementation SPTableData

@synthesize tableHasAutoIncrementField;

/**
 * Init class.
 */
- (id) init
{
	if ((self = [super init])) {
		columns = [[NSMutableArray alloc] init];
		columnNames = [[NSMutableArray alloc] init];
		constraints = [[NSMutableArray alloc] init];
		status = [[NSMutableDictionary alloc] init];
		primaryKeyColumns = [[NSMutableArray alloc] init];

		triggers = nil;
		tableEncoding = nil;
		tableCreateSyntax = nil;
		mySQLConnection = nil;
		tableHasAutoIncrementField = NO;

		pthread_mutex_init(&dataProcessingLock, NULL);
	}

	return self;
}

/**
 * Set the connection for use.
 * Called by the connect sheet methods.
 *
 * @param theConnection The used connection for the SPDatabaseDocument
 */
- (void) setConnection:(SPMySQLConnection *)theConnection
{
	mySQLConnection = theConnection;
	[mySQLConnection retain];
}

/**
 * Retrieve the encoding for the current table, using or refreshing the cache as appropriate.
 */
- (NSString *) tableEncoding
{

	// If processing is already in action, wait for it to complete
	[self _loopWhileWorking];

	if (tableEncoding == nil) {
		if ([tableListInstance tableType] == SPTableTypeView) {
			[self updateInformationForCurrentView];
		} else {
			[self updateInformationForCurrentTable];
		}
	}
	return (tableEncoding == nil) ? nil : [NSString stringWithString:tableEncoding];
}

/**
 * Retrieve the create syntax for the current table, using or refreshing the cache as appropriate.
 */
- (NSString *) tableCreateSyntax
{

	// If processing is already in action, wait for it to complete
	[self _loopWhileWorking];

	if (tableCreateSyntax == nil) {
		if ([tableListInstance tableType] == SPTableTypeView) {
			[self updateInformationForCurrentView];
		}
		else {
			[self updateInformationForCurrentTable];
		}
	}

	// On failure, return nil
	if (!tableCreateSyntax) return nil;

	return [NSString stringWithString:tableCreateSyntax];
}

/**
 * Retrieve all columns for the current table as an array, using or refreshing the cache as appropriate.
 */
- (NSArray *) columns
{

	// If processing is already in action, wait for it to complete
	[self _loopWhileWorking];

	if ([columns count] == 0) {
		if ([tableListInstance tableType] == SPTableTypeView) {
			[self updateInformationForCurrentView];
		} else {
			[self updateInformationForCurrentTable];
		}
	}
	return columns;
}

/**
 * Retrieve all constraints.
 */
- (NSArray *) getConstraints
{
	return constraints;
}

/**
 * Retrieve all triggers used in the current selected table.
 */
- (NSArray *) triggers
{
	// If processing is already in action, wait for it to complete
	[self _loopWhileWorking];	

	// If triggers is nil, the triggers need to be loaded - if a table is selected on MySQL >= 5.0.2
	if (!triggers) {
		if (([tableListInstance tableType] == SPTableTypeTable) && [[tableDocumentInstance serverSupport] supportsTriggers]) {
			[self updateTriggersForCurrentTable];
		} 
		else {
			return [NSArray array];
		}
	}

	return triggers;
}

/**
 * Retrieve a NSDictionary containing all parameters of the column with a specified name, using or refreshing the cache as appropriate.
 *
 * @param colName The column name.
 */
- (NSDictionary *) columnWithName:(NSString *)colName
{
	// If processing is already in action, wait for it to complete
	[self _loopWhileWorking];

	if ([columns count] == 0) {
		if ([tableListInstance tableType] == SPTableTypeView) {
			[self updateInformationForCurrentView];
		} else {
			[self updateInformationForCurrentTable];
		}
	}
	NSInteger columnIndex = [columnNames indexOfObject:colName];
	if (columnIndex == NSNotFound) return nil;
	return [columns objectAtIndex:columnIndex];
}

/**
 * Retrieve column names for the current table as an array, using or refreshing the cache as appropriate.
 */
- (NSArray *) columnNames
{
	// If processing is already in action, wait for it to complete
	[self _loopWhileWorking];

	if ([columnNames count] == 0) {
		if ([tableListInstance tableType] == SPTableTypeView) {
			[self updateInformationForCurrentView];
		} else {
			[self updateInformationForCurrentTable];
		}
	}
	return columnNames;
}

/**
 * Retrieve a NSDictionary containing all parameters of the column with a specific index, using or refreshing the cache as appropriate.
 *
 * @param index The index of the column array.
 */
- (NSDictionary *) columnAtIndex:(NSInteger)columnIndex
{
	// If processing is already in action, wait for it to complete
	[self _loopWhileWorking];

	if ([columns count] == 0) {
		if ([tableListInstance tableType] == SPTableTypeView) {
			[self updateInformationForCurrentView];
		} else {
			[self updateInformationForCurrentTable];
		}
	}
	return [columns objectAtIndex:columnIndex];
}

/**
 * Checks if this column is type text or blob.
 * Used to determine if we have to show a popup when we edit a value from this column.
 *
 * @param colName The column name which should be checked.
 */
- (BOOL) columnIsBlobOrText:(NSString *)colName
{
	// If processing is already in action, wait for it to complete
	[self _loopWhileWorking];

	if ([columns count] == 0) {
		if ([tableListInstance tableType] == SPTableTypeView) {
			[self updateInformationForCurrentView];
		} else {
			[self updateInformationForCurrentTable];
		}
	}

	return (BOOL) ([[[self columnWithName:colName] objectForKey:@"typegrouping"] isEqualToString:@"textdata" ] || [[[self columnWithName:colName] objectForKey:@"typegrouping"] isEqualToString:@"blobdata"]);
}

/**
 * Checks if this column is type geometry.
 * Used to determine if we have to use AsText() in SELECT.
 *
 * @param colName The column name which should be checked.
 */
- (BOOL) columnIsGeometry:(NSString *)colName
{
	// If processing is already in action, wait for it to complete
	[self _loopWhileWorking];

	if ([columns count] == 0) {
		if ([tableListInstance tableType] == SPTableTypeView) {
			[self updateInformationForCurrentView];
		} else {
			[self updateInformationForCurrentTable];
		}
	}

	return (BOOL) ([[[self columnWithName:colName] objectForKey:@"typegrouping"] isEqualToString:@"geometry"]);
}

/**
 * Retrieve the table status value for a supplied key, using or refreshing the cache as appropriate.
 *
 * @param aKey The key name of the underlying NSDictionary
 */
- (NSString *) statusValueForKey:(NSString *)aKey
{
	// If processing is already in action, wait for it to complete
	[self _loopWhileWorking];

	if ([status count] == 0) {
		[self updateStatusInformationForCurrentTable];
	}
	return [status objectForKey:aKey];
}

/**
 * Set the table status value for the supplied key. This method is useful for when status values are obtained
 * via other means and are subsequently more accurate than the value currently set.
 *
 * @param value The string value for the passed key name.
 *
 * @param key The key name.
 */
- (void)setStatusValue:(NSString *)value forKey:(NSString *)key
{
	[status setValue:value forKey:key];
}

/**
 * Retrieve all known status values as a dictionary, using or refreshing the cache as appropriate.
 */
- (NSDictionary *) statusValues
{
	// If processing is already in action, wait for it to complete
	[self _loopWhileWorking];

	if ([status count] == 0) {
		[self updateStatusInformationForCurrentTable];
	}
	return status;
}

/**
 * Flushes all caches - should be used on major changes, for example table changes.
 */
- (void) resetAllData
{
	[columns removeAllObjects];
	[columnNames removeAllObjects];
	[status removeAllObjects];

	if (triggers != nil) {
		[triggers release];
		triggers = nil;
	}

	if (tableEncoding != nil) {
		[tableEncoding release];
		tableEncoding = nil;
	}

	if (tableCreateSyntax != nil) {
		[tableCreateSyntax release];
		tableCreateSyntax = nil;
	}
}

/**
 * Flushes any status-related caches.
 */
- (void) resetStatusData
{
	[status removeAllObjects];
}


/**
 * Flushes any field/column-related caches.
 */
- (void) resetColumnData
{
	[columns removeAllObjects];
	[columnNames removeAllObjects];
}

/**
 * Retrieves the information for the current table and stores it in cache.
 * Returns a boolean indicating success.
 */
- (BOOL) updateInformationForCurrentTable
{
	pthread_mutex_lock(&dataProcessingLock);

	NSDictionary *tableData = nil;
	NSDictionary *columnData;
	NSEnumerator *enumerator;

	[columns removeAllObjects];
	[columnNames removeAllObjects];
	[constraints removeAllObjects];
	tableHasAutoIncrementField = NO;
	[primaryKeyColumns removeAllObjects];

	if( [tableListInstance tableType] == SPTableTypeTable || [tableListInstance tableType] == SPTableTypeView ) {
		tableData = [self informationForTable:[tableListInstance tableName]];
	}

	// If nil is returned, return failure.
	if (tableData == nil ) {

		// The table information fetch may have already unlocked the data lock.
		pthread_mutex_trylock(&dataProcessingLock);
		pthread_mutex_unlock(&dataProcessingLock);
		return FALSE;
	}

	[columns addObjectsFromArray:[tableData objectForKey:@"columns"]];

	enumerator = [columns objectEnumerator];
	while ((columnData = [enumerator nextObject])) {
		[columnNames addObject:[NSString stringWithString:[columnData objectForKey:@"name"]]];
	}

	if (tableEncoding != nil) {
		[tableEncoding release];
	}
	tableEncoding = [[NSString alloc] initWithString:[tableData objectForKey:@"encoding"]];
	[primaryKeyColumns addObjectsFromArray:[tableData objectForKey:@"primarykeyfield"]];

	pthread_mutex_unlock(&dataProcessingLock);

	return TRUE;
}

/**
 * Retrieves the information for the current view and stores it in cache.
 * Returns a boolean indicating success.
 */
- (BOOL) updateInformationForCurrentView
{
	pthread_mutex_lock(&dataProcessingLock);

	NSDictionary *viewData = [self informationForView:[tableListInstance tableName]];
	NSDictionary *columnData;
	NSEnumerator *enumerator;

	tableHasAutoIncrementField = NO;
	[primaryKeyColumns removeAllObjects];

	if (viewData == nil) {
		[columns removeAllObjects];
		[columnNames removeAllObjects];
		[constraints removeAllObjects];
		pthread_mutex_unlock(&dataProcessingLock);
		return FALSE;
	}

	[columns addObjectsFromArray:[viewData objectForKey:@"columns"]];

	enumerator = [columns objectEnumerator];
	while ((columnData = [enumerator nextObject])) {
		[columnNames addObject:[NSString stringWithString:[columnData objectForKey:@"name"]]];
	}

	if (tableEncoding != nil) {
		[tableEncoding release];
	}
	tableEncoding = [[NSString alloc] initWithString:[viewData objectForKey:@"encoding"]];

	pthread_mutex_unlock(&dataProcessingLock);

	return TRUE;
}

/**
 * Retrieve the CREATE TABLE string for a table and analyse it to extract the field
 * details, primary key, unique keys, and table encoding.
 * In future this could also be used to retrieve the majority of index information
 * assuming information like cardinality isn't needed.
 * This function is rather long due to the painful parsing required, but is fast.
 * Returns a boolean indicating success.
 */
- (NSDictionary *) informationForTable:(NSString *)tableName
{
	SPSQLParser *createTableParser, *fieldsParser, *fieldParser;
	NSMutableArray *tableColumns, *fieldStrings;
	NSMutableDictionary *tableColumn, *tableData;
	NSString *encodingString = nil;
	NSUInteger i, stringStart;
	unichar quoteCharacter;
	BOOL changeEncoding = ![[mySQLConnection encoding] isEqualToString:@"utf8"];

	// Catch unselected tables and return nil
	if ([tableName isEqualToString:@""] || !tableName) return nil;

	// Ensure the encoding is set to UTF8
	if (changeEncoding) {
		[mySQLConnection storeEncodingForRestoration];
		[mySQLConnection setEncoding:@"utf8"];
	}
	
	// In cases where this method is called directly instead of via -updateInformationForCurrentTable
	// (for example, from the exporters) clear the list of constraints to prevent the previous call's table
	// constraints being included in the table information (issue 1206).
	[constraints removeAllObjects];

	// Retrieve the CREATE TABLE syntax for the table
	SPMySQLResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE TABLE %@", [tableName backtickQuotedString]]];
	[theResult setReturnDataAsStrings:YES];

	// Check for any errors, but only display them if a connection still exists
	if ([mySQLConnection queryErrored]) {
		if ([mySQLConnection isConnected]) {
			SPBeginAlertSheet(NSLocalizedString(@"Error retrieving table information", @"error retrieving table information message"), NSLocalizedString(@"OK", @"OK button"),
					nil, nil, [NSApp mainWindow], self, nil, nil,
					[NSString stringWithFormat:NSLocalizedString(@"An error occurred while retrieving the information for table '%@'. Please try again.\n\nMySQL said: %@", @"error retrieving table information informative message"),
					   tableName, [mySQLConnection lastErrorMessage]]);

			// If the current table doesn't exist anymore reload table list
			if([mySQLConnection lastErrorID] == 1146) {

				// Release the table loading lock to allow reselection/reloading to requery the database.
				pthread_mutex_unlock(&dataProcessingLock);

				[[tableListInstance valueForKeyPath:@"tablesListView"] deselectAll:nil];
				[tableListInstance updateTables:self];
			}
			if (changeEncoding) [mySQLConnection restoreStoredEncoding];
		}

		return nil;
	}

	// Retrieve the table syntax string
	NSArray *syntaxResult = [theResult getRowAsArray];
	NSArray *resultFieldNames = [theResult fieldNames];

	// Only continue if syntaxResult is not nil. This accommodates causes where the above query caused the
	// connection reconnect dialog to appear and the user chose to close the connection.
	if (!syntaxResult) return nil;

	if (tableCreateSyntax != nil) [tableCreateSyntax release], tableCreateSyntax = nil;

	// A NULL value indicates that the user does not have permission to view the syntax
	if ([[syntaxResult objectAtIndex:1] isNSNull]) {
		[[NSAlert alertWithMessageText:NSLocalizedString(@"Permission Denied", @"Permission Denied")
						 defaultButton:NSLocalizedString(@"OK", @"OK button")
					   alternateButton:nil otherButton:nil
			 informativeTextWithFormat:NSLocalizedString(@"The creation syntax could not be retrieved due to a permissions error.\n\nPlease check your user permissions with an administrator.", @"Create syntax permission denied detail")]
			  beginSheetModalForWindow:[NSApp mainWindow]
						 modalDelegate:self didEndSelector:NULL contextInfo:NULL];
		if (changeEncoding) [mySQLConnection restoreStoredEncoding];
		return nil;
	}

	tableCreateSyntax = [[NSString alloc] initWithString:[syntaxResult objectAtIndex:1]];
	createTableParser = [[SPSQLParser alloc] initWithString:[syntaxResult objectAtIndex:1]];

	// Extract the fields definition string from the CREATE TABLE syntax
	fieldsParser = [[SPSQLParser alloc] initWithString:[createTableParser trimAndReturnStringFromCharacter:'(' toCharacter:')' trimmingInclusively:YES returningInclusively:NO skippingBrackets:YES]];

	// Split the fields and keys string into an array of individual elements
	fieldStrings = [[NSMutableArray alloc] initWithArray:[fieldsParser splitStringByCharacter:',' skippingBrackets:YES]];

	// fieldStrings should now hold unparsed field and key strings, while tableProperty string holds unparsed
	// table information.  Proceed further by parsing the field strings.
	tableColumns = [[NSMutableArray alloc] init];
	tableColumn = [[NSMutableDictionary alloc] init];
	fieldParser = [[SPSQLParser alloc] init];

	NSCharacterSet *whitespaceAndNewlineSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSCharacterSet *quoteSet = [NSCharacterSet characterSetWithCharactersInString:@"`'\""];
	NSCharacterSet *bracketSet = [NSCharacterSet characterSetWithCharactersInString:@"()"];

	tableData = [NSMutableDictionary dictionary];

	for (i = 0; i < [fieldStrings count]; i++) {

		// Take this field/key string, trim whitespace from both ends and remove comments
		[fieldsParser setString:[NSArrayObjectAtIndex(fieldStrings, i) stringByTrimmingCharactersInSet:whitespaceAndNewlineSet]];
		[fieldsParser deleteComments];
		if (![fieldsParser length]) {
			continue;
		}
		[tableColumn removeAllObjects];

		// If the first character is a quote character, this is a field definition.
		if ([quoteSet characterIsMember:[fieldsParser characterAtIndex:0]]) {
			quoteCharacter = [fieldsParser characterAtIndex:0];

			// Capture the area between the two backticks as the name
			// Set the parser to ignoreCommentStrings since a field name can contain # or /*
			[fieldsParser setIgnoreCommentStrings:YES];
			NSString *fieldName = [fieldsParser trimAndReturnStringFromCharacter: quoteCharacter
																	 toCharacter: quoteCharacter
															 trimmingInclusively: YES
															returningInclusively: NO
														   ignoringQuotedStrings: NO];
			if(fieldName == nil || [fieldName length] == 0) {
				NSBeep();
				NSAlert *alert = [[NSAlert alloc] init];
				[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK button")];
				[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"“%@” couldn't be parsed. You can edit the column setup but the column will not be shown in the Content view; please report this issue to the Sequel Pro team using the Help menu item.", @"“%@” couldn't be parsed. You can edit the column setup but the column will not be shown in the Content view; please report this issue to the Sequel Pro team using the Help menu item."), fieldsParser]];
				[alert setMessageText:NSLocalizedString(@"Error while parsing CREATE TABLE syntax",@"error while parsing CREATE TABLE syntax")];
				[alert setAlertStyle:NSCriticalAlertStyle];
				[alert runModal];
				[alert release];
				continue;
			}
			//if the next character is again a backtick, we stumbled across an escaped backtick. we have to continue parsing.
			while ([fieldsParser characterAtIndex:0] == quoteCharacter) {
				fieldName = [fieldName stringByAppendingFormat: @"`%@",
																[fieldsParser trimAndReturnStringFromCharacter: quoteCharacter
																								   toCharacter: quoteCharacter
																						   trimmingInclusively: YES
																						  returningInclusively: NO
																						 ignoringQuotedStrings: NO]
																];
			}
			[fieldsParser setIgnoreCommentStrings:NO];

			[tableColumn setObject:[NSString stringWithFormat:@"%llu", (unsigned long long)[tableColumns count]] forKey:@"datacolumnindex"];
			[tableColumn setObject:fieldName forKey:@"name"];

			// Split the remaining field definition string by spaces and process
			[tableColumn addEntriesFromDictionary:[self parseFieldDefinitionStringParts:[fieldsParser splitStringByCharacter:' ' skippingBrackets:YES]]];

			//if column is not null, but doesn't have a default value, set empty string
			if([[tableColumn objectForKey:@"null"] integerValue] == 0 && [[tableColumn objectForKey:@"autoincrement"] integerValue] == 0 && ![tableColumn objectForKey:@"default"]) {
				[tableColumn setObject:@"" forKey:@"default"];
			}

			// Store the column.
			NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:1];
			[d setDictionary:tableColumn];
			[tableColumns addObject:d];

		// TODO: Otherwise it's a key definition, check, or other 'metadata'.  Would be useful to parse/display these!
		} 
		else {
			NSArray *parts = [fieldsParser splitStringByCharacter:' ' skippingBrackets:YES ignoringQuotedStrings:YES];

			// Constraints
			if ([[parts objectAtIndex:0] hasPrefix:@"CONSTRAINT"]) {
				NSMutableDictionary *constraintDetails = [[NSMutableDictionary alloc] init];

				// Extract the relevant details from the constraint string
				[fieldsParser setString:[[parts objectAtIndex:1] stringByTrimmingCharactersInSet:bracketSet]];
				[constraintDetails setObject:[fieldsParser unquotedString] forKey:@"name"];

				NSMutableArray *keyColumns = [NSMutableArray array];
				NSArray *keyColumnStrings = [[[parts objectAtIndex:4] stringByTrimmingCharactersInSet:bracketSet] componentsSeparatedByString:@","];

				for (NSString *keyColumn in keyColumnStrings)
				{
					[fieldsParser setString:[[keyColumn stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] stringByTrimmingCharactersInSet:bracketSet]];
					[keyColumns addObject:[fieldsParser unquotedString]];
				}

				[constraintDetails setObject:keyColumns forKey:@"columns"];

				[fieldsParser setString:[[parts objectAtIndex:6] stringByTrimmingCharactersInSet:bracketSet]];
				[constraintDetails setObject:[fieldsParser unquotedString] forKey:@"ref_table"];

				[fieldsParser setString:[[parts objectAtIndex:7] stringByTrimmingCharactersInSet:bracketSet]];
				[constraintDetails setObject:[fieldsParser unquotedString] forKey:@"ref_columns"];

				NSUInteger nextOffs = 12;
				
				if ([parts count] > 8) {
					// NOTE: this won't get SET NULL | NO ACTION | RESTRICT
					if ([[parts objectAtIndex:9] hasPrefix:@"UPDATE"]) {
						if( [NSArrayObjectAtIndex(parts, 10) hasPrefix:@"SET"] ) {
							[constraintDetails setObject:@"SET NULL"
												  forKey:@"update"];
							nextOffs = 13;
						} else if( [NSArrayObjectAtIndex(parts, 10) hasPrefix:@"NO"] ) {
							[constraintDetails setObject:@"NO ACTION"
												  forKey:@"update"];
							nextOffs = 13;
						} else {
							[constraintDetails setObject:NSArrayObjectAtIndex(parts, 10)
												  forKey:@"update"];
						}
					}
					else if ([NSArrayObjectAtIndex(parts, 9) hasPrefix:@"DELETE"]) {
						if ([NSArrayObjectAtIndex(parts, 10) hasPrefix:@"SET"]) {
							[constraintDetails setObject:@"SET NULL"
												  forKey:@"delete"];
							nextOffs = 13;
						} else if( [NSArrayObjectAtIndex(parts, 10) hasPrefix:@"NO"] ) {
							[constraintDetails setObject:@"NO ACTION"
												  forKey:@"delete"];
							nextOffs = 13;
						} else {
							[constraintDetails setObject:NSArrayObjectAtIndex(parts, 10)
												  forKey:@"delete"];
						}
					}
				}
				
				if ([parts count] > nextOffs - 1) {
					if( [NSArrayObjectAtIndex(parts, nextOffs) hasPrefix:@"UPDATE"] ) {
						if( [NSArrayObjectAtIndex(parts, nextOffs+1) hasPrefix:@"SET"] ) {
							[constraintDetails setObject:@"SET NULL"
												  forKey:@"update"];
						} else if( [NSArrayObjectAtIndex(parts, nextOffs+1) hasPrefix:@"NO"] ) {
							[constraintDetails setObject:@"NO ACTION"
												  forKey:@"update"];
						} else {
							[constraintDetails setObject:NSArrayObjectAtIndex(parts, nextOffs+1)
												  forKey:@"update"];
						}
					}
					else if( [NSArrayObjectAtIndex(parts, nextOffs) hasPrefix:@"DELETE"] ) {
						if( [NSArrayObjectAtIndex(parts, nextOffs+1) hasPrefix:@"SET"] ) {
							[constraintDetails setObject:@"SET NULL"
												  forKey:@"delete"];
						} else if( [NSArrayObjectAtIndex(parts, nextOffs+1) hasPrefix:@"NO"] ) {
							[constraintDetails setObject:@"NO ACTION"
												  forKey:@"delete"];
						} else {
							[constraintDetails setObject:NSArrayObjectAtIndex(parts, nextOffs+1)
												  forKey:@"delete"];
						}
					}
				}
				
				[constraints addObject:constraintDetails];
				[constraintDetails release];
			}
			
			// primary key
			// add "isprimarykey" to the corresponding tableColumn
			// add dict root "primarykeyfield" = <field> for faster accessing
			else if( [NSArrayObjectAtIndex(parts, 0) hasPrefix:@"PRIMARY"] && [parts count] == 3) {
				SPSQLParser *keyParser = [SPSQLParser stringWithString:NSArrayObjectAtIndex(parts, 2)];
				keyParser = [SPSQLParser stringWithString:[keyParser stringFromCharacter:'(' toCharacter:')' inclusively:NO]];
				NSArray *primaryKeyQuotedNames = [keyParser splitStringByCharacter:','];
				if ([keyParser length]) {
					NSMutableArray *primaryKeyFields = [NSMutableArray array];
					for (NSString *quotedKeyName in primaryKeyQuotedNames) {
						NSString *primaryFieldName = [[SPSQLParser stringWithString:quotedKeyName] unquotedString];
						[primaryKeyFields addObject:primaryFieldName];
						for (NSMutableDictionary *theTableColumn in tableColumns) {
							if ([[theTableColumn objectForKey:@"name"] isEqualToString:primaryFieldName]) {
								[theTableColumn setObject:[NSNumber numberWithInteger:1] forKey:@"isprimarykey"];
								break;
							}
						}
					}
					[tableData setObject:primaryKeyFields forKey:@"primarykeyfield"];
				}
			}
			
			// unique keys
			// add to each corresponding tableColumn the tag "unique" if given
			else if( [NSArrayObjectAtIndex(parts, 0) hasPrefix:@"UNIQUE"]  && [parts count] == 4) {
				SPSQLParser *keyParser = [SPSQLParser stringWithString:NSArrayObjectAtIndex(parts, 3)];
				keyParser = [SPSQLParser stringWithString:[keyParser stringFromCharacter:'(' toCharacter:')' inclusively:NO]];
				for (NSString *quotedUniqueKey in [keyParser splitStringByCharacter:',']) {
					NSString *uniqueFieldName = [[SPSQLParser stringWithString:quotedUniqueKey] unquotedString];
					for (NSMutableDictionary *theTableColumn in tableColumns) {
						if ([[theTableColumn objectForKey:@"name"] isEqualToString:uniqueFieldName]) {
							[theTableColumn setObject:[NSNumber numberWithInteger:1] forKey:@"unique"];
							break;
						}
					}
				}
			}
			// who knows
			else {
				// NSLog( @"not parsed: %@", [parts objectAtIndex:0] );
			}
		}
	}
	[fieldStrings release];
	[fieldsParser release];
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

	// this will be 'Table' or 'View'
	[tableData setObject:[resultFieldNames objectAtIndex:0] forKey:@"type"];
	[tableData setObject:[NSString stringWithString:encodingString] forKey:@"encoding"];
	[tableData setObject:[NSArray arrayWithArray:tableColumns] forKey:@"columns"];
	[tableData setObject:[NSArray arrayWithArray:constraints] forKey:@"constraints"];

	[encodingString release];
	[tableColumns release];

	if (changeEncoding) [mySQLConnection restoreStoredEncoding];

	return tableData;
}

/**
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
	BOOL changeEncoding = ![[mySQLConnection encoding] isEqualToString:@"utf8"];

	// Catch unselected views and return nil
	if ([viewName isEqualToString:@""] || !viewName) return nil;

	// Ensure that queries are made in UTF8
	if (changeEncoding) {
		[mySQLConnection storeEncodingForRestoration];
		[mySQLConnection setEncoding:@"utf8"];
	}

	// Retrieve the CREATE TABLE syntax for the table
	SPMySQLResult *theResult = [mySQLConnection queryString: [NSString stringWithFormat: @"SHOW CREATE TABLE %@",
																					   [viewName backtickQuotedString]
																					]];
	[theResult setReturnDataAsStrings:YES];

	// Check for any errors, but only display them if a connection still exists
	if ([mySQLConnection queryErrored]) {
		if ([mySQLConnection isConnected]) {
			SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"),
					nil, nil, [NSApp mainWindow], self, nil, nil,
					[NSString stringWithFormat:NSLocalizedString(@"An error occurred while retrieving information.\nMySQL said: %@", @"message of panel when retrieving information failed"),
					   [mySQLConnection lastErrorMessage]]);
			if (changeEncoding) [mySQLConnection restoreStoredEncoding];
		}
		return nil;
	}

	// Retrieve the table syntax string
	if (tableCreateSyntax) [tableCreateSyntax release], tableCreateSyntax = nil;
	NSString *syntaxString = [[theResult getRowAsArray] objectAtIndex:1];

	// A NULL value indicates that the user does not have permission to view the syntax
	if ([syntaxString isNSNull]) {
		[[NSAlert alertWithMessageText:NSLocalizedString(@"Permission Denied", @"Permission Denied")
						 defaultButton:NSLocalizedString(@"OK", @"OK button")
					   alternateButton:nil otherButton:nil
			 informativeTextWithFormat:NSLocalizedString(@"The creation syntax could not be retrieved due to a permissions error.\n\nPlease check your user permissions with an administrator.", @"Create syntax permission denied detail")]
			  beginSheetModalForWindow:[NSApp mainWindow]
						 modalDelegate:self didEndSelector:NULL contextInfo:NULL];
		if (changeEncoding) [mySQLConnection restoreStoredEncoding];
		return nil;
	}

	tableCreateSyntax = [[NSString alloc] initWithString:syntaxString];

	// Retrieve the SHOW COLUMNS syntax for the table
	theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW COLUMNS FROM %@", [viewName backtickQuotedString]]];
	[theResult setReturnDataAsStrings:YES];

	// Check for any errors, but only display them if a connection still exists
	if ([mySQLConnection queryErrored]) {
		if ([mySQLConnection isConnected]) {
			SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"),
					nil, nil, [NSApp mainWindow], self, nil, nil,
					[NSString stringWithFormat:NSLocalizedString(@"An error occurred while retrieving information.\nMySQL said: %@", @"message of panel when retrieving information failed"),
					   [mySQLConnection lastErrorMessage]]);
			if (changeEncoding) [mySQLConnection restoreStoredEncoding];
		}
		return nil;
	}

	// Loop through the fields and capture details
	tableColumns = [[NSMutableArray alloc] init];
	tableColumn = [[NSMutableDictionary alloc] init];
	fieldParser = [[SPSQLParser alloc] init];
	for (resultRow in theResult) {
		[tableColumn removeAllObjects];

		// Add the column index and name
		[tableColumn setObject:[NSString stringWithFormat:@"%llu", (unsigned long long)[tableColumns count]] forKey:@"datacolumnindex"];
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
		if ([resultRow objectForKey:@"Default"])
			[tableColumn setObject:[resultRow objectForKey:@"Default"] forKey:@"default"];

		// Add the column to the list
		[tableColumns addObject:[NSDictionary dictionaryWithDictionary:tableColumn]];
	}
	[fieldParser release];
	[tableColumn release];

	// The character set has to be guessed at via the database encoding.
	// Add the details to the data object.
	viewData = [NSMutableDictionary dictionary];
	if (tableDocumentInstance)
		[viewData setObject:[NSString stringWithString:[tableDocumentInstance databaseEncoding]] forKey:@"encoding"];
	[viewData setObject:[NSArray arrayWithArray:tableColumns] forKey:@"columns"];

	[tableColumns release];

	if (changeEncoding) [mySQLConnection restoreStoredEncoding];

	return viewData;
}

/**
 * Retrieve the status of a table as a dictionary and add it to the local cache for reuse.
 */
- (BOOL)updateStatusInformationForCurrentTable
{
	pthread_mutex_lock(&dataProcessingLock);

	BOOL changeEncoding = ![[mySQLConnection encoding] isEqualToString:@"utf8"];

	// Catch unselected tables and return false
	if (![tableListInstance tableName]) {
		pthread_mutex_unlock(&dataProcessingLock);
		return FALSE;
	}

	// Ensure queries are run as UTF8
	if (changeEncoding) {
		[mySQLConnection storeEncodingForRestoration];
		[mySQLConnection setEncoding:@"utf8"];
	}

	// Run the status query and retrieve as a dictionary.
	NSMutableString *escapedTableName = [NSMutableString stringWithString:[tableListInstance tableName]];
	[escapedTableName replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:0 range:NSMakeRange(0, [escapedTableName length])];
	[escapedTableName replaceOccurrencesOfString:@"'" withString:@"\\\'" options:0 range:NSMakeRange(0, [escapedTableName length])];

	SPMySQLResult *tableStatusResult = nil;

	if ([tableListInstance tableType] == SPTableTypeProc) {
		NSMutableString *escapedDatabaseName = [NSMutableString stringWithString:[tableDocumentInstance database]];
		[escapedDatabaseName replaceOccurrencesOfString:@"'" withString:@"\\\'" options:0 range:NSMakeRange(0, [escapedDatabaseName length])];
		tableStatusResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SELECT * FROM information_schema.ROUTINES AS r WHERE r.SPECIFIC_NAME = '%@' AND r.ROUTINE_SCHEMA = '%@' AND r.ROUTINE_TYPE = 'PROCEDURE'", escapedTableName, escapedDatabaseName]];
	}
	else if ([tableListInstance tableType] == SPTableTypeFunc) {
		NSMutableString *escapedDatabaseName = [NSMutableString stringWithString:[tableDocumentInstance database]];
		[escapedDatabaseName replaceOccurrencesOfString:@"'" withString:@"\\\'" options:0 range:NSMakeRange(0, [escapedDatabaseName length])];
		tableStatusResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SELECT * FROM information_schema.ROUTINES AS r WHERE r.SPECIFIC_NAME = '%@' AND r.ROUTINE_SCHEMA = '%@' AND r.ROUTINE_TYPE = 'FUNCTION'", escapedTableName, escapedDatabaseName]];
	}
	else if ([tableListInstance tableType] == SPTableTypeView) {
		NSMutableString *escapedDatabaseName = [NSMutableString stringWithString:[tableDocumentInstance database]];
		[escapedDatabaseName replaceOccurrencesOfString:@"'" withString:@"\\\'" options:0 range:NSMakeRange(0, [escapedDatabaseName length])];
		tableStatusResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SELECT * FROM information_schema.VIEWS AS r WHERE r.TABLE_NAME = '%@' AND r.TABLE_SCHEMA = '%@'", escapedTableName, escapedDatabaseName]];
	}
	else if ([tableListInstance tableType] == SPTableTypeTable) {
		[escapedTableName replaceOccurrencesOfRegex:@"\\\\(?=\\Z|[^\'])" withString:@"\\\\\\\\"];
		tableStatusResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW TABLE STATUS LIKE '%@'", escapedTableName ]];
		[tableStatusResult setReturnDataAsStrings:YES];
	}

	// Check for any errors, only displaying them if the connection hasn't been terminated
	if ([mySQLConnection queryErrored]) {
		if ([mySQLConnection isConnected]) {
			SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"),
					nil, nil, [NSApp mainWindow], self, nil, nil,
					[NSString stringWithFormat:NSLocalizedString(@"An error occured while retrieving status data.\nMySQL said: %@", @"message of panel when retrieving view information failed"),
					   [mySQLConnection lastErrorMessage]]);
			if (changeEncoding) [mySQLConnection restoreStoredEncoding];
		}
		pthread_mutex_unlock(&dataProcessingLock);
		return FALSE;
	}

	// Retrieve the status as a dictionary and set as the cache
	[status setDictionary:[tableStatusResult getRowAsDictionary]];

	if ([tableListInstance tableType] == SPTableTypeTable) {

		// Reassign any "Type" key - for MySQL < 4.1 - to "Engine" for consistency.
		if ([status objectForKey:@"Type"]) {
			[status setObject:[status objectForKey:@"Type"] forKey:@"Engine"];
		}

		// If the "Engine" key is NULL, a problem occurred when retrieving the table information.
		if ([[status objectForKey:@"Engine"] isNSNull]) {
			[status setDictionary:[NSDictionary dictionaryWithObjectsAndKeys:@"Error", @"Engine", [NSString stringWithFormat:NSLocalizedString(@"An error occurred retrieving table information.  MySQL said: %@", @"MySQL table info retrieval error message"), [status objectForKey:@"Comment"]], @"Comment", [tableListInstance tableName], @"Name", nil]];
			if (changeEncoding) [mySQLConnection restoreStoredEncoding];
			pthread_mutex_unlock(&dataProcessingLock);
			return FALSE;
		}

		// Add a note for whether the row count is accurate or not - only for MyISAM
		if ([[status objectForKey:@"Engine"] isEqualToString:@"MyISAM"]) {
			[status setObject:@"y" forKey:@"RowsCountAccurate"];
		} else {
			[status setObject:@"n" forKey:@"RowsCountAccurate"];
		}

		// [status objectForKey:@"Rows"] is NULL then try to get the number of rows via SELECT COUNT(1) FROM `foo`
		// this happens e.g. for db "information_schema"
		if([[status objectForKey:@"Rows"] isNSNull]) {
			tableStatusResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SELECT COUNT(1) FROM %@", [escapedTableName backtickQuotedString] ]];
			if (![mySQLConnection queryErrored])
				[status setObject:[[tableStatusResult getRowAsArray] objectAtIndex:0] forKey:@"Rows"];
				[status setObject:@"y" forKey:@"RowsCountAccurate"];
		}

	}

	// When views are selected, populate the table by adding some default information.
	else if ([tableListInstance tableType] == SPTableTypeView) {
		[status addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
			@"View", @"Engine",
			@"No status information is available for views.", @"Comment",
			[tableListInstance tableName], @"Name",
			[status objectForKey:@"COLLATION_CONNECTION"], @"Collation",
			[status objectForKey:@"CHARACTER_SET_CLIENT"], @"CharacterSetClient",
			nil]];
	}

	if (changeEncoding) [mySQLConnection restoreStoredEncoding];

	pthread_mutex_unlock(&dataProcessingLock);

	return TRUE;
}

/**
 * Retrieve the triggers for the current table and add to local cache for reuse.
 */
- (BOOL) updateTriggersForCurrentTable
{
	pthread_mutex_lock(&dataProcessingLock);

	// Ensure queries are made in UTF8
	BOOL changeEncoding = ![[mySQLConnection encoding] isEqualToString:@"utf8"];
	if (changeEncoding) {
		[mySQLConnection storeEncodingForRestoration];
		[mySQLConnection setEncoding:@"utf8"];
	}

	SPMySQLResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"/*!50003 SHOW TRIGGERS WHERE `Table` = %@ */",
											  [[tableListInstance tableName] tickQuotedString]]];
	[theResult setReturnDataAsStrings:YES];

	// Check for any errors, but only display them if a connection still exists
	if ([mySQLConnection queryErrored]) {
		if ([mySQLConnection isConnected]) {
			SPBeginAlertSheet(NSLocalizedString(@"Error retrieving trigger information", @"error retrieving trigger information message"), NSLocalizedString(@"OK", @"OK button"),
							  nil, nil, [NSApp mainWindow], self, nil, nil,
							  [NSString stringWithFormat:NSLocalizedString(@"An error occurred while retrieving the trigger information for table '%@'. Please try again.\n\nMySQL said: %@", @"error retrieving table information informative message"),
							  [tableListInstance tableName], [mySQLConnection lastErrorMessage]]);
			if (triggers) [triggers release], triggers = nil;
			if (changeEncoding) [mySQLConnection restoreStoredEncoding];
		}

		pthread_mutex_unlock(&dataProcessingLock);
		return NO;
	}

	if (triggers) [triggers release];
	triggers = [[NSArray alloc] initWithArray:[theResult getAllRows]];

	if (changeEncoding) [mySQLConnection restoreStoredEncoding];

	pthread_mutex_unlock(&dataProcessingLock);

	return YES;
}

/**
 * Parse an array of field definition parts - not including name but including type and optionally unsigned/zerofill/null
 * and so forth - into a dictionary of parsed details.  Intended for use both with CREATE TABLE syntax - with fuller
 * details - and with the "type" column from SHOW COLUMNS.
 * Returns a dictionary of details with lowercase keys.
 */
- (NSDictionary *) parseFieldDefinitionStringParts:(NSArray *)definitionParts
{
	if (![definitionParts count]) return [NSDictionary dictionary];

	SPSQLParser *detailParser;
	SPSQLParser *fieldParser = [[SPSQLParser alloc] init];
	NSMutableDictionary *fieldDetails = [[NSMutableDictionary alloc] init];
	NSMutableArray *detailParts;
	NSString *detailString;
	NSUInteger i, definitionPartsIndex = 0, partsArrayLength;

	NSCharacterSet *whitespaceCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];

	// Skip blank items within the definition parts
	while (definitionPartsIndex < [definitionParts count]
			&& ![[NSArrayObjectAtIndex(definitionParts, definitionPartsIndex) stringByTrimmingCharactersInSet:whitespaceCharacterSet] length])
		definitionPartsIndex++;

	// The first item is always the data type.
	[fieldParser setString:NSArrayObjectAtIndex(definitionParts, definitionPartsIndex)];
	definitionPartsIndex++;

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
				[detailParser setString:NSArrayObjectAtIndex(detailParts, i)];
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
				[detailParser setString:NSArrayObjectAtIndex(detailParts, 1)];
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
	} else if ([detailString isEqualToString:@"POINT"] || [detailString isEqualToString:@"GEOMETRY"]
				|| [detailString isEqualToString:@"LINESTRING"] || [detailString isEqualToString:@"POLYGON"]
				|| [detailString isEqualToString:@"MULTIPOLYGON"] || [detailString isEqualToString:@"GEOMETRYCOLLECTION"]
				|| [detailString isEqualToString:@"MULTIPOINT"] || [detailString isEqualToString:@"MULTILINESTRING"]) {
		[fieldDetails setObject:@"geometry" forKey:@"typegrouping"];

	// Default to "blobdata".  This means that future and currently unsupported types - including spatial extensions -
	// will be preserved unmangled.
	} else {
		[fieldDetails setObject:@"blobdata" forKey:@"typegrouping"];
	}
	[detailString release];


	NSNumber *boolYES = [NSNumber numberWithBool:YES];
	NSNumber *boolNO  = [NSNumber numberWithBool:NO];

	// Set up some column defaults for all columns
	[fieldDetails setValue:boolYES forKey:@"null"];
	[fieldDetails setValue:boolNO forKey:@"unsigned"];
	[fieldDetails setValue:boolNO forKey:@"binary"];
	[fieldDetails setValue:boolNO forKey:@"zerofill"];
	[fieldDetails setValue:boolNO forKey:@"autoincrement"];
	[fieldDetails setValue:boolNO forKey:@"onupdatetimestamp"];
	[fieldDetails setValue:@"" forKey:@"comment"];
	[fieldDetails setValue:[NSMutableString string] forKey:@"unparsed"];

	// Walk through the remaining column definition parts storing recognised details
	partsArrayLength = [definitionParts count];
	id aValue;
	for ( ; definitionPartsIndex < partsArrayLength; definitionPartsIndex++) {
		detailString = [[NSString alloc] initWithString:[NSArrayObjectAtIndex(definitionParts, definitionPartsIndex) uppercaseString]];

		// Whether numeric fields are unsigned
		if ([detailString isEqualToString:@"UNSIGNED"]) {
			[fieldDetails setValue:boolYES forKey:@"unsigned"];

		// Whether numeric fields are zerofill
		} else if ([detailString isEqualToString:@"ZEROFILL"]) {
			[fieldDetails setValue:boolYES forKey:@"zerofill"];

		// Whether text types are binary
		} else if ([detailString isEqualToString:@"BINARY"]) {
			[fieldDetails setValue:boolYES forKey:@"binary"];

		// Whether text types have a different encoding to the table
		} else if ([detailString isEqualToString:@"CHARSET"] && (definitionPartsIndex + 1 < partsArrayLength)) {
			if (![[aValue = NSArrayObjectAtIndex(definitionParts, definitionPartsIndex+1) uppercaseString] isEqualToString:@"DEFAULT"]) {
				[fieldDetails setValue:aValue forKey:@"encoding"];
			}
			definitionPartsIndex++;
		} else if ([detailString isEqualToString:@"CHARACTER"] && (definitionPartsIndex + 2 < partsArrayLength)
					&& [[NSArrayObjectAtIndex(definitionParts, definitionPartsIndex+1) uppercaseString] isEqualToString:@"SET"]) {
			if (![[aValue = NSArrayObjectAtIndex(definitionParts, definitionPartsIndex+2) uppercaseString] isEqualToString:@"DEFAULT"]) {
				[fieldDetails setValue:aValue forKey:@"encoding"];
			}
			definitionPartsIndex += 2;

		// Whether text types have a different collation to the table
		} else if ([detailString isEqualToString:@"COLLATE"] && (definitionPartsIndex + 1 < partsArrayLength)) {
			if (![[aValue = NSArrayObjectAtIndex(definitionParts, definitionPartsIndex+1) uppercaseString] isEqualToString:@"DEFAULT"]) {
				[fieldDetails setValue:aValue forKey:@"collation"];
			}
			definitionPartsIndex++;

		// Whether fields are NOT NULL
		} else if ([detailString isEqualToString:@"NOT"] && (definitionPartsIndex + 1 < partsArrayLength)
					&& [[NSArrayObjectAtIndex(definitionParts, definitionPartsIndex+1) uppercaseString] isEqualToString:@"NULL"]) {
			[fieldDetails setValue:boolNO forKey:@"null"];
			definitionPartsIndex++;

		// Whether fields are NULL
		} else if ([detailString isEqualToString:@"NULL"]) {
			[fieldDetails setValue:boolYES forKey:@"null"];

		// Whether fields should auto-increment
		} else if ([detailString isEqualToString:@"AUTO_INCREMENT"]) {
			[fieldDetails setValue:boolYES forKey:@"autoincrement"];
			tableHasAutoIncrementField = YES;

		// Field defaults
		} else if ([detailString isEqualToString:@"DEFAULT"] && (definitionPartsIndex + 1 < partsArrayLength)) {
			detailParser = [[SPSQLParser alloc] initWithString:NSArrayObjectAtIndex(definitionParts, definitionPartsIndex+1)];
			if([[detailParser unquotedString] isEqualToString:@"NULL"])
				[fieldDetails setObject:[NSNull null] forKey:@"default"];
			else
				[fieldDetails setValue:[detailParser unquotedString] forKey:@"default"];
			[detailParser release];
			definitionPartsIndex++;

		// Special timestamp case - Whether fields are set to update the current timestamp
		} else if ([detailString isEqualToString:@"ON"] && (definitionPartsIndex + 2 < partsArrayLength)
					&& [[NSArrayObjectAtIndex(definitionParts, definitionPartsIndex+1) uppercaseString] isEqualToString:@"UPDATE"]
					&& [[NSArrayObjectAtIndex(definitionParts, definitionPartsIndex+2) uppercaseString] isEqualToString:@"CURRENT_TIMESTAMP"]) {
			[fieldDetails setValue:boolYES forKey:@"onupdatetimestamp"];
			definitionPartsIndex += 2;

		// Column comments
		} else if ([detailString isEqualToString:@"COMMENT"] && (definitionPartsIndex + 1 < partsArrayLength)) {
			detailParser = [[SPSQLParser alloc] initWithString:NSArrayObjectAtIndex(definitionParts, definitionPartsIndex+1)];
			[fieldDetails setValue:[detailParser unquotedString] forKey:@"comment"];
			[detailParser release];
			definitionPartsIndex++;

		// Preserve unhandled details to avoid losing information when rearranging columns etc
		// TODO: Currently unhandled: [UNIQUE | PRIMARY] KEY | COLUMN_FORMAT bar | STORAGE q | REFERENCES...
		} else {
			[[fieldDetails objectForKey:@"unparsed"] appendString:@" "];
			[[fieldDetails objectForKey:@"unparsed"] appendString:NSArrayObjectAtIndex(definitionParts, definitionPartsIndex)];
		}

		[detailString release];
	}

	return [fieldDetails autorelease];
}

/**
 * Return the column names which are set to PRIMIARY KEY; returns nil if no PRIMARY KEY is set.
 */
- (NSArray *)primaryKeyColumnNames
{

	// If processing is already in action, wait for it to complete
	[self _loopWhileWorking];

	if ([columns count] == 0) {
		if ([tableListInstance tableType] == SPTableTypeView) {
			[self updateInformationForCurrentView];
		} else {
			[self updateInformationForCurrentTable];
		}
	}

	if (![primaryKeyColumns count]) return nil;
	return primaryKeyColumns;
}

#pragma mark -

/**
 * Dealloc the class
 */
- (void)dealloc
{
	[columns release];
	[columnNames release];
	[constraints release];
	[status release];
	[primaryKeyColumns release];

	if (triggers) [triggers release];
	if (tableEncoding) [tableEncoding release];
	if (tableCreateSyntax) [tableCreateSyntax release];
	if (mySQLConnection) [mySQLConnection release];

	pthread_mutex_destroy(&dataProcessingLock);

	[super dealloc];
}

#pragma mark -
#pragma mark Private API

- (void)_loopWhileWorking
{
	while (pthread_mutex_trylock(&dataProcessingLock)) usleep(10000);
	pthread_mutex_unlock(&dataProcessingLock);
}

#ifdef SP_REFACTOR /* glue */

- (void)setTableDocumentInstance:(SPDatabaseDocument *)doc
{
	tableDocumentInstance = doc;
}

- (void)setTableListInstance:(SPTablesList *)list
{
	tableListInstance = list;
}

#endif

@end
