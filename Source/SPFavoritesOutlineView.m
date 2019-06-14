//
//  SPFavoritesOutlineView.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 10, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPFavoritesOutlineView.h"
#import "SPConnectionController.h"

@interface SPFavoritesOutlineView ()

@property (nonatomic,readwrite,assign) id itemForDoubleAction; //make setter private

@end

static NSUInteger SPFavoritesOutlineViewUnindent = 6;

@implementation SPFavoritesOutlineView

@synthesize justGainedFocus;
@synthesize itemForDoubleAction = _itemForDoubleAction;

- (void)awakeFromNib
{
	isOSVersionAtLeast10_7_0 = [SPOSInfo isOSVersionAtLeastMajor:10 minor:7 patch:0];
}

- (BOOL)acceptsFirstResponder
{
	if ([[self window] firstResponder] != self) {
		[self setJustGainedFocus:YES];
	}

	return YES;
}

- (BOOL)resignFirstResponder
{
	[self setJustGainedFocus:NO];
	
	return [super resignFirstResponder];;
}

/**
 * Right-click at row will select that row before ordering out the contextual menu
 * if not more than one row is selected.
 */
- (NSMenu *)menuForEvent:(NSEvent *)event
{	
	// If more than one row is selected only return the default contextual menu
	if ([self numberOfSelectedRows] > 1) return [self menu];
	
	// Right-click at a row will select that row before ordering out the context menu
	NSInteger row = [self rowAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]];
	
	if ((row >= 0) && (row < [self numberOfRows])) {
		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		[[self window] makeFirstResponder:self];
	}
	
	return [self menu];
}

- (void)keyDown:(NSEvent *)event
{
	// Enter or Return initiates a connection to the selected favorite, which is the same as double-clicking
	// one, so call the same selector.
	if (([self numberOfSelectedRows] == 1) && (([event keyCode] == 36) || ([event keyCode] == 76))) {
		[self setItemForDoubleAction:[self itemAtRow:[self selectedRow]]];
		[NSApp sendAction:[self doubleAction] to:[self delegate] from:self];
		[self setItemForDoubleAction:nil];
		return;
	}
	// If the Tab key is used, change focus rather than entering edit mode.
	if ([[event characters] length] && [[event characters] characterAtIndex:0] == NSTabCharacter) {
		if (([event modifierFlags] & NSEventModifierFlagShift) != NSEventModifierFlagShift) {
			[[self window] selectKeyViewFollowingView:self];
		} 
		else {
			[[self window] selectKeyViewPrecedingView:self];
		}
		
		return;
	}
	
	[super keyDown:event];
}

- (void)mouseDown:(NSEvent *)theEvent
{
	if([theEvent type] == NSLeftMouseDown && [theEvent clickCount] == 2) {
		// The tricky thing is that [self clickedRow] is set from [NSTableView mouseDown], so right now it's not populated.
		// We can't use [self selectedRow] either, as clicking on empty space does not update the selection.
		NSPoint clickAt = [theEvent locationInWindow];
		NSPoint relClickAt = [self convertPoint:clickAt fromView:nil];
		NSInteger rowNum = [self rowAtPoint:relClickAt];
		if(rowNum > -1) [self setItemForDoubleAction:[self itemAtRow:rowNum]];
	}
	
	[super mouseDown:theEvent];
	
	[self setItemForDoubleAction:nil]; // not much overhead, therefore unconditional
}

/**
 * To prevent right-clicking in a column's 'group' heading, ask the delegate if we support selecting it
 * as this normally doesn't apply to left-clicks. If we do support selecting this row, simply pass on the event.
 */
- (void)rightMouseDown:(NSEvent *)event
{
	if ([[self delegate] respondsToSelector:@selector(outlineView:shouldSelectItem:)]) {
		if ([[self delegate] outlineView:self shouldSelectItem:[self itemAtRow:[self rowAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]]]]) {
			[super rightMouseDown:event];
		}
	}
	else {
		[super rightMouseDown:event];
	}
}

/**
 * Disclosure triangles for the top-level items hae been removed, and similarly other
 * paddings need altering.  This involves increasing the padding - and reducing the width -
 * of all rows to compensate.
 */
- (NSRect)frameOfCellAtColumn:(NSInteger)columnIndex row:(NSInteger)rowIndex
{
	NSRect superFrame = [super frameOfCellAtColumn:columnIndex row:rowIndex];

	// On system versions lower than Lion, don't alter padding
	if (!isOSVersionAtLeast10_7_0) {
		return superFrame;
	}

	// Don't alter padding for the top-level items
	if ([[self delegate] respondsToSelector:@selector(outlineView:isGroupItem:)]) {
		if ([[self delegate] outlineView:self isGroupItem:[self itemAtRow:rowIndex]]) {
			return superFrame;
		}
	}

	return NSMakeRect(superFrame.origin.x + SPFavoritesOutlineViewUnindent, superFrame.origin.y, superFrame.size.width - SPFavoritesOutlineViewUnindent, superFrame.size.height);
}

/**
 * Disclosure triangles for the top-level items have been removed, the frames for other
 * disclosure items need to be similarly moved.
 */
- (NSRect)frameOfOutlineCellAtRow:(NSInteger)rowIndex
{
	NSRect superFrame = [super frameOfOutlineCellAtRow:rowIndex];

	// Return NSZeroRect if the row is a group row
	if ([[self delegate] respondsToSelector:@selector(outlineView:isGroupItem:)]) {
		if ([[self delegate] outlineView:self isGroupItem:[self itemAtRow:rowIndex]]) {
			return NSZeroRect;
		}
	}

	// On versions of Lion or above, amend the padding appropriately
	if (isOSVersionAtLeast10_7_0) {
		return NSMakeRect(superFrame.origin.x + SPFavoritesOutlineViewUnindent, superFrame.origin.y, superFrame.size.width, superFrame.size.height);
	}

	return superFrame;
}


/**
 * If the delegate is a SPConnectionController, and editing is currently in
 * progress, draw a custom highlight.
 */
- (void)highlightSelectionInClipRect:(NSRect)clipRect
{
	// Only proceed if a the delegate is a SPConnectionController and a favorite being edited
	if ([[self delegate] isKindOfClass:[SPConnectionController class]] && 
		[(SPConnectionController *)[self delegate] isEditingConnection] &&
		[(SPConnectionController *)[self delegate] selectedFavorite])
	{

		// Draw an editing dot instead of highlighting the whole row
		NSRect rowRect = [self rectOfRow:[self selectedRow]];
		float dotSize = rowRect.size.height / 1.9;
		NSRect dotRect = NSMakeRect(9.f, rowRect.origin.y + ((rowRect.size.height - dotSize) / 2), dotSize, dotSize);
		[NSGraphicsContext saveGraphicsState];

		NSBezierPath *clipPath = [NSBezierPath bezierPath];
		[clipPath appendBezierPathWithOvalInRect:dotRect];
		[clipPath addClip];

		NSGradient *dotGradient = [[[NSGradient alloc] initWithStartingColor:[NSColor colorWithDeviceRed:0.44f green:0.72f blue:0.92f alpha:1.f] endingColor:[NSColor colorWithDeviceRed:0.21f green:0.53f blue:0.82f alpha:1.f]] autorelease];
		[dotGradient drawInRect:dotRect angle:90.f];

		[NSGraphicsContext restoreGraphicsState];
		
		return;
	}

	[super highlightSelectionInClipRect:clipRect];
}

@end
