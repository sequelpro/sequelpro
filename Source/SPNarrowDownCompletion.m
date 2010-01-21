//
//  $Id: SPNarrowDownCompletion.m 744 2009-05-22 20:00:00Z bibiko $
//
//  SPGrowlController.m
//  sequel-pro
//
//  Created by Hans-J. Bibiko on May 14, 2009.
//
//  This class is based on TextMate's TMDIncrementalPopUp implementation
//  (Dialog plugin) written by Joachim Mårtensson, Allan Odgaard, and H.-J. Bibiko.
//   see license: http://svn.textmate.org/trunk/LICENSE
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

#import <Foundation/NSObjCRuntime.h>

#import "SPNarrowDownCompletion.h"
#import "SPArrayAdditions.h"
#import "SPStringAdditions.h"
#import "ImageAndTextCell.h"
#import "SPConstants.h"
#include <tgmath.h>

@interface NSTableView (MovingSelectedRow)

- (BOOL)SP_NarrowDownCompletion_canHandleEvent:(NSEvent*)anEvent;

@end

@interface SPNarrowDownCompletion (Private)

- (NSRect)rectOfMainScreen;
- (NSString*)filterString;
- (void)setupInterface;
- (void)filter;
- (void)insertCommonPrefix;
- (void)completeAndInsertSnippet;

@end

@implementation NSTableView (MovingSelectedRow)

- (BOOL)SP_NarrowDownCompletion_canHandleEvent:(NSEvent*)anEvent
{
	NSInteger visibleRows = (NSInteger)floor(NSHeight([self visibleRect]) / ([self rowHeight]+[self intercellSpacing].height)) - 1;

	struct { unichar key; NSInteger rows; } const key_movements[] =
	{
		{ NSUpArrowFunctionKey,              -1 },
		{ NSDownArrowFunctionKey,            +1 },
		{ NSPageUpFunctionKey,     -visibleRows },
		{ NSPageDownFunctionKey,   +visibleRows },
		{ NSHomeFunctionKey,    -(INT_MAX >> 1) },
		{ NSEndFunctionKey,     +(INT_MAX >> 1) },
	};

	unichar keyCode = 0;
	if([anEvent type] == NSScrollWheel)
		keyCode = [anEvent deltaY] >= 0.0 ? NSUpArrowFunctionKey : NSDownArrowFunctionKey;
	else if([anEvent type] == NSKeyDown && [[anEvent characters] length] == 1)
		keyCode = [[anEvent characters] characterAtIndex:0];


	for(size_t i = 0; i < sizeofA(key_movements); ++i)
	{
		if(keyCode == key_movements[i].key)
		{
			NSInteger row = MAX(0, MIN([self selectedRow] + key_movements[i].rows, [self numberOfRows]-1));
			[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
			[self scrollRowToVisible:row];

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

	if(self = [super initWithContentRect:NSMakeRect(0,0,maxWindowWidth,0) styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO])
	{
		mutablePrefix = [NSMutableString new];
		textualInputCharacters = [[NSMutableCharacterSet alphanumericCharacterSet] retain];
		caseSensitive = YES;
		filtered = nil;

		tableFont = [NSUnarchiver unarchiveObjectWithData:[[NSUserDefaults standardUserDefaults] dataForKey:SPCustomQueryEditorFont]];
		[self setupInterface];
	}
	return self;
}

- (void)dealloc
{
	[staticPrefix release];
	[mutablePrefix release];
	[textualInputCharacters release];

	if(suggestions) [suggestions release];

	if (filtered) [filtered release];

	[super dealloc];
}

- (id)initWithItems:(NSArray*)someSuggestions alreadyTyped:(NSString*)aUserString staticPrefix:(NSString*)aStaticPrefix 
	additionalWordCharacters:(NSString*)someAdditionalWordCharacters caseSensitive:(BOOL)isCaseSensitive 
	charRange:(NSRange)initRange parseRange:(NSRange)parseRange inView:(id)aView 
	dictMode:(BOOL)mode dbMode:(BOOL)theDbMode fuzzySearch:(BOOL)fuzzySearch
	backtickMode:(NSInteger)theBackTickMode withDbName:(NSString*)dbName withTableName:(NSString*)tableName 
	selectedDb:(NSString*)selectedDb caretMovedLeft:(BOOL)caretMovedLeft
{
	if(self = [self init])
	{

		// Set filter string 
		if(aUserString)
			[mutablePrefix appendString:aUserString];

		fuzzyMode = fuzzySearch;
		if(fuzzyMode)
			[theTableView setBackgroundColor:[NSColor colorWithCalibratedRed:0.9f green:0.9f blue:0.9f alpha:1.0f]];
		else
			[theTableView setBackgroundColor:[NSColor whiteColor]];

		dbStructureMode = theDbMode;
		cursorMovedLeft = caretMovedLeft;
		backtickMode = theBackTickMode;

		if(aStaticPrefix)
			staticPrefix = [aStaticPrefix retain];

		caseSensitive = isCaseSensitive;

		theCharRange = initRange;
		noFilterString = ([aUserString length]) ? NO : YES;

		theParseRange = parseRange;

		theView = aView;
		dictMode = mode;

		suggestions = [someSuggestions retain];

		[[theTableView tableColumnWithIdentifier:@"image"] setWidth:((dictMode) ? 0 : 20)];
		[[theTableView tableColumnWithIdentifier:@"name"] setWidth:((dictMode) ? 440 : 180)];

		currentDb = selectedDb;

		theDbName = dbName;

		if(someAdditionalWordCharacters)
			[textualInputCharacters addCharactersInString:someAdditionalWordCharacters];

	}
	return self;
}

- (void)setCaretPos:(NSPoint)aPos
{
	caretPos = aPos;

	NSRect mainScreen = [self rectOfMainScreen];

	NSInteger offx = (caretPos.x/mainScreen.size.width) + 1;

	if((caretPos.x + [self frame].size.width) > (mainScreen.size.width*offx))
		caretPos.x = (mainScreen.size.width*offx) - [self frame].size.width - 5;

	if(caretPos.y >= 0 && caretPos.y < [self frame].size.height)
	{
		caretPos.y += [self frame].size.height + ([tableFont pointSize]*1.5);
		isAbove = YES;
	}
	if(caretPos.y < 0 && (mainScreen.size.height-[self frame].size.height) < (caretPos.y*-1))
	{
		caretPos.y += [self frame].size.height + ([tableFont pointSize]*1.5);
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
	[self setAlphaValue:0.9];

	NSScrollView* scrollView = [[[NSScrollView alloc] initWithFrame:NSZeroRect] autorelease];
	[scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[scrollView setAutohidesScrollers:YES];
	[scrollView setHasVerticalScroller:YES];
	[scrollView setHasHorizontalScroller:NO];
	[[scrollView verticalScroller] setControlSize:NSSmallControlSize];
	[[scrollView horizontalScroller] setControlSize:NSSmallControlSize];

	theTableView = [[[NSTableView alloc] initWithFrame:NSZeroRect] autorelease];
	[theTableView setFocusRingType:NSFocusRingTypeNone];
	[theTableView setAllowsEmptySelection:NO];
	[theTableView setHeaderView:nil];
	[theTableView setDelegate:self];

	NSTableColumn *column0 = [[[NSTableColumn alloc] initWithIdentifier:@"image"] autorelease];
	[column0 setDataCell:[[ImageAndTextCell new] autorelease]];
	[column0 setEditable:NO];
	[theTableView addTableColumn:column0];
	[column0 setMinWidth:0];
	[column0 setWidth:20];

	NSTableColumn *column1 = [[[NSTableColumn alloc] initWithIdentifier:@"name"] autorelease];
	[column1 setEditable:NO];
	[theTableView addTableColumn:column1];
	[column1 setWidth:170];

	NSTableColumn *column3 = [[[NSTableColumn alloc] initWithIdentifier:@"type"] autorelease];
	[column3 setEditable:NO];
	[theTableView addTableColumn:column3];
	[column3 setWidth:139];

	NSTableColumn *column2 = [[[NSTableColumn alloc] initWithIdentifier:@"list"] autorelease];
	[column2 setEditable:NO];
	[theTableView addTableColumn:column2];
	[column0 setMinWidth:0];
	[column2 setWidth:6];

	NSTableColumn *column4 = [[[NSTableColumn alloc] initWithIdentifier:@"path"] autorelease];
	[column4 setEditable:NO];
	[theTableView addTableColumn:column4];
	[column4 setWidth:95];

	[theTableView setDataSource:self];
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

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	NSImage* image = nil;
	NSString* imageName = nil;

	if([[aTableColumn identifier] isEqualToString:@"image"]) {
		if(!dictMode) {
			imageName = [[filtered objectAtIndex:rowIndex] objectForKey:@"image"];
			if(imageName)
				image = [NSImage imageNamed:imageName];
			[[aTableColumn dataCell] setImage:image];
		}
		return @"";

	} else if([[aTableColumn identifier] isEqualToString:@"name"]) {
		// NSTextFieldCell *b = [[[NSTextFieldCell new] initTextCell:[[filtered objectAtIndex:rowIndex] objectForKey:@"display"]] autorelease];
		[[aTableColumn dataCell] setFont:[NSFont systemFontOfSize:12]];
		return [[filtered objectAtIndex:rowIndex] objectForKey:@"display"];

	} else if ([[aTableColumn identifier] isEqualToString:@"list"]) {
		if(dictMode) {
			return @"";
		} else {
			if([[filtered objectAtIndex:rowIndex] objectForKey:@"list"]) {
				NSPopUpButtonCell *b = [[NSPopUpButtonCell new] autorelease];
				[b setPullsDown:NO];
				[b setAltersStateOfSelectedItem:NO];
				[b setControlSize:NSMiniControlSize];
				NSMenu *m = [[NSMenu alloc] init];
				[m addItemWithTitle:[[filtered objectAtIndex:rowIndex] objectForKey:@"list"] action:NULL keyEquivalent:@""];
				[b setMenu:m];
				[m release];
				[b setPreferredEdge:NSMinXEdge];
				[b setArrowPosition:NSPopUpArrowAtCenter];
				[b setFont:[NSFont systemFontOfSize:11]];
				[b setBordered:NO];
				[aTableColumn setDataCell:b];
			} else {
				[aTableColumn setDataCell:[[NSTextFieldCell new] autorelease]];
			}
			return @"";
		}

	} else if([[aTableColumn identifier] isEqualToString:@"type"]) {
		if(dictMode) {
			return @"";
		} else {
			// [[aTableColumn dataCell] setTextColor:([aTableView selectedRow] == rowIndex)?[NSColor whiteColor]:[NSColor darkGrayColor]];
			// return ([[filtered objectAtIndex:rowIndex] objectForKey:@"type"]) ? [[filtered objectAtIndex:rowIndex] objectForKey:@"type"] : @"";
			NSTokenFieldCell *b = [[[NSTokenFieldCell alloc] initTextCell:([[filtered objectAtIndex:rowIndex] objectForKey:@"type"]) ? [[filtered objectAtIndex:rowIndex] objectForKey:@"type"] : @""] autorelease];
			[b setEditable:NO];
			[b setAlignment:NSRightTextAlignment];
			[b setFont:[NSFont systemFontOfSize:11]];
			[b setDelegate:self];
			return b;
		}

	} else if ([[aTableColumn identifier] isEqualToString:@"path"]) {
		if(dictMode) {
			return @"";
		} else {
			// [[aTableColumn dataCell] setTextColor:([aTableView selectedRow] == rowIndex)?[NSColor whiteColor]:[NSColor darkGrayColor]];
			// return ([[filtered objectAtIndex:rowIndex] objectForKey:@"path"]) ? [[filtered objectAtIndex:rowIndex] objectForKey:@"path"] : @"";
			if([[filtered objectAtIndex:rowIndex] objectForKey:@"path"]) {
				NSPopUpButtonCell *b = [[NSPopUpButtonCell new] autorelease];
				[b setPullsDown:NO];
				[b setAltersStateOfSelectedItem:NO];
				[b setControlSize:NSMiniControlSize];
				NSMenu *m = [[NSMenu alloc] init];
				for(id p in [[[filtered objectAtIndex:rowIndex] objectForKey:@"path"] componentsSeparatedByString:@"⇠"])
					[m addItemWithTitle:p action:NULL keyEquivalent:@""];
				[b setMenu:m];
				[m release];
				[b setPreferredEdge:NSMinXEdge];
				[b setArrowPosition:([m numberOfItems]>1) ? NSPopUpArrowAtCenter : NSPopUpNoArrow];
				[b setFont:[NSFont systemFontOfSize:11]];
				[b setBordered:NO];
				[aTableColumn setDataCell:b];
			} else {
				[aTableColumn setDataCell:[[NSTextFieldCell new] autorelease]];
			}
			return @"";
		}
	}
	return [filtered objectAtIndex:rowIndex];
}

// ======================================================================================
// = Check if at least one suggestion contains a “ ” - is so allow a “ ” to be typed in =
// ======================================================================================
- (void)checkSpaceForAllowedCharacter
{
	[textualInputCharacters removeCharactersInString:@" "];
	for(id w in filtered){
		if([[w objectForKey:@"match"] ?: [w objectForKey:@"display"] rangeOfString:@" "].length) {
			[textualInputCharacters addCharactersInString:@" "];
			break;
		}
	}
}

// ====================
// = Filter the items =
// ====================
- (void)filter
{

	NSMutableArray* newFiltered = [[NSMutableArray alloc] initWithCapacity:5];
	if([mutablePrefix length] > 0)
	{
		if(dictMode) {
			for(id w in [[NSSpellChecker sharedSpellChecker] completionsForPartialWordRange:NSMakeRange(0,[[self filterString] length]) inString:[self filterString] language:nil inSpellDocumentWithTag:0])
				[newFiltered addObject:[NSDictionary dictionaryWithObjectsAndKeys:w, @"display", nil]];
		} else {
			@try{
			NSPredicate* predicate;
			if(fuzzyMode) {
				NSMutableString *fuzzyRegexp = [[NSMutableString alloc] initWithCapacity:3];
				[fuzzyRegexp setString:@".*"];
				NSInteger i;
				unichar c;
				for(i=0; i<[[self filterString] length]; i++) {
					if(i>20) break;
					c = [[self filterString] characterAtIndex:i];
					if(c != '`') {
						if(c == '.' || c == '(' || c == ')' || c == '[' || c == ']' || c == '{' || c == '}')
							[fuzzyRegexp appendString:[NSString stringWithFormat:@"\\%c.*",c]];
						else
							[fuzzyRegexp appendString:[NSString stringWithFormat:@"%c.*",c]];
					}
				}
				// NSLog(@"re %@", fuzzyRegexp);
				if(caseSensitive)
					predicate = [NSPredicate predicateWithFormat:@"display MATCHES %@ OR isRef MATCHES %@", fuzzyRegexp, fuzzyRegexp];
				else
					predicate = [NSPredicate predicateWithFormat:@"display MATCHES[c] %@ OR isRef MATCHES[c] %@", fuzzyRegexp, fuzzyRegexp];
				[fuzzyRegexp release];
			} else {
				if(caseSensitive)
					predicate = [NSPredicate predicateWithFormat:@"match BEGINSWITH %@ OR (match == NULL AND display BEGINSWITH %@)", [self filterString], [self filterString]];
				else
					predicate = [NSPredicate predicateWithFormat:@"match BEGINSWITH[c] %@ OR (match == NULL AND display BEGINSWITH[c] %@)", [self filterString], [self filterString]];
			}
			[newFiltered addObjectsFromArray:[suggestions filteredArrayUsingPredicate:predicate]];
			}
			@catch(id ae) {
				NSLog(@"%@", @"Couldn't filter suggestion due to internal regexp error");
			}
			
		}
	}
	else
	{
		if(!dictMode)
			[newFiltered addObjectsFromArray:suggestions];
	}

	if(![newFiltered count])
		[newFiltered addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"No completions found", @"no completions found message"), @"display", @"", @"noCompletion", nil]];

	NSPoint old = NSMakePoint([self frame].origin.x, [self frame].origin.y + [self frame].size.height);

	NSInteger displayedRows = [newFiltered count] < SP_NARROWDOWNLIST_MAX_ROWS ? [newFiltered count] : SP_NARROWDOWNLIST_MAX_ROWS;
	CGFloat newHeight   = ([theTableView rowHeight] + [theTableView intercellSpacing].height) * ((displayedRows) ? displayedRows : 1);

	if(caretPos.y >= 0 && (isAbove || caretPos.y < newHeight))
	{
		isAbove = YES;
		old.y = caretPos.y + newHeight + ([tableFont pointSize]*1.5);
	}
	if(caretPos.y < 0 && (isAbove || ([self rectOfMainScreen].size.height-newHeight) < (caretPos.y*-1)))
		old.y = caretPos.y + newHeight + ([tableFont pointSize]*1.5);

	// newHeight is currently the new height for theTableView, but we need to resize the whole window
	// so here we use the difference in height to find the new height for the window
	[self setFrame:NSMakeRect(old.x, old.y-newHeight, maxWindowWidth, newHeight) display:YES];

	if (filtered) [filtered release];
	filtered = [newFiltered retain];
	[newFiltered release];
	if(!dictMode)
		[self checkSpaceForAllowedCharacter];
	[theTableView reloadData];
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
	NSRect mainScreen = [[NSScreen mainScreen] frame];
	NSScreen* candidate;
	enumerate([NSScreen screens], candidate)
	{
		if(NSMinX([candidate frame]) == 0.0f && NSMinY([candidate frame]) == 0.0f)
			mainScreen = [candidate frame];
	}
	return mainScreen;
}

// =============================
// = Run the actual popup-menu =
// =============================
- (void)orderFront:(id)sender
{
	[self filter];
	[super orderFront:sender];
	[self performSelector:@selector(watchUserEvents) withObject:nil afterDelay:0.05];
}

- (void)watchUserEvents
{
	closeMe = NO;
	while(!closeMe)
	{
		NSEvent* event = [NSApp nextEventMatchingMask:NSAnyEventMask
                                          untilDate:[NSDate distantFuture]
                                             inMode:NSDefaultRunLoopMode
                                            dequeue:YES];

		if(!event)
			continue;
		
		NSEventType t = [event type];
		if([theTableView SP_NarrowDownCompletion_canHandleEvent:event])
		{
			// skip the rest
		}
		else if(t == NSKeyDown)
		{
			NSUInteger flags = [event modifierFlags];
			unichar key        = [[event characters] length] == 1 ? [[event characters] characterAtIndex:0] : 0;

			// Check if user pressed ⌥ to allow composing of accented characters.
			// e.g. for US keyboard "⌥u a" to insert ä
			if (([event modifierFlags] & (NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask)) == NSAlternateKeyMask || [[event characters] length] == 0)
			{
				[NSApp sendEvent: event];
				[mutablePrefix appendString:[event characters]];
				theCharRange = NSMakeRange(theCharRange.location, theCharRange.length+[[event characters] length]);
				theParseRange = NSMakeRange(theParseRange.location, theParseRange.length+[[event characters] length]);
				[self filter];
			}
			else if((flags & NSControlKeyMask) || (flags & NSAlternateKeyMask) || (flags & NSCommandKeyMask))
			{
				[NSApp sendEvent:event];
				break;
			}
			else if([event keyCode] == 53) // escape
			{
				break;
			}
			else if(key == NSCarriageReturnCharacter || key == NSTabCharacter)
			{
				[self completeAndInsertSnippet];
			}
			else if(key == NSBackspaceCharacter || key == NSDeleteCharacter)
			{
				[NSApp sendEvent:event];
				if([mutablePrefix length] == 0)
					break;

				[mutablePrefix deleteCharactersInRange:NSMakeRange([mutablePrefix length]-1, 1)];
				theCharRange = NSMakeRange(theCharRange.location, theCharRange.length-1);
				theParseRange = NSMakeRange(theParseRange.location, theParseRange.length-1);
				[self filter];
			}
			else if([textualInputCharacters characterIsMember:key])
			{
				[NSApp sendEvent:event];
				[mutablePrefix appendString:[event characters]];
				theCharRange = NSMakeRange(theCharRange.location, theCharRange.length+1);
				theParseRange = NSMakeRange(theParseRange.location, theParseRange.length+1);
				[self filter];
				[self insertCommonPrefix];
			}
			else
			{
				[NSApp sendEvent:event];
				break;
			}
		}
		else if(t == NSRightMouseDown || t == NSLeftMouseDown)
		{
			if(([event clickCount] == 2)) {
				[self completeAndInsertSnippet];
			} else {
				[NSApp sendEvent:event];
				if(!NSPointInRect([NSEvent mouseLocation], [self frame]))
					break;
			}
		}
		else
		{
			[NSApp sendEvent:event];
		}
	}
	if(cursorMovedLeft) [theView performSelector:@selector(moveRight:)];
	[self close];
	usleep(70); // tiny delay to suppress while continously pressing of ESC overlapping
}

// ==================
// = Action methods =
// ==================
- (void)insertCommonPrefix
{

	if([theTableView selectedRow] == -1 || fuzzyMode)
		return;

	id cur = [filtered objectAtIndex:0];

	if([cur objectForKey:@"noCompletion"]) return;

	NSString* curMatch = [cur objectForKey:@"match"] ?: [cur objectForKey:@"display"];

	if(![curMatch length]) return;

	NSMutableString *commonPrefix = [NSMutableString string];
	[commonPrefix setString:curMatch];
	for(id candidate in filtered) {
		NSString* candidateMatch;
		candidateMatch = [candidate objectForKey:@"match"] ?: [candidate objectForKey:@"display"];
		NSString *tempPrefix = [candidateMatch commonPrefixWithString:commonPrefix options:NSCaseInsensitiveSearch];
		// if(![tempPrefix length]) break;
		if([commonPrefix length] > [tempPrefix length])
			[commonPrefix setString:tempPrefix];
	}

	// if(![commonPrefix length]) return;

	NSString* toInsert = [commonPrefix substringFromIndex:[[self filterString] length]];
	[mutablePrefix appendString:toInsert];
	theCharRange.length += [toInsert length];
	theParseRange.length += [toInsert length];
	[theView insertText:[toInsert lowercaseString]];
	[self checkSpaceForAllowedCharacter];

}

- (void)insert_text:(NSString* )aString
{
	[theView setSelectedRange:theCharRange];
	[theView insertText:aString];
	// If completion string contains backticks move caret out of the backticks
	if(backtickMode)
		[theView performSelector:@selector(moveRight:)];
}

- (void)completeAndInsertSnippet
{
	if([theTableView selectedRow] == -1) return;

	NSDictionary* selectedItem = [filtered objectAtIndex:[theTableView selectedRow]];

	if([selectedItem objectForKey:@"noCompletion"]) return;

	if(dictMode){
		[self insert_text:[selectedItem objectForKey:@"match"] ?: [selectedItem objectForKey:@"display"]];
	} else {
		NSString* candidateMatch = [selectedItem objectForKey:@"match"] ?: [selectedItem objectForKey:@"display"];
		if([selectedItem objectForKey:@"isRef"] 
				&& ([[NSApp currentEvent] modifierFlags] & (NSShiftKeyMask))
				&& [[selectedItem objectForKey:@"path"] length]) {
			NSString *path = [NSString stringWithFormat:@"%@.%@", 
				[[[[[selectedItem objectForKey:@"path"] componentsSeparatedByString:@"⇠"] reverseObjectEnumerator] allObjects] componentsJoinedByPeriodAndBacktickQuoted],
				[candidateMatch backtickQuotedString]];

			// Check if path's db name is the current selected db name
			NSRange r = [path rangeOfString:[currentDb backtickQuotedString] options:NSCaseInsensitiveSearch range:NSMakeRange(0, [[currentDb backtickQuotedString] length])];
			theCharRange = theParseRange;
			backtickMode = 0; // suppress move the caret one step rightwards
			if(path && [path length] && r.length) {
				[self insert_text:[path substringFromIndex:r.length+1]];
			} else {
				[self insert_text:path];
			}
		} else {
			// Is completion string a schema name for current connection
			if([selectedItem objectForKey:@"isRef"]) {
				backtickMode = 0; // suppress move the caret one step rightwards
				[self insert_text:[candidateMatch backtickQuotedString]];
			} else {
				[self insert_text:candidateMatch];
			}
		}
	}
	closeMe = YES;
}

@end
