//
//  $Id: SPFieldEditorController.h 802 2009-06-03 20:46:57Z bibiko $
//
//  SPHistoryController.h
//  sequel-pro
//
//  Created by Rowan Beentje on July 23, 2009
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

#import "TableDocument.h"
#import "TablesList.h"
#import "SPHistoryController.h"


@implementation SPHistoryController

#pragma mark Setup and teardown

/**
 * Initialise by creating a blank history array
 */
- (id) init
{
	if (self = [super init]) {
		history = [[NSMutableArray alloc] init];
		historyPosition = NSNotFound;
		restoringHistoryState = NO;
	}
	return self;	
}

- (void) dealloc
{
	[history release];
	[super dealloc];
}

#pragma mark -
#pragma mark Interface interaction

/**
 * Updates the toolbar item to reflect the current history state and position
 */
- (void) updateToolbarItem
{
	BOOL backEnabled = NO;
	BOOL forwardEnabled = NO;

	// Set the active state of the segments if appropriate
	if ([history count] && historyPosition > 0) backEnabled = YES;
	if ([history count] && historyPosition + 1 < [history count]) forwardEnabled = YES;
	
	[historyControl setEnabled:backEnabled forSegment:0];
	[historyControl setEnabled:forwardEnabled forSegment:1];
}

/**
 * Trigger a navigation action in response to a click
 */
- (IBAction) historyControlClicked:(NSSegmentedControl *)theControl
{
	switch ([theControl selectedSegment]) {

		// Back button clicked:
		case 0:
			if (historyPosition == NSNotFound || !historyPosition) return;
			[self loadEntryAtPosition:historyPosition - 1];
			break;

		// Forward button clicked:
		case 1:
			if (historyPosition == NSNotFound || historyPosition + 1 >= [history count]) return;
			[self loadEntryAtPosition:historyPosition + 1];
			break;
	}
}

/**
 * Retrieve the view that is currently selected from the database
 */
- (unsigned int) currentlySelectedView
{
	unsigned int theView = NSNotFound;

	NSString *viewName = [[[theDocument valueForKey:@"tableTabView"] selectedTabViewItem] identifier];
	if ([viewName isEqualToString:@"source"]) {
		theView = SP_VIEW_STRUCTURE;
	} else if ([viewName isEqualToString:@"content"]) {
		theView = SP_VIEW_CONTENT;
	} else if ([viewName isEqualToString:@"customQuery"]) {
		theView = SP_VIEW_CUSTOMQUERY;
	} else if ([viewName isEqualToString:@"status"]) {
		theView = SP_VIEW_STATUS;
	} else if ([viewName isEqualToString:@"relations"]) {
		theView = SP_VIEW_RELATIONS;
	}

	return theView;
}

#pragma mark -
#pragma mark Adding or updating history entries

/**
 * Call to store or update a history item for the document state. Checks against
 * the latest stored details; if they match, a new history item is not created.
 * This should therefore be called without worry of duplicates.
 */
- (void) updateHistoryEntries
{

	// Don't modify anything if we're in the process of restoring an old history state
	if (restoringHistoryState) return;

	// Work out the current document details
	NSString *theDatabase = [theDocument database];
	NSString *theTable = [theDocument table];
	unsigned int theView = [self currentlySelectedView];

	// Check for a duplicate against the current entry
	if (historyPosition != NSNotFound) {
		NSDictionary *currentHistoryItem = [history objectAtIndex:historyPosition];
		if ([[currentHistoryItem objectForKey:@"database"] isEqualToString:theDatabase]
			&& [[currentHistoryItem objectForKey:@"table"] isEqualToString:theTable]
			&& [[currentHistoryItem objectForKey:@"view"] intValue] == theView)
		{
			return;
		}
	}

	// If there's any items after the current history position, remove them
	if (historyPosition != NSNotFound && historyPosition < [history count] - 1) {
		[history removeObjectsInRange:NSMakeRange(historyPosition + 1, [history count] - historyPosition - 1)];

	// Special case: if the last history item is currently active, and has no table,
	// but the new selection does - delete the last entry, in order to replace it.
	// This improves history flow.
	} else if (historyPosition != NSNotFound && historyPosition == [history count] - 1
				&& [[[history objectAtIndex:historyPosition] objectForKey:@"database"] isEqualToString:theDatabase]
				&& ![[history objectAtIndex:historyPosition] objectForKey:@"table"])
	{
		[history removeLastObject];		
	}

	// Construct and add the new history entry
	NSMutableDictionary *newEntry = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										theDatabase, @"database",
										theTable, @"table",
										[NSNumber numberWithInt:theView], @"view",
										nil];
	[history addObject:newEntry];
	historyPosition = [history count] - 1;
	[self updateToolbarItem];
}

#pragma mark -
#pragma mark Loading history entries

/**
 * Load a history entry and attempt to return the interface to that state.
 */
- (void) loadEntryAtPosition:(unsigned int)position
{

	// Sanity check the input
	if (position == NSNotFound || position < 0 || position >= [history count]) {
		NSBeep();
		return;
	}

	restoringHistoryState = YES;

	// Update the position and extract the history entry
	historyPosition = position;
	NSDictionary *historyEntry = [history objectAtIndex:historyPosition];

	// Check and set the database
	if (![[theDocument database] isEqualToString:[historyEntry objectForKey:@"database"]]) {
		NSPopUpButton *chooseDatabaseButton = [theDocument valueForKey:@"chooseDatabaseButton"];
		[chooseDatabaseButton selectItemWithTitle:[historyEntry objectForKey:@"database"]];
		[theDocument chooseDatabase:self];
		if (![[theDocument database] isEqualToString:[historyEntry objectForKey:@"database"]]) {
			return [self abortEntryLoad];
		}
	}

	// Check and set the table
	if ([historyEntry objectForKey:@"table"] && ![[theDocument table] isEqualToString:[historyEntry objectForKey:@"table"]]) {
		TablesList *tablesListInstance = [theDocument valueForKey:@"tablesListInstance"];
		NSArray *tables = [tablesListInstance tables];
		if ([tables indexOfObject:[historyEntry objectForKey:@"table"]] == NSNotFound) {
			return [self abortEntryLoad];
		}
		[[tablesListInstance valueForKey:@"tablesListView"] selectRowIndexes:[NSIndexSet indexSetWithIndex:[tables indexOfObject:[historyEntry objectForKey:@"table"]]] byExtendingSelection:NO];
		if (![[theDocument table] isEqualToString:[historyEntry objectForKey:@"table"]]) {
			return [self abortEntryLoad];
		}
	} else if (![historyEntry objectForKey:@"table"] && [theDocument table]) {
		TablesList *tablesListInstance = [theDocument valueForKey:@"tablesListInstance"];
		[[tablesListInstance valueForKey:@"tablesListView"] deselectAll:self];		
	}

	// Check and set the view
	if ([self currentlySelectedView] != [[historyEntry objectForKey:@"view"] intValue]) {
		switch ([[historyEntry objectForKey:@"view"] intValue]) {
			case SP_VIEW_STRUCTURE:
				[theDocument viewStructure:self];
				break;
			case SP_VIEW_CONTENT:
				[theDocument viewContent:self];
				break;
			case SP_VIEW_CUSTOMQUERY:
				[theDocument viewQuery:self];
				break;
			case SP_VIEW_STATUS:
				[theDocument viewStatus:self];
				break;
			case SP_VIEW_RELATIONS:
				[theDocument viewRelations:self];
				break;
		}
		if ([self currentlySelectedView] != [[historyEntry objectForKey:@"view"] intValue]) {
			return [self abortEntryLoad];
		}
	}

	restoringHistoryState = NO;
	[self updateToolbarItem];
}

/**
 * Convenience method for aborting history load - could at some point
 * clean up the history list, show an alert, etc
 */
- (void) abortEntryLoad
{
	NSBeep();
	restoringHistoryState = NO;
}

@end
