//
//  SPTableView.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on July 15, 2009.
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

#import "SPTableView.h"
#import "SPQueryFavoriteManager.h"
#import "SPDatabaseDocument.h"
#import "SPWindowController.h"
#import "SPFieldMapperController.h"

@protocol SPTableViewDelegate <NSObject>
@optional
- (BOOL)cancelRowEditing;

@end

@interface NSTableView (ApplePrivate)
- (BOOL)_allowTabbingIntoCells;
@end

@interface SPTableView ()

- (void)_doubleClickAction;
- (void)_disableDoubleClickAction:(NSNotification *)notification;
- (void)_enableDoubleClickAction:(NSNotification *)notification;

@end

@implementation SPTableView

@synthesize tabEditingDisabled;

- (id) init
{
	if ((self = [super init])) {
		emptyDoubleClickAction = NULL;
	}
	
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (void) awakeFromNib
{
	[super setDoubleAction:@selector(_doubleClickAction)];
	
	if ([NSTableView instancesRespondToSelector:@selector(awakeFromNib)]) {
		[super awakeFromNib];
	}
}

#pragma mark -

/**
 * Track window changes, in order to add listeners for when sheets are shown
 * or hidden; this allows the double-click action to be disabled while sheets
 * are open, preventing beeps when using the field editor on double-click.
 */
- (void)viewWillMoveToWindow:(NSWindow *)aWindow 
{
	NSNotificationCenter *notifier = [NSNotificationCenter defaultCenter];

	[notifier removeObserver:self name:NSWindowWillBeginSheetNotification object:nil];
	[notifier removeObserver:self name:NSWindowDidEndSheetNotification object:nil];

	if (aWindow) {
		[notifier addObserver:self selector:@selector(_disableDoubleClickAction:) name:NSWindowWillBeginSheetNotification object:aWindow];
		[notifier addObserver:self selector:@selector(_enableDoubleClickAction:) name:NSWindowDidEndSheetNotification object:aWindow];
	}
	
	[super viewWillMoveToWindow:aWindow];
}

/**
 * Right-click at row will select that row before ordering out the contextual menu
 * if not more than one row is selected.
 */
- (NSMenu *)menuForEvent:(NSEvent *)event
{
#ifndef SP_CODA /* menuForEvent: */
	// Try to retrieve a reference to the table document (assuming this is frontmost tab)
	SPDatabaseDocument *parentTableDocument = nil;
	
	if ([[[[[self window] delegate] class] description] isEqualToString:@"SPWindowController"]) {
		parentTableDocument = [(SPWindowController *)[[self window] delegate] selectedTableDocument];
	}

	// If SPDatabaseDocument is performing a task suppress any context menu
	if (parentTableDocument && [parentTableDocument isWorking]) return nil;

	// Check to see whether any edits-in-progress need to be saved before changing selections
	if (parentTableDocument && ![parentTableDocument couldCommitCurrentViewActions]) return nil;

	// If more than one row is selected only returns the default contextual menu
	if ([self numberOfSelectedRows] > 1) return [self menu];
	
	// Right-click at a row will select that row before ordering out the context menu
	NSInteger row = [self rowAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]];
	
	if (row >= 0 && row < [self numberOfRows]) {
		
		// Check for SPTablesList if right-click on header, then suppress context menu
		if ([[[[self delegate] class] description] isEqualToString:@"SPTablesList"]) {
			if ([NSArrayObjectAtIndex([(NSObject*)[self delegate] valueForKeyPath:@"tableTypes"], row) integerValue] == -1)
				return nil;
		}
		
		if ([[[[self delegate] class] description] isEqualToString:@"SPQueryFavoriteManager"]) {
			if ([NSArrayObjectAtIndex([(NSObject*)[self delegate] valueForKeyPath:SPFavorites], row)  objectForKey:@"headerOfFileURL"])
				return nil;
		}
		
		if ([[[[self delegate] class] description] isEqualToString:@"SPContentFilterManager"]) {
			if ([NSArrayObjectAtIndex([(NSObject*)[self delegate] valueForKeyPath:@"contentFilters"], row)  objectForKey:@"headerOfFileURL"])
				return nil;
		}
		
		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		[[self window] makeFirstResponder:self];
	}
#endif
	return [self menu];
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

/**
 * THIS IS A HACK!
 *
 * When you do the following steps:
 *
 *   b.1) Have "Tab all controls" enabled in System Prefs
 *   b.2) Click on a row in the table view
 *   b.3) Set the focus to the next responder after the table view (e.g. by pressing "tab")
 *   b.4) Set the focus back to the table view by pressing "shift"+"tab"
 *
 * Cocoa would automatically start editing the table cell, which is not always desirable.
 *
 * Previously we overrode -becomeFirstResponder, which is the call ultimately triggering the
 * edit. However, when looking at the implementation of -becomeFirstResponder it becomes clear
 * that Apple has not intended for developers to override this method or provided any other way
 * to influence the behaviour and since our overridden method would omit some internal method calls
 * this caused other issues (#3214).
 *
 * We could still solve this by overriding it and hooking another of the three public API
 * calls it makes:
 *   a) -[NSTableView acceptsFirstResponder]
 *   b) -[NSTableColumn isEditable]
 *   c) -[NSTableView editColumn:row:withEvent:select:]
 *
 * But this would still be a hack as we would be relying on implementation internals and
 * each methods has some problem:
 *
 * We can't use a) because it is called too early and won't trigger a necessary
 * drawing update, leaving us with the same issue that we tried to solve here.
 *
 * While c) looks to be the better method to cancel an edit, it actually is too
 * late and will cause erratic behaviour with the focus ring.
 *
 * Which leaves b), which luckily is a primitive ivar setter
 * and not an observable property and doesn't trigger any side effects like
 * rerendering (tested with 10.9 and 10.14). BUT: Up to getting to the point where this
 * method is called, a lot of decision making is involved to determine the column to call
 * this on and it won't be called for view-based table views and group rows (full width cells)
 * anyway.
 *
 * So if we have to use a hack anyway, let's just go with the easiest thing and override
 * the internal method call that can cancel the edit right where we want it to (at least in 10.9 - 10.4).
 */
- (BOOL)_allowTabbingIntoCells
{
	return (tabEditingDisabled ? NO : [super _allowTabbingIntoCells]);
}

- (void)keyDown:(NSEvent *)theEvent
{
	// Check if ENTER or RETURN is hit and edit the column.
	if ([self numberOfSelectedRows] == 1 && ([theEvent keyCode] == 36 || [theEvent keyCode] == 76)) {

		if ([[[[self delegate] class] description] isEqualToString:@"SPFieldMapperController"]) {
			if ([(SPFieldMapperController*)[self delegate] isGlobalValueSheetOpen]) {
				[(SPFieldMapperController*)[self delegate] closeGlobalValuesSheet:nil];
				return;
			}

			// ENTER or RETURN closes the SPFieldMapperController sheet
			// by sending an object with the tag 1 if no table cell is edited
			if ([(SPFieldMapperController*)[self delegate] canBeClosed]) {
				NSButton *b = [[[NSButton alloc] init] autorelease];
				[b setTag:1];
				[(SPFieldMapperController*)[self delegate] closeSheet:b];
				
				return;
			} 
			else {
				goto pass_keyDown_to_super;
			}

		}

		if ((![[[[self delegate] class] description] isEqualToString:@"SPCustomQuery"]) &&
			(![[[[self delegate] class] description] isEqualToString:@"SPQueryFavoriteManager"]) &&
			(![[[[self delegate] class] description] isEqualToString:@"SPConnectionController"])) {
			
			// Ensure that editing is permitted
			if(![[self delegate] respondsToSelector:@selector(tableView:shouldEditTableColumn:row:)]) return; // disallow by default
			if(![[self delegate] tableView:self shouldEditTableColumn:[[self tableColumns] objectAtIndex:0] row:[self selectedRow]]) return;
			
			// Trigger a cell edit
			[self editColumn:0 row:[self selectedRow] withEvent:nil select:YES];
			
			return;
		}
	}

	// Check if ESCAPE is hit
	else if ([theEvent keyCode] == 53) {
		// Use it to cancel row editing if supported
		if ([[self delegate] respondsToSelector:@selector(cancelRowEditing)]) {
			if ([(id<SPTableViewDelegate>)[self delegate] cancelRowEditing]) return;
		}
		// If more rows is selected, cancel selection of all
		else if ([self numberOfSelectedRows] > 1) {
			[self deselectAll:nil];
		}
		return;
	}
	
	// If the Tab key is used, but tab editing is disabled, change focus rather than entering edit mode.
	else if (tabEditingDisabled && [[theEvent characters] length] && [[theEvent characters] characterAtIndex:0] == NSTabCharacter) {
		if (([theEvent modifierFlags] & NSEventModifierFlagShift) != NSEventModifierFlagShift) {
			[[self window] selectKeyViewFollowingView:self];
		} 
		else {
			[[self window] selectKeyViewPrecedingView:self];
		}
		
		return;
	}

pass_keyDown_to_super:
	@try {
		[super keyDown:theEvent];
	}
	@catch (NSException *ex) {
		// debug code for #2445
		NSString *ownId = [NSString stringWithFormat:@"%@(%@)",self,([self respondsToSelector:@selector(identifier)]? [self identifier] : @"-N/A-")];
		[NSException raise:NSInternalInconsistencyException
					format:@"%s: passing event to super failed! (issue #2445)\n\nOriginal exception:\n%@\n\nEvent:\n  %@\nDelegate:\n  %@\nself:\n  %@",__PRETTY_FUNCTION__,ex,theEvent,[self delegate],ownId];
	}
}

/**
 * To prevent right-clicking in a column's 'group' heading, ask the delegate if we support selecting it
 * as this normally doesn't apply to left-clicks. If we do support selecting this row, simply pass on the event.
 */
- (void)rightMouseDown:(NSEvent *)event
{
	if ([[self delegate] respondsToSelector:@selector(tableView:shouldSelectRow:)]) {
		if ([[self delegate] tableView:self shouldSelectRow:[self rowAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]]]) {
			[super rightMouseDown:event];
		}
	}
	else {
		[super rightMouseDown:event];
	}
}

- (void)setFont:(NSFont *)font;
{
	NSArray *tableColumns = [self tableColumns];
	NSUInteger columnIndex = [tableColumns count];
	
	while (columnIndex--) 
	{
		[[(NSTableColumn *)[tableColumns objectAtIndex:columnIndex] dataCell] setFont:font];
	}
}

- (void)setEmptyDoubleClickAction:(SEL)aSelector
{
	emptyDoubleClickAction = aSelector;
}

#ifdef SP_CODA

- (void)delete:(id)sender
{
	if ( [[self delegate] respondsToSelector:@selector(removeField:)] )
	{
		[[self delegate] performSelector:@selector(removeField:) withObject:self];
	}
	else if ( [[self delegate] respondsToSelector:@selector(removeIndex:)] )
	{
		[[self delegate] performSelector:@selector(removeIndex:) withObject:self];
	}
}


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ( [menuItem action] == @selector(delete:) )
	{	
		if ( [self numberOfSelectedRows] == 0 )
			return NO;
	}
	
	return YES;
}

#endif

/**
 * On a double click, determine whether the action was in the empty area
 * of the current table; if so, perform the assigned emptyDoubleClick action.
 */
- (void)_doubleClickAction
{
	if ([super clickedRow] == -1 && [super clickedColumn] == -1 && emptyDoubleClickAction) {
		[[self delegate] performSelector:emptyDoubleClickAction];
	}
}

/**
 * When a sheet is opened on this window, disable the double-click action.
 * This prevents beeping when a double-click results in a rejected cell edit but
 * opens a sheet such as the field editor sheet.
 */
- (void)_disableDoubleClickAction:(NSNotification *)notification
{
	[super setDoubleAction:NULL];
}

/**
 * Restore the double-click action after the sheet is closed.
 */
- (void)_enableDoubleClickAction:(NSNotification *)notification
{
	[super setDoubleAction:@selector(_doubleClickAction)];
}


@end
