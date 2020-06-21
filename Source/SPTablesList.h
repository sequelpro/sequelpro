//
//  SPTablesList.h
//  sequel-pro
//
//  Created by Lorenz Textor (lorenz@textor.ch) on Wed May 1, 2002.
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

@class SPHistoryController;
@class SPTableView;
@class SPMySQLConnection;
@class SPDatabaseDocument; 
@class SPDatabaseData;
@class SPTableStructure;
@class SPTableContent;
@class SPSplitView;
@class SPCharsetCollationHelper;
@class SPCustomQuery;
@class SPDataImport;
@class SPTableData;
@class SPTableInfo;
@class SPTableTriggers;
@class SPExtendedTableInfo;

@interface SPTablesList : NSObject <NSTextFieldDelegate, NSTableViewDelegate>
{
	IBOutlet SPDatabaseDocument *tableDocumentInstance;
	IBOutlet SPTableStructure *tableSourceInstance;
	IBOutlet SPTableContent *tableContentInstance;
	IBOutlet SPDatabaseData *databaseDataInstance;
	IBOutlet SPHistoryController *spHistoryControllerInstance;
	IBOutlet SPCustomQuery *customQueryInstance;
	IBOutlet SPDataImport *tableDumpInstance;
	IBOutlet SPTableData *tableDataInstance;
	IBOutlet SPExtendedTableInfo *extendedTableInfoInstance;
	IBOutlet SPTableInfo *tableInfoInstance;
	IBOutlet SPTableTriggers *tableTriggersInstance;

	IBOutlet NSWindow *copyTableSheet;
	IBOutlet SPTableView *tablesListView;
	IBOutlet NSButton *copyTableButton;
	IBOutlet NSTextField *copyTableNameField;
	IBOutlet NSTextField *copyTableMessageField;
	IBOutlet NSButton *copyTableContentSwitch;
	IBOutlet NSWindow *tableSheet;
	IBOutlet NSTextField *tableNameField;
	IBOutlet NSPopUpButton *tableEncodingButton;
	IBOutlet NSPopUpButton *tableCollationButton;
	IBOutlet NSPopUpButton *tableTypeButton;
	IBOutlet NSButton *toolbarAddButton;

	IBOutlet NSPopUpButton *toolbarActionsButton;
	IBOutlet NSButton *toolbarReloadButton;
	IBOutlet NSButton *addTableButton;
	IBOutlet NSMenuItem *truncateTableButton;
	IBOutlet SPSplitView *tableListSplitView;
	IBOutlet SPSplitView *tableListFilterSplitView;

	IBOutlet NSSearchField *listFilterField;

	// Table list 'gear' menu items
	IBOutlet NSMenuItem *removeTableMenuItem;
	IBOutlet NSMenuItem *duplicateTableMenuItem;
	IBOutlet NSMenuItem *renameTableMenuItem;
	IBOutlet NSMenuItem *openTableInNewTabMenuItem;
	IBOutlet NSMenuItem *openTableInNewWindowMenuItem;
	IBOutlet NSMenuItem *separatorTableMenuItem;
	IBOutlet NSMenuItem *showCreateSyntaxMenuItem;
	IBOutlet NSMenuItem *copyCreateSyntaxMenuItem;
	IBOutlet NSMenuItem *separatorTableMenuItem2;
	IBOutlet NSMenuItem *separatorTableMenuItem3;
	
	SPMySQLConnection *mySQLConnection;

	// Table list context menu items
	IBOutlet NSMenuItem *removeTableContextMenuItem;
	IBOutlet NSMenuItem *duplicateTableContextMenuItem;
	IBOutlet NSMenuItem *truncateTableContextMenuItem;
	IBOutlet NSMenuItem *renameTableContextMenuItem;
	IBOutlet NSMenuItem *openTableInNewTabContextMenuItem;
	IBOutlet NSMenuItem *openTableInNewWindowContextMenuItem;
	IBOutlet NSMenuItem *separatorTableContextMenuItem;
	IBOutlet NSMenuItem *showCreateSyntaxContextMenuItem;
	IBOutlet NSMenuItem *copyCreateSyntaxContextMenuItem;
	IBOutlet NSMenuItem *separatorTableContextMenuItem2;
	IBOutlet NSMenuItem *separatorTableContextMenuItem3;

	NSMutableArray *tables;
	NSMutableArray *filteredTables;
	NSMutableArray *tableTypes;
	NSMutableDictionary *tableComments;
	NSMutableArray *filteredTableTypes;
	SPTableType selectedTableType;
	NSString *selectedTableName;

	NSUserDefaults *prefs;

	BOOL isTableListFiltered;
	BOOL tableListIsSelectable;
	BOOL tableListContainsViews;
	BOOL alertSheetOpened;

	NSFont *smallSystemFont;
	
	SPCharsetCollationHelper *addTableCharsetHelper;
}

// IBAction methods
- (IBAction)updateTables:(nullable id)sender;
- (IBAction)addTable:(nullable id)sender;
- (IBAction)closeSheet:(nullable id)sender;
- (IBAction)removeTable:(nullable id)sender;
- (IBAction)copyTable:(nullable id)sender;
- (IBAction)renameTable:(nullable id)sender;
- (IBAction)truncateTable:(nullable id)sender;
- (IBAction)openTableInNewTab:(nullable id)sender;
- (IBAction)openTableInNewWindow:(nullable id)sender;
- (IBAction)togglePaneCollapse:(nullable id)sender;
- (IBAction)updateFilter:(nullable id)sender;

// Additional methods
- (void)setConnection:(nonnull SPMySQLConnection *)theConnection;
- (void)setSelectionState:(nullable NSDictionary *)selectionDetails;
- (void)selectTableAtIndex:(nullable NSNumber *)row;
- (void)makeTableListFilterHaveFocus;
- (void)makeTableListHaveFocus;
- (void)deselectAllTables;

// Getters
- (nonnull NSArray *)selectedTableNames;
- (nonnull NSArray *)selectedTableItems;
- (nonnull NSArray *)selectedTableTypes;
- (nullable NSString *)tableName;
- (SPTableType)tableType;
- (nonnull NSArray *)tables;
- (nonnull NSArray *)tableTypes;
- (nonnull NSArray *)allTableAndViewNames;
- (nonnull NSArray *)allTableNames;
- (nonnull NSArray *)allViewNames;
- (nonnull NSArray *)allFunctionNames;
- (nonnull NSArray *)allProcedureNames;
- (nonnull NSArray *)allEventNames;
- (nonnull NSArray *)allDatabaseNames;
- (nonnull NSArray *)allSystemDatabaseNames;
- (nullable NSString *)selectedDatabase;

- (BOOL)hasViews;
- (BOOL)hasFunctions;
- (BOOL)hasProcedures;
- (BOOL)hasEvents;
- (BOOL)hasNonTableObjects;

// Setters
- (BOOL)selectItemWithName:(nullable NSString *)theName;
- (BOOL)selectItemsWithNames:(nonnull NSArray *)theNames;

// Table list filter interaction
- (void)showFilter;
- (void)hideFilter;
- (void)clearFilter;

// Task interaction
- (void)startDocumentTaskForTab:(nullable NSNotification *)aNotification;
- (void)endDocumentTaskForTab:(nullable NSNotification *)aNotification;
- (void)setTableListSelectability:(BOOL)isSelectable;
- (BOOL)isTableNameValid:(nullable NSString *)tableName forType:(SPTableType)tableType;
- (BOOL)isTableNameValid:(nullable NSString *)tableName forType:(SPTableType)tableType ignoringSelectedTable:(BOOL)ignoreSelectedTable;
- (BOOL)selectionShouldChangeInTableView:(nullable NSTableView *)aTableView;

@end
