//
//  $Id$
//
//  TableStatus.m
//  sequel-pro
//
//  Created by Jason Hallford (jason.hallford@byu.edu) on Th July 08 2004.
//  sequel-pro Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
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

#import "TableStatus.h"
#import "SPTableData.h"
#import "SPStringAdditions.h"

@implementation TableStatus

- (void)setConnection:(CMMCPConnection *)theConnection
{
	mySQLConnection = theConnection;
	[mySQLConnection retain];
}

- (NSString*)formatValueWithKey:(NSString *)aKey inDictionary:(NSDictionary*)statusDict withLabel:(NSString*)label
{
	NSString *value = [statusDict objectForKey:aKey];
	
	if ([value isKindOfClass:[NSNull class]]) {
		value = @"--";
	} 
	else {
		// Format size strings
		if ([aKey isEqualToString:@"Data_length"]     || 
			[aKey isEqualToString:@"Max_data_length"] || 
			[aKey isEqualToString:@"Index_length"]    || 
			[aKey isEqualToString:@"Data_free"]) {
			
			value = [NSString stringForByteSize:[value intValue]];
		}
		// Format date strings to the user's long date format
		else if ([aKey isEqualToString:@"Create_time"] ||
				 [aKey isEqualToString:@"Update_time"]) {
			
			// Create date formatter
			NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
			
			[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
			
			[dateFormatter setDateStyle:NSDateFormatterLongStyle];
			[dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
			
			value = [dateFormatter stringFromDate:[NSDate dateWithNaturalLanguageString:value]];						
		}
	}
	
	NSString *labelVal = [NSString stringWithFormat:@"%@: %@", label, value];
	
	return labelVal;
}

- (void)loadTable:(NSString *)aTable
{
	// Store the table name away for future use...
	selectedTable = aTable;

	// Retrieve the table status information via the table data cache
	statusFields = [tableDataInstance statusValues];
	
	// No table selected or view selected
	if([aTable isEqualToString:@""] || !aTable || [[statusFields objectForKey:@"Engine"] isEqualToString:@"View"]) {
	
		if ([[statusFields objectForKey:@"Engine"] isEqualToString:@"View"]) {
			[tableName setStringValue:[NSString stringWithFormat:@"Name: %@", selectedTable]];
			[tableType setStringValue:@"Type: View"];
		} else {
			[tableName setStringValue:@"Name: --"];
			[tableType setStringValue:@"Type: --"];
		}

		[tableCreatedAt setStringValue:@"Created At: --"];
		[tableUpdatedAt setStringValue:@"Updated At: --"];

		// Assign the row values...
		[rowsNumber setStringValue:@"Number Of: --"];
		[rowsFormat setStringValue:@"Format: --"];	
		[rowsAvgLength setStringValue:@"Avg. Length: --"];
		[rowsAutoIncrement setStringValue:@"Auto Increment: --"];

		// Assign the size values...
		[sizeData setStringValue:@"Data: --"]; 
		[sizeMaxData setStringValue:@"Max Data: --"];	
		[sizeIndex setStringValue:@"Index: --"]; 
		[sizeFree setStringValue:@"Free: --"];

		// Finally, set the value of the comments box
		[commentsBox setStringValue:@"--"];

		return;
	}

	// Assign the table values...
	[tableName setStringValue:[NSString stringWithFormat:@"Name: %@",selectedTable]];
	[tableType setStringValue:[self formatValueWithKey:@"Engine" inDictionary:statusFields withLabel:@"Type"]];
	[tableCreatedAt setStringValue:[self formatValueWithKey:@"Create_time" inDictionary:statusFields withLabel:@"Created At"]];
	[tableUpdatedAt setStringValue:[self formatValueWithKey:@"Update_time" inDictionary:statusFields withLabel:@"Updated At"]];

	// Assign the row values...
	[rowsNumber setStringValue:[self formatValueWithKey:@"Rows" inDictionary:statusFields withLabel:@"Approx. Number"]];
	[rowsFormat setStringValue:[self formatValueWithKey:@"Row_format" inDictionary:statusFields withLabel:@"Format"]];	
	[rowsAvgLength setStringValue:[self formatValueWithKey:@"Avg_row_length" inDictionary:statusFields withLabel:@"Avg. Length"]];
	[rowsAutoIncrement setStringValue:[self formatValueWithKey:@"Auto_increment" inDictionary:statusFields withLabel:@"Auto Increment"]];

	// Assign the size values...
	[sizeData setStringValue:[self formatValueWithKey:@"Data_length" inDictionary:statusFields withLabel:@"Data"]]; 
	[sizeMaxData setStringValue:[self formatValueWithKey:@"Max_data_length" inDictionary:statusFields withLabel:@"Max Data"]];	
	[sizeIndex setStringValue:[self formatValueWithKey:@"Index_length" inDictionary:statusFields withLabel:@"Index"]]; 
	[sizeFree setStringValue:[self formatValueWithKey:@"Data_free" inDictionary:statusFields withLabel:@"Free"]];	 

	// Finally, assign the comments...
	[commentsBox setStringValue:[statusFields objectForKey:@"Comment"]];

	return;
}

- (IBAction)reloadTable:(id)sender
{
	[tableDataInstance resetStatusData];
	[self loadTable:selectedTable];
}

- (id)init
{
	self = [super init];
	
	return self;
}

@end
