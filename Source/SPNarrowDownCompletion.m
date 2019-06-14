//
//  SPNarrowDownCompletion.m
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

#import <Foundation/NSObjCRuntime.h>
#import <tgmath.h>

#import "SPNarrowDownCompletion.h"
#import "ImageAndTextCell.h"
#import "SPQueryController.h"
#import "RegexKitLite.h"
#import "SPTextView.h"
#import "SPDatabaseStructure.h"

#pragma mark -
#pragma mark attribute definition 

static NSString * const SPAutoCompletePlaceholderName = @"Placeholder";
static NSString * const SPAutoCompletePlaceholderVal  = @"placholder";

@interface NSTableView (MovingSelectedRow)

- (BOOL)SP_NarrowDownCompletion_canHandleEvent:(NSEvent*)anEvent;

@end

@interface SPNarrowDownCompletion ()

- (NSRect)rectOfMainScreen;
- (NSString*)filterString;
- (void)setupInterface;
- (void)filter;
- (void)insertAutocompletePlaceholder;
- (void)completeAndInsertSnippet;

@end

@implementation NSTableView (MovingSelectedRow)

- (BOOL)SP_NarrowDownCompletion_canHandleEvent:(NSEvent*)anEvent
{
	NSInteger visibleRows = (NSInteger)floor(NSHeight([self visibleRect]) / ([self rowHeight]+[self intercellSpacing].height)) - 1;

	struct { unichar key; NSInteger rows; } const key_movements[] = {
		{ NSUpArrowFunctionKey,              -1 },
		{ NSDownArrowFunctionKey,            +1 },
		{ NSPageUpFunctionKey,     -visibleRows },
		{ NSPageDownFunctionKey,   +visibleRows },
		{ NSHomeFunctionKey,    -(INT_MAX >> 1) },
		{ NSEndFunctionKey,     +(INT_MAX >> 1) },
	};

	unichar keyCode = 0;
	if([anEvent type] == NSKeyDown && [[anEvent characters] length] == 1) {
		keyCode = [[anEvent characters] characterAtIndex:0];
	}

	for(size_t i = 0; i < (sizeof(key_movements) / sizeof(key_movements[0])); ++i) {
		if(keyCode == key_movements[i].key) {
			NSInteger row = MAX(0, MIN([self selectedRow] + key_movements[i].rows, [self numberOfRows]-1));
			if(row == 0 && ![[[self delegate] tableView:self selectionIndexesForProposedSelection:[NSIndexSet indexSetWithIndex:row]] containsIndex:0]) {
				if(visibleRows > 1) [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row+1] byExtendingSelection:NO];
			}
			else {
				[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
			}
			[self scrollRowToVisible:row];
			[(SPNarrowDownCompletion*)[self delegate] insertAutocompletePlaceholder];
			return YES;
		}
	}

	return NO;
}

@end

@implementation SPNarrowDownCompletion
// =============================
// = Setup/tear-down functions =
// =============================
- (id)init
{
	maxWindowWidth = 450;

	if((self = [super initWithContentRect:NSMakeRect(0,0,maxWindowWidth,0) styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES]))
	{
		mutablePrefix = [NSMutableString new];
		originalFilterString = [NSMutableString new];
		textualInputCharacters = [[NSMutableCharacterSet alphanumericCharacterSet] retain];
		caseSensitive = YES;
		filtered = nil;
		spaceCounter = 0;
		currentSyncImage = 0;
		staticPrefix = nil;
		suggestions = nil;
		autocompletePlaceholderWasInserted = NO;
#ifndef SP_CODA
		prefs = [NSUserDefaults standardUserDefaults];
#endif

#ifndef SP_CODA
		tableFont = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:SPCustomQueryEditorFont]];
#else
		tableFont = [NSFont userFixedPitchFontOfSize:10.0];
#endif
		[self setupInterface];

		syncArrowImages = [[NSArray alloc] initWithObjects:[NSImage imageNamed:@"sync_arrows_01"],
		                                                   [NSImage imageNamed:@"sync_arrows_02"],
		                                                   [NSImage imageNamed:@"sync_arrows_03"],
		                                                   [NSImage imageNamed:@"sync_arrows_04"],
		                                                   [NSImage imageNamed:@"sync_arrows_05"],
		                                                   [NSImage imageNamed:@"sync_arrows_06"],
		                                                   nil];
	}
	return self;
}

- (void)dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	if(stateTimer != nil) {
		[stateTimer invalidate];
		SPClear(stateTimer);
	}
	SPClear(mutablePrefix);
	SPClear(textualInputCharacters);
	SPClear(originalFilterString);
	[theTableView setDataSource:nil];
	[theTableView setDelegate:nil];
	SPClear(theTableView);
	if (staticPrefix)               SPClear(staticPrefix);
	if (syncArrowImages)            SPClear(syncArrowImages);
	if (suggestions)                SPClear(suggestions);
	if (filtered)                   SPClear(filtered);
	if (databaseStructureRetrieval) SPClear(databaseStructureRetrieval);

	[super dealloc];
}

- (void)close
{
	// Invalidate the timer now to prevent retain cycles preventing deallocation
	if (stateTimer != nil) {
		[stateTimer invalidate];
		SPClear(stateTimer);
	}

	closeMe = YES;
	[theView setCompletionIsOpen:NO];
	[super close];
}

- (void)updateSyncArrowStatus
{
	// update sync arrow image
	currentSyncImage++;
	if(currentSyncImage >= [syncArrowImages count]) currentSyncImage = 0;

	// check if connection is still querying the db structure
	timeCounter++;
	if(timeCounter > 20) {
		timeCounter = 0;
		if(![databaseStructureRetrieval isQueryingDatabaseStructure]) {
			isQueryingDatabaseStructure = NO;
			if(stateTimer) {
				[stateTimer invalidate];
				SPClear(stateTimer);
				if(syncArrowImages) SPClear(syncArrowImages);
				[[self onMainThread] reInvokeCompletion];
				closeMe = YES;
				return;
			}
		}
	}

	[theTableView setNeedsDisplay:YES];
}

- (void)reInvokeCompletion
{
	if(stateTimer) {
		[stateTimer invalidate];
		SPClear(stateTimer);
	}
	[theView setCompletionIsOpen:NO];
	[self close];
	[theView performSelector:@selector(refreshCompletion) withObject:nil afterDelay:0.0];
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
 withDBStructureRetriever:(SPDatabaseStructure *)theDatabaseStructure
{
	if ((self = [self init]))
	{
		// Set filter string 
		if (aUserString) {
			[mutablePrefix appendString:aUserString];
			[originalFilterString appendString:aUserString];
		}

		autoCompletionMode = autoComplete;

		theAliasName = anAlias;

		oneColumnMode = oneColumn;

		fuzzyMode = fuzzySearch;

		cursorMovedLeft = caretMovedLeft;
		backtickMode = theBackTickMode;
		commaInsertionMode = NO;
		triggerMode = tabTriggerMode;

		if (aStaticPrefix) staticPrefix = [aStaticPrefix retain];

		caseSensitive = isCaseSensitive;

		theCharRange = initRange;

		theParseRange = parseRange;

		theView = aView;
		dictMode = mode;

		timeCounter = 0;

		suggestions = [someSuggestions retain];

		if (dictMode || oneColumnMode) {
			[[theTableView tableColumnWithIdentifier:@"image"] setWidth:0];

			if (!dictMode) {
				NSUInteger maxLength = 0;

				for (id w in someSuggestions) {
					NSUInteger len = [(NSString*)[w objectForKey:@"display"] length];

					if (len>maxLength) maxLength = len;
				}

				NSMutableString *dummy = [NSMutableString string];

				for (NSUInteger i=0; i<maxLength; i++) [dummy appendString:@" "];

				CGFloat w = NSSizeToCGSize([dummy sizeWithAttributes:@{NSFontAttributeName : tableFont}]).width + 26.0f;

				maxWindowWidth = (w>maxWindowWidth) ? maxWindowWidth : w;
			}
			else {
				maxWindowWidth = 220;
			}

			[[theTableView tableColumnWithIdentifier:@"name"] setWidth:maxWindowWidth];
		}

		currentDb = selectedDb;

		if (someAdditionalWordCharacters) {
			[textualInputCharacters addCharactersInString:someAdditionalWordCharacters];
		}

		databaseStructureRetrieval = [theDatabaseStructure retain];
		isQueryingDatabaseStructure = [databaseStructureRetrieval isQueryingDatabaseStructure];

		if (isQueryingDatabaseStructure) {
			stateTimer = [[NSTimer scheduledTimerWithTimeInterval:0.07f target:self selector:@selector(updateSyncArrowStatus) userInfo:nil repeats:YES] retain];
		}
	}

	return self;
}

- (void)setCaretPos:(NSPoint)aPos
{
	caretPos = aPos;

	NSRect screen = [self rectOfMainScreen];

	NSInteger offx = (caretPos.x/screen.size.width) + 1;

	if((caretPos.x + [self frame].size.width) > (screen.size.width*offx)) {
		caretPos.x = (screen.size.width*offx) - [self frame].size.width - 5;
	}

	if(caretPos.y >= 0 && caretPos.y < [self frame].size.height) {
		caretPos.y += [self frame].size.height + ([tableFont pointSize]*1.5f);
		isAbove = YES;
	}

	if(caretPos.y < 0 && (screen.size.height-[self frame].size.height) < (caretPos.y*-1)) {
		caretPos.y += [self frame].size.height + ([tableFont pointSize]*1.5f);
		isAbove = YES;
	}

	[self setFrameTopLeftPoint:caretPos];
}

- (void)setupInterface
{
	[self setReleasedWhenClosed:YES];
	[self setLevel:NSNormalWindowLevel];
	[self setHidesOnDeactivate:YES];
	[self setHasShadow:YES];
	[self setAlphaValue:0.9f];

	NSScrollView* scrollView = [[[NSScrollView alloc] initWithFrame:NSZeroRect] autorelease];
	[scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[scrollView setAutohidesScrollers:YES];
	[scrollView setHasVerticalScroller:YES];
	[scrollView setHasHorizontalScroller:NO];
	[[scrollView verticalScroller] setControlSize:NSSmallControlSize];
	[[scrollView horizontalScroller] setControlSize:NSSmallControlSize];

	theTableView = [[NSTableView alloc] initWithFrame:NSZeroRect];
	[theTableView setFocusRingType:NSFocusRingTypeNone];
	[theTableView setAllowsEmptySelection:YES];
	[theTableView setHeaderView:nil];

	{
		NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"image"] autorelease];
		[column setDataCell:[[NSImageCell new] autorelease]];
		[theTableView addTableColumn:column];
		[column setMinWidth:0];
		[column setWidth:20];
	}

	{
		NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"name"] autorelease];
		[column setEditable:NO];
		[[column dataCell] setFont:[NSFont systemFontOfSize:12]];
		[theTableView addTableColumn:column];
		[column setWidth:170];
	}

	{
		NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"type"] autorelease];
		[column setEditable:NO];
		[theTableView addTableColumn:column];
		[column setWidth:139];
	}

	{
		NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"list"] autorelease];
		[column setEditable:NO];
		[theTableView addTableColumn:column];
		[column setMinWidth:0];
		[column setWidth:6];
	}

	{
		NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"path"] autorelease];
		[column setEditable:NO];
		[theTableView addTableColumn:column];
		[column setWidth:95];
	}

	[theTableView setDataSource:self];
	[theTableView setDelegate:self];
	[scrollView setDocumentView:theTableView];

	[self setContentView:scrollView];
}

// ========================
// = TableView DataSource =
// ========================
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [filtered count];
}

- (NSString *)tableView:(NSTableView *)aTableView toolTipForCell:(id)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex mouseLocation:(NSPoint)mouseLocation
{
	NSString *identifier = [aTableColumn identifier];
	if([identifier isEqualToString:@"image"]) {
		if(isQueryingDatabaseStructure && rowIndex == 0) {
			return NSLocalizedString(@"fetching database structure in progress", @"fetching database structure in progress");
		}

		if(!dictMode) {
			NSString *imageName = [[filtered objectAtIndex:rowIndex] objectForKey:@"image"];
			if([imageName hasPrefix:@"dummy"])      return @"";
			if([imageName hasPrefix:@"table-view"]) return @"view";
			if([imageName hasPrefix:@"table"])      return @"table";
			if([imageName hasPrefix:@"database"])   return @"database";
			if([imageName hasPrefix:@"func"])       return @"function";
			if([imageName hasPrefix:@"proc"])       return @"procedure";
			if([imageName hasPrefix:@"field"])      return @"field";
		}
		return @"";
	}
	else if([identifier isEqualToString:@"name"]) {
		if(isQueryingDatabaseStructure && rowIndex == 0) {
			return NSLocalizedString(@"fetching database structure in progress", @"fetching database structure in progress");
		}

		return [[filtered objectAtIndex:rowIndex] objectForKey:@"display"];
	}
	else if ([identifier isEqualToString:@"list"] || [identifier isEqualToString:@"type"]) {
		if(isQueryingDatabaseStructure && rowIndex == 0) {
			return NSLocalizedString(@"fetching database structure data in progress", @"fetching database structure data in progress");
		}

		if(dictMode) {
			return @"";
		}
		else {
			if([[filtered objectAtIndex:rowIndex] objectForKey:@"list"]) {
				NSMutableString *tt = [NSMutableString string];
				[tt appendStringOrNil:[[filtered objectAtIndex:rowIndex] objectForKey:@"type"]];
				[tt appendString:@"\n"];
				[tt appendString:NSLocalizedString(@"Type Declaration:", @"type declaration header")];
				[tt appendString:@"\n"];
				[tt appendString:[[filtered objectAtIndex:rowIndex] objectForKey:@"list"]];
				return tt;
			}
			else {
				return ([[filtered objectAtIndex:rowIndex] objectForKey:@"type"]) ? [[filtered objectAtIndex:rowIndex] objectForKey:@"type"] : @"";
			}
		}
	}
	else if ([identifier isEqualToString:@"path"]) {
		if(isQueryingDatabaseStructure && rowIndex == 0) {
			return NSLocalizedString(@"fetching database structure in progress", @"fetching database structure in progress");
		}

		if(dictMode) {
			return @"";
		}
		else {
			if([[filtered objectAtIndex:rowIndex] objectForKey:@"path"]) {
				NSMutableString *tt = [NSMutableString string];
				[tt setString:NSLocalizedString(@"Schema path:", @"schema path header for completion tooltip")];
				BOOL flag = NO;
				for(id p in [[[filtered objectAtIndex:rowIndex] objectForKey:@"path"] componentsSeparatedByString:SPUniqueSchemaDelimiter]) {
					if(flag) [tt appendFormat:@"\n• %@",p];
					flag=YES;
				}
				return tt;
			}
			return @"";
		}
	}
	return @"";
}

- (NSIndexSet *)tableView:(NSTableView *)tableView selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes
{
	if(isQueryingDatabaseStructure && [proposedSelectionIndexes containsIndex:0]) {
		return [tableView selectedRowIndexes];
	}

	return proposedSelectionIndexes;
}

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	// tableColumn == nil is called for a potential group row by the table view, which we don't have
	if(!tableColumn) return nil;

	NSString *identifier = [tableColumn identifier];
	if ([identifier isEqualToString:@"list"]) {
		if(
			!(isQueryingDatabaseStructure && rowIndex == 0) &&
			!dictMode &&
			[[filtered objectAtIndex:rowIndex] objectForKey:@"list"]
		) {
			NSPopUpButtonCell *b = [NSPopUpButtonCell new];
			[b setPullsDown:NO];
			[b setAltersStateOfSelectedItem:NO];
			[b setControlSize:NSMiniControlSize];
			{
				NSMenu *m = [[NSMenu alloc] init];
				NSMenuItem *aMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Type Declaration:", @"type declaration header") action:NULL keyEquivalent:@""] autorelease];
				[aMenuItem setEnabled:NO];
				[m addItem:aMenuItem];
				[m addItemWithTitle:[[filtered objectAtIndex:rowIndex] objectForKey:@"list"] action:NULL keyEquivalent:@""];
				[b setMenu:m];
				[m release];
			}
			[b setPreferredEdge:NSMinXEdge];
			[b setArrowPosition:NSPopUpArrowAtCenter];
			[b setFont:[NSFont systemFontOfSize:11]];
			[b setBordered:NO];
			return [b autorelease];
		}
	}
	else if([identifier isEqualToString:@"type"]) {
		if(!(isQueryingDatabaseStructure && rowIndex == 0) && !dictMode) {
			NSTokenFieldCell *b = [[NSTokenFieldCell alloc] init];
			[b setEditable:NO];
			[b setAlignment:NSRightTextAlignment];
			[b setFont:[NSFont systemFontOfSize:11]];
			return [b autorelease];
		}
	}
	else if ([identifier isEqualToString:@"path"]) {
		if(
			!(isQueryingDatabaseStructure && rowIndex == 0) &&
			!dictMode &&
			[[filtered objectAtIndex:rowIndex] objectForKey:@"path"]
		) {
			NSPopUpButtonCell *b = [NSPopUpButtonCell new];
			[b setPullsDown:NO];
			[b setAltersStateOfSelectedItem:NO];
			[b setControlSize:NSMiniControlSize];
			{
				NSMenu *m = [[NSMenu alloc] init];
				for(id p in [[[[[filtered objectAtIndex:rowIndex] objectForKey:@"path"] componentsSeparatedByString:SPUniqueSchemaDelimiter] reverseObjectEnumerator] allObjects]) {
					[m addItemWithTitle:p action:NULL keyEquivalent:@""];
				}
				if([m numberOfItems] > 2) {
					[m removeItemAtIndex:[m numberOfItems]-1];
					[m removeItemAtIndex:0];
				}
				[b setMenu:m];
				[m release];
			}
			[b setPreferredEdge:NSMinXEdge];
			[b setArrowPosition:([b numberOfItems] > 1 ? NSPopUpArrowAtCenter : NSPopUpNoArrow)];
			[b setFont:[NSFont systemFontOfSize:11]];
			[b setBordered:NO];
			return [b autorelease];
		}
	}

	// ... otherwise use the default cell for the column (text field cell)
	return nil;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	NSString *identifier = [aTableColumn identifier];
	if([identifier isEqualToString:@"image"]) {
		if(dictMode) {
			return @"";
		}

		if(isQueryingDatabaseStructure && rowIndex == 0) {
			return [syncArrowImages objectAtIndex:currentSyncImage];
		}
		else {
			NSImage* image = nil;
			NSString *imageName = [[filtered objectAtIndex:rowIndex] objectForKey:@"image"];
			if(imageName) image = [NSImage imageNamed:imageName];
			return image;
		}
	}
	else if([identifier isEqualToString:@"name"]) {
		if(isQueryingDatabaseStructure && rowIndex == 0) {
			return NSLocalizedString(@"fetching database structure in progress", @"fetching database structure in progress");
		}

		return [[filtered objectAtIndex:rowIndex] objectForKey:@"display"];
	}
	else if ([identifier isEqualToString:@"list"]) {
		return @"";
	}
	else if([identifier isEqualToString:@"type"]) {
		if(isQueryingDatabaseStructure && rowIndex == 0) {
			return @"";
		}

		if(dictMode) {
			return @"";
		}

		return ([[filtered objectAtIndex:rowIndex] objectForKey:@"type"] ? [[filtered objectAtIndex:rowIndex] objectForKey:@"type"] : @"");
	}
	else if ([identifier isEqualToString:@"path"]) {
		return @"";
	}

	[NSException raise:NSInternalInconsistencyException format:@"Requesting data for invalid table column with identifier=%@", identifier];
	return nil; // compiler hint
}

// ======================================================================================
// = Check if at least one suggestion contains a “ ” - is so allow a “ ” to be typed in =
// ======================================================================================
- (void)checkSpaceForAllowedCharacter
{
	[textualInputCharacters removeCharactersInString:@" "];
	if(autoCompletionMode) return;
	if(spaceCounter < 1) {
		for(id w in filtered) {
			if([[w objectForKey:@"match"] ?: [w objectForKey:@"display"] rangeOfString:@" "].length && ![w objectForKey:@"noCompletion"]) {
				[textualInputCharacters addCharactersInString:@" "];
				break;
			}
		}
	}
}

// ====================
// = Filter the items =
// ====================
- (void)filter
{
	NSMutableArray* newFiltered = [[NSMutableArray alloc] initWithCapacity:5];
	
	if([mutablePrefix length] > 0) {
		if(dictMode) {
			NSPredicate* predicate;
			if(caseSensitive) {
				predicate = [NSPredicate predicateWithFormat:@"match BEGINSWITH %@ OR (match == NULL AND display BEGINSWITH %@)", [self filterString], [self filterString]];
			}
			else {
				predicate = [NSPredicate predicateWithFormat:@"match BEGINSWITH[c] %@ OR (match == NULL AND display BEGINSWITH[c] %@)", [self filterString], [self filterString]];
			}
			[newFiltered addObjectsFromArray:[suggestions filteredArrayUsingPredicate:predicate]];
			for(id w in [[NSSpellChecker sharedSpellChecker] completionsForPartialWordRange:NSMakeRange(0,[[self filterString] length]) inString:[self filterString] language:nil inSpellDocumentWithTag:0]) {
				[newFiltered addObject:[NSDictionary dictionaryWithObjectsAndKeys:w, @"display", nil]];
			}
		}
		else {
			@try{
				if(fuzzyMode) { // eg filter = "inf" this regexp search will be performed: (?i).*?i.*?n.*?f

					NSMutableString *fuzzyRegexp = [[NSMutableString alloc] initWithCapacity:3];
					NSUInteger i;
					unichar c;

					if (!caseSensitive) [fuzzyRegexp setString:@"(?i)"];

					for (i=0; i<[[self filterString] length]; i++) {
						c = [[self filterString] characterAtIndex:i];
						if(c != '`') {
							if(c == '.') {
								[fuzzyRegexp appendFormat:@".*?%@",SPUniqueSchemaDelimiter];
							}
							else if (c == '(' || c == ')' || c == '[' || c == ']' || c == '{' || c == '}') {
								[fuzzyRegexp appendFormat:@".*?\\%c",c];
							}
							else {
								[fuzzyRegexp appendFormat:@".*?%c",c];
							}
						}
					}

					for (id s in suggestions) {
						if ([[s objectForKey:@"display"] isMatchedByRegex:fuzzyRegexp] || [[s objectForKey:@"path"] isMatchedByRegex:fuzzyRegexp]) {
							[newFiltered addObject:s];
						}
					}

					[fuzzyRegexp release];
				}
				else {
					NSPredicate* predicate;
					if(caseSensitive) {
						predicate = [NSPredicate predicateWithFormat:@"match BEGINSWITH %@ OR (match == NULL AND display BEGINSWITH %@)", [self filterString], [self filterString]];
					}
					else {
						predicate = [NSPredicate predicateWithFormat:@"match BEGINSWITH[c] %@ OR (match == NULL AND display BEGINSWITH[c] %@)", [self filterString], [self filterString]];
					}
					[newFiltered addObjectsFromArray:[suggestions filteredArrayUsingPredicate:predicate]];
				}
			}
			@catch(id ae) {
				if(newFiltered) [newFiltered release];
				NSLog(@"%@", @"Couldn't filter suggestion due to internal regexp error");
				closeMe = YES;
				return;
			}
		}
	}
	else {
		if(!dictMode) [newFiltered addObjectsFromArray:suggestions];
	}

	if(![newFiltered count]) {
		if(autoCompletionMode) {
			[newFiltered release];
			closeMe = YES;
			return;
		}
		else {
			if([theView completionWasReinvokedAutomatically]) return;
			if([[self filterString] hasSuffix:@"."]) {
				[theView setCompletionWasReinvokedAutomatically:YES];
				[theView doCompletionByUsingSpellChecker:dictMode fuzzyMode:fuzzyMode autoCompleteMode:NO];
				[newFiltered release];
				closeMe = YES;
				return;
			}
			else {
				[newFiltered addObject:@{@"display" : NSLocalizedString(@"No item found", @"no item found message"), @"noCompletion" : @""}];
			}
		}
	}

	if(autoCompletionMode && [newFiltered count] == 1 && [[[self filterString] lowercaseString] isEqualToString:[[[newFiltered objectAtIndex:0] objectForKey:@"display"] lowercaseString]]) {
		[newFiltered release];
		closeMe = YES;
		return;
	}

	// if fetching db structure add dummy row for displaying that info on top of the list
	if(isQueryingDatabaseStructure) [newFiltered insertObject:@{@"display" : @"dummy", @"noCompletion" : @""} atIndex:0];

	NSPoint old = NSMakePoint([self frame].origin.x, [self frame].origin.y + [self frame].size.height);

	NSInteger displayedRows = [newFiltered count] < SPNarrowDownCompletionMaxRows ? [newFiltered count] : SPNarrowDownCompletionMaxRows;
	CGFloat newHeight = ([theTableView rowHeight] + [theTableView intercellSpacing].height) * ((displayedRows) ? displayedRows : 1);

	if(caretPos.y >= 0 && (isAbove || caretPos.y < newHeight)) {
		isAbove = YES;
		old.y = caretPos.y + newHeight + ([tableFont pointSize]*1.5f);
	}

	if(caretPos.y < 0 && (isAbove || ([self rectOfMainScreen].size.height-newHeight) < (caretPos.y*-1))) {
		old.y = caretPos.y + newHeight + ([tableFont pointSize]*1.5f);
	}

	// newHeight is currently the new height for theTableView, but we need to resize the whole window
	// so here we use the difference in height to find the new height for the window
	[self setFrame:NSMakeRect(old.x, old.y-newHeight, maxWindowWidth, newHeight) display:YES];

	if (filtered) [filtered release];
	filtered = [newFiltered retain];
	[newFiltered release];
	if(!dictMode) [self checkSpaceForAllowedCharacter];
	[theTableView reloadData];
	[theTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(isQueryingDatabaseStructure)?1:0] byExtendingSelection:NO];
}

// =========================
// = Convenience functions =
// =========================
- (NSString*)filterString
{
	return staticPrefix ? [staticPrefix stringByAppendingString:mutablePrefix] : mutablePrefix;
}

- (NSRect)rectOfMainScreen
{
	NSRect screen = [[NSScreen mainScreen] frame];
	
	for (NSScreen *candidate in [NSScreen screens]) {
		if (NSMinX([candidate frame]) == 0.0f && NSMinY([candidate frame]) == 0.0f) {
			screen = [candidate frame];
		}
	}
	
	return screen;
}

// =============================
// = Run the actual popup-menu =
// =============================
- (void)orderFront:(id)sender
{
	[self filter];
	if (!closeMe) {
		[super orderFront:sender];
		[self performSelector:@selector(watchUserEvents) withObject:nil afterDelay:0.05];
	}
	else {
		[self close];
	}
}

- (void)watchUserEvents
{

	[theView setCompletionIsOpen:YES];

	closeMe = NO;
	while(!closeMe) {
		NSEvent* event = [NSApp nextEventMatchingMask:NSAnyEventMask
		                                    untilDate:[NSDate distantFuture]
		                                       inMode:NSDefaultRunLoopMode
		                                      dequeue:YES];

		if(!event) continue;

		// Exit if closeMe has been set in the meantime
		if(closeMe) return;
		
		NSEventType t = [event type];
		if([theTableView SP_NarrowDownCompletion_canHandleEvent:event]) {
			// skip the rest
		}
		else if(t == NSKeyDown) {
			NSEventModifierFlags flags = [event modifierFlags];
			unichar key                = [[event characters] length] == 1 ? [[event characters] characterAtIndex:0] : 0;

			// Check if user pressed ⌥ to allow composing of accented characters.
			// e.g. for US keyboard "⌥u a" to insert ä
			if (([event modifierFlags] & (NSEventModifierFlagShift|NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagCommand)) == NSEventModifierFlagOption || [[event characters] length] == 0) {
				if (autocompletePlaceholderWasInserted) [self removeAutocompletionPlaceholderUsingFastMethod:YES];

				if (autoCompletionMode) {
					[theView setCompletionIsOpen:NO];
					[self close];
					[NSApp sendEvent:event];
					break;
				}

				[NSApp sendEvent: event];

				if(commaInsertionMode) break;

				[mutablePrefix appendString:[event characters]];
				theCharRange = NSMakeRange(theCharRange.location, theCharRange.length+[[event characters] length]);
				theParseRange = NSMakeRange(theParseRange.location, theParseRange.length+[[event characters] length]);
				[self filter];
			}
			else if((flags & NSEventModifierFlagOption) || (flags & NSEventModifierFlagCommand)) {
				if (autocompletePlaceholderWasInserted) [self removeAutocompletionPlaceholderUsingFastMethod:YES];
				[theView setCompletionIsOpen:NO];
				[self close];
				[NSApp sendEvent:event];
				break;
			}
			else if([event keyCode] == 53) { // escape
				if(flags & NSEventModifierFlagControl) {
					fuzzyMode = YES;
					[self filter];
				}
				else {
					if(autoCompletionMode) {
						if (autocompletePlaceholderWasInserted) [self removeAutocompletionPlaceholderUsingFastMethod:YES];
						[theView setCompletionIsOpen:NO];
						[self close];
						break;
					}
					if(cursorMovedLeft) [theView performSelector:@selector(moveRight:)];
					break;
				}
			}
			else if(key == NSCarriageReturnCharacter || key == NSEnterCharacter  || key == NSRightArrowFunctionKey || (key == NSTabCharacter && !triggerMode)) {
				[self completeAndInsertSnippet];
			}
			else if(key == NSBackspaceCharacter || key == NSDeleteCharacter) {
				if (autocompletePlaceholderWasInserted) [self removeAutocompletionPlaceholderUsingFastMethod:NO];

				if (autoCompletionMode) {
					[NSApp sendEvent:event];
					break;
				}

				[NSApp sendEvent:event];
				if([mutablePrefix length] == 0 || commaInsertionMode) break;

				spaceCounter = 0;
				[mutablePrefix deleteCharactersInRange:NSMakeRange([mutablePrefix length]-1, 1)];
				[originalFilterString deleteCharactersInRange:NSMakeRange([originalFilterString length]-1, 1)];
				theCharRange.length--;
				theParseRange.length--;
				[self filter];
			}
			else if([textualInputCharacters characterIsMember:key]) {
				if (autocompletePlaceholderWasInserted) [self removeAutocompletionPlaceholderUsingFastMethod:YES];

				if (autoCompletionMode) {
					[theView setCompletionIsOpen:NO];
					[self close];
					[NSApp sendEvent:event];
					return;
				}

				[NSApp sendEvent:event];

				if(commaInsertionMode) break;
				if([event keyCode] == 49) spaceCounter++; // space

				[mutablePrefix appendString:[event characters]];
				[originalFilterString appendString:[event characters]];
				theCharRange.length++;
				theParseRange.length++;
				[self filter];
				[self insertAutocompletePlaceholder];
			}
			else {
				[NSApp sendEvent:event];
				if(cursorMovedLeft) [theView performSelector:@selector(moveRight:)];
				break;
			}
		}
		else if(t == NSRightMouseDown || t == NSLeftMouseDown) {
			if(([event clickCount] == 2)) {
				[self completeAndInsertSnippet];
			}
			else {
				if(!NSPointInRect([NSEvent mouseLocation], [self frame])) {
					if (autocompletePlaceholderWasInserted) [self removeAutocompletionPlaceholderUsingFastMethod:YES];
					if(cursorMovedLeft) [theView performSelector:@selector(moveRight:)];
					[NSApp sendEvent:event];
					break;
				}
				[NSApp sendEvent:event];
			}
		}
		else {
			[NSApp sendEvent:event];
		}
	}

	// If the autocomplete menu is open, but the placeholder is still present, it needs removing.
	if (autocompletePlaceholderWasInserted) [self removeAutocompletionPlaceholderUsingFastMethod:NO];

	[theView setCompletionIsOpen:NO];
	[self close];
	usleep(70); // tiny delay to suppress while continously pressing of ESC overlapping
}

// ==================
// = Action methods =
// ==================
- (void)insertAutocompletePlaceholder
{
	if([theTableView selectedRow] == -1 || fuzzyMode) return;

	// Retrieve the current autocompletion length, if any
	NSUInteger currentAutocompleteLength = theCharRange.length - [originalFilterString length];

	// Clear any current placeholder
	if (autocompletePlaceholderWasInserted) [self removeAutocompletionPlaceholderUsingFastMethod:YES];

	// Select the highlighted item in the list of suggestions
	id cur = [filtered objectAtIndex:[theTableView selectedRow]];

	// Ensure it's a valid suggestion and extract the string
	if ([cur objectForKey:@"noCompletion"]) return;
	NSString* curMatch = [cur objectForKey:@"match"] ?: [cur objectForKey:@"display"];
	if (![curMatch length]) return;

	// Insert a placeholder for the string in the textview
	if ([originalFilterString length] < [curMatch length]) {
		NSUInteger currentSelectionPosition = [theView selectedRange].location;
		NSString* toInsert = [curMatch substringFromIndex:[originalFilterString length]];
		theCharRange.length += [toInsert length] - currentAutocompleteLength;
		theParseRange.length += [toInsert length];

		[theView breakUndoCoalescing];
		[theView insertText:[toInsert lowercaseString]];

		autocompletePlaceholderWasInserted = YES;

		// Restore the text selection location, and clearly mark the autosuggested text
		[theView setSelectedRange:NSMakeRange(currentSelectionPosition, 0)];
		NSMutableAttributedStringAddAttributeValueRange([theView textStorage], NSForegroundColorAttributeName, [[theView otherTextColor] colorWithAlphaComponent:0.3f], NSMakeRange(currentSelectionPosition, [toInsert length]));
		NSMutableAttributedStringAddAttributeValueRange([theView textStorage], SPAutoCompletePlaceholderName, SPAutoCompletePlaceholderVal, NSMakeRange(currentSelectionPosition, [toInsert length]));

		[self checkSpaceForAllowedCharacter];
	}
}

- (void)removeAutocompletionPlaceholderUsingFastMethod:(BOOL)useFastMethod
{
	if (!autocompletePlaceholderWasInserted) return;

	[theView breakUndoCoalescing];

	if (useFastMethod) {
		if(backtickMode) {
			NSRange r = NSMakeRange(theCharRange.location+1,theCharRange.length);
			[theView setSelectedRange:r];
		}
		else {
			[theView setSelectedRange:theCharRange];
		}
		[theView insertText:originalFilterString];
	} else {
		NSRange attributeResultRange = NSMakeRange(0, 0);
		NSUInteger scanPosition = 0;
		NSUInteger currentLength;

		[[theView textStorage] beginEditing];
		while (1) {
			currentLength = [[theView textStorage] length];
			if (scanPosition == currentLength) break;

			// Perform a search for the attribute, capturing the range of the [non]match
			if ([[theView textStorage] attribute:SPAutoCompletePlaceholderName atIndex:scanPosition longestEffectiveRange:&attributeResultRange inRange:NSMakeRange(scanPosition, currentLength-scanPosition)]) {
				// A match was found - attributeResultRange contains the range of the attributed string
				[theView shouldChangeTextInRange:attributeResultRange replacementString:@""];
				[[theView textStorage] deleteCharactersInRange:attributeResultRange];
			}
			else {
				// No match was found. attributeResultRange contains the range of the no match - this can be
				// checked to see whether a match is inside the full range.
				if (scanPosition + attributeResultRange.length == currentLength) break;

				// A match was found - retrieve the location
				NSUInteger matchStart = NSMaxRange(attributeResultRange);
				if ([[theView textStorage] attribute:SPAutoCompletePlaceholderName atIndex:matchStart longestEffectiveRange:&attributeResultRange inRange:NSMakeRange(matchStart, currentLength - matchStart)]) {
					[theView shouldChangeTextInRange:attributeResultRange replacementString:@""];
					[[theView textStorage] deleteCharactersInRange:attributeResultRange];
				}
			}
			scanPosition = attributeResultRange.location;
		}
		[[theView textStorage] endEditing];
	}

	autocompletePlaceholderWasInserted = NO;
}

- (void)insert_text:(NSString *)aString
{
	// Ensure that theCharRange is valid
	if(NSMaxRange(theCharRange) > [[theView string] length]) {
		theCharRange = NSIntersectionRange(NSMakeRange(0,[[theView string] length]), theCharRange);
	}

	[theView breakUndoCoalescing];

	NSRange r = [theView selectedRange];
	if(r.length) {
		[theView setSelectedRange:r];
	}
	else {
		if(backtickMode == 100) {
			NSString *replaceString = [[theView string] substringWithRange:theCharRange];
			BOOL nextCharIsBacktick = ([replaceString hasSuffix:@"`"]);
			if(theCharRange.length == 1) nextCharIsBacktick = NO;
			if(!nextCharIsBacktick) {
				if([replaceString hasPrefix:@"`"]) {
					[theView setSelectedRange:NSMakeRange(theCharRange.location, theCharRange.length+2)];
				}
				else {
					[theView setSelectedRange:theCharRange];
				}
			} else {
				[theView setSelectedRange:theCharRange];
			}
			backtickMode = 0;
		}
		else {
			[theView setSelectedRange:theCharRange];
		}
	}

	[theView breakUndoCoalescing];
	[theView insertText:aString];

	// If completion string contains backticks move caret out of the backticks
	if(backtickMode && !triggerMode) {
		[theView performSelector:@selector(moveRight:)];
	}
#ifndef SP_CODA
	// If it's a function or procedure append () and if a argument list can be retieved insert them as snippets
	else if([prefs boolForKey:SPCustomQueryFunctionCompletionInsertsArguments] && ([[[filtered objectAtIndex:[theTableView selectedRow]] objectForKey:@"image"] hasPrefix:@"func"] || [[[filtered objectAtIndex:[theTableView selectedRow]] objectForKey:@"image"] hasPrefix:@"proc"]) && ![aString hasSuffix:@")"]) {
		NSString *functionArgumentSnippet = [NSString stringWithFormat:@"(%@)", [[SPQueryController sharedQueryController] argumentSnippetForFunction:aString]];
		[theView insertAsSnippet:functionArgumentSnippet atRange:[theView selectedRange]];
		if([functionArgumentSnippet length] == 2) [theView performSelector:@selector(moveLeft:)];
	}
#endif
}

- (void)completeAndInsertSnippet
{
	if([theTableView selectedRow] == -1) return;

	NSDictionary *selectedItem = [filtered objectAtIndex:[theTableView selectedRow]];

	if([selectedItem objectForKey:@"noCompletion"]) {
		closeMe = YES;
		return;
	}

	if(dictMode) {
		[self insert_text:[selectedItem objectForKey:@"match"] ?: [selectedItem objectForKey:@"display"]];
	}
	else {
		NSString* candidateMatch = [selectedItem objectForKey:@"match"] ?: [selectedItem objectForKey:@"display"];
		if([selectedItem objectForKey:@"isRef"] 
		    && ([[NSApp currentEvent] modifierFlags] & (NSEventModifierFlagShift))
		    && [(NSString*)[selectedItem objectForKey:@"path"] length] && theAliasName == nil) {

			NSString *path = [[[selectedItem objectForKey:@"path"] componentsSeparatedByString:SPUniqueSchemaDelimiter] componentsJoinedByPeriodAndBacktickQuotedAndIgnoreFirst];
			// Check if path's db name is the current selected db name
			NSRange r = [path rangeOfString:[currentDb backtickQuotedString] options:NSCaseInsensitiveSearch range:NSMakeRange(0, [[currentDb backtickQuotedString] length])];
			theCharRange = theParseRange;
			backtickMode = 0; // suppress move the caret one step rightwards
			if(path && [path length] && r.length) {
				[self insert_text:[path substringFromIndex:r.length+1]];
			} else {
				[self insert_text:path];
			}
		}
		else {
			// Is completion string a schema name for current connection
			if([selectedItem objectForKey:@"isRef"]) {
				backtickMode = 100; // suppress move the caret one step rightwards
				if ([prefs boolForKey:SPCustomQueryEditorCompleteWithBackticks]) {
					[self insert_text:[candidateMatch backtickQuotedString]];
				}
				else {
					[self insert_text:candidateMatch];
				}
			}
			else {
				[self insert_text:candidateMatch];
			}
		}
	}

	// Pressing CTRL while inserting an item the suggestion list keeps open
	// to allow to add more field/table names comma separated
	if([selectedItem objectForKey:@"isRef"] && [[NSApp currentEvent] modifierFlags] & (NSEventModifierFlagControl)) {
		[theView insertText:@", "];
		theCharRange = [theView selectedRange];
		theParseRange = [theView selectedRange];
		commaInsertionMode = YES;
	}
	else {
		closeMe = YES;
	}
}

- (void)adjustWorkingRangeByDelta:(NSInteger)delta
{
	theCharRange.location += delta;
	theParseRange.location += delta;
}

@end
