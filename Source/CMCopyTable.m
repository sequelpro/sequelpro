//
//  $Id$
//
//  CMCopyTable.m
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

#import "CMCopyTable.h"
#import "SPArrayAdditions.h"
#import "SPStringAdditions.h"
#import "TableContent.h"
#import "SPTableTriggers.h"
#import "SPTableRelations.h"
#import "CustomQuery.h"
#import "SPNotLoaded.h"
#import "SPConstants.h"
#import "SPDataStorage.h"

NSInteger MENU_EDIT_COPY             = 2001;
NSInteger MENU_EDIT_COPY_WITH_COLUMN = 2002;
NSInteger MENU_EDIT_COPY_AS_SQL      = 2003;

@implementation CMCopyTable

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
			[result appendString:[NSString stringWithFormat:@"%@\t", [[NSArrayObjectAtIndex(columns, i) headerCell] stringValue]]];
		}
		[result appendString:[NSString stringWithFormat:@"\n"]];
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
	while ( rowIndex != NSNotFound )
	{ 
		for ( c = 0; c < numColumns; c++) {
			cellData = SPDataStorageObjectAtRowAndColumn(tableStorage, rowIndex, columnMappings[c]);

			// Copy the shown representation of the cell - custom NULL display strings, (not loaded),
			// and the string representation of any blobs or binary texts.
			if (cellData) {
				if ([cellData isNSNull])
					[result appendString:[NSString	stringWithFormat:@"%@\t", [prefs objectForKey:SPNullValue]]];
				else if ([cellData isSPNotLoaded])
					[result appendString:[NSString	stringWithFormat:@"%@\t", NSLocalizedString(@"(not loaded)", @"value shown for hidden blob and text fields")]];
				else if ([cellData isKindOfClass:[NSData class]]) {
					NSString *displayString = [[NSString alloc] initWithData:cellData encoding:[mySQLConnection encoding]];
					if (!displayString) displayString = [[NSString alloc] initWithData:cellData encoding:NSASCIIStringEncoding];
					if (displayString) {
						[result appendString:displayString];
						[displayString release];
					}
				} else
					[result appendString:[NSString stringWithFormat:@"%@\t", [cellData description]]];
			} else {
				[result appendString:@"\t"];
			}
		}
		
		if ([result length]){
			[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
		}
		[result appendString:[NSString stringWithFormat:@"\n"]];

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
	[result appendString:[NSString stringWithFormat:@"INSERT INTO %@ (%@)\nVALUES\n", 
		[(selectedTable == nil)?@"<table>":selectedTable backtickQuotedString], [tbHeader componentsJoinedAndBacktickQuoted]]];

	NSUInteger rowIndex = [selectedRows firstIndex];
	while ( rowIndex != NSNotFound )
	{
		[value appendString:@"\t("];
		cellData = nil;
		rowCounter++;
		for ( c = 0; c < numColumns; c++ )
		{
			cellData = SPDataStorageObjectAtRowAndColumn(tableStorage, rowIndex, columnMappings[c]);

			// If the data is not loaded, attempt to fetch the value
			if ([cellData isSPNotLoaded] && [[self delegate] isKindOfClass:[TableContent class]]) {

				// Abort if no table name given, not table content, or if there are no indices on this table
				if (!selectedTable || ![[self delegate] isKindOfClass:[TableContent class]] || ![[tableInstance argumentForRow:rowIndex] length]) {
					NSBeep();
					free(columnMappings);
					free(columnTypes);
					return nil;
				}

				// Use the argumentForRow to retrieve the missing information
				// TODO - this could be preloaded for all selected rows rather than cell-by-cell
				cellData = [mySQLConnection getFirstFieldFromQuery:
							[NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@",
								[[tbHeader objectAtIndex:columnMappings[c]] backtickQuotedString],
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
						[value appendString:[NSString stringWithFormat:@"%@, ", [cellData description]]];
						break;

					// Quote string, text and blob types appropriately
					case 1:
					case 2:
						if ([cellData isKindOfClass:[NSData class]]) {
							[value appendString:[NSString stringWithFormat:@"X'%@', ", [mySQLConnection prepareBinaryData:cellData]]];
						} else {
							[value appendString:[NSString stringWithFormat:@"'%@', ", [mySQLConnection prepareString:[cellData description]]]];
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
				[result appendString:value];
				[result appendString:[NSString stringWithFormat:@");\n\nINSERT INTO %@ (%@)\nVALUES\n", 
					[(selectedTable == nil)?@"<table>":selectedTable backtickQuotedString], [tbHeader componentsJoinedAndBacktickQuoted]]];
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
	while ( rowIndex != NSNotFound )
	{ 
		for ( c = 0; c < numColumns; c++) {
			cellData = SPDataStorageObjectAtRowAndColumn(tableStorage, rowIndex, columnMappings[c]);
			
			// Copy the shown representation of the cell - custom NULL display strings, (not loaded),
			// and the string representation of any blobs or binary texts.
			if (cellData) {
				if ([cellData isNSNull])
					[result appendString:[NSString	stringWithFormat:@"%@\t", [prefs objectForKey:SPNullValue]]];
				else if ([cellData isSPNotLoaded])
					[result appendString:[NSString	stringWithFormat:@"%@\t", NSLocalizedString(@"(not loaded)", @"value shown for hidden blob and text fields")]];
				else if ([cellData isKindOfClass:[NSData class]]) {
					NSString *displayString = [[NSString alloc] initWithData:cellData encoding:[mySQLConnection encoding]];
					if (!displayString) displayString = [[NSString alloc] initWithData:cellData encoding:NSASCIIStringEncoding];
					if (displayString) {
						[result appendString:displayString];
						[displayString release];
					}
				} else
					[result appendString:[NSString stringWithFormat:@"%@\t", [cellData description]]];
			} else {
				[result appendString:@"\t"];
			}
		}

		if ([result length]) {
			[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
		}
		
		[result appendString:[NSString stringWithFormat:@"\n"]];

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


- (void)keyDown:(NSEvent *)theEvent
{
	// RETURN or ENTER invoke editing mode for selected row
	// by calling tableView:shouldEditTableColumn: to validate
	if([[[[self delegate] class] description] isEqualToString:@"TableContent"]) {

		id tableContentView = [[self delegate] valueForKeyPath:@"tableContentView"];
		if([tableContentView numberOfSelectedRows] == 1 && ([theEvent keyCode] == 36 || [theEvent keyCode] == 76)) {
			if([[self delegate] tableView:tableContentView shouldEditTableColumn:[[tableContentView tableColumns] objectAtIndex:0] row:[tableContentView selectedRow]]) {
				[self editColumn:0 row:[self selectedRow] withEvent:nil select:YES];
				return;
			}
		}
	}
	if([[[[self delegate] class] description] isEqualToString:@"CustomQuery"]) {
		id tableContentView = [[self delegate] valueForKeyPath:@"customQueryView"];
		if([tableContentView numberOfSelectedRows] == 1 && ([theEvent keyCode] == 36 || [theEvent keyCode] == 76)) {

			// TODO: this works until the user presses OK in the Field Editor Sheet!!
			// in the future we should store the new row data temporarily and then
			// after editing the last column update the db field by field (ask HansJB)
			NSInteger colNum = [[tableContentView tableColumns] count];
			NSInteger i;
			for(i=0; i<colNum; i++) {
				[[self delegate] tableView:tableContentView shouldEditTableColumn:[[tableContentView tableColumns] objectAtIndex:i] row:[tableContentView selectedRow]];
			}
			return;
		}
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
