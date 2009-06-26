//
//  BWGradientWell.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWGradientWell.h"

static NSColor *borderColor;
static NSImage *pattern;

@implementation BWGradientWell

@synthesize startingColorWell, endingColorWell;

+ (void)initialize
{
	borderColor = [[NSColor colorWithCalibratedWhite:(121.0 / 255.0) alpha:1] retain];
	
	NSBundle *bundle = [NSBundle bundleForClass:[BWGradientWell class]];
	pattern = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"GradientWellPattern.tif"]];
}

- (void)drawRect:(NSRect)rect
{
	NSRect insetRect = NSInsetRect(self.bounds, 2, 2);
	
	[pattern drawAtPoint:insetRect.origin fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
	
	NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[startingColorWell color] endingColor:[endingColorWell color]];
	[gradient drawInRect:insetRect angle:0];
	[gradient release];
							
	[borderColor set];
	NSFrameRect(self.bounds);
}

@end
