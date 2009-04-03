//
//  CMTextView.m
//  sequel-pro
//
//  Created by Carsten Blüm.
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
//  Or mail to <lorenz@textor.ch>

#import "CMTextView.h"
#import "SPStringAdditions.h"

/*
 * Include all the extern variables and prototypes required for flex (used for syntax highlighting)
 */
#import "SPEditorTokens.h"
extern int yylex();
extern int yyuoffset, yyuleng;
typedef struct yy_buffer_state *YY_BUFFER_STATE;
void yy_switch_to_buffer(YY_BUFFER_STATE);
YY_BUFFER_STATE yy_scan_string (const char *);

#define kAPlinked   @"Linked" // attribute for a via auto-pair inserted char
#define kAPval      @"linked"
#define kWQquoted   @"Quoted" // set via lex to indicate a quoted string
#define kWQval      @"quoted"
#define kSQLkeyword @"SQLkw"  // attribute for found SQL keywords


@implementation CMTextView

/*
 * Checks if the char after the current caret position/selection matches a supplied attribute
 */
- (BOOL) isNextCharMarkedBy:(id)attribute
{
	unsigned int caretPosition = [self selectedRange].location;

	// Perform bounds checking
	if (caretPosition >= [[self string] length]) return NO;
	
	// Perform the check
	if ([[self textStorage] attribute:attribute atIndex:caretPosition effectiveRange:nil])
		return YES;

	return NO;
}


/*
 * Checks if the caret is wrapped by auto-paired characters.
 * e.g. [| := caret]: "|" 
 */
- (BOOL) areAdjacentCharsLinked
{
	unsigned int caretPosition = [self selectedRange].location;
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
	else
		return NO;

	// Check that the pairing character exists after the caret, and is tagged with the link attribute
	if (matchingChar == [[self string] characterAtIndex:caretPosition]
		&& [[self textStorage] attribute:kAPlinked atIndex:caretPosition effectiveRange:nil]) {
		return YES;
	}

	return NO;
}


/*
 * If the textview has a selection, wrap it with the supplied prefix and suffix strings;
 * return whether or not any wrap was performed.
 */
- (BOOL) wrapSelectionWithPrefix:(NSString *)prefix suffix:(NSString *)suffix
{

	// Only proceed if a selection is active
	if ([self selectedRange].length == 0)
		return NO;

	// Replace the current selection with the selected string wrapped in prefix and suffix
	[self insertText:
		[NSString stringWithFormat:@"%@%@%@", 
			prefix,
			[[self string] substringWithRange:[self selectedRange]],
			suffix
		]
	];
	return YES;
}

/*
 * Select current line and returns found NSRange.
 */
- (NSRange)selectCurrentLine
{
	[self doCommandBySelector:@selector(moveToBeginningOfLine:)];
	[self doCommandBySelector:@selector(moveToEndOfLineAndModifySelection:)];
	
	return([self selectedRange]);
}

/*
 * Select current word and returns found NSRange.
 *   finds: [| := caret]  |word  wo|rd  word|
 * If | is in between whitespaces nothing will be selected.
 */
- (NSRange)selectCurrentWord
{
	NSRange curRange = [self selectedRange];
	unsigned long curLocation = curRange.location;
	[self doCommandBySelector:@selector(moveWordLeft:)];
	[self  doCommandBySelector:@selector(moveWordRightAndModifySelection:)];

	unsigned long newStartRange = [self selectedRange].location;
	unsigned long newEndRange = newStartRange + [self selectedRange].length;

	// if current location does not intersect with found range
	// then caret is at the begin of a word -> change strategy
	if(curLocation < newStartRange || curLocation > newEndRange)
	{
		[self setSelectedRange:curRange];
		[self doCommandBySelector:@selector(moveWordRightAndModifySelection:)];
	}
	
	if([[[self string] substringWithRange:[self selectedRange]] rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location != NSNotFound)
		[self setSelectedRange:curRange];
		
	return([self selectedRange]);
}

/*
 * Copy selected text chunk as RTF to preserve syntax highlighting
 */
- (void)copyAsRTF
{

	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	NSTextStorage *textStorage = [self textStorage];
	NSData *rtf = [textStorage RTFFromRange:[self selectedRange]
		documentAttributes:nil];
	
	if (rtf)
	{
		[pb declareTypes:[NSArray arrayWithObject:NSRTFPboardType] owner:self];
		[pb setData:rtf forType:NSRTFPboardType];
	}

}

/*
 * Change selection or current word to upper case and preserves the selection.
 */
- (void)doSelectionUpperCase
{
	NSRange curRange = [self selectedRange];
	[self insertText:[[[self string] substringWithRange:(curRange.length)?curRange:[self selectCurrentWord]] uppercaseString]];
	[self setSelectedRange:curRange];
}

/*
 * Change selection or current word to lower case and preserves the selection.
 */
- (void)doSelectionLowerCase
{
	NSRange curRange = [self selectedRange];
	[self insertText:[[[self string] substringWithRange:(curRange.length)?curRange:[self selectCurrentWord]] lowercaseString]];
	[self setSelectedRange:curRange];
}

/*
 * Change selection or current word to title case and preserves the selection.
 */
- (void)doSelectionTitleCase
{
	NSRange curRange = [self selectedRange];
	[self insertText:[[[self string] substringWithRange:(curRange.length)?curRange:[self selectCurrentWord]] capitalizedString]];
	[self setSelectedRange:curRange];
}

/*
 * Change selection or current word according to Unicode's NFD and preserves the selection.
 */
- (void)doDecomposedStringWithCanonicalMapping
{
	NSRange curRange = [self selectedRange];
	[self insertText:[[[self string] substringWithRange:(curRange.length)?curRange:[self selectCurrentWord]] decomposedStringWithCanonicalMapping]];
	[self setSelectedRange:curRange];
}

/*
 * Change selection or current word according to Unicode's NFKD and preserves the selection.
 */
- (void)doDecomposedStringWithCompatibilityMapping
{
	NSRange curRange = [self selectedRange];
	[self insertText:[[[self string] substringWithRange:(curRange.length)?curRange:[self selectCurrentWord]] decomposedStringWithCompatibilityMapping]];
	[self setSelectedRange:curRange];
}

/*
 * Change selection or current word according to Unicode's NFC and preserves the selection.
 */
- (void)doPrecomposedStringWithCanonicalMapping
{
	NSRange curRange = [self selectedRange];
	[self insertText:[[[self string] substringWithRange:(curRange.length)?curRange:[self selectCurrentWord]] precomposedStringWithCanonicalMapping]];
	[self setSelectedRange:curRange];
}

/*
 * Change selection or current word according to Unicode's NFKC to title case and preserves the selection.
 */
- (void)doPrecomposedStringWithCompatibilityMapping
{
	NSRange curRange = [self selectedRange];
	[self insertText:[[[self string] substringWithRange:(curRange.length)?curRange:[self selectCurrentWord]] precomposedStringWithCompatibilityMapping]];
	[self setSelectedRange:curRange];
}


/*
 * Handle some keyDown events in order to provide autopairing functionality (if enabled).
 */
- (void) keyDown:(NSEvent *)theEvent
{
	
	long allFlags = (NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask);
	
	// Check if user pressed ⌥ to allow composing of accented characters.
	// e.g. for US keyboard "⌥u a" to insert ä
	if (([theEvent modifierFlags] & allFlags) == NSAlternateKeyMask)
	{
		[super keyDown: theEvent];
		return;
	}

	NSString *characters = [theEvent characters];
	NSString *charactersIgnMod = [theEvent charactersIgnoringModifiers];
	unichar insertedCharacter = [characters characterAtIndex:0];
	long curFlags = ([theEvent modifierFlags] & allFlags);
	

	// Note: switch(insertedCharacter) {} does not work instead use charactersIgnoringModifiers
	if([charactersIgnMod isEqualToString:@"w"]) // ^W select current word
		if(curFlags==(NSControlKeyMask))
		{
			[self selectCurrentWord];
			return;
		}

	if([charactersIgnMod isEqualToString:@"l"]) // ^L select current line
		if(curFlags==(NSControlKeyMask))
		{
			[self selectCurrentLine];
			return;
		}

	if([charactersIgnMod isEqualToString:@"c"]) // ^C copy as RTF
		if(curFlags==(NSControlKeyMask))
		{
			[self copyAsRTF];
			return;
		}

	if([charactersIgnMod isEqualToString:@"u"])
		// ^U upper case
		if(curFlags==(NSControlKeyMask))
			{
				[self doSelectionUpperCase];
				return;
			}
		// ^⌥U title case
		if(curFlags==(NSControlKeyMask|NSAlternateKeyMask))
		{
			[self doSelectionTitleCase];
			return;
		}

	if([charactersIgnMod isEqualToString:@"U"]) // ^⇧U lower case
		if(([theEvent modifierFlags] 
			& (NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask))==(NSControlKeyMask))
		{
			[self doSelectionLowerCase];
			return;
		}


	// Only process for character autopairing if autopairing is enabled and a single character is being added.
	if (autopairEnabled && characters && [characters length] == 1) {

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
			&& [self isNextCharMarkedBy:kAPlinked]

			// And we are inside a quoted string
			&& [self isNextCharMarkedBy:kWQquoted]

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

		// If the caret is inside a text string, without any selection, skip autopairing.
		// There is one exception to this - if the caret is before a linked pair character,
		// processing continues in order to check whether the next character should be jumped
		// over; e.g. [| := caret]: "foo|" and press " => only caret will be moved "foo"|
		if(![self isNextCharMarkedBy:kAPlinked] && [self isNextCharMarkedBy:kWQquoted] && ![self selectedRange].length) {
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
		}

		// Check to see whether the next character should be compared to the typed character;
		// if it matches the typed character, and is marked with the is-linked-pair attribute,
		// select the next character and replace it with the typed character.  This allows
		// a normally quoted string to be typed in full, with the autopair appearing as a hint and
		// then being automatically replaced when the user types it.
		if (skipTypedLinkedCharacter) {
			currentRange = [self selectedRange];
			if (currentRange.location != NSNotFound && currentRange.length == 0) {
				if ([self isNextCharMarkedBy:kAPlinked]) {
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
			}
			return;
		}
	}

	// The default action is to perform the normal key-down action.
	[super keyDown:theEvent];
}


- (void) deleteBackward:(id)sender
{

	// If the caret is currently inside a marked auto-pair, delete the characters on both sides
	// of the caret.
	NSRange currentRange = [self selectedRange];
	if (currentRange.length == 0 && currentRange.location > 0 && [self areAdjacentCharsLinked])
		[self setSelectedRange:NSMakeRange(currentRange.location - 1,2)];

	[super deleteBackward:sender];
}


/*
 * Handle special commands - see NSResponder.h for a sample list.
 * This subclass currently handles insertNewline: in order to preserve indentation
 * when adding newlines.
 */
- (void) doCommandBySelector:(SEL)aSelector
{

	// Handle newlines, adding any indentation found on the current line to the new line - ignoring the enter key if appropriate
    if (aSelector == @selector(insertNewline:)
		&& autoindentEnabled
		&& (!autoindentIgnoresEnter || [[NSApp currentEvent] keyCode] != 0x4C))
	{
		NSString *textViewString = [[self textStorage] string];
		NSString *currentLine, *indentString = nil;
		NSScanner *whitespaceScanner;
		NSRange currentLineRange;

		// Extract the current line based on the text caret or selection start position
		currentLineRange = [textViewString lineRangeForRange:NSMakeRange([self selectedRange].location, 0)];
		currentLine = [[NSString alloc] initWithString:[textViewString substringWithRange:currentLineRange]];

		// Scan all indentation characters on the line into a string
		whitespaceScanner = [[NSScanner alloc] initWithString:currentLine];
		[whitespaceScanner setCharactersToBeSkipped:nil];
		[whitespaceScanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&indentString];
		[whitespaceScanner release];
		[currentLine release];

		// Always add the newline, whether or not we want to indent the next line
		[self insertNewline:self];

		// Replicate the indentation on the previous line if one was found.
		if (indentString) [self insertText:indentString];

		// Return to avoid the original implementation, preventing double linebreaks
		return;
	}
	[super doCommandBySelector:aSelector];
}


/*
 * Shifts the selection, if any, rightwards by indenting any selected lines with one tab.
 * If the caret is within a line, the selection is not changed after the index; if the selection
 * has length, all lines crossed by the length are indented and fully selected.
 * Returns whether or not an indentation was performed.
 */
- (BOOL) shiftSelectionRight
{
	NSString *textViewString = [[self textStorage] string];
	NSRange currentLineRange;
	NSArray *lineRanges;
	NSString *tabString = @"\t";
	int i, indentedLinesLength = 0;

	if ([self selectedRange].location == NSNotFound) return NO;

	// Indent the currently selected line if the caret is within a single line
	if ([self selectedRange].length == 0) {
		NSRange currentLineRange;

		// Extract the current line range based on the text caret
		currentLineRange = [textViewString lineRangeForRange:[self selectedRange]];

		// Register the indent for undo
		[self shouldChangeTextInRange:NSMakeRange(currentLineRange.location, 0) replacementString:tabString];

		// Insert the new tab
		[self replaceCharactersInRange:NSMakeRange(currentLineRange.location, 0) withString:tabString];

		return YES;
	}

	// Otherwise, the selection has a length - get an array of current line ranges for the specified selection
	lineRanges = [textViewString lineRangesForRange:[self selectedRange]];

	// Loop through the ranges, storing a count of the overall length.
	for (i = 0; i < [lineRanges count]; i++) {
		currentLineRange = NSRangeFromString([lineRanges objectAtIndex:i]);
		indentedLinesLength += currentLineRange.length + 1;

		// Register the indent for undo
		[self shouldChangeTextInRange:NSMakeRange(currentLineRange.location+i, 0) replacementString:tabString];

		// Insert the new tab
		[self replaceCharactersInRange:NSMakeRange(currentLineRange.location+i, 0) withString:tabString];
	}

	// Select the entirety of the new range
	[self setSelectedRange:NSMakeRange(NSRangeFromString([lineRanges objectAtIndex:0]).location, indentedLinesLength)];

	return YES;
}


/*
 * Shifts the selection, if any, leftwards by un-indenting any selected lines by one tab if possible.
 * If the caret is within a line, the selection is not changed after the undent; if the selection has
 * length, all lines crossed by the length are un-indented and fully selected.
 * Returns whether or not an indentation was performed.
 */
- (BOOL) shiftSelectionLeft
{
	NSString *textViewString = [[self textStorage] string];
	NSRange currentLineRange;
	NSArray *lineRanges;
	int i, unindentedLines = 0, unindentedLinesLength = 0;

	if ([self selectedRange].location == NSNotFound) return NO;

	// Undent the currently selected line if the caret is within a single line
	if ([self selectedRange].length == 0) {
		NSRange currentLineRange;

		// Extract the current line range based on the text caret
		currentLineRange = [textViewString lineRangeForRange:[self selectedRange]];

		// Ensure that the line has length and that the first character is a tab
		if (currentLineRange.length < 1
			|| [textViewString characterAtIndex:currentLineRange.location] != '\t')
			return NO;

		// Register the undent for undo
		[self shouldChangeTextInRange:NSMakeRange(currentLineRange.location, 1) replacementString:@""];

		// Remove the tab
		[self replaceCharactersInRange:NSMakeRange(currentLineRange.location, 1) withString:@""];

		return YES;
	}

	// Otherwise, the selection has a length - get an array of current line ranges for the specified selection
	lineRanges = [textViewString lineRangesForRange:[self selectedRange]];

	// Loop through the ranges, storing a count of the total lines changed and the new length.
	for (i = 0; i < [lineRanges count]; i++) {
		currentLineRange = NSRangeFromString([lineRanges objectAtIndex:i]);
		unindentedLinesLength += currentLineRange.length;
		
		// Ensure that the line has length and that the first character is a tab
		if (currentLineRange.length < 1
			|| [textViewString characterAtIndex:currentLineRange.location-unindentedLines] != '\t')
			continue;

		// Register the undent for undo
		[self shouldChangeTextInRange:NSMakeRange(currentLineRange.location-unindentedLines, 1) replacementString:@""];

		// Remove the tab
		[self replaceCharactersInRange:NSMakeRange(currentLineRange.location-unindentedLines, 1) withString:@""];
		
		// As a line has been unindented, modify counts and lengths
		unindentedLines++;
		unindentedLinesLength--;
	}

	// If a change was made, select the entirety of the new range and return success
	if (unindentedLines) {
		[self setSelectedRange:NSMakeRange(NSRangeFromString([lineRanges objectAtIndex:0]).location, unindentedLinesLength)];
		return YES;
	}

	return NO;
}

/*
 * Handle autocompletion, returning a list of suggested completions for the supplied character range.
 */
- (NSArray *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(int *)index
{

	NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@" \t\r\n,()\"'`-!"];
	NSArray *textViewWords = [[self string] componentsSeparatedByCharactersInSet:separators];
	NSString *partialString = [[self string] substringWithRange:charRange];
	unsigned int partialLength = [partialString length];
	id tableNames = [[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKey:@"tables"];
	
	//unsigned int options = NSCaseInsensitiveSearch | NSAnchoredSearch;
	//NSRange partialRange = NSMakeRange(0, partialLength);
	
	NSMutableArray *compl = [[NSMutableArray alloc] initWithCapacity:32];
	
	NSMutableArray *possibleCompletions = [NSMutableArray arrayWithArray:textViewWords];
	[possibleCompletions addObjectsFromArray:[self keywords]];
	[possibleCompletions addObjectsFromArray:tableNames];
	
	// Add column names to completions list for currently selected table
	if ([[[self window] delegate] table] != nil) {
		id columnNames = [[[[self window] delegate] valueForKeyPath:@"tableDataInstance"] valueForKey:@"columnNames"];
		[possibleCompletions addObjectsFromArray:columnNames];
	}

	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF beginswith[cd] %@ AND length > %d", partialString, partialLength];
	NSArray *matchingCompletions = [[possibleCompletions filteredArrayUsingPredicate:predicate] sortedArrayUsingSelector:@selector(compare:)];
	unsigned i, insindex;
	
	insindex = 0;
	for (i = 0; i < [matchingCompletions count]; i ++)
	{
		if ([partialString isEqualToString:[[matchingCompletions objectAtIndex:i] substringToIndex:partialLength]])
		{
			// Matches case --> Insert at beginning of completion list
			[compl insertObject:[matchingCompletions objectAtIndex:i] atIndex:insindex++];
		}
		else
		{
			// Not matching case --> Insert at end of completion list
			[compl addObject:[matchingCompletions objectAtIndex:i]];	
		}
	}
	
	return [compl autorelease];
}


/*
 * Hook to invoke the auto-uppercasing of SQL keywords after pasting
 */
- (void)paste:(id)sender
{
	// Insert the content of the pasteboard
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	[self insertText:[pb stringForType:NSStringPboardType]];

	// Invoke the auto-uppercasing of SQL keywords via an additional trigger
	[self insertText:@""];
}


/*
 * List of keywords for autocompletion. If you add a keyword here,
 * it should also be added to the flex file SPEditorTokens.l
 */
-(NSArray *)keywords
{
	return [NSArray arrayWithObjects:
	@"ADD",
	@"ALL",
	@"ALTER TABLE",
	@"ALTER VIEW",
	@"ALTER SCHEMA",
	@"ALTER SCHEMA",
	@"ALTER FUNCTION",
	@"ALTER COLUMN",
	@"ALTER DATABASE",
	@"ALTER PROCEDURE",
	@"ANALYZE",
	@"AND",
	@"ASC",
	@"ASENSITIVE",
	@"BEFORE",
	@"BETWEEN",
	@"BIGINT",
	@"BINARY",
	@"BLOB",
	@"BOTH",
	@"CALL",
	@"CASCADE",
	@"CASE",
	@"CHANGE",
	@"CHAR",
	@"CHARACTER",
	@"CHECK",
	@"COLLATE",
	@"COLUMN",
	@"COLUMNS",
	@"CONDITION",
	@"CONNECTION",
	@"CONSTRAINT",
	@"CONTINUE",
	@"CONVERT",
	@"CREATE VIEW",
	@"CREATE INDEX",
	@"CREATE FUNCTION",
	@"CREATE DATABASE",
	@"CREATE PROCEDURE",
	@"CREATE SCHEMA",
	@"CREATE TRIGGER",
	@"CREATE TABLE",
	@"CREATE USER",
	@"CROSS",
	@"CURRENT_DATE",
	@"CURRENT_TIME",
	@"CURRENT_TIMESTAMP",
	@"CURRENT_USER",
	@"CURSOR",
	@"DATABASE",
	@"DATABASES",
	@"DAY_HOUR",
	@"DAY_MICROSECOND",
	@"DAY_MINUTE",
	@"DAY_SECOND",
	@"DEC",
	@"DECIMAL",
	@"DECLARE",
	@"DEFAULT",
	@"DELAYED",
	@"DELETE",
	@"DESC",
	@"DESCRIBE",
	@"DETERMINISTIC",
	@"DISTINCT",
	@"DISTINCTROW",
	@"DIV",
	@"DOUBLE",
	@"DROP TABLE",
	@"DROP TRIGGER",
	@"DROP VIEW",
	@"DROP SCHEMA",
	@"DROP USER",
	@"DROP PROCEDURE",
	@"DROP FUNCTION",
	@"DROP FOREIGN KEY",
	@"DROP INDEX",
	@"DROP PREPARE",
	@"DROP PRIMARY KEY",
	@"DROP DATABASE",
	@"DUAL",
	@"EACH",
	@"ELSE",
	@"ELSEIF",
	@"ENCLOSED",
	@"ESCAPED",
	@"EXISTS",
	@"EXIT",
	@"EXPLAIN",
	@"FALSE",
	@"FETCH",
	@"FIELDS",
	@"FLOAT",
	@"FOR",
	@"FORCE",
	@"FOREIGN KEY",
	@"FOUND",
	@"FROM",
	@"FULLTEXT",
	@"GOTO",
	@"GRANT",
	@"GROUP",
	@"HAVING",
	@"HIGH_PRIORITY",
	@"HOUR_MICROSECOND",
	@"HOUR_MINUTE",
	@"HOUR_SECOND",
	@"IGNORE",
	@"INDEX",
	@"INFILE",
	@"INNER",
	@"INOUT",
	@"INSENSITIVE",
	@"INSERT",
	@"INT",
	@"INTEGER",
	@"INTERVAL",
	@"INTO",
	@"ITERATE",
	@"JOIN",
	@"KEY",
	@"KEYS",
	@"KILL",
	@"LEADING",
	@"LEAVE",
	@"LEFT",
	@"LIKE",
	@"LIMIT",
	@"LINES",
	@"LOAD",
	@"LOCALTIME",
	@"LOCALTIMESTAMP",
	@"LOCK",
	@"LONG",
	@"LONGBLOB",
	@"LONGTEXT",
	@"LOOP",
	@"LOW_PRIORITY",
	@"MATCH",
	@"MEDIUMBLOB",
	@"MEDIUMINT",
	@"MEDIUMTEXT",
	@"MIDDLEINT",
	@"MINUTE_MICROSECOND",
	@"MINUTE_SECOND",
	@"MOD",
	@"NATURAL",
	@"NOT",
	@"NO_WRITE_TO_BINLOG",
	@"NULL",
	@"NUMERIC",
	@"ON",
	@"OPTIMIZE",
	@"OPTION",
	@"OPTIONALLY",
	@"ORDER",
	@"OUT",
	@"OUTER",
	@"OUTFILE",
	@"PRECISION",
	@"PRIMARY",
	@"PRIVILEGES",
	@"PROCEDURE",
	@"PURGE",
	@"READ",
	@"REAL",
	@"REFERENCES",
	@"REGEXP",
	@"RENAME",
	@"REPEAT",
	@"REPLACE",
	@"REQUIRE",
	@"RESTRICT",
	@"RETURN",
	@"REVOKE",
	@"RIGHT",
	@"RLIKE",
	@"SECOND_MICROSECOND",
	@"SELECT",
	@"SENSITIVE",
	@"SEPARATOR",
	@"SET",
	@"SHOW PROCEDURE STATUS",
	@"SHOW PROCESSLIST",
	@"SHOW SCHEMAS",
	@"SHOW SLAVE HOSTS",
	@"SHOW PRIVILEGES",
	@"SHOW OPEN TABLES",
	@"SHOW MASTER STATUS",
	@"SHOW SLAVE STATUS",
	@"SHOW PLUGIN",
	@"SHOW STORAGE ENGINES",
	@"SHOW VARIABLES",
	@"SHOW WARNINGS",
	@"SHOW TRIGGERS",
	@"SHOW TABLES",
	@"SHOW MASTER LOGS",
	@"SHOW TABLE STATUS",
	@"SHOW TABLE TYPES",
	@"SHOW STATUS",
	@"SHOW INNODB STATUS",
	@"SHOW CREATE DATABASE",
	@"SHOW CREATE FUNCTION",
	@"SHOW CREATE PROCEDURE",
	@"SHOW CREATE SCHEMA",
	@"SHOW COLUMNS",
	@"SHOW COLLATION",
	@"SHOW BINARY LOGS",
	@"SHOW BINLOG EVENTS",
	@"SHOW CHARACTER SET",
	@"SHOW CREATE TABLE",
	@"SHOW CREATE VIEW",
	@"SHOW FUNCTION STATUS",
	@"SHOW GRANTS",
	@"SHOW INDEX",
	@"SHOW FIELDS",
	@"SHOW ERRORS",
	@"SHOW DATABASES",
	@"SHOW ENGINE",
	@"SHOW ENGINES",
	@"SHOW KEYS",
	@"SMALLINT",
	@"SONAME",
	@"SPATIAL",
	@"SPECIFIC",
	@"SQL",
	@"SQLEXCEPTION",
	@"SQLSTATE",
	@"SQLWARNING",
	@"SQL_BIG_RESULT",
	@"SQL_CALC_FOUND_ROWS",
	@"SQL_SMALL_RESULT",
	@"SSL",
	@"STARTING",
	@"STRAIGHT_JOIN",
	@"TABLE",
	@"TABLES",
	@"TERMINATED",
	@"THEN",
	@"TINYBLOB",
	@"TINYINT",
	@"TINYTEXT",
	@"TRAILING",
	@"TRIGGER",
	@"TRUE",
	@"UNDO",
	@"UNION",
	@"UNIQUE",
	@"UNLOCK",
	@"UNSIGNED",
	@"UPDATE",
	@"USAGE",
	@"USE",
	@"USING",
	@"UTC_DATE",
	@"UTC_TIME",
	@"UTC_TIMESTAMP",
	@"VALUES",
	@"VARBINARY",
	@"VARCHAR",
	@"VARCHARACTER",
	@"VARYING",
	@"WHEN",
	@"WHERE",
	@"WHILE",
	@"WITH",
	@"WRITE",
	@"XOR",
	@"YEAR_MONTH",
	@"ZEROFILL",
	nil];
}


/*
 * Set whether this text view should apply the indentation on the current line to new lines.
 */
- (void)setAutoindent:(BOOL)enableAutoindent
{
	autoindentEnabled = enableAutoindent;
}

/*
 * Retrieve whether this text view applies indentation on the current line to new lines.
 */
- (BOOL)autoindent
{
	return autoindentEnabled;
}

/*
 * Set whether this text view should not autoindent when the Enter key is used, as opposed
 * to the return key.  Also catches function-return.
 */
- (void)setAutoindentIgnoresEnter:(BOOL)enableAutoindentIgnoresEnter
{
	autoindentIgnoresEnter = enableAutoindentIgnoresEnter;
}

/*
 * Retrieve whether this text view should not autoindent when the Enter key is used.
 */
- (BOOL)autoindentIgnoresEnter
{
	return autoindentIgnoresEnter;
}

/*
 * Set whether this text view should automatically create the matching closing char for ", ', ` and ( chars.
 */
- (void)setAutopair:(BOOL)enableAutopair
{
	autopairEnabled = enableAutopair;
}

/*
 * Retrieve whether this text view automatically creates the matching closing char for ", ', ` and ( chars.
 */
- (BOOL)autopair
{
	return autopairEnabled;
}

/*
 * Set whether SQL keywords should be automatically uppercased.
 */
- (void)setAutouppercaseKeywords:(BOOL)enableAutouppercaseKeywords
{
	autouppercaseKeywordsEnabled = enableAutouppercaseKeywords;
}

/*
 * Retrieve whether SQL keywords should be automaticallyuppercased.
 */
- (BOOL)autouppercaseKeywords
{
	return autouppercaseKeywordsEnabled;
}


/*******************
SYNTAX HIGHLIGHTING!
*******************/
- (void)awakeFromNib
/*
 * Sets self as delegate for the textView's textStorage to enable syntax highlighting,
 * and set defaults for general usage
 */
{
    [[self textStorage] setDelegate:self];

	autoindentEnabled = YES;
	autopairEnabled = YES;
	autoindentIgnoresEnter = NO;
	autouppercaseKeywordsEnabled = YES;
}

- (void)textStorageDidProcessEditing:(NSNotification *)notification
/*
 *  Performs syntax highlighting.
 *  This method recolors the entire text on every keypress. For performance reasons, this function does
 *  nothing if the text is more than 20 KB.
 *  
 *  The main bottleneck is the [NSTextStorage addAttribute:value:range:] method - the parsing itself is really fast!
 *  
 *  Some sample code from Andrew Choi ( http://members.shaw.ca/akochoi-old/blog/2003/11-09/index.html#3 ) has been reused.
 */
{
	NSTextStorage *textStore = [notification object];

	//make sure that the notification is from the correct textStorage object
	if (textStore!=[self textStorage]) return;


	NSColor *commentColor   = [NSColor colorWithDeviceRed:0.000 green:0.455 blue:0.000 alpha:1.000];
	NSColor *quoteColor     = [NSColor colorWithDeviceRed:0.769 green:0.102 blue:0.086 alpha:1.000];
	NSColor *keywordColor   = [NSColor colorWithDeviceRed:0.200 green:0.250 blue:1.000 alpha:1.000];
	NSColor *backtickColor  = [NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.658 alpha:1.000];

	NSColor *tokenColor;

	int token;
	NSRange textRange, tokenRange;

	textRange = NSMakeRange(0, [textStore length]);

	//don't color texts longer than about 20KB. would be too slow
	if (textRange.length > 20000) return; 

	//first remove the old colors
	[textStore removeAttribute:NSForegroundColorAttributeName range:textRange];


	//initialise flex
	yyuoffset = 0; yyuleng = 0;
	yy_switch_to_buffer(yy_scan_string([[textStore string] UTF8String]));

	//now loop through all the tokens
	while (token=yylex()){
		switch (token) {
			case SPT_SINGLE_QUOTED_TEXT:
			case SPT_DOUBLE_QUOTED_TEXT:
			tokenColor = quoteColor;
			break;
			case SPT_BACKTICK_QUOTED_TEXT:
			tokenColor = backtickColor;
			break;
			case SPT_RESERVED_WORD:
			tokenColor = keywordColor;
			break;
			case SPT_COMMENT:
			tokenColor = commentColor;
			break;
			default:
			tokenColor = nil;
		}

		if (!tokenColor) continue;

		tokenRange = NSMakeRange(yyuoffset, yyuleng);

		// make sure that tokenRange is valid (and therefore within textRange)
		// otherwise a bug in the lex code could cause the the TextView to crash
		tokenRange = NSIntersectionRange(tokenRange, textRange); 
		if (!tokenRange.length) continue;

		// Is the current token is marked as SQL keyword, uppercase it if required.
		if (autouppercaseKeywordsEnabled &&
			[[self textStorage] attribute:kSQLkeyword atIndex:tokenRange.location effectiveRange:nil])
		{
			// Note: Register it for undo doesn't work ?=> unreliable single char undo
			// Replace it
			[self replaceCharactersInRange:tokenRange withString:[[[self string] substringWithRange:tokenRange] uppercaseString]];
		}

		[textStore addAttribute: NSForegroundColorAttributeName
						  value: tokenColor
						  range: tokenRange ];

		// Add an attribute to be used in the auto-pairing (keyDown:)
		// to disable auto-pairing if caret is inside of any token found by lex.
		// For discussion: maybe change it later (only for quotes not keywords?)
		[textStore addAttribute: kWQquoted 
						  value: kWQval 
						  range: tokenRange ];


		// Mark each SQL keyword for auto-uppercasing and do it for the next textStorageDidProcessEditing: event.
		// Performing it one token later allows words which start as reserved keywords to be entered.
		if(token == SPT_RESERVED_WORD)
			[textStore addAttribute: kSQLkeyword
							  value: kWQval
							  range: tokenRange ];
	}

}

@end
