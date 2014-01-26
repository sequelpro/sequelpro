//
//  SPOutlineView.m
//  sequel-pro
//
//  Created by Mark Townsend on Aug 25, 2009.
//  Copyright (c) 2009 Mark Townsend. All rights reserved.
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

#import "SPOutlineView.h"

@implementation SPOutlineView

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
