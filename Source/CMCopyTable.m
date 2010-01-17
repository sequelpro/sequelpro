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
#import "CustomQuery.h"
#import "SPNotLoaded.h"
#import "SPConstants.h"

NSInteger MENU_EDIT_COPY_WITH_COLUMN = 2001;
NSInteger MENU_EDIT_COPY_AS_SQL      = 2002;

@implementation CMCopyTable

- (void)copy:(id)sender
{
	prefs = [[NSUserDefaults standardUserDefaults] retain];
	
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

//only have the copy menu item enabled when row(s) are selected
- (BOOL)validateMenuItem:(NSMenuItem*)anItem 
{	
	if ( [[anItem title] isEqualToString:@"Copy"] 
		|| [anItem tag] == MENU_EDIT_COPY_WITH_COLUMN )
	{
		return ([self selectedRow] > -1);
	}
	if ( [anItem tag] == MENU_EDIT_COPY_AS_SQL )
	{
		return (columnDefinitions != NULL && [self selectedRow] > -1);
	}
	return YES;
}

//get selected rows a string of newline separated lines of tab separated fields
//the value in each field is from the objects description method
- (NSString *)selectedRowsAsTabStringWithHeaders:(BOOL)withHeaders
{
	if ( [self numberOfSelectedRows] > 0 )
	{

		NSIndexSet *selectedRows = [self selectedRowIndexes];

		NSArray *columns = [self tableColumns];
		NSUInteger numColumns = [columns count];
		id dataSource = [self dataSource];
		
		NSMutableString *result = [NSMutableString stringWithCapacity:numColumns];
		
		if(withHeaders) {
			NSUInteger i;
			for( i = 0; i < numColumns; i++ ){
				[result appendString:[NSString stringWithFormat:@"%@\t", [[NSArrayObjectAtIndex(columns, i) headerCell] stringValue]]];
			}
			[result appendString:[NSString stringWithFormat:@"\n"]];
		}

		NSUInteger c;

		id rowData = nil;
		NSTableColumn *col = nil;
		
		NSUInteger rowIndex = [selectedRows firstIndex];

		while ( rowIndex != NSNotFound )
		{ 
			rowData = nil;
			for ( c = 0; c < numColumns; c++)
			{
				col = NSArrayObjectAtIndex(columns, c);
				rowData = [dataSource tableView:self 
					  objectValueForTableColumn:col 
											row:rowIndex ];
				
				if ( nil != rowData )
				{
					if ([rowData isNSNull])
						[result appendString:[NSString	stringWithFormat:@"%@\t", [prefs objectForKey:SPNullValue]]];
					else if ([rowData isSPNotLoaded])
						[result appendString:[NSString	stringWithFormat:@"%@\t", NSLocalizedString(@"(not loaded)", @"value shown for hidden blob and text fields")]];
					else
						[result appendString:[NSString stringWithFormat:@"%@\t", [rowData description] ] ];
				}
				else
				{
					[result appendString:@"\t"];
				}
			} //end for each column
			
			if ( [result length] )
			{
				[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
			}
			[result appendString: [ NSString stringWithFormat:@"\n"]];

			// next selected row
			rowIndex = [selectedRows indexGreaterThanIndex: rowIndex];

		} //end for each row
		
		if ( [result length] )
		{
			[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
		}
		return result;
	}
	else
	{
		return nil;
	}
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
	id dataSource            = [self dataSource];

	NSIndexSet *selectedRows = [self selectedRowIndexes];
	NSMutableString *value   = [NSMutableString stringWithCapacity:10];
	NSArray *dbDataRow;
	NSMutableArray *columnMappings;

	id rowData = nil;
	
	NSUInteger rowCounter = 0;
	NSUInteger penultimateRowIndex = [selectedRows count];
	NSUInteger c;
	NSUInteger valueLength = 0;

	NSMutableString *result = [NSMutableString stringWithCapacity:numColumns];

	// Create array of types according to the column order
	NSMutableArray *types = [NSMutableArray arrayWithCapacity:numColumns];
	// Create an array of table column names
	NSMutableArray *tbHeader = [NSMutableArray arrayWithCapacity:numColumns];
	for(id enumObj in columns)
	{
		[tbHeader addObject:[[enumObj headerCell] stringValue]];
		NSString *t = [[columnDefinitions objectAtIndex:[[enumObj identifier] integerValue]] objectForKey:@"typegrouping"];
		if([t isEqualToString:@"bit"] || [t isEqualToString:@"integer"] || [t isEqualToString:@"float"])
			[types addObject:[NSNumber numberWithInteger:0]]; // numeric
		else if([t isEqualToString:@"blobdata"])
			[types addObject:[NSNumber numberWithInteger:2]]; // blob data
		else if([t isEqualToString:@"textdata"])
			[types addObject:[NSNumber numberWithInteger:3]]; // long text data
		else
			[types addObject:[NSNumber numberWithInteger:1]]; // string (fallback coevally)
	}
	[result appendString:[NSString stringWithFormat:@"INSERT INTO %@ (%@)\nVALUES\n", 
		[(selectedTable == nil)?@"<table>":selectedTable backtickQuotedString], [tbHeader componentsJoinedAndBacktickQuoted]]];
	
	// Set up an array of table column mappings
	columnMappings = [[NSMutableArray alloc] initWithCapacity:numColumns];
	for ( c = 0; c < numColumns; c++ ) {
		[columnMappings addObject:[[columns objectAtIndex:c] identifier]];
	}

	NSUInteger rowIndex = [selectedRows firstIndex];
	NSTableColumn *col = nil;

	while ( rowIndex != NSNotFound )
	{ 
		[value appendString:@"\t("];
		rowData = nil;
		rowCounter++;
		for ( c = 0; c < numColumns; c++ )
		{
			col = NSArrayObjectAtIndex(columns, c);
			rowData = [dataSource tableView:self 
				  objectValueForTableColumn:col 
										row:rowIndex ];

			// Check for NULL value
			if([rowData isNSNull]) {
				[value appendString:@"NULL, "];
				continue;
			}
			else if ( rowData != nil ) {
				// check column type and insert the data accordingly
				switch([[types objectAtIndex:c] integerValue]) {
					case 0: // numeric
						[value appendString:[NSString stringWithFormat:@"%@, ", [rowData description]]];
						break;
					case 1: // string
						if ([rowData isKindOfClass:[NSData class]]) {
							[value appendString:[NSString stringWithFormat:@"X'%@', ", 
								[mySQLConnection prepareBinaryData:rowData]]];
						} else {
							[value appendString:[NSString stringWithFormat:@"'%@', ", 
								[mySQLConnection prepareString:[rowData description]]]];
						}
						break;
					case 2: // blob
						if (![[self delegate] isKindOfClass:[CustomQuery class]] && [rowData isSPNotLoaded]) {

							// Abort if there are no indices on this table or if there's no table name given.
							if (![[tableInstance argumentForRow:rowIndex] length] || selectedTable == nil) {
								[columnMappings release];
								return nil;
							}

							//if we have indexes, use argumentForRow
							dbDataRow = [[mySQLConnection queryString:
								[NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@", 
									[selectedTable backtickQuotedString], [tableInstance argumentForRow:rowIndex]]] fetchRowAsArray];
							if([[dbDataRow objectAtIndex:[[columnMappings objectAtIndex:c] integerValue]] isNSNull])
								[value appendString:@"NULL, "];
							else
								[value appendString:[NSString stringWithFormat:@"X'%@', ", 
									[mySQLConnection prepareBinaryData:[dbDataRow objectAtIndex:[[columnMappings objectAtIndex:c] integerValue]]]]];
						} else {
							[value appendString:[NSString stringWithFormat:@"X'%@', ", [mySQLConnection prepareBinaryData:rowData]]];
						}
						break;
					case 3: // long text data
						if (![[self delegate] isKindOfClass:[CustomQuery class]] && [prefs boolForKey:SPLoadBlobsAsNeeded]) {

							// Abort if there are no indices on this table or if there's no table name given.
							if (![[tableInstance argumentForRow:rowIndex] length] || selectedTable == nil)
								return nil;

							//if we have indexes, use argumentForRow
							dbDataRow = [[mySQLConnection queryString:
								[NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@", 
									[selectedTable backtickQuotedString], [tableInstance argumentForRow:rowIndex]]] fetchRowAsArray];
							if([[dbDataRow objectAtIndex:[[columnMappings objectAtIndex:c] integerValue]] isKindOfClass:[NSNull class]])
								[value appendString:@"NULL, "];
							else
								[value appendString:[NSString stringWithFormat:@"'%@', ", 
									[mySQLConnection prepareString:[[dbDataRow objectAtIndex:[[columnMappings objectAtIndex:c] integerValue]] description]]]];
						} else {
							[value appendString:[NSString stringWithFormat:@"'%@', ", 
								[[rowData description] stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"] ] ];
						}
						break;
					default:
						[columnMappings release];
						return nil;
				}
			}
			else
				// TODO is this necessary? or better to return nil?
				[value appendString:@"'', "];

		} //end for each column

		// delete last ', '
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

		// next selected row
		rowIndex = [selectedRows indexGreaterThanIndex: rowIndex];

	} //end for each row
	
	// delete last ",/n"
	if ( [result length] > 3 )
		[result deleteCharactersInRange:NSMakeRange([result length]-2, 2)];

	[result appendString:@";\n"];
	
	[columnMappings release];
	
	return result;
}


//get dragged rows a string of newline separated lines of tab separated fields
//the value in each field is from the objects description method
- (NSString *)draggedRowsAsTabString
{
	NSArray *columns = [self tableColumns];
	NSUInteger numColumns = [columns count];
	NSIndexSet *selectedRows = [self selectedRowIndexes];
	id dataSource = [self dataSource];
	
	NSMutableString *result = [NSMutableString stringWithCapacity:numColumns];

	NSUInteger c;

	id rowData = nil;
	NSTableColumn *col = nil;
	
	NSUInteger rowIndex = [selectedRows firstIndex];

	while ( rowIndex != NSNotFound )
	{ 
		rowData = nil;
		for ( c = 0; c < numColumns; c++)
		{
			col = [columns objectAtIndex:c];
			rowData = [dataSource tableView:self 
				  objectValueForTableColumn:col 
										row:rowIndex ];
			
			if ( nil != rowData )
			{
				if ([rowData isNSNull])
					[result appendString:[NSString	stringWithFormat:@"%@\t", [prefs objectForKey:SPNullValue]]];
				else if ([rowData isSPNotLoaded])
					[result appendString:[NSString	stringWithFormat:@"%@\t", NSLocalizedString(@"(not loaded)", @"value shown for hidden blob and text fields")]];
				else
					[result appendString:[NSString stringWithFormat:@"%@\t", [rowData description] ] ];
			}
			else
			{
				[result appendString:@"\t"];
			}
		} //end for each column
		
		if ( [result length] )
		{
			[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
		}
		[result appendString: [ NSString stringWithFormat:@"\n"]];

		// next selected row
		rowIndex = [selectedRows indexGreaterThanIndex: rowIndex];

	} //end for each row
	
	if ( [result length] )
	{
		[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
	}

	return result;
}

/*
 * Init self with data coming from the table content view. Mainly used for copying data properly.
 */
- (void)setTableInstance:(id)anInstance withColumns:(NSArray *)columnDefs withTableName:(NSString *)aTableName withConnection:(id)aMySqlConnection
{
	selectedTable     = aTableName;
	mySQLConnection   = aMySqlConnection;
	tableInstance     = anInstance;
	
	if (columnDefinitions) [columnDefinitions release];
	
	columnDefinitions = [[NSArray alloc] initWithArray:columnDefs];
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

@end
