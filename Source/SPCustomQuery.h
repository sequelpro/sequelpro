//
//  SPCustomQuery.h
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

#import "SPDatabaseContentViewDelegate.h"

#import <WebKit/WebKit.h>

#define SP_HELP_TOC_SEARCH_STRING @"contents"
#define SP_HELP_SEARCH_IN_MYSQL   0
#define SP_HELP_SEARCH_IN_PAGE    1
#define SP_HELP_SEARCH_IN_WEB     2
#define SP_HELP_GOBACK_BUTTON     0
#define SP_HELP_SHOW_TOC_BUTTON   1
#define SP_HELP_GOFORWARD_BUTTON  2
#define SP_HELP_NOT_AVAILABLE     @"__no_help_available"

#define SP_SAVE_ALL_FAVORTITE_MENUITEM_TAG       100001
#define SP_SAVE_SELECTION_FAVORTITE_MENUITEM_TAG 100000
#define SP_FAVORITE_HEADER_MENUITEM_TAG          200000
#define SP_HISTORY_COPY_MENUITEM_TAG             300000
#define SP_HISTORY_SAVE_MENUITEM_TAG             300001
#define SP_HISTORY_CLEAR_MENUITEM_TAG            300002

@class SPCopyTable;
@class SPQueryFavoriteManager;
@class SPDataStorage;
@class SPSplitView;
@class SPFieldEditorController;
@class SPMySQLConnection;
@class SPMySQLStreamingResultStore;
@class SPTextView;
@class SPDatabaseDocument;
@class SPTablesList;


@interface SPCustomQuery : NSObject <NSTableViewDataSource, NSWindowDelegate, NSTableViewDelegate, SPDatabaseContentViewDelegate>
{
	IBOutlet SPDatabaseDocument *tableDocumentInstance;
	IBOutlet SPTablesList *tablesListInstance;

#ifndef SP_CODA
	IBOutlet id queryFavoritesButton;
	IBOutlet NSMenuItem *queryFavoritesSearchMenuItem;
	IBOutlet NSMenuItem *queryFavoritesSaveAsMenuItem;
	IBOutlet NSMenuItem *queryFavoritesSaveAllMenuItem;
	IBOutlet id queryFavoritesSearchFieldView;
	IBOutlet NSSearchField *queryFavoritesSearchField;

	IBOutlet NSWindow *queryFavoritesSheet;
	IBOutlet NSButton *saveQueryFavoriteButton;
	IBOutlet NSTextField *queryFavoriteNameTextField;
	IBOutlet NSButton *saveQueryFavoriteGlobal;

	IBOutlet id queryHistoryButton;
	IBOutlet NSMenuItem *queryHistorySearchMenuItem;
	IBOutlet id queryHistorySearchFieldView;
	IBOutlet NSSearchField *queryHistorySearchField;
	IBOutlet NSMenuItem *clearHistoryMenuItem;
	IBOutlet NSMenuItem *saveHistoryMenuItem;
	IBOutlet NSMenuItem *copyHistoryMenuItem;
	IBOutlet NSPopUpButton *encodingPopUp;
#endif

	IBOutlet SPTextView *textView;
	IBOutlet SPCopyTable *customQueryView;
	IBOutlet NSScrollView *customQueryScrollView;
	IBOutlet id errorText;
	IBOutlet NSTextField *errorTextTitle;
	IBOutlet NSScrollView *errorTextScrollView;
	IBOutlet id affectedRowsText;
	IBOutlet id valueSheet;
	IBOutlet id valueTextField;

	// Hooks for old layouts using just the Run All button
	IBOutlet id runAllButton;

	// Hooks for layouts using the new single button with interchangeable actions
	IBOutlet id runPrimaryActionButton;
	IBOutlet id runPrimaryActionButtonAsSelection;
	IBOutlet NSMenuItem *runPrimaryActionMenuItem;
	IBOutlet NSMenuItem *runSecondaryActionMenuItem;

	IBOutlet NSMenuItem *shiftLeftMenuItem;
	IBOutlet NSMenuItem *shiftRightMenuItem;
	IBOutlet NSMenuItem *completionListMenuItem;
	IBOutlet NSMenuItem *editorFontMenuItem;
	IBOutlet NSMenuItem *autoindentMenuItem;
	IBOutlet NSMenuItem *autopairMenuItem;
	IBOutlet NSMenuItem *autohelpMenuItem;
	IBOutlet NSMenuItem *autouppercaseKeywordsMenuItem;
	IBOutlet NSMenuItem *commentCurrentQueryMenuItem;
	IBOutlet NSMenuItem *commentLineOrSelectionMenuItem;
	
#ifndef SP_CODA
	IBOutlet NSMenuItem *previousHistoryMenuItem;
	IBOutlet NSMenuItem *nextHistoryMenuItem;
	IBOutlet NSWindow *helpWebViewWindow;
	IBOutlet WebView *helpWebView;
	IBOutlet NSSearchField *helpSearchField;
	IBOutlet NSSearchFieldCell *helpSearchFieldCell;
	IBOutlet NSSegmentedControl *helpNavigator;
	IBOutlet NSSegmentedControl *helpTargetSelector;
#endif

	IBOutlet NSButton *queryInfoButton;
	IBOutlet SPSplitView *queryInfoPaneSplitView;
	IBOutlet SPSplitView *queryEditorSplitView;

	SPFieldEditorController *fieldEditor;
	SPQueryFavoriteManager *favoritesManager;

	NSUserDefaults *prefs;
	SPMySQLConnection *mySQLConnection;

	NSString *usedQuery;
	NSRange currentQueryRange;
	NSArray *currentQueryRanges;
	BOOL currentQueryBeforeCaret;

	NSString *mySQLversion;
	NSTableColumn *sortColumn;

	NSUInteger queryStartPosition;

#ifndef SP_CODA
	NSUInteger helpTarget;
	WebHistory *helpHistory;
	NSString *helpHTMLTemplate;
#endif

	SPDataStorage *resultData;
	pthread_mutex_t resultDataLock;
	NSArray *cqColumnDefinition;
	NSString *lastExecutedQuery;
	NSInteger editedRow;
	NSRect editedScrollViewRect;

	BOOL isWorking;
	BOOL tableRowsSelectable;
	BOOL reloadingExistingResult;
	BOOL queryIsTableSorter;
	BOOL isDesc;
	BOOL isFieldEditable;
	BOOL textViewWasChanged;
	NSNumber *sortField;

	NSIndexSet *selectionIndexToRestore;
	NSRect selectionViewportToRestore;

	NSString *fieldIDQueryString;

	NSUInteger numberOfQueries;
	NSUInteger queryInfoPanePaddingHeight;

	NSInteger currentHistoryOffsetIndex;
	BOOL historyItemWasJustInserted;

	NSTimer *queryLoadTimer;
	NSInteger runAllContinueStopSheetReturnCode;
	NSUInteger queryLoadInterfaceUpdateInterval, queryLoadTimerTicksSinceLastUpdate, queryLoadLastRowCount;

	NSString *kCellEditorErrorNoMatch;
	NSString *kCellEditorErrorNoMultiTabDb;
	NSString *kCellEditorErrorTooManyMatches;
}

#ifdef SP_CODA
@property (assign) SPDatabaseDocument* tableDocumentInstance;
@property (assign) SPTablesList* tablesListInstance;
@property (assign) SPTextView *textView;
@property (assign) SPCopyTable *customQueryView;
@property (assign) id affectedRowsText;
#endif

@property (assign) NSButton* runAllButton;
@property (assign) BOOL textViewWasChanged;

// IBAction methods
- (IBAction)runPrimaryQueryAction:(id)sender;
- (IBAction)runSecondaryQueryAction:(id)sender;
- (IBAction)switchDefaultQueryAction:(id)sender;
- (IBAction)runAllQueries:(id)sender;
- (IBAction)runSelectedQueries:(id)sender;
- (IBAction)chooseQueryFavorite:(id)sender;
- (IBAction)chooseQueryHistory:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)gearMenuItemSelected:(id)sender;
#ifndef SP_CODA
- (IBAction)showHelpForCurrentWord:(id)sender;
- (IBAction)showHelpForSearchString:(id)sender;
- (IBAction)helpSegmentDispatcher:(id)sender;
- (IBAction)helpTargetDispatcher:(id)sender;
- (IBAction)helpSearchFindNextInPage:(id)sender;
- (IBAction)helpSearchFindPreviousInPage:(id)sender;
- (IBAction)helpSelectHelpTargetMySQL:(id)sender;
- (IBAction)helpSelectHelpTargetPage:(id)sender;
- (IBAction)helpSelectHelpTargetWeb:(id)sender;
#endif
- (IBAction)filterQueryFavorites:(id)sender;
- (IBAction)filterQueryHistory:(id)sender;
- (IBAction)saveQueryHistory:(id)sender;
- (IBAction)copyQueryHistory:(id)sender;
- (IBAction)clearQueryHistory:(id)sender;
- (IBAction)showCompletionList:(id)sender;

// Query actions
- (void)performQueries:(NSArray *)queries withCallback:(SEL)customQueryCallbackMethod;
- (void)performQueriesTask:(NSDictionary *)taskArguments;
- (NSString *)queryAtPosition:(NSUInteger)position lookBehind:(BOOL *)doLookBehind;
- (NSRange)queryRangeAtPosition:(NSUInteger)position lookBehind:(BOOL *)doLookBehind;
- (NSRange)queryTextRangeForQuery:(NSInteger)anIndex startPosition:(NSUInteger)position;
- (void) updateStatusInterfaceWithDetails:(NSDictionary *)errorDetails;

// Interface setup
- (void)updateQueryInteractionInterface;
- (void)updateContextualRunInterface;

// Query load actions
- (void)initQueryLoadTimer;
- (void)clearQueryLoadTimer;
- (void)queryLoadUpdate:(NSTimer *)theTimer;

// Accessors
- (NSArray *)currentResult;
- (NSArray *)currentDataResultWithNULLs:(BOOL)includeNULLs truncateDataFields:(BOOL)truncate;
- (NSUInteger)currentResultRowCount;
- (void)updateResultStore:(SPMySQLStreamingResultStore *)theResultStore;

// Retrieving and setting table state
- (void)updateTableView;
- (NSIndexSet *)resultSelectedRowIndexes;
- (NSRect)resultViewport;
- (NSArray *)dataColumnDefinitions;
- (void)setResultSelectedRowIndexesToRestore:(NSIndexSet *)theIndexSet;
- (void)setResultViewportToRestore:(NSRect)theViewport;
- (void)storeCurrentResultViewForRestoration;
- (void)clearResultViewDetailsToRestore;
- (void)autosizeColumns;

#ifndef SP_CODA
// MySQL Help
- (void)showAutoHelpForCurrentWord:(id)sender;
- (NSString *)getHTMLformattedMySQLHelpFor:(NSString *)searchString calledByAutoHelp:(BOOL)autoHelp;
- (void)showHelpFor:(NSString *)aString addToHistory:(BOOL)addToHistory calledByAutoHelp:(BOOL)autoHelp;
- (void)helpTargetValidation;
- (void)openMySQLonlineDocumentationWithString:(NSString *)searchString;
- (NSWindow *)helpWebViewWindow;
#endif
- (void)setMySQLversion:(NSString *)theVersion;

// Task interaction
- (void)startDocumentTaskForTab:(NSNotification *)aNotification;
- (void)endDocumentTaskForTab:(NSNotification *)aNotification;

// Tableview interaction
- (void)tableSortCallback;

// Other
- (void)setConnection:(SPMySQLConnection *)theConnection;
- (void)doPerformQueryService:(NSString *)query;
- (void)doPerformLoadQueryService:(NSString *)query;
- (void)selectCurrentQuery;
- (void)commentOut;
- (void)commentOutCurrentQueryTakingSelection:(BOOL)takeSelection;
- (NSString *)usedQuery;
- (NSString *)argumentForRow:(NSUInteger)rowIndex ofTable:(NSString *)tableForColumn andDatabase:(NSString *)database includeBlobs:(BOOL)includeBlobs;
- (void)saveCellValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSUInteger)rowIndex;
- (NSArray*)fieldEditStatusForRow:(NSInteger)rowIndex andColumn:(NSInteger)columnIndex;
- (NSUInteger)numberOfQueries;
- (NSRange)currentQueryRange;
- (NSString *)buildHistoryString;
- (void)addHistoryEntry:(NSString *)entryString;
- (void)historyItemsHaveBeenUpdated:(id)manager;
- (void)processFieldEditorResult:(id)data contextInfo:(NSDictionary*)contextInfo;

@end
