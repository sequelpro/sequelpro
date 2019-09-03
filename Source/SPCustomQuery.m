//
//  SPCustomQuery.m
//  sequel-pro
//
//  Created by Lorenz Textor (lorenz@textor.ch) on May 1, 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//  Copyright (c) 2012 Sequel Pro Team. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <https://github.com/sequelpro/sequelpro>

#import "SPCustomQuery.h"
#import "SPSQLParser.h"
#ifndef SP_CODA /* headers */
#import "SPGrowlController.h"
#endif
#import "SPDataCellFormatter.h"
#import "SPDatabaseDocument.h"
#import "SPTablesList.h"
#import "RegexKitLite.h"
#import "SPFieldEditorController.h"
#import "SPTextAndLinkCell.h"
#import "SPTooltip.h"
#import "SPCopyTable.h"
#ifndef SP_CODA /* headers */
#import "SPQueryFavoriteManager.h"
#endif
#import "SPQueryController.h"
#import "SPEncodingPopupAccessory.h"
#import "SPDataStorage.h"
#import "SPAlertSheets.h"
#import "SPCopyTable.h"
#import "SPGeometryDataView.h"
#import "SPSplitView.h"
#import "SPTextView.h"
#import "RegexKitLite.h"
#import "SPThreadAdditions.h"
#import "SPConstants.h"
#ifndef SP_CODA /* headers */
#import "SPAppController.h"
#import "SPBundleHTMLOutputController.h"
#endif
#import "SPFunctions.h"
#import "SPHelpViewerClient.h"
#import "SPHelpViewerController.h"

#import <pthread.h>
#import <SPMySQL/SPMySQL.h>

#include <libkern/OSAtomic.h>

typedef struct {
	NSUInteger query;
	NSUInteger total;
} QueryProgress;

typedef void (^QueryProgressHandler)(QueryProgress *);

/**
 * This class is used to decouple the background thread running the SQL queries
 * from the main thread displaying the progress.
 *
 * It ensures that
 * - the background thread will not get blocked because it has to wait for the UI update to complete,
 * - the main thread does not have to process more progress updates than it can handle and
 * - the UI is updated at most once for each query (important with slow queries)
 *
 * This has quite a significant performance impact:
 * - Both threads synchronized on progress update =>
 *     running 2500 queries takes about 157 seconds wall time (SP reported time: 10.5s) and the UI is updated 2500 times
 * - With this class decoupling them =>
 *     running 2500 queries takes about 1 second wall time (SP reported time: 605ms) and the UI is updated 80 times
 */
@interface SPQueryProgressUpdateDecoupling : NSObject
{
	QueryProgressHandler updateHandler;

	volatile BOOL dirtyMarker;
	volatile OSSpinLock qpLock;
	volatile QueryProgress _queryProgress;
}
@property(atomic,assign) QueryProgress queryProgress;
- (instancetype)initWithBlock:(QueryProgressHandler)anUpdateHandler;
- (void)_updateProgress;
@end


@interface SPCustomQuery ()

- (id)_resultDataItemAtRow:(NSInteger)row columnIndex:(NSUInteger)column preserveNULLs:(BOOL)preserveNULLs asPreview:(BOOL)asPreview;
- (void)documentWillClose:(NSNotification *)notification;
- (void)queryFavoritesHaveBeenUpdated:(NSNotification *)notification;
- (void)historyItemsHaveBeenUpdated:(NSNotification *)notification;
- (void)helpWindowClosedByUser:(NSNotification *)notification;

@end

@implementation SPCustomQuery

#ifdef SP_CODA
@synthesize textView;
@synthesize customQueryView;
@synthesize tableDocumentInstance;
@synthesize tablesListInstance;
@synthesize affectedRowsText;
#endif

@synthesize runAllButton;
@synthesize textViewWasChanged;

#pragma mark IBAction methods

/**
 * Run the primary query task, as per the user preference
 */
- (IBAction)runPrimaryQueryAction:(id)sender
{
	if ([prefs boolForKey:SPQueryPrimaryControlRunsAll]) {
		[self runAllQueries:sender];
	} else {
		[self runSelectedQueries:sender];
	}
}

/**
 * Run the secondary query task, as per the user preference
 */
- (IBAction)runSecondaryQueryAction:(id)sender
{
	if ([prefs boolForKey:SPQueryPrimaryControlRunsAll]) {
		[self runSelectedQueries:sender];
	} else {
		[self runAllQueries:sender];
	}
}

/**
 * Swap the primary and secondary query run actions
 */
- (IBAction)switchDefaultQueryAction:(id)sender
{
	BOOL newValue = ![prefs boolForKey:SPQueryPrimaryControlRunsAll];
	[prefs setBool:newValue forKey:SPQueryPrimaryControlRunsAll];
	[self updateQueryInteractionInterface];
}

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

	// Re-init sort order
	isDesc = NO;
	sortColumn = nil;
	if(sortField) SPClear(sortField);

	// Retrieve the custom query string and split it into separate SQL queries
	queryParser = [[SPSQLParser alloc] initWithString:[textView string]];
	[queryParser setDelimiterSupport:YES];
	queries = [queryParser splitStringByCharacter:';'];

	// If carriage returns were found, normalise the queries
	if ([queryParser containsCarriageReturns]) {
		NSMutableArray *normalisedQueries = [NSMutableArray arrayWithCapacity:[queries count]];
		for (NSString *query in queries) {
			[normalisedQueries addObject:[SPSQLParser normaliseQueryForExecution:query]];
		}
		queries = normalisedQueries;
	}

	[queryParser release];

	// Reset queryStartPosition
	queryStartPosition = 0;

	reloadingExistingResult = NO;
	[self clearResultViewDetailsToRestore];

	[self performQueries:queries withCallback:NULL];
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

	// Re-init sort order
	isDesc = NO;
	sortColumn = nil;
	if(sortField) SPClear(sortField);

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
		queries = @[[SPSQLParser normaliseQueryForExecution:query]];

	// Otherwise, run the selected text.
	} else {
		queryParser = [[SPSQLParser alloc] initWithString:[[textView string] substringWithRange:selectedRange]];
		[queryParser setDelimiterSupport:YES];
		queries = [queryParser splitStringByCharacter:';'];

		// If carriage returns were found, normalise the queries
		if ([queryParser containsCarriageReturns]) {
			NSMutableArray *normalisedQueries = [NSMutableArray arrayWithCapacity:[queries count]];
			for (query in queries) {
				[normalisedQueries addObject:[SPSQLParser normaliseQueryForExecution:query]];
			}
			queries = normalisedQueries;
		}

		[queryParser release];
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
#ifndef SP_CODA /* ui manip for query favorites */
	if ([queryFavoritesButton indexOfSelectedItem] == 1) {

		// This should never evaluate to true as we are now performing menu validation, meaning the 'Save Query to Favorites' menu item will
		// only be enabled if the query text view has at least one character present.
		if ([[textView string] isEqualToString:@""]) {
			SPOnewayAlertSheet(
				NSLocalizedString(@"Empty query", @"empty query message"),
				[tableDocumentInstance parentWindow],
				NSLocalizedString(@"Cannot save an empty query.", @"empty query informative message")
			);
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
			SPOnewayAlertSheet(
				NSLocalizedString(@"Empty query", @"empty query message"),
				[tableDocumentInstance parentWindow],
				NSLocalizedString(@"Cannot save an empty query.", @"empty query informative message")
			);
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

		if([[NSApp currentEvent] modifierFlags] & (NSEventModifierFlagShift|NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagCommand))
			replaceContent = !replaceContent;
		if(replaceContent) {
			[textView setSelectedRange:NSMakeRange(0,[[textView string] length])];
			[textView breakUndoCoalescing];
			[textView insertText:@""];
		}

		// The actual query strings have been already stored as tooltip
		[textView insertAsSnippet:[[queryFavoritesButton selectedItem] toolTip] atRange:NSMakeRange([textView selectedRange].location, 0)];
	}
#endif
}

/*
 * Insert the choosen history query in the query textView
 */
- (IBAction)chooseQueryHistory:(id)sender
{
#ifndef SP_CODA
	[prefs synchronize];

	// Choose history item
	if ([queryHistoryButton indexOfSelectedItem] > 6) {

		BOOL replaceContent = [prefs boolForKey:SPQueryHistoryReplacesContent];
		[textView breakUndoCoalescing];
		if([[NSApp currentEvent] modifierFlags] & (NSEventModifierFlagShift|NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagCommand))
			replaceContent = !replaceContent;
		if(replaceContent)
			[textView setSelectedRange:NSMakeRange(0,[[textView string] length])];

		[textView insertText:[[[SPQueryController sharedQueryController] historyForFileURL:[tableDocumentInstance fileURL]] objectAtIndex:[queryHistoryButton indexOfSelectedItem]-7]];
	}
#endif
}

/**
 * Closes the sheet
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

/**
 * Perform simple actions (which don't require their own method), triggered by selecting the appropriate menu item
 * in the "gear" action menu displayed beneath the cusotm query view.
 */
- (IBAction)gearMenuItemSelected:(id)sender
{
#ifndef SP_CODA
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
#endif

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
		if([[NSApp currentEvent] modifierFlags] & (NSEventModifierFlagControl))
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
#ifndef SP_CODA /* prefs access */
		[prefs setBool:enableAutoindent forKey:SPCustomQueryAutoIndent];
		[prefs synchronize];
#endif
		[autoindentMenuItem setState:enableAutoindent?NSOnState:NSOffState];
		[textView setAutoindent:enableAutoindent];
	}

	// "Auto-pair characters" toggle
	if (sender == autopairMenuItem) {
		BOOL enableAutopair = !([autopairMenuItem state] == NSOffState);
#ifndef SP_CODA /* prefs access */
		[prefs setBool:enableAutopair forKey:SPCustomQueryAutoPairCharacters];
		[prefs synchronize];
#endif
		[autopairMenuItem setState:enableAutopair?NSOnState:NSOffState];
		[textView setAutopair:enableAutopair];
	}

#ifndef SP_CODA /* prefs access */
	// "Auto-help" toggle
	if (sender == autohelpMenuItem) {
		BOOL enableAutohelp = !([autohelpMenuItem state] == NSOffState);
		[prefs setBool:enableAutohelp forKey:SPCustomQueryUpdateAutoHelp];
		[prefs synchronize];
		[autohelpMenuItem setState:enableAutohelp?NSOnState:NSOffState];
		[textView setAutohelp:enableAutohelp];
	}
#endif

	// "Auto-uppercase keywords" toggle
	if (sender == autouppercaseKeywordsMenuItem) {
		BOOL enableAutouppercaseKeywords = !([autouppercaseKeywordsMenuItem state] == NSOffState);
#ifndef SP_CODA /* prefs access */
		[prefs setBool:enableAutouppercaseKeywords forKey:SPCustomQueryAutoUppercaseKeywords];
		[prefs synchronize];
#endif
		[autouppercaseKeywordsMenuItem setState:enableAutouppercaseKeywords?NSOnState:NSOffState];
		[textView setAutouppercaseKeywords:enableAutouppercaseKeywords];
	}
}

- (IBAction)saveQueryHistory:(id)sender
{
#ifndef SP_CODA
	NSSavePanel *panel = [NSSavePanel savePanel];

	[panel setAllowedFileTypes:@[SPFileExtensionSQL]];

	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:YES];
	[panel setCanSelectHiddenExtension:YES];
	[panel setCanCreateDirectories:YES];

	[panel setAccessoryView:[SPEncodingPopupAccessory encodingAccessory:[prefs integerForKey:SPLastSQLFileEncoding] includeDefaultEntry:NO encodingPopUp:&encodingPopUp]];

	[encodingPopUp setEnabled:YES];

    [panel setNameFieldStringValue:@"history"];
    [panel beginSheetModalForWindow:[tableDocumentInstance parentWindow] completionHandler:^(NSInteger returnCode) {
        if (returnCode == NSOKButton) {
			NSError *error = nil;
            
			[prefs setInteger:[[encodingPopUp selectedItem] tag] forKey:SPLastSQLFileEncoding];
			[prefs synchronize];
            
			[[self buildHistoryString] writeToURL:[panel URL]
                                       atomically:YES
                                         encoding:[[encodingPopUp selectedItem] tag]
                                            error:&error];
            
			if (error) [[NSAlert alertWithError:error] runModal];
		}
    }];
#endif
}

- (IBAction)copyQueryHistory:(id)sender
{
	NSPasteboard *pb = [NSPasteboard generalPasteboard];

	[pb declareTypes:@[NSStringPboardType] owner:nil];
	[pb setString:[self buildHistoryString] forType:NSStringPboardType];

}

/**
 * 'Clear History' menu item - clear query history
 */
- (IBAction)clearQueryHistory:(id)sender
{
#ifndef SP_CODA
	NSString *infoString;

	if ([tableDocumentInstance isUntitled])
		infoString = NSLocalizedString(@"Are you sure you want to clear the global history list? This action cannot be undone.", @"clear global history list informative message");
	else
		infoString = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to clear the history list for “%@”? This action cannot be undone.", @"clear history list for “%@” informative message"), [tableDocumentInstance displayName]];

	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Clear History?", @"clear history message")
									 defaultButton:NSLocalizedString(@"Clear", @"clear button")
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
									   otherButton:nil
						 informativeTextWithFormat:@"%@", infoString];

	[alert setAlertStyle:NSCriticalAlertStyle];

	NSArray *buttons = [alert buttons];

	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"r"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];

	[alert beginSheetModalForWindow:[tableDocumentInstance parentWindow]
					  modalDelegate:self
					 didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
						contextInfo:@"clearHistory"];
#endif
}

/* *
 * Set font panel's valid modes
 */
- (NSFontPanelModeMask)validModesForFontPanel:(NSFontPanel *)fontPanel
{
	return NSFontPanelSizeModeMask | NSFontPanelCollectionModeMask;
}

#pragma mark -
#pragma mark Query actions

/**
 * Performs the mysql-query given by the user
 * sets the tableView columns corresponding to the mysql-result
 */
- (void)performQueries:(NSArray *)queries withCallback:(SEL)customQueryCallbackMethod;
{
	NSString *taskString;
	
	//ensure there is no pending edit, which could be messed up (#2113)
	[[tableDocumentInstance parentWindow] endEditingFor:nil];
	
	if ([queries count] > 1) {
		taskString = [NSString stringWithFormat:NSLocalizedString(@"Running query %i of %lu...", @"Running multiple queries string"), 1, (unsigned long)[queries count]];
	} 
	else {
		taskString = NSLocalizedString(@"Running query...", @"Running single query string");
	}
	
	[tableDocumentInstance startTaskWithDescription:taskString];
	[errorTextTitle setStringValue:NSLocalizedString(@"Query Status", @"Query Status")];
	[errorText setString:taskString];
	[affectedRowsText setStringValue:@""];

	NSValue *encodedCallbackMethod = nil;
	if (customQueryCallbackMethod)
		encodedCallbackMethod = [NSValue valueWithBytes:&customQueryCallbackMethod objCType:@encode(SEL)];
	NSDictionary *taskArguments = [NSDictionary dictionaryWithObjectsAndKeys:queries, @"queries", encodedCallbackMethod, @"callback", nil];

	// If a helper thread is already running, execute inline - otherwise detach a new thread for the queries
	if ([NSThread isMainThread]) {
		[NSThread detachNewThreadWithName:SPCtxt(@"SPCustomQuery query perform task", tableDocumentInstance) target:self selector:@selector(performQueriesTask:) object:taskArguments];
	} 
	else {
		[self performQueriesTask:taskArguments];
	}
}

- (void)performQueriesTask:(NSDictionary *)taskArguments
{
	@autoreleasepool {
		NSArray                     *queries        = [taskArguments objectForKey:@"queries"];
		SPMySQLStreamingResultStore *resultStore    = nil;
		NSMutableString             *errors         = [NSMutableString string];
		SEL                          callbackMethod = NULL;
		NSString                    *taskButtonString;

		NSUInteger i, totalQueriesRun = 0, totalAffectedRows = 0;
		double executionTime = 0;
		NSInteger firstErrorOccuredInQuery = -1;
		BOOL suppressErrorSheet = NO;
		BOOL tableListNeedsReload = NO;
		BOOL databaseWasChanged = NO;
		// BOOL queriesSeparatedByDelimiter = NO;

		NSCharacterSet *whitespaceAndNewlineSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
#ifndef SP_CODA /* [tableDocumentInstance setQueryMode:] */
		[tableDocumentInstance setQueryMode:SPCustomQueryQueryMode];
#endif

		// Notify listeners that a query has started
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryWillBePerformed" object:tableDocumentInstance];

#ifndef SP_CODA /* growl */
		// Start the notification timer to allow notifications to be shown even if frontmost for long queries
		[[SPGrowlController sharedGrowlController] setVisibilityForNotificationName:@"Query Finished"];
#endif

		// Reset the current table view as necessary to avoid redraw and reload issues.
		// Restore the view position to the top left to be within the results for all datasets.
		if(editedRow == -1 && !reloadingExistingResult) {
			[[customQueryView onMainThread] scrollRowToVisible:0];
			[[customQueryView onMainThread] scrollColumnToVisible:0];
		}

		// Remove all the columns if not reloading the table
		if(!reloadingExistingResult) {
			SPClear(cqColumnDefinition);
			[[self onMainThread] updateTableView];
		}

		// Disable automatic query retries on failure for the custom queries
		[mySQLConnection setRetryQueriesOnConnectionFailure:NO];

		NSUInteger queryCount = [queries count];
		NSMutableArray *tempQueries = [NSMutableArray arrayWithCapacity:queryCount];

		// Enable task cancellation
		taskButtonString = (queryCount > 1)? NSLocalizedString(@"Stop queries", @"Stop queries string") : NSLocalizedString(@"Stop query", @"Stop query string");
		[tableDocumentInstance enableTaskCancellationWithTitle:taskButtonString callbackObject:nil callbackFunction:NULL];

		SPQueryProgressUpdateDecoupling *progressUpdater = [[SPQueryProgressUpdateDecoupling alloc] initWithBlock:^(QueryProgress *qp) {
			NSString *taskString = [NSString stringWithFormat:NSLocalizedString(@"Running query %ld of %lu...", @"Running multiple queries string"), (long)(qp->query+1), (unsigned long)(qp->total)];
			[tableDocumentInstance setTaskDescription:taskString];
			[errorText setString:taskString];
		}];

		// Perform the supplied queries in series
		for ( i = 0 ; i < queryCount ; i++ ) {

			if (i > 0) {
				QueryProgress qp = { .query = i, .total = queryCount};
				[progressUpdater setQueryProgress:qp];
			}

			NSString *query = [NSArrayObjectAtIndex(queries, i) stringByTrimmingCharactersInSet:whitespaceAndNewlineSet];

			// Don't run blank queries, or queries which only contain whitespace.
			if (![query length]) continue;

			// store trimmed queries for usedQueries and history
			[tempQueries addObject:query];

			// Run the query, timing execution (note this also includes network and overhead)
			resultStore = [[mySQLConnection resultStoreFromQueryString:query] retain];
			executionTime += [resultStore queryExecutionTime];
			totalQueriesRun++;

			// If this is the last query, retrieve and store the result; otherwise,
			// discard the result without fully loading.
			if (totalQueriesRun == queryCount || [mySQLConnection lastQueryWasCancelled]) {

				// Retrieve and cache the column definitions for the result array
				if (cqColumnDefinition) [cqColumnDefinition release];
				cqColumnDefinition = [[resultStore fieldDefinitions] retain];

				if(!reloadingExistingResult) {
					[[self onMainThread] updateTableView];
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

				// Init copyTable with necessary information for copying selected rows as SQL INSERT
				[customQueryView setTableInstance:self
				                    withTableData:resultData
				                      withColumns:cqColumnDefinition
				                    withTableName:resultTableName
				                   withConnection:mySQLConnection];

				[self updateResultStore:resultStore];
			} else {
				[resultStore cancelResultLoad];
			}

			// Record any affected rows
			if ( [mySQLConnection rowsAffectedByLastQuery] != (unsigned long long)~0 ) {
				totalAffectedRows += (NSUInteger) [mySQLConnection rowsAffectedByLastQuery];
			}
			else if ( [resultStore numberOfRows] ) {
				totalAffectedRows += (NSUInteger) [resultStore numberOfRows];
			}

			[resultStore release];

			// Store any error messages
			if ([mySQLConnection queryErrored] || [mySQLConnection lastQueryWasCancelled]) {

				NSString *errorString;
				if ([mySQLConnection lastQueryWasCancelled]) {
					if ([mySQLConnection lastQueryWasCancelledUsingReconnect]){
						errorString = NSLocalizedString(@"Query cancelled.  Please note that to cancel the query the connection had to be reset; transactions and connection variables were reset.", @"Query cancel by resetting connection error");
					}
					else {
						errorString = NSLocalizedString(@"Query cancelled.", @"Query cancelled error");
					}
				} else {
					errorString = [mySQLConnection lastErrorMessage];

					// If dealing with a "MySQL server has gone away" error, explain the situation.
					// Error 2006 is CR_SERVER_GONE_ERROR, which means the query write couldn't complete.
					if ([mySQLConnection lastErrorID] == 2006) {
						errorString = [NSString stringWithFormat:@"%@.\n\n%@", errorString, NSLocalizedString(@"(This usually indicates that the connection has been closed by the server after inactivity, but can also occur due to other conditions.  The connection has been restored; please try again if the query is safe to re-run.)", @"Explanation for MySQL server has gone away error")];
					}
				}

				// If the query errored, append error to the error log for display at the end
				if ( queryCount > 1 ) {
					if(firstErrorOccuredInQuery == -1) firstErrorOccuredInQuery = i+1;

					if(!suppressErrorSheet)
					{
						// Update error text for the user
						[errors appendFormat:NSLocalizedString(@"[ERROR in query %ld] %@\n", @"error text when multiple custom query failed"),
						                     (long)(i+1),
						                     errorString];
						[[errorTextTitle onMainThread] setStringValue:NSLocalizedString(@"Last Error Message", @"Last Error Message")];
						[[errorText onMainThread] setString:errors];

						// ask the user to continue after detecting an error
						if (![mySQLConnection lastQueryWasCancelled]) {

							[tableDocumentInstance setTaskIndicatorShouldAnimate:NO];
							[SPAlertSheets beginWaitingAlertSheetWithTitle:NSLocalizedString(@"MySQL Error", @"mysql error message")
							                                 defaultButton:NSLocalizedString(@"Run All", @"run all button")
							                               alternateButton:NSLocalizedString(@"Continue", @"continue button")
							                                   otherButton:NSLocalizedString(@"Stop", @"stop button")
							                                    alertStyle:NSWarningAlertStyle
							                                     docWindow:[tableDocumentInstance parentWindow]
							                                 modalDelegate:self
							                                didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
							                                   contextInfo:@"runAllContinueStopSheet"
							                                      infoText:[mySQLConnection lastErrorMessage]
							                                    returnCode:&runAllContinueStopSheetReturnCode];

							[tableDocumentInstance setTaskIndicatorShouldAnimate:YES];

							switch (runAllContinueStopSheetReturnCode) {
								case NSAlertDefaultReturn:
									suppressErrorSheet = YES;
								case NSAlertAlternateReturn:
									break;
								default:
									if(i < queryCount-1) {
										// output that message only if it was not the last one
										[errors appendString:NSLocalizedString(@"Execution stopped!\n", @"execution stopped message")];
									}
									i = queryCount; // break for loop; for safety reasons stop the execution of the following queries
							}
						}
					} else {
						[errors appendFormat:NSLocalizedString(@"[ERROR in query %ld] %@\n", @"error text when multiple custom query failed"),
						                     (long)(i+1),
						                     errorString];
					}
				} else {
					[errors setString:errorString];
				}
			} else {
				// Check if table/db list needs an update
				// The regex is a compromise between speed and usefullness. TODO: further improvements are needed
				if(!tableListNeedsReload && [query isMatchedByRegex:@"(?i)^\\s*\\b(create|alter|drop|rename)\\b\\s+."]) {
					tableListNeedsReload = YES;
				}
				if(!databaseWasChanged && [query isMatchedByRegex:@"(?i)^\\s*\\b(use|drop\\s+database|drop\\s+schema)\\b\\s+."]){
					databaseWasChanged = YES;
				}
			}
			// If the query was cancelled, end all queries.
			if ([mySQLConnection lastQueryWasCancelled]) break;
		}

		[progressUpdater release];

		// Reload table list if at least one query began with drop, alter, rename, or create
		if(tableListNeedsReload || databaseWasChanged) {
			// Build database pulldown menu
			[[tableDocumentInstance onMainThread] setDatabases:self];

			if (databaseWasChanged) {
				// Reset the current database
				[tableDocumentInstance refreshCurrentDatabase];
			}

			// Reload table list
			[tablesListInstance updateTables:self];
		}

		if(usedQuery) [usedQuery release];

		// if(!queriesSeparatedByDelimiter) // TODO: How to combine queries delimited by DELIMITER?
		usedQuery = [[NSString stringWithString:[tempQueries componentsJoinedByString:@";\n"]] retain];

		if (lastExecutedQuery) [lastExecutedQuery release];
		lastExecutedQuery = [[tempQueries lastObject] retain];

		// Perform empty query if no query is given
		if ( !queryCount ) {
			resultStore = [mySQLConnection resultStoreFromQueryString:@""];
			[resultStore cancelResultLoad];
			[errors setString:[mySQLConnection lastErrorMessage]];
		}

#ifndef SP_CODA
		// add query to history
		if(!reloadingExistingResult && [usedQuery length]) {
			[self performSelectorOnMainThread:@selector(addHistoryEntry:) withObject:usedQuery waitUntilDone:NO];
		}
#endif

		// Update status/errors text
		NSDictionary *statusDetails = [NSDictionary dictionaryWithObjectsAndKeys:
			errors, @"errorString",
			[NSNumber numberWithInteger:firstErrorOccuredInQuery], @"firstErrorQueryNumber",
			nil
		];
		[self performSelectorOnMainThread:@selector(updateStatusInterfaceWithDetails:) withObject:statusDetails waitUntilDone:YES];

		// Set up the status string
		NSString *statusString = nil;
		NSString *statusErrorString = [errors length]?NSLocalizedString(@"Errors", @"Errors title"):NSLocalizedString(@"No errors", @"No errors title");
		if ( [mySQLConnection lastQueryWasCancelled] ) {
			if (totalQueriesRun > 1) {
				statusString = [NSString stringWithFormat:NSLocalizedString(@"%@; Cancelled in query %ld, after %@", @"text showing multiple queries were cancelled"),
				                                          statusErrorString,
				                                          (long)totalQueriesRun,
				                                          [NSString stringForTimeInterval:executionTime]];
			} else {
				statusString = [NSString stringWithFormat:NSLocalizedString(@"%@; Cancelled after %@", @"text showing a query was cancelled"),
				                                          statusErrorString,
				                                          [NSString stringForTimeInterval:executionTime]];
			}
		} else if ( totalQueriesRun > 1 ) {
			if (totalAffectedRows==1) {
				statusString = [NSString stringWithFormat:NSLocalizedString(@"%@; 1 row affected in total, by %ld queries taking %@", @"text showing one row has been affected by multiple queries"),
				                                          statusErrorString,
				                                          (long)totalQueriesRun,
				                                          [NSString stringForTimeInterval:executionTime]];
			} else {
				statusString = [NSString stringWithFormat:NSLocalizedString(@"%@; %ld rows affected in total, by %ld queries taking %@", @"text showing how many rows have been affected by multiple queries"),
				                                          statusErrorString,
				                                          (long)totalAffectedRows,
				                                          (long)totalQueriesRun,
				                                          [NSString stringForTimeInterval:executionTime]];
			}
		} else {
			if (totalAffectedRows==1) {
				statusString = [NSString stringWithFormat:NSLocalizedString(@"%@; 1 row affected", @"text showing one row has been affected by a single query"),
				                                          statusErrorString];
			} else {
				statusString = [NSString stringWithFormat:NSLocalizedString(@"%@; %ld rows affected", @"text showing how many rows have been affected by a single query"),
				                                          statusErrorString,
				                                          (long)totalAffectedRows];
			}
			if([resultData count]) {
				// we were running a query that returns a result set (ie. SELECT).
				// TODO: mysql_query() returns as soon as the first result row is found (which might be pretty soon when using indexes / not doing aggregations)
				//       and that makes our query time measurement pretty useless (see #264)
				statusString = [statusString stringByAppendingFormat:NSLocalizedString(@", first row available after %1$@",@"Custom Query : text appended to the “x row(s) affected” messages. $1 is a time interval"),[NSString stringForTimeInterval:executionTime]];
			}
			else {
				statusString = [statusString stringByAppendingFormat:NSLocalizedString(@", taking %1$@",@"Custom Query : text appended to the “x row(s) affected” messages (for update/delete queries). $1 is a time interval"),[NSString stringForTimeInterval:executionTime]];
			}
		}

		[[affectedRowsText onMainThread] setStringValue:statusString];

		// Restore automatic query retries
		[mySQLConnection setRetryQueriesOnConnectionFailure:YES];

#ifndef SP_CODA /* [tableDocumentInstance setQueryMode:] */
		[tableDocumentInstance setQueryMode:SPInterfaceQueryMode];
#endif

		// If no results were returned, redraw the empty table and post notifications before returning.
		if ( ![resultData count] ) {
			[customQueryView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];

			// Notify any listeners that the query has completed
			[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];

#ifndef SP_CODA /* growl */
			// Perform the Growl notification for query completion
			[[SPGrowlController sharedGrowlController] notifyWithTitle:@"Query Finished"
			                                               description:[NSString stringWithFormat:NSLocalizedString(@"%@",@"description for query finished growl notification"), [[errorText onMainThread] string]]
			                                                  document:tableDocumentInstance
			                                          notificationName:@"Query Finished"];
#endif

			// Set up the callback if present
			if ([taskArguments objectForKey:@"callback"]) {
				[[taskArguments objectForKey:@"callback"] getValue:&callbackMethod];
				[self performSelectorOnMainThread:callbackMethod withObject:nil waitUntilDone:NO];
			}

			[tableDocumentInstance endTask];

			return;
		}

		// Restore the result view origin if appropriate
		if (!NSEqualRects(selectionViewportToRestore, NSZeroRect)) {

			// Scroll the viewport to the saved location
			selectionViewportToRestore.size = [customQueryView visibleRect].size;
			[[customQueryView onMainThread] scrollRectToVisible:selectionViewportToRestore];
		}

		//query finished
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];

#ifndef SP_CODA /* growl */
		// Query finished Growl notification
		[[SPGrowlController sharedGrowlController] notifyWithTitle:@"Query Finished"
		                                               description:[NSString stringWithFormat:NSLocalizedString(@"%@",@"description for query finished growl notification"), [[errorText onMainThread] string]]
		                                                  document:tableDocumentInstance
		                                          notificationName:@"Query Finished"];
#endif

		// Set up the callback if present
		if ([taskArguments objectForKey:@"callback"]) {
			[[taskArguments objectForKey:@"callback"] getValue:&callbackMethod];
			[self performSelectorOnMainThread:callbackMethod withObject:nil waitUntilDone:YES];
		}

		[tableDocumentInstance endTask];

		// Restore selection indexes if appropriate
		if (selectionIndexToRestore) [customQueryView selectRowIndexes:selectionIndexToRestore byExtendingSelection:NO];

		if (reloadingExistingResult) [[tableDocumentInstance parentWindow] makeFirstResponder:customQueryView];
	}
}

/**
 * Processes a supplied streaming result store, monitoring the load and updating
 * the data displayed during download.
 */
- (void)updateResultStore:(SPMySQLStreamingResultStore *)theResultStore
{
	pthread_mutex_lock(&resultDataLock);
	// Remove all items from the table
	SPMainQSync(^{
		[resultData removeAllRows];
		[customQueryView noteNumberOfRowsChanged];
	});

	// Add the new store
	[resultData setDataStorage:theResultStore updatingExisting:NO];
	pthread_mutex_unlock(&resultDataLock);

	// Start the data downloading
	[theResultStore startDownload];

	// Set up the table updates timer and wait for it to notify this thread about completion
	[[self onMainThread] initQueryLoadTimer];

	[resultData awaitDataDownloaded];
	
	// Any further UI updates are the responsibility of the timer callback
}

/**
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

	// If the supplied position is beyond the end of the string, return nil.
	if (position > [[textView string] length])
		return NSMakeRange(NSNotFound, 0);

	// Split the current text into ranges of queries
	// only if the textView was really changed, otherwise use the cache
	if([[textView textStorage] editedMask] != 0 || [self textViewWasChanged]) {
		[self setTextViewWasChanged:NO];
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

/**
 * Retrieve the range of the query for the passed index seen from a start position
 * specified within the custom query text view.
 */
- (NSRange)queryTextRangeForQuery:(NSInteger)anIndex startPosition:(NSUInteger)position
{
	SPSQLParser *customQueryParser;
	NSArray *queries;

	// If the supplied position beyond the end of the string, return nil.
	if (position > [[textView string] length])
		return NSMakeRange(NSNotFound,0);

	// Split the current text into ranges of queries
	customQueryParser = [[SPSQLParser alloc] initWithString:[[textView string] substringWithRange:NSMakeRange(position, [[textView string] length]-position)]];
	[customQueryParser setDelimiterSupport:YES];
	queries = [[NSArray alloc] initWithArray:[customQueryParser splitStringIntoRangesByCharacter:';']];
	[customQueryParser release];

	// Check for a valid index
	anIndex--;
	if(anIndex < 0 || anIndex >= (NSInteger)[queries count])
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

/**
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

/**
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

/**
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

/**
 * Update the interface to reflect the query error state.
 * Should be performed on the main thread.
 */
- (void) updateStatusInterfaceWithDetails:(NSDictionary *)errorDetails
{
	NSString *errorsString = [errorDetails objectForKey:@"errorString"];
	NSInteger firstErrorOccuredInQuery = [[errorDetails objectForKey:@"firstErrorQueryNumber"] integerValue];

	// If errors occur, display them
	if ( [mySQLConnection lastQueryWasCancelled] || ([errorsString length] && !queryIsTableSorter)) {

#ifndef SP_CODA
		// set the error text
		[errorTextTitle setStringValue:NSLocalizedString(@"Last Error Message", @"Last Error Message")];
		[errorText setString:[errorsString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
		[[errorTextScrollView verticalScroller] setFloatValue:1.0f];
#endif

		// try to select the line x of the first error if error message with ID 1064 contains "at line x"
		// by capturing the last number of the error string
		NSRange errorLineNumberRange = [errorsString rangeOfRegex:@"([0-9]+)[^0-9]*$" options:RKLNoOptions inRange:NSMakeRange(0, [errorsString length]) capture:1L error:nil];

		// if error ID 1064 and a line number was found
		if([mySQLConnection lastErrorID] == 1064 && errorLineNumberRange.length)
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
		[errorTextTitle setStringValue:NSLocalizedString(@"Last Error Message", @"Last Error Message")];
		[errorText setString:NSLocalizedString(@"Couldn't sort column.", @"text shown if an error occured while sorting the result table")];
		NSBeep();
	} else {
		[errorText setString:NSLocalizedString(@"There were no errors.", @"text shown when query was successfull")];
	}

#ifndef SP_CODA /* show/hide errror view */
	// Show or hide the error area if necessary
	if ([errorsString length] && [queryInfoPaneSplitView isCollapsibleSubviewCollapsed]) {
		[queryInfoPaneSplitView toggleCollapse:self];
	} else if (![errorsString length] && ![queryInfoPaneSplitView isCollapsibleSubviewCollapsed]) {
		[queryInfoPaneSplitView toggleCollapse:self];
	}
#else
	if ( [errorsString length] > 0 )
		NSRunAlertPanel(LOCAL(@"Query Error"), @"%@", LOCAL(@"OK"), nil, nil, errorsString);
#endif
}

#pragma mark -
#pragma mark Interface setup

/**
 * Update the Run Selection/Query/All button and menu item state according
 * to the user preferences.
 */
- (void)updateQueryInteractionInterface
{

	// By default, the interface uses Run Query/Run Selection as the primary interface,
	// but the user can switch this.
	BOOL primaryActionIsRunAll = [prefs boolForKey:SPQueryPrimaryControlRunsAll];

	// Update the links as appropriate
	if (primaryActionIsRunAll) {
		runPrimaryActionButtonAsSelection = nil;
		[runPrimaryActionButton setTitle:NSLocalizedString(@"Run All", @"run all button")];
		[runPrimaryActionMenuItem setTitle:NSLocalizedString(@"Run All Queries", @"Run All menu item title")];
	} else {
		runPrimaryActionButtonAsSelection = runPrimaryActionButton;
		[runSecondaryActionMenuItem setTitle:NSLocalizedString(@"Run All Queries", @"Run All menu item title")];
	}

	// Update the Run Current/Previous/Selection menu item (and button if appropriate)
	[self updateContextualRunInterface];
}

/**
 * Update the selection-sensitive "Run Current" / "Run Previous" / "Run Selection"
 * button and menu items based on the current interface state
 */
- (void)updateContextualRunInterface
{
	NSMenuItem *runSelectionMenuItem;

	// Determine the menu item to change
	if (runPrimaryActionButtonAsSelection) {
		runSelectionMenuItem = runPrimaryActionMenuItem;
	} else {
		runSelectionMenuItem = runSecondaryActionMenuItem;
	}

	// If the current selection is a single caret position, update the button based on
	// whether the caret is inside a valid query.
	if (![textView selectedRange].length) {
		if (currentQueryBeforeCaret) {
			[runPrimaryActionButtonAsSelection setTitle:NSLocalizedString(@"Run Previous", @"Title of button to run query just before text caret in custom query view")];
			[runSelectionMenuItem setTitle:NSLocalizedString(@"Run Previous Query", @"Title of action menu item to run query just before text caret in custom query view")];
		} else {
			[runPrimaryActionButtonAsSelection setTitle:NSLocalizedString(@"Run Current", @"Title of button to run current query in custom query view")];
			[runSelectionMenuItem setTitle:NSLocalizedString(@"Run Current Query", @"Title of action menu item to run current query in custom query view")];
		}

	// Otherwise, reflect the active selection
	} else {
		[runPrimaryActionButtonAsSelection setTitle:NSLocalizedString(@"Run Selection", @"Title of button to run selected text in custom query view")];
		[runSelectionMenuItem setTitle:NSLocalizedString(@"Run Selected Text", @"Title of action menu item to run selected text in custom query view")];
	}
}

#pragma mark -
#pragma mark Table load actions

/**
 * Set up the table loading interface update timer.
 * This should be called on the main thread.
 */
- (void) initQueryLoadTimer
{
	if (queryLoadTimer) [self clearQueryLoadTimer];
	
	queryLoadInterfaceUpdateInterval = 1;
	queryLoadLastRowCount = 0;
	queryLoadTimerTicksSinceLastUpdate = 0;

	queryLoadTimer = [[NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(queryLoadUpdate:) userInfo:nil repeats:YES] retain];
}

/**
 * Invalidate and release the table loading interface update timer.
 * This should be called on the main thread.
 */
- (void) clearQueryLoadTimer
{
	if (queryLoadTimer) {
		[queryLoadTimer invalidate];
		SPClear(queryLoadTimer);
	}
}

/**
 * Perform table interface updates when loading queries, based on timer
 * ticks.  As data becomes available, the table should be redrawn to
 * show new rows - quickly at the start of the table, and then slightly
 * slower after some time to avoid needless updates.
 */
- (void) queryLoadUpdate:(NSTimer *)theTimer
{
	NSUInteger resultDataCount = [resultData count];
	
	if (queryLoadTimerTicksSinceLastUpdate < queryLoadInterfaceUpdateInterval) {
		queryLoadTimerTicksSinceLastUpdate++;
		return;
	}

	if ([resultData dataDownloaded]) {
		[self clearQueryLoadTimer];
	}

	// Check whether a table update is required, based on whether new rows are
	// available to display.
	if (resultDataCount == queryLoadLastRowCount) {
		return;
	}

	// Update the table display
	[customQueryView noteNumberOfRowsChanged];

	// Update column widths in two cases: on very first rows displayed, and once
	// more than 200 rows are present.
	if (queryLoadInterfaceUpdateInterval == 1 || (resultDataCount >= 200 && queryLoadLastRowCount < 200)) {
		[self autosizeColumns];
	}

	queryLoadLastRowCount = resultDataCount;

	// Determine whether to decrease the update frequency
	switch (queryLoadInterfaceUpdateInterval) {
		case 1:
			queryLoadInterfaceUpdateInterval = 10;
			break;
		case 10:
			queryLoadInterfaceUpdateInterval = 25;
			break;
	}
	
	queryLoadTimerTicksSinceLastUpdate = 0;
}

#pragma mark -
#pragma mark Accessors

/**
 * Returns the current result (as shown in custom result view) as an array, the first object containing 
 * the field names as an array and the following objects containing the rows as arrays.
 */
- (NSArray *)currentResult
{	
	return [self currentDataResultWithNULLs:NO truncateDataFields:YES];
}

/**
 * Returns the number of rows in the current data result.
 *
 * @return The number of rows.
 */
- (NSUInteger)currentResultRowCount
{
	return [resultData count];
}

/**
 * Returns the current result (as shown in custom result view) as an array, the first object containing 
 * the field names as an array and the following objects containing the rows as arrays.
 *
 * @param includeNULLs Indicates whether to include NULLs as a native type
 *                     or use the user's NULL string representation preference.
 * @param truncate     Indicates whether to truncate data fields for display purposes.
 */
- (NSArray *)currentDataResultWithNULLs:(BOOL)includeNULLs truncateDataFields:(BOOL)truncate
{
	NSInteger i;	
	id tableColumn;
	NSMutableArray *tempRow = [[NSMutableArray alloc] init];
	
	// Set field names as first line
	for (tableColumn in [customQueryView tableColumns])
	{
		[tempRow addObject:[[tableColumn headerCell] stringValue]];
	}
	
	NSMutableArray *currentResult = [NSMutableArray array];
	
	[currentResult addObject:[NSArray arrayWithArray:tempRow]];

	// Add rows
	for (i = 0; i < [self numberOfRowsInTableView:customQueryView]; i++) 
	{
		[tempRow removeAllObjects];
		
		NSEnumerator *enumerator = [[customQueryView tableColumns] objectEnumerator];
		
		while ((tableColumn = [enumerator nextObject])) 
		{
			[tempRow addObject:[self _resultDataItemAtRow:i columnIndex:[[tableColumn identifier] integerValue] preserveNULLs:includeNULLs asPreview:truncate]];
		}
		
		[currentResult addObject:[NSArray arrayWithArray:tempRow]];
	}
	
	[tempRow release];
	
	return currentResult;
}

#pragma mark -
#pragma mark Additional methods

/**
 * Sets the connection (received from SPDatabaseDocument) and makes things that have to be done only once
 */
- (void)setConnection:(SPMySQLConnection *)theConnection
{
	mySQLConnection = theConnection;
	currentQueryRanges = nil;

	// Set up the interface

	[customQueryView setVerticalMotionCanBeginDrag:NO];
#ifndef SP_CODA
	[autoindentMenuItem setState:([prefs boolForKey:SPCustomQueryAutoIndent]?NSOnState:NSOffState)];
	[autopairMenuItem setState:([prefs boolForKey:SPCustomQueryAutoPairCharacters]?NSOnState:NSOffState)];
	[autohelpMenuItem setState:([prefs boolForKey:SPCustomQueryUpdateAutoHelp]?NSOnState:NSOffState)];
	[autouppercaseKeywordsMenuItem setState:([prefs boolForKey:SPCustomQueryAutoUppercaseKeywords]?NSOnState:NSOffState)];
#else
	[autoindentMenuItem setState:(YES?NSOnState:NSOffState)];
	[autopairMenuItem setState:(YES?NSOnState:NSOffState)];
	[autohelpMenuItem setState:(YES?NSOnState:NSOffState)];
	[autouppercaseKeywordsMenuItem setState:(YES?NSOnState:NSOffState)];
#endif

#ifndef SP_CODA
	if ( [[SPQueryController sharedQueryController] historyForFileURL:[tableDocumentInstance fileURL]] )
		[self performSelectorOnMainThread:@selector(historyItemsHaveBeenUpdated:) withObject:nil waitUntilDone:YES];

	// Populate query favorites
	[self queryFavoritesHaveBeenUpdated:nil];
#endif
}

/**
 * Inserts the query in the textView and performs query
 */
- (void)doPerformQueryService:(NSString *)query
{
	[self doPerformLoadQueryService:query];
	[self runAllQueries:self];
}

- (void)doPerformLoadQueryService:(NSString *)query
{
	[textView shouldChangeTextInRange:NSMakeRange(0, [[textView string] length]) replacementString:query];
	[textView setString:query];
	[textView didChangeText];
	[textView scrollRangeToVisible:NSMakeRange([query length], 0)];
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
		[NSArrayObjectAtIndex(theColumns, 0) setHeaderToolTip:nil]; // prevent crash #2414
		[customQueryView removeTableColumn:NSArrayObjectAtIndex(theColumns, 0)];
	}

	// Update font size on the table
#ifndef SP_CODA
	NSFont *tableFont = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPGlobalResultTableFont]];
#else
	NSFont *tableFont = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
#endif
	[customQueryView setRowHeight:2.0f+NSSizeToCGSize([@"{ǞṶḹÜ∑zgyf" sizeWithAttributes:@{NSFontAttributeName : tableFont}]).height];

	// If there are no table columns to add, return
	if (!cqColumnDefinition || ![cqColumnDefinition count]) return;

	// Add the new table columns
	for (NSDictionary *columnDefinition in cqColumnDefinition) {
		theCol = [[NSTableColumn alloc] initWithIdentifier:[columnDefinition objectForKey:@"datacolumnindex"]];
		[theCol setResizingMask:NSTableColumnUserResizingMask];
		[theCol setEditable:YES];
		SPTextAndLinkCell *dataCell = [[[SPTextAndLinkCell alloc] initTextCell:@""] autorelease];
		[dataCell setEditable:YES];
		[dataCell setFont:tableFont];

		[dataCell setLineBreakMode:NSLineBreakByTruncatingTail];
		[dataCell setFormatter:[[SPDataCellFormatter new] autorelease]];

		// Set field length limit if field is a varchar to match varchar length
		if ([[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"string"]
			|| [[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"bit"]) {
			[[dataCell formatter] setTextLimit:[[columnDefinition objectForKey:@"char_length"] integerValue]];
		}

		// Set the column to right-aligned for numeric data types
		if ([[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"integer"]
			|| [[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"float"])
		{
			[dataCell setAlignment:NSRightTextAlignment];
		}

		// Set field type for validations
		[[dataCell formatter] setFieldType:[columnDefinition objectForKey:@"type"]];
		[theCol setDataCell:dataCell];
		[[theCol headerCell] setStringValue:[columnDefinition objectForKey:@"name"]];
		[theCol setHeaderToolTip:[NSString stringWithFormat:@"%@ – %@%@", [columnDefinition objectForKey:@"name"], [columnDefinition objectForKey:@"type"], ([columnDefinition objectForKey:@"char_length"]) ? [NSString stringWithFormat:@"(%@)", [columnDefinition objectForKey:@"char_length"]] : @""]];

#ifndef SP_CODA
		// Set the width of this column to saved value if exists and maps to a real column
		if ([columnDefinition objectForKey:@"org_name"] && [(NSString *)[columnDefinition objectForKey:@"org_name"] length]) {
			NSNumber *colWidth = [[[[prefs objectForKey:SPTableColumnWidths] objectForKey:[NSString stringWithFormat:@"%@@%@", [columnDefinition objectForKey:@"db"], [tableDocumentInstance host]]] objectForKey:[columnDefinition objectForKey:@"org_table"]] objectForKey:[columnDefinition objectForKey:@"org_name"]];
			if ( colWidth ) {
				[theCol setWidth:[colWidth floatValue]];
			}
		}
#endif

		[customQueryView addTableColumn:theCol];
		[theCol release];
	}
}

/**
 * Provide a getter for the custom query result table's selected rows index set
 */
- (NSIndexSet *)resultSelectedRowIndexes
{
	return [customQueryView selectedRowIndexes];
}

/**
 * Provide a getter for the custom query result table's current viewport
 */
- (NSRect)resultViewport
{
	return [customQueryView visibleRect];
}

/**
 * Set the selected row indexes to restore on next custom query result table load
 */
- (void)setResultSelectedRowIndexesToRestore:(NSIndexSet *)theIndexSet
{
	if (selectionIndexToRestore) SPClear(selectionIndexToRestore);

	if (theIndexSet) selectionIndexToRestore = [[NSIndexSet alloc] initWithIndexSet:theIndexSet];
}

/**
 * Set the viewport to restore on next table load
 */
- (void)setResultViewportToRestore:(NSRect)theViewport
{
	selectionViewportToRestore = theViewport;
}

/**
 * Convenience method for storing all current settings for restoration
 */
- (void)storeCurrentResultViewForRestoration
{
	[self setResultSelectedRowIndexesToRestore:[self resultSelectedRowIndexes]];
	[self setResultViewportToRestore:[self resultViewport]];
}

/**
 * Convenience method for clearing any settings to restore
 */
- (void)clearResultViewDetailsToRestore
{
	[self setResultSelectedRowIndexesToRestore:nil];
	[self setResultViewportToRestore:NSZeroRect];
}

/**
 * Autosize all columns based on their content.
 * Should be called on the main thread.
 */
- (void)autosizeColumns
{
	if (isWorking) pthread_mutex_lock(&resultDataLock);
	NSDictionary *columnWidths = [customQueryView autodetectColumnWidths];
	if (isWorking) pthread_mutex_unlock(&resultDataLock);
	[customQueryView setDelegate:nil];
	for (NSDictionary *columnDefinition in cqColumnDefinition) {

#ifndef SP_CODA
		// Skip columns with saved widths
		if ([[[[prefs objectForKey:SPTableColumnWidths] objectForKey:[NSString stringWithFormat:@"%@@%@", [tableDocumentInstance database], [tableDocumentInstance host]]] objectForKey:[tablesListInstance tableName]] objectForKey:[columnDefinition objectForKey:@"name"]]) continue;
#endif

		// Otherwise set the column width
		NSTableColumn *aTableColumn = [customQueryView tableColumnWithIdentifier:[columnDefinition objectForKey:@"datacolumnindex"]];
		NSUInteger targetWidth = [[columnWidths objectForKey:[columnDefinition objectForKey:@"datacolumnindex"]] integerValue];
		[aTableColumn setWidth:targetWidth];
	}
	
	[customQueryView setDelegate:self];
}

#pragma mark -
#pragma mark Field Editing

/**
 * Check if table cell is editable
 * Returns as array the minimum number of possible changes or
 * -1 if no table name can be found or multiple table origins
 * -2 for other errors
 * and the used WHERE clause to identify
 */
- (NSArray*)fieldEditStatusForRow:(NSInteger)rowIndex andColumn:(NSInteger)columnIndex
{
	NSDictionary *columnDefinition = [NSDictionary dictionaryWithDictionary:[cqColumnDefinition objectAtIndex:[[[[customQueryView tableColumns] objectAtIndex:columnIndex] identifier] integerValue]]];

	if(!columnDefinition)
		return @[@(-2), @""];

	// Resolve the original table name for current column if AS was used
	NSString *tableForColumn = [columnDefinition objectForKey:@"org_table"];

	// Get the database name which the field belongs to
	NSString *dbForColumn = [columnDefinition objectForKey:@"db"];

	// No table/database name found indicates that the field's column contains data from more than one table as for UNION
	// or the field data are not bound to any table as in SELECT 1 or if column database is unset
	if(!tableForColumn || ![tableForColumn length] || !dbForColumn || ![dbForColumn length])
		return @[@(-1), @""];

	// if table and database name are given check if field can be identified unambiguously
	// first without blob data
	NSString *fieldIDQueryStr = [self argumentForRow:rowIndex ofTable:tableForColumn andDatabase:[columnDefinition objectForKey:@"db"] includeBlobs:NO];
	if(!fieldIDQueryStr)
		return @[@(-1), @""];

	[tableDocumentInstance startTaskWithDescription:NSLocalizedString(@"Checking field data for editing...", @"checking field data for editing task description")];

	// Actual check whether field can be identified bijectively 
	SPMySQLResult *tempResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SELECT COUNT(1) FROM %@.%@ %@",
		[[columnDefinition objectForKey:@"db"] backtickQuotedString],
		[tableForColumn backtickQuotedString],
		fieldIDQueryStr]];

	if ([mySQLConnection queryErrored]) {
		[tableDocumentInstance endTask];
		return @[@(-1), @""];
	}

	NSArray *tempRow = [tempResult getRowAsArray];

	if([tempRow count] && [[tempRow objectAtIndex:0] integerValue] > 1) {
		// try to identify the cell by using blob data
		fieldIDQueryStr = [self argumentForRow:rowIndex ofTable:tableForColumn andDatabase:[columnDefinition objectForKey:@"db"] includeBlobs:YES];
		if(!fieldIDQueryStr) {
			[tableDocumentInstance endTask];
			return @[@(-1), @""];
		}

		tempResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SELECT COUNT(1) FROM %@.%@ %@",
			[[columnDefinition objectForKey:@"db"] backtickQuotedString],
			[tableForColumn backtickQuotedString],
			fieldIDQueryStr]];

		if ([mySQLConnection queryErrored]) {
			[tableDocumentInstance endTask];
			return @[@(-1), @""];
		}

		tempRow = [tempResult getRowAsArray];

		if([tempRow count] && [[tempRow objectAtIndex:0] integerValue] < 1) {
			[tableDocumentInstance endTask];
			return @[@(-1), @""];
		}
	}

	[tableDocumentInstance endTask];

	if(fieldIDQueryStr == nil)
		fieldIDQueryStr = @"";

	return [NSArray arrayWithObjects:[NSNumber numberWithInteger:[[tempRow objectAtIndex:0] integerValue]], fieldIDQueryStr, nil];
}

/**
 * Collect all columns for a given 'tableForColumn' table and
 * return a WHERE clause for identifying the field in question.
 */
- (NSString *)argumentForRow:(NSUInteger)rowIndex ofTable:(NSString *)tableForColumn andDatabase:(NSString *)database includeBlobs:(BOOL)includeBlobs
{
	NSArray *dataRow;
	id field;
	NSMutableArray *argumentParts = [NSMutableArray array];

	// Check the table/view columns and select only those coming from the supplied database and table
	NSMutableArray *columnsInSpecifiedTable = [NSMutableArray array];
	for(field in cqColumnDefinition) {
		if([[field objectForKey:@"db"] isEqualToString:database] && [[field objectForKey:@"org_table"] isEqualToString:tableForColumn])
			[columnsInSpecifiedTable addObject:field];
	}

	// --- Build WHERE clause ---
	dataRow = [resultData rowContentsAtIndex:rowIndex];

	// Get the primary key if there is one, using any columns present within it
	SPMySQLResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW COLUMNS FROM %@.%@",
		[database backtickQuotedString], [tableForColumn backtickQuotedString]]];
	[theResult setReturnDataAsStrings:YES];
	NSMutableArray *primaryColumnsInSpecifiedTable = [NSMutableArray array];
	for (NSDictionary *eachRow in theResult) {
		if ( [[eachRow objectForKey:@"Key"] isEqualToString:@"PRI"] ) {
			for (field in columnsInSpecifiedTable) {
				if([[field objectForKey:@"org_name"] isEqualToString:[eachRow objectForKey:@"Field"]]) {
					[primaryColumnsInSpecifiedTable addObject:field];
				}
			}
		}
	}

	// Determine whether to use the primary keys list or fall back to all fields when building the query string
	NSMutableArray *columnsToQuery = [primaryColumnsInSpecifiedTable count] ? primaryColumnsInSpecifiedTable : columnsInSpecifiedTable;

	// Build up the argument
	for (field in columnsToQuery) {
		id aValue = [dataRow objectAtIndex:[[field objectForKey:@"datacolumnindex"] integerValue]];
		if ([aValue isNSNull]) {
			[argumentParts addObject:[NSString stringWithFormat:@"%@ IS NULL", [[field objectForKey:@"org_name"] backtickQuotedString]]];
		} else {
			NSString *fieldTypeGrouping = [field objectForKey:@"typegrouping"];

			// Skip blob-type fields if requested
			if (!includeBlobs
				&& ([fieldTypeGrouping isEqualToString:@"textdata"]
					||  [fieldTypeGrouping isEqualToString:@"blobdata"]
					|| [[field objectForKey:@"type"] isEqualToString:@"BINARY"]
					|| [[field objectForKey:@"type"] isEqualToString:@"VARBINARY"]))
			{
				continue;
			}

			// If the field is of type BIT then it needs a binary prefix
			if ([fieldTypeGrouping isEqualToString:@"bit"]) {
				[argumentParts addObject:[NSString stringWithFormat:@"%@=b'%@'", [[field objectForKey:@"org_name"] backtickQuotedString], [aValue description]]];
			}
			else if ([fieldTypeGrouping isEqualToString:@"geometry"]) {
				[argumentParts addObject:[NSString stringWithFormat:@"%@=%@", [[field objectForKey:@"org_name"] backtickQuotedString], [mySQLConnection escapeAndQuoteData:[aValue data]]]];
			}
			// BLOB/TEXT data
			else if ([aValue isKindOfClass:[NSData class]]) {
				[argumentParts addObject:[NSString stringWithFormat:@"%@=%@", [[field objectForKey:@"org_name"] backtickQuotedString], [mySQLConnection escapeAndQuoteData:aValue]]];
			}
			else {
				[argumentParts addObject:[NSString stringWithFormat:@"%@=%@", [[field objectForKey:@"org_name"] backtickQuotedString], [mySQLConnection escapeAndQuoteString:aValue]]];
			}
		}
	}

	// Check for empty strings
	if (![argumentParts count]) return nil;

	return [NSString stringWithFormat:@"WHERE (%@)", [argumentParts componentsJoinedByString:@" AND "]];
}

- (void)saveCellValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSUInteger)rowIndex
{
	NSDictionary *columnDefinition = [cqColumnDefinition objectAtIndex:[[aTableColumn identifier] integerValue]];
	NSString *columnTypeGroup = [columnDefinition objectForKey:@"typegrouping"];

	// Resolve the original table name for current column if AS was used
	NSString *tableForColumn = [columnDefinition objectForKey:@"org_table"];

	if(!tableForColumn || ![tableForColumn length]) {
		[errorTextTitle setStringValue:NSLocalizedString(@"Last Error Message", @"Last Error Message")];
		[errorText setString:[NSString stringWithFormat:NSLocalizedString(@"Couldn't identify field origin unambiguously. The column '%@' contains data from more than one table.", @"Custom Query result editing error - could not identify a corresponding column"), [columnDefinition objectForKey:@"name"]]];
		NSBeep();
		return;
	}

	// Resolve the original column name if AS was used
	NSString *columnName = [columnDefinition objectForKey:@"org_name"];

	// Check if the IDstring identifies the current field bijectively and get the WHERE clause
	NSArray *editStatus = [self fieldEditStatusForRow:rowIndex andColumn:[[aTableColumn identifier] integerValue]];
	fieldIDQueryString = [editStatus objectAtIndex:1];
	NSInteger numberOfPossibleUpdateRows = [[editStatus objectAtIndex:0] integerValue];

	if(numberOfPossibleUpdateRows == 1) {

		NSString *newObject = nil;
		if ( [anObject isKindOfClass:[NSCalendarDate class]] ) {
			newObject = [mySQLConnection escapeAndQuoteString:[anObject description]];
		} else if ( [anObject isKindOfClass:[NSNumber class]] ) {
			newObject = [anObject stringValue];
		} else if ( [anObject isKindOfClass:[NSData class]] ) {
			newObject = [mySQLConnection escapeAndQuoteData:anObject];
		} else {
			NSString *desc = [anObject description];
			if ( [desc isMatchedByRegex:SPCurrentTimestampPattern] ) {
				newObject = desc;
			} else if ([anObject isEqualToString:[prefs stringForKey:SPNullValue]]
						|| (([columnTypeGroup isEqualToString:@"float"] || [columnTypeGroup isEqualToString:@"integer"] || [columnTypeGroup isEqualToString:@"date"])
							&& [desc isEqualToString:@""]))
			{
				newObject = @"NULL";
			} else if ([columnTypeGroup isEqualToString:@"geometry"]) {
				newObject = [(NSString*)anObject getGeomFromTextString];
			} else if ([columnTypeGroup isEqualToString:@"bit"]) {
				newObject = [NSString stringWithFormat:@"b'%@'", ((![desc length] || [desc isEqualToString:@"0"]) ? @"0" : desc)];
			} else if ([columnTypeGroup isEqualToString:@"date"]
						&& [desc isEqualToString:@"NOW()"]) {
				newObject = @"NOW()";
			} else {
				newObject = [mySQLConnection escapeAndQuoteString:desc];
			}
		}

		[mySQLConnection queryString:
			[NSString stringWithFormat:@"UPDATE %@.%@ SET %@.%@.%@ = %@ %@ LIMIT 1",
				[[columnDefinition objectForKey:@"db"] backtickQuotedString], [[columnDefinition objectForKey:@"org_table"] backtickQuotedString],
				[[columnDefinition objectForKey:@"db"] backtickQuotedString], [[columnDefinition objectForKey:@"org_table"] backtickQuotedString], [columnName backtickQuotedString], newObject, fieldIDQueryString]];

		// Check for errors while UPDATE
		if ([mySQLConnection queryErrored]) {
			SPOnewayAlertSheet(
				NSLocalizedString(@"Error", @"error"),
				[tableDocumentInstance parentWindow],
				[NSString stringWithFormat:NSLocalizedString(@"Couldn't write field.\nMySQL said: %@", @"message of panel when error while updating field to db"), [mySQLConnection lastErrorMessage]]
			);
			return;
		}

		// This shouldn't happen – for safety reasons
		if ( ![mySQLConnection rowsAffectedByLastQuery] ) {
#ifndef SP_CODA
			if ( [prefs boolForKey:SPShowNoAffectedRowsError] ) {
				SPOnewayAlertSheet(
					NSLocalizedString(@"Warning", @"warning"),
					[tableDocumentInstance parentWindow],
					NSLocalizedString(@"The row was not written to the MySQL database. You probably haven't changed anything.\nReload the table to be sure that the row exists and use a primary key for your table.\n(This error can be turned off in the preferences.)", @"message of panel when no rows have been affected after writing to the db")
				);
			} else {
				NSBeep();
			}
#endif
			return;
		}

		// On success reload table data by executing the last query if reloading is enabled
#ifndef SP_CODA
		if ([prefs boolForKey:SPReloadAfterEditingRow]) {
			reloadingExistingResult = YES;
			[self storeCurrentResultViewForRestoration];
			[self performQueries:@[lastExecutedQuery] withCallback:NULL];
		} else {
#endif
			// otherwise, just update the data in the data storage
			[resultData replaceObjectInRow:rowIndex column:[[aTableColumn identifier] intValue] withObject:anObject];
#ifndef SP_CODA
		}
#endif
	} else {
		SPOnewayAlertSheet(
			NSLocalizedString(@"Error", @"error"),
			[tableDocumentInstance parentWindow],
			[NSString stringWithFormat:NSLocalizedString(@"Updating field content failed. Couldn't identify field origin unambiguously (%1$ld matches). It's very likely that while editing this field of table `%2$@` was changed.", @"message of panel when error while updating field to db after enabling it"), (numberOfPossibleUpdateRows<1)?0:numberOfPossibleUpdateRows, [columnDefinition objectForKey:@"org_table"]]
		);
	}
}

#pragma mark -
#pragma mark TableView datasource methods

/**
 * Returns the number of rows in the result set table view.
 */
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return (aTableView == customQueryView) ? (resultData == nil) ? 0 : [resultData count] : 0;
}

/**
 * This function changes the text color of text/blob fields whose content is NULL.
 */
- (void)tableView:(SPCopyTable *)aTableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex
{
	if (aTableView == customQueryView) {

		if (![cell respondsToSelector:@selector(setTextColor:)]) {
			return;
		}

		// For NULL cell's display the user's NULL value placeholder in grey to easily distinguish it from other values
		BOOL showCellAsGray = NO;

		NSUInteger columnIndex = [[aTableColumn identifier] integerValue];

		// While the table is being loaded, additional validation is required - data
		// locks must be used to avoid crashes, and indexes higher than the available
		// rows or columns may be requested.  Use gray to show loading in these cases.
		if (isWorking) {
			pthread_mutex_lock(&resultDataLock);
				
			if (SPIntS2U(rowIndex) < [resultData count] && columnIndex < [resultData columnCount]) {
				showCellAsGray = [resultData cellIsNullOrUnloadedAtRow:rowIndex column:columnIndex];
			} else {
				showCellAsGray = YES;
			}

			pthread_mutex_unlock(&resultDataLock);
		}
		else {
			showCellAsGray = [resultData cellIsNullOrUnloadedAtRow:rowIndex column:columnIndex];
		}

		[cell setTextColor:showCellAsGray ? [NSColor lightGrayColor] : [NSColor controlTextColor]];
	}
}

/**
 * Returns the object for the requested column and row index.
 */
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if (aTableView == customQueryView) {
		NSUInteger columnIndex = [[tableColumn identifier] integerValue];
		// if a user enters the field by keyboard navigation they might want to copy the contents without invoking the field editor sheet first
		BOOL forEditing = ([customQueryView editedColumn] == (NSInteger)columnIndex && [customQueryView editedRow] == rowIndex);
		return [self _resultDataItemAtRow:rowIndex columnIndex:[[tableColumn identifier] integerValue] preserveNULLs:NO asPreview:(forEditing != YES)];
	}

	return @"";
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if (aTableView == customQueryView) {

		// If the current cell should have been edited in a sheet, do nothing - field closing will have already
		// updated the field.
		if ([customQueryView shouldUseFieldEditorForRow:rowIndex column:[[aTableColumn identifier] integerValue] checkWithLock:NULL]) {
			return;
		}

		// Otherwise trigger a save
		[self saveCellValue:anObject forTableColumn:aTableColumn row:rowIndex];
	}
}

/**
 * Change the sort order by clicking at a column header
 */
- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
	// Prevent sorting while a query is running
	if ([tableDocumentInstance isWorking]) return;
	if (!cqColumnDefinition || ![cqColumnDefinition count]) return;

	NSMutableString *queryString = [NSMutableString stringWithString:lastExecutedQuery];

	NSEventModifierFlags modifierFlags = [[NSApp currentEvent] modifierFlags];
    
	// Sets column order as tri-state descending, ascending, no sort, descending, ascending etc. order if the same
	// header is clicked several times
	if (sortField && [[tableColumn identifier] integerValue] == [sortField integerValue]) {
        BOOL invert = NO;
        if (modifierFlags & NSEventModifierFlagShift) {
            invert = YES;
        }
        
        // this is the same as saying (isDesc && !invert) || (!isDesc && invert)
        if (isDesc != invert) {
			SPClear(sortField);
		} else {
			isDesc = !isDesc;
		}
	} else {
        // When the column is not sorted, allow to sort in reverse order using Shift+click
        if (modifierFlags & NSEventModifierFlagShift) {
            isDesc = YES;
        } else {
            isDesc = NO;
        }
        
		[[customQueryView onMainThread] setIndicatorImage:nil inTableColumn:[customQueryView tableColumnWithIdentifier:[NSString stringWithFormat:@"%lld", (long long)[sortField integerValue]]]];
		if (sortField) [sortField release];
		sortField = [[NSNumber alloc] initWithInteger:[[tableColumn identifier] integerValue]];
	}

	if(sortField) {
		// Set the highlight and indicatorImage
		[[customQueryView onMainThread] setHighlightedTableColumn:tableColumn];
		if (isDesc) {
			[[customQueryView onMainThread] setIndicatorImage:[NSImage imageNamed:@"NSDescendingSortIndicator"] inTableColumn:tableColumn];
		} else {
			[[customQueryView onMainThread] setIndicatorImage:[NSImage imageNamed:@"NSAscendingSortIndicator"] inTableColumn:tableColumn];
		}
	} else {
		// If no sort order deselect column header and
		// remove indicator image
		[[customQueryView onMainThread] setHighlightedTableColumn:nil];
		[[customQueryView onMainThread] setIndicatorImage:nil inTableColumn:tableColumn];
	}

	// Order by the column position number to avoid ambiguous name errors if any
	NSString* newOrder;
	if(sortField)
		newOrder = [NSString stringWithFormat:@" ORDER BY %ld %@ ", (long)([[tableColumn identifier] integerValue]+1), (isDesc)?@"DESC":@"ASC"];
	else
		newOrder = @"";

	// Remove any comments
	[queryString replaceOccurrencesOfRegex:@"--.*?\n" withString:@""];
	[queryString replaceOccurrencesOfRegex:@"--.*?$" withString:@""];
	[queryString replaceOccurrencesOfRegex:@"/\\*(.|\n)*?\\*/" withString:@""];

	// Remove all quoted strings as a temp string to match the correct clauses
	NSRange matchedRange;
	NSUInteger i;
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
	if(sortField)
		sortColumn = tableColumn;
	else
		sortColumn = nil;
	[self performQueries:@[queryString] withCallback:@selector(tableSortCallback)];
}

- (void)tableSortCallback
{
	queryIsTableSorter = NO;

	if ([mySQLConnection queryErrored]) {
		sortColumn = nil;
		if(sortField) SPClear(sortField);
		return;
	}

	[[customQueryView onMainThread] setNeedsDisplay:YES];

}

#pragma mark -
#pragma mark TableView Drag & Drop datasource methods

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rows toPasteboard:(NSPasteboard*)pboard
{
	if ( aTableView == customQueryView ) {
		NSString *tmp = [customQueryView draggedRowsAsTabString];
		if ( nil != tmp )
		{
			[pboard declareTypes:@[NSTabularTextPboardType, NSStringPboardType] owner:nil];
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
			if ([[pboardTypes objectAtIndex:0] isEqualToString:SPDefaultPasteboardDragType]==YES && operation==NSTableViewDropAbove)
			{
				originalRow = [[[info draggingPasteboard] stringForType:SPDefaultPasteboardDragType] intValue];

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
		originalRow = [[[info draggingPasteboard] stringForType:SPDefaultPasteboardDragType] intValue];
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

	// Suppress tooltip if another toolip is already visible, mainly displayed by a Bundle command
	// TODO has to be improved
	for(id win in [NSApp orderedWindows]) {
		if([[[[win contentView] class] description] isEqualToString:@"WebView"]) {
			return nil;
		}
	}

	NSImage *image;

	NSPoint pos = [NSEvent mouseLocation];
	pos.y -= 20;

	id theValue = nil;

	// While the table is being loaded, additional validation is required - data
	// locks must be used to avoid crashes, and indexes higher than the available
	// rows or columns may be requested.  Return "..." to indicate loading in these
	// cases.
	if (isWorking) {
		pthread_mutex_lock(&resultDataLock);
		if (SPIntS2U(row) < [resultData count] && (NSUInteger)[[aTableColumn identifier] integerValue] < [resultData columnCount]) {
			theValue = [[SPDataStorageObjectAtRowAndColumn(resultData, row, [[aTableColumn identifier] integerValue]) copy] autorelease];
		}
		pthread_mutex_unlock(&resultDataLock);

		if (!theValue) theValue = @"...";
	} else {
		theValue = SPDataStorageObjectAtRowAndColumn(resultData, row, [[aTableColumn identifier] integerValue]);
	}

	if(theValue == nil) return nil;

	// Get the original data for trying to display the blob data as an image
	if ([theValue isKindOfClass:[NSData class]]) {
		image = [[[NSImage alloc] initWithData:theValue] autorelease];
		if(image) {
			[SPTooltip showWithObject:image atLocation:pos ofType:@"image"];
			return nil;
		}
	}
	else if ([theValue isKindOfClass:[SPMySQLGeometryData class]]) {
		SPGeometryDataView *v = [[SPGeometryDataView alloc] initWithCoordinates:[theValue coordinates]];
		image = [v thumbnailImage];
		if(image) {
			[SPTooltip showWithObject:image atLocation:pos ofType:@"image"];
			[v release];
			return nil;
		}
		[v release];
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

/**
 * Double-click action on a field
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	// Only allow editing if a task is not active
	if ([tableDocumentInstance isWorking]) return NO;

	// Check if the field can identified bijectively
	if ( aTableView == customQueryView ) {
		
		// Nothing is editable while the field editor is running.
		// This guards against a special case where accessibility services might
		// check if a table field is editable while the sheet is running.
		if (fieldEditor) return NO;
		
		NSDictionary *columnDefinition = [cqColumnDefinition objectAtIndex:[[aTableColumn identifier] integerValue]];

		// Check if current field is a blob
		BOOL isBlob = ([[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"textdata"]
						|| [[columnDefinition objectForKey:@"typegrouping"] isEqualToString:@"blobdata"]);

		// Open the editing sheet if required
		if ([customQueryView shouldUseFieldEditorForRow:rowIndex column:[[aTableColumn identifier] integerValue] checkWithLock:NULL])
		{
			fieldEditor = [[SPFieldEditorController alloc] init];

			// Remember edited row for reselecting and setting the scroll view after reload
			editedRow = rowIndex;
			editedScrollViewRect = [customQueryScrollView documentVisibleRect];

			NSInteger editedColumn = 0;
			for (NSTableColumn* col in [customQueryView tableColumns]) {
				if([[col identifier] isEqualToString:[aTableColumn identifier]]) break;
				editedColumn++;
			}

			NSArray *editStatus = [self fieldEditStatusForRow:rowIndex andColumn:[[aTableColumn identifier] integerValue]];
			isFieldEditable = ([[editStatus objectAtIndex:0] integerValue] == 1) ? YES : NO;

			NSString *fieldType = nil;
			NSUInteger fieldLength = 0;
			NSString *fieldEncoding = nil;
			BOOL allowNULL = YES;

			// Retrieve the column defintion
			fieldType = [columnDefinition objectForKey:@"type"];
			if([columnDefinition objectForKey:@"char_length"])
				fieldLength = [[columnDefinition objectForKey:@"char_length"] integerValue];
			if([columnDefinition objectForKey:@"charset_name"] && ![[columnDefinition objectForKey:@"charset_name"] isEqualToString:@"binary"])
				fieldEncoding = [columnDefinition objectForKey:@"charset_name"];
			if([columnDefinition objectForKey:@"null"])
				allowNULL = (![[columnDefinition objectForKey:@"null"] integerValue]);

			[fieldEditor setEditedFieldInfo:[NSDictionary dictionaryWithObjectsAndKeys:
				[columnDefinition objectForKey:@"org_name"], @"colName",
				[columnDefinition objectForKey:@"org_table"], @"tableName",
				[self usedQuery], @"usedQuery",
				@"query", @"tableSource",
				nil]];

			[fieldEditor setTextMaxLength:fieldLength];
			[fieldEditor setFieldType:(fieldType==nil) ? @"" : fieldType];
			[fieldEditor setFieldEncoding:(fieldEncoding==nil) ? @"" : fieldEncoding];
			[fieldEditor setAllowNULL:allowNULL];

			id originalData = [resultData cellDataAtRow:rowIndex column:[[aTableColumn identifier] integerValue]];
			if ([originalData isNSNull])
				originalData = [NSString stringWithString:[prefs objectForKey:SPNullValue]];

			[fieldEditor editWithObject:originalData
							fieldName:[columnDefinition objectForKey:@"name"]
							usingEncoding:[mySQLConnection stringEncoding] 
							isObjectBlob:isBlob 
							isEditable:isFieldEditable 
							withWindow:[tableDocumentInstance parentWindow]
								sender:self
						   contextInfo:[NSDictionary dictionaryWithObjectsAndKeys:
											[NSNumber numberWithInteger:rowIndex], @"rowIndex",
											[NSNumber numberWithInteger:editedColumn], @"columnIndex",
											[NSNumber numberWithBool:isFieldEditable], @"isFieldEditable",
											nil]];

			return NO;
		}

		return YES;
	} 
	else {
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
 * Check triggering of Bundle command for row selection changes
 */
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{

	// Check our notification object is our table content view
	if ([aNotification object] != customQueryView) return;
	
#ifndef SP_CODA /* triggered commands */
	NSArray *triggeredCommands = [SPAppDelegate bundleCommandsForTrigger:SPBundleTriggerActionTableRowChanged];
	for(NSString* cmdPath in triggeredCommands) {
		NSArray *data = [cmdPath componentsSeparatedByString:@"|"];
		NSMenuItem *aMenuItem = [[[NSMenuItem alloc] init] autorelease];
		[aMenuItem setTag:0];
		[aMenuItem setToolTip:[data objectAtIndex:0]];

		// For HTML output check if corresponding window already exists
		BOOL stopTrigger = NO;
		if ([(NSString *)[data objectAtIndex:2] length]) {
			BOOL correspondingWindowFound = NO;
			NSString *uuid = [data objectAtIndex:2];
			for (id win in [NSApp windows]) {
				if ([[[[win delegate] class] description] isEqualToString:@"SPBundleHTMLOutputController"]) {
					if ([[[win delegate] windowUUID] isEqualToString:uuid]) {
						correspondingWindowFound = YES;
						break;
					}
				}
			}
			if(!correspondingWindowFound) stopTrigger = YES;
		}
		if(!stopTrigger) {
			id firstResponder = [[NSApp keyWindow] firstResponder];
			if([[data objectAtIndex:1] isEqualToString:SPBundleScopeGeneral]) {
				[[SPAppDelegate onMainThread] executeBundleItemForApp:aMenuItem];
			}
			else if([[data objectAtIndex:1] isEqualToString:SPBundleScopeDataTable]) {
				if([[[firstResponder class] description] isEqualToString:@"SPCopyTable"])
					[[firstResponder onMainThread] executeBundleItemForDataTable:aMenuItem];
			}
			else if([[data objectAtIndex:1] isEqualToString:SPBundleScopeInputField]) {
				if([firstResponder isKindOfClass:[NSTextView class]])
					[[firstResponder onMainThread] executeBundleItemForInputField:aMenuItem];
			}
		}
	}
#endif
}

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
	NSString *table = [columnDefinition objectForKey:@"org_table"];
	NSString *col = [columnDefinition objectForKey:@"org_name"];

	// Don't save if the column doesn't map to an underlying SQL field
	if (!table || ![table length] || !col || ![col length])
		return;

	NSMutableDictionary *tableColumnWidths;
	NSString *host_db = [NSString stringWithFormat:@"%@@%@", [columnDefinition objectForKey:@"db"], [tableDocumentInstance host]];

	// Retrieve or instantiate the tableColumnWidths object
#ifndef SP_CODA
	if ([prefs objectForKey:SPTableColumnWidths] != nil) {
		tableColumnWidths = [NSMutableDictionary dictionaryWithDictionary:[prefs objectForKey:SPTableColumnWidths]];
	} else {
#endif
		tableColumnWidths = [NSMutableDictionary dictionary];
#ifndef SP_CODA
	}
#endif

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
#ifndef SP_CODA
	[prefs setObject:tableColumnWidths forKey:SPTableColumnWidths];
#endif
}

/**
 * Resize a column when it's double-clicked.  (10.6+)
 */
- (CGFloat)tableView:(NSTableView *)tableView sizeToFitWidthOfColumn:(NSInteger)columnIndex
{
	NSTableColumn *theColumn = [[tableView tableColumns] objectAtIndex:columnIndex];
	NSDictionary *columnDefinition = [cqColumnDefinition objectAtIndex:[[theColumn identifier] integerValue]];

	// Get the column width
	NSUInteger targetWidth = [customQueryView autodetectWidthForColumnDefinition:columnDefinition maxRows:500];

	// Clear any saved widths for the column
#ifndef SP_CODA
	NSString *dbKey = [NSString stringWithFormat:@"%@@%@", [tableDocumentInstance database], [tableDocumentInstance host]];
	NSString *tableKey = [tablesListInstance tableName];
	NSMutableDictionary *savedWidths = [NSMutableDictionary dictionaryWithDictionary:[prefs objectForKey:SPTableColumnWidths]];
	NSMutableDictionary *dbDict = [NSMutableDictionary dictionaryWithDictionary:[savedWidths objectForKey:dbKey]];
	NSMutableDictionary *tableDict = [NSMutableDictionary dictionaryWithDictionary:[dbDict objectForKey:tableKey]];
	if ([tableDict objectForKey:[columnDefinition objectForKey:@"name"]]) {
		[tableDict removeObjectForKey:[columnDefinition objectForKey:@"name"]];
		if ([tableDict count]) {
			[dbDict setObject:[NSDictionary dictionaryWithDictionary:tableDict] forKey:tableKey];
		} else {
			[dbDict removeObjectForKey:tableKey];
		}
		if ([dbDict count]) {
			[savedWidths setObject:[NSDictionary dictionaryWithDictionary:dbDict] forKey:dbKey];
		} else {
			[savedWidths removeObjectForKey:dbKey];
		}
		[prefs setObject:[NSDictionary dictionaryWithDictionary:savedWidths] forKey:SPTableColumnWidths];
	}
#endif

	// Return the width, while the delegate is empty to prevent column resize notifications
	[customQueryView setDelegate:nil];
	[customQueryView performSelector:@selector(setDelegate:) withObject:self afterDelay:0.1];
	
	return targetWidth;
}

#pragma mark -
#pragma mark TextView delegate methods

/**
 * Traps enter key and performs query instead of inserting a line break if aTextView == textView
 * closes valueSheet if aTextView == valueTextField
 */
- (BOOL)textView:(NSTextView *)aTextView doCommandBySelector:(SEL)aSelector
{
	if (aTextView == textView) {
		if ([aTextView methodForSelector:aSelector] == [aTextView methodForSelector:@selector(insertNewline:)] &&
			[[[NSApp currentEvent] characters] isEqualToString:@"\003"]) {
			[self runPrimaryQueryAction:self];
			
			return YES;
		} 
		else {
			return NO;
		}

	} 
	else if (aTextView == valueTextField) {
		if ([aTextView methodForSelector:aSelector] == [aTextView methodForSelector:@selector(insertNewline:)]) {
			[self closeSheet:self];
			
			return YES;
		} 
		else {
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
	if (!newSelectedCharRange.length && [textView isSnippetMode]) [textView checkForCaretInsideSnippet];

	return newSelectedCharRange;
}

/**
 * A notification posted when the selection changes within the text view;
 * used to control the run-currentrun-selection button state and action.
 */
- (void)textViewDidChangeSelection:(NSNotification *)aNotification
{
	// Ensure that the notification is from the custom query text view
	if ( [aNotification object] != textView ) return;

	NSRange currentSelection = [textView selectedRange];
	NSUInteger caretPosition = currentSelection.location;

	// Detect the current query range, allowing the search to occur if the caret is after
	// a semicolon
	currentQueryBeforeCaret = YES;
	currentQueryRange = [self queryRangeAtPosition:caretPosition lookBehind:&currentQueryBeforeCaret];

	[textView setQueryRange:currentQueryRange];
	[textView setNeedsDisplayInRect:[textView bounds]];

	// If a query range is selected, update the current query range and menu actions
	if (currentQueryRange.length) {
		[commentCurrentQueryMenuItem setEnabled:YES];
	} else {
		currentQueryRange = NSMakeRange(0, 0);
		[commentCurrentQueryMenuItem setEnabled:NO];
	}

	// Vary the comment/line selection menu item according to whether a section is present
	if (currentSelection.length) {
		[commentLineOrSelectionMenuItem setTitle:NSLocalizedString(@"Comment Selection", @"Title of action menu item to comment selection")];
	} else {
		[commentLineOrSelectionMenuItem setTitle:NSLocalizedString(@"Comment Line", @"Title of action menu item to comment line")];
	}

	if (!historyItemWasJustInserted)
		currentHistoryOffsetIndex = -1;

	// Update the text of the contextual run current/previous/selection button and menu item
	[self updateContextualRunInterface];
}

#pragma mark -
#pragma mark TextField delegate methods

/**
 * Called whenever the user changes the name of the new query favorite or
 * the user changed the query favorite search string.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
#ifndef SP_CODA
	if ([notification object] == queryFavoriteNameTextField)
		[saveQueryFavoriteButton setEnabled:[[queryFavoriteNameTextField stringValue] length]];
	else if ([notification object] == queryFavoritesSearchField){
		[self filterQueryFavorites:nil];
	}
	else if ([notification object] == queryHistorySearchField) {
		[self filterQueryHistory:nil];
	}
#endif
}

#ifndef SP_CODA
- (NSUndoManager *)undoManagerForTextView:(NSTextView *)aTextView
{
	return [tableDocumentInstance undoManager];
}
#endif

#pragma mark -
#pragma mark SplitView delegate methods

#ifndef SP_CODA /* splitview delegate methods */

/**
 * Tells the split views that they can collapse views
 */
- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	// TODO: The query editor/results split view must not be collapsible, because both subviews would be collapsible, and the SPSplitView code expects only 1 collapsible subview max.
	return (sender == queryInfoPaneSplitView);
}

/**
 * The query information pane cannot be resized.
 */
- (NSRect)splitView:(NSSplitView *)splitView effectiveRect:(NSRect)proposedEffectiveRect forDrawnRect:(NSRect)drawnRect ofDividerAtIndex:(NSInteger)dividerIndex
{
	return (splitView == queryInfoPaneSplitView ? NSZeroRect : proposedEffectiveRect);
}

#endif

/**
 * Set the MySQL version as X.Y
 */
- (void)setMySQLversion:(NSString *)theVersion
{
	[textView setConnection:mySQLConnection withVersion:[[[[theVersion substringToIndex:3] componentsSeparatedByString:@"."] objectAtIndex:0] integerValue]];
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

#ifndef SP_CODA
/**
 * Show the data for "HELP 'currentWord' invoked by autohelp"
 */
- (void)showAutoHelpForCurrentWord:(id)sender
{
	NSString *searchString = [[sender string] substringWithRange:[sender getRangeForCurrentWord]];
	[[tableDocumentInstance helpViewerClient] showHelpFor:searchString addToHistory:YES calledByAutoHelp:YES];
}

/**
 * Detect when the help window is closed (manually) and disable autohelp to ensure it
 * isn't reopened on keypresses.
 */
- (void)helpWindowClosedByUser:(NSNotification *)notification
{
	if ([notification object] != [tableDocumentInstance helpViewerClient]) return;

	//TODO: this doesn't belong in the document context, since multiple open documents can become out of sync through this
	[prefs setBool:NO forKey:SPCustomQueryUpdateAutoHelp];
	[prefs synchronize];
	[autohelpMenuItem setState:NSOffState];
	[textView setAutohelp:NO];
}

#endif

#pragma mark -
#pragma mark Query favorites manager delegate methods

#ifndef SP_CODA

/**
 * Rebuild history popup menu.
 *
 * Warning: notification may be nil if invoked directly from within this class.
 *
 * MUST BE CALLED ON THE UI THREAD!
 */
- (void)historyItemsHaveBeenUpdated:(NSNotification *)notification
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

	// Reapply the filter
	[self filterQueryHistory:nil];
}

/**
 * Called by the query favorites manager whenever the query favorites have been updated.
 */
- (void)queryFavoritesHaveBeenUpdated:(NSNotification *)notification
{
	NSURL *fileURL = [tableDocumentInstance fileURL];

	// Warning: This method may be called before any connection has been made in the current tab (triggered by another tab)!
	// There doesn't seem to be a real indicator for this, but fileURL is the closest thing plus we need it below (#2266)
	if(!fileURL) return;

	NSMenu *menu = [queryFavoritesButton menu];

	// Remove all favorites beginning from the end
	while([queryFavoritesButton numberOfItems] > 7)
		[queryFavoritesButton removeItemAtIndex:[queryFavoritesButton numberOfItems]-1];

	// Build document-based list
	NSString *tblDocName = [[[fileURL absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] lastPathComponent];
	{
		NSMenuItem *headerMenuItem = [[NSMenuItem alloc] initWithTitle:tblDocName action:NULL keyEquivalent:@""];
		[headerMenuItem setTag:SP_FAVORITE_HEADER_MENUITEM_TAG];
		[headerMenuItem setToolTip:[NSString stringWithFormat:NSLocalizedString(@"‘%@’ based favorites",@"Query Favorites : List : Section Heading : current connection document : tooltip (arg is the name of the spf file)"), tblDocName]];
		[headerMenuItem setIndentationLevel:0];
		[menu addItem:headerMenuItem];
		[headerMenuItem release];
	}
	for (NSDictionary *favorite in [[SPQueryController sharedQueryController] favoritesForFileURL:fileURL]) {
		if (![favorite isKindOfClass:[NSDictionary class]] || ![favorite objectForKey:@"name"]) continue;
		NSMutableParagraphStyle *paraStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
		[paraStyle setTabStops:@[]];
		[paraStyle addTabStop:[[[NSTextTab alloc] initWithType:NSRightTabStopType location:190.0f] autorelease]];
		NSDictionary *attributes = @{NSParagraphStyleAttributeName : paraStyle, NSFontAttributeName : [NSFont systemFontOfSize:11]};
		NSAttributedString *titleString = [[[NSAttributedString alloc] initWithString:([favorite objectForKey:@"tabtrigger"] && [(NSString*)[favorite objectForKey:@"tabtrigger"] length]) ? [NSString stringWithFormat:@"%@\t%@⇥", [favorite objectForKey:@"name"], [favorite objectForKey:@"tabtrigger"]] : [favorite objectForKey:@"name"]
		                                                                   attributes:attributes] autorelease];
		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
		if ([favorite objectForKey:@"query"]) {
			[item setToolTip:[NSString stringWithString:[favorite objectForKey:@"query"]]];
		}
		[item setAttributedTitle:titleString];
		[item setIndentationLevel:1];
		[menu addItem:item];
		[item release];
	}

	// Build global list
	{
		NSMenuItem *headerMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Global",@"Query Favorites : List : Section Heading : global query favorites") action:NULL keyEquivalent:@""];
		[headerMenuItem setTag:SP_FAVORITE_HEADER_MENUITEM_TAG];
		[headerMenuItem setToolTip:NSLocalizedString(@"Globally stored favorites",@"Query Favorites : List : Section Heading : global : tooltip")];
		[headerMenuItem setIndentationLevel:0];
		[menu addItem:headerMenuItem];
		[headerMenuItem release];
	}
	for (NSDictionary *favorite in [prefs objectForKey:SPQueryFavorites]) {
		if (![favorite isKindOfClass:[NSDictionary class]] || ![favorite objectForKey:@"name"]) continue;
		NSMutableParagraphStyle *paraStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
		[paraStyle setTabStops:@[]];
		[paraStyle addTabStop:[[[NSTextTab alloc] initWithType:NSRightTabStopType location:190.0f] autorelease]];
		NSDictionary *attributes = @{NSParagraphStyleAttributeName : paraStyle, NSFontAttributeName : [NSFont systemFontOfSize:11]};
		NSAttributedString *titleString = [[[NSAttributedString alloc] initWithString:([favorite objectForKey:@"tabtrigger"] && [(NSString*)[favorite objectForKey:@"tabtrigger"] length]) ? [NSString stringWithFormat:@"%@\t%@⇥", [favorite objectForKey:@"name"], [favorite objectForKey:@"tabtrigger"]] : [favorite objectForKey:@"name"]
		                                                                   attributes:attributes] autorelease];
		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
		if ([favorite objectForKey:@"query"]) {
			[item setToolTip:[NSString stringWithString:[favorite objectForKey:@"query"]]];
		}
		[item setAttributedTitle:titleString];
		[item setIndentationLevel:1];
		[menu addItem:item];
		[item release];
	}

	// Reapply the filter
	[self filterQueryFavorites:nil];
}
#endif

#pragma mark -
#pragma mark Database content view delegate methods

- (NSString *)usedQuery
{
	return usedQuery;
}

/**
 * Provide a getter for the custom query result table's current viewport
 */
- (NSArray *)dataColumnDefinitions
{
	return cqColumnDefinition;
}

#pragma mark -
#pragma mark Task interaction

/**
 * Disable all content interactive elements during an ongoing task.
 */
- (void) startDocumentTaskForTab:(NSNotification *)aNotification
{
	isWorking = YES;

#ifndef SP_CODA /* check selected view */
	// Only proceed if this view is selected.
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarCustomQuery])
		return;
#endif

	tableRowsSelectable = NO;
	[runAllButton setEnabled:NO];
	[runPrimaryActionButton setEnabled:NO];
	[runPrimaryActionMenuItem setEnabled:NO];
	[runSecondaryActionMenuItem setEnabled:NO];
}

/**
 * Enable all content interactive elements after an ongoing task.
 */
- (void) endDocumentTaskForTab:(NSNotification *)aNotification
{
	isWorking = NO;

#ifndef SP_CODA /* check active tab */
	// Only proceed if this view is selected.
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarCustomQuery])
		return;
#endif

	tableRowsSelectable = YES;
	[runAllButton setEnabled:YES];
	[runPrimaryActionButton setEnabled:YES];
	[runPrimaryActionMenuItem setEnabled:YES];
	[runSecondaryActionMenuItem setEnabled:YES];
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

/**
 * Returns the range of the current active query.
 */
- (NSRange)currentQueryRange
{
	return currentQueryRange;
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

/**
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
		[customQueryView setRowHeight:2.0f+NSSizeToCGSize([@"{ǞṶḹÜ∑zgyf" sizeWithAttributes:@{NSFontAttributeName : tableFont}]).height];
		[customQueryView setFont:tableFont];
		[customQueryView reloadData];
	}
}

/**
 * Called when the save query favorite/clear history sheet is dismissed.
 */
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	if ([contextInfo isEqualToString:@"runAllContinueStopSheet"]) {
		runAllContinueStopSheetReturnCode = returnCode;
		return;
	}

#ifndef SP_CODA
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
							forKeys:@[@"name", @"query"]]];

				[prefs setObject:favorites forKey:SPQueryFavorites];
			} else {
				[[SPQueryController sharedQueryController] addFavorite:[NSMutableDictionary dictionaryWithObjects:
					[NSArray arrayWithObjects:[queryFavoriteNameTextField stringValue], [[queryToBeAddded mutableCopy] autorelease], nil]
						forKeys:@[@"name", @"query"]] forFileURL:[tableDocumentInstance fileURL]];
			}

			[saveQueryFavoriteGlobal setState:NSOffState];

			[self queryFavoritesHaveBeenUpdated:nil];
		}
	}

	[queryFavoriteNameTextField setStringValue:@""];
#endif
}

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
#ifndef SP_CODA
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
#else
	return NO;
#endif
}

- (void)processFieldEditorResult:(id)data contextInfo:(NSDictionary*)contextInfo
{

	NSInteger row = -1;
	NSInteger column = -1;

	if(contextInfo) {
		row = [[contextInfo objectForKey:@"rowIndex"] integerValue];
		column = [[contextInfo objectForKey:@"columnIndex"] integerValue];
	}

	if (data && contextInfo) {
		BOOL isResultFieldEditable = ([contextInfo objectForKey:@"isFieldEditable"]) ? YES : NO;

		if(isResultFieldEditable) {
			[self saveCellValue:[[data copy] autorelease] forTableColumn:[[customQueryView tableColumns] objectAtIndex:column] row:row];
		}
	}

	// this is a delegate method of the field editor controller. calling release
	// now would risk a dealloc while it is still our parent on the stack:
	[fieldEditor autorelease], fieldEditor = nil;

	// Preserve focus and restore selection indexes if appropriate
	[[tableDocumentInstance parentWindow] makeFirstResponder:customQueryView]; 
	if (selectionIndexToRestore)
		[customQueryView selectRowIndexes:selectionIndexToRestore byExtendingSelection:NO];

}

- (void)setFieldEditorSelectedRange:(NSRange)aRange
{
	[customQueryView setFieldEditorSelectedRange:aRange];
}

- (NSRange)fieldEditorSelectedRange
{
	return [customQueryView fieldEditorSelectedRange];
}

#pragma mark -

- (id)init
{
	if ((self = [super init])) {

		usedQuery = [@"" retain];
		lastExecutedQuery = nil;
		fieldIDQueryString = nil;
		sortField = nil;
		isDesc = NO;
		sortColumn = nil;
		isFieldEditable = NO;
		cqColumnDefinition = nil;
		favoritesManager = nil;

		tableRowsSelectable = YES;
		selectionIndexToRestore = nil;
		selectionViewportToRestore = NSZeroRect;

		// init tableView's data source
		resultData = [[SPDataStorage alloc] init];
		editedRow = -1;

		currentHistoryOffsetIndex = -1;
		historyItemWasJustInserted = NO;
		currentQueryRange = NSMakeRange(0, 0);
		currentQueryBeforeCaret = NO;
		runPrimaryActionButtonAsSelection = nil;

		queryLoadTimer = nil;

		prefs = [NSUserDefaults standardUserDefaults];

		kCellEditorErrorNoMatch = NSLocalizedString(@"Field is not editable. No matching record found.\nReload data, check encoding, or try to add\na primary key field or more fields\nin your SELECT statement for table '%@'\nto identify field origin unambiguously.", @"Custom Query result editing error - could not identify original row");
		kCellEditorErrorNoMultiTabDb = NSLocalizedString(@"Field is not editable. Field has no or multiple table or database origin(s).",@"field is not editable due to no table/database");
		kCellEditorErrorTooManyMatches = NSLocalizedString(@"Field is not editable. Couldn't identify field origin unambiguously (%ld matches).", @"Query result editing error - could not match row being edited uniquely");

	}

	return self;
}

#ifndef SP_CODA
/**
 * Filters the query favorites menu.
 */
- (IBAction)filterQueryFavorites:(id)sender
{
	NSMenu *menu = [queryFavoritesButton menu];

	for (NSInteger i = 7; i < [menu numberOfItems]; i++)
	{
		[[menu itemAtIndex:i] setHidden:([[menu itemAtIndex:i] tag] != SP_FAVORITE_HEADER_MENUITEM_TAG
										 && ![[[menu itemAtIndex:i] title] isMatchedByRegex:[NSString stringWithFormat:@"(?i).*%@.*", [queryFavoritesSearchField stringValue]]])];
	}
}

/**
 * Filters the query history menu.
 */
- (IBAction)filterQueryHistory:(id)sender
{
	NSArray *history = [[SPQueryController sharedQueryController] historyForFileURL:[tableDocumentInstance fileURL]];
	
	NSMenu *menu = [queryHistoryButton menu];
	
	for (NSInteger i = 7; i < [menu numberOfItems]; i++)
	{
		[[menu itemAtIndex:i] setHidden:(![[history objectAtIndex:i - 7] isMatchedByRegex:[NSString stringWithFormat:@"(?i).*%@.*", [queryHistorySearchField stringValue]]])];
	}
}
#endif

/**
 * If user selected a table cell which is a blob field and tried to edit it
 * cancel the fieldEditor, display the field editor sheet instead for editing
 * and re-enable the fieldEditor after editing.
 */
- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)aFieldEditor
{
	if(![control isKindOfClass:[SPCopyTable class]]) return YES;

	NSUInteger row, column;
	NSDictionary *columnDefinition = nil;
	BOOL shouldBeginEditing = NO;

	row = [customQueryView editedRow];
	column = [customQueryView editedColumn];

	// Retrieve the column definition
	columnDefinition = [NSDictionary dictionaryWithDictionary:[cqColumnDefinition objectAtIndex:[[[[customQueryView tableColumns] objectAtIndex:column] identifier] integerValue]]];

	if(!columnDefinition) return NO;

	NSArray *editStatus = [self fieldEditStatusForRow:row andColumn:column];
	NSInteger numberOfPossibleUpdateRows = [NSArrayObjectAtIndex(editStatus, 0) integerValue];
	NSPoint pos = [[tableDocumentInstance parentWindow] convertBaseToScreen:[customQueryView convertPoint:[customQueryView frameOfCellAtColumn:column row:row].origin toView:nil]];
	pos.y -= 20;
	switch(numberOfPossibleUpdateRows) {
		case -1:
			NSBeep();
			[SPTooltip showWithObject:kCellEditorErrorNoMultiTabDb
					atLocation:pos
					ofType:@"text"];
			shouldBeginEditing = NO;
		break;

		case 0:
			NSBeep();
			[SPTooltip showWithObject:[NSString stringWithFormat:kCellEditorErrorNoMatch, [columnDefinition objectForKey:@"org_table"]]
					atLocation:pos
					ofType:@"text"];
			shouldBeginEditing = NO;
		break;

		case 1:
			shouldBeginEditing = YES;
		break;

		default:
			NSBeep();
			[SPTooltip showWithObject:[NSString stringWithFormat:kCellEditorErrorTooManyMatches, (long)numberOfPossibleUpdateRows]
					atLocation:pos
					ofType:@"text"];
			shouldBeginEditing = NO;
	}

	isFieldEditable = shouldBeginEditing;

	// Open the field editor sheet if required
	if ([customQueryView shouldUseFieldEditorForRow:row column:column checkWithLock:NULL])
	{

		[customQueryView setFieldEditorSelectedRange:[aFieldEditor selectedRange]];

		// Cancel editing
		[control abortEditing];

		// Call the field editor sheet
		[self tableView:customQueryView shouldEditTableColumn:NSArrayObjectAtIndex([customQueryView tableColumns], column) row:row];

		// send current event to field editor sheet
		if([NSApp currentEvent])
			[NSApp sendEvent:[NSApp currentEvent]];

		return NO;

	}

	// Set editing color to black for NULL values while editing
	// TODO: This method won't be called until the user actually starts typing. The tableView's willDisplayCell delegate call is the proper place to update this (see SPTableContent)
	[aFieldEditor setTextColor:[NSColor controlTextColor]];

	return shouldBeginEditing;
}

/**
 * Abort editing of the Favorite and History search field editors if user presses ARROW UP or DOWN
 * to allow to navigate through the menu item list.
 */
- (BOOL)control:(NSControl*)control textView:(NSTextView*)aTextView doCommandBySelector:(SEL)command
{
#ifndef SP_CODA
	if(control == queryHistorySearchField || control == queryFavoritesSearchField) {
		if(command == @selector(moveDown:) || command == @selector(moveUp:)) {
			[queryHistorySearchField abortEditing];
			[queryFavoritesSearchField abortEditing];

			// Send moveDown/Up to the popup menu
			NSEvent *arrowEvent;
			if(command == @selector(moveDown:))
				arrowEvent = [NSEvent keyEventWithType:NSKeyDown location:NSMakePoint(0,0) modifierFlags:0 timestamp:0 windowNumber:[[tableDocumentInstance parentWindow] windowNumber] context:[NSGraphicsContext currentContext] characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:0x7D];
			else
				arrowEvent = [NSEvent keyEventWithType:NSKeyDown location:NSMakePoint(0,0) modifierFlags:0 timestamp:0 windowNumber:[[tableDocumentInstance parentWindow] windowNumber] context:[NSGraphicsContext currentContext] characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:0x7E];
			[NSApp postEvent:arrowEvent atStart:NO];
			return YES;

		}
	}

	else
#endif
		if([control isKindOfClass:[SPCopyTable class]]) {

		// Check firstly if SPCopyTable can handle command
		if([customQueryView control:control textView:aTextView doCommandBySelector:command])
			return YES;

		// Trap the escape key
		if (  [[control window] methodForSelector:command] == [[control window] methodForSelector:@selector(cancelOperation:)] )
		{

			// Abort editing
			[control abortEditing];

			// Preserve the focus
			[[tableDocumentInstance parentWindow] makeFirstResponder:customQueryView]; 

			return YES;
		}
	}

	return NO;
}

/**
 * Setup various interface controls.
 */
- (void)awakeFromNib
{

	[customQueryView setFieldEditorSelectedRange:NSMakeRange(0,0)];
	[self updateQueryInteractionInterface];

#ifndef SP_CODA
	// Set pre-defined menu tags
	[queryFavoritesSaveAsMenuItem setTag:SP_SAVE_SELECTION_FAVORTITE_MENUITEM_TAG];
	[queryFavoritesSaveAllMenuItem setTag:SP_SAVE_ALL_FAVORTITE_MENUITEM_TAG];
#endif

	// Set up the split views
	[queryEditorSplitView setMinSize:100 ofSubviewAtIndex:0];
	[queryEditorSplitView setMinSize:100 ofSubviewAtIndex:1];

	[queryInfoPaneSplitView setCollapsibleSubviewIndex:1];
	[queryInfoPaneSplitView setCollapsibleSubviewCollapsed:YES animate:NO];
	
	
#ifndef SP_CODA
	// Set the structure and index view's vertical gridlines if required
	[customQueryView setGridStyleMask:([prefs boolForKey:SPDisplayTableViewVerticalGridlines]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
#endif

	// Add observers for document task activity
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(startDocumentTaskForTab:)
												 name:SPDocumentTaskStartNotification
											   object:tableDocumentInstance];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(endDocumentTaskForTab:)
												 name:SPDocumentTaskEndNotification
											   object:tableDocumentInstance];
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(documentWillClose:)
	                                             name:SPDocumentWillCloseNotification
	                                           object:tableDocumentInstance];
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(queryFavoritesHaveBeenUpdated:)
	                                             name:SPQueryFavoritesHaveBeenUpdatedNotification
	                                           object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(historyItemsHaveBeenUpdated:)
	                                             name:SPHistoryItemsHaveBeenUpdatedNotification
	                                           object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(helpWindowClosedByUser:)
	                                             name:SPUserClosedHelpViewerNotification
	                                           object:[tableDocumentInstance helpViewerClient]];

#ifndef SP_CODA
	[prefs addObserver:self forKeyPath:SPGlobalResultTableFont options:NSKeyValueObservingOptionNew context:NULL];
#endif

}

#pragma mark -
#pragma mark Private API

/**
 * Retrieves the value from the underlying data storage at the supplied row and column indices.
 *
 * @param row           The row index
 * @param column        The column index
 * @param preserveNULLs Whether t
 * 
 * @return The value from the data storage
 */
- (id)_resultDataItemAtRow:(NSInteger)row columnIndex:(NSUInteger)column preserveNULLs:(BOOL)preserveNULLs asPreview:(BOOL)asPreview;
{
#warning duplicate code with SPTableContent.m tableView:objectValueForTableColumn:…
	id value = nil;
	
	// While the table is being loaded, additional validation is required - data
	// locks must be used to avoid crashes, and indexes higher than the available
	// rows or columns may be requested.  Return "..." to indicate loading in these
	// cases.
	if (isWorking) {
		pthread_mutex_lock(&resultDataLock);
		
		if (SPIntS2U(row) < [resultData count] && column < [resultData columnCount]) {
			value = SPDataStoragePreviewAtRowAndColumn(resultData, row, column, 150);
		}
		
		pthread_mutex_unlock(&resultDataLock);
		
		if (!value) value = @"...";
	} 
	else {
		if (asPreview) {
			value = SPDataStoragePreviewAtRowAndColumn(resultData, row, column, 150);
		} else {
			value = SPDataStorageObjectAtRowAndColumn(resultData, row, column);
		}
	}

	if ([value isKindOfClass:[SPMySQLGeometryData class]])
		return [value wktString];

	if ([value isNSNull])
		return preserveNULLs ? value : [prefs objectForKey:SPNullValue];

	if ([value isKindOfClass:[NSData class]]) {
		return [value stringRepresentationUsingEncoding:[mySQLConnection stringEncoding]];
	}

	return value;
}

//this method is called right before the UI objects are deallocated
- (void)documentWillClose:(NSNotification *)notification
{
	// if a result load is in progress we must stop the timer or it may try to call invalid IBOutlets
	[self clearQueryLoadTimer];
}

#pragma mark -

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
#ifndef SP_CODA
	[prefs removeObserver:self forKeyPath:SPGlobalResultTableFont];
#endif
	[NSObject cancelPreviousPerformRequestsWithTarget:customQueryView];

	[self clearQueryLoadTimer];
	SPClear(usedQuery);
	SPClear(lastExecutedQuery);
	SPClear(resultData);
	SPClear(favoritesManager);

	if(fieldEditor) SPClear(fieldEditor);

	if (sortField)               SPClear(sortField);
	if (cqColumnDefinition)      SPClear(cqColumnDefinition);
	if (selectionIndexToRestore) SPClear(selectionIndexToRestore);
	if (currentQueryRanges)      SPClear(currentQueryRanges);

	[super dealloc];
}

@end

#pragma mark -

@implementation SPQueryProgressUpdateDecoupling

- (instancetype)initWithBlock:(QueryProgressHandler)anUpdateHandler
{
	self = [super init];
	if (self) {
		updateHandler = [anUpdateHandler copy];
		qpLock = OS_SPINLOCK_INIT;
	}

	return self;
}

- (void)setQueryProgress:(QueryProgress)newProgress
{
	BOOL notify = NO;
	OSSpinLockLock(&qpLock);
	_queryProgress = newProgress;
	if(!dirtyMarker) {
		dirtyMarker = 1;
		notify = YES;
	}
	OSSpinLockUnlock(&qpLock);

	if(notify) [self performSelectorOnMainThread:@selector(_updateProgress) withObject:nil waitUntilDone:NO];
}

- (QueryProgress)queryProgress
{
	OSSpinLockLock(&qpLock);
	QueryProgress cpy = _queryProgress;
	OSSpinLockUnlock(&qpLock);
	return cpy;
}

- (void)_updateProgress
{
	OSSpinLockLock(&qpLock);
	bool doRun = dirtyMarker;
	dirtyMarker = NO;
	QueryProgress p = _queryProgress;
	OSSpinLockUnlock(&qpLock);

	if(doRun) updateHandler(&p);
}

- (void)dealloc
{
	SPClear(updateHandler);
	[super dealloc];
}

@end
