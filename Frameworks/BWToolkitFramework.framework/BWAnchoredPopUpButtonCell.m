//
//  BWAnchoredPopUpButtonCell.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWAnchoredPopUpButtonCell.h"
#import "BWAnchoredPopUpButton.h"
#import "BWAnchoredButtonBar.h"
#import "NSColor+BWAdditions.h"
#import "NSImage+BWAdditions.h"

#define IMAGE_INSET 8;
#define ARROW_INSET 11;

static NSColor *fillStop1, *fillStop2, *fillStop3, *fillStop4;
static NSColor *topBorderColor, *bottomBorderColor, *sideBorderColor, *sideInsetColor, *pressedColor;
static NSColor *textColor, *textShadowColor, *imageColor, *imageShadowColor;
static NSColor *borderedSideBorderColor, *borderedTopBorderColor;
static NSGradient *fillGradient;
static NSImage *pullDownArrow;
static float scaleFactor = 1.0f;

@interface BWAnchoredPopUpButtonCell (BWAPUBCPrivate)
- (void)drawTitleInFrame:(NSRect)cellFrame;
- (void)drawImageInFrame:(NSRect)cellFrame;
- (void)drawArrowInFrame:(NSRect)cellFrame;
@end

@implementation BWAnchoredPopUpButtonCell

+ (void)initialize;
{
    fillStop1				= [[NSColor colorWithCalibratedWhite:(253.0f / 255.0f) alpha:1] retain];
    fillStop2				= [[NSColor colorWithCalibratedWhite:(242.0f / 255.0f) alpha:1] retain];
    fillStop3				= [[NSColor colorWithCalibratedWhite:(230.0f / 255.0f) alpha:1] retain];
	fillStop4				= [[NSColor colorWithCalibratedWhite:(230.0f / 255.0f) alpha:1] retain];
	
    fillGradient			= [[NSGradient alloc] initWithColorsAndLocations:
							   fillStop1, (CGFloat)0.0,
							   fillStop2, (CGFloat)0.45454,
							   fillStop3, (CGFloat)0.45454,
							   fillStop4, (CGFloat)1.0,
							   nil];
	
	topBorderColor			= [[NSColor colorWithCalibratedWhite:(202.0f / 255.0f) alpha:1] retain];
	bottomBorderColor		= [[NSColor colorWithCalibratedWhite:(170.0f / 255.0f) alpha:1] retain];
	sideBorderColor			= [[NSColor colorWithCalibratedWhite:(0.0f / 255.0f) alpha:0.2] retain];
	sideInsetColor			= [[NSColor colorWithCalibratedWhite:(255.0f / 255.0f) alpha:0.5] retain];
	
	pressedColor			= [[NSColor colorWithCalibratedWhite:(0.0f / 255.0f) alpha:0.35] retain];
	
	textColor				= [[NSColor colorWithCalibratedWhite:(10.0f / 255.0f) alpha:1] retain];
	textShadowColor			= [[NSColor colorWithCalibratedWhite:(255.0f / 255.0f) alpha:0.75] retain];
	
	imageColor				= [[NSColor colorWithCalibratedWhite:(70.0f / 255.0f) alpha:1] retain];
	imageShadowColor		= [[NSColor colorWithCalibratedWhite:(240.0f / 255.0f) alpha:1] retain];
	
	borderedSideBorderColor	= [[NSColor colorWithCalibratedWhite:(0.0f / 255.0f) alpha:0.25] retain];
	borderedTopBorderColor	= [[NSColor colorWithCalibratedWhite:(190.0f / 255.0f) alpha:1] retain];
	
	if([BWAnchoredPopUpButtonCell class] == [self class])
	{
		NSBundle *bundle = [NSBundle bundleForClass:[BWAnchoredPopUpButtonCell class]];
		
		pullDownArrow = [[[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"ButtonBarPullDownArrow.pdf"]] retain];
	}
}

- (void)awakeFromNib
{
	scaleFactor = [[NSScreen mainScreen] userSpaceScaleFactor];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{		
	BOOL inBorderedBar = YES;
	
	if ([[[self controlView] superview] respondsToSelector:@selector(isAtBottom)])
	{
		if ([(BWAnchoredButtonBar *)[[self controlView] superview] isAtBottom])
			inBorderedBar = NO;
	}
	
	[fillGradient drawInRect:cellFrame angle:90];
	
	[bottomBorderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:cellFrame inView:[self controlView] horizontal:YES flip:YES];
	[sideInsetColor drawPixelThickLineAtPosition:1 withInset:1 inRect:cellFrame inView:[self controlView] horizontal:NO flip:NO];
	[sideInsetColor drawPixelThickLineAtPosition:1 withInset:1 inRect:cellFrame inView:[self controlView] horizontal:NO flip:YES];
	
	if (inBorderedBar)
	{
		[borderedTopBorderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:cellFrame inView:[self controlView] horizontal:YES flip:NO];
		[borderedSideBorderColor drawPixelThickLineAtPosition:0 withInset:1 inRect:cellFrame inView:[self controlView] horizontal:NO flip:NO];
		[borderedSideBorderColor drawPixelThickLineAtPosition:0 withInset:1 inRect:cellFrame inView:[self controlView] horizontal:NO flip:YES];
	}
	else
	{
		[topBorderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:cellFrame inView:[self controlView] horizontal:YES flip:NO];
		[sideBorderColor drawPixelThickLineAtPosition:0 withInset:1 inRect:cellFrame inView:[self controlView] horizontal:NO flip:NO];
		[sideBorderColor drawPixelThickLineAtPosition:0 withInset:1 inRect:cellFrame inView:[self controlView] horizontal:NO flip:YES];
	}
	
	if (inBorderedBar && [[self controlView] respondsToSelector:@selector(isAtLeftEdgeOfBar)])
	{
		if ([(BWAnchoredPopUpButton *)[self controlView] isAtLeftEdgeOfBar])
			[bottomBorderColor drawPixelThickLineAtPosition:0 withInset:1 inRect:cellFrame inView:[self controlView] horizontal:NO flip:NO];
		if ([(BWAnchoredPopUpButton *)[self controlView] isAtRightEdgeOfBar])
			[bottomBorderColor drawPixelThickLineAtPosition:0 withInset:1 inRect:cellFrame inView:[self controlView] horizontal:NO flip:YES];
	}
	
	if ([self image] == nil)
		[self drawTitleInFrame:cellFrame];
	else
		[self drawImageInFrame:cellFrame];
	
	[self drawArrowInFrame:cellFrame];
	
	if ([self isHighlighted])
	{
		[pressedColor set];
		NSRectFillUsingOperation(cellFrame, NSCompositeSourceOver);
	}
}

- (void)drawTitleInFrame:(NSRect)cellFrame
{
	if (![[self title] isEqualToString:@""])
	{
		NSColor *localTextColor = textColor;
		
		if (![self isEnabled])
		{
			localTextColor = [textColor colorWithAlphaComponent:0.6];
		}
		
		NSMutableDictionary *attributes = [[[NSMutableDictionary alloc] init] autorelease];
		[attributes addEntriesFromDictionary:[[self attributedTitle] attributesAtIndex:0 effectiveRange:NULL]];
		[attributes setObject:localTextColor forKey:NSForegroundColorAttributeName];
		[attributes setObject:[NSFont systemFontOfSize:11] forKey:NSFontAttributeName];
		
		NSShadow *shadow = [[[NSShadow alloc] init] autorelease];
		[shadow setShadowOffset:NSMakeSize(0,-1)];
		[shadow setShadowColor:textShadowColor];
		[attributes setObject:shadow forKey:NSShadowAttributeName];
		
		NSMutableAttributedString *string = [[[NSMutableAttributedString alloc] initWithString:[self title] attributes:attributes] autorelease];
		
		// Draw title
		NSRect boundingRect = [string boundingRectWithSize:cellFrame.size options:0];
		
		NSPoint cellCenter;
		cellCenter.y = cellFrame.size.height / 2;
		
		NSPoint drawPoint = cellCenter;
		drawPoint.y -= boundingRect.size.height / 2;
		drawPoint.y = roundf(drawPoint.y);
		
		drawPoint.x = IMAGE_INSET;
	
		[string drawAtPoint:drawPoint];
	}
}

- (void)drawImageInFrame:(NSRect)cellFrame
{
	NSImage *image = [self image];
	
	if (image != nil)
	{
		[image setScalesWhenResized:NO];
		NSRect sourceRect = NSZeroRect;
		
		if ([[image name] isEqualToString:@"NSActionTemplate"])
			[image setSize:NSMakeSize(10,10)];
		
		sourceRect.size = [image size];
		
		NSPoint backgroundCenter;
		backgroundCenter.y = cellFrame.size.height / 2;
		
		NSPoint drawPoint = backgroundCenter;
		drawPoint.y -= sourceRect.size.height / 2 ;//+ 0.5;
		drawPoint.y = roundf(drawPoint.y);
		
		drawPoint.x = IMAGE_INSET;
		
		NSAffineTransform* transform = [NSAffineTransform transform];
		[transform translateXBy:0.0 yBy:cellFrame.size.height];
		[transform scaleXBy:1.0 yBy:-1.0];
		[transform concat];
		
		if ([image isTemplate])
		{
			NSImage *glyphImage = [image tintedImageWithColor:imageColor];
			NSImage *shadowImage = [image tintedImageWithColor:imageShadowColor];
			NSPoint shadowPoint = drawPoint;
			shadowPoint.y--;
			
			[shadowImage drawAtPoint:shadowPoint fromRect:sourceRect operation:NSCompositeSourceOver fraction:1];		
			
			if ([self isEnabled])
				[glyphImage drawAtPoint:drawPoint fromRect:sourceRect operation:NSCompositeSourceOver fraction:1];
			else
				[glyphImage	drawAtPoint:drawPoint fromRect:sourceRect operation:NSCompositeSourceOver fraction:0.5];
			
			[transform invert];
			[transform concat];
		}
		else
		{
			if ([self isEnabled])
				[image drawAtPoint:drawPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
			else
				[image drawAtPoint:drawPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:0.5];
			
			// Run the flip transform again so the arrow doesn't draw upside-down
			NSAffineTransform* transform = [NSAffineTransform transform];
			[transform translateXBy:0.0 yBy:cellFrame.size.height];
			[transform scaleXBy:1.0 yBy:-1.0];
			[transform concat];
		}
	}
}
- (void)drawArrowInFrame:(NSRect)cellFrame
{
	if ([self pullsDown])
	{
		NSPoint drawPoint;
		drawPoint.x = NSMaxX(cellFrame) - ARROW_INSET;
		drawPoint.y = roundf(cellFrame.size.height / 2) - 2;

		NSImage *glyphImage = [pullDownArrow tintedImageWithColor:imageColor];
		NSImage *shadowImage = [pullDownArrow tintedImageWithColor:imageShadowColor];
		NSPoint shadowPoint = drawPoint;
		shadowPoint.y--;
		
		NSAffineTransform* transform = [NSAffineTransform transform];
		[transform translateXBy:0.0 yBy:cellFrame.size.height];
		[transform scaleXBy:1.0 yBy:-1.0];
		[transform concat];
		
		[shadowImage drawAtPoint:shadowPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
		
		if ([self isEnabled])
			[glyphImage drawAtPoint:drawPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
		else
			[glyphImage drawAtPoint:drawPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:0.5];
		
		[transform invert];
		[transform concat];
	}
	else
	{
		// Doesn't support pop-up style yet
	}
}

- (NSControlSize)controlSize
{
	return NSSmallControlSize;
}

- (void)setControlSize:(NSControlSize)size
{
	
}

@end