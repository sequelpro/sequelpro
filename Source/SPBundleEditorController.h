//
//  $Id$
//
//  SPBundleEditorController.h
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

#import <Cocoa/Cocoa.h>
#import <ShortcutRecorder/ShortcutRecorder.h>
#import "SPBundleCommandTextView.h"
#import "SPOutlineView.h"

@class SRRecorderControl, BWSplitView;

@interface SPBundleEditorController : NSWindowController {

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
	IBOutlet NSTextField *authorLabelField;
	IBOutlet NSTextField *contactLabelField;
	IBOutlet NSTextField *descriptionLabelField;
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
	IBOutlet NSButton *showHideMetaButton;
	IBOutlet NSMenuItem *duplicateMenuItem;
	IBOutlet NSMenuItem *revealInFinderMenuItem;
	IBOutlet SRRecorderControl *keyEquivalentField;
	IBOutlet NSButton *disabledCheckbox;
	IBOutlet NSScrollView *commandScrollView;
	IBOutlet NSScrollView *descriptionScrollView;
	IBOutlet BWSplitView *splitView;

	IBOutlet id undeleteSheet;
	IBOutlet NSTableView *undeleteTableView;

	IBOutlet NSTreeController *commandBundleTreeController;
	NSMutableArray *touchedBundleArray;
	NSMutableDictionary *commandBundleTree;
	NSSortDescriptor *sortDescriptor;

	NSString *bundlePath;
	NSString *draggedFilePath;
	NSString *oldBundleName;
	BOOL isTableCellEditing;

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

	BOOL doGroupDueToChars;
	BOOL allowUndo;
	BOOL wasCutPaste;
	BOOL selectionChanged;
	NSUndoManager *esUndoManager;

	NSArray *shellVariableSuggestions;

	NSMutableArray *deletedDefaultBundles;

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
- (IBAction)metaButtonChanged:(id)sender;
- (IBAction)performClose:(id)sender;
- (IBAction)undeleteDefaultBundles:(id)sender;
- (IBAction)closeUndeleteDefaultBundlesSheet:(id)sender;

- (BOOL)saveBundle:(NSDictionary*)bundle atPath:(NSString*)aPath;
- (BOOL)cancelRowEditing;

- (void)setWasCutPaste;
- (void)setDoGroupDueToChars;

@end
