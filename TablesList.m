//
//  TablesList.m
//  CocoaMySQL
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
//  More info at <http://cocoamysql.sourceforge.net/>
//  Or mail to <lorenz@textor.ch>

#import "TablesList.h"
#import "TableDocument.h"
#import "TableSource.h"
#import "TableContent.h"
#import "TableDump.h"


@implementation TablesList

//IBAction methods
- (IBAction)updateTables:(id)sender
/*
loads all table names in array tables and reload the tableView
*/
{
    CMMCPResult *theResult;
    int i;

    //query started
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];

    [tablesListView deselectAll:self];
    [tables removeAllObjects];

    theResult = [mySQLConnection listTables];
    for ( i = 0 ; i < [theResult numOfRows] ; i++ ) {
        [theResult dataSeek:i];
        [tables addObject:[[theResult fetchRowAsArray] objectAtIndex:0]];
    }
    [tablesListView reloadData];
    
    //query finished
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
}

- (IBAction)addTable:(id)sender
/*
adds a new table to the tables-array (no changes in mysql-db)
*/
{
    if ( ![tableSourceInstance selectionShouldChangeInTableView:nil] ||
            ![tableContentInstance selectionShouldChangeInTableView:nil] ||
            ![tableDocumentInstance database] )
        return;
    [tableWindow endEditingFor:nil];

    [tables addObject:@""];
    [tablesListView reloadData];
    [tablesListView selectRow:[tables count]-1 byExtendingSelection:NO];
    [tablesListView editColumn:0 row:[tables count]-1 withEvent:nil select:YES];
}

- (IBAction)removeTable:(id)sender
/*
invoked when user hits the remove button
alert sheet to ask user if he really wants to delete the table
*/
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

- (IBAction)copyTable:(id)sender
/*
copies a table, if desired with content
*/
{
    CMMCPResult *queryResult;
    NSScanner *scanner = [NSScanner alloc];
    NSString *scanString;
//    NSArray *fieldNames;
//    NSArray *theRow;
//    NSMutableString *rowValue = [NSMutableString string];
//    NSMutableArray *fieldValues;
    int code;
//    int rowCount, i, j;
//    BOOL errors = NO;

    if ( [tablesListView numberOfSelectedRows] != 1 )
        return;
    if ( ![tableSourceInstance selectionShouldChangeInTableView:nil] || ![tableContentInstance selectionShouldChangeInTableView:nil] )
        return;
    [tableWindow endEditingFor:nil];

//open copyTableSheet
    [copyTableNameField setStringValue:[NSString stringWithFormat:@"%@Copy", [tables objectAtIndex:[tablesListView selectedRow]]]];
    [copyTableContentSwitch setState:NSOffState];
    [NSApp beginSheet:copyTableSheet
            modalForWindow:tableWindow modalDelegate:self
            didEndSelector:nil contextInfo:nil];
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
        [scanner initWithString:[[queryResult fetchRowAsDictionary] objectForKey:@"Create Table"]];
        [scanner scanUpToString:@"(" intoString:nil];
        [scanner scanUpToString:@"" intoString:&scanString];
        [mySQLConnection queryString:[NSString stringWithFormat:@"CREATE TABLE `%@` %@", [copyTableNameField stringValue], scanString]];
        if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
//error while creating new table
            NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
                    [NSString stringWithFormat:NSLocalizedString(@"Couldn't create table.\nMySQL said: %@", @"message of panel when table cannot be created"), [mySQLConnection getLastErrorMessage]]);
        } else {
            if ( [copyTableContentSwitch state] == NSOnState ) {
//copy table content
/*
                queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SELECT * FROM `%@`",
                                    [tables objectAtIndex:[tablesListView selectedRow]]]];
                fieldNames = [queryResult fetchFieldNames];
                rowCount = [queryResult numOfRows];
                for ( i = 0 ; i < rowCount ; i++ ) {
                    [queryResult dataSeek:i];
                    theRow = [queryResult fetchRowAsArray];
                    fieldValues = [NSMutableArray array];
                    for ( j = 0 ; j < [theRow count] ; j++ ) {
                        if ( [[theRow objectAtIndex:j] isKindOfClass:[NSData class]] ) {
//                            [rowValue setString:[[NSString alloc] initWithData:[theRow objectAtIndex:j]
//                                    encoding:[mySQLConnection encoding]]];
                            [rowValue setString:[mySQLConnection prepareBinaryData:[theRow objectAtIndex:j]]];
                        } else {
                            [rowValue setString:[mySQLConnection prepareString:[[theRow objectAtIndex:j] description]]];
                        }
*/
/*
                        //escape special characters
                        for ( u = 0 ; u < [rowValue length] ; u++ ) {
                            if ( [rowValue characterAtIndex:u] == '\\' ) {
                                [rowValue insertString:@"\\" atIndex:u];
                                u++;
                            } else if ( [rowValue characterAtIndex:u] == '"' ) {
                                [rowValue insertString:@"\\" atIndex:u];
                                u++;
                            }
                        }
*/
/*
                        if ( [[theRow objectAtIndex:j] isKindOfClass:[NSNull class]] ) {
                            [fieldValues addObject:@"NULL"];
                        } else {
//                            [fieldValues addObject:[NSString stringWithFormat:@"\"%@\"", [mySQLConnection prepareString:rowValue]]];
//                            [fieldValues addObject:[NSString stringWithFormat:@"\"%@\"", rowValue]];
//                            [fieldValues addObject:[NSString stringWithFormat:@"'%@'", [mySQLConnection prepareString:rowValue]]];
                            [fieldValues addObject:[NSString stringWithFormat:@"'%@'", rowValue]];

                        }
                    }
                    [mySQLConnection queryString:[NSString stringWithFormat:@"INSERT INTO `%@` (`%@`) VALUES (%@)",
                        [copyTableNameField stringValue], [fieldNames componentsJoinedByString:@"`,`"],
                        [fieldValues componentsJoinedByString:@","]]];
                    if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
                        errors = YES;
                    }
                }
                if ( errors )
                    NSBeginAlertSheet(@"Warning", @"OK", nil, nil, tableWindow, self, nil, nil, nil,
                            @"There have been errors while copying table content. Please control the new table.");
*/
                [mySQLConnection queryString:[NSString stringWithFormat:@"INSERT INTO `%@` SELECT * FROM `%@`",
                    [copyTableNameField stringValue], [tables objectAtIndex:[tablesListView selectedRow]]]];
                if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
                    NSBeginAlertSheet(NSLocalizedString(@"Warning", @"warning"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
                            NSLocalizedString(@"There have been errors while copying table content. Please control the new table.", @"message of panel when table content cannot be copied"));
                }
            }
            [tables insertObject:[copyTableNameField stringValue] atIndex:[tablesListView selectedRow]+1];
            [tablesListView reloadData];
            [tablesListView selectRow:[tablesListView selectedRow]+1 byExtendingSelection:NO];
            [tablesListView scrollRowToVisible:[tablesListView selectedRow]];
        }
    }
}


//alert sheet methods
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
/*
method for alert sheets
invoked when user wants to delete a table
*/
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

//copyTableSheet methods
- (IBAction)closeCopyTableSheet:(id)sender
/*
closes copyTableSheet and stops modal session
*/
{
    [NSApp stopModalWithCode:[sender tag]];
}

//additional methods
- (void)removeTable;
/*
removes selected table(s) from mysql-db and tableView
*/
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
		} else {
	//couldn't drop table
			error = TRUE;
			errorText = [mySQLConnection getLastErrorMessage];
		}
		// get next index (beginning from the end)
        currentIndex = [indexes indexLessThanIndex:currentIndex];
    }
	[tablesListView deselectAll:self];
//	[tableSourceInstance loadTable:nil];
//	[tableContentInstance loadTable:nil];
//	[tableStatusInstance loadTable:nil];
	[tablesListView reloadData];
	// set window title
	[tableWindow setTitle:[NSString stringWithFormat:@"(MySQL %@) %@@%@/%@", [tableDocumentInstance mySQLVersion], [tableDocumentInstance user],
								[tableDocumentInstance host], [tableDocumentInstance database]]];
	if ( error )
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
			[NSString stringWithFormat:NSLocalizedString(@"Couldn't remove table.\nMySQL said: %@", @"message of panel when table cannot be removed"), errorText]);
}

- (void)setConnection:(CMMCPConnection *)theConnection
/*
sets the connection (received from TableDocument) and makes things that have to be done only once 
*/
{
    mySQLConnection = theConnection;

//    prefs = [[NSUserDefaults standardUserDefaults] retain];

//set smallSystemFonts
//    [[[tablesListView tableColumnWithIdentifier:@"tables"] dataCell] setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
//    [copyTableNameField setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
//    if ( [prefs boolForKey:@"useMonospacedFonts"] ) {
    if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"useMonospacedFonts"] ) {
        [[[tablesListView tableColumnWithIdentifier:@"tables"] dataCell]
                setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
    }

    [self updateTables:self];
}

- (void)doPerformQueryService:(NSString *)query
/*
selects customQuery tab and passes query to customQueryInstance
*/
{
    [tabView selectTabViewItemAtIndex:2];
    [customQueryInstance doPerformQueryService:query];
}


//getter methods
- (NSString *)table
/*
returns the currently selected table or nil if no table or mulitple tables are selected
*/
{
    if ( [tablesListView numberOfSelectedRows] == 1 ) {
        return [tables objectAtIndex:[tablesListView selectedRow]];
    } else {
        return nil;
    }
}

- (BOOL)structureLoaded
/*
returns YES if table source has already been loaded
*/
{
    return structureLoaded;
}

- (BOOL)contentLoaded
/*
returns YES if table content has already been loaded
*/
{
    return contentLoaded;
}

- (BOOL)statusLoaded
/*
returns YES if table status has already been loaded
*/
{
    return statusLoaded;
}


//tableView datasource methods
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

- (void)tableView:(NSTableView *)aTableView
            setObjectValue:(id)anObject
            forTableColumn:(NSTableColumn *)aTableColumn
            row:(int)rowIndex
/*
adds or renames a table (in tables-array and mysql-db)
removes new table from table-array if renaming had no success
*/
{
    if ( [[tables objectAtIndex:rowIndex] isEqualToString:@""] ) {
//new table
        if ( [anObject isEqualToString:@""] ) {
    //table has no name
            alertSheetOpened = YES;
            NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self,
                @selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addRow", NSLocalizedString(@"Table must have a name.", @"message of panel when no name is given for table"));
            [tables removeObjectAtIndex:rowIndex];
            [tablesListView reloadData];
        } else {
			if ( [tableDocumentInstance supportsEncoding] ) {
				[mySQLConnection queryString:[NSString stringWithFormat:@"CREATE TABLE `%@` (id int) DEFAULT CHARACTER SET %@", anObject, [tableDocumentInstance getSelectedEncoding]]];
            } else {
				[mySQLConnection queryString:[NSString stringWithFormat:@"CREATE TABLE `%@` (id int)", anObject]];
			}
			if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
    //added table with success
//                NSLog(@"added new table with success");
                [tables replaceObjectAtIndex:rowIndex withObject:anObject];
                if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 0 ) {
                    [tableSourceInstance loadTable:anObject];
                    structureLoaded = YES;
                    contentLoaded = NO;
                    statusLoaded = NO;
                } else if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 1 ) {
                    [tableSourceInstance loadTable:anObject];
                    [tableContentInstance loadTable:anObject];
                    structureLoaded = YES;
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
//                NSLog(@"couldn't add new table");
                alertSheetOpened = YES;
                NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self,
                    @selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addRow",
                    [NSString stringWithFormat:NSLocalizedString(@"Couldn't add table %@.\nMySQL said: %@", @"message of panel when table cannot be created with the given name"),
                        anObject, [mySQLConnection getLastErrorMessage]]);
                [tables removeObjectAtIndex:rowIndex];
                [tablesListView reloadData];
            }
        }
    } else {
//table modification
        if ( [[tables objectAtIndex:rowIndex] isEqualToString:anObject] ) {
    //no changes in table name
//            NSLog(@"no changes in table name");
        } else if ( [anObject isEqualToString:@""] ) {
    //table has no name
//            NSLog(@"name is nil");
            alertSheetOpened = YES;
            NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self,
                @selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addRow", NSLocalizedString(@"Table must have a name.", @"message of panel when no name is given for table"));
        } else {
            [mySQLConnection queryString:[NSString stringWithFormat:@"RENAME TABLE `%@` TO `%@`", [tables objectAtIndex:rowIndex], anObject]];
            if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
//                NSLog(@"renamed table with success");
    //renamed with success
                [tables replaceObjectAtIndex:rowIndex withObject:anObject];
                if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 0 ) {
                    [tableSourceInstance loadTable:anObject];
                    structureLoaded = YES;
                    contentLoaded = NO;
                    statusLoaded = NO;
                } else if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 1 ) {
                    [tableSourceInstance loadTable:anObject];
                    [tableContentInstance loadTable:anObject];
                    structureLoaded = YES;
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
//                NSLog(@"couldn't rename table");
                alertSheetOpened = YES;
                NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self,
                    @selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addRow",
                    [NSString stringWithFormat:NSLocalizedString(@"Couldn't rename table.\nMySQL said: %@", @"message of panel when table cannot be renamed"),
                        [mySQLConnection getLastErrorMessage]]);
            }
        }
    }
}

//tableView delegate methods
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
/*
traps enter and esc and edit/cancel without entering next row
*/
{
     if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(insertNewline:)] ) //trap enter
     {
        //save current line
        [[control window] makeFirstResponder:control];
        return TRUE;
     }
     else if ( [[control window] methodForSelector:command] == [[control window] methodForSelector:@selector(_cancelKey:)] ||
					[textView methodForSelector:command] == [textView methodForSelector:@selector(complete:)] )  //trap esc
     {
        //abort editing
        [control abortEditing];
        if ( [[tables objectAtIndex:[tablesListView selectedRow]] isEqualToString:@""] ) {
            //user added new table and then pressed escape
            [tables removeObjectAtIndex:[tablesListView selectedRow]];
            [tablesListView reloadData];
        }
        return TRUE;
     }
     else
     {
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
//    if ( ![tableSourceInstance addRowToDB] || ![tableContentInstance addRowToDB] ) {
    if ( ![tableSourceInstance selectionShouldChangeInTableView:nil] ||
                        ![tableContentInstance selectionShouldChangeInTableView:nil] ) {
        return NO;
    } else {
        return YES;
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
/*
loads a table in content or source view (if tab selected)
*/
{
     if ( [tablesListView numberOfSelectedRows] == 1 ) {
        if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 0 ) {
            [tableSourceInstance loadTable:[tables objectAtIndex:[tablesListView selectedRow]]];
            structureLoaded = YES;
            contentLoaded = NO;   
            statusLoaded = NO;
        } else if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 1 ) {
            [tableSourceInstance loadTable:[tables objectAtIndex:[tablesListView selectedRow]]];
            [tableContentInstance loadTable:[tables objectAtIndex:[tablesListView selectedRow]]];
            structureLoaded = YES;
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

//tabView delegate methods
- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
/*
loads structure or source if tab selected the first time
*/
{
    if ( [tablesListView numberOfSelectedRows] == 1 )
    {
        if ( ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 0) && !structureLoaded )
        {
            [tableSourceInstance loadTable:[tables objectAtIndex:[tablesListView selectedRow]]];
            structureLoaded = YES;
        }
        if ( ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 1) && !contentLoaded )
        {
            if ( !structureLoaded ) {
                [tableSourceInstance loadTable:[tables objectAtIndex:[tablesListView selectedRow]]];
                structureLoaded = YES;
            }
            [tableContentInstance loadTable:[tables objectAtIndex:[tablesListView selectedRow]]];
            contentLoaded = YES;
        }
        if ( ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 3) && !statusLoaded )
        {
            [tableStatusInstance loadTable:[tables objectAtIndex:[tablesListView selectedRow]]];
            statusLoaded = YES;
        }
    }
/*
    if ( [tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 3 )
    {
        [tableDumpInstance reloadTables:self];
    }
*/
}


//last but not least
- (id)init
{
    self = [super init];
    
    tables = [[NSMutableArray alloc] init];
    structureLoaded = NO;
    contentLoaded = NO;

    return self;
}

- (void)dealloc
{
//    NSLog(@"TableList dealloc");
    
    [tables release];
    
    [super dealloc];
}


@end
