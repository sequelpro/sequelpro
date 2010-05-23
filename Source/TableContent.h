//
//  $Id$
//
//  TableDocument.h
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed May 01 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//  
//  Forked by Abhi Beckert (abhibeckert.com) 2008-04-04
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

@class CMCopyTable, SPTextAndLinkCell, SPHistoryController, SPTableInfo, SPDataStorage;

@interface TableContent : NSObject 
{	
	IBOutlet id tableDocumentInstance;
	IBOutlet id tablesListInstance;
	IBOutlet id tableDataInstance;
	IBOutlet id tableSourceInstance;

	IBOutlet SPTableInfo *tableInfoInstance;
	IBOutlet SPHistoryController *spHistoryControllerInstance;
	
	IBOutlet CMCopyTable *tableContentView;
	IBOutlet NSPopUpButton *fieldField;
	IBOutlet id compareField;
	IBOutlet id argumentField;
	IBOutlet id filterButton;
	IBOutlet id addButton;
	IBOutlet id copyButton;
	IBOutlet id removeButton;
	IBOutlet id reloadButton;
	IBOutlet id multipleLineEditingButton;
	IBOutlet id countText;
	IBOutlet id limitRowsField;
	IBOutlet id limitRowsButton;
	IBOutlet id limitRowsStepper;
	IBOutlet id firstBetweenField;
	IBOutlet id secondBetweenField;
	IBOutlet id betweenTextField;

	IBOutlet NSButton *paginationPreviousButton;
	IBOutlet NSButton *paginationButton;
	IBOutlet NSButton *paginationNextButton;
	IBOutlet NSView *contentViewPane;
	IBOutlet NSView *paginationView;
	IBOutlet NSTextField *paginationPageField;
	IBOutlet NSStepper *paginationPageStepper;
	
	MCPConnection *mySQLConnection;

	BOOL _mainNibLoaded;
	BOOL isWorking;
	pthread_mutex_t tableValuesLock;
	NSMutableArray *nibObjectsToRelease;

	NSString *selectedTable, *usedQuery;
	SPDataStorage *tableValues;
	NSMutableArray *dataColumns, *keys, *oldRow;
	NSUInteger tableRowsCount, previousTableRowsCount;
	NSString *compareType;
	NSNumber *sortCol;
	BOOL isEditingRow, isEditingNewRow, isSavingRow, isDesc, setLimit;
	BOOL isFiltered, isLimited, isInterruptedLoad, maxNumRowsIsEstimate;
	NSUserDefaults *prefs;
	NSInteger currentlyEditingRow, maxNumRows;

	NSMutableDictionary *contentFilters;
	NSMutableDictionary *numberOfDefaultFilters;
	NSUInteger lastSelectedContentFilterIndex;
	id contentFilterManager;
	NSUInteger contentPage;

	BOOL sortColumnToRestoreIsAsc;
	BOOL tableRowsSelectable;
	NSString *sortColumnToRestore;
	NSUInteger pageToRestore;
	NSIndexSet *selectionIndexToRestore;
	NSRect selectionViewportToRestore;
	NSString *filterFieldToRestore, *filterComparisonToRestore, *filterValueToRestore, *firstBetweenValueToRestore, *secondBetweenValueToRestore;

	NSInteger paginationViewHeight;
}

// Table loading methods and information
- (void) loadTable:(NSString *)aTable;
- (void) clearTableValues;
- (void) loadTableValues;
- (NSString *) tableFilterString;
- (void) updateCountText;

// Table interface actions
- (IBAction) reloadTable:(id)sender;
- (void) reloadTableTask;
- (IBAction) filterTable:(id)sender;
- (void)filterTableTask;
- (IBAction) toggleFilterField:(id)sender;
- (NSString *) usedQuery;
- (void) setUsedQuery:(NSString *)query;

// Pagination
- (IBAction) navigatePaginationFromButton:(id)sender;
- (IBAction) togglePagination:(id)sender;
- (void) setPaginationViewVisibility:(BOOL)makeVisible;
- (void) updatePaginationState;

// Edit methods
- (IBAction)addRow:(id)sender;
- (IBAction)copyRow:(id)sender;
- (IBAction)removeRow:(id)sender;

// Getter methods
- (NSArray *)currentResult;
- (NSArray *)currentDataResult;

// Task interaction
- (void) startDocumentTaskForTab:(NSNotification *)aNotification;
- (void) endDocumentTaskForTab:(NSNotification *)aNotification;

// Additional methods
- (void)setConnection:(MCPConnection *)theConnection;
- (void)clickLinkArrow:(SPTextAndLinkCell *)theArrowCell;
- (void)clickLinkArrowTask:(SPTextAndLinkCell *)theArrowCell;
- (IBAction)setCompareTypes:(id)sender;
- (void)processResultIntoDataStorage:(MCPStreamingResult *)theResult approximateRowCount:(NSUInteger)targetRowCount;
- (BOOL)addRowToDB;
- (NSString *)argumentForRow:(NSInteger)row;
- (BOOL)tableContainsBlobOrTextColumns;
- (NSString *)fieldListForQuery;
- (void)updateNumberOfRows;
- (NSInteger)fetchNumberOfRows;
- (BOOL)saveRowOnDeselect;
- (void)sortTableTaskWithColumn:(NSTableColumn *)tableColumn;

// Retrieving and setting table state
- (NSString *) sortColumnName;
- (BOOL) sortColumnIsAscending;
- (NSUInteger) pageNumber;
- (NSIndexSet *) selectedRowIndexes;
- (NSRect) viewport;
- (NSDictionary *) filterSettings;
- (void) setSortColumnNameToRestore:(NSString *)theSortColumnName isAscending:(BOOL)isAscending;
- (void) setPageToRestore:(NSUInteger)thePage;
- (void) setSelectedRowIndexesToRestore:(NSIndexSet *)theIndexSet;
- (void) setViewportToRestore:(NSRect)theViewport;
- (void) setFiltersToRestore:(NSDictionary *)filterSettings;
- (void) storeCurrentDetailsForRestoration;
- (void) clearDetailsToRestore;

- (NSString *)escapeFilterArgument:(NSString *)argument againstClause:(NSString *)clause;
- (void)openContentFilterManager;
- (void)makeContentFilterHaveFocus;

@end
