//
//  $Id$
//
//  SPExportController.m
//  sequel-pro
//
//  Created by Ben Perry (benperry.com.au) on 21/02/09.
//  Modified by Stuart Connolly (stuconnolly.com)
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

#import "SPExportController.h"
#import "SPExportInitializer.h"
#import "SPTablesList.h"
#import "SPTableData.h"
#import "SPTableContent.h"
#import "SPArrayAdditions.h"
#import "SPStringAdditions.h"
#import "SPConstants.h"
#import "SPGrowlController.h"

@interface SPExportController (PrivateAPI)

- (void)_updateDisplayedExportFilename;
- (NSString *)_generateDefaultExportFilename;

- (void)_toggleExportButton:(id)uiStateDict;
- (void)_toggleExportButtonOnBackgroundThread;
- (void)_toggleExportButtonWithBool:(NSNumber *)enable;

- (void)_resizeWindowForCustomFilenameViewByHeightDelta:(NSInteger)delta;
- (void)_resizeWindowForAdvancedOptionsViewByHeightDelta:(NSInteger)delta;

@end

@implementation SPExportController

@synthesize connection;
@synthesize exportToMultipleFiles;
@synthesize exportCancelled;

#pragma mark -
#pragma mark Initialization

/**
 * Initializes an instance of SPExportController
 */
- (id)init
{
	if (self = [super initWithWindowNibName:@"ExportDialog"]) {
		
		[self setExportCancelled:NO];
		[self setExportToMultipleFiles:YES];
		
		exportType = SPSQLExport;
		exportSource = SPTableExport;
		exportTableCount = 0;
		currentTableExportIndex = 0;
		
		exportFilename = [[NSMutableString alloc] init];
		exportTypeLabel = @"";
		
		createCustomFilename = NO;
		sqlPreviousConnectionEncodingViaLatin1 = NO;
		
		tables = [[NSMutableArray alloc] init];
		exporters = [[NSMutableArray alloc] init];
		exportFiles = [[NSMutableArray alloc] init];
		operationQueue = [[NSOperationQueue alloc] init];
		
		showAdvancedView = NO;
		showCustomFilenameView = NO;
		
		heightOffset = 0;
		windowMinWidth = [[self window] minSize].width;
		windowMinHeigth = [[self window] minSize].height;
		
		prefs = [NSUserDefaults standardUserDefaults];
		
		// Default filename tokens
		availableFilenameTokens = @"host,database,table,date,time";
	}
	
	return self;
}

/**
 * Upon awakening select the first toolbar item
 */
- (void)awakeFromNib
{	
	// Set the current toolbar item
	currentToolbarItem = [[exportToolbar items] objectAtIndex:0];
	
	// Upon awakening select the SQL tab
	[exportToolbar setSelectedItemIdentifier:[currentToolbarItem itemIdentifier]];
	
	// Select the 'selected tables' option
	[exportInputPopUpButton selectItemAtIndex:SPTableExport];
}

#pragma mark -
#pragma mark IB action methods

/**
 * Display the export window allowing the user to select what and of what type to export.
 */
- (void)export
{	
	[self exportTables:nil asFormat:SPSQLExport];
}

/**
 * Displays the export window with the supplied tables and export type/format selected.
 */
- (void)exportTables:(NSArray *)exportTables asFormat:(SPExportType)format
{
	// Set the default export filename
	[self _updateDisplayedExportFilename];
	
	[self refreshTableList:self];
	
	if ([exportFiles count] > 0) [exportFiles removeAllObjects];
			
	// Select the correct tab according to the supplied export type
	[exportToolbar setSelectedItemIdentifier:[[[exportToolbar items] objectAtIndex:(format - 1)] itemIdentifier]];

	// Select the 'selected tables' source option
	[exportInputPopUpButton selectItemAtIndex:SPTableExport];
	
	// If tables were supplied, select them
	if (exportTables) {
		
		// Disable all tables
		for (NSMutableArray *table in tables)
		{
			[table replaceObjectAtIndex:1 withObject:[NSNumber numberWithBool:NO]];
			[table replaceObjectAtIndex:2 withObject:[NSNumber numberWithBool:NO]];
			[table replaceObjectAtIndex:3 withObject:[NSNumber numberWithBool:NO]];
		}
		
		// Select the supplied tables
		for (NSMutableArray *table in tables)
		{
			for (NSString *exportTable in exportTables)
			{
				if ([exportTable isEqualToString:[table objectAtIndex:0]]) {
					[table replaceObjectAtIndex:1 withObject:[NSNumber numberWithBool:YES]];
					[table replaceObjectAtIndex:2 withObject:[NSNumber numberWithBool:YES]];
					[table replaceObjectAtIndex:3 withObject:[NSNumber numberWithBool:YES]];
				}
			}
		}
		
		[exportTableList reloadData];
	}
	
	// Ensure interface validation
	[self switchTab:[[exportToolbar items] objectAtIndex:(format - 1)]];
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
	
	// If found the set the default path to the user's desktop, otherwise use their home directory
	[exportPathField setStringValue:([paths count] > 0) ? [paths objectAtIndex:0] : NSHomeDirectory()];
	
	[NSApp beginSheet:[self window]
	   modalForWindow:[tableDocumentInstance parentWindow]
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

/**
 * Opens the errors sheet and displays the supplied errors string.
 */
- (void)openExportErrorsSheetWithString:(NSString *)errors
{
	[errorsTextView setString:@""];
	[errorsTextView setString:errors];
	
	[NSApp beginSheet:errorsWindow 
	   modalForWindow:[tableDocumentInstance parentWindow] 
		modalDelegate:self 
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
		  contextInfo:nil];
}

/**
 * Displays the export finished Growl notification.
 */
- (void)displayExportFinishedGrowlNotification
{
	// Export finished Growl notification
	[[SPGrowlController sharedGrowlController] notifyWithTitle:@"Export Finished" 
												   description:[NSString stringWithFormat:NSLocalizedString(@"Finished exporting to %@", @"description for finished exporting growl notification"), exportFilename] 
													  document:tableDocumentInstance
											  notificationName:@"Export Finished"];
}

/**
 * Expands the custom filename format based on the selected tokens.
 */
- (NSString *)expandCustomFilenameFormatFromString:(NSString *)format usingTableName:(NSString *)table
{
	NSMutableString *string = [NSMutableString stringWithString:format];
	
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	
	[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	
	[dateFormatter setDateStyle:NSDateFormatterShortStyle];
	[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
	
	[string replaceOccurrencesOfString:@"host" withString:[tableDocumentInstance host]
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [string length])];
	
	[string replaceOccurrencesOfString:@"database" withString:[tableDocumentInstance database]
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [string length])];
	
	if (table) {
		[string replaceOccurrencesOfString:@"table" withString:table
								   options:NSLiteralSearch
									 range:NSMakeRange(0, [string length])];
	}
	else {
		[string replaceOccurrencesOfString:@"table" withString:@""
								   options:NSLiteralSearch
									 range:NSMakeRange(0, [string length])];
	}
	
	[string replaceOccurrencesOfString:@"date" withString:[dateFormatter stringFromDate:[NSDate date]]
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [string length])];
	
	[dateFormatter setDateStyle:NSDateFormatterNoStyle];
	[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
	
	[string replaceOccurrencesOfString:@"time" withString:[dateFormatter stringFromDate:[NSDate date]]
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [string length])];
	
	// Strip comma separators
	[string replaceOccurrencesOfString:@"," withString:@""
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [string length])];
	
	// Replace colons with hyphens
	[string replaceOccurrencesOfString:@":" withString:@"-"
							   options:NSLiteralSearch
								 range:NSMakeRange(0, [string length])];
	
	[dateFormatter release];
	
	return string;
}

/**
 * Closes the export dialog.
 */
- (IBAction)closeSheet:(id)sender
{
	if ([sender window] == [self window]) {
		
		// Close the advanced options view if it's open
		[exportAdvancedOptionsView setHidden:YES];
		[exportAdvancedOptionsViewButton setState:NSOffState];
		
		// Close the customize filename view if it's open
		[exportCustomFilenameView setHidden:YES];
		[exportCustomFilenameViewButton setState:NSOffState];
		
		// If open close the advanced options view and custom filename view
		[self _resizeWindowForAdvancedOptionsViewByHeightDelta:0];
		[self _resizeWindowForCustomFilenameViewByHeightDelta:0];
	}
	
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

/**
 * Change the selected toolbar item.
 */
- (IBAction)switchTab:(id)sender
{	
	if ([sender isKindOfClass:[NSToolbarItem class]]) {
				
		currentToolbarItem = sender;
		
		// Determine what data to use (filtered result, custom query result or selected table(s)) for the export operation
		exportSource = (exportType == SPDotExport) ? SPTableExport : [exportInputPopUpButton indexOfSelectedItem];
		
		// Determine the export type
		exportType = [sender tag];
		
		NSString *label = [[currentToolbarItem label] uppercaseString];
		
		[exportTabBar selectTabViewItemWithIdentifier:[label lowercaseString]];
				
		BOOL isSQL  = (exportType == SPSQLExport);
		BOOL isCSV  = (exportType == SPCSVExport);
		BOOL isXML  = (exportType == SPXMLExport);
		BOOL isHTML = (exportType == SPHTMLExport);
		BOOL isPDF  = (exportType == SPPDFExport);
		BOOL isDot  = (exportType == SPDotExport);
				
		BOOL disable = (isCSV || isXML || isHTML || isPDF || isDot);
		
		[exportFilePerTableCheck setHidden:(isSQL || isDot)];		
		[exportTableList setEnabled:(!isDot)];
		[exportSelectAllTablesButton setEnabled:(!isDot)];
		[exportDeselectAllTablesButton setEnabled:(!isDot)];
		[exportRefreshTablesButton setEnabled:(!isDot)];
		
		[[[exportInputPopUpButton menu] itemAtIndex:SPTableExport] setEnabled:(!isDot)];
		
		[exportInputPopUpButton setEnabled:(!isDot)];
				
		// Enable/disable the 'filtered result' and 'query result' options
		// Note that the result count check is always greater than one as the first row is always the field names
		[[[exportInputPopUpButton menu] itemAtIndex:SPFilteredExport] setEnabled:((!disable) && ([[tableContentInstance currentResult] count] > 1))];
		[[[exportInputPopUpButton menu] itemAtIndex:SPQueryExport] setEnabled:((!disable) && ([[customQueryInstance currentResult] count] > 1))];			
				
		[[exportTableList tableColumnWithIdentifier:@"structure"] setHidden:(isSQL) ? (![exportSQLIncludeStructureCheck state]) : disable];
		[[exportTableList tableColumnWithIdentifier:@"drop"] setHidden:(isSQL) ? (![exportSQLIncludeDropSyntaxCheck state]) : disable];
		
		[[[exportTableList tableColumnWithIdentifier:@"content"] headerCell] setStringValue:(disable) ? @"" : @"C"]; 
		
		[exportCSVNULLValuesAsTextField setStringValue:[prefs stringForKey:SPNullValue]]; 
		[exportXMLNULLValuesAsTextField setStringValue:[prefs stringForKey:SPNullValue]];
		
		if (!showCustomFilenameView) [self _updateDisplayedExportFilename];
	}
}

/**
 * Enables/disables and shows/hides various interface controls depending on the selected item.
 */
- (IBAction)switchInput:(id)sender
{
	if ([sender isKindOfClass:[NSPopUpButton class]]) {
		
		BOOL isSelectedTables = ([sender indexOfSelectedItem] == SPTableExport);
				
		[exportFilePerTableCheck setHidden:(!isSelectedTables) || (exportType == SPSQLExport)];		
		[exportTableList setEnabled:isSelectedTables];
		[exportSelectAllTablesButton setEnabled:isSelectedTables];
		[exportDeselectAllTablesButton setEnabled:isSelectedTables];
		[exportRefreshTablesButton setEnabled:isSelectedTables];
		
		availableFilenameTokens = ([sender indexOfSelectedItem] == SPQueryExport) ? @"host,database,date,time" : @"host,database,table,date,time";
		
		[self _updateDisplayedExportFilename];
	}
}

/**
 * Cancel's the export operation by stopping the current table export loop and marking any current SPExporter
 * NSOperation subclasses as cancelled.
 */
- (IBAction)cancelExport:(id)sender
{
	[self setExportCancelled:YES];
	
	[exportProgressTitle setStringValue:NSLocalizedString(@"Cancelling...", @"cancelling export message")];
	[exportProgressText setStringValue:NSLocalizedString(@"Cleaning up...", @"cancelling export cleaning up message")];
	
	// Disable the cancel button
	[sender setEnabled:NO];
	
	// Cancel all of the currently running operations
	[operationQueue cancelAllOperations];
	
	// Close the progress sheet
	[NSApp endSheet:exportProgressWindow returnCode:0];
	[exportProgressWindow orderOut:self];
	
	// Loop the cached export file paths and remove them from disk if they exist
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	for (NSString *filePath in exportFiles)
	{
		if ([fileManager fileExistsAtPath:filePath]) {
			[[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
		}
	}
	
	// Re-enable the cancel button for future exports
	[sender setEnabled:YES];
}

/**
 * Opens the open panel when user selects to change the output path.
 */
- (IBAction)changeExportOutputPath:(id)sender
{
	[exportCustomFilenameTokenField setStringValue:@""];
	[exportCustomFilenameTokensField setStringValue:availableFilenameTokens];
	
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setCanChooseFiles:NO];
	[panel setCanChooseDirectories:YES];
	[panel setCanCreateDirectories:YES];
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);
	
	[panel beginSheetForDirectory:([paths count] > 0) ? [paths objectAtIndex:0] : NSHomeDirectory() 
							 file:nil 
				   modalForWindow:[self window] 
					modalDelegate:self 
				   didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) 
					  contextInfo:nil];
}

/**
 * Refreshes the table list.
 */
- (IBAction)refreshTableList:(id)sender
{
	NSUInteger i;
	
	[tables removeAllObjects];
	
	// For all modes, retrieve table and view names
	NSArray *tablesAndViews = [tablesListInstance allTableAndViewNames];
	
	for (id itemName in tablesAndViews) {
		[tables addObject:[NSMutableArray arrayWithObjects:
						   itemName, 
						   [NSNumber numberWithBool:YES], 
						   [NSNumber numberWithBool:YES], 
						   [NSNumber numberWithBool:YES], 
						   [NSNumber numberWithInt:SPTableTypeTable], 
						   nil]];
	}
		
	// For SQL only, add procedures and functions
	if ([[[currentToolbarItem label] lowercaseString] isEqualToString:@"sql"]) {
		NSArray *procedures = [tablesListInstance allProcedureNames];
		
		for (id procName in procedures) 
		{
			[tables addObject:[NSMutableArray arrayWithObjects:
							   procName,
							   [NSNumber numberWithBool:YES],
							   [NSNumber numberWithBool:YES],
							   [NSNumber numberWithBool:YES],
							   [NSNumber numberWithInt:SPTableTypeProc], 
							   nil]];
		}
		
		NSArray *functions = [tablesListInstance allFunctionNames];
		
		for (id funcName in functions) 
		{
			[tables addObject:[NSMutableArray arrayWithObjects:
							   funcName,
							   [NSNumber numberWithBool:YES],
							   [NSNumber numberWithBool:YES],
							   [NSNumber numberWithBool:YES],
							   [NSNumber numberWithInt:SPTableTypeFunc], 
							   nil]];
		}	
	}
	
	[exportTableList reloadData];
}

/**
 * Selects or de-selects all tables.
 */
- (IBAction)selectDeselectAllTables:(id)sender
{
	BOOL toggleStructure = NO;
	BOOL toggleDropTable = NO;

	[self refreshTableList:self];

	// Determine whether the structure and drop items should also be toggled
	for (NSToolbarItem *item in [exportToolbar items])
	{
		if ([[item itemIdentifier] isEqualToString:[exportToolbar selectedItemIdentifier]] && [item tag] == SPSQLExport) {
			if ([exportSQLIncludeStructureCheck state]) toggleStructure = YES;
			if ([exportSQLIncludeDropSyntaxCheck state]) toggleDropTable = YES;
			
			break;
		}
	}

	for (NSMutableArray *table in tables)
	{
		if (toggleStructure) [table replaceObjectAtIndex:1 withObject:[NSNumber numberWithBool:[sender tag]]];
		
		[table replaceObjectAtIndex:2 withObject:[NSNumber numberWithBool:[sender tag]]];
		
		if (toggleDropTable) [table replaceObjectAtIndex:3 withObject:[NSNumber numberWithBool:[sender tag]]];
	}
	
	[exportTableList reloadData];
	
	[self _toggleExportButtonOnBackgroundThread];
}

/**
 * Toggles the state of the custom filename format token fields.
 */
- (IBAction)toggleCustomFilenameFormatView:(id)sender
{
	showCustomFilenameView = (!showCustomFilenameView);
	
	[exportCustomFilenameViewButton setState:showCustomFilenameView];
	[exportFilenameDividerBox setHidden:showCustomFilenameView];
	[exportCustomFilenameView setHidden:(!showCustomFilenameView)];
	
	[self _resizeWindowForCustomFilenameViewByHeightDelta:(showCustomFilenameView) ? [exportCustomFilenameView frame].size.height : 0];
		
	// On close update the displayed filename
	if (!showCustomFilenameView) {
		[self _updateDisplayedExportFilename];
	} 
	else {
		[exportCustomFilenameViewLabelButton setTitle:NSLocalizedString(@"Customize Filename", @"default customize file name label")];
	}
}

/**
 * Toggles the display of the advanced options box.
 */
- (IBAction)toggleAdvancedExportOptionsView:(id)sender
{
	showAdvancedView = (!showAdvancedView);
	
	[exportAdvancedOptionsViewButton setState:showAdvancedView];
	[exportAdvancedOptionsView setHidden:(!showAdvancedView)];
	
	[self _resizeWindowForAdvancedOptionsViewByHeightDelta:(showAdvancedView) ? ([exportAdvancedOptionsView frame].size.height + 10) : 0];
}

/**
 * Toggles the export button when choosing to include or table structures in an SQL export.
 */
- (IBAction)toggleSQLIncludeStructure:(id)sender
{
	[[exportTableList tableColumnWithIdentifier:@"structure"] setHidden:(![sender state])];
	
	[self _toggleExportButtonOnBackgroundThread];
}

/**
 * Toggles the export button when choosing to include or exclude table contents in an SQL export.
 */
- (IBAction)toggleSQLIncludeContent:(id)sender
{
	[[exportTableList tableColumnWithIdentifier:@"content"] setHidden:(![sender state])];
	
	[self _toggleExportButtonOnBackgroundThread];
}

/**
 * Toggles the export button when choosing to include or exclude table drop syntax in an SQL export.
 */
- (IBAction)toggleSQLIncludeDropSyntax:(id)sender
{
	[[exportTableList tableColumnWithIdentifier:@"drop"] setHidden:(![sender state])];
	
	[self _toggleExportButtonOnBackgroundThread];
}

#pragma mark -
#pragma mark Table view datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
{
	return [tables count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{		
	return NSArrayObjectAtIndex([tables objectAtIndex:rowIndex], [exportTableList columnWithIdentifier:[tableColumn identifier]]);
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{	
	[[tables objectAtIndex:rowIndex] replaceObjectAtIndex:[exportTableList columnWithIdentifier:[tableColumn identifier]] withObject:anObject];

	[self _toggleExportButtonOnBackgroundThread];
}

#pragma mark -
#pragma mark Table view delegate methods

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)rowIndex
{
	return (tableView != exportTableList);
}

- (BOOL)tableView:(NSTableView *)tableView shouldTrackCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	return (tableView == exportTableList);
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	[aCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
}

#pragma mark -
#pragma mark Toolbar delegate methods

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	NSMutableArray *items = [NSMutableArray array];
	
	for (NSToolbarItem *item in [toolbar items])
	{	
		[items addObject:[item itemIdentifier]];
	}
	
    return items;
}

#pragma mark -
#pragma mark Other 

/**
 * Invoked when the user dismissing the export dialog and starts the export process if required.
 */
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	// Perform the export
	if (returnCode == NSOKButton) {
		
		// Initialize the export after half a second to give the export sheet a chance to close 
		[self performSelector:@selector(initializeExportUsingSelectedOptions) withObject:nil afterDelay:0.5];
	}
}

/**
 * Invoked when the user dismisses the save panel. Updates the selected directory if they clicked OK.
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
	[exportFiles release], exportFiles = nil;
	[operationQueue release], operationQueue = nil;
	[exportFilename release], exportFilename = nil;
	
	if (sqlPreviousConnectionEncoding) [sqlPreviousConnectionEncoding release], sqlPreviousConnectionEncoding = nil;
	
	[super dealloc];
}

#pragma mark -
#pragma mark Private API

/**
 * Updates the displayed export filename, either custom or default.
 */
- (void)_updateDisplayedExportFilename
{	
	NSString *filename = ([[exportCustomFilenameTokenField stringValue] length] > 0) ? [self expandCustomFilenameFormatFromString:[exportCustomFilenameTokenField stringValue] usingTableName:[[tablesListInstance tables] objectAtIndex:1]] : [self _generateDefaultExportFilename]; 
	
	[exportCustomFilenameViewLabelButton setTitle:[NSString stringWithFormat:NSLocalizedString(@"Customize Filename (%@)", @"customize file name label"), filename]];
}

/**
 * Generates the default export filename based on the selected export options.
 */
- (NSString *)_generateDefaultExportFilename
{
	NSString *filename = @"";
	NSString *extension = @"";
	
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
	
	switch (exportType) {
		case SPSQLExport:
			extension = ([exportCompressOutputFile state]) ? @"sql.gz" : @"sql";
			break;
		case SPXMLExport:
			extension = @"xml";
			break;
		case SPDotExport:
			extension = @"dot";
			break;
	}
	
	return ([extension length] > 0) ? [filename stringByAppendingPathExtension:extension] : filename;
}

/**
 * Enables or disables the export button based on the state of various interface controls. 
 */
- (void)_toggleExportButton:(id)uiStateDict
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
	BOOL enable = NO;
	
	BOOL isSQL  = (exportType == SPSQLExport);
	BOOL isCSV  = (exportType == SPCSVExport);
	BOOL isXML  = (exportType == SPXMLExport);
	BOOL isHTML = (exportType == SPHTMLExport);
	BOOL isPDF  = (exportType == SPPDFExport);
	BOOL isDot  = (exportType == SPDotExport);
	
	BOOL structureEnabled = [[uiStateDict objectForKey:@"SQLExportStructureEnabled"] integerValue];
	BOOL contentEnabled   = [[uiStateDict objectForKey:@"SQLExportContentEnabled"] integerValue];
	BOOL dropEnabled      = [[uiStateDict objectForKey:@"SQLExportDropEnabled"] integerValue];
		
	if (isCSV || isXML || isHTML || isPDF || (isSQL && ((!structureEnabled) || (!dropEnabled)))) {
		enable = NO;
		
		// Only enable the button if at least one table is selected
		for (NSArray *table in tables)
		{
			if ([NSArrayObjectAtIndex(table, 2) boolValue]) {
				enable = YES;
				break;
			}
		}
	}
	else if (isSQL) {
		
		// Disable if all are unchecked
		if ((!contentEnabled) && (!structureEnabled) && (!dropEnabled)) {
			enable = NO;
		}
		// Disable if structure is unchecked, but content and drop are as dropping a table then trying to insert
		// into it is obviously an error.
		else if (contentEnabled && (!structureEnabled) && (dropEnabled)) {
			enable = NO;
		}
		else {			
			enable = (contentEnabled || (structureEnabled || dropEnabled));
		}
	}
		
	[self performSelectorOnMainThread:@selector(_toggleExportButtonWithBool:) withObject:[NSNumber numberWithBool:enable] waitUntilDone:NO];
		
	[pool release];
}

/**
 * Calls the above method on a background thread to determine whether or not the export button should be enabled.
 */
- (void)_toggleExportButtonOnBackgroundThread
{
	NSMutableDictionary *uiStateDict = [[NSMutableDictionary alloc] init];
		
	[uiStateDict setObject:[NSNumber numberWithInteger:[exportSQLIncludeStructureCheck state]] forKey:@"SQLExportStructureEnabled"];
	[uiStateDict setObject:[NSNumber numberWithInteger:[exportSQLIncludeContentCheck state]] forKey:@"SQLExportContentEnabled"];
	[uiStateDict setObject:[NSNumber numberWithInteger:[exportSQLIncludeDropSyntaxCheck state]] forKey:@"SQLExportDropEnabled"];
	
	[NSThread detachNewThreadSelector:@selector(_toggleExportButton:) toTarget:self withObject:uiStateDict];
	
	[uiStateDict release];
}

/**
 * Enables or disables the export button based on the supplied number (boolean).
 */
- (void)_toggleExportButtonWithBool:(NSNumber *)enable
{
	[exportButton setEnabled:[enable boolValue]];
}

/**
 * Resizes the export window's height by the supplied delta, while retaining the position of 
 * all interface controls to accommodate the custom filename view.
 */
- (void)_resizeWindowForCustomFilenameViewByHeightDelta:(NSInteger)delta
{
	NSUInteger popUpMask              = [exportInputPopUpButton autoresizingMask];
	NSUInteger fileCheckMask          = [exportFilePerTableCheck autoresizingMask];
	NSUInteger scrollMask             = [exportTablelistScrollView autoresizingMask];
	NSUInteger buttonBarMask          = [exportTableListButtonBar autoresizingMask];
	NSUInteger buttonMask             = [exportCustomFilenameViewButton autoresizingMask];
	NSUInteger textFieldMask          = [exportCustomFilenameViewLabelButton autoresizingMask];
	NSUInteger customFilenameViewMask = [exportCustomFilenameView autoresizingMask];
	NSUInteger tabBarMask             = [exportTabBar autoresizingMask];
	
	NSRect frame = [[self window] frame];
	
	[exportInputPopUpButton setAutoresizingMask:NSViewNotSizable | NSViewMaxYMargin];
	[exportFilePerTableCheck setAutoresizingMask:NSViewNotSizable | NSViewMaxYMargin];
	[exportTablelistScrollView setAutoresizingMask:NSViewNotSizable | NSViewMaxYMargin];
	[exportTableListButtonBar setAutoresizingMask:NSViewNotSizable | NSViewMaxYMargin];
	[exportTabBar setAutoresizingMask:NSViewNotSizable | NSViewMaxYMargin];
	[exportCustomFilenameViewButton setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[exportCustomFilenameViewLabelButton setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[exportCustomFilenameView setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	
	NSInteger newMinHeight = (windowMinHeigth - heightOffset + delta < windowMinHeigth) ? windowMinHeigth : windowMinHeigth - heightOffset + delta;
	
	[[self window] setMinSize:NSMakeSize(windowMinWidth, newMinHeight)];
	
	frame.origin.y += heightOffset;
	frame.size.height -= heightOffset;
	
	heightOffset = delta;
	
	frame.origin.y -= heightOffset;
	frame.size.height += heightOffset;
	
	[[self window] setFrame:frame display:YES animate:YES];
	
	[exportInputPopUpButton setAutoresizingMask:popUpMask];
	[exportFilePerTableCheck setAutoresizingMask:fileCheckMask];
	[exportTablelistScrollView setAutoresizingMask:scrollMask];
	[exportTableListButtonBar setAutoresizingMask:buttonBarMask];
	[exportCustomFilenameViewButton setAutoresizingMask:buttonMask];
	[exportCustomFilenameViewLabelButton setAutoresizingMask:textFieldMask];
	[exportCustomFilenameView setAutoresizingMask:customFilenameViewMask];
	[exportTabBar setAutoresizingMask:tabBarMask];
}

/**
 * Resizes the export window's height by the supplied delta, while retaining the position of 
 * all interface controls to accommodate the advanced options view.
 */
- (void)_resizeWindowForAdvancedOptionsViewByHeightDelta:(NSInteger)delta
{
	NSUInteger scrollMask       = [exportTablelistScrollView autoresizingMask];
	NSUInteger buttonBarMask    = [exportTableListButtonBar autoresizingMask];
	NSUInteger tabBarMask       = [exportTabBar autoresizingMask];
	NSUInteger buttonMask       = [exportAdvancedOptionsViewButton autoresizingMask];
	NSUInteger textFieldMask    = [exportAdvancedOptionsViewLabelButton autoresizingMask];
	NSUInteger advancedViewMask = [exportAdvancedOptionsView autoresizingMask];
	
	NSRect frame = [[self window] frame];
	
	[exportTablelistScrollView setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[exportTableListButtonBar setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[exportTabBar setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[exportAdvancedOptionsViewButton setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[exportAdvancedOptionsViewLabelButton setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[exportAdvancedOptionsView setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	
	NSInteger newMinHeight = (windowMinHeigth - heightOffset + delta < windowMinHeigth) ? windowMinHeigth : windowMinHeigth - heightOffset + delta;
	
	[[self window] setMinSize:NSMakeSize(windowMinWidth, newMinHeight)];
	
	frame.origin.y += heightOffset;
	frame.size.height -= heightOffset;
	
	heightOffset = delta;
	
	frame.origin.y -= heightOffset;
	frame.size.height += heightOffset;
	
	[[self window] setFrame:frame display:YES animate:YES];
	
	[exportTablelistScrollView setAutoresizingMask:scrollMask];
	[exportTableListButtonBar setAutoresizingMask:buttonBarMask];
	[exportTabBar setAutoresizingMask:tabBarMask];
	[exportAdvancedOptionsViewButton setAutoresizingMask:buttonMask];
	[exportAdvancedOptionsViewLabelButton setAutoresizingMask:textFieldMask];
	[exportAdvancedOptionsView setAutoresizingMask:advancedViewMask];
}

@end
