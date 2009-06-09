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

@implementation SPExportController

#pragma mark -
#pragma mark Export Methods

-(void)export
{
	if ([NSBundle loadNibNamed:@"ExportDialog" owner:self]) {
		[self loadTables];
		[NSApp beginSheet:exportWindow modalForWindow:tableWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
	}
}

- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:exportWindow];
	[NSApp stopModalWithCode:[sender tag]];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
}

#pragma mark -
#pragma mark Utility Methods

- (void)setConnection:(CMMCPConnection *)theConnection
{
	mySQLConnection = theConnection;
}

- (void)loadTables
{
	CMMCPResult *queryResult;
	int i;
	
	[tables removeAllObjects];
	queryResult = (CMMCPResult *)[mySQLConnection listTables];
	
	if ([queryResult numOfRows])
		[queryResult dataSeek:0];
	
	for ( i = 0 ; i < [queryResult numOfRows] ; i++ ) {
		[tables addObject:[NSMutableArray arrayWithObjects:
						   [NSNumber numberWithBool:YES],
						   [[queryResult fetchRowAsArray] objectAtIndex:0],
						   nil
						   ]];
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
#pragma mark Table View Datasource methods

- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
{
	return [tables count];
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
	id returnObject = nil;
	
	if ( [[aTableColumn identifier] isEqualToString:@"switch"] ) {
		returnObject = [[tables objectAtIndex:rowIndex] objectAtIndex:0];
	} else {
		returnObject = [[tables objectAtIndex:rowIndex] objectAtIndex:1];
	}
	
	return returnObject;
}

- (void)tableView:(NSTableView *)aTableView
   setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)aTableColumn
			  row:(int)rowIndex
{
	[[tables objectAtIndex:rowIndex] replaceObjectAtIndex:0 withObject:anObject];
}

#pragma mark -
#pragma mark Table View Delegate methods

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
	return (aTableView != exportTableList);
}

- (BOOL)tableView:(NSTableView *)aTableView shouldTrackCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	return (aTableView == exportTableList);
}

- (void)tableView:(NSTableView *)aTableView 
  willDisplayCell:(id)aCell 
   forTableColumn:(NSTableColumn *)aTableColumn 
			  row:(int)rowIndex
{
		[aCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
}

#pragma mark -
#pragma mark Toolbar Delegate Methods

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	NSArray *array = [toolbar items];
	NSMutableArray *items = [NSMutableArray arrayWithCapacity:6];
	
	for (NSToolbarItem *item in array)
	{
		[items addObject:[item itemIdentifier]];
	}
	
    return items;
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
	return YES;
}

- (id)init;
{
	self = [super init];
	tables = [[NSMutableArray alloc] init];
	return self;
}


- (void)dealloc
{	
    [tables release];
	[super dealloc];
}
@end
