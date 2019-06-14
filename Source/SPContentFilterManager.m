//
//  SPContentFilterManager.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on Sep 29, 2009.
//  Copyright (c) 2009 Hans-Jörg Bibiko. All rights reserved.
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

#import "SPContentFilterManager.h"
#import "ImageAndTextCell.h"
#import "RegexKitLite.h"
#import "SPQueryController.h"
#import "SPDatabaseDocument.h"
#import "SPConnectionController.h"
#import "SPSplitView.h"
#import "SPAppController.h"

static NSString *SPExportFilterAction = @"SPExportFilter";

#define SP_MULTIPLE_SELECTION_PLACEHOLDER_STRING NSLocalizedString(@"[multiple selection]", @"[multiple selection]")
#define SP_NO_SELECTION_PLACEHOLDER_STRING       NSLocalizedString(@"[no selection]", @"[no selection]")
#define SP_NAME_REQUIRED_PLACEHOLDER_STRING      NSLocalizedString(@"[name required]", @"displayed when new content filter has empty Name field (ContentFilterManager)")
#define SP_FILE_PARSER_ERROR_TITLE_STRING        NSLocalizedString(@"Error while reading data file", @"error while reading data file")

@implementation SPContentFilterManager

/**
 * Initialize the manager with the supplied document
 */
- (id)initWithDatabaseDocument:(SPDatabaseDocument *)document forFilterType:(NSString *)compareType
{
	if (document == nil) {
		NSBeep();
		NSLog(@"ContentFilterManager was called without a document.");

		return nil;
	}

	if ((self = [super initWithWindowNibName:@"ContentFilterManager"])) {
#ifndef SP_CODA
		prefs = [NSUserDefaults standardUserDefaults];
#endif

		contentFilters = [[NSMutableArray alloc] init];
		tableDocumentInstance = document;
#ifndef SP_CODA
		documentFileURL = [[tableDocumentInstance fileURL] copy];
#endif

		filterType = [compareType copy];
	}

	return self;
}

/**
 * Upon awakening bind the query text view's background colour.
 */
- (void)awakeFromNib
{
	// Set up the split view
	[contentFilterSplitView setMinSize:120.f ofSubviewAtIndex:0];
	[contentFilterSplitView setMaxSize:245.f ofSubviewAtIndex:0];

	// Add global group row to contentFilters
	[contentFilters addObject:@{
		@"MenuLabel"        : NSLocalizedString(@"Global", @"Content Filter Manager : Filter Entry List: 'Global' Header"),
		@"headerOfFileURL"  : @"",
		@"Clause"           : @"",
		@"ConjunctionLabel" : @""
	}];

#ifndef SP_CODA /* prefs access */
	// Build data source for global content filter (as mutable copy! otherwise each
	// change will be stored in the prefs at once)
	if ([[prefs objectForKey:SPContentFilters] objectForKey:filterType]) {
		for (id fav in [[prefs objectForKey:SPContentFilters] objectForKey:filterType])
		{
			id f = [[fav mutableCopy] autorelease];

			if ([f objectForKey:@"ConjunctionLabels"]) {
				[f setObject:[[f objectForKey:@"ConjunctionLabels"] objectAtIndex:0] forKey:@"ConjunctionLabel"];
			}

			[contentFilters addObject:f];
		}
	}

	// Build doc-based filters
	[contentFilters addObject:[NSDictionary dictionaryWithObjectsAndKeys:
		[[[documentFileURL absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] lastPathComponent], @"MenuLabel",
		[documentFileURL absoluteString], @"headerOfFileURL",
		@"", @"Clause",
		nil]];
	
	if ([[SPQueryController sharedQueryController] contentFilterForFileURL:documentFileURL]) {
		id filters = [[SPQueryController sharedQueryController] contentFilterForFileURL:documentFileURL];
		if([filters objectForKey:filterType])
			for(id fav in [filters objectForKey:filterType])
				[contentFilters addObject:[[fav mutableCopy] autorelease]];
	}
#endif

	// Select the first query if any
	NSUInteger i = 0;
	
	for(i=0; i < [contentFilters count]; i++ )
		if(![[contentFilters objectAtIndex:i] objectForKey:@"headerOfFileURL"])
			break;

	[[self window] makeFirstResponder:contentFilterTableView];

	// Init GUI elements
	[contentFilterTableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
	[[contentFilterNameTextField cell] setPlaceholderString:SP_NO_SELECTION_PLACEHOLDER_STRING];
	[contentFilterNameTextField setStringValue:@""];
	[contentFilterTextView setString:@""];

	// Register drag types
	[contentFilterTableView registerForDraggedTypes:@[SPContentFilterPasteboardDragType]];

	[contentFilterArrayController setContent:contentFilters];
	[contentFilterTableView reloadData];

	// Set Remove button state
	[removeButton setEnabled:([contentFilterTableView numberOfSelectedRows] > 0)];

	// Set column header
	[[[contentFilterTableView tableColumnWithIdentifier:@"MenuLabel"] headerCell] setStringValue:[NSString stringWithFormat:NSLocalizedString(@"‘%@’ Fields Content Filters", @"table column header. Read: 'Showing all content filters for fields of type %@' (ContentFilterManager)"), filterType]];
}

#pragma mark -
#pragma mark Accessor methods

/**
 * Returns the content filters array for fileURL.
 * 
 * @param fileURL == The SPDatabaseDocument file URL; if fileURL == nil return the global content filters
 */
- (NSMutableArray *)contentFilterForFileURL:(NSURL *)fileURL
{
	NSMutableArray *filters = [NSMutableArray array];

	NSString *fileURLstring = (fileURL == nil) ? @"" : [fileURL absoluteString];

	NSUInteger i = 0;

	// Look for the header specified by fileURL
	while (i<[contentFilters count])
	{
		if ([[contentFilters objectAtIndex:i] objectForKey:@"headerOfFileURL"] &&
			[[[contentFilters objectAtIndex:i] objectForKey:@"headerOfFileURL"] isEqualToString:fileURLstring])
		{
			i++;
			break;
		}
		
		i++;
	}

	// Take all content filters until the next header or end of all content filters
	NSUInteger numOfArgs;
	
	for (; i < [contentFilters count]; i++)
	{
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
		}
		else {
			break;
		}
	}

	return filters;
}

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
 * Adds/Inserts a content filter
 */
- (IBAction)addContentFilter:(id)sender
{
	NSMutableDictionary *filter;
	NSUInteger insertIndex;

	// Store pending changes in Clause
	[[self window] makeFirstResponder:nil];

	// Duplicate a selected filter if sender == self
	if(sender == self)
		filter = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithFormat:NSLocalizedString(@"%@ Copy",@"Content Filter Manager : Initial name of copied filter"),[contentFilterNameTextField stringValue]], [contentFilterTextView string], nil] forKeys:@[@"MenuLabel", @"Clause"]];
	// Add a new filter
	else
		filter = [NSMutableDictionary dictionaryWithObjects:@[NSLocalizedString(@"New Filter",@"Content Filter Manager : Initial name for new filter"), @"", @""] forKeys:@[@"MenuLabel", @"Clause", @"ConjunctionLabel"]];

	// If a favourite is currently selected, add the new favourite next to it
	if([contentFilterTableView numberOfSelectedRows] > 0) {
		insertIndex = [[contentFilterTableView selectedRowIndexes] lastIndex]+1;
		[contentFilters insertObject:filter atIndex:insertIndex];
	}

#ifndef SP_CODA
	// If the DatabaseDocument is an on-disk document, add the favourite to the bottom of that document's favourites
	else if (![tableDocumentInstance isUntitled]) {
		insertIndex = [contentFilters count] - 1;
		[contentFilters addObject:filter];
	}
#endif

	// Otherwise, add to the bottom of the Global list by default
	else {
		insertIndex = 1;
		while (![[contentFilters objectAtIndex:insertIndex] objectForKey:@"headerOfFileURL"]) {
			insertIndex++;
		}
		[contentFilters insertObject:filter atIndex:insertIndex];
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

	// Complete editing in the window
	[[self window] makeFirstResponder:nil];

	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Remove selected content filters?", @"remove selected content filters message")
									 defaultButton:NSLocalizedString(@"Remove", @"remove button")
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to remove all selected content filters? This action cannot be undone.", @"remove all selected content filters informative message")];

	[alert setAlertStyle:NSCriticalAlertStyle];

	NSArray *buttons = [alert buttons];

	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"r"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];

	[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"removeSelectedFilters"];
}

/**
 * Insert placeholder - the to be inserted placeholder string is stored in sender's tooltip
 */
- (IBAction)insertPlaceholder:(id)sender
{
	[contentFilterTextView insertText:[[[sender selectedItem] toolTip] substringToIndex:[[[sender selectedItem] toolTip] rangeOfString:@" – "].location]];
}

/**
 * Show save panel sheet for exporting content filters to disk
 */
- (IBAction)exportContentFilter:(id)sender
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
		[self savePanelDidEnd:panel returnCode:returnCode contextInfo:SPExportFilterAction];
	}];
#endif
}

/**
 * Show open panel sheet for importing content filters by adding them to current ones
 */
- (IBAction)importContentFilterByAdding:(id)sender
{
#ifndef SP_CODA
	NSOpenPanel *panel = [NSOpenPanel openPanel];

	[panel setCanSelectHiddenExtension:YES];
	[panel setDelegate:self];
	[panel setCanChooseDirectories:NO];
	[panel setAllowsMultipleSelection:NO];

	[panel setAllowedFileTypes:@[SPFileExtensionDefault]];

	[panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger returnCode)
	{
		[self importPanelDidEnd:panel returnCode:returnCode contextInfo:nil];
	}];
#endif
}

/**
 * Show open panel sheet for importing content filters by replacing the current ones. Not yet implemented
 */
- (IBAction)importFavoritesByReplacing:(id)sender
{

}

/**
 * Closes the content filter manager
 */
- (IBAction)closeContentFilterManagerSheet:(id)sender
{
	[NSApp endSheet:[self window] returnCode:0];
	[[self window] orderOut:self];

	// "Apply Changes" button was pressed
	if([sender tag]) {

		// Ensure that last changes will be written back
		// if only one filter is selected; otherwise unstable state
		if ([contentFilterTableView numberOfSelectedRows] == 1)
			[[self window] makeFirstResponder:contentFilterTableView];

#ifndef SP_CODA
		// Update current document's content filters in the SPQueryController
		[[SPQueryController sharedQueryController] replaceContentFilterByArray:
			[self contentFilterForFileURL:documentFileURL] ofType:filterType forFileURL:documentFileURL];

		// Update global preferences' list
		id cf = [[prefs objectForKey:SPContentFilters] mutableCopy];
		[cf setObject:[self contentFilterForFileURL:nil] forKey:filterType];
		[prefs setObject:cf forKey:SPContentFilters];
		[cf release];

		// Inform all opened documents to update the query favorites list
		[[NSNotificationCenter defaultCenter] postNotificationName:SPContentFiltersHaveBeenUpdatedNotification object:self];
#endif
	}
}

/**
 * It triggers an update of contentFilterTextView and 
 * resultingClauseContentLabel by inserting @"" into contentFilterTextView
 */
- (IBAction)suppressLeadingFieldPlaceholderWasChanged:(id)sender
{
	[contentFilterTextView insertText:@""];
}

#pragma mark -
#pragma mark TableView delegate methods

/**
 * Update contentFilterNameTextField if selection of contentFilterTableView was changed.
 */
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSInteger row = [contentFilterTableView selectedRow];
	
	if ((row > -1) && (row < (NSInteger)[contentFilters count])) {	
		
		NSString *newName = [[contentFilters objectAtIndex:[contentFilterTableView selectedRow]] objectForKey:@"MenuLabel"];
		
		[contentFilterNameTextField setStringValue:(newName) ? newName : @""];
	}
}

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
	if (![[contentFilters objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]]) return @"";

	return [[contentFilters objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
}

/**
 * Save content filter name (MenuLabel) if inline edited (suppress empty names)
 */
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{

	if([[aTableColumn identifier] isEqualToString:@"MenuLabel"]) {
		if([anObject isKindOfClass:[NSString class]] && [(NSString *)anObject length]) {
			[[contentFilters objectAtIndex:rowIndex] setObject:anObject forKey:@"MenuLabel"];
			[contentFilterNameTextField setStringValue:anObject];
		}
	}

	[contentFilterTableView reloadData];
}

/**
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

	return (rowIndex >= 0 && [[contentFilters objectAtIndex:rowIndex] objectForKey:@"headerOfFileURL"]) ? NO : YES;
}

/**
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

/**
 * A row of an header return is slighlty larger
 */
- (CGFloat)tableView:(NSTableView *)aTableView heightOfRow:(NSInteger)rowIndex
{
	return ([[contentFilters objectAtIndex:rowIndex] objectForKey:@"headerOfFileURL"]) ? 20 : 18;
}

/**
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

/**
 * Sorting by clicking at a column header inside groups. Not yet implemented
 */
- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
	// TODO: Not yet implemented
	return;
}

/**
 * If current row's contentFilters object has a key "headerOfFileURL" then row is grouped ie it's an header
 */
- (BOOL)tableView:(NSTableView *)aTableView isGroupRow:(NSInteger)rowIndex
{
	return ([[contentFilters objectAtIndex:rowIndex] objectForKey:@"headerOfFileURL"]) ? YES : NO;
}

#pragma mark -
#pragma mark TableView drag & drop delegate methods

/**
 * Return whether or not the supplied rows can be written.
 */
- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rows toPasteboard:(NSPasteboard*)pboard
{

	NSArray *pboardTypes = @[SPContentFilterPasteboardDragType];
	NSUInteger originalRow = [rows firstIndex];

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
	NSIndexSet *draggedIndexes = [[NSIndexSet alloc] initWithIndexSet:(NSIndexSet *)[unarchiver decodeObjectForKey:@"indexdata"]];
	[unarchiver finishDecoding];

	// TODO: still rely on a NSArray but in the future rewrite it to use the NSIndexSet directly
	NSMutableArray *draggedRows = [[NSMutableArray alloc] initWithCapacity:1];
	[draggedIndexes enumerateIndexesUsingBlock:^(NSUInteger rowIndex, BOOL * _Nonnull stop) {
		[draggedRows addObject:[NSNumber numberWithInteger:rowIndex]];
	}];


	NSInteger destinationRow = row;
	NSInteger offset = 0;

	NSUInteger i;

	for(i=0; i<[draggedRows count]; i++) {

		NSInteger originalRow = [[draggedRows objectAtIndex:i] integerValue];

		if(originalRow < destinationRow) destinationRow--;

		originalRow += offset;

		// For safety reasons
		if(originalRow > (NSInteger)[contentFilters count]-1) originalRow = [contentFilters count] - 1;

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
	[draggedIndexes release];
	[draggedRows release];
	return YES;
}

#pragma mark -
#pragma mark Various Control delegate methods

/**
 * Detect if inline editing was done
 */
- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
	isTableCellEditing = NO;
}

/**
 * Trap the escape overriding default behaviour and ending editing,
 * only within the current row.
 */
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	// Trap the escape key
	if (  [[control window] methodForSelector:command] == [[control window] methodForSelector:@selector(cancelOperation:)] )
	{

		// Abort editing
		[control abortEditing];
		isTableCellEditing = NO;
		// Reset name input text field
		if([contentFilterTableView selectedRow] > -1)
			[contentFilterNameTextField setStringValue:
				[[contentFilters objectAtIndex:[contentFilterTableView selectedRow]] objectForKey:@"MenuLabel"]];

		return YES;
	}

	return NO;
}

/**
 * Changes in the name text field will be saved in data source directly
 * to update the table view accordingly. If filter name is changed via inline editing
 * in the tableView update name text field accordingly and check for empty names
 */
- (void)controlTextDidChange:(NSNotification *)notification
{

	// Do nothing if no filter is selected
	if([contentFilterTableView numberOfSelectedRows] < 1) return;

	id object = [notification object];

	if(object == contentFilterNameTextField) {
		if([[contentFilterNameTextField stringValue] length]) {
			[[contentFilters objectAtIndex:[contentFilterTableView selectedRow]] setObject:[contentFilterNameTextField stringValue] forKey:@"MenuLabel"];
			[contentFilterTableView reloadData];
		} else {
			NSBeep();
			[[contentFilters objectAtIndex:[contentFilterTableView selectedRow]] setObject:SP_NAME_REQUIRED_PLACEHOLDER_STRING forKey:@"MenuLabel"];
			[contentFilterNameTextField setStringValue:SP_NAME_REQUIRED_PLACEHOLDER_STRING];
			[contentFilterNameTextField selectText:nil];
		}
	}
	else if (object == contentFilterTableView) {
		NSTextView *editor = [[notification userInfo] objectForKey:@"NSFieldEditor"];
		NSString *newName = [[editor textStorage] string];
		if([newName length]) {
			[contentFilterNameTextField setStringValue:newName];
		} else {
			NSBeep();
			[editor insertText:SP_NAME_REQUIRED_PLACEHOLDER_STRING];
			[editor setSelectedRange:NSMakeRange(0,[SP_NAME_REQUIRED_PLACEHOLDER_STRING length])];
			[contentFilterNameTextField setStringValue:SP_NAME_REQUIRED_PLACEHOLDER_STRING];
		}
	}

}

/**
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
		[numberOfArgsLabel setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Number of arguments: %lu", @"Argument count (ContentFilterManager)"), (unsigned long)numOfArgs]];

		[contentFilterConjunctionTextField setHidden:(numOfArgs < 2)];
		[contentFilterConjunctionLabel setHidden:(numOfArgs < 2)];

		if(numOfArgs > 2) {
			[resultingClauseLabel setStringValue:NSLocalizedString(@"Error", @"error")];
			[resultingClauseContentLabel setStringValue:NSLocalizedString(@"Maximum number of arguments is 2!", @"Shown when user inserts too many arguments (ContentFilterManager)")];
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
			[resultingClauseContentLabel setStringValue:[NSString stringWithFormat:@"%@%@", ([suppressLeadingFieldPlaceholderCheckbox state] == NSOnState) ? @"" : @"<field> ", c]];
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

	if (action == @selector(duplicateContentFilter:))
	{
		return ([contentFilterTableView numberOfSelectedRows] == 1);
	}
	else if ( (action == @selector(removeContentFilter:)) || (action == @selector(exportFavorites:)) )
	{
		return ([contentFilterTableView numberOfSelectedRows] > 0);
	}

	return YES;
}

#pragma mark -
#pragma mark Other

/**
 * Sheet did end method for removing content filters
 */
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	if ([contextInfo isEqualToString:@"removeSelectedFilters"]) {
		if (returnCode == NSAlertDefaultReturn) {
			NSIndexSet *indexes = [contentFilterTableView selectedRowIndexes];

			[indexes enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger currentIndex, BOOL * _Nonnull stop) {
				[contentFilters removeObjectAtIndex:currentIndex];
			}];

			if ([contentFilters count] == 2) {
				[contentFilterNameTextField setStringValue:@""];
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
- (void)importPanelDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
#ifndef SP_CODA
	if (returnCode == NSOKButton) {

		NSString *filename = [[[panel URLs] objectAtIndex:0] path];

		NSInteger insertionIndexStart, insertionIndexEnd;

		NSDictionary *spf = nil;

		if([[[filename pathExtension] lowercaseString] isEqualToString:SPFileExtensionDefault]) {
			{
				NSError *error = nil;
				
				NSData *pData = [NSData dataWithContentsOfFile:filename options:NSUncachedRead error:&error];
				
				if(pData && !error) {
					spf = [[NSPropertyListSerialization propertyListWithData:pData
																	 options:NSPropertyListImmutable
																	  format:NULL
																	   error:&error] retain];
				}
				
				if(!spf || error) {
					NSAlert *alert = [NSAlert alertWithMessageText:SP_FILE_PARSER_ERROR_TITLE_STRING
													 defaultButton:NSLocalizedString(@"OK", @"OK button")
												   alternateButton:nil
													   otherButton:nil
										 informativeTextWithFormat:NSLocalizedString(@"File couldn't be read. (%@)", @"error while reading data file"), [error localizedDescription]];
					
					[alert setAlertStyle:NSCriticalAlertStyle];
					[alert runModal];
					if (spf) [spf release];
					return;
				}
			}

			if([[spf objectForKey:SPContentFilters] objectForKey:filterType] && [[[spf objectForKey:SPContentFilters] objectForKey:filterType] count]) {

#ifndef SP_CODA
				// If the DatabaseDocument is an on-disk document, add the favourites to the bottom of it
				if (![tableDocumentInstance isUntitled]) {
					insertionIndexStart = [contentFilters count];
					[contentFilters addObjectsFromArray:[[spf objectForKey:SPContentFilters] objectForKey:filterType]];
					insertionIndexEnd = [contentFilters count] - 1;
				}

				// Otherwise, add to the bottom of the Global array
				else {
#endif
					NSUInteger i, l;
					insertionIndexStart = 1;
					while (![[contentFilters objectAtIndex:insertionIndexStart] objectForKey:@"headerOfFileURL"]) {
						insertionIndexStart++;
					}
					for (i = 0, l = [[[spf objectForKey:SPContentFilters] objectForKey:filterType] count]; i < l; i++) {
				 		[contentFilters insertObject:[[[spf objectForKey:SPContentFilters] objectForKey:filterType] objectAtIndex:i] atIndex:insertionIndexStart + i];
					}
					insertionIndexEnd = insertionIndexStart + i;
#ifndef SP_CODA
				}
#endif

				[contentFilterArrayController rearrangeObjects];
				[contentFilterTableView reloadData];
				[contentFilterTableView selectRowIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(insertionIndexStart, insertionIndexEnd - insertionIndexStart)] byExtendingSelection:NO];
				[contentFilterTableView scrollRowToVisible:insertionIndexEnd];
				[spf release];
			} else {
				NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithString:SP_FILE_PARSER_ERROR_TITLE_STRING]
												 defaultButton:NSLocalizedString(@"OK", @"OK button")
											   alternateButton:nil
												  otherButton:nil
									informativeTextWithFormat:NSLocalizedString(@"No content filters found.", @"No content filters were found in file to import (ContentFilterManager)")];

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
	if([contextInfo isEqualToString:SPExportFilterAction]) {
		if (returnCode == NSOKButton) {

			// Build a SPF with format = "content filters"
			NSMutableDictionary *spfdata = [NSMutableDictionary dictionary];
			NSMutableDictionary *cfdata = [NSMutableDictionary dictionary];
			NSMutableArray *filterData = [NSMutableArray array];


			[spfdata setObject:@1 forKey:SPFVersionKey];
			[spfdata setObject:SPFContentFiltersContentType forKey:SPFFormatKey];
			[spfdata setObject:@NO forKey:@"encrypted"];

			NSIndexSet *indexes = [contentFilterTableView selectedRowIndexes];

			// Get selected items and preserve the order
			NSUInteger i;
			for (i=1; i<[contentFilters count]; i++)
				if([indexes containsIndex:i])
					[filterData addObject:[contentFilters objectAtIndex:i]];

			[cfdata setObject:filterData forKey:filterType];
			[spfdata setObject:cfdata forKey:SPContentFilters];

			NSError *error = nil;
			NSData *plist = [NSPropertyListSerialization dataWithPropertyList:spfdata
			                                                           format:NSPropertyListXMLFormat_v1_0
			                                                          options:0
			                                                            error:&error];

			if(error) {
				NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error while converting content filter data", @"Content filters could not be converted to plist upon export - message title (ContentFilterManager)")
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

- (void)dealloc
{
	SPClear(contentFilters);
	SPClear(filterType);
	SPClear(documentFileURL);
	
	[super dealloc];
}

@end
