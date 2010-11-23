//
//  $Id$
//
//  SPTextViewAdditions.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on April 05, 2009
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

#import "SPAlertSheets.h"
#import "SPTooltip.h"
#import "SPBundleHTMLOutputController.h"
#import "SPCustomQuery.h"

@implementation NSTextView (SPTextViewAdditions)

/*
 * Returns the range of the current word.
 *   finds: [| := caret]  |word  wo|rd  word|
 * If | is in between whitespaces nothing will be selected.
 */
- (NSRange)getRangeForCurrentWord
{
	NSRange curRange = [self selectedRange];
	
	if (curRange.length)
        return curRange;
	
	NSUInteger curLocation = curRange.location;

	[self moveWordLeft:self];
	[self moveWordRightAndModifySelection:self];
	
	NSUInteger newStartRange = [self selectedRange].location;
	NSUInteger newEndRange = newStartRange + [self selectedRange].length;
	
	// if current location does not intersect with found range
	// then caret is at the begin of a word -> change strategy
	if(curLocation < newStartRange || curLocation > newEndRange)
	{
		[self setSelectedRange:curRange];
		[self moveWordRight:self];
		[self moveWordLeftAndModifySelection:self];
		newStartRange = [self selectedRange].location;
		newEndRange = newStartRange + [self selectedRange].length;
	}
	
	// how many space in front of the selection
	NSInteger bias = [self selectedRange].length - [[[[self string] substringWithRange:[self selectedRange]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length];
	[self setSelectedRange:NSMakeRange([self selectedRange].location+bias, [self selectedRange].length-bias)];
	newStartRange += bias;
	newEndRange -= bias;

	// is caret inside the selection still?
	if(curLocation < newStartRange || curLocation > newEndRange 
		|| [[[self string] substringWithRange:[self selectedRange]] rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location != NSNotFound)
		[self setSelectedRange:curRange];
	
	NSRange wordRange = [self selectedRange];
	
	[self setSelectedRange:curRange];
	
	return(wordRange);
}

/*
 * Select current word.
 *   finds: [| := caret]  |word  wo|rd  word|
 * If | is in between whitespaces nothing will be selected.
 */
- (IBAction)selectCurrentWord:(id)sender
{
	[self setSelectedRange:[self getRangeForCurrentWord]];
}

/*
 * Select current line.
 */
- (IBAction)selectCurrentLine:(id)sender
{
	NSRange lineRange = [[self string] lineRangeForRange:[self selectedRange]];
	if(lineRange.location != NSNotFound && lineRange.length)
		[self setSelectedRange:lineRange];
	else
		NSBeep();
}

/*
 *
 */
- (IBAction)selectEnclosingBrackets:(id)sender
{
	NSUInteger caretPosition = [self selectedRange].location;
	NSUInteger stringLength = [[self string] length];
	unichar co, cc;
	
	if(caretPosition == 0 || caretPosition >= stringLength) return;

	NSInteger pcnt = 0;
	NSInteger bcnt = 0;
	NSInteger scnt = 0;

	NSInteger i;

	// look for the first non-balanced closing bracket
	for(i=caretPosition; i<stringLength; i++) {
		switch([[self string] characterAtIndex:i]) {
			case ')': 
			if(!pcnt) {
				co='(';cc=')';
				i=stringLength;
			}
			pcnt++; break;
			case '(': pcnt--; break;
			case ']': 
			if(!bcnt) {
				co='[';cc=']';
				i=stringLength;
			}
			bcnt++; break;
			case '[': bcnt--; break;
			case '}': 
			if(!scnt) {
				co='{';cc='}';
				i=stringLength;
			}
			scnt++; break;
			case '{': scnt--; break;
		}
	}
	
	NSInteger start = -1;
	NSInteger end = -1;
	NSInteger bracketCounter = 0;

	if([[self string] characterAtIndex:caretPosition] == cc)
		bracketCounter--;
	if([[self string] characterAtIndex:caretPosition] == co)
		bracketCounter++;

	for(i=caretPosition; i>=0; i--) {
		if([[self string] characterAtIndex:i] == co) {
			if(!bracketCounter) {
				start = i;
				break;
			}
			bracketCounter--;
		}
		if([[self string] characterAtIndex:i] == cc) {
			bracketCounter++;
		}
	}
	if(start < 0 ) return;

	bracketCounter = 0;
	for(i=caretPosition; i<stringLength; i++) {
		if([[self string] characterAtIndex:i] == co) {
			bracketCounter++;
		}
		if([[self string] characterAtIndex:i] == cc) {
			if(!bracketCounter) {
				end = i+1;
				break;
			}
			bracketCounter--;
		}
	}
	if(end < 0 || bracketCounter || end-start < 1) return;
	
	[self setSelectedRange:NSMakeRange(start, end-start)];
	
}

/*
 * Change selection or current word to upper case and preserves the selection.
 */
- (IBAction)doSelectionUpperCase:(id)sender
{
	NSRange curRange = [self selectedRange];
	NSRange selRange = (curRange.length) ? curRange : [self getRangeForCurrentWord];
	[self setSelectedRange:selRange];
	[self insertText:[[[self string] substringWithRange:selRange] uppercaseString]];
	[self setSelectedRange:curRange];
}

/*
 * Change selection or current word to lower case and preserves the selection.
 */
- (IBAction)doSelectionLowerCase:(id)sender
{
	NSRange curRange = [self selectedRange];
	NSRange selRange = (curRange.length) ? curRange : [self getRangeForCurrentWord];
	[self setSelectedRange:selRange];
	[self insertText:[[[self string] substringWithRange:selRange] lowercaseString]];
	[self setSelectedRange:curRange];
}

/*
 * Change selection or current word to title case and preserves the selection.
 */
- (IBAction)doSelectionTitleCase:(id)sender
{
	NSRange curRange = [self selectedRange];
	NSRange selRange = (curRange.length) ? curRange : [self getRangeForCurrentWord];
	[self setSelectedRange:selRange];
	[self insertText:[[[self string] substringWithRange:selRange] capitalizedString]];
	[self setSelectedRange:curRange];
}

/*
 * Change selection or current word according to Unicode's NFD and preserves the selection.
 */
- (IBAction)doDecomposedStringWithCanonicalMapping:(id)sender
{
	NSRange curRange = [self selectedRange];
	NSRange selRange = (curRange.length) ? curRange : [self getRangeForCurrentWord];
	[self setSelectedRange:selRange];
	NSString* convString = [[[self string] substringWithRange:selRange] decomposedStringWithCanonicalMapping];
	[self insertText:convString];
	
	// correct range for combining characters
	if(curRange.length)
		[self setSelectedRange:NSMakeRange(selRange.location, [convString length])];
	else
	// if no selection place the caret at the end of the current word
	{
		NSRange newRange = [self getRangeForCurrentWord];
		[self setSelectedRange:NSMakeRange(newRange.location + newRange.length, 0)];
	}
}

/*
 * Change selection or current word according to Unicode's NFKD and preserves the selection.
 */
- (IBAction)doDecomposedStringWithCompatibilityMapping:(id)sender
{
	NSRange curRange = [self selectedRange];
	NSRange selRange = (curRange.length) ? curRange : [self getRangeForCurrentWord];
	[self setSelectedRange:selRange];
	NSString* convString = [[[self string] substringWithRange:selRange] decomposedStringWithCompatibilityMapping];
	[self insertText:convString];
	
	// correct range for combining characters
	if(curRange.length)
		[self setSelectedRange:NSMakeRange(selRange.location, [convString length])];
	else
	// if no selection place the caret at the end of the current word
	{
		NSRange newRange = [self getRangeForCurrentWord];
		[self setSelectedRange:NSMakeRange(newRange.location + newRange.length, 0)];
	}
}

/*
 * Change selection or current word according to Unicode's NFC and preserves the selection.
 */
- (IBAction)doPrecomposedStringWithCanonicalMapping:(id)sender
{
	NSRange curRange = [self selectedRange];
	NSRange selRange = (curRange.length) ? curRange : [self getRangeForCurrentWord];
	[self setSelectedRange:selRange];
	NSString* convString = [[[self string] substringWithRange:selRange] precomposedStringWithCanonicalMapping];
	[self insertText:convString];
	
	// correct range for combining characters
	if(curRange.length)
		[self setSelectedRange:NSMakeRange(selRange.location, [convString length])];
	else
	// if no selection place the caret at the end of the current word
	{
		NSRange newRange = [self getRangeForCurrentWord];
		[self setSelectedRange:NSMakeRange(newRange.location + newRange.length, 0)];
	}
}

- (IBAction)doRemoveDiacritics:(id)sender
{

	NSRange curRange = [self selectedRange];
	NSRange selRange = (curRange.length) ? curRange : [self getRangeForCurrentWord];
	[self setSelectedRange:selRange];
	NSString* convString = [[[self string] substringWithRange:selRange] decomposedStringWithCanonicalMapping];
	NSArray* chars;
	chars = [convString componentsSeparatedByCharactersInSet:[NSCharacterSet nonBaseCharacterSet]];
	NSString* cleanString = [chars componentsJoinedByString:@""];
	[self insertText:cleanString];
	if(curRange.length)
		[self setSelectedRange:NSMakeRange(selRange.location, [cleanString length])];
	else
	// if no selection place the caret at the end of the current word
	{
		NSRange newRange = [self getRangeForCurrentWord];
		[self setSelectedRange:NSMakeRange(newRange.location + newRange.length, 0)];
	}
	
}

/*
 * Change selection or current word according to Unicode's NFKC to title case and preserves the selection.
 */
- (IBAction)doPrecomposedStringWithCompatibilityMapping:(id)sender
{
	NSRange curRange = [self selectedRange];
	NSRange selRange = (curRange.length) ? curRange : [self getRangeForCurrentWord];
	[self setSelectedRange:selRange];
	NSString* convString = [[[self string] substringWithRange:selRange] precomposedStringWithCompatibilityMapping];
	[self insertText:convString];
	
	// correct range for combining characters
	if(curRange.length)
		[self setSelectedRange:NSMakeRange(selRange.location, [convString length])];
	else
	// if no selection place the caret at the end of the current word
	{
		NSRange newRange = [self getRangeForCurrentWord];
		[self setSelectedRange:NSMakeRange(newRange.location + newRange.length, 0)];
	}
}


/*
 * Transpose adjacent characters, or if a selection is given reverse the selected characters.
 * If the caret is at the absolute end of the text field it transpose the two last charaters.
 * If the caret is at the absolute beginnng of the text field do nothing.
 * TODO: not yet combining-diacritics-safe
 */
- (IBAction)doTranspose:(id)sender
{
	NSRange curRange = [self selectedRange];
	NSRange workingRange = curRange;
	
	if(!curRange.length)
		@try // caret is in between two chars
		{
			if(curRange.location+1 > [[self string] length])
			{
				// caret is at the end of a text field
				// transpose last two characters
				[self moveLeftAndModifySelection:self];
				[self moveLeftAndModifySelection:self];
				workingRange = [self selectedRange];
			}
			else if(curRange.location == 0)
			{
				// caret is at the beginning of the text field
				// do nothing
				workingRange.length = 0;
			}
			else
			{
				// caret is in between two characters
				// reverse adjacent characters 
				NSRange twoCharRange = NSMakeRange(curRange.location-1, 2);
				[self setSelectedRange:twoCharRange];
				workingRange = twoCharRange;
			}
		}
		@catch(id ae)
		{ workingRange.length = 0; }

	
	
	// reverse string : TODO not yet combining diacritics safe!
	NSUInteger len = workingRange.length;
	if (len > 1)
	{
		NSMutableString *reversedStr = [NSMutableString stringWithCapacity:len];
		while (len > 0)
			[reversedStr appendString:
				[NSString stringWithFormat:@"%C", [[self string] characterAtIndex:--len+workingRange.location]]];

		[self insertText:reversedStr];
		[self setSelectedRange:curRange];
	}
}

/**
 * Inserts the preference's NULL value set by the user
 */
- (IBAction)insertNULLvalue:(id)sender
{

	id prefs = [NSUserDefaults standardUserDefaults];
	if([self respondsToSelector:@selector(insertText:)])
		if([prefs objectForKey:SPNullValue] && [[prefs objectForKey:SPNullValue] length])
			[self insertText:[prefs objectForKey:SPNullValue]];
		else
			[self insertText:@"NULL"];

}

/**
 * Move selected lines or current line one line up
 */
- (IBAction)moveSelectionLineUp:(id)sender;
{
	NSRange currentSelection = [self selectedRange];
	NSRange lineRange = [[self string] lineRangeForRange:currentSelection];
	if(lineRange.location > 0) {
		NSRange beforeLineRange = [[self string] lineRangeForRange:NSMakeRange(lineRange.location-1, 0)];
		NSRange insertPoint = NSMakeRange(beforeLineRange.location, 0);
		NSString *currentLine = [[self string] substringWithRange:lineRange];
		BOOL lastLine = NO;
		if([currentLine characterAtIndex:[currentLine length]-1] != '\n') {
			currentLine = [NSString stringWithFormat:@"%@\n", currentLine];
			lastLine = YES;
		}
		[self setSelectedRange:lineRange];
		[self insertText:@""];
		[self setSelectedRange:insertPoint];
		[self insertText:currentLine];
		if(lastLine) {
			[self setSelectedRange:NSMakeRange([[self string] length]-1,1)];
			[self insertText:@""];
			
		}
		if(currentSelection.length)
			insertPoint.length+=[currentLine length];
		[self setSelectedRange:insertPoint];
	}
}

/**
 * Move selected lines or current line one line down
 */
- (IBAction)moveSelectionLineDown:(id)sender
{

	NSRange currentSelection = [self selectedRange];
	NSRange lineRange = [[self string] lineRangeForRange:currentSelection];
	if(NSMaxRange(lineRange) < [[self string] length]) {
		NSRange afterLineRange = [[self string] lineRangeForRange:NSMakeRange(NSMaxRange(lineRange), 0)];
		NSRange insertPoint = NSMakeRange(lineRange.location + afterLineRange.length, 0);
		NSString *currentLine = [[self string] substringWithRange:lineRange];
		[self setSelectedRange:lineRange];
		[self insertText:@""];
		[self setSelectedRange:insertPoint];
		if([[self string] characterAtIndex:insertPoint.location-1] != '\n') {
			[self insertText:@"\n"];
			insertPoint.location++;
			currentLine = [currentLine substringToIndex:[currentLine length]-1];
		}
		[self insertText:currentLine];
		if(currentSelection.length)
			insertPoint.length+=[currentLine length];
		[self setSelectedRange:insertPoint];
	}
}

/**
 * Increase the textView's font size by 1
 */
- (void)makeTextSizeLarger
{
	NSFont *aFont = [self font];
	BOOL editableStatus = [self isEditable];
	[self setEditable:YES];
	[self setFont:[[NSFontManager sharedFontManager] convertFont:aFont toSize:[aFont pointSize]+1]];
	[self setEditable:editableStatus];
}

/*
 * Decrease the textView's font size by 1 but not smaller than 4pt
 */
- (void)makeTextSizeSmaller
{
	NSFont *aFont = [self font];
	NSInteger newSize = ([aFont pointSize]-1 < 4) ? [aFont pointSize] : [aFont pointSize]-1;
	BOOL editableStatus = [self isEditable];
	[self setEditable:YES];
	[self setFont:[[NSFontManager sharedFontManager] convertFont:aFont toSize:newSize]];
	[self setEditable:editableStatus];
}

- (IBAction)executeBundleItemForInputField:(id)sender
{

	NSInteger idx = [sender tag] - 1000000;
	NSString *infoPath = nil;
	NSArray *bundleItems = [[NSApp delegate] bundleItemsForScope:SPBundleScopeInputField];
	if(idx >=0 && idx < [bundleItems count]) {
		infoPath = [[bundleItems objectAtIndex:idx] objectForKey:SPBundleInternPathToFileKey];
	} else {
		if([sender tag] == 0 && [[sender toolTip] length]) {
			infoPath = [sender toolTip];
		}
	}

	if(!infoPath) {
		NSBeep();
		return;
	}

	NSError *readError = nil;
	NSString *convError = nil;
	NSPropertyListFormat format;
	NSDictionary *cmdData = nil;
	NSData *pData = [NSData dataWithContentsOfFile:infoPath options:NSUncachedRead error:&readError];

	cmdData = [[NSPropertyListSerialization propertyListFromData:pData 
			mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&convError] retain];

	if(!cmdData || readError != nil || [convError length] || !(format == NSPropertyListXMLFormat_v1_0 || format == NSPropertyListBinaryFormat_v1_0)) {
		NSLog(@"“%@” file couldn't be read.", infoPath);
		NSBeep();
		if (cmdData) [cmdData release];
		return;
	} else {
		if([cmdData objectForKey:SPBundleFileCommandKey] && [[cmdData objectForKey:SPBundleFileCommandKey] length]) {

			NSString *cmd = [cmdData objectForKey:SPBundleFileCommandKey];
			NSString *inputAction = @"";
			NSString *inputFallBackAction = @"";
			NSError *err = nil;
			NSString *bundleInputFilePath = [NSString stringWithFormat:@"%@_%@", SPBundleTaskInputFilePath, [NSString stringWithNewUUID]];

			NSRange currentWordRange, currentSelectionRange, currentLineRange, currentQueryRange;

			[[NSFileManager defaultManager] removeItemAtPath:bundleInputFilePath error:nil];

			BOOL selfIsQueryEditor = ([[[self class] description] isEqualToString:@"SPTextView"]) ;

			if([cmdData objectForKey:SPBundleFileInputSourceKey])
				inputAction = [[cmdData objectForKey:SPBundleFileInputSourceKey] lowercaseString];
			if([cmdData objectForKey:SPBundleFileInputSourceFallBackKey])
				inputFallBackAction = [[cmdData objectForKey:SPBundleFileInputSourceFallBackKey] lowercaseString];

			currentSelectionRange = [self selectedRange];
			currentWordRange = [self getRangeForCurrentWord];
			currentLineRange = [[self string] lineRangeForRange:NSMakeRange([self selectedRange].location, 0)];

			if(selfIsQueryEditor) {
				currentQueryRange = [[self delegate] currentQueryRange];
			} else {
				currentQueryRange = currentLineRange;
			}
			if(!currentQueryRange.length)
				currentQueryRange = currentSelectionRange;

			NSRange replaceRange = NSMakeRange(currentSelectionRange.location, 0);
			if([inputAction isEqualToString:SPBundleInputSourceSelectedText]) {
				if(!currentSelectionRange.length) {
					if([inputFallBackAction isEqualToString:SPBundleInputSourceCurrentWord])
						replaceRange = currentWordRange;
					else if([inputFallBackAction isEqualToString:SPBundleInputSourceCurrentLine])
						replaceRange = currentLineRange;
					else if([inputFallBackAction isEqualToString:SPBundleInputSourceCurrentQuery])
						replaceRange = currentQueryRange;
					else if([inputAction isEqualToString:SPBundleInputSourceEntireContent])
						replaceRange = NSMakeRange(0,[[self string] length]);
				} else {
					replaceRange = currentSelectionRange;
				}

			}
			else if([inputAction isEqualToString:SPBundleInputSourceEntireContent]) {
				replaceRange = NSMakeRange(0, [[self string] length]);
			}

			NSMutableDictionary *env = [NSMutableDictionary dictionary];
			[env setObject:[infoPath stringByDeletingLastPathComponent] forKey:@"SP_BUNDLE_PATH"];
			[env setObject:bundleInputFilePath forKey:@"SP_BUNDLE_INPUT_FILE"];

			if(selfIsQueryEditor && [[self delegate] currentQueryRange].length)
				[env setObject:[[self string] substringWithRange:[[self delegate] currentQueryRange]] forKey:@"SP_CURRENT_QUERY"];

			if(currentSelectionRange.length)
				[env setObject:[[self string] substringWithRange:currentSelectionRange] forKey:@"SP_SELECTED_TEXT"];

			if(currentWordRange.length)
				[env setObject:[[self string] substringWithRange:currentWordRange] forKey:@"SP_CURRENT_WORD"];

			if(currentLineRange.length)
				[env setObject:[[self string] substringWithRange:currentLineRange] forKey:@"SP_CURRENT_LINE"];

			NSError *inputFileError = nil;
			NSString *input = [NSString stringWithString:[[self string] substringWithRange:replaceRange]];
			[input writeToFile:bundleInputFilePath
					  atomically:YES
						encoding:NSUTF8StringEncoding
						   error:&inputFileError];

			if(inputFileError != nil) {
				NSString *errorMessage  = [inputFileError localizedDescription];
				SPBeginAlertSheet(NSLocalizedString(@"Bundle Error", @"bundle error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [self window], self, nil, nil,
								  [NSString stringWithFormat:@"%@ “%@”:\n%@", NSLocalizedString(@"Error for", @"error for message"), [cmdData objectForKey:@"name"], errorMessage]);
				if (cmdData) [cmdData release];
				return;
			}

			NSString *output = [cmd runBashCommandWithEnvironment:env atCurrentDirectoryPath:nil error:&err];

			[[NSFileManager defaultManager] removeItemAtPath:bundleInputFilePath error:nil];

			if(err == nil && output && [cmdData objectForKey:SPBundleFileOutputActionKey]) {
				if([[cmdData objectForKey:SPBundleFileOutputActionKey] length] 
						&& ![[cmdData objectForKey:SPBundleFileOutputActionKey] isEqualToString:SPBundleOutputActionNone]) {
					NSString *action = [[cmdData objectForKey:SPBundleFileOutputActionKey] lowercaseString];

					if([action isEqualToString:SPBundleOutputActionShowAsTextTooltip]) {
						[SPTooltip showWithObject:output];
					}

					else if([action isEqualToString:SPBundleOutputActionShowAsHTMLTooltip]) {
						[SPTooltip showWithObject:output ofType:@"html"];
					}

					else if([action isEqualToString:SPBundleOutputActionShowAsHTML]) {
						SPBundleHTMLOutputController *c = [[SPBundleHTMLOutputController alloc] init];
						[c displayHTMLContent:output withOptions:nil];
					}

					if([self isEditable]) {

						if([action isEqualToString:SPBundleOutputActionInsertAsText]) {
							[self insertText:output];
						}

						else if([action isEqualToString:SPBundleOutputActionInsertAsSnippet]) {
							if([self respondsToSelector:@selector(insertAsSnippet:atRange:)])
								[self insertAsSnippet:output atRange:replaceRange];
							else
								[SPTooltip showWithObject:NSLocalizedString(@"Input Field doesn't support insertion of snippets.", @"input field  doesn't support insertion of snippets.")];
						}

						else if([action isEqualToString:SPBundleOutputActionReplaceContent]) {
							if([[self string] length])
								[self setSelectedRange:NSMakeRange(0, [[self string] length])];
							[self insertText:output];
						}

						else if([action isEqualToString:SPBundleOutputActionReplaceSelection]) {
							[self shouldChangeTextInRange:replaceRange replacementString:output];
							[self replaceCharactersInRange:replaceRange withString:output];
						}

					} else {
						[SPTooltip showWithObject:NSLocalizedString(@"Input Field is not editable.", @"input field is not editable.")];
					}

				}
			} else {
				NSString *errorMessage  = [err localizedDescription];
				SPBeginAlertSheet(NSLocalizedString(@"BASH Error", @"bash error"), NSLocalizedString(@"OK", @"OK button"), nil, nil, [self window], self, nil, nil,
								  [NSString stringWithFormat:@"%@ “%@”:\n%@", NSLocalizedString(@"Error for", @"error for message"), [cmdData objectForKey:@"name"], errorMessage]);
			}

		}

		if (cmdData) [cmdData release];

	}

}

/**
 * Add Bundle menu items.
 */
- (NSMenu *)menuForEvent:(NSEvent *)event 
{

	NSMenu *menu = [[self class] defaultMenu];

	// Remove 'Bundles' sub menu and separator
	NSMenuItem *bItem = [menu itemWithTag:10000000];
	if(bItem) {
		NSInteger sepIndex = [menu indexOfItem:bItem]-1;
		[menu removeItemAtIndex:sepIndex];
		[menu removeItem:bItem];
	}

	if([[[[[[NSApp delegate] frontDocumentWindow] delegate] selectedTableDocument] connectionID] isEqualToString:@"_"]) return menu;

	[[NSApp delegate] reloadBundles:self];

	NSArray *bundleCategories = [[NSApp delegate] bundleCategoriesForScope:SPBundleScopeInputField];
	NSArray *bundleItems = [[NSApp delegate] bundleItemsForScope:SPBundleScopeInputField];

	// Add 'Bundles' sub menu
	if(bundleItems && [bundleItems count]) {
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

			[mItem setTarget:[[NSApp mainWindow] firstResponder]];

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

	return menu;

}

#pragma mark -
#pragma mark multi-touch trackpad support

/**
 * Trackpad two-finger zooming gesture for in/decreasing the font size
 */
- (void) magnifyWithEvent:(NSEvent *)anEvent
{

	//Avoid font resizing for NSTextViews in SPCopyTable or NSTableView
	if([[[[self delegate] class] description] isEqualToString:@"SPCopyTable"] 
		|| [[[[self delegate] class] description] isEqualToString:@"NSTableView"]) return;

	if([anEvent deltaZ]>5.0)
		[self makeTextSizeLarger];
	else if([anEvent deltaZ]<-5.0)
		[self makeTextSizeSmaller];
}

@end
