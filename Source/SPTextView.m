//
//  SPTextView.m
//  sequel-pro
//
//  Created by Carsten Blüm.
//  Copyright (c) 2012 Sequel Pro Team. All rights reserved.
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

#import "SPTextView.h"
#import "SPCustomQuery.h"
#import "SPDatabaseDocument.h"
#import "SPNarrowDownCompletion.h"
#import "SPQueryController.h"
#import "SPTooltip.h"
#import "SPTablesList.h"
#import "SPNavigatorController.h"
#import "SPAlertSheets.h"
#import "RegexKitLite.h"
#ifndef SP_CODA /* headers */
#import "SPBundleHTMLOutputController.h"
#endif
#ifndef SP_CODA /* headers */
#import "SPAppController.h"
#endif
#import "SPDatabaseStructure.h"
#import "SPBundleCommandRunner.h"
#import "NoodleLineNumberView.h"
#import "SPCopyTable.h"
#import "SPEditorTokens.h"
#import "SPSyntaxParser.h"
#import "SPHelpViewerClient.h"

#import <SPMySQL/SPMySQL.h>

#pragma mark -
#pragma mark attribute definition 

#define kAPlinked      @"Linked" // attribute for a via auto-pair inserted char
#define kAPval         @"linked"
#define kLEXToken      @"Quoted" // set via lex to indicate a quoted string
#define kLEXTokenValue @"isMarked"
#define kSQLkeyword    @"s"      // attribute for found SQL keywords
#define kQuote         @"Quote"
#define kQuoteValue    @"isQuoted"
#define kValue         @"x"
#define kBTQuote       @"BTQuote"
#define kBTQuoteValue  @"isBTQuoted"

#pragma mark -
#pragma mark Constant definitions

#define SP_CQ_SEARCH_IN_MYSQL_HELP_MENU_ITEM_TAG 1000
#define SP_CQ_COPY_AS_RTF_MENU_ITEM_TAG          1001
#define SP_CQ_SELECT_CURRENT_QUERY_MENU_ITEM_TAG 1002

#define SP_SYNTAX_HILITE_BIAS 2000
#define SP_MAX_TEXT_SIZE_FOR_SYNTAX_HIGHLIGHTING 20000000

#pragma mark -

@interface SPTextView ()

NSInteger _alphabeticSort(id string1, id string2, void *reverse);
#ifndef SP_CODA
- (void)_setTextSelectionColor:(NSColor *)newSelectionColor;
- (void)_setTextSelectionColor:(NSColor *)newSelectionColor onBackgroundColor:(NSColor *)aBackgroundColor;
#endif
- (void)_positionCompletionPopup:(SPNarrowDownCompletion *)aPopup relativeToTextAtLocation:(NSUInteger)aLocation;

@end

// some helper functions for handling rectangles and points
// needed in roundedBezierPathAroundRange:
static inline CGFloat SPRectTop(NSRect rectangle) { return rectangle.origin.y; }
static inline CGFloat SPRectBottom(NSRect rectangle) { return rectangle.origin.y+rectangle.size.height; }
static inline CGFloat SPRectLeft(NSRect rectangle) { return rectangle.origin.x; }
static inline CGFloat SPRectRight(NSRect rectangle) { return rectangle.origin.x+rectangle.size.width; }
static inline CGFloat SPPointDistance(NSPoint a, NSPoint b) { return sqrtf( (a.x-b.x)*(a.x-b.x) + (a.y-b.y)*(a.y-b.y) ); }
static inline NSPoint SPPointOnLine(NSPoint a, NSPoint b, CGFloat t) { return NSMakePoint(a.x*(1.0f-t) + b.x*t, a.y*(1.0f-t) + b.y*t); }

@implementation SPTextView

@synthesize queryHiliteColor;
@synthesize queryEditorBackgroundColor;
@synthesize commentColor;
@synthesize quoteColor;
@synthesize keywordColor;
@synthesize backtickColor;
@synthesize numericColor;
@synthesize variableColor;
@synthesize otherTextColor;
@synthesize queryRange;
@synthesize shouldHiliteQuery;
@synthesize completionIsOpen;
@synthesize completionWasReinvokedAutomatically;

#ifdef SP_CODA
@synthesize tableDocumentInstance;
@synthesize tablesListInstance;
@synthesize customQueryInstance;
@synthesize mySQLConnection;
#endif

- (void) awakeFromNib
{
#ifndef SP_CODA /* init ivars */
	prefs = [[NSUserDefaults standardUserDefaults] retain];
	[self setFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorFont]]];
#endif

	// Set self as delegate for the textView's textStorage to enable syntax highlighting,
	[[self textStorage] setDelegate:self];

	// Set defaults for general usage
	autoindentEnabled = NO;
	autopairEnabled = YES;
	autoindentIgnoresEnter = NO;
	autouppercaseKeywordsEnabled = NO;
#ifndef SP_CODA
	autohelpEnabled = NO;
#endif
	delBackwardsWasPressed = NO;
	startListeningToBoundChanges = NO;
	textBufferSizeIncreased = NO;
	snippetControlCounter = -1;
	mirroredCounter = -1;
	completionPopup = nil;
	completionIsOpen = NO;
	isProcessingMirroredSnippets = NO;
	completionWasRefreshed = NO;

	lineNumberView = [[NoodleLineNumberView alloc] initWithScrollView:scrollView];
	[scrollView setVerticalRulerView:lineNumberView];
	[scrollView setHasHorizontalRuler:NO];
	[scrollView setHasVerticalRuler:YES];
	[scrollView setRulersVisible:YES];
	[self setAllowsDocumentBackgroundColorChange:YES];
	[self setContinuousSpellCheckingEnabled:NO];
#ifndef SP_CODA
	[self setAutoindent:[prefs boolForKey:SPCustomQueryAutoIndent]];
#else
	[self setAutoindent:YES];
#endif
	[self setAutoindentIgnoresEnter:YES];
#ifndef SP_CODA
	[self setAutopair:[prefs boolForKey:SPCustomQueryAutoPairCharacters]];
	[self setAutohelp:[prefs boolForKey:SPCustomQueryUpdateAutoHelp]];
	[self setAutouppercaseKeywords:[prefs boolForKey:SPCustomQueryAutoUppercaseKeywords]];
#else
	[self setAutopair:YES]; 
	//[self setAutouppercaseKeywords:YES]; // #18925
#endif
	[self setCompletionWasReinvokedAutomatically:NO];

	// Re-define tab stops for a better editing
	[self setTabStops];

	// disabled to get the current text range in textView safer
	[[self layoutManager] setBackgroundLayoutEnabled:NO];

	// add NSViewBoundsDidChangeNotification to scrollView
	[scrollView setPostsBoundsChangedNotifications:YES];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(boundsDidChangeNotification:) name:NSViewBoundsDidChangeNotification object:[scrollView contentView]];

#ifndef SP_CODA
	{
		struct csItem {
			NSString *p;
			SEL m;
		} colorSetup[] = {
			{ .p = SPCustomQueryEditorHighlightQueryColor, .m = @selector(setQueryHiliteColor:) },
			{ .p = SPCustomQueryEditorBackgroundColor,     .m = @selector(setQueryEditorBackgroundColor:) },
			{ .p = SPCustomQueryEditorBackgroundColor,     .m = @selector(setBackgroundColor:) },
			{ .p = SPCustomQueryEditorCommentColor,        .m = @selector(setCommentColor:) },
			{ .p = SPCustomQueryEditorQuoteColor,          .m = @selector(setQuoteColor:) },
			{ .p = SPCustomQueryEditorSQLKeywordColor,     .m = @selector(setKeywordColor:) },
			{ .p = SPCustomQueryEditorBacktickColor,       .m = @selector(setBacktickColor:) },
			{ .p = SPCustomQueryEditorNumericColor,        .m = @selector(setNumericColor:) },
			{ .p = SPCustomQueryEditorVariableColor,       .m = @selector(setVariableColor:) },
			{ .p = SPCustomQueryEditorTextColor,           .m = @selector(setOtherTextColor:) },
			{ .p = SPCustomQueryEditorTextColor,           .m = @selector(setTextColor:) },
			{ .p = SPCustomQueryEditorCaretColor,          .m = @selector(setInsertionPointColor:) },
			{ .p = SPCustomQueryEditorSelectionColor,      .m = @selector(_setTextSelectionColor:) },
			{ .p = nil, .m = NULL } // stop key
		};
		
		struct csItem *item = &colorSetup[0];
		
		NSDictionary *vendorDefaults = [prefs volatileDomainForName:NSRegistrationDomain]; //prefs from -registerDefaults: in app controller

		do {
			NSData *colorData = [prefs dataForKey:item->p];
			NSColor *color;
			BOOL canRetry = YES;
retry:
			if(colorData && (color = [NSUnarchiver unarchiveObjectWithData:colorData])) {
				[self performSelector:item->m withObject:color];
			}
			else if(canRetry) {
				// #2963: previous versions of SP would accept invalid data (resulting in `nil`) and store it in prefs,
				//        so if loading failed use the default color instead (`nil` would cause exceptions later on)
				colorData = [vendorDefaults objectForKey:item->p];
				canRetry = NO;
				SPLog(@"user defaults contains invalid value for theme color '%@'! (retrying with default value)", item->p);
				goto retry;
			}
		} while((++item)->p);
	}
	
	[self setShouldHiliteQuery:[prefs boolForKey:SPCustomQueryHighlightCurrentQuery]];

	[self setAutomaticDashSubstitutionEnabled:NO];  // prevents -- from becoming —, the em dash.
	[self setAutomaticQuoteSubstitutionEnabled:NO]; // prevents ' and " from becoming ‘, ’ and “, ” respectively.

	// Register observers for the when editor colors preference changes
	[prefs addObserver:self forKeyPath:SPCustomQueryEditorSelectionColor options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:SPCustomQueryEditorCaretColor options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:SPCustomQueryEditorFont options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:SPCustomQueryEditorBackgroundColor options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:SPCustomQueryEditorHighlightQueryColor options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:SPCustomQueryHighlightCurrentQuery options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:SPCustomQueryEditorCommentColor options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:SPCustomQueryEditorQuoteColor options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:SPCustomQueryEditorSQLKeywordColor options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:SPCustomQueryEditorBacktickColor options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:SPCustomQueryEditorNumericColor options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:SPCustomQueryEditorVariableColor options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:SPCustomQueryEditorTextColor options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:SPCustomQueryEditorTabStopWidth options:NSKeyValueObservingOptionNew context:NULL];
	[prefs addObserver:self forKeyPath:SPCustomQueryAutoUppercaseKeywords options:NSKeyValueObservingOptionNew context:NULL];
#else
	[self setQueryHiliteColor:[NSColor whiteColor]];
	[self setQueryEditorBackgroundColor:[NSColor whiteColor]];
	[self setCommentColor:[NSColor darkGrayColor]];
	[self setQuoteColor:[NSColor blueColor]];
	[self setKeywordColor:[NSColor redColor]];
	[self setBacktickColor:[NSColor purpleColor]];
	[self setNumericColor:[NSColor blueColor]];
	[self setVariableColor:[NSColor yellowColor]];
	[self setOtherTextColor:[NSColor blackColor]];
	[self setTextColor:otherTextColor];
	[self setInsertionPointColor:[NSColor blackColor]];
	[self setShouldHiliteQuery:YES];
	[self setSelectedTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSColor lightGrayColor], NSBackgroundColorAttributeName, nil]];

#endif
}

- (void) setConnection:(SPMySQLConnection *)theConnection withVersion:(NSInteger)majorVersion
{
	mySQLConnection = theConnection;
	mySQLmajorVersion = majorVersion;
}

/**
 * This method is called as part of Key Value Observing which is used to watch for prefernce changes which effect the interface.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
#ifndef SP_CODA
	if ([keyPath isEqualToString:SPCustomQueryEditorBackgroundColor]) {
		NSColor *backgroundColor = [NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]];
		[self setQueryEditorBackgroundColor:backgroundColor];
		[self setBackgroundColor:backgroundColor];
		[self _setTextSelectionColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorSelectionColor]] onBackgroundColor:backgroundColor];
		[self setNeedsDisplayInRect:[self bounds]];
	} else if ([keyPath isEqualToString:SPCustomQueryEditorFont]) {
		[self setFont:[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]]];
		[self setNeedsDisplayInRect:[self bounds]];
	} else if ([keyPath isEqualToString:SPCustomQueryEditorHighlightQueryColor]) {
		[self setQueryHiliteColor:[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]]];
		[self setNeedsDisplayInRect:[self bounds]];
	} else if ([keyPath isEqualToString:SPCustomQueryEditorCaretColor]) {
		[self setInsertionPointColor:[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]]];
		[self setNeedsDisplayInRect:[self bounds]];
	} else if ([keyPath isEqualToString:SPCustomQueryEditorSelectionColor]) {
		[self _setTextSelectionColor:[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]] onBackgroundColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorBackgroundColor]]];
		[self setNeedsDisplayInRect:[self bounds]];
	} else if ([keyPath isEqualToString:SPCustomQueryHighlightCurrentQuery]) {
		[self setShouldHiliteQuery:[[change objectForKey:NSKeyValueChangeNewKey] boolValue]];
		[self setNeedsDisplayInRect:[self bounds]];
	} else if ([keyPath isEqualToString:SPCustomQueryEditorCommentColor]) {
		[self setCommentColor:[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]]];
		if([[self string] length]<100000 && [self isEditable])
			[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.1];
	} else if ([keyPath isEqualToString:SPCustomQueryEditorQuoteColor]) {
		[self setQuoteColor:[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]]];
		if([[self string] length]<100000 && [self isEditable])
			[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.1];
	} else if ([keyPath isEqualToString:SPCustomQueryEditorSQLKeywordColor]) {
		[self setKeywordColor:[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]]];
		if([[self string] length]<100000 && [self isEditable])
			[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.1];
	} else if ([keyPath isEqualToString:SPCustomQueryEditorBacktickColor]) {
		[self setBacktickColor:[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]]];
		if([[self string] length]<100000 && [self isEditable])
			[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.1];
	} else if ([keyPath isEqualToString:SPCustomQueryEditorNumericColor]) {
		[self setNumericColor:[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]]];
		if([[self string] length]<100000 && [self isEditable])
			[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.1];
	} else if ([keyPath isEqualToString:SPCustomQueryEditorVariableColor]) {
		[self setVariableColor:[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]]];
		if([[self string] length]<100000 && [self isEditable])
			[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.1];
	} else if ([keyPath isEqualToString:SPCustomQueryEditorTextColor]) {
		[self setOtherTextColor:[NSUnarchiver unarchiveObjectWithData:[change objectForKey:NSKeyValueChangeNewKey]]];
		[self setTextColor:[self otherTextColor]];
		if([[self string] length]<100000 && [self isEditable])
			[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.1];
	} else if ([keyPath isEqualToString:SPCustomQueryEditorTabStopWidth]) {
		[self setTabStops];
	} else if ([keyPath isEqualToString:SPCustomQueryAutoUppercaseKeywords]) {
		[self setAutouppercaseKeywords:[prefs boolForKey:SPCustomQueryAutoUppercaseKeywords]];
	}
#endif
}

/**
 * Return an array of NSDictionary containing the sorted strings representing
 * the set of unique words, SQL keywords, user-defined funcs/procs, tables etc.
 * NSDic key "display" := the displayed and to be inserted word
 * NSDic key "image" := an image to be shown left from "display" (optional)
 *
 * [NSDictionary dictionaryWithObjectsAndKeys:@"foo", @"display", @"`foo`", @"match", @"func-small", @"image", nil]
 */
- (NSArray *)suggestionsForSQLCompletionWith:(NSString *)currentWord dictMode:(BOOL)isDictMode browseMode:(BOOL)dbBrowseMode withTableName:(NSString*)aTableName withDbName:(NSString*)aDbName
{

	NSMutableArray *possibleCompletions = [[NSMutableArray alloc] initWithCapacity:32];
	if(currentWord == nil) currentWord = @"";

	// If caret is not inside backticks add keywords and all words coming from the view.
	if(!dbBrowseMode)
	{
		// Only parse for words if text size is less than 1MB
		if([[self string] length] && [[self string] length]<1000000)
		{
			NSMutableSet *uniqueArray = [NSMutableSet setWithCapacity:5];

			for(id w in [[self textStorage] words])
				if([[w string] hasPrefix:currentWord])
					[uniqueArray addObject:[w string]];

			// Remove current word from list
			[uniqueArray removeObject:currentWord];

			NSInteger reverseSort = NO;

			for(id w in [[uniqueArray allObjects] sortedArrayUsingFunction:_alphabeticSort context:&reverseSort])
				[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:w, @"display", @"dummy-small", @"image", nil]];

		}

		if(!isDictMode) {
			// Add predefined keywords
			NSArray *keywordList = [[NSArray arrayWithArray:[[SPQueryController sharedQueryController] keywordList]] retain];
			for(id s in keywordList)
				[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:s, @"display", @"dummy-small", @"image", nil]];

			// Add predefined functions
			NSArray *functionList = [[NSArray arrayWithArray:[[SPQueryController sharedQueryController] functionList]] retain];
			for(id s in functionList)
				[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:s, @"display", @"func-small", @"image", nil]];

			[functionList release];
			[keywordList release];
		}

	}

	if(!isDictMode && [mySQLConnection isConnected])
	{
		// Add structural db/table/field data to completions list or fallback to gathering SPTablesList data

		NSString* connectionID;
		if(tableDocumentInstance)
			connectionID = [tableDocumentInstance connectionID];
		else
			connectionID = @"_";

		// Try to get structure data
		NSDictionary *dbs = [NSDictionary dictionaryWithDictionary:[[SPNavigatorController sharedNavigatorController] dbStructureForConnection:connectionID]];

		if(dbs != nil && [dbs isKindOfClass:[NSDictionary class]] && [dbs count]) {
			NSMutableArray *allDbs = [NSMutableArray array];
			[allDbs addObjectsFromArray:[dbs allKeys]];

			NSSortDescriptor *desc = [[NSSortDescriptor alloc] initWithKey:nil ascending:YES selector:@selector(localizedCompare:)];
			NSMutableArray *sortedDbs = [NSMutableArray array];
			[sortedDbs addObjectsFromArray:[allDbs sortedArrayUsingDescriptors:@[desc]]];

			NSString *currentDb = nil;
			NSString *currentTable = nil;

			if (tablesListInstance && [tablesListInstance selectedDatabase])
				currentDb = [NSString stringWithFormat:@"%@%@%@", connectionID, SPUniqueSchemaDelimiter, [tablesListInstance selectedDatabase]];
			if (tablesListInstance && [tablesListInstance tableName])
				currentTable = [tablesListInstance tableName];

			// Put current selected db at the top
			if(aTableName == nil && aDbName == nil && [tablesListInstance selectedDatabase]) {
				currentDb = [NSString stringWithFormat:@"%@%@%@", connectionID, SPUniqueSchemaDelimiter, [tablesListInstance selectedDatabase]];
				[sortedDbs removeObject:currentDb];
				[sortedDbs insertObject:currentDb atIndex:0];
			}

			NSString* aTableName_id;
			NSString* aDbName_id = [NSString stringWithFormat:@"%@%@%@", connectionID, SPUniqueSchemaDelimiter, aDbName];
			if(aDbName && aTableName)
				aTableName_id = [NSString stringWithFormat:@"%@%@%@", aDbName_id, SPUniqueSchemaDelimiter, aTableName];
			else
				aTableName_id = [NSString stringWithFormat:@"%@%@%@", currentDb, SPUniqueSchemaDelimiter, aTableName];


			// Put information_schema and/or mysql db at the end if not selected
			// 5.5.3+ also has performance_schema
			NSString* mysql_id = [NSString stringWithFormat:@"%@%@%@", connectionID, SPUniqueSchemaDelimiter, SPMySQLDatabase];
			NSString* inf_id   = [NSString stringWithFormat:@"%@%@%@", connectionID, SPUniqueSchemaDelimiter, SPMySQLInformationSchemaDatabase];
			NSString* perf_id  = [NSString stringWithFormat:@"%@%@%@", connectionID, SPUniqueSchemaDelimiter, SPMySQLPerformanceSchemaDatabase];
			
			if(currentDb && ![currentDb isEqualToString:mysql_id] && [sortedDbs containsObject:mysql_id]) {
				[sortedDbs removeObject:mysql_id];
				[sortedDbs addObject:mysql_id];
			}
			if(currentDb && ![currentDb isEqualToString:inf_id] && [sortedDbs containsObject:inf_id]) {
				[sortedDbs removeObject:inf_id];
				[sortedDbs addObject:inf_id];
			}
			if(currentDb && ![currentDb isEqualToString:perf_id] && [sortedDbs containsObject:perf_id]) {
				[sortedDbs removeObject:perf_id];
				[sortedDbs addObject:perf_id];
			}

			BOOL aTableNameExists = NO;
			if(!aDbName) {

				// Try to suggest only items which are uniquely valid for the parsed string
				NSArray *uniqueSchema = [[SPNavigatorController sharedNavigatorController] getUniqueDbIdentifierFor:[aTableName lowercaseString] andConnection:[[(NSObject*)[self delegate] valueForKeyPath:@"tableDocumentInstance"] connectionID]  ignoreFields:YES];
				NSInteger uniqueSchemaKind = [[uniqueSchema objectAtIndex:0] intValue];

				// If no db name but table name check if table name is a valid name in the current selected db
			 	if(uniqueSchemaKind == 2 && aTableName && [aTableName length] 
						&& [dbs objectForKey:currentDb] && [[dbs objectForKey:currentDb] isKindOfClass:[NSDictionary class]]
						&& [[dbs objectForKey:currentDb] objectForKey:[NSString stringWithFormat:@"%@%@%@", currentDb, SPUniqueSchemaDelimiter, [uniqueSchema objectAtIndex:1]]] )
				{
					aTableNameExists = YES;
					aTableName = [uniqueSchema objectAtIndex:1];
					aTableName_id = [NSString stringWithFormat:@"%@%@%@", currentDb, SPUniqueSchemaDelimiter, aTableName];
					aDbName_id = [NSString stringWithString:currentDb];
				}

				// If no db name but table name check if table name is a valid db name
				if(uniqueSchemaKind == 1 && !aTableNameExists && aTableName && [aTableName length]) {
					aDbName_id = [NSString stringWithFormat:@"%@%@%@", connectionID, SPUniqueSchemaDelimiter, [uniqueSchema objectAtIndex:1]];
					aTableNameExists = NO;
				}

			} else if (aDbName && [aDbName length]) {
				if(aTableName && [aTableName length] 
						&& [dbs objectForKey:aDbName_id]  && [[dbs objectForKey:aDbName_id] isKindOfClass:[NSDictionary class]]
						&& [[dbs objectForKey:aDbName_id] objectForKey:[NSString stringWithFormat:@"%@%@%@", aDbName_id, SPUniqueSchemaDelimiter, aTableName]]) {
					aTableNameExists = YES;
				}
			}

			// If aDbName exist show only those table
			if([allDbs containsObject:aDbName_id]) {
				[sortedDbs removeAllObjects];
				[sortedDbs addObject:aDbName_id];
			}

			for(id db in sortedDbs) {

				NSArray *allTables;
				if([[dbs objectForKey:db] isKindOfClass:[NSDictionary class]])
					allTables = [[dbs objectForKey:db] allKeys];
				else {
					[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:[[[[dbs objectForKey:db] description] componentsSeparatedByString:SPUniqueSchemaDelimiter] lastObject], @"display", @"database-small", @"image", @"", @"isRef", nil]];
					continue;
				}

				NSMutableArray *sortedTables = [NSMutableArray array];
				if(aTableNameExists) {
					[sortedTables addObject:aTableName_id];
				} else {
					[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:[[db componentsSeparatedByString:SPUniqueSchemaDelimiter] lastObject], @"display", @"database-small", @"image", @"", @"isRef", nil]];
					[sortedTables addObjectsFromArray:[allTables sortedArrayUsingDescriptors:@[desc]]];
					if([sortedTables count] > 1 && [sortedTables containsObject:[NSString stringWithFormat:@"%@%@%@", db, SPUniqueSchemaDelimiter, currentTable]]) {
						[sortedTables removeObject:[NSString stringWithFormat:@"%@%@%@", db, SPUniqueSchemaDelimiter, currentTable]];
						[sortedTables insertObject:[NSString stringWithFormat:@"%@%@%@", db, SPUniqueSchemaDelimiter, currentTable] atIndex:0];
					}
				}
				for(id table in sortedTables) {
					NSDictionary *theTable = [[dbs objectForKey:db] objectForKey:table];
					NSString *tablepath = [table substringFromIndex:[table rangeOfString:SPUniqueSchemaDelimiter].location];
					NSArray *allFields = [theTable allKeys];
					SPTableType structtype = (SPTableType)[[theTable objectForKey:@"  struct_type  "] intValue];
					BOOL breakFlag = NO;
					if(!aTableNameExists)
						switch(structtype) {
							case SPTableTypeTable:
								[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:[[table componentsSeparatedByString:SPUniqueSchemaDelimiter] lastObject], @"display", @"table-small-square", @"image", tablepath, @"path", @"", @"isRef", nil]];
								break;
							case SPTableTypeView:
								[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:[[table componentsSeparatedByString:SPUniqueSchemaDelimiter] lastObject], @"display", @"table-view-small-square", @"image", tablepath, @"path", @"", @"isRef", nil]];
								break;
							case SPTableTypeProc:
								[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:[[table componentsSeparatedByString:SPUniqueSchemaDelimiter] lastObject], @"display", @"proc-small", @"image", tablepath, @"path", @"", @"isRef", nil]];
								breakFlag = YES;
								break;
							case SPTableTypeFunc:
								[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:[[table componentsSeparatedByString:SPUniqueSchemaDelimiter] lastObject], @"display", @"func-small", @"image", tablepath, @"path", @"", @"isRef", nil]];
								breakFlag = YES;
								break;
							default:
								break;
						}
					if(!breakFlag) {
						NSArray *sortedFields = [allFields sortedArrayUsingDescriptors:@[desc]];
						for(id field in sortedFields) {
							if(![field hasPrefix:@"  "]) {
								NSString *fieldpath = [field substringFromIndex:[field rangeOfString:SPUniqueSchemaDelimiter].location];
								NSArray *def = [theTable objectForKey:field];
								NSString *typ = [NSString stringWithFormat:@"%@ %@ %@", [def objectAtIndex:0], [def objectAtIndex:3], [def objectAtIndex:5]];
								// Check if type definition contains a , if so replace the bracket content by … and add 
								// the bracket content as "list" key to prevend the token field to split them by ,
								if(typ && [typ rangeOfString:@","].length) {
									NSString *t = [typ stringByReplacingOccurrencesOfRegex:@"\\(.*?\\)" withString:@"(…)"];
									NSString *lst = [typ stringByMatching:@"\\(([^\\)]*?)\\)" capture:1L];
									[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
										[[field componentsSeparatedByString:SPUniqueSchemaDelimiter] lastObject], @"display", 
										@"field-small-square", @"image", 
										fieldpath, @"path", 
										t, @"type", 
										lst, @"list", 
										@"", @"isRef", 
										nil]];
								} else {
									[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
										[[field componentsSeparatedByString:SPUniqueSchemaDelimiter] lastObject], @"display", 
										@"field-small-square", @"image", 
										fieldpath, @"path",
										typ, @"type", 
										@"", @"isRef", 
										nil]];
								}
							}
						}
					}
				}
			}
			if(desc) [desc release];
		} else {

			// [possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"fetching table data…", @"fetching table data for completion in progress message"), @"path", @"", @"noCompletion", nil]];

			// Add all database names to completions list
			for (id obj in [tablesListInstance allDatabaseNames])
				[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:obj, @"display", @"database-small", @"image", @"", @"isRef", nil]];

			// Add all system database names to completions list
			for (id obj in [tablesListInstance allSystemDatabaseNames])
				[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:obj, @"display", @"database-small", @"image", @"", @"isRef", nil]];

			// Add table names to completions list
			for (id obj in [tablesListInstance allTableNames])
				[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:obj, @"display", @"table-small-square", @"image", @"", @"isRef", nil]];

			// Add view names to completions list
			for (id obj in [tablesListInstance allViewNames])
				[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:obj, @"display", @"table-view-small-square", @"image", @"", @"isRef", nil]];

#warning Private ivar accessed from outside (#2978)
			// Add field names to completions list for currently selected table
			if ([tableDocumentInstance table] != nil)
				for (id obj in [[tableDocumentInstance valueForKeyPath:@"tableDataInstance"] valueForKey:@"columnNames"])
					[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:obj, @"display", @"field-small-square", @"image", @"", @"isRef", nil]];

			// Add proc/func only for MySQL version 5 or higher
			if(mySQLmajorVersion > 4) {
				// Add all procedures to completions list for currently selected table
				for (id obj in [tablesListInstance allProcedureNames])
					[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:obj, @"display", @"proc-small", @"image", @"", @"isRef", nil]];

				// Add all function to completions list for currently selected table
				for (id obj in [tablesListInstance allFunctionNames])
					[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:obj, @"display", @"func-small", @"image", @"", @"isRef", nil]];
			}
		}
	}

	return [possibleCompletions autorelease];

}

- (void) doAutoCompletion
{
	if(completionIsOpen || !self || ![self delegate]) return;

	// Cancel autocompletion trigger
#ifndef SP_CODA
	if([prefs boolForKey:SPCustomQueryAutoComplete])
#endif
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
								selector:@selector(doAutoCompletion) 
								object:nil];


	NSRange r = [self selectedRange];

	if(![self delegate] || ![[self delegate] isKindOfClass:[SPCustomQuery class]] || r.length || snippetControlCounter > -1) return;

	if(r.location) {
		NSCharacterSet *ignoreCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"\"'`;,()[]{}=+/<> \t\n\r"];

		// Check the previous character and don't autocomplete if the character is whitespace or certain types of punctuation
		if ([ignoreCharacterSet characterIsMember:[[self string] characterAtIndex:r.location - 1]]) return;

		// Suppress auto-completion if the window isn't active anymore
		if ([[NSApp keyWindow] firstResponder] != self) return;

		BOOL useSpellChecker = NO;

		// Check if caret is inside a quote to auto-complete by using spellChecker
		if([(NSString*)NSMutableAttributedStringAttributeAtIndex([self textStorage], kQuote, (r.location-1), nil) length])
			useSpellChecker = YES;

		// Trigger the completion
		[self doCompletionByUsingSpellChecker:useSpellChecker fuzzyMode:NO autoCompleteMode:YES];
	}

}

- (void) refreshCompletion
{
	if(completionWasRefreshed) return;
	completionWasRefreshed = YES;
	[self doCompletionByUsingSpellChecker:NO fuzzyMode:completionFuzzyMode autoCompleteMode:NO];
}

- (void) doCompletionByUsingSpellChecker:(BOOL)isDictMode fuzzyMode:(BOOL)fuzzySearch autoCompleteMode:(BOOL)autoCompleteMode
{

	// Cancel autocompletion trigger
#ifndef SP_CODA
	if([prefs boolForKey:SPCustomQueryAutoComplete])
#endif
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
								selector:@selector(doAutoCompletion) 
								object:nil];

	if(![self isEditable] || (completionIsOpen && !completionWasReinvokedAutomatically)) {
		return;
	}

	[self breakUndoCoalescing];
	
	// Remember state for refreshCompletion
	completionFuzzyMode = fuzzySearch;

	NSUInteger caretPos = NSMaxRange([self selectedRange]);

	BOOL caretMovedLeft = NO;

	// Check if caret is located after a ` - if so move caret inside
	if(!autoCompleteMode && [[self string] length] && caretPos > 0 && [[self string] characterAtIndex:caretPos-1] == '`') {
		if([[self string] length] > caretPos && [[self string] characterAtIndex:caretPos] == '`') {
			;
		} else {
			caretPos--;
			caretMovedLeft = YES;
			[self setSelectedRange:NSMakeRange(caretPos, 0)];
		}
	}

	NSString* filter;
	NSString* dbName        = nil;
	NSString* tableName     = nil;
	NSRange completionRange = [self getRangeForCurrentWord];
	NSRange parseRange      = completionRange;
	NSString* currentWord   = [[self string] substringWithRange:completionRange];
	NSString* prefix        = @"";
	NSString *currentDb     = nil;

	// Break for long stuff
	if(completionRange.length>100000) return;

	NSString* allow; // additional chars which won't close the suggestion list window
	if(isDictMode)
		allow= @"_";
	else
		allow= @"_. ";

	BOOL dbBrowseMode = NO;
	NSInteger backtickMode = 0; // 0 none, 1 rigth only, 2 left only, 3 both
	BOOL caseInsensitive = YES;

	// Remove that attribute to suppress auto-uppercasing of certain keyword combinations
	if(![self selectedRange].length && [self selectedRange].location)
		[[self textStorage] removeAttribute:kSQLkeyword range:completionRange];

	[self setSelectedRange:NSMakeRange(caretPos, 0)];

	if(!isDictMode) {

		// Parse for leading db.table.field infos

		if(tablesListInstance && [tablesListInstance selectedDatabase])
			currentDb = [tablesListInstance selectedDatabase];
		else
			currentDb = @"";
		
		BOOL caretIsInsideBackticks = NO;

		// Is the caret inside backticks
		// Do not using attribute:atIndex: since it could return wrong results due to editing.
		// This approach counts the number of ` up to the beginning of the current line from caret position
		NSRange lineHeadRange = [[self string] lineRangeForRange:NSMakeRange(caretPos, 0)];
		NSString *lineHead = [[self string] substringWithRange:NSMakeRange(lineHeadRange.location, caretPos - lineHeadRange.location)];
		for(NSUInteger i=0; i<[lineHead length]; i++)
			if([lineHead characterAtIndex:i]=='`') caretIsInsideBackticks = !caretIsInsideBackticks;
			
		NSMutableCharacterSet *breakCharSet = [NSMutableCharacterSet characterSetWithCharactersInString:@",;(+=-*/%><~&|^"];
		[breakCharSet formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
		NSUInteger start = caretPos;
		NSInteger backticksCounter = (caretIsInsideBackticks) ? 1 : 0;
		NSInteger pointCounter     = 0;
		NSInteger firstPoint       = 0;
		NSInteger secondPoint      = 0;
		BOOL rightBacktick         = NO;
		BOOL leftBacktick          = NO;
		BOOL doParsing             = YES;

		unichar currentCharacter;

		while(start > 0 && doParsing) {
			currentCharacter = [[self string] characterAtIndex:--start];
			if(!(backticksCounter%2) && [breakCharSet characterIsMember:currentCharacter]) {
				start++;
				break;
			}
			if(currentCharacter == '.' && !(backticksCounter%2)) {
				pointCounter++;
				switch(pointCounter) {
					case 1:
					firstPoint = start;
					break;
					case 2:
					secondPoint = start;
					break;
					default:
					doParsing = NO;
					start++;
				}
			}
			if(doParsing && currentCharacter == '`') {
				backticksCounter++;
				if(!(backticksCounter%2) && start > 0) {
					currentCharacter = [[self string] characterAtIndex:start-1];
					if(currentCharacter != '`' && currentCharacter != '.') break;
					if(currentCharacter == '`') { // ignore `` 
						backticksCounter++;
						start--;
					}
				}
			}
		}

		dbBrowseMode = (pointCounter || backticksCounter);

		if(dbBrowseMode) {
			parseRange = NSMakeRange(start, caretPos-start);

			// Break for long stuff
			if(parseRange.length>100000) return;

			NSString *parsedString = [[self string] substringWithRange:parseRange];

			// Check if parsed string is wrapped by ``
			if([parsedString hasPrefix:@"`"]) {
				backtickMode+=1;
				leftBacktick = YES;
			}
			if([[self string] length] > NSMaxRange(parseRange)) {
				if([[self string] characterAtIndex:NSMaxRange(parseRange)] == '`') {
					backtickMode+=2;
					parseRange.length++; // adjust parse string for right `
					rightBacktick = YES;
				}
			}

			// Normalize point positions
			firstPoint-=start;
			secondPoint-=start;

			if(secondPoint>0) {
				dbName = [[[parsedString substringWithRange:NSMakeRange(0, secondPoint)] stringByReplacingOccurrencesOfString:@"``" withString:@"`"] stringByReplacingOccurrencesOfRegex:@"^`|`$" withString:@""];
				tableName = [[[parsedString substringWithRange:NSMakeRange(secondPoint+1,firstPoint-secondPoint-1)] stringByReplacingOccurrencesOfString:@"``" withString:@"`"] stringByReplacingOccurrencesOfRegex:@"^`|`$" withString:@""];
				filter = [[[parsedString substringWithRange:NSMakeRange(firstPoint+1,[parsedString length]-firstPoint-1)] stringByReplacingOccurrencesOfString:@"``" withString:@"`"] stringByReplacingOccurrencesOfRegex:@"^`|`$" withString:@""];
			} else if(firstPoint>0) {
				tableName = [[[parsedString substringWithRange:NSMakeRange(0, firstPoint)] stringByReplacingOccurrencesOfString:@"``" withString:@"`"] stringByReplacingOccurrencesOfRegex:@"^`|`$" withString:@""];
				filter = [[[parsedString substringWithRange:NSMakeRange(firstPoint+1,[parsedString length]-firstPoint-1)] stringByReplacingOccurrencesOfString:@"``" withString:@"`"] stringByReplacingOccurrencesOfRegex:@"^`|`$" withString:@""];
			} else {
				filter = [[parsedString stringByReplacingOccurrencesOfString:@"``" withString:@"`"] stringByReplacingOccurrencesOfRegex:@"^`|`$" withString:@""];
			}

			// Adjust completion range
			if(firstPoint>0) {
				completionRange = NSMakeRange(firstPoint+1+start,[parsedString length]-firstPoint-1);
			} 
			else if([filter length] && leftBacktick) {
				completionRange = NSMakeRange(completionRange.location-1,completionRange.length+1);
			}
			if(rightBacktick)
				completionRange.length++;

			// Check leading . since .tableName == <currentDB>.tableName etc.
			if([filter hasPrefix:@".`"]) {
				filter = [filter substringFromIndex:2];
				completionRange = NSMakeRange(completionRange.location-1,completionRange.length+1);
			} else if([filter hasPrefix:@"."]) {
				filter = [filter substringFromIndex:1];
			} else if([tableName hasPrefix:@".`"]) {
				tableName = [tableName substringFromIndex:2];
			}

			if(fuzzySearch) {
				filter = [[NSString stringWithString:[[self string] substringWithRange:parseRange]] stringByReplacingOccurrencesOfString:@"`" withString:@""];
				completionRange = parseRange;
			}

		} else {
			filter = [NSString stringWithString:currentWord];
		}
	} else {
		filter = [NSString stringWithString:currentWord];
	}

	// Cancel autocompletion trigger again if user typed something in while parsing
#ifndef SP_CODA
	if([prefs boolForKey:SPCustomQueryAutoComplete])
#endif
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
								selector:@selector(doAutoCompletion) 
								object:nil];

	// Check for table name aliases
	NSString *alias = nil;
	if(dbBrowseMode && tableDocumentInstance && customQueryInstance) {
		NSString *theDb = (dbName == nil) ? [NSString stringWithString:currentDb] : [NSString stringWithString:dbName];
		NSString *connectionID = [tableDocumentInstance connectionID];
		NSString *conID = [NSString stringWithFormat:@"%@%@%@", connectionID, SPUniqueSchemaDelimiter, theDb];
		NSDictionary *dbs = [NSDictionary dictionaryWithDictionary:[[[tableDocumentInstance databaseStructureRetrieval] structure] objectForKey:connectionID]];
		if(theDb && dbs != nil && [dbs count] && [dbs objectForKey:conID] && [[dbs objectForKey:conID] isKindOfClass:[NSDictionary class]]) {
			NSArray *allTables = [[dbs objectForKey:conID] allKeys];
			// Check if found table name is known, if not parse for aliases
			if(![allTables containsObject:[NSString stringWithFormat:@"%@%@%@", conID, SPUniqueSchemaDelimiter, tableName]]) {
				NSString *currentQuery = [[self string] substringWithRange:[customQueryInstance currentQueryRange]];
				NSString *re = [NSString stringWithFormat:@"(?i)[\\s,]`?(\\S+?)`?\\s+(AS\\s+)?`?%@`?\\b", tableName];
				NSArray *matches = [currentQuery componentsMatchedByRegex:re];
				for(NSString* m in matches) {
					NSRange aliasRange = [m rangeOfRegex:re capture:1L];
					if(aliasRange.length) {
						alias = [[m substringWithRange:aliasRange] stringByReplacingOccurrencesOfString:@"``" withString:@"`"];
						// If alias refers to db.table split and check it
						if([alias rangeOfString:@"."].length) {
							NSRange dbRange = [alias rangeOfRegex:@"^`?(.*?)`?\\." capture:1L];
							NSRange tbRange = [alias rangeOfRegex:@"\\.`?(.*?)`?$" capture:1L];
							NSString *db = [[alias substringWithRange:dbRange] stringByReplacingOccurrencesOfString:@"``" withString:@"`"];
							NSString *tb = [[alias substringWithRange:tbRange] stringByReplacingOccurrencesOfString:@"``" withString:@"`"];
							NSString *curConID = [NSString stringWithFormat:@"%@%@%@", connectionID, SPUniqueSchemaDelimiter, db];
							if([dbs objectForKey:curConID] && [[dbs objectForKey:curConID] isKindOfClass:[NSDictionary class]]) {
								allTables = [[dbs objectForKey:curConID] allKeys];
								if([allTables containsObject:[NSString stringWithFormat:@"%@%@%@", curConID, SPUniqueSchemaDelimiter, tb]]) {
									tableName = tb;
									dbName = db;
									break;
								}
							}
						} else {
							if([allTables containsObject:[NSString stringWithFormat:@"%@%@%@", conID, SPUniqueSchemaDelimiter, alias]]) {
								tableName = alias;
								break;
							}
						}
					}
				}
			}
		}
	}

	if (completionIsOpen) [completionPopup close], completionPopup = nil;

	completionIsOpen = YES;
	completionPopup = [[SPNarrowDownCompletion alloc] initWithItems:[self suggestionsForSQLCompletionWith:currentWord dictMode:isDictMode browseMode:dbBrowseMode withTableName:tableName withDbName:dbName]
	                                                   alreadyTyped:filter
	                                                   staticPrefix:prefix
	                                       additionalWordCharacters:allow
	                                                  caseSensitive:!caseInsensitive
	                                                      charRange:completionRange
	                                                     parseRange:parseRange
	                                                         inView:self
	                                                       dictMode:isDictMode
	                                                 tabTriggerMode:[self isSnippetMode]
	                                                    fuzzySearch:fuzzySearch
	                                                   backtickMode:backtickMode
	                                                     selectedDb:currentDb
	                                                 caretMovedLeft:caretMovedLeft
	                                                   autoComplete:autoCompleteMode
	                                                      oneColumn:isDictMode
	                                                          alias:alias
	                                       withDBStructureRetriever:[tableDocumentInstance databaseStructureRetrieval]];

	completionParseRangeLocation = parseRange.location;

	[self _positionCompletionPopup:completionPopup relativeToTextAtLocation:completionRange.location];

	[completionPopup orderFront:self];
	[completionPopup insertAutocompletePlaceholder];
}


/**
 * Returns the associated line number for a character position inside of the SPTextView
 */
- (NSUInteger) getLineNumberForCharacterIndex:(NSUInteger)anIndex
{
	return [lineNumberView lineNumberForCharacterIndex:anIndex]+1;
}

/**
 * Checks if the char after the current caret position/selection matches a supplied attribute
 */
- (BOOL) isNextCharMarkedBy:(id)attribute withValue:(id)aValue
{
	NSUInteger caretPosition = [self selectedRange].location;

	// Perform bounds checking
	if (caretPosition >= [[self string] length]) return NO;
	
	// Perform the check
	if ([[[self textStorage] attribute:attribute atIndex:caretPosition effectiveRange:nil] isEqualToString:aValue])
		return YES;

	return NO;
}

/**
 * Checks if the caret adjoins to an alphanumeric char  |word or word| or wo|rd
 * Exception for word| and char is a “(” to allow e.g. auto-pairing () for functions
 */
- (BOOL) isCaretAdjacentToAlphanumCharWithInsertionOf:(unichar)aChar
{
	NSUInteger caretPosition = [self selectedRange].location;
	NSCharacterSet *alphanum = [NSCharacterSet alphanumericCharacterSet];
	BOOL leftIsAlphanum = NO;
	BOOL rightIsAlphanum = NO;
	BOOL charIsOpenBracket = (aChar == '(');
	NSUInteger bufferLength = [[self string] length];

	if(!bufferLength) return NO;
	
	// Check previous/next character for being alphanum
	// @try block for bounds checking
	@try
	{
		if(caretPosition==0)
			leftIsAlphanum = NO;
		else
			leftIsAlphanum = [alphanum characterIsMember:[[self string] characterAtIndex:caretPosition-1]] && !charIsOpenBracket;
	} @catch(id ae) { }
	@try {
		if(caretPosition >= bufferLength)
			rightIsAlphanum = NO;
		else
			rightIsAlphanum= [alphanum characterIsMember:[[self string] characterAtIndex:caretPosition]];
		
	} @catch(id ae) { }

	return (leftIsAlphanum ^ rightIsAlphanum || (leftIsAlphanum && rightIsAlphanum));
}

/**
 * Checks if all the characters left from the caret are white spaces or caret is at the line begin.
 */
- (BOOL) isCaretAtIndentPositionIgnoreLineStart:(BOOL)ignoreLineStart
{
	NSString *textViewString = [[self textStorage] string];
	NSUInteger caretPosition = [self selectedRange].location;
	NSUInteger currentLineStartPosition = [textViewString lineRangeForRange:NSMakeRange(caretPosition, 0)].location;

	// Check if caret is at the beginning of a line
	// - used for deleteBackward: to allow to delete leading \n
	if(!ignoreLineStart && caretPosition == currentLineStartPosition)
		return NO;

	NSString *lineHeadToCaret = [textViewString substringWithRange:NSMakeRange(currentLineStartPosition, caretPosition-currentLineStartPosition)];
	return (![lineHeadToCaret length] || [lineHeadToCaret isMatchedByRegex:@"^\\s+$"]);
}

/**
 * Checks if the caret is wrapped by auto-paired characters.
 * e.g. [| := caret]: "|" 
 */
- (BOOL) areAdjacentCharsLinked
{
	NSUInteger caretPosition = [self selectedRange].location;
	unichar leftChar, matchingChar;

	// Perform bounds checking
	if ([self selectedRange].length) return NO;
	if (caretPosition < 1) return NO;
	if (caretPosition >= [[self string] length]) return NO;

	// Check the character to the left of the cursor and set the pairing character if appropriate
	leftChar = [[self string] characterAtIndex:caretPosition - 1];
	if (leftChar == '(')
		matchingChar = ')';
	else if (leftChar == '"' || leftChar == '`' || leftChar == '\'')
		matchingChar = leftChar;
	else if (leftChar == '{')
		matchingChar = '}';
	else
		return NO;

	// Check that the pairing character exists after the caret, and is tagged with the link attribute
	if (matchingChar == [[self string] characterAtIndex:caretPosition]
		&& [[[self textStorage] attribute:kAPlinked atIndex:caretPosition effectiveRange:nil] isEqualToString:kAPval]) {
		return YES;
	}

	return NO;
}

#pragma mark -
#pragma mark user actions

- (IBAction)printDocument:(id)sender
{

	// If Extended Table Info tab is active delegate the print call to the SPDatabaseDocument
	// if the user doesn't select anything in self
	if([[[[self delegate] class] description] isEqualToString:@"SPExtendedTableInfo"] && ![self selectedRange].length) {
		[[(NSObject*)[self delegate] valueForKeyPath:@"tableDocumentInstance"] printDocument:sender];
		return;
	}

	// This will scale the view to fit the page without centering it.
	[[NSPrintInfo sharedPrintInfo] setHorizontalPagination:NSFitPagination];
	[[NSPrintInfo sharedPrintInfo] setHorizontallyCentered:NO];
	[[NSPrintInfo sharedPrintInfo] setVerticallyCentered:NO];

	NSRange r = NSMakeRange(0, [[self string] length]);

	// Remove all colors before printing for large text buffer
	if(r.length > SP_TEXT_SIZE_TRIGGER_FOR_PARTLY_PARSING) {
		// Cancel all doSyntaxHighlighting requests
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
									selector:@selector(doSyntaxHighlighting) 
									object:nil];
		[[self textStorage] removeAttribute:NSForegroundColorAttributeName range:r];
		[[self textStorage] removeAttribute:kLEXToken range:r];
		[[self textStorage] ensureAttributesAreFixedInRange:r];

	}
	[[self textStorage] ensureAttributesAreFixedInRange:r];

	// Setup the print operation with the print info and view
	NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:self printInfo:[NSPrintInfo sharedPrintInfo]];

	// Order out print sheet
	[printOperation runOperationModalForWindow:[self window] delegate:nil didRunSelector:NULL contextInfo:NULL];

}

- (void)printOperationDidRun:(NSPrintOperation *)printOperation  success:(BOOL)success  contextInfo:(void *)contextInfo
{
	// Refresh syntax highlighting
	[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.01];
}

#ifndef SP_CODA
/**
 * Search for the current selection or current word in the MySQL Help 
 */
- (IBAction) showMySQLHelpForCurrentWord:(id)sender
{
	[[tableDocumentInstance helpViewerClient] showHelpForCurrentWord:self];
}
#endif

/**
 * If the textview has a selection, wrap it with the supplied prefix and suffix strings;
 * return whether or not any wrap was performed.
 */
- (BOOL) wrapSelectionWithPrefix:(NSString *)prefix suffix:(NSString *)suffix
{

	NSRange currentRange = [self selectedRange];

	// Only proceed if a selection is active
	if (currentRange.length == 0 || ![self isEditable])
		return NO;

	NSString *selString = [[self string] substringWithRange:currentRange];

	// Replace the current selection with the selected string wrapped in prefix and suffix
	[self insertText:[NSString stringWithFormat:@"%@%@%@", prefix, selString, suffix]];
	
	// Re-select original selection
	NSRange innerSelectionRange = NSMakeRange(currentRange.location+1, [selString length]);
	[self setSelectedRange:innerSelectionRange];

	// If autopair is enabled mark last autopair character as autopair-linked
#ifndef SP_CODA
	if([prefs boolForKey:SPCustomQueryAutoPairCharacters])
#endif
		[[self textStorage] addAttribute:kAPlinked value:kAPval range:NSMakeRange(NSMaxRange(innerSelectionRange), 1)];

	return YES;
}

/**
 * Copy selected text chunk as RTF to preserve syntax highlighting
 */
- (void) copyAsRTF
{

	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	NSTextStorage *textStorage = [self textStorage];
	NSData *rtf = [textStorage RTFFromRange:[self selectedRange] documentAttributes:@{}];
	
	if (rtf)
	{
		[pb declareTypes:@[NSRTFPboardType] owner:self];
		[pb setData:rtf forType:NSRTFPboardType];
	}
}

- (IBAction) selectCurrentQuery:(id)sender
{
	if([self isEditable])
		[customQueryInstance selectCurrentQuery];
}

/**
 * Selects the line lineNumber relatively to a selection (if given) and scrolls to it
 */
- (void) selectLineNumber:(NSUInteger)lineNumber ignoreLeadingNewLines:(BOOL)ignLeadingNewLines
{
	NSRange selRange;
	NSArray *lineRanges;
	if([self selectedRange].length)
		lineRanges = [[[self string] substringWithRange:[self selectedRange]] lineRangesForRange:NSMakeRange(0, [self selectedRange].length)];
	else
		lineRanges = [[self string] lineRangesForRange:NSMakeRange(0, [[self string] length])];

	if(ignLeadingNewLines) // ignore leading empty lines
	{
		NSUInteger arrayCount = [lineRanges count];
		NSUInteger i;
		for (i = 0; i < arrayCount; i++) {
			if(NSRangeFromString([lineRanges objectAtIndex:i]).length > 0)
				break;
			lineNumber++;
		}
	}

	// Safety-check the line number
	if (lineNumber > [lineRanges count]) lineNumber = [lineRanges count];
	if (lineNumber < 1) lineNumber = 1;

	// Grab the range to select
	selRange = NSRangeFromString([lineRanges objectAtIndex:lineNumber-1]);

	// adjust selRange if a selection was given
	if([self selectedRange].length)
		selRange.location += [self selectedRange].location;
	[self setSelectedRange:selRange];
	[self scrollRangeToVisible:selRange];
}

/**
 * Shifts the selection, if any, rightwards by indenting any selected lines with one tab.
 * If the caret is within a line, the selection is not changed after the index; if the selection
 * has length, all lines crossed by the length are indented and fully selected.
 * Returns whether or not an indentation was performed.
 */
- (BOOL) shiftSelectionRight
{
	NSString *textViewString = [[self textStorage] string];
	NSRange currentLineRange;
	NSRange selectedRange = [self selectedRange];

	if (selectedRange.location == NSNotFound || ![self isEditable]) return NO;

	NSString *indentString = @"\t";
#ifndef SP_CODA
	if ([prefs boolForKey:SPCustomQuerySoftIndent]) {
		NSUInteger numberOfSpaces = [prefs integerForKey:SPCustomQuerySoftIndentWidth];
		if(numberOfSpaces < 1) numberOfSpaces = 1;
		if(numberOfSpaces > 32) numberOfSpaces = 32;
		NSMutableString *spaces = [NSMutableString string];
		for(NSUInteger i = 0; i < numberOfSpaces; i++)
			[spaces appendString:@" "];
		indentString = [NSString stringWithString:spaces];
	}
#endif

	// Indent the currently selected line if the caret is within a single line
	if (selectedRange.length == 0) {

		// Extract the current line range based on the text caret
		currentLineRange = [textViewString lineRangeForRange:selectedRange];

		// Register the indent for undo
		[self shouldChangeTextInRange:NSMakeRange(currentLineRange.location, 0) replacementString:indentString];

		// Insert the new tab
		[self replaceCharactersInRange:NSMakeRange(currentLineRange.location, 0) withString:indentString];

		return YES;
	}

	// Otherwise, something is selected
	NSRange firstLineRange = [textViewString lineRangeForRange:NSMakeRange(selectedRange.location,0)];
	NSUInteger lastLineMaxRange = NSMaxRange([textViewString lineRangeForRange:NSMakeRange(NSMaxRange(selectedRange)-1,0)]);
	
	// Expand selection for first and last line to begin and end resp. but not the last line ending
	NSRange blockRange = NSMakeRange(firstLineRange.location, lastLineMaxRange - firstLineRange.location);
	if([textViewString characterAtIndex:NSMaxRange(blockRange)-1] == '\n' || [textViewString characterAtIndex:NSMaxRange(blockRange)-1] == '\r')
		blockRange.length--;

	// Replace \n by \n\t of all lines in blockRange
	NSString *newString;
	// check for line ending
	if([textViewString characterAtIndex:NSMaxRange(firstLineRange)-1] == '\r')
		newString = [indentString stringByAppendingString:
			[[textViewString substringWithRange:blockRange] 
				stringByReplacingOccurrencesOfString:@"\r" withString:[NSString stringWithFormat:@"\r%@", indentString]]];
	else
		newString = [indentString stringByAppendingString:
			[[textViewString substringWithRange:blockRange] 
				stringByReplacingOccurrencesOfString:@"\n" withString:[NSString stringWithFormat:@"\n%@", indentString]]];

	// Register the indent for undo
	[self shouldChangeTextInRange:blockRange replacementString:newString];

	[self replaceCharactersInRange:blockRange withString:newString];

	[self setSelectedRange:NSMakeRange(blockRange.location, [newString length])];

	if(blockRange.length == [newString length])
		return NO;
	else
		return YES;

}


/**
 * Shifts the selection, if any, leftwards by un-indenting any selected lines by one tab if possible.
 * If the caret is within a line, the selection is not changed after the undent; if the selection has
 * length, all lines crossed by the length are un-indented and fully selected.
 * Returns whether or not an indentation was performed.
 */
- (BOOL) shiftSelectionLeft
{
	NSString *textViewString = [[self textStorage] string];
	NSRange currentLineRange;

	if ([self selectedRange].location == NSNotFound || ![self isEditable]) return NO;

	// Undent the currently selected line if the caret is within a single line
	if ([self selectedRange].length == 0) {

		// Extract the current line range based on the text caret
		currentLineRange = [textViewString lineRangeForRange:[self selectedRange]];

		// Ensure that the line has length and that the first character is a tab
		if (currentLineRange.length < 1
			|| ([textViewString characterAtIndex:currentLineRange.location] != '\t' && [textViewString characterAtIndex:currentLineRange.location] != ' '))
			return NO;

		NSRange replaceRange;

		// Check for soft indention
		NSUInteger indentStringLength = 1;
#ifndef SP_CODA
		if ([prefs boolForKey:SPCustomQuerySoftIndent]) {
			NSUInteger numberOfSpaces = [prefs integerForKey:SPCustomQuerySoftIndentWidth];
			if(numberOfSpaces < 1) numberOfSpaces = 1;
			if(numberOfSpaces > 32) numberOfSpaces = 32;
			indentStringLength = numberOfSpaces;
			replaceRange = NSIntersectionRange(NSMakeRange(currentLineRange.location, indentStringLength), NSMakeRange(0,[[self string] length]));
			// Correct length for only white spaces
			NSString *possibleIndentString = [[[self textStorage] string] substringWithRange:replaceRange];
			NSUInteger numberOfLeadingWhiteSpaces = [possibleIndentString rangeOfRegex:@"^(\\s*)" capture:1L].length;
			if(numberOfLeadingWhiteSpaces == NSNotFound) numberOfLeadingWhiteSpaces = 0;
			replaceRange = NSMakeRange(currentLineRange.location, numberOfLeadingWhiteSpaces);
		} else {
#endif
			replaceRange = NSMakeRange(currentLineRange.location, indentStringLength);
#ifndef SP_CODA
		}
#endif

		// Register the undent for undo
		[self shouldChangeTextInRange:replaceRange replacementString:@""];

		// Remove the tab
		[self replaceCharactersInRange:replaceRange withString:@""];

		return YES;
	}

	// Otherwise, something is selected
	NSRange firstLineRange = [textViewString lineRangeForRange:NSMakeRange([self selectedRange].location,0)];
	NSUInteger lastLineMaxRange = NSMaxRange([textViewString lineRangeForRange:NSMakeRange(NSMaxRange([self selectedRange])-1,0)]);
	
	// Expand selection for first and last line to begin and end resp. but the last line ending
	NSRange blockRange = NSMakeRange(firstLineRange.location, lastLineMaxRange - firstLineRange.location);
	if([textViewString characterAtIndex:NSMaxRange(blockRange)-1] == '\n' || [textViewString characterAtIndex:NSMaxRange(blockRange)-1] == '\r')
		blockRange.length--;

	// Check for soft or hard indention
	NSString *indentString = @"\t";
	NSUInteger indentStringLength = 1;
#ifndef SP_CODA
	if ([prefs boolForKey:SPCustomQuerySoftIndent]) {
		indentStringLength = [prefs integerForKey:SPCustomQuerySoftIndentWidth];
		if(indentStringLength < 1) indentStringLength = 1;
		if(indentStringLength > 32) indentStringLength = 32;
		NSMutableString *spaces = [NSMutableString string];
		for(NSUInteger i = 0; i < indentStringLength; i++)
			[spaces appendString:@" "];
		indentString = [NSString stringWithString:spaces];
	}
#endif

	// Check if blockRange starts with SPACE or TAB
	// (this also catches the first line of the entire text buffer or
	// if only one line is selected)
	NSInteger leading = 0;
	if([textViewString characterAtIndex:blockRange.location] == ' ' 
		|| [textViewString characterAtIndex:blockRange.location] == '\t')
		leading += indentStringLength;

	// Replace \n[ \t] by \n of all lines in blockRange
	NSString *newString;
	// check for line ending
	if([textViewString characterAtIndex:NSMaxRange(firstLineRange)-1] == '\r')
		newString = [[textViewString substringWithRange:NSMakeRange(blockRange.location+leading, blockRange.length-leading)] 
			stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"\r%@", indentString] withString:@"\r"];
	else
		newString = [[textViewString substringWithRange:NSMakeRange(blockRange.location+leading, blockRange.length-leading)] 
		stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"\n%@", indentString] withString:@"\n"];

	// Register the unindent for undo
	[self shouldChangeTextInRange:blockRange replacementString:newString];

	[self replaceCharactersInRange:blockRange withString:newString];

	[self setSelectedRange:NSMakeRange(blockRange.location, [newString length])];

	if(blockRange.length == [newString length])
		return NO;
	else
		return YES;
}

#pragma mark -
#pragma mark snippet handler

/**
 * Reset snippet controller variables to end a snippet session
 */
- (void)endSnippetSession
{
	snippetControlCounter = -1;
	currentSnippetIndex   = -1;
	snippetControlMax     = -1;
	mirroredCounter       = -1;
	snippetWasJustInserted = NO;
}

/**
 * Shows pre-defined completion list
 */
- (void)showCompletionListFor:(NSString*)kind atRange:(NSRange)aRange fuzzySearch:(BOOL)fuzzySearchMode
{

	// Cancel auto-completion timer
#ifndef SP_CODA
	if([prefs boolForKey:SPCustomQueryAutoComplete])
#endif
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
								selector:@selector(doAutoCompletion) 
								object:nil];

	NSMutableArray *possibleCompletions = [[[NSMutableArray alloc] initWithCapacity:0] autorelease];

	NSString *connectionID;
	if(tableDocumentInstance)
		connectionID = [tableDocumentInstance connectionID];
	else
		connectionID = @"_";

	NSArray *arr = nil;
	if([kind isEqualToString:@"$SP_ASLIST_ALL_TABLES"]) {
		// TODO HansJB
		// NSString *currentDb = nil;
		//
		// if (tablesListInstance && [tablesListInstance selectedDatabase])
		// 	currentDb = [tablesListInstance selectedDatabase];
		//
		// NSDictionary *dbs = [NSDictionary dictionaryWithDictionary:[[mySQLConnection getDbStructure] objectForKey:connectionID]];
		// 
		// if(currentDb != nil && dbs != nil && [dbs count] && [dbs objectForKey:currentDb]) {
		// 	NSArray *allTables = [[dbs objectForKey:currentDb] allKeys];
		// 	NSSortDescriptor *desc = [[NSSortDescriptor alloc] initWithKey:nil ascending:YES selector:@selector(localizedCompare:)];
		// 	NSArray *sortedTables = [allTables sortedArrayUsingDescriptors:@[desc]];
		// 	[desc release];
		// 	for(id table in sortedTables) {
		// 		NSDictionary * theTable = [[dbs objectForKey:currentDb] objectForKey:table];
		// 		SPTableType structtype = (SPTableType)[[theTable objectForKey:@"  struct_type  "] intValue];
		// 		switch(structtype) {
		// 			case SPTableTypeTable:
		// 			[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:table, @"display", @"table-small-square", @"image", currentDb, @"path", @"", @"isRef", nil]];
		// 			break;
		// 			case SPTableTypeView:
		// 			[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:table, @"display", @"table-view-small-square", @"image", currentDb, @"path", @"", @"isRef", nil]];
		// 			break;
		// 		}
		// 	}
		// } else {
		arr = [NSArray arrayWithArray:[[(NSObject*)[self delegate] valueForKeyPath:@"tablesListInstance"] allTableAndViewNames]];
		if(arr == nil) {
			arr = @[];
		}
		for(id w in arr)
			[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:w, @"display", @"table-small-square", @"image", @"", @"isRef", nil]];
		// }
	}
	else if([kind isEqualToString:@"$SP_ASLIST_ALL_DATABASES"]) {
		arr = [NSArray arrayWithArray:[[(NSObject*)[self delegate] valueForKeyPath:@"tablesListInstance"] allDatabaseNames]];
		if(arr == nil) {
			arr = @[];
		}
		for(id w in arr)
			[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:w, @"display", @"database-small", @"image", @"", @"isRef", nil]];
		arr = [NSArray arrayWithArray:[[(NSObject*)[self delegate] valueForKeyPath:@"tablesListInstance"] allSystemDatabaseNames]];
		if(arr == nil) {
			arr = @[];
		}
		for(id w in arr)
			[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:w, @"display", @"database-small", @"image", @"", @"isRef", nil]];
	}
	else if([kind isEqualToString:@"$SP_ASLIST_ALL_FIELDS"]) {

		NSString *currentDb = nil;
		NSString *currentTable = nil;

		if (tablesListInstance && [tablesListInstance selectedDatabase])
			currentDb = [tablesListInstance selectedDatabase];
		if (tablesListInstance && [tablesListInstance tableName])
			currentTable = [tablesListInstance tableName];

		NSDictionary *dbs = [NSDictionary dictionaryWithDictionary:[[[tableDocumentInstance databaseStructureRetrieval] structure] objectForKey:connectionID]];
		if(currentDb != nil && currentTable != nil && dbs != nil && [dbs count] && [dbs objectForKey:currentDb] && [[dbs objectForKey:currentDb] objectForKey:currentTable]) {
			NSDictionary * theTable = [[dbs objectForKey:currentDb] objectForKey:currentTable];
			NSArray *allFields = [theTable allKeys];
			NSSortDescriptor *desc = [[NSSortDescriptor alloc] initWithKey:nil ascending:YES selector:@selector(localizedCompare:)];
			NSArray *sortedFields = [allFields sortedArrayUsingDescriptors:@[desc]];
			[desc release];
			for(id field in sortedFields) {
				if(![field hasPrefix:@"  "]) {
					NSArray *def = [theTable objectForKey:field];
					NSString *typ = [NSString stringWithFormat:@"%@ %@ %@", [def objectAtIndex:0], [def objectAtIndex:1], [def objectAtIndex:2]];
					// Check if type definition contains a , if so replace the bracket content by … and add 
					// the bracket content as "list" key to prevend the token field to split them by ,
					if(typ && [typ rangeOfString:@","].length) {
						NSString *t = [typ stringByReplacingOccurrencesOfRegex:@"\\(.*?\\)" withString:@"(…)"];
						NSString *lst = [typ stringByMatching:@"\\(([^\\)]*?)\\)" capture:1L];
						[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							field, @"display", 
							@"field-small-square", @"image", 
							[NSString stringWithFormat:@"%@%@%@", currentTable, SPUniqueSchemaDelimiter, currentDb], @"path",
							t, @"type", 
							lst, @"list", 
							@"", @"isRef", 
							nil]];
					} else {
						[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							field, @"display", 
							@"field-small-square", @"image", 
							[NSString stringWithFormat:@"%@%@%@", currentTable, SPUniqueSchemaDelimiter, currentDb], @"path",
							typ, @"type", 
							@"", @"isRef", 
							nil]];
					}
				}
			}
		}
		else {
#warning Private ivar accessed from outside (#2978)
			arr = [NSArray arrayWithArray:[[tableDocumentInstance valueForKeyPath:@"tableDataInstance"] valueForKey:@"columnNames"]];

			if(arr == nil) {
				arr = @[];
			}
			for(id w in arr)
				[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:w, @"display", @"field-small-square", @"image", @"", @"isRef", nil]];
		}
	}
	else {
		NSLog(@"“%@” is not a valid completion list", kind);
		NSBeep();
		return;
	}

	if (completionIsOpen) [completionPopup close], completionPopup = nil;
	completionIsOpen = YES;
	completionPopup = [[SPNarrowDownCompletion alloc] initWithItems:possibleCompletions
	                                                   alreadyTyped:@""
	                                                   staticPrefix:@""
	                                       additionalWordCharacters:@"_."
	                                                  caseSensitive:NO
	                                                      charRange:aRange
	                                                     parseRange:aRange
	                                                         inView:self
	                                                       dictMode:NO
	                                                 tabTriggerMode:[self isSnippetMode]
	                                                    fuzzySearch:fuzzySearchMode
	                                                   backtickMode:NO
	                                                     selectedDb:@""
	                                                 caretMovedLeft:NO
	                                                   autoComplete:NO
	                                                      oneColumn:NO
	                                                          alias:nil
	                                       withDBStructureRetriever:nil];

	[self _positionCompletionPopup:completionPopup relativeToTextAtLocation:aRange.location];

	[completionPopup orderFront:self];
}

/**
 * Update all mirrored snippets and adjust any involved instances
 */
- (void)processMirroredSnippets
{
	if(mirroredCounter > -1) {

		isProcessingMirroredSnippets = YES;

		NSInteger i, j, k, deltaLength;
		NSRange mirroredRange;

		SnippetControlInfo *currentSnippetRef = &snippetControlArray[currentSnippetIndex];
		// Go through each defined mirrored snippet and update it
		for(i=0; i<=mirroredCounter; i++) {
			MirrorControlInfo *mirrorRef = &snippetMirroredControlArray[i];
			if(mirrorRef->snippet == currentSnippetIndex) {

				deltaLength = currentSnippetRef->length - mirrorRef->length;

				mirroredRange = NSMakeRange(mirrorRef->location, mirrorRef->length);
				NSString *mirroredString = nil;

				// For safety reasons
				@try{
					mirroredString = [[self string] substringWithRange:NSMakeRange(currentSnippetRef->location, currentSnippetRef->length)];
				}
				@catch(id ae) {
					NSLog(@"Error while parsing for mirrored snippets. %@", [ae description]);
					NSBeep();
					[self endSnippetSession];
					return;
				}

				// Register for undo
				[self shouldChangeTextInRange:mirroredRange replacementString:mirroredString];

				[self replaceCharactersInRange:mirroredRange withString:mirroredString];
				mirrorRef->length = currentSnippetRef->length;

				// If a completion list is open adjust the theCharRange and theParseRange if a mirrored snippet
				// was updated which is located before the initial position 
				if(completionIsOpen && mirrorRef->location < (NSInteger)completionParseRangeLocation)
					[completionPopup adjustWorkingRangeByDelta:deltaLength];

				// Adjust all other snippets accordingly
				for(j=0; j<=snippetControlMax; j++) {
					if(snippetControlArray[j].location > -1) {
						if(snippetControlArray[j].location+snippetControlArray[j].length >= mirrorRef->location) {
							snippetControlArray[j].location += deltaLength;
						}
					}
				}
				// Adjust all mirrored snippets accordingly
				for(k=0; k<=mirroredCounter; k++) {
					if(i != k) {
						if(snippetMirroredControlArray[k].location > mirrorRef->location) {
							snippetMirroredControlArray[k].location += deltaLength;
						}
					}
				}
			}
		}

		isProcessingMirroredSnippets = NO;
		[self didChangeText];
		
	}
}


/**
 * Selects the current snippet defined by “currentSnippetIndex”
 */
- (void)selectCurrentSnippet
{
	if( snippetControlCounter  > -1 
		&& currentSnippetIndex >= 0 
		&& currentSnippetIndex <= snippetControlMax
		)
	{

		[self breakUndoCoalescing];

		// Place the caret at the end of the query favorite snippet
		// and finish snippet editing
		if(currentSnippetIndex == snippetControlMax) {
			[self setSelectedRange:NSMakeRange(snippetControlArray[snippetControlMax].location + snippetControlArray[snippetControlMax].length, 0)];
			[self endSnippetSession];
			return;
		}

		if(currentSnippetIndex >= 0 && currentSnippetIndex < COUNT_OF(snippetControlArray)) {
			SnippetControlInfo *currentSnippetRef = &snippetControlArray[currentSnippetIndex];
			if(currentSnippetRef->task == 0) {

				NSRange r1 = NSMakeRange(currentSnippetRef->location, currentSnippetRef->length);

				NSRange r2;
				// Ensure the selection for nested snippets if it is at very end of the text buffer
				// because NSIntersectionRange returns {0, 0} in such a case
				if(r1.location == [[self string] length])
					r2 = NSMakeRange([[self string] length], 0);
				else
					r2 = NSIntersectionRange(NSMakeRange(0,[[self string] length]), r1);

				if(r1.location == r2.location && r1.length == r2.length) {
					[self setSelectedRange:r2];
					NSString *snip = [[self string] substringWithRange:r2];
					
 					if([snip length] > 2 && [snip hasPrefix:@"¦"] && [snip hasSuffix:@"¦"]) {
						BOOL fuzzySearchMode = ([snip hasPrefix:@"¦¦"] && [snip hasSuffix:@"¦¦"]) ? YES : NO;
						NSInteger offset = (fuzzySearchMode) ? 2 : 1;
						NSRange insertRange = NSMakeRange(r2.location,0);
						NSString *newSnip = [snip substringWithRange:NSMakeRange(1*offset,[snip length]-(2*offset))];
						if([newSnip hasPrefix:@"$SP_ASLIST_"]) {
							[self showCompletionListFor:newSnip atRange:NSMakeRange(r2.location, 0) fuzzySearch:fuzzySearchMode];
							return;
						} else {
							NSArray *list = [[snip substringWithRange:NSMakeRange(1*offset,[snip length]-(2*offset))] componentsSeparatedByString:@"¦"];
							NSMutableArray *possibleCompletions = [[[NSMutableArray alloc] initWithCapacity:[list count]] autorelease];
							for(id w in list)
								[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:w, @"display", @"dummy-small", @"image", nil]];

							if (completionIsOpen) [completionPopup close], completionPopup = nil;
							completionIsOpen = YES;
							completionPopup = [[SPNarrowDownCompletion alloc] initWithItems:possibleCompletions
							                                                   alreadyTyped:@""
							                                                   staticPrefix:@""
							                                       additionalWordCharacters:@"_."
							                                                  caseSensitive:NO
							                                                      charRange:insertRange
							                                                     parseRange:insertRange
							                                                         inView:self
							                                                       dictMode:NO
							                                                 tabTriggerMode:[self isSnippetMode]
							                                                    fuzzySearch:fuzzySearchMode
							                                                   backtickMode:NO
							                                                     selectedDb:@""
							                                                 caretMovedLeft:NO
							                                                   autoComplete:NO
							                                                      oneColumn:YES
							                                                          alias:nil
							                                       withDBStructureRetriever:nil];

							[self _positionCompletionPopup:completionPopup relativeToTextAtLocation:r2.location];

							[completionPopup orderFront:self];
						}
					}
				} else {
					[self endSnippetSession];
				}
			}
		} else { // for safety reasons
			[self endSnippetSession];
		}
	} else { // for safety reasons
		[self endSnippetSession];
	}
}

/**
 * Inserts a chosen query favorite and initialze a snippet session if user defined any
 */
- (void)insertAsSnippet:(NSString*)theSnippet atRange:(NSRange)targetRange
{

	// Do not allow the insertion of a query favorite if snippets are active
	if(snippetControlCounter > -1) {
		NSBeep();
		return;
	}

	NSInteger i, j;
	mirroredCounter = -1;

	// reset snippet array
	for(i=0; i<COUNT_OF(snippetControlArray); i++) {
		snippetControlArray[i] = (SnippetControlInfo){ -1, -1, -1};
		snippetMirroredControlArray[i] = (MirrorControlInfo){-1, -1, -1};
	}

	if(theSnippet == nil || ![theSnippet length]) return;

	NSMutableString *snip = [[NSMutableString alloc] initWithCapacity:[theSnippet length]];

	@try{
		NSString *re = @"(?s)(?<!\\\\)\\$\\{(1?\\d):(.{0}|[^\\{\\}]*?[^\\\\])\\}";
		NSString *mirror_re = @"(?<!\\\\)\\$(1?\\d)(?=\\D)";

		if(targetRange.length)
			targetRange = NSIntersectionRange(NSMakeRange(0,[[self string] length]), targetRange);
		[snip setString:theSnippet];

		if (snip == nil) return;
		if (![snip length]) {
			[snip release];
			return;
		}

		// Replace `${x:…}` by ${x:`…`} for convience 
		[snip replaceOccurrencesOfRegex:@"`(?s)(?<!\\\\)\\$\\{(1?\\d):(.{0}|.*?[^\\\\])\\}`" withString:@"${$1:`$2`}"];
		[snip flushCachedRegexData];

		snippetControlCounter = -1;
		snippetControlMax     = -1;
		currentSnippetIndex   = -1;

		// Suppress snippet range calculation in [self textStorageDidProcessEditing] while initial insertion
		snippetWasJustInserted = YES;

		while([snip isMatchedByRegex:re]) {
			[snip flushCachedRegexData];
			snippetControlCounter++;

			NSRange snipRange = [snip rangeOfRegex:re capture:0L];
			NSInteger snipCnt = [[snip substringWithRange:[snip rangeOfRegex:re capture:1L]] intValue];
			NSRange hintRange = [snip rangeOfRegex:re capture:2L];

			// Check for snippet number 19 (to simplify regexp)
			if(snipCnt>18 || snipCnt<0) {
				NSLog(@"Only snippets in the range of 0…18 allowed.");
				[self endSnippetSession];
				break;
			}

			// Remember the maximal snippet number defined by user
			if(snipCnt>snippetControlMax)
				snippetControlMax = snipCnt;

			// Replace internal variables
			NSMutableString *theHintString = [[NSMutableString alloc] initWithCapacity:hintRange.length];
			[theHintString setString:[snip substringWithRange:hintRange]];
			if([theHintString isMatchedByRegex:@"(?<!\\\\)\\$SP_"]) {
				NSRange r;
				NSString *currentTable = nil;
				if (tablesListInstance && [tablesListInstance tableName])
					currentTable = [tablesListInstance tableName];
				NSString *currentDb = nil;
				if (tablesListInstance && [tablesListInstance selectedDatabase])
					currentDb = [tablesListInstance selectedDatabase];

#ifndef SP_CODA
				while ([theHintString isMatchedByRegex:@"(?<!\\\\)\\$SP_SELECTED_TABLES"]) 
				{
					r = [theHintString rangeOfRegex:@"(?<!\\\\)\\$SP_SELECTED_TABLES"];
					
					if (r.length) {
						NSArray *selTables = [[(NSObject *)[self delegate] valueForKeyPath:@"tablesListInstance"] selectedTableNames];
						
						[theHintString replaceCharactersInRange:r withString:[selTables count] ? [selTables componentsJoinedAndBacktickQuoted] : @"$SP_SELECTED_TABLE"];	
					}
					
					[theHintString flushCachedRegexData];
				}
#endif

				while([theHintString isMatchedByRegex:@"(?<!\\\\)\\$SP_SELECTED_TABLE"]) {
					r = [theHintString rangeOfRegex:@"(?<!\\\\)\\$SP_SELECTED_TABLE"];
					if(r.length) {
						if(currentTable && [currentTable length])
							[theHintString replaceCharactersInRange:r withString:[currentTable backtickQuotedString]];
						else
							[theHintString replaceCharactersInRange:r withString:@"<table>"];
					}
					[theHintString flushCachedRegexData];
				}

				while([theHintString isMatchedByRegex:@"(?<!\\\\)\\$SP_SELECTED_DATABASE"]) {
					r = [theHintString rangeOfRegex:@"(?<!\\\\)\\$SP_SELECTED_DATABASE"];
					if(r.length) {
						if(currentDb && [currentDb length])
							[theHintString replaceCharactersInRange:r withString:[currentDb backtickQuotedString]];
						else
							[theHintString replaceCharactersInRange:r withString:@"<database>"];
					}
					[theHintString flushCachedRegexData];
				}
			}

			// Handle escaped characters
			[theHintString replaceOccurrencesOfRegex:@"\\\\(\\$\\(|\\}|\\$SP_)" withString:@"$1"];
			[theHintString flushCachedRegexData];

#ifndef SP_CODA
			// If inside the snippet hint $(…) is defined run … as BASH command
			// and replace $(…) by the return string of that command. Please note
			// only one $(…) statement is allowed within one ${…} snippet environment.
			NSRange tagRange = [theHintString rangeOfRegex:@"(?s)(?<!\\\\)\\$\\((.*)\\)"];
			if(tagRange.length) {
				[theHintString flushCachedRegexData];
				NSRange cmdRange = [theHintString rangeOfRegex:@"(?s)(?<!\\\\)\\$\\(\\s*(.*)\\s*\\)" capture:1L];
				if(cmdRange.length) {
					NSError *err = nil;
					NSString *cmdResult = [SPBundleCommandRunner runBashCommand:[theHintString substringWithRange:cmdRange] withEnvironment:nil atCurrentDirectoryPath:nil error:&err];
					if(err == nil) {
						[theHintString replaceCharactersInRange:tagRange withString:cmdResult];
					} else if([err code] != 9) { // Suppress an error message if command was killed
						NSString *errorMessage  = [err localizedDescription];
						SPOnewayAlertSheet(
							NSLocalizedString(@"BASH Error", @"bash error"),
							[self window],
							[NSString stringWithFormat:NSLocalizedString(@"Error for “%1$@”:\n%2$@", @"error for bash command ($1), $2=message"), [theHintString substringWithRange:cmdRange], errorMessage]
						);
					}
				} else {
					[theHintString replaceCharactersInRange:tagRange withString:@""];
				}
			}
			[theHintString flushCachedRegexData];
#endif

			[snip replaceCharactersInRange:snipRange withString:theHintString];
			[snip flushCachedRegexData];

			// Store found snippet range
			snippetControlArray[snipCnt].location = snipRange.location + targetRange.location;
			snippetControlArray[snipCnt].length   = [theHintString length];
			snippetControlArray[snipCnt].task     = 0;

			[theHintString release];

			// Adjust successive snippets
			for(i=0; i<COUNT_OF(snippetControlArray); i++)
				if(snippetControlArray[i].location > -1 && i != snipCnt && snippetControlArray[i].location > snippetControlArray[snipCnt].location)
					snippetControlArray[i].location -= 3+((snipCnt>9)?2:1);

		}

		// Parse for mirrored snippets
		while([snip isMatchedByRegex:mirror_re]) {
			mirroredCounter++;
			if(mirroredCounter >= COUNT_OF(snippetMirroredControlArray)) {
				NSLog(@"Only %lu mirrored snippet placeholders allowed.",COUNT_OF(snippetMirroredControlArray));
				mirroredCounter--; //go back by one or the code below will do an out-of-bounds array access
				NSBeep();
				break;
			} else {

				NSRange snipRange = [snip rangeOfRegex:mirror_re capture:0L];
				NSInteger snipCnt = [[snip substringWithRange:[snip rangeOfRegex:mirror_re capture:1L]] intValue];

				// Check for snippet number 19 (to simplify regexp)
				if(snipCnt>18 || snipCnt<0) {
					NSLog(@"Only snippets in the range of 0…18 allowed.");
					[self endSnippetSession];
					break;
				}

				[snip replaceCharactersInRange:snipRange withString:@""];
				[snip flushCachedRegexData];

				// Store found mirrored snippet range
				snippetMirroredControlArray[mirroredCounter].snippet  = snipCnt;
				snippetMirroredControlArray[mirroredCounter].location = snipRange.location + targetRange.location;
				snippetMirroredControlArray[mirroredCounter].length   = 0;

				// Adjust successive snippets
				for(i=0; i<COUNT_OF(snippetControlArray); i++)
					if(snippetControlArray[i].location > -1 && snippetControlArray[i].location > snippetMirroredControlArray[mirroredCounter].location)
						snippetControlArray[i].location -= 1+((snipCnt>9)?2:1);

				[snip flushCachedRegexData];
			}
		}
		// Preset mirrored snippets with according snippet content
		if(mirroredCounter > -1) {
			for(i=0; i<=mirroredCounter; i++) {
				MirrorControlInfo *mirrorRef = &snippetMirroredControlArray[i];
				SnippetControlInfo *snippetRef = &snippetControlArray[mirrorRef->snippet];
				if(snippetRef->location > -1 && snippetRef->length > 0) {
					NSRange copyToRange   = NSMakeRange(mirrorRef->location-targetRange.location, mirrorRef->length);
					NSRange copyFromRange = NSMakeRange(snippetRef->location-targetRange.location, snippetRef->length);
					[snip replaceCharactersInRange:copyToRange withString:[snip substringWithRange:copyFromRange]];
					mirrorRef->length = snippetRef->length;
				}
				// Adjust successive snippets
				for(j=0; j<COUNT_OF(snippetControlArray); j++)
					if(snippetControlArray[j].location > -1 && snippetControlArray[j].location > mirrorRef->location)
						snippetControlArray[j].location += snippetRef->length;
				// Adjust successive mirrored snippets
				for(j=0; j<=mirroredCounter; j++)
					if(snippetMirroredControlArray[j].location > mirrorRef->location)
						snippetMirroredControlArray[j].location += snippetRef->length;
			}
		}

		if(snippetControlCounter > -1) {
			// Store the end for tab out
			snippetControlMax++;
			snippetControlArray[snippetControlMax] = (SnippetControlInfo){targetRange.location + [snip length], 0, 0};
		}

		// unescape escaped snippets and re-adjust successive snippet locations : \${1:a} → ${1:a}
		// unescape escaped mirrored snippets and re-adjust successive snippet locations : \$1 → $1
		for (NSString *regex in @[@"(?s)\\\\\\$\\{(1?\\d):(.{0}|.*?[^\\\\])\\}",@"(?s)\\\\\\$(1?\\d)(?=\\D)"]) {
			while([snip isMatchedByRegex:regex]) {
				NSRange escapeRange = [snip rangeOfRegex:regex capture:0L];
				[snip replaceCharactersInRange:escapeRange withString:[snip substringWithRange:NSMakeRange(escapeRange.location+1,escapeRange.length-1)]];
				NSInteger loc = escapeRange.location + targetRange.location;
				[snip flushCachedRegexData];
				for(i=0; i<=snippetControlMax; i++)
					if(snippetControlArray[i].location > -1 && snippetControlArray[i].location > loc)
						snippetControlArray[i].location--;
				// Adjust mirrored snippets
				if(mirroredCounter > -1)
					for(i=0; i<=mirroredCounter; i++)
						if(snippetMirroredControlArray[i].snippet > -1 && snippetMirroredControlArray[i].location > loc)
							snippetMirroredControlArray[i].location--;
			}
		}

		// Insert favorite query by selecting the tab trigger if any
		[self setSelectedRange:targetRange];

		// Registering for undo
		[self breakUndoCoalescing];
		[self insertText:snip];

		// If autopair is enabled check whether snip begins with ( and ends with ), if so mark ) as pair-linked
		if (
#ifndef SP_CODA
				[prefs boolForKey:SPCustomQueryAutoPairCharacters] &&
#else
#endif
				 (([snip hasPrefix:@"("] && [snip hasSuffix:@")"])
						|| ([snip hasPrefix:@"`"] && [snip hasSuffix:@"`"])
						|| ([snip hasPrefix:@"'"] && [snip hasSuffix:@"'"])
						|| ([snip hasPrefix:@"\""] && [snip hasSuffix:@"\""])))
		{
			[[self textStorage] addAttribute:kAPlinked value:kAPval range:NSMakeRange([self selectedRange].location - 1, 1)];
		}

		// Any snippets defined?
		if(snippetControlCounter > -1) {
			// Find and select first defined snippet
			currentSnippetIndex = 0;
			// Look for next defined snippet since snippet numbers might not be serial like 1, 5, and 12 e.g.
			while(snippetControlArray[currentSnippetIndex].location == -1 && currentSnippetIndex < COUNT_OF(snippetControlArray))
				currentSnippetIndex++;
			[self selectCurrentSnippet];
		}

		snippetWasJustInserted = NO;
	}
	@catch(id ae) { // For safety reasons catch exceptions
		NSLog(@"Snippet Error: %@", [ae description]);
		[self endSnippetSession];
		snippetWasJustInserted = NO;
	}

	if(snip)[snip release];

}

/**
 * Checks whether the current caret position in inside of a defined snippet range
 */
- (BOOL)checkForCaretInsideSnippet
{

	if(snippetWasJustInserted) return YES;

	BOOL isCaretInsideASnippet = NO;

	if(snippetControlCounter < 0 || currentSnippetIndex == snippetControlMax) {
		[self endSnippetSession];
		return NO;
	}
	
	[[self textStorage] ensureAttributesAreFixedInRange:[self selectedRange]];
	NSInteger caretPos = [self selectedRange].location;
	NSInteger i, j;
	NSInteger foundSnippetIndices[20]; // array to hold nested snippets

	j = -1;

	// Go through all snippet ranges and check whether the caret is inside of the
	// current snippet range. Remember matches 
	// in foundSnippetIndices array to test for nested snippets.
	for(i=0; i<=snippetControlMax; i++) {
		j++;
		foundSnippetIndices[j] = 0;
		if(snippetControlArray[i].location != -1
			&& caretPos >= snippetControlArray[i].location
			&& caretPos <= snippetControlArray[i].location + snippetControlArray[i].length) {

			foundSnippetIndices[j] = 1;
			if(i == currentSnippetIndex)
				isCaretInsideASnippet = YES;

		}
	}
	// If caret is not inside the current snippet range check if caret is inside of
	// another defined snippet; if so set currentSnippetIndex to it (this allows to use the
	// mouse to activate another snippet). If the caret is inside of overlapped snippets (nested)
	// then select this snippet which has the smallest length.
	if(!isCaretInsideASnippet && foundSnippetIndices[currentSnippetIndex] == 1) {
		isCaretInsideASnippet = YES;
	} else if(![self selectedRange].length) {
		NSInteger curIndex = -1;
		NSInteger smallestLength = -1;
		for(i=0; i<snippetControlMax; i++) {
			if(foundSnippetIndices[i] == 1) {
				if(curIndex == -1) {
					curIndex = i;
					smallestLength = snippetControlArray[i].length;
				} else {
					if(smallestLength > snippetControlArray[i].length) {
						curIndex = i;
						smallestLength = snippetControlArray[i].length;
					}
				}
			}
		}
		// Reset the active snippet
		if(curIndex > -1 && smallestLength > -1) {
			currentSnippetIndex = curIndex;
			isCaretInsideASnippet = YES;
		}
	}
	return isCaretInsideASnippet;

}

/**
 * Return YES if user interacts with snippets (is needed mainly for suppressing
 * the highlighting of the current query)
 */
- (BOOL)isSnippetMode
{
	return (snippetControlCounter > -1) ? YES : NO;
}

#pragma mark -
#pragma mark event management

/**
 * Used for autoHelp update if the user changed the caret position by using the mouse.
 */
- (void) mouseDown:(NSEvent *)theEvent
{

	// Cancel autoHelp timer
#ifndef SP_CODA
	if([prefs boolForKey:SPCustomQueryUpdateAutoHelp])
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
									selector:@selector(autoHelp) 
									object:nil];
#endif

	// Cancel auto-completion timer
#ifndef SP_CODA
	if([prefs boolForKey:SPCustomQueryAutoComplete])
#endif
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
								selector:@selector(doAutoCompletion) 
								object:nil];

	[super mouseDown:theEvent];

#ifndef SP_CODA
	// Start autoHelp timer
	if([prefs boolForKey:SPCustomQueryUpdateAutoHelp])
		[self performSelector:@selector(autoHelp) withObject:nil afterDelay:[[prefs valueForKey:SPCustomQueryAutoHelpDelay] doubleValue]];
#endif	
}

/**
 * Handle some keyDown events and perform autopairing functionality (if enabled).
 */
- (void) keyDown:(NSEvent *)theEvent
{
#ifndef SP_CODA

	if([prefs boolForKey:SPCustomQueryUpdateAutoHelp]) {// restart autoHelp timer
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
									selector:@selector(autoHelp) 
									object:nil];
		[self performSelector:@selector(autoHelp) withObject:nil 
			afterDelay:[[prefs valueForKey:SPCustomQueryAutoHelpDelay] doubleValue]];
	}
#endif

	// Cancel auto-completion timer
#ifndef SP_CODA
	if([prefs boolForKey:SPCustomQueryAutoComplete])
#endif
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
								selector:@selector(doAutoCompletion) 
								object:nil];


	NSEventModifierFlags allFlags = (NSEventModifierFlagShift|NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagCommand);
	
	// Check if user pressed ⌥ to allow composing of accented characters.
	// e.g. for US keyboard "⌥u a" to insert ä
	// or for non-US keyboards to allow to enter dead keys
	// e.g. for German keyboard ` is a dead key, press space to enter `
	if (([theEvent modifierFlags] & allFlags) == NSEventModifierFlagOption || [[theEvent characters] length] == 0)
	{
		[super keyDown: theEvent];
		return;
	}

	NSString *characters = [theEvent characters];
	NSString *charactersIgnMod = [theEvent charactersIgnoringModifiers];
	unichar insertedCharacter = [characters characterAtIndex:0];
	NSEventModifierFlags curFlags = ([theEvent modifierFlags] & allFlags);

	if ([theEvent keyCode] == 53 && [self isEditable]){ // ESC key for internal completion

		[self setCompletionWasReinvokedAutomatically:NO];
		completionWasRefreshed = NO;
		// Cancel autocompletion trigger
#ifndef SP_CODA
		if([prefs boolForKey:SPCustomQueryAutoComplete])
#endif
			[NSObject cancelPreviousPerformRequestsWithTarget:self 
									selector:@selector(doAutoCompletion) 
									object:nil];

		if(curFlags==(NSEventModifierFlagControl))
			[self doCompletionByUsingSpellChecker:NO fuzzyMode:YES autoCompleteMode:NO];
		else
			[self doCompletionByUsingSpellChecker:NO fuzzyMode:NO autoCompleteMode:NO];
		return;
	}
	if (insertedCharacter == NSF5FunctionKey && [self isEditable]){ // F5 for completion based on spell checker
		[self setCompletionWasReinvokedAutomatically:NO];
		[self doCompletionByUsingSpellChecker:YES fuzzyMode:NO autoCompleteMode:NO];
		return;
	}

	// Check for {SHIFT}TAB to try to insert query favorite via TAB trigger if SPTextView belongs to SPCustomQuery
	// and TAB as soft indention
	if ([theEvent keyCode] == 48 && [self isEditable] && [[self delegate] isKindOfClass:[SPCustomQuery class]]){
#ifndef SP_CODA
		NSRange targetRange = [self getRangeForCurrentWord];
		NSString *tabTrigger = [[self string] substringWithRange:targetRange];
#endif

		// Is TAB trigger active change selection according to {SHIFT}TAB
		if(snippetControlCounter > -1){

			if(curFlags==(NSEventModifierFlagShift)) { // select previous snippet

				currentSnippetIndex--;

				// Look for previous defined snippet since snippet numbers might not be serial like 1, 5, and 12 e.g.
				while(snippetControlArray[currentSnippetIndex].location == -1 && currentSnippetIndex > -2)
					currentSnippetIndex--;

				if(currentSnippetIndex < 0) {
					currentSnippetIndex = 0;
					while(snippetControlArray[currentSnippetIndex].location == -1 && currentSnippetIndex < COUNT_OF(snippetControlArray))
						currentSnippetIndex++;
					NSBeep();
				}

				[self selectCurrentSnippet];
				return;

			} else { // select next snippet

				currentSnippetIndex++;

				// Look for next defined snippet since snippet numbers might not be serial like 1, 5, and 12 e.g.
				while(snippetControlArray[currentSnippetIndex].location == -1 && currentSnippetIndex < COUNT_OF(snippetControlArray))
					currentSnippetIndex++;

				if(currentSnippetIndex > snippetControlMax) { // for safety reasons
					[self endSnippetSession];
				} else {
					[self selectCurrentSnippet];
					return;
				}
			}

			[self endSnippetSession];

		}

#ifndef SP_CODA
		// Check if tab trigger is defined; if so insert it, otherwise pass through event
		if(snippetControlCounter < 0 && [tabTrigger length] && [tableDocumentInstance fileURL]) {
			NSArray *snippets = [[SPQueryController sharedQueryController] queryFavoritesForFileURL:[tableDocumentInstance fileURL] andTabTrigger:tabTrigger includeGlobals:YES];
			if([snippets count] > 0 && [(NSString*)[(NSDictionary*)[snippets objectAtIndex:0] objectForKey:@"query"] length]) {
				[self insertAsSnippet:[(NSDictionary*)[snippets objectAtIndex:0] objectForKey:@"query"] atRange:targetRange];
				return;
			}
		}

		// Check for TAB as indention for current line, i.e. left of the caret there are only white spaces
		// but only if Soft Indent is set
		if([prefs boolForKey:SPCustomQuerySoftIndent] && [self isCaretAtIndentPositionIgnoreLineStart:YES]) {
			if([self shiftSelectionRight]) return;
		}
#endif
	}
  
	if(curFlags & NSEventModifierFlagCommand) {
		if([charactersIgnMod isEqualToString:@"+"] || [charactersIgnMod isEqualToString:@"="]) // increase text size by 1; ⌘+, ⌘=, and ⌘ numpad +
		{
			[self makeTextSizeLarger];
			return;
		}
		if([charactersIgnMod isEqualToString:@"-"]) // decrease text size by 1; ⌘- and numpad -
		{
			[self makeTextSizeSmaller];
			return;
		}
		if([charactersIgnMod isEqualToString:@"0"]) { // reset font to default
			BOOL editableStatus = [self isEditable];
			[self setEditable:YES];
#ifndef SP_CODA
			[self setFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorFont]]];
#endif
			[self setEditable:editableStatus];
			return;
		}
	}

	// Only process for character autopairing if autopairing is enabled and a single character is being added.
#ifndef SP_CODA
	if ([prefs boolForKey:SPCustomQueryAutoPairCharacters] && characters && [characters length] == 1) {
#else
	if (characters && [characters length] == 1) {
#endif

		delBackwardsWasPressed = NO;

		NSString *matchingCharacter = nil;
		BOOL processAutopair = NO, skipTypedLinkedCharacter = NO;
		NSRange currentRange;

		// When a quote character is being inserted into a string quoted with other
		// quote characters, or if it's the same character but is escaped, don't
		// automatically match it.
		if(
			// Only for " ` or ' quote characters
			(insertedCharacter == '\'' || insertedCharacter == '"' || insertedCharacter == '`')

			// And if the next char marked as linked auto-pair
			&& [self isNextCharMarkedBy:kAPlinked withValue:kAPval]

			// And we are inside a quoted string
			&& [self isNextCharMarkedBy:kLEXToken withValue:kLEXTokenValue]

			// And there is no selection, just the text caret
			&& ![self selectedRange].length

			&& (
				// And the user is inserting an escaped string
				[[self string] characterAtIndex:[self selectedRange].location-1] == '\\'
				
				// Or the user is inserting a character not matching the characters used to quote this string
				|| [[self string] characterAtIndex:[self selectedRange].location] != insertedCharacter
			)
		)
		{
			[super keyDown: theEvent];
			return;
		}

		// If the caret is inside a text string, without any selection, and not adjoined to an alphanumeric char
		// (exception for '(' ) skip autopairing.
		// There is one exception to this - if the caret is before a linked pair character,
		// processing continues in order to check whether the next character should be jumped
		// over; e.g. [| := caret]: "foo|" and press " => only caret will be moved "foo"|
		if( ([self isCaretAdjacentToAlphanumCharWithInsertionOf:insertedCharacter] && ![self isNextCharMarkedBy:kAPlinked withValue:kAPval] && ![self selectedRange].length) 
			|| (![self isNextCharMarkedBy:kAPlinked withValue:kAPval] && [self isNextCharMarkedBy:kLEXToken withValue:kLEXTokenValue] && ![self selectedRange].length)) {
			[super keyDown:theEvent];
			return;
		}

		// Check whether the submitted character should trigger autopair processing.
		switch (insertedCharacter)
		{
			case '(':
				matchingCharacter = @")";
				processAutopair = YES;
				break;
			case '"':
				matchingCharacter = @"\"";
				processAutopair = YES;
				skipTypedLinkedCharacter = YES;
				break;
			case '`':
				matchingCharacter = @"`";
				processAutopair = YES;
				skipTypedLinkedCharacter = YES;
				break;
			case '\'':
				matchingCharacter = @"'";
				processAutopair = YES;
				skipTypedLinkedCharacter = YES;
				break;
			case ')':
				skipTypedLinkedCharacter = YES;
				break;
			case '{':
				matchingCharacter = @"}";
				processAutopair = YES;
				break;
			case '}':
				skipTypedLinkedCharacter = YES;
				break;
		}

		// Check to see whether the next character should be compared to the typed character;
		// if it matches the typed character, and is marked with the is-linked-pair attribute,
		// select the next character and replace it with the typed character.  This allows
		// a normally quoted string to be typed in full, with the autopair appearing as a hint and
		// then being automatically replaced when the user types it.
		if (skipTypedLinkedCharacter) {
			currentRange = [self selectedRange];
			if (currentRange.location != NSNotFound && currentRange.length == 0) {
				if ([self isNextCharMarkedBy:kAPlinked withValue:kAPval]) {
					if ([[[self textStorage] string] characterAtIndex:currentRange.location] == insertedCharacter) {
						currentRange.length = 1;
						[self setSelectedRange:currentRange];
						processAutopair = NO;
					}
				}
			}
		}

		// If an appropriate character has been typed, and a matching character has been set,
		// some form of autopairing is required.
		if (processAutopair && matchingCharacter) {

			// Check to see whether several characters are selected, and if so, wrap them with
			// the auto-paired characters.  This returns false if the selection has zero length.
			if ([self wrapSelectionWithPrefix:characters suffix:matchingCharacter])
				return;
			
			// Otherwise, start by inserting the original character - the first half of the autopair.
			[super keyDown:theEvent];
			
			// Then process the second half of the autopair - the matching character.
			currentRange = [self selectedRange];
			if (currentRange.location != NSNotFound) {
				NSTextStorage *textStorage = [self textStorage];

				// Register the auto-pairing for undo
				[self shouldChangeTextInRange:currentRange replacementString:matchingCharacter];

				// Insert the matching character and give it the is-linked-pair-character attribute
				[self replaceCharactersInRange:currentRange withString:matchingCharacter];
				currentRange.length = 1;
				[textStorage addAttribute:kAPlinked value:kAPval range:currentRange];

				// Restore the original selection.
				currentRange.length=0;
				[self setSelectedRange:currentRange];
				
				[self didChangeText];
			}
			return;
		}

// Let Xcode 3 match braces correctly...
#ifndef SP_CODA
	}
#else
	}
#endif
	
	// break down the undo grouping level for better undo behavior
	[self breakUndoCoalescing];
	// The default action is to perform the normal key-down action.
	[super keyDown:theEvent];
	
}

/**
 * The following moveWord... routines are needed to be able to recognize a db schema à la
 * db.table.field as ONE word while navigating and selecting by the keyboard
 */
- (void)moveWordRight:(id)sender
{
	[super moveWordRight:sender];
	NSCharacterSet *whiteSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	while([self selectedRange].location < [[[self textStorage] string] length] 
		&& ([[[self textStorage] string] characterAtIndex:[self selectedRange].location] == '.' 
		|| (
				[[[self textStorage] string] characterAtIndex:[self selectedRange].location-1] == '.' 
				&& ![whiteSet characterIsMember:[[[self textStorage] string] characterAtIndex:[self selectedRange].location]]
			)
		))
		[super moveWordRight:sender];
}

- (void)moveWordLeft:(id)sender
{
	[super moveWordLeft:sender];
	while([self selectedRange].location > 0 && [[[self textStorage] string] characterAtIndex:[self selectedRange].location-1] == '.')
		[super moveWordLeft:sender];
}

- (void)moveWordLeftAndModifySelection:(id)sender
{
	[super moveWordLeftAndModifySelection:sender];
	while([self selectedRange].location > 0 && [[[self textStorage] string] characterAtIndex:[self selectedRange].location-1] == '.')
		[super moveWordLeftAndModifySelection:sender];
}

- (void)moveWordRightAndModifySelection:(id)sender
{
	[super moveWordRightAndModifySelection:sender];
	NSCharacterSet *whiteSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	while(NSMaxRange([self selectedRange]) < [[[self textStorage] string] length] 
		&& ([[[self textStorage] string] characterAtIndex:NSMaxRange([self selectedRange])] == '.' 
		|| (
				[[[self textStorage] string] characterAtIndex:NSMaxRange([self selectedRange])-1] == '.' 
				&& ![whiteSet characterIsMember:[[[self textStorage] string] characterAtIndex:NSMaxRange([self selectedRange])]]
			)
		))
		[super moveWordRightAndModifySelection:sender];
}

- (void) deleteBackward:(id)sender
{

	NSRange currentRange = [self selectedRange];

	if (currentRange.length == 0) {

		// If the caret is currently inside a marked auto-pair, delete the characters on both sides
		// of the caret.
		if (currentRange.location > 0 && [self areAdjacentCharsLinked]) {
			[self setSelectedRange:NSMakeRange(currentRange.location - 1,2)];
			// Avoid auto-uppercasing if resulting word would be a SQL keyword;
			// e.g. type inta| and deleteBackward:
			delBackwardsWasPressed = YES;
		}

		// Remove soft indent if active and left from caret are only white spaces
#ifndef SP_CODA
		else if ([prefs boolForKey:SPCustomQuerySoftIndent] && [self isCaretAtIndentPositionIgnoreLineStart:NO])
#else
		else if ([self isCaretAtIndentPositionIgnoreLineStart:NO])
#endif
		{
			[self shiftSelectionLeft];
			return;
		}

	}

	[super deleteBackward:sender];

}

/**
 * Handle special commands - see NSResponder.h for a sample list.
 * This subclass currently handles insertNewline: in order to preserve indentation
 * when adding newlines.
 */
- (void) doCommandBySelector:(SEL)aSelector
{

	// Handle newlines, adding any indentation found on the current line to the new line - ignoring the enter key if appropriate
    if (aSelector == @selector(insertNewline:)
#ifndef SP_CODA
		&& [prefs boolForKey:SPCustomQueryAutoIndent]
#endif
		&& (!autoindentIgnoresEnter || [[NSApp currentEvent] keyCode] != 0x4C))
	{
		NSString *textViewString = [[self textStorage] string];
		NSString *currentLine, *indentString = nil;
		NSScanner *whitespaceScanner;
		NSRange currentLineRange;
		NSUInteger lineCursorLocation;

		// Extract the current line based on the text caret or selection start position
		currentLineRange = [textViewString lineRangeForRange:NSMakeRange([self selectedRange].location, 0)];
		currentLine = [[NSString alloc] initWithString:[textViewString substringWithRange:currentLineRange]];
		lineCursorLocation = [self selectedRange].location - currentLineRange.location;

		// Scan all indentation characters on the line into a string
		whitespaceScanner = [[NSScanner alloc] initWithString:currentLine];
		[whitespaceScanner setCharactersToBeSkipped:nil];
		[whitespaceScanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&indentString];
		[whitespaceScanner release];
		[currentLine release];

		// Always add the newline, whether or not we want to indent the next line
		[self insertNewline:self];

		// Replicate the indentation on the previous line if one was found.
		if (indentString) {
			if (lineCursorLocation < [indentString length]) {
				[self insertText:[indentString substringWithRange:NSMakeRange(0, lineCursorLocation)]];
			} else {
				[self insertText:indentString];
			}
		}

		// Return to avoid the original implementation, preventing double linebreaks
		return;
	}

	// Remove soft indent if active and left from caret are only white spaces
#ifndef SP_CODA
	if (aSelector == @selector(deleteForward:)
		&& ![self selectedRange].length
		&& [prefs boolForKey:SPCustomQuerySoftIndent]
		&& [self isCaretAtIndentPositionIgnoreLineStart:YES]
		&& [self selectedRange].location < [[self string] length] && [[self string] characterAtIndex:[self selectedRange].location] == ' ')
	{
		[self shiftSelectionLeft];
		return;
	}
#endif

	[super doCommandBySelector:aSelector];
}

/**
 * Set whether this text view should apply the indentation on the current line to new lines.
 */
- (void)setAutoindent:(BOOL)enableAutoindent
{
	autoindentEnabled = enableAutoindent;
}

/**
 * Retrieve whether this text view applies indentation on the current line to new lines.
 */
- (BOOL)autoindent
{
	return autoindentEnabled;
}

/**
 * Set whether this text view should not autoindent when the Enter key is used, as opposed
 * to the return key.  Also catches function-return.
 */
- (void)setAutoindentIgnoresEnter:(BOOL)enableAutoindentIgnoresEnter
{
	autoindentIgnoresEnter = enableAutoindentIgnoresEnter;
}

/**
 * Retrieve whether this text view should not autoindent when the Enter key is used.
 */
- (BOOL)autoindentIgnoresEnter
{
	return autoindentIgnoresEnter;
}

/**
 * Set whether this text view should automatically create the matching closing char for ", ', ` and ( chars.
 */
- (void)setAutopair:(BOOL)enableAutopair
{
	autopairEnabled = enableAutopair;
}

/**
 * Retrieve whether this text view automatically creates the matching closing char for ", ', ` and ( chars.
 */
- (BOOL)autopair
{
	return autopairEnabled;
}

#ifndef SP_CODA
/**
 * Set whether MySQL Help should be automatically invoked while typing.
 */
- (void)setAutohelp:(BOOL)enableAutohelp
{
	autohelpEnabled = enableAutohelp;
}

/**
 * Retrieve whether MySQL Help should be automatically invoked while typing.
 */
- (BOOL)autohelp
{
	return autohelpEnabled;
}
#endif

/**
 * Set whether SQL keywords should be automatically uppercased.
 */
- (void)setAutouppercaseKeywords:(BOOL)enableAutouppercaseKeywords
{
	autouppercaseKeywordsEnabled = enableAutouppercaseKeywords;
}

/**
 * Retrieve whether SQL keywords should be automatically uppercased.
 */
- (BOOL)autouppercaseKeywords
{
	return autouppercaseKeywordsEnabled;
}


/**
 * If enabled it shows the MySQL Help for the current word (not inside quotes) or for the selection
 * after an adjustable delay if the textView is idle, i.e. no user interaction.
 */
- (void)autoHelp
{

#ifndef SP_CODA
	if(![prefs boolForKey:SPCustomQueryUpdateAutoHelp] || ![[self string] length]) return;
#else
	if(![[self string] length]) return;
#endif

	// If selection show Help for it
	if([self selectedRange].length)
	{
		[customQueryInstance performSelector:@selector(showAutoHelpForCurrentWord:) withObject:self afterDelay:0.1];
		return;
	}
	// Otherwise show Help if caret is not inside quotes
	NSUInteger cursorPosition = [self selectedRange].location;
	// If cursor at the end go one char leftwards
	if (cursorPosition > 0 && cursorPosition >= [[self string] length]) cursorPosition--;
	if (cursorPosition < [[self string] length] && ![(NSString*)NSMutableAttributedStringAttributeAtIndex([self textStorage], kQuote, cursorPosition, nil) length])
		[customQueryInstance performSelector:@selector(showAutoHelpForCurrentWord:) withObject:self afterDelay:0.1];

}

/**
 * Syntax Highlighting.
 *  
 * (The main bottleneck is the [NSTextStorage addAttribute:value:range:] method - the parsing itself is really fast!)
 * Some sample code from Andrew Choi ( http://members.shaw.ca/akochoi-old/blog/2003/11-09/index.html#3 ) has been reused.
 */
- (void)doSyntaxHighlighting
{

	NSTextStorage *textStore = [self textStorage];
	NSString *selfstr        = [self string];
	NSUInteger strlength     = [selfstr length];

	if(strlength > SP_MAX_TEXT_SIZE_FOR_SYNTAX_HIGHLIGHTING) return;

	NSRange textRange;

	// If text larger than SP_TEXT_SIZE_TRIGGER_FOR_PARTLY_PARSING
	// do highlighting partly (max SP_SYNTAX_HILITE_BIAS*2).
	// The approach is to take the middle position of the current view port
	// and highlight only ±SP_SYNTAX_HILITE_BIAS of that middle position
	// considering of line starts resp. ends
	if(strlength > SP_TEXT_SIZE_TRIGGER_FOR_PARTLY_PARSING)
	{

		// Get the text range currently displayed in the view port
		NSRect visibleRect = [[[self enclosingScrollView] contentView] documentVisibleRect];
		NSRange visibleRange = [[self layoutManager] glyphRangeForBoundingRectWithoutAdditionalLayout:visibleRect inTextContainer:[self textContainer]];

		if(!visibleRange.length) return;

		// Take roughly the middle position in the current view port
		NSUInteger curPos = visibleRange.location+(NSUInteger)(visibleRange.length/2);

		// get the last line to parse due to SP_SYNTAX_HILITE_BIAS
		// but look for only SP_SYNTAX_HILITE_BIAS chars forwards
		NSUInteger end = curPos + SP_SYNTAX_HILITE_BIAS;
		NSInteger lengthChecker = SP_SYNTAX_HILITE_BIAS;
		if (end > strlength ) {
			end = strlength;
		} else {
			while(end < strlength && lengthChecker > 0) {
				if(CFStringGetCharacterAtIndex((CFStringRef)selfstr, end)=='\n')
					break;
				end++;
				lengthChecker--;
			}
		}
		if(lengthChecker <= 0)
			end = curPos + SP_SYNTAX_HILITE_BIAS;

		// get the first line to parse due to SP_SYNTAX_HILITE_BIAS
		// but look for only SP_SYNTAX_HILITE_BIAS chars backwards
		NSUInteger start, start_temp;
		if(end <= (SP_SYNTAX_HILITE_BIAS*2))
		 	start = 0;
		else
		 	start = end - (SP_SYNTAX_HILITE_BIAS*2);

		start_temp = start;
		lengthChecker = SP_SYNTAX_HILITE_BIAS;
		if (start > 0)
			while(start>0 && lengthChecker > 0) {
				if(CFStringGetCharacterAtIndex((CFStringRef)selfstr, start)=='\n')
					break;
				start--;
				lengthChecker--;
			}
		if(lengthChecker <= 0)
			start = start_temp;

		textRange = NSMakeRange(start, end-start);

		// only to be sure that nothing went wrongly
		textRange = NSIntersectionRange(textRange, NSMakeRange(0, [textStore length])); 

		if (!textRange.length)
			return;

	} else {
		// If text size is less SP_TEXT_SIZE_TRIGGER_FOR_PARTLY_PARSING
		// process syntax highlighting for the entire text view buffer
		textRange = NSMakeRange(0,strlength);
	}

	// [textStore beginEditing];

	NSColor *tokenColor;

	size_t tokenEnd, token;
	NSRange tokenRange;

	// first remove the old colors and kQuote
	[textStore removeAttribute:NSForegroundColorAttributeName range:textRange];
	// mainly for suppressing auto-pairing in 
	[textStore removeAttribute:kLEXToken range:textRange];

	// initialise flex
	yyuoffset = textRange.location; yyuleng = 0;
	yy_switch_to_buffer(yy_scan_string(NSStringUTF8String([selfstr substringWithRange:textRange])));

	// NO if lexer doesn't find a token to suppress auto-uppercasing
	// and continue earlier.
	BOOL allowToCheckForUpperCase;
	
	// now loop through all the tokens
	while ((token=yylex())){

		allowToCheckForUpperCase = YES;
		
		switch (token) {
			case SPT_SINGLE_QUOTED_TEXT:
			case SPT_DOUBLE_QUOTED_TEXT:
			    tokenColor = quoteColor;
				allowToCheckForUpperCase = NO;
			    break;
			case SPT_RESERVED_WORD:
			    tokenColor = keywordColor;
			    break;
			case SPT_NUMERIC:
				tokenColor = numericColor;
				allowToCheckForUpperCase = NO;
				break;
			case SPT_BACKTICK_QUOTED_TEXT:
			    tokenColor = backtickColor;
				allowToCheckForUpperCase = NO;
			    break;
			case SPT_COMMENT:
			    tokenColor = commentColor;
				allowToCheckForUpperCase = NO;
			    break;
			case SPT_VARIABLE:
			    tokenColor = variableColor;
				allowToCheckForUpperCase = NO;
			    break;
			case SPT_WHITESPACE:
			    continue;
			    break;
			default:
			    tokenColor = otherTextColor;
				allowToCheckForUpperCase = NO;
		}

		tokenRange = NSMakeRange(yyuoffset, yyuleng);

		// make sure that tokenRange is valid (and therefore within textRange)
		// otherwise a bug in the lex code could cause the the TextView to crash
		// NOTE Disabled for testing purposes for speed it up
		tokenRange = NSIntersectionRange(tokenRange, textRange);
		if (!tokenRange.length) continue;

		// If the current token is marked as SQL keyword, uppercase it if required.
		tokenEnd = NSMaxRange(tokenRange) - 1;

		// Check the end of the token
		if (autouppercaseKeywordsEnabled 
			&& allowToCheckForUpperCase 
			&& textBufferSizeIncreased
			&& !delBackwardsWasPressed
			&& (tokenEnd+1) < strlength
			&& [(NSString*)NSMutableAttributedStringAttributeAtIndex(textStore, kSQLkeyword, tokenEnd, nil) length])
			// check if next char is not a kSQLkeyword or current kSQLkeyword is at the end; 
			// if so then upper case keyword if not already done
		{
	
			NSString* curTokenString = [selfstr substringWithRange:tokenRange];	
			if(![(NSString*)NSMutableAttributedStringAttributeAtIndex(textStore, kSQLkeyword,tokenEnd+1,nil) length])
			{
				NSString *curTokenStringUP = [curTokenString uppercaseString];
				if(![curTokenString isEqualToString:curTokenStringUP]) {
					// Register it for undo works only partly for now, at least the uppercased keyword will be selected
					[self shouldChangeTextInRange:tokenRange replacementString:curTokenStringUP];
					[self replaceCharactersInRange:tokenRange withString:curTokenStringUP];
				}
			}
		}

		NSMutableAttributedStringAddAttributeValueRange(textStore, NSForegroundColorAttributeName, tokenColor, tokenRange);
		
		// if(!allowToCheckForUpperCase) continue;
		
		// Add an attribute to be used in the auto-pairing (keyDown:)
		// to disable auto-pairing if caret is inside of any token found by lex.
		// For discussion: maybe change it later (only for quotes not keywords?)
		if(!allowToCheckForUpperCase && token < 6)
			NSMutableAttributedStringAddAttributeValueRange(textStore, kLEXToken, kLEXTokenValue, tokenRange);
		
		// Mark each SQL keyword for auto-uppercasing and do it for the next textStorageDidProcessEditing: event.
		// Performing it one token later allows words which start as reserved keywords to be entered.
		if(token == SPT_RESERVED_WORD)
			NSMutableAttributedStringAddAttributeValueRange(textStore, kSQLkeyword, kValue, tokenRange);
		
		// Add an attribute to be used to distinguish quotes from keywords etc.
		// used e.g. in completion suggestions
		else if(token < 4)
			NSMutableAttributedStringAddAttributeValueRange(textStore, kQuote, kQuoteValue, tokenRange);
		
		//distinguish backtick quoted word for completion
		// else if(token == SPT_BACKTICK_QUOTED_TEXT)
		// 	NSMutableAttributedStringAddAttributeValueRange(textStore, kBTQuote, kBTQuoteValue, tokenRange);

	}

	// [textStore endEditing];

	[self setNeedsDisplayInRect:[self bounds]];

}

- (void) setTabStops
{
#ifndef SP_CODA
	NSFont *tvFont = [self font];
#else
	NSFont* tvFont = [NSFont userFixedPitchFontOfSize:10.0];
#endif
	NSInteger i;
	NSTextTab *aTab;
	NSMutableArray *myArrayOfTabs;
	NSMutableParagraphStyle *paragraphStyle;

	BOOL oldEditableStatus = [self isEditable];
	[self setEditable:YES];

#ifndef SP_CODA
	NSInteger tabStopWidth = [prefs integerForKey:SPCustomQueryEditorTabStopWidth];
#else
	NSInteger tabStopWidth = 4;
#endif
	if(tabStopWidth < 1) tabStopWidth = 1;

	float tabWidth = NSSizeToCGSize([@" " sizeWithAttributes:@{NSFontAttributeName : tvFont}]).width;
	tabWidth = (float)tabStopWidth * tabWidth;

	NSInteger numberOfTabs = 256/tabStopWidth;
	myArrayOfTabs = [NSMutableArray arrayWithCapacity:numberOfTabs];
	aTab = [[NSTextTab alloc] initWithType:NSLeftTabStopType location:tabWidth];
	[myArrayOfTabs addObject:aTab];
	[aTab release];
	for(i=1; i<numberOfTabs; i++) {
		aTab = [[NSTextTab alloc] initWithType:NSLeftTabStopType location:tabWidth + ((float)i * tabWidth)];
		[myArrayOfTabs addObject:aTab];
		[aTab release];
	}
	paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[paragraphStyle setTabStops:myArrayOfTabs];
	// Soft wrapped lines are indented slightly
	[paragraphStyle setHeadIndent:4.0f];

	NSMutableDictionary *textAttributes = [[[NSMutableDictionary alloc] initWithCapacity:1] autorelease];
	[textAttributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];

	NSRange range = NSMakeRange(0, [[self textStorage] length]);
	if ([self shouldChangeTextInRange:range replacementString:nil]) {
		[[self textStorage] setAttributes:textAttributes range: range];
		[self didChangeText];
	}
	[self setTypingAttributes:textAttributes];
	[self setDefaultParagraphStyle:paragraphStyle];
	[self setFont:tvFont];

	[self setEditable:oldEditableStatus];

	[paragraphStyle release];
}

- (void)drawViewBackgroundInRect:(NSRect)rect {
	[super drawViewBackgroundInRect:rect];

	// Draw background only for screen display but not while printing, and only if view
	// background drawing is enabled.
	if([NSGraphicsContext currentContextDrawingToScreen] && [self drawsBackground]) {

		// Draw textview's background since due to the snippet highlighting we're responsible for it.
		[[self queryEditorBackgroundColor] setFill];
		NSRectFillUsingOperation(rect, NSCompositeSourceOver);

		if([[self delegate] isKindOfClass:[SPCustomQuery class]]) {

			// Highlights the current query if set in the Pref and no snippet session
			// and if nothing is selected in the text view
			if ([self shouldHiliteQuery] && snippetControlCounter<=-1 && ![self selectedRange].length && [[self string] length] < SP_MAX_TEXT_SIZE_FOR_SYNTAX_HIGHLIGHTING) {
				NSUInteger rectCount;
				[[self textStorage] ensureAttributesAreFixedInRange:[self queryRange]];
				NSRectArray queryRects = [[self layoutManager] rectArrayForCharacterRange: [self queryRange]
															 withinSelectedCharacterRange: [self queryRange]
																		  inTextContainer: [self textContainer]
																				rectCount: &rectCount ];
				[[self queryHiliteColor] setFill];
				NSRectFillListUsingOperation(queryRects, rectCount, NSCompositeSourceOver);
			}

			// Highlight snippets coming from the Query Favorite text macro
			if(snippetControlCounter > -1) {
				// Is the caret still inside a snippet
				if([self checkForCaretInsideSnippet]) {
					for(NSInteger i=0; i<snippetControlMax; i++) {
						if(snippetControlArray[i].location > -1) {
							// choose the colors for the snippet parts
							if(i == currentSnippetIndex) {
								[[NSColor colorWithCalibratedRed:1.0f green:0.6f blue:0.0f alpha:0.4f] setFill];
								[[NSColor colorWithCalibratedRed:1.0f green:0.6f blue:0.0f alpha:0.8f] setStroke];
							} else {
								[[NSColor colorWithCalibratedRed:1.0f green:0.8f blue:0.2f alpha:0.2f] setFill];
								[[NSColor colorWithCalibratedRed:1.0f green:0.8f blue:0.2f alpha:0.5f] setStroke];
							}
							NSBezierPath *snippetPath = [self roundedBezierPathAroundRange: NSMakeRange(snippetControlArray[i].location,snippetControlArray[i].length) ];
							[snippetPath fill];
							[snippetPath stroke];
						}
					}
				} else {
					[self endSnippetSession];
				}
			}

		}
	}
}

- (NSBezierPath*)roundedBezierPathAroundRange:(NSRange)aRange
{
	// parameters for snippet highlighting
	CGFloat kappa = 0.5522847498f; // magic number from http://www.whizkidtech.redprince.net/bezier/circle/
	CGFloat radius = 6;
	CGFloat horzInset = -3;
	CGFloat vertInset = 0.3f;
	BOOL connectDisconnectedPartsWithLine = NO;

	NSBezierPath *funkyPath = [NSBezierPath bezierPath];
	NSUInteger rectCount;
	NSRectArray rects = [[self layoutManager] rectArrayForCharacterRange: aRange
											withinSelectedCharacterRange: aRange
														 inTextContainer: [self textContainer]
															   rectCount: &rectCount ];
	if (rectCount>2 || (rectCount>1 && (SPRectRight(rects[1]) >= SPRectLeft(rects[0]) || connectDisconnectedPartsWithLine))) {
		// highlight complicated multiline snippet
		NSRect lineRects[4];
		lineRects[0] = rects[0];
		lineRects[1] = rects[1];
		lineRects[2] = rects[rectCount-2];
		lineRects[3] = rects[rectCount-1];
		for(int j=0;j<4;j++) lineRects[j] = NSInsetRect(lineRects[j], horzInset, vertInset);
		NSPoint vertices[8];
		vertices[0] = NSMakePoint( SPRectLeft(lineRects[0]),  SPRectTop(lineRects[0])    ); // point a
		vertices[1] = NSMakePoint( SPRectRight(lineRects[0]), SPRectTop(lineRects[0])    ); // point b
		vertices[2] = NSMakePoint( SPRectRight(lineRects[2]), SPRectBottom(lineRects[2]) ); // point c
		vertices[3] = NSMakePoint( SPRectRight(lineRects[3]), SPRectBottom(lineRects[2]) ); // point d
		vertices[4] = NSMakePoint( SPRectRight(lineRects[3]), SPRectBottom(lineRects[3]) ); // point e
		vertices[5] = NSMakePoint( SPRectLeft(lineRects[3]),  SPRectBottom(lineRects[3]) ); // point f
		vertices[6] = NSMakePoint( SPRectLeft(lineRects[1]),  SPRectTop(lineRects[1])    ); // point g
		vertices[7] = NSMakePoint( SPRectLeft(lineRects[0]),  SPRectTop(lineRects[1])    ); // point h

		for (NSUInteger j=0; j<8; j++) {
			NSPoint curr = vertices[j];
			NSPoint prev = vertices[(j+8-1)%8];
			NSPoint next = vertices[(j+1)%8];

			CGFloat s = radius/SPPointDistance(prev, curr);
			if (s>0.5) s = 0.5f;
			CGFloat t = radius/SPPointDistance(curr, next);
			if (t>0.5) t = 0.5f;

			NSPoint a = SPPointOnLine(curr, prev, 0.5f);
			NSPoint b = SPPointOnLine(curr, prev, s);
			NSPoint c = curr;
			NSPoint d = SPPointOnLine(curr, next, t);
			NSPoint e = SPPointOnLine(curr, next, 0.5f);

			if (j==0) [funkyPath moveToPoint:a];
			[funkyPath lineToPoint: b];
			[funkyPath curveToPoint:d controlPoint1:SPPointOnLine(b, c, kappa) controlPoint2:SPPointOnLine(d, c, kappa)];
			[funkyPath lineToPoint: e];
		}
	} else {
		//highlight disconnected snippet parts (or single line snippet)
		for (NSUInteger j=0; j<rectCount; j++) {
			NSRect rect = rects[j];
			rect = NSInsetRect(rect, horzInset, vertInset);
			[funkyPath appendBezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];
		}
	}
	return funkyPath;
}


#pragma mark -
#pragma mark context menu

/**
 * Add a menu item to context menu for looking up mysql documentation.
 */
- (NSMenu *)menuForEvent:(NSEvent *)event 
{	
#ifndef SP_CODA
	// Set title of the menu item
	if([self selectedRange].length)
		showMySQLHelpFor = NSLocalizedString(@"MySQL Help for Selection", @"MySQL Help for Selection");
	else
		showMySQLHelpFor = NSLocalizedString(@"MySQL Help for Word", @"MySQL Help for Word");
#endif
	
	// Add the menu items for
	// - MySQL Help for Word/Selection
	// - Copy as RTF
	// - Select Active Query
	// if it doesn't yet exist
	NSMenu *menu = [[self class] defaultMenu];
	
#ifndef SP_CODA
	if ([[[self class] defaultMenu] itemWithTag:SP_CQ_SEARCH_IN_MYSQL_HELP_MENU_ITEM_TAG] == nil)
	{
		[menu insertItem:[NSMenuItem separatorItem] atIndex:3];
		NSMenuItem *showMySQLHelpForMenuItem = [[NSMenuItem alloc] initWithTitle:showMySQLHelpFor action:@selector(showMySQLHelpForCurrentWord:) keyEquivalent:@"h"];
		[showMySQLHelpForMenuItem setTag:SP_CQ_SEARCH_IN_MYSQL_HELP_MENU_ITEM_TAG];
		[showMySQLHelpForMenuItem setKeyEquivalentModifierMask:NSEventModifierFlagControl];
		[menu insertItem:showMySQLHelpForMenuItem atIndex:4];
		[showMySQLHelpForMenuItem release];
	} else {
		[[menu itemWithTag:SP_CQ_SEARCH_IN_MYSQL_HELP_MENU_ITEM_TAG] setTitle:showMySQLHelpFor];
	}
#endif
	if ([[[self class] defaultMenu] itemWithTag:SP_CQ_COPY_AS_RTF_MENU_ITEM_TAG] == nil)
	{
		NSMenuItem *copyAsRTFMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Copy as RTF", @"Copy as RTF") action:@selector(copyAsRTF) keyEquivalent:@""];
		[copyAsRTFMenuItem setTag:SP_CQ_COPY_AS_RTF_MENU_ITEM_TAG];
		[menu insertItem:copyAsRTFMenuItem atIndex:2];
		[copyAsRTFMenuItem release];
	}
	if ([[[self class] defaultMenu] itemWithTag:SP_CQ_SELECT_CURRENT_QUERY_MENU_ITEM_TAG] == nil)
	{
		NSMenuItem *selectCurrentQueryMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Select Active Query", @"Select Active Query") action:@selector(selectCurrentQuery:) keyEquivalent:@""];
		[selectCurrentQueryMenuItem setTag:SP_CQ_SELECT_CURRENT_QUERY_MENU_ITEM_TAG];
		[menu insertItem:selectCurrentQueryMenuItem atIndex:4];
		[selectCurrentQueryMenuItem release];
	}
	// Hide "Select Active Query" if self is not editable
	[[menu itemAtIndex:4] setHidden:![self isEditable]];
	
	if(customQueryInstance) {
		[[menu itemAtIndex:5] setHidden:NO];
		[[menu itemAtIndex:6] setHidden:NO];
	} else {
		[[menu itemAtIndex:5] setHidden:YES];
		[[menu itemAtIndex:6] setHidden:YES];
	}

#ifndef SP_CODA
	[SPAppDelegate reloadBundles:self];

	// Remove 'Bundles' sub menu and separator
	NSMenuItem *bItem = [menu itemWithTag:10000000];
	if(bItem) {
		NSInteger sepIndex = [menu indexOfItem:bItem]-1;
		[menu removeItemAtIndex:sepIndex];
		[menu removeItem:bItem];
	}

	NSArray *bundleCategories = [SPAppDelegate bundleCategoriesForScope:SPBundleScopeInputField];
	NSArray *bundleItems = [SPAppDelegate bundleItemsForScope:SPBundleScopeInputField];

	// Add 'Bundles' sub menu for custom query editor only so far if bundles with scope 'editor' were found
	if(customQueryInstance && bundleItems && [bundleItems count]) {
		[menu addItem:[NSMenuItem separatorItem]];

		NSMenu *bundleMenu = [[[NSMenu alloc] init] autorelease];
		NSMenuItem *bundleSubMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Bundles", @"bundles menu item label") action:nil keyEquivalent:@""];
		[bundleSubMenuItem setTag:10000000];

		[menu addItem:bundleSubMenuItem];
		[menu setSubmenu:bundleMenu forItem:bundleSubMenuItem];

		NSMutableArray *categorySubMenus = [NSMutableArray array];
		NSMutableArray *categoryMenus = [NSMutableArray array];
		if([bundleCategories count]) {
			for(NSString* title in bundleCategories) {
				[categorySubMenus addObject:[[[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""] autorelease]];
				[categoryMenus addObject:[[[NSMenu alloc] init] autorelease]];
				[bundleMenu addItem:[categorySubMenus lastObject]];
				[bundleMenu setSubmenu:[categoryMenus lastObject] forItem:[categorySubMenus lastObject]];
			}
		}

		NSInteger i = 0;
		for(NSDictionary *item in bundleItems) {

			NSString *keyEq;
			if([item objectForKey:SPBundleFileKeyEquivalentKey])
				keyEq = [[item objectForKey:SPBundleFileKeyEquivalentKey] objectAtIndex:0];
			else
				keyEq = @"";

			NSMenuItem *mItem = [[[NSMenuItem alloc] initWithTitle:[item objectForKey:SPBundleInternLabelKey] action:@selector(executeBundleItemForInputField:) keyEquivalent:keyEq] autorelease];

			if([keyEq length])
				[mItem setKeyEquivalentModifierMask:[[[item objectForKey:SPBundleFileKeyEquivalentKey] objectAtIndex:1] intValue]];

			if([item objectForKey:SPBundleFileTooltipKey])
				[mItem setToolTip:[item objectForKey:SPBundleFileTooltipKey]];

			[mItem setTag:1000000 + i++];

			if([item objectForKey:SPBundleFileCategoryKey]) {
				[[categoryMenus objectAtIndex:[bundleCategories indexOfObject:[item objectForKey:SPBundleFileCategoryKey]]] addItem:mItem];
			} else {
				[bundleMenu addItem:mItem];
			}
		}

		[bundleSubMenuItem release];

	}
#endif

	return menu;

}

/**
 * Menu validation
 * Disable the search in the MySQL help function when getRangeForCurrentWord returns zero length. 
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem 
{
	// Enable or disable the search in the MySQL help menu item depending on whether there is a
	// selection and whether it is a reasonable length.
	if ([menuItem action] == @selector(showMySQLHelpForCurrentWord:)) {
		if ([self selectedRange].length > 0) {
			[menuItem setTitle:NSLocalizedString(@"MySQL Help for Selection", @"MySQL Help for Selection")];
		} else {
			[menuItem setTitle: NSLocalizedString(@"MySQL Help for Word", @"MySQL Help for Word")];
		}
		NSUInteger stringSize = [self getRangeForCurrentWord].length;
		return (0 < stringSize && stringSize < 65); // 1 ≤ stringSize ≤ 64
	}
	// Enable Copy as RTF if something is selected
	if ([menuItem action] == @selector(copyAsRTF)) {
		return ([self selectedRange].length>0);
	}
	// Validate Select Active Query
	if ([menuItem action] == @selector(selectCurrentQuery:)) {
		return ([self isEditable] && [[self delegate] isKindOfClass:[SPCustomQuery class]]);
	}
	// Disable "Copy with Column Names" and "Copy as SQL INSERT"
	// in the main menu
	if ( [menuItem tag] == SPEditMenuCopyWithColumns
		|| [menuItem tag] == SPEditMenuCopyAsSQL) {
		return NO;
	}

	return [super validateMenuItem:menuItem];
}

/**
 * Selection range changes
 * Listen to selection range change events and use changes of state between selection and no
 * selection to redraw the hilight state
 */
- (NSRange)selectionRangeForProposedRange:(NSRange)proposedSelRange granularity:(NSSelectionGranularity)granularity
{
	NSUInteger currentSelectionLength = [self selectedRange].length;

	// If selection started/ended, redraw the background in the current query area
	if ([self shouldHiliteQuery] && ((currentSelectionLength && !proposedSelRange.length) || (!currentSelectionLength && proposedSelRange.length))) {
		NSUInteger i = 0, rectCount = 0;
		NSRect* rectsToUpdate = [[self layoutManager] rectArrayForCharacterRange:[self queryRange]
		                                                withinSelectedCharacterRange:[self queryRange]
		                                                             inTextContainer:[self textContainer]
		                                                                   rectCount:&rectCount];
		for (i = 0; i < rectCount; i++) {
			[self setNeedsDisplayInRect:rectsToUpdate[i]];
		}
	}

	return [super selectionRangeForProposedRange:proposedSelRange granularity:granularity];
}

#pragma mark -
#pragma mark delegates

/**
 * Scrollview delegate after the textView's view port was changed.
 * Manily used to update the syntax highlighting for a large text size and line numbering rendering.
 */
- (void)boundsDidChangeNotification:(NSNotification *)notification
{
	// Invoke syntax highlighting if text view port was changed for large text
	if(startListeningToBoundChanges && [[self string] length] > SP_TEXT_SIZE_TRIGGER_FOR_PARTLY_PARSING)
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
									selector:@selector(doSyntaxHighlighting) 
									object:nil];
		
		if(![[self textStorage] changeInLength])
			[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.4];
	}
	// else
	// 	[scrollView displayRect:[scrollView visibleRect]];

}

/**
 *  Performs syntax highlighting, re-init autohelp, and re-calculation of snippets after a text change
 */
- (void)textStorageDidProcessEditing:(NSNotification *)notification
{

	NSTextStorage *textStore = [notification object];

	// Make sure that the notification is from the correct textStorage object
	if (textStore!=[self textStorage]) return;

	// Cancel autocompletion trigger
#ifndef SP_CODA
	if([prefs boolForKey:SPCustomQueryAutoComplete])
#endif
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
								selector:@selector(doAutoCompletion) 
								object:nil];

	// Cancel calling doSyntaxHighlighting for large text
	if([[self string] length] > SP_TEXT_SIZE_TRIGGER_FOR_PARTLY_PARSING)
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
								selector:@selector(doSyntaxHighlighting) 
								object:nil];

	NSInteger editedMask = [textStore editedMask];

	// Start autohelp only if the user really changed the text (not e.g. for setting a background color)
#ifndef SP_CODA
	if([prefs boolForKey:SPCustomQueryUpdateAutoHelp] && editedMask != 1) {
		[self performSelector:@selector(autoHelp) withObject:nil afterDelay:[[prefs valueForKey:SPCustomQueryAutoHelpDelay] doubleValue]];
	}
#endif

	// Start autocompletion if enabled
#ifndef SP_CODA
	if([[NSApp keyWindow] firstResponder] == self && [prefs boolForKey:SPCustomQueryAutoComplete] && !completionIsOpen && editedMask != 1 && [textStore changeInLength] == 1)
		[self performSelector:@selector(doAutoCompletion) withObject:nil afterDelay:[[prefs valueForKey:SPCustomQueryAutoCompleteDelay] doubleValue]];
#else
	if([[NSApp keyWindow] firstResponder] == self && !completionIsOpen && editedMask != 1 && [textStore changeInLength] == 1)
		[self performSelector:@selector(doAutoCompletion) withObject:nil afterDelay:1.5];
#endif

	// Do syntax highlighting/re-calculate snippet ranges only if the user really changed the text
	if(editedMask != 1) {

		[customQueryInstance setTextViewWasChanged:YES];

		// Re-calculate snippet ranges if snippet session is active
		if(snippetControlCounter > -1 && !snippetWasJustInserted && !isProcessingMirroredSnippets) {
			// Remove any fully nested snippets relative to the current snippet which was edited
			SnippetControlInfo *currentSnippetRef = &snippetControlArray[currentSnippetIndex];
			NSInteger currentSnippetLocation = currentSnippetRef->location;
			NSInteger currentSnippetMaxRange = currentSnippetRef->location + currentSnippetRef->length;
			NSInteger i;
			for(i=0; i<snippetControlMax; i++) {
				if(snippetControlArray[i].location > -1
					&& i != currentSnippetIndex
					&& snippetControlArray[i].location >= currentSnippetLocation
					&& snippetControlArray[i].location <= currentSnippetMaxRange
					&& snippetControlArray[i].location + snippetControlArray[i].length >= currentSnippetLocation
					&& snippetControlArray[i].location + snippetControlArray[i].length <= currentSnippetMaxRange
					) {
						snippetControlArray[i] = (SnippetControlInfo){-1, -1, -1};
				}
			}

			NSInteger editStartPosition = [textStore editedRange].location;
			NSUInteger changeInLength = [textStore changeInLength];

			// Adjust length change to current snippet
			currentSnippetRef->length += changeInLength;
			// If length < 0 break snippet input
			if(currentSnippetRef->length < 0) {
				[self endSnippetSession];
			} else {
				// Adjust start position of snippets after caret position
				for(i=0; i<=snippetControlMax; i++) {
					if(snippetControlArray[i].location > -1 && i != currentSnippetIndex) {
						if(editStartPosition < snippetControlArray[i].location) {
							snippetControlArray[i].location += changeInLength;
						} else if(editStartPosition >= snippetControlArray[i].location && editStartPosition <= snippetControlArray[i].location + snippetControlArray[i].length) {
							snippetControlArray[i].length += changeInLength;
						}
					}
				}
				// Adjust start position of mirrored snippets after caret position
				if(mirroredCounter > -1)
					for(i=0; i<=mirroredCounter; i++) {
						if(editStartPosition < snippetMirroredControlArray[i].location) {
							snippetMirroredControlArray[i].location += changeInLength;
						}
					}
			}

			if(mirroredCounter > -1 && snippetControlCounter > -1) {
				[self performSelector:@selector(processMirroredSnippets) withObject:nil afterDelay:0.0];
			}

			
		}
		if([textStore changeInLength] > 0)
			textBufferSizeIncreased = YES;
		else
			textBufferSizeIncreased = NO;

		if([textStore changeInLength] < SP_TEXT_SIZE_TRIGGER_FOR_PARTLY_PARSING)
			[self doSyntaxHighlighting];

	} else {
		[customQueryInstance setTextViewWasChanged:NO];
		textBufferSizeIncreased = NO;
	}

	startListeningToBoundChanges = YES;

}

/**
 * Set font panel's valid modes
 */
- (NSFontPanelModeMask)validModesForFontPanel:(NSFontPanel *)fontPanel
{
	return (NSFontPanelSizeModeMask|NSFontPanelCollectionModeMask);
}

#pragma mark -
#pragma mark drag&drop

/**
 * Insert the content of a dragged file path or if ⌘ is pressed
 * while dragging insert the file path
 */
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = [sender draggingPasteboard];

	if ( [[pboard types] containsObject:NSFilenamesPboardType] && [[pboard types] containsObject:@"CorePasteboardFlavorType 0x54455854"])
		return [super performDragOperation:sender];

	if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
		NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];

		// Only one file path is allowed
		if([files count] > 1) {
			NSLog(@"%@", NSLocalizedString(@"Only one dragged item allowed.",@"Only one dragged item allowed."));
			return YES;
		}

		NSString *filepath = [[pboard propertyListForType:NSFilenamesPboardType] objectAtIndex:0];
		// if (([filenamesAttributes fileHFSTypeCode] == 'clpt' && [filenamesAttributes fileHFSCreatorCode] == 'MACS') || [[filename pathExtension] isEqualToString:@"textClipping"] == YES) {
		// 	
		// }


		// Set the new insertion point
		NSPoint draggingLocation = [sender draggingLocation];
		draggingLocation = [self convertPoint:draggingLocation fromView:nil];
		NSUInteger characterIndex = [self characterIndexOfPoint:draggingLocation];
		[self setSelectedRange:NSMakeRange(characterIndex,0)];

		// Check if user pressed  ⌘ while dragging for inserting only the file path
		if([sender draggingSourceOperationMask] == 4)
		{
			[self insertText:filepath];
			return YES;
		}

		// Check size and NSFileType
		NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:filepath error:nil];

		if(attr)
		{
			NSNumber *filesize = [attr objectForKey:NSFileSize];
			NSString *filetype = [attr objectForKey:NSFileType];
			if(filetype == NSFileTypeRegular && filesize)
			{
				// Ask for confirmation if file content is larger than 1MB
				if([filesize unsignedLongValue] > 1000000)
				{
					NSAlert *alert = [[NSAlert alloc] init];
					[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK button")];
					[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];
					[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Do you really want to proceed with %@ of data?", @"message of panel asking for confirmation for inserting large text from dragging action"),
						[NSString stringForByteSize:[filesize longLongValue]]]];
					[alert setHelpAnchor:filepath];
					[alert setMessageText:NSLocalizedString(@"Warning",@"warning")];
					[alert setAlertStyle:NSWarningAlertStyle];
					[alert beginSheetModalForWindow:[self window] 
						modalDelegate:self 
						didEndSelector:@selector(dragAlertSheetDidEnd:returnCode:contextInfo:) 
						contextInfo:nil];
					[alert release];
					
				} else
					[self insertFileContentOfFile:filepath];
			}
		}
		return YES;
	} 
	
	// Insert selected items coming from the Navigator
	if ( [[pboard types] containsObject:SPNavigatorPasteboardDragType] ) {
		NSPoint draggingLocation = [sender draggingLocation];
		draggingLocation = [self convertPoint:draggingLocation fromView:nil];
		NSUInteger characterIndex = [self characterIndexOfPoint:draggingLocation];
		[self setSelectedRange:NSMakeRange(characterIndex,0)];

		NSKeyedUnarchiver *unarchiver = [[[NSKeyedUnarchiver alloc] initForReadingWithData:[pboard dataForType:SPNavigatorPasteboardDragType]] autorelease];
		NSArray *draggedItems = [[NSArray alloc] initWithArray:(NSArray *)[unarchiver decodeObjectForKey:@"itemdata"]];
		[unarchiver finishDecoding];

		NSMutableString *dragString = [NSMutableString string];
		NSMutableString *aPath = [NSMutableString string];

		NSString *currentDb = nil;
		NSString *currentTable = nil;

		if (tablesListInstance && [tablesListInstance selectedDatabase])
			currentDb = [tablesListInstance selectedDatabase];
		if (tablesListInstance && [tablesListInstance tableName])
			currentTable = [tablesListInstance tableName];

		if(!currentDb) currentDb = @"";
		if(!currentTable) currentTable = @"";

		for(NSString* item in draggedItems) {
			if([dragString length]) [dragString appendString:@", "];
			[aPath setString:item];
			// Insert path relative to the current selected db and table if any
			[aPath replaceOccurrencesOfRegex:[NSString stringWithFormat:@"^%@%@", currentDb, SPUniqueSchemaDelimiter] withString:@""];
			[aPath replaceOccurrencesOfRegex:[NSString stringWithFormat:@"^%@%@", currentTable, SPUniqueSchemaDelimiter] withString:@""];
			[dragString appendString:[[aPath componentsSeparatedByString:SPUniqueSchemaDelimiter] componentsJoinedByPeriodAndBacktickQuoted]];
		}
		[self breakUndoCoalescing];
		[self insertText:dragString];
		if (draggedItems) [draggedItems release];
		return YES;
	}

	return [super performDragOperation:sender];
}

/**
 * Confirmation sheetDidEnd method
 */
- (void)dragAlertSheetDidEnd:(NSAlert *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{

	[[sheet window] orderOut:nil];
	if ( returnCode == NSAlertFirstButtonReturn )
		[self insertFileContentOfFile:[sheet helpAnchor]];

}
/**
 * Convert a NSPoint, usually the mouse location, to
 * a character index of the text view.
 */
- (NSUInteger)characterIndexOfPoint:(NSPoint)aPoint
{
	NSUInteger glyphIndex;
	NSLayoutManager *layoutManager = [self layoutManager];
	CGFloat fractionalDistance;
	NSRange range;

	range = [layoutManager glyphRangeForTextContainer:[self textContainer]];
	glyphIndex = [layoutManager glyphIndexForPoint:aPoint
		inTextContainer:[self textContainer]
		fractionOfDistanceThroughGlyph:&fractionalDistance];
	if( fractionalDistance > 0.5 ) glyphIndex++;

	if( glyphIndex == NSMaxRange(range) )
		return  [[self textStorage] length];
	else
		return [layoutManager characterIndexForGlyphAtIndex:glyphIndex];

}

/**
 * Insert content of a plain text file for a given path.
 * In addition it tries to figure out the file's text encoding heuristically.
 */
- (void)insertFileContentOfFile:(NSString *)aPath
{
	
	NSError *err = nil;
	NSStringEncoding enc;
	NSString *content = nil;

	// Make usage of the UNIX command "file" to get an info
	// about file type and encoding.
	NSTask *aTask=[[NSTask alloc] init];
	NSPipe *aPipe=[[NSPipe alloc] init];
	NSFileHandle *handle;
	NSString *result;
	[aTask setLaunchPath:@"/usr/bin/file"];
	[aTask setArguments:[NSArray arrayWithObjects:aPath, @"-Ib", nil]];
	[aTask setStandardOutput:aPipe];
	handle=[aPipe fileHandleForReading];
	[aTask launch];
	result=[[NSString alloc] initWithData:[handle readDataToEndOfFile]
		encoding:NSASCIIStringEncoding];

	[aPipe release];
	[aTask release];

	// UTF16/32 files are detected as application/octet-stream resp. audio/mpeg
	if( [result hasPrefix:@"text/plain"] 
		|| [[[aPath pathExtension] lowercaseString] isEqualToString:SPFileExtensionSQL] 
		|| [[[aPath pathExtension] lowercaseString] isEqualToString:@"txt"]
		|| [result hasPrefix:@"audio/mpeg"] 
		|| [result hasPrefix:@"application/octet-stream"]
	)
	{
		// if UTF16/32 cocoa will try to find the correct encoding
		if([result hasPrefix:@"application/octet-stream"] || [result hasPrefix:@"audio/mpeg"] || [result rangeOfString:@"utf-16"].length)
			enc = 0;
		else if([result rangeOfString:@"utf-8"].length)
			enc = NSUTF8StringEncoding;
		else if([result rangeOfString:@"iso-8859-1"].length)
			enc = NSISOLatin1StringEncoding;
		else if([result rangeOfString:@"us-ascii"].length)
			enc = NSASCIIStringEncoding;
		else 
			enc = 0;

		if(enc == 0) // cocoa tries to detect the encoding
			content = [NSString stringWithContentsOfFile:aPath usedEncoding:&enc error:&err];
		else
			content = [NSString stringWithContentsOfFile:aPath encoding:enc error:&err];

		if(content)
		{
			[self insertText:content];
			[result release];
			// [self insertText:@""]; // Invoke keyword uppercasing
			return;
		}
		// If UNIX "file" failed try cocoa's encoding detection
		content = [NSString stringWithContentsOfFile:aPath encoding:enc error:&err];
		if(content)
		{
			[self insertText:content];
			[result release];
			// [self insertText:@""]; // Invoke keyword uppercasing
			return;
		}
	}
	
	[result release];

	NSLog(@"%@ ‘%@’.", NSLocalizedString(@"Couldn't read the file content of", @"Couldn't read the file content of"), aPath);
}

// Do nothing if NSColorPanel was opened from the NSTextView
- (void)changeColor:(id)sender
{
	return;
}

- (void)changeFont:(id)sender
{
#ifndef SP_CODA
	if (prefs && [self font] != nil) {
		[prefs setObject:[NSArchiver archivedDataWithRootObject:[self font]] forKey:SPCustomQueryEditorFont];
		NSFont *nf = [[NSFontPanel sharedFontPanel] panelConvertFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorFont]]];
		BOOL oldEditable = [self isEditable];
		[self setEditable:YES];
		[self setFont:nf];
		[self setEditable:oldEditable];
		[self setNeedsDisplayInRect:[self bounds]];
		[prefs setObject:[NSArchiver archivedDataWithRootObject:nf] forKey:SPCustomQueryEditorFont];
	}
#endif
}

#pragma mark -

- (void) dealloc
{

	// Cancel any deferred calls
	[NSObject cancelPreviousPerformRequestsWithTarget:self];

	// Remove observers
	[[NSNotificationCenter defaultCenter] removeObserver:self];
#ifndef SP_CODA
	[prefs removeObserver:self forKeyPath:SPCustomQueryEditorSelectionColor];
	[prefs removeObserver:self forKeyPath:SPCustomQueryEditorCaretColor];
	[prefs removeObserver:self forKeyPath:SPCustomQueryEditorFont];
	[prefs removeObserver:self forKeyPath:SPCustomQueryEditorBackgroundColor];
	[prefs removeObserver:self forKeyPath:SPCustomQueryEditorHighlightQueryColor];
	[prefs removeObserver:self forKeyPath:SPCustomQueryHighlightCurrentQuery];
	[prefs removeObserver:self forKeyPath:SPCustomQueryEditorCommentColor];
	[prefs removeObserver:self forKeyPath:SPCustomQueryEditorQuoteColor];
	[prefs removeObserver:self forKeyPath:SPCustomQueryEditorSQLKeywordColor];
	[prefs removeObserver:self forKeyPath:SPCustomQueryEditorBacktickColor];
	[prefs removeObserver:self forKeyPath:SPCustomQueryEditorNumericColor];
	[prefs removeObserver:self forKeyPath:SPCustomQueryEditorVariableColor];
	[prefs removeObserver:self forKeyPath:SPCustomQueryEditorTextColor];
	[prefs removeObserver:self forKeyPath:SPCustomQueryEditorTabStopWidth];
	[prefs removeObserver:self forKeyPath:SPCustomQueryAutoUppercaseKeywords];
#endif

	if (completionIsOpen) [completionPopup close], completionIsOpen = NO;
#ifndef SP_CODA
	SPClear(prefs);
#endif
	SPClear(lineNumberView);
	if(queryHiliteColor)           SPClear(queryHiliteColor);
	if(queryEditorBackgroundColor) SPClear(queryEditorBackgroundColor);
	if(commentColor)               SPClear(commentColor);
	if(quoteColor)                 SPClear(quoteColor);
	if(keywordColor)               SPClear(keywordColor);
	if(backtickColor)              SPClear(backtickColor);
	if(numericColor)               SPClear(numericColor);
	if(variableColor)              SPClear(variableColor);
	if(otherTextColor)             SPClear(otherTextColor);
	[super dealloc];
}

#pragma mark -
#pragma mark Private API

/**
 * Sort function (mainly used to sort the words in the textView)
 */
NSInteger _alphabeticSort(id string1, id string2, void *reverse)
{
	return [string1 localizedCaseInsensitiveCompare:string2];
}

#ifndef SP_CODA
/**
 * Take a supplied text selection colour, and if it contains an alpha component,
 * pre-multiply it by the background colour before setting it to avoid drawing problems.
 */
- (void)_setTextSelectionColor:(NSColor *)newSelectionColor onBackgroundColor:(NSColor *)aBackgroundColor
{

	// If the selection colour has an alpha component, modify it
	if ([newSelectionColor alphaComponent] < 1.f) {
		NSColorSpace *rgbColorSpace = [NSColorSpace genericRGBColorSpace];

		newSelectionColor = [newSelectionColor colorUsingColorSpace:rgbColorSpace];
		NSColor *backgroundColor = [[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorBackgroundColor]] colorUsingColorSpace:rgbColorSpace];

		CGFloat modifiedRedComponent = ([backgroundColor redComponent] * (1.f - [newSelectionColor alphaComponent])) + ([newSelectionColor redComponent] * [newSelectionColor alphaComponent]);
		CGFloat modifiedGreenComponent = ([backgroundColor greenComponent] * (1.f - [newSelectionColor alphaComponent])) + ([newSelectionColor greenComponent] * [newSelectionColor alphaComponent]);
		CGFloat modifiedBlueComponent = ([backgroundColor blueComponent] * (1.f - [newSelectionColor alphaComponent])) + ([newSelectionColor blueComponent] * [newSelectionColor alphaComponent]);
		newSelectionColor = [NSColor colorWithDeviceRed:modifiedRedComponent green:modifiedGreenComponent blue:modifiedBlueComponent alpha:1.f];
	}

	// Set the selection colour
	[self setSelectedTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:newSelectionColor, NSBackgroundColorAttributeName, nil]];
}

- (void)_setTextSelectionColor:(NSColor *)newSelectionColor
{
	[self _setTextSelectionColor:newSelectionColor onBackgroundColor:[self backgroundColor]];
}
#endif

/**
 * Take a supplied autocompletion popup, and position it to the correct position
 * for the text at the supplied text range location.
 */
- (void)_positionCompletionPopup:(SPNarrowDownCompletion *)aPopup relativeToTextAtLocation:(NSUInteger)aLocation
{

	// Get the range of glyphs generated from the character at the supplied location
	NSRange glyphRange = [[self layoutManager] glyphRangeForCharacterRange:NSMakeRange(aLocation, 1) actualCharacterRange:NULL];

	// Convert to a bounding rectangle in the window base coordinate system
	NSRect boundingRect = [[self layoutManager] boundingRectForGlyphRange:glyphRange inTextContainer:[self textContainer]];
	boundingRect = [self convertRect:boundingRect toView:nil];

	// Convert the window position to a screen position
	NSPoint screenPosition = [[self window] convertBaseToScreen:NSMakePoint(boundingRect.origin.x, boundingRect.origin.y)];

	// Adjust the popup x location to compensate for horizontal padding and icon
	screenPosition.x -= 26;

	[aPopup setCaretPos:screenPosition];
}

@end

