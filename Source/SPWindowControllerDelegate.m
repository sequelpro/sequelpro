//
//  SPWindowControllerDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on April 9, 2012.
//  Copyright (c) 2012 Stuart Connolly. All rights reserved.
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

#import "SPWindowControllerDelegate.h"
#import "PSMTabDragAssistant.h"
#import "SPDatabaseDocument.h"
#import "SPDatabaseViewController.h"
#import "SPAppController.h"

#import <PSMTabBar/PSMTabBarControl.h>
#import <PSMTabBar/PSMTabStyle.h>

@interface SPWindowController (SPDeclaredAPI)

- (void)_updateProgressIndicatorForItem:(NSTabViewItem *)theItem;
- (void)_switchOutSelectedTableDocument:(SPDatabaseDocument *)newDoc;

@end

@implementation SPWindowController (SPWindowControllerDelegate)

#pragma mark -
#pragma mark Window delegate methods

/**
 * Determine whether the window is permitted to close.
 * Go through the tabs in this window, and ask the database connection view
 * in each one if it can be closed, returning YES only if all can be closed.
 */
- (BOOL)windowShouldClose:(id)sender
{
	for (NSTabViewItem *eachItem in [tabView tabViewItems])
	{
		SPDatabaseDocument *eachDocument = [eachItem identifier];
		
		if (![eachDocument parentTabShouldClose]) return NO;
	}
	
	// Remove global session data if the last window of a session will be closed
	if ([SPAppDelegate sessionURL] && [[SPAppDelegate orderedDatabaseConnectionWindows] count] == 1) {
		[SPAppDelegate setSessionURL:nil];
		[SPAppDelegate setSpfSessionDocData:nil];
	}
	
	return YES;
}

/**
 * When the window does close, close all tabs.
 */
- (void)windowWillClose:(NSNotification *)notification
{
	for (NSTabViewItem *eachItem in [tabView tabViewItems]) 
	{
		[tabView removeTabViewItem:eachItem];
	}
	
	[self autorelease];
}

/**
 * When the window becomes key, inform the selected tab and
 * update menu items.
 */
- (void)windowDidBecomeKey:(NSNotification *)notification
{
	[selectedTableDocument tabDidBecomeKey];
	
	// Update the "Close window" item
	[closeWindowMenuItem setTitle:NSLocalizedString(@"Close Window", @"Close Window menu item")];
	[closeWindowMenuItem setKeyEquivalentModifierMask:(NSCommandKeyMask | NSShiftKeyMask)];
	
	// Ensure the "Close tab" item is enabled and has the standard shortcut
	[closeTabMenuItem setEnabled:YES];
	[closeTabMenuItem setKeyEquivalent:@"w"];
	[closeTabMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask];
}

/**
 * When the window resigns key, update menu items.
 */
- (void)windowDidResignKey:(NSNotification *)notification
{

	// Disable the "Close tab" menu item
	[closeTabMenuItem setEnabled:NO];
	[closeTabMenuItem setKeyEquivalent:@""];
	
	// Update the "Close window" item to show only "Close"
	[closeWindowMenuItem setTitle:NSLocalizedString(@"Close", @"Close menu item")];
	[closeWindowMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask];
}

/**
 * Observe changes in main window status to update drawing state to match
 */
- (void)windowDidBecomeMain:(NSNotification *)notification
{
	
}
- (void)windowDidResignMain:(NSNotification *)notification
{
}

/**
 * If the window is resized, notify all the tabs.
 */
- (void)windowDidResize:(NSNotification *)notification
{
	for (NSTabViewItem *eachItem in [tabView tabViewItems]) 
	{
		SPDatabaseDocument *eachDocument = [eachItem identifier];
		
		[eachDocument tabDidResize];
	}
}

/**
 * If the window is entering fullscreen, update the front tab's titlebar status view visibility.
 */
- (void)windowWillEnterFullScreen:(NSNotification *)notification
{
	[selectedTableDocument updateTitlebarStatusVisibilityForcingHide:YES];
}

/**
 * If the window exits fullscreen, update the front tab's titlebar status view visibility.
 */
- (void)windowDidExitFullScreen:(NSNotification *)notification
{
	[selectedTableDocument updateTitlebarStatusVisibilityForcingHide:NO];
}

#pragma mark -
#pragma mark Tab view delegate methods

/**
 * Called when a tab item is about to be selected.
 */
- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	[selectedTableDocument willResignActiveTabInWindow];
}

/**
 * Called when a tab item was selected.
 */
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if ([[PSMTabDragAssistant sharedDragAssistant] isDragging]) return;
	
	[self _switchOutSelectedTableDocument:[tabViewItem identifier]];
	[selectedTableDocument didBecomeActiveTabInWindow];

	if ([[self window] isKeyWindow]) [selectedTableDocument tabDidBecomeKey];

	[self updateAllTabTitles:self];
}

/**
 * Called to determine whether a tab view item can be closed
 *
 * Note: This is ONLY called when using the "X" button on the tab itself.
 */
- (BOOL)tabView:(NSTabView *)aTabView shouldCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
	SPDatabaseDocument *theDocument = [tabViewItem identifier];
	
	if (![theDocument parentTabShouldClose]) return NO;
	
	return YES;
}

/**
 * Called after a tab view item is closed.
 */
- (void)tabView:(NSTabView *)aTabView didCloseTabViewItem:(NSTabViewItem *)tabViewItem
{
	SPDatabaseDocument *theDocument = [tabViewItem identifier];
	
	[theDocument removeObserver:self forKeyPath:@"isProcessing"];
	[theDocument parentTabDidClose];
}

/**
 * Called to allow dragging of tab view items
 */
- (BOOL)tabView:(NSTabView *)aTabView shouldDragTabViewItem:(NSTabViewItem *)tabViewItem fromTabBar:(PSMTabBarControl *)tabBarControl
{
	return YES;
}

/**
 * Called when a tab finishes a drop.  This is called with the new tabView.
 */
- (void)tabView:(NSTabView*)aTabView didDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(PSMTabBarControl *)tabBarControl
{
	SPDatabaseDocument *draggedDocument = [tabViewItem identifier];
	
	// Grab a reference to the old window
	NSWindow *draggedFromWindow = [draggedDocument parentWindow];
	
	// If the window changed, perform additional processing.
	if (draggedFromWindow != [tabBarControl window]) {
		
		// Update the old window, ensuring the toolbar is cleared to prevent issues with toolbars in multiple windows
		[draggedFromWindow setToolbar:nil];
		[[draggedFromWindow windowController] updateSelectedTableDocument];
		
		// Update the item's document's window and controller
		[draggedDocument willResignActiveTabInWindow];
		[draggedDocument setParentWindowController:[[tabBarControl window] windowController]];
		[draggedDocument setParentWindow:[tabBarControl window]];
		[draggedDocument didBecomeActiveTabInWindow];
		
		// Update window controller's active tab, and update the document's isProcessing observation
		[[[tabBarControl window] windowController] updateSelectedTableDocument];
		[draggedDocument removeObserver:[draggedFromWindow windowController] forKeyPath:@"isProcessing"];
		[[[tabBarControl window] windowController] _updateProgressIndicatorForItem:tabViewItem];
	}
	
	// Check the window and move it to front if it's key (eg for new window creation)
	if ([[tabBarControl window] isKeyWindow]) [[tabBarControl window] orderFront:self];
}

/**
 * Respond to dragging events entering the tab in the tab bar.
 * Allows custom behaviours - for example, if dragging text, switch to the custom
 * query view.
 */
- (void)draggingEvent:(id <NSDraggingInfo>)dragEvent enteredTabBar:(PSMTabBarControl *)tabBarControl tabView:(NSTabViewItem *)tabViewItem
{
	SPDatabaseDocument *theDocument = [tabViewItem identifier];
	
	if (![theDocument isCustomQuerySelected] && [[[dragEvent draggingPasteboard] types] indexOfObject:NSStringPboardType] != NSNotFound)
	{
		[theDocument viewQuery:self];
	}
}

/**
 * Show tooltip for a tab view item.
 */
- (NSString *)tabView:(NSTabView *)aTabView toolTipForTabViewItem:(NSTabViewItem *)tabViewItem
{
	NSInteger tabIndex = [tabView indexOfTabViewItem:tabViewItem];
	
	if ([[tabBar cells] count] < (NSUInteger)tabIndex) return @"";
	
	PSMTabBarCell *theCell = [[tabBar cells] objectAtIndex:tabIndex];
	
	// If cell is selected show tooltip if truncated only
	if ([theCell tabState] & PSMTab_SelectedMask) {
		
		CGFloat cellWidth = [theCell width];
		CGFloat titleWidth = [theCell stringSize].width;
		CGFloat closeButtonWidth = 0;
		
		if ([theCell hasCloseButton])
			closeButtonWidth = [theCell closeButtonRectForFrame:[theCell frame]].size.width;
		
		if (titleWidth > cellWidth - closeButtonWidth) {
			return [theCell title];
		}
		
		return @"";
	} 
	// if cell is not selected show full title plus MySQL version is enabled as tooltip
	else {
		if ([[tabViewItem identifier] respondsToSelector:@selector(tabTitleForTooltip)]) {
			return [[tabViewItem identifier] tabTitleForTooltip];
		}
		
		return @"";
	}
}

/**
 * Allow window closing of the last tab item.
 */
- (void)tabView:(NSTabView *)aTabView closeWindowForLastTabViewItem:(NSTabViewItem *)tabViewItem
{
	[[aTabView window] close];
}

/**
 * When dragging a tab off a tab bar, add a shadow to the drag window.
 */
- (void)tabViewDragWindowCreated:(NSWindow *)dragWindow
{
	[dragWindow setHasShadow:YES];
}

/**
 * Allow dragging and dropping of tabs to any position, including out of a tab bar
 * to create a new window.
 */
- (BOOL)tabView:(NSTabView*)aTabView shouldDropTabViewItem:(NSTabViewItem *)tabViewItem inTabBar:(PSMTabBarControl *)tabBarControl
{
	return YES;
}

/**
 * When a tab is dragged off a tab bar, create a new window containing a new
 * (empty) tab bar to hold it.
 */
- (PSMTabBarControl *)tabView:(NSTabView *)aTabView newTabBarForDraggedTabViewItem:(NSTabViewItem *)tabViewItem atPoint:(NSPoint)point
{
	// Create the new window controller, with no tabs
	SPWindowController *newWindowController = [[SPWindowController alloc] initWithWindowNibName:@"MainWindow"];
	NSWindow *newWindow = [newWindowController window];
	
	CGFloat toolbarHeight = 0;
	
	if ([[[self window] toolbar] isVisible]) {
		NSRect innerFrame = [NSWindow contentRectForFrameRect:[[self window] frame] styleMask:[[self window] styleMask]];
		toolbarHeight = innerFrame.size.height - [[[self window] contentView] frame].size.height;
	}
	
	// Adjust the positioning as appropriate
	point.y += toolbarHeight;
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:SPAlwaysShowWindowTabBar]) point.y += kPSMTabBarControlHeight;
	
	// Set the new window position and size
	NSRect targetWindowFrame = [[self window] frame];
	targetWindowFrame.size.height -= toolbarHeight;
	[newWindow setFrame:targetWindowFrame display:NO];
	[newWindow setFrameTopLeftPoint:point];
	
	// Set the window controller as the window's delegate
	[newWindow setDelegate:newWindowController];
	
	// Set window title
	[newWindow setTitle:[[[tabViewItem identifier] parentWindow] title]];
	
	// Return the window's tab bar
	return [newWindowController valueForKey:@"tabBar"];
}

/**
 * When dragging a tab off the tab bar, return an image so that a
 * drag placeholder can be displayed.
 */
- (NSImage *)tabView:(NSTabView *)aTabView imageForTabViewItem:(NSTabViewItem *)tabViewItem offset:(NSSize *)offset styleMask:(unsigned int *)styleMask
{
	NSImage *viewImage = [[NSImage alloc] init];
	
	// Capture an image of the entire window
	CGImageRef windowImage = CGWindowListCreateImage(CGRectNull, kCGWindowListOptionIncludingWindow, (unsigned int)[[self window] windowNumber], kCGWindowImageBoundsIgnoreFraming);
	NSBitmapImageRep *viewRep = [[NSBitmapImageRep alloc] initWithCGImage:windowImage];
	[viewRep setSize:[[self window] frame].size];
	[viewImage addRepresentation:viewRep];
	[viewRep release];
	
	// Calculate the titlebar+toolbar height
	CGFloat contentViewOffsetY = [[self window] frame].size.height - [[[self window] contentView] frame].size.height;
	offset->height = contentViewOffsetY + [tabBar frame].size.height;
	
	// Draw over the tab bar area
	[viewImage lockFocus];
	[[NSColor windowBackgroundColor] set];
	NSRectFill([tabBar frame]);
	[viewImage unlockFocus];
	
	// Draw the tab bar background in the tab bar area
	[viewImage lockFocus];
	NSRect tabFrame = [tabBar frame];
	[[NSColor windowBackgroundColor] set];
	NSRectFill(tabFrame);
	
	// Draw the background flipped, which is actually the right way up
	NSAffineTransform *transform = [NSAffineTransform transform];
	
	[transform translateXBy:0.0f yBy:[[[self window] contentView] frame].size.height];
	[transform scaleXBy:1.0f yBy:-1.0f];
	
	[transform concat];
	[(id <PSMTabStyle>)[(PSMTabBarControl *)[aTabView delegate] style] drawBackgroundInRect:tabFrame];
	
	[viewImage unlockFocus];
	
	return [viewImage autorelease];
}

/**
 * Displays the current tab's context menu.
 */
- (NSMenu *)tabView:(NSTabView *)aTabView menuForTabViewItem:(NSTabViewItem *)tabViewItem
{
	NSMenu *menu = [[NSMenu alloc] init];
	
	[menu addItemWithTitle:NSLocalizedString(@"Close Tab", @"close tab context menu item") action:@selector(closeTab:) keyEquivalent:@""];
	[menu insertItem:[NSMenuItem separatorItem] atIndex:1];
	[menu addItemWithTitle:NSLocalizedString(@"Open in New Tab", @"open connection in new tab context menu item") action:@selector(openDatabaseInNewTab:) keyEquivalent:@""];
	
	return [menu autorelease];
}

/**
 * When tab drags start, show all the tab bars.  This allows adding tabs to windows
 * containing only one tab - where the bar is normally hidden.
 */
- (void)tabDragStarted:(id)sender
{
	[tabBar setHideForSingleTab:NO];
}

/**
 * When tab drags stop, set tab bars to automatically hide again for only one tab.
 */
- (void)tabDragStopped:(id)sender
{
	if (![[NSUserDefaults standardUserDefaults] boolForKey:SPAlwaysShowWindowTabBar]) {
		[tabBar setHideForSingleTab:YES];
	}
}

@end
