//
//  $Id$
//
//  TablesList.m
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed May 01 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
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

#import "TablesList.h"
#import "TableDocument.h"
#import "TableSource.h"
#import "TableContent.h"
#import "SPTableData.h"
#import "TableDump.h"
#import "ImageAndTextCell.h"
#import "SPStringAdditions.h"
#import "SPArrayAdditions.h"
#import "RegexKitLite.h"
#import "SPDatabaseData.h"
#import "NSMutableArray-MultipleSort.h"
#import "NSNotificationAdditions.h"
#import "SPConstants.h"

@interface TablesList (PrivateAPI)

- (void)removeTable;
- (void)truncateTable;
- (void)addTable;
- (void)copyTable;
- (void)renameTable;
- (BOOL)isTableNameValid:(NSString *)tableName;

@end

@implementation TablesList

#pragma mark -
#pragma mark IBAction methods

/**
 * Loads all table names in array tables and reload the tableView
 */
- (IBAction)updateTables:(id)sender
{
	MCPResult *theResult;
	NSArray *resultRow;
	int i;
	NSString *previousSelectedTable = nil;
	NSInteger selectedRowIndex;
	BOOL previousTableListIsSelectable = tableListIsSelectable;
	
	selectedRowIndex = [tablesListView selectedRow];
	
	if (selectedTableName) previousSelectedTable = [[NSString alloc] initWithString:selectedTableName];
	if (isTableListFiltered) {
		if (filteredTables) [filteredTables release];
		filteredTables = tables;
		if (filteredTableTypes) [filteredTableTypes release];
		filteredTableTypes = tableTypes;
		isTableListFiltered = NO;
	}
	tableListContainsViews = NO;
	
	tableListIsSelectable = YES;
	[tablesListView deselectAll:self];
	tableListIsSelectable = previousTableListIsSelectable;
	[tables removeAllObjects];
	[tableTypes removeAllObjects];

	if ([tableDocumentInstance database]) {

		// Notify listeners that a query has started
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:tableDocumentInstance];

		// Select the table list for the current database.  On MySQL versions after 5 this will include
		// views; on MySQL versions >= 5.0.02 select the "full" list to also select the table type column.
		theResult = [mySQLConnection queryString:@"SHOW /*!50002 FULL*/ TABLES"];
		if ([theResult numOfRows]) [theResult dataSeek:0];
		if ([theResult numOfFields] == 1) {
			for ( i = 0 ; i < [theResult numOfRows] ; i++ ) {
				[tables addObject:[[theResult fetchRowAsArray] objectAtIndex:0]];
				[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_TABLE]];
			}		
		} else {
			for ( i = 0 ; i < [theResult numOfRows] ; i++ ) {
				resultRow = [theResult fetchRowAsArray];
				[tables addObject:[resultRow objectAtIndex:0]];
				if ([[resultRow objectAtIndex:1] isEqualToString:@"VIEW"]) {
					[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_VIEW]];
					tableListContainsViews = YES;
				} else {
					[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_TABLE]];
				}
			}		
		}
		
		// Reorder the tables in alphabetical order
		[tables sortArrayUsingSelector:@selector(localizedCompare:) withPairedMutableArrays:tableTypes, nil];

		/* grab the procedures and functions
		 *
		 * using information_schema gives us more info (for information window perhaps?) but breaks
		 * backward compatibility with pre 4 I believe. I left the other methods below, in case.
		 */
		NSString *pQuery = [NSString stringWithFormat:@"SELECT * FROM information_schema.routines WHERE routine_schema = '%@' ORDER BY routine_name",[tableDocumentInstance database]];
		theResult = [mySQLConnection queryString:pQuery];
		
		// Check for mysql errors - if information_schema is not accessible for some reasons
		// omit adding procedures and functions
		if([[mySQLConnection getLastErrorMessage] isEqualToString:@""] && theResult != nil && [theResult numOfRows] ) {
			// add the header row
			[tables addObject:NSLocalizedString(@"PROCS & FUNCS",@"header for procs & funcs list")];
			[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_NONE]];
			[theResult dataSeek:0];
			
			if( [theResult numOfFields] == 1 ) {
				for( i = 0; i < [theResult numOfRows]; i++ ) {
					[tables addObject:NSArrayObjectAtIndex([theResult fetchRowAsArray],3)];
					if( [NSArrayObjectAtIndex([theResult fetchRowAsArray], 4) isEqualToString:@"PROCEDURE"]) {
						[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_PROC]];
					} else {
						[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_FUNC]];
					}
				}
			} else {
				for( i = 0; i < [theResult numOfRows]; i++ ) {
					resultRow = [theResult fetchRowAsArray];
					[tables addObject:NSArrayObjectAtIndex(resultRow, 3)];
					if( [NSArrayObjectAtIndex(resultRow, 4) isEqualToString:@"PROCEDURE"] ) {
						[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_PROC]];
					} else {
						[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_FUNC]];
					}
				}	
			}
		}
		
		/*
		BOOL addedPFHeader = FALSE;
		NSString *pQuery = [NSString stringWithFormat:@"SHOW PROCEDURE STATUS WHERE db = '%@'",[tableDocumentInstance database]];
		theResult = [mySQLConnection queryString:pQuery];
		
		if( [theResult numOfRows] ) {
			// add the header row
			[tables addObject:NSLocalizedString(@"PROCS & FUNCS",@"header for procs & funcs list")];
			[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_NONE]];
			addedPFHeader = TRUE;
			[theResult dataSeek:0];
			
			if( [theResult numOfFields] == 1 ) {
				for( i = 0; i < [theResult numOfRows]; i++ ) {
					[tables addObject:[[theResult fetchRowAsArray] objectAtIndex:1]];
					[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_PROC]];
				}
			} else {
				for( i = 0; i < [theResult numOfRows]; i++ ) {
					resultRow = [theResult fetchRowAsArray];
					[tables addObject:[resultRow objectAtIndex:1]];
					[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_PROC]];
				}	
			}
		}
		
		pQuery = [NSString stringWithFormat:@"SHOW FUNCTION STATUS WHERE db = '%@'",[tableDocumentInstance database]];
		theResult = [mySQLConnection queryString:pQuery];
		
		if( [theResult numOfRows] ) {
			if( !addedPFHeader ) {
				// add the header row			
				[tables addObject:NSLocalizedString(@"PROCS & FUNCS",@"header for procs & funcs list")];
				[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_NONE]];
			}
			[theResult dataSeek:0];
			
			if( [theResult numOfFields] == 1 ) {
				for( i = 0; i < [theResult numOfRows]; i++ ) {
					[tables addObject:[[theResult fetchRowAsArray] objectAtIndex:1]];
					[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_FUNC]];
				}
			} else {
				for( i = 0; i < [theResult numOfRows]; i++ ) {
					resultRow = [theResult fetchRowAsArray];
					[tables addObject:[resultRow objectAtIndex:1]];
					[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_FUNC]];
				}	
			}
		}
		*/		
		// Notify listeners that the query has finished
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];
	}

	// Add the table headers even if no tables were found
	if (tableListContainsViews) {
		[tables insertObject:NSLocalizedString(@"TABLES & VIEWS",@"header for table & views list") atIndex:0];
	} else {
		[tables insertObject:NSLocalizedString(@"TABLES",@"header for table list") atIndex:0];
	}
	[tableTypes insertObject:[NSNumber numberWithInt:SP_TABLETYPE_NONE] atIndex:0];

	[tablesListView reloadData];
	
	// if the previous selected table still exists, select it
	if( previousSelectedTable != nil && [tables indexOfObject:previousSelectedTable] < [tables count]) {
		int itemToReselect = [tables indexOfObject:previousSelectedTable];
		tableListIsSelectable = YES;
		[tablesListView selectRowIndexes:[NSIndexSet indexSetWithIndex:itemToReselect] byExtendingSelection:NO];
		tableListIsSelectable = previousTableListIsSelectable;
		if (selectedTableName) [selectedTableName release];
		selectedTableName = [[NSString alloc] initWithString:[tables objectAtIndex:itemToReselect]];
		selectedTableType = [[tableTypes objectAtIndex:itemToReselect] intValue];
	} else {
		if (selectedTableName) [selectedTableName release];
		selectedTableName = nil;
		selectedTableType = SP_TABLETYPE_NONE;
	}

	// Determine whether or not to show the list filter based on the number of tables, and clear it
	[self clearFilter];
	if ([tables count] > 20) [self showFilter];
	else [self hideFilter];

	// Set the filter placeholder text
	if ([tableDocumentInstance database]) {
		[[listFilterField cell] setPlaceholderString:NSLocalizedString(@"Filter", @"Filter placeholder")];
	}

	if (previousSelectedTable) [previousSelectedTable release];
}

/**
 * Adds a new table to the tables-array (no changes in mysql-db)
 */
- (IBAction)addTable:(id)sender
{
	if ((![tableSourceInstance saveRowOnDeselect]) || (![tableContentInstance saveRowOnDeselect]) || (![tableDocumentInstance database])) {
		return;
	}

	[tableWindow endEditingFor:nil];
	
	// Populate the table type (engine) popup button
	[tableTypeButton removeAllItems];
	
	NSArray *engines = [databaseDataInstance getDatabaseStorageEngines];
		
	// Add default menu item
	[tableTypeButton addItemWithTitle:@"Default"];
	[[tableTypeButton menu] addItem:[NSMenuItem separatorItem]];
	
	for (NSDictionary *engine in engines)
	{
		[tableTypeButton addItemWithTitle:[engine objectForKey:@"Engine"]];
	}
	
	[NSApp beginSheet:tableSheet
	   modalForWindow:tableWindow
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:@"addTable"];
}

/**
 * Closes the current sheet and stops the modal session
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

/**
 * Invoked when user hits the remove button alert sheet to ask user if he really wants to delete the table.
 */
- (IBAction)removeTable:(id)sender
{
	if (![tablesListView numberOfSelectedRows])
		return;
	
	[tableWindow endEditingFor:nil];
	
	NSAlert *alert = [NSAlert alertWithMessageText:@"" defaultButton:NSLocalizedString(@"Delete", @"delete button") alternateButton:NSLocalizedString(@"Cancel", @"cancel button") otherButton:nil informativeTextWithFormat:@""];

	[alert setAlertStyle:NSCriticalAlertStyle];

	NSArray *buttons = [alert buttons];
	
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"d"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
	
	NSIndexSet *indexes = [tablesListView selectedRowIndexes];

	NSString *tblTypes;
	unsigned currentIndex = [indexes lastIndex];
	
	if ([tablesListView numberOfSelectedRows] == 1) {
		if([[filteredTableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_VIEW)
			tblTypes = NSLocalizedString(@"view", @"view");
		else if([[filteredTableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_TABLE)
			tblTypes = NSLocalizedString(@"table", @"table");
		else if([[filteredTableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_PROC)
			tblTypes = NSLocalizedString(@"procedure", @"procedure");
		else if([[filteredTableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_FUNC)
			tblTypes = NSLocalizedString(@"function", @"function");
		
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Delete %@ '%@'?", @"delete table/view message"), tblTypes, [filteredTables objectAtIndex:[tablesListView selectedRow]]]];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the %@ '%@'. This operation cannot be undone.", @"delete table/view informative message"), tblTypes, [filteredTables objectAtIndex:[tablesListView selectedRow]]]];
	} 
	else {

		BOOL areTableTypeEqual = YES;
		int lastType = [[filteredTableTypes objectAtIndex:currentIndex] intValue];
		while (currentIndex != NSNotFound)
		{
			if([[filteredTableTypes objectAtIndex:currentIndex] intValue]!=lastType)
			{
				areTableTypeEqual = NO;
				break;
			}
			currentIndex = [indexes indexLessThanIndex:currentIndex];
		}
		if(areTableTypeEqual)
		{
			switch(lastType) {
				case SP_TABLETYPE_TABLE:
				tblTypes = NSLocalizedString(@"tables", @"tables");
				break;
				case SP_TABLETYPE_VIEW:
				tblTypes = NSLocalizedString(@"views", @"views");
				break;
				case SP_TABLETYPE_PROC:
				tblTypes = NSLocalizedString(@"procedures", @"procedures");
				break;
				case SP_TABLETYPE_FUNC:
				tblTypes = NSLocalizedString(@"functions", @"functions");
				break;
			}
			
		} else
			tblTypes = NSLocalizedString(@"items", @"items");

		[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Delete selected %@?", @"delete tables/views message"), tblTypes]];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the selected %@. This operation cannot be undone.", @"delete tables/views informative message"), tblTypes]];
	}
		
	[alert beginSheetModalForWindow:tableWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"removeRow"];
}

/**
 * Copies a table/view/proc/func, if desired with content
 */
- (IBAction)copyTable:(id)sender
{
	NSString *tableType;

	if ([tablesListView numberOfSelectedRows] != 1) return;
	if (![tableSourceInstance saveRowOnDeselect] || ![tableContentInstance saveRowOnDeselect]) return;
	
	[tableWindow endEditingFor:nil];

	// Detect table type: table or view
	int tblType = [[filteredTableTypes objectAtIndex:[tablesListView selectedRow]] intValue];
	
	switch (tblType){
		case SP_TABLETYPE_TABLE:
			tableType = NSLocalizedString(@"table",@"table");
			[copyTableContentSwitch setEnabled:YES];
			break;
		case SP_TABLETYPE_VIEW:
			tableType = NSLocalizedString(@"view",@"view");
			[copyTableContentSwitch setEnabled:NO];
			break;
		case SP_TABLETYPE_PROC:
			tableType = NSLocalizedString(@"procedure",@"procedure");
			[copyTableContentSwitch setEnabled:NO];
			break;
		case SP_TABLETYPE_FUNC:
			tableType = NSLocalizedString(@"function",@"function");
			[copyTableContentSwitch setEnabled:NO];
			break;
	}
		
	[copyTableMessageField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Duplicate %@ '%@' to:", @"duplicate object message"), tableType, [self tableName]]];

	//open copyTableSheet
	[copyTableNameField setStringValue:[NSString stringWithFormat:@"%@_copy", [filteredTables objectAtIndex:[tablesListView selectedRow]]]];
	[copyTableContentSwitch setState:NSOffState];
	
	[NSApp beginSheet:copyTableSheet
	   modalForWindow:tableWindow
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:@"copyTable"];
}

/**
 * Renames the currently selected table.
 */
- (IBAction)renameTable:(id)sender
{
	if ((![tableSourceInstance saveRowOnDeselect]) || (![tableContentInstance saveRowOnDeselect]) || (![tableDocumentInstance database])) {
		return;
	}
	
	[tableWindow endEditingFor:nil];
	[tableRenameField setStringValue:[self tableName]];
	[renameTableButton setEnabled:NO];
	
	NSString *tableType;
	
	switch([self tableType]){
		case SP_TABLETYPE_TABLE:
		tableType = NSLocalizedString(@"table",@"table");
		break;
		case SP_TABLETYPE_VIEW:
		tableType = NSLocalizedString(@"view",@"view");
		break;
		case SP_TABLETYPE_PROC:
		tableType = NSLocalizedString(@"procedure",@"procedure");
		break;
		case SP_TABLETYPE_FUNC:
		tableType = NSLocalizedString(@"function",@"function");
		break;
	}
	
	[tableRenameText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Rename %@ '%@' to:",@"rename item name to:"), tableType, [self tableName]]];
	
	[NSApp beginSheet:tableRenameSheet
	   modalForWindow:tableWindow
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:@"renameTable"];
}

/**
 * Truncates the currently selected table(s).
 */
- (IBAction)truncateTable:(id)sender
{
	if (![tablesListView numberOfSelectedRows])
		return;
	
	[tableWindow endEditingFor:nil];
	
	NSAlert *alert = [NSAlert alertWithMessageText:@"" 
									 defaultButton:NSLocalizedString(@"Truncate", @"truncate button") 
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button") 
									   otherButton:nil 
						 informativeTextWithFormat:@""];
	
	[alert setAlertStyle:NSCriticalAlertStyle];
	
	NSArray *buttons = [alert buttons];
	
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"t"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
	
	if ([tablesListView numberOfSelectedRows] == 1) {
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Truncate table '%@'?", @"truncate table message"), [filteredTables objectAtIndex:[tablesListView selectedRow]]]];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete ALL records in the table '%@'. This operation cannot be undone.", @"truncate table informative message"), [filteredTables objectAtIndex:[tablesListView selectedRow]]]];
	} 
	else {
		[alert setMessageText:NSLocalizedString(@"Truncate selected tables?", @"truncate tables message")];
		[alert setInformativeText:NSLocalizedString(@"Are you sure you want to delete ALL records in the selected tables. This operation cannot be undone.", @"truncate tables informative message")];
	}
	
	[alert beginSheetModalForWindow:tableWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"truncateTable"];
}

/**
 * Toggle whether the splitview is collapsed.
 */
- (IBAction)togglePaneCollapse:(id)sender
{
	[tableListSplitView toggleCollapse:sender];
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:([tableInfoCollapseButton state] == NSOffState)] forKey:SPTableInformationPanelCollapsed];
	[tableInfoCollapseButton setToolTip:([tableInfoCollapseButton state] == NSOffState) ? NSLocalizedString(@"Show Table Information", @"Show Table Information") : NSLocalizedString(@"Hide Table Information", @"Hide Table Information")];
}

#pragma mark -
#pragma mark Alert sheet methods

/**
 * Method for alert sheets.
 */
- (void)sheetDidEnd:(id)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{
	// Order out current sheet to suppress overlapping of sheets
	if ([sheet respondsToSelector:@selector(orderOut:)])
		[sheet orderOut:nil];

	if ([contextInfo isEqualToString:@"addRow"]) {
		alertSheetOpened = NO;
	} 
	else if ([contextInfo isEqualToString:@"removeRow"]) {
		if (returnCode == NSAlertDefaultReturn) {
			[self performSelector:@selector(removeTable) withObject:nil afterDelay:0.0];
		}
	}
	else if ([contextInfo isEqualToString:@"truncateTable"]) {
		if (returnCode == NSAlertDefaultReturn) {
			[self truncateTable];
		}
	}
	else if ([contextInfo isEqualToString:@"addTable"]) {
		if (returnCode == NSOKButton) {
			[self addTable];
		}
	}
	else if ([contextInfo isEqualToString:@"copyTable"]) {
		if (returnCode == NSOKButton) {
			[self copyTable];
		}
	}
	else if ([contextInfo isEqualToString:@"renameTable"]) {
		if (returnCode == NSOKButton) {
			[self renameTable];
		}
	}
}

#pragma mark -
#pragma mark Additional methods

/**
 * Sets the connection (received from TableDocument) and makes things that have to be done only once 
 */
- (void)setConnection:(MCPConnection *)theConnection
{
	mySQLConnection = theConnection;
	[self updateTables:self];
}

/**
 * Selects customQuery tab and passes query to customQueryInstance
 */
- (void)doPerformQueryService:(NSString *)query
{
	[tabView selectTabViewItemAtIndex:2];
	[customQueryInstance doPerformQueryService:query];
}

/**
 * Performs interface validation for various controls.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{

	id object = [notification object];

	if (object == tableNameField) {
		[addTableButton setEnabled:[self isTableNameValid:[tableNameField stringValue]]];
	}

	else if (object == copyTableNameField) {
		[copyTableButton setEnabled:[self isTableNameValid:[copyTableNameField stringValue]]];
	}

	else if (object == tableRenameField) {
		[renameTableButton setEnabled:[self isTableNameValid:[tableRenameField stringValue]]];
	}

}

/*
 * Controls the NSTextField's press RETURN event of Add/Rename/Duplicate sheets
 */
- (void)controlTextDidEndEditing:(NSNotification *)notification
{
	id object = [notification object];

	// Only RETURN/ENTER will be recognized for Add/Rename/Duplicate sheets to
	// activate the Add/Rename/Duplicate buttons
	if([[[notification userInfo] objectForKey:@"NSTextMovement"] intValue] != 0)
		return;

	if (object == tableRenameField) {
		[renameTableButton performClick:object];
	}
	else if (object == tableNameField) {
		[addTableButton performClick:object];
	}
	else if (object == copyTableNameField) {
		[copyTableButton performClick:object];
	}
}

/**
 * Updates the current table selection.  Triggered most times tableViewSelectionDidChange:
 * fires, and also as a result of certain table actions.
 */
- (void)updateSelectionWithTaskString:(NSString *)taskString
{

	// If there is a multiple or blank selection, clear all views directly.
	if ( [tablesListView numberOfSelectedRows] != 1 || ![[filteredTables objectAtIndex:[tablesListView selectedRow]] length] ) {
		NSIndexSet *indexes = [tablesListView selectedRowIndexes];

		// Update the selected table name and type
		if (selectedTableName) [selectedTableName release];
		if ([indexes count]) {
			selectedTableName = [[NSString alloc] initWithString:@""];
		} else {
			selectedTableName = nil;
		}
		selectedTableType = SP_TABLETYPE_NONE;

		[tableSourceInstance loadTable:nil];
		[tableContentInstance loadTable:nil];
		[extendedTableInfoInstance performSelectorOnMainThread:@selector(loadTable:) withObject:nil waitUntilDone:YES];
		structureLoaded = NO;
		contentLoaded = NO;
		statusLoaded = NO;

		// Set gear menu items Remove/Duplicate table/view according to the table types
		// if at least one item is selected
		if([indexes count]) {
			unsigned int currentIndex = [indexes lastIndex];
			BOOL areTableTypeEqual = YES;
			int lastType = [[filteredTableTypes objectAtIndex:currentIndex] intValue];
			while (currentIndex != NSNotFound)
			{
				if ([[filteredTableTypes objectAtIndex:currentIndex] intValue] != lastType)
				{
					areTableTypeEqual = NO;
					break;
				}
				currentIndex = [indexes indexLessThanIndex:currentIndex];
			}
			if (areTableTypeEqual)
			{
				switch (lastType) {
					case SP_TABLETYPE_TABLE:
					[removeTableMenuItem setTitle:NSLocalizedString(@"Remove Tables", @"remove tables menu title")];
					[truncateTableButton setTitle:NSLocalizedString(@"Truncate Tables", @"truncate tables menu item")];
					[removeTableContextMenuItem setTitle:NSLocalizedString(@"Remove Tables", @"remove tables menu title")];
					[truncateTableContextButton setTitle:NSLocalizedString(@"Truncate Tables", @"truncate tables menu item")];
					[truncateTableButton setHidden:NO];
					[truncateTableContextButton setHidden:NO];
					break;
					case SP_TABLETYPE_VIEW:
					[removeTableMenuItem setTitle:NSLocalizedString(@"Remove Views", @"remove views menu title")];
					[removeTableContextMenuItem setTitle:NSLocalizedString(@"Remove Views", @"remove views menu title")];
					[truncateTableButton setHidden:YES];
					[truncateTableContextButton setHidden:YES];
					break;
					case SP_TABLETYPE_PROC:
					[removeTableMenuItem setTitle:NSLocalizedString(@"Remove Procedures", @"remove procedures menu title")];
					[removeTableContextMenuItem setTitle:NSLocalizedString(@"Remove Procedures", @"remove procedures menu title")];
					[truncateTableButton setHidden:YES];
					[truncateTableContextButton setHidden:YES];
					break;
					case SP_TABLETYPE_FUNC:
					[removeTableMenuItem setTitle:NSLocalizedString(@"Remove Functions", @"remove functions menu title")];
					[removeTableContextMenuItem setTitle:NSLocalizedString(@"Remove Functions", @"remove functions menu title")];
					[truncateTableButton setHidden:YES];
					[truncateTableContextButton setHidden:YES];
					break;
				}
			
			} else {
				[removeTableMenuItem setTitle:NSLocalizedString(@"Remove Items", @"remove items menu title")];
				[removeTableContextMenuItem setTitle:NSLocalizedString(@"Remove Items", @"remove items menu title")];
				[truncateTableButton setHidden:YES];
				[truncateTableContextButton setHidden:YES];
			}
		}
		[renameTableContextMenuItem setHidden:YES];
		[duplicateTableContextMenuItem setHidden:YES];
		[separatorTableContextMenuItem setHidden:YES];

		[renameTableMenuItem setHidden:YES];
		[duplicateTableMenuItem setHidden:YES];
		[separatorTableMenuItem setHidden:YES];
		[separatorTableContextMenuItem setHidden:YES];

		// set window title
		[tableWindow setTitle:[tableDocumentInstance displaySPName]];
		
		// Add a history entry
		[spHistoryControllerInstance updateHistoryEntries];
		
		// Notify listeners of the table change now that the state is fully set up
		[[NSNotificationCenter defaultCenter] postNotificationName:SPTableChangedNotification object:tableDocumentInstance];

		return;
	}

	// Otherwise, set up a task
	[tableDocumentInstance startTaskWithDescription:taskString];

	// If on the main thread, fire up a thread to deal with view changes and data loading, else perform inline
	if ([NSThread isMainThread]) {
		[NSThread detachNewThreadSelector:@selector(updateSelectionTask) toTarget:self withObject:nil];
	} else {
		[self updateSelectionTask];
	}
}

- (void) updateSelectionTask
{	
	NSAutoreleasePool *selectionChangePool = [[NSAutoreleasePool alloc] init];
	NSString *tableEncoding = nil;

	// Update the selected table name and type
	if (selectedTableName) [selectedTableName release];
	selectedTableName = [[NSString alloc] initWithString:[filteredTables objectAtIndex:[tablesListView selectedRow]]];
	selectedTableType = [[filteredTableTypes objectAtIndex:[tablesListView selectedRow]] intValue];
	
	// Remove the "current selection" item for filtered lists if appropriate
	if (isTableListFiltered && [tablesListView selectedRow] < [filteredTables count] - 2 && [filteredTables count] > 2
		&& [[filteredTableTypes objectAtIndex:[filteredTableTypes count]-2] intValue] == SP_TABLETYPE_NONE
		&& [[filteredTables objectAtIndex:[filteredTables count]-2] isEqualToString:NSLocalizedString(@"CURRENT SELECTION",@"header for current selection in filtered list")])
	{
		[filteredTables removeObjectsInRange:NSMakeRange([filteredTables count]-2, 2)];
		[filteredTableTypes removeObjectsInRange:NSMakeRange([filteredTableTypes count]-2, 2)];
		[tablesListView reloadData];
	}
		
	// Reset the table information caches
	[tableDataInstance resetAllData];

	// Check the encoding if appropriate to determine if an encoding change and reset is required
	if( selectedTableType == SP_TABLETYPE_VIEW || selectedTableType == SP_TABLETYPE_TABLE) {

		// tableEncoding == nil indicates that there was an error while retrieving table data
		tableEncoding = [tableDataInstance tableEncoding];

		// If encoding is set to Autodetect, update the connection character set encoding
		// based on the newly selected table's encoding - but only if it differs from the current encoding.
		if ([[[NSUserDefaults standardUserDefaults] objectForKey:SPDefaultEncoding] isEqualToString:@"Autodetect"]) {
			if (tableEncoding != nil && ![tableEncoding isEqualToString:[tableDocumentInstance connectionEncoding]]) {
				[tableDocumentInstance setConnectionEncoding:tableEncoding reloadingViews:NO];
				[tableDataInstance resetAllData];
				tableEncoding = [tableDataInstance tableEncoding];
			}
		}
	}

	// Ensure status information is cached on the working thread	
	[tableDataInstance updateStatusInformationForCurrentTable];

	// Notify listeners of the table change now that the state is fully set up.
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:SPTableChangedNotification object:tableDocumentInstance];

	[separatorTableMenuItem setHidden:NO];
	[separatorTableContextMenuItem setHidden:NO];

	if( selectedTableType == SP_TABLETYPE_VIEW || selectedTableType == SP_TABLETYPE_TABLE) {
		if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 0 ) {
			[tableSourceInstance loadTable:selectedTableName];
			structureLoaded = YES;
			contentLoaded = NO;
			statusLoaded = NO;
		} else if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 1 ) {
			if(tableEncoding == nil) {
				[tableContentInstance loadTable:nil];
			} else {
				[tableContentInstance loadTable:selectedTableName];
			}
			structureLoaded = NO;
			contentLoaded = YES;
			statusLoaded = NO;
		} else if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 3 ) {
			[extendedTableInfoInstance performSelectorOnMainThread:@selector(loadTable:) withObject:selectedTableName waitUntilDone:YES];
			structureLoaded = NO;
			contentLoaded = NO;
			statusLoaded = YES;
		} else {
			structureLoaded = NO;
			contentLoaded = NO;
			statusLoaded = NO;
		}
	} else {

		// if we are not looking at a table or view, clear these
		[tableSourceInstance loadTable:nil];
		[tableContentInstance loadTable:nil];
		[extendedTableInfoInstance performSelectorOnMainThread:@selector(loadTable:) withObject:nil waitUntilDone:YES];
		structureLoaded = NO;
		contentLoaded = NO;
		statusLoaded = NO;
	}

	// Set gear menu items Remove/Duplicate table/view and mainMenu > Table items
	// according to the table types
	NSMenu *tableSubMenu = [[[NSApp mainMenu] itemWithTitle:@"Table"] submenu];
	
	if(selectedTableType == SP_TABLETYPE_VIEW)
	{
		// Change mainMenu > Table > ... according to table type
		[[tableSubMenu itemAtIndex:0] setTitle:NSLocalizedString(@"Copy Create View Syntax", @"copy create view syntax menu item")];
		[[tableSubMenu itemAtIndex:1] setTitle:NSLocalizedString(@"Show Create View Syntax", @"show create view syntax menu item")];
		[[tableSubMenu itemAtIndex:2] setHidden:NO]; // divider
		[[tableSubMenu itemAtIndex:3] setHidden:NO];
		[[tableSubMenu itemAtIndex:3] setTitle:NSLocalizedString(@"Check View", @"check view menu item")];
		[[tableSubMenu itemAtIndex:4] setHidden:YES]; // repair
		[[tableSubMenu itemAtIndex:5] setHidden:YES]; // divider
		[[tableSubMenu itemAtIndex:6] setHidden:YES]; // analyse
		[[tableSubMenu itemAtIndex:7] setHidden:YES]; // optimize
		[[tableSubMenu itemAtIndex:8] setHidden:NO];
		[[tableSubMenu itemAtIndex:8] setTitle:NSLocalizedString(@"Flush View", @"flush view menu item")];
		[[tableSubMenu itemAtIndex:9] setHidden:YES]; // checksum

		[renameTableMenuItem setHidden:NO]; // we don't have to check the mysql version
		[renameTableMenuItem setTitle:NSLocalizedString(@"Rename View...", @"rename view menu title")];
		[duplicateTableMenuItem setHidden:NO];
		[duplicateTableMenuItem setTitle:NSLocalizedString(@"Duplicate View...", @"duplicate view menu title")];
		[truncateTableButton setHidden:YES];
		[removeTableMenuItem setTitle:NSLocalizedString(@"Remove View", @"remove view menu title")];

		[renameTableContextMenuItem setHidden:NO]; // we don't have to check the mysql version
		[renameTableContextMenuItem setTitle:NSLocalizedString(@"Rename View...", @"rename view menu title")];
		[duplicateTableContextMenuItem setHidden:NO];
		[duplicateTableContextMenuItem setTitle:NSLocalizedString(@"Duplicate View...", @"duplicate view menu title")];
		[truncateTableContextButton setHidden:YES];
		[removeTableContextMenuItem setTitle:NSLocalizedString(@"Remove View", @"remove view menu title")];
	} 
	else if(selectedTableType == SP_TABLETYPE_TABLE) {
		[[tableSubMenu itemAtIndex:0] setTitle:NSLocalizedString(@"Copy Create Table Syntax", @"copy create table syntax menu item")];
		[[tableSubMenu itemAtIndex:1] setTitle:NSLocalizedString(@"Show Create Table Syntax", @"show create table syntax menu item")];
		[[tableSubMenu itemAtIndex:2] setHidden:NO]; // divider
		[[tableSubMenu itemAtIndex:3] setHidden:NO];
		[[tableSubMenu itemAtIndex:3] setTitle:NSLocalizedString(@"Check Table", @"check table menu item")];
		[[tableSubMenu itemAtIndex:4] setHidden:NO];
		[[tableSubMenu itemAtIndex:5] setHidden:NO]; // divider
		[[tableSubMenu itemAtIndex:6] setHidden:NO];
		[[tableSubMenu itemAtIndex:7] setHidden:NO];
		[[tableSubMenu itemAtIndex:8] setHidden:NO];
		[[tableSubMenu itemAtIndex:8] setTitle:NSLocalizedString(@"Flush Table", @"flush table menu item")];
		[[tableSubMenu itemAtIndex:9] setHidden:NO];

		[renameTableMenuItem setHidden:NO];
		[renameTableMenuItem setTitle:NSLocalizedString(@"Rename Table...", @"rename table menu title")];
		[duplicateTableMenuItem setHidden:NO];
		[duplicateTableMenuItem setTitle:NSLocalizedString(@"Duplicate Table...", @"duplicate table menu title")];
		[truncateTableButton setHidden:NO];
		[truncateTableButton setTitle:NSLocalizedString(@"Truncate Table", @"truncate table menu title")];
		[removeTableMenuItem setTitle:NSLocalizedString(@"Remove Table", @"remove table menu title")];

		[renameTableContextMenuItem setHidden:NO];
		[renameTableContextMenuItem setTitle:NSLocalizedString(@"Rename Table...", @"rename table menu title")];
		[duplicateTableContextMenuItem setHidden:NO];
		[duplicateTableContextMenuItem setTitle:NSLocalizedString(@"Duplicate Table...", @"duplicate table menu title")];
		[truncateTableContextButton setHidden:NO];
		[truncateTableContextButton setTitle:NSLocalizedString(@"Truncate Table", @"truncate table menu title")];
		[removeTableContextMenuItem setTitle:NSLocalizedString(@"Remove Table", @"remove table menu title")];

	} 
	else if(selectedTableType == SP_TABLETYPE_PROC) {
		[[tableSubMenu itemAtIndex:0] setTitle:NSLocalizedString(@"Copy Create Procedure Syntax", @"copy create proc syntax menu item")];
		[[tableSubMenu itemAtIndex:1] setTitle:NSLocalizedString(@"Show Create Procedure Syntax", @"show create proc syntax menu item")];
		[[tableSubMenu itemAtIndex:2] setHidden:YES]; // divider
		[[tableSubMenu itemAtIndex:3] setHidden:YES]; // copy columns
		[[tableSubMenu itemAtIndex:4] setHidden:YES]; // divider
		[[tableSubMenu itemAtIndex:5] setHidden:YES];
		[[tableSubMenu itemAtIndex:6] setHidden:YES];
		[[tableSubMenu itemAtIndex:7] setHidden:YES]; // divider
		[[tableSubMenu itemAtIndex:8] setHidden:YES];
		[[tableSubMenu itemAtIndex:9] setHidden:YES];
		
		[renameTableMenuItem setHidden:NO];
		[renameTableMenuItem setTitle:NSLocalizedString(@"Rename Procedure...", @"rename proc menu title")];
		[duplicateTableMenuItem setHidden:NO];
		[duplicateTableMenuItem setTitle:NSLocalizedString(@"Duplicate Procedure...", @"duplicate proc menu title")];
		[truncateTableButton setHidden:YES];
		[removeTableMenuItem setTitle:NSLocalizedString(@"Remove Procedure", @"remove proc menu title")];

		[renameTableContextMenuItem setHidden:NO];
		[renameTableContextMenuItem setTitle:NSLocalizedString(@"Rename Procedure...", @"rename proc menu title")];
		[duplicateTableContextMenuItem setHidden:NO];
		[duplicateTableContextMenuItem setTitle:NSLocalizedString(@"Duplicate Procedure...", @"duplicate proc menu title")];
		[truncateTableContextButton setHidden:YES];
		[removeTableContextMenuItem setTitle:NSLocalizedString(@"Remove Procedure", @"remove proc menu title")];

	}
	else if(selectedTableType == SP_TABLETYPE_FUNC) {
		[[tableSubMenu itemAtIndex:0] setTitle:NSLocalizedString(@"Copy Create Function Syntax", @"copy create func syntax menu item")];
		[[tableSubMenu itemAtIndex:1] setTitle:NSLocalizedString(@"Show Create Function Syntax", @"show create func syntax menu item")];
		[[tableSubMenu itemAtIndex:2] setHidden:YES]; // divider
		[[tableSubMenu itemAtIndex:3] setHidden:YES]; // copy columns
		[[tableSubMenu itemAtIndex:4] setHidden:YES]; // divider
		[[tableSubMenu itemAtIndex:5] setHidden:YES];
		[[tableSubMenu itemAtIndex:6] setHidden:YES];
		[[tableSubMenu itemAtIndex:7] setHidden:YES]; // divider
		[[tableSubMenu itemAtIndex:8] setHidden:YES];
		[[tableSubMenu itemAtIndex:9] setHidden:YES];	
		
		[renameTableMenuItem setHidden:NO];
		[renameTableMenuItem setTitle:NSLocalizedString(@"Rename Function...", @"rename func menu title")];
		[duplicateTableMenuItem setHidden:NO];
		[duplicateTableMenuItem setTitle:NSLocalizedString(@"Duplicate Function...", @"duplicate func menu title")];
		[truncateTableButton setHidden:YES];
		[removeTableMenuItem setTitle:NSLocalizedString(@"Remove Function", @"remove func menu title")];

		[renameTableContextMenuItem setHidden:NO];
		[renameTableContextMenuItem setTitle:NSLocalizedString(@"Rename Function...", @"rename func menu title")];
		[duplicateTableContextMenuItem setHidden:NO];
		[duplicateTableContextMenuItem setTitle:NSLocalizedString(@"Duplicate Function...", @"duplicate func menu title")];
		[truncateTableContextButton setHidden:YES];
		[removeTableContextMenuItem setTitle:NSLocalizedString(@"Remove Function", @"remove func menu title")];

	}

	// set window title
	[tableWindow setTitle:[tableDocumentInstance displaySPName]];

	// Update the "Show Create Syntax" window if it's already opened
	// according to the selected table/view/proc/func
	if([[tableDocumentInstance getCreateTableSyntaxWindow] isVisible])
		[tableDocumentInstance showCreateTableSyntax:self];

	// Add a history entry
	[spHistoryControllerInstance updateHistoryEntries];

	// Empty the loading pool and exit the thread
	[tableDocumentInstance endTask];
	[selectionChangePool drain];
}

#pragma mark -
#pragma mark Getter methods

/**
 * Returns the currently selected table or nil if no table or mulitple tables are selected
 */
- (NSString *)tableName
{
	return selectedTableName;
}

/*
 * Returns the currently selected table type, or -1 if no table or multiple tables are selected
 */
- (int) tableType
{
	return selectedTableType;
}

/**
 * Database tables accessor
 */
- (NSArray *)tables
{
	return tables;
}

/**
 * Database tables accessors for a given table type
 */
- (NSArray *)allTableAndViewNames
{
	NSMutableArray *returnArray = [NSMutableArray array];
	int i;
	int cnt = [[self tables] count];
	for(i=0; i<cnt; i++) {
		if([NSArrayObjectAtIndex([self tableTypes],i) intValue] == SP_TABLETYPE_TABLE || [NSArrayObjectAtIndex([self tableTypes],i) intValue] == SP_TABLETYPE_VIEW)
			[returnArray addObject:NSArrayObjectAtIndex([self tables], i)];
	}
	return returnArray;
}
- (NSArray *)allTableNames
{
	NSMutableArray *returnArray = [NSMutableArray array];
	int i;
	int cnt = [[self tables] count];
	for(i=0; i<cnt; i++) {
		if([NSArrayObjectAtIndex([self tableTypes],i) intValue] == SP_TABLETYPE_TABLE)
			[returnArray addObject:NSArrayObjectAtIndex([self tables], i)];
	}
	return returnArray;
}
- (NSArray *)allViewNames
{
	NSMutableArray *returnArray = [NSMutableArray array];
	int i;
	int cnt = [[self tables] count];
	for(i=0; i<cnt; i++) {
		if([NSArrayObjectAtIndex([self tableTypes],i) intValue] == SP_TABLETYPE_VIEW)
			[returnArray addObject:NSArrayObjectAtIndex([self tables], i)];
	}
	[returnArray sortUsingSelector:@selector(compare:)];
	return returnArray;
}
- (NSArray *)allProcedureNames
{
	NSMutableArray *returnArray = [NSMutableArray array];
	int i;
	int cnt = [[self tables] count];
	for(i=0; i<cnt; i++) {
		if([NSArrayObjectAtIndex([self tableTypes],i) intValue] == SP_TABLETYPE_PROC)
			[returnArray addObject:NSArrayObjectAtIndex([self tables], i)];
	}
	return returnArray;
}
- (NSArray *)allFunctionNames
{
	NSMutableArray *returnArray = [NSMutableArray array];
	int i;
	int cnt = [[self tables] count];
	for(i=0; i<cnt; i++) {
		if([NSArrayObjectAtIndex([self tableTypes],i) intValue] == SP_TABLETYPE_FUNC)
			[returnArray addObject:NSArrayObjectAtIndex([self tables], i)];
	}
	return returnArray;
}

/**
 * Returns an array of all available database names
 */
- (NSArray *)allDatabaseNames
{
	return [tableDocumentInstance allDatabaseNames];
}

/**
 * Database table types accessor
 */
- (NSArray *)tableTypes
{
	return tableTypes;
}

/**
 * Returns YES if table source has already been loaded
 */
- (BOOL)structureLoaded
{
	return structureLoaded;
}

/**
 * Returns YES if table content has already been loaded
 */
- (BOOL)contentLoaded
{
	return contentLoaded;
}

/**
 * Returns YES if table status has already been loaded
 */
- (BOOL)statusLoaded
{
	return statusLoaded;
}

#pragma mark -
#pragma mark Setter methods

/**
 * Mark the content table for refresh when it's next switched to
 */
- (void)setContentRequiresReload:(BOOL)reload
{
	contentLoaded = !reload;
}

/**
 * Mark the exteded table info for refresh when it's next switched to
 */
- (void)setStatusRequiresReload:(BOOL)reload
{
	statusLoaded = !reload;
}

/**
 * Select a table or view using the provided name; returns YES if the
 * supplied name could be selected, or NO if not.
 */
- (BOOL)selectTableOrViewWithName:(NSString *)theName
{
	int i, tableType;
	int itemIndex = NSNotFound;
	int caseInsensitiveItemIndex = NSNotFound;

	// Loop through the unfiltered tables/views to find the desired item
	for (i = 0; i < [tables count]; i++) {
		tableType = [[tableTypes objectAtIndex:i] intValue];
		if (tableType != SP_TABLETYPE_TABLE && tableType != SP_TABLETYPE_VIEW) continue;
		if ([[tables objectAtIndex:i] isEqualToString:theName]) {
			itemIndex = i;
			break;
		}
		if ([[tables objectAtIndex:i] compare:theName options:NSCaseInsensitiveSearch|NSLiteralSearch] == NSOrderedSame)
			caseInsensitiveItemIndex = i;
	}
	
	// If no case-sensitive match was found, use a case-insensitive match if available
	if (itemIndex == NSNotFound && caseInsensitiveItemIndex != NSNotFound)
		itemIndex = caseInsensitiveItemIndex;

	// If no match found, return failure
	if (itemIndex == NSNotFound) return NO;

	if (!isTableListFiltered) {
		[tablesListView selectRowIndexes:[NSIndexSet indexSetWithIndex:itemIndex] byExtendingSelection:NO];
	} else {
		int filteredIndex = [filteredTables indexOfObject:[tables objectAtIndex:itemIndex]];
		if (filteredIndex != NSNotFound) {
			[tablesListView selectRowIndexes:[NSIndexSet indexSetWithIndex:filteredIndex] byExtendingSelection:NO];
		} else {
			[tablesListView deselectAll:nil];
			if (selectedTableName) [selectedTableName release];
			selectedTableName = [[NSString alloc] initWithString:[tables objectAtIndex:itemIndex]];
			selectedTableType = [[tableTypes objectAtIndex:itemIndex] intValue];
			[self updateFilter:self];
			[self updateSelectionWithTaskString:[NSString stringWithFormat:NSLocalizedString(@"Loading %@...", @"Loading table task string"), theName]];
		}
	}
	return YES;
}

#pragma mark -
#pragma mark Datasource methods

/**
 * Returns the number of tables in the current database.
 */
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [filteredTables count];
}

/**
 * Returns the table names to be displayed in the tables list table view.
 */
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{

	// During imports the table view sometimes appears to request items beyond the end of the array.
	// Using a hinted noteNumberOfRowsChanged after dropping tables fixes this but then seems to stick
	// even after override, so check here for the time being and display empty rows during import.
	if (rowIndex >= [filteredTables count]) return @"";

	return [filteredTables objectAtIndex:rowIndex];
}

/**
 * Prevent table renames while tasks are active
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return ![tableDocumentInstance isWorking];
}

/**
 * Renames a table (in tables-array and mysql-db).
 */
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if ([selectedTableName isEqualToString:anObject]) {
		// No changes in table name
	} 
	else if ([anObject isEqualToString:@""]) {
		// Table has no name
		alertSheetOpened = YES;
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self,
						  @selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addRow", NSLocalizedString(@"Empty names are not allowed.", @"message of panel when no name is given for an item"));
	} 
	else {
		if(selectedTableType == SP_TABLETYPE_VIEW || selectedTableType == SP_TABLETYPE_TABLE)
		{
			[mySQLConnection queryString:[NSString stringWithFormat:@"RENAME TABLE %@ TO %@", [selectedTableName backtickQuotedString], [anObject backtickQuotedString]]];
		} 
		else
		{
			// procedures and functions can only be renamed if one creates the new one and delete the old one
			// get the create syntax
			NSString *tableType;
			switch (selectedTableType){
				case SP_TABLETYPE_PROC:
				tableType = @"PROCEDURE";
				break;
				case SP_TABLETYPE_FUNC:
				tableType = @"FUNCTION";
				break;
			}
			MCPResult *theResult;
			if (selectedTableType == SP_TABLETYPE_PROC)
				theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE PROCEDURE %@", [selectedTableName backtickQuotedString]]];
			else if(selectedTableType == SP_TABLETYPE_FUNC)
				theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE FUNCTION %@", [selectedTableName backtickQuotedString]]];
			else
				return;

			// Check for errors, only displaying if the connection hasn't been terminated
			if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
				if ([mySQLConnection isConnected]) {
					NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), 
									  NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
									  [NSString stringWithFormat:NSLocalizedString(@"An error occured while retrieving create syntax for '%@'.\n\nMySQL said: %@", @"message of panel when create syntax cannot be retrieved"), selectedTableName, [mySQLConnection getLastErrorMessage]]);

				}
				return;
			}

			id tableSyntax = [[theResult fetchRowAsArray] objectAtIndex:2];

			if ([tableSyntax isKindOfClass:[NSData class]])
				tableSyntax = [[[NSString alloc] initWithData:tableSyntax encoding:[mySQLConnection encoding]] autorelease];

			// replace the old name by the new one and drop the old one
			[mySQLConnection queryString:[tableSyntax stringByReplacingOccurrencesOfRegex:[NSString stringWithFormat:@"(?<=%@ )(`[^`]+?`)", tableType] withString:[anObject backtickQuotedString]]];
			if ([[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
				if ([mySQLConnection isConnected]) {
					[mySQLConnection queryString: [NSString stringWithFormat: @"DROP %@ %@", tableType, [[tables objectAtIndex:rowIndex] backtickQuotedString]]];
				}
			}
		}
		
		if ([[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
			// Renamed with success
			if (isTableListFiltered) {
				int unfilteredIndex = [tables indexOfObject:[filteredTables objectAtIndex:rowIndex]];
				[tables replaceObjectAtIndex:unfilteredIndex withObject:anObject];
			}
			[filteredTables replaceObjectAtIndex:rowIndex withObject:anObject];
			if (selectedTableName) [selectedTableName release];
			selectedTableName = [[NSString alloc] initWithString:anObject];
			
			if(selectedTableType == SP_TABLETYPE_FUNC || selectedTableType == SP_TABLETYPE_PROC)
				return;
			NSInteger selectedIndex = [tabView indexOfTabViewItem:[tabView selectedTabViewItem]];
			
			if (selectedIndex == 0) {
				[tableSourceInstance loadTable:anObject];
				structureLoaded = YES;
				contentLoaded = NO;
				statusLoaded = NO;
			} 
			else if (selectedIndex == 1) {
				[tableContentInstance loadTable:anObject];
				structureLoaded = NO;
				contentLoaded = YES;
				statusLoaded = NO;
			} 
			else if (selectedIndex == 3) {
				[extendedTableInfoInstance loadTable:anObject];
				structureLoaded = NO;
				contentLoaded = NO;
				statusLoaded = YES;
			} 
			else {
				statusLoaded = NO;
				structureLoaded = NO;
				contentLoaded = NO;
			}
			
			// Set window title
			[tableWindow setTitle:[tableDocumentInstance displaySPName]];

		} 
		else {
			// Error while renaming
			alertSheetOpened = YES;
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self,
							  @selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addRow",
							  [NSString stringWithFormat:NSLocalizedString(@"Couldn't rename '%@'.\nMySQL said: %@", @"message of panel when an item cannot be renamed"),
							  anObject, [mySQLConnection getLastErrorMessage]]);
		}
	}
}

#pragma mark -
#pragma mark TableView delegate methods

/**
 * Traps enter and esc and edit/cancel without entering next row
 */
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(insertNewline:)] ) {
		//save current line
		[[control window] makeFirstResponder:control];
		return TRUE;
		
	} else if ( [[control window] methodForSelector:command] == [[control window] methodForSelector:@selector(_cancelKey:)] ||
		[textView methodForSelector:command] == [textView methodForSelector:@selector(complete:)] ) {
		
		//abort editing
		[control abortEditing];
		
		return TRUE;
	} else{
		return FALSE;
	}
}

/**
 * Table view delegate method
 */
- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView
{

	// Don't allow selection changes while performing a task.
	if (!tableListIsSelectable) return NO;

	// End editing (otherwise problems when user hits reload button)
	[tableWindow endEditingFor:nil];
	
	if ( alertSheetOpened ) {
		return NO;
	}

	// We have to be sure that TableSource and TableContent have finished editing
	if ( ![tableSourceInstance saveRowOnDeselect] || ![tableContentInstance saveRowOnDeselect] ) {
		return NO;
	} else {
		return YES;
	}
}

/**
 * Loads a table in content or source view (if tab selected)
 */
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{	

	// Reset selectability after change if necessary
	if ([tableDocumentInstance isWorking]) tableListIsSelectable = NO;

	// Perform no action if the selected table hasn't actually changed - reselection etc
	if ([tablesListView numberOfSelectedRows] == 1
		&& [[filteredTables objectAtIndex:[tablesListView selectedRow]] length]
		&& [selectedTableName isEqualToString:[filteredTables objectAtIndex:[tablesListView selectedRow]]]
		&& selectedTableType == [[filteredTableTypes objectAtIndex:[tablesListView selectedRow]] intValue])
	{
		return;
	}

	// Save existing scroll position and details
	[spHistoryControllerInstance updateHistoryEntries];

	NSString *tableName = @"data";
	if ([tablesListView numberOfSelectedRows] == 1 && [[filteredTables objectAtIndex:[tablesListView selectedRow]] length])
		tableName = [filteredTables objectAtIndex:[tablesListView selectedRow]];
	[self updateSelectionWithTaskString:[NSString stringWithFormat:NSLocalizedString(@"Loading %@...", @"Loading table task string"), tableName]];
}

/**
 * Table view delegate method
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(int)rowIndex
{

	// Disallow selection while the document is working on a task
	if ([tableDocumentInstance isWorking]) return NO;

	//return (rowIndex != 0);
	if( [filteredTableTypes count] == 0 )
		return (rowIndex != 0 );
	return ([[filteredTableTypes objectAtIndex:rowIndex] intValue] != SP_TABLETYPE_NONE );
}

/**
 * Table view delegate method
 */
- (BOOL)tableView:(NSTableView *)aTableView isGroupRow:(int)rowIndex
{
	// For empty tables - title still present - or while lists are being altered
	if (rowIndex >= [filteredTableTypes count]) return (rowIndex == 0 );

	return ([[filteredTableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_NONE );
}

/**
 * Table view delegate method
 */
- (void)tableView:(NSTableView *)aTableView  willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if (rowIndex > 0 && rowIndex < [filteredTableTypes count]
		&& [[aTableColumn identifier] isEqualToString:@"tables"]) {
		if ([[filteredTableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_VIEW) {
			[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"table-view-small"]];
		} else if ([[filteredTableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_TABLE) { 
			[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"table-small"]];
		} else if ([[filteredTableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_PROC) { 
			[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"proc-small"]];
		} else if ([[filteredTableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_FUNC) { 
			[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"func-small"]];
		}
	
		if ([[filteredTableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_NONE) {
			[(ImageAndTextCell*)aCell setImage:nil];
			[(ImageAndTextCell*)aCell setIndentationLevel:0];
		} else {
			[(ImageAndTextCell*)aCell setIndentationLevel:1];
			[(ImageAndTextCell*)aCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];			
		}
	} else {
		[(ImageAndTextCell*)aCell setImage:nil];
		[(ImageAndTextCell*)aCell setIndentationLevel:0];
	}
}

/**
 * Table view delegate method
 */
- (float)tableView:(NSTableView *)tableView heightOfRow:(int)row
{
	return (row == 0) ? 25 : 17;
}

#pragma mark -
#pragma mark TabView delegate methods

/**
 * Loads structure or source if tab selected the first time,
 * using a threaded load if currently on the main thread.
 */
- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	[tableDocumentInstance startTaskWithDescription:[NSString stringWithFormat:NSLocalizedString(@"Loading %@...", @"Loading table task string"), selectedTableName]];
	if ([NSThread isMainThread]) {
		[NSThread detachNewThreadSelector:@selector(loadTabTask:) toTarget:self withObject:tabViewItem];
	} else {
		[self loadTabTask:tabViewItem];
	}
}
- (void)loadTabTask:(NSTabViewItem *)tabViewItem
{
	NSAutoreleasePool *tabLoadPool = [[NSAutoreleasePool alloc] init];

	if ( [tablesListView numberOfSelectedRows] == 1  && 
		([self tableType] == SP_TABLETYPE_TABLE || [self tableType] == SP_TABLETYPE_VIEW) ) {
		
		if ( ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 0) && !structureLoaded ) {
			[tableSourceInstance loadTable:selectedTableName];
			structureLoaded = YES;
		}
		
		if ( ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 1) && !contentLoaded ) {
			[tableContentInstance loadTable:selectedTableName];
			contentLoaded = YES;
		}
		
		if ( ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 3) && !statusLoaded ) {
			[extendedTableInfoInstance performSelectorOnMainThread:@selector(loadTable:) withObject:selectedTableName waitUntilDone:YES];
			statusLoaded = YES;
		}
	}
	else {
		[tableSourceInstance loadTable:nil];
		[tableContentInstance loadTable:nil];
	}

	[tableDocumentInstance endTask];
	[tabLoadPool drain];
}

/**
 * Menu item interface validation
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// popup button below table list
	if ([menuItem action] == @selector(copyTable:)) {
		return (([tablesListView numberOfSelectedRows] == 1) && [[self tableName] length] && [tablesListView numberOfSelectedRows] > 0);
	}
	
	if ([menuItem action] == @selector(removeTable:) || [menuItem action] == @selector(truncateTable:)) {
		return ([tablesListView numberOfSelectedRows] > 0);
	}

	if ([menuItem action] == @selector(renameTable:)) {
		return (([tablesListView numberOfSelectedRows] == 1) && [[self tableName] length]);
	}
	
	return [super validateMenuItem:menuItem];
}		

#pragma mark -
#pragma mark Table list filter interaction

/**
 * Show the filter box if it's currently hidden.  Use a delay to ensure
 * action is executed on first load.
 */
- (void) showFilter
{
	if ([tableListFilterSplitView collapsibleSubviewIsCollapsed])
		[tableListFilterSplitView performSelectorOnMainThread:@selector(toggleCollapse:) withObject:nil waitUntilDone:NO];
}

/**
 * Hide the filter box if it's currently shown.  Use a delay to ensure
 * action is executed on first load.
 */
- (void) hideFilter
{
	if (![tableListFilterSplitView collapsibleSubviewIsCollapsed])
		[tableListFilterSplitView performSelectorOnMainThread:@selector(toggleCollapse:) withObject:nil waitUntilDone:NO];
}

/**
 * Clear the current content of the filter box
 */
- (void) clearFilter
{
	[listFilterField setStringValue:@""];
}

/**
 * Update the filter search.
 */
- (IBAction) updateFilter:(id)sender
{

	// Don't try and maintain selections of multiple rows through filtering
	if ([tablesListView numberOfSelectedRows] > 1) {
		[tablesListView deselectAll:self];
		if (selectedTableName) [selectedTableName release], selectedTableName = nil;
	}

	if ([[listFilterField stringValue] length]) {
		if (isTableListFiltered) {
			[filteredTables release];
			[filteredTableTypes release];
		}
		filteredTables = [[NSMutableArray alloc] init];
		filteredTableTypes = [[NSMutableArray alloc] init];
		
		int i, lastTableType = NSNotFound, tableType;
		NSRange substringRange;
		for (i = 0; i < [tables count]; i++) {
			tableType = [[tableTypes objectAtIndex:i] intValue];
			if (tableType == SP_TABLETYPE_NONE) continue;
			substringRange = [[tables objectAtIndex:i] rangeOfString:[listFilterField stringValue] options:NSCaseInsensitiveSearch];
			if (substringRange.location == NSNotFound) continue;
		
			// Add a title if necessary
			if ((tableType == SP_TABLETYPE_TABLE || tableType == SP_TABLETYPE_VIEW) && lastTableType == NSNotFound)
			{
				if (tableListContainsViews) {
					[filteredTables addObject:NSLocalizedString(@"TABLES & VIEWS",@"header for table & views list")];
				} else {
					[filteredTables addObject:NSLocalizedString(@"TABLES",@"header for table list")];
				}
				[filteredTableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_NONE]];
			} else if ((tableType == SP_TABLETYPE_PROC || tableType == SP_TABLETYPE_FUNC)
						&& (lastTableType == NSNotFound || lastTableType == SP_TABLETYPE_TABLE || lastTableType == SP_TABLETYPE_VIEW))
			{
				[filteredTables addObject:NSLocalizedString(@"PROCS & FUNCS",@"header for procs & funcs list")];
				[filteredTableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_NONE]];
			}
			lastTableType = tableType;

			// Add the item
			[filteredTables addObject:[tables objectAtIndex:i]];
			[filteredTableTypes addObject:[tableTypes objectAtIndex:i]];
		}
		
		// Add a "no matches" title if nothing matches the current filter settings
		if (![filteredTables count]) {
			[filteredTables addObject:NSLocalizedString(@"NO MATCHES",@"header for no matches in filtered list")];
			[filteredTableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_NONE]];		
		}

		// If the currently selected table isn't present in the filter list, add it as a special entry
		if (selectedTableName && [filteredTables indexOfObject:selectedTableName] == NSNotFound) {
			[filteredTables addObject:NSLocalizedString(@"CURRENT SELECTION",@"header for current selection in filtered list")];
			[filteredTableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_NONE]];
			[filteredTables addObject:selectedTableName];
			[filteredTableTypes addObject:[NSNumber numberWithInt:selectedTableType]];
		}
		
		isTableListFiltered = YES;
	} else if (isTableListFiltered) {
		isTableListFiltered = NO;
		[filteredTables release];
		filteredTables = tables;
		[filteredTableTypes release];
		filteredTableTypes = tableTypes;
	}

	// Reselect correct row and reload the table view display
	if ([tablesListView numberOfRows] < [filteredTables count]) [tablesListView noteNumberOfRowsChanged];
	if (selectedTableName) [tablesListView selectRowIndexes:[NSIndexSet indexSetWithIndex:[filteredTables indexOfObject:selectedTableName]] byExtendingSelection:NO];
	[tablesListView reloadData];
}

/**
 * Select the supplied row index; added for convenience to allow
 * use with performSelector:withObject:afterDelay: for re-selection.
 */
- (void) selectTableAtIndex:(NSNumber *)row
{
	int rowIndex = [row intValue];
	if (rowIndex == NSNotFound || rowIndex > [filteredTables count] || [[filteredTableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_NONE)
		return;

	[tablesListView selectRowIndexes:[NSIndexSet indexSetWithIndex:rowIndex] byExtendingSelection:NO];
}

#pragma mark -
#pragma mark Task interaction

/**
 * Disable all table list interactive elements during an ongoing task.
 */
- (void) startDocumentTaskForTab:(NSNotification *)aNotification
{
	tableListIsSelectable = NO;
	[toolbarAddButton setEnabled:NO];
	[toolbarActionsButton setEnabled:NO];
	[toolbarReloadButton setEnabled:NO];
}

/**
 * Enable all table list interactive elements after an ongoing task.
 */
- (void) endDocumentTaskForTab:(NSNotification *)aNotification
{
	tableListIsSelectable = YES;
	[toolbarAddButton setEnabled:YES];
	[toolbarActionsButton setEnabled:YES];
	[toolbarReloadButton setEnabled:YES];
}

/**
 * Set the table list to selectable or not during the task process.
 */
- (void) setTableListSelectability:(BOOL)isSelectable
{
	tableListIsSelectable = isSelectable;
}

#pragma mark -
#pragma mark SplitView Delegate Methods

- (NSRect)splitView:(NSSplitView *)splitView effectiveRect:(NSRect)proposedEffectiveRect forDrawnRect:(NSRect)drawnRect ofDividerAtIndex:(NSInteger)dividerIndex
{
	return (splitView == tableListSplitView ? NSZeroRect : proposedEffectiveRect);
}


#pragma mark -
#pragma mark Other

/**
 * Standard init method. Performs various ivar initialisations. 
 */
- (id)init
{
	if ((self = [super init])) {
		tables = [[NSMutableArray alloc] init];
		filteredTables = tables;
		tableTypes = [[NSMutableArray alloc] init];
		filteredTableTypes = tableTypes;
		structureLoaded = NO;
		contentLoaded = NO;
		statusLoaded = NO;
		isTableListFiltered = NO;
		tableListIsSelectable = YES;
		tableListContainsViews = NO;
		selectedTableType = SP_TABLETYPE_NONE;
		selectedTableName = nil;
		[tables addObject:NSLocalizedString(@"TABLES",@"header for table list")];
	}
	
	return self;
}

/**
 * Standard awakeFromNib method for interface loading.
 */
- (void)awakeFromNib
{

	// Collapse the table information pane if preference to do so is set
	if ([[[NSUserDefaults standardUserDefaults] objectForKey:SPTableInformationPanelCollapsed] boolValue]
		&& [tableListSplitView collapsibleSubview]) {
		[tableInfoCollapseButton setNextState];
		[tableInfoCollapseButton setToolTip:NSLocalizedString(@"Show Table Information",@"Show Table Information")];
		[tableListSplitView setValue:[NSNumber numberWithFloat:[tableListSplitView collapsibleSubview].frame.size.height] forKey:@"uncollapsedSize"];
		[[tableListSplitView collapsibleSubview] setFrameSize:NSMakeSize([tableListSplitView collapsibleSubview].frame.size.width, 0)];
		[tableListSplitView setCollapsibleSubviewCollapsed:YES];
	} else {
		[tableInfoCollapseButton setToolTip:NSLocalizedString(@"Hide Table Information",@"Hide Table Information")];
	}

	// Start the table filter list collapsed
	if ([tableListFilterSplitView collapsibleSubview]) {
		[tableListFilterSplitView setValue:[NSNumber numberWithFloat:[tableListFilterSplitView collapsibleSubview].frame.size.height] forKey:@"uncollapsedSize"];
		[[tableListFilterSplitView collapsibleSubview] setFrameSize:NSMakeSize([tableListFilterSplitView collapsibleSubview].frame.size.width, 0)];
		[tableListFilterSplitView setCollapsibleSubviewCollapsed:YES];
	}

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

/**
 * Standard dealloc method.
 */
- (void)dealloc
{	
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[tables release];
	[tableTypes release];
	if (isTableListFiltered && filteredTables) [filteredTables release];
	if (isTableListFiltered && filteredTableTypes) [filteredTableTypes release];
	if (selectedTableName) [selectedTableName release];
	
	[super dealloc];
}

@end

@implementation TablesList (PrivateAPI)

/**
 * Removes the selected object (table, view, procedure, function, etc.) from the database and tableView.
 */
- (void)removeTable
{
	NSIndexSet *indexes = [tablesListView selectedRowIndexes];
	
	// get last index
	unsigned currentIndex = [indexes lastIndex];
	
	while (currentIndex != NSNotFound)
	{
		if([[filteredTableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_VIEW) {
			[mySQLConnection queryString: [NSString stringWithFormat: @"DROP VIEW %@",
										   [[filteredTables objectAtIndex:currentIndex] backtickQuotedString]
										   ]];
		} else if([[filteredTableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_TABLE) {
			[mySQLConnection queryString: [NSString stringWithFormat: @"DROP TABLE %@",
										   [[filteredTables objectAtIndex:currentIndex] backtickQuotedString]
										   ]];			
		} else if([[filteredTableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_PROC) {
			[mySQLConnection queryString: [NSString stringWithFormat: @"DROP PROCEDURE %@",
										   [[filteredTables objectAtIndex:currentIndex] backtickQuotedString]
										   ]];			
		} else if([[filteredTableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_FUNC) {
			[mySQLConnection queryString: [NSString stringWithFormat: @"DROP FUNCTION %@",
										   [[filteredTables objectAtIndex:currentIndex] backtickQuotedString]
										   ]];			
		} 

		// If no error is recorded, the table was successfully dropped - remove it from the list
		if ([[mySQLConnection getLastErrorMessage] isEqualTo:@""]) {
			//dropped table with success
			if (isTableListFiltered) {
				int unfilteredIndex = [tables indexOfObject:[filteredTables objectAtIndex:currentIndex]];
				[tables removeObjectAtIndex:unfilteredIndex];
				[tableTypes removeObjectAtIndex:unfilteredIndex];
			}
			[filteredTables removeObjectAtIndex:currentIndex];
			[filteredTableTypes removeObjectAtIndex:currentIndex];

			// Get next index (beginning from the end)
			currentIndex = [indexes indexLessThanIndex:currentIndex];

		// Otherwise, display an alert - and if there's tables left, ask whether to proceed
		} else {

			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			if ([indexes indexLessThanIndex:currentIndex] == NSNotFound) {
				[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK button")];
			} else {
				[alert addButtonWithTitle:NSLocalizedString(@"Continue", @"continue button")];
				[alert addButtonWithTitle:NSLocalizedString(@"Stop", @"stop button")];
			}
			[alert setMessageText:NSLocalizedString(@"Error", @"error")];
			[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Couldn't remove '%@'.\nMySQL said: %@", @"message of panel when an item cannot be removed"), [tables objectAtIndex:currentIndex], [mySQLConnection getLastErrorMessage]]];
			[alert setAlertStyle:NSWarningAlertStyle];
			if ([indexes indexLessThanIndex:currentIndex] == NSNotFound) {
				[alert beginSheetModalForWindow:tableWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
				currentIndex = NSNotFound;
			} else {
				int choice = [alert runModal];
				if (choice == NSAlertFirstButtonReturn) {
					currentIndex = [indexes indexLessThanIndex:currentIndex];
				} else {
					currentIndex = NSNotFound;
				}
			}
		}
	}
	
	// Remove the isolated "current selection" item for filtered lists if appropriate
	if (isTableListFiltered && [filteredTables count] > 1
		&& [[filteredTableTypes objectAtIndex:[filteredTableTypes count]-1] intValue] == SP_TABLETYPE_NONE
		&& [[filteredTables objectAtIndex:[filteredTables count]-1] isEqualToString:NSLocalizedString(@"CURRENT SELECTION",@"header for current selection in filtered list")])
	{
		[filteredTables removeLastObject];
		[filteredTableTypes removeLastObject];
	}
	
	[tablesListView reloadData];
	
	// set window title
	[tableWindow setTitle:[tableDocumentInstance displaySPName]];

	[tablesListView deselectAll:self];
}

/**
 * Trucates the selected table(s).
 */
- (void)truncateTable
{
	NSIndexSet *indexes = [tablesListView selectedRowIndexes];
	
	// Get last index
	unsigned currentIndex = [indexes lastIndex];
	
	while (currentIndex != NSNotFound)
	{
		[mySQLConnection queryString:[NSString stringWithFormat: @"TRUNCATE TABLE %@", [[filteredTables objectAtIndex:currentIndex] backtickQuotedString]]]; 
		
		// Couldn't truncate table
		if (![[mySQLConnection getLastErrorMessage] isEqualTo:@""]) {
			NSBeginAlertSheet(NSLocalizedString(@"Error truncating table", @"error truncating table message"), 
							  NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
							  [NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to truncate the table '%@'.\n\nMySQL said: %@", @"error truncating table informative message"), [filteredTables objectAtIndex:currentIndex], [mySQLConnection getLastErrorMessage]]);
		}
		
		// Get next index (beginning from the end)
		currentIndex = [indexes indexLessThanIndex:currentIndex];
	}
	
	// Reload the table's content view to show that it has been truncated 
	[tableContentInstance reloadTable:self];
}

/**
 * Adds a new table table to the database.
 */
- (void)addTable
{
	NSString *tableName = [tableNameField stringValue];
	NSString *createStatement = [NSString stringWithFormat:@"CREATE TABLE %@ (id INT)", [tableName backtickQuotedString]];
	
	// If there is an encoding selected other than the default we must specify it in CREATE TABLE statement
	if ([tableEncodingButton indexOfSelectedItem] > 0) {
		createStatement = [NSString stringWithFormat:@"%@ DEFAULT CHARACTER SET %@", createStatement, [[tableDocumentInstance mysqlEncodingFromDisplayEncoding:[tableEncodingButton title]] backtickQuotedString]];
	}
	
	// If there is a type selected other than the default we must specify it in CREATE TABLE statement
	if ([tableTypeButton indexOfSelectedItem] > 0) {
		createStatement = [NSString stringWithFormat:@"%@ ENGINE = %@", createStatement, [[tableTypeButton title] backtickQuotedString]];
	}
	
	// Create the table
	[mySQLConnection queryString:createStatement];
	
	if ([[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		
		// Table creation was successful - insert the new item into the tables list and select it.
		int addItemAtIndex = NSNotFound;
		for (int i = 0; i < [tables count]; i++) {
			int tableType = [[tableTypes objectAtIndex:i] intValue];
			if (tableType == SP_TABLETYPE_NONE) continue;
			if (tableType == SP_TABLETYPE_PROC || tableType == SP_TABLETYPE_FUNC) {
				addItemAtIndex = i - 1;
				break;
			}
			if ([tableName localizedCompare:[tables objectAtIndex:i]] == NSOrderedAscending) {
				addItemAtIndex = i;
				break;
			}
		}
		if (addItemAtIndex == NSNotFound) {
			[tables addObject:tableName];
			[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_TABLE]];
		} else {
			[tables insertObject:tableName atIndex:addItemAtIndex];
			[tableTypes insertObject:[NSNumber numberWithInt:SP_TABLETYPE_TABLE] atIndex:addItemAtIndex];		
		}
		
		// Set the selected table name and type, and then use updateFilter and updateSelection to update the filter list and selection.
		if (selectedTableName) [selectedTableName release];
		selectedTableName = [[NSString alloc] initWithString:tableName];
		selectedTableType = SP_TABLETYPE_TABLE;
		[self updateFilter:self];
		[tablesListView scrollRowToVisible:[tablesListView selectedRow]];
		[self updateSelectionWithTaskString:[NSString stringWithFormat:NSLocalizedString(@"Loading %@...", @"Loading table task string"), selectedTableName]];
	} 
	else {
		// Error while creating new table
		alertSheetOpened = YES;
		
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self,
						  @selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addRow",
						  [NSString stringWithFormat:NSLocalizedString(@"Couldn't add table %@.\nMySQL said: %@", @"message of panel when table cannot be created with the given name"),
						   tableName, [mySQLConnection getLastErrorMessage]]);
		
		[tablesListView reloadData];
	}
	
	// Clear table name
	[tableNameField setStringValue:@""];
}

/**
 * Copies the currently selected object (table, view, procedure, function, etc.).
 */
- (void)copyTable
{
	NSString *tableType;
	
	if ([[copyTableNameField stringValue] isEqualToString:@""]) {
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil, NSLocalizedString(@"Table must have a name.", @"message of panel when no name is given for table"));
		return;
	}
	
	BOOL copyTableContent = ([copyTableContentSwitch state] == NSOnState);
	
	int tblType = [[filteredTableTypes objectAtIndex:[tablesListView selectedRow]] intValue];
	
	switch (tblType){
		case SP_TABLETYPE_TABLE:
			tableType = NSLocalizedString(@"table",@"table");
			[copyTableContentSwitch setEnabled:YES];
			break;
		case SP_TABLETYPE_VIEW:
			tableType = NSLocalizedString(@"view",@"view");
			[copyTableContentSwitch setEnabled:NO];
			break;
		case SP_TABLETYPE_PROC:
			tableType = NSLocalizedString(@"procedure",@"procedure");
			[copyTableContentSwitch setEnabled:NO];
			break;
		case SP_TABLETYPE_FUNC:
			tableType = NSLocalizedString(@"function",@"function");
			[copyTableContentSwitch setEnabled:NO];
			break;
	}
	
	// Get table/view structure
	MCPResult *queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE %@ %@",
												[tableType uppercaseString],
												[[filteredTables objectAtIndex:[tablesListView selectedRow]] backtickQuotedString]
												]];
	
	if ( ![queryResult numOfRows] ) {
		//error while getting table structure
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
						  [NSString stringWithFormat:NSLocalizedString(@"Couldn't get create syntax.\nMySQL said: %@", @"message of panel when table information cannot be retrieved"), [mySQLConnection getLastErrorMessage]]);
		
    } else {
		//insert new table name in create syntax and create new table
		NSScanner *scanner = [NSScanner alloc];
		NSString *scanString;
		
		if(tblType == SP_TABLETYPE_VIEW){
			[scanner initWithString:[[queryResult fetchRowAsDictionary] objectForKey:@"Create View"]];
			[scanner scanUpToString:@"AS" intoString:nil];
			[scanner scanUpToString:@"" intoString:&scanString];
			[mySQLConnection queryString:[NSString stringWithFormat:@"CREATE VIEW %@ %@", [[copyTableNameField stringValue] backtickQuotedString], scanString]];
		} 
		else if(tblType == SP_TABLETYPE_TABLE){
			[scanner initWithString:[[queryResult fetchRowAsDictionary] objectForKey:@"Create Table"]];
			[scanner scanUpToString:@"(" intoString:nil];
			[scanner scanUpToString:@"" intoString:&scanString];
			
			// If there are any InnoDB referencial constraints we need to strip out the names as they must be unique. 
			// MySQL will generate the new names based on the new table name.
			scanString = [scanString stringByReplacingOccurrencesOfRegex:[NSString stringWithFormat:@"CONSTRAINT `[^`]+` "] withString:@""];
			
			// If we're not copying the tables content as well then we need to strip out any AUTO_INCREMENT presets.
			if (!copyTableContent) {
				scanString = [scanString stringByReplacingOccurrencesOfRegex:[NSString stringWithFormat:@"AUTO_INCREMENT=[0-9]+ "] withString:@""];
			}
			
			[mySQLConnection queryString:[NSString stringWithFormat:@"CREATE TABLE %@ %@", [[copyTableNameField stringValue] backtickQuotedString], scanString]];
		}
		else if(tblType == SP_TABLETYPE_FUNC || tblType == SP_TABLETYPE_PROC)
		{
			// get the create syntax
			MCPResult *theResult;
			if(selectedTableType == SP_TABLETYPE_PROC)
				theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE PROCEDURE %@", [selectedTableName backtickQuotedString]]];
			else if([self tableType] == SP_TABLETYPE_FUNC)
				theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE FUNCTION %@", [selectedTableName backtickQuotedString]]];
			else
				return;
			
			// Check for errors, only displaying if the connection hasn't been terminated
			if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
				if ([mySQLConnection isConnected]) {
					NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
									  [NSString stringWithFormat:NSLocalizedString(@"An error occured while retrieving the create syntax for '%@'.\nMySQL said: %@", @"message of panel when create syntax cannot be retrieved"), selectedTableName, [mySQLConnection getLastErrorMessage]]);
				}
				return;
			}
			
			id tableSyntax = [[theResult fetchRowAsArray] objectAtIndex:2];
			
			if ([tableSyntax isKindOfClass:[NSData class]])
				tableSyntax = [[NSString alloc] initWithData:tableSyntax encoding:[mySQLConnection encoding]];
			
			// replace the old name by the new one and drop the old one
			[mySQLConnection queryString:[tableSyntax stringByReplacingOccurrencesOfRegex:[NSString stringWithFormat:@"(?<=%@ )(`[^`]+?`)", [tableType uppercaseString]] withString:[[copyTableNameField stringValue] backtickQuotedString]]];
			
			[tableSyntax release];
			
			if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
				NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
								  [NSString stringWithFormat:NSLocalizedString(@"Couldn't duplicate '%@'.\nMySQL said: %@", @"message of panel when an item cannot be renamed"), [copyTableNameField stringValue], [mySQLConnection getLastErrorMessage]]);
			}
			
		}
		[scanner release];
		
        if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
			//error while creating new table
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
							  [NSString stringWithFormat:NSLocalizedString(@"Couldn't create '%@'.\nMySQL said: %@", @"message of panel when table cannot be created"), [copyTableNameField stringValue], [mySQLConnection getLastErrorMessage]]);
        } else {
			
            if (copyTableContent) {
				//copy table content
                [mySQLConnection queryString:[NSString stringWithFormat:
											  @"INSERT INTO %@ SELECT * FROM %@",
											  [[copyTableNameField stringValue] backtickQuotedString],
											  [selectedTableName backtickQuotedString]
											  ]];
				
                if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
                    NSBeginAlertSheet(
									  NSLocalizedString(@"Warning", @"warning"),
									  NSLocalizedString(@"OK", @"OK button"),
									  nil,
									  nil,
									  tableWindow,
									  self,
									  nil,
									  nil,
									  nil,
									  NSLocalizedString(@"There have been errors while copying table content. Please control the new table.", @"message of panel when table content cannot be copied")
									  );
                }
            }
			
			// Insert the new item into the tables list and select it.
			int addItemAtIndex = NSNotFound;
			for (int i = 0; i < [tables count]; i++) {
				int tableType = [[tableTypes objectAtIndex:i] intValue];
				if (tableType == SP_TABLETYPE_NONE) continue;
				if ((tableType == SP_TABLETYPE_VIEW || tableType == SP_TABLETYPE_TABLE)
					&& (tblType == SP_TABLETYPE_PROC || tblType == SP_TABLETYPE_FUNC)) {
					continue;
				}
				if ((tableType == SP_TABLETYPE_PROC || tableType == SP_TABLETYPE_FUNC)
					&& (tblType == SP_TABLETYPE_VIEW || tblType == SP_TABLETYPE_TABLE)) {
					addItemAtIndex = i - 1;
					break;
				}
				if ([[copyTableNameField stringValue] localizedCompare:[tables objectAtIndex:i]] == NSOrderedAscending) {
					addItemAtIndex = i;
					break;
				}
			}
			if (addItemAtIndex == NSNotFound) {
				[tables addObject:[copyTableNameField stringValue]];
				[tableTypes addObject:[NSNumber numberWithInt:tblType]];
			} else {
				[tables insertObject:[copyTableNameField stringValue] atIndex:addItemAtIndex];
				[tableTypes insertObject:[NSNumber numberWithInt:tblType] atIndex:addItemAtIndex];		
			}
			
			// Set the selected table name and type, and use updateFilter to update the filter list and selection
			if (selectedTableName) [selectedTableName release];
			selectedTableName = [[NSString alloc] initWithString:[copyTableNameField stringValue]];
			selectedTableType = tblType;
			[self updateFilter:self];
			[tablesListView scrollRowToVisible:[tablesListView selectedRow]];
			[self updateSelectionWithTaskString:[NSString stringWithFormat:NSLocalizedString(@"Loading %@...", @"Loading table task string"), selectedTableName]];
		}
	}
}

/**
 * Renames the currently selected object (table, view, procedure, function, etc.).
 */
- (void)renameTable
{
	if([self tableType] == SP_TABLETYPE_VIEW || [self tableType] == SP_TABLETYPE_TABLE) {
		[mySQLConnection queryString:[NSString stringWithFormat:@"RENAME TABLE %@ TO %@", [[self tableName] backtickQuotedString], [[tableRenameField stringValue] backtickQuotedString]]];
		
		if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), 
							  NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
							  [NSString stringWithFormat:NSLocalizedString(@"An error occured while renaming table '%@'.\n\nMySQL said: %@", @"rename table error informative message"), [self tableName], [mySQLConnection getLastErrorMessage]]);
		}
		else {
			// If there was no error, rename the table in our list and reload the table view's data
			if (isTableListFiltered) {
				[tables replaceObjectAtIndex:[tables indexOfObject:[self tableName]] withObject:[tableRenameField stringValue]];
			}
			[filteredTables replaceObjectAtIndex:[tablesListView selectedRow] withObject:[tableRenameField stringValue]];
			if (selectedTableName) [selectedTableName release];
			selectedTableName = [[NSString alloc] initWithString:[tableRenameField stringValue]];
			[tablesListView reloadData];
			[self updateSelectionWithTaskString:[NSString stringWithFormat:NSLocalizedString(@"Loading %@...", @"Loading table task string"), selectedTableName]];
			return;
		}
	} else {
		// procedures and functions can only be renamed if one creates the new one and delete the old one
		// get the create syntax
		MCPResult *theResult;
		if([self tableType] == SP_TABLETYPE_PROC)
			theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE PROCEDURE %@", [[self tableName] backtickQuotedString]]];
		else if([self tableType] == SP_TABLETYPE_FUNC)
			theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE FUNCTION %@", [[self tableName] backtickQuotedString]]];
		else
			return;
		
		// Check for errors, only displaying if the connection hasn't been terminated
		if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
			if ([mySQLConnection isConnected]) {
				NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), 
								  NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
								  [NSString stringWithFormat:NSLocalizedString(@"An error occured while retrieving create syntax for '%@'.\n\nMySQL said: %@", @"message of panel when create syntax cannot be retrieved"), [self tableName], [mySQLConnection getLastErrorMessage]]);
			}
			return;
		}
		
		id tableSyntax = [[theResult fetchRowAsArray] objectAtIndex:2];
		
		if ([tableSyntax isKindOfClass:[NSData class]])
			tableSyntax = [[NSString alloc] initWithData:tableSyntax encoding:[mySQLConnection encoding]];
		
		NSString *tableType;
		
		switch([self tableType]){
			case SP_TABLETYPE_TABLE:
				tableType = NSLocalizedString(@"table",@"table");
				break;
			case SP_TABLETYPE_VIEW:
				tableType = NSLocalizedString(@"view",@"view");
				break;
			case SP_TABLETYPE_PROC:
				tableType = NSLocalizedString(@"procedure",@"procedure");
				break;
			case SP_TABLETYPE_FUNC:
				tableType = NSLocalizedString(@"function",@"function");
				break;
		}
		
		// replace the old name by the new one and drop the old one
		[mySQLConnection queryString:[tableSyntax stringByReplacingOccurrencesOfRegex:[NSString stringWithFormat:@"(?<=%@ )(`[^`]+?`)", [tableType uppercaseString]] withString:[[tableRenameField stringValue] backtickQuotedString]]];
		[tableSyntax release];
		if ([[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
			if ([mySQLConnection isConnected]) {
				[mySQLConnection queryString: [NSString stringWithFormat: @"DROP %@ %@", tableType, [[self tableName] backtickQuotedString]]];
			}
		}
		if (![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
							  [NSString stringWithFormat:NSLocalizedString(@"Couldn't rename '%@'.\nMySQL said: %@", @"message of panel when an item cannot be renamed"), [self tableName], [mySQLConnection getLastErrorMessage]]);
		} else {
			if (isTableListFiltered) {
				[tables replaceObjectAtIndex:[tables indexOfObject:[self tableName]] withObject:[tableRenameField stringValue]];
			}
			[filteredTables replaceObjectAtIndex:[tablesListView selectedRow] withObject:[tableRenameField stringValue]];
			if (selectedTableName) [selectedTableName release];
			selectedTableName = [[NSString alloc] initWithString:[tableRenameField stringValue]];
			[tablesListView reloadData];
			[self updateSelectionWithTaskString:[NSString stringWithFormat:NSLocalizedString(@"Loading %@...", @"Loading table task string"), selectedTableName]];
			return;
		}
	}
	
	// Set window title
	[tableWindow setTitle:[tableDocumentInstance displaySPName]];
}

/*
 * Check tableName for length and if the tableName doesn't match
 * against current database table/view names (case-insensitive).
 */
- (BOOL)isTableNameValid:(NSString *)tableName
{
	BOOL isValid = YES;

	// Check case-insensitive and delete trailing whitespaces
	// since 'foo  ' or '   ' are not valid table names
	NSString *fieldStr = [[tableName stringByMatching:@"(.*?)\\s*$" capture:1] lowercaseString];

	// If table name has trailing whitespaces return 'no valid'
	if([fieldStr length] != [tableName length]) return NO;

	if([fieldStr length] > 0) {
		for(id table in [self allTableAndViewNames]) {
			if([fieldStr isEqualToString:[table lowercaseString]]) {
				isValid = NO;
				break;
			}
		}
	} else {
		isValid = NO; 
	}
	return isValid;
}

@end
