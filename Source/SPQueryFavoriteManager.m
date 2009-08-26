//
//  $Id$
//
//  SPQueryFavoriteManager.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Aug 23, 2009
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

#import "SPQueryFavoriteManager.h"
#import "SPEncodingPopupAccessory.h"

#define DEFAULT_QUERY_FAVORITE_FILE_EXTENSION @"sql"
#define QUERY_FAVORITES_PB_DRAG_TYPE @"SequelProQueryFavoritesPasteboard"

@implementation SPQueryFavoriteManager

/**
 * Initialize the manager with the supplied delegate
 */
- (id)initWithDelegate:(id)managerDelegate
{
	if ((self = [super initWithWindowNibName:@"QueryFavoriteManager"])) {
		delegate = managerDelegate;
		
		prefs = [NSUserDefaults standardUserDefaults];
		
		delegateRespondsToFavoriteUpdates = [delegate respondsToSelector:@selector(queryFavoritesHaveBeenUpdated:)];
	}
	
	return self;
}

/**
 * Upon awakening bind the query text view's background colour.
 */
- (void)awakeFromNib
{
	[favoriteQueryTextView setAllowsDocumentBackgroundColorChange:YES];
	
	NSMutableDictionary *bindingOptions = [NSMutableDictionary dictionary];
	
	[bindingOptions setObject:NSUnarchiveFromDataTransformerName forKey:@"NSValueTransformerName"];
	
	[favoriteQueryTextView bind:@"backgroundColor"
					   toObject:[NSUserDefaultsController sharedUserDefaultsController]
					withKeyPath:@"values.CustomQueryEditorBackgroundColor"
						options:bindingOptions];
	
	// Select the first query
	[queryFavoritesController setSelectionIndex:0];
	
	// Register drag types
	[favoritesTableView registerForDraggedTypes:[NSArray arrayWithObject:QUERY_FAVORITES_PB_DRAG_TYPE]];	
}

#pragma mark -
#pragma mark Accessor methods

/**
 * Returns the query favorites array.
 */
- (NSMutableArray *)queryFavorites
{
	return [queryFavoritesController arrangedObjects];
}

/**
 * This method is only implemented to be compatible with CMTextView.
 */
- (id)customQueryInstance
{
	return [[[NSApp mainWindow] delegate] valueForKey:@"customQueryInstance"];
}

#pragma mark -
#pragma mark IBAction methods

/**
 * Adds a query favorite
 */
- (IBAction)addQueryFavorite:(id)sender
{
	NSMutableDictionary *favorite = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"New Favorite", @"", nil] forKeys:[NSArray arrayWithObjects:@"name", @"query", nil]];
	
	[queryFavoritesController addObject:favorite];
	[queryFavoritesController setSelectionIndex:([[queryFavoritesController arrangedObjects] count] - 1)];
	
	[favoritesTableView reloadData];
	[favoritesTableView scrollRowToVisible:[favoritesTableView selectedRow]];
	
	// Inform the delegate that the query favorites have been updated
	if (delegateRespondsToFavoriteUpdates) {
		[delegate queryFavoritesHaveBeenUpdated:self];
	}
}

/**
 * Removes a query favorite
 */
- (IBAction)removeQueryFavorite:(id)sender
{
	if ([favoritesTableView numberOfSelectedRows] == 1) {
		[queryFavoritesController removeObjectAtArrangedObjectIndex:[favoritesTableView selectedRow]];
		
		[favoritesTableView reloadData];
		
		// Inform the delegate that the query favorites have been updated
		if (delegateRespondsToFavoriteUpdates) {
			[delegate queryFavoritesHaveBeenUpdated:self];
		}
	}
}

/**
 * Removes all query favorites
 */
- (IBAction)removeAllQueryFavorites:(id)sender
{
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Remove all query favorites?", @"remove all query favorites message") 
									 defaultButton:NSLocalizedString(@"Cancel", @"cancel button")
								   alternateButton:NSLocalizedString(@"Remove All", @"remove all button")
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to remove all of your saved query favorites? This action cannot be undone.", @"remove all query favorites informative message")];

	[alert setAlertStyle:NSCriticalAlertStyle];
	
	NSArray *buttons = [alert buttons];
	
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"\r"];
	[[buttons objectAtIndex:1] setKeyEquivalent:@""];
	
	[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"removeAllFavorites"];
}

/**
 * Copies a query favorite
 */
- (IBAction)copyQueryFavorite:(id)sender
{
	if ([favoritesTableView numberOfSelectedRows] == 1) { 
		NSMutableDictionary *favorite = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[favoriteNameTextField stringValue] stringByAppendingFormat:@" Copy"], [favoriteQueryTextView string], nil] forKeys:[NSArray arrayWithObjects:@"name", @"query", nil]];
		
		[queryFavoritesController addObject:favorite];
		[queryFavoritesController setSelectionIndex:([[queryFavoritesController arrangedObjects] count] - 1)];
		
		[favoritesTableView reloadData];
		[favoritesTableView scrollRowToVisible:[favoritesTableView selectedRow]];
		
		// Inform the delegate that the query favorites have been updated
		if (delegateRespondsToFavoriteUpdates) {
			[delegate queryFavoritesHaveBeenUpdated:self];
		}
	}
}

/**
 * Saves the currently selected query favorite to a user specified file.
 */
- (IBAction)saveFavoriteToFile:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setRequiredFileType:DEFAULT_QUERY_FAVORITE_FILE_EXTENSION];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:YES];
	[panel setCanSelectHiddenExtension:YES];
	
	[panel setAccessoryView:[SPEncodingPopupAccessory encodingAccessory:[prefs integerForKey:@"lastSqlFileEncoding"] includeDefaultEntry:NO encodingPopUp:&encodingPopUp]];
	
	[encodingPopUp setEnabled:YES];
	
	[panel beginSheetForDirectory:nil file:[favoriteNameTextField stringValue] modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

/**
 * Closes the query favorite manager
 */
- (IBAction)closeQueryManagerSheet:(id)sender
{
	[NSApp endSheet:[self window] returnCode:0];
	[[self window] orderOut:self];
}

#pragma mark -
#pragma mark Favorite methods

/**
 * Returns the query favorite at the supplied index.
 */
- (NSString *)queryFavoriteAtIndex:(NSInteger)index
{
	return [[[queryFavoritesController arrangedObjects] objectAtIndex:index] objectForKey:@"query"];
}

/**
 * Adds the supplied query the user's favorites. 
 */
- (SPQueryFavoriteAddition)addQueryToFavorites:(NSString *)query
{
	if ([query isEqualToString:@""]) return SPQueryFavoriteIsBlank;
	
	// Check that the favorite doesn't already exist
	for (NSDictionary *favorite in [queryFavoritesController arrangedObjects])
	{
		if ([[favorite objectForKey:@"query"] isEqualToString:query]) {
			return SPQueryFavoriteExists;
		}
	}
	
	NSMutableDictionary *favorite = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"test", query, nil] forKeys:[NSArray arrayWithObjects:@"name", @"query", nil]];
	
	[queryFavoritesController addObject:favorite];
	[queryFavoritesController setSelectionIndex:([[queryFavoritesController arrangedObjects] count] - 1)];
	
	[favoritesTableView reloadData];
	[favoritesTableView scrollRowToVisible:[favoritesTableView selectedRow]];
		
	// Inform the delegate that the query favorites have been updated
	if (delegateRespondsToFavoriteUpdates) {
		[delegate queryFavoritesHaveBeenUpdated:self];
	}
	
	return SPQueryFavoriteAdded;
}

#pragma mark -
#pragma mark SplitView delegate methods

/**
 * Return the maximum possible size of the splitview.
 */
- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
{
	return (proposedMax - 220);
}

/**
 * Return the minimum possible size of the splitview.
 */
- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
{
	return (proposedMin + 120);
}

#pragma mark -
#pragma mark TableView datasource methods

/**
 * Returns the number of query favorites.
 */
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [[queryFavoritesController arrangedObjects] count];
}

/**
 * Returns the value for the requested table column and row index.
 */
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	return [[[queryFavoritesController arrangedObjects] objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
}

#pragma mark -
#pragma mark TableView delegate methods

/**
 * Called whenever the user's changes the currently selected favorite.
 */
/*- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	[favoriteQueryTextView setString:@""];
	
	if ([favoritesTableView numberOfSelectedRows] == 1) {
		[favoriteQueryTextView setString:[[[queryFavoritesController arrangedObjects] objectAtIndex:[favoritesTableView selectedRow]] objectForKey:@"query"]];
	}
}*/

#pragma mark -
#pragma mark Menu validation

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = [menuItem action];
	
	if ((action == @selector(removeQueryFavorite:))	|| 
		(action == @selector(copyQueryFavorite:))	|| 
		(action == @selector(saveFavoriteToFile:))) 
	{
		return ([favoritesTableView numberOfSelectedRows] == 1);
	}
	else if (action == @selector(removeAllQueryFavorites:)) {
		return ([[queryFavoritesController arrangedObjects] count] > 0);
	}
	
	return YES;
}

#pragma mark -
#pragma mark TableView drag & drop delegate methods

/**
 * Return whether or not the supplied rows can be written.
 */
- (BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{	
	if ([rows count] == 1) {
		NSArray *pboardTypes = [NSArray arrayWithObject:QUERY_FAVORITES_PB_DRAG_TYPE];
		NSInteger originalRow = [[rows objectAtIndex:0] intValue];
		
		[pboard declareTypes:pboardTypes owner:nil];
		[pboard setString:[[NSNumber numberWithInt:originalRow] stringValue] forType:QUERY_FAVORITES_PB_DRAG_TYPE];
		
		return YES;
	} 
		
	return NO;
}

/**
 * Validate the proposed drop of the supplied rows.
 */
- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{	
	NSArray *pboardTypes = [[info draggingPasteboard] types];
	
	if (([pboardTypes count] > 1) && (row != -1)) {
		if (([pboardTypes containsObject:QUERY_FAVORITES_PB_DRAG_TYPE]) && (operation == NSTableViewDropAbove)) {
			NSInteger originalRow = [[[info draggingPasteboard] stringForType:QUERY_FAVORITES_PB_DRAG_TYPE] intValue];
			
			if ((row != originalRow) && (row != (originalRow + 1))) {
				return NSDragOperationMove;
			}
		}
	}
	
	return NSDragOperationNone;
}

/**
 * Return whether or not to accept the drop of the supplied rows.
 */
- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{	
	NSInteger originalRow = [[[info draggingPasteboard] stringForType:QUERY_FAVORITES_PB_DRAG_TYPE] intValue];
	NSInteger destinationRow = row;
	
	if (destinationRow > originalRow) destinationRow--;
	
	NSMutableDictionary *draggedRow = [NSMutableDictionary dictionaryWithDictionary:[[queryFavoritesController arrangedObjects] objectAtIndex:originalRow]];
	
	[queryFavoritesController removeObjectAtArrangedObjectIndex:originalRow];
	[queryFavoritesController insertObject:draggedRow atArrangedObjectIndex:destinationRow];
	
	[favoritesTableView reloadData];
	[favoritesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:destinationRow] byExtendingSelection:NO];
	
	return YES;
}

#pragma mark -
#pragma mark Other

/**
 * Sheet did end method
 */
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{
	if ([contextInfo isEqualToString:@"removeAllFavorites"]) {
		if (returnCode == NSAlertAlternateReturn) {
			[queryFavoritesController removeObjects:[queryFavoritesController arrangedObjects]];
		}
	}
}

/**
 * Save panel did end method.
 */
- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{
	if (returnCode == NSOKButton) {
		NSError *error = nil;
		
		[prefs setInteger:[[encodingPopUp selectedItem] tag] forKey:@"lastSqlFileEncoding"];
		[prefs synchronize];
		
		[[favoriteQueryTextView string] writeToFile:[panel filename] atomically:YES encoding:[[encodingPopUp selectedItem] tag] error:&error];
		
		if (error) [[NSAlert alertWithError:error] runModal];
	}
}

@end
