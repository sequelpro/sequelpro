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

#import <MCPKit/MCPKit.h>

@class SPHistoryController;

@interface NSObject (NSSplitView)

- (NSView *)collapsibleSubview;
- (IBAction)toggleCollapse:(id)sender;
- (BOOL)collapsibleSubviewIsCollapsed;
- (void)setCollapsibleSubviewCollapsed:(BOOL)flag;

@end

@interface SPTablesList : NSObject 
{
	IBOutlet id tableDocumentInstance;
	IBOutlet id tableSourceInstance;
	IBOutlet id tableContentInstance;
	IBOutlet id customQueryInstance;
	IBOutlet id tableDumpInstance;
	IBOutlet id tableDataInstance;
	IBOutlet id extendedTableInfoInstance;
	IBOutlet id databaseDataInstance;
	IBOutlet id tableInfoInstance;
	IBOutlet id tableTriggersInstance;
	IBOutlet SPHistoryController *spHistoryControllerInstance;

	IBOutlet id copyTableSheet;
	IBOutlet id tablesListView;
	IBOutlet id copyTableButton;
	IBOutlet id copyTableNameField;
	IBOutlet id copyTableMessageField;
	IBOutlet NSButton *copyTableContentSwitch;
	IBOutlet id tableSheet;
	IBOutlet id tableNameField;
	IBOutlet id tableEncodingButton;
	IBOutlet id tableTypeButton;
	IBOutlet id toolbarAddButton;
	IBOutlet id toolbarActionsButton;
	IBOutlet id toolbarReloadButton;
	IBOutlet id addTableButton;
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
	IBOutlet NSMenuItem *separatorTableMenuItem2;
	
	MCPConnection *mySQLConnection;
	
	// Table list context menu items
	IBOutlet NSMenuItem *removeTableContextMenuItem;
	IBOutlet NSMenuItem *duplicateTableContextMenuItem;
	IBOutlet NSMenuItem *truncateTableContextMenuItem;
	IBOutlet NSMenuItem *renameTableContextMenuItem;
	IBOutlet NSMenuItem *openTableInNewTabContextMenuItem;
	IBOutlet NSMenuItem *separatorTableContextMenuItem;
	IBOutlet NSMenuItem *showCreateSyntaxContextMenuItem;
	IBOutlet NSMenuItem *separatorTableContextMenuItem2;

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

	NSFont *smallSystemFont;

}

// IBAction methods
- (IBAction)updateTables:(id)sender;
- (IBAction)addTable:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)removeTable:(id)sender;
- (IBAction)copyTable:(id)sender;
- (IBAction)renameTable:(id)sender;
- (IBAction)truncateTable:(id)sender;
- (IBAction)openTableInNewTab:(id)sender;
- (IBAction)togglePaneCollapse:(id)sender;

// Alert sheet callbacks
- (void)sheetDidEnd:(id)sheet returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo;

// Additional methods
- (void)setConnection:(MCPConnection *)theConnection;
- (void)setSelectionState:(NSDictionary *)selectionDetails;
- (void)selectTableAtIndex:(NSNumber *)row;
- (void)makeTableListFilterHaveFocus;

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
- (BOOL)selectItemsWithNames:(NSArray *)theNames;

// Table list filter interaction
- (void) showFilter;
- (void) hideFilter;
- (void) clearFilter;
- (IBAction) updateFilter:(id)sender;

// Task interaction
- (void) startDocumentTaskForTab:(NSNotification *)aNotification;
- (void) endDocumentTaskForTab:(NSNotification *)aNotification;
- (void) setTableListSelectability:(BOOL)isSelectable;

@end
