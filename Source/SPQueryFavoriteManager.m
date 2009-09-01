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
#import "ImageAndTextCell.h"
#import "SPEncodingPopupAccessory.h"

#define DEFAULT_QUERY_FAVORITE_FILE_EXTENSION @"sql"
#define DEFAULT_SEQUELPRO_FILE_EXTENSION @"spf"

#define SP_MULTIPLE_SELECTION_PLACEHOLDER_STRING NSLocalizedString(@"[multiple selection]", @"[multiple selection]")
#define SP_NO_SELECTION_PLACEHOLDER_STRING NSLocalizedString(@"[no selection]", @"[no selection]")

#define QUERY_FAVORITES_PB_DRAG_TYPE @"SequelProQueryFavoritesPasteboard"

@interface SPQueryFavoriteManager (Private)
- (void)_writePendingQueryString;
@end

@implementation SPQueryFavoriteManager

/**
 * Initialize the manager with the supplied delegate
 */
- (id)initWithDelegate:(id)managerDelegate
{
	if ((self = [super initWithWindowNibName:@"QueryFavoriteManager"])) {
		delegate = managerDelegate;

		prefs = [NSUserDefaults standardUserDefaults];

		favoriteProperties = [[NSMutableArray alloc] init];
		favorites = [[NSMutableArray alloc] init];
		selectedRowBeforeChangingSelection = 0;
		pendingQueryString = [[NSMutableString alloc] init];
		
		delegateRespondsToFavoriteUpdates = [delegate respondsToSelector:@selector(queryFavoritesHaveBeenUpdated:)];
	}
	
	return self;
}

- (void)dealloc
{
	[favoriteProperties release];
	[favorites release];
	[pendingQueryString release];
	[super dealloc];
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


	[favorites addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"GLOBAL", @"name", nil]];
	[favoriteProperties addObject:[NSNumber numberWithInt:SP_FAVORITETYPE_HEADER]];

	// Build data source for global queryFavorites (as mutable copy! otherwise each
	// change will be stored in the prefs at once)
	if([prefs objectForKey:@"queryFavorites"]) {
		for(id fav in [prefs objectForKey:@"queryFavorites"]) {
			[favorites addObject:[fav mutableCopy]];
			[favoriteProperties addObject:[NSNumber numberWithInt:SP_FAVORITETYPE_GLOBAL]];
		}
	}
	[favoritesTableView reloadData];

	// Set Remove button state
	[removeButton setEnabled:([favorites count] > 1)];

	// Select the first query
	[favoritesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:1] byExtendingSelection:NO];

	// Register drag types
	[favoritesTableView registerForDraggedTypes:[NSArray arrayWithObject:QUERY_FAVORITES_PB_DRAG_TYPE]];
}

#pragma mark -
#pragma mark Accessor methods

/**
 * Returns the global query favorites array.
 */
- (NSMutableArray *)globalQueryFavorites
{
	NSMutableArray *globals = [NSMutableArray array];
	
	NSUInteger i;
	
	for(i=1; i<[favorites count]; i++)
		if([[favoriteProperties objectAtIndex:i] intValue] == SP_FAVORITETYPE_GLOBAL)
			[globals addObject:[favorites objectAtIndex:i]];

	return globals;
}

/**
 * Returns the global query favorites array.
 */
- (NSMutableArray *)connectionQueryFavorites
{
	NSMutableArray *conns = [NSMutableArray array];
	
	NSUInteger i;
	
	for(i=1; i<[favorites count]; i++)
		if([[favoriteProperties objectAtIndex:i] intValue] == SP_FAVORITETYPE_CONNECTION)
			[conns addObject:[favorites objectAtIndex:i]];

	return conns;
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

	[self _writePendingQueryString];
	NSMutableDictionary *favorite = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"New Favorite", @"", nil] forKeys:[NSArray arrayWithObjects:@"name", @"query", nil]];
	
	[favorites addObject:favorite];
	[favoriteProperties addObject:[NSNumber numberWithInt:SP_FAVORITETYPE_GLOBAL]];
	[favoritesTableView reloadData];

	[favoritesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:([favorites count] - 1)] byExtendingSelection:NO];
	
	[favoritesTableView scrollRowToVisible:[favoritesTableView selectedRow]];

	selectedRowBeforeChangingSelection = [favorites count] - 1;

	[removeButton setEnabled:([favorites count] > 1)];
	
	[[self window] makeFirstResponder:favoriteNameTextField];

}

/**
 * Removes a query favorite
 */
- (IBAction)removeQueryFavorite:(id)sender
{
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Remove selected query favorites?", @"remove selected query favorites message") 
									 defaultButton:NSLocalizedString(@"Cancel", @"cancel button")
								   alternateButton:NSLocalizedString(@"Remove", @"remove button")
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to remove all selected query favorites? This action cannot be undone.", @"remove all selected query favorites informative message")];

	[alert setAlertStyle:NSCriticalAlertStyle];
	
	NSArray *buttons = [alert buttons];
	
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"\r"];
	[[buttons objectAtIndex:1] setKeyEquivalent:@""];
	
	[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"removeSelectedFavorites"];
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
		
		[self _writePendingQueryString];
		
		[favorites addObject:favorite];
		[favoriteProperties addObject:[NSNumber numberWithInt:SP_FAVORITETYPE_GLOBAL]];
		
		[favoritesTableView reloadData];

		// Update selection
		[favoritesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:([favorites count] - 1)] byExtendingSelection:NO];
		selectedRowBeforeChangingSelection = [favorites count] - 1;
		
		[favoritesTableView scrollRowToVisible:[favoritesTableView selectedRow]];
		
		[[self window] makeFirstResponder:favoriteNameTextField];

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
	[panel setCanCreateDirectories:YES];

	[panel setAccessoryView:[SPEncodingPopupAccessory encodingAccessory:[prefs integerForKey:@"lastSqlFileEncoding"] includeDefaultEntry:NO encodingPopUp:&encodingPopUp]];
	
	[encodingPopUp setEnabled:YES];
	
	[panel beginSheetForDirectory:nil file:[favoriteNameTextField stringValue] modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:@"saveQuery"];
}

- (IBAction)exportFavorites:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setRequiredFileType:DEFAULT_SEQUELPRO_FILE_EXTENSION];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:NO];
	[panel setCanSelectHiddenExtension:YES];
	[panel setCanCreateDirectories:YES];

	[panel beginSheetForDirectory:nil file:nil modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:@"exportFavorites"];
}

- (IBAction)importFavoritesByAdding:(id)sender
{
	
}

- (IBAction)importFavoritesByReplacing:(id)sender
{
	
}

/**
 * Closes the query favorite manager
 */
- (IBAction)closeQueryManagerSheet:(id)sender
{

	[NSApp endSheet:[self window] returnCode:0];
	[[self window] orderOut:self];

	// Save button was pressed
	if([sender tag]) {
		// Ensure that last changes will be written to prefs
		// if only one favorite is selected; otherwise unstable state
		if ([favoritesTableView numberOfSelectedRows] == 1) {
			[self _writePendingQueryString];
			[[self window] makeFirstResponder:favoritesTableView];
			[favoritesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRowBeforeChangingSelection] byExtendingSelection:NO];
		}

		// Inform the delegate that the query favorites have been updated
		if (delegateRespondsToFavoriteUpdates)
			[delegate queryFavoritesHaveBeenUpdated:self];

	}
	
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
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [favorites count];
}

/**
 * Returns the value for the requested table column and row index.
 */
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if(![[favorites objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]]) return @"";

	return [[favorites objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
}

/*
 * Save favorite names if inline edited (suppress empty names)
 */
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{

	if([[aTableColumn identifier] isEqualToString:@"name"] && [anObject length]) {
		[[favorites objectAtIndex:rowIndex] setObject:[anObject description] forKey:@"name"];
		[[favorites objectAtIndex:rowIndex] setObject:[favoriteQueryTextView string] forKey:@"query"];
		[favoriteNameTextField setStringValue:[anObject description]];
	}

	[favoritesTableView reloadData];
}

/*
 * Before selecting an other favorite save pending query string changes
 * and make sure that no group table item can be selected
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
	[pendingQueryString setString:[favoriteQueryTextView string]];
	[self _writePendingQueryString];
	return ([[favoriteProperties objectAtIndex:rowIndex] intValue] == SP_FAVORITETYPE_HEADER) ? NO : YES;
}

/*
 * Update name and query view and control several table selection modi
 */
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{

	// store the last selected favorite for writing the pending query string
	// - for a single favorite selection
	if([favoritesTableView numberOfSelectedRows] == 1)
		selectedRowBeforeChangingSelection = [favoritesTableView selectedRow];
	// - for multiple favorite selection
	if([favoritesTableView numberOfSelectedRows] > 1) {

		// Save query string directly
		if(selectedRowBeforeChangingSelection > 0 && selectedRowBeforeChangingSelection < [favorites count])
		[[favorites objectAtIndex:selectedRowBeforeChangingSelection] setObject:[favoriteQueryTextView string] forKey:@"query"];

		// Update name text field
		[[favoriteNameTextField cell] setPlaceholderString:SP_MULTIPLE_SELECTION_PLACEHOLDER_STRING];
		[favoriteNameTextField setStringValue:@""];
		[favoriteNameTextField setEditable:NO];
		[favoriteNameTextField setSelectable:NO];
		
		// This is an "hack"; if one set it to @"" it could happen that
		// the wrong pending query string will be saved
		[favoriteQueryTextView setTextColor:[NSColor clearColor]];
		[favoriteQueryTextView setEditable:NO];
		[favoriteQueryTextView setSelectable:NO];
		
		return;

	} else {
		[favoriteNameTextField setEditable:YES];
		[favoriteNameTextField setSelectable:YES];
		[favoriteQueryTextView setSelectable:YES];
		[favoriteQueryTextView setEditable:YES];
	}


	// only the "GLOBAL" header is in the table 
	if([favorites count] < 2) {
		[self _writePendingQueryString];
		[[self window] makeFirstResponder:favoritesTableView];
		[[favoriteNameTextField cell] setPlaceholderString:SP_NO_SELECTION_PLACEHOLDER_STRING];
		[favoriteNameTextField setStringValue:@""];
		[favoriteQueryTextView setString:@""];
		[pendingQueryString setString:@""];
		selectedRowBeforeChangingSelection = -1;
		return;
	}

	// Update name and query field contents
	NSUInteger row = (NSUInteger)[[aNotification object] selectedRow];

	// This is needed if one deletes the last table item
	if(row > [favorites count] - 1) row = [favorites count] - 1;
	if(row < 1) row = 1;

	[favoriteNameTextField setStringValue:[[favorites objectAtIndex:row] objectForKey:@"name"]];
	[favoriteQueryTextView setString:[[favorites objectAtIndex:row] objectForKey:@"query"]];

}

/*
 * Set indention levels for headers and favorites
 * (maybe in the future use an image for headers for expanding and collapsing)
 */
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if([[favoriteProperties objectAtIndex:rowIndex] intValue] == SP_FAVORITETYPE_HEADER && [[aTableColumn identifier] isEqualToString:@"name"]) {
		// if([[[favoriteProperties objectAtIndex:rowIndex] objectForKey:@"isGroup"] isEqualToString:@"1"])
		// 	[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"NSRightFacingTriangleTemplate"]];
		// else
		// 	[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"NSLeftFacingTriangleTemplate"]];
		[(ImageAndTextCell*)aCell setIndentationLevel:0];
	}
	else if([[favoriteProperties objectAtIndex:rowIndex] intValue] != SP_FAVORITETYPE_HEADER && [[aTableColumn identifier] isEqualToString:@"name"]) {
		// [(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"dummy-small"]];
		[(ImageAndTextCell*)aCell setIndentationLevel:1];
	}
}

/*
 * A row of an header return is slighlty larger
 */
- (CGFloat)tableView:(NSTableView *)aTableView heightOfRow:(NSInteger)rowIndex
{
	return ([[favoriteProperties objectAtIndex:rowIndex] intValue] == SP_FAVORITETYPE_HEADER) ? 20 : 18;
}

/*
 * Only favorite name can be edited inline
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return ([[favoriteProperties objectAtIndex:rowIndex] intValue] == SP_FAVORITETYPE_HEADER) ? NO : YES;
}

/*
 * favoriteProperties holds the data if a table row is a group header or not
 */
- (BOOL)tableView:(NSTableView *)aTableView isGroupRow:(NSInteger)rowIndex
{
	return ([[favoriteProperties objectAtIndex:rowIndex] intValue] == SP_FAVORITETYPE_HEADER) ? YES : NO;
}

/*
 * Changes in the name text field will be saved in data source directly
 * to update the table view accordingly
 */
- (void)controlTextDidChange:(NSNotification *)notification
{

	// Do nothing if no favorite is selected
	if([favoritesTableView selectedRow] < 1) return;

	id object = [notification object];

	if(object == favoriteNameTextField) {
		[[favorites objectAtIndex:[favoritesTableView selectedRow]] setObject:[favoriteNameTextField stringValue] forKey:@"name"];
		[favoritesTableView reloadData];
	}

}

/*
 * Changes in the query text view will be cached as pending query string which will update
 * the data source before selecting an other favorite or before an other event.
 * If multiple rows are selected update name field.
 */
- (void)textViewDidChangeSelection:(NSNotification *)notification
{
	id object = [notification object];

	if(object == favoriteQueryTextView) {
		if(![favoriteQueryTextView isEditable]) return;
		[pendingQueryString setString:[NSString stringWithString:[favoriteQueryTextView string]]];
		if([favoritesTableView numberOfSelectedRows] > 1) {
			[[favoriteNameTextField cell] setPlaceholderString:SP_MULTIPLE_SELECTION_PLACEHOLDER_STRING];
			[favoriteNameTextField setStringValue:@""];
			selectedRowBeforeChangingSelection = -1;
			return;
		}
	}
}

#pragma mark -
#pragma mark Menu validation

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{

	// Disable all if only GLOBAL is in the table
	if([favorites count] < 2) return NO;

	SEL action = [menuItem action];
	
	if ( (action == @selector(copyQueryFavorite:))	|| 
		(action == @selector(saveFavoriteToFile:))) 
	{
		return ([favoritesTableView numberOfSelectedRows] == 1);
	}
	else if ( (action == @selector(removeQueryFavorite:))	||
		( action == @selector(exportFavorites:)))
	{
		return ([favoritesTableView numberOfSelectedRows] > 0);
	}
	else if (action == @selector(removeAllQueryFavorites:)) {
		return ([favorites count] > 0);
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
	
		// Save query string before dragging
		// and suppress the writing of pending query string changes
		[[favorites objectAtIndex:selectedRowBeforeChangingSelection] setObject:[favoriteQueryTextView string] forKey:@"query"];
		selectedRowBeforeChangingSelection = -1;
		return YES;
	} else {
		[favoritesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRowBeforeChangingSelection] byExtendingSelection:NO];
		[[favoriteNameTextField cell] setPlaceholderString:SP_MULTIPLE_SELECTION_PLACEHOLDER_STRING];
		[favoriteNameTextField setStringValue:@""];
		[favoriteQueryTextView setTextColor:[NSColor clearColor]];
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
			
			if ((row != originalRow) && (row != (originalRow + 1)) && (row > 0)) {
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
	
	NSMutableDictionary *draggedRow = [NSMutableDictionary dictionaryWithDictionary:[favorites objectAtIndex:originalRow]];
	
	[favorites removeObjectAtIndex:originalRow];
	[favorites insertObject:draggedRow atIndex:destinationRow];
	
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
	// Is disabled - do we need that?
	// if ([contextInfo isEqualToString:@"removeAllFavorites"]) {
	// 	if (returnCode == NSAlertAlternateReturn) {
	// 		[favorites removeObjects:[queryFavoritesController arrangedObjects]];
	// 	}
	// }
	if([contextInfo isEqualToString:@"removeSelectedFavorites"]) {
		if (returnCode == NSAlertAlternateReturn) {
			NSIndexSet *indexes = [favoritesTableView selectedRowIndexes];

			// get last index
			NSUInteger currentIndex = [indexes lastIndex];
			NSUInteger idx = currentIndex;

			// Prevend to write pending changes
			selectedRowBeforeChangingSelection = -1;
			[pendingQueryString setString:@""];

			while (currentIndex != NSNotFound) {
				[favorites removeObjectAtIndex:currentIndex];
				[favoriteProperties removeObjectAtIndex:currentIndex];
				// get next index (beginning from the end)
				currentIndex = [indexes indexLessThanIndex:currentIndex];
				[favoritesTableView reloadData];
			}

			// Set focus to favorite list to avoid an unstable state
			[[self window] makeFirstResponder:favoritesTableView];

			// Try to reselect a favorite
			[favoritesTableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
			if(idx > [favorites count]-1)
				idx = [favorites count]-1;
			if(idx != 0)
				[favoritesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:idx] byExtendingSelection:NO];

			if(idx > 1) {
				[favoriteNameTextField setStringValue:[[favorites objectAtIndex:idx] objectForKey:@"name"]];
				[favoriteQueryTextView setString:[[favorites objectAtIndex:idx] objectForKey:@"query"]];
			}

			[removeButton setEnabled:([favorites count] > 1)];
		}
	}
}

/**
 * Save panel did end method.
 */
- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{

	if([contextInfo isEqualToString:@"saveQuery"]) {
		if (returnCode == NSOKButton) {
			NSError *error = nil;
		
			[prefs setInteger:[[encodingPopUp selectedItem] tag] forKey:@"lastSqlFileEncoding"];
			[prefs synchronize];
		
			[[favoriteQueryTextView string] writeToFile:[panel filename] atomically:YES encoding:[[encodingPopUp selectedItem] tag] error:&error];
		
			if (error) [[NSAlert alertWithError:error] runModal];
		}
	}
	else if([contextInfo isEqualToString:@"exportFavorites"]) {
		if (returnCode == NSOKButton) {

			// Build a SPF with format = "query favorites"
			NSMutableDictionary *spfdata = [NSMutableDictionary dictionary];
			NSMutableArray *favoriteData = [NSMutableArray array];
			NSMutableDictionary *data = [NSMutableDictionary dictionary];
			[spfdata setObject:[NSNumber numberWithInt:1] forKey:@"version"];
			[spfdata setObject:@"query favorites" forKey:@"format"];
			[spfdata setObject:[NSNumber numberWithBool:NO] forKey:@"encrypted"];

			NSIndexSet *indexes = [favoritesTableView selectedRowIndexes];

			// Get selected items and preserve the order
			NSUInteger i;
			for (i=1; i<[favorites count]; i++)
				if([indexes containsIndex:i])
					[favoriteData addObject:[favorites objectAtIndex:i]];

			[data setObject:favoriteData forKey:@"queryFavorites"];
			[spfdata setObject:data forKey:@"data"];
			
			NSString *err = nil;
			NSData *plist = [NSPropertyListSerialization dataFromPropertyList:spfdata
													  format:NSPropertyListXMLFormat_v1_0
											errorDescription:&err];

			if(err != nil) {
				NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while converting query favorite data", @"error while converting query favorite data")]
												 defaultButton:NSLocalizedString(@"OK", @"OK button") 
											   alternateButton:nil 
												  otherButton:nil 
									informativeTextWithFormat:err];

				[alert setAlertStyle:NSCriticalAlertStyle];
				[alert runModal];
				return;
			}

			NSError *error = nil;
			[plist writeToFile:[panel filename] options:NSAtomicWrite error:&error];
			if (error) [[NSAlert alertWithError:error] runModal];

		}
	}
}

/*
 * Before an other favorite will be chosen or an other event will unfocus the 
 * query text view store the query into the data source
 */
- (void)_writePendingQueryString
{
	if(selectedRowBeforeChangingSelection > 0 && selectedRowBeforeChangingSelection < [favorites count] ) {
		[[favorites objectAtIndex:selectedRowBeforeChangingSelection] setObject:[NSString stringWithString:pendingQueryString] forKey:@"query"];
	} else if(selectedRowBeforeChangingSelection = 0) {
		[[favorites objectAtIndex:[favoritesTableView selectedRow]] setObject:[NSString stringWithString:pendingQueryString] forKey:@"query"];
	}
	[pendingQueryString setString:@""];
}

@end
