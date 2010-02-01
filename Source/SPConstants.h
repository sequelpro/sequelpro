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

// View modes
enum {
	SPStructureViewMode	  = 1,
	SPContentViewMode	  = 2,
	SPRelationsViewMode	  = 3,
	SPTableInfoViewMode	  = 4,
	SPQueryEditorViewMode = 5
};
typedef NSUInteger SPViewMode;

// Query modes
enum {
	SPInterfaceQueryMode    = 0,
	SPCustomQueryQueryMode  = 1,
	SPImportExportQueryMode = 2
};
typedef NSUInteger SPQueryMode;

// Connection types
enum {
	SPTCPIPConnection     = 0,
	SPSocketConnection    = 1,
	SPSSHTunnelConnection = 2
}; 
typedef NSUInteger SPConnectionType;

// Export type constants
enum {
	SP_SQL_EXPORT   = 1,
	SP_CSV_EXPORT   = 2,
	SP_XML_EXPORT   = 3,
	SP_PDF_EXPORT   = 4,
	SP_HTML_EXPORT  = 5,
	SP_EXCEL_EXPORT = 6
};
typedef NSUInteger SPExportType;

// Export source constants
enum {
	SP_FILTERED_EXPORT     = 1,
	SP_CUSTOM_QUERY_EXPORT = 2,
	SP_TABLE_EXPORT        = 3
};
typedef NSUInteger SPExportSource;

// Table row count query usage levels
typedef enum {
	SPRowCountFetchNever	= 0,
	SPRowCountFetchIfCheap	= 1,
	SPRowCountFetchAlways	= 2
} SPRowCountQueryUsageLevels;

// Kill mode constants
extern NSString *SPKillProcessQueryMode;
extern NSString *SPKillProcessConnectionMode;

// Default monospaced font name
extern NSString *SPDefaultMonospacedFontName;

// Table view drag types
extern NSString *SPFavoritesPasteboardDragType;
extern NSString *SPContentFilterPasteboardDragType;
extern NSString *SPQueryFavortiesPasteboardDragType;

// File extensions
extern NSString *SPFileExtensionDefault;
extern NSString *SPFileExtensionSQL;


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
extern NSString *SPTableRowCountQueryLevel;
extern NSString *SPTableRowCountCheapSizeBoundary;
extern NSString *SPNewFieldsAllowNulls;
extern NSString *SPLimitResults;
extern NSString *SPLimitResultsValue;
extern NSString *SPNullValue;
extern NSString *SPGlobalResultTableFont;

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
extern NSString *SPConsoleShowConnections;
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
extern NSString *SPTableChangedNotification;
extern NSString *SPBlobTextEditorSpellCheckingEnabled;

// URLs
extern NSString *SPHomePageURL;
extern NSString *SPDonationsURL;
extern NSString *SPFAQURL;
extern NSString *SPDocumentationURL;
extern NSString *SPContactURL;

// Toolbar constants

// Main window toolbar
extern NSString *SPMainToolbarDatabaseSelection;
extern NSString *SPMainToolbarHistoryNavigation;
extern NSString *SPMainToolbarShowConsole;
extern NSString *SPMainToolbarClearConsole;
extern NSString *SPMainToolbarTableStructure;
extern NSString *SPMainToolbarTableContent;
extern NSString *SPMainToolbarCustomQuery;
extern NSString *SPMainToolbarTableInfo;
extern NSString *SPMainToolbarTableRelations;
extern NSString *SPMainToolbarTableTriggers;
extern NSString *SPMainToolbarUserManager;

// Preferences toolbar
extern NSString *SPPreferenceToolbarGeneral;
extern NSString *SPPreferenceToolbarTables;
extern NSString *SPPreferenceToolbarFavorites;
extern NSString *SPPreferenceToolbarNotifications;
extern NSString *SPPreferenceToolbarAutoUpdate;
extern NSString *SPPreferenceToolbarNetwork;
extern NSString *SPPreferenceToolbarEditor;
extern NSString *SPPreferenceToolbarShortcuts;
