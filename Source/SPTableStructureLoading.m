//
//  $Id$
//
//  SPTableStructureLoading.m
//  Sequel Pro
//
//  Created by Stuart Connolly (stuconnolly.com) on July 4, 2012
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
#import "SPTableFieldValidation.h"
#import "SPDatabaseViewController.h"
#import "SPIndexesController.h"
#import "SPTablesList.h"

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
			SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"),
							  nil, nil, [NSApp mainWindow], self, nil, nil,
							  [NSString stringWithFormat:NSLocalizedString(@"An error occurred while retrieving information.\nMySQL said: %@", @"message of panel when retrieving information failed"),
							   [mySQLConnection lastErrorMessage]]);
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
	
	if ([encodings count]) {
		
		// Populate encoding popup button
		NSMutableArray *encodingTitles = [[NSMutableArray alloc] initWithCapacity:[encodings count]+1];
		
		[encodingTitles addObject:@""];
		
		for (NSDictionary *encoding in encodings)
		{
			[encodingTitles addObject:(![encoding objectForKey:@"DESCRIPTION"]) ? [encoding objectForKey:@"CHARACTER_SET_NAME"] : [NSString stringWithFormat:@"%@ (%@)", [encoding objectForKey:@"DESCRIPTION"], [encoding objectForKey:@"CHARACTER_SET_NAME"]]];
		}
		
		[[encodingPopupCell onMainThread] removeAllItems];
		[[encodingPopupCell onMainThread] addItemsWithTitles:encodingTitles];
		[encodingTitles release];
	}
	else {
		[[encodingPopupCell onMainThread] removeAllItems];
		[[encodingPopupCell onMainThread] addItemWithTitle:NSLocalizedString(@"Not available", @"not available label")];
	}
	
	// Process all the fields to normalise keys and add additional information
	for (id theField in theTableFields) 
	{
		// Select and re-map encoding and collation since [self dataSource] stores the choice as NSNumbers
		NSString *fieldEncoding = @"";
		NSInteger selectedIndex = 0;
		
		NSString *type = [[[theField objectForKey:@"type"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
		
		NSString *collation = nil; 
		NSString *encoding = nil;
		
		if ([fieldValidation isFieldTypeString:type] && ![type hasSuffix:@"BINARY"] && ![type hasSuffix:@"BLOB"]) {
						
			collation = [theField objectForKey:@"collation"] ? [theField objectForKey:@"collation"] : [[tableDataInstance statusValues] objectForKey:@"collation"];
			encoding = [theField objectForKey:@"encoding"] ? [theField objectForKey:@"encoding"] : [tableDataInstance tableEncoding];
			
			// If we still don't have a collation then fallback on the database default (not available on MySQL < 4.1.1).
			if (!collation) {
				collation = [databaseDataInstance getDatabaseDefaultCollation];
			}
		}
		
		if (encoding) {
			for (id enc in encodings) 
			{
				if ([[enc objectForKey:@"CHARACTER_SET_NAME"] isEqualToString:encoding]) {
					fieldEncoding = encoding;
					break;
				}
				
				selectedIndex++;
			}
			
			// Due to leading @"" in popup list
			selectedIndex++;
		}
		
		[theField setObject:[NSNumber numberWithInteger:selectedIndex] forKey:@"encoding"];
		
		selectedIndex = 0;
		
		if (encoding && collation) {
			
			NSArray *theCollations = [databaseDataInstance getDatabaseCollationsForEncoding:fieldEncoding];
			
			for (id col in theCollations) 
			{
				if ([[col objectForKey:@"COLLATION_NAME"] isEqualToString:collation]) {
					
					// Set BINARY if collation ends with _bin for convenience
					if ([[col objectForKey:@"COLLATION_NAME"] hasSuffix:@"_bin"]) {
						[theField setObject:[NSNumber numberWithInt:1] forKey:@"binary"];
					}
					
					break;
				}
				
				selectedIndex++;
			}
			
			// Due to leading @"" in popup list
			selectedIndex++;
		}
		
		[theField setObject:[NSNumber numberWithInteger:selectedIndex] forKey:@"collation"];
		
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
		
		// For timestamps check to see whether "on update CURRENT_TIMESTAMP"  and set Extra accordingly
		else if ([type isEqualToString:@"TIMESTAMP"] && [[theField objectForKey:@"onupdatetimestamp"] integerValue]) {
			[theField setObject:@"on update CURRENT_TIMESTAMP" forKey:@"Extra"];
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
	[NSThread detachNewThreadSelector:@selector(queryDbStructureWithUserInfo:) 
							 toTarget:[tableDocumentInstance databaseStructureRetrieval] 
						   withObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"forceUpdate", nil]];
	
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
#ifndef SP_REFACTOR /* patch */
	![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableStructure] ||
#endif
	![tableDocumentInstance isWorking];
	
	// Update the selected table name
	if (selectedTable) [selectedTable release], selectedTable = nil;
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
#ifndef SP_REFACTOR
	[addIndexButton setEnabled:NO];
	[removeIndexButton setEnabled:NO];
	[editTableButton setEnabled:NO];
#endif
	
	// If no table is selected, refresh the table/index display to blank and return
	if (!selectedTable) {
		[tableSourceView reloadData];
		// Empty indexesController's fields and indices explicitly before reloading
		[indexesController setFields:[NSArray array]];
		[indexesController setIndexes:[NSArray array]];
		[indexesTableView reloadData];
		
		return;
	}
	
	// Update the fields and indexes stores
	[tableFields setArray:[tableDetails objectForKey:@"tableFields"]];
	
	[indexesController setFields:tableFields];
	[indexesController setIndexes:[tableDetails objectForKey:@"tableIndexes"]];
	
	if (defaultValues) [defaultValues release], defaultValues = nil;
	
	newDefaultValues = [NSMutableDictionary dictionaryWithCapacity:[tableFields count]];
	
	for (id theField in tableFields)
	{
		[newDefaultValues setObject:[theField objectForKey:@"default"] forKey:[theField objectForKey:@"name"]];
	}
	
	defaultValues = [[NSDictionary dictionaryWithDictionary:newDefaultValues] retain];
	
#ifndef SP_REFACTOR
	// Enable the edit table button
	[editTableButton setEnabled:enableInteraction];
#endif
	
	// If a view is selected, disable the buttons; otherwise enable.
	BOOL editingEnabled = ([tablesListInstance tableType] == SPTableTypeTable) && enableInteraction;
	
	[addFieldButton setEnabled:editingEnabled];
#ifndef SP_REFACTOR
	[addIndexButton setEnabled:editingEnabled];
#endif
	
	// Reload the views
	[indexesTableView reloadData];
	[tableSourceView reloadData];
}

@end
