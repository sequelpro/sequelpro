//
//  SPTableInfo.m
//  sequel-pro
//
//  Created by Ben Perry on Jun 6, 2008
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

#import "SPTableInfo.h"
#import "ImageAndTextCell.h"
#import "CMMCPConnection.h"
#import "CMMCPResult.h"
#import "TableDocument.h"
#import "TablesList.h"
#import "SPTableData.h"
#import "SPStringAdditions.h"

#import <MCPKit_bundled/MCPKit_bundled.h>

@implementation SPTableInfo

- (id)init
{
	if ((self = [super init])) {
		info = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(tableChanged:) 
												 name:NSTableViewSelectionDidChangeNotification 
											   object:tableList];
	
	[info addObject:NSLocalizedString(@"TABLE INFORMATION",@"header for table info pane")];
	[infoTable reloadData];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[info release];
		
	[super dealloc];
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [info count];
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
	return [info objectAtIndex:rowIndex];
}

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(int)rowIndex
{
	// row 1 and 6 should be editable - ie be able to rename the table and change the auto_increment value.
	return NO;//(rowIndex == 1 || rowIndex == 6 );
}


- (BOOL)tableView:(NSTableView *)aTableView isGroupRow:(int)row
{
	// This makes the top row (TABLE INFORMATION) have the diff styling
	return (row == 0);	
}

- (void)tableView:(NSTableView *)aTableView 
  willDisplayCell:(id)aCell 
   forTableColumn:(NSTableColumn *)aTableColumn 
			  row:(int)rowIndex
{
	if ((rowIndex > 0) && [[aTableColumn identifier] isEqualToString:@"info"]) {
		[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"TablePropertyIcon"]];
		[(ImageAndTextCell*)aCell setIndentationLevel:1];
	} else {
		[(ImageAndTextCell*)aCell setImage:nil];
		[(ImageAndTextCell*)aCell setIndentationLevel:0];
	}
}

- (void)tableChanged:(NSNotification *)notification
{
	NSDictionary *tableStatus;

	[info removeAllObjects];

	// For views, no information can be displayed.
	if ([tableListInstance tableType] == SP_TABLETYPE_VIEW) {
		[info addObject:@"VIEW INFORMATION"];
		[info addObject:@"no information available"];
		[infoTable reloadData];
		return;
	}

	[info addObject:@"TABLE INFORMATION"];
		
	if ([tableListInstance tableName])
	{
		if ([[tableListInstance tableName] isEqualToString:@""]) {
			[info addObject:@"multiple tables"];

		} else {

			// Retrieve the table status information via the data cache
			tableStatus = [tableDataInstance statusValues];

			// Check for errors
			if (![tableStatus count]) {
				[info addObject:@"error occurred"];
				return;
			}

			// Check for "Create_time" == NULL
			if (![[tableStatus objectForKey:@"Create_time"] isNSNull]) {

				// Set up our data formatter
				NSDateFormatter *createDateFormatter = [[[NSDateFormatter alloc] init] autorelease];
				[createDateFormatter setDateStyle:NSDateFormatterShortStyle];
				[createDateFormatter setTimeStyle:NSDateFormatterNoStyle];

				// Convert our string date from the result to an NSDate.
				NSDate *create_date = [NSDate dateWithNaturalLanguageString:[tableStatus objectForKey:@"Create_time"]];

				// Add the creation date to the infoTable
				[info addObject:[NSString stringWithFormat:@"created: %@", [createDateFormatter stringFromDate:create_date]]];
			}

			// Check for "Update_time" == NULL - InnoDB tables don't have an update time
			if (![[tableStatus objectForKey:@"Update_time"] isNSNull]) {

				// Setup our data formatter
				NSDateFormatter *updateDateFormatter = [[[NSDateFormatter alloc] init] autorelease];
				[updateDateFormatter setDateStyle:NSDateFormatterShortStyle];
				[updateDateFormatter setTimeStyle:NSDateFormatterNoStyle];

				// Convert our string date from the result to an NSDate.
				NSDate *update_date = [NSDate dateWithNaturalLanguageString:[tableStatus objectForKey:@"Update_time"]];

				// Add the update date to the infoTable
				[info addObject:[NSString stringWithFormat:@"updated: %@", [updateDateFormatter stringFromDate:update_date]]];
			}
						
			[info addObject:[NSString stringWithFormat:@"rows: ~%@", [tableStatus objectForKey:@"Rows"]]];
			[info addObject:[NSString stringWithFormat:@"size: %@", [NSString stringForByteSize:[[tableStatus objectForKey:@"Data_length"] intValue]]]];
			[info addObject:[NSString stringWithFormat:@"encoding: %@", [tableDataInstance tableEncoding]]];
			
			if (![[tableStatus objectForKey:@"Auto_increment"] isNSNull]) {
				[info addObject:[NSString stringWithFormat:@"auto_increment: %@", [tableStatus objectForKey:@"Auto_increment"]]];
			}
		}
	}
	
	[infoTable reloadData];
}

@end
