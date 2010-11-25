//
//  $Id$
//
//  SPBundleEditorController.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on November 12, 2010
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

#import "SPBundleEditorController.h"
#import "SPArrayAdditions.h"

#define kBundleNameKey @"bundleName"
#define kChildrenKey @"_children_"
#define kInputFieldScopeArrayIndex 0
#define kDataTableScopeArrayIndex 1
#define kGeneralScopeArrayIndex 2
#define kDisabledScopeTag 10

@interface SPBundleEditorController (PrivateAPI)

- (void)_updateInputPopupButton;
- (id)_currentSelectedObject;
- (id)_currentSelectedNode;
- (NSUInteger)_arrangedScopeIndexForScopeIndex:(NSUInteger)scopeIndex;
- (NSUInteger)_scopeIndexForArrangedScopeIndex:(NSUInteger)scopeIndex;
- (NSUInteger)_arrangedCategoryIndexForScopeIndex:(NSUInteger)scopeIndex andCategory:(NSString*)category;

@end

#pragma mark -

@implementation SPBundleEditorController

/**
 * Initialisation
 */
- (id)init
{

	if ((self = [super initWithWindowNibName:@"BundleEditor"])) {
		commandBundleArray = nil;
		touchedBundleArray = nil;
		draggedFilePath = nil;
		oldBundleName = nil;
		isTableCellEditing = NO;
		bundlePath = [[[NSFileManager defaultManager] applicationSupportDirectoryForSubDirectory:SPBundleSupportFolder createIfNotExists:NO error:nil] retain];
	}
	
	return self;

}

- (void)dealloc
{

	[inputGeneralScopePopUpMenu release];
	[inputInputFieldScopePopUpMenu release];
	[inputDataTableScopePopUpMenu release];
	[outputGeneralScopePopUpMenu release];
	[outputInputFieldScopePopUpMenu release];
	[outputDataTableScopePopUpMenu release];
	[inputFallbackInputFieldScopePopUpMenu release];
	[inputNonePopUpMenu release];

	[inputGeneralScopeArray release];
	[inputInputFieldScopeArray release];
	[inputDataTableScopeArray release];
	[outputGeneralScopeArray release];
	[outputInputFieldScopeArray release];
	[outputDataTableScopeArray release];
	[inputFallbackInputFieldScopeArray release];

	if(commandBundleArray) [commandBundleArray release], commandBundleArray = nil;
	if(touchedBundleArray) [touchedBundleArray release], touchedBundleArray = nil;
	if(commandBundleTree) [commandBundleTree release], commandBundleTree = nil;
	if(sortDescriptor) [sortDescriptor release], sortDescriptor = nil;
	if(bundlePath) [bundlePath release], bundlePath = nil;

	[super dealloc];

}

- (void)awakeFromNib
{

	commandBundleArray = [[NSMutableArray alloc] initWithCapacity:1];
	touchedBundleArray = [[NSMutableArray alloc] initWithCapacity:1];
	commandBundleTree = [[NSMutableDictionary alloc] initWithCapacity:1];
	sortDescriptor = [[NSSortDescriptor alloc] initWithKey:kBundleNameKey ascending:YES selector:@selector(localizedCompare:)];

	[commandBundleTree setObject:[NSMutableArray array] forKey:kChildrenKey];
	[commandBundleTree setObject:@"BUNDLES" forKey:kBundleNameKey];
	[[commandBundleTree objectForKey:kChildrenKey] addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSMutableArray array], kChildrenKey, NSLocalizedString(@"Input Field", @"input field scope menu label"), kBundleNameKey, nil]];
	[[commandBundleTree objectForKey:kChildrenKey] addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSMutableArray array], kChildrenKey, NSLocalizedString(@"Data Table", @"data table scope menu label"), kBundleNameKey, nil]];
	[[commandBundleTree objectForKey:kChildrenKey] addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSMutableArray array], kChildrenKey, NSLocalizedString(@"General", @"general scope menu label"), kBundleNameKey, nil]];

	// Init all needed menus
	inputGeneralScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	inputInputFieldScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	inputDataTableScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	inputNonePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	outputGeneralScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	outputInputFieldScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	outputDataTableScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	inputFallbackInputFieldScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];

	inputGeneralScopeArray = [[NSArray arrayWithObjects:SPBundleInputSourceNone, nil] retain];
	inputInputFieldScopeArray = [[NSArray arrayWithObjects:SPBundleInputSourceNone, SPBundleInputSourceSelectedText, SPBundleInputSourceEntireContent, nil] retain];
	inputDataTableScopeArray = [[NSArray arrayWithObjects:SPBundleInputSourceNone, SPBundleInputSourceSelectedTableRowsAsTab, SPBundleInputSourceSelectedTableRowsAsCsv, SPBundleInputSourceSelectedTableRowsAsSqlInsert, SPBundleInputSourceTableRowsAsTab, SPBundleInputSourceTableRowsAsCsv, SPBundleInputSourceTableRowsAsSqlInsert, nil] retain];
	outputInputFieldScopeArray = [[NSArray arrayWithObjects:SPBundleOutputActionNone, SPBundleOutputActionInsertAsText, SPBundleOutputActionInsertAsSnippet, SPBundleOutputActionReplaceSelection, SPBundleOutputActionReplaceContent, SPBundleOutputActionShowAsTextTooltip, SPBundleOutputActionShowAsHTMLTooltip, SPBundleOutputActionShowAsHTML, nil] retain];
	outputGeneralScopeArray = [[NSArray arrayWithObjects:SPBundleOutputActionNone, SPBundleOutputActionShowAsTextTooltip, SPBundleOutputActionShowAsHTMLTooltip, SPBundleOutputActionShowAsHTML, nil] retain];
	outputDataTableScopeArray = [[NSArray arrayWithObjects:SPBundleOutputActionNone, SPBundleOutputActionShowAsTextTooltip, SPBundleOutputActionShowAsHTMLTooltip, SPBundleOutputActionShowAsHTML, nil] retain];
	inputFallbackInputFieldScopeArray = [[NSArray arrayWithObjects:SPBundleInputSourceNone, SPBundleInputSourceCurrentWord, SPBundleInputSourceCurrentLine, SPBundleInputSourceCurrentQuery, SPBundleInputSourceEntireContent, nil] retain];

	NSMutableArray *allPopupScopeItems = [NSMutableArray array];
	[allPopupScopeItems addObjectsFromArray:inputGeneralScopeArray];
	[allPopupScopeItems addObjectsFromArray:inputInputFieldScopeArray];
	[allPopupScopeItems addObjectsFromArray:inputDataTableScopeArray];
	[allPopupScopeItems addObjectsFromArray:outputInputFieldScopeArray];
	[allPopupScopeItems addObjectsFromArray:outputGeneralScopeArray];
	[allPopupScopeItems addObjectsFromArray:outputDataTableScopeArray];
	[allPopupScopeItems addObjectsFromArray:inputFallbackInputFieldScopeArray];

	NSDictionary *menuItemTitles = [NSDictionary dictionaryWithObjects:
						[NSArray arrayWithObjects:
							NSLocalizedString(@"None", @"none menu item label"),

							NSLocalizedString(@"None", @"none menu item label"),
							NSLocalizedString(@"Selected Text", @"selected text menu item label"),
							NSLocalizedString(@"Entire Content", @"entire content menu item label"),

							NSLocalizedString(@"None", @"none menu item label"),
							NSLocalizedString(@"Selected Rows (TSV)", @"selected rows (TSV) menu item label"),
							NSLocalizedString(@"Selected Rows (CSV)", @"selected rows (CSV) menu item label"),
							NSLocalizedString(@"Selected Rows (SQL)", @"selected rows (SQL) menu item label"),
							NSLocalizedString(@"Table Content (TSV)", @"table content (TSV) menu item label"),
							NSLocalizedString(@"Table Content (CSV)", @"table content (CSV) menu item label"),
							NSLocalizedString(@"Table Content (SQL)", @"table content (SQL) menu item label"),

							NSLocalizedString(@"None", @"none menu item label"),
							NSLocalizedString(@"Insert as Text", @"insert as text item label"),
							NSLocalizedString(@"Insert as Snippet", @"insert as snippet item label"),
							NSLocalizedString(@"Replace Selection", @"replace selection item label"),
							NSLocalizedString(@"Replace Entire Content", @"replace entire content item label"),
							NSLocalizedString(@"Show as Text Tooltip", @"show as text tooltip item label"),
							NSLocalizedString(@"Show as HTML Tooltip", @"show as html tooltip item label"),
							NSLocalizedString(@"Show as HTML", @"show as html item label"),

							NSLocalizedString(@"None", @"none menu item label"),
							NSLocalizedString(@"Show as Text Tooltip", @"show as text tooltip item label"),
							NSLocalizedString(@"Show as HTML Tooltip", @"show as html tooltip item label"),
							NSLocalizedString(@"Show as HTML", @"show as html item label"),

							NSLocalizedString(@"None", @"none menu item label"),
							NSLocalizedString(@"Show as Text Tooltip", @"show as text tooltip item label"),
							NSLocalizedString(@"Show as HTML Tooltip", @"show as html tooltip item label"),
							NSLocalizedString(@"Show as HTML", @"show as html item label"),

							NSLocalizedString(@"None", @"none menu item label"),
							NSLocalizedString(@"Current Word", @"current word item label"),
							NSLocalizedString(@"Current Line", @"current line item label"),
							NSLocalizedString(@"Current Query", @"current query item label"),
							NSLocalizedString(@"Entire Content", @"entire content item label"),
						nil]
					forKeys:allPopupScopeItems];

	NSMenuItem *anItem;
	for(NSString* title in inputGeneralScopeArray) {
		anItem = [[NSMenuItem alloc] initWithTitle:[menuItemTitles objectForKey:title] action:@selector(inputPopupButtonChanged:) keyEquivalent:@""];
		[inputGeneralScopePopUpMenu addItem:anItem];
		[anItem release];
	}
	for(NSString* title in inputInputFieldScopeArray) {
		anItem = [[NSMenuItem alloc] initWithTitle:[menuItemTitles objectForKey:title] action:@selector(inputPopupButtonChanged:) keyEquivalent:@""];
		[inputInputFieldScopePopUpMenu addItem:anItem];
		[anItem release];
	}
	for(NSString* title in inputDataTableScopeArray) {
		anItem = [[NSMenuItem alloc] initWithTitle:[menuItemTitles objectForKey:title] action:@selector(inputPopupButtonChanged:) keyEquivalent:@""];
		[inputDataTableScopePopUpMenu addItem:anItem];
		[anItem release];
	}
	for(NSString* title in outputGeneralScopeArray) {
		anItem = [[NSMenuItem alloc] initWithTitle:[menuItemTitles objectForKey:title] action:@selector(outputPopupButtonChanged:) keyEquivalent:@""];
		[outputGeneralScopePopUpMenu addItem:anItem];
		[anItem release];
	}
	for(NSString* title in outputInputFieldScopeArray) {
		anItem = [[NSMenuItem alloc] initWithTitle:[menuItemTitles objectForKey:title] action:@selector(outputPopupButtonChanged:) keyEquivalent:@""];
		[outputInputFieldScopePopUpMenu addItem:anItem];
		[anItem release];
	}
	for(NSString* title in outputDataTableScopeArray) {
		anItem = [[NSMenuItem alloc] initWithTitle:[menuItemTitles objectForKey:title] action:@selector(outputPopupButtonChanged:) keyEquivalent:@""];
		[outputDataTableScopePopUpMenu addItem:anItem];
		[anItem release];
	}
	for(NSString* title in inputFallbackInputFieldScopeArray) {
		anItem = [[NSMenuItem alloc] initWithTitle:[menuItemTitles objectForKey:title] action:@selector(inputFallbackPopupButtonChanged:) keyEquivalent:@""];
		[inputFallbackInputFieldScopePopUpMenu addItem:anItem];
		[anItem release];
	}
	anItem = [[NSMenuItem alloc] initWithTitle:[menuItemTitles objectForKey:SPBundleInputSourceNone] action:nil keyEquivalent:@""];
	[inputNonePopUpMenu addItem:anItem];
	[anItem release];

	[inputGeneralScopePopUpMenu removeAllItems];
	anItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"General", @"general scope menu label") action:@selector(scopeButtonChanged:) keyEquivalent:@""];
	[anItem setTag:kGeneralScopeArrayIndex];
	[inputGeneralScopePopUpMenu addItem:anItem];
	[anItem release];
	anItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Input Field", @"input field scope menu label") action:@selector(scopeButtonChanged:) keyEquivalent:@""];
	[anItem setTag:kInputFieldScopeArrayIndex];
	[inputGeneralScopePopUpMenu addItem:anItem];
	[anItem release];
	anItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Data Table", @"data table scope menu label") action:@selector(scopeButtonChanged:) keyEquivalent:@""];
	[anItem setTag:kDataTableScopeArrayIndex];
	[inputGeneralScopePopUpMenu addItem:anItem];
	[anItem release];
	[inputGeneralScopePopUpMenu addItem:[NSMenuItem separatorItem]];
	anItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Disable Command", @"disable command menu label") action:@selector(scopeButtonChanged:) keyEquivalent:@""];
	[anItem setTag:kDisabledScopeTag];
	[inputGeneralScopePopUpMenu addItem:anItem];
	[anItem release];
	[scopePopupButton setMenu:inputGeneralScopePopUpMenu];

	[keyEquivalentField setCanCaptureGlobalHotKeys:YES];

	[commandBundleTreeController setSortDescriptors:[NSArray arrayWithObjects:sortDescriptor, nil]];

}

#pragma mark -

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

	[self _updateInputPopupButton];

}

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
		NSString *newScope = [currentDict objectForKey:SPBundleFileScopeKey];
		NSUInteger newScopeIndex = [self _arrangedScopeIndexForScopeIndex:selectedTag];
		NSString *currentCategory = [currentDict objectForKey:SPBundleFileCategoryKey];
		if(!currentCategory) currentCategory = @"";
		if([currentCategory length]) {
			NSUInteger *newIndexPath[4];
			newIndexPath[0] = 0;
			newIndexPath[1] = newScopeIndex;
			newIndexPath[2] = [self _arrangedCategoryIndexForScopeIndex:selectedTag andCategory:currentCategory];
			newIndexPath[3] = 0;
			[commandBundleTreeController moveNode:[self _currentSelectedNode] toIndexPath:[NSIndexPath indexPathWithIndexes:newIndexPath length:4]];
			[commandBundleTreeController rearrangeObjects];
			[commandsOutlineView reloadData];
		} else {
			// Move current Bundle command to according new scope without category
			NSUInteger *newIndexPath[3];
			newIndexPath[0] = 0;
			newIndexPath[1] = newScopeIndex;
			newIndexPath[2] = 0;
			[commandBundleTreeController moveNode:[self _currentSelectedNode] toIndexPath:[NSIndexPath indexPathWithIndexes:newIndexPath length:3]];
			[commandBundleTreeController rearrangeObjects];
			[commandsOutlineView reloadData];
		}
	}

	[oldScope release];

	[self _updateInputPopupButton];

}

- (IBAction)duplicateCommandBundle:(id)sender
{
	if ([commandsOutlineView numberOfSelectedRows] == 1)
		[self addCommandBundle:self];
	else
		NSBeep();
}

- (IBAction)addCommandBundle:(id)sender
{
	NSMutableDictionary *bundle;
	NSUInteger insertIndex;

	// Store pending changes in Query
	[[self window] makeFirstResponder:nameTextField];

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
			newFileName = [NSString stringWithFormat:@"%@_%ld", newFileName, (NSUInteger)(random() % 35000)];
			newBundleFilePath = [NSString stringWithFormat:@"%@/%@.%@", bundlePath, newFileName, SPUserBundleFileExtension];
			if([[NSFileManager defaultManager] fileExistsAtPath:possibleExisitingBundleFilePath isDirectory:&isDir] && isDir) {
				if([[NSFileManager defaultManager] copyItemAtPath:possibleExisitingBundleFilePath toPath:newBundleFilePath error:nil])
					copyingWasSuccessful = YES;
			}
		}
		if(!copyingWasSuccessful) {

			[commandsOutlineView reloadData];

			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error", @"error")
											 defaultButton:NSLocalizedString(@"OK", @"OK button") 
										   alternateButton:nil 
											  otherButton:nil 
								informativeTextWithFormat:NSLocalizedString(@"Error while duplicating Bundle content.", @"error while duplicating Bundle content")];
		
			[alert setAlertStyle:NSCriticalAlertStyle];
			[alert runModal];

			return;

		}
		[bundle setObject:newFileName forKey:kBundleNameKey];

		// Insert duplicate below selected one
		NSUInteger *currentPath[[currentIndexPath length]];
		[currentIndexPath getIndexes:&currentPath];
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
			NSUInteger *newPath[3];
			[currentIndexPath getIndexes:&newPath];
			newPath[2] = 0;
			currentIndexPath = [NSIndexPath indexPathWithIndexes:newPath length:3];
			lastIndexWasAlreadyFixed = YES;
		}
		// If selected item is a category go one item deeper
		else if([currentIndexPath length] == 3 && [currentObject objectForKey:kChildrenKey]) {
			NSUInteger *newPath[4];
			[currentIndexPath getIndexes:&newPath];
			newPath[3] = 0;
			currentIndexPath = [NSIndexPath indexPathWithIndexes:newPath length:4];
			lastIndexWasAlreadyFixed = YES;
			category = [currentObject objectForKey:kBundleNameKey];
		}

		NSUInteger *currentPath[[currentIndexPath length]];
		[currentIndexPath getIndexes:&currentPath];

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

		bundle = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"New Bundle", @"New Name", @"", scope, category, nil] 
						forKeys:[NSArray arrayWithObjects:kBundleNameKey, SPBundleFileNameKey, SPBundleFileCommandKey, SPBundleFileScopeKey, SPBundleFileCategoryKey, nil]];
	}

	if(![touchedBundleArray containsObject:[bundle objectForKey:kBundleNameKey]])
		[touchedBundleArray addObject:[bundle objectForKey:kBundleNameKey]];

	[commandBundleTreeController insertObject:bundle atArrangedObjectIndexPath:currentIndexPath];

	[commandBundleTreeController rearrangeObjects];
	[commandsOutlineView reloadData];

	[commandsOutlineView scrollRowToVisible:[commandsOutlineView selectedRow]];

	[removeButton setEnabled:([[commandBundleTreeController selectedObjects] count] == 1 && ![[[commandBundleTreeController selectedObjects] objectAtIndex:0] objectForKey:kChildrenKey])];
	[addButton setEnabled:([[commandBundleTreeController selectionIndexPath] length] > 1)];

	[self _updateInputPopupButton];

	[[self window] makeFirstResponder:commandsOutlineView];

}

- (IBAction)removeCommandBundle:(id)sender
{
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Remove selected Bundle?", @"remove selected bundle message") 
									 defaultButton:NSLocalizedString(@"Remove", @"remove button")
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to move the selected Bundle to the Trash and remove them respectively?", @"move to trash and remove resp the selected bundle informative message")];

	[alert setAlertStyle:NSCriticalAlertStyle];
	
	NSArray *buttons = [alert buttons];
	
	// Change the alert's cancel button to have the key equivalent of return
	[[buttons objectAtIndex:0] setKeyEquivalent:@"r"];
	[[buttons objectAtIndex:0] setKeyEquivalentModifierMask:NSCommandKeyMask];
	[[buttons objectAtIndex:1] setKeyEquivalent:@"\r"];
	
	[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"removeSelectedBundles"];

}

- (IBAction)revealCommandBundleInFinder:(id)sender
{

	if([commandsOutlineView numberOfSelectedRows] != 1) return;

	[[NSWorkspace sharedWorkspace] selectFile:[NSString stringWithFormat:@"%@/%@.%@/%@", 
		bundlePath, [[self _currentSelectedObject] objectForKey:kBundleNameKey], SPUserBundleFileExtension, SPBundleFileName] inFileViewerRootedAtPath:nil];

}

- (IBAction)saveBundle:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setRequiredFileType:SPUserBundleFileExtension];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:NO];
	[panel setCanSelectHiddenExtension:YES];
	[panel setCanCreateDirectories:YES];

	[panel beginSheetForDirectory:nil file:[[self _currentSelectedObject] objectForKey:kBundleNameKey] modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"saveBundle"];
}

- (IBAction)showHelp:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:NSLocalizedString(@"http://www.sequelpro.com/docs/Bundle_Editor", @"Localized help page for bundle editor - do not localize if no translated webpage is available")]];
}

- (IBAction)reloadBundles:(id)sender
{
	[self showWindow:self];
}

- (IBAction)showWindow:(id)sender
{

	// Suppress parsing if window is already opened
	if(sender != self && [[self window] isVisible]) {
		[super showWindow:sender];
		return;
	}



	// Order out window
	[super showWindow:sender];

	// Re-init commandBundleArray
	[commandBundleArray removeAllObjects];
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

				NSError *readError = nil;
				NSString *convError = nil;
				NSPropertyListFormat format;
				NSDictionary *cmdData = nil;
				NSString *infoPath = [NSString stringWithFormat:@"%@/%@/%@", bundlePath, bundle, SPBundleFileName];
				NSData *pData = [NSData dataWithContentsOfFile:infoPath options:NSUncachedRead error:&readError];

				cmdData = [[NSPropertyListSerialization propertyListFromData:pData 
						mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError] retain];

				if(!cmdData || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {
					NSLog(@"“%@/%@” file couldn't be read.", bundle, SPBundleFileName);
					NSBeep();
					if (cmdData) [cmdData release];
				} else {
					if([cmdData objectForKey:SPBundleFileNameKey] && [[cmdData objectForKey:SPBundleFileNameKey] length] && [cmdData objectForKey:SPBundleFileScopeKey])
					{
						NSMutableDictionary *bundleCommand = [NSMutableDictionary dictionary];
						[bundleCommand addEntriesFromDictionary:cmdData];
						[bundleCommand setObject:[bundle stringByDeletingPathExtension] forKey:kBundleNameKey];

						[commandBundleArray addObject:bundleCommand];
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

	[commandBundleTreeController setContent:commandBundleTree];
	[commandBundleTreeController rearrangeObjects];
	[commandsOutlineView reloadData];
	[commandsOutlineView expandItem:nil expandChildren:YES];

}

- (IBAction)saveAndCloseWindow:(id)sender
{

	// Commit all pending edits
	if([commandBundleTreeController commitEditing]) {

		// Get all Bundles out of commandBundleTree which were touched
		NSMutableArray *allBundles = [NSMutableArray array];
		for(NSInteger k = 0; k < [[commandBundleTree objectForKey:kChildrenKey] count]; k++) {
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
				NSString *newName = [NSString stringWithFormat:@"%@_%ld", [item objectForKey:kBundleNameKey], (NSUInteger)(random() % 35000)];
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
				NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while saving “%@”.", @"error while saving “%@”"), [item objectForKey:kBundleNameKey]]
												 defaultButton:NSLocalizedString(@"OK", @"OK button") 
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

	[[NSApp delegate] reloadBundles:self];

}

- (BOOL)saveBundle:(NSDictionary*)bundle atPath:(NSString*)aPath
{

	NSFileManager *fm = [NSFileManager defaultManager];
	BOOL isDir = NO;

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
	}
	
	// If aPath exists but it's not a folder bail out
	if(!isDir) return NO;

	// The command.plist file path
	NSString *cmdFilePath = [NSString stringWithFormat:@"%@/%@", aPath, SPBundleFileName];

	NSMutableDictionary *saveDict = [NSMutableDictionary dictionary];
	[saveDict addEntriesFromDictionary:bundle];

	// Remove unnecessary keys
	[saveDict removeObjectsForKeys:[NSArray arrayWithObjects:
		kBundleNameKey,
		nil]];

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
					NSString *trashDir = [NSHomeDirectory() stringByAppendingPathComponent:@".Trash"];

					// Use a AppleScript script since NSWorkspace performFileOperation or NSFileManager moveItemAtPath 
					// have problems probably due access rights.
					NSString *moveToTrashCommand = [NSString stringWithFormat:@"osascript -e 'tell application \"Finder\" to move (POSIX file \"%@\") to the trash'", thePath];
					[moveToTrashCommand runBashCommandWithEnvironment:nil atCurrentDirectoryPath:nil error:&error];
					if(error != nil) {
						NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while moving “%@” to Trash.", @"error while moving “%@” to trash"), thePath]
														 defaultButton:NSLocalizedString(@"OK", @"OK button") 
													   alternateButton:nil 
														  otherButton:nil 
											informativeTextWithFormat:[error localizedDescription]];
					
						[alert setAlertStyle:NSCriticalAlertStyle];
						[alert runModal];
						deletionSuccessfully = NO;
						break;
					}
					[commandsOutlineView reloadData];
				}
			}

			if(deletionSuccessfully) {
				[commandBundleTreeController removeObjectsAtArrangedObjectIndexPaths:selIndexPaths];
				[commandBundleTreeController rearrangeObjects];
			} else {
				[self reloadBundles:self];
			}

			// Set focus to table view to avoid an unstable state
			[[self window] makeFirstResponder:commandsOutlineView];

			[removeButton setEnabled:([[commandBundleTreeController selectedObjects] count] == 1 && ![[[commandBundleTreeController selectedObjects] objectAtIndex:0] objectForKey:kChildrenKey])];
			[addButton setEnabled:([[commandBundleTreeController selectionIndexPath] length] > 1)];

		}
	} else if([contextInfo isEqualToString:@"saveBundle"]) {
		if (returnCode == NSOKButton) {

			id aBundle = [self _currentSelectedObject];

			NSString *bundleFileName = [aBundle objectForKey:kBundleNameKey];
			NSString *possibleExisitingBundleFilePath = [NSString stringWithFormat:@"%@/%@.%@", bundlePath, bundleFileName, SPUserBundleFileExtension];

			NSString *savePath = [sheet filename];

			BOOL isDir;
			BOOL copyingWasSuccessful = YES;
			// Copy possible existing bundle with content
			if([[NSFileManager defaultManager] fileExistsAtPath:possibleExisitingBundleFilePath isDirectory:&isDir] && isDir) {
				if(![[NSFileManager defaultManager] copyItemAtPath:possibleExisitingBundleFilePath toPath:savePath error:nil])
					copyingWasSuccessful = NO;
			}
			if(!copyingWasSuccessful || ![self saveBundle:aBundle atPath:savePath]) {
				NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error while saving the Bundle.", @"error while saving a Bundle")
												 defaultButton:NSLocalizedString(@"OK", @"OK button") 
											   alternateButton:nil 
												  otherButton:nil 
									informativeTextWithFormat:@""];
			
				[alert setAlertStyle:NSCriticalAlertStyle];
				[alert runModal];
			}
		}
	}

}

#pragma mark -
#pragma mark NSWindow delegate

/**
 * Suppress closing of the window if user pressed ESC while inline table cell editing.
 */
- (BOOL)windowShouldClose:(id)sender
{

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
	// Clear commandBundleArray if window will close to save memory
	[commandBundleArray removeAllObjects];
	[touchedBundleArray removeAllObjects];
	[[[commandBundleTree objectForKey:kChildrenKey] objectAtIndex:0] setObject:[NSMutableArray array] forKey:kChildrenKey];
	[[[commandBundleTree objectForKey:kChildrenKey] objectAtIndex:1] setObject:[NSMutableArray array] forKey:kChildrenKey];
	[[[commandBundleTree objectForKey:kChildrenKey] objectAtIndex:2] setObject:[NSMutableArray array] forKey:kChildrenKey];
	[commandsOutlineView reloadData];

	// Remove temporary drag file if any
	if(draggedFilePath) {
		[[NSFileManager defaultManager] removeItemAtPath:draggedFilePath error:nil];
		[draggedFilePath release];
		draggedFilePath = nil;
	}
	if(oldBundleName) [oldBundleName release], oldBundleName = nil;

	return YES;
}

#pragma mark -
#pragma mark SRRecorderControl delegate

- (void)shortcutRecorder:(SRRecorderControl *)aRecorder keyComboDidChange:(KeyCombo)newKeyCombo
{

	if([commandsOutlineView selectedRow] < 0) return;

	// Transform KeyCombo struct to KeyBinding.dict format for NSMenuItems
	NSMutableString *keyEq = [NSMutableString string];
	NSString *theChar = [[aRecorder keyCharsIgnoringModifiers] lowercaseString];
	[keyEq setString:@""];
	if(newKeyCombo.code > -1) {
		if(newKeyCombo.flags & NSControlKeyMask)
			[keyEq appendString:@"^"];
		if(newKeyCombo.flags & NSAlternateKeyMask)
			[keyEq appendString:@"~"];
		if(newKeyCombo.flags & NSShiftKeyMask) {
			[keyEq appendString:@"$"];
			theChar = [theChar uppercaseString];
		}
		if(newKeyCombo.flags & NSCommandKeyMask)
			[keyEq appendString:@"@"];
		[keyEq appendString:theChar];
	}
	[[self _currentSelectedObject] setObject:keyEq forKey:SPBundleFileKeyEquivalentKey];

}

#pragma mark -
#pragma mark outline delegates


- (BOOL)outlineView:(id)outlineView isItemExpandable:(id)item
{
	if([item isKindOfClass:[NSDictionary class]] && [item objectForKey:kChildrenKey])
		return YES;

	return NO;
}

- (NSInteger)outlineView:(id)outlineView numberOfChildrenOfItem:(id)item
{

	if(item == nil)
		item = commandBundleTree;
	
	if([item isKindOfClass:[NSDictionary class]])
		if([item objectForKey:kChildrenKey])
			return [[item objectForKey:kChildrenKey] count];
		else
			return [item count];

	if([item isKindOfClass:[NSArray class]])
		return [item count];
	
	return 0;
}

- (id)outlineView:(id)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{

	if(item && [item respondsToSelector:@selector(objectForKey:)])
		return [item objectForKey:kBundleNameKey];
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

- (void)outlineViewSelectionDidChange:(NSNotification *)aNotification
{

	if([aNotification object] != commandsOutlineView) return;

	if(oldBundleName) [oldBundleName release], oldBundleName = nil;
	if(![[self _currentSelectedObject] objectForKey:kChildrenKey])
		oldBundleName = [[[self _currentSelectedObject] objectForKey:kBundleNameKey] retain];
	else
		if(oldBundleName) [oldBundleName release], oldBundleName = nil;
		
	if(oldBundleName != nil && ![touchedBundleArray containsObject:oldBundleName])
		[touchedBundleArray addObject:oldBundleName];
	[self _updateInputPopupButton];

}

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
	if([commandsOutlineView numberOfSelectedRows] != 1 || [items count] != 1 ||
		![[items objectAtIndex:0] isLeaf]) return NO;

	// Remove old temporary drag file if any
	if(draggedFilePath) {
		[[NSFileManager defaultManager] removeItemAtPath:draggedFilePath error:nil];
		[draggedFilePath release];
		draggedFilePath = nil;
	}

	NSImage *dragImage;
	NSPoint dragPosition;

	NSDictionary *bundleDict = [[items objectAtIndex:0] representedObject];
	NSString *bundleFileName = [bundleDict objectForKey:kBundleNameKey];
	NSString *possibleExisitingBundleFilePath = [NSString stringWithFormat:@"%@/%@.%@", bundlePath, bundleFileName, SPUserBundleFileExtension];

	draggedFilePath = [[NSString stringWithFormat:@"/tmp/%@.%@", bundleFileName, SPUserBundleFileExtension] retain];

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
	[pboard declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:nil];
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
#pragma mark TableView delegate

/*
 * Save spBundle name if inline edited (suppress empty names) and check for renaming and / in the name
 */
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
			if(!isValid) {
				[[self _currentSelectedObject] setObject:oldBundleName forKey:kBundleNameKey];
			}

			[commandBundleTreeController rearrangeObjects];
			[commandsOutlineView reloadData];

			if(oldBundleName) [oldBundleName release], oldBundleName = nil;
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
		NSUInteger *newIndexPath[[currentIndexPath length]];
		[currentIndexPath getIndexes:&newIndexPath];

		// Set the category index
		newIndexPath[2] = (NSUInteger)[self _arrangedCategoryIndexForScopeIndex:scopeIndex andCategory:[categoryTextField stringValue]];

		[commandBundleTreeController moveNode:[self _currentSelectedNode] toIndexPath:[NSIndexPath indexPathWithIndexes:newIndexPath length:[currentIndexPath length]]];
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
	
	if ( (action == @selector(duplicateCommandBundle:)) 
		|| (action == @selector(revealCommandBundleInFinder:))
		|| (action == @selector(saveBundle:))
		|| (action == @selector(removeCommandBundle:))
		) 
	{
		// Allow to record short-cuts used by the Bundle Editor
		if([[NSApp mainWindow] firstResponder] == keyEquivalentField) return NO;
		return ([[commandBundleTreeController selectedObjects] count] == 1 && ![[[commandBundleTreeController selectedObjects] objectAtIndex:0] objectForKey:kChildrenKey]);
	}

	return YES;

}

#pragma mark -
#pragma mark TableView drag & drop delegate methods

/**
 * Allow for drag-n-drop out of the application as a copy
 */
- (NSUInteger)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return NSDragOperationMove;
}


/**
 * Drag a table row item as spBundle
 */
- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rows toPasteboard:(NSPasteboard*)aPboard
{

	if([commandsOutlineView numberOfSelectedRows] != 1 || [rows count] != 1) return NO;

	// Remove old temporary drag file if any
	if(draggedFilePath) {
		[[NSFileManager defaultManager] removeItemAtPath:draggedFilePath error:nil];
		[draggedFilePath release];
		draggedFilePath = nil;
	}

	NSImage *dragImage;
	NSPoint dragPosition;

	NSDictionary *bundleDict = [commandsOutlineView itemAtRow:[rows firstIndex]];
	NSString *bundleFileName = [bundleDict objectForKey:kBundleNameKey];
	NSString *possibleExisitingBundleFilePath = [NSString stringWithFormat:@"%@/%@.%@", bundlePath, bundleFileName, SPUserBundleFileExtension];

	draggedFilePath = [[NSString stringWithFormat:@"/tmp/%@.%@", bundleFileName, SPUserBundleFileExtension] retain];


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
	NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	[pboard declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:nil];
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

		[self performSelector:@selector(setAllowedUndo) withObject:nil afterDelay:0.09];
	}
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

@end

#pragma mark -

@implementation SPBundleEditorController (PrivateAPI)

- (void)_updateInputPopupButton
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

	if([scope isEqualToString:SPBundleScopeGeneral])
		[scopePopupButton selectItemWithTag:kGeneralScopeArrayIndex];
	else if([scope isEqualToString:SPBundleScopeInputField])
		[scopePopupButton selectItemWithTag:kInputFieldScopeArrayIndex];
	else if([scope isEqualToString:SPBundleScopeDataTable])
		[scopePopupButton selectItemWithTag:kDataTableScopeArrayIndex];
	else
		[scopePopupButton selectItemWithTag:kDisabledScopeTag];

	[currentDict setObject:[NSNumber numberWithBool:NO] forKey:SPBundleFileDisabledKey];

	switch([[scopePopupButton selectedItem] tag]) {
		case kGeneralScopeArrayIndex: // General
		[inputPopupButton setMenu:inputNonePopUpMenu];
		[inputPopupButton selectItemAtIndex:0];
		[outputPopupButton setMenu:outputGeneralScopePopUpMenu];
		anIndex = [outputGeneralScopeArray indexOfObject:output];
		if(anIndex == NSNotFound) anIndex = 0;
		[outputPopupButton selectItemAtIndex:anIndex];
		input = SPBundleInputSourceNone;
		[inputFallbackPopupButton setHidden:YES];
		[fallbackLabelField setHidden:YES];
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
		input = SPBundleInputSourceNone;
		[inputFallbackPopupButton setHidden:YES];
		[fallbackLabelField setHidden:YES];
		break;
		case kDisabledScopeTag: // Disable command
		[currentDict setObject:[NSNumber numberWithBool:YES] forKey:SPBundleFileDisabledKey];
		break;
		default:
		[inputPopupButton setMenu:inputNonePopUpMenu];
		[inputPopupButton selectItemAtIndex:0];
		[outputPopupButton setMenu:outputGeneralScopePopUpMenu];
		anIndex = [outputGeneralScopeArray indexOfObject:output];
		if(anIndex == NSNotFound) anIndex = 0;
		[outputPopupButton selectItemAtIndex:anIndex];
	}

	if([input isEqualToString:SPBundleInputSourceSelectedText]) {
		[inputFallbackPopupButton setHidden:NO];
		[fallbackLabelField setHidden:NO];
	} else {
		[inputFallbackPopupButton setHidden:YES];
		[fallbackLabelField setHidden:YES];
	}

	[removeButton setEnabled:([[commandBundleTreeController selectedObjects] count] == 1 && ![[[commandBundleTreeController selectedObjects] objectAtIndex:0] objectForKey:kChildrenKey])];
	[addButton setEnabled:([[commandBundleTreeController selectionIndexPath] length] > 1)];

}

- (id)_currentSelectedObject
{
	return [[commandsOutlineView itemAtRow:[commandsOutlineView selectedRow]] representedObject];
}
- (id)_currentSelectedNode

{
	return [commandsOutlineView itemAtRow:[commandsOutlineView selectedRow]];
}

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

- (NSUInteger)_arrangedCategoryIndexForScopeIndex:(NSUInteger)scopeIndex andCategory:(NSString*)category
{
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
				NSMutableDictionary *newCat = [NSMutableDictionary dictionary];
				[newCat setObject:category forKey:kBundleNameKey];
				[newCat setObject:[NSMutableArray array] forKey:kChildrenKey];
				NSUInteger *newPath[3];
				newPath[0] = 0;
				newPath[1] = k;
				newPath[2] = 0;
				[[[j representedObject] objectForKey:kChildrenKey] addObject:newCat];
				[commandBundleTreeController rearrangeObjects];
				[commandsOutlineView reloadData];
				return [self _arrangedCategoryIndexForScopeIndex:scopeIndex andCategory:category];

			}
			k++;
		}
		return 0;
	}

	return returnIndex;
}

@end

