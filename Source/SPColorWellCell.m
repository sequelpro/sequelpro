//
//  SPColorWellCell.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on August 17, 2010.
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

#import "SPColorWellCell.h"

@implementation SPColorWellCell

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
	// Set initial inset from cellFrame
	NSRect rect = NSInsetRect (cellFrame, 0.5f, 0.5f);

	// General inset for colored rect shown inside rect
	CGFloat insetFactor = 2.0f;

	// Draw border
	[[NSColor darkGrayColor] set];
	[NSBezierPath strokeRect: rect];
	[[NSColor grayColor] set];
	[NSBezierPath fillRect: NSInsetRect (rect, 1.0f, 1.0f)];

	// The following rectangle and triangle are needed for displaying color with alpha values
	// Draw black rectangle
	[[NSColor blackColor] set];
	[NSBezierPath fillRect: NSInsetRect (rect, insetFactor, insetFactor)];

	// Draw white triangle
	[[NSColor whiteColor] set];
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path moveToPoint: NSMakePoint(rect.origin.x - insetFactor + rect.size.width, rect.origin.y + insetFactor)];
	[path lineToPoint: NSMakePoint(rect.origin.x - insetFactor + rect.size.width, rect.origin.y + rect.size.height - insetFactor)];
	[path lineToPoint: NSMakePoint(rect.origin.x + insetFactor, rect.origin.y + rect.size.height - insetFactor)];
	[path closePath];
	[path fill];

	// Draw the actual color as rect
	[(NSColor*) [self objectValue] set];
	NSRectFillUsingOperation(NSInsetRect (rect, insetFactor, insetFactor), NSCompositeSourceOver);
}

@end
