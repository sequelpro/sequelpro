//
//  $Id$
//
//  SPFieldMapperController.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on February 01, 2010
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

#import "SPFieldMapperController.h"
#import "SPTableData.h"
#import "TableDump.h"
#import "TablesList.h"
#import "SPArrayAdditions.h"
#import "SPStringAdditions.h"
#import "SPConstants.h"
#import "SPNotLoaded.h"
#import "CMTextView.h"

@implementation SPFieldMapperController

@synthesize sourcePath;

#pragma mark -
#pragma mark Initialization

/**
 * Initialize the field mapper
 */
- (id)initWithDelegate:(id)managerDelegate
{
	if (self = [super initWithWindowNibName:@"DataMigrationDialog"]) {

		fieldMappingCurrentRow = 0;
		if(managerDelegate == nil) {
			NSBeep();
			NSLog(@"FieldMapperController was called without a delegate.");
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
		fieldMappingGlobalValuesSQLMarked = [[NSMutableArray alloc] init];
		fieldMappingArray = nil;

		lastDisabledCSVFieldcolumn = [NSNumber numberWithInteger:0];

		doImport          = [NSNumber numberWithInteger:0];
		doNotImport       = [NSNumber numberWithInteger:1];
		isEqual           = [NSNumber numberWithInteger:2];
		doImportString    = @"―";
		doNotImportString = @" ";
		isEqualString     = @"=";

		prefs = [NSUserDefaults standardUserDefaults];
	}
	
	return self;
}

- (void)awakeFromNib
{

	// Set source path
	if([sourcePath hasPrefix:SPImportClipboardTempFileNamePrefix]) {
		[fileSourcePath setURL:[NSURL fileURLWithPath:NSLocalizedString(@"Clipboard", @"Clipboard")]];
	} else {
		[fileSourcePath setURL:[NSURL fileURLWithPath:sourcePath]];
	}
	[fileSourcePath setDoubleAction:@selector(goBackToFileChooser:)];

	[onupdateTextView setDelegate:theDelegate];
	windowMinWidth = [[self window] minSize].width;
	windowMinHeigth = [[self window] minSize].height;

	// Init table target popup menu
	[tableTargetPopup removeAllItems];
	if([[theDelegate valueForKeyPath:@"tablesListInstance"] allTableNames]) {
		[tableTargetPopup addItemsWithTitles:[[theDelegate valueForKeyPath:@"tablesListInstance"] allTableNames]];
		[[tableTargetPopup menu] addItem:[NSMenuItem separatorItem]];
		[tableTargetPopup addItemWithTitle:NSLocalizedString(@"Refresh List", @"refresh list menu item")];

		// Select either the currently selected table, or the first item in the list
		if ([[theDelegate valueForKeyPath:@"tableDocumentInstance"] table] != nil && ![[[theDelegate valueForKeyPath:@"tablesListInstance"] tableName] isEqualToString:@""]) {
			[tableTargetPopup selectItemWithTitle:[[theDelegate valueForKeyPath:@"tablesListInstance"] tableName]];
		} else {
			[tableTargetPopup selectItemAtIndex:0];
		}

	}
	
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
	primaryKeyField = nil;
	heightOffset = 0;
	[advancedReplaceView setHidden:YES];
	[advancedUpdateView setHidden:YES];
	[advancedInsertView setHidden:YES];

	[self changeHasHeaderCheckbox:self];
	[self changeTableTarget:self];
	[[self window] makeFirstResponder:fieldMapperTableView];
	if([fieldMappingTableColumnNames count])
		[fieldMapperTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];

	[removeGlobalValueButton setEnabled:([globalValuesTableView numberOfSelectedRows] > 0)];
	[insertNULLValueButton setEnabled:([globalValuesTableView numberOfSelectedRows] == 1)];

	[self updateFieldNameAlignment];

}

- (void)dealloc
{
	if (mySQLConnection) [mySQLConnection release];
	if (sourcePath) [sourcePath release];
	if (fieldMappingTableColumnNames) [fieldMappingTableColumnNames release];
	if (fieldMappingTableTypes) [fieldMappingTableTypes release];
	if (fieldMappingArray) [fieldMappingArray release];
	if (fieldMappingButtonOptions) [fieldMappingButtonOptions release];
	if (fieldMappingOperatorOptions) [fieldMappingOperatorOptions release];
	if (fieldMappingOperatorArray) [fieldMappingOperatorArray release];
	if (fieldMappingGlobalValues) [fieldMappingGlobalValues release];
	if (fieldMappingGlobalValuesSQLMarked) [fieldMappingGlobalValuesSQLMarked release];
	if (fieldMappingTableDefaultValues) [fieldMappingTableDefaultValues release];
	if (primaryKeyField) [primaryKeyField release];
	[super dealloc];
}

#pragma mark -
#pragma mark Setter methods

- (void)setConnection:(MCPConnection *)theConnection
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
	for(NSInteger i=0; i < [fieldMappingGlobalValues count]; i++)
		if([[fieldMappingGlobalValuesSQLMarked objectAtIndex:i] boolValue])
			[globals addObject:[fieldMappingGlobalValues objectAtIndex:i]];
		else
			[globals addObject:[NSString stringWithFormat:@"'%@'", [fieldMappingGlobalValues objectAtIndex:i]]];

	return globals;
}

- (BOOL)globalValuesInUsage
{
	NSInteger i = 0;
	for(id item in fieldMappingArray) {
		if([item intValue] >= numberOfImportColumns && [fieldMappingOperatorArray objectAtIndex:i] != doNotImport)
			return YES;
		i++;
	}
	return NO;
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
	return ([importFieldNamesHeaderSwitch state] == NSOnState)?YES:NO;
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

#pragma mark -
#pragma mark IBAction methods

- (IBAction)closeSheet:(id)sender
{
	[advancedReplaceView setHidden:YES];
	[advancedUpdateView setHidden:YES];
	[advancedInsertView setHidden:YES];
	[advancedBox setHidden:YES];
	[self resizeWindowByHeightDelta:0];
	[NSApp endSheet:[self window] returnCode:[sender tag]];
}

- (IBAction)changeTableTarget:(id)sender
{

	// Is Refresh List chosen?
	if([tableTargetPopup selectedItem] == [tableTargetPopup lastItem]) {
		[tableTargetPopup removeAllItems];
		// Update tables list
		[[theDelegate valueForKeyPath:@"tablesListInstance"] updateTables:nil];
		if([[theDelegate valueForKeyPath:@"tablesListInstance"] allTableNames]) {
			[tableTargetPopup addItemsWithTitles:[[theDelegate valueForKeyPath:@"tablesListInstance"] allTableNames]];
			[[tableTargetPopup menu] addItem:[NSMenuItem separatorItem]];
			[tableTargetPopup addItemWithTitle:NSLocalizedString(@"Refresh List", @"refresh list menu item")];
		}
		return;
	}

	NSInteger i;

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
	// NSLog(@"d %@", tableDetails);
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
				if (primaryKeyField) [primaryKeyField release];
				primaryKeyField = [[tableDetails objectForKey:@"primarykeyfield"] retain];
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
	if (fieldMappingArray) [fieldMappingArray release], fieldMappingArray = nil;
	[self setupFieldMappingArray];
	[rowDownButton setEnabled:NO];
	[rowUpButton setEnabled:([fieldMappingImportArray count] > 1)];
	[recordCountLabel setStringValue:[NSString stringWithFormat:@"%ld of %@%lu records", (long)(fieldMappingCurrentRow+1), fieldMappingImportArrayIsPreview?@"first ":@"", (unsigned long)[fieldMappingImportArray count]]];

	[self updateFieldMappingButtonCell];
	[self updateFieldMappingOperatorOptions];

	// Set all operators to doNotImport
	[fieldMappingOperatorArray removeAllObjects];
	for(i=0; i < [fieldMappingTableColumnNames count]; i++)
		[fieldMappingOperatorArray addObject:doNotImport];

	// Set the first n operators to doImport
	if([fieldMappingImportArray count]) {
		NSInteger possibleImports = ([NSArrayObjectAtIndex(fieldMappingImportArray, 0) count] > [fieldMappingTableColumnNames count]) ? [fieldMappingTableColumnNames count] : [NSArrayObjectAtIndex(fieldMappingImportArray, 0) count];
		for(i=0; i < possibleImports; i++)
			[fieldMappingOperatorArray replaceObjectAtIndex:i withObject:doImport];
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

	[fieldMapperTableView reloadData];

}

- (IBAction)changeImportMethod:(id)sender
{
	NSInteger i;

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

	// If operator is set to = for UPDATE method replace it by doNotImport
	if(![[importMethodPopup titleOfSelectedItem] isEqualToString:@"UPDATE"]) {
		[advancedButton setEnabled:YES];
		for(i=0; i<[fieldMappingTableColumnNames count]; i++) {
			if([fieldMappingOperatorArray objectAtIndex:i] == isEqual) {
				[fieldMappingOperatorArray replaceObjectAtIndex:i withObject:doNotImport];
			}
		}
	} else {
		[advancedButton setEnabled:YES];
	}

	[self validateImportButton];

	[self updateFieldMappingOperatorOptions];
	[fieldMapperTableView reloadData];
}

- (IBAction)changeFieldAlignment:(id)sender
{

	if(![fieldMappingImportArray count]) return;

	NSInteger i;
	NSInteger possibleImports = ([NSArrayObjectAtIndex(fieldMappingImportArray, 0) count] > [fieldMappingTableColumnNames count]) ? [fieldMappingTableColumnNames count] : [NSArrayObjectAtIndex(fieldMappingImportArray, 0) count];

	if(possibleImports < 1) return;

	switch([[alignByPopup selectedItem] tag]) {
		case 0: // file order
		for(i=0; i<possibleImports; i++)
			[fieldMappingArray replaceObjectAtIndex:i withObject:[NSNumber numberWithInteger:i]];
		break;
		case 1: // reversed file order
		possibleImports--;
		for(i=possibleImports; i>=0; i--)
			[fieldMappingArray replaceObjectAtIndex:possibleImports-i withObject:[NSNumber numberWithInteger:i]];
		break;
		case 2: // try to align header and table target field names via Levenshtein distance
		[self matchHeaderNames];
		break;
	}
	[fieldMapperTableView reloadData];

	// Remember last field alignment if not "custom order"
	if([[alignByPopup selectedItem] tag] != 3)
		[prefs setInteger:[[alignByPopup selectedItem] tag] forKey:SPCSVFieldImportMappingAlignment];

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
	
	[recordCountLabel setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%ld of %@%lu records", @"%ld of %@%lu records"), (long)(fieldMappingCurrentRow+1), fieldMappingImportArrayIsPreview?@"first ":@"", (unsigned long)[fieldMappingImportArray count]]];
	
	// enable/disable buttons
	[rowDownButton setEnabled:(fieldMappingCurrentRow != 0)];
	[rowUpButton setEnabled:(fieldMappingCurrentRow != ([fieldMappingImportArray count]-1))];
}

- (IBAction)changeHasHeaderCheckbox:(id)sender
{
	[matchingNameMenuItem setEnabled:([importFieldNamesHeaderSwitch state] == NSOnState)?YES:NO];
}

- (IBAction)goBackToFileChooser:(id)sender
{
	[NSApp endSheet:[self window] returnCode:[sender tag]];
	if([sourcePath hasPrefix:SPImportClipboardTempFileNamePrefix]) {
		[theDelegate importFromClipboard];
	} else {
		[theDelegate importFile];
	}
}

#pragma mark -
#pragma mark Global Value Sheet

- (IBAction)addGlobalSourceVariable:(id)sender
{
	[NSApp beginSheet:globalValuesSheet 
		modalForWindow:[self window] 
		modalDelegate:self 
		didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
	[self addGlobalValue:nil];
}

- (IBAction)addGlobalValue:(id)sender
{
	[fieldMappingGlobalValues addObject:@""];
	[fieldMappingGlobalValuesSQLMarked addObject:[NSNumber numberWithBool:NO]];
	[globalValuesTableView reloadData];
	[globalValuesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[fieldMappingGlobalValues count]-1-numberOfImportColumns] byExtendingSelection:NO];
	[globalValuesTableView editColumn:1 row:[fieldMappingGlobalValues count]-1-numberOfImportColumns withEvent:nil select:YES];
}

- (IBAction)removeGlobalValue:(id)sender
{
	NSIndexSet *indexes = [globalValuesTableView selectedRowIndexes];

	// get last index
	NSUInteger currentIndex = [indexes lastIndex];

	while (currentIndex != NSNotFound) {
		[fieldMappingGlobalValues removeObjectAtIndex:currentIndex+numberOfImportColumns];
		[fieldMappingGlobalValuesSQLMarked removeObjectAtIndex:currentIndex+numberOfImportColumns];
		// get next index (beginning from the end)
		currentIndex = [indexes indexLessThanIndex:currentIndex];
	}

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

		// Set corresponding operator to doImport if not set to isEqual
		if([fieldMappingOperatorArray objectAtIndex:[fieldMapperTableView selectedRow]] != isEqual)
			[fieldMappingOperatorArray replaceObjectAtIndex:[fieldMapperTableView selectedRow] withObject:doImport];

		[fieldMapperTableView reloadData];

		// Set alignment popup to "custom order"
		[alignByPopup selectItemWithTag:3];

	}

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
			[onupdateTextView insertText:[NSString stringWithFormat:@"%@ = %@", [primaryKeyField backtickQuotedString], [primaryKeyField backtickQuotedString]]];
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

#pragma mark -
#pragma mark Others

- (void)resizeWindowByHeightDelta:(NSInteger)delta
{
	NSUInteger tableMask = [fieldMapperTableScrollView autoresizingMask];
	NSUInteger headerSwitchMask = [importFieldNamesHeaderSwitch autoresizingMask];
	NSUInteger alignPopupMask = [alignByPopup autoresizingMask];
	NSUInteger alignPopupLabelMask = [alignByPopupLabel autoresizingMask];
	NSUInteger importMethodLabelMask = [importMethodLabel autoresizingMask];
	NSUInteger importMethodMask = [importMethodPopup autoresizingMask];
	NSUInteger advancedButtonMask = [advancedButton autoresizingMask];
	NSUInteger advancedLabelMask = [advancedLabel autoresizingMask];
	NSUInteger insertViewMask = [advancedInsertView autoresizingMask];
	NSUInteger updateViewMask = [advancedUpdateView autoresizingMask];
	NSUInteger replaceViewMask = [advancedReplaceView autoresizingMask];

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

}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if ([sheet respondsToSelector:@selector(orderOut:)]) [sheet orderOut:nil];
	if (sheet == globalValuesSheet)
		[self updateFieldMappingButtonCell];
}

- (void)matchHeaderNames
{
	if(![fieldMappingImportArray count]) return;

	NSMutableArray *fileHeaderNames = [NSMutableArray array];
	[fileHeaderNames setArray:NSArrayObjectAtIndex(fieldMappingImportArray, 0)];
	NSMutableArray *tableHeaderNames = [NSMutableArray array];
	[tableHeaderNames setArray:fieldMappingTableColumnNames];

	NSInteger i,j;
	NSMutableArray *matchedHeaderNames = [NSMutableArray array];
	for(i=0; i < [tableHeaderNames count]; i++) {
		CGFloat minDist = 1e6;
		NSInteger minIndex = 0;
		for(j=0; j < [fileHeaderNames count]; j++) {
			NSString *headerName = [NSArrayObjectAtIndex(fileHeaderNames,j) lowercaseString];
			CGFloat dist = [[NSArrayObjectAtIndex(tableHeaderNames,i) lowercaseString] levenshteinDistanceWithWord:headerName];
			if(dist < minDist && ![matchedHeaderNames containsObject:headerName]) {
				minDist = dist;
				minIndex = j;
			}
			if(dist == 0.0f) [matchedHeaderNames addObject:headerName];
		}
		[fieldMappingArray replaceObjectAtIndex:i withObject:[NSNumber numberWithInteger:minIndex]];
		[fieldMappingOperatorArray replaceObjectAtIndex:i withObject:doImport];
	}

	// If a pair with distance 0 was found set doNotImport to those fields which are still mapped
	// to such csv file header name
	if([matchedHeaderNames count])
		for(i=0; i < [tableHeaderNames count]; i++) {
			NSString *mappedFileHeaderName = [NSArrayObjectAtIndex(fileHeaderNames, [[fieldMappingArray objectAtIndex:i] integerValue]) lowercaseString];
			if([matchedHeaderNames containsObject:mappedFileHeaderName] && ![mappedFileHeaderName isEqualToString:[NSArrayObjectAtIndex(tableHeaderNames, i) lowercaseString]])
				[fieldMappingOperatorArray replaceObjectAtIndex:i withObject:doNotImport];
		}
}

/*
 * Sets up the fieldMapping array to be shown in the tableView
 */
- (void)setupFieldMappingArray
{
	NSInteger i, value;

	if (!fieldMappingArray) {
		fieldMappingArray = [[NSMutableArray alloc] init];
		for (i = 0; i < [fieldMappingTableColumnNames count]; i++) {
			if (i < [NSArrayObjectAtIndex(fieldMappingImportArray, fieldMappingCurrentRow) count] 
					&& ![NSArrayObjectAtIndex(NSArrayObjectAtIndex(fieldMappingImportArray, fieldMappingCurrentRow), i) isKindOfClass:[NSNull class]]) {
				value = i;
			} else {
				value = 0;
			}
			
			[fieldMappingArray addObject:[NSNumber numberWithInteger:value]];
		}
	}

	[fieldMapperTableView reloadData];
}

/*
 * Update the NSButtonCell items for use in the import_value mapping display
 */
- (void)updateFieldMappingButtonCell
{
	NSInteger i;
	if([fieldMappingImportArray count] == 0) return;
	[fieldMappingButtonOptions setArray:[fieldMappingImportArray objectAtIndex:fieldMappingCurrentRow]];
	for (i = 0; i < [fieldMappingButtonOptions count]; i++) {
		if ([[fieldMappingButtonOptions objectAtIndex:i] isNSNull])
			[fieldMappingButtonOptions replaceObjectAtIndex:i withObject:[NSString stringWithFormat:@"%i. <%@>", i+1, [prefs objectForKey:SPNullValue]]];
		else if ([[fieldMappingButtonOptions objectAtIndex:i] isSPNotLoaded])
			[fieldMappingButtonOptions replaceObjectAtIndex:i withObject:[NSString stringWithFormat:@"%i. <%@>", i+1, @"DEFAULT"]];
		else
			[fieldMappingButtonOptions replaceObjectAtIndex:i withObject:[NSString stringWithFormat:@"%i. %@", i+1, NSArrayObjectAtIndex(fieldMappingButtonOptions, i)]];
	}

	// Add global values if any
	if([fieldMappingGlobalValues count]>numberOfImportColumns)
		for(i; i < [fieldMappingGlobalValues count]; i++) {
			if ([NSArrayObjectAtIndex(fieldMappingGlobalValues, i) isNSNull])
				[fieldMappingButtonOptions addObject:[NSString stringWithFormat:@"%i. <%@>", i+1, [prefs objectForKey:SPNullValue]]];
			else
				[fieldMappingButtonOptions addObject:[NSString stringWithFormat:@"%i. %@", i+1, NSArrayObjectAtIndex(fieldMappingGlobalValues, i)]];
		}

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

	if([prefs integerForKey:SPCSVFieldImportMappingAlignment]
			&& [prefs integerForKey:SPCSVFieldImportMappingAlignment] >= 0
			&& [prefs integerForKey:SPCSVFieldImportMappingAlignment] < 4) {
		alignment = [prefs integerForKey:SPCSVFieldImportMappingAlignment];
	}

	// Set matching names only if csv file has an header
	if(importFieldNamesHeader && alignment == 2)
		[alignByPopup selectItemWithTag:2];
	else if(!importFieldNamesHeader && alignment == 2)
		[alignByPopup selectItemWithTag:0];
	else
		[alignByPopup selectItemWithTag:alignment];

	[self changeFieldAlignment:nil];

}

- (void)validateImportButton
{
	BOOL enableImportButton = YES;
	if([[self selectedImportMethod] isEqualToString:@"UPDATE"]) {
		enableImportButton = NO;
		for(id op in fieldMappingOperatorArray) {
			if(op == isEqual) {
				enableImportButton = YES;
				break;
			}
		}
	}
	[importButton setEnabled:enableImportButton];
}

#pragma mark -
#pragma mark Table view datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
{
	if(aTableView == fieldMapperTableView)
		return [fieldMappingTableColumnNames count];
	else if(aTableView == globalValuesTableView)
		return [fieldMappingGlobalValues count] - numberOfImportColumns;
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	[aCell setFont:([prefs boolForKey:SPUseMonospacedFonts]) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
}

- (void)tableView:(NSTableView*)aTableView didClickTableColumn:(NSTableColumn *)aTableColumn
{

	if(aTableView == fieldMapperTableView) {
		// A click at the operator column's header toggle all operators
		if ([[aTableColumn identifier] isEqualToString:@"operator"] 
				&& [self numberOfRowsInTableView:aTableView]
				&& [fieldMappingOperatorArray count]
				&& [fieldMappingTableColumnNames count]) {
			NSInteger i;
			NSNumber *globalValue = doImport;
			if([fieldMappingOperatorArray objectAtIndex:0] == doImport)
				globalValue = doNotImport;
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

		if ([fieldMappingOperatorArray objectAtIndex:rowIndex] == doNotImport) return [NSString stringWithFormat:@"DEFAULT: %@", [fieldMappingTableDefaultValues objectAtIndex:rowIndex]];

		if([[aTableColumn identifier] isEqualToString:@"import_value"] && [importFieldNamesHeaderSwitch state] == NSOnState) {

			if([NSArrayObjectAtIndex(fieldMappingArray, rowIndex) integerValue]>=[NSArrayObjectAtIndex(fieldMappingImportArray, 0) count])
				return [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Global value", @"global value"), NSArrayObjectAtIndex(fieldMappingGlobalValues, [NSArrayObjectAtIndex(fieldMappingArray, rowIndex) integerValue])];

			if(fieldMappingCurrentRow)
				return [NSString stringWithFormat:@"%@: %@", 
					[NSArrayObjectAtIndex(NSArrayObjectAtIndex(fieldMappingImportArray, 0), [NSArrayObjectAtIndex(fieldMappingArray, rowIndex) integerValue]) description],
					[NSArrayObjectAtIndex(NSArrayObjectAtIndex(fieldMappingImportArray, fieldMappingCurrentRow), [NSArrayObjectAtIndex(fieldMappingArray, rowIndex) integerValue]) description]];
			else
				return [NSArrayObjectAtIndex(NSArrayObjectAtIndex(fieldMappingImportArray, 0), [NSArrayObjectAtIndex(fieldMappingArray, rowIndex) integerValue]) description];

		}

		else if([[aTableColumn identifier] isEqualToString:@"import_value"] && [importFieldNamesHeaderSwitch state] == NSOffState)
			return [NSArrayObjectAtIndex(NSArrayObjectAtIndex(fieldMappingImportArray, fieldMappingCurrentRow), [NSArrayObjectAtIndex(fieldMappingArray, rowIndex) integerValue]) description];

		else if([[aTableColumn identifier] isEqualToString:@"operator"]) {
			if([aCell objectValue] == doImport)
				return NSLocalizedString(@"Import field", @"import field operator tooltip");
			else if([aCell objectValue] == doNotImport)
				return NSLocalizedString(@"Ignore field", @"ignore field label");
			else if([aCell objectValue] == isEqual)
				return NSLocalizedString(@"Do UPDATE where field contents match", @"do update operator tooltip");
			else
				return @"";
		}

		else if([[aTableColumn identifier] isEqualToString:@"target_field"])
			return [fieldMappingTableColumnNames objectAtIndex:rowIndex];
	}
	else if(aTableView == globalValuesTableView) {
		if ([[aTableColumn identifier] isEqualToString:@"global_value"])
			return [fieldMappingGlobalValues objectAtIndex:numberOfImportColumns + rowIndex];
	}
	return @"";
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{

	if(aTableView == fieldMapperTableView) {
		if ([[aTableColumn identifier] isEqualToString:@"target_field"]) {
			if ([[aTableColumn dataCell] isKindOfClass:[NSPopUpButtonCell class]]) {
				[(NSPopUpButton *)[aTableColumn dataCell] removeAllItems];
				[(NSPopUpButtonCell *)[aTableColumn dataCell] addItemWithTitle:[fieldMappingTableColumnNames objectAtIndex:rowIndex]];
			}
			return [fieldMappingTableColumnNames objectAtIndex:rowIndex];
		}

		else if ([[aTableColumn identifier] isEqualToString:@"type"]) {
			NSTokenFieldCell *b = [[[NSTokenFieldCell alloc] initTextCell:[fieldMappingTableTypes objectAtIndex:rowIndex]] autorelease];
			[b setEditable:NO];
			[b setAlignment:NSLeftTextAlignment];
			[b setWraps:NO];
			[b setFont:[NSFont systemFontOfSize:9]];
			[b setDelegate:self];
			return b;
		}

		else if ([[aTableColumn identifier] isEqualToString:@"import_value"]) {
			if ([[aTableColumn dataCell] isKindOfClass:[NSPopUpButtonCell class]]) {
				NSPopUpButtonCell *c = [aTableColumn dataCell]; 
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
				[c addItemWithTitle:NSLocalizedString(@"Add Value or Expression…", @"add global value or expression menu item")];
				[c addItemWithTitle:[NSString stringWithFormat:@"DEFAULT: %@", [fieldMappingTableDefaultValues objectAtIndex:rowIndex]]];
				[[m itemAtIndex:[c numberOfItems]-1] setEnabled:NO];

				// If user doesn't want to import it show its DEFAULT value if not
				// UPDATE was chosen otherwise hide it.
				if([fieldMappingOperatorArray objectAtIndex:rowIndex] != doNotImport)
					return [fieldMappingArray objectAtIndex:rowIndex];
				else if(![[self selectedImportMethod] isEqualToString:@"UPDATE"])
					return [NSNumber numberWithInteger:[c numberOfItems]-1];

			}
		} 

		else if ([[aTableColumn identifier] isEqualToString:@"operator"]) {
			if ([[aTableColumn dataCell] isKindOfClass:[NSPopUpButtonCell class]]) {
				[(NSPopUpButtonCell *)[aTableColumn dataCell] removeAllItems];
				[(NSPopUpButtonCell *)[aTableColumn dataCell] addItemsWithTitles:fieldMappingOperatorOptions];
			}
			return [fieldMappingOperatorArray objectAtIndex:rowIndex];
		} 
	}
	
	
	else if(aTableView == globalValuesTableView) {
		if ([[aTableColumn identifier] isEqualToString:@"value_index"]) {
			return [NSString stringWithFormat:@"%ld.", numberOfImportColumns + rowIndex + 1];
		}

		else if ([[aTableColumn identifier] isEqualToString:@"global_value"]) {
			return [fieldMappingGlobalValues objectAtIndex:numberOfImportColumns + rowIndex];
		}

		else if ([[aTableColumn identifier] isEqualToString:@"sql"])
			return [fieldMappingGlobalValuesSQLMarked objectAtIndex:numberOfImportColumns + rowIndex];

	}
	
	
	return nil;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{

	if(aTableView == fieldMapperTableView) {
		if ([[aTableColumn identifier] isEqualToString:@"import_value"]) {
			if([anObject integerValue] > [fieldMappingButtonOptions count]) {
				// Ignore field - set operator to doNotImport
				if([anObject integerValue] == [fieldMappingButtonOptions count]+1) {
					lastDisabledCSVFieldcolumn = [fieldMappingArray objectAtIndex:rowIndex];
					[fieldMappingOperatorArray replaceObjectAtIndex:rowIndex withObject:doNotImport];
					[aTableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.0];
				}
				// Ignore all field - set all operator to doNotImport
				else if([anObject integerValue] == [fieldMappingButtonOptions count]+2) {
					NSInteger i;
					NSNumber *globalValue = doNotImport;
					[fieldMappingOperatorArray removeAllObjects];
					for(i=0; i < [fieldMappingTableColumnNames count]; i++)
						[fieldMappingOperatorArray addObject:globalValue];
					[aTableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.0];
				}
				// Import all field - set all operator to doImport
				else if([anObject integerValue] == [fieldMappingButtonOptions count]+3) {
					NSInteger i;
					NSNumber *globalValue = doImport;
					[fieldMappingOperatorArray removeAllObjects];
					for(i=0; i < [fieldMappingTableColumnNames count]; i++)
						[fieldMappingOperatorArray addObject:globalValue];
					[aTableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.0];
				}
				else if([[self selectedImportMethod] isEqualToString:@"UPDATE"] && [anObject integerValue] == [fieldMappingButtonOptions count]+4) {
					[fieldMappingOperatorArray replaceObjectAtIndex:rowIndex withObject:isEqual];
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
			if([(NSNumber*)anObject integerValue] > -1 && NSArrayObjectAtIndex(fieldMappingOperatorArray, rowIndex) != isEqual)
				[fieldMappingOperatorArray replaceObjectAtIndex:rowIndex withObject:doImport];

			[self validateImportButton];

		}

		else if ([[aTableColumn identifier] isEqualToString:@"operator"]) {
			if([fieldMappingOperatorArray objectAtIndex:rowIndex] == doNotImport) {
				[fieldMappingOperatorArray replaceObjectAtIndex:rowIndex withObject:anObject];
				[fieldMappingArray replaceObjectAtIndex:rowIndex withObject:lastDisabledCSVFieldcolumn];
			} else {
				if(anObject == doNotImport) lastDisabledCSVFieldcolumn = [fieldMappingArray objectAtIndex:rowIndex];
				[fieldMappingOperatorArray replaceObjectAtIndex:rowIndex withObject:anObject];
			}
			[self validateImportButton];
		}
		// Refresh table
		[aTableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.01];
	}
	else if(aTableView == globalValuesTableView) {
		if ([[aTableColumn identifier] isEqualToString:@"global_value"])
			[fieldMappingGlobalValues replaceObjectAtIndex:(numberOfImportColumns + rowIndex) withObject:anObject];
		else if ([[aTableColumn identifier] isEqualToString:@"sql"])
			[fieldMappingGlobalValuesSQLMarked replaceObjectAtIndex:(numberOfImportColumns + rowIndex) withObject:anObject];
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

@end
