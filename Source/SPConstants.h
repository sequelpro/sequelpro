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

#import <Foundation/Foundation.h>

// View modes
typedef enum {
	SPStructureViewMode	  = 1,
	SPContentViewMode	  = 2,
	SPRelationsViewMode	  = 3,
	SPTableInfoViewMode   = 4,
	SPQueryEditorViewMode = 5,
	SPTriggersViewMode    = 6
} SPViewMode;

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
	SPSQLExport   = 0,
	SPCSVExport   = 1,
	SPXMLExport   = 2,
	SPDotExport   = 3,
	SPPDFExport   = 4,
	SPHTMLExport  = 5,
	SPExcelExport = 6
};
typedef NSUInteger SPExportType;

// Export source constants
enum {
	SPFilteredExport = 0,
	SPQueryExport    = 1,
	SPTableExport    = 2
};
typedef NSUInteger SPExportSource;

// SQL export INSERT statment divider constants
enum {
	SPSQLInsertEveryNDataBytes = 0,
	SPSQLInsertEveryNRows      = 1
};
typedef NSUInteger SPSQLExportInsertDivider;

// Table row count query usage levels
typedef enum {
	SPRowCountFetchNever   = 0,
	SPRowCountFetchIfCheap = 1,
	SPRowCountFetchAlways  = 2
} SPRowCountQueryUsageLevels;

// Export type
typedef enum {
	SPExportingSQL = 0,
	SPExportingCSV = 1,
	SPExportingXML = 2,
	SPExportingDOT = 3
} SPExportMode;

// Database object (table list) types
typedef enum
{
	SPTableTypeNone  = -1,
	SPTableTypeTable = 0,
	SPTableTypeView  = 1,
	SPTableTypeProc  = 2,
	SPTableTypeFunc  = 3
} SPTableType;

// History views
typedef enum
{
	SPTableViewStructure   = 0,
	SPTableViewContent     = 1,
	SPTableViewCustomQuery = 2,
	SPTableViewStatus      = 3,
	SPTableViewRelations   = 4,
	SPTableViewTriggers    = 5
} SPTableViewType;

// SSH tunnel password modes
typedef enum
{
	SPSSHPasswordUsesKeychain = 0,
	SPSSHPasswordAsksUI       = 1,
	SPSSHPasswordNone         = 2
} SPSSHTunnelPasswordMode;

// Sort by constants
typedef enum
{
	SPFavoritesSortNameItem = 0,
	SPFavoritesSortHostItem = 1,
	SPFavoritesSortTypeItem = 2
} SPFavoritesSortItem;

// Text and link cell draw states
typedef enum
{
	SPLinkDrawStateNormal              = 0,
	SPLinkDrawStateHighlight           = 1,
	SPLinkDrawStateBackgroundHighlight = 2
} SPTextAndLinkCellDrawState;

// Menu tag constants
typedef enum
{
	SPMainMenuSequelPro = 0,
	SPMainMenuFile      = 1,
	SPMainMenuEdit      = 2,
	SPMainMenuView      = 3,
	SPMainMenuDatabase  = 4,
	SPMainMenuTable     = 5,
	SPMainMenuWindow    = 6,
	SPMainMenuHelp      = 7
} SPMainMenuTags;

// Encoding constants
typedef enum
{
	SPEncodingAutodetect		= 0,
	SPEncodingUCS2				= 10,
	SPEncodingUTF8				= 20,
	SPEncodingUTF8viaLatin1		= 30,
	SPEncodingASCII				= 40,
	SPEncodingLatin1			= 50,
	SPEncodingMacRoman			= 60,
	SPEncodingCP1250Latin2		= 70,
	SPEncodingISOLatin2			= 80,
	SPEncodingCP1256Arabic		= 90,
	SPEncodingGreek				= 100,
	SPEncodingHebrew			= 110,
	SPEncodingLatin5Turkish		= 120,
	SPEncodingCP1257WinBaltic	= 130,
	SPEncodingCP1251WinCyrillic = 140,
	SPEncodingBig5Chinese		= 150,
	SPEncodingShiftJISJapanese	= 160,
	SPEncodingEUCJPJapanese		= 170,
	SPEncodingEUCKRKorean		= 180
} SPEncodingTypes;

// Long running notification time for Growl messages
extern const CGFloat SPLongRunningNotificationTime;

// Narrow down completion max rows
extern const NSUInteger SPNarrowDownCompletionMaxRows;

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

// Filenames
extern NSString *SPHTMLPrintTemplate;
extern NSString *SPHTMLTableInfoPrintTemplate;
extern NSString *SPHTMLHelpTemplate;


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
extern NSString *SPCustomQueryEditorTabStopWidth;
extern NSString *SPCustomQueryAutoComplete;
extern NSString *SPCustomQueryAutoCompleteDelay;
extern NSString *SPCustomQueryFunctionCompletionInsertsArguments;

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
extern NSString *SPProcessListShowProcessID;
extern NSString *SPProcessListEnableAutoRefresh;
extern NSString *SPProcessListAutoRrefreshInterval;
extern NSString *SPFavoritesSortedBy;
extern NSString *SPFavoritesSortedInReverse;

// Hidden Prefs
extern NSString *SPPrintWarningRowLimit;
extern NSString *SPDisplayServerVersionInWindowTitle;

// Import and export
extern NSString *SPCSVImportFieldTerminator;
extern NSString *SPCSVImportLineTerminator;
extern NSString *SPCSVImportFieldEnclosedBy;
extern NSString *SPCSVImportFieldEscapeCharacter;
extern NSString *SPCSVImportFirstLineIsHeader;
extern NSString *SPCSVFieldImportMappingAlignment;
extern NSString *SPImportClipboardTempFileNamePrefix;
extern NSString *SPSQLExportUseCompression;
extern NSString *SPNoBOMforSQLdumpFile;

// Misc
extern NSString *SPContentFilters;
extern NSString *SPDocumentTaskEndNotification;
extern NSString *SPDocumentTaskStartNotification;
extern NSString *SPFieldEditorSheetFont;
extern NSString *SPLastSQLFileEncoding;
extern NSString *SPPrintBackground;
extern NSString *SPPrintImagePreviews;
extern NSString *SPQueryFavorites;
extern NSString *SPQueryFavoriteReplacesContent;
extern NSString *SPQueryHistory;
extern NSString *SPQueryHistoryReplacesContent;
extern NSString *SPQuickLookTypes;
extern NSString *SPTableChangedNotification;
extern NSString *SPBlobTextEditorSpellCheckingEnabled;
extern NSString *SPUniqueSchemaDelimiter;

// URLs
extern NSString *SPHomePageURL;
extern NSString *SPDonationsURL;
extern NSString *SPFAQURL;
extern NSString *SPDocumentationURL;
extern NSString *SPContactURL;
extern NSString *SPKeyboardShortcutsURL;
extern NSString *SPMySQLSearchURL;
extern NSString *SPDevURL;
extern NSString *SPGettingConnectedDocURL;
extern NSString *SPTranslationFeedbackURL;

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
extern NSString **SPViewModeToMainToolbarMap[];

// Preferences toolbar
extern NSString *SPPreferenceToolbarGeneral;
extern NSString *SPPreferenceToolbarTables;
extern NSString *SPPreferenceToolbarFavorites;
extern NSString *SPPreferenceToolbarNotifications;
extern NSString *SPPreferenceToolbarAutoUpdate;
extern NSString *SPPreferenceToolbarNetwork;
extern NSString *SPPreferenceToolbarEditor;
extern NSString *SPPreferenceToolbarShortcuts;
