//
//  SPActivityTextFieldCell.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on December 1, 2010.
//  Copyright (c) 2010 Hans-Jörg Bibiko. All rights reserved.
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

#import "SPActivityTextFieldCell.h"
#import "SPTableInfo.h"

#define FAVORITE_NAME_FONT_SIZE 12.0f

@interface SPActivityTextFieldCell ()

- (NSAttributedString *)constructSubStringAttributedString;
- (NSAttributedString *)attributedStringForFavoriteName;
- (NSDictionary *)mainStringAttributedStringAttributes;
- (NSDictionary *)subStringAttributedStringAttributes;

@end

@implementation SPActivityTextFieldCell

/**
 * Provide a method to derive the link rect from a cell rect.
 */
static inline NSRect SPTextLinkRectFromCellRect(NSRect inRect) 
{
	return NSMakeRect(inRect.origin.x + inRect.size.width - 30, inRect.origin.y - 1, 15, inRect.size.height);
}


@synthesize activityName;
@synthesize activityInfo;
@synthesize contextInfo;

/**
 * Init.
 */
- (id)init
{
	if ((self = [super init])) {
		mainStringColor = [NSColor blackColor];
		subStringColor = [NSColor grayColor];
		activityName = nil;
		activityInfo = nil;
		cancelButton = nil;
		contextInfo = nil;
		drawState = SPLinkDrawStateNormal;

		cancelButton = [[NSButtonCell alloc] init];
		[cancelButton setButtonType:NSMomentaryChangeButton];
		[cancelButton setImagePosition:NSImageRight];
		[cancelButton setTitle:@""];
		[cancelButton setBordered:NO];
		[cancelButton setShowsBorderOnlyWhileMouseInside:YES];
		[cancelButton setImage:[NSImage imageNamed:@"cancel"]];
		[cancelButton setAlternateImage:[NSImage imageNamed:@"cancel-clicked"]];
	}
	
	return self;
}

/**
 * Encodes using a given receiver.
 */
- (void) encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];
}

- (id)copyWithZone:(NSZone *)zone 
{
	SPActivityTextFieldCell *cell = (SPActivityTextFieldCell *)[super copyWithZone:zone];

	cell->activityName = nil;
	if (activityName) cell->activityName = [activityName copyWithZone:zone];

	cell->activityInfo = nil;
	if (activityInfo) cell->activityInfo = [activityInfo copyWithZone:zone];

	cell->contextInfo = nil;
	if (contextInfo) cell->contextInfo = [contextInfo copyWithZone:zone];

	cell->cancelButton = nil;
	if (cancelButton) cell->cancelButton = [cancelButton copyWithZone:zone];

	return cell;
}


/**
 * Draws the actual cell.
 */
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{

	[cancelButton setEnabled:(contextInfo != nil)];

	(([self isHighlighted]) && (![[self highlightColorWithFrame:cellFrame inView:controlView] isEqualTo:[NSColor secondarySelectedControlColor]])) ? [self invertFontColors] : [self restoreFontColors];
	
	// Construct and get the sub text attributed string
	NSAttributedString *mainString = [self attributedStringForFavoriteName];
	NSAttributedString *subString = [self constructSubStringAttributedString];
	
	NSRect subFrame = NSMakeRect(0.0f, 0.0f, [subString size].width, [subString size].height);
	
	// Total height of both strings with a 2 pixel separation space
	CGFloat totalHeight = [mainString size].height + [subString size].height + 1.0f;
	
	cellFrame.origin.y += (cellFrame.size.height - totalHeight) / 2.0f;
	cellFrame.origin.x += 10.0f; // Indent main string from image
	
	// Position the sub text's frame rect
	subFrame.origin.y = [mainString size].height + cellFrame.origin.y + 1.0f;
	subFrame.origin.x = cellFrame.origin.x;
	
	cellFrame.size.height = totalHeight;
	
	NSUInteger i;
	CGFloat maxWidth = cellFrame.size.width - 30;
	CGFloat mainStringWidth = [mainString size].width;
	CGFloat subStringWidth = [subString size].width;

	// Set a right-padding
	maxWidth -= 10;

	if (maxWidth < mainStringWidth) {
		for (i = 0; i <= [mainString length]; i++) {
			if ([[mainString attributedSubstringFromRange:NSMakeRange(0, i)] size].width >= maxWidth && i >= 3) {
				mainString = [[[NSMutableAttributedString alloc] initWithString:[[[mainString attributedSubstringFromRange:NSMakeRange(0, i - 3)] string] stringByAppendingString:@"..."] attributes:[self mainStringAttributedStringAttributes]] autorelease];
			}
		}
	}
	
	if (maxWidth < subStringWidth) {
		for (i = 0; i <= [subString length]; i++) {
			if ([[subString attributedSubstringFromRange:NSMakeRange(0, i)] size].width >= maxWidth && i >= 3) {
				subString = [[[NSMutableAttributedString alloc] initWithString:[[[subString attributedSubstringFromRange:NSMakeRange(0, i - 3)] string] stringByAppendingString:@"..."] attributes:[self subStringAttributedStringAttributes]] autorelease];
			}
		}
	}

	[mainString drawInRect:NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width-30, cellFrame.size.height)];
	[subString drawInRect:subFrame];

	NSRect linkRect = SPTextLinkRectFromCellRect(cellFrame);

	// Get the new link state
	NSInteger newDrawState = ([self isHighlighted])?
							((([(NSTableView *)[self controlView] editedColumn] != -1
								|| [[[self controlView] window] firstResponder] == [self controlView])
								&& [[[self controlView] window] isKeyWindow])?SPLinkDrawStateHighlight:SPLinkDrawStateBackgroundHighlight):
							SPLinkDrawStateNormal;

	// Update the link arrow style if the state has changed
	if (drawState != newDrawState) {
		drawState = newDrawState;
		switch (drawState) {
			case SPLinkDrawStateNormal:
				[cancelButton setImage:[NSImage imageNamed:@"cancel"]];
				[cancelButton setAlternateImage:[NSImage imageNamed:@"cancel-clicked"]];
				break;
			case SPLinkDrawStateHighlight:
				[cancelButton setImage:[NSImage imageNamed:@"cancel-highlighted"]];
				[cancelButton setAlternateImage:[NSImage imageNamed:@"cancel-clicked-highlighted"]];
				break;
			case SPLinkDrawStateBackgroundHighlight:
				[cancelButton setImage:[NSImage imageNamed:@"cancel-clicked"]];
				[cancelButton setAlternateImage:[NSImage imageNamed:@"cancel"]];
				break;
		}
	}

	[cancelButton drawWithFrame:linkRect inView:controlView];
}

- (NSRect)expansionFrameWithFrame:(NSRect)cellFrame inView:(NSView *)view
{
	return NSZeroRect;
}

/**
 * Allow hit tracking for cancel functionality
 */
- (NSCellHitResult)hitTestForEvent:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView
{
	return NSCellHitContentArea | NSCellHitTrackableArea;
}

/**
 * Allow mouse tracking within the button cell, to support expected click
 * behaviour in the button cell.
 */
- (BOOL)trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView untilMouseUp:(BOOL)untilMouseUp
{

	NSPoint p = [controlView convertPoint:[theEvent locationInWindow] fromView:nil];
	NSRect linkRect = SPTextLinkRectFromCellRect(cellFrame);
	linkRect.origin.x += 15;

	// Fast path for if not in button rect - just pass to super
	if (!NSMouseInRect(p, linkRect, [controlView isFlipped]))
		return [super trackMouse:theEvent inRect:cellFrame ofView:controlView untilMouseUp:untilMouseUp];

	// Ignore events other than mouse down.
	if ([theEvent type] != NSLeftMouseDown) return YES;

	// Continue tracking the mouse while it's down, updating the state as it enters and leaves the cell,
	// until it is released; if still within the cell, follow the link.
	BOOL mouseInButton = YES;
	while (1) {
		if (mouseInButton) {

			// Highlight the button
			[cancelButton highlight:YES withFrame:linkRect inView:controlView];

			// Continue to track until mouse completes a click or exits the cell while still down
			BOOL mouseClicked = [cancelButton trackMouse:theEvent inRect:linkRect ofView:controlView untilMouseUp:NO];
			if (mouseClicked) {

				// Remove highlight, and follow the link
				[cancelButton highlight:NO withFrame:linkRect inView:controlView];

				NSInteger status = 0;

				// Cancel activity
				if([contextInfo objectForKey:@"type"] && [[contextInfo objectForKey:@"type"] isEqualToString:@"bashcommand"]) {
					NSInteger pid = [[contextInfo objectForKey:@"pid"] intValue];
					if(pid > 0) {
						NSTask *killTask = [[NSTask alloc] init];
						[killTask setLaunchPath:@"/bin/sh"];
						// [killTask setArguments:[NSArray arrayWithObjects:@"-c", [NSString stringWithFormat:@"kill -9 -%ld", pid], nil]];
						[killTask setArguments:[NSArray arrayWithObjects:@"-c", [NSString stringWithFormat:@"[[ `ps -ax | egrep '%ld.*%@' | wc -l` -eq \"4\" ]] && kill -9 -%ld 2&> /tmp/sp_kill_error.txt", (long)pid, [SPBundleTaskScriptCommandFilePath stringByExpandingTildeInPath], (long)pid], nil]];
						[killTask launch];
						[killTask waitUntilExit];
						status = [killTask terminationStatus];
						[killTask release];
					}
				}
				// Remove it from the list directly since the list will be updated in the background
				// to avoid to cancel a command which is already cancelled
				if(status == 0)
					[[[(id)controlView delegate] onMainThread] removeActivity:[[contextInfo objectForKey:@"pid"] intValue]];
				return YES;
			}

			// Mouse has exited the cell.  Remove highlight.
			mouseInButton = NO;
			[cancelButton highlight:NO withFrame:linkRect inView:controlView];
		}

		// Keep tracking the mouse outside the button, until the mouse button is released or it reenters the button
		theEvent = [[controlView window] nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
		p = [controlView convertPoint:[theEvent locationInWindow] fromView:nil];
		mouseInButton = NSMouseInRect(p, linkRect, [controlView isFlipped]);

		// If the event is a mouse release, break the loop.
		if ([theEvent type] == NSLeftMouseUp) break;
	}

	return YES;
}

- (NSSize)cellSize
{
	NSSize cellSize = [super cellSize];
	NSAttributedString *mainString = [self attributedStringForFavoriteName];
	NSAttributedString *subString = [self constructSubStringAttributedString];

	// 15 := indention 10 from image to string plus 5 px padding
	CGFloat theWidth = MAX([mainString size].width, [subString size].width) + (([self image] != nil) ? [[self image] size].width : 0) + 15;

	CGFloat totalHeight = [mainString size].height + [subString size].height + 1.0f;

	cellSize.width = theWidth;
	cellSize.height = totalHeight + 13.0f;
	return cellSize;
}

/**
 * Inverts the displayed font colors when the cell is selected.
 */
- (void)invertFontColors
{
	mainStringColor = [NSColor whiteColor];
	subStringColor = [NSColor whiteColor];
}

/**
 * Restores the displayed font colors once the cell is no longer selected.
 */
- (void)restoreFontColors
{
	mainStringColor = [NSColor blackColor];
	subStringColor = [NSColor grayColor];
}

/**
 * Dealloc.
 */
- (void)dealloc 
{
	if(activityName) SPClear(activityName);
	if(activityInfo) SPClear(activityInfo);
	if(contextInfo) SPClear(contextInfo);
	if(cancelButton) SPClear(cancelButton);

	[super dealloc];
}

#pragma mark - Private API

/**
 * Constructs the attributed string to be used as the cell's substring.
 */
- (NSAttributedString *)constructSubStringAttributedString
{
	return [[[NSAttributedString alloc] initWithString:activityInfo attributes:[self subStringAttributedStringAttributes]] autorelease];
}

/**
 * Constructs the attributed string for the cell's favorite name.
 */
- (NSAttributedString *)attributedStringForFavoriteName
{	
	return [[[NSAttributedString alloc] initWithString:activityName attributes:[self mainStringAttributedStringAttributes]] autorelease];
}

/**
 * Returns the attributes of the cell's main string.
 */
- (NSDictionary *)mainStringAttributedStringAttributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:mainStringColor, NSForegroundColorAttributeName, [NSFont systemFontOfSize:FAVORITE_NAME_FONT_SIZE], NSFontAttributeName, nil];
}

/**
 * Returns the attributes of the cell's sub string.
 */
- (NSDictionary *)subStringAttributedStringAttributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:subStringColor, NSForegroundColorAttributeName, [NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName, nil];
}

@end
