//
//  SPQueryConsole.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Jan 30, 2009
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

#import "SPQueryConsole.h"

#define DEFAULT_CONSOLE_LOG_FILENAME @"untitled"
#define DEFAULT_CONSOLE_LOG_FILE_EXTENSION @"log"

#define CONSOLE_WINDOW_AUTO_SAVE_NAME @"QueryConsole"

@interface SPQueryConsole (PrivateAPI)

- (void)_appendMessageToConsole:(NSString *)message withColor:(NSColor *)color;

@end

@implementation SPQueryConsole

// -------------------------------------------------------------------------------
// awakeFromNib
//
// Set the window's auto save name.
// -------------------------------------------------------------------------------
- (void)awakeFromNib
{
	[self setWindowFrameAutosaveName:CONSOLE_WINDOW_AUTO_SAVE_NAME];
}

// -------------------------------------------------------------------------------
// clearConsole:
//
// Clears the console by setting its displayed text to an empty string.
// -------------------------------------------------------------------------------
- (IBAction)clearConsole:(id)sender
{
	[consoleTextView setString:@""];
}

// -------------------------------------------------------------------------------
// saveConsoleAs:
//
// Presents the user with a save panel to the save the current console to a log file.
// -------------------------------------------------------------------------------
- (IBAction)saveConsoleAs:(id)sender
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	
	[panel setRequiredFileType:DEFAULT_CONSOLE_LOG_FILE_EXTENSION];
	
	[panel setExtensionHidden:NO];
	[panel setAllowsOtherFileTypes:YES];
	[panel setCanSelectHiddenExtension:YES];
	
	[panel beginSheetForDirectory:nil 
							 file:DEFAULT_CONSOLE_LOG_FILENAME 
				   modalForWindow:[self window] 
					modalDelegate:self 
				   didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) 
					  contextInfo:NULL];
}

// -------------------------------------------------------------------------------
// showMessageInConsole:
//
// Shows the supplied message in the console.
// -------------------------------------------------------------------------------
- (void)showMessageInConsole:(NSString *)message
{
	[self _appendMessageToConsole:message withColor:[NSColor blackColor]];
}

// -------------------------------------------------------------------------------
// showErrorInConsole:
//
// Shows the supplied error in the console.
// -------------------------------------------------------------------------------
- (void)showErrorInConsole:(NSString *)error
{
	[self _appendMessageToConsole:error	withColor:[NSColor redColor]];
}

// -------------------------------------------------------------------------------
// consoleTextView
//
// Return a reference to the console's text view.
// -------------------------------------------------------------------------------
- (NSTextView *)consoleTextView
{
	return consoleTextView;
}

// -------------------------------------------------------------------------------
// savePanelDidEnd:returnCode:contextInfo:
//
// Called when the NSSavePanel sheet ends.
// -------------------------------------------------------------------------------
- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSOKButton) {
		[[[consoleTextView textStorage] string] writeToFile:[sheet filename] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	}
}

@end

@implementation SPQueryConsole (PrivateAPI)

// -------------------------------------------------------------------------------
// _appendMessageToConsole:withColor:
//
// Appeds the supplied string to the query console, coloring the text using the 
// supplied color.
// -------------------------------------------------------------------------------
- (void)_appendMessageToConsole:(NSString *)message withColor:(NSColor *)color
{
	int begin, end;
	
	// Set the selected range of the text view to be the very last character
	[consoleTextView setSelectedRange:NSMakeRange([[consoleTextView string] length], 0)];
	begin = [[consoleTextView string] length];
	
	// Apped the message to the current text storage using the text view's current typing attributes
	[[consoleTextView textStorage] appendAttributedString:[[NSAttributedString alloc] initWithString:message attributes:[consoleTextView typingAttributes]]];
	end = [[consoleTextView string] length];
	
	// Color the text we just added
	[consoleTextView setTextColor:color range:NSMakeRange(begin, (end - begin))];

	// Scroll to the text we just added
	[consoleTextView scrollRangeToVisible:[consoleTextView selectedRange]];
}

@end
