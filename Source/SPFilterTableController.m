//
//  SPFilterTableController.m
//  sequel-pro
//
//  Created by Max Lohrmann on 07.05.18.
//  Copyright (c) 2018 Max Lohrmann. All rights reserved.
//  Relocated from existing files. Previous copyright applies.
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

#import "SPFilterTableController.h"
#import "SPSplitView.h"
#import "SPCopyTable.h"
#import "SPTextView.h"
#import "RegexKitLite.h"
#import "SPTextAndLinkCell.h"

static NSString *SPTableFilterSetDefaultOperator = @"SPTableFilterSetDefaultOperator";
static void *FilterTableKVOContext = &FilterTableKVOContext;

@interface SPFilterTableController () <NSTableViewDataSource, NSTableViewDelegate, NSControlTextEditingDelegate>

- (IBAction)filterTable:(id)sender;
- (IBAction)toggleLookAllFieldsMode:(id)sender;
- (IBAction)tableFilterClear:(id)sender;

- (IBAction)toggleNegateClause:(id)sender;
- (IBAction)toggleDistinctSelect:(id)sender;
- (IBAction)setDefaultOperator:(id)sender;

- (IBAction)closeSheet:(id)sender;
- (IBAction)showDefaultOperaterHelp:(id)sender;

- (void)updateFilterTableClause:(id)currentValue;

+ (NSString*)escapeFilterTableDefaultOperator:(NSString*)op;

@end

@implementation SPFilterTableController

#pragma mark Public methods

@synthesize target;
@synthesize action;

- (instancetype)init {
	if ((self = [super initWithWindowNibName:@"FilterTableWindow"])) {
		target = nil;
		action = NULL;

		prefs = [NSUserDefaults standardUserDefaults];
		[prefs addObserver:self
		        forKeyPath:SPDisplayTableViewVerticalGridlines
		           options:NSKeyValueObservingOptionNew
		           context:FilterTableKVOContext];

		filterTableData = [[NSMutableDictionary alloc] initWithCapacity:1];

		filterTableNegate          = NO;
		filterTableDistinct        = NO;
		filterTableIsSwapped       = NO;

		lastEditedFilterTableValue = nil;
	}
	return self;
}

- (void)dealloc
{
	//TODO this should be changed to the variant with …context: after 10.6 support is removed!
	[prefs removeObserver:self forKeyPath:SPDisplayTableViewVerticalGridlines];

	SPClear(filterTableData);
	SPClear(lastEditedFilterTableValue);
	SPClear(filterTableDefaultOperator);
	[super dealloc];
}

- (void)showFilterTableWindow
{
	[[self window] makeKeyAndOrderFront:nil];
	[filterTableWhereClause setContinuousSpellCheckingEnabled:NO];
	[filterTableWhereClause setAutoindent:NO];
	[filterTableWhereClause setAutoindentIgnoresEnter:NO];
	[filterTableWhereClause setAutopair:[prefs boolForKey:SPCustomQueryAutoPairCharacters]];
	[filterTableWhereClause setAutohelp:NO];
	[filterTableWhereClause setAutouppercaseKeywords:[prefs boolForKey:SPCustomQueryAutoUppercaseKeywords]];
	[filterTableWhereClause setCompletionWasReinvokedAutomatically:NO];
	[filterTableWhereClause insertText:@""];
	[filterTableWhereClause didChangeText];

	[[filterTableView window] makeFirstResponder:filterTableView];
}

- (void)setFilterTableData:(NSData*)arcData
{
	if(!arcData) return;
	NSDictionary *filterData = [NSUnarchiver unarchiveObjectWithData:arcData];
	[filterTableData removeAllObjects];
	[filterTableData addEntriesFromDictionary:filterData];
	[[self window] makeKeyAndOrderFront:nil];
	[filterTableView reloadData];
}

- (NSData*) filterTableData
{
	if(![[self window] isVisible]) return nil;

	[filterTableView deselectAll:nil];

	return [NSArchiver archivedDataWithRootObject:filterTableData];
}

- (NSString *)tableFilterString
{
	if([[[filterTableWhereClause textStorage] string] length]) {
		if ([filterTableNegateCheckbox state] == NSOnState) {
			return [NSString stringWithFormat:@"NOT (%@)", [[filterTableWhereClause textStorage] string]];
		}
		else {
			return [[filterTableWhereClause textStorage] string];
		}
	}
	else {
		return nil;
	}
}

- (void)setColumns:(NSArray *)dataColumns
{
	[self window]; // make sure window is loaded
	// Clear filter table
	[filterTableView abortEditing];
	while ([[filterTableView tableColumns] count]) {
		[NSArrayObjectAtIndex([filterTableView tableColumns], 0) setHeaderToolTip:nil]; // prevent crash #2414
		[filterTableView removeTableColumn:NSArrayObjectAtIndex([filterTableView tableColumns], 0)];
	}
	// Clear filter table data
	[filterTableData removeAllObjects];
	[filterTableWhereClause setString:@""];

	// Clear error state
	[self setFilterError:0 message:nil sqlstate:nil];

	if(dataColumns) {
		CGFloat totalWidth = 0;
		// Add the new columns to the filterTable
		for (NSDictionary *columnDefinition in dataColumns ) {
			// Set up column for filterTable
			NSTableColumn *filterCol = [[NSTableColumn alloc] initWithIdentifier:[columnDefinition objectForKey:@"datacolumnindex"]];
			[[filterCol headerCell] setStringValue:[columnDefinition objectForKey:@"name"]];
			[filterCol setEditable:YES];
			SPTextAndLinkCell *filterDataCell = [[[SPTextAndLinkCell alloc] initTextCell:@""] autorelease];
			[filterDataCell setEditable:YES];
			[filterDataCell setLineBreakMode:NSLineBreakByTruncatingTail]; // add ellipsis for long values (default is to simply hide words)
			[filterCol setDataCell:filterDataCell];
			NSSize headerSize = [[[filterCol headerCell] attributedStringValue] size];
			CGFloat headerInitialWidth = headerSize.width + 5.0;
			[filterCol setWidth:headerInitialWidth];
			totalWidth += headerInitialWidth;
			[filterTableView addTableColumn:filterCol];
			[filterCol release];

			[filterTableData setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
				[columnDefinition objectForKey:@"name"], @"name",
				[columnDefinition objectForKey:@"typegrouping"], @"typegrouping",
				[NSMutableArray arrayWithObjects:@"", @"", @"", @"", @"", @"", @"", @"", @"", @"", nil], SPTableContentFilterKey,
					nil] forKey:[columnDefinition objectForKey:@"datacolumnindex"]];
		}

		// if the width of all columns is still less than the width of the table view resize them uniformly once to take up all horizontal space
		if(totalWidth < [[filterTableView enclosingScrollView] contentSize].width) [filterTableView sizeToFit];
	}

	[filterTableView reloadData];
}

- (BOOL)isDistinct
{
	return filterTableDistinct;
}

- (void)setFilterError:(NSUInteger)errorID message:(NSString *)message sqlstate:(NSString *)sqlstate
{
	if(errorID) {
		[[self window] setTitle:[NSString stringWithFormat:@"%@ – %@", NSLocalizedString(@"Filter", @"filter label"), NSLocalizedString(@"WHERE clause not valid", @"WHERE clause not valid")]];
	}
	else {
		[[self window] setTitle:NSLocalizedString(@"Filter", @"filter label")];
	}
}

#pragma mark - Internal methods

- (void)windowDidLoad
{
	[filterTableView setGridStyleMask:([prefs boolForKey:SPDisplayTableViewVerticalGridlines]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];

	// Modify the filter table split view sizes
	[filterTableSplitView setMinSize:135 ofSubviewAtIndex:1];

	// Init Filter Table GUI
	[filterTableDistinctCheckbox setState:(filterTableDistinct) ? NSOnState : NSOffState];
	[filterTableNegateCheckbox setState:(filterTableNegate) ? NSOnState : NSOffState];
	[filterTableLiveSearchCheckbox setState:NSOffState];

	filterTableDefaultOperator = [[[self class] escapeFilterTableDefaultOperator:[prefs objectForKey:SPFilterTableDefaultOperator]] retain];
}

- (IBAction)filterTable:(id)sender
{
	if(target && action) [target performSelector:action withObject:self];
}

/**
 * Generate WHERE clause to look for last typed pattern in all fields
 */
- (IBAction)toggleLookAllFieldsMode:(id)sender
{
	[self updateFilterTableClause:sender];

	// If live search is set perform filtering
	if ([filterTableLiveSearchCheckbox state] == NSOnState) {
		[self filterTable:filterTableFilterButton];
	}
}

/**
 * Clear the filter table
 */
- (IBAction)tableFilterClear:(id)sender
{
	[filterTableView abortEditing];

	if(filterTableData && [filterTableData count]) {

		// Clear filter data
		for(NSNumber *col in [filterTableData allKeys])
		{
			[[filterTableData objectForKey:col] setObject:[NSMutableArray arrayWithObjects:@"", @"", @"", @"", @"", @"", @"", @"", @"", @"", nil] forKey:SPTableContentFilterKey];
		}

		[filterTableView reloadData];
		[filterTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
		[filterTableWhereClause setString:@""];

		// Reload table
		[self filterTable:nil];
	}
}

/**
 * Set filter table's Negate
 */
- (IBAction)toggleNegateClause:(id)sender
{
	filterTableNegate = !filterTableNegate;

	if (filterTableNegate) {
		[filterTableQueryTitle setStringValue:NSLocalizedString(@"WHERE NOT query", @"Title of filter preview area when the query WHERE is negated")];
	}
	else {
		[filterTableQueryTitle setStringValue:NSLocalizedString(@"WHERE query", @"Title of filter preview area when the query WHERE is normal")];
	}

	// If live search is set perform filtering
	if ([filterTableLiveSearchCheckbox state] == NSOnState) {
		[self filterTable:filterTableFilterButton];
	}
}

/**
 * Set filter table's Distinct
 */
- (IBAction)toggleDistinctSelect:(id)sender
{
	filterTableDistinct = !filterTableDistinct;

	[filterTableDistinctCheckbox setState:(filterTableDistinct) ? NSOnState : NSOffState];

	// If live search is set perform filtering
	if ([filterTableLiveSearchCheckbox state] == NSOnState) {
		[self filterTable:filterTableFilterButton];
	}
}

/**
 * Set filter table's default operator
 */
- (IBAction)setDefaultOperator:(id)sender
{
	[[self window] makeFirstResponder:filterTableView];

	// Load history
	if([prefs objectForKey:SPFilterTableDefaultOperatorLastItems]) {
		NSMutableArray *lastItems = [NSMutableArray array];

		[lastItems addObject:@"LIKE '%@%'"];

		for(NSString* item in [prefs objectForKey:SPFilterTableDefaultOperatorLastItems])
		{
			[lastItems addObject:item];
		}

		[filterTableSetDefaultOperatorValue removeAllItems];
		[filterTableSetDefaultOperatorValue addItemsWithObjectValues:lastItems];
	}

	[filterTableSetDefaultOperatorValue setStringValue:[prefs objectForKey:SPFilterTableDefaultOperator]];

	[NSApp beginSheet:filterTableSetDefaultOperatorSheet
	   modalForWindow:[self window]
	    modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
	      contextInfo:SPTableFilterSetDefaultOperator];
}

/**
 * Close an open sheet.
 */
- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
	[sheet orderOut:self];

	if([contextInfo isEqualToString:SPTableFilterSetDefaultOperator]) {
		if(returnCode) {
			if(filterTableDefaultOperator) [filterTableDefaultOperator release];
			NSString *newOperator = [filterTableSetDefaultOperatorValue stringValue];
			filterTableDefaultOperator = [[[self class] escapeFilterTableDefaultOperator:newOperator] retain];
			[prefs setObject:newOperator forKey:SPFilterTableDefaultOperator];

			if(![newOperator isMatchedByRegex:@"(?i)like\\s+['\"]%@%['\"]\\s*"]) {
				if(![prefs objectForKey:SPFilterTableDefaultOperatorLastItems])
					[prefs setObject:[NSMutableArray array] forKey:SPFilterTableDefaultOperatorLastItems];

				NSMutableArray *lastItems = [NSMutableArray array];
				[lastItems setArray:[prefs objectForKey:SPFilterTableDefaultOperatorLastItems]];

				if([lastItems containsObject:newOperator])
					[lastItems removeObject:newOperator];
				if([lastItems count] > 0)
					[lastItems insertObject:newOperator atIndex:0];
				else
					[lastItems addObject:newOperator];
				// Remember only the last 15 items
				if([lastItems count] > 15)
					while([lastItems count] > 15)
						[filterTableSetDefaultOperatorValue removeItemAtIndex:[lastItems count]-1];

				[prefs setObject:lastItems forKey:SPFilterTableDefaultOperatorLastItems];
			}
			[self updateFilterTableClause:nil];
		}
	}
}

/**
 * Closes the current sheet and stops the modal session
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

/**
 * Opens the content filter help page in the default browser.
 */
- (IBAction)showDefaultOperaterHelp:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:SPLOCALIZEDURL_CONTENTFILTERHELP]];
}

/**
 * Update WHERE clause in filter table window.
 *
 * @param currentValue If currentValue == nil take the data from filterTableData, if currentValue == filterTableSearchAllFields
 * generate a WHERE clause to search in all given fields, if currentValue == a string take this string as table cell data of the
 * currently edited table cell
 */
- (void)updateFilterTableClause:(id)currentValue
{
	NSMutableString *clause  = [NSMutableString string];
	NSInteger numberOfRows   = [self numberOfRowsInTableView:filterTableView];
	NSInteger numberOfCols   = [[filterTableView tableColumns] count];
	NSRange opRange, defopRange;

	BOOL lookInAllFields = NO;

	NSString *re1 = @"^\\s*(<[=>]?|>=?|!?=|≠|≤|≥)\\s*(.*?)\\s*$";
	NSString *re2 = @"^\\s*(.*)\\s+(.*?)\\s*$";

	NSInteger editedRow = [filterTableView editedRow];

	if (currentValue == filterTableSearchAllFields) {
		numberOfRows = 1;
		lookInAllFields = YES;
	}

	[filterTableWhereClause setString:@""];

	for (NSInteger i = 0; i < numberOfRows; i++)
	{
		NSInteger numberOfValues = 0;

		for (NSInteger anIndex = 0; anIndex < numberOfCols; anIndex++)
		{
			NSString *filterCell = nil;
			NSDictionary *filterCellData = [NSDictionary dictionaryWithDictionary:[filterTableData objectForKey:[NSString stringWithFormat:@"%ld", (long)anIndex]]];

			// Take filterTableData
			if (!currentValue) {
				filterCell = NSArrayObjectAtIndex([filterCellData objectForKey:SPTableContentFilterKey], i);
			}
			// Take last edited value to create the OR clause
			else if (lookInAllFields) {
				if (lastEditedFilterTableValue && [lastEditedFilterTableValue length]) {
					filterCell = lastEditedFilterTableValue;
				}
				else {
					[filterTableWhereClause setString:@""];
					[filterTableWhereClause insertText:@""];
					[filterTableWhereClause scrollRangeToVisible:NSMakeRange(0, 0)];

					// If live search is set perform filtering
					if ([filterTableLiveSearchCheckbox state] == NSOnState) {
						[self filterTable:filterTableFilterButton];
					}
				}
			}
			// Take value from currently edited table cell
			else if ([currentValue isKindOfClass:[NSString class]]) {
				if (i == editedRow && anIndex == [[NSArrayObjectAtIndex([filterTableView tableColumns], [filterTableView editedColumn]) identifier] integerValue]) {
					filterCell = (NSString*)currentValue;
				}
				else {
					filterCell = NSArrayObjectAtIndex([filterCellData objectForKey:SPTableContentFilterKey], i);
				}
			}

			if ([filterCell length]) {

				// Recode special operators
				filterCell = [filterCell stringByReplacingOccurrencesOfRegex:@"^\\s*≠" withString:@"!="];
				filterCell = [filterCell stringByReplacingOccurrencesOfRegex:@"^\\s*≤" withString:@"<="];
				filterCell = [filterCell stringByReplacingOccurrencesOfRegex:@"^\\s*≥" withString:@">="];

				if (numberOfValues) {
					[clause appendString:(lookInAllFields) ? @" OR " : @" AND "];
				}

				NSString *fieldName = [[filterCellData objectForKey:@"name"] backtickQuotedString];
				NSString *filterTableDefaultOperatorWithFieldName = [filterTableDefaultOperator stringByReplacingOccurrencesOfString:@"`@`" withString:fieldName];

				opRange = [filterCell rangeOfString:@"`@`"];
				defopRange = [filterTableDefaultOperator rangeOfString:@"`@`"];

				// if cell data begins with ' or " treat it as it is
				// by checking if default operator by itself contains a ' or " - if so
				// remove first and if given the last ' or "
				if ([filterCell isMatchedByRegex:@"^\\s*['\"]"]) {
					if ([filterTableDefaultOperator isMatchedByRegex:@"['\"]"]) {
						NSArray *matches = [filterCell arrayOfCaptureComponentsMatchedByRegex:@"^\\s*(['\"])(.*)\\1\\s*$"];

						if ([matches count] && [matches = NSArrayObjectAtIndex(matches, 0) count] == 3) {
							[clause appendFormat:[NSString stringWithFormat:@"%%@ %@", filterTableDefaultOperatorWithFieldName], fieldName, NSArrayObjectAtIndex(matches, 2)];
						}
						else {
							matches = [filterCell arrayOfCaptureComponentsMatchedByRegex:@"^\\s*(['\"])(.*)\\s*$"];

							if ([matches count] && [matches = NSArrayObjectAtIndex(matches, 0) count] == 3) {
								[clause appendFormat:[NSString stringWithFormat:@"%%@ %@", filterTableDefaultOperatorWithFieldName], fieldName, NSArrayObjectAtIndex(matches, 2)];
							}
						}
					}
					else {
						[clause appendFormat:[NSString stringWithFormat:@"%%@ %@", filterTableDefaultOperatorWithFieldName], fieldName, filterCell];
					}
				}
					// If cell contains the field name placeholder
				else if (opRange.length || defopRange.length) {
					filterCell = [filterCell stringByReplacingOccurrencesOfString:@"`@`" withString:fieldName];

					if (defopRange.length) {
						[clause appendFormat:filterTableDefaultOperatorWithFieldName, [filterCell stringByReplacingOccurrencesOfString:@"`@`" withString:fieldName]];
					}
					else {
						[clause appendString:[filterCell stringByReplacingOccurrencesOfString:@"`@`" withString:fieldName]];
					}
				}
					// If cell is equal to NULL
				else if ([filterCell isMatchedByRegex:@"(?i)^\\s*null\\s*$"]) {
					[clause appendFormat:@"%@ IS NULL", fieldName];
				}
					// If cell starts with an operator
				else if ([filterCell isMatchedByRegex:re1]) {
					NSArray *matches = [filterCell arrayOfCaptureComponentsMatchedByRegex:re1];

					if ([matches count] && [matches = NSArrayObjectAtIndex(matches, 0) count] == 3) {
						[clause appendFormat:@"%@ %@ %@", fieldName, NSArrayObjectAtIndex(matches, 1), NSArrayObjectAtIndex(matches, 2)];
					}
				}
					// If cell consists of at least two words treat the first as operator and the rest as argument
				else if ([filterCell isMatchedByRegex:re2]) {
					NSArray *matches = [filterCell arrayOfCaptureComponentsMatchedByRegex:re2];

					if ([matches count] && [matches = NSArrayObjectAtIndex(matches,0) count] == 3) {
						[clause appendFormat:@"%@ %@ %@", fieldName, [NSArrayObjectAtIndex(matches, 1) uppercaseString], NSArrayObjectAtIndex(matches, 2)];
					}
				}
					// Apply the default operator
				else {
					[clause appendFormat:[NSString stringWithFormat:@"%%@ %@", filterTableDefaultOperatorWithFieldName], fieldName, filterCell];
				}

				numberOfValues++;
			}
		}

		if (numberOfValues) {
			[clause appendString:@"\nOR\n"];
		}
	}

	// Remove last " OR " if any
	[filterTableWhereClause setString:[clause length] > 3 ? [clause substringToIndex:([clause length] - 4)] : @""];

	// Update syntax highlighting and uppercasing
	[filterTableWhereClause insertText:@""];
	[filterTableWhereClause scrollRangeToVisible:NSMakeRange(0, 0)];

	// If live search is set perform filtering
	if ([filterTableLiveSearchCheckbox state] == NSOnState) {
		[self filterTable:filterTableFilterButton];
	}
}

#pragma mark - TableView datasource methods

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if (filterTableIsSwapped) {
		[[[filterTableData objectForKey:@(rowIndex)] objectForKey:SPTableContentFilterKey] replaceObjectAtIndex:([[tableColumn identifier] integerValue] - 1) withObject:(NSString *)object];
	}
	else {
		[[[filterTableData objectForKey:[tableColumn identifier]] objectForKey:SPTableContentFilterKey] replaceObjectAtIndex:rowIndex withObject:(NSString *)object];
	}

	[self updateFilterTableClause:nil];
}

- (NSInteger)numberOfRowsInTableView:(SPCopyTable *)tableView
{
	return filterTableIsSwapped ? [filterTableData count] : [[[filterTableData objectForKey:@"0"] objectForKey:SPTableContentFilterKey] count];
}

- (id)tableView:(SPCopyTable *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	NSUInteger columnIndex = [[tableColumn identifier] integerValue];

	if (filterTableIsSwapped) {
		// First column shows the field names
		if (columnIndex == 0) {
			return [[[NSTableHeaderCell alloc] initTextCell:[[filterTableData objectForKey:[NSNumber numberWithInteger:rowIndex]] objectForKey:@"name"]] autorelease];
		}

		return NSArrayObjectAtIndex([[filterTableData objectForKey:[NSNumber numberWithInteger:rowIndex]] objectForKey:SPTableContentFilterKey], columnIndex - 1);
	}

	return NSArrayObjectAtIndex([[filterTableData objectForKey:[tableColumn identifier]] objectForKey:SPTableContentFilterKey], rowIndex);
}

#pragma mark - TableView delegate methods

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)rowIndex
{
	return YES;
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	//if ([tableDocumentInstance isWorking]) return NO;

	return (filterTableIsSwapped && [[tableColumn identifier] integerValue] == 0) ? NO : YES;
}

- (void)tableView:(SPCopyTable *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if (filterTableIsSwapped && [[tableColumn identifier] integerValue] == 0) {
		[cell setDrawsBackground:YES];
		[cell setBackgroundColor:[NSColor lightGrayColor]];
	} else {
		[cell setDrawsBackground:NO];
	}
}

- (NSString *)tableView:(NSTableView *)tableView toolTipForCell:(id)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation
{
	return nil;
}

#pragma mark - Control delegate methods

- (void)controlTextDidChange:(NSNotification *)notification
{
	if ([notification object] == filterTableView) {

		NSString *string = [[[[notification userInfo] objectForKey:@"NSFieldEditor"] textStorage] string];

		if (string && [string length]) {
			if (lastEditedFilterTableValue) [lastEditedFilterTableValue release];

			lastEditedFilterTableValue = [[NSString stringWithString:string] retain];
		}

		[self updateFilterTableClause:string];
	}
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)editor
{
	return YES;
}

- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)aFieldEditor
{
	return YES;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	// Check firstly if SPCopyTable can handle command
	if ([control respondsToSelector:@selector(control:textView:doCommandBySelector:)]) {
		if ([(id)control control:control textView:textView doCommandBySelector:command]) return YES;
	}

	// Trap the escape key
	if ([[control window] methodForSelector:command] == [[control window] methodForSelector:@selector(cancelOperation:)]) {
		// Abort editing
		[control abortEditing];

		return YES;
	}

	return NO;
}

#pragma mark - KVO

/**
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	// a parent class (or cocoa) can also use KVO, so we need to watch out to only catch those KVO messages we requested
	if(context == FilterTableKVOContext) {
		// Display table veiew vertical gridlines preference changed
		if ([keyPath isEqualToString:SPDisplayTableViewVerticalGridlines]) {
			[filterTableView setGridStyleMask:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
		}
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

#pragma mark -

/**
 * Escape passed operator for usage as filterTableDefaultOperator.
 */
+ (NSString*)escapeFilterTableDefaultOperator:(NSString *)op
{
	if (!op) return @"";

	NSMutableString *newOp = [[[NSMutableString alloc] initWithCapacity:[op length]] autorelease];

	[newOp setString:op];
	[newOp replaceOccurrencesOfRegex:@"%" withString:@"%%"];
	[newOp replaceOccurrencesOfRegex:@"(?<!`)@(?!=`)" withString:@"%@"];

	return newOp;
}

@end

