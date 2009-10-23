//
//  $Id$
//
//  CustomQuery.h
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
#import <WebKit/WebKit.h>

#import "CMCopyTable.h"
#import "CMTextView.h"
#import "RegexKitLite.h"

#define SP_HELP_TOC_SEARCH_STRING @"contents"
#define SP_HELP_SEARCH_IN_MYSQL   0
#define SP_HELP_SEARCH_IN_PAGE    1
#define SP_HELP_SEARCH_IN_WEB     2
#define SP_HELP_GOBACK_BUTTON     0
#define SP_HELP_SHOW_TOC_BUTTON   1
#define SP_HELP_GOFORWARD_BUTTON  2
#define SP_HELP_NOT_AVAILABLE     @"__no_help_available"

#define SP_MYSQL_DEV_SEARCH_URL   @"http://search.mysql.com/search?q=%@&site=refman-%@"

#define SP_SAVE_ALL_FAVORTITE_MENUITEM_TAG            100001
#define SP_SAVE_SELECTION_FAVORTITE_MENUITEM_TAG      100000
#define SP_FAVORITE_HEADER_MENUITEM_TAG               200000


@class SPQueryFavoriteManager;

@interface CustomQuery : NSObject 
{
	IBOutlet id tableDocumentInstance;
	IBOutlet id tableWindow;

	IBOutlet id queryFavoritesButton;
	IBOutlet NSMenuItem *queryFavoritesSearchMenuItem;
	IBOutlet NSMenuItem *queryFavoritesSaveAsMenuItem;
	IBOutlet NSMenuItem *queryFavoritesSaveAllMenuItem;
	IBOutlet id queryFavoritesSearchFieldView;
	IBOutlet NSSearchField *queryFavoritesSearchField;

	IBOutlet NSWindow *queryFavoritesSheet;
	IBOutlet NSButton *saveQueryFavoriteButton;
	IBOutlet NSTextField *queryFavoriteNameTextField;
	IBOutlet id saveQueryFavoriteGlobal;

	IBOutlet id queryHistoryButton;
	IBOutlet NSMenuItem *queryHistorySearchMenuItem;
	IBOutlet id queryHistorySearchFieldView;
	IBOutlet NSSearchField *queryHistorySearchField;

	IBOutlet CMTextView *textView;
	IBOutlet CMCopyTable *customQueryView;
	IBOutlet id errorText;
	IBOutlet id affectedRowsText;
	IBOutlet id valueSheet;
	IBOutlet id valueTextField;
	IBOutlet id runSelectionButton;
	IBOutlet id runAllButton;
	IBOutlet id multipleLineEditingButton;

	IBOutlet NSMenuItem *runSelectionMenuItem;
	IBOutlet NSMenuItem *runAllMenuItem;
	IBOutlet NSMenuItem *clearHistoryMenuItem;
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

	IBOutlet NSWindow *helpWebViewWindow;
	IBOutlet WebView *helpWebView;
	IBOutlet NSSearchField *helpSearchField;
	IBOutlet NSSearchFieldCell *helpSearchFieldCell;
	IBOutlet NSSegmentedControl *helpNavigator;
	IBOutlet NSSegmentedControl *helpTargetSelector;

	SPQueryFavoriteManager *favoritesManager;

	NSUserDefaults *prefs;
	MCPConnection *mySQLConnection;

	NSString *usedQuery;
	NSRange currentQueryRange;
	NSArray *currentQueryRanges;
	NSRange oldThreadedQueryRange;
	BOOL hasBackgroundAttribute;
	BOOL selectionButtonCanBeEnabled;
	NSString *mySQLversion;
	NSTableColumn *sortColumn;

	int queryStartPosition;

	int helpTarget;
	WebHistory *helpHistory;
	NSString *helpHTMLTemplate;

	NSMutableArray *fullResult;
	NSInteger fullResultCount;
	NSArray *cqColumnDefinition;
	NSString *lastExecutedQuery;

	BOOL tableReloadAfterEditing;
	BOOL queryIsTableSorter;
	BOOL isDesc;
	NSNumber *sortField;

	NSString *fieldIDQueryString;

	unsigned int numberOfQueries;
	
}

// IBAction methods
- (IBAction)runAllQueries:(id)sender;
- (void) runAllQueriesCallback;
- (IBAction)runSelectedQueries:(id)sender;
- (IBAction)chooseQueryFavorite:(id)sender;
- (IBAction)chooseQueryHistory:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)gearMenuItemSelected:(id)sender;
- (IBAction)showHelpForCurrentWord:(id)sender;
- (IBAction)showHelpForSearchString:(id)sender;
- (IBAction)helpSegmentDispatcher:(id)sender;
- (IBAction)helpTargetDispatcher:(id)sender;
- (IBAction)helpSearchFindNextInPage:(id)sender;
- (IBAction)helpSearchFindPreviousInPage:(id)sender;
- (IBAction)helpSelectHelpTargetMySQL:(id)sender;
- (IBAction)helpSelectHelpTargetPage:(id)sender;
- (IBAction)helpSelectHelpTargetWeb:(id)sender;
- (IBAction)filterQueryFavorites:(id)sender;
- (IBAction)filterQueryHistory:(id)sender;

// Query actions
- (void)performQueries:(NSArray *)queries withCallback:(SEL)customQueryCallbackMethod;
- (void)performQueriesTask:(NSDictionary *)taskArguments;
- (NSString *)queryAtPosition:(long)position lookBehind:(BOOL *)doLookBehind;
- (NSRange)queryRangeAtPosition:(long)position lookBehind:(BOOL *)doLookBehind;
- (NSRange)queryTextRangeForQuery:(int)anIndex startPosition:(long)position;

// Accessors
- (NSArray *)currentResult;
- (void)processResultIntoDataStorage:(MCPStreamingResult *)theResult;

// MySQL Help
- (NSString *)getHTMLformattedMySQLHelpFor:(NSString *)aString;
- (void)showHelpFor:(NSString *)aString addToHistory:(BOOL)addToHistory;
- (void)helpTargetValidation;
- (void)openMySQLonlineDocumentationWithString:(NSString *)searchString;
- (NSWindow *)helpWebViewWindow;
- (void)setMySQLversion:(NSString *)theVersion;

// Task interaction
- (void) startDocumentTaskForTab:(NSNotification *)aNotification;
- (void) endDocumentTaskForTab:(NSNotification *)aNotification;

// Other
- (void)setConnection:(MCPConnection *)theConnection;
- (void)doPerformQueryService:(NSString *)query;
- (void)doPerformLoadQueryService:(NSString *)query;
- (void)selectCurrentQuery;
- (void)commentOut;
- (void)commentOutCurrentQueryTakingSelection:(BOOL)takeSelection;
- (NSString *)usedQuery;
- (NSString *)argumentForRow:(NSUInteger)rowIndex ofTable:(NSString *)tableForColumn andDatabase:(NSString *)database;
- (unsigned int)numberOfQueries;

@end
