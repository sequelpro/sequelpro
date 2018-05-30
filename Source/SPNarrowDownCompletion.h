//
//  SPNarrowDownCompletion.h
//  sequel-pro
//
//  This class is based on TextMate's TMDIncrementalPopUp implementation
//  (Dialog plugin) written by Joachim Mårtensson, Allan Odgaard, and Hans-Jörg Bibiko.
//
//  See license: http://svn.textmate.org/trunk/LICENSE
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

@class SPDatabaseStructure;

@interface SPNarrowDownCompletion : NSWindow <NSTableViewDelegate, NSTableViewDataSource>
{
	NSArray *suggestions;
	NSMutableString *mutablePrefix;
	NSString *staticPrefix;
	NSString *currentDb;
	NSArray *filtered;
	NSTableView *theTableView;
	NSPoint caretPos;
	BOOL isAbove;
	BOOL closeMe;
	BOOL caseSensitive;
	BOOL dictMode;
	BOOL triggerMode;
	BOOL fuzzyMode;
	BOOL cursorMovedLeft;
	BOOL commaInsertionMode;
	BOOL autoCompletionMode;
	BOOL oneColumnMode;
	BOOL isQueryingDatabaseStructure;
	BOOL autocompletePlaceholderWasInserted;
	NSMutableString *originalFilterString;
	NSInteger backtickMode;
	NSFont *tableFont;
	NSRange theCharRange;
	NSRange theParseRange;
	NSString *theAliasName;

	NSTimer *stateTimer;
	NSArray *syncArrowImages;
	NSUInteger currentSyncImage;

	NSUInteger timeCounter;

	id theView;

	NSInteger maxWindowWidth;
	NSInteger spaceCounter;

	NSMutableCharacterSet *textualInputCharacters;

	SPDatabaseStructure *databaseStructureRetrieval;
#ifndef SP_CODA
	NSUserDefaults *prefs;
#endif
}

- (id)      initWithItems:(NSArray *)someSuggestions
             alreadyTyped:(NSString *)aUserString
             staticPrefix:(NSString *)aStaticPrefix
 additionalWordCharacters:(NSString *)someAdditionalWordCharacters
            caseSensitive:(BOOL)isCaseSensitive
                charRange:(NSRange)initRange
               parseRange:(NSRange)parseRange
                   inView:(id)aView
                 dictMode:(BOOL)mode
           tabTriggerMode:(BOOL)tabTriggerMode
              fuzzySearch:(BOOL)fuzzySearch
             backtickMode:(NSInteger)theBackTickMode
               selectedDb:(NSString *)selectedDb
           caretMovedLeft:(BOOL)caretMovedLeft
             autoComplete:(BOOL)autoComplete
                oneColumn:(BOOL)oneColumn
                    alias:(NSString *)anAlias
 withDBStructureRetriever:(SPDatabaseStructure *)theDatabaseStructure;
- (void)setCaretPos:(NSPoint)aPos;
- (void)insert_text:(NSString *)aString;
- (void)insertAutocompletePlaceholder;
- (void)removeAutocompletionPlaceholderUsingFastMethod:(BOOL)useFastMethod;
- (void)adjustWorkingRangeByDelta:(NSInteger)delta;

- (void)updateSyncArrowStatus;
- (void)reInvokeCompletion;

@end
