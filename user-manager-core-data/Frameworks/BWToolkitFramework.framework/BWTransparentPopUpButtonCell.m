//
//  BWTransparentPopUpButtonCell.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWTransparentPopUpButtonCell.h"
#import "NSImage+BWAdditions.h"

static NSImage *popUpFillN, *popUpFillP, *popUpRightN, *popUpRightP, *popUpLeftN, *popUpLeftP, *pullDownRightN, *pullDownRightP;
static NSColor *disabledColor, *enabledColor;

@interface NSCell (BWTPUBCPrivate)
- (NSDictionary *)_textAttributes;
@end

@interface BWTransparentPopUpButtonCell (BWTPUBCPrivate)
- (NSColor *)interiorColor;
@end

@implementation BWTransparentPopUpButtonCell

+ (void)initialize;
{
	NSBundle *bundle = [NSBundle bundleForClass:[BWTransparentPopUpButtonCell class]];
	
	popUpFillN = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"TransparentPopUpFillN.tiff"]];
	popUpFillP = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"TransparentPopUpFillP.tiff"]];
	popUpRightN = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"TransparentPopUpRightN.tiff"]];
	popUpRightP = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"TransparentPopUpRightP.tiff"]];
	popUpLeftN = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"TransparentPopUpLeftN.tiff"]];
	popUpLeftP = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"TransparentPopUpLeftP.tiff"]];
	pullDownRightN = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"TransparentPopUpPullDownRightN.tif"]];
	pullDownRightP = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"TransparentPopUpPullDownRightP.tif"]];
	
	enabledColor = [[NSColor whiteColor] retain];
	disabledColor = [[NSColor colorWithCalibratedWhite:0.6 alpha:1] retain];
}

- (void)drawBezelWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	cellFrame.size.height = popUpFillN.size.height;
	
	if ([self isHighlighted])
	{
		if ([self pullsDown])
			NSDrawThreePartImage(cellFrame, popUpLeftP, popUpFillP, pullDownRightP, NO, NSCompositeSourceOver, 1, YES);
		else
			NSDrawThreePartImage(cellFrame, popUpLeftP, popUpFillP, popUpRightP, NO, NSCompositeSourceOver, 1, YES);
	}
	else
	{
		if ([self pullsDown])
			NSDrawThreePartImage(cellFrame, popUpLeftN, popUpFillN, pullDownRightN, NO, NSCompositeSourceOver, 1, YES);
		else
			NSDrawThreePartImage(cellFrame, popUpLeftN, popUpFillN, popUpRightN, NO, NSCompositeSourceOver, 1, YES);
	}
}

- (void)drawImageWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{	
	NSImage *image = [self image];
	
	if (image != nil)
	{
		[image setScalesWhenResized:NO];

		if ([[image name] isEqualToString:@"NSActionTemplate"])
			[image setSize:NSMakeSize(10,10)];
		
		NSImage *newImage = image;
		
		if ([image isTemplate])
			newImage = [image tintedImageWithColor:[self interiorColor]];

		NSAffineTransform* xform = [NSAffineTransform transform];
		[xform translateXBy:0.0 yBy:cellFrame.size.height];
		[xform scaleXBy:1.0 yBy:-1.0];
		[xform concat];
		
		[newImage drawInRect:[self imageRectForBounds:cellFrame] fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
		
		NSAffineTransform* xform2 = [NSAffineTransform transform];
		[xform2 translateXBy:0.0 yBy:cellFrame.size.height];
		[xform2 scaleXBy:1.0 yBy:-1.0];
		[xform2 concat];
	}	
}

- (NSRect)imageRectForBounds:(NSRect)bounds;
{
	NSRect rect = [super imageRectForBounds:bounds];
	
	rect.origin.y += 3;
	
	if ([self imagePosition] == NSImageOnly || [self imagePosition] == NSImageOverlaps || [self imagePosition] == NSImageAbove || [self imagePosition] == NSImageBelow)
	{
		rect.origin.x += 4;
	}
	else if ([self imagePosition] == NSImageRight)
	{
		rect.origin.x += 3;
	}
	else if ([self imagePosition] == NSImageLeft || [self imagePosition] == NSNoImage)
	{
		rect.origin.x -= 1;
	}
	
	return rect;
}

- (NSRect)titleRectForBounds:(NSRect)cellFrame
{
	NSRect titleRect = [super titleRectForBounds:cellFrame];
	
	titleRect.origin.y -= 1;
	titleRect.origin.x -= 2;
	titleRect.size.width += 6;
	
	if ([self image] != nil)
	{
		if ([self imagePosition] == NSImageOnly || [self imagePosition] == NSImageOverlaps || [self imagePosition] == NSImageAbove || [self imagePosition] == NSImageBelow)
		{
			
		}
		else if ([self imagePosition] == NSImageRight)
		{
			if ([self alignment] == NSRightTextAlignment)
				titleRect.origin.x -= 3;
		}
		else if ([self imagePosition] == NSImageLeft || [self imagePosition] == NSNoImage)
		{
			titleRect.origin.x += 2;
		}
	}
		
	return titleRect;
}

- (NSDictionary *)_textAttributes
{
	NSMutableDictionary *attributes = [[[NSMutableDictionary alloc] init] autorelease];
	[attributes addEntriesFromDictionary:[super _textAttributes]];
	[attributes setObject:[NSFont systemFontOfSize:11] forKey:NSFontAttributeName];
	[attributes setObject:[self interiorColor] forKey:NSForegroundColorAttributeName];
	
	return attributes;
}

- (NSColor *)interiorColor
{
	NSColor *interiorColor;
	
	if ([self isEnabled])
		interiorColor = enabledColor;
	else
		interiorColor = disabledColor;
	
	return interiorColor;
}

- (NSControlSize)controlSize
{
	return NSSmallControlSize;
}

- (void)setControlSize:(NSControlSize)size
{
	
}

@end
