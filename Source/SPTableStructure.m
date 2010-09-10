//
//  $Id$
//
//  SPTableStructure.m
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed May 01 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
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

#import "SPTableStructure.h"
#import "SPDatabaseDocument.h"
#import "SPTableInfo.h"
#import "SPTablesList.h"
#import "SPTableData.h"
#import "SPSQLParser.h"
#import "SPStringAdditions.h"
#import "SPArrayAdditions.h"
#import "SPConstants.h"
#import "SPAlertSheets.h"
#import "SPMainThreadTrampoline.h"
#import "SPIndexesController.h"
#import "RegexKitLite.h"

@interface SPTableStructure (PrivateAPI)

- (void)_removeFieldAndForeignKey:(NSNumber *)removeForeignKey;
- (BOOL)_isFieldTypeNumeric:(NSString*)aType;
- (BOOL)_isFieldTypeDate:(NSString*)aType;
- (BOOL)_isFieldTypeString:(NSString*)aType;

@end

@implementation SPTableStructure

#pragma mark -

/**
 * Init.
 */
- (id)init
{
	if ((self = [super init])) {
		tableFields = [[NSMutableArray alloc] init];
		oldRow      = [[NSMutableDictionary alloc] init];
		enumFields  = [[NSMutableDictionary alloc] init];
		typeSuggestions = nil;

		currentlyEditingRow = -1;
		defaultValues = nil;
		selectedTable = nil;

		prefs = [NSUserDefaults standardUserDefaults];
	}

	return self;
}

/**
 * Nib awakening.
 */
- (void)awakeFromNib
{
	// Set the structure and index view's vertical gridlines if required
	[tableSourceView setGridStyleMask:([prefs boolForKey:SPDisplayTableViewVerticalGridlines]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];

	// Set the strutcture and index view's font
	[tableSourceView setFont:([prefs boolForKey:SPUseMonospacedFonts]) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[indexesTableView setFont:([prefs boolForKey:SPUseMonospacedFonts]) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];

	typeSuggestions = [[NSArray arrayWithObjects:
		@"TINYINT",
		@"SMALLINT",
		@"MEDIUMINT",
		@"INT",
		@"BIGINT",
		@"FLOAT",
		@"DOUBLE",
		@"DOUBLE PRECISION",
		@"REAL",
		@"DECIMAL",
		@"BIT",
		@"SERIAL",
		@"BOOL",
		@"BOOLEAN",
		@"DEC",
		@"FIXED",
		@"NUMERIC",
		@"--------",
		@"CHAR",
		@"VARCHAR",
		@"BINARY",
		@"VARBINARY",
		@"TINYBLOB",
		@"BLOB",
		@"TEXT",
		@"MEDIUMBLOB",
		@"MEDIUMTEXT",
		@"LONGBLOB",
		@"LONGTEXT",
		@"ENUM",
		@"SET",
		@"--------",
		@"DATE",
		@"DATETIME",
		@"TIMESTAMP",
		@"TIME",
		@"YEAR",
		nil] retain];
		// Hint: _isFieldTypeDate and _isFieldTypeNumeric must be changed if typeSuggestions was changed!
	

	databaseDataInstance = [tableDocumentInstance valueForKeyPath:@"databaseDataInstance"];

	// Add observers for document task activity
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(startDocumentTaskForTab:)
												 name:SPDocumentTaskStartNotification
											   object:tableDocumentInstance];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(endDocumentTaskForTab:)
												 name:SPDocumentTaskEndNotification
											   object:tableDocumentInstance];
}

#pragma mark -

/**
 * Loads aTable, put it in an array, update the tableViewColumns and reload the tableView
 */
- (void)loadTable:(NSString *)aTable
{
	NSMutableArray *theTableFields = [NSMutableArray array];
	NSArray *theTableIndexes;
	NSMutableDictionary *theTableEnumLists = [NSMutableDictionary dictionary];
	NSInteger i;

	// Check whether a save of the current row is required.
	if ( ![[self onMainThread] saveRowOnDeselect] ) return;

	// If no table is selected, reset the interface and return
	if (!aTable || ![aTable length]) {
		[[self onMainThread] setTableDetails:nil];
		return;
	}

	// Make a mutable copy out of the cached [tableDataInstance columns] since we're adding infos
	for(id col in [tableDataInstance columns])
		[theTableFields addObject:[[col mutableCopy] autorelease]];

	// Retrieve the indexes for the table
	indexResult = [[mySQLConnection queryString:[NSString stringWithFormat:@"SHOW INDEX FROM %@", [aTable backtickQuotedString]]] retain];

	// If an error occurred, reset the interface and abort
	if ([mySQLConnection queryErrored]) {
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];
		[[self onMainThread] setTableDetails:nil];

		if ([mySQLConnection isConnected]) {
			SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"),
					nil, nil, [NSApp mainWindow], self, nil, nil,
					[NSString stringWithFormat:NSLocalizedString(@"An error occurred while retrieving information.\nMySQL said: %@", @"message of panel when retrieving information failed"),
					   [mySQLConnection getLastErrorMessage]]);
		}
		if (indexResult) [indexResult release];
		return;
	}

	// Process the indexes into a local array of dictionaries
	theTableIndexes = [self fetchResultAsArray:indexResult];
	[indexResult release];

	// Set the Key column
	for(NSDictionary* theIndex in theTableIndexes) {
		for(id field in theTableFields) {
			if([[field objectForKey:@"name"] isEqualToString:[theIndex objectForKey:@"Column_name"]]) {
				if([[theIndex objectForKey:@"Key_name"] isEqualToString:@"PRIMARY"])
					[field setObject:@"PRI" forKey:@"Key"];
				else
					[field setObject:(([[theIndex objectForKey:@"Non_unique"] isEqualToString:@"1"]) ? @"MUL" : @"UNI") forKey:@"Key"];
				break;
			}
		}
	}

	// Set up the encoding PopUpButtonCell
	NSArray *encodings  = [databaseDataInstance getDatabaseCharacterSetEncodings];
	if (([encodings count] > 0) && ([tableDataInstance tableEncoding])) {
		NSString *selectedTitle = @"";
		[encodingPopupCell removeAllItems];
		[encodingPopupCell addItemWithTitle:@""];
		// Populate encoding popup button
		for (NSDictionary *encoding in encodings)
		{
			NSString *menuItemTitle = (![encoding objectForKey:@"DESCRIPTION"]) ? [encoding objectForKey:@"CHARACTER_SET_NAME"] : [NSString stringWithFormat:@"%@ (%@)", [encoding objectForKey:@"DESCRIPTION"], [encoding objectForKey:@"CHARACTER_SET_NAME"]];
			[encodingPopupCell addItemWithTitle:menuItemTitle];
		}
	}
	else {
		[encodingPopupCell addItemWithTitle:NSLocalizedString(@"Not available", @"not available label")];
	}

	// Process all the fields to normalise keys and add additional information
	for (id theField in theTableFields) {

		// Select and re-map encoding and collation since [self dataSource] stores the choice as NSNumbers
		NSString *fieldEncoding = @"";
		NSInteger selectedIndex = 0;
		if([theField objectForKey:@"encoding"]) {
			for(id enc in encodings) {
				if([[enc objectForKey:@"CHARACTER_SET_NAME"] isEqualToString:[theField objectForKey:@"encoding"]]) {
					fieldEncoding = [theField objectForKey:@"encoding"];
					break;
				}
				selectedIndex++;
			}
			selectedIndex++; // due to leading @"" in popup list
		}
		[theField setObject:[NSNumber numberWithInt:selectedIndex] forKey:@"encoding"];
		selectedIndex = 0;
		if([fieldEncoding length] && [theField objectForKey:@"collation"]) {
			NSArray *theCollations = [databaseDataInstance getDatabaseCollationsForEncoding:fieldEncoding];
			for(id col in theCollations) {
				if([[col objectForKey:@"COLLATION_NAME"] isEqualToString:[theField objectForKey:@"collation"]]) {
					break;
				}
				selectedIndex++;
			}
			selectedIndex++; // due to leading @"" in popup list
		}
		[theField setObject:[NSNumber numberWithInt:selectedIndex] forKey:@"collation"];

		NSString *type = [[theField objectForKey:@"type"] uppercaseString];

		// Get possible values if the field is an enum or a set
		if (([type isEqualToString:@"ENUM"] || [type isEqualToString:@"SET"]) && [theField objectForKey:@"values"]) {
			[theTableEnumLists setObject:[NSArray arrayWithArray:[theField objectForKey:@"values"]] forKey:[theField objectForKey:@"name"]];
			[theField setObject:[NSString stringWithFormat:@"'%@'", [[theField objectForKey:@"values"] componentsJoinedByString:@"','"]] forKey:@"length"];
		}

		// Join length and decimals if any
		if ([theField objectForKey:@"decimals"])
			[theField setObject:[NSString stringWithFormat:@"%@,%@", [theField objectForKey:@"length"], [theField objectForKey:@"decimals"]] forKey:@"length"];

		// Normalize default
		if(![theField objectForKey:@"default"])
			[theField setObject:@"" forKey:@"default"];
		else if([[theField objectForKey:@"default"] isKindOfClass:[NSNull class]])
			[theField setObject:[prefs stringForKey:SPNullValue] forKey:@"default"];

		// Init Extra field
		[theField setObject:@"None" forKey:@"Extra"];

		// Check for auto_increment and set Extra accordingly
		if([[theField objectForKey:@"autoincrement"] integerValue])
			[theField setObject:@"auto_increment" forKey:@"Extra"];

		// For timestamps check to see whether "on update CURRENT_TIMESTAMP"  and set Extra accordingly
		else if ([type isEqualToString:@"TIMESTAMP"] && [[theField objectForKey:@"onupdatetimestamp"] integerValue])
			[theField setObject:@"on update CURRENT_TIMESTAMP" forKey:@"Extra"];

	}

	// Set up the table details for the new table, and request an data/interface update
	NSDictionary *tableDetails = [NSDictionary dictionaryWithObjectsAndKeys:
									aTable, @"name",
									theTableFields, @"tableFields",
									theTableIndexes, @"tableIndexes",
									theTableEnumLists, @"enumLists",
									nil];
	[[self onMainThread] setTableDetails:tableDetails];

	// Send the query finished/work complete notification
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];

}

/**
 * Reloads the table (performing a new mysql-query)
 */
- (IBAction)reloadTable:(id)sender
{
	[tableDataInstance resetAllData];
	[tablesListInstance setStatusRequiresReload:YES];

	// Query the structure of all databases in the background (mainly for completion)
	[NSThread detachNewThreadSelector:@selector(queryDbStructureWithUserInfo:) toTarget:mySQLConnection withObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"forceUpdate", nil]];

	[self loadTable:selectedTable];
}

/**
 * Update stored table details and update the interface to match the supplied
 * table details.
 * Should be called on the main thread.
 */
- (void) setTableDetails:(NSDictionary *)tableDetails
{
	NSString *newTableName = [tableDetails objectForKey:@"name"];
	NSMutableDictionary *newDefaultValues;
	BOOL enableInteraction = ![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableStructure] || ![tableDocumentInstance isWorking];

	// Update the selected table name
	if (selectedTable) [selectedTable release], selectedTable = nil;
	if (newTableName) selectedTable = [[NSString alloc] initWithString:newTableName];

	[indexesController setTable:selectedTable];

	// Reset the table store and display
	[enumFields removeAllObjects];
	[tableSourceView deselectAll:self];
	[indexesTableView deselectAll:self];
	[tableFields removeAllObjects];
	[addFieldButton setEnabled:NO];
	[copyFieldButton setEnabled:NO];
	[removeFieldButton setEnabled:NO];
	[addIndexButton setEnabled:NO];
	[removeIndexButton setEnabled:NO];
	[editTableButton setEnabled:NO];

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
		[newDefaultValues setObject:[theField objectForKey:@"default"] forKey:[theField objectForKey:@"name"]];

	defaultValues = [[NSDictionary dictionaryWithDictionary:newDefaultValues] retain];

	// Enable the edit table button
	[editTableButton setEnabled:enableInteraction];

	// If a view is selected, disable the buttons; otherwise enable.
	BOOL editingEnabled = ([tablesListInstance tableType] == SPTableTypeTable) && enableInteraction;

	[addFieldButton setEnabled:editingEnabled];
	[addIndexButton setEnabled:editingEnabled];

	// Reload the views
	[indexesTableView reloadData];
	[tableSourceView reloadData];
}

#pragma mark -
#pragma mark Edit methods

/**
 * Adds an empty row to the tableSource-array and goes into edit mode
 */
- (IBAction)addField:(id)sender
{
	// Check whether a save of the current row is required.
	if ( ![self saveRowOnDeselect] ) return;

	NSInteger insertIndex = ([tableSourceView numberOfSelectedRows] == 0 ? [tableSourceView numberOfRows] : [tableSourceView selectedRow] + 1);

	[tableFields insertObject:[NSMutableDictionary
							   dictionaryWithObjects:[NSArray arrayWithObjects:@"", @"INT", @"", @"0", @"0", @"0", ([prefs boolForKey:SPNewFieldsAllowNulls]) ? @"1" : @"0", @"", [prefs stringForKey:SPNullValue], @"None", @"", [NSNumber numberWithInt:0], [NSNumber numberWithInt:0], nil]
							   forKeys:[NSArray arrayWithObjects:@"name", @"type", @"length", @"unsigned", @"zerofill", @"binary", @"null", @"Key", @"default", @"Extra", @"comment", @"encoding", @"collation", nil]]
					  atIndex:insertIndex];

	[tableSourceView reloadData];
	[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:insertIndex] byExtendingSelection:NO];
	isEditingRow = YES;
	isEditingNewRow = YES;
	currentlyEditingRow = [tableSourceView selectedRow];
	[tableSourceView editColumn:0 row:insertIndex withEvent:nil select:YES];
}

/**
 * Copies a field and goes in edit mode for the new field
 */
- (IBAction)copyField:(id)sender
{
	NSMutableDictionary *tempRow;
	NSUInteger rowToCopy;

	// Store the row to duplicate, as saveRowOnDeselect and subsequent reloads may trigger a deselection
	if ([tableSourceView numberOfSelectedRows]) {
		rowToCopy = [tableSourceView selectedRow];
	} else {
		rowToCopy = [tableSourceView numberOfRows]-1;
	}

	// Check whether a save of the current row is required.
	if ( ![self saveRowOnDeselect] ) return;

	//add copy of selected row and go in edit mode
	tempRow = [NSMutableDictionary dictionaryWithDictionary:[tableFields objectAtIndex:rowToCopy]];
	[tempRow setObject:[[tempRow objectForKey:@"name"] stringByAppendingString:@"Copy"] forKey:@"name"];
	[tempRow setObject:@"" forKey:@"Key"];
	[tempRow setObject:@"None" forKey:@"Extra"];
	[tableFields addObject:tempRow];
	[tableSourceView reloadData];
	[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:[tableSourceView numberOfRows]-1] byExtendingSelection:NO];
	isEditingRow = YES;
	isEditingNewRow = YES;
	currentlyEditingRow = [tableSourceView selectedRow];
	[tableSourceView editColumn:0 row:[tableSourceView numberOfRows]-1 withEvent:nil select:YES];
}

/**
 * Ask the user to confirm that they really want to remove the selected field.
 */
- (IBAction)removeField:(id)sender
{
	if (![tableSourceView numberOfSelectedRows]) return;

	// Check whether a save of the current row is required.
	if (![self saveRowOnDeselect]) return;

	NSInteger index = [tableSourceView selectedRow];

	if ((index == -1) || (index > ([tableFields count] - 1))) return;

	// Check if the user tries to delete the last defined field in table
	// Note that because of better menu item validation, this check will now never evaluate to true.
	if ([tableSourceView numberOfRows] < 2) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error while deleting field", @"Error while deleting field")
										 defaultButton:NSLocalizedString(@"OK", @"OK button")
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:NSLocalizedString(@"You cannot delete the last field in a table. Delete the table instead.", @"You cannot delete the last field in a table. Delete the table instead.")];

		[alert setAlertStyle:NSCriticalAlertStyle];

		[alert beginSheetModalForWindow:[tableDocumentInstance parentWindow] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"cannotremovefield"];

	}

	NSString *field = [[tableFields objectAtIndex:index] objectForKey:@"name"];

	BOOL hasForeignKey = NO;
	NSString *referencedTable = @"";

	// Check to see whether the user is attempting to remove a field that has foreign key constraints and thus
	// would result in an error if not dropped before removing the field.
	for (NSDictionary *constraint in [tableDataInstance getConstraints])
	{
		for (NSString *column in [constraint objectForKey:@"columns"])
		{
			if ([column isEqualToString:field]) {
				hasForeignKey = YES;
				referencedTable = [constraint objectForKey:@"ref_table"];
				break;
			}
		}
	}

	NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Delete field '%@'?", @"delete field message"), field]
									 defaultButton:NSLocalizedString(@"Delete", @"delete button")
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
									   otherButton:nil
						 informativeTextWithFormat:(hasForeignKey) ? [NSString stringWithFormat:NSLocalizedString(@"This field is part of a foreign key relationship with the table '%@'. This relationship must be removed before the field can be deleted.\n\nAre you sure you want to continue to delete the relationship and the field? This action cannot be undone.", @"delete field and foreign key informative message"), referencedTable] : [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the field '%@'? This action cannot be undone.", @"delete field informative message"), field]];

	[alert setAlertStyle:NSCriticalAlertStyle];

	NSArray *buttons = [alert buttons];

	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"d"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];

	[alert beginSheetModalForWindow:[tableDocumentInstance parentWindow] modalDelegate:self didEndSelector:@selector(removeFieldSheetDidEnd:returnCode:contextInfo:) contextInfo:(hasForeignKey) ? @"removeFieldAndForeignKey" : @"removeField"];
}

/**
 *
 */
- (IBAction)resetAutoIncrement:(id)sender
{
	if ([sender tag] == 1) {

		[resetAutoIncrementLine setHidden:YES];

		if ([[tableDocumentInstance valueForKeyPath:@"tableTabView"] indexOfTabViewItem:[[tableDocumentInstance valueForKeyPath:@"tableTabView"] selectedTabViewItem]] == 0)
			[resetAutoIncrementLine setHidden:NO];

		// Begin the sheet
		[NSApp beginSheet:resetAutoIncrementSheet
		   modalForWindow:[tableDocumentInstance parentWindow]
			modalDelegate:self
		   didEndSelector:@selector(resetAutoincrementSheetDidEnd:returnCode:contextInfo:)
			  contextInfo:nil];

		[resetAutoIncrementValue setStringValue:@"1"];
	}
	else if ([sender tag] == 2) {
		[self setAutoIncrementTo:@"1"];
	}
}

/**
 * Process the autoincrement sheet closing, resetting if the user confirmed the action.
 */
- (void)resetAutoincrementSheetDidEnd:(NSWindow *)theSheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	// Order out current sheet to suppress overlapping of sheets
	[theSheet orderOut:nil];

	if (returnCode == NSAlertDefaultReturn) {
		[self setAutoIncrementTo:[[resetAutoIncrementValue stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
	}
}

/**
 * Process the remove field sheet closing, performing the delete if the user
 * confirmed the action.
 */
- (void)removeFieldSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	// Order out current sheet to suppress overlapping of sheets
	[[alert window] orderOut:nil];

	if (returnCode == NSAlertDefaultReturn) {
		[tableDocumentInstance startTaskWithDescription:NSLocalizedString(@"Removing field...", @"removing field task status message")];

		NSNumber *removeKey = [NSNumber numberWithBool:[contextInfo hasSuffix:@"AndForeignKey"]];

		if ([NSThread isMainThread]) {
			[NSThread detachNewThreadSelector:@selector(_removeFieldAndForeignKey:) toTarget:self withObject:removeKey];

			[tableDocumentInstance enableTaskCancellationWithTitle:NSLocalizedString(@"Cancel", @"cancel button") callbackObject:self callbackFunction:NULL];
		}
		else {
			[self _removeFieldAndForeignKey:removeKey];
		}
	}
}

#pragma mark -
#pragma mark Index sheet methods

/**
 * Closes the current sheet and stops the modal session
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

/*
closes the keySheet
*/
- (IBAction)closeKeySheet:(id)sender
{
	[NSApp stopModalWithCode:[sender tag]];
}


#pragma mark -
#pragma mark Additional methods

/**
 * Sets the connection (received from SPDatabaseDocument) and makes things that have to be done only once
 */
- (void)setConnection:(MCPConnection *)theConnection
{
	mySQLConnection = theConnection;

	// Set the indexes controller connection
	[indexesController setConnection:mySQLConnection];

	// Set up tableView
	[tableSourceView registerForDraggedTypes:[NSArray arrayWithObjects:@"SequelProPasteboard", nil]];
}

- (void)setAutoIncrementTo:(NSString*)valueAsString
{

	NSString *selTable = nil;

	// if selectedTable is nil try to get the name from SPTablesList
	if(selectedTable == nil || ![selectedTable length])
		selTable = [tablesListInstance tableName];
	else
		selTable = [NSString stringWithString:selectedTable];

	if(selTable == nil || ![selTable length])
		return;

	if(valueAsString == nil || ![valueAsString length]) {
		// reload data and bail
		[tableDataInstance resetAllData];
		[extendedTableInfoInstance loadTable:selTable];
		[tableInfoInstance tableChanged:nil];
		return;
	}

	NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
	[formatter setNumberStyle:NSNumberFormatterDecimalStyle];
	NSNumber *autoIncValue = [formatter numberFromString:valueAsString];
	[formatter release];

	[mySQLConnection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ AUTO_INCREMENT = %@", [selTable backtickQuotedString], [autoIncValue stringValue]]];

	if ([mySQLConnection queryErrored]) {
		SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"),
						  NSLocalizedString(@"OK", @"OK button"),
						  nil, nil, [NSApp mainWindow], nil, nil, nil,
						  [NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to reset AUTO_INCREMENT of table '%@'.\n\nMySQL said: %@", @"error resetting auto_increment informative message"),
								selTable, [mySQLConnection getLastErrorMessage]]);
	}

	// reload data
	[tableDataInstance resetStatusData];
	if([[tableDocumentInstance valueForKeyPath:@"tableTabView"] indexOfTabViewItem:[[tableDocumentInstance valueForKeyPath:@"tableTabView"] selectedTabViewItem]] == 3) {
		[tableDataInstance resetAllData];
		[extendedTableInfoInstance loadTable:selTable];
	}

	[tableInfoInstance tableChanged:nil];

}

/**
 * Converts the supplied result to an array containing a (mutable) dictionary for each row
 */
- (NSArray *)fetchResultAsArray:(MCPResult *)theResult
{
	NSUInteger numOfRows = [theResult numOfRows];
	NSMutableArray *tempResult = [NSMutableArray arrayWithCapacity:numOfRows];
	NSMutableDictionary *tempRow;
	NSArray *keys;
	NSInteger i;
	id prefsNullValue = [prefs objectForKey:SPNullValue];

	// Ensure table information is returned as strings to avoid problems with some server versions
	[theResult setReturnDataAsStrings:YES];

	if (numOfRows) [theResult dataSeek:0];
	for ( i = 0 ; i < numOfRows ; i++ ) {
		tempRow = [NSMutableDictionary dictionaryWithDictionary:[theResult fetchRowAsDictionary]];

		// Replace NSNull instances with the NULL string from preferences
		keys = [tempRow allKeys];
		for (id theKey in keys) {
			if ([[tempRow objectForKey:theKey] isNSNull])
				[tempRow setObject:prefsNullValue forKey:theKey];
		}

		// Update some fields to be more human-readable or GUI compatible
		if ([[tempRow objectForKey:@"Extra"] isEqualToString:@""]) {
			[tempRow setObject:@"None" forKey:@"Extra"];
		}
		if ([[tempRow objectForKey:@"Null"] isEqualToString:@"YES"]) {
			[tempRow setObject:@"1" forKey:@"Null"];
		} else {
			[tempRow setObject:@"0" forKey:@"Null"];
		}
		[tempResult addObject:tempRow];
	}

	return tempResult;
}


/*
 * A method to be called whenever the selection changes or the table would be reloaded
 * or altered; checks whether the current row is being edited, and if so attempts to save
 * it.  Returns YES if no save was necessary or the save was successful, and NO if a save
 * was necessary but failed - also reselecting the row for re-editing.
 */
- (BOOL)saveRowOnDeselect
{
	// If no rows are currently being edited, or a save is already in progress, return success at once.
	if (!isEditingRow || isSavingRow) return YES;
	isSavingRow = YES;

	// Save any edits which have been made but not saved to the table yet.
	[[tableDocumentInstance parentWindow] endEditingFor:nil];

	// Attempt to save the row, and return YES if the save succeeded.
	if ([self addRowToDB]) {
		isSavingRow = NO;
		return YES;
	}

	// Saving failed - return failure.
	isSavingRow = NO;
	return NO;
}

/**
 * tries to write row to mysql-db
 * returns YES if row written to db, otherwies NO
 * returns YES if no row is beeing edited and nothing has to be written to db
 */
- (BOOL)addRowToDB;
{

	if (!isEditingRow || currentlyEditingRow == -1)
		return YES;

	if (alertSheetOpened)
		return NO;

	NSInteger code;
	NSDictionary *theRow;
	NSMutableString *queryString;

	NSString *theRowType = @"";
	NSString *theRowExtra = @"";
	
	BOOL specialFieldTypes = NO;

	theRow = [tableFields objectAtIndex:currentlyEditingRow];

	if([theRow objectForKey:@"type"])
		theRowType = [[[theRow objectForKey:@"type"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];

	if([theRow objectForKey:@"Extra"])
		theRowExtra = [[[theRow objectForKey:@"Extra"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];

	if(isEditingNewRow)
		queryString = [NSMutableString stringWithFormat:@"ALTER TABLE %@ ADD %@ %@", 
			[selectedTable backtickQuotedString], 
			[[theRow objectForKey:@"name"] backtickQuotedString], 
			theRowType];
	else
		queryString = [NSMutableString stringWithFormat:@"ALTER TABLE %@ CHANGE %@ %@ %@", 
			[selectedTable backtickQuotedString], 
			[[theRow objectForKey:@"name"] backtickQuotedString], 
			[[theRow objectForKey:@"name"] backtickQuotedString], 
			theRowType];

	// Check for pre-defined field type SERIAL
	if([theRowType isEqualToString:@"SERIAL"]) {
		specialFieldTypes = YES;
	}

	// Check for pre-defined field type BOOL(EAN)
	else if([theRowType rangeOfRegex:@"(?i)bool(ean)?"].length) {
		specialFieldTypes = YES;

		if ([[theRow objectForKey:@"null"] integerValue] == 0) {
			[queryString appendString:@"\n NOT NULL"];
		} else {
			[queryString appendString:@"\n NULL"];
		}
		// If a NULL value has been specified, and NULL is allowed, specify DEFAULT NULL
		if ([[theRow objectForKey:@"default"] isEqualToString:[prefs objectForKey:SPNullValue]]) {
			if ([[theRow objectForKey:@"null"] integerValue] == 1) {
				[queryString appendString:@"\n DEFAULT NULL "];
			}
		}
		else if (![[theRow objectForKey:@"default"] length]) {
			;
		}
		// Otherwise, use the provided default
		else {
			[queryString appendFormat:@"\n DEFAULT '%@' ", [mySQLConnection prepareString:[theRow objectForKey:@"default"]]];
		}
	}

	// Check for Length specification
	else if ([theRow objectForKey:@"length"] && [[[theRow objectForKey:@"length"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length]) {
		[queryString appendFormat:@"(%@)", [theRow objectForKey:@"length"]];
	}

	if(!specialFieldTypes) {


		if([self _isFieldTypeString:theRowType]) {
			// Add CHARSET
			NSString *fieldEncoding = @"";
			if([[theRow objectForKey:@"encoding"] integerValue] > 0) {
				NSString *enc = [[encodingPopupCell itemAtIndex:[[theRow objectForKey:@"encoding"] integerValue]] title];
				NSInteger start = [enc rangeOfString:@"("].location+1;
				NSInteger end = [enc length] - start - 1;
				fieldEncoding = [enc substringWithRange:NSMakeRange(start, end)];
				[queryString appendFormat:@"\n CHARACTER SET %@", fieldEncoding];
			}
			// Remember CHARSET for COLLATE
			if(![fieldEncoding length] && [tableDataInstance tableEncoding]) {
				fieldEncoding = [tableDataInstance tableEncoding];
			}

			// ADD COLLATE
			if([fieldEncoding length] && [[theRow objectForKey:@"collation"] integerValue] > 0) {
				NSArray *theCollations = [databaseDataInstance getDatabaseCollationsForEncoding:fieldEncoding];
				NSString *col = [[theCollations objectAtIndex:[[theRow objectForKey:@"collation"] integerValue]-1] objectForKey:@"COLLATION_NAME"];
				[queryString appendFormat:@"\n COLLATE %@", col];
			}

			if ( [[theRow objectForKey:@"binary"] integerValue] == 1) {
				[queryString appendString:@"\n BINARY"];
			}

		}

		else if([self _isFieldTypeNumeric:theRowType] && ![theRowType isEqualToString:@"BIT"]) {

			if ([[theRow objectForKey:@"unsigned"] integerValue] == 1) {
				[queryString appendString:@"\n UNSIGNED"];
			}

			if ( [[theRow objectForKey:@"zerofill"] integerValue] == 1) {
				[queryString appendString:@"\n ZEROFILL"];
			}
		}

		if ([[theRow objectForKey:@"null"] integerValue] == 0 || [theRowExtra isEqualToString:@"SERIAL DEFAULT VALUE"]) {
			[queryString appendString:@"\n NOT NULL"];
		} else {
			[queryString appendString:@"\n NULL"];
		}

		// Don't provide any defaults for auto-increment fields
		if (![theRowExtra isEqualToString:@"AUTO_INCREMENT"]) {

			// If a NULL value has been specified, and NULL is allowed, specify DEFAULT NULL
			if ([[theRow objectForKey:@"default"] isEqualToString:[prefs objectForKey:SPNullValue]]) {
				if ([[theRow objectForKey:@"null"] integerValue] == 1) {
					[queryString appendString:@"\n DEFAULT NULL"];
				}
			}
			// Otherwise, if CURRENT_TIMESTAMP was specified for timestamps, use that
			else if ([theRowType isEqualToString:@"TIMESTAMP"] &&
					 [[[theRow objectForKey:@"default"] uppercaseString] isEqualToString:@"CURRENT_TIMESTAMP"])
			{
				[queryString appendString:@"\n DEFAULT CURRENT_TIMESTAMP"];

			}
			// If the field is of type BIT, permit the use of single qoutes and also don't quote the default value.
			// For example, use DEFAULT b'1' as opposed to DEFAULT 'b\'1\'' which results in an error.
			else if ([[theRow objectForKey:@"default"] length] && [theRowType isEqualToString:@"BIT"]) {
				[queryString appendFormat:@"\n DEFAULT %@", [theRow objectForKey:@"default"]];
			}
			// Suppress appending DEFAULT clause for any numerics, date, time fields if default is empty to avoid error messages
			else if (![[theRow objectForKey:@"default"] length] && ([self _isFieldTypeNumeric:theRowType] || [self _isFieldTypeDate:theRowType])) {
				;
			}
			// Otherwise, use the provided default
			else {
				[queryString appendFormat:@"\n DEFAULT '%@'", [mySQLConnection prepareString:[theRow objectForKey:@"default"]]];
			}
		}

		if (![theRowExtra isEqualToString:@""] && ![theRowExtra isEqualToString:@"NONE"])
		{
			[queryString appendFormat:@"\n %@", theRowExtra];
		}

	}

	// Any column comments
	if ([[theRow objectForKey:@"comment"] length]) {
		[queryString appendFormat:@"\n COMMENT '%@'", [mySQLConnection prepareString:[theRow objectForKey:@"comment"]]];
	}

	if (!isEditingNewRow) {

		// Unparsed details - column formats, storage, reference definitions
		if ([[theRow objectForKey:@"unparsed"] length]) {
			[queryString appendFormat:@"\n %@", [theRow objectForKey:@"unparsed"]];
		}
	}

	// Asks the user to add an index to query if auto_increment is set and field isn't indexed
	if ([theRowExtra isEqualToString:@"AUTO_INCREMENT"] && (![theRow objectForKey:@"Key"] || [[theRow objectForKey:@"Key"] isEqualToString:@""]))
	{
		[chooseKeyButton selectItemAtIndex:0];

		[NSApp beginSheet:keySheet
		   modalForWindow:[tableDocumentInstance parentWindow] modalDelegate:self
		   didEndSelector:nil
			  contextInfo:nil];

		code = [NSApp runModalForWindow:keySheet];

		[NSApp endSheet:keySheet];
		[keySheet orderOut:nil];

		if (code) {
			// User wants to add PRIMARY KEY
			if ([chooseKeyButton indexOfSelectedItem] == 0 ) {
				[queryString appendString:@"\n PRIMARY KEY"];

				// Add AFTER ... only if the user added a new field
				if (isEditingNewRow) {
					[queryString appendFormat:@"\n AFTER %@", [[[tableFields objectAtIndex:(currentlyEditingRow -1)] objectForKey:@"name"] backtickQuotedString]];
				}
			}
			else {
				// Add AFTER ... only if the user added a new field
				if (isEditingNewRow) {
					[queryString appendFormat:@"\n AFTER %@", [[[tableFields objectAtIndex:(currentlyEditingRow -1)] objectForKey:@"name"] backtickQuotedString]];
				}

				[queryString appendFormat:@"\n, ADD %@ (%@)", [chooseKeyButton titleOfSelectedItem], [[theRow objectForKey:@"name"] backtickQuotedString]];
			}
		}
	}
	// Add AFTER ... only if the user added a new field
	else if (isEditingNewRow) {
		[queryString appendFormat:@"\n AFTER %@", [[[tableFields objectAtIndex:(currentlyEditingRow -1)] objectForKey:@"name"] backtickQuotedString]];
	}

	// Execute query
	[mySQLConnection queryString:queryString];

	if (![mySQLConnection queryErrored]) {
		isEditingRow = NO;
		isEditingNewRow = NO;
		currentlyEditingRow = -1;

		[tableDataInstance resetAllData];
		[tablesListInstance setStatusRequiresReload:YES];
		[self loadTable:selectedTable];

		// Mark the content table for refresh
		[tablesListInstance setContentRequiresReload:YES];

		// Query the structure of all databases in the background
		[NSThread detachNewThreadSelector:@selector(queryDbStructureWithUserInfo:) toTarget:mySQLConnection withObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"forceUpdate", selectedTable, @"affectedItem", [NSNumber numberWithInt:[tablesListInstance tableType]], @"affectedItemType", nil]];

		return YES;
	}
	else {
		alertSheetOpened = YES;
		if([mySQLConnection getLastErrorID] == 1146) { // If the current table doesn't exist anymore
			SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"),
							  NSLocalizedString(@"OK", @"OK button"),
							  nil, nil, [tableDocumentInstance parentWindow], self, nil, nil,
							  [NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to alter table '%@'.\n\nMySQL said: %@", @"error while trying to alter table message"),
							  selectedTable, [mySQLConnection getLastErrorMessage]]);

			isEditingRow = NO;
			isEditingNewRow = NO;
			currentlyEditingRow = -1;
			[tableFields removeAllObjects];
			//[indexes removeAllObjects];
			[tableSourceView reloadData];
			[indexesTableView reloadData];
			[addFieldButton setEnabled:NO];
			[copyFieldButton setEnabled:NO];
			[removeFieldButton setEnabled:NO];
			[addIndexButton setEnabled:NO];
			[removeIndexButton setEnabled:NO];
			[editTableButton setEnabled:NO];
			[tablesListInstance updateTables:self];
			return NO;
		}
		// Problem: alert sheet doesn't respond to first click
		if (isEditingNewRow) {
			SPBeginAlertSheet(NSLocalizedString(@"Error adding field", @"error adding field message"),
							  NSLocalizedString(@"Edit row", @"Edit row button"),
							  NSLocalizedString(@"Discard changes", @"discard changes button"), nil, [tableDocumentInstance parentWindow], self, @selector(addRowErrorSheetDidEnd:returnCode:contextInfo:), nil,
							  [NSString stringWithFormat:NSLocalizedString(@"An error occurred when trying to add the field '%@' via\n\n%@\n\nMySQL said: %@", @"error adding field informative message"),
							  [theRow objectForKey:@"name"], queryString, [mySQLConnection getLastErrorMessage]]);
		}
		else {
			SPBeginAlertSheet(NSLocalizedString(@"Error changing field", @"error changing field message"),
							  NSLocalizedString(@"Edit row", @"Edit row button"),
							  NSLocalizedString(@"Discard changes", @"discard changes button"), nil, [tableDocumentInstance parentWindow], self, @selector(addRowErrorSheetDidEnd:returnCode:contextInfo:), nil,
							  [NSString stringWithFormat:NSLocalizedString(@"An error occurred when trying to change the field '%@' via\n\n%@\n\nMySQL said: %@", @"error changing field informative message"),
							  [theRow objectForKey:@"name"], queryString, [mySQLConnection getLastErrorMessage]]);
		}

		return NO;
	}
}

/**
 * Perform the action requested in the Add Row error sheet.
 */
- (void)addRowErrorSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{

	// Order out current sheet to suppress overlapping of sheets
	[[alert window] orderOut:nil];

	alertSheetOpened = NO;

	// Remain in edit mode - reselect the row and resume editing
	if (returnCode == NSAlertDefaultReturn) {

		// Problem: reentering edit mode for first cell doesn't function
		[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:currentlyEditingRow] byExtendingSelection:NO];
		[tableSourceView performSelector:@selector(keyDown:) withObject:[NSEvent keyEventWithType:NSKeyDown location:NSMakePoint(0,0) modifierFlags:0 timestamp:0 windowNumber:[[tableDocumentInstance parentWindow] windowNumber] context:[NSGraphicsContext currentContext] characters:nil charactersIgnoringModifiers:nil isARepeat:NO keyCode:0x24] afterDelay:0.0];
	}

	// Discard changes and cancel editing
	else {
		if (!isEditingNewRow) {
			[tableFields replaceObjectAtIndex:currentlyEditingRow
								   withObject:[NSMutableDictionary dictionaryWithDictionary:oldRow]];
			isEditingRow = NO;
		}
		else {
			[tableFields removeObjectAtIndex:currentlyEditingRow];
			isEditingRow = NO;
			isEditingNewRow = NO;
		}

		currentlyEditingRow = -1;
	}

	[tableSourceView reloadData];
}

/**
 * A method to show an error sheet after a short delay, so that it can
 * be called from within an endSheet selector. This should be called on
 * the main thread.
 */
-(void)showErrorSheetWith:(NSDictionary *)errorDictionary
{

	// If this method has been called directly, invoke a delay.  Invoking the delay
	// on the main thread ensures the timer fires on the main thread.
	if (![errorDictionary objectForKey:@"delayed"]) {
		NSMutableDictionary *delayedErrorDictionary = [NSMutableDictionary dictionaryWithDictionary:errorDictionary];
		[delayedErrorDictionary setObject:[NSNumber numberWithBool:YES] forKey:@"delayed"];
		[self performSelector:@selector(showErrorSheetWith:) withObject:delayedErrorDictionary afterDelay:0.3];
		return;
	}

	// Display the error sheet
	SPBeginAlertSheet([errorDictionary objectForKey:@"title"], NSLocalizedString(@"OK", @"OK button"),
			nil, nil, [tableDocumentInstance parentWindow], self, nil, nil,
			[errorDictionary objectForKey:@"message"]);
}

/**
 * This method is called as part of Key Value Observing which is used to watch for preference changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	// Display table veiew vertical gridlines preference changed
	if ([keyPath isEqualToString:SPDisplayTableViewVerticalGridlines]) {
        [tableSourceView setGridStyleMask:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	}
	// Use monospaced fonts preference changed
	else if ([keyPath isEqualToString:SPUseMonospacedFonts]) {

		BOOL useMonospacedFont = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];

		[tableSourceView setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		[indexesTableView setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];

		[tableSourceView reloadData];
		[indexesTableView reloadData];
	}
}

/**
 * Menu validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// Remove field
	if ([menuItem action] == @selector(removeField:)) {
		return (([tableSourceView numberOfSelectedRows] == 1) && ([tableSourceView numberOfRows] > 1));
	}

	// Duplicate field
	if ([menuItem action] == @selector(copyField:)) {
		return ([tableSourceView numberOfSelectedRows] == 1);
	}

	// Reset AUTO_INCREMENT
	if ([menuItem action] == @selector(resetAutoIncrement:)) {
		return [indexesController validateMenuItem:menuItem];
	}

	return YES;
}

#pragma mark -
#pragma mark Alert sheet methods

/**
 * Called whenever a sheet is dismissed.
 */
- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{

	// Order out current sheet to suppress overlapping of sheets
	if ([sheet respondsToSelector:@selector(orderOut:)])
		[sheet orderOut:nil];
	else if ([sheet respondsToSelector:@selector(window)])
		[[sheet window] orderOut:nil];

	alertSheetOpened = NO;
}

#pragma mark -
#pragma mark Getter methods

/*
get the default value for a specified field
*/
- (NSString *)defaultValueForField:(NSString *)field
{
	if ( ![defaultValues objectForKey:field] ) {
		return [prefs objectForKey:SPNullValue];
	} else if ( [[defaultValues objectForKey:field] isMemberOfClass:[NSNull class]] ) {
		return [prefs objectForKey:SPNullValue];
	} else {
		return [defaultValues objectForKey:field];
	}
}

/*
returns an array containing the field names of the selected table
*/
- (NSArray *)fieldNames
{
	NSMutableArray *tempArray = [NSMutableArray array];
	NSEnumerator *enumerator;
	id field;

	//load table if not already done
	if ( ![tablesListInstance structureLoaded] ) {
		[self loadTable:[tablesListInstance tableName]];
	}

	//get field names
	enumerator = [tableFields objectEnumerator];
	while ( (field = [enumerator nextObject]) ) {
		[tempArray addObject:[field objectForKey:@"name"]];
	}

	return [NSArray arrayWithArray:tempArray];
}

/*
returns a dictionary containing enum/set field names as key and possible values as array
*/
- (NSDictionary *)enumFields
{
	return [NSDictionary dictionaryWithDictionary:enumFields];
}

/**
 * Returns a dictionary describing the source of the table to be used for printing purposes. The object accessible
 * via the key 'structure' is an array of the tables fields, where the first element is always the field names
 * and each subsequent element is the field data. This is also true for the table's indexes, which are accessible
 * via the key 'indexes'.
 */
- (NSDictionary *)tableSourceForPrinting
{
	NSInteger i, j;
	NSMutableArray *tempResult  = [NSMutableArray array];
	NSMutableArray *tempResult2 = [NSMutableArray array];

	NSString *nullValue = [prefs stringForKey:SPNullValue];
	CFStringRef escapedNullValue = CFXMLCreateStringByEscapingEntities(NULL, ((CFStringRef)nullValue), NULL);

	MCPResult *structureQueryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW COLUMNS FROM %@", [selectedTable backtickQuotedString]]];
	MCPResult *indexesQueryResult   = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW INDEXES FROM %@", [selectedTable backtickQuotedString]]];

	[structureQueryResult setReturnDataAsStrings:YES];
	[indexesQueryResult setReturnDataAsStrings:YES];

	if ([structureQueryResult numOfRows]) [structureQueryResult dataSeek:0];
	if ([indexesQueryResult numOfRows]) [indexesQueryResult dataSeek:0];

	[tempResult addObject:[structureQueryResult fetchFieldNames]];

	NSMutableArray *temp = [[indexesQueryResult fetchFieldNames] mutableCopy];

	// Remove the 'table' column
	[temp removeObjectAtIndex:0];

	[tempResult2 addObject:temp];

	[temp release];

	for (i = 0; i < [structureQueryResult numOfRows]; i++) {
		NSMutableArray *row = [[structureQueryResult fetchRowAsArray] mutableCopy];

		// For every NULL value replace it with the user's NULL value placeholder so we can actually print it
		for (j = 0; j < [row count]; j++)
		{
			if ([[row objectAtIndex:j] isNSNull]) {
				[row replaceObjectAtIndex:j withObject:(NSString *)escapedNullValue];
			}
		}

		[tempResult addObject:row];

		[row release];
	}

	for (i = 0; i < [indexesQueryResult numOfRows]; i++) {
		NSMutableArray *index = [[indexesQueryResult fetchRowAsArray] mutableCopy];

		// Remove the 'table' column values
		[index removeObjectAtIndex:0];

		// For every NULL value replace it with the user's NULL value placeholder so we can actually print it
		for (j = 0; j < [index count]; j++)
		{
			if ([[index objectAtIndex:j] isNSNull]) {
				[index replaceObjectAtIndex:j withObject:(NSString *)escapedNullValue];
			}
		}

		[tempResult2 addObject:index];

		[index release];
	}

	CFRelease(escapedNullValue);
	return [NSDictionary dictionaryWithObjectsAndKeys:tempResult, @"structure", tempResult2, @"indexes", nil];
}

#pragma mark -
#pragma mark Task interaction

/**
 * Disable all content interactive elements during an ongoing task.
 */
- (void)startDocumentTaskForTab:(NSNotification *)aNotification
{
	// Only proceed if this view is selected.
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableStructure]) return;

	[tableSourceView setEnabled:NO];
	[addFieldButton setEnabled:NO];
	[removeFieldButton setEnabled:NO];
	[copyFieldButton setEnabled:NO];
	[reloadFieldsButton setEnabled:NO];
	[editTableButton setEnabled:NO];

	[indexesTableView setEnabled:NO];
	[addIndexButton setEnabled:NO];
	[removeIndexButton setEnabled:NO];
	[refreshIndexesButton setEnabled:NO];
}

/**
 * Enable all content interactive elements after an ongoing task.
 */
- (void)endDocumentTaskForTab:(NSNotification *)aNotification
{
	// Only re-enable elements if the current tab is the structure view
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableStructure]) return;

	BOOL editingEnabled = ([tablesListInstance tableType] == SPTableTypeTable);

	[tableSourceView setEnabled:YES];
	[tableSourceView displayIfNeeded];
	[addFieldButton setEnabled:editingEnabled];

	if (editingEnabled && [tableSourceView numberOfSelectedRows] > 0) {
		[removeFieldButton setEnabled:YES];
		[copyFieldButton setEnabled:YES];
	}

	[reloadFieldsButton setEnabled:YES];
	[editTableButton setEnabled:YES];

	[indexesTableView setEnabled:YES];
	[indexesTableView displayIfNeeded];

	[addIndexButton setEnabled:editingEnabled];
	[removeIndexButton setEnabled:(editingEnabled && ([indexesTableView numberOfSelectedRows] > 0))];
	[refreshIndexesButton setEnabled:YES];
}

#pragma mark -
#pragma mark TableView datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [tableFields count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	// Return a placeholder if the table is reloading
	if (rowIndex >= [tableFields count]) return @"...";

	if([[tableColumn identifier] isEqualToString:@"collation"]) {
		if([[[tableFields objectAtIndex:rowIndex] objectForKey:@"encoding"] integerValue] > 0) {
			NSString *enc = [[encodingPopupCell itemAtIndex:[[[tableFields objectAtIndex:rowIndex] objectForKey:@"encoding"] integerValue]] title];
			NSInteger start = [enc rangeOfString:@"("].location+1;
			NSInteger end = [enc length] - start - 1;
			collations = [databaseDataInstance getDatabaseCollationsForEncoding:[enc substringWithRange:NSMakeRange(start, end)]];
		} else {
			if([tableDataInstance tableEncoding]) {
				collations = [databaseDataInstance getDatabaseCollationsForEncoding:[tableDataInstance tableEncoding]];
			} else {
				collations = [NSArray array];
			}
		}

		[[tableColumn dataCell] removeAllItems];

		if ([collations count] > 0) {
			[[tableColumn dataCell] addItemWithTitle:@""];
			// Populate collation popup button
			for (NSDictionary *collation in collations)
				[[tableColumn dataCell] addItemWithTitle:[collation objectForKey:@"COLLATION_NAME"]];
		}
	}

	return [[tableFields objectAtIndex:rowIndex] objectForKey:[tableColumn identifier]];
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	// Make sure that the drag operation is for the right table view
	if (aTableView != tableSourceView) return;

	if (!isEditingRow) {
		[oldRow setDictionary:[tableFields objectAtIndex:rowIndex]];
		isEditingRow = YES;
		currentlyEditingRow = rowIndex;
	}

	// Reset collation if encoding was changed
	if([[aTableColumn identifier] isEqualToString:@"encoding"]) {
		if([[[tableFields objectAtIndex:rowIndex] objectForKey:@"encoding"] integerValue] != [anObject integerValue]) {
			[[tableFields objectAtIndex:rowIndex] setObject:[NSNumber numberWithInteger:0] forKey:@"collation"];
			[tableSourceView reloadData];
		}
	}

	if([[aTableColumn identifier] isEqualToString:@"type"]) {
		if(anObject && [(NSString*)anObject length] && ![(NSString*)anObject hasPrefix:@"--"])
			[[tableFields objectAtIndex:rowIndex] setObject:[(NSString*)anObject uppercaseString] forKey:@"type"];
	}
	else
		[[tableFields objectAtIndex:rowIndex] setObject:(anObject) ? anObject : @"" forKey:[aTableColumn identifier]];

}

/**
 * Confirm whether to allow editing of a row. Returns YES by default, but NO for views.
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if ([tableDocumentInstance isWorking]) return NO;

	// Return NO for views
	if ([tablesListInstance tableType] == SPTableTypeView) return NO;

	return YES;
}

/*
Begin a drag and drop operation from the table - copy a single dragged row to the drag pasteboard.
*/
- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rows toPasteboard:(NSPasteboard*)pboard
{
	// Make sure that the drag operation is started from the right table view
	if (aTableView != tableSourceView) return NO;

	// Check whether a save of the current field row is required.
	if ( ![self saveRowOnDeselect] ) return NO;

	if ([rows count] == 1) {
		[pboard declareTypes:[NSArray arrayWithObject:@"SequelProPasteboard"] owner:nil];
		[pboard setString:[[NSNumber numberWithInteger:[rows firstIndex]] stringValue] forType:@"SequelProPasteboard"];
		return YES;
	} else {
		return NO;
	}
}

/*
Determine whether to allow a drag and drop operation on this table - for the purposes of drag reordering,
validate that the original source is of the correct type and within the same table, and that the drag
would result in a position change.
*/
- (NSDragOperation)tableView:(NSTableView*)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row
	proposedDropOperation:(NSTableViewDropOperation)operation
{
    //make sure that the drag operation is for the right table view
    if (tableView!=tableSourceView) return NO;

	NSArray *pboardTypes = [[info draggingPasteboard] types];
	NSInteger originalRow;

	// Ensure the drop is of the correct type
	if (operation == NSTableViewDropAbove && row != -1 && [pboardTypes containsObject:@"SequelProPasteboard"]) {

		// Ensure the drag originated within this table
		if ([info draggingSource] == tableView) {
			originalRow = [[[info draggingPasteboard] stringForType:@"SequelProPasteboard"] integerValue];

			if (row != originalRow && row != (originalRow+1)) {
				return NSDragOperationMove;
			}
		}
	}

	return NSDragOperationNone;
}

/*
 * Having validated a drop, perform the field/column reordering to match.
 */
- (BOOL)tableView:(NSTableView*)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)destinationRowIndex dropOperation:(NSTableViewDropOperation)operation
{
    //make sure that the drag operation is for the right table view
    if (tableView!=tableSourceView) return NO;

	NSInteger originalRowIndex;
	NSMutableString *queryString;
	NSDictionary *originalRow;

	// Extract the original row position from the pasteboard and retrieve the details
	originalRowIndex = [[[info draggingPasteboard] stringForType:@"SequelProPasteboard"] integerValue];
	originalRow = [[NSDictionary alloc] initWithDictionary:[tableFields objectAtIndex:originalRowIndex]];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:tableDocumentInstance];

	// Begin construction of the reordering query
	queryString = [NSMutableString stringWithFormat:@"ALTER TABLE %@ MODIFY COLUMN %@ %@", [selectedTable backtickQuotedString],
		[[originalRow objectForKey:@"name"] backtickQuotedString],
		[[originalRow objectForKey:@"type"] uppercaseString]];

	// Add the length parameter if necessary
	if ( [originalRow objectForKey:@"length"] && ![[originalRow objectForKey:@"length"] isEqualToString:@""]) {
		[queryString appendFormat:@"(%@)", [originalRow objectForKey:@"length"]];
	}

	NSString *fieldEncoding = @"";
	if([[originalRow objectForKey:@"encoding"] integerValue] > 0) {
		NSString *enc = [[encodingPopupCell itemAtIndex:[[originalRow objectForKey:@"encoding"] integerValue]] title];
		NSInteger start = [enc rangeOfString:@"("].location+1;
		NSInteger end = [enc length] - start - 1;
		fieldEncoding = [enc substringWithRange:NSMakeRange(start, end)];
		[queryString appendFormat:@" CHARACTER SET %@", fieldEncoding];
	}
	if(![fieldEncoding length] && [tableDataInstance tableEncoding]) {
		fieldEncoding = [tableDataInstance tableEncoding];
	}
	if([fieldEncoding length] && [[originalRow objectForKey:@"collation"] integerValue] > 0) {
		NSArray *theCollations = [databaseDataInstance getDatabaseCollationsForEncoding:fieldEncoding];
		NSString *col = [[theCollations objectAtIndex:[[originalRow objectForKey:@"collation"] integerValue]-1] objectForKey:@"COLLATION_NAME"];
		[queryString appendFormat:@" COLLATE %@", col];
	}


	// Add unsigned, zerofill, binary, not null if necessary
	if ([[originalRow objectForKey:@"unsigned"] integerValue]) {
		[queryString appendString:@" UNSIGNED"];
	}
	if ([[originalRow objectForKey:@"zerofill"] integerValue]) {
		[queryString appendString:@" ZEROFILL"];
	}
	if ([[originalRow objectForKey:@"binary"] integerValue]) {
		[queryString appendString:@" BINARY"];
	}
	if (![[originalRow objectForKey:@"null"] integerValue]) {
		[queryString appendString:@" NOT NULL"];
	}
	if (![[originalRow objectForKey:@"Extra"] isEqualToString:@"None"] ) {
		[queryString appendString:@" "];
		[queryString appendString:[[originalRow objectForKey:@"Extra"] uppercaseString]];
	}

	BOOL isTimestampType = [[[originalRow objectForKey:@"type"] lowercaseString] isEqualToString:@"timestamp"];

	// Add the default value, skip it for auto_increment
	if([originalRow objectForKey:@"Extra"] && ![[originalRow objectForKey:@"Extra"] isEqualToString:@"auto_increment"]) {
		if ([[originalRow objectForKey:@"default"] isEqualToString:[prefs objectForKey:SPNullValue]]) {
			if ([[originalRow objectForKey:@"null"] integerValue] == 1) {
				[queryString appendString:(isTimestampType) ? @" NULL DEFAULT NULL" : @" DEFAULT NULL"];
			}
		}
		else if (isTimestampType && ([[[originalRow objectForKey:@"default"] uppercaseString] isEqualToString:@"CURRENT_TIMESTAMP"]) ) {
				[queryString appendString:@" DEFAULT CURRENT_TIMESTAMP"];
		}
		else {
			[queryString appendFormat:@" DEFAULT '%@'", [mySQLConnection prepareString:[originalRow objectForKey:@"default"]]];
		}
	}

	// Any column comments
	if ([[originalRow objectForKey:@"comment"] length]) {
		[queryString appendFormat:@" COMMENT '%@'", [mySQLConnection prepareString:[originalRow objectForKey:@"comment"]]];
	}

	// Unparsed details - column formats, storage, reference definitions
	if ([originalRow objectForKey:@"unparsed"]) {
		[queryString appendString:[originalRow objectForKey:@"unparsed"]];
	}

	// Add the new location
	if ( destinationRowIndex == 0 ){
		[queryString appendString:@" FIRST"];
	} else {
		[queryString appendFormat:@" AFTER %@",
						[[[tableFields objectAtIndex:destinationRowIndex-1] objectForKey:@"name"] backtickQuotedString]];
	}

	// Run the query; report any errors, or reload the table on success
	[mySQLConnection queryString:queryString];

	if ([mySQLConnection queryErrored]) {
		SPBeginAlertSheet(NSLocalizedString(@"Error moving field", @"error moving field message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [tableDocumentInstance parentWindow], self, nil, nil,
			[NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to move the field.\n\nMySQL said: %@", @"error moving field informative message"), [mySQLConnection getLastErrorMessage]]);
	} else {
		[tableDataInstance resetAllData];
		[tablesListInstance setStatusRequiresReload:YES];
		[self loadTable:selectedTable];

		// Mark the content table cache for refresh
		[tablesListInstance setContentRequiresReload:YES];

		if ( originalRowIndex < destinationRowIndex ) {
			[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:destinationRowIndex-1] byExtendingSelection:NO];
		} else {
			[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:destinationRowIndex] byExtendingSelection:NO];
		}
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];

	[originalRow release];
	return YES;
}

#pragma mark -
#pragma mark TableView delegate methods

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
	// If we are editing a row, attempt to save that row - if saving failed, do not select the new row.
	if (isEditingRow && ![self addRowToDB]) return NO;
	return YES;
}

/**
 * Performs various interface validation
 */
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	id object = [aNotification object];

	// Check for which table view the selection changed
	if (object == tableSourceView) {

		// If we are editing a row, attempt to save that row - if saving failed, reselect the edit row.
		if (isEditingRow && [tableSourceView selectedRow] != currentlyEditingRow && ![self saveRowOnDeselect]) return;

		[copyFieldButton setEnabled:YES];

		// Check if there is currently a field selected and change button state accordingly
		if ([tableSourceView numberOfSelectedRows] > 0 && [tablesListInstance tableType] == SPTableTypeTable) {
			[removeFieldButton setEnabled:YES];
		} else {
			[removeFieldButton setEnabled:NO];
			[copyFieldButton setEnabled:NO];
		}

		// If the table only has one field, disable the remove button. This removes the need to check that the user
		// is attempting to remove the last field in a table in removeField: above, but leave it in just in case.
		if ([tableSourceView numberOfRows] == 1) {
			[removeFieldButton setEnabled:NO];
		}
	}
}

/**
 * Traps enter and esc and make/cancel editing without entering next row
 */
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	NSInteger row, column;

	row = [tableSourceView editedRow];
	column = [tableSourceView editedColumn];

	// Trap the tab key, selecting the next item in the line
	if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(insertTab:)] && [tableSourceView numberOfColumns] - 1 == column)
	{
		//save current line
		[[control window] makeFirstResponder:control];

		if ( [self addRowToDB] && [textView methodForSelector:command] == [textView methodForSelector:@selector(insertTab:)] ) {
			if ( row < ([tableSourceView numberOfRows] - 1) ) {
				[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:row+1] byExtendingSelection:NO];
				[tableSourceView editColumn:0 row:row+1 withEvent:nil select:YES];
			} else {
				[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
				[tableSourceView editColumn:0 row:0 withEvent:nil select:YES];
			}
		}
		return YES;

	}

	// Trap shift-tab key
	else if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(insertBacktab:)] && column < 1)
	{
		if ( [self addRowToDB] && [textView methodForSelector:command] == [textView methodForSelector:@selector(insertBacktab:)] ) {
			[[control window] makeFirstResponder:control];
			if ( row > 0) {
				[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:row-1] byExtendingSelection:NO];
				[tableSourceView editColumn:([tableFields count]-1) row:row-1 withEvent:nil select:YES];
			} else {
				[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:([tableFields count]-1)] byExtendingSelection:NO];
				[tableSourceView editColumn:([tableFields count]-1) row:([tableSourceView numberOfRows]-1) withEvent:nil select:YES];
			}
		}
		return YES;
	}

	// Trap the enter key, triggering a save
	else if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(insertNewline:)] )
	{
		// Suppress enter for non-text fields to allow selecting of chosen items from comboboxes or popups
		if(![[[[[[tableSourceView tableColumns] objectAtIndex:column] dataCell] class] description] isEqualToString:@"NSTextFieldCell"])
			return YES;

		[[control window] makeFirstResponder:control];
		[self addRowToDB];
		[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		[tableSourceView makeFirstResponder];
		return YES;
	
	}

	// Trap escape, aborting the edit and reverting the row
	else if (  [[control window] methodForSelector:command] == [[control window] methodForSelector:@selector(cancelOperation:)] )
	{
		[control abortEditing];
		if ( isEditingRow && !isEditingNewRow ) {
			isEditingRow = NO;
			[tableFields replaceObjectAtIndex:row withObject:[NSMutableDictionary dictionaryWithDictionary:oldRow]];
		} else if ( isEditingNewRow ) {
			isEditingRow = NO;
			isEditingNewRow = NO;
			[tableFields removeObjectAtIndex:row];
			[tableSourceView reloadData];
		}
		currentlyEditingRow = -1;
		[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		[tableSourceView makeFirstResponder];
		return YES;
	 } else {
		 return NO;
	 }
}


/*
 * Modify cell display by disabling table cells when a view is selected, meaning structure/index
 * is uneditable.
 */
- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{

	//make sure that the message is from the right table view
	if (tableView != tableSourceView) return;

	[aCell setEnabled:([tablesListInstance tableType] == SPTableTypeTable)];
}

#pragma mark -
#pragma mark SplitView delegate methods

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	return YES;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
	return proposedMax - 130;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
	return proposedMin + 130;
}

- (NSRect)splitView:(NSSplitView *)splitView additionalEffectiveRectOfDividerAtIndex:(NSInteger)dividerIndex
{
	return [structureGrabber convertRect:[structureGrabber bounds] toView:splitView];
}

- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
	if ([aNotification object] == tablesIndexesSplitView) {
		NSView *indexesView = [[tablesIndexesSplitView subviews] objectAtIndex:1];
		if ([tablesIndexesSplitView isSubviewCollapsed:indexesView]) {
			[indexesShowButton setHidden:NO];
		} else {
			[indexesShowButton setHidden:YES];
		}
	}
}

- (IBAction)unhideIndexesView:(id)sender
{
	[tablesIndexesSplitView setPosition:[tablesIndexesSplitView frame].size.height-130 ofDividerAtIndex:0];
}

#pragma mark -
#pragma mark NSComboBox delegates

- (id)comboBoxCell:(NSComboBoxCell *)aComboBoxCell objectValueForItemAtIndex:(NSInteger)index
{
	return [typeSuggestions objectAtIndex:index];
}

- (NSInteger)numberOfItemsInComboBoxCell:(NSComboBoxCell *)aComboBoxCell
{
	return [typeSuggestions count];
}

/**
 * Allow completion for lowercased input
 */
- (NSString *)comboBoxCell:(NSComboBoxCell *)aComboBoxCell completedString:(NSString *)uncompletedString
{

	if([uncompletedString hasPrefix:@"-"]) return @"";

	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH[c] %@", [uncompletedString uppercaseString]];
	NSArray *result = [typeSuggestions filteredArrayUsingPredicate:predicate];

	if(result && [result count])
		return [result objectAtIndex:0];

	return @"";

}

#pragma mark -
#pragma mark Private API methods

/**
 * Return if aType is numeric according to typeSuggestions's position
 * Hint: This must be changed if typeSuggestions was changed!
 */
- (BOOL)_isFieldTypeNumeric:(NSString*)aType
{
	NSString *type = [[aType stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];

	if(![typeSuggestions containsObject:type]) return YES; // for safety reasons

	return ([typeSuggestions indexOfObject:type] < 17);
}

/**
 * Return if aType is a date or time according to typeSuggestions's position
 * Hint: This must be changed if typeSuggestions was changed!
 */
- (BOOL)_isFieldTypeDate:(NSString*)aType
{
	NSString *type = [[aType stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];

	if(![typeSuggestions containsObject:type]) return YES; // for safety reasons

	return ([typeSuggestions indexOfObject:type] > 31);
}

/**
 * Return if aType is a string type
 */
- (BOOL)_isFieldTypeString:(NSString*)aType
{
	NSString *type = [[aType stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];

	if(![typeSuggestions containsObject:type]) return YES; // for safety reasons

	return (![self _isFieldTypeDate:type] && ![self _isFieldTypeNumeric:type]);
}

/**
 * Removes a field from the current table and the dependent foreign key if specified.
 */
- (void)_removeFieldAndForeignKey:(NSNumber *)removeForeignKey
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	// Remove the foreign key before the field if required
	if ([removeForeignKey boolValue]) {

		NSString *relationName = @"";
		NSString *field = [[tableFields objectAtIndex:[tableSourceView selectedRow]] objectForKey:@"name"];

		// Get the foreign key name
		for (NSDictionary *constraint in [tableDataInstance getConstraints])
		{
			for (NSString *column in [constraint objectForKey:@"columns"])
			{
				if ([column isEqualToString:field]) {
					relationName = [constraint objectForKey:@"name"];
					break;
				}
			}
		}

		[mySQLConnection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ DROP FOREIGN KEY %@", [selectedTable backtickQuotedString], [relationName backtickQuotedString]]];

		// Check for errors, but only if the query wasn't cancelled
		if ([mySQLConnection queryErrored] && ![mySQLConnection queryCancelled]) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			[errorDictionary setObject:NSLocalizedString(@"Unable to delete relation", @"error deleting relation message") forKey:@"title"];
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to delete the relation '%@'.\n\nMySQL said: %@", @"error deleting relation informative message"), relationName, [mySQLConnection getLastErrorMessage]] forKey:@"message"];
			[[self onMainThread] showErrorSheetWith:errorDictionary];
		}
	}

	// Remove field
	[mySQLConnection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ DROP %@",
								  [selectedTable backtickQuotedString], [[[tableFields objectAtIndex:[tableSourceView selectedRow]] objectForKey:@"name"] backtickQuotedString]]];

	// Check for errors, but only if the query wasn't cancelled
	if ([mySQLConnection queryErrored] && ![mySQLConnection queryCancelled]) {
		NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
		[errorDictionary setObject:NSLocalizedString(@"Error", @"error") forKey:@"title"];
		[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedString(@"Couldn't delete field %@.\nMySQL said: %@", @"message of panel when field cannot be deleted"),
									[[tableFields objectAtIndex:[tableSourceView selectedRow]] objectForKey:@"name"],
									[mySQLConnection getLastErrorMessage]] forKey:@"message"];
		[[self onMainThread] showErrorSheetWith:errorDictionary];
	}
	else {
		[tableDataInstance resetAllData];
		[tablesListInstance setStatusRequiresReload:YES];
		[self loadTable:selectedTable];

		// Mark the content table cache for refresh
		[tablesListInstance setContentRequiresReload:YES];
	}

	[tableDocumentInstance endTask];

	// Preserve focus on table for keyboard navigation
	[tableSourceView makeFirstResponder];

	[pool drain];
}

#pragma mark -

/**
 * Dealloc.
 */
- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[tableFields release];
	[oldRow release];
	[enumFields release];
	[typeSuggestions release];

	if (defaultValues) [defaultValues release];
	if (selectedTable) [selectedTable release];

	[super dealloc];
}

@end
