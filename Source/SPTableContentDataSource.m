//
//  $Id$
//
//  SPTableContentDataSource.m
//  Sequel Pro
//
//  Created by Stuart Connolly (stuconnolly.com) on March 20, 2012
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
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPTableContentDataSource.h"
#import "SPDataStorage.h"
#import "SPCopyTable.h"
#import "SPTablesList.h"

#import <SPMySQL/SPMySQL.h>
#import <pthread.h>

@implementation SPTableContent (SPTableContentDataSource)

#pragma mark -
#pragma mark TableView datasource methods

- (NSInteger)numberOfRowsInTableView:(SPCopyTable *)tableView
{
#ifndef SP_REFACTOR
	if (tableView == filterTableView) {
		return filterTableIsSwapped ? [filterTableData count] : [[[filterTableData objectForKey:[NSNumber numberWithInteger:0]] objectForKey:@"filter"] count];
	}
	else 
#endif
		if (tableView == tableContentView) {
			return tableRowsCount;
		}
	
	return 0;
}

- (id)tableView:(SPCopyTable *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
#ifndef SP_REFACTOR
	if (tableView == filterTableView) {
		if (filterTableIsSwapped)
			
			// First column shows the field names
			if ([[tableColumn identifier] integerValue] == 0) {
				return [[[NSTableHeaderCell alloc] initTextCell:[[filterTableData objectForKey:[NSNumber numberWithInteger:rowIndex]] objectForKey:@"name"]] autorelease];
			} 
			else {
				return NSArrayObjectAtIndex([[filterTableData objectForKey:[NSNumber numberWithInteger:rowIndex]] objectForKey:@"filter"], [[tableColumn identifier] integerValue] - 1);
			}
			else {
				return NSArrayObjectAtIndex([[filterTableData objectForKey:[tableColumn identifier]] objectForKey:@"filter"], rowIndex);
			}
	}
	else 
#endif
		if (tableView == tableContentView) {
			
			id value = nil;
			NSUInteger columnIndex = [[tableColumn identifier] integerValue];
			
			// While the table is being loaded, additional validation is required - data
			// locks must be used to avoid crashes, and indexes higher than the available
			// rows or columns may be requested.  Return "..." to indicate loading in these
			// cases.
			if (isWorking) {
				pthread_mutex_lock(&tableValuesLock);
				
				if (rowIndex < (NSInteger)tableRowsCount && columnIndex < [tableValues columnCount]) {
					value = [[SPDataStorageObjectAtRowAndColumn(tableValues, rowIndex, columnIndex) copy] autorelease];
				}
				
				pthread_mutex_unlock(&tableValuesLock);
				
				if (!value) return @"...";
			} 
			else {
				value = SPDataStorageObjectAtRowAndColumn(tableValues, rowIndex, columnIndex);
			}
			
			if ([value isKindOfClass:[SPMySQLGeometryData class]])
				return [value wktString];
			
			if ([value isNSNull])
				return [prefs objectForKey:SPNullValue];
			
			if ([value isKindOfClass:[NSData class]])
				return [value shortStringRepresentationUsingEncoding:[mySQLConnection stringEncoding]];
			
			if ([value isSPNotLoaded])
				return NSLocalizedString(@"(not loaded)", @"value shown for hidden blob and text fields");
			
			return value;
		}
	
	return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
#ifndef SP_REFACTOR
	if(tableView == filterTableView) {
		if (filterTableIsSwapped) {
			[[[filterTableData objectForKey:[NSNumber numberWithInteger:rowIndex]] objectForKey:@"filter"] replaceObjectAtIndex:([[tableColumn identifier] integerValue] - 1) withObject:(NSString *)object];
		}
		else {
			[[[filterTableData objectForKey:[tableColumn identifier]] objectForKey:@"filter"] replaceObjectAtIndex:rowIndex withObject:(NSString *)object];
		}
		
		[self updateFilterTableClause:nil];
		
		return;
	}
	else 
#endif
		if (tableView == tableContentView) {
			
			// If the current cell should have been edited in a sheet, do nothing - field closing will have already
			// updated the field.
			if ([tableContentView shouldUseFieldEditorForRow:rowIndex column:[[tableColumn identifier] integerValue]]) {
				return;
			}
			
			// If table data comes from a view, save back to the view
			if ([tablesListInstance tableType] == SPTableTypeView) {
				[self saveViewCellValue:object forTableColumn:tableColumn row:rowIndex];
				return;
			}
			
			// Catch editing events in the row and if the row isn't currently being edited,
			// start an edit.  This allows edits including enum changes to save correctly.
			if (isEditingRow && [tableContentView selectedRow] != currentlyEditingRow) {
				[self saveRowOnDeselect];
			}
			
			if (!isEditingRow) {
				[oldRow setArray:[tableValues rowContentsAtIndex:rowIndex]];
				
				isEditingRow = YES;
				currentlyEditingRow = rowIndex;
			}
			
			NSDictionary *column = NSArrayObjectAtIndex(dataColumns, [[tableColumn identifier] integerValue]);
			
			if (object) {
				// Restore NULLs if necessary
				if ([object isEqualToString:[prefs objectForKey:SPNullValue]] && [[column objectForKey:@"null"] boolValue]) {
					object = [NSNull null];
				}
				
				[tableValues replaceObjectInRow:rowIndex column:[[tableColumn identifier] integerValue] withObject:object];
			} 
			else {
				[tableValues replaceObjectInRow:rowIndex column:[[tableColumn identifier] integerValue] withObject:@""];
			}
		}
}

@end
