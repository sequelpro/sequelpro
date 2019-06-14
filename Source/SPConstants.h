//
//  SPConstants.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 16, 2009.
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

/**
 * This header should be used to define constants that are used globally (i.e. among multiple classes/files).
 * Constants that need only be defined for a particular class should be done within the implementation file
 * of said class. Try to avoid the use of macros to define constants as much as possible as they do not incur
 * type checking when used and cannot be tested for equality.
 */

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
typedef NS_ENUM(NSUInteger, SPQueryMode) {
	SPInterfaceQueryMode    = 0,
	SPCustomQueryQueryMode  = 1,
	SPImportExportQueryMode = 2
};

// Connection types
typedef NS_ENUM(NSUInteger, SPConnectionType) {
	SPTCPIPConnection     = 0,
	SPSocketConnection    = 1,
	SPSSHTunnelConnection = 2
};

// Export type constants
typedef NS_ENUM(NSUInteger, SPExportType) {
	SPSQLExport   = 0,
	SPCSVExport   = 1,
	SPXMLExport   = 2,
	SPDotExport   = 3,
	SPPDFExport   = 4,
	SPHTMLExport  = 5,
	SPExcelExport = 6,
	SPAnyExportType = NSUIntegerMax, // this is a transient type to indicate "no specific choice"
};

// Export source constants
typedef NS_ENUM(NSUInteger, SPExportSource) {
	SPFilteredExport = 0,
	SPQueryExport    = 1,
	SPTableExport    = 2
};

// SQL export INSERT statment divider constants
typedef NS_ENUM(NSUInteger , SPSQLExportInsertDivider) {
	SPSQLInsertEveryNDataBytes = 0,
	SPSQLInsertEveryNRows      = 1
};

// XML export formats
typedef NS_ENUM(NSUInteger, SPXMLExportFormat) {
	SPXMLExportMySQLFormat = 0,
	SPXMLExportPlainFormat = 1
};

// Table row count query usage levels
typedef enum {
	SPRowCountFetchNever   = 0,
	SPRowCountFetchIfCheap = 1,
	SPRowCountFetchAlways  = 2
} SPRowCountQueryUsageLevels;

// Database object (table list) types
typedef enum
{
	SPTableTypeNone  = -1,
	SPTableTypeTable = 0,
	SPTableTypeView  = 1,
	SPTableTypeProc  = 2,
	SPTableTypeFunc  = 3,
	SPTableTypeEvent = 4
} SPTableType;

// Content views
typedef NS_ENUM(NSInteger, SPTableViewType)
{
	SPTableViewStructure   = 0,
	SPTableViewContent     = 1,
	SPTableViewCustomQuery = 2,
	SPTableViewStatus      = 3,
	SPTableViewRelations   = 4,
	SPTableViewTriggers    = 5,

	SPTableViewInvalid     = NSNotFound
};

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
	SPFavoritesSortUnsorted  = -1,
	SPFavoritesSortNameItem  =  0,
	SPFavoritesSortHostItem  =  1,
	SPFavoritesSortTypeItem  =  2,
	SPFavoritesSortColorItem =  3
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
	SPMainMenuFileSaveConnection   = 1004,
	SPMainMenuFileSaveConnectionAs = 1005,
	SPMainMenuFileSaveQuery        = 1006,
	SPMainMenuFileSaveQueryAs      = 1008,
	SPMainMenuFileSaveSession      = 1020,
	SPMainMenuFileSaveSessionAs    = 1021,
	SPMainMenuFileClose            = 1003,
	SPMainMenuFileCloseTab         = 1103,
	SPMainMenuEdit      = 2,
	SPMainMenuView      = 3,
	SPMainMenuDatabase  = 4,
	SPMainMenuTable     = 5,
	SPMainMenuBundles   = 6,
	SPMainMenuWindow    = 7,
	SPMainMenuHelp      = 8
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
	SPEncodingEUCKRKorean		= 180,
	SPEncodingUTF8MB4           = 190
} SPEncodingTypes;

// Table index type menu tags
typedef enum
{
	SPPrimaryKeyMenuTag	= 0,
	SPIndexMenuTag		= 1,
	SPUniqueMenuTag		= 2,
	SPFullTextMenuTag	= 3,
	SPSpatialMenuTag	= 4
} SPTableIndexTypeTags;

// File compression formats
typedef enum
{
	SPNoCompression    = 0,
	SPGzipCompression  = 1,
	SPBzip2Compression = 2
} SPFileCompressionFormat;

// Import SQL error handling tags/choices
typedef enum
{
	SPSQLImportAskOnError	= 0,
	SPSQLImportIgnoreErrors	= 1
} SPSQLImportErrorHandling;

// Export file handle creation 
typedef enum
{
	SPExportFileHandleInvalid = -1,
	SPExportFileHandleCreated = 0,
	SPExportFileHandleFailed  = 1,
	SPExportFileHandleExists  = 2
} SPExportFileHandleStatus;

typedef enum
{
	SPPrefFontChangeTargetTable  = 1,
	SPPrefFontChangeTargetEditor = 2
} SPPreferenceFontChangeTarget;

// Predefined localisable URLs
#define SPLOCALIZEDURL_HOMEPAGE            NSLocalizedString(@"https://www.sequelpro.com/", @"Localized home page - do not localize if no translated webpage is available")
#define SPLOCALIZEDURL_FAQ                 NSLocalizedString(@"https://www.sequelpro.com/docs/Frequently_Asked_Questions", @"Localized help page for Frequently Asked Questions - do not localize if no translated webpage is available")
#define SPLOCALIZEDURL_DOCUMENTATION       NSLocalizedString(@"https://www.sequelpro.com/docs/", @"Localized documentation home page - do not localize if no translated webpage is available")
#define SPLOCALIZEDURL_CONTACT             NSLocalizedString(@"https://www.sequelpro.com/docs/Contact_the_developers", @"Localized contact page - do not localize if no translated webpage is available")
#define SPLOCALIZEDURL_KEYBOARDSHORTCUTS   NSLocalizedString(@"https://www.sequelpro.com/docs/Keyboard_Shortcuts", @"Localized keyboard shortcuts page - do not localize if no translated webpage is available")
#define SPLOCALIZEDURL_CONNECTIONHELP      NSLocalizedString(@"https://www.sequelpro.com/docs/category/getting-connected/", @"Localized connection help page - do not localize if no translated webpage is available")
#define SPLOCALIZEDURL_TRANSLATIONFEEDBACK NSLocalizedString(@"https://dev.sequelpro.com/translate/feedback", @"Localized translation feedback page - do not localize if no translated webpage is available")
#define SPLOCALIZEDURL_BUNDLEEDITORHELP    NSLocalizedString(@"https://www.sequelpro.com/bundles/reference/", @"Localized help page for bundle editor - do not localize if no translated webpage is available")
#define SPLOCALIZEDURL_CONTENTFILTERHELP   NSLocalizedString(@"https://www.sequelpro.com/docs/Content_Filters", @"Localized help page for content filter - do not localize if no translated webpage is available")

// Narrow down completion max rows
extern const NSUInteger SPNarrowDownCompletionMaxRows;

// Default monospaced font name
extern NSString *SPDefaultMonospacedFontName;

// System database names
extern NSString *SPMySQLDatabase;
extern NSString *SPMySQLInformationSchemaDatabase;
extern NSString *SPMySQLPerformanceSchemaDatabase;
extern NSString *SPMySQLSysDatabase;

// Table view drag types
extern NSString *SPDefaultPasteboardDragType;
extern NSString *SPFavoritesPasteboardDragType;
extern NSString *SPContentFilterPasteboardDragType;
extern NSString *SPNavigatorPasteboardDragType;
extern NSString *SPNavigatorTableDataPasteboardDragType;
extern NSString *SPExportCustomFileNameTokenPlistType;

// File extensions
extern NSString *SPFileExtensionDefault;
extern NSString *SPFileExtensionSQL;
extern NSString *SPBundleFileExtension;
extern NSString *SPColorThemeFileExtension;
extern NSString *SPUserBundleFileExtension;

// File names
extern NSString *SPFavoritesDataFile;
extern NSString *SPHTMLPrintTemplate;
extern NSString *SPHTMLTableInfoPrintTemplate;
extern NSString *SPHTMLHelpTemplate;
extern NSString *SPPreferenceDefaultsFile;

// SPF file types
extern NSString *SPFExportSettingsContentType;
extern NSString *SPFContentFiltersContentType;
extern NSString *SPFQueryFavoritesContentType;
extern NSString *SPFConnectionContentType;

// Folder names
extern NSString *SPThemesSupportFolder;
extern NSString *SPBundleSupportFolder;
extern NSString *SPDataSupportFolder;

// Table filter
extern NSString *SPTableContentFilterKey;

// Preference key constants
extern NSString *SPFirstRun;

// General Prefpane
extern NSString *SPDefaultFavorite;
extern NSString *SPSelectLastFavoriteUsed;
extern NSString *SPLastFavoriteID;
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
extern NSString *SPFilterTableDefaultOperator;
extern NSString *SPFilterTableDefaultOperatorLastItems;

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
extern NSString *SPCustomQueryEditorSelectionColor;
extern NSString *SPCustomQueryAutoIndent;
extern NSString *SPCustomQueryAutoPairCharacters;
extern NSString *SPCustomQueryAutoUppercaseKeywords;
extern NSString *SPCustomQueryUpdateAutoHelp;
extern NSString *SPCustomQueryAutoHelpDelay;
extern NSString *SPCustomQueryHighlightCurrentQuery;
extern NSString *SPCustomQueryEditorTabStopWidth;
extern NSString *SPCustomQueryEditorCompleteWithBackticks;
extern NSString *SPCustomQueryAutoComplete;
extern NSString *SPCustomQueryAutoCompleteDelay;
extern NSString *SPCustomQueryFunctionCompletionInsertsArguments;
extern NSString *SPCustomQueryEditorThemeName;
extern NSString *SPCustomQuerySoftIndent;
extern NSString *SPCustomQuerySoftIndentWidth;

// AutoUpdate Prefpane
extern NSString *SPLastUsedVersion;

// GUI Prefs
extern NSString *SPConsoleShowTimestamps;
extern NSString *SPConsoleShowConnections;
extern NSString *SPConsoleShowDatabases;
extern NSString *SPConsoleShowSelectsAndShows;
extern NSString *SPConsoleShowHelps;
extern NSString *SPEditInSheetEnabled;
extern NSString *SPTableInformationPanelCollapsed;
extern NSString *SPTableColumnWidths;
extern NSString *SPProcessListTableColumnWidths;
extern NSString *SPProcessListShowProcessID;
extern NSString *SPProcessListShowFullProcessList;
extern NSString *SPProcessListEnableAutoRefresh;
extern NSString *SPProcessListAutoRrefreshInterval;
extern NSString *SPFavoritesSortedBy;
extern NSString *SPFavoritesSortedInReverse;
extern NSString *SPAlwaysShowWindowTabBar;
extern NSString *SPResetAutoIncrementAfterDeletionOfAllRows;
extern NSString *SPFavoriteColorList;
extern NSString *SPDisplayBinaryDataAsHex;
extern NSString *SPMonospacedFontSize;
extern NSString *SPRuleFilterEditorLastVisibilityChoice;

// Hidden Prefs
extern NSString *SPPrintWarningRowLimit;
extern NSString *SPDisplayServerVersionInWindowTitle;
extern NSString *SPLongRunningQueryNotificationTime;
extern NSString *SPAlphabeticalTableSorting;

// Import and export
extern NSString *SPCSVImportFieldTerminator;
extern NSString *SPCSVImportLineTerminator;
extern NSString *SPCSVImportFieldEnclosedBy;
extern NSString *SPCSVImportFieldEscapeCharacter;
extern NSString *SPCSVImportFirstLineIsHeader;
extern NSString *SPCSVFieldImportMappingAlignment;
extern NSString *SPImportClipboardTempFileNamePrefix;
extern NSString *SPLastExportSettings;

// Export filename tokens
extern NSString *SPFileNameDatabaseTokenName;
extern NSString *SPFileNameHostTokenName;
extern NSString *SPFileNameDateTokenName;
extern NSString *SPFileNameYearTokenName;
extern NSString *SPFileNameMonthTokenName;
extern NSString *SPFileNameDayTokenName;
extern NSString *SPFileNameTimeTokenName;
extern NSString *SPFileName24HourTimeTokenName;
extern NSString *SPFileNameFavoriteTokenName;
extern NSString *SPFileNameTableTokenName;

// Misc
extern NSString *SPContentFilters;
extern NSString *SPDocumentTaskEndNotification;
extern NSString *SPDocumentTaskStartNotification;
extern NSString *SPDocumentWillCloseNotification;
extern NSString *SPActivitiesUpdateNotification;
extern NSString *SPWindowToolbarDidToggleNotification;
extern NSString *SPFieldEditorSheetFont;
extern NSString *SPLastSQLFileEncoding;
extern NSString *SPPrintBackground;
extern NSString *SPPrintImagePreviews;
extern NSString *SPQueryFavorites;
extern NSString *SPQueryFavoriteReplacesContent;
extern NSString *SPQueryHistory;
extern NSString *SPQueryHistoryReplacesContent;
extern NSString *SPQueryPrimaryControlRunsAll;
extern NSString *SPQuickLookTypes;
extern NSString *SPTableChangedNotification;
extern NSString *SPTableInfoChangedNotification;
extern NSString *SPBlobTextEditorSpellCheckingEnabled;
extern NSString *SPUniqueSchemaDelimiter;
extern NSString *SPLastImportIntoNewTableEncoding;
extern NSString *SPLastImportIntoNewTableType;
extern NSString *SPGlobalValueHistory;
extern NSString *SPBundleDeletedDefaultBundlesKey;
extern NSString *SPHiddenKeyFileVisibilityKey;
extern NSString *SPSelectionDetailTypeIndexed;
extern NSString *SPSelectionDetailTypePrimaryKeyed;
extern NSString *SPSSHEnableMuxingPreference;
extern NSString *SPSSHClientPath;
extern NSString *SPSSLCipherListKey;
extern NSString *SPQueryFavoritesHaveBeenUpdatedNotification;
extern NSString *SPHistoryItemsHaveBeenUpdatedNotification;
extern NSString *SPContentFiltersHaveBeenUpdatedNotification;
extern NSString *SPCopyContentOnTableCopy;

// URLs
extern NSString *SPDonationsURL;
extern NSString *SPMySQLSearchURL;
extern NSString *SPDevURL;

// Toolbar constants
//
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

// Connection favorite keys
extern NSString *SPFavoritesRootKey;
extern NSString *SPFavoriteChildrenKey;
extern NSString *SPFavoritesGroupNameKey;
extern NSString *SPFavoritesGroupIsExpandedKey;
extern NSString *SPFavoriteIDKey;
extern NSString *SPFavoriteNameKey;
extern NSString *SPFavoriteDatabaseKey;
extern NSString *SPFavoriteHostKey;
extern NSString *SPFavoritePortKey;
extern NSString *SPFavoriteUserKey;
extern NSString *SPFavoriteColorIndexKey;
extern NSString *SPFavoriteTypeKey;
extern NSString *SPFavoriteSocketKey;
extern NSString *SPFavoriteSSHHostKey;
extern NSString *SPFavoriteSSHPortKey;
extern NSString *SPFavoriteSSHUserKey;
extern NSString *SPFavoriteSSHKeyLocationEnabledKey;
extern NSString *SPFavoriteSSHKeyLocationKey;
extern NSString *SPFavoriteUseSSLKey;
extern NSString *SPFavoriteSSLKeyFileLocationEnabledKey;
extern NSString *SPFavoriteSSLKeyFileLocationKey;
extern NSString *SPFavoriteSSLCertificateFileLocationEnabledKey;
extern NSString *SPFavoriteSSLCertificateFileLocationKey;
extern NSString *SPFavoriteSSLCACertFileLocationEnabledKey;
extern NSString *SPFavoriteSSLCACertFileLocationKey;
extern NSString *SPFavoriteUseCompressionKey;
extern NSString *SPConnectionFavoritesChangedNotification;

extern NSString *SPFFormatKey;
extern NSString *SPFVersionKey;

// Favorites import/export
extern NSString *SPFavoritesDataRootKey;

// Bundle Files and Bundle Editor
extern NSString *SPBundleScopeQueryEditor;
extern NSString *SPBundleScopeDataTable;
extern NSString *SPBundleScopeInputField;
extern NSString *SPBundleScopeGeneral;
extern NSString *SPBundleInputSourceSelectedText;
extern NSString *SPBundleInputSourceEntireContent;
extern NSString *SPBundleInputSourceCurrentWord;
extern NSString *SPBundleInputSourceCurrentQuery;
extern NSString *SPBundleInputSourceCurrentLine;
extern NSString *SPBundleInputSourceSelectedTableRowsAsTab;
extern NSString *SPBundleInputSourceSelectedTableRowsAsCsv;
extern NSString *SPBundleInputSourceSelectedTableRowsAsSqlInsert;
extern NSString *SPBundleInputSourceTableRowsAsTab;
extern NSString *SPBundleInputSourceTableRowsAsCsv;
extern NSString *SPBundleInputSourceTableRowsAsSqlInsert;
extern NSString *SPBundleInputSourceNone;
extern NSString *SPBundleInputSourceBlobHandlingInclude;
extern NSString *SPBundleInputSourceBlobHandlingExclude;
extern NSString *SPBundleInputSourceBlobHandlingImageFileReference;
extern NSString *SPBundleInputSourceBlobHandlingFileReference;
extern NSString *SPBundleOutputActionNone;
extern NSString *SPBundleOutputActionInsertAsText;
extern NSString *SPBundleOutputActionInsertAsSnippet;
extern NSString *SPBundleOutputActionReplaceSelection;
extern NSString *SPBundleOutputActionReplaceContent;
extern NSString *SPBundleOutputActionShowAsTextTooltip;
extern NSString *SPBundleOutputActionShowAsHTMLTooltip;
extern NSString *SPBundleOutputActionShowAsHTML;
extern NSString *SPBundleTriggerActionNone;
extern NSString *SPBundleTriggerActionDatabaseChanged;
extern NSString *SPBundleTriggerActionTableChanged;
extern NSString *SPBundleTriggerActionTableRowChanged;
extern NSString *SPBundleFileCommandKey;
extern NSString *SPBundleFileScopeKey;
extern NSString *SPBundleFileNameKey;
extern NSString *SPBundleFileCategoryKey;
extern NSString *SPBundleFileInputSourceKey;
extern NSString *SPBundleFileInputSourceFallBackKey;
extern NSString *SPBundleFileOutputActionKey;
extern NSString *SPBundleFileKeyEquivalentKey;
extern NSString *SPBundleFileInternalKeyEquivalentKey;
extern NSString *SPBundleFileInternalexecutionUUID;
extern NSString *SPBundleFileTooltipKey;
extern NSString *SPBundleFileDisabledKey;
extern NSString *SPBundleFileAuthorKey;
extern NSString *SPBundleFileContactKey;
extern NSString *SPBundleFileUUIDKey;
extern NSString *SPBundleFileDescriptionKey;
extern NSString *SPBundleFileTriggerKey;
extern NSString *SPBundleFileWithBlobKey;
extern NSString *SPBundleFileIsDefaultBundleKey;
extern NSString *SPBundleFileDefaultBundleWasModifiedKey;
extern NSString *SPBundleInternLabelKey;
extern NSString *SPBundleInternPathToFileKey;
extern NSString *SPBundleInternKeyEquivalentKey;
extern NSString *SPBundleFileName;
extern NSString *SPBundleTaskInputFilePath;
extern NSString *SPBundleTaskOutputFilePath;
extern NSString *SPBundleTaskScriptCommandFilePath;
extern NSString *SPBundleTaskCopyBlobFileDirectory;
extern NSString *SPBundleTaskTableMetaDataFilePath;

extern NSString *SPBundleShellVariableInputFilePath;
extern NSString *SPBundleShellVariableOutputFilePath;
extern NSString *SPBundleShellVariableBundlePath;
extern NSString *SPBundleShellVariableBlobFileDirectory;
extern NSString *SPBundleShellVariableQueryFile;
extern NSString *SPBundleShellVariableQueryResultFile;
extern NSString *SPBundleShellVariableQueryResultStatusFile;
extern NSString *SPBundleShellVariableQueryResultMetaFile;
extern NSString *SPBundleShellVariableInputTableMetaData;
extern NSString *SPBundleShellVariableBundleScope;
extern NSString *SPBundleShellVariableUsedQueryForTable;
extern NSString *SPBundleShellVariableCurrentEditedColumnName;
extern NSString *SPBundleShellVariableSelectedTable;
extern NSString *SPBundleShellVariableCurrentEditedTable;
extern NSString *SPBundleShellVariableDataTableSource;
extern NSString *SPBundleShellVariableCurrentQuery;
extern NSString *SPBundleShellVariableSelectedText;
extern NSString *SPBundleShellVariableCurrentWord;
extern NSString *SPBundleShellVariableCurrentLine;
extern NSString *SPBundleShellVariableSelectedRowIndices;
extern NSString *SPBundleShellVariableSelectedTextRange;
extern NSString *SPBundleShellVariableAllDatabases;
extern NSString *SPBundleShellVariableSelectedTables;
extern NSString *SPBundleShellVariableSelectedDatabase;
extern NSString *SPBundleShellVariableRDBMSVersion;
extern NSString *SPBundleShellVariableRDBMSType;
extern NSString *SPBundleShellVariableProcessID;
extern NSString *SPBundleShellVariableIconFile;
extern NSString *SPBundleShellVariableAppResourcesDirectory;
extern NSString *SPBundleShellVariableExitNone;
extern NSString *SPBundleShellVariableExitReplaceSelection;
extern NSString *SPBundleShellVariableExitReplaceContent;
extern NSString *SPBundleShellVariableExitInsertAsText;
extern NSString *SPBundleShellVariableExitInsertAsSnippet;
extern NSString *SPBundleShellVariableExitShowAsHTML;
extern NSString *SPBundleShellVariableExitShowAsTextTooltip;
extern NSString *SPBundleShellVariableExitShowAsHTMLTooltip;
extern NSString *SPBundleShellVariableCurrentHost;
extern NSString *SPBundleShellVariableCurrentUser;
extern NSString *SPBundleShellVariableCurrentPort;
extern NSString *SPBundleShellVariableDatabaseEncoding;
extern NSString *SPBundleShellVariableAllProcedures;
extern NSString *SPBundleShellVariableAllFunctions;
extern NSString *SPBundleShellVariableAllViews;
extern NSString *SPBundleShellVariableAllTables;

extern NSString *SPCurrentTimestampPattern;

typedef NS_ENUM(NSInteger, SPBundleRedirectAction) {
	SPBundleRedirectActionNone                 = 200,
	SPBundleRedirectActionReplaceSection       = 201,
	SPBundleRedirectActionReplaceContent       = 202,
	SPBundleRedirectActionInsertAsText         = 203,
	SPBundleRedirectActionInsertAsSnippet      = 204,
	SPBundleRedirectActionShowAsHTML           = 205,
	SPBundleRedirectActionShowAsTextTooltip    = 207,
	SPBundleRedirectActionShowAsHTMLTooltip    = 208,
	SPBundleRedirectActionLastCode             = 208
};

// URL scheme
extern NSString *SPURLSchemeQueryInputPathHeader;
extern NSString *SPURLSchemeQueryResultPathHeader;
extern NSString *SPURLSchemeQueryResultStatusPathHeader;
extern NSString *SPURLSchemeQueryResultMetaPathHeader;

extern NSString *SPCommonCryptoExceptionName;
extern NSString *SPErrorDomain; // generic SP error domain for NSError

typedef NS_ENUM(NSInteger,SPErrorCode) { // error codes in SPErrorDomain
	/** When plist deserialization fails with nil return and no NSError or the returned object has the wrong type */
	SPErrorWrongTypeOrNil = 110001,
	/** Parsed data is syntactically correct, but semantically wrong (e.g. a SPF file with the wrong content format */
	SPErrorWrongContentType = 110002,
	/** Some data has a version that we don't know how to handle (can be used with e.g. SPF files, which have explicit version numbers) */
	SPErrorWrongContentVersion = 110003,
};

#define SPAppDelegate ((SPAppController *)[NSApp delegate])

// Provides a standard method for our "[x release], x = nil;" convention.
// Yes, this could have been done with a preprocessor macro alone, however
// a function works more nicely in the debugger and in production code
// the optimizer will most likely remove all overhead by inlining anyway :)
void _SPClear(id *addr);
#define SPClear(x) _SPClear(&x)

// Stolen from Stack Overflow: http://stackoverflow.com/questions/969130
#define SPLog(fmt, ...) NSLog((@"%s:%d: " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)

// See http://stackoverflow.com/questions/4415524
#define COUNT_OF(x) (NSInteger)((sizeof(x)/sizeof(0[x])) / ((size_t)(!(sizeof(x) % sizeof(0[x])))))

// This definition is mostly for legibility
#ifndef ESUCCESS
	#define ESUCCESS 0
#else
	#if ESUCCESS != 0
		#error 'ESUCCESS' must be defined as zero!
	#endif
#endif
