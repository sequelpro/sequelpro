//
//  $Id$
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
//  More info at <http://code.google.com/p/sequel-pro/>

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

// XML export formats
enum {
	SPXMLExportMySQLFormat = 0,
	SPXMLExportPlainFormat = 1
};
typedef NSUInteger SPXMLExportFormat;

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
	SPFavoritesSortUnsorted = -1,
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
	SPEncodingEUCKRKorean		= 180
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
#define SPLOCALIZEDURL_HOMEPAGE            NSLocalizedString(@"http://www.sequelpro.com/", @"Localized home page - do not localize if no translated webpage is available")
#define SPLOCALIZEDURL_FAQ                 NSLocalizedString(@"http://www.sequelpro.com/docs/Frequently_Asked_Questions", @"Localized help page for Frequently Asked Questions - do not localize if no translated webpage is available")
#define SPLOCALIZEDURL_DOCUMENTATION       NSLocalizedString(@"http://www.sequelpro.com/docs/", @"Localized documentation home page - do not localize if no translated webpage is available")
#define SPLOCALIZEDURL_CONTACT             NSLocalizedString(@"http://www.sequelpro.com/docs/Contact_the_developers", @"Localized contact page - do not localize if no translated webpage is available")
#define SPLOCALIZEDURL_KEYBOARDSHORTCUTS   NSLocalizedString(@"http://www.sequelpro.com/docs/Keyboard_Shortcuts", @"Localized keyboard shortcuts page - do not localize if no translated webpage is available")
#define SPLOCALIZEDURL_CONNECTIONHELP      NSLocalizedString(@"http://www.sequelpro.com/docs/Getting_Connected", @"Localized connection help page - do not localize if no translated webpage is available")
#define SPLOCALIZEDURL_TRANSLATIONFEEDBACK NSLocalizedString(@"http://dev.sequelpro.com/translate/feedback", @"Localized translation feedback page - do not localize if no translated webpage is available")
#define SPLOCALIZEDURL_BUNDLEEDITORHELP    NSLocalizedString(@"http://www.sequelpro.com/docs/Bundle_Editor", @"Localized help page for bundle editor - do not localize if no translated webpage is available")
#define SPLOCALIZEDURL_CONTENTFILTERHELP   NSLocalizedString(@"http://www.sequelpro.com/docs/Content_Filters", @"Localized help page for content filter - do not localize if no translated webpage is available")

// Narrow down completion max rows
extern const NSUInteger SPNarrowDownCompletionMaxRows;

// Default monospaced font name
extern NSString *SPDefaultMonospacedFontName;

// System database names
extern NSString *SPMySQLDatabase;
extern NSString *SPMySQLInformationSchemaDatabase;
extern NSString *SPMySQLPerformanceSchemaDatabase;

// Table view drag types
extern NSString *SPDefaultPasteboardDragType;
extern NSString *SPFavoritesPasteboardDragType;
extern NSString *SPContentFilterPasteboardDragType;
extern NSString *SPNavigatorPasteboardDragType;
extern NSString *SPNavigatorTableDataPasteboardDragType;

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
extern NSString *SPSQLExportUseCompression;
extern NSString *SPNoBOMforSQLdumpFile;
extern NSString *SPExportLastDirectory;
extern NSString *SPExportFilenameFormat;

// Misc
extern NSString *SPContentFilters;
extern NSString *SPDocumentTaskEndNotification;
extern NSString *SPDocumentTaskStartNotification;
extern NSString *SPDocumentWillCloseNotification;
extern NSString *SPActivitiesUpdateNotification;
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
extern NSString *SPLastImportIntoNewTableEncoding;
extern NSString *SPLastImportIntoNewTableType;
extern NSString *SPGlobalValueHistory;
extern NSString *SPBundleDeletedDefaultBundlesKey;
extern NSString *SPHiddenKeyFileVisibilityKey;
extern NSString *SPSelectionDetailTypeIndexed;
extern NSString *SPSelectionDetailTypePrimaryKeyed;

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
extern NSString *SPConnectionFavoritesChangedNotification;

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

extern const NSInteger SPBundleRedirectActionNone;
extern const NSInteger SPBundleRedirectActionReplaceSection;
extern const NSInteger SPBundleRedirectActionReplaceContent;
extern const NSInteger SPBundleRedirectActionInsertAsText;
extern const NSInteger SPBundleRedirectActionInsertAsSnippet;
extern const NSInteger SPBundleRedirectActionShowAsHTML;
extern const NSInteger SPBundleRedirectActionShowAsTextTooltip;
extern const NSInteger SPBundleRedirectActionShowAsHTMLTooltip;
extern const NSInteger SPBundleRedirectActionLastCode;

// URL scheme
extern NSString *SPURLSchemeQueryInputPathHeader;
extern NSString *SPURLSchemeQueryResultPathHeader;
extern NSString *SPURLSchemeQueryResultStatusPathHeader;
extern NSString *SPURLSchemeQueryResultMetaPathHeader;
