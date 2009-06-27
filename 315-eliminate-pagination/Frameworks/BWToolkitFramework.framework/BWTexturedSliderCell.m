//
//  BWTexturedSliderCell.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWTexturedSliderCell.h"

@implementation BWTexturedSliderCell
@synthesize trackHeight;

static NSImage *trackLeftImage, *trackFillImage, *trackRightImage, *thumbPImage, *thumbNImage;

+ (void)initialize 
{
	if([BWTexturedSliderCell class] == [self class])
	{
		NSBundle *bundle = [NSBundle bundleForClass:[BWTexturedSliderCell class]];

		trackLeftImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"TexturedSliderTrackLeft.tiff"]];
		trackFillImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"TexturedSliderTrackFill.tiff"]];
		trackRightImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"TexturedSliderTrackRight.tiff"]];
		thumbPImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"TexturedSliderThumbP.tiff"]];
		thumbNImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"TexturedSliderThumbN.tiff"]];
	}
}

- (id)initWithCoder:(NSCoder *)decoder;
{
    if ((self = [super initWithCoder:decoder]) != nil)
	{
		[self setTrackHeight:[decoder decodeBoolForKey:@"BWTSTrackHeight"]];
		[self setControlSize:NSSmallControlSize];
		isPressed = NO;
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [super encodeWithCoder:coder];
	
	[coder encodeBool:[self trackHeight] forKey:@"BWTSTrackHeight"];
}
	
- (NSControlSize)controlSize
{
	return NSRegularControlSize;
}

- (void)setControlSize:(NSControlSize)size
{
	
}

- (NSInteger)numberOfTickMarks
{
	return 0;
}

- (void)setNumberOfTickMarks:(NSInteger)numberOfTickMarks
{
	
}

- (void)drawBarInside:(NSRect)cellFrame flipped:(BOOL)flipped
{	
	NSRect slideRect = cellFrame;
	
	if (trackHeight == 0)
		slideRect.size.height = trackFillImage.size.height;
	else
		slideRect.size.height = trackFillImage.size.height + 1;
	
	slideRect.origin.y += roundf((cellFrame.size.height - slideRect.size.height) / 2);

	// Inset the bar so the knob goes all the way to both ends
	slideRect.size.width -= 9;
	slideRect.origin.x += 5;

	if ([self isEnabled])
		NSDrawThreePartImage(slideRect, trackLeftImage, trackFillImage, trackRightImage, NO, NSCompositeSourceOver, 1, flipped);
	else
		NSDrawThreePartImage(slideRect, trackLeftImage, trackFillImage, trackRightImage, NO, NSCompositeSourceOver, 0.5, flipped);
}

- (void)drawKnob:(NSRect)rect
{
	NSImage *drawImage;
	
	if (isPressed)
		drawImage = thumbPImage;
	else
		drawImage = thumbNImage;
	
	NSPoint drawPoint;
	drawPoint.x = rect.origin.x + roundf((rect.size.width - drawImage.size.width) / 2);
	drawPoint.y = NSMaxY(rect) - roundf((rect.size.height - drawImage.size.height) / 2);
	
	if (trackHeight == 0)
		drawPoint.y++;
	
	[drawImage compositeToPoint:drawPoint operation:NSCompositeSourceOver];
}

- (BOOL)_usesCustomTrackImage
{
	return YES;
}

- (BOOL)startTrackingAt:(NSPoint)startPoint inView:(NSView *)controlView
{
	isPressed = YES;
	return [super startTrackingAt:startPoint inView:controlView];	
}

- (void)stopTracking:(NSPoint)lastPoint at:(NSPoint)stopPoint inView:(NSView *)controlView mouseIsUp:(BOOL)flag
{
	isPressed = NO;
	[super stopTracking:(NSPoint)lastPoint at:(NSPoint)stopPoint inView:(NSView *)controlView mouseIsUp:(BOOL)flag];
}

@end
