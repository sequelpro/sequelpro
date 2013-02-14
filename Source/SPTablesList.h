//
//  $Id$
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
//  More info at <http://code.google.com/p/sequel-pro/>

@class SPHistoryController;
@class SPTableView;
@class SPMySQLConnection;
@class SPDatabaseDocument; 
@class SPDatabaseData;
@class SPTableStructure;
@class SPTableContent;
@class SPSplitView;

#ifdef SP_CODA
@class SQLSidebarViewController;
#endif

@interface SPTablesList : NSObject <NSTextFieldDelegate, NSTableViewDelegate>
{
	IBOutlet SPDatabaseDocument*	tableDocumentInstance;
	IBOutlet SPTableStructure* tableSourceInstance;
	IBOutlet SPTableContent* tableContentInstance;
#ifndef SP_CODA /* ivars */
	IBOutlet id customQueryInstance;
	IBOutlet id tableDumpInstance;
	IBOutlet id tableDataInstance;
	IBOutlet id extendedTableInfoInstance;
#endif
	IBOutlet SPDatabaseData* databaseDataInstance;
#ifndef SP_CODA /* ivars */
	IBOutlet id tableInfoInstance;
	IBOutlet id tableTriggersInstance;
	IBOutlet SPHistoryController *spHistoryControllerInstance;

	IBOutlet id copyTableSheet;
#endif
	IBOutlet SPTableView *tablesListView;
#ifndef SP_CODA /* ivars */
	IBOutlet id copyTableButton;
	IBOutlet id copyTableNameField;
	IBOutlet id copyTableMessageField;
	IBOutlet NSButton *copyTableContentSwitch;
#endif
	IBOutlet id tableSheet;
	IBOutlet id tableNameField;
	IBOutlet id tableEncodingButton;
	IBOutlet id tableTypeButton;
	IBOutlet id toolbarAddButton;
#ifdef SP_CODA
	id toolbarDeleteButton;
#endif
#ifndef SP_CODA
	IBOutlet id toolbarActionsButton;
#endif
	IBOutlet id toolbarReloadButton;
	IBOutlet id addTableButton;
#ifndef SP_CODA
	IBOutlet id truncateTableButton;
	IBOutlet SPSplitView *tableListSplitView;
	IBOutlet SPSplitView *tableListFilterSplitView;

	IBOutlet NSSearchField *listFilterField;

	// Table list 'gear' menu items
	IBOutlet NSMenuItem *removeTableMenuItem;
	IBOutlet NSMenuItem *duplicateTableMenuItem;
	IBOutlet NSMenuItem *renameTableMenuItem;
	IBOutlet NSMenuItem *openTableInNewTabMenuItem;
	IBOutlet NSMenuItem *separatorTableMenuItem;
	IBOutlet NSMenuItem *showCreateSyntaxMenuItem;
	IBOutlet NSMenuItem *copyCreateSyntaxMenuItem;
	IBOutlet NSMenuItem *separatorTableMenuItem2;
	IBOutlet NSMenuItem *separatorTableMenuItem3;
#endif
	
	SPMySQLConnection *mySQLConnection;
	
#ifndef SP_CODA /* ivars */
	// Table list context menu items
	IBOutlet NSMenuItem *removeTableContextMenuItem;
	IBOutlet NSMenuItem *duplicateTableContextMenuItem;
	IBOutlet NSMenuItem *truncateTableContextMenuItem;
	IBOutlet NSMenuItem *renameTableContextMenuItem;
	IBOutlet NSMenuItem *openTableInNewTabContextMenuItem;
	IBOutlet NSMenuItem *separatorTableContextMenuItem;
	IBOutlet NSMenuItem *showCreateSyntaxContextMenuItem;
	IBOutlet NSMenuItem *copyCreateSyntaxContextMenuItem;
	IBOutlet NSMenuItem *separatorTableContextMenuItem2;
	IBOutlet NSMenuItem *separatorTableContextMenuItem3;
#endif

	NSMutableArray *tables;
	NSMutableArray *filteredTables;
	NSMutableArray *tableTypes;
	NSMutableArray *filteredTableTypes;
	SPTableType selectedTableType;
	NSString *selectedTableName;
	BOOL isTableListFiltered;
	BOOL tableListIsSelectable;
	BOOL tableListContainsViews;
	BOOL alertSheetOpened;

#ifndef SP_CODA /* ivars */
	NSFont *smallSystemFont;
#endif

#ifdef SP_CODA
	SQLSidebarViewController* sidebarViewController;
#endif
}

// IBAction methods
- (IBAction)updateTables:(id)sender;
- (IBAction)addTable:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)removeTable:(id)sender;

#ifndef SP_CODA /* method decls */
- (IBAction)copyTable:(id)sender;
- (IBAction)renameTable:(id)sender;
- (IBAction)truncateTable:(id)sender;
- (IBAction)openTableInNewTab:(id)sender;
- (IBAction)togglePaneCollapse:(id)sender;
#endif

// Additional methods
- (void)setConnection:(SPMySQLConnection *)theConnection;
- (void)setSelectionState:(NSDictionary *)selectionDetails;

#ifndef SP_CODA /* method decls */
- (void)selectTableAtIndex:(NSNumber *)row;
- (void)makeTableListFilterHaveFocus;
- (void)makeTableListHaveFocus;
#endif

// Getters
- (NSArray *)selectedTableNames;
- (NSArray *)selectedTableItems;
- (NSArray *)selectedTableTypes;
- (NSString *)tableName;
- (SPTableType)tableType;
- (NSArray *)tables;
- (NSArray *)tableTypes;
- (NSArray *)allTableAndViewNames;
- (NSArray *)allTableNames;
- (NSArray *)allViewNames;
- (NSArray *)allFunctionNames;
- (NSArray *)allProcedureNames;
- (NSArray *)allDatabaseNames;
- (NSArray *)allSystemDatabaseNames;
- (NSString *)selectedDatabase;

// Setters
- (BOOL)selectItemWithName:(NSString *)theName;
#ifndef SP_CODA /* method decls */
- (BOOL)selectItemsWithNames:(NSArray *)theNames;

// Table list filter interaction
- (void) showFilter;
- (void) hideFilter;
- (void) clearFilter;
#endif
- (IBAction) updateFilter:(id)sender;

// Task interaction
- (void) startDocumentTaskForTab:(NSNotification *)aNotification;
- (void) endDocumentTaskForTab:(NSNotification *)aNotification;
- (void) setTableListSelectability:(BOOL)isSelectable;
- (BOOL)isTableNameValid:(NSString *)tableName forType:(SPTableType)tableType;
- (BOOL)isTableNameValid:(NSString *)tableName forType:(SPTableType)tableType ignoringSelectedTable:(BOOL)ignoreSelectedTable;

#ifdef SP_CODA /* method decls */
@property (assign) SPTableStructure* tableSourceInstance;
@property (assign) SPTableContent* tableContentInstance;
@property (assign) id toolbarAddButton;
@property (assign) id toolbarDeleteButton;
@property (assign) id toolbarReloadButton;
@property (assign) id tableSheet;
@property (assign) id tableNameField;
@property (assign) id tableEncodingButton;
@property (assign) id tableTypeButton;
@property (assign) id databaseDataInstance;
@property (assign) id addTableButton;
@property (assign) SPTableView* tablesListView;
@property (assign) SQLSidebarViewController* sidebarViewController;

- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView;
- (void)setDatabaseDocument:(SPDatabaseDocument*)val;
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;

#endif
@end
