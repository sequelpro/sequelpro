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

// Preference key constants
extern NSString *SPDefaultEncoding;
extern NSString *SPUseMonospacedFonts;
extern NSString *SPDisplayTableViewVerticalGridlines;
extern NSString *SPReloadAfterAddingRow;
extern NSString *SPReloadAfterEditingRow;
extern NSString *SPReloadAfterRemovingRow;
extern NSString *SPLoadBlobsAsNeeded;
extern NSString *SPFetchCorrectRowCount;
extern NSString *SPNewFieldsAllowNulls;
extern NSString *SPLimitResults;
extern NSString *SPLimitResultsValue;
extern NSString *SPNullValue;
extern NSString *SPShowNoAffectedRowsError;
extern NSString *SPGrowlEnabled;
extern NSString *SPConnectionTimeoutValue;
extern NSString *SPUseKeepAlive;
extern NSString *SPKeepAliveInterval;
extern NSString *SPEditInSheetEnabled;
extern NSString *SPAutoConnectToDefault;
extern NSString *SPQueryFavoriteReplacesContent;
extern NSString *SPQueryHistoryReplacesContent;
extern NSString *SPCustomQueryEditorFont;
extern NSString *SPCustomQueryEditorBackgroundColor;
extern NSString *SPCustomQueryEditorBacktickColor;
extern NSString *SPCustomQueryEditorCommentColor;
extern NSString *SPCustomQueryEditorNumericColor;
extern NSString *SPCustomQueryEditorQuoteColor;
extern NSString *SPCustomQueryEditorSQLKeywordColor;
extern NSString *SPCustomQueryEditorTextColor;
extern NSString *SPCustomQueryEditorHighlightQueryColor;
extern NSString *SPCustomQueryEditorCaretColor;
extern NSString *SPCustomQueryEditorVariableColor;
extern NSString *SPCustomQueryHighlightCurrentQuery;
extern NSString *SPCustomQueryAutoIndent;
extern NSString *SPCustomQueryAutoPairCharacters;
extern NSString *SPCustomQueryAutoUppercaseKeywords;
extern NSString *SPCustomQueryUpdateAutoHelp;
extern NSString *SPCustomQueryAutoHelpDelay;
extern NSString *SPCustomQueryMaxHistoryItems;
extern NSString *SPLastSQLFileEncoding;
extern NSString *SPSelectLastFavoriteUsed;
extern NSString *SPLastFavoriteIndex;
extern NSString *SPTableInformationPanelCollapsed;
extern NSString *SPConsoleEnableLogging;
extern NSString *SPConsoleEnableInterfaceLogging;
extern NSString *SPConsoleEnableCustomQueryLogging;
extern NSString *SPConsoleEnableImportExportLogging;
extern NSString *SPEnableErrorLogging;
extern NSString *SPConsoleShowTimestamps;
extern NSString *SPConsoleShowSelectsAndShows;
extern NSString *SPConsoleShowHelps;
extern NSString *SPPrintBackground;
extern NSString *SPPrintImagePreviews;
extern NSString *SPContentFilters;
extern NSString *SPCSVImportFieldTerminator;
extern NSString *SPCSVImportLineTerminator;
extern NSString *SPCSVImportFieldEnclosedBy;
extern NSString *SPCSVImportFieldEscapeCharacter;
extern NSString *SPCSVImportFirstLineIsHeader;
extern NSString *SPLastUsedVersion;
extern NSString *SPFieldEditorSheetFont;
extern NSString *SPQuickLookTypes;
extern NSString *SPQueryFavorites;
extern NSString *SPFavorites;
extern NSString *SPTableColumnWidths;
extern NSString *SPQueryHistory;
extern NSString *SPDocumentTaskStartNotification;
extern NSString *SPDocumentTaskEndNotification;
