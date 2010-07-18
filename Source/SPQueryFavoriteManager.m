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
#import "SPQueryController.h"
#import "SPConstants.h"
#import "SPConnectionController.h"
#import "RegexKitLite.h"
#import "SPTextView.h"

#define SP_MULTIPLE_SELECTION_PLACEHOLDER_STRING NSLocalizedString(@"[multiple selection]", @"[multiple selection]")
#define SP_NO_SELECTION_PLACEHOLDER_STRING NSLocalizedString(@"[no selection]", @"[no selection]")

@interface SPQueryFavoriteManager (Private)

- (void)_initWithNoSelection;

@end

@implementation SPQueryFavoriteManager

/**
 * Initialize the manager with the supplied delegate
 */
- (id)initWithDelegate:(id)managerDelegate
{
	if ((self = [super initWithWindowNibName:@"QueryFavoriteManager"])) {

		prefs = [NSUserDefaults standardUserDefaults];

		favorites = [[NSMutableArray alloc] init];
		
		if(managerDelegate == nil) {
			NSBeep();
			NSLog(@"Query Favorite Manger was called without a delegate.");
			return nil;
		}
		tableDocumentInstance = [managerDelegate valueForKeyPath:@"tableDocumentInstance"];
		delegatesFileURL = [tableDocumentInstance fileURL];
	}
	
	return self;
}

- (void)dealloc
{
	[favorites release];
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


	[favorites addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			@"Global", @"name", 
			@"", @"headerOfFileURL",
			@"", @"query",
			nil]];

	// Build data source for global queryFavorites (as mutable copy! otherwise each
	// change will be stored in the prefs at once)
	if([prefs objectForKey:SPQueryFavorites]) {
		for(id fav in [prefs objectForKey:SPQueryFavorites])
			[favorites addObject:[[fav mutableCopy] autorelease]];
	}

	[favorites addObject:[NSDictionary dictionaryWithObjectsAndKeys:
		[[[delegatesFileURL absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] lastPathComponent], @"name", 
		[delegatesFileURL absoluteString], @"headerOfFileURL", 
		@"", @"query",
		nil]];

	if([[SPQueryController sharedQueryController] favoritesForFileURL:delegatesFileURL]) {
		for(id fav in [[SPQueryController sharedQueryController] favoritesForFileURL:delegatesFileURL])
			[favorites addObject:[[fav mutableCopy] autorelease]];
	}

	// Select the first query if any		
	for (NSDictionary *favorite in favorites) 
	{
		if (![favorite objectForKey:@"headerOfFileURL"]) break;
	}

	[[self window] makeFirstResponder:favoritesTableView];
	[self _initWithNoSelection];

	// Register drag types
	[favoritesTableView registerForDraggedTypes:[NSArray arrayWithObject:SPFavoritesPasteboardDragType]];
	
	[favoritesArrayController setContent:favorites];
	[favoritesTableView reloadData];

	// Set Remove button state
	[removeButton setEnabled:([favoritesTableView numberOfSelectedRows] > 0)];
	
	// Set the button bar delegate 
	[splitViewButtonBar setSplitViewDelegate:self];
}

#pragma mark -
#pragma mark Accessor methods

/**
 * Returns the query favorites array for fileURL.
 * fileURL == nil → global favorites
 */
- (NSMutableArray *)queryFavoritesForFileURL:(NSURL *)fileURL
{
	NSMutableArray *favs = [NSMutableArray array];
	NSString *fileURLstring;

	if(fileURL == nil)
		fileURLstring = @"";
	else
		fileURLstring = [fileURL absoluteString];

	NSUInteger i = 0;

	// Look for the header specified by fileURL
	while(i<[favorites count]) {
		if ([[favorites objectAtIndex:i] objectForKey:@"headerOfFileURL"] 
				&& [[[favorites objectAtIndex:i] objectForKey:@"headerOfFileURL"] isEqualToString:fileURLstring]) {
			i++;
			break;
		}
		i++;
	}

	// Take all favorites until the next header or end of favorites
	for(i; i<[favorites count]; i++) {

		if(![[favorites objectAtIndex:i] objectForKey:@"headerOfFileURL"])
			[favs addObject:[favorites objectAtIndex:i]];
		else
			break;

	}

	return favs;
}

/**
 * This method is only implemented to be compatible with SPTextView.
 */
- (id)customQueryInstance
{
	return [tableDocumentInstance valueForKey:@"customQueryInstance"];
}

#pragma mark -
#pragma mark IBAction methods

/**
 * Adds/Inserts a query favorite
 */
- (IBAction)addQueryFavorite:(id)sender
{
	NSMutableDictionary *favorite;
	NSUInteger insertIndex;

	// Store pending changes in Query
	[[self window] makeFirstResponder:favoriteNameTextField];

	// Duplicate a selected favorite if sender == self
	if (sender == self)
		favorite = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[favoriteNameTextField stringValue] stringByAppendingFormat:@" Copy"], [favoriteQueryTextView string], nil] forKeys:[NSArray arrayWithObjects:@"name", @"query", nil]];
	// Add a new favorite
	else
		favorite = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"New Favorite", @"", nil] forKeys:[NSArray arrayWithObjects:@"name", @"query", nil]];
	
	if ([favoritesTableView numberOfSelectedRows] > 0) {
		insertIndex = [[favoritesTableView selectedRowIndexes] lastIndex]+1;
		[favorites insertObject:favorite atIndex:insertIndex];
	} 
	else {
		[favorites addObject:favorite];
		insertIndex = [favorites count] - 1;
	}

	[favoritesArrayController rearrangeObjects];
	[favoritesTableView reloadData];

	[favoritesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:insertIndex] byExtendingSelection:NO];
	
	[favoritesTableView scrollRowToVisible:[favoritesTableView selectedRow]];

	[removeButton setEnabled:([favoritesTableView numberOfSelectedRows] > 0)];
	[[self window] makeFirstResponder:favoriteNameTextField];
}

/**
 * Duplicates a query favorite
 */
- (IBAction)duplicateQueryFavorite:(id)sender
{
	if ([favoritesTableView numberOfSelectedRows] == 1)
		[self addQueryFavorite:self];
	else
		NSBeep();
}

/**
 * Removes a query favorite
 */
- (IBAction)removeQueryFavorite:(id)sender
{
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Remove selected query favorites?", @"remove selected query favorites message") 
									 defaultButton:NSLocalizedString(@"Remove", @"remove button")
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to remove all selected query favorites? This action cannot be undone.", @"remove all selected query favorites informative message")];

	[alert setAlertStyle:NSCriticalAlertStyle];
	
	NSArray *buttons = [alert buttons];
	
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"r"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
	
	[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"removeSelectedFavorites"];
}

/**
 * Removes all query favorites
 */
- (IBAction)removeAllQueryFavorites:(id)sender
{
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Remove all query favorites?", @"remove all query favorites message") 
									 defaultButton:NSLocalizedString(@"Remove All", @"remove all button")
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to remove all of your saved query favorites? This action cannot be undone.", @"remove all query favorites informative message")];

	[alert setAlertStyle:NSCriticalAlertStyle];
	
	NSArray *buttons = [alert buttons];
	
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"r"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
	
	[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"removeAllFavorites"];
}

/**
 * Saves the currently selected query favorite to a user specified file.
 */
- (IBAction)saveFavoriteToFile:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setRequiredFileType:SPFileExtensionSQL];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:YES];
	[panel setCanSelectHiddenExtension:YES];
	[panel setCanCreateDirectories:YES];

	[panel setAccessoryView:[SPEncodingPopupAccessory encodingAccessory:[prefs integerForKey:SPLastSQLFileEncoding] includeDefaultEntry:NO encodingPopUp:&encodingPopUp]];
	
	[encodingPopUp setEnabled:YES];
	
	[panel beginSheetForDirectory:nil file:[favoriteNameTextField stringValue] modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:@"saveQuery"];
}

- (IBAction)exportFavorites:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setRequiredFileType:SPFileExtensionDefault];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:NO];
	[panel setCanSelectHiddenExtension:YES];
	[panel setCanCreateDirectories:YES];

	[panel beginSheetForDirectory:nil file:nil modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:@"exportFavorites"];
}

- (IBAction)importFavoritesByAdding:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanSelectHiddenExtension:YES];
	[panel setDelegate:self];
	[panel setCanChooseDirectories:NO];
	[panel setAllowsMultipleSelection:NO];
	// [panel setResolvesAliases:YES];
	
	[panel beginSheetForDirectory:nil 
						   file:@"" 
						  types:[NSArray arrayWithObjects:SPFileExtensionDefault, SPFileExtensionSQL, nil] 
				 modalForWindow:[self window]
				  modalDelegate:self 
				 didEndSelector:@selector(importPanelDidEnd:returnCode:contextInfo:) 
					contextInfo:NULL];
}

- (IBAction)importFavoritesByReplacing:(id)sender
{
	
}

/**
 * Insert placeholder - the placeholder string is stored as tooltip
 */
- (IBAction)insertPlaceholder:(id)sender
{
	NSString *placeholder = [[[sender selectedItem] toolTip] substringToIndex:[[[sender selectedItem] toolTip] rangeOfString:@" – "].location];
	[favoriteQueryTextView insertText:placeholder];
}

/**
 * Closes the query favorite manager
 */
- (IBAction)closeQueryManagerSheet:(id)sender
{

	// First check for ESC if pressed while inline editing
	if(![sender tag] && isTableCellEditing) {
		[favoritesTableView abortEditing];
		isTableCellEditing = NO;
		return;
	}

	[NSApp endSheet:[self window] returnCode:0];
	[[self window] orderOut:self];

	// "Apply Changes" button was pressed
	if([sender tag]) {

		// Ensure that last changes will be written back
		// if only one favorite is selected; otherwise unstable state
		if ([favoritesTableView numberOfSelectedRows] == 1) {
			[[self window] makeFirstResponder:favoritesTableView];
		}

		// Update current document's query favorites in the SPQueryController
		[[SPQueryController sharedQueryController] replaceFavoritesByArray:
			[self queryFavoritesForFileURL:delegatesFileURL] forFileURL:delegatesFileURL];

		// Update global preferences' list
		[prefs setObject:[self queryFavoritesForFileURL:nil] forKey:SPQueryFavorites];

		// Inform all opened documents to update the query favorites list
		for(id doc in [[NSApp delegate] orderedDocuments])
			if([[doc valueForKeyPath:@"customQueryInstance"] respondsToSelector:@selector(queryFavoritesHaveBeenUpdated:)])
				[[doc valueForKeyPath:@"customQueryInstance"] queryFavoritesHaveBeenUpdated:self];


	}

}

- (IBAction)showHelp:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:NSLocalizedString(@"http://www.sequelpro.com/docs/Query_Favorites", @"Localized help page for query favourites - do not localize if no translated webpage is available")]];
}

#pragma mark -
#pragma mark SplitView delegate methods

/**
 * Return the maximum possible size of the splitview.
 */
- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
	return (proposedMax - 240);
}

/**
 * Return the minimum possible size of the splitview.
 */
- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
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

	if([[aTableColumn identifier] isEqualToString:@"name"]) {
		if(![[favorites objectAtIndex:rowIndex] objectForKey:@"name"]) return @"";
		return [[favorites objectAtIndex:rowIndex] objectForKey:@"name"];
	} else if([[aTableColumn identifier] isEqualToString:@"tabtrigger"]) {
		if(![[favorites objectAtIndex:rowIndex] objectForKey:@"tabtrigger"] || ![(NSString*)[[favorites objectAtIndex:rowIndex] objectForKey:@"tabtrigger"] length]) return @"";
		return [NSString stringWithFormat:@"%@⇥", [[favorites objectAtIndex:rowIndex] objectForKey:@"tabtrigger"]];
	}
	return @"";
}

/*
 * Save favorite names if inline edited (suppress empty names)
 */
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{

	if([[aTableColumn identifier] isEqualToString:@"name"]) {
		if([anObject isKindOfClass:[NSString class]] && [(NSString *)anObject length]) {
			[[favorites objectAtIndex:rowIndex] setObject:anObject forKey:@"name"];
			// [[favorites objectAtIndex:rowIndex] setObject:[favoriteQueryTextView string] forKey:@"query"];
			[favoriteNameTextField setStringValue:anObject];
		}
	}

	[favoritesTableView reloadData];
}

/*
 * Before selecting an other favorite save pending query string changes
 * and make sure that no group table item can be selected
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
	return ([[favorites objectAtIndex:rowIndex] objectForKey:@"headerOfFileURL"]) ? NO : YES;
}

/*
 * Set indention levels for headers and favorites
 * (maybe in the future use an image for headers for expanding and collapsing)
 */
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if([[favorites objectAtIndex:rowIndex] objectForKey:@"headerOfFileURL"] && [[aTableColumn identifier] isEqualToString:@"name"]) {
		// if([[[favoriteProperties objectAtIndex:rowIndex] objectForKey:@"isGroup"] isEqualToString:@"1"])
		// 	[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"NSRightFacingTriangleTemplate"]];
		// else
		// 	[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"NSLeftFacingTriangleTemplate"]];
		[(ImageAndTextCell*)aCell setIndentationLevel:0];
	}
	else if(![[favorites objectAtIndex:rowIndex] objectForKey:@"headerOfFileURL"] && [[aTableColumn identifier] isEqualToString:@"name"]) {
		// [(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"dummy-small"]];
		[(ImageAndTextCell*)aCell setIndentationLevel:1];
	}
}

/*
 * A row of an header return is slighlty larger
 */
- (CGFloat)tableView:(NSTableView *)aTableView heightOfRow:(NSInteger)rowIndex
{
	return ([[favorites objectAtIndex:rowIndex] objectForKey:@"headerOfFileURL"]) ? 20 : 18;
}

/*
 * Only favorite name can be edited inline
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if([[favorites objectAtIndex:rowIndex] objectForKey:@"headerOfFileURL"]) {
		return NO;
	} else {
		isTableCellEditing = YES;
		return YES;
	}
}

/*
 * Sorting by clicking at a column header inside groups
 */
- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
	// TODO: Not yet implemented
	return;
}

/*
 * favoriteProperties holds the data if a table row is a group header or not
 */
- (BOOL)tableView:(NSTableView *)aTableView isGroupRow:(NSInteger)rowIndex
{
	return ([[favorites objectAtIndex:rowIndex] objectForKey:@"headerOfFileURL"]) ? YES : NO;
}
/*
 * Detect if inline editing was done - then ESC to close the sheet will be activate
 */ 
- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
	isTableCellEditing = NO;
}

/*
 * Changes in the name/tabtrigger text field will be saved in data source directly
 * to update the table view accordingly
 */
- (void)controlTextDidChange:(NSNotification *)notification
{

	// Do nothing if no favorite is selected
	if([favoritesTableView numberOfSelectedRows] < 1) return;

	id object = [notification object];

	if(object == favoriteNameTextField) {
		[[favorites objectAtIndex:[favoritesTableView selectedRow]] setObject:[favoriteNameTextField stringValue] forKey:@"name"];
		[favoritesTableView reloadData];
	} 
	else if(object == favoriteTabTriggerTextField){
		//Validate trigger - it only may contain alphnumeric characters
		NSString *tabTrigger = [NSString stringWithString:[[favoriteTabTriggerTextField stringValue] stringByReplacingOccurrencesOfRegex:@"(?i)[^[:L:]0-9]+" withString:@""]];
		[favoriteTabTriggerTextField setStringValue:tabTrigger];
		[[favorites objectAtIndex:[favoritesTableView selectedRow]] setObject:tabTrigger forKey:@"tabtrigger"];
		[favoritesTableView reloadData];
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
	
	if ( (action == @selector(duplicateQueryFavorite:))	|| 
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
- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rows toPasteboard:(NSPasteboard*)pboard
{

	NSArray *pboardTypes = [NSArray arrayWithObject:SPFavoritesPasteboardDragType];
	NSInteger originalRow = [rows firstIndex];

	if(originalRow < 1) return NO;

	// Do not drag headers
	if([[favorites objectAtIndex:originalRow] objectForKey:@"headerOfFileURL"]) return NO;

	[pboard declareTypes:pboardTypes owner:nil];

	NSMutableData *indexdata = [[[NSMutableData alloc] init] autorelease];
	NSKeyedArchiver *archiver = [[[NSKeyedArchiver alloc] initForWritingWithMutableData:indexdata] autorelease];
	[archiver encodeObject:rows forKey:@"indexdata"];
	[archiver finishEncoding];
	[pboard setData:indexdata forType:SPFavoritesPasteboardDragType];

	return YES;

}

/**
 * Validate the proposed drop of the supplied rows.
 */
- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{	
	NSArray *pboardTypes = [[info draggingPasteboard] types];
	
	if (([pboardTypes count] > 1) && (row != -1)) {
		if (([pboardTypes containsObject:SPFavoritesPasteboardDragType]) && (operation == NSTableViewDropAbove)) {
			if (row > 0) {
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

	if(row < 1) return NO;

	NSKeyedUnarchiver *unarchiver = [[[NSKeyedUnarchiver alloc] initForReadingWithData:[[info draggingPasteboard] dataForType:SPFavoritesPasteboardDragType]] autorelease];
	NSIndexSet *draggedIndexes = [[NSIndexSet alloc] initWithIndexSet:(NSIndexSet *)[unarchiver decodeObjectForKey:@"indexdata"]];
	[unarchiver finishDecoding];

	// TODO: still rely on a NSArray but in the future rewrite it to use the NSIndexSet directly
	NSMutableArray *draggedRows = [[NSMutableArray alloc] initWithCapacity:1];
	NSUInteger rowIndex = [draggedIndexes firstIndex];
	while ( rowIndex != NSNotFound ) {
		[draggedRows addObject:[NSNumber numberWithInteger:rowIndex]];
		rowIndex = [draggedIndexes indexGreaterThanIndex: rowIndex];
	}

	NSInteger destinationRow = row;
	NSInteger offset = 0;

	NSUInteger i;

	for(i=0; i<[draggedRows count]; i++) {

		NSInteger originalRow = [[draggedRows objectAtIndex:i] integerValue];

		if(originalRow < destinationRow) destinationRow--;

		originalRow += offset;

		// For safety reasons
		if(originalRow > [favorites count]-1) originalRow = [favorites count] - 1;

		NSMutableDictionary *draggedRow = [NSMutableDictionary dictionaryWithDictionary:[favorites objectAtIndex:originalRow]];
		[favorites removeObjectAtIndex:originalRow];
		[favoritesTableView reloadData];

		if(destinationRow+i >= [favorites count])
			[favorites addObject:draggedRow];
		else
			[favorites insertObject:draggedRow atIndex:destinationRow+i];

		if(originalRow < row) offset--;

	}

	[favoritesTableView reloadData];
	[favoritesArrayController rearrangeObjects];
	[draggedIndexes release];
	[draggedRows release];

	return YES;
}

#pragma mark -
#pragma mark Other

/**
 * Sheet did end method
 */
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	// Is disabled - do we need that?
	// if ([contextInfo isEqualToString:@"removeAllFavorites"]) {
	// 	if (returnCode == NSAlertAlternateReturn) {
	// 		[favorites removeObjects:[queryFavoritesController arrangedObjects]];
	// 	}
	// }
	if([contextInfo isEqualToString:@"removeSelectedFavorites"]) {
		if (returnCode == NSAlertDefaultReturn) {
			NSIndexSet *indexes = [favoritesTableView selectedRowIndexes];

			// get last index
			NSUInteger currentIndex = [indexes lastIndex];

			while (currentIndex != NSNotFound) {
				[favorites removeObjectAtIndex:currentIndex];
				// get next index (beginning from the end)
				currentIndex = [indexes indexLessThanIndex:currentIndex];
			}

			[favoritesArrayController rearrangeObjects];
			[favoritesTableView reloadData];

			// Set focus to favorite list to avoid an unstable state
			[[self window] makeFirstResponder:favoritesTableView];

			[removeButton setEnabled:([favoritesTableView numberOfSelectedRows] > 0)];
		}
	}
}

/**
 * Import panel did end method.
 */
- (void)importPanelDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{

	if (returnCode == NSOKButton) {

		NSString *filename = [[panel filenames] objectAtIndex:0];
		NSError *readError = nil;
		NSString *convError = nil;
		NSPropertyListFormat format;

		NSDictionary *spf = nil;

		if([[[filename pathExtension] lowercaseString] isEqualToString:SPFileExtensionDefault]) {
			NSData *pData = [NSData dataWithContentsOfFile:filename options:NSUncachedRead error:&readError];

			spf = [[NSPropertyListSerialization propertyListFromData:pData 
					mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError] retain];

			if(!spf || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {
				NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while reading data file", @"error while reading data file")]
												 defaultButton:NSLocalizedString(@"OK", @"OK button") 
											   alternateButton:nil 
												  otherButton:nil 
									informativeTextWithFormat:NSLocalizedString(@"File couldn't be read.", @"error while reading data file")];

				[alert setAlertStyle:NSCriticalAlertStyle];
				[alert runModal];
				if (spf) [spf release];
				return;
			}

			if([spf objectForKey:SPQueryFavorites] && [[spf objectForKey:SPQueryFavorites] count]) {
				// if([favoritesTableView numberOfSelectedRows] > 0) {
				// 	// Insert imported queries after the last selected favorite
				// 	NSUInteger insertIndex = [[favoritesTableView selectedRowIndexes] lastIndex] + 1;
				// 	NSUInteger i;
				// 	for(i=0; i<[[spf objectForKey:SPQueryFavorites] count]; i++) {
				// 		[favorites insertObject:[[spf objectForKey:SPQueryFavorites] objectAtIndex:i] atIndex:insertIndex+i];
				// 	}
				// } else {
				// 	// If no selection add them
				[favorites addObjectsFromArray:[spf objectForKey:SPQueryFavorites]];
				// }
				[favoritesArrayController rearrangeObjects];
				[favoritesTableView reloadData];
				[spf release];
			} else {
				NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while reading data file", @"error while reading data file")]
												 defaultButton:NSLocalizedString(@"OK", @"OK button") 
											   alternateButton:nil 
												  otherButton:nil 
									informativeTextWithFormat:NSLocalizedString(@"No query favorites found.", @"error that no query favorites found")];

				[alert setAlertStyle:NSInformationalAlertStyle];
				[alert runModal];
				[spf release];
				return;
			}
		}
	}
}


/**
 * Save panel did end method.
 */
- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{

	if([contextInfo isEqualToString:@"saveQuery"]) {
		if (returnCode == NSOKButton) {
			NSError *error = nil;
		
			[prefs setInteger:[[encodingPopUp selectedItem] tag] forKey:SPLastSQLFileEncoding];
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

	
			[spfdata setObject:[NSNumber numberWithInteger:1] forKey:@"version"];
			[spfdata setObject:@"query favorites" forKey:@"format"];
			[spfdata setObject:[NSNumber numberWithBool:NO] forKey:@"encrypted"];

			NSIndexSet *indexes = [favoritesTableView selectedRowIndexes];

			// Get selected items and preserve the order
			NSUInteger i;
			for (i=1; i<[favorites count]; i++)
				if([indexes containsIndex:i])
					[favoriteData addObject:[favorites objectAtIndex:i]];

			[spfdata setObject:favoriteData forKey:SPQueryFavorites];
			
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

- (void)_initWithNoSelection
{
	[favoritesTableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
	[[favoriteNameTextField cell] setPlaceholderString:SP_NO_SELECTION_PLACEHOLDER_STRING];
	[favoriteNameTextField setStringValue:@""];
	[favoriteQueryTextView setString:@""];
}

@end
