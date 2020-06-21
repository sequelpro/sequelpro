//
//  SPWindow.m
//  sequel-pro
//
//  Created by Rowan Beentje on January 23, 2011.
//  Copyright (c) 2011 Rowan Beentje. All rights reserved.
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

#import "SPWindow.h"
#import "SPWindowController.h"

@implementation SPWindow

@synthesize isSheetWhichCanBecomeMain;

#pragma mark -

+ (void)initialize
{
	// Disable automatic window tabbing on 10.12+
	if ([NSWindow respondsToSelector:@selector(setAllowsAutomaticWindowTabbing:)]) {
		[NSWindow setAllowsAutomaticWindowTabbing:NO];
	}
}

#pragma mark -
#pragma mark Keyboard shortcut additions

/**
 * While keyboard shortcuts are an easy way to apply code app-wide, alternate menu
 * items only collapse if the unmodified key matches; this method allows keyboard
 * shortcuts without menu equivalents for a window, or the use of different base shortcuts.
 */
- (void) sendEvent:(NSEvent *)theEvent
{
	if ([theEvent type] == NSKeyDown && [[theEvent charactersIgnoringModifiers] length]) {

		unichar theCharacter = [[theEvent charactersIgnoringModifiers] characterAtIndex:0];

		// ⌃⎋ sends a right-click to order front the context menu under the first responder's visible Rect
		if ([theEvent keyCode] == 53 && (([theEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask) == (NSEventModifierFlagOption))) {

			id firstResponder = [[NSApp keyWindow] firstResponder];

			if(firstResponder && [firstResponder respondsToSelector:@selector(menuForEvent:)]) {

				NSRect theRect = [firstResponder visibleRect];
				NSPoint loc = theRect.origin;
				loc.y += theRect.size.height+5;
				loc = [firstResponder convertPoint:loc toView:nil];
				NSEvent *anEvent = [NSEvent
				        mouseEventWithType:NSRightMouseDown
				        location:loc
				        modifierFlags:0
				        timestamp:1
				        windowNumber:[self windowNumber]
				        context:[NSGraphicsContext currentContext]
				        eventNumber:0
				        clickCount:1
				        pressure:0.0f];

			    [NSMenu popUpContextMenu:[firstResponder menuForEvent:theEvent] withEvent:anEvent forView:firstResponder];

				return;

			}

		}

		switch (theCharacter) {

			// Alternate keys for switching tabs - ⇧⌘[ and ⇧⌘].  These seem to be standards on some apps,
			// including Apple applications under some circumstances
			case '}':
				if (([theEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask) == (NSEventModifierFlagCommand | NSEventModifierFlagShift))
				{
					if ([[self windowController] respondsToSelector:@selector(selectNextDocumentTab:)])
						[[self windowController] selectNextDocumentTab:self];
					return;
				}
				break;
			case '{':
				if (([theEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask) == (NSEventModifierFlagCommand | NSEventModifierFlagShift))
				{
					if ([[self windowController] respondsToSelector:@selector(selectPreviousDocumentTab:)])
						[[self windowController] selectPreviousDocumentTab:self];
					return;
				}
				break;

			// Also support ⌥⌘← and ⌥⌘→, used in other applications, for maximum compatibility
			case NSRightArrowFunctionKey:
				if (([theEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask) == (NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagNumericPad | NSEventModifierFlagFunction))
				{
					if ([[self windowController] respondsToSelector:@selector(selectNextDocumentTab:)])
						[[self windowController] selectNextDocumentTab:self];
					return;
				}
				break;
			case NSLeftArrowFunctionKey:
				if (([theEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask) == (NSEventModifierFlagCommand | NSEventModifierFlagOption | NSEventModifierFlagNumericPad | NSEventModifierFlagFunction))
				{
					if ([[self windowController] respondsToSelector:@selector(selectPreviousDocumentTab:)])
						[[self windowController] selectPreviousDocumentTab:self];
					return;
				}
				break;
		}
	}

	[super sendEvent:theEvent];
}

#pragma mark -
#pragma mark Undo manager handling

/**
 * If this window is controlled by an SPWindowController, and thus supports being asked
 * for the frontmost SPTableDocument, request the undoController for that table
 * document.  This allows undo to be individual per tab rather than shared across the
 * window.
 */
- (NSUndoManager *)undoManager
{
	if ([[self windowController] respondsToSelector:@selector(selectedTableDocument)]) {
		return [[[self windowController] selectedTableDocument] undoManager];

	}

	return [super undoManager];
}

#pragma mark -
#pragma mark Method overrides

/**
 * Allow sheets to become main if necessary, for example if they are acting as an
 * editor for a window.
 */
- (BOOL)canBecomeMainWindow
{
	// If this window is a sheet which is permitted to become main, respond appropriately
	if ([self isSheet] && isSheetWhichCanBecomeMain) {
		return [self isVisible];
	}

	// Otherwise, if this window has a sheet attached which can become main, return NO.
	if ([[self attachedSheet] isKindOfClass:[SPWindow class]] && [(SPWindow *)[self attachedSheet] isSheetWhichCanBecomeMain]) {
		return NO;
	}

	return [super canBecomeMainWindow];
}

/**
 * Override the standard toolbar show/hide, adding a notification that can be
 * used to update state.
 */
- (void)toggleToolbarShown:(id)sender
{
	[super toggleToolbarShown:sender];

	[[NSNotificationCenter defaultCenter] postNotificationName:SPWindowToolbarDidToggleNotification object:nil];
}

/**
 * On 10.7+, allow the window to go fullscreen; do nothing on <10.7.
 */
- (void)toggleFullScreen:(id)sender
{
	if ([NSWindow instancesRespondToSelector:@selector(toggleFullScreen:)]) {
		[super toggleFullScreen:sender];
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// If the item is the Show/Hide Toolbar menu item, override the text to allow correct translation
	if ([menuItem action] == @selector(toggleToolbarShown:)) {
		BOOL theResponse = [super validateMenuItem:menuItem];
		if ([[self toolbar] isVisible] || [menuItem state] == NSOnState) {
			[menuItem setTitle:NSLocalizedString(@"Hide Toolbar", @"Hide Toolbar menu item")];
		} else {
			[menuItem setTitle:NSLocalizedString(@"Show Toolbar", @"Show Toolbar menu item")];
		}
		return theResponse;
	}

	// On systems which don't support fullscreen windows, disable the fullscreen menu item
	if ([menuItem action] == @selector(toggleFullScreen:)) {
		if (![NSWindow instancesRespondToSelector:@selector(toggleFullScreen:)]) {
			return NO;
		}
	}

	// Allow the superclass to perform validation otherwise (if possible)
	if ([super respondsToSelector:@selector(validateMenuItem:)]) {
		return [super validateMenuItem:menuItem];
	}

	return YES;
}

@end
