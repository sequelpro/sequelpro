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
#import "SPTooltip.h"
#import "SPQueryFavoriteManager.h"
#import "SPQueryController.h"
#import "SPConstants.h"
#import "SPEncodingPopupAccessory.h"
#import "SPDataStorage.h"
#import "SPAlertSheets.h"
#import "SPMainThreadTrampoline.h"

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

	// Prevent multiple runs by holding the keys down
	if ([tableDocumentInstance isWorking]) return;

	// Fixes bug in key equivalents.
	if ([[NSApp currentEvent] type] == NSKeyUp) {
		return;
	}

	// Retrieve the custom query string and split it into separate SQL queries
	queryParser = [[SPSQLParser alloc] initWithString:[textView string]];
	[queryParser setDelimiterSupport:YES];
	queries = [queryParser splitStringByCharacter:';'];
	[queryParser release];

	oldThreadedQueryRange = [textView selectedRange];
	// Unselect a selection if given to avoid interferring with error highlighting
	[textView setSelectedRange:NSMakeRange(oldThreadedQueryRange.location, 0)];
	// Reset queryStartPosition
	queryStartPosition = 0;

	reloadingExistingResult = NO;
	[self clearResultViewDetailsToRestore];

	// Remember query start position for error highlighting
	queryTextViewStartPosition = 0;

	[self performQueries:queries withCallback:@selector(runAllQueriesCallback)];
}

- (void) runAllQueriesCallback
{

	// If no error was selected, reconstruct a given selection.  This
	// may no longer be valid if the query text has changed in the
	// meantime, so error-checking is required.
	if (oldThreadedQueryRange.location + oldThreadedQueryRange.length <= [[textView string] length]) {

		if ([textView selectedRange].length == 0)
			[textView setSelectedRange:oldThreadedQueryRange];

		// Invoke textStorageDidProcessEditing: for syntax highlighting and auto-uppercase
		NSRange oldRange = [textView selectedRange];
		[textView setSelectedRange:NSMakeRange(oldThreadedQueryRange.location,0)];
		[textView insertText:@""];
		[textView setSelectedRange:oldRange];
	}
}

/*
 * Depending on selection, run either the query containing the selection caret (if the caret is
 * at a single point within the text view), or run the selected text (if a text range is selected).
 */
- (IBAction)runSelectedQueries:(id)sender
{
	NSArray *queries;
	NSString *query = nil;
	NSRange selectedRange = [textView selectedRange];
	SPSQLParser *queryParser;

	// Prevent multiple runs by holding the keys down
	if ([tableDocumentInstance isWorking]) return;

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

		// Remember query start position for error highlighting
		queryTextViewStartPosition = currentQueryRange.location;

	// Otherwise, run the selected text.
	} else {
		queryParser = [[SPSQLParser alloc] initWithString:[[textView string] substringWithRange:selectedRange]];
		[queryParser setDelimiterSupport:YES];
		queries = [queryParser splitStringByCharacter:';'];
		[queryParser release];

		// Remember query start position for error highlighting
		queryTextViewStartPosition = selectedRange.location;
	}

	// Invoke textStorageDidProcessEditing: for syntax highlighting and auto-uppercase
	// and preserve the selection
	[textView setSelectedRange:NSMakeRange(selectedRange.location, 0)];
	[textView insertText:@""];

	// Inserting empty text may have cancelled a partial accent - range check before
	// restoring the selection.
	if (selectedRange.location > [[textView string] length]) selectedRange.location = [[textView string] length];
	[textView setSelectedRange:selectedRange];

	reloadingExistingResult = NO;
	[self clearResultViewDetailsToRestore];

	[self performQueries:queries withCallback:NULL];
}

/**
 * Insert the choosen favorite query in the query textView or save query to favorites or opens window to edit favorites
 */
- (IBAction)chooseQueryFavorite:(id)sender
{
	if ([queryFavoritesButton indexOfSelectedItem] == 1) {
		
		// This should never evaluate to true as we are now performing menu validation, meaning the 'Save Query to Favorites' menu item will
		// only be enabled if the query text view has at least one character present.
		if ([[textView string] isEqualToString:@""]) {
			SPBeginAlertSheet(NSLocalizedString(@"Empty query", @"empty query message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [tableDocumentInstance parentWindow], self, nil, nil,
							  NSLocalizedString(@"Cannot save an empty query.", @"empty query informative message"));
			return;
		}

		if ([tableDocumentInstance isUntitled]) [saveQueryFavoriteGlobal setState:NSOnState];
		[NSApp beginSheet:queryFavoritesSheet 
		   modalForWindow:[tableDocumentInstance parentWindow] 
			modalDelegate:self 
		   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
			  contextInfo:@"addSelectionToNewQueryFavorite"];

	}
	if ([queryFavoritesButton indexOfSelectedItem] == 2) {
		
		// This should never evaluate to true as we are now performing menu validation, meaning the 'Save Query to Favorites' menu item will
		// only be enabled if the query text view has at least one character present.
		if ([[textView string] isEqualToString:@""]) {
			SPBeginAlertSheet(NSLocalizedString(@"Empty query", @"empty query message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [tableDocumentInstance parentWindow], self, nil, nil,
							  NSLocalizedString(@"Cannot save an empty query.", @"empty query informative message"));
			return;
		}

		if ([tableDocumentInstance isUntitled]) [saveQueryFavoriteGlobal setState:NSOnState];
		[NSApp beginSheet:queryFavoritesSheet 
		   modalForWindow:[tableDocumentInstance parentWindow] 
			modalDelegate:self 
		   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
			  contextInfo:@"addAllToNewQueryFavorite"];
	}
	else if ([queryFavoritesButton indexOfSelectedItem] == 3) {

		// init query favorites controller
		[prefs synchronize];
		if(favoritesManager) [favoritesManager release];
		favoritesManager = [[SPQueryFavoriteManager alloc] initWithDelegate:self];

		// Open query favorite manager
		[NSApp beginSheet:[favoritesManager window] 
		   modalForWindow:[tableDocumentInstance parentWindow] 
			modalDelegate:favoritesManager
		   didEndSelector:nil 
			  contextInfo:nil];
	} 
	else if ([queryFavoritesButton indexOfSelectedItem] > 5) {
		// Choose favorite
		BOOL replaceContent = [prefs boolForKey:SPQueryFavoriteReplacesContent];

		if([[NSApp currentEvent] modifierFlags] & (NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask))
			replaceContent = !replaceContent;
		if(replaceContent) {
			[textView setSelectedRange:NSMakeRange(0,[[textView string] length])];
			[textView breakUndoCoalescing];
			[textView insertText:@""];
		}

		// The actual query strings have been already stored as tooltip
		[textView insertAsSnippet:[[queryFavoritesButton selectedItem] toolTip] atRange:NSMakeRange([textView selectedRange].location, 0)];
	}
}

/*
 * Insert the choosen history query in the query textView
 */
- (IBAction)chooseQueryHistory:(id)sender
{

	[prefs synchronize];

	// Choose history item
	if ([queryHistoryButton indexOfSelectedItem] > 6) {

		BOOL replaceContent = [prefs boolForKey:SPQueryHistoryReplacesContent];
		[textView breakUndoCoalescing];
		if([[NSApp currentEvent] modifierFlags] & (NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask))
			replaceContent = !replaceContent;
		if(replaceContent)
			[textView setSelectedRange:NSMakeRange(0,[[textView string] length])];

		[textView insertText:[[[SPQueryController sharedQueryController] historyForFileURL:[tableDocumentInstance fileURL]] objectAtIndex:[queryHistoryButton indexOfSelectedItem]-7]];
	}
}

/*
 * Closes the sheet
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

/*
 * Perform simple actions (which don't require their own method), triggered by selecting the appropriate menu item
 * in the "gear" action menu displayed beneath the cusotm query view.
 */
- (IBAction)gearMenuItemSelected:(id)sender
{

	if ( sender == previousHistoryMenuItem ) {
		NSInteger numberOfHistoryItems = [[SPQueryController sharedQueryController] numberOfHistoryItemsForFileURL:[tableDocumentInstance fileURL]];
		currentHistoryOffsetIndex++;
		if ( numberOfHistoryItems > 0 && currentHistoryOffsetIndex < numberOfHistoryItems && currentHistoryOffsetIndex >= 0) {
			historyItemWasJustInserted = YES;
			[textView breakUndoCoalescing];
			NSString *historyString = [[[SPQueryController sharedQueryController] historyForFileURL:[tableDocumentInstance fileURL]] objectAtIndex:currentHistoryOffsetIndex];
			NSRange rangeOfInsertedString = NSMakeRange([textView selectedRange].location, [historyString length]);
			[textView insertText:historyString];
			[textView setSelectedRange:rangeOfInsertedString];
		} else {
			currentHistoryOffsetIndex--;
			NSBeep();
		}
		historyItemWasJustInserted = NO;
	}

	if ( sender == nextHistoryMenuItem ) {
		NSInteger numberOfHistoryItems = [[SPQueryController sharedQueryController] numberOfHistoryItemsForFileURL:[tableDocumentInstance fileURL]];
		currentHistoryOffsetIndex--;
		if ( numberOfHistoryItems > 0 && currentHistoryOffsetIndex < numberOfHistoryItems && currentHistoryOffsetIndex >= 0) {
			historyItemWasJustInserted = YES;
			[textView breakUndoCoalescing];
			NSString *historyString = [[[SPQueryController sharedQueryController] historyForFileURL:[tableDocumentInstance fileURL]] objectAtIndex:currentHistoryOffsetIndex];
			NSRange rangeOfInsertedString = NSMakeRange([textView selectedRange].location, [historyString length]);
			[textView insertText:historyString];
			[textView setSelectedRange:rangeOfInsertedString];
		} else {
			currentHistoryOffsetIndex++;
			NSBeep();
		}
		historyItemWasJustInserted = NO;
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
		if([[NSApp currentEvent] modifierFlags] & (NSControlKeyMask))
			[textView doCompletionByUsingSpellChecker:NO fuzzyMode:YES autoCompleteMode:NO];
		else
			[textView doCompletionByUsingSpellChecker:NO fuzzyMode:NO autoCompleteMode:NO];
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
		[prefs setBool:enableAutoindent forKey:SPCustomQueryAutoIndent];
		[prefs synchronize];
		[autoindentMenuItem setState:enableAutoindent?NSOnState:NSOffState];
		[textView setAutoindent:enableAutoindent];
	}

	// "Auto-pair characters" toggle
	if (sender == autopairMenuItem) {
		BOOL enableAutopair = !([autopairMenuItem state] == NSOffState);
		[prefs setBool:enableAutopair forKey:SPCustomQueryAutoPairCharacters];
		[prefs synchronize];
		[autopairMenuItem setState:enableAutopair?NSOnState:NSOffState];
		[textView setAutopair:enableAutopair];
	}

	// "Auto-help" toggle
	if (sender == autohelpMenuItem) {
		BOOL enableAutohelp = !([autohelpMenuItem state] == NSOffState);
		[prefs setBool:enableAutohelp forKey:SPCustomQueryUpdateAutoHelp];
		[prefs synchronize];
		[autohelpMenuItem setState:enableAutohelp?NSOnState:NSOffState];
		[textView setAutohelp:enableAutohelp];
	}

	// "Auto-uppercase keywords" toggle
	if (sender == autouppercaseKeywordsMenuItem) {
		BOOL enableAutouppercaseKeywords = !([autouppercaseKeywordsMenuItem state] == NSOffState);
		[prefs setBool:enableAutouppercaseKeywords forKey:SPCustomQueryAutoUppercaseKeywords];
		[prefs synchronize];
		[autouppercaseKeywordsMenuItem setState:enableAutouppercaseKeywords?NSOnState:NSOffState];
		[textView setAutouppercaseKeywords:enableAutouppercaseKeywords];
	}
}

- (IBAction)saveQueryHistory:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setRequiredFileType:SPFileExtensionSQL];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:YES];
	[panel setCanSelectHiddenExtension:YES];
	[panel setCanCreateDirectories:YES];

	[panel setAccessoryView:[SPEncodingPopupAccessory encodingAccessory:[prefs integerForKey:SPLastSQLFileEncoding] includeDefaultEntry:NO encodingPopUp:&encodingPopUp]];
	
	[encodingPopUp setEnabled:YES];
	
	[panel beginSheetForDirectory:nil file:@"history" modalForWindow:[tableDocumentInstance parentWindow] modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:@"saveHistory"];
}

- (IBAction)copyQueryHistory:(id)sender
{

	NSPasteboard *pb = [NSPasteboard generalPasteboard];

	[pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
	[pb setString:[self buildHistoryString] forType:NSStringPboardType];

}

// "Clear History" menu item - clear query history
- (IBAction)clearQueryHistory:(id)sender
{

	NSString *infoString;

	if ([tableDocumentInstance isUntitled])
		infoString = NSLocalizedString(@"Are you sure you want to clear the global history list? This action cannot be undone.", @"clear global history list informative message");
	else
		infoString = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to clear the history list for “%@”? This action cannot be undone.", @"clear history list for “%@” informative message"), [tableDocumentInstance displayName]];

	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Clear History?", @"clear history message") 
									 defaultButton:NSLocalizedString(@"Clear", @"clear button")
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
									   otherButton:nil
						 informativeTextWithFormat:infoString];

	[alert setAlertStyle:NSCriticalAlertStyle];
	
	NSArray *buttons = [alert buttons];
	
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"r"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
	
	[alert beginSheetModalForWindow:[tableDocumentInstance parentWindow] 
					  modalDelegate:self 
					 didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) 
						contextInfo:@"clearHistory"];

}

/*
 * Set font panel's valid modes
 */
- (NSUInteger)validModesForFontPanel:(NSFontPanel *)fontPanel
{
	return (NSFontPanelSizeModeMask|NSFontPanelCollectionModeMask);
}

#pragma mark -
#pragma mark Query actions

/*
 * Performs the mysql-query given by the user
 * sets the tableView columns corresponding to the mysql-result
 */
- (void)performQueries:(NSArray *)queries withCallback:(SEL)customQueryCallbackMethod;
{
	NSString *taskString;
	if ([queries count] > 1) {
		taskString = [NSString stringWithFormat:NSLocalizedString(@"Running query %i of %lu...", @"Running multiple queries string"), 1, (unsigned long)[queries count]];
	} else {
		taskString = NSLocalizedString(@"Running query...", @"Running single query string");
	}
	[tableDocumentInstance startTaskWithDescription:taskString];
	[errorText setStringValue:taskString];
	[affectedRowsText setStringValue:@""];

	NSValue *encodedCallbackMethod = nil;
	if (customQueryCallbackMethod)
		encodedCallbackMethod = [NSValue valueWithBytes:&customQueryCallbackMethod objCType:@encode(SEL)];
	NSDictionary *taskArguments = [NSDictionary dictionaryWithObjectsAndKeys:queries, @"queries", encodedCallbackMethod, @"callback", nil];
	
	// If a helper thread is already running, execute inline - otherwise detach a new thread for the queries
	if ([NSThread isMainThread]) {
		[NSThread detachNewThreadSelector:@selector(performQueriesTask:) toTarget:self withObject:taskArguments];
	} else {
		[self performQueriesTask:taskArguments];
	}
}

- (void)performQueriesTask:(NSDictionary *)taskArguments
{
	NSAutoreleasePool	*queryRunningPool = [[NSAutoreleasePool alloc] init];
	NSArray				*queries	= [taskArguments objectForKey:@"queries"];
	MCPStreamingResult	*streamingResult  = nil;
	NSMutableString		*errors     = [NSMutableString string];
	SEL					callbackMethod = NULL;
	NSString			*taskButtonString;
	
	NSInteger i, totalQueriesRun = 0, totalAffectedRows = 0;
	double executionTime = 0;
	NSInteger firstErrorOccuredInQuery = -1;
	BOOL suppressErrorSheet = NO;
	BOOL tableListNeedsReload = NO;
	BOOL databaseWasChanged = NO;
	// BOOL queriesSeparatedByDelimiter = NO;
	
	NSCharacterSet *whitespaceAndNewlineSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	[tableDocumentInstance setQueryMode:SPCustomQueryQueryMode];

	// Notify listeners that a query has started
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:tableDocumentInstance];

	// Start the notification timer to allow notifications to be shown even if frontmost for long queries
	[[SPGrowlController sharedGrowlController] setVisibilityForNotificationName:@"Query Finished"];

	// Reset the current table view as necessary to avoid redraw and reload issues.
	// Restore the view position to the top left to be within the results for all datasets.
	if(editedRow == -1) {
		[[customQueryView onMainThread] scrollRowToVisible:0];
		[[customQueryView onMainThread] scrollColumnToVisible:0];
	}

	// Remove all the columns if not reloading the table
	if(!reloadingExistingResult) {
		if (cqColumnDefinition) [cqColumnDefinition release], cqColumnDefinition = nil;
		[[self onMainThread] updateTableView];
	}

	// Disable automatic query retries on failure for the custom queries
	[mySQLConnection setAllowQueryRetries:NO];

	NSUInteger queryCount = [queries count];
	NSMutableArray *tempQueries = [NSMutableArray arrayWithCapacity:queryCount];

	// Enable task cancellation
	if (queryCount > 1)
		taskButtonString = NSLocalizedString(@"Stop queries", @"Stop queries string");
	else
		taskButtonString = NSLocalizedString(@"Stop query", @"Stop query string");
	[tableDocumentInstance enableTaskCancellationWithTitle:taskButtonString callbackObject:nil callbackFunction:NULL];

	// Perform the supplied queries in series
	for ( i = 0 ; i < queryCount ; i++ ) {

		if (i > 0) {
			NSString *taskString = [NSString stringWithFormat:NSLocalizedString(@"Running query %ld of %lu...", @"Running multiple queries string"), (long)(i+1), (unsigned long)queryCount];
			[tableDocumentInstance setTaskDescription:taskString];
			[[errorText onMainThread] setStringValue:taskString];
		}

		NSString *query = [NSArrayObjectAtIndex(queries, i) stringByTrimmingCharactersInSet:whitespaceAndNewlineSet];

		// Don't run blank queries, or queries which only contain whitespace.
		if (![query length])
			continue;

		// store trimmed queries for usedQueries and history
		[tempQueries addObject:query];

		// Run the query, timing execution (note this also includes network and overhead)
		streamingResult = [[mySQLConnection streamingQueryString:query] retain];
		executionTime += [mySQLConnection lastQueryExecutionTime];
		totalQueriesRun++;

		// If this is the last query, retrieve and store the result; otherwise,
		// discard the result without fully loading.
		if (totalQueriesRun == queryCount || [mySQLConnection queryCancelled]) {

			// Retrieve and cache the column definitions for the result array
			if (cqColumnDefinition) [cqColumnDefinition release];
			cqColumnDefinition = [[streamingResult fetchResultFieldsStructure] retain];

			if(!reloadingExistingResult) {
				[[self onMainThread] updateTableView];
			}

			[self processResultIntoDataStorage:streamingResult];
		} else {
			[streamingResult cancelResultLoad];
		}

		// Record any affected rows
		if ( [mySQLConnection affectedRows] != -1 )
			totalAffectedRows += [mySQLConnection affectedRows];
		else if ( [streamingResult numOfRows] )
			totalAffectedRows += [streamingResult numOfRows];

		[streamingResult release];

		// Store any error messages
		if ([mySQLConnection queryErrored] || [mySQLConnection queryCancelled]) {

			NSString *errorString;
			if ([mySQLConnection queryCancelled]) {
				if ([mySQLConnection queryCancellationUsedReconnect])
					errorString = NSLocalizedString(@"Query cancelled.  Please note that to cancel the query the connection had to be reset; transactions and connection variables were reset.", @"Query cancel by resetting connection error");
				else
					errorString = NSLocalizedString(@"Query cancelled.", @"Query cancelled error");
			} else {
				errorString = [mySQLConnection getLastErrorMessage];
			}

			// If the query errored, append error to the error log for display at the end
			if ( queryCount > 1 ) {
				if(firstErrorOccuredInQuery == -1)
					firstErrorOccuredInQuery = i+1;

				if(!suppressErrorSheet)
				{
					// Update error text for the user
					[errors appendString:[NSString stringWithFormat:NSLocalizedString(@"[ERROR in query %ld] %@\n", @"error text when multiple custom query failed"),
										(long)(i+1),
										errorString]];
					[[errorText onMainThread] setStringValue:errors];

					// ask the user to continue after detecting an error
					if (![mySQLConnection queryCancelled]) {
						NSAlert *alert = [[[NSAlert alloc] init] autorelease];
						[alert addButtonWithTitle:NSLocalizedString(@"Run All", @"run all button")];
						[alert addButtonWithTitle:NSLocalizedString(@"Continue", @"continue button")];
						[alert addButtonWithTitle:NSLocalizedString(@"Stop", @"stop button")];
						[alert setMessageText:NSLocalizedString(@"MySQL Error", @"mysql error message")];
						[alert setInformativeText:[mySQLConnection getLastErrorMessage]];
						[alert setAlertStyle:NSWarningAlertStyle];
						NSInteger choice = [[alert onMainThread] runModal];
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
					}
				} else {
					[errors appendString:[NSString stringWithFormat:NSLocalizedString(@"[ERROR in query %ld] %@\n", @"error text when multiple custom query failed"),
											(long)(i+1),
											errorString]];
				}
			} else {
				[errors setString:errorString];
			}
		} else {
			// Check if table/db list needs an update
			// The regex is a compromise between speed and usefullness. TODO: further improvements are needed
			if(!tableListNeedsReload && [query isMatchedByRegex:@"(?i)^\\s*\\b(create|alter|drop|rename)\\b\\s+."])
				tableListNeedsReload = YES;
			if(!databaseWasChanged && [query isMatchedByRegex:@"(?i)^\\s*\\b(use|drop\\s+database|drop\\s+schema)\\b\\s+."])
				databaseWasChanged = YES;
		}
		// If the query was cancelled, end all queries.
		if ([mySQLConnection queryCancelled]) break;
	}

	// Reload table list if at least one query began with drop, alter, rename, or create
	if(tableListNeedsReload || databaseWasChanged) {
		// Build database pulldown menu
		[tableDocumentInstance setDatabases:self];

		if (databaseWasChanged)
			// Reset the current database
			[tableDocumentInstance refreshCurrentDatabase];

		// Reload table list
		[tablesListInstance updateTables:self];

	}
	
	if(usedQuery)
		[usedQuery release];
	
	// if(!queriesSeparatedByDelimiter) // TODO: How to combine queries delimited by DELIMITER?
	usedQuery = [[NSString stringWithString:[tempQueries componentsJoinedByString:@";\n"]] retain];
	
	lastExecutedQuery = [[tempQueries lastObject] retain];
	
	// Perform empty query if no query is given
	if ( !queryCount ) {
		streamingResult = [mySQLConnection streamingQueryString:@""];
		[streamingResult cancelResultLoad];
		[errors setString:[mySQLConnection getLastErrorMessage]];
	}
	
	// add query to history
	if(!reloadingExistingResult && [usedQuery length])
		[self performSelectorOnMainThread:@selector(addHistoryEntry:) withObject:usedQuery waitUntilDone:NO];

	// Update status/errors text
	NSDictionary *statusDetails = [NSDictionary dictionaryWithObjectsAndKeys:
									errors, @"errorString",
									[NSNumber numberWithInteger:firstErrorOccuredInQuery], @"firstErrorQueryNumber",
									nil];
	[self performSelectorOnMainThread:@selector(updateStatusInterfaceWithDetails:) withObject:statusDetails waitUntilDone:YES];
	
	// Set up the status string
	if ( [mySQLConnection queryCancelled] ) {
		if (totalQueriesRun > 1) {
			[[affectedRowsText onMainThread] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Cancelled in query %ld, after %@", @"text showing multiple queries were cancelled"),
                                              (long)totalQueriesRun,
                                              [NSString stringForTimeInterval:executionTime]
                                              ]];
		} else {
			[[affectedRowsText onMainThread] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Cancelled after %@", @"text showing a query was cancelled"),
                                              [NSString stringForTimeInterval:executionTime]
                                              ]];
		}
	} else if ( totalQueriesRun > 1 ) {
		if (totalAffectedRows==1) {
			[[affectedRowsText onMainThread] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"1 row affected in total, by %ld queries taking %@", @"text showing one row has been affected by multiple queries"),
                                              (long)totalQueriesRun,
                                              [NSString stringForTimeInterval:executionTime]
                                              ]];

		} else {
			[[affectedRowsText onMainThread] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%ld rows affected in total, by %ld queries taking %@", @"text showing how many rows have been affected by multiple queries"),
                                              (long)totalAffectedRows,
                                              (long)totalQueriesRun,
                                              [NSString stringForTimeInterval:executionTime]
                                              ]];

		}
	} else {
		if (totalAffectedRows==1) {
			[[affectedRowsText onMainThread] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"1 row affected, taking %@", @"text showing one row has been affected by a single query"),
                                              [NSString stringForTimeInterval:executionTime]
                                              ]];
		} else {
			[[affectedRowsText onMainThread] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%ld rows affected, taking %@", @"text showing how many rows have been affected by a single query"),
                                              (long)totalAffectedRows,
                                              [NSString stringForTimeInterval:executionTime]
                                              ]];

		}
	}

	// Restore automatic query retries
	[mySQLConnection setAllowQueryRetries:YES];

	[tableDocumentInstance setQueryMode:SPInterfaceQueryMode];
	
	// If no results were returned, redraw the empty table and post notifications before returning.
	if ( !resultDataCount ) {
		[customQueryView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];

		// Notify any listeners that the query has completed
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];

		// Perform the Growl notification for query completion
		[[SPGrowlController sharedGrowlController] notifyWithTitle:@"Query Finished"
                                                       description:[NSString stringWithFormat:NSLocalizedString(@"%@",@"description for query finished growl notification"), [errorText stringValue]] 
														  document:tableDocumentInstance
                                                  notificationName:@"Query Finished"];

		// Set up the callback if present
		if ([taskArguments objectForKey:@"callback"]) {
			[[taskArguments objectForKey:@"callback"] getValue:&callbackMethod];
			[self performSelectorOnMainThread:callbackMethod withObject:nil waitUntilDone:NO];
		}

		[tableDocumentInstance endTask];
		[queryRunningPool release];

		return;
	}

	// Find result table name for copying as SQL INSERT.
	// If more than one table name is found set resultTableName to nil.
	// resultTableName will be set to the original table name (not defined via AS) provided by mysql return
	// and the resultTableName can differ due to case-sensitive/insensitive settings!.
	NSString *resultTableName = [[cqColumnDefinition objectAtIndex:0] objectForKey:@"org_table"];
	for(id field in cqColumnDefinition) {
		if(![[field objectForKey:@"org_table"] isEqualToString:resultTableName]) {
			resultTableName = nil;
			break;
		}
	}

	[customQueryView reloadData];

	// Restore the result view origin if appropriate
	if (!NSEqualRects(selectionViewportToRestore, NSZeroRect)) {

		// Scroll the viewport to the saved location
		selectionViewportToRestore.size = [customQueryView visibleRect].size;
		[customQueryView scrollRectToVisible:selectionViewportToRestore];
	}

	// Restore selection indexes if appropriate
	if (selectionIndexToRestore) {
		BOOL previousTableRowsSelectable = tableRowsSelectable;
		tableRowsSelectable = YES;
		[customQueryView selectRowIndexes:selectionIndexToRestore byExtendingSelection:NO];
		tableRowsSelectable = previousTableRowsSelectable;
	}

	// Init copyTable with necessary information for copying selected rows as SQL INSERT
	[customQueryView setTableInstance:self withTableData:resultData withColumns:cqColumnDefinition withTableName:resultTableName withConnection:mySQLConnection];

	//query finished
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];
	
	// Query finished Growl notification    
    [[SPGrowlController sharedGrowlController] notifyWithTitle:@"Query Finished"
                                                   description:[NSString stringWithFormat:NSLocalizedString(@"%@",@"description for query finished growl notification"), [errorText stringValue]] 
													  document:tableDocumentInstance
                                              notificationName:@"Query Finished"];

	// Set up the callback if present
	if ([taskArguments objectForKey:@"callback"]) {
		[[taskArguments objectForKey:@"callback"] getValue:&callbackMethod];
		[self performSelectorOnMainThread:callbackMethod withObject:nil waitUntilDone:YES];
	}

	[tableDocumentInstance endTask];
	[queryRunningPool release];
}

/*
 * Processes a supplied streaming result set, loading it into the data array.
 */
- (void)processResultIntoDataStorage:(MCPStreamingResult *)theResult
{
	NSArray *tempRow;
	NSUInteger rowsProcessed = 0;
	NSUInteger nextTableDisplayBoundary = 50;
	NSAutoreleasePool *dataLoadingPool;
	BOOL tableViewRedrawn = NO;

	// Remove all items from the table
	resultDataCount = 0;
	[customQueryView performSelectorOnMainThread:@selector(noteNumberOfRowsChanged) withObject:nil waitUntilDone:YES];
	pthread_mutex_lock(&resultDataLock);
	[resultData removeAllRows];
	pthread_mutex_unlock(&resultDataLock);

	// Set the column count on the data store
	[resultData setColumnCount:[theResult numOfFields]];

	// Set up an autorelease pool for row processing
	dataLoadingPool = [[NSAutoreleasePool alloc] init];

	// Loop through the result rows as they become available
	while (tempRow = [theResult fetchNextRowAsArray]) {

		pthread_mutex_lock(&resultDataLock);
		SPDataStorageAddRow(resultData, tempRow);
		resultDataCount++;
		pthread_mutex_unlock(&resultDataLock);

		// Update the count of rows processed
		rowsProcessed++;

		// Update the table view with new results every now and then
		if (rowsProcessed > nextTableDisplayBoundary) {
			[customQueryView performSelectorOnMainThread:@selector(noteNumberOfRowsChanged) withObject:nil waitUntilDone:NO];
			if (!tableViewRedrawn) {
				[customQueryView performSelectorOnMainThread:@selector(displayIfNeeded) withObject:nil waitUntilDone:NO];
				tableViewRedrawn = YES;
			}
			nextTableDisplayBoundary *= 2;
		}

		// Drain and reset the autorelease pool every ~1024 rows
		if (!(rowsProcessed % 1024)) {
			[dataLoadingPool drain];
			dataLoadingPool = [[NSAutoreleasePool alloc] init];
		}
	}

	[customQueryView performSelectorOnMainThread:@selector(noteNumberOfRowsChanged) withObject:nil waitUntilDone:NO];
	[customQueryView setNeedsDisplay:YES];
	
	// Clean up the autorelease pool
	[dataLoadingPool drain];
}

/*
 * Retrieve the range of the query at a position specified 
 * within the custom query text view.
 */
- (NSRange)queryRangeAtPosition:(NSUInteger)position lookBehind:(BOOL *)doLookBehind
{
	SPSQLParser *customQueryParser;
	NSArray     *queries;
	NSString    *query = nil;
	NSRange     queryRange;
	
	NSUInteger i, j, queryPosition = 0;
	NSUInteger queryCount;

	NSCharacterSet *whitespaceAndNewlineSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSCharacterSet *whitespaceSet           = [NSCharacterSet whitespaceCharacterSet];

	// If the supplied position is negative or beyond the end of the string, return nil.
	if (position < 0 || position > [[textView string] length])
		return NSMakeRange(NSNotFound, 0);

	// Split the current text into ranges of queries
	// only if the textView was really changed, otherwise use the cache
	if([[textView textStorage] editedMask] != 0) {
		customQueryParser = [[SPSQLParser alloc] initWithString:[textView string]];
		[customQueryParser setDelimiterSupport:YES];
		queries = [[NSArray alloc] initWithArray:[customQueryParser splitStringIntoRangesByCharacter:';']];
		numberOfQueries = [queries count];
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
	NSInteger biasStart = [query rangeOfRegex:@"^\\s*"].length;
	NSInteger biasEnd   = [query rangeOfRegex:@"\\s*$"].length;
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
- (NSRange)queryTextRangeForQuery:(NSInteger)anIndex startPosition:(NSUInteger)position
{
	SPSQLParser *customQueryParser;
	NSArray *queries;

	// If the supplied position is negative or beyond the end of the string, return nil.
	if (position < 0 || position > [[textView string] length])
		return NSMakeRange(NSNotFound,0);

	// Split the current text into ranges of queries
	customQueryParser = [[SPSQLParser alloc] initWithString:[[textView string] substringWithRange:NSMakeRange(position, [[textView string] length]-position)]];
	[customQueryParser setDelimiterSupport:YES];
	queries = [[NSArray alloc] initWithArray:[customQueryParser splitStringIntoRangesByCharacter:';']];
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
	
	// Remove all leading and trailing white spaces
	NSInteger offset = [theQueryString rangeOfRegex:@"^(\\s*)"].length;
	theQueryRange.location += offset;
	theQueryRange.length -= offset;
	offset = [theQueryString rangeOfRegex:@"(\\s*)$"].length;
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
- (NSString *)queryAtPosition:(NSUInteger)position lookBehind:(BOOL *)doLookBehind
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
 * Add or remove "⁄*  *⁄" for each line in the current query
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
 * if the selection is in-line wrap selection into ⁄* block comments and
 * place the caret after ⁄* to allow to enter !xxxxxx e.g.
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

/*
 * Update the interface to reflect the query error state.
 * Should be performed on the main thread.
 */
- (void) updateStatusInterfaceWithDetails:(NSDictionary *)errorDetails
{
	NSString *errorsString = [errorDetails objectForKey:@"errorString"];
	NSInteger firstErrorOccuredInQuery = [[errorDetails objectForKey:@"firstErrorQueryNumber"] integerValue];

	// If errors occur, display them
	if ( [mySQLConnection queryCancelled] || ([errorsString length] && !queryIsTableSorter)) {
		// set the error text
		[errorText setStringValue:errorsString];

		// try to select the line x of the first error if error message with ID 1064 contains "at line x"
		// by capturing the last number of the error string
		NSRange errorLineNumberRange = [errorsString rangeOfRegex:@"([0-9]+)[^0-9]*$" options:RKLNoOptions inRange:NSMakeRange(0, [errorsString length]) capture:1L error:nil];

		// if error ID 1064 and a line number was found
		if([mySQLConnection getLastErrorID] == 1064 && errorLineNumberRange.length)
		{
			// Get the line number
			NSUInteger errorAtLine = [[errorsString substringWithRange:errorLineNumberRange] integerValue];
			NSUInteger lineOffset = [textView getLineNumberForCharacterIndex:[self queryTextRangeForQuery:firstErrorOccuredInQuery startPosition:queryStartPosition].location] - 1;

			// Check for near message
			NSRange errorNearMessageRange = [errorsString rangeOfRegex:@"[( ]'(.+)'[ -]" options:(RKLMultiline|RKLDotAll) inRange:NSMakeRange(0, [errorsString length]) capture:1L error:nil];
			if(errorNearMessageRange.length) // if a "near message" was found
			{
				NSUInteger bufferLength = [[textView string] length];

				NSRange bufferRange = NSMakeRange(0, bufferLength);

				// Build the range to search for nearMessage (beginning from queryStartPosition to try to avoid mismatching)
				NSRange theRange = NSMakeRange(queryStartPosition, bufferLength-queryStartPosition);
				theRange = NSIntersectionRange(bufferRange, theRange);

				// Get the range in textView of the near message
				NSRange textNearMessageRange = [[[textView string] substringWithRange:theRange] rangeOfString:[errorsString substringWithRange:errorNearMessageRange] options:NSLiteralSearch];

				// Correct the near message range relative to queryStartPosition
				textNearMessageRange = NSMakeRange(textNearMessageRange.location+queryStartPosition, textNearMessageRange.length);
				textNearMessageRange = NSIntersectionRange(bufferRange, textNearMessageRange);

				// Select the near message and scroll to it
				if(textNearMessageRange.length > 0) {
					[textView setSelectedRange:textNearMessageRange];
					[textView scrollRangeToVisible:textNearMessageRange];
				}
			} else {
				[textView selectLineNumber:errorAtLine+lineOffset ignoreLeadingNewLines:YES];
			}
		} else { // Select first erroneous query entirely
			
			NSRange queryRange;
			if(firstErrorOccuredInQuery == -1) // for current or previous query
			{
				BOOL isLookBehind = YES;
				queryRange = [self queryRangeAtPosition:[textView selectedRange].location lookBehind:&isLookBehind];
				if(queryRange.length)
					[textView setSelectedRange:queryRange];
			} else {
				// select the query for which the first error was detected
				queryRange = [self queryTextRangeForQuery:firstErrorOccuredInQuery startPosition:queryStartPosition];
				queryRange = NSIntersectionRange(NSMakeRange(0, [[textView string] length]), queryRange);
				[textView setSelectedRange:queryRange];
				[textView scrollRangeToVisible:queryRange];
			}
		}

	} else if ( [errorsString length] && queryIsTableSorter ) {
		[errorText setStringValue:NSLocalizedString(@"Couldn't sort column.", @"text shown if an error occured while sorting the result table")];
		NSBeep();
	} else {
		[errorText setStringValue:NSLocalizedString(@"There were no errors.", @"text shown when query was successfull")];
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
	NSInteger i;
	
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
	mySQLConnection = theConnection;
	currentQueryRanges = nil;

	// Set up the interface

	[customQueryView setVerticalMotionCanBeginDrag:NO];
	[autoindentMenuItem setState:([prefs boolForKey:SPCustomQueryAutoIndent]?NSOnState:NSOffState)];
	[autopairMenuItem setState:([prefs boolForKey:SPCustomQueryAutoPairCharacters]?NSOnState:NSOffState)];
	[autohelpMenuItem setState:([prefs boolForKey:SPCustomQueryUpdateAutoHelp]?NSOnState:NSOffState)];
	[autouppercaseKeywordsMenuItem setState:([prefs boolForKey:SPCustomQueryAutoUppercaseKeywords]?NSOnState:NSOffState)];

	if ( [[SPQueryController sharedQueryController] historyForFileURL:[tableDocumentInstance fileURL]] )
		[self performSelectorOnMainThread:@selector(historyItemsHaveBeenUpdated:) withObject:self waitUntilDone:YES];

	// Populate query favorites
	[self queryFavoritesHaveBeenUpdated:nil];
	
	// Disable runSelectionMenuItem in the gear menu
	[runSelectionMenuItem setEnabled:NO];
}

/*
 * Inserts the query in the textView and performs query
 */
- (void)doPerformQueryService:(NSString *)query
{
	[textView shouldChangeTextInRange:NSMakeRange(0, [[textView string] length]) replacementString:query];
	[textView setString:query];
	[textView didChangeText];
	[textView scrollRangeToVisible:NSMakeRange([query length], 0)];
	[self runAllQueries:self];
}
- (void)doPerformLoadQueryService:(NSString *)query
{
	[textView shouldChangeTextInRange:NSMakeRange(0, [[textView string] length]) replacementString:query];
	[textView setString:query];
	[textView didChangeText];
	[textView scrollRangeToVisible:NSMakeRange([query length], 0)];
}

- (NSString *)usedQuery
{
	return usedQuery;
}

#pragma mark -
#pragma mark Retrieving and setting table state

/**
 * Update the results table view state to match the current column definitions.
 * Should be called on the main thread.
 */
- (void) updateTableView
{
	NSArray *theColumns;
	NSTableColumn *theCol;

	// Remove all existing columns from the table
	theColumns = [customQueryView tableColumns];
	while ([theColumns count]) {
		[customQueryView removeTableColumn:NSArrayObjectAtIndex(theColumns, 0)];
	}

	// Update font size on the table
	NSFont *tableFont = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPGlobalResultTableFont]];
	[customQueryView setRowHeight:2.0f+NSSizeToCGSize([[NSString stringWithString:@"{ǞṶḹÜ∑zgyf"] sizeWithAttributes:[NSDictionary dictionaryWithObject:tableFont forKey:NSFontAttributeName]]).height];

	// If there are no table columns to add, return
	if (!cqColumnDefinition || ![cqColumnDefinition count]) return;

	// Add the new table columns
	for (NSDictionary *columnDefinition in cqColumnDefinition) {
		theCol = [[NSTableColumn alloc] initWithIdentifier:[columnDefinition objectForKey:@"datacolumnindex"]];
		[theCol setResizingMask:NSTableColumnUserResizingMask];
		[theCol setEditable:YES];
		SPTextAndLinkCell *dataCell = [[[SPTextAndLinkCell alloc] initTextCell:@""] autorelease];
		[dataCell setEditable:YES];
		[dataCell setFormatter:[[SPDataCellFormatter new] autorelease]];
		[dataCell setFont:tableFont];

		[dataCell setLineBreakMode:NSLineBreakByTruncatingTail];
		[theCol setDataCell:dataCell];
		[[theCol headerCell] setStringValue:[columnDefinition objectForKey:@"name"]];

		// Set the width of this column to saved value if exists and maps to a real column
		if ([columnDefinition objectForKey:@"org_name"] && [(NSString *)[columnDefinition objectForKey:@"org_name"] length]) {
			NSNumber *colWidth = [[[[prefs objectForKey:SPTableColumnWidths] objectForKey:[NSString stringWithFormat:@"%@@%@", [columnDefinition objectForKey:@"db"], [tableDocumentInstance host]]] objectForKey:[columnDefinition objectForKey:@"org_table"]] objectForKey:[columnDefinition objectForKey:@"org_name"]];
			if ( colWidth ) {
				[theCol setWidth:[colWidth doubleValue]];
			}
		}

		[customQueryView addTableColumn:theCol];
		[theCol release];
	}

	[customQueryView sizeLastColumnToFit];

	//tries to fix problem with last row (otherwise to small)
	//sets last column to width of the first if smaller than 30
	//problem not fixed for resizing window
	if ( [[customQueryView tableColumnWithIdentifier:[NSNumber numberWithInteger:[theColumns count]-1]] width] < 30 )
		[[customQueryView tableColumnWithIdentifier:[NSNumber numberWithInteger:[theColumns count]-1]]
				setWidth:[[customQueryView tableColumnWithIdentifier:[NSNumber numberWithInteger:0]] width]];
}

/**
 * Provide a getter for the custom query result table's selected rows index set
 */
- (NSIndexSet *) resultSelectedRowIndexes
{
	return [customQueryView selectedRowIndexes];
}

/**
 * Provide a getter for the custom query result table's current viewport
 */
- (NSRect) resultViewport
{
	return [customQueryView visibleRect];
}

/**
 * Set the selected row indexes to restore on next custom query result table load
 */
- (void) setResultSelectedRowIndexesToRestore:(NSIndexSet *)theIndexSet
{
	if (selectionIndexToRestore) [selectionIndexToRestore release], selectionIndexToRestore = nil;

	if (theIndexSet) selectionIndexToRestore = [[NSIndexSet alloc] initWithIndexSet:theIndexSet];
}

/**
 * Set the viewport to restore on next table load
 */
- (void) setResultViewportToRestore:(NSRect)theViewport
{
	selectionViewportToRestore = theViewport;
}

/**
 * Convenience method for storing all current settings for restoration
 */
- (void) storeCurrentResultViewForRestoration
{
	[self setResultSelectedRowIndexesToRestore:[self resultSelectedRowIndexes]];
	[self setResultViewportToRestore:[self resultViewport]];
}

/**
 * Convenience method for clearing any settings to restore
 */
- (void) clearResultViewDetailsToRestore
{
	[self setResultSelectedRowIndexesToRestore:nil];
	[self setResultViewportToRestore:NSZeroRect];
}

#pragma mark -
#pragma mark Field Editing

/*
 * Collect all columns for a given 'tableForColumn' table and
 * return a WHERE clause for identifying the field in quesyion.
 */
- (NSString *)argumentForRow:(NSUInteger)rowIndex ofTable:(NSString *)tableForColumn andDatabase:(NSString *)database
{
	NSArray *dataRow;
	NSDictionary *theRow;
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

	// --- Build WHERE clause ---
	dataRow = [resultData rowContentsAtIndex:rowIndex];

	// Get the primary key if there is one
	MCPResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW COLUMNS FROM %@.%@", 
		[database backtickQuotedString], [tableForColumn backtickQuotedString]]];
	[theResult setReturnDataAsStrings:YES];
	if ([theResult numOfRows]) [theResult dataSeek:0];
	NSInteger i;
	for ( i = 0 ; i < [theResult numOfRows] ; i++ ) {
		theRow = [theResult fetchRowAsDictionary];
		if ( [[theRow objectForKey:@"Key"] isEqualToString:@"PRI"] ) {
			for(field in columnsForFieldTableName) {
				id aValue = [dataRow objectAtIndex:[[field objectForKey:@"datacolumnindex"] integerValue]];
				if([[field objectForKey:@"org_name"] isEqualToString:[theRow objectForKey:@"Field"]]) {
					[fieldIDQueryStr appendFormat:@"%@.%@.%@ = %@)", 
						[database backtickQuotedString], 
						[tableForColumn backtickQuotedString], 
						[[theRow objectForKey:@"Field"] backtickQuotedString], 
						[aValue description]];
					return fieldIDQueryStr;
				}
			}
		}
	}
	
	// If there is no primary key, all found fields belonging to the same table are used in the argument
	for(field in columnsForFieldTableName) {
		id aValue = [dataRow objectAtIndex:[[field objectForKey:@"datacolumnindex"] integerValue]];
		if ([aValue isKindOfClass:[NSNull class]] || [aValue isNSNull]) {
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

/**
 * Returns the number of rows in the result set table view.
 */
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if (aTableView == customQueryView) {
		return (resultData == nil) ? 0 : resultDataCount;
	} 
	else {
		return 0;
	}
}

/**
 * This function changes the text color of text/blob fields whose content is NULL.
 */
- (void)tableView:(CMCopyTable *)aTableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex
{	
	if (aTableView == customQueryView) {

		// For NULL cell's display the user's NULL value placeholder in grey to easily distinguish it from other values 
		if ([cell respondsToSelector:@selector(setTextColor:)]) {
			NSUInteger columnIndex = [[aTableColumn identifier] integerValue];
			id theValue = nil;

			// While the table is being loaded, additional validation is required - data
			// locks must be used to avoid crashes, and indexes higher than the available
			// rows or columns may be requested.  Use gray to show loading in these cases.
			if (isWorking) {
				pthread_mutex_lock(&resultDataLock);
				if (rowIndex < resultDataCount && columnIndex < [resultData columnCount]) {
					theValue = SPDataStorageObjectAtRowAndColumn(resultData, rowIndex, columnIndex);
				}
				pthread_mutex_unlock(&resultDataLock);

				if (!theValue) {
					[cell setTextColor:[NSColor lightGrayColor]];
					return;
				}
			} else {
				theValue = SPDataStorageObjectAtRowAndColumn(resultData, rowIndex, columnIndex);
			}
			
			[cell setTextColor:[theValue isNSNull] ? [NSColor lightGrayColor] : [NSColor blackColor]];
		}
	}
}

/**
 * Returns the object for the requested column and row index.
 */
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if (aTableView == customQueryView) {
		NSUInteger columnIndex = [[aTableColumn identifier] integerValue];
		id theValue = nil;

		// While the table is being loaded, additional validation is required - data
		// locks must be used to avoid crashes, and indexes higher than the available
		// rows or columns may be requested.  Return "..." to indicate loading in these
		// cases.
		if (isWorking) {
			pthread_mutex_lock(&resultDataLock);
			if (rowIndex < resultDataCount && columnIndex < [resultData columnCount]) {
				theValue = [[SPDataStorageObjectAtRowAndColumn(resultData, rowIndex, columnIndex) copy] autorelease];
			}
			pthread_mutex_unlock(&resultDataLock);

			if (!theValue) return @"...";
		} else {
			theValue = SPDataStorageObjectAtRowAndColumn(resultData, rowIndex, columnIndex);
		}
		
		if ([theValue isKindOfClass:[NSData class]])
			return [theValue shortStringRepresentationUsingEncoding:[mySQLConnection encoding]];

		if ([theValue isNSNull])
			return [prefs objectForKey:SPNullValue];

	    return theValue;
	}
	else {
		return @"";
	}
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if (aTableView == customQueryView) {

		// Field editing
		if (fieldIDQueryString == nil) return;

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
		NSInteger numberOfPossibleUpdateRows = [[[[mySQLConnection queryString:[NSString stringWithFormat:@"SELECT COUNT(1) FROM %@.%@ %@", [[columnDefinition objectForKey:@"db"] backtickQuotedString], [tableForColumn backtickQuotedString], fieldIDQueryString]] fetchRowAsArray] objectAtIndex:0] integerValue];
		if(numberOfPossibleUpdateRows == 1) {
			// [[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:tableDocumentInstance];
			
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
				} else if([anObject isEqualToString:[prefs stringForKey:SPNullValue]]) {
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
					[[columnDefinition objectForKey:@"db"] backtickQuotedString], [tableForColumn backtickQuotedString],
					[[columnDefinition objectForKey:@"db"] backtickQuotedString], [tableForColumn backtickQuotedString], [columnName backtickQuotedString], newObject, fieldIDQueryString]];
			
			// [[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];

			// Check for errors while UPDATE
			if ([mySQLConnection queryErrored]) {
				SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), NSLocalizedString(@"Cancel", @"cancel button"), nil, [tableDocumentInstance parentWindow], self, nil, nil,
								  [NSString stringWithFormat:NSLocalizedString(@"Couldn't write field.\nMySQL said: %@", @"message of panel when error while updating field to db"), [mySQLConnection getLastErrorMessage]]);

				return;
			}


			// This shouldn't happen – for safety reasons
			if ( ![mySQLConnection affectedRows] ) {
				if ( [prefs boolForKey:SPShowNoAffectedRowsError] ) {
					SPBeginAlertSheet(NSLocalizedString(@"Warning", @"warning"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [tableDocumentInstance parentWindow], self, nil, nil,
									  NSLocalizedString(@"The row was not written to the MySQL database. You probably haven't changed anything.\nReload the table to be sure that the row exists and use a primary key for your table.\n(This error can be turned off in the preferences.)", @"message of panel when no rows have been affected after writing to the db"));
				} else {
					NSBeep();
				}
				return;
			}

			// On success reload table data by executing the last query
			reloadingExistingResult = YES;
			[self storeCurrentResultViewForRestoration];

			[self performQueries:[NSArray arrayWithObject:lastExecutedQuery] withCallback:NULL];
			
		} else {
			SPBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [tableDocumentInstance parentWindow], self, nil, nil,
							  [NSString stringWithFormat:NSLocalizedString(@"Updating field content failed. Couldn't identify field origin unambiguously (%ld match%@). It's very likely that while editing this field the table `%@` was changed by an other user.", @"message of panel when error while updating field to db after enabling it"), 
										(long)numberOfPossibleUpdateRows, (numberOfPossibleUpdateRows>1)?@"es":@"", tableForColumn]);

		}

	}
}

/*
 * Change the sort order by clicking at a column header
 */
- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{

	// Prevent sorting while a query is running
	if ([tableDocumentInstance isWorking]) return;
	if (!cqColumnDefinition || ![cqColumnDefinition count]) return;

	NSMutableString *queryString = [NSMutableString stringWithString:lastExecutedQuery];

	//sets order descending if a header is clicked twice
	if ( sortField && [[tableColumn identifier] isEqualToNumber:sortField] ) {
		isDesc = !isDesc;
	} else {
		isDesc = NO;
		if (sortField) [customQueryView setIndicatorImage:nil inTableColumn:[customQueryView tableColumnWithIdentifier:sortField]];
	}

	if (sortField) [sortField release];
	sortField = [[NSNumber alloc] initWithInteger:[[tableColumn identifier] integerValue]];

	// Order by the column position number to avoid ambiguous name errors
	NSString* newOrder = [NSString stringWithFormat:@" ORDER BY %ld %@ ", (long)([[tableColumn identifier] integerValue]+1), (isDesc)?@"DESC":@"ASC"];
	
	// Remove any comments
	[queryString replaceOccurrencesOfRegex:@"--.*?\n" withString:@""];
	[queryString replaceOccurrencesOfRegex:@"--.*?$" withString:@""];
	[queryString replaceOccurrencesOfRegex:@"/\\*(.|\n)*?\\*/" withString:@""];

	// Remove all quoted strings as a temp string to match the correct clauses
	NSRange matchedRange;
	NSInteger i;
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

	reloadingExistingResult = YES;
	[self storeCurrentResultViewForRestoration];
	queryIsTableSorter = YES;
	sortColumn = tableColumn;
	[self performQueries:[NSArray arrayWithObject:queryString] withCallback:@selector(tableSortCallback)];
}

- (void) tableSortCallback
{
	queryIsTableSorter = NO;

	if ([mySQLConnection queryErrored]) {
		sortColumn = nil;
		return;
	}

	//sets highlight and indicatorImage
	[customQueryView setHighlightedTableColumn:sortColumn];
	if ( isDesc )
		[customQueryView setIndicatorImage:[NSImage imageNamed:@"NSDescendingSortIndicator"] inTableColumn:sortColumn];
	else
		[customQueryView setIndicatorImage:[NSImage imageNamed:@"NSAscendingSortIndicator"] inTableColumn:sortColumn];

}


#pragma mark -
#pragma mark TableView Drag & Drop datasource methods

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rows toPasteboard:(NSPasteboard*)pboard
{
	if ( aTableView == customQueryView ) {
		NSString *tmp = [customQueryView draggedRowsAsTabString];
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

/*- (NSDragOperation)tableView:(NSTableView*)aTableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row
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
		[queryFavoritesView selectRowIndexes:[NSIndexSet indexSetWithIndex:destinationRow] byExtendingSelection:NO];
	
		return YES;
	} else {
		return NO;
	}
}*/

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

	if([[aCell stringValue] length] < 2 || [tableDocumentInstance isWorking]) return nil;

	NSImage *image;

	NSPoint pos = [NSEvent mouseLocation];
	pos.y -= 20;

	// Try to get the original data. If not possible return nil.
	// @try clause is used due to the multifarious cases of
	// possible exceptions (eg for reloading tables etc.)
	id theValue;
	@try{
		theValue = SPDataStorageObjectAtRowAndColumn(resultData, row, [[aTableColumn identifier] integerValue]);
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
	// by using the cell's font
	[SPTooltip showWithObject:[aCell stringValue] 
			atLocation:pos 
				ofType:@"text" 
		displayOptions:[NSDictionary dictionaryWithObjectsAndKeys:
					[[aCell font] familyName], @"fontname", 
					[NSString stringWithFormat:@"%f",[[aCell font] pointSize]], @"fontsize", 
					nil]];

	return nil;
}

/*
 * Double-click action on a field
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{

	// Only allow editing if a task is not active
	if ([tableDocumentInstance isWorking]) return NO;

	// Check if the field can identified bijectively
	if ( aTableView == customQueryView ) {


		NSDictionary *columnDefinition;
		BOOL noTableName = NO;
		BOOL isFieldEditable;
		BOOL isBlob;
		NSInteger numberOfPossibleUpdateRows = -1;

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
			numberOfPossibleUpdateRows = [[[[mySQLConnection queryString:[NSString stringWithFormat:@"SELECT COUNT(1) FROM %@.%@ %@", [[columnDefinition objectForKey:@"db"] backtickQuotedString], [tableForColumn backtickQuotedString], fieldIDQueryString]] fetchRowAsArray] objectAtIndex:0] integerValue];

			isFieldEditable = (numberOfPossibleUpdateRows == 1) ? YES : NO;

			if(!isFieldEditable)
				if(numberOfPossibleUpdateRows == 0)
					[errorText setStringValue:[NSString stringWithFormat:@"Field is not editable. No matching record found. Try to add the primary key field or more fields in your SELECT statement for table '%@' to identify field origin unambiguously.", tableForColumn]];
				else
			 		[errorText setStringValue:[NSString stringWithFormat:@"Field is not editable. Couldn't identify field origin unambiguously (%ld match%@).", (long)numberOfPossibleUpdateRows, (numberOfPossibleUpdateRows>1)?@"es":@""]];

		} else {
			// no table/databse name are given
			isFieldEditable = NO;
			fieldIDQueryString = nil;
		 	[errorText setStringValue:NSLocalizedString(@"Field is not editable. Field has no or multiple table or database origin(s).",@"field is not editable due to no table/database")];
		}


		SPFieldEditorController *fieldEditor = [[SPFieldEditorController alloc] init];

		// Remember edited row for reselecting and setting the scroll view after reload
		editedRow = rowIndex;
		editedScrollViewRect = [customQueryScrollView documentVisibleRect];

		// Set max text length
		if ([[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"string"]
		 && [columnDefinition valueForKey:@"char_length"])
			[fieldEditor setTextMaxLength:[[columnDefinition valueForKey:@"char_length"] integerValue]];

		id originalData = [resultData cellDataAtRow:rowIndex column:[[aTableColumn identifier] integerValue]];
		if ([originalData isNSNull]) originalData = [prefs objectForKey:SPNullValue];

		id editData = [[fieldEditor editWithObject:originalData
								fieldName:[columnDefinition objectForKey:@"name"]
								usingEncoding:[mySQLConnection encoding] 
								isObjectBlob:isBlob 
								isEditable:isFieldEditable 
								withWindow:[tableDocumentInstance parentWindow]] retain];

		if ( editData )
			[self tableView:aTableView setObjectValue:[editData copy] forTableColumn:aTableColumn row:rowIndex];

		[fieldEditor release];

		if ( editData ) [editData release];

		return NO;

	} else {
		return YES;
	}
}

/**
 * Prevent the selection of rows while the table is still loading
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
	return tableRowsSelectable;
}

#pragma mark -
#pragma mark TableView notifications

/**
 * Saves the new column size in the preferences for columns which map to fields
 */
- (void)tableViewColumnDidResize:(NSNotification *)aNotification
{
	// Abort if still loading the table
	if (![cqColumnDefinition count]) return;

	// Retrieve the original index of the column from the identifier
	NSInteger columnIndex = [[[[aNotification userInfo] objectForKey:@"NSTableColumn"] identifier] integerValue];
	NSDictionary *columnDefinition = NSArrayObjectAtIndex(cqColumnDefinition, columnIndex);

	// Don't save if the column doesn't map to an underlying SQL field
	if (![columnDefinition objectForKey:@"org_name"] || ![(NSString *)[columnDefinition objectForKey:@"org_name"] length])
		return;

	NSMutableDictionary *tableColumnWidths;
	NSString *host_db = [NSString stringWithFormat:@"%@@%@", [columnDefinition objectForKey:@"db"], [tableDocumentInstance host]];
	NSString *table = [columnDefinition objectForKey:@"org_table"];
	NSString *col = [columnDefinition objectForKey:@"org_name"];
	
	// Retrieve or instantiate the tableColumnWidths object
	if ([prefs objectForKey:SPTableColumnWidths] != nil) {
		tableColumnWidths = [NSMutableDictionary dictionaryWithDictionary:[prefs objectForKey:SPTableColumnWidths]];
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
	[[[tableColumnWidths objectForKey:host_db] objectForKey:table] setObject:[NSNumber numberWithDouble:[(NSTableColumn *)[[aNotification userInfo] objectForKey:@"NSTableColumn"] width]] forKey:col];
	[prefs setObject:tableColumnWidths forKey:SPTableColumnWidths];
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

- (NSRange)textView:(NSTextView *)aTextView willChangeSelectionFromCharacterRange:(NSRange)oldSelectedCharRange toCharacterRange:(NSRange)newSelectedCharRange
{
	// Check if snippet session is still valid
	if(!newSelectedCharRange.length && [textView isSnippetMode]) [textView checkForCaretInsideSnippet];

	return newSelectedCharRange;
}

/*
 * A notification posted when the selection changes within the text view;
 * used to control the run-currentrun-selection button state and action.
 */
- (void)textViewDidChangeSelection:(NSNotification *)aNotification
{

	// Ensure that the notification is from the custom query text view
	if ( [aNotification object] != textView ) return;

	BOOL isLookBehind = YES;
	NSRange currentSelection = [textView selectedRange];
	NSUInteger caretPosition = currentSelection.location;
	NSRange qRange = [self queryRangeAtPosition:caretPosition lookBehind:&isLookBehind];

	if(qRange.length)
		currentQueryRange = qRange;
	else
		currentQueryRange = NSMakeRange(0, 0);

	[textView setQueryRange:qRange];
	[textView setNeedsDisplay:YES];

	// disable "Comment Current Query" menu item if no current query is selectable
	[commentCurrentQueryMenuItem setEnabled:(currentQueryRange.length) ? YES : NO];

	// If no text is selected, disable the button and action menu.
	if ( caretPosition == NSNotFound ) {
		selectionButtonCanBeEnabled = NO;
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
			selectionButtonCanBeEnabled = YES;
			if (![tableDocumentInstance isWorking]) {
				[runSelectionButton setEnabled:YES];
				[runSelectionMenuItem setEnabled:YES];
			}
		} else {
			selectionButtonCanBeEnabled = NO;
			[runSelectionButton setEnabled:NO];
			[runSelectionMenuItem setEnabled:NO];
		}
		[commentLineOrSelectionMenuItem setTitle:NSLocalizedString(@"Comment Line", @"Title of action menu item to comment line")];

	// For selection ranges, enable the button.
	} else {
		selectionButtonCanBeEnabled = YES;
		[runSelectionButton setTitle:NSLocalizedString(@"Run Selection", @"Title of button to run selected text in custom query view")];
		[runSelectionMenuItem setTitle:NSLocalizedString(@"Run Selected Text", @"Title of action menu item to run selected text in custom query view")];
		[commentLineOrSelectionMenuItem setTitle:NSLocalizedString(@"Comment Selection", @"Title of action menu item to comment selection")];
		if (![tableDocumentInstance isWorking]) {
			[runSelectionButton setEnabled:YES];
			[runSelectionMenuItem setEnabled:YES];
		}
	}

	if(!historyItemWasJustInserted)
		currentHistoryOffsetIndex = -1;
}

#pragma mark -
#pragma mark TextField delegate methods

/**
 * Called whenever the user changes the name of the new query favorite or
 * the user changed the query favorite search string.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	if ([notification object] == queryFavoriteNameTextField)
		[saveQueryFavoriteButton setEnabled:[[queryFavoriteNameTextField stringValue] length]];
	else if ([notification object] == queryFavoritesSearchField){
		[self filterQueryFavorites:nil];
	}
	else if ([notification object] == queryHistorySearchField) {
		[self filterQueryHistory:nil];
	}

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
- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
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
- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
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
	[textView setConnection:mySQLConnection withVersion:[[[mySQLversion componentsSeparatedByString:@"."] objectAtIndex:0] integerValue]];
	
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
- (void)showHelpFor:(NSString *)searchString addToHistory:(BOOL)addToHistory calledByAutoHelp:(BOOL)autoHelp
{

	if(![searchString length]) return;

	NSString *helpString = [self getHTMLformattedMySQLHelpFor:searchString calledByAutoHelp:autoHelp];

	if(autoHelp && [helpString isEqualToString:SP_HELP_NOT_AVAILABLE]) {
		[helpWebViewWindow orderOut:nil];
		return;
	}

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

	// close Help window if no Help available
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
			[self showHelpFor:searchString addToHistory:YES calledByAutoHelp:NO];
			break;
	}
}

/*
 * Show the Help for the selected text in the webview
 */
- (IBAction)showHelpForWebViewSelection:(id)sender
{
	[self showHelpFor:[[helpWebView selectedDOMRange] text] addToHistory:YES calledByAutoHelp:NO];
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
	[self showHelpFor:searchString addToHistory:YES calledByAutoHelp:NO];
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
			[self showHelpFor:SP_HELP_TOC_SEARCH_STRING addToHistory:YES calledByAutoHelp:NO];
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

- (IBAction)showCompletionList:(id)sender
{
	NSRange insertRange = NSMakeRange([textView selectedRange].location, 0);
	switch([sender tag]) {
		case 8000:
		[textView showCompletionListFor:@"$SP_ASLIST_ALL_DATABASES" atRange:insertRange fuzzySearch:NO];
		break;
		case 8001:
		[textView showCompletionListFor:@"$SP_ASLIST_ALL_TABLES" atRange:insertRange fuzzySearch:NO];
		break;
		case 8002:
		[textView showCompletionListFor:@"$SP_ASLIST_ALL_FIELDS" atRange:insertRange fuzzySearch:NO];
		break;
	}
}
/*
 * Show the data for "HELP 'currentWord' invoked by autohelp"
 */
- (void)showAutoHelpForCurrentWord:(id)sender
{
	NSString *searchString = [[sender string] substringWithRange:[sender getRangeForCurrentWord]];
	[self showHelpFor:searchString addToHistory:YES calledByAutoHelp:YES];
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
	NSString *version = nil;
	if([[mySQLversion stringByReplacingOccurrencesOfString:@"." withString:@""] integerValue] < 42)
		version = @"41";
	else
		version = [mySQLversion stringByReplacingOccurrencesOfString:@"." withString:@""];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:
		[[NSString stringWithFormat:
			SPMySQLSearchURL,
			searchString,
			version]
		stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]]];
}

/*
 * Return the help string HTML formatted from executing "HELP 'searchString'".
 * If more than one help topic was found return a link list.
 */
- (NSString *)getHTMLformattedMySQLHelpFor:(NSString *)searchString calledByAutoHelp:(BOOL)autoHelp
{

	if(![searchString length]) return @"";
	
	NSRange         aRange;
	MCPResult     *theResult = nil;
	NSDictionary    *tableDetails;
	NSMutableString *theHelp = [NSMutableString string];

	[theHelp setString:@""];
	
	// search via: HELP 'searchString'
	theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"HELP '%@'", [searchString stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"]]];
	if ([mySQLConnection queryErrored])
	{
		// if an error or HELP is not supported fall back to online search but
		// don't open it if autoHelp is enabled
		if(!autoHelp)
			[self openMySQLonlineDocumentationWithString:searchString];

		[helpWebViewWindow close];
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
			NSInteger safeCnt = 0; // safety counter - not more than 200 loops allowed
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
		NSInteger i;
		NSInteger r = [theResult numOfRows];
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
	NSInteger navigationType = [[actionInformation objectForKey:WebActionNavigationTypeKey] integerValue];

	if([[[request URL] scheme] isEqualToString:@"applewebdata"] && navigationType == WebNavigationTypeLinkClicked){
		[self showHelpFor:[[[request URL] path] lastPathComponent] addToHistory:YES calledByAutoHelp:NO];
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
			[self showHelpFor:[[[[actionInformation objectForKey:WebActionOriginalURLKey] absoluteString] lastPathComponent] stringByReplacingPercentEscapesUsingEncoding:NSASCIIStringEncoding] addToHistory:NO calledByAutoHelp:NO];
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
			NSInteger tag = [menuItem tag];
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
#pragma mark Query favorites manager delegate methods

/**
 * Rebuild history popup menu.
 */
- (void)historyItemsHaveBeenUpdated:(id)manager
{

	// Abort if the connection has been closed already - sign of a closed window
	if (![mySQLConnection isConnected]) return;

	// Refresh history popup menu
	NSMenu* historyMenu = [queryHistoryButton menu];
	while([queryHistoryButton numberOfItems] > 7)
		[queryHistoryButton removeItemAtIndex:[queryHistoryButton numberOfItems]-1];
	
	NSUInteger numberOfHistoryItems = [[SPQueryController sharedQueryController] numberOfHistoryItemsForFileURL:[tableDocumentInstance fileURL]];
	if(numberOfHistoryItems>0)
		for(id historyMenuItem in [[SPQueryController sharedQueryController] historyMenuItemsForFileURL:[tableDocumentInstance fileURL]])
			[historyMenu addItem:historyMenuItem];
}
/**
 * Called by the query favorites manager whenever the query favorites have been updated.
 */
- (void)queryFavoritesHaveBeenUpdated:(id)manager
{
	NSMenuItem *headerMenuItem;
	NSMenu *menu = [queryFavoritesButton menu];

	// Remove all favorites beginning from the end
	while([queryFavoritesButton numberOfItems] > 7)
		[queryFavoritesButton removeItemAtIndex:[queryFavoritesButton numberOfItems]-1];
	
	// Build document-based list
	headerMenuItem = [[NSMenuItem alloc] initWithTitle:
		[[[[tableDocumentInstance fileURL] absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] lastPathComponent] 
		action:NULL keyEquivalent:@""];
	[headerMenuItem setTag:SP_FAVORITE_HEADER_MENUITEM_TAG];
	[headerMenuItem setToolTip:[NSString stringWithFormat:@"‘%@’ based favorites", 
		[[[[tableDocumentInstance fileURL] absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] lastPathComponent]]];
	[headerMenuItem setIndentationLevel:0];
	[menu addItem:headerMenuItem];
	[headerMenuItem release];
	for (NSDictionary *favorite in [[SPQueryController sharedQueryController] favoritesForFileURL:[tableDocumentInstance fileURL]]) {
		if (![favorite isKindOfClass:[NSDictionary class]] || ![favorite objectForKey:@"name"]) continue;
		NSMutableParagraphStyle *paraStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
		[paraStyle setTabStops:[NSArray array]];
		[paraStyle addTabStop:[[[NSTextTab alloc] initWithType:NSRightTabStopType location:190.0] autorelease]];
		NSDictionary *attributes = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:paraStyle, [NSFont systemFontOfSize:11], nil] forKeys:[NSArray arrayWithObjects:NSParagraphStyleAttributeName, NSFontAttributeName, nil]];
		NSAttributedString *titleString = [[[NSAttributedString alloc]
			initWithString:([favorite objectForKey:@"tabtrigger"] && [(NSString*)[favorite objectForKey:@"tabtrigger"] length]) ? [NSString stringWithFormat:@"%@\t%@⇥", [favorite objectForKey:@"name"], [favorite objectForKey:@"tabtrigger"]] : [favorite objectForKey:@"name"]
			    attributes:attributes] autorelease];
		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
		[item setToolTip:[NSString stringWithString:[favorite objectForKey:@"query"]]];
		[item setAttributedTitle:titleString];
		[item setIndentationLevel:1];
		[menu addItem:item];
		[item release];
	}

	// Build global list
	headerMenuItem = [[NSMenuItem alloc] initWithTitle:@"Global" action:NULL keyEquivalent:@""];
	[headerMenuItem setTag:SP_FAVORITE_HEADER_MENUITEM_TAG];
	[headerMenuItem setToolTip:@"Globally stored favorites"];
	[headerMenuItem setIndentationLevel:0];
	[menu addItem:headerMenuItem];
	[headerMenuItem release];
	for (NSDictionary *favorite in [prefs objectForKey:SPQueryFavorites]) {
		if (![favorite isKindOfClass:[NSDictionary class]] || ![favorite objectForKey:@"name"]) continue;
		NSMutableParagraphStyle *paraStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
		[paraStyle setTabStops:[NSArray array]];
		[paraStyle addTabStop:[[[NSTextTab alloc] initWithType:NSRightTabStopType location:190.0] autorelease]];
		NSDictionary *attributes = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:paraStyle, [NSFont systemFontOfSize:11], nil] forKeys:[NSArray arrayWithObjects:NSParagraphStyleAttributeName, NSFontAttributeName, nil]];
		NSAttributedString *titleString = [[[NSAttributedString alloc]
			initWithString:([favorite objectForKey:@"tabtrigger"] && [(NSString*)[favorite objectForKey:@"tabtrigger"] length]) ? [NSString stringWithFormat:@"%@\t%@⇥", [favorite objectForKey:@"name"], [favorite objectForKey:@"tabtrigger"]] : [favorite objectForKey:@"name"]
			    attributes:attributes] autorelease];
		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
		[item setToolTip:[NSString stringWithString:[favorite objectForKey:@"query"]]];
		[item setAttributedTitle:titleString];
		[item setIndentationLevel:1];
		[menu addItem:item];
		[item release];
	}
}

#pragma mark -
#pragma mark Task interaction

/**
 * Disable all content interactive elements during an ongoing task.
 */
- (void) startDocumentTaskForTab:(NSNotification *)aNotification
{
	isWorking = YES;

	// Only proceed if this view is selected.
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarCustomQuery])
		return;

	tableRowsSelectable = NO;
	[runSelectionButton setEnabled:NO];
	[runSelectionMenuItem setEnabled:NO];
	[runAllButton setEnabled:NO];
	[runAllMenuItem setEnabled:NO];
}

/**
 * Enable all content interactive elements after an ongoing task.
 */
- (void) endDocumentTaskForTab:(NSNotification *)aNotification
{
	isWorking = NO;

	// Only proceed if this view is selected.
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarCustomQuery])
		return;

	if (selectionButtonCanBeEnabled) {
		[runSelectionButton setEnabled:YES];
		[runSelectionMenuItem setEnabled:YES];
	}
	tableRowsSelectable = YES;
	[runAllButton setEnabled:YES];
	[runAllMenuItem setEnabled:YES];
}

#pragma mark -
#pragma mark Other

/**
 * Returns the number of queries.
 */
- (NSUInteger)numberOfQueries
{
	return numberOfQueries;
}

- (NSString *)buildHistoryString
{
	return [[[SPQueryController sharedQueryController] historyForFileURL:[tableDocumentInstance fileURL]] componentsJoinedByString:@";\n"];
}

/**
 * Add a query string to the file/global history, via the query controller.
 * Single argument allows calls on the main thread.
 */
- (void)addHistoryEntry:(NSString *)entryString
{
	[[SPQueryController sharedQueryController] addHistory:entryString forFileURL:[tableDocumentInstance fileURL]];
}

/*
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	// Display table veiew vertical gridlines preference changed
	if ([keyPath isEqualToString:SPDisplayTableViewVerticalGridlines]) {
        [customQueryView setGridStyleMask:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	}
	// Result Table Font preference changed
	else if ([keyPath isEqualToString:SPGlobalResultTableFont]) {
		NSFont *tableFont = [NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]];
		[customQueryView setRowHeight:2.0f+NSSizeToCGSize([[NSString stringWithString:@"{ǞṶḹÜ∑zgyf"] sizeWithAttributes:[NSDictionary dictionaryWithObject:tableFont forKey:NSFontAttributeName]]).height];
		[customQueryView setFont:tableFont];
		[customQueryView reloadData];
	}
}

/**
 * Called when the save query favorite/clear history sheet is dismissed.
 */
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{

	if ([contextInfo isEqualToString:@"clearHistory"]) {
		if (returnCode == NSOKButton) {
			// Remove items in the query controller
			[[SPQueryController sharedQueryController] replaceHistoryByArray:[NSMutableArray array] forFileURL:[tableDocumentInstance fileURL]];
		}
		return;
	}

	if ([contextInfo isEqualToString:@"addAllToNewQueryFavorite"] || [contextInfo isEqualToString:@"addSelectionToNewQueryFavorite"]) {
		if (returnCode == NSOKButton) {
			
			// Add the new query favorite directly the user's preferences here instead of asking the manager to do it
			// as it may not have been fully initialized yet.
			NSMutableArray *favorites = [NSMutableArray arrayWithArray:[prefs objectForKey:SPQueryFavorites]];

			// What should be saved
			NSString *queryToBeAddded;

			if([contextInfo isEqualToString:@"addSelectionToNewQueryFavorite"]) {
				// First check for a selection
				if([textView selectedRange].length)
					queryToBeAddded = [[textView string] substringWithRange:[textView selectedRange]];
				// then for a current query
				else if(currentQueryRange.length)
					queryToBeAddded = [[textView string] substringWithRange:currentQueryRange];
				// otherwise take the entire string
				else
					queryToBeAddded = [textView string];
			} else {
				queryToBeAddded = [textView string];
			}
			
			if([saveQueryFavoriteGlobal state] == NSOnState) {
				[favorites addObject:[NSMutableDictionary dictionaryWithObjects:
					[NSArray arrayWithObjects:[queryFavoriteNameTextField stringValue], queryToBeAddded, nil] 
							forKeys:[NSArray arrayWithObjects:@"name", @"query", nil]]];
			
				[prefs setObject:favorites forKey:SPQueryFavorites];
			} else {
				[[SPQueryController sharedQueryController] addFavorite:[NSMutableDictionary dictionaryWithObjects:
					[NSArray arrayWithObjects:[queryFavoriteNameTextField stringValue], [[queryToBeAddded mutableCopy] autorelease], nil] 
						forKeys:[NSArray arrayWithObjects:@"name", @"query", nil]] forFileURL:[tableDocumentInstance fileURL]];
			}

			[saveQueryFavoriteGlobal setState:NSOffState];

			[self queryFavoritesHaveBeenUpdated:nil];

		}
	}
	
	[queryFavoriteNameTextField setStringValue:@""];
}

- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode contextInfo:(id)contextInfo
{
	if([contextInfo isEqualToString:@"saveHistory"]) {
		if (returnCode == NSOKButton) {
			NSError *error = nil;
		
			[prefs setInteger:[[encodingPopUp selectedItem] tag] forKey:SPLastSQLFileEncoding];
			[prefs synchronize];
		
			[[self buildHistoryString] writeToFile:[panel filename] 
										atomically:YES 
										  encoding:[[encodingPopUp selectedItem] tag] 
											 error:&error];
		
			if (error) [[NSAlert alertWithError:error] runModal];
		}
	}
}

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{

	// Control "Save ... to Favorites"
	if ( [menuItem tag] == SP_SAVE_SELECTION_FAVORTITE_MENUITEM_TAG ) {
		if ([[textView string] length] < 1) return NO;
		if([textView selectedRange].length)
			[menuItem setTitle:NSLocalizedString(@"Save Selection to Favorites",@"Save Selection to Favorites")];
		else if(currentQueryRange.length)
			[menuItem setTitle:NSLocalizedString(@"Save Current Query to Favorites",@"Save Current Query to Favorites")];
		else
			[menuItem setTitle:NSLocalizedString(@"Save All to Favorites",@"Save All to Favorites")];
	}

	// Control "Save All to Favorites"
	if ( [menuItem tag] == SP_SAVE_ALL_FAVORTITE_MENUITEM_TAG ) {
		if ([[textView string] length] < 1) return NO;
	}

	// Avoid selecting button list headers
	else if ( [menuItem tag] == SP_FAVORITE_HEADER_MENUITEM_TAG ) {
		return NO;
	}

	// Control Clear History menu item title according to isUntitled
	else if ( [menuItem tag] == SP_HISTORY_CLEAR_MENUITEM_TAG ) {
		if ( [tableDocumentInstance isUntitled] ) {
			[menuItem setTitle:NSLocalizedString(@"Clear Global History", @"clear global history menu item title")];
			[menuItem setToolTip:NSLocalizedString(@"Clear the global history list", @"clear the global history list tooltip message")];
		} else {
			[menuItem setTitle:[NSString stringWithFormat:NSLocalizedString(@"Clear History for “%@”", @"clear history for “%@” menu title"), [tableDocumentInstance displayName]]];
			[menuItem setToolTip:NSLocalizedString(@"Clear the document-based history list", @"clear the document-based history list tooltip message")];
		}
	}

	// Check for History items
	else if ( [menuItem tag] >= SP_HISTORY_COPY_MENUITEM_TAG && [menuItem tag] <= SP_HISTORY_CLEAR_MENUITEM_TAG ) {
		return ([queryHistoryButton numberOfItems]-7);
	}

	return YES;
}

#pragma mark -

- (id)init
{
	if ((self = [super init])) {
		
		usedQuery = [[NSString stringWithString:@""] retain];

		sortField = nil;
		isDesc = NO;
		sortColumn = nil;
		selectionButtonCanBeEnabled = NO;
		cqColumnDefinition = nil;
		favoritesManager = nil;

		tableRowsSelectable = YES;
		selectionIndexToRestore = nil;
		selectionViewportToRestore = NSZeroRect;

		// init helpHTMLTemplate
		NSError *error;
		
		helpHTMLTemplate = [[NSString alloc]
							initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:SPHTMLHelpTemplate ofType:@"html"]
							encoding:NSUTF8StringEncoding
							error:&error];
		
		// an error occurred while reading
		if (helpHTMLTemplate == nil) {
			NSLog(@"%@", [NSString stringWithFormat:@"Error reading “%@.html”!<br>%@", SPHTMLHelpTemplate, [error localizedFailureReason]]);
			NSBeep();
		}
		
		// init search history
		[helpWebView setMaintainsBackForwardList:YES];
		[[helpWebView backForwardList] setCapacity:20];
		
		// init tableView's data source
		resultDataCount = 0;
		resultData = [[SPDataStorage alloc] init];
		editedRow = -1;

		currentHistoryOffsetIndex = -1;
		historyItemWasJustInserted = NO;

		prefs = [NSUserDefaults standardUserDefaults];

	}

	return self;
}

/**
 * Filters the query favorites menu.
 */
- (IBAction)filterQueryFavorites:(id)sender
{
	NSUInteger i;
	NSMenu *menu = [queryFavoritesButton menu];
	NSString *searchPattern = [queryFavoritesSearchField stringValue];
	
	for (i = 7; i < [menu numberOfItems]; i++)
	{
		[[menu itemAtIndex:i] setHidden:([[menu itemAtIndex:i] tag] != SP_FAVORITE_HEADER_MENUITEM_TAG 
										 && ![[[menu itemAtIndex:i] title] isMatchedByRegex:[NSString stringWithFormat:@"(?i).*%@.*", searchPattern]])];
	}
}

/**
 * Filters the query history menu.
 */
- (IBAction)filterQueryHistory:(id)sender
{
	NSMenu *menu = [queryHistoryButton menu];
	NSUInteger numberOfItems = [menu numberOfItems];
	NSUInteger i;
	NSString *searchPattern = [queryHistorySearchField stringValue];
	NSArray *history = [[SPQueryController sharedQueryController] historyForFileURL:[tableDocumentInstance fileURL]];
	for (i = 7; i < numberOfItems; i++)
	{
		[[menu itemAtIndex:i] setHidden:(![[history objectAtIndex:i-7] isMatchedByRegex:[NSString stringWithFormat:@"(?i).*%@.*", searchPattern]])];
	}
}

/**
 * Abort editing of the Favorite and History search field editors if user presses ARROW UP or DOWN
 * to allow to navigate through the menu item list.
 */
- (BOOL)control:(NSControl*)control textView:(NSTextView*)textView doCommandBySelector:(SEL)commandSelector
{
	if(control == queryHistorySearchField || control == queryFavoritesSearchField) {
		if(commandSelector == @selector(moveDown:) || commandSelector == @selector(moveUp:)) {
			[queryHistorySearchField abortEditing];
			[queryFavoritesSearchField abortEditing];

			// Send moveDown/Up to the popup menu
			NSEvent *arrowEvent;
			if(commandSelector == @selector(moveDown:))
				arrowEvent = [NSEvent keyEventWithType:NSKeyDown location:NSMakePoint(0,0) modifierFlags:0 timestamp:0 windowNumber:[[tableDocumentInstance parentWindow] windowNumber] context:[NSGraphicsContext currentContext] characters:nil charactersIgnoringModifiers:nil isARepeat:NO keyCode:0x7D];
			else
				arrowEvent = [NSEvent keyEventWithType:NSKeyDown location:NSMakePoint(0,0) modifierFlags:0 timestamp:0 windowNumber:[[tableDocumentInstance parentWindow] windowNumber] context:[NSGraphicsContext currentContext] characters:nil charactersIgnoringModifiers:nil isARepeat:NO keyCode:0x7E];
			[[NSApplication sharedApplication] postEvent:arrowEvent atStart:NO];
			return YES;

		}
	}
	return NO;
}
// - (void)menu:(NSMenu *)menu willHighlightItem:(NSMenuItem *)item
// {
// // Set the focus at the search field
// // TODO : but no way out; always selecting first/last menu item
// // because after setting focus to search field NSMenu selectedItemIndex is -1
// 	if(item == queryHistorySearchMenuItem) {
// 		[queryHistorySearchField selectText:nil];
// 	}
// 
// }

/**
 * Setup various interface controls.
 */
- (void)awakeFromNib
{
	// Set pre-defined menu tags 
	[queryFavoritesSaveAsMenuItem setTag:SP_SAVE_SELECTION_FAVORTITE_MENUITEM_TAG];
	[queryFavoritesSaveAllMenuItem setTag:SP_SAVE_ALL_FAVORTITE_MENUITEM_TAG];

	// Set the structure and index view's vertical gridlines if required
	[customQueryView setGridStyleMask:([prefs boolForKey:SPDisplayTableViewVerticalGridlines]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];	
	
	// Add observers for document task activity
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(startDocumentTaskForTab:)
												 name:SPDocumentTaskStartNotification
											   object:tableDocumentInstance];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(endDocumentTaskForTab:)
												 name:SPDocumentTaskEndNotification
											   object:tableDocumentInstance];

	[prefs addObserver:self forKeyPath:SPGlobalResultTableFont options:NSKeyValueObservingOptionNew context:NULL];


}

/**
 * Dealloc.
 */
- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[prefs removeObserver:self forKeyPath:SPGlobalResultTableFont];

	[usedQuery release];
	[resultData release];
	[favoritesManager release];
	
	if (helpHTMLTemplate) [helpHTMLTemplate release];
	if (mySQLversion) [mySQLversion release];
	if (sortField) [sortField release];
	if (cqColumnDefinition) [cqColumnDefinition release];
	if (selectionIndexToRestore) [selectionIndexToRestore release];
	if (currentQueryRanges) [currentQueryRanges release];
	
	[super dealloc];
}
	
@end
