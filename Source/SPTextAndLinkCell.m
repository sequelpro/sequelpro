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
	linkRect = NSMakeRect(aRect.origin.x + aRect.size.width - 15, aRect.origin.y - 1, 12, aRect.size.height);

	// Draw the text
	[super drawInteriorWithFrame:textRect inView:controlView];

	// Get the new link state
	int newDrawState = ([self isHighlighted])?
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
				break;
			case SP_LINKDRAWSTATE_HIGHLIGHT:
				[linkButton setImage:[NSImage imageNamed:@"link-arrow-highlighted"]];
				break;
			case SP_LINKDRAWSTATE_BACKGROUNDHIGHLIGHT:
				[linkButton setImage:[NSImage imageNamed:@"link-arrow-clicked"]];
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

	// Hit the link if it falls within the link rectangle for this cell, set when drawing
	if (p.x > linkRect.origin.x && p.x < (linkRect.origin.x + linkRect.size.width)) {

		// Capture the clicked row and cell
		NSTableView *tableView = (NSTableView *)[self controlView];
		p = [[[NSApp mainWindow] contentView] convertPoint:[event locationInWindow] toView:tableView];
		lastLinkColumn = [tableView columnAtPoint:p];
		lastLinkRow = [tableView rowAtPoint:p];

		[linkTarget performSelector:linkAction withObject:self];
		return NSCellHitContentArea;

	// Otherwise return an editable hit - this allows the entire cell to be clicked to edit the contents.
	} else {
		return NSCellHitContentArea | NSCellHitEditableTextArea;
	}
}

#pragma mark -
#pragma mark Information getters

/**
 * Retrieve the last column that recorded a click with the link cell
 */
- (int) getClickedColumn
{
	return lastLinkColumn;
}

/**
 * Retrieve the last row that recorded a click with the link cell
 */
- (int) getClickedRow
{
	return lastLinkRow;
}

@end
