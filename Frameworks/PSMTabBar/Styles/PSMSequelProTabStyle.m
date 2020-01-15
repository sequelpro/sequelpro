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
//  More info at <https://github.com/sequelpro/sequelpro>

#import "PSMSequelProTabStyle.h"
#import "PSMTabBarCell.h"
#import "PSMTabBarControl.h"
#import "NSBezierPath_AMShading.h"
#import "PSMTabDragAssistant.h"

#define kPSMSequelProObjectCounterRadius 7.0f
#define kPSMSequelProCounterMinWidth 20
#define kPSMSequelProTabCornerRadius 0

#ifndef __MAC_10_10
#define __MAC_10_10 101000
#endif

#if __MAC_OS_X_VERSION_MAX_ALLOWED < __MAC_10_10
// This code is available since 10.8 but public only since 10.10
typedef struct {
	NSInteger major;
	NSInteger minor;
	NSInteger patch;
} NSOperatingSystemVersion;

@interface NSProcessInfo ()

- (NSOperatingSystemVersion)operatingSystemVersion;
- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version;

@end
#endif

@interface PSMSequelProTabStyle ()

- (NSColor *)_lineColorForTabCellDrawing;
- (void)_drawTabCell:(PSMTabBarCell *)cell withBackgroundColor:(NSColor *)backgroundColor lineColor:(NSColor *)lineColor;
- (BOOL)isInDarkMode;

@end

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
		// Avoid call to the deprecated (10.8+) Gestalt() function.
		// This code actually belongs in it's own class, but since both PSMTabBar.framework
		// and SP itself would need it, the loader will complain about a duplicate class implementation.
		NSProcessInfo *procInfo = [NSProcessInfo processInfo];

		if ([procInfo respondsToSelector:@selector(isOperatingSystemAtLeastVersion:)]) {
			NSOperatingSystemVersion os10_7_0 = {10,7,0};
			NSOperatingSystemVersion os10_10_0 = {10,10,0};
			NSOperatingSystemVersion os10_14_0 = {10,14,0};

			systemVersionIsAtLeast10_7_0 = [procInfo isOperatingSystemAtLeastVersion:os10_7_0];
			systemVersionIsAtLeast10_10_0 = [procInfo isOperatingSystemAtLeastVersion:os10_10_0];
			systemVersionIsAtLeast10_14_0 = [procInfo isOperatingSystemAtLeastVersion:os10_14_0];
		}
		else {
			SInt32 versionMajor = 0;
			SInt32 versionMinor = 0;
			Gestalt(gestaltSystemVersionMajor, &versionMajor);
			Gestalt(gestaltSystemVersionMinor, &versionMinor);
			
			systemVersionIsAtLeast10_7_0  = (versionMajor > 10 || (versionMajor == 10 && versionMinor >= 7));
			systemVersionIsAtLeast10_10_0 = (versionMajor > 10 || (versionMajor == 10 && versionMinor >= 10));
			systemVersionIsAtLeast10_14_0 = (versionMajor > 10 || (versionMajor == 10 && versionMinor >= 14));
		}

		NSBundle *bundle = [PSMTabBarControl bundle];

        sequelProCloseButton = [[NSImage alloc] initByReferencingFile:[bundle pathForImageResource:@"SequelProTabClose"]];
        sequelProCloseButtonDown = [[NSImage alloc] initByReferencingFile:[bundle pathForImageResource:@"SequelProTabClose_Pressed"]];
        sequelProCloseButtonOver = [[NSImage alloc] initByReferencingFile:[bundle pathForImageResource:@"SequelProTabClose_Rollover"]];

        sequelProCloseDirtyButton = [[NSImage alloc] initByReferencingFile:[bundle pathForImageResource:@"SequelProTabDirty"]];
        sequelProCloseDirtyButtonDown = [[NSImage alloc] initByReferencingFile:[bundle pathForImageResource:@"SequelProTabDirty_Pressed"]];
        sequelProCloseDirtyButtonOver = [[NSImage alloc] initByReferencingFile:[bundle pathForImageResource:@"SequelProTabDirty_Rollover"]];
                
        _addTabButtonImage = [[NSImage alloc] initByReferencingFile:[bundle pathForImageResource:@"AddTabButton"]];
        _addTabButtonPressedImage = [[NSImage alloc] initByReferencingFile:[bundle pathForImageResource:@"AddTabButton"]];
        _addTabButtonRolloverImage = [[NSImage alloc] initByReferencingFile:[bundle pathForImageResource:@"AddTabButton"]];
		
		_objectCountStringAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:
										[[NSFontManager sharedFontManager] convertFont:[NSFont fontWithName:@"Helvetica" size:11.0f] toHaveTrait:NSBoldFontMask], NSFontAttributeName,
										[[NSColor whiteColor] colorWithAlphaComponent:0.85f], NSForegroundColorAttributeName, nil, nil];
    }
    return self;
}

- (void)dealloc
{
    [sequelProCloseButton release];
    [sequelProCloseButtonDown release];
    [sequelProCloseButtonOver release];
    [sequelProCloseDirtyButton release];
    [sequelProCloseDirtyButtonDown release];
    [sequelProCloseDirtyButtonOver release];
    [_addTabButtonImage release];
    [_addTabButtonPressedImage release];
    [_addTabButtonRolloverImage release];
    
	[_objectCountStringAttributes release];
	
    [super dealloc];
}

#pragma mark -
#pragma mark Detect Dark Aqua Mode

- (BOOL)isInDarkMode
{
	if(systemVersionIsAtLeast10_14_0) {
		NSAppearance *appearance = [NSAppearance currentAppearance] ?: [NSApp effectiveAppearance];
		NSAppearanceName match = [appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];

		if ([NSAppearanceNameDarkAqua isEqualToString:match]) {
			return YES;
		}
	}
	return NO;
}

#pragma mark -
#pragma mark Control Specific

- (CGFloat)leftMarginForTabBarControl
{
    return 0.0f;
}

- (CGFloat)rightMarginForTabBarControl
{
    return 10.0f; // enough to fit plus button
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
			dragRect.origin.x -= 5.0f;
			dragRect.size.width += 10.0f;
		} else {
			dragRect.size.height += 1.0f;
			dragRect.origin.y -= 1.0f;
			dragRect.origin.x += 2.0f;
			dragRect.size.width -= 3.0f;
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
    result.size = [sequelProCloseButton size];
    result.origin.x = cellFrame.origin.x + MARGIN_X;
    result.origin.y = cellFrame.origin.y + MARGIN_Y + 2.0f;
    
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
        result.origin.x += [sequelProCloseButton size].width + kPSMTabBarCellPadding;
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
    countWidth += (2 * kPSMSequelProObjectCounterRadius - 6.0f);
    if (countWidth < kPSMSequelProCounterMinWidth) {
        countWidth = kPSMSequelProCounterMinWidth;
    }
    
    NSRect result;
    result.size = NSMakeSize(countWidth, 2 * kPSMSequelProObjectCounterRadius); // temp
    result.origin.x = cellFrame.origin.x + cellFrame.size.width - MARGIN_X - result.size.width;
    result.origin.y = cellFrame.origin.y + MARGIN_Y + 1.0f;
    
    if (![[cell indicator] isHidden]) {
        result.origin.x -= kPSMTabBarIndicatorWidth + kPSMTabBarCellPadding;
    }
    
    return result;
}

- (CGFloat)minimumWidthOfTabCell:(PSMTabBarCell *)cell
{
    CGFloat resultWidth = 0.0f;
    
    // left margin
    resultWidth = MARGIN_X;
    
    // close button?
    if ([cell hasCloseButton] && ![cell isCloseButtonSuppressed]) {
        resultWidth += [sequelProCloseButton size].width + kPSMTabBarCellPadding;
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
    
    return ceilf(resultWidth);
}

- (CGFloat)desiredWidthOfTabCell:(PSMTabBarCell *)cell
{
    CGFloat resultWidth = 0.0f;
    
    // left margin
    resultWidth = MARGIN_X;
    
    // close button?
    if ([cell hasCloseButton] && ![cell isCloseButtonSuppressed])
        resultWidth += [sequelProCloseButton size].width + kPSMTabBarCellPadding;
    
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
    
    return ceilf(resultWidth);
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
    [attrStr addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:11.0f] range:range];
    [attrStr addAttribute:NSForegroundColorAttributeName value:[[NSColor textColor] colorWithAlphaComponent:0.75f] range:range];
    
    // Add shadow attribute
    NSShadow* textShadow;
    textShadow = [[[NSShadow alloc] init] autorelease];
    CGFloat shadowAlpha;
    if (([cell state] == NSOnState) || [cell isHighlighted]) {
        shadowAlpha = 0.8f;
    } else {
        shadowAlpha = 0.5f;
    }
    [textShadow setShadowColor:[NSColor colorWithCalibratedWhite:1.0f alpha:shadowAlpha]];
    [textShadow setShadowOffset:NSMakeSize(0, -1)];
    [textShadow setShadowBlurRadius:1.0f];
	
    // Paragraph Style for Truncating Long Text
    static NSMutableParagraphStyle *TruncatingTailParagraphStyle = nil;
    if (!TruncatingTailParagraphStyle) {
        TruncatingTailParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
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
        labelRect.size.height -= 4.0f;
        labelRect.origin.y += 4.0f;
        NSMutableAttributedString *attrStr;
        NSString *contents = @"PSMTabBarControl";
        attrStr = [[[NSMutableAttributedString alloc] initWithString:contents] autorelease];
		NSRange range = NSMakeRange(0, [contents length]);
        [attrStr addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:11.0f] range:range];
        NSMutableParagraphStyle *centeredParagraphStyle = nil;
        
		if (!centeredParagraphStyle) {
            centeredParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
            [centeredParagraphStyle setAlignment:NSCenterTextAlignment];
        }
        [attrStr addAttribute:NSParagraphStyleAttributeName value:centeredParagraphStyle range:range];
        [centeredParagraphStyle release];
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
	// Draw for our whole bounds; it'll be automatically clipped to fit the appropriate drawing area
	rect = [tabBar bounds];
	
	// Find active cell
	PSMTabBarCell *selectedCell = nil;

	for (PSMTabBarCell *aCell in [tabBar cells]) {
		if (aCell.tabState & PSMTab_SelectedMask) {
			selectedCell = aCell;
			break;
		}
	}

	[NSGraphicsContext saveGraphicsState];
	[[NSGraphicsContext currentContext] setShouldAntialias:NO];

	float backgroundCalibratedWhite = 0.73f;

	float lineCalibratedWhite = [[NSColor grayColor] whiteComponent];
	float shadowAlpha = 0.4f;

	// When the window is in the background, tone down the colours
	if ((![[tabBar window] isMainWindow] && ![[[tabBar window] attachedSheet] isMainWindow]) || ![NSApp isActive]) {
		backgroundCalibratedWhite = 0.86f;
		lineCalibratedWhite = 0.49f;
		shadowAlpha = 0.3f;
	}
	
	if ([self isInDarkMode]) {
		backgroundCalibratedWhite -= 0.55f;
		lineCalibratedWhite -= 0.39f;
		shadowAlpha -= 0.1f;
	}
	
	// Fill in background of tab bar
	if (tabBar.cells.count != 1) { // multiple tabs - fill with background color
		[[NSColor colorWithCalibratedWhite:backgroundCalibratedWhite alpha:1.0f] set];
	} else { // When there's only one tab, the tabs are probably hidden, so use the selected cell's highlight colour as our background colour
		[[self fillColorForCell:selectedCell] set];
	}
	NSRectFill(NSMakeRect(rect.origin.x, rect.origin.y, rect.size.width, rect.size.height));

	// Draw horizontal line across the top edge
	[[NSColor colorWithCalibratedWhite:lineCalibratedWhite alpha:1.0f] set];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(rect.origin.x, rect.origin.y + 0.5f) toPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + 0.5f)];
	
	// Draw horizontal line across the bottom edge
	[NSBezierPath strokeLineFromPoint:NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height - 0.5f) toPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height - 0.5f)];
	
	[NSGraphicsContext restoreGraphicsState];
}

// Step 3
- (void)drawTabCell:(PSMTabBarCell *)cell
{
	// Don't draw cells when collapsed
	if ([tabBar isTabBarHidden]) return;

	NSColor *lineColor = [self _lineColorForTabCellDrawing];
	NSColor *fillColor = [self fillColorForCell:cell];

	[self _drawTabCell:cell withBackgroundColor:fillColor lineColor:lineColor];
	
	[self drawInteriorWithTabCell:cell inView:[cell customControlView]];
}

/**
 * Same as above, but doesn't draw the left hand (right had of the actual tab) border for the tab drag image.
 */
- (void)drawTabCellForDragImage:(PSMTabBarCell *)cell
{
	NSColor *fillColor = [self fillColorForCell:cell];

	[self _drawTabCell:cell withBackgroundColor:fillColor lineColor:nil];

	[self drawInteriorWithTabCell:cell inView:[cell customControlView]];
}

// Step 4
- (void)drawInteriorWithTabCell:(PSMTabBarCell *)cell inView:(NSView*)controlView
{
    NSRect cellFrame = [cell frame];
	CGFloat insetLabelWidth = 0;

    // close button
    if ([cell hasCloseButton] && ![cell isCloseButtonSuppressed] && [cell isHighlighted]) {
		
        NSRect closeButtonRect = [cell closeButtonRectForFrame:cellFrame];
        NSImage *closeButton = nil;

        closeButton = [cell isEdited] ? sequelProCloseDirtyButton : sequelProCloseButton;
		
        if ([cell closeButtonOver]) closeButton = [cell isEdited] ? sequelProCloseDirtyButtonOver : sequelProCloseButtonOver;
        if ([cell closeButtonPressed]) closeButton = [cell isEdited] ? sequelProCloseDirtyButtonDown : sequelProCloseButtonDown;

		// Slightly darken background tabs on mouse over
		if ([cell state] == NSOffState) {
			NSColor *lineColor = [self _lineColorForTabCellDrawing];
			NSColor *fillColor = [[self fillColorForCell:cell] shadowWithLevel:0.03f];

			[self _drawTabCell:cell withBackgroundColor:fillColor lineColor:lineColor];
		}

		[closeButton drawInRect:closeButtonRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0f respectFlipped:YES hints:nil];
    }
    
    // icon
    if ([cell hasIcon]) {
        NSRect iconRect = [self iconRectForTabCell:cell];
        NSImage *icon = [(id)[[cell representedObject] identifier] icon];
        
        // center in available space (in case icon image is smaller than kPSMTabBarIconWidth)
        if ([icon size].width < kPSMTabBarIconWidth) {
            iconRect.origin.x += (kPSMTabBarIconWidth - [icon size].width)/2.0f;
        }
        if ([icon size].height < kPSMTabBarIconWidth) {
            iconRect.origin.y -= (kPSMTabBarIconWidth - [icon size].height)/2.0f;
        }
        
		[icon drawInRect:iconRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0f respectFlipped:YES hints:nil];

        // scoot label over
        insetLabelWidth += iconRect.size.width + kPSMTabBarCellPadding;
    }
	else {
		insetLabelWidth += [sequelProCloseButton size].width + kPSMTabBarCellPadding;
	}
    
    // label rect
    NSRect labelRect;
    labelRect.origin.x = cellFrame.origin.x + MARGIN_X + insetLabelWidth;
    labelRect.size.width = cellFrame.size.width - (labelRect.origin.x - cellFrame.origin.x) - insetLabelWidth - MARGIN_X;
    labelRect.size.height = cellFrame.size.height;
    labelRect.origin.y = cellFrame.origin.y + MARGIN_Y;
    
    // object counter
    if ([cell count] > 0) {
        [[cell countColor] ?: [NSColor colorWithCalibratedWhite:0.3f alpha:0.6f] set];
        NSBezierPath *path = [NSBezierPath bezierPath];
        NSRect myRect = [self objectCounterRectForTabCell:cell];
        [path moveToPoint:NSMakePoint(myRect.origin.x + kPSMSequelProObjectCounterRadius, myRect.origin.y)];
        [path lineToPoint:NSMakePoint(myRect.origin.x + myRect.size.width - kPSMSequelProObjectCounterRadius, myRect.origin.y)];
        [path appendBezierPathWithArcWithCenter:NSMakePoint(myRect.origin.x + myRect.size.width - kPSMSequelProObjectCounterRadius, myRect.origin.y + kPSMSequelProObjectCounterRadius) radius:kPSMSequelProObjectCounterRadius startAngle:270.0f endAngle:90.0f];
        [path lineToPoint:NSMakePoint(myRect.origin.x + kPSMSequelProObjectCounterRadius, myRect.origin.y + myRect.size.height)];
        [path appendBezierPathWithArcWithCenter:NSMakePoint(myRect.origin.x + kPSMSequelProObjectCounterRadius, myRect.origin.y + kPSMSequelProObjectCounterRadius) radius:kPSMSequelProObjectCounterRadius startAngle:90.0f endAngle:270.0f];
        [path fill];
        
        // draw attributed string centered in area
        NSRect counterStringRect;
        NSAttributedString *counterString = [self attributedObjectCountValueForTabCell:cell];
        counterStringRect.size = [counterString size];
        counterStringRect.origin.x = myRect.origin.x + ((myRect.size.width - counterStringRect.size.width) / 2.0f) + 0.25f;
        counterStringRect.origin.y = myRect.origin.y + ((myRect.size.height - counterStringRect.size.height) / 2.0f) + 0.5f;
        [counterString drawInRect:counterStringRect];
        
        // shrink label width to make room for object counter
        labelRect.size.width -= myRect.size.width + kPSMTabBarCellPadding;
    }
	
	// determine text colour
	NSAttributedString *labelString = cell.attributedStringValue;
	if (cell.state != NSOnState) {
		NSMutableAttributedString *newLabelString = labelString.mutableCopy;
		NSColor *textColor = [NSColor darkGrayColor];
		if ([self isInDarkMode]) {
			textColor = [cell backgroundColor] ? [NSColor blackColor] : [NSColor lightGrayColor];
		}
		
		[newLabelString addAttribute:NSForegroundColorAttributeName value:textColor range:NSMakeRange(0, newLabelString.length)];
		labelString = newLabelString.copy;
	}
	
	// draw label
	[labelString drawInRect:labelRect];
}

- (NSColor *)fillColorForCell:(PSMTabBarCell *)cell
{
	NSColor *fillColor = nil;

	// Set up colours
	if (([[tabBar window] isMainWindow] || [[[tabBar window] attachedSheet] isMainWindow]) && [NSApp isActive]) {
		if ([cell state] == NSOnState) { //active window, active cell
			float tabWhiteComponent = 0.795f;
			if (!tabBar.window.toolbar.isVisible) tabWhiteComponent += 0.02f;
			if ([self isInDarkMode]) tabWhiteComponent -= 0.55f;
			
			fillColor = [NSColor colorWithCalibratedWhite:tabWhiteComponent alpha:1.0f];
			
			if([cell backgroundColor]) {
				fillColor = [self isInDarkMode] ? [[cell backgroundColor] shadowWithLevel:0.25] : [cell backgroundColor];;
			}
		} else { //active window, background cell
			float tabWhiteComponent = 0.68f;
			if ([self isInDarkMode]) tabWhiteComponent -= 0.51f;
			
			fillColor = [NSColor colorWithCalibratedWhite:tabWhiteComponent alpha:1.0f];
			
			if([cell backgroundColor]) {
				//should be a slightly darker variant of the color
				fillColor = [self isInDarkMode] ? [[cell backgroundColor] shadowWithLevel:0.40] : [[cell backgroundColor] shadowWithLevel:0.15];
				
				// also desaturate the color
				fillColor = [NSColor colorWithCalibratedHue:fillColor.hueComponent saturation:fillColor.saturationComponent * 0.4 brightness:fillColor.brightnessComponent alpha:1.0f];
			}
		}
	} else {
		if ([cell state] == NSOnState) { //background window, active cell
			float tabWhiteComponent = 0.957f;
			if (!tabBar.window.toolbar.isVisible) tabWhiteComponent += 0.01f;
			if ([self isInDarkMode]) tabWhiteComponent -= 0.75f;

			//create a slightly desaturated variant (gray can't be desaturated so we instead make it brighter)
			if (cell.backgroundColor) {
				fillColor = [NSColor colorWithCalibratedHue:cell.backgroundColor.hueComponent saturation:cell.backgroundColor.saturationComponent brightness:(cell.backgroundColor.brightnessComponent * 1.28) alpha:1.0f];
			} else {
				fillColor = [NSColor colorWithCalibratedWhite:tabWhiteComponent alpha:1.0f];
			}
			
		} else { //background window, background cell
			float tabWhiteComponent = 0.86f;
			if ([self isInDarkMode]) tabWhiteComponent -= 0.7f;
			
			fillColor = [NSColor colorWithCalibratedWhite:tabWhiteComponent alpha:1.0f];
			
			//make it dark first, then desaturate
			if (cell.backgroundColor) {
				NSColor *dark = [[cell backgroundColor] shadowWithLevel:0.15];
				fillColor = [NSColor colorWithCalibratedHue:dark.hueComponent saturation:dark.saturationComponent * 0.15 brightness:(dark.brightnessComponent * 1.28) alpha:1.0f];
			}
		}
	}
	
	return fillColor;
}

#pragma mark -
#pragma mark Archiving

- (void)encodeWithCoder:(NSCoder *)aCoder 
{
}

- (id)initWithCoder:(NSCoder *)aDecoder 
{
    return [self init];
}

#pragma mark -
#pragma mark Private API

- (void)_drawTabCell:(PSMTabBarCell *)cell withBackgroundColor:(NSColor *)backgroundColor lineColor:(NSColor *)lineColor
{
	NSRect cellFrame = [cell frame];

	// Setup fill rect
	NSRect fillRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y + 1, cellFrame.size.width, cellFrame.size.height - 1.5);

	// Draw
	[NSGraphicsContext saveGraphicsState];

	[backgroundColor set];
	NSRectFill(fillRect);

	if (lineColor) {

		// Stroke left edge
		[lineColor setStroke];

		NSPoint point1 = NSMakePoint(fillRect.origin.x + fillRect.size.width - 0.5, fillRect.origin.y);
		NSPoint point2 = NSMakePoint(fillRect.origin.x + fillRect.size.width - 0.5, fillRect.origin.y + fillRect.size.height);

		[NSBezierPath strokeLineFromPoint:point1 toPoint:point2];
	}

	[NSGraphicsContext restoreGraphicsState];
}

- (NSColor *)_lineColorForTabCellDrawing
{
	NSColor *lineColor = nil;
	
	if (([[tabBar window] isMainWindow] || [[[tabBar window] attachedSheet] isMainWindow]) && [NSApp isActive]) {
		if ([self isInDarkMode]) {
			lineColor = [NSColor colorWithCalibratedWhite:0.29f alpha:.42f];
		} else {
			lineColor = [NSColor grayColor];
		}
	}
	else {
		if ([self isInDarkMode]) {
			lineColor = [NSColor colorWithCalibratedWhite:0.19f alpha:.42f];
		} else {
			lineColor = [NSColor colorWithCalibratedWhite:0.49f alpha:1.0f];
		}
	}

	return lineColor;
}

@end
