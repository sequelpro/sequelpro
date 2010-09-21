//
//  $Id$
//
//  SPColorWellCell.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on August 17, 2010
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

#import "SPColorWellCell.h"

@implementation SPColorWellCell

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
	// Set initial inset from cellFrame
	NSRect rect = NSInsetRect (cellFrame, 0.5, 0.5);

	// General inset for colored rect shown inside rect
	CGFloat insetFactor = 2.0f;

	// Draw border
	[[NSColor darkGrayColor] set];
	[NSBezierPath strokeRect: rect];
	[[NSColor grayColor] set];
	[NSBezierPath fillRect: NSInsetRect (rect, 1.0, 1.0)];

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
