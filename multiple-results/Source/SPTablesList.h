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

#import <Cocoa/Cocoa.h>
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
	IBOutlet id copyTableContentSwitch;
	IBOutlet id tabView;
	IBOutlet id tableSheet;
	IBOutlet id tableNameField;
	IBOutlet id tableEncodingButton;
	IBOutlet id tableTypeButton;
	IBOutlet id toolbarAddButton;
	IBOutlet id toolbarActionsButton;
	IBOutlet id toolbarReloadButton;
	IBOutlet id addTableButton;
	IBOutlet id truncateTableButton;
	IBOutlet id truncateTableContextButton;
	IBOutlet NSSplitView *tableListSplitView;
	IBOutlet NSSplitView *tableListFilterSplitView;
	IBOutlet NSButton *tableInfoCollapseButton;

	IBOutlet NSSearchField *listFilterField;

	// Table list 'gear' menu items
	IBOutlet NSMenuItem *removeTableMenuItem;
	IBOutlet NSMenuItem *duplicateTableMenuItem;
	IBOutlet NSMenuItem *renameTableMenuItem;
	IBOutlet NSMenuItem *separatorTableMenuItem;
	IBOutlet NSMenuItem *showCreateSyntaxMenuItem;
	IBOutlet NSMenuItem *separatorTableMenuItem2;
	
	MCPConnection *mySQLConnection;
	
	// Table list context menu items
	IBOutlet NSMenuItem *removeTableContextMenuItem;
	IBOutlet NSMenuItem *duplicateTableContextMenuItem;
	IBOutlet NSMenuItem *renameTableContextMenuItem;
	IBOutlet NSMenuItem *separatorTableContextMenuItem;
	IBOutlet NSMenuItem *showCreateSyntaxContextMenuItem;
	IBOutlet NSMenuItem *separatorTableContextMenuItem2;

	NSMutableArray *tables;
	NSMutableArray *filteredTables;
	NSMutableArray *tableTypes;
	NSMutableArray *filteredTableTypes;
	NSInteger selectedTableType;
	NSString *selectedTableName;
	BOOL isTableListFiltered;
	BOOL tableListIsSelectable;
	BOOL tableListContainsViews;

	BOOL structureLoaded, contentLoaded, statusLoaded, triggersLoaded, alertSheetOpened;
}

// IBAction methods
- (IBAction)updateTables:(id)sender;
- (IBAction)addTable:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)removeTable:(id)sender;
- (IBAction)copyTable:(id)sender;
- (IBAction)renameTable:(id)sender;
- (IBAction)truncateTable:(id)sender;
- (IBAction)togglePaneCollapse:(id)sender;

// Additional methods
- (void)setConnection:(MCPConnection *)theConnection;
- (void)doPerformQueryService:(NSString *)query;
- (void)updateSelectionWithTaskString:(NSString *)taskString;
- (void)updateSelectionTask;
- (void)setSelection:(NSDictionary *)selectionDetails;
- (void)selectTableAtIndex:(NSNumber *)row;
- (void)makeTableListFilterHaveFocus;

// Getters
- (NSArray *)selectedTableNames;
- (NSArray *)selectedTableItems;
- (NSString *)tableName;
- (NSInteger)tableType;
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
- (BOOL)structureLoaded;
- (BOOL)contentLoaded;
- (BOOL)statusLoaded;

// Setters
- (void)setContentRequiresReload:(BOOL)reload;
- (void)setStatusRequiresReload:(BOOL)reload;
- (BOOL)selectItemWithName:(NSString *)theName;

// Tabview delegate methods
- (void)loadTabTask:(NSTabViewItem *)tabViewItem;

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
