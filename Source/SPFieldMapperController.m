//
//  $Id$
//
//  SPQueryFavoriteManager.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on February 01, 2010
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
//

#import "SPFieldMapperController.h"
#import "SPTableData.h"
#import "TablesList.h"

@implementation SPFieldMapperController

@synthesize sourcePath;

#pragma mark -
#pragma mark Initialization


/**
 * Initialize the field mapper
 */
- (id)initWithDelegate:(id)managerDelegate
{
	if (self = [super initWithWindowNibName:@"DataMigrationDialog"]) {

		fieldMappingCurrentRow = 0;
		if(managerDelegate == nil) {
			NSBeep();
			NSLog(@"FieldMapperController was called without a delegate.");
			return nil;
		}
		theDelegate = managerDelegate;
		fieldMappingTableColumnNames = [[NSMutableArray alloc] initWithCapacity:1];
	}
	
	return self;
}

- (void)awakeFromNib
{
	[fileSourcePath setURL:[NSURL URLWithString:sourcePath]];
	[tableTargetPopup removeAllItems];
	[tableTargetPopup addItemsWithTitles:[[theDelegate valueForKeyPath:@"tablesListInstance"] allTableNames]];

	// Select either the currently selected table, or the first item in the list
	if ([[theDelegate valueForKeyPath:@"tableDocumentInstance"] table] != nil && ![[[theDelegate valueForKeyPath:@"tablesListInstance"] tableName] isEqualToString:@""]) {
		[tableTargetPopup selectItemWithTitle:[[theDelegate valueForKeyPath:@"tablesListInstance"] tableName]];
	} else {
		[tableTargetPopup selectItemAtIndex:0];
	}
	
	[self changeTableTarget:self];
}
/*
 * Set the connection for use.
 * Called by the connect sheet methods.
 */
- (void)setConnection:(MCPConnection *)theConnection
{
	mySQLConnection = theConnection;
	[mySQLConnection retain];
}

- (void)dealloc
{
	if (mySQLConnection) [mySQLConnection release];
	if (sourcePath) [sourcePath release];
	if (fieldMappingTableColumnNames) [fieldMappingTableColumnNames release];
	[super dealloc];
}

#pragma mark -
#pragma mark IBAction methods

- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:[self window] returnCode:[sender tag]];
}

- (IBAction)changeTableTarget:(id)sender
{
	
	// Remove all the current columns
	[fieldMappingTableColumnNames removeAllObjects];

	// Retrieve the information for the newly selected table using a SPTableData instance
	SPTableData *selectedTableData = [[SPTableData alloc] init];
	[selectedTableData setConnection:mySQLConnection];
	NSDictionary *tableDetails = [selectedTableData informationForTable:[tableTargetPopup titleOfSelectedItem]];
	if (tableDetails) {
		for (NSDictionary *column in [tableDetails objectForKey:@"columns"]) {
			[fieldMappingTableColumnNames addObject:[NSString stringWithString:[column objectForKey:@"name"]]];
		}
	}
	NSLog(@"f %@", [fieldMappingTableColumnNames description]);
	[selectedTableData release];

	// Update the table view
	fieldMappingCurrentRow = 0;
	if (fieldMappingArray) [fieldMappingArray release], fieldMappingArray = nil;
	// [self setupFieldMappingArray];
	[rowDownButton setEnabled:NO];
	[rowUpButton setEnabled:([fieldMappingImportArray count] > 1)];
	[recordCountLabel setStringValue:[NSString stringWithFormat:@"%ld of %@%lu records", (long)(fieldMappingCurrentRow+1), fieldMappingImportArrayIsPreview?@"first ":@"", (unsigned long)[fieldMappingImportArray count]]];

	// [self updateFieldMappingButtonCell];
	[fieldMapperTableView reloadData];
}

- (IBAction)changeImportMethod:(id)sender
{
	
}

/*
 * Displays next/previous row in fieldMapping tableView
 */
- (IBAction)stepRow:(id)sender
{
	if ( [sender tag] == 0 ) {
		fieldMappingCurrentRow--;
	} else {
		fieldMappingCurrentRow++;
	}
	// [self updateFieldMappingButtonCell];
	
	[fieldMapperTableView reloadData];
	
	[recordCountLabel setStringValue:[NSString stringWithFormat:@"%ld of %@%lu records", (long)(fieldMappingCurrentRow+1), fieldMappingImportArrayIsPreview?@"first ":@"", (unsigned long)[fieldMappingImportArray count]]];
	
	// enable/disable buttons
	[rowDownButton setEnabled:(fieldMappingCurrentRow != 0)];
	[rowUpButton setEnabled:(fieldMappingCurrentRow != ([fieldMappingImportArray count]-1))];
}

#pragma mark -
#pragma mark Table view datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
{
	return [fieldMappingTableColumnNames count];
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{

}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if ([[aTableColumn identifier] isEqualToString:@"target_field"]) {
		return [fieldMappingTableColumnNames objectAtIndex:rowIndex];
		
	}
	// else if ([[aTableColumn identifier] isEqualToString:@"value"]) {
	// 	if ([[[aTableColumn dataCell] class] isEqualTo:[NSPopUpButtonCell class]]) {
	// 		[(NSPopUpButtonCell *)[aTableColumn dataCell] removeAllItems];
	// 		[(NSPopUpButtonCell *)[aTableColumn dataCell] addItemWithTitle:NSLocalizedString(@"Do not import", @"text for csv import drop downs")];
	// 		[(NSPopUpButtonCell *)[aTableColumn dataCell] addItemsWithTitles:fieldMappingButtonOptions];
	// 	}
	// 	
	// 	returnObject = [fieldMappingArray objectAtIndex:rowIndex];
	// } 
	return nil;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
}


@end
