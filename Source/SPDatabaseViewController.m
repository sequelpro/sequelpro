//
//  SPDatabaseViewController.m
//  sequel-pro
//
//  Created by Rowan Beentje on October 31, 2010.
//  Copyright (c) 2010 Arboreal. All rights reserved.
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

#ifndef SP_CODA /* headers */
#import "SPAppController.h"
#import "SPBundleHTMLOutputController.h"
#endif
#import "SPCopyTable.h"
#import "SPDatabaseViewController.h"
#import "SPHistoryController.h"
#import "SPTableContent.h"
#import "SPTableData.h"
#import "SPTablesList.h"
#import "SPTableTriggers.h"
#import "SPThreadAdditions.h"
#import "SPTableRelations.h"
#ifdef SP_CODA /* headers */
#import "SPTableStructure.h"
#import "SPTableStructureLoading.h"
#endif

#import <SPMySQL/SPMySQL.h>

@interface SPDatabaseDocument (SPDatabaseViewControllerPrivateAPI)

- (void)_loadTabTask:(NSTabViewItem *)tabViewItem;
- (void)_loadTableTask;

@end

@implementation SPDatabaseDocument (SPDatabaseViewController)

#pragma mark -
#pragma mark Getters

#ifndef SP_CODA /* getters */
/**
 * Returns the master database view, containing the tables list and views for
 * table setup and contents.
 */
- (NSView *)databaseView
{
	return parentView;
}
#endif

/**
 * Returns the name of the currently selected table/view/procedure/function.
 */
- (NSString *)table
{
	return selectedTableName;
}

/**
 * Returns the currently selected table type, or -1 if no table or multiple tables are selected
 */
- (SPTableType)tableType
{
	return selectedTableType;
}

/**
 * Returns YES if table source has already been loaded
 */
- (BOOL)structureLoaded
{
	return structureLoaded;
}

/**
 * Returns YES if table content has already been loaded
 */
- (BOOL)contentLoaded
{
	return contentLoaded;
}

/**
 * Returns YES if table status has already been loaded
 */
- (BOOL)statusLoaded
{
	return statusLoaded;
}

#ifndef SP_CODA /* toolbar ibactions */

#pragma mark -
#pragma mark Tab view control and delegate methods

//WARNING: Might be called from code in background threads
- (IBAction)viewStructure:(id)sender
{
	// Cancel the selection if currently editing a view and unable to save
	if (![self couldCommitCurrentViewActions]) {
		[[mainToolbar onMainThread] setSelectedItemIdentifier:*SPViewModeToMainToolbarMap[[prefs integerForKey:SPLastViewMode]]];
		return;
	}

	[[tableTabView onMainThread] selectTabViewItemAtIndex:0];
	[[mainToolbar onMainThread] setSelectedItemIdentifier:SPMainToolbarTableStructure];
	[spHistoryControllerInstance updateHistoryEntries];
	
	[prefs setInteger:SPStructureViewMode forKey:SPLastViewMode];
}

- (IBAction)viewContent:(id)sender
{
	// Cancel the selection if currently editing a view and unable to save
	if (![self couldCommitCurrentViewActions]) {
		[mainToolbar setSelectedItemIdentifier:*SPViewModeToMainToolbarMap[[prefs integerForKey:SPLastViewMode]]];
		return;
	}

	[tableTabView selectTabViewItemAtIndex:1];
	[mainToolbar setSelectedItemIdentifier:SPMainToolbarTableContent];
	[spHistoryControllerInstance updateHistoryEntries];
	
	[prefs setInteger:SPContentViewMode forKey:SPLastViewMode];
}

- (IBAction)viewQuery:(id)sender
{
	// Cancel the selection if currently editing a view and unable to save
	if (![self couldCommitCurrentViewActions]) {
		[mainToolbar setSelectedItemIdentifier:*SPViewModeToMainToolbarMap[[prefs integerForKey:SPLastViewMode]]];
		return;
	}

	[tableTabView selectTabViewItemAtIndex:2];
	[mainToolbar setSelectedItemIdentifier:SPMainToolbarCustomQuery];
	[spHistoryControllerInstance updateHistoryEntries];

	// Set the focus on the text field
	[parentWindow makeFirstResponder:customQueryTextView];
	
	[prefs setInteger:SPQueryEditorViewMode forKey:SPLastViewMode];
}

- (void) viewCustomQuery:(id)sender withString:(NSString*)query {
	[self viewQuery:sender];
	[customQueryInstance doPerformLoadQueryService:query];
	[NSTimer scheduledTimerWithTimeInterval:0.1 target:[NSBlockOperation blockOperationWithBlock:^{
		[customQueryInstance doPerformQueryService:query];
	}] selector:@selector(main) userInfo:nil repeats:NO];
}

- (IBAction)viewStatus:(id)sender
{
	// Cancel the selection if currently editing a view and unable to save
	if (![self couldCommitCurrentViewActions]) {
		[mainToolbar setSelectedItemIdentifier:*SPViewModeToMainToolbarMap[[prefs integerForKey:SPLastViewMode]]];
		return;
	}

	[tableTabView selectTabViewItemAtIndex:3];
	[mainToolbar setSelectedItemIdentifier:SPMainToolbarTableInfo];
	[spHistoryControllerInstance updateHistoryEntries];

	if ([[self table] length]) {
		[extendedTableInfoInstance loadTable:[self table]];
	}
	
	[parentWindow makeFirstResponder:[extendedTableInfoInstance valueForKeyPath:@"tableCreateSyntaxTextView"]];

	[prefs setInteger:SPTableInfoViewMode forKey:SPLastViewMode];
}

- (IBAction)viewRelations:(id)sender
{
	// Cancel the selection if currently editing a view and unable to save
	if (![self couldCommitCurrentViewActions]) {
		[mainToolbar setSelectedItemIdentifier:*SPViewModeToMainToolbarMap[[prefs integerForKey:SPLastViewMode]]];
		return;
	}

	[tableTabView selectTabViewItemAtIndex:4];
	[mainToolbar setSelectedItemIdentifier:SPMainToolbarTableRelations];
	[spHistoryControllerInstance updateHistoryEntries];
	
	[prefs setInteger:SPRelationsViewMode forKey:SPLastViewMode];
}

- (IBAction)viewTriggers:(id)sender
{
	// Cancel the selection if currently editing a view and unable to save
	if (![self couldCommitCurrentViewActions]) {
		[mainToolbar setSelectedItemIdentifier:*SPViewModeToMainToolbarMap[[prefs integerForKey:SPLastViewMode]]];
		return;
	}	
	
	[tableTabView selectTabViewItemAtIndex:5];
	[mainToolbar setSelectedItemIdentifier:SPMainToolbarTableTriggers];
	[spHistoryControllerInstance updateHistoryEntries];
	
	[prefs setInteger:SPTriggersViewMode forKey:SPLastViewMode];
}
#endif

/**
 * Mark the structure tab for refresh when it's next switched to,
 * or reload the view if it's currently active
 */
- (void)setStructureRequiresReload:(BOOL)reload
{
	BOOL reloadRequired = reload;

#ifndef SP_CODA
	if ([tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == SPTableViewStructure) {
		reloadRequired = NO;
	}
#endif

	if (reloadRequired && selectedTableName) {
		[tableSourceInstance loadTable:selectedTableName];
	} 
	else {
		structureLoaded = !reload;
	}
}

/**
 * Mark the content tab for refresh when it's next switched to,
 * or reload the view if it's currently active
 */
- (void)setContentRequiresReload:(BOOL)reload
{
	if (reload && selectedTableName
#ifndef SP_CODA /* check which tab is selected */
	 && [tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == SPTableViewContent
#endif
	 ) {
		[tableContentInstance loadTable:selectedTableName];
	} 
	else {
		contentLoaded = !reload;
	}
}

/**
 * Mark the extended tab info for refresh when it's next switched to,
 * or reload the view if it's currently active
 */
- (void)setStatusRequiresReload:(BOOL)reload
{
	if (reload && selectedTableName 
#ifndef SP_CODA /* check which tab is selected */
		&& [tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == SPTableViewStatus
#endif
		) {
		[[extendedTableInfoInstance onMainThread] loadTable:selectedTableName];
	} 
	else {
		statusLoaded = !reload;
	}
}

/**
 * Mark the relations tab for refresh when it's next switched to,
 * or reload the view if it's currently active
 */
- (void)setRelationsRequiresReload:(BOOL)reload
{
	if (reload && selectedTableName 
#ifndef SP_CODA /* check which tab is selected */
		&& [tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == SPTableViewRelations
#endif
		) {
		[[tableRelationsInstance onMainThread] refreshRelations:self];
	} 
	else {
		relationsLoaded = !reload;
	}
}

#ifndef SP_CODA /* !!! respond to tab change */
/**
 * Triggers a task to update the newly selected tab view, ensuring
 * the data is fully loaded and up-to-date.
 */
- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	[self startTaskWithDescription:[NSString stringWithFormat:NSLocalizedString(@"Loading %@...", @"Loading table task string"), [self table]]];
	
	if ([NSThread isMainThread]) {
		[NSThread detachNewThreadWithName:SPCtxt(@"SPDatabaseViewController view load task",self)
								   target:self 
								 selector:@selector(_loadTabTask:) 
								   object:tabViewItem];
	} 
	else {
		[self _loadTabTask:tabViewItem];
	}
}
#endif

#pragma mark -
#pragma mark Table control

/**
 * Loads a specified table into the database view, and ensures it's selected in
 * the tables list.  Passing a table name of nil will deselect any currently selected
 * table, but will leave multiple selections intact.
 * If this method is supplied with the currently selected name, a reload rather than
 * a load will be triggered.
 */
- (void)loadTable:(NSString *)aTable ofType:(SPTableType)aTableType
{
	// Ensure a connection is still present
	if (![mySQLConnection isConnected]) return;

	// If the supplied table name was nil, clear the views.
	if (!aTable) {
		
		// Update the selected table name and type
		if (selectedTableName) SPClear(selectedTableName);
		
		selectedTableType = SPTableTypeNone;

		// Clear the views
		[[tablesListInstance onMainThread] setSelectionState:nil];
		[tableSourceInstance loadTable:nil];
		[tableContentInstance loadTable:nil];
#ifndef SP_CODA /* [extendedTableInfoInstance loadTable:] */
		[[extendedTableInfoInstance onMainThread] loadTable:nil];
		[[tableTriggersInstance onMainThread] resetInterface];
		[[tableRelationsInstance onMainThread] refreshRelations:self];
#endif
		structureLoaded = NO;
		contentLoaded = NO;
		statusLoaded = NO;
		triggersLoaded = NO;
		relationsLoaded = NO;

#ifndef SP_CODA
		// Update the window title
		[self updateWindowTitle:self];

		// Add a history entry
		[spHistoryControllerInstance updateHistoryEntries];
#endif

		// Notify listeners of the table change
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:SPTableChangedNotification object:self];

		return;
	}

	BOOL isReloading = (selectedTableName && [selectedTableName isEqualToString:aTable]);

	// Store the new name
	if (selectedTableName) [selectedTableName release];
	
	selectedTableName = [[NSString alloc] initWithString:aTable];
	selectedTableType = aTableType;

	// Start a task
	if (isReloading) {
		[self startTaskWithDescription:NSLocalizedString(@"Reloading...", @"Reloading table task string")];
	} 
	else {
		[self startTaskWithDescription:[NSString stringWithFormat:NSLocalizedString(@"Loading %@...", @"Loading table task string"), aTable]];	
	}

	// Update the tables list interface - also updates menus to reflect the selected table type
	[[tablesListInstance onMainThread] setSelectionState:[NSDictionary dictionaryWithObjectsAndKeys:aTable, @"name", [NSNumber numberWithInteger:aTableType], @"type", nil]];

	// If on the main thread, fire up a thread to deal with view changes and data loading;
	// if already on a background thread, make the changes on the existing thread.
	if ([NSThread isMainThread]) {
		[NSThread detachNewThreadWithName:SPCtxt(@"SPDatabaseViewController table load task",self)
								   target:self 
								 selector:@selector(_loadTableTask) 
								   object:nil];
	} 
	else {
		[self _loadTableTask];
	}
}
 
@end

#pragma mark -

@implementation SPDatabaseDocument (SPDatabaseViewControllerPrivateAPI)

/**
 * In a threaded task, ensure that the supplied tab is loaded -
 * usually as a result of switching to it.
 */
- (void)_loadTabTask:(NSTabViewItem *)tabViewItem
{
	NSAutoreleasePool *tabLoadPool = [[NSAutoreleasePool alloc] init];

	// If anything other than a single table or view is selected, don't proceed.
	if (![self table] || ([tablesListInstance tableType] != SPTableTypeTable && [tablesListInstance tableType] != SPTableTypeView))
	{
		[self endTask];
		[tabLoadPool drain];
		return;
	}

	// Get the tab view index and ensure the associated view is loaded
	NSInteger selectedTabViewIndex = [[tabViewItem tabView] indexOfTabViewItem:tabViewItem];

	switch (selectedTabViewIndex) {
		case SPTableViewStructure:
			if (!structureLoaded) {
				[tableSourceInstance loadTable:selectedTableName];
				structureLoaded = YES;
			}
			break;
		case SPTableViewContent:
			if (!contentLoaded) {
				[tableContentInstance loadTable:selectedTableName];
				contentLoaded = YES;
			}
			break;
#ifndef SP_CODA /* case SPTableViewStatus: case SPTableViewTriggers: */
		case SPTableViewStatus:
			if (!statusLoaded) {
				[[extendedTableInfoInstance onMainThread] loadTable:selectedTableName];
				statusLoaded = YES;
			}
			break;
		case SPTableViewTriggers:
			if (!triggersLoaded) {
				[[tableTriggersInstance onMainThread] loadTriggers];
				triggersLoaded = YES;
			}
			break;
		case SPTableViewRelations:
			if (!relationsLoaded) {
				[[tableRelationsInstance onMainThread] refreshRelations:self];
				 relationsLoaded = YES;
			}
			break;
#endif
	}

	[self endTask];
	
	[tabLoadPool drain];
}


/**
 * In a threaded task, load the currently selected table/view/proc/function.
 */
- (void)_loadTableTask
{
	NSAutoreleasePool *loadPool = [[NSAutoreleasePool alloc] init];
	NSString *tableEncoding = nil;

#ifndef SP_CODA /* Update the window title */
	// Update the window title
	[self updateWindowTitle:self];
#endif

	// Reset table information caches and mark that all loaded views require their data reloading
	[tableDataInstance resetAllData];
	
	structureLoaded = NO;
	contentLoaded = NO;
	statusLoaded = NO;
	triggersLoaded = NO;
	relationsLoaded = NO;
	
	// Ensure status and details are fetched using UTF8
	NSString *previousEncoding = [mySQLConnection encoding];
	BOOL changeEncoding = ![previousEncoding isEqualToString:@"utf8"];
	
	if (changeEncoding) {
		[mySQLConnection storeEncodingForRestoration];
		[mySQLConnection setEncoding:@"utf8"];
	}

	// Cache status information on the working thread
	[tableDataInstance updateStatusInformationForCurrentTable];

	// Check the current encoding against the table encoding to see whether
	// an encoding change and reset is required.  This also caches table information on
	// the working thread.
	if( selectedTableType == SPTableTypeView || selectedTableType == SPTableTypeTable) {

		// tableEncoding == nil indicates that there was an error while retrieving table data
		tableEncoding = [tableDataInstance tableEncoding];

		// If encoding is set to Autodetect, update the connection character set encoding
		// based on the newly selected table's encoding - but only if it differs from the current encoding.
		if ([[[NSUserDefaults standardUserDefaults] objectForKey:SPDefaultEncoding] intValue] == SPEncodingAutodetect) {
			if (tableEncoding != nil && ![tableEncoding isEqualToString:previousEncoding]) {
				[self setConnectionEncoding:tableEncoding reloadingViews:NO];
				changeEncoding = NO;
			}
		}
	}

	if (changeEncoding) [mySQLConnection restoreStoredEncoding];

	// Notify listeners of the table change now that the state is fully set up.
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:SPTableChangedNotification object:self];

#ifndef SP_CODA /* [spHistoryControllerInstance restoreViewStates] */

	// Restore view states as appropriate
	[spHistoryControllerInstance restoreViewStates];
#endif

	// Load the currently selected view if looking at a table or view
	if (tableEncoding && (selectedTableType == SPTableTypeView || selectedTableType == SPTableTypeTable))
	{
#ifndef SP_CODA /* load everything */
		NSInteger selectedTabViewIndex = [tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]];

		switch (selectedTabViewIndex) {
			case SPTableViewStructure:
#endif
				[tableSourceInstance loadTable:selectedTableName];
				structureLoaded = YES;
#ifndef SP_CODA /* load everything */
				break;
			case SPTableViewContent:
#endif
				[tableContentInstance loadTable:selectedTableName];
				contentLoaded = YES;
#ifndef SP_CODA /* load everything */
				break;
			case SPTableViewStatus:
				[[extendedTableInfoInstance onMainThread] loadTable:selectedTableName];
				statusLoaded = YES;
				break;
			case SPTableViewTriggers:
				[[tableTriggersInstance onMainThread] loadTriggers];
				triggersLoaded = YES;
				break;
			case SPTableViewRelations:
				[[tableRelationsInstance onMainThread] refreshRelations:self];
				relationsLoaded = YES;
				break;
		}
#endif
	}

	// Clear any views which haven't been loaded as they weren't visible.  Note
	// that this should be done after reloading visible views, instead of clearing all
	// views, to reduce UI operations and avoid resetting state unnecessarily.
	// Some views (eg TableRelations) make use of the SPTableChangedNotification and
	// so don't require manual clearing.
	if (!structureLoaded) [tableSourceInstance loadTable:nil];
	if (!contentLoaded) [tableContentInstance loadTable:nil];
	if (!statusLoaded) [[extendedTableInfoInstance onMainThread] loadTable:nil];
	if (!triggersLoaded) [[tableTriggersInstance onMainThread] resetInterface];

	// If the table row counts an inaccurate and require updating, trigger an update - no
	// action will be performed if not necessary
	[tableDataInstance updateAccurateNumberOfRowsForCurrentTableForcingUpdate:NO];

#ifndef SP_CODA /* show Create Table syntax */
	// Update the "Show Create Syntax" window if it's already opened
	// according to the selected table/view/proc/func
	if ([[[self onMainThread] getCreateTableSyntaxWindow] isVisible]) {
		[[self onMainThread] showCreateTableSyntax:self];
	}

	// Add a history entry
	[spHistoryControllerInstance updateHistoryEntries];
#endif
	// Empty the loading pool and exit the thread
	[self endTask];

#ifndef SP_CODA /* triggered commands */
	NSArray *triggeredCommands = [SPAppDelegate bundleCommandsForTrigger:SPBundleTriggerActionTableChanged];
	
	for(NSString* cmdPath in triggeredCommands) 
	{
		NSArray *data = [cmdPath componentsSeparatedByString:@"|"];
		NSMenuItem *aMenuItem = [[[NSMenuItem alloc] init] autorelease];
		[aMenuItem setTag:0];
		[aMenuItem setToolTip:[data objectAtIndex:0]];

		// For HTML output check if corresponding window already exists
		BOOL stopTrigger = NO;
		if([(NSString*)[data objectAtIndex:2] length]) {
			BOOL correspondingWindowFound = NO;
			NSString *uuid = [data objectAtIndex:2];
			for(id win in [NSApp windows]) {
				if([[[[win delegate] class] description] isEqualToString:@"SPBundleHTMLOutputController"]) {
					if([[[win delegate] windowUUID] isEqualToString:uuid]) {
						correspondingWindowFound = YES;
						break;
					}
				}
			}
			if(!correspondingWindowFound) stopTrigger = YES;
		}
		if(!stopTrigger) {
			id firstResponder = [[NSApp keyWindow] firstResponder];
			if([[data objectAtIndex:1] isEqualToString:SPBundleScopeGeneral]) {
				[[SPAppDelegate onMainThread] executeBundleItemForApp:aMenuItem];
			}
			else if([[data objectAtIndex:1] isEqualToString:SPBundleScopeDataTable]) {
				if([[[firstResponder class] description] isEqualToString:@"SPCopyTable"])
					[[firstResponder onMainThread] executeBundleItemForDataTable:aMenuItem];
			}
			else if([[data objectAtIndex:1] isEqualToString:SPBundleScopeInputField]) {
				if([firstResponder isKindOfClass:[NSTextView class]])
					[[firstResponder onMainThread] executeBundleItemForInputField:aMenuItem];
			}
		}
	}
#endif

	[loadPool drain];
}

@end
