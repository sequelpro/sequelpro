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
#import "SPStringAdditions.h"
#import "SPConstants.h"
#import "TableDocument.h"

@interface SPExtendedTableInfo (PrivateAPI)

- (NSString *)_formatValueWithKey:(NSString *)key inDictionary:(NSDictionary *)statusDict withLabel:(NSString *)label;

@end

@implementation SPExtendedTableInfo

@synthesize connection;

/**
 * Upon awakening bind the create syntax text view's background colour.
 */
- (void)awakeFromNib
{
	[tableCreateSyntaxTextView setAllowsDocumentBackgroundColorChange:YES];
	
	NSMutableDictionary *bindingOptions = [NSMutableDictionary dictionary];
	
	[bindingOptions setObject:NSUnarchiveFromDataTransformerName forKey:@"NSValueTransformerName"];
	
	[tableCreateSyntaxTextView bind:@"backgroundColor"
						   toObject:[NSUserDefaultsController sharedUserDefaultsController]
						withKeyPath:@"values.CustomQueryEditorBackgroundColor"
							options:bindingOptions];

	// Add observers for document task activity
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(startDocumentTaskForTab:)
												 name:SPDocumentTaskStartNotification
											   object:tableDocumentInstance];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(endDocumentTaskForTab:)
												 name:SPDocumentTaskEndNotification
											   object:tableDocumentInstance];
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
 * Note that interface elements are also toggled in start/endDocumentTaskForTab:, with similar logic.
 * Due to the large quantity of interface interaction in this function it is not thread-safe.
 */
- (void)loadTable:(NSString *)table
{	
	BOOL enableInteraction = ![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableInfo] || ![tableDocumentInstance isWorking];

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
			// Set create syntax
			[tableCreateSyntaxTextView setEditable:YES];
			[tableCreateSyntaxTextView shouldChangeTextInRange:NSMakeRange(0, [[tableCreateSyntaxTextView string] length]) replacementString:@""];
			[tableCreateSyntaxTextView setString:@""];
			NSString *createViewSyntax = [[tableDataInstance tableCreateSyntax] createViewSyntaxPrettifier];
			[tableCreateSyntaxTextView shouldChangeTextInRange:NSMakeRange(0, 0) replacementString:createViewSyntax];
			[tableCreateSyntaxTextView insertText:createViewSyntax];
			[tableCreateSyntaxTextView didChangeText];
			[tableCreateSyntaxTextView setEditable:NO];
		} else {
			[tableCreateSyntaxTextView setEditable:YES];
			[tableCreateSyntaxTextView shouldChangeTextInRange:NSMakeRange(0, [[tableCreateSyntaxTextView string] length]) replacementString:@""];
			[tableCreateSyntaxTextView setString:@""];
			[tableCreateSyntaxTextView didChangeText];
			[tableCreateSyntaxTextView setEditable:NO];
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
		[tableCommentsTextView setEditable:NO];
		[tableCommentsTextView shouldChangeTextInRange:NSMakeRange(0, [[tableCommentsTextView string] length]) replacementString:@""];
		[tableCommentsTextView setString:@""];
		[tableCommentsTextView didChangeText];
		
		return;
	}
	
	NSArray *engines    = [databaseDataInstance getDatabaseStorageEngines];
	NSArray *encodings  = [databaseDataInstance getDatabaseCharacterSetEncodings];
	NSArray *collations = [databaseDataInstance getDatabaseCollationsForEncoding:[tableDataInstance tableEncoding]];
	
	if (([engines count] > 0) && ([statusFields objectForKey:@"Engine"])) {
		// Populate type popup button
		for (NSDictionary *engine in engines)
		{		
			[tableTypePopUpButton addItemWithTitle:[engine objectForKey:@"Engine"]];
		}	
		
		[tableTypePopUpButton selectItemWithTitle:[statusFields objectForKey:@"Engine"]];
		[tableTypePopUpButton setEnabled:enableInteraction];
	}
	else {
		[tableTypePopUpButton addItemWithTitle:@"Not available"];
	}
	
	if (([encodings count] > 0) && ([tableDataInstance tableEncoding])) {
		NSString *selectedTitle = @"";
		
		// Populate encoding popup button
		for (NSDictionary *encoding in encodings)
		{			
			NSString *menuItemTitle = (![encoding objectForKey:@"DESCRIPTION"]) ? [encoding objectForKey:@"CHARACTER_SET_NAME"] : [NSString stringWithFormat:@"%@ (%@)", [encoding objectForKey:@"DESCRIPTION"], [encoding objectForKey:@"CHARACTER_SET_NAME"]];
						
			[tableEncodingPopUpButton addItemWithTitle:menuItemTitle];
			
			if ([[tableDataInstance tableEncoding] isEqualToString:[encoding objectForKey:@"CHARACTER_SET_NAME"]]) {
				selectedTitle = menuItemTitle;
			}
		}	
		
		[tableEncodingPopUpButton selectItemWithTitle:selectedTitle];
		[tableEncodingPopUpButton setEnabled:enableInteraction];
	}
	else {
		[tableEncodingPopUpButton addItemWithTitle:@"Not available"];
	}
	
	if (([collations count] > 0) && ([statusFields objectForKey:@"Collation"])) {
		// Populate collation popup button
		for (NSDictionary *collation in collations)
		{		
			[tableCollationPopUpButton addItemWithTitle:[collation objectForKey:@"COLLATION_NAME"]];
		}	
				
		[tableCollationPopUpButton selectItemWithTitle:[statusFields objectForKey:@"Collation"]];
		[tableCollationPopUpButton setEnabled:enableInteraction];
	}
	else {
		[tableCollationPopUpButton addItemWithTitle:@"Not available"];
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
	[tableCommentsTextView setEditable:YES];
	[tableCommentsTextView shouldChangeTextInRange:NSMakeRange(0, [[tableCommentsTextView string] length]) replacementString:[statusFields objectForKey:@"Comment"]];
	[tableCommentsTextView setString:[statusFields objectForKey:@"Comment"]];
	[tableCommentsTextView didChangeText];
	[tableCommentsTextView setEditable:enableInteraction];
	
	// Set create syntax
	[tableCreateSyntaxTextView setEditable:YES];
	[tableCreateSyntaxTextView shouldChangeTextInRange:NSMakeRange(0, [[tableCommentsTextView string] length]) replacementString:@""];
	[tableCreateSyntaxTextView setString:@""];
	[tableCreateSyntaxTextView didChangeText];
	[tableCreateSyntaxTextView shouldChangeTextInRange:NSMakeRange(0, 0) replacementString:[tableDataInstance tableCreateSyntax]];
	[tableCreateSyntaxTextView insertText:[tableDataInstance tableCreateSyntax]];
	[tableCreateSyntaxTextView didChangeText];
	[tableCreateSyntaxTextView setEditable:NO];
}

/**
 * NSTextView delegate. Used to change the selected table's comment.
 */
- (void)textDidEndEditing:(NSNotification *)notification
{
	id object = [notification object];
	if ((object == tableCommentsTextView) && ([object isEditable]) && ([selectedTable length] > 0)) {
		
		NSString *currentComment = [tableDataInstance statusValueForKey:@"Comment"];
		NSString *newComment = [[tableCommentsTextView string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

		// Check that the user actually changed the tables comment
		if (![currentComment isEqualToString:newComment]) {
			
			// Alter table's comment
			[connection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ COMMENT = '%@'", [selectedTable backtickQuotedString], [connection prepareString:newComment]]];
			
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

#pragma mark -
#pragma mark Task interaction

/**
 * Disable all content interactive elements during an ongoing task.
 */
- (void)startDocumentTaskForTab:(NSNotification *)aNotification
{
	// Only proceed if this view is selected.
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableInfo])
		return;

	[tableTypePopUpButton setEnabled:NO];
	[tableEncodingPopUpButton setEnabled:NO];
	[tableCollationPopUpButton setEnabled:NO];
	[tableCommentsTextView setEditable:NO];
}

/**
 * Enable all content interactive elements after an ongoing task.
 */
- (void)endDocumentTaskForTab:(NSNotification *)aNotification
{
	// Only proceed if this view is selected.
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableInfo])
		return;

	NSDictionary *statusFields = [tableDataInstance statusValues];
	
	if (!selectedTable || ![selectedTable length] || [[statusFields objectForKey:@"Engine"] isEqualToString:@"View"])
		return;

	// If we are viewing tables in the information_schema database, then disable all controls that cause table
	// changes as these tables are not modifiable by anyone.
	BOOL isInformationSchemaDb = [[tableDocumentInstance database] isEqualToString:@"information_schema"];
	
	if ([[databaseDataInstance getDatabaseStorageEngines] count] && [statusFields objectForKey:@"Engine"]) {
		[tableTypePopUpButton setEnabled:(!isInformationSchemaDb)];
	}

	if ([[databaseDataInstance getDatabaseCharacterSetEncodings] count] && [tableDataInstance tableEncoding]) {
		[tableEncodingPopUpButton setEnabled:(!isInformationSchemaDb)];
	}

	if ([[databaseDataInstance getDatabaseCollationsForEncoding:[tableDataInstance tableEncoding]] count]
		&& [statusFields objectForKey:@"Collation"])
	{
		[tableCollationPopUpButton setEnabled:(!isInformationSchemaDb)];
	}

	[tableCommentsTextView setEditable:(!isInformationSchemaDb)];
}

#pragma mark -

/**
 * Release connection.
 */
- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

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
			
			value = [NSString stringForByteSize:[value longLongValue]];
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
		// Format numbers
		else if ([key isEqualToString:@"Rows"] ||
				 [key isEqualToString:@"Avg_row_length"] || 
				 [key isEqualToString:@"Auto_increment"]) {
			NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];	
			[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];

			value = [numberFormatter stringFromNumber:[NSNumber numberWithLongLong:[value longLongValue]]];

			// Prefix number of rows with '~' if it is not an accurate count
			if ([key isEqualToString:@"Rows"] && ![[infoDict objectForKey:@"RowsCountAccurate"] boolValue]) {
				value = [@"~" stringByAppendingString:value];
			}
		}
	}
		
	return [NSString stringWithFormat:@"%@: %@", label, ([value length] > 0) ? value : @"Not available"];
}

@end
