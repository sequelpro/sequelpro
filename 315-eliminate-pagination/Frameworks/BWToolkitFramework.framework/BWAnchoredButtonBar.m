//
//  BWAnchoredButtonBar.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWAnchoredButtonBar.h"
#import "NSColor+BWAdditions.h"
#import "NSView+BWAdditions.h"
#import "BWAnchoredButton.h"

static NSColor *topLineColor, *bottomLineColor;
static NSColor *topColor, *middleTopColor, *middleBottomColor, *bottomColor;
static NSColor *sideInsetColor, *borderedTopLineColor;
static NSColor *resizeHandleColor, *resizeInsetColor;
static NSGradient *gradient;
static BOOL wasBorderedBar;
static float scaleFactor = 0.0f;

@interface BWAnchoredButtonBar (BWABBPrivate)
- (void)drawResizeHandleInRect:(NSRect)handleRect withColor:(NSColor *)color;
- (void)drawLastButtonInsetInRect:(NSRect)rect;
- (BOOL)isInLastSubview;
- (NSSplitView *)splitView;
@end

@implementation BWAnchoredButtonBar

@synthesize selectedIndex, isAtBottom, isResizable, handleIsRightAligned, splitViewDelegate;

+ (void)initialize;
{
	topLineColor		 = [[NSColor colorWithCalibratedWhite:(202.0f / 255.0f) alpha:1] retain];
	bottomLineColor		 = [[NSColor colorWithCalibratedWhite:(170.0f / 255.0f) alpha:1] retain];
    topColor			 = [[NSColor colorWithCalibratedWhite:(253.0f / 255.0f) alpha:1] retain];
    middleTopColor		 = [[NSColor colorWithCalibratedWhite:(242.0f / 255.0f) alpha:1] retain];
    middleBottomColor	 = [[NSColor colorWithCalibratedWhite:(230.0f / 255.0f) alpha:1] retain];
	bottomColor			 = [[NSColor colorWithCalibratedWhite:(230.0f / 255.0f) alpha:1] retain];
	sideInsetColor		 = [[NSColor colorWithCalibratedWhite:(255.0f / 255.0f) alpha:0.5] retain];
	borderedTopLineColor = [[NSColor colorWithCalibratedWhite:(190.0f / 255.0f) alpha:1] retain];
    
	gradient			 = [[NSGradient alloc] initWithColorsAndLocations:
						   topColor, (CGFloat)0.0,
						   middleTopColor, (CGFloat)0.45454,
						   middleBottomColor, (CGFloat)0.45454,
						   bottomColor, (CGFloat)1.0,
						   nil];
	
	resizeHandleColor	 = [[NSColor colorWithCalibratedWhite:(0.0f / 255.0f) alpha:0.598] retain];
	resizeInsetColor	 = [[NSColor colorWithCalibratedWhite:(255.0f / 255.0f) alpha:0.55] retain];
}

- (id)initWithFrame:(NSRect)frame 
{
    self = [super initWithFrame:frame];
    if (self) 
	{
        scaleFactor = [[NSScreen mainScreen] userSpaceScaleFactor];
		[self setIsResizable:YES];
		[self setIsAtBottom:YES];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder;
{
    if ((self = [super initWithCoder:decoder]) != nil)
	{
		[self setIsResizable:[decoder decodeBoolForKey:@"BWABBIsResizable"]];
		[self setIsAtBottom:[decoder decodeBoolForKey:@"BWABBIsAtBottom"]];
		[self setHandleIsRightAligned:[decoder decodeBoolForKey:@"BWABBHandleIsRightAligned"]];
		[self setSelectedIndex:[decoder decodeIntForKey:@"BWABBSelectedIndex"]];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
    [super encodeWithCoder:coder];
	
	[coder encodeBool:[self isResizable] forKey:@"BWABBIsResizable"];
	[coder encodeBool:[self isAtBottom] forKey:@"BWABBIsAtBottom"];
	[coder encodeBool:[self handleIsRightAligned] forKey:@"BWABBHandleIsRightAligned"];
	[coder encodeInt:[self selectedIndex] forKey:@"BWABBSelectedIndex"];
}

- (void)awakeFromNib
{
	scaleFactor = [[NSScreen mainScreen] userSpaceScaleFactor];
	
	// See if we're in a split view, and set its delegate
	NSSplitView *splitView = [self splitView];
	
	if (splitView != nil && [splitView isVertical] && [self isResizable])
		[splitView setDelegate:self];
		
	[self bringToFront];
}

- (void)drawRect:(NSRect)rect 
{	
	rect = self.bounds;
	
	// Draw gradient
	NSRect gradientRect;
	if (isAtBottom)
		gradientRect = NSMakeRect(rect.origin.x,rect.origin.y,rect.size.width,rect.size.height - 1);
	else
		gradientRect = NSInsetRect(rect, 0, 1); 
	[gradient drawInRect:gradientRect angle:270];
	
	// Draw top line
	if (isAtBottom)
		[topLineColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:YES flip:YES];
	else
		[borderedTopLineColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:YES flip:YES];
	
	// Draw resize handle
	if (isResizable)
	{
		NSRect handleRect = NSMakeRect(NSMaxX(rect)-11,6,6,10);
		
		if ([self handleIsRightAligned])
			handleRect.origin.x = 4;
		
		[self drawResizeHandleInRect:handleRect withColor:resizeHandleColor];
		
		NSRect insetRect = NSOffsetRect(handleRect,1,-1);
		[self drawResizeHandleInRect:insetRect withColor:resizeInsetColor];
	}
	
	[self drawLastButtonInsetInRect:rect];
	
	// Draw bottom line and sides if it's in non-bottom mode
	if (!isAtBottom)
	{
		[bottomLineColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:YES flip:NO];
		[bottomLineColor drawPixelThickLineAtPosition:0 withInset:1 inRect:rect inView:self horizontal:NO flip:NO];
		[bottomLineColor drawPixelThickLineAtPosition:0 withInset:1 inRect:rect inView:self horizontal:NO flip:YES];
	}
}

- (void)drawResizeHandleInRect:(NSRect)handleRect withColor:(NSColor *)color
{
	[color drawPixelThickLineAtPosition:0 withInset:0 inRect:handleRect inView:self horizontal:NO flip:NO];
	[color drawPixelThickLineAtPosition:3 withInset:0 inRect:handleRect inView:self horizontal:NO flip:NO];
	[color drawPixelThickLineAtPosition:6 withInset:0 inRect:handleRect inView:self horizontal:NO flip:NO];
}

- (void)drawLastButtonInsetInRect:(NSRect)rect
{
	NSView *rightMostView = nil;
	
	if ([[self subviews] count] > 0)
	{
		rightMostView = [[self subviews] objectAtIndex:0];
		
		NSView *currentSubview = nil;
		for (currentSubview in [self subviews])
		{
			if ([[currentSubview className] isEqualToString:@"BWAnchoredButton"] || [[currentSubview className] isEqualToString:@"BWAnchoredPopUpButton"])
			{
				if (NSMaxX([currentSubview frame]) > NSMaxX([rightMostView frame]))
					rightMostView = currentSubview;
				
				if ([currentSubview frame].origin.x == 0)
					[(BWAnchoredButton *)currentSubview setIsAtLeftEdgeOfBar:YES];
				else
					[(BWAnchoredButton *)currentSubview setIsAtLeftEdgeOfBar:NO];
				
				if (NSMaxX([currentSubview frame]) == NSMaxX([self bounds]))
					[(BWAnchoredButton *)currentSubview setIsAtRightEdgeOfBar:YES];
				else
					[(BWAnchoredButton *)currentSubview setIsAtRightEdgeOfBar:NO];
			}
		}
	}
	
	if (rightMostView != nil && ([[rightMostView className] isEqualToString:@"BWAnchoredButton"] || [[rightMostView className] isEqualToString:@"BWAnchoredPopUpButton"]))
	{
		NSRect newRect = NSOffsetRect(rect,0,-1);
		[sideInsetColor drawPixelThickLineAtPosition:NSMaxX([rightMostView frame]) withInset:0 inRect:newRect inView:self horizontal:NO flip:NO];
	}
}

- (void)viewDidMoveToSuperview
{
	if ([self splitView] != nil)
		self.handleIsRightAligned = [self isInLastSubview];
}

- (BOOL)isInLastSubview
{
	// This method could be made more robust. Right now it assumes that the button bar's direct parent is the split view.
	if ([self splitView] != nil && [self superview] == [[[self splitView] subviews] lastObject])
		return YES;
	
	return NO;
}

- (NSSplitView *)splitView
{
	NSSplitView *splitView = nil;
	id currentView = self;
	
	while (![currentView isKindOfClass:[NSSplitView class]] && currentView != nil)
	{
		currentView = [currentView superview];
		if ([currentView isKindOfClass:[NSSplitView class]])
			splitView = currentView;
	}
	
	return splitView;
}

- (void)setIsAtBottom:(BOOL)flag
{
	isAtBottom = flag;

	if (flag)
	{
		[self setFrameSize:NSMakeSize(self.frame.size.width,23)];
		wasBorderedBar = NO;
	}
	else
	{
		[self setFrameSize:NSMakeSize(self.frame.size.width,24)];
		wasBorderedBar = YES;
	}

	[self setNeedsDisplay:YES];
}

- (void)setSelectedIndex:(int)anIndex
{
	if (anIndex == 0)
	{
		[self setIsAtBottom:YES];
		[self setIsResizable:YES];
	}
	else if (anIndex == 1)
	{
		[self setIsAtBottom:YES];
		[self setIsResizable:NO];
	}
	else if (anIndex == 2)
	{
		[self setIsAtBottom:NO];
		[self setIsResizable:NO];
	}
	selectedIndex = anIndex;
	
	[self setNeedsDisplay:YES];
}

+ (BOOL)wasBorderedBar
{
	return wasBorderedBar;
}

#pragma mark NSSplitView Delegate Methods

// Add the resize handle rect to the split view hot zone
- (NSRect)splitView:(NSSplitView *)aSplitView additionalEffectiveRectOfDividerAtIndex:(NSInteger)dividerIndex
{
	if ([splitViewDelegate respondsToSelector:@selector(splitView:additionalEffectiveRectOfDividerAtIndex:)])
		return [splitViewDelegate splitView:aSplitView additionalEffectiveRectOfDividerAtIndex:dividerIndex];
	
	NSRect paddedHandleRect;
	paddedHandleRect.origin.y = [aSplitView frame].size.height - [self frame].origin.y - [self bounds].size.height;
	paddedHandleRect.origin.x = NSMaxX([self bounds]) - 15;
	
	if (self.handleIsRightAligned)
		paddedHandleRect.origin.x = [aSplitView frame].size.width - [self bounds].size.width;
	
	paddedHandleRect.size.width = 15;
	paddedHandleRect.size.height = [self bounds].size.height;
	
	return paddedHandleRect;
}

// Remaining delegate methods. They test for an implementation by the splitViewDelegate (otherwise perform default behavior)

- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
	if ([splitViewDelegate respondsToSelector:@selector(splitView:constrainMinCoordinate:ofSubviewAt:)])
		return [splitViewDelegate splitView:sender constrainMinCoordinate:proposedMin ofSubviewAt:offset];
	
	return proposedMin;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
	if ([splitViewDelegate respondsToSelector:@selector(splitView:constrainMaxCoordinate:ofSubviewAt:)])
		return [splitViewDelegate splitView:sender constrainMaxCoordinate:proposedMax ofSubviewAt:offset];
	
	return proposedMax;
}

- (void)splitView:(NSSplitView*)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	if ([splitViewDelegate respondsToSelector:@selector(splitView:resizeSubviewsWithOldSize:)])
		return [splitViewDelegate splitView:sender resizeSubviewsWithOldSize:oldSize];
	
	[sender adjustSubviews];
}

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview
{
	if ([splitViewDelegate respondsToSelector:@selector(splitView:canCollapseSubview:)])
		return [splitViewDelegate splitView:sender canCollapseSubview:subview];
	
	return NO;
}

- (CGFloat)splitView:(NSSplitView *)sender constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)offset
{
	if ([splitViewDelegate respondsToSelector:@selector(splitView:constrainSplitPosition:ofSubviewAt:)])
		return [splitViewDelegate splitView:sender constrainSplitPosition:proposedPosition ofSubviewAt:offset];
	
	return proposedPosition;
}

- (NSRect)splitView:(NSSplitView *)splitView effectiveRect:(NSRect)proposedEffectiveRect forDrawnRect:(NSRect)drawnRect ofDividerAtIndex:(NSInteger)dividerIndex
{
	if ([splitViewDelegate respondsToSelector:@selector(splitView:effectiveRect:forDrawnRect:ofDividerAtIndex:)])
		return [splitViewDelegate splitView:splitView effectiveRect:proposedEffectiveRect forDrawnRect:drawnRect ofDividerAtIndex:dividerIndex];
	
	return proposedEffectiveRect;
}

- (BOOL)splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex
{
	if ([splitViewDelegate respondsToSelector:@selector(splitView:shouldCollapseSubview:forDoubleClickOnDividerAtIndex:)])
		return [splitViewDelegate splitView:splitView shouldCollapseSubview:subview forDoubleClickOnDividerAtIndex:dividerIndex];
	
	return NO;
}

- (BOOL)splitView:(NSSplitView *)splitView shouldHideDividerAtIndex:(NSInteger)dividerIndex
{
	if ([splitViewDelegate respondsToSelector:@selector(splitView:shouldHideDividerAtIndex:)])
		return [splitViewDelegate splitView:splitView shouldHideDividerAtIndex:dividerIndex];
	
	return NO;
}

@end
