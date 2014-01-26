//
//  SPNavigatorOutlineView.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on March 23, 2010.
//  Copyright (c) 2010 Hans-Jörg Bibiko. All rights reserved.
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

#import "SPNavigatorOutlineView.h"
#import "SPNavigatorController.h"

@implementation SPNavigatorOutlineView

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (void)keyDown:(NSEvent *)theEvent
{
	// Enter or Return selects in active document the chosen item
	if ([self numberOfSelectedRows] == 1 && ([theEvent keyCode] == 36 || [theEvent keyCode] == 76)) {
		[(SPNavigatorController *)[self delegate] selectInActiveDocumentItem:[self itemAtRow:[self selectedRow]] fromView:self];
		
		return;
	}

	[super keyDown:theEvent];
}

/**
 * Return the data source item of the selected row, if no or multiple selections return nil.
 */
- (id)selectedItem
{
	if ([self numberOfSelectedRows] == 1) {
		return [self itemAtRow:[self selectedRow]];
	}
	
	return nil;
}

@end
