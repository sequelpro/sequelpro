//
//  SPBundleEditorController.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on November 12, 2010.
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

#import "SPBundleEditorController.h"
#import "SPBundleCommandRunner.h"
#import "SPOutlineView.h"
#import "SPBundleCommandTextView.h"
#import "SPSplitView.h"
#import "SPAppController.h"

#define kBundleNameKey @"bundleName"
#define kChildrenKey @"_children_"
#define kInputFieldScopeArrayIndex 0
#define kDataTableScopeArrayIndex 1
#define kGeneralScopeArrayIndex 2
#define kDisabledScopeTag 10

#define SP_BUNDLEEDITOR_SCOPE_INPUTFIELD_STRING       NSLocalizedString(@"Input Field", @"Bundle Editor : Scope dropdown : 'input field' item")
#define SP_BUNDLEEDITOR_SCOPE_DATATABLE_STRING        NSLocalizedString(@"Data Table", @"Bundle Editor : Scope dropdown : 'data table' item")
#define SP_BUNDLEEDITOR_SCOPE_GENERAL_STRING          NSLocalizedString(@"General", @"Bundle Editor : Scope dropdown : 'general' item")
#define SP_BUNDLEEDITOR_OUTLINE_BUNDLE_TOOLTIP_STRING NSLocalizedString(@"“%@” Bundle",@"Bundle Editor : Outline View : Bundle item : tooltip")

#define SP_BUNDLEEDITOR_SPLITVIEW_AUTOSAVE_STRING     @"SPBundleEditorSplitView"

@interface SPBundleEditorController ()

- (void)_updateBundleDataView;
- (void)_updateBundleMetaSummary;
- (id)_currentSelectedObject;
- (id)_currentSelectedNode;
- (void)_enableBundleDataInput:(BOOL)enabled bundleEnabled:(BOOL)bundleEnabled;
- (void)_initTree;
- (NSUInteger)_arrangedScopeIndexForScopeIndex:(NSUInteger)scopeIndex;
- (NSUInteger)_scopeIndexForArrangedScopeIndex:(NSUInteger)scopeIndex;
- (NSUInteger)_arrangedCategoryIndexForScopeIndex:(NSUInteger)scopeIndex andCategory:(NSString*)category;
- (void)_metaSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

@end

#pragma mark -

@implementation SPBundleEditorController

- (id)init
{

	if ((self = [super initWithWindowNibName:@"BundleEditor"])) {
		touchedBundleArray = nil;
		draggedFilePath = nil;
		oldBundleName = nil;
		isTableCellEditing = NO;
		deletedDefaultBundles = [[NSMutableArray alloc] initWithCapacity:1];
	}
	
	return self;
}

- (void)awakeFromNib
{

	// Set the splitview up
	[splitView setMinSize:122.f ofSubviewAtIndex:0];
	[splitView setMinSize:588.f ofSubviewAtIndex:1];

	// Set up the shortcut recorder control
	[keyEquivalentField setAnimates:YES];
	[keyEquivalentField setStyle:SRGreyStyle];
	[keyEquivalentField setAllowedFlags:ShortcutRecorderAllFlags];
	[keyEquivalentField setRequiredFlags:ShortcutRecorderEmptyFlags];
	[keyEquivalentField setAllowsKeyOnly:NO escapeKeysRecord:NO];

	// Init all needed variables; popup menus (with the chance for localization); and set
	// defaults

	bundlePath = [[[NSFileManager defaultManager] applicationSupportDirectoryForSubDirectory:SPBundleSupportFolder createIfNotExists:NO error:nil] retain];


	touchedBundleArray = [[NSMutableArray alloc] initWithCapacity:1];
	commandBundleTree = [[NSMutableDictionary alloc] initWithCapacity:1];
	sortDescriptor = [[NSSortDescriptor alloc] initWithKey:kBundleNameKey ascending:YES selector:@selector(localizedCompare:)];

	[commandBundleTree setObject:[NSMutableArray array] forKey:kChildrenKey];
	[commandBundleTree setObject:NSLocalizedString(@"BUNDLES",@"Bundle Editor : Outline View : 'BUNDLES' item") forKey:kBundleNameKey];
	[[commandBundleTree objectForKey:kChildrenKey] addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSMutableArray array], kChildrenKey, SP_BUNDLEEDITOR_SCOPE_INPUTFIELD_STRING, kBundleNameKey, nil]];
	[[commandBundleTree objectForKey:kChildrenKey] addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSMutableArray array], kChildrenKey, SP_BUNDLEEDITOR_SCOPE_DATATABLE_STRING, kBundleNameKey, nil]];
	[[commandBundleTree objectForKey:kChildrenKey] addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSMutableArray array], kChildrenKey, SP_BUNDLEEDITOR_SCOPE_GENERAL_STRING, kBundleNameKey, nil]];
	[commandBundleTreeController setContent:commandBundleTree];

	// Init all needed menus
	inputGeneralScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	inputInputFieldScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	inputDataTableScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	outputGeneralScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	outputInputFieldScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	outputDataTableScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	inputFallbackInputFieldScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	triggerInputFieldPopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	triggerDataTablePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	triggerGeneralPopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	withBlobDataTablePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	inputNonePopUpMenu = [[NSMenu alloc] initWithTitle:@""];

	inputGeneralScopeArray = [@[SPBundleInputSourceNone] retain];
	inputInputFieldScopeArray = [@[SPBundleInputSourceNone, SPBundleInputSourceSelectedText, SPBundleInputSourceEntireContent] retain];
	inputDataTableScopeArray = [@[SPBundleInputSourceNone, SPBundleInputSourceSelectedTableRowsAsTab, SPBundleInputSourceSelectedTableRowsAsCsv, SPBundleInputSourceSelectedTableRowsAsSqlInsert, SPBundleInputSourceTableRowsAsTab, SPBundleInputSourceTableRowsAsCsv, SPBundleInputSourceTableRowsAsSqlInsert] retain];
	outputInputFieldScopeArray = [@[SPBundleOutputActionNone, SPBundleOutputActionInsertAsText, SPBundleOutputActionInsertAsSnippet, SPBundleOutputActionReplaceSelection, SPBundleOutputActionReplaceContent, SPBundleOutputActionShowAsTextTooltip, SPBundleOutputActionShowAsHTMLTooltip, SPBundleOutputActionShowAsHTML] retain];
	outputGeneralScopeArray = [@[SPBundleOutputActionNone, SPBundleOutputActionShowAsTextTooltip, SPBundleOutputActionShowAsHTMLTooltip, SPBundleOutputActionShowAsHTML] retain];
	outputDataTableScopeArray = [@[SPBundleOutputActionNone, SPBundleOutputActionShowAsTextTooltip, SPBundleOutputActionShowAsHTMLTooltip, SPBundleOutputActionShowAsHTML] retain];
	inputFallbackInputFieldScopeArray = [@[SPBundleInputSourceNone, SPBundleInputSourceCurrentWord, SPBundleInputSourceCurrentLine, SPBundleInputSourceCurrentQuery, SPBundleInputSourceEntireContent] retain];
	triggerInputFieldArray = [@[SPBundleTriggerActionNone] retain];
	triggerDataTableArray = [@[SPBundleTriggerActionNone, SPBundleTriggerActionDatabaseChanged, SPBundleTriggerActionTableChanged, SPBundleTriggerActionTableRowChanged] retain];
	triggerGeneralArray = [@[SPBundleTriggerActionNone, SPBundleTriggerActionDatabaseChanged, SPBundleTriggerActionTableChanged] retain];
	withBlobDataTableArray = [@[SPBundleInputSourceBlobHandlingExclude, SPBundleInputSourceBlobHandlingInclude, SPBundleInputSourceBlobHandlingImageFileReference, SPBundleInputSourceBlobHandlingFileReference] retain];
	NSArray *inputNoneArray = @[SPBundleInputSourceNone]; //we only need that once to construct the menu

	NSMutableArray *allPopupScopeItems = [NSMutableArray array];
	[allPopupScopeItems addObjectsFromArray:inputGeneralScopeArray];
	[allPopupScopeItems addObjectsFromArray:inputInputFieldScopeArray];
	[allPopupScopeItems addObjectsFromArray:inputDataTableScopeArray];
	[allPopupScopeItems addObjectsFromArray:outputInputFieldScopeArray];
	[allPopupScopeItems addObjectsFromArray:outputGeneralScopeArray];
	[allPopupScopeItems addObjectsFromArray:outputDataTableScopeArray];
	[allPopupScopeItems addObjectsFromArray:inputFallbackInputFieldScopeArray];
	[allPopupScopeItems addObjectsFromArray:triggerInputFieldArray];
	[allPopupScopeItems addObjectsFromArray:triggerDataTableArray];
	[allPopupScopeItems addObjectsFromArray:triggerGeneralArray];
	[allPopupScopeItems addObjectsFromArray:withBlobDataTableArray];
	[allPopupScopeItems addObjectsFromArray:inputNoneArray];

	NSDictionary *menuItemTitles = [NSDictionary dictionaryWithObjects:@[
					NSLocalizedString(@"None", @"Bundle Editor : Scope=General : Input source dropdown: 'None' item"),

					NSLocalizedString(@"None", @"Bundle Editor : Scope=Field : Input source dropdown: 'None' item"),
					NSLocalizedString(@"Selected Text", @"Bundle Editor : Scope=Field : Input source dropdown: 'selected text' item"),
					NSLocalizedString(@"Entire Content", @"Bundle Editor : Scope=Field : Input source dropdown: 'entire content' item"),

					NSLocalizedString(@"None", @"Bundle Editor : Scope=Data-Table : Input source dropdown: 'none' item"),
					NSLocalizedString(@"Selected Rows (TSV)", @"Bundle Editor : Scope=Data-Table : Input source dropdown: 'selected rows as tab-separated' item"),
					NSLocalizedString(@"Selected Rows (CSV)", @"Bundle Editor : Scope=Data-Table : Input source dropdown: 'selected rows as comma-separated' item"),
					NSLocalizedString(@"Selected Rows (SQL)", @"Bundle Editor : Scope=Data-Table : Input source dropdown: 'selected rows as SQL' item"),
					NSLocalizedString(@"Table Content (TSV)", @"Bundle Editor : Scope=Data-Table : Input source dropdown: 'table content as tab-separated' item"),
					NSLocalizedString(@"Table Content (CSV)", @"Bundle Editor : Scope=Data-Table : Input source dropdown: 'table content as comma-separated' item"),
					NSLocalizedString(@"Table Content (SQL)", @"Bundle Editor : Scope=Data-Table : Input source dropdown: 'table content as SQL' item"),

					NSLocalizedString(@"None", @"Bundle Editor : Scope=Field : Output dropdown : 'none' item"),
					NSLocalizedString(@"Insert as Text", @"Bundle Editor : Scope=Field : Output dropdown : 'insert as text' item"),
					NSLocalizedString(@"Insert as Snippet", @"Bundle Editor : Scope=Field : Output dropdown : 'insert as snippet' item"),
					NSLocalizedString(@"Replace Selection", @"Bundle Editor : Scope=Field : Output dropdown : 'replace selection' item"),
					NSLocalizedString(@"Replace Entire Content", @"Bundle Editor : Scope=Field : Output dropdown : 'replace entire content' item"),
					NSLocalizedString(@"Show as Text Tooltip", @"Bundle Editor : Scope=Field : Output dropdown : 'show as text tooltip' item"),
					NSLocalizedString(@"Show as HTML Tooltip", @"Bundle Editor : Scope=Field : Output dropdown : 'show as html tooltip' item"),
					NSLocalizedString(@"Show as HTML", @"Bundle Editor : Scope=Field : Output dropdown : 'show as html' item"),

					NSLocalizedString(@"None", @"Bundle Editor : Scope=General : Output dropdown : 'none' item"),
					NSLocalizedString(@"Show as Text Tooltip", @"Bundle Editor : Scope=General : Output dropdown : 'show as text tooltip' item"),
					NSLocalizedString(@"Show as HTML Tooltip", @"Bundle Editor : Scope=General : Output dropdown : 'show as html tooltip' item"),
					NSLocalizedString(@"Show as HTML", @"Bundle Editor : Scope=General : Output dropdown : 'show as html' item"),

					NSLocalizedString(@"None", @"Bundle Editor : Scope=Data-Table : Output dropdown : 'none' item"),
					NSLocalizedString(@"Show as Text Tooltip", @"Bundle Editor : Scope=Data-Table : Output dropdown : 'show as text tooltip' item"),
					NSLocalizedString(@"Show as HTML Tooltip", @"Bundle Editor : Scope=Data-Table : Output dropdown : 'show as html tooltip' item"),
					NSLocalizedString(@"Show as HTML", @"Bundle Editor : Scope=Data-Table : Output dropdown : 'show as html' item"),

					NSLocalizedString(@"None", @"Bundle Editor : Fallback Input source dropdown : 'none' item"),
					NSLocalizedString(@"Current Word", @"Bundle Editor : Fallback Input source dropdown : 'current word' item"),
					NSLocalizedString(@"Current Line", @"Bundle Editor : Fallback Input source dropdown : 'current line' item"),
					NSLocalizedString(@"Current Query", @"Bundle Editor : Fallback Input source dropdown : 'current query' item"),
					NSLocalizedString(@"Entire Content", @"Bundle Editor : Fallback Input source dropdown : 'entire content' item"),

					NSLocalizedString(@"None", @"Bundle Editor : Scope=Field : Trigger dropdown : 'none' item"),

					NSLocalizedString(@"None", @"Bundle Editor : Scope=Data-Table : Trigger dropdown : 'none' item"),
					NSLocalizedString(@"Database changed", @"Bundle Editor : Scope=Data-Table : Trigger dropdown : 'database changed' item"),
					NSLocalizedString(@"Table changed", @"Bundle Editor : Scope=Data-Table : Trigger dropdown : 'table changed' item"),
					NSLocalizedString(@"Table Row changed", @"Bundle Editor : Scope=Data-Table : Trigger dropdown : 'table row changed' item"),

					NSLocalizedString(@"None", @"Bundle Editor : Scope=General : Trigger dropdown : 'none' item"),
					NSLocalizedString(@"Database changed", @"Bundle Editor : Scope=General : Trigger dropdown : 'database changed' item"),
					NSLocalizedString(@"Table changed", @"Bundle Editor : Scope=General : Trigger dropdown : 'table changed' item"),

					NSLocalizedString(@"exclude BLOB", @"Bundle Editor : BLOB dropdown : 'exclude BLOB' item"),
					NSLocalizedString(@"include BLOB", @"Bundle Editor : BLOB dropdown : 'include BLOB' item"),
					NSLocalizedString(@"save BLOB as image file", @"Bundle Editor : BLOB dropdown : 'save BLOB as image file' item"),
					NSLocalizedString(@"save BLOB as dat file", @"Bundle Editor : BLOB dropdown : 'save BLOB as dat file' item"),

					NSLocalizedString(@"None", @"Bundle Editor : Scope=? : ? dropdown: 'None' item")
			] forKeys:allPopupScopeItems];

	struct _menuItemMap {
		NSArray *items;
		NSMenu *menu;
		SEL action;
	};

	struct _menuItemMap menus[] = {
			{inputGeneralScopeArray,            inputGeneralScopePopUpMenu,            @selector(inputPopupButtonChanged:)},
			{inputInputFieldScopeArray,         inputInputFieldScopePopUpMenu,         @selector(inputPopupButtonChanged:)},
			{inputDataTableScopeArray,          inputDataTableScopePopUpMenu,          @selector(inputPopupButtonChanged:)},
			{outputGeneralScopeArray,           outputGeneralScopePopUpMenu,           @selector(outputPopupButtonChanged:)},
			{outputInputFieldScopeArray,        outputInputFieldScopePopUpMenu,        @selector(outputPopupButtonChanged:)},
			{outputDataTableScopeArray,         outputDataTableScopePopUpMenu,         @selector(outputPopupButtonChanged:)},
			{inputFallbackInputFieldScopeArray, inputFallbackInputFieldScopePopUpMenu, @selector(inputFallbackPopupButtonChanged:)},
			{triggerInputFieldArray,            triggerInputFieldPopUpMenu,            @selector(triggerButtonChanged:)},
			{triggerDataTableArray,             triggerDataTablePopUpMenu,             @selector(triggerButtonChanged:)},
			{triggerGeneralArray,               triggerGeneralPopUpMenu,               @selector(triggerButtonChanged:)},
			{withBlobDataTableArray,            withBlobDataTablePopUpMenu,            @selector(withBlobButtonChanged:)},
			{inputNoneArray,                    inputNonePopUpMenu,                    NULL}
	};

	for(unsigned int i=0;i<COUNT_OF(menus);i++) {
		struct _menuItemMap *menu = &menus[i];
		for(NSString* title in menu->items) {
			NSMenuItem *anItem = [[NSMenuItem alloc] initWithTitle:[menuItemTitles objectForKey:title] action:menu->action keyEquivalent:@""];
			[menu->menu addItem:anItem];
			[anItem release];
		}
	}

	NSMenuItem *anItem;
	[inputGeneralScopePopUpMenu removeAllItems];
	anItem = [[NSMenuItem alloc] initWithTitle:SP_BUNDLEEDITOR_SCOPE_GENERAL_STRING action:@selector(scopeButtonChanged:) keyEquivalent:@""];
	[anItem setTag:kGeneralScopeArrayIndex];
	[inputGeneralScopePopUpMenu addItem:anItem];
	[anItem release];
	anItem = [[NSMenuItem alloc] initWithTitle:SP_BUNDLEEDITOR_SCOPE_INPUTFIELD_STRING action:@selector(scopeButtonChanged:) keyEquivalent:@""];
	[anItem setTag:kInputFieldScopeArrayIndex];
	[inputGeneralScopePopUpMenu addItem:anItem];
	[anItem release];
	anItem = [[NSMenuItem alloc] initWithTitle:SP_BUNDLEEDITOR_SCOPE_DATATABLE_STRING action:@selector(scopeButtonChanged:) keyEquivalent:@""];
	[anItem setTag:kDataTableScopeArrayIndex];
	[inputGeneralScopePopUpMenu addItem:anItem];
	[anItem release];
	[scopePopupButton setMenu:inputGeneralScopePopUpMenu];

	[keyEquivalentField setCanCaptureGlobalHotKeys:YES];

	[commandBundleTreeController setSortDescriptors:[NSArray arrayWithObjects:sortDescriptor, nil]];

	shellVariableSuggestions = [@[
			SPBundleShellVariableAllDatabases,
			SPBundleShellVariableAllFunctions,
			SPBundleShellVariableAllProcedures,
			SPBundleShellVariableAllTables,
			SPBundleShellVariableAllViews,
			SPBundleShellVariableAppResourcesDirectory,
			SPBundleShellVariableBlobFileDirectory,
			SPBundleShellVariableExitInsertAsSnippet,
			SPBundleShellVariableExitInsertAsText,
			SPBundleShellVariableExitNone,
			SPBundleShellVariableExitReplaceContent,
			SPBundleShellVariableExitReplaceSelection,
			SPBundleShellVariableExitShowAsHTML,
			SPBundleShellVariableExitShowAsHTMLTooltip,
			SPBundleShellVariableExitShowAsTextTooltip,
			SPBundleShellVariableInputFilePath,
			SPBundleShellVariableInputTableMetaData,
			SPBundleShellVariableBundlePath,
			SPBundleShellVariableBundleScope,
			SPBundleShellVariableCurrentEditedColumnName,
			SPBundleShellVariableCurrentEditedTable,
			SPBundleShellVariableCurrentHost,
			SPBundleShellVariableCurrentLine,
			SPBundleShellVariableCurrentPort,
			SPBundleShellVariableCurrentQuery,
			SPBundleShellVariableCurrentUser,
			SPBundleShellVariableCurrentWord,
			SPBundleShellVariableDataTableSource,
			SPBundleShellVariableDatabaseEncoding,
			SPBundleShellVariableIconFile,
			SPBundleShellVariableProcessID,
			SPBundleShellVariableQueryFile,
			SPBundleShellVariableQueryResultFile,
			SPBundleShellVariableQueryResultMetaFile,
			SPBundleShellVariableQueryResultStatusFile,
			SPBundleShellVariableRDBMSType,
			SPBundleShellVariableRDBMSVersion,
			SPBundleShellVariableSelectedDatabase,
			SPBundleShellVariableSelectedRowIndices,
			SPBundleShellVariableSelectedTable,
			SPBundleShellVariableSelectedTables,
			SPBundleShellVariableSelectedText,
			SPBundleShellVariableSelectedTextRange,
			SPBundleShellVariableUsedQueryForTable
	] retain];

	if([[NSUserDefaults standardUserDefaults] objectForKey:SPBundleDeletedDefaultBundlesKey]) {
		[deletedDefaultBundles setArray:[[NSUserDefaults standardUserDefaults] objectForKey:SPBundleDeletedDefaultBundlesKey]];
	}

	[self _initTree];

};

#pragma mark -

/**
 * Store input source in bundle dict since it is not bound
 * via key binding and update various GUI elements
 */
- (IBAction)inputPopupButtonChanged:(id)sender
{

	id currentDict = [self _currentSelectedObject];

	NSMenu* senderMenu = [sender menu];

	NSInteger selectedIndex = [senderMenu indexOfItem:sender];
	NSString *input = SPBundleInputSourceNone;
	if(senderMenu == inputGeneralScopePopUpMenu)
		input = [inputGeneralScopeArray objectAtIndex:selectedIndex];
	else if(senderMenu == inputInputFieldScopePopUpMenu)
		input = [inputInputFieldScopeArray objectAtIndex:selectedIndex];
	else if(senderMenu == inputDataTableScopePopUpMenu)
		input = [inputDataTableScopeArray objectAtIndex:selectedIndex];
	else if(senderMenu == inputNonePopUpMenu)
		input = SPBundleInputSourceNone;

	[currentDict setObject:input forKey:SPBundleFileInputSourceKey];

	[self _updateBundleDataView];

}

/**
 * Store input fallback source in bundle dict since it is not bound
 * via key binding.
 */
- (IBAction)inputFallbackPopupButtonChanged:(id)sender
{

	id currentDict = [self _currentSelectedObject];

	NSMenu* senderMenu = [sender menu];

	NSInteger selectedIndex = [senderMenu indexOfItem:sender];
	NSString *input = SPBundleInputSourceNone;
	if(senderMenu == inputFallbackInputFieldScopePopUpMenu)
		input = [inputFallbackInputFieldScopeArray objectAtIndex:selectedIndex];

	[currentDict setObject:input forKey:SPBundleFileInputSourceFallBackKey];

}

/**
 * Store output action in bundle dict since it is not bound
 * via key binding.
 */
- (IBAction)outputPopupButtonChanged:(id)sender
{

	id currentDict = [self _currentSelectedObject];

	NSMenu* senderMenu = [sender menu];

	NSInteger selectedIndex = [senderMenu indexOfItem:sender];
	NSString *output = SPBundleOutputActionNone;
	if(senderMenu == outputGeneralScopePopUpMenu)
		output = [outputGeneralScopeArray objectAtIndex:selectedIndex];
	else if(senderMenu == outputInputFieldScopePopUpMenu)
		output = [outputInputFieldScopeArray objectAtIndex:selectedIndex];
	else if(senderMenu == outputDataTableScopePopUpMenu)
		output = [outputDataTableScopeArray objectAtIndex:selectedIndex];

	[currentDict setObject:output forKey:SPBundleFileOutputActionKey];

}

/**
 * If scope was changed store that info in the bundle dict since it is not bound
 * via key binding. In addition move the selected item to its new scope in the tree.
 * If a category was set check if the scope also has this category; if not create it.
 */
- (IBAction)scopeButtonChanged:(id)sender
{

	id currentDict = [self _currentSelectedObject];

	NSInteger selectedTag = [sender tag];
	NSString *oldScope = [[currentDict objectForKey:SPBundleFileScopeKey] retain];

	switch(selectedTag) {
		case kGeneralScopeArrayIndex:
		[currentDict setObject:SPBundleScopeGeneral forKey:SPBundleFileScopeKey];
		break;
		case kInputFieldScopeArrayIndex:
		[currentDict setObject:SPBundleScopeInputField forKey:SPBundleFileScopeKey];
		break;
		case kDataTableScopeArrayIndex:
		[currentDict setObject:SPBundleScopeDataTable forKey:SPBundleFileScopeKey];
		break;
		default:
		[currentDict setObject:@"" forKey:SPBundleFileScopeKey];
	}

	if(selectedTag != kDisabledScopeTag && ![[currentDict objectForKey:SPBundleFileScopeKey] isEqualToString:oldScope]) {
		NSUInteger newScopeIndex = [self _arrangedScopeIndexForScopeIndex:selectedTag];
		NSString *currentCategory = [currentDict objectForKey:SPBundleFileCategoryKey];
		if(!currentCategory) currentCategory = @"";
		if([currentCategory length]) {
			NSUInteger newIndexPath[4];
			newIndexPath[0] = 0;
			newIndexPath[1] = newScopeIndex;
			newIndexPath[2] = [self _arrangedCategoryIndexForScopeIndex:selectedTag andCategory:currentCategory];
			newIndexPath[3] = 0;
			[commandBundleTreeController moveNode:[self _currentSelectedNode] toIndexPath:[NSIndexPath indexPathWithIndexes:newIndexPath length:4]];
			[commandBundleTreeController rearrangeObjects];
			[commandsOutlineView reloadData];
		} else {
			// Move current Bundle command to according new scope without category
			NSUInteger newIndexPath[3];
			newIndexPath[0] = 0;
			newIndexPath[1] = newScopeIndex;
			newIndexPath[2] = 0;
			[commandBundleTreeController moveNode:[self _currentSelectedNode] toIndexPath:[NSIndexPath indexPathWithIndexes:newIndexPath length:3]];
			[commandBundleTreeController rearrangeObjects];
			[commandsOutlineView reloadData];
		}
	}

	[oldScope release];

	[self _updateBundleDataView];

}

/**
 * Store trigger in bundle dict since it is not bound
 * via key binding and update various GUI elements
 */
- (IBAction)triggerButtonChanged:(id)sender
{

	id currentDict = [self _currentSelectedObject];

	NSMenu* senderMenu = [sender menu];

	NSInteger selectedIndex = [senderMenu indexOfItem:sender];
	NSString *input = SPBundleTriggerActionNone;
	if(senderMenu == triggerGeneralPopUpMenu)
		input = [triggerGeneralArray objectAtIndex:selectedIndex];
	else if(senderMenu == triggerInputFieldPopUpMenu)
		input = [triggerInputFieldArray objectAtIndex:selectedIndex];
	else if(senderMenu == triggerDataTablePopUpMenu)
		input = [triggerDataTableArray objectAtIndex:selectedIndex];

	[currentDict setObject:input forKey:SPBundleFileTriggerKey];

	[self _updateBundleDataView];

}

/**
 * Store trigger in bundle dict since it is not bound
 * via key binding and update various GUI elements
 */
- (IBAction)withBlobButtonChanged:(id)sender
{

	id currentDict = [self _currentSelectedObject];

	NSMenu* senderMenu = [sender menu];

	NSInteger selectedIndex = [senderMenu indexOfItem:sender];
	NSString *input = SPBundleInputSourceBlobHandlingExclude;

	input = [withBlobDataTableArray objectAtIndex:selectedIndex];

	[currentDict setObject:input forKey:SPBundleFileWithBlobKey];

	[self _updateBundleDataView];

}

/**
 * Duplicate the selected bundle (processed in addCommandBundle:)
 */
- (IBAction)duplicateCommandBundle:(id)sender
{
	if ([commandsOutlineView numberOfSelectedRows] == 1)
		[self addCommandBundle:self];
	else
		NSBeep();
}

/**
 * If sender == self duplicate selected bundle; otherwise add a new bundle -
 * insert the new item under the selected one and set scope and category resp. according
 * to current selection in the tree
 */
- (IBAction)addCommandBundle:(id)sender
{
	NSMutableDictionary *bundle;

	// Store pending changes in Query
	[[self window] makeFirstResponder:nameTextField];

	NSString *newUUID = [NSString stringWithNewUUID];

	NSIndexPath *currentIndexPath = nil;
	currentIndexPath = [commandBundleTreeController selectionIndexPath];

	if(!currentIndexPath) {
		NSBeep();
		return;
	}

	// Duplicate a selected Bundle if sender == self
	if (sender == self) {
		NSDictionary *currentDict = [self _currentSelectedObject];
		bundle = [NSMutableDictionary dictionaryWithDictionary:currentDict];

		[bundle setObject:newUUID forKey:SPBundleFileUUIDKey];

		NSString *bundleFileName = [bundle objectForKey:kBundleNameKey];
		NSString *newFileName = [NSString stringWithFormat:@"%@_Copy", [bundle objectForKey:kBundleNameKey]];
		NSString *possibleExisitingBundleFilePath = [NSString stringWithFormat:@"%@/%@.%@", bundlePath, bundleFileName, SPUserBundleFileExtension];
		NSString *newBundleFilePath = [NSString stringWithFormat:@"%@/%@.%@", bundlePath, newFileName, SPUserBundleFileExtension];

		BOOL isDir;
		BOOL copyingWasSuccessful = YES;
		// Copy possible existing bundle with content
		if([[NSFileManager defaultManager] fileExistsAtPath:possibleExisitingBundleFilePath isDirectory:&isDir] && isDir) {
			if(![[NSFileManager defaultManager] copyItemAtPath:possibleExisitingBundleFilePath toPath:newBundleFilePath error:nil])
				copyingWasSuccessful = NO;
		}
		if(!copyingWasSuccessful) {
			// try again with new name
			newFileName = [NSString stringWithFormat:@"%@_%ld", newFileName, (long)(random() % 35000)];
			newBundleFilePath = [NSString stringWithFormat:@"%@/%@.%@", bundlePath, newFileName, SPUserBundleFileExtension];
			if([[NSFileManager defaultManager] fileExistsAtPath:possibleExisitingBundleFilePath isDirectory:&isDir] && isDir) {
				if([[NSFileManager defaultManager] copyItemAtPath:possibleExisitingBundleFilePath toPath:newBundleFilePath error:nil])
					copyingWasSuccessful = YES;
			}
		}
		if(!copyingWasSuccessful) {

			[commandsOutlineView reloadData];

			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error", @"Bundle Editor : Copy-Command-Error : error dialog title")
											 defaultButton:NSLocalizedString(@"OK", @"Bundle Editor : Copy-Command-Error : OK button") 
										   alternateButton:nil 
											  otherButton:nil 
								informativeTextWithFormat:NSLocalizedString(@"Error while duplicating Bundle content.", @"Bundle Editor : Copy-Command-Error : Copying failed error message")];
		
			[alert setAlertStyle:NSCriticalAlertStyle];
			[alert runModal];

			return;

		}
		[bundle setObject:newFileName forKey:kBundleNameKey];

		[self saveBundle:bundle atPath:nil];

		// Insert duplicate below selected one
		NSUInteger currentPath[[currentIndexPath length]];
		[currentIndexPath getIndexes:currentPath];
		currentPath[[currentIndexPath length]-1] = (NSUInteger)currentPath[[currentIndexPath length]-1] + 1;
		currentIndexPath = [NSIndexPath indexPathWithIndexes:currentPath length:[currentIndexPath length]];

	}
	// Add a new Bundle
	else {

		NSString *category = nil;
		NSString *scope = nil;
		BOOL lastIndexWasAlreadyFixed = NO;
		id currentObject = [self _currentSelectedObject];

		// If selected item is one of the main scopes go one item deeper
		if([currentIndexPath length] == 2) {
			NSUInteger newPath[3];
			[currentIndexPath getIndexes:newPath];
			newPath[2] = 0;
			currentIndexPath = [NSIndexPath indexPathWithIndexes:newPath length:3];
			lastIndexWasAlreadyFixed = YES;
		}
		// If selected item is a category go one item deeper
		else if([currentIndexPath length] == 3 && [currentObject objectForKey:kChildrenKey]) {
			NSUInteger newPath[4];
			[currentIndexPath getIndexes:newPath];
			newPath[3] = 0;
			currentIndexPath = [NSIndexPath indexPathWithIndexes:newPath length:4];
			lastIndexWasAlreadyFixed = YES;
			category = [currentObject objectForKey:kBundleNameKey];
		}

		NSUInteger currentPath[[currentIndexPath length]];
		[currentIndexPath getIndexes:currentPath];

		// Last index plus 1 to insert bundle under the current selection
		if(!lastIndexWasAlreadyFixed) {
			currentPath[[currentIndexPath length]-1] = (NSUInteger)currentPath[[currentIndexPath length]-1] + 1;
			currentIndexPath = [NSIndexPath indexPathWithIndexes:currentPath length:[currentIndexPath length]];
		}

		// Set current scope
		switch([self _scopeIndexForArrangedScopeIndex:(NSUInteger)currentPath[1]]) {
			case kInputFieldScopeArrayIndex:
			scope = SPBundleScopeInputField;
			break;
			case kDataTableScopeArrayIndex:
			scope = SPBundleScopeDataTable;
			break;
			case kGeneralScopeArrayIndex:
			scope = SPBundleScopeGeneral;
			break;
			default:
			scope = SPBundleScopeGeneral;
		}

		// Get current category
		if([currentIndexPath length] > 2 && category == nil) {
			category = [[[[[commandsOutlineView parentForItem:[self _currentSelectedNode]] representedObject] objectForKey:kChildrenKey] objectAtIndex:0] objectForKey:SPBundleFileCategoryKey];
		}
		if(category == nil) category = @"";

		bundle = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"New Bundle",@"Bundle Editor : Default name for new bundle in the list on the left"), NSLocalizedString(@"New Name",@"Bundle Editor : Default name for a new bundle in the menu"), @"", scope, category, newUUID, nil] 
						forKeys:@[kBundleNameKey, SPBundleFileNameKey, SPBundleFileCommandKey, SPBundleFileScopeKey, SPBundleFileCategoryKey, SPBundleFileUUIDKey]];
	}

	if(![touchedBundleArray containsObject:[bundle objectForKey:kBundleNameKey]])
		[touchedBundleArray addObject:[bundle objectForKey:kBundleNameKey]];

	[commandBundleTreeController insertObject:bundle atArrangedObjectIndexPath:currentIndexPath];

	[commandBundleTreeController rearrangeObjects];
	[commandsOutlineView reloadData];

	[commandsOutlineView scrollRowToVisible:[commandsOutlineView selectedRow]];

	[removeButton setEnabled:([[commandBundleTreeController selectedObjects] count] == 1 && ![[[commandBundleTreeController selectedObjects] objectAtIndex:0] objectForKey:kChildrenKey])];
	[addButton setEnabled:([[commandBundleTreeController selectionIndexPath] length] > 1)];

	[self _updateBundleDataView];

	[[self window] makeFirstResponder:commandsOutlineView];

}

/**
 * Remove the selected bundle but before ask for confirmation
 */
- (IBAction)removeCommandBundle:(id)sender
{

	[commandsOutlineView abortEditing];

	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Remove selected Bundle?", @"Bundle Editor : Remove-Bundle: remove dialog title") 
									 defaultButton:NSLocalizedString(@"Remove", @"Bundle Editor : Remove-Bundle: remove button")
								   alternateButton:NSLocalizedString(@"Cancel", @"Bundle Editor : Remove-Bundle: cancel button")
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to move the selected Bundle to the Trash and remove them respectively?", @"Bundle Editor : Remove-Bundle: remove dialog message")];

	[alert setAlertStyle:NSCriticalAlertStyle];
	
	NSArray *buttons = [alert buttons];
	
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"r"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
	
	[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"removeSelectedBundles"];

}

/**
 * Reveal selected bundle.spBundle folder in Finder
 */
- (IBAction)revealCommandBundleInFinder:(id)sender
{
	if ([commandsOutlineView numberOfSelectedRows] != 1) return;

	[[NSWorkspace sharedWorkspace] selectFile:[NSString stringWithFormat:@"%@/%@.%@/%@", 
		bundlePath, [[self _currentSelectedObject] objectForKey:kBundleNameKey], SPUserBundleFileExtension, SPBundleFileName] inFileViewerRootedAtPath:@""];
}

/**
 * Open Save Panel for saving the selected bundle to disk
 */
- (IBAction)saveBundle:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];

	[panel setAllowedFileTypes:@[SPUserBundleFileExtension]];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:NO];
	[panel setCanSelectHiddenExtension:YES];
	[panel setCanCreateDirectories:YES];

	[panel setNameFieldStringValue:[[self _currentSelectedObject] objectForKey:kBundleNameKey]];

	[panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger returnCode) {
		if (returnCode != NSFileHandlingPanelOKButton) return;
		
		// Panel is still on screen. Hide it first. (This is Apple's recommended way)
		[panel orderOut:nil];
		
		id aBundle = [self _currentSelectedObject];
		
		NSString *bundleFileName = [aBundle objectForKey:kBundleNameKey];
		NSString *possibleExisitingBundleFilePath = [NSString stringWithFormat:@"%@/%@.%@", bundlePath, bundleFileName, SPUserBundleFileExtension];
		NSAssert(possibleExisitingBundleFilePath != nil, @"source bundle path must be non-nil!");
		
		NSString *savePath = [[panel URL] path];
		NSAssert(savePath != nil, @"destination bundle path must be non-nil! (URL=%@)",[panel URL]);
		
		BOOL isDir;
		BOOL copyingWasSuccessful = YES;
		NSError *err = nil;
		
		// Copy possible existing bundle with content
		if([[NSFileManager defaultManager] fileExistsAtPath:possibleExisitingBundleFilePath isDirectory:&isDir] && isDir) {
			//FIXME This will fail if savePath exists, but the user already consented overwriting in the save panel. We should use trashItemAtURL:... once we are 10.8+
			if(![[NSFileManager defaultManager] copyItemAtPath:possibleExisitingBundleFilePath toPath:savePath error:&err]) {
				//if we have an NSError that will provide the nicest error message.
				if(err) {
					[[NSAlert alertWithError:err] runModal];
					return;
				}
				NSLog(@"copy(%@ -> %@) failed!",possibleExisitingBundleFilePath,savePath);
				copyingWasSuccessful = NO;
			}
		}
		
		if(!copyingWasSuccessful || ![self saveBundle:aBundle atPath:savePath]) {
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText:NSLocalizedString(@"Error while saving the Bundle.", @"Bundle Editor : Save-Bundle-Error : error dialog title")];
			[alert addButtonWithTitle:NSLocalizedString(@"OK", @"Bundle Editor : Save-Bundle-Error : OK button")];
			[alert setAlertStyle:NSCriticalAlertStyle];
			[alert runModal]; //blocks
			[alert release];
		}
	}];
}

/**
 * Show help web page for Bundle Editor
 */
- (IBAction)showHelp:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:SPLOCALIZEDURL_BUNDLEEDITORHELP]];
}

/**
 * Reload all installed bundles and order front the Bundle Editor
 */
- (IBAction)reloadBundles:(id)sender
{
	[self _initTree];
}

/**
 * Read all installed bundles and order front the Bundle Editor
 */
- (IBAction)showWindow:(id)sender
{
	[super showWindow:sender];
}

- (IBAction)performClose:(id)sender
{
	[self _initTree];
	[self close];
}

- (IBAction)undeleteDefaultBundles:(id)sender
{
	[NSApp beginSheet:undeleteSheet
	   modalForWindow:[self window] 
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:@"undeleteSelectedDefaultBundles"];
}

- (IBAction)closeUndeleteDefaultBundlesSheet:(id)sender
{

	[NSApp endSheet:[sender window] returnCode:[sender tag]];

	if ([sender respondsToSelector:@selector(orderOut:)])
		[sender orderOut:nil];
	else if ([sender respondsToSelector:@selector(window)])
		[[sender window] orderOut:nil];
}

- (IBAction)displayBundleMetaInfo:(id)sender
{
	[NSApp beginSheet:metaInfoSheet
	   modalForWindow:[self window]
		modalDelegate:self
	   didEndSelector:@selector(_metaSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

- (IBAction)closeSheet:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

/**
 * Save all touched bundles to disk and close the Bundle Editor window
 */
- (IBAction)saveAndCloseWindow:(id)sender
{
	// Commit all pending edits
	if([commandBundleTreeController commitEditing]) {

		// Get all Bundles out of commandBundleTree which were touched
		NSMutableArray *allBundles = [NSMutableArray array];
		for (NSUInteger k = 0; k < [[commandBundleTree objectForKey:kChildrenKey] count]; k++) {
			for(id item in [[[commandBundleTree objectForKey:kChildrenKey] objectAtIndex:k] objectForKey:kChildrenKey]) {
				if([item objectForKey:kChildrenKey]) {
					for(id b in [item objectForKey:kChildrenKey]) {
						if([touchedBundleArray containsObject:[b objectForKey:kBundleNameKey]]) {
							[allBundles addObject:b];
						}
					}
				}
				else {
					if([touchedBundleArray containsObject:[item objectForKey:kBundleNameKey]]) {
						[allBundles addObject:item];
					}
				}
			}
		}

		// Make the bundleNames unique since they represent folder names
		NSMutableDictionary *allNames = [NSMutableDictionary dictionary];
		NSInteger idx = 0;
		for(id item in allBundles) {
			if([allNames objectForKey:[item objectForKey:kBundleNameKey]]) {
				NSString *newName = [NSString stringWithFormat:@"%@_%ld", [item objectForKey:kBundleNameKey], (long)(random() % 35000)];
				[[allBundles objectAtIndex:idx] setObject:newName forKey:kBundleNameKey];
			} else {
				[allNames setObject:@"" forKey:[item objectForKey:kBundleNameKey]];
			}
			idx++;
		}

		BOOL closeMe = YES;
		for(id item in allBundles) {
			if(![self saveBundle:item atPath:nil]) {
				closeMe = NO;
				NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while saving “%@”.", @"Bundle Editor : Save-and-Close-Error : error dialog title"), [item objectForKey:kBundleNameKey]]
												 defaultButton:NSLocalizedString(@"OK", @"Bundle Editor : Save-and-Close-Error : OK button") 
											   alternateButton:nil 
												  otherButton:nil 
									informativeTextWithFormat:@""];
			
				[alert setAlertStyle:NSCriticalAlertStyle];
				[alert runModal];
				break;
			}
		}
		if(closeMe)
			[[self window] performClose:self];
	}

	[SPAppDelegate reloadBundles:self];

}

/**
 * Save the passed NSDictionary representing a bundle to disk at path aPath and
 * return success
 */
- (BOOL)saveBundle:(NSDictionary*)bundle atPath:(NSString*)aPath
{

	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDir = NO;
	BOOL isNewBundle = NO;

	// If passed aPath is nil construct the path from bundle's bundleName.
	// aPath is mainly used for dragging a bundle from table view.
	if(aPath == nil) {
		if(![bundle objectForKey:kBundleNameKey] || ![[bundle objectForKey:kBundleNameKey] length]) {
			return NO;
		}
		if(!bundlePath)
			bundlePath = [[[NSFileManager defaultManager] applicationSupportDirectoryForSubDirectory:SPBundleSupportFolder createIfNotExists:YES error:nil] retain];
		aPath = [NSString stringWithFormat:@"%@/%@.%@", bundlePath, [bundle objectForKey:kBundleNameKey], SPUserBundleFileExtension];
	}

	// Create spBundle folder if it doesn't exist
	if(![fm fileExistsAtPath:aPath isDirectory:&isDir]) {
		if(![fm createDirectoryAtPath:aPath withIntermediateDirectories:YES attributes:nil error:nil])
			return NO;
		isDir = YES;
		isNewBundle = YES;
	}
	
	// If aPath exists but it's not a folder bail out
	if(!isDir) return NO;

	// The command.plist file path
	NSString *cmdFilePath = [NSString stringWithFormat:@"%@/%@", aPath, SPBundleFileName];

	NSMutableDictionary *saveDict = [NSMutableDictionary dictionary];
	[saveDict addEntriesFromDictionary:bundle];

	// ROT13 a contact - mainly a mail address
	if([saveDict objectForKey:SPBundleFileContactKey] && [[saveDict objectForKey:SPBundleFileContactKey] length])
		[saveDict setObject:[[saveDict objectForKey:SPBundleFileContactKey] rot13] forKey:SPBundleFileContactKey];

	// Remove unnecessary keys
	[saveDict removeObjectsForKeys:@[kBundleNameKey]];


	if(!isNewBundle) {
		NSDictionary *cmdData = nil;
		{
			NSError *error = nil;
			
			NSData *pData = [NSData dataWithContentsOfFile:cmdFilePath options:NSUncachedRead error:&error];
			
			cmdData = [[NSPropertyListSerialization propertyListWithData:pData
																 options:NSPropertyListImmutable
																  format:NULL
																   error:&error] retain];
			
			if(!cmdData || error) {
				NSLog(@"“%@” file couldn't be read. (error=%@)", cmdFilePath, error);
				NSBeep();
				if (cmdData) [cmdData release];
				return NO;
			}
		}
		
		// Check for changes and return if no changes are found
		if([[saveDict description] isEqualToString:[cmdData description]]) 
			return YES;
		if([cmdData objectForKey:SPBundleFileIsDefaultBundleKey]) 
			[saveDict setObject:@YES forKey:SPBundleFileDefaultBundleWasModifiedKey];
		
		if (cmdData) [cmdData release];
	}

	// Remove a given old command.plist file
	[fm removeItemAtPath:cmdFilePath error:nil];
	[saveDict writeToFile:cmdFilePath atomically:YES];

	return YES;
}

/**
 * Sheet did end method
 */
- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo
{

	// Order out current sheet to suppress overlapping of sheets
	if ([sheet respondsToSelector:@selector(orderOut:)])
		[sheet orderOut:nil];
	else if ([sheet respondsToSelector:@selector(window)])
		[[sheet window] orderOut:nil];

	if([contextInfo isEqualToString:@"removeSelectedBundles"]) {
		if (returnCode == NSAlertDefaultReturn) {
			
			NSArray *selObjects = [commandBundleTreeController selectedObjects];
			NSArray *selIndexPaths = [commandBundleTreeController selectionIndexPaths];
			BOOL deletionSuccessfully = YES;

			for(id obj in selObjects) {

				// Move already installed Bundles to Trash
				NSString *bundleName = [obj objectForKey:kBundleNameKey];
				NSString *thePath = [NSString stringWithFormat:@"%@/%@.%@", bundlePath, bundleName, SPUserBundleFileExtension];
				if([[NSFileManager defaultManager] fileExistsAtPath:thePath isDirectory:nil]) {
					NSError *error = nil;

					// Use a AppleScript script since NSWorkspace performFileOperation or NSFileManager moveItemAtPath 
					// have problems probably due access rights.
					NSString *moveToTrashCommand = [NSString stringWithFormat:@"osascript -e 'tell application \"Finder\" to move (POSIX file \"%@\") to the trash'", thePath];
					
					[SPBundleCommandRunner runBashCommand:moveToTrashCommand withEnvironment:nil atCurrentDirectoryPath:nil error:&error];
					
					if(error != nil) {
						NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while moving “%@” to Trash.", @"Bundle Editor : Trash-Bundle(s)-Error : error dialog title"), thePath]
														 defaultButton:NSLocalizedString(@"OK", @"Bundle Editor : Trash-Bundle(s)-Error : OK button") 
													   alternateButton:nil 
														  otherButton:nil 
											informativeTextWithFormat:@"%@", [error localizedDescription]];
					
						[alert setAlertStyle:NSCriticalAlertStyle];
						[alert runModal];
						deletionSuccessfully = NO;
						break;
					}
					if([obj objectForKey:SPBundleFileIsDefaultBundleKey]) {
						[deletedDefaultBundles addObject:[NSArray arrayWithObjects:[obj objectForKey:SPBundleFileUUIDKey], [obj objectForKey:SPBundleFileNameKey], nil]];
						[[NSUserDefaults standardUserDefaults] setObject:deletedDefaultBundles forKey:SPBundleDeletedDefaultBundlesKey];
					}
					[commandsOutlineView reloadData];
				}
			}

			if(deletionSuccessfully) {
				[commandBundleTreeController removeObjectsAtArrangedObjectIndexPaths:selIndexPaths];
				[commandBundleTreeController rearrangeObjects];
			}

			[self reloadBundles:self];

			[commandBundleTreeController setSelectionIndexPath:[[selIndexPaths objectAtIndex:0] indexPathByRemovingLastIndex]];
			[commandsOutlineView expandItem:[self _currentSelectedNode] expandChildren:NO];

			// Set focus to table view to avoid an unstable state
			[[self window] makeFirstResponder:commandsOutlineView];

			[removeButton setEnabled:([[commandBundleTreeController selectedObjects] count] == 1 && ![[[commandBundleTreeController selectedObjects] objectAtIndex:0] objectForKey:kChildrenKey])];
			[addButton setEnabled:([[commandBundleTreeController selectionIndexPath] length] > 1)];

		}
	}
	else if([contextInfo isEqualToString:@"undeleteSelectedDefaultBundles"]) {
		if(returnCode == 1) {

			NSIndexSet *selectedRows = [undeleteTableView selectedRowIndexes];

			if(![selectedRows count]) return;

			NSUInteger rowIndex;
			NSMutableArray *stillUndeletedBundles = [NSMutableArray array];
			for(rowIndex = 0; rowIndex < [deletedDefaultBundles count]; rowIndex++) {
				if(![selectedRows containsIndex:rowIndex])
					[stillUndeletedBundles addObject:[deletedDefaultBundles objectAtIndex:rowIndex]];
			}
			[deletedDefaultBundles setArray:stillUndeletedBundles];
			[undeleteTableView reloadData];
			[[NSUserDefaults standardUserDefaults] setObject:stillUndeletedBundles forKey:SPBundleDeletedDefaultBundlesKey];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[SPAppDelegate reloadBundles:nil];
			[self reloadBundles:self];

		}
	}
	else {
		NSBeep();
		NSLog(@"%s: unhandled case! (contextInfo=%p)",__func__,contextInfo);
	}

}

- (BOOL)cancelRowEditing
{
	[commandsOutlineView abortEditing];
	isTableCellEditing = NO;
	return YES;
}

#pragma mark -
#pragma mark NSWindow delegate

- (BOOL)windowShouldClose:(id)sender
{

	// Suppress closing of the window if user pressed ESC while inline table cell editing.
	if(isTableCellEditing) {
		[commandsOutlineView abortEditing];
		isTableCellEditing = NO;
		[[self window] makeFirstResponder:commandsOutlineView];
		return NO;
	}
	return YES;

}

- (void)windowWillClose:(NSNotification *)notification
{
	// Remove temporary drag file if any
	if(draggedFilePath) {
		[[NSFileManager defaultManager] removeItemAtPath:draggedFilePath error:nil];
		SPClear(draggedFilePath);
	}
	if(oldBundleName) SPClear(oldBundleName);
}

#pragma mark -
#pragma mark SRRecorderControl delegate

- (BOOL) shortcutValidator:(SRValidator *)validator isKeyCode:(NSInteger)keyCode andFlagsTaken:(NSUInteger)flags reason:(NSString **)aReason;
{
    return YES;
}

- (BOOL)shortcutRecorderCell:(SRRecorderCell *)aRecorderCell isKeyCode:(NSInteger)keyCode andFlagsTaken:(NSUInteger)flags reason:(NSString **)aReason
{
	return YES;
}

- (void)shortcutRecorder:(SRRecorderControl *)aRecorder keyComboDidChange:(KeyCombo)newKeyCombo
{

	if([commandsOutlineView selectedRow] < 0) return;

	// Transform KeyCombo struct to KeyBinding.dict format for NSMenuItems
	NSMutableString *keyEq = [NSMutableString string];

	NSString *theChar = @"";

	if([aRecorder objectValue])
		theChar =[[[aRecorder objectValue] objectForKey:@"characters"] lowercaseString];
	else
		theChar =[[aRecorder keyCharsIgnoringModifiers] lowercaseString];
	[keyEq setString:@""];
	if(newKeyCombo.code > -1) {
		if(newKeyCombo.flags & NSEventModifierFlagControl)
			[keyEq appendString:@"^"];
		if(newKeyCombo.flags & NSEventModifierFlagOption)
			[keyEq appendString:@"~"];
		if(newKeyCombo.flags & NSEventModifierFlagShift) {
			[keyEq appendString:@"$"];
			theChar = [theChar uppercaseString];
		}
		if(newKeyCombo.flags & NSEventModifierFlagCommand)
			[keyEq appendString:@"@"];
		if(theChar)
			[keyEq appendString:theChar];
	}
	[[self _currentSelectedObject] setObject:keyEq forKey:SPBundleFileKeyEquivalentKey];

}

#pragma mark -
#pragma mark TableView delegates

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [deletedDefaultBundles count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return [[deletedDefaultBundles objectAtIndex:rowIndex] objectAtIndex:1];
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return NO;
}

#pragma mark -
#pragma mark outline delegates

- (BOOL)outlineView:(id)outlineView isItemExpandable:(id)item
{
	return [item isKindOfClass:[NSDictionary class]] && [item objectForKey:kChildrenKey];
}

- (NSInteger)outlineView:(id)outlineView numberOfChildrenOfItem:(id)item
{
	if (item == nil) item = commandBundleTree;
	
	if ([item isKindOfClass:[NSDictionary class]]) {
		return [item objectForKey:kChildrenKey] ? [[item objectForKey:kChildrenKey] count] : [item count];
	}

	if ([item isKindOfClass:[NSArray class]]) {
		return [item count];
	}
	
	return 0;
}

- (id)outlineView:(id)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if (item && [[item representedObject] respondsToSelector:@selector(objectForKey:)]) {
		return [[item representedObject] objectForKey:kBundleNameKey];
	}
	
	return @"";
}

- (BOOL)outlineView:outlineView isGroupItem:(id)item
{
	return ([[item representedObject] isKindOfClass:[NSDictionary class]] && [[item representedObject] objectForKey:kChildrenKey]);
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item
{
	if(![outlineView parentForItem:item]) return NO;
	return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item
{
	return (![item isLeaf]);
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	if([outlineView levelForItem:item] == 0) return NO;
	return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if ([[commandBundleTreeController selectionIndexPath] length] > 2) {
		isTableCellEditing = YES;
		return YES;
	}
	isTableCellEditing = NO;
	return NO;
}

/**
 * Validate GUI elements and remember the bundle name after the user
 * selected another bundle
 */
- (void)outlineViewSelectionDidChange:(NSNotification *)aNotification
{
	if([aNotification object] != commandsOutlineView) return;

	// Remember selected bundle name to reset the name if the user cancelled
	// the editing of the bundle name
	if(oldBundleName) SPClear(oldBundleName);
	if(![[self _currentSelectedObject] objectForKey:kChildrenKey]) {
		oldBundleName = [[[self _currentSelectedObject] objectForKey:kBundleNameKey] retain];
		[self _enableBundleDataInput:YES bundleEnabled:![[[self _currentSelectedObject] objectForKey:@"disabled"] boolValue]];
	} else {
		[self _enableBundleDataInput:NO bundleEnabled:NO];
		if(oldBundleName) SPClear(oldBundleName);
	}

	// Remember the selected bundle name in touchedBundleArray to save only those 
	// bundles which were at least selected by the user to minimize disk activity
	if(oldBundleName != nil && ![touchedBundleArray containsObject:oldBundleName])
		[touchedBundleArray addObject:oldBundleName];

	[self _updateBundleDataView];
	
	[commandTextView setSelectedRange:NSMakeRange(0,0)];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldShowOutlineCellForItem:(id)item
{
	if([outlineView levelForItem:item] == 0) return NO;
	return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldShowCellExpansionForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	return NO;
}

- (NSString *)outlineView:(NSOutlineView *)outlineView toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tc item:(id)item mouseLocation:(NSPoint)mouseLocation{
	if([outlineView levelForItem:item] == 0) return NSLocalizedString(@"Installed Bundles", @"Bundle Editor : Outline View : 'BUNDLES' item : tooltip");
	if([outlineView levelForItem:item] == 1) {
		NSString *bName = [[item representedObject] objectForKey:kBundleNameKey];
		NSUInteger k = 0;
		BOOL found = NO;
		for(id i in [[commandBundleTreeController arrangedObjects] childNodes]) {
			for(id j in [i childNodes]) {
				if([[[j representedObject] objectForKey:kBundleNameKey] isEqualToString:bName]) {
					found = YES;
					break;
				}
				k++;
			}
			if(found) break;
		}
		switch([self _scopeIndexForArrangedScopeIndex:k]) {
			case kInputFieldScopeArrayIndex:
			return NSLocalizedString(@"Input Field Scope\ncommands will run on each text input field", @"Bundle Editor : Outline View : 'Input Field' item : tooltip");
			break;
			case kDataTableScopeArrayIndex:
			return NSLocalizedString(@"Data Table Scope\ncommands will run on the Content and Query data tables", @"Bundle Editor : Outline View : 'Data Table' item : tooltip");
			break;
			case kGeneralScopeArrayIndex:
			return NSLocalizedString(@"General Scope\ncommands will run application-wide", @"Bundle Editor : Outline View : 'General' item : tooltip");
			break;
			default:
			return @"";
		}
	}
	if([outlineView levelForItem:item] == 2) {
		if([[item representedObject] objectForKey:kChildrenKey]) {
			return [NSString stringWithFormat:NSLocalizedString(@"Bundles in category “%@”",@"Bundle Editor : Outline View : Menu Category item : tooltip"), [[item representedObject] objectForKey:kBundleNameKey]];
		} else {
			if([[item representedObject] objectForKey:SPBundleFileTooltipKey] && [[[item representedObject] objectForKey:SPBundleFileTooltipKey] length])
				return [[item representedObject] objectForKey:SPBundleFileTooltipKey];
			else
				return [NSString stringWithFormat:SP_BUNDLEEDITOR_OUTLINE_BUNDLE_TOOLTIP_STRING, [[item representedObject] objectForKey:kBundleNameKey]];
		}
	}
	if([outlineView levelForItem:item] == 3) {
		if([[item representedObject] objectForKey:SPBundleFileTooltipKey] && [[[item representedObject] objectForKey:SPBundleFileTooltipKey] length])
			return [[item representedObject] objectForKey:SPBundleFileTooltipKey];
		else
			return [NSString stringWithFormat:SP_BUNDLEEDITOR_OUTLINE_BUNDLE_TOOLTIP_STRING, [[item representedObject] objectForKey:kBundleNameKey]];
	}
	return @"";
}

#pragma mark -
#pragma mark TableView (outline) delegate

/**
 * Traps enter and esc and edit/cancel without entering next row
 */
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	if ( [[control window] methodForSelector:command] == [[control window] methodForSelector:@selector(cancelOperation:)] ||
		[textView methodForSelector:command] == [textView methodForSelector:@selector(complete:)] ) {

		//abort editing
		[control abortEditing];
		[[commandsOutlineView window] makeFirstResponder:commandsOutlineView];
		return YES;
	} else{
		return NO;
	}
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{

	if([aNotification object] == commandsOutlineView) {

		// We edit a category
		if([[self _currentSelectedObject] objectForKey:kChildrenKey]) {

			NSString *newCategoryName = [[[aNotification userInfo] objectForKey:@"NSFieldEditor"] string];

			// Set the new category for each child
			for(id item in [[self _currentSelectedObject] objectForKey:kChildrenKey])
				[item setObject:newCategoryName forKey:SPBundleFileCategoryKey];

		}
		// We edit a spBundle name
		else {

			NSString *newBundleName = [[[aNotification userInfo] objectForKey:@"NSFieldEditor"] string];

			BOOL isValid = YES;

			if(oldBundleName && newBundleName && [newBundleName length] && ![newBundleName rangeOfString:@"/"].length) {

				NSString *oldName = [NSString stringWithFormat:@"%@/%@.%@", bundlePath, oldBundleName, SPUserBundleFileExtension];
				NSString *newName = [NSString stringWithFormat:@"%@/%@.%@", bundlePath, newBundleName, SPUserBundleFileExtension];
	
				BOOL isDir;
				NSFileManager *fm = [NSFileManager defaultManager];
				// Check for renaming
				if([fm fileExistsAtPath:oldName isDirectory:&isDir] && isDir) {
					if(![fm moveItemAtPath:oldName toPath:newName error:nil]) {
						isValid = NO;
					}
				}
				// Check if the new name already exists
				else {
					if([fm fileExistsAtPath:newName isDirectory:&isDir] && isDir) {
						isValid = NO;
					}
				}
			} else {
				isValid = NO;
			}

			// If not valid reset name to the old one
			if(!isValid && oldBundleName) {
				[[self _currentSelectedObject] setObject:oldBundleName forKey:kBundleNameKey];
			}

			[commandBundleTreeController rearrangeObjects];
			[commandsOutlineView reloadData];

			if(oldBundleName) SPClear(oldBundleName);
			oldBundleName = [[[self _currentSelectedObject] objectForKey:kBundleNameKey] retain];
			if(oldBundleName != nil && ![touchedBundleArray containsObject:oldBundleName])
				[touchedBundleArray addObject:oldBundleName];
		}

		isTableCellEditing = NO;
	}
	else if([aNotification object] == categoryTextField) {

		// Move Bundle to new category node; if not exists create it
		NSUInteger scopeIndex = 0;
		NSString* currentScope = [[self _currentSelectedObject] objectForKey:SPBundleFileScopeKey];
		if([currentScope isEqualToString:SPBundleScopeDataTable])
			scopeIndex = kDataTableScopeArrayIndex;
		else if([currentScope isEqualToString:SPBundleScopeGeneral])
			scopeIndex = kGeneralScopeArrayIndex;
		else if([currentScope isEqualToString:SPBundleScopeInputField])
			scopeIndex = kInputFieldScopeArrayIndex;

		NSIndexPath *currentIndexPath = [commandBundleTreeController selectionIndexPath];
		NSUInteger newIndexPathLength = 4;
		NSUInteger newIndexPath[newIndexPathLength];
		[currentIndexPath getIndexes:newIndexPath];
		newIndexPath[3] = 0;

		// Set the category index
		NSUInteger newCategoryIndex = (NSUInteger)[self _arrangedCategoryIndexForScopeIndex:scopeIndex andCategory:[categoryTextField stringValue]];
		if(newCategoryIndex == NSNotFound) {
			newIndexPath[2] = 0;
			newIndexPathLength--;
		} else
			newIndexPath[2] = newCategoryIndex;

		// Move the selected item to the new category node
		[commandBundleTreeController moveNode:[self _currentSelectedNode] toIndexPath:[NSIndexPath indexPathWithIndexes:newIndexPath length:newIndexPathLength]];
		[commandBundleTreeController rearrangeObjects];
		[commandsOutlineView reloadData];
	}
}

#pragma mark -
#pragma mark Menu validation

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = [menuItem action];
	
	if ((action == @selector(duplicateCommandBundle:)) || 
		(action == @selector(revealCommandBundleInFinder:)) ||
		(action == @selector(saveBundle:)) || 
		(action == @selector(removeCommandBundle:)) ||
		(action == @selector(displayBundleMetaInfo:))) 
	{
		// Allow to record short-cuts used by the Bundle Editor
		if([[NSApp keyWindow] firstResponder] == keyEquivalentField) return NO;
		
		return ([[commandBundleTreeController selectedObjects] count] == 1 && ![[[commandBundleTreeController selectedObjects] objectAtIndex:0] objectForKey:kChildrenKey]);
	}

	if ( action == @selector(undeleteDefaultBundles:) ) {
		return ([deletedDefaultBundles count]) ? YES : NO;
	}

	return YES;
}

#pragma mark -
#pragma mark OutlineView drag & drop delegate methods

/**
 * Allow for drag-n-drop out of the application as a copy
 */
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return NSDragOperationMove;
}

/**
 * Drag selected bundle as spBundle file to eg Finder
 */
- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
	if([commandsOutlineView numberOfSelectedRows] != 1 || [items count] != 1 ||
		![[items objectAtIndex:0] isLeaf]) return NO;

	// Remove old temporary drag file if any
	if(draggedFilePath) {
		[[NSFileManager defaultManager] removeItemAtPath:draggedFilePath error:nil];
		SPClear(draggedFilePath);
	}

	NSImage *dragImage;
	NSPoint dragPosition;

	NSDictionary *bundleDict = [[items objectAtIndex:0] representedObject];
	NSString *bundleFileName = [bundleDict objectForKey:kBundleNameKey];
	NSString *possibleExisitingBundleFilePath = [NSString stringWithFormat:@"%@/%@.%@", bundlePath, bundleFileName, SPUserBundleFileExtension];

	draggedFilePath = [[NSString stringWithFormat:@"%@/%@.%@", [NSFileManager temporaryDirectory], bundleFileName, SPUserBundleFileExtension] retain];

	BOOL isDir;

	// Copy possible existing bundle with content
	if([[NSFileManager defaultManager] fileExistsAtPath:possibleExisitingBundleFilePath isDirectory:&isDir] && isDir) {
		if(![[NSFileManager defaultManager] copyItemAtPath:possibleExisitingBundleFilePath toPath:draggedFilePath error:nil])
			return NO;
	}

	// Write temporary bundle data to disk but do not save the dict to Bundles folder
	if(![self saveBundle:bundleDict atPath:draggedFilePath]) return NO;

	// Write data to the pasteboard
	NSArray *fileList = [NSArray arrayWithObjects:draggedFilePath, nil];
	// NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	[pboard declareTypes:@[NSFilenamesPboardType] owner:nil];
	[pboard setPropertyList:fileList forType:NSFilenamesPboardType];

	// Start the drag operation
	dragImage = [[NSWorkspace sharedWorkspace] iconForFile:draggedFilePath];
	dragPosition = [[[self window] contentView] convertPoint:[[NSApp currentEvent] locationInWindow] fromView:nil];
	dragPosition.x -= 32;
	dragPosition.y -= 32;
	[[self window] dragImage:dragImage at:dragPosition offset:NSZeroSize
		event:[NSApp currentEvent] pasteboard:pboard source:[self window] slideBack:YES];

	return YES;
}

#pragma mark -
#pragma mark NSTextView delegates

/**
 * Update command text view for highlighting the current edited line
 */
- (void)textViewDidChangeSelection:(NSNotification *)aNotification
{
	[commandTextView setNeedsDisplay:YES];
}

/**
 * Group text changes to improve the undo behaviour
 */
- (void)textDidChange:(NSNotification *)aNotification
{

	if([aNotification object] == commandTextView) {

		 // Traps any editing in commandTextView to allow undo grouping only if the text buffer was really changed.
		 // Inform the run loop delayed for larger undo groups.

		[NSObject cancelPreviousPerformRequestsWithTarget:self
									selector:@selector(setAllowedUndo)
									object:nil];

		// If conditions match create an undo group
		NSInteger cycleCounter;
		if( ( wasCutPaste || allowUndo || doGroupDueToChars ) && ![esUndoManager isUndoing] && ![esUndoManager isRedoing] ) {
			allowUndo = NO;
			wasCutPaste = NO;
			doGroupDueToChars = NO;
			selectionChanged = NO;

			cycleCounter = 0;
			while([esUndoManager groupingLevel] > 0) {
				[esUndoManager endUndoGrouping];
				cycleCounter++;
			}
			while([esUndoManager groupingLevel] < cycleCounter)
				[esUndoManager beginUndoGrouping];

			cycleCounter = 0;
		}

		[self performSelector:@selector(setAllowedUndo) withObject:nil afterDelay:0.0005];
	}
}

/**
 * Add shell variable names to the completion list
 */
- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index
{

	NSMutableArray *suggestions = [NSMutableArray array];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@ ", [[textView string] substringWithRange:charRange]];
	[suggestions addObjectsFromArray:[shellVariableSuggestions filteredArrayUsingPredicate:predicate]];
	[suggestions addObjectsFromArray:words];
	return suggestions;

}

#pragma mark -
#pragma mark UndoManager methods

/**
 * Establish and return an UndoManager for editTextView
 */
- (NSUndoManager*)undoManagerForTextView:(NSTextView*)aTextView
{
	if (!esUndoManager)
		esUndoManager = [[NSUndoManager alloc] init];

	return esUndoManager;
}

/**
 * Set variable if something in editTextView was cutted or pasted for creating better undo grouping.
 */
- (void)setWasCutPaste
{
	wasCutPaste = YES;
}

/**
 * Will be invoke delayed for creating better undo grouping according to type speed (see [self textDidChange:]).
 */
- (void)setAllowedUndo
{
	allowUndo = YES;
}

/**
 * Will be set if according to characters typed in editTextView for creating better undo grouping.
 */
- (void)setDoGroupDueToChars
{
	doGroupDueToChars = YES;
}

- (void)_initTree
{
	// Re-init commandBundleTree
	[[[commandBundleTree objectForKey:kChildrenKey] objectAtIndex:kInputFieldScopeArrayIndex] setObject:[NSMutableArray array] forKey:kChildrenKey];
	[[[commandBundleTree objectForKey:kChildrenKey] objectAtIndex:kDataTableScopeArrayIndex] setObject:[NSMutableArray array] forKey:kChildrenKey];
	[[[commandBundleTree objectForKey:kChildrenKey] objectAtIndex:kGeneralScopeArrayIndex] setObject:[NSMutableArray array] forKey:kChildrenKey];
	[commandsOutlineView reloadData];

	// Load all installed bundle items
	if(bundlePath) {
		NSError *error = nil;
		NSArray *foundBundles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:bundlePath error:&error];
		if (foundBundles && [foundBundles count]) {
			for(NSString* bundle in foundBundles) {
				if(![[[bundle pathExtension] lowercaseString] isEqualToString:[SPUserBundleFileExtension lowercaseString]]) continue;

				NSDictionary *cmdData = nil;
				NSError *readError = nil;
					
				NSString *infoPath = [NSString stringWithFormat:@"%@/%@/%@", bundlePath, bundle, SPBundleFileName];
				NSData *pData = [NSData dataWithContentsOfFile:infoPath options:NSUncachedRead error:&readError];
				
				if(pData && !error) {
					cmdData = [[NSPropertyListSerialization propertyListWithData:pData
																		 options:NSPropertyListImmutable
																		  format:NULL
																		   error:&readError] retain];
				}
				
				if(!cmdData || readError) {
					NSLog(@"“%@/%@” file couldn't be read. (error=%@)", bundle, SPBundleFileName, readError);
					NSBeep();
					if (cmdData) [cmdData release];
				}
				else {
					if([cmdData objectForKey:SPBundleFileNameKey] && [[cmdData objectForKey:SPBundleFileNameKey] length] && [cmdData objectForKey:SPBundleFileScopeKey])
					{
						NSMutableDictionary *bundleCommand = [NSMutableDictionary dictionary];
						[bundleCommand addEntriesFromDictionary:cmdData];
						[bundleCommand setObject:[bundle stringByDeletingPathExtension] forKey:kBundleNameKey];

						// ROT13 a contact - mainly a mail address
						if([bundleCommand objectForKey:SPBundleFileContactKey] && [[bundleCommand objectForKey:SPBundleFileContactKey] length])
							[bundleCommand setObject:[[bundleCommand objectForKey:SPBundleFileContactKey] rot13] forKey:SPBundleFileContactKey];

						if([[cmdData objectForKey:SPBundleFileScopeKey] isEqualToString:SPBundleScopeInputField]) {
							if([cmdData objectForKey:SPBundleFileCategoryKey] && [[cmdData objectForKey:SPBundleFileCategoryKey] length]) {
								BOOL catExists = NO;
								id children = [[[commandBundleTree objectForKey:kChildrenKey] objectAtIndex:kInputFieldScopeArrayIndex] objectForKey:kChildrenKey];
								for(id child in children) {
									if([child isKindOfClass:[NSDictionary class]] && [child objectForKey:kChildrenKey] && [[child objectForKey:kBundleNameKey] isEqualToString:[cmdData objectForKey:SPBundleFileCategoryKey]]) {
										[[child objectForKey:kChildrenKey] addObject:bundleCommand];
										catExists = YES;
										break;
									}
								}
								if(!catExists) {
									NSMutableDictionary *aDict = [NSMutableDictionary dictionary];
									[aDict setObject:[cmdData objectForKey:SPBundleFileCategoryKey] forKey:kBundleNameKey];
									[aDict setObject:[NSMutableArray array] forKey:kChildrenKey];
									[[aDict objectForKey:kChildrenKey] addObject:bundleCommand];
									[[[[commandBundleTree objectForKey:kChildrenKey] objectAtIndex:0] objectForKey:kChildrenKey] addObject:aDict];
								}
							} else {
								[[[[commandBundleTree objectForKey:kChildrenKey] objectAtIndex:0] objectForKey:kChildrenKey] addObject:bundleCommand];
							}
						}

						else if([[cmdData objectForKey:SPBundleFileScopeKey] isEqualToString:SPBundleScopeDataTable]) {
							if([cmdData objectForKey:SPBundleFileCategoryKey] && [[cmdData objectForKey:SPBundleFileCategoryKey] length]) {
								BOOL catExists = NO;
								id children = [[[commandBundleTree objectForKey:kChildrenKey] objectAtIndex:kDataTableScopeArrayIndex] objectForKey:kChildrenKey];
								for(id child in children) {
									if([child isKindOfClass:[NSDictionary class]] && [child objectForKey:kChildrenKey] && [[child objectForKey:kBundleNameKey] isEqualToString:[cmdData objectForKey:SPBundleFileCategoryKey]]) {
										[[child objectForKey:kChildrenKey] addObject:bundleCommand];
										catExists = YES;
										break;
									}
								}
								if(!catExists) {
									NSMutableDictionary *aDict = [NSMutableDictionary dictionary];
									[aDict setObject:[cmdData objectForKey:SPBundleFileCategoryKey] forKey:kBundleNameKey];
									[aDict setObject:[NSMutableArray array] forKey:kChildrenKey];
									[[aDict objectForKey:kChildrenKey] addObject:bundleCommand];
									[[[[commandBundleTree objectForKey:kChildrenKey] objectAtIndex:1] objectForKey:kChildrenKey] addObject:aDict];
								}
							} else {
								[[[[commandBundleTree objectForKey:kChildrenKey] objectAtIndex:1] objectForKey:kChildrenKey] addObject:bundleCommand];
							}
						}

						else if([[cmdData objectForKey:SPBundleFileScopeKey] isEqualToString:SPBundleScopeGeneral]) {
							if([cmdData objectForKey:SPBundleFileCategoryKey] && [[cmdData objectForKey:SPBundleFileCategoryKey] length]) {
								BOOL catExists = NO;
								id children = [[[commandBundleTree objectForKey:kChildrenKey] objectAtIndex:kGeneralScopeArrayIndex] objectForKey:kChildrenKey];
								for(id child in children) {
									if([child isKindOfClass:[NSDictionary class]] && [child objectForKey:kChildrenKey] && [[child objectForKey:kBundleNameKey] isEqualToString:[cmdData objectForKey:SPBundleFileCategoryKey]]) {
										[[child objectForKey:kChildrenKey] addObject:bundleCommand];
										catExists = YES;
										break;
									}
								}
								if(!catExists) {
									NSMutableDictionary *aDict = [NSMutableDictionary dictionary];
									[aDict setObject:[cmdData objectForKey:SPBundleFileCategoryKey] forKey:kBundleNameKey];
									[aDict setObject:[NSMutableArray array] forKey:kChildrenKey];
									[[aDict objectForKey:kChildrenKey] addObject:bundleCommand];
									[[[[commandBundleTree objectForKey:kChildrenKey] objectAtIndex:2] objectForKey:kChildrenKey] addObject:aDict];
								}
							} else {
								[[[[commandBundleTree objectForKey:kChildrenKey] objectAtIndex:2] objectForKey:kChildrenKey] addObject:bundleCommand];
							}
						}

					}
					if (cmdData) [cmdData release];
				}
			}
		}
	}

	[removeButton setEnabled:([[commandBundleTreeController selectedObjects] count] == 1 && ![[[commandBundleTreeController selectedObjects] objectAtIndex:0] objectForKey:kChildrenKey])];
	[addButton setEnabled:([[commandBundleTreeController selectionIndexPath] length] > 1)];

	NSUInteger selPath[2];
	selPath[0] = 0;
	selPath[1] = 0;
	[commandBundleTreeController setSelectionIndexPath:[NSIndexPath indexPathWithIndexes:selPath length:2]];
	[commandBundleTreeController rearrangeObjects];
	[commandsOutlineView reloadData];

	[commandsOutlineView expandItem:[commandsOutlineView itemAtRow:0] expandChildren:NO];
	[self _updateBundleDataView];
	[self _enableBundleDataInput:NO bundleEnabled:NO];
}

/**
 * Update various GUI elements due to scope or input changes
 */
- (void)_updateBundleDataView
{
	NSInteger anIndex;

	if([commandsOutlineView selectedRow] < 0) return;

	NSDictionary *currentDict = [self _currentSelectedObject];

	NSString *input = [currentDict objectForKey:SPBundleFileInputSourceKey];
	if(!input || ![input length]) input = SPBundleInputSourceNone;

	NSString *inputfallback = [currentDict objectForKey:SPBundleFileInputSourceFallBackKey];
	if(!inputfallback || ![inputfallback length]) inputfallback = SPBundleInputSourceNone;

	NSString *output = [currentDict objectForKey:SPBundleFileOutputActionKey];
	if(!output || ![output length]) output = SPBundleOutputActionNone;

	NSString *scope = [currentDict objectForKey:SPBundleFileScopeKey];
	if(!scope) scope = SPBundleScopeGeneral;

	NSString *trigger = [currentDict objectForKey:SPBundleFileTriggerKey];
	if(!trigger) trigger = SPBundleTriggerActionNone;

	NSString *withBlob = [currentDict objectForKey:SPBundleFileWithBlobKey];
	if(!withBlob) withBlob = SPBundleInputSourceBlobHandlingExclude;

	// Update the scope popup button
	if([scope isEqualToString:SPBundleScopeGeneral])
		[scopePopupButton selectItemWithTag:kGeneralScopeArrayIndex];
	else if([scope isEqualToString:SPBundleScopeInputField])
		[scopePopupButton selectItemWithTag:kInputFieldScopeArrayIndex];
	else if([scope isEqualToString:SPBundleScopeDataTable])
		[scopePopupButton selectItemWithTag:kDataTableScopeArrayIndex];
	else
		[scopePopupButton selectItemWithTag:kDisabledScopeTag];

	// Change due scope setting various popup buttons
	switch([[scopePopupButton selectedItem] tag]) {
		case kGeneralScopeArrayIndex: // General
		[inputPopupButton setMenu:inputNonePopUpMenu];
		[inputPopupButton selectItemAtIndex:0];

		[outputPopupButton setMenu:outputGeneralScopePopUpMenu];
		anIndex = [outputGeneralScopeArray indexOfObject:output];
		if(anIndex == NSNotFound) anIndex = 0;
		[outputPopupButton selectItemAtIndex:anIndex];

		[triggerPopupButton setMenu:triggerGeneralPopUpMenu];
		anIndex = [triggerGeneralArray indexOfObject:trigger];
		if(anIndex == NSNotFound) anIndex = 0;
		[triggerPopupButton selectItemAtIndex:anIndex];

		input = SPBundleInputSourceNone;
		[inputFallbackPopupButton setHidden:YES];
		[fallbackLabelField setHidden:YES];
		[withBlobPopupButton setHidden:YES];
		[withBlobLabelField setHidden:YES];

		break;
		case kInputFieldScopeArrayIndex: // Input Field
		[inputPopupButton setMenu:inputInputFieldScopePopUpMenu];
		anIndex = [inputInputFieldScopeArray indexOfObject:input];
		if(anIndex == NSNotFound) anIndex = 0;
		[inputPopupButton selectItemAtIndex:anIndex];

		[inputFallbackPopupButton setMenu:inputFallbackInputFieldScopePopUpMenu];
		anIndex = [inputFallbackInputFieldScopeArray indexOfObject:inputfallback];
		if(anIndex == NSNotFound) anIndex = 0;
		[inputFallbackPopupButton selectItemAtIndex:anIndex];

		[outputPopupButton setMenu:outputInputFieldScopePopUpMenu];
		anIndex = [outputInputFieldScopeArray indexOfObject:output];
		if(anIndex == NSNotFound) anIndex = 0;
		[outputPopupButton selectItemAtIndex:anIndex];

		[triggerPopupButton setMenu:triggerInputFieldPopUpMenu];
		anIndex = [triggerInputFieldArray indexOfObject:trigger];
		if(anIndex == NSNotFound) anIndex = 0;
		[triggerPopupButton selectItemAtIndex:anIndex];

		[withBlobPopupButton setHidden:YES];
		[withBlobLabelField setHidden:YES];

		break;
		case kDataTableScopeArrayIndex: // Data Table
		[inputPopupButton setMenu:inputDataTableScopePopUpMenu];
		anIndex = [inputDataTableScopeArray indexOfObject:input];
		if(anIndex == NSNotFound) anIndex = 0;
		[inputPopupButton selectItemAtIndex:anIndex];

		[outputPopupButton setMenu:outputDataTableScopePopUpMenu];
		anIndex = [outputDataTableScopeArray indexOfObject:output];
		if(anIndex == NSNotFound) anIndex = 0;
		[outputPopupButton selectItemAtIndex:anIndex];

		[inputFallbackPopupButton setHidden:YES];
		[fallbackLabelField setHidden:YES];

		[triggerPopupButton setMenu:triggerDataTablePopUpMenu];
		anIndex = [triggerDataTableArray indexOfObject:trigger];
		if(anIndex == NSNotFound) anIndex = 0;
		[triggerPopupButton selectItemAtIndex:anIndex];

		[withBlobPopupButton setMenu:withBlobDataTablePopUpMenu];
		anIndex = [withBlobDataTableArray indexOfObject:withBlob];
		if(anIndex == NSNotFound) anIndex = 0;
		[withBlobPopupButton selectItemAtIndex:anIndex];

		[inputFallbackPopupButton setHidden:YES];
		[fallbackLabelField setHidden:YES];

		if([currentDict objectForKey:SPBundleFileInputSourceKey] && ([[currentDict objectForKey:SPBundleFileInputSourceKey] isEqualToString:SPBundleInputSourceNone] || [[currentDict objectForKey:SPBundleFileInputSourceKey] isEqualToString:SPBundleInputSourceTableRowsAsSqlInsert] || [[currentDict objectForKey:SPBundleFileInputSourceKey] isEqualToString:SPBundleInputSourceSelectedTableRowsAsSqlInsert])) {
			[withBlobPopupButton setHidden:YES];
			[withBlobLabelField setHidden:YES];
		} else {
			[withBlobPopupButton setHidden:NO];
			[withBlobLabelField setHidden:NO];
		}
		input = SPBundleInputSourceNone;

		break;
		case kDisabledScopeTag: // Disable command
		break;
		default:
		[inputPopupButton setMenu:inputNonePopUpMenu];
		[inputPopupButton selectItemAtIndex:0];
		[outputPopupButton setMenu:outputGeneralScopePopUpMenu];
		anIndex = [outputGeneralScopeArray indexOfObject:output];
		if(anIndex == NSNotFound) anIndex = 0;
		[outputPopupButton selectItemAtIndex:anIndex];
	}

	// If input method is "Selected Text" display fallback input popup
	// otherwise hide it
	if([input isEqualToString:SPBundleInputSourceSelectedText]) {
		[inputFallbackPopupButton setHidden:NO];
		[fallbackLabelField setHidden:NO];
	} else {
		[inputFallbackPopupButton setHidden:YES];
		[fallbackLabelField setHidden:YES];
	}

	// Update the bundle summary text
	[self _updateBundleMetaSummary];

	// Validate add and remove bundle button in left bar
	[removeButton setEnabled:([[commandBundleTreeController selectedObjects] count] == 1 && ![[[commandBundleTreeController selectedObjects] objectAtIndex:0] objectForKey:kChildrenKey])];
	[addButton setEnabled:([[commandBundleTreeController selectionIndexPath] length] > 1)];

}

/**
 * Update the bundle meta summary text
 */
- (void)_updateBundleMetaSummary
{
	NSDictionary *currentDict = [self _currentSelectedObject];
	if (!currentDict) {
		[metaInfoSummary setStringValue:@""];
		return;
	}

	NSMutableString *metaString = [[[NSMutableString alloc] init] autorelease];
	if ([currentDict objectForKey:@"author"]) {
		[metaString appendFormat:@"(%@) ", [currentDict objectForKey:@"author"]];
	} else if ([currentDict objectForKey:@"contact"]) {
		[metaString appendFormat:@"(%@) ", [currentDict objectForKey:@"contact"]];
	}

	if ([currentDict objectForKey:@"description"]) [metaString appendString:[currentDict objectForKey:@"description"]];

	[metaInfoSummary setStringValue:metaString];
}

/**
 * Return the current selected object as NSDictionary
 */
- (id)_currentSelectedObject
{
	return [[commandsOutlineView itemAtRow:[commandsOutlineView selectedRow]] representedObject];
}

/**
 * Return the current selected object as NSTreeNode
 */
- (id)_currentSelectedNode
{
	return [commandsOutlineView itemAtRow:[commandsOutlineView selectedRow]];
}

/**
 * Convert scope index from unsorted index to sorted (arranged) index
 */
- (NSUInteger)_arrangedScopeIndexForScopeIndex:(NSUInteger)scopeIndex
{
	NSString *unsortedBundleName = [[[commandBundleTree objectForKey:kChildrenKey] objectAtIndex:scopeIndex] objectForKey:kBundleNameKey];

	if(!unsortedBundleName || ![unsortedBundleName length]) return scopeIndex;

	NSUInteger k = 0;
	for(id i in [[commandBundleTreeController arrangedObjects] childNodes]) {
		for(id j in [i childNodes]) {
			if([[[j representedObject] objectForKey:kBundleNameKey] isEqualToString:unsortedBundleName])
				return k;
			k++;
		}
	}

	return k;
}

/**
 * Convert scope index from sorted (arranged) index to unsorted index
 */
- (NSUInteger)_scopeIndexForArrangedScopeIndex:(NSUInteger)scopeIndex
{
	NSString *bName = [[[[[[[commandBundleTreeController arrangedObjects] childNodes] objectAtIndex:0] childNodes] objectAtIndex:scopeIndex] representedObject] objectForKey:kBundleNameKey];
	NSUInteger k = 0;
	for(id i in [commandBundleTree objectForKey:kChildrenKey]) {
		if([[i objectForKey:kBundleNameKey] isEqualToString:bName])
			return k;
		k++;
	}
	return k;
}

/**
 * Enable / disable data input
 */
- (void)_enableBundleDataInput:(BOOL)enabled bundleEnabled:(BOOL)bundleEnabled
{

	// Most of the interface requires both a bundle selected and enabled
	BOOL enableInterface = enabled && bundleEnabled;
	[nameTextField setEnabled:enableInterface];
	[inputPopupButton setEnabled:enableInterface];
	[inputFallbackPopupButton setEnabled:enableInterface];
	[scopePopupButton setEnabled:enableInterface];
	[commandTextView setEditable:enableInterface];
	[outputPopupButton setEnabled:enableInterface];
	[triggerPopupButton setEnabled:enableInterface];
	[keyEquivalentField setEnabled:enableInterface];
	[categoryTextField setEnabled:enableInterface];
	[tooltipTextField setEnabled:enableInterface];

	// Always leave the meta fields enabled, and the disabled checkbox.
	[authorTextField setEnabled:enabled];
	[contactTextField setEnabled:enabled];
	[descriptionTextView setEditable:enabled];
	[displayMetaInfoButton setEnabled:enabled];

	[disabledCheckbox setEnabled:enabled];
}

/**
 * Return that index for the unsorted scopeIndex and given category. If the category
 * does not exist create a new category node.
 */
- (NSUInteger)_arrangedCategoryIndexForScopeIndex:(NSUInteger)scopeIndex andCategory:(NSString*)category
{

	if(!category || ![category length]) return NSNotFound;

	NSString *unsortedBundleName = [[[commandBundleTree objectForKey:kChildrenKey] objectAtIndex:scopeIndex] objectForKey:kBundleNameKey];

	if(!unsortedBundleName || ![unsortedBundleName length]) return scopeIndex;

	NSUInteger returnIndex = 0;
	NSUInteger k = 0;
	for(id i in [[commandBundleTreeController arrangedObjects] childNodes]) {
		for(id j in [i childNodes]) {
			if([[[j representedObject] objectForKey:kBundleNameKey] isEqualToString:unsortedBundleName]) {
				//Check if category exists; if not created
				for(id c in [j childNodes]) {
					if([[[c representedObject] objectForKey:kBundleNameKey] isEqualToString:category] && [[c representedObject] objectForKey:kChildrenKey]) {
						return returnIndex;
					}
					returnIndex++;
				}
				// Not found ergo create it
				NSMutableDictionary *newCat = [NSMutableDictionary dictionary];
				[newCat setObject:category forKey:kBundleNameKey];
				[newCat setObject:[NSMutableArray array] forKey:kChildrenKey];
				
				// Add it
				[[[j representedObject] objectForKey:kChildrenKey] addObject:newCat];

				// Rearrange the tree
				[commandBundleTreeController rearrangeObjects];
				[commandsOutlineView reloadData];

				// Find new position in sorted tree
				returnIndex = 0;
				for(id c in [j childNodes]) {
					if([[[c representedObject] objectForKey:kBundleNameKey] isEqualToString:category] && [[c representedObject] objectForKey:kChildrenKey]) {
						return returnIndex;
					}
					returnIndex++;
				}
			}
			k++;
		}
		return 0;
	}

	return returnIndex;
}

- (void)_metaSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet makeFirstResponder:nil];
	
	[self _updateBundleMetaSummary];
}

#pragma mark -

- (void)dealloc
{
	SPClear(inputGeneralScopePopUpMenu);
	SPClear(inputInputFieldScopePopUpMenu);
	SPClear(inputDataTableScopePopUpMenu);
	SPClear(outputGeneralScopePopUpMenu);
	SPClear(outputInputFieldScopePopUpMenu);
	SPClear(outputDataTableScopePopUpMenu);
	SPClear(inputFallbackInputFieldScopePopUpMenu);
	SPClear(triggerInputFieldPopUpMenu);
	SPClear(triggerDataTablePopUpMenu);
	SPClear(triggerGeneralPopUpMenu);
	SPClear(withBlobDataTablePopUpMenu);
	SPClear(inputNonePopUpMenu);
	
	SPClear(inputGeneralScopeArray);
	SPClear(inputInputFieldScopeArray);
	SPClear(inputDataTableScopeArray);
	SPClear(outputGeneralScopeArray);
	SPClear(outputInputFieldScopeArray);
	SPClear(outputDataTableScopeArray);
	SPClear(inputFallbackInputFieldScopeArray);
	SPClear(triggerInputFieldArray);
	SPClear(triggerDataTableArray);
	SPClear(triggerGeneralArray);
	SPClear(withBlobDataTableArray);
	
	SPClear(shellVariableSuggestions);
	SPClear(deletedDefaultBundles);
	
	if (touchedBundleArray) SPClear(touchedBundleArray);
	if (commandBundleTree) SPClear(commandBundleTree);
	if (sortDescriptor) SPClear(sortDescriptor);
	if (bundlePath) SPClear(bundlePath);
	if (esUndoManager) SPClear(esUndoManager);
	
	[super dealloc];
}

@end
