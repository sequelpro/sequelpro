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
#import "SPExportHandlerInstance.h"
#import "SPExportHandlerFactory.h"

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

	// this will also add the next exporter to the operation queue, which is the same we would do here.
	[self exportEnded:nil];
}

/**
 * @see _queueIsEmptyAfterCancelling:
 */
- (void)exportEnded:(SPExporter *)exp
{
	//if there are more exporters left, start with the next one
	if([exporters count]) {

		[operationQueue addOperation:[exporters objectAtIndex:0]];

		// Remove the exporter we just added to the operation queue from our list of exporters
		// so we know it's already been done.
		[exporters removeObjectAtIndex:0];

	}
	//done with everything
	else {
		[self _hideExportProgress];

		// Restore query mode
		[tableDocumentInstance setQueryMode:SPInterfaceQueryMode];

		// Display Growl notification
		[self displayExportFinishedGrowlNotification:[[[exp exportOutputFile] exportFilePath] lastPathComponent]];

		// Restore the connection encoding to it's pre-export value
		[tableDocumentInstance setConnectionEncoding:[NSString stringWithFormat:@"%@%@", previousConnectionEncoding, (previousConnectionEncodingViaLatin1) ? @"-" : @""] reloadingViews:NO];
	}
}

/**
 * Initializes the export process by analysing the selected criteria.
 */
- (void)initializeExportUsingSelectedOptions
{
	// this is down here because the table export can show a message dialog that returns to the export sheet on a shortcut
	if([[self currentExportHandler] respondsToSelector:@selector(didBecomeInactive)]) {
		[[self currentExportHandler] didBecomeInactive];
	}

	NSArray *dataArray = nil;

	// Get rid of the cached connection encoding
	if (previousConnectionEncoding) SPClear(previousConnectionEncoding);

	createCustomFilename = ([[exportCustomFilenameTokenField stringValue] length] > 0);

	NSMutableArray *exportTables = [NSMutableArray array];

	// Get the data depending on the source
	switch (exportSource)
	{
		case SPFilteredExport:
			currentExportFileCountEstimate = 1;
			dataArray = [tableContentInstance currentDataResultWithNULLs:YES hideBLOBs:NO];
			break;
		case SPQueryExport:
			currentExportFileCountEstimate = 1;
			dataArray = [customQueryInstance currentDataResultWithNULLs:YES truncateDataFields:NO];
			break;
		case SPTableExport:
			// Create an array of tables to export
			for (_SPExportListItem *object in exportObjectList)
			{
				if([object isGroupRow]) continue;

				if([[self currentExportHandler] wouldIncludeSchemaObject:object])
					[exportTables addObject:object];
			}
			currentExportFileCountEstimate = ([exportTables count])? (([[[self currentExportHandler] factory] supportsExportToMultipleFiles] && [self exportToMultipleFiles])? [exportTables count] : 1) : 0;
			break;
		case SPDatabaseExport:
			currentExportFileCountEstimate = 0; //can't say what will happen
			; // nothing to do here
	}

	// Set the export type label
	[exportTypeLabel release];
	exportTypeLabel = [[[[self currentExportHandler] factory] localizedShortName] retain];

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
		case SPDatabaseExport:
			[self exportTables:nil orDataArray:nil];
			break;
	}
}

/**
 * Exports the contents of the supplied array of tables or data array.
 *
 *
 * @param exportTables An array of table/view names to be exported (can be nil).
 * @param dataArray    A MySQL result set array to be exported (can be nil).
 */
- (void)exportTables:(NSArray *)exportTables orDataArray:(NSArray *)dataArray
{
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
	
	SPExportersAndFiles pair;
	if(exportTables) {
		NSAssert([[self currentExportHandler] respondsToSelector:@selector(allExportersForSchemaObjects:)],@"Current exporter handler %@ does not implement method for exporting schema objects!",[self currentExportHandler]);
		pair = [[self currentExportHandler] allExportersForSchemaObjects:exportTables];
	}
	else if(dataArray) {
		NSAssert([[self currentExportHandler] respondsToSelector:@selector(allExportersForData:)],@"Current exporter handler %@ does not implement method for exporting table data!",[self currentExportHandler]);
		pair = [[self currentExportHandler] allExportersForData:dataArray];
	}
	else {
		NSAssert([[self currentExportHandler] respondsToSelector:@selector(allExporters)],@"Current exporter handler %@ does not implement method for exporting databases!",[self currentExportHandler]);
		pair = [[self currentExportHandler] allExporters];
	}

	[exporters addObjectsFromArray:pair.exporters];
	[exportFiles addObjectsFromArray:pair.exportFiles];
	
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

@end
