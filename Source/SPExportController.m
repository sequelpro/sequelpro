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

#import <MCPKit/MCPKit.h>

#import "SPExportController.h"
#import "SPExporterInitializer.h"
#import "TablesList.h"
#import "SPTableData.h"
#import "TableDocument.h"
#import "TableContent.h"
#import "CustomQuery.h"
#import "SPArrayAdditions.h"
#import "SPStringAdditions.h"
#import "SPConstants.h"
#import "SPGrowlController.h"

@interface SPExportController (PrivateAPI)

- (void)_toggleExportButton;
- (void)_initializeExportUsingSelectedOptions;
- (void)_resizeWindowByHeightDelta:(NSInteger)delta;

@end

@implementation SPExportController

@synthesize connection;
@synthesize exportToMultipleFiles;
@synthesize exportCancelled;

/**
 * Initializes an instance of SPExportController
 */
- (id)init
{
	if (self = [super initWithWindowNibName:@"ExportDialog"]) {
		
		[self setExportCancelled:NO];
		[self setExportToMultipleFiles:YES];
		
		exportType = 0;
		exportTableCount = 0;
		currentTableExportIndex = 0;
		
		exportTypeLabel = @"";
		
		tables = [[NSMutableArray alloc] init];
		exporters = [[NSMutableArray alloc] init];
		operationQueue = [[NSOperationQueue alloc] init];
		
		showAdvancedView = NO;
		
		heightOffset = 0;
		windowMinWidth = [[self window] minSize].width;
		windowMinHeigth = [[self window] minSize].height;
		
		prefs = [NSUserDefaults standardUserDefaults];
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
	
	// Disable the 'filtered result' and 'query result' options
	[[exportInputMatrix cellAtRow:0 column:0] setEnabled:NO];
	[[exportInputMatrix cellAtRow:1 column:0] setEnabled:NO];
	
	// Select the 'selected tables' option
	[exportInputMatrix selectCellAtRow:2 column:0];
}

#pragma mark -
#pragma mark IB action methods

/**
 * Display the export window allowing the user to select what and of what type to export.
 */
- (void)export
{	
	[self refreshTableList:self];
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES);

	// If found the set the default path to the user's desktop, otherwise use their home directory
	[exportPathField setStringValue:([paths count] > 0) ? [paths objectAtIndex:0] : NSHomeDirectory()];
	
	[NSApp beginSheet:[self window]
	   modalForWindow:tableWindow
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

/**
 * Closes the export dialog.
 */
- (IBAction)closeSheet:(id)sender
{
	// Close the advanced options view if it's open
	[exportAdvancedOptionsView setHidden:YES];
	[exportAdvancedOptionsViewButton setState:NSOffState];
	
	[self _resizeWindowByHeightDelta:0];
	
	[NSApp endSheet:[self window] returnCode:[sender tag]];
	[[self window] orderOut:self];
}

/**
 * Change the selected toolbar item.
 */
- (IBAction)switchTab:(id)sender
{
	if ([sender isKindOfClass:[NSToolbarItem class]]) {
		
		NSString *tabLabel = [[sender label] lowercaseString];
		
		[exportTabBar selectTabViewItemWithIdentifier:tabLabel];
		
		BOOL isCSV = [tabLabel isEqualToString:@"csv"];
		BOOL isSQL = [[exportToolbar selectedItemIdentifier] isEqualToString:@"sql"];
		BOOL hideColumns = (isCSV || [tabLabel isEqualToString:@"xml"]);
		
		[exportUseUTF8BOMButton setEnabled:(!isCSV)];
		
		[exportFilePerTableCheck setHidden:isSQL];
		[exportFilePerTableNote setHidden:isSQL];
		
		// Disable the 'filtered result' and 'query result' options
		[[exportInputMatrix cellAtRow:0 column:0] setEnabled:hideColumns];
		[[exportInputMatrix cellAtRow:1 column:0] setEnabled:hideColumns];
		
		[[exportTableList tableColumnWithIdentifier:@"structure"] setHidden:hideColumns];
		[[exportTableList tableColumnWithIdentifier:@"drop"] setHidden:hideColumns];
		
		[[[exportTableList tableColumnWithIdentifier:@"content"] headerCell] setStringValue:(hideColumns) ? @"" : @"C"]; 
		
		[exportCSVNULLValuesAsTextField setEnabled:isCSV];
		[exportCSVNULLValuesAsTextField setStringValue:(isCSV) ? [prefs stringForKey:SPNullValue] : @""]; 
		
		[self refreshTableList:self];
	}
}

/**
 * Enables/disables and shows/hides various interface controls depending on the selected item.
 */
- (IBAction)switchInput:(id)sender
{
	if ([sender isKindOfClass:[NSMatrix class]]) {
		
		BOOL isSelectedTables = ([[sender selectedCell] tag] == 3);
		
		[exportFilePerTableCheck setHidden:(!isSelectedTables)];
		[exportFilePerTableNote setHidden:(!isSelectedTables)];
		
		[exportTableList setEnabled:isSelectedTables];
		[exportSelectAllTablesButton setEnabled:isSelectedTables];
		[exportDeselectAllTablesButton setEnabled:isSelectedTables];
		[exportRefreshTablesButton setEnabled:isSelectedTables];
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
 * Opens the open panel when user selects to change the output path.
 */
- (IBAction)changeExportOutputPath:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setCanChooseFiles:NO];
	[panel setCanChooseDirectories:YES];
	[panel setCanCreateDirectories:YES];
	[panel setAccessoryView:exportCustomFilenameView];
	
	[panel beginSheetForDirectory:NSHomeDirectory() 
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
	if ([[exportToolbar selectedItemIdentifier] isEqualToString:@"sql"]) {
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
	NSUInteger i;
	
	[self refreshTableList:self];
	
	for (NSMutableArray *table in tables)
	{
		[table replaceObjectAtIndex:2 withObject:([sender tag]) ? [NSNumber numberWithBool:YES] : [NSNumber numberWithBool:NO]];
	}
	
	[exportTableList reloadData];
}

/**
 * Toggles the display of the advanced options box.
 */
- (IBAction)toggleAdvancedExportOptionsView:(id)sender
{
	showAdvancedView = !showAdvancedView;
	
	if (showAdvancedView) {
		[exportAdvancedOptionsViewButton setState:NSOnState];
		[self _resizeWindowByHeightDelta:([exportAdvancedOptionsView frame].size.height + 10)];
		[exportAdvancedOptionsView setHidden:NO];
	} 
	else {
		[exportAdvancedOptionsViewButton setState:NSOffState];
		[self _resizeWindowByHeightDelta:0];
		[exportAdvancedOptionsView setHidden:YES];
	}
}

/**
 * Toggles the export button when choosing to include or table structures in an SQL export.
 */
- (IBAction)toggleSQLIncludeStructure:(id)sender
{
	[[exportTableList tableColumnWithIdentifier:@"structure"] setHidden:(![sender state])];
	
	[self _toggleExportButton];
}

/**
 * Toggles the export button when choosing to include or exclude table contents in an SQL export.
 */
- (IBAction)toggleSQLIncludeContent:(id)sender
{
	[sender setTag:[sender state]];
	
	[self selectDeselectAllTables:sender];
	
	[self _toggleExportButton];
}

/**
 * Toggles the export button when choosing to include or exclude table drop syntax in an SQL export.
 */
- (IBAction)toggleSQLIncludeDropSyntax:(id)sender
{
	[[exportTableList tableColumnWithIdentifier:@"drop"] setHidden:(![sender state])];
	
	[self _toggleExportButton];
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
 * Invoked when the user dismissing the export dialog and starts the export process if required.
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
	[operationQueue release], operationQueue = nil;
	
	[super dealloc];
}

#pragma mark -
#pragma mark Private API

/**
 * Enables or disables the export button based on the state of various interface controls.
 */
- (void)_toggleExportButton
{
	BOOL structureEnabled = [exportSQLIncludeStructureCheck state];
	BOOL contentEnabled   = [exportSQLIncludeContentCheck state];
	BOOL dropEnabled      = [exportSQLIncludeDropSyntaxCheck state];
	
	// Disable if all are unchecked
	if ((!contentEnabled) && (!structureEnabled) && (!dropEnabled)) {
		[exportButton setEnabled:NO];
	}
	// Disable if structure is unchecked, but content and drop are as dropping a table then trying to insert
	// into it is obviously an error
	else if (contentEnabled && (!structureEnabled) && (dropEnabled)) {
		[exportButton setEnabled:NO];
	}
	else {
		[exportButton setEnabled:(contentEnabled || (structureEnabled || dropEnabled))];
	}
}

/**
 * Initializes the export process by analysing the selected criteria.
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
 * Resizes the export window's height by the supplied delta, while retaining the position of 
 * all interface controls.
 */
- (void)_resizeWindowByHeightDelta:(NSInteger)delta
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
