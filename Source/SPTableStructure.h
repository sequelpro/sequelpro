//
//  $Id$
//
//  SPTableStructure.h
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed May 01 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
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

#import <MCPKit/MCPKit.h>

@class SPDatabaseDocument, SPTableFieldValidation, SPTableData, SPDatabaseData, SPTablesList, SPIndexesController, SPTableView;

@interface SPTableStructure : NSObject 
#ifdef SP_REFACTOR
<NSTableViewDelegate, NSTableViewDataSource, NSComboBoxCellDataSource>
#endif
{
	IBOutlet SPTablesList* tablesListInstance;
	IBOutlet SPTableData* tableDataInstance;
	IBOutlet SPDatabaseDocument* tableDocumentInstance;
#ifndef SP_REFACTOR /* ivars */
	IBOutlet id tableInfoInstance;
	IBOutlet id extendedTableInfoInstance;
#endif
	IBOutlet SPIndexesController* indexesController;
	IBOutlet SPDatabaseData* databaseDataInstance;

#ifndef SP_REFACTOR /* ivars */
	IBOutlet id keySheet;
	IBOutlet id resetAutoIncrementSheet;
	IBOutlet id resetAutoIncrementValue;
	IBOutlet id resetAutoIncrementLine;
#endif
	IBOutlet SPTableView* tableSourceView;
	IBOutlet id addFieldButton;
	IBOutlet id duplicateFieldButton;
	IBOutlet id removeFieldButton;
	IBOutlet id reloadFieldsButton;
#ifndef SP_REFACTOR /* ivars */
	IBOutlet id chooseKeyButton;
	IBOutlet id structureGrabber;
	IBOutlet id editTableButton;
	IBOutlet id addIndexButton;
	IBOutlet id removeIndexButton;
	IBOutlet id refreshIndexesButton;
#endif
	IBOutlet SPTableView* indexesTableView;
#ifndef SP_REFACTOR /* ivars */
	IBOutlet NSSplitView *tablesIndexesSplitView;
	IBOutlet NSButton *indexesShowButton;

	IBOutlet id viewColumnsMenu;
#endif
	IBOutlet NSPopUpButtonCell *encodingPopupCell;

	MCPConnection *mySQLConnection;
	MCPResult *tableSourceResult;
	MCPResult *indexResult;
	
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

#ifdef SP_REFACTOR
@property (assign) SPIndexesController* indexesController;
@property (assign) id indexesTableView;
@property (assign) id addFieldButton;
@property (assign) id duplicateFieldButton;
@property (assign) id removeFieldButton;
@property (assign) id reloadFieldsButton;
#endif

// Table loading
- (void)loadTable:(NSString *)aTable;
- (IBAction)reloadTable:(id)sender;
- (void)setTableDetails:(NSDictionary *)tableDetails;

#ifdef SP_REFACTOR /* method decls */
- (void)setDatabaseDocument:(SPDatabaseDocument*)doc;
- (void)setTableListInstance:(SPTablesList*)list;
- (void)setTableDataInstance:(SPTableData*)data;
- (void)setDatabaseDataInstance:(SPDatabaseData*)data;
- (void)setTableSourceView:(SPTableView*)tv;
- (void)setEncodingPopupCell:(NSPopUpButtonCell*)cell;
#endif
- (void)showErrorSheetWith:(NSDictionary *)errorDictionary;

// Edit methods
- (IBAction)addField:(id)sender;
- (IBAction)duplicateField:(id)sender;
- (IBAction)removeField:(id)sender;
- (void)removeFieldSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (IBAction)resetAutoIncrement:(id)sender;
- (void)resetAutoincrementSheetDidEnd:(NSWindow *)theSheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (IBAction)showOptimizedFieldType:(id)sender;
- (IBAction)toggleColumnView:(id)sender;
- (BOOL)cancelRowEditing;

// Index sheet methods
- (IBAction)closeSheet:(id)sender;

// Additional methods
- (void)setConnection:(MCPConnection *)theConnection;
- (NSArray *)fetchResultAsArray:(MCPResult *)theResult;
- (BOOL)saveRowOnDeselect;
- (BOOL)addRowToDB;
- (void)addRowErrorSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)setAutoIncrementTo:(NSString*)valueAsString;

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

@end
