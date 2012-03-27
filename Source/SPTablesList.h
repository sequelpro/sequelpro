//
//  $Id$
//
//  SPTablesList.h
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

@class SPHistoryController, SPTableView, SPMySQLConnection;
@class SPDatabaseDocument, SPDatabaseData, SPTableStructure, SPTableContent;

#ifdef SP_REFACTOR
@class SQLSidebarViewController;
#endif

@interface NSObject (NSSplitView)

- (NSView *)collapsibleSubview;
- (IBAction)toggleCollapse:(id)sender;
- (BOOL)collapsibleSubviewIsCollapsed;
- (void)setCollapsibleSubviewCollapsed:(BOOL)flag;

@end

@interface SPTablesList : NSObject 
#ifdef SP_REFACTOR
<NSTextFieldDelegate>
#endif
{
	IBOutlet SPDatabaseDocument*	tableDocumentInstance;
	IBOutlet SPTableStructure* tableSourceInstance;
	IBOutlet SPTableContent* tableContentInstance;
#ifndef SP_REFACTOR /* ivars */
	IBOutlet id customQueryInstance;
	IBOutlet id tableDumpInstance;
	IBOutlet id tableDataInstance;
	IBOutlet id extendedTableInfoInstance;
#endif
	IBOutlet SPDatabaseData* databaseDataInstance;
#ifndef SP_REFACTOR /* ivars */
	IBOutlet id tableInfoInstance;
	IBOutlet id tableTriggersInstance;
	IBOutlet SPHistoryController *spHistoryControllerInstance;

	IBOutlet id copyTableSheet;
#endif
	IBOutlet SPTableView *tablesListView;
#ifndef SP_REFACTOR /* ivars */
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
#ifdef SP_REFACTOR
	id toolbarDeleteButton;
#endif
#ifndef SP_REFACTOR
	IBOutlet id toolbarActionsButton;
	IBOutlet id toolbarReloadButton;
#endif
	IBOutlet id addTableButton;
#ifndef SP_REFACTOR
	IBOutlet id truncateTableButton;
	IBOutlet NSSplitView *tableListSplitView;
	IBOutlet NSSplitView *tableListFilterSplitView;
	IBOutlet NSButton *tableInfoCollapseButton;

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
	
#ifndef SP_REFACTOR /* ivars */
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
	NSInteger selectedTableType;
	NSString *selectedTableName;
	BOOL isTableListFiltered;
	BOOL tableListIsSelectable;
	BOOL tableListContainsViews;
	BOOL alertSheetOpened;

#ifndef SP_REFACTOR /* ivars */
	NSFont *smallSystemFont;
#endif

#ifdef SP_REFACTOR
	SQLSidebarViewController* sidebarViewController;
#endif
}

// IBAction methods
- (IBAction)updateTables:(id)sender;

- (IBAction)addTable:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)removeTable:(id)sender;
#ifndef SP_REFACTOR /* method decls */
- (IBAction)copyTable:(id)sender;
- (IBAction)renameTable:(id)sender;
- (IBAction)truncateTable:(id)sender;
- (IBAction)openTableInNewTab:(id)sender;
- (IBAction)togglePaneCollapse:(id)sender;
#endif
// Additional methods
- (void)setConnection:(SPMySQLConnection *)theConnection;
- (void)setSelectionState:(NSDictionary *)selectionDetails;
#ifndef SP_REFACTOR /* method decls */
- (void)selectTableAtIndex:(NSNumber *)row;
- (void)makeTableListFilterHaveFocus;
#endif

// Getters
- (NSArray *)selectedTableNames;
#ifndef SP_REFACTOR /* method decls */
- (NSArray *)selectedTableItems;
- (NSArray *)selectedTableTypes;
#endif
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
#ifndef SP_REFACTOR /* method decls */
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

#ifdef SP_REFACTOR /* method decls */
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
