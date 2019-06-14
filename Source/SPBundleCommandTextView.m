//
//  SPBundleCommandTextView.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on November 19, 2010.
//  Copyright (c) 2010 Hans-Jörg Bibiko. All rights reserved.
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

#import "SPBundleCommandTextView.h"
#import "SPTextViewAdditions.h"
#import "SPBundleEditorController.h"
#import "NoodleLineNumberView.h"
#import "RegexKitLite.h"

@implementation SPBundleCommandTextView

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[prefs removeObserver:self forKeyPath:SPCustomQueryEditorTabStopWidth];
	SPClear(prefs);
	SPClear(lineNumberView);
	[super dealloc];
}

- (void)awakeFromNib
{

	prefs = [[NSUserDefaults standardUserDefaults] retain];

	[prefs addObserver:self forKeyPath:SPCustomQueryEditorTabStopWidth options:NSKeyValueObservingOptionNew context:NULL];

	if([prefs dataForKey:@"BundleEditorFont"]) {
		NSFont *nf = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:@"BundleEditorFont"]];
		[self setFont:nf];
	}

	lineNumberView = [[NoodleLineNumberView alloc] initWithScrollView:commandScrollView];
	[commandScrollView setVerticalRulerView:lineNumberView];
	[commandScrollView setHasHorizontalRuler:NO];
	[commandScrollView setHasVerticalRuler:YES];
	[commandScrollView setRulersVisible:YES];
	
	// disable typo stuff in 10.8+ SDK
	[self setAutomaticDashSubstitutionEnabled:NO];
	[self setAutomaticQuoteSubstitutionEnabled:NO];

	// Re-define tab stops for a better editing
	[self setTabStops];

	// disabled to get the current text range in textView safer
	[[self layoutManager] setBackgroundLayoutEnabled:NO];

	// add NSViewBoundsDidChangeNotification to scrollView
	[commandScrollView setPostsBoundsChangedNotifications:YES];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(boundsDidChangeNotification:) name:NSViewBoundsDidChangeNotification object:[commandScrollView contentView]];

}

- (void)drawRect:(NSRect)rect
{
	// Draw background only for screen display but not while printing
	if([NSGraphicsContext currentContextDrawingToScreen]) {

		// Draw textview's background since due to the snippet highlighting we're responsible for it.
		[[NSColor whiteColor] setFill];
		NSRectFill(rect);

		if (![self selectedRange].length && [[self string] length]) {
			NSRange r = [[self string] lineRangeForRange:NSMakeRange([self selectedRange].location, 0)];
			NSUInteger rectCount;
			[[self textStorage] ensureAttributesAreFixedInRange:r];
			NSRectArray queryRects = [[self layoutManager] rectArrayForCharacterRange: r
														 withinSelectedCharacterRange: r
																	  inTextContainer: [self textContainer]
																			rectCount: &rectCount ];
			[[NSColor colorWithCalibratedRed:0.95f green:0.95f blue:0.95f alpha:1.0f] setFill];
			NSRectFillListUsingOperation(queryRects, rectCount, NSCompositeSourceOver);
		}
	}

	[super drawRect:rect];

}

#pragma mark -

/**
 * Shifts the selection, if any, rightwards by indenting any selected lines with one tab.
 * If the caret is within a line, the selection is not changed after the index; if the selection
 * has length, all lines crossed by the length are indented and fully selected.
 * Returns whether or not an indentation was performed.
 */
- (BOOL)shiftSelectionRight
{
	NSString *textViewString = [[self textStorage] string];
	NSRange currentLineRange;

	if ([self selectedRange].location == NSNotFound || ![self isEditable]) return NO;

	// Indent the currently selected line if the caret is within a single line
	if ([self selectedRange].length == 0) {

		// Extract the current line range based on the text caret
		currentLineRange = [textViewString lineRangeForRange:[self selectedRange]];

		// Register the indent for undo
		[self shouldChangeTextInRange:NSMakeRange(currentLineRange.location, 0) replacementString:@"\t"];

		// Insert the new tab
		[self replaceCharactersInRange:NSMakeRange(currentLineRange.location, 0) withString:@"\t"];

		return YES;
	}

	// Otherwise, something is selected
	NSRange firstLineRange = [textViewString lineRangeForRange:NSMakeRange([self selectedRange].location,0)];
	NSUInteger lastLineMaxRange = NSMaxRange([textViewString lineRangeForRange:NSMakeRange(NSMaxRange([self selectedRange])-1,0)]);
	
	// Expand selection for first and last line to begin and end resp. but not the last line ending
	NSRange blockRange = NSMakeRange(firstLineRange.location, lastLineMaxRange - firstLineRange.location);
	if([textViewString characterAtIndex:NSMaxRange(blockRange)-1] == '\n' || [textViewString characterAtIndex:NSMaxRange(blockRange)-1] == '\r')
		blockRange.length--;

	// Replace \n by \n\t of all lines in blockRange
	NSString *newString;
	// check for line ending
	if([textViewString characterAtIndex:NSMaxRange(firstLineRange)-1] == '\r')
		newString = [@"\t" stringByAppendingString:
			[[textViewString substringWithRange:blockRange] 
				stringByReplacingOccurrencesOfString:@"\r" withString:@"\r\t"]];
	else
		newString = [@"\t" stringByAppendingString:
			[[textViewString substringWithRange:blockRange] 
				stringByReplacingOccurrencesOfString:@"\n" withString:@"\n\t"]];

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
- (BOOL)shiftSelectionLeft
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

		// Register the undent for undo
		[self shouldChangeTextInRange:NSMakeRange(currentLineRange.location, 1) replacementString:@""];

		// Remove the tab
		[self replaceCharactersInRange:NSMakeRange(currentLineRange.location, 1) withString:@""];

		return YES;
	}

	// Otherwise, something is selected
	NSRange firstLineRange = [textViewString lineRangeForRange:NSMakeRange([self selectedRange].location,0)];
	NSUInteger lastLineMaxRange = NSMaxRange([textViewString lineRangeForRange:NSMakeRange(NSMaxRange([self selectedRange])-1,0)]);
	
	// Expand selection for first and last line to begin and end resp. but the last line ending
	NSRange blockRange = NSMakeRange(firstLineRange.location, lastLineMaxRange - firstLineRange.location);
	if([textViewString characterAtIndex:NSMaxRange(blockRange)-1] == '\n' || [textViewString characterAtIndex:NSMaxRange(blockRange)-1] == '\r')
		blockRange.length--;

	// Check if blockRange starts with SPACE or TAB
	// (this also catches the first line of the entire text buffer or
	// if only one line is selected)
	NSInteger leading = 0;
	if([textViewString characterAtIndex:blockRange.location] == ' ' 
		|| [textViewString characterAtIndex:blockRange.location] == '\t')
		leading++;

	// Replace \n[ \t] by \n of all lines in blockRange
	NSString *newString;
	// check for line ending
	if([textViewString characterAtIndex:NSMaxRange(firstLineRange)-1] == '\r')
		newString = [[[textViewString substringWithRange:NSMakeRange(blockRange.location+leading, blockRange.length-leading)] 
			stringByReplacingOccurrencesOfString:@"\r\t" withString:@"\r"] 
			stringByReplacingOccurrencesOfString:@"\r " withString:@"\r"];
	else
		newString = [[[textViewString substringWithRange:NSMakeRange(blockRange.location+leading, blockRange.length-leading)] 
			stringByReplacingOccurrencesOfString:@"\n\t" withString:@"\n"] 
			stringByReplacingOccurrencesOfString:@"\n " withString:@"\n"];

	// Register the unindent for undo
	[self shouldChangeTextInRange:blockRange replacementString:newString];

	[self replaceCharactersInRange:blockRange withString:newString];

	[self setSelectedRange:NSMakeRange(blockRange.location, [newString length])];

	if(blockRange.length == [newString length])
		return NO;
	else
		return YES;
}

/*
 * Add or remove "-- " for each line in the current query or selection,
 * if the selection is in-line wrap selection into ⁄* block comments and
 * place the caret after ⁄* to allow to enter !xxxxxx e.g.
 */
- (void)commentOut
{

	NSRange oldRange = [self selectedRange];
	NSString *commentString = @"#";
	
	if([[self string] hasPrefix:@"#!"] && [[self string] length] > 4) {
		NSRange firstLineRange = NSMakeRange(2, [[self string] rangeOfString:@"\n"].location - 2);
		NSString *firstLine = [[self string] substringWithRange:firstLineRange];
		if([firstLine isMatchedByRegex:@"osascript"]) {
			commentString = @"--";
		}
	}

	// get the current line range
	NSRange lineRange = [[self string] lineRangeForRange:oldRange];
	NSMutableString *n = [NSMutableString string];

	// Put "-- " in front of the current line
	[n setString:[NSString stringWithFormat:@"%@ %@", commentString, [[self string] substringWithRange:lineRange]]];

	// Check if current line is already commented out, if so uncomment it
	// and preserve the original indention via regex:@"^-- (\\s*)"
	if([n isMatchedByRegex:[NSString stringWithFormat:@"^%@ \\s*(%@\\s|#)", commentString, commentString]]) {
		[n replaceOccurrencesOfRegex:[NSString stringWithFormat:@"^%@ \\s*(%@\\s|#)", commentString, commentString]
			withString:[n substringWithRange:[n rangeOfRegex:[NSString stringWithFormat:@"^%@ (\\s*)", commentString]
												options:RKLNoOptions
												inRange:NSMakeRange(0,[n length])
												capture:1
												error: nil]]];
	} else if ([n isMatchedByRegex:[NSString stringWithFormat:@"^%@ \\s*/\\*.*? ?\\*/\\s*$", commentString]]) {
		[n replaceOccurrencesOfRegex:[NSString stringWithFormat:@"^%@ \\s*/\\* ?", commentString]
			withString:[n substringWithRange:[n rangeOfRegex:[NSString stringWithFormat:@"^%@ (\\s*)", commentString]
												options:RKLNoOptions
												inRange:NSMakeRange(0,[n length])
												capture:1
												error: nil]]];
		[n replaceOccurrencesOfRegex:@" ?\\*/\\s*$"
			withString:[n substringWithRange:[n rangeOfRegex:@" ?\\*/(\\s*)$"
												options:RKLNoOptions
												inRange:NSMakeRange(0,[n length])
												capture:1
												error: nil]]];
	}

	// Replace current line by (un)commented string
	// The caret will be placed at the beginning of the next line if present to
	// allow a fast (un)commenting of lines
	[self setSelectedRange:lineRange];
	[self insertText:n];

	// Try to create an undo group
	if ([[self delegate] respondsToSelector:@selector(setWasCutPaste)]) {
		[(SPBundleEditorController *)[self delegate] setWasCutPaste];
	}
}

- (IBAction)undo:(id)sender
{
	textWasChanged = NO;
	
	[[self undoManager] undo];
	
	// Due to the undoManager implementation it could happen that
	// an action will be recoreded which actually didn't change the
	// text buffer. That's why repeat undo.
	if (!textWasChanged) [[self undoManager] undo];
	if (!textWasChanged) [[self undoManager] undo];
}

- (IBAction)redo:(id)sender
{
	textWasChanged = NO;
	
	[[self undoManager] redo];
	
	// Due to the undoManager implementation it could happen that
	// an action will be recoreded which actually didn't change the
	// text buffer. That's why repeat redo.
	if (!textWasChanged) [[self undoManager] redo];
	if (!textWasChanged) [[self undoManager] redo];
}

- (IBAction)paste:(id)sender
{
	// Try to create an undo group
	if ([[self delegate] respondsToSelector:@selector(setWasCutPaste)]){
		[(SPBundleEditorController *)[self delegate] setWasCutPaste];
	}
	
	[super paste:sender];
}

- (IBAction)cut:(id)sender
{
	// Try to create an undo group
	if ([[self delegate] respondsToSelector:@selector(setWasCutPaste)]) {
		[(SPBundleEditorController *)[self delegate] setWasCutPaste];
	}

	[super cut:sender];
}

- (void)setTabStops
{
	NSFont *tvFont = [self font];
	NSInteger i;
	NSTextTab *aTab;
	NSMutableArray *myArrayOfTabs;
	NSMutableParagraphStyle *paragraphStyle;

	if(tvFont == nil && [prefs dataForKey:@"BundleEditorFont"]) {
		tvFont = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:@"BundleEditorFont"]];
	}
	if(tvFont == nil) {
		tvFont = [NSFont fontWithName:SPDefaultMonospacedFontName size:12];
		[self setFont:tvFont];
		[prefs setObject:[NSArchiver archivedDataWithRootObject:tvFont] forKey:@"BundleEditorFont"];
	}

	BOOL oldEditableStatus = [self isEditable];
	[self setEditable:YES];

	NSInteger tabStopWidth = [prefs integerForKey:SPCustomQueryEditorTabStopWidth];
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

/**
 * If the textview has a selection, wrap it with the supplied prefix and suffix strings;
 * return whether or not any wrap was performed.
 */
- (BOOL)wrapSelectionWithPrefix:(unichar)prefix
{

	NSRange currentRange = [self selectedRange];

	// Only proceed if a selection is active
	if (currentRange.length == 0 || ![self isEditable])
		return NO;

	NSString *matchingCharacter;
	NSString *prefixStr = nil;

	// Set matchingCharacter due to prefix.
	switch (prefix)
	{
		case '(':
			matchingCharacter = @")";
			break;
		case '"':
			matchingCharacter = @"\"";
			break;
		case '`':
			matchingCharacter = @"`";
			break;
		case '\'':
			matchingCharacter = @"'";
			break;
		case '{':
			matchingCharacter = @"}";
			break;
		case '[':
			matchingCharacter = @"]";
			break;
		case 0x201c:
			prefixStr = @"“";
			matchingCharacter = @"”";
			break;
		case 0x2018:
			prefixStr = @"‘";
			matchingCharacter = @"’";
			break;
		default:
		return NO;
	}

	NSString *selString = [[self string] substringWithRange:currentRange];
	NSString *replaceString;
	if(prefixStr != nil)
		replaceString = [NSString stringWithFormat:@"%@%@%@", prefixStr, selString, matchingCharacter];
	else
		replaceString = [NSString stringWithFormat:@"%c%@%@", prefix, selString, matchingCharacter];

	[self breakUndoCoalescing];

	// Replace the current selection with the selected string wrapped in prefix and suffix
	[self insertText:replaceString];

	// Re-select original selection
	NSRange innerSelectionRange = NSMakeRange(currentRange.location+1, [selString length]);
	[self setSelectedRange:innerSelectionRange];

	return YES;
}

- (void)keyDown:(NSEvent *)theEvent
{

	NSEventModifierFlags allFlags = (NSEventModifierFlagShift|NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagCommand);
	
	NSString *characters = [theEvent characters];
	NSString *charactersIgnMod = [theEvent charactersIgnoringModifiers];
	if(![characters length]) {
		[super keyDown: theEvent];
		return;
	}
	unichar insertedCharacter = [characters characterAtIndex:0];
	NSEventModifierFlags curFlags = ([theEvent modifierFlags] & allFlags);

	if(curFlags & NSEventModifierFlagCommand) {
		if([charactersIgnMod isEqualToString:@"+"] || [charactersIgnMod isEqualToString:@"="]) // increase text size by 1; ⌘+ and numpad +
		{
			[self makeTextSizeLarger];
			[self saveChangedFontInUserDefaults];
			return;
		}
		if([charactersIgnMod isEqualToString:@"-"]) // decrease text size by 1; ⌘- and numpad -
		{
			[self makeTextSizeSmaller];
			[self saveChangedFontInUserDefaults];
			return;
		}
		if([charactersIgnMod isEqualToString:@"0"]) // return text to standard size; ⌘0
		{
			[self makeTextStandardSize];
			[self saveChangedFontInUserDefaults];
			return;
		}
		if([charactersIgnMod isEqualToString:@"["]) // shift left
		{
			[self shiftSelectionLeft];
			return;
		}
		if([charactersIgnMod isEqualToString:@"]"]) // shift right
		{
			[self shiftSelectionRight];
			return;
		}
		if([charactersIgnMod isEqualToString:@"/"]) // comment out text
		{
			[self commentOut];
			return;
		}
	}

	// Allow undo grouping if user typed a ' ' (for word level undo)
	// or a RETURN but not for each char due to writing speed
	if ([charactersIgnMod isEqualToString:@" "] ||
	    [theEvent keyCode] == 36 || 
	    [theEvent modifierFlags] & (NSEventModifierFlagCommand|NSEventModifierFlagControl|NSEventModifierFlagOption))
	{
		[(SPBundleEditorController *)[self delegate] setDoGroupDueToChars];
	}

	// Check to see whether several characters are selected, and if so, wrap them with
	// the auto-paired characters.  This returns false if the selection has zero length.
	if ([self wrapSelectionWithPrefix:insertedCharacter]) return;

	[super keyDown: theEvent];
}

/**
 * Handle special commands - see NSResponder.h for a sample list.
 * This subclass currently handles insertNewline: in order to preserve indentation
 * when adding newlines.
 */
- (void) doCommandBySelector:(SEL)aSelector
{

	// Handle newlines, adding any indentation found on the current line to the new line - ignoring the enter key if appropriate
    if (aSelector == @selector(insertNewline:) || [[NSApp currentEvent] keyCode] == 0x4C)
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

		// Try to create an undo group
		if ([[self delegate] respondsToSelector:@selector(setWasCutPaste)]) {
			[(SPBundleEditorController *)[self delegate] setWasCutPaste];
		}

		// Return to avoid the original implementation, preventing double linebreaks
		return;
	}
	[super doCommandBySelector:aSelector];
}

#pragma mark -

/*
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

		// Set the new insertion point
		NSPoint draggingLocation = [sender draggingLocation];
		draggingLocation = [self convertPoint:draggingLocation fromView:nil];
		NSUInteger characterIndex = [self characterIndexOfPoint:draggingLocation];
		[self setSelectedRange:NSMakeRange(characterIndex,0)];

		// Check if user pressed  ⌘ while dragging for inserting only the file path
		if ([sender draggingSourceOperationMask] == 4) {
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
					[alert setMessageText:NSLocalizedString(@"Warning", @"warning")];
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

	return [super performDragOperation:sender];
}

/*
 * Confirmation sheetDidEnd method
 */
- (void)dragAlertSheetDidEnd:(NSAlert *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{

	[[sheet window] orderOut:nil];
	if ( returnCode == NSAlertFirstButtonReturn )
		[self insertFileContentOfFile:[sheet helpAnchor]];

}

#pragma mark -

/*
 * Convert a NSPoint, usually the mouse location, to
 * a character index of the text view.
 */
- (NSUInteger)characterIndexOfPoint:(NSPoint)aPoint
{
	NSUInteger glyphIndex;
	NSLayoutManager *layoutManager = [self layoutManager];
	CGFloat partialFraction;
	NSRange range;

	range = [layoutManager glyphRangeForTextContainer:[self textContainer]];
	glyphIndex = [layoutManager glyphIndexForPoint:aPoint
		inTextContainer:[self textContainer]
		fractionOfDistanceThroughGlyph:&partialFraction];
	if( partialFraction > 0.5 ) glyphIndex++;

	if( glyphIndex == NSMaxRange(range) )
		return  [[self textStorage] length];
	else
		return [layoutManager characterIndexForGlyphAtIndex:glyphIndex];

}

/*
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
			return;
		}
		// If UNIX "file" failed try cocoa's encoding detection
		content = [NSString stringWithContentsOfFile:aPath encoding:enc error:&err];
		if(content)
		{
			[self insertText:content];
			[result release];
			return;
		}
	}
	
	[result release];

	NSLog(@"%@ ‘%@’.", NSLocalizedString(@"Couldn't read the file content of", @"Couldn't read the file content of"), aPath);
}

#pragma mark -

/**
 * Validate undo and redo menu items
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	
	if ([menuItem action] == @selector(undo:)) {
		return ([[self undoManager] canUndo]);
	}
	if ([menuItem action] == @selector(redo:)) {
		return ([[self undoManager] canRedo]);
	}
	return YES;
}

#pragma mark -

- (void)textDidChange:(NSNotification *)aNotification
{
	textWasChanged = YES;
}

/**
 * Scrollview delegate after the command textView's view port was changed.
 * Manily used to render line numbering.
 */
- (void)boundsDidChangeNotification:(NSNotification *)notification
{
	[commandScrollView display];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if([keyPath isEqualToString:SPCustomQueryEditorTabStopWidth]) {
		[self setTabStops];
	}
}

#pragma mark -

// Store the font in the prefs for selected delegates only
- (void)saveChangedFontInUserDefaults
{
	if([[[[self delegate] class] description] isEqualToString:@"SPBundleEditorController"])
		[prefs setObject:[NSArchiver archivedDataWithRootObject:[self font]] forKey:@"BundleEditorFont"];
}

// Action receiver for a font change in the font panel
- (void)changeFont:(id)sender
{
	if (prefs && [self font] != nil) {
		NSFont *nf = [[NSFontPanel sharedFontPanel] panelConvertFont:[self font]];
		[self setFont:nf];
		[self saveChangedFontInUserDefaults];
	}
}

@end
