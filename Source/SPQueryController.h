//
//  $Id$
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
//  More info at <http://code.google.com/p/sequel-pro/>

#ifndef SP_REFACTOR /* constants */
extern NSString *SPQueryConsoleWindowAutoSaveName;
extern NSString *SPTableViewDateColumnID;
extern NSString *SPTableViewConnectionColumnID;
#endif

@interface SPQueryController : NSWindowController 
{
#ifndef SP_REFACTOR /* ivars */
	IBOutlet NSView *saveLogView;
	IBOutlet NSTableView *consoleTableView;
	IBOutlet NSSearchField *consoleSearchField;
	IBOutlet NSTextField *loggingDisabledTextField;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSButton *includeTimeStampsButton, *includeConnectionButton, *saveConsoleButton, *clearConsoleButton;
	
	NSFont *consoleFont;
	NSMutableArray *messagesFullSet, *messagesFilteredSet, *messagesVisibleSet;
	BOOL showSelectStatementsAreDisabled;
	BOOL showHelpStatementsAreDisabled;
	BOOL filterIsActive;
	BOOL allowConsoleUpdate;
	
	NSMutableString *activeFilterString;
	
	// DocumentsController
	NSUInteger untitledDocumentCounter;
	NSMutableDictionary *favoritesContainer;
	NSMutableDictionary *historyContainer;
	NSMutableDictionary *contentFilterContainer;
	NSUInteger numberOfMaxAllowedHistory;
#endif

	NSArray *completionKeywordList;
	NSArray *completionFunctionList;
	NSDictionary *functionArgumentSnippets;

#ifndef SP_REFACTOR /* ivars */
	NSUserDefaults *prefs;
	NSDateFormatter *dateFormatter;
	
	pthread_mutex_t consoleLock;
#endif
}

#ifndef SP_REFACTOR
@property (readwrite, retain) NSFont *consoleFont;
#endif

+ (SPQueryController *)sharedQueryController;

- (IBAction)copy:(id)sender;
- (IBAction)clearConsole:(id)sender;
- (IBAction)saveConsoleAs:(id)sender;
- (IBAction)toggleShowTimeStamps:(id)sender;
- (IBAction)toggleShowConnections:(id)sender;
- (IBAction)toggleShowSelectShowStatements:(id)sender;
- (IBAction)toggleShowHelpStatements:(id)sender;

- (void)updateEntries;

- (BOOL)allowConsoleUpdate;
- (void)setAllowConsoleUpdate:(BOOL)allowUpdate;

- (void)showMessageInConsole:(NSString *)message connection:(NSString *)connection;
- (void)showErrorInConsole:(NSString *)error connection:(NSString *)connection;

- (NSUInteger)consoleMessageCount;

@end
