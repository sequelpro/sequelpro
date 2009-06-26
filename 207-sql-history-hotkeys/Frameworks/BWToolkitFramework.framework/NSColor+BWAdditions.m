//
//  NSColor+PixelWideLines.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "NSColor+BWAdditions.h"

@implementation NSColor (BWAdditions)

//  Use this method to draw 1 px wide lines independent of scale factor. Handy for resolution independent drawing. Still needs some work - there are issues with drawing at the edges of views.
- (void)drawPixelThickLineAtPosition:(int)posInPixels withInset:(int)insetInPixels inRect:(NSRect)aRect inView:(NSView *)view horizontal:(BOOL)isHorizontal flip:(BOOL)shouldFlip
{
	// Convert the given rectangle from points to pixels
	aRect = [view convertRectToBase:aRect];
	
	// Round up the rect's values to integers
	aRect = NSIntegralRect(aRect);
	
	// Add or subtract 0.5 so the lines are drawn within pixel bounds 
	if (isHorizontal)
	{
		if ([view isFlipped])
			aRect.origin.y -= 0.5;
		else
			aRect.origin.y += 0.5;
	}
	else
	{
		aRect.origin.x += 0.5;
	}
	
	NSSize sizeInPixels = aRect.size;
	
	// Convert the rect back to points for drawing
	aRect = [view convertRectFromBase:aRect];
	
	// Flip the position so it's at the other side of the rect
	if (shouldFlip)
	{
		if (isHorizontal)
			posInPixels = sizeInPixels.height - posInPixels - 1;
		else
			posInPixels = sizeInPixels.width - posInPixels - 1;
	}
	
	float posInPoints = posInPixels / [[NSScreen mainScreen] userSpaceScaleFactor];
	float insetInPoints = insetInPixels / [[NSScreen mainScreen] userSpaceScaleFactor];
	
	// Calculate line start and end points
	float startX, startY, endX, endY;
	
	if (isHorizontal)
	{
		startX = aRect.origin.x + insetInPoints;
		startY = aRect.origin.y + posInPoints;
		endX   = aRect.origin.x + aRect.size.width - insetInPoints;
		endY   = aRect.origin.y + posInPoints;
	}
	else
	{
		startX = aRect.origin.x + posInPoints;
		startY = aRect.origin.y + insetInPoints;
		endX   = aRect.origin.x + posInPoints;
		endY   = aRect.origin.y + aRect.size.height - insetInPoints;
	}
	
	// Draw line
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path setLineWidth:0.0f];
	[path moveToPoint:NSMakePoint(startX,startY)];
	[path lineToPoint:NSMakePoint(endX,endY)];
	[self set];
	[path stroke];
}

@end
