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
#import <WebKit/WebKit.h>
#import <MCPKit_bundled/MCPKit_bundled.h>
#import "CMCopyTable.h"
#import "CMTextView.h"
#import "CMMCPConnection.h"
#import "CMMCPResult.h"
#import "RegexKitLite.h"

#define SP_HELP_TOC_SEARCH_STRING @"contents"

@interface CustomQuery : NSObject {

	IBOutlet id tableWindow;
	IBOutlet id queryFavoritesButton;
	IBOutlet id queryHistoryButton;
	IBOutlet CMTextView *textView;
	IBOutlet CMCopyTable *customQueryView;
	IBOutlet id errorText;
	IBOutlet id affectedRowsText;
	IBOutlet id valueSheet;
	IBOutlet id valueTextField;
	IBOutlet id queryFavoritesSheet;
	IBOutlet id queryFavoritesView;
	IBOutlet id removeQueryFavoriteButton;
	IBOutlet id copyQueryFavoriteButton;
	IBOutlet id runSelectionButton;
	IBOutlet id runAllButton;

	IBOutlet NSMenuItem *runSelectionMenuItem;
	IBOutlet NSMenuItem *clearHistoryMenuItem;
	IBOutlet NSMenuItem *shiftLeftMenuItem;
	IBOutlet NSMenuItem *shiftRightMenuItem;
	IBOutlet NSMenuItem *completionListMenuItem;
	IBOutlet NSMenuItem *editorFontMenuItem;
	IBOutlet NSMenuItem *autoindentMenuItem;
	IBOutlet NSMenuItem *autopairMenuItem;
	IBOutlet NSMenuItem *autohelpMenuItem;
	IBOutlet NSMenuItem *autouppercaseKeywordsMenuItem;

	IBOutlet NSWindow *helpWebViewWindow;
	IBOutlet WebView *helpWebView;
	IBOutlet NSSearchField *helpSearchField;
	IBOutlet NSSearchFieldCell *helpSearchFieldCell;
	IBOutlet NSSegmentedControl *helpNavigator;
	IBOutlet NSSegmentedControl *helpTargetSelector;


	NSArray *queryResult;
	NSUserDefaults *prefs;
	NSMutableArray *queryFavorites;
	
	CMMCPConnection *mySQLConnection;
	
	NSString *usedQuery;
	NSRange currentQueryRange;
	NSArray *currentQueryRanges;
	BOOL hasBackgroundAttribute;
	NSString *mySQLversion;
		
	int queryStartPosition;
	
	int helpTarget;
	WebHistory *helpHistory;
	NSString *helpHTMLTemplate;
	
	NSMutableArray *fullResult;
	NSArray *cqColumnDefinition;
	NSString *lastExecutedQuery;
	
	BOOL tempAlertWasShown; // a temp value for nightly builts
		
}

// IBAction methods
- (IBAction)runAllQueries:(id)sender;
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


// queryFavoritesSheet methods
- (IBAction)addQueryFavorite:(id)sender;
- (IBAction)removeQueryFavorite:(id)sender;
- (IBAction)copyQueryFavorite:(id)sender;
- (IBAction)closeQueryFavoritesSheet:(id)sender;

// Query actions
- (void)performQueries:(NSArray *)queries;
- (NSString *)queryAtPosition:(long)position lookBehind:(BOOL *)doLookBehind;
- (NSRange)queryRangeAtPosition:(long)position lookBehind:(BOOL *)doLookBehind;
- (NSRange)queryTextRangeForQuery:(int)anIndex startPosition:(long)position;

// Accessors
- (NSArray *)currentResult;
- (NSArray *)fetchResultAsArray:(CMMCPResult *)theResult;

// MySQL Help
- (NSString *)getHTMLformattedMySQLHelpFor:(NSString *)aString;
- (void)showHelpFor:(NSString *)aString addToHistory:(BOOL)addToHistory;
- (void)helpTargetValidation;
- (void)openMySQLonlineDocumentationWithString:(NSString *)searchString;
- (NSWindow *)helpWebViewWindow;
- (void)setMySQLversion:(NSString *)theVersion;


// Other
- (void)setConnection:(CMMCPConnection *)theConnection;
- (void)setFavorites;
- (void)doPerformQueryService:(NSString *)query;
- (void)selectCurrentQuery;
- (NSString *)usedQuery;
- (NSString *)argumentForRow:(NSUInteger)rowIndex ofTable:(NSString *)tableForColumn;


@end
