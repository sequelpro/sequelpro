//
//  SPTableTextFieldCell.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 1, 2009.
//  Copyright (c) 2009 Stuart Connolly. All rights reserved.
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

#import "SPTableTextFieldCell.h"

@implementation SPTableTextFieldCell



/**
 * Initialise
 */
- (id) initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self) {
//		noteButton = nil;
		noteButton = [[NSCell alloc] init];
		[noteButton setTitle:@""];
		[noteButton setBordered:NO];
		[noteButton setAlignment:NSRightTextAlignment];
		[noteButton setSelectable:FALSE];
		[noteButton setEditable:FALSE];
	}
	return self;
}

/**
 * Deallocate
 */
- (void) dealloc
{
	[noteButton release];
	noteButton = nil;
	[super dealloc];
}

- copyWithZone:(NSZone *)zone
{
	SPTableTextFieldCell *cell = (SPTableTextFieldCell *)[super copyWithZone:zone];
	cell->noteButton = nil;
	if (noteButton) cell->noteButton = [noteButton copyWithZone:zone];
	return cell;
}

/**
 * Implements nicer cell truncating by appending '...' to the table name, before asking super to draw it.
 */
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{			
	// Construct and get the sub text attributed string
	NSAttributedString *string = [self attributedStringValue];

	NSUInteger i;
	CGFloat maxWidth = cellFrame.size.width;
	CGFloat stringWidth = [string size].width;

	// Set a right padding
	maxWidth -= 5;

	if (maxWidth < stringWidth) {
		for (i = 0; i <= [string length]; i++) {
			if (([[string attributedSubstringFromRange:NSMakeRange(0, i)] size].width >= maxWidth) && (i >= 3)) {
				string = [[[NSMutableAttributedString alloc] initWithString:[[[string attributedSubstringFromRange:NSMakeRange(0, i - 3)] string] stringByAppendingString:@"..."] attributes:[string attributesAtIndex:0 effectiveRange:NULL]] autorelease];
				break;
			}
		}
	}

	[self setAttributedStringValue:string];
	[super drawInteriorWithFrame:cellFrame inView:controlView];

	
	// Set up new rects
	
	if (noteButton != nil)
	{
		NSRect linkRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width, cellFrame.size.height);
		[noteButton drawInteriorWithFrame:linkRect inView:controlView];
	}
	
}

- (void) setNote:(NSString *)lableText
{
	if (noteButton != nil)
	{
		[noteButton setTitle:lableText];
	}
}

- (NSSize)cellSize
{
	NSSize cellSize = [super cellSize];

	cellSize.width = [[self attributedStringValue] size].width + (([self image] != nil) ? [[self image] size].width : 0) + 25;
	cellSize.height = [[self attributedStringValue] size].height + 14.0f;

	return cellSize;
}

@end
