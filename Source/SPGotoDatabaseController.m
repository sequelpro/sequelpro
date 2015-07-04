//
//  GotoDatbaseController.m
//  sequel-pro
//
//  Created by Max Lohrmann on 12.10.14.
//  Copyright (c) 2014 Max Lohrmann. All rights reserved.
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

#import "SPGotoDatabaseController.h"

@interface SPGotoDatabaseController (Private)

/** Update the list of matched names
 * @param filter     The string to be matched.
 * @param exactMatch Will be set to YES if there is at least one entry in 
 *                   unfilteredList that is equivalent to filter. Can be NULL to disable.
 *
 * This method will take every item in the unfilteredList and add matching items 
 * to the filteredList, including highlighting.
 * It will neither clear the filteredList first, nor change the isFiltered ivar!
 * Search is case insensitive.
 */
- (void)_buildHightlightedFilterList:(NSString *)filter didFindExactMatch:(BOOL *)exactMatch;

- (IBAction)okClicked:(id)sender;
- (IBAction)cancelClicked:(id)sender;
- (IBAction)searchChanged:(id)sender;
- (IBAction)toggleWordSearch:(id)sender;

- (BOOL)qualifiesForWordSearch:(NSString *)s;
- (BOOL)qualifiesForWordSearch; //takes s from searchField
@end

@implementation SPGotoDatabaseController

@synthesize allowCustomNames;

- (id)init
{
    if ((self = [super initWithWindowNibName:@"GotoDatabaseDialog"])) {
        unfilteredList = [[NSMutableArray alloc] init];
		filteredList   = [[NSMutableArray alloc] init];
		isFiltered     = NO;

		[self setAllowCustomNames:YES];
    }

    return self;
}

- (void)windowDidLoad {
	// Handle a double click in the DB list the same as if OK was clicked.
	[databaseListView setTarget:self];
	[databaseListView setDoubleAction:@selector(okClicked:)];
}

#pragma mark -
#pragma mark IBAction

- (IBAction)okClicked:(id)sender
{
	[NSApp stopModalWithCode:YES];

	[[self window] orderOut:nil];
}

- (IBAction)cancelClicked:(id)sender
{
	[NSApp stopModalWithCode:NO];

	[[self window] orderOut:nil];
}

- (IBAction)searchChanged:(id)sender
{
	[filteredList removeAllObjects];

	NSString *newFilter = [searchField stringValue];

	if (!newFilter || [newFilter isEqualToString:@""]) {
		isFiltered = NO;
	}
	else {
		isFiltered = YES;

		BOOL exactMatch = NO;

		[self _buildHightlightedFilterList:newFilter didFindExactMatch:&exactMatch];

		//always add the search string to the end of the list (in case the user
		//wants to switch to a DB not in the list) unless there was an exact match
		if ([self allowCustomNames] && !exactMatch) {
			NSMutableAttributedString *searchValue = [[NSMutableAttributedString alloc] initWithString:newFilter];

			[searchValue applyFontTraits:NSItalicFontMask range:NSMakeRange(0, [newFilter length])];

			[filteredList addObject:[searchValue autorelease]];
		}
	}

	[databaseListView reloadData];

	// Ensure we have a selection
	if ([databaseListView selectedRow] < 0) {
		[databaseListView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	}
	
	[okButton setEnabled:([databaseListView selectedRow] >= 0)];
}

- (IBAction)toggleWordSearch:(id)sender
{
	//if the search field is empty just add two " and put the caret in-between
	if(![[searchField stringValue] length]) {
		[searchField setStringValue:@"\"\""];
		[[searchField currentEditor] setSelectedRange:NSMakeRange(1, 0)];

	}
	else if (![self qualifiesForWordSearch]) {
		[searchField setStringValue:[NSString stringWithFormat:@"\"%@\"",[searchField stringValue]]];
		//change the selection to be inside the quotes
		[[searchField currentEditor] setSelectedRange:NSMakeRange(1, [[searchField stringValue] length]-2)];
	}
	else {
		NSString *str = [searchField stringValue];
		[searchField setStringValue:[str substringWithRange:NSMakeRange(1, [str length]-2)]];
	}
	[self searchChanged:nil];
}

#pragma mark -
#pragma mark Public

- (NSString *)selectedDatabase
{
	NSInteger row = [databaseListView selectedRow];

	id attrValue;

	if (isFiltered) {
		attrValue = [filteredList objectOrNilAtIndex:row];
	}
	else {
		attrValue = [unfilteredList objectOrNilAtIndex:row];
	}

	if ([attrValue isKindOfClass:[NSAttributedString class]]) {
		return [attrValue string];
	}

	return attrValue;
}

- (void)setDatabaseList:(NSArray *)list
{
	// Update list of databases
	[unfilteredList removeAllObjects];
	[unfilteredList addObjectsFromArray:list];
}

- (BOOL)runModal
{
	// NSWindowController is lazy with loading nibs
	[self window];
	
	// Reset the search field
	[searchField setStringValue:@""];
	[self searchChanged:nil];

	// Give focus to search field
	[[self window] makeFirstResponder:searchField];

	// Start modal dialog
	return [NSApp runModalForWindow:[self window]];
}

#pragma mark -
#pragma mark Private

- (void)_buildHightlightedFilterList:(NSString *)filter didFindExactMatch:(BOOL *)exactMatch
{
	NSDictionary *attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
						   [NSColor colorWithCalibratedRed:249/255.0 green:247/255.0 blue:62/255.0 alpha:0.5],NSBackgroundColorAttributeName,
						   [NSColor colorWithCalibratedRed:180/255.0 green:164/255.0 blue:31/255.0 alpha:1.0],NSUnderlineColorAttributeName,
						   [NSNumber numberWithInt:NSUnderlineStyleSingle],NSUnderlineStyleAttributeName,
						   nil];

	NSStringCompareOptions opts = NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch|NSWidthInsensitiveSearch;
	
	// interpret a quoted string as 'looking for exact submachtes only'
	if([self qualifiesForWordSearch:filter]) {
		//remove quotes for matching
		filter = [filter substringWithRange:NSMakeRange(1, [filter length]-2)];
		
		//look for matches
		for (NSString *db in unfilteredList) {
			NSRange matchRange = [db rangeOfString:filter options:opts];
			
			if(matchRange.location == NSNotFound) continue;
			
			// Should we check for exact match AND have not yet found one?
			if (exactMatch && !*exactMatch) {
				if (matchRange.location == 0 && matchRange.length == [db length]) {
					*exactMatch = YES;
				}
			}
			
			NSMutableAttributedString *attrMatch = [[NSMutableAttributedString alloc] initWithString:db];
			[attrMatch setAttributes:attrs range:matchRange];
			[filteredList addObject:[attrMatch autorelease]];
		}
	}
	// default to a per-character search
	else {
		for (NSString *db in unfilteredList) {
			
			NSArray *matches = nil;
			BOOL hasMatch = [db nonConsecutivelySearchString:filter matchingRanges:&matches];
			
			if(!hasMatch) continue;
			
			// Should we check for exact match AND have not yet found one?
			if (exactMatch && !*exactMatch) {
				if([matches count] == 1) {
					NSRange match = [(NSValue *)[matches objectAtIndex:0] rangeValue];
					if (match.location == 0 && match.length == [db length]) {
						*exactMatch = YES;
					}
				}
			}
			
			NSMutableAttributedString *attrMatch = [[NSMutableAttributedString alloc] initWithString:db];
			
			for (NSValue *matchValue in matches) {
				[attrMatch setAttributes:attrs range:[matchValue rangeValue]];
			}
			
			[filteredList addObject:[attrMatch autorelease]];
		}
	}
	
	[attrs release];
}

- (BOOL)qualifiesForWordSearch:(NSString *)s
{
	return (s && ([s length] > 1) && (([s hasPrefix:@"\""] && [s hasSuffix:@"\""]) || ([s hasPrefix:@"'"] && [s hasSuffix:@"'"])));
}

- (BOOL)qualifiesForWordSearch
{
	return [self qualifiesForWordSearch:[searchField stringValue]];
}

#pragma mark -
#pragma mark NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if (!isFiltered) {
		return [unfilteredList count];
	}
	else {
		return [filteredList count];
	}
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if (!isFiltered) {
		return [unfilteredList objectAtIndex:rowIndex];
	}
	else {
		return [filteredList objectAtIndex:rowIndex];
	}
}

#pragma mark -
#pragma mark NSControlTextEditingDelegate

- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector
{
	// The ESC key will usually clear the search field. we want to close the dialog
	if (commandSelector == @selector(cancelOperation:)) {
		[cancelButton performClick:control];
		return YES;
	}

	// Arrow down/up will usually go to start/end of the text field. we want to change the selected table row.
	if (commandSelector == @selector(moveDown:)) {
		[databaseListView selectRowIndexes:[NSIndexSet indexSetWithIndex:([databaseListView selectedRow]+1)] byExtendingSelection:NO];
		return YES;
	}

	if (commandSelector == @selector(moveUp:)) {
		[databaseListView selectRowIndexes:[NSIndexSet indexSetWithIndex:([databaseListView selectedRow]-1)] byExtendingSelection:NO];
		return YES;
	}

	// Forward return to OK button (enter will not be caught by search field)
	if (commandSelector == @selector(insertNewline:)) {
		[okButton performClick:control];
		return YES;
	}
	
	return NO;
}

#pragma mark -
#pragma mark NSUserInterfaceValidations

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
	if([anItem action] == @selector(toggleWordSearch:)) {
		[(NSMenuItem *)anItem setState:([self qualifiesForWordSearch]? NSOnState : NSOffState)];
	}
	return YES;
}

#pragma mark -

- (void)dealloc
{
    SPClear(unfilteredList);
	SPClear(filteredList);

	[super dealloc];
}

@end
