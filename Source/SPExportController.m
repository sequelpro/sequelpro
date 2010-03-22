//
//  $Id$
//
//  SPExportController.m
//  sequel-pro
//
//  Created by Ben Perry (benperry.com.au) on 21/02/09.
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

#import "SPExportController.h"
#import "SPCSVExporter.h"
#import "TablesList.h"
#import "SPTableData.h"
#import "TableDocument.h"
#import "TableContent.h"
#import "CustomQuery.h"
#import "SPArrayAdditions.h"
#import "SPStringAdditions.h"
#import "SPConstants.h"
#import "SPGrowlController.h"
#import "SPMainThreadTrampoline.h"

@interface SPExportController (PrivateAPI)

- (void)_initializeExportUsingSelectedOptions;
- (void)_exportTables:(NSArray *)exportTables orDataArray:(NSArray *)dataArray;
- (SPExporter *)_initializeExporterForTable:(NSString *)table orDataArray:(NSArray *)dataArray;
- (NSFileHandle *)_getFileHandleForFilePath:(NSString *)filePath;

@end

@implementation SPExportController

@synthesize tableDocumentInstance;
@synthesize tableContentInstance;
@synthesize customQueryInstance;
@synthesize tableDataInstance;

@synthesize connection;
@synthesize exportToMultipleFiles;
@synthesize exportCancelled;

/**
 * Initializes an instance of SPExportController
 */
- (id)init
{
	if ((self = [super init])) {
		[self setExportCancelled:NO];
		[self setExportToMultipleFiles:YES];
		
		exportType = 0;
		exportTableCount = 0;
		currentTableExportIndex = 0;
		
		exportTypeLabel = @"";
		
		tables = [[NSMutableArray alloc] init];
		exporters = [[NSMutableArray alloc] init];
		operationQueue = [[NSOperationQueue alloc] init];
	}
	
	return self;
}

/**
 * Upon awakening select the first toolbar item
 */
- (void)awakeFromNib
{
	// Upon awakening select the SQL tab
	[exportToolbar setSelectedItemIdentifier:[[[exportToolbar items] objectAtIndex:0] itemIdentifier]];
}

#pragma mark -
#pragma mark IB action methods

/**
 * Display the export window allowing the user to select what and of what type to export.
 */
- (void)export
{
	if (!exportWindow) [NSBundle loadNibNamed:@"ExportDialog" owner:self];
	
	NSUInteger i;
		
	[tables removeAllObjects];
	
	MCPResult *queryResult = (MCPResult *)[[self connection] listTables];
	
	if ([queryResult numOfRows]) [queryResult dataSeek:0];
	
	for (i = 0; i < [queryResult numOfRows]; i++) 
	{
		[tables addObject:[NSMutableArray arrayWithObjects:
						   [NSNumber numberWithBool:YES],
						   NSArrayObjectAtIndex([queryResult fetchRowAsArray], 0),
						   nil]];
	}
	
	[exportTableList reloadData];
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);

	// If found the set the default path to the user's desktop, otherwise use their home directory
	[exportPathField setStringValue:([paths count] > 0) ? [paths objectAtIndex:0] : NSHomeDirectory()];
	
	[NSApp beginSheet:exportWindow
	   modalForWindow:tableWindow
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

/**
 * Closes the export dialog
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:exportWindow returnCode:[sender tag]];
	[exportWindow orderOut:self];
}

/**
 * Change the selected toolbar item.
 */
- (IBAction)switchTab:(id)sender
{
	if ([sender isKindOfClass:[NSToolbarItem class]]) {
		[exportTabBar selectTabViewItemWithIdentifier:[[sender label] lowercaseString]];		
	}
}

/**
 * Enables/disables and shows/hides various interface controls depending on the selected item.
 */
- (IBAction)switchInput:(id)sender
{
	if ([sender isKindOfClass:[NSMatrix class]]) {
		
		NSInteger tag = [[sender selectedCell] tag];
		
		[exportFilePerTableCheck setHidden:(tag != 3)];
		[exportFilePerTableNote  setHidden:(tag != 3)];
		
		[exportTableList setEnabled:(tag == 3)];
	}
}

/**
 * Cancel's the export operation by stopping the current table export loop and marking any current SPExporter
 * NSOperation subclasses as cancelled.
 */
- (IBAction)cancelExport:(id)sender
{
	[self setExportCancelled:YES];
	
	// Cancel all of the currently running operations
	[operationQueue cancelAllOperations];
	
	// Close the progress sheet
	[NSApp endSheet:exportProgressWindow returnCode:0];
	[exportProgressWindow orderOut:self];
}

/**
 *
 */
- (IBAction)changeExportOutputPath:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setCanChooseFiles:NO];
	[panel setCanChooseDirectories:YES];
	[panel setCanCreateDirectories:YES];
	
	[panel beginSheetForDirectory:NSHomeDirectory() 
							 file:nil 
				   modalForWindow:exportWindow 
					modalDelegate:self 
				   didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) 
					  contextInfo:nil];
}

#pragma mark -
#pragma mark Table view datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
{
	return [tables count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{	
	return NSArrayObjectAtIndex([tables objectAtIndex:rowIndex], ([[aTableColumn identifier] isEqualToString:@"switch"]) ? 0 : 1);
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	[[tables objectAtIndex:rowIndex] replaceObjectAtIndex:0 withObject:anObject];
}

#pragma mark -
#pragma mark Table view delegate methods

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
	return (aTableView != exportTableList);
}

- (BOOL)tableView:(NSTableView *)aTableView shouldTrackCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	return (aTableView == exportTableList);
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	[aCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
}

#pragma mark -
#pragma mark Toolbar delegate methods

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	NSMutableArray *items = [NSMutableArray arrayWithCapacity:6];
	
	for (NSToolbarItem *item in [toolbar items])
	{	
		[items addObject:[item itemIdentifier]];
	}
	
    return items;
}

#pragma mark -
#pragma mark Other 

/**
 * Invoked when the user 
 */
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	// Perform the export
	if (returnCode == NSOKButton) {
		
		// Initialize the export after half a second to give the export sheet a chance to close 
		[self performSelector:@selector(_initializeExportUsingSelectedOptions) withObject:nil afterDelay:0.5];
	}
}

/**
 * Invoked when the user dismisses the save panel. Updates the selected directory is they clicked OK.
 */
- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		[exportPathField setStringValue:[panel directory]];
	}
}

#pragma mark -

/**
 * Dealloc
 */
- (void)dealloc
{	
    [tables release], tables = nil;
	[exporters release], exporters = nil;
	[operationQueue release], operationQueue = nil;
	
	[super dealloc];
}

@end

@implementation SPExportController (PrivateAPI)

/**
 *
 */
- (void)_initializeExportUsingSelectedOptions
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
		case SPCustomQueryExport:
			
			break;
		case SPTableExport:
			// Create an array of tables to export
			for (NSMutableArray *table in tables)
			{
				if ([[table objectAtIndex:0] boolValue]) {
					[exportTables addObject:[table objectAtIndex:1]];
				}
			}
			
			break;
	}
	
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
			[self _exportTables:nil orDataArray:[tableContentInstance currentResult]];
			break;
		case SPCustomQueryExport:
			[self _exportTables:nil orDataArray:[customQueryInstance currentResult]];
			break;
		case SPTableExport:
			[self _exportTables:exportTables orDataArray:nil];
			break;
	}
}

/**
 * Exports the contents' of the supplied array of tables. Note that this method currently only supports 
 * exporting in CSV and XML formats.
 */
- (void)_exportTables:(NSArray *)exportTables orDataArray:(NSArray *)dataArray
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
	
	// If the user has selected to only export to a single file or this is a filtered or custom query 
	// export create the single file now and assign it to all subsequently created exporters.
	if ((![self exportToMultipleFiles]) || (exportSource == SPFilteredExport) || (exportSource == SPCustomQueryExport)) {
		
		NSString *filename = @"";
		
		// Determine what the file name should be
		switch (exportSource) 
		{
			case SPFilteredExport:
				filename = [NSString stringWithFormat:@"%@_view", [tableDocumentInstance table]];
				break;
			case SPCustomQueryExport:
				filename = @"query_result";
				break;
			case SPTableExport:
				filename = [tableDocumentInstance database];
				break;
		}
		
		singleFileHandle = [self _getFileHandleForFilePath:[[exportPathField stringValue] stringByAppendingPathComponent:filename]];
	}
	
	// Start the export process depending on the data source
	if (exportSource == SPTableExport) {
		
		// Cache the number of tables being exported
		exportTableCount = [exportTables count];
		
		// Loop through the tables, creating an exporter for each
		for (NSString *table in exportTables) 
		{
			if ([self exportCancelled]) break;
			
			SPExporter *exporter = [self _initializeExporterForTable:table orDataArray:nil];
			
			// If required set the single file handle
			if ((![self exportToMultipleFiles]) || (exportType == SPCSVExport)) {
				[exporter setExportOutputFileHandle:singleFileHandle];
				
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
												  [exportCSVLinesTerminatedField stringValue]] dataUsingEncoding:[exporter exportOutputEncoding]]];
					
					singleFileHeaderHasBeenWritten = YES;
				}
				
			}
						
			[exporters addObject:exporter];
		}		
	}
	else {
		SPExporter *exporter = [self _initializeExporterForTable:nil orDataArray:dataArray];
		
		[exporter setExportOutputFileHandle:singleFileHandle];
		
		[exporters addObject:exporter];
	}
	
	// Add the first exporter to the operation queue
	[operationQueue addOperation:[exporters objectAtIndex:0]];
	
	// Remove the exporter we just added to the operation queue from our list of exporters 
	// so we know it's already been done.
	[exporters removeObjectAtIndex:0];	
}

/**
 *
 */
- (SPExporter *)_initializeExporterForTable:(NSString *)table orDataArray:(NSArray *)dataArray
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
	
	SPExporter *exporter;
	SPCSVExporter *csvExporter;
	
	// Based on the type of export create a new instance of the corresponding exporter and set it's specific options
	switch (exportType)
	{
		case SPSQLExport:
			
			break;
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
			
			[csvExporter setExportOutputEncoding:[MCPConnection encodingForMySQLEncoding:[[tableDocumentInstance connectionEncoding] UTF8String]]];
			[csvExporter setCsvNULLString:[[NSUserDefaults standardUserDefaults] objectForKey:SPNullValue]];
			
			[csvExporter setCsvTableColumnNumericStatus:tableColumnNumericStatus];
			
			// If required create separate files
			if ((exportSource == SPTableExport) && [self exportToMultipleFiles] && (exportTableCount > 0)) {
				exportFile = [[exportPathField stringValue] stringByAppendingPathComponent:table];
								
				fileHandle = [self _getFileHandleForFilePath:exportFile];
			}
			
			exporter = csvExporter;
			
			break;
		case SPXMLExport:
			
			break;
	}
	
	// Set the exporter's generic properties
	[exporter setConnection:connection];
	[exporter setExportOutputFileHandle:fileHandle];
	[exporter setExportUsingLowMemoryBlockingStreaming:([exportProcessLowMemory state] == NSOnState)];
	
	return exporter;
}
	
/**
 *
 */
- (NSFileHandle *)_getFileHandleForFilePath:(NSString *)filePath
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
