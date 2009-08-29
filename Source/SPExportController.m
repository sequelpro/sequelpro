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
#import "TableDocument.h"
#import "SPArrayAdditions.h"

@implementation SPExportController

/**
 * Initializes an instance of SPExportController
 */
- (id)init
{
	if ((self = [super init])) {
		tables = [[NSMutableArray alloc] init];
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
#pragma mark Export methods

/**
 * Display the export window allowing the user to select what and of what type to export.
 */
- (void)export
{
	if (!exportWindow) [NSBundle loadNibNamed:@"ExportDialog" owner:self];
	
	[self loadTables];

	[exportPathField setStringValue:NSHomeDirectory()];
	
	[NSApp beginSheet:exportWindow
	   modalForWindow:tableWindow
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

/**
 * Close the export dialog
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:exportWindow returnCode:[sender tag]];
	[exportWindow orderOut:self];
}

/**
 *
 */
- (IBAction)cancelExport:(id)sender
{
	// Cancel the export operation here
}

- (IBAction)changeExportOutputPath:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel setCanChooseFiles:NO];
	[panel setCanChooseDirectories:YES];
	[panel setCanCreateDirectories:YES];
	
	[panel beginSheetForDirectory:NSHomeDirectory() file:nil modalForWindow:exportWindow modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	// Perform the export
	if (returnCode == NSOKButton) {
		
		// First determine what type of export the user selected
		SPExportType exportType = 0;
		
		for (NSToolbarItem *item in [exportToolbar items])
		{
			if ([[item itemIdentifier] isEqualToString:[exportToolbar selectedItemIdentifier]]) {
				exportType = [item tag];
				break;
			}
		}
		
		// Determine what data to use (filtered result, custom query result or selected tables) for the export operation
		SPExportSource exportSource = ([exportInputMatrix selectedRow] + 1);
		
		NSMutableArray *exportTables = [NSMutableArray array];
		
		// Get the data depending on the source
		switch (exportSource) 
		{
			case SP_FILTERED_EXPORT:
				
				break;
			case SP_CUSTOM_QUERY_EXPORT:
				
				break;
			case SP_TABLE_EXPORT:
				// Create an array of tables to export
				for (NSMutableArray *table in tables)
				{
					if ([[table objectAtIndex:0] boolValue]) {
						[exportTables addObject:[table objectAtIndex:1]];
					}
				}
				
				break;
		}
		
		// Create the file handle
		
		
		SPExporter *exporter;
		SPCSVExporter *csvExporter;
		
		// Based on the type of export create a new instance of the corresponding exporter and set it's specific options
		switch (exportType)
		{
			case SP_SQL_EXPORT:
				
				break;
			case SP_CSV_EXPORT:
				csvExporter = [[SPCSVExporter alloc] init];
				
				[csvExporter setCsvOutputFieldNames:[exportCSVIncludeFieldNamesCheck state]];
				[csvExporter setCsvFieldSeparatorString:[exportCSVFieldsTerminatedField stringValue]];
				[csvExporter setCsvEnclosingCharacterString:[exportCSVFieldsWrappedField stringValue]];
				[csvExporter setCsvLineEndingString:[exportCSVLinesTerminatedField stringValue]];
				[csvExporter setCsvEscapeString:[exportCSVFieldsEscapedField stringValue]];
				
				[csvExporter setCsvOutputEncoding:[MCPConnection encodingForMySQLEncoding:[[tableDocumentInstance connectionEncoding] UTF8String]]];
				[csvExporter setCsvNULLString:[[NSUserDefaults standardUserDefaults] objectForKey:@"NullValue"]];
				
				exporter = csvExporter;
				break;
			case SP_XML_EXPORT:
				
				break;
			case SP_PDF_EXPORT:
				
				break;
			case SP_HTML_EXPORT:
				
				break;
			case SP_EXCEL_EXPORT:
				
				break;
		}
		
		// Set the exporter's delegate
		[exporter setDelegate:self];
	}
}

- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		[exportPathField setStringValue:[panel directory]];
	}
}

#pragma mark -
#pragma mark Utility methods

- (void)setConnection:(MCPConnection *)theConnection
{
	mySQLConnection = theConnection;
}

- (void)loadTables
{
	NSUInteger i;
	
	[tables removeAllObjects];
	
	MCPResult *queryResult = (MCPResult *)[mySQLConnection listTables];
	
	if ([queryResult numOfRows]) [queryResult dataSeek:0];
	
	for ( i = 0 ; i < [queryResult numOfRows] ; i++ ) 
	{
		[tables addObject:[NSMutableArray arrayWithObjects:
						   [NSNumber numberWithBool:YES],
						   NSArrayObjectAtIndex([queryResult fetchRowAsArray], 0),
						   nil]];
	}
	
	[exportTableList reloadData];
}

- (IBAction)switchTab:(id)sender
{
	if ([sender isKindOfClass:[NSToolbarItem class]]) {
		[exportTabBar selectTabViewItemWithIdentifier:[[sender label] lowercaseString]];
		
		[exportFilePerTableCheck setHidden:[[sender label] isEqualToString:@"Excel"]];
		[exportFilePerTableNote  setHidden:[[sender label] isEqualToString:@"Excel"]];
	}
}

- (IBAction)switchInput:(id)sender
{
	if ([sender isKindOfClass:[NSMatrix class]]) {
		[exportTableList setEnabled:([[sender selectedCell] tag] == 3)];
	}
}

#pragma mark -
#pragma mark Table view datasource methods

- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
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

- (void)dealloc
{	
    [tables release], tables = nil;
	
	[super dealloc];
}

@end
