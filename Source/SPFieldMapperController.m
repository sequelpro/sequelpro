//
//  SPFieldMapperController.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on February 1, 2010.
//  Copyright (c) 2010 Hans-Jörg Bibiko. All rights reserved.
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

#import "SPFieldMapperController.h"
#import "SPTableData.h"
#import "SPDataImport.h"
#import "SPTablesList.h"
#import "SPTextView.h"
#import "SPTableView.h"
#import "SPCategoryAdditions.h"
#import "RegexKitLite.h"
#import "SPDatabaseData.h"
#import "SPFunctions.h"

#import <SPMySQL/SPMySQL.h>

// Constants
static NSString *SPTableViewImportValueColumnID = @"import_value";
static NSString *SPTableViewTypeColumnID        = @"type";
static NSString *SPTableViewTargetFieldColumnID = @"target_field";
static NSString *SPTableViewOperatorColumnID    = @"operator";
static NSString *SPTableViewValueIndexColumnID  = @"value_index";
static NSString *SPTableViewGlobalValueColumnID = @"global_value";
static NSString *SPTableViewSqlColumnID         = @"sql";
static NSUInteger SPSourceColumnTypeText        = 0;
static NSUInteger SPSourceColumnTypeInteger     = 1;

@interface SPFieldMapperController ()
- (void)_setupFieldMappingPopUpMenus;
@end

@implementation SPFieldMapperController

@synthesize sourcePath;

#pragma mark -
#pragma mark Initialisation

- (id)initWithDelegate:(id)managerDelegate
{
	if ((self = [super initWithWindowNibName:@"DataMigrationDialog"])) {

		fieldMappingCurrentRow = 0;
		if(managerDelegate == nil) {
			NSBeep();
			NSLog(@"SPFieldMapperController was called without a delegate.");
			return nil;
		}
		theDelegate = managerDelegate;

		fieldMappingTableColumnNames   = [[NSMutableArray alloc] init];
		fieldMappingTableDefaultValues = [[NSMutableArray alloc] init];
		fieldMappingTableTypes         = [[NSMutableArray alloc] init];
		fieldMappingButtonOptions      = [[NSMutableArray alloc] init];
		fieldMappingOperatorOptions    = [[NSMutableArray alloc] init];
		fieldMappingOperatorArray      = [[NSMutableArray alloc] init];
		fieldMappingGlobalValues       = [[NSMutableArray alloc] init];
		defaultFieldTypesForComboBox   = [[NSMutableArray alloc] init];
		fieldMappingGlobalValuesSQLMarked = [[NSMutableArray alloc] init];
		fieldMappingArray = nil;

		lastDisabledCSVFieldcolumn = @0;

		doImportKey       = @0;
		doNotImportKey    = @1;
		isEqualKey        = @2;
		doImportString    = @"―";
		doNotImportString = @" ";
		isEqualString     = @"=";
		newTableMode      = NO;
		addGlobalSheetIsOpen = NO;
		toBeEditedRowIndexes = [[NSMutableIndexSet alloc] init];

		prefs = [NSUserDefaults standardUserDefaults];

		tablesListInstance = [theDelegate valueForKeyPath:@"tablesListInstance"];
		databaseDataInstance = [tablesListInstance valueForKeyPath:@"databaseDataInstance"];

#ifndef SP_CODA /* init ivars */
		if(![prefs objectForKey:SPLastImportIntoNewTableType])
			[prefs setObject:@"Default" forKey:SPLastImportIntoNewTableType];
		if(![prefs objectForKey:SPLastImportIntoNewTableEncoding])
			[prefs setObject:@"Default" forKey:SPLastImportIntoNewTableEncoding];
#endif
	}

	return self;
}

- (void)awakeFromNib
{
	// Set Context Menu
	[[[fieldMapperTableView menu] itemAtIndex:0] setHidden:YES];
	[[[fieldMapperTableView menu] itemAtIndex:1] setHidden:YES];
	[[[fieldMapperTableView menu] itemAtIndex:2] setHidden:NO];
	[[[fieldMapperTableView menu] itemAtIndex:3] setHidden:NO];
	// [[[fieldMapperTableView menu] itemAtIndex:4] setHidden:NO];

	// Set source path
	// Note: [fileSourcePath setURL:[NSURL fileWithPath:sourcePath]] does NOT work
	// if Sequel Pro runs localized. Reason unknown, it seems to be a NSPathControl bug.
	// Ask HansJB for more info.
	NSPathControl *pc = [[[NSPathControl alloc] initWithFrame:NSZeroRect] autorelease];
	[pc setURL:[NSURL fileURLWithPath:sourcePath]];
	if([pc pathComponentCells])
		[fileSourcePath setPathComponentCells:[pc pathComponentCells]];
	[fileSourcePath setDoubleAction:@selector(goBackToFileChooserFromPathControl:)];

	[onupdateTextView setDelegate:theDelegate];
	windowMinWidth = [[self window] minSize].width;
	windowMinHeigth = [[self window] minSize].height;

	[newTableNameTextField setHidden:YES];
	[newTableNameLabel setHidden:YES];
	[newTableNameInfoButton setHidden:YES];
	[newTableButton setHidden:NO];

	// Init table target popup menu
	[tableTargetPopup removeAllItems];
	[tableTargetPopup addItemWithTitle:NSLocalizedString(@"New Table", @"new table menu item")];
	[tableTargetPopup addItemWithTitle:NSLocalizedString(@"Refresh List", @"refresh list menu item")];
	[[tableTargetPopup menu] addItem:[NSMenuItem separatorItem]];
	NSArray *allTableNames = [tablesListInstance allTableNames];
	if(allTableNames) {
		[tableTargetPopup addItemsWithTitles:allTableNames];

		// Select either the currently selected table, or the first item in the list, or if no table in db switch to "New Table" mode
		if ([[tablesListInstance selectedTableNames] count]
				&& [allTableNames containsObject:[[tablesListInstance selectedTableNames] objectAtIndex:0]]) {
			[tableTargetPopup selectItemWithTitle:[[tablesListInstance selectedTableNames] objectAtIndex:0]];
		} else {
			if([allTableNames count])
				[tableTargetPopup selectItemAtIndex:3];
			else
				[tableTargetPopup selectItemAtIndex:0];
				[newTableNameTextField selectText:nil];
		}

	}

	[defaultFieldTypesForComboBox setArray:@[
			@"VARCHAR(255)",
			@"CHAR(63)",
			@"TEXT",
			@"LONGTEXT",
			@"INT(11)",
			@"BIGINT",
			@"DATE",
			@"DATETIME",
			@"TIME",
			@"TIMESTAMP"
	]];

	[importFieldNamesHeaderSwitch setState:importFieldNamesHeader];

	[addRemainingDataSwitch setState:NO];
	[ignoreCheckBox setState:NO];
	[ignoreUpdateCheckBox setState:NO];
	[delayedCheckBox setState:NO];
	[delayedReplaceCheckBox setState:NO];
	[onupdateCheckBox setState:NO];
	[lowPriorityCheckBox setState:NO];
	[lowPriorityReplaceCheckBox setState:NO];
	[lowPriorityUpdateCheckBox setState:NO];
	[highPriorityCheckBox setState:NO];
	[skipexistingRowsCheckBox setState:NO];
	[skipexistingRowsCheckBox setEnabled:NO];
	[advancedButton setState:NO];
	[advancedBox setHidden:YES];

	showAdvancedView = NO;
	targetTableHasPrimaryKey = NO;
	primaryKeyFields = nil;
	heightOffset = 0;
	[advancedReplaceView setHidden:YES];
	[advancedUpdateView setHidden:YES];
	[advancedInsertView setHidden:YES];

	[self changeTableTarget:self];
	[self changeHasHeaderCheckbox:self];
	[[self window] makeFirstResponder:fieldMapperTableView];
	if([fieldMappingTableColumnNames count])
		[fieldMapperTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];

	[removeGlobalValueButton setEnabled:([globalValuesTableView numberOfSelectedRows] > 0)];
	[insertNULLValueButton setEnabled:([globalValuesTableView numberOfSelectedRows] == 1)];

	[self updateFieldNameAlignment];
	
	[self validateImportButton];
}

- (void)dealloc
{
	if (mySQLConnection) SPClear(mySQLConnection);
	if (sourcePath) SPClear(sourcePath);
	if (fieldMappingTableColumnNames) SPClear(fieldMappingTableColumnNames);
	if (defaultFieldTypesForComboBox) SPClear(defaultFieldTypesForComboBox);
	if (fieldMappingTableTypes) SPClear(fieldMappingTableTypes);
	if (fieldMappingArray) SPClear(fieldMappingArray);
	if (fieldMappingButtonOptions) SPClear(fieldMappingButtonOptions);
	if (fieldMappingOperatorOptions) SPClear(fieldMappingOperatorOptions);
	if (fieldMappingOperatorArray) SPClear(fieldMappingOperatorArray);
	if (fieldMappingGlobalValues) SPClear(fieldMappingGlobalValues);
	if (fieldMappingGlobalValuesSQLMarked) SPClear(fieldMappingGlobalValuesSQLMarked);
	if (fieldMappingTableDefaultValues) SPClear(fieldMappingTableDefaultValues);
	if (primaryKeyFields) SPClear(primaryKeyFields);
	if (toBeEditedRowIndexes) SPClear(toBeEditedRowIndexes);
	
	[super dealloc];
}

#pragma mark -
#pragma mark Setter methods

- (void)setConnection:(SPMySQLConnection *)theConnection
{
	mySQLConnection = theConnection;
	[mySQLConnection retain];
}

- (void)setImportDataArray:(id)theFieldMappingImportArray hasHeader:(BOOL)hasHeader isPreview:(BOOL)isPreview
{

	numberOfImportColumns = 0;

	[fieldMappingGlobalValues removeAllObjects];

	fieldMappingImportArray = theFieldMappingImportArray;
	importFieldNamesHeader  = hasHeader;
	fieldMappingImportArrayIsPreview = isPreview;

	if([fieldMappingImportArray count])
		numberOfImportColumns = [NSArrayObjectAtIndex(fieldMappingImportArray, 0) count];

	NSInteger i;
	for(i=0; i<numberOfImportColumns; i++) {
		[fieldMappingGlobalValues addObject:@"…"];
		[fieldMappingGlobalValuesSQLMarked addObject:@"…"];
	}

}

#pragma mark -
#pragma mark Getter methods

- (NSString*)selectedTableTarget
{

	if(newTableMode) return [newTableNameTextField stringValue];

	return ([tableTargetPopup titleOfSelectedItem] == nil) ? @"" : [tableTargetPopup titleOfSelectedItem];

}

- (NSArray*)fieldMapperOperator
{
	return [NSArray arrayWithArray:fieldMappingOperatorArray];
}

- (NSString*)selectedImportMethod
{
	return ([importMethodPopup titleOfSelectedItem] == nil) ? @"" : [importMethodPopup titleOfSelectedItem];
}

- (NSArray*)fieldMappingArray
{
	return fieldMappingArray;
}

- (NSArray*)fieldMappingGlobalValueArray
{
	NSMutableArray *globals = [NSMutableArray array];
	for(NSUInteger i=0; i < [fieldMappingGlobalValues count]; i++) {
		id glob = NSArrayObjectAtIndex(fieldMappingGlobalValues, i);
		if([NSArrayObjectAtIndex(fieldMappingGlobalValuesSQLMarked, i) boolValue] || [glob isNSNull])
			[globals addObject:glob];
		else
			[globals addObject:[NSString stringWithFormat:@"'%@'", [(NSString*)glob stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"]]];
	}

	return globals;
}

- (BOOL)globalValuesInUsage
{
	NSInteger i = 0;
	for(id item in fieldMappingArray) {
		if([item intValue] >= numberOfImportColumns && ![doNotImportKey isEqualToNumber:NSArrayObjectAtIndex(fieldMappingOperatorArray, i)])
			return YES;
		i++;
	}
	return NO;
}

- (BOOL)importIntoNewTable
{
	return newTableMode;
}

- (NSArray*)fieldMappingTableColumnNames
{
	return fieldMappingTableColumnNames;
}

- (NSArray*)fieldMappingTableDefaultValues
{
	return fieldMappingTableDefaultValues;
}

- (BOOL)importFieldNamesHeader
{
	if(importFieldNamesHeaderSwitch) {
		return ([importFieldNamesHeaderSwitch state] == NSOnState);
	}
	else {
		//this is a provisional field for the initial value of the checkbox until the window is actually loaded
		return importFieldNamesHeader;
	}
}

- (BOOL)hasContentRows
{
	return (([fieldMappingImportArray count] - ([self importFieldNamesHeader]? 1 : 0)) > 0);
}

- (BOOL)insertRemainingRowsAfterUpdate
{
	return ([addRemainingDataSwitch state] == NSOnState)?YES:NO;
}

- (NSString*)importHeaderString
{
	if([[importMethodPopup titleOfSelectedItem] isEqualToString:@"INSERT"]) {
		return [NSString stringWithFormat:@"INSERT %@%@%@%@INTO ",
			([lowPriorityCheckBox state] == NSOnState) ? @"LOW_PRIORITY " : @"",
			([delayedCheckBox state] == NSOnState) ? @"DELAYED " : @"",
			([highPriorityCheckBox state] == NSOnState) ? @"HIGH_PRIORITY " : @"",
			([ignoreCheckBox state] == NSOnState) ? @"IGNORE " : @""
			];
	}
	else if([[importMethodPopup titleOfSelectedItem] isEqualToString:@"REPLACE"]) {
		return [NSString stringWithFormat:@"REPLACE %@%@INTO ",
			([lowPriorityReplaceCheckBox state] == NSOnState) ? @"LOW_PRIORITY " : @"",
			([delayedReplaceCheckBox state] == NSOnState) ? @"DELAYED " : @""
			];
	}
	else if([[importMethodPopup titleOfSelectedItem] isEqualToString:@"UPDATE"]) {
		return [NSString stringWithFormat:@"UPDATE %@%@%@ SET ",
			([lowPriorityUpdateCheckBox state] == NSOnState) ? @"LOW_PRIORITY " : @"",
			([ignoreUpdateCheckBox state] == NSOnState) ? @"IGNORE " : @"",
			[[self selectedTableTarget] backtickQuotedString]
			];
	}
	return @"";
}

- (NSString*)onupdateString
{
	if([onupdateCheckBox state] == NSOnState && [[onupdateTextView string] length])
		return [NSString stringWithFormat:@"ON DUPLICATE KEY UPDATE %@", [onupdateTextView string]];
	else
		return @"";
}

- (BOOL)canBeClosed
{
	return [importButton isEnabled];
}

- (BOOL)isGlobalValueSheetOpen
{
	return addGlobalSheetIsOpen;
}

#pragma mark -
#pragma mark IBAction methods

- (IBAction)closeInfoSheet:(id)sender
{
	// Only save selection if the user selected 'OK'
	if ([sender tag]) {
#ifndef SP_CODA
		[prefs setObject:[newTableInfoEnginePopup titleOfSelectedItem] forKey:SPLastImportIntoNewTableType];
		[prefs setObject:[newTableInfoEncodingPopup titleOfSelectedItem] forKey:SPLastImportIntoNewTableEncoding];
#endif
	}

	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

- (IBAction)closeSheet:(id)sender
{

	// Try to add new columns first
	if(!newTableMode && [toBeEditedRowIndexes count] && [sender tag] == 1) {
		[[self window] endEditingFor:nil];

		NSUInteger currentIndex = [toBeEditedRowIndexes firstIndex];

		while (currentIndex != NSNotFound) {

			NSMutableString *createString = [NSMutableString string];

			[createString appendFormat:@"ALTER TABLE %@ ADD %@ %@",
				[[tableTargetPopup titleOfSelectedItem] backtickQuotedString],
				[[fieldMappingTableColumnNames objectAtIndex:currentIndex] backtickQuotedString],
				[fieldMappingTableTypes objectAtIndex:currentIndex]];

			[mySQLConnection queryString:createString];

			if ([mySQLConnection queryErrored]) {
				NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error adding new column", @"error adding new column message")
												 defaultButton:NSLocalizedString(@"OK", @"OK button")
											   alternateButton:nil
												   otherButton:nil
									 informativeTextWithFormat:NSLocalizedString(@"An error occurred while trying to add the new column '%@' by\n\n%@.\n\nMySQL said: %@", @"error adding new column informative message"), [fieldMappingTableColumnNames objectAtIndex:currentIndex], createString, [mySQLConnection lastErrorMessage]];

				[alert setAlertStyle:NSCriticalAlertStyle];
				[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
				return;
			} else {
				[toBeEditedRowIndexes removeIndex:currentIndex];
			}

			currentIndex = [toBeEditedRowIndexes indexGreaterThanIndex:currentIndex];
		}


	}

	// Try to create the new TABLE
	else if(newTableMode && [sender tag] == 1) {

		[[self window] endEditingFor:nil];

		NSMutableString *createString = [NSMutableString string];
		[createString appendFormat:@"CREATE TABLE %@ (\n", [[newTableNameTextField stringValue] backtickQuotedString]];
		NSInteger columnIndex = 0;
		NSInteger numberOfColumns = [fieldMappingTableColumnNames count];
		NSMutableArray *columnDetails = [NSMutableArray array];
		for(columnIndex = 0; columnIndex < numberOfColumns; columnIndex++) {

			// Skip fields which aren't marked as imported
			if (![doImportKey isEqualToNumber:[fieldMappingOperatorArray objectAtIndex:columnIndex]]) {
				continue;
			}

			[columnDetails addObject:[NSString stringWithFormat:@"\t%@ %@", [[fieldMappingTableColumnNames objectAtIndex:columnIndex] backtickQuotedString], [fieldMappingTableTypes objectAtIndex:columnIndex]]];
		}
		[createString appendString:[columnDetails componentsJoinedByString:@", \n"]];
		[createString appendString:@")"];

#ifndef SP_CODA
		if(![[prefs objectForKey:SPLastImportIntoNewTableType] isEqualToString:@"Default"])
			[createString appendFormat:@" ENGINE=%@", [prefs objectForKey:SPLastImportIntoNewTableType]];
		if(![[prefs objectForKey:SPLastImportIntoNewTableEncoding] isEqualToString:@"Default"]) {
			NSString *encodingName = [[prefs objectForKey:SPLastImportIntoNewTableEncoding] stringByMatching:@"\\((.*)\\)" capture:1L];
			if (!encodingName) encodingName = @"utf8";
			[createString appendString:[NSString stringWithFormat:@" DEFAULT CHARACTER SET %@", [encodingName backtickQuotedString]]];
		}
#endif

		[mySQLConnection queryString:createString];

		if ([mySQLConnection queryErrored]) {
			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error adding new table", @"error adding new table message")
											 defaultButton:NSLocalizedString(@"OK", @"OK button")
										   alternateButton:nil
											   otherButton:nil
								 informativeTextWithFormat:NSLocalizedString(@"An error occurred while trying to add the new table '%@' by\n\n%@.\n\nMySQL said: %@", @"error adding new table informative message"), [newTableNameTextField stringValue], createString, [mySQLConnection lastErrorMessage]];

			[alert setAlertStyle:NSCriticalAlertStyle];
			[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
			return;
		}

	}


	[advancedReplaceView setHidden:YES];
	[advancedUpdateView setHidden:YES];
	[advancedInsertView setHidden:YES];
	[advancedBox setHidden:YES];
	[self resizeWindowByHeightDelta:0];
	[NSApp endSheet:[self window] returnCode:[sender tag]];
}

- (IBAction)changeTableTarget:(id)sender
{

	NSArray *allTableNames = [tablesListInstance allTableNames];
	NSUInteger i;

	// Remove all indexes for new columns
	[toBeEditedRowIndexes removeAllIndexes];

	// Is Refresh List chosen?
	if([tableTargetPopup selectedItem] == [tableTargetPopup itemAtIndex:1]) {
		[tableTargetPopup removeAllItems];
		[tableTargetPopup addItemWithTitle:NSLocalizedString(@"New Table", @"new table menu item")];
		[tableTargetPopup addItemWithTitle:NSLocalizedString(@"Refresh List", @"refresh list menu item")];
		[[tableTargetPopup menu] addItem:[NSMenuItem separatorItem]];

		// Update tables list
		[tablesListInstance updateTables:nil];
		if(allTableNames) {
			[tableTargetPopup addItemsWithTitles:allTableNames];
		}

		// Select either the currently selected table, or the first item in the list, or if no table in db switch to "New Table" mode
		if ([[tablesListInstance selectedTableNames] count]
				&& [allTableNames containsObject:[[tablesListInstance selectedTableNames] objectAtIndex:0]]) {
			[tableTargetPopup selectItemWithTitle:[[tablesListInstance selectedTableNames] objectAtIndex:0]];
		} else {
			if([allTableNames count])
				[tableTargetPopup selectItemAtIndex:3];
			else
				[tableTargetPopup selectItemAtIndex:0];
		}

		return;

	}

	// New Table was chosen
	else if([tableTargetPopup selectedItem] == [tableTargetPopup itemAtIndex:0]) {
		[self newTable:nil];
		return;
	}

	// Remove all the current columns
	[fieldMappingTableColumnNames removeAllObjects];
	[fieldMappingTableDefaultValues removeAllObjects];
	[fieldMappingTableTypes removeAllObjects];

	// Retrieve the information for the newly selected table using a SPTableData instance
	SPTableData *selectedTableData = [[SPTableData alloc] init];
	[selectedTableData setConnection:mySQLConnection];
	NSDictionary *tableDetails = [selectedTableData informationForTable:[tableTargetPopup titleOfSelectedItem]];
	targetTableHasPrimaryKey = NO;
	BOOL isReplacePossible = NO;

	if (tableDetails) {
		for (NSDictionary *column in [tableDetails objectForKey:@"columns"]) {
			[fieldMappingTableColumnNames addObject:[NSString stringWithString:[column objectForKey:@"name"]]];
			NSMutableString *type = [NSMutableString string];
			if([column objectForKey:@"type"])
				[type appendString:[column objectForKey:@"type"]];
			if([column objectForKey:@"length"])
				[type appendFormat:@"(%@)", [column objectForKey:@"length"]];
			if([column objectForKey:@"values"])
				[type appendFormat:@"(%@)", [[column objectForKey:@"values"] componentsJoinedByString:@"¦"]];

			if([column objectForKey:@"isprimarykey"]) {
				[type appendFormat:@",%@",@"PRIMARY"];
				if([[[column objectForKey:@"autoincrement"] description] isEqualToString:@"1"]) {
					[fieldMappingTableDefaultValues addObject:@"auto_increment"];
				} else {
					[fieldMappingTableDefaultValues addObject:@"0"];
				}
				targetTableHasPrimaryKey = YES;
				if (primaryKeyFields) [primaryKeyFields release];
				primaryKeyFields = [[tableDetails objectForKey:@"primarykeyfield"] retain];
			} else {
				if([column objectForKey:@"unique"]) {
					[type appendFormat:@",%@",@"UNIQUE"];
					isReplacePossible = YES;
				}
				// if([[[column objectForKey:@"onupdatetimestamp"] description] isEqualToString:@"1"]) {
				// 	[fieldMappingTableDefaultValues addObject:@"CURRENT_TIMESTAMP"];
				// } else {
				if ([column objectForKey:@"default"])
					[fieldMappingTableDefaultValues addObject:[column objectForKey:@"default"]];
				else
					[fieldMappingTableDefaultValues addObject:[NSNull null]];
				// }
			}

			[fieldMappingTableTypes addObject:[NSString stringWithString:type]];
		}
	}

	[selectedTableData release];
	[[importMethodPopup menu] setAutoenablesItems:NO];
	[[importMethodPopup itemWithTitle:@"REPLACE"] setEnabled:(targetTableHasPrimaryKey|isReplacePossible)];
	[skipexistingRowsCheckBox setEnabled:targetTableHasPrimaryKey];

	// Update the table view
	fieldMappingCurrentRow = 0;
	if (fieldMappingArray) SPClear(fieldMappingArray);
	[self setupFieldMappingArray];
	[self updateRowNavigation];

	[self updateFieldMappingButtonCell];
	[self updateFieldMappingOperatorOptions];

	// Set all operators to doNotImportKey
	[fieldMappingOperatorArray removeAllObjects];
	for(i=0; i < [fieldMappingTableColumnNames count]; i++)
		[fieldMappingOperatorArray addObject:doNotImportKey];

	// Set the first n operators to doImport
	if([fieldMappingImportArray count]) {
		NSUInteger possibleImports = ([NSArrayObjectAtIndex(fieldMappingImportArray, 0) count] > [fieldMappingTableColumnNames count]) ? [fieldMappingTableColumnNames count] : [NSArrayObjectAtIndex(fieldMappingImportArray, 0) count];
		for(i=0; i < possibleImports; i++)
			[fieldMappingOperatorArray replaceObjectAtIndex:i withObject:doImportKey];
	}

	// Disable Import button if no fields are available
	[importButton setEnabled:([fieldMappingTableColumnNames count] > 0)];
	// Disable UPDATE import method if target table has less than 2 fields
	// and fall back to INSERT if UPDATE was selected
	if([fieldMappingTableColumnNames count] > 1) {
		[[importMethodPopup itemWithTitle:@"UPDATE"] setEnabled:YES];
	} else {
		[[importMethodPopup itemWithTitle:@"UPDATE"] setEnabled:NO];
		if([[importMethodPopup titleOfSelectedItem] isEqualToString:@"UPDATE"]) {
			[importMethodPopup selectItemWithTitle:@"INSERT"];
			[self changeImportMethod:nil];
		}
	}

	[self updateFieldNameAlignment];

	[self _setupFieldMappingPopUpMenus];
	[fieldMapperTableView reloadData];

}

- (IBAction)changeImportMethod:(id)sender
{
	NSUInteger i;

	[onupdateTextView setBackgroundColor:[NSColor lightGrayColor]];
	[onupdateTextView setEditable:NO];
	[ignoreCheckBox setState:NO];
	[ignoreUpdateCheckBox setState:NO];
	[delayedCheckBox setState:NO];
	[delayedReplaceCheckBox setState:NO];
	[onupdateCheckBox setState:NO];
	[lowPriorityCheckBox setState:NO];
	[lowPriorityReplaceCheckBox setState:NO];
	[lowPriorityUpdateCheckBox setState:NO];
	[highPriorityCheckBox setState:NO];

	[advancedReplaceView setHidden:YES];
	[advancedUpdateView setHidden:YES];
	[advancedInsertView setHidden:YES];

	if(showAdvancedView) {
		[advancedBox setHidden:NO];
		if([[importMethodPopup titleOfSelectedItem] isEqualToString:@"UPDATE"]) {
			[self resizeWindowByHeightDelta:[advancedUpdateView frame].size.height-10];
			[advancedUpdateView setHidden:NO];
			[advancedInsertView setHidden:YES];
			[advancedReplaceView setHidden:YES];
		}
		else if([[importMethodPopup titleOfSelectedItem] isEqualToString:@"INSERT"]) {
			[self resizeWindowByHeightDelta:[advancedInsertView frame].size.height-20];
			[advancedInsertView setHidden:NO];
			[advancedUpdateView setHidden:YES];
			[advancedReplaceView setHidden:YES];
		}
		else if([[importMethodPopup titleOfSelectedItem] isEqualToString:@"REPLACE"]) {
			[self resizeWindowByHeightDelta:[advancedReplaceView frame].size.height-10];
			[advancedReplaceView setHidden:NO];
			[advancedUpdateView setHidden:YES];
			[advancedInsertView setHidden:YES];
		}
	} else {
		[advancedBox setHidden:YES];
	}

	// If operator is set to = for UPDATE method replace it by doNotImportKey
	if(![[importMethodPopup titleOfSelectedItem] isEqualToString:@"UPDATE"]) {
		[advancedButton setEnabled:YES];
		for(i=0; i<[fieldMappingTableColumnNames count]; i++) {
			if([isEqualKey isEqualToNumber:[fieldMappingOperatorArray objectAtIndex:i]]) {
				[fieldMappingOperatorArray replaceObjectAtIndex:i withObject:doNotImportKey];
			}
		}
	} else {
		[advancedButton setEnabled:YES];
	}

	[self validateImportButton];

	[self updateFieldMappingOperatorOptions];
	
	[self _setupFieldMappingPopUpMenus];
	[fieldMapperTableView reloadData];
}

- (IBAction)changeFieldAlignment:(id)sender
{

	if(![self hasContentRows]) return;

	NSUInteger i;
	NSInteger j;
	NSInteger possibleImports = ([NSArrayObjectAtIndex(fieldMappingImportArray, 0) count] > [fieldMappingTableColumnNames count]) ? [fieldMappingTableColumnNames count] : [NSArrayObjectAtIndex(fieldMappingImportArray, 0) count];

	if(possibleImports < 1) return;

	// Set all operators to doNotImportKey
	[fieldMappingOperatorArray removeAllObjects];
	for(i=0; i < [fieldMappingTableColumnNames count]; i++)
		[fieldMappingOperatorArray addObject:doNotImportKey];

	switch([[alignByPopup selectedItem] tag]) {
		case 0: // file order
		for(j=0; j<possibleImports; j++) {
			[fieldMappingArray replaceObjectAtIndex:j withObject:[NSNumber numberWithInteger:j]];
			[fieldMappingOperatorArray replaceObjectAtIndex:j withObject:doImportKey];
		}
		break;
		case 1: // reversed file order
		possibleImports--;
		for(j=possibleImports; j>=0; j--) {
			[fieldMappingArray replaceObjectAtIndex:possibleImports-j withObject:[NSNumber numberWithInteger:j]];
			[fieldMappingOperatorArray replaceObjectAtIndex:possibleImports - j withObject:doImportKey];
		}
		break;
		case 2: // try to align header and table target field names via Levenshtein distance
		[self matchHeaderNames];
		break;
	}
	[fieldMapperTableView reloadData];

#ifndef SP_CODA
	// Remember last field alignment if not "custom order"
	if([[alignByPopup selectedItem] tag] != 3)
		[prefs setInteger:[[alignByPopup selectedItem] tag] forKey:SPCSVFieldImportMappingAlignment];
#endif

}
/*
 * Displays next/previous row in fieldMapping tableView
 */
- (IBAction)stepRow:(id)sender
{
	if ( [sender tag] == 0 ) {
		fieldMappingCurrentRow--;
	} else {
		fieldMappingCurrentRow++;
	}
	[self updateFieldMappingButtonCell];

	[fieldMapperTableView reloadData];
	
	[self updateRowNavigation];
}

- (IBAction)changeHasHeaderCheckbox:(id)sender
{
	NSInteger i;
	NSArray *headerRow;

	[matchingNameMenuItem setEnabled:[self importFieldNamesHeader]];

	// In New Table mode reset new field name according to importFieldNamesHeaderSwitch's state
	if (newTableMode) {
		[fieldMappingTableColumnNames removeAllObjects];
		if([self importFieldNamesHeader]) {
			headerRow = NSArrayObjectAtIndex(fieldMappingImportArray, 0);
			for (i = 0; i < numberOfImportColumns; i++) {
				id headerCol = NSArrayObjectAtIndex(headerRow, i);
				// we don't want a NSNull in the column headers to mess stuff up (issue #2375)
				if([headerCol isNSNull]) headerCol = [prefs stringForKey:SPNullValue];
				[fieldMappingTableColumnNames addObject:headerCol];
			}
		} else {
			for (i = 1; i <= numberOfImportColumns; i++) {
				[fieldMappingTableColumnNames addObject:[NSString stringWithFormat:@"col_%ld", (long)i]];
			}
		}
		[fieldMapperTableView reloadData];
	}

	[self updateFieldMappingButtonCell];
	[fieldMapperTableView reloadData];
	
	[self updateRowNavigation];
	
	[self validateImportButton];
}

- (IBAction)goBackToFileChooserFromPathControl:(id)sender
{
	[gobackButton performSelector:@selector(performClick:) withObject:nil afterDelay:0.0f];
}

- (IBAction)goBackToFileChooser:(id)sender
{

	[NSApp endSheet:[self window] returnCode:[sender tag]];

	if([sourcePath hasPrefix:SPImportClipboardTempFileNamePrefix])
		[theDelegate importFromClipboard];
	else
		[theDelegate importFile];

}

- (IBAction)newTable:(id)sender
{
	newTableMode = YES;

	// Set Context Menu
	[[[fieldMapperTableView menu] itemAtIndex:0] setHidden:NO];
	[[[fieldMapperTableView menu] itemAtIndex:1] setHidden:YES];
	[[[fieldMapperTableView menu] itemAtIndex:2] setHidden:YES];
	[[[fieldMapperTableView menu] itemAtIndex:3] setHidden:YES];
	// [[[fieldMapperTableView menu] itemAtIndex:4] setHidden:YES];

	[importMethodPopup selectItemWithTitle:@"INSERT"];
	[[importMethodPopup itemWithTitle:@"UPDATE"] setEnabled:NO];
	[[importMethodPopup itemWithTitle:@"REPLACE"] setEnabled:NO];

	[tableTargetPopup setHidden:YES];
	[newTableNameTextField setHidden:NO];
	[newTableNameLabel setHidden:NO];
	[newTableNameInfoButton setHidden:NO];
	[newTableButton setHidden:YES];
	[newTableNameTextField selectText:nil];

	// Check length and type of fieldMappingImportArray values
	NSInteger maxLengthOfSourceColumns [numberOfImportColumns];
	NSUInteger typeOfSourceColumns [numberOfImportColumns];
	NSInteger columnCounter;

	// Set up initial defaults for the column states
	for (columnCounter = 0; columnCounter < numberOfImportColumns; columnCounter++) {
		maxLengthOfSourceColumns[columnCounter] = 0;
		typeOfSourceColumns[columnCounter] = SPSourceColumnTypeInteger;
	}

	// Step through the currently known data and get the types and values
	NSUInteger i = ([self importFieldNamesHeader] ? 1 : 0);
	NSArray *row;
	id col;
	for ( ; i < [fieldMappingImportArray count]; i++) {
		row = NSArrayObjectAtIndex(fieldMappingImportArray, i);
		for (columnCounter = 0; columnCounter < numberOfImportColumns; columnCounter++) {
			col = NSArrayObjectAtIndex(row, columnCounter);
			if(col && ![col isNSNull] && ![col isSPNotLoaded]) {
				if([col isKindOfClass:[NSString class]] && maxLengthOfSourceColumns[columnCounter] < (NSInteger)[(NSString*)col length]) {
					maxLengthOfSourceColumns[columnCounter] = [(NSString*)col length];
				}
				if(typeOfSourceColumns[columnCounter] == SPSourceColumnTypeInteger) {
					if(![[[NSNumber numberWithLongLong:[col longLongValue]] stringValue] isEqualToString:col])
					typeOfSourceColumns[columnCounter] = SPSourceColumnTypeText;
				}
			}
		}
	}


	[fieldMappingTableColumnNames removeAllObjects];
	[fieldMappingTableDefaultValues removeAllObjects];
	[fieldMappingTableTypes removeAllObjects];
	
	BOOL serverGreaterThanVersion4 = ([mySQLConnection serverMajorVersion] >= 5) ? YES : NO;
	BOOL importFirstRowAsFieldNames = [self importFieldNamesHeader];

	NSArray *headerRow = NSArrayObjectAtIndex(fieldMappingImportArray, 0);
	for (columnCounter = 0; columnCounter < numberOfImportColumns; columnCounter++) {
		if (importFirstRowAsFieldNames) {
			id headerName = NSArrayObjectAtIndex(headerRow, columnCounter);
			// we don't want a NSNull in the column headers to mess stuff up (issue #2375)
			if([headerName isNSNull]) headerName = [prefs stringForKey:SPNullValue];
			[fieldMappingTableColumnNames addObject:headerName];
		} else {
			[fieldMappingTableColumnNames addObject:[NSString stringWithFormat:@"col_%ld", (long)(columnCounter + 1)]];
		}

		[fieldMappingTableDefaultValues addObject:@""];

		if (typeOfSourceColumns[columnCounter] == SPSourceColumnTypeInteger) {
			if (maxLengthOfSourceColumns[columnCounter] < 9)
				[fieldMappingTableTypes addObject:@"INT(11)"];
			else
				[fieldMappingTableTypes addObject:@"BIGINT(11)"];
		} else {
			if (serverGreaterThanVersion4) {
				if (maxLengthOfSourceColumns[columnCounter] < 256)
					[fieldMappingTableTypes addObject:@"VARCHAR(255)"];
				else if (maxLengthOfSourceColumns[columnCounter] < 32768)
					[fieldMappingTableTypes addObject:@"VARCHAR(32767)"];
				else
					[fieldMappingTableTypes addObject:@"TEXT"];
			} else {
				if (maxLengthOfSourceColumns[columnCounter] < 256)
					[fieldMappingTableTypes addObject:@"VARCHAR(255)"];
				else
					[fieldMappingTableTypes addObject:@"TEXT"];
			}
		}
	}

	// Update the table view
	fieldMappingCurrentRow = 0;
	if (fieldMappingArray) SPClear(fieldMappingArray);
	[self setupFieldMappingArray];
	[self updateRowNavigation];
	
	[self updateFieldMappingButtonCell];
	[self updateFieldMappingOperatorOptions];

	// Set all operators to doNotImportKey
	[fieldMappingOperatorArray removeAllObjects];
	for (i=0; i < [fieldMappingTableColumnNames count]; i++)
		[fieldMappingOperatorArray addObject:doImportKey];

	[self _setupFieldMappingPopUpMenus];
	[fieldMapperTableView reloadData];
	[self validateImportButton];
}

/*
 * Add new column to the selected table (processed after pressing 'Import' button)
 */
- (IBAction)addNewColumn:(id)sender
{

	[fieldMappingOperatorArray addObject:doNotImportKey];
	[fieldMappingTableColumnNames addObject:NSLocalizedString(@"New Column Name", @"new column name placeholder string")];
	[fieldMappingTableTypes addObject:@"VARCHAR(255)"];
	[fieldMappingTableDefaultValues addObject:@""];

	NSInteger newIndex = [fieldMappingTableTypes count]-1;

	[fieldMappingArray addObject:[NSNumber numberWithInteger:newIndex]];
	[toBeEditedRowIndexes addIndex:newIndex];

	[self _setupFieldMappingPopUpMenus];
	[fieldMapperTableView reloadData];

	[fieldMapperTableView editColumn:2 row:newIndex withEvent:nil select:YES];

}


/*
 * Remove currently new added column
 */
- (IBAction)removeNewColumn:(id)sender
{

	NSInteger toBeRemovedIndex = [fieldMapperTableView selectedRow];

	if(![toBeEditedRowIndexes containsIndex:toBeRemovedIndex]) {
		NSBeep();
		return;
	}

	[fieldMappingOperatorArray removeObjectAtIndex:toBeRemovedIndex];
	[fieldMappingTableColumnNames removeObjectAtIndex:toBeRemovedIndex];
	[fieldMappingTableTypes removeObjectAtIndex:toBeRemovedIndex];
	[fieldMappingTableDefaultValues removeObjectAtIndex:toBeRemovedIndex];

	[fieldMappingArray removeObjectAtIndex:toBeRemovedIndex];
	[toBeEditedRowIndexes removeIndex:toBeRemovedIndex];

	// Renumber indexes greater than toBeRemovedIndex
	[toBeEditedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger currentIndex, BOOL * _Nonnull stop) {
		if(currentIndex > (NSUInteger)toBeRemovedIndex) {
			[toBeEditedRowIndexes addIndex:currentIndex-1];
			[toBeEditedRowIndexes removeIndex:currentIndex];
		}
	}];

	[self _setupFieldMappingPopUpMenus];
	[fieldMapperTableView reloadData];

}

/*
 * Set all table target field types to that one of the current selected type
 */
- (IBAction)setAllTypesTo:(id)sender
{
	NSInteger row = [fieldMapperTableView selectedRow];
	if(row<0 || row>=(NSInteger)([fieldMappingTableColumnNames count])) {
		NSBeep();
		return;
	}
	NSString *type = [[fieldMappingTableTypes objectAtIndex:row] retain];
	[fieldMappingTableTypes removeAllObjects];
	NSUInteger i;
	for(i=0; i<[fieldMappingTableColumnNames count]; i++)
		[fieldMappingTableTypes addObject:type];
	[fieldMapperTableView reloadData];
	[type release];
}

/*
 * Show sheet to set up encoding and engine for the new to be created table
 */
- (IBAction)newTableInfo:(id)sender
{
	[[self window] endEditingFor:nil];

	// Populate the table type (engine) popup button
	[newTableInfoEnginePopup removeAllItems];

	NSArray *engines = [databaseDataInstance getDatabaseStorageEngines];

	// Add default menu item
	[newTableInfoEnginePopup addItemWithTitle:@"Default"];
	[[newTableInfoEnginePopup menu] addItem:[NSMenuItem separatorItem]];

	for (NSDictionary *engine in engines)
	{
		[newTableInfoEnginePopup addItemWithTitle:[engine objectForKey:@"Engine"]];
	}

#ifndef SP_CODA
	[newTableInfoEnginePopup selectItemWithTitle:[prefs objectForKey:SPLastImportIntoNewTableType]];
#endif

	// Populate the table encoding popup button with a default menu item
	[newTableInfoEncodingPopup removeAllItems];
	[newTableInfoEncodingPopup addItemWithTitle:@"Default"];

	// Retrieve the server-supported encodings and add them to the menu
	NSArray *encodings  = [databaseDataInstance getDatabaseCharacterSetEncodings];
	NSString *utf8MenuItemTitle = nil;
	
	if ([encodings count] > 0 && ([mySQLConnection serverVersionIsGreaterThanOrEqualTo:4 minorVersion:1 releaseVersion:0]))
	{
		[[newTableInfoEncodingPopup menu] addItem:[NSMenuItem separatorItem]];
		for (NSDictionary *encoding in encodings) {
			NSString *menuItemTitle = (![encoding objectForKey:@"DESCRIPTION"]) ? [encoding objectForKey:@"CHARACTER_SET_NAME"] : [NSString stringWithFormat:@"%@ (%@)", [encoding objectForKey:@"DESCRIPTION"], [encoding objectForKey:@"CHARACTER_SET_NAME"]];
			[newTableInfoEncodingPopup addItemWithTitle:menuItemTitle];

			// If the UTF8 entry has been encountered, store the menu title
			if ([[encoding objectForKey:@"CHARACTER_SET_NAME"] isEqualToString:@"utf8"]) {
				utf8MenuItemTitle = [NSString stringWithString:menuItemTitle];
			}
		}

		// If a UTF8 entry was found, promote it to the top of the list
		if (utf8MenuItemTitle) {
			[[newTableInfoEncodingPopup menu] insertItem:[NSMenuItem separatorItem] atIndex:2];
			[newTableInfoEncodingPopup insertItemWithTitle:utf8MenuItemTitle atIndex:2];
		}

#ifndef SP_CODA
		[newTableInfoEncodingPopup selectItemWithTitle:[prefs objectForKey:SPLastImportIntoNewTableEncoding]];
#endif
	}

	[NSApp beginSheet:newTableInfoWindow
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
}

#pragma mark -
#pragma mark Global Value Sheet

- (IBAction)addGlobalSourceVariable:(id)sender
{

	// Since it can be called via keyboard short-cut as well bail the call if sheet is already open
	if(addGlobalSheetIsOpen) return;

	addGlobalSheetIsOpen = YES;

	// Init insert pulldown menu

	// Remove all dynamic menu items
	while([insertPullDownButton numberOfItems] > (([[self selectedImportMethod] isEqualToString:@"UPDATE"]) ? 6 : 5))
		[insertPullDownButton removeItemAtIndex:[insertPullDownButton numberOfItems]-1];

#ifndef SP_CODA
	// Add recent global value menu
	if([prefs objectForKey:SPGlobalValueHistory] && [[prefs objectForKey:SPGlobalValueHistory] isKindOfClass:[NSArray class]] && [[prefs objectForKey:SPGlobalValueHistory] count])
		for(id item in [prefs objectForKey:SPGlobalValueHistory])
			[recentGlobalValueMenu addItemWithTitle:item action:@selector(insertRecentGlobalValue:) keyEquivalent:@""];
#endif

	// Add column placeholder
	NSInteger i = 0;
	if([self hasContentRows]) {
		for(id item in [fieldMappingImportArray objectAtIndex:([self importFieldNamesHeader]? 1 : 0)]) {
			i++;
			if ([item isNSNull]) {
				[insertPullDownButton addItemWithTitle:[NSString stringWithFormat:@"%li. <%@>", (long)i, [prefs objectForKey:SPNullValue]]];
			} else if ([item isSPNotLoaded]) {
				[insertPullDownButton addItemWithTitle:[NSString stringWithFormat:@"%li. <%@>", (long)i, @"DEFAULT"]];
			} else {
				if([(NSString*)item length] > 20)
					[insertPullDownButton addItemWithTitle:[NSString stringWithFormat:@"%li. %@…", (long)i, [item substringToIndex:20]]];
				else
					[insertPullDownButton addItemWithTitle:[NSString stringWithFormat:@"%li. %@", (long)i, item]];
			}
		}
	}

	[NSApp beginSheet:globalValuesSheet
		modalForWindow:[self window]
		modalDelegate:self
		didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];

	[self addGlobalValue:nil];
}

- (IBAction)addGlobalValue:(id)sender
{
	[fieldMappingGlobalValues addObject:@""];
	[fieldMappingGlobalValuesSQLMarked addObject:@NO];
	[globalValuesTableView reloadData];
	[globalValuesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[fieldMappingGlobalValues count]-1-numberOfImportColumns] byExtendingSelection:NO];
	[globalValuesTableView editColumn:1 row:[fieldMappingGlobalValues count]-1-numberOfImportColumns withEvent:nil select:YES];
}

- (IBAction)removeGlobalValue:(id)sender
{

	[globalValuesTableView abortEditing];

	NSIndexSet *indexes = [globalValuesTableView selectedRowIndexes];

	[indexes enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger currentIndex, BOOL * _Nonnull stop) {
		[fieldMappingGlobalValues removeObjectAtIndex:currentIndex+numberOfImportColumns];
		[fieldMappingGlobalValuesSQLMarked removeObjectAtIndex:currentIndex+numberOfImportColumns];
	}];

	[globalValuesTableView reloadData];

	// Set focus to favorite list to avoid an unstable state
	[globalValuesSheet makeFirstResponder:globalValuesTableView];

	[removeGlobalValueButton setEnabled:([globalValuesTableView numberOfSelectedRows] > 0)];
	[insertNULLValueButton setEnabled:([globalValuesTableView numberOfSelectedRows] == 1)];
}

- (IBAction)insertNULLValue:(id)sender;
{
	if([globalValuesTableView numberOfSelectedRows] != 1) return;

	[globalValuesTableView abortEditing];
	[fieldMappingGlobalValues replaceObjectAtIndex:[globalValuesTableView selectedRow]+numberOfImportColumns withObject:[NSNull null]];

	[globalValuesTableView reloadData];

}

- (IBAction)closeGlobalValuesSheet:(id)sender
{

		// Ensure all changes are stored before ordering out
		[globalValuesTableView validateEditing];
		if ([globalValuesTableView numberOfSelectedRows] == 1)
			[globalValuesSheet makeFirstResponder:globalValuesTableView];

		// Replace the current map pair with the last selected global value
		if([replaceAfterSavingCheckBox state] == NSOnState && [globalValuesTableView numberOfSelectedRows] == 1) {

			[fieldMappingArray replaceObjectAtIndex:[fieldMapperTableView selectedRow] withObject:[NSNumber numberWithInteger:[globalValuesTableView selectedRow]+numberOfImportColumns]];

			// Set corresponding operator to doImport if not set to isEqualKey
			if(![isEqualKey isEqualToNumber:[fieldMappingOperatorArray objectAtIndex:[fieldMapperTableView selectedRow]]])
				[fieldMappingOperatorArray replaceObjectAtIndex:[fieldMapperTableView selectedRow] withObject:doImportKey];

			// Set alignment popup to "custom order"
			[alignByPopup selectItemWithTag:3];

		}

	// This must happen before orderOut:nil as that might cause the tableview to redraw which would in turn invalidate
	// a newly added globalValue when updateFieldMappingButtonCell has not been run before.
	[self updateFieldMappingButtonCell];

	[NSApp endSheet:globalValuesSheet returnCode:[sender tag]];
}

#pragma mark -
#pragma mark Advanced Sheet

- (IBAction)openAdvancedSheet:(id)sender
{
	showAdvancedView = !showAdvancedView;
	if(showAdvancedView) {
		[advancedButton setState:NSOnState];
		[self changeImportMethod:nil];
	} else {
		[advancedButton setState:NSOffState];
		[advancedBox setHidden:YES];
		[advancedReplaceView setHidden:YES];
		[advancedUpdateView setHidden:YES];
		[advancedInsertView setHidden:YES];
		[self resizeWindowByHeightDelta:0];
	}
}

- (IBAction)advancedCheckboxValidation:(id)sender
{

	if(sender == lowPriorityReplaceCheckBox && [lowPriorityReplaceCheckBox state] == NSOnState) {
		[delayedReplaceCheckBox setState:NO];
		return;
	}
	if(sender == delayedReplaceCheckBox && [delayedReplaceCheckBox state] == NSOnState) {
		[lowPriorityReplaceCheckBox setState:NO];
		return;
	}
	if(sender == skipexistingRowsCheckBox) {
		if([skipexistingRowsCheckBox state] == NSOnState) {
			[delayedCheckBox setState:NO];
			[delayedCheckBox setEnabled:NO];
			[onupdateCheckBox setState:YES];
			[onupdateCheckBox setEnabled:NO];
			[onupdateTextView setEditable:YES];
			[onupdateTextView setSelectedRange:NSMakeRange(0,[[onupdateTextView string] length])];
			NSMutableArray *queryParts = [NSMutableArray arrayWithCapacity:[primaryKeyFields count]];
			for (NSString *eachFieldName in primaryKeyFields) {
				[queryParts addObject:[NSString stringWithFormat:@"%@ = %@", [eachFieldName backtickQuotedString], [eachFieldName backtickQuotedString]]];
			}
			[onupdateTextView insertText:[queryParts componentsJoinedByString:@" AND "]];
			[onupdateTextView setBackgroundColor:[NSColor lightGrayColor]];
			[onupdateTextView setEditable:NO];
		} else {
			[delayedCheckBox setEnabled:YES];
			[onupdateCheckBox setState:NO];
			[onupdateCheckBox setEnabled:YES];
			BOOL oldEditableState = [onupdateTextView isEditable];
			[onupdateTextView setEditable:YES];
			[onupdateTextView setSelectedRange:NSMakeRange(0,[[onupdateTextView string] length])];
			[onupdateTextView insertText:@""];
			[onupdateTextView setEditable:oldEditableState];
		}
	}

	if(sender == lowPriorityCheckBox && [lowPriorityCheckBox state] == NSOnState) {
		[highPriorityCheckBox setState:NO];
		[delayedCheckBox setState:NO];
		if([skipexistingRowsCheckBox state] == NSOffState)
			[onupdateCheckBox setEnabled:YES];
	}
	if(sender == highPriorityCheckBox && [highPriorityCheckBox state] == NSOnState) {
		[lowPriorityCheckBox setState:NO];
		[delayedCheckBox setState:NO];
		if([skipexistingRowsCheckBox state] == NSOffState)
			[onupdateCheckBox setEnabled:YES];
	}
	if(sender == delayedCheckBox) {
		if([delayedCheckBox state] == NSOnState) {
			[lowPriorityCheckBox setState:NO];
			[highPriorityCheckBox setState:NO];
			[onupdateCheckBox setState:NO];
			[onupdateCheckBox setEnabled:NO];
		} else {
			[onupdateCheckBox setEnabled:YES];
		}
	}

	if(sender == onupdateCheckBox && [onupdateCheckBox state] == NSOnState) {
		[onupdateTextView setBackgroundColor:[NSColor whiteColor]];
		[onupdateTextView setEditable:YES];
		[[self window] makeFirstResponder:onupdateTextView];
	}
	if([onupdateCheckBox state] == NSOffState && [skipexistingRowsCheckBox state] == NSOffState) {
		[onupdateTextView setBackgroundColor:[NSColor lightGrayColor]];
		[onupdateTextView setEditable:NO];
	}
}

- (IBAction)insertPulldownValue:(id)sender
{
	if ([globalValuesTableView numberOfSelectedRows] != 1 || [globalValuesTableView editedRow] < 0) return;

	NSInteger selectedIndex = [sender indexOfItem:[sender selectedItem]] - 4;
	
	if ([[[NSApp keyWindow] firstResponder] respondsToSelector:@selector(insertText:)]) {
		[[[NSApp keyWindow] firstResponder] insertText:[NSString stringWithFormat:@"$%ld", (long)selectedIndex]];
	}
}

- (IBAction)insertRecentGlobalValue:(id)sender
{
	if ([globalValuesTableView numberOfSelectedRows] != 1 || [globalValuesTableView editedRow] < 0) return;

	if ([[[NSApp keyWindow] firstResponder] respondsToSelector:@selector(insertText:)]) {
		[[[NSApp keyWindow] firstResponder] insertText:[sender title]];
	}
}

#pragma mark -
#pragma mark Others

- (void)resizeWindowByHeightDelta:(NSInteger)delta
{
#ifndef SP_CODA /* resizeWindowByHeightDelta: */
	NSAutoresizingMaskOptions tableMask = [fieldMapperTableScrollView autoresizingMask];
	NSAutoresizingMaskOptions headerSwitchMask = [importFieldNamesHeaderSwitch autoresizingMask];
	NSAutoresizingMaskOptions alignPopupMask = [alignByPopup autoresizingMask];
	NSAutoresizingMaskOptions alignPopupLabelMask = [alignByPopupLabel autoresizingMask];
	NSAutoresizingMaskOptions importMethodLabelMask = [importMethodLabel autoresizingMask];
	NSAutoresizingMaskOptions importMethodMask = [importMethodPopup autoresizingMask];
	NSAutoresizingMaskOptions advancedButtonMask = [advancedButton autoresizingMask];
	NSAutoresizingMaskOptions advancedLabelMask = [advancedLabel autoresizingMask];
	NSAutoresizingMaskOptions insertViewMask = [advancedInsertView autoresizingMask];
	NSAutoresizingMaskOptions updateViewMask = [advancedUpdateView autoresizingMask];
	NSAutoresizingMaskOptions replaceViewMask = [advancedReplaceView autoresizingMask];

	NSRect frame = [[self window] frame];
	if(frame.size.height>600 && delta > heightOffset) {
		frame.origin.y += [advancedInsertView frame].size.height;
		frame.size.height -= [advancedInsertView frame].size.height;
		[[self window] setFrame:frame display:YES animate:YES];
	}

	[fieldMapperTableScrollView setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[importFieldNamesHeaderSwitch setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[alignByPopup setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[alignByPopupLabel setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[importMethodLabel setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[importMethodPopup setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[advancedButton setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[advancedLabel setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[advancedInsertView setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[advancedUpdateView setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[advancedReplaceView setAutoresizingMask:NSViewNotSizable|NSViewMinYMargin];
	[advancedBox setAutoresizingMask:NSViewNotSizable|NSViewWidthSizable|NSViewHeightSizable|NSViewMaxXMargin|NSViewMinXMargin];

	NSInteger newMinHeight = (windowMinHeigth-heightOffset+delta < windowMinHeigth) ? windowMinHeigth : windowMinHeigth-heightOffset+delta;
	[[self window] setMinSize:NSMakeSize(windowMinWidth, newMinHeight)];
	frame.origin.y += heightOffset;
	frame.size.height -= heightOffset;
	heightOffset = delta;
	frame.origin.y -= heightOffset;
	frame.size.height += heightOffset;
	[[self window] setFrame:frame display:YES animate:YES];

	[fieldMapperTableScrollView setAutoresizingMask:tableMask];
	[importFieldNamesHeaderSwitch setAutoresizingMask:headerSwitchMask];
	[alignByPopup setAutoresizingMask:alignPopupMask];
	[alignByPopupLabel setAutoresizingMask:alignPopupLabelMask];
	[importMethodLabel setAutoresizingMask:importMethodLabelMask];
	[importMethodPopup setAutoresizingMask:importMethodMask];
	[advancedButton setAutoresizingMask:advancedButtonMask];
	[advancedLabel setAutoresizingMask:advancedLabelMask];
	[advancedReplaceView setAutoresizingMask:replaceViewMask];
	[advancedUpdateView setAutoresizingMask:updateViewMask];
	[advancedInsertView setAutoresizingMask:insertViewMask];
	[advancedBox setAutoresizingMask:NSViewNotSizable|NSViewWidthSizable|NSViewMaxYMargin|NSViewMaxXMargin|NSViewMinXMargin];
#endif
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if ([sheet respondsToSelector:@selector(orderOut:)]) [sheet orderOut:nil];

	if (sheet == globalValuesSheet) {
		addGlobalSheetIsOpen = NO;
	}
}

- (void)matchHeaderNames
{
	if(![self hasContentRows]) return;

	NSMutableArray *fileHeaderNames = [NSMutableArray array];
	[fileHeaderNames setArray:NSArrayObjectAtIndex(fieldMappingImportArray, 0)];
	NSMutableArray *tableHeaderNames = [NSMutableArray array];
	[tableHeaderNames setArray:fieldMappingTableColumnNames];

	// Create a distance matrix for each file-table name
	// distance will be calculated by using Levenshtein distance minus common prefix and suffix length
	// and minus the length of a fuzzy regex search for a common sequence of characters
	NSUInteger i,j,k;
	NSMutableArray *distMatrix = [NSMutableArray array];
	for(i=0; i < [tableHeaderNames count]; i++) {
		CGFloat   dist     = 1e6f;
		for(j=0; j < [fileHeaderNames count]; j++) {
			id fileHeaderName = NSArrayObjectAtIndex(fileHeaderNames,j);
			if([fileHeaderName isNSNull] || [fileHeaderName isSPNotLoaded]) continue;
			NSString *headerName = [(NSString*)fileHeaderName lowercaseString];
			NSString *tableHeadName = [NSArrayObjectAtIndex(tableHeaderNames,i) lowercaseString];
			dist = [tableHeadName levenshteinDistanceWithWord:headerName];

			// if dist > 0 subtract the length of common prefixes, suffixes, and in common sequence characters
			if(dist > 0.0) {
				dist -= [[tableHeadName commonPrefixWithString:headerName options:NSCaseInsensitiveSearch] length];
				dist -= [[tableHeadName commonPrefixWithString:headerName options:NSCaseInsensitiveSearch|NSBackwardsSearch] length];

				NSMutableString *fuzzyRegexp = [[NSMutableString alloc] initWithCapacity:3];
				unichar c;

				for(k=0; k<[headerName length]; k++) {
					c = [headerName characterAtIndex:k];
					if (c == '.' || c == '(' || c == ')' || c == '[' || c == ']' || c == '{' || c == '}')
						[fuzzyRegexp appendFormat:@".*?\\%c",c];
					else
						[fuzzyRegexp appendFormat:@".*?%c",c];
				}
				dist -= [tableHeadName rangeOfRegex:fuzzyRegexp].length;
				[fuzzyRegexp release];

			} else {
				// Levenshtein distance == 0 means that both names are equal set dist to 
				// a large negative number since dist can be negative due to search for in common chars
				dist = -1e6f;
			}

			[distMatrix addObject:[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithFloat:dist], @"dist",
				NSStringFromRange(NSMakeRange(i,j)), @"match",
				(NSString*)fileHeaderName, @"file",
				NSArrayObjectAtIndex(tableHeaderNames,i), @"table",
				nil]];

		}

	}

	// Sort the matrix according distance
	NSSortDescriptor *sortByDistance = [[[NSSortDescriptor alloc] initWithKey:@"dist" ascending:YES] autorelease];
	[distMatrix sortUsingDescriptors:[NSArray arrayWithObjects:sortByDistance, nil]];

	NSMutableArray *matchedFile  = [NSMutableArray array];
	NSMutableArray *matchedTable = [NSMutableArray array];
	NSUInteger cnt = 0;
	for(NSDictionary* m in distMatrix) {
		if(![matchedFile containsObject:[m objectForKey:@"file"]] && ![matchedTable containsObject:[m objectForKey:@"table"]]) {

			NSRange match = NSRangeFromString([m objectForKey:@"match"]);

			// Set best match
			[fieldMappingArray replaceObjectAtIndex:match.location withObject:[NSNumber numberWithInteger:match.length]];
			[fieldMappingOperatorArray replaceObjectAtIndex:match.location withObject:doImportKey];

			// Remember matched pair
			[matchedTable addObject:[m objectForKey:@"table"]];
			[matchedFile addObject:[m objectForKey:@"file"]];
			cnt++;
		}

		// break if all file names are mapped
		if(cnt >= [fileHeaderNames count]) break;

	}
}

/*
 * Sets up the fieldMapping array to be shown in the tableView
 */
- (void)setupFieldMappingArray
{
	NSUInteger i, value;

	if (!fieldMappingArray) {
		fieldMappingArray = [[NSMutableArray alloc] init];
		NSArray *currentRowValues = NSArrayObjectAtIndex(fieldMappingImportArray, fieldMappingCurrentRow);
		for (i = 0; i < [fieldMappingTableColumnNames count]; i++) {
			if (i < [currentRowValues count]) {
				value = i;
			} else {
				value = 0;
			}

			[fieldMappingArray addObject:[NSNumber numberWithUnsignedInteger:value]];
		}
	}

	[fieldMapperTableView reloadData];
}

/*
 * Update the NSButtonCell items for use in the import_value mapping display
 */
- (void)updateFieldMappingButtonCell
{
	NSUInteger i;
	if(![self hasContentRows]) return;
	[fieldMappingButtonOptions setArray:[fieldMappingImportArray objectAtIndex:fieldMappingCurrentRow]];
	for (i = 0; i < [fieldMappingButtonOptions count]; i++) {
		if ([[fieldMappingButtonOptions objectAtIndex:i] isNSNull])
			[fieldMappingButtonOptions replaceObjectAtIndex:i withObject:[NSString stringWithFormat:@"%li. <%@>", (long)i+1, [prefs objectForKey:SPNullValue]]];
		else if ([[fieldMappingButtonOptions objectAtIndex:i] isSPNotLoaded])
			[fieldMappingButtonOptions replaceObjectAtIndex:i withObject:[NSString stringWithFormat:@"%li. <%@>", (long)i+1, @"DEFAULT"]];
		else
			[fieldMappingButtonOptions replaceObjectAtIndex:i withObject:[NSString stringWithFormat:@"%li. %@", (long)i+1, NSArrayObjectAtIndex(fieldMappingButtonOptions, i)]];
	}

	// Add global values if any
	if((NSInteger)[fieldMappingGlobalValues count]>numberOfImportColumns)
		for( ; i < [fieldMappingGlobalValues count]; i++) {
			if ([NSArrayObjectAtIndex(fieldMappingGlobalValues, i) isNSNull])
				[fieldMappingButtonOptions addObject:[NSString stringWithFormat:@"%li. <%@>", (long)i+1, [prefs objectForKey:SPNullValue]]];
			else
				[fieldMappingButtonOptions addObject:[NSString stringWithFormat:@"%li. %@", (long)i+1, NSArrayObjectAtIndex(fieldMappingGlobalValues, i)]];
		}

	[self _setupFieldMappingPopUpMenus];
	[fieldMapperTableView reloadData];

}

/*
 * Update the NSButtonCell items for use in the operator mapping display
 */
- (void)updateFieldMappingOperatorOptions
{
	if(![[importMethodPopup titleOfSelectedItem] isEqualToString:@"UPDATE"]) {
		[fieldMappingOperatorOptions setArray:[NSArray arrayWithObjects:doImportString, doNotImportString, nil]];
	} else {
		[fieldMappingOperatorOptions setArray:[NSArray arrayWithObjects:doImportString, doNotImportString, isEqualString, nil]];
	}
}

/*
 * Set field name alignment to default
 */
- (void)updateFieldNameAlignment
{

	NSInteger alignment = 0;

#ifndef SP_CODA
	if([prefs integerForKey:SPCSVFieldImportMappingAlignment]
			&& [prefs integerForKey:SPCSVFieldImportMappingAlignment] >= 0
			&& [prefs integerForKey:SPCSVFieldImportMappingAlignment] < 4) {
		alignment = [prefs integerForKey:SPCSVFieldImportMappingAlignment];
	}
#endif

	if(alignment == 2) {
		// Set matching names only if csv file has a header
		if([self importFieldNamesHeader])
			[alignByPopup selectItemWithTag:2];
		else
			[alignByPopup selectItemWithTag:0];
	}
	else {
		[alignByPopup selectItemWithTag:alignment];
	}

	[self changeFieldAlignment:nil];

}

- (void)updateRowNavigation
{
	int firstRowIsHeader = [self importFieldNamesHeader] ? 1 : 0;

	// if the first row becomes a header row it can no longer be a content row
	if(!fieldMappingCurrentRow && firstRowIsHeader && [self hasContentRows]) {
		fieldMappingCurrentRow++;
		[self updateFieldMappingButtonCell];
		[fieldMapperTableView reloadData];
	}

	NSUInteger countRows = [fieldMappingImportArray count];
	[rowDownButton setEnabled:(fieldMappingCurrentRow > firstRowIsHeader)];
	[rowUpButton setEnabled:(SPIntS2U(fieldMappingCurrentRow) < (countRows - 1))];
	
	long displayedCurrentRow = fieldMappingCurrentRow+1-firstRowIsHeader;
	unsigned long displayedTotalRows = (countRows? (countRows - firstRowIsHeader) : 0); //avoid negative values on empty array
	
	NSString *fmt;
	if(fieldMappingImportArrayIsPreview)
		fmt = NSLocalizedString(@"%ld of first %lu record(s)", @"Label showing the index of the selected CSV row (csv partially loaded)");
	else
		fmt = NSLocalizedString(@"%ld of %lu record(s)", @"Label showing the index of the selected CSV row");
	
	[recordCountLabel setStringValue:[NSString stringWithFormat:fmt, displayedCurrentRow, displayedTotalRows]];
}

- (void)validateImportButton
{
	BOOL enableImportButton = YES;
	
	if (newTableMode) {
		if (![tablesListInstance isTableNameValid:[newTableNameTextField stringValue] forType:SPTableTypeTable ignoringSelectedTable:NO]) {
			[importButton setEnabled:NO];
			return;
		}
		
		BOOL hasImportColumns = NO;
		for (NSUInteger i = 0; i < [fieldMappingTableColumnNames count]; i++) {
			NSString *colName = [fieldMappingTableColumnNames objectAtIndex:i];
			BOOL shouldImport = [doImportKey isEqualToNumber:[fieldMappingOperatorArray objectAtIndex:i]];
			if (shouldImport && ![colName length]) {
				[importButton setEnabled:NO];
				return;
			}
			if(!hasImportColumns && shouldImport) hasImportColumns = YES;
		}
		
		if(!hasImportColumns) {
			// new table without any columns is not valid
			[importButton setEnabled:NO];
			return;
		}
		
		for (NSString* fieldType in fieldMappingTableTypes) {
			if(![fieldType length]) {
				[importButton setEnabled:NO];
				return;
			}
		}
	}
	else {
		// we don't want to create a new table and have no rows to import either => can't import nothing
		if(![self hasContentRows]) {
			[importButton setEnabled:NO];
			return;
		}
	}

	if ([[self selectedImportMethod] isEqualToString:@"UPDATE"]) {
		enableImportButton = NO;
		for(id op in fieldMappingOperatorArray) {
			if([isEqualKey isEqualToNumber:op]) {
				enableImportButton = YES;
				break;
			}
		}
	}

	[importButton setEnabled:enableImportButton];

}

/**
 * Menu item interface validation
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	NSInteger row = [fieldMapperTableView selectedRow];

	// Hide/display Remove New Column menu item
	[[[fieldMapperTableView menu] itemAtIndex:3] setHidden:([toBeEditedRowIndexes containsIndex:row]) ? NO : YES];

	if (newTableMode && [menuItem action] == @selector(setAllTypesTo:)) {
		if(row > -1) { // row == -1 on empty selection
			NSString *orgTitle = [[menuItem title] substringToIndex:[[menuItem title] rangeOfString:@":"].location];
			[menuItem setTitle:[NSString stringWithFormat:@"%@: %@", orgTitle, [fieldMappingTableTypes objectAtIndex:row]]];
			[menuItem setHidden:NO];
		}
		else {
			[menuItem setHidden:YES];
			return NO;
		}
	}
	else if (!newTableMode && [menuItem action] == @selector(insertNULLValue:)) {
		return ([[globalValuesTableView selectedRowIndexes] count] == 1) ? YES : NO;
	}
	else if (!newTableMode && [menuItem action] == @selector(removeNewColumn:)) {
		if([toBeEditedRowIndexes containsIndex:row]) {
			NSString *orgTitle = [[menuItem title] substringToIndex:[[menuItem title] rangeOfString:@":"].location];
			[menuItem setTitle:[NSString stringWithFormat:@"%@: %@", orgTitle, [fieldMappingTableColumnNames objectAtIndex:row]]];
			return YES;
		} else {
			NSString *orgTitle = [[menuItem title] substringToIndex:[[menuItem title] rangeOfString:@":"].location];
			[menuItem setTitle:[NSString stringWithFormat:@"%@:", orgTitle]];
			return NO;
		}
	}

	return YES;

}

#pragma mark -
#pragma mark Table view datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
{
	if(aTableView == fieldMapperTableView)
		return [fieldMappingTableColumnNames count];
	else if(aTableView == globalValuesTableView)
		return [fieldMappingGlobalValues count] - numberOfImportColumns;
	return 0;
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
#ifndef SP_CODA
	CGFloat monospacedFontSize = [prefs floatForKey:SPMonospacedFontSize] > 0 ? [prefs floatForKey:SPMonospacedFontSize] : [NSFont smallSystemFontSize];

	[aCell setFont:[prefs boolForKey:SPUseMonospacedFonts] ? [NSFont fontWithName:SPDefaultMonospacedFontName size:monospacedFontSize] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
#endif
}

- (void)tableView:(NSTableView*)aTableView didClickTableColumn:(NSTableColumn *)aTableColumn
{

	if(aTableView == fieldMapperTableView) {
		// A click at the operator column's header toggle all operators
		if ([[aTableColumn identifier] isEqualToString:SPTableViewOperatorColumnID]
				&& [self numberOfRowsInTableView:aTableView]
				&& [fieldMappingOperatorArray count]
				&& [fieldMappingTableColumnNames count]) {
			NSUInteger i;
			NSNumber *globalValue = doImportKey;
			if([doImportKey isEqualToNumber:[fieldMappingOperatorArray objectAtIndex:0]])
				globalValue = doNotImportKey;
			[fieldMappingOperatorArray removeAllObjects];
			for(i=0; i < [fieldMappingTableColumnNames count]; i++)
				[fieldMappingOperatorArray addObject:globalValue];
			[self validateImportButton];
			[fieldMapperTableView reloadData];
		}
	}
}

- (NSString *)tableView:(NSTableView *)aTableView toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex mouseLocation:(NSPoint)mouseLocation
{

	if(aTableView == fieldMapperTableView) {

		if([[aTableColumn identifier] isEqualToString:SPTableViewImportValueColumnID]) {

			if ([doNotImportKey isEqual:[fieldMappingOperatorArray objectAtIndex:rowIndex]]) return [NSString stringWithFormat:@"DEFAULT: %@", [fieldMappingTableDefaultValues objectAtIndex:rowIndex]];

			if([importFieldNamesHeaderSwitch state] == NSOnState) {
				if([NSArrayObjectAtIndex(fieldMappingArray, rowIndex) unsignedIntegerValue]>=[NSArrayObjectAtIndex(fieldMappingImportArray, 0) count])
					return [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"User-defined value", @"user-defined value"), NSArrayObjectAtIndex(fieldMappingGlobalValues, [NSArrayObjectAtIndex(fieldMappingArray, rowIndex) integerValue])];

				if(fieldMappingCurrentRow)
					return [NSString stringWithFormat:@"%@: %@",
													  [NSArrayObjectAtIndex(NSArrayObjectAtIndex(fieldMappingImportArray, 0), [NSArrayObjectAtIndex(fieldMappingArray, rowIndex) integerValue]) description],
													  [NSArrayObjectAtIndex(NSArrayObjectAtIndex(fieldMappingImportArray, fieldMappingCurrentRow), [NSArrayObjectAtIndex(fieldMappingArray, rowIndex) integerValue]) description]];
				else
					return [NSArrayObjectAtIndex(NSArrayObjectAtIndex(fieldMappingImportArray, 0), [NSArrayObjectAtIndex(fieldMappingArray, rowIndex) integerValue]) description];

			}
			else if([importFieldNamesHeaderSwitch state] == NSOffState) {
				NSUInteger colIndex = [NSArrayObjectAtIndex(fieldMappingArray, rowIndex) unsignedIntegerValue];
				NSString *retval;
				if(colIndex >= [NSArrayObjectAtIndex(fieldMappingImportArray, 0) count])
					retval = NSArrayObjectAtIndex(fieldMappingGlobalValues, colIndex);
				else
					retval = NSArrayObjectAtIndex(NSArrayObjectAtIndex(fieldMappingImportArray, fieldMappingCurrentRow), colIndex);
				
				if([retval isNSNull]) retval = NSLocalizedString(@"Value will be imported as MySQL NULL", @"CSV Field Mapping : Table View : Tooltip for fields with NULL value");

				return retval;
			}
		}

		else if([[aTableColumn identifier] isEqualToString:SPTableViewOperatorColumnID]) {
			if([doImportKey isEqual:[aCell objectValue]])
				return NSLocalizedString(@"Import field", @"import field operator tooltip");
			else if([doNotImportKey isEqual:[aCell objectValue]])
				return NSLocalizedString(@"Ignore field", @"ignore field label");
			else if([isEqualKey isEqual:[aCell objectValue]])
				return NSLocalizedString(@"Do UPDATE where field contents match", @"do update operator tooltip");
		}

		else if([[aTableColumn identifier] isEqualToString:SPTableViewTargetFieldColumnID]) {
			return [fieldMappingTableColumnNames objectAtIndex:rowIndex];
		}
	}
	else if(aTableView == globalValuesTableView) {
		if ([[aTableColumn identifier] isEqualToString:SPTableViewGlobalValueColumnID])
			return [fieldMappingGlobalValues objectAtIndex:numberOfImportColumns + rowIndex];
	}
	return @"";
}

- (void)menuNeedsUpdate:(NSMenu *)aMenu
{
	// Note: matching aMenu with "==" will most likely not work, as NSTableView copies it.
	// This technique is based on: http://www.corbinstreehouse.com/blog/2005/07/dynamically-populating-an-nspopupbuttoncell-in-an-nstableview/
	
	NSInteger rowIndex = [fieldMapperTableView selectedRow];
	if(rowIndex < 0)
		return;
	
	NSInteger rowIndexInMenu = firstDefaultItemOffset + rowIndex;
	for (NSInteger i = firstDefaultItemOffset; i < [aMenu numberOfItems]; i++) {
		[[aMenu itemAtIndex:i] setHidden:(i != rowIndexInMenu)];
	}
}

- (void)_setupFieldMappingPopUpMenus
{
	NSPopUpButtonCell *c = [[fieldMapperTableView tableColumnWithIdentifier:SPTableViewImportValueColumnID] dataCell];
	NSMenu *m = [c menu];
	[m setAutoenablesItems:NO];
	[c removeAllItems];
	[c addItemsWithTitles:fieldMappingButtonOptions];
	
	[m addItem:[NSMenuItem separatorItem]];
	
	[c addItemWithTitle:NSLocalizedString(@"Ignore Field", @"ignore field label")];
	[c addItemWithTitle:NSLocalizedString(@"Ignore all Fields", @"ignore all fields menu item")];
	[c addItemWithTitle:NSLocalizedString(@"Import all Fields", @"import all fields menu item")];
	if([[self selectedImportMethod] isEqualToString:@"UPDATE"])
		[c addItemWithTitle:NSLocalizedString(@"Match Field", @"match field menu item")];
	
	[m addItem:[NSMenuItem separatorItem]];
	
	NSMenuItem *menuItem = [m addItemWithTitle:NSLocalizedString(@"Add Value or Expression…", @"add global value or expression menu item") action:@selector(addGlobalSourceVariable:) keyEquivalent:@"g"];
	[menuItem setKeyEquivalentModifierMask:(NSEventModifierFlagOption|NSEventModifierFlagCommand)];
	
	//create all menu items for the "DEFAULT" rows. We will use menuNeedsUpdate: to hide all items that are not needed.
	//This works because NSTableView will copy the menu before showing it, so menuNeedsUpdate: will work on a disposable copy
	//while the full menu is never shown (but it's items are displayed in the table view)
	firstDefaultItemOffset = [m numberOfItems];
	for (id item in fieldMappingTableDefaultValues) {
		NSString *label = [NSString stringWithFormat:NSLocalizedString(@"Default: %@",@"import : csv field mapping : field default value"), item];
		NSMenuItem *defaultItem = [m addItemWithTitle:label action:NULL keyEquivalent:@""];
		[defaultItem setEnabled:NO];
	}
	
	NSPopUpButtonCell *optsCell = [[fieldMapperTableView tableColumnWithIdentifier:SPTableViewOperatorColumnID] dataCell];
	[optsCell removeAllItems];
	[optsCell addItemsWithTitles:fieldMappingOperatorOptions];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{

	if(aTableView == fieldMapperTableView) {
		
		if ([[aTableColumn identifier] isEqualToString:SPTableViewTargetFieldColumnID]) {
			return [fieldMappingTableColumnNames objectAtIndex:rowIndex];
		}

		else if ([[aTableColumn identifier] isEqualToString:SPTableViewTypeColumnID]) {
			if([toBeEditedRowIndexes containsIndex:rowIndex]) {
				[aTableColumn setDataCell:typeComboxBox];
				return [fieldMappingTableTypes objectAtIndex:rowIndex];
			}
			if(newTableMode) {
				[aTableColumn setDataCell:typeComboxBox];
				return [fieldMappingTableTypes objectAtIndex:rowIndex];
			} else {
				NSTokenFieldCell *b = [[[NSTokenFieldCell alloc] initTextCell:[fieldMappingTableTypes objectAtIndex:rowIndex]] autorelease];
				[b setEditable:NO];
				[b setAlignment:NSLeftTextAlignment];
				[b setWraps:NO];
				[b setFont:[NSFont systemFontOfSize:9]];
				[b setDelegate:self];
				[aTableColumn setDataCell:b];
				return [fieldMappingTableTypes objectAtIndex:rowIndex];
			}
		}

		else if ([[aTableColumn identifier] isEqualToString:SPTableViewImportValueColumnID]) {

			// Check if all global value was deleted, if so set assigned field as doNotImportKey
			if([[fieldMappingArray objectAtIndex:rowIndex] unsignedIntegerValue] >= [fieldMappingButtonOptions count]) {
				[fieldMappingOperatorArray replaceObjectAtIndex:rowIndex withObject:doNotImportKey];
			}

			// If user doesn't want to import it show its DEFAULT value if not
			// UPDATE was chosen otherwise hide it.
			if(![doNotImportKey isEqualToNumber:[fieldMappingOperatorArray objectAtIndex:rowIndex]])
				return [fieldMappingArray objectAtIndex:rowIndex];
			else if(![[self selectedImportMethod] isEqualToString:@"UPDATE"])
				return [NSNumber numberWithInteger:firstDefaultItemOffset+rowIndex];
		}

		else if ([[aTableColumn identifier] isEqualToString:SPTableViewOperatorColumnID]) {
			return [fieldMappingOperatorArray objectAtIndex:rowIndex];
		}
	}


	else if(aTableView == globalValuesTableView) {
		if ([[aTableColumn identifier] isEqualToString:SPTableViewValueIndexColumnID]) {
			return [NSString stringWithFormat:@"%ld.", (long)(numberOfImportColumns + rowIndex + 1)];
		}

		else if ([[aTableColumn identifier] isEqualToString:SPTableViewGlobalValueColumnID]) {
			return [fieldMappingGlobalValues objectAtIndex:numberOfImportColumns + rowIndex];
		}

		else if ([[aTableColumn identifier] isEqualToString:SPTableViewSqlColumnID])
			return [fieldMappingGlobalValuesSQLMarked objectAtIndex:numberOfImportColumns + rowIndex];

	}


	return nil;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if(aTableView == globalValuesTableView) return YES;

	if([toBeEditedRowIndexes containsIndex:rowIndex]) return YES;

	if(!newTableMode) return NO;

	return YES;

}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{

	if(aTableView == fieldMapperTableView) {
		if ([[aTableColumn identifier] isEqualToString:SPTableViewImportValueColumnID]) {
			if([anObject integerValue] > (NSInteger)[fieldMappingButtonOptions count]) {
				// Ignore field - set operator to doNotImportKey
				if([anObject integerValue] == (NSInteger)[fieldMappingButtonOptions count]+1) {
					lastDisabledCSVFieldcolumn = [fieldMappingArray objectAtIndex:rowIndex];
					[fieldMappingOperatorArray replaceObjectAtIndex:rowIndex withObject:doNotImportKey];
					[aTableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.0];
				}
				// Ignore all field - set all operator to doNotImportKey
				else if([anObject integerValue] == (NSInteger)[fieldMappingButtonOptions count]+2) {
					NSUInteger i;
					NSNumber *globalValue = doNotImportKey;
					[fieldMappingOperatorArray removeAllObjects];
					for(i=0; i < [fieldMappingTableColumnNames count]; i++)
						[fieldMappingOperatorArray addObject:globalValue];
					[aTableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.0];
				}
				// Import all field - set all operator to doImport
				else if([anObject integerValue] == (NSInteger)[fieldMappingButtonOptions count]+3) {
					NSUInteger i;
					NSNumber *globalValue = doImportKey;
					[fieldMappingOperatorArray removeAllObjects];
					for(i=0; i < [fieldMappingTableColumnNames count]; i++)
						[fieldMappingOperatorArray addObject:globalValue];
					[aTableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.0];
				}
				else if([[self selectedImportMethod] isEqualToString:@"UPDATE"] && [anObject integerValue] == (NSInteger)[fieldMappingButtonOptions count]+4) {
					[fieldMappingOperatorArray replaceObjectAtIndex:rowIndex withObject:isEqualKey];
					[aTableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.0];
				}
				// Add global value
				else if([anObject integerValue] == ([[self selectedImportMethod] isEqualToString:@"UPDATE"]) ? [fieldMappingButtonOptions count]+6 : [fieldMappingButtonOptions count]+5) {
					[aTableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.0];
					[self addGlobalSourceVariable:nil];
				}
				[self validateImportButton];

				return;
			}

			// If user changed the order set alignment popup to "custom order"
			if([fieldMappingArray objectAtIndex:rowIndex] != anObject)
				[alignByPopup selectItemWithTag:3];

			[fieldMappingArray replaceObjectAtIndex:rowIndex withObject:anObject];

			// If user _changed_ the csv file column set the operator to doImport if not set to =
			if([(NSNumber*)anObject integerValue] > -1 && ![isEqualKey isEqualToNumber:NSArrayObjectAtIndex(fieldMappingOperatorArray, rowIndex)])
				[fieldMappingOperatorArray replaceObjectAtIndex:rowIndex withObject:doImportKey];

			[self validateImportButton];

		}

		else if ([[aTableColumn identifier] isEqualToString:SPTableViewTargetFieldColumnID]) {
			if(newTableMode || [toBeEditedRowIndexes containsIndex:rowIndex]) {
				if([(NSString*)anObject length]) {
					[fieldMappingTableColumnNames replaceObjectAtIndex:rowIndex withObject:anObject];
				}
			}
		}

		else if ([[aTableColumn identifier] isEqualToString:SPTableViewTypeColumnID]) {
			if(newTableMode || [toBeEditedRowIndexes containsIndex:rowIndex]) {
				if([(NSString*)anObject length]) {
					[fieldMappingTableTypes replaceObjectAtIndex:rowIndex withObject:anObject];
					if(![defaultFieldTypesForComboBox containsObject:anObject])
						[defaultFieldTypesForComboBox insertObject:anObject atIndex:0];
				}
			} else {

			}
		}

		else if ([[aTableColumn identifier] isEqualToString:SPTableViewOperatorColumnID]) {
			if([doNotImportKey isEqualToNumber:[fieldMappingOperatorArray objectAtIndex:rowIndex]]) {
				[fieldMappingOperatorArray replaceObjectAtIndex:rowIndex withObject:anObject];
				[fieldMappingArray replaceObjectAtIndex:rowIndex withObject:lastDisabledCSVFieldcolumn];
			} else {
				if([doNotImportKey isEqual:anObject]) lastDisabledCSVFieldcolumn = [fieldMappingArray objectAtIndex:rowIndex];
				[fieldMappingOperatorArray replaceObjectAtIndex:rowIndex withObject:anObject];
			}
			[self validateImportButton];
		}
	}
	else if(aTableView == globalValuesTableView) {
		if ([[aTableColumn identifier] isEqualToString:SPTableViewGlobalValueColumnID]) {

			[fieldMappingGlobalValues replaceObjectAtIndex:(numberOfImportColumns + rowIndex) withObject:anObject];

			// If anObject contains $1 etc. enable SQL checkbox
			if([anObject isMatchedByRegex:@"(?<!\\\\)\\$\\d+"])
				[fieldMappingGlobalValuesSQLMarked replaceObjectAtIndex:(numberOfImportColumns + rowIndex) withObject:@1];

			// Store anObject as recent global value if it's new
			NSMutableArray *recents = [NSMutableArray array];
#ifndef SP_CODA
			if([prefs objectForKey:SPGlobalValueHistory] && [[prefs objectForKey:SPGlobalValueHistory] isKindOfClass:[NSArray class]] && [[prefs objectForKey:SPGlobalValueHistory] count])
				[recents setArray:[prefs objectForKey:SPGlobalValueHistory]];
#endif
			if([recents containsObject:anObject])
				[recents removeObject:anObject];
			[recents insertObject:anObject atIndex:0];
			while([recents count] > 20)
				[recents removeObjectAtIndex:[recents count]-1];
#ifndef SP_CODA
			if([recents count])
				[prefs setObject:recents forKey:SPGlobalValueHistory];
#endif

			// Re-init recent menu
			[recentGlobalValueMenu removeAllItems];
			for(id item in recents)
				[recentGlobalValueMenu addItemWithTitle:item action:@selector(insertRecentGlobalValue:) keyEquivalent:@""];

		} else if ([[aTableColumn identifier] isEqualToString:SPTableViewSqlColumnID]) {
			[fieldMappingGlobalValuesSQLMarked replaceObjectAtIndex:(numberOfImportColumns + rowIndex) withObject:anObject];
		}
	}
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	id object = [aNotification object];

	if (object == globalValuesTableView) {
		[removeGlobalValueButton setEnabled:([globalValuesTableView numberOfSelectedRows] > 0)];
		[insertNULLValueButton setEnabled:([globalValuesTableView numberOfSelectedRows] == 1)];
	}

}


/*
 * Trap the enter, escape, tab and arrow keys, overriding default behaviour and continuing/ending editing,
 * only within the current row of the tableView only in newTableMode.
 */
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{

	if((!newTableMode || addGlobalSheetIsOpen) && ![toBeEditedRowIndexes containsIndex:[fieldMapperTableView selectedRow]]) return NO;

	NSInteger row, column;

	row = [fieldMapperTableView editedRow];
	column = [fieldMapperTableView editedColumn];

	BOOL isCellComplex = ([[fieldMapperTableView preparedCellAtColumn:column row:row] isKindOfClass:[NSComboBoxCell class]]) ? YES : NO;

	// Trap tab key
	// -- for handling of blob fields and to check if it's editable look at [[self delegate] control:textShouldBeginEditing:]
	if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(insertTab:)] )
	{
		[[control window] makeFirstResponder:control];

		// Save the current line if it's the last field in the table
		if ( [fieldMapperTableView numberOfColumns] - 1 == column) {
			[[fieldMapperTableView window] makeFirstResponder:fieldMapperTableView];
		} else {
			// Select the next field for editing
			[fieldMapperTableView editColumn:column+1 row:row withEvent:nil select:YES];
		}

		return YES;
	}

	// Trap shift-tab key
	else if ( [textView methodForSelector:command] == [textView methodForSelector:@selector(insertBacktab:)] )
	{
		[[control window] makeFirstResponder:control];

		// Save the current line if it's the last field in the table
		if ( column < 1 ) {
			[[fieldMapperTableView window] makeFirstResponder:fieldMapperTableView];
		} else {
			// Select the previous field for editing
			[fieldMapperTableView editColumn:column-1 row:row withEvent:nil select:YES];
		}

		return YES;
	}

	// Trap enter key
	else if (  [textView methodForSelector:command] == [textView methodForSelector:@selector(insertNewline:)] )
	{

		if(isCellComplex && newTableMode) return NO;

		// If newTableNameTextField is active enter key closes the sheet
		if(control == newTableNameTextField) {
			NSButton *b = [[[NSButton alloc] init] autorelease];
			[b setTag:1];
			[self closeSheet:b];
			return YES;
		}

		[[self window] endEditingFor:nil];
		[[control window] makeFirstResponder:control];
		return YES;

	}

	// Trap down arrow key
	else if (  [textView methodForSelector:command] == [textView methodForSelector:@selector(moveDown:)] )
	{

		if(isCellComplex) return NO;

		NSInteger newRow = row+1;
		if (newRow>=[self numberOfRowsInTableView:fieldMapperTableView]) return YES; //check if we're already at the end of the list

		[[control window] makeFirstResponder:control];

		[fieldMapperTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
		[fieldMapperTableView editColumn:column row:newRow withEvent:nil select:YES];
		return YES;
	}

	// Trap up arrow key
	else if (  [textView methodForSelector:command] == [textView methodForSelector:@selector(moveUp:)] )
	{

		if(isCellComplex) return NO;

		if (row==0) return YES; //already at the beginning of the list
		NSUInteger newRow = row-1;

		[[control window] makeFirstResponder:control];

		if(![toBeEditedRowIndexes containsIndex:newRow]) return NO;

		[fieldMapperTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO];
		[fieldMapperTableView editColumn:column row:newRow withEvent:nil select:YES];
		return YES;
	}


	// Trap the escape key
	else if (  [[control window] methodForSelector:command] == [[control window] methodForSelector:@selector(cancelOperation:)] )
	{

		// Abort editing
		[control abortEditing];

		// Preserve the focus
		[[fieldMapperTableView window] makeFirstResponder:fieldMapperTableView];

		return YES;
	}

	return NO;

}

#pragma mark -
#pragma mark NSTextField delegates


/*
 * Validate some user input in newTableMode
 */
- (void)controlTextDidChange:(NSNotification *)notification
{

	if(!newTableMode) return;

	[self validateImportButton];

}

#pragma mark -
#pragma mark NSComboBox delegates

- (id)comboBoxCell:(NSComboBoxCell *)aComboBoxCell objectValueForItemAtIndex:(NSInteger)anIndex
{
	return [defaultFieldTypesForComboBox objectAtIndex:anIndex];
}

- (NSInteger)numberOfItemsInComboBoxCell:(NSComboBoxCell *)aComboBoxCell
{
	return [defaultFieldTypesForComboBox count];
}

@end
