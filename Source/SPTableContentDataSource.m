//
//  SPTableContentDataSource.m
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

#import "SPTableContentDataSource.h"
#import "SPTableContentFilter.h"
#import "SPDataStorage.h"
#import "SPCopyTable.h"
#import "SPTablesList.h"
#import "SPAlertSheets.h"

#import <pthread.h>
#import <SPMySQL/SPMySQL.h>

@interface SPTableContent (SPTableContentDataSource_Private_API)

- (id)_contentValueForTableColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex asPreview:(BOOL)asPreview;

@end

@implementation SPTableContent (SPTableContentDataSource)

#pragma mark -
#pragma mark TableView datasource methods

- (NSInteger)numberOfRowsInTableView:(SPCopyTable *)tableView
{
#ifndef SP_CODA
	if (tableView == filterTableView) {
		return filterTableIsSwapped ? [filterTableData count] : [[[filterTableData objectForKey:@"0"] objectForKey:SPTableContentFilterKey] count];
	}
#endif
	if (tableView == tableContentView) {
		return tableRowsCount;
	}
	
	return 0;
}

- (id)tableView:(SPCopyTable *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	NSUInteger columnIndex = [[tableColumn identifier] integerValue];
#ifndef SP_CODA
	if (tableView == filterTableView) {
		if (filterTableIsSwapped) {
			// First column shows the field names
			if (columnIndex == 0) {
				return [[[NSTableHeaderCell alloc] initTextCell:[[filterTableData objectForKey:[NSNumber numberWithInteger:rowIndex]] objectForKey:@"name"]] autorelease];
			} 

			return NSArrayObjectAtIndex([[filterTableData objectForKey:[NSNumber numberWithInteger:rowIndex]] objectForKey:SPTableContentFilterKey], columnIndex - 1);
		}
		
		return NSArrayObjectAtIndex([[filterTableData objectForKey:[tableColumn identifier]] objectForKey:SPTableContentFilterKey], rowIndex);
	}
#endif
	if (tableView == tableContentView) {
		
		id value = nil;
		
		// While the table is being loaded, additional validation is required - data
		// locks must be used to avoid crashes, and indexes higher than the available
		// rows or columns may be requested.  Return "..." to indicate loading in these
		// cases.
		if (isWorking) {
			pthread_mutex_lock(&tableValuesLock);
			
			if (rowIndex < (NSInteger)tableRowsCount && columnIndex < [tableValues columnCount]) {
				value = [self _contentValueForTableColumn:columnIndex row:rowIndex asPreview:YES];
			}
			
			pthread_mutex_unlock(&tableValuesLock);
			
			if (!value) return @"...";
		} 
		else {
			if ([tableView editedColumn] == (NSInteger)columnIndex && [tableView editedRow] == rowIndex) {
				value = [self _contentValueForTableColumn:columnIndex row:rowIndex asPreview:NO];
			}
			else {
				value = [self _contentValueForTableColumn:columnIndex row:rowIndex asPreview:YES];
			}
		}
		
		if ([value isKindOfClass:[SPMySQLGeometryData class]]) {
			return [value wktString];
		}
		
		if ([value isNSNull]) {
			return [prefs objectForKey:SPNullValue];
		}
		
		if ([value isKindOfClass:[NSData class]]) {
			
			if ([self cellValueIsDisplayedAsHexForColumn:columnIndex]) {
				if ([(NSData *)value length] > 255) {
					return [NSString stringWithFormat:@"0x%@...", [[(NSData *)value subdataWithRange:NSMakeRange(0, 255)] dataToHexString]];
				}
				return [NSString stringWithFormat:@"0x%@", [(NSData *)value dataToHexString]];
			}

			pthread_mutex_t *fieldEditorCheckLock = NULL;
			if (isWorking) {
				fieldEditorCheckLock = &tableValuesLock;
			}

			// Unless we're editing, always retrieve the short string representation, truncating the value where necessary
			if ([tableView editedColumn] == (NSInteger)columnIndex || [tableView editedRow] == rowIndex) {
				return [value stringRepresentationUsingEncoding:[mySQLConnection stringEncoding]];
			} else {
				return [value shortStringRepresentationUsingEncoding:[mySQLConnection stringEncoding]];
			}
		}
		
		if ([value isSPNotLoaded]) {
			return NSLocalizedString(@"(not loaded)", @"value shown for hidden blob and text fields");
		}
		
		return value;
	}
	
	return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
#ifndef SP_CODA
	if(tableView == filterTableView) {
		if (filterTableIsSwapped) {
			[[[filterTableData objectForKey:[NSNumber numberWithInteger:rowIndex]] objectForKey:SPTableContentFilterKey] replaceObjectAtIndex:([[tableColumn identifier] integerValue] - 1) withObject:(NSString *)object];
		}
		else {
			[[[filterTableData objectForKey:[tableColumn identifier]] objectForKey:SPTableContentFilterKey] replaceObjectAtIndex:rowIndex withObject:(NSString *)object];
		}
		
		[self updateFilterTableClause:nil];
		
		return;
	}
#endif
	if (tableView == tableContentView) {
		
		// If the current cell should have been edited in a sheet, do nothing - field closing will have already
		// updated the field.
		if ([tableContentView shouldUseFieldEditorForRow:rowIndex column:[[tableColumn identifier] integerValue] checkWithLock:NULL]) {
			return;
		}
		
		// If table data comes from a view, save back to the view
		if ([tablesListInstance tableType] == SPTableTypeView) {
			[self saveViewCellValue:object forTableColumn:tableColumn row:rowIndex];
			return;
		}
		
		NSInteger columnIndex = [[tableColumn identifier] integerValue];
		NSDictionary *columnDefinition = [[(id <SPDatabaseContentViewDelegate>)[tableContentView delegate] dataColumnDefinitions] objectAtIndex:columnIndex];
		
		NSString *columnType = [columnDefinition objectForKey:@"typegrouping"];
		
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
		
		if ([columnType isEqualToString:@"binary"] && [object isKindOfClass: [NSString class]]) {
			//
			// This is a binary object being edited as a hex string. (Is there a better
			// way to detect this case?)
			// Convert the string back to binary, checking for errors.
			//
			NSData *data = [NSData dataWithHexString: object];
			if (data) {
				object = data;
				[tableValues replaceObjectInRow:rowIndex column:[[tableColumn identifier] integerValue] withObject:object];
			}
			else {
				SPOnewayAlertSheet(
								   NSLocalizedString(@"Error", @"error"),
								   [tableDocumentInstance parentWindow],
								   NSLocalizedString(@"Bad hexadecimal data input.", @"Bad hexadecimal data input.")
								   );
				return;

			}
		}
		else if (object) {
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

- (BOOL)cellValueIsDisplayedAsHexForColumn:(NSUInteger)columnIndex
{
	if (![prefs boolForKey:SPDisplayBinaryDataAsHex]) {
		return NO;
	}
	
	NSDictionary *columnDefinition = [[(id <SPDatabaseContentViewDelegate>)[tableContentView delegate] dataColumnDefinitions] objectAtIndex:columnIndex];
	NSString *typeGrouping = columnDefinition[@"typegrouping"];
	
	if ([typeGrouping isEqual:@"binary"]) {
		return YES;
	}
	
	if ([typeGrouping isEqual:@"blobdata"]) {
		return YES;
	}
	
	
	return NO;
}

@end

@implementation SPTableContent (SPTableContentDataSource_Private_API)

- (id)_contentValueForTableColumn:(NSUInteger)columnIndex row:(NSUInteger)rowIndex asPreview:(BOOL)asPreview
{
	if (asPreview) {
		return SPDataStoragePreviewAtRowAndColumn(tableValues, rowIndex, columnIndex, 150);
	}

	return SPDataStorageObjectAtRowAndColumn(tableValues, rowIndex, columnIndex);
}

@end
