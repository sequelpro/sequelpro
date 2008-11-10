//
//  TableDocument.h
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed May 01 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//  
//  Forked by Abhi Beckert (abhibeckert.com) 2008-04-04
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

#import "TableContent.h"
#import "TableDocument.h"
#import "TablesList.h"
#import "TableSource.h"
#import "CMImageView.h"


@implementation TableContent

- (id)init
{
	if (![super init])
		return nil;
	
	fullResult = [[NSMutableArray alloc] init];
	filteredResult = [[NSMutableArray alloc] init];
	oldRow = [[NSMutableDictionary alloc] init];
	areShowingAllRows = false;
	
	return self;
}

- (void)awakeFromNib
{
}

- (void)loadTable:(NSString *)aTable
/*
 loads aTable, put it in an array, update the tableViewColumns and reload the tableView
 */
{
	int i;
	NSNumber *colWidth;
	NSArray		*theColumns;
	NSTableColumn	*theCol;
	//	NSNumberFormatter	*numberFormatter;
	NSString 		*query;
	CMMCPResult	*queryResult;
	
	selectedTable = aTable;
	[tableContentView deselectAll:self];
	if ( isEditingRow )
		return;
	
	//query started
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];
	
	[limitRowsField setStringValue:@"1"];
	
	//reset keys
	if ( keys ) {
		keys = nil;
	}
	
	[tableContentView scrollRowToVisible:0];
	[tableContentView scrollColumnToVisible:0];
	
	if ( [aTable isEqualToString:@""] || !aTable ) {
		//no table selected
		//free tableView
		theColumns = [tableContentView tableColumns];
		while ([theColumns count]) {
			[tableContentView removeTableColumn:[theColumns objectAtIndex:0]];
		}
		//		theCol = [[NSTableColumn alloc] initWithIdentifier:@""];
		//		[[theCol headerCell] setStringValue:@""];
		//		[tableContentView addTableColumn:theCol];
		//		[tableContentView sizeLastColumnToFit];
		[fullResult removeAllObjects];
		[filteredResult removeAllObjects];
		[tableContentView reloadData];
		//		[theCol release];
		
		//disable filter options
		[fieldField setEnabled:NO];
		[fieldField removeAllItems];
		[fieldField addItemWithTitle:NSLocalizedString(@"field", @"popup menuitem for field (showing only if disabled)")];
		[compareField setEnabled:NO];
		[compareField removeAllItems];
		[compareField addItemWithTitle:NSLocalizedString(@"is", @"popup menuitem for field IS value")];
		[argumentField setEnabled:NO];
		[argumentField setStringValue:@""];
		[filterButton setEnabled:NO];
		areShowingAllRows = YES;
		
		//disable limit fields
		if ( [prefs boolForKey:@"limitRows"] ) {
			[limitRowsText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Limited to %d rows starting with row", @"text showing the number of rows the result is limited to"),
										   [prefs integerForKey:@"limitRowsValue"]]];
		} else {
			[limitRowsField setStringValue:@""];
			[limitRowsText setStringValue:NSLocalizedString(@"No limit", @"text showing that the result isn't limited")];
		}
		[limitRowsField setEnabled:NO];
		[limitRowsButton setEnabled:NO];
		[limitRowsStepper setEnabled:NO];
		
		//disable buttons
		[addButton setEnabled:NO];
		[copyButton setEnabled:NO];
		[removeButton setEnabled:NO];
		
		[countText setStringValue:@""];
		
		//query finished
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
		
		return;
	}
	
	//make a fast query to get fieldNames and fieldTypes (used in fieldListForQuery method)
	queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SELECT * FROM `%@` LIMIT 0", selectedTable]];
	fieldTypes = [[queryResult fetchTypesAsArray] retain];
	fieldNames = [[queryResult fetchFieldNames] retain];
	
	//perform query and load result in array (each row as a dictionary)
	//	queryResult = [mySQLConnection queryString:[@"SELECT * FROM " stringByAppendingString:selectedTable]];
	query = [NSString stringWithFormat:@"SELECT %@ FROM `%@`", [self fieldListForQuery], selectedTable];
	if ( [prefs boolForKey:@"limitRows"] ) {
		if ( [limitRowsField intValue] <= 0 ) {
			[limitRowsField setStringValue:@"1"];
		}
		query = [query stringByAppendingString:
				 [NSString stringWithFormat:@" LIMIT %d,%d",
				  [limitRowsField intValue]-1, [prefs integerForKey:@"limitRowsValue"]]];
	}
	//	[queryResult release];
	queryResult = [mySQLConnection queryString:query];
	//	[fullResult setArray:[[self fetchResultAsArray:queryResult] retain]];
	[fullResult setArray:[self fetchResultAsArray:queryResult]];
	[filteredResult setArray:fullResult];
	//	fieldTypes = [[queryResult fetchTypesAsArray] retain];
	//	fieldNames = [[queryResult fetchFieldNames] retain];
	
	//set count text
	numRows = [self getNumberOfRows];
	[countText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%d rows in table", @"text showing how many rows are in the result"), numRows]];
	
	//clear sorting
	sortField = nil;
	isDesc = NO;
	
	if ( queryResult == nil ) {
		NSLog(@"Loading table %@ failed, query string was: %@", aTable, query);
		return;
	}
	
	//enable and initialize filter fields (with tags for position of menu item and field position)
	[fieldField setEnabled:YES];
	[fieldField removeAllItems];
	[fieldField addItemsWithTitles:fieldNames];
	for ( i = 0 ; i < [fieldField numberOfItems] ; i++ ) {
		[[fieldField itemAtIndex:i] setTag:i];
	}
	[compareField setEnabled:YES];
	[self setCompareTypes:self];
	[argumentField setEnabled:YES];
	[argumentField setStringValue:@""];
	[filterButton setEnabled:YES];
	areShowingAllRows = YES;
	
	//enable or disable limit fields
	if ( [prefs boolForKey:@"limitRows"] ) {
		[limitRowsField setEnabled:YES];
		[limitRowsButton setEnabled:YES];
		[limitRowsStepper setEnabled:YES];
		[limitRowsText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Limited to %d rows starting with row", @"text showing the number of rows the result is limited to"),
									   [prefs integerForKey:@"limitRowsValue"]]];
	} else {
		[limitRowsField setEnabled:NO];
		[limitRowsButton setEnabled:NO];
		[limitRowsStepper setEnabled:NO];
		[limitRowsField setStringValue:@""];
		[limitRowsText setStringValue:NSLocalizedString(@"No limit", @"text showing that the result isn't limited")];
	}
	
	//enable buttons
	[addButton setEnabled:YES];
	[copyButton setEnabled:YES];
	[removeButton setEnabled:YES];
	
	//set columns
	//remove all columns from table
	theColumns = [tableContentView tableColumns];
	i=0;
	while ([theColumns count]) {
		[tableContentView removeTableColumn:[theColumns objectAtIndex:0]];
		i++;
	}
	
	//add columns, corresponding to the query result
	theColumns = fieldNames;
	for ( i = 0 ; i < [theColumns count] ; i++ ) {
		theCol = [[NSTableColumn alloc] initWithIdentifier:[theColumns objectAtIndex:i]];
		[theCol setEditable:YES];
		if ( [theCol respondsToSelector:@selector(setResizingMask:)] ) {
			// os 10.4
			[theCol setResizingMask:NSTableColumnUserResizingMask];
		} else {
			// os pre-10.4
			[theCol setResizable:YES];
		}
		NSComboBoxCell *dataCell;
		if ( [[tableSourceInstance enumFields] objectForKey:[theColumns objectAtIndex:i]] ) {
			dataCell = [[[NSComboBoxCell alloc] initTextCell:@""] autorelease];
			[dataCell setButtonBordered:NO];
			[dataCell setBezeled:NO];
			[dataCell setDrawsBackground:NO];
			[dataCell setCompletes:YES];
			[dataCell setControlSize:NSSmallControlSize];
			[dataCell addItemWithObjectValue:@"NULL"];
			[dataCell addItemsWithObjectValues:[[tableSourceInstance enumFields] objectForKey:[theColumns objectAtIndex:i]]];
		} else {
			dataCell = [[[NSTextFieldCell alloc] initTextCell:@""] autorelease];
		}
		[dataCell setEditable:YES];
		//		[[theCol dataCell] setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		if ( [prefs boolForKey:@"useMonospacedFonts"] ) {
			//			[[theCol dataCell] setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
			[dataCell setFont:[NSFont fontWithName:@"Monaco" size:10]];
		} else {
			[dataCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}
		if ( [dataCell respondsToSelector:@selector(setLineBreakMode:)] ) {
			// os 10.4
			[dataCell setLineBreakMode:NSLineBreakByTruncatingTail];
		}
		[theCol setDataCell:dataCell];
		//set date and number formatters
		/*
		 if ([[fieldTypes objectAtIndex:i] isEqualToString:@"timestamp"]) {
		 [[theCol dataCell] setFormatter:[[NSDateFormatter alloc]
		 initWithDateFormat:@"%Y-%m-%d %H:%M:%S" allowNaturalLanguage:YES]];
		 }
		 if ([[fieldTypes objectAtIndex:i] isEqualToString:@"datetime"]) {
		 [[theCol dataCell] setFormatter:[[NSDateFormatter alloc] initWithDateFormat:@"%Y-%m-%d %H:%M:%S" allowNaturalLanguage:YES]];
		 }
		 if ([[fieldTypes objectAtIndex:i] isEqualToString:@"date"]) {
		 [[theCol dataCell] setFormatter:[[NSDateFormatter alloc] initWithDateFormat:@"%Y-%m-%d" allowNaturalLanguage:YES]];
		 }
		 if ([[fieldTypes objectAtIndex:i] isEqualToString:@"time"]) {
		 [[theCol dataCell] setFormatter:[[NSDateFormatter alloc] initWithDateFormat:@"%H:%M:%S" allowNaturalLanguage:YES]];
		 }
		 if ([[fieldTypes objectAtIndex:i] isEqualToString:@"year"]) {
		 [[theCol dataCell] setFormatter:[[NSDateFormatter alloc] initWithDateFormat:@"%Y" allowNaturalLanguage:YES]];
		 }
		 if ([[fieldTypes objectAtIndex:i] isEqualToString:@"tiny"] || [[fieldTypes objectAtIndex:i] isEqualToString:@"short"]
		 || [[fieldTypes objectAtIndex:i] isEqualToString:@"long"] || [[fieldTypes objectAtIndex:i] isEqualToString:@"int24"]
		 || [[fieldTypes objectAtIndex:i] isEqualToString:@"longlong"] ) {
		 numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
		 [numberFormatter setFormat:@"0"];
		 [numberFormatter setAttributedStringForNil:[[NSAttributedString alloc] initWithString:[prefs stringForKey:@"nullValue"]]];
		 [numberFormatter setAllowsFloats:NO];
		 [[theCol dataCell] setFormatter:numberFormatter];
		 }
		 if ( [[fieldTypes objectAtIndex:i] isEqualToString:@"decimal"] || [[fieldTypes objectAtIndex:i] isEqualToString:@"float"]
		 || [[fieldTypes objectAtIndex:i] isEqualToString:@"double"] ) {
		 numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
		 //here we should allow any number of decimal values (after the comma)
		 //problem with float-numbers like 2.13231e+08
		 //double numbers doesn't have all decimal values
		 //-> bugs in the framework?
		 [numberFormatter setFormat:@"0.####################"];
		 [numberFormatter setAttributedStringForNil:[[NSAttributedString alloc] initWithString:[prefs stringForKey:@"nullValue"]]];
		 [[theCol dataCell] setFormatter:numberFormatter];
		 }
		 */
		[[theCol headerCell] setStringValue:[theColumns objectAtIndex:i]];
		// set width of column to saved value if exists
		colWidth = [[[[prefs objectForKey:@"tableColumnWidths"] objectForKey:[NSString stringWithFormat:@"%@@%@", [tableDocumentInstance database], [tableDocumentInstance host]]] objectForKey:[tablesListInstance table]] objectForKey:[theColumns objectAtIndex:i]];
		if ( colWidth ) {
			[theCol setWidth:[colWidth floatValue]];
		}
		[tableContentView addTableColumn:theCol];
		[theCol release];
	}
	
	//	[tableContentView sizeLastColumnToFit];
	//tries to fix problem with last row (otherwise to small)
	//sets last column to width of the first if smaller than 30
	//problem not fixed for resizing window
	//	if ( [[tableContentView tableColumnWithIdentifier:[theColumns objectAtIndex:[theColumns count]-1]] width] < 30 )
	//		[[tableContentView tableColumnWithIdentifier:[theColumns objectAtIndex:[theColumns count]-1]]
	//				setWidth:[[tableContentView tableColumnWithIdentifier:[theColumns objectAtIndex:0]] width]];
	
	[tableContentView reloadData];
	
	//query finished
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
}

- (IBAction)reloadTable:(id)sender
/*
 reloads the table (performing a new mysql-query)
 */
{
	[self loadTable:selectedTable];
}

- (IBAction)reloadTableValues:(id)sender
/*
 reload the table values without reconfiguring the tableView (with filter and limit if set)
 */
{
	NSString *queryString;
	CMMCPResult *queryResult;
	
	//query started
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];
	
	//enable or disable limit fields
	if ( [prefs boolForKey:@"limitRows"] ) {
		[limitRowsField setEnabled:YES];
		[limitRowsButton setEnabled:YES];
		[limitRowsStepper setEnabled:YES];
		[limitRowsText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Limited to %d rows starting with row", @"text showing the number of rows the result is limited to"),
									   [prefs integerForKey:@"limitRowsValue"]]];
	} else {
		[limitRowsField setEnabled:NO];
		[limitRowsButton setEnabled:NO];
		[limitRowsStepper setEnabled:NO];
		[limitRowsText setStringValue:NSLocalizedString(@"No limit", @"text showing that the result isn't limited")];
		[limitRowsField setStringValue:@""];
	}
	
	//	queryString = [@"SELECT * FROM " stringByAppendingString:selectedTable];
	queryString = [NSString stringWithFormat:@"SELECT %@ FROM `%@`", [self fieldListForQuery], selectedTable];
	if ( sortField ) {
		queryString = [NSString stringWithFormat:@"%@ ORDER BY `%@`", queryString, sortField];
		//		queryString = [queryString stringByAppendingString:[NSString stringWithFormat:@" ORDER BY `%@`", sortField]];
		if ( isDesc )
			queryString = [queryString stringByAppendingString:@" DESC"];
	}
	if ( [prefs boolForKey:@"limitRows"] ) {
		if ( [limitRowsField intValue] <= 0 ) {
			[limitRowsField setStringValue:@"1"];
		}
		queryString = [queryString stringByAppendingString:
					   [NSString stringWithFormat:@" LIMIT %d,%d",
						[limitRowsField intValue]-1, [prefs integerForKey:@"limitRowsValue"]]];
		[limitRowsField selectText:self];
	}
	queryResult = [mySQLConnection queryString:queryString];
	//	[fullResult setArray:[[self fetchResultAsArray:queryResult] retain]];
	[fullResult setArray:[self fetchResultAsArray:queryResult]];
	numRows = [self getNumberOfRows];
	if ( !areShowingAllRows ) {
		[self filterTable:self];
		[countText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%d rows of %d selected", @"text showing how many rows are in the filtered result"), [filteredResult count], numRows]];
	} else {
		[filteredResult setArray:fullResult];
		[countText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%d rows in table", @"text showing how many rows are in the result"), numRows]];
	}
	[tableContentView reloadData];
	
	//query finished
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
}

/**
 * filter the table with arguments given by the user
 */
- (IBAction)filterTable:(id)sender
{
	CMMCPResult *theResult;
	int tag = [[compareField selectedItem] tag];
	NSString *compareOperator = @"";
	NSMutableString *argument = [[NSMutableString alloc] initWithString:[argumentField stringValue]];
	NSString *queryString;
	int i;
	
	if ([argument length] == 0) {
		[argument release];
		[self showAll:sender];
		return;
	}
	
	//query started
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];
	
	BOOL doQuote = YES;
	
	if ( ![compareType isEqualToString:@""] ) {
		if ( [compareType isEqualToString:@"string"] ) {
			//string comparision
			switch ( tag ) {
				case 0:
					compareOperator = @"LIKE";
					break;
				case 1:
					compareOperator = @"NOT LIKE";
					break;
				case 2:
					compareOperator = @"LIKE";
					[argument setString:[[@"%" stringByAppendingString:argument] stringByAppendingString:@"%"]];
					break;
				case 3:
					compareOperator = @"NOT LIKE";
					[argument setString:[[@"%" stringByAppendingString:argument] stringByAppendingString:@"%"]];
					break;
				case 4:
					compareOperator = @"IN";
					doQuote = NO;
					[argument setString:[[@"(" stringByAppendingString:argument] stringByAppendingString:@")"]];
					break;
			}
		} else if ( [compareType isEqualToString:@"number"] ) {
			//number comparision
			switch ( tag ) {
				case 0:
					compareOperator = @"=";
					break;
				case 1:
					compareOperator = @"!=";
					break;
				case 2:
					compareOperator = @">";
					break;
				case 3:
					compareOperator = @"<";
					break;
				case 4:
					compareOperator = @">=";
					break;
				case 5:
					compareOperator = @"<=";
					break;
				case 6:
					compareOperator = @"IN";
					doQuote = NO;
					[argument setString:[[@"(" stringByAppendingString:argument] stringByAppendingString:@")"]];
					break;
			}
		} else if ( [compareType isEqualToString:@"date"] ) {
			//date comparision
			switch ( tag ) {
				case 0:
					compareOperator = @"=";
					break;
				case 1:
					compareOperator = @"!=";
					break;
				case 2:
					compareOperator = @"<";
					break;
				case 3:
					compareOperator = @">";
					break;
				case 4:
					compareOperator = @"<=";
					break;
				case 5:
					compareOperator = @">=";
					break;
			}
		}
		
		//		queryString = [NSString stringWithFormat:@"SELECT %@ FROM `%@` WHERE `%@` %@ '%@'",
		//							[self fieldListForQuery], selectedTable, [fieldField titleOfSelectedItem],
		//							compareOperator, argument];
		if (doQuote) {
			//escape special characters
			for ( i = 0 ; i < [argument length] ; i++ ) {
				if ( [argument characterAtIndex:i] == '\\' ) {
					[argument insertString:@"\\" atIndex:i];
					i++;
				}
			}
			[argument setString:[mySQLConnection prepareString:argument]];
			queryString = [NSString stringWithFormat:@"SELECT %@ FROM `%@` WHERE `%@` %@ \"%@\"",
						   [self fieldListForQuery], selectedTable, [fieldField titleOfSelectedItem],
						   compareOperator, argument];			
		} else {
			queryString = [NSString stringWithFormat:@"SELECT %@ FROM `%@` WHERE `%@` %@ %@",
						   [self fieldListForQuery], selectedTable, [fieldField titleOfSelectedItem],
						   compareOperator, argument];
		}
		if ( sortField ) {
			//			queryString = [queryString stringByAppendingString:[NSString stringWithFormat:@" ORDER BY `%@`", sortField]];
			queryString = [NSString stringWithFormat:@"%@ ORDER BY `%@`", queryString, sortField];
			if ( isDesc )
				queryString = [queryString stringByAppendingString:@" DESC"];
		}
		if ( [prefs boolForKey:@"limitRows"] ) {
			if ( [limitRowsField intValue] <= 0 ) {
				[limitRowsField setStringValue:@"1"];
			}
			queryString = [queryString stringByAppendingString:
						   [NSString stringWithFormat:@" LIMIT %d,%d",
							[limitRowsField intValue]-1, [prefs integerForKey:@"limitRowsValue"]]];
		}
	} else {
		NSLog(@"ERROR: unknown compare type %@", compareType);
		queryString = @"";
	}
	
	theResult = [mySQLConnection queryString:queryString];
	[filteredResult setArray:[self fetchResultAsArray:theResult]];
	
	[countText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%d rows of %d selected", @"text showing how many rows are in the filtered result"), [filteredResult count], numRows]];
	
	[tableContentView reloadData];
	areShowingAllRows = NO;
	
	//query finished
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
	[argument release];
}

/**
 * reload tableView with all results shown (no new mysql-query, it uses simply the fullResult array)
 */
- (IBAction)showAll:(id)sender
{
	[filteredResult setArray:fullResult];
	[tableContentView reloadData];
	areShowingAllRows = YES;
	
	[countText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%d rows in table", @"text showing how many rows are in the result"), numRows]];
}


//edit methods
- (IBAction)addRow:(id)sender
/*
 adds an empty row to the table-array and goes into edit mode
 */
{
	NSMutableDictionary *newRow = [NSMutableDictionary dictionary];
	int i;
	
	if ( ![self selectionShouldChangeInTableView:nil] )
		return;
	
	for ( i = 0 ; i < [fieldNames count] ; i++ ) {
		//		[newRow setObject:[prefs stringForKey:@"nullValue"] forKey:[fieldNames objectAtIndex:i]];
		[newRow setObject:[tableSourceInstance defaultValueForField:[fieldNames objectAtIndex:i]]
				   forKey:[fieldNames objectAtIndex:i]];
	}
	[filteredResult addObject:newRow];
	
	isEditingRow = YES;
	isEditingNewRow = YES;
	[tableContentView reloadData];
	[tableContentView selectRow:[tableContentView numberOfRows]-1 byExtendingSelection:NO];
	if ( [multipleLineEditingButton state] == NSOffState )
		[tableContentView editColumn:0 row:[tableContentView numberOfRows]-1 withEvent:nil select:YES];
}

- (IBAction)copyRow:(id)sender
/*
 copies a row of the table-array and goes into edit mode
 */
{
	NSMutableDictionary *tempRow;
	CMMCPResult *queryResult;
	NSDictionary *row;
	int i;
	
	if ( ![self selectionShouldChangeInTableView:nil] )
		return;
	if ( [tableContentView numberOfSelectedRows] < 1 )
		return;
	if ( [tableContentView numberOfSelectedRows] > 1 ) {
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil, NSLocalizedString(@"You can only copy single rows.", @"message of panel when trying to copy multiple rows"));
		return;
	}
	
	//copy row
	tempRow = [NSMutableDictionary dictionaryWithDictionary:[filteredResult objectAtIndex:[tableContentView selectedRow]]];
	[filteredResult insertObject:tempRow atIndex:[tableContentView selectedRow]+1];
	isEditingRow = YES;
	isEditingNewRow = YES;
	//set autoincrement fields to NULL
	queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW COLUMNS FROM `%@`", selectedTable]];
	for ( i = 0 ; i < [queryResult numOfRows] ; i++ ) {
		[queryResult dataSeek:i];
		row = [queryResult fetchRowAsDictionary];
		if ( [[row objectForKey:@"Extra"] isEqualToString:@"auto_increment"] ) {
			[tempRow setObject:[prefs stringForKey:@"nullValue"] forKey:[row objectForKey:@"Field"]];
		}
	}
	//select row and go in edit mode
	[tableContentView reloadData];
	[tableContentView selectRow:[tableContentView selectedRow]+1 byExtendingSelection:NO];
	if ( [multipleLineEditingButton state] == NSOffState )
		[tableContentView editColumn:0 row:[tableContentView selectedRow] withEvent:nil select:YES];
}

- (IBAction)removeRow:(id)sender
/*
 asks user if he really wants to delete the selected rows
 */
{
	if ( ![self selectionShouldChangeInTableView:nil] )
		return;
	if ( ![tableContentView numberOfSelectedRows] )
		return;
	/*
	 if ( ([tableContentView numberOfSelectedRows] == [self numberOfRowsInTableView:tableContentView]) &&
	 areShowingAllRows &&
	 (![prefs boolForKey:@"limitRows"] || ([tableContentView numberOfSelectedRows] < [prefs integerForKey:@"limitRowsValue"])) ) {
	 */
	if ( ([tableContentView numberOfSelectedRows] == [tableContentView numberOfRows]) && 
		(([prefs boolForKey:@"limitRows"] && [tableContentView numberOfSelectedRows] == [self fetchNumberOfRows]) ||
		 (![prefs boolForKey:@"limitRows"] && [tableContentView numberOfSelectedRows] == [self getNumberOfRows])) ) {
		NSBeginAlertSheet(NSLocalizedString(@"Warning", @"warning"), NSLocalizedString(@"Delete", @"delete button"), NSLocalizedString(@"Cancel", @"cancel button"), nil, tableWindow, self, @selector(sheetDidEnd:returnCode:contextInfo:),
						  nil, @"removeallrows", NSLocalizedString(@"Do you really want to delete all rows?", @"message of panel asking for confirmation for deleting all rows"));
	} else if ( [tableContentView numberOfSelectedRows] == 1 ) {
		NSBeginAlertSheet(NSLocalizedString(@"Warning", @"warning"), NSLocalizedString(@"Delete", @"delete button"), NSLocalizedString(@"Cancel", @"cancel button"), nil, tableWindow, self, @selector(sheetDidEnd:returnCode:contextInfo:),
						  nil, @"removerow", NSLocalizedString(@"Do you really want to delete the selected row?", @"message of panel asking for confirmation for deleting the selected row"));
	} else {
		NSBeginAlertSheet(NSLocalizedString(@"Warning", @"warning"), NSLocalizedString(@"Delete", @"delete button"), NSLocalizedString(@"Cancel", @"cancel button"), nil, tableWindow, self, @selector(sheetDidEnd:returnCode:contextInfo:),
						  nil, @"removerow",
						  [NSString stringWithFormat:NSLocalizedString(@"Do you really want to delete the selected %d rows?", @"message of panel asking for confirmation for deleting the selected rows"), [tableContentView numberOfSelectedRows]]);
	}
}


//editSheet methods
- (IBAction)closeEditSheet:(id)sender
{
	[NSApp stopModalWithCode:[sender tag]];
}

- (IBAction)openEditSheet:(id)sender
/*
 loads a file into the editSheet
 */
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	if ( [panel runModal] == NSOKButton ) {
		NSString *fileName = [panel filename];
		
		// free old data
		if ( editData != nil ) {
			[editData release];
		}
		
		// load new data/images
		editData = [[NSData alloc] initWithContentsOfFile:fileName];
		NSImage *image = [[[NSImage alloc] initByReferencingFile:fileName] autorelease];
		NSString *contents = [[NSString stringWithContentsOfFile:fileName] autorelease];
		
		// set the image preview, string contents and hex representation
		[editImage setImage:image];
		[editTextView setString:contents];
		[hexTextView setString:[self dataToHex:editData]];
	}
}

- (IBAction)saveEditSheet:(id)sender
/*
 saves a file containing the content of the editSheet
 */
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	if ( [panel runModal] == NSOKButton ) {
		NSString *fileName = [panel filename];
		NSString *data;
		
		if ( [editData isKindOfClass:[NSData class]] ) {
			data = editData;
		} else {
			data = [editData description];
		}
		if ( [editData respondsToSelector:@selector(writeToFile:atomically:encoding:error:)] ) {
			// mac os 10.4 or later
			[editData writeToFile:fileName atomically:YES encoding:[CMMCPConnection encodingForMySQLEncoding:[(NSString *)[tableDocumentInstance encoding] UTF8String]] error:NULL];
		} else {
			// mac os pre 10.4
			[editData writeToFile:fileName atomically:YES];
		}
	}
}

- (IBAction)dropImage:(id)sender
/*
 invoked when user drag&drops image on imageView
 */
{
	// load new data/images
	if (nil != editData)
	{
		[editData release];
	}
	editData = [[[NSData alloc] initWithContentsOfFile:[sender draggedFilePath]] retain];
	NSString *contents = [NSString stringWithContentsOfFile:[sender draggedFilePath]];
	
	// set the string contents and hex representation
	[editTextView setString:contents];
	[hexTextView setString:[self dataToHex:editData]];
}

- (void)textDidChange:(NSNotification *)notification
/*
 invoked when the user changes the string in the editSheet
 */
{
	// clear the image and hex (since i doubt someone can "type" a gif)
	[editImage setImage:nil];
	[hexTextView setString:@""];
	
	// free old data
	if ( editData != nil ) {
		[editData release];
	}
	
	// set edit data to text
	editData = [[editTextView string] retain];
}

- (NSString *)dataToHex:(NSData *)data
/*
 returns the hex representation of the given data
 */
{
	unsigned i;
	unsigned totalLength = [data length];
	int bytesPerLine = 16;
	NSMutableString *retVal = [NSMutableString string];
	unsigned char *nodisplay = "\t\n\r\f";
	
	// get the length of the longest location
	int longest = [(NSString *)[NSString stringWithFormat:@"%X", totalLength - ( totalLength % bytesPerLine )] length];
	
	for ( i = 0; i < totalLength; i += bytesPerLine ) {
		int j;
		NSMutableString *hex = [[NSMutableString alloc] initWithCapacity:(3 * bytesPerLine - 1)];
		NSMutableString *location = [[NSMutableString alloc] initWithCapacity:(longest + 2)];
		NSMutableString *chars = [[NSMutableString alloc] init];
		unsigned char *buffer;
		int buffLength = bytesPerLine;
		
		// add hex value of location
		[location appendString:[NSString stringWithFormat:@"%X", i]];
		
		// pad it
		while( longest > [location length] ) {
			[location insertString:@"0" atIndex:0];
		}
		
		// get the chars from the NSData obj
		if ( i + buffLength >= totalLength ) {
			buffLength = totalLength - i;
		}
		buffer = (unsigned char*) malloc( sizeof( unsigned char ) * buffLength );
		NSRange range = { i, buffLength };
		[data getBytes:buffer range:range];
		
		// build the hex string
		for ( j = 0; j < buffLength; j++ ) {
			unsigned char byte = *(buffer + j);
			if ( byte < 16 ) {
				[hex appendString:@"0"];
			}
			[hex appendString:[NSString stringWithFormat:@"%X", byte]];
			[hex appendString:@" "];
			
			// if the char is undisplayable, replace it with "."
			unsigned char current;
			int count = 0;
			while ( ( current = *(nodisplay + count++) ) > 0 ) {
				if ( current == byte ) {
					*(buffer + j) = '.';
					break;
				}
			}
		}
		
		// add padding to missing hex values.
		for ( j = 0; j < bytesPerLine - buffLength; j++ ) {
			[hex appendString:@"   "];
		}
		
		// remove extra ghost characters
		[chars appendString:[NSString stringWithCString:buffer]];
		if ( [chars length] > bytesPerLine ) {
			[chars deleteCharactersInRange:NSMakeRange( bytesPerLine, [chars length] - bytesPerLine )];
		}
		
		// build line
		[retVal appendString:location];
		[retVal appendString:@"  "];
		[retVal appendString:hex];
		[retVal appendString:@" "];
		[retVal appendString:chars];
		[retVal appendString:@"\n"];
		
		// clean up
		[hex release];
		[chars release];
		[location release];
		free( buffer );
	}
	
	return retVal;
}

//getter methods
- (NSArray *)currentResult
/*
 returns the current result (as shown in table content view) as array, the first object containing the field names as array, the following objects containing the rows as array
 */
{
	NSArray *tableColumns;
	NSEnumerator *enumerator;
	id tableColumn;
	NSMutableArray *currentResult = [NSMutableArray array];
	NSMutableArray *tempRow = [NSMutableArray array];
	int i;
	
	//load table if not already done
	if ( ![tablesListInstance contentLoaded] ) {
		[self loadTable:(NSString *)[tablesListInstance table]];
	}
	
	tableColumns = [tableContentView tableColumns];
	enumerator = [tableColumns objectEnumerator];
	
	//set field names as first line
	while ( (tableColumn = [enumerator nextObject]) ) {
		[tempRow addObject:[[tableColumn headerCell] stringValue]];
	}
	[currentResult addObject:[NSArray arrayWithArray:tempRow]];
	
	//add rows
	for ( i = 0 ; i < [self numberOfRowsInTableView:nil] ; i++) {
		[tempRow removeAllObjects];
		enumerator = [tableColumns objectEnumerator];
		while ( (tableColumn = [enumerator nextObject]) ) {
			[tempRow addObject:[self tableView:nil objectValueForTableColumn:tableColumn row:i]];
		}
		[currentResult addObject:[NSArray arrayWithArray:tempRow]];
	}
	return currentResult;
}


//additional methods
- (void)setConnection:(CMMCPConnection *)theConnection
/*
 sets the connection (received from TableDocument) and makes things that have to be done only once 
 */
{
	mySQLConnection = theConnection;
	
	[tableContentView setVerticalMotionCanBeginDrag:NO];
	
	prefs = [[NSUserDefaults standardUserDefaults] retain];
	if ( [prefs boolForKey:@"useMonospacedFonts"] ) {
		[argumentField setFont:[NSFont fontWithName:@"Monaco" size:10]];
		[limitRowsField setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
		[editTextView setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
	} else {
		[editTextView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}
	[hexTextView setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
	[limitRowsStepper setEnabled:NO];
	if ( [prefs boolForKey:@"limitRows"] ) {
		[limitRowsText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Limited to %d rows starting with row", @"text showing the number of rows the result is limited to"),
									   [prefs integerForKey:@"limitRowsValue"]]];
	} else {
		[limitRowsText setStringValue:NSLocalizedString(@"No limit", @"text showing that the result isn't limited")];
		[limitRowsField setStringValue:@""];
	}
}

- (IBAction)setCompareTypes:(id)sender
/*
 sets the compare types for the filter and the appropriate formatter for the textField
 */
{
	NSArray *stringFields = [NSArray arrayWithObjects:@"varstring", @"string", @"tinyblob", @"blob", @"mediumblob", @"longblob", @"set", @"enum", nil];
	NSArray *stringTypes = [NSArray arrayWithObjects:NSLocalizedString(@"is", @"popup menuitem for field IS value"), NSLocalizedString(@"is not", @"popup menuitem for field IS NOT value"), NSLocalizedString(@"contains", @"popup menuitem for field CONTAINS value"), NSLocalizedString(@"contains not", @"popup menuitem for field CONTAINS NOT value"), @"IN", nil];
	NSArray *numberFields = [NSArray arrayWithObjects:@"tiny", @"short", @"long", @"int24", @"longlong", @"decimal", @"float", @"double", nil];
	NSArray *numberTypes = [NSArray arrayWithObjects:@"=", @"≠", @">", @"<", @"≥", @"≤", @"IN", nil];
	NSArray *dateFields = [NSArray arrayWithObjects:@"timestamp", @"date", @"time", @"datetime", @"year", nil];
	NSArray *dateTypes = [NSArray arrayWithObjects:NSLocalizedString(@"is", @"popup menuitem for field IS value"), NSLocalizedString(@"is not", @"popup menuitem for field IS NOT value"), NSLocalizedString(@"older than", @"popup menuitem for field OLDER THAN value"), NSLocalizedString(@"younger than", @"popup menuitem for field YOUNGER THAN value"), NSLocalizedString(@"older than or equal to", @"popup menuitem for field OLDER THAN OR EQUAL TO value"), NSLocalizedString(@"younger than or equal to", @"popup menuitem for field YOUNGER THAN OR EQUAL TO value"), nil];
	NSString *fieldType = [NSString stringWithString:[fieldTypes objectAtIndex:[[fieldField selectedItem] tag]]];
	//	NSNumberFormatter *numberFormatter;
	int i;
	
	//	numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
	//	[numberFormatter setFormat:@"0.####################"];
	
	[compareField removeAllItems];
	//	[argumentField setStringValue:@""];
	
	//why do we get "string" for enum fields? (error in framework?)
	if ( [stringFields containsObject:fieldType] ) {
		[compareField addItemsWithTitles:stringTypes];
		compareType = @"string";
		//		[argumentField setFormatter:nil];
	} else if ( [numberFields containsObject:fieldType] ) {
		[compareField addItemsWithTitles:numberTypes];
		compareType = @"number";
		//		[argumentField setFormatter:numberFormatter];
	} else if ( [dateFields containsObject:fieldType] ) {
		[compareField addItemsWithTitles:dateTypes];
		compareType = @"date";
		/*
		 if ([fieldType isEqualToString:@"timestamp"]) {
		 [argumentField setFormatter:[[NSDateFormatter alloc]
		 initWithDateFormat:@"%Y-%m-%d %H:%M:%S" allowNaturalLanguage:YES]];
		 }
		 if ([fieldType isEqualToString:@"datetime"]) {
		 [argumentField setFormatter:[[NSDateFormatter alloc] initWithDateFormat:@"%Y-%m-%d %H:%M:%S" allowNaturalLanguage:YES]];
		 }
		 if ([fieldType isEqualToString:@"date"]) {
		 [argumentField setFormatter:[[NSDateFormatter alloc] initWithDateFormat:@"%Y-%m-%d" allowNaturalLanguage:YES]];
		 }
		 if ([fieldType isEqualToString:@"time"]) {
		 [argumentField setFormatter:[[NSDateFormatter alloc] initWithDateFormat:@"%H:%M:%S" allowNaturalLanguage:YES]];
		 }
		 if ([fieldType isEqualToString:@"year"]) {
		 [argumentField setFormatter:[[NSDateFormatter alloc] initWithDateFormat:@"%Y" allowNaturalLanguage:YES]];
		 }
		 */
	} else {
		NSLog(@"ERROR: unknown type for comparision: %@", fieldType);
	}
	
	for ( i = 0 ; i < [compareField numberOfItems] ; i++ ) {
		[[compareField itemAtIndex:i] setTag:i];
	}
	
	// set focus on argumentField
	[argumentField selectText:self];
}

- (IBAction)stepLimitRows:(id)sender
/*
 steps the start row up or down (+/- limitRowsValue)
 */
{
	if ( [limitRowsStepper intValue] > 0 ) {
		[limitRowsField setIntValue:[limitRowsField intValue]+[prefs integerForKey:@"limitRowsValue"]];
	} else {
		if ( ([limitRowsField intValue]-[prefs integerForKey:@"limitRowsValue"]) < 1 ) {
			[limitRowsField setIntValue:1];
		} else {
			[limitRowsField setIntValue:[limitRowsField intValue]-[prefs integerForKey:@"limitRowsValue"]];
		}
	}
	[limitRowsStepper setIntValue:0];
}

- (NSArray *)fetchResultAsArray:(CMMCPResult *)theResult
/*
 fetches the result as an array with a dictionary for each row in it
 */
{
	NSMutableArray *tempResult = [NSMutableArray array];
	NSDictionary *tempRow;
	NSMutableDictionary *modifiedRow = [NSMutableDictionary dictionary];
	NSEnumerator *enumerator;
	id key;
	int i,j;
	
	for ( i = 0 ; i < [theResult numOfRows] ; i++ ) {
		[theResult dataSeek:i];
		tempRow = [theResult fetchRowAsDictionary];
		enumerator = [tempRow keyEnumerator];
		while ( key = [enumerator nextObject] ) {
			if ( [[tempRow objectForKey:key] isMemberOfClass:[NSNull class]] ) {
				[modifiedRow setObject:[prefs stringForKey:@"nullValue"] forKey:key];
				/*
				 //NSData objects now decoded in tableView:objectValueForTableColumn:row
				 //object in result remains a NSData object
				 } else if ( [[tempRow objectForKey:key] isKindOfClass:[NSData class]] ) {
				 [modifiedRow setObject:[[NSString alloc] initWithData:[tempRow objectForKey:key] encoding:[mySQLConnection encoding]]
				 forKey:key];
				 */
			} else {
				[modifiedRow setObject:[tempRow objectForKey:key] forKey:key];
			}
			//add values for hidden blob and text fields
			if ( [prefs boolForKey:@"dontShowBlob"] ) {
				for ( j = 0 ; j < [fieldTypes count] ; j++ ) {
					if ( [self isBlobOrText:[fieldTypes objectAtIndex:j]] ) {
						[modifiedRow setObject:NSLocalizedString(@"- blob or text -", @"value shown for hidden blob and text fields") forKey:[fieldNames objectAtIndex:j]];
					}
				}
			}
		}
		[tempResult addObject:[NSMutableDictionary dictionaryWithDictionary:modifiedRow]];
	}
	return tempResult;
}

- (BOOL)addRowToDB
/*
 tries to write row to mysql-db
 returns YES if row written to db, otherwies NO
 returns YES if no row is beeing edited and nothing has to be written to db
 */
{
	int rowIndex = [tableContentView selectedRow];
	NSMutableArray *fieldValues = [[NSMutableArray alloc] init];
	NSMutableString *queryString;
	NSString *query;
	CMMCPResult *queryResult;
	id rowObject;
	NSMutableString *rowValue = [NSMutableString string];
	NSString *currentTime = [[NSDate date] descriptionWithCalendarFormat:@"%H:%M:%S" timeZone:nil locale:nil];
	int i;
	
	if ( !isEditingRow || rowIndex == -1) {
		[fieldValues release];
		return YES;
	}
	
	//get field values
	for ( i=0 ; i < [fieldNames count] ; i++) {
		rowObject = [[filteredResult objectAtIndex:rowIndex] objectForKey:[fieldNames objectAtIndex:i]];
		//convert the object to a string (here we can add special treatment for date-, number- and data-fields)
		if ( [[rowObject description] isEqualToString:[prefs stringForKey:@"nullValue"]] ||
			([rowObject isMemberOfClass:[NSString class]] && [[rowObject description] isEqualToString:@""]) ) {
			//NULL when user entered the nullValue string defined in the prefs or when a number field isn't set
			//	problem: when a number isn't set, sequel-pro enters 0
			//	-> second if argument isn't necessary!
			[rowValue setString:@"NULL"];
		} else {
			if ( [rowObject isKindOfClass:[NSCalendarDate class]] ) {
				//				[rowValue setString:[NSString stringWithFormat:@"\"%@\"", [mySQLConnection prepareString:[rowObject description]]]];
				[rowValue setString:[NSString stringWithFormat:@"'%@'", [mySQLConnection prepareString:[rowObject description]]]];
			} else if ( [rowObject isKindOfClass:[NSNumber class]] ) {
				[rowValue setString:[rowObject stringValue]];
			} else if ( [rowObject isKindOfClass:[NSData class]] ) {
				//problem: if a blob field is edited, it becomes a string and is not more prepared as binary data
				//		but probably blob fields are corrupted before, when they decoded in the tableView method
				//				[rowValue setString:[NSString stringWithFormat:@"\"%@\"", [mySQLConnection prepareBinaryData:rowObject]]];
				[rowValue setString:[NSString stringWithFormat:@"'%@'", [mySQLConnection prepareBinaryData:rowObject]]];
			} else {
				//				[rowValue setString:[NSString stringWithFormat:@"\"%@\"", [mySQLConnection prepareString:[rowObject description]]]];
				if ( [[rowObject description] isEqualToString:@"CURRENT_TIMESTAMP"] ) {
					[rowValue setString:@"CURRENT_TIMESTAMP"];
				} else {
					[rowValue setString:[NSString stringWithFormat:@"'%@'", [mySQLConnection prepareString:[rowObject description]]]];
				}
			}
		}
		//escape special characters -> now escaped by framework
		/*
		 for ( j = 0 ; j < [rowValue length] ; j++ ) {
		 if ( [rowValue characterAtIndex:j] == '\\' ) {
		 [rowValue insertString:@"\\" atIndex:j];
		 j++;
		 } else if ( [rowValue characterAtIndex:j] == '"' ) {
		 [rowValue insertString:@"\\" atIndex:j];
		 j++;
		 }
		 }
		 */
		[fieldValues addObject:[NSString stringWithString:rowValue]];
	}
	
	if ( isEditingNewRow ) {
		//INSERT syntax
		queryString = [NSString stringWithFormat:@"INSERT INTO `%@` (`%@`) VALUES (%@)",
					   selectedTable, [fieldNames componentsJoinedByString:@"`,`"], [fieldValues componentsJoinedByString:@","]];
	} else {
		//UPDATE syntax
		queryString = [NSMutableString stringWithFormat:@"UPDATE `%@` SET ", selectedTable];
		for ( i = 0 ; i < [fieldNames count] ; i++ ) {
			if ( i > 0 ) {
				[queryString appendString:@", "];
			}
			[queryString appendString:[NSString stringWithFormat:@"`%@`=%@",
									   [fieldNames objectAtIndex:i], [fieldValues objectAtIndex:i]]];
		}
		[fieldValues release];
		[queryString appendString:[NSString stringWithFormat:@" WHERE %@", [self argumentForRow:-2]]];
	}
	[mySQLConnection queryString:queryString];
	
	//NSLog( @"%@", queryString );
	
	if ( ![mySQLConnection affectedRows] ) {
		//no rows changed
		if ( [prefs boolForKey:@"showError"] ) {
			NSBeginAlertSheet(NSLocalizedString(@"Warning", @"warning"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
							  NSLocalizedString(@"The row was not written to the MySQL database. You probably haven't changed anything.\nReload the table to be sure that the row exists and use a primary key for your table.\n(This error can be turned off in the preferences.)", @"message of panel when no rows have been affected after writing to the db"));
		} else {
			NSBeep();
		}
		[filteredResult replaceObjectAtIndex:rowIndex withObject:[NSMutableDictionary dictionaryWithDictionary:oldRow]];
		isEditingRow = NO;
		isEditingNewRow = NO;
		[tableDocumentInstance showErrorInConsole:[NSString stringWithFormat:NSLocalizedString(@"/* WARNING %@ No rows have been affected */\n", @"warning shown in the console when no rows have been affected after writing to the db"), currentTime]];
		return YES;
	} else if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
		//added new row with success
		isEditingRow = NO;
		if ( isEditingNewRow ) {
			if ( [prefs boolForKey:@"reloadAfterAdding"] ) {
				[self reloadTableValues:self];
				//				if ( sortField )
				[tableContentView deselectAll:self];
			} else {
				//set insertId for fields with auto_increment
				queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW COLUMNS FROM `%@`", selectedTable]];
				for ( i = 0 ; i < [queryResult numOfRows] ; i++ ) {
					[queryResult dataSeek:i];
					rowObject = [queryResult fetchRowAsDictionary];
					if ( [[rowObject objectForKey:@"Extra"] isEqualToString:@"auto_increment"] ) {
						[[filteredResult objectAtIndex:rowIndex] setObject:[NSNumber numberWithLong:[mySQLConnection insertId]]
																	forKey:[rowObject objectForKey:@"Field"]];
					}
				}
				[fullResult addObject:[filteredResult objectAtIndex:rowIndex]];
			}
			isEditingNewRow = NO;
		} else {
			//updated row with success
			if ( [prefs boolForKey:@"reloadAfterEditing"] ) {
				[self reloadTableValues:self];
				//				if ( sortField )
				[tableContentView deselectAll:self];
			} else {
				//				query = [@"SELECT * FROM " stringByAppendingString:selectedTable];
				query = [NSString stringWithFormat:@"SELECT %@ FROM `%@`", [self fieldListForQuery], selectedTable];
				if ( sortField ) {
					//					query = [query stringByAppendingString:[NSString stringWithFormat:@" ORDER BY `%@`", sortField]];
					query = [NSString stringWithFormat:@"%@ ORDER BY `%@`", query, sortField];
					if ( isDesc )
						query = [query stringByAppendingString:@" DESC"];
				}
				if ( [prefs boolForKey:@"limitRows"] ) {
					if ( [limitRowsField intValue] <= 0 ) {
						[limitRowsField setStringValue:@"1"];
					}
					query = [query stringByAppendingString:
							 [NSString stringWithFormat:@" LIMIT %d,%d",
							  [limitRowsField intValue]-1, [prefs integerForKey:@"limitRowsValue"]]];
				}
				queryResult = [mySQLConnection queryString:query];
				//				[fullResult setArray:[[self fetchResultAsArray:queryResult] retain]];
				[fullResult setArray:[self fetchResultAsArray:queryResult]];
			}
		}
		return YES;
	} else {
		//error in mysql-query
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), NSLocalizedString(@"Cancel", @"cancel button"), nil, tableWindow, self, @selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addrow",
						  [NSString stringWithFormat:NSLocalizedString(@"Couldn't write row.\nMySQL said: %@", @"message of panel when error while adding row to db"), [mySQLConnection getLastErrorMessage]]);
		return NO;
	}
}

- (NSString *)argumentForRow:(int)row
/*
 returns the WHERE argument to identify a row
 if row is -2, it uses the oldRow
 if there is one, it uses the primary key, otherwise uses all fields as argument and sets LIMIT to 1
 */
{
	CMMCPResult *theResult;
	NSDictionary *theRow;
	id tempValue;
	NSMutableString *value = [NSMutableString string];
	NSMutableString *argument = [NSMutableString string];
	int i,j;
	NSEnumerator *enumerator;
	id type;
	BOOL blob = NO;
	NSArray *numberFields = [NSArray arrayWithObjects:@"tiny", @"short", @"long", @"int24", @"longlong", @"decimal", @"float", @"double", nil];
	
	if ( row == -1 )
		return @"";
	
	//get primary key if there is one
	/*
	 theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW INDEX FROM `%@`", selectedTable]];
	 for ( i = 0 ; i < [theResult numOfRows] ; i++ ) {
	 [theResult dataSeek:i];
	 theRow = [theResult fetchRowAsDictionary];
	 if ( [[theRow objectForKey:@"Key_name"] isEqualToString:@"PRIMARY"] ) {
	 [keys addObject:[theRow objectForKey:@"Column_name"]];
	 }
	 }
	 */
	if ( !keys ) {
		setLimit = NO;
		keys = [[NSMutableArray alloc] init];
		theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW COLUMNS FROM `%@`", selectedTable]];
		for ( i = 0 ; i < [theResult numOfRows] ; i++ ) {
			[theResult dataSeek:i];
			theRow = [theResult fetchRowAsDictionary];
			if ( [[theRow objectForKey:@"Key"] isEqualToString:@"PRI"] ) {
				[keys addObject:[theRow objectForKey:@"Field"]];
			}
		}
	}
	
	if ( ![keys count] ) {
		//if there is no primary key, take all fields as argument
		//here we have a problem when dontShowBlob == YES (we don't have the right values to use in the WHERE statement)
		[keys setArray:fieldNames];
		setLimit = YES;
		enumerator = [fieldTypes objectEnumerator];
		while ( (type = [enumerator nextObject]) ) {
			if ( [self isBlobOrText:type] ) {
				blob = YES;
			}
		}
		if ( [prefs boolForKey:@"dontShowBlob"] && blob ) {
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
							  NSLocalizedString(@"You can't hide blob and text fields when working with tables without index.", @"message of panel when trying to edit tables without index and with hidden blob/text fields"));
			[keys removeAllObjects];
			[tableContentView deselectAll:self];
			return @"";
		}
	}
	for ( i = 0 ; i < [keys count] ; i++ ) {
		if ( i )
			[argument appendString:@" AND "];
		if ( row >= 0 ) {
			//use selected row
			tempValue = [[filteredResult objectAtIndex:row] objectForKey:[keys objectAtIndex:i]];
		} else {
			//use oldRow
			tempValue = [oldRow objectForKey:[keys objectAtIndex:i]];
		}
		if ( [tempValue isKindOfClass:[NSData class]] ) {
			[value setString:[[NSString alloc] initWithData:tempValue encoding:[mySQLConnection encoding]]];
		} else {
			[value setString:[tempValue description]];
		}
		
		if ( [value isEqualToString:[prefs stringForKey:@"nullValue"]] ) {
			[value setString:@"NULL"];
		} else {
			//escape special characters (in WHERE statement!)
			for ( j = 0 ; j < [value length] ; j++ ) {
				if ( [value characterAtIndex:j] == '\\' ) {
					[value insertString:@"\\" atIndex:j];
					j++;
				}
			}
			[value setString:[mySQLConnection prepareString:value]];
			for ( j = 0 ; j < [value length] ; j++ ) {
				if ( [value characterAtIndex:j] == '%' ||
					[value characterAtIndex:j] == '_' ) {
					[value insertString:@"\\" atIndex:j];
					j++;
				}
			}
			//			[value setString:[NSString stringWithFormat:@"\"%@\"", value]];
			[value setString:[NSString stringWithFormat:@"'%@'", value]];
		}
		if ( [value isEqualToString:@"NULL"] ) {
			[argument appendString:[NSString stringWithFormat:@"`%@` IS NULL", [keys objectAtIndex:i]]];
		} else {
			if ( [numberFields containsObject:[fieldTypes objectAtIndex:[fieldNames indexOfObject:[keys objectAtIndex:i]]]] ) {
				[argument appendString:[NSString stringWithFormat:@"`%@` = %@", [keys objectAtIndex:i], value]];
			} else {
				[argument appendString:[NSString stringWithFormat:@"`%@` LIKE %@", [keys objectAtIndex:i], value]];
			}
		}
	}
	if ( setLimit )
		[argument appendString:@" LIMIT 1"];
	return argument;
}

- (BOOL)isBlobOrText:(NSString *)fieldType
/*
 returns YES if fieldType is some kind of blob or text. afaik the type of this fields is always blob, but better we test it...
 it would be nice to know if it is blob or text, but mysql doesn't want to tell it...
 */
{
	if ( [fieldType isEqualToString:@"tinyblob"] || [fieldType isEqualToString:@"blob"] ||
		[fieldType isEqualToString:@"mediumblob"] || [fieldType isEqualToString:@"longblob"] ) {
		return YES;
	} else {
		return NO;
	}
}

- (NSString *)fieldListForQuery
/*
 returns * if dontShowBlob == NO
 returns a comma-separated list of all fields which aren't of type blob or text if dontShowBlob == YES
 */
{
	int i;
	NSMutableArray *fields = [NSMutableArray array];
	
	if ( [prefs boolForKey:@"dontShowBlob"] ) {
		for ( i = 0 ; i < [fieldTypes count] ; i++ ) {
			if ( ![self isBlobOrText:[fieldTypes objectAtIndex:i]] ) {
				[fields addObject:[fieldNames objectAtIndex:i]];
			}
		}
		if ( [fields count] == 0 ) {
			return [NSString stringWithFormat:@"`%@`", [fieldNames objectAtIndex:0]];
		} else {
			return [NSString stringWithFormat:@"`%@`", [fields componentsJoinedByString:@"`,`"]];
		}
	} else {
		return @"*";
	}
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
/*
 if contextInfo == addrow: remain in edit-mode if user hits OK, otherwise cancel editing
 if contextInfo == removerow: removes row if user hits OK
 */
{
	NSEnumerator *enumerator = [tableContentView selectedRowEnumerator];
	NSNumber *index;
	NSMutableArray *tempArray = [NSMutableArray array];
	NSMutableArray *tempResult = [NSMutableArray array];
	NSString *queryString;
	CMMCPResult *queryResult;
	int i, errors;
	
	[sheet orderOut:self];
	
	if ( [contextInfo isEqualToString:@"addrow"] ) {
		if ( returnCode == NSAlertDefaultReturn ) {
			//problem: reenter edit mode doesn't function
			[tableContentView editColumn:0 row:[tableContentView selectedRow] withEvent:nil select:YES];
		} else {
			if ( !isEditingNewRow ) {
				[filteredResult replaceObjectAtIndex:[tableContentView selectedRow]
										  withObject:[NSMutableDictionary dictionaryWithDictionary:oldRow]];
				isEditingRow = NO;
			} else {
				[filteredResult removeObjectAtIndex:[tableContentView selectedRow]];
				isEditingRow = NO;
				isEditingNewRow = NO;
			}
		}
		[tableContentView reloadData];
	} else if ( [contextInfo isEqualToString:@"removeallrows"] ) {
		if ( returnCode == NSAlertDefaultReturn ) {
			/*
			 if ( ([tableContentView numberOfSelectedRows] == [self numberOfRowsInTableView:tableContentView]) &&
			 areShowingAllRows &&
			 ([tableContentView numberOfSelectedRows] < [prefs integerForKey:@"limitRowsValue"]) ) {
			 */
			[mySQLConnection queryString:[NSString stringWithFormat:@"DELETE FROM `%@`", selectedTable]];
			if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
				[self reloadTable:self];
			} else {
				NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
								  [NSString stringWithFormat:NSLocalizedString(@"Couldn't remove rows.\nMySQL said: %@", @"message of panel when field cannot be removed"),
								   [mySQLConnection getLastErrorMessage]]);
			}
		}
	} else if ( [contextInfo isEqualToString:@"removerow"] ) {
		if ( returnCode == NSAlertDefaultReturn ) {
			errors = 0;
			
			while ( (index = [enumerator nextObject]) ) {
				[mySQLConnection queryString:[NSString stringWithFormat:@"DELETE FROM `%@` WHERE %@",
											  selectedTable, [self argumentForRow:[index intValue]]]];
				if ( ![mySQLConnection affectedRows] ) {
					//no rows deleted
					errors++;
				} else if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
					//rows deleted with success
					[tempArray addObject:index];
				} else {
					//error in mysql-query
					errors++;
				}
			}
			
			if ( errors ) {
				NSBeginAlertSheet(NSLocalizedString(@"Warning", @"warning"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil, [NSString stringWithFormat:NSLocalizedString(@"%d rows have not been removed. Reload the table to be sure that the rows exist and use a primary key for your table.", @"message of panel when not all selected fields have been deleted"), errors]);
			}
			
			//do deleting (after enumerating)
			if ( [prefs boolForKey:@"reloadAfterRemoving"] ) {
				[self reloadTableValues:self];
			} else {
				for ( i = 0 ; i < [filteredResult count] ; i++ ) {
					if ( ![tempArray containsObject:[NSNumber numberWithInt:i]] )
						[tempResult addObject:[filteredResult objectAtIndex:i]];
				}
				[filteredResult setArray:tempResult];
				numRows = [self getNumberOfRows];
				if ( !areShowingAllRows ) {
					//					queryString = [@"SELECT * FROM " stringByAppendingString:selectedTable];
					queryString = [NSString stringWithFormat:@"SELECT %@ FROM `%@`", [self fieldListForQuery], selectedTable];
					if ( sortField ) {
						//						queryString = [queryString stringByAppendingString:[NSString stringWithFormat:@" ORDER BY `%@`", sortField]];
						queryString = [NSString stringWithFormat:@"%@ ORDER BY `%@`", queryString, sortField];
						if ( isDesc )
							queryString = [queryString stringByAppendingString:@" DESC"];
					}
					if ( [prefs boolForKey:@"limitRows"] ) {
						if ( [limitRowsField intValue] <= 0 ) {
							[limitRowsField setStringValue:@"1"];
						}
						queryString = [queryString stringByAppendingString:
									   [NSString stringWithFormat:@" LIMIT %d,%d",
										[limitRowsField intValue]-1, [prefs integerForKey:@"limitRowsValue"]]];
					}
					queryResult = [mySQLConnection queryString:queryString];
					//						[fullResult setArray:[[self fetchResultAsArray:queryResult] retain]];
					[fullResult setArray:[self fetchResultAsArray:queryResult]];
					[tableContentView reloadData];
					[countText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%d rows of %d selected", @"text showing how many rows are in the filtered result"),
											   [filteredResult count], numRows]];
				} else {
					[fullResult setArray:filteredResult];
					[tableContentView reloadData];
					[countText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%d rows in table", @"text showing how many rows are in the result"), numRows]];
				}
			}
			[tableContentView deselectAll:self];
		}
	}
}

- (int)getNumberOfRows
/*
 returns the number of rows in the selected table
 queries the number from mysql if enabled in prefs and result is limited, otherwise just return the fullResult count
 */
{
	if ( [prefs boolForKey:@"limitRows"] && [prefs boolForKey:@"fetchRowCount"] ) {
		numRows = [self fetchNumberOfRows];
	} else {
		numRows = [fullResult count];
	}
	return numRows;
}

- (int)fetchNumberOfRows
/*
 fetches the number of rows in the selected table using a "SELECT COUNT(*)" query and return it
 */
{
	return [[[[mySQLConnection queryString:[NSString stringWithFormat:@"SELECT COUNT(*) FROM `%@`", selectedTable]] fetchRowAsArray] objectAtIndex:0] intValue];
}


//tableView datasource methods
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [filteredResult count];
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
	id theRow, theValue;
	
	theRow = [filteredResult objectAtIndex:rowIndex];
	theValue = [theRow objectForKey:[aTableColumn identifier]];
	
	if ( [theValue isKindOfClass:[NSData class]] ) {
		theValue = [[NSString alloc] initWithData:theValue encoding:[mySQLConnection encoding]];
		//show only first 50 characters to speed up interface (but return everything when this method is used to return the current result)
		//		if ( ([theValue length] > 100) && aTableView ) {
	}
	
//	if ( ([(NSString *)theValue length] > 100) && aTableView ) {
//		theValue = [NSString stringWithFormat:@"%@(...)", [theValue substringToIndex:100]];
//	}
	
	return theValue;
}

- (void)tableView:(NSTableView *)aTableView
   setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)aTableColumn
			  row:(int)rowIndex
{
	if ( !isEditingRow ) {
		[oldRow setDictionary:[filteredResult objectAtIndex:rowIndex]];
		isEditingRow = YES;
	}
	if ( anObject ) {
		[[filteredResult objectAtIndex:rowIndex] setObject:anObject forKey:[aTableColumn identifier]];
	} else {
		[[filteredResult objectAtIndex:rowIndex] setObject:@"" forKey:[aTableColumn identifier]];
	}
}

//tableView delegate methods
- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn
/*
 sorts the tableView by the clicked column
 if clicked twice, order is descending
 */
{
	NSString *queryString;
	NSImage *upSortImage;
	NSImage *downSortImage;
	CMMCPResult *queryResult;
	
	if ( [selectedTable isEqualToString:@""] || !selectedTable )
		return;
	if ( ![self selectionShouldChangeInTableView:nil] )
		return;
	
	//query started
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];
	
	upSortImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"sort-up" ofType:@"tiff"]];
	[upSortImage autorelease];
	downSortImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"sort-down" ofType:@"tiff"]];
	[downSortImage autorelease];
	
	//sets order descending if a header is clicked twice
	if ( [[tableColumn identifier] isEqualTo:sortField] ) {
		if ( isDesc ) {
			isDesc = NO;
		} else {
			isDesc = YES;
		}
	} else {
		isDesc = NO;
		[tableContentView setIndicatorImage:nil inTableColumn:[tableContentView tableColumnWithIdentifier:sortField]];
	}
	sortField = [tableColumn identifier];
	
	//make queryString and perform query
	queryString = [NSString stringWithFormat:@"SELECT %@ FROM `%@` ORDER BY `%@`", [self fieldListForQuery],
				   selectedTable, sortField];
	if ( isDesc )
		queryString = [queryString stringByAppendingString:@" DESC"];
	if ( [prefs boolForKey:@"limitRows"] ) {
		if ( [limitRowsField intValue] <= 0 ) {
			[limitRowsField setStringValue:@"1"];
		}
		queryString = [queryString stringByAppendingString:
					   [NSString stringWithFormat:@" LIMIT %d,%d",
						[limitRowsField intValue]-1, [prefs integerForKey:@"limitRowsValue"]]];
	}
	queryResult = [mySQLConnection queryString:queryString];
	
	//	[fullResult setArray:[[self fetchResultAsArray:queryResult] retain]];
	[fullResult setArray:[self fetchResultAsArray:queryResult]];
	
	if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
						  [NSString stringWithFormat:NSLocalizedString(@"Couldn't sort table. MySQL said: %@", @"message of panel when sorting of table failed"), [mySQLConnection getLastErrorMessage]]);
		return;
	}
	
	//sets highlight and indicatorImage
	[tableContentView setHighlightedTableColumn:tableColumn];
	if ( isDesc ) {
		[tableContentView setIndicatorImage:downSortImage inTableColumn:tableColumn];
	} else {
		[tableContentView setIndicatorImage:upSortImage inTableColumn:tableColumn];
	}
	
	//query finished
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
	
	//if filter is activated filters the result, otherwise shows fullResult
	if ( !areShowingAllRows ) {
		[self filterTable:self];
	} else {
		[filteredResult setArray:fullResult];
		[tableContentView reloadData];
	}
}

- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView
{
	/*
	 int row = [tableContentView editedRow];
	 int column = [tableContentView editedColumn];
	 NSTableColumn *tableColumn;
	 NSCell *cell;
	 
	 if ( row != -1 ) {
	 tableColumn = [[tableContentView tableColumns] objectAtIndex:column]; 
	 cell = [tableColumn dataCellForRow:row]; 
	 [cell endEditing:[tableContentView currentEditor]]; 
	 }
	 */
	//end editing (otherwise problems when user hits reload button)
	[tableWindow endEditingFor:nil];
	
	return [self addRowToDB];
}

- (void)tableViewColumnDidResize:(NSNotification *)aNotification
/*
 saves the new column size in the preferences
 */
{
	// sometimes the column has no identifier. I can't figure out what is causing it, so we just skip over this item
	if (![[[aNotification userInfo] objectForKey:@"NSTableColumn"] identifier])
		return;
	
	NSMutableDictionary *tableColumnWidths;
	NSString *database = [NSString stringWithFormat:@"%@@%@", [tableDocumentInstance database], [tableDocumentInstance host]];
	NSString *table = (NSString *)[tablesListInstance table];
	
	// get tableColumnWidths object
	if ( [prefs objectForKey:@"tableColumnWidths"] != nil ) {
		tableColumnWidths = [NSMutableDictionary dictionaryWithDictionary:[prefs objectForKey:@"tableColumnWidths"]];
	} else {
		tableColumnWidths = [NSMutableDictionary dictionary];
	}
	// get database object
	if  ( [tableColumnWidths objectForKey:database] == nil ) {
		[tableColumnWidths setObject:[NSMutableDictionary dictionary] forKey:database];
	} else {
		[tableColumnWidths setObject:[[tableColumnWidths objectForKey:database] mutableCopy] forKey:database];
	}
	// get table object
	if  ( [[tableColumnWidths objectForKey:database] objectForKey:table] == nil ) {
		[[tableColumnWidths objectForKey:database] setObject:[NSMutableDictionary dictionary] forKey:table];
	} else {
		[[tableColumnWidths objectForKey:database] setObject:[[[tableColumnWidths objectForKey:database] objectForKey:table] mutableCopy] forKey:table];
	}
	// save column size
	[[[tableColumnWidths objectForKey:database] objectForKey:table] setObject:[NSNumber numberWithFloat:[[[aNotification userInfo] objectForKey:@"NSTableColumn"] width]] forKey:[[[aNotification userInfo] objectForKey:@"NSTableColumn"] identifier]];
	[prefs setObject:tableColumnWidths forKey:@"tableColumnWidths"];
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
/*
 opens sheet if multipleLineEditingButton is clicked or field is a hidden blob or text field
 */
{
	NSEnumerator *enumerator;
	id type;
	BOOL blob = NO;
	NSDictionary *tempRow;
	NSMutableDictionary *modifiedRow = [NSMutableDictionary dictionary];
	id key;
	int code;
	NSString *query;
	CMMCPResult *tempResult;
	id theValue;
	BOOL columnIsBlob = NO;
	//	int i;
	//	NSArray *columns = [aTableView tableColumns];
	
	if ( [prefs boolForKey:@"dontShowBlob"] && !isEditingRow ) {
		//get all row values if dontShowBlob == YES and table contains blob or text field and isEditingRow = NO
		enumerator = [fieldTypes objectEnumerator];
		while ( (type = [enumerator nextObject]) ) {
			if ( [self isBlobOrText:type] ) {
				blob = YES;
			}
		}
		
		if ( blob ) {
			query = [NSString stringWithFormat:@"SELECT * FROM `%@` WHERE %@",
					 selectedTable, [self argumentForRow:[tableContentView selectedRow]]];
			tempResult = [mySQLConnection queryString:query];
			if ( ![tempResult numOfRows] ) {
				NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
								  NSLocalizedString(@"Couldn't load the row. Reload the table to be sure that the row exists and use a primary key for your table.", @"message of panel when loading of row failed"));
				return NO;
			}
			tempRow = [tempResult fetchRowAsDictionary];
			enumerator = [tempRow keyEnumerator];
			while ( key = [enumerator nextObject] ) {
				if ( [[tempRow objectForKey:key] isMemberOfClass:[NSNull class]] ) {
					[modifiedRow setObject:[prefs stringForKey:@"nullValue"] forKey:key];
				} else {
					[modifiedRow setObject:[tempRow objectForKey:key] forKey:key];
				}
			}
			[filteredResult replaceObjectAtIndex:rowIndex
									  withObject:[NSMutableDictionary dictionaryWithDictionary:modifiedRow]];
			[tableContentView reloadData];
		}
	}
	
	/*
	 // find the column we're trying to edit
	 for ( i = 0; i < [columns count]; i++ ) {
	 if ( [columns objectAtIndex:i] == aTableColumn ) {
	 // this flag will let us determine if we should "force" multi-line edit.
	 columnIsBlob = [self isBlobOrText:[fieldTypes objectAtIndex:i]];
	 break;
	 }
	 }
	 */
	//is the column a blob field -> if YES force sheet editing
	if ( [self isBlobOrText:[fieldTypes objectAtIndex:[fieldNames indexOfObject:[aTableColumn identifier]]]] ) {
		columnIsBlob = YES;
	}
	
	if ( [multipleLineEditingButton state] == NSOnState || columnIsBlob ) {
		theValue = [[filteredResult objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
		NSImage *image = nil;
		editData = [theValue retain];
		
		if ( [theValue isKindOfClass:[NSData class]] ) {
			image = [[NSImage alloc] initWithData:theValue];
			[hexTextView setString:[self dataToHex:theValue]];
			/*
			 // update displayed font to monospace
			 NSFont *font = [NSFont fontWithName:@"Courier" size:12.0f];
			 NSRange hexRange = { 0, [[hexTextView string] length] - 1 };
			 [hexTextView setFont:font range:hexRange];
			 */
			theValue = [[NSString alloc] initWithData:theValue encoding:[mySQLConnection encoding]];
		} else {
			[hexTextView setString:@""];
			theValue = [theValue description];
		}
		
		[editImage setImage:image];
		[editTextView setString:theValue];
		[editTextView setSelectedRange:NSMakeRange(0,[[editTextView string] length])];
		//different sheets for date (with up/down arrows), number and text
		[NSApp beginSheet:editSheet
		   modalForWindow:tableWindow modalDelegate:self
		   didEndSelector:nil contextInfo:nil];
		code = [NSApp runModalForWindow:editSheet];
		
		[NSApp endSheet:editSheet];
		[editSheet orderOut:nil];
		
		if ( code ) {
			if ( !isEditingRow ) {
				[oldRow setDictionary:[filteredResult objectAtIndex:rowIndex]];
				isEditingRow = YES;
			}
			
			[[filteredResult objectAtIndex:rowIndex] setObject:[editData copy]
														forKey:[aTableColumn identifier]];
			
			// clean up
			[editImage setImage:nil];
			[editTextView setString:@""];
			[hexTextView setString:@""];
			if ( editData ) {
				[editData release];
			}
		}
		return NO;
	} else {
		return YES;
	}
}

- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray*)rows 
	 toPasteboard:(NSPasteboard*)pboard
/*
 enable drag from tableview
 */
{	
	if ( tableView == tableContentView )
	{
		NSString *tmp = [tableContentView draggedRowsAsTabString:rows];
		
		if ( nil != tmp )
		{
			[pboard declareTypes:[NSArray arrayWithObjects: NSTabularTextPboardType, 
								  NSStringPboardType, nil]
						   owner:nil];
			
			[pboard setString:tmp forType:NSStringPboardType];
			[pboard setString:tmp forType:NSTabularTextPboardType];
			return YES;
		}
	}
	return NO;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
/*
 traps enter and esc an make/cancel editing without entering next row
 */
{
	int row, column, i;
	
	row = [tableContentView editedRow];
	column = [tableContentView editedColumn];
	
	if (  [textView methodForSelector:command] == [textView methodForSelector:@selector(insertNewline:)] ||
		[textView methodForSelector:command] == [textView methodForSelector:@selector(insertTab:)] ) //trap enter and tab
	{
		//save current line
		[[control window] makeFirstResponder:control];
		if ( column == ( [tableContentView numberOfColumns] - 1 ) ) {
			[self addRowToDB];
			/*
			 if ( [self addRowToDB] &&
			 ( [textView methodForSelector:command] == [textView methodForSelector:@selector(insertTab:)] ) &&
			 !(sortField && ([prefs boolForKey:@"reloadAfterAdding"] || [prefs boolForKey:@"reloadAfterEditing"])) ) {
			 //get in edit-mode of next row if user hit tab (and result isn't sorted and reloaded)
			 if ( row < ([tableContentView numberOfRows] - 1) ) {
			 [tableContentView selectRow:row+1 byExtendingSelection:NO];
			 [tableContentView editColumn:0 row:row+1 withEvent:nil select:YES];
			 } else {
			 [tableContentView selectRow:0 byExtendingSelection:NO];
			 [tableContentView editColumn:0 row:0 withEvent:nil select:YES];	   
			 }
			 }
			 */
		} else {
			//check if next column is a blob column
			i = 1;
			while ( [self isBlobOrText:[fieldTypes objectAtIndex:[fieldNames indexOfObject:[[[tableContentView tableColumns] objectAtIndex:column+i] identifier]]]] ) {
				i++;
				if ( (column+i) >= [tableContentView numberOfColumns] ) {
					//there is no other column after the blob column
					[self addRowToDB];
					return TRUE;
				}
			}
			//edit the column after the blob column
			[tableContentView editColumn:column+i row:row withEvent:nil select:YES];
		}
		return TRUE;
	}
	else if (  [[control window] methodForSelector:command] == [[control window] methodForSelector:@selector(_cancelKey:)] ||
			 [textView methodForSelector:command] == [textView methodForSelector:@selector(complete:)] )  //trap esc
	{
		//abort editing
		[control abortEditing];
		if ( isEditingRow && !isEditingNewRow ) {
			isEditingRow = NO;
			[filteredResult replaceObjectAtIndex:row withObject:[NSMutableDictionary dictionaryWithDictionary:oldRow]];
		} else if ( isEditingNewRow ) {
			isEditingRow = NO;
			isEditingNewRow = NO;
			[filteredResult removeObjectAtIndex:row];
			[tableContentView reloadData];
		}
		return TRUE;
	}
	else
	{
		return FALSE;
	}
}


//textView delegate methods
- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector
/*
 traps enter and return key and closes editSheet instead of inserting a linebreak when user hits return
 */
{
	if ( aTextView == editTextView ) {
		if ( [aTextView methodForSelector:aSelector] == [aTextView methodForSelector:@selector(insertNewline:)] &&
			[[[NSApp currentEvent] characters] isEqualToString:@"\003"] )
		{
			[NSApp stopModalWithCode:1];
			return YES;
		} else {
			return NO;
		}
	}
	return NO;
}


//last but not least

- (void)dealloc
{
	//	NSLog(@"TableContent dealloc");
	
	[editData release];
	[fullResult release];
	[filteredResult release];
	[keys release];
	[oldRow release];
	[fieldNames release];
	[fieldTypes release];
	[compareType release];
	[sortField release];
	[prefs release];
	
	[super dealloc];
}

@end
