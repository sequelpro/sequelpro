//
//  $Id$
//
//  SPCopyTable.m
//  sequel-pro
//
//  Created by Stuart Glenn on Wed Apr 21 2004.
//  Changed by Lorenz Textor on Sat Nov 13 2004
//  Copyright (c) 2004 Stuart Glenn. All rights reserved.
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

#import <MCPKit/MCPKit.h>

#import "SPCopyTable.h"
#import "SPArrayAdditions.h"
#import "SPStringAdditions.h"
#import "SPTableContent.h"
#import "SPTableTriggers.h"
#import "SPTableRelations.h"
#import "SPCustomQuery.h"
#import "SPNotLoaded.h"
#import "SPConstants.h"
#import "SPDataStorage.h"
#import "SPTextAndLinkCell.h"

NSInteger MENU_EDIT_COPY             = 2001;
NSInteger MENU_EDIT_COPY_WITH_COLUMN = 2002;
NSInteger MENU_EDIT_COPY_AS_SQL      = 2003;

@implementation SPCopyTable

- (void)copy:(id)sender
{
	NSString *tmp = nil;

	if([sender tag] == MENU_EDIT_COPY_AS_SQL) {
		tmp = [self selectedRowsAsSqlInserts];
		if ( nil != tmp )
		{
			NSPasteboard *pb = [NSPasteboard generalPasteboard];

			[pb declareTypes:[NSArray arrayWithObjects: NSStringPboardType, nil]
					   owner:nil];

			[pb setString:tmp forType:NSStringPboardType];
		}
	} else {
		tmp = [self selectedRowsAsTabStringWithHeaders:([sender tag] == MENU_EDIT_COPY_WITH_COLUMN)];
		if ( nil != tmp )
		{
			NSPasteboard *pb = [NSPasteboard generalPasteboard];

			[pb declareTypes:[NSArray arrayWithObjects: NSTabularTextPboardType,
				NSStringPboardType, nil]
					   owner:nil];

			[pb setString:tmp forType:NSStringPboardType];
			[pb setString:tmp forType:NSTabularTextPboardType];
		}
	}
}

/*
 * Cell editing in SPCustomQuery or for views in SPTableContent
 */
- (BOOL)isCellEditingMode
{

	return ([[self delegate] isKindOfClass:[SPCustomQuery class]] 
		|| ([[self delegate] isKindOfClass:[SPTableContent class]] 
				&& [[self delegate] valueForKeyPath:@"tablesListInstance"] 
				&& [[[self delegate] valueForKeyPath:@"tablesListInstance"] tableType] == SPTableTypeView));

}

/*
 * Check if current edited cell represents a class other than a normal NSString
 * like pop-up menus for enum or set
 */
- (BOOL)isCellComplex
{

	return (![[self preparedCellAtColumn:[self editedColumn] row:[self editedRow]] isKindOfClass:[SPTextAndLinkCell class]]);

}

/*
 * Trap the enter, escape, tab and arrow keys, overriding default behaviour and continuing/ending editing,
 * only within the current row.
 */
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{


	NSUInteger row, column;

	row = [self editedRow];
	column = [self editedColumn];

	// Trap tab key
	// -- for handling of blob fields and to check if it's editable look at [[self delegate] control:textShouldBeginEditing:]
	if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(insertTab:)] )
	{
		[[control window] makeFirstResponder:control];

		// Save the current line if it's the last field in the table
		if ( [self numberOfColumns] - 1 == column) {
			if([[self delegate] respondsToSelector:@selector(addRowToDB)])
				[[self delegate] addRowToDB];
			[[self window] makeFirstResponder:self];
		} else {
			// Select the next field for editing
			[self editColumn:column+1 row:row withEvent:nil select:YES];
		}

		return YES;
	}

	// Trap shift-tab key
	else if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(insertBacktab:)] )
	{
		[[control window] makeFirstResponder:control];

		// Save the current line if it's the last field in the table
		if ( column < 1 ) {
			if([[self delegate] respondsToSelector:@selector(addRowToDB)])
				[[self delegate] addRowToDB];
			[[self window] makeFirstResponder:self];
		} else {
			// Select the previous field for editing
			[self editColumn:column-1 row:row withEvent:nil select:YES];
		}

		return YES;
	}

	// Trap enter key
	else if (  [textView methodForSelector:command] == [textView methodForSelector:@selector(insertNewline:)] )
	{
		// If enum field is edited RETURN selects the new value instead of saving the entire row
		if([self isCellComplex])
			return YES;

		[[control window] makeFirstResponder:control];
		if([[self delegate] isKindOfClass:[SPTableContent class]] && ![self isCellEditingMode] && [[self delegate] respondsToSelector:@selector(addRowToDB)])
			[[self delegate] addRowToDB];
		return YES;

	}

	// Trap down arrow key
	else if (  [textView methodForSelector:command] == [textView methodForSelector:@selector(moveDown:)] )
	{

		// If enum field is edited ARROW key navigates through the popup list
		if([self isCellComplex])
			return NO;

		NSUInteger newRow = row+1;
		if (newRow>=[[self delegate] numberOfRowsInTableView:self]) return YES; //check if we're already at the end of the list

		[[control window] makeFirstResponder:control];
		if([[self delegate] isKindOfClass:[SPTableContent class]] && ![self isCellEditingMode] && [[self delegate] respondsToSelector:@selector(addRowToDB)])
			[[self delegate] addRowToDB];

		if (newRow>=[[self delegate] numberOfRowsInTableView:self]) return YES; //check again. addRowToDB could reload the table and change the number of rows
		if (column>=[tableStorage columnCount]) return YES; //the column count could change too

		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
		[self editColumn:column row:newRow withEvent:nil select:YES];
		return YES;
	}

	// Trap up arrow key
	else if (  [textView methodForSelector:command] == [textView methodForSelector:@selector(moveUp:)] )
	{

		// If enum field is edited ARROW key navigates through the popup list
		if([self isCellComplex])
			return NO;

		if (row==0) return YES; //already at the beginning of the list
		NSUInteger newRow = row-1;

		[[control window] makeFirstResponder:control];
		if([[self delegate] isKindOfClass:[SPTableContent class]] && ![self isCellEditingMode] && [[self delegate] respondsToSelector:@selector(addRowToDB)])
			[[self delegate] addRowToDB];

		if (newRow>=[[self delegate] numberOfRowsInTableView:self]) return YES; // addRowToDB could reload the table and change the number of rows
		if (column>=[tableStorage columnCount]) return YES; //the column count could change too

		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
		[self editColumn:column row:newRow withEvent:nil select:YES];
		return YES;
	}

	return NO;
}


//allow for drag-n-drop out of the application as a copy
- (NSUInteger)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return NSDragOperationCopy;
}

/**
 * Only have the copy menu item enabled when row(s) are selected in
 * supported tables.
 */
- (BOOL)validateMenuItem:(NSMenuItem*)anItem
{
	NSInteger menuItemTag = [anItem tag];

	// Don't validate anything other than the copy commands
	if (menuItemTag != MENU_EDIT_COPY && menuItemTag != MENU_EDIT_COPY_WITH_COLUMN && menuItemTag != MENU_EDIT_COPY_AS_SQL) {
		return YES;
	}

	// Don't enable menus for relations or triggers - no action to take yet
	if ([[self delegate] isKindOfClass:[SPTableRelations class]] || [[self delegate] isKindOfClass:[SPTableTriggers class]]) {
		return NO;
	}

	// Enable the Copy [with column names] commands if a row is selected
	if (menuItemTag == MENU_EDIT_COPY || menuItemTag == MENU_EDIT_COPY_WITH_COLUMN) {
		return ([self numberOfSelectedRows] > 0);
	}

	// Enable the Copy as SQL commands if rows are selected and column definitions are available
	if (menuItemTag == MENU_EDIT_COPY_AS_SQL) {
		return (columnDefinitions != nil && [self numberOfSelectedRows] > 0);
	}

	return NO;
}

//get selected rows a string of newline separated lines of tab separated fields
//the value in each field is from the objects description method
- (NSString *)selectedRowsAsTabStringWithHeaders:(BOOL)withHeaders
{
	if ([self numberOfSelectedRows] == 0) return nil;

	NSIndexSet *selectedRows = [self selectedRowIndexes];

	NSArray *columns = [self tableColumns];
	NSUInteger numColumns = [columns count];
	NSMutableString *result = [NSMutableString stringWithCapacity:2000];

	// Add the table headers if requested to do so
	if (withHeaders) {
		NSUInteger i;
		for( i = 0; i < numColumns; i++ ){
			[result appendFormat:@"%@\t", [[NSArrayObjectAtIndex(columns, i) headerCell] stringValue]];
		}
		[result appendString:@"\n"];
	}

	NSUInteger c;
	id cellData = nil;

	// Create an array of table column mappings for fast iteration
	NSUInteger *columnMappings = malloc(numColumns * sizeof(NSUInteger));
	for ( c = 0; c < numColumns; c++) {
		columnMappings[c] = [[[columns objectAtIndex:c] identifier] unsignedIntValue];
	}

	// Loop through the rows, adding their descriptive contents
	NSUInteger rowIndex = [selectedRows firstIndex];
	NSString * nullString = [prefs objectForKey:SPNullValue];
	NSStringEncoding connectionEncoding = [mySQLConnection encoding];
	while ( rowIndex != NSNotFound )
	{
		for ( c = 0; c < numColumns; c++) {
			cellData = SPDataStorageObjectAtRowAndColumn(tableStorage, rowIndex, columnMappings[c]);

			// Copy the shown representation of the cell - custom NULL display strings, (not loaded),
			// and the string representation of any blobs or binary texts.
			if (cellData) {
				if ([cellData isNSNull])
					[result appendFormat:@"%@\t", nullString];
				else if ([cellData isSPNotLoaded])
					[result appendFormat:@"%@\t", NSLocalizedString(@"(not loaded)", @"value shown for hidden blob and text fields")];
				else if ([cellData isKindOfClass:[NSData class]]) {
					NSString *displayString = [[NSString alloc] initWithData:cellData encoding:[mySQLConnection stringEncoding]];
					if (!displayString) displayString = [[NSString alloc] initWithData:cellData encoding:NSASCIIStringEncoding];
					if (displayString) {
						[result appendFormat:@"%@\t", displayString];
						[displayString release];
					}
				} else
					[result appendFormat:@"%@\t", [cellData description]];
			} else {
				[result appendString:@"\t"];
			}
		}

		// Remove the trailing tab and add the linebreak
		if ([result length]){
			[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
		}
		[result appendString:@"\n"];

		// Select the next row index
		rowIndex = [selectedRows indexGreaterThanIndex:rowIndex];
	}

	// Remove the trailing line end
	if ([result length]) {
		[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
	}

	free(columnMappings);

	return result;
}

/*
 * Return selected rows as SQL INSERT INTO `foo` VALUES (baz) string.
 * If no selected table name is given `<table>` will be used instead.
 */
- (NSString *)selectedRowsAsSqlInserts
{

	if ( [self numberOfSelectedRows] < 1 ) return nil;

	NSArray *columns         = [self tableColumns];
	NSUInteger numColumns    = [columns count];

	NSIndexSet *selectedRows = [self selectedRowIndexes];
	NSMutableString *value   = [NSMutableString stringWithCapacity:10];

	id cellData = nil;

	NSUInteger rowCounter = 0;
	NSUInteger penultimateRowIndex = [selectedRows count];
	NSUInteger c;
	NSUInteger valueLength = 0;

	NSMutableString *result = [NSMutableString stringWithCapacity:2000];

	// Create an array of table column names
	NSMutableArray *tbHeader = [NSMutableArray arrayWithCapacity:numColumns];
	for (id enumObj in columns) {
		[tbHeader addObject:[[enumObj headerCell] stringValue]];
	}

	// Create arrays of table column mappings and types for fast iteration
	NSUInteger *columnMappings = malloc(numColumns * sizeof(NSUInteger));
	NSUInteger *columnTypes = malloc(numColumns * sizeof(NSUInteger));
	for ( c = 0; c < numColumns; c++) {
		columnMappings[c] = [[[columns objectAtIndex:c] identifier] unsignedIntValue];

		NSString *t = [[columnDefinitions objectAtIndex:columnMappings[c]] objectForKey:@"typegrouping"];

		// Numeric data
		if ([t isEqualToString:@"bit"] || [t isEqualToString:@"integer"] || [t isEqualToString:@"float"])
			columnTypes[c] = 0;

		// Blob data or long text data
		else if ([t isEqualToString:@"blobdata"] || [t isEqualToString:@"textdata"])
			columnTypes[c] = 2;

		// Default to strings
		else
			columnTypes[c] = 1;
	}

	// Begin the SQL string
	[result appendFormat:@"INSERT INTO %@ (%@)\nVALUES\n",
		[(selectedTable == nil)?@"<table>":selectedTable backtickQuotedString], [tbHeader componentsJoinedAndBacktickQuoted]];

	NSUInteger rowIndex = [selectedRows firstIndex];
	Class spTableContentClass = [SPTableContent class];
	Class nsDataClass = [NSData class];
	while ( rowIndex != NSNotFound )
	{
		[value appendString:@"\t("];
		cellData = nil;
		rowCounter++;
		for ( c = 0; c < numColumns; c++ )
		{
			cellData = SPDataStorageObjectAtRowAndColumn(tableStorage, rowIndex, columnMappings[c]);

			// If the data is not loaded, attempt to fetch the value
			if ([cellData isSPNotLoaded] && [[self delegate] isKindOfClass:spTableContentClass]) {

				// Abort if no table name given, not table content, or if there are no indices on this table
				if (!selectedTable || ![[self delegate] isKindOfClass:spTableContentClass] || ![[tableInstance argumentForRow:rowIndex] length]) {
					NSBeep();
					free(columnMappings);
					free(columnTypes);
					return nil;
				}

				// Use the argumentForRow to retrieve the missing information
				// TODO - this could be preloaded for all selected rows rather than cell-by-cell
				cellData = [mySQLConnection getFirstFieldFromQuery:
							[NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@",
								[NSArrayObjectAtIndex(tbHeader, columnMappings[c]) backtickQuotedString],
								[selectedTable backtickQuotedString],
								[tableInstance argumentForRow:rowIndex]]];
			}

			// Check for NULL value
			if ([cellData isNSNull]) {
				[value appendString:@"NULL, "];
				continue;

			} else if (cellData) {

				// Check column type and insert the data accordingly
				switch(columnTypes[c]) {

					// Convert numeric types to unquoted strings
					case 0:
						[value appendFormat:@"%@, ", [cellData description]];
						break;

					// Quote string, text and blob types appropriately
					case 1:
					case 2:
						if ([cellData isKindOfClass:nsDataClass]) {
							[value appendFormat:@"X'%@', ", [mySQLConnection prepareBinaryData:cellData]];
						} else {
							[value appendFormat:@"'%@', ", [mySQLConnection prepareString:[cellData description]]];
						}
						break;

					// Unhandled cases - abort
					default:
						NSBeep();
						free(columnMappings);
						free(columnTypes);
						return nil;
				}

			// If nil is encountered, abort
			} else {
				NSBeep();
				free(columnMappings);
				free(columnTypes);
				return nil;
			}
		}

		// Remove the trailing ', ' from the query
		if ( [value length] > 2 )
			[value deleteCharactersInRange:NSMakeRange([value length]-2, 2)];

		valueLength += [value length];

		// Close this VALUES group and set up the next one if appropriate
		if ( rowCounter != penultimateRowIndex ) {

			// Add a new INSERT starter command every ~250k of data.
			if ( valueLength > 250000 ) {
				[result appendFormat:@"%@);\n\nINSERT INTO %@ (%@)\nVALUES\n", value, [(selectedTable == nil)?@"<table>":selectedTable backtickQuotedString], [tbHeader componentsJoinedAndBacktickQuoted]];
				[value setString:@""];
				valueLength = 0;
			} else {
				[value appendString:@"),\n"];
			}

		} else {
			[value appendString:@"),\n"];
			[result appendString:value];
		}

		// Get the next selected row index
		rowIndex = [selectedRows indexGreaterThanIndex:rowIndex];

	}

	// Remove the trailing ",\n" from the query string
	if ( [result length] > 3 )
		[result deleteCharactersInRange:NSMakeRange([result length]-2, 2)];

	[result appendString:@";\n"];

	free(columnMappings);
	free(columnTypes);

	return result;
}


//get dragged rows a string of newline separated lines of tab separated fields
//the value in each field is from the objects description method
- (NSString *)draggedRowsAsTabString
{
	NSArray *columns = [self tableColumns];
	NSUInteger numColumns = [columns count];
	NSIndexSet *selectedRows = [self selectedRowIndexes];

	NSMutableString *result = [NSMutableString stringWithCapacity:2000];
	NSUInteger c;
	id cellData = nil;

	// Create an array of table column mappings for fast iteration
	NSUInteger *columnMappings = malloc(numColumns * sizeof(NSUInteger));
	for ( c = 0; c < numColumns; c++) {
		columnMappings[c] = [[[columns objectAtIndex:c] identifier] unsignedIntValue];
	}

	// Loop through the rows, adding their descriptive contents
	NSUInteger rowIndex = [selectedRows firstIndex];
	NSString *nullString = [prefs objectForKey:SPNullValue];
	Class nsDataClass = [NSData class];
	NSStringEncoding connectionEncoding = [mySQLConnection stringEncoding];
	while ( rowIndex != NSNotFound )
	{
		for ( c = 0; c < numColumns; c++) {
			cellData = SPDataStorageObjectAtRowAndColumn(tableStorage, rowIndex, columnMappings[c]);

			// Copy the shown representation of the cell - custom NULL display strings, (not loaded),
			// and the string representation of any blobs or binary texts.
			if (cellData) {
				if ([cellData isNSNull])
					[result appendFormat:@"%@\t", nullString];
				else if ([cellData isSPNotLoaded])
					[result appendFormat:@"%@\t", NSLocalizedString(@"(not loaded)", @"value shown for hidden blob and text fields")];
				else if ([cellData isKindOfClass:nsDataClass]) {
					NSString *displayString = [[NSString alloc] initWithData:cellData encoding:connectionEncoding];
					if (!displayString) displayString = [[NSString alloc] initWithData:cellData encoding:NSASCIIStringEncoding];
					if (displayString) {
						[result appendString:displayString];
						[displayString release];
					}
				} else
					[result appendFormat:@"%@\t", [cellData description]];
			} else {
				[result appendString:@"\t"];
			}
		}

		if ([result length]) {
			[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
		}

		[result appendString:@"\n"];

		// Retrieve the next selected row index
		rowIndex = [selectedRows indexGreaterThanIndex:rowIndex];
	}

	// Trim the trailing line ending
	if ([result length]) {
		[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
	}

	free(columnMappings);

	return result;
}

/**
 * Init self with data coming from the table content view. Mainly used for copying data properly.
 */
- (void)setTableInstance:(id)anInstance withTableData:(SPDataStorage *)theTableStorage withColumns:(NSArray *)columnDefs withTableName:(NSString *)aTableName withConnection:(id)aMySqlConnection
{
	selectedTable     = aTableName;
	mySQLConnection   = aMySqlConnection;
	tableInstance     = anInstance;
	tableStorage	  = theTableStorage;

	if (columnDefinitions) [columnDefinitions release];
	columnDefinitions = [[NSArray alloc] initWithArray:columnDefs];
}

/*
 * Update the table storage location if necessary.
 */
- (void)setTableData:(SPDataStorage *)theTableStorage
{
	tableStorage = theTableStorage;
}

/**
 * Autodetect column widths for a specified font.
 */
- (NSDictionary *) autodetectColumnWidths
{
	NSMutableDictionary *columnWidths = [NSMutableDictionary dictionaryWithCapacity:[columnDefinitions count]];
	NSUInteger columnWidth;
	NSUInteger allColumnWidths = 0;

	for (NSDictionary *columnDefinition in columnDefinitions) {
		if ([[NSThread currentThread] isCancelled]) return nil;

		columnWidth = [self autodetectWidthForColumnDefinition:columnDefinition maxRows:100];
		[columnWidths setObject:[NSNumber numberWithUnsignedInteger:columnWidth] forKey:[columnDefinition objectForKey:@"datacolumnindex"]];
		allColumnWidths += columnWidth;
	}

	// Compare the column widths to the table width.  If wider, narrow down wide columns as necessary
	if (allColumnWidths > [self bounds].size.width) {
		NSUInteger availableWidthToReduce = 0;

		// Look for columns that are wider than the multi-column max
		for (NSString *columnIdentifier in columnWidths) {
			columnWidth = [[columnWidths objectForKey:columnIdentifier] unsignedIntegerValue];
			if (columnWidth > SP_MAX_CELL_WIDTH_MULTICOLUMN) availableWidthToReduce += columnWidth - SP_MAX_CELL_WIDTH_MULTICOLUMN;
		}

		// Determine how much width can be reduced
		NSUInteger widthToReduce = allColumnWidths - [self bounds].size.width;
		if (availableWidthToReduce < widthToReduce) widthToReduce = availableWidthToReduce;

		// Proportionally decrease the column sizes
		if (widthToReduce) {
			NSArray *columnIdentifiers = [columnWidths allKeys];
			for (NSString *columnIdentifier in columnIdentifiers) {
				columnWidth = [[columnWidths objectForKey:columnIdentifier] unsignedIntegerValue];
				if (columnWidth > SP_MAX_CELL_WIDTH_MULTICOLUMN) {
					columnWidth -= ceil((double)(columnWidth - SP_MAX_CELL_WIDTH_MULTICOLUMN) / availableWidthToReduce * widthToReduce);
					[columnWidths setObject:[NSNumber numberWithUnsignedInteger:columnWidth] forKey:columnIdentifier];
				}
			}
		}
	}

	return columnWidths;
}

/**
 * Autodetect the column width for a specified column - derived from the supplied
 * column definition, using the stored data and the specified font.
 */
- (NSUInteger)autodetectWidthForColumnDefinition:(NSDictionary *)columnDefinition maxRows:(NSUInteger)rowsToCheck
{
	CGFloat columnBaseWidth;
	id contentString;
	NSUInteger cellWidth, maxCellWidth, i;
	NSRange linebreakRange;
	double rowStep;
	NSFont *tableFont = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPGlobalResultTableFont]];
	NSUInteger columnIndex = [[columnDefinition objectForKey:@"datacolumnindex"] unsignedIntegerValue];
	NSDictionary *stringAttributes = [NSDictionary dictionaryWithObject:tableFont forKey:NSFontAttributeName];

	// Check the number of rows available to check, sampling every n rows
	if ([tableStorage count] < rowsToCheck) {
		rowStep = 1;
	} else {
		rowStep = floor([tableStorage count] / rowsToCheck);
	}
	rowsToCheck = [tableStorage count];

	// Set a default padding for this column
	columnBaseWidth = 24;

	// Iterate through the data store rows, checking widths
	maxCellWidth = 0;
	for (i = 0; i < rowsToCheck; i += rowStep) {

		// Retrieve the cell's content
		contentString = [tableStorage cellDataAtRow:i column:columnIndex];

		// Replace NULLs with their placeholder string
		if ([contentString isNSNull]) {
			contentString = [prefs objectForKey:SPNullValue];

		// Same for cells for which loading has been deferred - likely blobs
		} else if ([contentString isSPNotLoaded]) {
			contentString = NSLocalizedString(@"(not loaded)", @"value shown for hidden blob and text fields");

		} else {

			// Otherwise, ensure the cell is represented as a short string
			if ([contentString isKindOfClass:[NSData class]]) {
				contentString = [contentString shortStringRepresentationUsingEncoding:[mySQLConnection stringEncoding]];
			} else if ([contentString length] > 500) {
				contentString = [contentString substringToIndex:500];
			}

			// If any linebreaks are present, use only the visible part of the string
			linebreakRange = [contentString rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]];
			if (linebreakRange.location != NSNotFound) {
				contentString = [contentString substringToIndex:linebreakRange.location];
			}
		}

		// Calculate the width, using it if it's higher than the current stored width
		cellWidth = [contentString sizeWithAttributes:stringAttributes].width;
		if (cellWidth > maxCellWidth) maxCellWidth = cellWidth;
		if (maxCellWidth > SP_MAX_CELL_WIDTH) {
			maxCellWidth = SP_MAX_CELL_WIDTH;
			break;
		}
	}

	// If the column has a foreign key link, expand the width; and also for enums
	if ([columnDefinition objectForKey:@"foreignkeyreference"]) {
		maxCellWidth += 18;
	} else if ([[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"enum"]) {
		maxCellWidth += 8;
	}

	// Add the padding
	maxCellWidth += columnBaseWidth;

	// If the header width is wider than this expanded width, use it instead
	cellWidth = [[columnDefinition objectForKey:@"name"] sizeWithAttributes:[NSDictionary dictionaryWithObject:[NSFont labelFontOfSize:[NSFont smallSystemFontSize]] forKey:NSFontAttributeName]].width;
	if (cellWidth + 10 > maxCellWidth) maxCellWidth = cellWidth + 10;

	return maxCellWidth;
}

- (void)keyDown:(NSEvent *)theEvent
{

	// RETURN or ENTER invoke editing mode for selected row
	// by calling tableView:shouldEditTableColumn: to validate
	if([self numberOfSelectedRows] == 1 && ([theEvent keyCode] == 36 || [theEvent keyCode] == 76)) {

		for(id item in [self tableColumns]) {
			// Run in fieldEditorMode?
			if(![[self delegate] tableView:self shouldEditTableColumn:item row:[self selectedRow]])
				;
			else {
				[self editColumn:0 row:[self selectedRow] withEvent:nil select:YES];
				break;
			}
		}

		return;
	}

	// Check if ESCAPE is hit and use it to cancel row editing if supported
	else if ([theEvent keyCode] == 53 && [[self delegate] respondsToSelector:@selector(cancelRowEditing)])
	{
		if ([[self delegate] cancelRowEditing]) return;
	}
	

	[super keyDown:theEvent];
}

#pragma mark -

- (void) awakeFromNib
{
	columnDefinitions = nil;
	prefs = [[NSUserDefaults standardUserDefaults] retain];

	if ([NSTableView instancesRespondToSelector:@selector(awakeFromNib)]) {
		[super awakeFromNib] ;
	}
}

- (void) dealloc
{
	if (columnDefinitions) [columnDefinitions release];
	[prefs release];

	[super dealloc];
}

@end
