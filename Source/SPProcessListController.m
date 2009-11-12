//
//  $Id$
//
//  SPProcessListController.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 12, 2009
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

#import <MCPKit/MCPKit.h>

#import "SPProcessListController.h"
#import "SPConstants.h"
#import "SPArrayAdditions.h"

@interface SPProcessListController (PrivateAPI)

- (void)_getDatabaseProcessList;
- (void)_killProcessQueryWithId:(NSUInteger)processId;
- (void)_killProcessConnectionWithId:(NSUInteger)processId;
- (void)_updateServerProcessesFilterForFilterString:(NSString *)filterString;

@end

@implementation SPProcessListController

@synthesize connection;

/**
 * Initialisation
 */
- (id)init
{
	if ((self = [super initWithWindowNibName:@"DatabaseProcessList"])) {
		processes = [[NSMutableArray alloc] init];
	}
	
	return self;
}

/**
 * Interface initialisation
 */
- (void)awakeFromNib
{
	// Set the process table view's vertical gridlines if required
	[processListTableView setGridStyleMask:([[NSUserDefaults standardUserDefaults] boolForKey:SPDisplayTableViewVerticalGridlines]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
}

#pragma mark -
#pragma mark IBAction methods

/**
 * Copies the currently selected process(es) to the pasteboard.
 */
- (IBAction)copy:(id)sender
{	
	NSResponder *firstResponder = [[self window] firstResponder];
	
	if ((firstResponder == processListTableView) && ([processListTableView numberOfSelectedRows] > 0)) {
		
		NSMutableString *string = [NSMutableString string];
		NSIndexSet *rows = [processListTableView selectedRowIndexes];
		
		NSUInteger i = [rows firstIndex];
		
		while (i != NSNotFound) 
		{
			if (i < [processesFiltered count]) {
				NSDictionary *process = NSArrayObjectAtIndex(processesFiltered, i);
				
				NSString *stringTmp = [NSString stringWithFormat:@"%@ %@ %@ %@ %@ %@ %@ %@",
									   [process objectForKey:@"Id"],
									   [process objectForKey:@"User"],
									   [process objectForKey:@"Host"],
									   [process objectForKey:@"db"],
									   [process objectForKey:@"Command"],
									   [process objectForKey:@"Time"],
									   [process objectForKey:@"State"],
									   [process objectForKey:@"Info"]];
				
				[string appendString:stringTmp];
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
 * Close the process list sheet.
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:[self window] returnCode:[sender tag]];
	[[self window] orderOut:self];
	
	// If the filtered array is allocated and it's not a reference to the processes array get rid of it
	if ((processesFiltered) && (processesFiltered != processes)) {
		[processesFiltered release], processesFiltered = nil;
	}		
}

/**
 * Refreshes the process list.
 */
- (IBAction)refreshProcessList:(id)sender
{
	// Start progress Indicator
	[refreshProgressIndicator startAnimation:self];
	[refreshProgressIndicator setHidden:NO];
	
	// Disable controls
	[refreshProcessesButton setEnabled:NO];
	[closeProcessListButton setEnabled:NO];
	[saveProcessesButton setEnabled:NO];
	[filterProcessesSearchField setEnabled:NO];
	
	[self _getDatabaseProcessList];
	
	// Reapply any filters is required
	if ([[filterProcessesSearchField stringValue] length] > 0) {
		[self _updateServerProcessesFilterForFilterString:[filterProcessesSearchField stringValue]];
	}
	
	[processListTableView reloadData];
	
	// Enable controls
	[filterProcessesSearchField setEnabled:YES];
	[saveProcessesButton setEnabled:YES];
	[closeProcessListButton setEnabled:YES];
	[refreshProcessesButton setEnabled:YES];
	
	// Stop progress Indicator
	[refreshProgressIndicator stopAnimation:self];
	[refreshProgressIndicator setHidden:YES];
}

/**
 * Saves the process list to the selected file.
 */
- (IBAction)saveServerProcesses:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
		
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:YES];
	[panel setCanSelectHiddenExtension:YES];
	
	[panel beginSheetForDirectory:nil file:@"ServerProcesses" modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

/**
 * Kills the currently selected process' query.
 */
- (IBAction)killProcessQuery:(id)sender
{
	// No process selected. Interface validation should prevent this.
	if ([processListTableView numberOfSelectedRows] != 1) return;
	
	NSUInteger processId = [[[processes objectAtIndex:[processListTableView selectedRow]] valueForKey:@"Id"] integerValue];
		
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Kill query?", @"kill query message")
									 defaultButton:NSLocalizedString(@"Kill", @"kill button") 
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button") 
									   otherButton:nil 
						 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to kill the current query executing on connection ID %d.\n\nPlease be aware that continuing to kill this query may result in data corruption. Please proceed with caution.", @"kill query informative message"), processId]];
	
	NSArray *buttons = [alert buttons];
	
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"k"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
	
	[alert setAlertStyle:NSCriticalAlertStyle];
	
	[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:SPKillProcessQueryMode];
}

/**
 * Kills the currently selected proceess' connection.
 */
- (IBAction)killProcessConnection:(id)sender
{
	// No process selected. Interface validation should prevent this.
	if ([processListTableView numberOfSelectedRows] != 1) return;
	
	NSUInteger processId = [[[processes objectAtIndex:[processListTableView selectedRow]] valueForKey:@"Id"] integerValue];
	
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Kill connection?", @"kill connection message")
									 defaultButton:NSLocalizedString(@"Kill", @"kill button") 
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button") 
									   otherButton:nil 
						 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to kill connection ID %d.\n\nPlease be aware that continuing to kill this connection may result in data corruption. Please proceed with caution.", @"kill connection informative message"), processId]];
	
	NSArray *buttons = [alert buttons];
	
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"k"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
	
	[alert setAlertStyle:NSCriticalAlertStyle];
	
	[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:SPKillProcessConnectionMode];
}

#pragma mark -
#pragma mark Other methods

/**
 * Displays the process list sheet attached to the supplied window.
 */
- (void)displayProcessListSheetAttachedToWindow:(NSWindow *)window
{
	// Weak reference
	processesFiltered = processes;
	
	// Get the current process list
	[self _getDatabaseProcessList];
	
	// Reload the tableview
	[processListTableView reloadData];
	
	// If the search field already has value from when the panel was previously open, apply the filter.
	if ([[filterProcessesSearchField stringValue] length] > 0) {
		[self _updateServerProcessesFilterForFilterString:[filterProcessesSearchField stringValue]];
	}
	 
	// Open the sheet
	[NSApp beginSheet:[self window] modalForWindow:window modalDelegate:self didEndSelector:nil contextInfo:nil];
}

/**
 * Invoked when the kill alerts are dismissed. Decide what to do based on the user's decision.
 */
- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	if (returnCode == NSAlertDefaultReturn) {
		NSUInteger processId = [[[processes objectAtIndex:[processListTableView selectedRow]] valueForKey:@"Id"] integerValue];
		
		if ([contextInfo isEqualToString:SPKillProcessQueryMode]) {
			[self _killProcessQueryWithId:processId];
		}
		else if ([contextInfo isEqualToString:SPKillProcessConnectionMode]) {
			[self _killProcessConnectionWithId:processId];
		}
	}
}

/**
 * Invoked when the save panel is dismissed.
 */
- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	if (returnCode == NSAlertDefaultReturn) {
		if ([processesFiltered count] > 0) {
			NSMutableString *processesString = [NSMutableString string];
			
			for (NSDictionary *process in processesFiltered)
			{
				NSString *stringTmp = [NSString stringWithFormat:@"%@ %@ %@ %@ %@ %@ %@ %@",
									   [process objectForKey:@"Id"],
									   [process objectForKey:@"User"],
									   [process objectForKey:@"Host"],
									   [process objectForKey:@"db"],
									   [process objectForKey:@"Command"],
									   [process objectForKey:@"Time"],
									   [process objectForKey:@"State"],
									   [process objectForKey:@"Info"]];
				
				[processesString appendString:stringTmp];
				[processesString appendString:@"\n"];
			}
			
			[processesString writeToFile:[panel filename] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
		}
	}
}

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = [menuItem action];
	
	if (action == @selector(copy:)) {
		return ([processListTableView numberOfSelectedRows] > 0);
	}
	
	if ((action == @selector(killProcessQuery:)) || (action == @selector(killProcessConnection:))) {
		return ([processListTableView numberOfSelectedRows] == 1);
	}
	
	return YES;
}

/**
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	if ([keyPath isEqualToString:SPDisplayTableViewVerticalGridlines]) {
        [processListTableView setGridStyleMask:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	}
}

#pragma mark -
#pragma mark Tableview delegate methods

/**
 * Table view delegate method. Returns the number of rows in the table veiw.
 */
- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [processesFiltered count];
}

/**
 * Table view delegate method. Returns the specific object for the request column and row.
 */
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{	
	id object = [[processesFiltered objectAtIndex:row] valueForKey:[tableColumn identifier]];
	
	return (![object isNSNull]) ? object : @"NULL";
}

#pragma mark -
#pragma mark Text field delegate methods

/**
 * Apply the filter string to the current process list.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	id object = [notification object];
	
	if (object == filterProcessesSearchField) {
		[self _updateServerProcessesFilterForFilterString:[object stringValue]];
	}
}

#pragma mark -

/**
 * Dealloc
 */
- (void)dealloc
{
	[processes release], processes = nil;
	
	[super dealloc];
}

@end

@implementation SPProcessListController (PrivateAPI)

/**
 * Gets the current process list form the database;
 */
- (void)_getDatabaseProcessList
{
	NSUInteger i = 0;
	
	// Get processes
	MCPResult *processList = [connection queryString:@"SHOW PROCESSLIST"];
	
	if ([processList numOfRows]) [processList dataSeek:0];
	
	[processes removeAllObjects];

	for (i = 0; i < [processList numOfRows]; i++) 
	{
		[processes addObject:[processList fetchRowAsDictionary]];
	}
}

/**
 * Attempts to kill the query executing on the connection associate with the supplied ID.
 */
- (void)_killProcessQueryWithId:(NSUInteger)processId
{
	// Kill the query
	[connection queryString:[NSString stringWithFormat:@"KILL QUERY %d", processId]];
	
	// Check for errors
	if (![[connection getLastErrorMessage] isEqualToString:@""]) {
		NSBeginAlertSheet(NSLocalizedString(@"Unable to kill query", @"error killing query message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [self window], self, nil, nil, nil,
						  [NSString stringWithFormat:NSLocalizedString(@"An error occured while attempting to kill the query associated with connection %d.\n\nMySQL said: %@", @"error killing query informative message"), processId, [connection getLastErrorMessage]]);
	}
	
	// Refresh the process list
	[self refreshProcessList:self];
}

/**
 * Attempts the kill the connection associated with the supplied ID.
 */
- (void)_killProcessConnectionWithId:(NSUInteger)processId
{
	// Kill the connection
	[connection queryString:[NSString stringWithFormat:@"KILL CONNECTION %d", processId]];
	
	// Check for errors
	if (![[connection getLastErrorMessage] isEqualToString:@""]) {
		NSBeginAlertSheet(NSLocalizedString(@"Unable to kill connection", @"error killing connection message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [self window], self, nil, nil, nil,
						  [NSString stringWithFormat:NSLocalizedString(@"An error occured while attempting to kill connection %d.\n\nMySQL said: %@", @"error killing query informative message"), processId, [connection getLastErrorMessage]]);
	}
	
	// Refresh the process list
	[self refreshProcessList:self];
}

/**
 * Filter the displayed server processes against the supplied filter string.
 */
- (void)_updateServerProcessesFilterForFilterString:(NSString *)filterString
{
	[saveProcessesButton setEnabled:NO];
		
	filterString = [[filterString lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	// If the filtered array is allocated and its not a reference to the processes array,
	// relase it to prevent memory leaks upon the next allocation.
	if ((processesFiltered) && (processesFiltered != processes)) {
		[processesFiltered release], processesFiltered = nil;
	}
	
	processesFiltered = [[NSMutableArray alloc] init];
	
	if ([filterString length] == 0) {
		[processesFiltered release];
		processesFiltered = processes;
		
		[saveProcessesButton setEnabled:YES];
		[saveProcessesButton setTitle:@"Save As..."];
		[processesCountTextField setStringValue:@""];
		
		[processListTableView reloadData];
		
		return;
	}
	
	// Perform filtering
	for (NSDictionary *process in processes) 
	{
		if (([[process objectForKey:@"Id"] rangeOfString:filterString options:NSCaseInsensitiveSearch].location != NSNotFound)      ||
			([[process objectForKey:@"User"] rangeOfString:filterString options:NSCaseInsensitiveSearch].location != NSNotFound)    ||
			([[process objectForKey:@"Host"] rangeOfString:filterString options:NSCaseInsensitiveSearch].location != NSNotFound)    ||
			((![[process objectForKey:@"db"] isNSNull]) && ([[process objectForKey:@"db"] rangeOfString:filterString options:NSCaseInsensitiveSearch].location != NSNotFound))      ||
			([[process objectForKey:@"Command"] rangeOfString:filterString options:NSCaseInsensitiveSearch].location != NSNotFound) ||
			([[process objectForKey:@"Time"] rangeOfString:filterString options:NSCaseInsensitiveSearch].location != NSNotFound)    ||
			((![[process objectForKey:@"State"] isNSNull]) && ([[process objectForKey:@"State"] rangeOfString:filterString options:NSCaseInsensitiveSearch].location != NSNotFound))   ||
			((![[process objectForKey:@"Info"] isNSNull]) && ([[process objectForKey:@"Info"] rangeOfString:filterString options:NSCaseInsensitiveSearch].location != NSNotFound)))
		{
			[processesFiltered addObject:process];
		}
	}
	
	[processListTableView reloadData];
	
	[processesCountTextField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%d of %d", "filtered server processes count"), [processesFiltered count], [processes count]]];
	[processesCountTextField setHidden:NO];
	
	if ([processesFiltered count] == 0) return;
	
	[saveProcessesButton setEnabled:YES];
	[saveProcessesButton setTitle:@"Save View As..."];
}

@end
