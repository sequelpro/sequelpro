//
//  $Id$
//
//  SPWindowController.m
//  sequel-pro
//
//  Created by Rowan Beentje on May 16, 2010
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

#import "SPWindowController.h"
#import "SPConstants.h"
#import "SPDatabaseDocument.h"
#import <PSMTabBar/PSMTabBarControl.h>
#import <PSMTabBar/PSMTabStyle.h>

@interface SPWindowController (PrivateAPI)

- (void) _updateProgressIndicatorForItem:(NSTabViewItem *)theItem;

@end

@implementation SPWindowController

/**
 * awakeFromNib
 */
- (void) awakeFromNib
{
	selectedTableDocument = nil;

	// Disable automatic cascading - this occurs before the size is set, so let the app
	// controller apply cascading after frame autosaving.
	[self setShouldCascadeWindows:NO];

	// Initialise the managed database connections array
	managedDatabaseConnections = [[NSMutableArray alloc] init];

	// Set up the tab bar
	[tabBar setStyleNamed:@"SequelPro"];
	[tabBar setCanCloseOnlyTab:NO];
	[tabBar setHideForSingleTab:YES];
	[tabBar setShowAddTabButton:YES];
	[tabBar setSizeCellsToFit:NO];
	[tabBar setCellMinWidth:100];
	[tabBar setCellMaxWidth:250];
	[tabBar setCellOptimumWidth:250];
	[tabBar setSelectsTabsOnMouseDown:YES];
	[tabBar setTearOffStyle:PSMTabBarTearOffAlphaWindow];

    // hook up add tab button
    [[tabBar addTabButton] setTarget:self];
    [[tabBar addTabButton] setAction:@selector(addNewConnection:)];

	// Retrieve references to the 'Close Window' and 'Close Tab' menus.  These are updated as window focus changes.
	closeWindowMenuItem = [[[[NSApp mainMenu] itemWithTag:SPMainMenuFile] submenu] itemWithTag:1003];
	closeTabMenuItem = [[[[NSApp mainMenu] itemWithTag:SPMainMenuFile] submenu] itemWithTag:1103];

	// Register for drag start and stop notifications - used to show/hide tab bars
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tabDragStarted:) name:@"SPTabDragStart" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tabDragStopped:) name:@"SPTabDragStop" object:nil];
}

/**
 * Deallocation
 */
- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[managedDatabaseConnections release];

	[super dealloc];
}

#pragma mark -
#pragma mark Database connection management

/**
 * Add a new database connection to the window, in a tab view.
 */
- (IBAction) addNewConnection:(id)sender
{

	// Create a new database connection view
	SPDatabaseDocument *newTableDocument = [[SPDatabaseDocument alloc] init];
	[newTableDocument setParentWindowController:self];
	[newTableDocument setParentWindow:[self window]];

	// Set up a new tab with the connection view as the identifier, add the view, and add it to the tab view
    NSTabViewItem *newItem = [[[NSTabViewItem alloc] initWithIdentifier:newTableDocument] autorelease];
	[newItem setView:[newTableDocument parentView]];
    [tabView addTabViewItem:newItem];
    [tabView selectTabViewItem:newItem];
	[newTableDocument setParentTabViewItem:newItem];

	// Tell the new database connection view to set up the window and update titles
	[newTableDocument didBecomeActiveTabInWindow];
	[newTableDocument updateWindowTitle:self];

	// Bind the tab bar's progress display to the document
	[self _updateProgressIndicatorForItem:newItem];

	[newTableDocument release];
}

/**
 * Retrieve the currently connection view in the window.
 */
- (SPDatabaseDocument *) selectedTableDocument
{
	return selectedTableDocument;
}

/**
 * Update the currently selected connection view
 */
- (void) updateSelectedTableDocument
{
	selectedTableDocument = [[tabView selectedTabViewItem] identifier];
	[selectedTableDocument didBecomeActiveTabInWindow];
}

/**
 * Ask all the connection views to update their titles.
 * As tab titles depend on the currently selected tab, changes
 * within each tab may require other tabs to update their titles.
 * If the sender is a tab, that tab is skipped when updating titles.
 */
- (void) updateAllTabTitles:(id)sender
{
	for (NSTabViewItem *eachItem in [tabView tabViewItems]) {
		SPDatabaseDocument *eachDocument = [eachItem identifier];
		if (eachDocument != sender) [eachDocument updateWindowTitle:self];
	}
}


/**
 * Close the current tab, or if it's the last in the window, the window.
 */
- (IBAction) closeTab:(id)sender
{

	// Return if the selected tab shouldn't be closed
	if (![selectedTableDocument parentTabShouldClose]) return NO;

	// If there are multiple tabs, close the front tab.
	if ([tabView numberOfTabViewItems] > 1) {
		[tabView removeTabViewItem:[tabView selectedTabViewItem]];
	} else {
		[[self window] performClose:self];
	}
}

/**
 * Select next tab; if last select first one.
 */
- (IBAction) selectNextDocumentTab:(id)sender
{
	if([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == [tabView numberOfTabViewItems] - 1)
		[tabView selectFirstTabViewItem:nil];
	else
		[tabView selectNextTabViewItem:nil];
}

/**
 * Select previous tab; if first select last one.
 */
- (IBAction) selectPreviousDocumentTab:(id)sender
{
	if([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 0)
		[tabView selectLastTabViewItem:nil];
	else
		[tabView selectPreviousTabViewItem:nil];
}

/**
 * Move the currently selected tab to a new window.
 */
- (IBAction) moveSelectedTabInNewWindow:(id)sender
{

	static NSPoint cascadeLocation = {.x = 0, .y = 0};

	SPDatabaseDocument *selectedDocument = [[tabView selectedTabViewItem] identifier];
	NSTabViewItem *selectedTabViewItem = [tabView selectedTabViewItem];
	PSMTabBarCell *selectedCell = [[tabBar cells] objectAtIndex:[tabView indexOfTabViewItem:selectedTabViewItem]];

	SPWindowController *newWindowController = [[SPWindowController alloc] initWithWindowNibName:@"MainWindow"];
	NSWindow *newWindow = [newWindowController window];

	CGFloat toolbarHeight = 0;
	if ([[[self window] toolbar] isVisible]) {
		NSRect innerFrame = [NSWindow contentRectForFrameRect:[[self window] frame] styleMask:[[self window] styleMask]];
		toolbarHeight = innerFrame.size.height - [[[self window] contentView] frame].size.height;
	}
	
	// Set the new window position and size
	NSRect targetWindowFrame = [[self window] frame];
	targetWindowFrame.size.height -= toolbarHeight;
	[newWindow setFrame:targetWindowFrame display:NO];

	// Cascade according to the statically stored cascade location.
	cascadeLocation = [newWindow cascadeTopLeftFromPoint:cascadeLocation];

	// Set the window controller as the window's delegate
	[newWindow setDelegate:newWindowController];

	// Set window title
	[newWindow setTitle:[[[[tabView selectedTabViewItem] identifier] parentWindow] title]];

	// New window's tabBar control
	PSMTabBarControl *control = [newWindowController valueForKey:@"tabBar"];

	// Add the selected tab to the new window
	[[control cells] insertObject:selectedCell atIndex:0];

	// Remove 'isProcessing' observer from old windowController
	[selectedDocument removeObserver:self forKeyPath:@"isProcessing"];

	// Update new 'isProcessing' observer and bind the new tab bar's progress display to the document
	[self _updateProgressIndicatorForItem:selectedTabViewItem];

	//remove the tracking rects and bindings registered on the old tab
	[tabBar removeTrackingRect:[selectedCell closeButtonTrackingTag]];
	[tabBar removeTrackingRect:[selectedCell cellTrackingTag]];
	[tabBar removeTabForCell:selectedCell];

	//rebind the selected cell to the new control
	[control bindPropertiesForCell:selectedCell andTabViewItem:selectedTabViewItem];
	
	[selectedCell setControlView:control];
	
	[[tabBar tabView] removeTabViewItem:[selectedCell representedObject]];

	[[control tabView] addTabViewItem:selectedTabViewItem];

	[control update:NO]; //make sure the new tab is set in the correct position

	// Update tabBar of the new window
	[newWindowController tabView:[tabBar tabView] didDropTabViewItem:[selectedCell representedObject] inTabBar:control];

	[newWindow makeKeyAndOrderFront:nil];

}

/**
 * Menu validation
 */
- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{

	// Select Next/Previous/Move Tab
	if (   [menuItem action] == @selector(selectPreviousDocumentTab:) 
		|| [menuItem action] == @selector(selectNextDocumentTab:)
		|| [menuItem action] == @selector(moveSelectedTabInNewWindow:))
	{
		return ([tabView numberOfTabViewItems] != 1);
	}

	// See if the front document blocks validation of this item
	if (![selectedTableDocument validateMenuItem:menuItem]) return NO;

	return YES;
}

/**
 * Retrieve the documents associated with this window.
 */
- (NSArray *)documents
{
	NSMutableArray *documentsArray = [NSMutableArray array];
	for (NSTabViewItem *eachItem in [tabView tabViewItems]) {
		[documentsArray addObject:[eachItem identifier]];
	}
	return documentsArray;
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
	selectedTableDocument = [tabViewItem identifier];
	[selectedTableDocument didBecomeActiveTabInWindow];
	if ([[self window] isKeyWindow]) [selectedTableDocument tabDidBecomeKey];
	[self updateAllTabTitles:self];
}

/**
 * Called to determine whether a tab view item can be closed
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
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SPTabDragStart" object:self];
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
		
		// Update the old window
		[[draggedFromWindow windowController] updateSelectedTableDocument];

		// Update the item's document's window and controller
		[draggedDocument willResignActiveTabInWindow];
		[draggedDocument setParentWindowController:[[tabBarControl window] windowController]];
		[draggedDocument setParentWindow:[tabBarControl window]];
		[draggedDocument didBecomeActiveTabInWindow];

		// Update isProcessing observation
		[draggedDocument removeObserver:[draggedFromWindow windowController] forKeyPath:@"isProcessing"];
		[[[tabBarControl window] windowController] _updateProgressIndicatorForItem:tabViewItem];
	}

	// Check the window and move it to front if it's key (eg for new window creation)
	if ([[tabBarControl window] isKeyWindow]) [[tabBarControl window] orderFront:self];

	[[NSNotificationCenter defaultCenter] postNotificationName:@"SPTabDragStop" object:self];
}

/**
 * Show tooltip for a tab view item.
 */
- (NSString *)tabView:(NSTabView *)aTabView toolTipForTabViewItem:(NSTabViewItem *)tabViewItem
{

	NSInteger tabIndex = [tabView indexOfTabViewItem:tabViewItem];

	if([[tabBar cells] count] < tabIndex) return @"";

	PSMTabBarCell *theCell = [[tabBar cells] objectAtIndex:tabIndex];

	// If cell is selected show tooltip if truncated only
	if([theCell tabState] & PSMTab_SelectedMask) {

		CGFloat cellWidth = [theCell width];
		CGFloat titleWidth = [theCell stringSize].width;
		CGFloat closeButtonWidth = 0;

		if([theCell hasCloseButton])
			closeButtonWidth = [theCell closeButtonRectForFrame:[theCell frame]].size.width;

		if(titleWidth > cellWidth - closeButtonWidth)
			return [theCell title];

		return @"";

	// if cell is not selected show full title plus MySQL version is enabled as tooltip
	} else {
		if([[tabViewItem identifier] respondsToSelector:@selector(tabTitleForTooltip)])
			return [[tabViewItem identifier] tabTitleForTooltip];
		
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

	// Tweak window positioning according to the style and toolbar
	point.x -= [[tabBar style] leftMarginForTabBarControl];
	point.y += 21 + toolbarHeight - kPSMTabBarControlHeight;

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
	[[[self window] contentView] lockFocus];
	NSBitmapImageRep *viewRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:[[[self window] contentView] frame]] autorelease];
	[viewImage addRepresentation:viewRep];
	[[[self window] contentView] unlockFocus];

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
	[transform scaleXBy:1.0 yBy:-1.0];
	[transform concat];
	tabFrame.origin.y = -tabFrame.origin.y - tabFrame.size.height;
	[(id <PSMTabStyle>)[[aTabView delegate] style] drawBackgroundInRect:tabFrame];
	[transform invert];
	[transform concat];
	[viewImage unlockFocus];

	offset->height = 21;
	*styleMask = NSTitledWindowMask | NSUnifiedTitleAndToolbarWindowMask;

	return [viewImage autorelease];
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
	[tabBar setHideForSingleTab:YES];
}

#pragma mark -
#pragma mark Window delegate methods

/**
 * Determine whether the window is permitted to close.
 * Go through the tabs in this window, and ask the database connection view
 * in each one if it can be closed, returning YES only if all can be closed.
 */
- (BOOL)windowShouldClose:(id)sender
{
	for (NSTabViewItem *eachItem in [tabView tabViewItems]) {
		SPDatabaseDocument *eachDocument = [eachItem identifier];
		if (![eachDocument parentTabShouldClose]) return NO;
	}

	return YES;
}

/**
 * When the window does close, close all tabs.
 */
- (void)windowWillClose:(NSNotification *)notification

{
	for (NSTabViewItem *eachItem in [tabView tabViewItems]) {
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
 * If the window is resized, notify all the tabs.
 */
- (void)windowDidResize:(NSNotification *)notification
{
	for (NSTabViewItem *eachItem in [tabView tabViewItems]) {
		SPDatabaseDocument *eachDocument = [eachItem identifier];
		[eachDocument tabDidResize];
	}
}

#pragma mark -
#pragma mark First responder forwarding to active tab

/**
 * Delegate unrecognised methods to the selected table document, thanks to the magic
 * of NSInvocation (see forwardInvocation: docs for background). Must be paired
 * with methodSignationForSelector:.
 */
- (void) forwardInvocation:(NSInvocation *)theInvocation
{
	SEL theSelector = [theInvocation selector];
	if (![selectedTableDocument respondsToSelector:theSelector]) [self doesNotRecognizeSelector:theSelector];
	[theInvocation invokeWithTarget:selectedTableDocument];
}

/**
 * Return the correct method signatures for the selected table document if
 * NSObject doesn't implement the requested methods.
 */
- (NSMethodSignature *) methodSignatureForSelector:(SEL)theSelector
{
	NSMethodSignature *defaultSignature = [super methodSignatureForSelector:theSelector];
	if (defaultSignature) return defaultSignature;

	return [selectedTableDocument methodSignatureForSelector:theSelector];
}

/**
 * Override the default repondsToSelector:, returning true if either NSObject
 * or the selected table document supports the selector.
 */
- (BOOL) respondsToSelector:(SEL)theSelector
{	
	return ([super respondsToSelector:theSelector] || [selectedTableDocument respondsToSelector:theSelector]);
}

/**
 * Override the default performSelector:, again either using NSObject defaults
 * or performing the selector on the selected table document.
 */
- (id) performSelector:(SEL)theSelector
{
	if ([super respondsToSelector:theSelector]) return [super performSelector:theSelector];

	if (![selectedTableDocument respondsToSelector:theSelector]) [self doesNotRecognizeSelector:theSelector];
	return [selectedTableDocument performSelector:theSelector];
}

/**
 * Override the default performSelector:withObject: - see performSelector:
 */
- (id) performSelector:(SEL)theSelector withObject:(id)theObject
{
	if ([super respondsToSelector:theSelector]) return [super performSelector:theSelector withObject:theObject];

	if (![selectedTableDocument respondsToSelector:theSelector]) [self doesNotRecognizeSelector:theSelector];
	return [selectedTableDocument performSelector:theSelector withObject:theObject];
}

@end

@implementation SPWindowController (PrivateAPI)

/**
 * Binds a tab bar item's progress indicator to the represented
 * tableDocument.
 */
- (void) _updateProgressIndicatorForItem:(NSTabViewItem *)theItem
{
	PSMTabBarCell *theCell = [[tabBar cells] objectAtIndex:[tabView indexOfTabViewItem:theItem]];
	[[theCell indicator] setControlSize:NSSmallControlSize];
	SPDatabaseDocument *theDocument = [theItem identifier];

	[[theCell indicator] setHidden:NO];
	NSMutableDictionary *bindingOptions = [NSMutableDictionary dictionary];
	[bindingOptions setObject:NSNegateBooleanTransformerName forKey:@"NSValueTransformerName"];
	[[theCell indicator] bind:@"animate" toObject:theDocument withKeyPath:@"isProcessing" options:nil];
	[[theCell indicator] bind:@"hidden" toObject:theDocument withKeyPath:@"isProcessing" options:bindingOptions];
	[theDocument addObserver:self forKeyPath:@"isProcessing" options:nil context:nil];
}

/**
 * When receiving an update for a bound value - an observed value on the
 * document - ask the tab bar control to redraw as appropriate.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [tabBar update];
}

@end