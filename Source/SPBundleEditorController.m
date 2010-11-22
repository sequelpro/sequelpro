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


@interface SPBundleEditorController (PrivateAPI)

- (void)_updateInputPopupButton;

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
		draggedFilePath = nil;
		oldBundleName = nil;
		isTableCellEditing = NO;
		bundlePath = [[[NSFileManager defaultManager] applicationSupportDirectoryForSubDirectory:SPBundleSupportFolder createIfNotExists:NO error:nil] retain];
	}
	
	return self;

}

- (void)dealloc
{

	[inputEditorScopePopUpMenu release];
	[inputInputFieldScopePopUpMenu release];
	[inputDataTableScopePopUpMenu release];
	[outputEditorScopePopUpMenu release];
	[outputInputFieldScopePopUpMenu release];
	[outputDataTableScopePopUpMenu release];
	[inputFallbackEditorScopePopUpMenu release];
	[inputFallbackInputFieldScopePopUpMenu release];
	[inputNonePopUpMenu release];

	[inputEditorScopeArray release];
	[inputInputFieldScopeArray release];
	[inputDataTableScopeArray release];
	[outputEditorScopeArray release];
	[outputInputFieldScopeArray release];
	[outputDataTableScopeArray release];
	[inputFallbackEditorScopeArray release];
	[inputFallbackInputFieldScopeArray release];

	if(commandBundleArray) [commandBundleArray release], commandBundleArray = nil;
	if(bundlePath) [bundlePath release], bundlePath = nil;

	[super dealloc];

}

- (void)awakeFromNib
{

	// Init all needed menus
	inputEditorScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	inputInputFieldScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	inputDataTableScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	inputNonePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	outputEditorScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	outputInputFieldScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	outputDataTableScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	inputFallbackEditorScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];
	inputFallbackInputFieldScopePopUpMenu = [[NSMenu alloc] initWithTitle:@""];

	inputEditorScopeArray = [[NSArray arrayWithObjects:SPBundleInputSourceNone, SPBundleInputSourceSelectedText, SPBundleInputSourceEntireContent, nil] retain];
	inputInputFieldScopeArray = [[NSArray arrayWithObjects:SPBundleInputSourceNone, SPBundleInputSourceSelectedText, SPBundleInputSourceEntireContent, nil] retain];
	inputDataTableScopeArray = [[NSArray arrayWithObjects:SPBundleInputSourceNone, SPBundleInputSourceSelectedTableRowsAsTab, SPBundleInputSourceSelectedTableRowsAsCsv, SPBundleInputSourceSelectedTableRowsAsSqlInsert, SPBundleInputSourceTableRowsAsTab, SPBundleInputSourceTableRowsAsCsv, SPBundleInputSourceTableRowsAsSqlInsert, nil] retain];
	outputEditorScopeArray = [[NSArray arrayWithObjects:SPBundleOutputActionNone, SPBundleOutputActionInsertAsText, SPBundleOutputActionInsertAsSnippet, SPBundleOutputActionReplaceSelection, SPBundleOutputActionReplaceContent, SPBundleOutputActionShowAsTextTooltip, SPBundleOutputActionShowAsHTMLTooltip, SPBundleOutputActionShowAsHTML, nil] retain];
	outputInputFieldScopeArray = [[NSArray arrayWithObjects:SPBundleOutputActionNone, SPBundleOutputActionInsertAsText, SPBundleOutputActionReplaceSelection, SPBundleOutputActionReplaceContent, SPBundleOutputActionShowAsTextTooltip, SPBundleOutputActionShowAsHTMLTooltip, SPBundleOutputActionShowAsHTML, nil] retain];
	outputDataTableScopeArray = [[NSArray arrayWithObjects:SPBundleOutputActionNone, SPBundleOutputActionShowAsTextTooltip, SPBundleOutputActionShowAsHTMLTooltip, SPBundleOutputActionShowAsHTML, nil] retain];
	inputFallbackEditorScopeArray = [[NSArray arrayWithObjects:SPBundleInputSourceNone, SPBundleInputSourceCurrentWord, SPBundleInputSourceCurrentLine, SPBundleInputSourceCurrentQuery, SPBundleInputSourceEntireContent, nil] retain];
	inputFallbackInputFieldScopeArray = [[NSArray arrayWithObjects:SPBundleInputSourceNone, SPBundleInputSourceCurrentWord, SPBundleInputSourceCurrentLine, SPBundleInputSourceEntireContent, nil] retain];

	NSMutableArray *allPopupScopeItems = [NSMutableArray array];
	[allPopupScopeItems addObjectsFromArray:inputEditorScopeArray];
	[allPopupScopeItems addObjectsFromArray:inputInputFieldScopeArray];
	[allPopupScopeItems addObjectsFromArray:inputDataTableScopeArray];
	[allPopupScopeItems addObjectsFromArray:outputEditorScopeArray];
	[allPopupScopeItems addObjectsFromArray:outputInputFieldScopeArray];
	[allPopupScopeItems addObjectsFromArray:outputDataTableScopeArray];
	[allPopupScopeItems addObjectsFromArray:inputFallbackEditorScopeArray];
	[allPopupScopeItems addObjectsFromArray:inputFallbackInputFieldScopeArray];

	NSDictionary *menuItemTitles = [NSDictionary dictionaryWithObjects:
						[NSArray arrayWithObjects:
							NSLocalizedString(@"None", @"none menu item label"),
							NSLocalizedString(@"Selected Text", @"selected text menu item label"),
							NSLocalizedString(@"Entire Content", @"entire content menu item label"),
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
							NSLocalizedString(@"Insert as Text", @"insert as text item label"),
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
							NSLocalizedString(@"Current Word", @"current word item label"),
							NSLocalizedString(@"Current Line", @"current line item label"),
							NSLocalizedString(@"Current Query", @"current query item label"),
							NSLocalizedString(@"Entire Content", @"entire content item label"),
							NSLocalizedString(@"None", @"none menu item label"),
							NSLocalizedString(@"Current Word", @"current word item label"),
							NSLocalizedString(@"Current Line", @"current line item label"),
							NSLocalizedString(@"Entire Content", @"entire content item label"),
						nil]
					forKeys:allPopupScopeItems];

	NSMenuItem *anItem;
	for(NSString* title in inputEditorScopeArray) {
		anItem = [[NSMenuItem alloc] initWithTitle:[menuItemTitles objectForKey:title] action:@selector(inputPopupButtonChanged:) keyEquivalent:@""];
		[inputEditorScopePopUpMenu addItem:anItem];
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
	for(NSString* title in outputEditorScopeArray) {
		anItem = [[NSMenuItem alloc] initWithTitle:[menuItemTitles objectForKey:title] action:@selector(outputPopupButtonChanged:) keyEquivalent:@""];
		[outputEditorScopePopUpMenu addItem:anItem];
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
	for(NSString* title in inputFallbackEditorScopeArray) {
		anItem = [[NSMenuItem alloc] initWithTitle:[menuItemTitles objectForKey:title] action:@selector(inputFallbackPopupButtonChanged:) keyEquivalent:@""];
		[inputFallbackEditorScopePopUpMenu addItem:anItem];
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

	[keyEquivalentField setCanCaptureGlobalHotKeys:YES];

}

#pragma mark -

- (IBAction)inputPopupButtonChanged:(id)sender
{

	id currentDict = [commandBundleArray objectAtIndex:[commandsTableView selectedRow]];

	NSMenu* senderMenu = [sender menu];

	NSInteger selectedIndex = [senderMenu indexOfItem:sender];
	NSString *input = SPBundleInputSourceNone;
	if(senderMenu == inputEditorScopePopUpMenu)
		input = [inputEditorScopeArray objectAtIndex:selectedIndex];
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

	id currentDict = [commandBundleArray objectAtIndex:[commandsTableView selectedRow]];

	NSMenu* senderMenu = [sender menu];

	NSInteger selectedIndex = [senderMenu indexOfItem:sender];
	NSString *input = SPBundleInputSourceNone;
	if(senderMenu == inputFallbackEditorScopePopUpMenu)
		input = [inputFallbackEditorScopeArray objectAtIndex:selectedIndex];
	else if(senderMenu == inputFallbackInputFieldScopePopUpMenu)
		input = [inputFallbackInputFieldScopeArray objectAtIndex:selectedIndex];

	[currentDict setObject:input forKey:SPBundleFileInputSourceFallBackKey];

}

- (IBAction)outputPopupButtonChanged:(id)sender
{

	id currentDict = [commandBundleArray objectAtIndex:[commandsTableView selectedRow]];

	NSMenu* senderMenu = [sender menu];

	NSInteger selectedIndex = [senderMenu indexOfItem:sender];
	NSString *output = SPBundleOutputActionNone;
	if(senderMenu == outputEditorScopePopUpMenu)
		output = [outputEditorScopeArray objectAtIndex:selectedIndex];
	else if(senderMenu == outputInputFieldScopePopUpMenu)
		output = [outputInputFieldScopeArray objectAtIndex:selectedIndex];
	else if(senderMenu == outputDataTableScopePopUpMenu)
		output = [outputDataTableScopeArray objectAtIndex:selectedIndex];

	[currentDict setObject:output forKey:SPBundleFileOutputActionKey];

}

- (IBAction)scopeButtonChanged:(id)sender
{

	id currentDict = [commandBundleArray objectAtIndex:[commandsTableView selectedRow]];
	NSInteger inputMask = [[currentDict objectForKey:SPBundleScopeQueryEditor] intValue] * 1 +
						[[currentDict objectForKey:SPBundleScopeInputField] intValue] * 2 +
						[[currentDict objectForKey:SPBundleScopeDataTable] intValue] * 4;

	if(inputMask < 1 || inputMask > 7) {
		inputMask = 7;
		NSNumber *on = [NSNumber numberWithInt:1];
		[currentDict setObject:on forKey:SPBundleScopeQueryEditor];
		[currentDict setObject:on forKey:SPBundleScopeInputField];
		[currentDict setObject:on forKey:SPBundleScopeDataTable];
	}

	[currentDict setObject:[NSNumber numberWithInt:inputMask] forKey:@"inputMask"];

	if(inputMask > 4) {
		[currentDict setObject:SPBundleInputSourceNone forKey:SPBundleFileInputSourceKey];
		[currentDict setObject:SPBundleInputSourceNone forKey:SPBundleFileInputSourceFallBackKey];
		if(![[currentDict objectForKey:SPBundleFileOutputActionKey] isEqualToString:SPBundleOutputActionShowAsTextTooltip] 
			&& ![[currentDict objectForKey:SPBundleFileOutputActionKey] isEqualToString:SPBundleOutputActionShowAsHTMLTooltip]) {
			[currentDict setObject:SPBundleOutputActionNone forKey:SPBundleFileOutputActionKey];
		}

	}
	if([[currentDict objectForKey:SPBundleFileInputSourceKey] isEqualToString:SPBundleInputSourceSelectedText]) {
		if(inputMask > 1 && [[currentDict objectForKey:SPBundleFileInputSourceFallBackKey] isEqualToString:SPBundleInputSourceCurrentQuery])
			[currentDict setObject:SPBundleInputSourceNone forKey:SPBundleFileInputSourceFallBackKey];
	}
	if((inputMask == 2 || inputMask == 3) && [[currentDict objectForKey:SPBundleFileOutputActionKey] isEqualToString:SPBundleOutputActionInsertAsSnippet])
		[currentDict setObject:SPBundleOutputActionInsertAsText forKey:SPBundleFileOutputActionKey];

	[self _updateInputPopupButton];

}

- (IBAction)duplicateCommandBundle:(id)sender
{
	if ([commandsTableView numberOfSelectedRows] == 1)
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

	// Duplicate a selected Bundle if sender == self
	if (sender == self) {
		NSDictionary *currentDict = [commandBundleArray objectAtIndex:[commandsTableView selectedRow]];
		bundle = [NSMutableDictionary dictionaryWithDictionary:currentDict];

		NSString *bundleFileName = [bundle objectForKey:@"bundleName"];
		NSString *newFileName = [NSString stringWithFormat:@"%@_Copy", [bundle objectForKey:@"bundleName"]];
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

			[commandsTableView reloadData];

			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Error", @"error")
											 defaultButton:NSLocalizedString(@"OK", @"OK button") 
										   alternateButton:nil 
											  otherButton:nil 
								informativeTextWithFormat:NSLocalizedString(@"Error while duplicating Bundle content.", @"error while duplicating Bundle content")];
		
			[alert setAlertStyle:NSCriticalAlertStyle];
			[alert runModal];

			return;

		}

		[bundle setObject:newFileName forKey:@"bundleName"];

	}
	// Add a new Bundle
	else {
		bundle = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"New Bundle", @"New Name", @"", SPBundleScopeInputField, [NSNumber numberWithInt:1], nil] 
						forKeys:[NSArray arrayWithObjects:@"bundleName", SPBundleFileNameKey, SPBundleFileCommandKey, SPBundleFileScopeKey, SPBundleScopeInputField, nil]];
	}
	if ([commandsTableView numberOfSelectedRows] > 0) {
		insertIndex = [[commandsTableView selectedRowIndexes] lastIndex]+1;
		[commandBundleArray insertObject:bundle atIndex:insertIndex];
	} 
	else {
		[commandBundleArray addObject:bundle];
		insertIndex = [commandBundleArray count] - 1;
	}

	[commandBundleArrayController rearrangeObjects];
	[commandsTableView reloadData];

	[commandsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:insertIndex] byExtendingSelection:NO];
	
	[commandsTableView scrollRowToVisible:[commandsTableView selectedRow]];

	[removeButton setEnabled:([commandsTableView numberOfSelectedRows] > 0)];
	[[self window] makeFirstResponder:commandsTableView];
	[self scopeButtonChanged:nil];
	if([commandsTableView numberOfSelectedRows] > 0)
		[commandsTableView editColumn:0 row:insertIndex withEvent:nil select:YES];
}

- (IBAction)removeCommandBundle:(id)sender
{
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Remove selected Bundles?", @"remove selected bundles message") 
									 defaultButton:NSLocalizedString(@"Remove", @"remove button")
								   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"Are you sure you want to move all selected Bundles to the Trash and remove them respectively?", @"move to trash and remove resp all selected bundles informative message")];

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

	if([commandsTableView numberOfSelectedRows] != 1) return;

	[[NSWorkspace sharedWorkspace] selectFile:[NSString stringWithFormat:@"%@/%@.%@/%@", 
		bundlePath, [[commandBundleArray objectAtIndex:[commandsTableView selectedRow]] objectForKey:@"bundleName"], SPUserBundleFileExtension, SPBundleFileName] inFileViewerRootedAtPath:nil];

}

- (IBAction)saveBundle:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setRequiredFileType:SPUserBundleFileExtension];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:NO];
	[panel setCanSelectHiddenExtension:YES];
	[panel setCanCreateDirectories:YES];

	[panel beginSheetForDirectory:nil file:[[commandBundleArray objectAtIndex:[commandsTableView selectedRow]] objectForKey:@"bundleName"] modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:@"saveBundle"];
}

- (IBAction)showHelp:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:NSLocalizedString(@"http://www.sequelpro.com/docs/Bundle_Editor", @"Localized help page for bundle editor - do not localize if no translated webpage is available")]];
}

- (IBAction)showWindow:(id)sender
{

	// Suppress parsing if window is already opened
	if([[self window] isVisible]) {
		[super showWindow:sender];
		return;
	}



	// Order out window
	[super showWindow:sender];

	// Re-init commandBundleArray
	if(commandBundleArray) [commandBundleArray release], commandBundleArray = nil;
	commandBundleArray = [[NSMutableArray alloc] init];

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
						[bundleCommand setObject:[bundle stringByDeletingPathExtension] forKey:@"bundleName"];

						NSInteger inputMask = 0;

						// Handle stored scopes
						NSArray *scopes = [[cmdData objectForKey:SPBundleFileScopeKey] componentsSeparatedByString:@" "];
						for(NSString *scope in scopes) {
							[bundleCommand setObject:[NSNumber numberWithInt:1] forKey:scope];
							if([scope isEqualToString:SPBundleScopeQueryEditor]) inputMask += 1;
							if([scope isEqualToString:SPBundleScopeInputField]) inputMask += 2;
							if([scope isEqualToString:SPBundleScopeDataTable]) inputMask += 4;
							[bundleCommand setObject:[NSNumber numberWithInt:inputMask] forKey:@"inputMask"];
						}

						[commandBundleArray addObject:bundleCommand];

					}
					if (cmdData) [cmdData release];
				}
			}
		}
	}

	[commandBundleArrayController setContent:commandBundleArray];
	[commandBundleArrayController rearrangeObjects];
	[commandsTableView reloadData];

}

- (IBAction)saveAndCloseWindow:(id)sender
{

	// Commit all pending edits
	if([commandBundleArrayController commitEditing]) {

		// Make the bundleNames unique since they represent folder names
		NSMutableDictionary *allNames = [NSMutableDictionary dictionary];
		NSInteger idx = 0;
		for(id item in commandBundleArray) {
			if([allNames objectForKey:[item objectForKey:@"bundleName"]]) {
				NSString *newName = [NSString stringWithFormat:@"%@_%ld", [item objectForKey:@"bundleName"], (NSUInteger)(random() % 35000)];
				[[commandBundleArray objectAtIndex:idx] setObject:newName forKey:@"bundleName"];
			} else {
				[allNames setObject:@"" forKey:[item objectForKey:@"bundleName"]];
			}
			idx++;
		}

		BOOL closeMe = YES;
		for(id item in commandBundleArray) {
			if(![self saveBundle:item atPath:nil]) {
				closeMe = NO;
				NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while saving “%@”.", @"error while saving “%@”"), [item objectForKey:@"bundleName"]]
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
		if(![bundle objectForKey:@"bundleName"] || ![[bundle objectForKey:@"bundleName"] length]) {
			return NO;
		}
		aPath = [NSString stringWithFormat:@"%@/%@.%@", bundlePath, [bundle objectForKey:@"bundleName"], SPUserBundleFileExtension];
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

	// Build scope key
	NSMutableString *scopes = [NSMutableString string];
	if([bundle objectForKey:SPBundleScopeQueryEditor] && [[bundle objectForKey:SPBundleScopeQueryEditor] intValue]) {
		if([scopes length]) [scopes appendString:@" "];
		[scopes appendString:SPBundleScopeQueryEditor];
	}
	if([bundle objectForKey:SPBundleScopeInputField] && [[bundle objectForKey:SPBundleScopeInputField] intValue]) {
		if([scopes length]) [scopes appendString:@" "];
		[scopes appendString:SPBundleScopeInputField];
	}
	if([bundle objectForKey:SPBundleScopeDataTable] && [[bundle objectForKey:SPBundleScopeDataTable] intValue]) {
		if([scopes length]) [scopes appendString:@" "];
		[scopes appendString:SPBundleScopeDataTable];
	}
	if(![scopes length]) {
		// For safety reasons
		[scopes setString:[NSString stringWithFormat:@"%@ %@ %@", SPBundleScopeQueryEditor, SPBundleScopeInputField, SPBundleScopeDataTable]];
		[saveDict setObject:SPBundleInputSourceNone forKey:SPBundleFileInputSourceKey];
		[saveDict setObject:SPBundleOutputActionNone forKey:SPBundleFileOutputActionKey];
	}
	[saveDict setObject:scopes forKey:SPBundleFileScopeKey];

	// Remove unnecessary keys
	[saveDict removeObjectsForKeys:[NSArray arrayWithObjects:
		@"bundleName",
		@"inputMask",
		SPBundleScopeQueryEditor,
		SPBundleScopeInputField,
		SPBundleScopeDataTable,
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
			NSIndexSet *indexes = [commandsTableView selectedRowIndexes];

			// get last index
			NSUInteger currentIndex = [indexes lastIndex];

			while (currentIndex != NSNotFound) {

				// Move already installed Bundles to Trash
				NSString *bundleName = [[commandBundleArray objectAtIndex:currentIndex] objectForKey:@"bundleName"];
				NSString *thePath = [NSString stringWithFormat:@"%@/%@.%@", bundlePath, bundleName, SPUserBundleFileExtension];
				if([[NSFileManager defaultManager] fileExistsAtPath:thePath isDirectory:nil]) {
					NSError *error = nil;
					NSString *trashDir = [NSHomeDirectory() stringByAppendingPathComponent:@".Trash"];

					// Use a AppleScript script since NSWorkspace performFileOperation or NSFileManager moveItemAtPath 
					// have problems probably due access rights.
					NSString *moveToTrahCommand = [NSString stringWithFormat:@"osascript -e 'tell application \"Finder\" to move (POSIX file \"%@\") to the trash'", thePath];
					[moveToTrahCommand runBashCommandWithEnvironment:nil atCurrentDirectoryPath:nil error:&error];
					if(error != nil) {
						NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Error while moving “%@” to Trash.", @"error while moving “%@” to trash"), thePath]
														 defaultButton:NSLocalizedString(@"OK", @"OK button") 
													   alternateButton:nil 
														  otherButton:nil 
											informativeTextWithFormat:[error localizedDescription]];
					
						[alert setAlertStyle:NSCriticalAlertStyle];
						[alert runModal];
						break;
					}
				}
				[commandBundleArray removeObjectAtIndex:currentIndex];
				// get next index (beginning from the end)
				currentIndex = [indexes indexLessThanIndex:currentIndex];
			}

			[commandBundleArrayController rearrangeObjects];
			[commandsTableView reloadData];

			// Set focus to table view to avoid an unstable state
			[[self window] makeFirstResponder:commandsTableView];

			[removeButton setEnabled:([commandsTableView numberOfSelectedRows] > 0)];
		}
	} else if([contextInfo isEqualToString:@"saveBundle"]) {
		if (returnCode == NSOKButton) {

			id aBundle = [commandBundleArray objectAtIndex:[commandsTableView selectedRow]];

			NSString *bundleFileName = [aBundle objectForKey:@"bundleName"];
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
		[commandsTableView abortEditing];
		isTableCellEditing = NO;
		[[self window] makeFirstResponder:commandsTableView];
		return NO;
	}
	return YES;

}

- (void)windowWillClose:(NSNotification *)notification
{
	// Release commandBundleArray if window will close to save memory
	if(commandBundleArray) [commandBundleArray release], commandBundleArray = nil;

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

	if([commandsTableView selectedRow] < 0 || [commandsTableView selectedRow] > [commandBundleArray count]) return;

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
	[[commandBundleArray objectAtIndex:[commandsTableView selectedRow]] setObject:keyEq forKey:SPBundleFileKeyEquivalentKey];

}

#pragma mark -
#pragma mark TableView data source and delegate

/**
 * Returns the number of query commandBundleArray.
 */
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [commandBundleArray count];
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if(oldBundleName) [oldBundleName release], oldBundleName = nil;
	oldBundleName = [[[commandBundleArray objectAtIndex:rowIndex] objectForKey:@"bundleName"] retain];
	isTableCellEditing = YES;
	return YES;
}

/**
 * Returns the value for the requested table column and row index.
 */
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{

	if([[aTableColumn identifier] isEqualToString:@"name"]) {
		if(![[commandBundleArray objectAtIndex:rowIndex] objectForKey:@"name"]) return @"...";
		return [[commandBundleArray objectAtIndex:rowIndex] objectForKey:@"bundleName"];
	}
	return @"";
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	if([aNotification object] != commandsTableView) return;

	[self _updateInputPopupButton];
}

/*
 * Save spBundle name if inline edited (suppress empty names) and check for renaming and / in the name
 */
- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{

	if([aNotification object] != commandsTableView) return;

	NSString *newBundleName = [[[aNotification userInfo] objectForKey:@"NSFieldEditor"] string];

	NSInteger selectedTableRow = [commandsTableView selectedRow];

	BOOL isValid = YES;

	if(newBundleName && [newBundleName length] && ![newBundleName rangeOfString:@"/"].length) {

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
		if(!oldBundleName) oldBundleName = @"New Name";
		[[commandBundleArray objectAtIndex:selectedTableRow] setObject:oldBundleName forKey:@"bundleName"];
	}

	[commandsTableView reloadData];

	isTableCellEditing = NO;

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
		) 
	{
		// Allow to record short-cuts used by the Bundle Editor
		if([[NSApp mainWindow] firstResponder] == keyEquivalentField) return NO;
		return ([commandsTableView numberOfSelectedRows] == 1);
	}
	else if ( (action == @selector(removeCommandBundle:)) )
	{
		// Allow to record short-cuts used by the Bundle Editor
		if([[NSApp mainWindow] firstResponder] == keyEquivalentField) return NO;
		return ([commandsTableView numberOfSelectedRows] > 0);
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

	if([commandsTableView numberOfSelectedRows] != 1 || [rows count] != 1) return NO;

	// Remove old temporary drag file if any
	if(draggedFilePath) {
		[[NSFileManager defaultManager] removeItemAtPath:draggedFilePath error:nil];
		[draggedFilePath release];
		draggedFilePath = nil;
	}

	NSImage *dragImage;
	NSPoint dragPosition;

	NSDictionary *bundleDict = [commandBundleArray objectAtIndex:[rows firstIndex]];
	NSString *bundleFileName = [bundleDict objectForKey:@"bundleName"];
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

/**
 * Traps any editing in editTextView to allow undo grouping only if the text buffer was really changed.
 * Inform the run loop delayed for larger undo groups.
 */
- (void)textDidChange:(NSNotification *)aNotification
{

	if([aNotification object] != commandTextView) return;

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

	if([commandsTableView selectedRow] < 0 || [commandsTableView selectedRow] > [commandBundleArray count]) return;

	NSDictionary *currentDict = [commandBundleArray objectAtIndex:[commandsTableView selectedRow]];

	NSString *input = [currentDict objectForKey:SPBundleFileInputSourceKey];
	if(!input || ![input length]) input = SPBundleInputSourceNone;

	NSString *inputfallback = [currentDict objectForKey:SPBundleFileInputSourceFallBackKey];
	if(!inputfallback || ![inputfallback length]) inputfallback = SPBundleInputSourceNone;

	NSString *output = [currentDict objectForKey:SPBundleFileOutputActionKey];
	if(!output || ![output length]) output = SPBundleOutputActionNone;

	NSInteger inputMask = [[currentDict objectForKey:@"inputMask"] intValue];
	switch(inputMask) {
		case 1:
		[inputPopupButton setMenu:inputEditorScopePopUpMenu];
		anIndex = [inputEditorScopeArray indexOfObject:input];
		if(anIndex == NSNotFound) anIndex = 0;
		[inputPopupButton selectItemAtIndex:anIndex];
		[inputFallbackPopupButton setMenu:inputFallbackEditorScopePopUpMenu];
		anIndex = [inputFallbackEditorScopeArray indexOfObject:inputfallback];
		if(anIndex == NSNotFound) anIndex = 0;
		[inputFallbackPopupButton selectItemAtIndex:anIndex];
		[outputPopupButton setMenu:outputEditorScopePopUpMenu];
		anIndex = [outputEditorScopeArray indexOfObject:output];
		if(anIndex == NSNotFound) anIndex = 0;
		[outputPopupButton selectItemAtIndex:anIndex];
		break;
		case 2:
		case 3:
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
		case 4:
		[inputPopupButton setMenu:inputDataTableScopePopUpMenu];
		anIndex = [inputDataTableScopeArray indexOfObject:input];
		if(anIndex == NSNotFound) anIndex = 0;
		[inputPopupButton selectItemAtIndex:anIndex];
		[outputPopupButton setMenu:outputDataTableScopePopUpMenu];
		anIndex = [outputDataTableScopeArray indexOfObject:output];
		if(anIndex == NSNotFound) anIndex = 0;
		[outputPopupButton selectItemAtIndex:anIndex];
		break;
		case 5:
		case 6:
		case 7:
		[inputPopupButton setMenu:inputNonePopUpMenu];
		[inputPopupButton selectItemAtIndex:0];
		[outputPopupButton setMenu:outputDataTableScopePopUpMenu];
		anIndex = [outputDataTableScopeArray indexOfObject:output];
		if(anIndex == NSNotFound) anIndex = 0;
		[outputPopupButton selectItemAtIndex:anIndex];
		break;
		default:
		[inputPopupButton setMenu:inputNonePopUpMenu];
		[inputPopupButton selectItemAtIndex:0];
		[outputPopupButton setMenu:outputDataTableScopePopUpMenu];
		anIndex = [outputDataTableScopeArray indexOfObject:output];
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

}


@end

