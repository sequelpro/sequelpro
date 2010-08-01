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
#import "SPTableData.h"
#import "SPStringAdditions.h"
#import "SPConstants.h"
#import "SPAlertSheets.h"

@interface SPTableRelations (PrivateAPI)

- (void)_refreshRelationDataForcingCacheRefresh:(BOOL)clearAllCaches;
- (void)_updateAvailableTableColumns;

@end

@implementation SPTableRelations

@synthesize connection;
@synthesize relationData;

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
	// Set the table relation view's vertical gridlines if required
	[relationsTableView setGridStyleMask:([[NSUserDefaults standardUserDefaults] boolForKey:SPDisplayTableViewVerticalGridlines]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	
	// Set the strutcture and index view's font
	BOOL useMonospacedFont = [[NSUserDefaults standardUserDefaults] boolForKey:SPUseMonospacedFonts];
	
	for (NSTableColumn *column in [relationsTableView tableColumns])
	{
		[[column dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}
	
	// Register as an observer for the when the UseMonospacedFonts preference changes
	[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:SPUseMonospacedFonts options:NSKeyValueObservingOptionNew context:NULL];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(tableSelectionChanged:) 
												 name:SPTableChangedNotification 
											   object:tableDocumentInstance];

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
#pragma mark IB action methods

/**
 * Closes the relation sheet.
 */
- (IBAction)closeRelationSheet:(id)sender
{
	[NSApp endSheet:addRelationPanel returnCode:0];
	[addRelationPanel orderOut:self];
}

/**
 * Add a new relation using the selected values.
 */
- (IBAction)confirmAddRelation:(id)sender
{	
	[self closeRelationSheet:self];
	
	NSString *thisTable  = [tablesListInstance tableName];
	NSString *thisColumn = [columnPopUpButton titleOfSelectedItem];
	NSString *thatTable  = [refTablePopUpButton titleOfSelectedItem];
	NSString *thatColumn = [refColumnPopUpButton titleOfSelectedItem];
	
	NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ ADD FOREIGN KEY (%@) REFERENCES %@ (%@)", 
												[thisTable backtickQuotedString],
												[thisColumn backtickQuotedString],
												[thatTable backtickQuotedString],
												[thatColumn backtickQuotedString]];
	
	// If required add ON DELETE
	if ([onDeletePopUpButton indexOfSelectedItem] > 0) {
		query = [query stringByAppendingString:[NSString stringWithFormat:@" ON DELETE %@", [[onDeletePopUpButton titleOfSelectedItem] uppercaseString]]];
	}
	
	// If required add ON UPDATE
	if ([onUpdatePopUpButton indexOfSelectedItem] > 0) {
		query = [query stringByAppendingString:[NSString stringWithFormat:@" ON UPDATE %@", [[onUpdatePopUpButton titleOfSelectedItem] uppercaseString]]];
	}
	
	// Execute query
	[connection queryString:query];

	if ([connection queryErrored]) {
		SPBeginAlertSheet(NSLocalizedString(@"Error creating relation", @"error creating relation message"), 
						  NSLocalizedString(@"OK", @"OK button"),
						  nil, nil, [NSApp mainWindow], nil, nil, nil, nil, 
						  [NSString stringWithFormat:NSLocalizedString(@"The specified relation was unable to be created.\n\nMySQL said: %@", @"error creating relation informative message"), [connection getLastErrorMessage]]);		
	} 
	else {
		[self _refreshRelationDataForcingCacheRefresh:YES];
	} 	
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
	MCPResult *result = [connection queryString:[NSString stringWithFormat:@"SELECT table_name FROM information_schema.tables WHERE table_type = 'BASE TABLE' AND engine = 'InnoDB' AND table_schema = %@", [[tableDocumentInstance database] tickQuotedString]]];
	
	[result dataSeek:0];
	
	for (NSInteger i = 0; i < [result numOfRows]; i++)
	{		
		[refTablePopUpButton addItemWithTitle:[[result fetchRowAsArray] objectAtIndex:0]];
	}
	
	[self selectReferenceTable:nil];
	
	[NSApp beginSheet:addRelationPanel
	   modalForWindow:tableWindow
		modalDelegate:self
	   didEndSelector:nil 
		  contextInfo:nil];
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
		
		NSArray *buttons = [alert buttons];
		
		// Change the alert's cancel button to have the key equivalent of return
		[[buttons objectAtIndex:0] setKeyEquivalent:@"d"];
		[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
		[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
		
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
	BOOL enableInteraction = ![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableRelations] || ![tableDocumentInstance isWorking];

	// To begin enable all interface elements
	[addRelationButton setEnabled:enableInteraction];		
	[refreshRelationsButton setEnabled:enableInteraction];
	[relationsTableView setEnabled:YES];
	
	// Get the current table's storage engine
	NSString *engine = [tableDataInstance statusValueForKey:@"Engine"];
	
	if (([tablesListInstance tableType] == SPTableTypeTable) && ([[engine lowercaseString] isEqualToString:@"innodb"])) {
		
		// Update the text label
		[labelTextField setStringValue:[NSString stringWithFormat:@"Relations for table: %@", [tablesListInstance tableName]]];
		
		[addRelationButton setEnabled:enableInteraction];
		[refreshRelationsButton setEnabled:enableInteraction];
		[relationsTableView setEnabled:YES];
	} 
	else {
		[addRelationButton setEnabled:NO];		
		[refreshRelationsButton setEnabled:NO];	
		[relationsTableView setEnabled:NO];
		
		[labelTextField setStringValue:([tablesListInstance tableType] == SPTableTypeTable) ? @"This table currently does not support relations. Only tables that use the InnoDB storage engine support them." : @""];
	}	
	
	[self _refreshRelationDataForcingCacheRefresh:NO];
}

#pragma mark -
#pragma mark Tableview datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [relationData count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
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

/*
 * Double-click action on table cells - for the time being, return
 * NO to disable editing.
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if ([tableDocumentInstance isWorking]) return NO;

	return NO;
}

/**
 * Disable row selection while the document is working.
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
	return ![tableDocumentInstance isWorking];
}

#pragma mark -
#pragma mark Task interaction

/**
 * Disable all content interactive elements during an ongoing task.
 */
- (void)startDocumentTaskForTab:(NSNotification *)aNotification
{

	// Only proceed if this view is selected.
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableRelations]) return;

	[addRelationButton setEnabled:NO];
	[refreshRelationsButton setEnabled:NO];
	[removeRelationButton setEnabled:NO];
}

/**
 * Enable all content interactive elements after an ongoing task.
 */
- (void)endDocumentTaskForTab:(NSNotification *)aNotification
{

	// Only proceed if this view is selected.
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableRelations]) return;

	if ([relationsTableView isEnabled]) {
		[addRelationButton setEnabled:YES];
		[refreshRelationsButton setEnabled:YES];
	}
	
	[removeRelationButton setEnabled:([relationsTableView numberOfSelectedRows] > 0)];
}

#pragma mark -
#pragma mark Other

/**
 * Returns an array of relation data to be used for printing purposes. The first element in the array is always
 * an array of the columns and each subsequent element is an array of relation data.
 */
- (NSArray *)relationDataForPrinting
{
	NSMutableArray *headings = [[NSMutableArray alloc] init];
	NSMutableArray *data     = [NSMutableArray array];
	
	// Get the relations table view's columns
	for (NSTableColumn *column in [relationsTableView tableColumns])
	{
		[headings addObject:[[column headerCell] stringValue]];
	}
	
	[data addObject:headings];
	
	[headings release];
		
	// Get the relation data
	for (NSDictionary *relation in relationData)
	{
		NSMutableArray *temp = [[NSMutableArray alloc] init];
		
		[temp addObject:[relation objectForKey:@"name"]];
		[temp addObject:[relation objectForKey:@"columns"]];
		[temp addObject:[relation objectForKey:@"fk_table"]];
		[temp addObject:[relation objectForKey:@"fk_columns"]];
		[temp addObject:([relation objectForKey:@"on_update"]) ? [relation objectForKey:@"on_update"] : @""];
		[temp addObject:([relation objectForKey:@"on_delete"]) ? [relation objectForKey:@"on_delete"] : @""];
		
		[data addObject:temp];
		
		[temp release];
	}
	
	return data; 
}

/**
 * NSAlert didEnd method.
 */
- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	if ([contextInfo isEqualToString:@"removeRelation"]) {
		
		if (returnCode == NSAlertDefaultReturn) {
			
			NSString *thisTable = [tablesListInstance tableName];
			NSIndexSet *selectedSet = [relationsTableView selectedRowIndexes];
			
			NSUInteger row = [selectedSet lastIndex];
			
			while (row != NSNotFound) 
			{
				NSString *relationName = [[relationData objectAtIndex:row] objectForKey:@"name"];
				NSString *query = [NSString stringWithFormat:@"ALTER TABLE %@ DROP FOREIGN KEY %@", [thisTable backtickQuotedString], [relationName backtickQuotedString]];
				
				[connection queryString:query];
				
				if ([connection queryErrored]) {
					
					SPBeginAlertSheet(NSLocalizedString(@"Unable to remove relation", @"error removing relation message"), 
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
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	// Display table veiew vertical gridlines preference changed
	if ([keyPath isEqualToString:SPDisplayTableViewVerticalGridlines]) {
        [relationsTableView setGridStyleMask:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	}
	// Use monospaced fonts preference changed
	else if ([keyPath isEqualToString:SPUseMonospacedFonts]) {
		
		BOOL useMonospacedFont = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
		
		for (NSTableColumn *column in [relationsTableView tableColumns])
		{
			[[column dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}
		
		[relationsTableView reloadData];
	}
}

/**
 * Menu validation
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// Remove row
	if ([menuItem action] == @selector(removeRelation:)) {
		[menuItem setTitle:([relationsTableView numberOfSelectedRows] > 1) ? NSLocalizedString(@"Delete Relations", @"delete relations menu item") : NSLocalizedString(@"Delete Relation", @"delete relation menu item")];
		
		return ([relationsTableView numberOfSelectedRows] > 0);
	}
	
	return YES;
}

#pragma mark -

/*
 * Dealloc.
 */
- (void)dealloc
{	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:SPUseMonospacedFonts];

	[relationData release], relationData = nil;
	
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
	
	if ([tablesListInstance tableType] == SPTableTypeTable) {
		
		if (clearAllCaches) [tableDataInstance updateInformationForCurrentTable];
				
		NSArray *constraints = [tableDataInstance getConstraints];
		
		for (NSDictionary *constraint in constraints) 
		{
			[relationData addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[constraint objectForKey:@"name"], @"name",
									[[constraint objectForKey:@"columns"] objectAtIndex:0], @"columns",
									[constraint objectForKey:@"ref_table"], @"fk_table",
									[constraint objectForKey:@"ref_columns"], @"fk_columns",
									([constraint objectForKey:@"update"] ? [constraint objectForKey:@"update"] : @""), @"on_update",
    								([constraint objectForKey:@"delete"] ? [constraint objectForKey:@"delete"] : @""), @"on_delete",
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
	for (NSDictionary *aColumn in columns) 
	{		
		if ([[columnInfo objectForKey:@"type"] isEqualToString:[aColumn objectForKey:@"type"]]) {
			[validColumns addObject:[aColumn objectForKey:@"name"]];			
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
