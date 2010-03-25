//
//  $Id$
//
//  TableSource.m
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

#import "TableSource.h"
#import "TableDocument.h"
#import "SPTableInfo.h"
#import "TablesList.h"
#import "SPTableData.h"
#import "SPSQLParser.h"
#import "SPStringAdditions.h"
#import "SPArrayAdditions.h"
#import "SPConstants.h"
#import "SPAlertSheets.h"
#import "SPMainThreadTrampoline.h"

@interface TableSource (PrivateAPI)

- (void)_addIndex;
- (void)_removeFieldAndForeignKey:(NSNumber *)removeForeignKey;
- (void)_removeIndexAndForeignKey:(NSNumber *)removeForeignKey;

@end

@implementation TableSource

/**
 * Loads aTable, put it in an array, update the tableViewColumns and reload the tableView
 */
- (void)loadTable:(NSString *)aTable
{
	NSArray *theTableFields, *theTableIndexes;
	NSMutableDictionary *theTableEnumLists = [NSMutableDictionary dictionary];
	NSArray *extrasArray;
	NSMutableDictionary *tempDefaultValues;
	NSInteger i;
	SPSQLParser *fieldParser;

	// Check whether a save of the current row is required.
	if ( ![[self onMainThread] saveRowOnDeselect] ) return;

	// If no table is selected, reset the interface and return
	if (!aTable || ![aTable length]) {
		[[self onMainThread] setTableDetails:nil];
		return;
	}
	
	// Send the query started/working notification
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:tableDocumentInstance];
  
	// Retrieve the column information for this table.
	// TODO: update this and indexes to use TableData at some point - tiny bit more parsing required...
	tableSourceResult = [[mySQLConnection queryString:[NSString stringWithFormat:@"SHOW COLUMNS FROM %@", [aTable backtickQuotedString]]] retain];

	// If an error occurred, reset the interface and abort
	if ([mySQLConnection queryErrored]) {
		NSString *errorMessage = [NSString stringWithString:[mySQLConnection getLastErrorMessage]];

		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];
		[[self onMainThread] setTableDetails:nil];

		SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), 
				nil, nil, [NSApp mainWindow], self, nil, nil, nil,
				[NSString stringWithFormat:NSLocalizedString(@"An error occurred while retrieving information.\nMySQL said: %@", @"message of panel when retrieving information failed"),
				   errorMessage]);
		if (tableSourceResult) [tableSourceResult release];
		return;
	}

	// Process the field names into a local array of dictionaries 
	theTableFields = [self fetchResultAsArray:tableSourceResult];
	[tableSourceResult release];

	// Retrieve the indexes for the table
	indexResult = [[mySQLConnection queryString:[NSString stringWithFormat:@"SHOW INDEX FROM %@", [aTable backtickQuotedString]]] retain];

	// If an error occurred, reset the interface and abort
	if ([mySQLConnection queryErrored]) {
		NSString *errorMessage = [NSString stringWithString:[mySQLConnection getLastErrorMessage]];

		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];
		[[self onMainThread] setTableDetails:nil];

		SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), 
				nil, nil, [NSApp mainWindow], self, nil, nil, nil,
				[NSString stringWithFormat:NSLocalizedString(@"An error occurred while retrieving information.\nMySQL said: %@", @"message of panel when retrieving information failed"),
				   errorMessage]);
		if (indexResult) [indexResult release];
		return;
	}

	// Process the indexes into a local array of dictionaries
	theTableIndexes = [self fetchResultAsArray:indexResult];
	[indexResult release];

	// Process all the fields to normalise keys and add additional information
	for (id theField in theTableFields) {
		NSString *type;
		NSString *length;
		NSString *extras;

		// Set up the field parser with the type definition
		fieldParser = [[SPSQLParser alloc] initWithString:[theField objectForKey:@"Type"]];

		// Pull out the field type; if no brackets are found, this returns nil - in which case simple values can be used.
		type = [fieldParser trimAndReturnStringToCharacter:'(' trimmingInclusively:YES returningInclusively:NO];
		if (!type) {
			type = [NSString stringWithString:fieldParser];
			length = @"";
			extras = @"";
		} else {

			// Pull out the length, which may include enum/set values
			length = [fieldParser trimAndReturnStringToCharacter:')' trimmingInclusively:YES returningInclusively:NO];
			if (!length) length = @"";

			// Separate any remaining extras
			extras = [NSString stringWithString:fieldParser];
			if (!extras) extras = @"";
		}

		[fieldParser release];

		// Get possible values if the field is an enum or a set
		if ([type isEqualToString:@"enum"] || [type isEqualToString:@"set"]) {
			SPSQLParser *valueParser = [[SPSQLParser alloc] initWithString:length];
			NSMutableArray *possibleValues = [[NSMutableArray alloc] initWithArray:[valueParser splitStringByCharacter:',']];
			for (i = 0; i < [possibleValues count]; i++) {
				[valueParser setString:[possibleValues objectAtIndex:i]];
				[possibleValues replaceObjectAtIndex:i withObject:[valueParser unquotedString]];
			}
			[theTableEnumLists setObject:[NSArray arrayWithArray:possibleValues] forKey:[theField objectForKey:@"Field"]];
			[possibleValues release];
			[valueParser release];
		}
		
		// For timestamps check to see whether "on update CURRENT_TIMESTAMP" - not returned
		// by SHOW COLUMNS - should be set from the table data store
		if ([type isEqualToString:@"timestamp"]
			&& [[[tableDataInstance columnWithName:[theField objectForKey:@"Field"]] objectForKey:@"onupdatetimestamp"] integerValue])
		{
			[theField setObject:@"on update CURRENT_TIMESTAMP" forKey:@"Extra"];
		}

		// Scan extras for values like unsigned, zerofill, binary
		extrasArray = [extras componentsSeparatedByString:@" "];
		for (id extra in extrasArray) {
			if ([extra isEqualToString:@"unsigned"]) {
				[theField setObject:@"1" forKey:@"unsigned"];
			} else if ([extra isEqualToString:@"zerofill"]) {
				[theField setObject:@"1" forKey:@"zerofill"];
			} else if ([extra isEqualToString:@"binary"]) {
				[theField setObject:@"1" forKey:@"binary"];
			} else {
				if (![extra isEqualToString:@""])
					NSLog(@"ERROR: unknown option in field definition: %@", extra);
			}
		}

		[theField setObject:type forKey:@"Type"];
		[theField setObject:length forKey:@"Length"];
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
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];
}

/**
 * Reloads the table (performing a new mysql-query)
 */
- (IBAction)reloadTable:(id)sender
{
	[tableDataInstance resetAllData];
	[tablesListInstance setStatusRequiresReload:YES];
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

	// Reset the table store and display
	[enumFields removeAllObjects];
	[tableSourceView deselectAll:self];
	[indexView deselectAll:self];
	[tableFields removeAllObjects];
	[indexes removeAllObjects];
	[addFieldButton setEnabled:NO];
	[copyFieldButton setEnabled:NO];
	[removeFieldButton setEnabled:NO];
	[addIndexButton setEnabled:NO];
	[removeIndexButton setEnabled:NO];
	[editTableButton setEnabled:NO];

	// If no table is selected, refresh the table display to blank and return
	if (!selectedTable) {
		[tableSourceView reloadData];
		[indexView reloadData];
		return;
	}

	// Update the fields and indexes stores
	[tableFields setArray:[tableDetails objectForKey:@"tableFields"]];
	[indexes setArray:[tableDetails objectForKey:@"tableIndexes"]];

	// Update the default values array and the indexed column fields control
	[indexedColumnsField removeAllItems];
	if (defaultValues) [defaultValues release], defaultValues = nil;
	newDefaultValues = [NSMutableDictionary dictionaryWithCapacity:[tableFields count]];
	for (id theField in tableFields) {
		[newDefaultValues setObject:[theField objectForKey:@"Default"] forKey:[theField objectForKey:@"Field"]];
		[indexedColumnsField addItemWithObjectValue:[theField objectForKey:@"Field"]];
	}
	defaultValues = [[NSDictionary dictionaryWithDictionary:newDefaultValues] retain];

	// Only show up to ten items in the indexed column fields control
	if ([tableFields count] < 10) {
		[indexedColumnsField setNumberOfVisibleItems:[tableFields count]];
	} else {
		[indexedColumnsField setNumberOfVisibleItems:10];
	}

	// Enable the edit table button
	[editTableButton setEnabled:enableInteraction];

	// If a view is selected, disable the buttons; otherwise enable.
	BOOL editingEnabled = ([tablesListInstance tableType] == SPTableTypeTable) && enableInteraction;
	[addFieldButton setEnabled:editingEnabled];
	[addIndexButton setEnabled:editingEnabled];

	// Reload the views
	[indexView reloadData];
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
							   dictionaryWithObjects:[NSArray arrayWithObjects:@"", @"int", @"", @"0", @"0", @"0", ([prefs boolForKey:SPNewFieldsAllowNulls]) ? @"1" : @"0", @"", [prefs stringForKey:SPNullValue], @"None", nil]
							   forKeys:[NSArray arrayWithObjects:@"Field", @"Type", @"Length", @"unsigned", @"zerofill", @"binary", @"Null", @"Key", @"Default", @"Extra", nil]]
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
	[tempRow setObject:[[tempRow objectForKey:@"Field"] stringByAppendingString:@"Copy"] forKey:@"Field"];
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

	// Check if the user tries to delete the last defined field in table
	// Note that because of better menu item validation, this check will now never evaluate to true.
	if ([tableSourceView numberOfRows] < 2) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error while deleting field", @"Error while deleting field")
										 defaultButton:NSLocalizedString(@"OK", @"OK button") 
									   alternateButton:nil 
										   otherButton:nil 
							 informativeTextWithFormat:NSLocalizedString(@"You cannot delete the last field in a table. Use 'Remove table' (DROP TABLE) instead.", @"You cannot delete the last field in that table. Use 'Remove table' (DROP TABLE) instead")];

		[alert setAlertStyle:NSCriticalAlertStyle];

		[alert beginSheetModalForWindow:tableWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"cannotremovefield"];
		
	}
	
	NSString *field = [[tableFields objectAtIndex:[tableSourceView selectedRow]] objectForKey:@"Field"];
	
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
						 informativeTextWithFormat:(hasForeignKey) ? [NSString stringWithFormat:NSLocalizedString(@"This field is part of a foreign key relationship with the table '%@'. This relationship must be removed before the field can be deleted.\n\nAre you sure you want to continue to remove the relationship and the field? This action cannot be undone.", @"delete field and foreign key informative message"), referencedTable] : [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the field '%@'? This action cannot be undone.", @"delete field informative message"), field]];
	
	[alert setAlertStyle:NSCriticalAlertStyle];
	
	NSArray *buttons = [alert buttons];
	
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"d"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
	
	[alert beginSheetModalForWindow:tableWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:(hasForeignKey) ? @"removeFieldAndForeignKey" : @"removeField"];
}

/**
 * Ask the user to confirm that they really want to remove the selected index.
 */
- (IBAction)removeIndex:(id)sender
{
	if (![indexView numberOfSelectedRows]) return;

	// Check whether a save of the current fields row is required.
	if (![self saveRowOnDeselect]) return;
	
	NSString *keyName    =  [[indexes objectAtIndex:[indexView selectedRow]] objectForKey:@"Key_name"];
	NSString *columnName =  [[indexes objectAtIndex:[indexView selectedRow]] objectForKey:@"Column_name"];
		
	BOOL hasForeignKey = NO;
	NSString *constraintName = @"";
	
	// Check to see whether the user is attempting to remove an index that a foreign key constraint depends on
	// thus would result in an error if not dropped before removing the index.
	for (NSDictionary *constraint in [tableDataInstance getConstraints])
	{
		for (NSString *column in [constraint objectForKey:@"columns"])
		{
			if ([column isEqualToString:columnName]) {
				hasForeignKey = YES;
				constraintName = [constraint objectForKey:@"name"];
				break;
			}
		}
	}
	
	NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Delete index '%@'?", @"delete index message"), keyName]
									 defaultButton:NSLocalizedString(@"Delete", @"delete button")
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
									   otherButton:nil 
						 informativeTextWithFormat:(hasForeignKey) ? [NSString stringWithFormat:NSLocalizedString(@"The foreign key relationship '%@' has a dependency on this index. This relationship must be removed before the index can be deleted.\n\nAre you sure you want to continue to remove the relationship and the index? This action cannot be undone.", @"delete index and foreign key informative message"), constraintName] : [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the index '%@'? This action cannot be undone.", @"delete index informative message"), keyName]];
	
	[alert setAlertStyle:NSCriticalAlertStyle];
	
	NSArray *buttons = [alert buttons];
	
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"d"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
	
	[alert beginSheetModalForWindow:tableWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:(hasForeignKey) ? @"removeIndexAndForeignKey" : @"removeIndex"];
}

- (IBAction)resetAutoIncrement:(id)sender
{

	if([sender tag] == 1) {
		
		[resetAutoIncrementLine setHidden:YES];
		if([[tableDocumentInstance valueForKeyPath:@"tableTabView"] indexOfTabViewItem:[[tableDocumentInstance valueForKeyPath:@"tableTabView"] selectedTabViewItem]] == 0)
			[resetAutoIncrementLine setHidden:NO];

		// Begin the sheet
		[NSApp beginSheet:resetAutoIncrementSheet
		   modalForWindow:tableWindow 
			modalDelegate:self
		   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
			  contextInfo:@"resetAutoIncrement"];

		[resetAutoIncrementValue setStringValue:@"1"];
	}
	else if([sender tag] == 2) {
		[self setAutoIncrementTo:@"1"];
	}

}

#pragma mark -
#pragma mark Index sheet methods

/**
 * Opens the add new index sheet.
 */
- (IBAction)openIndexSheet:(id)sender
{
	NSInteger i;

	// Check whether a save of the current field row is required.
	if (![self saveRowOnDeselect]) return;

	// Set sheet defaults - key type PRIMARY, key name PRIMARY and disabled, and blank indexed columns
	[indexTypeField selectItemAtIndex:0];
	[indexNameField setEnabled:NO];
	[indexNameField setStringValue:@"PRIMARY"];
	[indexedColumnsField setStringValue:@""];
	[indexSheet makeFirstResponder:indexedColumnsField];
	
	// Check to see whether a primary key already exists for the table, and if so select an INDEX instead
	for (i = 0; i < [tableFields count]; i++) 
	{
		if ([[[tableFields objectAtIndex:i] objectForKey:@"Key"] isEqualToString:@"PRI"]) {
			[indexTypeField selectItemAtIndex:1];
			[indexNameField setEnabled:YES];
			[indexNameField setStringValue:@""];
			[indexSheet makeFirstResponder:indexNameField];
			break;
		}
	}

	// Begin the sheet
	[NSApp beginSheet:indexSheet
	   modalForWindow:tableWindow 
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
		  contextInfo:@"addIndex"];
}

/**
 * Closes the current sheet and stops the modal session
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

/*
invoked when user chooses an index type
*/
- (IBAction)chooseIndexType:(id)sender
{
	if ( [[indexTypeField titleOfSelectedItem] isEqualToString:@"PRIMARY KEY"] ) {
		[indexNameField setEnabled:NO];
		[indexNameField setStringValue:@"PRIMARY"];
	} else {
		[indexNameField setEnabled:YES];
		if ( [[indexNameField stringValue] isEqualToString:@"PRIMARY"] )
			[indexNameField setStringValue:@""];
	}
}

/*
reopens indexSheet after errorSheet (no columns specified)
*/
- (void)closeAlertSheet
{
	[self openIndexSheet:self];
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
 * Sets the connection (received from TableDocument) and makes things that have to be done only once 
 */
- (void)setConnection:(MCPConnection *)theConnection
{
	mySQLConnection = theConnection;

	// Set up tableView
	[tableSourceView registerForDraggedTypes:[NSArray arrayWithObjects:@"SequelProPasteboard", nil]];
}

- (void)setAutoIncrementTo:(NSString*)valueAsString
{

	if(valueAsString == nil || ![valueAsString length]) return;

	NSString *selTable = nil;

	// if selectedTable is nil try to get the name from tablesList
	if(selectedTable == nil || ![selectedTable length])
		selTable = [tablesListInstance tableName];
	else
		selTable = [NSString stringWithString:selectedTable];

	if(selTable == nil || ![selTable length])
		return;

	[mySQLConnection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ AUTO_INCREMENT = %@", [selTable backtickQuotedString], valueAsString]];

	if ([mySQLConnection queryErrored]) {
		SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), 
						  NSLocalizedString(@"OK", @"OK button"),
						  nil, nil, [NSApp mainWindow], nil, nil, nil, nil, 
						  [NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to reset AUTO_INCREMENT of table '%@'.\n\nMySQL said: %@", @"error resetting auto_increment informative message"), 
								selTable, [mySQLConnection getLastErrorMessage]]);
	} else {
		[tableDataInstance resetStatusData];
		if([[tableDocumentInstance valueForKeyPath:@"tableTabView"] indexOfTabViewItem:[[tableDocumentInstance valueForKeyPath:@"tableTabView"] selectedTabViewItem]] == 3) {
			[tableDataInstance resetAllData];
			[extendedTableInfoInstance loadTable:selTable];
		}
		[tableInfoInstance tableChanged:nil];
	}
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
	[tableWindow endEditingFor:nil];

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
	NSInteger code;
	NSDictionary *theRow;
	NSMutableString *queryString;

	if (!isEditingRow || currentlyEditingRow == -1)
		return YES;
	
	if (alertSheetOpened)
		return NO;

	theRow = [tableFields objectAtIndex:currentlyEditingRow];
	
	if (isEditingNewRow) {
		// ADD syntax
		if ([[theRow objectForKey:@"Length"] isEqualToString:@""] || ![theRow objectForKey:@"Length"]) {
			
			queryString = [NSMutableString stringWithFormat:@"ALTER TABLE %@ ADD %@ %@",
															[selectedTable backtickQuotedString], 
															[[theRow objectForKey:@"Field"] backtickQuotedString], 
															[theRow objectForKey:@"Type"]];
		} 
		else {
			queryString = [NSMutableString stringWithFormat:@"ALTER TABLE %@ ADD %@ %@(%@)",
															[selectedTable backtickQuotedString], 
															[[theRow objectForKey:@"Field"] backtickQuotedString], 
															[theRow objectForKey:@"Type"],
															[theRow objectForKey:@"Length"]];
		}
	} 
	else {
		// CHANGE syntax
		if (([[theRow objectForKey:@"Length"] isEqualToString:@""]) || 
			(![theRow objectForKey:@"Length"]) || 
			([[theRow objectForKey:@"Type"] isEqualToString:@"datetime"])) 
		{
			// If the old row and new row dictionaries are equal then the user didn't actually change anything so don't continue 
			if ([oldRow isEqualToDictionary:theRow]) return YES;
			
			queryString = [NSMutableString stringWithFormat:@"ALTER TABLE %@ CHANGE %@ %@ %@",
															[selectedTable backtickQuotedString], 
															[[oldRow objectForKey:@"Field"] backtickQuotedString], 
															[[theRow objectForKey:@"Field"] backtickQuotedString],
															[theRow objectForKey:@"Type"]];
		} 
		else {
			// If the old row and new row dictionaries are equal then the user didn't actually change anything so don't continue 
			if ([oldRow isEqualToDictionary:theRow]) return YES;
			
			queryString = [NSMutableString stringWithFormat:@"ALTER TABLE %@ CHANGE %@ %@ %@(%@)",
															[selectedTable backtickQuotedString], 
															[[oldRow objectForKey:@"Field"] backtickQuotedString], 
															[[theRow objectForKey:@"Field"] backtickQuotedString],
															[theRow objectForKey:@"Type"], 
															[theRow objectForKey:@"Length"]];
		}
	}
	
	// Field specification
	if ([[theRow objectForKey:@"unsigned"] integerValue] == 1) {
		[queryString appendString:@" UNSIGNED"];
	}
	
	if ( [[theRow objectForKey:@"zerofill"] integerValue] == 1) {
		[queryString appendString:@" ZEROFILL"];
	}
	
	if ( [[theRow objectForKey:@"binary"] integerValue] == 1) {
		[queryString appendString:@" BINARY"];
	}

	if ([[theRow objectForKey:@"Null"] integerValue] == 0) {
		[queryString appendString:@" NOT NULL"];
	} else {
		[queryString appendString:@" NULL"];
	}
	
	// Don't provide any defaults for auto-increment fields
	if ([[theRow objectForKey:@"Extra"] isEqualToString:@"auto_increment"]) {
		[queryString appendString:@" "];
	} 
	else {
		// If a NULL value has been specified, and NULL is allowed, specify DEFAULT NULL
		if ([[theRow objectForKey:@"Default"] isEqualToString:[prefs objectForKey:SPNullValue]]) {
			if ([[theRow objectForKey:@"Null"] integerValue] == 1) {
				[queryString appendString:@" DEFAULT NULL "];
			}
		} 
		// Otherwise, if CURRENT_TIMESTAMP was specified for timestamps, use that
		else if ([[theRow objectForKey:@"Type"] isEqualToString:@"timestamp"] && 
				 [[[theRow objectForKey:@"Default"] uppercaseString] isEqualToString:@"CURRENT_TIMESTAMP"])
		{
			[queryString appendString:@" DEFAULT CURRENT_TIMESTAMP "];

		}
		// If the field is of type BIT, permit the use of single qoutes and also don't quote the default value.
		// For example, use DEFAULT b'1' as opposed to DEFAULT 'b\'1\'' which results in an error.
		else if ([[theRow objectForKey:@"Type"] isEqualToString:@"bit"]) {
			[queryString appendString:[NSString stringWithFormat:@" DEFAULT %@ ", [theRow objectForKey:@"Default"]]];
		}
		// Otherwise, use the provided default
		else {
			[queryString appendString:[NSString stringWithFormat:@" DEFAULT '%@' ", [mySQLConnection prepareString:[theRow objectForKey:@"Default"]]]];
		}
	}
	
	if (!(
			[[theRow objectForKey:@"Extra"] isEqualToString:@""] || 
			[[theRow objectForKey:@"Extra"] isEqualToString:@"None"]
		) && 
		[theRow objectForKey:@"Extra"] ) 
	{
		[queryString appendString:@" "];
		[queryString appendString:[theRow objectForKey:@"Extra"]];
	}
	
	if (!isEditingNewRow) {

		// Add details not provided via the SHOW COLUMNS query from the table data cache so column details aren't lost
		NSDictionary *originalColumnDetails = [[tableDataInstance columns] objectAtIndex:currentlyEditingRow];

		// Any column comments
		if ([originalColumnDetails objectForKey:@"comment"] && [(NSString *)[originalColumnDetails objectForKey:@"comment"] length]) {
			[queryString appendString:[NSString stringWithFormat:@" COMMENT '%@'", [mySQLConnection prepareString:[originalColumnDetails objectForKey:@"comment"]]]];
		}

		// Unparsed details - column formats, storage, reference definitions
		if ([originalColumnDetails objectForKey:@"unparsed"]) {
			[queryString appendString:[originalColumnDetails objectForKey:@"unparsed"]];
		}
	}
	
	// Asks the user to add an index to query if auto_increment is set and field isn't indexed
	if ([[theRow objectForKey:@"Extra"] isEqualToString:@"auto_increment"] && 
		([[theRow objectForKey:@"Key"] isEqualToString:@""] || 
		![theRow objectForKey:@"Key"])) 
	{
		[chooseKeyButton selectItemAtIndex:0];
		
		[NSApp beginSheet:keySheet 
		   modalForWindow:tableWindow modalDelegate:self 
		   didEndSelector:nil 
			  contextInfo:nil];
		
		code = [NSApp runModalForWindow:keySheet];
		
		[NSApp endSheet:keySheet];
		[keySheet orderOut:nil];
		
		if (code) {
			// User wants to add PRIMARY KEY
			if ([chooseKeyButton indexOfSelectedItem] == 0 ) { 
				[queryString appendString:@" PRIMARY KEY"];
				
				// Add AFTER ... only if the user added a new field
				if (isEditingNewRow) {
					[queryString appendString:[NSString stringWithFormat:@" AFTER %@", [[[tableFields objectAtIndex:(currentlyEditingRow -1)] objectForKey:@"Field"] backtickQuotedString]]];
				}
			} 
			else {
				// Add AFTER ... only if the user added a new field
				if (isEditingNewRow) {
					[queryString appendString:[NSString stringWithFormat:@" AFTER %@", [[[tableFields objectAtIndex:(currentlyEditingRow -1)] objectForKey:@"Field"] backtickQuotedString]]];
				} 
				
				[queryString appendString:[NSString stringWithFormat:@", ADD %@ (%@)", [chooseKeyButton titleOfSelectedItem], [[theRow objectForKey:@"Field"] backtickQuotedString]]];
			}
		}
	} 
	// Add AFTER ... only if the user added a new field
	else if (isEditingNewRow) {
		[queryString appendString:[NSString stringWithFormat:@" AFTER %@", [[[tableFields objectAtIndex:(currentlyEditingRow -1)] objectForKey:@"Field"] backtickQuotedString]]];
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

		// Query the structure of all databases in the background (mainly for completion)
		[NSThread detachNewThreadSelector:@selector(queryDbStructure) toTarget:mySQLConnection withObject:nil];

		return YES;
	} 
	else {
		alertSheetOpened = YES;
		if([mySQLConnection getLastErrorID] == 1146) { // If the current table doesn't exist anymore
			SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), 
							  NSLocalizedString(@"OK", @"OK button"), 
							  nil, nil, tableWindow, self, @selector(sheetDidEnd:returnCode:contextInfo:), nil, nil, 
							  [NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to alter table '%@'.\n\nMySQL said: %@", @"error while trying to alter table message"), 
							  selectedTable, [mySQLConnection getLastErrorMessage]]);

			isEditingRow = NO;
			isEditingNewRow = NO;
			currentlyEditingRow = -1;
			[tableFields removeAllObjects];
			[indexes removeAllObjects];
			[tableSourceView reloadData];
			[indexView reloadData];
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
							  NSLocalizedString(@"Discard changes", @"discard changes button"), nil, tableWindow, self, @selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addrow", 
							  [NSString stringWithFormat:NSLocalizedString(@"An error occurred when trying to add the field '%@'.\n\nMySQL said: %@", @"error adding field informative message"), 
							  [theRow objectForKey:@"Field"], [mySQLConnection getLastErrorMessage]]);
		} 
		else {
			SPBeginAlertSheet(NSLocalizedString(@"Error changing field", @"error changing field message"), 
							  NSLocalizedString(@"Edit row", @"Edit row button"), 
							  NSLocalizedString(@"Discard changes", @"discard changes button"), nil, tableWindow, self, @selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addrow", 
							  [NSString stringWithFormat:NSLocalizedString(@"An error occurred when trying to change the field '%@'.\n\nMySQL said: %@", @"error changing field informative message"), 
							  [theRow objectForKey:@"Field"], [mySQLConnection getLastErrorMessage]]);
		}
		
		return NO;
	}
}

/*
 * Show Error sheet (can be called from inside of a endSheet selector)
 * via [self performSelector:@selector(showErrorSheetWithTitle:) withObject: afterDelay:]
 */
-(void)showErrorSheetWith:(id)error
{
	// error := first object is the title , second the message, only one button OK
	SPBeginAlertSheet([error objectAtIndex:0], NSLocalizedString(@"OK", @"OK button"), 
			nil, nil, tableWindow, self, nil, nil, nil,
			[error objectAtIndex:1]);
}

/**
 * This method is called as part of Key Value Observing which is used to watch for preference changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	// Display table veiew vertical gridlines preference changed
	if ([keyPath isEqualToString:SPDisplayTableViewVerticalGridlines]) {
        [tableSourceView setGridStyleMask:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
		[indexView setGridStyleMask:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	}
	// Use monospaced fonts preference changed
	else if ([keyPath isEqualToString:SPUseMonospacedFonts]) {
		
		BOOL useMonospacedFont = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
		
		for (NSTableColumn *indexColumn in [indexView tableColumns])
		{
			[[indexColumn dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}
		
		for (NSTableColumn *fieldColumn in [tableSourceView tableColumns])
		{
			[[fieldColumn dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}
		
		[tableSourceView reloadData];
		[indexView reloadData];
	}
}

/**
 * Menu validation
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
	
	// Remove index
	if ([menuItem action] == @selector(removeIndex:)) {
		return ([indexView numberOfSelectedRows] == 1);
	}
	
	// Reset AUTO_INCREMENT
	if ([menuItem action] == @selector(resetAutoIncrement:)) {
		return ([indexView numberOfSelectedRows] == 1 
			&& [[indexes objectAtIndex:[indexView selectedRow]] objectForKey:@"Key_name"] 
			&& [[[indexes objectAtIndex:[indexView selectedRow]] objectForKey:@"Key_name"] isEqualToString:@"PRIMARY"]);
	}
	
	return YES;
}

#pragma mark -
#pragma mark Alert sheet methods

/**
 * Called whenever a sheet is dismissed.
 *
 * if contextInfo == addrow: remain in edit-mode if user hits OK, otherwise cancel editing
 * if contextInfo == removefield: removes row from mysql-db if user hits ok
 * if contextInfo == removeindex: removes index from mysql-db if user hits ok
 * if contextInfo == addIndex: adds and index to the mysql-db if user hits ok
 * if contextInfo == cannotremovefield: do nothing
 */
- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	// Order out current sheet to suppress overlapping of sheets
	if ([sheet respondsToSelector:@selector(orderOut:)])
		[sheet orderOut:nil];
	else if ([sheet respondsToSelector:@selector(window)])
		[[sheet window] orderOut:nil];
	
	if ([contextInfo isEqualToString:@"addrow"]) {
		
		alertSheetOpened = NO;
		
		if (returnCode == NSAlertDefaultReturn) {
			
			// Problem: reentering edit mode for first cell doesn't function
			[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:currentlyEditingRow] byExtendingSelection:NO];
			[tableSourceView performSelector:@selector(keyDown:) withObject:[NSEvent keyEventWithType:NSKeyDown location:NSMakePoint(0,0) modifierFlags:0 timestamp:0 windowNumber:[tableWindow windowNumber] context:[NSGraphicsContext currentContext] characters:nil charactersIgnoringModifiers:nil isARepeat:NO keyCode:0x24] afterDelay:0.0];
		} 
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
	else if ([contextInfo isEqualToString:@"removeField"] || [contextInfo isEqualToString:@"removeFieldAndForeignKey"]) {
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
	else if ([contextInfo isEqualToString:@"addIndex"]) {
		if (returnCode == NSOKButton) {
			[tableDocumentInstance startTaskWithDescription:NSLocalizedString(@"Adding index...", @"adding index task status message")];
			
			if ([NSThread isMainThread]) {
				[NSThread detachNewThreadSelector:@selector(_addIndex) toTarget:self withObject:nil];
				
				[tableDocumentInstance enableTaskCancellationWithTitle:NSLocalizedString(@"Cancel", @"cancel button") callbackObject:self callbackFunction:NULL];				
			} 
			else {
				[self _addIndex];
			}
		}
	}
	else if ([contextInfo isEqualToString:@"removeIndex"] || [contextInfo isEqualToString:@"removeIndexAndForeignKey"]) {
		if (returnCode == NSAlertDefaultReturn) {
			[tableDocumentInstance startTaskWithDescription:NSLocalizedString(@"Removing index...", @"removing index task status message")];
			
			NSNumber *removeKey = [NSNumber numberWithBool:[contextInfo hasSuffix:@"AndForeignKey"]];
			
			if ([NSThread isMainThread]) {
				[NSThread detachNewThreadSelector:@selector(_removeIndexAndForeignKey:) toTarget:self withObject:removeKey];
				
				[tableDocumentInstance enableTaskCancellationWithTitle:NSLocalizedString(@"Cancel", @"cancel button") callbackObject:self callbackFunction:NULL];				
			} 
			else {
				[self _removeIndexAndForeignKey:removeKey];
			}
		}
	} 
	else if ([contextInfo isEqualToString:@"cannotremovefield"]) {
		;
	}
	else if ([contextInfo isEqualToString:@"resetAutoIncrement"]) {
		if (returnCode == NSAlertDefaultReturn) {
			[self setAutoIncrementTo:[[resetAutoIncrementValue stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
		}
	}
	else
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
		[tempArray addObject:[field objectForKey:@"Field"]];
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
- (void) startDocumentTaskForTab:(NSNotification *)aNotification
{

	// Only proceed if this view is selected.
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableStructure]) return;

	[tableSourceView setEnabled:NO];
	[addFieldButton setEnabled:NO];
	[removeFieldButton setEnabled:NO];
	[copyFieldButton setEnabled:NO];
	[reloadFieldsButton setEnabled:NO];
	[editTableButton setEnabled:NO];

	[indexView setEnabled:NO];
	[addIndexButton setEnabled:NO];
	[removeIndexButton setEnabled:NO];
	[reloadIndexesButton setEnabled:NO];
}

/**
 * Enable all content interactive elements after an ongoing task.
 */
- (void) endDocumentTaskForTab:(NSNotification *)aNotification
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

	[indexView setEnabled:YES];
	[indexView displayIfNeeded];
	[addIndexButton setEnabled:editingEnabled];
	if (editingEnabled && [indexView numberOfSelectedRows] > 0)
		[removeIndexButton setEnabled:YES];
	[reloadIndexesButton setEnabled:YES];
}

#pragma mark -
#pragma mark TableView datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return (aTableView == tableSourceView) ? [tableFields count] : [indexes count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	NSDictionary *theRow;

	if (aTableView == tableSourceView) {
		
		// Return a placeholder if the table is reloading
		if (rowIndex >= [tableFields count]) return @"...";

		theRow = [tableFields objectAtIndex:rowIndex];
	} else {
		theRow = [indexes objectAtIndex:rowIndex];
	}

	return [theRow objectForKey:[aTableColumn identifier]];
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    // Make sure that the drag operation is for the right table view
    if (aTableView!=tableSourceView) return;

	if (!isEditingRow) {
		[oldRow setDictionary:[tableFields objectAtIndex:rowIndex]];
		isEditingRow = YES;
		currentlyEditingRow = rowIndex;
	}
	
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
		[[originalRow objectForKey:@"Field"] backtickQuotedString],
		[originalRow objectForKey:@"Type"]];

	// Add the length parameter if necessary
	if ( [originalRow objectForKey:@"Length"] && ![[originalRow objectForKey:@"Length"] isEqualToString:@""]) {
		[queryString appendString:[NSString stringWithFormat:@"(%@)", [originalRow objectForKey:@"Length"]]];
	}

	// Add unsigned, zerofill, binary, not null if necessary
	if ([[originalRow objectForKey:@"unsigned"] isEqualToString:@"1"]) {
		[queryString appendString:@" UNSIGNED"];
	}
	if ([[originalRow objectForKey:@"zerofill"] isEqualToString:@"1"]) {
		[queryString appendString:@" ZEROFILL"];
	}
	if ([[originalRow objectForKey:@"binary"] isEqualToString:@"1"]) {
		[queryString appendString:@" BINARY"];
	}
	if ([[originalRow objectForKey:@"Null"] isEqualToString:@"0"] ) {
		[queryString appendString:@" NOT NULL"];
	}
	if (![[originalRow objectForKey:@"Extra"] isEqualToString:@"None"] ) {
		[queryString appendString:@" "];
		[queryString appendString:[[originalRow objectForKey:@"Extra"] uppercaseString]];
	}

	// Add the default value
	if ([[originalRow objectForKey:@"Default"] isEqualToString:[prefs objectForKey:SPNullValue]]) {
		if ([[originalRow objectForKey:@"Null"] integerValue] == 1) {
			[queryString appendString:@" DEFAULT NULL"];
		}
	} else if ( [[originalRow objectForKey:@"Type"] isEqualToString:@"timestamp"] && ([[[originalRow objectForKey:@"Default"] uppercaseString] isEqualToString:@"CURRENT_TIMESTAMP"]) ) {
			[queryString appendString:@" DEFAULT CURRENT_TIMESTAMP"];
	} else {
		[queryString appendString:[NSString stringWithFormat:@" DEFAULT '%@'", [mySQLConnection prepareString:[originalRow objectForKey:@"Default"]]]];
	}

	// Add details not provided via the SHOW COLUMNS query from the table data cache so column details aren't lost
	NSDictionary *originalColumnDetails = [[tableDataInstance columns] objectAtIndex:originalRowIndex];

	// Any column comments
	if ([originalColumnDetails objectForKey:@"comment"] && [(NSString *)[originalColumnDetails objectForKey:@"comment"] length]) {
		[queryString appendString:[NSString stringWithFormat:@" COMMENT '%@'", [mySQLConnection prepareString:[originalColumnDetails objectForKey:@"comment"]]]];
	}

	// Unparsed details - column formats, storage, reference definitions
	if ([originalColumnDetails objectForKey:@"unparsed"]) {
		[queryString appendString:[originalColumnDetails objectForKey:@"unparsed"]];
	}

	// Add the new location
	if ( destinationRowIndex == 0 ){
		[queryString appendString:@" FIRST"];
	} else {
		[queryString appendString:[NSString stringWithFormat:@" AFTER %@",
						[[[tableFields objectAtIndex:destinationRowIndex-1] objectForKey:@"Field"] backtickQuotedString]]];
	}

	// Run the query; report any errors, or reload the table on success
	[mySQLConnection queryString:queryString];
	if ([mySQLConnection queryErrored]) {
		SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
			[NSString stringWithFormat:NSLocalizedString(@"Couldn't move field. MySQL said: %@", @"message of panel when field cannot be added in drag&drop operation"), [mySQLConnection getLastErrorMessage]]);
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
	else if (object == indexView) {
		// Check if there is currently an index selected and change button state accordingly
		[removeIndexButton setEnabled:([indexView numberOfSelectedRows] > 0 && [tablesListInstance tableType] == SPTableTypeTable)];
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

	 if (  [textView methodForSelector:command] == [textView methodForSelector:@selector(insertNewline:)] ||
				[textView methodForSelector:command] == [textView methodForSelector:@selector(insertTab:)] ) //trap enter and tab
	 {
		//save current line
		[[control window] makeFirstResponder:control];
		if ( column == 9 ) {
			if ( [self addRowToDB] && [textView methodForSelector:command] == [textView methodForSelector:@selector(insertTab:)] ) {
				if ( row < ([tableSourceView numberOfRows] - 1) ) {
					[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:row+1] byExtendingSelection:NO];
					[tableSourceView editColumn:0 row:row+1 withEvent:nil select:YES];
				} else {
					[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
					[tableSourceView editColumn:0 row:0 withEvent:nil select:YES];
				}
			}
		} else {
			if ( column == 2 ) {
				[tableSourceView editColumn:column+6 row:row withEvent:nil select:YES];
			} else {
				[tableSourceView editColumn:column+1 row:row withEvent:nil select:YES];
			}
		}
		return TRUE;
		 
	 } else if (  [[control window] methodForSelector:command] == [[control window] methodForSelector:@selector(_cancelKey:)] ||
					[textView methodForSelector:command] == [textView methodForSelector:@selector(complete:)] ) {
		//abort editing
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
		return TRUE;
	 } else {
		 return FALSE;
	 }
}


/*
 * Modify cell display by disabling table cells when a view is selected, meaning structure/index
 * is uneditable.
 */
- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    
    //make sure that the message is from the right table view
    if (tableView!=tableSourceView) return;

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
	return proposedMax - 150;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
	return proposedMin + 150;
}

- (NSRect)splitView:(NSSplitView *)splitView additionalEffectiveRectOfDividerAtIndex:(NSInteger)dividerIndex
{	
	return [structureGrabber convertRect:[structureGrabber bounds] toView:splitView];
}

#pragma mark -
#pragma mark Other

// Last but not least
- (id)init
{
	if ((self = [super init])) {
		tableFields = [[NSMutableArray alloc] init];
		indexes     = [[NSMutableArray alloc] init];
		oldRow      = [[NSMutableDictionary alloc] init];
		enumFields  = [[NSMutableDictionary alloc] init];
		
		currentlyEditingRow = -1;
		defaultValues = nil;
		selectedTable = nil;
		
		prefs = [NSUserDefaults standardUserDefaults];
	}

	return self;
}

- (void)awakeFromNib
{
	// Set the structure and index view's vertical gridlines if required
	[tableSourceView setGridStyleMask:([prefs boolForKey:SPDisplayTableViewVerticalGridlines]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	[indexView setGridStyleMask:([prefs boolForKey:SPDisplayTableViewVerticalGridlines]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
		
	// Set the strutcture and index view's font
	BOOL useMonospacedFont = [prefs boolForKey:SPUseMonospacedFonts];
	
	for (NSTableColumn *indexColumn in [indexView tableColumns])
	{
		[[indexColumn dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}
	
	for (NSTableColumn *fieldColumn in [tableSourceView tableColumns])
	{
		[[fieldColumn dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}
	
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

- (void)dealloc
{	
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[tableFields release];
	[indexes release];
	[oldRow release];
	[enumFields release];
	if (defaultValues) [defaultValues release];
	if (selectedTable) [selectedTable release];
	
	[super dealloc];
}

@end

@implementation TableSource (PrivateAPI)

/**
 * Adds an index to the current table.
 */
- (void)_addIndex;
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Check whether a save of the current fields row is required.
	if (![[self onMainThread] saveRowOnDeselect]) return;
	
	if (![[indexedColumnsField stringValue] isEqualToString:@""]) {
		
		NSString *indexName = @"";
		NSMutableArray *tempIndexedColumns = [[NSMutableArray alloc] init];
		
		if ([[indexNameField stringValue] isEqualToString:@"PRIMARY"]) {
			indexName = @"";
		} 
		else {
			indexName = ([[indexNameField stringValue] isEqualToString:@""]) ? @"" : [[indexNameField stringValue] backtickQuotedString];
		}
		
		NSArray *indexedColumns = [[indexedColumnsField stringValue] componentsSeparatedByString:@","];
		
		// For each column strip leading and trailing whitespace and add it to the temp array
		for (NSString *column in indexedColumns)
		{			
			[tempIndexedColumns addObject:[column stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
		}
		
		// Execute the query
		[mySQLConnection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ ADD %@ %@ (%@)",
									  [selectedTable backtickQuotedString], [indexTypeField titleOfSelectedItem], indexName,
									  [tempIndexedColumns componentsJoinedAndBacktickQuoted]]];
		
		// Check for errors, but only if the query wasn't cancelled
		if ([mySQLConnection queryErrored] && ![mySQLConnection queryCancelled]) {
			SPBeginAlertSheet(NSLocalizedString(@"Unable to add index", @"add index error message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil, 
							  [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to add the index.\n\nMySQL said: %@", @"add index error informative message"), [mySQLConnection getLastErrorMessage]]);
		}
		else {
			[tableDataInstance resetAllData];
			[tablesListInstance setStatusRequiresReload:YES];
			[self loadTable:selectedTable];
		}
		
		[tempIndexedColumns release];
	}
	
	[tableDocumentInstance endTask];
	
	[pool drain];
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
		NSString *field = [[tableFields objectAtIndex:[tableSourceView selectedRow]] objectForKey:@"Field"];
		
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
			
			SPBeginAlertSheet(NSLocalizedString(@"Unable to remove relation", @"error removing relation message"), 
							  NSLocalizedString(@"OK", @"OK button"),
							  nil, nil, [NSApp mainWindow], nil, nil, nil, nil, 
							  [NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to remove the relation '%@'.\n\nMySQL said: %@", @"error removing relation informative message"), relationName, [mySQLConnection getLastErrorMessage]]);	
		} 
	}
	
	// Remove field
	[mySQLConnection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ DROP %@",
								  [selectedTable backtickQuotedString], [[[tableFields objectAtIndex:[tableSourceView selectedRow]] objectForKey:@"Field"] backtickQuotedString]]];
	
	// Check for errors, but only if the query wasn't cancelled
	if ([mySQLConnection queryErrored] && ![mySQLConnection queryCancelled]) {
		
		[self performSelector:@selector(showErrorSheetWith:) 
				   withObject:[NSArray arrayWithObjects:NSLocalizedString(@"Error", @"error"),
							   [NSString stringWithFormat:NSLocalizedString(@"Couldn't remove field %@.\nMySQL said: %@", @"message of panel when field cannot be removed"),
								[[tableFields objectAtIndex:[tableSourceView selectedRow]] objectForKey:@"Field"],
								[mySQLConnection getLastErrorMessage]],
							   nil] 
				   afterDelay:0.3];
	} 
	else {
		[tableDataInstance resetAllData];
		[tablesListInstance setStatusRequiresReload:YES];
		[self loadTable:selectedTable];
		
		// Mark the content table cache for refresh
		[tablesListInstance setContentRequiresReload:YES];
	}
	
	[tableDocumentInstance endTask];
	
	[pool drain];
}

/**
 * Removes an index from the current table and the dependent foreign key if specified.
 */
- (void)_removeIndexAndForeignKey:(NSNumber *)removeForeignKey
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Remove the foreign key dependency before the index if required
	if ([removeForeignKey boolValue]) {
		
		NSString *columnName =  [[indexes objectAtIndex:[indexView selectedRow]] objectForKey:@"Column_name"];
		
		NSString *constraintName = @"";
		
		// Check to see whether the user is attempting to remove an index that a foreign key constraint depends on
		// thus would result in an error if not dropped before removing the index.
		for (NSDictionary *constraint in [tableDataInstance getConstraints])
		{
			for (NSString *column in [constraint objectForKey:@"columns"])
			{
				if ([column isEqualToString:columnName]) {
					constraintName = [constraint objectForKey:@"name"];
					break;
				}
			}
		}
		
		[mySQLConnection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ DROP FOREIGN KEY %@", [selectedTable backtickQuotedString], [constraintName backtickQuotedString]]];
		
		// Check for errors, but only if the query wasn't cancelled
		if ([mySQLConnection queryErrored] && ![mySQLConnection queryCancelled]) {
			
			SPBeginAlertSheet(NSLocalizedString(@"Unable to remove relation", @"error removing relation message"), 
							  NSLocalizedString(@"OK", @"OK button"),
							  nil, nil, [NSApp mainWindow], nil, nil, nil, nil, 
							  [NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to remove the relation '%@'.\n\nMySQL said: %@", @"error removing relation informative message"), constraintName, [mySQLConnection getLastErrorMessage]]);	
		} 
	}
	
	if ([[[indexes objectAtIndex:[indexView selectedRow]] objectForKey:@"Key_name"] isEqualToString:@"PRIMARY"]) {
		[mySQLConnection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ DROP PRIMARY KEY", [selectedTable backtickQuotedString]]];
	}
	else {
		[mySQLConnection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ DROP INDEX %@",
									  [selectedTable backtickQuotedString], [[[indexes objectAtIndex:[indexView selectedRow]] objectForKey:@"Key_name"] backtickQuotedString]]];
	}
	
	// Check for errors, but only if the query wasn't cancelled
	if ([mySQLConnection queryErrored] && ![mySQLConnection queryCancelled]) {
		
		[self performSelector:@selector(showErrorSheetWith:) 
				   withObject:[NSArray arrayWithObjects:NSLocalizedString(@"Unable to remove index", @"error removing index message"),
							   [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to remove the index.\n\nMySQL said: %@", @"error removing index informative message"), [mySQLConnection getLastErrorMessage]], nil] 
				   afterDelay:0.3];
	} 
	else {
		[tableDataInstance resetAllData];
		[tablesListInstance setStatusRequiresReload:YES];
		[self loadTable:selectedTable];
	}
	
	[tableDocumentInstance endTask];
	
	[pool drain];
}

@end
