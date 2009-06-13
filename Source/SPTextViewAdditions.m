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

#import "SPStringAdditions.h"
#import "SPTextViewAdditions.h"

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
		[self moveWordRight:self];
		[self moveWordLeftAndModifySelection:self];
		newStartRange = [self selectedRange].location;
		newEndRange = newStartRange + [self selectedRange].length;
	}
	
	// how many space in front of the selection
	int bias = [self selectedRange].length - [[[[self string] substringWithRange:[self selectedRange]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length];
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
	[self doCommandBySelector:@selector(moveToBeginningOfLine:)];
	[self doCommandBySelector:@selector(moveToEndOfLineAndModifySelection:)];
}

/*
 *
 */
- (IBAction)selectEnclosingBrackets:(id)sender
{
	long caretPosition = [self selectedRange].location;
	long stringLength = [[self string] length];
	unichar co, cc;
	
	if(caretPosition == 0 || caretPosition >= stringLength) return;

	long pcnt = 0;
	long bcnt = 0;
	long scnt = 0;

	long i;

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
	
	long start = -1;
	long end = -1;
	long bracketCounter = 0;

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
	if(workingRange.length > 1)
	{
		NSMutableString *reversedStr;
		unsigned long len = workingRange.length;
		reversedStr = [NSMutableString stringWithCapacity:len];
		while (len > 0)
			[reversedStr appendString:
				[NSString stringWithFormat:@"%C", [[self string] characterAtIndex:--len+workingRange.location]]];

		[self insertText:reversedStr];
		[self setSelectedRange:curRange];
	}
}

/*
 * Insert the content of a dragged file path or if ⌘ is pressed
 * while dragging insert the file path
 */
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = [sender draggingPasteboard];

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
		unsigned int characterIndex = [self characterIndexOfPoint:draggingLocation];
		[self setSelectedRange:NSMakeRange(characterIndex,0)];

		// Check if user pressed  ⌘ while dragging for inserting only the file path
		if([sender draggingSourceOperationMask] == 4)
		{
			[self insertText:filepath];
			return YES;
		}

		// Check size and NSFileType
		NSDictionary *attr = [[NSFileManager defaultManager] fileAttributesAtPath:filepath traverseLink:YES];
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
					[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Do you really want to proceed with %.1f MB of data?", @"message of panel asking for confirmation for inserting large text from dragging action"),
						 [filesize unsignedLongValue]/1048576.0]];
					[alert setHelpAnchor:filepath];
					[alert setMessageText:NSLocalizedString(@"Warning",@"Warning")];
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
- (void)dragAlertSheetDidEnd:(NSAlert *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{

	[[sheet window] orderOut:nil];
	if ( returnCode == NSAlertFirstButtonReturn )
		[self insertFileContentOfFile:[sheet helpAnchor]];

}
/*
 * Convert a NSPoint, usually the mouse location, to
 * a character index of the text view.
 */
- (unsigned int)characterIndexOfPoint:(NSPoint)aPoint
{
	unsigned int glyphIndex;
	NSLayoutManager *layoutManager = [self layoutManager];
	float fraction;
	NSRange range;

	range = [layoutManager glyphRangeForTextContainer:[self textContainer]];
	glyphIndex = [layoutManager glyphIndexForPoint:aPoint
		inTextContainer:[self textContainer]
		fractionOfDistanceThroughGlyph:&fraction];
	if( fraction > 0.5 ) glyphIndex++;

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
	NSTask *task=[[NSTask alloc] init];
	NSPipe *pipe=[[NSPipe alloc] init];
	NSFileHandle *handle;
	NSString *result;
	[task setLaunchPath:@"/usr/bin/file"];
	[task setArguments:[NSArray arrayWithObjects:aPath, @"-Ib", nil]];
	[task setStandardOutput:pipe];
	handle=[pipe fileHandleForReading];
	[task launch];
	result=[[NSString alloc] initWithData:[handle readDataToEndOfFile]
		encoding:NSASCIIStringEncoding];

	[pipe release];
	[task release];

	// UTF16/32 files are detected as application/octet-stream resp. audio/mpeg
	if([result hasPrefix:@"application/octet-stream"] || [result hasPrefix:@"audio/mpeg"] || [result hasPrefix:@"text/plain"] || [[[aPath pathExtension] lowercaseString] isEqualToString:@"sql"])
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
			[self insertText:@""]; // Invoke keyword uppercasing
			return;
		}
		// If UNIX "file" failed try cocoa's encoding detection
		content = [NSString stringWithContentsOfFile:aPath encoding:enc error:&err];
		if(content)
		{
			[self insertText:content];
			[result release];
			[self insertText:@""]; // Invoke keyword uppercasing
			return;
		}
	}
	
	[result release];

	NSLog(@"%@ ‘%@’.", NSLocalizedString(@"Couldn't read the file content of", @"Couldn't read the file content of"), aPath);
}

/*
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
	int newSize = ([aFont pointSize]-1 < 4) ? [aFont pointSize] : [aFont pointSize]-1;
	BOOL editableStatus = [self isEditable];
	[self setEditable:YES];
	[self setFont:[[NSFontManager sharedFontManager] convertFont:aFont toSize:newSize]];
	[self setEditable:editableStatus];
}


#pragma mark -
#pragma mark multi-touch trackpad support

/*
 * Trackpad two-finger zooming gesture in/decreases the font size
 */
- (void) magnifyWithEvent:(NSEvent *)anEvent
{

	//Avoid font resizing for NSTextViews in CMCopyTable or NSTableView
	if([[[[self delegate] class] description] isEqualToString:@"CMCopyTable"] 
		|| [[[[self delegate] class] description] isEqualToString:@"NSTableView"]) return;

	if([anEvent deltaZ]>5.0)
		[self makeTextSizeLarger];
	else if([anEvent deltaZ]<-5.0)
		[self makeTextSizeSmaller];

	[self insertText:@""];
}


@end
