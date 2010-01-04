//
//  $Id$
//
//  SPContentFilterManager.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on Sep 29, 2009
//  Copyright (c) 2009 Hans-Jörg Bibiko. All rights reserved.
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

#import "SPContentFilterManager.h"
#import "ImageAndTextCell.h"
#import "RegexKitLite.h"
#import "SPQueryController.h"
#import "TableContent.h"
#import "SPConstants.h"
#import "SPConnectionController.h"

#define SP_MULTIPLE_SELECTION_PLACEHOLDER_STRING NSLocalizedString(@"[multiple selection]", @"[multiple selection]")
#define SP_NO_SELECTION_PLACEHOLDER_STRING NSLocalizedString(@"[no selection]", @"[no selection]")

@interface SPContentFilterManager (Private)
- (void)_initWithNoSelection;
@end

@implementation SPContentFilterManager

/**
 * Initialize the manager with the supplied delegate
 */
- (id)initWithDelegate:(id)managerDelegate forFilterType:(NSString *)compareType
{
	if ((self = [super initWithWindowNibName:@"ContentFilterManager"])) {

		prefs = [NSUserDefaults standardUserDefaults];

		contentFilters = [[NSMutableArray alloc] init];
		
		if(managerDelegate == nil) {
			NSBeep();
			NSLog(@"ContentFilterManager was called without a delegate.");
			return nil;
		}
		delegatesFileURL = [[managerDelegate valueForKeyPath:@"tableDocumentInstance"] fileURL];

		filterType = [NSString stringWithString:compareType];

	}
	
	return self;
}

- (void)dealloc
{
	[contentFilters release];
	[super dealloc];
}

/**
 * Upon awakening bind the query text view's background colour.
 */
- (void)awakeFromNib
{
	[contentFilterTextView setAllowsDocumentBackgroundColorChange:YES];
	
	NSMutableDictionary *bindingOptions = [NSMutableDictionary dictionary];
	
	[bindingOptions setObject:NSUnarchiveFromDataTransformerName forKey:@"NSValueTransformerName"];
	
	[contentFilterTextView bind:@"backgroundColor"
					   toObject:[NSUserDefaultsController sharedUserDefaultsController]
					withKeyPath:@"values.CustomQueryEditorBackgroundColor"
						options:bindingOptions];


	[contentFilters addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			@"Global", @"MenuLabel", 
			@"", @"headerOfFileURL",
			@"", @"Clause",
			@"", @"ConjunctionLabel",
			nil]];

	// Build data source for global content filter (as mutable copy! otherwise each
	// change will be stored in the prefs at once)
	if([[prefs objectForKey:SPContentFilters] objectForKey:filterType]) {
		for(id fav in [[prefs objectForKey:SPContentFilters] objectForKey:filterType]) {
			id f = [[fav mutableCopy] autorelease];
			if([f objectForKey:@"ConjunctionLabels"])
				[f setObject:[[f objectForKey:@"ConjunctionLabels"] objectAtIndex:0] forKey:@"ConjunctionLabel"];
			[contentFilters addObject:f];
		}
	}

	// Build doc-based filters
	[contentFilters addObject:[NSDictionary dictionaryWithObjectsAndKeys:
		[[[delegatesFileURL absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] lastPathComponent], @"MenuLabel", 
		[delegatesFileURL absoluteString], @"headerOfFileURL", 
		@"", @"Clause",
		nil]];
	if([[SPQueryController sharedQueryController] contentFilterForFileURL:delegatesFileURL]) {
		id filters = [[SPQueryController sharedQueryController] contentFilterForFileURL:delegatesFileURL];
		if([filters objectForKey:filterType])
			for(id fav in [filters objectForKey:filterType])
				[contentFilters addObject:[[fav mutableCopy] autorelease]];
	}


	// Select the first query if any
	NSUInteger i = 0;
	for(i=0; i < [contentFilters count]; i++ )
		if(![[contentFilters objectAtIndex:i] objectForKey:@"headerOfFileURL"])
			break;

	[[self window] makeFirstResponder:contentFilterTableView];
	[self _initWithNoSelection];

	// Register drag types
	[contentFilterTableView registerForDraggedTypes:[NSArray arrayWithObject:SPContentFilterPasteboardDragType]];
	
	[contentFilterArrayController setContent:contentFilters];
	[contentFilterTableView reloadData];

	// Set Remove button state
	[removeButton setEnabled:([contentFilterTableView numberOfSelectedRows] > 0)];

	// Set column header
	[[[contentFilterTableView tableColumnWithIdentifier:@"MenuLabel"] headerCell] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"‘%@’ Fields Content Filters", @"content filter for field type ‘%@’"), filterType]];

	// Set the button delegate 
	[splitViewButtonBar setSplitViewDelegate:self];
}

#pragma mark -
#pragma mark Accessor methods

/**
 * Returns the content filters array for fileURL.
 * fileURL == nil → global content filters
 */
- (NSMutableArray *)contentFilterForFileURL:(NSURL *)fileURL
{
	NSMutableArray *filters = [NSMutableArray array];
	NSString *fileURLstring;

	if(fileURL == nil)
		fileURLstring = @"";
	else
		fileURLstring = [fileURL absoluteString];

	NSUInteger i = 0;

	// Look for the header specified by fileURL
	while(i<[contentFilters count]) {
		if ([[contentFilters objectAtIndex:i] objectForKey:@"headerOfFileURL"] 
				&& [[[contentFilters objectAtIndex:i] objectForKey:@"headerOfFileURL"] isEqualToString:fileURLstring]) {
			i++;
			break;
		}
		i++;
	}

	// Take all content filters until the next header or end of all content filters
	NSUInteger numOfArgs;
	for(i; i<[contentFilters count]; i++) {

		if(![[contentFilters objectAtIndex:i] objectForKey:@"headerOfFileURL"]) {
			NSMutableDictionary *d = [[NSMutableDictionary alloc] init];
			[d setDictionary:[contentFilters objectAtIndex:i]];
			NSMutableArray *conjLabel = [[NSMutableArray alloc] init];
			numOfArgs = [[[d objectForKey:@"Clause"] componentsMatchedByRegex:@"(?<!\\\\)(\\$\\{.*?\\})"] count];
			if(numOfArgs > 1) {
				if([d objectForKey:@"ConjunctionLabel"]) {
					[conjLabel addObject:[d objectForKey:@"ConjunctionLabel"]];
					[d setObject:conjLabel forKey:@"ConjunctionLabels"];
				}
			} else {
				[d removeObjectForKey:@"ConjunctionLabels"];
			}
			[d removeObjectForKey:@"ConjunctionLabel"];
			[conjLabel release];
			[d setObject:[NSNumber numberWithInteger:numOfArgs] forKey:@"NumberOfArguments"];
			[filters addObject:d];
			[d release];
		} else
			break;

	}

	return filters;
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
 * Adds/Inserts a content filter
 */
- (IBAction)addContentFilter:(id)sender
{

	NSMutableDictionary *filter;
	NSUInteger insertIndex;

	// Store pending changes in Clause
	[[self window] makeFirstResponder:contentFilterNameTextField];

	// Duplicate a selected filter if sender == self
	if(sender == self)
		filter = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[contentFilterNameTextField stringValue] stringByAppendingFormat:@" Copy"], [contentFilterTextView string], nil] forKeys:[NSArray arrayWithObjects:@"MenuLabel", @"Clause", nil]];
	// Add a new filter
	else
		filter = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"New Filter", @"", @"", nil] forKeys:[NSArray arrayWithObjects:@"MenuLabel", @"Clause", @"ConjunctionLabel", nil]];

	if([contentFilterTableView numberOfSelectedRows] > 0) {
		insertIndex = [[contentFilterTableView selectedRowIndexes] lastIndex]+1;
		[contentFilters insertObject:filter atIndex:insertIndex];
	} else {
		[contentFilters addObject:filter];
		insertIndex = [contentFilters count] - 1;
	}

	[contentFilterArrayController rearrangeObjects];
	[contentFilterTableView reloadData];

	[contentFilterTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:insertIndex] byExtendingSelection:NO];
	
	[contentFilterTableView scrollRowToVisible:[contentFilterTableView selectedRow]];

	[removeButton setEnabled:([contentFilterTableView numberOfSelectedRows] > 0)];
	[[self window] makeFirstResponder:contentFilterNameTextField];

}

/**
 * Duplicates a filter
 */
- (IBAction)duplicateContentFilter:(id)sender
{
	if ([contentFilterTableView numberOfSelectedRows] == 1)
		[self addContentFilter:self];
	else
		NSBeep();
}

/**
 * Removes a filter
 */
- (IBAction)removeContentFilter:(id)sender
{
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Remove selected content filters?", @"remove selected content filters message") 
									 defaultButton:NSLocalizedString(@"Remove", @"remove button")
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to remove all selected content filters? This action cannot be undone.", @"remove all selected content filters informative message")];

	[alert setAlertStyle:NSCriticalAlertStyle];
	
	NSArray *buttons = [alert buttons];
	
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"r"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
	
	[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"removeSelectedFilters"];
}

/**
 * Insert placeholder - the placeholder string is stored as tooltip
 */
- (IBAction)insertPlaceholder:(id)sender
{
	[contentFilterTextView insertText:[[[sender selectedItem] toolTip] substringToIndex:[[[sender selectedItem] toolTip] rangeOfString:@" – "].location]];
}

- (IBAction)exportContentFilter:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setRequiredFileType:SPFileExtensionDefault];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:NO];
	[panel setCanSelectHiddenExtension:YES];
	[panel setCanCreateDirectories:YES];

	[panel beginSheetForDirectory:nil file:nil modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:@"exportFilter"];
}

- (IBAction)importContentFilterByAdding:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanSelectHiddenExtension:YES];
	[panel setDelegate:self];
	[panel setCanChooseDirectories:NO];
	[panel setAllowsMultipleSelection:NO];
	[panel setResolvesAliases:YES];
	
	[panel beginSheetForDirectory:nil 
						   file:@"" 
						  types:[NSArray arrayWithObjects:SPFileExtensionDefault, nil] 
				 modalForWindow:[self window]
				  modalDelegate:self 
				 didEndSelector:@selector(importPanelDidEnd:returnCode:contextInfo:) 
					contextInfo:NULL];
}

- (IBAction)importFavoritesByReplacing:(id)sender
{
	
}

/**
 * Closes the content filter manager
 */
- (IBAction)closeContentFilterManagerSheet:(id)sender
{

	// First check for ESC if pressed while inline editing
	if(![sender tag] && isTableCellEditing) {
		[contentFilterTableView abortEditing];
		isTableCellEditing = NO;
		return;
	}

	[NSApp endSheet:[self window] returnCode:0];
	[[self window] orderOut:self];

	// "Apply Changes" button was pressed
	if([sender tag]) {

		// Ensure that last changes will be written back
		// if only one filter is selected; otherwise unstable state
		if ([contentFilterTableView numberOfSelectedRows] == 1)
			[[self window] makeFirstResponder:contentFilterTableView];

		// Update current document's content filters in the SPQueryController
		[[SPQueryController sharedQueryController] replaceContentFilterByArray:
			[self contentFilterForFileURL:delegatesFileURL] ofType:filterType forFileURL:delegatesFileURL];

		// Update global preferences' list
		id cf = [[prefs objectForKey:SPContentFilters] mutableCopy];
		[cf setObject:[self contentFilterForFileURL:nil] forKey:filterType];
		[prefs setObject:cf forKey:SPContentFilters];
		[cf release];
		
		// Inform all opened documents to update the query favorites list
		for(id doc in [[NSDocumentController sharedDocumentController] documents])
			if([[doc valueForKeyPath:@"tableContentInstance"] respondsToSelector:@selector(setCompareTypes:)])
				[[doc valueForKeyPath:@"tableContentInstance"] setCompareTypes:nil];


	}

}

#pragma mark -
#pragma mark SplitView delegate methods

/**
 * Return the maximum possible size of the splitview.
 */
- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
{
	return (proposedMax - 245);
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
 * Returns the number of all content filters.
 */
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [contentFilters count];
}

/**
 * Returns the value for the requested table column and row index.
 */
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if(![[contentFilters objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]]) return @"";

	return [[contentFilters objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
}

/*
 * Save content filter name (MenuLabel) if inline edited (suppress empty names)
 */
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{

	if([[aTableColumn identifier] isEqualToString:@"MenuLabel"] && [anObject length]) {
		[[contentFilters objectAtIndex:rowIndex] setObject:[anObject description] forKey:@"MenuLabel"];
		[contentFilterNameTextField setStringValue:[anObject description]];
	}

	[contentFilterTableView reloadData];
}

/*
 * Before selecting an other filter save pending query string changes
 * and make sure that no group table item can be selected
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
	BOOL enable = ([contentFilterTableView numberOfSelectedRows] > 0);
	[removeButton setEnabled:enable];
	[numberOfArgsLabel setHidden:!enable];
	[resultingClauseLabel setHidden:!enable];
	[resultingClauseContentLabel setHidden:!enable];
	[insertPlaceholderButton setEnabled:enable];

	return ([[contentFilters objectAtIndex:rowIndex] objectForKey:@"headerOfFileURL"]) ? NO : YES;
}

/*
 * Set indention levels for headers and filters
 * (maybe in the future use an image for headers for expanding and collapsing)
 */
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if([[contentFilters objectAtIndex:rowIndex] objectForKey:@"headerOfFileURL"] && [[aTableColumn identifier] isEqualToString:@"MenuLabel"]) {
		// if([[[favoriteProperties objectAtIndex:rowIndex] objectForKey:@"isGroup"] isEqualToString:@"1"])
		// 	[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"NSRightFacingTriangleTemplate"]];
		// else
		// 	[(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"NSLeftFacingTriangleTemplate"]];
		[(ImageAndTextCell*)aCell setIndentationLevel:0];
	}
	else if(![[contentFilters objectAtIndex:rowIndex] objectForKey:@"headerOfFileURL"] && [[aTableColumn identifier] isEqualToString:@"MenuLabel"]) {
		// [(ImageAndTextCell*)aCell setImage:[NSImage imageNamed:@"dummy-small"]];
		[(ImageAndTextCell*)aCell setIndentationLevel:1];
	}
}

/*
 * A row of an header return is slighlty larger
 */
- (CGFloat)tableView:(NSTableView *)aTableView heightOfRow:(NSInteger)rowIndex
{
	return ([[contentFilters objectAtIndex:rowIndex] objectForKey:@"headerOfFileURL"]) ? 20 : 18;
}

/*
 * Only filter name can be edited inline
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if([[contentFilters objectAtIndex:rowIndex] objectForKey:@"headerOfFileURL"]) {
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
 * contentFilters holds the data if a table row is a group header or not
 */
- (BOOL)tableView:(NSTableView *)aTableView isGroupRow:(NSInteger)rowIndex
{
	return ([[contentFilters objectAtIndex:rowIndex] objectForKey:@"headerOfFileURL"]) ? YES : NO;
}
/*
 * Detect if inline editing was done - then ESC to close the sheet will be activate
 */ 
- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
	isTableCellEditing = NO;
}

/*
 * Changes in the name text field will be saved in data source directly
 * to update the table view accordingly
 */
- (void)controlTextDidChange:(NSNotification *)notification
{

	// Do nothing if no filter is selected
	if([contentFilterTableView numberOfSelectedRows] < 1) return;

	id object = [notification object];

	if(object == contentFilterNameTextField) {
		[[contentFilters objectAtIndex:[contentFilterTableView selectedRow]] setObject:[contentFilterNameTextField stringValue] forKey:@"MenuLabel"];
		[contentFilterTableView reloadData];
	}

}

/*
 * Parse clause and update labels accordingly
 */
- (void)textViewDidChangeSelection:(NSNotification *)notification
{
	// Do nothing if no filter is selected
	if([contentFilterTableView numberOfSelectedRows] < 1) return;

	id object = [notification object];

	if(object == contentFilterTextView) {
		[insertPlaceholderButton setEnabled:([[contentFilterTextView string] length])];
		[resultingClauseLabel setHidden:(![[contentFilterTextView string] length])];
		[resultingClauseContentLabel setHidden:(![[contentFilterTextView string] length])];
		[numberOfArgsLabel setHidden:(![[contentFilterTextView string] length])];

		NSUInteger numOfArgs = [[[contentFilterTextView string] componentsMatchedByRegex:@"(?<!\\\\)(\\$\\{.*?\\})"] count];
		[numberOfArgsLabel setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Number of arguments: %d", @"Number of arguments: %d"), numOfArgs]];

		[contentFilterConjunctionTextField setHidden:(numOfArgs < 2)];
		[contentFilterConjunctionLabel setHidden:(numOfArgs < 2)];

		if(numOfArgs > 2) {
			[resultingClauseLabel setStringValue:NSLocalizedString(@"Error", @"error")];
			[resultingClauseContentLabel setStringValue:NSLocalizedString(@"Maximum number of arguments is 2!", @"Maximum number of arguments is 2!")];
		} else {
			[resultingClauseLabel setStringValue:@"SELECT * FROM <table> WHERE"];
			NSMutableString *c = [[NSMutableString alloc] init];
			[c setString:[contentFilterTextView string]];
			[c replaceOccurrencesOfRegex:@"(?<!\\\\)\\$BINARY" withString:@"[BINARY]"];
			[c flushCachedRegexData];
			[c replaceOccurrencesOfRegex:@"(?<!\\\\)(\\$\\{.*?\\})" withString:@"[arg]"];
			[c flushCachedRegexData];
			[c replaceOccurrencesOfRegex:@"(?<!\\\\)\\$CURRENT_FIELD" withString:@"<field>"];
			[c flushCachedRegexData];
			[resultingClauseContentLabel setStringValue:[NSString stringWithFormat:@"<field> %@", c]];
			[c release];
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
	if([contentFilters count] < 2) return NO;

	SEL action = [menuItem action];
	
	if ( (action == @selector(duplicateContentFilter:))) 
	{
		return ([contentFilterTableView numberOfSelectedRows] == 1);
	}
	else if ( (action == @selector(removeContentFilter:))	||
		( action == @selector(exportFavorites:)))
	{
		return ([contentFilterTableView numberOfSelectedRows] > 0);
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

	NSArray *pboardTypes = [NSArray arrayWithObject:SPContentFilterPasteboardDragType];
	NSInteger originalRow = [[rows objectAtIndex:0] intValue];

	if(originalRow < 1) return NO;

	// Do not drag headers
	if([[contentFilters objectAtIndex:originalRow] objectForKey:@"headerOfFileURL"]) return NO;

	[pboard declareTypes:pboardTypes owner:nil];

	NSMutableData *indexdata = [[[NSMutableData alloc] init] autorelease];
	NSKeyedArchiver *archiver = [[[NSKeyedArchiver alloc] initForWritingWithMutableData:indexdata] autorelease];
	[archiver encodeObject:rows forKey:@"indexdata"];
	[archiver finishEncoding];
	[pboard setData:indexdata forType:SPContentFilterPasteboardDragType];

	return YES;

}

/**
 * Validate the proposed drop of the supplied rows.
 */
- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{	
	NSArray *pboardTypes = [[info draggingPasteboard] types];
	
	if (([pboardTypes count] > 1) && (row != -1)) {
		if (([pboardTypes containsObject:SPContentFilterPasteboardDragType]) && (operation == NSTableViewDropAbove)) {
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

	NSKeyedUnarchiver *unarchiver = [[[NSKeyedUnarchiver alloc] initForReadingWithData:[[info draggingPasteboard] dataForType:SPContentFilterPasteboardDragType]] autorelease];
	NSArray *draggedRows = [NSArray arrayWithArray:(NSArray *)[unarchiver decodeObjectForKey:@"indexdata"]];
	[unarchiver finishDecoding];

	NSInteger destinationRow = row;
	NSInteger offset = 0;

	NSUInteger i;

	for(i=0; i<[draggedRows count]; i++) {

		NSInteger originalRow = [[draggedRows objectAtIndex:i] intValue];

		if(originalRow < destinationRow) destinationRow--;

		originalRow += offset;

		// For safety reasons
		if(originalRow > [contentFilters count]-1) originalRow = [contentFilters count] - 1;

		NSMutableDictionary *draggedRow = [NSMutableDictionary dictionaryWithDictionary:[contentFilters objectAtIndex:originalRow]];
		[contentFilters removeObjectAtIndex:originalRow];
		[contentFilterTableView reloadData];

		if(destinationRow+i >= [contentFilters count])
			[contentFilters addObject:draggedRow];
		else
			[contentFilters insertObject:draggedRow atIndex:destinationRow+i];

		if(originalRow < row) offset--;

	}

	[contentFilterTableView reloadData];
	[contentFilterArrayController rearrangeObjects];

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
	if([contextInfo isEqualToString:@"removeSelectedFilters"]) {
		if (returnCode == NSAlertDefaultReturn) {
			NSIndexSet *indexes = [contentFilterTableView selectedRowIndexes];

			// get last index
			NSUInteger currentIndex = [indexes lastIndex];

			while (currentIndex != NSNotFound) {
				[contentFilters removeObjectAtIndex:currentIndex];
				// get next index (beginning from the end)
				currentIndex = [indexes indexLessThanIndex:currentIndex];
			}

			[contentFilterArrayController rearrangeObjects];
			[contentFilterTableView reloadData];

			// Set focus to filter list to avoid an unstable state
			[[self window] makeFirstResponder:contentFilterTableView];

			[removeButton setEnabled:([contentFilterTableView numberOfSelectedRows] > 0)];
		}
	}
}

/**
 * Import panel did end method.
 */
- (void)importPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{

	if (returnCode == NSOKButton) {

		NSString *filename = [[panel filenames] objectAtIndex:0];
		NSError *readError = nil;
		NSString *convError = nil;
		NSPropertyListFormat format;

		NSDictionary *spf = nil;

		if([[[filename pathExtension] lowercaseString] isEqualToString:@"spf"]) {
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

			if([[spf objectForKey:SPContentFilters] objectForKey:filterType] && [[[spf objectForKey:SPContentFilters] objectForKey:filterType] count]) {
				// if([contentFilterTableView numberOfSelectedRows] > 0) {
				// 	// Insert imported filters after the last selected filter
				// 	NSUInteger insertIndex = [[contentFilterTableView selectedRowIndexes] lastIndex] + 1;
				// 	NSUInteger i;
				// 	for(i=0; i<[[[spf objectForKey:SPContentFilters] objectForKey:filterType] count]; i++) {
				// 		[contentFilters insertObject:[[spf objectForKey:SPQueryFavorites] objectAtIndex:i] atIndex:insertIndex+i];
				// 	}
				// } else {
				// 	// If no selection add them
				[contentFilters addObjectsFromArray:[[spf objectForKey:SPContentFilters] objectForKey:filterType]];
				// }
				[contentFilterArrayController rearrangeObjects];
				[contentFilterTableView reloadData];
			} else {
				NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while reading data file", @"error while reading data file")]
												 defaultButton:NSLocalizedString(@"OK", @"OK button") 
											   alternateButton:nil 
												  otherButton:nil 
									informativeTextWithFormat:NSLocalizedString(@"No content filters found.", @"error that no content filters found")];

				[alert setAlertStyle:NSInformationalAlertStyle];
				[alert runModal];
				return;
			}
		}
	}
}


/**
 * Save panel did end method.
 */
- (void)savePanelDidEnd:(NSSavePanel *)panel returnCode:(int)returnCode contextInfo:(NSString *)contextInfo
{

	if([contextInfo isEqualToString:@"exportFilter"]) {
		if (returnCode == NSOKButton) {

			// Build a SPF with format = "content filters"
			NSMutableDictionary *spfdata = [NSMutableDictionary dictionary];
			NSMutableDictionary *cfdata = [NSMutableDictionary dictionary];
			NSMutableArray *filterData = [NSMutableArray array];

	
			[spfdata setObject:[NSNumber numberWithInt:1] forKey:@"version"];
			[spfdata setObject:@"content filters" forKey:@"format"];
			[spfdata setObject:[NSNumber numberWithBool:NO] forKey:@"encrypted"];

			NSIndexSet *indexes = [contentFilterTableView selectedRowIndexes];

			// Get selected items and preserve the order
			NSUInteger i;
			for (i=1; i<[contentFilters count]; i++)
				if([indexes containsIndex:i])
					[filterData addObject:[contentFilters objectAtIndex:i]];

			[cfdata setObject:filterData forKey:filterType];
			[spfdata setObject:cfdata forKey:SPContentFilters];
			
			NSString *err = nil;
			NSData *plist = [NSPropertyListSerialization dataFromPropertyList:spfdata
													  format:NSPropertyListXMLFormat_v1_0
											errorDescription:&err];

			if(err != nil) {
				NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while converting content filter data", @"error while converting content filter data")]
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
	[contentFilterTableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
	[[contentFilterNameTextField cell] setPlaceholderString:SP_NO_SELECTION_PLACEHOLDER_STRING];
	[contentFilterNameTextField setStringValue:@""];
	[contentFilterTextView setString:@""];
}
@end
