//
//  $Id$
//
//  SPIndexesController.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on June 13, 2010
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

#import "SPIndexesController.h"
#import "SPConstants.h"
#import "SPAlertSheets.h"

@interface SPIndexesController (PrivateAPI)

- (void)_addIndexUsingDetails:(NSDictionary *)indexDetails;
- (void)_removeIndexUsingDeatails:(NSDictionary *)indexDetails;

@end

@implementation SPIndexesController

@synthesize table;
@synthesize connection;

#pragma mark -

/**
 * Init.
 */
- (id)init
{
	if ((self = [super initWithWindowNibName:@"IndexesView"])) {
		
		table = @"";
		
		fields  = [[NSMutableArray alloc] init];
		indexes = [[NSMutableArray alloc] init];
		
		prefs = [NSUserDefaults standardUserDefaults];
	}
	
	return self;
}

/**
 * Nib awakening.
 */
- (void)awakeFromNib
{	
	// Set the index tables view's vertical gridlines if required
	[indexesTableView setGridStyleMask:([prefs boolForKey:SPDisplayTableViewVerticalGridlines]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	
	// Set the strutcture and index view's font
	BOOL useMonospacedFont = [prefs boolForKey:SPUseMonospacedFonts];
	
	for (NSTableColumn *indexColumn in [indexesTableView tableColumns])
	{
		[[indexColumn dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}
	
	[prefs addObserver:self forKeyPath:SPDisplayTableViewVerticalGridlines options:NSKeyValueObservingOptionNew context:NULL];
}

#pragma mark -
#pragma mark IBAction methods

/**
 * Opens the add new index sheet.
 */
- (IBAction)addIndex:(id)sender
{	
	// Check whether a save of the current field row is required.
	if (![tableStructure saveRowOnDeselect]) return;
	
	// Set sheet defaults - key type PRIMARY, key name PRIMARY and disabled
	[indexTypePopUpButton selectItemAtIndex:0];
	[indexNameTextField setEnabled:NO];
	[indexNameTextField setStringValue:@"PRIMARY"];
	
	[[self window] makeFirstResponder:indexedColumnsComboBox];
	
	// Check to see whether a primary key already exists for the table, and if so select an INDEX instead
	for (NSDictionary *field in fields) 
	{
		if ([[field objectForKey:@"Key"] isEqualToString:@"PRI"]) {
			[indexTypePopUpButton selectItemAtIndex:1];
			[indexNameTextField setEnabled:YES];
			[indexNameTextField setStringValue:@""];
			
			[[self window] makeFirstResponder:indexNameTextField];
			
			break;
		}
	}
	
	// Update the default values array and the indexed column fields control
	[indexedColumnsComboBox removeAllItems];
	
	for (NSDictionary *field in fields) 
	{
		[indexedColumnsComboBox addItemWithObjectValue:[field objectForKey:@"Field"]];
	}
	
	// Only show up to ten items in the indexed column fields combo box
	[indexedColumnsComboBox setNumberOfVisibleItems:([fields count] < 10) ? [fields count] : 10];
	
	// Select the first column
	[indexedColumnsComboBox selectItemAtIndex:0];
	
	// Begin the sheet
	[NSApp beginSheet:[self window]
	   modalForWindow:[dbDocument parentWindow] 
		modalDelegate:self
	   didEndSelector:@selector(addIndexSheetDidEnd:returnCode:contextInfo:) 
		  contextInfo:nil];
}

/**
 * Ask the user to confirm that they really want to remove the selected index.
 */
- (IBAction)removeIndex:(id)sender
{
	if (![indexesTableView numberOfSelectedRows]) return;
	
	// Check whether a save of the current fields row is required.
	if (![tableStructure saveRowOnDeselect]) return;
	
	NSInteger index = [indexesTableView selectedRow];
	
	if ((index == -1) || (index > ([indexes count] - 1))) return;
	
	NSString *keyName    =  [[indexes objectAtIndex:index] objectForKey:@"Key_name"];
	NSString *columnName =  [[indexes objectAtIndex:index] objectForKey:@"Column_name"];
	
	BOOL hasForeignKey = NO;
	NSString *constraintName = @"";
	
	// Check to see whether the user is attempting to remove an index that a foreign key constraint depends on
	// thus would result in an error if not dropped before removing the index.
	for (NSDictionary *constraint in [tableData getConstraints])
	{
		for (NSString *column in [constraint objectForKey:@"columns"])
		{
			if ([column isEqualToString:columnName]) {
				hasForeignKey = YES;
				constraintName = [constraint objectForKey:@"name"];
				break;
			}
		}
	}
	
	NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Delete index '%@'?", @"delete index message"), keyName]
									 defaultButton:NSLocalizedString(@"Delete", @"delete button")
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
									   otherButton:nil 
						 informativeTextWithFormat:(hasForeignKey) ? [NSString stringWithFormat:NSLocalizedString(@"The foreign key relationship '%@' has a dependency on this index. This relationship must be removed before the index can be deleted.\n\nAre you sure you want to continue to delete the relationship and the index? This action cannot be undone.", @"delete index and foreign key informative message"), constraintName] : [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the index '%@'? This action cannot be undone.", @"delete index informative message"), keyName]];
	
	[alert setAlertStyle:NSCriticalAlertStyle];
	
	NSArray *buttons = [alert buttons];
	
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"d"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
	
	[alert beginSheetModalForWindow:[dbDocument parentWindow] modalDelegate:self didEndSelector:@selector(removeIndexSheetDidEnd:returnCode:contextInfo:) contextInfo:(hasForeignKey) ? @"removeIndexAndForeignKey" : @"removeIndex"];
}

/**
 * Invoked when user chooses an index type
 */
- (IBAction)chooseIndexType:(id)sender
{
	if ([[indexTypePopUpButton titleOfSelectedItem] isEqualToString:@"PRIMARY KEY"] ) {
		[indexNameTextField setEnabled:NO];
		[indexNameTextField setStringValue:@"PRIMARY"];
	} 
	else {
		[indexNameTextField setEnabled:YES];
		
		if ([[indexNameTextField stringValue] isEqualToString:@"PRIMARY"]) {
			[indexNameTextField setStringValue:@""];
		}
	}
}

/**
 * Close the current sheet
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

#pragma mark -
#pragma mark TableView datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [indexes count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	return [[indexes objectAtIndex:rowIndex] objectForKey:[tableColumn identifier]];	
}

#pragma mark -
#pragma mark TableView delegate methods

/**
 * Performs various interface validation
 */
- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	if ([notification object] == indexesTableView) {
		
		// Check if there is currently an index selected and change button state accordingly
		[removeIndexButton setEnabled:([indexesTableView numberOfSelectedRows] > 0 && [tablesList tableType] == SPTableTypeTable)];
	}
	
}

#pragma mark -
#pragma mark Text field delegate methods

/**
 * Only enable the add button if there is at least one indexed column.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{		
	if ([notification object] == indexedColumnsComboBox) {
		[addIndexButton setEnabled:([[[indexedColumnsComboBox stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] > 0)]; 
	}
}

#pragma mark -
#pragma mark Other methods

/**
 * Sets the current table's fields.
 */
- (void)setFields:(NSArray *)tableFields
{
	[fields removeAllObjects];
	
	[fields setArray:tableFields];
}

/**
 * Sets the current table's indexes.
 */
- (void)setIndexes:(NSArray *)tableIndexes
{
	[indexes removeAllObjects];
	
	[indexes setArray:tableIndexes];
}

/**
 * Process the new index sheet closing, adding the index if appropriate
 */
- (void)addIndexSheetDidEnd:(NSWindow *)theSheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[theSheet orderOut:nil];
	
	if (returnCode == NSOKButton) {
		[dbDocument startTaskWithDescription:NSLocalizedString(@"Adding index...", @"adding index task status message")];
		
		NSMutableDictionary *indexDetails = [NSMutableDictionary dictionary];
		
		[indexDetails setObject:[[indexedColumnsComboBox stringValue] componentsSeparatedByString:@","] forKey:@"IndexedColumns"];
		[indexDetails setObject:[indexNameTextField stringValue] forKey:@"IndexName"];
		[indexDetails setObject:[indexTypePopUpButton titleOfSelectedItem] forKey:@"IndexType"];
		
		if ([NSThread isMainThread]) {
			[NSThread detachNewThreadSelector:@selector(_addIndexUsingDetails:) toTarget:self withObject:indexDetails];
			
			[dbDocument enableTaskCancellationWithTitle:NSLocalizedString(@"Cancel", @"cancel button") callbackObject:self callbackFunction:NULL];				
		} 
		else {
			[self _addIndexUsingDetails:indexDetails];
		}
	}
}

/**
 * Process the remove index sheet closing, performing the delete if the user
 * confirmed the action.
 */
- (void)removeIndexSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	// Order out current sheet to suppress overlapping of sheets
	[[alert window] orderOut:nil];
	
	if (returnCode == NSAlertDefaultReturn) {
		[dbDocument startTaskWithDescription:NSLocalizedString(@"Removing index...", @"removing index task status message")];
				
		NSMutableDictionary *indexDetails = [NSMutableDictionary dictionary];
		
		[indexDetails setObject:[indexes objectAtIndex:[indexesTableView selectedRow]] forKey:@"Index"];
		[indexDetails setObject:[NSNumber numberWithBool:[contextInfo hasSuffix:@"AndForeignKey"]] forKey:@"RemoveForeignKey"];
		
		if ([NSThread isMainThread]) {
			[NSThread detachNewThreadSelector:@selector(_removeIndexUsingDeatails:) toTarget:self withObject:indexDetails];
			
			[dbDocument enableTaskCancellationWithTitle:NSLocalizedString(@"Cancel", @"cancel button") callbackObject:self callbackFunction:NULL];
		} 
		else {
			[self _removeIndexUsingDeatails:indexDetails];
		}
	}
}

/**
 * This method is called as part of Key Value Observing which is used to watch for preference changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	// Display table veiew vertical gridlines preference changed
	if ([keyPath isEqualToString:SPDisplayTableViewVerticalGridlines]) {
		[indexesTableView setGridStyleMask:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	}
	// Use monospaced fonts preference changed
	else if ([keyPath isEqualToString:SPUseMonospacedFonts]) {
		
		BOOL useMonospacedFont = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
		
		for (NSTableColumn *indexColumn in [indexesTableView tableColumns])
		{
			[[indexColumn dataCell] setFont:(useMonospacedFont) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}
		
		[indexesTableView reloadData];
	}
}

/**
 * Menu validation
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{	
	// Remove index
	if ([menuItem action] == @selector(removeIndex:)) {
		return ([indexesTableView numberOfSelectedRows] == 1);
	}
	
	// Reset AUTO_INCREMENT
	if ([menuItem action] == @selector(resetAutoIncrement:)) {		
		return ([indexesTableView numberOfSelectedRows] == 1 
				&& [[indexes objectAtIndex:[indexesTableView selectedRow]] objectForKey:@"Key_name"] 
				&& [[[indexes objectAtIndex:[indexesTableView selectedRow]] objectForKey:@"Key_name"] isEqualToString:@"PRIMARY"]);
	}
	
	return YES;
}

#pragma mark -
#pragma mark Private API methods

/**
 * Adds an index to the current table.
 */
- (void)_addIndexUsingDetails:(NSDictionary *)indexDetails
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Check whether a save of the current fields row is required.
	if (![[tableStructure onMainThread] saveRowOnDeselect]) return;
	
	NSString *indexName = [indexDetails objectForKey:@"IndexName"];
	NSString *indexType = [indexDetails objectForKey:@"IndexType"];
	NSArray *indexedColumns = [indexDetails objectForKey:@"IndexedColumns"];
	
	// Interface validation should prevent this
	if ([indexedColumns count] > 0) {
		
		NSMutableArray *tempIndexedColumns = [[NSMutableArray alloc] init];
		
		if ([indexName isEqualToString:@"PRIMARY"]) {
			indexName = @"";
		} 
		else {
			indexName = ([indexName isEqualToString:@""]) ? @"" : [indexName backtickQuotedString];
		}
		
		// For each column strip leading and trailing whitespace and add it to the temp array
		for (NSString *column in indexedColumns)
		{			
			[tempIndexedColumns addObject:[column stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
		}
		
		// Execute the query
		[connection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ ADD %@ %@ (%@)", [table backtickQuotedString], indexType, indexName, [tempIndexedColumns componentsJoinedAndBacktickQuoted]]];
		
		[tempIndexedColumns release];
		
		// Check for errors, but only if the query wasn't cancelled
		if ([connection queryErrored] && ![connection queryCancelled]) {
			SPBeginAlertSheet(NSLocalizedString(@"Unable to add index", @"add index error message"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [dbDocument parentWindow], self, nil, nil, 
							  [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to add the index.\n\nMySQL said: %@", @"add index error informative message"), [connection getLastErrorMessage]]);
		}
		else {
			[tableData resetAllData];
			[tablesList setStatusRequiresReload:YES];
			
			[tableStructure loadTable:table];
		}
	}
	
	[dbDocument endTask];
	
	[pool drain];
}

/**
 * Removes an index from the current table using the supplied details.
 */
- (void)_removeIndexUsingDeatails:(NSDictionary *)indexDetails
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSDictionary *index   = [indexDetails objectForKey:@"Index"];
	BOOL removeForeignKey = [[indexDetails objectForKey:@"RemoveForeignKey"] boolValue];
	
	// Remove the foreign key dependency before the index if required
	if ([removeForeignKey boolValue]) {
		
		NSString *columnName =  [index objectForKey:@"Column_name"];
		
		NSString *constraintName = @"";
		
		// Check to see whether the user is attempting to remove an index that a foreign key constraint depends on
		// thus would result in an error if not dropped before removing the index.
		for (NSDictionary *constraint in [tableData getConstraints])
		{
			for (NSString *column in [constraint objectForKey:@"columns"])
			{
				if ([column isEqualToString:columnName]) {
					constraintName = [constraint objectForKey:@"name"];
					break;
				}
			}
		}
		
		[connection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ DROP FOREIGN KEY %@", [table backtickQuotedString], [constraintName backtickQuotedString]]];
		
		// Check for errors, but only if the query wasn't cancelled
		if ([connection queryErrored] && ![connection queryCancelled]) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			
			[errorDictionary setObject:NSLocalizedString(@"Unable to delete relation", @"error deleting relation message") forKey:@"title"];
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to delete the relation '%@'.\n\nMySQL said: %@", @"error deleting relation informative message"), constraintName, [connection getLastErrorMessage]] forKey:@"message"];
			
			[[tableStructure onMainThread] showErrorSheetWith:errorDictionary];
		} 
	}
	
	if ([[index objectForKey:@"Key_name"] isEqualToString:@"PRIMARY"]) {
		[connection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ DROP PRIMARY KEY", [table backtickQuotedString]]];
	}
	else {
		[connection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ DROP INDEX %@",
								 [table backtickQuotedString], [[index objectForKey:@"Key_name"] backtickQuotedString]]];
	}
	
	// Check for errors, but only if the query wasn't cancelled
	if ([connection queryErrored] && ![connection queryCancelled]) {
		NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
		
		[errorDictionary setObject:NSLocalizedString(@"Unable to delete index", @"error deleting index message") forKey:@"title"];
		[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to delete the index.\n\nMySQL said: %@", @"error deleting index informative message"), [connection getLastErrorMessage]] forKey:@"message"];
		
		[[tableStructure onMainThread] showErrorSheetWith:errorDictionary];
	} 
	else {
		[tableData resetAllData];
		[tablesList setStatusRequiresReload:YES];
		
		[tableStructure loadTable:table];
	}
	
	[dbDocument endTask];
	
	[pool drain];
}

#pragma mark -

/**
 * Dealloc.
 */
- (void)dealloc
{		
	[table release];
	[indexes release];
	[fields release];
	
	[super dealloc];
}

@end
