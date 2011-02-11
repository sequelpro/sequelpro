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
#import "SPAlertSheets.h"
#import "SPServerSupport.h"

// Constants
static const NSString *SPTriggerName       = @"TriggerName";
static const NSString *SPTriggerTableName  = @"TriggerTableName";
static const NSString *SPTriggerEvent      = @"TriggerEvent";
static const NSString *SPTriggerActionTime = @"TriggerActionTime";
static const NSString *SPTriggerStatement  = @"TriggerStatement";
static const NSString *SPTriggerDefiner    = @"TriggerDefiner";
static const NSString *SPTriggerCreated    = @"TriggerCreated";
static const NSString *SPTriggerSQLMode    = @"TriggerSQLMode";

@interface SPTableTriggers (PrivateAPI)

- (void)_editTriggerAtIndex:(NSInteger)index;
- (void)_toggleConfirmAddTriggerButtonEnabled;
- (void)_refreshTriggerDataForcingCacheRefresh:(BOOL)clearAllCaches;

@end

@implementation SPTableTriggers

@synthesize connection;

#pragma mark -
#pragma mark Initialization

/**
 * Init
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

	[self resetInterface];

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

/**
 * Reset the trigger interface, as for no selected table.
 */
- (void)resetInterface
{
	[triggerData removeAllObjects];
	[triggersTableView noteNumberOfRowsChanged];

	// Disable all interface elements by default
	[addTriggerButton setEnabled:NO];
	[refreshTriggersButton setEnabled:NO];
	[triggersTableView setEnabled:NO];
	[labelTextField setStringValue:@""];

	// Show a warning if the version of MySQL is too low to support triggers
	if (![[tableDocumentInstance serverSupport] supportsTriggers]) {
		[labelTextField setStringValue:NSLocalizedString(@"This version of MySQL does not support triggers. Support for triggers was added in MySQL 5.0.2", @"triggers not supported label")];
	}
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
	
	NSString *createTriggerStatementTemplate = @"CREATE TRIGGER %@ %@ %@ ON %@ FOR EACH ROW %@";

	// MySQL doesn't have ALTER TRIGGER, so we delete the old one and add a new one.
	// In case of error, all the old trigger info is kept in buffer
	if (isEdit && [editTriggerName length] > 0)
	{
		NSString *queryDelete = [NSString stringWithFormat:@"DROP TRIGGER %@.%@",
								 [[tableDocumentInstance database] backtickQuotedString],
								 [editTriggerName backtickQuotedString]];
		
		[connection queryString:queryDelete];
		
		if ([connection queryErrored]) {
			SPBeginAlertSheet(NSLocalizedString(@"Unable to delete trigger", @"error deleting trigger message"),
							  NSLocalizedString(@"OK", @"OK button"),
							  nil, nil, [NSApp mainWindow], nil, nil, nil,
							  [NSString stringWithFormat:NSLocalizedString(@"The selected trigger couldn't be deleted.\n\nMySQL said: %@", @"error deleting trigger informative message"),
							   [connection getLastErrorMessage]]);
			
			return;
		}
	}

	NSString *triggerName       = [triggerNameTextField stringValue];
	NSString *triggerActionTime = ([triggerActionTimePopUpButton indexOfSelectedItem]) ? @"AFTER" : @"BEFORE";
	NSString *triggerEvent      = @"";
	
	switch ([triggerEventPopUpButton indexOfSelectedItem]) 
	{
		case 0:
			triggerEvent = @"INSERT";
			break;
		case 1:
			triggerEvent = @"UPDATE";
			break;
		case 2:
			triggerEvent = @"DELETE";
			break;
	}
	
	NSString *triggerStatement  = [triggerStatementTextView string];

	NSString *query = [NSString stringWithFormat:createTriggerStatementTemplate,
					   [triggerName backtickQuotedString],
					   triggerActionTime,
					   triggerEvent,
					   [[tablesListInstance tableName] backtickQuotedString],
					   triggerStatement];

	// Execute query
	[connection queryString:query];

	if (([connection queryErrored])) {
		SPBeginAlertSheet(NSLocalizedString(@"Error creating trigger", @"error creating trigger message"),
						  NSLocalizedString(@"OK", @"OK button"),
						  nil, nil, [NSApp mainWindow], nil, nil, nil,
						  [NSString stringWithFormat:NSLocalizedString(@"The specified trigger was unable to be created.\n\nMySQL said: %@", @"error creating trigger informative message"),
						   [connection getLastErrorMessage]]);
		
		// In case of error, re-create the original trigger statement
		if (isEdit) {
			[triggerStatementTextView setString:editTriggerStatement];
			
			NSString *query = [NSString stringWithFormat:createTriggerStatementTemplate,
							   [editTriggerName backtickQuotedString],
							   editTriggerActionTime,
							   editTriggerEvent,
							   [editTriggerTableName backtickQuotedString],
							   editTriggerStatement];
		
			// If this attempt to re-create the trigger failed, then we're screwed as we've just lost the user's 
			// data, but they had a backup and everything's cool, right? Should we be displaying an error here
			// or will it interfere with the one above?
			[connection queryString:query];
		}
	}
	else {
		[triggerNameTextField setStringValue:@""];
		[triggerStatementTextView setString:@""];
	}

	// After Edit, rename button to Add
	if (isEdit) {
		isEdit = NO;
		[confirmAddTriggerButton setTitle:NSLocalizedString(@"Add", @"Add trigger button label")];
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
 * Edits the selected trigger.
 */
- (IBAction)editTrigger:(id)sender
{
	[self _editTriggerAtIndex:[triggersTableView selectedRow]];
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
- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if ([tableDocumentInstance isWorking]) return NO;

	// Start Edit panel
	if (([triggerData count] > rowIndex) && ([triggerData objectAtIndex:rowIndex] != NSNotFound)) {
		[self _editTriggerAtIndex:rowIndex];
	}

	return NO;
}

/**
 * Disable row selection while the document is working.
 */
- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)rowIndex
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
	SEL action = [menuItem action];
	
	// Remove row
	if (action == @selector(removeTrigger:)) {
		[menuItem setTitle:([triggersTableView numberOfSelectedRows] > 1) ? NSLocalizedString(@"Delete Triggers", @"delete triggers menu item") : NSLocalizedString(@"Delete Trigger", @"delete trigger menu item")];

		return ([triggersTableView numberOfSelectedRows] > 0);
	}
	else if (action == @selector(editTrigger:)) {
		return ([triggersTableView numberOfSelectedRows] == 1);
	}

	return YES;
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

		[temp addObject:[trigger objectForKey:SPTriggerName]];
		[temp addObject:[trigger objectForKey:SPTriggerEvent]];
		[temp addObject:[trigger objectForKey:SPTriggerActionTime]];
		[temp addObject:[trigger objectForKey:SPTriggerStatement]];
		[temp addObject:[trigger objectForKey:SPTriggerDefiner]];
		[temp addObject:([trigger objectForKey:SPTriggerCreated]) ? [trigger objectForKey:SPTriggerCreated] : @""];
		[temp addObject:[trigger objectForKey:SPTriggerSQLMode]];

		[data addObject:temp];

		[temp release];
	}

	return data;
}

#pragma mark -
#pragma mark Textfield delegate methods

/**
 * Toggles the enabled state of confirm add trigger button based on the editing of the trigger's name.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	[self _toggleConfirmAddTriggerButtonEnabled];
}

#pragma mark -
#pragma mark Private API

/**
 * Presents the edit sheet for the trigger at the supplied index.
 *
 * @param index The index of the trigger to edit
 */
- (void)_editTriggerAtIndex:(NSInteger)index
{
	NSDictionary *trigger = [triggerData objectAtIndex:index];
	
	// Cache the original trigger's name and statement in the event that the editing process fails and
	// we need to recreate it.
	editTriggerName       = [trigger objectForKey:SPTriggerName];
	editTriggerStatement  = [trigger objectForKey:SPTriggerStatement];
	editTriggerTableName  = [trigger objectForKey:SPTriggerTableName];
	editTriggerEvent      = [trigger objectForKey:SPTriggerEvent];
	editTriggerActionTime = [trigger objectForKey:SPTriggerActionTime];
	
	[triggerNameTextField setStringValue:editTriggerName];
	[triggerStatementTextView setString:editTriggerStatement];
	
	// Timin title is different then what we have saved in the database (case difference)
	for (NSUInteger i = 0; i < [[triggerActionTimePopUpButton itemArray] count]; i++)
	{
		if ([[[triggerActionTimePopUpButton itemTitleAtIndex:i] uppercaseString] isEqualToString:[[trigger objectForKey:@"timing"] uppercaseString]]) {
			[triggerActionTimePopUpButton selectItemAtIndex:i];
			break;
		}
	}
	
	// Event title is different then what we have saved in the database (case difference)
	for (NSUInteger i = 0; i < [[triggerEventPopUpButton itemArray] count]; i++)
	{
		if ([[[triggerEventPopUpButton itemTitleAtIndex:i] uppercaseString] isEqualToString:[[trigger objectForKey:@"event"] uppercaseString]]) {
			[triggerEventPopUpButton selectItemAtIndex:i];
			break;
		}
	}
	
	// Change button label from Add to Edit
	[confirmAddTriggerButton setTitle:NSLocalizedString(@"Save", @"Save trigger button label")];
	
	isEdit = YES;
	
	[NSApp beginSheet:addTriggerPanel
	   modalForWindow:[tableDocumentInstance parentWindow]
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
}

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
 *
 * @param classAllCaches Indicates whether all the caches should be refreshed
 */
- (void)_refreshTriggerDataForcingCacheRefresh:(BOOL)clearAllCaches
{
	[triggerData removeAllObjects];
	
	if ([tablesListInstance tableType] == SPTableTypeTable) {
		
		if (clearAllCaches) {
			[tableDataInstance resetAllData];
			[tableDataInstance updateTriggersForCurrentTable];
		}
		
		NSArray *triggers = ([[tableDocumentInstance serverSupport] supportsTriggers]) ? [tableDataInstance triggers] : nil;
		
		for (NSDictionary *trigger in triggers)
		{
			[triggerData addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[trigger objectForKey:@"Table"],     SPTriggerTableName,
									[trigger objectForKey:@"Trigger"],   SPTriggerName,
									[trigger objectForKey:@"Event"],     SPTriggerEvent,
									[trigger objectForKey:@"Timing"],    SPTriggerActionTime,
									[trigger objectForKey:@"Statement"], SPTriggerStatement,
									[trigger objectForKey:@"Definer"],   SPTriggerDefiner,
									[trigger objectForKey:@"Created"],   SPTriggerCreated,
									[trigger objectForKey:@"sql_mode"],  SPTriggerSQLMode,
									nil]];
			
		}
	}
	
	[triggersTableView reloadData];
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
