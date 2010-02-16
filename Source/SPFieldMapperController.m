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
//

#import "SPFieldMapperController.h"
#import "SPTableData.h"
#import "TablesList.h"
#import "SPArrayAdditions.h"
#import "SPConstants.h"

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
		// fieldMappingTableDefaultValues = [[NSMutableArray alloc] init];
		fieldMappingTableTypes         = [[NSMutableArray alloc] init];
		fieldMappingButtonOptions      = [[NSMutableArray alloc] init];
		fieldMappingOperatorOptions    = [[NSMutableArray alloc] init];
		fieldMappingOperatorArray      = [[NSMutableArray alloc] init];
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
	[fileSourcePath setURL:[NSURL URLWithString:sourcePath]];

	// Init table target popup menu
	[tableTargetPopup removeAllItems];
	if([[theDelegate valueForKeyPath:@"tablesListInstance"] allTableNames]) {
		[tableTargetPopup addItemsWithTitles:[[theDelegate valueForKeyPath:@"tablesListInstance"] allTableNames]];

		// Select either the currently selected table, or the first item in the list
		if ([[theDelegate valueForKeyPath:@"tableDocumentInstance"] table] != nil && ![[[theDelegate valueForKeyPath:@"tablesListInstance"] tableName] isEqualToString:@""]) {
			[tableTargetPopup selectItemWithTitle:[[theDelegate valueForKeyPath:@"tablesListInstance"] tableName]];
		} else {
			[tableTargetPopup selectItemAtIndex:0];
		}

	}
	
	[importFieldNamesHeaderSwitch setState:importFieldNamesHeader];
	
	[self changeTableTarget:self];
	[[self window] makeFirstResponder:fieldMapperTableView];
	if([fieldMappingTableColumnNames count])
		[fieldMapperTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];

}

- (void)dealloc
{
	if (mySQLConnection) [mySQLConnection release];
	if (sourcePath) [sourcePath release];
	if (fieldMappingTableColumnNames) [fieldMappingTableColumnNames release];
	// if (fieldMappingTableDefaultValues) [fieldMappingTableDefaultValues release];
	if (fieldMappingTableTypes) [fieldMappingTableTypes release];
	if (fieldMappingArray) [fieldMappingArray release];
	if (fieldMappingButtonOptions) [fieldMappingButtonOptions release];
	if (fieldMappingOperatorOptions) [fieldMappingOperatorOptions release];
	if (fieldMappingOperatorArray) [fieldMappingOperatorArray release];
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
	fieldMappingImportArray = theFieldMappingImportArray;
	importFieldNamesHeader  = hasHeader;
	fieldMappingImportArrayIsPreview = isPreview;
}

#pragma mark -
#pragma mark Getter methods

- (NSString*)selectedTableTarget
{
	return [tableTargetPopup titleOfSelectedItem];
}

- (NSArray*)fieldMapperOperator
{
	return [NSArray arrayWithArray:fieldMappingOperatorArray];
}

- (NSString*)selectedImportMethod
{
	return [importMethodPopup titleOfSelectedItem];
}

- (NSArray*)fieldMappingArray
{
	return fieldMappingArray;
}

- (NSArray*)fieldMappingTableColumnNames
{
	return fieldMappingTableColumnNames;
}

- (BOOL)importFieldNamesHeader
{
	return importFieldNamesHeader;
}

#pragma mark -
#pragma mark IBAction methods

- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:[self window] returnCode:[sender tag]];
}

- (IBAction)changeTableTarget:(id)sender
{

	NSInteger i;

	// Remove all the current columns
	[fieldMappingTableColumnNames removeAllObjects];
	// [fieldMappingTableDefaultValues removeAllObjects];
	[fieldMappingTableTypes removeAllObjects];

	// Retrieve the information for the newly selected table using a SPTableData instance
	SPTableData *selectedTableData = [[SPTableData alloc] init];
	[selectedTableData setConnection:mySQLConnection];
	NSDictionary *tableDetails = [selectedTableData informationForTable:[tableTargetPopup titleOfSelectedItem]];

	if (tableDetails) {
		for (NSDictionary *column in [tableDetails objectForKey:@"columns"]) {
			[fieldMappingTableColumnNames addObject:[NSString stringWithString:[column objectForKey:@"name"]]];
			// if([column objectForKey:@"default"])
			// 	[fieldMappingTableDefaultValues addObject:[NSString stringWithString:[column objectForKey:@"default"]]];
			// else
			// 	[fieldMappingTableDefaultValues addObject:@""];
			NSMutableString *type = [NSMutableString string];
			if([column objectForKey:@"type"])
				[type appendString:[column objectForKey:@"type"]];
			if([column objectForKey:@"length"])
				[type appendFormat:@"(%@)", [column objectForKey:@"length"]];
			if([column objectForKey:@"values"])
				[type appendFormat:@"(%@)", [[column objectForKey:@"values"] componentsJoinedByString:@"¦"]];
			if([column objectForKey:@"autoincrement"] && [[column objectForKey:@"autoincrement"] integerValue] == 1)
				[type appendFormat:@",%@",@"PRIMARY KEY"];
			else if ([column objectForKey:@"default"])
				[type appendFormat:@",%@",[column objectForKey:@"default"]];
			[fieldMappingTableTypes addObject:[NSString stringWithString:type]];
		}
	}

	[selectedTableData release];

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

	[alignByPopup selectItemWithTag:0];

	[fieldMapperTableView reloadData];

}

- (IBAction)changeImportMethod:(id)sender
{
	NSInteger i;
	// If operator is set to = for UPDATE method replace it by doNotImport
	if(![[importMethodPopup titleOfSelectedItem] isEqualToString:@"UPDATE"]) {
		for(i=0; i<[fieldMappingTableColumnNames count]; i++) {
			if([fieldMappingOperatorArray objectAtIndex:i] == isEqual)
				[fieldMappingOperatorArray replaceObjectAtIndex:i withObject:doNotImport];
		}
	}

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
		
	}
	[fieldMapperTableView reloadData];
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
	
	[recordCountLabel setStringValue:[NSString stringWithFormat:@"%ld of %@%lu records", (long)(fieldMappingCurrentRow+1), fieldMappingImportArrayIsPreview?@"first ":@"", (unsigned long)[fieldMappingImportArray count]]];
	
	// enable/disable buttons
	[rowDownButton setEnabled:(fieldMappingCurrentRow != 0)];
	[rowUpButton setEnabled:(fieldMappingCurrentRow != ([fieldMappingImportArray count]-1))];
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
	
	[fieldMappingButtonOptions setArray:[fieldMappingImportArray objectAtIndex:fieldMappingCurrentRow]];
	for (i = 0; i < [fieldMappingButtonOptions count]; i++) {
		if ([[fieldMappingButtonOptions objectAtIndex:i] isNSNull]) {
			[fieldMappingButtonOptions replaceObjectAtIndex:i withObject:[NSString stringWithFormat:@"%i. %@", i+1, [prefs objectForKey:SPNullValue]]];
		} else {
			[fieldMappingButtonOptions replaceObjectAtIndex:i withObject:[NSString stringWithFormat:@"%i. %@", i+1, NSArrayObjectAtIndex(fieldMappingButtonOptions, i)]];
		}
	}
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


#pragma mark -
#pragma mark Table view datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
{
	return [fieldMappingTableColumnNames count];
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	[aCell setFont:([prefs boolForKey:SPUseMonospacedFonts]) ? [NSFont fontWithName:SPDefaultMonospacedFontName size:[NSFont smallSystemFontSize]] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
}

- (void)tableView:(NSTableView*)tableView didClickTableColumn:(NSTableColumn *)aTableColumn
{

	// A click at the operator column's header toggles all operators
	if ([[aTableColumn identifier] isEqualToString:@"operator"] 
			&& [self numberOfRowsInTableView:tableView]
			&& [fieldMappingOperatorArray count]
			&& [fieldMappingTableColumnNames count]) {
		NSInteger i;
		NSNumber *globalValue = doImport;
		if([fieldMappingOperatorArray objectAtIndex:0] == doImport) {
			globalValue = doNotImport;
			// NSTextFieldCell *c = [[[NSTextFieldCell alloc] init] autorelease];
			// [c setStringValue:doNotImportString];
			// [aTableColumn setHeaderCell:c];
		} else {
			// NSTextFieldCell *c = [[[NSTextFieldCell alloc] init] autorelease];
			// [c setStringValue:doImportString];
			// [aTableColumn setHeaderCell:c];
		}
		[fieldMappingOperatorArray removeAllObjects];
		for(i=0; i < [fieldMappingTableColumnNames count]; i++)
			[fieldMappingOperatorArray addObject:globalValue];
		[fieldMapperTableView reloadData];
	} 

}

- (NSString *)tableView:(NSTableView *)aTableView toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex mouseLocation:(NSPoint)mouseLocation
{
	if([[aTableColumn identifier] isEqualToString:@"import_value"] && [importFieldNamesHeaderSwitch state] == NSOnState) {
		if ([fieldMappingOperatorArray objectAtIndex:rowIndex] == doNotImport) return @"";
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
			return NSLocalizedString(@"Do import", @"import operator");
		else if([aCell objectValue] == doNotImport)
			return NSLocalizedString(@"Do not import", @"do not import operator");
		else if([aCell objectValue] == isEqual)
			return NSLocalizedString(@"Do UPDATE where field contents match", @"do update operator");
		else
			return @"";
	}
	else if([[aTableColumn identifier] isEqualToString:@"target_field"])
		return [fieldMappingTableColumnNames objectAtIndex:rowIndex];


	return @"";
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
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
		[b setFont:[NSFont systemFontOfSize:9]];
		[b setDelegate:self];
		return b;
	}
	else if ([[aTableColumn identifier] isEqualToString:@"import_value"]) {
		if ([[aTableColumn dataCell] isKindOfClass:[NSPopUpButtonCell class]]) {
			[(NSPopUpButtonCell *)[aTableColumn dataCell] removeAllItems];
			if([fieldMappingOperatorArray objectAtIndex:rowIndex] != doNotImport)
				[(NSPopUpButtonCell *)[aTableColumn dataCell] addItemsWithTitles:fieldMappingButtonOptions];
			return [fieldMappingArray objectAtIndex:rowIndex];
			// } else {
			// 	NSString *defaultValue = [fieldMappingTableDefaultValues objectAtIndex:[[fieldMappingArray objectAtIndex:rowIndex] integerValue]];
			// 	[(NSPopUpButtonCell *)[aTableColumn dataCell] addItemWithTitle:defaultValue];
			// 	return defaultValue;
			// }
		}
	} 
	else if ([[aTableColumn identifier] isEqualToString:@"operator"]) {
		if ([[aTableColumn dataCell] isKindOfClass:[NSPopUpButtonCell class]]) {
			[(NSPopUpButtonCell *)[aTableColumn dataCell] removeAllItems];
			[(NSPopUpButtonCell *)[aTableColumn dataCell] addItemsWithTitles:fieldMappingOperatorOptions];
		}
		return [fieldMappingOperatorArray objectAtIndex:rowIndex];
	} 
	return nil;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if ([[aTableColumn identifier] isEqualToString:@"import_value"]) {
		[fieldMappingArray replaceObjectAtIndex:rowIndex withObject:anObject];
	}
	else if ([[aTableColumn identifier] isEqualToString:@"operator"]) {
		if([fieldMappingOperatorArray objectAtIndex:rowIndex] == anObject) return;
		if([fieldMappingOperatorArray objectAtIndex:rowIndex] == doNotImport) {
			[fieldMappingOperatorArray replaceObjectAtIndex:rowIndex withObject:anObject];
			[fieldMappingArray replaceObjectAtIndex:rowIndex withObject:lastDisabledCSVFieldcolumn];
		} else {
			if(anObject == doNotImport) lastDisabledCSVFieldcolumn = [fieldMappingArray objectAtIndex:rowIndex];
			[fieldMappingOperatorArray replaceObjectAtIndex:rowIndex withObject:anObject];
		}
		[aTableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.01];
	}
}

@end
