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
#import "SPArrayAdditions.h"

#define MESSAGE_TRUNCATE_CHARACTER_LENGTH 256
#define MESSAGE_TIME_STAMP_FORMAT @"%H:%M:%S"

#define DEFAULT_CONSOLE_LOG_FILENAME @"untitled"
#define DEFAULT_CONSOLE_LOG_FILE_EXTENSION @"sql"

#define CONSOLE_WINDOW_AUTO_SAVE_NAME @"QueryConsole"

// Table view column identifiers
#define TABLEVIEW_MESSAGE_COLUMN_IDENTIFIER @"message"
#define TABLEVIEW_DATE_COLUMN_IDENTIFIER @"messageDate"

@interface SPQueryController (PrivateAPI)

- (NSString *)_getConsoleStringWithTimeStamps:(BOOL)timeStamps;

- (void)_updateFilterState;
- (void)_addMessageToConsole:(NSString *)message isError:(BOOL)error;
- (BOOL)_messageMatchesCurrentFilters:(NSString *)message;

@end

static SPQueryController *sharedQueryController = nil;

@implementation SPQueryController

@synthesize consoleFont;

/*
 * Returns the shared query console.
 */
+ (SPQueryController *)sharedQueryController
{
    @synchronized(self) {
        if (sharedQueryController == nil) {
            [[self alloc] init];
        }
    }
    
    return sharedQueryController;
}

+ (id)allocWithZone:(NSZone *)zone
{    
    @synchronized(self) {
        if (sharedQueryController == nil) {
            sharedQueryController = [super allocWithZone:zone];
            
            return sharedQueryController;
        }
    }
    
    return nil; // On subsequent allocation attempts return nil
}

- (id)init
{
	if ((self = [super initWithWindowNibName:@"Console"])) {
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
		
		favoritesContainer = [[NSMutableDictionary alloc] init];
		historyContainer = [[NSMutableDictionary alloc] init];

	}
	
	return self;
}

/*
 * The following base protocol methods are implemented to ensure the singleton status of this class.
 */

- (id)copyWithZone:(NSZone *)zone { return self; }

- (id)retain { return self; }

- (unsigned)retainCount { return UINT_MAX; }

- (id)autorelease { return self; }

- (void)release { }

/**
 * Set the window's auto save name and initialise display
 */
- (void)awakeFromNib
{
	prefs = [NSUserDefaults standardUserDefaults];
	
	[self setWindowFrameAutosaveName:CONSOLE_WINDOW_AUTO_SAVE_NAME];
	[[consoleTableView tableColumnWithIdentifier:TABLEVIEW_DATE_COLUMN_IDENTIFIER] setHidden:![prefs boolForKey:@"ConsoleShowTimestamps"]];
	showSelectStatementsAreDisabled = ![prefs boolForKey:@"ConsoleShowSelectsAndShows"];
	showHelpStatementsAreDisabled = ![prefs boolForKey:@"ConsoleShowHelps"];
	
	[self _updateFilterState];
	
	[loggingDisabledTextField setStringValue:([prefs boolForKey:@"ConsoleEnableLogging"]) ? @"" : @"Query logging is currently disabled"];
}

/**
 * Standard dealloc.
 */
- (void)dealloc
{
	messagesVisibleSet = nil;

	[messagesFullSet release], messagesFullSet = nil;
	[messagesFilteredSet release], messagesFilteredSet = nil;
	[activeFilterString release], activeFilterString = nil;
	
	[favoritesContainer release];
	[historyContainer release];

	[super dealloc];
}

#pragma mark ----------------------
#pragma mark QueryConsoleController


/**
 * Copy implementation for console table view.
 */
- (void)copy:(id)sender
{
	NSResponder *firstResponder = [[self window] firstResponder];
	
	if ((firstResponder == consoleTableView) && ([consoleTableView numberOfSelectedRows] > 0)) {
		
		NSString *string = @"";
		NSIndexSet *rows = [consoleTableView selectedRowIndexes];
		
		NSUInteger i = [rows firstIndex];
		
		while (i != NSNotFound) 
		{
			if (i < [messagesVisibleSet count]) {
				SPConsoleMessage *message = NSArrayObjectAtIndex(messagesVisibleSet, i);
				
				NSString *consoleMessage = [message message];
				
				// If the timestamp column is not hidden we need to include them in the copy
				if (![[consoleTableView tableColumnWithIdentifier:TABLEVIEW_DATE_COLUMN_IDENTIFIER] isHidden]) {
					
					NSString *dateString = [[message messageDate] descriptionWithCalendarFormat:MESSAGE_TIME_STAMP_FORMAT timeZone:nil locale:nil];
					
					consoleMessage = [NSString stringWithFormat:@"/* MySQL %@ */ %@", dateString, consoleMessage];
				}
				
				string = [string stringByAppendingFormat:@"%@\n", consoleMessage];
			}
			
			i = [rows indexGreaterThanIndex:i];
		}
		
		NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
		
		// Copy the string to the pasteboard
		[pasteBoard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] owner:nil];
		[pasteBoard setString:string forType:NSStringPboardType];
	}
}

/**
 * Clears the console by removing all of its messages.
 */
- (IBAction)clearConsole:(id)sender
{
	[messagesFullSet removeAllObjects];
	[messagesFilteredSet removeAllObjects];
	
	[consoleTableView reloadData];
}

/**
 * Presents the user with a save panel to the save the current console to a log file.
 */
- (IBAction)saveConsoleAs:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setRequiredFileType:DEFAULT_CONSOLE_LOG_FILE_EXTENSION];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:YES];
	[panel setCanSelectHiddenExtension:YES];
	
	[panel setAccessoryView:saveLogView];
	
	[panel beginSheetForDirectory:nil file:DEFAULT_CONSOLE_LOG_FILENAME modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

/**
 * Toggles the display of the message time stamp column in the table view.
 */
- (IBAction)toggleShowTimeStamps:(id)sender
{
	[[consoleTableView tableColumnWithIdentifier:TABLEVIEW_DATE_COLUMN_IDENTIFIER] setHidden:([sender state])];
}

/**
 * Toggles the hiding of messages containing SELECT and SHOW statements
 */
- (IBAction)toggleShowSelectShowStatements:(id)sender
{	
	// Store the state of the toggle for later quick reference
	showSelectStatementsAreDisabled = [sender state];
	
	[self _updateFilterState];
}

/**
 * Toggles the hiding of messages containing HELP statements
 */
- (IBAction)toggleShowHelpStatements:(id)sender
{	
	// Store the state of the toggle for later quick reference
	showHelpStatementsAreDisabled = [sender state];
	
	[self _updateFilterState];
}

/**
 * Shows the supplied message in the console.
 */
- (void)showMessageInConsole:(NSString *)message
{
	[self _addMessageToConsole:message isError:NO];
}

/**
 * Shows the supplied error in the console.
 */
- (void)showErrorInConsole:(NSString *)error
{
	[self _addMessageToConsole:error isError:YES];
}

/**
 * Returns the number of messages currently in the console.
 */
- (NSUInteger)consoleMessageCount
{
	return [messagesFullSet count];
}

/**
 * Called when the NSSavePanel sheet ends. Writes the console's current content to the selected file if required.
 */
- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		[[self _getConsoleStringWithTimeStamps:[includeTimeStampsButton intValue]] writeToFile:[sheet filename] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	}
}

#pragma mark -
#pragma mark Tableview delegate methods

/**
 * Table view delegate method. Returns the number of rows in the table veiw.
 */
- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [messagesVisibleSet count];
}

/**
 * Table view delegate method. Returns the specific object for the request column and row.
 */
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
	NSString *returnValue = nil;
	
	id object = [[messagesVisibleSet objectAtIndex:row] valueForKey:[tableColumn identifier]];
	
	if ([[tableColumn identifier] isEqualToString:TABLEVIEW_DATE_COLUMN_IDENTIFIER]) {
		
		NSString *dateString = [(NSDate *)object descriptionWithCalendarFormat:MESSAGE_TIME_STAMP_FORMAT timeZone:nil locale:nil];
		
		returnValue = [NSString stringWithFormat:@"/* MySQL %@ */", dateString];
	} 
	else {
		if ([(NSString *)object length] > MESSAGE_TRUNCATE_CHARACTER_LENGTH) {
			object = [NSString stringWithFormat:@"%@...", [object substringToIndex:MESSAGE_TRUNCATE_CHARACTER_LENGTH]];
		}
		
		returnValue = object;
	}
	
	NSMutableDictionary *stringAtributes = nil;
	
	if (consoleFont) {
		stringAtributes = [NSMutableDictionary dictionaryWithObject:consoleFont forKey:NSFontAttributeName];
	}
	
	// If this is an error message give it a red colour
	if ([(SPConsoleMessage *)[messagesVisibleSet objectAtIndex:row] isError]) {
		if (stringAtributes) {
			[stringAtributes setObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
		}
		else {
			stringAtributes = [NSMutableDictionary dictionaryWithObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
		}
	}
	
	return [[[NSAttributedString alloc] initWithString:returnValue attributes:stringAtributes] autorelease];
}


#pragma mark -
#pragma mark Other

/**
 * Called whenver the test within the search field changes.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	id object = [notification object];
	
	if ([object isEqualTo:consoleSearchField]) {
		
		// Store the state of the text filter and the current filter string for later quick reference
		[activeFilterString setString:[[object stringValue] lowercaseString]];
		filterIsActive = [activeFilterString length]?YES:NO;
		
		[self _updateFilterState];
	} 
}

/**
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	if ([keyPath isEqualToString:@"ConsoleEnableLogging"]) {
		[loggingDisabledTextField setStringValue:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? @"" : @"Query logging is currently disabled"];
	}
}

/**
 * Menu item validation for console table view contextual menu.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(copy:)) {
		return ([consoleTableView numberOfSelectedRows] > 0);
	}
	
	if ([menuItem action] == @selector(clearConsole:)) {
		return ([self consoleMessageCount] > 0);
	}
	
	return [[self window] validateMenuItem:menuItem];
}

- (void)updateEntries
{
	[consoleTableView reloadData];
	[consoleTableView scrollRowToVisible:([messagesVisibleSet count] - 1)];
}

- (NSString *)windowFrameAutosaveName
{
	return @"QueryConsole";
}

#pragma mark ----------------------
#pragma mark DocumentsController

- (NSURL *)registerDocumentWithFileURL:(NSURL *)fileURL andContextInfo:(NSMutableDictionary *)contextInfo
{
	
	// Register a new untiled document and return its URL
	if(fileURL == nil) {
		NSURL *new = [NSURL URLWithString:[[NSString stringWithFormat:@"Untitled %d", untitledDocumentCounter] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
		untitledDocumentCounter++;
		
		if(![favoritesContainer objectForKey:[new absoluteString]]) {
			NSMutableArray *arr = [[NSMutableArray alloc] init];
			[favoritesContainer setObject:arr forKey:[new absoluteString]];
			[arr release];
		}

		// Set the global history coming from the Prefs as default if available
		if(![historyContainer objectForKey:[new absoluteString]]) {
			if([prefs objectForKey:@"queryHistory"]) {
				NSMutableArray *arr = [[NSMutableArray alloc] init];
				[arr addObjectsFromArray:[prefs objectForKey:@"queryHistory"]];
				[historyContainer setObject:arr forKey:[new absoluteString]];
				[arr release];
			} else {
				NSMutableArray *arr = [[NSMutableArray alloc] init];
				[historyContainer setObject:[NSMutableArray array] forKey:[new absoluteString]];
				[arr release];
			}
		}

		return new;

	}
	
	// Register a spf file to manage all query favorites and query history items
	// file path based (incl. Untitled docs) in a dictionary whereby the key represents the file URL as string.
	if(![favoritesContainer objectForKey:[fileURL absoluteString]]) {
		if(contextInfo != nil && [contextInfo objectForKey:@"queryFavorites"] && [[contextInfo objectForKey:@"queryFavorites"] count]) {
			NSMutableArray *arr = [[NSMutableArray alloc] init];
			[arr addObjectsFromArray:[contextInfo objectForKey:@"queryFavorites"]];
			[favoritesContainer setObject:arr forKey:[fileURL absoluteString]];
			[arr release];
		} else {
			NSMutableArray *arr = [[NSMutableArray alloc] init];
			[favoritesContainer setObject:arr forKey:[fileURL absoluteString]];
			[arr release];
		}
	}
	if(![historyContainer objectForKey:[fileURL absoluteString]]) {
		if(contextInfo != nil && [contextInfo objectForKey:@"queryHistory"] && [[contextInfo objectForKey:@"queryHistory"] count]) {
			NSMutableArray *arr = [[NSMutableArray alloc] init];
			[arr addObjectsFromArray:[contextInfo objectForKey:@"queryHistory"]];
			[historyContainer setObject:arr forKey:[fileURL absoluteString]];
			[arr release];
		} else {
			NSMutableArray *arr = [[NSMutableArray alloc] init];
			[historyContainer setObject:arr forKey:[fileURL absoluteString]];
			[arr release];
		}
	}
	
	return fileURL;
	
}

- (void)removeRegisteredDocumentWithFileURL:(NSURL *)fileURL
{

	// Check for multiple instance of the same document.
	// Remove it if only one instance was registerd.
	NSArray *allDocs = [[NSDocumentController sharedDocumentController] documents];
	NSMutableArray *allURLs = [NSMutableArray array];
	for(id doc in allDocs) {
		if([allURLs containsObject:[doc fileURL]])
			return;
		else
			[allURLs addObject:[doc fileURL]];
	}

	if([favoritesContainer objectForKey:[fileURL absoluteString]])
		[favoritesContainer removeObjectForKey:[fileURL absoluteString]];
	if([historyContainer objectForKey:[fileURL absoluteString]])
		[historyContainer removeObjectForKey:[fileURL absoluteString]];

}

- (void)addFavorite:(NSDictionary *)favorite forFileURL:(NSURL *)fileURL
{
	
}

- (void)replaceFavoritesByArray:(NSArray *)favoritesArray forFileURL:(NSURL *)fileURL
{
	if([favoritesContainer objectForKey:[fileURL absoluteString]])
		[favoritesContainer setObject:favoritesArray forKey:[fileURL absoluteString]];
}

- (void)replaceHistoryByArray:(NSArray *)historyArray forFileURL:(NSURL *)fileURL
{
	if([historyContainer objectForKey:[fileURL absoluteString]])
		[historyContainer setObject:historyArray forKey:[fileURL absoluteString]];
}

- (void)addHistory:(NSString *)history forFileURL:(NSURL *)fileURL
{

	NSUInteger maxHistoryItems = [[prefs objectForKey:@"CustomQueryMaxHistoryItems"] intValue];

	// Save each history item due to its document source
	if([historyContainer objectForKey:[fileURL absoluteString]]) {

		// Remove all duplicates by using a NSPopUpButton
		NSPopUpButton *uniquifier = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,0,0,0) pullsDown:YES];
		[uniquifier addItemsWithTitles:[historyContainer objectForKey:[fileURL absoluteString]]];
		[uniquifier insertItemWithTitle:history atIndex:0];

		while ( [uniquifier numberOfItems] > maxHistoryItems )
			[uniquifier removeItemAtIndex:[uniquifier numberOfItems]-1];

		[self replaceHistoryByArray:[uniquifier itemTitles] forFileURL:fileURL];
		[uniquifier release];

	}

	// Save history items coming from each Untitled document in the global Preferences successively
	// regardingless of the source document.
	if(![[fileURL absoluteString] hasPrefix:@"/"]) {

		// Remove all duplicates by using a NSPopUpButton
		NSPopUpButton *uniquifier = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,0,0,0) pullsDown:YES];
		[uniquifier addItemsWithTitles:[prefs objectForKey:@"queryHistory"]];
		[uniquifier insertItemWithTitle:history atIndex:0];

		while ( [uniquifier numberOfItems] > maxHistoryItems )
			[uniquifier removeItemAtIndex:[uniquifier numberOfItems]-1];

		[prefs setObject:[uniquifier itemTitles] forKey:@"queryHistory"];
		[uniquifier release];

	}

}

- (NSMutableArray *)favoritesForFileURL:(NSURL *)fileURL
{
	if([favoritesContainer objectForKey:[fileURL absoluteString]])
		return [favoritesContainer objectForKey:[fileURL absoluteString]];

	return [NSMutableArray array];

}

- (NSMutableArray *)historyForFileURL:(NSURL *)fileURL
{
	if([historyContainer objectForKey:[fileURL absoluteString]])
		return [historyContainer objectForKey:[fileURL absoluteString]];

	return [NSMutableArray array];

}

@end

@implementation SPQueryController (PrivateAPI)

/**
 * Creates and returns a string made entirely of all of the console's messages and includes the message
 * time stamps if specified.
 */
- (NSString *)_getConsoleStringWithTimeStamps:(BOOL)timeStamps
{
	NSMutableString *consoleString = [[[NSMutableString alloc] init] autorelease];
	
	for (SPConsoleMessage *message in messagesVisibleSet) 
	{
		if (timeStamps) {
			NSString *dateString = [[message messageDate] descriptionWithCalendarFormat:MESSAGE_TIME_STAMP_FORMAT timeZone:nil locale:nil];
			
			[consoleString appendString:[NSString stringWithFormat:@"/* MySQL %@ */ ", dateString]];
		}
		
		[consoleString appendString:[NSString stringWithFormat:@"%@\n", [message message]]];
	}
	
	return consoleString;
}


/**
 * Updates the filtered result set based on any filter string and whether or not
 * all SELECT nd SHOW statements should be shown within the console.
 */
- (void)_updateFilterState
{
	
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
		
		[saveConsoleButton setTitle:@"Save As..."];
		
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
	
	[saveConsoleButton setTitle:@"Save View As..."];
	
	// Hide progress spinner
	[progressIndicator setHidden:YES];
	[progressIndicator stopAnimation:self];
}

/**
 * Adds the supplied message to the query console.
 */
- (void)_addMessageToConsole:(NSString *)message isError:(BOOL)error
{
	SPConsoleMessage *consoleMessage = [SPConsoleMessage consoleMessageWithMessage:[[[message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"\n" withString:@" "] stringByAppendingString:@";"] date:[NSDate date]];
	
	[consoleMessage setIsError:error];
	
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
	if ( [[self window] isVisible] ) {
		[consoleTableView reloadData];
		[consoleTableView scrollRowToVisible:([messagesVisibleSet count] - 1)];
	}
}

/**
 * Checks whether the supplied message text matches the current filter text, if any,
 * and whether it should be hidden if the SELECT/SHOW toggle is off.
 */
- (BOOL)_messageMatchesCurrentFilters:(NSString *)message
{	
	BOOL messageMatchesCurrentFilters = YES;
	
	// Check whether to hide the message based on the current filter text, if any
	if (filterIsActive
		&& [message rangeOfString:activeFilterString options:NSCaseInsensitiveSearch].location == NSNotFound)
	{
		messageMatchesCurrentFilters = NO;
	}
	
	// If hiding SELECTs and SHOWs is toggled to on, check whether the message is a SELECT or SHOW
	if (messageMatchesCurrentFilters
		&& showSelectStatementsAreDisabled
		&& ([[message uppercaseString] hasPrefix:@"SELECT"] || [[message uppercaseString] hasPrefix:@"SHOW"]))
	{
		messageMatchesCurrentFilters = NO;
	}
	// If hiding HELP is toggled to on, check whether the message is a HELP
	if (messageMatchesCurrentFilters
		&& showHelpStatementsAreDisabled
		&& ([[message uppercaseString] hasPrefix:@"HELP"]))
	{
		messageMatchesCurrentFilters = NO;
	}
	
	return messageMatchesCurrentFilters;
}

@end
