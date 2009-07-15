//
//  $Id$
//
//  SPTableRelations.h
//  sequel-pro
//
//  Created by J Knight on 13/05/09.
//  Copyright 2009 J Knight. All rights reserved.
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

#import "SPTableRelations.h"
#import "TableDocument.h"
#import "TablesList.h"
#import "CMMCPConnection.h"
#import "CMMCPResult.h"
#import "SPTableData.h"
#import "SPStringAdditions.h"

@interface SPTableRelations (PrivateAPI)

- (void)_refreshRelationDataForcingCacheRefresh:(BOOL)clearAllCaches;
- (void)_updateAvailableTableColumns;

@end

@implementation SPTableRelations

@synthesize connection;

/**
 * init
 */
- (id)init
{
	if ((self = [super init])) {
		relationData = [[NSMutableArray alloc] init];
	}

	return self;
}

/**
 * Register to listen for table selection changes upon nib awakening.
 */
- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(tableSelectionChanged:) 
												 name:NSTableViewSelectionDidChangeNotification 
											   object:tableList];
}

#pragma mark -
#pragma mark IB action methods

/**
 * Closes the relation sheet.
 */
- (IBAction)closeRelationSheet:(id)sender
{
	// 0 = success
	[NSApp stopModalWithCode:0];
}

/**
 * Add a new relation using the selected values.
 */
- (IBAction)confirmAddRelation:(id)sender
{	
	NSString *thisTable  = [tablesListInstance tableName];
	NSString *thisColumn = [columnPopUpButton titleOfSelectedItem];
	NSString *thatTable  = [refTablePopUpButton titleOfSelectedItem];
	NSString *thatColumn = [refColumnPopUpButton titleOfSelectedItem];
	
	NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD FOREIGN KEY (%@) REFERENCES %@ (%@)", 
												[thisTable backtickQuotedString],
												thisColumn,
												[thatTable backtickQuotedString],
												thatColumn];
	
	// If required add ON DELETE
	if ([onDeletePopUpButton indexOfSelectedItem] > 0) {
		query = [query stringByAppendingString:[NSString stringWithFormat:@" ON DELETE %@", [onDeletePopUpButton titleOfSelectedItem]]];
	}
	
	// If required add ON UPDATE
	if ([onUpdatePopUpButton indexOfSelectedItem] > 0) {
		query = [query stringByAppendingString:[NSString stringWithFormat:@" ON UPDATE %@", [onUpdatePopUpButton titleOfSelectedItem]]];
	}
	
	// Execute query
	[connection queryString:query];
	
	int retCode = (![[connection getLastErrorMessage] isEqualToString:@""]);
		
	[NSApp stopModalWithCode:retCode];	
}

/**
 * Updates the available columns when the user selects a table.
 */
- (IBAction)selectTableColumn:(id)sender
{
	[self _updateAvailableTableColumns];
}

/**
 * Updates the available columns when the user selects a table.
 */
- (IBAction)selectReferenceTable:(id)sender
{
	[self _updateAvailableTableColumns];
}

/**
 * Called whenever the user selected to add a new relation. 
 */
- (IBAction)addRelation:(id)sender
{	
	// Set up the controls
	[addRelationTableBox setTitle:[NSString stringWithFormat:@"Table: %@", [tablesListInstance tableName]]];
	
	[columnPopUpButton removeAllItems];
	[columnPopUpButton addItemsWithTitles:[tableDataInstance columnNames]];
	
	[refTablePopUpButton removeAllItems];
	
	// Get all InnoDB tables in the current database
	CMMCPResult *result = [connection queryString:[NSString stringWithFormat:@"SELECT table_name FROM information_schema.tables WHERE table_type = 'BASE TABLE' AND engine = 'InnoDB' AND table_schema = '%@' AND table_name != '%@'", [tableDocumentInstance database], [tablesListInstance tableName]]];
	
	[result dataSeek:0];
	
	for (int i = 0; i < [result numOfRows]; i++)
	{		
		[refTablePopUpButton addItemWithTitle:[[result fetchRowAsArray] objectAtIndex:0]];
	}
	
	[self selectReferenceTable:nil];
	
	[NSApp beginSheet:addRelationPanel
	   modalForWindow:tableWindow
		modalDelegate:self
	   didEndSelector:nil 
		  contextInfo:nil];
	
	int code = [NSApp runModalForWindow:addRelationPanel];
	
	[NSApp endSheet:addRelationPanel];
	[addRelationPanel orderOut:nil];

	// 0 indicates success
	if (code) {
		NSBeginAlertSheet(NSLocalizedString(@"Error creating relation", @"error creating relation message"), 
						  NSLocalizedString(@"OK", @"OK button"),
						  nil, nil, [NSApp mainWindow], nil, nil, nil, nil, 
						  [NSString stringWithFormat:NSLocalizedString(@"The specified relation was unable to be created.\n\nMySQL said: %@", @"error creating relation informative message"), [connection getLastErrorMessage]]);		
	} 
	else {
		[self _refreshRelationDataForcingCacheRefresh:YES];
	}
}

/**
 * Removes the selected relations.
 */
- (IBAction)removeRelation:(id)sender
{
	if ([relationsTableView numberOfSelectedRows] > 0) {
		
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Delete relation", @"delete relation message") 
										 defaultButton:NSLocalizedString(@"Delete", @"delete button") 
									   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
										   otherButton:nil 
							 informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to delete the selected relations? This action cannot be undone.", @"delete selected relation informative message")];
		
		[alert setAlertStyle:NSCriticalAlertStyle];
		
		[alert beginSheetModalForWindow:tableWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:@"removeRelation"];
	}
}

/**
 * Trigger a refresh of the displayed relations via the interface.
 */
- (IBAction)refreshRelations:(id)sender
{
	[self _refreshRelationDataForcingCacheRefresh:YES];
}

/**
 * Called whenever the user selects a different table.
 */
- (void)tableSelectionChanged:(NSNotification *)notification
{
	// To begin enable all interface elements
	[addRelationButton setEnabled:YES];		
	[refreshRelationsButton setEnabled:YES];
	[relationsTableView setEnabled:YES];
	
	// Get the current table's storage engine
	NSString *engine = [tableDataInstance statusValueForKey:@"Engine"];
	
	if (([tablesListInstance tableType] == SP_TABLETYPE_TABLE) && ([[engine lowercaseString] isEqualToString:@"innodb"])) {
		
		// Update the text label
		[labelTextField setStringValue:[NSString stringWithFormat:@"Relations for table: %@", [tablesListInstance tableName]]];
		
		[addRelationButton setEnabled:YES];
		[refreshRelationsButton setEnabled:YES];
		[relationsTableView setEnabled:YES];
	} 
	else {
		[addRelationButton setEnabled:NO];		
		[refreshRelationsButton setEnabled:NO];	
		[relationsTableView setEnabled:NO];
		
		[labelTextField setStringValue:([tablesListInstance tableType] == SP_TABLETYPE_TABLE) ? @"This table does not support relations" : @""];
	}	
	
	[self _refreshRelationDataForcingCacheRefresh:NO];
}

#pragma mark -
#pragma mark Tableview datasource methods

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [relationData count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)rowIndex
{
	return [[relationData objectAtIndex:rowIndex] objectForKey:[tableColumn identifier]];
}

#pragma mark -
#pragma mark Tableview delegate methods

/**
 * Called whenever the relations table view selection changes.
 */
- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	[removeRelationButton setEnabled:([relationsTableView numberOfSelectedRows] > 0)];
}

#pragma mark -
#pragma mark Other

/**
 * NSAlert didEnd method.
 */
- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{
	if ([contextInfo isEqualToString:@"removeRelation"]) {
		
		if (returnCode == NSAlertDefaultReturn) {
			
			NSString *thisTable = [tablesListInstance tableName];
			NSIndexSet *selectedSet = [relationsTableView selectedRowIndexes];
			
			unsigned int row = [selectedSet lastIndex];
			
			while (row != NSNotFound) 
			{
				NSString *relationName = [[relationData objectAtIndex:row] objectForKey:@"name"];
				NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ DROP FOREIGN KEY %@", [thisTable backtickQuotedString], [relationName backtickQuotedString]];
				
				[connection queryString:query];
				
				if (![[connection getLastErrorMessage] isEqualToString:@""] ) {
					
					NSBeginAlertSheet(NSLocalizedString(@"Unable to remove relation", @"error removing relation message"), 
									  NSLocalizedString(@"OK", @"OK button"),
									  nil, nil, [NSApp mainWindow], nil, nil, nil, nil, 
									  [NSString stringWithFormat:NSLocalizedString(@"The selected relation couldn't be removed.\n\nMySQL said: %@", @"error removing relation informative message"), [connection getLastErrorMessage]]);	
					
					// Abort loop
					break;
				} 
				
				row = [selectedSet indexLessThanIndex:row];
			}
			
			[self _refreshRelationDataForcingCacheRefresh:YES];
		}
	} 
}

/**
 * Menu validation
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// Remove row
	if ([menuItem action] == @selector(removeRelation:)) {
		[menuItem setTitle:([relationsTableView numberOfSelectedRows] > 1) ? @"Delete Relations" : @"Delete Relation"];
		
		return ([relationsTableView numberOfSelectedRows] > 0);
	}
	
	return YES;
}

/*
 * Dealloc.
 */
- (void)dealloc
{	
	[relationData release], relationData = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}

@end

@implementation SPTableRelations (PrivateAPI)

/**
 * Refresh the displayed relations, optionally forcing a refresh of the underlying cache.
 */
- (void)_refreshRelationDataForcingCacheRefresh:(BOOL)clearAllCaches
{
	[relationData removeAllObjects];
	
	if ([tablesListInstance tableType] == SP_TABLETYPE_TABLE) {
		
		if (clearAllCaches) [tableDataInstance updateInformationForCurrentTable];
				
		NSArray *constraints = [tableDataInstance getConstraints];
		
		for (NSDictionary *constraint in constraints) 
		{
			[relationData addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[constraint objectForKey:@"name"], @"name",
									[constraint objectForKey:@"columns"], @"columns",
									[constraint objectForKey:@"ref_table"], @"fk_table",
									[constraint objectForKey:@"ref_columns"], @"fk_columns",
									[constraint objectForKey:@"update"], @"on_update",
									[constraint objectForKey:@"delete"], @"on_delete",
									nil]];
			
		}
	} 
	
	[relationsTableView reloadData];
}

/**
 * Updates the available table columns that the reference is pointing to. Available columns are those that are
 * within the selected table and are of the same data type as the column the reference is from.
 */
- (void)_updateAvailableTableColumns
{
	NSString *column = [columnPopUpButton titleOfSelectedItem];
	NSString *table = [refTablePopUpButton titleOfSelectedItem];
		
	[tableDataInstance resetAllData];
	[tableDataInstance updateInformationForCurrentTable];
	
	NSDictionary *columnInfo = [[tableDataInstance columnWithName:column] copy];
		
	[refColumnPopUpButton setEnabled:NO];
	[confirmAddRelationButton setEnabled:NO];
	
	[refColumnPopUpButton removeAllItems];
	
	[tableDataInstance resetAllData];
	NSDictionary *tableInfo = [tableDataInstance informationForTable:table];
	
	NSArray *columns = [tableInfo objectForKey:@"columns"];
	
	NSMutableArray *validColumns = [NSMutableArray array];
	
	// Only add columns of the same data type
	for (int i = 0; i < [columns count]; i++) 
	{		
		if ([[columnInfo objectForKey:@"type"] isEqualToString:[[columns objectAtIndex:i] objectForKey:@"type"]]) {
			[validColumns addObject:[[columns objectAtIndex:i] objectForKey:@"name"]];			
		}
	}
	
	// Add the valid columns
	if ([validColumns count] > 0) {
		[refColumnPopUpButton addItemsWithTitles:validColumns];
		
		[refColumnPopUpButton setEnabled:YES];
		[confirmAddRelationButton setEnabled:YES];
	}
	
	[columnInfo release];
}

@end
