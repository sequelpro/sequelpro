//
//  SPTableContentDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on March 20, 2012.
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
//
//  More info at <https://github.com/sequelpro/sequelpro>

#import "SPTableContentDelegate.h"
#import "SPTableContentFilter.h"
#ifndef SP_CODA /* headers */
#import "SPAppController.h"
#endif
#import "SPDatabaseDocument.h"
#import "SPDataStorage.h"
#import "SPGeometryDataView.h"
#import "SPTooltip.h"
#import "SPTablesList.h"
#ifndef SP_CODA /* headers */
#import "SPBundleHTMLOutputController.h"
#endif
#import "SPCopyTable.h"
#import "SPAlertSheets.h"
#import "SPTableData.h"
#import "SPFieldEditorController.h"
#import "SPThreadAdditions.h"
#import "SPTextAndLinkCell.h"

#import <pthread.h>
#import <SPMySQL/SPMySQL.h>

@interface SPTableContent (SPDeclaredAPI)

- (BOOL)cancelRowEditing;
- (BOOL)cellValueIsDisplayedAsHexForColumn:(NSUInteger)columnIndex;

@end

@implementation SPTableContent (SPTableContentDelegate)

#pragma mark -
#pragma mark TableView delegate methods

/**
 * Sorts the tableView by the clicked column. If clicked twice, order is altered to descending.
 * Performs the task in a new thread if necessary.
 */
- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
	if ([selectedTable isEqualToString:@""] || !selectedTable || tableView != tableContentView) return;
	
	// Prevent sorting while the table is still loading
	if ([tableDocumentInstance isWorking]) return;
	
	// Start the task
	[tableDocumentInstance startTaskWithDescription:NSLocalizedString(@"Sorting table...", @"Sorting table task description")];
	
	if ([NSThread isMainThread]) {
		[NSThread detachNewThreadWithName:SPCtxt(@"SPTableContent table sort task", tableDocumentInstance) target:self selector:@selector(sortTableTaskWithColumn:) object:tableColumn];
	} 
	else {
		[self sortTableTaskWithColumn:tableColumn];
	}
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	// Check our notification object is our table content view
	if ([aNotification object] != tableContentView) return;
	
	isFirstChangeInView = YES;
	
	[addButton setEnabled:([tablesListInstance tableType] == SPTableTypeTable)];
	
	// If we are editing a row, attempt to save that row - if saving failed, reselect the edit row.
	if (isEditingRow && [tableContentView selectedRow] != currentlyEditingRow && ![self saveRowOnDeselect]) return;
	
	if (![tableDocumentInstance isWorking]) {
		// Update the row selection count
		// and update the status of the delete/duplicate buttons
		if([tablesListInstance tableType] == SPTableTypeTable) {
			if ([tableContentView numberOfSelectedRows] > 0) {
				[duplicateButton setEnabled:([tableContentView numberOfSelectedRows] == 1)];
				[removeButton setEnabled:YES];
			}
			else {
				[duplicateButton setEnabled:NO];
				[removeButton setEnabled:NO];
			}
		} 
		else {
			[duplicateButton setEnabled:NO];
			[removeButton setEnabled:NO];
		}
	}
	
	[self updateCountText];
	
#ifndef SP_CODA /* triggered commands */
	NSArray *triggeredCommands = [SPAppDelegate bundleCommandsForTrigger:SPBundleTriggerActionTableRowChanged];
	
	for (NSString *cmdPath in triggeredCommands) 
	{
		NSArray *data = [cmdPath componentsSeparatedByString:@"|"];
		NSMenuItem *aMenuItem = [[[NSMenuItem alloc] init] autorelease];
		
		[aMenuItem setTag:0];
		[aMenuItem setToolTip:[data objectAtIndex:0]];
		
		// For HTML output check if corresponding window already exists
		BOOL stopTrigger = NO;
		
		if ([(NSString *)[data objectAtIndex:2] length]) {
			BOOL correspondingWindowFound = NO;
			NSString *uuid = [data objectAtIndex:2];
			
			for (id win in [NSApp windows]) 
			{
				if ([[[[win delegate] class] description] isEqualToString:@"SPBundleHTMLOutputController"]) {
					if ([[[win delegate] windowUUID] isEqualToString:uuid]) {
						correspondingWindowFound = YES;
						break;
					}
				}
			}
			
			if (!correspondingWindowFound) stopTrigger = YES;
		}
		if (!stopTrigger) {
			id firstResponder = [[NSApp keyWindow] firstResponder];
			if ([[data objectAtIndex:1] isEqualToString:SPBundleScopeGeneral]) {
				[[SPAppDelegate onMainThread] executeBundleItemForApp:aMenuItem];
			}
			else if ([[data objectAtIndex:1] isEqualToString:SPBundleScopeDataTable]) {
				if ([[[firstResponder class] description] isEqualToString:@"SPCopyTable"]) {
					[[firstResponder onMainThread] executeBundleItemForDataTable:aMenuItem];
				}
			}
			else if ([[data objectAtIndex:1] isEqualToString:SPBundleScopeInputField]) {
				if ([firstResponder isKindOfClass:[NSTextView class]]) {
					[[firstResponder onMainThread] executeBundleItemForInputField:aMenuItem];
				}
			}
		}
	}
#endif
}

/**
 * Saves the new column size in the preferences.
 */
- (void)tableViewColumnDidResize:(NSNotification *)notification
{
	// Check our notification object is our table content view
	if ([notification object] != tableContentView) return;
	
	// Sometimes the column has no identifier. I can't figure out what is causing it, so we just skip over this item
	if (![[[notification userInfo] objectForKey:@"NSTableColumn"] identifier]) return;
	
	NSMutableDictionary *tableColumnWidths;
	NSString *database = [NSString stringWithFormat:@"%@@%@", [tableDocumentInstance database], [tableDocumentInstance host]];
	NSString *table = [tablesListInstance tableName];
	
	// Get tableColumnWidths object
#ifndef SP_CODA
	if ([prefs objectForKey:SPTableColumnWidths] != nil ) {
		tableColumnWidths = [NSMutableDictionary dictionaryWithDictionary:[prefs objectForKey:SPTableColumnWidths]];
	} 
	else {
#endif
		tableColumnWidths = [NSMutableDictionary dictionary];
#ifndef SP_CODA
	}
#endif
	
	// Get the database object
	if  ([tableColumnWidths objectForKey:database] == nil) {
		[tableColumnWidths setObject:[NSMutableDictionary dictionary] forKey:database];
	} 
	else {
		[tableColumnWidths setObject:[NSMutableDictionary dictionaryWithDictionary:[tableColumnWidths objectForKey:database]] forKey:database];
	}
	
	// Get the table object
	if  ([[tableColumnWidths objectForKey:database] objectForKey:table] == nil) {
		[[tableColumnWidths objectForKey:database] setObject:[NSMutableDictionary dictionary] forKey:table];
	} 
	else {
		[[tableColumnWidths objectForKey:database] setObject:[NSMutableDictionary dictionaryWithDictionary:[[tableColumnWidths objectForKey:database] objectForKey:table]] forKey:table];
	}
	
	// Save column size
	[[[tableColumnWidths objectForKey:database] objectForKey:table] 
	 setObject:[NSNumber numberWithDouble:[(NSTableColumn *)[[notification userInfo] objectForKey:@"NSTableColumn"] width]] 
	 forKey:[[[[notification userInfo] objectForKey:@"NSTableColumn"] headerCell] stringValue]];
#ifndef SP_CODA
	[prefs setObject:tableColumnWidths forKey:SPTableColumnWidths];
#endif
}

/**
 * Confirm whether to allow editing of a row. Returns YES by default, unless the multipleLineEditingButton is in
 * the ON state, or for blob or text fields - in those cases opens a sheet for editing instead and returns NO.
 */
- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if ([tableDocumentInstance isWorking]) return NO;
	
#ifndef SP_CODA
	if (tableView == filterTableView) {
		return (filterTableIsSwapped && [[tableColumn identifier] integerValue] == 0) ? NO : YES;
	}
	else 
#endif
		if (tableView == tableContentView) {
			
			// Nothing is editable while the field editor is running.
			// This guards against a special case where accessibility services might
			// check if a table field is editable while the sheet is running.
			if (fieldEditor) return NO;
			
			// Ensure that row is editable since it could contain "(not loaded)" columns together with
			// issue that the table has no primary key
			NSString *wherePart = [NSString stringWithString:[self argumentForRow:[tableContentView selectedRow]]];
			
			if (![wherePart length]) return NO;
			
			// If the selected cell hasn't been loaded, load it.
			if ([[tableValues cellDataAtRow:rowIndex column:[[tableColumn identifier] integerValue]] isSPNotLoaded]) {
				
				// Only get the data for the selected column, not all of them
				NSString *query = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@", [[[tableColumn headerCell] stringValue] backtickQuotedString], [selectedTable backtickQuotedString], wherePart];
				
				SPMySQLResult *tempResult = [mySQLConnection queryString:query];
				
				if (![tempResult numberOfRows]) {
					SPOnewayAlertSheet(
						NSLocalizedString(@"Error", @"error"),
						[tableDocumentInstance parentWindow],
						NSLocalizedString(@"Couldn't load the row. Reload the table to be sure that the row exists and use a primary key for your table.", @"message of panel when loading of row failed")
					);
					return NO;
				}
				
				NSArray *tempRow = [tempResult getRowAsArray];
				
				[tableValues replaceObjectInRow:rowIndex column:[[tableContentView tableColumns] indexOfObject:tableColumn] withObject:[tempRow objectAtIndex:0]];
				[tableContentView reloadData];
			}
			
			// Retrieve the column definition
			NSDictionary *columnDefinition = [cqColumnDefinition objectAtIndex:[[tableColumn identifier] integerValue]];
			
			// Open the editing sheet if required
			if ([tableContentView shouldUseFieldEditorForRow:rowIndex column:[[tableColumn identifier] integerValue] checkWithLock:NULL]) {
				
				BOOL isBlob = [tableDataInstance columnIsBlobOrText:[[tableColumn headerCell] stringValue]];
				
				// A table is per definition editable
				BOOL isFieldEditable = YES;
				
				// Check for Views if field is editable
				if ([tablesListInstance tableType] == SPTableTypeView) {
					NSArray *editStatus = [self fieldEditStatusForRow:rowIndex andColumn:[[tableColumn identifier] integerValue]];
					isFieldEditable = [[editStatus objectAtIndex:0] integerValue] == 1;
				}
				
				NSUInteger fieldLength = 0;
				NSString *fieldEncoding = nil;
				BOOL allowNULL = YES;
				
				NSString *fieldType = [columnDefinition objectForKey:@"type"];
				
				if ([columnDefinition objectForKey:@"char_length"]) {
					fieldLength = [[columnDefinition objectForKey:@"char_length"] integerValue];
				}
				
				if ([columnDefinition objectForKey:@"null"]) {
					allowNULL = (![[columnDefinition objectForKey:@"null"] integerValue]);
				}
				
				if ([columnDefinition objectForKey:@"charset_name"] && ![[columnDefinition objectForKey:@"charset_name"] isEqualToString:@"binary"]) {
					fieldEncoding = [columnDefinition objectForKey:@"charset_name"];
				}
				
				fieldEditor = [[SPFieldEditorController alloc] init];
				
				[fieldEditor setEditedFieldInfo:[NSDictionary dictionaryWithObjectsAndKeys:
												 [[tableColumn headerCell] stringValue], @"colName",
												 [self usedQuery], @"usedQuery",
												 @"content", @"tableSource",
												 nil]];
				
				[fieldEditor setTextMaxLength:fieldLength];
				[fieldEditor setFieldType:fieldType == nil ? @"" : fieldType];
				[fieldEditor setFieldEncoding:fieldEncoding == nil ? @"" : fieldEncoding];
				[fieldEditor setAllowNULL:allowNULL];
			
				id cellValue = [tableValues cellDataAtRow:rowIndex column:[[tableColumn identifier] integerValue]];
				
				if ([cellValue isNSNull]) {
					cellValue = [NSString stringWithString:[prefs objectForKey:SPNullValue]];
				}

				if ([self cellValueIsDisplayedAsHexForColumn:[[tableColumn identifier] integerValue]]) {
					[fieldEditor setTextMaxLength:[[self tableView:tableContentView objectValueForTableColumn:tableColumn row:rowIndex] length]];
					isFieldEditable = NO;
				}
				
				NSInteger editedColumn = 0;
				
				for (NSTableColumn* col in [tableContentView tableColumns]) 
				{
					if ([[col identifier] isEqualToString:[tableColumn identifier]]) break;
					
					editedColumn++;
				}
				
				[fieldEditor editWithObject:cellValue
								  fieldName:[[tableColumn headerCell] stringValue]
							  usingEncoding:[mySQLConnection stringEncoding]
							   isObjectBlob:isBlob
								 isEditable:isFieldEditable
								 withWindow:[tableDocumentInstance parentWindow]
									 sender:self
								contextInfo:[NSDictionary dictionaryWithObjectsAndKeys:
											 [NSNumber numberWithInteger:rowIndex], @"rowIndex",
											 [NSNumber numberWithInteger:editedColumn], @"columnIndex",
											 [NSNumber numberWithBool:isFieldEditable], @"isFieldEditable",
											 nil]];
				
				return NO;
			}
			
			return YES;
		}
	
	return YES;
}

/**
 * Enable drag from tableview
 */
- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rows toPasteboard:(NSPasteboard*)pboard
{
	if (tableView == tableContentView) {
		NSString *tmp;
		
		// By holding ⌘, ⇧, or/and ⌥ copies selected rows as SQL INSERTS
		// otherwise \t delimited lines
		if ([[NSApp currentEvent] modifierFlags] & (NSCommandKeyMask|NSShiftKeyMask|NSAlternateKeyMask)) {
			tmp = [tableContentView rowsAsSqlInsertsOnlySelectedRows:YES];
		}
		else {
			tmp = [tableContentView draggedRowsAsTabString];
		}

		if (tmp && [tmp length])
		{
			[pboard declareTypes:@[NSTabularTextPboardType, NSStringPboardType] owner:nil];
			
			[pboard setString:tmp forType:NSStringPboardType];
			[pboard setString:tmp forType:NSTabularTextPboardType];
			
			return YES;
		}
	}
	
	return NO;
}

/**
 * Disable row selection while the document is working.
 */
- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)rowIndex
{
#ifndef SP_CODA
	if (tableView == filterTableView) {
		return YES;
	}
	else 
#endif
		return tableView == tableContentView ? tableRowsSelectable : YES;
}

/**
 * Resize a column when it's double-clicked (10.6+ only).
 */
- (CGFloat)tableView:(NSTableView *)tableView sizeToFitWidthOfColumn:(NSInteger)columnIndex
{
	NSTableColumn *theColumn = [[tableView tableColumns] objectAtIndex:columnIndex];
	NSDictionary *columnDefinition = [dataColumns objectAtIndex:[[theColumn identifier] integerValue]];
	
	// Get the column width
	NSUInteger targetWidth = [tableContentView autodetectWidthForColumnDefinition:columnDefinition maxRows:500];
	
#ifndef SP_CODA
	// Clear any saved widths for the column
	NSString *dbKey = [NSString stringWithFormat:@"%@@%@", [tableDocumentInstance database], [tableDocumentInstance host]];
	NSString *tableKey = [tablesListInstance tableName];
	NSMutableDictionary *savedWidths = [NSMutableDictionary dictionaryWithDictionary:[prefs objectForKey:SPTableColumnWidths]];
	NSMutableDictionary *dbDict = [NSMutableDictionary dictionaryWithDictionary:[savedWidths objectForKey:dbKey]];
	NSMutableDictionary *tableDict = [NSMutableDictionary dictionaryWithDictionary:[dbDict objectForKey:tableKey]];
	
	if ([tableDict objectForKey:[columnDefinition objectForKey:@"name"]]) {
		[tableDict removeObjectForKey:[columnDefinition objectForKey:@"name"]];
		
		if ([tableDict count]) {
			[dbDict setObject:[NSDictionary dictionaryWithDictionary:tableDict] forKey:tableKey];
		} 
		else {
			[dbDict removeObjectForKey:tableKey];
		}
		
		if ([dbDict count]) {
			[savedWidths setObject:[NSDictionary dictionaryWithDictionary:dbDict] forKey:dbKey];
		} 
		else {
			[savedWidths removeObjectForKey:dbKey];
		}
		
		[prefs setObject:[NSDictionary dictionaryWithDictionary:savedWidths] forKey:SPTableColumnWidths];
	}
#endif
	
	// Return the width, while the delegate is empty to prevent column resize notifications
	[tableContentView setDelegate:nil];
	[tableContentView performSelector:@selector(setDelegate:) withObject:self afterDelay:0.1];
	
	return targetWidth;
}

/**
 * This function changes the text color of text/blob fields which are null or not yet loaded to gray
 */
- (void)tableView:(SPCopyTable *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
#ifndef SP_CODA
	if (tableView == filterTableView) {
		if (filterTableIsSwapped && [[tableColumn identifier] integerValue] == 0) {
			[cell setDrawsBackground:YES];
			[cell setBackgroundColor:lightGrayColor];
		} 
		else {
			[cell setDrawsBackground:NO];
		}
		
		return;
	}
	else 
#endif
		if (tableView == tableContentView) {
			
			if (![cell respondsToSelector:@selector(setTextColor:)]) return;
			
			BOOL cellIsNullOrUnloaded = NO;
			BOOL cellIsLinkCell = [cell isMemberOfClass:[SPTextAndLinkCell class]];

			NSUInteger columnIndex = [[tableColumn identifier] integerValue];
			
			// If user wants to edit 'cell' set text color to black and return to avoid
			// writing in gray if value was NULL
			if ([tableView editedColumn] != -1
				&& [tableView editedRow] == rowIndex
				&& (NSUInteger)[[NSArrayObjectAtIndex([tableView tableColumns], [tableView editedColumn]) identifier] integerValue] == columnIndex) {
				[cell setTextColor:blackColor];
				if (cellIsLinkCell) [cell setLinkActive:NO];
				return;
			}

			// While the table is being loaded, additional validation is required - data
			// locks must be used to avoid crashes, and indexes higher than the available
			// rows or columns may be requested.  Use gray to indicate loading in these cases.
			if (isWorking) {
				pthread_mutex_lock(&tableValuesLock);
				
				if (rowIndex < (NSInteger)tableRowsCount && columnIndex < [tableValues columnCount]) {
					cellIsNullOrUnloaded = [tableValues cellIsNullOrUnloadedAtRow:rowIndex column:columnIndex];
				}
				
				pthread_mutex_unlock(&tableValuesLock);
			} 
			else {
				cellIsNullOrUnloaded = [tableValues cellIsNullOrUnloadedAtRow:rowIndex column:columnIndex];
			}

			if (cellIsNullOrUnloaded) {
				[cell setTextColor:rowIndex == [tableContentView selectedRow] ? whiteColor : lightGrayColor];
			} 
			else {
				[cell setTextColor:blackColor];
			}
			
			if ([self cellValueIsDisplayedAsHexForColumn:[[tableColumn identifier] integerValue]]) {
				[cell setTextColor:rowIndex == [tableContentView selectedRow] ? whiteColor : blueColor];
			}

			// Disable link arrows for the currently editing row and for any NULL or unloaded cells
			if (cellIsLinkCell) {
				if (cellIsNullOrUnloaded || [tableView editedRow] == rowIndex) {
					[cell setLinkActive:NO];
				}
				else {
					[cell setLinkActive:YES];
				}
			}
		}
}

#ifndef SP_CODA
/**
 * Show the table cell content as tooltip
 * 
 * - for text displays line breaks and tabs as well
 * - if blob data can be interpret as image data display the image as  transparent thumbnail
 *   (up to now using base64 encoded HTML data).
 */
- (NSString *)tableView:(NSTableView *)tableView toolTipForCell:(id)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation
{
	if (tableView == filterTableView) {
		return nil;
	}
	else if (tableView == tableContentView) {
		
		if ([[aCell stringValue] length] < 2 || [tableDocumentInstance isWorking]) return nil;
		
		// Suppress tooltip if another toolip is already visible, mainly displayed by a Bundle command
		// TODO has to be improved
		for (id win in [NSApp orderedWindows]) 
		{
			if ([[[[win contentView] class] description] isEqualToString:@"WebView"]) return nil;
		}
		
		NSImage *image;
		
		NSPoint pos = [NSEvent mouseLocation];
		pos.y -= 20;
		
		id theValue = nil;
		
		// While the table is being loaded, additional validation is required - data
		// locks must be used to avoid crashes, and indexes higher than the available
		// rows or columns may be requested.  Return "..." to indicate loading in these
		// cases.
		if (isWorking) {
			pthread_mutex_lock(&tableValuesLock);
			
			if (row < (NSInteger)tableRowsCount && [[tableColumn identifier] integerValue] < (NSInteger)[tableValues columnCount]) {
				theValue = [[SPDataStorageObjectAtRowAndColumn(tableValues, row, [[tableColumn identifier] integerValue]) copy] autorelease];
			}
			
			pthread_mutex_unlock(&tableValuesLock);
			
			if (!theValue) theValue = @"...";
		} 
		else {
			theValue = SPDataStorageObjectAtRowAndColumn(tableValues, row, [[tableColumn identifier] integerValue]);
		}
		
		if (theValue == nil) return nil;
		
		if ([theValue isKindOfClass:[NSData class]]) {
			image = [[[NSImage alloc] initWithData:theValue] autorelease];
			
			if (image) {
				[SPTooltip showWithObject:image atLocation:pos ofType:@"image"];
				return nil;
			}
		}
		else if ([theValue isKindOfClass:[SPMySQLGeometryData class]]) {
			SPGeometryDataView *v = [[SPGeometryDataView alloc] initWithCoordinates:[theValue coordinates]];
			image = [v thumbnailImage];
			
			if (image) {
				[SPTooltip showWithObject:image atLocation:pos ofType:@"image"];
				[v release];
				return nil;
			}
			
			[v release];
		}
		
		// Show the cell string value as tooltip (including line breaks and tabs)
		// by using the cell's font
		[SPTooltip showWithObject:[aCell stringValue]
					   atLocation:pos
						   ofType:@"text"
				   displayOptions:[NSDictionary dictionaryWithObjectsAndKeys:
								   [[aCell font] familyName], @"fontname",
								   [NSString stringWithFormat:@"%f",[[aCell font] pointSize]], @"fontsize",
								   nil]];
		
		return nil;
	}
	
	return nil;
}
#endif

#ifndef SP_CODA /* SplitView delegate methods */

#pragma mark -
#pragma mark SplitView delegate methods

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	return NO;
}

/**
 * Set a minimum size for the filter text area.
 */
- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
	return proposedMax - 180;
}

/**
 * Set a minimum size for the field list and action area.
 */
- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
	return proposedMin + 225;
}

/**
 * Improve default resizing and resize only the filter text area by default.
 */
- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	NSSize newSize = [sender frame].size;
	NSView *leftView = [[sender subviews] objectAtIndex:0];
	NSView *rightView = [[sender subviews] objectAtIndex:1];
	float dividerThickness = [sender dividerThickness];
	NSRect leftFrame = [leftView frame];
	NSRect rightFrame = [rightView frame];
	
	// Resize height of both views
	leftFrame.size.height = newSize.height;
	rightFrame.size.height = newSize.height;
	
	// Only resize the right view's width - unless the constraint has been reached
	if (rightFrame.size.width > 180 || newSize.width > oldSize.width) {
		rightFrame.size.width = newSize.width - leftFrame.size.width - dividerThickness;
	} 
	else {
		leftFrame.size.width = newSize.width - rightFrame.size.width - dividerThickness;
	}
	
	rightFrame.origin.x = leftFrame.size.width + dividerThickness;	
	
	[leftView setFrame:leftFrame];
	[rightView setFrame:rightFrame];
}

#endif

#pragma mark -
#pragma mark Control delegate methods

- (void)controlTextDidChange:(NSNotification *)notification
{
#ifndef SP_CODA
	if ([notification object] == filterTableView) {
		
		NSString *string = [[[[notification userInfo] objectForKey:@"NSFieldEditor"] textStorage] string];
		
		if (string && [string length]) {
			if (lastEditedFilterTableValue) [lastEditedFilterTableValue release];
			
			lastEditedFilterTableValue = [[NSString stringWithString:string] retain];
		}
		
		[self updateFilterTableClause:string];
	}
#endif
}

/**
 * If the user selected a table cell which is a blob field and tried to edit it
 * cancel the inline edit, display the field editor sheet instead for editing
 * and re-enable inline editing after closing the sheet.
 */
- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)aFieldEditor
{	
	if (control != tableContentView) return YES;
	
	NSUInteger row, column;
	BOOL shouldBeginEditing = YES;
	
	row = [tableContentView editedRow];
	column = [tableContentView editedColumn];
	
	// If cell editing mode and editing request comes
	// from the keyboard show an error tooltip
	// or bypass if numberOfPossibleUpdateRows == 1
	if ([tableContentView isCellEditingMode]) {
		
		NSArray *editStatus = [self fieldEditStatusForRow:row andColumn:[[NSArrayObjectAtIndex([tableContentView tableColumns], column) identifier] integerValue]];
		NSInteger numberOfPossibleUpdateRows = [[editStatus objectAtIndex:0] integerValue];
		NSPoint pos = [[tableDocumentInstance parentWindow] convertBaseToScreen:[tableContentView convertPoint:[tableContentView frameOfCellAtColumn:column row:row].origin toView:nil]];
		
		pos.y -= 20;
		
		switch (numberOfPossibleUpdateRows) 
		{
			case -1:
				[SPTooltip showWithObject:kCellEditorErrorNoMultiTabDb
							   atLocation:pos
								   ofType:@"text"];
				shouldBeginEditing = NO;
				break;
			case 0:
				[SPTooltip showWithObject:[NSString stringWithFormat:kCellEditorErrorNoMatch, selectedTable]
							   atLocation:pos
								   ofType:@"text"];
				shouldBeginEditing = NO;
				break;
			case 1:
				shouldBeginEditing = YES;
				break;
			default:
				[SPTooltip showWithObject:[NSString stringWithFormat:kCellEditorErrorTooManyMatches, (long)numberOfPossibleUpdateRows]
							   atLocation:pos
								   ofType:@"text"];
				shouldBeginEditing = NO;
		}
		
	}
	
	// Open the field editor sheet if required
	if ([tableContentView shouldUseFieldEditorForRow:row column:column checkWithLock:NULL])
	{
		[tableContentView setFieldEditorSelectedRange:[aFieldEditor selectedRange]];
		
		// Cancel editing
		[control abortEditing];
		
		NSAssert(fieldEditor == nil, @"Method should not to be called while a field editor sheet is open!");
		// Call the field editor sheet
		[self tableView:tableContentView shouldEditTableColumn:NSArrayObjectAtIndex([tableContentView tableColumns], column) row:row];
		
		// send current event to field editor sheet
		if ([NSApp currentEvent]) {
			[NSApp sendEvent:[NSApp currentEvent]];
		}
		
		return NO;
	}
	
	return shouldBeginEditing;
}

/**
 * Trap the enter, escape, tab and arrow keys, overriding default behaviour and continuing/ending editing,
 * only within the current row.
 */
- (BOOL)control:(NSControl<NSControlTextEditingDelegate> *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	// Check firstly if SPCopyTable can handle command
	if ([control control:control textView:textView doCommandBySelector:command])
		return YES;
	
	// Trap the escape key
	if ([[control window] methodForSelector:command] == [[control window] methodForSelector:@selector(cancelOperation:)]) {
		// Abort editing
		[control abortEditing];
		
		if ((SPCopyTable*)control == tableContentView) {
			[self cancelRowEditing];
		}
		
		return YES;
	}
	
	return NO;
}

#pragma mark -
#pragma mark Database content view delegate methods

- (NSString *)usedQuery
{
	return usedQuery;
}

/**
 * Retrieve the data column definitions
 */
- (NSArray *)dataColumnDefinitions
{
	return dataColumns;
}

@end
