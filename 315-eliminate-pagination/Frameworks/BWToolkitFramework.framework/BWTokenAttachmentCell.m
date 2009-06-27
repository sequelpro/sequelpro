//
//  BWTokenAttachmentCell.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWTokenAttachmentCell.h"

static NSGradient *blueGradient, *blueStrokeGradient, *blueInsetGradient, *highlightedBlueGradient, *highlightedBlueStrokeGradient, *highlightedBlueInsetGradient, *arrowGradient;
static NSShadow *textShadow;
static NSColor *highlightedArrowColor;

static float arrowWidth = 7.0;
static float arrowHeight = 6.0;

@interface NSTokenAttachmentCell (BWTACPrivate)
- (NSDictionary *)_textAttributes;
@end

@interface BWTokenAttachmentCell (BWTACPrivate)
+ (NSImage *)arrowInHighlightedState:(BOOL)isHighlighted;
@end

@implementation BWTokenAttachmentCell

+ (void)initialize
{
	NSColor *blueTopColor = [NSColor colorWithCalibratedRed:217.0/255.0 green:228.0/255.0 blue:254.0/255.0 alpha:1];
	NSColor *blueBottomColor = [NSColor colorWithCalibratedRed:195.0/255.0 green:212.0/255.0 blue:250.0/255.0 alpha:1];	
	blueGradient = [[NSGradient alloc] initWithStartingColor:blueTopColor endingColor:blueBottomColor];
	
	NSColor *blueStrokeTopColor = [NSColor colorWithCalibratedRed:164.0/255.0 green:184.0/255.0 blue:230.0/255.0 alpha:1];
	NSColor *blueStrokeBottomColor = [NSColor colorWithCalibratedRed:122.0/255.0 green:128.0/255.0 blue:199.0/255.0 alpha:1];
	blueStrokeGradient = [[NSGradient alloc] initWithStartingColor:blueStrokeTopColor endingColor:blueStrokeBottomColor];

	NSColor *blueInsetTopColor = [NSColor colorWithCalibratedRed:226.0/255.0 green:234.0/255.0 blue:254.0/255.0 alpha:1];
	NSColor *blueInsetBottomColor = [NSColor colorWithCalibratedRed:206.0/255.0 green:221.0/255.0 blue:250.0/255.0 alpha:1];
	blueInsetGradient = [[NSGradient alloc] initWithStartingColor:blueInsetTopColor endingColor:blueInsetBottomColor];
	
	NSColor *highlightedBlueTopColor = [NSColor colorWithCalibratedRed:80.0/255.0 green:127.0/255.0 blue:251.0/255.0 alpha:1];
	NSColor *highlightedBlueBottomColor = [NSColor colorWithCalibratedRed:65.0/255.0 green:107.0/255.0 blue:236.0/255.0 alpha:1];	
	highlightedBlueGradient = [[NSGradient alloc] initWithStartingColor:highlightedBlueTopColor endingColor:highlightedBlueBottomColor];	

	NSColor *highlightedBlueStrokeTopColor = [NSColor colorWithCalibratedRed:51.0/255.0 green:95.0/255.0 blue:248.0/255.0 alpha:1];
	NSColor *highlightedBlueStrokeBottomColor = [NSColor colorWithCalibratedRed:42.0/255.0 green:47.0/255.0 blue:233.0/255.0 alpha:1];
	highlightedBlueStrokeGradient = [[NSGradient alloc] initWithStartingColor:highlightedBlueStrokeTopColor endingColor:highlightedBlueStrokeBottomColor];

	NSColor *highlightedBlueInsetTopColor = [NSColor colorWithCalibratedRed:92.0/255.0 green:137.0/255.0 blue:251.0/255.0 alpha:1];
	NSColor *highlightedBlueInsetBottomColor = [NSColor colorWithCalibratedRed:76.0/255.0 green:116.0/255.0 blue:236.0/255.0 alpha:1];
	highlightedBlueInsetGradient = [[NSGradient alloc] initWithStartingColor:highlightedBlueInsetTopColor endingColor:highlightedBlueInsetBottomColor];
	
	NSColor *arrowGradientTopColor = [NSColor colorWithCalibratedRed:111.0/255.0 green:140.0/255.0 blue:222.0/255.0 alpha:1];
	NSColor *arrowGradientBottomColor = [NSColor colorWithCalibratedRed:58.0/255.0 green:91.0/255.0 blue:203.0/255.0 alpha:1];
	arrowGradient = [[NSGradient alloc] initWithStartingColor:arrowGradientTopColor endingColor:arrowGradientBottomColor];
	
	textShadow = [[NSShadow alloc] init];
	[textShadow setShadowOffset:NSMakeSize(0,1 / [[NSScreen mainScreen] userSpaceScaleFactor])];
	[textShadow setShadowColor:[[NSColor blackColor] colorWithAlphaComponent:0.3]];
	
	highlightedArrowColor = [[NSColor colorWithCalibratedRed:246.0/255.0 green:249.0/255.0 blue:254.0/255.0 alpha:1] retain];
}

- (NSImage *)arrowInHighlightedState:(BOOL)isHighlighted
{
	float scaleFactor = [[NSScreen mainScreen] userSpaceScaleFactor];
	
	NSImage *arrowImage = [[[NSImage alloc] init] autorelease];
	[arrowImage setSize:NSMakeSize(arrowWidth, arrowHeight)];
	[arrowImage setFlipped:YES];
	
	[arrowImage lockFocus];
	
	NSPoint p1 = NSMakePoint(0,0);
	NSPoint p2 = NSMakePoint(arrowWidth,0);
	NSPoint p3 = NSMakePoint(arrowWidth / 2, arrowHeight - 1 / scaleFactor);
	
	NSBezierPath *triangle = [NSBezierPath bezierPath];
	[triangle moveToPoint:p1];
	[triangle lineToPoint:p2];
	[triangle lineToPoint:p3];
	[triangle lineToPoint:p1];
	
	p1 = NSMakePoint(0, 1 / scaleFactor);
	p2 = NSMakePoint(arrowWidth, 1 / scaleFactor);
	p3 = NSMakePoint(arrowWidth / 2, arrowHeight);
	
	NSBezierPath *triangle2 = [NSBezierPath bezierPath];
	[triangle2 moveToPoint:p1];
	[triangle2 lineToPoint:p2];
	[triangle2 lineToPoint:p3];
	[triangle2 lineToPoint:p1];
	
	if (isHighlighted)
	{
		// Draw shadow	
		[[[NSColor blackColor] colorWithAlphaComponent:0.2] set];
		[triangle fill];
		
		// Draw arrow
		[highlightedArrowColor set];
		[triangle2 fill];
	}
	else
	{
		// Draw shadow	
		[[[NSColor whiteColor] colorWithAlphaComponent:0.75] set];
		[triangle2 fill];
		
		// Draw arrow
		[arrowGradient drawInBezierPath:triangle angle:90];	
	}

	[arrowImage unlockFocus];
	
	return arrowImage;
}

- (void)drawTokenWithFrame:(NSRect)aRect inView:(NSView *)aView;
{
	float scaleFactor = [[NSScreen mainScreen] userSpaceScaleFactor];
	
	NSRect drawingRect = [self drawingRectForBounds:aRect];
	NSRect insetRect = NSInsetRect(drawingRect, 1 / scaleFactor, 1 / scaleFactor);
	NSRect insetRect2 = NSInsetRect(insetRect, 1 / scaleFactor, 1 / scaleFactor);
	
	if (scaleFactor < 0.99 || scaleFactor > 1.01)
	{
		drawingRect = [aView centerScanRect:drawingRect];
		insetRect = [aView centerScanRect:insetRect];
		insetRect2 = [aView centerScanRect:insetRect2];		
	}

	NSBezierPath *drawingPath = [NSBezierPath bezierPathWithRoundedRect:drawingRect xRadius:0.5*drawingRect.size.height yRadius:0.5*drawingRect.size.height];
	NSBezierPath *insetPath = [NSBezierPath bezierPathWithRoundedRect:insetRect xRadius:0.5*insetRect.size.height yRadius:0.5*insetRect.size.height];
	NSBezierPath *insetPath2 = [NSBezierPath bezierPathWithRoundedRect:insetRect2 xRadius:0.5*insetRect2.size.height yRadius:0.5*insetRect2.size.height];
	
	if (_tacFlags._selected == NO)
	{
		[blueStrokeGradient drawInBezierPath:drawingPath angle:90];
		[blueInsetGradient drawInBezierPath:insetPath angle:90];
		[blueGradient drawInBezierPath:insetPath2 angle:90];
	}
	else
	{
		[highlightedBlueStrokeGradient drawInBezierPath:drawingPath angle:90];
		[highlightedBlueInsetGradient drawInBezierPath:insetPath angle:90];
		[highlightedBlueGradient drawInBezierPath:insetPath2 angle:90];
	}

	// Darken on mouse over
	CGFloat red, blue, green, alpha;
	[[self tokenBackgroundColor] getRed:&red green:&green blue:&blue alpha:&alpha];
	
	if (red > 0.427 && red < 0.428)
	{
		[[NSColor colorWithCalibratedRed:32.0/255.0 green:59.0/255.0 blue:167.0/255.0 alpha:0.1] set];
		
		[NSGraphicsContext saveGraphicsState];
		[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositePlusDarker];
		[drawingPath fill];
		[NSGraphicsContext restoreGraphicsState];
	}
		
}

- (int)interiorBackgroundStyle
{
	// If the token isn't selected, tell NSCell to draw a white shadow below the text
	if (_tacFlags._selected == NO)
		return NSBackgroundStyleRaised;
	
	return [super interiorBackgroundStyle];
}

- (NSDictionary *)_textAttributes
{
	if (_tacFlags._selected)
	{	
		NSMutableDictionary *attributes = [[[NSMutableDictionary alloc] init] autorelease];
		[attributes addEntriesFromDictionary:[super _textAttributes]];
		[attributes setObject:textShadow forKey:NSShadowAttributeName];
		
		return attributes;
	}
	
	return [super _textAttributes];
}

- (id)pullDownImage
{
	NSImage *arrowImage;
	
	if (_tacFlags._selected)
		arrowImage = [self arrowInHighlightedState:YES];
	else
		arrowImage = [self arrowInHighlightedState:NO];
	
	return arrowImage;
}

- (NSRect)pullDownRectForBounds:(NSRect)bounds
{
	NSRect pullDownRect = [super pullDownRectForBounds:bounds];
	
	pullDownRect.origin.x--;
	
	if (!_tacFlags._selected)
		pullDownRect.origin.y++;
	
	float scaleFactor = [[NSScreen mainScreen] userSpaceScaleFactor];

	if (scaleFactor < 0.99 || scaleFactor > 1.01)
		pullDownRect = [[self controlView] centerScanRect:pullDownRect];
	
	return pullDownRect;
}

// --- For testing menu arrows ---
//- (BOOL)_hasMenu
//{
//	return YES;
//}

@end
