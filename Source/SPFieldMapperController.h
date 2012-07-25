//
//  $Id$
//
//  SPFieldMapperController.h
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on February 1, 2010.
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
//  More info at <http://code.google.com/p/sequel-pro/>

@class SPTextView;
@class SPTableView;
@class SPTablesList;
@class SPMySQLConnection;

@interface SPFieldMapperController : NSWindowController
#ifdef SP_REFACTOR
<NSTokenFieldCellDelegate>
#endif
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
	IBOutlet NSButton *importFieldNamesHeaderSwitch;
	IBOutlet NSButton *addRemainingDataSwitch;
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
	IBOutlet NSButton *newTableButton;
	IBOutlet id newTableInfoWindow;
	IBOutlet id newTableInfoEncodingPopup;
	IBOutlet id newTableInfoEnginePopup;

	IBOutlet id globalValuesSheet;
	IBOutlet NSButton *addGlobalValueButton;
	IBOutlet NSButton *removeGlobalValueButton;
	IBOutlet NSButton *insertNULLValueButton;
	IBOutlet NSButton *replaceAfterSavingCheckBox;
	IBOutlet NSPopUpButton *insertPullDownButton;
	IBOutlet NSMenu *recentGlobalValueMenu;

	IBOutlet NSButton *ignoreCheckBox;
	IBOutlet NSButton *ignoreUpdateCheckBox;
	IBOutlet NSButton *delayedCheckBox;
	IBOutlet NSButton *delayedReplaceCheckBox;
	IBOutlet NSButton *onupdateCheckBox;
	IBOutlet NSButton *lowPriorityCheckBox;
	IBOutlet NSButton *lowPriorityReplaceCheckBox;
	IBOutlet NSButton *lowPriorityUpdateCheckBox;
	IBOutlet NSButton *highPriorityCheckBox;
	IBOutlet NSButton *skipexistingRowsCheckBox;
	IBOutlet SPTextView *onupdateTextView;
	IBOutlet id gobackButton;

	IBOutlet id advancedButton;

	IBOutlet id advancedInsertView;
	IBOutlet id advancedReplaceView;
	IBOutlet id advancedUpdateView;

	IBOutlet NSComboBoxCell *typeComboxBox;

	id theDelegate;
	id customQueryInstance;
	id fieldMappingImportArray;
	SPTablesList *tablesListInstance;
	id databaseDataInstance;

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

	NSString *newTableEncoding;
	NSString *newTableEngine;

	NSNumber *doImport;
	NSNumber *doNotImport;
	NSNumber *isEqual;
	NSString *doImportString;
	NSString *doNotImportString;
	NSString *isEqualString;

	NSInteger numberOfImportColumns;
	NSMutableIndexSet *toBeEditedRowIndexes;

	BOOL fieldMappingImportArrayIsPreview;
	BOOL importFieldNamesHeader;
	BOOL showAdvancedView;
	BOOL targetTableHasPrimaryKey;
	BOOL newTableMode;
	BOOL addGlobalSheetIsOpen;

	NSArray *primaryKeyFields;
	NSNumber *lastDisabledCSVFieldcolumn;

	SPMySQLConnection *mySQLConnection;

	NSString *sourcePath;

	NSUserDefaults *prefs;
	
	NSInteger heightOffset;
	NSUInteger windowMinWidth;
	NSUInteger windowMinHeigth;
}

@property(retain) NSString* sourcePath;

- (id)initWithDelegate:(id)managerDelegate;

- (void)setConnection:(SPMySQLConnection *)theConnection;
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
- (IBAction)goBackToFileChooserFromPathControl:(id)sender;

- (IBAction)addGlobalValue:(id)sender;
- (IBAction)removeGlobalValue:(id)sender;
- (IBAction)insertNULLValue:(id)sender;
- (IBAction)closeGlobalValuesSheet:(id)sender;
- (IBAction)advancedCheckboxValidation:(id)sender;
- (IBAction)insertPulldownValue:(id)sender;
- (IBAction)insertRecentGlobalValue:(id)sender;

- (IBAction)newTable:(id)sender;
- (IBAction)newTableInfo:(id)sender;
- (IBAction)closeInfoSheet:(id)sender;
- (IBAction)addNewColumn:(id)sender;
- (IBAction)removeNewColumn:(id)sender;
// - (IBAction)editColumn:(id)sender;
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
