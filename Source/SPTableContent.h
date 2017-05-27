//
//  SPTableContent.h
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
@class SPCopyTable;
@class SPTextAndLinkCell;
@class SPHistoryController;
@class SPTableInfo;
@class SPDataStorage;
@class SPTextView;
@class SPFieldEditorController;
@class SPMySQLConnection;
@class SPMySQLStreamingResultStore;
@class SPTableData;
@class SPDatabaseDocument;
@class SPTablesList;
@class SPTableStructure;
@class SPTableList;
@class SPContentFilterManager;
#ifndef SP_CODA
@class SPSplitView;
#endif
@class SPTableContentFilterController;

#import "SPDatabaseContentViewDelegate.h"

@interface SPTableContent : NSObject <NSTableViewDelegate, NSTableViewDataSource, NSComboBoxDataSource, NSComboBoxDelegate>
{	
	IBOutlet SPDatabaseDocument *tableDocumentInstance;
	IBOutlet id tablesListInstance;
	IBOutlet SPTableData* tableDataInstance;
	IBOutlet id tableSourceInstance;

#ifndef SP_CODA
	IBOutlet SPTableInfo *tableInfoInstance;
	IBOutlet SPHistoryController *spHistoryControllerInstance;
#endif
	
	IBOutlet SPCopyTable *tableContentView;
	IBOutlet NSPopUpButton *fieldField;
	IBOutlet id compareField;
	IBOutlet id argumentField;
	IBOutlet id filterButton;
	IBOutlet id queryButton;
	IBOutlet id addButton;
	IBOutlet id duplicateButton;
	IBOutlet id removeButton;
	IBOutlet id reloadButton;
#ifndef SP_CODA
	IBOutlet NSButton *multipleLineEditingButton;
	IBOutlet id countText;
	IBOutlet id limitRowsField;
	IBOutlet id limitRowsButton;
	IBOutlet id limitRowsStepper;
#endif
	IBOutlet id firstBetweenField;
	IBOutlet id secondBetweenField;
	IBOutlet id betweenTextField;

	IBOutlet NSButton *paginationPreviousButton;
#ifndef SP_CODA
	IBOutlet NSButton *paginationButton;
	IBOutlet NSButton *paginationGoButton;
#endif
	IBOutlet NSButton *paginationNextButton;
#ifndef SP_CODA
	IBOutlet NSView *contentViewPane;
	IBOutlet NSViewController *paginationViewController;
	IBOutlet NSView *paginationView;
	IBOutlet NSBox *paginationBox;
	NSPopover *paginationPopover;
#endif
	IBOutlet NSTextField *paginationPageField;
#ifndef SP_CODA
	IBOutlet NSStepper *paginationPageStepper;

	IBOutlet SPCopyTable *filterTableView;
	IBOutlet NSPanel *filterTableWindow;
	IBOutlet SPSplitView *filterTableSplitView;
	IBOutlet NSTextField *filterTableQueryTitle;
	IBOutlet NSButton *filterTableFilterButton;
	IBOutlet NSButton *filterTableClearButton;
	IBOutlet SPTextView *filterTableWhereClause;
	IBOutlet NSButton *filterTableNegateCheckbox;
	IBOutlet NSButton *filterTableDistinctCheckbox;
	IBOutlet NSButton *filterTableLiveSearchCheckbox;
	IBOutlet NSButton *filterTableSearchAllFields;
	IBOutlet NSPanel *filterTableSetDefaultOperatorSheet;
	IBOutlet NSComboBox* filterTableSetDefaultOperatorValue;

	// Temporary to avoid nib conflicts during WIP
	IBOutlet SPSplitView *contentSplitView;

	IBOutlet SPTableContentFilterController *filterControllerInstance;
#endif
	SPMySQLConnection *mySQLConnection;

	BOOL _mainNibLoaded;
	BOOL isWorking;
	pthread_mutex_t tableValuesLock;
#ifndef SP_CODA
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

#ifndef SP_CODA
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
	NSDictionary *selectionToRestore;
	NSRect selectionViewportToRestore;
	NSString *filterFieldToRestore, *filterComparisonToRestore, *filterValueToRestore, *firstBetweenValueToRestore, *secondBetweenValueToRestore;

#ifndef SP_CODA
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
	NSColor *blueColor;
	NSColor *whiteColor;

	SPFieldEditorController *fieldEditor;
	NSRange fieldEditorSelectedRange;
}

#ifdef SP_CODA /* glue */
@property (assign) id filterButton;
@property (assign) id fieldField;
@property (assign) id compareField;
@property (assign) id betweenTextField;
@property (assign) id firstBetweenField;
@property (assign) id secondBetweenField;
@property (assign) id argumentField;
@property (assign) NSButton* addButton;
@property (assign) NSButton* duplicateButton;
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

- (void)setFieldEditorSelectedRange:(NSRange)aRange;
- (NSRange)fieldEditorSelectedRange;

// Table loading methods and information
- (void)loadTable:(NSString *)aTable;
- (void)setTableDetails:(NSDictionary *)tableDetails;
- (void)clearTableValues;
- (void)loadTableValues;
- (NSString *)tableFilterString;
- (void)updateCountText;
- (void)initTableLoadTimer;
- (void)clearTableLoadTimer;
- (void)tableLoadUpdate:(NSTimer *)theTimer;

// Table interface actions
- (IBAction)reloadTable:(id)sender;
- (void)reloadTableTask;
- (IBAction)filterTable:(id)sender;
- (IBAction)goToQuery:(id)sender;
- (void)filterTableTask;
- (IBAction)toggleFilterField:(id)sender;
- (void)setUsedQuery:(NSString *)query;

// Pagination
- (IBAction)navigatePaginationFromButton:(id)sender;
#ifndef SP_CODA
- (IBAction)togglePagination:(NSButton *)sender;
#endif
- (void)setPaginationViewVisibility:(BOOL)makeVisible;
- (void)updatePaginationState;

// Edit methods
- (IBAction)addRow:(id)sender;
- (IBAction)duplicateRow:(id)sender;
- (IBAction)removeRow:(id)sender;
- (void)removeRowSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(NSString *)contextInfo;

// Filter Table
- (IBAction)tableFilterClear:(id)sender;
- (IBAction)showFilterTable:(id)sender;
- (IBAction)toggleNegateClause:(id)sender;
- (IBAction)toggleDistinctSelect:(id)sender;
- (IBAction)setDefaultOperator:(id)sender;
- (IBAction)toggleLookAllFieldsMode:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)showDefaultOperaterHelp:(id)sender;

// Data accessors
- (NSArray *)currentResult;
- (NSArray *)currentDataResultWithNULLs:(BOOL)includeNULLs hideBLOBs:(BOOL)hide;

// Task interaction
- (void)startDocumentTaskForTab:(NSNotification *)aNotification;
- (void)endDocumentTaskForTab:(NSNotification *)aNotification;

// Additional methods
- (void)setConnection:(SPMySQLConnection *)theConnection;
- (void)clickLinkArrow:(SPTextAndLinkCell *)theArrowCell;
- (void)clickLinkArrowTask:(SPTextAndLinkCell *)theArrowCell;
- (IBAction)setCompareTypes:(id)sender;
- (void)updateResultStore:(SPMySQLStreamingResultStore *)theResultStore approximateRowCount:(NSUInteger)targetRowCount;
- (BOOL)saveRowToTable;
- (void) addRowErrorSheetDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (NSString *)argumentForRow:(NSInteger)row;
- (NSString *)argumentForRow:(NSInteger)row excludingLimits:(BOOL)excludeLimits;
- (NSString *)argumentForRow:(NSUInteger)rowIndex ofTable:(NSString *)tableForColumn andDatabase:(NSString *)database includeBlobs:(BOOL)includeBlobs;
- (BOOL)tableContainsBlobOrTextColumns;
- (NSString *)fieldListForQuery;
- (void)updateNumberOfRows;
- (void)autosizeColumns;
- (BOOL)saveRowOnDeselect;
- (void)sortTableTaskWithColumn:(NSTableColumn *)tableColumn;
- (void)showErrorSheetWith:(NSArray *)error;
- (void)processFieldEditorResult:(id)data contextInfo:(NSDictionary*)contextInfo;
- (void)saveViewCellValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSUInteger)rowIndex;

// Retrieving and setting table state
- (NSString *)sortColumnName;
- (BOOL)sortColumnIsAscending;
- (NSUInteger)pageNumber;
- (NSDictionary *)selectionDetailsAllowingIndexSelection:(BOOL)allowIndexFallback;
- (NSRect)viewport;
- (CGFloat)tablesListWidth;
- (NSDictionary *)filterSettings;
- (void)setSortColumnNameToRestore:(NSString *)theSortColumnName isAscending:(BOOL)isAscending;
- (void)setPageToRestore:(NSUInteger)thePage;
- (void)setSelectionToRestore:(NSDictionary *)theSelection;
- (void)setViewportToRestore:(NSRect)theViewport;
- (void)setFiltersToRestore:(NSDictionary *)filterSettings;
- (void)storeCurrentDetailsForRestoration;
- (void)clearDetailsToRestore;
- (void)setFilterTableData:(NSData *)arcData;
- (NSData *)filterTableData;

//- (NSString *)escapeFilterArgument:(NSString *)argument againstClause:(NSString *)clause;
- (void)openContentFilterManager;

- (NSArray *)fieldEditStatusForRow:(NSInteger)rowIndex andColumn:(NSInteger)columnIndex;

@end
