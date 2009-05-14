//
//  TableRelations.m
//  sequel-pro
//
//  Created by J Knight on 13/05/09.
//  Copyright 2009 TalonEdge Ltd.. All rights reserved.
//

#import "TableRelations.h"
#import "TableDocument.h"
#import "TablesList.h"
#import "CMMCPConnection.h"
#import "CMMCPResult.h"
#import "SPTableData.h"

@implementation TableRelations

- (id)init
{
	if (![super init])
		return nil;
	
	relData = [[NSMutableArray alloc] init];

	return self;
}

- (void)dealloc
{	
	[relData release], relData = nil;
	
	[super dealloc];
}

- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(tableChanged:) 
												 name:NSTableViewSelectionDidChangeNotification 
											   object:tableList];
}

- (void)setConnection:(CMMCPConnection *)theConnection
{
	mySQLConnection = theConnection;			
}

- (IBAction)closeRelationSheet:(id)sender
{
	[NSApp stopModalWithCode:1];
}

- (IBAction)addRelation:(id)sender
{
	[NSApp stopModalWithCode:0];	
}

// user choose a reference table
- (IBAction)chooseRefTable:(id)sender
{
	NSString *table = [refTableSelect titleOfSelectedItem];
	
	[refColumnSelect removeAllItems];

	NSDictionary *info = [tableDataInstance informationForTable:table];
	NSArray *cols = [info objectForKey:@"columns"];
	NSMutableArray *colNames = [[NSMutableArray alloc] init];
	for( int i = 0; i < [cols count]; i++ ) {
		[colNames addObject:[[cols objectAtIndex:i] objectForKey:@"name"]];
	}
	[refColumnSelect addItemsWithTitles:colNames];
	[colNames release];
}

- (IBAction)addRow:(id)sender
{
	// set up the controls
	[tableBox setTitle:[NSString stringWithFormat:@"Table: %@",[tablesListInstance tableName] ]];
	[columnSelect removeAllItems];
	[columnSelect addItemsWithTitles:[tableDataInstance columnNames]];
	[refTableSelect removeAllItems];
	// grab only real tables
	NSArray *tables = [tablesListInstance tables];
	NSArray *types = [tablesListInstance tableTypes];
	NSMutableArray *validTables = [[NSMutableArray alloc] init];
	for( int i = 0; i < [tables count]; i++ ) {
		NSLog( @"%@ %@", [tables objectAtIndex:i], [types objectAtIndex:i] );
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
	
	
	[NSApp runModalForWindow:relationSheet];
	
	[NSApp endSheet:relationSheet];
	[relationSheet orderOut:nil];
}

- (IBAction)removeRow:(id)sender
{
	if ( [relationsView numberOfSelectedRows] ) {
		int resp = NSRunAlertPanel(@"Remove Relations",
		@"Are you sure you want to remove the selected relations?",
								   @"OK", @"Cancel", nil );
		if( resp == NSAlertDefaultReturn ) {
			
		}
	}
}

- (IBAction)refresh:(id)sender
{

	[relData removeAllObjects];
	
	if( [tablesListInstance tableType] == SP_TABLETYPE_TABLE ) {
		[labelText setStringValue:[NSString stringWithFormat:@"Relations for table: %@",[tablesListInstance tableName]]];			
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
	} else {
		[labelText setStringValue:@""];		
	}
	
	[relationsView reloadData];

}

- (void)tableChanged:(NSNotification *)notification
{
	if( [tablesListInstance tableType] == SP_TABLETYPE_TABLE ) {
		[addButton setEnabled:YES];
	} else {
		[addButton setEnabled:NO];		
	}	
	
	[self refresh:nil];
}


//tableView datasource methods
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [relData count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
	//NSNumber *theIdentifier = [aTableColumn identifier];
	NSDictionary *theRow = [relData objectAtIndex:rowIndex];
	return [theRow objectForKey:[aTableColumn identifier]];
}

- (void)tableView:(NSTableView *)aTableView
   setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)aTableColumn
			  row:(int)rowIndex
{
	
}

//tableView delegate methods
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
	return FALSE;
}
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	return FALSE;
}


@end
