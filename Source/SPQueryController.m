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
#import "SPConstants.h"
#import "CustomQuery.h"

#define MESSAGE_TRUNCATE_CHARACTER_LENGTH 256

// Table view column identifiers
#define TABLEVIEW_MESSAGE_COLUMN_IDENTIFIER    @"message"
#define TABLEVIEW_DATE_COLUMN_IDENTIFIER       @"messageDate"
#define TABLEVIEW_CONNECTION_COLUMN_IDENTIFIER @"messageConnection"

@interface SPQueryController (PrivateAPI)

- (void)_updateFilterState;
- (BOOL)_messageMatchesCurrentFilters:(NSString *)message;
- (NSString *)_getConsoleStringWithTimeStamps:(BOOL)timeStamps connections:(BOOL)connections;
- (void)_addMessageToConsole:(NSString *)message connection:(NSString *)connection isError:(BOOL)error;

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
		allowConsoleUpdate = YES;
		
		favoritesContainer = [[NSMutableDictionary alloc] init];
		historyContainer = [[NSMutableDictionary alloc] init];
		contentFilterContainer = [[NSMutableDictionary alloc] init];
		completionKeywordList = nil;
		completionFunctionList = nil;
		functionArgumentSnippets = nil;

		NSError *readError = nil;
		NSString *convError = nil;
		NSPropertyListFormat format;
		NSDictionary *completionPlist;
		NSData *completionTokensData = [NSData dataWithContentsOfFile:[NSBundle pathForResource:@"CompletionTokens.plist" ofType:nil inDirectory:[[NSBundle mainBundle] bundlePath]] 
			options:NSMappedRead error:&readError];

		
		completionPlist = [NSDictionary dictionaryWithDictionary:[NSPropertyListSerialization propertyListFromData:completionTokensData 
				mutabilityOption:NSPropertyListMutableContainersAndLeaves format:&format errorDescription:&convError]];

		if(completionPlist == nil || readError != nil || convError != nil) {
			NSLog(@"Error while reading “CompletionTokens.plist”:\n%@\n%@", [readError localizedDescription], convError);
			NSBeep();
		} else {
			if([completionPlist objectForKey:@"core_keywords"]) {
				completionKeywordList = [[NSArray arrayWithArray:[completionPlist objectForKey:@"core_keywords"]] retain];
			} else {
				NSLog(@"No “core_keywords” array found.");
				NSBeep();
			}
			if([completionPlist objectForKey:@"core_builtin_functions"]) {
				completionFunctionList = [[NSArray arrayWithArray:[completionPlist objectForKey:@"core_builtin_functions"]] retain];
			} else {
				NSLog(@"No “core_builtin_functions” array found.");
				NSBeep();
			}
			if([completionPlist objectForKey:@"function_argument_snippets"]) {
				functionArgumentSnippets = [[NSDictionary dictionaryWithDictionary:[completionPlist objectForKey:@"function_argument_snippets"]] retain];
			} else {
				NSLog(@"No “function_argument_snippets” dictionary found.");
				NSBeep();
			}
		}

	}
	
	return self;
}

/*
 * The following base protocol methods are implemented to ensure the singleton status of this class.
 */

- (id)copyWithZone:(NSZone *)zone { return self; }

- (id)retain { return self; }

- (NSUInteger)retainCount { return NSUIntegerMax; }

- (id)autorelease { return self; }

- (void)release { }

/**
 * Set the window's auto save name and initialise display
 */
- (void)awakeFromNib
{
	prefs = [NSUserDefaults standardUserDefaults];
	
	[self setWindowFrameAutosaveName:@"QueryConsole"];
	
	// Show/hide table columns
	[[consoleTableView tableColumnWithIdentifier:TABLEVIEW_DATE_COLUMN_IDENTIFIER] setHidden:![prefs boolForKey:SPConsoleShowTimestamps]];
	[[consoleTableView tableColumnWithIdentifier:TABLEVIEW_CONNECTION_COLUMN_IDENTIFIER] setHidden:![prefs boolForKey:SPConsoleShowConnections]];
	
	showSelectStatementsAreDisabled = ![prefs boolForKey:SPConsoleShowSelectsAndShows];
	showHelpStatementsAreDisabled = ![prefs boolForKey:SPConsoleShowHelps];
	
	[self _updateFilterState];
	
	[loggingDisabledTextField setStringValue:([prefs boolForKey:SPConsoleEnableLogging]) ? @"" : NSLocalizedString(@"Query logging is currently disabled", @"query logging disabled label")];
	
	// Setup data formatter
	dateFormatter = [[NSDateFormatter alloc] init];
	
	[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	
	[dateFormatter setDateStyle:NSDateFormatterNoStyle];
	[dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
	
	// Set the process table view's vertical gridlines if required
	[consoleTableView setGridStyleMask:([prefs boolForKey:SPDisplayTableViewVerticalGridlines]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];

	// Set the strutcture and index view's font
	BOOL useMonospacedFont = [prefs boolForKey:SPUseMonospacedFonts];
	
	for (NSTableColumn *column in [consoleTableView tableColumns])
	{
		[[column dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}
}

#pragma mark -
#pragma mark QueryConsoleController

/**
 * Copy implementation for console table view.
 */
- (void)copy:(id)sender
{
	NSResponder *firstResponder = [[self window] firstResponder];
	
	if ((firstResponder == consoleTableView) && ([consoleTableView numberOfSelectedRows] > 0)) {
		
		NSMutableString *string = [NSMutableString string];
		NSIndexSet *rows = [consoleTableView selectedRowIndexes];
		
		NSUInteger i = [rows firstIndex];
		
		BOOL dateColumnIsHidden = [[consoleTableView tableColumnWithIdentifier:TABLEVIEW_DATE_COLUMN_IDENTIFIER] isHidden];
		BOOL connectionColumnIsHidden = [[consoleTableView tableColumnWithIdentifier:TABLEVIEW_CONNECTION_COLUMN_IDENTIFIER] isHidden];
		
		[string setString:@""];
		
		while (i != NSNotFound) 
		{
			if (i < [messagesVisibleSet count]) {
				SPConsoleMessage *message = NSArrayObjectAtIndex(messagesVisibleSet, i);
								
				// If the timestamp column is not hidden we need to include them in the copy
				if (!dateColumnIsHidden) {
					[string appendString:@"/* "];
					[string appendString:[dateFormatter stringFromDate:[message messageDate]]];
					if (connectionColumnIsHidden) [string appendString:@" */ "];
					else [string appendString:@" "];				
				}
				
				// If the connection column is not hidden we need to include them in the copy
				if (!connectionColumnIsHidden) {
					if (dateColumnIsHidden) [string appendString:@"/* "];
					[string appendString:[message messageConnection]];
					[string appendString:@" */ "];
				}
				
				[string appendString:[message message]];
				[string appendString:@"\n"];
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
	
	[panel setRequiredFileType:SPFileExtensionSQL];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:YES];
	[panel setCanSelectHiddenExtension:YES];
	
	[panel setAccessoryView:saveLogView];
	
	[panel beginSheetForDirectory:nil file:@"untitled" modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

/**
 * Toggles the display of the message time stamp column in the table view.
 */
- (IBAction)toggleShowTimeStamps:(id)sender
{
	[[consoleTableView tableColumnWithIdentifier:TABLEVIEW_DATE_COLUMN_IDENTIFIER] setHidden:([sender state])];
}

/**
 * Toggles the display of message connections column in the table view.
 */
- (IBAction)toggleShowConnections:(id)sender
{
	[[consoleTableView tableColumnWithIdentifier:TABLEVIEW_CONNECTION_COLUMN_IDENTIFIER] setHidden:([sender state])];
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
 * Shows the supplied message from the supplied connection in the console.
 */
- (void)showMessageInConsole:(NSString *)message connection:(NSString *)connection
{
	[self _addMessageToConsole:message connection:connection isError:NO];
}

/**
 * Shows the supplied error from the supplied connection in the console.
 */
- (void)showErrorInConsole:(NSString *)error connection:(NSString *)connection
{
	[self _addMessageToConsole:error connection:connection isError:YES];
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
- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		[[self _getConsoleStringWithTimeStamps:[includeTimeStampsButton integerValue] connections:[includeConnectionButton integerValue]] writeToFile:[sheet filename] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	}
}

#pragma mark -
#pragma mark Tableview delegate methods

/**
 * Table view delegate method. Returns the number of rows in the table veiw.
 */
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
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
				
		returnValue = [dateFormatter stringFromDate:(NSDate *)object];		
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
	// Show/hide logging disabled label
	if ([keyPath isEqualToString:SPConsoleEnableLogging]) {
		[loggingDisabledTextField setStringValue:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? @"" : @"Query logging is currently disabled"];
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
}

/**
 * Menu item validation for console table view contextual menu.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(copy:)) {
		return ([consoleTableView numberOfSelectedRows] > 0);
	}
	
	// Clear console
	if ([menuItem action] == @selector(clearConsole:)) {
		return ([self consoleMessageCount] > 0);
	}
	
	return [[self window] validateMenuItem:menuItem];
}

- (BOOL) allowConsoleUpdate 
{
	return allowConsoleUpdate;
}

- (void) setAllowConsoleUpdate:(BOOL)allowUpdate 
{
	allowConsoleUpdate = allowUpdate;
	if (allowUpdate && [[self window] isVisible]) [self updateEntries];
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

#pragma mark -
#pragma mark Completion List Controller

- (NSArray*)functionList
{
	if(completionFunctionList != nil && [completionFunctionList count])
		return completionFunctionList;
	return [NSArray array];
}

- (NSArray*)keywordList
{
	if(completionKeywordList != nil && [completionKeywordList count])
		return completionKeywordList;
	return [NSArray array];
}

- (NSString*)argumentSnippetForFunction:(NSString*)func
{
	if(functionArgumentSnippets && [functionArgumentSnippets objectForKey:[func uppercaseString]])
		return [functionArgumentSnippets objectForKey:[func uppercaseString]];
	return @"";
}

#pragma mark -
#pragma mark DocumentsController

- (NSURL *)registerDocumentWithFileURL:(NSURL *)fileURL andContextInfo:(NSMutableDictionary *)contextInfo
{
	// Register a new untiled document and return its URL
	if(fileURL == nil) {
		NSURL *new = [NSURL URLWithString:[[NSString stringWithFormat:@"Untitled %ld", (unsigned long)untitledDocumentCounter] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
		untitledDocumentCounter++;
		
		if(![favoritesContainer objectForKey:[new absoluteString]]) {
			NSMutableArray *arr = [[NSMutableArray alloc] init];
			[favoritesContainer setObject:arr forKey:[new absoluteString]];
			[arr release];
		}

		// Set the global history coming from the Prefs as default if available
		if(![historyContainer objectForKey:[new absoluteString]]) {
			if([prefs objectForKey:SPQueryHistory]) {
				NSMutableArray *arr = [[NSMutableArray alloc] init];
				[arr addObjectsFromArray:[prefs objectForKey:SPQueryHistory]];
				[historyContainer setObject:arr forKey:[new absoluteString]];
				[arr release];
			} else {
				NSMutableArray *arr = [[NSMutableArray alloc] init];
				[historyContainer setObject:[NSMutableArray array] forKey:[new absoluteString]];
				[arr release];
			}
		}

		// Set the doc-based content filters
		if(![contentFilterContainer objectForKey:[new absoluteString]]) {
			[contentFilterContainer setObject:[NSMutableDictionary dictionary] forKey:[new absoluteString]];
		}

		return new;

	}
	
	// Register a spf file to manage all query favorites and query history items
	// file path based (incl. Untitled docs) in a dictionary whereby the key represents the file URL as string.
	if(![favoritesContainer objectForKey:[fileURL absoluteString]]) {
		if(contextInfo != nil && [contextInfo objectForKey:SPQueryFavorites] && [[contextInfo objectForKey:SPQueryFavorites] count]) {
			NSMutableArray *arr = [[NSMutableArray alloc] init];
			[arr addObjectsFromArray:[contextInfo objectForKey:SPQueryFavorites]];
			[favoritesContainer setObject:arr forKey:[fileURL absoluteString]];
			[arr release];
		} else {
			NSMutableArray *arr = [[NSMutableArray alloc] init];
			[favoritesContainer setObject:arr forKey:[fileURL absoluteString]];
			[arr release];
		}
	}
	
	if(![historyContainer objectForKey:[fileURL absoluteString]]) {
		if(contextInfo != nil && [contextInfo objectForKey:SPQueryHistory] && [[contextInfo objectForKey:SPQueryHistory] count]) {
			NSMutableArray *arr = [[NSMutableArray alloc] init];
			[arr addObjectsFromArray:[contextInfo objectForKey:SPQueryHistory]];
			[historyContainer setObject:arr forKey:[fileURL absoluteString]];
			[arr release];
		} else {
			NSMutableArray *arr = [[NSMutableArray alloc] init];
			[historyContainer setObject:arr forKey:[fileURL absoluteString]];
			[arr release];
		}
	}
	
	if(![contentFilterContainer objectForKey:[fileURL absoluteString]]) {
		if(contextInfo != nil && [contextInfo objectForKey:SPContentFilters]) {
			[contentFilterContainer setObject:[contextInfo objectForKey:SPContentFilters] forKey:[fileURL absoluteString]];
		} else {
			NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
			[contentFilterContainer setObject:dict forKey:[fileURL absoluteString]];
			[dict release];
		}
	}
	
	return fileURL;
}

- (void)removeRegisteredDocumentWithFileURL:(NSURL *)fileURL
{
	// Check for multiple instance of the same document.
	// Remove it if only one instance was registerd.
	NSArray *allDocs = [[NSApp delegate] orderedDocuments];
	NSMutableArray *allURLs = [NSMutableArray array];
	for(id doc in allDocs) {
		if (![doc fileURL]) continue;
		if([allURLs containsObject:[doc fileURL]])
			return;
		else
			[allURLs addObject:[doc fileURL]];
	}

	if([favoritesContainer objectForKey:[fileURL absoluteString]])
		[favoritesContainer removeObjectForKey:[fileURL absoluteString]];
	if([historyContainer objectForKey:[fileURL absoluteString]])
		[historyContainer removeObjectForKey:[fileURL absoluteString]];
	if([contentFilterContainer objectForKey:[fileURL absoluteString]])
		[contentFilterContainer removeObjectForKey:[fileURL absoluteString]];
}

- (void)replaceContentFilterByArray:(NSArray *)contentFilterArray ofType:(NSString *)filterType forFileURL:(NSURL *)fileURL
{
	if([contentFilterContainer objectForKey:[fileURL absoluteString]]) {
		NSMutableDictionary *c = [[NSMutableDictionary alloc] init];
		[c setDictionary:[contentFilterContainer objectForKey:[fileURL absoluteString]]];
		[c setObject:contentFilterArray forKey:filterType];
		[contentFilterContainer setObject:c forKey:[fileURL absoluteString]];
		[c release];
	}
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

	// Inform all opened documents to update the history list
	for(id doc in [[NSApp delegate] orderedDocuments])
		if([[doc valueForKeyPath:@"customQueryInstance"] respondsToSelector:@selector(historyItemsHaveBeenUpdated:)])
				[[doc valueForKeyPath:@"customQueryInstance"] performSelectorOnMainThread:@selector(historyItemsHaveBeenUpdated:) withObject:self waitUntilDone:NO];


	// User did choose to clear the global history list
	if(![fileURL isFileURL] && ![historyArray count])
		[prefs setObject:historyArray forKey:SPQueryHistory];
}

- (void)addFavorite:(NSDictionary *)favorite forFileURL:(NSURL *)fileURL
{
	if([favoritesContainer objectForKey:[fileURL absoluteString]])
		[[favoritesContainer objectForKey:[fileURL absoluteString]] addObject:favorite];
}

- (void)addHistory:(NSString *)history forFileURL:(NSURL *)fileURL
{
	NSUInteger maxHistoryItems = [[prefs objectForKey:SPCustomQueryMaxHistoryItems] integerValue];

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
	if(![fileURL isFileURL]) {

		// Remove all duplicates by using a NSPopUpButton
		NSPopUpButton *uniquifier = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,0,0,0) pullsDown:YES];
		[uniquifier addItemsWithTitles:[prefs objectForKey:SPQueryHistory]];
		[uniquifier insertItemWithTitle:history atIndex:0];

		while ( [uniquifier numberOfItems] > maxHistoryItems )
			[uniquifier removeItemAtIndex:[uniquifier numberOfItems]-1];

		[prefs setObject:[uniquifier itemTitles] forKey:SPQueryHistory];
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

- (NSArray *)historyMenuItemsForFileURL:(NSURL *)fileURL
{
	if([historyContainer objectForKey:[fileURL absoluteString]]) {
		NSMutableArray *returnArray = [NSMutableArray arrayWithCapacity:[[historyContainer objectForKey:[fileURL absoluteString]] count]];
		NSMenuItem *historyMenuItem;
		for(NSString* history in [historyContainer objectForKey:[fileURL absoluteString]]) {
			historyMenuItem = [[[NSMenuItem alloc] initWithTitle:([history length] > 64) ? [NSString stringWithFormat:@"%@…", [history substringToIndex:63]] : history
			 											action:NULL 
												keyEquivalent:@""] autorelease];
			[historyMenuItem setToolTip:([history length] > 256) ? [NSString stringWithFormat:@"%@…", [history substringToIndex:255]] : history];
			[returnArray addObject:historyMenuItem];
		}
		
		return returnArray;
	}

	return [NSArray array];
}

- (NSUInteger)numberOfHistoryItemsForFileURL:(NSURL *)fileURL
{
	if([historyContainer objectForKey:[fileURL absoluteString]])
		return [[historyContainer objectForKey:[fileURL absoluteString]] count];
	else
		return 0;
}
- (NSMutableDictionary *)contentFilterForFileURL:(NSURL *)fileURL
{
	if([contentFilterContainer objectForKey:[fileURL absoluteString]])
		return [contentFilterContainer objectForKey:[fileURL absoluteString]];

	return [NSMutableDictionary dictionary];
}

- (NSArray *)queryFavoritesForFileURL:(NSURL *)fileURL andTabTrigger:(NSString *)tabTrigger includeGlobals:(BOOL)includeGlobals
{
	if(![tabTrigger length]) return [NSArray array];

	NSMutableArray *result = [[NSMutableArray alloc] init];
	for(id fav in [self favoritesForFileURL:fileURL]) {
		if([fav objectForKey:@"tabtrigger"] && [[fav objectForKey:@"tabtrigger"] isEqualToString:tabTrigger])
			[result addObject:fav];
	}
	
	if(includeGlobals && [prefs objectForKey:SPQueryFavorites]) {
		for(id fav in [prefs objectForKey:SPQueryFavorites]) {
			if([fav objectForKey:@"tabtrigger"] && [[fav objectForKey:@"tabtrigger"] isEqualToString:tabTrigger]) {
				[result addObject:fav];
				break;
			}
		}
	}
	
	return [result autorelease];
}

- (void)removeFavoriteAtIndex:(NSUInteger)index forFileURL:(NSURL *)fileURL
{
	[[favoritesContainer objectForKey:[fileURL absoluteString]] removeObjectAtIndex:index];
}

- (void)insertFavorite:(NSDictionary *)favorite atIndex:(NSUInteger)index forFileURL:(NSURL *)fileURL
{
	[[favoritesContainer objectForKey:[fileURL absoluteString]] insertObject:favorite atIndex:index];
}

#pragma mark -

/**
 * Dealloc.
 */
- (void)dealloc
{
	messagesVisibleSet = nil;
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	[dateFormatter release], dateFormatter = nil;
	
	[messagesFullSet release], messagesFullSet = nil;
	[messagesFilteredSet release], messagesFilteredSet = nil;
	[activeFilterString release], activeFilterString = nil;
	
	[favoritesContainer release], favoritesContainer = nil;
	[historyContainer release], historyContainer = nil;
	[contentFilterContainer release], contentFilterContainer = nil;

	if(completionKeywordList) [completionKeywordList release];
	if(completionFunctionList) [completionFunctionList release];
	if(functionArgumentSnippets) [functionArgumentSnippets release];
	[super dealloc];
}

@end

@implementation SPQueryController (PrivateAPI)

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

/**
 * Creates and returns a string made entirely of all of the console's messages and includes the message
 * time stamp and connection if specified.
 */
- (NSString *)_getConsoleStringWithTimeStamps:(BOOL)timeStamps connections:(BOOL)connections
{
	NSMutableString *consoleString = [NSMutableString string];
	
	for (SPConsoleMessage *message in messagesVisibleSet) 
	{
		// As we are going to save the messages as an SQL file we need to comment 
		// the timestamps and connections if included.
		if (timeStamps || connections) [consoleString appendString:@"/* "];
		
		// If the timestamp column is not hidden we need to include them in the copy
		if (timeStamps) {
			[consoleString appendString:[dateFormatter stringFromDate:[message messageDate]]];
			[consoleString appendString:@" "];					
		}
		
		// If the connection column is not hidden we need to include them in the copy
		if (connections) {
			[consoleString appendString:[message messageConnection]];
			[consoleString appendString:@" "];
		}
			
		// Close the comment
		if (timeStamps || connections) [consoleString appendString:@"*/ "];
		
		[consoleString appendString:[message message]];
		[consoleString appendString:@"\n"];		
	}
	
	return consoleString;
}

/**
 * Adds the supplied message to the query console.
 */
- (void)_addMessageToConsole:(NSString *)message connection:(NSString *)connection isError:(BOOL)error
{
	NSString *messageTemp = [[message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];

	// Only append a semi-colon (;) if the supplied message is not an error
	if (!error) {
		messageTemp = [messageTemp stringByAppendingString:@";"];
	}
	
	SPConsoleMessage *consoleMessage = [SPConsoleMessage consoleMessageWithMessage:messageTemp date:[NSDate date] connection:connection];
		
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
	if (allowConsoleUpdate && [[self window] isVisible]) {
		[consoleTableView noteNumberOfRowsChanged];
		[consoleTableView scrollRowToVisible:([messagesVisibleSet count] - 1)];
		[consoleTableView reloadData];
	}
}

@end
