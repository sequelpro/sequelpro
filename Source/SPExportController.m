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
#import "TablesList.h"
#import "SPTableData.h"
#import "TableContent.h"
#import "SPArrayAdditions.h"
#import "SPStringAdditions.h"
#import "SPConstants.h"
#import "SPGrowlController.h"

@interface SPExportController (PrivateAPI)

- (void)_toggleExportButton;
- (void)_resizeWindowByHeightDelta:(NSInteger)delta;

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
		
		exportType = 0;
		exportTableCount = 0;
		currentTableExportIndex = 0;
		
		exportFilename = @"";
		exportTypeLabel = @"";
		
		createCustomFilename = NO;
		sqlPreviousConnectionEncodingViaLatin1 = NO;
		
		tables = [[NSMutableArray alloc] init];
		exporters = [[NSMutableArray alloc] init];
		operationQueue = [[NSOperationQueue alloc] init];
		
		showAdvancedView = NO;
		
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
	// Upon awakening select the SQL tab
	[exportToolbar setSelectedItemIdentifier:[[[exportToolbar items] objectAtIndex:0] itemIdentifier]];
	
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
	[self exportTables:nil asFormat:0];
}

/**
 * Displays the export window with the supplied tables and export type/format selected.
 */
- (void)exportTables:(NSArray *)exportTables asFormat:(SPExportType)format
{
	[self refreshTableList:self];
		
	if (exportTables && format) {
		
		// Select the correct tab according to the supplied export type
		[exportToolbar setSelectedItemIdentifier:[[[exportToolbar items] objectAtIndex:(format - 1)] itemIdentifier]];
	
		// Select the 'selected tables' source option
		[exportInputMatrix selectCellAtRow:2 column:0];
		
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
		
		// Ensure interface validation
		[self switchTab:[[exportToolbar items] objectAtIndex:(format - 1)]];
	}
	
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
		
		[self _resizeWindowByHeightDelta:0];
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
		
		NSString *label = [[currentToolbarItem label] lowercaseString];
		
		[exportTabBar selectTabViewItemWithIdentifier:label];
				
		BOOL isSQL  = [label isEqualToString:@"sql"];
		BOOL isCSV  = [label isEqualToString:@"csv"];
		BOOL isXML  = [label isEqualToString:@"xml"];
		BOOL isHTML = [label isEqualToString:@"html"];
		BOOL isPDF  = [label isEqualToString:@"pdf"];
		BOOL isDot  = [label isEqualToString:@"dot"];
		
		BOOL disable = (isCSV || isXML || isHTML || isPDF || isDot);
		
		[exportFilePerTableCheck setHidden:(isSQL || isDot)];
		[exportFilePerTableNote setHidden:(isSQL || isDot)];
		
		[exportTableList setEnabled:(!isDot)];
		[exportSelectAllTablesButton setEnabled:(!isDot)];
		[exportDeselectAllTablesButton setEnabled:(!isDot)];
		[exportRefreshTablesButton setEnabled:(!isDot)];
		
		[[exportInputMatrix cellAtRow:2 column:0] setEnabled:(!isDot)];
		
		if (isDot) {
			// Disable all source checkboxes
			[[exportInputMatrix cellAtRow:0 column:0] setEnabled:NO];
			[[exportInputMatrix cellAtRow:1 column:0] setEnabled:NO];
		}
		else {
			// Enable/disable the 'filtered result' and 'query result' options
			[[exportInputMatrix cellAtRow:0 column:0] setEnabled:((disable) && ([[tableContentInstance currentResult] count] > 1))];
			[[exportInputMatrix cellAtRow:1 column:0] setEnabled:((disable) && ([[customQueryInstance currentResult] count] > 1))];			
		}
		
		[[exportTableList tableColumnWithIdentifier:@"structure"] setHidden:disable];
		[[exportTableList tableColumnWithIdentifier:@"drop"] setHidden:disable];
		
		[[[exportTableList tableColumnWithIdentifier:@"content"] headerCell] setStringValue:(disable) ? @"" : @"C"]; 
		
		[exportCSVNULLValuesAsTextField setStringValue:[prefs stringForKey:SPNullValue]]; 
	}
}

/**
 * Enables/disables and shows/hides various interface controls depending on the selected item.
 */
- (IBAction)switchInput:(id)sender
{
	if ([sender isKindOfClass:[NSMatrix class]]) {
		
		BOOL isSelectedTables = ([[sender selectedCell] tag] == SPTableExport);
		
		[exportFilePerTableCheck setHidden:(!isSelectedTables)];
		[exportFilePerTableNote setHidden:(!isSelectedTables)];
		
		[exportTableList setEnabled:isSelectedTables];
		[exportSelectAllTablesButton setEnabled:isSelectedTables];
		[exportDeselectAllTablesButton setEnabled:isSelectedTables];
		[exportRefreshTablesButton setEnabled:isSelectedTables];
		
		availableFilenameTokens = ([[sender selectedCell] tag] == SPQueryExport) ? @"host,database,date,time" : @"host,database,table,date,time";
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
	[exportCustomFilenameTokenField setStringValue:@""];
	[exportCustomFilenameTokensField setStringValue:availableFilenameTokens];
	
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setCanChooseFiles:NO];
	[panel setCanChooseDirectories:YES];
	[panel setCanCreateDirectories:YES];
	[panel setAccessoryView:exportCustomFilenameView];
	
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
	[self refreshTableList:self];
	
	for (NSMutableArray *table in tables)
	{
		[table replaceObjectAtIndex:2 withObject:[NSNumber numberWithBool:[sender tag]]];
	}
	
	[exportTableList reloadData];
	
	[self _toggleExportButton];
}

/**
 * Toggles the state of the custom filename format token fields.
 */
- (IBAction)toggleCustomFilenameFormat:(id)sender
{
	[exportCustomFilenameTokenField setEnabled:[sender state]];
	[exportCustomFilenameTokensField setEnabled:[sender state]];
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

	[self _toggleExportButton];
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
#pragma mark Text field delegate methods

- (void)controlTextDidChange:(NSNotification *)notification
{
	if ([notification object] == exportCustomFilenameTokenField) {
		
		// Create the table name, but since this is only an example, use the first table in the list
		NSString *filename = [self expandCustomFilenameFormatFromString:[exportCustomFilenameTokenField stringValue] usingTableName:[[tablesListInstance tables] objectAtIndex:1]];
				
		[exportCustomFilenameExampleTextField setStringValue:[NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Example", @"example label"), filename]];
	}
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
	[operationQueue release], operationQueue = nil;
	
	if (sqlPreviousConnectionEncoding) [sqlPreviousConnectionEncoding release], sqlPreviousConnectionEncoding = nil;
	
	[super dealloc];
}

#pragma mark -
#pragma mark Private API

/**
 * Enables or disables the export button based on the state of various interface controls.
 */
- (void)_toggleExportButton
{
	NSString *label = [[currentToolbarItem label] lowercaseString];
	
	BOOL isSQL  = [label isEqualToString:@"sql"];
	BOOL isCSV  = [label isEqualToString:@"csv"];
	BOOL isXML  = [label isEqualToString:@"xml"];
	BOOL isHTML = [label isEqualToString:@"html"];
	BOOL isPDF  = [label isEqualToString:@"pdf"];
		
	if (isCSV || isXML || isHTML || isPDF) {
		[exportButton setEnabled:NO];
		
		// Only enable the button if at least one table is selected
		for (NSArray *table in tables)
		{
			if ([NSArrayObjectAtIndex(table, 2) boolValue]) {
				[exportButton setEnabled:YES];
				break;
			}
		}
	}
	else if (isSQL) {
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
