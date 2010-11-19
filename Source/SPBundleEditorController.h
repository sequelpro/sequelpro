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
#import "SPEditSheetTextView.h"

@class SRRecorderControl;

@interface SPBundleEditorController : NSWindowController {

	IBOutlet id commandTextView;
	IBOutlet NSTableView* commandsTableView;
	IBOutlet NSTextField* nameTextField;
	IBOutlet NSTextField* tootlipTextField;
	IBOutlet NSTextField* categoryTextField;
	IBOutlet NSTextField* fallbackLabelField;
	IBOutlet NSPopUpButton* inputPopupButton;
	IBOutlet NSPopUpButton* inputFallbackPopupButton;
	IBOutlet NSPopUpButton* outputPopupButton;
	IBOutlet NSButton *editorScopeButton;
	IBOutlet NSButton *inputFieldScopeButton;
	IBOutlet NSButton *dataTableScopeButton;
	IBOutlet NSButton *disableCheckBox;
	IBOutlet NSButton *removeButton;
	IBOutlet NSMenuItem *duplicateMenuItem;
	IBOutlet NSMenuItem *revealInFinderMenuItem;
	IBOutlet SRRecorderControl *keyEquivalentField;

	IBOutlet NSArrayController *commandBundleArrayController;
	NSMutableArray *commandBundleArray;
	
	NSString *bundlePath;
	NSString *draggedFilePath;
	NSString *oldBundleName;
	BOOL isTableCellEditing;

	NSMenu *inputEditorScopePopUpMenu;
	NSMenu *inputInputFieldScopePopUpMenu;
	NSMenu *inputDataTableScopePopUpMenu;
	NSMenu *inputNonePopUpMenu;
	NSMenu *outputEditorScopePopUpMenu;
	NSMenu *outputInputFieldScopePopUpMenu;
	NSMenu *outputDataTableScopePopUpMenu;
	NSMenu *inputFallbackEditorScopePopUpMenu;
	NSMenu *inputFallbackInputFieldScopePopUpMenu;

	NSArray *inputEditorScopeArray;
	NSArray *inputInputFieldScopeArray;
	NSArray *inputDataTableScopeArray;
	NSArray *outputEditorScopeArray;
	NSArray *outputInputFieldScopeArray;
	NSArray *outputDataTableScopeArray;
	NSArray *inputFallbackEditorScopeArray;
	NSArray *inputFallbackInputFieldScopeArray;

	BOOL doGroupDueToChars;
	BOOL allowUndo;
	BOOL wasCutPaste;
	BOOL selectionChanged;
	NSUndoManager *esUndoManager;

}

- (IBAction)inputPopupButtonChanged:(id)sender;
- (IBAction)inputFallbackPopupButtonChanged:(id)sender;
- (IBAction)outputPopupButtonChanged:(id)sender;
- (IBAction)scopeButtonChanged:(id)sender;
- (IBAction)duplicateCommandBundle:(id)sender;
- (IBAction)addCommandBundle:(id)sender;
- (IBAction)removeCommandBundle:(id)sender;
- (IBAction)revealCommandBundleInFinder:(id)sender;
- (IBAction)saveBundle:(id)sender;
- (IBAction)showHelp:(id)sender;
- (IBAction)saveAndCloseWindow:(id)sender;

- (BOOL)saveBundle:(NSDictionary*)bundle atPath:(NSString*)aPath;

- (void)setWasCutPaste;
- (void)setDoGroupDueToChars;

@end
