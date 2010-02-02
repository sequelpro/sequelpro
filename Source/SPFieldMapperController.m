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

@implementation SPFieldMapperController

#pragma mark -
#pragma mark Initialization


/**
 * Initialize the field mapper
 */
- (id)initWithDelegate:(id)managerDelegate
{
	if ((self = [super initWithWindowNibName:@"DataMigrationDialog"])) {

		fieldMappingCurrentRow = 0;
		if(managerDelegate == nil) {
			NSBeep();
			NSLog(@"FieldMapperController was called without a delegate.");
			return nil;
		}
		theDelegate = managerDelegate;

	}
	
	return self;
}

- (void)awakeFromNib
{
	
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
	[super dealloc];
}

#pragma mark -
#pragma mark IBAction methods

- (IBAction)changeTableTarget:(id)sender
{
	
	// Remove all the current columns
	// [fieldMappingTableColumnNames removeAllObjects];

	// Retrieve the information for the newly selected table using a SPTableData instance
	SPTableData *selectedTableData = [[SPTableData alloc] init];
	[selectedTableData setConnection:mySQLConnection];
	NSDictionary *tableDetails = [selectedTableData informationForTable:[tableTargetPopup titleOfSelectedItem]];
	if (tableDetails) {
		// for (NSDictionary *column in [tableDetails objectForKey:@"columns"]) {
		// 	[fieldMappingTableColumnNames addObject:[NSString stringWithString:[column objectForKey:@"name"]]];
		// }
	}
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


@end
