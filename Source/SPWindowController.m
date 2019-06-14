//
//  SPWindowController.m
//  sequel-pro
//
//  Created by Rowan Beentje on May 16, 2010.
//  Copyright (c) 2010 Rowan Beentje. All rights reserved.
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

#import "SPWindowController.h"
#import "SPDatabaseDocument.h"
#import "SPAppController.h"
#import "PSMTabDragAssistant.h"
#import "SPConnectionController.h"
#import "SPFavoritesOutlineView.h"

#import <PSMTabBar/PSMTabBarControl.h>
#import <PSMTabBar/PSMTabStyle.h>

@interface SPWindowController ()

- (void)_setUpTabBar;
- (void)_updateProgressIndicatorForItem:(NSTabViewItem *)theItem;
- (void)_switchOutSelectedTableDocument:(SPDatabaseDocument *)newDoc;
- (void)_selectedTableDocumentDeallocd:(NSNotification *)notification;

#pragma mark - SPWindowControllerDelegate

- (void)tabDragStarted:(id)sender;
- (void)tabDragStopped:(id)sender;

@end

@implementation SPWindowController

#pragma mark -
#pragma mark Initialisation

- (void)awakeFromNib
{
	[self _switchOutSelectedTableDocument:nil];
	
	[[self window] setCollectionBehavior:[[self window] collectionBehavior] | NSWindowCollectionBehaviorFullScreenPrimary];

	// Disable automatic cascading - this occurs before the size is set, so let the app
	// controller apply cascading after frame autosaving.
	[self setShouldCascadeWindows:NO];

	// Initialise the managed database connections array
	managedDatabaseConnections = [[NSMutableArray alloc] init];

	[self _setUpTabBar];

	// Retrieve references to the 'Close Window' and 'Close Tab' menus.  These are updated as window focus changes.
	closeWindowMenuItem = [[[[NSApp mainMenu] itemWithTag:SPMainMenuFile] submenu] itemWithTag:SPMainMenuFileClose];
	closeTabMenuItem = [[[[NSApp mainMenu] itemWithTag:SPMainMenuFile] submenu] itemWithTag:SPMainMenuFileCloseTab];

	// Register for drag start and stop notifications - used to show/hide tab bars
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tabDragStarted:) name:PSMTabDragDidBeginNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tabDragStopped:) name:PSMTabDragDidEndNotification object:nil];

	// Because we are a document-based app we automatically adopt window restoration on 10.7+.
	// However that causes a race condition with our own window setup code.
	// Remove this when we actually support restoration.
	if([[self window] respondsToSelector:@selector(setRestorable:)])
		[[self window] setRestorable:NO];
}

#pragma mark -
#pragma mark Database connection management

/**
 * Add a new database connection to the window, in a tab view.
 */
- (IBAction)addNewConnection:(id)sender
{
	[self addNewConnection];
}

- (SPDatabaseDocument *)addNewConnection
{
	// Create a new database connection view
	SPDatabaseDocument *newTableDocument = [[SPDatabaseDocument alloc] init];
	
	[newTableDocument setParentWindowController:self];
	[newTableDocument setParentWindow:[self window]];

	// Set up a new tab with the connection view as the identifier, add the view, and add it to the tab view
    NSTabViewItem *newItem = [[[NSTabViewItem alloc] initWithIdentifier:newTableDocument] autorelease];
	
	[newItem setView:[newTableDocument databaseView]];
    [tabView addTabViewItem:newItem];
    [tabView selectTabViewItem:newItem];
	[newTableDocument setParentTabViewItem:newItem];

	// Tell the new database connection view to set up the window and update titles
	[newTableDocument didBecomeActiveTabInWindow];
	[newTableDocument updateWindowTitle:self];

	// Bind the tab bar's progress display to the document
	[self _updateProgressIndicatorForItem:newItem];
	
	return [newTableDocument autorelease];
}

/**
 * Retrieve the currently connection view in the window.
 */
- (SPDatabaseDocument *)selectedTableDocument
{
	return selectedTableDocument;
}

/**
 * Update the currently selected connection view
 */
- (void)updateSelectedTableDocument
{
	[self _switchOutSelectedTableDocument:[[tabView selectedTabViewItem] identifier]];
	
	[selectedTableDocument didBecomeActiveTabInWindow];
}

/**
 * Ask all the connection views to update their titles.
 * As tab titles depend on the currently selected tab, changes
 * within each tab may require other tabs to update their titles.
 * If the sender is a tab, that tab is skipped when updating titles.
 */
- (void)updateAllTabTitles:(id)sender
{
	for (NSTabViewItem *eachItem in [tabView tabViewItems]) 
	{
		SPDatabaseDocument *eachDocument = [eachItem identifier];
		
		if (eachDocument != sender) {
			[eachDocument updateWindowTitle:self];
		}
	}
}

/**
 * Close the current tab, or if it's the last in the window, the window.
 */
- (IBAction)closeTab:(id)sender
{
	// If there are multiple tabs, close the front tab.
	if ([tabView numberOfTabViewItems] > 1) {
		// Return if the selected tab shouldn't be closed
		if (![selectedTableDocument parentTabShouldClose]) return;
		[tabView removeTabViewItem:[tabView selectedTabViewItem]];
	} 
	else {
		//trying to close the window will itself call parentTabShouldClose for all tabs in windowShouldClose:
		[[self window] performClose:self];
	}
}

/**
 * Select next tab; if last select first one.
 */
- (IBAction) selectNextDocumentTab:(id)sender
{
	if ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == [tabView numberOfTabViewItems] - 1) {
		[tabView selectFirstTabViewItem:nil];
	}
	else {
		[tabView selectNextTabViewItem:nil];
	}
}

/**
 * Select previous tab; if first select last one.
 */
- (IBAction) selectPreviousDocumentTab:(id)sender
{
	if ([tabView indexOfTabViewItem:[tabView selectedTabViewItem]] == 0) {
		[tabView selectLastTabViewItem:nil];
	}
	else {
		[tabView selectPreviousTabViewItem:nil];
	}
}

/**
 * Move the currently selected tab to a new window.
 */
- (IBAction)moveSelectedTabInNewWindow:(id)sender
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
#warning Private ivar accessed from outside (#2978)
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
	
	[selectedCell setCustomControlView:control];
	
	[[tabBar tabView] removeTabViewItem:[selectedCell representedObject]];

	[[control tabView] addTabViewItem:selectedTabViewItem];

	// Make sure the new tab is set in the correct position by forcing an update
	[tabBar update:NO];

	// Update tabBar of the new window
	[newWindowController tabView:[tabBar tabView] didDropTabViewItem:[selectedCell representedObject] inTabBar:control];

	[newWindow makeKeyAndOrderFront:nil];	
}

/**
 * Toggle the tab bar's visibility.
 */
- (IBAction)toggleTabBarShown:(id)sender
{
	[tabBar setHideForSingleTab:![tabBar hideForSingleTab]];
	[[NSUserDefaults standardUserDefaults] setBool:![tabBar hideForSingleTab] forKey:SPAlwaysShowWindowTabBar];
}

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// Select Next/Previous/Move Tab
	if ([menuItem action] == @selector(selectPreviousDocumentTab:) ||
		[menuItem action] == @selector(selectNextDocumentTab:) ||
		[menuItem action] == @selector(moveSelectedTabInNewWindow:))
	{
		return ([tabView numberOfTabViewItems] != 1);
	}

	// Show/hide Tab bar
	if ([menuItem action] == @selector(toggleTabBarShown:)) {
		[menuItem setTitle:(![tabBar isTabBarHidden] ? NSLocalizedString(@"Hide Tab Bar", @"hide tab bar") : NSLocalizedString(@"Show Tab Bar", @"show tab bar"))];
		
		return [[tabBar cells] count] <= 1;
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

/**
 * Select tab at index.
 */
- (void)selectTabAtIndex:(NSInteger)index
{
	if ([[tabBar cells] count] > 0 && [[tabBar cells] count] > (NSUInteger)index) {
		[tabView selectTabViewItemAtIndex:index];
	} 
	else if ([[tabBar cells] count]) {
		[tabView selectTabViewItemAtIndex:0];
	}
}

- (void)setHideForSingleTab:(BOOL)hide
{
	[tabBar setHideForSingleTab:hide];
}

/**
 * Opens the current connection in a new tab, but only if it's already connected.
 */
- (void)openDatabaseInNewTab
{
	if ([selectedTableDocument database]) {
		[selectedTableDocument openDatabaseInNewTab:self];
	}
}

#pragma mark -
#pragma mark Tab Bar
- (void)updateTabBar
{
	BOOL collapse = NO;
 
	if (selectedTableDocument.getConnection) {
		if (selectedTableDocument.connectionController.colorIndex != -1) {
			collapse = YES;
		}
	}
	
	tabBar.heightCollapsed = collapse ? 8 : 1;
	
	[tabBar update];
}

#pragma mark -
#pragma mark First responder forwarding to active tab

/**
 * Delegate unrecognised methods to the selected table document, thanks to the magic
 * of NSInvocation (see forwardInvocation: docs for background). Must be paired
 * with methodSignationForSelector:.
 */
- (void)forwardInvocation:(NSInvocation *)theInvocation
{
	SEL theSelector = [theInvocation selector];
	
	if (![selectedTableDocument respondsToSelector:theSelector]) {
		[self doesNotRecognizeSelector:theSelector];
	}
	
	[theInvocation invokeWithTarget:selectedTableDocument];
}

/**
 * Return the correct method signatures for the selected table document if
 * NSObject doesn't implement the requested methods.
 */
- (NSMethodSignature *)methodSignatureForSelector:(SEL)theSelector
{
	NSMethodSignature *defaultSignature = [super methodSignatureForSelector:theSelector];
	
	return defaultSignature ? defaultSignature : [selectedTableDocument methodSignatureForSelector:theSelector];
}

/**
 * Override the default repondsToSelector:, returning true if either NSObject
 * or the selected table document supports the selector.
 */
- (BOOL)respondsToSelector:(SEL)theSelector
{
	return ([super respondsToSelector:theSelector] || [selectedTableDocument respondsToSelector:theSelector]);
}

/**
 * Override the default performSelector:, again either using NSObject defaults
 * or performing the selector on the selected table document.
 */
- (id)performSelector:(SEL)theSelector
{
	if ([super respondsToSelector:theSelector]) {
		return [super performSelector:theSelector];
	}

	if (![selectedTableDocument respondsToSelector:theSelector]) {
		[self doesNotRecognizeSelector:theSelector];
	}
	
	return [selectedTableDocument performSelector:theSelector];
}

/**
 * Override the default performSelector:withObject: - see performSelector:
 */
- (id)performSelector:(SEL)theSelector withObject:(id)theObject
{
	if ([super respondsToSelector:theSelector]) {
		return [super performSelector:theSelector withObject:theObject];
	}

	if (![selectedTableDocument respondsToSelector:theSelector]) {
		[self doesNotRecognizeSelector:theSelector];
	}
	
	return [selectedTableDocument performSelector:theSelector withObject:theObject];
}

/**
 * When receiving an update for a bound value - an observed value on the
 * document - ask the tab bar control to redraw as appropriate.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [tabBar update];
}

#pragma mark -
#pragma mark Private API

/**
 * Set up the window's tab bar.
 */
- (void)_setUpTabBar
{
	[tabBar setStyleNamed:@"SequelPro"];
	[tabBar setCanCloseOnlyTab:NO];
	[tabBar setHideForSingleTab:![[NSUserDefaults standardUserDefaults] boolForKey:SPAlwaysShowWindowTabBar]];
	[tabBar setShowAddTabButton:YES];
	[tabBar setSizeCellsToFit:NO];
	[tabBar setCellMinWidth:100];
	[tabBar setCellMaxWidth:25000];
	[tabBar setCellOptimumWidth:25000];
	[tabBar setSelectsTabsOnMouseDown:YES];
	[tabBar setCreatesTabOnDoubleClick:YES];
	[tabBar setTearOffStyle:PSMTabBarTearOffAlphaWindow];
	[tabBar setUsesSafariStyleDragging:YES];
	
	// Hook up add tab button
	[tabBar setCreateNewTabTarget:self];
	[tabBar setCreateNewTabAction:@selector(addNewConnection:)];
	
	// Set the double click target and action
	[tabBar setDoubleClickTarget:self];
	[tabBar setDoubleClickAction:@selector(openDatabaseInNewTab)];
}

/**
 * Binds a tab bar item's progress indicator to the represented tableDocument.
 */
- (void)_updateProgressIndicatorForItem:(NSTabViewItem *)theItem
{
	PSMTabBarCell *theCell = [[tabBar cells] objectAtIndex:[tabView indexOfTabViewItem:theItem]];
	
	[[theCell indicator] setControlSize:NSSmallControlSize];
	
	SPDatabaseDocument *theDocument = [theItem identifier];
	
	[[theCell indicator] setHidden:NO];
	
	NSMutableDictionary *bindingOptions = [NSMutableDictionary dictionary];
	
	[bindingOptions setObject:NSNegateBooleanTransformerName forKey:@"NSValueTransformerName"];
	
	[[theCell indicator] bind:@"animate" toObject:theDocument withKeyPath:@"isProcessing" options:nil];
	[[theCell indicator] bind:@"hidden" toObject:theDocument withKeyPath:@"isProcessing" options:bindingOptions];
	
	[theDocument addObserver:self forKeyPath:@"isProcessing" options:0 context:nil];
}


- (void)_switchOutSelectedTableDocument:(SPDatabaseDocument *)newDoc
{
	NSAssert([NSThread isMainThread], @"Switching the selectedTableDocument via a background thread is not supported!");
	
	// shortcut if there is nothing to do
	if(selectedTableDocument == newDoc) return;
	
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	if(selectedTableDocument) {
		[nc removeObserver:self name:SPDocumentWillCloseNotification object:selectedTableDocument];
		selectedTableDocument = nil;
	}
	if(newDoc) {
		[nc addObserver:self selector:@selector(_selectedTableDocumentDeallocd:) name:SPDocumentWillCloseNotification object:newDoc];
		selectedTableDocument = newDoc;
	}
	
	[self updateTabBar];
}

- (void)_selectedTableDocumentDeallocd:(NSNotification *)notification
{
	[self _switchOutSelectedTableDocument:nil];
}

#pragma mark - SPWindowControllerDelegate

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
	[closeWindowMenuItem setKeyEquivalentModifierMask:(NSEventModifierFlagCommand | NSEventModifierFlagShift)];

	// Ensure the "Close tab" item is enabled and has the standard shortcut
	[closeTabMenuItem setEnabled:YES];
	[closeTabMenuItem setKeyEquivalent:@"w"];
	[closeTabMenuItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
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
	[closeWindowMenuItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
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

	// workaround bug where "source list" table views are broken in the new window. See https://github.com/sequelpro/sequelpro/issues/2863
	SPWindowController *newWindowController = tabBarControl.window.windowController;
	newWindowController.selectedTableDocument.connectionController.favoritesOutlineView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
	newWindowController.selectedTableDocument.dbTablesTableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleRegular;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0)), dispatch_get_main_queue(), ^{
		newWindowController.selectedTableDocument.dbTablesTableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleSourceList;
		newWindowController.selectedTableDocument.connectionController.favoritesOutlineView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleSourceList;
	});
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
#warning Private ivar accessed from outside (#2978)
	return [newWindowController valueForKey:@"tabBar"];
}

/**
 * When dragging a tab off the tab bar, return an image so that a
 * drag placeholder can be displayed.
 */
- (NSImage *)tabView:(NSTabView *)aTabView imageForTabViewItem:(NSTabViewItem *)tabViewItem offset:(NSSize *)offset styleMask:(NSUInteger *)styleMask
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

#pragma mark -

- (void)dealloc
{
	[self _switchOutSelectedTableDocument:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	// Tear down the animations on the tab bar to stop redraws
	[tabBar destroyAnimations];
	
	SPClear(managedDatabaseConnections);
	
	[super dealloc];
}

@end
