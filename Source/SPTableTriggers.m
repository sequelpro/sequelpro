//
//  $Id$
//
//  SPTableTriggers.m
//  sequel-pro
//
//  Created by Marius Ursache
//  Copyright (c) 2010 Marius Ursache. All rights reserved.
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

#import "SPTableTriggers.h"
#import "SPDatabaseDocument.h"
#import "SPTablesList.h"
#import "SPTableData.h"
#import "SPStringAdditions.h"
#import "SPConstants.h"
#import "SPAlertSheets.h"

@interface SPTableTriggers (PrivateAPI)

- (void)_toggleConfirmAddTriggerButtonEnabled;
- (void)_refreshTriggerDataForcingCacheRefresh:(BOOL)clearAllCaches;

@end

@implementation SPTableTriggers

@synthesize connection;

/**
 * init
 */
- (id)init
{
	if ((self = [super init])) {
		triggerData = [[NSMutableArray alloc] init];
		isEdit = NO;
	}

	return self;
}

/**
 * Register to listen for table selection changes upon nib awakening.
 */
- (void)awakeFromNib
{
	// Set the table triggers view's vertical gridlines if required
	[triggersTableView setGridStyleMask:([[NSUserDefaults standardUserDefaults] boolForKey:SPDisplayTableViewVerticalGridlines]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];

	// Set the strutcture and index view's font
	BOOL useMonospacedFont = [[NSUserDefaults standardUserDefaults] boolForKey:SPUseMonospacedFonts];

	for (NSTableColumn *column in [triggersTableView tableColumns])
	{
		[[column dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}

	// Register as an observer for the when the UseMonospacedFonts preference changes
	[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:SPUseMonospacedFonts options:NSKeyValueObservingOptionNew context:NULL];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(triggerStatementTextDidChange:)
												 name:NSTextStorageDidProcessEditingNotification
											   object:[triggerStatementTextView textStorage]];

	// Add observers for document task activity
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(startDocumentTaskForTab:)
												 name:SPDocumentTaskStartNotification
											   object:tableDocumentInstance];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(endDocumentTaskForTab:)
												 name:SPDocumentTaskEndNotification
											   object:tableDocumentInstance];
}

/**
 * Called whenever the user selects the triggers tab for the first time,
 * or switches between tables with the triggers tab active.
 */
- (void)loadTriggers
{
	BOOL enableInteraction = ((![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableTriggers]) || (![tableDocumentInstance isWorking]));

	// Disable all interface elements by default
	[addTriggerButton setEnabled:NO];
	[refreshTriggersButton setEnabled:NO];
	[triggersTableView setEnabled:NO];
	[labelTextField setStringValue:@""];

	// Show a warning if the version of MySQL is too low to support triggers
	if ([connection serverMajorVersion] < 5
		|| ([connection serverMajorVersion]     == 5
			&& [connection serverMinorVersion]  == 0
			&& [connection serverReleaseVersion] < 2))
	{
		[labelTextField setStringValue:NSLocalizedString(@"This version of MySQL does not support triggers. Support for triggers was added in MySQL 5.0.2", @"triggers not supported label")];
		return;
	}

	// If no item is selected, or the item selected is not a table, return.
	if (![tablesListInstance tableName] || [tablesListInstance tableType] != SPTableTypeTable)
		return;

	// Update the text label
	[labelTextField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Triggers for table: %@", @"triggers for table label"), [tablesListInstance tableName]]];

	// Enable interface elements
	[addTriggerButton setEnabled:enableInteraction];
	[refreshTriggersButton setEnabled:enableInteraction];
	[triggersTableView setEnabled:YES];

	// Ensure trigger data is loaded
	[self _refreshTriggerDataForcingCacheRefresh:NO];
}

#pragma mark -
#pragma mark IB action methods

/**
 * Closes the trigers sheet.
 */
- (IBAction)closeTriggerSheet:(id)sender
{
	[NSApp endSheet:addTriggerPanel returnCode:0];
	[addTriggerPanel orderOut:self];
}

/**
 * Add a new trigger using the selected values.
 */
- (IBAction)confirmAddTrigger:(id)sender
{
	[self closeTriggerSheet:self];

	// MySQL doesn't have ALTER TRIGGER, so we delete the old one and add a new one.
	// In case of error, all the old trigger info is kept in buffer
	if(isEdit && [editTriggerName length]>0)
	{
		NSString *queryDelete = [NSString stringWithFormat:@"DROP TRIGGER %@.%@",
								 [[tableDocumentInstance database] backtickQuotedString],
								 [editTriggerName backtickQuotedString]];
		[connection queryString:queryDelete];
		if([connection queryErrored])
		{
			SPBeginAlertSheet(NSLocalizedString(@"Unable to delete trigger",
												@"error deleting trigger message"),
							  NSLocalizedString(@"OK", @"OK button"),
							  nil, nil, [NSApp mainWindow], nil, nil, nil,
							  [NSString stringWithFormat:NSLocalizedString(@"The selected trigger couldn't be deleted.\n\nMySQL said: %@",
																		   @"error deleting trigger informative message"),
							   [connection getLastErrorMessage]]);
		}
	}

	NSString *triggerName       = [triggerNameTextField stringValue];
	NSString *triggerActionTime = ([triggerActionTimePopUpButton indexOfSelectedItem]) ? @"AFTER" : @"BEFORE";
	NSString *triggerEvent      = @"";
	switch([triggerEventPopUpButton indexOfSelectedItem]) {
		case 0: triggerEvent = @"INSERT";
		case 1: triggerEvent = @"UPDATE";
		case 2: triggerEvent = @"DELETE";
	}
	NSString *triggerStatement  = [triggerStatementTextView string];

	NSString *query = [NSString stringWithFormat:@"CREATE TRIGGER %@ %@ %@ ON %@ FOR EACH ROW %@",
					   [triggerName backtickQuotedString],
					   triggerActionTime,
					   triggerEvent,
					   [[tablesListInstance tableName] backtickQuotedString],
					   triggerStatement];

	// Execute query
	[connection queryString:query];

	if (([connection queryErrored])) {
		SPBeginAlertSheet(NSLocalizedString(@"Error creating trigger",
											@"error creating trigger message"),
						  NSLocalizedString(@"OK", @"OK button"),
						  nil, nil, [NSApp mainWindow], nil, nil, nil,
						  [NSString stringWithFormat:NSLocalizedString(@"The specified trigger was unable to be created.\n\nMySQL said: %@",
																	   @"error creating trigger informative message"),
						   [connection getLastErrorMessage]]);
		// In case of error, restore the original trigger statement
		if(isEdit) {
			[triggerStatementTextView setString:editTriggerStatement];
		}
	}
	else {
		[triggerNameTextField setStringValue:@""];
		[triggerStatementTextView setString:@""];
	}

	// After Edit, rename button to Add
	if(isEdit)
	{
		isEdit = NO;
		[confirmAddTriggerButton setTitle: NSLocalizedString(@"Add", @"Add trigger button")];
	}

	[self _refreshTriggerDataForcingCacheRefresh:YES];
}

/**
 * Displays the add new trigger sheet.
 */
- (IBAction)addTrigger:(id)sender
{

	[NSApp beginSheet:addTriggerPanel
	   modalForWindow:[tableDocumentInstance parentWindow]
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
}

/**
 * Removes the selected trigger.
 */
- (IBAction)removeTrigger:(id)sender
{
	if ([triggersTableView numberOfSelectedRows] > 0) {

		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Delete trigger", @"delete trigger message")
										 defaultButton:NSLocalizedString(@"Delete", @"delete button")
									   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
										   otherButton:nil
							 informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to delete the selected triggers? This action cannot be undone.", @"delete selected trigger informative message")];

		[alert setAlertStyle:NSCriticalAlertStyle];

		NSArray *buttons = [alert buttons];

		// Change the alert's cancel button to have the key equivalent of return
		[[buttons objectAtIndex:0] setKeyEquivalent:@"d"];
		[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
		[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];

		[alert beginSheetModalForWindow:[tableDocumentInstance parentWindow] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:@"removeTrigger"];
	}
}

/**
 * Trigger a refresh of the displayed triggers via the interface.
 */
- (IBAction)refreshTriggers:(id)sender
{
	[self _refreshTriggerDataForcingCacheRefresh:YES];
}

#pragma mark -
#pragma mark Tableview datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [triggerData count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	return [[triggerData objectAtIndex:rowIndex] objectForKey:[tableColumn identifier]];
}

#pragma mark -
#pragma mark Tableview delegate methods

/**
 * Called whenever the triggers table view selection changes.
 */
- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	[removeTriggerButton setEnabled:([triggersTableView numberOfSelectedRows] > 0)];
}

/**
 * Double-click action on table cells - for the time being, return NO to disable editing.
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if ([tableDocumentInstance isWorking]) return NO;

	// Start Edit panel
	if([triggerData count] > rowIndex && [triggerData objectAtIndex:rowIndex] != NSNotFound)
	{
		NSDictionary *trigger = [triggerData objectAtIndex:rowIndex];

		// Temporary save original name and statement (we need them later)
		editTriggerName = [trigger objectForKey:@"trigger"];
		editTriggerStatement = [trigger objectForKey:@"statement"];

		[triggerNameTextField setStringValue:editTriggerName];
		[triggerStatementTextView setString:editTriggerStatement];

		// Timin title is different then what we have saved in the database (case difference)
		for(int i=0;i<[[triggerActionTimePopUpButton itemArray] count]; i++)
		{
			if([[[triggerActionTimePopUpButton itemTitleAtIndex:i] uppercaseString]
				isEqualToString:[[trigger objectForKey:@"timing"] uppercaseString]])
			{
				[triggerActionTimePopUpButton selectItemAtIndex:i];
				break;
			}
		}

		// Event title is different then what we have saved in the database (case difference)
		for(int i=0;i<[[triggerEventPopUpButton itemArray] count]; i++)
		{
			if([[[triggerEventPopUpButton itemTitleAtIndex:i] uppercaseString]
				isEqualToString:[[trigger objectForKey:@"event"] uppercaseString]])
			{
				[triggerEventPopUpButton selectItemAtIndex:i];
				break;
			}
		}

		// Change button label from Add to Edit
		[confirmAddTriggerButton setTitle:NSLocalizedString(@"Edit", @"Edit trigger button")];
		isEdit = YES;

		[NSApp beginSheet:addTriggerPanel
		   modalForWindow:[tableDocumentInstance parentWindow]
			modalDelegate:self
		   didEndSelector:nil
			  contextInfo:nil];
	}

	return NO;
}

/**
 * Disable row selection while the document is working.
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
	return (![tableDocumentInstance isWorking]);
}

#pragma mark -
#pragma mark Task interaction

/**
 * Disable all content interactive elements during an ongoing task.
 */
- (void)startDocumentTaskForTab:(NSNotification *)notification
{
	// Only proceed if this view is selected.
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableTriggers]) return;

	[addTriggerButton setEnabled:NO];
	[refreshTriggersButton setEnabled:NO];
	[removeTriggerButton setEnabled:NO];
}

/**
 * Enable all content interactive elements after an ongoing task.
 */
- (void)endDocumentTaskForTab:(NSNotification *)notification
{
	// Only proceed if this view is selected.
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableTriggers]) return;

	if ([triggersTableView isEnabled]) {
		[addTriggerButton setEnabled:YES];
		[refreshTriggersButton setEnabled:YES];
	}

	[removeTriggerButton setEnabled:([triggersTableView numberOfSelectedRows] > 0)];
}

#pragma mark -
#pragma mark Other

/**
 * NSAlert didEnd method.
 */
- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	if ([contextInfo isEqualToString:@"removeTrigger"]) {

		if (returnCode == NSAlertDefaultReturn) {

			NSString *database = [tableDocumentInstance database];
			NSIndexSet *selectedSet = [triggersTableView selectedRowIndexes];

			NSUInteger row = [selectedSet lastIndex];

			while (row != NSNotFound)
			{
				NSString *triggerName = [[triggerData objectAtIndex:row] objectForKey:@"trigger"];
				NSString *query = [NSString stringWithFormat:@"DROP TRIGGER %@.%@", [database backtickQuotedString], [triggerName backtickQuotedString]];

				[connection queryString:query];

				if ([connection queryErrored]) {
					SPBeginAlertSheet(NSLocalizedString(@"Unable to delete trigger", @"error deleting trigger message"),
									  NSLocalizedString(@"OK", @"OK button"),
									  nil, nil, [NSApp mainWindow], nil, nil, nil,
									  [NSString stringWithFormat:NSLocalizedString(@"The selected trigger couldn't be deleted.\n\nMySQL said: %@", @"error deleting trigger informative message"), [connection getLastErrorMessage]]);

					// Abort loop
					break;
				}

				row = [selectedSet indexLessThanIndex:row];
			}

			[self _refreshTriggerDataForcingCacheRefresh:YES];
		}
	}
}

/**
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	// Display table veiew vertical gridlines preference changed
	if ([keyPath isEqualToString:SPDisplayTableViewVerticalGridlines]) {
        [triggersTableView setGridStyleMask:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	}
	// Use monospaced fonts preference changed
	else if ([keyPath isEqualToString:SPUseMonospacedFonts]) {

		BOOL useMonospacedFont = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];

		for (NSTableColumn *column in [triggersTableView tableColumns])
		{
			[[column dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}

		[triggersTableView reloadData];
	}
}

/**
 * Menu validation
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// Remove row
	if ([menuItem action] == @selector(removeTrigger:)) {
		[menuItem setTitle:([triggersTableView numberOfSelectedRows] > 1) ? NSLocalizedString(@"Delete Triggers", @"delete triggers menu item") : NSLocalizedString(@"Delete Trigger", @"delete trigger menu item")];

		return ([triggersTableView numberOfSelectedRows] > 0);
	}

	return YES;
}

/**
 * Toggles the enabled state of confirm add trigger button based on the editing of the trigger's name.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	[self _toggleConfirmAddTriggerButtonEnabled];
}

/**
 * Toggles the enabled state of confirm add trigger button based on the editing of the trigger's statement.
 */
- (void)triggerStatementTextDidChange:(NSNotification *)notification
{
	[self _toggleConfirmAddTriggerButtonEnabled];
}

/**
 * Returns an array of trigger data to be used for printing purposes. The first element in the array is always
 * an array of the columns and each subsequent element is an array of trigger data.
 */
- (NSArray *)triggerDataForPrinting
{
	NSMutableArray *headings = [[NSMutableArray alloc] init];
	NSMutableArray *data     = [NSMutableArray array];

	// Get the relations table view's columns
	for (NSTableColumn *column in [triggersTableView tableColumns])
	{
		[headings addObject:[[column headerCell] stringValue]];
	}

	// Get rid of the 'Table' column
	[headings removeObjectAtIndex:0];

	[data addObject:headings];

	[headings release];

	// Get the relation data
	for (NSDictionary *trigger in triggerData)
	{
		NSMutableArray *temp = [[NSMutableArray alloc] init];

		[temp addObject:[trigger objectForKey:@"trigger"]];
		[temp addObject:[trigger objectForKey:@"event"]];
		[temp addObject:[trigger objectForKey:@"timing"]];
		[temp addObject:[trigger objectForKey:@"statement"]];
		[temp addObject:[trigger objectForKey:@"definer"]];
		[temp addObject:([trigger objectForKey:@"created"]) ? [trigger objectForKey:@"created"] : @""];
		[temp addObject:[trigger objectForKey:@"sql_mode"]];

		[data addObject:temp];

		[temp release];
	}

	return data;
}

#pragma mark -

/**
 * Dealloc.
 */
- (void)dealloc
{
	[triggerData release], triggerData = nil;

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:SPUseMonospacedFonts];

	[super dealloc];
}

@end

@implementation SPTableTriggers (PrivateAPI)

/**
 * Enables or disables the confirm add trigger button based on the values of the trigger's name
 * and statement fields.
 */
- (void)_toggleConfirmAddTriggerButtonEnabled
{
	[confirmAddTriggerButton setEnabled:(([[triggerNameTextField stringValue] length] > 0) && ([[triggerStatementTextView string] length] > 0))];
}

/**
 * Refresh the displayed trigger, optionally forcing a refresh of the underlying cache.
 */
- (void)_refreshTriggerDataForcingCacheRefresh:(BOOL)clearAllCaches
{
	[triggerData removeAllObjects];

	if ([tablesListInstance tableType] == SPTableTypeTable) {

		if (clearAllCaches) {
			[tableDataInstance resetAllData];
			[tableDataInstance updateTriggersForCurrentTable];
		}

		NSArray *triggers = nil;
		if ([connection serverMajorVersion] >= 5 && [connection serverMinorVersion] >= 0)
			triggers = [tableDataInstance triggers];

		for (NSDictionary *trigger in triggers)
		{
			[triggerData addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									 [trigger objectForKey:@"Table"], @"table",
									 [trigger objectForKey:@"Trigger"], @"trigger",
									 [trigger objectForKey:@"Event"], @"event",
									 [trigger objectForKey:@"Timing"], @"timing",
									 [trigger objectForKey:@"Statement"], @"statement",
 									 [trigger objectForKey:@"Definer"], @"definer",
									 [trigger objectForKey:@"Created"], @"created",
									 [trigger objectForKey:@"sql_mode"], @"sql_mode",
									 nil]];

		}
	}

	[triggersTableView reloadData];
}

@end
