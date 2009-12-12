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

// Kill mode constants
NSString *SPKillProcessQueryMode                 = @"SPKillProcessQueryMode";
NSString *SPKillProcessConnectionMode            = @"SPKillProcessConnectionMode";

// Default monospaced font name
NSString *SPDefaultMonospacedFontName            = @"Monaco";

// Table view drag types
NSString *SPFavoritesPasteboardDragType          = @"SPFavoritesPasteboard";
NSString *SPContentFilterPasteboardDragType      = @"SPContentFilterPasteboard";

// File extensions
NSString *SPFileExtensionDefault                 = @"spf";
NSString *SPFileExtensionSQL                     = @"sql";

// Preference key constants
// General Prefpane
NSString *SPDefaultFavorite                      = @"DefaultFavorite";
NSString *SPSelectLastFavoriteUsed               = @"SelectLastFavoriteUsed";
NSString *SPLastFavoriteIndex                    = @"LastFavoriteIndex";
NSString *SPAutoConnectToDefault                 = @"AutoConnectToDefault";
NSString *SPDefaultViewMode                      = @"DefaultViewMode";
NSString *SPLastViewMode                         = @"LastViewMode";
NSString *SPDefaultEncoding                      = @"DefaultEncoding";
NSString *SPUseMonospacedFonts                   = @"UseMonospacedFonts";
NSString *SPDisplayTableViewVerticalGridlines    = @"DisplayTableViewVerticalGridlines";
NSString *SPCustomQueryMaxHistoryItems           = @"CustomQueryMaxHistoryItems";

// Tables Prefpane
NSString *SPReloadAfterAddingRow                 = @"ReloadAfterAddingRow";
NSString *SPReloadAfterEditingRow                = @"ReloadAfterEditingRow";
NSString *SPReloadAfterRemovingRow               = @"ReloadAfterRemovingRow";
NSString *SPLoadBlobsAsNeeded                    = @"LoadBlobsAsNeeded";
NSString *SPFetchCorrectRowCount                 = @"FetchCorrectRowCount";
NSString *SPNewFieldsAllowNulls                  = @"NewFieldsAllowNulls";
NSString *SPLimitResults                         = @"LimitResults";
NSString *SPLimitResultsValue                    = @"LimitResultsValue";
NSString *SPNullValue                            = @"NullValue";

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
NSString *SPCustomQueryAutoIndent                = @"CustomQueryAutoIndent";
NSString *SPCustomQueryAutoPairCharacters        = @"CustomQueryAutoPairCharacters";
NSString *SPCustomQueryAutoUppercaseKeywords     = @"CustomQueryAutoUppercaseKeywords";
NSString *SPCustomQueryUpdateAutoHelp            = @"CustomQueryUpdateAutoHelp";
NSString *SPCustomQueryAutoHelpDelay             = @"CustomQueryAutoHelpDelay";
NSString *SPCustomQueryHighlightCurrentQuery     = @"CustomQueryHighlightCurrentQuery";

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

// Import
NSString *SPCSVImportFieldEnclosedBy             = @"CSVImportFieldEnclosedBy";
NSString *SPCSVImportFieldEscapeCharacter        = @"CSVImportFieldEscapeCharacter";
NSString *SPCSVImportFieldTerminator             = @"CSVImportFieldTerminator";
NSString *SPCSVImportFirstLineIsHeader           = @"CSVImportFirstLineIsHeader";
NSString *SPCSVImportLineTerminator              = @"CSVImportLineTerminator";

// Misc 
NSString *SPContentFilters                       = @"ContentFilters";
NSString *SPDocumentTaskEndNotification          = @"DocumentTaskEnded";
NSString *SPDocumentTaskStartNotification        = @"DocumentTaskStarted";
NSString *SPFieldEditorSheetFont                 = @"FieldEditorSheetFont";
NSString *SPLastSQLFileEncoding                  = @"lastSqlFileEncoding";
NSString *SPNoBOMforSQLdumpFile                  = @"NoBOMforSQLdumpFile";
NSString *SPPrintBackground                      = @"PrintBackground";
NSString *SPPrintImagePreviews                   = @"PrintImagePreviews";
NSString *SPQueryFavorites                       = @"queryFavorites";
NSString *SPQueryFavoriteReplacesContent         = @"QueryFavoriteReplacesContent";
NSString *SPQueryHistory                         = @"queryHistory";
NSString *SPQueryHistoryReplacesContent          = @"QueryHistoryReplacesContent";
NSString *SPQuickLookTypes                       = @"QuickLookTypes";
NSString *SPTableChangedNotification             = @"SPTableSelectionChanged";
NSString *SPBlobTextEditorSpellCheckingEnabled   = @"BlobTextEditorSpellCheckingEnabled";

// URLs
NSString *SPHomePageURL                          = @"http://www.sequelpro.com/";
NSString *SPDonationsURL                         = @"http://www.sequelpro.com/donate.html";
NSString *SPFAQURL                               = @"http://www.sequelpro.com/docs/Frequently_Asked_Questions";
NSString *SPDocumentationURL                     = @"http://www.sequelpro.com/docs/";
NSString *SPContactURL                           = @"http://www.sequelpro.com/docs/Contact_the_developers";

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
NSString *SPMainToolbarUserManager               = @"SwitchToUserManagerToolbarItemIdentifier";

// Preferences toolbar
NSString *SPPreferenceToolbarGeneral             = @"SPPreferenceToolbarGeneral";
NSString *SPPreferenceToolbarTables              = @"SPPreferenceToolbarTables";
NSString *SPPreferenceToolbarFavorites           = @"SPPreferenceToolbarFavorites";
NSString *SPPreferenceToolbarNotifications       = @"SPPreferenceToolbarNotifications";
NSString *SPPreferenceToolbarAutoUpdate          = @"SPPreferenceToolbarAutoUpdate";
NSString *SPPreferenceToolbarNetwork             = @"SPPreferenceToolbarNetwork";
NSString *SPPreferenceToolbarEditor              = @"SPPreferenceToolbarEditor";
NSString *SPPreferenceToolbarShortcuts           = @"SPPreferenceToolbarShortcuts";
