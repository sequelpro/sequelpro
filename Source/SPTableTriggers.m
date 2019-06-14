//
//  SPTableTriggers.m
//  sequel-pro
//
//  Created by Marius Ursache.
//  Copyright (c) 2010 Marius Ursache. All rights reserved.
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

#import "SPTableTriggers.h"
#import "SPDatabaseDocument.h"
#import "SPTablesList.h"
#import "SPTableData.h"
#import "SPTableView.h"
#import "SPAlertSheets.h"
#import "SPServerSupport.h"

#import <SPMySQL/SPMySQL.h>

// Constants
static const NSString *SPTriggerName       = @"TriggerName";
static const NSString *SPTriggerEvent      = @"TriggerEvent";
static const NSString *SPTriggerActionTime = @"TriggerActionTime";
static const NSString *SPTriggerStatement  = @"TriggerStatement";
static const NSString *SPTriggerDefiner    = @"TriggerDefiner";
static const NSString *SPTriggerCreated    = @"TriggerCreated";
static const NSString *SPTriggerSQLMode    = @"TriggerSQLMode";

typedef NS_ENUM(NSInteger, SPTriggerActionTimeTag) {
	SPTriggerActionTimeBeforeTag = 0,
	SPTriggerActionTimeAfterTag  = 1
};

typedef NS_ENUM(NSInteger, SPTriggerEventTag) {
	SPTriggerEventInsertTag = 0,
	SPTriggerEventUpdateTag = 1,
	SPTriggerEventDeleteTag = 2
};

static SPTriggerActionTimeTag TagForActionTime(NSString *mysql);
static SPTriggerEventTag TagForEvent(NSString *mysql);

@interface SPTableTriggers ()

- (void)_editTriggerAtIndex:(NSInteger)index;
- (void)_toggleConfirmAddTriggerButtonEnabled;
- (void)_refreshTriggerDataForcingCacheRefresh:(BOOL)clearAllCaches;
- (void)_openTriggerSheet;
- (void)_reopenTriggerSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)_addPreferenceObservers;
- (void)_removePreferenceObservers;

@end

@implementation SPTableTriggers

@synthesize connection;

#pragma mark -
#pragma mark Initialisation

- (id)init
{
	if ((self = [super init])) {
		triggerData = [[NSMutableArray alloc] init];
		editedTrigger = nil;
		isEdit = NO;
	}

	return self;
}

/**
 * Register to listen for table selection changes upon nib awakening.
 */
- (void)awakeFromNib
{
	prefs = [NSUserDefaults standardUserDefaults];

	// Set the table triggers view's vertical gridlines if required
	[triggersTableView setGridStyleMask:[prefs boolForKey:SPDisplayTableViewVerticalGridlines] ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];

	// Set the double-click action in blank areas of the table to create new rows
	[triggersTableView setEmptyDoubleClickAction:@selector(addTrigger:)];

	// Set the strutcture and index view's font
	BOOL useMonospacedFont = [prefs boolForKey:SPUseMonospacedFonts];

	CGFloat monospacedFontSize = [prefs floatForKey:SPMonospacedFontSize] > 0 ? [prefs floatForKey:SPMonospacedFontSize] : [NSFont smallSystemFontSize];

	[addTriggerPanel setInitialFirstResponder:triggerNameTextField];
	
	for (NSTableColumn *column in [triggersTableView tableColumns])
	{
		[[column dataCell] setFont:useMonospacedFont ? [NSFont fontWithName:SPDefaultMonospacedFontName size:monospacedFontSize] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}

	[self _addPreferenceObservers];

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
	if (isEdit && [(NSString *)[editedTrigger objectForKey:SPTriggerName] length] > 0)
	{
		NSString *queryDelete = [NSString stringWithFormat:@"DROP TRIGGER %@.%@",
								 [[tableDocumentInstance database] backtickQuotedString],
								 [[editedTrigger objectForKey:SPTriggerName] backtickQuotedString]];
		
		[connection queryString:queryDelete];
		
		if ([connection queryErrored]) {
			SPBeginAlertSheet(NSLocalizedString(@"Unable to delete trigger", @"error deleting trigger message"),
							  NSLocalizedString(@"OK", @"OK button"),
							  nil, nil, [NSApp mainWindow], self, @selector(_reopenTriggerSheet:returnCode:contextInfo:), NULL,
							  [NSString stringWithFormat:NSLocalizedString(@"The selected trigger couldn't be deleted.\n\nMySQL said: %@", @"error deleting trigger informative message"),
							   [connection lastErrorMessage]]);
			
			return;
		}
	}

	NSString *triggerName       = [triggerNameTextField stringValue];
	
	NSString *triggerActionTime = @"";
	switch ([triggerActionTimePopUpButton selectedTag])
	{
		case SPTriggerActionTimeBeforeTag:
			triggerActionTime = @"BEFORE";
			break;
			
		case SPTriggerActionTimeAfterTag:
			triggerActionTime = @"AFTER";
			break;
	}
	
	NSString *triggerEvent      = @"";
	switch ([triggerEventPopUpButton selectedTag])
	{
		case SPTriggerEventInsertTag:
			triggerEvent = @"INSERT";
			break;
		case SPTriggerEventUpdateTag:
			triggerEvent = @"UPDATE";
			break;
		case SPTriggerEventDeleteTag:
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
		NSString *createTriggerError = [connection lastErrorMessage];
		
		// In case of error, re-create the original trigger statement
		if (isEdit) {
			query = [NSString stringWithFormat:createTriggerStatementTemplate,
					 [[editedTrigger objectForKey:SPTriggerName] backtickQuotedString],
					 [editedTrigger objectForKey:SPTriggerActionTime],
					 [editedTrigger objectForKey:SPTriggerEvent],
					 [[tablesListInstance tableName] backtickQuotedString],
					 [editedTrigger objectForKey:SPTriggerStatement]];
		
			// If this attempt to re-create the trigger failed, then we're screwed as we've just lost the user's 
			// data, but they had a backup and everything's cool, right? Should we be displaying an error here
			// or will it interfere with the one above?
			[connection queryString:query];
		}

		SPBeginAlertSheet(NSLocalizedString(@"Error creating trigger", @"error creating trigger message"),
						  NSLocalizedString(@"OK", @"OK button"),
						  nil, nil, [NSApp mainWindow], self, @selector(_reopenTriggerSheet:returnCode:contextInfo:), NULL,
						  [NSString stringWithFormat:NSLocalizedString(@"The specified trigger was unable to be created.\n\nMySQL said: %@", @"error creating trigger informative message"),
						   createTriggerError]);
	}

	[self _refreshTriggerDataForcingCacheRefresh:YES];
}

/**
 * Displays the add new trigger sheet.
 */
- (IBAction)addTrigger:(id)sender
{
	// Check whether table editing is permitted (necessary as some actions - eg table double-click - bypass validation)
	if ([tableDocumentInstance isWorking] || [tablesListInstance tableType] != SPTableTypeTable) return;

	// Reset the interface name and statement
	[triggerNameTextField setStringValue:@""];
	[triggerStatementTextView setString:@""];
	isEdit = NO;
	[confirmAddTriggerButton setTitle:NSLocalizedString(@"Add", @"Add trigger button label")];

	[self _openTriggerSheet];
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
		[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
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
	id value = [[triggerData objectAtIndex:rowIndex] objectForKey:[tableColumn identifier]];

	if ([value isNSNull]) {
		return [prefs objectForKey:SPNullValue];
	}

	return value;
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

			[selectedSet enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger row, BOOL * _Nonnull stop) {
				NSString *triggerName = [[triggerData objectAtIndex:row] objectForKey:SPTriggerName];
				NSString *query = [NSString stringWithFormat:@"DROP TRIGGER %@.%@", [database backtickQuotedString], [triggerName backtickQuotedString]];

				[connection queryString:query];

				if ([connection queryErrored]) {
					[[alert window] orderOut:self];
					SPOnewayAlertSheet(
						NSLocalizedString(@"Unable to delete trigger", @"error deleting trigger message"),
						[tableDocumentInstance parentWindow],
						[NSString stringWithFormat:NSLocalizedString(@"The selected trigger couldn't be deleted.\n\nMySQL said: %@", @"error deleting trigger informative message"), [connection lastErrorMessage]]
					);
					// Abort loop
					*stop = YES;
				}
			}];

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
		CGFloat monospacedFontSize = [prefs floatForKey:SPMonospacedFontSize] > 0 ? [prefs floatForKey:SPMonospacedFontSize] : [NSFont smallSystemFontSize];

		for (NSTableColumn *column in [triggersTableView tableColumns])
		{
			[[column dataCell] setFont:useMonospacedFont ? [NSFont fontWithName:SPDefaultMonospacedFontName size:monospacedFontSize] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
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
#pragma mark Private API

/**
 * Presents the edit sheet for the trigger at the supplied index.
 *
 * @param index The index of the trigger to edit
 */
- (void)_editTriggerAtIndex:(NSInteger)index
{
	NSDictionary *trigger = [triggerData objectAtIndex:index];
	
	// Cache the original trigger in the event that the editing process fails and we need to recreate it.
	if (editedTrigger) [editedTrigger release];
	editedTrigger = [trigger copy];
	
	[triggerNameTextField setStringValue:[trigger objectForKey:SPTriggerName]];
	[triggerStatementTextView setString:[trigger objectForKey:SPTriggerStatement]];
	
	[triggerActionTimePopUpButton selectItemWithTag:TagForActionTime([trigger objectForKey:SPTriggerActionTime])];
	
	[triggerEventPopUpButton selectItemWithTag:TagForEvent([trigger objectForKey:SPTriggerEvent])];
	
	// Change button label from Add to Edit
	[confirmAddTriggerButton setTitle:NSLocalizedString(@"Save", @"Save trigger button label")];
	
	isEdit = YES;
	
	[self _openTriggerSheet];
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
		NSCharacterSet *nulSet = [NSCharacterSet characterSetWithCharactersInString:[NSString stringWithFormat:@"%C", (unsigned short)'\0']];
		
		for (NSDictionary *trigger in triggers)
		{

			// Trim nul bytes off the Statement, as some versions of MySQL can add these, preventing easy editing
			NSString *statementString = [[trigger objectForKey:@"Statement"] stringByTrimmingCharactersInSet:nulSet];

			// Copy across all the trigger data needed, trimming nul bytes off the Statement
			[triggerData addObject:[NSDictionary dictionaryWithObjectsAndKeys:
									[trigger objectForKey:@"Trigger"],   SPTriggerName,
									[trigger objectForKey:@"Event"],     SPTriggerEvent,
									[trigger objectForKey:@"Timing"],    SPTriggerActionTime,
									statementString,                     SPTriggerStatement,
									[trigger objectForKey:@"Definer"],   SPTriggerDefiner,
									[trigger objectForKey:@"Created"],   SPTriggerCreated,
									[trigger objectForKey:@"sql_mode"],  SPTriggerSQLMode,
									nil]];
			
		}
	}
	
	[triggersTableView reloadData];
}

/**
 * Open the add or edit trigger sheet.
 */
- (void)_openTriggerSheet
{
	[NSApp beginSheet:addTriggerPanel
	   modalForWindow:[tableDocumentInstance parentWindow]
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
}

/**
 * Reopen the add trigger sheet, usually after an error message, with the previous content.
 */
- (void)_reopenTriggerSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[self performSelector:@selector(_openTriggerSheet) withObject:nil afterDelay:0.0];
}

/**
 * Add any necessary preference observers to allow live updating on changes.
 */
- (void)_addPreferenceObservers
{
	// Register as an observer for the when the UseMonospacedFonts preference changes
	[prefs addObserver:self forKeyPath:SPUseMonospacedFonts options:NSKeyValueObservingOptionNew context:NULL];

	// Register observers for when the DisplayTableViewVerticalGridlines preference changes
	[prefs addObserver:self forKeyPath:SPDisplayTableViewVerticalGridlines options:NSKeyValueObservingOptionNew context:NULL];
}

/**
 * Remove any previously added preference observers.
 */
- (void)_removePreferenceObservers
{
	[prefs removeObserver:self forKeyPath:SPUseMonospacedFonts];
	[prefs removeObserver:self forKeyPath:SPDisplayTableViewVerticalGridlines];
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
 * Alter the colour of cells displaying NULL values
 */
- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if (![cell respondsToSelector:@selector(setTextColor:)]) {
		return;
	}

	id value = [[triggerData objectAtIndex:rowIndex] objectForKey:[tableColumn identifier]];

	[cell setTextColor:[value isNSNull] ? [NSColor lightGrayColor] : [NSColor controlTextColor]];
}

/**
 * Double-click action on table cells - for the time being, return NO to disable editing.
 */
- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if ([tableDocumentInstance isWorking]) return NO;

	// Start Edit panel
	if (((NSInteger)[triggerData count] > rowIndex) && [triggerData objectAtIndex:rowIndex]) {
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
#pragma mark Textfield delegate methods

/**
 * Toggles the enabled state of confirm add trigger button based on the editing of the trigger's name.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	[self _toggleConfirmAddTriggerButtonEnabled];
}

#pragma mark -

- (void)dealloc
{
	SPClear(triggerData);
	SPClear(editedTrigger);

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[self _removePreferenceObservers];

	[super dealloc];
}

@end

#pragma mark -

SPTriggerActionTimeTag TagForActionTime(NSString *mysql)
{
	NSString *uc = [mysql uppercaseString];
	if([uc isEqualToString:@"BEFORE"]) return SPTriggerActionTimeBeforeTag;
	if([uc isEqualToString:@"AFTER"])  return SPTriggerActionTimeAfterTag;
	SPLog(@"Unknown trigger action time: %@",uc);
	return -1;
}

SPTriggerEventTag TagForEvent(NSString *mysql)
{
	NSString *uc = [mysql uppercaseString];
	if([uc isEqualToString:@"INSERT"]) return SPTriggerEventInsertTag;
	if([uc isEqualToString:@"UPDATE"]) return SPTriggerEventUpdateTag;
	if([uc isEqualToString:@"DELETE"]) return SPTriggerEventDeleteTag;
	SPLog(@"Unknown trigger event: %@",uc);
	return -1;
}
