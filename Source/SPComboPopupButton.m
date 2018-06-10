//
//  SPComboPopupButton.m
//  sequel-pro
//
//  Created by Rowan Beentje (rowan.beent.je) on March 22, 2013
//  Copyright (c) 2013 Rowan Beentje. All rights reserved.
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

#import "SPComboPopupButton.h"

#define kSPComboPopupButtonLineOffsetMini 13;
#define kSPComboPopupButtonLineOffsetSmall 15;
#define kSPComboPopupButtonLineOffsetRegular 17;

@interface SPComboPopupButton ()

- (void)_initCustomData;

@end

@interface SPComboPopupButtonCell : NSPopUpButtonCell

@end

@implementation SPComboPopupButton

@synthesize shouldDrawNonHighlightState;
@synthesize lineOffset;

#pragma mark -
#pragma mark Setup

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder])) {
		[self _initCustomData];
	}
	return self;
}

- (id)initWithFrame:(NSRect)frameRect pullsDown:(BOOL)flag
{
	if ((self = [super initWithFrame:frameRect pullsDown:flag])) {
		[self _initCustomData];
	}
	return self;
}

/**
 * Default to the overridden class. Note that this won't apply to instanced
 * created in a xib, where the cell class should be selected appropriately.
 */
+ (Class)cellClass
{
	return [SPComboPopupButtonCell class];
}

#pragma mark -
#pragma mark Drawing

/**
 * Draw the control, largely leveraging NSPopupButton drawing but with tweaks
 * to draw a separator line and different highlights if the dropdown area is
 * selected.
 */
- (void)drawRect:(NSRect)dirtyRect
{
	NSRect boundsRect = [self bounds];
	CGFloat boundingLinePosition = boundsRect.origin.x + boundsRect.size.width - lineOffset - 0.5;
	CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	CGFloat heightIndent = ([self isFlipped] ? 4.f : -4.f);

	// Allow the NSPopupButton to draw the majority of the button, with one exception:
	// if the menu is open, only draw part of the rectangle highlighted.
	if (menuIsOpen) {

		// Draw the unhighlighted button state in the left-hand part of the button
		NSRect partialDirtyRect = NSIntersectionRect(dirtyRect, NSMakeRect(boundsRect.origin.x, boundsRect.origin.y, boundingLinePosition - boundsRect.origin.x, boundsRect.size.height));
		if (!NSIsEmptyRect(partialDirtyRect)) {
			CGContextSaveGState(context);
			CGContextClipToRect(context, NSRectToCGRect(partialDirtyRect));
			shouldDrawNonHighlightState = YES;
			[super drawRect:partialDirtyRect];
			shouldDrawNonHighlightState = NO;
			CGContextRestoreGState(context);
		}

		// Draw the right-hand side of the button as normal
		partialDirtyRect = NSIntersectionRect(dirtyRect, NSMakeRect(boundingLinePosition - 0.5, boundsRect.origin.y, boundsRect.origin.x + boundsRect.size.width + 0.5 - boundingLinePosition, boundsRect.size.height));
		if (!NSIsEmptyRect(partialDirtyRect)) {
			CGContextSaveGState(context);
			CGContextClipToRect(context, NSRectToCGRect(partialDirtyRect));
			[super drawRect:dirtyRect];
			CGContextRestoreGState(context);
		}
	} else {
		[super drawRect:dirtyRect];
	}

	// Draw the divider line for the two parts of the button
	NSColor *lineBaseColor = [[NSColor lightGrayColor] colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];
	CGFloat lineColorParts[[lineBaseColor numberOfComponents]];
	CGColorSpaceRef rgbSpace = CGColorSpaceCreateDeviceRGB();
	[lineBaseColor getComponents:(CGFloat *)&lineColorParts];
	CGColorRef lineColor = CGColorCreate(rgbSpace, lineColorParts);
	CGColorRef lineEdgeColor = CGColorCreateCopyWithAlpha(lineColor, 0.1);
	CGColorRef gradientColors[] = { lineEdgeColor, lineColor, lineColor, lineEdgeColor };
	CFArrayRef colorArray = CFArrayCreate(NULL, (const void **)gradientColors, 4, &kCFTypeArrayCallBacks);
	CGFloat gradientPositions[] = { 0.05, 0.25, 0.75, 0.95 };
	CGGradientRef lineGradient = CGGradientCreateWithColors(rgbSpace, colorArray, gradientPositions);

	CGContextSaveGState(context);
	CGContextSetStrokeColor(context, lineColorParts);
	CGContextAddRect(context, CGRectMake(boundingLinePosition - 0.5, boundsRect.origin.y + heightIndent, 1.f, boundsRect.size.height - fabs(2 * heightIndent)));
	CGContextClip(context);
	CGContextDrawLinearGradient(context, lineGradient, CGPointMake(boundingLinePosition - 0.5, boundsRect.origin.y + heightIndent), CGPointMake(boundingLinePosition - 0.5, boundsRect.origin.y + boundsRect.size.height - fabs(heightIndent)), 0);
	CGContextRestoreGState(context);

	CGGradientRelease(lineGradient);
	CFRelease(colorArray);
	CGColorRelease(lineEdgeColor);
	CGColorRelease(lineColor);
	CGColorSpaceRelease(rgbSpace);
}

#pragma mark -
#pragma mark Click action overrides

- (void)performClick:(id)sender
{
	if (actionSelector && actionTarget) {
		[self sendAction:actionSelector to:actionTarget];
	}
}

- (id)target
{
	return actionTarget;
}

- (void)setTarget:(id)anObject
{
	actionTarget = anObject;
}

- (SEL)action
{
	return actionSelector;
}

- (void)setAction:(SEL)aSelector
{
	actionSelector = aSelector;
}

#pragma mark -
#pragma mark Menu delegate implementation

- (void)menuWillOpen:(NSMenu *)menu
{
	menuIsOpen = YES;
}

- (void)menuDidClose:(NSMenu *)menu
{
	menuIsOpen = NO;
}

#pragma mark -

- (void)_initCustomData
{

	// Set the line position based on the initial control size
	switch ([[self cell] controlSize]) {
		case NSMiniControlSize:
			lineOffset = kSPComboPopupButtonLineOffsetMini;
		break;
		case NSSmallControlSize:
			lineOffset = kSPComboPopupButtonLineOffsetSmall;
		break;
		default:
			lineOffset = kSPComboPopupButtonLineOffsetRegular;
		break;
	}

	// Track when the menu is open via delegate methods
	menuIsOpen = NO;
	[[[self cell] menu] setDelegate:self];

	// Move any xib-specified action and target for use as the button target
	actionSelector = [super action];
	[super setAction:NULL];
	actionTarget = [super target];
	[super setTarget:nil];
}

@end

#pragma mark -

@implementation SPComboPopupButtonCell

/**
 * Indent the title slightly to take account of the additional divider
 */
- (NSRect)drawTitle:(NSAttributedString *)title withFrame:(NSRect)frame inView:(NSView *)controlView
{
	frame.size.width -= 1;
	return [super drawTitle:title withFrame:frame inView:controlView];
}

/**
 * Allow the button to overwrite the draw status as required
 */
- (BOOL)isHighlighted
{
	if ([(SPComboPopupButton *)[self controlView] shouldDrawNonHighlightState]) {
		return NO;
	}
	return [super isHighlighted];
}

#pragma mark -
#pragma mark Custom interaction handling

- (BOOL)trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView untilMouseUp:(BOOL)untilMouseUp
{
	NSPoint thePoint;
	NSRect activeRect;
	CGFloat heightIndent = ([controlView isFlipped] ? 2.f : -2.f);
	BOOL mouseInButton = YES;
	BOOL trackAsPerMenuButton = NO;

	// If the event isn't a mouse button event, allow the NSPopUpButtonCell to handle it
	if ([theEvent type] != NSLeftMouseDown) {
		trackAsPerMenuButton = YES;
	}

	// If the view doesn't support line position checks, pass on the event
	else if (![controlView respondsToSelector:@selector(lineOffset)]) {
		trackAsPerMenuButton = YES;
	}

	// If the click is to the right of the line, show the menu
	else if ([controlView convertPoint:theEvent.locationInWindow fromView:nil].x + [(SPComboPopupButton *)controlView lineOffset] >= [controlView frame].size.width) {
		trackAsPerMenuButton = YES;
	}

	if (trackAsPerMenuButton) {
		return [super trackMouse:theEvent inRect:cellFrame ofView:controlView untilMouseUp:untilMouseUp];
	}


	// Custom tracking to be performed - indent the vertical button area slightly
	activeRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y + heightIndent, cellFrame.size.width - [(SPComboPopupButton *)controlView lineOffset] + 1, cellFrame.size.height - fabs(2 * heightIndent));

	// Continue tracking the mouse while it's down, updating the state as it enters and leaves the cell,
	// until it is released; if still within the cell, perform a click.
	while ([theEvent type] != NSLeftMouseUp) {
		thePoint = [controlView convertPoint:[theEvent locationInWindow] fromView:nil];

		if (NSMouseInRect(thePoint, activeRect, [controlView isFlipped]) != mouseInButton) {
			mouseInButton = !mouseInButton;
			[self setHighlighted:mouseInButton];
		}

		theEvent = [[controlView window] nextEventMatchingMask:(NSLeftMouseUpMask | NSLeftMouseDraggedMask)];
	}

	// If the mouse is still inside the button area, perform a click action and restore state
	if (mouseInButton) {
		if ([controlView respondsToSelector:@selector(performClick:)]) {
			[(NSControl *)controlView performClick:self];
		}
		[self setHighlighted:NO];
	}

	return YES;
}

@end
