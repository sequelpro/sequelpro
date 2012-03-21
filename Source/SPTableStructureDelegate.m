//
//  $Id$
//
//  SPTableStructureDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 26, 2010
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPTableStructureDelegate.h"
#import "SPAlertSheets.h"
#import "SPDatabaseData.h"
#import "SPDatabaseViewController.h"
#import "SPTableData.h"
#import "SPTableView.h"
#import "SPTableFieldValidation.h"
#import "SPMySQL.h"

@implementation SPTableStructure (SPTableStructureDelegate)

#pragma mark -
#pragma mark Table view datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [tableFields count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	// Return a placeholder if the table is reloading
	if ((NSUInteger)rowIndex >= [tableFields count]) return @"...";
	
	if([[tableColumn identifier] isEqualToString:@"collation"]) {
		NSInteger idx = 0;
		if((idx = [[NSArrayObjectAtIndex(tableFields,rowIndex) objectForKey:@"encoding"] integerValue]) > 0 && idx < [encodingPopupCell numberOfItems]) {
			NSString *enc = [[encodingPopupCell itemAtIndex:idx] title];
			NSInteger start = [enc rangeOfString:@"("].location+1;
			NSInteger end = [enc length] - start - 1;
			collations = [databaseDataInstance getDatabaseCollationsForEncoding:[enc substringWithRange:NSMakeRange(start, end)]];
		} else {

			// If the structure has loaded (not still loading!) and the table encoding
			// is set, use the appropriate collations.
			if([tableDocumentInstance structureLoaded] && [tableDataInstance tableEncoding] != nil) {
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

	else if([[tableColumn identifier] isEqualToString:@"Extra"]) {
		id dataCell = [tableColumn dataCell];
		[dataCell removeAllItems];
		// Populate Extra suggestion popup button
		for (id item in extraFieldSuggestions) {
			if(!(isCurrentExtraAutoIncrement && [item isEqualToString:@"auto_increment"])) {
				[dataCell addItemWithObjectValue:item];
			}
		}
	}

	return [NSArrayObjectAtIndex(tableFields, rowIndex) objectForKey:[tableColumn identifier]];
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
	
	NSMutableDictionary *currentRow = [tableFields objectAtIndex:rowIndex];
	
	// Reset collation if encoding was changed
	if([[aTableColumn identifier] isEqualToString:@"encoding"]) {
		if([[currentRow objectForKey:@"encoding"] integerValue] != [anObject integerValue]) {
			[currentRow setObject:[NSNumber numberWithInteger:0] forKey:@"collation"];
			[tableSourceView reloadData];
		}
	}
	// Reset collation if BINARY was set to 1 since BINARY sets collation to *_bin
	else if([[aTableColumn identifier] isEqualToString:@"binary"]) {
		if([[currentRow objectForKey:@"binary"] integerValue] != [anObject integerValue]) {
			if([anObject integerValue] == 1) {
				[currentRow setObject:[NSNumber numberWithInteger:0] forKey:@"collation"];
			}
			[tableSourceView reloadData];
		}
	}
	// Set null field to "do not allow NULL" for auto_increment Extra and reset Extra suggestion list
	else if([[aTableColumn identifier] isEqualToString:@"Extra"]) {
		if(![[currentRow objectForKey:@"Extra"] isEqualToString:anObject]) {

			isCurrentExtraAutoIncrement = [[[anObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString] isEqualToString:@"AUTO_INCREMENT"];
			if(isCurrentExtraAutoIncrement) {
				[currentRow setObject:[NSNumber numberWithInteger:0] forKey:@"null"];

				// Asks the user to add an index to query if AUTO_INCREMENT is set and field isn't indexed
				if ((![currentRow objectForKey:@"Key"] || [[currentRow objectForKey:@"Key"] isEqualToString:@""])) {
#ifndef SP_REFACTOR
					[chooseKeyButton selectItemWithTag:SPPrimaryKeyMenuTag];

					[NSApp beginSheet:keySheet
					   modalForWindow:[tableDocumentInstance parentWindow] modalDelegate:self
					   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
						  contextInfo:@"autoincrementindex" ];
#endif
				}
			} else {
				autoIncrementIndex = nil;
			}

			id dataCell = [aTableColumn dataCell];
			[dataCell removeAllItems];
			[dataCell addItemsWithObjectValues:extraFieldSuggestions];
			[dataCell noteNumberOfItemsChanged];
			[dataCell reloadData];
			[tableSourceView reloadData];

		}
	}
	// Reset default to "" if field doesn't allow NULL and current default is set to NULL
	else if ([[aTableColumn identifier] isEqualToString:@"null"]) {
		if ([[currentRow objectForKey:@"null"] integerValue] != [anObject integerValue]) {
			if([anObject integerValue] == 0) {
				if([[currentRow objectForKey:@"default"] isEqualToString:[prefs objectForKey:SPNullValue]])
					[currentRow setObject:@"" forKey:@"default"];
			}
			[tableSourceView reloadData];
		}
	}
	
	// Store new value but not if user choose "---" for type and reset values if required
	if ([[aTableColumn identifier] isEqualToString:@"type"]) {
		if (anObject && [(NSString*)anObject length] && ![(NSString*)anObject hasPrefix:@"--"]) {
			[currentRow setObject:[(NSString*)anObject uppercaseString] forKey:@"type"];
			
			// If type is BLOB or TEXT reset DEFAULT since these field types don't allow a default
			if ([[currentRow objectForKey:@"type"] hasSuffix:@"TEXT"] 
					|| [[currentRow objectForKey:@"type"] hasSuffix:@"BLOB"] 
					|| [fieldValidation isFieldTypeGeometry:[currentRow objectForKey:@"type"]]
					|| ([fieldValidation isFieldTypeDate:[currentRow objectForKey:@"type"]] && ![[currentRow objectForKey:@"type"] isEqualToString:@"YEAR"])) {
				[currentRow setObject:@"" forKey:@"default"];
				[currentRow setObject:@"" forKey:@"length"];
			}
			
			[tableSourceView reloadData];
		}
	} 
	else {
		[currentRow setObject:(anObject) ? anObject : @"" forKey:[aTableColumn identifier]];
	}
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

/**
 * Begin a drag and drop operation from the table - copy a single dragged row to the drag pasteboard.
 */
- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rows toPasteboard:(NSPasteboard*)pboard
{
	// Make sure that the drag operation is started from the right table view
	if (aTableView != tableSourceView) return NO;
	
	// Check whether a save of the current field row is required.
	if ( ![self saveRowOnDeselect] ) return NO;
	
	if ([rows count] == 1) {
		[pboard declareTypes:[NSArray arrayWithObject:SPDefaultPasteboardDragType] owner:nil];
		[pboard setString:[[NSNumber numberWithInteger:[rows firstIndex]] stringValue] forType:SPDefaultPasteboardDragType];
		return YES;
	} 
	else {
		return NO;
	}
}

/**
 * Determine whether to allow a drag and drop operation on this table - for the purposes of drag reordering,
 * validate that the original source is of the correct type and within the same table, and that the drag
 * would result in a position change.
 */
- (NSDragOperation)tableView:(NSTableView*)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    //make sure that the drag operation is for the right table view
    if (tableView!=tableSourceView) return NO;
	
	NSArray *pboardTypes = [[info draggingPasteboard] types];
	NSInteger originalRow;
	
	// Ensure the drop is of the correct type
	if (operation == NSTableViewDropAbove && row != -1 && [pboardTypes containsObject:SPDefaultPasteboardDragType]) {
		
		// Ensure the drag originated within this table
		if ([info draggingSource] == tableView) {
			originalRow = [[[info draggingPasteboard] stringForType:SPDefaultPasteboardDragType] integerValue];
			
			if (row != originalRow && row != (originalRow+1)) {
				return NSDragOperationMove;
			}
		}
	}
	
	return NSDragOperationNone;
}

/**
 * Having validated a drop, perform the field/column reordering to match.
 */
- (BOOL)tableView:(NSTableView*)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)destinationRowIndex dropOperation:(NSTableViewDropOperation)operation
{
    // Make sure that the drag operation is for the right table view
    if (tableView != tableSourceView) return NO;
	
	NSInteger originalRowIndex;
	NSMutableString *queryString;
	NSDictionary *originalRow;
	
	// Extract the original row position from the pasteboard and retrieve the details
	originalRowIndex = [[[info draggingPasteboard] stringForType:SPDefaultPasteboardDragType] integerValue];
	originalRow = [[NSDictionary alloc] initWithDictionary:[tableFields objectAtIndex:originalRowIndex]];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:tableDocumentInstance];
	
	// Begin construction of the reordering query
	queryString = [NSMutableString stringWithFormat:@"ALTER TABLE %@ MODIFY COLUMN %@ %@", [selectedTable backtickQuotedString],
				   [[originalRow objectForKey:@"name"] backtickQuotedString],
				   [[originalRow objectForKey:@"type"] uppercaseString]];
	
	// Add the length parameter if necessary
	if ([originalRow objectForKey:@"length"] && ![[originalRow objectForKey:@"length"] isEqualToString:@""]) {
		[queryString appendFormat:@"(%@)", [originalRow objectForKey:@"length"]];
	}
	
	NSString *fieldEncoding = @"";
	
	if ([[originalRow objectForKey:@"encoding"] integerValue] > 0) {
		NSString *enc = [[encodingPopupCell itemAtIndex:[[originalRow objectForKey:@"encoding"] integerValue]] title];
		NSInteger start = [enc rangeOfString:@"("].location+1;
		NSInteger end = [enc length] - start - 1;
		fieldEncoding = [enc substringWithRange:NSMakeRange(start, end)];
		[queryString appendFormat:@" CHARACTER SET %@", fieldEncoding];
	}
	
	if (![fieldEncoding length] && [tableDataInstance tableEncoding]) {
		fieldEncoding = [tableDataInstance tableEncoding];
	}
	
	if ([fieldEncoding length] && [[originalRow objectForKey:@"collation"] integerValue] > 0) {
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
	if ([originalRow objectForKey:@"Extra"] && ![[originalRow objectForKey:@"Extra"] isEqualToString:@"auto_increment"]) {
		if ([[originalRow objectForKey:@"default"] isEqualToString:[prefs objectForKey:SPNullValue]]) {
			if ([[originalRow objectForKey:@"null"] integerValue] == 1) {
				[queryString appendString:(isTimestampType) ? @" NULL DEFAULT NULL" : @" DEFAULT NULL"];
			}
		}
		else if (isTimestampType && ([[[originalRow objectForKey:@"default"] uppercaseString] isEqualToString:@"CURRENT_TIMESTAMP"]) ) {
			[queryString appendString:@" DEFAULT CURRENT_TIMESTAMP"];
		}
		else if ([(NSString *)[originalRow objectForKey:@"default"] length]) {
			[queryString appendFormat:@" DEFAULT %@", [mySQLConnection escapeAndQuoteString:[originalRow objectForKey:@"default"]]];
		}
	}
	
	// Any column comments
	if ([(NSString *)[originalRow objectForKey:@"comment"] length]) {
		[queryString appendFormat:@" COMMENT %@", [mySQLConnection escapeAndQuoteString:[originalRow objectForKey:@"comment"]]];
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
						  [NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to move the field.\n\nMySQL said: %@", @"error moving field informative message"), [mySQLConnection lastErrorMessage]]);
	} 
	else {
		[tableDataInstance resetAllData];
		[tableDocumentInstance setStatusRequiresReload:YES];
		[self loadTable:selectedTable];
		
		// Mark the content table cache for refresh
		[tableDocumentInstance setContentRequiresReload:YES];
		
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
#pragma mark Table view delegate methods

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
		
		[duplicateFieldButton setEnabled:YES];
		
		// Check if there is currently a field selected and change button state accordingly
		if ([tableSourceView numberOfSelectedRows] > 0 && [tablesListInstance tableType] == SPTableTypeTable) {
			[removeFieldButton setEnabled:YES];
		} 
		else {
			[removeFieldButton setEnabled:NO];
			[duplicateFieldButton setEnabled:NO];
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
	else if ([textView methodForSelector:command] == [textView methodForSelector:@selector(insertNewline:)])
	{
		// Suppress enter for non-text fields to allow selecting of chosen items from comboboxes or popups
		if (![[[[[[tableSourceView tableColumns] objectAtIndex:column] dataCell] class] description] isEqualToString:@"NSTextFieldCell"])
			return YES;
		
		[[control window] makeFirstResponder:control];
		[self addRowToDB];
		[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		[[tableDocumentInstance parentWindow] makeFirstResponder:tableSourceView];
		
		return YES;
	}
	
	// Trap escape, aborting the edit and reverting the row
	else if (  [[control window] methodForSelector:command] == [[control window] methodForSelector:@selector(cancelOperation:)] )
	{
		[control abortEditing];
		[self cancelRowEditing];
		
		return YES;
	} 
	else {
		return NO;
	}
}

/**
 * Modify cell display by disabling table cells when a view is selected, meaning structure/index
 * is uneditable and do cell validation due to row's field type.
 */
- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	//make sure that the message is from the right table view
	if (tableView != tableSourceView) return;
	
	if ([tablesListInstance tableType] == SPTableTypeView) {
		[aCell setEnabled:NO];
	} 
	else {
		// validate cell against current field type
		NSDictionary *theRow = NSArrayObjectAtIndex(tableFields, rowIndex);
		NSString *theRowType = @"";
		
		if ((theRowType = [theRow objectForKey:@"type"])) {
			theRowType = [[theRowType stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
		}
		
		// Only string fields allow encoding settings
		if (([[aTableColumn identifier] isEqualToString:@"encoding"])) {
			[aCell setEnabled:([fieldValidation isFieldTypeString:theRowType] && ![theRowType hasSuffix:@"BINARY"] && ![theRowType hasSuffix:@"BLOB"])];
		}
		
		// Only string fields allow collation settings and string field is not set to BINARY since BINARY sets the collation to *_bin
		else if ([[aTableColumn identifier] isEqualToString:@"collation"]){
 			[aCell setEnabled:([fieldValidation isFieldTypeString:theRowType] && [[theRow objectForKey:@"binary"] integerValue] == 0 && ![theRowType hasSuffix:@"BINARY"] && ![theRowType hasSuffix:@"BLOB"])];
		}
		
		// Check if UNSIGNED and ZEROFILL is allowed
		else if ([[aTableColumn identifier] isEqualToString:@"zerofill"] || [[aTableColumn identifier] isEqualToString:@"unsigned"]) {
			[aCell setEnabled:([fieldValidation isFieldTypeNumeric:theRowType] && ![theRowType isEqualToString:@"BIT"])];
		}
		
		// Check if BINARY is allowed
		else if ([[aTableColumn identifier] isEqualToString:@"binary"]) {
			[aCell setEnabled:([fieldValidation isFieldTypeAllowBinary:theRowType])];
		}
		
		// TEXT, BLOB, and GEOMETRY fields don't allow a DEFAULT
		else if ([[aTableColumn identifier] isEqualToString:@"default"]) {
			[aCell setEnabled:([theRowType hasSuffix:@"TEXT"] || [theRowType hasSuffix:@"BLOB"] || [fieldValidation isFieldTypeGeometry:theRowType]) ? NO : YES];
		}
		
		// Check allow NULL
		else if ([[aTableColumn identifier] isEqualToString:@"null"]) {
			[aCell setEnabled:([[theRow objectForKey:@"Key"] isEqualToString:@"PRI"] || [[[theRow objectForKey:@"Extra"] uppercaseString] isEqualToString:@"AUTO_INCREMENT"]) ? NO : YES];
		}
		
		// TEXT, BLOB, date, and GEOMETRY fields don't allow a length
		else if ([[aTableColumn identifier] isEqualToString:@"length"]) {
			[aCell setEnabled:([theRowType hasSuffix:@"TEXT"] || [theRowType hasSuffix:@"BLOB"] || ([fieldValidation isFieldTypeDate:theRowType] && ![theRowType isEqualToString:@"YEAR"]) || [fieldValidation isFieldTypeGeometry:theRowType]) ? NO : YES];
		}
		else {
			[aCell setEnabled:YES];
		}
	}
}

#pragma mark -
#pragma mark Split view delegate methods
#ifndef SP_REFACTOR /* Split view delegate methods */

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
		} 
		else {
			[indexesShowButton setHidden:YES];
		}
	}
}
#endif

#pragma mark -
#pragma mark Combo box delegate methods

- (id)comboBoxCell:(NSComboBoxCell *)aComboBoxCell objectValueForItemAtIndex:(NSInteger)index
{
	return NSArrayObjectAtIndex(typeSuggestions, index);
}

- (NSInteger)numberOfItemsInComboBoxCell:(NSComboBoxCell *)aComboBoxCell
{
	return [typeSuggestions count];
}

/**
 * Allow completion of field data types of lowercased input.
 */
- (NSString *)comboBoxCell:(NSComboBoxCell *)aComboBoxCell completedString:(NSString *)uncompletedString
{
	if ([uncompletedString hasPrefix:@"-"]) return @"";
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH[c] %@", [uncompletedString uppercaseString]];
	NSArray *result = [typeSuggestions filteredArrayUsingPredicate:predicate];
	
	if (result && [result count]) return [result objectAtIndex:0];
	
	return @"";
}

@end
