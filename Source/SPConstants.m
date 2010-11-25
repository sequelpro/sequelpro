//
//  $Id$
//
//  SPConstants.m
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

#import "SPConstants.h"

// Long running notification time for Growl messages
const CGFloat SPLongRunningNotificationTime      = 3.0;

// Narrow down completion max rows
const NSUInteger SPNarrowDownCompletionMaxRows   = 15;

// Kill mode constants
NSString *SPKillProcessQueryMode                 = @"SPKillProcessQueryMode";
NSString *SPKillProcessConnectionMode            = @"SPKillProcessConnectionMode";

// Default monospaced font name
NSString *SPDefaultMonospacedFontName            = @"Monaco";

// Table view drag types
NSString *SPDefaultPasteboardDragType            = @"SequelProPasteboard";
NSString *SPFavoritesPasteboardDragType          = @"SPFavoritesPasteboard";
NSString *SPContentFilterPasteboardDragType      = @"SPContentFilterPasteboard";

// File extensions
NSString *SPFileExtensionDefault                 = @"spf";
NSString *SPBundleFileExtension                  = @"spfs";
NSString *SPFileExtensionSQL                     = @"sql";
NSString *SPColorThemeFileExtension              = @"spTheme";
NSString *SPUserBundleFileExtension              = @"spBundle";

// File names
NSString *SPFavoritesDataFile                    = @"Favorites.plist";
NSString *SPHTMLPrintTemplate                    = @"SPPrintTemplate";
NSString *SPHTMLTableInfoPrintTemplate           = @"SPTableInfoPrintTemplate";
NSString *SPHTMLHelpTemplate                     = @"SPMySQLHelpTemplate";

// Folder names
NSString *SPThemesSupportFolder                  = @"Themes";
NSString *SPBundleSupportFolder                  = @"Bundles";
NSString *SPDataSupportFolder                    = @"Data";

// Preference key constants
// General Prefpane
NSString *SPDefaultFavorite                      = @"DefaultFavorite";
NSString *SPSelectLastFavoriteUsed               = @"SelectLastFavoriteUsed";
NSString *SPLastFavoriteIndex                    = @"LastFavoriteIndex";
NSString *SPAutoConnectToDefault                 = @"AutoConnectToDefault";
NSString *SPDefaultViewMode                      = @"DefaultViewMode";
NSString *SPLastViewMode                         = @"LastViewMode";
NSString *SPDefaultEncoding                      = @"DefaultEncodingTag";
NSString *SPUseMonospacedFonts                   = @"UseMonospacedFonts";
NSString *SPDisplayTableViewVerticalGridlines    = @"DisplayTableViewVerticalGridlines";
NSString *SPCustomQueryMaxHistoryItems           = @"CustomQueryMaxHistoryItems";

// Tables Prefpane
NSString *SPReloadAfterAddingRow                 = @"ReloadAfterAddingRow";
NSString *SPReloadAfterEditingRow                = @"ReloadAfterEditingRow";
NSString *SPReloadAfterRemovingRow               = @"ReloadAfterRemovingRow";
NSString *SPLoadBlobsAsNeeded                    = @"LoadBlobsAsNeeded";
NSString *SPTableRowCountQueryLevel              = @"TableRowCountQueryLevel";
NSString *SPTableRowCountCheapSizeBoundary       = @"TableRowCountCheapLookupSizeBoundary";
NSString *SPNewFieldsAllowNulls                  = @"NewFieldsAllowNulls";
NSString *SPLimitResults                         = @"LimitResults";
NSString *SPLimitResultsValue                    = @"LimitResultsValue";
NSString *SPNullValue                            = @"NullValue";
NSString *SPGlobalResultTableFont                = @"GlobalResultTableFont";
NSString *SPFilterTableDefaultOperator           = @"FilterTableDefaultOperator";
NSString *SPFilterTableDefaultOperatorLastItems  = @"FilterTableDefaultOperatorLastItems";

// Favorites Prefpane
NSString *SPFavorites                            = @"favorites";

// Notifications Prefpane
NSString *SPGrowlEnabled                         = @"GrowlEnabled";
NSString *SPShowNoAffectedRowsError              = @"ShowNoAffectedRowsError";
NSString *SPConsoleEnableLogging                 = @"ConsoleEnableLogging";
NSString *SPConsoleEnableInterfaceLogging        = @"ConsoleEnableInterfaceLogging";
NSString *SPConsoleEnableCustomQueryLogging      = @"ConsoleEnableCustomQueryLogging";
NSString *SPConsoleEnableImportExportLogging     = @"ConsoleEnableImportExportLogging";
NSString *SPConsoleEnableErrorLogging            = @"ConsoleEnableErrorLogging";

// Network Prefpane
NSString *SPConnectionTimeoutValue               = @"ConnectionTimeoutValue";
NSString *SPUseKeepAlive                         = @"UseKeepAlive";
NSString *SPKeepAliveInterval                    = @"KeepAliveInterval";

// Editor Prefpane
NSString *SPCustomQueryEditorFont                = @"CustomQueryEditorFont";
NSString *SPCustomQueryEditorTextColor           = @"CustomQueryEditorTextColor";
NSString *SPCustomQueryEditorBackgroundColor     = @"CustomQueryEditorBackgroundColor";
NSString *SPCustomQueryEditorCaretColor          = @"CustomQueryEditorCaretColor";
NSString *SPCustomQueryEditorCommentColor        = @"CustomQueryEditorCommentColor";
NSString *SPCustomQueryEditorSQLKeywordColor     = @"CustomQueryEditorSQLKeywordColor";
NSString *SPCustomQueryEditorNumericColor        = @"CustomQueryEditorNumericColor";
NSString *SPCustomQueryEditorQuoteColor          = @"CustomQueryEditorQuoteColor";
NSString *SPCustomQueryEditorBacktickColor       = @"CustomQueryEditorBacktickColor";
NSString *SPCustomQueryEditorVariableColor       = @"CustomQueryEditorVariableColor";
NSString *SPCustomQueryEditorHighlightQueryColor = @"CustomQueryEditorHighlightQueryColor";
NSString *SPCustomQueryEditorSelectionColor      = @"CustomQueryEditorSelectionColor";
NSString *SPCustomQueryAutoIndent                = @"CustomQueryAutoIndent";
NSString *SPCustomQueryAutoPairCharacters        = @"CustomQueryAutoPairCharacters";
NSString *SPCustomQueryAutoUppercaseKeywords     = @"CustomQueryAutoUppercaseKeywords";
NSString *SPCustomQueryUpdateAutoHelp            = @"CustomQueryUpdateAutoHelp";
NSString *SPCustomQueryAutoHelpDelay             = @"CustomQueryAutoHelpDelay";
NSString *SPCustomQueryHighlightCurrentQuery     = @"CustomQueryHighlightCurrentQuery";
NSString *SPCustomQueryEditorTabStopWidth        = @"CustomQueryEditorTabStopWidth";
NSString *SPCustomQueryAutoComplete              = @"CustomQueryAutoComplete";
NSString *SPCustomQueryAutoCompleteDelay         = @"CustomQueryAutoCompleteDelay";
NSString *SPCustomQueryFunctionCompletionInsertsArguments = @"CustomQueryFunctionCompletionInsertsArguments";
NSString *SPCustomQueryEditorThemeName           = @"CustomQueryEditorThemeName";

// AutoUpdate Prefpane
NSString *SPLastUsedVersion                      = @"LastUsedVersion";

// GUI Prefs
NSString *SPConsoleShowHelps                     = @"ConsoleShowHelps";
NSString *SPConsoleShowSelectsAndShows           = @"ConsoleShowSelectsAndShows";
NSString *SPConsoleShowTimestamps                = @"ConsoleShowTimestamps";
NSString *SPConsoleShowConnections               = @"ConsoleShowConnections";
NSString *SPEditInSheetEnabled                   = @"EditInSheetEnabled";
NSString *SPTableInformationPanelCollapsed       = @"TableInformationPanelCollapsed";
NSString *SPTableColumnWidths                    = @"tableColumnWidths";
NSString *SPProcessListTableColumnWidths         = @"ProcessListTableColumnWidths";
NSString *SPProcessListShowProcessID             = @"ProcessListShowProcessID";
NSString *SPProcessListEnableAutoRefresh         = @"ProcessListEnableAutoRefresh";
NSString *SPProcessListAutoRrefreshInterval      = @"ProcessListAutoRrefreshInterval";
NSString *SPFavoritesSortedBy                    = @"FavoritesSortedBy";
NSString *SPFavoritesSortedInReverse             = @"FavoritesSortedInReverse";
NSString *SPAlwaysShowWindowTabBar               = @"WindowAlwaysShowTabBar";
NSString *SPResetAutoIncrementAfterDeletionOfAllRows = @"ResetAutoIncrementAfterDeletionOfAllRows";

// Hidden Prefs
NSString *SPPrintWarningRowLimit                 = @"PrintWarningRowLimit";
NSString *SPDisplayServerVersionInWindowTitle    = @"DisplayServerVersionInWindowTitle";

// Import and export
NSString *SPCSVImportFieldEnclosedBy             = @"CSVImportFieldEnclosedBy";
NSString *SPCSVImportFieldEscapeCharacter        = @"CSVImportFieldEscapeCharacter";
NSString *SPCSVImportFieldTerminator             = @"CSVImportFieldTerminator";
NSString *SPCSVImportFirstLineIsHeader           = @"CSVImportFirstLineIsHeader";
NSString *SPCSVImportLineTerminator              = @"CSVImportLineTerminator";
NSString *SPCSVFieldImportMappingAlignment       = @"CSVFieldImportMappingAlignment";
NSString *SPImportClipboardTempFileNamePrefix    = @"/tmp/_SP_ClipBoard_Import_File_";
NSString *SPSQLExportUseCompression              = @"SQLExportUseCompression";
NSString *SPNoBOMforSQLdumpFile                  = @"NoBOMforSQLdumpFile";

// Misc 
NSString *SPContentFilters                       = @"ContentFilters";
NSString *SPDocumentTaskEndNotification          = @"DocumentTaskEnded";
NSString *SPDocumentTaskStartNotification        = @"DocumentTaskStarted";
NSString *SPFieldEditorSheetFont                 = @"FieldEditorSheetFont";
NSString *SPLastSQLFileEncoding                  = @"lastSqlFileEncoding";
NSString *SPPrintBackground                      = @"PrintBackground";
NSString *SPPrintImagePreviews                   = @"PrintImagePreviews";
NSString *SPQueryFavorites                       = @"queryFavorites";
NSString *SPQueryFavoriteReplacesContent         = @"QueryFavoriteReplacesContent";
NSString *SPQueryHistory                         = @"queryHistory";
NSString *SPQueryHistoryReplacesContent          = @"QueryHistoryReplacesContent";
NSString *SPQuickLookTypes                       = @"QuickLookTypes";
NSString *SPTableChangedNotification             = @"SPTableSelectionChanged";
NSString *SPBlobTextEditorSpellCheckingEnabled   = @"BlobTextEditorSpellCheckingEnabled";
NSString *SPUniqueSchemaDelimiter                = @"￸"; // U+FFF8
NSString *SPLastImportIntoNewTableEncoding       = @"LastImportIntoNewTableEncoding";
NSString *SPLastImportIntoNewTableType           = @"LastImportIntoNewTableType";
NSString *SPGlobalValueHistory                   = @"GlobalValueHistory";

// URLs
NSString *SPDonationsURL                         = @"http://www.sequelpro.com/donate.html";
NSString *SPMySQLSearchURL                       = @"http://search.mysql.com/search?q=%@&site=refman-%@&lr=lang_%@";
NSString *SPDevURL                               = @"http://code.google.com/p/sequel-pro/";

// Toolbar constants

// Main window toolbar
NSString *SPMainToolbarDatabaseSelection         = @"DatabaseSelectToolbarItemIdentifier";
NSString *SPMainToolbarHistoryNavigation         = @"HistoryNavigationToolbarItemIdentifier";
NSString *SPMainToolbarShowConsole               = @"ShowConsoleIdentifier";
NSString *SPMainToolbarClearConsole              = @"ClearConsoleIdentifier";
NSString *SPMainToolbarTableStructure            = @"SwitchToTableStructureToolbarItemIdentifier";
NSString *SPMainToolbarTableContent              = @"SwitchToTableContentToolbarItemIdentifier";
NSString *SPMainToolbarCustomQuery               = @"SwitchToRunQueryToolbarItemIdentifier";
NSString *SPMainToolbarTableInfo                 = @"SwitchToTableInfoToolbarItemIdentifier";
NSString *SPMainToolbarTableRelations            = @"SwitchToTableRelationsToolbarItemIdentifier";
NSString *SPMainToolbarTableTriggers             = @"SwitchToTableTriggersToolbarItemIdentifier";
NSString *SPMainToolbarUserManager               = @"SwitchToUserManagerToolbarItemIdentifier";
NSString **SPViewModeToMainToolbarMap[]          = {nil, &SPMainToolbarTableStructure, &SPMainToolbarTableContent, &SPMainToolbarCustomQuery, &SPMainToolbarTableInfo, &SPMainToolbarTableRelations, &SPMainToolbarTableTriggers};

// Preferences toolbar
NSString *SPPreferenceToolbarGeneral             = @"SPPreferenceToolbarGeneral";
NSString *SPPreferenceToolbarTables              = @"SPPreferenceToolbarTables";
NSString *SPPreferenceToolbarFavorites           = @"SPPreferenceToolbarFavorites";
NSString *SPPreferenceToolbarNotifications       = @"SPPreferenceToolbarNotifications";
NSString *SPPreferenceToolbarAutoUpdate          = @"SPPreferenceToolbarAutoUpdate";
NSString *SPPreferenceToolbarNetwork             = @"SPPreferenceToolbarNetwork";
NSString *SPPreferenceToolbarEditor              = @"SPPreferenceToolbarEditor";
NSString *SPPreferenceToolbarShortcuts           = @"SPPreferenceToolbarShortcuts";

// Connection favorite keys
NSString *SPFavoritesRootKey                             = @"Favorites Root";
NSString *SPFavoriteChildrenKey                          = @"Children";
NSString *SPFavoritesGroupNameKey                        = @"Name";
NSString *SPFavoriteIDKey                                = @"id";
NSString *SPFavoriteNameKey                              = @"name";
NSString *SPFavoriteDatabaseKey                          = @"database";
NSString *SPFavoriteHostKey                              = @"host";
NSString *SPFavoritePortKey                              = @"port";
NSString *SPFavoriteUserKey                              = @"user";
NSString *SPFavoriteTypeKey                              = @"type";
NSString *SPFavoriteSocketKey                            = @"socket";
NSString *SPFavoriteSSHHostKey                           = @"sshHost";
NSString *SPFavoriteSSHPortKey                           = @"sshPort";
NSString *SPFavoriteSSHUserKey                           = @"sshUser";
NSString *SPFavoriteSSHKeyLocationEnabledKey             = @"sshKeyLocationEnabled";
NSString *SPFavoriteSSHKeyLocationKey                    = @"sshKeyLocation";
NSString *SPFavoriteUseSSLKey                            = @"useSSL";
NSString *SPFavoriteSSLKeyFileLocationEnabledKey         = @"sslKeyFileLocationEnabled";
NSString *SPFavoriteSSLKeyFileLocationKey                = @"sslKeyFileLocation";
NSString *SPFavoriteSSLCertificateFileLocationEnabledKey = @"sslCertificateFileLocationEnabled";
NSString *SPFavoriteSSLCertificateFileLocationKey        = @"sslCertificateFileLocation";
NSString *SPFavoriteSSLCACertFileLocationEnabledKey      = @"sslCACertFileLocationEnabled";
NSString *SPFavoriteSSLCACertFileLocationKey             = @"sslCACertFileLocation";

// Bundle Files and Bundle Editor
NSString *SPBundleScopeQueryEditor                          = @"editor";
NSString *SPBundleScopeDataTable                            = @"datatable";
NSString *SPBundleScopeInputField                           = @"inputfield";
NSString *SPBundleScopeGeneral                              = @"general";
NSString *SPBundleInputSourceSelectedText                   = @"selectedtext";
NSString *SPBundleInputSourceEntireContent                  = @"entirecontent";
NSString *SPBundleInputSourceCurrentWord                    = @"currentword";
NSString *SPBundleInputSourceCurrentQuery                   = @"currentquery";
NSString *SPBundleInputSourceCurrentLine                    = @"currentline";
NSString *SPBundleInputSourceSelectedTableRowsAsTab         = @"selectedtablerowsastab";
NSString *SPBundleInputSourceSelectedTableRowsAsCsv         = @"selectedtablerowsascsv";
NSString *SPBundleInputSourceSelectedTableRowsAsSqlInsert   = @"selectedtablerowsassqlinsert";
NSString *SPBundleInputSourceTableRowsAsTab                 = @"tablerowsastab";
NSString *SPBundleInputSourceTableRowsAsCsv                 = @"tablerowsascsv";
NSString *SPBundleInputSourceTableRowsAsSqlInsert           = @"tablerowsassqlinsert";
NSString *SPBundleInputSourceNone                           = @"none";
NSString *SPBundleOutputActionNone                          = @"none";
NSString *SPBundleOutputActionInsertAsText                  = @"insertastext";
NSString *SPBundleOutputActionInsertAsSnippet               = @"insertassnippet";
NSString *SPBundleOutputActionReplaceSelection              = @"replaceselection";
NSString *SPBundleOutputActionReplaceContent                = @"replacecontent";
NSString *SPBundleOutputActionShowAsTextTooltip             = @"showastexttooltip";
NSString *SPBundleOutputActionShowAsHTMLTooltip             = @"showashtmltooltip";
NSString *SPBundleOutputActionShowAsHTML                    = @"showashtml";
NSString *SPBundleFileCommandKey                            = @"command";
NSString *SPBundleFileScopeKey                              = @"scope";
NSString *SPBundleFileNameKey                               = @"name";
NSString *SPBundleFileCategoryKey                           = @"category";
NSString *SPBundleFileInputSourceKey                        = @"input";
NSString *SPBundleFileInputSourceFallBackKey                = @"input_fallback";
NSString *SPBundleFileOutputActionKey                       = @"output";
NSString *SPBundleFileKeyEquivalentKey                      = @"keyEquivalent";
NSString *SPBundleFileInternalKeyEquivalentKey              = @"internalKeyEquivalent";
NSString *SPBundleFileTooltipKey                            = @"tooltip";
NSString *SPBundleFileDisabledKey                           = @"disabled";
NSString *SPBundleFileAuthorKey                             = @"author";
NSString *SPBundleFileContactKey                            = @"contact";
NSString *SPBundleFileUUIDKey                               = @"uuid";
NSString *SPBundleFileDescriptionKey                        = @"description";
NSString *SPBundleInternLabelKey                            = @"label";
NSString *SPBundleInternPathToFileKey                       = @"path";
NSString *SPBundleInternKeyEquivalentKey                    = @"keyEquivalent";

NSString *SPBundleFileName                                  = @"command.plist";
NSString *SPBundleTaskInputFilePath                         = @"/tmp/SP_BUNDLE_TASK_INPUT";
NSString *SPBundleTaskScriptCommandFilePath                 = @"/tmp/SP_SCRIPT_COMMAND";

// sequel URL scheme
NSString *SPURLSchemeQueryInputPathHeader          = @"/tmp/SP_QUERY_";
NSString *SPURLSchemeQueryResultPathHeader         = @"/tmp/SP_QUERY_RESULT_";
NSString *SPURLSchemeQueryResultStatusPathHeader   = @"/tmp/SP_QUERY_RESULT_STATUS_";
NSString *SPURLSchemeQueryResultMetaPathHeader     = @"/tmp/SP_QUERY_META_";
