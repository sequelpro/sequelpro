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

// Preference key constants
NSString *SPDefaultEncoding                      = @"SPDefaultEncoding";
NSString *SPUseMonospacedFonts                   = @"UseMonospacedFonts";
NSString *SPDisplayTableViewVerticalGridlines    = @"DisplayTableViewVerticalGridlines";
NSString *SPReloadAfterAddingRow                 = @"ReloadAfterAddingRow";
NSString *SPReloadAfterEditingRow                = @"ReloadAfterEditingRow";
NSString *SPReloadAfterRemovingRow               = @"ReloadAfterRemovingRow";
NSString *SPLoadBlobsAsNeeded                    = @"LoadBlobsAsNeeded";
NSString *SPFetchCorrectRowCount                 = @"FetchCorrectRowCount";
NSString *SPNewFieldsAllowNulls                  = @"NewFieldsAllowNulls";
NSString *SPLimitResults                         = @"LimitResults";
NSString *SPLimitResultsValue                    = @"LimitResultsValue";
NSString *SPNullValue                            = @"NullValue";
NSString *SPShowNoAffectedRowsError              = @"ShowNoAffectedRowsError";
NSString *SPGrowlEnabled                         = @"GrowlEnabled";
NSString *SPConnectionTimeoutValue               = @"ConnectionTimeoutValue";
NSString *SPUseKeepAlive                         = @"UseKeepAlive";
NSString *SPKeepAliveInterval                    = @"KeepAliveInterval";
NSString *SPEditInSheetEnabled                   = @"EditInSheetEnabled";
NSString *SPQueryFavoriteReplacesContent         = @"QueryFavoriteReplacesContent";
NSString *SPQueryHistoryReplacesContent          = @"QueryHistoryReplacesContent";
NSString *SPCustomQueryEditorFont                = @"CustomQueryEditorFont";
NSString *SPCustomQueryEditorBackgroundColor     = @"CustomQueryEditorBackgroundColor";
NSString *SPCustomQueryEditorBacktickColor       = @"CustomQueryEditorBacktickColor";
NSString *SPCustomQueryEditorCommentColor        = @"CustomQueryEditorCommentColor";
NSString *SPCustomQueryEditorNumericColor        = @"CustomQueryEditorNumericColor";
NSString *SPCustomQueryEditorQuoteColor          = @"CustomQueryEditorQuoteColor";
NSString *SPCustomQueryEditorSQLKeywordColor     = @"CustomQueryEditorSQLKeywordColor";
NSString *SPCustomQueryEditorTextColor           = @"CustomQueryEditorTextColor";
NSString *SPCustomQueryEditorHighlightQueryColor = @"CustomQueryEditorHighlightQueryColor";
NSString *SPCustomQueryEditorCaretColor          = @"CustomQueryEditorCaretColor";
NSString *SPCustomQueryEditorVariableColor       = @"CustomQueryEditorVariableColor";
NSString *SPCustomQueryHighlightCurrentQuery     = @"CustomQueryHighlightCurrentQuery";
NSString *SPCustomQueryAutoIndent                = @"CustomQueryAutoIndent";
NSString *SPCustomQueryAutoPairCharacters        = @"CustomQueryAutoPairCharacters";
NSString *SPCustomQueryAutoUppercaseKeywords     = @"CustomQueryAutoUppercaseKeywords";
NSString *SPCustomQueryUpdateAutoHelp            = @"CustomQueryUpdateAutoHelp";
NSString *SPCustomQueryAutoHelpDelay             = @"CustomQueryAutoHelpDelay";
NSString *SPCustomQueryMaxHistoryItems           = @"CustomQueryMaxHistoryItems";
NSString *SPLastSQLFileEncoding                  = @"lastSqlFileEncoding";
NSString *SPSelectLastFavoriteUsed               = @"SelectLastFavoriteUsed";
NSString *SPLastFavoriteIndex                    = @"LastFavoriteIndex";
NSString *SPTableInformationPanelCollapsed       = @"TableInformationPanelCollapsed";
NSString *SPConsoleEnableLogging                 = @"ConsoleEnableLogging";
NSString *SPConsoleEnableInterfaceLogging        = @"ConsoleEnableInterfaceLogging";
NSString *SPConsoleEnableCustomQueryLogging      = @"ConsoleEnableCustomQueryLogging";
NSString *SPConsoleEnableImportExportLogging     = @"ConsoleEnableImportExportLogging";
NSString *SPEnableErrorLogging                   = @"EnableErrorLogging";
NSString *SPConsoleShowTimestamps                = @"ConsoleShowTimestamps";
NSString *SPConsoleShowSelectsAndShows           = @"ConsoleShowSelectsAndShows";
NSString *SPConsoleShowHelps                     = @"ConsoleShowHelps";
NSString *SPPrintBackground                      = @"PrintBackground";
NSString *SPPrintImagePreviews                   = @"PrintImagePreviews";
NSString *SPContentFilters                       = @"ContentFilters";
NSString *SPCSVImportFieldTerminator             = @"CSVImportFieldTerminator";
NSString *SPCSVImportLineTerminator              = @"CSVImportLineTerminator";
NSString *SPCSVImportFieldEnclosedBy             = @"CSVImportFieldEnclosedBy";
NSString *SPCSVImportFieldEscapeCharacter        = @"CSVImportFieldEscapeCharacter";
NSString *SPCSVImportFirstLineIsHeader           = @"CSVImportFirstLineIsHeader";
NSString *SPLastUsedVersion                      = @"LastUsedVersion";
NSString *SPFieldEditorSheetFont                 = @"FieldEditorSheetFont";
NSString *SPQuickLookTypes                       = @"QuickLookTypes";
NSString *SPQueryFavorites                       = @"queryFavorites";
NSString *SPFavorites                            = @"favorites";
NSString *SPTableColumnWidths                    = @"tableColumnWidths";
NSString *SPQueryHistory                         = @"queryHistory";
