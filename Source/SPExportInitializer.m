//
//  SPExportInitializer.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on March 31, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPExportInitializer.h"
#import "SPTableData.h"
#import "SPDatabaseDocument.h"
#import "SPTablesList.h"
#import "SPGrowlController.h"
#import "SPDatabaseDocument.h"
#import "SPCustomQuery.h"
#import "SPAlertSheets.h"
#import "SPTableContent.h"
#import "SPCSVExporter.h"
#import "SPSQLExporter.h"
#import "SPXMLExporter.h"
#import "SPDotExporter.h"
#import "SPExportFile.h"
#import "SPExportFileUtilities.h"
#import "SPExportFilenameUtilities.h"
#import "SPExportFileNameTokenObject.h"
#import "SPConnectionControllerDelegateProtocol.h"
#import "SPExportController+SharedPrivateAPI.h"
#import "SPSQLExporterDelegate.h"

#import <SPMySQL/SPMySQL.h>

@implementation SPExportController (SPExportInitializer)

/**
 * Starts the export process by placing the first exporter on the operation queue. Also opens the progress
 * sheet if it's not already visible.
 */
- (void)startExport
{
	// Start progress indicator
	[exportProgressTitle setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Exporting %@", @"text showing that the application is importing a supplied format"), exportTypeLabel]];		
	[exportProgressText setStringValue:NSLocalizedString(@"Writing...", @"text showing that app is writing text file")];
	
	[exportProgressIndicator setUsesThreadedAnimation:NO];
	[exportProgressIndicator setIndeterminate:NO];
	[exportProgressIndicator setDoubleValue:0];

	// If it's not already displayed, open the progress sheet
	if (![exportProgressWindow isVisible]) {
		[NSApp beginSheet:exportProgressWindow
		   modalForWindow:[tableDocumentInstance parentWindow]
			modalDelegate:self
		   didEndSelector:nil 
			  contextInfo:nil];
	}

	// cache the current connection encoding so the exporter can do what it wants.
	previousConnectionEncoding = [[NSString alloc] initWithString:[connection encoding]];
	previousConnectionEncodingViaLatin1 = [connection encodingUsesLatin1Transport];
		
	// Add the first exporter to the operation queue
	[operationQueue addOperation:[exporters objectAtIndex:0]];
	
	// Remove the exporter we just added to the operation queue from our list of exporters 
	// so we know it's already been done.
	[exporters removeObjectAtIndex:0];	
}

/**
 * @see _queueIsEmptyAfterCancelling:
 */
- (void)exportEnded
{
	[self _hideExportProgress];

	// Restore query mode
	[tableDocumentInstance setQueryMode:SPInterfaceQueryMode];

	// Display Growl notification
	[self displayExportFinishedGrowlNotification];

	// Restore the connection encoding to it's pre-export value
	[tableDocumentInstance setConnectionEncoding:[NSString stringWithFormat:@"%@%@", previousConnectionEncoding, (previousConnectionEncodingViaLatin1) ? @"-" : @""] reloadingViews:NO];
}

/**
 * Initializes the export process by analysing the selected criteria.
 */
- (void)initializeExportUsingSelectedOptions
{
	NSArray *dataArray = nil;
	
	// Get rid of the cached connection encoding
	if (previousConnectionEncoding) SPClear(previousConnectionEncoding);
	
	createCustomFilename = ([[exportCustomFilenameTokenField stringValue] length] > 0);
	
	NSMutableArray *exportTables = [NSMutableArray array];
	
	// Set whether or not we are to export to multiple files
	[self setExportToMultipleFiles:[exportFilePerTableCheck state]];
	
	// Get the data depending on the source
	switch (exportSource) 
	{
		case SPFilteredExport:
			dataArray = [tableContentInstance currentDataResultWithNULLs:YES hideBLOBs:NO hexBLOBs: [exportCSVBlobsAsHexidecimalCheck state]];
			break;
		case SPQueryExport:
			dataArray = [customQueryInstance currentDataResultWithNULLs:YES truncateDataFields:NO];
			break;
		case SPTableExport:
			// Create an array of tables to export
			for (NSMutableArray *table in tables)
			{
				if (exportType == SPSQLExport) {
					if ([[table objectAtIndex:1] boolValue] || [[table objectAtIndex:2] boolValue] || [[table objectAtIndex:3] boolValue]) {

						// Check the overall export settings
						if ([[table objectAtIndex:1] boolValue] && (![exportSQLIncludeStructureCheck state])) {
							[table replaceObjectAtIndex:1 withObject:@NO];
						}
							
						if ([[table objectAtIndex:2] boolValue] && (![exportSQLIncludeContentCheck state])) {
							[table replaceObjectAtIndex:2 withObject:@NO];
						}
							
						if ([[table objectAtIndex:3] boolValue] && (![exportSQLIncludeDropSyntaxCheck state])) {
							[table replaceObjectAtIndex:3 withObject:@NO];
						}

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
		case SPPDFExport:
		case SPHTMLExport:
		case SPExcelExport:
		default:
			[NSException raise:NSInvalidArgumentException format:@"unsupported exportType=%lu",exportType];
			return;
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
 *
 * Note that at least one of these parameters must not be nil.
 *
 * @param exportTables An array of table/view names to be exported (can be nil).
 * @param dataArray    A MySQL result set array to be exported (can be nil).
 */
- (void)exportTables:(NSArray *)exportTables orDataArray:(NSArray *)dataArray
{
	BOOL singleFileHandleSet = NO;
	SPExportFile *singleExportFile = nil, *file = nil;
	
	// Change query logging mode
	[tableDocumentInstance setQueryMode:SPImportExportQueryMode];
	
	// Start the notification timer to allow notifications to be shown even if frontmost for long queries
	[[SPGrowlController sharedGrowlController] setVisibilityForNotificationName:@"Export Finished"];
	
	// Setup the progress sheet
	[exportProgressTitle setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Exporting %@", @"text showing that the application is importing a supplied format"), exportTypeLabel]];
	[exportProgressText setStringValue:NSLocalizedString(@"Initializing...", @"initializing export label")];
	
	[exportProgressIndicator setIndeterminate:YES];
	[exportProgressIndicator setUsesThreadedAnimation:YES];
	
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
			NSString *selectedTableName = nil;
			
			if (exportSource == SPTableExport && [exportTables count] == 1) selectedTableName = [exportTables objectAtIndex:0];

			[exportFilename setString:createCustomFilename ? [self expandCustomFilenameFormatUsingTableName:selectedTableName] : [self generateDefaultExportFilename]];

			// Only append the extension if necessary
			if (![[exportFilename pathExtension] length]) {
				[exportFilename setString:[exportFilename stringByAppendingPathExtension:[self currentDefaultExportFileExtension]]];
			}

			singleExportFile = [SPExportFile exportFileAtPath:[[exportPathField stringValue] stringByAppendingPathComponent:exportFilename]];
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
					if (!singleFileHandleSet) {
						[singleExportFile setExportFileNeedsCSVHeader:YES];
						
						[exportFiles addObject:singleExportFile];
						
						singleFileHandleSet = YES;
					}
					
					[csvExporter setExportOutputFile:singleExportFile];
				}
				
				[exporters addObject:csvExporter];
			}		
		}
		else {
			csvExporter = [self initializeCSVExporterForTable:nil orDataArray:dataArray];
			
			[exportFiles addObject:singleExportFile];
			
			[csvExporter setExportOutputFile:singleExportFile];
			
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
		[sqlExporter setSqlOutputIncludeAutoIncrement:([exportSQLIncludeStructureCheck state] && [exportSQLIncludeAutoIncrementValueButton state])];
		
		[sqlExporter setSqlInsertAfterNValue:[exportSQLInsertNValueTextField integerValue]];
		[sqlExporter setSqlInsertDivider:[exportSQLInsertDividerPopUpButton indexOfSelectedItem]];
		
		[sqlExporter setSqlExportTables:exportTables];
		
		// Create custom filename if required
		NSString *selectedTableName = (exportSource == SPTableExport && [exportTables count] == 1)? [[exportTables objectAtIndex:0] objectAtIndex:0] : nil;
		[exportFilename setString:(createCustomFilename) ? [self expandCustomFilenameFormatUsingTableName:selectedTableName] : [self generateDefaultExportFilename]];
		
		// Only append the extension if necessary
		if (![[exportFilename pathExtension] length]) {
			[exportFilename setString:[exportFilename stringByAppendingPathExtension:[self currentDefaultExportFileExtension]]];
		}
		
		file = [SPExportFile exportFileAtPath:[[exportPathField stringValue] stringByAppendingPathComponent:exportFilename]];
		
		[exportFiles addObject:file];
		
		[sqlExporter setExportOutputFile:file];
		
		[exporters addObject:sqlExporter];
		
		[sqlExporter release];
	}
	// XML export
	else if (exportType == SPXMLExport) {
		
		SPXMLExporter *xmlExporter = nil;
		
		// If the user has selected to only export to a single file or this is a filtered or custom query 
		// export, create the single file now and assign it to all subsequently created exporters.
		if ((![self exportToMultipleFiles]) || (exportSource == SPFilteredExport) || (exportSource == SPQueryExport)) {
			NSString *selectedTableName = nil;
			if (exportSource == SPTableExport && [exportTables count] == 1) selectedTableName = [exportTables objectAtIndex:0];
			
			[exportFilename setString:(createCustomFilename) ? [self expandCustomFilenameFormatUsingTableName:selectedTableName] : [self generateDefaultExportFilename]];
						
			// Only append the extension if necessary
			if (![[exportFilename pathExtension] length]) {
				[exportFilename setString:[exportFilename stringByAppendingPathExtension:[self currentDefaultExportFileExtension]]];
			}

			singleExportFile = [SPExportFile exportFileAtPath:[[exportPathField stringValue] stringByAppendingPathComponent:exportFilename]];
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
					if (!singleFileHandleSet) {
						[singleExportFile setExportFileNeedsXMLHeader:YES];
						
						[exportFiles addObject:singleExportFile];
						
						singleFileHandleSet = YES;
					}
					
					[xmlExporter setExportOutputFile:singleExportFile];
				}
				
				[exporters addObject:xmlExporter];
			}		
		}
		else {
			xmlExporter = [self initializeXMLExporterForTable:nil orDataArray:dataArray];
			
			[singleExportFile setExportFileNeedsXMLHeader:YES];
			
			[exportFiles addObject:singleExportFile];
			
			[xmlExporter setExportOutputFile:singleExportFile];
		
			[exporters addObject:xmlExporter];
		}		
	}
	// Dot export
	else if (exportType == SPDotExport) {
		
		// Cache the number of tables being exported
		exportTableCount = [exportTables count];
		
		SPDotExporter *dotExporter = [[SPDotExporter alloc] initWithDelegate:self];
		
		[dotExporter setDotTableData:tableDataInstance];
		[dotExporter setDotForceLowerTableNames:[exportDotForceLowerTableNamesCheck state]];
		[dotExporter setDotDatabaseHost:[tableDocumentInstance host]];
		[dotExporter setDotDatabaseName:[tableDocumentInstance database]];
		[dotExporter setDotDatabaseVersion:[tableDocumentInstance mySQLVersion]];

		[dotExporter setDotExportTables:exportTables];
		
		// Create custom filename if required
		if (createCustomFilename) {
			[exportFilename setString:[self expandCustomFilenameFormatUsingTableName:nil]];
		}
		else {
			[exportFilename setString:[tableDocumentInstance database]];
		}
		
		// Only append the extension if necessary
		if (![[exportFilename pathExtension] length]) {
			[exportFilename setString:[exportFilename stringByAppendingPathExtension:[self currentDefaultExportFileExtension]]];
		}
		
		file = [SPExportFile exportFileAtPath:[[exportPathField stringValue] stringByAppendingPathComponent:exportFilename]];
		
		[exportFiles addObject:file];
		
		[dotExporter setExportOutputFile:file];
		
		[exporters addObject:dotExporter];
		
		[dotExporter release];
	}
	
	// For each of the created exporters, set their generic properties
	for (SPExporter *exporter in exporters)
	{
		[exporter setConnection:connection];
		[exporter setServerSupport:[self serverSupport]];
		[exporter setExportOutputEncoding:[connection stringEncoding]];
		[exporter setExportMaxProgress:(NSInteger)[exportProgressIndicator bounds].size.width];
		[exporter setExportUsingLowMemoryBlockingStreaming:([exportProcessLowMemoryButton state] == NSOnState)];
		[exporter setExportOutputCompressionFormat:(SPFileCompressionFormat)[exportOutputCompressionFormatPopupButton indexOfSelectedItem]];
		[exporter setExportOutputCompressFile:([exportOutputCompressionFormatPopupButton indexOfSelectedItem] != SPNoCompression)];
	}
		
	NSMutableArray *problemFiles = [[NSMutableArray alloc] init];
		
	// Create the actual file handles while dealing with errors (e.g. file already exists, etc) during creation
	for (SPExportFile *exportFile in exportFiles)
	{		
		if ([exportFile createExportFileHandle:NO] == SPExportFileHandleCreated) {

			[exportFile setCompressionFormat:(SPFileCompressionFormat)[exportOutputCompressionFormatPopupButton indexOfSelectedItem]];
			
			if ([exportFile exportFileNeedsCSVHeader]) {
				[self writeCSVHeaderToExportFile:exportFile];
			}
			else if ([exportFile exportFileNeedsXMLHeader]) {
				[self writeXMLHeaderToExportFile:exportFile];
			}
		}
		else {
			[problemFiles addObject:exportFile];
		}
	}
	
	// Deal with any file handles that we failed to create for whatever reason
	if ([problemFiles count] > 0) {
		[self errorCreatingExportFileHandles:problemFiles];
	}
	else {
		[self startExport];
	}

	[problemFiles release];
}

/**
 * Initialises a CSV exporter for the supplied table name or data array.
 *
 * @param table     The table name for which the exporter should be cerated for (can be nil).
 * @param dataArray The MySQL result data array for which the exporter should be created for (can be nil).
 */
- (SPCSVExporter *)initializeCSVExporterForTable:(NSString *)table orDataArray:(NSArray *)dataArray
{	
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
	[csvExporter setCsvExportBlobsAsHex:[exportCSVBlobsAsHexidecimalCheck state]];
		
	// If required create separate files
	if (exportSource == SPTableExport && [self exportToMultipleFiles]) {
		
		if (createCustomFilename) {
			
			// Create custom filename based on the selected format
			[exportFilename setString:[self expandCustomFilenameFormatUsingTableName:table]];
			
			// If the user chose to use a custom filename format and we exporting to multiple files, make
			// sure the table name is included to ensure the output files are unique.
			if (exportTableCount > 1) {
				BOOL tableNameInTokens = NO;
				NSArray *representedObjects = [exportCustomFilenameTokenField objectValue];
				for (id representedObject in representedObjects) {
					if ([representedObject isKindOfClass:[SPExportFileNameTokenObject class]] && [[representedObject tokenId] isEqualToString:NSLocalizedString(@"table", @"table")]) tableNameInTokens = YES;
				}
				[exportFilename setString:(tableNameInTokens ? exportFilename : [exportFilename stringByAppendingFormat:@"_%@", table])];
			}
		}
		else {
			[exportFilename setString:(dataArray) ? [tableDocumentInstance database] : table]; 
		}
		
		// Only append the extension if necessary
		if (![[exportFilename pathExtension] length]) {
			[exportFilename setString:[exportFilename stringByAppendingPathExtension:[self currentDefaultExportFileExtension]]];
		}
						
		SPExportFile *file = [SPExportFile exportFileAtPath:[[exportPathField stringValue] stringByAppendingPathComponent:exportFilename]];
		
		[exportFiles addObject:file];
		
		[csvExporter setExportOutputFile:file];
	}
	
	return [csvExporter autorelease];
}

/**
 * Initialises a XML exporter for the supplied table name or data array.
 *
 * @param table     The table name for which the exporter should be cerated for (can be nil).
 * @param dataArray The MySQL result data array for which the exporter should be created for (can be nil).
 */
- (SPXMLExporter *)initializeXMLExporterForTable:(NSString *)table orDataArray:(NSArray *)dataArray
{	
	SPXMLExporter *xmlExporter = [[SPXMLExporter alloc] initWithDelegate:self];
	
	// if required set the data array
	if (exportSource != SPTableExport) {
		[xmlExporter setXmlDataArray:dataArray];
	}
	
	// Regardless of the export source, set exporter's table name as it's used in the output
	// of table and table content exports.
	[xmlExporter setXmlTableName:table];

	[xmlExporter setXmlFormat:[exportXMLFormatPopUpButton indexOfSelectedItem]];
	[xmlExporter setXmlOutputIncludeStructure:[exportXMLIncludeStructure state]];
	[xmlExporter setXmlOutputIncludeContent:[exportXMLIncludeContent state]];
	[xmlExporter setXmlNULLString:[exportXMLNULLValuesAsTextField stringValue]];
	
	// If required create separate files
	if ((exportSource == SPTableExport) && exportToMultipleFiles && (exportTableCount > 0)) {
		
		if (createCustomFilename) {
			
			// Create custom filename based on the selected format
			[exportFilename setString:[self expandCustomFilenameFormatUsingTableName:table]];
			
			// If the user chose to use a custom filename format and we exporting to multiple files, make
			// sure the table name is included to ensure the output files are unique.
			if (exportTableCount > 1) {
				BOOL tableNameInTokens = NO;
				NSArray *representedObjects = [exportCustomFilenameTokenField objectValue];
				for (id representedObject in representedObjects) {
					if ([representedObject isKindOfClass:[SPExportFileNameTokenObject class]] && [[representedObject tokenId] isEqualToString:NSLocalizedString(@"table", @"table")]) tableNameInTokens = YES;
				}
				[exportFilename setString:(tableNameInTokens ? exportFilename : [exportFilename stringByAppendingFormat:@"_%@", table])];
			}
		}
		else {
			[exportFilename setString:(dataArray) ? [tableDocumentInstance database] : table]; 
		}
		
		// Only append the extension if necessary
		if (![[exportFilename pathExtension] length]) {
			[exportFilename setString:[exportFilename stringByAppendingPathExtension:[self currentDefaultExportFileExtension]]];
		}
										
		SPExportFile *file = [SPExportFile exportFileAtPath:[[exportPathField stringValue] stringByAppendingPathComponent:exportFilename]];
		
		[file setExportFileNeedsXMLHeader:YES];
		
		[exportFiles addObject:file];
		
		[xmlExporter setExportOutputFile:file];
	}
	
	return [xmlExporter autorelease];
}

@end
