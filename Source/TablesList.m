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

@implementation TablesList


#pragma mark IBAction methods

/*
loads all table names in array tables and reload the tableView
*/
- (IBAction)updateTables:(id)sender
{
	CMMCPResult *theResult;
	NSArray *resultRow;
	int i;
	BOOL containsViews = NO;

	[tablesListView deselectAll:self];
	[tables removeAllObjects];
	[tableTypes removeAllObjects];
	[tableTypes addObject:[NSNumber numberWithInt:-1]];

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
	}

	if (containsViews) {
		[tables insertObject:NSLocalizedString(@"TABLES & VIEWS",@"header for table & views list") atIndex:0];
	} else {
		[tables insertObject:NSLocalizedString(@"TABLES",@"header for table list") atIndex:0];
	}

	// Notify listeners that the query has finished
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];

	[tablesListView reloadData];	
}

/*
adds a new table to the tables-array (no changes in mysql-db)
*/
- (IBAction)addTable:(id)sender
{
	if ( ![tableSourceInstance saveRowOnDeselect] ||
			![tableContentInstance saveRowOnDeselect] ||
			![tableDocumentInstance database] )
		return;
	[tableWindow endEditingFor:nil];

	[tables addObject:@""];
	[tableTypes addObject:[NSNumber numberWithInt:SP_TABLETYPE_TABLE]];
	[tablesListView reloadData];
	[tablesListView selectRow:[tables count]-1 byExtendingSelection:NO];
	[tablesListView editColumn:0 row:[tables count]-1 withEvent:nil select:YES];
}

/*
invoked when user hits the remove button
alert sheet to ask user if he really wants to delete the table
*/
- (IBAction)removeTable:(id)sender
{
	if ( ![tablesListView numberOfSelectedRows] )
		return;
	[tableWindow endEditingFor:nil];

	if ( [tablesListView numberOfSelectedRows] == 1 ) {
		NSBeginAlertSheet(NSLocalizedString(@"Warning", @"warning"), NSLocalizedString(@"Delete", @"delete button"), NSLocalizedString(@"Cancel", @"cancel button"), nil, tableWindow, self,
			@selector(sheetDidEnd:returnCode:contextInfo:), nil,
			@"removeRow", [NSString stringWithFormat:NSLocalizedString(@"Do you really want to delete the table %@?", @"message of panel asking for confirmation for deleting table"),
				[tables objectAtIndex:[tablesListView selectedRow]]]);
	} else {
		NSBeginAlertSheet(NSLocalizedString(@"Warning", @"warning"), NSLocalizedString(@"Delete", @"delete button"), NSLocalizedString(@"Cancel", @"cancel button"), nil, tableWindow, self,
			@selector(sheetDidEnd:returnCode:contextInfo:), nil,
			@"removeRow", [NSString stringWithFormat:NSLocalizedString(@"Do you really want to delete the selected tables?", @"message of panel asking for confirmation for deleting tables"),
				[tables objectAtIndex:[tablesListView selectedRow]]]);
	}
}

/*
copies a table, if desired with content
*/
- (IBAction)copyTable:(id)sender
{
	CMMCPResult *queryResult;
//	NSArray *fieldNames;
//	NSArray *theRow;
//	NSMutableString *rowValue = [NSMutableString string];
//	NSMutableArray *fieldValues;
	int code;
//	int rowCount, i, j;
//	BOOL errors = NO;

	if ( [tablesListView numberOfSelectedRows] != 1 )
		return;
	if ( ![tableSourceInstance saveRowOnDeselect] || ![tableContentInstance saveRowOnDeselect] ) {
		return;
	}
	[tableWindow endEditingFor:nil];

	//open copyTableSheet
	[copyTableNameField setStringValue:[NSString stringWithFormat:@"%@Copy", [tables objectAtIndex:[tablesListView selectedRow]]]];
	[copyTableContentSwitch setState:NSOffState];
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
	queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW CREATE TABLE `%@`",
					[tables objectAtIndex:[tablesListView selectedRow]]]];
	
	if ( ![queryResult numOfRows] ) {
		//error while getting table structure
        NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
                    [NSString stringWithFormat:NSLocalizedString(@"Couldn't get table information.\nMySQL said: %@", @"message of panel when table information cannot be retrieved"), [mySQLConnection getLastErrorMessage]]);

    } else {
		//insert new table name in create syntax and create new table
		NSScanner *scanner = [NSScanner alloc];
		NSString *scanString;

        [scanner initWithString:[[queryResult fetchRowAsDictionary] objectForKey:@"Create Table"]];
        [scanner scanUpToString:@"(" intoString:nil];
        [scanner scanUpToString:@"" intoString:&scanString];
        [mySQLConnection queryString:[NSString stringWithFormat:@"CREATE TABLE `%@` %@", [copyTableNameField stringValue], scanString]];
		[scanner release];
		
        if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
			//error while creating new table
            NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
                    [NSString stringWithFormat:NSLocalizedString(@"Couldn't create table.\nMySQL said: %@", @"message of panel when table cannot be created"), [mySQLConnection getLastErrorMessage]]);
        } else {
			
            if ( [copyTableContentSwitch state] == NSOnState ) {
				//copy table content
                [mySQLConnection queryString:[NSString stringWithFormat:
											  @"INSERT INTO `%@` SELECT * FROM `%@`",
											  [copyTableNameField stringValue],
											  [tables objectAtIndex:[tablesListView selectedRow]]
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
			[tableTypes insertObject:[NSNumber numberWithInt:SP_TABLETYPE_TABLE] atIndex:[tablesListView selectedRow]+1];
            [tablesListView reloadData];
            [tablesListView selectRow:[tablesListView selectedRow]+1 byExtendingSelection:NO];
            [tablesListView scrollRowToVisible:[tablesListView selectedRow]];
        }
    }
}


#pragma mark Alert sheet methods

/*
method for alert sheets
invoked when user wants to delete a table
*/
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{
	if ( [contextInfo isEqualToString:@"addRow"] ) {
		alertSheetOpened = NO;
	} else if ( [contextInfo isEqualToString:@"removeRow"] ) {
		if ( returnCode == NSAlertDefaultReturn ) {
			[sheet orderOut:self];
			[self removeTable];
		}
	}
}

/*
closes copyTableSheet and stops modal session
*/
- (IBAction)closeCopyTableSheet:(id)sender
{
	[NSApp stopModalWithCode:[sender tag]];
}

#pragma mark Additional methods

/*
removes selected table(s) from mysql-db and tableView
*/
- (void)removeTable;
{
	NSIndexSet *indexes = [tablesListView selectedRowIndexes];
	NSString *errorText;
	BOOL error = FALSE;
	
	// get last index
	unsigned currentIndex = [indexes lastIndex];
	while (currentIndex != NSNotFound)
	{
		[mySQLConnection queryString:[NSString stringWithFormat:@"DROP TABLE `%@`", [tables objectAtIndex:currentIndex]]];
		
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
	[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@@%@/%@", [tableDocumentInstance mySQLVersion], [tableDocumentInstance user],
								[tableDocumentInstance host], [tableDocumentInstance database]]];
	if ( error )
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
			[NSString stringWithFormat:NSLocalizedString(@"Couldn't remove table.\nMySQL said: %@", @"message of panel when table cannot be removed"), errorText]);
}

/*
sets the connection (received from TableDocument) and makes things that have to be done only once 
*/
- (void)setConnection:(CMMCPConnection *)theConnection
{
	mySQLConnection = theConnection;
	[self updateTables:self];
}

/*
selects customQuery tab and passes query to customQueryInstance
*/
- (void)doPerformQueryService:(NSString *)query
{
	[tabView selectTabViewItemAtIndex:2];
	[customQueryInstance doPerformQueryService:query];
}


#pragma mark Getter methods

/*
returns the currently selected table or nil if no table or mulitple tables are selected
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

- (NSArray *)tables
{
	return tables;
}

- (NSArray *)tableTypes
{
	return tableTypes;
}

/*
returns YES if table source has already been loaded
*/
- (BOOL)structureLoaded
{
	return structureLoaded;
}

/*
returns YES if table content has already been loaded
*/
- (BOOL)contentLoaded
{
	return contentLoaded;
}

/*
returns YES if table status has already been loaded
*/
- (BOOL)statusLoaded
{
	return statusLoaded;
}

#pragma mark Setter methods

/*
Mark the content table for refresh when it's next switched to
*/
- (void)setContentRequiresReload:(BOOL)reload
{
	contentLoaded = !reload;
}

#pragma mark Datasource methods

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [tables count];
}

- (id)tableView:(NSTableView *)aTableView
			objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
		return [tables objectAtIndex:rowIndex];
}

/**
 * adds or renames a table (in tables-array and mysql-db)
 * removes new table from table-array if renaming had no success
 */
- (void)tableView:(NSTableView *)aTableView
			setObjectValue:(id)anObject
			forTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
	
	if ( [[tables objectAtIndex:rowIndex] isEqualToString:@""] ) {
		//new table
		if ( [anObject isEqualToString:@""] ) {
			//table has no name
			alertSheetOpened = YES;
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self,
				@selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addRow", NSLocalizedString(@"Table must have a name.", @"message of panel when no name is given for table"));
			[tables removeObjectAtIndex:rowIndex];
			[tableTypes removeObjectAtIndex:rowIndex];
			[tablesListView reloadData];
		} else {
			if ( [tableDocumentInstance supportsEncoding] ) {
				[mySQLConnection queryString:[NSString stringWithFormat:@"CREATE TABLE `%@` (id int) DEFAULT CHARACTER SET %@", anObject, [tableDocumentInstance connectionEncoding]]];
			} else {
				[mySQLConnection queryString:[NSString stringWithFormat:@"CREATE TABLE `%@` (id int)", anObject]];
			}
			
			if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
				//added table with success
				[tables replaceObjectAtIndex:rowIndex withObject:anObject];
				
				if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 0 ) {
					[tableSourceInstance loadTable:anObject];
					structureLoaded = YES;
					contentLoaded = NO;
					statusLoaded = NO;
				} else if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 1 ) {
					[tableContentInstance loadTable:anObject];
					structureLoaded = NO;
					contentLoaded = YES;
					statusLoaded = NO;
				} else if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 3 ) {
					[tableStatusInstance loadTable:anObject];
					statusLoaded = YES;
					structureLoaded = NO;
					contentLoaded = NO;
				} else {
					statusLoaded = NO;
					structureLoaded = NO;
					contentLoaded = NO;
				}
				
				// set window title
				[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@@%@/%@/%@", [tableDocumentInstance mySQLVersion], [tableDocumentInstance user],
					[tableDocumentInstance host], [tableDocumentInstance database], anObject]];
			} else {
				
				//error while adding new table
				alertSheetOpened = YES;
				NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self,
					@selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addRow",
						[NSString stringWithFormat:NSLocalizedString(@"Couldn't add table %@.\nMySQL said: %@", @"message of panel when table cannot be created with the given name"),
							anObject, [mySQLConnection getLastErrorMessage]]);
				[tableTypes removeObjectAtIndex:rowIndex];
				[tables removeObjectAtIndex:rowIndex];
				[tablesListView reloadData];
			}
		}
	} else {
		
		//table modification
		if ( [[tables objectAtIndex:rowIndex] isEqualToString:anObject] ) {
			//no changes in table name
//			NSLog(@"no changes in table name");
		} else if ( [anObject isEqualToString:@""] ) {
			//table has no name
//			NSLog(@"name is nil");
			alertSheetOpened = YES;
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self,
				@selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addRow", NSLocalizedString(@"Table must have a name.", @"message of panel when no name is given for table"));
		} else {
			[mySQLConnection queryString:[NSString stringWithFormat:@"RENAME TABLE `%@` TO `%@`", [tables objectAtIndex:rowIndex], anObject]];
			if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
//				NSLog(@"renamed table with success");
				//renamed with success
				[tables replaceObjectAtIndex:rowIndex withObject:anObject];
				
				if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 0 ) {
					[tableSourceInstance loadTable:anObject];
					structureLoaded = YES;
					contentLoaded = NO;
					statusLoaded = NO;
				} else if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 1 ) {
					[tableContentInstance loadTable:anObject];
					structureLoaded = NO;
					contentLoaded = YES;
					statusLoaded = NO;
				} else if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 3 ) {
					[tableStatusInstance loadTable:anObject];
					structureLoaded = NO;
					contentLoaded = NO; 			
					statusLoaded = YES;
				} else {
					statusLoaded = NO;
					structureLoaded = NO;
					contentLoaded = NO;
				}
				
				// set window title
				[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@@%@/%@/%@", [tableDocumentInstance mySQLVersion], [tableDocumentInstance user],
					[tableDocumentInstance host], [tableDocumentInstance database], anObject]];
			} else {
				//error while renaming
//				NSLog(@"couldn't rename table");
				alertSheetOpened = YES;
				NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self,
					@selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addRow",
						[NSString stringWithFormat:NSLocalizedString(@"Couldn't rename table.\nMySQL said: %@", @"message of panel when table cannot be renamed"),
							[mySQLConnection getLastErrorMessage]]);
			}
		}
	}
}

#pragma mark TableView delegate methods

/*
traps enter and esc and edit/cancel without entering next row
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

- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView
{
/*
	int row = [tablesListView editedRow];
	int column = [tablesListView editedColumn];
	NSTableColumn *tableColumn;
	NSCell *cell;

	if ( row != -1 ) {
		tableColumn = [[tablesListView tableColumns] objectAtIndex:column]; 
		cell = [tableColumn dataCellForRow:row]; 
	[cell endEditing:[tablesListView currentEditor]]; 
	}
*/
	//end editing (otherwise problems when user hits reload button)
	[tableWindow endEditingFor:nil];
	if ( alertSheetOpened ) {
		return NO;
	}

	//we have to be sure that TableSource and TableContent have finished editing
//	if ( ![tableSourceInstance addRowToDB] || ![tableContentInstance addRowToDB] ) {
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

		// If encoding is set to Autodetect, update the connection character set encoding
		// based on the newly selected table's encoding - but only if it differs from the current encoding.
		if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"encoding"] isEqualToString:@"Autodetect"]) {
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
		 
		// set window title
		[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@@%@/%@/%@", [tableDocumentInstance mySQLVersion], [tableDocumentInstance user],
									[tableDocumentInstance host], [tableDocumentInstance database], [tables objectAtIndex:[tablesListView selectedRow]]]];
	} else {
		[tableSourceInstance loadTable:nil];
		[tableContentInstance loadTable:nil];
		[tableStatusInstance loadTable:nil];
		structureLoaded = NO;
		contentLoaded = NO;
		statusLoaded = NO;
		
		// set window title
		[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@@%@/%@", [tableDocumentInstance mySQLVersion], [tableDocumentInstance user],
									[tableDocumentInstance host], [tableDocumentInstance database]]];
	}	
}

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(int)rowIndex
{
	return (rowIndex != 0);
}


- (BOOL)tableView:(NSTableView *)aTableView isGroupRow:(int)row
{
	return (row == 0);	
}

- (void)tableView:(NSTableView *)aTableView 
  willDisplayCell:(id)aCell 
   forTableColumn:(NSTableColumn *)aTableColumn 
			  row:(int)rowIndex
{
	if (rowIndex > 0 && [[aTableColumn identifier] isEqualToString:@"tables"]) {
		if ([[tableTypes objectAtIndex:rowIndex] intValue] == SP_TABLETYPE_VIEW) {
			[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"table-view-small"]];
		} else {
			[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"table-small"]];
		}
		
		[(ImageAndTextCell*)aCell setIndentationLevel:1];
		[(ImageAndTextCell*)aCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		
	} else {
		[(ImageAndTextCell*)aCell setImage:nil];
		[(ImageAndTextCell*)aCell setIndentationLevel:0];
	}
}

- (float)tableView:(NSTableView *)tableView heightOfRow:(int)row
{
	if (row == 0) {
		return 25;
	} else {
		return 17;
	}
}

#pragma mark -
#pragma mark TabView delegate methods

/*
loads structure or source if tab selected the first time
*/
- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if ( [tablesListView numberOfSelectedRows] == 1 ) {
		
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
/*
	if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 3 ) {
		[tableDumpInstance reloadTables:self];
	}
*/
}

#pragma mark -
//last but not least
- (id)init
{
	self = [super init];
	
	tables = [[NSMutableArray alloc] init];
	tableTypes = [[NSMutableArray alloc] init];
	structureLoaded = NO;
	contentLoaded = NO;
	statusLoaded = NO;
	[tables addObject:NSLocalizedString(@"TABLES",@"header for table list")];
	return self;
}

- (void)dealloc
{
//	NSLog(@"TableList dealloc");
	
	[tables release];
	[tableTypes release];
	
	[super dealloc];
}


@end
