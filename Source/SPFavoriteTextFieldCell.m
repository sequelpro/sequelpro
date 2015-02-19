//
//  SPFavoriteTextFieldCell.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on December 29, 2008.
//  Copyright (c) 2008 Stuart Connolly. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <https://github.com/sequelpro/sequelpro>

#import "SPFavoriteTextFieldCell.h"
#import "SPOSInfo.h"

extern BOOL isOSAtLeast10_10_0(void);

@implementation SPFavoriteTextFieldCell

- (id)init
{
	if ((self = [super init])) {
		drawsDividerUnderCell = NO;
	}
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone 
{
    SPFavoriteTextFieldCell *cell = (SPFavoriteTextFieldCell *)[super copyWithZone:zone];

	cell->drawsDividerUnderCell = drawsDividerUnderCell;
	cell->labelColor            = [labelColor copyWithZone:zone];
    
	return cell;
}

/**
 * Returns whether this cell is set to draw a divider in the space directly below
 * the cell (whatever currently populates that space).
 */
- (BOOL)drawsDividerUnderCell
{
	return drawsDividerUnderCell;
}

/**
 * Set whether this cell should draw a divider in the space directly below
 * the cell (whatever currently populates that space).
 */
- (void)setDrawsDividerUnderCell:(BOOL)drawsDivider
{
	drawsDividerUnderCell = drawsDivider;
}

@synthesize labelColor;

#pragma mark -

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	if(labelColor) {
		CGFloat round = (cellFrame.size.height/2);
		NSBezierPath *bg = [NSBezierPath bezierPathWithRoundedRect:cellFrame xRadius:round yRadius:round];
		
		if(isOSAtLeast10_10_0()) {
			CGFloat h,s,b,a;
			[labelColor getHue:&h saturation:&s brightness:&b alpha:&a];
			
			[[NSColor colorWithCalibratedHue:h saturation:s*1.21 brightness:b*1.1 alpha:a] set];
			[bg fill];
		}
		else {
			// Draw main background gradient
			NSGradient * gradient = [[NSGradient alloc] initWithColorsAndLocations:
									 [labelColor highlightWithLevel:0.33], 0.0,
									  labelColor, 0.5,
									 [labelColor shadowWithLevel:0.15], 1.0, nil];
			[gradient drawInBezierPath:bg angle:90.0];
			[gradient release];
			
			//replace the shadow color of the highlighted item (the default is dark blue)
			if([self isHighlighted]) {
				NSMutableAttributedString *mas = [[self attributedStringValue] mutableCopy];
				NSShadow *strShadow = [mas attribute:NSShadowAttributeName atIndex:0 effectiveRange:NULL];
				if(strShadow) {
					[strShadow setShadowColor:[labelColor shadowWithLevel:0.4]];
					[self setAttributedStringValue:mas];
				}
				[mas release];
			}
			
			// Add a little border at the top half (technically this is an inner shadow)
			CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
			
			NSShadow* shadow = [[NSShadow alloc] init];
			[shadow setShadowColor:labelColor];
			[shadow setShadowOffset: NSMakeSize(0.1, -1.2)];
			[shadow setShadowBlurRadius: 1];
			
			[NSGraphicsContext saveGraphicsState];
			NSRectClip([bg bounds]);
			CGContextSetShadowWithColor(context, CGSizeZero, 0, NULL);
			
			CGContextSetAlpha(context, [[shadow shadowColor] alphaComponent]);
			CGContextBeginTransparencyLayer(context, NULL);
			{
				[shadow set];
				
				CGContextSetBlendMode(context, kCGBlendModeSourceOut);
				CGContextBeginTransparencyLayer(context, NULL);
				
				[[shadow shadowColor] setFill];
				[bg fill];
				
				CGContextEndTransparencyLayer(context);
			}
			CGContextEndTransparencyLayer(context);
			[NSGraphicsContext restoreGraphicsState];
			
			[shadow release];
		}
	}
	
	[super drawWithFrame:cellFrame inView:controlView];
}


/**
 * Draws the actual cell, with a divider if appropriate.
 */
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{		
	[super drawInteriorWithFrame:cellFrame inView:controlView];

	if (drawsDividerUnderCell) {
		NSRect viewFrame = [controlView frame];

		NSPoint startPoint = NSMakePoint(viewFrame.origin.x + 7.f, viewFrame.origin.y);
		NSPoint endPoint = NSMakePoint(viewFrame.origin.x + viewFrame.size.width - 7.f, viewFrame.origin.y);

		if ([controlView isFlipped]) {
			startPoint.y += cellFrame.size.height + 8.5f;
			endPoint.y += cellFrame.size.height + 8.5f;
		} 
		else {
			startPoint.y -= cellFrame.size.height + 8.5f;
			endPoint.y -= cellFrame.size.height + 8.5f;
		}

		[NSGraphicsContext saveGraphicsState];
		[[NSColor gridColor] set];
		
		NSShadow *lineGlow = [[NSShadow alloc] init];
		
		[lineGlow setShadowBlurRadius:1];
		[lineGlow setShadowColor:[[NSColor controlLightHighlightColor] colorWithAlphaComponent:0.75f]];
		[lineGlow setShadowOffset:NSMakeSize(0, -1)];
		[lineGlow set];
		
		[NSBezierPath strokeLineFromPoint:startPoint toPoint:endPoint];
		
		[lineGlow release];
		
		[NSGraphicsContext restoreGraphicsState];
	}
}

- (void)dealloc
{
	[self setLabelColor:nil];
	
	[super dealloc];
}

@end

BOOL isOSAtLeast10_10_0() {
	const BOOL value = [SPOSInfo isOSVersionAtLeastMajor:10 minor:10 patch:0];
	return value;
}
