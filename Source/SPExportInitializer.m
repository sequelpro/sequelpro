//
//  $Id$
//
//  SPExporterInitializer.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on March 31, 2010
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

#import <MCPKit/MCPKit.h>

#import "SPExporterInitializer.h"
#import "SPStringAdditions.h"
#import "SPTableData.h"
#import "TableDocument.h"
#import "SPGrowlController.h"
#import "SPMainThreadTrampoline.h"
#import "TableDocument.h"
#import "CustomQuery.h"

#import "SPCSVExporter.h"
#import "SPSQLExporter.h"
#import "SPXMLExporter.h"

@implementation SPExportController (SPExporterInitializer)

/**
 * Initializes the export process by analysing the selected criteria.
 */
- (void)initializeExportUsingSelectedOptions
{
	// First determine what type of export the user selected
	for (NSToolbarItem *item in [exportToolbar items])
	{
		if ([[item itemIdentifier] isEqualToString:[exportToolbar selectedItemIdentifier]]) {
			exportType = [item tag];
			break;
		}
	}
	
	// Determine what data to use (filtered result, custom query result or selected table(s)) for the export operation
	exportSource = ([exportInputMatrix selectedRow] + 1);
	
	NSMutableArray *exportTables = [NSMutableArray array];
	
	// Set whether or not we are to export to multiple files
	[self setExportToMultipleFiles:[exportFilePerTableCheck state]];
	
	// Get the data depending on the source
	switch (exportSource) 
	{
		case SPFilteredExport:
			
			break;
		case SPQueryExport:
			
			break;
		case SPTableExport:
			// Create an array of tables to export
			for (NSMutableArray *table in tables)
			{
				if (exportType == SPSQLExport) {
					if ([[table objectAtIndex:1] boolValue] || [[table objectAtIndex:2] boolValue] || [[table objectAtIndex:3] boolValue]) {
						[exportTables addObject:table];
					}
				}
				else {
					if ([[table objectAtIndex:2] boolValue]) {
						[exportTables addObject:[table objectAtIndex:0]];
					}
				}
			}
			break;
	}
	
	NSLog(@"tables = %@", exportTables);
	
	// Set the type label 
	switch (exportType)
	{
		case SPSQLExport:
			exportTypeLabel = @"SQL";
			break;
		case SPCSVExport:
			exportTypeLabel = @"CSV";
			break;
		case SPXMLExport:
			exportTypeLabel = @"XML";
			break;
			
	}
	
	// Begin the export based on the source
	switch (exportSource) 
	{
		case SPFilteredExport:
			[self exportTables:nil orDataArray:[tableContentInstance currentResult]];
			break;
		case SPQueryExport:
			[self exportTables:nil orDataArray:[customQueryInstance currentResult]];
			break;
		case SPTableExport:
			[self exportTables:exportTables orDataArray:nil];
			break;
	}
}

/**
 * Exports the contents' of the supplied array of tables or data array.
 */
- (void)exportTables:(NSArray *)exportTables orDataArray:(NSArray *)dataArray
{
	NSUInteger i;
	NSFileHandle *singleFileHandle = nil;
	BOOL singleFileHeaderHasBeenWritten = NO;
	
	[tableDocumentInstance setQueryMode:SPImportExportQueryMode];
	
	// Start the notification timer to allow notifications to be shown even if frontmost for long queries
	[[SPGrowlController sharedGrowlController] setVisibilityForNotificationName:@"Export Finished"];
	
	// Reset the interface
	[[exportProgressTitle onMainThread] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Exporting %@", @"text showing that the application is importing a supplied format"), exportTypeLabel]];		
	[[exportProgressText onMainThread] setStringValue:NSLocalizedString(@"Writing...", @"text showing that app is writing text file")];
	
	[[exportProgressText onMainThread] displayIfNeeded];
	[[exportProgressIndicator onMainThread] setDoubleValue:0];
	[[exportProgressIndicator onMainThread] displayIfNeeded];
	
	// Open the progress sheet
	[NSApp beginSheet:exportProgressWindow
	   modalForWindow:tableWindow 
		modalDelegate:self
	   didEndSelector:nil 
		  contextInfo:nil];
	
	SPExporter *exporter;
	
	// CSV export
	if (exportType == SPCSVExport) {
		
		SPCSVExporter *csvExporter = nil;
		
		// If the user has selected to only export to a single file or this is a filtered or custom query 
		// export create the single file now and assign it to all subsequently created exporters.
		if ((![self exportToMultipleFiles]) || (exportSource == SPFilteredExport) || (exportSource == SPQueryExport)) {
			
			NSString *filename = @"";
			
			// Determine what the file name should be
			switch (exportSource) 
			{
				case SPFilteredExport:
					filename = [NSString stringWithFormat:@"%@_view", [tableDocumentInstance table]];
					break;
				case SPQueryExport:
					filename = @"query_result";
					break;
				case SPTableExport:
					filename = [tableDocumentInstance database];
					break;
			}
			
			singleFileHandle = [self getFileHandleForFilePath:[[exportPathField stringValue] stringByAppendingPathComponent:filename]];
		}
		
		// Start the export process depending on the data source
		if (exportSource == SPTableExport) {
			
			// Cache the number of tables being exported
			exportTableCount = [exportTables count];
			
			// Loop through the tables, creating an exporter for each
			for (NSString *table in exportTables) 
			{
				if ([self exportCancelled]) break;
				
				csvExporter = [self initializeCSVExporterForTable:table orDataArray:nil];
				
				// If required write the single file handle for CSV exports
				if (![self exportToMultipleFiles]) {
					[csvExporter setExportOutputFileHandle:singleFileHandle];
					
					if (!singleFileHeaderHasBeenWritten) {
						// Write the file header and the first table name
						[singleFileHandle writeData:[[NSMutableString stringWithFormat:@"%@: %@   %@: %@    %@: %@%@%@%@ %@%@%@",
													  NSLocalizedString(@"Host", @"csv export host heading"),
													  [tableDocumentInstance host], 
													  NSLocalizedString(@"Database", @"csv export database heading"),
													  [tableDocumentInstance database], 
													  NSLocalizedString(@"Generation Time", @"csv export generation time heading"),
													  [NSDate date], 
													  [exportCSVLinesTerminatedField stringValue], 
													  [exportCSVLinesTerminatedField stringValue],
													  NSLocalizedString(@"Table", @"csv export table heading"),
													  table,
													  [exportCSVLinesTerminatedField stringValue], 
													  [exportCSVLinesTerminatedField stringValue]] dataUsingEncoding:NSUTF8StringEncoding]];
						
						singleFileHeaderHasBeenWritten = YES;
					}
				}
			}		
		}
		else {
			csvExporter = [self initializeCSVExporterForTable:nil orDataArray:dataArray];
			
			[csvExporter setExportOutputFileHandle:singleFileHandle];
		}
		
		exporter = csvExporter;
	}
	// SQL export
	else if (exportType == SPSQLExport) {
		
		// Cache the number of tables being exported
		exportTableCount = [exportTables count];
		
		SPSQLExporter *sqlExporter = [[SPSQLExporter alloc] initWithDelegate:self];
				
		[sqlExporter setSqlDatabaseHost:[tableDocumentInstance host]];
		[sqlExporter setSqlDatabaseName:[tableDocumentInstance database]];
		[sqlExporter setSqlDatabaseVersion:[tableDocumentInstance mySQLVersion]];
		
		[sqlExporter setSqlOutputIncludeUTF8BOM:[exportUseUTF8BOMButton state]];
		/*[sqlExporter setSqlOutputIncludeStructure:[exportSQLIncludeStructureCheck state]];
		[sqlExporter setSqlOutputIncludeContent:[exportSQLIncludeContentCheck state]];
		[sqlExporter setSqlOutputIncludeDropSyntax:[exportSQLIncludeDropSyntaxCheck state]];*/
		[sqlExporter setSqlOutputIncludeErrors:[exportSQLIncludeErrorsCheck state]];
		
		// Cache the current connection encoding then change it to UTF-8 to allow SQL dumps to work
		sqlPreviousConnectionEncoding = [tableDocumentInstance connectionEncoding];
		sqlPreviousConnectionEncodingViaLatin1 = [tableDocumentInstance connectionEncodingViaLatin1:nil];
		
		[tableDocumentInstance setConnectionEncoding:@"utf8" reloadingViews:NO];
		
		NSMutableArray *tableTypes = [[NSMutableArray alloc] init];
		NSMutableDictionary *infoDict = [[NSMutableDictionary alloc] init];
		
		// Build the table information dictionary as well as the table array with item type
		for (NSArray *table in exportTables)
		{
			[infoDict setObject:[tableDataInstance informationForTable:[table objectAtIndex:0]] forKey:[table objectAtIndex:0]];
		}
		
		[sqlExporter setSqlTableInformation:infoDict];
		[sqlExporter setSqlExportTables:exportTables];
		
		[infoDict release];
		[tableTypes release];
		
		NSFileHandle *fileHandle = [self getFileHandleForFilePath:[[exportPathField stringValue] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@.sql", [tableDocumentInstance database], [[NSDate date] descriptionWithCalendarFormat:@"%Y-%m-%d" timeZone:nil locale:nil]]]];
				
		[sqlExporter setExportOutputFileHandle:fileHandle];
		
		exporter = sqlExporter;
	}
	
	// Set the exporter's generic properties
	[exporter setConnection:connection];
	[exporter setExportOutputEncoding:[connection encoding]];
	[exporter setExportUsingLowMemoryBlockingStreaming:([exportProcessLowMemoryButton state] == NSOnState)];
	
	[exporters addObject:exporter];
	
	// Add the first exporter to the operation queue
	[operationQueue addOperation:[exporters objectAtIndex:0]];
	
	// Remove the exporter we just added to the operation queue from our list of exporters 
	// so we know it's already been done.
	[exporters removeObjectAtIndex:0];	
}

/**
 *
 */
- (SPCSVExporter *)initializeCSVExporterForTable:(NSString *)table orDataArray:(NSArray *)dataArray
{
	NSString *exportFile = @"";
	NSFileHandle *fileHandle = nil;
	
	NSDictionary *tableDetails = [NSDictionary dictionary];
	NSMutableArray *tableColumnNumericStatus = [NSMutableArray array];
	
	if (exportSource == SPTableExport) {
		
		// Determine whether the supplied table is actually a table or a view via the CREATE TABLE command, and get the table details
		MCPResult *queryResult = [connection queryString:[NSString stringWithFormat:@"SHOW CREATE TABLE %@", [table backtickQuotedString]]];
		
		[queryResult setReturnDataAsStrings:YES];
		
		if ([queryResult numOfRows]) {
			tableDetails = [NSDictionary dictionaryWithDictionary:[queryResult fetchRowAsDictionary]];
			
			tableDetails = [NSDictionary dictionaryWithDictionary:([tableDetails objectForKey:@"Create View"]) ? [tableDataInstance informationForView:table] : [tableDataInstance informationForTable:table]];
		}
		
		// Retrieve the table details via the data class, and use it to build an array containing column numeric status
		for (NSDictionary *column in [tableDetails objectForKey:@"columns"])
		{
			NSString *tableColumnTypeGrouping = [column objectForKey:@"typegrouping"];
			
			[tableColumnNumericStatus addObject:[NSNumber numberWithBool:([tableColumnTypeGrouping isEqualToString:@"bit"] || 
																		  [tableColumnTypeGrouping isEqualToString:@"integer"] || 
																		  [tableColumnTypeGrouping isEqualToString:@"float"])]]; 
		}
	}
	
	// Exporter references
	SPExporter *exporter = nil;
	SPCSVExporter *csvExporter = nil;
	SPSQLExporter *sqlExporter = nil;
	
	// Based on the type of export create a new instance of the corresponding exporter and set it's specific options
	switch (exportType)
	{
		case SPCSVExport:
			csvExporter = [[SPCSVExporter alloc] initWithDelegate:self];
			
			// Depeding on the export source, set the table name or result array
			if (exportSource == SPTableExport) {
				[csvExporter setCsvTableName:table];
			}
			else {
				[csvExporter setCsvDataArray:dataArray];
			}
			
			[csvExporter setCsvOutputFieldNames:[exportCSVIncludeFieldNamesCheck state]];
			[csvExporter setCsvFieldSeparatorString:[exportCSVFieldsTerminatedField stringValue]];
			[csvExporter setCsvEnclosingCharacterString:[exportCSVFieldsWrappedField stringValue]];
			[csvExporter setCsvLineEndingString:[exportCSVLinesTerminatedField stringValue]];
			[csvExporter setCsvEscapeString:[exportCSVFieldsEscapedField stringValue]];
			
			[csvExporter setCsvNULLString:[exportCSVNULLValuesAsTextField stringValue]];
			
			[csvExporter setCsvTableColumnNumericStatus:tableColumnNumericStatus];
			
			// If required create separate files
			if ((exportSource == SPTableExport) && [self exportToMultipleFiles] && (exportTableCount > 0)) {
				exportFile = [[exportPathField stringValue] stringByAppendingPathComponent:table];
				
				fileHandle = [self getFileHandleForFilePath:exportFile];
			
				[csvExporter setExportOutputFileHandle:fileHandle];
			}
			
			exporter = csvExporter;
			
			break;
		case SPXMLExport:
			
			break;
	}
	
	return [exporter autorelease];
}

/**
 *
 */
- (NSFileHandle *)getFileHandleForFilePath:(NSString *)filePath
{
	NSFileHandle *fileHandle = nil;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if ([fileManager fileExistsAtPath:filePath]) {
		if ((![fileManager isWritableFileAtPath:filePath]) || (!(fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath]))) {
			SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
							  NSLocalizedString(@"Couldn't replace the file. Be sure that you have the necessary privileges.", @"message of panel when file cannot be replaced"));
			return nil;
		}
		
		// Truncates the file to zero bytes
		[fileHandle truncateFileAtOffset:0];
	} 
	// Otherwise attempt to create a file
	else {
		if (![fileManager createFileAtPath:filePath contents:[NSData data] attributes:nil]) {
			SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
							  NSLocalizedString(@"Couldn't write to file. Be sure that you have the necessary privileges.", @"message of panel when file cannot be written"));
			return nil;
		}
		
		// Retrieve a filehandle for the file, attempting to delete it on failure.
		fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
		
		if (!fileHandle) {
			[[NSFileManager defaultManager] removeFileAtPath:filePath handler:nil];
			
			SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
							  NSLocalizedString(@"Couldn't write to file. Be sure that you have the necessary privileges.", @"message of panel when file cannot be written"));
			return nil;
		}
	}
	
	return fileHandle;
}

@end
