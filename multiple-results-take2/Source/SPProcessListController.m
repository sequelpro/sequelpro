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

#import "SPProcessListController.h"
#import "SPArrayAdditions.h"
#import "SPDatabaseDocument.h"
#import "SPConstants.h"
#import "SPAlertSheets.h"

#define TABLEVIEW_ID_COLUMN_IDENTIFIER @"Id"

@interface SPProcessListController (PrivateAPI)

- (void)_processListRefreshed;
- (void)_startAutoRefreshTimer;
- (void)_killAutoRefreshTimer;
- (void)_fireAutoRefresh:(NSTimer *)timer;
- (void)_updateSelectedAutoRefreshIntervalInterface;
- (void)_startAutoRefreshTimerWithInterval:(NSTimeInterval)interval;
- (void)_getDatabaseProcessListInBackground:(id)object;
- (void)_killProcessQueryWithId:(NSUInteger)processId;
- (void)_killProcessConnectionWithId:(NSUInteger)processId;
- (void)_updateServerProcessesFilterForFilterString:(NSString *)filterString;

@end

@implementation SPProcessListController

@synthesize connection;

#pragma mark -
#pragma mark Initialisation

/**
 * Initialisation
 */
- (id)init
{
	if ((self = [super initWithWindowNibName:@"DatabaseProcessList"])) {
		
		autoRefreshTimer = nil;
		processListThreadRunning = NO;
		
		processes = [[NSMutableArray alloc] init];
		
		prefs = [NSUserDefaults standardUserDefaults];
	}
	
	return self;
}

/**
 * Interface initialisation
 */
- (void)awakeFromNib
{	
	[[self window] setTitle:[NSString stringWithFormat:@"%@ %@", [[[NSApp delegate] frontDocument] name], NSLocalizedString(@"Server Processes", @"server processes window title")]];
	
	[self setWindowFrameAutosaveName:@"ProcessList"];
	
	// Show/hide table columns
	[[processListTableView tableColumnWithIdentifier:TABLEVIEW_ID_COLUMN_IDENTIFIER] setHidden:![prefs boolForKey:SPProcessListShowProcessID]];
	
	// Set the process table view's vertical gridlines if required
	[processListTableView setGridStyleMask:([prefs boolForKey:SPDisplayTableViewVerticalGridlines]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];

	// Set the strutcture and index view's font
	BOOL useMonospacedFont = [prefs boolForKey:SPUseMonospacedFonts];
	
	for (NSTableColumn *column in [processListTableView tableColumns])
	{
		[[column dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}
	
	// Register as an observer for the when the UseMonospacedFonts preference changes
	[prefs addObserver:self forKeyPath:SPUseMonospacedFonts options:NSKeyValueObservingOptionNew context:NULL];
}

/**
 * Interface loading
 */
- (void)windowDidLoad
{
	// Update the selected auto refresh interval
	[self _updateSelectedAutoRefreshIntervalInterface];
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
 * Close the current sheet
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

/**
 * If required start the auto refresh timer.
 */
- (void)showWindow:(id)sender
{
	// If the auto refresh option is enable start the timer
	if ([prefs boolForKey:SPProcessListEnableAutoRefresh]) {
		
		// Start the auto refresh time but by pass the interface updates
		[self _startAutoRefreshTimer];
	}
	
	[super showWindow:sender];
}

/**
 * Refreshes the process list.
 */
- (IBAction)refreshProcessList:(id)sender
{
	// If the document is currently performing a task (most likely threaded) on the current connection, don't
	// allow a refresh to prevent connection lock errors.
	if ([(SPDatabaseDocument *)[connection delegate] isWorking]) return;
	
	// Also, only proceed if there is not already a background thread running.
	if (processListThreadRunning) return;
	
	// Start progress Indicator
	[refreshProgressIndicator startAnimation:self];
	[refreshProgressIndicator setHidden:NO];
	
	// Disable controls
	[refreshProcessesButton setEnabled:NO];
	[saveProcessesButton setEnabled:NO];
	[filterProcessesSearchField setEnabled:NO];
	
	processListThreadRunning = YES;
		
	// Get the processes list on a background thread
	[NSThread detachNewThreadSelector:@selector(_getDatabaseProcessListInBackground:) toTarget:self withObject:nil];
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
						 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to kill the current query executing on connection ID %lu?\n\nPlease be aware that continuing to kill this query may result in data corruption. Please proceed with caution.", @"kill query informative message"), (unsigned long)processId]];
	
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
						 informativeTextWithFormat:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to kill connection ID %lu?\n\nPlease be aware that continuing to kill this connection may result in data corruption. Please proceed with caution.", @"kill connection informative message"), (unsigned long)processId]];
	
	NSArray *buttons = [alert buttons];
	
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"k"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
	
	[alert setAlertStyle:NSCriticalAlertStyle];
	
	[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:SPKillProcessConnectionMode];
}

/**
 * Toggles the display of the process ID table column.
 */
- (IBAction)toggleShowProcessID:(id)sender
{
	[[processListTableView tableColumnWithIdentifier:TABLEVIEW_ID_COLUMN_IDENTIFIER] setHidden:([sender state])];
}

/**
 * Toggles whether or not auto refresh is enabled.
 */
- (IBAction)toggleProcessListAutoRefresh:(id)sender
{
	BOOL enable = [sender state];
	
	// Enable/Disable the refresh button
	[refreshProcessesButton setEnabled:(!enable)];
	
	(enable) ? [self _startAutoRefreshTimer] : [self _killAutoRefreshTimer];
}

/**
 * Changes the auto refresh time interval based on the selected item
 */
- (IBAction)setAutoRefreshInterval:(id)sender
{
	[self _startAutoRefreshTimerWithInterval:[sender tag]];
}

/**
 *
 */
- (IBAction)setCustomAutoRefreshInterval:(id)sender
{
	[customIntervalTextField setStringValue:[prefs stringForKey:SPProcessListAutoRrefreshInterval]];
	
	[NSApp beginSheet:customIntervalWindow
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

#pragma mark -
#pragma mark Other methods

/**
 * Displays the process list sheet attached to the supplied window.
 */
- (void)displayProcessListWindow
{
	// Weak reference
	processesFiltered = processes;
	
	[self refreshProcessList:self];
	 
	[self showWindow:self];
}

/**
 * Invoked when the kill alerts are dismissed. Decide what to do based on the user's decision.
 */
- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	// Order out current sheet to suppress overlapping of sheets
	if ([sheet respondsToSelector:@selector(orderOut:)]) {
		[sheet orderOut:nil];
	}
	else if ([sheet respondsToSelector:@selector(window)]) {
		[[sheet window] orderOut:nil];
	}

	if (returnCode == NSAlertDefaultReturn) {
		
		if (sheet == customIntervalWindow) {			
			[self _startAutoRefreshTimerWithInterval:[customIntervalTextField integerValue]];
		}
		else {
			NSUInteger processId = [[[processes objectAtIndex:[processListTableView selectedRow]] valueForKey:@"Id"] integerValue];
			
			if ([contextInfo isEqualToString:SPKillProcessQueryMode]) {
				[self _killProcessQueryWithId:processId];
			}
			else if ([contextInfo isEqualToString:SPKillProcessConnectionMode]) {
				[self _killProcessConnectionWithId:processId];
			}
		}
	}
}

/**
 * Invoked when the save panel is dismissed.
 */
- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	if (returnCode == NSOKButton) {
		if ([processesFiltered count] > 0) {
			NSMutableString *processesString = [NSMutableString stringWithFormat:@"# MySQL server proceese for %@\n\n", [[[NSApp delegate] frontDocument] host]];
			
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
	
	if ((action == @selector(setAutoRefreshInterval:)) || (action == @selector(setCustomAutoRefreshInterval:))) {
		return [prefs boolForKey:SPProcessListEnableAutoRefresh];
	}
	
	return YES;
}

/**
 * NSWindow autosave name
 */
- (NSString *)windowFrameAutosaveName
{
	return @"ProcessList";
}

/**
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	// Display table veiew vertical gridlines preference changed
	if ([keyPath isEqualToString:SPDisplayTableViewVerticalGridlines]) {
        [processListTableView setGridStyleMask:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	}
	// Use monospaced fonts preference changed
	else if ([keyPath isEqualToString:SPUseMonospacedFonts]) {
		
		BOOL useMonospacedFont = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
		
		for (NSTableColumn *column in [processListTableView tableColumns])
		{
			[[column dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}
		
		[processListTableView reloadData];
	}
}

#pragma mark -
#pragma mark Tableview delegate methods

/**
 * Table view delegate method. Returns the number of rows in the table veiw.
 */
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [processesFiltered count];
}

/**
 * Table view delegate method. Returns the specific object for the request column and row.
 */
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{	
	id object = (row < [processesFiltered count]) ? [[processesFiltered objectAtIndex:row] valueForKey:[tableColumn identifier]] : @"";
		
	return (![object isNSNull]) ? object : [prefs stringForKey:SPNullValue];
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
	else if (object == customIntervalTextField) {
		[customIntervalButton setEnabled:(([[customIntervalTextField stringValue] length] > 0) && ([customIntervalTextField integerValue] > 0))];
	}
}

#pragma mark -
#pragma mark Window delegate methods

/**
 * Kill the auto refresh timer if it's running.
 */
- (void)windowWillClose:(NSNotification *)notification
{	
	// If the filtered array is allocated and it's not a reference to the processes array get rid of it
	if ((processesFiltered) && (processesFiltered != processes)) {
		[processesFiltered release], processesFiltered = nil;
	}
	
	// Kill the auto refresh timer if running
	[self _killAutoRefreshTimer];	
}

#pragma mark -

/**
 * Dealloc
 */
- (void)dealloc
{
	[prefs removeObserver:self forKeyPath:SPUseMonospacedFonts];

	processListThreadRunning = NO;
	
	[processes release], processes = nil;
	
	if (autoRefreshTimer) [autoRefreshTimer release], autoRefreshTimer = nil;
	
	[super dealloc];
}

#pragma mark -
#pragma mark Private API

/**
 * Called by the background thread on the main thread once it has completed getting the list of processes.
 */
- (void)_processListRefreshed
{
	processListThreadRunning = NO;
	
	// Reapply any filters is required
	if ([[filterProcessesSearchField stringValue] length] > 0) {
		[self _updateServerProcessesFilterForFilterString:[filterProcessesSearchField stringValue]];
	}
	
	[processListTableView reloadData];
	
	// Enable controls
	[filterProcessesSearchField setEnabled:YES];
	[saveProcessesButton setEnabled:YES];
	[refreshProcessesButton setEnabled:(![autoRefreshButton state])];
	
	// Stop progress Indicator
	[refreshProgressIndicator stopAnimation:self];
	[refreshProgressIndicator setHidden:YES];
}

/**
 * Starts the auto refresh timer.
 */
- (void)_startAutoRefreshTimer
{		
	autoRefreshTimer = [[NSTimer scheduledTimerWithTimeInterval:[prefs doubleForKey:SPProcessListAutoRrefreshInterval] target:self selector:@selector(_fireAutoRefresh:) userInfo:nil repeats:YES] retain];
}

/**
 * Kills the auto refresh timer.
 */
- (void)_killAutoRefreshTimer
{
	// If the auto refresh timer is running, kill it
	if (autoRefreshTimer && [autoRefreshTimer isValid]) {		
		[autoRefreshTimer invalidate];
		[autoRefreshTimer release], autoRefreshTimer = nil;
	}
}

/**
 * Refreshes the process list when called by the auto refesh timer.
 */
- (void)_fireAutoRefresh:(NSTimer *)timer
{	
	[self refreshProcessList:self];
}

/**
 *
 */
- (void)_updateSelectedAutoRefreshIntervalInterface
{	
	BOOL found = NO;
	NSUInteger interval = [prefs integerForKey:SPProcessListAutoRrefreshInterval];
	
	NSArray *items = [[autoRefreshIntervalMenuItem submenu] itemArray];
	
	// Uncheck all items
	for (NSMenuItem *item in items)
	{
		[item setState:NSOffState];
	}
	
	// Check the selected item
	for (NSMenuItem *item in items)
	{ 		
		if (interval == [item tag]) {
			found = YES;
			[item setState:NSOnState];
			break;
		}
	}
	
	// If a match wasn't found then a custom value is set
	if (!found) [[items objectAtIndex:([items count] - 1)] setState:NSOnState];
}

/**
 * Starts the auto refresh time with the supplied time interval.
 */
- (void)_startAutoRefreshTimerWithInterval:(NSTimeInterval)interval
{
	[prefs setDouble:interval forKey:SPProcessListAutoRrefreshInterval];
	
	// Update the interface
	[self _updateSelectedAutoRefreshIntervalInterface];
	
	// Kill the timer and restart it with the new interval
	[self _killAutoRefreshTimer];
	[self _startAutoRefreshTimer];
}

/**
 * Gets a list of current database processed on a background thread.
 */
- (void)_getDatabaseProcessListInBackground:(id)object;
{	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSUInteger i = 0;
	
	// Get processes
	if ([connection isConnected]) {
		
		MCPResult *processList = [connection listProcesses];
		
		[processList setReturnDataAsStrings:YES];
		
		if ([processList numOfRows]) [processList dataSeek:0];
		
		[processes removeAllObjects];
		
		for (i = 0; i < [processList numOfRows]; i++) 
		{
			[processes addObject:[processList fetchRowAsDictionary]];
		}
	}
	
	// Update the UI on the main thread
	[self performSelectorOnMainThread:@selector(_processListRefreshed) withObject:nil waitUntilDone:NO];
	
	[pool release];
}

/**
 * Attempts to kill the query executing on the connection associate with the supplied ID.
 */
- (void)_killProcessQueryWithId:(NSUInteger)processId
{
	// Kill the query
	[connection queryString:[NSString stringWithFormat:@"KILL QUERY %lu", (unsigned long)processId]];
	
	// Check for errors
	if ([connection queryErrored]) {
		SPBeginAlertSheet(NSLocalizedString(@"Unable to kill query", @"error killing query message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [self window], self, nil, nil,
						  [NSString stringWithFormat:NSLocalizedString(@"An error occured while attempting to kill the query associated with connection %lu.\n\nMySQL said: %@", @"error killing query informative message"), (unsigned long)processId, [connection getLastErrorMessage]]);
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
	[connection queryString:[NSString stringWithFormat:@"KILL CONNECTION %lu", (unsigned long)processId]];
	
	// Check for errors
	if ([connection queryErrored]) {
		SPBeginAlertSheet(NSLocalizedString(@"Unable to kill connection", @"error killing connection message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [self window], self, nil, nil,
						  [NSString stringWithFormat:NSLocalizedString(@"An error occured while attempting to kill connection %lu.\n\nMySQL said: %@", @"error killing query informative message"), (unsigned long)processId, [connection getLastErrorMessage]]);
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
		[saveProcessesButton setTitle:NSLocalizedString(@"Save As...", @"save as button title")];
		[processesCountTextField setStringValue:@""];
		
		[processListTableView reloadData];
		
		return;
	}
	
	// Perform filtering
	for (NSDictionary *process in processes) 
	{
		if (([[process objectForKey:@"Id"] rangeOfString:filterString options:NSCaseInsensitiveSearch].location != NSNotFound) ||
			([[process objectForKey:@"User"] rangeOfString:filterString options:NSCaseInsensitiveSearch].location != NSNotFound) ||
			([[process objectForKey:@"Host"] rangeOfString:filterString options:NSCaseInsensitiveSearch].location != NSNotFound) ||
			((![[process objectForKey:@"db"] isNSNull]) && ([[process objectForKey:@"db"] rangeOfString:filterString options:NSCaseInsensitiveSearch].location != NSNotFound)) ||
			([[process objectForKey:@"Command"] rangeOfString:filterString options:NSCaseInsensitiveSearch].location != NSNotFound) ||
			([[process objectForKey:@"Time"] rangeOfString:filterString options:NSCaseInsensitiveSearch].location != NSNotFound) ||
			((![[process objectForKey:@"State"] isNSNull]) && ([[process objectForKey:@"State"] rangeOfString:filterString options:NSCaseInsensitiveSearch].location != NSNotFound)) ||
			((![[process objectForKey:@"Info"] isNSNull]) && ([[process objectForKey:@"Info"] rangeOfString:filterString options:NSCaseInsensitiveSearch].location != NSNotFound)))
		{
			[processesFiltered addObject:process];
		}
	}
	
	[processListTableView reloadData];
	
	[processesCountTextField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Showing %lu of %lu processes", "filtered item count"), (unsigned long)[processesFiltered count], (unsigned long)[processes count]]];
	[processesCountTextField setHidden:NO];
	
	if ([processesFiltered count] == 0) return;
	
	[saveProcessesButton setEnabled:YES];
	[saveProcessesButton setTitle:NSLocalizedString(@"Save View As...", @"save view as button title")];
}

@end
