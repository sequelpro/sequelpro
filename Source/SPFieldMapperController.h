//
//  $Id$
//
//  SPFieldMapperController.h
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

#import <Cocoa/Cocoa.h>
#import <MCPKit/MCPKit.h>
#import "SPTableView.h"

@class SPTextView;

@interface SPFieldMapperController : NSWindowController 
{
	IBOutlet SPTableView *fieldMapperTableView;
	IBOutlet id fieldMapperTableScrollView;
	IBOutlet NSTableView *globalValuesTableView;
	IBOutlet NSPopUpButton *tableTargetPopup;
	IBOutlet NSPathControl *fileSourcePath;
	IBOutlet NSPopUpButton *importMethodPopup;
	IBOutlet id rowUpButton;
	IBOutlet id rowDownButton;
	IBOutlet id recordCountLabel;
	IBOutlet id importFieldNamesHeaderSwitch;
	IBOutlet id addRemainingDataSwitch;
	IBOutlet id importButton;
	IBOutlet id advancedBox;
	IBOutlet NSPopUpButton *alignByPopup;
	IBOutlet id alignByPopupLabel;
	IBOutlet id importMethodLabel;
	IBOutlet id advancedLabel;
	IBOutlet NSMenuItem *matchingNameMenuItem;
	IBOutlet NSMenuItem *addNewColumnMenuItem;
	IBOutlet NSMenuItem *setAllTypesToMenuItem;

	IBOutlet NSTextField *newTableNameTextField;
	IBOutlet NSTextField *newTableNameLabel;
	IBOutlet NSButton *newTableNameInfoButton;

	IBOutlet id globalValuesSheet;
	IBOutlet NSButton *addGlobalValueButton;
	IBOutlet NSButton *removeGlobalValueButton;
	IBOutlet NSButton *insertNULLValueButton;
	IBOutlet id replaceAfterSavingCheckBox;

	IBOutlet id ignoreCheckBox;
	IBOutlet id ignoreUpdateCheckBox;
	IBOutlet id delayedCheckBox;
	IBOutlet id delayedReplaceCheckBox;
	IBOutlet id onupdateCheckBox;
	IBOutlet id lowPriorityCheckBox;
	IBOutlet id lowPriorityReplaceCheckBox;
	IBOutlet id lowPriorityUpdateCheckBox;
	IBOutlet id highPriorityCheckBox;
	IBOutlet id skipexistingRowsCheckBox;
	IBOutlet SPTextView *onupdateTextView;

	IBOutlet id advancedButton;

	IBOutlet id advancedInsertView;
	IBOutlet id advancedReplaceView;
	IBOutlet id advancedUpdateView;

	IBOutlet NSComboBoxCell *typeComboxBox;

	id theDelegate;
	id customQueryInstance;
	id fieldMappingImportArray;
	id tablesListInstance;

	NSInteger fieldMappingCurrentRow;
	NSMutableArray *fieldMappingArray;
	NSMutableArray *fieldMappingTableColumnNames;
	NSMutableArray *fieldMappingTableTypes;
	NSMutableArray *fieldMappingButtonOptions;
	NSMutableArray *fieldMappingOperatorOptions;
	NSMutableArray *fieldMappingOperatorArray;
	NSMutableArray *fieldMappingGlobalValues;
	NSMutableArray *fieldMappingGlobalValuesSQLMarked;
	NSMutableArray *fieldMappingTableDefaultValues;
	NSMutableArray *defaultFieldTypesForComboBox;


	NSNumber *doImport;
	NSNumber *doNotImport;
	NSNumber *isEqual;
	NSString *doImportString;
	NSString *doNotImportString;
	NSString *isEqualString;

	NSInteger numberOfImportColumns;

	BOOL fieldMappingImportArrayIsPreview;
	BOOL importFieldNamesHeader;
	BOOL showAdvancedView;
	BOOL targetTableHasPrimaryKey;
	BOOL newTableMode;
	BOOL addGlobalSheetIsOpen;

	NSString *primaryKeyField;
	NSNumber *lastDisabledCSVFieldcolumn;

	MCPConnection *mySQLConnection;

	NSString *sourcePath;

	NSUserDefaults *prefs;
	
	NSInteger heightOffset;
	NSUInteger windowMinWidth;
	NSUInteger windowMinHeigth;
}

@property(retain) NSString* sourcePath;

- (id)initWithDelegate:(id)managerDelegate;

- (void)setConnection:(MCPConnection *)theConnection;
- (void)setImportDataArray:(id)theFieldMappingImportArray hasHeader:(BOOL)hasHeader isPreview:(BOOL)isPreview;

// Getter methods
- (NSString*)selectedTableTarget;
- (NSArray*)fieldMapperOperator;
- (NSString*)selectedImportMethod;
- (NSArray*)fieldMappingArray;
- (NSArray*)fieldMappingTableColumnNames;
- (NSArray*)fieldMappingGlobalValueArray;
- (NSArray*)fieldMappingTableDefaultValues;
- (BOOL)importFieldNamesHeader;
- (BOOL)insertRemainingRowsAfterUpdate;
- (BOOL)globalValuesInUsage;
- (BOOL)importIntoNewTable;
- (NSString*)onupdateString;
- (NSString*)importHeaderString;
- (BOOL)canBeClosed;
- (BOOL)isGlobalValueSheetOpen;

// IBAction methods
- (IBAction)changeTableTarget:(id)sender;
- (IBAction)changeImportMethod:(id)sender;
- (IBAction)changeFieldAlignment:(id)sender;
- (IBAction)changeHasHeaderCheckbox:(id)sender;
- (IBAction)stepRow:(id)sender;
- (IBAction)addGlobalSourceVariable:(id)sender;
- (IBAction)openAdvancedSheet:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)goBackToFileChooser:(id)sender;

- (IBAction)addGlobalValue:(id)sender;
- (IBAction)removeGlobalValue:(id)sender;
- (IBAction)insertNULLValue:(id)sender;
- (IBAction)closeGlobalValuesSheet:(id)sender;
- (IBAction)advancedCheckboxValidation:(id)sender;

- (IBAction)addNewColumn:(id)sender;
- (IBAction)setAllTypesTo:(id)sender;

// Others
- (void)resizeWindowByHeightDelta:(NSInteger)delta;
- (void)matchHeaderNames;
- (void)setupFieldMappingArray;
- (void)updateFieldMappingButtonCell;
- (void)updateFieldMappingOperatorOptions;
- (void)updateFieldNameAlignment;
- (void)validateImportButton;

@end
