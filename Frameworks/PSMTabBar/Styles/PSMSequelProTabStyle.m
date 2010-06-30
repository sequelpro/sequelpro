//
//  $Id: PSMSequelProTabStyle.m 2317 2010-06-15 10:19:41Z avenjamin $
//
//  PSMSequelProTabStyle.m
//  sequel-pro
//
//  Created by Ben Perry on June 15, 2010
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import "PSMSequelProTabStyle.h"
#import "PSMTabBarCell.h"
#import "PSMTabBarControl.h"
#import "NSBezierPath_AMShading.h"
#import "PSMTabDragAssistant.h"

#define kPSMSequelProObjectCounterRadius 7.0
#define kPSMSequelProCounterMinWidth 20
#define kPSMSequelProTabCornerRadius 4.5
#define MARGIN_X 7

@implementation PSMSequelProTabStyle

- (NSString *)name
{
    return @"SequelPro";
}

#pragma mark -
#pragma mark Creation/Destruction

- (id) init
{
    if ( (self = [super init]) ) {
        metalCloseButton = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"TabClose_Front"]];
        metalCloseButtonDown = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"TabClose_Front_Pressed"]];
        metalCloseButtonOver = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"TabClose_Front_Rollover"]];

        metalCloseDirtyButton = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"TabClose_Dirty"]];
        metalCloseDirtyButtonDown = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"TabClose_Dirty_Pressed"]];
        metalCloseDirtyButtonOver = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"TabClose_Dirty_Rollover"]];
                
        _addTabButtonImage = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"AddTabButton"]];
        _addTabButtonPressedImage = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"AddTabButtonPushed"]];
        _addTabButtonRolloverImage = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"AddTabButtonRollover"]];
		
		_objectCountStringAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:[[NSFontManager sharedFontManager] convertFont:[NSFont fontWithName:@"Helvetica" size:11.0] toHaveTrait:NSBoldFontMask], NSFontAttributeName,
																					[[NSColor whiteColor] colorWithAlphaComponent:0.85], NSForegroundColorAttributeName,
																					nil, nil];
    }
    return self;
}

- (void)dealloc
{
    [metalCloseButton release];
    [metalCloseButtonDown release];
    [metalCloseButtonOver release];
    [metalCloseDirtyButton release];
    [metalCloseDirtyButtonDown release];
    [metalCloseDirtyButtonOver release];
    [_addTabButtonImage release];
    [_addTabButtonPressedImage release];
    [_addTabButtonRolloverImage release];
    
	[_objectCountStringAttributes release];
	
    [super dealloc];
}

#pragma mark -
#pragma mark Control Specific

- (CGFloat)leftMarginForTabBarControl
{
    return 5.0f;
}

- (CGFloat)rightMarginForTabBarControl
{
    return 24.0f;
}

- (CGFloat)topMarginForTabBarControl
{
	return 10.0f;
}

- (void)setOrientation:(PSMTabBarOrientation)value
{
	// Hard code orientation to horizontal
	orientation = PSMTabBarHorizontalOrientation;
}

#pragma mark -
#pragma mark Add Tab Button

- (NSImage *)addTabButtonImage
{
    return _addTabButtonImage;
}

- (NSImage *)addTabButtonPressedImage
{
    return _addTabButtonPressedImage;
}

- (NSImage *)addTabButtonRolloverImage
{
    return _addTabButtonRolloverImage;
}

#pragma mark -
#pragma mark Cell Specific

- (NSRect)dragRectForTabCell:(PSMTabBarCell *)cell orientation:(PSMTabBarOrientation)tabOrientation
{
	NSRect dragRect = [cell frame];
	dragRect.size.width++;
	
	if ([cell tabState] & PSMTab_SelectedMask) {
		if (tabOrientation == PSMTabBarHorizontalOrientation) {
			dragRect.origin.x -= 5.0;
			dragRect.size.width += 10.0;
		} else {
			dragRect.size.height += 1.0;
			dragRect.origin.y -= 1.0;
			dragRect.origin.x += 2.0;
			dragRect.size.width -= 3.0;
		}
	} else if (tabOrientation == PSMTabBarVerticalOrientation) {
		dragRect.origin.x--;
	}
	
	return dragRect;
}

- (NSRect)closeButtonRectForTabCell:(PSMTabBarCell *)cell withFrame:(NSRect)cellFrame
{
    if ([cell hasCloseButton] == NO) {
        return NSZeroRect;
    }
    
    NSRect result;
    result.size = [metalCloseButton size];
    result.origin.x = cellFrame.origin.x + MARGIN_X;
    result.origin.y = cellFrame.origin.y + MARGIN_Y + 2.0;
    
    return result;
}

- (NSRect)iconRectForTabCell:(PSMTabBarCell *)cell
{
    NSRect cellFrame = [cell frame];
    
    if ([cell hasIcon] == NO) {
        return NSZeroRect;
    }
    
    NSRect result;
    result.size = NSMakeSize(kPSMTabBarIconWidth, kPSMTabBarIconWidth);
    result.origin.x = cellFrame.origin.x + MARGIN_X;
	result.origin.y = cellFrame.origin.y + MARGIN_Y;
    
    if ([cell hasCloseButton] && ![cell isCloseButtonSuppressed]) {
        result.origin.x += [metalCloseButton size].width + kPSMTabBarCellPadding;
    }
	
    return result;
}

- (NSRect)indicatorRectForTabCell:(PSMTabBarCell *)cell
{
    NSRect cellFrame = [cell frame];
    
    if ([[cell indicator] isHidden]) {
        return NSZeroRect;
    }
    
    NSRect result;
    result.size = NSMakeSize(kPSMTabBarIndicatorWidth, kPSMTabBarIndicatorWidth);
    result.origin.x = cellFrame.origin.x + cellFrame.size.width - MARGIN_X - kPSMTabBarIndicatorWidth;
    result.origin.y = cellFrame.origin.y + MARGIN_Y;
	
    return result;
}

- (NSRect)objectCounterRectForTabCell:(PSMTabBarCell *)cell
{
    NSRect cellFrame = [cell frame];
    
    if ([cell count] == 0) {
        return NSZeroRect;
    }
    
    CGFloat countWidth = [[self attributedObjectCountValueForTabCell:cell] size].width;
    countWidth += (2 * kPSMSequelProObjectCounterRadius - 6.0);
    if (countWidth < kPSMSequelProCounterMinWidth) {
        countWidth = kPSMSequelProCounterMinWidth;
    }
    
    NSRect result;
    result.size = NSMakeSize(countWidth, 2 * kPSMSequelProObjectCounterRadius); // temp
    result.origin.x = cellFrame.origin.x + cellFrame.size.width - MARGIN_X - result.size.width;
    result.origin.y = cellFrame.origin.y + MARGIN_Y + 1.0;
    
    if (![[cell indicator] isHidden]) {
        result.origin.x -= kPSMTabBarIndicatorWidth + kPSMTabBarCellPadding;
    }
    
    return result;
}


- (CGFloat)minimumWidthOfTabCell:(PSMTabBarCell *)cell
{
    CGFloat resultWidth = 0.0;
    
    // left margin
    resultWidth = MARGIN_X;
    
    // close button?
    if ([cell hasCloseButton] && ![cell isCloseButtonSuppressed]) {
        resultWidth += [metalCloseButton size].width + kPSMTabBarCellPadding;
    }
    
    // icon?
    if ([cell hasIcon]) {
        resultWidth += kPSMTabBarIconWidth + kPSMTabBarCellPadding;
    }
    
    // the label
    resultWidth += kPSMMinimumTitleWidth;
    
    // object counter?
    if ([cell count] > 0) {
        resultWidth += [self objectCounterRectForTabCell:cell].size.width + kPSMTabBarCellPadding;
    }
    
    // indicator?
    if ([[cell indicator] isHidden] == NO)
        resultWidth += kPSMTabBarCellPadding + kPSMTabBarIndicatorWidth;
    
    // right margin
    resultWidth += MARGIN_X;
    
    return ceil(resultWidth);
}

- (CGFloat)desiredWidthOfTabCell:(PSMTabBarCell *)cell
{
    CGFloat resultWidth = 0.0;
    
    // left margin
    resultWidth = MARGIN_X;
    
    // close button?
    if ([cell hasCloseButton] && ![cell isCloseButtonSuppressed])
        resultWidth += [metalCloseButton size].width + kPSMTabBarCellPadding;
    
    // icon?
    if ([cell hasIcon]) {
        resultWidth += kPSMTabBarIconWidth + kPSMTabBarCellPadding;
    }
    
    // the label
    resultWidth += [[cell attributedStringValue] size].width;
    
    // object counter?
    if ([cell count] > 0) {
        resultWidth += [self objectCounterRectForTabCell:cell].size.width + kPSMTabBarCellPadding;
    }
    
    // indicator?
    if ([[cell indicator] isHidden] == NO)
        resultWidth += kPSMTabBarCellPadding + kPSMTabBarIndicatorWidth;
    
    // right margin
    resultWidth += MARGIN_X;
    
    return ceil(resultWidth);
}

- (CGFloat)tabCellHeight
{
	return kPSMTabBarControlHeight;
}

#pragma mark -
#pragma mark Cell Values

- (NSAttributedString *)attributedObjectCountValueForTabCell:(PSMTabBarCell *)cell
{
    NSString *contents = [NSString stringWithFormat:@"%lu", (unsigned long)[cell count]];
    return [[[NSMutableAttributedString alloc] initWithString:contents attributes:_objectCountStringAttributes] autorelease];
}

- (NSAttributedString *)attributedStringValueForTabCell:(PSMTabBarCell *)cell
{
    NSMutableAttributedString *attrStr;
    NSString *contents = [cell stringValue];
    attrStr = [[[NSMutableAttributedString alloc] initWithString:contents] autorelease];
    NSRange range = NSMakeRange(0, [contents length]);
    
    // Add font attribute
    [attrStr addAttribute:NSFontAttributeName value:[NSFont boldSystemFontOfSize:11.0] range:range];
    [attrStr addAttribute:NSForegroundColorAttributeName value:[[NSColor textColor] colorWithAlphaComponent:0.75] range:range];
    
    // Add shadow attribute
    NSShadow* shadow;
    shadow = [[[NSShadow alloc] init] autorelease];
    CGFloat shadowAlpha;
    if (([cell state] == NSOnState) || [cell isHighlighted]) {
        shadowAlpha = 0.8;
    } else {
        shadowAlpha = 0.5;
    }
    [shadow setShadowColor:[NSColor colorWithCalibratedWhite:1.0 alpha:shadowAlpha]];
    [shadow setShadowOffset:NSMakeSize(0, -1)];
    [shadow setShadowBlurRadius:1.0];
    [attrStr addAttribute:NSShadowAttributeName value:shadow range:range];
    
    // Paragraph Style for Truncating Long Text
    static NSMutableParagraphStyle *TruncatingTailParagraphStyle = nil;
    if (!TruncatingTailParagraphStyle) {
        TruncatingTailParagraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] retain];
        [TruncatingTailParagraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
        [TruncatingTailParagraphStyle setAlignment:NSCenterTextAlignment];
    }
    [attrStr addAttribute:NSParagraphStyleAttributeName value:TruncatingTailParagraphStyle range:range];
    
    return attrStr;
}

#pragma mark -
#pragma mark Drawing

// Step 1
- (void)drawTabBar:(PSMTabBarControl *)bar inRect:(NSRect)rect
{
	if (orientation != [bar orientation]) {
		orientation = [bar orientation];
	}
	
	if (tabBar != bar) {
		tabBar = bar;
	}
	
	[self drawBackgroundInRect:rect];
	
	// no tab view == not connected
    if (![bar tabView]) {
        NSRect labelRect = rect;
        labelRect.size.height -= 4.0;
        labelRect.origin.y += 4.0;
        NSMutableAttributedString *attrStr;
        NSString *contents = @"PSMTabBarControl";
        attrStr = [[[NSMutableAttributedString alloc] initWithString:contents] autorelease];
		NSRange range = NSMakeRange(0, [contents length]);
        [attrStr addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:11.0] range:range];
        NSMutableParagraphStyle *centeredParagraphStyle = nil;
        
		if (!centeredParagraphStyle) {
            centeredParagraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] retain];
            [centeredParagraphStyle setAlignment:NSCenterTextAlignment];
        }
        [attrStr addAttribute:NSParagraphStyleAttributeName value:centeredParagraphStyle range:range];
        [attrStr drawInRect:labelRect];
        return;
    }
    
    // draw cells
    NSEnumerator *e = [[bar cells] objectEnumerator];
    PSMTabBarCell *cell;
    while ( (cell = [e nextObject]) ) {
        if ([bar isAnimating] || (![cell isInOverflowMenu] && NSIntersectsRect([cell frame], rect))) {
            [cell drawWithFrame:[cell frame] inView:bar];
        }
    }
}


// Step 2
- (void)drawBackgroundInRect:(NSRect)rect
{
	//Draw for our whole bounds; it'll be automatically clipped to fit the appropriate drawing area
	rect = [tabBar bounds];
	
	[NSGraphicsContext saveGraphicsState];
	[[NSGraphicsContext currentContext] setShouldAntialias:NO];

	float backgroundCalibratedWhite = 0.495;
	float lineCalibratedWhite = [[NSColor darkGrayColor] whiteComponent];
	float shadowAlpha = 0.4;

	// When the window is in the background, tone down the colours
	if (![[tabBar window] isKeyWindow]) {
		backgroundCalibratedWhite = 0.685;
		lineCalibratedWhite = 0.49;
		shadowAlpha = 0.3;
	}

	// fill in background of tab bar
	[[NSColor colorWithCalibratedWhite:backgroundCalibratedWhite alpha:1.0] set];
	NSRectFillUsingOperation(rect, NSCompositeSourceAtop);

	// Draw horizontal line across bottom edge, with a slight bottom glow
	[[NSColor colorWithCalibratedWhite:lineCalibratedWhite alpha:1.0] set];
	[NSGraphicsContext saveGraphicsState];
	NSShadow *shadow = [[NSShadow alloc] init];
	[shadow setShadowBlurRadius:1];
	[shadow setShadowColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.2]];
	[shadow setShadowOffset:NSMakeSize(0,1)];
	[shadow set];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height - 0.5) toPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height - 0.5)];
	[shadow release];
	[NSGraphicsContext restoreGraphicsState];

	// Add a shadow before drawing the top edge
	[NSGraphicsContext saveGraphicsState];
	shadow = [[NSShadow alloc] init];
	[shadow setShadowBlurRadius:4];
	[shadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:shadowAlpha]];
	[shadow setShadowOffset:NSMakeSize(0,0)];
	[shadow set];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(rect.origin.x, rect.origin.y + 0.5) toPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + 0.5)];
	[shadow release];
	[NSGraphicsContext restoreGraphicsState];
	
	[NSGraphicsContext restoreGraphicsState];
}



// Step 3
- (void)drawTabCell:(PSMTabBarCell *)cell
{
    NSRect cellFrame = [cell frame];	
    NSColor *lineColor = nil;
	NSColor *fillColor = nil;
	NSColor *shadowColor = nil;
    NSBezierPath *outlineBezier = [NSBezierPath bezierPath];
    NSBezierPath *fillBezier = [NSBezierPath bezierPath];
	NSPoint center = NSZeroPoint;
	NSPoint topLeftArcCenter, bottomLeftArcCenter, topRightArcCenter, bottomRightArcCenter;
	BOOL drawRightEdge = YES;
	BOOL drawLeftEdge = YES;

	// For cells in the off state, determine whether to draw the edges.
	if ([cell state] == NSOffState) {
		NSUInteger selectedCellIndex = NSUIntegerMax;
		NSUInteger drawingCellIndex = NSUIntegerMax;
		NSUInteger firstOverflowedCellIndex = NSUIntegerMax;

		NSUInteger currentIndex = 0;
		for (PSMTabBarCell *aCell in [tabBar cells]) {
			if (aCell == cell) drawingCellIndex = currentIndex;
			if ([aCell state] == NSOnState || ([aCell isPlaceholder] && [aCell currentStep] > 1)) {
				selectedCellIndex = currentIndex;
			}
			if ([aCell isInOverflowMenu]) {
				firstOverflowedCellIndex = currentIndex;
				break;
			}
			currentIndex++;
		}

		// Draw the left edge if the cell is to the left of the active tab, or if the preceding cell is
		// being dragged, and not for the very first cell.
		if ((!drawingCellIndex || (drawingCellIndex == 1 && [[[tabBar cells] objectAtIndex:0] isPlaceholder]))
			|| (drawingCellIndex > selectedCellIndex
				&& (drawingCellIndex != selectedCellIndex + 1 || ![[[tabBar cells] objectAtIndex:selectedCellIndex] isPlaceholder])))
		{
			drawLeftEdge = NO;
		}

		// Draw the right edge for tabs to the right, the last tab in the bar, and where the following
		// cell is being dragged.
		if (drawingCellIndex < selectedCellIndex
			&& drawingCellIndex != firstOverflowedCellIndex - 1
			&& (drawingCellIndex >= selectedCellIndex + 1 || ![[[tabBar cells] objectAtIndex:selectedCellIndex] isPlaceholder]))
		{
			drawRightEdge = NO;
		}
	}

	// Set up colours
	if ([[tabBar window] isKeyWindow]) {
		lineColor = [NSColor darkGrayColor];
		if ([cell state] == NSOnState) {
			fillColor = [NSColor colorWithCalibratedWhite:0.59 alpha:1.0];
			shadowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.7];
		} else {
			fillColor = [NSColor colorWithCalibratedWhite:0.495 alpha:1.0];		
			shadowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:1.0];
		}
	} else {
		lineColor = [NSColor colorWithCalibratedWhite:0.49 alpha:1.0];
		if ([cell state] == NSOnState) {
			fillColor = [NSColor colorWithCalibratedWhite:0.81 alpha:1.0];
			shadowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.4];
		} else {
			fillColor = [NSColor colorWithCalibratedWhite:0.685 alpha:1.0];
			shadowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.7];
		}
	}
	
	[NSGraphicsContext saveGraphicsState];
	
	NSRect aRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width, cellFrame.size.height);

	// If the tab bar is hidden, don't draw the top pixel
	if ([tabBar isTabBarHidden]) {
		aRect.origin.y++;
		aRect.size.height--;
	}

	// Set up the corner bezier paths arc centers
	topLeftArcCenter = NSMakePoint(aRect.origin.x - kPSMSequelProTabCornerRadius + 0.5, aRect.origin.y + kPSMSequelProTabCornerRadius);
	topRightArcCenter = NSMakePoint(aRect.origin.x + aRect.size.width + kPSMSequelProTabCornerRadius + 0.5, aRect.origin.y + kPSMSequelProTabCornerRadius);
	bottomLeftArcCenter = NSMakePoint(aRect.origin.x + kPSMSequelProTabCornerRadius + 0.5, aRect.origin.y + aRect.size.height - kPSMSequelProTabCornerRadius);
	bottomRightArcCenter = NSMakePoint(aRect.origin.x + aRect.size.width - kPSMSequelProTabCornerRadius + 0.5, aRect.origin.y + aRect.size.height - kPSMSequelProTabCornerRadius );

	// Construct the outline path
	if (drawLeftEdge) {
		[outlineBezier appendBezierPathWithArcWithCenter:topLeftArcCenter radius:kPSMSequelProTabCornerRadius startAngle:270 endAngle:360 clockwise:NO];
		[outlineBezier appendBezierPathWithArcWithCenter:bottomLeftArcCenter radius:kPSMSequelProTabCornerRadius startAngle:180 endAngle:90 clockwise:YES];
	}
	if (drawRightEdge) {
		[outlineBezier appendBezierPathWithArcWithCenter:bottomRightArcCenter radius:kPSMSequelProTabCornerRadius startAngle:90 endAngle:0 clockwise:YES];
		[outlineBezier appendBezierPathWithArcWithCenter:topRightArcCenter radius:kPSMSequelProTabCornerRadius startAngle:180 endAngle:270 clockwise:NO];
	}

	// Set up a fill bezier based on the outline path
	[fillBezier appendBezierPath:outlineBezier];

	// If one edge is missing, apply a local fill to the other edge
	if (drawRightEdge && !drawLeftEdge) {
		[fillBezier lineToPoint:NSMakePoint(aRect.origin.x + aRect.size.width - kPSMSequelProTabCornerRadius + 0.5, aRect.origin.y)];
		[fillBezier lineToPoint:NSMakePoint(aRect.origin.x + aRect.size.width - kPSMSequelProTabCornerRadius + 0.5, aRect.origin.y + aRect.size.height)];
	} else if (!drawRightEdge && drawLeftEdge) {
		[fillBezier lineToPoint:NSMakePoint(aRect.origin.x + 0.5 + kPSMSequelProTabCornerRadius, aRect.origin.y)];
	}

	// Set the tab outer shadow and draw the shadow
	[NSGraphicsContext saveGraphicsState];
	NSShadow *shadow = [[NSShadow alloc] init];
	[shadow setShadowBlurRadius:4];
	[shadow setShadowColor:shadowColor];
	[shadow setShadowOffset:NSMakeSize(0, 0)];
	[shadow set];
	[outlineBezier stroke];
	[shadow release];
	[NSGraphicsContext restoreGraphicsState];

	// Fill the tab with a solid colour
	[fillColor set];
	[fillBezier fill];

	// Re-stroke without shadow over the fill.
	[lineColor set];
	[outlineBezier stroke];

	// Add a bottom line to the active tab, with a slight inner glow
	if ([cell state] == NSOnState) {
		outlineBezier = [NSBezierPath bezierPath];
		if (drawLeftEdge) {
			[outlineBezier appendBezierPathWithArcWithCenter:bottomLeftArcCenter radius:kPSMSequelProTabCornerRadius startAngle:180 endAngle:90 clockwise:YES];
		} else {
			[outlineBezier moveToPoint:NSMakePoint(aRect.origin.x, aRect.origin.y + aRect.size.height - 0.5)];
		}
		if (drawRightEdge) {
			[outlineBezier appendBezierPathWithArcWithCenter:bottomRightArcCenter radius:kPSMSequelProTabCornerRadius startAngle:90 endAngle:0 clockwise:YES];
		} else {
			[outlineBezier lineToPoint:NSMakePoint(aRect.origin.x + aRect.size.width, aRect.origin.y + aRect.size.height - 0.5)];
		}
		shadow = [[NSShadow alloc] init];
		[shadow setShadowBlurRadius:1];
		[shadow setShadowColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.3]];
		[shadow setShadowOffset:NSMakeSize(0, 1)];
		[shadow set];
		[outlineBezier stroke];

	// Add the shadow over the tops of background tabs
	} else if (drawLeftEdge || drawRightEdge) {

		// Set up a CGContext so that drawing can be clipped (to prevent shadow issues)
		CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
		CGContextSaveGState(context);
		NSPoint topLeft, topRight;
		CGFloat drawAlpha = [[tabBar window] isKeyWindow] ? 1.0 : 0.7;
		outlineBezier = [NSBezierPath bezierPath];

		// Calculate the endpoints of the line
		if (drawLeftEdge) {
			topLeft = NSMakePoint(aRect.origin.x + 0.5 - kPSMSequelProTabCornerRadius + 2, aRect.origin.y + 0.5);
		} else {
			topLeft = NSMakePoint(aRect.origin.x + aRect.size.width - kPSMSequelProTabCornerRadius + 0.5, aRect.origin.y + 0.5);
		}
		if (drawRightEdge) {
			topRight = NSMakePoint(aRect.origin.x + aRect.size.width + kPSMSequelProTabCornerRadius + 0.5 - 2, aRect.origin.y + 0.5);
		} else {
			topRight = NSMakePoint(aRect.origin.x + 0.5 + kPSMSequelProTabCornerRadius, aRect.origin.y + 0.5);
		}

		// Set up the line and clipping point
		CGContextClipToRect(context, (CGRect)NSMakeRect(topLeft.x, topLeft.y, topRight.x-topLeft.x, aRect.size.height));
		[[NSColor colorWithCalibratedWhite:0.2 alpha:drawAlpha] set];
		[outlineBezier moveToPoint:topLeft];
		[outlineBezier lineToPoint:topRight];

		// Set up the shadow
		shadow = [[NSShadow alloc] init];
		[shadow setShadowBlurRadius:4];
		[shadow setShadowColor:[NSColor colorWithCalibratedWhite:0.2 alpha:drawAlpha]];
		[shadow setShadowOffset:NSMakeSize(0,0)];
		[shadow set];

		// Draw, and then restore the previous graphics state
		[outlineBezier stroke];
		CGContextRestoreGState(context);
	}
	
	[NSGraphicsContext restoreGraphicsState];
	
    [self drawInteriorWithTabCell:cell inView:[cell controlView]];
}


// Step 4
- (void)drawInteriorWithTabCell:(PSMTabBarCell *)cell inView:(NSView*)controlView
{
    NSRect cellFrame = [cell frame];
	CGFloat insetLabelWidth = 0;
	BOOL tabBarIsRightOfSelectedTab = NO;
	
	// Determine if the selected tab is right of this tab
	for (PSMTabBarCell *aCell in [tabBar cells]) {
		if (aCell == cell) break;
		if ([aCell state] == NSOnState) {
			tabBarIsRightOfSelectedTab = YES;
			break;
		}
	}
    
    // close button
    if ([cell hasCloseButton] && ![cell isCloseButtonSuppressed] && [cell isHighlighted]) {
		
        NSSize closeButtonSize = NSZeroSize;
        NSRect closeButtonRect = [cell closeButtonRectForFrame:cellFrame];
        NSImage * closeButton = nil;

        closeButton = [cell isEdited] ? metalCloseDirtyButton : metalCloseButton;
		
        if ([cell closeButtonOver]) closeButton = [cell isEdited] ? metalCloseDirtyButtonOver : metalCloseButtonOver;
        if ([cell closeButtonPressed]) closeButton = [cell isEdited] ? metalCloseDirtyButtonDown : metalCloseButtonDown;
        
        closeButtonSize = [closeButton size];
		
        if ([controlView isFlipped]) {
            closeButtonRect.origin.y += closeButtonRect.size.height;
        }
        
        [closeButton compositeToPoint:closeButtonRect.origin operation:NSCompositeSourceOver fraction:1.0];
    }
	insetLabelWidth += [metalCloseButton size].width + kPSMTabBarCellPadding;
    
    // icon
    if ([cell hasIcon]) {
        NSRect iconRect = [self iconRectForTabCell:cell];
        NSImage *icon = [[[cell representedObject] identifier] icon];
        
		if ([controlView isFlipped]) {
			iconRect.origin.y += iconRect.size.height;
        }
        
        // center in available space (in case icon image is smaller than kPSMTabBarIconWidth)
        if ([icon size].width < kPSMTabBarIconWidth) {
            iconRect.origin.x += (kPSMTabBarIconWidth - [icon size].width)/2.0;
        }
        if ([icon size].height < kPSMTabBarIconWidth) {
            iconRect.origin.y -= (kPSMTabBarIconWidth - [icon size].height)/2.0;
        }
        
		[icon compositeToPoint:iconRect.origin operation:NSCompositeSourceOver fraction:1.0];
        
        // scoot label over
        insetLabelWidth += iconRect.size.width + kPSMTabBarCellPadding;
    }
    
    // label rect
    NSRect labelRect;
    labelRect.origin.x = cellFrame.origin.x + MARGIN_X + insetLabelWidth;
    labelRect.size.width = cellFrame.size.width - (labelRect.origin.x - cellFrame.origin.x) - insetLabelWidth - MARGIN_X;
    labelRect.size.height = cellFrame.size.height;
    labelRect.origin.y = cellFrame.origin.y + MARGIN_Y;
    
    if ([cell state] == NSOnState) {
        //labelRect.origin.y -= 1;
    }
    
    if (![[cell indicator] isHidden]) {
        labelRect.size.width -= (kPSMTabBarIndicatorWidth + kPSMTabBarCellPadding);
    }
    
    // object counter
    if ([cell count] > 0) {
        [[cell countColor] ?: [NSColor colorWithCalibratedWhite:0.3 alpha:0.6] set];
        NSBezierPath *path = [NSBezierPath bezierPath];
        NSRect myRect = [self objectCounterRectForTabCell:cell];
        if ([cell state] == NSOnState) {
            //myRect.origin.y -= 1.0;
        }
        [path moveToPoint:NSMakePoint(myRect.origin.x + kPSMSequelProObjectCounterRadius, myRect.origin.y)];
        [path lineToPoint:NSMakePoint(myRect.origin.x + myRect.size.width - kPSMSequelProObjectCounterRadius, myRect.origin.y)];
        [path appendBezierPathWithArcWithCenter:NSMakePoint(myRect.origin.x + myRect.size.width - kPSMSequelProObjectCounterRadius, myRect.origin.y + kPSMSequelProObjectCounterRadius) radius:kPSMSequelProObjectCounterRadius startAngle:270.0 endAngle:90.0];
        [path lineToPoint:NSMakePoint(myRect.origin.x + kPSMSequelProObjectCounterRadius, myRect.origin.y + myRect.size.height)];
        [path appendBezierPathWithArcWithCenter:NSMakePoint(myRect.origin.x + kPSMSequelProObjectCounterRadius, myRect.origin.y + kPSMSequelProObjectCounterRadius) radius:kPSMSequelProObjectCounterRadius startAngle:90.0 endAngle:270.0];
        [path fill];
        
        // draw attributed string centered in area
        NSRect counterStringRect;
        NSAttributedString *counterString = [self attributedObjectCountValueForTabCell:cell];
        counterStringRect.size = [counterString size];
        counterStringRect.origin.x = myRect.origin.x + ((myRect.size.width - counterStringRect.size.width) / 2.0) + 0.25;
        counterStringRect.origin.y = myRect.origin.y + ((myRect.size.height - counterStringRect.size.height) / 2.0) + 0.5;
        [counterString drawInRect:counterStringRect];
        
        // shrink label width to make room for object counter
        labelRect.size.width -= myRect.size.width + kPSMTabBarCellPadding;
    }
    
    // draw label
    [[cell attributedStringValue] drawInRect:labelRect];
}

   	

#pragma mark -
#pragma mark Archiving

- (void)encodeWithCoder:(NSCoder *)aCoder 
{
    //[super encodeWithCoder:aCoder];
/*    
    if ([aCoder allowsKeyedCoding]) {
        [aCoder encodeObject:metalCloseButton forKey:@"metalCloseButton"];
        [aCoder encodeObject:metalCloseButtonDown forKey:@"metalCloseButtonDown"];
        [aCoder encodeObject:metalCloseButtonOver forKey:@"metalCloseButtonOver"];
        [aCoder encodeObject:metalCloseDirtyButton forKey:@"metalCloseDirtyButton"];
        [aCoder encodeObject:metalCloseDirtyButtonDown forKey:@"metalCloseDirtyButtonDown"];
        [aCoder encodeObject:metalCloseDirtyButtonOver forKey:@"metalCloseDirtyButtonOver"];
        [aCoder encodeObject:_addTabButtonImage forKey:@"addTabButtonImage"];
        [aCoder encodeObject:_addTabButtonPressedImage forKey:@"addTabButtonPressedImage"];
        [aCoder encodeObject:_addTabButtonRolloverImage forKey:@"addTabButtonRolloverImage"];
    }
*/    
}

- (id)initWithCoder:(NSCoder *)aDecoder 
{
    self = [self init];
    if (self) {

/*    
        if ([aDecoder allowsKeyedCoding]) {
            metalCloseButton = [[aDecoder decodeObjectForKey:@"metalCloseButton"] retain];
            metalCloseButtonDown = [[aDecoder decodeObjectForKey:@"metalCloseButtonDown"] retain];
            metalCloseButtonOver = [[aDecoder decodeObjectForKey:@"metalCloseButtonOver"] retain];
            metalCloseDirtyButton = [[aDecoder decodeObjectForKey:@"metalCloseDirtyButton"] retain];
            metalCloseDirtyButtonDown = [[aDecoder decodeObjectForKey:@"metalCloseDirtyButtonDown"] retain];
            metalCloseDirtyButtonOver = [[aDecoder decodeObjectForKey:@"metalCloseDirtyButtonOver"] retain];
            _addTabButtonImage = [[aDecoder decodeObjectForKey:@"addTabButtonImage"] retain];
            _addTabButtonPressedImage = [[aDecoder decodeObjectForKey:@"addTabButtonPressedImage"] retain];
            _addTabButtonRolloverImage = [[aDecoder decodeObjectForKey:@"addTabButtonRolloverImage"] retain];
        }
*/        
    }
    return self;
}

@end
