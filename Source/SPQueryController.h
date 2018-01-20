//
//  SPQueryController.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Jan 30, 2009
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

#ifndef SP_CODA /* constants */
extern NSString *SPQueryConsoleWindowAutoSaveName;
extern NSString *SPTableViewDateColumnID;
extern NSString *SPTableViewConnectionColumnID;
extern NSString *SPTableViewDatabaseColumnID;
#endif

@interface SPQueryController : NSWindowController 
{
#ifndef SP_CODA /* ivars */
	IBOutlet NSView *saveLogView;
	IBOutlet NSTableView *consoleTableView;
	IBOutlet NSSearchField *consoleSearchField;
	IBOutlet NSTextField *loggingDisabledTextField;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSButton *includeTimeStampsButton;
	IBOutlet NSButton *includeConnectionButton;
	IBOutlet NSButton *includeDatabaseButton;
	IBOutlet NSButton *saveConsoleButton;
	IBOutlet NSButton *clearConsoleButton;

	BOOL showSelectStatementsAreDisabled;
	BOOL showHelpStatementsAreDisabled;
	BOOL filterIsActive;
	BOOL allowConsoleUpdate;

	NSFont *consoleFont;
	NSMutableString *activeFilterString;
	NSMutableArray *messagesFullSet, *messagesFilteredSet, *messagesVisibleSet;

	// DocumentsController
	NSMutableDictionary *favoritesContainer;
	NSMutableDictionary *historyContainer;
	NSMutableDictionary *contentFilterContainer;
	NSUInteger untitledDocumentCounter;
	NSUInteger numberOfMaxAllowedHistory;
#endif

	NSArray *completionKeywordList;
	NSArray *completionFunctionList;
	NSDictionary *functionArgumentSnippets;

#ifndef SP_CODA /* ivars */
	NSUserDefaults *prefs;
	NSDateFormatter *dateFormatter;
	
	pthread_mutex_t consoleLock;
#endif
}

#ifndef SP_CODA
@property (readwrite, retain) NSFont *consoleFont;
#endif

+ (SPQueryController *)sharedQueryController;

/**
 * Calls -sqlStringForForRowIndexes: with the current selection and 
 * puts the output into the general Pasteboard (only if non-empty)
 */
- (IBAction)copy:(id)sender;
- (IBAction)clearConsole:(id)sender;
- (IBAction)saveConsoleAs:(id)sender;
- (IBAction)toggleShowTimeStamps:(id)sender;
- (IBAction)toggleShowConnections:(id)sender;
- (IBAction)toggleShowDatabases:(id)sender;
- (IBAction)toggleShowSelectShowStatements:(id)sender;
- (IBAction)toggleShowHelpStatements:(id)sender;

- (void)updateEntries;

- (BOOL)allowConsoleUpdate;
- (void)setAllowConsoleUpdate:(BOOL)allowUpdate;

- (void)showMessageInConsole:(NSString *)message connection:(NSString *)connection database:(NSString *)database;
- (void)showErrorInConsole:(NSString *)error connection:(NSString *)connection database:(NSString *)database;

- (NSUInteger)consoleMessageCount;

/**
 * Returns the console messages specified by indexes as a string, each message separated by "\n".
 * @param indexes The indexes of rows to be returned. 
 *                Invalid indexes will be skipped silently.
 *                nil is treated as an empty set.
 *
 * If no (valid) indexes are given, @"" will be returned.
 * The output may include other info like timestamp, host, etc. if shown in the table view, as part of a comment.
 *
 * THIS METHOD IS NOT THREAD-SAFE!
 */
- (NSString *)sqlStringForRowIndexes:(NSIndexSet *)indexes;

#pragma mark - SPQueryControllerInitializer

- (NSError *)loadCompletionLists;

#pragma mark - SPQueryDocumentsController

- (NSURL *)registerDocumentWithFileURL:(NSURL *)fileURL andContextInfo:(NSMutableDictionary *)contextInfo;
- (void)removeRegisteredDocumentWithFileURL:(NSURL *)fileURL;

- (void)addFavorite:(NSDictionary *)favorite forFileURL:(NSURL *)fileURL;
- (void)replaceFavoritesByArray:(NSArray *)favoritesArray forFileURL:(NSURL *)fileURL;
- (void)removeFavoriteAtIndex:(NSUInteger)index forFileURL:(NSURL *)fileURL;
- (void)insertFavorite:(NSDictionary *)favorite atIndex:(NSUInteger)index forFileURL:(NSURL *)fileURL;

- (void)addHistory:(NSString *)history forFileURL:(NSURL *)fileURL;
- (void)replaceHistoryByArray:(NSArray *)historyArray forFileURL:(NSURL *)fileURL;

- (void)replaceContentFilterByArray:(NSArray *)contentFilterArray ofType:(NSString *)filterType forFileURL:(NSURL *)fileURL;

- (NSMutableArray *)favoritesForFileURL:(NSURL *)fileURL;
- (NSMutableArray *)historyForFileURL:(NSURL *)fileURL;
- (NSArray *)historyMenuItemsForFileURL:(NSURL *)fileURL;
- (NSUInteger)numberOfHistoryItemsForFileURL:(NSURL *)fileURL;
- (NSMutableDictionary *)contentFilterForFileURL:(NSURL *)fileURL;

- (NSArray *)queryFavoritesForFileURL:(NSURL *)fileURL andTabTrigger:(NSString *)tabTrigger includeGlobals:(BOOL)includeGlobals;

// Completion list controller
- (NSArray*)functionList;
- (NSArray*)keywordList;
- (NSString*)argumentSnippetForFunction:(NSString*)func;

@end
