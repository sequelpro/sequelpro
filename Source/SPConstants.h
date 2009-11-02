//
//  $Id$
//
//  SPConstants.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 16, 2009
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

// TODO: change #defines
// see http://developer.apple.com/mac/library/documentation/Cocoa/Conceptual/CodingGuidelines/Articles/NamingIvarsAndTypes.html#//apple_ref/doc/uid/20001284-1003095

#import <Cocoa/Cocoa.h>

// Extensions
#define DEFAULT_SEQUEL_PRO_FILE_EXTENSION     @"spf"
#define DEFAULT_QUERY_FAVORITE_FILE_EXTENSION @"sql"
#define DEFAULT_CONSOLE_LOG_FILE_EXTENSION    @"sql"

// Tableview drag types
#define FAVORITES_PB_DRAG_TYPE       @"SequelProPreferencesPasteboard"
#define CONTENT_FILTER_PB_DRAG_TYPE  @"SequelProContentFilterPasteboard"
#define QUERY_FAVORITES_PB_DRAG_TYPE @"SequelProQueryFavoritesPasteboard"

// URLs
#define SEQUEL_PRO_HOME_PAGE_URL @"http://www.sequelpro.com/"
#define SEQUEL_PRO_DONATIONS_URL @"http://www.sequelpro.com/donate.html"
#define SEQUEL_PRO_FAQ_URL       @"http://www.sequelpro.com/frequently-asked-questions.html"
#define SEQUEL_PRO_DOCS_URL      @"http://www.sequelpro.com/docs"
#define SEQUEL_PRO_CONTACT_URL   @"http://www.sequelpro.com/docs/Contact_the_developers"

// Main toolbar constants
#define MAIN_TOOLBAR_DATABASE_SELECTION @"DatabaseSelectToolbarItemIdentifier"
#define MAIN_TOOLBAR_HISTORY_NAVIGATION @"HistoryNavigationToolbarItemIdentifier"
#define MAIN_TOOLBAR_SHOW_CONSOLE       @"ShowConsoleIdentifier"
#define MAIN_TOOLBAR_CLEAR_CONSOLE      @"ClearConsoleIdentifier"
#define MAIN_TOOLBAR_FLUSH_PRIVILEGES   @"FlushPrivilegesIdentifier"
#define MAIN_TOOLBAR_TABLE_STRUCTURE    @"SwitchToTableStructureToolbarItemIdentifier"
#define MAIN_TOOLBAR_TABLE_CONTENT      @"SwitchToTableContentToolbarItemIdentifier"
#define MAIN_TOOLBAR_CUSTOM_QUERY       @"SwitchToRunQueryToolbarItemIdentifier"
#define MAIN_TOOLBAR_TABLE_INFO         @"SwitchToTableInfoToolbarItemIdentifier"
#define MAIN_TOOLBAR_TABLE_RELATIONS    @"SwitchToTableRelationsToolbarItemIdentifier"
#define MAIN_TOOLBAR_USER_MANAGER       @"SwitchToUserManagerToolbarItemIdentifier"

// View Modes
typedef enum {
	SPStructureViewMode		= 1,
	SPContentViewMode		= 2,
	SPRelationsViewMode		= 3,
	SPTableInfoViewMode		= 4,
	SPQueryEditorViewMode	= 5
} SPViewMode;

// Preference key constants
// General Prefpane
extern NSString *SPDefaultFavorite;
extern NSString *SPSelectLastFavoriteUsed;
extern NSString *SPLastFavoriteIndex;
extern NSString *SPAutoConnectToDefault;
extern NSString *SPDefaultViewMode;
extern NSString *SPLastViewMode;
extern NSString *SPDefaultEncoding;
extern NSString *SPUseMonospacedFonts;
extern NSString *SPDisplayTableViewVerticalGridlines;
extern NSString *SPCustomQueryMaxHistoryItems;

// Tables Prefpane
extern NSString *SPReloadAfterAddingRow;
extern NSString *SPReloadAfterEditingRow;
extern NSString *SPReloadAfterRemovingRow;
extern NSString *SPLoadBlobsAsNeeded;
extern NSString *SPFetchCorrectRowCount;
extern NSString *SPNewFieldsAllowNulls;
extern NSString *SPLimitResults;
extern NSString *SPLimitResultsValue;
extern NSString *SPNullValue;

// Favorites Prefpane
extern NSString *SPFavorites;

// Notifications Prefpane
extern NSString *SPGrowlEnabled;
extern NSString *SPShowNoAffectedRowsError;
extern NSString *SPConsoleEnableLogging;
extern NSString *SPConsoleEnableInterfaceLogging;
extern NSString *SPConsoleEnableCustomQueryLogging;
extern NSString *SPConsoleEnableImportExportLogging;
extern NSString *SPConsoleEnableErrorLogging;

// Network Prefpane
extern NSString *SPConnectionTimeoutValue;
extern NSString *SPUseKeepAlive;
extern NSString *SPKeepAliveInterval;

// Editor Prefpane
extern NSString *SPCustomQueryEditorFont;
extern NSString *SPCustomQueryEditorTextColor;
extern NSString *SPCustomQueryEditorBackgroundColor;
extern NSString *SPCustomQueryEditorCaretColor;
extern NSString *SPCustomQueryEditorCommentColor;
extern NSString *SPCustomQueryEditorSQLKeywordColor;
extern NSString *SPCustomQueryEditorNumericColor;
extern NSString *SPCustomQueryEditorQuoteColor;
extern NSString *SPCustomQueryEditorBacktickColor;
extern NSString *SPCustomQueryEditorVariableColor;
extern NSString *SPCustomQueryEditorHighlightQueryColor;
extern NSString *SPCustomQueryAutoIndent;
extern NSString *SPCustomQueryAutoPairCharacters;
extern NSString *SPCustomQueryAutoUppercaseKeywords;
extern NSString *SPCustomQueryUpdateAutoHelp;
extern NSString *SPCustomQueryAutoHelpDelay;
extern NSString *SPCustomQueryHighlightCurrentQuery;

// AutoUpdate Prefpane
extern NSString *SPLastUsedVersion;

// GUI Prefs
extern NSString *SPConsoleShowTimestamps;
extern NSString *SPConsoleShowSelectsAndShows;
extern NSString *SPConsoleShowHelps;
extern NSString *SPEditInSheetEnabled;
extern NSString *SPTableInformationPanelCollapsed;
extern NSString *SPTableColumnWidths;

// Import
extern NSString *SPCSVImportFieldTerminator;
extern NSString *SPCSVImportLineTerminator;
extern NSString *SPCSVImportFieldEnclosedBy;
extern NSString *SPCSVImportFieldEscapeCharacter;
extern NSString *SPCSVImportFirstLineIsHeader;

// Misc
extern NSString *SPContentFilters;
extern NSString *SPDocumentTaskEndNotification;
extern NSString *SPDocumentTaskStartNotification;
extern NSString *SPFieldEditorSheetFont;
extern NSString *SPLastSQLFileEncoding;
extern NSString *SPNoBOMforSQLdumpFile;
extern NSString *SPPrintBackground;
extern NSString *SPPrintImagePreviews;
extern NSString *SPQueryFavorites;
extern NSString *SPQueryFavoriteReplacesContent;
extern NSString *SPQueryHistory;
extern NSString *SPQueryHistoryReplacesContent;
extern NSString *SPQuickLookTypes;
