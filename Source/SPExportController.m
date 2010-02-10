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
#import "SPArrayAdditions.h"
#import "SPStringAdditions.h"
#import "SPConstants.h"
#import "SPLogger.h"

@interface SPExportController (PrivateAPI)

- (void)_initializeExportUsingSelectedOptions;
- (BOOL)_exportTables:(NSArray *)exportTables;

@end

@implementation SPExportController

@synthesize connection;
@synthesize exportCancelled;

/**
 * Initializes an instance of SPExportController
 */
- (id)init
{
	if ((self = [super init])) {
		[self setExportCancelled:NO];
		
		exportType = 0;
		
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
	
	for ( i = 0 ; i < [queryResult numOfRows] ; i++ ) 
	{
		[tables addObject:[NSMutableArray arrayWithObjects:
						   [NSNumber numberWithBool:YES],
						   NSArrayObjectAtIndex([queryResult fetchRowAsArray], 0),
						   nil]];
	}
	
	[exportTableList reloadData];

	[exportPathField setStringValue:NSHomeDirectory()];
	
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
		
		[exportFilePerTableCheck setHidden:[[sender label] isEqualToString:@"Excel"]];
		[exportFilePerTableNote  setHidden:[[sender label] isEqualToString:@"Excel"]];
	}
}

/**
 *
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
#pragma mark SPExporterDataAccess protocol methods

/**
 *
 */
- (void)exporterProcessWillBegin:(SPExporter *)exporter
{
	//[exportProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): fetching data...", @"text showing that app is fetching data for table dump"), ((unsigned long)(i + 1)), ((unsigned long)tableCount), tableName]];
	[exportProgressText displayIfNeeded];
	
	[exportProgressIndicator setIndeterminate:YES];
	[exportProgressIndicator setUsesThreadedAnimation:YES];
	[exportProgressIndicator startAnimation:self];
	
	[[SPLogger logger] log:[NSString stringWithFormat:@"Exporter started: %@", exporter]];
	
	// Update the progress text and set the progress bar back to determinate
	//[exportProgressText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Table %lu of %lu (%@): Writing...", @"text showing that app is writing data for table export"), ((unsigned long)(i + 1)), ((unsigned long)tableCount), tableName]];
	[exportProgressText displayIfNeeded];
	
	[exportProgressIndicator stopAnimation:self];
	[exportProgressIndicator setUsesThreadedAnimation:NO];
	[exportProgressIndicator setIndeterminate:NO];
	[exportProgressIndicator setDoubleValue:0];
	[exportProgressIndicator displayIfNeeded];
}

/**
 * This method is part of the SPExporterDataAccess protocol. It is called when an expoter completes it's data
 * conversion process and the operation is effectively complete. The resulting data can be accessed via
 * SPExporter's exportData method.
 */
- (void)exporterProcessComplete:(SPExporter *)exporter
{	
	// Do something with the data...
	[[SPLogger logger] log:[NSString stringWithFormat:@"Exporter finished: %@", exporter]];
	
	// If required create a new file for each table being exported
	if ((exportSource == SPTableExport) && ([exportFilePerTableCheck state] == NSOnState)) {
		//NSFileHandle *tableFileHandle = [NSFileHandle fileHandleForWritingAtPath:[exportPathField stringByAppendingPathComponent:[exporter ]];
	}
	
	// If required add the next exporter to the operation queue
	if ([exporters count] > 0) {
		[operationQueue addOperation:[exporters objectAtIndex:0]];
	
		// Remove the exporter we just added to the operation queue from our list of exporters 
		// so we know it's already been done.
		[exporters removeObjectAtIndex:0];
	}
	// Otherwise if the exporter list is empty, close the progress sheet
	else {
		[NSApp endSheet:exportProgressWindow returnCode:0];
		[exportProgressWindow orderOut:self];
	}
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
	
	// Begin the export based on the type
	switch (exportSource) 
	{
		case SPFilteredExport:
			
			break;
		case SPCustomQueryExport:
			
			break;
		case SPTableExport:
			[self _exportTables:exportTables];
			break;
	}
}

/**
 * Exports the contents' of the supplied array of tables. Note that this method currently only supports 
 * exporting in CSV and XML formats.
 */
- (BOOL)_exportTables:(NSArray *)exportTables
{
	NSUInteger i;
	NSDictionary *tableDetails;
	
	// Reset the interface
	[exportProgressTitle setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Exporting %@", @"text showing that the application is importing a supplied format"), @"CSV"]];
	[exportProgressText setStringValue:NSLocalizedString(@"Writing...", @"text showing that app is writing text file")];
	[exportProgressText displayIfNeeded];
	[exportProgressIndicator setDoubleValue:0];
	[exportProgressIndicator displayIfNeeded];
	
	// Open the progress sheet
	[NSApp beginSheet:exportProgressWindow
	   modalForWindow:tableWindow 
		modalDelegate:self
	   didEndSelector:nil 
		  contextInfo:nil];
	
	// Add a dump header to the dump file
	NSMutableString *csvLineEnd = [NSMutableString stringWithString:[exportCSVLinesTerminatedField stringValue]]; 
			
	[csvLineEnd replaceOccurrencesOfString:@"\\t" withString:@"\t"
								   options:NSLiteralSearch
									 range:NSMakeRange(0, [csvLineEnd length])];
	
	[csvLineEnd replaceOccurrencesOfString:@"\\n" withString:@"\n"
								   options:NSLiteralSearch
									 range:NSMakeRange(0, [csvLineEnd length])];
	
	[csvLineEnd replaceOccurrencesOfString:@"\\r" withString:@"\r"
								   options:NSLiteralSearch
									 range:NSMakeRange(0, [csvLineEnd length])];
	
	NSUInteger tableCount = [exportTables count];
	
	/*if ([exportTables count] > 1) {
		[infoString setString:[NSString stringWithFormat:@"Host: %@   Database: %@   Generation Time: %@%@%@",
							  [tableDocumentInstance host], [tableDocumentInstance database], [NSDate date], csvLineEnd, csvLineEnd]];
	}*/
	
	// Loop through the tables
	for (i = 0 ; i < tableCount; i++) 
	{
		if ([self exportCancelled]) break;
		
		// Update the progress text and reset the progress bar to indeterminate status
		NSString *tableName = [exportTables objectAtIndex:i];
		
		// For CSV exports of more than one table, output the name of the table
		/*if (tableCount > 1) {
			[fileHandle writeData:[[NSString stringWithFormat:@"Table %@%@%@", tableName, csvLineEnd, csvLineEnd] dataUsingEncoding:encoding]];
		}*/
		
		// Determine whether this table is a table or a view via the create table command, and get the table details
		MCPResult *queryResult = [connection queryString:[NSString stringWithFormat:@"SHOW CREATE TABLE %@", [tableName backtickQuotedString]]];
		
		[queryResult setReturnDataAsStrings:YES];
		
		if ([queryResult numOfRows]) {
			tableDetails = [NSDictionary dictionaryWithDictionary:[queryResult fetchRowAsDictionary]];
			
			tableDetails = [NSDictionary dictionaryWithDictionary:([tableDetails objectForKey:@"Create View"]) ? [tableDataInstance informationForView:tableName] : [tableDataInstance informationForTable:tableName]];
		}
		
		// Retrieve the table details via the data class, and use it to build an array containing column numeric status
		NSMutableArray *tableColumnNumericStatus = [NSMutableArray array];
		
		for (NSDictionary *column in [tableDetails objectForKey:@"columns"])
		{
			NSString *tableColumnTypeGrouping = [column objectForKey:@"typegrouping"];
			
			[tableColumnNumericStatus addObject:[NSNumber numberWithBool:([tableColumnTypeGrouping isEqualToString:@"bit"] || 
																		  [tableColumnTypeGrouping isEqualToString:@"integer"] || 
																		  [tableColumnTypeGrouping isEqualToString:@"float"])]]; 
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
				
				[csvExporter setCsvTableName:tableName];
				
				[csvExporter setCsvOutputFieldNames:[exportCSVIncludeFieldNamesCheck state]];
				[csvExporter setCsvFieldSeparatorString:[exportCSVFieldsTerminatedField stringValue]];
				[csvExporter setCsvEnclosingCharacterString:[exportCSVFieldsWrappedField stringValue]];
				[csvExporter setCsvLineEndingString:[exportCSVLinesTerminatedField stringValue]];
				[csvExporter setCsvEscapeString:[exportCSVFieldsEscapedField stringValue]];
				
				[csvExporter setExportOutputEncoding:[MCPConnection encodingForMySQLEncoding:[[tableDocumentInstance connectionEncoding] UTF8String]]];
				[csvExporter setCsvNULLString:[[NSUserDefaults standardUserDefaults] objectForKey:SPNullValue]];
				
				[csvExporter setCsvTableColumnNumericStatus:tableColumnNumericStatus];
				
				exporter = csvExporter;
				
				break;
			case SPXMLExport:
				
				break;
			case SPPDFExport:
				
				break;
			case SPHTMLExport:
				
				break;
			case SPExcelExport:
				
				break;
		}
		
		// Set the exporter's generic properties
		[exporter setConnection:connection];
		[exporter setExportUsingLowMemoryBlockingStreaming:([exportProcessLowMemory state] == NSOnState)];
				
		[exporters addObject:exporter];
		
		// Add a spacer to the file
		//[fileHandle writeData:[[NSString stringWithFormat:@"%@%@%@", csvLineEnd, csvLineEnd, csvLineEnd] dataUsingEncoding:encoding]];
	}
	
	// Add the first exporter to the operation queue
	[operationQueue addOperation:[exporters objectAtIndex:0]];
	
	// Remove the exporter we just added to the operation queue from our list of exporters 
	// so we know it's already been done.
	[exporters removeObjectAtIndex:0];
	
	return YES;
}

@end
