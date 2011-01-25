//
//  $Id$
//
//  SPWindow.m
//  sequel-pro
//
//  Created by Rowan Beentje on January 23, 2011
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

#import "SPWindow.h"


@implementation SPWindow

#pragma mark -
#pragma mark Keyboard shortcut additions

/**
 * While keyboard shortcuts are an easy way to apply code app-wide, alternate menu
 * items only collapse if the unmodified key matches; this method allows keyboard
 * shortcuts without menu equivalents for a window, or the use of different base shortcuts.
 */
- (void) sendEvent:(NSEvent *)theEvent
{
	if ([theEvent type] == NSKeyDown && [[theEvent characters] length]) {

		unichar theCharacter = [[theEvent charactersIgnoringModifiers] characterAtIndex:0];

		switch (theCharacter) {

			// Alternate keys for switching tabs - ⇧⌘[ and ⇧⌘].  These seem to be standards on some apps,
			// including Apple applications under some circumstances
			case '}':
				if (([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) == (NSCommandKeyMask | NSShiftKeyMask))
				{
					return [[self windowController] selectNextDocumentTab:self];
				}
				break;
			case '{':
				if (([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) == (NSCommandKeyMask | NSShiftKeyMask))
				{
					return [[self windowController] selectPreviousDocumentTab:self];
				}
				break;

			// Also support ⌥⌘← and ⌥⌘→, used in other applications, for maximum compatibility
			case NSRightArrowFunctionKey:
				if (([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) == (NSCommandKeyMask | NSAlternateKeyMask | NSNumericPadKeyMask | NSFunctionKeyMask))
				{
					return [[self windowController] selectNextDocumentTab:self];
				}
				break;
			case NSLeftArrowFunctionKey:
				if (([theEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) == (NSCommandKeyMask | NSAlternateKeyMask | NSNumericPadKeyMask | NSFunctionKeyMask))
				{
					return [[self windowController] selectPreviousDocumentTab:self];
				}
				break;
		}
	}

	[super sendEvent:theEvent];
}


@end
