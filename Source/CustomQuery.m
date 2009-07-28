//
//  $Id$
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

#import "CustomQuery.h"
#import "SPSQLParser.h"
#import "SPGrowlController.h"
#import "SPStringAdditions.h"
#import "SPTextViewAdditions.h"
#import "SPArrayAdditions.h"
#import "SPDataAdditions.h"
#import "SPDataCellFormatter.h"
#import "TableDocument.h"
#import "TablesList.h"
#import "RegexKitLite.h"
#import "SPFieldEditorController.h"
#import "SPTextAndLinkCell.h"

#define SP_MYSQL_DEV_SEARCH_URL   @"http://search.mysql.com/search?q=%@&site=refman-%@"
#define SP_HELP_SEARCH_IN_MYSQL   0
#define SP_HELP_SEARCH_IN_PAGE    1
#define SP_HELP_SEARCH_IN_WEB     2
#define SP_HELP_GOBACK_BUTTON     0
#define SP_HELP_SHOW_TOC_BUTTON   1
#define SP_HELP_GOFORWARD_BUTTON  2
#define SP_HELP_NOT_AVAILABLE     @"__no_help_available"

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
	queries = [queryParser splitSqlStringByCharacter:';'];
	[queryParser release];

	NSRange curRange = [textView selectedRange];
	// Unselect a selection if given to avoid interferring with error highlighting
	[textView setSelectedRange:NSMakeRange(curRange.location, 0)];
	// Reset queryStartPosition
	queryStartPosition = 0;

	tableReloadAfterEditing = NO;

	[self performQueries:queries];
	// If no error was selected reconstruct a given selection
	if([textView selectedRange].length == 0)
		[textView setSelectedRange:curRange];

	// Invoke textStorageDidProcessEditing: for syntax highlighting and auto-uppercase
	NSRange oldRange = [textView selectedRange];
	[textView setSelectedRange:NSMakeRange(oldRange.location,0)];
	[textView insertText:@""];
	[textView setSelectedRange:oldRange];
	

	// Select the text of the query textView for re-editing
	//[textView selectAll:self];
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
		// BOOL doLookBehind = YES;
		// query = [self queryAtPosition:selectedRange.location lookBehind:&doLookBehind];
		if(currentQueryRange.length)
			query = [[textView string] substringWithRange:currentQueryRange];
		if (!query) {
			NSBeep();
			return;
		}
		queries = [NSArray arrayWithObject:query];

	// Otherwise, run the selected text.
	} else {
		queryParser = [[SPSQLParser alloc] initWithString:[[textView string] substringWithRange:selectedRange]];
		queries = [queryParser splitSqlStringByCharacter:';'];
		[queryParser release];
	}
	
	// Invoke textStorageDidProcessEditing: for syntax highlighting and auto-uppercase
	// and preserve the selection
	[textView setSelectedRange:NSMakeRange(selectedRange.location,0)];
	[textView insertText:@""];
	[textView setSelectedRange:selectedRange];

	tableReloadAfterEditing = NO;

	[self performQueries:queries];
}

/*
 * Insert the choosen favorite query in the query textView or save query to favorites or opens window to edit favorites
 */
- (IBAction)chooseQueryFavorite:(id)sender
{
	if ( [queryFavoritesButton indexOfSelectedItem] == 1) {
//save query to favorites
		//check if favorite doesn't exist
		NSEnumerator *enumerator = [queryFavorites objectEnumerator];
		id favorite;
		while ( (favorite = [enumerator nextObject]) ) {
			if ( [favorite isEqualToString:[textView string]] ) {
				NSBeginAlertSheet(NSLocalizedString(@"Query already exists", @"query already exists message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
								  NSLocalizedString(@"The query you are adding to your favorites already exists.", @"query already exists informative message"));
				return;
			}
		}
		if ( [[textView string] isEqualToString:@""] ) {
				NSBeginAlertSheet(NSLocalizedString(@"Empty query", @"empty query message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
								  NSLocalizedString(@"Cannot save an empty query.", @"empty query informative message"));
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
		[textView insertText:[queryFavoritesButton titleOfSelectedItem]];
	}
}

/*
 * Insert the choosen history query in the query textView
 */
- (IBAction)chooseQueryHistory:(id)sender
{
	[textView insertText:[queryHistoryButton titleOfSelectedItem]];
}

/*
 * Closes the sheet
 */
- (IBAction)closeSheet:(id)sender
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

	// "Comment Line/Selection" menu item - Add or remove "-- " for each line 
	// in a line or selection resp. or wrap the selection into /* */ 
	// if the selection does not end at the end of a line (in-line comment)
	if (sender == commentLineOrSelectionMenuItem) {
		[self commentOut];
	}

	// "Comment Current Query" menu item - Add or remove "-- " for each line 
	// in the current query
	if (sender == commentCurrentQueryMenuItem) {
		[self commentOutCurrentQueryTakingSelection:NO];
	}

	// "Completion List" menu item - used to autocomplete.  Uses a different shortcut to avoid the menu button flickering
	// on normal autocomplete usage.
	if (sender == completionListMenuItem) {
		[textView complete:self];
	}

	// "Editor font..." menu item to bring up the font panel
	if (sender == editorFontMenuItem) {
		[[NSFontPanel sharedFontPanel] setPanelFont:[textView font] isMultiple:NO];
		[[NSFontPanel sharedFontPanel] setDelegate:self];
		[[NSFontPanel sharedFontPanel] makeKeyAndOrderFront:self];
	}

	// "Indent new lines" toggle
	if (sender == autoindentMenuItem) {
		BOOL enableAutoindent = !([autoindentMenuItem state] == NSOffState);
		[prefs setBool:enableAutoindent forKey:@"CustomQueryAutoIndent"];
		[prefs synchronize];
		[autoindentMenuItem setState:enableAutoindent?NSOnState:NSOffState];
		[textView setAutoindent:enableAutoindent];
	}

	// "Auto-pair characters" toggle
	if (sender == autopairMenuItem) {
		BOOL enableAutopair = !([autopairMenuItem state] == NSOffState);
		[prefs setBool:enableAutopair forKey:@"CustomQueryAutoPairCharacters"];
		[prefs synchronize];
		[autopairMenuItem setState:enableAutopair?NSOnState:NSOffState];
		[textView setAutopair:enableAutopair];
	}

	// "Auto-help" toggle
	if (sender == autohelpMenuItem) {
		BOOL enableAutohelp = !([autohelpMenuItem state] == NSOffState);
		[prefs setBool:enableAutohelp forKey:@"CustomQueryUpdateAutoHelp"];
		[prefs synchronize];
		[autohelpMenuItem setState:enableAutohelp?NSOnState:NSOffState];
		[textView setAutohelp:enableAutohelp];
	}

	// "Auto-uppercase keywords" toggle
	if (sender == autouppercaseKeywordsMenuItem) {
		BOOL enableAutouppercaseKeywords = !([autouppercaseKeywordsMenuItem state] == NSOffState);
		[prefs setBool:enableAutouppercaseKeywords forKey:@"CustomQueryAutoUppercaseKeywords"];
		[prefs synchronize];
		[autouppercaseKeywordsMenuItem setState:enableAutouppercaseKeywords?NSOnState:NSOffState];
		[textView setAutouppercaseKeywords:enableAutouppercaseKeywords];
	}
}

/*
 * Set font panel's valid modes
 */
- (unsigned int)validModesForFontPanel:(NSFontPanel *)fontPanel
{
	return (NSFontPanelAllModesMask ^ NSFontPanelAllEffectsModeMask);
}


#pragma mark -
#pragma mark queryFavoritesSheet methods

/*
 * Adds a query favorite
 */
- (IBAction)addQueryFavorite:(id)sender
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

/*
 * removes a query favorite
 */
- (IBAction)removeQueryFavorite:(id)sender
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

/*
 * Copies a query favorite
 */
- (IBAction)copyQueryFavorite:(id)sender
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

/*
 * Closes queryFavoritesSheet and saves favorites to preferences
 */
- (IBAction)closeQueryFavoritesSheet:(id)sender
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

/*
 * Performs the mysql-query given by the user
 * sets the tableView columns corresponding to the mysql-result
 */
- (void)performQueries:(NSArray *)queries;
{	
	
	NSArray         *theColumns;
	NSTableColumn   *theCol;
	MCPResult     *theResult  = nil;
	NSMutableArray  *menuItems  = [NSMutableArray array];
	NSMutableString *errors     = [NSMutableString string];
	
	int i, totalQueriesRun = 0, totalAffectedRows = 0;
	double executionTime = 0;
	int firstErrorOccuredInQuery = -1;
	BOOL suppressErrorSheet = NO;
	BOOL tableListNeedsReload = NO;
	BOOL databaseWasChanged = NO;
	// BOOL queriesSeparatedByDelimiter = NO;
	
	NSCharacterSet *whitespaceAndNewlineSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];

	// Notify listeners that a query has started
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];

	// Reset the current table view as necessary to avoid redraw and reload issues.
	// Restore the view position to the top left to be within the results for all datasets.
	[customQueryView scrollRowToVisible:0];
	[customQueryView scrollColumnToVisible:0];

	// Remove all the columns
	if(!tableReloadAfterEditing) {
		theColumns = [customQueryView tableColumns];
		while ([theColumns count]) {
			[customQueryView removeTableColumn:NSArrayObjectAtIndex(theColumns, 0)];
		}
	}

	// Disable automatic query retries on failure for the custom queries
	[mySQLConnection setAllowQueryRetries:NO];

	long queryCount = [queries count];
	NSMutableArray *tempQueries = [NSMutableArray arrayWithCapacity:queryCount];

	// Perform the supplied queries in series
	for ( i = 0 ; i < queryCount ; i++ ) {

		NSString *query = [NSArrayObjectAtIndex(queries, i) stringByTrimmingCharactersInSet:whitespaceAndNewlineSet];

		// Don't run blank queries, or queries which only contain whitespace.
		if (![query length])
			continue;

		// store trimmed queries for usedQueries and history
		[tempQueries addObject:query];

		// Run the query, timing execution (note this also includes network and overhead)
		theResult = [mySQLConnection queryString:query];
		executionTime += [mySQLConnection lastQueryExecutionTime];
		totalQueriesRun++;

		// Record any affected rows
		if ( [mySQLConnection affectedRows] != -1 )
			totalAffectedRows += [mySQLConnection affectedRows];

		// Store any error messages
		if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {

			// If the query errored, append error to the error log for display at the end
			if ( queryCount > 1 ) {
				if(firstErrorOccuredInQuery == -1)
					firstErrorOccuredInQuery = i+1;

				if(!suppressErrorSheet)
				{
					// Update error text for the user
					[errors appendString:[NSString stringWithFormat:NSLocalizedString(@"[ERROR in query %d] %@\n", @"error text when multiple custom query failed"),
										i+1,
										[mySQLConnection getLastErrorMessage]]];
					[errorText setStringValue:errors];
					// ask the user to continue after detecting an error
					NSAlert *alert = [[[NSAlert alloc] init] autorelease];
					[alert addButtonWithTitle:NSLocalizedString(@"Run All", @"run all button")];
					[alert addButtonWithTitle:NSLocalizedString(@"Continue", @"continue button")];
					[alert addButtonWithTitle:NSLocalizedString(@"Stop", @"stop button")];
					[alert setMessageText:NSLocalizedString(@"MySQL Error", @"mysql error message")];
					[alert setInformativeText:[mySQLConnection getLastErrorMessage]];
					[alert setAlertStyle:NSWarningAlertStyle];
					int choice = [alert runModal];
					switch (choice){
						case NSAlertFirstButtonReturn:
							suppressErrorSheet = YES;
						case NSAlertSecondButtonReturn:
							break;
						default:
							if(i < queryCount-1) // output that message only if it was not the last one
								[errors appendString:NSLocalizedString(@"Execution stopped!\n", @"execution stopped message")];
							i = queryCount; // break for loop; for safety reasons stop the execution of the following queries
					}

				} else {
					[errors appendString:[NSString stringWithFormat:NSLocalizedString(@"[ERROR in query %d] %@\n", @"error text when multiple custom query failed"),
											i+1,
											[mySQLConnection getLastErrorMessage]]];
				}
			} else {
				[errors setString:[mySQLConnection getLastErrorMessage]];
			}
		} else {
			// Check if table/db list needs an update
			// The regex is a compromise between speed and usefullness. TODO: further improvements are needed
			if(!tableListNeedsReload && [query isMatchedByRegex:@"(?i)\\b(create|alter|drop|rename)\\b\\s+."])
				tableListNeedsReload = YES;
			if(!databaseWasChanged && [query isMatchedByRegex:@"(?i)\\b(use|drop\\s+database|drop\\s+schema)\\b\\s+."])
				databaseWasChanged = YES;
		}
	}

	// Reload table list if at least one query began with drop, alter, rename, or create
	if(tableListNeedsReload || databaseWasChanged) {
		// Build database pulldown menu
		[[tableWindow delegate] setDatabases:self];

		if (databaseWasChanged)
			// Reset the current database
			[[tableWindow delegate] refreshCurrentDatabase];

		// Reload table list
		[[[tableWindow delegate] valueForKeyPath:@"tablesListInstance"] updateTables:self];
	}
	
	if(usedQuery)
		[usedQuery release];
	
	// if(!queriesSeparatedByDelimiter) // TODO: How to combine queries delimited by DELIMITER?
	usedQuery = [[NSString stringWithString:[tempQueries componentsJoinedByString:@";\n"]] retain];
	
	lastExecutedQuery = [[tempQueries lastObject] retain];
	
	//perform empty query if no query is given
	if ( !queryCount ) {
		theResult = [mySQLConnection queryString:@""];
		[errors setString:[mySQLConnection getLastErrorMessage]];
	}
	
	//add query to history
	// if(!queriesSeparatedByDelimiter) { // TODO only add to history if no “delimiter” command was used
	if(!tableReloadAfterEditing) {
		[queryHistoryButton insertItemWithTitle:usedQuery atIndex:1];

		int maxHistoryItems = [[prefs objectForKey:@"CustomQueryMaxHistoryItems"] intValue];

		while ( [queryHistoryButton numberOfItems] > maxHistoryItems + 1 )
			[queryHistoryButton removeItemAtIndex:[queryHistoryButton numberOfItems]-1];

		for ( i = 1 ; i < [queryHistoryButton numberOfItems] ; i++ )
			[menuItems addObject:[queryHistoryButton itemTitleAtIndex:i]];

		[prefs setObject:menuItems forKey:@"queryHistory"];
	}

	// Error checking
	if ( [errors length] && !queryIsTableSorter ) {
		// set the error text
		[errorText setStringValue:errors];
		// select the line x of the first error if error message contains "at line x"
		NSRange errorLineNumberRange = [errors rangeOfRegex:@"([0-9]+)$" options:RKLNoOptions inRange:NSMakeRange(0, [errors length]) capture:1 error:nil];
		if(errorLineNumberRange.length) // if a line number was found
		{
			// Get the line number
			unsigned int errorAtLine = [[errors substringWithRange:errorLineNumberRange] intValue];
			[textView selectLineNumber:errorAtLine ignoreLeadingNewLines:YES];

			// Check for near message
			NSRange errorNearMessageRange = [errors rangeOfRegex:@" '(.*?)' " options:(RKLMultiline|RKLDotAll) inRange:NSMakeRange(0, [errors length]) capture:1 error:nil];
			if(errorNearMessageRange.length) // if a "near message" was found
			{
				// Build the range to search for nearMessage (beginning from queryStartPosition to try to avoid mismatching)
				NSRange theRange = NSMakeRange(queryStartPosition, [[textView string] length]-queryStartPosition);
				// Get the range in textView of the near message
				NSRange textNearMessageRange = [[[textView string] substringWithRange:theRange] rangeOfString:[errors substringWithRange:errorNearMessageRange] options:NSLiteralSearch];
				// Correct the near message range relative to queryStartPosition
				textNearMessageRange = NSMakeRange(textNearMessageRange.location+queryStartPosition, textNearMessageRange.length);
				// Select the near message and scroll to it
				[textView setSelectedRange:textNearMessageRange];
				[textView scrollRangeToVisible:textNearMessageRange];
			}
		} else { // Select first erroneous query entirely
			
			NSRange queryRange;
			if(firstErrorOccuredInQuery == -1) // for current or previous query
			{
				BOOL isLookBehind = YES;
				queryRange = [self queryRangeAtPosition:[textView selectedRange].location lookBehind:&isLookBehind];
				[textView setSelectedRange:queryRange];
			} else {
				// select the query for which the first error was detected
				queryRange = [self queryTextRangeForQuery:firstErrorOccuredInQuery startPosition:queryStartPosition];
				[textView setSelectedRange:queryRange];
			}

		}
		
	} else if ( [errors length] && queryIsTableSorter ) {
		[errorText setStringValue:NSLocalizedString(@"Couldn't sort column.", @"text shown if an error occured while sorting the result table")];
		NSBeep();
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

	// Restore automatic query retries
	[mySQLConnection setAllowQueryRetries:YES];

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

	// get column definitions for the result array
	cqColumnDefinition = [[theResult fetchResultFieldsStructure] retain];

	// set datasource
	[fullResult removeAllObjects];
	[fullResult setArray:[self fetchResultAsArray:theResult]];

	// Find result table name for copying as SQL INSERT.
	// If more than one table name is found set resultTableName to nil.
	// resultTableName will be set to the original table name (not defined via AS) provided by mysql return
	// and the resultTableName can differ due to case-sensitive/insensitive settings!.
	BOOL resultShowsColumnsFromOneTable = YES;
	NSString *resultTableName = [[cqColumnDefinition objectAtIndex:0] objectForKey:@"org_table"];
	for(id field in cqColumnDefinition) {
		if(![[field objectForKey:@"org_table"] isEqualToString:resultTableName]) {
			resultShowsColumnsFromOneTable = NO;
			resultTableName = nil;
			break;
		}
	}

	// Add columns corresponding to the query result
	theColumns = [theResult fetchFieldNames];

	if(!tableReloadAfterEditing) {
		for ( i = 0 ; i < [theResult numOfFields] ; i++) {
			NSDictionary *columnDefinition = NSArrayObjectAtIndex(cqColumnDefinition,i);
			theCol = [[NSTableColumn alloc] initWithIdentifier:[columnDefinition objectForKey:@"datacolumnindex"]];
			[theCol setResizingMask:NSTableColumnUserResizingMask];
			[theCol setEditable:YES];
			SPTextAndLinkCell *dataCell = [[[SPTextAndLinkCell alloc] initTextCell:@""] autorelease];
			[dataCell setEditable:YES];
			[dataCell setFormatter:[[SPDataCellFormatter new] autorelease]];
			if ( [prefs boolForKey:@"UseMonospacedFonts"] ) {
				[dataCell setFont:[NSFont fontWithName:@"Monaco" size:10]];
			} else {
				[dataCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
			}
			[dataCell setLineBreakMode:NSLineBreakByTruncatingTail];
			[theCol setDataCell:dataCell];
			[[theCol headerCell] setStringValue:NSArrayObjectAtIndex(theColumns, i)];

			// Set the width of this column to saved value if exists and maps to a real column
			if ([columnDefinition objectForKey:@"org_name"] && [[columnDefinition objectForKey:@"org_name"] length]) {
				NSNumber *colWidth = [[[[prefs objectForKey:@"tableColumnWidths"] objectForKey:[NSString stringWithFormat:@"%@@%@", [columnDefinition objectForKey:@"db"], [tableDocumentInstance host]]] objectForKey:[columnDefinition objectForKey:@"org_table"]] objectForKey:[columnDefinition objectForKey:@"org_name"]];
				if ( colWidth ) {
					[theCol setWidth:[colWidth floatValue]];
				}
			}

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
	
	}
	[customQueryView reloadData];
	
	// Init copyTable with necessary information for copying selected rows as SQL INSERT
	[customQueryView setTableInstance:self withTableData:fullResult withColumns:cqColumnDefinition withTableName:resultTableName withConnection:mySQLConnection];
	
	//query finished
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
	
	// Query finished Growl notification    
    [[SPGrowlController sharedGrowlController] notifyWithTitle:@"Query Finished"
                                                   description:[NSString stringWithFormat:NSLocalizedString(@"%@",@"description for query finished growl notification"), [errorText stringValue]] 
                                              notificationName:@"Query Finished"];
}

/*
 * Fetches the result as an array, with an array for each row in it
 */
- (NSArray *)fetchResultAsArray:(MCPResult *)theResult
{
	// NSArray *columns;
	unsigned long numOfRows = [theResult numOfRows];
	NSMutableArray *tempResult = [NSMutableArray arrayWithCapacity:numOfRows];

	NSArray *tempRow;
	NSMutableArray *modifiedRow = [NSMutableArray array];
	int i, j, numOfFields;
	Class nullClass = [NSNull class];
	id prefsNullValue = [prefs objectForKey:@"NullValue"];
	// BOOL prefsLoadBlobsAsNeeded = [prefs boolForKey:@"LoadBlobsAsNeeded"];

	// columns = [customQueryView columns];
	// long columnsCount = [cqColumnDefinition count];

	if (numOfRows) [theResult dataSeek:0];
	for ( i = 0 ; i < numOfRows ; i++ ) {
		tempRow = [theResult fetchRowAsArray];

		if ( i == 0 ) numOfFields = [tempRow count];

		for ( j = 0; j < numOfFields; j++) {
			if ( [NSArrayObjectAtIndex(tempRow, j) isMemberOfClass:nullClass] ) {
				[modifiedRow addObject:prefsNullValue];
			} else {
				[modifiedRow addObject:NSArrayObjectAtIndex(tempRow, j)];
			}
		}

		// Add values for hidden blob and text fields if appropriate
		// if ( prefsLoadBlobsAsNeeded ) {
		// 	for ( j = 0 ; j < columnsCount ; j++ ) {
		// 		if ( [[NSArrayObjectAtIndex(cqColumnDefinition, j) objectForKey:@"typegrouping"] isEqualToString:@"blobdata"] ||
		// 		 	[[NSArrayObjectAtIndex(cqColumnDefinition, j) objectForKey:@"typegrouping"] isEqualToString:@"textdata"]) {
		// 			[modifiedRow setObject:NSLocalizedString(@"(not loaded)", @"value shown for hidden blob and text fields") forKey:[NSArrayObjectAtIndex(cqColumnDefinition, j) objectForKey:@"name"]];
		// 		}
		// 	}
		// }

		[tempResult addObject:[NSArray arrayWithArray:modifiedRow]];
		[modifiedRow removeAllObjects];
	}

	return tempResult;
}


/*
 * Retrieve the range of the query at a position specified 
 * within the custom query text view.
 */
- (NSRange)queryRangeAtPosition:(long)position lookBehind:(BOOL *)doLookBehind
{
	SPSQLParser *customQueryParser;
	NSArray     *queries;
	NSString    *query = nil;
	NSRange     queryRange;
	
	long i, j, queryPosition = 0;
	long queryCount;

	NSCharacterSet *whitespaceAndNewlineSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSCharacterSet *whitespaceSet           = [NSCharacterSet whitespaceCharacterSet];

	// If the supplied position is negative or beyond the end of the string, return nil.
	if (position < 0 || position > [[textView string] length])
		return NSMakeRange(NSNotFound, 0);

	// Split the current text into ranges of queries
	// only if the textView was really changed, otherwise use the cache
	if([[textView textStorage] editedMask] != 0) {
		customQueryParser = [[SPSQLParser alloc] initWithString:[textView string]];
		queries = [[NSArray alloc] initWithArray:[customQueryParser splitSqlStringIntoRangesByCharacter:';']];
		if(currentQueryRanges)
			[currentQueryRanges release];
		currentQueryRanges = [[NSArray arrayWithArray:queries] retain];
		[customQueryParser release];
	} else {
		queries = [[NSArray alloc] initWithArray:currentQueryRanges];
	}

	queryCount = [queries count];

	// Walk along the array of queries to identify the current query - taking into account
	// the extra semicolon at the end of each query
	for (i = 0; i < queryCount; i++ ) {

		queryRange = [NSArrayObjectAtIndex(queries, i) rangeValue];
		queryPosition = NSMaxRange(queryRange);
		queryStartPosition = queryRange.location;

		if (queryPosition >= position) {
		
			// If lookbehind is enabled, check whether the current position could be considered to
			// be within the previous query.  A position just after a semicolon is always considered
			// to be within the previous query; otherwise, if there is only whitespace *and newlines*
			// before the next character, also consider the position to belong to the previous query.
			if (*doLookBehind) {
				BOOL positionAssociatedWithPreviousQuery = NO;

				// If the caret is at the very start of the string, always associate
				if (position == queryStartPosition) positionAssociatedWithPreviousQuery = YES;
				
				// If the caret is in between a user-defined delimiter whose length is >1, always associate
				if (!positionAssociatedWithPreviousQuery && i && NSMaxRange([NSArrayObjectAtIndex(queries, i-1) rangeValue]) < position && position < queryStartPosition) positionAssociatedWithPreviousQuery = YES;
				
				// Otherwise associate if only whitespace since previous, and a newline before next.
				if (!positionAssociatedWithPreviousQuery) {
					@try{
					NSString *stringToPrevious = [[textView string] substringWithRange:NSMakeRange(queryStartPosition, position - queryStartPosition)];
					NSString *stringToEnd = [[textView string] substringWithRange:NSMakeRange(position, queryPosition - position)];
					if (![[stringToPrevious stringByTrimmingCharactersInSet:whitespaceAndNewlineSet] length]) {
						for (j = 0; j < [stringToEnd length]; j++) {
							if ([whitespaceSet characterIsMember:[stringToEnd characterAtIndex:j]]) continue;
							if ([whitespaceAndNewlineSet characterIsMember:[stringToEnd characterAtIndex:j]]) {
								positionAssociatedWithPreviousQuery = YES;
							}
							break;
						}
					}
					} @catch(id ae) {}
				}

				// If there is a previous query and the position should be associated with it, do so.
				if (i && positionAssociatedWithPreviousQuery && [[[[textView string] substringWithRange:[NSArrayObjectAtIndex(queries, i-1) rangeValue]] stringByTrimmingCharactersInSet:whitespaceAndNewlineSet] length]) {
					queryRange = [[queries objectAtIndex:i-1] rangeValue];
					break;
				}

				// Lookbehind failed - set the pointer to NO so the parent knows.
				*doLookBehind = NO;
			}
			break;
		}
	}

	// For lookbehinds catch position at the very end of a string ending in a semicolon
	if (*doLookBehind && position == [[textView string] length])
	{
		queryRange = [[queries lastObject] rangeValue];
	} 

	[queries release];

	
	queryRange = NSIntersectionRange(queryRange, NSMakeRange(0, [[textView string] length])); 
	if (!queryRange.length) {
		return NSMakeRange(NSNotFound, 0);
	}

	query = [[textView string] substringWithRange:queryRange];

	// Highlight by setting a background color the current query
	// and ignore leading/trailing white spaces
	int biasStart = [query rangeOfRegex:@"^\\s*"].length;
	int biasEnd   = [query rangeOfRegex:@"\\s*$"].length;
	queryRange.location += biasStart;
	queryRange.length   -= biasEnd+biasStart;

	// Ensure the string isn't empty.
	// (We could also strip comments for this check, but that prevents use of conditional comments)
	if(queryRange.length < 1 || queryRange.length > [query length]) {
		return NSMakeRange(NSNotFound, 0);
	}

	// Return the located query range
	return queryRange;
}

/*
 * Retrieve the range of the query for the passed index seen from a start position
 * specified within the custom query text view.  
 */
- (NSRange)queryTextRangeForQuery:(int)anIndex startPosition:(long)position
{
	SPSQLParser *customQueryParser;
	NSArray *queries;

	// If the supplied position is negative or beyond the end of the string, return nil.
	if (position < 0 || position > [[textView string] length])
		return NSMakeRange(NSNotFound,0);

	// Split the current text into ranges of queries
	customQueryParser = [[SPSQLParser alloc] initWithString:[[textView string] substringWithRange:NSMakeRange(position, [[textView string] length]-position)]];
	queries = [[NSArray alloc] initWithArray:[customQueryParser splitSqlStringIntoRangesByCharacter:';']];
	[customQueryParser release];

	// Check for a valid index
	anIndex--;
	if(anIndex < 0 || anIndex >= [queries count])
	{
		[queries release];
		return NSMakeRange(NSNotFound, 0);
	}

	NSRange theQueryRange = [[queries objectAtIndex:anIndex] rangeValue];
	NSString *theQueryString = [[textView string] substringWithRange:theQueryRange];
	
	[queries release];
	
	// Remove all leading white spaces
	int offset = [theQueryString rangeOfRegex:@"^(\\s*)"].length;
	theQueryRange.location += offset;
	theQueryRange.length -= offset;
	return theQueryRange;
}

/*
 * Retrieve the query at a position specified within the custom query
 * text view.  This will return nil if the position specified is beyond
 * the available string or if an empty query would be returned.
 * If lookBehind is set, returns the *previous* query, but only if the
 * caret should be associated with the previous query based on whitespace.
 */
- (NSString *)queryAtPosition:(long)position lookBehind:(BOOL *)doLookBehind
{

	BOOL lookBehind = *doLookBehind;
	NSRange queryRange = [self queryRangeAtPosition:position lookBehind:&lookBehind];
	*doLookBehind = lookBehind;
	
	return (queryRange.length) ? [[textView string] substringWithRange:queryRange] : nil;
}

- (void)selectCurrentQuery
{
	if(currentQueryRange.length)
		[textView setSelectedRange:currentQueryRange];
}

/*
 * Add or remove "/*  *~/" for each line in the current query
 * a given selection
 */
- (void)commentOutCurrentQueryTakingSelection:(BOOL)takeSelection
{

	BOOL isUncomment = NO;

	NSRange oldRange = [textView selectedRange];
	
	NSRange workingRange = oldRange;
	if(!takeSelection)
		workingRange = currentQueryRange;

	NSMutableString *n = [NSMutableString string];

	[n setString:[[textView string] substringWithRange:workingRange]];

	if([n isMatchedByRegex:@"\\n\\Z"]) {
		workingRange.length--;
		[n replaceOccurrencesOfRegex:@"\\n\\Z" withString:@""];
	}

	// Escape given */ by *\/ 
	[n replaceOccurrencesOfRegex:@"\\*/(?=.)" withString:@"*\\\\/"];
	[n replaceOccurrencesOfRegex:@"\\*/(?=\\n)" withString:@"*\\\\/"];

	// Wrap current query into /* */
	[n replaceOccurrencesOfRegex:@"^" withString:@"/* "];
	[n appendString:@" */"];
	
	// Check if current query/selection is already commented out, if so uncomment it
	if([n isMatchedByRegex:@"^/\\* \\s*/\\*\\s*(.|\\n)*?\\s*\\*/ \\*/\\s*$"]) {
		[n replaceOccurrencesOfRegex:@"^/\\* \\s*/\\*\\s*" withString:@""];
		[n replaceOccurrencesOfRegex:@"\\s*\\*/ \\*/\\s*\\Z" withString:@""];
		// unescape *\/
		[n replaceOccurrencesOfRegex:@"\\*\\\\/" withString:@"*/"];
		isUncomment = YES;
	}

	// Replace current query/selection by (un)commented string
	[textView setSelectedRange:workingRange];
	[textView insertText:n];
	
	// If commenting out locate the caret just after the first /* to allow to enter 
	// something like /*!400000 or similar
	if(!isUncomment)
		[textView setSelectedRange:NSMakeRange(workingRange.location+2,0)];

}

/*
 * Add or remove "-- " for each line in the current query or selection,
 * if the selection is in-line wrap selection into /* block comments and
 * place the caret after /* to allow to enter !xxxxxx e.g.
 */
- (void)commentOut
{

	NSRange oldRange = [textView selectedRange];
	
	if(oldRange.length) { // (un)comment selection
		[self commentOutCurrentQueryTakingSelection:YES];
	} else { // single line
		
		// get the current line range
		NSRange lineRange = [[textView string] lineRangeForRange:oldRange];
		NSMutableString *n = [NSMutableString string];

		// Put "-- " in front of the current line
		[n setString:[NSString stringWithFormat:@"-- %@", [[textView string] substringWithRange:lineRange]]];

		// Check if current line is already commented out, if so uncomment it
		// and preserve the original indention via regex:@"^-- (\\s*)"
		if([n isMatchedByRegex:@"^-- \\s*(--\\s|#)"]) {
			[n replaceOccurrencesOfRegex:@"^-- \\s*(--\\s|#)" 
				withString:[n substringWithRange:[n rangeOfRegex:@"^-- (\\s*)" 
													options:RKLNoOptions 
													inRange:NSMakeRange(0,[n length]) 
													capture:1
													error: nil]]];
		} else if ([n isMatchedByRegex:@"^-- \\s*/\\*.*? ?\\*/\\s*$"]) {
			[n replaceOccurrencesOfRegex:@"^-- \\s*/\\* ?" 
				withString:[n substringWithRange:[n rangeOfRegex:@"^-- (\\s*)" 
													options:RKLNoOptions 
													inRange:NSMakeRange(0,[n length]) 
													capture:1
													error: nil]]];
			[n replaceOccurrencesOfRegex:@" ?\\*/\\s*$" 
				withString:[n substringWithRange:[n rangeOfRegex:@" ?\\*/(\\s*)$" 
													options:RKLNoOptions 
													inRange:NSMakeRange(0,[n length]) 
													capture:1
													error: nil]]];
		}
		
		// Replace current line by (un)commented string
		// The caret will be placed at the beginning of the next line if present to
		// allow a fast (un)commenting of lines
		[textView setSelectedRange:lineRange];
		[textView insertText:n];

	}

}

#pragma mark -
#pragma mark Accessors

/*
 * Returns the current result (as shown in custom result view) as array, 
 * the first object containing the field names as array, 
 * the following objects containing the rows as array
 */
- (NSArray *)currentResult
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

/*
 * Sets the connection (received from TableDocument) and makes things that have to be done only once 
 */
- (void)setConnection:(MCPConnection *)theConnection
{
	NSArray *tableColumns = [queryFavoritesView tableColumns];
	NSEnumerator *enumerator = [tableColumns objectEnumerator];
	id column;

	mySQLConnection = theConnection;
	
	prefs = [NSUserDefaults standardUserDefaults];
	currentQueryRanges = nil;

	if ( [prefs objectForKey:@"queryFavorites"] ) {
		queryFavorites = [[NSMutableArray alloc] initWithArray:[prefs objectForKey:@"queryFavorites"]];
	} else {
		queryFavorites = [[NSMutableArray array] retain];
	}

	hasBackgroundAttribute = NO;

	// Set up the interface
	// Bind backgroundColor
	[textView setAllowsDocumentBackgroundColorChange:YES];
	NSMutableDictionary *bindingOptions = [NSMutableDictionary dictionary];
	[bindingOptions setObject:NSUnarchiveFromDataTransformerName
		forKey:@"NSValueTransformerName"];
	[textView bind: @"backgroundColor"
		toObject: [NSUserDefaultsController sharedUserDefaultsController]
		withKeyPath:@"values.CustomQueryEditorBackgroundColor"
		options:bindingOptions];
	[textView setFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:@"CustomQueryEditorFont"]]];
	[textView setBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:@"CustomQueryEditorBackgroundColor"]]];
	[textView setTextColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:@"CustomQueryEditorTextColor"]]];
	[textView setInsertionPointColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:@"CustomQueryEditorCaretColor"]]];
	
	[customQueryView setVerticalMotionCanBeginDrag:NO];
	[textView setContinuousSpellCheckingEnabled:NO];
	[autoindentMenuItem setState:([prefs boolForKey:@"CustomQueryAutoIndent"]?NSOnState:NSOffState)];
	[textView setAutoindent:[prefs boolForKey:@"CustomQueryAutoIndent"]];
	[textView setAutoindentIgnoresEnter:YES];
	[autopairMenuItem setState:([prefs boolForKey:@"CustomQueryAutoPairCharacters"]?NSOnState:NSOffState)];
	[textView setAutopair:[prefs boolForKey:@"CustomQueryAutoPairCharacters"]];
	[autohelpMenuItem setState:([prefs boolForKey:@"CustomQueryUpdateAutoHelp"]?NSOnState:NSOffState)];
	[textView setAutohelp:[prefs boolForKey:@"CustomQueryUpdateAutoHelp"]];
	[autouppercaseKeywordsMenuItem setState:([prefs boolForKey:@"CustomQueryAutoUppercaseKeywords"]?NSOnState:NSOffState)];
	[textView setAutouppercaseKeywords:[prefs boolForKey:@"CustomQueryAutoUppercaseKeywords"]];
	[queryFavoritesView registerForDraggedTypes:[NSArray arrayWithObjects:@"SequelProPasteboard", nil]];

	while ( (column = [enumerator nextObject]) )
	{
		if ( [prefs boolForKey:@"UseMonospacedFonts"] ) {
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
	
	// Disable runSelectionMenuItem in the gear menu
	[runSelectionMenuItem setEnabled:NO];
	
}

/*
 * Set up the favorites popUpButton
 */
- (void)setFavorites
{
	int i;

//remove all menuItems and add favorites from preferences
	for ( i = 4 ; i < [queryFavoritesButton numberOfItems] ; i++ ) {
		[queryFavoritesButton removeItemAtIndex:i];
	}
	[queryFavoritesButton addItemsWithTitles:queryFavorites];
}

/*
 * Inserts the query in the textView and performs query
 */
- (void)doPerformQueryService:(NSString *)query
{
	[textView setString:query];
	[self runAllQueries:self];
}

- (NSString *)usedQuery
{
	return usedQuery;
}

#pragma mark
#pragma mark Field Editing

/*
 * Collect all columns for a given 'tableForColumn' table and
 * return a WHERE clause for identifying the field in quesyion.
 */
- (NSString *)argumentForRow:(NSUInteger)rowIndex ofTable:(NSString *)tableForColumn andDatabase:(NSString *)database
{
	NSArray *dataRow;
	id field;

	//Look for all columns which are coming from "tableForColumn"
	NSMutableArray *columnsForFieldTableName = [NSMutableArray array];
	for(field in cqColumnDefinition) {
		if([[field objectForKey:@"org_table"] isEqualToString:tableForColumn])
			[columnsForFieldTableName addObject:field];
	}

	// Try to identify the field bijectively
	NSMutableString *fieldIDQueryStr = [NSMutableString string];
	[fieldIDQueryStr setString:@"WHERE ("];
	
	// Build WHERE clause
	dataRow = [fullResult objectAtIndex:rowIndex];
	for(field in columnsForFieldTableName) {
		id aValue = [dataRow objectAtIndex:[[field objectForKey:@"datacolumnindex"] intValue]];
		if ([aValue isKindOfClass:[NSNull class]] || [[aValue description] isEqualToString:[prefs stringForKey:@"NullValue"]]) {
			[fieldIDQueryStr appendFormat:@"%@ IS NULL", [[field objectForKey:@"org_name"] backtickQuotedString]];
		} else {
			[fieldIDQueryStr appendFormat:@"%@=", [[field objectForKey:@"org_name"] backtickQuotedString]];
			if ([[field objectForKey:@"typegrouping"] isEqualToString:@"textdata"])
				[fieldIDQueryStr appendFormat:@"'%@'", [mySQLConnection prepareString:aValue]];
			else if ([[field objectForKey:@"typegrouping"] isEqualToString:@"blobdata"])
				[fieldIDQueryStr appendFormat:@"X'%@'", [mySQLConnection prepareBinaryData:aValue]];
			else if ([[field objectForKey:@"typegrouping"] isEqualToString:@"integer"])
				[fieldIDQueryStr appendFormat:@"%@", [aValue description]];
			else
				[fieldIDQueryStr appendFormat:@"'%@'", [mySQLConnection prepareString:aValue]];
		}
		
		[fieldIDQueryStr appendString:@" AND "];
	}
	// Remove last " AND "
	if([fieldIDQueryStr length]>12)
		[fieldIDQueryStr replaceCharactersInRange:NSMakeRange([fieldIDQueryStr length]-5,5) withString:@")"];
	
	return fieldIDQueryStr;
}


#pragma mark -
#pragma mark TableView datasource methods

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if ( aTableView == customQueryView ) {
		if ( nil == fullResult ) {
			return 0;
		} else {
			return [fullResult count];
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

	if ( aTableView == customQueryView ) {

		id theValue = NSArrayObjectAtIndex(NSArrayObjectAtIndex(fullResult, rowIndex), [[aTableColumn identifier] intValue]);

		if ( [theValue isKindOfClass:[NSData class]] )
			return [theValue shortStringRepresentationUsingEncoding:[mySQLConnection encoding]];

		if ( [theValue isMemberOfClass:[NSNull class]] )
			return [prefs objectForKey:@"NullValue"];

	    return theValue;

	}
	
	else if ( aTableView == queryFavoritesView ) {
		return [queryFavorites objectAtIndex:rowIndex];
	}
	
	else {
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
				NSRunAlertPanel(@"Query already exists", @"The query you are adding to your favorites already exists.", @"OK", nil, nil);
				
				//remove row if it was a (blank) new row or a copied row
				if ( [NSArrayObjectAtIndex(queryFavorites, rowIndex) isEqualToString:@""] ||
						[NSArrayObjectAtIndex(queryFavorites, rowIndex) isEqualToString:anObject] ) {
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
	else if ( aTableView == customQueryView ) {

		// Field editing

		if(fieldIDQueryString == nil) return;

		NSDictionary *columnDefinition;

		// Retrieve the column defintion
		for(id c in cqColumnDefinition) {
			if([[c objectForKey:@"datacolumnindex"] isEqualToNumber:[aTableColumn identifier]]) {
				columnDefinition = [NSDictionary dictionaryWithDictionary:c];
				break;
			}
		}

		// Resolve the original table name for current column if AS was used
		NSString *tableForColumn = [columnDefinition objectForKey:@"org_table"];

		if(!tableForColumn || ![tableForColumn length]) {
			[errorText setStringValue:[NSString stringWithFormat:@"Couldn't identify field origin unambiguously. The column '%@' contains data from more than one table.", [columnDefinition objectForKey:@"name"]]];
			NSBeep();
			return;
		}

		// Resolve the original column name if AS was used
		NSString *columnName = [columnDefinition objectForKey:@"org_name"];

		// NSString *fieldIDQueryString = [self argumentForRow:rowIndex ofTable:tableForColumn];
		
		// Check if the IDstring identifies the current field bijectively
		int numberOfPossibleUpdateRows = [[[[mySQLConnection queryString:[NSString stringWithFormat:@"SELECT COUNT(*) FROM %@.%@ %@", [columnDefinition objectForKey:@"db"], [tableForColumn backtickQuotedString], fieldIDQueryString]] fetchRowAsArray] objectAtIndex:0] intValue];
		if(numberOfPossibleUpdateRows == 1) {
			// [[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];
			
			NSString *newObject = nil;
			if ( [anObject isKindOfClass:[NSCalendarDate class]] ) {
				newObject = [NSString stringWithFormat:@"'%@'", [mySQLConnection prepareString:[anObject description]]];
			} else if ( [anObject isKindOfClass:[NSNumber class]] ) {
				newObject = [anObject stringValue];
			} else if ( [anObject isKindOfClass:[NSData class]] ) {
				newObject = [NSString stringWithFormat:@"X'%@'", [mySQLConnection prepareBinaryData:anObject]];
			} else {
				if ( [[anObject description] isEqualToString:@"CURRENT_TIMESTAMP"] ) {
					newObject = @"CURRENT_TIMESTAMP";
				} else if([anObject isEqualToString:[prefs stringForKey:@"NullValue"]]) {
					newObject = @"NULL";
				} else if ([[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"bit"]) {
					newObject = ((![[anObject description] length] || [[anObject description] isEqualToString:@"0"])?@"0":@"1");
				} else if ([[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"date"]
							&& [[anObject description] isEqualToString:@"NOW()"]) {
					newObject = @"NOW()";
				} else {
					newObject = [NSString stringWithFormat:@"'%@'", [mySQLConnection prepareString:[anObject description]]];
				}
			}

			[mySQLConnection queryString:
				[NSString stringWithFormat:@"UPDATE %@.%@ SET %@.%@.%@=%@ %@ LIMIT 1", 
					[columnDefinition objectForKey:@"db"], [tableForColumn backtickQuotedString],
					[columnDefinition objectForKey:@"db"], [tableForColumn backtickQuotedString], [columnName backtickQuotedString], newObject, fieldIDQueryString]];
			
			// [[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];

			// Check for errors while UPDATE
			if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""] ) {
				NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), NSLocalizedString(@"Cancel", @"cancel button"), nil, tableWindow, self, nil, nil, nil,
								  [NSString stringWithFormat:NSLocalizedString(@"Couldn't write field.\nMySQL said: %@", @"message of panel when error while updating field to db"), [mySQLConnection getLastErrorMessage]]);

				return;
			}


			// This shouldn't happen – for safety reasons
			if ( ![mySQLConnection affectedRows] ) {
				if ( [prefs boolForKey:@"ShowNoAffectedRowsError"] ) {
					NSBeginAlertSheet(NSLocalizedString(@"Warning", @"warning"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
									  NSLocalizedString(@"The row was not written to the MySQL database. You probably haven't changed anything.\nReload the table to be sure that the row exists and use a primary key for your table.\n(This error can be turned off in the preferences.)", @"message of panel when no rows have been affected after writing to the db"));
				} else {
					NSBeep();
				}
				return;
			}

			// On success reload table data by executing the last query
			tableReloadAfterEditing = YES;
			[self performQueries:[NSArray arrayWithObject:lastExecutedQuery]];
			
		} else {
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, tableWindow, self, nil, nil, nil,
							  [NSString stringWithFormat:NSLocalizedString(@"Updating field content failed. Couldn't identify field origin unambiguously (%d match%@). It's very likely that while editing this field the table `%@` was changed by an other user.", @"message of panel when error while updating field to db after enabling it"), 
										numberOfPossibleUpdateRows, (numberOfPossibleUpdateRows>1)?@"es":@"", tableForColumn]);

		}

	}
}

/*
 * Change the sort order by clicking at a column header
 */
- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{

	NSMutableString *queryString = [NSMutableString stringWithString:lastExecutedQuery];

	//sets order descending if a header is clicked twice
	if ( sortField && [[tableColumn identifier] isEqualToNumber:sortField] ) {
		isDesc = !isDesc;
	} else {
		isDesc = NO;
		if (sortField) [customQueryView setIndicatorImage:nil inTableColumn:[customQueryView tableColumnWithIdentifier:sortField]];
	}

	if (sortField) [sortField release];
	sortField = [[NSNumber alloc] initWithInt:[[tableColumn identifier] intValue]];

	// Order by the column position number to avoid ambiguous name errors
	NSString* newOrder = [NSString stringWithFormat:@" ORDER BY %i %@ ", [[tableColumn identifier] intValue]+1, (isDesc)?@"DESC":@"ASC"];
	
	[queryString replaceOccurrencesOfRegex:@"--.*?\n" withString:@""];
	[queryString replaceOccurrencesOfRegex:@"--.*?$" withString:@""];
	[queryString replaceOccurrencesOfRegex:@"/\\*(.|\n)*?\\*/" withString:@""];

	// Remove all quoted strings as a temp string to match the correct clauses
	NSRange matchedRange;
	int i;
	NSMutableString *tmpString = [NSMutableString stringWithString:queryString];
	NSMutableString *qq = [NSMutableString string];
	matchedRange = [tmpString rangeOfRegex:@"\"(?:[^\"\\\\]*+|\\\\.)*\""];
	// Replace all "..." with _'s
	while(matchedRange.length) {
		[qq setString:@""];
		for(i=0; i<matchedRange.length; i++) [qq appendString:@"_"];
		[tmpString replaceCharactersInRange:matchedRange withString:qq];
		[tmpString flushCachedRegexData];
		matchedRange = [tmpString rangeOfRegex:@"\"(?:[^\"\\\\]*+|\\\\.)*\""];
	}
	// Replace all '...' with _'s
	matchedRange = [tmpString rangeOfRegex:@"'(?:[^'\\\\]*+|\\\\.)*'"];
	while(matchedRange.length) {
		[qq setString:@""];
		for(i=0; i<matchedRange.length; i++) [qq appendString:@"_"];
		[tmpString replaceCharactersInRange:matchedRange withString:qq];
		[tmpString flushCachedRegexData];
		matchedRange = [tmpString rangeOfRegex:@"'(?:[^'\\\\]*+|\\\\.)*'"];
	}
	// Replace all `...` with _'s
	matchedRange = [tmpString rangeOfRegex:@"`(?:[^`\\\\]*+|\\\\.)*`"];
	while(matchedRange.length) {
		[qq setString:@""];
		for(i=0; i<matchedRange.length; i++) [qq appendString:@"_"];
		[tmpString replaceCharactersInRange:matchedRange withString:qq];
		[tmpString flushCachedRegexData];
		matchedRange = [tmpString rangeOfRegex:@"`(?:[^`\\\\]*+|\\\\.)*`"];
	}

	// Check for an existing ORDER clause (in the temp string),
	// if so replace it by the new one (in the actual string)
	// Test for ORDER clause inside a statement
	if([tmpString isMatchedByRegex:@"(?i)\\s+ORDER\\s+BY\\s+(.|\\n)+(\\s+(DESC|ASC))?(\\s|\\n)+(?=(LI|PR|IN|FO|LO))"])
		{
			matchedRange = [tmpString rangeOfRegex:@"(?i)\\s+ORDER\\s+BY\\s+(.|\\n)+(\\s+(DESC|ASC))?(\\s|\\n)+(?=(LI|PR|IN|FO|LO))"];
			[queryString replaceCharactersInRange:matchedRange withString:newOrder];
		}
	// Test for ORDER clause at the end
	else if ([tmpString isMatchedByRegex:@"(?i)\\s+ORDER\\s+BY\\s+(.|\\n)+((\\s|\\n)+(DESC|ASC))?"])
		{
			matchedRange = [tmpString rangeOfRegex:@"(?i)\\s+ORDER\\s+BY\\s+(.|\\n)+((\\s|\\n)+(DESC|ASC))?"];
			[queryString replaceCharactersInRange:matchedRange withString:newOrder];
		}
	// No ORDER clause found
	// ORDER clause has to be inserted before LIMIT, PROCEDURE, INTO, FOR, or LOCK due to MySQL syntax for SELECT
	else if([tmpString isMatchedByRegex:@"(?i)\\bSELECT\\b((.|\\n)+?)\\s*(?=(\\sLIMIT\\s|\\sPROCEDURE\\s|\\sINTO\\s|\\sFOR\\s|\\sLOCK\\s))"])
		{
			matchedRange = [tmpString rangeOfRegex:@"(?i)\\bSELECT\\b((.|\\n)+?)(?=(\\sLIMIT\\s|\\sPROCEDURE\\s|\\sINTO\\s|\\sFOR\\s|\\sLOCK\\s))" capture:1];
			NSString *orderHeader = [NSString stringWithFormat:@"%@ %@", [queryString substringWithRange:matchedRange], newOrder];
			[queryString replaceCharactersInRange:matchedRange withString:orderHeader];
		}
	// Otherwise append the new ORDER clause at the end
	else
		[queryString appendFormat:@" %@", newOrder];

	tableReloadAfterEditing = YES;
	queryIsTableSorter = YES;
	[self performQueries:[NSArray arrayWithObject:queryString]];
	queryIsTableSorter = NO;

	if(![[mySQLConnection getLastErrorMessage] isEqualToString:@""]) return;

	//sets highlight and indicatorImage
	[customQueryView setHighlightedTableColumn:tableColumn];
	if ( isDesc )
		[customQueryView setIndicatorImage:[NSImage imageNamed:@"NSDescendingSortIndicator"] inTableColumn:tableColumn];
	else
		[customQueryView setIndicatorImage:[NSImage imageNamed:@"NSAscendingSortIndicator"] inTableColumn:tableColumn];

}


#pragma mark -
#pragma mark TableView Drag & Drop datasource methods

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


#pragma mark -
#pragma mark TableView delegate methods

/*
 * Double-click action on a field
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{

	// Check if the field can identified bijectively
	if ( aTableView == customQueryView ) {


		NSDictionary *columnDefinition;
		BOOL noTableName = NO;
		BOOL isFieldEditable;
		BOOL isBlob;
		int numberOfPossibleUpdateRows = -1;

		// Retrieve the column defintion
		for(id c in cqColumnDefinition) {
			if([[c objectForKey:@"datacolumnindex"] isEqualToNumber:[aTableColumn identifier]]) {
				columnDefinition = [NSDictionary dictionaryWithDictionary:c];
				break;
			}
		}

		// Check if current field is a blob
		if([[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"textdata"]
			|| [[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"blobdata"])
			isBlob = YES;
		else
			isBlob = NO;

		// Resolve the original table name for current column if AS was used
		NSString *tableForColumn = [columnDefinition objectForKey:@"org_table"];

		// Get the database name which the field belongs to
		NSString *dbForColumn = [columnDefinition objectForKey:@"db"];

		// No table/database name found indicates that the field's column contains data from more than one table as for UNION
		// or the field data are not bound to any table as in SELECT 1 or if column database is unset
		if(!tableForColumn || ![tableForColumn length] || ![dbForColumn length])
			noTableName = YES;
	
		if(!noTableName) {
			// if table and database name are given check if field can be identified unambiguously
			fieldIDQueryString = [self argumentForRow:rowIndex ofTable:tableForColumn andDatabase:[columnDefinition objectForKey:@"db"]];
	
			// Actual check whether field can be identified bijectively
			numberOfPossibleUpdateRows = [[[[mySQLConnection queryString:[NSString stringWithFormat:@"SELECT COUNT(*) FROM %@.%@ %@", [columnDefinition objectForKey:@"db"], [tableForColumn backtickQuotedString], fieldIDQueryString]] fetchRowAsArray] objectAtIndex:0] intValue];

			isFieldEditable = (numberOfPossibleUpdateRows == 1) ? YES : NO;

			if(!isFieldEditable)
			 	[errorText setStringValue:[NSString stringWithFormat:@"Field is not editable. Couldn't identify field origin unambiguously (%d match%@).", numberOfPossibleUpdateRows, (numberOfPossibleUpdateRows>1)?@"es":@""]];

		} else {
			// no table/databse name are given
			isFieldEditable = NO;
			fieldIDQueryString = nil;
		 	[errorText setStringValue:NSLocalizedString(@"Field is not editable. Field has no or multiple table or database origin(s).",@"field is not editable due to no table/database")];
		}


		SPFieldEditorController *fieldEditor = [[SPFieldEditorController alloc] init];
		id editData = [[fieldEditor editWithObject:[[fullResult objectAtIndex:rowIndex] objectAtIndex:[[aTableColumn identifier] intValue]] 
								usingEncoding:[mySQLConnection encoding] 
								isObjectBlob:isBlob 
								isEditable:isFieldEditable 
								withWindow:tableWindow] retain];

		if ( editData )
			[self tableView:aTableView setObjectValue:[editData copy] forTableColumn:aTableColumn row:rowIndex];

		[fieldEditor release];

		if ( editData ) [editData release];

		return NO;

	} else {
		return YES;
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

/**
 * Saves the new column size in the preferences for columns which map to fields
 */
- (void)tableViewColumnDidResize:(NSNotification *)aNotification
{
	// Abort if still loading the table
	if (![cqColumnDefinition count]) return;
NSLog(@"start");
	// Retrieve the original index of the column from the identifier
	int columnIndex = [[[[aNotification userInfo] objectForKey:@"NSTableColumn"] identifier] intValue];
	NSDictionary *columnDefinition = NSArrayObjectAtIndex(cqColumnDefinition, columnIndex);
	NSLog(@"1");
	// Don't save if the column doesn't map to an underlying SQL field
	if (![columnDefinition objectForKey:@"org_name"] || ![[columnDefinition objectForKey:@"org_name"] length])
		return;
	NSLog(@"2");

	NSMutableDictionary *tableColumnWidths;
	NSString *host_db = [NSString stringWithFormat:@"%@@%@", [columnDefinition objectForKey:@"db"], [tableDocumentInstance host]];
	NSString *table = [columnDefinition objectForKey:@"org_table"];
	NSString *col = [columnDefinition objectForKey:@"org_name"];
	
	// Retrieve or instantiate the tableColumnWidths object
	if ([prefs objectForKey:@"tableColumnWidths"] != nil) {
		tableColumnWidths = [NSMutableDictionary dictionaryWithDictionary:[prefs objectForKey:@"tableColumnWidths"]];
	} else {
		tableColumnWidths = [NSMutableDictionary dictionary];
	}

	// Edit or create database object
	if  ([tableColumnWidths objectForKey:host_db] == nil) {
		[tableColumnWidths setObject:[NSMutableDictionary dictionary] forKey:host_db];
	} else {
		[tableColumnWidths setObject:[NSMutableDictionary dictionaryWithDictionary:[tableColumnWidths objectForKey:host_db]] forKey:host_db];
	}
	
	// Edit or create table object
	if  ([[tableColumnWidths objectForKey:host_db] objectForKey:table] == nil) {
		[[tableColumnWidths objectForKey:host_db] setObject:[NSMutableDictionary dictionary] forKey:table];
	} else {
		[[tableColumnWidths objectForKey:host_db] setObject:[NSMutableDictionary dictionaryWithDictionary:[[tableColumnWidths objectForKey:host_db] objectForKey:table]] forKey:table];
	}

	// Save the column size
	[[[tableColumnWidths objectForKey:host_db] objectForKey:table] setObject:[NSNumber numberWithFloat:[[[aNotification userInfo] objectForKey:@"NSTableColumn"] width]] forKey:col];
	[prefs setObject:tableColumnWidths forKey:@"tableColumnWidths"];
}


#pragma mark -
#pragma mark TextView delegate methods

/*
 * Traps enter key and performs query instead of inserting a line break if aTextView == textView
 * closes valueSheet if aTextView == valueTextField
 */
- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector
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

#pragma mark -
#pragma mark TextView notifications

/*
 * A notification posted when the selection changes within the text view;
 * used to control the run-currentrun-selection button state and action.
 */
- (void)textViewDidChangeSelection:(NSNotification *)aNotification
{

	// Ensure that the notification is from the custom query text view
	if ( [aNotification object] != textView ) return;

	// Remove all background color attributes used by highlighting the current query
	if([prefs boolForKey:@"CustomQueryHighlightCurrentQuery"]) {
		// Remove only the background attribute for the current range if still valid
		NSRange textRange = NSMakeRange(0,[[textView string] length]);
		NSRange r = NSIntersectionRange(currentQueryRange, textRange);
		if(r.length)
			[[textView textStorage] removeAttribute:NSBackgroundColorAttributeName range:r];
		else
			[[textView textStorage] removeAttribute:NSBackgroundColorAttributeName range:textRange];
	} else {
		// ensure that we do it only once
		if(hasBackgroundAttribute) {
			[[textView textStorage] removeAttribute:NSBackgroundColorAttributeName range:NSMakeRange(0,[[textView string] length])];
			hasBackgroundAttribute = NO;
		}
	}

	BOOL isLookBehind = YES;
	NSRange currentSelection = [textView selectedRange];
	long caretPosition = currentSelection.location;
	NSRange qRange = [self queryRangeAtPosition:caretPosition lookBehind:&isLookBehind];

	// Highlight by setting a background color the current query
	// if nothing is selected
	if(qRange.length && !currentSelection.length) {
		if([prefs boolForKey:@"CustomQueryHighlightCurrentQuery"]) {
			[[textView textStorage] addAttribute: NSBackgroundColorAttributeName
					  value: [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:@"CustomQueryEditorHighlightQueryColor"]]
					  range: qRange ];
			hasBackgroundAttribute = YES;
		}
		currentQueryRange = qRange;
		
	} else {
		currentQueryRange = NSMakeRange(0, 0);
	}

	// disable "Comment Current Query" meun item if no current query is selectable
	[commentCurrentQueryMenuItem setEnabled:(currentQueryRange.length) ? YES : NO];

	// If no text is selected, disable the button and action menu.
	if ( caretPosition == NSNotFound ) {
		[runSelectionButton setEnabled:NO];
		[runSelectionMenuItem setEnabled:NO];
		return;
	}

	// If the current selection is a single caret position, update the button based on
	// whether the caret is inside a valid query.
	if (!currentSelection.length) {
		[runSelectionButton setTitle:NSLocalizedString(@"Run Current", @"Title of button to run current query in custom query view")];
		[runSelectionMenuItem setTitle:NSLocalizedString(@"Run Current Query", @"Title of action menu item to run current query in custom query view")];

		// If a valid query is present at the cursor position, enable the button
		if (qRange.length) {
			if (isLookBehind) {
				[runSelectionButton setTitle:NSLocalizedString(@"Run Previous", @"Title of button to run query just before text caret in custom query view")];
				[runSelectionMenuItem setTitle:NSLocalizedString(@"Run Previous Query", @"Title of action menu item to run query just before text caret in custom query view")];
			}
			[runSelectionButton setEnabled:YES];
			[runSelectionMenuItem setEnabled:YES];
		} else {
			[runSelectionButton setEnabled:NO];
			[runSelectionMenuItem setEnabled:NO];
		}
		[commentLineOrSelectionMenuItem setTitle:NSLocalizedString(@"Comment Line", @"Title of action menu item to comment line")];

	// For selection ranges, enable the button.
	} else {
		[runSelectionButton setTitle:NSLocalizedString(@"Run Selection", @"Title of button to run selected text in custom query view")];
		[runSelectionButton setEnabled:YES];
		[runSelectionMenuItem setTitle:NSLocalizedString(@"Run Selected Text", @"Title of action menu item to run selected text in custom query view")];
		[runSelectionMenuItem setEnabled:YES];
		[commentLineOrSelectionMenuItem setTitle:NSLocalizedString(@"Comment Selection", @"Title of action menu item to comment selection")];
	}

}

/*
 * Save the custom query editor font if it is changed.
 */
- (void)textViewDidChangeTypingAttributes:(NSNotification *)aNotification
{
	// Only save the font if prefs have been loaded, ensuring the saved font has been applied once.
	if (prefs)
		[prefs setObject:[NSArchiver archivedDataWithRootObject:[textView font]] forKey:@"CustomQueryEditorFont"];
}


#pragma mark -
#pragma mark SplitView delegate methods

/*
 * Tells the splitView that it can collapse views
 */
- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	return YES;
}

/*
 * Defines max position of splitView
 */
- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
{
	if ( offset == 0 ) {
		return proposedMax - 100;
	} else {
		return proposedMax - 73;
	}
}

/*
 * Defines min position of splitView
 */
- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
{
	if ( offset == 0 ) {
		return proposedMin + 100;
	} else {
		return proposedMin + 100;
	}
}


#pragma mark -
#pragma mark MySQL Help

/*
 * Set the MySQL version as X.Y for Help window title and online search
 */
- (void)setMySQLversion:(NSString *)theVersion
{
	mySQLversion = [[theVersion substringToIndex:3] retain];
	[textView setConnection:mySQLConnection withVersion:[[[mySQLversion componentsSeparatedByString:@"."] objectAtIndex:0] intValue]];
	
}

/*
 * Return the Help window.
 */
- (NSWindow *)helpWebViewWindow
{
	return helpWebViewWindow;
}

/*
 * Show the data for "HELP 'searchString'".
 */
- (void)showHelpFor:(NSString *)searchString addToHistory:(BOOL)addToHistory
{
	
	NSString * helpString = [self getHTMLformattedMySQLHelpFor:searchString];

	// Order out resp. init the Help window if not visible
	if(![helpWebViewWindow isVisible])
	{
		// set title of the Help window
		[helpWebViewWindow setTitle:[NSString stringWithFormat:@"%@ (%@ %@)", NSLocalizedString(@"MySQL Help", @"mysql help"), NSLocalizedString(@"version", @"version"), mySQLversion]];
	
		// init goback/forward buttons
		if([[helpWebView backForwardList] backListCount] < 1)
		{
			[helpNavigator setEnabled:NO forSegment:SP_HELP_GOBACK_BUTTON];
			[helpNavigator setEnabled:NO forSegment:SP_HELP_GOFORWARD_BUTTON];
		} else {
			[helpNavigator setEnabled:[[helpWebView backForwardList] backListCount] forSegment:SP_HELP_GOBACK_BUTTON];
			[helpNavigator setEnabled:[[helpWebView backForwardList] forwardListCount] forSegment:SP_HELP_GOFORWARD_BUTTON];
		}

		// set default to search in MySQL help
		helpTarget = SP_HELP_SEARCH_IN_MYSQL;
		[helpTargetSelector setSelectedSegment:SP_HELP_SEARCH_IN_MYSQL];
		[self helpTargetValidation];

		// order out Help window if Help is available
		if(![helpString isEqualToString:SP_HELP_NOT_AVAILABLE])
			[helpWebViewWindow orderFront:helpWebView];
			
	}

	// close Help window if no Help avaiable
	if([helpString isEqualToString:SP_HELP_NOT_AVAILABLE])
		[helpWebViewWindow close];
	
	if(![helpString length]) return;
	
	// add searchString to history list
	if(addToHistory)
	{
		WebHistoryItem *aWebHistoryItem = [[WebHistoryItem alloc] initWithURLString:[NSString stringWithFormat:@"applewebdata://%@", searchString] title:searchString lastVisitedTimeInterval:[[NSDate date] timeIntervalSinceDate:[NSDate distantFuture]]];
		[[helpWebView backForwardList] addItem:aWebHistoryItem];
		[aWebHistoryItem release];
	}

	// validate goback/forward buttons
	[helpNavigator setEnabled:[[helpWebView backForwardList] backListCount] forSegment:SP_HELP_GOBACK_BUTTON];
	[helpNavigator setEnabled:[[helpWebView backForwardList] forwardListCount] forSegment:SP_HELP_GOFORWARD_BUTTON];
	
	// load HTML formatted help into the webview
	[[helpWebView mainFrame] loadHTMLString:helpString baseURL:nil];
	
}


/*
 * Show the data for "HELP 'search word'" according to helpTarget
 */
- (IBAction)showHelpForSearchString:(id)sender
{
	NSString *searchString = [[helpSearchField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	switch(helpTarget)
	{
		case SP_HELP_SEARCH_IN_PAGE:
			if(![helpWebView searchFor:searchString direction:YES caseSensitive:NO wrap:YES])
				if([searchString length]) NSBeep();
			break;
		case SP_HELP_SEARCH_IN_WEB:
			if(![searchString length])
				break;
			[self openMySQLonlineDocumentationWithString:searchString];
			break;
		case SP_HELP_SEARCH_IN_MYSQL:
			[self showHelpFor:searchString addToHistory:YES];
			break;
	}
}

/*
 * Show the Help for the selected text in the webview
 */
- (IBAction)showHelpForWebViewSelection:(id)sender
{
	[self showHelpFor:[[helpWebView selectedDOMRange] text] addToHistory:YES];
}

/*
 * Show MySQL's online documentation for the selected text in the webview
 */
- (IBAction)searchInDocForWebViewSelection:(id)sender
{
	NSString *searchString = [[[helpWebView selectedDOMRange] text] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if(![searchString length])
	{
		NSBeep();
		return;
	}
	[self openMySQLonlineDocumentationWithString:searchString];
}


/*
 * Show the data for "HELP 'currentWord'"
 */
- (IBAction)showHelpForCurrentWord:(id)sender
{
	NSString *searchString = [[sender string] substringWithRange:[sender getRangeForCurrentWord]];
	[self showHelpFor:searchString addToHistory:YES];
}

/*
 * Find Next/Previous in current page
 */
- (IBAction)helpSearchFindNextInPage:(id)sender
{
	if(helpTarget == SP_HELP_SEARCH_IN_PAGE)
		if(![helpWebView searchFor:[[helpSearchField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] direction:YES caseSensitive:NO wrap:YES])
			NSBeep();
}
- (IBAction)helpSearchFindPreviousInPage:(id)sender
{
	if(helpTarget == SP_HELP_SEARCH_IN_PAGE)
		if(![helpWebView searchFor:[[helpSearchField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] direction:NO caseSensitive:NO wrap:YES])
			NSBeep();
}

/*
 * Navigation for back/TOC/forward
 */
- (IBAction)helpSegmentDispatcher:(id)sender
{
	switch([helpNavigator selectedSegment])
	{
		case SP_HELP_GOBACK_BUTTON:
			[helpWebView goBack];
			break;
		case SP_HELP_SHOW_TOC_BUTTON:
			[self showHelpFor:SP_HELP_TOC_SEARCH_STRING addToHistory:YES];
			break;
		case SP_HELP_GOFORWARD_BUTTON:
			[helpWebView goForward];
			break;
	}
	// validate goback and goforward buttons according history
	[helpNavigator setEnabled:[[helpWebView backForwardList] backListCount] forSegment:SP_HELP_GOBACK_BUTTON];
	[helpNavigator setEnabled:[[helpWebView backForwardList] forwardListCount] forSegment:SP_HELP_GOFORWARD_BUTTON];
	
}

/*
 * Set helpTarget according user choice via mouse and keyboard short-cuts.
 */
- (IBAction)helpSelectHelpTargetMySQL:(id)sender
{
	helpTarget = SP_HELP_SEARCH_IN_MYSQL;
	[helpTargetSelector setSelectedSegment:SP_HELP_SEARCH_IN_MYSQL];
	[self helpTargetValidation];
}
- (IBAction)helpSelectHelpTargetPage:(id)sender
{
	helpTarget = SP_HELP_SEARCH_IN_PAGE;
	[helpTargetSelector setSelectedSegment:SP_HELP_SEARCH_IN_PAGE];
	[self helpTargetValidation];
}
- (IBAction)helpSelectHelpTargetWeb:(id)sender
{
	helpTarget = SP_HELP_SEARCH_IN_WEB;
	[helpTargetSelector setSelectedSegment:SP_HELP_SEARCH_IN_WEB];
	[self helpTargetValidation];
}
- (IBAction)helpTargetDispatcher:(id)sender
{
	helpTarget = [helpTargetSelector selectedSegment];
	[self helpTargetValidation];
}

/*
 * Control the help search field behaviour.
 */
- (void)helpTargetValidation
{
	switch(helpTarget)
	{
		case SP_HELP_SEARCH_IN_PAGE:
		case SP_HELP_SEARCH_IN_WEB:
		[helpSearchFieldCell setSendsWholeSearchString:YES];
		break;
		case SP_HELP_SEARCH_IN_MYSQL:
		[helpSearchFieldCell setSendsWholeSearchString:NO];
		break;
	}
}

- (void)openMySQLonlineDocumentationWithString:(NSString *)searchString
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:
		[[NSString stringWithFormat:
			SP_MYSQL_DEV_SEARCH_URL,
			searchString,
			[mySQLversion stringByReplacingOccurrencesOfString:@"." withString:@""]]
		stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]]];
}

/*
 * Return the help string HTML formatted from executing "HELP 'searchString'".
 * If more than one help topic was found return a link list.
 */
- (NSString *)getHTMLformattedMySQLHelpFor:(NSString *)searchString
{

	if(![searchString length]) return @"";
	
	NSRange         aRange;
	MCPResult     *theResult = nil;
	NSDictionary    *tableDetails;
	NSMutableString *theHelp = [NSMutableString string];

	[theHelp setString:@""];
	
	// search via: HELP 'searchString'
	theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"HELP '%@'", [searchString stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"]]];
	if ( ![[mySQLConnection getLastErrorMessage] isEqualToString:@""])
	{
		// if an error or HELP is not supported fall back to online search
		NSLog(@"Error in HELP statement for '%@'", searchString);
		[self openMySQLonlineDocumentationWithString:searchString];
		return SP_HELP_NOT_AVAILABLE;
	}
	// nothing found?
	if(![theResult numOfRows]) {
		// try to search via: HELP 'searchString%'
		theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"HELP '%@%%'", [searchString stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"]]];
		// really nothing found?
		if(![theResult numOfRows])
			return @"";
	}
	tableDetails = [[NSDictionary alloc] initWithDictionary:[theResult fetchRowAsDictionary]];

	if ([tableDetails objectForKey:@"description"]) { // one single help topic found
		if ([tableDetails objectForKey:@"name"]) {
			[theHelp appendString:@"<h2 class='header'>"];
			[theHelp appendString:[[[tableDetails objectForKey:@"name"] copy] autorelease]];
			[theHelp appendString:@"</h2>"];

		}
		if ([tableDetails objectForKey:@"description"]) {
			NSMutableString *desc = [NSMutableString string];
			NSError *err1 = NULL;
			NSString *aUrl;
			
			[desc setString:[[[tableDetails objectForKey:@"description"] copy] autorelease]];

			//[desc replaceOccurrencesOfString:[searchString uppercaseString] withString:[NSString stringWithFormat:@"<span class='searchstring'>%@</span>", [searchString uppercaseString]] options:NSLiteralSearch range:NSMakeRange(0,[desc length])];

			// detect and generate http links
			aRange = NSMakeRange(0,0);
			int safeCnt = 0; // safety counter - not more than 200 loops allowed
			while(1){
				aRange = [desc rangeOfRegex:@"\\s((https?|ftp|file)://.*?html)" options:RKLNoOptions inRange:NSMakeRange(aRange.location+aRange.length, [desc length]-aRange.location-aRange.length) capture:1 error:&err1];
				if(aRange.location != NSNotFound) {
					aUrl = [desc substringWithRange:aRange];
					[desc replaceCharactersInRange:aRange withString:[NSString stringWithFormat:@"<a href='%@'>%@</a>", aUrl, aUrl]];
				}
				else
					break;
				safeCnt++;
				if(safeCnt > 200)
					break;
			}
			// detect and generate mysql links for "[HELP keyword]"
			aRange = NSMakeRange(0,0);
			safeCnt = 0;
			while(1){
				// TODO how to catch in HELP 'grant' last see [HELP SHOW GRANTS] ?? it's ridiculous
				aRange = [desc rangeOfRegex:@"\\[HELP ([^ ]*?)\\]" options:RKLNoOptions inRange:NSMakeRange(aRange.location+aRange.length+53, [desc length]-53-aRange.location-aRange.length) capture:1 error:&err1];
				if(aRange.location != NSNotFound) {
					aUrl = [[desc substringWithRange:aRange] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
					[desc replaceCharactersInRange:aRange withString:[NSString stringWithFormat:@"<a title='%@ “%@”' href='%@' class='internallink'>%@</a>", NSLocalizedString(@"Show MySQL help for", @"show mysql help for"), aUrl, aUrl, aUrl]];
				}
				else
					break;
				safeCnt++;
				if(safeCnt > 200)
					break;
			}
			// detect and generate mysql links for capitalzed letters
			// aRange = NSMakeRange(0,0);
			// safeCnt = 0;
			// while(1){
			// 	aRange = [desc rangeOfRegex:@"(?<!\\w)([A-Z_]{2,}( [A-Z_]{2,})?)" options:RKLNoOptions inRange:NSMakeRange(aRange.location+aRange.length, [desc length]-aRange.location-aRange.length) capture:1 error:&err1];
			// 	if(aRange.location != NSNotFound) {
			// 		aUrl = [desc substringWithRange:aRange];
			// 		[desc replaceCharactersInRange:aRange withString:[NSString stringWithFormat:@"<a title='%@ “%@”' href='%@' class='internallink'>%@</a>", NSLocalizedString(@"Show MySQL help for", @"show mysql help for"), aUrl, aUrl, aUrl]];
			// 	}
			// 	else
			// 		break;
			// 	safeCnt++;
			// 	if(safeCnt > 200)
			// 		break;
			// }

			[theHelp appendString:@"<pre class='description'>"];
			[theHelp appendString:desc];
			[theHelp appendString:@"</pre>"];
		}
		// are examples available?
		if([tableDetails objectForKey:@"example"]){
			NSString *examples = [[[tableDetails objectForKey:@"example"] copy] autorelease];
			if([examples length]){
				[theHelp appendString:@"<br><i><b>Example:</b></i><br><pre class='example'>"];
				[theHelp appendString:examples];
				[theHelp appendString:@"</pre>"];
			}
		}
	} else { // list all found topics
		int i;
		int r = [theResult numOfRows];
		if (r) [theResult dataSeek:0];
		// check if HELP 'contents' is called
		if(![searchString isEqualToString:SP_HELP_TOC_SEARCH_STRING])
			[theHelp appendString:[NSString stringWithFormat:@"<br><i>%@ “%@”</i><br>", NSLocalizedString(@"Help topics for", @"help topics for"), searchString]];
		else
			[theHelp appendString:[NSString stringWithFormat:@"<br><b>%@:</b><br>", NSLocalizedString(@"MySQL Help – Categories", @"mysql help categories"), searchString]];

		// iterate through all found rows and print them as HTML ul/li list
		[theHelp appendString:@"<ul>"];
		for ( i = 0 ; i < r ; i++ ) {
			NSArray *anArray = [theResult fetchRowAsArray];
			NSString *topic = [anArray objectAtIndex:[anArray count]-2];
			[theHelp appendString:
				[NSString stringWithFormat:@"<li><a title='%@ “%@”' href='%@' class='internallink'>%@</a></li>", NSLocalizedString(@"Show MySQL help for", @"show mysql help for"), topic, topic, topic]];
		}
		[theHelp appendString:@"</ul>"];
	}

	[tableDetails release];
	
	return [NSString stringWithFormat:helpHTMLTemplate, theHelp];

}

//////////////////////////////
// WebView delegate methods //
//////////////////////////////

/*
 * Link detector: If user clicked at an http link open it in the default browser,
 * otherwise search for it in the MySQL help. Additionally handle back/forward events from
 * keyboard and context menu.
 */
- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
	int navigationType = [[actionInformation objectForKey:WebActionNavigationTypeKey] intValue];

	if([[[request URL] scheme] isEqualToString:@"applewebdata"] && navigationType == WebNavigationTypeLinkClicked){
		[self showHelpFor:[[[request URL] path] lastPathComponent] addToHistory:YES];
		[listener ignore];
	} else {
		if (navigationType == WebNavigationTypeOther) {
			// catch reload event
			// if([[[actionInformation objectForKey:WebActionOriginalURLKey] absoluteString] isEqualToString:@"about:blank"])
			// 	[listener use];
			// else
			[listener use];
		} else if (navigationType == WebNavigationTypeLinkClicked) {
			// show http in browser
			[[NSWorkspace sharedWorkspace] openURL:[actionInformation objectForKey:WebActionOriginalURLKey]];
			[listener ignore];
		} else if (navigationType == WebNavigationTypeBackForward) {
			// catch back/forward events from contextual menu
			[self showHelpFor:[[[[actionInformation objectForKey:WebActionOriginalURLKey] absoluteString] lastPathComponent] stringByReplacingPercentEscapesUsingEncoding:NSASCIIStringEncoding] addToHistory:NO];
			[listener ignore];
		} else if (navigationType == WebNavigationTypeReload) {
			// just in case
			[listener ignore];
		} else {
			// Ignore WebNavigationTypeFormSubmitted, WebNavigationTypeFormResubmitted.
			[listener ignore];
		}
	}
}

/*
 * Manage contextual menu in helpWebView
 * Ignore "Reload", "Open Link", "Open Link in new Window", "Download link" etc.
 */
- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{

	NSMutableArray *webViewMenuItems = [[defaultMenuItems mutableCopy] autorelease];
	
	if (webViewMenuItems)
	{
		// Remove all needless default menu items 
		NSEnumerator *itemEnumerator = [defaultMenuItems objectEnumerator];
		NSMenuItem *menuItem = nil;
		while (menuItem = [itemEnumerator nextObject])
		{
			int tag = [menuItem tag];
			switch (tag)
			{
				case 2000: // WebMenuItemTagOpenLink
				case WebMenuItemTagOpenLinkInNewWindow:
				case WebMenuItemTagDownloadLinkToDisk:
				case WebMenuItemTagOpenImageInNewWindow:
				case WebMenuItemTagDownloadImageToDisk:
				case WebMenuItemTagCopyImageToClipboard:
				case WebMenuItemTagOpenFrameInNewWindow:
				case WebMenuItemTagStop:
				case WebMenuItemTagReload:
				case WebMenuItemTagCut:
				case WebMenuItemTagPaste:
				case WebMenuItemTagSpellingGuess:
				case WebMenuItemTagNoGuessesFound:
				case WebMenuItemTagIgnoreSpelling:
				case WebMenuItemTagLearnSpelling:
				case WebMenuItemTagOther:
				case WebMenuItemTagOpenWithDefaultApplication:
				[webViewMenuItems removeObjectIdenticalTo: menuItem];
				break;
			}
		}
	}

	// Add two menu items for a selection if no link is given
	if(webViewMenuItems 
		&& [[element objectForKey:@"WebElementIsSelected"] boolValue] 
		&& ![[element objectForKey:@"WebElementLinkIsLive"] boolValue])
	{

		NSMenuItem *searchInMySQL;
		NSMenuItem *searchInMySQLonline;

		[webViewMenuItems insertObject:[NSMenuItem separatorItem] atIndex:0];

		searchInMySQLonline = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Search in MySQL Documentation", @"Search in MySQL Documentation") action:@selector(searchInDocForWebViewSelection:) keyEquivalent:@""];
		[searchInMySQLonline setEnabled:YES];
		[searchInMySQLonline setTarget:self];
		[webViewMenuItems insertObject:searchInMySQLonline atIndex:0];
		[searchInMySQLonline release];

		searchInMySQL = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Search in MySQL Help", @"Search in MySQL Help") action:@selector(showHelpForWebViewSelection:) keyEquivalent:@""];
		[searchInMySQL setEnabled:YES];
		[searchInMySQL setTarget:self];
		[webViewMenuItems insertObject:searchInMySQL atIndex:0];
		[searchInMySQL release];

	}

	return webViewMenuItems;

}

#pragma mark -
#pragma mark Other

/*
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	if ([keyPath isEqualToString:@"DisplayTableViewVerticalGridlines"]) {
        [customQueryView setGridStyleMask:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	}
}

#pragma mark -

// Last but not least
- (id)init;
{
	if ((self = [super init])) {
		
		usedQuery = [[NSString stringWithString:@""] retain];

		sortField = nil;
		isDesc = NO;

		// init helpHTMLTemplate
		NSError *error;
		
		helpHTMLTemplate = [[NSString alloc]
							initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"sequel-pro-mysql-help-template" ofType:@"html"]
							encoding:NSUTF8StringEncoding
							error:&error];
		
		// an error occurred while reading
		if (helpHTMLTemplate == nil) {
			NSLog(@"%@", [NSString stringWithFormat:@"Error reading “sequel-pro-mysql-help-template.html”!<br>%@", [error localizedFailureReason]]);
			NSBeep();
		}
		
		// init search history
		[helpWebView setMaintainsBackForwardList:YES];
		[[helpWebView backForwardList] setCapacity:20];
		
		// init tableView's data source
		fullResult = [[NSMutableArray alloc] init];

	}

	return self;
}

- (void)awakeFromNib
{
	// Set the structure and index view's vertical gridlines if required
	[customQueryView setGridStyleMask:([prefs boolForKey:@"DisplayTableViewVerticalGridlines"]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
}

- (void)dealloc
{
	[queryFavorites release];
	[usedQuery release];
	[fullResult release];
	if (sortField) [sortField release];
	[super dealloc];
}
	
@end
