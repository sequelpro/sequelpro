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

#import "SPExportInitializer.h"
#import "SPStringAdditions.h"
#import "SPTableData.h"
#import "SPDatabaseDocument.h"
#import "SPTablesList.h"
#import "SPGrowlController.h"
#import "SPMainThreadTrampoline.h"
#import "SPDatabaseDocument.h"
#import "SPCustomQuery.h"
#import "SPFileHandle.h"
#import "SPAlertSheets.h"

#import "SPCSVExporter.h"
#import "SPSQLExporter.h"
#import "SPXMLExporter.h"
#import "SPDotExporter.h"

@implementation SPExportController (SPExportInitializer)

/**
 * Initializes the export process by analysing the selected criteria.
 */
- (void)initializeExportUsingSelectedOptions
{
	NSArray *dataArray = nil;
	
	// Get rid of the cached connection encoding
	if (sqlPreviousConnectionEncoding) [sqlPreviousConnectionEncoding release], sqlPreviousConnectionEncoding = nil;
	
	createCustomFilename = ([[exportCustomFilenameTokenField stringValue] length] > 0);
	
	NSMutableArray *exportTables = [NSMutableArray array];
	
	// Set whether or not we are to export to multiple files
	[self setExportToMultipleFiles:[exportFilePerTableCheck state]];
	
	// Get the data depending on the source
	switch (exportSource) 
	{
		case SPFilteredExport:
			dataArray = [tableContentInstance currentResult];
			break;
		case SPQueryExport:
			dataArray = [customQueryInstance currentResult];
			break;
		case SPTableExport:
			// Create an array of tables to export
			for (NSMutableArray *table in tables)
			{
				if (exportType == SPSQLExport) {
					if ([[table objectAtIndex:1] boolValue] || [[table objectAtIndex:2] boolValue] || [[table objectAtIndex:3] boolValue]) {

						// Check the overall export settings
						if ([[table objectAtIndex:1] boolValue] && [exportSQLIncludeStructureCheck state] == NSOffState)
							[table replaceObjectAtIndex:1 withObject:[NSNumber numberWithBool:NO]];
						if ([[table objectAtIndex:2] boolValue] && [exportSQLIncludeContentCheck state] == NSOffState)
							[table replaceObjectAtIndex:2 withObject:[NSNumber numberWithBool:NO]];
						if ([[table objectAtIndex:3] boolValue] && [exportSQLIncludeDropSyntaxCheck state] == NSOffState)
							[table replaceObjectAtIndex:3 withObject:[NSNumber numberWithBool:NO]];

						[exportTables addObject:table];
					}
				}
				else if (exportType == SPDotExport) {
					[exportTables addObject:[table objectAtIndex:0]];
				}
				else {
					if ([[table objectAtIndex:2] boolValue]) {
						[exportTables addObject:[table objectAtIndex:0]];
					}
				}
			}
			
			break;
	}
	
	// Set the export type label 
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
		case SPDotExport:
			exportTypeLabel = @"Dot";
			break;
	}
		
	// Begin the export based on the source
	switch (exportSource) 
	{
		case SPFilteredExport:
		case SPQueryExport:
			[self exportTables:nil orDataArray:dataArray];
			break;
		case SPTableExport:
			[self exportTables:exportTables orDataArray:nil];
			break;
	}
}

/**
 * Exports the contents of the supplied array of tables or data array.
 */
- (void)exportTables:(NSArray *)exportTables orDataArray:(NSArray *)dataArray
{
	NSUInteger i;
	SPFileHandle *singleFileHandle = nil;
	BOOL singleFileHeaderHasBeenWritten = NO;
	
	// Change query logging mode
	[tableDocumentInstance setQueryMode:SPImportExportQueryMode];
	
	// Start the notification timer to allow notifications to be shown even if frontmost for long queries
	[[SPGrowlController sharedGrowlController] setVisibilityForNotificationName:@"Export Finished"];
	
	// Reset the progress interface
	[exportProgressTitle setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Exporting %@", @"text showing that the application is importing a supplied format"), exportTypeLabel]];		
	[exportProgressText setStringValue:NSLocalizedString(@"Writing...", @"text showing that app is writing text file")];
	[exportProgressIndicator setDoubleValue:0];
	
	// Open the progress sheet
	[NSApp beginSheet:exportProgressWindow
	   modalForWindow:[tableDocumentInstance parentWindow]
		modalDelegate:self
	   didEndSelector:nil 
		  contextInfo:nil];
	
	// CSV export
	if (exportType == SPCSVExport) {
		
		SPCSVExporter *csvExporter = nil;
		
		// If the user has selected to only export to a single file or this is a filtered or custom query 
		// export, create the single file now and assign it to all subsequently created exporters.
		if ((![self exportToMultipleFiles]) || (exportSource == SPFilteredExport) || (exportSource == SPQueryExport)) {

			// Create custom filename if required
			if (createCustomFilename) {
				[exportFilename setString:[self expandCustomFilenameFormatFromString:[exportCustomFilenameTokenField stringValue] usingTableName:nil]];
			}
			else {
				// Determine what the file name should be
				switch (exportSource) 
				{
					case SPFilteredExport:
						[exportFilename setString:[NSString stringWithFormat:@"%@_view", [tableDocumentInstance table]]];
						break;
					case SPQueryExport:
						[exportFilename setString:@"query_result"];
						break;
					case SPTableExport:
						[exportFilename setString:[tableDocumentInstance database]];
						break;
				}
			}
			
			[exportFilename setString:[exportFilename stringByAppendingPathExtension:[self currentDefaultExportFileExtension]]];
			
			singleFileHandle = [self getFileHandleForFilePath:[[exportPathField stringValue] stringByAppendingPathComponent:exportFilename]];
		}
		
		// Start the export process depending on the data source
		if (exportSource == SPTableExport) {
			
			// Cache the number of tables being exported
			exportTableCount = [exportTables count];
			
			// Loop through the tables, creating an exporter for each
			for (NSString *table in exportTables) 
			{				
				csvExporter = [self initializeCSVExporterForTable:table orDataArray:nil];
				
				// If required create a single file handle for all CSV exports
				if (![self exportToMultipleFiles]) {
					[csvExporter setExportOutputFileHandle:singleFileHandle];
					
					if (!singleFileHeaderHasBeenWritten) {
						
						NSMutableString *lineEnding = [NSMutableString stringWithString:[exportCSVLinesTerminatedField stringValue]];
						
						// Escape tabs, line endings and carriage returns
						[lineEnding replaceOccurrencesOfString:@"\\t" withString:@"\t"
													   options:NSLiteralSearch
														 range:NSMakeRange(0, [lineEnding length])];
						
						
						[lineEnding replaceOccurrencesOfString:@"\\n" withString:@"\n"
													   options:NSLiteralSearch
														 range:NSMakeRange(0, [lineEnding length])];
						
						[lineEnding replaceOccurrencesOfString:@"\\r" withString:@"\r"
													   options:NSLiteralSearch
														 range:NSMakeRange(0, [lineEnding length])];
						
						// Write the file header and the first table name
						[singleFileHandle writeData:[[NSMutableString stringWithFormat:@"%@: %@   %@: %@    %@: %@%@%@%@ %@%@%@",
													  NSLocalizedString(@"Host", @"csv export host heading"),
													  [tableDocumentInstance host], 
													  NSLocalizedString(@"Database", @"csv export database heading"),
													  [tableDocumentInstance database], 
													  NSLocalizedString(@"Generation Time", @"csv export generation time heading"),
													  [NSDate date], 
													  lineEnding, 
													  lineEnding,
													  NSLocalizedString(@"Table", @"csv export table heading"),
													  table,
													  lineEnding, 
													  lineEnding] dataUsingEncoding:[connection encoding]]];
						
						singleFileHeaderHasBeenWritten = YES;
					}
				}
				
				[exporters addObject:csvExporter];
			}		
		}
		else {
			csvExporter = [self initializeCSVExporterForTable:nil orDataArray:dataArray];
			
			[csvExporter setExportOutputFileHandle:singleFileHandle];
			
			[exporters addObject:csvExporter];
		}
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
		[sqlExporter setSqlOutputEncodeBLOBasHex:[exportSQLBLOBFieldsAsHexCheck state]];
		[sqlExporter setSqlOutputIncludeErrors:[exportSQLIncludeErrorsCheck state]];
		
		[sqlExporter setSqlInsertAfterNValue:[exportSQLInsertNValueTextField integerValue]];
		[sqlExporter setSqlInsertDivider:[exportSQLInsertDividerPopUpButton indexOfSelectedItem]];
		
		// Cache the current connection encoding then change it to UTF-8 to allow SQL dumps to work
		sqlPreviousConnectionEncoding = [[NSString alloc] initWithString:[tableDocumentInstance connectionEncoding]];
		sqlPreviousConnectionEncodingViaLatin1 = [tableDocumentInstance connectionEncodingViaLatin1:nil];
				
		[tableDocumentInstance setConnectionEncoding:@"utf8" reloadingViews:NO];
				
		[sqlExporter setSqlExportTables:exportTables];
		
		// Create custom filename if required
		[exportFilename setString:(createCustomFilename) ? [self expandCustomFilenameFormatFromString:[exportCustomFilenameTokenField stringValue] usingTableName:nil] : [NSString stringWithFormat:@"%@_%@", [tableDocumentInstance database], [[NSDate date] descriptionWithCalendarFormat:@"%Y-%m-%d" timeZone:nil locale:nil]]];
		
		[exportFilename setString:[exportFilename stringByAppendingPathExtension:[self currentDefaultExportFileExtension]]];
				
		SPFileHandle *fileHandle = [self getFileHandleForFilePath:[[exportPathField stringValue] stringByAppendingPathComponent:exportFilename]];
				
		[sqlExporter setExportOutputFileHandle:fileHandle];
		
		[exporters addObject:sqlExporter];
		
		[sqlExporter release];
	}
	// XML export
	else if (exportType == SPXMLExport) {
		
		SPXMLExporter *xmlExporter = nil;
		
		// If the user has selected to only export to a single file or this is a filtered or custom query 
		// export, create the single file now and assign it to all subsequently created exporters.
		if ((![self exportToMultipleFiles]) || (exportSource == SPFilteredExport) || (exportSource == SPQueryExport)) {
			
			// Create custom filename if required
			if (createCustomFilename) {
				[exportFilename setString:[self expandCustomFilenameFormatFromString:[exportCustomFilenameTokenField stringValue] usingTableName:nil]];
			}
			else {
				// Determine what the file name should be
				switch (exportSource) 
				{
					case SPFilteredExport:
						[exportFilename setString:[NSString stringWithFormat:@"%@_view", [tableDocumentInstance table]]];
						break;
					case SPQueryExport:
						[exportFilename setString:@"query_result"];
						break;
					case SPTableExport:
						[exportFilename setString:[tableDocumentInstance database]];
						break;
				}
			}
			
			[exportFilename setString:[exportFilename stringByAppendingPathExtension:[self currentDefaultExportFileExtension]]];
			
			singleFileHandle = [self getFileHandleForFilePath:[[exportPathField stringValue] stringByAppendingPathComponent:exportFilename]];
		}
		
		// Start the export process depending on the data source
		if (exportSource == SPTableExport) {
			
			// Cache the number of tables being exported
			exportTableCount = [exportTables count];
			
			// Loop through the tables, creating an exporter for each
			for (NSString *table in exportTables) 
			{				
				xmlExporter = [self initializeXMLExporterForTable:table orDataArray:nil];
				
				// If required create a single file handle for all XML exports 
				if (![self exportToMultipleFiles]) {
					[xmlExporter setExportOutputFileHandle:singleFileHandle];
					
					if (!singleFileHeaderHasBeenWritten) {
						
						// Write the file header
						[self writeXMLHeaderToFileHandle:singleFileHandle];
						
						singleFileHeaderHasBeenWritten = YES;
					}
				}
				
				[exporters addObject:xmlExporter];
			}		
		}
		else {
			xmlExporter = [self initializeXMLExporterForTable:nil orDataArray:dataArray];
			
			[xmlExporter setExportOutputFileHandle:singleFileHandle];
		
			[exporters addObject:xmlExporter];
		}
	}
	// Dot export
	else if (exportType == SPDotExport) {
		
		// Cache the number of tables being exported
		exportTableCount = [exportTables count];
		
		SPDotExporter *dotExporter = [[SPDotExporter alloc] initWithDelegate:self];
		
		[dotExporter setDotTableData:tableDataInstance];
		[dotExporter setDotDatabaseHost:[tableDocumentInstance host]];
		[dotExporter setDotDatabaseName:[tableDocumentInstance database]];
		[dotExporter setDotDatabaseVersion:[tableDocumentInstance mySQLVersion]];
		
		// Cache the current connection encoding then change it to UTF-8 to allow SQL dumps to work
		sqlPreviousConnectionEncoding = [[NSString alloc] initWithString:[tableDocumentInstance connectionEncoding]];
		sqlPreviousConnectionEncodingViaLatin1 = [tableDocumentInstance connectionEncodingViaLatin1:nil];
		
		[tableDocumentInstance setConnectionEncoding:@"utf8" reloadingViews:NO];
		
		[dotExporter setDotExportTables:exportTables];
		
		// Create custom filename if required
		if (createCustomFilename) {
			[exportFilename setString:[self expandCustomFilenameFormatFromString:[exportCustomFilenameTokenField stringValue] usingTableName:nil]];
		}
		else {
			[exportFilename setString:[tableDocumentInstance database]];
		}
		
		[exportFilename setString:[exportFilename stringByAppendingPathExtension:[self currentDefaultExportFileExtension]]];

		SPFileHandle *fileHandle = [self getFileHandleForFilePath:[[exportPathField stringValue] stringByAppendingPathComponent:exportFilename]];
		
		[dotExporter setExportOutputFileHandle:fileHandle];
		
		[exporters addObject:dotExporter];
		
		[dotExporter release];
	}
	
	// For each of the created exporters, set their generic properties
	for (SPExporter *exporter in exporters)
	{
		[exporter setConnection:connection];
		[exporter setExportOutputEncoding:[connection encoding]];
		[exporter setExportMaxProgress:(NSInteger)[exportProgressIndicator bounds].size.width];
		[exporter setExportUsingLowMemoryBlockingStreaming:[exportProcessLowMemoryButton state]];
		[exporter setExportOutputCompressionFormat:[exportOutputCompressionFormatPopupButton indexOfSelectedItem]];
		[exporter setExportOutputCompressFile:([exportOutputCompressionFormatPopupButton indexOfSelectedItem] != SPNoCompression)];
	}
		
	// Add the first exporter to the operation queue
	[operationQueue addOperation:[exporters objectAtIndex:0]];
	
	// Remove the exporter we just added to the operation queue from our list of exporters 
	// so we know it's already been done.
	[exporters removeObjectAtIndex:0];	
}

/**
 * Initialises a CSV exporter for the supplied table name or data array.
 */
- (SPCSVExporter *)initializeCSVExporterForTable:(NSString *)table orDataArray:(NSArray *)dataArray
{
	SPFileHandle *fileHandle = nil;
	
	SPCSVExporter *csvExporter = [[SPCSVExporter alloc] initWithDelegate:self];
	
	// Depeding on the export source, set the table name or data array
	if (exportSource == SPTableExport) {
		[csvExporter setCsvTableName:table];
	}
	else {
		[csvExporter setCsvDataArray:dataArray];
	}
	
	[csvExporter setCsvTableData:tableDataInstance];
	[csvExporter setCsvOutputFieldNames:[exportCSVIncludeFieldNamesCheck state]];
	[csvExporter setCsvFieldSeparatorString:[exportCSVFieldsTerminatedField stringValue]];
	[csvExporter setCsvEnclosingCharacterString:[exportCSVFieldsWrappedField stringValue]];
	[csvExporter setCsvLineEndingString:[exportCSVLinesTerminatedField stringValue]];
	[csvExporter setCsvEscapeString:[exportCSVFieldsEscapedField stringValue]];
	[csvExporter setCsvNULLString:[exportCSVNULLValuesAsTextField stringValue]];
		
	// If required create separate files
	if (exportSource == SPTableExport && [self exportToMultipleFiles]) {
		
		if (createCustomFilename) {
			
			// Create custom filename based on the selected format
			[exportFilename setString:[self expandCustomFilenameFormatFromString:[exportCustomFilenameTokenField stringValue] usingTableName:table]];
			
			// If the user chose to use a custom filename format and we exporting to multiple files, make
			// sure the table name is included to ensure the output files are unique.
			if (exportTableCount > 1) {
				[exportFilename setString:([[exportCustomFilenameTokenField stringValue] rangeOfString:@"table" options:NSLiteralSearch].location == NSNotFound) ? [exportFilename stringByAppendingFormat:@"_%@", table] : exportFilename];
			}
		}
		else {
			[exportFilename setString:(dataArray) ? [tableDocumentInstance database] : table]; 
		}
		
		[exportFilename setString:[exportFilename stringByAppendingPathExtension:[self currentDefaultExportFileExtension]]];
				
		fileHandle = [self getFileHandleForFilePath:[[exportPathField stringValue] stringByAppendingPathComponent:exportFilename]];
		
		[csvExporter setExportOutputFileHandle:fileHandle];
	}
	
	return [csvExporter autorelease];
}

/**
 * Initialises a XML exporter for the supplied table name or data array.
 */
- (SPXMLExporter *)initializeXMLExporterForTable:(NSString *)table orDataArray:(NSArray *)dataArray
{
	SPFileHandle *fileHandle = nil;
	
	SPXMLExporter *xmlExporter = [[SPXMLExporter alloc] initWithDelegate:self];
	
	// Depeding on the export source, set the table name or data array
	if (exportSource == SPTableExport) {
		[xmlExporter setXmlTableName:table];
	}
	else {
		[xmlExporter setXmlDataArray:dataArray];
	}
	
	// Regardless of the export source, set exporter's table name as it's used in the output
	// of table and table content exports.
	[xmlExporter setXmlTableName:[tablesListInstance tableName]];
	
	[xmlExporter setXmlNULLString:[exportXMLNULLValuesAsTextField stringValue]];
	
	// If required create separate files
	if ((exportSource == SPTableExport) && exportToMultipleFiles && (exportTableCount > 0)) {
		[exportFilename setString:[[exportPathField stringValue] stringByAppendingPathComponent:table]];
		[exportFilename setString:[exportFilename stringByAppendingPathExtension:[self currentDefaultExportFileExtension]]];
		
		fileHandle = [self getFileHandleForFilePath:exportFilename];
						
		// Write the file header
		[self writeXMLHeaderToFileHandle:fileHandle];
		
		[xmlExporter setExportOutputFileHandle:fileHandle];
	}
	
	return [xmlExporter autorelease];
}

/**
 * Writes the XML file header to the supplied file handle.
 */
- (void)writeXMLHeaderToFileHandle:(SPFileHandle *)fileHandle
{
	NSMutableString *header = [NSMutableString string];
	
	[header setString:@"<?xml version=\"1.0\"?>\n\n"];
	[header appendString:@"<!--\n-\n"];
	[header appendString:@"- Sequel Pro XML dump\n"];
	[header appendString:[NSString stringWithFormat:@"- Version %@\n-\n", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]]];
	[header appendString:[NSString stringWithFormat:@"- %@\n- %@\n-\n", SPLOCALIZEDURL_HOMEPAGE, SPDevURL]];
	[header appendString:[NSString stringWithFormat:@"- Host: %@ (MySQL %@)\n", [tableDocumentInstance host], [tableDocumentInstance mySQLVersion]]];
	[header appendString:[NSString stringWithFormat:@"- Database: %@\n", [tableDocumentInstance database]]];
	[header appendString:[NSString stringWithFormat:@"- Generation Time: %@\n", [NSDate date]]];
	[header appendString:@"-\n-->\n\n"];
	
	if (exportSource == SPTableExport) {
		[header appendString:[NSString stringWithFormat:@"<%@>\n\n", [[tableDocumentInstance database] HTMLEscapeString]]];
	}
		
	[fileHandle writeData:[header dataUsingEncoding:NSUTF8StringEncoding]];	
}

/**
 * Returns a file handle for writing at the supplied path.
 */
- (SPFileHandle *)getFileHandleForFilePath:(NSString *)path
{
	SPFileHandle *fileHandle = nil;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if ([fileManager fileExistsAtPath:path]) {
		if ((![fileManager isWritableFileAtPath:path]) || (!(fileHandle = [SPFileHandle fileHandleForWritingAtPath:path]))) {
			SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [tableDocumentInstance parentWindow], self, nil, nil,
							  NSLocalizedString(@"Couldn't replace the file. Be sure that you have the necessary privileges.", @"message of panel when file cannot be replaced"));
			return nil;
		}
	} 
	// Otherwise attempt to create a file
	else {
		if (![fileManager createFileAtPath:path contents:[NSData data] attributes:nil]) {
			SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [tableDocumentInstance parentWindow], self, nil, nil,
							  NSLocalizedString(@"Couldn't write to file. Be sure that you have the necessary privileges.", @"message of panel when file cannot be written"));
			return nil;
		}
		
		// Retrieve a filehandle for the file, attempting to delete it on failure.
		fileHandle = [SPFileHandle fileHandleForWritingAtPath:path];
		
		if (!fileHandle) {
			[[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
			
			SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [tableDocumentInstance parentWindow], self, nil, nil,
							  NSLocalizedString(@"Couldn't write to file. Be sure that you have the necessary privileges.", @"message of panel when file cannot be written"));
			return nil;
		}
	}
	
	// Keep a record of the file handle's path in case the user cancels the export then we need to remove
	// it from disk.
	[exportFiles addObject:path];
	
	return fileHandle;
}

@end
