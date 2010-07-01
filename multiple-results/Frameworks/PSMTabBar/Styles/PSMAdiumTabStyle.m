//
//  PSMAdiumTabStyle.m
//  PSMTabBarControl
//
//  Created by Kent Sutherland on 5/26/06.
//  Copyright 2006 Kent Sutherland. All rights reserved.
//

#import "PSMAdiumTabStyle.h"
#import "PSMTabBarCell.h"
#import "PSMTabBarControl.h"
#import "NSBezierPath_AMShading.h"

#define Adium_CellPadding 2
#define Adium_MARGIN_X 4
#define kPSMAdiumCounterPadding 3.0
#define kPSMAdiumObjectCounterRadius 7.0
#define kPSMAdiumCounterMinWidth 20

#define kPSMTabBarControlSourceListHeight	28

#define kPSMTabBarLargeImageHeight			kPSMTabBarControlSourceListHeight - 4
#define kPSMTabBarLargeImageWidth			kPSMTabBarLargeImageHeight

@implementation PSMAdiumTabStyle

- (NSString *)name
{
    return @"Adium";
}

#pragma mark -
#pragma mark Creation/Destruction

- (id)init
{
    if ( (self = [super init]) ) {
		[self loadImages];
		_drawsUnified = NO;
		_drawsRight = NO;
        
        _objectCountStringAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:[[NSFontManager sharedFontManager] convertFont:[NSFont fontWithName:@"Helvetica" size:11.0] toHaveTrait:NSBoldFontMask], NSFontAttributeName,
																					[[NSColor whiteColor] colorWithAlphaComponent:0.85], NSForegroundColorAttributeName,
																					nil, nil];
    }
    return self;
}

- (void)loadImages
{
	_closeButton = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"AquaTabClose_Front"]];
	_closeButtonDown = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"AquaTabClose_Front_Pressed"]];
	_closeButtonOver = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"AquaTabClose_Front_Rollover"]];

    _closeDirtyButton = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"AquaTabCloseDirty_Front"]];
    _closeDirtyButtonDown = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"AquaTabCloseDirty_Front_Pressed"]];
    _closeDirtyButtonOver = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"AquaTabCloseDirty_Front_Rollover"]];
        	
	_addTabButtonImage = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"AquaTabNew"]];
    _addTabButtonPressedImage = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"AquaTabNewPressed"]];
    _addTabButtonRolloverImage = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"AquaTabNewRollover"]];
	
	_gradientImage = [[NSImage alloc] initByReferencingFile:[[PSMTabBarControl bundle] pathForImageResource:@"AdiumGradient"]];
}

- (void)dealloc
{
	[_closeButton release];
	[_closeButtonDown release];
	[_closeButtonOver release];
    
	[_closeDirtyButton release];
	[_closeDirtyButtonDown release];
	[_closeDirtyButtonOver release];
	
	[_addTabButtonImage release];
	[_addTabButtonPressedImage release];
	[_addTabButtonRolloverImage release];
	
	[_gradientImage release];
	
    [_objectCountStringAttributes release];
    
    [super dealloc];
}

#pragma mark -
#pragma mark Drawing Style Accessors

- (BOOL)drawsUnified
{
	return _drawsUnified;
}

- (void)setDrawsUnified:(BOOL)value
{
	_drawsUnified = value;
}

- (BOOL)drawsRight
{
	return _drawsRight;
}

- (void)setDrawsRight:(BOOL)value
{
	_drawsRight = value;
}

#pragma mark -
#pragma mark Control Specific

- (CGFloat)leftMarginForTabBarControl
{
    return 3.0f;
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
	orientation = value;
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
	
	if ([cell tabState] & PSMTab_SelectedMask) {
		if (tabOrientation == PSMTabBarHorizontalOrientation) {
			dragRect.size.width++;
			dragRect.size.height -= 2.0;
		}
	}
	
	return dragRect;
}

- (BOOL)closeButtonIsEnabledForCell:(PSMTabBarCell *)cell
{
	return ([cell hasCloseButton] && ![cell isCloseButtonSuppressed]);
	
}
- (NSRect)closeButtonRectForTabCell:(PSMTabBarCell *)cell withFrame:(NSRect)cellFrame
{
	if ([self closeButtonIsEnabledForCell:cell] == NO) {
		return NSZeroRect;
	}

	NSRect result;
	result.size = [_closeButton size];

	switch (orientation) {
		case PSMTabBarHorizontalOrientation:
		{
			result.origin.x = cellFrame.origin.x + Adium_MARGIN_X;
			result.origin.y = cellFrame.origin.y + MARGIN_Y + 2.0;
			if ([cell state] == NSOnState) {
				result.origin.y -= 1;
			}
			break;
		}			

		case PSMTabBarVerticalOrientation:
		{
			result.origin.x = NSMaxX(cellFrame) - (Adium_MARGIN_X*2) - NSWidth(result);
			result.origin.y = NSMinY(cellFrame) + (NSHeight(cellFrame) / 2) - (result.size.height / 2) + 1;
			break;
		}
	}

	return result;
}

- (NSRect)iconRectForTabCell:(PSMTabBarCell *)cell
{
	if ([cell hasIcon] == NO) {
		return NSZeroRect;
	}

	NSRect cellFrame = [cell frame];
	NSImage *icon = [[[cell representedObject] identifier] icon];
	NSSize	iconSize = [icon size];

	NSRect result;
	result.size = iconSize;

	switch (orientation)
	{
		case PSMTabBarHorizontalOrientation:
			result.origin.x = cellFrame.origin.x + Adium_MARGIN_X;
			result.origin.y = cellFrame.origin.y + MARGIN_Y;
			break;

		case PSMTabBarVerticalOrientation:
			result.origin.x = NSMaxX(cellFrame) - (Adium_MARGIN_X * 2) - NSWidth(result);
			result.origin.y = NSMinY(cellFrame) + (NSHeight(cellFrame) / 2) - (NSHeight(result) / 2) + 1;
			break;
	}

	// For horizontal tabs, center in available space (in case icon image is smaller than kPSMTabBarIconWidth)
	if (orientation == PSMTabBarHorizontalOrientation) {
		if (iconSize.width < kPSMTabBarIconWidth)
			result.origin.x += (kPSMTabBarIconWidth - iconSize.width) / 2.0;
		if (iconSize.height < kPSMTabBarIconWidth)
			result.origin.y += (kPSMTabBarIconWidth - iconSize.height) / 2.0;
	}

	if ([cell state] == NSOnState) {
		result.origin.y -= 1;
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
	result.origin.x = cellFrame.origin.x + cellFrame.size.width - Adium_MARGIN_X - kPSMTabBarIndicatorWidth;
	result.origin.y = cellFrame.origin.y + MARGIN_Y;

	if ([cell state] == NSOnState) {
		result.origin.y -= 1;
	}

	return result;
}

- (NSSize)sizeForObjectCounterRectForTabCell:(PSMTabBarCell *)cell
{
	NSSize size;
	CGFloat countWidth = [[self attributedObjectCountValueForTabCell:cell] size].width;

	countWidth += (2 * kPSMAdiumObjectCounterRadius - 6.0 + kPSMAdiumCounterPadding);
	
	if (countWidth < kPSMAdiumCounterMinWidth) {
		countWidth = kPSMAdiumCounterMinWidth;
	}
	
	size = NSMakeSize(countWidth, 2 * kPSMAdiumObjectCounterRadius); // temp

	return size;
}

- (NSRect)objectCounterRectForTabCell:(PSMTabBarCell *)cell
{
	NSRect cellFrame;
	NSRect result;

	if ([cell count] == 0) {
		return NSZeroRect;
	}

	cellFrame = [cell frame];
	result.size = [self sizeForObjectCounterRectForTabCell:cell];
	result.origin.x = NSMaxX(cellFrame) - Adium_MARGIN_X - result.size.width;
	result.origin.y = cellFrame.origin.y + MARGIN_Y + 1.0;

	if (![[cell indicator] isHidden]) {
		result.origin.x -= kPSMTabBarIndicatorWidth + Adium_CellPadding;
	}

	return result;
}

- (CGFloat)minimumWidthOfTabCell:(PSMTabBarCell *)cell
{
	CGFloat resultWidth = 0.0;

	// left margin
	resultWidth = Adium_MARGIN_X;

	// close button?
	if ([self closeButtonIsEnabledForCell:cell]) {
		resultWidth += MAX([_closeButton size].width, NSWidth([self iconRectForTabCell:cell])) + Adium_CellPadding;
	}

	// icon?
	/*if ([cell hasIcon]) {
		resultWidth += kPSMTabBarIconWidth + Adium_CellPadding;
	}*/

	// the label
	resultWidth += kPSMMinimumTitleWidth;

	// object counter?
	if (([cell count] > 0) && (orientation == PSMTabBarHorizontalOrientation)) {
		resultWidth += NSWidth([self objectCounterRectForTabCell:cell]) + Adium_CellPadding;
	}

	// indicator?
	if ([[cell indicator] isHidden] == NO) {
		resultWidth += Adium_CellPadding + kPSMTabBarIndicatorWidth;
	}

	// right margin
	resultWidth += Adium_MARGIN_X;

	return ceil(resultWidth);
}

- (CGFloat)desiredWidthOfTabCell:(PSMTabBarCell *)cell
{
	CGFloat resultWidth = 0.0;

	// left margin
	resultWidth = Adium_MARGIN_X;

	// close button?
	if ([self closeButtonIsEnabledForCell:cell]) {
		resultWidth += MAX([_closeButton size].width, NSWidth([self iconRectForTabCell:cell])) + Adium_CellPadding;
	}

	// icon?
	/*if ([cell hasIcon]) {
		resultWidth += kPSMTabBarIconWidth + Adium_CellPadding;
	}*/

	// the label
	resultWidth += [[cell attributedStringValue] size].width + Adium_CellPadding;

	// object counter?
	if (([cell count] > 0) && (orientation == PSMTabBarHorizontalOrientation)){
		resultWidth += [self objectCounterRectForTabCell:cell].size.width + Adium_CellPadding;
	}

	// indicator?
	if ([[cell indicator] isHidden] == NO) {
		resultWidth += Adium_CellPadding + kPSMTabBarIndicatorWidth;
	}

	// right margin
	resultWidth += Adium_MARGIN_X;

	return ceil(resultWidth);
}

- (CGFloat)tabCellHeight
{
	return ((orientation == PSMTabBarHorizontalOrientation) ? kPSMTabBarControlHeight : kPSMTabBarControlSourceListHeight);
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
	[attrStr addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:11.0] range:range];
	[attrStr addAttribute:NSForegroundColorAttributeName value:[NSColor controlTextColor] range:range];

	// Paragraph Style for Truncating Long Text
	static NSMutableParagraphStyle *TruncatingTailParagraphStyle = nil;
	if (!TruncatingTailParagraphStyle) {
		TruncatingTailParagraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] retain];
		[TruncatingTailParagraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
	}
	[attrStr addAttribute:NSParagraphStyleAttributeName value:TruncatingTailParagraphStyle range:range];

	return attrStr;
}

#pragma mark -
#pragma mark Cell Drawing

- (CGFloat)heightOfAttributedString:(NSAttributedString *)inAttributedString withWidth:(CGFloat)width
{
	static NSMutableDictionary *cache;
	if (!cache)
		cache = [[NSMutableDictionary alloc] init];
	if ([cache count] > 100) //100 items should be trivial in terms of memory overhead, but sufficient
		[cache removeAllObjects];
	NSNumber *cachedHeight = [cache objectForKey:inAttributedString];
	if (cachedHeight)
		return [cachedHeight doubleValue];
	else {
		NSTextStorage		*textStorage = [[NSTextStorage alloc] initWithAttributedString:inAttributedString];
		NSTextContainer 	*textContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(width, 1e7)];
		NSLayoutManager 	*layoutManager = [[NSLayoutManager alloc] init];
		
		//Configure
		[textContainer setLineFragmentPadding:0.0];
		[layoutManager addTextContainer:textContainer];
		[textStorage addLayoutManager:layoutManager];
		
		//Force the layout manager to layout its text
		(void)[layoutManager glyphRangeForTextContainer:textContainer];
		
		CGFloat height = [layoutManager usedRectForTextContainer:textContainer].size.height;
		
		[textStorage release];
		[textContainer release];
		[layoutManager release];
		
		[cache setObject:[NSNumber numberWithDouble:height] forKey:inAttributedString];
		
		return height;
	}
}

- (void)drawObjectCounterInCell:(PSMTabBarCell *)cell withRect:(NSRect)myRect
{
    myRect.size.width -= kPSMAdiumCounterPadding;
    myRect.origin.x += kPSMAdiumCounterPadding;
    
	[[cell countColor] ?: [NSColor colorWithCalibratedWhite:0.3 alpha:0.6] set];
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path setLineWidth:1.0];
	
	if ([cell state] == NSOnState) {
		myRect.origin.y -= 1.0;
	}
	
	[path moveToPoint:NSMakePoint(NSMinX(myRect) + kPSMAdiumObjectCounterRadius, NSMinY(myRect))];
	[path lineToPoint:NSMakePoint(NSMaxX(myRect) - kPSMAdiumObjectCounterRadius, NSMinY(myRect))];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(myRect) - kPSMAdiumObjectCounterRadius, NSMinY(myRect) + kPSMAdiumObjectCounterRadius) 
									 radius:kPSMAdiumObjectCounterRadius
								 startAngle:270.0
								   endAngle:90.0];
	[path lineToPoint:NSMakePoint(NSMinX(myRect) + kPSMAdiumObjectCounterRadius, NSMaxY(myRect))];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(myRect) + kPSMAdiumObjectCounterRadius, NSMinY(myRect) + kPSMAdiumObjectCounterRadius) 
									 radius:kPSMAdiumObjectCounterRadius
								 startAngle:90.0
								   endAngle:270.0];
	[path fill];
	
	// draw attributed string centered in area
	NSRect counterStringRect;
	NSAttributedString *counterString = [self attributedObjectCountValueForTabCell:cell];
	counterStringRect.size = [counterString size];
	counterStringRect.origin.x = myRect.origin.x + ((myRect.size.width - counterStringRect.size.width) / 2.0) + 0.25;
	counterStringRect.origin.y = myRect.origin.y + ((myRect.size.height - counterStringRect.size.height) / 2.0) + 0.5;
	[counterString drawInRect:counterStringRect];
}

- (NSBezierPath *)bezierPathWithRoundedRect:(NSRect)rect radius:(CGFloat)radius
{
    NSBezierPath	*path = [NSBezierPath bezierPath];
    NSPoint 		topLeft, topRight, bottomLeft, bottomRight;
    
    topLeft = NSMakePoint(rect.origin.x, rect.origin.y);
    topRight = NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y);
    bottomLeft = NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height);
    bottomRight = NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height);
	
    [path appendBezierPathWithArcWithCenter:NSMakePoint(topLeft.x + radius, topLeft.y + radius)
                                     radius:radius
                                 startAngle:180
                                   endAngle:270
                                  clockwise:NO];
    [path lineToPoint:NSMakePoint(topRight.x - radius, topRight.y)];
    
    [path appendBezierPathWithArcWithCenter:NSMakePoint(topRight.x - radius, topRight.y + radius)
                                     radius:radius
                                 startAngle:270
                                   endAngle:0
                                  clockwise:NO];
    [path lineToPoint:NSMakePoint(bottomRight.x, bottomRight.y - radius)];
    
    [path appendBezierPathWithArcWithCenter:NSMakePoint(bottomRight.x - radius, bottomRight.y - radius)
                                     radius:radius
                                 startAngle:0
                                   endAngle:90
                                  clockwise:NO];
    [path lineToPoint:NSMakePoint(bottomLeft.x + radius, bottomLeft.y)];
	
    [path appendBezierPathWithArcWithCenter:NSMakePoint(bottomLeft.x + radius, bottomLeft.y - radius)
                                     radius:radius
                                 startAngle:90
                                   endAngle:180
                                  clockwise:NO];
    [path lineToPoint:NSMakePoint(topLeft.x, topLeft.y + radius)];
	
    return path;
}

- (void)drawInteriorWithTabCell:(PSMTabBarCell *)cell inView:(NSView*)controlView
{
	NSRect cellFrame = [cell frame];
	
	if ((orientation == PSMTabBarVerticalOrientation) &&
		[cell hasLargeImage]) {
		NSImage *image = [[[cell representedObject] identifier] largeImage];
		cellFrame.origin.x += Adium_MARGIN_X;

		NSRect imageDrawingRect = NSMakeRect(cellFrame.origin.x,
											 cellFrame.origin.y - ((kPSMTabBarControlSourceListHeight - kPSMTabBarLargeImageHeight) / 2),
											 kPSMTabBarLargeImageWidth, kPSMTabBarLargeImageHeight);

		[NSGraphicsContext saveGraphicsState];
		//Use a transform to draw an arbitrary image in our flipped view
		NSAffineTransform *transform = [NSAffineTransform transform];
		[transform translateXBy:imageDrawingRect.origin.x yBy:(imageDrawingRect.origin.y + imageDrawingRect.size.height)];
		[transform scaleXBy:1.0 yBy:-1.0];
		[transform concat];

		imageDrawingRect.origin = NSMakePoint(0,0);
		
		//Create Rounding.
		CGFloat userIconRoundingRadius = (kPSMTabBarLargeImageWidth / 4.0);
		if (userIconRoundingRadius > 3) userIconRoundingRadius = 3;
		NSBezierPath	*clipPath = [self bezierPathWithRoundedRect:imageDrawingRect radius:userIconRoundingRadius];
		[clipPath addClip];

		[image drawInRect:imageDrawingRect
				 fromRect:NSMakeRect(0, 0, [image size].width, [image size].height)
				operation:NSCompositeSourceOver
				 fraction:1.0];

		[NSGraphicsContext restoreGraphicsState];

		cellFrame.origin.x += imageDrawingRect.size.width;
		cellFrame.size.width -= imageDrawingRect.size.width;
	}

	// label rect
	NSRect labelRect;
	labelRect.origin.x = cellFrame.origin.x + Adium_MARGIN_X;
	labelRect.size.width = cellFrame.size.width - (labelRect.origin.x - cellFrame.origin.x) - Adium_CellPadding;
	labelRect.size.height = cellFrame.size.height;
	switch (orientation)
	{
		case PSMTabBarHorizontalOrientation:
			labelRect.origin.y = cellFrame.origin.y + MARGIN_Y + 1.0;
			break;
		case PSMTabBarVerticalOrientation:
			labelRect.origin.y = cellFrame.origin.y;
			break;
	}
	
	if ([self closeButtonIsEnabledForCell:cell]) {
		/* The close button and the icon (if present) are drawn combined, changing on-hover */
		NSRect closeButtonRect = [cell closeButtonRectForFrame:cellFrame];
		NSRect iconRect = [self iconRectForTabCell:cell];
		NSRect drawingRect;
		NSImage *closeButtonOrIcon = nil;

		if ([cell hasIcon]) {
			/* If the cell has an icon and a close button, determine which rect should be used and use it consistently
			 * This only matters for horizontal tabs; vertical tabs look fine without making this adjustment.
			 */
			if (NSWidth(iconRect) > NSWidth(closeButtonRect)) {
				closeButtonRect.origin.x = NSMinX(iconRect) + NSWidth(iconRect)/2 - NSWidth(closeButtonRect)/2;
			}
		}

		if ([cell closeButtonPressed]) {
			closeButtonOrIcon = ([cell isEdited] ? _closeDirtyButtonDown : _closeButtonDown);
			drawingRect = closeButtonRect;

		} else if ([cell closeButtonOver]) {
            closeButtonOrIcon = ([cell isEdited] ? _closeDirtyButtonOver : _closeButtonOver);
			drawingRect = closeButtonRect;
	
		} else if ((orientation == PSMTabBarVerticalOrientation) &&
				   ([cell count] > 0)) {
			/* In vertical tabs, the count indicator supercedes the icon */
			NSSize counterSize = [self sizeForObjectCounterRectForTabCell:cell];
			if (counterSize.width > NSWidth(closeButtonRect)) {
				closeButtonRect.origin.x -= (counterSize.width - NSWidth(closeButtonRect));
				closeButtonRect.size.width = counterSize.width;
			}

			closeButtonRect.origin.y = cellFrame.origin.y + ((NSHeight(cellFrame) - counterSize.height) / 2);
			closeButtonRect.size.height = counterSize.height;

			drawingRect = closeButtonRect;
			[self drawObjectCounterInCell:cell withRect:drawingRect];
			/* closeButtonOrIcon == nil */

		} else if ([cell hasIcon]) {
			closeButtonOrIcon = [[[cell representedObject] identifier] icon];
			drawingRect = iconRect;
	
		} else {
			closeButtonOrIcon = ([cell isEdited] ? _closeDirtyButton : _closeButton);
			drawingRect = closeButtonRect;
		}
		
		if ([controlView isFlipped]) {
			drawingRect.origin.y += drawingRect.size.height;
		}

		[closeButtonOrIcon compositeToPoint:drawingRect.origin operation:NSCompositeSourceOver fraction:1.0];
		
		// scoot label over
		switch (orientation)
		{
			case PSMTabBarHorizontalOrientation:
			{
				CGFloat oldOrigin = labelRect.origin.x;
				if (NSWidth(iconRect) > NSWidth(closeButtonRect)) {
					labelRect.origin.x = (NSMaxX(iconRect) + (Adium_CellPadding * 2));
				} else {
					labelRect.origin.x = (NSMaxX(closeButtonRect) + (Adium_CellPadding * 2));					
				}
				labelRect.size.width -= (NSMinX(labelRect) - oldOrigin);
				break;
			}
			case PSMTabBarVerticalOrientation:
			{
				//Generate the remaining label rect directly from the location of the close button, allowing for padding
				if (NSWidth(iconRect) > NSWidth(closeButtonRect)) {
					labelRect.size.width = NSMinX(iconRect) - Adium_CellPadding - NSMinX(labelRect);
				} else {
					labelRect.size.width = NSMinX(closeButtonRect) - Adium_CellPadding - NSMinX(labelRect);
				}

				break;
			}
		}

	} else if ([cell hasIcon]) {
		/* The close button is disabled; the cell has an icon */
		NSRect iconRect = [self iconRectForTabCell:cell];
		NSImage *icon = [[[cell representedObject] identifier] icon];

		if ([controlView isFlipped]) {
			iconRect.origin.y += iconRect.size.height;
		}

		[icon compositeToPoint:iconRect.origin operation:NSCompositeSourceOver fraction:1.0];
		
		// scoot label over by the size of the standard close button
		switch (orientation)
		{
			case PSMTabBarHorizontalOrientation:
				labelRect.origin.x += (NSWidth(iconRect) + Adium_CellPadding);
				labelRect.size.width -= (NSWidth(iconRect) + Adium_CellPadding);
				break;
			case PSMTabBarVerticalOrientation:
				labelRect.size.width -= (NSWidth(iconRect) + Adium_CellPadding);
				break;
		}		
	}

	if ([cell state] == NSOnState) {
		labelRect.origin.y -= 1;
	}
	
	if (![[cell indicator] isHidden]) {
		labelRect.size.width -= (kPSMTabBarIndicatorWidth + Adium_CellPadding);
	}
    
	// object counter
	//The object counter takes up space horizontally...
	if (([cell count] > 0) &&
		(orientation == PSMTabBarHorizontalOrientation)) {
		NSRect counterRect = [self objectCounterRectForTabCell:cell];
		
		[self drawObjectCounterInCell:cell withRect:counterRect];
		labelRect.size.width -= NSWidth(counterRect) + Adium_CellPadding;
	}
	
	// draw label
	NSAttributedString *attributedString = [cell attributedStringValue];
	if (orientation == PSMTabBarVerticalOrientation) {
		//Calculate the centered rect
		CGFloat stringHeight = [self heightOfAttributedString:attributedString withWidth:NSWidth(labelRect)];
		if (stringHeight < labelRect.size.height) {
			labelRect.origin.y += (NSHeight(labelRect) - stringHeight) / 2.0;
		}		
	}

	[attributedString drawInRect:labelRect];
}

- (void)drawTabCell:(PSMTabBarCell *)cell
{
	NSRect cellFrame = [cell frame];
	NSColor *lineColor = nil;
    NSBezierPath *bezier = [NSBezierPath bezierPath];
    lineColor = [NSColor grayColor];

	[bezier setLineWidth:1.0];

	//disable antialiasing of bezier paths
	[NSGraphicsContext saveGraphicsState];
	[[NSGraphicsContext currentContext] setShouldAntialias:NO];
	
	NSShadow *shadow = [[NSShadow alloc] init];
	[shadow setShadowOffset:NSMakeSize(-2, -2)];
	[shadow setShadowBlurRadius:2];
	[shadow setShadowColor:[NSColor colorWithCalibratedWhite:0.6 alpha:1.0]];

	if ([cell state] == NSOnState) {
		// selected tab
		if (orientation == PSMTabBarHorizontalOrientation) {
			NSRect aRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, NSWidth(cellFrame), cellFrame.size.height - 2.5);
			
			// background
			if (_drawsUnified) {
				if ([[[tabBar tabView] window] isKeyWindow]) {
					NSBezierPath *path = [NSBezierPath bezierPathWithRect:aRect];
					[path linearGradientFillWithStartColor:[NSColor colorWithCalibratedWhite:0.835 alpha:1.0]
												endColor:[NSColor colorWithCalibratedWhite:0.843 alpha:1.0]];
				} else {
					[[NSColor windowBackgroundColor] set];
					NSRectFill(aRect);
				}
			} else {
				[_gradientImage drawInRect:NSMakeRect(NSMinX(aRect), NSMinY(aRect), NSWidth(aRect), NSHeight(aRect)) fromRect:NSMakeRect(0, 0, [_gradientImage size].width, [_gradientImage size].height) operation:NSCompositeSourceOver fraction:1.0];
			}
			
			// frame
			[lineColor set];
			[bezier setLineWidth:1.0];
			[bezier moveToPoint:NSMakePoint(aRect.origin.x, aRect.origin.y)];
			[bezier lineToPoint:NSMakePoint(aRect.origin.x, aRect.origin.y + aRect.size.height)];
			
			[shadow setShadowOffset:NSMakeSize(-2, -2)];
			[shadow set];
			[bezier stroke];
			
			bezier = [NSBezierPath bezierPath];
			[bezier setLineWidth:1.0];
			[bezier moveToPoint:NSMakePoint(NSMinX(aRect), NSMaxY(aRect))];
			[bezier lineToPoint:NSMakePoint(NSMaxX(aRect), NSMaxY(aRect))];
			[bezier lineToPoint:NSMakePoint(NSMaxX(aRect), NSMinY(aRect))];
			
			if ([[cell controlView] frame].size.height < 2) {
				// special case of hidden control; need line across top of cell
				[bezier moveToPoint:NSMakePoint(aRect.origin.x, aRect.origin.y + 0.5)];
				[bezier lineToPoint:NSMakePoint(aRect.origin.x+aRect.size.width, aRect.origin.y + 0.5)];
			}
			
			[shadow setShadowOffset:NSMakeSize(2, -2)];
			[shadow set];
			[bezier stroke];
		} else {
			NSRect aRect;
			
			if (_drawsRight) {
				aRect = NSMakeRect(cellFrame.origin.x - 1, cellFrame.origin.y, cellFrame.size.width - 3, cellFrame.size.height);
			} else {
				aRect = NSMakeRect(cellFrame.origin.x + 2, cellFrame.origin.y, cellFrame.size.width - 2, cellFrame.size.height);
			}
			
			// background
			if (_drawsUnified) {
				if ([[[tabBar tabView] window] isKeyWindow]) {
					NSBezierPath *path = [NSBezierPath bezierPathWithRect:aRect];
					[path linearGradientFillWithStartColor:[NSColor colorWithCalibratedWhite:0.835 alpha:1.0]
												endColor:[NSColor colorWithCalibratedWhite:0.843 alpha:1.0]];
				} else {
					[[NSColor windowBackgroundColor] set];
					NSRectFill(aRect);
				}
			} else {
				NSBezierPath *path = [NSBezierPath bezierPathWithRect:aRect];
				if (_drawsRight) {
					[path linearVerticalGradientFillWithStartColor:[NSColor colorWithCalibratedWhite:0.92 alpha:1.0]
														  endColor:[NSColor colorWithCalibratedWhite:0.98 alpha:1.0]];
				} else {
					[path linearVerticalGradientFillWithStartColor:[NSColor colorWithCalibratedWhite:0.98 alpha:1.0]
														  endColor:[NSColor colorWithCalibratedWhite:0.92 alpha:1.0]];					
				}
			}
			
			// frame
			//top line
			[lineColor set];
			[bezier setLineWidth:1.0];
			[bezier moveToPoint:NSMakePoint(NSMinX(aRect), NSMinY(aRect))];
			[bezier lineToPoint:NSMakePoint(NSMaxX(aRect), NSMinY(aRect))];
			[bezier stroke];
			
			//outer edge and bottom lines
			bezier = [NSBezierPath bezierPath];
			[bezier setLineWidth:1.0];
			if (_drawsRight) {
				//Right
				[bezier moveToPoint:NSMakePoint(NSMaxX(aRect), NSMinY(aRect))];
				[bezier lineToPoint:NSMakePoint(NSMaxX(aRect), NSMaxY(aRect))];
				//Bottom
				[bezier lineToPoint:NSMakePoint(NSMinX(aRect), NSMaxY(aRect))];
			} else {
				//Left
				[bezier moveToPoint:NSMakePoint(NSMinX(aRect), NSMinY(aRect))];
				[bezier lineToPoint:NSMakePoint(NSMinX(aRect), NSMaxY(aRect))];
				//Bottom
				[bezier lineToPoint:NSMakePoint(NSMaxX(aRect), NSMaxY(aRect))];
			}
			[shadow setShadowOffset:NSMakeSize((_drawsRight ? 2 : -2), -2)];
			[shadow set];
			[bezier stroke];
		}
	} else {
		// unselected tab
		NSRect aRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width, cellFrame.size.height);
		
		// rollover
		if ([cell isHighlighted]) {
			[[NSColor colorWithCalibratedWhite:0.0 alpha:0.1] set];
			NSRectFillUsingOperation(aRect, NSCompositeSourceAtop);
		}
		
		// frame
		[lineColor set];
		
		if (orientation == PSMTabBarHorizontalOrientation) {
			[bezier moveToPoint:NSMakePoint(aRect.origin.x, aRect.origin.y)];
			[bezier lineToPoint:NSMakePoint(aRect.origin.x + aRect.size.width, aRect.origin.y)];
			if (!([cell tabState] & PSMTab_RightIsSelectedMask)) {
				//draw the tab divider
				[bezier lineToPoint:NSMakePoint(aRect.origin.x + aRect.size.width, aRect.origin.y + aRect.size.height)];
			}
			[bezier stroke];

		} else {
			//No outline for vertical
		}
	}
	
	[NSGraphicsContext restoreGraphicsState];
	[shadow release];
	
	[self drawInteriorWithTabCell:cell inView:[cell controlView]];
}

- (void)drawBackgroundInRect:(NSRect)rect
{
	//Draw for our whole bounds; it'll be automatically clipped to fit the appropriate drawing area
	rect = [tabBar bounds];

	switch (orientation) {
		case PSMTabBarHorizontalOrientation:
			if (_drawsUnified && [[[tabBar tabView] window] isKeyWindow]) {
				if ([[[tabBar tabView] window] isKeyWindow]) {
					NSBezierPath *backgroundPath = [NSBezierPath bezierPathWithRect:rect];
					[backgroundPath linearGradientFillWithStartColor:[NSColor colorWithCalibratedWhite:0.835 alpha:1.0]
															endColor:[NSColor colorWithCalibratedWhite:0.843 alpha:1.0]];
				} else {
					[[NSColor windowBackgroundColor] set];
					NSRectFill(rect);
				}
			} else {
				[[NSColor colorWithCalibratedWhite:0.85 alpha:0.6] set];
				[NSBezierPath fillRect:rect];
			}
			break;

		case PSMTabBarVerticalOrientation:
			//This is the Mail.app source list background color... which differs from the iTunes one.
			[[NSColor colorWithCalibratedRed:.9059
									   green:.9294
										blue:.9647
									   alpha:1.0] set];
			NSRectFill(rect);
			break;
	}			

	//Draw the border and shadow around the tab bar itself
	[NSGraphicsContext saveGraphicsState];
	[[NSGraphicsContext currentContext] setShouldAntialias:NO];

	NSShadow *shadow = [[NSShadow alloc] init];
	[shadow setShadowBlurRadius:2];
	[shadow setShadowColor:[NSColor colorWithCalibratedWhite:0.6 alpha:1.0]];
	
	[[NSColor grayColor] set];
	
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path setLineWidth:1.0];
				
	switch (orientation) {
		case PSMTabBarHorizontalOrientation:
		{
			rect.origin.y++;
			[path moveToPoint:NSMakePoint(rect.origin.x, rect.origin.y)];
			[path lineToPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y)];
			[shadow setShadowOffset:NSMakeSize(2, -2)];
			
			[shadow set];
			[path stroke];

			break;
		}

		case PSMTabBarVerticalOrientation:
		{
			NSPoint startPoint, endPoint;
			NSSize shadowOffset;
			
			//Draw vertical shadow
			if (_drawsRight) {
				startPoint = NSMakePoint(NSMinX(rect), NSMinY(rect));
				endPoint = NSMakePoint(NSMinX(rect), NSMaxY(rect));
				shadowOffset = NSMakeSize(2, -2);
			} else {
				startPoint = NSMakePoint(NSMaxX(rect) - 1, NSMinY(rect));
				endPoint = NSMakePoint(NSMaxX(rect) - 1, NSMaxY(rect));
				shadowOffset = NSMakeSize(-2, -2);
			}
				
			[path moveToPoint:startPoint];
			[path lineToPoint:endPoint];
			[shadow setShadowOffset:shadowOffset];
			
			[shadow set];
			[path stroke];

			[path removeAllPoints];
			
			//Draw top horizontal shadow
			startPoint = NSMakePoint(NSMinX(rect), NSMinY(rect));
			endPoint = NSMakePoint(NSMaxX(rect), NSMinY(rect));
			shadowOffset = NSMakeSize(0, -1);
			
			[path moveToPoint:startPoint];
			[path lineToPoint:endPoint];
			[shadow setShadowOffset:shadowOffset];
			
			[shadow set];
			[path stroke];
			
			break;
		}
	}

	[shadow release];
	[NSGraphicsContext restoreGraphicsState];
}

- (void)drawTabBar:(PSMTabBarControl *)bar inRect:(NSRect)rect
{
	if (orientation != [bar orientation]) {
		orientation = [bar orientation];
	}
	
	if (tabBar != bar) {
		[tabBar release];
		tabBar = [bar retain];
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

#pragma mark -
#pragma mark Archiving

- (void)encodeWithCoder:(NSCoder *)aCoder 
{
    if ([aCoder allowsKeyedCoding]) {
        [aCoder encodeObject:_closeButton forKey:@"closeButton"];
        [aCoder encodeObject:_closeButtonDown forKey:@"closeButtonDown"];
        [aCoder encodeObject:_closeButtonOver forKey:@"closeButtonOver"];
        [aCoder encodeObject:_closeDirtyButton forKey:@"closeDirtyButton"];
        [aCoder encodeObject:_closeDirtyButtonDown forKey:@"closeDirtyButtonDown"];
        [aCoder encodeObject:_closeDirtyButtonOver forKey:@"closeDirtyButtonOver"];
        [aCoder encodeObject:_addTabButtonImage forKey:@"addTabButtonImage"];
        [aCoder encodeObject:_addTabButtonPressedImage forKey:@"addTabButtonPressedImage"];
        [aCoder encodeObject:_addTabButtonRolloverImage forKey:@"addTabButtonRolloverImage"];
		[aCoder encodeBool:_drawsUnified forKey:@"drawsUnified"];
		[aCoder encodeBool:_drawsRight forKey:@"drawsRight"];
    }
}

- (id)initWithCoder:(NSCoder *)aDecoder 
{
   if ( (self = [super init]) ) {
        if ([aDecoder allowsKeyedCoding]) {
            _closeButton = [[aDecoder decodeObjectForKey:@"closeButton"] retain];
            _closeButtonDown = [[aDecoder decodeObjectForKey:@"closeButtonDown"] retain];
            _closeButtonOver = [[aDecoder decodeObjectForKey:@"closeButtonOver"] retain];
            _closeDirtyButton = [[aDecoder decodeObjectForKey:@"closeDirtyButton"] retain];
            _closeDirtyButtonDown = [[aDecoder decodeObjectForKey:@"closeDirtyButtonDown"] retain];
            _closeDirtyButtonOver = [[aDecoder decodeObjectForKey:@"closeDirtyButtonOver"] retain];
            _addTabButtonImage = [[aDecoder decodeObjectForKey:@"addTabButtonImage"] retain];
            _addTabButtonPressedImage = [[aDecoder decodeObjectForKey:@"addTabButtonPressedImage"] retain];
            _addTabButtonRolloverImage = [[aDecoder decodeObjectForKey:@"addTabButtonRolloverImage"] retain];
			_drawsUnified = [aDecoder decodeBoolForKey:@"drawsUnified"];
			_drawsRight = [aDecoder decodeBoolForKey:@"drawsRight"];
        }
    }
    return self;
}

@end
