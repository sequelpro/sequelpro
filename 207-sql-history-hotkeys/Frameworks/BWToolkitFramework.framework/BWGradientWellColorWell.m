//
//  BWGradientWellColorWell.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWGradientWellColorWell.h"

static NSColor *borderColor;
static float bezelThickness = 2;

@implementation BWGradientWellColorWell

@synthesize gradientWell;

+ (void)initialize
{
	borderColor = [[NSColor colorWithCalibratedWhite:(66.0 / 255.0) alpha:1] retain];
}

- (void)drawRect:(NSRect)rect
{
	[super drawRect:rect];
	
	[borderColor set];
	NSFrameRect(self.bounds);
	
	[borderColor drawSwatchInRect:NSInsetRect(self.bounds, bezelThickness + 1, bezelThickness + 1)];

	[[self color] drawSwatchInRect:NSInsetRect(self.bounds, bezelThickness + 2, bezelThickness + 2)];
}

- (void)setColor:(NSColor *)color
{
	[gradientWell setNeedsDisplay:YES];

	[super setColor:color];
}

@end
