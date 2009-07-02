//
//  BWUnanchoredButtonCell.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWUnanchoredButtonCell.h"
#import "BWUnanchoredButton.h"
#import "NSColor+BWAdditions.h"

static NSColor *fillStop1, *fillStop2, *fillStop3, *fillStop4;
static NSColor *borderColor, *topBorderColor, *bottomInsetColor, *topInsetColor, *pressedColor;
static NSGradient *fillGradient;

@interface BWAnchoredButtonCell (BWUBCPrivate)
- (void)drawTitleInFrame:(NSRect)cellFrame;
- (void)drawImageInFrame:(NSRect)cellFrame;
@end

@implementation BWUnanchoredButtonCell

+ (void)initialize;
{
    fillStop1			= [[NSColor colorWithCalibratedWhite:(251.0f / 255.0f) alpha:1] retain];
    fillStop2			= [[NSColor colorWithCalibratedWhite:(251.0f / 255.0f) alpha:1] retain];
    fillStop3			= [[NSColor colorWithCalibratedWhite:(236.0f / 255.0f) alpha:1] retain];
	fillStop4			= [[NSColor colorWithCalibratedWhite:(243.0f / 255.0f) alpha:1] retain];
	
    fillGradient		= [[NSGradient alloc] initWithColorsAndLocations:
						   fillStop1, (CGFloat)0.0,
						   fillStop2, (CGFloat)0.5,
						   fillStop3, (CGFloat)0.5,
						   fillStop4, (CGFloat)1.0,
						   nil];
	
	topBorderColor		= [[NSColor colorWithCalibratedWhite:(126.0f / 255.0f) alpha:1] retain];
	borderColor			= [[NSColor colorWithCalibratedWhite:(151.0f / 255.0f) alpha:1] retain];
	
	topInsetColor		= [[NSColor colorWithCalibratedWhite:(0.0f / 255.0f) alpha:0.08] retain];
	bottomInsetColor	= [[NSColor colorWithCalibratedWhite:(255.0f / 255.0f) alpha:0.54] retain];
	
	pressedColor		= [[NSColor colorWithCalibratedWhite:(0.0f / 255.0f) alpha:0.3] retain];
}


- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	[fillGradient drawInRect:NSInsetRect(cellFrame, 0, 2) angle:90];
	
	[topInsetColor drawPixelThickLineAtPosition:0 withInset:0 inRect:cellFrame inView:[self controlView] horizontal:YES flip:NO];	
	[topBorderColor drawPixelThickLineAtPosition:1 withInset:0 inRect:cellFrame inView:[self controlView] horizontal:YES flip:NO];
	[borderColor drawPixelThickLineAtPosition:1 withInset:0 inRect:cellFrame inView:[self controlView] horizontal:YES flip:YES];
	[bottomInsetColor drawPixelThickLineAtPosition:0 withInset:0 inRect:cellFrame inView:[self controlView] horizontal:YES flip:YES];
	
	[borderColor drawPixelThickLineAtPosition:0 withInset:2 inRect:cellFrame inView:[self controlView] horizontal:NO flip:YES];
	[borderColor drawPixelThickLineAtPosition:0 withInset:2 inRect:cellFrame inView:[self controlView] horizontal:NO flip:NO];

	if ([self image] == nil)
	{
		NSRect titleRect = cellFrame;
		titleRect.size.height -= 4;
		[super drawTitleInFrame:titleRect];
	}
	else
		[super drawImageInFrame:cellFrame];
	
	if ([self isHighlighted])
	{
		[pressedColor set];
		NSRectFillUsingOperation(NSInsetRect(cellFrame,0,1), NSCompositeSourceOver);
	}
}


@end
