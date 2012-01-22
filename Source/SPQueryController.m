//
//  $Id$
//
//  SPQueryController.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Jan 30, 2009
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

#import "SPQueryController.h"
#import "SPConsoleMessage.h"
#import "SPCustomQuery.h"
#import "SPQueryControllerInitializer.h"

#import "pthread.h"

@interface SPQueryController ()

- (void)_updateFilterState;
- (BOOL)_messageMatchesCurrentFilters:(NSString *)message;
- (NSString *)_getConsoleStringWithTimeStamps:(BOOL)timeStamps connections:(BOOL)connections;
- (void)_addMessageToConsole:(NSString *)message connection:(NSString *)connection isError:(BOOL)error;

@end

static SPQueryController *sharedQueryController = nil;

@implementation SPQueryController

#ifndef SP_REFACTOR
@synthesize consoleFont;
#endif

/**
 * Returns the shared query console.
 */
+ (SPQueryController *)sharedQueryController
{
	@synchronized(self) {
		if (sharedQueryController == nil) {
			sharedQueryController = [[super allocWithZone:NULL] init];
		}
	}

	return sharedQueryController;
}

+ (id)allocWithZone:(NSZone *)zone
{
	@synchronized(self) {
		return [[self sharedQueryController] retain];
	}
	
#ifdef SP_REFACTOR
	return nil;  // only here to stop clang's 'can reach end of non-void function'
#endif
}

- (id)init
{
	if ((self = [super initWithWindowNibName:@"Console"])) {
#ifndef SP_REFACTOR
		messagesFullSet		= [[NSMutableArray alloc] init];
		messagesFilteredSet	= [[NSMutableArray alloc] init];

		showSelectStatementsAreDisabled = NO;
		showHelpStatementsAreDisabled = NO;
		filterIsActive = NO;
		activeFilterString = [[NSMutableString alloc] init];

		// Weak reference to active messages set - starts off as full set
		messagesVisibleSet = messagesFullSet;

		untitledDocumentCounter = 1;
		numberOfMaxAllowedHistory = 100;
		allowConsoleUpdate = YES;

		favoritesContainer = [[NSMutableDictionary alloc] init];
		historyContainer = [[NSMutableDictionary alloc] init];
		contentFilterContainer = [[NSMutableDictionary alloc] init];
#endif
		completionKeywordList = nil;
		completionFunctionList = nil;
		functionArgumentSnippets = nil;
		
#ifndef SP_REFACTOR
		pthread_mutex_init(&consoleLock, NULL);
#endif

		NSError *error = [self loadCompletionLists];
		
		if (error) {
			NSLog(@"Error loading completion tokens data: %@", [error localizedDescription]); 
		}
	}

	return self;
}

/**
 * The following base protocol methods are implemented to ensure the singleton status of this class.
 */

- (id)copyWithZone:(NSZone *)zone { return self; }

- (id)retain { return self; }

- (NSUInteger)retainCount { return NSUIntegerMax; }

- (id)autorelease { return self; }

- (void)release { }

#pragma mark -
#pragma mark QueryConsoleController

/**
 * Copy implementation for console table view.
 */
- (void)copy:(id)sender
{
#ifndef SP_REFACTOR
	NSResponder *firstResponder = [[self window] firstResponder];

	if ((firstResponder == consoleTableView) && ([consoleTableView numberOfSelectedRows] > 0)) {

		NSMutableString *string = [NSMutableString string];
		NSIndexSet *rows = [consoleTableView selectedRowIndexes];

		NSUInteger i = [rows firstIndex];

		BOOL dateColumnIsHidden = [[consoleTableView tableColumnWithIdentifier:SPTableViewDateColumnID] isHidden];
		BOOL connectionColumnIsHidden = [[consoleTableView tableColumnWithIdentifier:SPTableViewConnectionColumnID] isHidden];

		[string setString:@""];

		while (i != NSNotFound)
		{
			if (i < [messagesVisibleSet count]) {
				SPConsoleMessage *message = NSArrayObjectAtIndex(messagesVisibleSet, i);

				// If the timestamp column is not hidden we need to include them in the copy
				if (!dateColumnIsHidden)
					[string appendFormat:@"/* %@ %@ ", [dateFormatter stringFromDate:[message messageDate]], (connectionColumnIsHidden) ? @"*/ ": @""];


				// If the connection column is not hidden we need to include them in the copy
				if (!connectionColumnIsHidden)
					[string appendFormat:@"%@%@ */ ",(dateColumnIsHidden) ? @"/* " : @"", [message messageConnection]];

				[string appendFormat:@"%@\n", [message message]];
			}

			i = [rows indexGreaterThanIndex:i];
		}

		NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];

		// Copy the string to the pasteboard
		[pasteBoard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] owner:nil];
		[pasteBoard setString:string forType:NSStringPboardType];
	}
#endif
}

/**
 * Clears the console by removing all of its messages.
 */
- (IBAction)clearConsole:(id)sender
{
#ifndef SP_REFACTOR
	[messagesFullSet removeAllObjects];
	[messagesFilteredSet removeAllObjects];

	[consoleTableView reloadData];
#endif
}

/**
 * Presents the user with a save panel to the save the current console to a log file.
 */
- (IBAction)saveConsoleAs:(id)sender
{
#ifndef SP_REFACTOR
	NSSavePanel *panel = [NSSavePanel savePanel];

	[panel setRequiredFileType:SPFileExtensionSQL];

	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:YES];
	[panel setCanSelectHiddenExtension:YES];

	[panel setAccessoryView:saveLogView];

	[panel beginSheetForDirectory:nil file:NSLocalizedString(@"ConsoleLog", @"Console : Save as : Initial filename") modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
#endif
}

/**
 * Toggles the display of the message time stamp column in the table view.
 */
- (IBAction)toggleShowTimeStamps:(id)sender
{
#ifndef SP_REFACTOR
	[[consoleTableView tableColumnWithIdentifier:SPTableViewDateColumnID] setHidden:([sender state])];
#endif
}

/**
 * Toggles the display of message connections column in the table view.
 */
- (IBAction)toggleShowConnections:(id)sender
{
#ifndef SP_REFACTOR
	[[consoleTableView tableColumnWithIdentifier:SPTableViewConnectionColumnID] setHidden:([sender state])];
#endif
}

/**
 * Toggles the hiding of messages containing SELECT and SHOW statements
 */
- (IBAction)toggleShowSelectShowStatements:(id)sender
{
#ifndef SP_REFACTOR
	// Store the state of the toggle for later quick reference
	showSelectStatementsAreDisabled = [sender state];

	[self _updateFilterState];
#endif
}

/**
 * Toggles the hiding of messages containing HELP statements
 */
- (IBAction)toggleShowHelpStatements:(id)sender
{
#ifndef SP_REFACTOR
	// Store the state of the toggle for later quick reference
	showHelpStatementsAreDisabled = [sender state];

	[self _updateFilterState];
#endif
}

/**
 * Shows the supplied message from the supplied connection in the console.
 */
- (void)showMessageInConsole:(NSString *)message connection:(NSString *)connection
{
#ifndef SP_REFACTOR
	[self _addMessageToConsole:message connection:connection isError:NO];
#endif
}

/**
 * Shows the supplied error from the supplied connection in the console.
 */
- (void)showErrorInConsole:(NSString *)error connection:(NSString *)connection
{
#ifndef SP_REFACTOR
	[self _addMessageToConsole:error connection:connection isError:YES];
#endif
}

/**
 * Returns the number of messages currently in the console.
 */
- (NSUInteger)consoleMessageCount
{
#ifndef SP_REFACTOR
	return [messagesFullSet count];
#else
	return 0;
#endif
}

/**
 * Called when the NSSavePanel sheet ends. Writes the console's current content to the selected file if required.
 */
- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
#ifndef SP_REFACTOR
	if (returnCode == NSOKButton) {
		[[self _getConsoleStringWithTimeStamps:[includeTimeStampsButton integerValue] connections:[includeConnectionButton integerValue]] writeToFile:[sheet filename] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	}
#endif
}

#pragma mark -
#pragma mark Other

/**
 * Called whenver the test within the search field changes.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
#ifndef SP_REFACTOR
	if ([[notification object] isEqualTo:consoleSearchField]) {

		// Store the state of the text filter and the current filter string for later quick reference
		[activeFilterString setString:[[[notification object] stringValue] lowercaseString]];
		
		filterIsActive = [activeFilterString length] > 0;

		[self _updateFilterState];
	}
#endif
}

/**
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
#ifndef SP_REFACTOR
	// Show/hide logging disabled label
	if ([keyPath isEqualToString:SPConsoleEnableLogging]) {
		[loggingDisabledTextField setStringValue:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? @"" : NSLocalizedString(@"Query logging is currently disabled", @"query logging currently disabled label")];
	}
	// Display table veiew vertical gridlines preference changed
	else if ([keyPath isEqualToString:SPDisplayTableViewVerticalGridlines]) {
        [consoleTableView setGridStyleMask:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	}
	// Use monospaced fonts preference changed
	else if ([keyPath isEqualToString:SPUseMonospacedFonts]) {

		BOOL useMonospacedFont = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];

		for (NSTableColumn *column in [consoleTableView tableColumns])
		{
			[[column dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}

		[consoleTableView reloadData];
	}
#endif
}

/**
 * Menu item validation for console table view contextual menu.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
#ifndef SP_REFACTOR
	if ([menuItem action] == @selector(copy:)) {
		return ([consoleTableView numberOfSelectedRows] > 0);
	}

	// Clear console
	if ([menuItem action] == @selector(clearConsole:)) {
		return ([self consoleMessageCount] > 0);
	}
#endif

	return [[self window] validateMenuItem:menuItem];
}

- (BOOL)allowConsoleUpdate
{
#ifndef SP_REFACTOR
	return allowConsoleUpdate;
#else
	return NO;
#endif
}

- (void)setAllowConsoleUpdate:(BOOL)allowUpdate
{
#ifndef SP_REFACTOR
	allowConsoleUpdate = allowUpdate;
	
	if (allowUpdate && [[self window] isVisible]) [self updateEntries];
#endif
}

/**
 * Update the Query Console and scroll to its last line.
 */
- (void)updateEntries
{
#ifndef SP_REFACTOR
	[consoleTableView reloadData];
	[consoleTableView scrollRowToVisible:([messagesVisibleSet count] - 1)];
#endif
}

/**
 * Return the AutoSaveName of the Query Console.
 */
- (NSString *)windowFrameAutosaveName
{
	return SPQueryConsoleWindowAutoSaveName;
}

/**
 * Updates the filtered result set based on any filter string and whether or not
 * all SELECT nd SHOW statements should be shown within the console.
 */
- (void)_updateFilterState
{
#ifndef SP_REFACTOR
	// Display start progress spinner
	[progressIndicator setHidden:NO];
	[progressIndicator startAnimation:self];
	
	// Don't allow clearing the console while filtering its content
	[saveConsoleButton setEnabled:NO];
	[clearConsoleButton setEnabled:NO];
	
	[messagesFilteredSet removeAllObjects];
	
	// If filtering is disabled and all show/selects are shown, empty the filtered
	// result set and set the full set to visible.
	if (!filterIsActive && !showSelectStatementsAreDisabled && !showHelpStatementsAreDisabled) {
		messagesVisibleSet = messagesFullSet;
		
		[consoleTableView reloadData];
		[consoleTableView scrollRowToVisible:([messagesVisibleSet count] - 1)];
		
		[saveConsoleButton setEnabled:YES];
		[clearConsoleButton setEnabled:YES];
		
		[saveConsoleButton setTitle:NSLocalizedString(@"Save As...", @"save as button title")];
		
		// Hide progress spinner
		[progressIndicator setHidden:YES];
		[progressIndicator stopAnimation:self];
		
		return;
	}
	
	// Cache frequently used selector, avoiding dynamic binding overhead
	IMP messageMatchesFilters = [self methodForSelector:@selector(_messageMatchesCurrentFilters:)];
	
	// Loop through all the messages in the full set to determine which should be
	// added to the filtered set.
	for (SPConsoleMessage *message in messagesFullSet) {
		
		// Add a reference to the message to the filtered set if filters are active and the
		// current message matches them
		if ((messageMatchesFilters)(self, @selector(_messageMatchesCurrentFilters:), [message message])) {
			[messagesFilteredSet addObject:message];
		}
	}
	
	// Ensure that the filtered set is marked as the currently visible set.
	messagesVisibleSet = messagesFilteredSet;
	
	[consoleTableView reloadData];
	[consoleTableView scrollRowToVisible:([messagesVisibleSet count] - 1)];
	
	if ([messagesVisibleSet count] > 0) {
		[saveConsoleButton setEnabled:YES];
		[clearConsoleButton setEnabled:YES];
	}
	
	[saveConsoleButton setTitle:NSLocalizedString(@"Save View As...", @"save view as button title")];
	
	// Hide progress spinner
	[progressIndicator setHidden:YES];
	[progressIndicator stopAnimation:self];
#endif
}

/**
 * Checks whether the supplied message text matches the current filter text, if any,
 * and whether it should be hidden if the SELECT/SHOW toggle is off.
 */
- (BOOL)_messageMatchesCurrentFilters:(NSString *)message
{
	BOOL messageMatchesCurrentFilters = YES;
	
#ifndef SP_REFACTOR
	// Check whether to hide the message based on the current filter text, if any
	if (filterIsActive && [message rangeOfString:activeFilterString options:NSCaseInsensitiveSearch].location == NSNotFound) {
		messageMatchesCurrentFilters = NO;
	}
	
	// If hiding SELECTs and SHOWs is toggled to on, check whether the message is a SELECT or SHOW
	if (messageMatchesCurrentFilters && 
		showSelectStatementsAreDisabled && 
		([[message uppercaseString] hasPrefix:@"SELECT"] || [[message uppercaseString] hasPrefix:@"SHOW"]))
	{
		messageMatchesCurrentFilters = NO;
	}
	
	// If hiding HELP is toggled to on, check whether the message is a HELP
	if (messageMatchesCurrentFilters && showHelpStatementsAreDisabled && ([[message uppercaseString] hasPrefix:@"HELP"])) {
		messageMatchesCurrentFilters = NO;
	}
#endif
	
	return messageMatchesCurrentFilters;
}

/**
 * Creates and returns a string made entirely of all of the console's messages and includes the message
 * time stamp and connection if specified.
 */
- (NSString *)_getConsoleStringWithTimeStamps:(BOOL)timeStamps connections:(BOOL)connections
{
	NSMutableString *consoleString = [NSMutableString string];
	
#ifndef SP_REFACTOR
	NSArray *messageCopy = [messagesVisibleSet copy];
	
	for (SPConsoleMessage *message in messagesVisibleSet)
	{
		// As we are going to save the messages as an SQL file we need to comment
		// the timestamps and connections if included.
		if (timeStamps || connections) [consoleString appendString:@"/* "];
		
		// If the timestamp column is not hidden we need to include them in the copy
		if (timeStamps) {
			[consoleString appendFormat:@"%@ ", [dateFormatter stringFromDate:[message messageDate]]];
		}
		
		// If the connection column is not hidden we need to include them in the copy
		if (connections) {
			[consoleString appendFormat:@"%@ ", [message messageConnection]];
		}
		
		// Close the comment
		if (timeStamps || connections) [consoleString appendString:@"*/ "];
		
		[consoleString appendFormat:@"%@\n", [message message]];
	}
	
	[messageCopy release];
#endif
	
	return consoleString;
}

/**
 * Adds the supplied message to the query console.
 */
- (void)_addMessageToConsole:(NSString *)message connection:(NSString *)connection isError:(BOOL)error
{
#ifndef SP_REFACTOR
	NSString *messageTemp = [[message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
	
	// Only append a semi-colon (;) if the supplied message is not an error
	if (!error) messageTemp = [messageTemp stringByAppendingString:@";"];
	
	SPConsoleMessage *consoleMessage = [SPConsoleMessage consoleMessageWithMessage:messageTemp date:[NSDate date] connection:connection];
	
	[consoleMessage setIsError:error];
	
	pthread_mutex_lock(&consoleLock);
	
	[messagesFullSet addObject:consoleMessage];
	
	// If filtering is active, determine whether to add a reference to the filtered set
	if ((showSelectStatementsAreDisabled || showHelpStatementsAreDisabled || filterIsActive)
		&& [self _messageMatchesCurrentFilters:[consoleMessage message]])
	{
		[messagesFilteredSet addObject:[messagesFullSet lastObject]];
		[saveConsoleButton setEnabled:YES];
		[clearConsoleButton setEnabled:YES];
	}
	
	// Reload the table and scroll to the new message if it's visible (for speed)
	if (allowConsoleUpdate && [[self window] isVisible]) {
		[consoleTableView noteNumberOfRowsChanged];
		[consoleTableView scrollRowToVisible:([messagesVisibleSet count] - 1)];
		[consoleTableView reloadData];
	}
	
	pthread_mutex_unlock(&consoleLock);
#endif
}

#pragma mark -

/**
 * Dealloc.
 */
- (void)dealloc
{
#ifndef SP_REFACTOR
	messagesVisibleSet = nil;
#endif
	[NSObject cancelPreviousPerformRequestsWithTarget:self];

#ifndef SP_REFACTOR
	[dateFormatter release], dateFormatter = nil;

	[messagesFullSet release], messagesFullSet = nil;
	[messagesFilteredSet release], messagesFilteredSet = nil;
	[activeFilterString release], activeFilterString = nil;

	[favoritesContainer release], favoritesContainer = nil;
	[historyContainer release], historyContainer = nil;
	[contentFilterContainer release], contentFilterContainer = nil;
#endif

	if (completionKeywordList) [completionKeywordList release], completionKeywordList = nil;
	if (completionFunctionList) [completionFunctionList release], completionFunctionList = nil; 
	if (functionArgumentSnippets) [functionArgumentSnippets release], functionArgumentSnippets = nil;
	
#ifndef SP_REFACTOR
	pthread_mutex_destroy(&consoleLock);
#endif
	
	[super dealloc];
}

@end
