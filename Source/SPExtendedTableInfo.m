//
//  $Id$
//
//  SPExtendedTableInfo.m
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

#import "SPExtendedTableInfo.h"
#import "SPTableData.h"
#import "RegexKitLite.h"
#import "SPDatabaseData.h"
#import "CMMCPConnection.h"
#import "SPStringAdditions.h"

@interface SPExtendedTableInfo (PrivateAPI)

- (NSString *)_formatValueWithKey:(NSString *)key inDictionary:(NSDictionary *)statusDict withLabel:(NSString *)label;

@end

@implementation SPExtendedTableInfo

@synthesize connection;

/**
 * Set the create table syntax textview's font.
 */
- (void)awakeFromNib
{
	[tableCreateSyntaxTextView setFont:[NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:@"CustomQueryEditorFont"]]];
}

#pragma mark -
#pragma mark IBAction methods

/**
 * Reloads the info for the currently selected table.
 */
- (IBAction)reloadTable:(id)sender
{
	// Reset the table data's cache
	[tableDataInstance resetAllData];
	
	// Load the new table info
	[self loadTable:selectedTable];
}

/**
 * Update the table type (storage engine) of the currently selected table.
 */
- (IBAction)updateTableType:(id)sender
{
	NSString *newType = [sender titleOfSelectedItem];
	NSString *currentType = [tableDataInstance statusValueForKey:@"Engine"];

	// Check if the user selected the same type
	if ([currentType isEqualToString:newType]) {
		return;
	}
	
	// Alter table's storage type
	[connection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ TYPE = %@", [selectedTable backtickQuotedString], newType]];
	
	if ([connection getLastErrorID] == 0) {
		// Reload the table's data
		[self reloadTable:self];
	}
	else {
		[sender selectItemWithTitle:currentType];
		
		NSBeginAlertSheet(NSLocalizedString(@"Error changing table type", @"error changing table type message"), 
						  NSLocalizedString(@"OK", @"OK button"), nil, nil, [NSApp mainWindow], self, nil, nil, nil,
						  [NSString stringWithFormat:NSLocalizedString(@"An error occurred when trying to change the table type to '%@'.\n\nMySQL said: %@", @"error changing table type informative message"), newType, [connection getLastErrorMessage]]);
	}
}

/**
 * Update the character set encoding of the currently selected table.
 */
- (IBAction)updateTableEncoding:(id)sender
{
	NSString *currentEncoding = [tableDataInstance tableEncoding];
	NSString *newEncoding = [[sender titleOfSelectedItem] stringByMatching:@"^.+\\((.+)\\)$" capture:1L];
	
	// Check if the user selected the same encoding
	if ([currentEncoding isEqualToString:newEncoding]) {
		return;
	}
	
	// Alter table's character set encoding
	[connection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ CHARACTER SET = %@", [selectedTable backtickQuotedString], newEncoding]];
	
	if ([connection getLastErrorID] == 0) {
		// Reload the table's data
		[self reloadTable:self];
	}
	else {
		[sender selectItemWithTitle:currentEncoding];
		
		NSBeginAlertSheet(NSLocalizedString(@"Error changing table encoding", @"error changing table encoding message"), 
						  NSLocalizedString(@"OK", @"OK button"), nil, nil, [NSApp mainWindow], self, nil, nil, nil,
						  [NSString stringWithFormat:NSLocalizedString(@"An error occurred when trying to change the table encoding to '%@'.\n\nMySQL said: %@", @"error changing table encoding informative message"), newEncoding, [connection getLastErrorMessage]]);
	}
}

/**
 * Update the character set collation of the currently selected table.
 */
- (IBAction)updateTableCollation:(id)sender
{
	NSString *newCollation = [sender titleOfSelectedItem];
	NSString *currentCollation = [tableDataInstance statusValueForKey:@"Collation"];
	
	// Check if the user selected the same collation
	if ([currentCollation isEqualToString:newCollation]) {
		return;
	}
	
	// Alter table's character set collation
	[connection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ COLLATE = %@", [selectedTable backtickQuotedString], newCollation]];
	
	if ([connection getLastErrorID] == 0) {
		// Reload the table's data
		[self reloadTable:self];
	}
	else {
		[sender selectItemWithTitle:currentCollation];
		
		NSBeginAlertSheet(NSLocalizedString(@"Error changing table collation", @"error changing table collation message"), 
						  NSLocalizedString(@"OK", @"OK button"), nil, nil, [NSApp mainWindow], self, nil, nil, nil,
						  [NSString stringWithFormat:NSLocalizedString(@"An error occurred when trying to change the table collation to '%@'.\n\nMySQL said: %@", @"error changing table collation informative message"), newCollation, [connection getLastErrorMessage]]);
	}
}

#pragma mark -
#pragma mark Other
 
/**
 * Load all the info for the supplied table by querying the table data instance and updaing the interface 
 * elements accordingly. 
 */
- (void)loadTable:(NSString *)table
{	
	// Store the table name away for future use
	selectedTable = table;
	
	// Retrieve the table status information via the table data cache
	NSDictionary *statusFields = [tableDataInstance statusValues];
	
	[tableTypePopUpButton removeAllItems];
	[tableEncodingPopUpButton removeAllItems];
	[tableCollationPopUpButton removeAllItems];
	
	// No table selected or view selected
	if ([table isEqualToString:@""] || (!table) || [[statusFields objectForKey:@"Engine"] isEqualToString:@"View"]) {
		
		[tableTypePopUpButton setEnabled:NO];
		[tableEncodingPopUpButton setEnabled:NO];
		[tableCollationPopUpButton setEnabled:NO];
		
		if ([[statusFields objectForKey:@"Engine"] isEqualToString:@"View"]) {
			[tableTypePopUpButton addItemWithTitle:@"View"];
		}
		
		[tableCreatedAt setStringValue:@"Created at: "];
		[tableUpdatedAt setStringValue:@"Updated at: "];
		
		// Set row values
		[tableRowNumber setStringValue:@"Number of rows: "];
		[tableRowFormat setStringValue:@"Row format: "];	
		[tableRowAvgLength setStringValue:@"Avg. row length: "];
		[tableRowAutoIncrement setStringValue:@"Auto increment: "];
		
		// Set size values
		[tableDataSize setStringValue:@"Data size: "]; 
		[tableMaxDataSize setStringValue:@"Max data size: "];	
		[tableIndexSize setStringValue:@"Index size: "]; 
		[tableSizeFree setStringValue:@"Free data size: "];
		
		// Set comments 
		[tableCommentsTextView setString:@""];
		
		// Set create syntax
		[tableCreateSyntaxTextView setString:@""];
		
		return;
	}
	
	NSArray *engines    = [databaseDataInstance getDatabaseStorageEngines];
	NSArray *encodings  = [databaseDataInstance getDatabaseCharacterSetEncodings];
	NSArray *collations = [databaseDataInstance getDatabaseCollationsForEncoding:[tableDataInstance tableEncoding]];
	
	if ([engines count] > 0) {
		// Populate type popup button
		for (NSDictionary *engine in engines)
		{		
			[tableTypePopUpButton addItemWithTitle:[engine objectForKey:@"ENGINE"]];
		}	
		
		[tableTypePopUpButton selectItemWithTitle:[statusFields objectForKey:@"Engine"]];
		[tableTypePopUpButton setEnabled:YES];
	}
	
	if ([encodings count] > 0) {
		NSString *selectedTitle = @"";
		
		// Populate encoding popup button
		for (NSDictionary *encoding in encodings)
		{		
			NSString *menuItemTitle = [NSString stringWithFormat:@"%@ (%@)", [encoding objectForKey:@"DESCRIPTION"], [encoding objectForKey:@"CHARACTER_SET_NAME"]];
			
			[tableEncodingPopUpButton addItemWithTitle:menuItemTitle];
			
			if ([[tableDataInstance tableEncoding] isEqualToString:[encoding objectForKey:@"CHARACTER_SET_NAME"]]) {
				selectedTitle = menuItemTitle;
			}
		}	
		
		[tableEncodingPopUpButton selectItemWithTitle:selectedTitle];
		[tableEncodingPopUpButton setEnabled:YES];
	}
	
	if ([collations count] > 0) {
		// Populate collation popup button
		for (NSDictionary *collation in collations)
		{		
			[tableCollationPopUpButton addItemWithTitle:[collation objectForKey:@"COLLATION_NAME"]];
		}	
		
		[tableCollationPopUpButton selectItemWithTitle:[statusFields objectForKey:@"Collation"]];
		[tableCollationPopUpButton setEnabled:YES];
	}
	
	[tableCreatedAt setStringValue:[self _formatValueWithKey:@"Create_time" inDictionary:statusFields withLabel:@"Created at"]];
	[tableUpdatedAt setStringValue:[self _formatValueWithKey:@"Update_time" inDictionary:statusFields withLabel:@"Updated at"]];
	
	// Set row values
	[tableRowNumber setStringValue:[self _formatValueWithKey:@"Rows" inDictionary:statusFields withLabel:@"Number of rows"]];
	[tableRowFormat setStringValue:[self _formatValueWithKey:@"Row_format" inDictionary:statusFields withLabel:@"Row format"]];	
	[tableRowAvgLength setStringValue:[self _formatValueWithKey:@"Avg_row_length" inDictionary:statusFields withLabel:@"Avg. row length"]];
	[tableRowAutoIncrement setStringValue:[self _formatValueWithKey:@"Auto_increment" inDictionary:statusFields withLabel:@"Auto increment"]];
	
	// Set size values
	[tableDataSize setStringValue:[self _formatValueWithKey:@"Data_length" inDictionary:statusFields withLabel:@"Data size"]]; 
	[tableMaxDataSize setStringValue:[self _formatValueWithKey:@"Max_data_length" inDictionary:statusFields withLabel:@"Max data size"]];	
	[tableIndexSize setStringValue:[self _formatValueWithKey:@"Index_length" inDictionary:statusFields withLabel:@"Index size"]]; 
	[tableSizeFree setStringValue:[self _formatValueWithKey:@"Data_free" inDictionary:statusFields withLabel:@"Free data size"]];	 
	
	// Set comments
	[tableCommentsTextView setString:[statusFields objectForKey:@"Comment"]];
	
	// Set create syntax
	[tableCreateSyntaxTextView setEditable:YES];
	[tableCreateSyntaxTextView setString:@""];
	[tableCreateSyntaxTextView insertText:[tableDataInstance tableCreateSyntax]];
	[tableCreateSyntaxTextView setEditable:NO];
}

/**
 * NSTextView delegate. Used to change the selected table's comment.
 */
- (void)textDidEndEditing:(NSNotification *)notification
{
	if (([notification object] == tableCommentsTextView) && ([selectedTable length] > 0)) {
		
		NSString *currentComment = [tableDataInstance statusValueForKey:@"Comment"];
		NSString *newComment = [[tableCommentsTextView string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		// Check that the user actually changed the tables comment
		if (![currentComment isEqualToString:newComment]) {
			
			// Alter table's comment
			[connection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ COMMENT = '%@'", [selectedTable backtickQuotedString], newComment]];
			
			if ([connection getLastErrorID] == 0) {
				// Reload the table's data
				[self reloadTable:self];
			}
			else {
				NSBeginAlertSheet(NSLocalizedString(@"Error changing table comment", @"error changing table comment message"), 
								  NSLocalizedString(@"OK", @"OK button"), nil, nil, [NSApp mainWindow], self, nil, nil, nil,
								  [NSString stringWithFormat:NSLocalizedString(@"An error occurred when trying to change the table's comment to '%@'.\n\nMySQL said: %@", @"error changing table comment informative message"), newComment, [connection getLastErrorMessage]]);
			}
		}
	}
}

/**
 * Release connection.
 */
- (void)dealloc
{
	[connection release], connection = nil;
	
	[super dealloc];
}

@end

@implementation SPExtendedTableInfo (PrivateAPI)

/**
 * Format and returns the value within the info dictionary with the associated key. 
 */
- (NSString *)_formatValueWithKey:(NSString *)key inDictionary:(NSDictionary *)infoDict withLabel:(NSString *)label
{
	NSString *value = [infoDict objectForKey:key];
	
	if ([value isKindOfClass:[NSNull class]]) {
		value = @"";
	} 
	else {
		// Format size strings
		if ([key isEqualToString:@"Data_length"]     || 
			[key isEqualToString:@"Max_data_length"] || 
			[key isEqualToString:@"Index_length"]    || 
			[key isEqualToString:@"Data_free"]) {
			
			value = [NSString stringForByteSize:[value intValue]];
		}
		// Format date strings to the user's long date format
		else if ([key isEqualToString:@"Create_time"] ||
				 [key isEqualToString:@"Update_time"]) {
			
			// Create date formatter
			NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
			
			[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
			
			[dateFormatter setDateStyle:NSDateFormatterLongStyle];
			[dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
			
			value = [dateFormatter stringFromDate:[NSDate dateWithNaturalLanguageString:value]];						
		}
	}
		
	return [NSString stringWithFormat:@"%@: %@", label, ([value length] > 0) ? value : @"Not available"];
}

@end
