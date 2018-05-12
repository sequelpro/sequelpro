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
@class SPTableContentFilterController;
@class SPFilterTableController;

typedef NS_ENUM(NSInteger, SPTableContentFilterSource) {
	SPTableContentFilterSourceNone = -1,
	SPTableContentFilterSourceRuleFilter = 0,
	SPTableContentFilterSourceTableFilter = 1,
	SPTableContentFilterSourceURLScheme = 2,
};

#import "SPDatabaseContentViewDelegate.h"

@interface SPTableContent : NSObject <NSTableViewDelegate, NSTableViewDataSource, NSComboBoxDataSource, NSComboBoxDelegate, SPDatabaseContentViewDelegate>
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

	IBOutlet NSButton *toggleRuleFilterButton;
	IBOutlet id addButton;
	IBOutlet id duplicateButton;
	IBOutlet id removeButton;
	IBOutlet id reloadButton;
#ifndef SP_CODA
	IBOutlet NSButton *multipleLineEditingButton;
	IBOutlet NSTextField *countText;
	IBOutlet id limitRowsField;
	IBOutlet id limitRowsButton;
	IBOutlet id limitRowsStepper;
#endif

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

	IBOutlet SPTableContentFilterController *filterControllerInstance;
	IBOutlet SPFilterTableController *filterTableController;
	BOOL scrollViewHasRubberbandScrolling;
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
	NSNumber *sortCol;
	BOOL isEditingRow, isEditingNewRow, isSavingRow, isDesc, setLimit;
	BOOL isFiltered, isLimited, isInterruptedLoad, maxNumRowsIsEstimate;
	NSUserDefaults *prefs;
	NSInteger currentlyEditingRow, maxNumRows;

	NSUInteger contentPage;

#ifndef SP_CODA
	SPTableContentFilterSource activeFilter;
	SPTableContentFilterSource activeFilterToRestore;
	NSString *schemeFilter;
#endif

	BOOL sortColumnToRestoreIsAsc;
	BOOL tableRowsSelectable;
	NSString *sortColumnToRestore;
	NSUInteger pageToRestore;
	NSDictionary *selectionToRestore;
	NSRect selectionViewportToRestore;

#ifndef SP_CODA
	NSInteger paginationViewHeight;
#endif

	NSTimer *tableLoadTimer;
	NSUInteger tableLoadInterfaceUpdateInterval, tableLoadTimerTicksSinceLastUpdate, tableLoadLastRowCount, tableLoadTargetRowCount;

	NSArray *cqColumnDefinition;
	BOOL isFirstChangeInView;

	NSString *kCellEditorErrorNoMatch;
	NSString *kCellEditorErrorNoMultiTabDb;
	NSString *kCellEditorErrorTooManyMatches;

	NSColor *blackColor;
	NSColor *lightGrayColor;
	NSColor *blueColor;
	NSColor *whiteColor;

	SPFieldEditorController *fieldEditor;

	// this represents the visible area of the whole content view at runtime.
	// we use it as a positioning aide for the other two views below
	IBOutlet NSView *contentAreaContainer;
	IBOutlet NSView *filterRuleEditorContainer;
	IBOutlet NSView *tableContentContainer;

	BOOL showFilterRuleEditor;

	NSDictionary *filtersToRestore;
}

#ifdef SP_CODA /* glue */
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
- (IBAction)toggleRuleEditorVisible:(id)sender;
- (void)filterTableTask;
- (void)setUsedQuery:(NSString *)query;
- (NSString *)selectedTable;

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
- (IBAction)showFilterTable:(id)sender;

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
- (void)setActiveFilterToRestore:(SPTableContentFilterSource)filter;
- (SPTableContentFilterSource)activeFilter;
- (void)setFilterTableData:(NSData *)arcData;
- (NSData *)filterTableData;

//- (NSString *)escapeFilterArgument:(NSString *)argument againstClause:(NSString *)clause;

- (NSArray *)fieldEditStatusForRow:(NSInteger)rowIndex andColumn:(NSInteger)columnIndex;

#pragma mark - SPTableContentDataSource

- (BOOL)cellValueIsDisplayedAsHexForColumn:(NSUInteger)columnIndex;

#pragma mark - SPTableContentFilter

- (void)makeContentFilterHaveFocus;

@end
