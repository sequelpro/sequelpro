//
//  SPQueryFavoriteManager.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Aug 23, 2009.
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

#import "SPQueryFavoriteManager.h"
#import "ImageAndTextCell.h"
#import "SPEncodingPopupAccessory.h"
#import "SPQueryController.h"
#import "SPDatabaseDocument.h"
#import "SPConnectionController.h"
#import "RegexKitLite.h"
#import "SPTextView.h"
#import "SPSplitView.h"
#import "SPAppController.h"

#define SP_MULTIPLE_SELECTION_PLACEHOLDER_STRING NSLocalizedString(@"[multiple selection]", @"[multiple selection]")
#define SP_NO_SELECTION_PLACEHOLDER_STRING       NSLocalizedString(@"[no selection]", @"[no selection]")

@interface SPQueryFavoriteManager ()

- (void)_initWithNoSelection;

@end

@implementation SPQueryFavoriteManager

/**
 * Initialize the manager with the supplied delegate.
 */
- (id)initWithDelegate:(id)managerDelegate
{
	if ((self = [super initWithWindowNibName:@"QueryFavoriteManager"])) {

#ifndef SP_CODA
		prefs = [NSUserDefaults standardUserDefaults];
#endif

		favorites = [[NSMutableArray alloc] init];
		
		if(managerDelegate == nil) {
			NSBeep();
			NSLog(@"Query Favorite Manager was called without a delegate.");
			return nil;
		}
		tableDocumentInstance = [managerDelegate valueForKeyPath:@"tableDocumentInstance"];
#ifndef SP_CODA
		delegatesFileURL = [tableDocumentInstance fileURL];
#endif
	}
	
	return self;
}

/**
 * Upon awakening bind the query text view's background colour.
 */
- (void)awakeFromNib
{
#ifndef SP_CODA
	[favorites addObject:@{
			@"name"            : @"Global",
			@"headerOfFileURL" : @"",
			@"query"           : @""
	}];

	// Set up the split view
	[favoritesSplitView setMinSize:152.f ofSubviewAtIndex:0];
	[favoritesSplitView setMinSize:385.f ofSubviewAtIndex:1];

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
	[favoritesTableView registerForDraggedTypes:@[SPFavoritesPasteboardDragType]];
	
	[favoritesArrayController setContent:favorites];
	[favoritesTableView reloadData];

	// Set Remove button state
	[removeButton setEnabled:([favoritesTableView numberOfSelectedRows] > 0)];
#endif
}

#pragma mark -
#pragma mark Accessor methods

/**
 * Returns the query favorites array for fileURL.
 * fileURL == nil → global favorites
 */
#ifndef SP_CODA
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
	for( ; i<[favorites count]; i++) {

		if(![[favorites objectAtIndex:i] objectForKey:@"headerOfFileURL"])
			[favs addObject:[favorites objectAtIndex:i]];
		else
			break;

	}

	return favs;
}
#endif

/**
 * This method is only implemented to be compatible with SPTextView.
 */
- (id)customQueryInstance
{
	return [tableDocumentInstance customQueryInstance];
}

#pragma mark -
#pragma mark IBAction methods

/**
 * Adds/Inserts a query favorite
 */
- (IBAction)addQueryFavorite:(id)sender
{
#ifndef SP_CODA 
	NSMutableDictionary *favorite;
	NSUInteger insertIndex;

	// Store pending changes in Query
	[[self window] makeFirstResponder:favoriteNameTextField];

	// Duplicate a selected favorite if sender == self
	if (sender == self) {
		favorite = [NSMutableDictionary dictionaryWithDictionary:@{
			@"name":  [NSString stringWithFormat:NSLocalizedString(@"%@ Copy", @"query favorite manager : duplicate favorite : new favorite name"),[favoriteNameTextField stringValue]],
			@"query": [NSString stringWithString:[favoriteQueryTextView string]] // #2938 - without copying the string we would store the live NS*MutableString object that backs the text view and changes its contents when selection changes!
		}];
	}
	// Add a new favorite
	else {
		favorite = [NSMutableDictionary dictionaryWithDictionary:@{
			@"name":  NSLocalizedString(@"New Favorite",@"query favorite manager : new favorite : name"),
			@"query": @""
		}];
	}
	
	// If a favourite is currently selected, add the new favourite next to it
	if ([favoritesTableView numberOfSelectedRows] > 0) {
		insertIndex = [[favoritesTableView selectedRowIndexes] lastIndex]+1;
		[favorites insertObject:favorite atIndex:insertIndex];
	} 

	// If the DatabaseDocument is an on-disk document, add the favourite to the bottom of it
	else if (![tableDocumentInstance isUntitled]) {
		insertIndex = [favorites count] - 1;
		[favorites addObject:favorite];
	}

	// Otherwise, add to the bottom of the Global array by default
	else {
		insertIndex = 1;
		while (![[favorites objectAtIndex:insertIndex] objectForKey:@"headerOfFileURL"]) {
			insertIndex++;
		}
		[favorites insertObject:favorite atIndex:insertIndex];
	}

	[favoritesArrayController rearrangeObjects];
	[favoritesTableView reloadData];

	[favoritesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:insertIndex] byExtendingSelection:NO];
	
	[favoritesTableView scrollRowToVisible:[favoritesTableView selectedRow]];

	[removeButton setEnabled:([favoritesTableView numberOfSelectedRows] > 0)];
	[[self window] makeFirstResponder:favoriteNameTextField];
#endif
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
	//sender can be a NSButton or a NSMenuItem
	
	// Complete editing in the window
	[[self window] makeFirstResponder:[self window]];

	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Remove selected query favorites?", @"remove selected query favorites message") 
									 defaultButton:NSLocalizedString(@"Remove", @"remove button")
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to remove all selected query favorites? This action cannot be undone.", @"remove all selected query favorites informative message")];

	[alert setAlertStyle:NSCriticalAlertStyle];
	
	NSArray *buttons = [alert buttons];
	
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"r"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
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
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
	
	[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"removeAllFavorites"];
}

/**
 * Saves the currently selected query favorite to a user specified file.
 */
- (IBAction)saveFavoriteToFile:(id)sender
{
#ifndef SP_CODA
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setAllowedFileTypes:@[SPFileExtensionSQL]];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:YES];
	[panel setCanSelectHiddenExtension:YES];
	[panel setCanCreateDirectories:YES];

	[panel setAccessoryView:[SPEncodingPopupAccessory encodingAccessory:[prefs integerForKey:SPLastSQLFileEncoding] includeDefaultEntry:NO encodingPopUp:&encodingPopUp]];
	
	[encodingPopUp setEnabled:YES];

	[panel setNameFieldStringValue:[favoriteNameTextField stringValue]];

	[panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger returnCode)
	{
		[self savePanelDidEnd:panel returnCode:returnCode contextInfo:@"saveQuery"];
	}];
#endif
}

- (IBAction)exportFavorites:(id)sender
{
#ifndef SP_CODA
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setAllowedFileTypes:@[SPFileExtensionDefault]];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:NO];
	[panel setCanSelectHiddenExtension:YES];
	[panel setCanCreateDirectories:YES];

	[panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger returnCode)
	{
		[self savePanelDidEnd:panel returnCode:returnCode contextInfo:@"exportFavorites"];
	}];
#endif
}

- (IBAction)importFavoritesByAdding:(id)sender
{
#ifndef SP_CODA
	NSOpenPanel *panel = [NSOpenPanel openPanel];

	[panel setCanSelectHiddenExtension:YES];
	[panel setDelegate:self];
	[panel setCanChooseDirectories:NO];
	[panel setAllowsMultipleSelection:NO];

	[panel setAllowedFileTypes:@[SPFileExtensionDefault, SPFileExtensionSQL]];

	[panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger returnCode)
	{
		[self importPanelDidEnd:panel returnCode:returnCode contextInfo:NULL];
	}];
#endif
}

- (IBAction)importFavoritesByReplacing:(id)sender
{
	
}

/**
 * Insert placeholder - the placeholder string is stored as tooltip
 */
- (IBAction)insertPlaceholder:(id)sender
{
	// Look up the sender's tag to determine the placeholder to insert.
	// Note that tag values alter behaviour slightly - see below.
	NSDictionary *lookupTable = @{
			@100 : NSLocalizedString(@"default_value", @"Query snippet default value placeholder"),
			@101 : NSLocalizedString(@"$(shell_command)", @"Query snippet shell command syntax and placeholder"),
			@501 : @"$1",
			@102 : @"¦a¦b¦",
			@103 : @"¦¦a¦b¦¦",
			@104 : @"¦",
			@105 : @"$SP_SELECTED_TABLE",
			@106 : @"$SP_SELECTED_TABLES",
			@107 : @"$SP_SELECTED_DATABASE",
			@108 : @"¦$SP_ASLIST_ALL_FIELDS¦",
			@109 : @"¦¦$SP_ASLIST_ALL_FIELDS¦¦",
			@110 : @"¦$SP_ASLIST_ALL_TABLES¦",
			@111 : @"¦¦$SP_ASLIST_ALL_TABLES¦¦",
			@112 : @"¦$SP_ASLIST_ALL_DATABASES¦",
			@113 : @"¦¦$SP_ASLIST_ALL_DATABASES¦¦"
	};
	NSString *placeholder = [lookupTable objectForKey:[NSNumber numberWithInteger:[[sender selectedItem] tag]]];
	if (!placeholder) [NSException raise:NSInternalInconsistencyException format:@"Inserted placeholder (%lld) not found", (long long)[[sender selectedItem] tag]];

	// Iterate through the current snippets, to get the lowest unused tab counter, and
	// to determine whether the current selection is inside a tab snippet or not
	NSMutableDictionary *snippetNumbers = [NSMutableDictionary dictionary];
	BOOL selectionInsideSnippet = NO;
	NSUInteger rangeStart = 0;
	NSString *queryString = [[favoriteQueryTextView textStorage] string];
	NSRange selRange = [favoriteQueryTextView selectedRange];
	NSString *snipRegex = @"(?s)(?<!\\\\)\\$\\{(1?\\d):(.{0}|[^\\{\\}]*?[^\\\\])\\}";
	while (true) {
		NSRange matchedRange = [queryString rangeOfRegex:snipRegex inRange:NSMakeRange(rangeStart, [queryString length] - rangeStart)];
		if (matchedRange.location == NSNotFound) break;

		// Check whether the selection range lies within the snippet
		if (selRange.location != NSNotFound
			&& selRange.location > matchedRange.location + 1
			&& NSMaxRange(selRange) < NSMaxRange(matchedRange))
		{
			selectionInsideSnippet = YES;
		}

		// Identify the tab completion index
		NSRange snippetNumberRange = [queryString rangeOfRegex:snipRegex options:RKLNoOptions inRange:matchedRange capture:1L error:NULL];
		NSInteger snippetNumber = [[queryString substringWithRange:snippetNumberRange] integerValue];
		[snippetNumbers setObject:@YES forKey:[NSNumber numberWithInteger:snippetNumber]];

		rangeStart = NSMaxRange(matchedRange);
	}

	// If the selection is not inside a snippet, wrap it inside the snippet syntax.
	// Never do this for items with a tag above 500: these are not permitted inside a snippet.
	if (!selectionInsideSnippet && [[sender selectedItem] tag] < 500) {

		// Work out the lowest unused tab counter to use
		NSInteger snippetNumber = 0;
		while ([snippetNumbers objectForKey:[NSNumber numberWithInteger:snippetNumber]]) {
			snippetNumber++;
		}

		placeholder = [NSString stringWithFormat:@"${%lld:%@}", (long long)snippetNumber, placeholder];
	}

	[favoriteQueryTextView insertText:placeholder];
}

/**
 * Closes the query favorite manager
 */
- (IBAction)closeQueryManagerSheet:(id)sender
{
#ifndef SP_CODA

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
		[[NSNotificationCenter defaultCenter] postNotificationName:SPQueryFavoritesHaveBeenUpdatedNotification object:self];
	}
#endif

}

#ifndef SP_CODA
- (IBAction)showHelp:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:NSLocalizedString(@"http://www.sequelpro.com/docs/Working_with_Query_Favorites", @"Localized help page for query favourites - do not localize if no translated webpage is available")]];
}
#endif

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
	if (rowIndex == -1) return YES;
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
	// TODO: Implement me
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

	NSArray *pboardTypes = @[SPFavoritesPasteboardDragType];
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
	[draggedIndexes enumerateIndexesUsingBlock:^(NSUInteger rowIndex, BOOL * _Nonnull stop) {
		[draggedRows addObject:[NSNumber numberWithUnsignedInteger:rowIndex]];
	}];

	NSInteger destinationRow = row;
	NSInteger offset = 0;

	NSUInteger i;

	for(i=0; i<[draggedRows count]; i++) {

		NSInteger originalRow = [[draggedRows objectAtIndex:i] integerValue];

		if(originalRow < destinationRow) destinationRow--;

		originalRow += offset;

		// For safety reasons
		if(originalRow > (NSInteger)[favorites count]-1) originalRow = [favorites count] - 1;

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

			[indexes enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger currentIndex, BOOL * _Nonnull stop) {
				[favorites removeObjectAtIndex:currentIndex];
			}];

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
#ifndef SP_CODA

	if (returnCode == NSOKButton) {

		NSString *filename = [[[panel URLs] objectAtIndex:0] path];
		NSError *readError = nil;
		NSInteger insertionIndexStart, insertionIndexEnd;

		NSDictionary *spf = nil;

		if([[[filename pathExtension] lowercaseString] isEqualToString:SPFileExtensionDefault]) {
			NSData *pData = [NSData dataWithContentsOfFile:filename options:NSUncachedRead error:&readError];

			if(pData && !readError) {
				spf = [[NSPropertyListSerialization propertyListWithData:pData
																 options:NSPropertyListImmutable
																  format:NULL
																   error:&readError] retain];
			}
			
			if(!spf || readError) {
				NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error while reading data file", @"error while reading data file")
												 defaultButton:NSLocalizedString(@"OK", @"OK button") 
											   alternateButton:nil 
												   otherButton:nil
									 informativeTextWithFormat:NSLocalizedString(@"File couldn't be read. (%@)", @"error while reading data file"), [readError localizedDescription]];

				[alert setAlertStyle:NSCriticalAlertStyle];
				[alert runModal];
				if (spf) [spf release];
				return;
			}

			if([spf objectForKey:SPQueryFavorites] && [[spf objectForKey:SPQueryFavorites] count]) {

				// If the DatabaseDocument is an on-disk document, add the favourites to the bottom of it
				if (![tableDocumentInstance isUntitled]) {
					insertionIndexStart = [favorites count];
					[favorites addObjectsFromArray:[spf objectForKey:SPQueryFavorites]];
					insertionIndexEnd = [favorites count] - 1;
				}

				// Otherwise, add to the bottom of the Global array
				else {
					NSUInteger i, l;
					insertionIndexStart = 1;
					while (![[favorites objectAtIndex:insertionIndexStart] objectForKey:@"headerOfFileURL"]) {
						insertionIndexStart++;
					}
					for (i = 0, l = [[spf objectForKey:SPQueryFavorites] count]; i < l; i++) {
				 		[favorites insertObject:[[spf objectForKey:SPQueryFavorites] objectAtIndex:i] atIndex:insertionIndexStart + i];
					}
					insertionIndexEnd = insertionIndexStart + i;
				}

				[favoritesArrayController rearrangeObjects];
				[favoritesTableView reloadData];
				[favoritesTableView selectRowIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(insertionIndexStart, insertionIndexEnd - insertionIndexStart)] byExtendingSelection:NO];
				[favoritesTableView scrollRowToVisible:insertionIndexEnd];
				[spf release];
			} else {
				NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithString:NSLocalizedString(@"Error while reading data file", @"error while reading data file")]
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
#endif
}

/**
 * Save panel did end method.
 */
- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
#ifndef SP_CODA

	if([contextInfo isEqualToString:@"saveQuery"]) {
		if (returnCode == NSOKButton) {
			NSError *error = nil;
		
			[prefs setInteger:[[encodingPopUp selectedItem] tag] forKey:SPLastSQLFileEncoding];
			[prefs synchronize];
		
			[[favoriteQueryTextView string] writeToURL:[panel URL] atomically:YES encoding:[[encodingPopUp selectedItem] tag] error:&error];
		
			if (error) [[NSAlert alertWithError:error] runModal];
		}
	}
	else if([contextInfo isEqualToString:@"exportFavorites"]) {
		if (returnCode == NSOKButton) {

			// Build a SPF with format = "query favorites"
			NSMutableDictionary *spfdata = [NSMutableDictionary dictionary];
			NSMutableArray *favoriteData = [NSMutableArray array];

	
			[spfdata setObject:@1 forKey:SPFVersionKey];
			[spfdata setObject:SPFQueryFavoritesContentType forKey:SPFFormatKey];
			[spfdata setObject:@NO forKey:@"encrypted"];

			NSIndexSet *indexes = [favoritesTableView selectedRowIndexes];

			// Get selected items and preserve the order
			NSUInteger i;
			for (i=1; i<[favorites count]; i++)
				if([indexes containsIndex:i])
					[favoriteData addObject:[favorites objectAtIndex:i]];

			[spfdata setObject:favoriteData forKey:SPQueryFavorites];
			
			NSError *error = nil;
			
			NSData *plist = [NSPropertyListSerialization dataWithPropertyList:spfdata
																	   format:NSPropertyListXMLFormat_v1_0
																	  options:0
																		error:&error];

			if(error) {
				NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error while converting query favorite data", @"error while converting query favorite data")
												 defaultButton:NSLocalizedString(@"OK", @"OK button") 
											   alternateButton:nil 
												   otherButton:nil
									 informativeTextWithFormat:@"%@", [error localizedDescription]];

				[alert setAlertStyle:NSCriticalAlertStyle];
				[alert runModal];
				return;
			}

			[plist writeToURL:[panel URL] options:NSAtomicWrite error:&error];
			if (error) [[NSAlert alertWithError:error] runModal];

		}
	}
#endif
}

#pragma mark -
#pragma mark Private API

- (void)_initWithNoSelection
{
	[favoritesTableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
	[[favoriteNameTextField cell] setPlaceholderString:SP_NO_SELECTION_PLACEHOLDER_STRING];
	[favoriteNameTextField setStringValue:@""];
	[favoriteQueryTextView setString:@""];
}

#pragma mark -

- (void)dealloc
{
	SPClear(favorites);
	
	[super dealloc];
}

@end
