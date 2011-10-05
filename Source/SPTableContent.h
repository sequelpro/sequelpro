//
//  $Id$
//
//  SPDatabaseDocument.h
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

#import <MCPKit/MCPKit.h>

@class SPDatabaseDocument, SPCopyTable, SPTextAndLinkCell, SPHistoryController, SPTableInfo, SPDataStorage, SPTextView, SPFieldEditorController;
@class SPTableData, SPDatabaseDocument, SPTablesList, SPTableStructure, SPTableList, SPContentFilterManager;

@interface SPTableContent : NSObject
#ifdef SP_REFACTOR
<NSTableViewDelegate, NSTableViewDataSource, NSComboBoxDataSource, NSComboBoxDelegate>
#endif
{	
	IBOutlet SPDatabaseDocument *tableDocumentInstance;
	IBOutlet id tablesListInstance;
	IBOutlet SPTableData* tableDataInstance;
	IBOutlet id tableSourceInstance;

#ifndef SP_REFACTOR
	IBOutlet SPTableInfo *tableInfoInstance;
	IBOutlet SPHistoryController *spHistoryControllerInstance;
#endif
	
	IBOutlet SPCopyTable *tableContentView;
	IBOutlet NSPopUpButton *fieldField;
	IBOutlet id compareField;
	IBOutlet id argumentField;
	IBOutlet id filterButton;
	IBOutlet id addButton;
	IBOutlet id copyButton;
	IBOutlet id removeButton;
	IBOutlet id reloadButton;
#ifndef SP_REFACTOR
	IBOutlet id multipleLineEditingButton;
	IBOutlet id countText;
	IBOutlet id limitRowsField;
	IBOutlet id limitRowsButton;
	IBOutlet id limitRowsStepper;
#endif
	IBOutlet id firstBetweenField;
	IBOutlet id secondBetweenField;
	IBOutlet id betweenTextField;

	IBOutlet NSButton *paginationPreviousButton;
#ifndef SP_REFACTOR
	IBOutlet NSButton *paginationButton;
#endif
	IBOutlet NSButton *paginationNextButton;
#ifndef SP_REFACTOR
	IBOutlet NSView *contentViewPane;
	IBOutlet NSView *paginationView;
#endif
	IBOutlet NSTextField *paginationPageField;
#ifndef SP_REFACTOR
	IBOutlet NSStepper *paginationPageStepper;

	IBOutlet SPCopyTable *filterTableView;
	IBOutlet NSPanel *filterTableWindow;
	IBOutlet NSButton *filterTableFilterButton;
	IBOutlet NSButton *filterTableClearButton;
	IBOutlet SPTextView *filterTableWhereClause;
	IBOutlet NSButton *filterTableNegateCheckbox;
	IBOutlet NSMenuItem *filterTableDistinctMenuItem;
	IBOutlet NSButton *filterTableLiveSearchCheckbox;
	IBOutlet NSMenuItem *filterTableGearLookAllFields;
	IBOutlet NSPanel *filterTableSetDefaultOperatorSheet;
	IBOutlet NSComboBox* filterTableSetDefaultOperatorValue;
#endif
	MCPConnection *mySQLConnection;

	BOOL _mainNibLoaded;
	BOOL isWorking;
	pthread_mutex_t tableValuesLock;
#ifndef SP_REFACTOR
	NSMutableArray *nibObjectsToRelease;
#endif

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
	SPContentFilterManager *contentFilterManager;
	NSUInteger contentPage;

#ifndef SP_REFACTOR
	NSMutableDictionary *filterTableData;
	BOOL filterTableNegate;
	BOOL filterTableDistinct;
	BOOL filterTableIsSwapped;
	NSString *filterTableDefaultOperator;
	NSString *lastEditedFilterTableValue;
	NSInteger activeFilter; // 0 = default filter; 1 = filter table; 2 = sequelpro url scheme
	NSString *schemeFilter;
#endif

	BOOL sortColumnToRestoreIsAsc;
	BOOL tableRowsSelectable;
	NSString *sortColumnToRestore;
	NSUInteger pageToRestore;
	NSIndexSet *selectionIndexToRestore;
	NSRect selectionViewportToRestore;
	NSString *filterFieldToRestore, *filterComparisonToRestore, *filterValueToRestore, *firstBetweenValueToRestore, *secondBetweenValueToRestore;

#ifndef SP_REFACTOR
	NSInteger paginationViewHeight;
#endif

	NSTimer *tableLoadTimer;
	NSUInteger tableLoadInterfaceUpdateInterval, tableLoadTimerTicksSinceLastUpdate, tableLoadLastRowCount, tableLoadTargetRowCount;

	NSArray *cqColumnDefinition;
	NSString *fieldIDQueryString;
	BOOL isFirstChangeInView;

	NSString *kCellEditorErrorNoMatch;
	NSString *kCellEditorErrorNoMultiTabDb;
	NSString *kCellEditorErrorTooManyMatches;

	NSColor *blackColor;
	NSColor *lightGrayColor;

	SPFieldEditorController *fieldEditor;
	NSRange fieldEditorSelectedRange;
}

- (void)setFieldEditorSelectedRange:(NSRange)aRange;
- (NSRange)fieldEditorSelectedRange;

// Table loading methods and information
- (void) loadTable:(NSString *)aTable;
- (void) clearTableValues;
- (void) loadTableValues;
- (NSString *) tableFilterString;
- (void) updateCountText;
- (void) initTableLoadTimer;
- (void) clearTableLoadTimer;
- (void) tableLoadUpdate:(NSTimer *)theTimer;

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
#ifndef SP_REFACTOR
- (IBAction) togglePagination:(id)sender;
#endif
- (void) setPaginationViewVisibility:(BOOL)makeVisible;
- (void) updatePaginationState;

// Edit methods
- (IBAction)addRow:(id)sender;
- (IBAction)copyRow:(id)sender;
- (IBAction)removeRow:(id)sender;
- (void)removeRowSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo;

// Filter Table
- (IBAction)tableFilterClear:(id)sender;
- (IBAction)showFilterTable:(id)sender;
- (IBAction)toggleNegateClause:(id)sender;
- (IBAction)toggleDistinctSelect:(id)sender;
- (IBAction)setDefaultOperator:(id)sender;
- (IBAction)swapFilterTable:(id)sender;
- (IBAction)toggleLookAllFieldsMode:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)showDefaultOperaterHelp:(id)sender;

// Data accessors
- (NSArray *)currentResult;
- (NSArray *)currentDataResultWithNULLs:(BOOL)includeNULLs;

// Task interaction
- (void) startDocumentTaskForTab:(NSNotification *)aNotification;
- (void) endDocumentTaskForTab:(NSNotification *)aNotification;

// Additional methods
- (void)setConnection:(MCPConnection *)theConnection;
- (void)clickLinkArrow:(SPTextAndLinkCell *)theArrowCell;
- (void)clickLinkArrowTask:(SPTextAndLinkCell *)theArrowCell;
- (IBAction)setCompareTypes:(id)sender;
- (void)processResultIntoDataStorage:(MCPStreamingResult *)theResult approximateRowCount:(NSUInteger)targetRowCount;
- (BOOL)saveRowToTable;
- (void) addRowErrorSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (NSString *)argumentForRow:(NSInteger)row;
- (NSString *)argumentForRow:(NSInteger)row excludingLimits:(BOOL)excludeLimits;
- (NSString *)argumentForRow:(NSUInteger)rowIndex ofTable:(NSString *)tableForColumn andDatabase:(NSString *)database includeBlobs:(BOOL)includeBlobs;
- (BOOL)tableContainsBlobOrTextColumns;
- (NSString *)fieldListForQuery;
- (void)updateNumberOfRows;
- (NSInteger)fetchNumberOfRows;
- (void)autosizeColumns;
- (BOOL)saveRowOnDeselect;
- (void)sortTableTaskWithColumn:(NSTableColumn *)tableColumn;
- (void)showErrorSheetWith:(id)error;
- (void)processFieldEditorResult:(id)data contextInfo:(NSDictionary*)contextInfo;
- (void)saveViewCellValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSUInteger)rowIndex;

// Retrieving and setting table state
- (NSString *) sortColumnName;
- (BOOL) sortColumnIsAscending;
- (NSUInteger) pageNumber;
- (NSIndexSet *) selectedRowIndexes;
- (NSRect) viewport;
- (CGFloat) tablesListWidth;
- (NSDictionary *) filterSettings;
- (NSArray *)dataColumnDefinitions;
- (void) setSortColumnNameToRestore:(NSString *)theSortColumnName isAscending:(BOOL)isAscending;
- (void) setPageToRestore:(NSUInteger)thePage;
- (void) setSelectedRowIndexesToRestore:(NSIndexSet *)theIndexSet;
- (void) setViewportToRestore:(NSRect)theViewport;
- (void) setFiltersToRestore:(NSDictionary *)filterSettings;
- (void) storeCurrentDetailsForRestoration;
- (void) clearDetailsToRestore;
- (void) setFilterTableData:(NSData*)arcData;
- (NSData*) filterTableData;

- (NSString *)escapeFilterArgument:(NSString *)argument againstClause:(NSString *)clause;
- (void)openContentFilterManager;
- (void)makeContentFilterHaveFocus;

- (NSArray*)fieldEditStatusForRow:(NSInteger)rowIndex andColumn:(NSNumber *)columnIndex;

- (void)updateFilterTableClause:(id)currentValue;
- (NSString*)escapeFilterTableDefaultOperator:(NSString*)anOperator;

#ifdef SP_REFACTOR /* glue */
@property (assign) id filterButton;
@property (assign) id fieldField;
@property (assign) id compareField;
@property (assign) id betweenTextField;
@property (assign) id firstBetweenField;
@property (assign) id secondBetweenField;
@property (assign) id argumentField;
@property (assign) NSButton* addButton;
@property (assign) NSButton* copyButton;
@property (assign) NSButton* removeButton;
@property (assign) NSButton* reloadButton;
@property (assign) NSButton* paginationNextButton;
@property (assign) NSButton* paginationPreviousButton;
@property (assign) NSTextField* paginationPageField;
@property (assign) SPDatabaseDocument* tableDocumentInstance;
@property (assign) SPTablesList* tablesListInstance;
@property (assign) SPCopyTable* tableContentView;
@property (assign) SPTableData* tableDataInstance;
@property (assign) SPTableStructure* tableSourceInstance;
#endif

@end
