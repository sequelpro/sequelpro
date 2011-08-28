//
//  $Id: SPTableView.m 866 2009-06-15 16:05:54Z bibiko $
//
//  SPTableView.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on July 15, 2009
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

#import "SPTableView.h"
#import "SPQueryFavoriteManager.h"
#import "SPDatabaseDocument.h"
#import "SPWindowController.h"
#import "SPFieldMapperController.h"

@interface SPTableView (SPTableViewDelegate)

- (BOOL)cancelRowEditing;

@end

@interface SPTableView (PrivateAPI)

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

- (void) awakeFromNib
{
	[super setDoubleAction:@selector(_doubleClickAction)];
	if ([NSTableView instancesRespondToSelector:@selector(awakeFromNib)])
		[super awakeFromNib];
}

/**
 * Track window changes, in order to add listeners for when sheets are shown
 * or hidden; this allows the double-click action to be disabled while sheets
 * are open, preventing beeps when using the field editor on double-click.
 */
- (void) viewWillMoveToWindow:(NSWindow *)aWindow {
	NSNotificationCenter *notifier = [NSNotificationCenter defaultCenter];

	[notifier removeObserver:self name:NSWindowWillBeginSheetNotification object:nil];
	[notifier removeObserver:self name:NSWindowDidEndSheetNotification object:nil];

	if (aWindow) {
		[notifier addObserver:self selector:@selector(_disableDoubleClickAction:) name:NSWindowWillBeginSheetNotification object:aWindow];
		[notifier addObserver:self selector:@selector(_enableDoubleClickAction:) name:NSWindowDidEndSheetNotification object:aWindow];
	}
}

#pragma mark -

/**
 * Right-click at row will select that row before ordering out the contextual menu
 * if not more than one row is selected.
 */
- (NSMenu *)menuForEvent:(NSEvent *)event
{
#ifndef SP_REFACTOR /* menuForEvent: */
	// Try to retrieve a reference to the table document (assuming this is frontmost tab)
	SPDatabaseDocument *parentTableDocument = nil;
	
	if ([[[[[self window] delegate] class] description] isEqualToString:@"SPWindowController"]) {
		parentTableDocument = [[[self window] delegate] selectedTableDocument];
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
 * On becomeFirstResponder, if editing is disabled, override the super and just
 * display instead; this prevents the selected cell from automatically editing
 * if the table is backtabbed to.
 */
- (BOOL)becomeFirstResponder {
	if (tabEditingDisabled) {
		[self display];
		return YES;
	}
	return [super becomeFirstResponder];
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
				[super keyDown:theEvent];
				return;
			}

		}

		if ((![[[[self delegate] class] description] isEqualToString:@"SPCustomQuery"]) &&
			(![[[[self delegate] class] description] isEqualToString:@"SPQueryFavoriteManager"]) &&
			(![[[[self delegate] class] description] isEqualToString:@"SPConnectionController"])) {
			
			// Ensure that editing is permitted
			if (![[self delegate] tableView:self shouldEditTableColumn:[[self tableColumns] objectAtIndex:0] row:[self selectedRow]]) return;

			// Trigger a cell edit
			[self editColumn:0 row:[self selectedRow] withEvent:nil select:YES];
			
			return;
		}
	}

	// Check if ESCAPE is hit and use it to cancel row editing if supported
	else if ([theEvent keyCode] == 53 && [[self delegate] respondsToSelector:@selector(cancelRowEditing)]) {
		if ([[self delegate] performSelector:@selector(cancelRowEditing)]) return;
	}
	
	// If the Tab key is used, but tab editing is disabled, change focus rather than entering edit mode.
	else if (tabEditingDisabled && [[theEvent characters] length] && [[theEvent characters] characterAtIndex:0] == NSTabCharacter) {
		if (([theEvent modifierFlags] & NSShiftKeyMask) != NSShiftKeyMask) {
			[[self window] selectKeyViewFollowingView:self];
		} else {
			[[self window] selectKeyViewPrecedingView:self];
		}
		return;
	}
	
	[super keyDown:theEvent];
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

@end


@implementation SPTableView (PrivateAPI)

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
