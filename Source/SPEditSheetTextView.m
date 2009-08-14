//
//  $Id: SPTextViewAdditions.m 866 2009-06-15 16:05:54Z bibiko $
//
//  SPEditSheetTextView.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on June 15, 2009
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

#import "SPEditSheetTextView.h"
#import "SPTextViewAdditions.h"
#import "SPFieldEditorController.h"

@implementation SPEditSheetTextView

- (IBAction)undo:(id)sender
{
	textWasChanged = NO;
	[[self undoManager] undo];
	// Due to the undoManager implementation it could happen that
	// an action will be recoreded which actually didn't change the
	// text buffer. That's why repeat undo.
	if(!textWasChanged) [[self undoManager] undo];
}

- (IBAction)redo:(id)sender
{
	textWasChanged = NO;
	[[self undoManager] redo];
	// Due to the undoManager implementation it could happen that
	// an action will be recoreded which actually didn't change the
	// text buffer. That's why repeat redo.
	if(!textWasChanged) [[self undoManager] redo];
}

- (IBAction)paste:(id)sender
{
	[[self delegate] setWasCutPaste];
	[super paste:sender];
}

- (IBAction)cut:(id)sender
{
	[[self delegate] setWasCutPaste];
	[super cut:sender];
}

/*
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

	long allFlags = (NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask);
	
	// Check if user pressed ⌥ to allow composing of accented characters.
	// e.g. for US keyboard "⌥u a" to insert ä
	// or for non-US keyboards to allow to enter dead keys
	// e.g. for German keyboard ` is a dead key, press space to enter `
	if (([theEvent modifierFlags] & allFlags) == NSAlternateKeyMask || [[theEvent characters] length] == 0)
	{
		[super keyDown: theEvent];
		return;
	}

	// NSString *characters = [theEvent characters];
	NSString *charactersIgnMod = [theEvent charactersIgnoringModifiers];
	// unichar insertedCharacter = [characters characterAtIndex:0];
	long curFlags = ([theEvent modifierFlags] & allFlags);

	if(curFlags & NSCommandKeyMask) {
		if([charactersIgnMod isEqualToString:@"+"]) // increase text size by 1; ⌘+ and numpad +
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
	}

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
	if( [result hasPrefix:@"text/plain"] 
		|| [[[aPath pathExtension] lowercaseString] isEqualToString:@"sql"] 
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
