//
//  SPQueryConsole.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Jan 30, 2009
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

#import "SPQueryConsole.h"
#import "SPConsoleMessage.h"

#define MESSAGE_TRUNCATE_CHARACTER_LENGTH 256
#define MESSAGE_TIME_STAMP_FORMAT @"%H:%M:%S"

#define DEFAULT_CONSOLE_LOG_FILENAME @"untitled"
#define DEFAULT_CONSOLE_LOG_FILE_EXTENSION @"sql"

#define CONSOLE_WINDOW_AUTO_SAVE_NAME @"QueryConsole"

// Table view column identifiers
#define TABLEVIEW_MESSAGE_COLUMN_IDENTIFIER @"message"
#define TABLEVIEW_DATE_COLUMN_IDENTIFIER @"messageDate"

@interface SPQueryConsole (PrivateAPI)

- (NSString *)_getConsoleStringWithTimeStamps:(BOOL)timeStamps;

- (void)_updateFilterState;
- (void)_addMessageToConsole:(NSString *)message isError:(BOOL)error;
- (BOOL)_messageMatchesCurrentFilters:(NSString *)message;

@end

static SPQueryConsole *sharedQueryConsole = nil;

@implementation SPQueryConsole

/*
 * Returns the shared query console.
 */
+ (SPQueryConsole *)sharedQueryConsole
{
    @synchronized(self) {
        if (sharedQueryConsole == nil) {
            [[self alloc] init];
        }
    }
    
    return sharedQueryConsole;
}

+ (id)allocWithZone:(NSZone *)zone
{    
    @synchronized(self) {
        if (sharedQueryConsole == nil) {
            sharedQueryConsole = [super allocWithZone:zone];
            
            return sharedQueryConsole;
        }
    }
    
    return nil; // On subsequent allocation attempts return nil
}

- (id)init
{
	if ((self = [super initWithWindowNibName:@"Console"])) {
		messagesFullSet		= [[NSMutableArray alloc] init];
		messagesFilteredSet	= [[NSMutableArray alloc] init];
		consoleFont			= [[NSFont systemFontOfSize:[NSFont smallSystemFontSize]] retain];

		showSelectStatementsAreDisabled = NO;
		filterIsActive = NO;
		activeFilterString = [[NSMutableString alloc] init];

		// Weak reference to active messages set - starts off as full set
		messagesVisibleSet = messagesFullSet;

		uncollapsedDateColumnWidth = [[consoleTableView tableColumnWithIdentifier:TABLEVIEW_DATE_COLUMN_IDENTIFIER] width];
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
	[self setWindowFrameAutosaveName:CONSOLE_WINDOW_AUTO_SAVE_NAME];
	if (![[NSUserDefaults standardUserDefaults] boolForKey:@"ConsoleShowTimestamps"]) {
		uncollapsedDateColumnWidth = [[consoleTableView tableColumnWithIdentifier:TABLEVIEW_DATE_COLUMN_IDENTIFIER] width];
		[[consoleTableView tableColumnWithIdentifier:TABLEVIEW_DATE_COLUMN_IDENTIFIER] setMinWidth:0.0];
		[[consoleTableView tableColumnWithIdentifier:TABLEVIEW_DATE_COLUMN_IDENTIFIER] setWidth: 0.0];	
	}
	showSelectStatementsAreDisabled = ![[NSUserDefaults standardUserDefaults] boolForKey:@"ConsoleShowSelectsAndShows"];
	[self _updateFilterState];
}

/**
 * Copy implementation for console table view.
 */
- (void)copy:(id)sender
{
	NSResponder *firstResponder = [[self window] firstResponder];

	if ((firstResponder == consoleTableView) && ([consoleTableView numberOfSelectedRows] > 0)) {

		NSString *string = @"";
		NSIndexSet *rows = [consoleTableView selectedRowIndexes];

		int i = [rows firstIndex];

		while (i != NSNotFound) 
		{
			if (i < [messagesVisibleSet count]) {
				SPConsoleMessage *message = [messagesVisibleSet objectAtIndex:i];

				NSString *consoleMessage = [message message];

				// If the timestamp column is not hidden we need to include them in the copy
				if ([[consoleTableView tableColumnWithIdentifier:TABLEVIEW_DATE_COLUMN_IDENTIFIER] width] > 0) {

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
	[panel beginSheetForDirectory:nil 
							 file:DEFAULT_CONSOLE_LOG_FILENAME 
				   modalForWindow:[self window] 
					modalDelegate:self 
				   didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) 
					  contextInfo:NULL];
}

/**
 * Toggles the display of the message time stamp column in the table view.
 */
- (IBAction)toggleShowTimeStamps:(id)sender
{
	if ([sender state]) {
		[[consoleTableView tableColumnWithIdentifier:TABLEVIEW_DATE_COLUMN_IDENTIFIER] setMinWidth:50.0];
		[[consoleTableView tableColumnWithIdentifier:TABLEVIEW_DATE_COLUMN_IDENTIFIER] setWidth:uncollapsedDateColumnWidth];
	} else {
		uncollapsedDateColumnWidth = [[consoleTableView tableColumnWithIdentifier:TABLEVIEW_DATE_COLUMN_IDENTIFIER] width];
		[[consoleTableView tableColumnWithIdentifier:TABLEVIEW_DATE_COLUMN_IDENTIFIER] setMinWidth:0.0];
		[[consoleTableView tableColumnWithIdentifier:TABLEVIEW_DATE_COLUMN_IDENTIFIER] setWidth: 0.0];
	}
}

/**
 * Toggles the hiding of messages containing SELECT and SHOW statements
 */
- (IBAction)toggleShowSelectShowStatements:(id)sender
{

	// Store the state of the toggle for later quick reference
	showSelectStatementsAreDisabled = ![sender state];

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
- (int)consoleMessageCount
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
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
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

- (NSFont *)consoleFont
{
	return consoleFont;
}

- (void)setConsoleFont:(NSFont *)theFont
{
	if (consoleFont) [consoleFont release];
	consoleFont = [theFont copy];
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
	[consoleFont release], consoleFont = nil;

	[super dealloc];
}

@end

@implementation SPQueryConsole (PrivateAPI)

/**
 * Creates and returns a string made entirely of all of the console's messages and includes the message
 * time stamps if specified.
 */
- (NSString *)_getConsoleStringWithTimeStamps:(BOOL)timeStamps
{
	NSMutableString *consoleString = [[[NSMutableString alloc] init] autorelease];
	int i;

	for (i = 0; i < [messagesVisibleSet count]; i++) {
		SPConsoleMessage *message = [messagesVisibleSet objectAtIndex:i];
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
	int i;

	// Display start progress spinner
	[progressIndicator setHidden:NO];
	[progressIndicator startAnimation:self];

	// Don't allow clearing the console while filtering its content
	[saveConsoleButton setEnabled:NO];
	[clearConsoleButton setEnabled:NO];

	[messagesFilteredSet removeAllObjects];

	// If filtering is disabled and all show/selects are shown, empty the filtered
	// result set and set the full set to visible.
	if (!filterIsActive && !showSelectStatementsAreDisabled) {
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
	for (i = 0; i < [messagesFullSet count]; i++) {
		SPConsoleMessage *message = [messagesFullSet objectAtIndex:i]; 

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
	NSMutableString *mutableMessage = [NSMutableString stringWithString:[message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
	[mutableMessage replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0, [mutableMessage length])];
	SPConsoleMessage *consoleMessage = [SPConsoleMessage consoleMessageWithMessage:[mutableMessage stringByAppendingString:@";"] date:[NSDate date]];

	[consoleMessage setIsError:error];

	[messagesFullSet addObject:consoleMessage];

	// If filtering is active, determine whether to add a reference to the filtered set
	if ((showSelectStatementsAreDisabled || filterIsActive)
		&& [self _messageMatchesCurrentFilters:[consoleMessage message]])
	{
		[messagesFilteredSet addObject:[messagesFullSet lastObject]];
		[saveConsoleButton setEnabled:YES];
		[clearConsoleButton setEnabled:YES];
	}

	// Reload the table and scroll to the new message
	[consoleTableView reloadData];
	[consoleTableView scrollRowToVisible:([messagesVisibleSet count] - 1)];
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

	return messageMatchesCurrentFilters;
}

@end
