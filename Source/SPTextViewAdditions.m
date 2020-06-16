//
//  SPTextViewAdditions.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on April 05, 2009.
//  Copyright (c) 2009 Hans-Jörg Bibiko. All rights reserved.
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

#import "SPAlertSheets.h"
#import "SPTooltip.h"
#ifndef SP_CODA /* headers */
#import "SPBundleHTMLOutputController.h"
#endif
#import "SPCustomQuery.h"
#ifndef SP_CODA /* headers */
#import "SPAppController.h"
#endif
#import "SPFieldEditorController.h"
#import "SPTextView.h"
#import "SPWindowController.h"
#import "SPDatabaseDocument.h"
#import "SPBundleCommandRunner.h"

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
	NSInteger start = curLocation;
	NSUInteger end = curLocation;
	NSUInteger strLen = [[self string] length];

	NSMutableCharacterSet *wordCharSet = [NSMutableCharacterSet alphanumericCharacterSet];
	[wordCharSet addCharactersInString:@"_."];
	[wordCharSet removeCharactersInString:@"`"];

	if (start) {
		start--;
		while ([wordCharSet characterIsMember:[[self string] characterAtIndex:start]]) {
			start--;
			if(start < 0) break;
		}
		start++;
	}

	while (end < strLen && [wordCharSet characterIsMember:[[self string] characterAtIndex:end]]) {
		end++;
	}

	NSRange wordRange = NSMakeRange(start, end-start);
	if (wordRange.length && [[self string] characterAtIndex:NSMaxRange(wordRange)-1] == '.')
		wordRange.length--;

	return wordRange;
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

	// look for the first non-balanced closing bracket
	for(NSUInteger i=caretPosition; i<stringLength; i++) {
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

	for(NSInteger i=caretPosition; i>=0; i--) {
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
	for(NSUInteger i=caretPosition; i<stringLength; i++) {
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
		[self setSelectedRange:NSMakeRange(NSMaxRange(newRange), 0)];
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
		[self setSelectedRange:NSMakeRange(NSMaxRange(newRange), 0)];
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
		[self setSelectedRange:NSMakeRange(NSMaxRange(newRange), 0)];
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
		[self setSelectedRange:NSMakeRange(NSMaxRange(newRange), 0)];
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
		[self setSelectedRange:NSMakeRange(NSMaxRange(newRange), 0)];
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
	if ([self respondsToSelector:@selector(insertText:)]) {
		if([prefs stringForKey:SPNullValue] && [[prefs stringForKey:SPNullValue] length])
			[self insertText:[prefs objectForKey:SPNullValue]];
		else
			[self insertText:@"NULL"];
	}
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

/**
 * Increase the textView's font size by 1
 */
- (void)makeTextStandardSize
{
	NSFont *aFont = [self font];
	BOOL editableStatus = [self isEditable];
	[self setEditable:YES];
	[self setFont:[[NSFontManager sharedFontManager] convertFont:aFont toSize:11.0f]];
	[self setEditable:editableStatus];
}

#ifndef SP_CODA
- (IBAction)executeBundleItemForInputField:(id)sender
{

	NSInteger idx = [sender tag] - 1000000;
	NSString *infoPath = nil;
	NSArray *bundleItems = [SPAppDelegate bundleItemsForScope:SPBundleScopeInputField];
	if(idx >=0 && idx < (NSInteger)[bundleItems count]) {
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

	NSDictionary *cmdData = nil;
	{
		NSError *error = nil;

		NSData *pData = [NSData dataWithContentsOfFile:infoPath options:NSUncachedRead error:&error];

		if(!error) {
			cmdData = [[NSPropertyListSerialization propertyListWithData:pData
																 options:NSPropertyListImmutable
																  format:NULL
																   error:&error] retain];
		}
		
		if(!cmdData || error) {
			NSLog(@"“%@” file couldn't be read. (readError=%@)", infoPath, error);
			NSBeep();
			if (cmdData) [cmdData release];
			return;
		}
	}

	if([cmdData objectForKey:SPBundleFileCommandKey] && [(NSString *)[cmdData objectForKey:SPBundleFileCommandKey] length]) {

		NSString *cmd = [cmdData objectForKey:SPBundleFileCommandKey];
		NSString *inputAction = @"";
		NSString *inputFallBackAction = @"";
		NSError *err = nil;
		NSString *uuid = [NSString stringWithNewUUID];
		NSString *bundleInputFilePath = [NSString stringWithFormat:@"%@_%@", [SPBundleTaskInputFilePath stringByExpandingTildeInPath], uuid];

		NSRange currentWordRange, currentSelectionRange, currentLineRange, currentQueryRange;

		[[NSFileManager defaultManager] removeItemAtPath:bundleInputFilePath error:nil];

		BOOL selfIsQueryEditor = ([[[self class] description] isEqualToString:@"SPTextView"] && [[self delegate] respondsToSelector:@selector(currentQueryRange)]);

		if([cmdData objectForKey:SPBundleFileInputSourceKey])
			inputAction = [[cmdData objectForKey:SPBundleFileInputSourceKey] lowercaseString];
		if([cmdData objectForKey:SPBundleFileInputSourceFallBackKey])
			inputFallBackAction = [[cmdData objectForKey:SPBundleFileInputSourceFallBackKey] lowercaseString];

		currentSelectionRange = [self selectedRange];
		currentWordRange = [self getRangeForCurrentWord];
		currentLineRange = [[self string] lineRangeForRange:NSMakeRange([self selectedRange].location, 0)];

		if(selfIsQueryEditor) {
			currentQueryRange = [(SPCustomQuery*)[self delegate] currentQueryRange];
		} else {
			currentQueryRange = currentLineRange;
		}
		if(!currentQueryRange.length)
			currentQueryRange = currentSelectionRange;

		NSRange replaceRange = currentSelectionRange;
		if([inputAction isEqualToString:SPBundleInputSourceSelectedText]) {
			if(!currentSelectionRange.length) {
				if([inputFallBackAction isEqualToString:SPBundleInputSourceCurrentWord])
					replaceRange = currentWordRange;
				else if([inputFallBackAction isEqualToString:SPBundleInputSourceCurrentLine])
					replaceRange = currentLineRange;
				else if([inputFallBackAction isEqualToString:SPBundleInputSourceCurrentQuery])
					replaceRange = currentQueryRange;
				else if([inputFallBackAction isEqualToString:SPBundleInputSourceEntireContent])
					replaceRange = NSMakeRange(0,[[self string] length]);
			} else {
				replaceRange = currentSelectionRange;
			}

		}
		else if([inputAction isEqualToString:SPBundleInputSourceEntireContent]) {
			replaceRange = NSMakeRange(0, [[self string] length]);
		}

		NSMutableDictionary *env = [NSMutableDictionary dictionary];
		[env setObject:[infoPath stringByDeletingLastPathComponent] forKey:SPBundleShellVariableBundlePath];
		[env setObject:bundleInputFilePath forKey:SPBundleShellVariableInputFilePath];
		[env setObject:SPBundleScopeInputField forKey:SPBundleShellVariableBundleScope];

		id tableSource = [self delegate];
		if([[[tableSource class] description] isEqualToString:@"SPFieldEditorController"]) {
			NSDictionary *editedFieldInfo = [tableSource editedFieldInfo];
			[env setObject:[editedFieldInfo objectForKey:@"colName"] forKey:SPBundleShellVariableCurrentEditedColumnName];
			if([editedFieldInfo objectForKey:@"tableName"])
				[env setObject:[editedFieldInfo objectForKey:@"tableName"] forKey:SPBundleShellVariableCurrentEditedTable];
			[env setObject:[editedFieldInfo objectForKey:@"usedQuery"] forKey:SPBundleShellVariableUsedQueryForTable];
			[env setObject:[editedFieldInfo objectForKey:@"tableSource"] forKey:SPBundleShellVariableDataTableSource];
		}
		else if([[[tableSource class] description] isEqualToString:@"SPCopyTable"]) {
			NSInteger editedCol = [tableSource editedColumn];
			if(editedCol > -1) {
				NSString *colName = [[[[tableSource tableColumns] objectAtIndex:editedCol] headerCell] stringValue];
				if([[[[tableSource dataSource] class] description] hasSuffix:@"Content"]) {
					[env setObject:[colName description] forKey:SPBundleShellVariableCurrentEditedColumnName];
					[env setObject:@"content" forKey:SPBundleShellVariableDataTableSource];
				} else {
					NSArray *defs = [[tableSource delegate] dataColumnDefinitions];
					for(NSDictionary* col in defs) {
						if([[col objectForKey:@"name"] isEqualToString:colName]) {
							[env setObject:[col objectForKey:@"org_name"] forKey:SPBundleShellVariableCurrentEditedColumnName];
							[env setObject:[col objectForKey:@"org_table"] forKey:SPBundleShellVariableCurrentEditedTable];
							break;
						}
					}
					[env setObject:@"query" forKey:SPBundleShellVariableDataTableSource];
				}
				if([[tableSource delegate] respondsToSelector:@selector(usedQuery)] && [[tableSource delegate] usedQuery])
					[env setObject:[[tableSource delegate] usedQuery] forKey:SPBundleShellVariableUsedQueryForTable];
			}
		}

		if(selfIsQueryEditor && [(SPCustomQuery*)[self delegate] currentQueryRange].length)
			[env setObject:[[self string] substringWithRange:[(SPCustomQuery*)[self delegate] currentQueryRange]] forKey:SPBundleShellVariableCurrentQuery];

		if(currentSelectionRange.length)
			[env setObject:[[self string] substringWithRange:currentSelectionRange] forKey:SPBundleShellVariableSelectedText];

		if(currentWordRange.length)
			[env setObject:[[self string] substringWithRange:currentWordRange] forKey:SPBundleShellVariableCurrentWord];

		if(currentLineRange.length)
			[env setObject:[[self string] substringWithRange:currentLineRange] forKey:SPBundleShellVariableCurrentLine];

		[env setObject:NSStringFromRange(replaceRange) forKey:SPBundleShellVariableSelectedTextRange];

		NSError *inputFileError = nil;
		NSString *input = [NSString stringWithString:[[self string] substringWithRange:replaceRange]];

		[input writeToFile:bundleInputFilePath
				  atomically:YES
					encoding:NSUTF8StringEncoding
					   error:&inputFileError];

		if(inputFileError != nil) {
			NSString *errorMessage  = [inputFileError localizedDescription];
			SPOnewayAlertSheet(
				NSLocalizedString(@"Bundle Error", @"bundle error"),
				[self window],
				[NSString stringWithFormat:@"%@ “%@”:\n%@", NSLocalizedString(@"Error for", @"error for message"), [cmdData objectForKey:@"name"], errorMessage]
			);
			if (cmdData) [cmdData release];
			return;
		}

		NSString *output = [SPBundleCommandRunner runBashCommand:cmd withEnvironment:env 
										atCurrentDirectoryPath:nil 
										callerInstance:[SPAppDelegate frontDocument]
										contextInfo:[NSDictionary dictionaryWithObjectsAndKeys:
												([cmdData objectForKey:SPBundleFileNameKey])?:@"-", @"name",
												NSLocalizedString(@"Input Field", @"input field menu item label"), @"scope",
																  uuid, SPBundleFileInternalexecutionUUID, nil]
										error:&err];

		[[NSFileManager defaultManager] removeItemAtPath:bundleInputFilePath error:nil];

		NSString *action = SPBundleOutputActionNone;
		if([cmdData objectForKey:SPBundleFileOutputActionKey] && [(NSString *)[cmdData objectForKey:SPBundleFileOutputActionKey] length])
			action = [[cmdData objectForKey:SPBundleFileOutputActionKey] lowercaseString];

		// Redirect due exit code
		if(err != nil) {
			if([err code] == SPBundleRedirectActionNone) {
				action = SPBundleOutputActionNone;
				err = nil;
			}
			else if([err code] == SPBundleRedirectActionReplaceSection) {
				action = SPBundleOutputActionReplaceSelection;
				err = nil;
			}
			else if([err code] == SPBundleRedirectActionReplaceContent) {
				action = SPBundleOutputActionReplaceContent;
				err = nil;
			}
			else if([err code] == SPBundleRedirectActionInsertAsText) {
				action = SPBundleOutputActionInsertAsText;
				err = nil;
			}
			else if([err code] == SPBundleRedirectActionInsertAsSnippet) {
				action = SPBundleOutputActionInsertAsSnippet;
				err = nil;
			}
			else if([err code] == SPBundleRedirectActionShowAsHTML) {
				action = SPBundleOutputActionShowAsHTML;
				err = nil;
			}
			else if([err code] == SPBundleRedirectActionShowAsTextTooltip) {
				action = SPBundleOutputActionShowAsTextTooltip;
				err = nil;
			}
			else if([err code] == SPBundleRedirectActionShowAsHTMLTooltip) {
				action = SPBundleOutputActionShowAsHTMLTooltip;
				err = nil;
			}
		}

		if(err == nil && output) {
			if(![action isEqualToString:SPBundleOutputActionNone]) {

				if([action isEqualToString:SPBundleOutputActionShowAsTextTooltip]) {
					[SPTooltip showWithObject:output];
				}

				else if([action isEqualToString:SPBundleOutputActionShowAsHTMLTooltip]) {
					[SPTooltip showWithObject:output ofType:@"html"];
				}

				else if([action isEqualToString:SPBundleOutputActionShowAsHTML]) {
					BOOL correspondingWindowFound = NO;
					for(id win in [NSApp windows]) {
						if([[win delegate] isKindOfClass:[SPBundleHTMLOutputController class]]) {
							if([[[win delegate] windowUUID] isEqualToString:[cmdData objectForKey:SPBundleFileUUIDKey]]) {
								correspondingWindowFound = YES;
								[[win delegate] displayHTMLContent:output withOptions:nil];
								break;
							}
						}
					}
					if(!correspondingWindowFound) {
						SPBundleHTMLOutputController *c = [[SPBundleHTMLOutputController alloc] init];
						[c setWindowUUID:[cmdData objectForKey:SPBundleFileUUIDKey]];
						[c displayHTMLContent:output withOptions:nil];
						[SPAppDelegate addHTMLOutputController:c];
					}
				}

				if([self isEditable]) {

					if([action isEqualToString:SPBundleOutputActionInsertAsText]) {
						[self insertText:output];
					}

					else if([action isEqualToString:SPBundleOutputActionInsertAsSnippet]) {
						if([self respondsToSelector:@selector(insertAsSnippet:atRange:)])
							[(SPTextView *)self insertAsSnippet:output atRange:replaceRange];
						else
							[SPTooltip showWithObject:NSLocalizedString(@"Input Field doesn't support insertion of snippets.", @"input field  doesn't support insertion of snippets.")];
					}

					else if([action isEqualToString:SPBundleOutputActionReplaceContent]) {
						if([[self string] length])
							[self setSelectedRange:NSMakeRange(0, [[self string] length])];
						[self insertText:output];
					}

					else if([action isEqualToString:SPBundleOutputActionReplaceSelection]) {
						NSRange safeRange = NSIntersectionRange(replaceRange, NSMakeRange(0, [[self string] length]));
						[self shouldChangeTextInRange:safeRange replacementString:output];
						[self replaceCharactersInRange:safeRange withString:output];
					}

				} else {
					[SPTooltip showWithObject:NSLocalizedString(@"Input Field is not editable.", @"input field is not editable.")];
				}

			}
		} else if([err code] != 9) { // Suppress an error message if command was killed
			NSString *errorMessage  = [err localizedDescription];
			SPOnewayAlertSheet(
				NSLocalizedString(@"BASH Error", @"bash error"),
				[self window],
				[NSString stringWithFormat:@"%@ “%@”:\n%@", NSLocalizedString(@"Error for", @"error for message"), [cmdData objectForKey:@"name"], errorMessage]
			);
		}

	}

	if (cmdData) [cmdData release];
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

	if ([[[(SPWindowController *)[[SPAppDelegate frontDocumentWindow] delegate] selectedTableDocument] connectionID] isEqualToString:@"_"]) return menu;

	[SPAppDelegate reloadBundles:self];

	NSArray *bundleCategories = [SPAppDelegate bundleCategoriesForScope:SPBundleScopeInputField];
	NSArray *bundleItems = [SPAppDelegate bundleItemsForScope:SPBundleScopeInputField];

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

			[mItem setTarget:[[NSApp keyWindow] firstResponder]];

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
#endif

@end
