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
#import "TablesList.h"
#import "SPArrayAdditions.h"

@implementation SPExportController

- (id)init;
{
	if ((self = [super init])) {
		tables = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void)awakeFromNib
{
	// Upon awakening select the SQL tab
	[exportToolbar setSelectedItemIdentifier:[[[exportToolbar items] objectAtIndex:0] itemIdentifier]];
}

#pragma mark -
#pragma mark Export methods

- (void)export
{
	if (!exportWindow) {
		[NSBundle loadNibNamed:@"ExportDialog" owner:self];
	}
	
	[self loadTables];
	
	[NSApp beginSheet:exportWindow
	   modalForWindow:tableWindow
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:exportWindow returnCode:[sender tag]];
	[exportWindow orderOut:self];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	// Perform the export
	if (returnCode == NSOKButton) {
		
		// First determine what type of export the user selected
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
	int i;
	
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

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{	
	return NSArrayObjectAtIndex([tables objectAtIndex:rowIndex], ([[aTableColumn identifier] isEqualToString:@"switch"]) ? 0 : 1);
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
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

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
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
