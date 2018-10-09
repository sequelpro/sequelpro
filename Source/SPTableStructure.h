//
//  SPTableStructure.h
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

@class SPDatabaseDocument;
@class SPTableFieldValidation;
@class SPTableData;
@class SPDatabaseData;
@class SPTablesList;
@class SPIndexesController;
@class SPTableView;
@class SPMySQLConnection;
@class SPMySQLResult;
@class SPExtendedTableInfo;
@class SPTableInfo;

@interface SPFieldTypeHelp : NSObject
{
	NSString *typeName;
	NSString *typeDefinition;
	NSString *typeRange;
	NSString *typeDescription;
}

@property(readonly) NSString *typeName;
@property(readonly) NSString *typeDefinition;
@property(readonly) NSString *typeRange;
@property(readonly) NSString *typeDescription;

@end

@interface SPTableStructure : NSObject <NSTableViewDelegate, NSTableViewDataSource, NSComboBoxCellDataSource>
{
	IBOutlet SPTablesList *tablesListInstance;
	IBOutlet SPTableData *tableDataInstance;
	IBOutlet SPDatabaseDocument *tableDocumentInstance;
	IBOutlet SPTableInfo *tableInfoInstance;
	IBOutlet SPExtendedTableInfo *extendedTableInfoInstance;
	IBOutlet SPIndexesController *indexesController;
	IBOutlet SPDatabaseData *databaseDataInstance;
	
	IBOutlet NSPanel *structureHelpPanel;
	IBOutlet NSTextView *structureHelpText;

	IBOutlet id keySheet;
	IBOutlet id resetAutoIncrementSheet;
	IBOutlet id resetAutoIncrementValue;
	IBOutlet id resetAutoIncrementLine;
	IBOutlet SPTableView* tableSourceView;
	IBOutlet id addFieldButton;
	IBOutlet id duplicateFieldButton;
	IBOutlet id removeFieldButton;
	IBOutlet id reloadFieldsButton;
	IBOutlet id chooseKeyButton;
	IBOutlet id structureGrabber;
	IBOutlet id editTableButton;
	IBOutlet id addIndexButton;
	IBOutlet id removeIndexButton;
	IBOutlet id refreshIndexesButton;
	IBOutlet SPTableView* indexesTableView;
	IBOutlet NSSplitView *tablesIndexesSplitView;
	IBOutlet NSButton *indexesShowButton;

	IBOutlet id viewColumnsMenu;
	IBOutlet NSPopUpButtonCell *encodingPopupCell;

	SPMySQLConnection *mySQLConnection;
	
	SPTableFieldValidation *fieldValidation;

	NSString *selectedTable;
	NSMutableArray *tableFields;
	NSMutableDictionary *oldRow, *enumFields;
	NSDictionary *defaultValues;
	NSInteger currentlyEditingRow;
	NSUserDefaults *prefs;
	NSArray *collations;
	NSArray *typeSuggestions;
	NSArray *extraFieldSuggestions;
	BOOL isCurrentExtraAutoIncrement;
	NSString *autoIncrementIndex;
	
	BOOL isEditingRow, isEditingNewRow, isSavingRow, alertSheetOpened;
}

- (void)showErrorSheetWith:(NSDictionary *)errorDictionary;

// Edit methods
- (IBAction)addField:(id)sender;
- (IBAction)duplicateField:(id)sender;
- (IBAction)removeField:(id)sender;
- (void)removeFieldSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (IBAction)resetAutoIncrement:(id)sender;
- (void)resetAutoincrementSheetDidEnd:(NSWindow *)theSheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)takeAutoIncrementFrom:(NSTextField *)field;
- (IBAction)showOptimizedFieldType:(id)sender;
- (IBAction)toggleColumnView:(NSMenuItem *)sender;
- (BOOL)cancelRowEditing;

// Index sheet methods
- (IBAction)closeSheet:(id)sender;

// Additional methods
- (void)setConnection:(SPMySQLConnection *)theConnection;
- (NSArray *)convertIndexResultToArray:(SPMySQLResult *)theResult;
- (BOOL)saveRowOnDeselect;
- (BOOL)addRowToDB;
- (void)addRowErrorSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)setAutoIncrementTo:(NSNumber *)value;

// Accessors
- (NSString *)defaultValueForField:(NSString *)field;
- (NSArray *)fieldNames;
- (NSDictionary *)enumFields;
- (NSDictionary *)tableSourceForPrinting;

// Task interaction
- (void)startDocumentTaskForTab:(NSNotification *)aNotification;
- (void)endDocumentTaskForTab:(NSNotification *)aNotification;

// Split view interaction
- (IBAction)unhideIndexesView:(id)sender;

+ (SPFieldTypeHelp *)helpForFieldType:(NSString *)typeName;

#pragma mark - SPTableStructureLoading

- (void)loadTable:(NSString *)aTable;
- (IBAction)reloadTable:(id)sender;
- (void)setTableDetails:(NSDictionary *)tableDetails;

@end
