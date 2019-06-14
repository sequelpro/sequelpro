//
//  SPEditSheetTextView.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on June 15, 2009.
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

#import "SPEditSheetTextView.h"
#import "SPTextViewAdditions.h"
#import "SPFieldEditorController.h"

@implementation SPEditSheetTextView

- (id)init
{
	if((self = [super init]))
	{
	}
	return self;
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
#ifndef SP_CODA
	// Try to create an undo group
	if ([[self delegate] respondsToSelector:@selector(setWasCutPaste)]) {
		[(SPFieldEditorController *)[self delegate] setWasCutPaste];
	}
#endif
	
	[super paste:sender];
}

- (IBAction)cut:(id)sender
{
#ifndef SP_CODA
	// Try to create an undo group
	if ([[self delegate] respondsToSelector:@selector(setWasCutPaste)]) {
		[(SPFieldEditorController *)[self delegate] setWasCutPaste];
	}
#endif
	
	[super cut:sender];
}

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

- (void)textDidChange:(NSNotification *)aNotification
{
	textWasChanged = YES;
}

- (void)keyDown:(NSEvent *)theEvent
{
	NSEventModifierFlags allFlags = (NSEventModifierFlagShift|NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagCommand);
	
	// Check if user pressed ⌥ to allow composing of accented characters.
	// e.g. for US keyboard "⌥u a" to insert ä
	// or for non-US keyboards to allow to enter dead keys
	// e.g. for German keyboard ` is a dead key, press space to enter `
	if (([theEvent modifierFlags] & allFlags) == NSEventModifierFlagOption || [[theEvent characters] length] == 0) {
		[super keyDown: theEvent];
		return;
	}

	NSString *charactersIgnMod = [theEvent charactersIgnoringModifiers];
	NSEventModifierFlags curFlags = ([theEvent modifierFlags] & allFlags);

	if (curFlags & NSEventModifierFlagCommand) {
		if ([charactersIgnMod isEqualToString:@"+"] || [charactersIgnMod isEqualToString:@"="]) // increase text size by 1; ⌘+ and numpad +
		{
			[self makeTextSizeLarger];
			[self saveChangedFontInUserDefaults];
			return;
		}
		
		if ([charactersIgnMod isEqualToString:@"-"]) // decrease text size by 1; ⌘- and numpad -
		{
			[self makeTextSizeSmaller];
			[self saveChangedFontInUserDefaults];
			return;
		}
		
		if ([charactersIgnMod isEqualToString:@"0"]) // return the text size to the default size; ⌘0
		{
			[self makeTextStandardSize];
			[self saveChangedFontInUserDefaults];
			return;
		}
	}

#ifndef SP_CODA
	// Allow undo grouping if user typed a ' ' (for word level undo)
	// or a RETURN but not for each char due to writing speed
	if ([charactersIgnMod isEqualToString:@" "] ||
	    [theEvent keyCode] == 36 ||
	    [theEvent modifierFlags] & (NSEventModifierFlagCommand|NSEventModifierFlagControl|NSEventModifierFlagOption))
	{
		[(SPFieldEditorController *)[self delegate] setDoGroupDueToChars];
	}
#endif
	
	[super keyDown: theEvent];
}

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
/*
 * Convert a NSPoint, usually the mouse location, to
 * a character index of the text view.
 */
- (NSUInteger)characterIndexOfPoint:(NSPoint)aPoint
{
	NSUInteger glyphIndex;
	NSLayoutManager *layoutManager = [self layoutManager];
	CGFloat fraction;
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

// Store the font in the prefs for selected delegates only
- (void)saveChangedFontInUserDefaults
{
	if([[[[self delegate] class] description] isEqualToString:@"SPFieldEditorController"])
		[[NSUserDefaults standardUserDefaults] setObject:[NSArchiver archivedDataWithRootObject:[self font]] forKey:@"FieldEditorSheetFont"];
}

// Action receiver for a font change in the font panel
- (void)changeFont:(id)sender
{
	NSFont *nf = [[NSFontPanel sharedFontPanel] panelConvertFont:[self font]];
	[self setFont:nf];
	[self saveChangedFontInUserDefaults];
}

@end
