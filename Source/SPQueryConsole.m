//
//  SPQueryConsole.m
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

#import "SPQueryConsole.h"
#import "SPConsoleMessage.h"

#define MESSAGE_TRUNCATE_CHARACTER_LENGTH 256
#define MESSAGE_TIME_STAMP_FORMAT @"%H:%M:%S"

#define DEFAULT_CONSOLE_LOG_FILENAME @"untitled"
#define DEFAULT_CONSOLE_LOG_FILE_EXTENSION @"log"

#define CONSOLE_WINDOW_AUTO_SAVE_NAME @"QueryConsole"

// Table view column identifiers
#define TABLEVIEW_MESSAGE_COLUMN_IDENTIFIER @"message"
#define TABLEVIEW_DATE_COLUMN_IDENTIFIER @"messageDate"

@interface SPQueryConsole (PrivateAPI)

- (NSString *)_getConsoleStringWithTimeStamps:(BOOL)timeStamps;

- (void)_hideSelectShowStatements:(BOOL)show;
- (void)_filterConsoleUsingSearchString:(NSString *)string;
- (void)_addMessageToConsole:(NSString *)message isError:(BOOL)error;

@end

static SPQueryConsole *sharedQueryConsole = nil;

@implementation SPQueryConsole

@synthesize consoleFont;

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
		messages          = [[NSMutableArray alloc] init];
		messagesSubset    = [[NSMutableArray alloc] init];
		messagesFilterSet = [[NSMutableArray alloc] init];
				
		// Weak reference
		messagesActiveSet = messages;
		messagesFilterSet = messagesActiveSet;
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
 * Set the window's auto save name.
 */
- (void)awakeFromNib
{
	[self setWindowFrameAutosaveName:CONSOLE_WINDOW_AUTO_SAVE_NAME];
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
		
		NSUInteger i = [rows firstIndex];
		
		while (i != NSNotFound) 
		{			
			if (i < [messagesFilterSet count]) {
				SPConsoleMessage *message = [messagesFilterSet objectAtIndex:i];
				
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
	[messages removeAllObjects];
	
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
	[[consoleTableView tableColumnWithIdentifier:TABLEVIEW_DATE_COLUMN_IDENTIFIER] setHidden:(![sender intValue])];
}

/**
 * Toggles the hiding of messages containing SELECT and SHOW statements
 */
- (IBAction)toggleShowSelectShowStatements:(id)sender
{
	[self _hideSelectShowStatements:(![sender intValue])];
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
	return [messages count];
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
	return [messagesFilterSet count];
}

/**
 * Table view delegate method. Returns the specific object for the request column and row.
 */
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSUInteger)row
{		
	NSString *returnValue = nil;
	
	id object = [[messagesFilterSet objectAtIndex:row] valueForKey:[tableColumn identifier]];
	
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
	if ([(SPConsoleMessage *)[messagesFilterSet objectAtIndex:row] isError]) {
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
		[self _filterConsoleUsingSearchString:[[object stringValue] lowercaseString]];
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

/**
 * Standard dealloc.
 */
- (void)dealloc
{
	messagesSubset = nil;
	
	[messages release], messages = nil;
	[messagesSubset release], messagesSubset = nil;
	[messagesFilterSet release], messagesFilterSet = nil;
	
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
	
	for (SPConsoleMessage *message in messagesFilterSet) 
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
 * Either hides or shows all SELECT and SHOW statements within the console.
 */
- (void)_hideSelectShowStatements:(BOOL)show
{		
	if (!show) {
		messagesActiveSet = messages;
		messagesFilterSet = messagesActiveSet;
		
		[consoleTableView reloadData];
		
		return;
	}
	
	messagesActiveSet = [messages mutableCopy];
		
	// Filter out messages that have a prefix of either SELECT or SHOW
	for (SPConsoleMessage *message in messages) 
	{
		if ([[message message] hasPrefix:@"SELECT"] || [[message message] hasPrefix:@"SHOW"]) {
			[messagesActiveSet removeObject:message];
		}
	}
	
	messagesFilterSet = messagesActiveSet;
	
	[consoleTableView reloadData];
}

/**
 * Filters the messages array using the supplued search string.
 */
- (void)_filterConsoleUsingSearchString:(NSString *)searchString
{
	// Display start progress spinner
	[progressIndicator setHidden:NO];
	[progressIndicator startAnimation:self];
	
	// Don't allow clearing the console while filtering its content
	[saveConsoleButton setEnabled:NO];
	[clearConsoleButton setEnabled:NO];
	
	[saveConsoleButton setTitle:@"Save View As..."];
	
    // If there's no search string assign the active messages array back to the message array 
    if ([searchString length] == 0) {
		[messagesFilterSet removeAllObjects];
		
		messagesFilterSet = messagesActiveSet;
        
		[consoleTableView reloadData];
		[consoleTableView scrollRowToVisible:([messagesFilterSet count] - 1)];
		
		[saveConsoleButton setEnabled:YES];
		[clearConsoleButton setEnabled:YES];
		
		[saveConsoleButton setTitle:@"Save As..."];
		
		// Display start progress spinner
		[progressIndicator setHidden:YES];
		[progressIndicator stopAnimation:self];
		
		return;
    }
	
	// Remove all objects in the subset
	[messagesSubset removeAllObjects];
 	
	// Filter the messages 
	for (SPConsoleMessage *message in messagesActiveSet) 
	{
		if ([[message message] rangeOfString:searchString options:NSCaseInsensitiveSearch].location != NSNotFound) {
			[messagesSubset addObject:message];
		}
	}
	
	messagesFilterSet = messagesSubset;
	
    [consoleTableView reloadData];
	[consoleTableView scrollRowToVisible:([messagesFilterSet count] - 1)];
	
	if ([messagesFilterSet count] > 0) {
		[saveConsoleButton setEnabled:YES];
	}
	
	// Display start progress spinner
	[progressIndicator setHidden:YES];
	[progressIndicator stopAnimation:self];
}

/**
 * Adds the supplied message to the query console.
 */
- (void)_addMessageToConsole:(NSString *)message isError:(BOOL)error
{		
	SPConsoleMessage *consoleMessage = [SPConsoleMessage consoleMessageWithMessage:[[message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByAppendingString:@";"] date:[NSDate date]];
	
	[consoleMessage setIsError:error];
	
	[messages addObject:consoleMessage];
	
	[consoleTableView reloadData];
	[consoleTableView scrollRowToVisible:([messages count] - 1)];	
}

@end
