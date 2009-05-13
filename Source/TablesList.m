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
//  Or mail to <lorenz@textor.ch>

#import "TablesList.h"
#import "TableDocument.h"
#import "TableSource.h"
#import "TableContent.h"
#import "SPTableData.h"
#import "TableDump.h"
#import "ImageAndTextCell.h"
#import "CMMCPConnection.h"
#import "CMMCPResult.h"
#import "SPStringAdditions.h"

@implementation TablesList

#pragma mark IBAction methods

/**
 * Loads all table names in array tables and reload the tableView
 */
- (IBAction)updateTables:(id)sender
{
	CMMCPResult *theResult;
	NSArray *resultRow;
	int i;
	BOOL containsViews = NO;
	NSString *selectedTable = nil;
	NSInteger selectedRowIndex;
	
	selectedRowIndex = [tablesListView selectedRow];	
	if(selectedRowIndex > 0 && [tables count]){
		selectedTable = [NSString stringWithString:[tables objectAtIndex:selectedRowIndex]];
	}

	[tablesListView deselectAll:self];
	[tables removeAllObjects];
	[tableTypes removeAllObjects];
	[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_NONE]];

	if ([tableDocumentInstance database]) {

		// Notify listeners that a query has started
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];

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
					containsViews = YES;
				} else {
					[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_TABLE]];
				}
			}		
		}

		/* grab the procedures and functions
		 *
		 * using information_schema gives us more info (for information window perhaps?) but breaks
		 * backward compatibility with pre 4 I believe. I left the other methods below, in case.
		 */
		NSString *pQuery = [NSString stringWithFormat:@"SELECT * FROM information_schema.routines WHERE routine_schema = '%@' ORDER BY routine_name",[tableDocumentInstance database]];
		theResult = [mySQLConnection queryString:pQuery];
		
		if( [theResult numOfRows] ) {
			// add the header row
			[tables addObject:NSLocalizedString(@"PROCS & FUNCS",@"header for procs & funcs list")];
			[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_NONE]];
			[theResult dataSeek:0];
			
			if( [theResult numOfFields] == 1 ) {
				for( i = 0; i < [theResult numOfRows]; i++ ) {
					[tables addObject:[[theResult fetchRowAsArray] objectAtIndex:3]];
					if( [[[theResult fetchRowAsArray] objectAtIndex:4] isEqualToString:@"PROCEDURE"]) {
						[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_PROC]];						
					} else {
						[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_FUNC]];						
					}
				}
			} else {
				for( i = 0; i < [theResult numOfRows]; i++ ) {
					resultRow = [theResult fetchRowAsArray];
					[tables addObject:[resultRow objectAtIndex:3]];
					if( [[resultRow objectAtIndex:4] isEqualToString:@"PROCEDURE"] ) {
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
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
	}

	if (containsViews) {
		[tables insertObject:NSLocalizedString(@"TABLES & VIEWS",@"header for table & views list") atIndex:0];
	} else {
		[tables insertObject:NSLocalizedString(@"TABLES",@"header for table list") atIndex:0];
	}

	[tablesListView reloadData];
	
	//if the previous selected table still exists, select it
	if( selectedTable != nil && [tables indexOfObject:selectedTable] < [tables count]) {
		[tablesListView selectRowIndexes:[NSIndexSet indexSetWithIndex:[tables indexOfObject:selectedTable]] byExtendingSelection:NO];
	}
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
	
	[NSApp beginSheet:tableSheet
	   modalForWindow:tableWindow
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
	
	NSInteger returnCode = [NSApp runModalForWindow:tableSheet];
	
	[NSApp endSheet:tableSheet];
	[tableSheet orderOut:nil];
	
	if (!returnCode) {
		// Clear table name
		[tableNameField setStringValue:@""];
		
		return;
	}
		
	NSString *tableName = [tableNameField stringValue];
	NSString *createStatement = [NSString stringWithFormat:@"CREATE TABLE %@ (id INT)", [tableName backtickQuotedString]];
	
	// If there is an encoding selected other than the default we must specify it in CREATE TABLE statement
	if ([tableEncodingButton indexOfSelectedItem] > 0) {
		createStatement = [NSString stringWithFormat:@"%@ DEFAULT CHARACTER SET %@", createStatement, [[tableDocumentInstance mysqlEncodingFromDisplayEncoding:[tableEncodingButton title]] backtickQuotedString]];
	}
	
	// Create the table
	[mySQLConnection queryString:createStatement];
	
	if ([[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
		// Table creation was successful
		[tables insertObject:tableName atIndex:1];
		[tableTypes insertObject:[NSNumber numberWithInt:SP_TABLETYPE_TABLE] atIndex:1];
		[tablesListView reloadData];
		[tablesListView selectRow:1 byExtendingSelection:NO];
		
		NSInteger selectedIndex = [tabView indexOfTabViewItem:[tabView selectedTabViewItem]];
		
		if (selectedIndex == 0) {
			[tableSourceInstance loadTable:tableName];
			structureLoaded = YES;
			contentLoaded = NO;
			statusLoaded = NO;
		} 
		else if (selectedIndex == 1) {
			[tableContentInstance loadTable:tableName];
			structureLoaded = NO;
			contentLoaded = YES;
			statusLoaded = NO;
		} 
		else if (selectedIndex == 3) {
			[tableStatusInstance loadTable:tableName];
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
		[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/%@/%@", [tableDocumentInstance mySQLVersion],
							  [tableDocumentInstance name], [tableDocumentInstance database], tableName]];
	} 
	else {
		// Error while creating new table
		alertSheetOpened = YES;
		
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self,
						  @selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addRow",
						  [NSString stringWithFormat:NSLocalizedString(@"Couldn't add table %@.\nMySQL said: %@", @"message of panel when table cannot be created with the given name"),
						  tableName, [mySQLConnection getLastErrorMessage]]);
		
		[tableTypes removeObjectAtIndex:([tableTypes count] - 1)];
		[tables removeObjectAtIndex:([tables count] - 1)];
		[tablesListView reloadData];
	}
	
	// Clear table name
	[tableNameField setStringValue:@""];
}

/**
 * Closes the add table sheet and stops the modal session
 */
- (IBAction)closeTableSheet:(id)sender
{
	[NSApp stopModalWithCode:[sender tag]];
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

	NSIndexSet *indexes = [tablesListView selectedRowIndexes];
	NSString *tblTypes;
	unsigned currentIndex = [indexes lastIndex];
	
	if ([tablesListView numberOfSelectedRows] == 1) {
		if([[tableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_VIEW)
			tblTypes = NSLocalizedString(@"view", @"view");
		else if([[tableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_TABLE)
			tblTypes = NSLocalizedString(@"table", @"table");
		else if([[tableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_PROC)
			tblTypes = NSLocalizedString(@"procedure", @"procedure");
		else if([[tableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_FUNC)
			tblTypes = NSLocalizedString(@"function", @"function");
		
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Delete %@ '%@'?", @"delete table/view message"), tblTypes, [tables objectAtIndex:[tablesListView selectedRow]]]];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the %@ '%@'. This operation cannot be undone.", @"delete table/view informative message"), tblTypes, [tables objectAtIndex:[tablesListView selectedRow]]]];
	} 
	else {
		int tblTypesChecksum = 0;
		while (currentIndex != NSNotFound)
		{
			tblTypesChecksum += [[tableTypes objectAtIndex:currentIndex] intValue];
			currentIndex = [indexes indexLessThanIndex:currentIndex];
		}

		if(tblTypesChecksum == 0)
			tblTypes = NSLocalizedString(@"tables", @"tables");
		else if(tblTypesChecksum == [indexes count])
			tblTypes = NSLocalizedString(@"views", @"views");
		else
			tblTypes = NSLocalizedString(@"tables/views", @"tables/views");

		[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Delete selected %@?", @"delete tables/views message"), tblTypes]];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the selected %@. This operation cannot be undone.", @"delete tables/views informative message"), tblTypes]];
	}
		
	[alert beginSheetModalForWindow:tableWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"removeRow"];
}

/**
 * Copies a table, if desired with content, or view
 */
- (IBAction)copyTable:(id)sender
{
	CMMCPResult *queryResult;
//	NSArray *fieldNames;
//	NSArray *theRow;
//	NSMutableString *rowValue = [NSMutableString string];
//	NSMutableArray *fieldValues;
	int code;
	BOOL isView;
	NSString *tblType;
//	int rowCount, i, j;
//	BOOL errors = NO;

	if ( [tablesListView numberOfSelectedRows] != 1 ||
		[[tableTypes objectAtIndex:[tablesListView selectedRow]] intValue] == SP_TABLETYPE_PROC ||
		[[tableTypes objectAtIndex:[tablesListView selectedRow]] intValue] == SP_TABLETYPE_FUNC ) {
		
		return;
	}
	
	
	if ( ![tableSourceInstance saveRowOnDeselect] || ![tableContentInstance saveRowOnDeselect] ) {
		return;
	}
	[tableWindow endEditingFor:nil];

	// Detect table type: table or view
	isView = [[tableTypes objectAtIndex:[tablesListView selectedRow]] intValue] == SP_TABLETYPE_VIEW;

	//open copyTableSheet
	[copyTableNameField setStringValue:[NSString stringWithFormat:@"%@Copy", [tables objectAtIndex:[tablesListView selectedRow]]]];
	[copyTableContentSwitch setState:NSOffState];
	// Hide if selected item is a view
	[copyTableContentSwitch setEnabled:!isView];
	// Set message according to table type and the table type string
	if(isView) {
		[copyTableMessageField setStringValue:NSLocalizedString(@"Duplicate view to", @"duplicate view message")];
		tblType = @"VIEW";
	} else {
		[copyTableMessageField setStringValue:NSLocalizedString(@"Duplicate table to", @"duplicate table message")];
		tblType = @"TABLE";
	}


	[NSApp beginSheet:copyTableSheet
	   modalForWindow:tableWindow
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
	
	code = [NSApp runModalForWindow:copyTableSheet];
	
	[NSApp endSheet:copyTableSheet];
	[copyTableSheet orderOut:nil];

	if ( !code )
		return;
	if ( [[copyTableNameField stringValue] isEqualToString:@""] ) {
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil, NSLocalizedString(@"Table must have a name.", @"message of panel when no name is given for table"));
		return;
	}

	//get table structure
	queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE %@ %@",
					tblType,
					[[tables objectAtIndex:[tablesListView selectedRow]] backtickQuotedString]
					]];
	
	if ( ![queryResult numOfRows] ) {
		//error while getting table structure
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
			[NSString stringWithFormat:NSLocalizedString(@"Couldn't get table information.\nMySQL said: %@", @"message of panel when table information cannot be retrieved"), [mySQLConnection getLastErrorMessage]]);

    } else {
		//insert new table name in create syntax and create new table
		NSScanner *scanner = [NSScanner alloc];
		NSString *scanString;

		if(isView){
			[scanner initWithString:[[queryResult fetchRowAsDictionary] objectForKey:@"Create View"]];
			[scanner scanUpToString:@"AS" intoString:nil];
			[scanner scanUpToString:@"" intoString:&scanString];
			[mySQLConnection queryString:[NSString stringWithFormat:@"CREATE VIEW %@ %@", [[copyTableNameField stringValue] backtickQuotedString], scanString]];
		} else {
			[scanner initWithString:[[queryResult fetchRowAsDictionary] objectForKey:@"Create Table"]];
			[scanner scanUpToString:@"(" intoString:nil];
			[scanner scanUpToString:@"" intoString:&scanString];
			[mySQLConnection queryString:[NSString stringWithFormat:@"CREATE TABLE %@ %@", [[copyTableNameField stringValue] backtickQuotedString], scanString]];
		}
		[scanner release];
		
        if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
			//error while creating new table
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
				[NSString stringWithFormat:NSLocalizedString(@"Couldn't create table.\nMySQL said: %@", @"message of panel when table cannot be created"), [mySQLConnection getLastErrorMessage]]);
        } else {
			
            if ( [copyTableContentSwitch state] == NSOnState ) {
				//copy table content
                [mySQLConnection queryString:[NSString stringWithFormat:
											  @"INSERT INTO %@ SELECT * FROM %@",
											  [[copyTableNameField stringValue] backtickQuotedString],
											  [[tables objectAtIndex:[tablesListView selectedRow]] backtickQuotedString]
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
			
			[tables insertObject:[copyTableNameField stringValue] atIndex:[tablesListView selectedRow]+1];
			[tableTypes insertObject:[NSNumber numberWithInt:(isView)?SP_TABLETYPE_VIEW : SP_TABLETYPE_TABLE] atIndex:[tablesListView selectedRow]+1];
			[tablesListView selectRow:[tablesListView selectedRow]+1 byExtendingSelection:NO];
			[self updateTables:self];
			[tablesListView scrollRowToVisible:[tablesListView selectedRow]];

		}
	}
}

#pragma mark Alert sheet methods

/**
 * Method for alert sheets. Invoked when user wants to delete a table.
 */
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{
	if ( [contextInfo isEqualToString:@"addRow"] ) {
		alertSheetOpened = NO;
	} else if ( [contextInfo isEqualToString:@"removeRow"] ) {
		if ( returnCode == NSAlertDefaultReturn ) {
			[self removeTable];
		}
	}
}

/**
 * Closes copyTableSheet and stops modal session
 */
- (IBAction)closeCopyTableSheet:(id)sender
{
	[NSApp stopModalWithCode:[sender tag]];
}

#pragma mark Additional methods

/**
 * Removes selected table(s) or view(s) from mysql-db and tableView
 */
- (void)removeTable
{
	NSIndexSet *indexes = [tablesListView selectedRowIndexes];
	NSString *errorText;
	BOOL error = FALSE;
	
	// get last index
	unsigned currentIndex = [indexes lastIndex];
	while (currentIndex != NSNotFound)
	{

		if([[tableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_VIEW)
		{
			[mySQLConnection queryString: [NSString stringWithFormat: @"DROP VIEW %@",
																	  [[tables objectAtIndex:currentIndex] backtickQuotedString]
																	]];
		} else if([[tableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_TABLE) {
			[mySQLConnection queryString: [NSString stringWithFormat: @"DROP TABLE %@",
										   [[tables objectAtIndex:currentIndex] backtickQuotedString]
										   ]];			
		} else if([[tableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_PROC) {
			[mySQLConnection queryString: [NSString stringWithFormat: @"DROP PROCEDURE %@",
										   [[tables objectAtIndex:currentIndex] backtickQuotedString]
										   ]];			
		} else if([[tableTypes objectAtIndex:currentIndex] intValue] == SP_TABLETYPE_FUNC) {
			[mySQLConnection queryString: [NSString stringWithFormat: @"DROP FUNCTION %@",
										   [[tables objectAtIndex:currentIndex] backtickQuotedString]
										   ]];			
		} 
	
		if ( [[mySQLConnection getLastErrorMessage] isEqualTo:@""] ) {
			//dropped table with success
			[tables removeObjectAtIndex:currentIndex];
			[tableTypes removeObjectAtIndex:currentIndex];
		} else {
			//couldn't drop table
			error = TRUE;
			errorText = [mySQLConnection getLastErrorMessage];
		}
		
		// get next index (beginning from the end)
		currentIndex = [indexes indexLessThanIndex:currentIndex];
	}
	
	[tablesListView deselectAll:self];
	//[tableSourceInstance loadTable:nil];
	//[tableContentInstance loadTable:nil];
	//[tableStatusInstance loadTable:nil];
	[tablesListView reloadData];
	
	// set window title
	[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/%@", [tableDocumentInstance mySQLVersion],
								[tableDocumentInstance name], [tableDocumentInstance database]]];
	if ( error )
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
			[NSString stringWithFormat:NSLocalizedString(@"Couldn't remove table.\nMySQL said: %@", @"message of panel when table cannot be removed"), errorText]);
}

/**
 * Sets the connection (received from TableDocument) and makes things that have to be done only once 
 */
- (void)setConnection:(CMMCPConnection *)theConnection
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
	if ([notification object] == tableNameField) {
		[addTableButton setEnabled:([[tableNameField stringValue] length] > 0)]; 
	}
}

#pragma mark Getter methods

/**
 * Returns the currently selected table or nil if no table or mulitple tables are selected
 */
- (NSString *)tableName
{
	if ( [tablesListView numberOfSelectedRows] == 1 ) {
		return [tables objectAtIndex:[tablesListView selectedRow]];
	} else if ([tablesListView numberOfSelectedRows] > 1) {
		return @"";
	} else {
		return nil;
	}
}

/*
 * Returns the currently selected table type, or -1 if no table or multiple tables are selected
 */
- (int) tableType
{
	if ( [tablesListView numberOfSelectedRows] == 1 ) {
		return [[tableTypes objectAtIndex:[tablesListView selectedRow]] intValue];
	} else if ([tablesListView numberOfSelectedRows] > 1) {
		return -1;
	} else {
		return -1;
	}
}

/**
 * Database tables accessor
 */
- (NSArray *)tables
{
	return tables;
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

#pragma mark Setter methods

/**
 * Mark the content table for refresh when it's next switched to
 */
- (void)setContentRequiresReload:(BOOL)reload
{
	contentLoaded = !reload;
}

#pragma mark Datasource methods

/**
 * Returns the number of tables in the current database.
 */
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [tables count];
}

/**
 * Returns the table names to be displayed in the tables list table view.
 */
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	return [tables objectAtIndex:rowIndex];
}

/**
 * Renames a table (in tables-array and mysql-db).
 * Removes new table from table-array if renaming had no success
 */
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if ([[tables objectAtIndex:rowIndex] isEqualToString:anObject]) {
		// No changes in table name
	} 
	else if ([anObject isEqualToString:@""]) {
		// Table has no name
		alertSheetOpened = YES;
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self,
						  @selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addRow", NSLocalizedString(@"Table must have a name.", @"message of panel when no name is given for table"));
	} 
	else {
		[mySQLConnection queryString:[NSString stringWithFormat:@"RENAME TABLE %@ TO %@", [[tables objectAtIndex:rowIndex] backtickQuotedString], [anObject backtickQuotedString]]];
		
		if ([[mySQLConnection getLastErrorMessage] isEqualToString:@""]) {
			// Renamed with success
			[tables replaceObjectAtIndex:rowIndex withObject:anObject];
			
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
				[tableStatusInstance loadTable:anObject];
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
			[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/%@/%@", [tableDocumentInstance mySQLVersion],
								  [tableDocumentInstance name], [tableDocumentInstance database], anObject]];
		} 
		else {
			// Error while renaming
			alertSheetOpened = YES;
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self,
							  @selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addRow",
							  [NSString stringWithFormat:NSLocalizedString(@"Couldn't rename table.\nMySQL said: %@", @"message of panel when table cannot be renamed"),
							  [mySQLConnection getLastErrorMessage]]);
		}
	}
}

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
		
		if ( [[tables objectAtIndex:[tablesListView selectedRow]] isEqualToString:@""] ) {
			//user added new table and then pressed escape
			[tableTypes removeObjectAtIndex:[tablesListView selectedRow]];
			[tables removeObjectAtIndex:[tablesListView selectedRow]];
			[tablesListView reloadData];
		}
		
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
	if ( [tablesListView numberOfSelectedRows] == 1 && [[self tableName] length] ) {
		
		// Reset the table information caches
		[tableDataInstance resetAllData];

		if( [[tableTypes objectAtIndex:[tablesListView selectedRow]] intValue] == SP_TABLETYPE_VIEW ||
		   [[tableTypes objectAtIndex:[tablesListView selectedRow]] intValue] == SP_TABLETYPE_TABLE) {
			// If encoding is set to Autodetect, update the connection character set encoding
			// based on the newly selected table's encoding - but only if it differs from the current encoding.
			if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultEncoding"] isEqualToString:@"Autodetect"]) {
				if (![[tableDataInstance tableEncoding] isEqualToString:[tableDocumentInstance connectionEncoding]]) {
					[tableDocumentInstance setConnectionEncoding:[tableDataInstance tableEncoding] reloadingViews:NO];
					[tableDataInstance resetAllData];
				}
			}
		
			if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 0 ) {
				[tableSourceInstance loadTable:[tables objectAtIndex:[tablesListView selectedRow]]];
				structureLoaded = YES;
				contentLoaded = NO;
				statusLoaded = NO;
			} else if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 1 ) {
				[tableContentInstance loadTable:[tables objectAtIndex:[tablesListView selectedRow]]];
				structureLoaded = NO;
				contentLoaded = YES;
				statusLoaded = NO;
			} else if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 3 ) {
				[tableStatusInstance loadTable:[tables objectAtIndex:[tablesListView selectedRow]]];
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
			[tableStatusInstance loadTable:nil];
			structureLoaded = NO;
			contentLoaded = NO;
			statusLoaded = NO;			
		}
			
		// Set gear menu items Remove/Duplicate table/view and mainMenu > Table items
		// according to the table types
		if([[tableTypes objectAtIndex:[tablesListView selectedRow]] intValue] == SP_TABLETYPE_VIEW)
		{
			// Change mainMenu > Table > ... according to table type
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:0] setTitle:NSLocalizedString(@"Copy Create View Syntax", @"copy create view syntax menu item")];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:1] setTitle:NSLocalizedString(@"Show Create View Syntax", @"show create view syntax menu item")];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:2] setHidden:NO]; // divider
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:3] setHidden:NO]; // copy columns
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:4] setHidden:NO]; // divider
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:5] setTitle:NSLocalizedString(@"Check View", @"check view menu item")];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:6] setHidden:YES]; // repair
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:7] setHidden:YES]; // divider
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:8] setHidden:YES]; // analyse
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:9] setHidden:YES]; // optimize
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:10] setTitle:NSLocalizedString(@"Flush View", @"flush view menu item")];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:11] setHidden:YES]; // checksum

			[removeTableMenuItem setTitle:NSLocalizedString(@"Remove view", @"remove view menu title")];
			[duplicateTableMenuItem setTitle:NSLocalizedString(@"Duplicate view", @"duplicate view menu title")];
		} 
		else if([[tableTypes objectAtIndex:[tablesListView selectedRow]] intValue] == SP_TABLETYPE_TABLE) {
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:0] setTitle:NSLocalizedString(@"Copy Create Table Syntax", @"copy create table syntax menu item")];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:1] setTitle:NSLocalizedString(@"Show Create Table Syntax", @"show create table syntax menu item")];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:2] setHidden:NO]; // divider
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:3] setHidden:NO]; // copy columns
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:4] setHidden:NO]; // divider
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:5] setTitle:NSLocalizedString(@"Check Table", @"check table menu item")];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:6] setHidden:NO];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:7] setHidden:NO]; // divider
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:8] setHidden:NO];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:9] setHidden:NO];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:10] setTitle:NSLocalizedString(@"Flush Table", @"flush table menu item")];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:11] setHidden:NO];

			[removeTableMenuItem setTitle:NSLocalizedString(@"Remove table", @"remove table menu title")];
			[duplicateTableMenuItem setTitle:NSLocalizedString(@"Duplicate table", @"duplicate table menu title")];
		} 
		else if([[tableTypes objectAtIndex:[tablesListView selectedRow]] intValue] == SP_TABLETYPE_PROC) {
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:0] setTitle:NSLocalizedString(@"Copy Create Procedure Syntax", @"copy create proc syntax menu item")];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:1] setTitle:NSLocalizedString(@"Show Create Procedure Syntax", @"show create proc syntax menu item")];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:2] setHidden:YES]; // divider
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:3] setHidden:YES]; // copy columns
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:4] setHidden:YES]; // divider
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:5] setHidden:YES];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:6] setHidden:YES];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:7] setHidden:YES]; // divider
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:8] setHidden:YES];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:9] setHidden:YES];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:10] setHidden:YES];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:11] setHidden:YES];
			
			[removeTableMenuItem setTitle:NSLocalizedString(@"Remove procedure", @"remove proc menu title")];
			[duplicateTableMenuItem setTitle:NSLocalizedString(@"Duplicate procedure", @"duplicate proc menu title")];
		}
		else if([[tableTypes objectAtIndex:[tablesListView selectedRow]] intValue] == SP_TABLETYPE_FUNC) {
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:0] setTitle:NSLocalizedString(@"Copy Create Function Syntax", @"copy create func syntax menu item")];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:1] setTitle:NSLocalizedString(@"Show Create Function Syntax", @"show create func syntax menu item")];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:2] setHidden:YES]; // divider
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:3] setHidden:YES]; // copy columns
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:4] setHidden:YES]; // divider
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:5] setHidden:YES];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:6] setHidden:YES];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:7] setHidden:YES]; // divider
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:8] setHidden:YES];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:9] setHidden:YES];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:10] setHidden:YES];
			[[[[[NSApp mainMenu] itemAtIndex:5] submenu] itemAtIndex:11] setHidden:YES];
			
			[removeTableMenuItem setTitle:NSLocalizedString(@"Remove function", @"remove func menu title")];
			[duplicateTableMenuItem setTitle:NSLocalizedString(@"Duplicate function", @"duplicate func menu title")];
		}
		// set window title
		[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/%@/%@", [tableDocumentInstance mySQLVersion],
									[tableDocumentInstance name], [tableDocumentInstance database], [tables objectAtIndex:[tablesListView selectedRow]]]];
	} else {
		[tableSourceInstance loadTable:nil];
		[tableContentInstance loadTable:nil];
		[tableStatusInstance loadTable:nil];
		structureLoaded = NO;
		contentLoaded = NO;
		statusLoaded = NO;

		// Set gear menu items Remove/Duplicate table/view according to the table types
		NSIndexSet *indexes = [tablesListView selectedRowIndexes];
		unsigned currentIndex = [indexes lastIndex];
		int tblTypesChecksum = 0;
		while (currentIndex != NSNotFound)
		{
			tblTypesChecksum += [[tableTypes objectAtIndex:currentIndex] intValue];
			currentIndex = [indexes indexLessThanIndex:currentIndex];
		}
		if(tblTypesChecksum == 0)
			[removeTableMenuItem setTitle:NSLocalizedString(@"Remove tables", @"remove tables menu title")];
		else if(tblTypesChecksum == [indexes count])
			[removeTableMenuItem setTitle:NSLocalizedString(@"Remove views", @"remove views menu title")];
		else
			[removeTableMenuItem setTitle:NSLocalizedString(@"Remove tables/views", @"remove tables/views menu title")];

		// set window title
		[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@/%@", [tableDocumentInstance mySQLVersion],
									[tableDocumentInstance name], [tableDocumentInstance database]]];
	}	
}

/**
 * Table view delegate method
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(int)rowIndex
{
	//return (rowIndex != 0);
	if( [tableTypes count] == 0 )
		return (rowIndex != 0 );
	return ([[tableTypes objectAtIndex:rowIndex] intValue] != SP_TABLETYPE_NONE );
}

/**
 * Table view delegate method
 */
- (BOOL)tableView:(NSTableView *)aTableView isGroupRow:(int)rowIndex
{
	//return (row == 0);	
	if( [tableTypes count] == 0 )
		return (rowIndex == 0 );
	return ([[tableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_NONE );
}

/**
 * Table view delegate method
 */
- (void)tableView:(NSTableView *)aTableView  willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if (rowIndex > 0 && [[aTableColumn identifier] isEqualToString:@"tables"]) {
		if ([[tableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_VIEW) {
			[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"table-view-small"]];
		} else if ([[tableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_TABLE) { 
			[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"table-small"]];
		} else if ([[tableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_PROC) { 
			[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"proc-small"]];
		} else if ([[tableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_FUNC) { 
			[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"func-small"]];
		}
	
		if ([[tableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_NONE) {
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

#pragma mark TabView delegate methods

/**
 * Loads structure or source if tab selected the first time
 */
- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if ( [tablesListView numberOfSelectedRows] == 1  && 
		([self tableType] == SP_TABLETYPE_TABLE || [self tableType] == SP_TABLETYPE_VIEW) ) {
		
		if ( ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 0) && !structureLoaded ) {
			[tableSourceInstance loadTable:[tables objectAtIndex:[tablesListView selectedRow]]];
			structureLoaded = YES;
		}
		
		if ( ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 1) && !contentLoaded ) {
			[tableContentInstance loadTable:[tables objectAtIndex:[tablesListView selectedRow]]];
			contentLoaded = YES;
		}
		
		if ( ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 3) && !statusLoaded ) {
			[tableStatusInstance loadTable:[tables objectAtIndex:[tablesListView selectedRow]]];
			statusLoaded = YES;
		}
	}
	else {
		[tableSourceInstance loadTable:nil];
		[tableContentInstance loadTable:nil];
	}
}

/**
 * Menu item interface validation
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// popup button below table list
	if ([menuItem action] == @selector(copyTable:))
	{
		if( [self tableType] == SP_TABLETYPE_FUNC || [self tableType] == SP_TABLETYPE_PROC )
			return NO;
		return [tablesListView numberOfSelectedRows] == 1 && [[self tableName] length] && [tablesListView numberOfSelectedRows] > 0;
	}
	if ([menuItem action] == @selector(removeTable:))
	{
		return [tablesListView numberOfSelectedRows] > 0;
	}
	
	return [super validateMenuItem:menuItem];
}		

#pragma mark Other

/**
 * Standard init method. Performs various ivar initialisations. 
 */
- (id)init
{
	if ((self = [super init])) {
		tables = [[NSMutableArray alloc] init];
		tableTypes = [[NSMutableArray alloc] init];
		structureLoaded = NO;
		contentLoaded = NO;
		statusLoaded = NO;
		[tables addObject:NSLocalizedString(@"TABLES",@"header for table list")];
	}
	
	return self;
}

/**
 * Standard dealloc method.
 */
- (void)dealloc
{	
	[tables release], tables = nil;
	[tableTypes release], tableTypes = nil;
	
	[super dealloc];
}

@end
