//
//  TableSource.m
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

#import "TableSource.h"
#import "TablesList.h"


@implementation TableSource

/*
loads aTable, put it in an array, update the tableViewColumns and reload the tableView
*/
- (void)loadTable:(NSString *)aTable
{
	NSEnumerator *enumerator;
	id field;
	NSScanner *scanner = [NSScanner alloc];
	NSArray *extrasArray;
	NSMutableDictionary *tempDefaultValues;
	NSEnumerator *extrasEnumerator;
	id extra;
	int i;
  
	selectedTable = aTable;
	[tableSourceView deselectAll:self];
	
	if ( isEditingRow )
		return;
  
	// empty variables
	[enumFields removeAllObjects];
  
	//query started
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];
  
	if ( [aTable isEqualToString:@""] || !aTable ) {
		[tableFields removeAllObjects];
		[indexes removeAllObjects];
		[tableSourceView reloadData];
		[indexView reloadData];
		[addFieldButton setEnabled:NO];
		[copyFieldButton setEnabled:NO];
		[removeFieldButton setEnabled:NO];
		[addIndexButton setEnabled:NO];
		[removeIndexButton setEnabled:NO];

		// set the table type menu back to the default, and disable it
		[tableTypeButton selectItemAtIndex:0];
		[tableTypeButton setEnabled:NO];
		tableType = nil;

		//query finished
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];

		[scanner release];

		return;
	}
	
	//perform queries and load results in array (each row as a dictionary)
	tableSourceResult = [[mySQLConnection queryString:[NSString stringWithFormat:@"SHOW COLUMNS FROM `%@`", selectedTable]] retain];
	
	// listFieldsFromTable is broken in the current version of the framework (no back-ticks for table name)!
	//	tableSourceResult = [[mySQLConnection listFieldsFromTable:selectedTable] retain];
	//	[tableFields setArray:[[self fetchResultAsArray:tableSourceResult] retain]];
	[tableFields setArray:[self fetchResultAsArray:tableSourceResult]];
	[tableSourceResult release];

	indexResult = [[mySQLConnection queryString:[NSString stringWithFormat:@"SHOW INDEX FROM `%@`", selectedTable]] retain];
	//	[indexes setArray:[[self fetchResultAsArray:indexResult] retain]];
	[indexes setArray:[self fetchResultAsArray:indexResult]];
	[indexResult release];
	
	CMMCPResult *tableStatusResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW TABLE STATUS LIKE '%@'", selectedTable]];
	[tableType release];
	
	NSDictionary *tempRow = [tableStatusResult fetchRowAsDictionary];
	if ( [tempRow objectForKey:@"Type"]) {
		tableType = [tempRow objectForKey:@"Type"];
	} else {
		tableType = [tempRow objectForKey:@"Engine"];
	}
	[tableType retain];
	
	//get table default values
	if ( defaultValues ) {
		[defaultValues release];
		defaultValues = nil;
	}
	
	tempDefaultValues = [NSMutableDictionary dictionary];
	for ( i = 0 ; i < [tableFields count] ; i++ ) {
		[tempDefaultValues setObject:[[tableFields objectAtIndex:i] objectForKey:@"Default"] forKey:[[tableFields objectAtIndex:i] objectForKey:@"Field"]];
	}
	defaultValues = [[NSDictionary dictionaryWithDictionary:tempDefaultValues] retain];
	
	//put field length and extras in separate key
	enumerator = [tableFields objectEnumerator];
	
	while ( (field = [enumerator nextObject]) ) {
		NSString *type;
		NSString *length;
		NSString *extras;
		
		// scan for length and extras like unsigned
		[scanner initWithString:[field objectForKey:@"Type"]];
		[scanner scanUpToString:@"(" intoString:&type];
		[scanner scanString:@"(" intoString:nil];
		
		if ( ![scanner scanUpToString:@")" intoString:&length] )
			length = @"";
		
		[scanner scanString:@")" intoString:nil];
		if ( ![scanner scanUpToString:@"" intoString:&extras] ) {
			extras = @"";
		}
		
		// get possible values if field is enum or set
		if ( [type isEqualToString:@"enum"] || [type isEqualToString:@"set"] ) {
			NSMutableArray *possibleValues = [[[length substringWithRange:NSMakeRange(1,[length length]-2)] componentsSeparatedByString:@"','"] mutableCopy];
			NSMutableString *possibleValue = [NSMutableString string];
			
			for ( i = 0 ; i < [possibleValues count] ; i++ ) {
				[possibleValue setString:[possibleValues objectAtIndex:i]];
				[possibleValue replaceOccurrencesOfString:@"''" withString:@"'" options:nil range:NSMakeRange(0,[possibleValue length])];
				[possibleValue replaceOccurrencesOfString:@"\\\\" withString:@"\\" options:nil range:NSMakeRange(0,[possibleValue length])];
				[possibleValues replaceObjectAtIndex:i withObject:[NSString stringWithString:possibleValue]];
			}
			
			[enumFields setObject:[NSArray arrayWithArray:possibleValues] forKey:[field objectForKey:@"Field"]];
			[possibleValues release];
		}
		
		// scan extras for values like unsigned, zerofill, binary
		extrasArray = [extras componentsSeparatedByString:@" "];
		extrasEnumerator = [extrasArray objectEnumerator];
		
		while ( (extra = [extrasEnumerator nextObject]) ) {
			if ( [extra isEqualToString:@"unsigned"] ) {
				[field setObject:@"1" forKey:@"unsigned"];
			} else if ( [extra isEqualToString:@"zerofill"] ) {
				[field setObject:@"1" forKey:@"zerofill"];
			} else if ( [extra isEqualToString:@"binary"] ) {
				[field setObject:@"1" forKey:@"binary"];
			} else {
				if ( ![extra isEqualToString:@""] )
					NSLog(@"ERROR: unknown option in field definition: %@", extra);
			}
		}
		
		[field setObject:type forKey:@"Type"];
		[field setObject:length forKey:@"Length"];
	}
	
	// Determine the table type
	if ( ![tableType isKindOfClass:[NSNull class]] ) {
		[tableTypeButton selectItemWithTitle:tableType];
		[tableTypeButton setEnabled:YES];
	} else {
		[tableTypeButton selectItemWithTitle:@"--"];
		[tableTypeButton setEnabled:NO];
	}
	
	//enable buttons
	[addFieldButton setEnabled:YES];
	[copyFieldButton setEnabled:YES];
	[removeFieldButton setEnabled:YES];
	[addIndexButton setEnabled:YES];
	[removeIndexButton setEnabled:YES];
	
	//add columns to indexedColumnsField
	[indexedColumnsField removeAllItems];
	enumerator = [tableFields objectEnumerator];
	
	while ( (field = [enumerator nextObject]) ) {
		[indexedColumnsField addItemWithObjectValue:[field objectForKey:@"Field"]];
	}
	
	if ( [tableFields count] < 10 ) {
		[indexedColumnsField setNumberOfVisibleItems:[tableFields count]];
	} else {
		[indexedColumnsField setNumberOfVisibleItems:10];
	}
	
	[tableSourceView reloadData];
	[indexView reloadData];
	
	// display and *then* tile to force scroll bars to be in the correct position
	[[tableSourceView enclosingScrollView] display];
	[[tableSourceView enclosingScrollView] tile];
	
	//query finished
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
	
	[scanner release];
}

/*
reloads the table (performing a new mysql-query)
*/
- (IBAction)reloadTable:(id)sender
{
	[self loadTable:selectedTable];
}


#pragma mark Edit methods

/*
adds an empty row to the tableSource-array and goes into edit mode
*/
- (IBAction)addField:(id)sender
{
/*
	if ( ![self addRowToDB] )
		return;
*/
	if ( ![self selectionShouldChangeInTableView:nil] )
		return;

	[tableFields addObject:[NSMutableDictionary
		dictionaryWithObjects:[NSArray arrayWithObjects:@"",@"int",@"",@"0",@"0",@"0",@"YES",@"",[prefs stringForKey:@"nullValue"],@"None",nil]
		forKeys:[NSArray arrayWithObjects:@"Field",@"Type",@"Length",@"unsigned",@"zerofill",@"binary",@"Null",@"Key",@"Default",@"Extra",nil]]];

	isEditingRow = YES;
	isEditingNewRow = YES;
	[tableSourceView reloadData];
	[tableSourceView selectRow:[tableSourceView numberOfRows]-1 byExtendingSelection:NO];
	[tableSourceView editColumn:0 row:[tableSourceView numberOfRows]-1 withEvent:nil select:YES];
}

/*
copies a field and goes in edit mode for the new field
*/
- (IBAction)copyField:(id)sender
{
	NSMutableDictionary *tempRow;

	if ( ![tableSourceView numberOfSelectedRows] )
		return;
	if ( ![self selectionShouldChangeInTableView:nil] )
		return;
	
	//add copy of selected row and go in edit mode
	tempRow = [NSMutableDictionary dictionaryWithDictionary:[tableFields objectAtIndex:[tableSourceView selectedRow]]];
	[tempRow setObject:[[tempRow objectForKey:@"Field"] stringByAppendingString:@"Copy"] forKey:@"Field"];
	[tempRow setObject:@"" forKey:@"Key"];
	[tempRow setObject:@"None" forKey:@"Extra"];
	[tableFields addObject:tempRow];
	isEditingRow = YES;
	isEditingNewRow = YES;
	[tableSourceView reloadData];
	[tableSourceView selectRow:[tableSourceView numberOfRows]-1 byExtendingSelection:NO];
	[tableSourceView editColumn:0 row:[tableSourceView numberOfRows]-1 withEvent:nil select:YES];
}

/*
adds the index to the mysql-db and stops modal session with code 1 when success, 0 when error and -1 when no columns specified
*/
- (IBAction)addIndex:(id)sender
{
	NSString *indexName;
	NSArray *indexedColumns;
	NSMutableArray *tempIndexedColumns = [NSMutableArray array];
	NSEnumerator *enumerator;
	NSString *string;

	if ( [[indexedColumnsField stringValue] isEqualToString:@""] ) {
		[NSApp stopModalWithCode:-1];
	} else {
		if ( [[indexNameField stringValue] isEqualToString:@"PRIMARY"] ) {
			indexName = @"";
		 } else {
			if ( [[indexNameField stringValue] isEqualToString:@""] )
			{
				indexName = @"";
			} else {
				indexName = [NSString stringWithFormat:@"`%@`", [indexNameField stringValue]];
			}
		}
		indexedColumns = [[indexedColumnsField stringValue] componentsSeparatedByString:@","];
		enumerator = [indexedColumns objectEnumerator];
		while ( (string = [enumerator nextObject]) ) {
			if ( ([string characterAtIndex:0] == ' ') ) {
				[tempIndexedColumns addObject:[string substringWithRange:NSMakeRange(1,([string length]-1))]];
			} else {
				[tempIndexedColumns addObject:[NSString stringWithString:string]];
			}
		}
		
		[mySQLConnection queryString:[NSString stringWithFormat:@"ALTER TABLE `%@` ADD %@ %@ (`%@`)",
				selectedTable, [indexTypeField titleOfSelectedItem], indexName,
				[tempIndexedColumns componentsJoinedByString:@"`,`"]]];

/*
NSLog([NSString stringWithFormat:@"ALTER TABLE `%@` ADD %@ %@ (`%@`)",
				selectedTable, [indexTypeField titleOfSelectedItem], indexName,
				[[[indexedColumnsField stringValue] componentsSeparatedByString:@","] componentsJoinedByString:@"`,`"]]);
*/

		if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
			[self loadTable:selectedTable];
			[NSApp stopModalWithCode:1];
		} else {
			[NSApp stopModalWithCode:0];
		}
	}
}

/*
opens alertsheet and asks for confirmation
*/
- (IBAction)removeField:(id)sender
{
	if ( ![tableSourceView numberOfSelectedRows] )
		return;
	if ( ![self selectionShouldChangeInTableView:nil] )
		return;

	NSBeginAlertSheet(NSLocalizedString(@"Warning", @"warning"), NSLocalizedString(@"Delete", @"delete button"), NSLocalizedString(@"Cancel", @"cancel button"), nil, tableWindow, self, @selector(sheetDidEnd:returnCode:contextInfo:),
			nil, @"removefield", [NSString stringWithFormat:NSLocalizedString(@"Do you really want to delete the field %@?", @"message of panel asking for confirmation for deleting field"),
										[[tableFields objectAtIndex:[tableSourceView selectedRow]] objectForKey:@"Field"]] );
}

/*
opens alertsheet and asks for confirmation
*/
- (IBAction)removeIndex:(id)sender
{
	if ( ![indexView numberOfSelectedRows] )
		return;
	if ( ![self selectionShouldChangeInTableView:nil] )
		return;

	NSBeginAlertSheet(NSLocalizedString(@"Warning", @"warning"), NSLocalizedString(@"Delete", @"delete button"), NSLocalizedString(@"Cancel", @"cancel button"), nil, tableWindow, self, @selector(sheetDidEnd:returnCode:contextInfo:),
			nil, @"removeindex", [NSString stringWithFormat:NSLocalizedString(@"Do you really want to delete the index %@?", @"message of panel asking for confirmation for deleting index"),
										[[indexes objectAtIndex:[indexView selectedRow]] objectForKey:@"Key_name"]] );
}

- (IBAction)typeChanged:(id)sender
{
	NSString* selectedItem = [sender titleOfSelectedItem];
	if([selectedItem isEqualToString:@"--"] || [tableType isEqualToString:selectedItem]) {
		[sender selectItemWithTitle:tableType];	
	} else {
		// alert any listeners that we are about to perform a query.
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];
		
		NSString *query = [NSString stringWithFormat:@"ALTER TABLE `%@` TYPE = %@",selectedTable,selectedItem];
		[mySQLConnection queryString:query];
		
		// The query is now complete.
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
		
		// Did the alter work?  If so, we need to record the new data.  If not, we must revert back to
		// the previous state.
		if([mySQLConnection getLastErrorID] == 0)
		{
			// Make sure "tableType" is changed and the status tab is flagged for reload...
			[tableType release];
			tableType = selectedItem;
			[tableType retain];
			
//			[[NSNotificationCenter defaultCenter] postNotificationName:@"SelectedTableStatusHasChanged" object:self];		

			// Mark the content table for refresh
			[tablesListInstance setContentRequiresReload:YES];
		} else {
			[sender selectItemWithTitle:tableType];
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
						[NSString stringWithFormat:NSLocalizedString(@"Couldn't change table type.\nMySQL said: %@", @"message of panel when table type cannot be removed"), [mySQLConnection getLastErrorMessage]]);
		}
	}
}


#pragma mark Index sheet methods

/*
opens the indexSheet
*/
- (IBAction)openIndexSheet:(id)sender
{
	int code = 0;

	if ( ![self selectionShouldChangeInTableView:nil] )
		return;

	[indexTypeField selectItemAtIndex:0];
	[indexNameField setEnabled:NO];
	[indexNameField setStringValue:@"PRIMARY"];
	[indexedColumnsField setStringValue:@""];

	[NSApp beginSheet:indexSheet
			modalForWindow:tableWindow modalDelegate:self
			didEndSelector:nil contextInfo:nil];
	code = [NSApp runModalForWindow:indexSheet];
	
	[NSApp endSheet:indexSheet];
	[indexSheet orderOut:nil];

	//code == -1 -> no columns specified
	//code == 0 -> error while adding index
	//code == 1 -> index added with succes OR sheet closed without adding index
	if ( code == 0 ) {
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
				[NSString stringWithFormat:NSLocalizedString(@"Couldn't add index.\nMySQL said: %@", @"message of panel when index cannot be created"), [mySQLConnection getLastErrorMessage]]);
	} else if ( code == -1 ) {
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, @selector(closeAlertSheet), nil,
			   NSLocalizedString(@"Please insert the columns you want to index.", @"message of panel when no columns are specified to be indexed"));
	}
}

/*
closes the indexSheet without adding the index (stops modal session with code 1)
*/
- (IBAction)closeIndexSheet:(id)sender
{
	[NSApp stopModalWithCode:1];
}

/*
invoked when user chooses an index type
*/
- (IBAction)chooseIndexType:(id)sender
{
	if ( [[indexTypeField titleOfSelectedItem] isEqualToString:@"PRIMARY KEY"] ) {
		[indexNameField setEnabled:NO];
		[indexNameField setStringValue:@"PRIMARY"];
	} else {
		[indexNameField setEnabled:YES];
		if ( [[indexNameField stringValue] isEqualToString:@"PRIMARY"] )
			[indexNameField setStringValue:@""];
	}
}

/*
reopens indexSheet after errorSheet (no columns specified)
*/
- (void)closeAlertSheet
{
	[self openIndexSheet:self];
}

/*
closes the keySheet
*/
- (IBAction)closeKeySheet:(id)sender
{
	[NSApp stopModalWithCode:[sender tag]];
}


#pragma mark Additional methods

/*
sets the connection (received from TableDocument) and makes things that have to be done only once 
*/
- (void)setConnection:(CMMCPConnection *)theConnection
{
	NSEnumerator *indexColumnsEnumerator = [[indexView tableColumns] objectEnumerator];
	NSEnumerator *fieldColumnsEnumerator = [[tableSourceView tableColumns] objectEnumerator];
	id indexColumn;
	id fieldColumn;

	mySQLConnection = theConnection;

	prefs = [[NSUserDefaults standardUserDefaults] retain];

	//set up tableView
	[tableSourceView registerForDraggedTypes:[NSArray arrayWithObjects:@"SequelProPasteboard", nil]];

	while ( (indexColumn = [indexColumnsEnumerator nextObject]) ) {
		if ( [prefs boolForKey:@"useMonospacedFonts"] ) {
			[[indexColumn dataCell] setFont:[NSFont fontWithName:@"Monaco" size:10]];
		}
		else 
		{
			[[indexColumn dataCell] setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}
	}
	while ( (fieldColumn = [fieldColumnsEnumerator nextObject]) ) {
		if ( [prefs boolForKey:@"useMonospacedFonts"] ) {
			[[fieldColumn dataCell] setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
		}
		else
		{
			[[fieldColumn dataCell] setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}
	}
}

/*
fetches the result as an array with a dictionary for each row in it
*/
- (NSArray *)fetchResultAsArray:(CMMCPResult *)theResult
{
	NSMutableArray *tempResult = [NSMutableArray array];
	NSMutableDictionary *tempRow;
	NSEnumerator *enumerator;
	id key;
	int i;

	if ([theResult numOfRows]) [theResult dataSeek:0];
	for ( i = 0 ; i < [theResult numOfRows] ; i++ ) {
		tempRow = [NSMutableDictionary dictionaryWithDictionary:[theResult fetchRowAsDictionary]];

		//use NULL string from preferences instead of the NSNull oject returned by the framework
		enumerator = [tempRow keyEnumerator];
		while ( (key = [enumerator nextObject]) ) {
			if ( [[tempRow objectForKey:key] isMemberOfClass:[NSNull class]] )
				[tempRow setObject:[prefs objectForKey:@"nullValue"] forKey:key];
		}
		// change some fields to be more human-readable or GUI compatible
		if ( [[tempRow objectForKey:@"Extra"] isEqualToString:@""] ) {
			[tempRow setObject:@"None" forKey:@"Extra"];
		}
		if ( [[tempRow objectForKey:@"Null"] isEqualToString:@"YES"] ) {
//			[tempRow setObject:[NSNumber numberWithInt:0] forKey:@"Null"];
			[tempRow setObject:@"YES" forKey:@"Null"];
		} else {
//			[tempRow setObject:[NSNumber numberWithInt:1] forKey:@"Null"];
			[tempRow setObject:@"NO" forKey:@"Null"];
		}
		[tempResult addObject:tempRow];
	}

	return tempResult;
}

- (BOOL)addRowToDB;
/*
tries to write row to mysql-db
returns YES if row written to db, otherwies NO
returns YES if no row is beeing edited and nothing has to be written to db
*/
{
	NSDictionary *theRow;
	NSMutableString *queryString;
	int code;

	if ( !isEditingRow || ![tableSourceView numberOfSelectedRows] )
		return YES;
	if ( alertSheetOpened )
		return NO;

	theRow = [tableFields objectAtIndex:[tableSourceView selectedRow]];

	if ( isEditingNewRow ) {
		//ADD syntax
		if ( [[theRow objectForKey:@"Length"] isEqualToString:@""] || ![theRow objectForKey:@"Length"] ) {
			queryString = [NSMutableString stringWithFormat:@"ALTER TABLE `%@` ADD `%@` %@",
						selectedTable, [theRow objectForKey:@"Field"], [theRow objectForKey:@"Type"]];
		} else {
			queryString = [NSMutableString stringWithFormat:@"ALTER TABLE `%@` ADD `%@` %@(%@)",
						selectedTable, [theRow objectForKey:@"Field"], [theRow objectForKey:@"Type"],
						[theRow objectForKey:@"Length"]];
		}
	} else {
		//CHANGE syntax
		if ( [[theRow objectForKey:@"Length"] isEqualToString:@""] || ![theRow objectForKey:@"Length"] ) {
			queryString = [NSMutableString stringWithFormat:@"ALTER TABLE `%@` CHANGE `%@` `%@` %@",
					selectedTable, [oldRow objectForKey:@"Field"], [theRow objectForKey:@"Field"],
					[theRow objectForKey:@"Type"]];
		} else {
			queryString = [NSMutableString stringWithFormat:@"ALTER TABLE `%@` CHANGE `%@` `%@` %@(%@)",
					selectedTable, [oldRow objectForKey:@"Field"], [theRow objectForKey:@"Field"],
					[theRow objectForKey:@"Type"], [theRow objectForKey:@"Length"]];
		}
	}
	
	//field specification
	if ( [[theRow objectForKey:@"unsigned"] intValue] == 1 ) {
		[queryString appendString:@" UNSIGNED"];
	}
	if ( [[theRow objectForKey:@"zerofill"] intValue] == 1 ) {
		[queryString appendString:@" ZEROFILL"];
	}
	if ( [[theRow objectForKey:@"binary"] intValue] == 1 ) {
		[queryString appendString:@" BINARY"];
	}
//	if ( [[theRow objectForKey:@"Null"] isEqualToString:@"NO"] || [[theRow objectForKey:@"Null"] isEqualToString:@"NOT NULL"]
//			|| [[theRow objectForKey:@"Null"] isEqualToString:@"no"] || [[theRow objectForKey:@"Null"] isEqualToString:@"not null"])
	if ( [[theRow objectForKey:@"Null"] isEqualToString:@"NO"] )
		[queryString appendString:@" NOT NULL"];
	if ( ![[theRow objectForKey:@"Extra"] isEqualToString:@"auto_increment"] && !([[theRow objectForKey:@"Type"] isEqualToString:@"timestamp"] && [[theRow objectForKey:@"Default"] isEqualToString:@"NULL"]) ) {
		if ( [[theRow objectForKey:@"Default"] isEqualToString:[prefs objectForKey:@"nullValue"]] ) {
			if ([[theRow objectForKey:@"Null"] isEqualToString:@"YES"] ) {
				[queryString appendString:@" DEFAULT NULL "];
			}
		} else if ( [[theRow objectForKey:@"Type"] isEqualToString:@"timestamp"] && ([[theRow objectForKey:@"Default"] isEqualToString:@"CURRENT_TIMESTAMP"] || [[theRow objectForKey:@"Default"] isEqualToString:@"current_timestamp"]) ) {
				[queryString appendString:@" DEFAULT CURRENT_TIMESTAMP "];
		} else {
	//		[queryString appendString:[NSString stringWithFormat:@" DEFAULT \"%@\" ", [theRow objectForKey:@"Default"]]];
			[queryString appendString:[NSString stringWithFormat:@" DEFAULT '%@' ", [mySQLConnection prepareString:[theRow objectForKey:@"Default"]]]];
		}
	} else {
		[queryString appendString:@" "];
	}
	
	if ( ![[theRow objectForKey:@"Extra"] isEqualToString:@""] && ![[theRow objectForKey:@"Extra"] isEqualToString:@"None"] && [theRow objectForKey:@"Extra"] ) {
		[queryString appendString:[theRow objectForKey:@"Extra"]];
	}
	
	//asks to add an index to query if auto_increment is set and field isn't indexed
	if ( [[theRow objectForKey:@"Extra"] isEqualToString:@"auto_increment"]
				&& ([[theRow objectForKey:@"Key"] isEqualToString:@""] || ![theRow objectForKey:@"Key"]) ) {
		[chooseKeyButton selectItemAtIndex:0];
		[NSApp beginSheet:keySheet
				modalForWindow:tableWindow modalDelegate:self
				didEndSelector:nil contextInfo:nil];
		code = [NSApp runModalForWindow:keySheet];
		
		[NSApp endSheet:keySheet];
		[keySheet orderOut:nil];
		
		if ( code ) {
			if ( [chooseKeyButton indexOfSelectedItem] == 0 ) {
				[queryString appendString:@" PRIMARY KEY"];
			} else {
				[queryString appendString:[NSString stringWithFormat:@", ADD %@ (`%@`)",
						[chooseKeyButton titleOfSelectedItem], [theRow objectForKey:@"Field"]]];
			}
		}
	}
	
	[mySQLConnection queryString:queryString];

	//NSLog(queryString);

	if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
		isEditingRow = NO;
		isEditingNewRow = NO;
		[self loadTable:selectedTable];

		// Mark the content table for refresh
		[tablesListInstance setContentRequiresReload:YES];

		return YES;
	} else {
		alertSheetOpened = YES;
		//problem: alert sheet doesn't respond to first click
		if ( isEditingNewRow ) {
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), NSLocalizedString(@"Cancel", @"cancel button"), nil, tableWindow, self, @selector(sheetDidEnd:returnCode:contextInfo:),
					nil, @"addrow", [NSString stringWithFormat:NSLocalizedString(@"Couldn't add field %@.\nMySQL said: %@", @"message of panel when field cannot be added"),
						[theRow objectForKey:@"Field"], [mySQLConnection getLastErrorMessage]]);
		} else {
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), NSLocalizedString(@"Cancel", @"cancel button"), nil, tableWindow, self, @selector(sheetDidEnd:returnCode:contextInfo:),
					nil, @"addrow", [NSString stringWithFormat:NSLocalizedString(@"Couldn't change field %@.\nMySQL said: %@", @"message of panel when field cannot be changed"),
						[theRow objectForKey:@"Field"], [mySQLConnection getLastErrorMessage]]);
		}
		return NO;
	}
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{
	/*
	 if contextInfo == addrow: remain in edit-mode if user hits OK, otherwise cancel editing
	 if contextInfo == removefield: removes row from mysql-db if user hits ok
	 if contextInfo == removeindex: removes index from mysql-db if user hits ok
	 */
	
	[sheet orderOut:self];

	if ( [contextInfo isEqualToString:@"addrow"] ) {
		alertSheetOpened = NO;
		if ( returnCode == NSAlertDefaultReturn ) {
			//problem: reentering edit mode for first cell doesn't function
			[tableSourceView editColumn:0 row:[tableSourceView selectedRow] withEvent:nil select:YES];
		} else {
			if ( !isEditingNewRow ) {
				[tableFields replaceObjectAtIndex:[tableSourceView selectedRow]
							withObject:[NSMutableDictionary dictionaryWithDictionary:oldRow]];
				isEditingRow = NO;
			} else {
				[tableFields removeObjectAtIndex:[tableSourceView selectedRow]];
				isEditingRow = NO;
				isEditingNewRow = NO;
			}
		}
		[tableSourceView reloadData];
	} else if ( [contextInfo isEqualToString:@"removefield"] ) {
		if ( returnCode == NSAlertDefaultReturn ) {
			//remove row
			[mySQLConnection queryString:[NSString stringWithFormat:@"ALTER TABLE `%@` DROP `%@`",
					selectedTable, [[tableFields objectAtIndex:[tableSourceView selectedRow]] objectForKey:@"Field"]]];
			
			if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
				[self loadTable:selectedTable];

				// Mark the content table for refresh
				[tablesListInstance setContentRequiresReload:YES];
			} else {
				NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
					[NSString stringWithFormat:NSLocalizedString(@"Couldn't remove field %@.\nMySQL said: %@", @"message of panel when field cannot be removed"),
						[[tableFields objectAtIndex:[tableSourceView selectedRow]] objectForKey:@"Field"],
						[mySQLConnection getLastErrorMessage]]);
			}
		}
	} else if ( [contextInfo isEqualToString:@"removeindex"] ) {
		if ( returnCode == NSAlertDefaultReturn ) {
			//remove index
			if ( [[[indexes objectAtIndex:[indexView selectedRow]] objectForKey:@"Key_name"] isEqualToString:@"PRIMARY"] ) {
				[mySQLConnection queryString:[NSString stringWithFormat:@"ALTER TABLE `%@` DROP PRIMARY KEY", selectedTable]];
			} else {
				[mySQLConnection queryString:[NSString stringWithFormat:@"ALTER TABLE `%@` DROP INDEX `%@`",
						selectedTable, [[indexes objectAtIndex:[indexView selectedRow]] objectForKey:@"Key_name"]]];
			}
		
			if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
				[self loadTable:selectedTable];
			} else {
				NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
						[NSString stringWithFormat:NSLocalizedString(@"Couldn't remove index.\nMySQL said: %@", @"message of panel when index cannot be removed"), [mySQLConnection getLastErrorMessage]]);
			}
		}
	}
}


#pragma mark Getter methods

/*
get the default value for a specified field
*/
- (NSString *)defaultValueForField:(NSString *)field
{
	if ( ![defaultValues objectForKey:field] ) {
		return [prefs objectForKey:@"nullValue"];	
	} else if ( [[defaultValues objectForKey:field] isMemberOfClass:[NSNull class]] ) {
		return [prefs objectForKey:@"nullValue"];
	} else {
		return [defaultValues objectForKey:field];
	}
}

/*
returns an array containing the field names of the selected table
*/
- (NSArray *)fieldNames
{
	NSMutableArray *tempArray = [NSMutableArray array];
	NSEnumerator *enumerator;
	id field;
	
	//load table if not already done
	if ( ![tablesListInstance structureLoaded] ) {
		[self loadTable:(NSString *)[tablesListInstance table]];
	}
	
	//get field names
	enumerator = [tableFields objectEnumerator];
	while ( (field = [enumerator nextObject]) ) {
		[tempArray addObject:[field objectForKey:@"Field"]];
	}
  
	return [NSArray arrayWithArray:tempArray];
}

/*
returns a dictionary containing enum/set field names as key and possible values as array
*/
- (NSDictionary *)enumFields
{
	return [NSDictionary dictionaryWithDictionary:enumFields];
}

#pragma mark TableView datasource methods

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if ( aTableView == tableSourceView ) {
		return [tableFields count];
	} else {
		return [indexes count];
	}
}

- (id)tableView:(NSTableView *)aTableView
			objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
	id theRow, theValue;
	
	if ( aTableView == tableSourceView ) {
		theRow = [tableFields objectAtIndex:rowIndex];
	} else {
		theRow = [indexes objectAtIndex:rowIndex];
	}
	theValue = [theRow objectForKey:[aTableColumn identifier]];

	return theValue;
}

- (void)tableView:(NSTableView *)aTableView
			setObjectValue:(id)anObject
			forTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
	if ( !isEditingRow ) {
		[oldRow setDictionary:[tableFields objectAtIndex:rowIndex]];
		isEditingRow = YES;
	}
	if ( anObject ) {
		[[tableFields objectAtIndex:rowIndex] setObject:anObject forKey:[aTableColumn identifier]];
	} else {
		[[tableFields objectAtIndex:rowIndex] setObject:@"" forKey:[aTableColumn identifier]];
	}
}

/*
Begin a drag and drop operation from the table - copy a single dragged row to the drag pasteboard.
*/
- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard
{
	int originalRow;
	NSArray *pboardTypes;

	if ( ![self selectionShouldChangeInTableView:nil] )
		return NO;

	if ( ([rows count] == 1)  && (tableView == tableSourceView) ) {
		pboardTypes=[NSArray arrayWithObjects:@"SequelProPasteboard", nil];
		originalRow = [[rows objectAtIndex:0] intValue];

		[pboard declareTypes:pboardTypes owner:nil];
		[pboard setString:[[NSNumber numberWithInt:originalRow] stringValue] forType:@"SequelProPasteboard"];

		return YES;
	} else {
		return NO;
	}
}

/*
Determine whether to allow a drag and drop operation on this table - for the purposes of drag reordering,
validate that the original source is of the correct type and within the same table, and that the drag
would result in a position change.
*/
- (NSDragOperation)tableView:(NSTableView*)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row
	proposedDropOperation:(NSTableViewDropOperation)operation
{
	NSArray *pboardTypes = [[info draggingPasteboard] types];
	int originalRow;

	// Ensure the drop is of the correct type
	if (operation == NSTableViewDropAbove && row != -1 && [pboardTypes containsObject:@"SequelProPasteboard"]) {
	
		// Ensure the drag originated within this table
		if ([info draggingSource] == tableView) {
			originalRow = [[[info draggingPasteboard] stringForType:@"SequelProPasteboard"] intValue];
			
			if (row != originalRow && row != (originalRow+1)) {
				return NSDragOperationMove;
			}
		}
	}

	return NSDragOperationNone;
}

/*
Having validated a drop, perform the field/column reordering to match.
*/
- (BOOL)tableView:(NSTableView*)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)destinationRow dropOperation:(NSTableViewDropOperation)operation
{
	int originalRow;
	NSMutableString *queryString;

	// Extract the original row position from the pasteboard.
	originalRow = [[[info draggingPasteboard] stringForType:@"SequelProPasteboard"] intValue];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];

	// Begin construction of the reordering query
	queryString = [NSMutableString stringWithFormat:@"ALTER TABLE `%@` MODIFY COLUMN `%@` %@", selectedTable,
		[[tableFields objectAtIndex:originalRow] objectForKey:@"Field"],
		[[tableFields objectAtIndex:originalRow] objectForKey:@"Type"]];

	// Add the length parameter if necessary
	if ( [[tableFields objectAtIndex:originalRow] objectForKey:@"Length"] &&
		![[[tableFields objectAtIndex:originalRow] objectForKey:@"Length"] isEqualToString:@""])
	{
		[queryString appendString:[NSString stringWithFormat:@"(%@)",
			[[tableFields objectAtIndex:originalRow] objectForKey:@"Length"]]];
	}

	// Add the new location
	if ( destinationRow == 0 ){
		[queryString appendString:@" FIRST"];
	} else {
		[queryString appendString:[NSString stringWithFormat:@" AFTER `%@`",
						[[tableFields objectAtIndex:destinationRow-1] objectForKey:@"Field"]]];
	}

	// Run the query; report any errors, or reload the table on success
	[mySQLConnection queryString:queryString];
	if ( ![[mySQLConnection getLastErrorMessage] isEqualTo:@""] ) {
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
			[NSString stringWithFormat:NSLocalizedString(@"Couldn't move field. MySQL said: %@", @"message of panel when field cannot be added in drag&drop operation"), [mySQLConnection getLastErrorMessage]]);
	} else {
		[self loadTable:selectedTable];
		if ( originalRow < destinationRow ) {
			[tableSourceView selectRow:destinationRow-1 byExtendingSelection:NO];
		} else {
			[tableSourceView selectRow:destinationRow byExtendingSelection:NO];
		}
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];

	// Mark the content table for refresh
	[tablesListInstance setContentRequiresReload:YES];
	
	return YES;
}

#pragma mark TtableView delegate methods

- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView
{
/*
	int row = [tableSourceView editedRow];
	int column = [tableSourceView editedColumn];
	NSTableColumn *tableColumn;
	NSCell *cell;

	if ( row != -1 ) {
		tableColumn = [[tableSourceView tableColumns] objectAtIndex:column]; 
		cell = [tableColumn dataCellForRow:row]; 
	[cell endEditing:[tableSourceView currentEditor]]; 
	}
*/
//end editing (otherwise problems when user hits reload button)
	[tableWindow endEditingFor:nil];

	return [self addRowToDB];
}

/*
traps enter and esc and make/cancel editing without entering next row
*/
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	int row, column;

	row = [tableSourceView editedRow];
	column = [tableSourceView editedColumn];

	 if (  [textView methodForSelector:command] == [textView methodForSelector:@selector(insertNewline:)] ||
				[textView methodForSelector:command] == [textView methodForSelector:@selector(insertTab:)] ) //trap enter and tab
	 {
		//save current line
		[[control window] makeFirstResponder:control];
		if ( column == 9 ) {
			if ( [self addRowToDB] && [textView methodForSelector:command] == [textView methodForSelector:@selector(insertTab:)] ) {
				if ( row < ([tableSourceView numberOfRows] - 1) ) {
					[tableSourceView selectRow:row+1 byExtendingSelection:NO];
					[tableSourceView editColumn:0 row:row+1 withEvent:nil select:YES];
				} else {
					[tableSourceView selectRow:0 byExtendingSelection:NO];
					[tableSourceView editColumn:0 row:0 withEvent:nil select:YES];
				}
			}
		} else {
			if ( column == 2 ) {
				[tableSourceView editColumn:column+4 row:row withEvent:nil select:YES];
			} else if ( column == 6 ) {
				[tableSourceView editColumn:column+2 row:row withEvent:nil select:YES];
			} else {
				[tableSourceView editColumn:column+1 row:row withEvent:nil select:YES];
			}
		}
		return TRUE;
		 
	 } else if (  [[control window] methodForSelector:command] == [[control window] methodForSelector:@selector(_cancelKey:)] ||
					[textView methodForSelector:command] == [textView methodForSelector:@selector(complete:)] ) {
		//abort editing
		[control abortEditing];
		if ( isEditingRow && !isEditingNewRow ) {
			isEditingRow = NO;
			[tableFields replaceObjectAtIndex:row withObject:[NSMutableDictionary dictionaryWithDictionary:oldRow]];
		} else if ( isEditingNewRow ) {
			isEditingRow = NO;
			isEditingNewRow = NO;
			[tableFields removeObjectAtIndex:row];
			[tableSourceView reloadData];
		}
		return TRUE;
	 } else {
		 return FALSE;
	 }
}


#pragma mark SplitView delegate methods

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	return YES;
}

- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
{
		return proposedMax - 150;
}

- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
{
		return proposedMin + 150;
}

- (NSRect)splitView:(NSSplitView *)splitView additionalEffectiveRectOfDividerAtIndex:(int)dividerIndex
{	
	return [structureGrabber convertRect:[structureGrabber bounds] toView:splitView];
}

//last but not least
- (id)init
{
	self = [super init];

	tableFields = [[NSMutableArray alloc] init];
	indexes = [[NSMutableArray alloc] init];
	oldRow = [[NSMutableDictionary alloc] init];
	enumFields = [[NSMutableDictionary alloc] init];

	return self;
}

- (void)dealloc
{	
	[tableFields release];
	[indexes release];
	[oldRow release];
	[defaultValues release];
	[prefs release];
	[enumFields release];
	
	[super dealloc];
}

@end
