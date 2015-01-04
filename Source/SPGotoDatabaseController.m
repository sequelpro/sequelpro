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

	for (NSString *db in unfilteredList) {
		// Let's just assume it is in the users interest (most of the time) for searches to be CI.
		NSRange match = [db rangeOfString:filter options:NSCaseInsensitiveSearch];

		if (match.location == NSNotFound) continue;

		// Should we check for exact match AND have not yet found one?
		if (exactMatch && !*exactMatch) {
			if (match.location == 0 && match.length == [db length]) {
				*exactMatch = YES;
			}
		}
		
		NSMutableAttributedString *attrMatch = [[NSMutableAttributedString alloc] initWithString:db];

		[attrMatch setAttributes:attrs range:match];

		[filteredList addObject:[attrMatch autorelease]];
	}
	
	[attrs release];
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

- (void)dealloc
{
    SPClear(unfilteredList);
	SPClear(filteredList);

	[super dealloc];
}

@end
