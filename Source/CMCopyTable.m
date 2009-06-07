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

#import "CMCopyTable.h"
#import "SPArrayAdditions.h"

int MENU_EDIT_COPY_WITH_COLUMN = 2001;
int MENU_EDIT_COPY_AS_SQL      = 2002;

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
- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)isLocal
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
		NSArray *columns = [self tableColumns];
		int numColumns = [columns count];
		id dataSource = [self dataSource];
		
		NSMutableString *result = [NSMutableString stringWithCapacity:numColumns];
		
		if(withHeaders) {
			int i;
			for( i = 0; i < numColumns; i++ ){
				[result appendString:[NSString stringWithFormat:@"%@\t", [[[columns objectAtIndex:i] headerCell] stringValue]]];
			}
			[result appendString:[NSString stringWithFormat:@"\n"]];
		}
		
		//this is really deprecated in 10.3, but the new method is really weird
		NSEnumerator *enumerator = [self selectedRowEnumerator]; 
		
		int c;
		id row = nil;
		id rowData = nil;
		NSTableColumn *col = nil;
		
		while (row = [enumerator nextObject]) 
		{ 
			rowData = nil;
			for ( c = 0; c < numColumns; c++)
			{
				col = [columns objectAtIndex:c];
				rowData = [dataSource tableView:self 
					  objectValueForTableColumn:col 
											row:[row intValue] ];
				
				if ( nil != rowData )
				{
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
 * Return selected rows as SQL INSERT INTO foo VALUES baz
 * string.
 */
- (NSString *)selectedRowsAsSqlInserts
{
	if ( [self numberOfSelectedRows] > 0 )
	{
		NSArray *columns = [self tableColumns];
		int numColumns = [columns count];
		id dataSource = [self dataSource];
		id enumObj;

		NSMutableString *result = [NSMutableString stringWithCapacity:numColumns];

		// Create an array of table column names
		NSMutableArray *tbHeader = [NSMutableArray arrayWithCapacity:numColumns];
		enumerate(columns, enumObj) [tbHeader addObject:[[enumObj headerCell] stringValue]];

		// Create an hash of header name and typegrouping
		NSMutableDictionary *headerType = [NSMutableDictionary dictionaryWithCapacity:numColumns];
		enumerate(columnDefinitions, enumObj)
			[headerType setObject:[enumObj objectForKey:@"typegrouping"] forKey:[enumObj objectForKey:@"name"]];

		// Create array of types according to the column order
		NSMutableArray *types = [NSMutableArray arrayWithCapacity:numColumns];
		enumerate(tbHeader, enumObj)
		{
			NSString *t = [headerType objectForKey:enumObj];

			if([t isEqualToString:@"bit"] || [t isEqualToString:@"integer"] || [t isEqualToString:@"float"])
				[types addObject:[NSNumber numberWithInt:0]];
			else if([t isEqualToString:@"blobdata"])
				[types addObject:[NSNumber numberWithInt:2]];
			else
				[types addObject:[NSNumber numberWithInt:1]];

		}
		
		[result appendString:[NSString stringWithFormat:@"INSERT INTO `%@` (%@)\nVALUES\n", 
			(selectedTable == nil)?@"<table>":selectedTable, [tbHeader componentsJoinedAndBacktickQuoted]]];

		int c;
		id rowData = nil;
		NSTableColumn *col = nil;
		NSIndexSet *rowIndexes = [self selectedRowIndexes];
		unsigned row = [rowIndexes firstIndex];

		while ( row != NSNotFound )
		{ 
			[result appendString:@"\t("];
			rowData = nil;
			for ( c = 0; c < numColumns; c++)
			{
				col = [columns objectAtIndex:c];
				rowData = [dataSource tableView:self 
					  objectValueForTableColumn:col 
											row:row ];

				if ( nil != rowData ) {

					switch([[types objectAtIndex:c] intValue]) {
						case 0: // numeric
						[result appendString:[NSString stringWithFormat:@"%@,", [rowData description]]];
						break;
						case 1: // string
						[result appendString:[NSString stringWithFormat:@"'%@',", [[rowData description] stringByReplacingOccurrencesOfString:@"'" withString:@"\'"] ] ];
						break;
						case 2: //blob
						[result appendString:[NSString stringWithFormat:@"X'%@',", @"<BLOB>"]];
					}
				}
				else
					[result appendString:@"'',"];

			} //end for each column
			
			if ( [result length] )
			{
				[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
			}
			[result appendString: [ NSString stringWithFormat:@"),\n"]];
			
			row = [rowIndexes indexGreaterThanIndex: row];
			
		} //end for each row
		
		if ( [result length] > 3 )
		{
			[result deleteCharactersInRange:NSMakeRange([result length]-2, 2)];
		}
		
		[result appendString:@";\n"];
		
		return result;
	}
	else
	{
		return nil;
	}
}

//get dragged rows a string of newline separated lines of tab separated fields
//the value in each field is from the objects description method
- (NSString *)draggedRowsAsTabString:(NSArray *)rows
{
	if ( [rows count] > 0 )
	{
		NSArray *columns = [self tableColumns];
		int numColumns = [columns count];
		id dataSource = [self dataSource];
		
		NSMutableString *result = [NSMutableString stringWithCapacity:numColumns];

		//this is really deprecated in 10.3, but the new method is really weird
		NSEnumerator *enumerator = [rows objectEnumerator]; 
		
		int c;
		id row = nil;
		id rowData = nil;
		NSTableColumn *col = nil;
		
		while (row = [enumerator nextObject]) 
		{ 
			rowData = nil;
			for ( c = 0; c < numColumns; c++)
			{
				col = [columns objectAtIndex:c];
				rowData = [dataSource tableView:self 
					  objectValueForTableColumn:col 
											row:[row intValue] ];
				
				if ( nil != rowData )
				{
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

- (void)setTableInfoWithColumns:(NSArray *)columnDefs withTable:(NSString *)aTable
{
	columnDefinitions = [[NSArray arrayWithArray:columnDefs] retain];
	selectedTable = aTable;
}

@end
