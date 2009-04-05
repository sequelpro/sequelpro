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

#import "SPStringAdditions.h"

@implementation NSTextView (SPTextViewAdditions)

/*
 * Returns the range of the current word.
 *   finds: [| := caret]  |word  wo|rd  word|
 * If | is in between whitespaces nothing will be selected.
 */
- (NSRange)getRangeForCurrentWord
{

	NSRange curRange = [self selectedRange];
	unsigned long curLocation = curRange.location;

	[self moveWordLeft:self];
	[self moveWordRightAndModifySelection:self];
	
	unsigned long newStartRange = [self selectedRange].location;
	unsigned long newEndRange = newStartRange + [self selectedRange].length;
	
	// if current location does not intersect with found range
	// then caret is at the begin of a word -> change strategy
	if(curLocation < newStartRange || curLocation > newEndRange)
	{
		[self setSelectedRange:curRange];
		[self moveWordRightAndModifySelection:self];
	}
	
	if([[[self string] substringWithRange:[self selectedRange]] rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location != NSNotFound)
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
	[self doCommandBySelector:@selector(moveToBeginningOfLine:)];
	[self doCommandBySelector:@selector(moveToEndOfLineAndModifySelection:)];
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


@end

