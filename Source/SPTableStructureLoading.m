//
//  SPTableStructureLoading.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on July 4, 2012.
//  Copyright (c) 2012 Stuart Connolly. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.

#import "SPTableStructureLoading.h"
#import "SPTableData.h"
#import "SPAlertSheets.h"
#import "SPDatabaseData.h"
#import "SPDatabaseStructure.h"
#import "SPTableFieldValidation.h"
#import "SPDatabaseViewController.h"
#import "SPIndexesController.h"
#import "SPTablesList.h"
#import "SPThreadAdditions.h"
#import "SPTableView.h"
#import "SPFunctions.h"

#import <SPMySQL/SPMySQL.h>

@implementation SPTableStructure (SPTableStructureLoading)

#pragma mark -
#pragma mark Table loading

/**
 * Loads aTable, puts it in an array, updates the tableViewColumns and reloads the tableView.
 */
- (void)loadTable:(NSString *)aTable
{
	NSMutableDictionary *theTableEnumLists = [NSMutableDictionary dictionary];
	
	// Check whether a save of the current row is required.
	if (![[self onMainThread] saveRowOnDeselect]) return;
	
	// If no table is selected, reset the interface and return
	if (!aTable || ![aTable length]) {
		[[self onMainThread] setTableDetails:nil];
		return;
	}
	
	NSMutableArray *theTableFields = [[NSMutableArray alloc] init];
	
	// Make a mutable copy out of the cached [tableDataInstance columns] since we're adding infos
	for (id col in [tableDataInstance columns]) 
	{
		[theTableFields addObject:[[col mutableCopy] autorelease]];
	}
	
	// Retrieve the indexes for the table
	SPMySQLResult *indexResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW INDEX FROM %@", [aTable backtickQuotedString]]];
	
	// If an error occurred, reset the interface and abort
	if ([mySQLConnection queryErrored]) {
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];
		[[self onMainThread] setTableDetails:nil];
		
		if ([mySQLConnection isConnected]) {
			SPOnewayAlertSheet(
				NSLocalizedString(@"Error", @"error"),
				[NSApp mainWindow],
				[NSString stringWithFormat:NSLocalizedString(@"An error occurred while retrieving information.\nMySQL said: %@", @"message of panel when retrieving information failed"), [mySQLConnection lastErrorMessage]]
			);
		}
		
		return;
	}
	
	// Process the indexes into a local array of dictionaries
	NSArray *theTableIndexes = [self convertIndexResultToArray:indexResult];
	
	// Set the Key column
	for (NSDictionary* theIndex in theTableIndexes) 
	{
		for (id field in theTableFields) 
		{
			if ([[field objectForKey:@"name"] isEqualToString:[theIndex objectForKey:@"Column_name"]]) {
				if ([[theIndex objectForKey:@"Key_name"] isEqualToString:@"PRIMARY"]) {
					[field setObject:@"PRI" forKey:@"Key"];
				}
				else {
					if ([[field objectForKey:@"typegrouping"] isEqualToString:@"geometry"]) {
						[field setObject:@"SPA" forKey:@"Key"];	
					}
					else {
						[field setObject:(([[theIndex objectForKey:@"Non_unique"] isEqualToString:@"1"]) ? @"MUL" : @"UNI") forKey:@"Key"];
					}
				}
				
				break;
			}
		}
	}
	
	// Set up the encoding PopUpButtonCell
	NSArray *encodings  = [databaseDataInstance getDatabaseCharacterSetEncodings];

	SPMainQSync(^{
		[encodingPopupCell removeAllItems];

		if ([encodings count]) {

			[encodingPopupCell addItemWithTitle:@"dummy"];
			//copy the default attributes and add gray color
			NSMutableDictionary *defaultAttrs = [NSMutableDictionary dictionaryWithDictionary:[[encodingPopupCell attributedTitle] attributesAtIndex:0 effectiveRange:NULL]];
			[defaultAttrs setObject:[NSColor lightGrayColor] forKey:NSForegroundColorAttributeName];
			[[encodingPopupCell lastItem] setTitle:@""];

			for (NSDictionary *encoding in encodings)
			{
				NSString *encodingName = [encoding objectForKey:@"CHARACTER_SET_NAME"];
				NSString *title = (![encoding objectForKey:@"DESCRIPTION"]) ? encodingName : [NSString stringWithFormat:@"%@ (%@)", [encoding objectForKey:@"DESCRIPTION"], encodingName];

				[encodingPopupCell addItemWithTitle:title];
				NSMenuItem *item = [encodingPopupCell lastItem];

				[item setRepresentedObject:encodingName];

				if ([encodingName isEqualToString:[tableDataInstance tableEncoding]]) {

					NSAttributedString *itemString = [[NSAttributedString alloc] initWithString:[item title] attributes:defaultAttrs];

					[item setAttributedTitle:[itemString autorelease]];
				}
			}
		}
		else {
			[encodingPopupCell addItemWithTitle:NSLocalizedString(@"Not available", @"not available label")];
		}
	});
	
	// Process all the fields to normalise keys and add additional information
	for (id theField in theTableFields) 
	{
		NSString *type = [[[theField objectForKey:@"type"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];

		if([type isEqualToString:@"JSON"]) {
			// MySQL 5.7 manual:
			// "MySQL handles strings used in JSON context using the utf8mb4 character set and utf8mb4_bin collation.
			//  Strings in other character set are converted to utf8mb4 as necessary."
			[theField setObject:@"utf8mb4" forKey:@"encodingName"];
			[theField setObject:@"utf8mb4_bin" forKey:@"collationName"];
			[theField setObject:@1 forKey:@"binary"];
		}
		else if ([fieldValidation isFieldTypeString:type]) {
			// The MySQL 4.1 manual says:
			//
			// MySQL chooses the column character set and collation in the following manner:
			//   1. If both CHARACTER SET X and COLLATE Y were specified, then character set X and collation Y are used.
			//   2. If CHARACTER SET X was specified without COLLATE, then character set X and its default collation are used.
			//   3. If COLLATE Y was specified without CHARACTER SET, then the character set associated with Y and collation Y.
			//   4. Otherwise, the table character set and collation are used.
			NSString *encoding  = [theField objectForKey:@"encoding"];
			NSString *collation = [theField objectForKey:@"collation"];
			if(encoding) {
				if(collation) {
					// 1
				}
				else {
					collation = [databaseDataInstance getDefaultCollationForEncoding:encoding]; // 2
				}
			}
			else {
				if(collation) {
					encoding = [databaseDataInstance getEncodingFromCollation:collation]; // 3
				}
				else {
					encoding = [tableDataInstance tableEncoding]; //4
					collation = [tableDataInstance statusValueForKey:@"Collation"];
					if(!collation) {
						// should not happen, as the TABLE STATUS output always(?) includes the collation
						collation = [databaseDataInstance getDefaultCollationForEncoding:encoding];
					}
				}
			}

			// MySQL < 4.1 does not support collations (they are part of the charset), it will be nil there

			[theField setObject:encoding forKey:@"encodingName"];
			[theField setObject:collation forKey:@"collationName"];

			// Set BINARY if collation ends with _bin for convenience
			if ([collation hasSuffix:@"_bin"]) {
				[theField setObject:@1 forKey:@"binary"];
			}
		}
		
		// Get possible values if the field is an enum or a set
		if (([type isEqualToString:@"ENUM"] || [type isEqualToString:@"SET"]) && [theField objectForKey:@"values"]) {
			[theTableEnumLists setObject:[NSArray arrayWithArray:[theField objectForKey:@"values"]] forKey:[theField objectForKey:@"name"]];
			[theField setObject:[NSString stringWithFormat:@"'%@'", [[theField objectForKey:@"values"] componentsJoinedByString:@"','"]] forKey:@"length"];
		}
		
		// Join length and decimals if any
		if ([theField objectForKey:@"decimals"])
			[theField setObject:[NSString stringWithFormat:@"%@,%@", [theField objectForKey:@"length"], [theField objectForKey:@"decimals"]] forKey:@"length"];
		
		// Normalize default
		if (![theField objectForKey:@"default"]) {
			[theField setObject:@"" forKey:@"default"];
		}
		else if ([[theField objectForKey:@"default"] isNSNull]) {
			[theField setObject:[prefs stringForKey:SPNullValue] forKey:@"default"];
		}
		
		// Init Extra field
		[theField setObject:@"None" forKey:@"Extra"];
		
		// Check for auto_increment and set Extra accordingly
		if ([[theField objectForKey:@"autoincrement"] integerValue]) {
			[theField setObject:@"auto_increment" forKey:@"Extra"];
		}
		
		// For timestamps/datetime check to see whether "on update CURRENT_TIMESTAMP"  and set Extra accordingly
		else if ([type isInArray:@[@"TIMESTAMP",@"DATETIME"]] && [[theField objectForKey:@"onupdatetimestamp"] boolValue]) {
			NSString *ouct = @"on update CURRENT_TIMESTAMP";
			// restore a length parameter if the field has fractional seconds.
			// the parameter of current_timestamp MUST match the field's length in that case, so we can just 'guess' it.
			NSString *fieldLen = [theField objectForKey:@"length"];
			if([fieldLen length] && ![fieldLen isEqualToString:@"0"]) {
				ouct = [ouct stringByAppendingFormat:@"(%@)",fieldLen];
			}
			[theField setObject:ouct forKey:@"Extra"];
		}
	}
	
	// Set up the table details for the new table, and request an data/interface update
	NSDictionary *tableDetails = [NSDictionary dictionaryWithObjectsAndKeys:
								  aTable, @"name",
								  theTableFields, @"tableFields",
								  theTableIndexes, @"tableIndexes",
								  theTableEnumLists, @"enumLists",
								  nil];
	
	[[self onMainThread] setTableDetails:tableDetails];
	
	isCurrentExtraAutoIncrement = [tableDataInstance tableHasAutoIncrementField];
	autoIncrementIndex = nil;
	
	// Send the query finished/work complete notification
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];
	
	[theTableFields release];
}

/**
 * Reloads the table (performing a new query).
 */
- (IBAction)reloadTable:(id)sender
{
	// Check whether a save of the current row is required
	if (![[self onMainThread] saveRowOnDeselect]) return;
	
	[tableDataInstance resetAllData];
	[tableDocumentInstance setStatusRequiresReload:YES];
	
	// Query the structure of all databases in the background (mainly for completion)
	[[tableDocumentInstance databaseStructureRetrieval] queryDbStructureInBackgroundWithUserInfo:@{@"forceUpdate" : @YES}];
	
	[self loadTable:selectedTable];
}

/**
 * Updates the stored table details and updates the interface to match.
 *
 * Should be called on the main thread.
 */
- (void)setTableDetails:(NSDictionary *)tableDetails
{
	NSString *newTableName = [tableDetails objectForKey:@"name"];
	NSMutableDictionary *newDefaultValues;
	
	BOOL enableInteraction = 
#ifndef SP_CODA /* patch */
	![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableStructure] ||
#endif
	![tableDocumentInstance isWorking];
	
	// Update the selected table name
	if (selectedTable) SPClear(selectedTable);
	if (newTableName) selectedTable = [[NSString alloc] initWithString:newTableName];
	
	[indexesController setTable:selectedTable];
	
	// Reset the table store and display
	[tableSourceView deselectAll:self];
	[tableFields removeAllObjects];
	[enumFields removeAllObjects];
	[indexesTableView deselectAll:self];
	[addFieldButton setEnabled:NO];
	[duplicateFieldButton setEnabled:NO];
	[removeFieldButton setEnabled:NO];
#ifndef SP_CODA
	[addIndexButton setEnabled:NO];
	[removeIndexButton setEnabled:NO];
	[editTableButton setEnabled:NO];
#endif
	
	// If no table is selected, refresh the table/index display to blank and return
	if (!selectedTable) {
		[tableSourceView reloadData];
		// Empty indexesController's fields and indices explicitly before reloading
		[indexesController setFields:@[]];
		[indexesController setIndexes:@[]];
		[indexesTableView reloadData];
		
		return;
	}
	
	// Update the fields and indexes stores
	[tableFields setArray:[tableDetails objectForKey:@"tableFields"]];
	
	[indexesController setFields:tableFields];
	[indexesController setIndexes:[tableDetails objectForKey:@"tableIndexes"]];
	
	if (defaultValues) SPClear(defaultValues);
	
	newDefaultValues = [NSMutableDictionary dictionaryWithCapacity:[tableFields count]];
	
	for (id theField in tableFields)
	{
		[newDefaultValues setObject:[theField objectForKey:@"default"] forKey:[theField objectForKey:@"name"]];
	}
	
	defaultValues = [[NSDictionary dictionaryWithDictionary:newDefaultValues] retain];
	
#ifndef SP_CODA
	// Enable the edit table button
	[editTableButton setEnabled:enableInteraction];
#endif
	
	// If a view is selected, disable the buttons; otherwise enable.
	BOOL editingEnabled = ([tablesListInstance tableType] == SPTableTypeTable) && enableInteraction;
	
	[addFieldButton setEnabled:editingEnabled];
#ifndef SP_CODA
	[addIndexButton setEnabled:editingEnabled && ![[[tableDataInstance statusValueForKey:@"Engine"] uppercaseString] isEqualToString:@"CSV"]];
#endif
	
	// Reload the views
	[indexesTableView reloadData];
	[tableSourceView reloadData];
}

@end
