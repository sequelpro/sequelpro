//
//  $Id$
//
//  SPDatabaseViewController.m
//  sequel-pro
//
//  Created by Rowan Beentje on 31/10/2010.
//  Copyright 2010 Arboreal. All rights reserved.
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

#import "SPAppController.h"
#import "SPBundleHTMLOutputController.h"
#import "SPCopyTable.h"
#import "SPDatabaseViewController.h"
#import "SPHistoryController.h"
#import "SPTableContent.h"
#import "SPTableData.h"
#import "SPTablesList.h"
#import "SPTableTriggers.h"
#ifdef SP_REFACTOR /* headers */
#import "SPTableStructure.h"
#endif

@interface SPDatabaseDocument (SPDatabaseViewControllerPrivateAPI)

- (void)_loadTabTask:(NSTabViewItem *)tabViewItem;
- (void)_loadTableTask;

@end

@implementation SPDatabaseDocument (SPDatabaseViewController)

#pragma mark -
#pragma mark Getters

#ifndef SP_REFACTOR /* getters */
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

#ifndef SP_REFACTOR /* toolbar ibactions */

#pragma mark -
#pragma mark Tab view control and delegate methods

- (IBAction)viewStructure:(id)sender
{
	// Cancel the selection if currently editing a view and unable to save
	if (![self couldCommitCurrentViewActions]) {
		[mainToolbar setSelectedItemIdentifier:*SPViewModeToMainToolbarMap[[prefs integerForKey:SPLastViewMode]]];
		return;
	}

	[tableTabView selectTabViewItemAtIndex:0];
	[mainToolbar setSelectedItemIdentifier:SPMainToolbarTableStructure];
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

	// Refresh data
	if([self table] && [[self table] length]) {
		[tableDataInstance resetAllData];
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
	if (reload && selectedTableName && [tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == SPTableViewStructure) {
		[tableSourceInstance loadTable:selectedTableName];
	} else {
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
#ifndef SP_REFACTOR /* check which tab is selected */
	 && [tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == SPTableViewContent
#endif
	 ) {
		[tableContentInstance loadTable:selectedTableName];
	} else {
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
#ifndef SP_REFACTOR /* check which tab is selected */
		&& [tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]] == SPTableViewStatus
#endif
		) {
		[[extendedTableInfoInstance onMainThread] loadTable:selectedTableName];
	} else {
		statusLoaded = !reload;
	}
}

#ifndef SP_REFACTOR /* !!! respond to tab change */
/**
 * Triggers a task to update the newly selected tab view, ensuring
 * the data is fully loaded and up-to-date.
 */
- (void)tabView:(NSTabView *)aTabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	[self startTaskWithDescription:[NSString stringWithFormat:NSLocalizedString(@"Loading %@...", @"Loading table task string"), [self table]]];
	if ([NSThread isMainThread]) {
		[NSThread detachNewThreadSelector:@selector(_loadTabTask:) toTarget:self withObject:tabViewItem];
	} else {
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
- (void)loadTable:(NSString *)aTable ofType:(NSInteger)aTableType
{

	// Ensure a connection is still present
	if (![mySQLConnection isConnected]) return;

	// If the supplied table name was nil, clear the views.
	if (!aTable) {
		
		// Update the selected table name and type
		if (selectedTableName) [selectedTableName release], selectedTableName = nil;
		selectedTableType = SPTableTypeNone;

		// Clear the views
		[[tablesListInstance onMainThread] setSelectionState:nil];
		[tableSourceInstance loadTable:nil];
		[tableContentInstance loadTable:nil];
#ifndef SP_REFACTOR /* [extendedTableInfoInstance loadTable:] */
		[[extendedTableInfoInstance onMainThread] loadTable:nil];
		[[tableTriggersInstance onMainThread] resetInterface];
#endif
		structureLoaded = NO;
		contentLoaded = NO;
		statusLoaded = NO;
		triggersLoaded = NO;

#ifndef SP_REFACTOR
		// Update the window title
		[self updateWindowTitle:self];

		// Add a history entry
		[spHistoryControllerInstance updateHistoryEntries];
#endif

		// Notify listeners of the table change
#ifndef SP_REFACTOR
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:SPTableChangedNotification object:self];
#else
		[[NSNotificationCenter defaultCenter] sequelProPostNotificationOnMainThreadWithName:SPTableChangedNotification object:self];
#endif

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
	} else {
		[self startTaskWithDescription:[NSString stringWithFormat:NSLocalizedString(@"Loading %@...", @"Loading table task string"), aTable]];	
	}

	// Update the tables list interface - also updates menus to reflect the selected table type
	[[tablesListInstance onMainThread] setSelectionState:[NSDictionary dictionaryWithObjectsAndKeys:aTable, @"name", [NSNumber numberWithInteger:aTableType], @"type", nil]];

	// If on the main thread, fire up a thread to deal with view changes and data loading;
	// if already on a background thread, make the changes on the existing thread.
	if ([NSThread isMainThread]) {
		[NSThread detachNewThreadSelector:@selector(_loadTableTask) toTarget:self withObject:nil];
	} else {
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
	if (![self table]
		|| ([tablesListInstance tableType] != SPTableTypeTable && [tablesListInstance tableType] != SPTableTypeView))
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
#ifndef SP_REFACTOR /* case SPTableViewStatus: case SPTableViewTriggers: */
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

#ifndef SP_REFACTOR /* Update the window title */
	// Update the window title
	[self updateWindowTitle:self];
#endif

	// Reset table information caches and mark that all loaded views require their data reloading
	[tableDataInstance resetAllData];
	structureLoaded = NO;
	contentLoaded = NO;
	statusLoaded = NO;
	triggersLoaded = NO;

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
#ifndef SP_REFACTOR
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:SPTableChangedNotification object:self];
#else
		[[NSNotificationCenter defaultCenter] sequelProPostNotificationOnMainThreadWithName:SPTableChangedNotification object:self];
#endif
#ifndef SP_REFACTOR /* [spHistoryControllerInstance restoreViewStates] */

	// Restore view states as appropriate
	[spHistoryControllerInstance restoreViewStates];
#endif

	// Load the currently selected view if looking at a table or view
	if (tableEncoding && (selectedTableType == SPTableTypeView || selectedTableType == SPTableTypeTable))
	{
#ifndef SP_REFACTOR /* load everything */
		NSInteger selectedTabViewIndex = [tableTabView indexOfTabViewItem:[tableTabView selectedTabViewItem]];

		switch (selectedTabViewIndex) {
			case SPTableViewStructure:
#endif
				[tableSourceInstance loadTable:selectedTableName];
				structureLoaded = YES;
#ifndef SP_REFACTOR /* load everything */
				break;
			case SPTableViewContent:
#endif
				[tableContentInstance loadTable:selectedTableName];
				contentLoaded = YES;
#ifndef SP_REFACTOR /* load everything */
				break;
			case SPTableViewStatus:
				[[extendedTableInfoInstance onMainThread] loadTable:selectedTableName];
				statusLoaded = YES;
				break;
			case SPTableViewTriggers:
				[[tableTriggersInstance onMainThread] loadTriggers];
				triggersLoaded = YES;
				break;
		}
#endif
	}

	// Clear any views which haven't been loaded as they weren't visible.  Note
	// that this should be done after reloading visible views, instead of clearing all
	// views, to reduce UI operations and avoid resetting state unnecessarily.
	if (!structureLoaded) [tableSourceInstance loadTable:nil];
	if (!contentLoaded) [tableContentInstance loadTable:nil];
	if (!statusLoaded) [[extendedTableInfoInstance onMainThread] loadTable:nil];
	if (!triggersLoaded) [[tableTriggersInstance onMainThread] resetInterface];

#ifndef SP_REFACTOR /* show Create Table syntax */
	// Update the "Show Create Syntax" window if it's already opened
	// according to the selected table/view/proc/func
	if([[[self onMainThread] getCreateTableSyntaxWindow] isVisible])
		[[self onMainThread] showCreateTableSyntax:self];

	// Add a history entry
	[spHistoryControllerInstance updateHistoryEntries];
#endif
	// Empty the loading pool and exit the thread
	[self endTask];

#ifndef SP_REFACTOR /* triggered commands */
	NSArray *triggeredCommands = [[NSApp delegate] bundleCommandsForTrigger:SPBundleTriggerActionTableChanged];
	for(NSString* cmdPath in triggeredCommands) {
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
			if([[data objectAtIndex:1] isEqualToString:SPBundleScopeGeneral]) {
				[[[NSApp delegate] onMainThread] executeBundleItemForApp:aMenuItem];
			}
			else if([[data objectAtIndex:1] isEqualToString:SPBundleScopeDataTable]) {
				if([[[[[NSApp mainWindow] firstResponder] class] description] isEqualToString:@"SPCopyTable"])
					[[[[NSApp mainWindow] firstResponder] onMainThread] executeBundleItemForDataTable:aMenuItem];
			}
			else if([[data objectAtIndex:1] isEqualToString:SPBundleScopeInputField]) {
				if([[[NSApp mainWindow] firstResponder] isKindOfClass:[NSTextView class]])
					[[[[NSApp mainWindow] firstResponder] onMainThread] executeBundleItemForInputField:aMenuItem];
			}
		}
	}
#endif


	[loadPool drain];
}

@end
