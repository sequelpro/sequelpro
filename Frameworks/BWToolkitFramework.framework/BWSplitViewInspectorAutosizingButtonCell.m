//
//  BWSplitViewInspectorAutosizingButtonCell.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWSplitViewInspectorAutosizingButtonCell.h"
#import "BWSplitViewInspectorAutosizingView.h"
#import "NSColor+BWAdditions.h"
#import "NSImage+BWAdditions.h"
#import "NSApplication+BWAdditions.h"
#import "IBColor.h"

static NSColor *insetColor, *borderColor, *viewColor, *lineColor, *insetLineColor;
static NSImage *blueArrowStart, *blueArrowEnd, *redArrowStart, *redArrowEnd, *redArrowFill;
static float interiorInset = 7.0;

@implementation BWSplitViewInspectorAutosizingButtonCell

+ (void)initialize
{
	insetColor = [IBColor customViewLightBorderColor];
	borderColor = [IBColor customViewDarkBorderColor];
	
	// Note: These two colors are reversed in IBColor in 10.5
	if ([NSApplication isOnLeopard])
		viewColor = [IBColor containerCustomViewBackgroundColor];
	else
		viewColor = [IBColor childlessCustomViewBackgroundColor];
	
	lineColor = [[NSColor colorWithCalibratedRed:124.0/255.0 green:139.0/255.0 blue:159.0/255.0 alpha:1.0] retain];
	insetLineColor = [[[NSColor whiteColor] colorWithAlphaComponent:0.19] retain];
	
	NSBundle *bundle = [NSBundle bundleForClass:[BWSplitViewInspectorAutosizingButtonCell class]];
	blueArrowStart = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"Inspector-SplitViewArrowBlueLeft.tif"]];
	blueArrowEnd = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"Inspector-SplitViewArrowBlueRight.tif"]];
	redArrowStart = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"Inspector-SplitViewArrowRedLeft.tif"]];
	redArrowFill = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"Inspector-SplitViewArrowRedFill.tif"]];
	redArrowEnd = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"Inspector-SplitViewArrowRedRight.tif"]];
}

- (void)drawBezelWithFrame:(NSRect)frame inView:(NSView *)controlView
{
	[viewColor set];
	NSRectFillUsingOperation(frame,NSCompositeSourceOver);

	[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:frame inView:controlView horizontal:NO flip:NO];
	[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:frame inView:controlView horizontal:NO flip:YES];
	[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:frame inView:controlView horizontal:YES flip:YES];
	[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:frame inView:controlView horizontal:YES flip:NO];
	
	[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:frame inView:controlView horizontal:NO flip:NO];
	[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:frame inView:controlView horizontal:NO flip:YES];
	[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:frame inView:controlView horizontal:YES flip:YES];
	[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:frame inView:controlView horizontal:YES flip:NO];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	BOOL isVertical = [(BWSplitViewInspectorAutosizingView *)[controlView superview] isVertical];
	NSImage *blueArrowStartCap, *blueArrowEndCap, *redArrowStartCap, *redArrowFillSlice, *redArrowEndCap;
	
	if (isVertical)
	{
		blueArrowStartCap = blueArrowStart;
		blueArrowEndCap = blueArrowEnd;
		redArrowStartCap = redArrowStart;
		redArrowFillSlice = redArrowFill;
		redArrowEndCap = redArrowEnd;
		
		[blueArrowStartCap setFlipped:YES];
		[blueArrowEndCap setFlipped:YES];
	}
	else
	{
		blueArrowStartCap = [blueArrowStart rotateImage90DegreesClockwise:NO];
		blueArrowEndCap = [blueArrowEnd rotateImage90DegreesClockwise:NO];
		redArrowStartCap = [redArrowEnd rotateImage90DegreesClockwise:NO];
		redArrowFillSlice = [redArrowFill rotateImage90DegreesClockwise:NO];
		redArrowEndCap = [redArrowStart rotateImage90DegreesClockwise:NO];
	}
	
	float arrowHeight = [blueArrowStartCap size].height;
	float arrowWidth = [blueArrowStartCap size].width;
	
	NSRect arrowRect = NSZeroRect;
	
	if (isVertical)
		arrowRect = NSMakeRect(interiorInset, roundf(cellFrame.size.height / 2 - 0.5 * arrowHeight), roundf(cellFrame.size.width - interiorInset * 2), arrowHeight);
	else
		arrowRect = NSMakeRect(roundf(cellFrame.size.width / 2 - 0.5 * arrowWidth), interiorInset - 1, arrowWidth, roundf(cellFrame.size.height - (interiorInset - 1) * 2));
	
	if ([self intValue] == 0)
	{
		NSPoint startArrowOrigin = arrowRect.origin;
		NSPoint endArrowOrigin;
		
		if (isVertical)
			endArrowOrigin = NSMakePoint(NSMaxX(arrowRect) - arrowWidth, arrowRect.origin.y);
		else
			endArrowOrigin = NSMakePoint(arrowRect.origin.x,NSMaxY(arrowRect) - arrowHeight);
		
		[blueArrowStartCap drawAtPoint:startArrowOrigin fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
		[blueArrowEndCap drawAtPoint:endArrowOrigin fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
		
		NSPoint startPoint, endPoint;
		
		if (isVertical)
		{
			startPoint = NSMakePoint(arrowRect.origin.x + arrowWidth, arrowRect.origin.y + floorf(arrowHeight / 2) + 0.5);
			endPoint = NSMakePoint(arrowRect.origin.x + arrowRect.size.width - arrowWidth, arrowRect.origin.y + floorf(arrowHeight / 2) + 0.5);
		}
		else
		{
			startPoint = NSMakePoint(arrowRect.origin.x + floorf(arrowWidth / 2) + 0.5, arrowRect.origin.y + arrowHeight);
			endPoint = NSMakePoint(arrowRect.origin.x + floorf(arrowWidth / 2) + 0.5, NSMaxY(arrowRect) - arrowHeight);
		}

		CGFloat array[2] = {3.0, 1.0};
		
		// Draw dashed line
		NSBezierPath *dashedLine = [NSBezierPath bezierPath];
		[dashedLine setLineWidth:1.0];
		[dashedLine setLineDash:array count:2 phase:3.0];
		[dashedLine moveToPoint:startPoint];
		[dashedLine lineToPoint:endPoint];
		[lineColor set];
		[dashedLine stroke];
		
		// Draw white dashed inset line
		NSBezierPath *dashedInsetLine = [NSBezierPath bezierPath];
		[dashedInsetLine setLineWidth:1.0];
		[dashedInsetLine setLineDash:array count:2 phase:3.0];
		if (isVertical)
		{
			[dashedInsetLine moveToPoint:NSMakePoint(startPoint.x, startPoint.y + 1)];
			[dashedInsetLine lineToPoint:NSMakePoint(endPoint.x, endPoint.y + 1)];
		}
		else
		{
			[dashedInsetLine moveToPoint:NSMakePoint(startPoint.x + 1, startPoint.y)];
			[dashedInsetLine lineToPoint:NSMakePoint(endPoint.x + 1, endPoint.y)];
		}
		[insetLineColor set];
		[dashedInsetLine stroke];
	}
	else
	{
		if (isVertical)
			NSDrawThreePartImage(arrowRect, redArrowStartCap, redArrowFillSlice, redArrowEndCap, NO, NSCompositeSourceOver, 1, YES);
		else
			NSDrawThreePartImage(arrowRect, redArrowStartCap, redArrowFillSlice, redArrowEndCap, YES, NSCompositeSourceOver, 1, YES);
	}
}

@end
