//
//  SPIndexesController.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on June 13, 2010.
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

#import "SPIndexesController.h"
#import "SPAlertSheets.h"
#import "SPServerSupport.h"
#import "SPTableContent.h"
#import "SPTableData.h"
#import "SPDatabaseDocument.h"
#import "SPTablesList.h"
#import "SPTableView.h"
#import "SPDatabaseViewController.h"
#import "SPTableStructure.h"
#import "SPTableStructureLoading.h"
#import "SPThreadAdditions.h"

#import <SPMySQL/SPMySQL.h>

// Constants
static const NSString *SPNewIndexIndexName      = @"IndexName";
static const NSString *SPNewIndexIndexType      = @"IndexType";
static const NSString *SPNewIndexIndexedColumns = @"IndexedColumns";
static const NSString *SPNewIndexStorageType    = @"IndexStorageType";
static const NSString *SPNewIndexKeyBlockSize   = @"IndexKeyBlockSize";

@interface SPIndexesController ()

- (BOOL)_isFullTextIndexSelected;
- (void)_addAdditionalIndexTypes;
- (void)_reloadIndexedColumnsTableData;
- (void)_addIndexUsingDetails:(NSDictionary *)indexDetails;
- (void)_removeIndexUsingDetails:(NSDictionary *)indexDetails;
- (void)_resizeWindowForAdvancedOptionsViewByHeightDelta:(NSInteger)delta;

@end

@implementation SPIndexesController

@synthesize table;
@synthesize connection;

#pragma mark -

- (id)init
{
	if ((self = [super initWithWindowNibName:@"IndexesView"])) {
		mainNibLoaded = NO;
		table = @"";

		fields  = [[NSMutableArray alloc] init];
		indexes = [[NSMutableArray alloc] init];
		indexedFields = [[NSMutableArray alloc] init];

		prefs = [NSUserDefaults standardUserDefaults];

		showAdvancedView = NO;

		heightOffset = 0;
		windowMinWidth = [[self window] minSize].width;
		windowMinHeigth = [[self window] minSize].height;

		// Create an array of field types that supporting specifying an index length prefix
		supportsLength = [[NSArray alloc] initWithObjects:
						  @"CHAR", @"VARCHAR", @"TINYTEXT", @"TEXT", @"MEDIUMTEXT", @"LONGTEXT",
						  @"BINARY", @"VARBINARY", @"TINYBLOB", @"BLOB", @"MEDIUMBLOB", @"LONGBLOB", nil];

		// Create an array of field types that require an index length prefix
		requiresLength = [[NSArray alloc] initWithObjects:
						  @"TINYTEXT", @"TEXT", @"MEDIUMTEXT", @"LONGTEXT",
						  @"TINYBLOB", @"BLOB", @"MEDIUMBLOB", @"LONGBLOB", nil];
	}

	return self;
}

- (void)awakeFromNib
{
	// As this controller also loads its own nib, it may call awakeFromNib multiple times; perform setup only once.
	if (mainNibLoaded) return;
	mainNibLoaded = YES;

	// Set the index tables view's vertical gridlines if required
	[indexesTableView setGridStyleMask:([prefs boolForKey:SPDisplayTableViewVerticalGridlines]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];

	// Set the strutcture and index view's font
	BOOL useMonospacedFont = [prefs boolForKey:SPUseMonospacedFonts];

	CGFloat monospacedFontSize = [prefs floatForKey:SPMonospacedFontSize] > 0 ? [prefs floatForKey:SPMonospacedFontSize] : [NSFont smallSystemFontSize];

	// Set the double-click action in blank areas of the table to create new rows
	[indexesTableView setEmptyDoubleClickAction:@selector(addIndex:)];

	for (NSTableColumn *indexColumn in [indexesTableView tableColumns])
	{
		[[indexColumn dataCell] setFont:useMonospacedFont ? [NSFont fontWithName:SPDefaultMonospacedFontName size:monospacedFontSize] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}

	for (NSTableColumn *fieldColumn in [indexedColumnsTableView tableColumns])
	{
		[[fieldColumn dataCell] setFont:useMonospacedFont ? [NSFont fontWithName:SPDefaultMonospacedFontName size:monospacedFontSize] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	}

	[prefs addObserver:self forKeyPath:SPDisplayTableViewVerticalGridlines options:NSKeyValueObservingOptionNew context:NULL];
}

#pragma mark -
#pragma mark IB action methods

/**
 * Opens the add new index sheet.
 */
- (IBAction)addIndex:(id)sender
{
	// Check whether table editing is permitted (necessary as some actions - eg table double-click - bypass validation)
	if ([dbDocument isWorking] || [tablesList tableType] != SPTableTypeTable) return;
	
	// Check whether a save of the current field row is required.
	if (![tableStructure saveRowOnDeselect]) return;

	isMyISAMTable = [[tableData statusValueForKey:@"Engine"] isEqualToString:@"MyISAM"];
	isInnoDBTable = [[tableData statusValueForKey:@"Engine"] isEqualToString:@"InnoDB"];
	
	// Reset visibility of the primary key item
	[[[indexTypePopUpButton menu] itemWithTag:SPPrimaryKeyMenuTag] setHidden:NO];

	// Set sheet defaults - key type PRIMARY, key name PRIMARY and disabled
	[indexTypePopUpButton selectItemWithTag:SPPrimaryKeyMenuTag];
	[indexNameTextField setEnabled:NO];
	[indexNameTextField setStringValue:@"PRIMARY"];

	[self _addAdditionalIndexTypes];
	
	// Check to see whether a primary key already exists for the table, and if so select INDEX instead
	for (NSDictionary *field in fields)
	{
		if ([[field objectForKey:@"isprimarykey"] boolValue]) {

			// Hide primary key option
			[[[indexTypePopUpButton menu] itemWithTag:SPPrimaryKeyMenuTag] setHidden:YES];

			// Select INDEX type
			[indexTypePopUpButton selectItemWithTag:SPIndexMenuTag];
			[indexNameTextField setEnabled:YES];
			[indexNameTextField setStringValue:@""];

			[[self window] makeFirstResponder:indexNameTextField];

			break;
		}
	}
	
	NSMutableArray *indexedFieldNames = [[NSMutableArray alloc] init];
	
	// Build an array of all indexed column names
	for (NSDictionary *index in indexes)
	{
		[indexedFieldNames addObject:[index objectForKey:@"Column_name"]];
	}
	
	NSDictionary *initialField = nil;
	
	// Select the first column as the initial field that doesn't already have an index
	for (NSDictionary *field in fields)
	{
		if (![indexedFieldNames containsObject:[field objectForKey:@"name"]]) {
			initialField = [[field mutableCopy] autorelease];
			break;
		}
	}

	// If no initial field has been selected yet - all fields are indexed - add the first field.
	if (!initialField) initialField = [fields objectAtIndex:0];
	
	if (indexedFieldNames) SPClear(indexedFieldNames);

	// Reset the indexed columns
	[indexedFields removeAllObjects];
	[indexedFields addObject:initialField];

	// Determine whether to show or hide the size column initially depending on whether the
	// initial key has a required size
	[indexSizeTableColumn setHidden:![requiresLength containsObject:[[initialField objectForKey:@"type"] uppercaseString]]];

	[self _reloadIndexedColumnsTableData];

	[addIndexedColumnButton setEnabled:([indexedFields count] < [fields count])];

	// MyISAM and InnoDB tables only support BTREE storage types so disable the storage type popup button
	// as it's the default anyway.
	[indexStorageTypePopUpButton setEnabled:(!(isMyISAMTable || isInnoDBTable))];

	// The ability to specify an index's key block size was added in MySQL 5.1.10 so disable the textfield
	// if it's not supported.
	[indexKeyBlockSizeTextField setEnabled:[[dbDocument serverSupport] supportsIndexKeyBlockSize]];

	// Begin the sheet
	[NSApp beginSheet:[self window]
	   modalForWindow:[dbDocument parentWindow]
		modalDelegate:self
	   didEndSelector:@selector(addIndexSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];

	// Because there is only one indexed column initially, disable the remove button
	[removeIndexedColumnButton setEnabled:NO];
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

	if ((index == -1) || (index > ((NSInteger)[indexes count] - 1))) return;

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
						 informativeTextWithFormat:hasForeignKey ? NSLocalizedString(@"The foreign key relationship '%@' has a dependency on this index. This relationship must be removed before the index can be deleted.\n\nAre you sure you want to continue to delete the relationship and the index? This action cannot be undone.", @"delete index and foreign key informative message"), constraintName : NSLocalizedString(@"Are you sure you want to delete the index '%@'? This action cannot be undone.", @"delete index informative message"), keyName];

	[alert setAlertStyle:NSCriticalAlertStyle];

	NSArray *buttons = [alert buttons];

	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"d"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];

	[alert beginSheetModalForWindow:[dbDocument parentWindow]
					  modalDelegate:self
					 didEndSelector:@selector(removeIndexSheetDidEnd:returnCode:contextInfo:)
						contextInfo:(hasForeignKey) ? @"removeIndexAndForeignKey" : @"removeIndex"];
}

/**
 * Invoked when user chooses an index type
 */
- (IBAction)chooseIndexType:(id)sender
{
	NSInteger indexType = [[indexTypePopUpButton selectedItem] tag];
	
	if (indexType == SPPrimaryKeyMenuTag) {
		[indexNameTextField setEnabled:NO];
		[indexNameTextField setStringValue:@"PRIMARY"];
		[indexStorageTypePopUpButton setEnabled:NO];
	}
	else {
		[indexNameTextField setEnabled:YES];

		if ([[indexNameTextField stringValue] isEqualToString:@"PRIMARY"]) {
			[indexNameTextField setStringValue:@""];
		}

		// Specifiying an index storage type (i.e. HASH or BTREE) is not permitted with SPATIAL indexes
		[indexStorageTypePopUpButton setEnabled:(indexType != SPSpatialMenuTag) && !(isMyISAMTable || isInnoDBTable)];
	}
	
	[indexSizeTableColumn setHidden:[self _isFullTextIndexSelected]];

	[self _reloadIndexedColumnsTableData];
}

/**
 * Close the current sheet.
 */
- (IBAction)closeSheet:(id)sender
{
	// Close the advanced options view if it's open
	[indexAdvancedOptionsView setHidden:YES];
	[indexAdvancedOptionsViewButton setState:NSOffState];
	showAdvancedView = NO;

	// Hide the size column
	[indexSizeTableColumn setHidden:YES];

	[self _resizeWindowForAdvancedOptionsViewByHeightDelta:0];

	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];

	// Clear the index key block size field
	[indexKeyBlockSizeTextField setStringValue:@""];
}

/**
 * Adds a new field to be included in the index.
 */
- (IBAction)addIndexedField:(id)sender
{
	if ([indexedFields count] <= ([fields count] - 1)) {

		// Add a field that hasn't already been added
		for (NSDictionary *field in fields)
		{
			if (![indexedFields containsObject:field]) {
				[indexedFields addObject:[[field mutableCopy] autorelease]];
				break;
			}
		}

		// If the field type is foud within the requires length array then a length prefix is required so
		// display the size column.
		if ([requiresLength containsObject:[[[indexedFields objectAtIndex:([indexedFields count] - 1)] objectForKey:@"type"] uppercaseString]]) [indexSizeTableColumn setHidden:NO];
	}

	[self _reloadIndexedColumnsTableData];

	// Select new added row
	[indexedColumnsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[indexedFields count]-1] byExtendingSelection:NO];

	[addIndexedColumnButton setEnabled:([indexedFields count] < [fields count])];
}

/**
 * Removes a field from those that are to be included in the index.
 */
- (IBAction)removeIndexedField:(id)sender
{
	[indexedFields removeObjectAtIndex:[indexedColumnsTableView selectedRow]];

	[self _reloadIndexedColumnsTableData];

	[addIndexedColumnButton setEnabled:([indexedFields count] < [fields count])];
}

/**
 * Toggles the display of the advanced options view.
 */
- (IBAction)toggleAdvancedIndexOptionsView:(id)sender
{
	showAdvancedView = (!showAdvancedView);

	[indexAdvancedOptionsViewButton setState:showAdvancedView];
	[indexAdvancedOptionsView setHidden:(!showAdvancedView)];

	// When hiding the advanced options, the size column would normally be hidden as well
	// - unless any of the ndexes fields have a required key size.
	BOOL hideSizesColumn = !showAdvancedView;
	
	if (hideSizesColumn) {
		for (NSDictionary *aField in indexedFields) 
		{
			if ([requiresLength containsObject:[[aField objectForKey:@"type"] uppercaseString]]) hideSizesColumn = NO;
		}
	}
	
	[indexSizeTableColumn setHidden:hideSizesColumn];

	[self _resizeWindowForAdvancedOptionsViewByHeightDelta:showAdvancedView ? ([indexAdvancedOptionsView frame].size.height + 10) : 0];
}

#pragma mark -
#pragma mark TableView datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return (tableView == indexesTableView) ? [indexes count] : [indexedFields count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{

	if (tableView == indexesTableView) {
	 	return [[indexes objectAtIndex:rowIndex] objectForKey:[tableColumn identifier]];
	}
	else {
		id object = [[indexedFields objectAtIndex:rowIndex] objectForKey:[tableColumn identifier]];
		
		if ([[tableColumn identifier] isEqualToString:@"Size"] && object) {
			object = [NSNumber numberWithLongLong:[object longLongValue]];
		}
		
		return object;
	}
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if (tableView == indexesTableView) return;

	if ([[tableColumn identifier] isEqualToString:@"name"]) {
		
		// Iterate to given fields to replace the correct desired index field dictionary
		for (NSDictionary *dic in fields) 
		{
			if ([[dic objectForKey:@"name"] isEqualToString:object]) {
				[indexedFields replaceObjectAtIndex:rowIndex withObject:dic];
				break;
			}
		}
	}
	else {

		// Ensure conversion to string for Size column and its formatter
		if ([object isKindOfClass:[NSNumber class]]) {
			object = [NSString stringWithFormat:@"%llu", [object unsignedLongLongValue]];
		}
		
		if (object) {
			[[indexedFields objectAtIndex:rowIndex] setObject:object forKey:[tableColumn identifier]];
		} 
		else {
			[[indexedFields objectAtIndex:rowIndex] removeObjectForKey:[tableColumn identifier]];
		}
	}

	[self _reloadIndexedColumnsTableData];
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if ([[tableColumn identifier] isEqualToString:@"Size"]) {

		// If the field is of type TEXT or BLOB then a index prefix length is required so change the default
		// placeholder of 'optional' to 'required', BUT only if the index type is not FULLTEXT.
		BOOL isFullTextType = [self _isFullTextIndexSelected];
		
		[cell setPlaceholderString:([requiresLength containsObject:[[[indexedFields objectAtIndex:rowIndex] objectForKey:@"type"] uppercaseString]] && !isFullTextType) ? NSLocalizedString(@"required", @"required placeholder string") : NSLocalizedString(@"optional", @"optional placeholder string")];
	}
}

#pragma mark -
#pragma mark ComboBoxCell datasource methods

/**
 * Returns the number items that are to be shown in the combo box cell.
 */
- (NSInteger)numberOfItemsInComboBoxCell:(NSComboBoxCell *)comboBoxCell
{
	return [fields count] - [indexedFields count];
}

/**
 * Returns the item to be displayed in the combo box cell as the supplied index.
 */
- (id)comboBoxCell:(NSComboBoxCell *)comboBoxCell objectValueForItemAtIndex:(NSInteger)index
{	
	NSMutableArray *availableFields = [fields mutableCopy];
	
	[availableFields removeObjectsInArray:indexedFields];
	
	NSString *name = [[availableFields objectAtIndex:index] objectForKey:@"name"];
	
	SPClear(availableFields);
	
	return name;
}

#pragma mark -
#pragma mark TableView delegate methods

/**
 * UI control validation.
 */
- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	if ([notification object] == indexesTableView) {

		// Check if there is currently an index selected and change button state accordingly
		[removeIndexButton setEnabled:([indexesTableView numberOfSelectedRows] > 0 && [tablesList tableType] == SPTableTypeTable)];
	}
	else if ([notification object] == indexedColumnsTableView) {
		[removeIndexedColumnButton setEnabled:(([indexedFields count] > 1) && ([indexedColumnsTableView numberOfSelectedRows] == 1))];
	}
}

#pragma mark -
#pragma mark Accessor methods

/**
 * Sets the current table's fields.
 *
 * @param tableFields An array of table fields (NSDictionary instances)
 */
- (void)setFields:(NSArray *)tableFields
{
	[fields removeAllObjects];

	[fields setArray:tableFields];

	[indexedFields removeAllObjects];

	if ([fields count]) [indexedFields addObject:[[[fields objectAtIndex:0] mutableCopy] autorelease]];
}

/**
 * Sets the current table's indexes.
 *
 * @param tableIndexes An array of table indexes (NSDictionary instances)
 */
- (void)setIndexes:(NSArray *)tableIndexes
{
	[indexes removeAllObjects];

	[indexes setArray:tableIndexes];
}

#pragma mark -
#pragma mark Other methods

/**
 * Process the new index sheet closing, adding the index if appropriate
 */
- (void)addIndexSheetDidEnd:(NSWindow *)theSheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[theSheet orderOut:nil];

	if (returnCode == NSOKButton) {
		[dbDocument startTaskWithDescription:NSLocalizedString(@"Adding index...", @"adding index task status message")];

		NSUInteger i, j;
		NSMutableDictionary *indexDetails = [NSMutableDictionary dictionary];

		// Loop the indexed fields array and remove duplicates
		NSArray *copy = [indexedFields copy];

		for (i = ([copy count] - 1); i > 0; i--)
		{
			NSString *field = [[copy objectAtIndex:i] objectForKey:@"name"];

			for (j = 0; j < i; j++)
			{
				if ([[[copy objectAtIndex:j] objectForKey:@"name"] isEqualToString:field]) {
					[indexedFields removeObjectAtIndex:i];
				}
			}
		}

		SPClear(copy);

		// In the event that we removed duplicate columns reload the table view to ensure that the next time
		// it is open we don't cause the table view to ask for rows that no longer exist.
		[indexedColumnsTableView reloadData];

		[indexDetails setObject:indexedFields forKey:SPNewIndexIndexedColumns];
		[indexDetails setObject:[indexNameTextField stringValue] forKey:SPNewIndexIndexName];

		switch ([[indexTypePopUpButton selectedItem] tag]) 
		{
			case SPPrimaryKeyMenuTag:
				[indexDetails setObject:@"PRIMARY KEY" forKey:SPNewIndexIndexType];
				break;
			case SPIndexMenuTag:
				[indexDetails setObject:@"INDEX" forKey:SPNewIndexIndexType];
				break;
			case SPUniqueMenuTag:
				[indexDetails setObject:@"UNIQUE" forKey:SPNewIndexIndexType];
				break;
			case SPFullTextMenuTag:
				[indexDetails setObject:@"FULLTEXT" forKey:SPNewIndexIndexType];
				break;
			case SPSpatialMenuTag:
				[indexDetails setObject:@"SPATIAL" forKey:SPNewIndexIndexType];
				break;
		}

		// If there is a key block size set it means the database version supports it
		if ([[indexKeyBlockSizeTextField stringValue] length]) {
			[indexDetails setObject:[NSNumber numberWithInteger:[indexKeyBlockSizeTextField integerValue]] forKey:SPNewIndexKeyBlockSize];
		}

		if (([indexStorageTypePopUpButton indexOfSelectedItem] > 0) && ([[indexTypePopUpButton selectedItem] tag] != SPSpatialMenuTag)) {
			[indexDetails setObject:[indexStorageTypePopUpButton titleOfSelectedItem] forKey:SPNewIndexStorageType];
		}

		if ([NSThread isMainThread]) {
			[NSThread detachNewThreadWithName:SPCtxt(@"SPIndexesController index creation thread", dbDocument) target:self selector:@selector(_addIndexUsingDetails:) object:indexDetails];

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
		[indexDetails setObject:[NSNumber numberWithBool:[(NSString *)contextInfo hasSuffix:@"AndForeignKey"]] forKey:@"RemoveForeignKey"];

		if ([NSThread isMainThread]) {
			[NSThread detachNewThreadWithName:SPCtxt(@"SPIndexesController index removal thread", dbDocument) target:self selector:@selector(_removeIndexUsingDetails:) object:indexDetails];

			[dbDocument enableTaskCancellationWithTitle:NSLocalizedString(@"Cancel", @"cancel button") callbackObject:self callbackFunction:NULL];
		}
		else {
			[self _removeIndexUsingDetails:indexDetails];
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
		CGFloat monospacedFontSize = [prefs floatForKey:SPMonospacedFontSize] > 0 ? [prefs floatForKey:SPMonospacedFontSize] : [NSFont smallSystemFontSize];

		for (NSTableColumn *indexColumn in [indexesTableView tableColumns])
		{
			[[indexColumn dataCell] setFont:useMonospacedFont ? [NSFont fontWithName:SPDefaultMonospacedFontName size:monospacedFontSize] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}

		for (NSTableColumn *indexColumn in [indexedColumnsTableView tableColumns])
		{
			[[indexColumn dataCell] setFont:useMonospacedFont ? [NSFont fontWithName:SPDefaultMonospacedFontName size:monospacedFontSize] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		}

		[indexesTableView reloadData];

		[self _reloadIndexedColumnsTableData];
	}
}

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// Remove index
	if ([menuItem action] == @selector(removeIndex:)) {
		return [indexesTableView numberOfSelectedRows] == 1;
	}

	// Reset AUTO_INCREMENT
	if ([menuItem action] == @selector(resetAutoIncrement:)) {
		return ([indexesTableView numberOfSelectedRows] == 1
				&& [[indexes objectAtIndex:[indexesTableView selectedRow]] objectForKey:@"Key_name"]
				&& [[[indexes objectAtIndex:[indexesTableView selectedRow]] objectForKey:@"Key_name"] isEqualToString:@"PRIMARY"]);
	}

	// Remove indexed field
	if ([menuItem action] == @selector(removeIndexedField:)) {
		return (([indexedFields count] > 1) && ([indexedColumnsTableView numberOfSelectedRows] == 1));
	}

	return YES;
}

#pragma mark -
#pragma mark Private API methods

/**
 * Is the currently selected index type FULLTEXT.
 */
- (BOOL)_isFullTextIndexSelected
{
	return [indexTypePopUpButton selectedTag] == SPFullTextMenuTag;
}

/**
 * Adds any additional index types depending on the table type.
 */
- (void)_addAdditionalIndexTypes
{	
	if ([indexTypePopUpButton indexOfItemWithTag:SPSpatialMenuTag] > -1) {
		[indexTypePopUpButton removeItemAtIndex:[indexTypePopUpButton indexOfItemWithTag:SPSpatialMenuTag]];
	}
	
	if ([indexTypePopUpButton indexOfItemWithTag:SPFullTextMenuTag] > -1) {
		[indexTypePopUpButton removeItemAtIndex:[indexTypePopUpButton indexOfItemWithTag:SPFullTextMenuTag]];
	}
	
	// SPATIAL index types are only available using the MyISAM engine
	if (isMyISAMTable) {
		if ([[dbDocument serverSupport] supportsSpatialExtensions]) {
			NSMenuItem *spatialMenuItem = [[[NSMenuItem alloc] init] autorelease];
			
			[spatialMenuItem setTitle:NSLocalizedString(@"SPATIAL", @"spatial index menu item title")];
			[spatialMenuItem setTag:SPSpatialMenuTag];
			
			[[indexTypePopUpButton menu] addItem:spatialMenuItem];
		}
	}
	
	// FULLTEXT only works with MyISAM and (InnoDB since 5.6.4)
	if (isMyISAMTable || (isInnoDBTable && [[dbDocument serverSupport] supportsFulltextOnInnoDB])) {
		NSMenuItem *fullTextMenuItem = [[[NSMenuItem alloc] init] autorelease];
		
		[fullTextMenuItem setTitle:NSLocalizedString(@"FULLTEXT", @"full text index menu item title")];
		[fullTextMenuItem setTag:SPFullTextMenuTag];
		
		[[indexTypePopUpButton menu] addItem:fullTextMenuItem];
	}
}

/**
 * Reloads the indexed columns table view data and displays the size column if required.
 */
- (void)_reloadIndexedColumnsTableData
{
	NSUInteger sizeRequiredFieldAndNotYetSet = 0;
	NSUInteger sizeRequired = 0;

	BOOL isFullTextType = [self _isFullTextIndexSelected];

	for (NSDictionary *field in indexedFields) 
	{
		if (!isFullTextType && [requiresLength containsObject:[[field objectForKey:@"type"] uppercaseString]]) {
			sizeRequired++;
			sizeRequiredFieldAndNotYetSet++;
			
			if ([field objectForKey:@"Size"] && [(NSString *)[field objectForKey:@"Size"] length]) {
				sizeRequiredFieldAndNotYetSet--;
			}
		}
	}

	// Only toggle the sizes column if the advanced view is hidden and at least one field requires a size
	if (!showAdvancedView) [indexSizeTableColumn setHidden:!sizeRequired];

	// Validate Add Button
	[confirmAddIndexButton setEnabled:!sizeRequiredFieldAndNotYetSet];

	[indexedColumnsTableView reloadData];
}

/**
 * Adds an index to the current table.
 *
 * @param indexDeatails A dictionary containing the details of the new index to be added
 */
- (void)_addIndexUsingDetails:(NSDictionary *)indexDetails
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	// Check whether a save of the current fields row is required.
	if (![[tableStructure onMainThread] saveRowOnDeselect]) return;

	// Retrieve index details
	NSString *indexName         = [indexDetails objectForKey:SPNewIndexIndexName];
	NSString *indexType         = [indexDetails objectForKey:SPNewIndexIndexType];
	NSString *indexStorageType  = [indexDetails objectForKey:SPNewIndexStorageType];
	NSNumber *indexKeyBlockSize = [indexDetails objectForKey:SPNewIndexKeyBlockSize];
	NSArray *indexedColumns     = [indexDetails objectForKey:SPNewIndexIndexedColumns];

	// Interface validation should prevent this, but just to be safe
	if ([indexedColumns count] > 0) {

		NSMutableArray *tempIndexedColumns = [[NSMutableArray alloc] init];

		if ([indexType isEqualToString:@"PRIMARY KEY"]) {
			indexName = @"";
		}
		else {
			indexName = ([indexName isEqualToString:@""]) ? @"" : [indexName backtickQuotedString];
		}

		// For each column add it to the temp array and check if size is required
		for (NSDictionary *column in indexedColumns)
		{
			NSString *columnName = [column objectForKey:@"name"];
			NSString *columnType = [column objectForKey:@"type"];

			if ((![columnName length]) || (![columnType length])) continue;

			BOOL isFullTextType = [indexType isEqualToString:@"FULLTEXT"];
			
			// If this field type requires a length and one hasn't been specified (interface validation
			// should ensure this doesn't happen), then skip it.
			if ([requiresLength containsObject:[columnType uppercaseString]] && (![(NSString *)[column objectForKey:@"Size"] length]) && !isFullTextType) continue;

			if ([column objectForKey:@"Size"] && [supportsLength containsObject:columnType] && !isFullTextType) {

				[tempIndexedColumns addObject:[NSString stringWithFormat:@"%@ (%@)", [columnName backtickQuotedString], [column objectForKey:@"Size"]]];
			}
			else {
				[tempIndexedColumns addObject:[columnName backtickQuotedString]];
			}
		}

		if ([tempIndexedColumns count]) {

			if ((![indexType isEqualToString:@"INDEX"]) && (![indexType isEqualToString:@"PRIMARY KEY"])) indexType = [indexType stringByAppendingFormat:@" INDEX"];

			// Build the query
			NSMutableString *query = [NSMutableString stringWithFormat:@"ALTER TABLE %@ ADD %@", [table backtickQuotedString], indexType];

			// If supplied specify the index's name
			if ([indexName length]) {
				[query appendString:@" "];
				[query appendString:indexName];
			}

			// If supplied specify the index's storage type
			if (indexStorageType) {
				[query appendString:@" USING "];
				[query appendString:indexStorageType];
			}

			// Add the columns
			[query appendFormat:@" (%@)", [tempIndexedColumns componentsJoinedByCommas]];

			// If supplied specify the index's key block size
			if (indexKeyBlockSize) {
				[query appendFormat:@" KEY_BLOCK_SIZE = %ld", (long)[indexKeyBlockSize integerValue]];
			}

			// Execute the query
			[connection queryString:query];

			// Check for errors, but only if the query wasn't cancelled
			if ([connection queryErrored] && ![connection lastQueryWasCancelled]) {
				SPOnewayAlertSheet(
								   NSLocalizedString(@"Unable to add index", @"add index error message"),
								   [dbDocument parentWindow],
								   [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to add the index.\n\nMySQL said: %@", @"add index error informative message"), [connection lastErrorMessage]]
								   );
			}
			else {
				[tableData resetAllData];
				[dbDocument setStatusRequiresReload:YES];
				
				[tableStructure loadTable:table];
			}
		}

		SPClear(tempIndexedColumns);
	}

	// Reset indexed fields to default
	[indexedFields removeAllObjects];
	[indexedFields addObject:[[[fields objectAtIndex:0] mutableCopy] autorelease]];

	[dbDocument endTask];

	[pool drain];
}

/**
 * Removes an index from the current table using the supplied details.
 *
 * @param indexDetails A dictionary containing the details of the index to be removed
 */
- (void)_removeIndexUsingDetails:(NSDictionary *)indexDetails
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSDictionary *index   = [indexDetails objectForKey:@"Index"];
	BOOL removeForeignKey = [[indexDetails objectForKey:@"RemoveForeignKey"] boolValue];

	// Remove the foreign key dependency before the index if required
	if (removeForeignKey) {

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
		if ([connection queryErrored] && ![connection lastQueryWasCancelled]) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];

			[errorDictionary setObject:NSLocalizedString(@"Unable to delete relation", @"error deleting relation message") forKey:@"title"];
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to delete the relation '%@'.\n\nMySQL said: %@", @"error deleting relation informative message"), constraintName, [connection lastErrorMessage]] forKey:@"message"];

			[(SPTableStructure*)[tableStructure onMainThread] showErrorSheetWith:errorDictionary];
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
	if ([connection queryErrored] && ![connection lastQueryWasCancelled]) {
		NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];

		[errorDictionary setObject:NSLocalizedString(@"Unable to delete index", @"error deleting index message") forKey:@"title"];
		[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to delete the index.\n\nMySQL said: %@", @"error deleting index informative message"), [connection lastErrorMessage]] forKey:@"message"];

		[(SPTableStructure*)[tableStructure onMainThread] showErrorSheetWith:errorDictionary];
	}
	else {
		[tableData resetAllData];
		[dbDocument setStatusRequiresReload:YES];

		[tableStructure loadTable:table];
	}

	[dbDocument endTask];

	[pool drain];
}

/**
 * Resizes the new index sheet's height by the supplied delta, while retaining the position of
 * all interface controls to accommodate the advanced options view.
 *
 * @param delta The height delta for which the height should be adjusted for.
 */
- (void)_resizeWindowForAdvancedOptionsViewByHeightDelta:(NSInteger)delta
{
	NSUInteger popUpMask        = [indexTypePopUpButton autoresizingMask];
	NSUInteger nameFieldMask    = [indexNameTextField autoresizingMask];
	NSUInteger scrollMask       = [indexedColumnsScrollView autoresizingMask];
	NSUInteger buttonMask       = [indexAdvancedOptionsViewButton autoresizingMask];
	NSUInteger textFieldMask    = [indexAdvancedOptionsViewLabelButton autoresizingMask];
	NSUInteger advancedViewMask = [indexAdvancedOptionsView autoresizingMask];
	NSUInteger typeLabelMask    = [indexTypeLabel autoresizingMask];
	NSUInteger nameLabelMask    = [indexNameLabel autoresizingMask];
	NSUInteger buttonBarMask    = [(NSView*)anchoredButtonBar autoresizingMask];

	NSRect frame = [[self window] frame];

	if (frame.size.height > 600 && delta > heightOffset) {
		frame.origin.y += [indexAdvancedOptionsView frame].size.height;
		frame.size.height -= [indexAdvancedOptionsView frame].size.height;

		[[self window] setFrame:frame display:YES animate:YES];
	}

	[indexTypePopUpButton setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[indexNameTextField setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[indexedColumnsScrollView setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[indexAdvancedOptionsViewButton setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[indexAdvancedOptionsViewLabelButton setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[indexAdvancedOptionsView setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[indexTypeLabel setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];
	[indexNameLabel setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];

	[(NSView*)anchoredButtonBar setAutoresizingMask:NSViewNotSizable | NSViewMinYMargin];

	NSInteger newMinHeight = (windowMinHeigth - heightOffset + delta < windowMinHeigth) ? windowMinHeigth : windowMinHeigth - heightOffset + delta;

	[[self window] setMinSize:NSMakeSize(windowMinWidth, newMinHeight)];

	frame.origin.y += heightOffset;
	frame.size.height -= heightOffset;

	heightOffset= delta;

	frame.origin.y -= heightOffset;
	frame.size.height += heightOffset;

	[[self window] setFrame:frame display:YES animate:YES];

	[indexTypePopUpButton setAutoresizingMask:popUpMask];
	[indexNameTextField setAutoresizingMask:nameFieldMask];
	[indexedColumnsScrollView setAutoresizingMask:scrollMask];
	[indexAdvancedOptionsViewButton setAutoresizingMask:buttonMask];
	[indexAdvancedOptionsViewLabelButton setAutoresizingMask:textFieldMask];
	[indexAdvancedOptionsView setAutoresizingMask:advancedViewMask];
	[indexTypeLabel setAutoresizingMask:typeLabelMask];
	[indexNameLabel setAutoresizingMask:nameLabelMask];

	[(NSView*)anchoredButtonBar setAutoresizingMask:buttonBarMask];
}

#pragma mark -

- (void)dealloc
{
	SPClear(table);
	SPClear(indexes);
	SPClear(fields);

	SPClear(supportsLength);
	SPClear(requiresLength);

	if (indexedFields) SPClear(indexedFields);

	[prefs removeObserver:self forKeyPath:SPDisplayTableViewVerticalGridlines];

	[super dealloc];
}

@end
