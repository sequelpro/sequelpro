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
#import "SPTableInfo.h"
#import "TablesList.h"
#import "CMImageView.h"
#import "CMCopyTable.h"
#import "SPDataCellFormatter.h"
#import "SPTableData.h"
#import "SPQueryController.h"
#import "SPStringAdditions.h"
#import "SPArrayAdditions.h"
#import "SPTextViewAdditions.h"
#import "SPDataAdditions.h"
#import "SPTextAndLinkCell.h"
#import "QLPreviewPanel.h"
#import "SPFieldEditorController.h"
#import "SPTooltip.h"
#import "RegexKitLite.h"


@implementation TableContent

/**
 * Standard init method. Initialize various ivars.
 */
- (id)init
{
	if ((self == [super init])) {
		
		tableValues      = [[NSMutableArray alloc] init];
		dataColumns    = [[NSMutableArray alloc] init];
		oldRow         = [[NSMutableArray alloc] init];
		
		selectedTable = nil;
		sortCol       = nil;
		isDesc		  = NO;
		keys		  = nil;

		currentlyEditingRow = -1;

		sortColumnToRestore = nil;
		sortColumnToRestoreIsAsc = YES;
		limitStartPositionToRestore = 1;
		selectionIndexToRestore = nil;
		selectionViewportToRestore = NSZeroRect;
		filterFieldToRestore = nil;
		filterComparisonToRestore = nil;
		filterValueToRestore = nil;
		firstBetweenValueToRestore = nil;
		secondBetweenValueToRestore = nil;

		isFiltered = NO;
		isLimited = NO;
		
		prefs = [NSUserDefaults standardUserDefaults];
		
		usedQuery = [[NSString alloc] initWithString:@""];
		
		// Init default filters for Content Browser
		contentFilters = nil;
		contentFilters = [[NSMutableDictionary alloc] init];
		numberOfDefaultFilters = [[NSMutableDictionary alloc] init];

		NSError *readError = nil;
		NSString *convError = nil;
		NSPropertyListFormat format;
		NSData *defaultFilterData = [NSData dataWithContentsOfFile:[NSBundle pathForResource:@"ContentFilters.plist" ofType:nil inDirectory:[[NSBundle mainBundle] bundlePath]] 
			options:NSMappedRead error:&readError];

		[contentFilters setDictionary:[NSPropertyListSerialization propertyListFromData:defaultFilterData 
				mutabilityOption:NSPropertyListMutableContainersAndLeaves format:&format errorDescription:&convError]];
		if(contentFilters == nil || readError != nil || convError != nil) {
			NSLog(@"Error while reading 'ContentFilters.plist':\n%@\n%@", [readError localizedDescription], convError);
			NSBeep();
		} else {
			[numberOfDefaultFilters setObject:[NSNumber numberWithInt:[[contentFilters objectForKey:@"number"] count]] forKey:@"number"];
			[numberOfDefaultFilters setObject:[NSNumber numberWithInt:[[contentFilters objectForKey:@"date"] count]] forKey:@"date"];
			[numberOfDefaultFilters setObject:[NSNumber numberWithInt:[[contentFilters objectForKey:@"string"] count]] forKey:@"string"];
		}
		

	}
	
	return self;
}

- (void)awakeFromNib
{
	// Set the table content view's vertical gridlines if required
	[tableContentView setGridStyleMask:([prefs boolForKey:@"DisplayTableViewVerticalGridlines"]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
}

#pragma mark -
#pragma mark Table loading methods and information

/*
 * Loads aTable, retrieving column information and updating the tableViewColumns before
 * reloading table data into the data array and redrawing the table.
 */
- (void)loadTable:(NSString *)aTable
{
	int			i;
	NSNumber	*colWidth, *sortColumnNumberToRestore = nil;
	NSArray *columnNames;
	NSDictionary *columnDefinition;
	NSTableColumn	*theCol;

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
		[tableValues removeAllObjects];
		[tableContentView reloadData];
		isFiltered = NO;
		isLimited = NO;
		[countText setStringValue:@""];

		// Empty and disable filter options
		[fieldField setEnabled:NO];
		[fieldField removeAllItems];
		[fieldField addItemWithTitle:NSLocalizedString(@"field", @"popup menuitem for field (showing only if disabled)")];
		[compareField setEnabled:NO];
		[compareField removeAllItems];
		[compareField addItemWithTitle:NSLocalizedString(@"is", @"popup menuitem for field IS value")];
		[argumentField setHidden:NO];
		[argumentField setEnabled:NO];
		[firstBetweenField setEnabled:NO];
		[secondBetweenField setEnabled:NO];
		[firstBetweenField setStringValue:@""];
		[secondBetweenField setStringValue:@""];
		[argumentField setStringValue:@""];
		[filterButton setEnabled:NO];
		
		// Hide BETWEEN operator controls
		[firstBetweenField setHidden:YES];
		[secondBetweenField setHidden:YES];
		[betweenTextField setHidden:YES];
		
		// Empty and disable the limit field
		[limitRowsField setStringValue:@""];
		[limitRowsField setEnabled:NO];
		[limitRowsButton setEnabled:NO];
		[limitRowsStepper setEnabled:NO];

		// Disable table action buttons
		[addButton setEnabled:NO];
		[copyButton setEnabled:NO];
		[removeButton setEnabled:NO];

		// Clear restoration settings
		[self clearDetailsToRestore];

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
		[dataCell setFormatter:[[SPDataCellFormatter new] autorelease]];

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
		if (sortColumnToRestore && [sortColumnToRestore isEqualToString:[columnDefinition objectForKey:@"name"]])
			sortColumnNumberToRestore = [columnDefinition objectForKey:@"datacolumnindex"];
		
		// Add the column to the table
		[tableContentView addTableColumn:theCol];
		[theCol release];
	}

	// If the table has been reloaded and the previously selected sort column is still present, reselect it. 
	if (sortColumnNumberToRestore) {
		theCol = [tableContentView tableColumnWithIdentifier:sortColumnNumberToRestore];
		if (sortCol) [sortCol release];
		sortCol = [sortColumnNumberToRestore copy];
		[tableContentView setHighlightedTableColumn:theCol];
		isDesc = !sortColumnToRestoreIsAsc;
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

	// Store the current first responder so filter field doesn't steal focus
	id currentFirstResponder = [tableWindow firstResponder];
	
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
	
	// Restore preserved filter settings if appropriate and valid
	if (filterFieldToRestore) {
		[fieldField selectItemWithTitle:filterFieldToRestore];
		[self setCompareTypes:self];

		if ([fieldField itemWithTitle:filterFieldToRestore]
			&& ((!filterComparisonToRestore && filterValueToRestore)
				|| [compareField itemWithTitle:filterComparisonToRestore]))
		{
			if (filterComparisonToRestore) [compareField selectItemWithTitle:filterComparisonToRestore];
			if([filterComparisonToRestore isEqualToString:@"BETWEEN"]) {
				[argumentField setHidden:YES];
				if (firstBetweenValueToRestore) [firstBetweenField setStringValue:firstBetweenValueToRestore];
				if (secondBetweenValueToRestore) [secondBetweenField setStringValue:secondBetweenValueToRestore];
			} else {
				if (filterValueToRestore) [argumentField setStringValue:filterValueToRestore];
			}
			[self toggleFilterField:self];
			
		}
	}

	// Restore first responder
	[tableWindow makeFirstResponder:currentFirstResponder];

	// Enable or disable the limit fields according to preference setting
	if ( [prefs boolForKey:@"LimitResults"] ) {

		// Preserve the limit field - if this is beyond the current number of rows,
		// reloadData will reset as necessary.
		if (limitStartPositionToRestore < 1) limitStartPositionToRestore = 1;
		[limitRowsField setStringValue:[NSString stringWithFormat:@"%u", limitStartPositionToRestore]];

		[limitRowsField setEnabled:YES];
		[limitRowsButton setEnabled:YES];
		[limitRowsStepper setEnabled:YES];
	} else {
		[limitRowsField setEnabled:NO];
		[limitRowsButton setEnabled:NO];
		[limitRowsStepper setEnabled:NO];
		[limitRowsField setStringValue:@""];
	}

	// Set the state of the table buttons
	[addButton setEnabled:YES];
	[copyButton setEnabled:NO];
	[removeButton setEnabled:NO];

	// Trigger a data refresh
	[self loadTableValues];

	// Restore the view origin if appropriate
	if (!NSEqualRects(selectionViewportToRestore, NSZeroRect)) {

		// Let the table know the size of the newly available data
		[tableContentView reloadData];

		// Scroll the viewport to the saved location
		selectionViewportToRestore.size = [tableContentView visibleRect].size;
		[tableContentView scrollRectToVisible:selectionViewportToRestore];
	}

	// Restore selection indexes if appropriate
	if (selectionIndexToRestore) {
		[tableContentView selectRowIndexes:selectionIndexToRestore byExtendingSelection:NO];
	}
	
	// Reload the table data display
	[tableContentView reloadData];
	
	// Init copyTable with necessary information for copying selected rows as SQL INSERT
	[tableContentView setTableInstance:self withTableData:tableValues withColumns:dataColumns withTableName:selectedTable withConnection:mySQLConnection];

	// Post the notification that the query is finished
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];

	// Clear any details to restore now that they have been restored
	[self clearDetailsToRestore];
}

/**
 * Reload the table data without reconfiguring the tableView,
 * using filters and limits as appropriate.
 * Will not refresh the table view itself.
 */
- (void) loadTableValues
{
	// If no table is selected, return
	if(!selectedTable) return;

	NSMutableString *queryString;
	NSString *queryStringBeforeLimit = nil;
	NSString *filterString;
	MCPStreamingResult *streamingResult;
	int rowsToLoad = [[tableDataInstance statusValueForKey:@"Rows"] intValue];
	
	// Notify any listeners that a query has started
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];
	
	// Start construction of the query string
	queryString = [NSMutableString stringWithFormat:@"SELECT %@ FROM %@", [self fieldListForQuery], [selectedTable backtickQuotedString]];

	// Add a filter string if appropriate
	filterString = [self tableFilterString];
	
	if (filterString) {
		[queryString appendFormat:@" WHERE %@", filterString];
		isFiltered = YES;
	} else {
		isFiltered = NO;
	}

	// Add sorting details if appropriate
	if (sortCol) {
		[queryString appendFormat:@" ORDER BY %@", [[[dataColumns objectAtIndex:[sortCol intValue]] objectForKey:@"name"] backtickQuotedString]];
		if (isDesc) [queryString appendString:@" DESC"];
	}

	// Check to see if a limit needs to be applied
	if ([prefs boolForKey:@"LimitResults"]) {

		// Ensure the limit isn't negative
		if ([limitRowsField intValue] <= 0) {
			[limitRowsField setStringValue:@"1"];
		}

		// If the result set is being limited, take a copy of the string to allow resetting limit
		// if no results are found
		if ([limitRowsField intValue] > 1) {
			queryStringBeforeLimit = [NSString stringWithString:queryString];
		}

		// Append the limit settings
		[queryString appendFormat:@" LIMIT %d,%d", [limitRowsField intValue]-1, [prefs integerForKey:@"LimitResultsValue"]];

		// Update the approximate count of the rows to load
		rowsToLoad = rowsToLoad - ([limitRowsField intValue]-1);
		if (rowsToLoad > [prefs integerForKey:@"LimitResultsValue"]) rowsToLoad = [prefs integerForKey:@"LimitResultsValue"];
	}
	
	// Perform and process the query
	[self setUsedQuery:queryString];
	streamingResult = [mySQLConnection streamingQueryString:queryString];
	[self processResultIntoDataStorage:streamingResult approximateRowCount:rowsToLoad];
	[streamingResult release];

	// If the result is empty, and a limit is active, reset the limit
	if ([prefs boolForKey:@"LimitResults"] && queryStringBeforeLimit && ![tableValues count]) {
		[limitRowsField setStringValue:@"1"];
		queryString = [NSMutableString stringWithFormat:@"%@ LIMIT 0,%d", queryStringBeforeLimit, [prefs integerForKey:@"LimitResultsValue"]];
		[self setUsedQuery:queryString];
		streamingResult = [mySQLConnection streamingQueryString:queryString];
		[self processResultIntoDataStorage:streamingResult approximateRowCount:[prefs integerForKey:@"LimitResultsValue"]];
		[streamingResult release];
	}

	if ([prefs boolForKey:@"LimitResults"]
		&& ([limitRowsField intValue] > 1
			|| [tableValues count] == [prefs integerForKey:@"LimitResultsValue"]))
	{
		isLimited = YES;
	} else {
		isLimited = NO;
	}

	// Update the rows count as necessary
	[self updateNumberOfRows];

	// Set the filter text
	[self updateCountText];
	
	// Notify listenters that the query has finished
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
}

/**
 * Returns the query string for the current filter settings,
 * ready to be dropped into a WHERE clause, or nil if no filtering
 * is active.
 */
- (NSString *)tableFilterString
{

	// If the clause has the placeholder $BINARY that placeholder will be replaced
	// by BINARY if the user pressed ⇧ while invoking 'Filter' otherwise it will
	// replaced by @"".
	BOOL caseSensitive = (([[NSApp currentEvent] modifierFlags] 
		& (NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask)) > 0);

	NSString *filterString;

	if(contentFilters == nil) {
		NSLog(@"Fatal error while retrieving content filters. No filters found.");
		NSBeep();
		return nil;
	}

	// Current selected filter type
	if(![contentFilters objectForKey:compareType]) {
		NSLog(@"Error while retrieving filters. Filter type “%@” unknown.", compareType);
		NSBeep();
		return nil;
	}
	NSDictionary *filter = [[contentFilters objectForKey:compareType] objectAtIndex:[[compareField selectedItem] tag]];

	if(![filter objectForKey:@"Clause"] || ![filter objectForKey:@"NumberOfArguments"]) {
		NSLog(@"Error while retrieving filter clause. No “Clause” or/and “NumberOfArguments” key found.");
		NSBeep();
		return nil;
	}

	NSUInteger numberOfArguments = [[filter objectForKey:@"NumberOfArguments"] intValue];

	// argument if Filter requires only one argument
	NSMutableString *argument = [[NSMutableString alloc] initWithString:[argumentField stringValue]];

	// If the filter field is empty and the selected filter does not require
	// only one argument, then no filtering is required - return nil.
	if (![argument length] && numberOfArguments == 1) {
		[argument release];
		return nil;
	}

	// arguments if Filter requires two arguments
	NSMutableString *firstBetweenArgument  = [[NSMutableString alloc] initWithString:[firstBetweenField stringValue]];
	NSMutableString *secondBetweenArgument = [[NSMutableString alloc] initWithString:[secondBetweenField stringValue]];

	// If filter requires two arguments and either of the argument fields are empty 
	// return nil.
	if (numberOfArguments == 2) {
		if (([firstBetweenArgument length] == 0) || ([secondBetweenArgument length] == 0)) {
			[argument release];
			[firstBetweenArgument release];
			[secondBetweenArgument release];
			return nil;
		}
	}

	// Retrieve actual WHERE clause
	NSMutableString *clause = [[NSMutableString alloc] init];
	[clause setString:[filter objectForKey:@"Clause"]];

	[clause replaceOccurrencesOfRegex:@"\\$BINARY" withString:(caseSensitive) ? @"BINARY" : @""];
	[clause flushCachedRegexData];

	// Escape % sign
	[clause replaceOccurrencesOfRegex:@"%" withString:@"%%"];
	[clause flushCachedRegexData];

	// Replace placeholder ${} by %@
	NSRange matchedRange;
	NSString *re = @"(?<!\\\\)\\$\\{.*?\\}";
	if([clause isMatchedByRegex:re]) {
		while([clause isMatchedByRegex:re]) {
			matchedRange = [clause rangeOfRegex:re];
			[clause replaceCharactersInRange:matchedRange withString:@"%@"];
			[clause flushCachedRegexData];
		}
	}

	// Check number of placeholders and given 'NumberOfArguments'
	if([clause replaceOccurrencesOfString:@"%@" withString:@"%@" options:NSLiteralSearch range:NSMakeRange(0, [clause length])] != numberOfArguments) {
		NSLog(@"Error while setting filter string. “NumberOfArguments” differs from the number of arguments specified in “Clause”.");
		NSBeep();
		[argument release];
		[firstBetweenArgument release];
		[secondBetweenArgument release];
		[clause release];
		return nil;
	}

	// Construct the filter string according the required number of arguments
	if (numberOfArguments == 2) {
		filterString = [NSString stringWithFormat:@"%@ %@", 
			[[fieldField titleOfSelectedItem] backtickQuotedString], 
			[NSString stringWithFormat:clause, 
				[self escapeFilterArgument:firstBetweenArgument againstClause:clause], 
				[self escapeFilterArgument:secondBetweenArgument againstClause:clause]]];
	} else if (numberOfArguments == 1) {
		filterString = [NSString stringWithFormat:@"%@ %@", 
			[[fieldField titleOfSelectedItem] backtickQuotedString], 
			[NSString stringWithFormat:clause, [self escapeFilterArgument:argument againstClause:clause]]];
	} else {
		filterString = [NSString stringWithFormat:@"%@ %@", 
			[[fieldField titleOfSelectedItem] backtickQuotedString], 
			[filter objectForKey:@"Clause"]];
			if(numberOfArguments > 2) {
				NSLog(@"Filter with more than 2 arguments is not yet supported.");
				NSBeep();
			}
	}

	[argument release];
	[firstBetweenArgument release];
	[secondBetweenArgument release];
	[clause release];

	// Return the filter string
	return filterString;
}

- (NSString *)escapeFilterArgument:(NSString *)argument againstClause:(NSString *)clause
{

	NSMutableString *arg = [[NSMutableString alloc] init];
	[arg setString:argument];

	[arg replaceOccurrencesOfRegex:@"(\\\\)(?![nrt])" withString:@"\\\\\\\\\\\\\\\\"];
	[arg flushCachedRegexData];
	[arg replaceOccurrencesOfRegex:@"(\\\\)(?=[nrt])" withString:@"\\\\\\"];
	[arg flushCachedRegexData];
	
	// Get quote sign for escaping - this should work for 99% of all cases
	NSString *quoteSign = [clause stringByMatching:@"([\"'])[^\\1]*?%@[^\\1]*?\\1" capture:1L];
	// Esape argument
	if(quoteSign != nil && [quoteSign length] == 1) {
		[arg replaceOccurrencesOfRegex:[NSString stringWithFormat:@"(%@)", quoteSign] withString:@"\\\\$1"];
		[arg flushCachedRegexData];
	}
	if([clause isMatchedByRegex:@"(?i)\\blike\\b.*?%(?!@)"]) {
		NSLog(@"asdas", _cmd);
		[arg replaceOccurrencesOfRegex:@"([_%])" withString:@"\\\\$1"];
		[arg flushCachedRegexData];
	}
	return [arg autorelease];
}

/*
 * Update the table count/selection text
 */
- (void)updateCountText
{
	NSString *rowString;
	NSMutableString *countString = [NSMutableString string];

	// If no filter or limit is active, show just the count of rows in the table
	if (!isFiltered && !isLimited) {
		if ([tableValues count] == 1)
			[countString appendFormat:NSLocalizedString(@"%d row in table", @"text showing a single row in the result"), [tableValues count]];
		else
			[countString appendFormat:NSLocalizedString(@"%d rows in table", @"text showing how many rows are in the result"), [tableValues count]];

	// If a limit is active, display a string suggesting a limit is active
	} else if (!isFiltered && isLimited) {
		[countString appendFormat:NSLocalizedString(@"Rows %d-%d of %@%d from table", @"text showing how many rows are in the limited result"), [limitRowsField intValue], [limitRowsField intValue]+[tableValues count]-1, maxNumRowsIsEstimate?@"~":@"", maxNumRows];

	// If just a filter is active, show a count and an indication a filter is active
	} else if (isFiltered && !isLimited) {
		if ([tableValues count] == 1)
			[countString appendFormat:NSLocalizedString(@"%d row of %@%d matches filter", @"text showing how a single rows matched filter"), [tableValues count], maxNumRowsIsEstimate?@"~":@"", maxNumRows];
		else
			[countString appendFormat:NSLocalizedString(@"%d rows of %@%d match filter", @"text showing how many rows matched filter"), [tableValues count], maxNumRowsIsEstimate?@"~":@"", maxNumRows];

	// If both a filter and limit is active, display full string
	} else {
		[countString appendFormat:NSLocalizedString(@"Rows %d-%d from filtered matches", @"text showing how many rows are in the limited filter match"), [limitRowsField intValue], [limitRowsField intValue]+[tableValues count]-1];
	}

	// If rows are selected, append selection count
	if ([tableContentView numberOfSelectedRows] > 0) {
		[countString appendString:@"; "];
		if ([tableContentView numberOfSelectedRows] == 1)
			rowString = [NSString stringWithString:NSLocalizedString(@"row", @"singular word for row")];
		else
			rowString = [NSString stringWithString:NSLocalizedString(@"rows", @"plural word for rows")];
		[countString appendFormat:NSLocalizedString(@"%d %@ selected", @"text showing how many rows are selected"), [tableContentView numberOfSelectedRows], rowString];
	}

	[countText setStringValue:countString];
}

#pragma mark -
#pragma mark Table interface actions

/*
 * Reloads the current table data, performing a new SQL query. Now attempts to preserve sort order, filters, and viewport.
 */
- (IBAction)reloadTable:(id)sender
{
	// Check whether a save of the current row is required.
	if (![self saveRowOnDeselect]) return;

	// Save view details to restore safely if possible
	[self storeCurrentDetailsForRestoration];

	// Clear the table data column cache
	[tableDataInstance resetColumnData];

	// Load the table's data
	[self loadTable:selectedTable];
}

/*
 * Filter the table with arguments given by the user
 */
- (IBAction)filterTable:(id)sender
{

	// Check whether a save of the current row is required.
	if (![self saveRowOnDeselect]) return;

	// Update history
	[spHistoryControllerInstance updateHistoryEntries];

	// Update negative limits
	if ([limitRowsField intValue] <= 0) {
		[limitRowsField setStringValue:@"1"];
	}

	// If limitRowsField > number of total table rows show the last limitRowsValue rows
	if ([prefs boolForKey:@"LimitResults"] && [limitRowsField intValue] >= maxNumRows) {
		int newLimit = maxNumRows - [prefs integerForKey:@"LimitResultsValue"];
		[limitRowsField setStringValue:[[NSNumber numberWithInt:(newLimit<1)?1:newLimit] stringValue]];
	}

	// Reload data using the new filter settings
	[self loadTableValues];
	
	// Reset the table view
	[tableContentView scrollPoint:NSMakePoint(0.0, 0.0)];
	[tableContentView reloadData];
}

/**
 * Enables or disables the filter input field based on the selected filter type.
 */
- (IBAction)toggleFilterField:(id)sender
{

	NSDictionary *filter = [[contentFilters objectForKey:compareType] objectAtIndex:[[compareField selectedItem] tag]];
	if ([[filter objectForKey:@"NumberOfArguments"] intValue] == 2) {
		[argumentField setHidden:YES];

		if([filter objectForKey:@"ConjunctionLabels"] && [[filter objectForKey:@"ConjunctionLabels"] count] == 1)
			[betweenTextField setStringValue:[[filter objectForKey:@"ConjunctionLabels"] objectAtIndex:0]];
		[betweenTextField setHidden:NO];
		[firstBetweenField setHidden:NO];
		[secondBetweenField setHidden:NO];

		[firstBetweenField setEnabled:YES];
		[secondBetweenField setEnabled:YES];
		[firstBetweenField selectText:self];
	}
	else if ([[filter objectForKey:@"NumberOfArguments"] intValue] == 1){
		[argumentField setHidden:NO];
		[argumentField setEnabled:YES];
		[argumentField selectText:self];

		[betweenTextField setHidden:YES];
		[firstBetweenField setHidden:YES];
		[secondBetweenField setHidden:YES];
	}
	else {
		[argumentField setHidden:NO];
		[argumentField setEnabled:NO];

		[betweenTextField setHidden:YES];
		[firstBetweenField setHidden:YES];
		[secondBetweenField setHidden:YES];

		// Start search if no argument is required
		[self filterTable:self];
	}

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

#pragma mark -
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
	[tableValues addObject:newRow];

	[tableContentView reloadData];
	[tableContentView selectRowIndexes:[NSIndexSet indexSetWithIndex:[tableContentView numberOfRows]-1] byExtendingSelection:NO];
	isEditingRow = YES;
	isEditingNewRow = YES;
	currentlyEditingRow = [tableContentView selectedRow];
	if ( [multipleLineEditingButton state] == NSOffState )
		[tableContentView editColumn:0 row:[tableContentView numberOfRows]-1 withEvent:nil select:YES];
}

/**
 * Copies a row of the table-array and goes into edit mode
 */
- (IBAction)copyRow:(id)sender
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
	tempRow = [NSMutableArray arrayWithArray:[tableValues objectAtIndex:[tableContentView selectedRow]]];
	[tableValues insertObject:tempRow atIndex:[tableContentView selectedRow]+1];
	
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
	[tableContentView selectRowIndexes:[NSIndexSet indexSetWithIndex:[tableContentView selectedRow]+1] byExtendingSelection:NO];
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
	
	if (([tableContentView numberOfSelectedRows] == [tableContentView numberOfRows]) && !isFiltered && !isLimited) {
		
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
			id o = [NSArrayObjectAtIndex(tableValues, i) objectAtIndex:[[tableColumn identifier] intValue]];
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
	if ( ![prefs boolForKey:@"LimitResults"] ) {
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

	// Save existing scroll position and details
	[spHistoryControllerInstance updateHistoryEntries];

	// Store the filter details to use when next loading the table
	NSString *targetFilterValue = [[tableValues objectAtIndex:[theArrowCell getClickedRow]] objectAtIndex:dataColumnIndex];
	NSDictionary *filterSettings = [NSDictionary dictionaryWithObjectsAndKeys:
										[refDictionary objectForKey:@"column"], @"filterField",
										targetFilterValue, @"filterValue",
										([targetFilterValue isEqualToString:[prefs objectForKey:@"NullValue"]]?@"IS NULL":nil), @"filterComparison",
										nil];
	[self setFiltersToRestore:filterSettings];

	// Attempt to switch to the new table
	if (![tablesListInstance selectTableOrViewWithName:[refDictionary objectForKey:@"table"]]) {
		NSBeep();
		[self setFiltersToRestore:nil];
	}
}

/**
 * Sets the compare types for the filter and the appropriate formatter for the textField
 */
- (IBAction)setCompareTypes:(id)sender
{

	if(contentFilters == nil 
		|| ![contentFilters objectForKey:@"number"]
		|| ![contentFilters objectForKey:@"string"]
		|| ![contentFilters objectForKey:@"date"]) {
		NSLog(@"Error while setting filter types.");
		NSBeep();
		return;
	}

	NSString *fieldTypeGrouping = [NSString stringWithString:[[tableDataInstance columnWithName:[[fieldField selectedItem] title]] objectForKey:@"typegrouping"]];

	[compareField removeAllItems];
	
	if ( [fieldTypeGrouping isEqualToString:@"date"] ) {
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
	} else if ([fieldTypeGrouping isEqualToString:@"string"]   || [fieldTypeGrouping isEqualToString:@"binary"]
			|| [fieldTypeGrouping isEqualToString:@"textdata"] || [fieldTypeGrouping isEqualToString:@"blobdata"]
			|| [fieldTypeGrouping isEqualToString:@"enum"]) {

		compareType = @"string";
		// [argumentField setFormatter:nil];

	} else if ([fieldTypeGrouping isEqualToString:@"bit"] || [fieldTypeGrouping isEqualToString:@"integer"]
				|| [fieldTypeGrouping isEqualToString:@"float"]) {
		compareType = @"number";
		// [argumentField setFormatter:numberFormatter];

	} else  {
		compareType = @"";
		NSBeep();
		NSLog(@"ERROR: unknown type for comparision: %@, in %@", [[tableDataInstance columnWithName:[[fieldField selectedItem] title]] objectForKey:@"type"], fieldTypeGrouping);
	}
	
	// Add IS NULL and IS NOT NULL as they should always be available
	// [compareField addItemWithTitle:@"IS NULL"];
	// [compareField addItemWithTitle:@"IS NOT NULL"];

	// Remove user-defined filters first
	if([numberOfDefaultFilters objectForKey:compareType]) {
		NSUInteger cycles = [[contentFilters objectForKey:compareType] count] - [[numberOfDefaultFilters objectForKey:compareType] intValue];
		while(cycles > 0) {
			[[contentFilters objectForKey:compareType] removeLastObject];
			cycles--;
		}
	}

	// Load user-defined content filters
	if([prefs objectForKey:@"ContentFilters"] 
		&& [contentFilters objectForKey:compareType]
		&& [[prefs objectForKey:@"ContentFilters"] objectForKey:compareType])
	{
		[[contentFilters objectForKey:compareType] addObjectsFromArray:[[prefs objectForKey:@"ContentFilters"] objectForKey:compareType]];
	}

	// Rebuild operator popup menu
	NSUInteger i = 0;
	NSMenu *menu = [compareField menu];
	if([contentFilters objectForKey:compareType])
		for(id filter in [contentFilters objectForKey:compareType]) {
			NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:([filter objectForKey:@"MenuLabel"])?[filter objectForKey:@"MenuLabel"]:@"not specified" action:NULL keyEquivalent:@""];
			if([filter objectForKey:@"Tooltip"])
				[item setToolTip:[filter objectForKey:@"Tooltip"]];
			[item setTag:i];
			[menu addItem:item];
			[item release];
			i++;
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
		[limitRowsField setIntValue:(newStep>maxNumRows)?[limitRowsField intValue]:newStep];
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
 * Processes a supplied streaming result set, loading it into the data array.
 */
- (void)processResultIntoDataStorage:(MCPStreamingResult *)theResult approximateRowCount:(long)targetRowCount
{
	NSArray *tempRow;
	NSMutableArray *newRow;
	NSMutableArray *columnBlobStatuses = [[NSMutableArray alloc] init];
	NSUInteger i;
	
	// Update the progress wheel every ~15%
	NSUInteger loadingIndicatorDelta = 15;

	NSUInteger lastProgressValue = loadingIndicatorDelta;
	float relativeTargetRowCount = 100.0/targetRowCount;

	long rowsProcessed = 0;
	long columnsCount = [dataColumns count];

	NSAutoreleasePool *dataLoadingPool;
	NSProgressIndicator *dataLoadingIndicator = [tableDocumentInstance valueForKey:@"queryProgressBar"];
	id prefsNullValue = [[prefs objectForKey:@"NullValue"] retain];
	BOOL prefsLoadBlobsAsNeeded = [prefs boolForKey:@"LoadBlobsAsNeeded"];
	Class nullClass = [NSNull class];

	// Build up an array of which columns are blobs for faster iteration
	for ( i = 0; i < columnsCount ; i++ ) {
		[columnBlobStatuses addObject:[NSNumber numberWithBool:[tableDataInstance columnIsBlobOrText:[NSArrayObjectAtIndex(dataColumns, i) objectForKey:@"name"] ]]];
	}

	// Remove all items from the table and reset the progress indicator
	[tableValues removeAllObjects];
	if (targetRowCount) [dataLoadingIndicator setIndeterminate:NO];
	[dataLoadingIndicator setDoubleValue:(int)loadingIndicatorDelta/2];
	[dataLoadingIndicator display];

	// Set up an autorelease pool for row processing
	dataLoadingPool = [[NSAutoreleasePool alloc] init];

	// Loop through the result rows as they become available
	while (tempRow = [theResult fetchNextRowAsArray]) {
		NSMutableArrayAddObject(tableValues, [NSMutableArray arrayWithCapacity:columnsCount]);
		newRow = NSArrayObjectAtIndex(tableValues, rowsProcessed);

		// Process the retrieved row
		for ( i = 0; i < columnsCount; i++ ) {
			if ( [NSArrayObjectAtIndex(tempRow, i) isMemberOfClass:nullClass] ) {
				NSMutableArrayAddObject(newRow, prefsNullValue);
			} else {
				NSMutableArrayAddObject(newRow, NSArrayObjectAtIndex(tempRow, i));
			}
		}

		// Add values for hidden blob and text fields if appropriate
		if ( prefsLoadBlobsAsNeeded ) {
			for ( i = 0 ; i < columnsCount ; i++ ) {
				if ( [NSArrayObjectAtIndex(columnBlobStatuses, i) boolValue] ) {
					[newRow replaceObjectAtIndex:i withObject:NSLocalizedString(@"(not loaded)", @"value shown for hidden blob and text fields")];
				}
			}
		}

		// Update the progress bar as necessary, minimising updates
		rowsProcessed++;
		if (rowsProcessed < targetRowCount) {
			[dataLoadingIndicator setDoubleValue:(rowsProcessed*relativeTargetRowCount)];
			if ((int)[dataLoadingIndicator doubleValue] > lastProgressValue) {
				[dataLoadingIndicator display];
				lastProgressValue = (int)[dataLoadingIndicator doubleValue] + loadingIndicatorDelta;
			}
		} else if (rowsProcessed == targetRowCount) {
			[dataLoadingIndicator setIndeterminate:YES];
		}

		// Drain and reset the autorelease pool every ~1024 rows
		if (!(rowsProcessed % 1024)) {
			[dataLoadingPool drain];
			dataLoadingPool = [[NSAutoreleasePool alloc] init];
		}
	}
	
	// Clean up the autorelease pool and reset the progress indicator
	[dataLoadingPool drain];
	[dataLoadingIndicator setIndeterminate:YES];
	
	[columnBlobStatuses release];
	[prefsNullValue release];
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
	id rowObject;
	NSMutableString *rowValue = [NSMutableString string];
	NSString *currentTime = [[NSDate date] descriptionWithCalendarFormat:@"%H:%M:%S" timeZone:nil locale:nil];
	int i;
	
	if ( !isEditingRow || currentlyEditingRow == -1) {
		return YES;
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];

	// If editing, compare the new row to the old row and if they are identical finish editing without saving.
	if (!isEditingNewRow && [oldRow isEqualToArray:[tableValues objectAtIndex:currentlyEditingRow]]) {
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
		rowObject = [NSArrayObjectAtIndex(tableValues, currentlyEditingRow) objectAtIndex:i];
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
		[tableValues replaceObjectAtIndex:currentlyEditingRow withObject:[NSMutableArray arrayWithArray:oldRow]];
		isEditingRow = NO;
		isEditingNewRow = NO;
		currentlyEditingRow = -1;
		[[SPQueryController sharedQueryController] showErrorInConsole:[NSString stringWithFormat:NSLocalizedString(@"/* WARNING %@ No rows have been affected */\n", @"warning shown in the console when no rows have been affected after writing to the db"), currentTime]];
		return YES;

	// On success...
	} else if ( [[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
		isEditingRow = NO;

		// New row created successfully
		if ( isEditingNewRow ) {
			if ( [prefs boolForKey:@"ReloadAfterAddingRow"] ) {
				[self loadTableValues];
				[tableWindow endEditingFor:nil];
				[tableContentView reloadData];
			} else {

				// Set the insertId for fields with auto_increment
				for ( i = 0; i < [dataColumns count] ; i++ ) {
					if ([[NSArrayObjectAtIndex(dataColumns, i) objectForKey:@"autoincrement"] intValue]) {
						[[tableValues objectAtIndex:currentlyEditingRow] replaceObjectAtIndex:i withObject:[[NSNumber numberWithLong:[mySQLConnection insertId]] description]];
					}
				}
			}
			isEditingNewRow = NO;

		// Existing row edited successfully
		} else {

			// Reload table if set to - otherwise no action required.
			if ( [prefs boolForKey:@"ReloadAfterEditingRow"] ) {
				[self loadTableValues];
				[tableWindow endEditingFor:nil];
				[tableContentView reloadData];
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
	[tableContentView selectRowIndexes:[NSIndexSet indexSetWithIndex:currentlyEditingRow] byExtendingSelection:NO];
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
			tempValue = [NSArrayObjectAtIndex(tableValues, row) objectAtIndex:[[[tableDataInstance columnWithName:NSArrayObjectAtIndex(keys, i)] objectForKey:@"datacolumnindex"] intValue]];

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
	NSString *wherePart;
	int i, errors;
	
	if ( [contextInfo isEqualToString:@"addrow"] ) {
		[sheet orderOut:self];
		
		if ( returnCode == NSAlertDefaultReturn ) {
			//problem: reenter edit mode doesn't function
			[tableContentView editColumn:0 row:[tableContentView selectedRow] withEvent:nil select:YES];
		} else {
			if ( !isEditingNewRow ) {
				[tableValues replaceObjectAtIndex:[tableContentView selectedRow]
										  withObject:[NSMutableArray arrayWithArray:oldRow]];
				isEditingRow = NO;
			} else {
				[tableValues removeObjectAtIndex:[tableContentView selectedRow]];
				isEditingRow = NO;
				isEditingNewRow = NO;
			}
			currentlyEditingRow = -1;
		}
		[tableContentView reloadData];
	} else if ( [contextInfo isEqualToString:@"removeallrows"] ) {
		if ( returnCode == NSAlertDefaultReturn ) {
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
				[self loadTableValues];
				[tableContentView reloadData];
			} else {
				for ( i = 0 ; i < [tableValues count] ; i++ ) {
					if ( ![tempArray containsObject:[NSNumber numberWithInt:i]] )
						[tempResult addObject:NSArrayObjectAtIndex(tableValues, i)];
				}
				[tableValues setArray:tempResult];
				[tableContentView reloadData];
			}
			[tableContentView deselectAll:self];
		}
	}
}

/**
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

#pragma mark -
#pragma mark Retrieving and setting table state

/**
 * Provide a getter for the table's sort column name
 */
- (NSString *) sortColumnName
{
	if (!sortCol || !dataColumns) return nil;

	return [[dataColumns objectAtIndex:[sortCol intValue]] objectForKey:@"name"];
}

/**
 * Provide a getter for the table current sort order
 */
- (BOOL) sortColumnIsAscending
{
	return !isDesc;
}

/**
 * Provide a getter for the table's selected rows index set
 */
- (NSIndexSet *) selectedRowIndexes
{
	return [tableContentView selectedRowIndexes];
}

/**
 * Provide a getter for the LIMIT position
 */
- (unsigned int) limitStart
{
	return [limitRowsField intValue];
}

/**
 * Provide a getter for the table's current viewport
 */
- (NSRect) viewport
{
	return [tableContentView visibleRect];
}

/**
 * Provide a getter for the current filter details
 */
- (NSDictionary *) filterSettings
{
	NSDictionary *theDictionary;

	if (![fieldField isEnabled]) return nil;

	theDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
						[[fieldField selectedItem] title], @"filterField",
						[[compareField selectedItem] title], @"filterComparison",
						[NSNumber numberWithInt:[[compareField selectedItem] tag]], @"filterComparisonTag",
						[argumentField stringValue], @"filterValue",
						[firstBetweenField stringValue], @"firstBetweenField",
						[secondBetweenField stringValue], @"secondBetweenField",
						nil];

	return theDictionary;
}

/**
 * Set the sort column and sort order to restore on next table load
 */
- (void) setSortColumnNameToRestore:(NSString *)theSortColumnName isAscending:(BOOL)isAscending
{
	if (sortColumnToRestore) [sortColumnToRestore release], sortColumnToRestore = nil;

	if (theSortColumnName) {
		sortColumnToRestore = [[NSString alloc] initWithString:theSortColumnName];
		sortColumnToRestoreIsAsc = isAscending;
	}
}

/**
 * Sets the value for the limit start position to use on next table load
 */
- (void) setLimitStartToRestore:(unsigned int)theLimitStart
{
	limitStartPositionToRestore = theLimitStart;
}

/**
 * Set the selected row indexes to restore on next table load
 */
- (void) setSelectedRowIndexesToRestore:(NSIndexSet *)theIndexSet
{
	if (selectionIndexToRestore) [selectionIndexToRestore release], selectionIndexToRestore = nil;

	if (theIndexSet) selectionIndexToRestore = [[NSIndexSet alloc] initWithIndexSet:theIndexSet];
}

/**
 * Set the viewport to restore on next table load
 */
- (void) setViewportToRestore:(NSRect)theViewport
{
	selectionViewportToRestore = theViewport;
}

/**
 * Set the filter settings to restore (if possible) on next table load
 */
- (void) setFiltersToRestore:(NSDictionary *)filterSettings
{
	if (filterFieldToRestore) [filterFieldToRestore release], filterFieldToRestore = nil;
	if (filterComparisonToRestore) [filterComparisonToRestore release], filterComparisonToRestore = nil;
	if (filterValueToRestore) [filterValueToRestore release], filterValueToRestore = nil;
	if (firstBetweenValueToRestore) [firstBetweenValueToRestore release], firstBetweenValueToRestore = nil;
	if (secondBetweenValueToRestore) [secondBetweenValueToRestore release], secondBetweenValueToRestore = nil;

	if (filterSettings) {
		if ([filterSettings objectForKey:@"filterField"])
			filterFieldToRestore = [[NSString alloc] initWithString:[filterSettings objectForKey:@"filterField"]];
		if ([filterSettings objectForKey:@"filterComparison"]) {
			// Check if operator is BETWEEN, if so set up input fields
			if([[filterSettings objectForKey:@"filterComparison"] isEqualToString:@"BETWEEN"]) {
				[argumentField setHidden:YES];
				[betweenTextField setHidden:NO];
				[firstBetweenField setHidden:NO];
				[secondBetweenField setHidden:NO];
				[firstBetweenField setEnabled:YES];
				[secondBetweenField setEnabled:YES];
			}
			
			filterComparisonToRestore = [[NSString alloc] initWithString:[filterSettings objectForKey:@"filterComparison"]];
		}
		if([[filterSettings objectForKey:@"filterComparison"] isEqualToString:@"BETWEEN"]) {
			if ([filterSettings objectForKey:@"firstBetweenField"])
				firstBetweenValueToRestore = [[NSString alloc] initWithString:[filterSettings objectForKey:@"firstBetweenField"]];
			if ([filterSettings objectForKey:@"secondBetweenField"])
				secondBetweenValueToRestore = [[NSString alloc] initWithString:[filterSettings objectForKey:@"secondBetweenField"]];
		} else {
			if ([filterSettings objectForKey:@"filterValue"])
				filterValueToRestore = [[NSString alloc] initWithString:[filterSettings objectForKey:@"filterValue"]];
		}
	}
}

/**
 * Convenience method for storing all current settings for restoration
 */
- (void) storeCurrentDetailsForRestoration
{
	[self setSortColumnNameToRestore:[self sortColumnName] isAscending:[self sortColumnIsAscending]];
	[self setLimitStartToRestore:[self limitStart]];
	[self setSelectedRowIndexesToRestore:[self selectedRowIndexes]];
	[self setViewportToRestore:[self viewport]];
	[self setFiltersToRestore:[self filterSettings]];
}

/**
 * Convenience method for clearing any settings to restore
 */
- (void) clearDetailsToRestore
{
	[self setSortColumnNameToRestore:nil isAscending:YES];
	[self setLimitStartToRestore:1];
	[self setSelectedRowIndexesToRestore:nil];
	[self setViewportToRestore:NSZeroRect];
	[self setFiltersToRestore:nil];
}

#pragma mark -
#pragma mark Table drawing and editing

/**
 * Updates the number of rows in the selected table.
 * Attempts to use the fullResult count if available, also updating the
 * table data store; otherwise, uses the table data store if accurate or
 * falls back to a fetch if necessary and set in preferences.
 * The prefs option "fetch accurate row counts" is used as a last resort as
 * it can be very slow on large InnoDB tables which require a full table scan.
 */
- (void)updateNumberOfRows
{

	// For unfiltered and non-limited tables, use the result count - and update the status count
	if (!isLimited && !isFiltered) {
		maxNumRows = [tableValues count];
		maxNumRowsIsEstimate = NO;
		[tableDataInstance setStatusValue:[NSString stringWithFormat:@"%d", maxNumRows] forKey:@"Rows"];
		[tableDataInstance setStatusValue:@"y" forKey:@"RowsCountAccurate"];
		[tableInfoInstance tableChanged:nil];
		[[tableDocumentInstance valueForKey:@"extendedTableInfoInstance"] loadTable:selectedTable];

	// Otherwise, if the table status value is accurate, use it
	} else if ([[tableDataInstance statusValueForKey:@"RowsCountAccurate"] boolValue]) {
		maxNumRows = [[tableDataInstance statusValueForKey:@"Rows"] intValue];
		maxNumRowsIsEstimate = NO;

	// Choose whether to display an estimate, or to fetch the correct row count, based on prefs
	} else if ([prefs boolForKey:@"FetchCorrectRowCount"]) {
		maxNumRows = [self fetchNumberOfRows];
		maxNumRowsIsEstimate = NO;
		[tableDataInstance setStatusValue:[NSString stringWithFormat:@"%d", maxNumRows] forKey:@"Rows"];
		[tableDataInstance setStatusValue:@"y" forKey:@"RowsCountAccurate"];
		[tableInfoInstance tableChanged:nil];
		[[tableDocumentInstance valueForKey:@"extendedTableInfoInstance"] loadTable:selectedTable];

	// Use the estimate count
	} else {
		maxNumRows = [[tableDataInstance statusValueForKey:@"Rows"] intValue];
		maxNumRowsIsEstimate = YES;
	}
}

/*
 * Fetches the number of rows in the selected table using a "SELECT COUNT(1)" query and return it
 */
- (int)fetchNumberOfRows
{
	return [[[[mySQLConnection queryString:[NSString stringWithFormat:@"SELECT COUNT(1) FROM %@", [selectedTable backtickQuotedString]]] fetchRowAsArray] objectAtIndex:0] intValue];
}

#pragma mark -
#pragma mark TableView delegate methods

/**
 * Show the table cell content as tooltip
 * - for text displays line breaks and tabs as well
 * - if blob data can be interpret as image data display the image as  transparent thumbnail
 *    (up to now using base64 encoded HTML data)
 */
- (NSString *)tableView:(NSTableView *)aTableView toolTipForCell:(SPTextAndLinkCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation
{

	if([[aCell stringValue] length] < 2) return nil;

	NSImage *image;

	NSPoint pos = [NSEvent mouseLocation];
	pos.y -= 20;
	
	// Try to get the original data. If not possible return nil.
	// @try clause is used due to the multifarious cases of
	// possible exceptions (eg for reloading tables etc.)
	id theValue;
	@try{
		theValue = NSArrayObjectAtIndex(NSArrayObjectAtIndex(tableValues, row), [[aTableColumn identifier] intValue]);
	}
	@catch(id ae) {
		return nil;
	}

	// Get the original data for trying to display the blob data as an image
	if ([theValue isKindOfClass:[NSData class]]) {
		image = [[[NSImage alloc] initWithData:theValue] autorelease];
		if(image) {
			[SPTooltip showWithObject:image atLocation:pos ofType:@"image"];
			return nil;
		}
	}

	// Show the cell string value as tooltip (including line breaks and tabs)
	[SPTooltip showWithObject:[aCell stringValue] atLocation:pos];

	return nil;
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [tableValues count];
}

- (id)tableView:(CMCopyTable *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	id theValue = NSArrayObjectAtIndex(NSArrayObjectAtIndex(tableValues, rowIndex), [[aTableColumn identifier] intValue]);

	if ([theValue isKindOfClass:[NSData class]])
		return [theValue shortStringRepresentationUsingEncoding:[mySQLConnection encoding]];

	return theValue;
}

/**
 * This function changes the text color of text/blob fields which are not yet loaded to gray
 */
- (void)tableView:(CMCopyTable *)aTableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn*)aTableColumn row:(int)row
{
	// If user wants to edit 'cell' set text color to black and return to avoid
	// writing in gray if value was NULL
	if ( [aTableView editedColumn] == [[aTableColumn identifier] intValue] && [aTableView editedRow] == row) {
		[cell setTextColor:[NSColor blackColor]];
		return;
	}

	NSDictionary *column = NSArrayObjectAtIndex(dataColumns, [[aTableColumn identifier] intValue]);

	// For NULL cell's display the user's NULL value placeholder in grey to easily distinguish it from other values 
	if ([cell respondsToSelector:@selector(setTextColor:)]) {
		
		// Note that this approach of changing the color of NULL placeholders is dependent on the cell's value matching that
		// of the user's NULL value preference which was set in the result array when it was retrieved (see fetchResultAsArray).
		// Also, as an added measure check that the table column actually allows NULLs to make sure we don't change a cell that
		// happens to have a value matching the NULL placeholder, but the column doesn't allow NULLs.
		[cell setTextColor:([[cell stringValue] isEqualToString:[prefs objectForKey:@"NullValue"]] && [[column objectForKey:@"null"] boolValue]) ? [NSColor lightGrayColor] : [NSColor blackColor]];
	}

	// Check if loading of text/blob fields is disabled
	// If not, all text fields are loaded and we don't have to make them gray
	if ([prefs boolForKey:@"LoadBlobsAsNeeded"])
	{
		// Make sure that the cell actually responds to setTextColor:
		// In the future, we might use different cells for the table view
		// that don't support this selector
		if ([cell respondsToSelector:@selector(setTextColor:)])
		{
			// Test if the current column is a text or a blob field
			NSString *columnTypeGrouping = [column objectForKey:@"typegrouping"];
			
			if ([columnTypeGrouping isEqualToString:@"textdata"] || [columnTypeGrouping isEqualToString:@"blobdata"]) {

				// now check if the field has been loaded already or not
				if ([[cell stringValue] isEqualToString:NSLocalizedString(@"(not loaded)", @"value shown for hidden blob and text fields")])
				{
					// change the text color of the cell to gray
					[cell setTextColor:[NSColor lightGrayColor]];
				}
				else {
					// Change the text color back to black
					// This is necessary because NSTableView reuses
					// the NSCell to draw further rows in the column
					[cell setTextColor:([[cell stringValue] isEqualToString:[prefs objectForKey:@"NullValue"]] && [[column objectForKey:@"null"] boolValue]) ? [NSColor lightGrayColor] : [NSColor blackColor]];
				}
			}
		}
	}
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	// Catch editing events in the row and if the row isn't currently being edited,
	// start an edit.  This allows edits including enum changes to save correctly.
	if ( !isEditingRow ) {
		[oldRow setArray:NSArrayObjectAtIndex(tableValues, rowIndex)];
		isEditingRow = YES;
		currentlyEditingRow = rowIndex;
	}
	
	if (anObject)
		[NSArrayObjectAtIndex(tableValues, rowIndex) replaceObjectAtIndex:[[aTableColumn identifier] intValue] withObject:anObject];
	else
		[NSArrayObjectAtIndex(tableValues, rowIndex) replaceObjectAtIndex:[[aTableColumn identifier] intValue] withObject:@""];

}

#pragma mark -
#pragma mark TableView delegate methods

- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn
/*
 sorts the tableView by the clicked column
 if clicked twice, order is descending
 */
{
	
	if ( [selectedTable isEqualToString:@""] || !selectedTable )
		return;
	
	// Check whether a save of the current row is required.
	if ( ![self saveRowOnDeselect] ) return;
		
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

	// Update data using the new sort order
	[self loadTableValues];
	
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

	[tableContentView reloadData];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	// Check our notification object is our table content view
	if ([aNotification object] != tableContentView) return;

	// If we are editing a row, attempt to save that row - if saving failed, reselect the edit row.
	if (isEditingRow && [tableContentView selectedRow] != currentlyEditingRow && ![self saveRowOnDeselect]) return;
	
	// Update the row selection count
    // and update the status of the delete/duplicate buttons
	if ([tableContentView numberOfSelectedRows] > 0) {
        [copyButton setEnabled:YES];
        [removeButton setEnabled:YES];
	} 
	else {
        [copyButton setEnabled:NO];
        [removeButton setEnabled:NO];
	}

	[self updateCountText];
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

/**
 * Confirm whether to allow editing of a row. Returns YES by default, unless the multipleLineEditingButton is in
 * the ON state, or for blob or text fields - in those cases opens a sheet for editing instead and returns NO.
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{		
	NSUInteger i;
	
	// If the preference value for not showing blobs is set, check whether the row contains any blobs.
	if ([prefs boolForKey:@"LoadBlobsAsNeeded"]) {

		// If the table does contain blob or text fields, load the values ready for editing.
		if ([self tableContainsBlobOrTextColumns]) {
			NSString *wherePart = [NSString stringWithString:[self argumentForRow:[tableContentView selectedRow]]];
			
			if ([wherePart length] == 0) return NO;
						
			// Only get the data for the selected column, not all of them
			NSString *query = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@", [[[aTableColumn headerCell] stringValue] backtickQuotedString], [selectedTable backtickQuotedString], wherePart];
			
			MCPResult *tempResult = [mySQLConnection queryString:query];
			
			if (![tempResult numOfRows]) {
				NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
								  NSLocalizedString(@"Couldn't load the row. Reload the table to be sure that the row exists and use a primary key for your table.", @"message of panel when loading of row failed"));
				return NO;
			}
			
			NSArray *tempRow = [tempResult fetchRowAsArray];
			NSMutableArray *modifiedRow = [NSMutableArray array];
			
			for (i = 0; i < [tempRow count]; i++) 
			{
				[modifiedRow addObject:([[tempRow objectAtIndex:i] isMemberOfClass:[NSNull class]]) ? [prefs stringForKey:@"NullValue"] : [tempRow objectAtIndex:i]];
			}
												
			[[tableValues objectAtIndex:rowIndex] replaceObjectAtIndex:[[tableContentView tableColumns] indexOfObject:aTableColumn] withObject:[modifiedRow objectAtIndex:0]];
			[tableContentView reloadData];
		}
	}
	
	BOOL isBlob = [tableDataInstance columnIsBlobOrText:[[aTableColumn headerCell] stringValue]];
				
	// Open the sheet if the multipleLineEditingButton is enabled or the column was a blob or a text.
	if ([multipleLineEditingButton state] == NSOnState || isBlob) {
		
		SPFieldEditorController *fieldEditor = [[SPFieldEditorController alloc] init];
		
		[fieldEditor setTextMaxLength:[[[aTableColumn dataCellForRow:rowIndex] formatter] textLimit]];
		
		id editData = [[fieldEditor editWithObject:[[tableValues objectAtIndex:rowIndex] objectAtIndex:[[aTableColumn identifier] intValue]] 
								 	 fieldName:[[aTableColumn headerCell] stringValue]
								 usingEncoding:[mySQLConnection encoding] 
								  isObjectBlob:isBlob 
									isEditable:YES 
									withWindow:tableWindow] retain];

		if (editData) {
			if (!isEditingRow) {
				[oldRow setArray:[tableValues objectAtIndex:rowIndex]];
				isEditingRow = YES;
				currentlyEditingRow = rowIndex;
			}
			
			[[tableValues objectAtIndex:rowIndex] replaceObjectAtIndex:[[aTableColumn identifier] intValue] withObject:[editData copy]];
		}

		[fieldEditor release];

		if (editData) [editData release];

		return NO;
	}

	return YES;
}

/**
 * Enable drag from tableview
 */
- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard
{	
	if (tableView == tableContentView) {
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
#pragma mark SplitView delegate methods

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	return NO;
}

- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
{
	return (proposedMax - 180);
}

- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
{
	return (proposedMin + 200);
}

#pragma mark -
#pragma mark Other methods

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
			[tableValues replaceObjectAtIndex:row withObject:[NSMutableArray arrayWithArray:oldRow]];
		} else if ( isEditingNewRow ) {
			isEditingRow = NO;
			isEditingNewRow = NO;
			[tableValues removeObjectAtIndex:row];
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
	[tableValues release];
	[dataColumns release];
	[oldRow release];
	if (contentFilters) [contentFilters release];
	if (numberOfDefaultFilters) [numberOfDefaultFilters release];
	if (keys) [keys release];
	if (sortCol) [sortCol release];
	[usedQuery release];
	if (sortColumnToRestore) [sortColumnToRestore release];
	if (selectionIndexToRestore) [selectionIndexToRestore release];
	if (filterFieldToRestore) filterFieldToRestore = nil;
	if (filterComparisonToRestore) filterComparisonToRestore = nil;
	if (filterValueToRestore) filterValueToRestore = nil;
	if (firstBetweenValueToRestore) firstBetweenValueToRestore = nil;
	if (secondBetweenValueToRestore) secondBetweenValueToRestore = nil;
		
	[super dealloc];
}

@end
