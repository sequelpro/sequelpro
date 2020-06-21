//
//  SPTableStructure.m
//  sequel-pro
//
//  Created by Lorenz Textor (lorenz@textor.ch) on May 1, 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//  Copyright (c) 2012 Sequel Pro Team. All rights reserved.
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

#import "SPTableStructure.h"
#import "SPDatabaseStructure.h"
#import "SPDatabaseDocument.h"
#import "SPTableInfo.h"
#import "SPTablesList.h"
#import "SPTableData.h"
#import "SPTableView.h"
#import "SPDatabaseData.h"
#import "SPSQLParser.h"
#import "SPAlertSheets.h"
#import "SPIndexesController.h"
#import "RegexKitLite.h"
#import "SPTableFieldValidation.h"
#import "SPThreadAdditions.h"
#import "SPServerSupport.h"
#import "SPExtendedTableInfo.h"
#import "SPFunctions.h"
#import "SPPillAttachmentCell.h"
#import "SPIdMenu.h"
#import "SPComboBoxCell.h"

#import <SPMySQL/SPMySQL.h>

static NSString *SPRemoveField = @"SPRemoveField";
static NSString *SPRemoveFieldAndForeignKey = @"SPRemoveFieldAndForeignKey";

@interface SPFieldTypeHelp ()

@property(copy,readwrite) NSString *typeName;
@property(copy,readwrite) NSString *typeDefinition;
@property(copy,readwrite) NSString *typeRange;
@property(copy,readwrite) NSString *typeDescription;

@end

@implementation SPFieldTypeHelp

@synthesize typeName;
@synthesize typeDefinition;
@synthesize typeRange;
@synthesize typeDescription;

- (void)dealloc
{
	[self setTypeName:nil];
	[self setTypeDefinition:nil];
	[self setTypeRange:nil];
	[self setTypeDescription:nil];
	[super dealloc];
}

@end

static inline SPFieldTypeHelp *MakeFieldTypeHelp(NSString *typeName,NSString *typeDefinition,NSString *typeRange,NSString *typeDescription) {
	SPFieldTypeHelp *obj = [[SPFieldTypeHelp alloc] init];
	
	[obj setTypeName:       typeName];
	[obj setTypeDefinition: typeDefinition];
	[obj setTypeRange:      typeRange];
	[obj setTypeDescription:typeDescription];
	
	return [obj autorelease];
}

struct _cmpMap {
	NSString *title; // the title of the "pill"
	NSString *tooltipPart; // the tooltip of the menuitem
	NSString *cmpWith; // the string to match against
};

/**
 * This function will compare the representedObject of every item in menu against
 * every map->cmpWith. If they match it will append a pill-like (similar to a TokenFieldCell's token)
 * element labelled map->title to the menu item's title. If map->tooltipPart is set,
 * it will also be added to the menu item's tooltip.
 *
 * This is used with the encoding/collation popup menus to add visual indicators for the
 * table-level and default encoding/collation.
 */
static void _BuildMenuWithPills(NSMenu *menu,struct _cmpMap *map,size_t mapEntries);

@interface SPTableStructure ()

- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo;
- (void)_removeFieldAndForeignKey:(NSNumber *)removeForeignKey;
- (NSString *)_buildPartialColumnDefinitionString:(NSDictionary *)theRow;

#pragma mark - SPTableStructureDelegate

- (void)_displayFieldTypeHelpIfPossible:(SPComboBoxCell *)cell;

@end

@implementation SPTableStructure

#ifdef SP_CODA
@synthesize indexesController;
@synthesize indexesTableView;
@synthesize addFieldButton;
@synthesize duplicateFieldButton;
@synthesize removeFieldButton;
@synthesize reloadFieldsButton;
#endif

#pragma mark -
#pragma mark Initialisation

- (id)init
{
	if ((self = [super init])) {
		
		tableFields = [[NSMutableArray alloc] init];
		oldRow      = [[NSMutableDictionary alloc] init];
		enumFields  = [[NSMutableDictionary alloc] init];
		
		defaultValues = nil;
		selectedTable = nil;
		typeSuggestions = nil;
		extraFieldSuggestions = nil;
		currentlyEditingRow = -1;
		isCurrentExtraAutoIncrement = NO;
		autoIncrementIndex = nil;

		fieldValidation = [[SPTableFieldValidation alloc] init];
		
		prefs = [NSUserDefaults standardUserDefaults];
	}

	return self;
}

- (void)awakeFromNib
{
	// Set the structure and index view's vertical gridlines if required
	[tableSourceView setGridStyleMask:[prefs boolForKey:SPDisplayTableViewVerticalGridlines] ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	[indexesTableView setGridStyleMask:[prefs boolForKey:SPDisplayTableViewVerticalGridlines] ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];

	// Set the double-click action in blank areas of the table to create new rows
	[tableSourceView setEmptyDoubleClickAction:@selector(addField:)];

	BOOL useMonospacedFont = [prefs boolForKey:SPUseMonospacedFonts];
	NSInteger monospacedFontSize = [prefs integerForKey:SPMonospacedFontSize] > 0 ? [prefs integerForKey:SPMonospacedFontSize] : [NSFont smallSystemFontSize];

	// Set the strutcture and index view's font
	[tableSourceView setFont:useMonospacedFont ? [NSFont fontWithName:SPDefaultMonospacedFontName size:monospacedFontSize] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
	[indexesTableView setFont:useMonospacedFont ? [NSFont fontWithName:SPDefaultMonospacedFontName size:monospacedFontSize] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];

	extraFieldSuggestions = [@[
			@"None",
			@"auto_increment",
			@"on update CURRENT_TIMESTAMP",
			@"SERIAL DEFAULT VALUE"
	] retain];

	// Note that changing the contents or ordering of this array will affect the implementation of 
	// SPTableFieldValidation. See it's implementation file for more details.
	typeSuggestions = [@[
		SPMySQLTinyIntType,
		SPMySQLSmallIntType,
		SPMySQLMediumIntType,
		SPMySQLIntType,
		SPMySQLBigIntType,
		SPMySQLFloatType,
		SPMySQLDoubleType,
		SPMySQLDoublePrecisionType,
		SPMySQLRealType,
		SPMySQLDecimalType,
		SPMySQLBitType,
		SPMySQLSerialType,
		SPMySQLBoolType,
		SPMySQLBoolean,
		SPMySQLDecType,
		SPMySQLFixedType,
		SPMySQLNumericType,
		@"--------",
		SPMySQLCharType,
		SPMySQLVarCharType,
		SPMySQLTinyTextType,
		SPMySQLTextType,
		SPMySQLMediumTextType,
		SPMySQLLongTextType,
		SPMySQLTinyBlobType,
		SPMySQLMediumBlobType,
		SPMySQLBlobType,
		SPMySQLLongBlobType,
		SPMySQLBinaryType,
		SPMySQLVarBinaryType,
		SPMySQLJsonType,
		SPMySQLEnumType,
		SPMySQLSetType,
		@"--------",
		SPMySQLDateType,
		SPMySQLDatetimeType,
		SPMySQLTimestampType,
		SPMySQLTimeType,
		SPMySQLYearType,
		@"--------",
		SPMySQLGeometryType,
		SPMySQLPointType,
		SPMySQLLineStringType,
		SPMySQLPolygonType,
		SPMySQLMultiPointType,
		SPMySQLMultiLineStringType,
		SPMySQLMultiPolygonType,
		SPMySQLGeometryCollectionType] retain];

	[fieldValidation setFieldTypes:typeSuggestions];
	
	// Add observers for document task activity
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(startDocumentTaskForTab:)
												 name:SPDocumentTaskStartNotification
											   object:tableDocumentInstance];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(endDocumentTaskForTab:)
												 name:SPDocumentTaskEndNotification
											   object:tableDocumentInstance];

	// Init the view column submenu according to saved hidden status;
	// menu items are identified by their tag number which represents the initial column index
	for (NSMenuItem *item in [viewColumnsMenu itemArray]) [item setState:NSOnState]; // Set all items to NSOnState

	for (NSTableColumn *col in [tableSourceView tableColumns]) 
	{
		if ([col isHidden]) {
			if ([[col identifier] isEqualToString:@"Key"])
				[[viewColumnsMenu itemWithTag:7] setState:NSOffState];
			else if ([[col identifier] isEqualToString:@"encoding"])
				[[viewColumnsMenu itemWithTag:10] setState:NSOffState];
			else if ([[col identifier] isEqualToString:@"collation"])
				[[viewColumnsMenu itemWithTag:11] setState:NSOffState];
			else if ([[col identifier] isEqualToString:@"comment"])
				[[viewColumnsMenu itemWithTag:12] setState:NSOffState];
		}
	}

	[tableSourceView reloadData];
}

#pragma mark -
#pragma mark Edit methods

/**
 * Adds an empty row to the tableSource-array and goes into edit mode
 */
- (IBAction)addField:(id)sender
{
	// Check whether table editing is permitted (necessary as some actions - eg table double-click - bypass validation)
	if ([tableDocumentInstance isWorking] || [tablesListInstance tableType] != SPTableTypeTable) return;

	// Check whether a save of the current row is required.
	if (![self saveRowOnDeselect]) return;

	NSInteger insertIndex = ([tableSourceView numberOfSelectedRows] == 0 ? [tableSourceView numberOfRows] : [tableSourceView selectedRow] + 1);

#ifndef SP_CODA /* prefs access */
	BOOL allowNull = [[[tableDataInstance statusValueForKey:@"Engine"] uppercaseString] isEqualToString:@"CSV"] ? NO : [prefs boolForKey:SPNewFieldsAllowNulls];
	
	[tableFields insertObject:[NSMutableDictionary
							   dictionaryWithObjects:[NSArray arrayWithObjects:@"", @"INT", @"", @"0", @"0", @"0", allowNull ? @"1" : @"0", @"", [prefs stringForKey:SPNullValue], @"None", @"", nil]
							   forKeys:@[@"name", @"type", @"length", @"unsigned", @"zerofill", @"binary", @"null", @"Key", @"default", @"Extra", @"comment"]]
					  atIndex:insertIndex];
#else
	[tableFields insertObject:[NSMutableDictionary
							   dictionaryWithObjects:[NSArray arrayWithObjects:@"", @"INT", @"", @"0", @"0", @"0", @"1", @"", @"NULL", @"None", @"", @0, @0, nil]
							   forKeys:[NSArray arrayWithObjects:@"name", @"type", @"length", @"unsigned", @"zerofill", @"binary", @"null", @"Key", @"default", @"Extra", @"comment", @"encoding", @"collation", nil]]
					  atIndex:insertIndex];
#endif

	[tableSourceView reloadData];
	[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:insertIndex] byExtendingSelection:NO];
	
	isEditingRow = YES;
	isEditingNewRow = YES;
	currentlyEditingRow = [tableSourceView selectedRow];
	
	[tableSourceView editColumn:0 row:insertIndex withEvent:nil select:YES];
}

/**
 * Show optimized field type for selected field
 */
- (IBAction)showOptimizedFieldType:(id)sender
{
	SPMySQLResult *theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SELECT %@ FROM %@ PROCEDURE ANALYSE(0,8192)", 
		[[[tableFields objectAtIndex:[tableSourceView selectedRow]] objectForKey:@"name"] backtickQuotedString],
		[selectedTable backtickQuotedString]]];

	// Check for errors
	if ([mySQLConnection queryErrored]) {
		NSString *message = NSLocalizedString(@"Error while fetching the optimized field type", @"error while fetching the optimized field type message");
		
		if ([mySQLConnection isConnected]) {

			[[NSAlert alertWithMessageText:message 
							 defaultButton:@"OK" 
						   alternateButton:nil 
							   otherButton:nil 
				 informativeTextWithFormat:NSLocalizedString(@"An error occurred while fetching the optimized field type.\n\nMySQL said:%@", @"an error occurred while fetching the optimized field type.\n\nMySQL said:%@"), [mySQLConnection lastErrorMessage]]
				  beginSheetModalForWindow:[tableDocumentInstance parentWindow] 
							 modalDelegate:self 
							didEndSelector:NULL 
							   contextInfo:NULL];
		}

		return;
	}

	[theResult setReturnDataAsStrings:YES];
	
	NSDictionary *analysisResult = [theResult getRowAsDictionary];

	NSString *type = [analysisResult objectForKey:@"Optimal_fieldtype"];
	
	if (!type || [type isNSNull] || ![type length]) {
		type = NSLocalizedString(@"No optimized field type found.", @"no optimized field type found. message");
	}

	[[NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Optimized type for field '%@'", @"Optimized type for field %@"), [[tableFields objectAtIndex:[tableSourceView selectedRow]] objectForKey:@"name"]] 
					 defaultButton:@"OK" 
				   alternateButton:nil 
					   otherButton:nil 
		 informativeTextWithFormat:@"%@", type]
		  beginSheetModalForWindow:[tableDocumentInstance parentWindow] 
					 modalDelegate:self 
					didEndSelector:NULL 
					   contextInfo:NULL];

}

/**
 * Control the visibility of the columns
 */
- (IBAction)toggleColumnView:(NSMenuItem *)sender
{
	NSString *columnIdentifierName = nil;

	switch([sender tag]) {
		case 7:
		columnIdentifierName = @"Key";
		break;
		case 10:
		columnIdentifierName = @"encoding";
		break;
		case 11:
		columnIdentifierName = @"collation";
		break;
		case 12:
		columnIdentifierName = @"comment";
		break;
		default:
		return;
	}

	for(NSTableColumn *col in [tableSourceView tableColumns]) {

		if([[col identifier] isEqualToString:columnIdentifierName]) {
			[col setHidden:([sender state] == NSOffState) ? NO : YES];
			[(NSMenuItem *)sender setState:![sender state]];
			break;
		}

	}

	[tableSourceView reloadData];

}

/**
 * Copies a field and goes in edit mode for the new field
 */
- (IBAction)duplicateField:(id)sender
{
	NSMutableDictionary *tempRow;
	NSUInteger rowToCopy;

	// Store the row to duplicate, as saveRowOnDeselect and subsequent reloads may trigger a deselection
	if ([tableSourceView numberOfSelectedRows]) {
		rowToCopy = [tableSourceView selectedRow];
	} else {
		rowToCopy = [tableSourceView numberOfRows]-1;
	}

	// Check whether a save of the current row is required.
	if ( ![self saveRowOnDeselect] ) return;

	//add copy of selected row and go in edit mode
	tempRow = [NSMutableDictionary dictionaryWithDictionary:[tableFields objectAtIndex:rowToCopy]];
	[tempRow setObject:[[tempRow objectForKey:@"name"] stringByAppendingString:@"Copy"] forKey:@"name"];
	[tempRow setObject:@"" forKey:@"Key"];
	[tempRow setObject:@"None" forKey:@"Extra"];
	[tableFields addObject:tempRow];
	[tableSourceView reloadData];
	[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:[tableSourceView numberOfRows]-1] byExtendingSelection:NO];
	isEditingRow = YES;
	isEditingNewRow = YES;
	currentlyEditingRow = [tableSourceView selectedRow];
	[tableSourceView editColumn:0 row:[tableSourceView numberOfRows]-1 withEvent:nil select:YES];
}

/**
 * Ask the user to confirm that they really want to remove the selected field.
 */
- (IBAction)removeField:(id)sender
{
	if (![tableSourceView numberOfSelectedRows]) return;

	// Check whether a save of the current row is required.
	if (![self saveRowOnDeselect]) return;

	NSInteger anIndex = [tableSourceView selectedRow];

	if ((anIndex == -1) || (anIndex > (NSInteger)([tableFields count] - 1))) return;

	// Check if the user tries to delete the last defined field in table
	// Note that because of better menu item validation, this check will now never evaluate to true.
	if ([tableSourceView numberOfRows] < 2) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error while deleting field", @"Error while deleting field")
										 defaultButton:NSLocalizedString(@"OK", @"OK button")
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:NSLocalizedString(@"You cannot delete the last field in a table. Delete the table instead.", @"You cannot delete the last field in a table. Delete the table instead.")];

		[alert setAlertStyle:NSCriticalAlertStyle];

		[alert beginSheetModalForWindow:[tableDocumentInstance parentWindow] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"cannotremovefield"];

	}

	NSString *field = [[tableFields objectAtIndex:anIndex] objectForKey:@"name"];

	BOOL hasForeignKey = NO;
	NSString *referencedTable = @"";

	// Check to see whether the user is attempting to remove a field that has foreign key constraints and thus
	// would result in an error if not dropped before removing the field.
	for (NSDictionary *constraint in [tableDataInstance getConstraints])
	{
		for (NSString *column in [constraint objectForKey:@"columns"])
		{
			if ([column isEqualToString:field]) {
				hasForeignKey = YES;
				referencedTable = [constraint objectForKey:@"ref_table"];
				break;
			}
		}
	}

	NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Delete field '%@'?", @"delete field message"), field]
									 defaultButton:NSLocalizedString(@"Delete", @"delete button")
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
									   otherButton:nil
						 informativeTextWithFormat:hasForeignKey ? NSLocalizedString(@"This field is part of a foreign key relationship with the table '%@'. This relationship must be removed before the field can be deleted.\n\nAre you sure you want to continue to delete the relationship and the field? This action cannot be undone.", @"delete field and foreign key informative message"), referencedTable : NSLocalizedString(@"Are you sure you want to delete the field '%@'? This action cannot be undone.", @"delete field informative message"), field];

	[alert setAlertStyle:NSCriticalAlertStyle];

	NSArray *buttons = [alert buttons];

#ifndef SP_CODA
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"d"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
#else
	[[buttons objectAtIndex:0] setKeyEquivalent:@"\r"];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\e"];
#endif

	[alert beginSheetModalForWindow:[tableDocumentInstance parentWindow] 
					  modalDelegate:self 
					 didEndSelector:@selector(removeFieldSheetDidEnd:returnCode:contextInfo:) 
						contextInfo:hasForeignKey ? SPRemoveFieldAndForeignKey : SPRemoveField];
}

/**
 * Resets the auto increment value of a table.
 */
- (IBAction)resetAutoIncrement:(id)sender
{
	if ([sender tag] == 1) {

		[resetAutoIncrementLine setHidden:YES];

		if ([tableDocumentInstance currentlySelectedView] == SPTableViewStructure){
			[resetAutoIncrementLine setHidden:NO];
		}

		// Begin the sheet
		[NSApp beginSheet:resetAutoIncrementSheet
		   modalForWindow:[tableDocumentInstance parentWindow]
			modalDelegate:self
		   didEndSelector:@selector(resetAutoincrementSheetDidEnd:returnCode:contextInfo:)
			  contextInfo:nil];

		[resetAutoIncrementValue setStringValue:@"1"];
	}
	else if ([sender tag] == 2) {
		[self setAutoIncrementTo:@1];
	}
}

/**
 * Process the autoincrement sheet closing, resetting if the user confirmed the action.
 */
- (void)resetAutoincrementSheetDidEnd:(NSWindow *)theSheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	// Order out current sheet to suppress overlapping of sheets
	[theSheet orderOut:nil];

	if (returnCode == NSAlertDefaultReturn) {
		[self takeAutoIncrementFrom:resetAutoIncrementValue];
	}
}

- (void)takeAutoIncrementFrom:(NSTextField *)field
{
	id obj = [field objectValue];

	//nil is handled by -setAutoIncrementTo:
	if (obj && ![obj isKindOfClass:[NSNumber class]]) {
		[NSException raise:NSInternalInconsistencyException format:@"[$field objectValue] should return NSNumber *, but was %@",[obj class]];
	}

	[self setAutoIncrementTo:(NSNumber *)obj];
}

/**
 * Process the remove field sheet closing, performing the delete if the user
 * confirmed the action.
 */
- (void)removeFieldSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	// Order out current sheet to suppress overlapping of sheets
	[[alert window] orderOut:nil];

	if (returnCode == NSAlertDefaultReturn) {
		[tableDocumentInstance startTaskWithDescription:NSLocalizedString(@"Removing field...", @"removing field task status message")];

		NSNumber *removeKey = [NSNumber numberWithBool:[(NSString *)contextInfo isEqualToString:SPRemoveFieldAndForeignKey]];

		if ([NSThread isMainThread]) {
			[NSThread detachNewThreadWithName:SPCtxt(@"SPTableStructure field and key removal task", tableDocumentInstance)
									   target:self 
									 selector:@selector(_removeFieldAndForeignKey:) 
									   object:removeKey];

			[tableDocumentInstance enableTaskCancellationWithTitle:NSLocalizedString(@"Cancel", @"cancel button") 
													callbackObject:self 
												  callbackFunction:NULL];
		}
		else {
			[self _removeFieldAndForeignKey:removeKey];
		}
	}
}

/**
 * Cancel active row editing, replacing the previous row if there was one
 * and resetting state.
 * Returns whether row editing was cancelled.
 */
- (BOOL)cancelRowEditing
{
	if (!isEditingRow) return NO;
	
	if (isEditingNewRow) {
		isEditingNewRow = NO;
		[tableFields removeObjectAtIndex:currentlyEditingRow];
	} 
	else {
		[tableFields replaceObjectAtIndex:currentlyEditingRow withObject:[NSMutableDictionary dictionaryWithDictionary:oldRow]];
	}
	
	isEditingRow = NO;
	isCurrentExtraAutoIncrement = [tableDataInstance tableHasAutoIncrementField];
	autoIncrementIndex = nil;
	
	[tableSourceView reloadData];
	
	currentlyEditingRow = -1;
	
	[[tableDocumentInstance parentWindow] makeFirstResponder:tableSourceView];
	
	return YES;
}

#pragma mark -
#pragma mark Other IB action methods

- (IBAction)unhideIndexesView:(id)sender
{
#ifndef SP_CODA
	[tablesIndexesSplitView setPosition:[tablesIndexesSplitView frame].size.height-130 ofDividerAtIndex:0];
#endif
}

#pragma mark -
#pragma mark Index sheet methods

/**
 * Closes the current sheet and stops the modal session.
 */
- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

#pragma mark -
#pragma mark Additional methods

/**
 * Try table's auto_increment to a specific value
 *
 * @param valueAsString The new auto_increment integer as NSString
 */
- (void)setAutoIncrementTo:(NSNumber *)value
{
	NSString *selTable = [tablesListInstance tableName];

	if (selTable == nil || ![selTable length]) return;

	if (value == nil) {
		// reload data and bail
		[tableDataInstance resetAllData];
#ifndef SP_CODA
		[extendedTableInfoInstance loadTable:selTable];
		[tableInfoInstance tableChanged:nil];
#endif
		return;
	}

	// only int and float types can be AUTO_INCREMENT and right now BIGINT = 64 Bit (<= long long) is the largest type mysql supports
	[mySQLConnection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ AUTO_INCREMENT = %llu", [selTable backtickQuotedString], [value unsignedLongLongValue]]];

	if ([mySQLConnection queryErrored]) {
		SPOnewayAlertSheet(
			NSLocalizedString(@"Error", @"error"),
			[NSApp mainWindow],
			[NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to reset AUTO_INCREMENT of table '%@'.\n\nMySQL said: %@", @"error resetting auto_increment informative message"),selTable, [mySQLConnection lastErrorMessage]]
		);
	}

	// reload data
	[tableDataInstance resetStatusData];
	if([tableDocumentInstance currentlySelectedView] == SPTableViewStatus) {
		[tableDataInstance resetAllData];
#ifndef SP_CODA
		[extendedTableInfoInstance loadTable:selTable];
#endif
	}

#ifndef SP_CODA
	[tableInfoInstance tableChanged:nil];
#endif
}

/**
 * Converts the supplied result to an array containing a (mutable) dictionary for each row
 */
- (NSArray *)convertIndexResultToArray:(SPMySQLResult *)theResult
{
	NSUInteger numOfRows = (NSUInteger)[theResult numberOfRows];
	NSMutableArray *tempResult = [NSMutableArray arrayWithCapacity:numOfRows];
	NSMutableDictionary *tempRow;
	NSArray *keys;
	NSInteger i;
	id prefsNullValue = [prefs objectForKey:SPNullValue];

	// Ensure table information is returned as strings to avoid problems with some server versions
	[theResult setReturnDataAsStrings:YES];

	for ( i = 0 ; i < (NSInteger)numOfRows ; i++ ) {
		tempRow = [NSMutableDictionary dictionaryWithDictionary:[theResult getRowAsDictionary]];

		// Replace NSNull instances with the NULL string from preferences
		keys = [tempRow allKeys];
		for (id theKey in keys) {
			if ([[tempRow objectForKey:theKey] isNSNull])
				[tempRow setObject:prefsNullValue forKey:theKey];
		}

		// Update some fields to be more human-readable or GUI compatible
		if ([[tempRow objectForKey:@"Extra"] isEqualToString:@""]) {
			[tempRow setObject:@"None" forKey:@"Extra"];
		}
		if ([[tempRow objectForKey:@"Null"] isEqualToString:@"YES"]) {
			[tempRow setObject:@"1" forKey:@"Null"];
		} else {
			[tempRow setObject:@"0" forKey:@"Null"];
		}
		[tempResult addObject:tempRow];
	}

	return tempResult;
}

/**
 * A method to be called whenever the selection changes or the table would be reloaded
 * or altered; checks whether the current row is being edited, and if so attempts to save
 * it.  Returns YES if no save was necessary or the save was successful, and NO if a save
 * was necessary but failed - also reselecting the row for re-editing.
 */
- (BOOL)saveRowOnDeselect
{

	// Save any edits which have been made but not saved to the table yet;
	// but not for any NSSearchFields which could cause a crash for undo, redo.
	id currentFirstResponder = [[tableDocumentInstance parentWindow] firstResponder];
	if (currentFirstResponder && [currentFirstResponder isKindOfClass:[NSView class]] && [(NSView *)currentFirstResponder isDescendantOf:tableSourceView]) {
		[[tableDocumentInstance parentWindow] endEditingFor:nil];
	}

	// If no rows are currently being edited, or a save is already in progress, return success at once.
	if (!isEditingRow || isSavingRow) return YES;
	isSavingRow = YES;

	// Attempt to save the row, and return YES if the save succeeded.
	if ([self addRowToDB]) {
		isSavingRow = NO;
		return YES;
	}

	// Saving failed - return failure.
	isSavingRow = NO;
	return NO;
}

/**
 * Tries to write row to mysql-db
 * returns YES if row written to db, otherwies NO
 * returns YES if no row is beeing edited and nothing has to be written to db
 */
- (BOOL)addRowToDB
{
	if ((!isEditingRow) || (currentlyEditingRow == -1)) return YES;

	if (alertSheetOpened) return NO;

	// Save any edits which have been started but not saved to the underlying table/data structures
	// yet - but not if currently undoing/redoing, as this can cause a processing loop
	if (![[[[tableSourceView window] firstResponder] undoManager] isUndoing] && ![[[[tableSourceView window] firstResponder] undoManager] isRedoing]) {
		[[tableSourceView window] endEditingFor:nil];
	}

	NSDictionary *theRow = [tableFields objectAtIndex:currentlyEditingRow];

	if ([autoIncrementIndex isEqualToString:@"PRIMARY KEY"]) {
		// If the field isn't set to be unsigned and we're making it the primary key then make it unsigned
		if (![[theRow objectForKey:@"unsigned"] boolValue]) {
			NSMutableDictionary *rowCpy = [theRow mutableCopy];
			[rowCpy setObject:@YES forKey:@"unsigned"];
			theRow = [rowCpy autorelease];
		}
	}

	NSMutableString *queryString = [NSMutableString stringWithFormat:@"ALTER TABLE %@",[selectedTable backtickQuotedString]];
	[queryString appendString:@" "];
	if (isEditingNewRow) {
		[queryString appendString:@"ADD"];
	}
	else {
		[queryString appendFormat:@"CHANGE %@",[[oldRow objectForKey:@"name"] backtickQuotedString]];
	}
	[queryString appendString:@" "];
	[queryString appendString:[self _buildPartialColumnDefinitionString:theRow]];

	// Process index if given for fields set to AUTO_INCREMENT
	if (autoIncrementIndex) {
		// User wants to add PRIMARY KEY
		if ([autoIncrementIndex isEqualToString:@"PRIMARY KEY"]) {
			[queryString appendString:@"\n PRIMARY KEY"];

			// Add AFTER ... only if the user added a new field
			if (isEditingNewRow) {
				[queryString appendFormat:@"\n AFTER %@", [[[tableFields objectAtIndex:(currentlyEditingRow -1)] objectForKey:@"name"] backtickQuotedString]];
			}
		}
		else {
			// Add AFTER ... only if the user added a new field
			if (isEditingNewRow) {
				[queryString appendFormat:@"\n AFTER %@", [[[tableFields objectAtIndex:(currentlyEditingRow -1)] objectForKey:@"name"] backtickQuotedString]];
			}

			[queryString appendFormat:@"\n, ADD %@ (%@)", autoIncrementIndex, [[theRow objectForKey:@"name"] backtickQuotedString]];
		}
	}
	// Add AFTER ... only if the user added a new field
	else if (isEditingNewRow) {
		[queryString appendFormat:@"\n AFTER %@", [[[tableFields objectAtIndex:(currentlyEditingRow -1)] objectForKey:@"name"] backtickQuotedString]];
	}

	isCurrentExtraAutoIncrement = NO;
	autoIncrementIndex = nil;

	// Execute query
	[mySQLConnection queryString:queryString];

	if (![mySQLConnection queryErrored]) {
		isEditingRow = NO;
		isEditingNewRow = NO;
		currentlyEditingRow = -1;

		[tableDataInstance resetAllData];
		[tableDocumentInstance setStatusRequiresReload:YES];
		[self loadTable:selectedTable];

		// Mark the content table for refresh
		[tableDocumentInstance setContentRequiresReload:YES];

		// Query the structure of all databases in the background
		[[tableDocumentInstance databaseStructureRetrieval] queryDbStructureInBackgroundWithUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:@YES, @"forceUpdate", selectedTable, @"affectedItem", [NSNumber numberWithInteger:[tablesListInstance tableType]], @"affectedItemType", nil]];

		return YES;
	}
	else {
		alertSheetOpened = YES;
		if([mySQLConnection lastErrorID] == 1146) { // If the current table doesn't exist anymore
			SPOnewayAlertSheet(
				NSLocalizedString(@"Error", @"error"),
				[tableDocumentInstance parentWindow],
				[NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to alter table '%@'.\n\nMySQL said: %@", @"error while trying to alter table message"),selectedTable, [mySQLConnection lastErrorMessage]]
			);

			isEditingRow = NO;
			isEditingNewRow = NO;
			currentlyEditingRow = -1;
			[tableFields removeAllObjects];
			[tableSourceView reloadData];
			[indexesTableView reloadData];
			[addFieldButton setEnabled:NO];
			[duplicateFieldButton setEnabled:NO];
			[removeFieldButton setEnabled:NO];
#ifndef SP_CODA
			[addIndexButton setEnabled:NO];
			[removeIndexButton setEnabled:NO];
			[editTableButton setEnabled:NO];
#endif
			[tablesListInstance updateTables:self];
			return NO;
		}
		// Problem: alert sheet doesn't respond to first click
		if (isEditingNewRow) {
			SPBeginAlertSheet(NSLocalizedString(@"Error adding field", @"error adding field message"),
							  NSLocalizedString(@"Edit row", @"Edit row button"),
							  NSLocalizedString(@"Discard changes", @"discard changes button"), nil, [tableDocumentInstance parentWindow], self, @selector(addRowErrorSheetDidEnd:returnCode:contextInfo:), NULL,
							  [NSString stringWithFormat:NSLocalizedString(@"An error occurred when trying to add the field '%@' via\n\n%@\n\nMySQL said: %@", @"error adding field informative message"),
							  [theRow objectForKey:@"name"], queryString, [mySQLConnection lastErrorMessage]]);
		}
		else {
			SPBeginAlertSheet(NSLocalizedString(@"Error changing field", @"error changing field message"),
							  NSLocalizedString(@"Edit row", @"Edit row button"),
							  NSLocalizedString(@"Discard changes", @"discard changes button"), nil, [tableDocumentInstance parentWindow], self, @selector(addRowErrorSheetDidEnd:returnCode:contextInfo:), NULL,
							  [NSString stringWithFormat:NSLocalizedString(@"An error occurred when trying to change the field '%@' via\n\n%@\n\nMySQL said: %@", @"error changing field informative message"),
							  [theRow objectForKey:@"name"], queryString, [mySQLConnection lastErrorMessage]]);
		}

		return NO;
	}
}

/**
 * Takes the column definition from a dictionary and returns the it to be used
 * with an ALTER statement, e.g.:
 *  `col1` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT
 */
- (NSString *)_buildPartialColumnDefinitionString:(NSDictionary *)theRow
{
	NSMutableString *queryString;
	BOOL fieldDefIncludesLen = NO;
	
	NSString *theRowType = @"";
	NSString *theRowExtra = @"";
	
	BOOL specialFieldTypes = NO;

	if ([theRow objectForKey:@"type"])
		theRowType = [[[theRow objectForKey:@"type"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];

	if ([theRow objectForKey:@"Extra"])
		theRowExtra = [[[theRow objectForKey:@"Extra"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];

	queryString = [NSMutableString stringWithString:[[theRow objectForKey:@"name"] backtickQuotedString]];

	[queryString appendString:@" "];
	[queryString appendString:theRowType];

	// Check for pre-defined field type SERIAL
	if([theRowType isEqualToString:@"SERIAL"]) {
		specialFieldTypes = YES;
	}

	// Check for pre-defined field type BOOL(EAN)
	else if([theRowType rangeOfRegex:@"(?i)bool(ean)?"].length) {
		specialFieldTypes = YES;

		if ([[theRow objectForKey:@"null"] integerValue] == 0) {
			[queryString appendString:@"\n NOT NULL"];
		} else {
			[queryString appendString:@"\n NULL"];
		}
		// If a NULL value has been specified, and NULL is allowed, specify DEFAULT NULL
		if ([[theRow objectForKey:@"default"] isEqualToString:[prefs objectForKey:SPNullValue]]) 
		{
			if ([[theRow objectForKey:@"null"] integerValue] == 1) {
				[queryString appendString:@"\n DEFAULT NULL "];
			}
		}
		else if (![(NSString *)[theRow objectForKey:@"default"] length]) {
			;
		}
		// Otherwise, use the provided default
		else {
			[queryString appendFormat:@"\n DEFAULT %@ ", [mySQLConnection escapeAndQuoteString:[theRow objectForKey:@"default"]]];
		}
	}

	// Check for Length specification
	else if ([theRow objectForKey:@"length"] && [[[theRow objectForKey:@"length"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length]) {
		fieldDefIncludesLen = YES;
		[queryString appendFormat:@"(%@)", [theRow objectForKey:@"length"]];
	}

	if(!specialFieldTypes) {


		if ([theRowType isEqualToString:@"JSON"]) {
			// we "see" JSON as a string, but it is not internally to MySQL and so doesn't allow CHARACTER SET/BINARY/COLLATE either.
		}
		else if ([fieldValidation isFieldTypeString:theRowType]) {
			BOOL charsetSupport = [[tableDocumentInstance serverSupport] supportsPost41CharacterSetHandling];

			// Add CHARSET
			NSString *fieldEncoding = [theRow objectForKey:@"encodingName"];
			if(charsetSupport && [fieldEncoding length]) {
				[queryString appendFormat:@"\n CHARACTER SET %@", fieldEncoding];
			}

			if ([[theRow objectForKey:@"binary"] integerValue] == 1) {
				[queryString appendString:@"\n BINARY"];
			}
			else {
				// ADD COLLATE
				// Note: a collate without charset is valid in MySQL. The charset can be determined from a collation.
				NSString *fieldCollation = [theRow objectForKey:@"collationName"];
				if(charsetSupport && [fieldCollation length]) {
					[queryString appendFormat:@"\n COLLATE %@", fieldCollation];
				}
			}

		}
		else if ([fieldValidation isFieldTypeNumeric:theRowType] && (![theRowType isEqualToString:@"BIT"])) {

			if ([[theRow objectForKey:@"unsigned"] integerValue] == 1) {
				[queryString appendString:@"\n UNSIGNED"];
			}

			if ( [[theRow objectForKey:@"zerofill"] integerValue] == 1) {
				[queryString appendString:@"\n ZEROFILL"];
			}
		}

		if ([[theRow objectForKey:@"null"] integerValue] == 0 || [theRowExtra isEqualToString:@"SERIAL DEFAULT VALUE"]) {
			[queryString appendString:@"\n NOT NULL"];
		} 
		else {
			[queryString appendString:@"\n NULL"];
		}

		// Don't provide any defaults for auto-increment fields
		if (![theRowExtra isEqualToString:@"AUTO_INCREMENT"]) {
			NSArray *matches;
			NSString *defaultValue = [theRow objectForKey:@"default"];
			// If a NULL value has been specified, and NULL is allowed, specify DEFAULT NULL
			if ([defaultValue isEqualToString:[prefs objectForKey:SPNullValue]])
			{
				if ([[theRow objectForKey:@"null"] integerValue] == 1) {
					[queryString appendString:@"\n DEFAULT NULL"];
				}
			}
			// Otherwise, if CURRENT_TIMESTAMP was specified for timestamps/datetimes, use that
			else if ([theRowType isInArray:@[@"TIMESTAMP",@"DATETIME"]] &&
					[(matches = [[defaultValue uppercaseString] captureComponentsMatchedByRegex:SPCurrentTimestampPattern]) count])
			{
				[queryString appendString:@"\n DEFAULT CURRENT_TIMESTAMP"];
				NSString *userLen = [matches objectAtIndex:1];
				// mysql 5.6.4+ allows DATETIME(n) for fractional seconds, which in turn requires CURRENT_TIMESTAMP(n) with the same n!
				// Also, if the user explicitly added one we should never ignore that.
				if([userLen length] || fieldDefIncludesLen) {
					[queryString appendFormat:@"(%@)",([userLen length]? userLen : [theRow objectForKey:@"length"])];
				}
			}
			// If the field is of type BIT, permit the use of single qoutes and also don't quote the default value.
			// For example, use DEFAULT b'1' as opposed to DEFAULT 'b\'1\'' which results in an error.
			else if ([defaultValue length] && [theRowType isEqualToString:@"BIT"]) {
				[queryString appendFormat:@"\n DEFAULT %@", defaultValue];
			}
			// Suppress appending DEFAULT clause for any numerics, date, time fields if default is empty to avoid error messages;
			// also don't specify a default for TEXT/BLOB, JSON or geometry fields to avoid strict mode errors
			else if (![defaultValue length] && ([fieldValidation isFieldTypeNumeric:theRowType] || [fieldValidation isFieldTypeDate:theRowType] || [theRowType hasSuffix:@"TEXT"] || [theRowType hasSuffix:@"BLOB"] || [theRowType isEqualToString:@"JSON"] || [fieldValidation isFieldTypeGeometry:theRowType])) {
				;
			}
			//for ENUM field type
			else if (([defaultValue length]==0) && [theRowType isEqualToString:@"ENUM"]) {
				[queryString appendFormat:@" "];
			}
			// Otherwise, use the provided default
			else {
				[queryString appendFormat:@"\n DEFAULT %@", [mySQLConnection escapeAndQuoteString:defaultValue]];
			}
		}

		if ([theRowExtra length] && ![theRowExtra isEqualToString:@"NONE"]) {
			[queryString appendFormat:@"\n %@", theRowExtra];
			//fix our own default item if needed
			if([theRowExtra isEqualToString:@"ON UPDATE CURRENT_TIMESTAMP"] && fieldDefIncludesLen) {
				[queryString appendFormat:@"(%@)",[theRow objectForKey:@"length"]];
			}
		}
	}

	// Any column comments
	if ([(NSString *)[theRow objectForKey:@"comment"] length]) {
		[queryString appendFormat:@"\n COMMENT %@", [mySQLConnection escapeAndQuoteString:[theRow objectForKey:@"comment"]]];
	}

	// Unparsed details - column formats, storage, reference definitions
	if ([(NSString *)[theRow objectForKey:@"unparsed"] length]) {
		[queryString appendFormat:@"\n %@", [theRow objectForKey:@"unparsed"]];
	}

	return queryString;
}

/**
 * A method to show an error sheet after a short delay, so that it can
 * be called from within an endSheet selector. This should be called on
 * the main thread.
 */
- (void)showErrorSheetWith:(NSDictionary *)errorDictionary
{
	// If this method has been called directly, invoke a delay.  Invoking the delay
	// on the main thread ensures the timer fires on the main thread.
	if (![errorDictionary objectForKey:@"delayed"]) {
		NSMutableDictionary *delayedErrorDictionary = [NSMutableDictionary dictionaryWithDictionary:errorDictionary];
		[delayedErrorDictionary setObject:@YES forKey:@"delayed"];
		[self performSelector:@selector(showErrorSheetWith:) withObject:delayedErrorDictionary afterDelay:0.3];
		return;
	}

	// Display the error sheet
	SPOnewayAlertSheet([errorDictionary objectForKey:@"title"], [tableDocumentInstance parentWindow], [errorDictionary objectForKey:@"message"]);
}

/**
 * Menu validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// Remove field
	if ([menuItem action] == @selector(removeField:)) {
		return (([tableSourceView numberOfSelectedRows] == 1) && ([tableSourceView numberOfRows] > 1));
	}

	// Duplicate field
	if ([menuItem action] == @selector(duplicateField:)) {
		return ([tableSourceView numberOfSelectedRows] == 1);
	}
	
	//show optimized field type
	if([menuItem action] == @selector(showOptimizedFieldType:)) {
		return ([tableSourceView numberOfSelectedRows] == 1);
	}

	// Reset AUTO_INCREMENT
	if ([menuItem action] == @selector(resetAutoIncrement:)) {
		return [indexesController validateMenuItem:menuItem];
	}

	return YES;
}

#pragma mark -
#pragma mark Alert sheet methods

/**
 * Called whenever a sheet is dismissed.
 */
- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{
#ifndef SP_CODA

	// Order out current sheet to suppress overlapping of sheets
	if ([sheet respondsToSelector:@selector(orderOut:)])
		[sheet orderOut:nil];
	else if ([sheet respondsToSelector:@selector(window)])
		[[sheet window] orderOut:nil];

	alertSheetOpened = NO;

	if(contextInfo && [contextInfo isEqualToString:@"autoincrementindex"]) {
		if (returnCode) {
			switch ([[chooseKeyButton selectedItem] tag]) {
				case SPPrimaryKeyMenuTag:
					autoIncrementIndex = @"PRIMARY KEY";
					break;
				case SPIndexMenuTag:
					autoIncrementIndex = @"INDEX";
					break;
				case SPUniqueMenuTag:
					autoIncrementIndex = @"UNIQUE";
					break;
			}
		} else {
			autoIncrementIndex = nil;
			if([tableSourceView selectedRow] > -1 && [extraFieldSuggestions count])
				[[tableFields objectAtIndex:[tableSourceView selectedRow]] setObject:[extraFieldSuggestions objectAtIndex:0] forKey:@"Extra"];
			[tableSourceView reloadData];
			isCurrentExtraAutoIncrement = NO;
		}
	}
#endif
}

/**
 * Perform the action requested in the Add Row error sheet.
 */
- (void)addRowErrorSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	// Order out current sheet to suppress overlapping of sheets
	[[alert window] orderOut:nil];
	
	alertSheetOpened = NO;
	
	// Remain in edit mode - reselect the row and resume editing
	if (returnCode == NSAlertDefaultReturn) {
		
		// Problem: reentering edit mode for first cell doesn't function
		[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:currentlyEditingRow] byExtendingSelection:NO];
		[tableSourceView performSelector:@selector(keyDown:) withObject:[NSEvent keyEventWithType:NSKeyDown location:NSMakePoint(0,0) modifierFlags:0 timestamp:0 windowNumber:[[tableDocumentInstance parentWindow] windowNumber] context:[NSGraphicsContext currentContext] characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:0x24] afterDelay:0.0];
	}
	
	// Discard changes and cancel editing
	else {
		[self cancelRowEditing];
	}

	[tableSourceView reloadData];
}

#pragma mark -
#pragma mark KVO methods

/**
 * This method is called as part of Key Value Observing which is used to watch for preference changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
#ifndef SP_CODA /* observe prefs change */
	// Display table veiew vertical gridlines preference changed
	if ([keyPath isEqualToString:SPDisplayTableViewVerticalGridlines]) {
        [tableSourceView setGridStyleMask:([[change objectForKey:NSKeyValueChangeNewKey] boolValue]) ? NSTableViewSolidVerticalGridLineMask : NSTableViewGridNone];
	}
	// Use monospaced fonts preference changed
	else if ([keyPath isEqualToString:SPUseMonospacedFonts]) {

		BOOL useMonospacedFont = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
		CGFloat monospacedFontSize = [prefs floatForKey:SPMonospacedFontSize] > 0 ? [prefs floatForKey:SPMonospacedFontSize] : [NSFont smallSystemFontSize];

		[tableSourceView setFont:useMonospacedFont ? [NSFont fontWithName:SPDefaultMonospacedFontName size:monospacedFontSize] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		[indexesTableView setFont:useMonospacedFont ? [NSFont fontWithName:SPDefaultMonospacedFontName size:monospacedFontSize] : [NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		
		[tableSourceView reloadData];
		[indexesTableView reloadData];
	}
#endif
}

#pragma mark -
#pragma mark Accessors

/**
 * Sets the connection (received from SPDatabaseDocument) and makes things that have to be done only once
 */
- (void)setConnection:(SPMySQLConnection *)theConnection
{
	mySQLConnection = theConnection;
	
	// Set the indexes controller connection
	[indexesController setConnection:mySQLConnection];
	
	// Set up tableView
	[tableSourceView registerForDraggedTypes:@[SPDefaultPasteboardDragType]];
}

/**
 * Get the default value for a specified field
 */
- (NSString *)defaultValueForField:(NSString *)field
{
	if ( ![defaultValues objectForKey:field] ) {
		return [prefs objectForKey:SPNullValue];
	} else if ( [[defaultValues objectForKey:field] isNSNull] ) {
		return [prefs objectForKey:SPNullValue];
	} else {
		return [defaultValues objectForKey:field];
	}
}

/**
 * Returns an array containing the field names of the selected table
 */
- (NSArray *)fieldNames
{
	NSMutableArray *tempArray = [NSMutableArray array];
	NSEnumerator *enumerator;
	id field;

	//load table if not already done
	if ( ![tableDocumentInstance structureLoaded] ) {
		[self loadTable:[tableDocumentInstance table]];
	}

	//get field names
	enumerator = [tableFields objectEnumerator];
	while ( (field = [enumerator nextObject]) ) {
		[tempArray addObject:[field objectForKey:@"name"]];
	}

	return [NSArray arrayWithArray:tempArray];
}

/**
 * Returns a dictionary containing enum/set field names as key and possible values as array
 */
- (NSDictionary *)enumFields
{
	return [NSDictionary dictionaryWithDictionary:enumFields];
}

/**
 * Returns a dictionary describing the source of the table to be used for printing purposes. The object accessible
 * via the key 'structure' is an array of the tables fields, where the first element is always the field names
 * and each subsequent element is the field data. This is also true for the table's indexes, which are accessible
 * via the key 'indexes'.
 */
- (NSDictionary *)tableSourceForPrinting
{
	NSUInteger i, j;
	NSMutableArray *tempResult  = [NSMutableArray array];
	NSMutableArray *tempResult2 = [NSMutableArray array];

	NSString *nullValue = [prefs stringForKey:SPNullValue];
	CFStringRef escapedNullValue = CFXMLCreateStringByEscapingEntities(NULL, ((CFStringRef)nullValue), NULL);

	SPMySQLResult *structureQueryResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW COLUMNS FROM %@", [selectedTable backtickQuotedString]]];
	SPMySQLResult *indexesQueryResult   = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW INDEXES FROM %@", [selectedTable backtickQuotedString]]];

	[structureQueryResult setReturnDataAsStrings:YES];
	[indexesQueryResult setReturnDataAsStrings:YES];

	[tempResult addObject:[structureQueryResult fieldNames]];

	NSMutableArray *temp = [[indexesQueryResult fieldNames] mutableCopy];

	// Remove the 'table' column
	[temp removeObjectAtIndex:0];

	[tempResult2 addObject:temp];

	[temp release];

	for (i = 0; i < [structureQueryResult numberOfRows]; i++) {
		NSMutableArray *row = [[structureQueryResult getRowAsArray] mutableCopy];

		// For every NULL value replace it with the user's NULL value placeholder so we can actually print it
		for (j = 0; j < [row count]; j++)
		{
			if ([[row objectAtIndex:j] isNSNull]) {
				[row replaceObjectAtIndex:j withObject:(NSString *)escapedNullValue];
			}
		}

		[tempResult addObject:row];

		[row release];
	}

	for (i = 0; i < [indexesQueryResult numberOfRows]; i++) {
		NSMutableArray *eachIndex = [[indexesQueryResult getRowAsArray] mutableCopy];

		// Remove the 'table' column values
		[eachIndex removeObjectAtIndex:0];

		// For every NULL value replace it with the user's NULL value placeholder so we can actually print it
		for (j = 0; j < [eachIndex count]; j++)
		{
			if ([[eachIndex objectAtIndex:j] isNSNull]) {
				[eachIndex replaceObjectAtIndex:j withObject:(NSString *)escapedNullValue];
			}
		}

		[tempResult2 addObject:eachIndex];

		[eachIndex release];
	}

	CFRelease(escapedNullValue);
	return [NSDictionary dictionaryWithObjectsAndKeys:tempResult, @"structure", tempResult2, @"indexes", nil];
}

#pragma mark -
#pragma mark Task interaction

/**
 * Disable all content interactive elements during an ongoing task.
 */
- (void)startDocumentTaskForTab:(NSNotification *)aNotification
{
#ifndef SP_CODA /* check toolbar mode */
	// Only proceed if this view is selected.
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableStructure]) return;
#endif

	[tableSourceView setEnabled:NO];
	[addFieldButton setEnabled:NO];
	[removeFieldButton setEnabled:NO];
	[duplicateFieldButton setEnabled:NO];
	[reloadFieldsButton setEnabled:NO];
#ifndef SP_CODA
	[editTableButton setEnabled:NO];
#endif

	[indexesTableView setEnabled:NO];
#ifndef SP_CODA
	[addIndexButton setEnabled:NO];
	[removeIndexButton setEnabled:NO];
	[refreshIndexesButton setEnabled:NO];
#endif
}

/**
 * Enable all content interactive elements after an ongoing task.
 */
- (void)endDocumentTaskForTab:(NSNotification *)aNotification
{
#ifndef SP_CODA /* check toolbar mode */
	// Only re-enable elements if the current tab is the structure view
	if (![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableStructure]) return;
#endif

	BOOL editingEnabled = ([tablesListInstance tableType] == SPTableTypeTable);

	[tableSourceView setEnabled:YES];
	[tableSourceView displayIfNeeded];
	[addFieldButton setEnabled:editingEnabled];

	if (editingEnabled && [tableSourceView numberOfSelectedRows] > 0) {
		[removeFieldButton setEnabled:YES];
		[duplicateFieldButton setEnabled:YES];
	}

	[reloadFieldsButton setEnabled:YES];
#ifndef SP_CODA
	[editTableButton setEnabled:YES];
#endif

	[indexesTableView setEnabled:YES];
	[indexesTableView displayIfNeeded];

#ifndef SP_CODA
	[addIndexButton setEnabled:editingEnabled && ![[[tableDataInstance statusValueForKey:@"Engine"] uppercaseString] isEqualToString:@"CSV"]];
	[removeIndexButton setEnabled:(editingEnabled && ([indexesTableView numberOfSelectedRows] > 0))];
	[refreshIndexesButton setEnabled:YES];
#endif
}

#pragma mark -
#pragma mark Private API

/**
 * Removes a field from the current table and the dependent foreign key if specified.
 */
- (void)_removeFieldAndForeignKey:(NSNumber *)removeForeignKey
{
	@autoreleasepool {
		// Remove the foreign key before the field if required
		if ([removeForeignKey boolValue]) {
			NSString *relationName = @"";
			NSString *field = [[tableFields objectAtIndex:[tableSourceView selectedRow]] objectForKey:@"name"];

			// Get the foreign key name
			for (NSDictionary *constraint in [tableDataInstance getConstraints])
			{
				for (NSString *column in [constraint objectForKey:@"columns"])
				{
					if ([column isEqualToString:field]) {
						relationName = [constraint objectForKey:@"name"];
						break;
					}
				}
			}

			[mySQLConnection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ DROP FOREIGN KEY %@", [selectedTable backtickQuotedString], [relationName backtickQuotedString]]];

			// Check for errors, but only if the query wasn't cancelled
			if ([mySQLConnection queryErrored] && ![mySQLConnection lastQueryWasCancelled]) {
				NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
				[errorDictionary setObject:NSLocalizedString(@"Unable to delete relation", @"error deleting relation message") forKey:@"title"];
				[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to delete the relation '%@'.\n\nMySQL said: %@", @"error deleting relation informative message"), relationName, [mySQLConnection lastErrorMessage]] forKey:@"message"];
				[[self onMainThread] showErrorSheetWith:errorDictionary];
			}
		}

		// Remove field
		[mySQLConnection queryString:[NSString stringWithFormat:@"ALTER TABLE %@ DROP %@",
		                                                        [selectedTable backtickQuotedString], [[[tableFields objectAtIndex:[tableSourceView selectedRow]] objectForKey:@"name"] backtickQuotedString]]];

		// Check for errors, but only if the query wasn't cancelled
		if ([mySQLConnection queryErrored] && ![mySQLConnection lastQueryWasCancelled]) {
			NSMutableDictionary *errorDictionary = [NSMutableDictionary dictionary];
			[errorDictionary setObject:NSLocalizedString(@"Error", @"error") forKey:@"title"];
			[errorDictionary setObject:[NSString stringWithFormat:NSLocalizedString(@"Couldn't delete field %@.\nMySQL said: %@", @"message of panel when field cannot be deleted"),
			                                                      [[tableFields objectAtIndex:[tableSourceView selectedRow]] objectForKey:@"name"],
			                                                      [mySQLConnection lastErrorMessage]] forKey:@"message"];

			[[self onMainThread] showErrorSheetWith:errorDictionary];
		}
		else {
			[tableDataInstance resetAllData];

			// Refresh relevant views
			[tableDocumentInstance setStatusRequiresReload:YES];
			[tableDocumentInstance setContentRequiresReload:YES];
			[tableDocumentInstance setRelationsRequiresReload:YES];

			[self loadTable:selectedTable];
		}

		[tableDocumentInstance endTask];

		// Preserve focus on table for keyboard navigation
		[[tableDocumentInstance parentWindow] makeFirstResponder:tableSourceView];
	}
}

#pragma mark -
#pragma mark Table loading

/**
 * Loads aTable, puts it in an array, updates the tableViewColumns and reloads the tableView.
 */
- (void)loadTable:(NSString *)aTable
{
	NSMutableDictionary *theTableEnumLists = [NSMutableDictionary dictionary];

	// Check whether a save of the current row is required.
	if (![[self onMainThread] saveRowOnDeselect]) return;

	// If no table is selected, reset the interface and return
	if (!aTable || ![aTable length]) {
		[[self onMainThread] setTableDetails:nil];
		return;
	}

	NSMutableArray *theTableFields = [[NSMutableArray alloc] init];

	// Make a mutable copy out of the cached [tableDataInstance columns] since we're adding infos
	for (id col in [tableDataInstance columns])
	{
		[theTableFields addObject:[[col mutableCopy] autorelease]];
	}

	// Retrieve the indexes for the table
	SPMySQLResult *indexResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW INDEX FROM %@", [aTable backtickQuotedString]]];

	// If an error occurred, reset the interface and abort
	if ([mySQLConnection queryErrored]) {
		[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];
		[[self onMainThread] setTableDetails:nil];

		if ([mySQLConnection isConnected]) {
			SPOnewayAlertSheet(
							   NSLocalizedString(@"Error", @"error"),
							   [NSApp mainWindow],
							   [NSString stringWithFormat:NSLocalizedString(@"An error occurred while retrieving information.\nMySQL said: %@", @"message of panel when retrieving information failed"), [mySQLConnection lastErrorMessage]]
							   );
		}

		return;
	}

	// Process the indexes into a local array of dictionaries
	NSArray *tableIndexes = [self convertIndexResultToArray:indexResult];

	// Set the Key column
	for (NSDictionary *index in tableIndexes)
	{
		for (id field in theTableFields)
		{
			if ([[field objectForKey:@"name"] isEqualToString:[index objectForKey:@"Column_name"]]) {
				if ([[index objectForKey:@"Key_name"] isEqualToString:@"PRIMARY"]) {
					[field setObject:@"PRI" forKey:@"Key"];
				}
				else {
					if ([[field objectForKey:@"typegrouping"] isEqualToString:@"geometry"] &&
						[[index objectForKey:@"Index_type"] isEqualToString:@"SPATIAL"] &&
						![field objectForKey:@"Key"]) {
						[field setObject:@"SPA" forKey:@"Key"];
					}
					else {
						[field setObject:[[index objectForKey:@"Non_unique"] isEqualToString:@"1"] ? @"MUL" : @"UNI" forKey:@"Key"];
					}
				}

				break;
			}
		}
	}

	// Set up the encoding PopUpButtonCell
	NSArray *encodings  = [databaseDataInstance getDatabaseCharacterSetEncodings];

	SPMainQSync(^{
		[encodingPopupCell removeAllItems];

		if ([encodings count]) {

			[encodingPopupCell addItemWithTitle:@"dummy"];
			//copy the default attributes and add gray color
			NSMutableDictionary *defaultAttrs = [NSMutableDictionary dictionaryWithDictionary:[[encodingPopupCell attributedTitle] attributesAtIndex:0 effectiveRange:NULL]];
			[defaultAttrs setObject:[NSColor lightGrayColor] forKey:NSForegroundColorAttributeName];
			[[encodingPopupCell lastItem] setTitle:@""];

			for (NSDictionary *encoding in encodings)
			{
				NSString *encodingName = [encoding objectForKey:@"CHARACTER_SET_NAME"];
				NSString *title = (![encoding objectForKey:@"DESCRIPTION"]) ? encodingName : [NSString stringWithFormat:@"%@ (%@)", [encoding objectForKey:@"DESCRIPTION"], encodingName];

				[encodingPopupCell addItemWithTitle:title];
				NSMenuItem *item = [encodingPopupCell lastItem];

				[item setRepresentedObject:encodingName];

				if ([encodingName isEqualToString:[tableDataInstance tableEncoding]]) {

					NSAttributedString *itemString = [[NSAttributedString alloc] initWithString:[item title] attributes:defaultAttrs];

					[item setAttributedTitle:[itemString autorelease]];
				}
			}
		}
		else {
			[encodingPopupCell addItemWithTitle:NSLocalizedString(@"Not available", @"not available label")];
		}
	});

	// Process all the fields to normalise keys and add additional information
	for (id theField in theTableFields)
	{
		NSString *type = [[[theField objectForKey:@"type"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];

		if([type isEqualToString:@"JSON"]) {
			// MySQL 5.7 manual:
			// "MySQL handles strings used in JSON context using the utf8mb4 character set and utf8mb4_bin collation.
			//  Strings in other character set are converted to utf8mb4 as necessary."
			[theField setObject:@"utf8mb4" forKey:@"encodingName"];
			[theField setObject:@"utf8mb4_bin" forKey:@"collationName"];
			[theField setObject:@1 forKey:@"binary"];
		}
		else if ([fieldValidation isFieldTypeString:type]) {
			// The MySQL 4.1 manual says:
			//
			// MySQL chooses the column character set and collation in the following manner:
			//   1. If both CHARACTER SET X and COLLATE Y were specified, then character set X and collation Y are used.
			//   2. If CHARACTER SET X was specified without COLLATE, then character set X and its default collation are used.
			//   3. If COLLATE Y was specified without CHARACTER SET, then the character set associated with Y and collation Y.
			//   4. Otherwise, the table character set and collation are used.
			NSString *encoding  = [theField objectForKey:@"encoding"];
			NSString *collation = [theField objectForKey:@"collation"];
			if(encoding) {
				if(collation) {
					// 1
				}
				else {
					collation = [databaseDataInstance getDefaultCollationForEncoding:encoding]; // 2
				}
			}
			else {
				if(collation) {
					encoding = [databaseDataInstance getEncodingFromCollation:collation]; // 3
				}
				else {
					encoding = [tableDataInstance tableEncoding]; //4
					collation = [tableDataInstance statusValueForKey:@"Collation"];
					if(!collation) {
						// should not happen, as the TABLE STATUS output always(?) includes the collation
						collation = [databaseDataInstance getDefaultCollationForEncoding:encoding];
					}
				}
			}

			// MySQL < 4.1 does not support collations (they are part of the charset), it will be nil there

			[theField setObject:encoding forKey:@"encodingName"];
			[theField setObject:collation forKey:@"collationName"];

			// Set BINARY if collation ends with _bin for convenience
			if ([collation hasSuffix:@"_bin"]) {
				[theField setObject:@1 forKey:@"binary"];
			}
		}

		// Get possible values if the field is an enum or a set
		if (([type isEqualToString:@"ENUM"] || [type isEqualToString:@"SET"]) && [theField objectForKey:@"values"]) {
			[theTableEnumLists setObject:[NSArray arrayWithArray:[theField objectForKey:@"values"]] forKey:[theField objectForKey:@"name"]];
			[theField setObject:[NSString stringWithFormat:@"'%@'", [[theField objectForKey:@"values"] componentsJoinedByString:@"','"]] forKey:@"length"];
		}

		// Join length and decimals if any
		if ([theField objectForKey:@"decimals"])
			[theField setObject:[NSString stringWithFormat:@"%@,%@", [theField objectForKey:@"length"], [theField objectForKey:@"decimals"]] forKey:@"length"];

		// Normalize default
		if (![theField objectForKey:@"default"]) {
			[theField setObject:@"" forKey:@"default"];
		}
		else if ([[theField objectForKey:@"default"] isNSNull]) {
			[theField setObject:[prefs stringForKey:SPNullValue] forKey:@"default"];
		}

		// Init Extra field
		[theField setObject:@"None" forKey:@"Extra"];

		// Check for auto_increment and set Extra accordingly
		if ([[theField objectForKey:@"autoincrement"] integerValue]) {
			[theField setObject:@"auto_increment" forKey:@"Extra"];
		}

		// For timestamps/datetime check to see whether "on update CURRENT_TIMESTAMP"  and set Extra accordingly
		else if ([type isInArray:@[@"TIMESTAMP",@"DATETIME"]] && [[theField objectForKey:@"onupdatetimestamp"] boolValue]) {
			NSString *ouct = @"on update CURRENT_TIMESTAMP";
			// restore a length parameter if the field has fractional seconds.
			// the parameter of current_timestamp MUST match the field's length in that case, so we can just 'guess' it.
			NSString *fieldLen = [theField objectForKey:@"length"];
			if([fieldLen length] && ![fieldLen isEqualToString:@"0"]) {
				ouct = [ouct stringByAppendingFormat:@"(%@)",fieldLen];
			}
			[theField setObject:ouct forKey:@"Extra"];
		}
	}

	// Set up the table details for the new table, and request an data/interface update
	NSDictionary *tableDetails = [NSDictionary dictionaryWithObjectsAndKeys:
								  aTable, @"name",
								  theTableFields, @"tableFields",
								  tableIndexes, @"tableIndexes",
								  theTableEnumLists, @"enumLists",
								  nil];

	[[self onMainThread] setTableDetails:tableDetails];

	isCurrentExtraAutoIncrement = [tableDataInstance tableHasAutoIncrementField];
	autoIncrementIndex = nil;

	// Send the query finished/work complete notification
	[[NSNotificationCenter defaultCenter] postNotificationOnMainThreadWithName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];

	[theTableFields release];
}

/**
 * Reloads the table (performing a new query).
 */
- (IBAction)reloadTable:(id)sender
{
	// Check whether a save of the current row is required
	if (![[self onMainThread] saveRowOnDeselect]) return;

	[tableDataInstance resetAllData];
	[tableDocumentInstance setStatusRequiresReload:YES];

	// Query the structure of all databases in the background (mainly for completion)
	[[tableDocumentInstance databaseStructureRetrieval] queryDbStructureInBackgroundWithUserInfo:@{@"forceUpdate" : @YES}];

	[self loadTable:selectedTable];
}

/**
 * Updates the stored table details and updates the interface to match.
 *
 * Should be called on the main thread.
 */
- (void)setTableDetails:(NSDictionary *)tableDetails
{
	NSString *newTableName = [tableDetails objectForKey:@"name"];
	NSMutableDictionary *newDefaultValues;

	BOOL enableInteraction =
#ifndef SP_CODA /* patch */
	![[tableDocumentInstance selectedToolbarItemIdentifier] isEqualToString:SPMainToolbarTableStructure] ||
#endif
	![tableDocumentInstance isWorking];

	// Update the selected table name
	if (selectedTable) SPClear(selectedTable);
	if (newTableName) selectedTable = [[NSString alloc] initWithString:newTableName];

	[indexesController setTable:selectedTable];

	// Reset the table store and display
	[tableSourceView deselectAll:self];
	[tableFields removeAllObjects];
	[enumFields removeAllObjects];
	[indexesTableView deselectAll:self];
	[addFieldButton setEnabled:NO];
	[duplicateFieldButton setEnabled:NO];
	[removeFieldButton setEnabled:NO];
#ifndef SP_CODA
	[addIndexButton setEnabled:NO];
	[removeIndexButton setEnabled:NO];
	[editTableButton setEnabled:NO];
#endif

	// If no table is selected, refresh the table/index display to blank and return
	if (!selectedTable) {
		[tableSourceView reloadData];
		// Empty indexesController's fields and indices explicitly before reloading
		[indexesController setFields:@[]];
		[indexesController setIndexes:@[]];
		[indexesTableView reloadData];

		return;
	}

	// Update the fields and indexes stores
	[tableFields setArray:[tableDetails objectForKey:@"tableFields"]];

	[indexesController setFields:tableFields];
	[indexesController setIndexes:[tableDetails objectForKey:@"tableIndexes"]];

	if (defaultValues) SPClear(defaultValues);

	newDefaultValues = [NSMutableDictionary dictionaryWithCapacity:[tableFields count]];

	for (id theField in tableFields)
	{
		[newDefaultValues setObject:[theField objectForKey:@"default"] forKey:[theField objectForKey:@"name"]];
	}

	defaultValues = [[NSDictionary dictionaryWithDictionary:newDefaultValues] retain];

#ifndef SP_CODA
	// Enable the edit table button
	[editTableButton setEnabled:enableInteraction];
#endif

	// If a view is selected, disable the buttons; otherwise enable.
	BOOL editingEnabled = ([tablesListInstance tableType] == SPTableTypeTable) && enableInteraction;

	[addFieldButton setEnabled:editingEnabled];
#ifndef SP_CODA
	[addIndexButton setEnabled:editingEnabled && ![[[tableDataInstance statusValueForKey:@"Engine"] uppercaseString] isEqualToString:@"CSV"]];
#endif

	// Reload the views
	[indexesTableView reloadData];
	[tableSourceView reloadData];
}

#pragma mark - SPTableStructureDelegate

#pragma mark Table view datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [tableFields count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	// Return a placeholder if the table is reloading
	if ((NSUInteger)rowIndex >= [tableFields count]) return @"...";

	NSDictionary *rowData = NSArrayObjectAtIndex(tableFields, rowIndex);

	if ([[tableColumn identifier] isEqualToString:@"collation"]) {
		NSString *tableEncoding = [tableDataInstance tableEncoding];
		NSString *columnEncoding = [rowData objectForKey:@"encodingName"];
		NSString *columnCollation = [rowData objectForKey:@"collationName"]; // loadTable: has already inferred it, if not set explicit

#warning Building the collation menu here is a big performance hog. This should be done in menuNeedsUpdate: below!
		NSPopUpButtonCell *collationCell = [tableColumn dataCell];
		[collationCell removeAllItems];
		[collationCell addItemWithTitle:@"dummy"];
		//copy the default style of menu items and add gray color for default item
		NSMutableDictionary *menuAttrs = [NSMutableDictionary dictionaryWithDictionary:[[collationCell attributedTitle] attributesAtIndex:0 effectiveRange:NULL]];
		[menuAttrs setObject:[NSColor lightGrayColor] forKey:NSForegroundColorAttributeName];
		[[collationCell lastItem] setTitle:@""];

		//if this is not set the column either has no encoding (numeric etc.) or retrieval failed. Either way we can't provide collations
		if([columnEncoding length]) {
			collations = [databaseDataInstance getDatabaseCollationsForEncoding:columnEncoding];

			if ([collations count] > 0) {
				NSString *tableCollation = [[tableDataInstance statusValues] objectForKey:@"Collation"];

				if (![tableCollation length]) {
					tableCollation = [databaseDataInstance getDefaultCollationForEncoding:tableEncoding];
				}

				BOOL columnUsesTableDefaultEncoding = ([columnEncoding isEqualToString:tableEncoding]);
				// Populate collation popup button
				for (NSDictionary *collation in collations)
				{
					NSString *collationName = [collation objectForKey:@"COLLATION_NAME"];

					[collationCell addItemWithTitle:collationName];
					NSMenuItem *item = [collationCell lastItem];
					[item setRepresentedObject:collationName];

					// If this matches the table's collation, draw in gray
					if (columnUsesTableDefaultEncoding && [collationName isEqualToString:tableCollation]) {
						NSAttributedString *itemString = [[NSAttributedString alloc] initWithString:[item title] attributes:menuAttrs];
						[item setAttributedTitle:[itemString autorelease]];
					}
				}

				// the popup cell is subclassed to take the representedObject instead of the item index
				return columnCollation;
			}
		}

		return nil;
	}
	else if ([[tableColumn identifier] isEqualToString:@"encoding"]) {
		// the encoding menu was already configured during setTableDetails:
		NSString *columnEncoding = [rowData objectForKey:@"encodingName"];

		if([columnEncoding length]) {
			NSInteger idx = [encodingPopupCell indexOfItemWithRepresentedObject:columnEncoding];
			if(idx > 0) return @(idx);
		}

		return @0;
	}
	else if ([[tableColumn identifier] isEqualToString:@"Extra"]) {
		id dataCell = [tableColumn dataCell];

		[dataCell removeAllItems];

		// Populate Extra suggestion popup button
		for (id item in extraFieldSuggestions)
		{
			if (!(isCurrentExtraAutoIncrement && [item isEqualToString:@"auto_increment"])) {
				[dataCell addItemWithObjectValue:item];
			}
		}
	}

	return [rowData objectForKey:[tableColumn identifier]];
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	// Make sure that the operation is for the right table view
	if (aTableView != tableSourceView) return;

	NSMutableDictionary *currentRow = NSArrayObjectAtIndex(tableFields,rowIndex);

	if (!isEditingRow) {
		[oldRow setDictionary:currentRow];
		isEditingRow = YES;
		currentlyEditingRow = rowIndex;
	}

	// Reset collation if encoding was changed
	if ([[aTableColumn identifier] isEqualToString:@"encoding"]) {
		NSString *oldEncoding = [currentRow objectForKey:@"encodingName"];
		NSString *newEncoding = [[encodingPopupCell itemAtIndex:[anObject integerValue]] representedObject];
		if (![oldEncoding isEqualToString:newEncoding]) {
			[currentRow removeObjectForKey:@"collationName"];
			[tableSourceView reloadData];
		}
		if(!newEncoding)
			[currentRow removeObjectForKey:@"encodingName"];
		else
			[currentRow setObject:newEncoding forKey:@"encodingName"];
		return;
	}
	else if ([[aTableColumn identifier] isEqualToString:@"collation"]) {
		//the popup button is subclassed to return the representedObject instead of the item index
		NSString *newCollation = anObject;

		if(!newCollation)
			[currentRow removeObjectForKey:@"collationName"];
		else
			[currentRow setObject:newCollation forKey:@"collationName"];
		return;
	}
	// Reset collation if BINARY was changed, as enabling BINARY sets collation to *_bin
	else if ([[aTableColumn identifier] isEqualToString:@"binary"]) {
		if ([[currentRow objectForKey:@"binary"] integerValue] != [anObject integerValue]) {
			[currentRow removeObjectForKey:@"collationName"];

			[tableSourceView reloadData];
		}
	}
	// Set null field to "do not allow NULL" for auto_increment Extra and reset Extra suggestion list
	else if ([[aTableColumn identifier] isEqualToString:@"Extra"]) {
		if (![[currentRow objectForKey:@"Extra"] isEqualToString:anObject]) {

			isCurrentExtraAutoIncrement = [[[anObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString] isEqualToString:@"AUTO_INCREMENT"];

			if (isCurrentExtraAutoIncrement) {
				[currentRow setObject:@0 forKey:@"null"];

				// Asks the user to add an index to query if AUTO_INCREMENT is set and field isn't indexed
				if ((![currentRow objectForKey:@"Key"] || [[currentRow objectForKey:@"Key"] isEqualToString:@""])) {
#ifndef SP_CODA
					[chooseKeyButton selectItemWithTag:SPPrimaryKeyMenuTag];

					[NSApp beginSheet:keySheet
					   modalForWindow:[tableDocumentInstance parentWindow] modalDelegate:self
					   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
						  contextInfo:@"autoincrementindex" ];
#endif
				}
			}
			else {
				autoIncrementIndex = nil;
			}

			id dataCell = [aTableColumn dataCell];

			[dataCell removeAllItems];
			[dataCell addItemsWithObjectValues:extraFieldSuggestions];
			[dataCell noteNumberOfItemsChanged];
			[dataCell reloadData];

			[tableSourceView reloadData];

		}
	}
	// Reset default to "" if field doesn't allow NULL and current default is set to NULL
	else if ([[aTableColumn identifier] isEqualToString:@"null"]) {
		if ([[currentRow objectForKey:@"null"] integerValue] != [anObject integerValue]) {
			if ([anObject integerValue] == 0) {
				if ([[currentRow objectForKey:@"default"] isEqualToString:[prefs objectForKey:SPNullValue]]) {
					[currentRow setObject:@"" forKey:@"default"];
				}
			}

			[tableSourceView reloadData];
		}
	}
	// Store new value but not if user choose "---" for type and reset values if required
	else if ([[aTableColumn identifier] isEqualToString:@"type"]) {
		if (anObject && [(NSString*)anObject length] && ![(NSString*)anObject hasPrefix:@"--"]) {
			[currentRow setObject:[(NSString*)anObject uppercaseString] forKey:@"type"];

			// If type is BLOB or TEXT reset DEFAULT since these field types don't allow a default
			if ([[currentRow objectForKey:@"type"] hasSuffix:@"TEXT"] ||
				[[currentRow objectForKey:@"type"] hasSuffix:@"BLOB"] ||
				[[currentRow objectForKey:@"type"] isEqualToString:@"JSON"] ||
				[fieldValidation isFieldTypeGeometry:[currentRow objectForKey:@"type"]] ||
				([fieldValidation isFieldTypeDate:[currentRow objectForKey:@"type"]] && ![[currentRow objectForKey:@"type"] isEqualToString:@"YEAR"]))
			{
				[currentRow setObject:@"" forKey:@"default"];
				[currentRow setObject:@"" forKey:@"length"];
			}

			[tableSourceView reloadData];
		}
		return;
	}

	[currentRow setObject:(anObject) ? anObject : @"" forKey:[aTableColumn identifier]];
}

/**
 * Confirm whether to allow editing of a row. Returns YES by default, but NO for views.
 */
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if ([tableDocumentInstance isWorking]) return NO;

	// Return NO for views
	if ([tablesListInstance tableType] == SPTableTypeView) return NO;

	return YES;
}

/**
 * Begin a drag and drop operation from the table - copy a single dragged row to the drag pasteboard.
 */
- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rows toPasteboard:(NSPasteboard*)pboard
{
	// Make sure that the drag operation is started from the right table view
	if (aTableView != tableSourceView) return NO;

	// Check whether a save of the current field row is required.
	if (![self saveRowOnDeselect]) return NO;

	if ([rows count] == 1) {
		[pboard declareTypes:@[SPDefaultPasteboardDragType] owner:nil];
		[pboard setString:[NSString stringWithFormat:@"%lu",[rows firstIndex]] forType:SPDefaultPasteboardDragType];

		return YES;
	}

	return NO;
}

/**
 * Determine whether to allow a drag and drop operation on this table - for the purposes of drag reordering,
 * validate that the original source is of the correct type and within the same table, and that the drag
 * would result in a position change.
 */
- (NSDragOperation)tableView:(NSTableView*)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
	// Make sure that the drag operation is for the right table view
	if (tableView!=tableSourceView) return NSDragOperationNone;

	NSArray *pboardTypes = [[info draggingPasteboard] types];
	NSInteger originalRow;

	// Ensure the drop is of the correct type
	if (operation == NSTableViewDropAbove && row != -1 && [pboardTypes containsObject:SPDefaultPasteboardDragType]) {

		// Ensure the drag originated within this table
		if ([info draggingSource] == tableView) {
			originalRow = [[[info draggingPasteboard] stringForType:SPDefaultPasteboardDragType] integerValue];

			if (row != originalRow && row != (originalRow+1)) {
				return NSDragOperationMove;
			}
		}
	}

	return NSDragOperationNone;
}

/**
 * Having validated a drop, perform the field/column reordering to match.
 */
- (BOOL)tableView:(NSTableView*)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)destinationRowIndex dropOperation:(NSTableViewDropOperation)operation
{
	// Make sure that the drag operation is for the right table view
	if (tableView != tableSourceView) return NO;

	// Extract the original row position from the pasteboard and retrieve the details
	NSInteger originalRowIndex = [[[info draggingPasteboard] stringForType:SPDefaultPasteboardDragType] integerValue];
	NSDictionary *originalRow = [[NSDictionary alloc] initWithDictionary:[tableFields objectAtIndex:originalRowIndex]];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:tableDocumentInstance];

	// Begin construction of the reordering query
	NSMutableString *queryString = [NSMutableString stringWithFormat:@"ALTER TABLE %@ MODIFY COLUMN %@",
									[selectedTable backtickQuotedString],
									[self _buildPartialColumnDefinitionString:originalRow]];

	[queryString appendString:@" "];
	// Add the new location
	if (destinationRowIndex == 0) {
		[queryString appendString:@"FIRST"];
	}
	else {
		[queryString appendFormat:@"AFTER %@", [[[tableFields objectAtIndex:destinationRowIndex - 1] objectForKey:@"name"] backtickQuotedString]];
	}

	// Run the query; report any errors, or reload the table on success
	[mySQLConnection queryString:queryString];

	if ([mySQLConnection queryErrored]) {
		SPOnewayAlertSheet(
						   NSLocalizedString(@"Error moving field", @"error moving field message"),
						   [tableDocumentInstance parentWindow],
						   [NSString stringWithFormat:NSLocalizedString(@"An error occurred while trying to move the field.\n\nMySQL said: %@", @"error moving field informative message"), [mySQLConnection lastErrorMessage]]
						   );
	}
	else {
		[tableDataInstance resetAllData];
		[tableDocumentInstance setStatusRequiresReload:YES];

		[self loadTable:selectedTable];

		// Mark the content table cache for refresh
		[tableDocumentInstance setContentRequiresReload:YES];

		[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:destinationRowIndex - ((originalRowIndex < destinationRowIndex) ? 1 : 0)] byExtendingSelection:NO];
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:tableDocumentInstance];

	[originalRow release];

	return YES;
}

#pragma mark -
#pragma mark Table view delegate methods

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
	// If we are editing a row, attempt to save that row - if saving failed, do not select the new row.
	if (isEditingRow && ![self addRowToDB]) return NO;

	return YES;
}

/**
 * Performs various interface validation
 */
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	// Check for which table view the selection changed
	if ([aNotification object] == tableSourceView) {

		// If we are editing a row, attempt to save that row - if saving failed, reselect the edit row.
		if (isEditingRow && [tableSourceView selectedRow] != currentlyEditingRow && ![self saveRowOnDeselect]) return;

		[duplicateFieldButton setEnabled:YES];

		// Check if there is currently a field selected and change button state accordingly
		if ([tableSourceView numberOfSelectedRows] > 0 && [tablesListInstance tableType] == SPTableTypeTable) {
			[removeFieldButton setEnabled:YES];
		}
		else {
			[removeFieldButton setEnabled:NO];
			[duplicateFieldButton setEnabled:NO];
		}

		// If the table only has one field, disable the remove button. This removes the need to check that the user
		// is attempting to remove the last field in a table in removeField: above, but leave it in just in case.
		if ([tableSourceView numberOfRows] == 1) {
			[removeFieldButton setEnabled:NO];
		}
	}
}

/**
 * Traps enter and esc and make/cancel editing without entering next row
 */
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	NSInteger row, column;

	row = [tableSourceView editedRow];
	column = [tableSourceView editedColumn];

	// Trap the tab key, selecting the next item in the line
	if ([textView methodForSelector:command] == [textView methodForSelector:@selector(insertTab:)] && [tableSourceView numberOfColumns] - 1 == column)
	{
		//save current line
		[[control window] makeFirstResponder:control];

		if ([self addRowToDB] && [textView methodForSelector:command] == [textView methodForSelector:@selector(insertTab:)]) {
			if (row < ([tableSourceView numberOfRows] - 1)) {
				[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:row + 1] byExtendingSelection:NO];
				[tableSourceView editColumn:0 row:row + 1 withEvent:nil select:YES];
			}
			else {
				[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
				[tableSourceView editColumn:0 row:0 withEvent:nil select:YES];
			}
		}

		return YES;
	}
	// Trap shift-tab key
	else if ([textView methodForSelector:command] == [textView methodForSelector:@selector(insertBacktab:)] && column < 1)
	{
		if ([self addRowToDB] && [textView methodForSelector:command] == [textView methodForSelector:@selector(insertBacktab:)]) {
			[[control window] makeFirstResponder:control];

			if (row > 0) {
				[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:row - 1] byExtendingSelection:NO];
				[tableSourceView editColumn:([tableSourceView numberOfColumns] - 1) row:row - 1 withEvent:nil select:YES];
			}
			else {
				[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:([tableFields count] - 1)] byExtendingSelection:NO];
				[tableSourceView editColumn:([tableSourceView numberOfColumns] - 1) row:([tableSourceView numberOfRows] - 1) withEvent:nil select:YES];
			}
		}

		return YES;
	}
	// Trap the enter key, triggering a save
	else if ([textView methodForSelector:command] == [textView methodForSelector:@selector(insertNewline:)])
	{
		// Suppress enter for non-text fields to allow selecting of chosen items from comboboxes or popups
		if (![[[[[[tableSourceView tableColumns] objectAtIndex:column] dataCell] class] description] isEqualToString:@"NSTextFieldCell"]) {
			return YES;
		}

		[[control window] makeFirstResponder:control];

		[self addRowToDB];

		[tableSourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

		[[tableDocumentInstance parentWindow] makeFirstResponder:tableSourceView];

		return YES;
	}
	// Trap escape, aborting the edit and reverting the row
	else if ([[control window] methodForSelector:command] == [[control window] methodForSelector:@selector(cancelOperation:)])
	{
		[control abortEditing];

		[self cancelRowEditing];

		return YES;
	}

	return NO;
}

/**
 * Modify cell display by disabling table cells when a view is selected, meaning structure/index
 * is uneditable and do cell validation due to row's field type.
 */
- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	// Make sure that the message is from the right table view
	if (tableView != tableSourceView) return;

	if ([tablesListInstance tableType] == SPTableTypeView) {
		[aCell setEnabled:NO];
	}
	else {
		// Validate cell against current field type
		NSString *rowType;
		NSDictionary *row = NSArrayObjectAtIndex(tableFields, rowIndex);

		if ((rowType = [row objectForKey:@"type"])) {
			rowType = [[rowType stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
		}

		// Only string fields allow encoding settings, but JSON only uses utf8mb4
		if (([[tableColumn identifier] isEqualToString:@"encoding"])) {
			[aCell setEnabled:(![rowType isEqualToString:@"JSON"] && [fieldValidation isFieldTypeString:rowType] && [[tableDocumentInstance serverSupport] supportsPost41CharacterSetHandling])];
		}

		// Only string fields allow collation settings and string field is not set to BINARY since BINARY sets the collation to *_bin
		else if ([[tableColumn identifier] isEqualToString:@"collation"]) {
			// JSON always uses utf8mb4_bin which is already covered by this logic
			[aCell setEnabled:([fieldValidation isFieldTypeString:rowType] && [[row objectForKey:@"binary"] integerValue] == 0 && [[tableDocumentInstance serverSupport] supportsPost41CharacterSetHandling])];
		}

		// Check if UNSIGNED and ZEROFILL is allowed
		else if ([[tableColumn identifier] isEqualToString:@"zerofill"] || [[tableColumn identifier] isEqualToString:@"unsigned"]) {
			[aCell setEnabled:([fieldValidation isFieldTypeNumeric:rowType] && ![rowType isEqualToString:@"BIT"])];
		}

		// Check if BINARY is allowed
		else if ([[tableColumn identifier] isEqualToString:@"binary"]) {
			// JSON always uses utf8mb4_bin
			[aCell setEnabled:(![rowType isEqualToString:@"JSON"] && [fieldValidation isFieldTypeAllowBinary:rowType])];
		}

		// TEXT, BLOB, GEOMETRY and JSON fields don't allow a DEFAULT
		else if ([[tableColumn identifier] isEqualToString:@"default"]) {
			[aCell setEnabled:([rowType hasSuffix:@"TEXT"] || [rowType hasSuffix:@"BLOB"] || [rowType isEqualToString:@"JSON"] || [fieldValidation isFieldTypeGeometry:rowType]) ? NO : YES];
		}

		// Check allow NULL
		else if ([[tableColumn identifier] isEqualToString:@"null"]) {
			[aCell setEnabled:([[row objectForKey:@"Key"] isEqualToString:@"PRI"] ||
							   [[[row objectForKey:@"Extra"] uppercaseString] isEqualToString:@"AUTO_INCREMENT"] ||
							   [[[tableDataInstance statusValueForKey:@"Engine"] uppercaseString] isEqualToString:@"CSV"]) ? NO : YES];
		}

		// TEXT, BLOB, date, GEOMETRY and JSON fields don't allow a length
		else if ([[tableColumn identifier] isEqualToString:@"length"]) {
			[aCell setEnabled:([rowType hasSuffix:@"TEXT"] ||
							   [rowType hasSuffix:@"BLOB"] ||
							   [rowType isEqualToString:@"JSON"] ||
							   ([fieldValidation isFieldTypeDate:rowType] && ![[tableDocumentInstance serverSupport] supportsFractionalSeconds] && ![rowType isEqualToString:@"YEAR"]) ||
							   [fieldValidation isFieldTypeGeometry:rowType]) ? NO : YES];
		}
		else {
			[aCell setEnabled:YES];
		}
	}
}

#pragma mark -
#pragma mark Split view delegate methods
#ifndef SP_CODA /* Split view delegate methods */

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	return YES;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
	return proposedMax - 130;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
	return proposedMin + 130;
}

- (NSRect)splitView:(NSSplitView *)splitView additionalEffectiveRectOfDividerAtIndex:(NSInteger)dividerIndex
{
	return [structureGrabber convertRect:[structureGrabber bounds] toView:splitView];
}

- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
	if ([aNotification object] == tablesIndexesSplitView) {

		NSView *indexesView = [[tablesIndexesSplitView subviews] objectAtIndex:1];

		if ([tablesIndexesSplitView isSubviewCollapsed:indexesView]) {
			[indexesShowButton setHidden:NO];
		}
		else {
			[indexesShowButton setHidden:YES];
		}
	}
}
#endif

#pragma mark -
#pragma mark Combo box delegate methods

- (id)comboBoxCell:(NSComboBoxCell *)aComboBoxCell objectValueForItemAtIndex:(NSInteger)index
{
	return NSArrayObjectAtIndex(typeSuggestions, index);
}

- (NSInteger)numberOfItemsInComboBoxCell:(NSComboBoxCell *)aComboBoxCell
{
	return [typeSuggestions count];
}

/**
 * Allow completion of field data types of lowercased input.
 */
- (NSString *)comboBoxCell:(NSComboBoxCell *)aComboBoxCell completedString:(NSString *)uncompletedString
{
	if ([uncompletedString hasPrefix:@"-"]) return @"";

	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH[c] %@", [uncompletedString uppercaseString]];
	NSArray *result = [typeSuggestions filteredArrayUsingPredicate:predicate];

	if ([result count]) return [result objectAtIndex:0];

	return @"";
}

- (void)comboBoxCell:(SPComboBoxCell *)cell willPopUpWindow:(NSWindow *)win
{
	// the selected item in the popup list is independent of the displayed text, we have to explicitly set it, too
	NSInteger pos = [typeSuggestions indexOfObject:[cell stringValue]];
	if(pos != NSNotFound) {
		[cell selectItemAtIndex:pos];
		[cell scrollItemAtIndexToTop:pos];
	}

	//set up the help window to the right position
	NSRect listFrame = [win frame];
	NSRect helpFrame = [structureHelpPanel frame];
	helpFrame.origin.y = listFrame.origin.y;
	helpFrame.size.height = listFrame.size.height;
	[structureHelpPanel setFrame:helpFrame display:YES];

	[self _displayFieldTypeHelpIfPossible:cell];
}

- (void)comboBoxCell:(SPComboBoxCell *)cell willDismissWindow:(NSWindow *)win
{
	//hide the window if it is still visible
	[structureHelpPanel orderOut:nil];
}

- (void)comboBoxCellSelectionDidChange:(SPComboBoxCell *)cell
{
	[self _displayFieldTypeHelpIfPossible:cell];
}

- (void)_displayFieldTypeHelpIfPossible:(SPComboBoxCell *)cell
{
	NSString *selected = [typeSuggestions objectOrNilAtIndex:[cell indexOfSelectedItem]];

	const SPFieldTypeHelp *help = [[self class] helpForFieldType:selected];

	if (help) {
		NSMutableAttributedString *as = [[NSMutableAttributedString alloc] init];

		//title
		{
			NSDictionary *titleAttr = @{NSFontAttributeName: [NSFont boldSystemFontOfSize:[NSFont systemFontSize]], NSForegroundColorAttributeName: [NSColor controlTextColor]};
			NSAttributedString *title = [[NSAttributedString alloc] initWithString:[help typeDefinition] attributes:titleAttr];
			[as appendAttributedString:[title autorelease]];
			[[as mutableString] appendString:@"\n"];
		}

		//range
		if ([[help typeRange] length]) {
			NSDictionary *rangeAttr = @{NSFontAttributeName: [NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSForegroundColorAttributeName: [NSColor controlTextColor]};
			NSAttributedString *range = [[NSAttributedString alloc] initWithString:[help typeRange] attributes:rangeAttr];
			[as appendAttributedString:[range autorelease]];
			[[as mutableString] appendString:@"\n"];
		}

		[[as mutableString] appendString:@"\n"];

		//description
		{
			NSDictionary *descAttr = @{NSFontAttributeName: [NSFont systemFontOfSize:[NSFont systemFontSize]], NSForegroundColorAttributeName: [NSColor controlTextColor]};
			NSAttributedString *desc = [[NSAttributedString alloc] initWithString:[help typeDescription] attributes:descAttr];
			[as appendAttributedString:[desc autorelease]];
		}

		[as addAttribute:NSParagraphStyleAttributeName value:[NSParagraphStyle defaultParagraphStyle] range:NSMakeRange(0, [as length])];

		[[structureHelpText textStorage] setAttributedString:[as autorelease]];

		NSRect rect = [as boundingRectWithSize:NSMakeSize([structureHelpText frame].size.width-2, CGFLOAT_MAX) options:NSStringDrawingUsesFontLeading|NSStringDrawingUsesLineFragmentOrigin];

		NSRect winRect = [structureHelpPanel frame];

		CGFloat winAddonSize = (winRect.size.height - [[structureHelpPanel contentView] frame].size.height) + (6*2);

		NSRect popUpFrame = [[cell spPopUpWindow] frame];

		//determine the side on which to add our window based on the space left on screen
		NSPoint topRightCorner = NSMakePoint(popUpFrame.origin.x, NSMaxY(popUpFrame));
		NSRect screenRect = [NSScreen rectOfScreenAtPoint:topRightCorner];

		if (NSMaxX(popUpFrame)+10+winRect.size.width > NSMaxX(screenRect)-10) {
			// exceeds right border, display on the left
			winRect.origin.x = popUpFrame.origin.x - 10 - winRect.size.width;
		}
		else {
			// display on the right
			winRect.origin.x = NSMaxX(popUpFrame)+10;
		}

		winRect.size.height = rect.size.height + winAddonSize;
		winRect.origin.y = NSMaxY(popUpFrame) - winRect.size.height;

		[structureHelpPanel setFrame:winRect display:YES];

		[structureHelpPanel orderFront:nil];
	}
	else {
		[structureHelpPanel orderOut:nil];
	}
}

#pragma mark -
#pragma mark Menu delegate methods (encoding/collation dropdown menu)

- (void)menuNeedsUpdate:(SPIdMenu *)menu
{
	if(![menu isKindOfClass:[SPIdMenu class]]) return;
	//NOTE: NSTableView will usually copy the menu and call this method on the copy. Matching with == won't work!

	//walk through the menu and clear the attributedTitle if set. This will remove the gray color from the default items
	for(NSMenuItem *item in [menu itemArray]) {
		if([item attributedTitle]) {
			[item setAttributedTitle:nil];
		}
	}

	NSDictionary *rowData = NSArrayObjectAtIndex(tableFields, [tableSourceView selectedRow]);

	if([[menu menuId] isEqualToString:@"encodingPopupMenu"]) {
		NSString *tableEncoding = [tableDataInstance tableEncoding];
		//NSString *databaseEncoding = [databaseDataInstance getDatabaseDefaultCharacterSet];
		//NSString *serverEncoding = [databaseDataInstance getServerDefaultCharacterSet];

		struct _cmpMap defaultCmp[] = {
			{
				NSLocalizedString(@"Table",@"Table Structure : Encoding dropdown : 'item is table default' marker"),
				[NSString stringWithFormat:NSLocalizedString(@"This is the default encoding of table “%@”.", @"Table Structure : Encoding dropdown : table marker tooltip"),selectedTable],
				tableEncoding
			},
			/* //we could, but that might confuse users even more plus there is no inheritance between a columns charset and the db/server default
			 {
			 NSLocalizedString(@"Database",@"Table Structure : Encoding dropdown : 'item is database default' marker"),
			 [NSString stringWithFormat:NSLocalizedString(@"This is the default encoding of database “%@”.", @"Table Structure : Encoding dropdown : database marker tooltip"),[tableDocumentInstance database]],
			 databaseEncoding
			 },
			 {
			 NSLocalizedString(@"Server",@"Table Structure : Encoding dropdown : 'item is server default' marker"),
			 NSLocalizedString(@"This is the default encoding of this server.", @"Table Structure : Encoding dropdown : server marker tooltip"),
			 serverEncoding
			 } */
		};

		_BuildMenuWithPills(menu, defaultCmp, COUNT_OF(defaultCmp));
	}
	else if([[menu menuId] isEqualToString:@"collationPopupMenu"]) {
		NSString *encoding = [rowData objectForKey:@"encodingName"];
		NSString *encodingDefaultCollation = [databaseDataInstance getDefaultCollationForEncoding:encoding];
		NSString *tableCollation = [tableDataInstance statusValueForKey:@"Collation"];
		//NSString *databaseCollation = [databaseDataInstance getDatabaseDefaultCollation];
		//NSString *serverCollation = [databaseDataInstance getServerDefaultCollation];

		struct _cmpMap defaultCmp[] = {
			{
				NSLocalizedString(@"Default",@"Table Structure : Collation dropdown : 'item is the same as the default collation of the row's charset' marker"),
				[NSString stringWithFormat:NSLocalizedString(@"This is the default collation of encoding “%@”.", @"Table Structure : Collation dropdown : default marker tooltip"),encoding],
				encodingDefaultCollation
			},
			{
				NSLocalizedString(@"Table",@"Table Structure : Collation dropdown : 'item is the same as the collation of table' marker"),
				[NSString stringWithFormat:NSLocalizedString(@"This is the default collation of table “%@”.", @"Table Structure : Collation dropdown : table marker tooltip"),selectedTable],
				tableCollation
			},
			/* // see the comment for charset above
			 {
			 NSLocalizedString(@"Database",@"Table Structure : Collation dropdown : 'item is the same as the collation of database' marker"),
			 [NSString stringWithFormat:NSLocalizedString(@"This is the default collation of database “%@”.", @"Table Structure : Collation dropdown : database marker tooltip"),[tableDocumentInstance database]],
			 databaseCollation
			 },
			 {
			 NSLocalizedString(@"Server",@"Table Structure : Collation dropdown : 'item is the same as the collation of server' marker"),
			 NSLocalizedString(@"This is the default collation of this server.", @"Table Structure : Collation dropdown : server marker tooltip"),
			 serverCollation
			 } */
		};

		_BuildMenuWithPills(menu, defaultCmp, COUNT_OF(defaultCmp));
	}
}

#pragma mark -

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	SPClear(tableFields);
	SPClear(oldRow);
	SPClear(enumFields);
	SPClear(typeSuggestions);
	SPClear(extraFieldSuggestions);

	SPClear(fieldValidation);

	if (defaultValues) SPClear(defaultValues);
	if (selectedTable) SPClear(selectedTable);

	[super dealloc];
}

+ (SPFieldTypeHelp *)helpForFieldType:(NSString *)typeName
{
	static dispatch_once_t token;
	static NSArray *list;
	dispatch_once(&token, ^{
		// NSString *FN(NSNumber *): format a number using the user locale (to make large numbers more legible)
#define FN(x) [NSNumberFormatter localizedStringFromNumber:x numberStyle:NSNumberFormatterDecimalStyle]
		NSString *intRangeTpl = NSLocalizedString(@"Signed: %@ to %@\nUnsigned: %@ to %@",@"range of integer types");
		// NSString *INTR(NSNumber *sMin, NSNumber *sMax, NSNumber *uMin, NSNumber *uMax): return formatted string for integer types (signed min/max, unsigned min/max)
#define INTR(sMin,sMax,uMin,uMax) [NSString stringWithFormat:intRangeTpl,FN(sMin),FN(sMax),FN(uMin),FN(uMax)]
		list = [@[
			MakeFieldTypeHelp(
				SPMySQLTinyIntType,
				@"TINYINT[(M)] [UNSIGNED] [ZEROFILL]",
				INTR(@(-128),@127,@0,@255),
				NSLocalizedString(@"The smallest integer type, requires 1 byte storage space. M is the optional display width and does not affect the possible value range.",@"description of tinyint")
			),
			MakeFieldTypeHelp(
				SPMySQLSmallIntType,
				@"SMALLINT[(M)] [UNSIGNED] [ZEROFILL]",
				INTR(@(-32768), @32767, @0, @65535),
				NSLocalizedString(@"Requires 2 bytes storage space. M is the optional display width and does not affect the possible value range.",@"description of smallint")
			),
			MakeFieldTypeHelp(
				SPMySQLMediumIntType,
				@"MEDIUMINT[(M)] [UNSIGNED] [ZEROFILL]",
				INTR(@(-8388608), @8388607, @0, @16777215),
				NSLocalizedString(@"Requires 3 bytes storage space. M is the optional display width and does not affect the possible value range.",@"description of mediumint")
			),
			MakeFieldTypeHelp(
				SPMySQLIntType,
				@"INT[(M)] [UNSIGNED] [ZEROFILL]",
				INTR(@(-2147483648), @2147483647, @0, @4294967295),
				NSLocalizedString(@"Requires 4 bytes storage space. M is the optional display width and does not affect the possible value range. INTEGER is an alias to this type.",@"description of int")
			),
			MakeFieldTypeHelp(
				SPMySQLBigIntType,
				@"BIGINT[(M)] [UNSIGNED] [ZEROFILL]",
				INTR([NSDecimalNumber decimalNumberWithString:@"-9223372036854775808"], [NSDecimalNumber decimalNumberWithString:@"9223372036854775807"], @0, [NSDecimalNumber decimalNumberWithString:@"18446744073709551615"]),
				NSLocalizedString(@"Requires 8 bytes storage space. M is the optional display width and does not affect the possible value range. Note: Arithmetic operations might fail for large numbers.",@"description of bigint")
			),
			MakeFieldTypeHelp(
				SPMySQLFloatType,
				@"FLOAT[(M,D)] [UNSIGNED] [ZEROFILL]",
				NSLocalizedString(@"Accurate to approx. 7 decimal places", @"range of float"),
				NSLocalizedString(@"IEEE 754 single-precision floating-point value. M is the maxium number of digits, of which D may be after the decimal point. Note: Many decimal numbers can only be approximated by floating-point values. See DECIMAL if you require exact results.",@"description of float")
			),
			MakeFieldTypeHelp(
				SPMySQLDoubleType,
				@"DOUBLE[(M,D)] [UNSIGNED] [ZEROFILL]",
				NSLocalizedString(@"Accurate to approx. 15 decimal places", @"range of double"),
				NSLocalizedString(@"IEEE 754 double-precision floating-point value. M is the maxium number of digits, of which D may be after the decimal point. Note: Many decimal numbers can only be approximated by floating-point values. See DECIMAL if you require exact results.",@"description of double")
			),
			MakeFieldTypeHelp(
				SPMySQLDoublePrecisionType,
				@"DOUBLE PRECISION[(M,D)] [UNSIGNED] [ZEROFILL]",
				@"",
				NSLocalizedString(@"This is an alias for DOUBLE.",@"description of double precision")
			),
			MakeFieldTypeHelp(
				SPMySQLRealType,
				@"REAL[(M,D)] [UNSIGNED] [ZEROFILL]",
				@"",
				NSLocalizedString(@"This is an alias for DOUBLE, unless REAL_AS_FLOAT is configured.",@"description of double real")
			),
			MakeFieldTypeHelp(
				SPMySQLDecimalType,
				@"DECIMAL[(M[,D])] [UNSIGNED] [ZEROFILL]",
				NSLocalizedString(@"M (precision): Up to 65 digits\nD (scale): 0 to 30 digits", @"range of decimal"),
				NSLocalizedString(@"A fixed-point, exact decimal value. M is the maxium number of digits, of which D may be after the decimal point. When rounding, 0-4 is always rounded down, 5-9 up (“round towards nearest”).",@"description of decimal")
			),
			MakeFieldTypeHelp(
				SPMySQLSerialType,
				@"SERIAL",
				[NSString stringWithFormat:NSLocalizedString(@"Range: %@ to %@", @"range for serial type"),FN(@0),FN([NSDecimalNumber decimalNumberWithString:@"18446744073709551615"])],
				NSLocalizedString(@"This is an alias for BIGINT UNSIGNED NOT NULL AUTO_INCREMENT UNIQUE.",@"description of serial")
			),
			MakeFieldTypeHelp(
				SPMySQLBitType,
				@"BIT[(M)]",
				NSLocalizedString(@"M: 1 (default) to 64", @"range for bit type"),
				NSLocalizedString(@"A bit-field type. M specifies the number of bits. If shorter values are inserted, they will be aligned on the least significant bit. See the SET type if you want to explicitly name each bit.",@"description of bit")
			),
			MakeFieldTypeHelp(
				SPMySQLBoolType,
				@"BOOL",
				@"",
				NSLocalizedString(@"This is an alias for TINYINT(1).",@"description of bool")
			),
			MakeFieldTypeHelp(
				SPMySQLBoolean,
				@"BOOLEAN",
				@"",
				NSLocalizedString(@"This is an alias for TINYINT(1).",@"description of boolean")
			),
			MakeFieldTypeHelp(
				SPMySQLDecType,
				@"DEC[(M[,D])] [UNSIGNED] [ZEROFILL]",
				@"",
				NSLocalizedString(@"This is an alias for DECIMAL.",@"description of dec")
			),
			MakeFieldTypeHelp(
				SPMySQLFixedType,
				@"FIXED[(M[,D])] [UNSIGNED] [ZEROFILL]",
				@"",
				NSLocalizedString(@"This is an alias for DECIMAL.",@"description of fixed")
			),
			MakeFieldTypeHelp(
				SPMySQLNumericType,
				@"NUMERIC[(M[,D])] [UNSIGNED] [ZEROFILL]",
				@"",
				NSLocalizedString(@"This is an alias for DECIMAL.",@"description of numeric")
			),
			// ----------------------------------------------------------------------------------
			MakeFieldTypeHelp(
				SPMySQLCharType,
				@"CHAR(M)",
				NSLocalizedString(@"M: 0 to 255 characters", @"range for char type"),
				NSLocalizedString(@"A character string that will require M×w bytes per row, independent of the actual content length. w is the maximum number of bytes a single character can occupy in the given encoding.",@"description of char")
			),
			MakeFieldTypeHelp(
				SPMySQLVarCharType,
				@"VARCHAR(M)",
				[NSString stringWithFormat:NSLocalizedString(@"M: %@ to %@ characters", @"range for varchar type"),FN(@0),FN(@(65535))],
				NSLocalizedString(@"A character string that can store up to M bytes, but requires less space for shorter values. The actual number of characters is further limited by the used encoding and the values of other fields in the row.",@"description of varchar")
			),
			MakeFieldTypeHelp(
				SPMySQLTinyTextType,
				@"TINYTEXT",
				NSLocalizedString(@"Up to 255 characters", @"range for tinytext type"),
				NSLocalizedString(@"A character string that can store up to 255 bytes, but requires less space for shorter values. The actual number of characters is further limited by the used encoding. Unlike VARCHAR this type does not count towards the maximum row length.",@"description of tinytext")
			),
			MakeFieldTypeHelp(
				SPMySQLTextType,
				@"TEXT[(M)]",
				[NSString stringWithFormat:NSLocalizedString(@"M: %@ to %@ characters", @"range for text type"),FN(@0),FN(@(65535))],
				NSLocalizedString(@"A character string that can store up to M bytes, but requires less space for shorter values. The actual number of characters is further limited by the used encoding. Unlike VARCHAR this type does not count towards the maximum row length.",@"description of text")
			),
			MakeFieldTypeHelp(
				SPMySQLMediumTextType,
				@"MEDIUMTEXT",
				[NSString stringWithFormat:NSLocalizedString(@"Up to %@ characters (16 MiB)", @"range for mediumtext type"),FN(@16777215)],
				NSLocalizedString(@"A character string with variable length. The actual number of characters is further limited by the used encoding. Unlike VARCHAR this type does not count towards the maximum row length.",@"description of mediumtext")
			),
			MakeFieldTypeHelp(
				SPMySQLLongTextType,
				@"LONGTEXT",
				[NSString stringWithFormat:NSLocalizedString(@"M: %@ to %@ characters (4 GiB)", @"range for longtext type"),FN(@0),FN(@4294967295)],
				NSLocalizedString(@"A character string with variable length. The actual number of characters is further limited by the used encoding. Unlike VARCHAR this type does not count towards the maximum row length.",@"description of longtext")
			),
			MakeFieldTypeHelp(
				SPMySQLTinyBlobType,
				@"TINYBLOB",
				NSLocalizedString(@"Up to 255 bytes", @"range for tinyblob type"),
				NSLocalizedString(@"A byte array with variable length. Unlike VARBINARY this type does not count towards the maximum row length.",@"description of tinyblob")
			),
			MakeFieldTypeHelp(
				SPMySQLMediumBlobType,
				@"MEDIUMBLOB",
				[NSString stringWithFormat:NSLocalizedString(@"Up to %@ bytes (16 MiB)", @"range for mediumblob type"),FN(@16777215)],
				NSLocalizedString(@"A byte array with variable length. Unlike VARBINARY this type does not count towards the maximum row length.",@"description of mediumblob")
			),
			MakeFieldTypeHelp(
				SPMySQLBlobType,
				@"BLOB[(M)]",
				[NSString stringWithFormat:NSLocalizedString(@"M: %@ to %@ bytes", @"range for blob type"),FN(@0),FN(@65535)],
				NSLocalizedString(@"A byte array with variable length. Unlike VARBINARY this type does not count towards the maximum row length.",@"description of blob")
			),
			MakeFieldTypeHelp(
				SPMySQLLongBlobType,
				@"LONGBLOB",
				[NSString stringWithFormat:NSLocalizedString(@"Up to %@ bytes (4 GiB)", @"range for longblob type"),FN(@4294967295)],
				NSLocalizedString(@"A byte array with variable length. Unlike VARBINARY this type does not count towards the maximum row length.",@"description of longblob")
			),
			MakeFieldTypeHelp(
				SPMySQLBinaryType,
				@"BINARY(M)",
				NSLocalizedString(@"M: 0 to 255 bytes", @"range for binary type"),
				NSLocalizedString(@"A byte array with fixed length. Shorter values will always be padded to the right with 0x00 until they fit M.",@"description of binary")
			),
			MakeFieldTypeHelp(
				SPMySQLVarBinaryType,
				@"VARBINARY(M)",
				[NSString stringWithFormat:NSLocalizedString(@"M: %@ to %@ bytes", @"range for varbinary type"),FN(@0),FN(@(65535))],
				NSLocalizedString(@"A byte array with variable length. The actual number of bytes is further limited by the values of other fields in the row.",@"description of varbinary")
			),
			MakeFieldTypeHelp(
				SPMySQLJsonType,
				@"JSON",
				NSLocalizedString(@"Limited to @@max_allowed_packet", @"range for json type"),
				NSLocalizedString(@"A data type that validates JSON data on INSERT and internally stores it in a binary format that is both, more compact and faster to access than textual JSON.\nAvailable from MySQL 5.7.8.", @"description of json")
			),
			MakeFieldTypeHelp(
				SPMySQLEnumType,
				@"ENUM('member',...)",
				[NSString stringWithFormat:NSLocalizedString(@"Up to %@ distinct members (<%@ in practice)\n1-2 bytes storage", @"range for enum type"),FN(@(65535)),FN(@3000)],
				NSLocalizedString(@"Defines a list of members, of which every field can use at most one. Values are sorted by their index number (starting at 0 for the first member).",@"description of enum")
			),
			MakeFieldTypeHelp(
				SPMySQLSetType,
				@"SET('member',...)",
				NSLocalizedString(@"Range: 1 to 64 members\n1, 2, 3, 4 or 8 bytes storage", @"range for set type"),
				NSLocalizedString(@"A SET can define up to 64 members (as strings) of which a field can use one or more using a comma-separated list. Upon insertion the order of members is automatically normalized and duplicate members will be eliminated. Assignment of numbers is supported using the same semantics as for BIT types.",@"description of set")
			),
			// --------------------------------------------------------------------------
			MakeFieldTypeHelp(
				SPMySQLDateType,
				@"DATE",
				NSLocalizedString(@"Range: 1000-01-01 to 9999-12-31", @"range for date type"),
				NSLocalizedString(@"Stores a date without time information. The representation is YYYY-MM-DD. The value is not affected by any time zone setting. Invalid values are converted to 0000-00-00.",@"description of date")
			),
			MakeFieldTypeHelp(
				SPMySQLDatetimeType,
				@"DATETIME[(F)]",
				NSLocalizedString(@"Range: 1000-01-01 00:00:00.0 to 9999-12-31 23:59:59.999999\nF (precision): 0 (1s) to 6 (1µs)", @"range for datetime type"),
				NSLocalizedString(@"Stores a date and time of day. The representation is YYYY-MM-DD HH:MM:SS[.I*], I being fractional seconds. The value is not affected by any time zone setting. Invalid values are converted to 0000-00-00 00:00:00.0. Fractional seconds were added in MySQL 5.6.4 with a precision down to microseconds (6), specified by F.",@"description of datetime")
			),
			MakeFieldTypeHelp(
				SPMySQLTimestampType,
				@"TIMETSTAMP[(F)]",
				NSLocalizedString(@"Range: 1970-01-01 00:00:01.0 to 2038-01-19 03:14:07.999999\nF (precision): 0 (1s) to 6 (1µs)", @"range for timestamp type"),
				NSLocalizedString(@"Stores a date and time of day as seconds since the beginning of the UNIX epoch (1970-01-01 00:00:00). The values displayed/stored are affected by the connection's @@time_zone setting.\nThe representation is the same as for DATETIME. Invalid values, as well as \"second zero\", are converted to 0000-00-00 00:00:00.0. Fractional seconds were added in MySQL 5.6.4 with a precision down to microseconds (6), specified by F. Some additional rules may apply.",@"description of timestamp")
			),
			MakeFieldTypeHelp(
				SPMySQLTimeType,
				@"TIME[(F)]",
				NSLocalizedString(@"Range: -838:59:59.0 to 838:59:59.0\nF (precision): 0 (1s) to 6 (1µs)", @"range for time type"),
				NSLocalizedString(@"Stores a time of day, duration or time interval. The representation is HH:MM:SS[.I*], I being fractional seconds. The value is not affected by any time zone setting. Invalid values are converted to 00:00:00. Fractional seconds were added in MySQL 5.6.4 with a precision down to microseconds (6), specified by F.",@"description of time")
			),
			MakeFieldTypeHelp(
				SPMySQLYearType,
				@"YEAR(4)",
				NSLocalizedString(@"Range: 0000, 1901 to 2155", @"range for year type"),
				NSLocalizedString(@"Represents a 4 digit year value, stored as 1 byte. Invalid values are converted to 0000 and two digit values 0 to 69 will be converted to years 2000 to 2069, resp. values 70 to 99 to years 1970 to 1999.\nThe YEAR(2) type was removed in MySQL 5.7.5.",@"description of year")
			),
			// --------------------------------------------------------------------------
			MakeFieldTypeHelp(
				SPMySQLGeometryType,
				@"GEOMETRY",
				@"",
				NSLocalizedString(@"Can store a single spatial value of types POINT, LINESTRING or POLYGON. Spatial support in MySQL is based on the OpenGIS Geometry Model.",@"description of geometry")
			),
			MakeFieldTypeHelp(
				SPMySQLPointType,
				@"POINT",
				@"",
				NSLocalizedString(@"Represents a single location in coordinate space using X and Y coordinates. The point is zero-dimensional.",@"description of point")
			),
			MakeFieldTypeHelp(
				SPMySQLLineStringType,
				@"LINESTRING",
				@"",
				NSLocalizedString(@"Represents an ordered set of coordinates where each consecutive pair of two points is connected by a straight line.",@"description of linestring")
			),
			MakeFieldTypeHelp(
				SPMySQLPolygonType,
				@"POLYGON",
				@"",
				NSLocalizedString(@"Creates a surface by combining one LinearRing (ie. a LineString that is closed and simple) as the outside boundary with zero or more inner LinearRings acting as \"holes\".",@"description of polygon")
			),
			MakeFieldTypeHelp(
				SPMySQLMultiPointType,
				@"MULTIPOINT",
				@"",
				NSLocalizedString(@"Represents a set of Points without specifying any kind of relation and/or order between them.",@"description of multipoint")
			),
			MakeFieldTypeHelp(
				SPMySQLMultiLineStringType,
				@"MULTILINESTRING",
				@"",
				NSLocalizedString(@"Represents a collection of LineStrings.",@"description of multilinestring")
			),
			MakeFieldTypeHelp(
				SPMySQLMultiPolygonType,
				@"MULTIPOLYGON",
				@"",
				NSLocalizedString(@"Represents a collection of Polygons. The Polygons making up the MultiPolygon must not intersect.",@"description of multipolygon")
			),
			MakeFieldTypeHelp(
				SPMySQLGeometryCollectionType,
				@"GEOMETRYCOLLECTION",
				@"",
				NSLocalizedString(@"Represents a collection of objects of any other single- or multi-valued spatial type. The only restriction being, that all objects must share a common coordinate system.",@"description of geometrycollection")
			),
		] retain];
#undef FN
#undef INTR
	});

	for (SPFieldTypeHelp *item in list) {
		if ([[item typeName] isEqualToString:typeName]) {
			return item;
		}
	}
	
	return nil;
}

@end

#pragma mark -

void _BuildMenuWithPills(NSMenu *menu, struct _cmpMap *map, size_t mapEntries)
{
	NSDictionary *baseAttrs = @{NSFontAttributeName: [menu font], NSParagraphStyleAttributeName: [NSParagraphStyle defaultParagraphStyle]};

	for (NSMenuItem *item in [menu itemArray])
	{
		NSMutableAttributedString *itemStr = [[NSMutableAttributedString alloc] initWithString:[item title] attributes:baseAttrs];
		NSString *value = [item representedObject];

		NSMutableArray *tooltipParts = [NSMutableArray array];

		for (unsigned int i = 0; i < mapEntries; ++i)
		{
			struct _cmpMap *cmp = &map[i];

			if ([cmp->cmpWith isEqualToString:value]) {

				SPPillAttachmentCell *cell = [[SPPillAttachmentCell alloc] init];

				[cell setStringValue:cmp->title];

				NSTextAttachment *attachment = [[NSTextAttachment alloc] init];

				[attachment setAttachmentCell:[cell autorelease]];

				NSAttributedString *attachmentString = [NSAttributedString attributedStringWithAttachment:[attachment autorelease]];

				[[itemStr mutableString] appendString:@" "];
				[itemStr appendAttributedString:attachmentString];

				if (cmp->tooltipPart) {
					[tooltipParts addObject:cmp->tooltipPart];
				}
			}
		}

		if ([tooltipParts count]) {
			[item setToolTip:[tooltipParts componentsJoinedByString:@" "]];
		}

		[item setAttributedTitle:[itemStr autorelease]];
	}
}
