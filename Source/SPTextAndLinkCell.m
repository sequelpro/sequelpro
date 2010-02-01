//
//  $Id: SPTextAndLinkCell.m 866 2009-06-15 16:05:54Z bibiko $
//
//  SPTextAndLinkCell.m
//  sequel-pro
//
//  Created by Rowan Beentje on 16/07/2009.
//  With thanks to Brian Dunagan ( http://www.bdunagan.com/ ) for original approach
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

#import "SPTextAndLinkCell.h"

@implementation SPTextAndLinkCell

/**
 * Provide a method to derive the link rect from a cell rect.
 */
static inline NSRect SPTextLinkRectFromCellRect(NSRect inRect) 
{
	return NSMakeRect(inRect.origin.x + inRect.size.width - 15, inRect.origin.y - 1, 12, inRect.size.height);
}

#pragma mark -
#pragma mark Setup and teardown

/**
 * Initialise
 */
- (id) initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self) {
		hasLink = NO;
		linkButton = nil;
		linkTarget = nil;
		drawState = SP_LINKDRAWSTATE_NORMAL;
		
		lastLinkColumn = NSNotFound;
		lastLinkRow = NSNotFound;
	}
	return self;
}

/**
 * Deallocate
 */
- (void) dealloc
{
	if (linkButton) [linkButton release];

	[super dealloc];
}

/**
 * Encodes using a given receiver.
 */
- (void) encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];
}

/**
 * Returns a new instance which is a copy of the receiver
 */
- (id) copyWithZone:(NSZone *)zone {
	SPTextAndLinkCell *copy = [super copyWithZone:zone];
	if (linkButton) copy->linkButton = [linkButton copyWithZone:zone];
	return copy;
}


#pragma mark -
#pragma mark Enabling link functionality

/**
 * Set the link target and action - this also enables the link
 * arrow within the cell.
 */
- (void) setTarget:(id)theTarget action:(SEL)theAction
{
	linkTarget = theTarget;
	linkAction = theAction;

	if (!hasLink) {
		hasLink = YES;

		linkButton = [[NSButtonCell alloc] init];
		[linkButton setButtonType:NSMomentaryChangeButton];
		[linkButton setImagePosition:NSImageRight];
		[linkButton setTitle:@""];
		[linkButton setBordered:NO];
		[linkButton setShowsBorderOnlyWhileMouseInside:YES];
		[linkButton setImage:[NSImage imageNamed:@"link-arrow"]];
		[linkButton setAlternateImage:[NSImage imageNamed:@"link-arrow-clicked"]];
	}
}

#pragma mark -
#pragma mark Drawing and interaction

/**
 * Redraw the table cell, altering super draw behavior to leave space
 * for the link if necessary.
 */
- (void)drawInteriorWithFrame:(NSRect)aRect inView:(NSView *)controlView
{

	// Fast case for no arrow
	if (!hasLink) {
		[super drawInteriorWithFrame:aRect inView:controlView];
		return;
	}
	
	// Set up new rects
	NSRect textRect = NSMakeRect(aRect.origin.x, aRect.origin.y, aRect.size.width - 18, aRect.size.height);
	NSRect linkRect = SPTextLinkRectFromCellRect(aRect);

	// Draw the text
	[super drawInteriorWithFrame:textRect inView:controlView];

	// Get the new link state
	NSInteger newDrawState = ([self isHighlighted])?
							((([(NSTableView *)[self controlView] editedColumn] != -1
								|| [[[self controlView] window] firstResponder] == [self controlView])
								&& [[[self controlView] window] isKeyWindow])?SP_LINKDRAWSTATE_HIGHLIGHT:SP_LINKDRAWSTATE_BACKGROUNDHIGHLIGHT):
							SP_LINKDRAWSTATE_NORMAL;

	// Update the link arrow style if the state has changed
	if (drawState != newDrawState) {
		drawState = newDrawState;
		switch (drawState) {
			case SP_LINKDRAWSTATE_NORMAL:
				[linkButton setImage:[NSImage imageNamed:@"link-arrow"]];
				[linkButton setAlternateImage:[NSImage imageNamed:@"link-arrow-clicked"]];
				break;
			case SP_LINKDRAWSTATE_HIGHLIGHT:
				[linkButton setImage:[NSImage imageNamed:@"link-arrow-highlighted"]];
				[linkButton setAlternateImage:[NSImage imageNamed:@"link-arrow-highlighted-clicked"]];
				break;
			case SP_LINKDRAWSTATE_BACKGROUNDHIGHLIGHT:
				[linkButton setImage:[NSImage imageNamed:@"link-arrow-clicked"]];
				[linkButton setAlternateImage:[NSImage imageNamed:@"link-arrow"]];
				break;
		}
	}

	[linkButton drawInteriorWithFrame:linkRect inView:controlView];
}

/**
 * Allow hit tracking for link functionality
 */
- (NSUInteger) hitTestForEvent:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView
{

	// Fast case for no link - make entire cell editable click area
	if (!hasLink) return NSCellHitContentArea | NSCellHitEditableTextArea;

	NSPoint p = [[[NSApp  mainWindow] contentView] convertPoint:[event locationInWindow] toView:controlView];
	NSRect linkRect = SPTextLinkRectFromCellRect(cellFrame);

	// Hit the link if it falls within the link rectangle for this cell, set when drawing
	if (p.x > linkRect.origin.x && p.x < (linkRect.origin.x + linkRect.size.width)) {

		// Return a trackable hit
		return NSCellHitContentArea | NSCellHitTrackableArea;

	// Otherwise return an editable hit - this allows the entire cell to be clicked to edit the contents.
	} else {
		return NSCellHitContentArea | NSCellHitEditableTextArea;
	}
}

/**
 * Allow mouse tracking within the button cell, to support expected click
 * behaviour in the button cell.
 */
- (BOOL)trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView untilMouseUp:(BOOL)untilMouseUp
{

	// Fast case for no link
	if (!hasLink) return [super trackMouse:theEvent inRect:cellFrame ofView:controlView untilMouseUp:untilMouseUp];

	NSPoint p = [controlView convertPoint:[theEvent locationInWindow] fromView:nil];
	NSRect linkRect = SPTextLinkRectFromCellRect(cellFrame);

	// Fast path for if not in button rect - just pass to super
	if (!NSMouseInRect(p, linkRect, [controlView isFlipped]))
		return [super trackMouse:theEvent inRect:cellFrame ofView:controlView untilMouseUp:untilMouseUp];

	// Continue tracking the mouse while it's down, updating the state as it enters and leaves the cell,
	// until it is released; if still within the cell, follow the link.
	BOOL mouseInButton = YES;
	while (1) {
		if (mouseInButton) {

			// Highlight the button
			[linkButton highlight:YES withFrame:linkRect inView:controlView];

			// Continue to track until mouse completes a click or exits the cell while still down
			BOOL mouseClicked = [linkButton trackMouse:theEvent inRect:linkRect ofView:controlView untilMouseUp:NO];
			if (mouseClicked) {

				// Capture the clicked row and cell
				NSTableView *tableView = (NSTableView *)[self controlView];
				p = [[[NSApp mainWindow] contentView] convertPoint:[theEvent locationInWindow] toView:tableView];
				lastLinkColumn = [tableView columnAtPoint:p];
				lastLinkRow = [tableView rowAtPoint:p];

				// Remove highlight, and follow the link
				[linkButton highlight:NO withFrame:linkRect inView:controlView];
				[linkTarget performSelector:linkAction withObject:self];
				return YES;
			}

			// Mouse has exited the cell.  Remove highlight.
			mouseInButton = NO;
			[linkButton highlight:NO withFrame:linkRect inView:controlView];
		}

		// Keep tracking the mouse outside the button, until the mouse button is released or it reenters the button
		theEvent = [[controlView window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
		p = [controlView convertPoint:[theEvent locationInWindow] fromView:nil];
		mouseInButton = NSMouseInRect(p, linkRect, [controlView isFlipped]);

		// If the event is a mouse release, break the loop.
		if ([theEvent type] == NSLeftMouseUp) break;
	}

	return YES;
}

#pragma mark -
#pragma mark Information getters

/**
 * Retrieve the last column that recorded a click with the link cell
 */
- (NSInteger) getClickedColumn
{
	return lastLinkColumn;
}

/**
 * Retrieve the last row that recorded a click with the link cell
 */
- (NSInteger) getClickedRow
{
	return lastLinkRow;
}

/**
 * Suppress the built-in expansion tooltip
 */
- (NSRect)expansionFrameWithFrame:(NSRect)cellFrame inView:(NSView *)view
{
	return NSZeroRect;
}

@end
