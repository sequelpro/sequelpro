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
//

#import "SPTableRelations.h"
#import "TableDocument.h"
#import "TablesList.h"
#import "CMMCPConnection.h"
#import "CMMCPResult.h"
#import "SPTableData.h"

@implementation SPTableRelations

/*
 * init
 */
- (id)init
{
	if (![super init])
		return nil;
	
	relData = [[NSMutableArray alloc] init];

	return self;
}

/*
 * dealloc
 */
- (void)dealloc
{	
	[relData release], relData = nil;
	
	[super dealloc];
}

/*
 * awakeFromNib
 */
- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(tableChanged:) 
												 name:NSTableViewSelectionDidChangeNotification 
											   object:tableList];
}

/*
 * setConnection
 * set the database connection
 */
- (void)setConnection:(CMMCPConnection *)theConnection
{
	mySQLConnection = theConnection;			
}

#pragma mark -
#pragma mark IB action methods

/*
 * closeRelationSheet
 * happens if the user hits cancel
 */
- (IBAction)closeRelationSheet:(id)sender
{
	// 0 = success,
	[NSApp stopModalWithCode:0];
}

/*
 * addRelation
 * attempt to add the relations from the relationSheet data
 */
- (IBAction)addRelation:(id)sender
{
	// 0 = success,
	int retCode = 0;
	NSString *thisTable = [tablesListInstance tableName];
	NSString *thisColumn = [columnSelect titleOfSelectedItem];
	NSString *thatTable = [refTableSelect titleOfSelectedItem];
	NSString *thatColumn = [refColumnSelect titleOfSelectedItem];
	NSString *onUpdate = [onUpdateSelect titleOfSelectedItem];
	NSString *onDelete = [onDeleteSelect titleOfSelectedItem];
	NSString *query = [NSString stringWithFormat:
					   @"ALTER TABLE `%@` ADD FOREIGN KEY (`%@`) REFERENCES `%@` (`%@`)", 
					   thisTable,
					   thisColumn,
					   thatTable,
					   thatColumn];
	
	if( [onDelete length] ) {
		query = [query stringByAppendingString:[NSString stringWithFormat:@" ON DELETE %@", onDelete]];
	}
	if( [onUpdate length] ) {
			query = [query stringByAppendingString:[NSString stringWithFormat:@" ON UPDATE %@", onUpdate]];
	}
	
	//NSLog( query );

	[mySQLConnection queryString:query];
	
	if ( ! [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
		NSLog(@"error: %@", [mySQLConnection getLastErrorMessage]);
		retCode = 1;
	} 
		
	[NSApp stopModalWithCode:retCode];	
}

/*
 * chooseRefTable
 * update the columns select when the user chooses a reference table
 */
- (IBAction)chooseRefTable:(id)sender
{
	NSString *table = [refTableSelect titleOfSelectedItem];
	
	[refColumnSelect removeAllItems];

	NSDictionary *info = [tableDataInstance informationForTable:table];
	NSArray *cols = [info objectForKey:@"columns"];
	NSMutableArray *colNames = [[NSMutableArray alloc] init];
	// TODO depending on the selected column type, it would be smart to only
	// show columns that are valid to linkage. this.int -> ints only
	for( int i = 0; i < [cols count]; i++ ) {
		[colNames addObject:[[cols objectAtIndex:i] objectForKey:@"name"]];
	}
	[refColumnSelect addItemsWithTitles:colNames];
	[colNames release];
}

/*
 * addRow
 * called when the user indicated they want to add a relation
 */
- (IBAction)addRow:(id)sender
{
	// TODO check that this is an INNO table 
	
	// set up the controls
	[tableBox setTitle:[NSString stringWithFormat:@"Table: %@",[tablesListInstance tableName] ]];
	[columnSelect removeAllItems];
	[columnSelect addItemsWithTitles:[tableDataInstance columnNames]];
	[refTableSelect removeAllItems];
	// grab only real tables
	// TODO filter this so it only shows INNO tables
	NSArray *tables = [tablesListInstance tables];
	NSArray *types = [tablesListInstance tableTypes];
	NSMutableArray *validTables = [[NSMutableArray alloc] init];
	for( int i = 0; i < [tables count]; i++ ) {
		if( [[types objectAtIndex:i] intValue] == SP_TABLETYPE_TABLE ) {
			[validTables addObject:[tables objectAtIndex:i]];
		}
	}
	[refTableSelect addItemsWithTitles:validTables];
	[validTables release];
	[self chooseRefTable:nil];
	
	[NSApp beginSheet:relationSheet
			modalForWindow:tableWindow
			modalDelegate:self
			didEndSelector:nil 
		  contextInfo:nil];
	
	
	int code = [NSApp runModalForWindow:relationSheet];
	
	[NSApp endSheet:relationSheet];
	[relationSheet orderOut:nil];

	// 0 indicates success
	if( code ) {
		NSRunAlertPanel(NSLocalizedString(@"Error", @"error"), //@"Error Adding Relation",
						[NSString stringWithFormat:NSLocalizedString(@"Couldn't add relation.\nMySQL said: %@",@"message of panel when relation cannot be created"),[mySQLConnection getLastErrorMessage]],
						NSLocalizedString(@"OK", @"OK button"), nil, nil );		
	} else {
		[self refresh:nil];		
	}
}

/*
 * removeRow
 * called when rows are selected and the user wants to remove those relations
 */
- (IBAction)removeRow:(id)sender
{
	if ( [relationsView numberOfSelectedRows] ) {
		int resp = NSRunAlertPanel(NSLocalizedString(@"Delete relation",@"delete relation message"),
								   NSLocalizedString(@"Are you sure you want to delete the selected relations?\nThis action cannot be undone!",@"delete selected relation informative message"),
								   NSLocalizedString(@"Delete", @"delete button"), 
								   NSLocalizedString(@"Cancel", @"cancel button"), nil );
		if( resp == NSAlertDefaultReturn ) {
			NSString *thisTable = [tablesListInstance tableName];
			NSIndexSet *selectedSet = [relationsView selectedRowIndexes];
			unsigned int row = [selectedSet lastIndex];
			while( row != NSNotFound ) {
				NSArray *relName = [[relData objectAtIndex:row] objectForKey:@"name"];
				NSString *query = [NSString stringWithFormat:@"ALTER TABLE `%@` DROP FOREIGN KEY `%@`",
								   thisTable, relName];
				//NSLog( query );
				
				[mySQLConnection queryString:query];
				
				if ( ! [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
					NSLog(@"error: %@", [mySQLConnection getLastErrorMessage]);
					NSRunAlertPanel(NSLocalizedString(@"Error", @"error"), 
									[NSString stringWithFormat:NSLocalizedString(@"Couldn't remove relation.\nMySQL said: %@",@"message of panel when relation cannot be removed"),[mySQLConnection getLastErrorMessage]],
									NSLocalizedString(@"OK", @"OK button"), nil, nil );		
					// abort loop
					break;
				} 
				row = [selectedSet indexLessThanIndex:row];
			}
			[self refresh:nil];
		}
	}
}

/*
 * refresh
 * called to refesh the relations list
 */
- (IBAction)refresh:(id)sender
{
	[relData removeAllObjects];
	
	if ([tablesListInstance tableType] == SP_TABLETYPE_TABLE) {
		
		[tableDataInstance updateInformationForCurrentTable];
				
		NSArray *constraints = [tableDataInstance getConstraints];
		
		for( int i = 0; i < [constraints count]; i++ ) {
			[relData addObject:[NSDictionary dictionaryWithObjectsAndKeys:
								[tablesListInstance tableName], @"table",
								[[constraints objectAtIndex:i] objectForKey:@"name"], @"name",
								[[constraints objectAtIndex:i] objectForKey:@"columns"], @"columns",
								[[constraints objectAtIndex:i] objectForKey:@"ref_table"], @"fk_table",
								[[constraints objectAtIndex:i] objectForKey:@"ref_columns"], @"fk_columns",
								[[constraints objectAtIndex:i] objectForKey:@"update"], @"on_update",
								[[constraints objectAtIndex:i] objectForKey:@"delete"], @"on_delete",
								nil]];
			
		}
	} 
	
	[relationsView reloadData];
}

/*
 * tableChanged
 * notification from the tableList when the users click a table
 */
- (void)tableChanged:(NSNotification *)notification
{
	// To begin enable all interface elements
	[addButton setEnabled:YES];		
	[refreshButton setEnabled:YES];
	
	// Get the current table's storage engine
	NSString *engine = [tableDataInstance statusValueForKey:@"Engine"];
	
	if (([tablesListInstance tableType] == SP_TABLETYPE_TABLE) && ([[engine lowercaseString] isEqualToString:@"innodb"])) {
		
		// Update the text label
		[labelText setStringValue:[NSString stringWithFormat:@"Relations for table: %@", [tablesListInstance tableName]]];
		
		[addButton setEnabled:YES];
		[refreshButton setEnabled:YES];
	} 
	else {
		[addButton setEnabled:NO];		
		[refreshButton setEnabled:NO];	
		
		[labelText setStringValue:([tablesListInstance tableType] == SP_TABLETYPE_TABLE) ? @"This table does not support relations" : @""];
	}	
	
	[self refresh:self];
}

#pragma mark -
#pragma mark Tableview datasource methods

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [relData count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
	NSDictionary *theRow = [relData objectAtIndex:rowIndex];
	return [theRow objectForKey:[aTableColumn identifier]];
}

- (void)tableView:(NSTableView *)aTableView
   setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)aTableColumn
			  row:(int)rowIndex
{
	
}

#pragma mark -
#pragma mark Tableview delegate methods

- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
	
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	if ( [relationsView numberOfSelectedRows] ) {
		[removeButton setEnabled:YES];
	} else {
		[removeButton setEnabled:NO];		
	}
}

- (void)tableViewSelectionIsChanging:(NSNotification *)aNotification
{
	
}

- (void)tableViewColumnDidResize:(NSNotification *)aNotification
{
	
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	return NO;
}

- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard
{
	return NO;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	return NO;
}

@end
