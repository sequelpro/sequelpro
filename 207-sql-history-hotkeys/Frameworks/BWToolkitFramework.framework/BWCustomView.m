//
//  BWGradientSplitViewSubview.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWCustomView.h"
#import "NSColor+BWAdditions.h"
#import "NSWindow+BWAdditions.h"
#import "NSApplication+BWAdditions.h"
#import "IBColor.h"

@interface BWCustomView (BWCVPrivate)
- (void)drawTextInRect:(NSRect)rect;
- (NSColor *)containerCustomViewBackgroundColor;
- (NSColor *)childlessCustomViewBackgroundColor;
- (NSColor *)customViewDarkTexturedBorderColor;
- (NSColor *)customViewDarkBorderColor;
- (NSColor *)customViewLightBorderColor;
@end

@implementation BWCustomView

- (void)drawRect:(NSRect)rect 
{
	rect = self.bounds;
	
	NSColor *insetColor = [self customViewLightBorderColor];
	NSColor *borderColor;
	
	if ([[self window] isTextured])
		borderColor = [self customViewDarkTexturedBorderColor];
	else
		borderColor = [self customViewDarkBorderColor];	
		
	// Note: These two colors are reversed in IBColor in 10.5
	if (self.subviews.count == 0)
	{
		if ([NSApplication isOnLeopard])
			[[self containerCustomViewBackgroundColor] set];
		else
			[[self childlessCustomViewBackgroundColor] set];
		NSRectFillUsingOperation(rect,NSCompositeSourceOver);
	}
	else
	{
		if ([NSApplication isOnLeopard])
			[[self childlessCustomViewBackgroundColor] set];
		else
			[[self containerCustomViewBackgroundColor] set];
		NSRectFillUsingOperation(rect,NSCompositeSourceOver);
	}
		
	if ([[self superview] isKindOfClass:NSClassFromString(@"BWSplitView")] && [[self superview] subviews].count > 1)
	{
		isOnItsOwn = NO;
		NSArray *subviews = [[self superview] subviews];
		
		if ([subviews objectAtIndex:0] == self)
		{
			[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:rect inView:self horizontal:NO flip:NO];
			[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:rect inView:self horizontal:YES flip:YES];
			
			if ([(NSSplitView *)[self superview] isVertical])
			{
				[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:rect inView:self horizontal:YES flip:NO];
				[insetColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:NO flip:YES];	
				[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:YES flip:NO];
			}
			else
			{
				[insetColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:YES flip:NO];
				[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:rect inView:self horizontal:NO flip:YES];
				[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:NO flip:YES];
			}

			[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:NO flip:NO];
			[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:YES flip:YES];				
		}
		else if ([subviews lastObject] == self)
		{
			[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:rect inView:self horizontal:NO flip:YES];
			[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:rect inView:self horizontal:YES flip:NO];
			
			if ([(NSSplitView *)[self superview] isVertical])
			{
				[insetColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:NO flip:NO];
				[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:rect inView:self horizontal:YES flip:YES];
				[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:YES flip:YES];
				[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:NO flip:YES];		
			}
			else
			{
				[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:rect inView:self horizontal:NO flip:NO];
				[insetColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:YES flip:YES];
				[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:NO flip:YES];
				[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:NO flip:NO];
			}
			
			[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:YES flip:NO];
		}
		else
		{	
			if ([(NSSplitView *)[self superview] isVertical])
			{
				[insetColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:NO flip:NO];
				[insetColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:NO flip:YES];
				[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:rect inView:self horizontal:YES flip:YES];
				[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:rect inView:self horizontal:YES flip:NO];
				[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:YES flip:NO];
				[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:YES flip:YES];				
			}
			else
			{
				[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:rect inView:self horizontal:NO flip:NO];
				[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:rect inView:self horizontal:NO flip:YES];
				[insetColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:YES flip:YES];
				[insetColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:YES flip:NO];
				[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:NO flip:NO];
				[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:NO flip:YES];				
			}
		}
	}
	else
	{
		isOnItsOwn = YES;
		
		[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:rect inView:self horizontal:NO flip:NO];
		[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:rect inView:self horizontal:NO flip:YES];
		[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:rect inView:self horizontal:YES flip:YES];
		[insetColor drawPixelThickLineAtPosition:1 withInset:0 inRect:rect inView:self horizontal:YES flip:NO];
		
		[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:NO flip:NO];
		[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:NO flip:YES];
		[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:YES flip:YES];
		[borderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:rect inView:self horizontal:YES flip:NO];
	}
	
	if (rect.size.height > 16)
		[self drawTextInRect:rect];
}

- (void)drawTextInRect:(NSRect)rect
{
	NSString *text;
	
	if (isOnItsOwn)
		text = [NSString stringWithFormat:@"%d x %d pt",(int)rect.size.width,(int)rect.size.height];
	else if ([(NSSplitView *)[self superview] isVertical])
		text = [NSString stringWithFormat:@"%d pt",(int)rect.size.width];
	else
		text = [NSString stringWithFormat:@"%d pt",(int)rect.size.height];
	
	if (![self.className isEqualToString:@"NSView"])
		text = self.className;
	
	NSMutableDictionary *attributes = [[[NSMutableDictionary alloc] init] autorelease];
	[attributes setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
	[attributes setObject:[NSFont boldSystemFontOfSize:12] forKey:NSFontAttributeName];
	
	NSShadow *shadow = [[[NSShadow alloc] init] autorelease];
	[shadow setShadowOffset:NSMakeSize(0,-1)];
	[shadow setShadowColor:[[NSColor blackColor] colorWithAlphaComponent:0.4]];
	[attributes setObject:shadow forKey:NSShadowAttributeName];
	
	NSMutableAttributedString *string = [[[NSMutableAttributedString alloc] initWithString:text attributes:attributes] autorelease];
	
	NSRect boundingRect = [string boundingRectWithSize:rect.size options:0];
	
	NSPoint rectCenter;
	rectCenter.x = rect.size.width / 2;
	rectCenter.y = rect.size.height / 2;
	
	NSPoint drawPoint = rectCenter;
	drawPoint.x -= boundingRect.size.width / 2;
	drawPoint.y -= boundingRect.size.height / 2;
	
	drawPoint.x = roundf(drawPoint.x);
	drawPoint.y = roundf(drawPoint.y);
	
	[string drawAtPoint:drawPoint];
}

@end