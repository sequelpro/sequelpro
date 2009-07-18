//
//  BWAnchoredButtonCell.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWAnchoredButtonCell.h"
#import "BWAnchoredButtonBar.h"
#import "BWAnchoredButton.h"
#import "NSColor+BWAdditions.h"
#import "NSImage+BWAdditions.h"

static NSColor *fillStop1, *fillStop2, *fillStop3, *fillStop4;
static NSColor *topBorderColor, *bottomBorderColor, *sideBorderColor, *sideInsetColor, *pressedColor;
static NSColor *textColor, *textShadowColor, *imageColor, *imageShadowColor;
static NSColor *borderedSideBorderColor, *borderedTopBorderColor;
static NSGradient *fillGradient;
static float scaleFactor = 1.0f;

@interface BWAnchoredButtonCell (BWABCPrivate)
- (void)drawTitleInFrame:(NSRect)cellFrame;
- (void)drawImageInFrame:(NSRect)cellFrame;
@end

@implementation BWAnchoredButtonCell

+ (void)initialize;
{
    fillStop1			= [[NSColor colorWithCalibratedWhite:(253.0f / 255.0f) alpha:1] retain];
    fillStop2			= [[NSColor colorWithCalibratedWhite:(242.0f / 255.0f) alpha:1] retain];
    fillStop3			= [[NSColor colorWithCalibratedWhite:(230.0f / 255.0f) alpha:1] retain];
	fillStop4			= [[NSColor colorWithCalibratedWhite:(230.0f / 255.0f) alpha:1] retain];
	
    fillGradient		= [[NSGradient alloc] initWithColorsAndLocations:
						   fillStop1, (CGFloat)0.0,
						   fillStop2, (CGFloat)0.45454,
						   fillStop3, (CGFloat)0.45454,
						   fillStop4, (CGFloat)1.0,
						   nil];
	
	topBorderColor		= [[NSColor colorWithCalibratedWhite:(202.0f / 255.0f) alpha:1] retain];
	bottomBorderColor	= [[NSColor colorWithCalibratedWhite:(170.0f / 255.0f) alpha:1] retain];
	sideBorderColor		= [[NSColor colorWithCalibratedWhite:(0.0f / 255.0f) alpha:0.2] retain];
	sideInsetColor		= [[NSColor colorWithCalibratedWhite:(255.0f / 255.0f) alpha:0.5] retain];
	
	pressedColor		= [[NSColor colorWithCalibratedWhite:(0.0f / 255.0f) alpha:0.35] retain];
	
	textColor			= [[NSColor colorWithCalibratedWhite:(10.0f / 255.0f) alpha:1] retain];
	textShadowColor		= [[NSColor colorWithCalibratedWhite:(255.0f / 255.0f) alpha:0.75] retain];
	
	imageColor			= [[NSColor colorWithCalibratedWhite:(72.0f / 255.0f) alpha:1] retain];
	imageShadowColor	= [[NSColor colorWithCalibratedWhite:(240.0f / 255.0f) alpha:1] retain];
	
	borderedSideBorderColor	= [[NSColor colorWithCalibratedWhite:(0.0f / 255.0f) alpha:0.25] retain];
	borderedTopBorderColor	= [[NSColor colorWithCalibratedWhite:(190.0f / 255.0f) alpha:1] retain];

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
		if ([(BWAnchoredButton *)[self controlView] isAtLeftEdgeOfBar])
			[bottomBorderColor drawPixelThickLineAtPosition:0 withInset:1 inRect:cellFrame inView:[self controlView] horizontal:NO flip:NO];
		if ([(BWAnchoredButton *)[self controlView] isAtRightEdgeOfBar])
			[bottomBorderColor drawPixelThickLineAtPosition:0 withInset:1 inRect:cellFrame inView:[self controlView] horizontal:NO flip:YES];
	}
	
	if ([self image] == nil && [self alternateImage] == nil)
		[self drawTitleInFrame:cellFrame];
	else
		[self drawImageInFrame:cellFrame];
		
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
		[self setAttributedTitle:string];

		// Draw title
		NSRect boundingRect = [[self attributedTitle] boundingRectWithSize:cellFrame.size options:0];
		
		NSPoint cellCenter;
		cellCenter.x = cellFrame.size.width / 2;
		cellCenter.y = cellFrame.size.height / 2;
		
		NSPoint drawPoint = cellCenter;
		drawPoint.x -= boundingRect.size.width / 2;
		drawPoint.y -= boundingRect.size.height / 2;
		
		drawPoint.x = roundf(drawPoint.x);
		drawPoint.y = roundf(drawPoint.y);
		
		if (drawPoint.x < 4)
			drawPoint.x = 4;
		
		[[self attributedTitle] drawAtPoint:drawPoint];
	}
}

- (void)drawImageInFrame:(NSRect)cellFrame
{
	NSImage *image;
	
	image = ([self state] == NSOffState || [self alternateImage] == nil ? [self image] : [self alternateImage]);
		
		
	if (image != nil)
	{
		[image setScalesWhenResized:NO];
		NSRect sourceRect = NSZeroRect;
		
		if ([[image name] isEqualToString:@"NSActionTemplate"])
			[image setSize:NSMakeSize(10,10)];

		sourceRect.size = [image size];
		
		NSPoint backgroundCenter;
		backgroundCenter.x = cellFrame.size.width / 2;
		backgroundCenter.y = cellFrame.size.height / 2;
		
		NSPoint drawPoint = backgroundCenter;
		drawPoint.x -= sourceRect.size.width / 2;
		drawPoint.y -= sourceRect.size.height / 2 ;
		
		drawPoint.x = roundf(drawPoint.x);
		drawPoint.y = roundf(drawPoint.y);
		
		NSAffineTransform* xform = [NSAffineTransform transform];
		[xform translateXBy:0.0 yBy:cellFrame.size.height];
		[xform scaleXBy:1.0 yBy:-1.0];
		[xform concat];
		
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
		}
		else
		{
			if ([self isEnabled])
				[image drawAtPoint:drawPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
			else
				[image drawAtPoint:drawPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:0.5];
		}
	}
}

- (NSControlSize)controlSize
{
	return [super controlSize];
}

- (void)setControlSize:(NSControlSize)size
{
	
}

@end
