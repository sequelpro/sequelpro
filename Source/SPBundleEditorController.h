//
//  SPBundleEditorController.h
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

#import <ShortcutRecorder/ShortcutRecorder.h>

@class SRRecorderControl;
@class SPSplitView;
@class SPOutlineView;
@class SPBundleCommandTextView;

@interface SPBundleEditorController : NSWindowController 
{
	IBOutlet SPBundleCommandTextView *commandTextView;
	IBOutlet SPOutlineView *commandsOutlineView;
	IBOutlet NSTextField *authorTextField;
	IBOutlet NSTextField *contactTextField;
	IBOutlet NSTextView *descriptionTextView;
	IBOutlet NSTextField *nameTextField;
	IBOutlet NSTextField *tooltipTextField;
	IBOutlet NSTextField *categoryTextField;
	IBOutlet NSTextField *fallbackLabelField;
	IBOutlet NSTextField *withBlobLabelField;
	IBOutlet NSTextField *commandLabelField;
	IBOutlet NSPopUpButton *inputPopupButton;
	IBOutlet NSPopUpButton *inputFallbackPopupButton;
	IBOutlet NSPopUpButton *outputPopupButton;
	IBOutlet NSPopUpButton *scopePopupButton;
	IBOutlet NSPopUpButton *triggerPopupButton;
	IBOutlet NSPopUpButton *withBlobPopupButton;
	IBOutlet NSButton *removeButton;
	IBOutlet NSButton *addButton;
	IBOutlet NSButton *saveButton;
	IBOutlet NSButton *cancelButton;
	IBOutlet NSButton *helpButton;
	IBOutlet NSTextField *metaInfoSummary;
	IBOutlet NSButton *displayMetaInfoButton;
	IBOutlet NSMenuItem *duplicateMenuItem;
	IBOutlet NSMenuItem *revealInFinderMenuItem;
	IBOutlet SRRecorderControl *keyEquivalentField;
	IBOutlet NSButton *disabledCheckbox;
	IBOutlet NSScrollView *commandScrollView;
	IBOutlet SPSplitView *splitView;

	IBOutlet NSWindow *undeleteSheet;
	IBOutlet NSWindow *metaInfoSheet;
	IBOutlet NSTableView *undeleteTableView;

	IBOutlet NSTreeController *commandBundleTreeController;
	
	NSMutableArray *touchedBundleArray;
	NSMutableArray *deletedDefaultBundles;
	NSMutableDictionary *commandBundleTree;
	NSSortDescriptor *sortDescriptor;
	NSUndoManager *esUndoManager;

	NSString *bundlePath;
	NSString *draggedFilePath;
	NSString *oldBundleName;

	NSMenu *inputGeneralScopePopUpMenu;
	NSMenu *inputInputFieldScopePopUpMenu;
	NSMenu *inputDataTableScopePopUpMenu;
	NSMenu *inputNonePopUpMenu;
	NSMenu *outputGeneralScopePopUpMenu;
	NSMenu *outputInputFieldScopePopUpMenu;
	NSMenu *outputDataTableScopePopUpMenu;
	NSMenu *inputFallbackInputFieldScopePopUpMenu;
	NSMenu *triggerInputFieldPopUpMenu;
	NSMenu *triggerDataTablePopUpMenu;
	NSMenu *triggerGeneralPopUpMenu;
	NSMenu *withBlobDataTablePopUpMenu;

	NSArray *inputGeneralScopeArray;
	NSArray *inputInputFieldScopeArray;
	NSArray *inputDataTableScopeArray;
	NSArray *outputGeneralScopeArray;
	NSArray *outputInputFieldScopeArray;
	NSArray *outputDataTableScopeArray;
	NSArray *inputFallbackInputFieldScopeArray;
	NSArray *triggerInputFieldArray;
	NSArray *triggerDataTableArray;
	NSArray *triggerGeneralArray;
	NSArray *withBlobDataTableArray;
	NSArray *shellVariableSuggestions;
	
	BOOL doGroupDueToChars;
	BOOL allowUndo;
	BOOL wasCutPaste;
	BOOL selectionChanged;
	BOOL isTableCellEditing;
}

- (IBAction)inputPopupButtonChanged:(id)sender;
- (IBAction)inputFallbackPopupButtonChanged:(id)sender;
- (IBAction)outputPopupButtonChanged:(id)sender;
- (IBAction)scopeButtonChanged:(id)sender;
- (IBAction)triggerButtonChanged:(id)sender;
- (IBAction)withBlobButtonChanged:(id)sender;
- (IBAction)duplicateCommandBundle:(id)sender;
- (IBAction)addCommandBundle:(id)sender;
- (IBAction)removeCommandBundle:(id)sender;
- (IBAction)revealCommandBundleInFinder:(id)sender;
- (IBAction)saveBundle:(id)sender;
- (IBAction)showHelp:(id)sender;
- (IBAction)saveAndCloseWindow:(id)sender;
- (IBAction)reloadBundles:(id)sender;
- (IBAction)performClose:(id)sender;
- (IBAction)undeleteDefaultBundles:(id)sender;
- (IBAction)closeUndeleteDefaultBundlesSheet:(id)sender;
- (IBAction)displayBundleMetaInfo:(id)sender;
- (IBAction)closeSheet:(id)sender;

- (BOOL)saveBundle:(NSDictionary*)bundle atPath:(NSString*)aPath;
- (BOOL)cancelRowEditing;

- (void)setWasCutPaste;
- (void)setDoGroupDueToChars;

@end
