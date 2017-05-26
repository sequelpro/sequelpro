//
//  SPCopyTable.m
//  sequel-pro
//
//  Created by Stuart Glenn on April 21, 2004.
//  Changed by Lorenz Textor on November 13, 2004
//  Copyright (c) 2004 Stuart Glenn. All rights reserved.
//  Copyright (c) 2012 Sequel Pro Team. All rights reserved.
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

#import "SPCopyTable.h"
#import "SPTableContent.h"
#import "SPTableTriggers.h"
#import "SPTableRelations.h"
#import "SPCustomQuery.h"
#import "SPDataStorage.h"
#import "SPTextAndLinkCell.h"
#import "SPTooltip.h"
#import "SPAlertSheets.h"
#ifndef SP_CODA /* headers */
#import "SPBundleHTMLOutputController.h"
#endif
#import "SPGeometryDataView.h"
#ifndef SP_CODA /* headers */
#import "SPBundleEditorController.h"
#import "SPAppController.h"
#endif
#import "SPTablesList.h"
#import "SPBundleCommandRunner.h"
#import "SPDatabaseContentViewDelegate.h"

#import <SPMySQL/SPMySQL.h>
#import "pthread.h"
#include <stdlib.h>

NSInteger SPEditMenuCopy            = 2001;
NSInteger SPEditMenuCopyWithColumns = 2002;
NSInteger SPEditMenuCopyAsSQL       = 2003;

static const NSInteger kBlobExclude     = 1;
static const NSInteger kBlobInclude     = 2;
static const NSInteger kBlobAsFile      = 3;
static const NSInteger kBlobAsImageFile = 4;

@implementation SPCopyTable

/**
 * Hold the selected range of the current table cell editor to be able to set this passed
 * selection in the field editor's editTextView
 */
@synthesize fieldEditorSelectedRange;
@synthesize tmpBlobFileDirectory;

/**
 * Cell editing in SPCustomQuery or for views in SPTableContent
 */
- (BOOL)isCellEditingMode
{
	return ([[self delegate] isKindOfClass:[SPCustomQuery class]] 
		|| ([[self delegate] isKindOfClass:[SPTableContent class]] 
				&& [(NSObject*)[self delegate] valueForKeyPath:@"tablesListInstance"] 
				&& [(SPTablesList*)([(NSObject*)[self delegate] valueForKeyPath:@"tablesListInstance"]) tableType] == SPTableTypeView));
}

/**
 * Check if current edited cell represents a class other than a normal NSString
 * like pop-up menus for enum or set
 */
- (BOOL)isCellComplex
{
	return (![[self preparedCellAtColumn:[self editedColumn] row:[self editedRow]] isKindOfClass:[SPTextAndLinkCell class]]);
}

#pragma mark -

/**
 * Handles the general Copy action of selected rows in the table according to sender
 */
- (void)copy:(id)sender
{
#ifndef SP_CODA /* copy table rows */
	NSString *tmp = nil;

	if ([sender tag] == SPEditMenuCopyAsSQL) {
		tmp = [self rowsAsSqlInsertsOnlySelectedRows:YES];
		
		if (tmp != nil){
			NSPasteboard *pb = [NSPasteboard generalPasteboard];

			[pb declareTypes:@[NSStringPboardType] owner:nil];

			[pb setString:tmp forType:NSStringPboardType];
		}
	} 
	else {
		tmp = [self rowsAsTabStringWithHeaders:([sender tag] == SPEditMenuCopyWithColumns) onlySelectedRows:YES blobHandling:kBlobInclude];
		
		if (tmp != nil) {
			NSPasteboard *pb = [NSPasteboard generalPasteboard];

			[pb declareTypes:@[NSTabularTextPboardType, NSStringPboardType] owner:nil];

			[pb setString:tmp forType:NSStringPboardType];
			[pb setString:tmp forType:NSTabularTextPboardType];
		}
	}
#endif
}

#ifdef SP_CODA

- (void)delete:(id)sender
{
        [tableInstance removeRow:self];
}

#endif

/**
 * Get selected rows a string of newline separated lines of tab separated fields
 * the value in each field is from the objects description method
 */
#ifndef SP_CODA /* get rows as string */
- (NSString *)rowsAsTabStringWithHeaders:(BOOL)withHeaders onlySelectedRows:(BOOL)onlySelected blobHandling:(NSInteger)withBlobHandling
{
	if (onlySelected && [self numberOfSelectedRows] == 0) return nil;

	NSIndexSet *selectedRows;
	if(onlySelected)
		selectedRows = [self selectedRowIndexes];
	else
		selectedRows = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [tableStorage count])];

	NSArray *columns = [self tableColumns];
	NSUInteger numColumns = [columns count];
	NSMutableString *result = [NSMutableString stringWithCapacity:2000];

	// Add the table headers if requested to do so
	if (withHeaders) {
		NSUInteger i;
		for( i = 0; i < numColumns; i++ ){
			if([result length])
				[result appendString:@"\t"];
			[result appendString:[[NSArrayObjectAtIndex(columns, i) headerCell] stringValue]];
		}
		[result appendString:@"\n"];
	}

	// Create an array of table column mappings for fast iteration
	NSUInteger *columnMappings = calloc(numColumns, sizeof(NSUInteger));
	for (NSUInteger ci = 0; ci < numColumns; ci++ )
		columnMappings[ci] = (NSUInteger)[[NSArrayObjectAtIndex(columns, ci) identifier] integerValue];

	// Loop through the rows, adding their descriptive contents
	NSString *nullString = [prefs objectForKey:SPNullValue];
	BOOL hexBlobs = [[prefs objectForKey: SPCopyBLOBsAsHex] boolValue];
	Class spmysqlGeometryData = [SPMySQLGeometryData class];
	__block NSUInteger rowCounter = 0;

	if((withBlobHandling == kBlobAsFile || withBlobHandling == kBlobAsImageFile) && tmpBlobFileDirectory && [tmpBlobFileDirectory length]) {
		NSFileManager *fm = [NSFileManager defaultManager];
		[fm removeItemAtPath:tmpBlobFileDirectory error:nil];
		[fm createDirectoryAtPath:tmpBlobFileDirectory withIntermediateDirectories:YES attributes:nil error:nil];
	}

	[selectedRows enumerateIndexesUsingBlock:^(NSUInteger rowIndex, BOOL * _Nonnull stop) {
		for (NSUInteger c = 0; c < numColumns; c++ ) {
			id cellData = SPDataStorageObjectAtRowAndColumn(tableStorage, rowIndex, columnMappings[c]);

			// Copy the shown representation of the cell - custom NULL display strings, (not loaded),
			// definable representation of any blobs or binary texts.
			if (cellData) {
				if ([cellData isNSNull])
					[result appendFormat:@"%@\t", nullString];
				else if ([cellData isSPNotLoaded])
					[result appendFormat:@"%@\t", NSLocalizedString(@"(not loaded)", @"value shown for hidden blob and text fields")];
				else if ([cellData isKindOfClass:[NSData class]]) {
					if(withBlobHandling == kBlobInclude) {
						NSString *displayString;
						if (hexBlobs)
							displayString = [[cellData dataToHexString] copy];
						else
							displayString = [[NSString alloc] initWithData:cellData encoding:[mySQLConnection stringEncoding]];
						if (!displayString) displayString = [[NSString alloc] initWithData:cellData encoding:NSASCIIStringEncoding];
						if (displayString) {
							[result appendFormat:@"%@\t", displayString];
							[displayString release];
						}
					}
					else if(withBlobHandling == kBlobAsFile && tmpBlobFileDirectory && [tmpBlobFileDirectory length]) {
						NSString *fp = [NSString stringWithFormat:@"%@/%ld_%ld.dat", tmpBlobFileDirectory, (long)rowCounter, (long)c];
						[cellData writeToFile:fp atomically:NO];
						[result appendFormat:@"%@\t", fp];
					}
					else if(withBlobHandling == kBlobAsImageFile && tmpBlobFileDirectory && [tmpBlobFileDirectory length]) {
						NSString *fp = [NSString stringWithFormat:@"%@/%ld_%ld.tif", tmpBlobFileDirectory, (long)rowCounter, (long)c];
						NSImage *image = [[NSImage alloc] initWithData:cellData];
						if (image) {
							NSData *d = [[NSData alloc] initWithData:[image TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1]];
							[d writeToFile:fp atomically:NO];
							if(d) SPClear(d);
							[image release];
						} else {
							NSString *noData = @"";
							[noData writeToFile:fp atomically:NO encoding:NSUTF8StringEncoding error:NULL];
						}
						[result appendFormat:@"%@\t", fp];
					}
					else {
						[result appendString:@"BLOB\t"];
					}
				}
				else if ([cellData isKindOfClass:spmysqlGeometryData]) {
					if((withBlobHandling == kBlobAsFile || withBlobHandling == kBlobAsImageFile) && tmpBlobFileDirectory && [tmpBlobFileDirectory length]) {
						NSString *fp = [NSString stringWithFormat:@"%@/%ld_%ld.pdf", tmpBlobFileDirectory, (long)rowCounter, (long)c];
						SPGeometryDataView *v = [[SPGeometryDataView alloc] initWithCoordinates:[cellData coordinates]];
						NSData *thePDF = [v pdfData];
						if(thePDF) {
							[thePDF writeToFile:fp atomically:NO];
							[result appendFormat:@"%@\t", fp];
						} else {
							[result appendFormat:@"%@\t", [cellData wktString]];
						}
						if(v) SPClear(v);
					} else {
						[result appendFormat:@"%@\t", [cellData wktString]];
					}
				}
				else
					[result appendFormat:@"%@\t", [[[cellData description] stringByReplacingOccurrencesOfString:@"\n" withString:@"↵"] stringByReplacingOccurrencesOfString:@"\t" withString:@"⇥"]];
			} else {
				[result appendString:@"\t"];
			}
		}

		rowCounter++;

		// Remove the trailing tab and add the linebreak
		if ([result length]){
			[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
		}
		[result appendString:@"\n"];
	}];

	// Remove the trailing line end
	if ([result length]) {
		[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
	}

	free(columnMappings);

	return result;
}

/**
 * Get selected rows a string of newline separated lines of , separated fields wrapped into quotes
 * the value in each field is from the objects description method
 */
- (NSString *)rowsAsCsvStringWithHeaders:(BOOL)withHeaders onlySelectedRows:(BOOL)onlySelected blobHandling:(NSInteger)withBlobHandling
{
	if (onlySelected && [self numberOfSelectedRows] == 0) return nil;

	NSIndexSet *selectedRows;
	if(onlySelected)
		selectedRows = [self selectedRowIndexes];
	else
		selectedRows = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [tableStorage count])];

	NSArray *columns = [self tableColumns];
	NSUInteger numColumns = [columns count];
	NSMutableString *result = [NSMutableString stringWithCapacity:2000];

	// Add the table headers if requested to do so
	if (withHeaders) {
		NSUInteger i;
		for( i = 0; i < numColumns; i++ ){
			if([result length])
				[result appendString:@","];
			[result appendFormat:@"\"%@\"", [[[NSArrayObjectAtIndex(columns, i) headerCell] stringValue] stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""]];
		}
		[result appendString:@"\n"];
	}

	// Create an array of table column mappings for fast iteration
	NSUInteger *columnMappings = calloc(numColumns, sizeof(NSUInteger));
	for (NSUInteger ci = 0; ci < numColumns; ci++ )
		columnMappings[ci] = (NSUInteger)[[NSArrayObjectAtIndex(columns, ci) identifier] integerValue];

	// Loop through the rows, adding their descriptive contents
	NSString *nullString = [prefs objectForKey:SPNullValue];
	Class spmysqlGeometryData = [SPMySQLGeometryData class];

	__block NSUInteger rowCounter = 0;

	if((withBlobHandling == kBlobAsFile || withBlobHandling == kBlobAsImageFile) && tmpBlobFileDirectory && [tmpBlobFileDirectory length]) {
		NSFileManager *fm = [NSFileManager defaultManager];
		[fm removeItemAtPath:tmpBlobFileDirectory error:nil];
		[fm createDirectoryAtPath:tmpBlobFileDirectory withIntermediateDirectories:YES attributes:nil error:nil];
	}

	[selectedRows enumerateIndexesUsingBlock:^(NSUInteger rowIndex, BOOL * _Nonnull stop) {
		for (NSUInteger c = 0; c < numColumns; c++ ) {
			id cellData = SPDataStorageObjectAtRowAndColumn(tableStorage, rowIndex, columnMappings[c]);

			// Copy the shown representation of the cell - custom NULL display strings, (not loaded),
			// definable representation of any blobs or binary texts.
			if (cellData) {
				if ([cellData isNSNull])
					[result appendFormat:@"\"%@\",", nullString];
				else if ([cellData isSPNotLoaded])
					[result appendFormat:@"\"%@\",", NSLocalizedString(@"(not loaded)", @"value shown for hidden blob and text fields")];
				else if ([cellData isKindOfClass:[NSData class]]) {
					if(withBlobHandling == kBlobInclude) {
						NSString *displayString = [[NSString alloc] initWithData:cellData encoding:[mySQLConnection stringEncoding]];
						if (!displayString) displayString = [[NSString alloc] initWithData:cellData encoding:NSASCIIStringEncoding];
						if (displayString) {
							[result appendFormat:@"\"%@\",", displayString];
							[displayString release];
						}
					}
					else if(withBlobHandling == kBlobAsFile && tmpBlobFileDirectory && [tmpBlobFileDirectory length]) {
						NSString *fp = [NSString stringWithFormat:@"%@/%ld_%ld.dat", tmpBlobFileDirectory, (long)rowCounter, (long)c];
						[cellData writeToFile:fp atomically:NO];
						[result appendFormat:@"\"%@\",", fp];
					}
					else if(withBlobHandling == kBlobAsImageFile && tmpBlobFileDirectory && [tmpBlobFileDirectory length]) {
						NSString *fp = [NSString stringWithFormat:@"%@/%ld_%ld.tif", tmpBlobFileDirectory, (long)rowCounter, (long)c];
						NSImage *image = [[NSImage alloc] initWithData:cellData];
						if (image) {
							NSData *d = [[NSData alloc] initWithData:[image TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1]];
							[d writeToFile:fp atomically:NO];
							if(d) SPClear(d);
							[image release];
						} else {
							NSString *noData = @"";
							[noData writeToFile:fp atomically:NO encoding:NSUTF8StringEncoding error:NULL];
						}
						[result appendFormat:@"\"%@\",", fp];
					}
					else {
						[result appendString:@"\"BLOB\","];
					}
				}
				else if ([cellData isKindOfClass:spmysqlGeometryData]) {
					if((withBlobHandling == kBlobAsFile || withBlobHandling == kBlobAsImageFile) && tmpBlobFileDirectory && [tmpBlobFileDirectory length]) {
						NSString *fp = [NSString stringWithFormat:@"%@/%ld_%ld.pdf", tmpBlobFileDirectory, (long)rowCounter, (long)c];
						SPGeometryDataView *v = [[SPGeometryDataView alloc] initWithCoordinates:[cellData coordinates]];
						NSData *thePDF = [v pdfData];
						if(thePDF) {
							[thePDF writeToFile:fp atomically:NO];
							[result appendFormat:@"\"%@\",", fp];
						} else {
							[result appendFormat:@"\"%@\",", [cellData wktString]];
						}
						if(v) SPClear(v);
					} else {
						[result appendFormat:@"\"%@\",", [cellData wktString]];
					}
				}
				else
					[result appendFormat:@"\"%@\",", [cellData description]];
			} else {
				[result appendString:@","];
			}
		}

		rowCounter++;

		// Remove the trailing tab and add the linebreak
		if ([result length]){
			[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
		}
		[result appendString:@"\n"];
	}];

	// Remove the trailing line end
	if ([result length]) {
		[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
	}

	free(columnMappings);

	return result;
}
#endif

/*
 * Return selected rows as SQL INSERT INTO `foo` VALUES (baz) string.
 * If no selected table name is given `<table>` will be used instead.
 */
- (NSString *)rowsAsSqlInsertsOnlySelectedRows:(BOOL)onlySelected
{
	if (onlySelected && [self numberOfSelectedRows] == 0) return nil;

	NSIndexSet *selectedRows = (onlySelected) ? [self selectedRowIndexes] : [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [tableStorage count])];

	NSArray *columns      = [self tableColumns];
	NSUInteger numColumns = [columns count];
	NSMutableString *value = [NSMutableString stringWithCapacity:10];

	id cellData = nil;

	NSUInteger rowCounter = 0;
	NSUInteger penultimateRowIndex = [selectedRows count];
	NSUInteger c;

	NSMutableString *result = [NSMutableString stringWithCapacity:2000];

	// Create an array of table column names
	NSMutableArray *tbHeader = [NSMutableArray arrayWithCapacity:numColumns];
	
	for (id enumObj in columns) 
	{
		[tbHeader addObject:[[enumObj headerCell] stringValue]];
	}

	// Create arrays of table column mappings and types for fast iteration
	NSUInteger *columnMappings = calloc(numColumns, sizeof(NSUInteger));
	NSUInteger *columnTypes = calloc(numColumns, sizeof(NSUInteger));
	
	for (c = 0; c < numColumns; c++) 
	{
		columnMappings[c] = (NSUInteger)[[NSArrayObjectAtIndex(columns, c) identifier] integerValue];

		NSString *t = [NSArrayObjectAtIndex(columnDefinitions, columnMappings[c]) objectForKey:@"typegrouping"];

		// Numeric data
		if ([t isEqualToString:@"bit"] || [t isEqualToString:@"integer"] || [t isEqualToString:@"float"])
			columnTypes[c] = 0;

		// Blob data or long text data
		else if ([t isEqualToString:@"blobdata"] || [t isEqualToString:@"textdata"])
			columnTypes[c] = 2;

		// GEOMETRY data
		else if ([t isEqualToString:@"geometry"])
			columnTypes[c] = 3;

		// Default to strings
		else
			columnTypes[c] = 1;
	}

	// Begin the SQL string
	[result appendFormat:@"INSERT INTO %@ (%@)\nVALUES\n",
		[(selectedTable == nil) ? @"<table>" : selectedTable backtickQuotedString], [tbHeader componentsJoinedAndBacktickQuoted]];

	NSUInteger rowIndex = [selectedRows firstIndex];
	Class spTableContentClass = [SPTableContent class];
	Class nsDataClass = [NSData class];
	
	while (rowIndex != NSNotFound)
	{
		[value appendString:@"\t("];
		cellData = nil;
		rowCounter++;
		NSMutableArray *rowValues = [[NSMutableArray alloc] initWithCapacity:numColumns];
		
		for (c = 0; c < numColumns; c++)
		{
			cellData = SPDataStorageObjectAtRowAndColumn(tableStorage, rowIndex, columnMappings[c]);

			// If the data is not loaded, attempt to fetch the value
			if ([cellData isSPNotLoaded] && [[self delegate] isKindOfClass:spTableContentClass]) {

				NSString *whereArgument = [tableInstance argumentForRow:rowIndex];
				// Abort if no table name given, not table content, or if there are no indices on this table
				if (!selectedTable || ![[self delegate] isKindOfClass:spTableContentClass] || ![whereArgument length]) {
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
								whereArgument]];
			}

			// Check for NULL value
			if ([cellData isNSNull]) {
				[rowValues addObject:@"NULL"];
				continue;

			} 
			else if (cellData) {

				// Check column type and insert the data accordingly
				switch (columnTypes[c]) {

					// Convert numeric types to unquoted strings
					case 0:
						[rowValues addObject:[cellData description]];
						break;

					// Quote string, text and blob types appropriately
					case 1:
					case 2:
						if ([cellData isKindOfClass:nsDataClass]) {
							[rowValues addObject:[mySQLConnection escapeAndQuoteData:cellData]];
						} else {
							[rowValues addObject:[mySQLConnection escapeAndQuoteString:[cellData description]]];
						}
						break;

					// GEOMETRY
					case 3:
						[rowValues addObject:[mySQLConnection escapeAndQuoteData:[cellData data]]];
						break;
					// Unhandled cases - abort
					default:
						NSBeep();
						free(columnMappings);
						free(columnTypes);
						[rowValues release];
						return nil;
				}

			// If nil is encountered, abort
			} 
			else {
				NSBeep();
				free(columnMappings);
				free(columnTypes);
				[rowValues release];
				return nil;
			}
		}

		// Add to the string in comma-separated form, and increment the string length
		[value appendString:[rowValues componentsJoinedByString:@", "]];
		[rowValues release];

		// Close this VALUES group and set up the next one if appropriate
		if (rowCounter != penultimateRowIndex) {

			// Add a new INSERT starter command every ~250k of data.
			if ([value length] > 250000) {
				[result appendFormat:@"%@);\n\nINSERT INTO %@ (%@)\nVALUES\n",
						value,
						[(selectedTable == nil) ? @"<table>" : selectedTable backtickQuotedString],
						[tbHeader componentsJoinedAndBacktickQuoted]];
				[value setString:@""];
			} 
			else {
				[value appendString:@"),\n"];
			}

		} 
		else {
			[value appendString:@"),\n"];
			[result appendString:value];
		}

		// Get the next selected row index
		rowIndex = [selectedRows indexGreaterThanIndex:rowIndex];
	}

	// Remove the trailing ",\n" from the query string
	if ([result length] > 3) {
		[result deleteCharactersInRange:NSMakeRange([result length]-2, 2)];
	}

	[result appendString:@";\n"];

	free(columnMappings);
	free(columnTypes);

	return result;
}

/**
 * Allow for drag-n-drop out of the application as a copy
 */
- (NSDragOperation) draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return NSDragOperationCopy;
}

/**
 * Get dragged rows a string of newline separated lines of tab separated fields
 * the value in each field is from the objects description method
 */
- (NSString *) draggedRowsAsTabString
{
	NSArray *columns = [self tableColumns];
	NSUInteger numColumns = [columns count];
	NSIndexSet *selectedRows = [self selectedRowIndexes];

	NSMutableString *result = [NSMutableString stringWithCapacity:2000];

	// Create an array of table column mappings for fast iteration
	NSUInteger *columnMappings = calloc(numColumns, sizeof(NSUInteger));
	for (NSUInteger ci = 0; ci < numColumns; ci++ )
		columnMappings[ci] = (NSUInteger)[[NSArrayObjectAtIndex(columns, ci) identifier] integerValue];

	// Loop through the rows, adding their descriptive contents
	NSString *nullString = [prefs objectForKey:SPNullValue];
	Class nsDataClass = [NSData class];
	Class spmysqlGeometryData = [SPMySQLGeometryData class];
	NSStringEncoding connectionEncoding = [mySQLConnection stringEncoding];
	[selectedRows enumerateIndexesUsingBlock:^(NSUInteger rowIndex, BOOL * _Nonnull stop) {
		for (NSUInteger c = 0; c < numColumns; c++ ) {
			id cellData = SPDataStorageObjectAtRowAndColumn(tableStorage, rowIndex, columnMappings[c]);

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
				}
				else if ([cellData isKindOfClass:spmysqlGeometryData]) {
					[result appendFormat:@"%@\t", [cellData wktString]];
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
	}];

	// Trim the trailing line ending
	if ([result length]) {
		[result deleteCharactersInRange:NSMakeRange([result length]-1, 1)];
	}

	free(columnMappings);

	return result;
}

#pragma mark -

/**
 * Init self with data coming from the table content view. Mainly used for copying data properly.
 */
- (void) setTableInstance:(id)anInstance withTableData:(SPDataStorage *)theTableStorage withColumns:(NSArray *)columnDefs withTableName:(NSString *)aTableName withConnection:(id)aMySqlConnection
{
	selectedTable     = aTableName;
	mySQLConnection   = aMySqlConnection;
	tableInstance     = anInstance;
	tableStorage	  = theTableStorage;

	if (columnDefinitions) SPClear(columnDefinitions);
	columnDefinitions = [[NSArray alloc] initWithArray:columnDefs];
}

/*
 * Update the table storage location if necessary.
 */
- (void) setTableData:(SPDataStorage *)theTableStorage
{
	tableStorage = theTableStorage;
}

#pragma mark -

/**
 * Autodetect column widths for a specified font.
 */
- (NSDictionary *) autodetectColumnWidths
{
	NSMutableDictionary *columnWidths = [NSMutableDictionary dictionaryWithCapacity:[columnDefinitions count]];
	NSUInteger columnWidth;
	NSUInteger allColumnWidths = 0;

	// Determine the available size
	NSScrollView *parentScrollView = (NSScrollView*)[[self superview] superview];
 	CGFloat visibleTableWidth = [parentScrollView bounds].size.width - [NSScroller scrollerWidth] - [columnDefinitions count] * 3.5f;

	for (NSDictionary *columnDefinition in columnDefinitions) {
		if ([[NSThread currentThread] isCancelled]) return nil;

		columnWidth = [self autodetectWidthForColumnDefinition:columnDefinition maxRows:100];
		[columnWidths setObject:[NSString stringWithFormat:@"%llu", (unsigned long long)columnWidth] forKey:[columnDefinition objectForKey:@"datacolumnindex"]];
		allColumnWidths += columnWidth;
	}

	// Compare the column widths to the table width.  If wider, narrow down wide columns as necessary
	if (allColumnWidths > visibleTableWidth) {
		NSUInteger availableWidthToReduce = 0;

		// Look for columns that are wider than the multi-column max
		for (NSString *columnIdentifier in columnWidths) {
			columnWidth = [[columnWidths objectForKey:columnIdentifier] integerValue];
			if (columnWidth > SP_MAX_CELL_WIDTH_MULTICOLUMN) availableWidthToReduce += columnWidth - SP_MAX_CELL_WIDTH_MULTICOLUMN;
		}

		// Determine how much width can be reduced
		NSUInteger widthToReduce = allColumnWidths - visibleTableWidth;
		if (availableWidthToReduce < widthToReduce) widthToReduce = availableWidthToReduce;

		// Proportionally decrease the column sizes
		if (widthToReduce) {
			NSArray *columnIdentifiers = [columnWidths allKeys];
			for (NSString *columnIdentifier in columnIdentifiers) {
				columnWidth = [[columnWidths objectForKey:columnIdentifier] integerValue];
				if (columnWidth > SP_MAX_CELL_WIDTH_MULTICOLUMN) {
					columnWidth -= ceilf((double)(columnWidth - SP_MAX_CELL_WIDTH_MULTICOLUMN) / availableWidthToReduce * widthToReduce);
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
	unichar breakChar;
#ifndef SP_CODA /* patch */
	NSFont *tableFont = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPGlobalResultTableFont]];
#else
	NSFont *tableFont = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
#endif
	NSUInteger columnIndex = (NSUInteger)[[columnDefinition objectForKey:@"datacolumnindex"] integerValue];
	NSDictionary *stringAttributes = @{NSFontAttributeName : tableFont};
	Class spmysqlGeometryData = [SPMySQLGeometryData class];

	// Check the number of rows available to check, sampling every n rows
	if ([tableStorage count] < rowsToCheck)
		rowStep = 1;
	else
		rowStep = floorf([tableStorage count] / rowsToCheck);

	rowsToCheck = [tableStorage count];

	// Set a default padding for this column
	columnBaseWidth = 24;

	// Iterate through the data store rows, checking widths
	maxCellWidth = 0;
	for (i = 0; i < rowsToCheck; i += rowStep) {

		// Retrieve part of the cell's content to get widths, topping out at a maximum length
		contentString =	SPDataStoragePreviewAtRowAndColumn(tableStorage, i, columnIndex, 500);

		// If the cell hasn't loaded yet, skip processing
		if (!contentString)
			continue;

		// Get WKT string out of the SPMySQLGeometryData for calculation
		else if ([contentString isKindOfClass:spmysqlGeometryData])
			contentString = [contentString wktString];

		// Replace NULLs with their placeholder string
		else if ([contentString isNSNull]) {
			contentString = [prefs objectForKey:SPNullValue];

		// Same for cells for which loading has been deferred - likely blobs
		} else if ([contentString isSPNotLoaded]) {
			contentString = NSLocalizedString(@"(not loaded)", @"value shown for hidden blob and text fields");

		} else {

			// Otherwise, ensure the cell is represented as a short string
			if ([contentString isKindOfClass:[NSData class]]) {
				contentString = [contentString shortStringRepresentationUsingEncoding:[mySQLConnection stringEncoding]];
			} else if ([(NSString *)contentString length] > 500) {
				contentString = [contentString substringToIndex:500];
			}

			// If any linebreaks are present, they are displayed as single characters; replace them with pilcrow/
			// reverse pilcrow to match display output width.
			linebreakRange = [contentString rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet] options:NSLiteralSearch];
			if (linebreakRange.location != NSNotFound) {
				NSMutableString *singleLineString = [[[NSMutableString alloc] initWithString:contentString] autorelease];
				while (linebreakRange.location != NSNotFound) {
					breakChar = [singleLineString characterAtIndex:linebreakRange.location];
					switch (breakChar) {
						case '\n':
							[singleLineString replaceCharactersInRange:linebreakRange withString:@"¶"];
							break;
						default:
							[singleLineString replaceCharactersInRange:linebreakRange withString:@"⁋"];
							if (breakChar == '\r' && NSMaxRange(linebreakRange) < [singleLineString length] && [singleLineString characterAtIndex:linebreakRange.location+1] == '\n') {
								[singleLineString deleteCharactersInRange:NSMakeRange(linebreakRange.location+1, 1)];
							}
					}
					linebreakRange = [singleLineString rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet] options:NSLiteralSearch];
				}
				contentString = singleLineString;
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
	cellWidth = [[columnDefinition objectForKey:@"name"] sizeWithAttributes:@{NSFontAttributeName : [NSFont labelFontOfSize:[NSFont smallSystemFontSize]]}].width;
	if (cellWidth + 10 > maxCellWidth) maxCellWidth = cellWidth + 10;

	return maxCellWidth;
}

#pragma mark -

- (NSMenu *)menuForEvent:(NSEvent *)event 
{
	NSMenu *menu = [self menu];
#ifndef SP_CODA /* menuForEvent: */

	if(![[self delegate] isKindOfClass:[SPCustomQuery class]] && ![[self delegate] isKindOfClass:[SPTableContent class]]) return menu;

	[SPAppDelegate reloadBundles:self];

	// Remove 'Bundles' sub menu and separator
	NSMenuItem *bItem = [menu itemWithTag:10000000];
	if(bItem) {
		NSInteger sepIndex = [menu indexOfItem:bItem]-1;
		[menu removeItemAtIndex:sepIndex];
		[menu removeItem:bItem];
	}

	NSArray *bundleCategories = [SPAppDelegate bundleCategoriesForScope:SPBundleScopeDataTable];
	NSArray *bundleItems = [SPAppDelegate bundleItemsForScope:SPBundleScopeDataTable];

	// Add 'Bundles' sub menu
	if(bundleItems && [bundleItems count]) {
		[menu addItem:[NSMenuItem separatorItem]];

		NSMenu *bundleMenu = [[[NSMenu alloc] init] autorelease];
		NSMenuItem *bundleSubMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Bundles", @"bundles menu item label") action:nil keyEquivalent:@""];
		[bundleSubMenuItem setTag:10000000];

		[menu addItem:bundleSubMenuItem];
		[menu setSubmenu:bundleMenu forItem:bundleSubMenuItem];

		NSMutableArray *categorySubMenus = [NSMutableArray array];
		NSMutableArray *categoryMenus = [NSMutableArray array];
		if([bundleCategories count]) {
			for(NSString* title in bundleCategories) {
				[categorySubMenus addObject:[[[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""] autorelease]];
				[categoryMenus addObject:[[[NSMenu alloc] init] autorelease]];
				[bundleMenu addItem:[categorySubMenus lastObject]];
				[bundleMenu setSubmenu:[categoryMenus lastObject] forItem:[categorySubMenus lastObject]];
			}
		}

		NSInteger i = 0;
		for(NSDictionary *item in bundleItems) {

			NSString *keyEq;
			if([item objectForKey:SPBundleFileKeyEquivalentKey])
				keyEq = [[item objectForKey:SPBundleFileKeyEquivalentKey] objectAtIndex:0];
			else
				keyEq = @"";

			NSMenuItem *mItem = [[[NSMenuItem alloc] initWithTitle:[item objectForKey:SPBundleInternLabelKey] action:@selector(executeBundleItemForDataTable:) keyEquivalent:keyEq] autorelease];

			if([keyEq length])
				[mItem setKeyEquivalentModifierMask:[[[item objectForKey:SPBundleFileKeyEquivalentKey] objectAtIndex:1] intValue]];

			if([item objectForKey:SPBundleFileTooltipKey])
				[mItem setToolTip:[item objectForKey:SPBundleFileTooltipKey]];

			[mItem setTag:1000000 + i++];

			if([item objectForKey:SPBundleFileCategoryKey]) {
				[[categoryMenus objectAtIndex:[bundleCategories indexOfObject:[item objectForKey:SPBundleFileCategoryKey]]] addItem:mItem];
			} else {
				[bundleMenu addItem:mItem];
			}
		}

		[bundleSubMenuItem release];
	}
#endif
	return menu;

}

- (void)selectTableRows:(NSArray*)rowIndices
{
	if (!rowIndices || ![rowIndices count]) return;

	NSMutableIndexSet *selection = [NSMutableIndexSet indexSet];

	NSInteger rows = [(id<NSTableViewDataSource>)[self delegate] numberOfRowsInTableView:self];

	NSInteger i;
	
	if(rows > 0) {
		for (NSString* idx in rowIndices) 
		{
			i = [idx integerValue];
			
			if (i >= 0 && i < rows) {
				[selection addIndex:i];
		}
		}

		[self selectRowIndexes:selection byExtendingSelection:NO];
	}
}

/**
 * Only have the copy menu item enabled when row(s) are selected in
 * supported tables.
 */
- (BOOL)validateMenuItem:(NSMenuItem*)anItem
{
#ifndef SP_CODA /* validateMenuItem: */
	NSInteger menuItemTag = [anItem tag];

	if ([anItem action] == @selector(performFindPanelAction:)) {
		return (menuItemTag == 1 && [[self delegate] isKindOfClass:[SPTableContent class]]);
	}

	// Don't validate anything other than the copy commands
	if (menuItemTag != SPEditMenuCopy && menuItemTag != SPEditMenuCopyWithColumns && menuItemTag != SPEditMenuCopyAsSQL) {
		return YES;
	}

	// Don't enable menus for relations or triggers - no action to take yet
	if ([[self delegate] isKindOfClass:[SPTableRelations class]] || [[self delegate] isKindOfClass:[SPTableTriggers class]]) {
		return NO;
	}

	// Enable the Copy [with column names] commands if a row is selected
	if (menuItemTag == SPEditMenuCopy || menuItemTag == SPEditMenuCopyWithColumns) {
		return ([self numberOfSelectedRows] > 0);
	}

	// Enable the Copy as SQL commands if rows are selected and column definitions are available
	if (menuItemTag == SPEditMenuCopyAsSQL) {
		return (columnDefinitions != nil && [self numberOfSelectedRows] > 0);
	}
#endif
#ifdef SP_CODA
	if ( [anItem action] == @selector(selectAll:) )
		return YES;
		
	if ( [anItem action] == @selector(delete:) )
	{
		if ( [self numberOfSelectedRows] > 0 )
			return YES;
	}
#endif
	return NO;
}

/**
 * Trap the enter, escape, tab and arrow keys, overriding default behaviour and continuing/ending editing,
 * only within the current row.
 */
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	NSInteger row, column;

	row = [self editedRow];
	column = [self editedColumn];

	// Trap tab key
	// -- for handling of blob fields and to check if it's editable look at [[self delegate] control:textShouldBeginEditing:]
	if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(insertTab:)] )
	{
		[[control window] makeFirstResponder:control];

		// Save the current line if it's the last field in the table
		if ( [self numberOfColumns] - 1 == column ) {
			if([[self delegate] respondsToSelector:@selector(saveRowToTable)])
				[(SPTableContent*)[self delegate] saveRowToTable];
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
			if([[self delegate] respondsToSelector:@selector(saveRowToTable)])
				[(SPTableContent*)([self delegate]) saveRowToTable];
			[[self window] makeFirstResponder:self];
		} else {
			// Select the previous field for editing
			[self editColumn:column-1 row:row withEvent:nil select:YES];
		}

		return YES;
	}

	// Trap enter key
	else if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(insertNewline:)] )
	{
		// If enum field is edited RETURN selects the new value instead of saving the entire row
		if([self isCellComplex])
			return YES;

		[[control window] makeFirstResponder:control];
		if([[self delegate] isKindOfClass:[SPTableContent class]] && ![self isCellEditingMode] && [[self delegate] respondsToSelector:@selector(saveRowToTable)])
			[(SPTableContent*)[self delegate] saveRowToTable];
		
		return YES;
	}

	// Trap down arrow key
	else if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(moveDown:)] )
	{
		// If enum field is edited ARROW key navigates through the popup list
		if([self isCellComplex])
			return NO;

		// Check whether the editor is multiline - if so, allow the arrow down to change selection if it's not
		// on the final line
		if (NSMaxRange([[textView string] lineRangeForRange:[textView selectedRange]]) < [[textView string] length])
			return NO;

		NSInteger newRow = row+1;

		// Check if we're already at the end of the list
		if (newRow >= [(id<NSTableViewDataSource>)[self delegate] numberOfRowsInTableView:self]) return YES;

		[[control window] makeFirstResponder:control];
		
		if ([[self delegate] isKindOfClass:[SPTableContent class]] && ![self isCellEditingMode] && [[self delegate] respondsToSelector:@selector(saveRowToTable)]) {
			[(SPTableContent*)([self delegate]) saveRowToTable];
		}

		// Check again. saveRowToTable could reload the table and change the number of rows
		if (newRow>=[(id<NSTableViewDataSource>)[self delegate] numberOfRowsInTableView:self]) return YES;

		// The column count could change too
		if (tableStorage && (NSUInteger)column >= [tableStorage columnCount]) return YES;

		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
		[self editColumn:column row:newRow withEvent:nil select:YES];
		
		return YES;
	}
	// Trap up arrow key
	else if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(moveUp:)] )
	{
		// If enum field is edited ARROW key navigates through the popup list
		if ([self isCellComplex]) return NO;

		// Check whether the editor is multiline - if so, allow the arrow up to change selection if it's not
		// on the first line
		if ([[textView string] lineRangeForRange:[textView selectedRange]].location > 0) return NO;

		// Already at the beginning of the list
		if (row == 0) return YES;

		NSInteger newRow = row-1;

		[[control window] makeFirstResponder:control];

		if ([[self delegate] isKindOfClass:[SPTableContent class]] && ![self isCellEditingMode] && [[self delegate] respondsToSelector:@selector(saveRowToTable)]) {
			[(SPTableContent *)[self delegate] saveRowToTable];
		}

		// saveRowToTable could reload the table and change the number of rows
		if (newRow >= [(id<NSTableViewDataSource>)[self delegate] numberOfRowsInTableView:self]) return YES;
		
		// The column count could change too
		if (tableStorage && (NSUInteger)column>=[tableStorage columnCount]) return YES;

		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
		[self editColumn:column row:newRow withEvent:nil select:YES];
		
		return YES;
	}

	return NO;
}

- (void)keyDown:(NSEvent *)theEvent
{
	// RETURN or ENTER invoke editing mode for selected row
	// by calling tableView:shouldEditTableColumn: to validate

	if([self numberOfSelectedRows] == 1 && ([theEvent keyCode] == 36 || [theEvent keyCode] == 76)) {
		[self editColumn:0 row:[self selectedRow] withEvent:nil select:YES];
		return;
	}
	
	// Check if ESCAPE is hit and use it to cancel row editing if supported
	if ([theEvent keyCode] == 53 && [[self delegate] respondsToSelector:@selector(cancelRowEditing)])
	{
		if ([[self delegate] performSelector:@selector(cancelRowEditing)]) return;
	}

	else if ([theEvent keyCode] == 48 && ([[self delegate] isKindOfClass:[SPCustomQuery class]] 
		|| [[self delegate] isKindOfClass:[SPTableContent class]])) {
		[self editColumn:0 row:[self selectedRow] withEvent:nil select:YES];
		return;
	}

	[super keyDown:theEvent];
}

#pragma mark -
#pragma mark Field editing checks

/**
 * Determine whether to use the sheet for editing; do so if the multipleLineEditingButton is enabled,
 * or if the column was a blob or a text, or if it contains linebreaks.
 */
- (BOOL)shouldUseFieldEditorForRow:(NSUInteger)rowIndex column:(NSUInteger)colIndex checkWithLock:(pthread_mutex_t *)dataLock
{
	// Return YES if the multiple line editing button is enabled - triggers sheet editing on all cells.
#ifndef SP_CODA
	if ([prefs boolForKey:SPEditInSheetEnabled]) return YES;
#endif
	
	// Retrieve the column definition
	NSDictionary *columnDefinition = [[(id <SPDatabaseContentViewDelegate>)[self delegate] dataColumnDefinitions] objectAtIndex:colIndex];
	NSString *columnType = [columnDefinition objectForKey:@"typegrouping"];

	// If the column is a BLOB or TEXT column, and not an enum, trigger sheet editing
	BOOL isBlob = ([columnType isEqualToString:@"textdata"] || [columnType isEqualToString:@"blobdata"]);
	if (isBlob && ![columnType isEqualToString:@"enum"]) return YES;

	// Otherwise, check the cell value for newlines.
	id cellValue = nil;

	// If a data lock was supplied, use it and perform additional checks for safety
	if (dataLock) {
		pthread_mutex_lock(dataLock);

		if (rowIndex < [tableStorage count] && colIndex < [tableStorage columnCount]) {
			cellValue = [tableStorage cellDataAtRow:rowIndex column:colIndex];
		}

		pthread_mutex_unlock(dataLock);

		if (!cellValue) return YES;

	// Otherwise grab the value directly
	} else {
		cellValue = [tableStorage cellDataAtRow:rowIndex column:colIndex];
	}

	if ([cellValue isKindOfClass:[NSData class]]) {
		cellValue = [[[NSString alloc] initWithData:cellValue encoding:[mySQLConnection stringEncoding]] autorelease];
	}

	if (![cellValue isNSNull]
		&& [columnType isEqualToString:@"string"]
		&& [cellValue rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet] options:NSLiteralSearch].location != NSNotFound)
	{
		return YES;
	}

	// Otherwise, use standard editing
	return NO;
}

#pragma mark -
#pragma mark Bundle Command Support

- (IBAction)executeBundleItemForDataTable:(id)sender
{
#ifndef SP_CODA /* executeBundleItemForDataTable: */
	NSInteger idx = [sender tag] - 1000000;
	NSString *infoPath = nil;
	NSArray *bundleItems = [SPAppDelegate bundleItemsForScope:SPBundleScopeDataTable];
	if(idx >=0 && idx < (NSInteger)[bundleItems count]) {
		infoPath = [[bundleItems objectAtIndex:idx] objectForKey:SPBundleInternPathToFileKey];
	} else {
		if([sender tag] == 0 && [[sender toolTip] length]) {
			infoPath = [sender toolTip];
		}
	}

	if(!infoPath) {
		NSBeep();
		return;
	}

	NSError *readError = nil;
	NSString *convError = nil;
	NSPropertyListFormat format;
	NSDictionary *cmdData = nil;
	NSData *pData = [NSData dataWithContentsOfFile:infoPath options:NSUncachedRead error:&readError];

	cmdData = [[NSPropertyListSerialization propertyListFromData:pData 
			mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError] retain];

	if(!cmdData || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {
		NSLog(@"“%@” file couldn't be read.", infoPath);
		NSBeep();
		if (cmdData) [cmdData release];
		return;
	} else {
		if([cmdData objectForKey:SPBundleFileCommandKey] && [(NSString *)[cmdData objectForKey:SPBundleFileCommandKey] length]) {

			NSString *cmd = [cmdData objectForKey:SPBundleFileCommandKey];
			NSString *inputAction = @"";
			NSString *inputFallBackAction = @"";
			NSError *err = nil;
			NSString *uuid = [NSString stringWithNewUUID];
			NSString *bundleInputFilePath = [NSString stringWithFormat:@"%@_%@", SPBundleTaskInputFilePath, uuid];
			NSString *bundleInputTableMetaDataFilePath = [NSString stringWithFormat:@"%@_%@", SPBundleTaskTableMetaDataFilePath, uuid];

			[[NSFileManager defaultManager] removeItemAtPath:bundleInputFilePath error:nil];

			if([cmdData objectForKey:SPBundleFileInputSourceKey])
				inputAction = [[cmdData objectForKey:SPBundleFileInputSourceKey] lowercaseString];
			if([cmdData objectForKey:SPBundleFileInputSourceFallBackKey])
				inputFallBackAction = [[cmdData objectForKey:SPBundleFileInputSourceFallBackKey] lowercaseString];

			NSMutableDictionary *env = [NSMutableDictionary dictionary];
			[env setObject:[infoPath stringByDeletingLastPathComponent] forKey:SPBundleShellVariableBundlePath];
			[env setObject:bundleInputFilePath forKey:SPBundleShellVariableInputFilePath];

			if ([[self delegate] respondsToSelector:@selector(usedQuery)] && [(id <SPDatabaseContentViewDelegate>)[self delegate] usedQuery]) {
				[env setObject:[(id <SPDatabaseContentViewDelegate>)[self delegate] usedQuery] forKey:SPBundleShellVariableUsedQueryForTable];
			}

			[env setObject:bundleInputTableMetaDataFilePath forKey:SPBundleShellVariableInputTableMetaData];
			[env setObject:SPBundleScopeDataTable forKey:SPBundleShellVariableBundleScope];

			if([self numberOfSelectedRows]) {
				NSMutableArray *sel = [NSMutableArray array];
				NSIndexSet *selectedRows = [self selectedRowIndexes];
				[selectedRows enumerateIndexesUsingBlock:^(NSUInteger rowIndex, BOOL * _Nonnull stop) {
					[sel addObject:[NSString stringWithFormat:@"%llu", (unsigned long long)rowIndex]];
				}];
				[env setObject:[sel componentsJoinedByString:@"\t"] forKey:SPBundleShellVariableSelectedRowIndices];
			}

			NSError *inputFileError = nil;
			NSString *input = @"";
			NSInteger blobHandling = kBlobExclude;
			if([cmdData objectForKey:SPBundleFileWithBlobKey]) {
				if([[cmdData objectForKey:SPBundleFileWithBlobKey] isEqualToString:SPBundleInputSourceBlobHandlingExclude])
					blobHandling = kBlobExclude;
				else if([[cmdData objectForKey:SPBundleFileWithBlobKey] isEqualToString:SPBundleInputSourceBlobHandlingInclude])
					blobHandling = kBlobInclude;
				else if([[cmdData objectForKey:SPBundleFileWithBlobKey] isEqualToString:SPBundleInputSourceBlobHandlingImageFileReference])
					blobHandling = kBlobAsImageFile;
				else if([[cmdData objectForKey:SPBundleFileWithBlobKey] isEqualToString:SPBundleInputSourceBlobHandlingFileReference])
					blobHandling = kBlobAsFile;
			}

			if(blobHandling != kBlobExclude) {
				NSString *bundleBlobFilePath = [NSString stringWithFormat:@"%@_%@", SPBundleTaskCopyBlobFileDirectory, uuid];
				[env setObject:bundleBlobFilePath forKey:SPBundleShellVariableBlobFileDirectory];
				[self setTmpBlobFileDirectory:bundleBlobFilePath];
			} else {
				[self setTmpBlobFileDirectory:@""];
			}

			if([inputAction isEqualToString:SPBundleInputSourceSelectedTableRowsAsTab]) {
				input = [self rowsAsTabStringWithHeaders:YES onlySelectedRows:YES blobHandling:blobHandling];
			}
			else if([inputAction isEqualToString:SPBundleInputSourceSelectedTableRowsAsCsv]) {
				input = [self rowsAsCsvStringWithHeaders:YES onlySelectedRows:YES blobHandling:blobHandling];
			}
			else if([inputAction isEqualToString:SPBundleInputSourceSelectedTableRowsAsSqlInsert]) {
				input = [self rowsAsSqlInsertsOnlySelectedRows:YES];
			}
			else if([inputAction isEqualToString:SPBundleInputSourceTableRowsAsTab]) {
				input = [self rowsAsTabStringWithHeaders:YES onlySelectedRows:NO blobHandling:blobHandling];
			}
			else if([inputAction isEqualToString:SPBundleInputSourceTableRowsAsCsv]) {
				input = [self rowsAsCsvStringWithHeaders:YES onlySelectedRows:NO blobHandling:blobHandling];
			}
			else if([inputAction isEqualToString:SPBundleInputSourceTableRowsAsSqlInsert]) {
				input = [self rowsAsSqlInsertsOnlySelectedRows:NO];
			}
			
			if(input == nil) input = @"";
			[input writeToFile:bundleInputFilePath
					  atomically:YES
						encoding:NSUTF8StringEncoding
						   error:&inputFileError];
			
			if(inputFileError != nil) {
				NSString *errorMessage  = [inputFileError localizedDescription];
				SPOnewayAlertSheet(
					NSLocalizedString(@"Bundle Error", @"bundle error"),
					[self window],
					[NSString stringWithFormat:@"%@ “%@”:\n%@", NSLocalizedString(@"Error for", @"error for message"), [cmdData objectForKey:@"name"], errorMessage]
				);
				if (cmdData) [cmdData release];
				return;
			}


			// Create an array of table column mappings for fast iteration
			NSArray *columns = [self tableColumns];
			NSUInteger numColumns = [columns count];
			NSUInteger *columnMappings = calloc(numColumns, sizeof(NSUInteger));
			NSUInteger c;
			for ( c = 0; c < numColumns; c++ )
				columnMappings[c] = (NSUInteger)[[NSArrayObjectAtIndex(columns, c) identifier] integerValue];

			NSMutableString *tableMetaData = [NSMutableString string];
			if([[self delegate] isKindOfClass:[SPCustomQuery class]]) {
				[env setObject:@"query" forKey:SPBundleShellVariableDataTableSource];
				
				NSArray *defs = [(id <SPDatabaseContentViewDelegate>)[self delegate] dataColumnDefinitions];
				
				if(defs && [defs count] == numColumns)
					for( c = 0; c < numColumns; c++ ) {
						NSDictionary *col = NSArrayObjectAtIndex(defs, columnMappings[c]);
						[tableMetaData appendFormat:@"%@\t", [col objectForKey:@"type"]];
						[tableMetaData appendFormat:@"%@\t", [col objectForKey:@"typegrouping"]];
						[tableMetaData appendFormat:@"%@\t", ([col objectForKey:@"char_length"]) ? : @""];
						[tableMetaData appendFormat:@"%@\t", [col objectForKey:@"UNSIGNED_FLAG"]];
						[tableMetaData appendFormat:@"%@\t", [col objectForKey:@"AUTO_INCREMENT_FLAG"]];
						[tableMetaData appendFormat:@"%@\t", [col objectForKey:@"PRI_KEY_FLAG"]];
						[tableMetaData appendString:@"\n"];
					}
			}
			else if([[self delegate] isKindOfClass:[SPTableContent class]]) {
				[env setObject:@"content" forKey:SPBundleShellVariableDataTableSource];
				
				NSArray *defs = [(id <SPDatabaseContentViewDelegate>)[self delegate] dataColumnDefinitions];
				
				if(defs && [defs count] == numColumns)
					for( c = 0; c < numColumns; c++ ) {
						NSDictionary *col = NSArrayObjectAtIndex(defs, columnMappings[c]);
						[tableMetaData appendFormat:@"%@\t", [col objectForKey:@"type"]];
						[tableMetaData appendFormat:@"%@\t", [col objectForKey:@"typegrouping"]];
						[tableMetaData appendFormat:@"%@\t", ([col objectForKey:@"length"]) ? : @""];
						[tableMetaData appendFormat:@"%@\t", [col objectForKey:@"unsigned"]];
						[tableMetaData appendFormat:@"%@\t", [col objectForKey:@"autoincrement"]];
						[tableMetaData appendFormat:@"%@\t", ([col objectForKey:@"isprimarykey"]) ? : @"0"];
						[tableMetaData appendFormat:@"%@\n", [col objectForKey:@"comment"]];
					}
			}
			free(columnMappings);

			inputFileError = nil;
			[tableMetaData writeToFile:bundleInputTableMetaDataFilePath
					  atomically:YES
						encoding:NSUTF8StringEncoding
						   error:&inputFileError];
			
			if(inputFileError != nil) {
				NSString *errorMessage  = [inputFileError localizedDescription];
				SPOnewayAlertSheet(
					NSLocalizedString(@"Bundle Error", @"bundle error"),
					[self window],
					[NSString stringWithFormat:@"%@ “%@”:\n%@", NSLocalizedString(@"Error for", @"error for message"), [cmdData objectForKey:@"name"], errorMessage]
				);
				if (cmdData) [cmdData release];
				return;
			}


			NSString *output = [SPBundleCommandRunner runBashCommand:cmd withEnvironment:env 
											atCurrentDirectoryPath:nil 
											callerInstance:[SPAppDelegate frontDocument]
											contextInfo:[NSDictionary dictionaryWithObjectsAndKeys:
													([cmdData objectForKey:SPBundleFileNameKey])?:@"-", @"name",
													NSLocalizedString(@"Data Table", @"data table menu item label"), @"scope",
																	  uuid, SPBundleFileInternalexecutionUUID, nil]
											error:&err];

			[[NSFileManager defaultManager] removeItemAtPath:bundleInputFilePath error:nil];

			NSString *action = SPBundleOutputActionNone;
			if([cmdData objectForKey:SPBundleFileOutputActionKey] && [(NSString *)[cmdData objectForKey:SPBundleFileOutputActionKey] length])
				action = [[cmdData objectForKey:SPBundleFileOutputActionKey] lowercaseString];

			// Redirect due exit code
			if(err != nil) {
				if([err code] == SPBundleRedirectActionNone) {
					action = SPBundleOutputActionNone;
					err = nil;
				}
				else if([err code] == SPBundleRedirectActionReplaceSection) {
					action = SPBundleOutputActionReplaceSelection;
					err = nil;
				}
				else if([err code] == SPBundleRedirectActionReplaceContent) {
					action = SPBundleOutputActionReplaceContent;
					err = nil;
				}
				else if([err code] == SPBundleRedirectActionInsertAsText) {
					action = SPBundleOutputActionInsertAsText;
					err = nil;
				}
				else if([err code] == SPBundleRedirectActionInsertAsSnippet) {
					action = SPBundleOutputActionInsertAsSnippet;
					err = nil;
				}
				else if([err code] == SPBundleRedirectActionShowAsHTML) {
					action = SPBundleOutputActionShowAsHTML;
					err = nil;
				}
				else if([err code] == SPBundleRedirectActionShowAsTextTooltip) {
					action = SPBundleOutputActionShowAsTextTooltip;
					err = nil;
				}
				else if([err code] == SPBundleRedirectActionShowAsHTMLTooltip) {
					action = SPBundleOutputActionShowAsHTMLTooltip;
					err = nil;
				}
			}

			if(err == nil && output) {
				if(![action isEqualToString:SPBundleOutputActionNone]) {
					NSPoint pos = [NSEvent mouseLocation];
					pos.y -= 16;

					if([action isEqualToString:SPBundleOutputActionShowAsTextTooltip]) {
						[SPTooltip showWithObject:output atLocation:pos];
					}

					else if([action isEqualToString:SPBundleOutputActionShowAsHTMLTooltip]) {
						[SPTooltip showWithObject:output atLocation:pos ofType:@"html"];
					}

					else if([action isEqualToString:SPBundleOutputActionShowAsHTML]) {
						BOOL correspondingWindowFound = NO;
						for(id win in [NSApp windows]) {
							if([[win delegate] isKindOfClass:[SPBundleHTMLOutputController class]]) {
								if([[[win delegate] windowUUID] isEqualToString:[cmdData objectForKey:SPBundleFileUUIDKey]]) {
									correspondingWindowFound = YES;
									[[win delegate] displayHTMLContent:output withOptions:nil];
									break;
								}
							}
						}
						if(!correspondingWindowFound) {
							SPBundleHTMLOutputController *bundleController = [[SPBundleHTMLOutputController alloc] init];
							[bundleController setWindowUUID:[cmdData objectForKey:SPBundleFileUUIDKey]];
							[bundleController displayHTMLContent:output withOptions:nil];
							[SPAppDelegate addHTMLOutputController:bundleController];
						}
					}
				}
			} else if([err code] != 9) { // Suppress an error message if command was killed
				NSString *errorMessage  = [err localizedDescription];
				SPOnewayAlertSheet(
					NSLocalizedString(@"BASH Error", @"bash error"),
					[self window],
					[NSString stringWithFormat:@"%@ “%@”:\n%@", NSLocalizedString(@"Error for", @"error for message"), [cmdData objectForKey:@"name"], errorMessage]
				);
			}
		}

		if (cmdData) [cmdData release];
	}
#endif
}

#pragma mark -

- (void)awakeFromNib
{
	columnDefinitions = nil;
	prefs = [[NSUserDefaults standardUserDefaults] retain];

	if ([NSTableView instancesRespondToSelector:@selector(awakeFromNib)]) {
		[super awakeFromNib];
	}
}

- (void)dealloc
{
	if (columnDefinitions) SPClear(columnDefinitions);
#ifndef SP_CODA
	SPClear(prefs);
#endif

	[super dealloc];
}

@end
