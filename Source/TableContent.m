//
//  $Id$
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

#import <MCPKit/MCPKit.h>

#import "TableContent.h"
#import "TableDocument.h"
#import "TablesList.h"
#import "CMImageView.h"
#import "CMCopyTable.h"
#import "SPDataCellFormatter.h"
#import "SPTableData.h"
#import "SPQueryConsole.h"
#import "SPStringAdditions.h"
#import "SPArrayAdditions.h"
#import "SPTextViewAdditions.h"
#import "SPDataAdditions.h"
#import "SPTextAndLinkCell.h"
#import "QLPreviewPanel.h"
#import "SPFieldEditorController.h"

@implementation TableContent

/**
 * Standard init method. Initialize various ivars.
 */
- (id)init
{
	if ((self == [super init])) {
		
		fullResult     = [[NSMutableArray alloc] init];
		filteredResult = [[NSMutableArray alloc] init];
		dataColumns    = [[NSMutableArray alloc] init];
		oldRow         = [[NSMutableArray alloc] init];
		
		selectedTable = nil;
		sortCol       = nil;
		lastField     = nil;
		// editData	  = nil;
		keys		  = nil;
		targetFilterColumn = nil;
		targetFilterValue = nil;

		areShowingAllRows = false;
		currentlyEditingRow = -1;
		
		prefs = [NSUserDefaults standardUserDefaults];
		
		usedQuery = [[NSString alloc] initWithString:@""];
	}
	
	return self;
}

- (void)awakeFromNib
{
	// Set the table content view's vertical gridlines if required
	[tableContentView setGridStyleMask:([prefs boolForKey:@"DisplayTableViewVerticalGridlines"]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
}

/*
 * Loads aTable, retrieving column information and updating the tableViewColumns before
 * reloading table data into the fullResults array and redrawing the table.
 */
- (void)loadTable:(NSString *)aTable
{
	int			i;
	NSNumber	*colWidth, *savedSortCol = nil;
	NSArray *columnNames;
	NSDictionary *columnDefinition;
	NSTableColumn	*theCol;
	NSString	*query;
	MCPResult	*queryResult;
	BOOL		preserveCurrentView = [aTable isEqualToString:selectedTable];
	NSString	*preservedFilterField = nil, *preservedFilterComparison, *preservedFilterValue;

	// Clear the selection, and abort the reload if the user is still editing a row
	[tableContentView deselectAll:self];
	if ( isEditingRow )
		return;

	// Store the newly selected table name
	selectedTable = aTable;
	
	// Reset table key store for use in argumentForRow:
	if (keys) [keys release], keys = nil;

	// Restore the table content view to the top left
	[tableContentView scrollRowToVisible:0];
	[tableContentView scrollColumnToVisible:0];

	// Remove existing columns from the table
	while ([[tableContentView tableColumns] count]) {
		[tableContentView removeTableColumn:NSArrayObjectAtIndex([tableContentView tableColumns], 0)];
	}

	// Reset data column store
	[dataColumns removeAllObjects];

	// If no table has been supplied, reset the view to a blank table and disabled elements.
	// [tableDataInstance tableEncoding] == nil indicates that an error occured while retrieving table data
	if ( [[[tableDataInstance statusValues] objectForKey:@"Rows"] isKindOfClass:[NSNull class]] || [aTable isEqualToString:@""] || !aTable || [tableDataInstance tableEncoding] == nil)
	{
		// Empty the stored data arrays
		[fullResult removeAllObjects];
		[filteredResult removeAllObjects];
		[tableContentView reloadData];
		areShowingAllRows = YES;
		[countText setStringValue:@""];

		// Empty and disable filter options
		[fieldField setEnabled:NO];
		[fieldField removeAllItems];
		[fieldField addItemWithTitle:NSLocalizedString(@"field", @"popup menuitem for field (showing only if disabled)")];
		[compareField setEnabled:NO];
		[compareField removeAllItems];
		[compareField addItemWithTitle:NSLocalizedString(@"is", @"popup menuitem for field IS value")];
		[argumentField setEnabled:NO];
		[argumentField setStringValue:@""];
		[filterButton setEnabled:NO];

		// Empty and disable the limit field
		[limitRowsField setStringValue:@""];
		[limitRowsText setStringValue:NSLocalizedString(@"No limit", @"text showing that the result isn't limited")];
		[limitRowsField setEnabled:NO];
		[limitRowsButton setEnabled:NO];
		[limitRowsStepper setEnabled:NO];

		// Disable table action buttons
		[addButton setEnabled:NO];
		[copyButton setEnabled:NO];
		[removeButton setEnabled:NO];

		return;
	}

	// Post a notification that a query will be performed
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];

	// Retrieve the field names and types for this table from the data cache. This is used when requesting all data as part
	// of the fieldListForQuery method, and also to decide whether or not to preserve the current filter/sort settings.
	[dataColumns addObjectsFromArray:[tableDataInstance columns]];
	columnNames = [tableDataInstance columnNames];
	
	// Retrieve the constraints, and loop through them to add up to one foreign key to each column
	NSArray *constraints = [tableDataInstance getConstraints];
	for (NSDictionary *constraint in constraints) {
		NSString *firstColumn = [[[constraint objectForKey:@"columns"] componentsSeparatedByString:@","] objectAtIndex:0];
		NSString *firstRefColumn = [[[constraint objectForKey:@"ref_columns"] componentsSeparatedByString:@","] objectAtIndex:0];
		int columnIndex = [columnNames indexOfObject:firstColumn];
		if (columnIndex != NSNotFound && ![[dataColumns objectAtIndex:columnIndex] objectForKey:@"foreignkeyreference"]) {
			NSDictionary *refDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
											[constraint objectForKey:@"ref_table"], @"table",
											firstRefColumn, @"column",
											nil];
			NSMutableDictionary *rowDictionary = [NSMutableDictionary dictionaryWithDictionary:[dataColumns objectAtIndex:columnIndex]];
			[rowDictionary setObject:refDictionary forKey:@"foreignkeyreference"];
			[dataColumns replaceObjectAtIndex:columnIndex withObject:rowDictionary];
		}
	}

	// Retrieve the total number of rows of the current table
	// to adjustify "Limit From:"
	maxNumRowsOfCurrentTable = [[[tableDataInstance statusValues] objectForKey:@"Rows"] intValue];

	// Retrieve the number of rows in the table and initially mark all as being visible.
	numRows = [self getNumberOfRows];
	areShowingAllRows = YES;
	
	NSString *nullValue = [prefs objectForKey:@"NullValue"];
	
	// Add the new columns to the table
	for ( i = 0 ; i < [dataColumns count] ; i++ ) {
		columnDefinition = NSArrayObjectAtIndex(dataColumns, i);

		// Set up the column
		theCol = [[NSTableColumn alloc] initWithIdentifier:[columnDefinition objectForKey:@"datacolumnindex"]];
		[[theCol headerCell] setStringValue:[columnDefinition objectForKey:@"name"]];
		[theCol setEditable:YES];
		
		// Set up the data cell depending on the column type
		id dataCell;
		if ([[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"enum"]) {
			dataCell = [[[NSComboBoxCell alloc] initTextCell:@""] autorelease];
			[dataCell setButtonBordered:NO];
			[dataCell setBezeled:NO];
			[dataCell setDrawsBackground:NO];
			[dataCell setCompletes:YES];
			[dataCell setControlSize:NSSmallControlSize];
			// add prefs NULL value representation if NULL value is allowed for that field
			if([[columnDefinition objectForKey:@"null"] boolValue])
				[dataCell addItemWithObjectValue:nullValue];
			[dataCell addItemsWithObjectValues:[columnDefinition objectForKey:@"values"]];

		// Add a foreign key arrow if applicable
		} else if ([columnDefinition objectForKey:@"foreignkeyreference"]) {
			dataCell = [[[SPTextAndLinkCell alloc] initTextCell:@""] autorelease];
			[dataCell setTarget:self action:@selector(clickLinkArrow:)];
		
		// Otherwise instantiate a text-only cell
		} else {
			dataCell = [[[SPTextAndLinkCell alloc] initTextCell:@""] autorelease];
		}
		[dataCell setEditable:YES];

		// Set the line break mode and an NSFormatter subclass which truncates long strings for display
		[dataCell setLineBreakMode:NSLineBreakByTruncatingTail];
		//[dataCell setFormatter:[[SPDataCellFormatter new] autorelease]];

		// Set field length limit if field is a varchar to match varchar length
		if ([[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"string"]) {
			[[dataCell formatter] setTextLimit:[[columnDefinition objectForKey:@"length"] intValue]];
		}
		
		// Set the data cell font according to the preferences
		if ( [prefs boolForKey:@"UseMonospacedFonts"] ) {
			[dataCell setFont:[NSFont fontWithName:@"Monaco" size:10]];
		} else {
			[dataCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}

		// Assign the data cell
		[theCol setDataCell:dataCell];
		
		// Set the width of this column to saved value if exists
		colWidth = [[[[prefs objectForKey:@"tableColumnWidths"] objectForKey:[NSString stringWithFormat:@"%@@%@", [tableDocumentInstance database], [tableDocumentInstance host]]] objectForKey:[tablesListInstance tableName]] objectForKey:[columnDefinition objectForKey:@"name"]];
		if ( colWidth ) {
			[theCol setWidth:[colWidth floatValue]];
		}
		
		// Set the column to be reselected for sorting if appropriate
		if (lastField && [lastField isEqualToString:[columnDefinition objectForKey:@"name"]])
			savedSortCol = [columnDefinition objectForKey:@"datacolumnindex"];
		
		// Add the column to the table
		[tableContentView addTableColumn:theCol];
		[theCol release];
	}

	// If the table has been reloaded and the previously selected sort column is still present, reselect it. 
	if (preserveCurrentView && savedSortCol) {
		theCol = [tableContentView tableColumnWithIdentifier:savedSortCol];
		if (sortCol) [sortCol release];
		sortCol = [savedSortCol copy];
		[tableContentView setHighlightedTableColumn:theCol];
		if ( isDesc ) {
			[tableContentView setIndicatorImage:[NSImage imageNamed:@"NSDescendingSortIndicator"] inTableColumn:theCol];
		} else {
			[tableContentView setIndicatorImage:[NSImage imageNamed:@"NSAscendingSortIndicator"] inTableColumn:theCol];
		}
	
	// Otherwise, clear sorting
	} else {
		if (sortCol) {
			[sortCol release];
			sortCol = nil;
		}
		isDesc = NO;
	}

	// Preserve the stored filter settings if appropriate
	if (!targetFilterColumn && preserveCurrentView && [fieldField isEnabled]) {
		preservedFilterField = [NSString stringWithString:[[fieldField selectedItem] title]];
		preservedFilterComparison = [NSString stringWithString:[[compareField selectedItem] title]];
		preservedFilterValue = [NSString stringWithString:[argumentField stringValue]];
	}

	// Enable and initialize filter fields (with tags for position of menu item and field position)
	[fieldField setEnabled:YES];
	[fieldField removeAllItems];
	[fieldField addItemsWithTitles:columnNames];
	for ( i = 0 ; i < [fieldField numberOfItems] ; i++ ) {
		[[fieldField itemAtIndex:i] setTag:i];
	}
	[compareField setEnabled:YES];
	[self setCompareTypes:self];
	[argumentField setEnabled:YES];
	[argumentField setStringValue:@""];
	[filterButton setEnabled:YES];
	
	// Select the specified target filter settings if set
	if (targetFilterColumn) {
		[fieldField selectItemWithTitle:targetFilterColumn];
		[self setCompareTypes:self];
		if ([targetFilterValue isEqualToString:[prefs objectForKey:@"NullValue"]]) {
			[compareField selectItemWithTitle:@"IS NULL"];
		} else {
			[compareField selectItemAtIndex:0];	// "=", "IS", etc
			[argumentField setStringValue:targetFilterValue];
		}
		areShowingAllRows = NO;
		targetFilterColumn = nil;
		targetFilterValue = nil;

	// Otherwise, restore preserved filter settings if appropriate and valid
	} else if (preserveCurrentView && preservedFilterField != nil && [fieldField itemWithTitle:preservedFilterField]) {
		[fieldField selectItemWithTitle:preservedFilterField];
		[self setCompareTypes:self];
		
		if ([fieldField itemWithTitle:preservedFilterField] && [compareField itemWithTitle:preservedFilterComparison]) {
			[compareField selectItemWithTitle:preservedFilterComparison];
			[argumentField setStringValue:preservedFilterValue];
			areShowingAllRows = NO;
		}
	}

	// Enable or disable the limit fields according to preference setting
	if ( [prefs boolForKey:@"LimitResults"] ) {

		// Attempt to preserve the limit value if it's still valid
		if (!preserveCurrentView || [limitRowsField intValue] < 1 || [limitRowsField intValue] >= numRows) {	
			[limitRowsField setStringValue:@"1"];
		}
		[limitRowsField setEnabled:YES];
		[limitRowsButton setEnabled:YES];
		[limitRowsStepper setEnabled:YES];
		[limitRowsText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Limited to %d rows starting with row", @"text showing the number of rows the result is limited to"),
									   [prefs integerForKey:@"LimitResultsValue"]]];
		if ([prefs integerForKey:@"LimitResultsValue"] < numRows)
			areShowingAllRows = NO;
	} else {
		[limitRowsField setEnabled:NO];
		[limitRowsButton setEnabled:NO];
		[limitRowsStepper setEnabled:NO];
		[limitRowsField setStringValue:@""];
		[limitRowsText setStringValue:NSLocalizedString(@"No limit", @"text showing that the result isn't limited")];
	}

	// set the state of the table buttons
	[addButton setEnabled:YES];
	[copyButton setEnabled:NO];
	[removeButton setEnabled:NO];

	// Perform the data query and store the result as an array containing a dictionary per result row
	query = [NSString stringWithFormat:@"SELECT %@ FROM %@", [self fieldListForQuery], [selectedTable backtickQuotedString]];
	if ( sortCol ) {
		query = [NSString stringWithFormat:@"%@ ORDER BY %@", query, [[[dataColumns objectAtIndex:[sortCol intValue]] objectForKey:@"name"] backtickQuotedString]];
		if ( isDesc )
			query = [query stringByAppendingString:@" DESC"];
	}
	
	if ( [prefs boolForKey:@"LimitResults"] ) {
		if ( [limitRowsField intValue] <= 0 ) {
			[limitRowsField setStringValue:@"1"];
		}
		query = [query stringByAppendingString:
					[NSString stringWithFormat:@" LIMIT %d,%d",
						[limitRowsField intValue]-1, [prefs integerForKey:@"LimitResultsValue"]]];
	}

	[self setUsedQuery:query];
	
	queryResult = [mySQLConnection queryString:query];
	if ( queryResult == nil ) {
		NSLog(@"Loading table data for %@ failed, query string was: %@", aTable, query);
		return;
	}
	
	[fullResult setArray:[self fetchResultAsArray:queryResult]];
	
	// This to fix an issue where by areShowingAllRows is set to NO above during the restore of the filter options
	// leading the code to believe that the result set is filtered. If the filtered result set count is the same as the
	// maximum rows in the table then filtering is currently not in use and we set areShowingAllRows back to YES.
	if ([filteredResult count] == maxNumRowsOfCurrentTable) {
		areShowingAllRows = YES;
	}

	// Apply any filtering and update the row count
	if (!areShowingAllRows) {
		[self filterTable:self];
		[countText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%d rows of %d selected", @"text showing how many rows are in the filtered result"), [filteredResult count], numRows]];
	} 
	else {
		[filteredResult setArray:fullResult];
		[countText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%d rows in table", @"text showing how many rows are in the result"), [fullResult count]]];
	}

	// Reload the table data
	[tableContentView reloadData];
	
	// Init copyTable with necessary information for copying selected rows as SQL INSERT
	[tableContentView setTableInstance:self withTableData:filteredResult withColumns:dataColumns withTableName:selectedTable withConnection:mySQLConnection];

	// Post the notification that the query is finished
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
}

/*
 * Reloads the current table data, performing a new SQL query. Now attempts to preserve sort order, filters, and viewport.
 */
- (IBAction)reloadTable:(id)sender
{
	// Check whether a save of the current row is required.
	if (![self saveRowOnDeselect]) return;

	// Store the current viewport location
	NSRect viewRect = [tableContentView visibleRect];

	// Clear the table data column cache
	[tableDataInstance resetColumnData];

	// Load the table's data
	[self loadTable:selectedTable];
	
	// Restore the viewport
	[tableContentView scrollRectToVisible:viewRect];
}

/*
 * Reload the table values without reconfiguring the tableView (with filter and limit if set)
 */
- (IBAction)reloadTableValues:(id)sender
{
	NSString *queryString;
	MCPResult *queryResult;
	
	//query started
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];
	
	//enable or disable limit fields
	if ( [prefs boolForKey:@"LimitResults"] ) {
		[limitRowsField setEnabled:YES];
		[limitRowsButton setEnabled:YES];
		[limitRowsStepper setEnabled:YES];
		[limitRowsText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Limited to %d rows starting with row", @"text showing the number of rows the result is limited to"),
									   [prefs integerForKey:@"LimitResultsValue"]]];
	} else {
		[limitRowsField setEnabled:NO];
		[limitRowsButton setEnabled:NO];
		[limitRowsStepper setEnabled:NO];
		[limitRowsText setStringValue:NSLocalizedString(@"No limit", @"text showing that the result isn't limited")];
		[limitRowsField setStringValue:@""];
	}
	
	//	queryString = [@"SELECT * FROM " stringByAppendingString:selectedTable];
	queryString = [NSString stringWithFormat:@"SELECT %@ FROM %@", [self fieldListForQuery], [selectedTable backtickQuotedString]];
	if ( sortCol ) {
		queryString = [NSString stringWithFormat:@"%@ ORDER BY %@", queryString, [[[dataColumns objectAtIndex:[sortCol intValue]] objectForKey:@"name"] backtickQuotedString]];
		//		queryString = [queryString stringByAppendingString:[NSString stringWithFormat:@" ORDER BY %@", [sortField backtickQuotedString]]];
		if ( isDesc )
			queryString = [queryString stringByAppendingString:@" DESC"];
	}
	if ( [prefs boolForKey:@"LimitResults"] ) {
		if ( [limitRowsField intValue] <= 0 ) {
			[limitRowsField setStringValue:@"1"];
		}
		queryString = [queryString stringByAppendingString:
					   [NSString stringWithFormat:@" LIMIT %d,%d",
						[limitRowsField intValue]-1, [prefs integerForKey:@"LimitResultsValue"]]];
		[limitRowsField selectText:self];
	}
	
	[self setUsedQuery:queryString];
	
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


/*
 * Filter the table with arguments given by the user
 */
- (IBAction)filterTable:(id)sender
{
	MCPResult *theResult;
	int tag = [[compareField selectedItem] tag];
	NSString *compareOperator = @"";
	NSMutableString *argument = [[NSMutableString alloc] initWithString:[argumentField stringValue]];
	NSString *queryString;
	int i;

	// Check whether a save of the current row is required.
	if ( ![self saveRowOnDeselect] ) {
		[argument release];
		return;
	}

	// Update negative limits
	if ( [limitRowsField intValue] <= 0 ) {
		[limitRowsField setStringValue:@"1"];
	}

	// If limitRowsField > number of total found rows show the last limitRowsValue rows
	if ( [prefs boolForKey:@"LimitResults"] && [limitRowsField intValue] >= maxNumRowsOfCurrentTable ) {
		int newLimit = maxNumRowsOfCurrentTable - [prefs integerForKey:@"LimitResultsValue"];
		[limitRowsField setStringValue:[[NSNumber numberWithInt:(newLimit<1)?1:newLimit] stringValue]];
	}

	
	// If the filter field is empty, the limit field is at 1, and the selected filter is not looking
	// for NULLs or NOT NULLs, then don't allow filtering.
	if (([argument length] == 0) && (![[[compareField selectedItem] title] hasSuffix:@"NULL"]) && (![prefs boolForKey:@"LimitResults"] || [limitRowsField intValue] == 1)) {
		[argument release];
		[self showAll:sender];
		return;
	}
	
	// Query started
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];
	
	BOOL doQuote = YES;
	BOOL ignoreArgument = NO;

	// Start building the query string
	queryString = [NSString stringWithFormat:@"SELECT %@ FROM %@", [self fieldListForQuery], [selectedTable backtickQuotedString]];			

	// Add filter if appropriate
	if (([argument length] > 0) || [[[compareField selectedItem] title] hasSuffix:@"NULL"]) {
		if (![compareType isEqualToString:@""]) {
			if ([compareType isEqualToString:@"string"]) {
				// String comparision
				switch (tag) {
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
					case 5:
						compareOperator = @"IS NULL";
						doQuote = NO;
						ignoreArgument = YES;
						break;
					case 6:
						compareOperator = @"IS NOT NULL";
						doQuote = NO;
						ignoreArgument = YES;
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
					case 7:
						compareOperator = @"LIKE";
						doQuote = YES;
						ignoreArgument = YES;
						break;
					case 8:
						compareOperator = @"IS NULL";
						doQuote = NO;
						ignoreArgument = YES;
						break;
					case 9:
						compareOperator = @"IS NOT NULL";
						doQuote = NO;
						ignoreArgument = YES;
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
						compareOperator = @"IS NULL";
						doQuote = NO;
						ignoreArgument = YES;
						break;
					case 7:
						compareOperator = @"IS NOT NULL";
						doQuote = NO;
						ignoreArgument = YES;
						break;
				}
			} else {
				doQuote = NO;
				ignoreArgument = YES;
				NSLog(@"ERROR: unknown compare type %@", compareType);
			}
			
			if (doQuote) {
				//escape special characters
				for ( i = 0 ; i < [argument length] ; i++ ) {
					if ( [argument characterAtIndex:i] == '\\' ) {
						[argument insertString:@"\\" atIndex:i];
						i++;
					}
				}
				[argument setString:[mySQLConnection prepareString:argument]];
				queryString = [NSString stringWithFormat:@"%@ WHERE %@ %@ \"%@\"",
								queryString, [[fieldField titleOfSelectedItem] backtickQuotedString], compareOperator, argument];			
			} else {
				queryString = [NSString stringWithFormat:@"%@ WHERE %@ %@ %@",
								queryString, [[fieldField titleOfSelectedItem] backtickQuotedString],
								compareOperator, (ignoreArgument) ? @"" : argument];
			}
		}
	}

	// Add sorting details if appropriate
	if ( sortCol ) {
		queryString = [NSString stringWithFormat:@"%@ ORDER BY %@", queryString, [[[dataColumns objectAtIndex:[sortCol intValue]] objectForKey:@"name"] backtickQuotedString]];
		if ( isDesc )
			queryString = [queryString stringByAppendingString:@" DESC"];
	}

	// retain the query before LIMIT
	// to redo the query if nothing found for LIMIT > 1
	NSString* tempQueryString;
	// LIMIT if appropriate
	if ( [prefs boolForKey:@"LimitResults"] ) {
		tempQueryString = [NSString stringWithString:queryString];
		queryString = [NSString stringWithFormat:@"%@ LIMIT %d,%d", queryString,
						[limitRowsField intValue]-1, [prefs integerForKey:@"LimitResultsValue"]];
	}

	[self setUsedQuery:queryString];
	
	theResult = [mySQLConnection queryString:queryString];
	[filteredResult setArray:[self fetchResultAsArray:theResult]];
	
	// try it again if theResult is empty and limitRowsField > 1 by setting LIMIT to 0, limitRowsValue
	if([prefs boolForKey:@"LimitResults"] && [limitRowsField intValue] > 1 && [filteredResult count] == 0) {
		queryString = [NSString stringWithFormat:@"%@ LIMIT %d,%d", tempQueryString,
						0, [prefs integerForKey:@"LimitResultsValue"]];
		theResult = [mySQLConnection queryString:queryString];
		[limitRowsField setStringValue:@"1"];
		[filteredResult setArray:[self fetchResultAsArray:theResult]];
	}
	
	[countText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%d rows of %d selected", @"text showing how many rows are in the filtered result"), [filteredResult count], numRows]];
	
	// Reset the table view
	[tableContentView scrollPoint:NSMakePoint(0.0, 0.0)];
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

	// Check whether a save of the current row is required.
	if ( ![self saveRowOnDeselect] ) return;

	[filteredResult setArray:fullResult];
	[tableContentView reloadData];
	areShowingAllRows = YES;
	
	[countText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%d rows in table", @"text showing how many rows are in the result"), numRows]];
}

/**
 * Enables or disables the filter input field based on the selected filter type.
 */
- (IBAction)toggleFilterField:(id)sender
{
	// If the user is filtering for NULLs then disabled the filter field, otherwise enable it.
	[argumentField setEnabled:(![[[compareField selectedItem] title] hasSuffix:@"NULL"])];
}

- (NSString *)usedQuery
{
	return usedQuery;
}

- (void)setUsedQuery:(NSString *)query
{
	if (usedQuery) [usedQuery release];
	usedQuery = [[NSString alloc] initWithString:query];
}


#pragma mark Edit methods

/*
 * Adds an empty row to the table-array and goes into edit mode
 */
- (IBAction)addRow:(id)sender
{
	NSMutableDictionary *column;
	NSMutableArray *newRow = [NSMutableArray array];
	int i;

	// Check whether a save of the current row is required.
	if ( ![self saveRowOnDeselect] ) return;

	for ( i = 0 ; i < [dataColumns count] ; i++ ) {
		column = NSArrayObjectAtIndex(dataColumns, i);
		if ([column objectForKey:@"default"] == nil || [[column objectForKey:@"default"] isEqualToString:@"NULL"]) {
			[newRow addObject:[prefs stringForKey:@"NullValue"]];
		} else {
			[newRow addObject:[column objectForKey:@"default"]];
		}
	}
	[filteredResult addObject:newRow];

	[tableContentView reloadData];
	[tableContentView selectRow:[tableContentView numberOfRows]-1 byExtendingSelection:NO];
	isEditingRow = YES;
	isEditingNewRow = YES;
	currentlyEditingRow = [tableContentView selectedRow];
	if ( [multipleLineEditingButton state] == NSOffState )
		[tableContentView editColumn:0 row:[tableContentView numberOfRows]-1 withEvent:nil select:YES];
}

- (IBAction)copyRow:(id)sender
/*
 copies a row of the table-array and goes into edit mode
 */
{
	NSMutableArray *tempRow;
	MCPResult *queryResult;
	NSDictionary *row;
	NSArray *dbDataRow = nil;
	int i;
	
	// Check whether a save of the current row is required.
	if ( ![self saveRowOnDeselect] ) return;

	if ( [tableContentView numberOfSelectedRows] < 1 )
		return;
	if ( [tableContentView numberOfSelectedRows] > 1 ) {
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil, NSLocalizedString(@"You can only copy single rows.", @"message of panel when trying to copy multiple rows"));
		return;
	}
	
	//copy row
	tempRow = [NSMutableArray arrayWithArray:[filteredResult objectAtIndex:[tableContentView selectedRow]]];
	[filteredResult insertObject:tempRow atIndex:[tableContentView selectedRow]+1];
	
	//if we don't show blobs, read data for this duplicate column from db
	if ([prefs boolForKey:@"LoadBlobsAsNeeded"]) {
		// Abort if there are no indices on this table - argumentForRow will display an error.
		if (![[self argumentForRow:[tableContentView selectedRow]] length]){
			return;
		}
		//if we have indexes, use argumentForRow
		queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@", [selectedTable backtickQuotedString], [self argumentForRow:[tableContentView selectedRow]]]];
		dbDataRow = [queryResult fetchRowAsArray];
	}
	
	//set autoincrement fields to NULL
	queryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW COLUMNS FROM %@", [selectedTable backtickQuotedString]]];
	if ([queryResult numOfRows]) [queryResult dataSeek:0];
	for ( i = 0 ; i < [queryResult numOfRows] ; i++ ) {
		row = [queryResult fetchRowAsDictionary];
		if ( [[row objectForKey:@"Extra"] isEqualToString:@"auto_increment"] ) {
			[tempRow replaceObjectAtIndex:i withObject:[prefs stringForKey:@"NullValue"]];
		} else if ( [tableDataInstance columnIsBlobOrText:[row objectForKey:@"Field"]] && [prefs boolForKey:@"LoadBlobsAsNeeded"] && dbDataRow) {
			NSString *valueString = nil;
			//if what we read from DB is NULL (NSNull), we replace it with the string NULL
			if([[dbDataRow objectAtIndex:i] isKindOfClass:[NSNull class]])
				valueString = [prefs objectForKey:@"NullValue"];
			else
				valueString = [dbDataRow objectAtIndex:i];
			[tempRow replaceObjectAtIndex:i withObject:valueString];
		}
	}
	
	//select row and go in edit mode
	[tableContentView reloadData];
	[tableContentView selectRow:[tableContentView selectedRow]+1 byExtendingSelection:NO];
	isEditingRow = YES;
	isEditingNewRow = YES;
	currentlyEditingRow = [tableContentView selectedRow];
	if ( [multipleLineEditingButton state] == NSOffState )
		[tableContentView editColumn:0 row:[tableContentView selectedRow] withEvent:nil select:YES];
}

/**
 * Asks the user if they really want to delete the selected rows
 */
- (IBAction)removeRow:(id)sender
{
	// Check whether a save of the current row is required.
	if (![self saveRowOnDeselect]) 
		return;

	if (![tableContentView numberOfSelectedRows])
		return;
	
	NSAlert *alert = [NSAlert alertWithMessageText:@""
									 defaultButton:NSLocalizedString(@"Delete", @"delete button") 
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button") 
									   otherButton:nil 
						 informativeTextWithFormat:@""];
	
	[alert setAlertStyle:NSCriticalAlertStyle];
	
	NSString *contextInfo = @"removerow";
	
	if (([tableContentView numberOfSelectedRows] == [tableContentView numberOfRows]) && 
		(([prefs boolForKey:@"LimitResults"] && [tableContentView numberOfSelectedRows] == [self fetchNumberOfRows]) ||
		 (![prefs boolForKey:@"LimitResults"] && [tableContentView numberOfSelectedRows] == [self getNumberOfRows]))) {
		
		contextInfo = @"removeallrows";
		
		[alert setMessageText:NSLocalizedString(@"Delete all rows?", @"delete all rows message")];
		[alert setInformativeText:NSLocalizedString(@"Are you sure you want to delete all the rows from this table. This action cannot be undone.", @"delete all rows informative message")];
	} 
	else if ([tableContentView numberOfSelectedRows] == 1) {
		[alert setMessageText:NSLocalizedString(@"Delete selected row?", @"delete selected row message")];
		[alert setInformativeText:NSLocalizedString(@"Are you sure you want to delete the selected row from this table. This action cannot be undone.", @"delete selected row informative message")];
	} 
	else {
		[alert setMessageText:NSLocalizedString(@"Delete rows?", @"delete rows message")];
		[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the selected %d rows from this table. This action cannot be undone.", @"delete rows informative message"), [tableContentView numberOfSelectedRows]]];
	}
	
	[alert beginSheetModalForWindow:tableWindow modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:contextInfo];
}

//getter methods
- (NSArray *)currentDataResult
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
		[self loadTable:[tablesListInstance tableName]];
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
			id o = [NSArrayObjectAtIndex(fullResult, i) objectAtIndex:[[tableColumn identifier] intValue]];
			if([o isKindOfClass:[NSNull class]])
				[tempRow addObject:@"NULL"];
			else if([o isKindOfClass:[NSString class]])
				[tempRow addObject:[o description]];
			else {
				NSImage *image = [[NSImage alloc] initWithData:o];
				if(image) {
					int imageWidth = [image size].width;
					if (imageWidth > 100) imageWidth = 100;
					[tempRow addObject:[NSString stringWithFormat:
						@"<IMG WIDTH='%d' SRC=\"data:image/auto;base64,%@\">", 
						imageWidth, 
						[[image TIFFRepresentationUsingCompression:NSTIFFCompressionJPEG factor:0.01] base64EncodingWithLineLength:0]]];
				} else {
					[tempRow addObject:@"&lt;BLOB&gt;"];
				}
				if(image) [image release];
			}
		}
		[currentResult addObject:[NSArray arrayWithArray:tempRow]];
	}
	return currentResult;
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
		[self loadTable:[tablesListInstance tableName]];
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

// Additional methods

/**
 * Sets the connection (received from TableDocument) and makes things that have to be done only once 
 */
- (void)setConnection:(MCPConnection *)theConnection
{
	mySQLConnection = theConnection;
	
	[tableContentView setVerticalMotionCanBeginDrag:NO];
	
	if ( [prefs boolForKey:@"UseMonospacedFonts"] ) {
		[argumentField setFont:[NSFont fontWithName:@"Monaco" size:10]];
		[limitRowsField setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
	} else {
		[limitRowsField setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		[argumentField setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}
	[limitRowsStepper setEnabled:NO];
	if ( [prefs boolForKey:@"LimitResults"] ) {
		[limitRowsText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Limited to %d rows starting with row", @"text showing the number of rows the result is limited to"),
									   [prefs integerForKey:@"LimitResultsValue"]]];
	} else {
		[limitRowsText setStringValue:NSLocalizedString(@"No limit", @"text showing that the result isn't limited")];
		[limitRowsField setStringValue:@""];
	}
}

/**
 * Performs the requested action - switching to another table
 * with the appropriate filter settings - when a link arrow is
 * selected.
 */
- (void)clickLinkArrow:(SPTextAndLinkCell *)theArrowCell
{
	if ([theArrowCell getClickedColumn] == NSNotFound || [theArrowCell getClickedRow] == NSNotFound) return;
	int dataColumnIndex = [[[[tableContentView tableColumns] objectAtIndex:[theArrowCell getClickedColumn]] identifier] intValue];

	// Ensure the clicked cell has foreign key details available
	NSDictionary *refDictionary = [[dataColumns objectAtIndex:dataColumnIndex] objectForKey:@"foreignkeyreference"];
	if (!refDictionary) return;

	// Check whether a save of the current row is required.
	if ( ![self saveRowOnDeselect] ) return;

	// Store the filter details to use when next loading the table
	targetFilterColumn = [refDictionary objectForKey:@"column"];
	targetFilterValue = [[filteredResult objectAtIndex:[theArrowCell getClickedRow]] objectAtIndex:dataColumnIndex];

	// Attempt to switch to the new table
	if (![tablesListInstance selectTableOrViewWithName:[refDictionary objectForKey:@"table"]]) {
		NSBeep();
		targetFilterColumn = nil;
		targetFilterValue = nil;
	}
}

/**
 * Sets the compare types for the filter and the appropriate formatter for the textField
 */
- (IBAction)setCompareTypes:(id)sender
{
	NSArray *stringTypes  = [NSArray arrayWithObjects:NSLocalizedString(@"is", @"popup menuitem for field IS value"), NSLocalizedString(@"is not", @"popup menuitem for field IS NOT value"), NSLocalizedString(@"contains", @"popup menuitem for field CONTAINS value"), NSLocalizedString(@"contains not", @"popup menuitem for field CONTAINS NOT value"), @"IN", nil];
	NSArray *numberTypes  = [NSArray arrayWithObjects:@"=", @"≠", @">", @"<", @"≥", @"≤", @"IN", @"LIKE", nil];
	NSArray *dateTypes    = [NSArray arrayWithObjects:NSLocalizedString(@"is", @"popup menuitem for field IS value"), NSLocalizedString(@"is not", @"popup menuitem for field IS NOT value"), NSLocalizedString(@"is after", @"popup menuitem for field AFTER DATE value"), NSLocalizedString(@"is before", @"popup menuitem for field BEFORE DATE value"), NSLocalizedString(@"is after or equal to", @"popup menuitem for field AFTER OR EQUAL TO value"), NSLocalizedString(@"is before or equal to", @"popup menuitem for field BEFORE OR EQUAL TO value"), nil];
	NSString *fieldTypeGrouping   = [NSString stringWithString:[[tableDataInstance columnWithName:[[fieldField selectedItem] title]] objectForKey:@"typegrouping"]];
	
	int i;
	
	[compareField removeAllItems];
	
	if ( [fieldTypeGrouping isEqualToString:@"date"] ) {
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

	// TODO: A bug in the framework previously meant enum fields had to be treated as string fields for the purposes
	// of comparison - this can now be split out to support additional comparison fucntionality if desired.
	} else if ([fieldTypeGrouping isEqualToString:@"string"] || [fieldTypeGrouping isEqualToString:@"binary"]
			|| [fieldTypeGrouping isEqualToString:@"textdata"] || [fieldTypeGrouping isEqualToString:@"blobdata"]
			|| [fieldTypeGrouping isEqualToString:@"enum"]) {
		[compareField addItemsWithTitles:stringTypes];
		compareType = @"string";
		//		[argumentField setFormatter:nil];
	} else if ([fieldTypeGrouping isEqualToString:@"bit"] || [fieldTypeGrouping isEqualToString:@"integer"]
				|| [fieldTypeGrouping isEqualToString:@"float"]) {
		[compareField addItemsWithTitles:numberTypes];
		compareType = @"number";
		//		[argumentField setFormatter:numberFormatter];
	} else  {
		NSLog(@"ERROR: unknown type for comparision: %@, in %@", [[tableDataInstance columnWithName:[[fieldField selectedItem] title]] objectForKey:@"type"], fieldTypeGrouping);
	}
	
	// Add IS NULL and IS NOT NULL as they should always be available
	[compareField addItemWithTitle:@"IS NULL"];
	[compareField addItemWithTitle:@"IS NOT NULL"];
	
	for ( i = 0 ; i < [compareField numberOfItems] ; i++ ) {
		[[compareField itemAtIndex:i] setTag:i];
	}

	// Update the argumentField enabled state
	[self toggleFilterField:self];

	// set focus on argumentField
	[argumentField selectText:self];
}

- (IBAction)stepLimitRows:(id)sender
/*
 steps the start row up or down (+/- limitRowsValue)
 */
{
	if ( [limitRowsStepper intValue] > 0 ) {
		int newStep = [limitRowsField intValue]+[prefs integerForKey:@"LimitResultsValue"];
		// if newStep > the total number of rows in the current table retain the old value
		[limitRowsField setIntValue:(newStep>maxNumRowsOfCurrentTable)?[limitRowsField intValue]:newStep];
	} else {
		if ( ([limitRowsField intValue]-[prefs integerForKey:@"LimitResultsValue"]) < 1 ) {
			[limitRowsField setIntValue:1];
		} else {
			[limitRowsField setIntValue:[limitRowsField intValue]-[prefs integerForKey:@"LimitResultsValue"]];
		}
	}
	[limitRowsStepper setIntValue:0];
}

/*
 * Fetches the result as an array, with an array for each row in it
 */
- (NSArray *)fetchResultAsArray:(MCPResult *)theResult
{
	unsigned long numOfRows = [theResult numOfRows];
	NSMutableArray *tempResult = [NSMutableArray arrayWithCapacity:numOfRows];

	NSArray *tempRow;
	NSMutableArray *modifiedRow = [NSMutableArray array];
	NSMutableArray *columnBlobStatuses = [NSMutableArray array];
	int i, j;
	Class nullClass = [NSNull class];
	id prefsNullValue = [prefs objectForKey:@"NullValue"];
	BOOL prefsLoadBlobsAsNeeded = [prefs boolForKey:@"LoadBlobsAsNeeded"];

	long columnsCount = [dataColumns count];

	// Build up an array of which columns are blobs for faster iteration
	for ( i = 0; i < columnsCount ; i++ ) {
		[columnBlobStatuses addObject:[NSNumber numberWithBool:[tableDataInstance columnIsBlobOrText:[NSArrayObjectAtIndex(dataColumns, i) objectForKey:@"name"] ]]];
	}
	
	if (numOfRows) [theResult dataSeek:0];
	for ( i = 0 ; i < numOfRows ; i++ ) {
		[modifiedRow removeAllObjects];
		tempRow = [theResult fetchRowAsArray];

		for ( j = 0; j < columnsCount; j++ ) {
			if ( [NSArrayObjectAtIndex(tempRow, j) isMemberOfClass:nullClass] ) {
				[modifiedRow addObject:prefsNullValue];
			} else {
				[modifiedRow addObject:NSArrayObjectAtIndex(tempRow, j)];
			}
		}

		// Add values for hidden blob and text fields if appropriate
		if ( prefsLoadBlobsAsNeeded ) {
			for ( j = 0 ; j < columnsCount ; j++ ) {
				if ( [NSArrayObjectAtIndex(columnBlobStatuses, j) boolValue] ) {
					[modifiedRow replaceObjectAtIndex:j withObject:NSLocalizedString(@"(not loaded)", @"value shown for hidden blob and text fields")];
				}
			}
		}

		[tempResult addObject:[NSMutableArray arrayWithArray:modifiedRow]];
	}

	return tempResult;
}


/*
 * Tries to write a new row to the database.
 * Returns YES if row is written to database, otherwise NO; also returns YES if no row
 * is being edited and nothing has to be written to the database.
 */
- (BOOL)addRowToDB
{
	NSArray *columnNames;
	NSMutableString *queryString;
	NSString *query;
	MCPResult *queryResult;
	id rowObject;
	NSMutableString *rowValue = [NSMutableString string];
	NSString *currentTime = [[NSDate date] descriptionWithCalendarFormat:@"%H:%M:%S" timeZone:nil locale:nil];
	int i;
	
	if ( !isEditingRow || currentlyEditingRow == -1) {
		return YES;
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];

	// If editing, compare the new row to the old row and if they are identical finish editing without saving.
	if (!isEditingNewRow && [oldRow isEqualToArray:[filteredResult objectAtIndex:currentlyEditingRow]]) {
		isEditingRow = NO;
		currentlyEditingRow = -1;
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
		return YES;
	}

	// Retrieve the field names and types for this table from the data cache.  This is used when requesting all data as part
	// of the fieldListForQuery method, and also to decide whether or not to preserve the current filter/sort settings.
	columnNames = [tableDataInstance columnNames];
	
	NSMutableArray *fieldValues = [[NSMutableArray alloc] init];
	// Get the field values
	for ( i = 0 ; i < [columnNames count] ; i++ ) {
		rowObject = [NSArrayObjectAtIndex(filteredResult, currentlyEditingRow) objectAtIndex:i];
		// Convert the object to a string (here we can add special treatment for date-, number- and data-fields)
		if ( [[rowObject description] isEqualToString:[prefs stringForKey:@"NullValue"]]
				|| ([rowObject isMemberOfClass:[NSString class]] && [[rowObject description] isEqualToString:@""]) ) {

			//NULL when user entered the nullValue string defined in the prefs or when a number field isn't set
			//	problem: when a number isn't set, sequel-pro enters 0
			//	-> second if argument isn't necessary!
			[rowValue setString:@"NULL"];
		} else {

			// I don't believe any of these class matches are ever met at present.
			if ( [rowObject isKindOfClass:[NSCalendarDate class]] ) {
				[rowValue setString:[NSString stringWithFormat:@"'%@'", [mySQLConnection prepareString:[rowObject description]]]];
			} else if ( [rowObject isKindOfClass:[NSNumber class]] ) {
				[rowValue setString:[rowObject stringValue]];
			} else if ( [rowObject isKindOfClass:[NSData class]] ) {
				[rowValue setString:[NSString stringWithFormat:@"X'%@'", [mySQLConnection prepareBinaryData:rowObject]]];
			} else {
				if ( [[rowObject description] isEqualToString:@"CURRENT_TIMESTAMP"] ) {
					[rowValue setString:@"CURRENT_TIMESTAMP"];
				} else if ([[NSArrayObjectAtIndex(dataColumns, i) objectForKey:@"typegrouping"] isEqualToString:@"bit"]) {
					[rowValue setString:((![[rowObject description] length] || [[rowObject description] isEqualToString:@"0"])?@"0":@"1")];
				} else if ([[NSArrayObjectAtIndex(dataColumns, i) objectForKey:@"typegrouping"] isEqualToString:@"date"]
							&& [[rowObject description] isEqualToString:@"NOW()"]) {
					[rowValue setString:@"NOW()"];
				} else {
					[rowValue setString:[NSString stringWithFormat:@"'%@'", [mySQLConnection prepareString:[rowObject description]]]];
				}
			}
		}
		[fieldValues addObject:[NSString stringWithString:rowValue]];
	}
	
	// Use INSERT syntax when creating new rows
	if ( isEditingNewRow ) {
		queryString = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)",
					   [selectedTable backtickQuotedString], [columnNames componentsJoinedAndBacktickQuoted], [fieldValues componentsJoinedByString:@","]];

	// Use UPDATE syntax otherwise
	} else {
		queryString = [NSMutableString stringWithFormat:@"UPDATE %@ SET ", [selectedTable backtickQuotedString]];
		for ( i = 0 ; i < [columnNames count] ; i++ ) {
			if ( i > 0 ) {
				[queryString appendString:@", "];
			}
			[queryString appendString:[NSString stringWithFormat:@"%@=%@",
									   [NSArrayObjectAtIndex(columnNames, i) backtickQuotedString], [fieldValues objectAtIndex:i]]];
		}
		[queryString appendString:[NSString stringWithFormat:@" WHERE %@", [self argumentForRow:-2]]];
	}
	[mySQLConnection queryString:queryString];
	[fieldValues release];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
	
	// If no rows have been changed, show error if appropriate.
	if ( ![mySQLConnection affectedRows] && ![mySQLConnection getLastErrorMessage] && ![[mySQLConnection getLastErrorMessage] length]) {
		if ( [prefs boolForKey:@"ShowNoAffectedRowsError"] ) {
			NSBeginAlertSheet(NSLocalizedString(@"Warning", @"warning"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
							  NSLocalizedString(@"The row was not written to the MySQL database. You probably haven't changed anything.\nReload the table to be sure that the row exists and use a primary key for your table.\n(This error can be turned off in the preferences.)", @"message of panel when no rows have been affected after writing to the db"));
		} else {
			NSBeep();
		}
		[filteredResult replaceObjectAtIndex:currentlyEditingRow withObject:[NSMutableArray arrayWithArray:oldRow]];
		isEditingRow = NO;
		isEditingNewRow = NO;
		currentlyEditingRow = -1;
		[[SPQueryConsole sharedQueryConsole] showErrorInConsole:[NSString stringWithFormat:NSLocalizedString(@"/* WARNING %@ No rows have been affected */\n", @"warning shown in the console when no rows have been affected after writing to the db"), currentTime]];
		return YES;

	// On success...
	} else if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
		isEditingRow = NO;

		// New row created successfully
		if ( isEditingNewRow ) {
			if ( [prefs boolForKey:@"ReloadAfterAddingRow"] ) {
				[self reloadTableValues:self];
				[tableContentView deselectAll:self];
				[tableWindow endEditingFor:nil];
			} else {

				// Set the insertId for fields with auto_increment
				for ( i = 0; i < [dataColumns count] ; i++ ) {
					if ([[NSArrayObjectAtIndex(dataColumns, i) objectForKey:@"autoincrement"] intValue]) {
						[[filteredResult objectAtIndex:currentlyEditingRow] replaceObjectAtIndex:i withObject:[[NSNumber numberWithLong:[mySQLConnection insertId]] description]];
					}
				}
				[fullResult addObject:[filteredResult objectAtIndex:currentlyEditingRow]];
			}
			isEditingNewRow = NO;

		// Existing row edited successfully
		} else {
			if ( [prefs boolForKey:@"ReloadAfterEditingRow"] ) {
				[self reloadTableValues:self];
				[tableContentView deselectAll:self];
				[tableWindow endEditingFor:nil];

			// TODO: this probably needs looking at... it's reloading it all itself?
			} else {
				query = [NSString stringWithFormat:@"SELECT %@ FROM %@", [self fieldListForQuery], [selectedTable backtickQuotedString]];
				if ( sortCol ) {
					query = [NSString stringWithFormat:@"%@ ORDER BY %@", query, [[[dataColumns objectAtIndex:[sortCol intValue]] objectForKey:@"name"] backtickQuotedString]];
					if ( isDesc )
						query = [query stringByAppendingString:@" DESC"];
				}
				if ( [prefs boolForKey:@"LimitResults"] ) {
					if ( [limitRowsField intValue] <= 0 ) {
						[limitRowsField setStringValue:@"1"];
					}
					query = [query stringByAppendingString:
							 [NSString stringWithFormat:@" LIMIT %d,%d",
							  [limitRowsField intValue]-1, [prefs integerForKey:@"LimitResultsValue"]]];
				}
				queryResult = [mySQLConnection queryString:query];
				[fullResult setArray:[self fetchResultAsArray:queryResult]];
			}
		}
		currentlyEditingRow = -1;
		
		return YES;

	// Report errors which have occurred
	} else {
		NSBeginAlertSheet(NSLocalizedString(@"Couldn't write row", @"Couldn't write row error"), NSLocalizedString(@"OK", @"OK button"), NSLocalizedString(@"Cancel", @"cancel button"), nil, tableWindow, self, @selector(sheetDidEnd:returnCode:contextInfo:), nil, @"addrow",
						  [NSString stringWithFormat:NSLocalizedString(@"MySQL said:\n\n%@", @"message of panel when error while adding row to db"), [mySQLConnection getLastErrorMessage]]);
		return NO;
	}
}


/*
 * A method to be called whenever the table selection changes; checks whether the current
 * row is being edited, and if so attempts to save it.  Returns YES if no save was necessary
 * or the save was successful, and NO if a save was necessary and failed - in which case further
 * editing is required.  In that case this method will reselect the row in question for reediting.
 */
- (BOOL)saveRowOnDeselect
{

	// If no rows are currently being edited, or a save is in progress, return success at once.
	if (!isEditingRow || isSavingRow) return YES;
	isSavingRow = YES;

	// Save any edits which have been made but not saved to the table yet.
	[tableWindow endEditingFor:nil];

	// Attempt to save the row, and return YES if the save succeeded.
	if ([self addRowToDB]) {
		isSavingRow = NO;
		return YES;
	}

	// Saving failed - reselect the old row and return failure.
	[tableContentView selectRow:currentlyEditingRow byExtendingSelection:NO];
	isSavingRow = NO;
	return NO;
}

/*
 * Returns the WHERE argument to identify a row.
 * If "row" is -2, it uses the oldRow.
 * Uses the primary key if available, otherwise uses all fields as argument and sets LIMIT to 1
 */
- (NSString *)argumentForRow:(int)row
{
	MCPResult *theResult;
	NSDictionary *theRow;
	id tempValue;
	NSMutableString *value = [NSMutableString string];
	NSMutableString *argument = [NSMutableString string];
	// NSString *columnType;
	NSArray *columnNames;
	int i;
	
	if ( row == -1 )
		return @"";
	
	// Retrieve the field names for this table from the data cache.  This is used when requesting all data as part
	// of the fieldListForQuery method, and also to decide whether or not to preserve the current filter/sort settings.
	columnNames = [tableDataInstance columnNames];

	// Get the primary key if there is one
	if ( !keys ) {
		setLimit = NO;
		keys = [[NSMutableArray alloc] init];
		theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW COLUMNS FROM %@", [selectedTable backtickQuotedString]]];
		if ([theResult numOfRows]) [theResult dataSeek:0];
		for ( i = 0 ; i < [theResult numOfRows] ; i++ ) {
			theRow = [theResult fetchRowAsDictionary];
			if ( [[theRow objectForKey:@"Key"] isEqualToString:@"PRI"] ) {
				[keys addObject:[theRow objectForKey:@"Field"]];
			}
		}
	}
	
	// If there is no primary key, all the fields are used in the argument.
	if ( ![keys count] ) {
		[keys setArray:columnNames];
		setLimit = YES;		
		
		// When the option to not show blob or text options is set, we have a problem - we don't have
		// the right values to use in the WHERE statement.  Throw an error if this is the case.
		if ( [prefs boolForKey:@"LoadBlobsAsNeeded"] && [self tableContainsBlobOrTextColumns] ) {
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
							  NSLocalizedString(@"You can't hide blob and text fields when working with tables without index.", @"message of panel when trying to edit tables without index and with hidden blob/text fields"));
			[keys removeAllObjects];
			[tableContentView deselectAll:self];
			return @"";
		}
	}

	// Walk through the keys list constructing the argument list
	for ( i = 0 ; i < [keys count] ; i++ ) {
		if ( i )
			[argument appendString:@" AND "];

		// Use the selected row if appropriate
		if ( row >= 0 ) {
			tempValue = [NSArrayObjectAtIndex(filteredResult, row) objectAtIndex:[[[tableDataInstance columnWithName:NSArrayObjectAtIndex(keys, i)] objectForKey:@"datacolumnindex"] intValue]];

		// Otherwise use the oldRow
		} else {
			tempValue = [oldRow objectAtIndex:[[[tableDataInstance columnWithName:NSArrayObjectAtIndex(keys, i)] objectForKey:@"datacolumnindex"] intValue]];
		}

		if ( [tempValue isKindOfClass:[NSData class]] ) {
			[value setString:[NSString stringWithFormat:@"X'%@'", [mySQLConnection prepareBinaryData:tempValue]]];
		} else {
			[value setString:[tempValue description]];
		}

		if ( [value isEqualToString:[prefs stringForKey:@"NullValue"]] ) {
			[argument appendString:[NSString stringWithFormat:@"%@ IS NULL", [NSArrayObjectAtIndex(keys, i) backtickQuotedString]]];
		} else {

			if (! [tempValue isKindOfClass:[NSData class]] ) {
				[value setString:[NSString stringWithFormat:@"'%@'", [mySQLConnection prepareString:value]]];
			}

			[argument appendString:[NSString stringWithFormat:@"%@ = %@", [NSArrayObjectAtIndex(keys, i) backtickQuotedString], value]];
		}
	}
	if ( setLimit )
		[argument appendString:@" LIMIT 1"];
	return argument;
}


/*
 * Returns YES if the table contains any columns which are of any of the blob or text types,
 * NO otherwise.
 */
- (BOOL)tableContainsBlobOrTextColumns
{
	int i;

	for ( i = 0 ; i < [dataColumns count]; i++ ) {
		if ( [tableDataInstance columnIsBlobOrText:[NSArrayObjectAtIndex(dataColumns, i) objectForKey:@"name"]] ) {
			return YES;
		}
	}

	return NO;
}

/*
 * Returns a string controlling which fields to retrieve for a query.  Returns * (all fields) if the preferences
 * option dontShowBlob isn't set; otherwise, returns a comma-separated list of all non-blob/text fields.
 */
- (NSString *)fieldListForQuery
{
	int i;
	NSMutableArray *fields = [NSMutableArray array];
	NSArray *columnNames = [tableDataInstance columnNames];
	
	if ( [prefs boolForKey:@"LoadBlobsAsNeeded"] ) {
		for ( i = 0 ; i < [columnNames count] ; i++ ) {
			if (![tableDataInstance columnIsBlobOrText:[NSArrayObjectAtIndex(dataColumns, i) objectForKey:@"name"]] ) {
				[fields addObject:[NSArrayObjectAtIndex(columnNames, i) backtickQuotedString]];
			} else {
			
				// For blob/text fields, select a null placeholder so the column count is still correct
				[fields addObject:@"NULL"];
			}
		}

		return [fields componentsJoinedByString:@","];
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
	NSString *queryString, *wherePart;
	MCPResult *queryResult;
	int i, errors;
	
	if ( [contextInfo isEqualToString:@"addrow"] ) {
		[sheet orderOut:self];
		
		if ( returnCode == NSAlertDefaultReturn ) {
			//problem: reenter edit mode doesn't function
			[tableContentView editColumn:0 row:[tableContentView selectedRow] withEvent:nil select:YES];
		} else {
			if ( !isEditingNewRow ) {
				[filteredResult replaceObjectAtIndex:[tableContentView selectedRow]
										  withObject:[NSMutableArray arrayWithArray:oldRow]];
				isEditingRow = NO;
			} else {
				[filteredResult removeObjectAtIndex:[tableContentView selectedRow]];
				isEditingRow = NO;
				isEditingNewRow = NO;
			}
			currentlyEditingRow = -1;
		}
		[tableContentView reloadData];
	} else if ( [contextInfo isEqualToString:@"removeallrows"] ) {
		if ( returnCode == NSAlertDefaultReturn ) {
			/*
			 if ( ([tableContentView numberOfSelectedRows] == [self numberOfRowsInTableView:tableContentView]) &&
			 areShowingAllRows &&
			 ([tableContentView numberOfSelectedRows] < [prefs integerForKey:@"LimitResultsValue"]) ) {
			 */
			[mySQLConnection queryString:[NSString stringWithFormat:@"DELETE FROM %@", [selectedTable backtickQuotedString]]];
			if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
				[self reloadTable:self];
			} else {
				[self performSelector:@selector(showErrorSheetWith:)
					withObject:[NSArray arrayWithObjects:NSLocalizedString(@"Error", @"error"),
						[NSString stringWithFormat:NSLocalizedString(@"Couldn't remove rows.\nMySQL said: %@", @"message of panel when field cannot be removed"),
						   [mySQLConnection getLastErrorMessage]],
						nil]
					afterDelay:0.3];
			}
		}
	} else if ( [contextInfo isEqualToString:@"removerow"] ) {
		if ( returnCode == NSAlertDefaultReturn ) {
			errors = 0;
			
			while ( (index = [enumerator nextObject]) ) {
				wherePart = [NSString stringWithString:[self argumentForRow:[index intValue]]];
				//argumentForRow might return empty query, in which case we shouldn't execute the partial query
				if([wherePart length] > 0) {
					[mySQLConnection queryString:[NSString stringWithFormat:@"DELETE FROM %@ WHERE %@", [selectedTable backtickQuotedString], wherePart]];
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
				} else {
					errors++;
				}

			}
			
			if ( errors ) {
				[self performSelector:@selector(showErrorSheetWith:)
					withObject:[NSArray arrayWithObjects:NSLocalizedString(@"Warning", @"warning"),
						[NSString stringWithFormat:NSLocalizedString(@"%d row%@ ha%@ not been removed. Reload the table to be sure that the rows exist and use a primary key for your table.", @"message of panel when not all selected fields have been deleted"), errors, (errors>1)?@"s":@"", (errors>1)?@"ve":@"s"],
						nil]
					afterDelay:0.3];
			}

			//do deleting (after enumerating)
			if ( [prefs boolForKey:@"ReloadAfterRemovingRow"] ) {
				[self reloadTableValues:self];
			} else {
				for ( i = 0 ; i < [filteredResult count] ; i++ ) {
					if ( ![tempArray containsObject:[NSNumber numberWithInt:i]] )
						[tempResult addObject:NSArrayObjectAtIndex(filteredResult, i)];
				}
				[filteredResult setArray:tempResult];
				numRows = [self getNumberOfRows];
				if ( !areShowingAllRows ) {
					//					queryString = [@"SELECT * FROM " stringByAppendingString:selectedTable];
					queryString = [NSString stringWithFormat:@"SELECT %@ FROM %@", [self fieldListForQuery], [selectedTable backtickQuotedString]];
					if ( sortCol ) {
						//						queryString = [queryString stringByAppendingString:[NSString stringWithFormat:@" ORDER BY %@", [sortField backtickQuotedString]]];
						queryString = [NSString stringWithFormat:@"%@ ORDER BY %@", queryString, [[[dataColumns objectAtIndex:[sortCol intValue]] objectForKey:@"name"] backtickQuotedString]];
						if ( isDesc )
							queryString = [queryString stringByAppendingString:@" DESC"];
					}
					if ( [prefs boolForKey:@"LimitResults"] ) {
						if ( [limitRowsField intValue] <= 0 ) {
							[limitRowsField setStringValue:@"1"];
						}
						queryString = [queryString stringByAppendingString:
									   [NSString stringWithFormat:@" LIMIT %d,%d",
										[limitRowsField intValue]-1, [prefs integerForKey:@"LimitResultsValue"]]];
					}
					
					[self setUsedQuery:queryString];
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

/*
 * Show Error sheet (can be called from inside of a endSheet selector)
 * via [self performSelector:@selector(showErrorSheetWithTitle:) withObject: afterDelay:]
 */
-(void)showErrorSheetWith:(id)error
{
	// error := first object is the title , second the message, only one button OK
	NSBeginAlertSheet([error objectAtIndex:0], NSLocalizedString(@"OK", @"OK button"), 
			nil, nil, tableWindow, self, nil, nil, nil,
			[error objectAtIndex:1]);
}


/*
 * Returns the number of rows in the selected table
 * Queries the number from MySQL if enabled in prefs and result is limited, otherwise just return the fullResult count.
 */
- (int)getNumberOfRows
{
	if ([prefs boolForKey:@"LimitResults"] && [prefs boolForKey:@"FetchCorrectRowCount"]) {
		numRows = [self fetchNumberOfRows];
	} else {
		numRows = [fullResult count];
	}
	
	return numRows;
}

/*
 * Fetches the number of rows in the selected table using a "SELECT COUNT(1)" query and return it
 */
- (int)fetchNumberOfRows
{
	return [[[[mySQLConnection queryString:[NSString stringWithFormat:@"SELECT COUNT(1) FROM %@", [selectedTable backtickQuotedString]]] fetchRowAsArray] objectAtIndex:0] intValue];
}

//tableView datasource methods
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [filteredResult count];
}

- (id)tableView:(CMCopyTable *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{

	id theValue = NSArrayObjectAtIndex(NSArrayObjectAtIndex(filteredResult, rowIndex), [[aTableColumn identifier] intValue]);

	if ( [theValue isKindOfClass:[NSData class]] )
		return [theValue shortStringRepresentationUsingEncoding:[mySQLConnection encoding]];

	return theValue;
}

- (void)tableView: (CMCopyTable *)aTableView
	willDisplayCell: (id)cell
	forTableColumn: (NSTableColumn*)aTableColumn
	row: (int)row
/*
	*  This function changes the text color of 
	*  text/blob fields which are not yet loaded to gray
*/
{
	// Check if loading of text/blob fields is disabled
	// If not, all text fields are loaded and we don't have to make them gray
	if ([prefs boolForKey:@"LoadBlobsAsNeeded"])
	{
		// Make sure that the cell actually responds to setTextColor:
		// In the future, we might use different cells for the table view
		// that don't support this selector
		if ([cell respondsToSelector:@selector(setTextColor:)])
		{
			NSString   *columnTypeGrouping;
			NSUInteger  indexOfColumn;

			indexOfColumn = [[aTableColumn identifier] intValue];

			// Test if the current column is a text or a blob field
			columnTypeGrouping = [[dataColumns objectAtIndex:indexOfColumn] objectForKey:@"typegrouping"];
			if ([columnTypeGrouping isEqualToString:@"textdata"] || [columnTypeGrouping isEqualToString:@"blobdata"]) {

				// now check if the field has been loaded already or not
				if ([[cell stringValue] isEqualToString:NSLocalizedString(@"(not loaded)", @"value shown for hidden blob and text fields")])
				{
					// change the text color of the cell to gray
					[cell setTextColor: [NSColor grayColor]];
				}
				else
				{
					// Change the text color back to black
					// This is necessary because NSTableView reuses
					// the NSCell to draw further rows in the column
					[cell setTextColor: [NSColor blackColor]];
				}
			}
		}
	}
}

- (void)tableView:(NSTableView *)aTableView
   setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)aTableColumn
			  row:(int)rowIndex
{

	// Catch editing events in the row and if the row isn't currently being edited,
	// start an edit.  This allows edits including enum changes to save correctly.
	if ( !isEditingRow ) {
		[oldRow setArray:NSArrayObjectAtIndex(filteredResult, rowIndex)];
		isEditingRow = YES;
		currentlyEditingRow = rowIndex;
	}
	
	if ( anObject )
		[NSArrayObjectAtIndex(filteredResult, rowIndex) replaceObjectAtIndex:[[aTableColumn identifier] intValue] withObject:anObject];
	else
		[NSArrayObjectAtIndex(filteredResult, rowIndex) replaceObjectAtIndex:[[aTableColumn identifier] intValue] withObject:@""];

}

#pragma mark -
#pragma mark tableView delegate methods

- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn
/*
 sorts the tableView by the clicked column
 if clicked twice, order is descending
 */
{
	NSString *queryString;
	MCPResult *queryResult;
	
	if ( [selectedTable isEqualToString:@""] || !selectedTable )
		return;
	
	// Check whether a save of the current row is required.
	if ( ![self saveRowOnDeselect] ) return;

	//query started
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];
		
	//sets order descending if a header is clicked twice
	if ( [[tableColumn identifier] isEqualTo:sortCol] ) {
		if ( isDesc ) {
			isDesc = NO;
		} else {
			isDesc = YES;
		}
	} else {
		isDesc = NO;
		[tableContentView setIndicatorImage:nil inTableColumn:[tableContentView tableColumnWithIdentifier:sortCol]];
	}
	if (sortCol) [sortCol release];
	sortCol = [[NSNumber alloc] initWithInt:[[tableColumn identifier] intValue]];
	
	// Save the sort field name for use when refreshing the table
	if (lastField) [lastField release];
	lastField = [[NSString alloc] initWithString:[[dataColumns objectAtIndex:[[tableColumn identifier] intValue]] objectForKey:@"name"]];
	
	//make queryString and perform query
	queryString = [NSString stringWithFormat:@"SELECT %@ FROM %@ ORDER BY %@", [self fieldListForQuery],
				   [selectedTable backtickQuotedString], [[[dataColumns objectAtIndex:[sortCol intValue]] objectForKey:@"name"] backtickQuotedString]];
	if ( isDesc )
		queryString = [queryString stringByAppendingString:@" DESC"];
	if ( [prefs boolForKey:@"LimitResults"] ) {
		if ( [limitRowsField intValue] <= 0 ) {
			[limitRowsField setStringValue:@"1"];
		}
		queryString = [queryString stringByAppendingString:
					   [NSString stringWithFormat:@" LIMIT %d,%d",
						[limitRowsField intValue]-1, [prefs integerForKey:@"LimitResultsValue"]]];
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
		[tableContentView setIndicatorImage:[NSImage imageNamed:@"NSDescendingSortIndicator"] inTableColumn:tableColumn];
	} else {
		[tableContentView setIndicatorImage:[NSImage imageNamed:@"NSAscendingSortIndicator"] inTableColumn:tableColumn];
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

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	// Check our notification object is our table content view
	if ([aNotification object] != tableContentView)
		return;

	// If we are editing a row, attempt to save that row - if saving failed, reselect the edit row.
	if ( isEditingRow && [tableContentView selectedRow] != currentlyEditingRow && ![self saveRowOnDeselect] ) return;
	
	// Update the row selection count
    // and update the status of the delete/duplicate buttons
	if ( [tableContentView numberOfSelectedRows] > 0 ) {
        [copyButton setEnabled:YES];
        [removeButton setEnabled:YES];
		[countText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%d of %d rows selected", @"Text showing how many rows are selected"), [tableContentView numberOfSelectedRows], [tableContentView numberOfRows]]];
	} else {
        [copyButton setEnabled:NO];
        [removeButton setEnabled:NO];
		[countText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%d rows", @"Text showing how many rows are in the result"), [tableContentView numberOfRows]]];
	}
}

- (void)tableViewSelectionIsChanging:(NSNotification *)aNotification
{
	// Check our notification object is our table content view
	if ([aNotification object] != tableContentView)
		return;
	
	if ( [tableContentView numberOfSelectedRows] > 0 ) {
		[countText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%d of %d rows selected", @"Text showing how many rows are selected"), [tableContentView numberOfSelectedRows], [tableContentView numberOfRows]]];
	} else {
		[countText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%d rows", @"Text showing how many rows are in the result"), [tableContentView numberOfRows]]];
	}
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
	NSString *table = [tablesListInstance tableName];
	
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
		[tableColumnWidths setObject:[NSMutableDictionary dictionaryWithDictionary:[tableColumnWidths objectForKey:database]] forKey:database];

	}
	// get table object
	if  ( [[tableColumnWidths objectForKey:database] objectForKey:table] == nil ) {
		[[tableColumnWidths objectForKey:database] setObject:[NSMutableDictionary dictionary] forKey:table];
	} else {
		[[tableColumnWidths objectForKey:database] setObject:[NSMutableDictionary dictionaryWithDictionary:[[tableColumnWidths objectForKey:database] objectForKey:table]] forKey:table];

	}
	// save column size
	[[[tableColumnWidths objectForKey:database] objectForKey:table] setObject:[NSNumber numberWithFloat:[[[aNotification userInfo] objectForKey:@"NSTableColumn"] width]] forKey:[[[[aNotification userInfo] objectForKey:@"NSTableColumn"] headerCell] stringValue]];
	[prefs setObject:tableColumnWidths forKey:@"tableColumnWidths"];
}

/*
 * Confirm whether to allow editing of a row.  Returns YES by default, unless the multipleLineEditingButton is in
 * the ON state, or for blob or text fields - in those cases opens a sheet for editing instead and returns NO.
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	int i;
	NSString *query, *wherePart = nil;

	NSArray *tempRow;
	NSMutableArray *modifiedRow = [NSMutableArray array];
	// id theValue;
	MCPResult *tempResult;
	
	// If not isEditingRow and the preference value for not showing blobs is set, check whether the row contains any blobs.
	if ( [prefs boolForKey:@"LoadBlobsAsNeeded"] && !isEditingRow ) {

		// If the table does contain blob or text fields, load the values ready for editing.
		if ( [self tableContainsBlobOrTextColumns] ) {
			wherePart = [NSString stringWithString:[self argumentForRow:[tableContentView selectedRow]]];
			if([wherePart length]==0)
				return NO;
			query = [NSString stringWithFormat:@"SELECT * FROM %@ WHERE %@", [selectedTable backtickQuotedString], wherePart];
			tempResult = [mySQLConnection queryString:query];
			if ( ![tempResult numOfRows] ) {
				NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
								  NSLocalizedString(@"Couldn't load the row. Reload the table to be sure that the row exists and use a primary key for your table.", @"message of panel when loading of row failed"));
				return NO;
			}
			tempRow = [tempResult fetchRowAsArray];
			for ( i = 0; i < [tempRow count]; i++ ) {
				if ( [[tempRow objectAtIndex:i] isMemberOfClass:[NSNull class]] ) {
					[modifiedRow addObject:[prefs stringForKey:@"NullValue"]];
				} else {
					[modifiedRow addObject:[tempRow objectAtIndex:i]];
				}
			}
			[filteredResult replaceObjectAtIndex:rowIndex withObject:[NSMutableArray arrayWithArray:modifiedRow]];
			[tableContentView reloadData];
		}
	}
	
	BOOL isBlob = [tableDataInstance columnIsBlobOrText:[[aTableColumn headerCell] stringValue]];
	// Open the sheet if the multipleLineEditingButton is enabled or the column was a blob or a text.
	if ( [multipleLineEditingButton state] == NSOnState || isBlob ) {
		
		SPFieldEditorController *fieldEditor = [[SPFieldEditorController alloc] init];
		id editData = [[fieldEditor editWithObject:[[filteredResult objectAtIndex:rowIndex] objectAtIndex:[[aTableColumn identifier] intValue]] 
								 usingEncoding:[mySQLConnection encoding] isObjectBlob:isBlob isEditable:YES withWindow:tableWindow] retain];

		if ( editData ) {
			if ( !isEditingRow ) {
				[oldRow setArray:[filteredResult objectAtIndex:rowIndex]];
				isEditingRow = YES;
				currentlyEditingRow = rowIndex;
			}
			[[filteredResult objectAtIndex:rowIndex] replaceObjectAtIndex:[[aTableColumn identifier] intValue] withObject:[editData copy]];
		}

		[fieldEditor release];

		if ( editData ) [editData release];

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

		NSString *tmp;
		
		// By holding ⌘, ⇧, or/and ⌥ copies selected rows as SQL INSERTS
		// otherwise \t delimited lines
		if([[NSApp currentEvent] modifierFlags] & (NSCommandKeyMask|NSShiftKeyMask|NSAlternateKeyMask))
			tmp = [tableContentView selectedRowsAsSqlInserts];
		else
			tmp = [tableContentView draggedRowsAsTabString:rows];
		
		if ( nil != tmp && [tmp length] )
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

#pragma mark -

/*
 * Trap the enter and escape keys, overriding default behaviour and continuing/ending editing,
 * only within the current row.
 */
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	NSString *fieldType;
	int row, column, i;
	
	row = [tableContentView editedRow];
	column = [tableContentView editedColumn];

	// Trap enter and tab keys
	if (  [textView methodForSelector:command] == [textView methodForSelector:@selector(insertNewline:)] ||
		[textView methodForSelector:command] == [textView methodForSelector:@selector(insertTab:)] )
	{
		[[control window] makeFirstResponder:control];

		// Save the current line if it's the last field in the table
		if ( column == ( [tableContentView numberOfColumns] - 1 ) ) {
			[self addRowToDB];
		} else {

			// Check if next column is a blob column, and skip to the next non-blob column
			i = 1;
			while (
				(fieldType = [[tableDataInstance columnWithName:[[NSArrayObjectAtIndex([tableContentView tableColumns], column+i) headerCell] stringValue]] objectForKey:@"typegrouping"])
				&& ([fieldType isEqualToString:@"textdata"] || [fieldType isEqualToString:@"blobdata"])
			) {
				i++;

				// If there are no columns after the latest blob or text column, save the current line.
				if ( (column+i) >= [tableContentView numberOfColumns] ) {
					[self addRowToDB];
					return TRUE;
				}
			}

			// Edit the column after the blob column
			[tableContentView editColumn:column+i row:row withEvent:nil select:YES];
		}
		return TRUE;
	}
	
	// Trap the escape key
	else if (  [[control window] methodForSelector:command] == [[control window] methodForSelector:@selector(_cancelKey:)] ||
			 [textView methodForSelector:command] == [textView methodForSelector:@selector(complete:)] )
	{

		// Abort editing
		[control abortEditing];
		if ( isEditingRow && !isEditingNewRow ) {
			isEditingRow = NO;
			[filteredResult replaceObjectAtIndex:row withObject:[NSMutableArray arrayWithArray:oldRow]];
		} else if ( isEditingNewRow ) {
			isEditingRow = NO;
			isEditingNewRow = NO;
			[filteredResult removeObjectAtIndex:row];
			[tableContentView reloadData];
		}
		currentlyEditingRow = -1;
		return TRUE;
	}
	else
	{
		return FALSE;
	}
}

/**
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	if ([keyPath isEqualToString:@"DisplayTableViewVerticalGridlines"]) {
        [tableContentView setGridStyleMask:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	}
}

/**
 * Menu validation
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// Remove row
	if ([menuItem action] == @selector(removeRow:)) {
		[menuItem setTitle:([tableContentView numberOfSelectedRows] > 1) ? @"Delete Rows" : @"Delete Row"];
		
		return ([tableContentView numberOfSelectedRows] > 0);
	}
	
	// Duplicate row
	if ([menuItem action] == @selector(copyRow:)) {		
		return ([tableContentView numberOfSelectedRows] == 1);
	}
	
	return YES;
}

// Last but not least
- (void)dealloc
{
	[fullResult release];
	[filteredResult release];
	[dataColumns release];
	[oldRow release];
	// if (editData) [editData release];
	if (keys) [keys release];
	if (sortCol) [sortCol release];
	if (lastField) [lastField release];
	[usedQuery release];
	
	[super dealloc];
}

@end
