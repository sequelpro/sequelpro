//
//  CustomQuery.m
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

#import "CustomQuery.h"
#import "SPSQLParser.h"
#import "SPGrowlController.h"
#import "SPStringAdditions.h"


@implementation CustomQuery



#pragma mark IBAction methods


/*
 * Split all the queries in the text view, split them into individual queries,
 * and run sequentially.
 */
- (IBAction)runAllQueries:(id)sender
{
	SPSQLParser *queryParser;
	NSArray		*queries;

	// Fixes bug in key equivalents.
	if ([[NSApp currentEvent] type] == NSKeyUp) {
		return;
	}

	// Retrieve the custom query string and split it into separate SQL queries
	queryParser = [[SPSQLParser alloc] initWithString:[textView string]];
	queries = [queryParser splitStringByCharacter:';'];
	[queryParser release];

	[self performQueries:queries];

	// Select the text of the query textView for re-editing and set standard font
	[textView selectAll:self];
	if ( [prefs boolForKey:@"useMonospacedFonts"] ) {
		[textView setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
	} else {
		[textView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}
}

/*
 * Depending on selection, run either the query containing the selection caret (if the caret is
 * at a single point within the text view), or run the selected text (if a text range is selected).
 */
- (IBAction)runSelectedQueries:(id)sender
{
	NSArray *queries;
	NSString *query;
	NSRange selectedRange = [textView selectedRange];
	SPSQLParser *queryParser;

	// If the current selection is a single caret position, run the current query.
	if (selectedRange.length == 0) {
		query = [self queryAtPosition:selectedRange.location];
		if (!query) {
			NSBeep();
			return;
		}
		queries = [NSArray arrayWithObject:query];

	// Otherwise, run the selected text.
	} else {
		queryParser = [[SPSQLParser alloc] initWithString:[[textView string] substringWithRange:selectedRange]];
		queries = [queryParser splitStringByCharacter:';'];
		[queryParser release];
	}
	
	[self performQueries:queries];
}


- (IBAction)chooseQueryFavorite:(id)sender
/*
insert the choosen favorite query in the query textView or save query to favorites or opens window to edit favorites
*/
{
	if ( [queryFavoritesButton indexOfSelectedItem] == 1) {
//save query to favorites
		//check if favorite doesn't exist
		NSEnumerator *enumerator = [queryFavorites objectEnumerator];
		id favorite;
		while ( (favorite = [enumerator nextObject]) ) {
			if ( [favorite isEqualToString:[textView string]] ) {
				NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
						NSLocalizedString(@"Query already exists in favorites.", @"message of panel when trying to save query which already exists in favorites"));
				return;
			}
		}
		if ( [[textView string] isEqualToString:@""] ) {
				NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
						NSLocalizedString(@"Query can't be empty.", @"message of panel when trying to save empty query"));
				return;
		}
		[queryFavorites addObject:[NSString stringWithString:[textView string]]];
		[queryFavoritesView reloadData];
		[prefs setObject:queryFavorites forKey:@"queryFavorites"];
		[self setFavorites];
	} else if ( [queryFavoritesButton indexOfSelectedItem] == 2) {
//edit favorites
		[NSApp beginSheet:queryFavoritesSheet
				modalForWindow:tableWindow modalDelegate:self
				didEndSelector:nil contextInfo:nil];
		[NSApp runModalForWindow:queryFavoritesSheet];
	
		[NSApp endSheet:queryFavoritesSheet];
		[queryFavoritesSheet orderOut:nil];
	} else if ( [queryFavoritesButton indexOfSelectedItem] != 3) {
//choose favorite
		[textView replaceCharactersInRange:[textView selectedRange] withString:[queryFavoritesButton titleOfSelectedItem]];
	}
}

- (IBAction)chooseQueryHistory:(id)sender
/*
insert the choosen history query in the query textView
*/
{
	[textView setString:[queryHistoryButton titleOfSelectedItem]];
	[textView selectAll:self];
}

- (IBAction)closeSheet:(id)sender
/*
closes the sheet
*/
{
	[NSApp stopModal];
}


/*
 * Perform simple actions (which don't require their own method), triggered by selecting the appropriate menu item
 * in the "gear" action menu displayed beneath the cusotm query view.
 */
- (IBAction)gearMenuItemSelected:(id)sender
{
	// "Clear History" menu item - clear query history
	if (sender == clearHistoryMenuItem) {
		[queryHistoryButton removeAllItems];
		[queryHistoryButton addItemWithTitle:NSLocalizedString(@"Query History…",@"Title of query history popup button")];
		[prefs setObject:[NSArray array] forKey:@"queryHistory"];
	}

	// "Shift Right" menu item - indent the selection with an additional tab.
	if (sender == shiftRightMenuItem) {
		[textView shiftSelectionRight];
	}

	// "Shift Left" menu item - un-indent the selection by one tab if possible.
	if (sender == shiftLeftMenuItem) {
		[textView shiftSelectionLeft];
	}

	// "Completion List" menu item - used to autocomplete.  Uses a different shortcut to avoid the menu button flickering
	// on normal autocomplete usage.
	if (sender == completionListMenuItem) {
		[textView complete:self];
	}

	// "Indent new lines" toggle
	if (sender == autoindentMenuItem) {
		BOOL enableAutoindent = ([autoindentMenuItem state] == NSOffState);
		[prefs setBool:enableAutoindent forKey:@"CustomQueryAutoindent"];
		[prefs synchronize];
		[autoindentMenuItem setState:enableAutoindent?NSOnState:NSOffState];
		[textView setAutoindent:enableAutoindent];
	}

	// "Auto-pair characters" toggle
	if (sender == autopairMenuItem) {
		BOOL enableAutopair = ([autopairMenuItem state] == NSOffState);
		[prefs setBool:enableAutopair forKey:@"CustomQueryAutopair"];
		[prefs synchronize];
		[autopairMenuItem setState:enableAutopair?NSOnState:NSOffState];
		[textView setAutopair:enableAutopair];
	}
}


#pragma mark -
#pragma mark queryFavoritesSheet methods


- (IBAction)addQueryFavorite:(id)sender
/*
adds a query favorite
*/
{
	int row = [queryFavoritesView editedRow];
	int column = [queryFavoritesView editedColumn];
	NSTableColumn *tableColumn;
	NSCell *cell;

//end editing
	if ( row != -1 ) {
		tableColumn = [[queryFavoritesView tableColumns] objectAtIndex:column]; 
		cell = [tableColumn dataCellForRow:row]; 
		[cell endEditing:[queryFavoritesView currentEditor]]; 
	}

	[queryFavorites addObject:[NSString string]];
	[queryFavoritesView reloadData];
	[queryFavoritesView selectRow:[queryFavoritesView numberOfRows]-1 byExtendingSelection:NO];
	[queryFavoritesView editColumn:0 row:[queryFavoritesView numberOfRows]-1 withEvent:nil select:YES];
}

- (IBAction)removeQueryFavorite:(id)sender
/*
removes a query favorite
*/
{
	int row = [queryFavoritesView editedRow];
	int column = [queryFavoritesView editedColumn];
	NSTableColumn *tableColumn;
	NSCell *cell;

//end editing
	if ( row != -1 ) {
		tableColumn = [[queryFavoritesView tableColumns] objectAtIndex:column]; 
		cell = [tableColumn dataCellForRow:row]; 
		[cell endEditing:[queryFavoritesView currentEditor]]; 
	}

	if ( [queryFavoritesView numberOfSelectedRows] > 0 ) {
		[queryFavorites removeObjectAtIndex:[queryFavoritesView selectedRow]];
		[queryFavoritesView reloadData];
	}
}

- (IBAction)copyQueryFavorite:(id)sender
/*
copies a query favorite
*/
{
	int row = [queryFavoritesView editedRow];
	int column = [queryFavoritesView editedColumn];
	NSTableColumn *tableColumn;
	NSCell *cell;

//end editing
	if ( row != -1 ) {
		tableColumn = [[queryFavoritesView tableColumns] objectAtIndex:column]; 
		cell = [tableColumn dataCellForRow:row]; 
		[cell endEditing:[queryFavoritesView currentEditor]]; 
	}

	if ( [queryFavoritesView numberOfSelectedRows] > 0 ) {
		[queryFavorites insertObject:
					[NSString stringWithString:[queryFavorites objectAtIndex:[queryFavoritesView selectedRow]]]
					atIndex:[queryFavoritesView selectedRow]+1];
		[queryFavoritesView reloadData];
		[queryFavoritesView selectRow:[queryFavoritesView selectedRow]+1 byExtendingSelection:NO];
		[queryFavoritesView editColumn:0 row:[queryFavoritesView selectedRow] withEvent:nil select:YES];
	}
}

- (IBAction)closeQueryFavoritesSheet:(id)sender
/*
closes queryFavoritesSheet and saves favorites to preferences
*/
{
	int row = [queryFavoritesView editedRow];
	int column = [queryFavoritesView editedColumn];
	NSTableColumn *tableColumn;
	NSCell *cell;

//end editing
	if ( row != -1 ) {
		tableColumn = [[queryFavoritesView tableColumns] objectAtIndex:column]; 
		cell = [tableColumn dataCellForRow:row]; 
		[cell endEditing:[queryFavoritesView currentEditor]]; 
	}

	[NSApp stopModal];
	[prefs setObject:queryFavorites forKey:@"queryFavorites"];
	[self setFavorites];
}


#pragma mark -
#pragma mark Query actions


- (void)performQueries:(NSArray *)queries;
/*
performs the mysql-query given by the user
sets the tableView columns corresponding to the mysql-result
*/
{	
	
	NSArray		*theColumns;
	NSTableColumn	*theCol;
	CMMCPResult	*theResult = nil;
	NSMutableArray	*menuItems = [NSMutableArray array];
	NSMutableArray	*tempResult = [NSMutableArray array];
	NSMutableString	*errors = [NSMutableString string];
	int i, totalQueriesRun = 0, totalAffectedRows = 0;
	float executionTime = 0;

	// Notify listeners that a query has started
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];

	// Reset the current table view as necessary to avoid redraw and reload issues.
	// Restore the view position to the top left to be within the results for all datasets.
	[customQueryView scrollRowToVisible:0];
	[customQueryView scrollColumnToVisible:0];

	// Remove all the columns
	theColumns = [customQueryView tableColumns];
	while ([theColumns count]) {
		[customQueryView removeTableColumn:[theColumns objectAtIndex:0]];
	}

	// Perform the supplied queries in series
	for ( i = 0 ; i < [queries count] ; i++ ) {
	
		// Don't run blank queries, or queries which only contain whitespace.
		if ([[[queries objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0)
			continue;

		// Run the query, timing execution (note this also includes network and overhead)
		theResult = [mySQLConnection queryString:[queries objectAtIndex:i]];
		executionTime += [mySQLConnection lastQueryExecutionTime];
		totalQueriesRun++;

		// Record any affected rows
		if ( [mySQLConnection affectedRows] != -1 )
			totalAffectedRows += [mySQLConnection affectedRows];

		// Store any error messages
		if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {

			// If the query errored, append error to the error log for display at the end
			if ( [queries count] > 1 ) {
				[errors appendString:[NSString stringWithFormat:NSLocalizedString(@"[ERROR in query %d] %@\n", @"error text when multiple custom query failed"),
										i+1,
										[mySQLConnection getLastErrorMessage]]];
			} else {
				[errors setString:[mySQLConnection getLastErrorMessage]];
			}
		}
	}
	
	//perform empty query if no query is given
	if ( [queries count] == 0 ) {
		theResult = [mySQLConnection queryString:@""];
		[errors setString:[mySQLConnection getLastErrorMessage]];
	}
	
//put result in array
	[queryResult release];
	queryResult = nil;
	if ( nil != theResult )
	{
		int r = [theResult numOfRows];
		if (r) [theResult dataSeek:0];
		for ( i = 0 ; i < r ; i++ ) {
			[tempResult addObject:[theResult fetchRowAsArray]];
		}
		queryResult = [[NSArray arrayWithArray:tempResult] retain];
	}

//add query to history
	[queryHistoryButton insertItemWithTitle:[queries componentsJoinedByString:@"; "] atIndex:1];
	while ( [queryHistoryButton numberOfItems] > 21 ) {
		[queryHistoryButton removeItemAtIndex:[queryHistoryButton numberOfItems]-1];
	}
	for ( i = 1 ; i < [queryHistoryButton numberOfItems] ; i++ )
	{
		[menuItems addObject:[queryHistoryButton itemTitleAtIndex:i]];
	}
	[prefs setObject:menuItems forKey:@"queryHistory"];

	if ( [errors length] ) {
		[errorText setStringValue:errors];
	} else {
		[errorText setStringValue:NSLocalizedString(@"There were no errors.", @"text shown when query was successfull")];
	}
	
	// Set up the status string
	if ( totalQueriesRun > 1 ) {
        if (totalAffectedRows==1) {
            [affectedRowsText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"1 row affected in total, by %i queries taking %@", @"text showing one row has been affected by multiple queries"),
                                              totalQueriesRun,
                                              [NSString stringForTimeInterval:executionTime]
                                              ]];
            
        } else {
            [affectedRowsText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%i rows affected in total, by %i queries taking %@", @"text showing how many rows have been affected by multiple queries"),
                                              totalAffectedRows,
                                              totalQueriesRun,
                                              [NSString stringForTimeInterval:executionTime]
                                              ]];
            
        }
	} else {
        if (totalAffectedRows==1) {
            [affectedRowsText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"1 row affected, taking %@", @"text showing one row has been affected by a single query"),
                                              [NSString stringForTimeInterval:executionTime]
                                              ]];
        } else {
            [affectedRowsText setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%i rows affected, taking %@", @"text showing how many rows have been affected by a single query"),
                                              totalAffectedRows,
                                              [NSString stringForTimeInterval:executionTime]
                                              ]];
            
        }
	}


	// If no results were returned, redraw the empty table and post notifications before returning.
	if ( !theResult || ![theResult numOfRows] ) {
		[customQueryView reloadData];

		// Notify any listeners that the query has completed
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];

		// Perform the Growl notification for query completion
        [[SPGrowlController sharedGrowlController] notifyWithTitle:@"Query Finished"
                                                       description:[NSString stringWithFormat:NSLocalizedString(@"%@",@"description for query finished growl notification"), [errorText stringValue]] 
                                                  notificationName:@"Query Finished"];
		
		return;
	}


	// Otherwise add columns corresponding to the query result
	theColumns = [theResult fetchFieldNames];
	for ( i = 0 ; i < [theResult numOfFields] ; i++) {
		theCol = [[NSTableColumn alloc] initWithIdentifier:[NSNumber numberWithInt:i]];
		[theCol setResizingMask:NSTableColumnUserResizingMask];
		NSTextFieldCell *dataCell = [[[NSTextFieldCell alloc] initTextCell:@""] autorelease];
		[dataCell setEditable:NO];
		if ( [prefs boolForKey:@"useMonospacedFonts"] ) {
			[dataCell setFont:[NSFont fontWithName:@"Monaco" size:10]];
		} else {
			[dataCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}
		[dataCell setLineBreakMode:NSLineBreakByTruncatingTail];
		[theCol setDataCell:dataCell];
		[[theCol headerCell] setStringValue:[theColumns objectAtIndex:i]];

		[customQueryView addTableColumn:theCol];
		[theCol release];
	}
	
	[customQueryView sizeLastColumnToFit];
	//tries to fix problem with last row (otherwise to small)
	//sets last column to width of the first if smaller than 30
	//problem not fixed for resizing window
	if ( [[customQueryView tableColumnWithIdentifier:[NSNumber numberWithInt:[theColumns count]-1]] width] < 30 )
		[[customQueryView tableColumnWithIdentifier:[NSNumber numberWithInt:[theColumns count]-1]]
				setWidth:[[customQueryView tableColumnWithIdentifier:[NSNumber numberWithInt:0]] width]];
	[customQueryView reloadData];
	
	//query finished
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
	
	// Query finished Growl notification    
    [[SPGrowlController sharedGrowlController] notifyWithTitle:@"Query Finished"
                                                   description:[NSString stringWithFormat:NSLocalizedString(@"%@",@"description for query finished growl notification"), [errorText stringValue]] 
                                              notificationName:@"Query Finished"];
}

/*
 * Retrieve the query at a position specified within the custom query
 * text view.  This will return nil if the position specified is beyond
 * the available string or if an empty query would be returned.
 */
- (NSString *)queryAtPosition:(long)position
{
	SPSQLParser *customQueryParser;
	NSArray *queries;
	NSString *query = nil;
	int i, queryPosition = 0;

	// If the supplied position is negative or beyond the end of the string, return nil.
	if (position < 0 || position > [[textView string] length])
		return nil;

	// Split the current text into queries
	customQueryParser = [[SPSQLParser alloc] initWithString:[textView string]];
	queries = [[NSArray alloc] initWithArray:[customQueryParser splitStringByCharacter:';']];
	[customQueryParser release];

	// Walk along the array of queries to identify the current query - taking into account
	// the extra semicolon at the end of each query
	for (i = 0; i < [queries count]; i++ ) {
		queryPosition += [[queries objectAtIndex:i] length];
		if (queryPosition >= position) {
			query = [NSString stringWithString:[queries objectAtIndex:i]];
			break;
		}
		queryPosition++;
	}
	
	[queries release];

	// Ensure the string isn't empty.
	// (We could also strip comments for this check, but that prevents use of conditional comments)
	if ([[query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0)
		return nil;

	// Return the located string.
	return query;
}


#pragma mark -
#pragma mark Accessors


- (NSArray *)currentResult
/*
returns the current result (as shown in custom result view) as array, the first object containing the field names as array, the following objects containing the rows as array
*/
{
	NSArray *tableColumns = [customQueryView tableColumns];
	NSEnumerator *enumerator = [tableColumns objectEnumerator];
	id tableColumn;
	NSMutableArray *currentResult = [NSMutableArray array];
	NSMutableArray *tempRow = [NSMutableArray array];
	int i;
	
	//set field names as first line
	while ( (tableColumn = [enumerator nextObject]) ) {
		[tempRow addObject:[[tableColumn headerCell] stringValue]];
	}
	[currentResult addObject:[NSArray arrayWithArray:tempRow]];
	
	//add rows
	for ( i = 0 ; i < [self numberOfRowsInTableView:customQueryView] ; i++) {
		[tempRow removeAllObjects];
		enumerator = [tableColumns objectEnumerator];
		while ( (tableColumn = [enumerator nextObject]) ) {
			[tempRow addObject:[self tableView:customQueryView objectValueForTableColumn:tableColumn row:i]];
		}
		[currentResult addObject:[NSArray arrayWithArray:tempRow]];
	}
	return currentResult;
}


#pragma mark -
#pragma mark Additional methods


- (void)setConnection:(CMMCPConnection *)theConnection
/*
sets the connection (received from TableDocument) and makes things that have to be done only once 
*/
{
	NSArray *tableColumns = [queryFavoritesView tableColumns];
	NSEnumerator *enumerator = [tableColumns objectEnumerator];
	id column;

	mySQLConnection = theConnection;

	prefs = [[NSUserDefaults standardUserDefaults] retain];
	if ( [prefs objectForKey:@"queryFavorites"] ) {
		queryFavorites = [[NSMutableArray alloc] initWithArray:[prefs objectForKey:@"queryFavorites"]];
	} else {
		queryFavorites = [[NSMutableArray array] retain];
	}

	// Set up the interface
	[customQueryView setVerticalMotionCanBeginDrag:NO];
	if ( [prefs boolForKey:@"useMonospacedFonts"] ) {
		[textView setFont:[NSFont fontWithName:@"Monaco" size:[NSFont smallSystemFontSize]]];
	} else {
		[textView setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}
	[textView setContinuousSpellCheckingEnabled:NO];
	[autoindentMenuItem setState:([prefs boolForKey:@"CustomQueryAutoindent"]?NSOnState:NSOffState)];
	[textView setAutoindent:[prefs boolForKey:@"CustomQueryAutoindent"]];
	[textView setAutoindentIgnoresEnter:YES];
	[autopairMenuItem setState:([prefs boolForKey:@"CustomQueryAutopair"]?NSOnState:NSOffState)];
	[textView setAutopair:[prefs boolForKey:@"CustomQueryAutopair"]];
	[queryFavoritesView registerForDraggedTypes:[NSArray arrayWithObjects:@"SequelProPasteboard", nil]];
	while ( (column = [enumerator nextObject]) )
	{
		if ( [prefs boolForKey:@"useMonospacedFonts"] ) {
			[[column dataCell] setFont:[NSFont fontWithName:@"Monaco" size:10]];
		} else {
			[[column dataCell] setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}
	}
	if ( [prefs objectForKey:@"queryHistory"] )
	{
		[queryHistoryButton addItemsWithTitles:[prefs objectForKey:@"queryHistory"]];
	}
	[self setFavorites];
}

- (void)setFavorites
/*
set up the favorites popUpButton
*/
{
	int i;

//remove all menuItems and add favorites from preferences
	for ( i = 4 ; i < [queryFavoritesButton numberOfItems] ; i++ ) {
		[queryFavoritesButton removeItemAtIndex:i];
	}
	[queryFavoritesButton addItemsWithTitles:queryFavorites];
}

- (void)doPerformQueryService:(NSString *)query
/*
inserts the query in the textView and performs query
*/
{
	[textView setString:query];
	[self runAllQueries:self];
}


#pragma mark -
#pragma mark TableView datasource methods


- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if ( aTableView == customQueryView ) {
		if ( nil == queryResult ) {
			return 0;
		} else {
			return [queryResult count];
		}
	} else if ( aTableView == queryFavoritesView ) {
		return [queryFavorites count];
	} else {
		return 0;
	}
}

- (id)tableView:(NSTableView *)aTableView
			objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
	NSArray	*theRow;
	NSNumber *theIdentifier = [aTableColumn identifier];

	if ( aTableView == customQueryView ) {
		theRow = [queryResult objectAtIndex:rowIndex];
		
		if ( [[theRow objectAtIndex:[theIdentifier intValue]] isKindOfClass:[NSData class]] ) {
			NSString *tmp = [[NSString alloc] initWithData:[theRow objectAtIndex:[theIdentifier intValue]]
												  encoding:[mySQLConnection encoding]];
			if (tmp == nil) {
				tmp = [[NSString alloc] initWithData:[theRow objectAtIndex:[theIdentifier intValue]]
											encoding:NSASCIIStringEncoding];
			}
			return [tmp autorelease];
		}
		if ( [[theRow objectAtIndex:[theIdentifier intValue]] isMemberOfClass:[NSNull class]] )
			return [prefs objectForKey:@"nullValue"];
	
		return [theRow objectAtIndex:[theIdentifier intValue]];
	} else if ( aTableView == queryFavoritesView ) {
		return [queryFavorites objectAtIndex:rowIndex];
	} else {
		return @"";
	}
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject
			forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if ( aTableView == queryFavoritesView ) {
		NSEnumerator *enumerator = [queryFavorites objectEnumerator];
		id favorite;
		int i = 0;

		if ( [anObject isEqualToString:@""] ) {
			[queryFavoritesView deselectAll:self];
			[queryFavorites removeObjectAtIndex:rowIndex];
			[queryFavoritesView reloadData];
			return;
		}

		while ( (favorite = [enumerator nextObject]) ) {
			if ( [favorite isEqualToString:anObject] && i != rowIndex) {
				NSRunAlertPanel(@"Error", @"Query already exists in favorites.", @"OK", nil, nil);
				//remove row if it was a (blank) new row or a copied row
				if ( [[queryFavorites objectAtIndex:rowIndex] isEqualToString:@""] ||
						[[queryFavorites objectAtIndex:rowIndex] isEqualToString:anObject] ) {
					[queryFavoritesView deselectAll:self];
					[queryFavorites removeObjectAtIndex:rowIndex];
					[queryFavoritesView reloadData];
				}
				return;
			}
			i++;
		}
		[queryFavorites replaceObjectAtIndex:rowIndex withObject:anObject];
		[queryFavoritesView reloadData];
	}
}


//tableView drag&drop datasource methods
- (BOOL)tableView:(NSTableView *)aTableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard
{
	int originalRow;
	NSArray *pboardTypes;

	if ( aTableView == queryFavoritesView ) 
	{
		if ( [rows count] == 1 ) 
		{
			pboardTypes = [NSArray arrayWithObjects:@"SequelProPasteboard", nil];
			originalRow = [[rows objectAtIndex:0] intValue];
	
			[pboard declareTypes:pboardTypes owner:nil];
			[pboard setString:[[NSNumber numberWithInt:originalRow] stringValue] forType:@"SequelProPasteboard"];
			
			return YES;
		} 
		else 
		{
			return NO;
		}
	} else if ( aTableView == customQueryView ) {
		NSString *tmp = [customQueryView draggedRowsAsTabString:rows];
		if ( nil != tmp )
		{
			[pboard declareTypes:[NSArray arrayWithObjects: NSTabularTextPboardType, 
				NSStringPboardType, nil]
						   owner:nil];
			[pboard setString:tmp forType:NSStringPboardType];
			[pboard setString:tmp forType:NSTabularTextPboardType];
			return YES;
		}
		return NO;
	} else {
		return NO;
	}
}

- (NSDragOperation)tableView:(NSTableView*)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row
	proposedDropOperation:(NSTableViewDropOperation)operation
{
	NSArray *pboardTypes = [[info draggingPasteboard] types];
	int originalRow;

	if ( aTableView == queryFavoritesView ) {
		if ([pboardTypes count] == 1 && row != -1)
		{
			if ([[pboardTypes objectAtIndex:0] isEqualToString:@"SequelProPasteboard"]==YES && operation==NSTableViewDropAbove)
			{
				originalRow = [[[info draggingPasteboard] stringForType:@"SequelProPasteboard"] intValue];
	
				if (row != originalRow && row != (originalRow+1))
				{
					return NSDragOperationMove;
				}
			}
		}
		return NSDragOperationNone;
	} else {
		return NSDragOperationNone;
	}
}

- (BOOL)tableView:(NSTableView*)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	int originalRow;
	int destinationRow;
	NSMutableDictionary *draggedRow;

	if ( aTableView == queryFavoritesView ) {
		originalRow = [[[info draggingPasteboard] stringForType:@"SequelProPasteboard"] intValue];
		destinationRow = row;
	
		if ( destinationRow > originalRow )
			destinationRow--;
	
		draggedRow = [queryFavorites objectAtIndex:originalRow];
		[queryFavorites removeObjectAtIndex:originalRow];
		[queryFavorites insertObject:draggedRow atIndex:destinationRow];
		
		[queryFavoritesView reloadData];
		[queryFavoritesView selectRow:destinationRow byExtendingSelection:NO];
	
		return YES;
	} else {
		return NO;
	}
}


//tableView delegate methods
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
/*
opens sheet with value when double clicking on a field
*/
{
	if ( aTableView == customQueryView ) {
		NSArray *theRow;
		NSString *theValue;
		NSNumber *theIdentifier = [aTableColumn identifier];
	
	//get the value
		theRow = [queryResult objectAtIndex:rowIndex];
	
		if ( [[theRow objectAtIndex:[theIdentifier intValue]] isKindOfClass:[NSData class]] ) {
			theValue = [[NSString alloc] initWithData:[theRow objectAtIndex:[theIdentifier intValue]]
								encoding:[mySQLConnection encoding]];
			if (theValue == nil) {
				theValue = [[NSString alloc] initWithData:[theRow objectAtIndex:[theIdentifier intValue]]
												 encoding:NSASCIIStringEncoding];
			}
			[theValue autorelease];
		} else if ( [[theRow objectAtIndex:[theIdentifier intValue]] isMemberOfClass:[NSNull class]] ) {
			theValue = [prefs objectForKey:@"nullValue"];
		} else {
			theValue = [theRow objectAtIndex:[theIdentifier intValue]];
		}
	
		[valueTextField setString:[theValue description]];
		[valueTextField selectAll:self];
		[NSApp beginSheet:valueSheet
				modalForWindow:tableWindow modalDelegate:self
				didEndSelector:nil contextInfo:nil];
		[NSApp runModalForWindow:valueSheet];
	
		[NSApp endSheet:valueSheet];
		[valueSheet orderOut:nil];
	
		return NO;
	} else {
		return YES;
	}
}


#pragma mark -
#pragma mark SplitView delegate methods


- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
/*
tells the splitView that it can collapse views
*/
{
	return YES;
}

- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
/*
defines max position of splitView
*/
{
	if ( offset == 0 ) {
		return proposedMax - 100;
	} else {
		return proposedMax - 73;
	}
}

- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
/*
defines min position of splitView
*/
{
	if ( offset == 0 ) {
		return proposedMin + 100;
	} else {
		return proposedMin + 100;
	}
}


#pragma mark -
#pragma mark TextView delegate methods


- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector
/*
traps enter key and
	performs query instead of inserting a line break if aTextView == textView
	closes valueSheet if aTextView == valueTextField
*/
{
	if ( aTextView == textView ) {
		if ( [aTextView methodForSelector:aSelector] == [aTextView methodForSelector:@selector(insertNewline:)] &&
				[[[NSApp currentEvent] characters] isEqualToString:@"\003"] )
		{
			[self runAllQueries:self];
			return YES;
		} else {
			return NO;
		}
	} else if ( aTextView == valueTextField ) {
		if ( [aTextView methodForSelector:aSelector] == [aTextView methodForSelector:@selector(insertNewline:)] )
		{
			[self closeSheet:self];
			return YES;
		} else {
			return NO;
		}
	}
	return NO;
}

/*
 * A notification posted when the selection changes within the text view;
 * used to control the run-currentrun-selection button state and action.
 */
- (void)textViewDidChangeSelection:(NSNotification *)aNotification
{

	// Ensure that the notification is from the custom query text view
	if ( [aNotification object] != textView ) return;

	// If no text is selected, disable the button and action menu.
	if ( [textView selectedRange].location == NSNotFound ) {
		[runSelectionButton setEnabled:NO];
		[runSelectionMenuItem setEnabled:NO];
		return;
	}

	// If the current selection is a single caret position, update the button based on
	// whether the caret is inside a valid query.
	if ([textView selectedRange].length == 0) {
		int selectionPosition = [textView selectedRange].location;
		int movedRangeStart, movedRangeLength;
		NSRange oldSelection;

		// Retrieve the old selection position
        [[[aNotification userInfo] objectForKey:@"NSOldSelectedCharacterRange"] getValue:&oldSelection];

		// Only process the query text if the selection previously had length, or moved more than 100 characters,
		// or the intervening space contained a semicolon, or typing has been performed with no current query.
		// This adds more checks to every keypress, but ensures the majority of the actions don't incur a
		// parsing overhead - which is cheap on small text strings but heavy of large queries.
		movedRangeStart = (selectionPosition < oldSelection.location)?selectionPosition:oldSelection.location;
		movedRangeLength = abs(selectionPosition - oldSelection.location);
		if (oldSelection.length > 0
			|| movedRangeLength > 100
			|| oldSelection.location > [[textView string] length]
			|| [[textView string] rangeOfString:@";" options:0 range:NSMakeRange(movedRangeStart, movedRangeLength)].location != NSNotFound
			|| (![runSelectionButton isEnabled] && selectionPosition > oldSelection.location
				&& [[[[textView string] substringWithRange:NSMakeRange(movedRangeStart, movedRangeLength)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length])
			) {

			[runSelectionButton setTitle:NSLocalizedString(@"Run Current", @"Title of button to run current query in custom query view")];
			[runSelectionMenuItem setTitle:NSLocalizedString(@"Run Current Query", @"Title of action menu item to run current query in custom query view")];

			// If a valid query is present at the cursor position, enable the button
			if ([self queryAtPosition:selectionPosition]) {
				[runSelectionButton setEnabled:YES];
				[runSelectionMenuItem setEnabled:YES];
			} else {
				[runSelectionButton setEnabled:NO];
				[runSelectionMenuItem setEnabled:NO];
			}
		}

	// For selection ranges, enable the button.
	} else {
		[runSelectionButton setTitle:NSLocalizedString(@"Run Selection", @"Title of button to run selected text in custom query view")];
		[runSelectionButton setEnabled:YES];		
		[runSelectionMenuItem setTitle:NSLocalizedString(@"Run Selected Text", @"Title of action menu item to run selected text in custom query view")];
		[runSelectionMenuItem setEnabled:YES];		
	}
}


#pragma mark -
#pragma mark TableView notifications


/*
 * Updates various interface elements based on the current table view selection.
 */
- (void)tableViewSelectionDidChange:(NSNotification *)notification
{	
	if ([notification object] == queryFavoritesView) {
		
		// Enable/disable buttons
		[removeQueryFavoriteButton setEnabled:([queryFavoritesView numberOfSelectedRows] == 1)];
		[copyQueryFavoriteButton setEnabled:([queryFavoritesView numberOfSelectedRows] == 1)];
	}
}


#pragma mark -


// Last but not least
- (id)init;
{
	self = [super init];
	return self;
}

- (void)dealloc
{
	[queryResult release];
	[prefs release];
	[queryFavorites release];
	
	[super dealloc];
}
	
@end
