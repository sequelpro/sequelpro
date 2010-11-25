//
//  $Id$
//
//  SPOutlineView.m
//  sequel-pro
//
//  Created by Mark Townsend on Aug 25, 2009
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

#import "SPOutlineView.h"

@implementation SPOutlineView

- (id)init
{
	if(self = [super init]){
		;
	}
	return self;
}

/**
 * Right-click at row will select that row before ordering out the contextual menu
 * if not more than one row is selected.
 */
- (NSMenu *)menuForEvent:(NSEvent *)event
{

	// Check for SPBundleEditorController if right-click on expamdable item, then suppress context menu
	if ([[[[self delegate] class] description] isEqualToString:@"SPBundleEditorController"]) {

		// If more than one row is selected only returns the default contextual menu
		if ([self numberOfSelectedRows] > 1) return nil;

		// Right-click at a row will select that row before ordering out the context menu
		NSInteger row = [self rowAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]];

		if (row >= 0 && row < [self numberOfRows]) {
			[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
			[[self window] makeFirstResponder:self];
		}

		if ([self levelForItem:[self itemAtRow:[self selectedRow]]] < 1)
			return nil;
		return [self menu];
	}


	// If more than one row is selected only returns the default contextual menu
	if ([self numberOfSelectedRows] > 1) return [self menu];

	// Right-click at a row will select that row before ordering out the context menu
	NSInteger row = [self rowAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]];

	if (row >= 0 && row < [self numberOfRows]) {
		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		[[self window] makeFirstResponder:self];
	}

	return [self menu];
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (void)keyDown:(NSEvent *)theEvent
{

	if ([self numberOfSelectedRows] == 1 && ([theEvent keyCode] == 36 || [theEvent keyCode] == 76)) {
		if ([[[[self delegate] class] description] isEqualToString:@"SPBundleEditorController"]) {
			if([[self delegate] respondsToSelector:@selector(outlineView:shouldEditTableColumn:item:)] &&
				[[self delegate] outlineView:self shouldEditTableColumn:[self tableColumnWithIdentifier:@"bundleName"] item:[self itemAtRow:[self selectedRow]]]
				)
				[self editColumn:0 row:[self selectedRow] withEvent:nil select:YES];
			else
				return;
		}
		
		[self editColumn:0 row:[self selectedRow] withEvent:nil select:YES];
	}
	else {
		[super keyDown:theEvent];
	}
}

@end
