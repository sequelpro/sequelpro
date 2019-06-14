//
//  SPSplitView.m
//  sequel-pro
//
//  Created by Rowan Beentje on April 25, 2012.
//  Copyright (c) 2012 Rowan Beentje. All rights reserved.
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

#import "SPSplitView.h"
#import "SPDateAdditions.h"
#import "SPOSInfo.h"
#include <stdlib.h>

static BOOL isOSAtLeast10_7;

@interface SPSplitView ()

- (void)_initCustomProperties;
- (void)_ensureDefaultSubviewSizesToIndex:(NSUInteger)anIndex;

- (void)_saveAutoSaveSizes;
- (void)_restoreAutoSaveSizes;

- (NSArray *)_suggestedSizesForTargetSize:(CGFloat)targetSize respectingSpringsAndStruts:(BOOL)respectStruts respectingConstraints:(BOOL)respectConstraints;

- (CGFloat)_startPositionOfView:(NSView *)aView;
- (CGFloat)_lengthOfView:(NSView *)aView;
- (void)_setStartPosition:(CGFloat)newOrigin ofView:(NSView *)aView;
- (void)_setLength:(CGFloat)newLength ofView:(NSView *)aView;

- (BOOL)_isViewResizable:(NSView *)aView;
@end

@interface SPSplitViewHelperView : NSView
{
	NSView *wrappedView;
}

- (instancetype)initReplacingView:(NSView *)aView inVerticalSplitView:(BOOL)verticalSplitView;
- (void)restoreOriginalView;

@end

@interface SPSplitViewAnimationRetainCycleBypass : NSObject
{
	__unsafe_unretained SPSplitView *parentSplitView;
}

- (instancetype)initWithParent:(SPSplitView *)aSplitView;
- (void)_animationStep:(NSTimer *)aTimer;

@end


@implementation SPSplitView

+ (void)initialize {
	isOSAtLeast10_7 = [SPOSInfo isOSVersionAtLeastMajor:10 minor:7 patch:0];
}

#pragma mark -
#pragma mark Setup and teardown

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect])) {
		[self _initCustomProperties];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
	if ((self = [super initWithCoder:coder])) {
		[self _initCustomProperties];
	}
	return self;
}

- (void)awakeFromNib
{
	if ([NSSplitView instancesRespondToSelector:@selector(awakeFromNib)]) {
		[super awakeFromNib];
	}

	// Normal splitview autosave appears to have problems on Lion - handle it ourselves as well.
	[self _restoreAutoSaveSizes];

	[collapseToggleButton setState:(collapsibleSubviewCollapsed?NSOnState:NSOffState)];
}

- (void)dealloc
{
	SPClear(viewMinimumSizes);
	SPClear(viewMaximumSizes);

	if (animationTimer) [animationTimer invalidate], SPClear(animationTimer);
	if (animationRetainCycleBypassObject) SPClear(animationRetainCycleBypassObject);

	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

#pragma mark -
#pragma mark Delegate management

- (void)setDelegate:(id<NSSplitViewDelegate>)aDelegate
{
	delegate = aDelegate;
}

#pragma mark -
#pragma mark Collapsible subview management

/**
 * Set the index of the collapsible subview; pass in NSNotFound as the index
 * to unset an existing subview.
 */
- (void)setCollapsibleSubviewIndex:(NSUInteger)subviewIndex
{
	if (collapsibleSubviewIndex == subviewIndex) {
		return;
	}

	if (subviewIndex > [[self subviews] count]) {
		[NSException raise:NSInternalInconsistencyException format:@"Specified a collpasible subview index which doesn't exist"];
	}

	// If an existing collapsible subview exists, and the view is collapsed,
	// expand the old view before proceeding
	if (collapsibleSubviewIndex != NSNotFound && collapsibleSubviewCollapsed) {
		[self setCollapsibleSubviewCollapsed:NO animate:NO];
	}

	collapsibleSubviewIndex = subviewIndex;
	[collapseToggleButton setState:NSOffState];
	collapsibleSubviewCollapsed = NO;
}

/**
 * Set a button which controls the state of the collapsible subview; if this is set,
 * the button state will automatically be set as the subview collapses or expands.
 * This can also be set using the IBOutlet.
 */
- (void)setToggleCollapseButton:(NSButton *)aButton
{
	collapseToggleButton = aButton;
	[collapseToggleButton setState:(collapsibleSubviewCollapsed?NSOnState:NSOffState)];
}

/**
 * Return whether the collapsible subview is collapsed or collapsing.
 */
- (BOOL)isCollapsibleSubviewCollapsed
{
	if (collapsibleSubviewIndex == NSNotFound) {
		return NO;
	}

	return collapsibleSubviewCollapsed;
}

/**
 * Return whether the specified subview is collapsed, overriding the original method for
 * the collapsible subview set on this object; note that for the subview collapsible by
 * this class, YES is returned only if the subview is fully collapsed, not when animating.
 */
- (BOOL)isSubviewCollapsed:(NSView *)subview
{
	NSUInteger subviewIndex = [[self subviews] indexOfObject:subview];
	if (collapsibleSubviewIndex == NSNotFound || subviewIndex != collapsibleSubviewIndex)  {
		return [super isSubviewCollapsed:subview];
	}

	return collapsibleSubviewCollapsed && !animationTimer;
}

/**
 * Toggle the collapse state, using animation.
 */
- (IBAction)toggleCollapse:(id)sender
{
	[self setCollapsibleSubviewCollapsed:!collapsibleSubviewCollapsed animate:YES];
}

/**
 * Trigger a collapsible subview collapse or expand, optionally animating the transition.
 * This is the master collapse/expand method, called by any other methods to perform the work.
 */
- (void)setCollapsibleSubviewCollapsed:(BOOL)shouldCollapse animate:(BOOL)shouldAnimate
{
	if (collapsibleSubviewIndex == NSNotFound || shouldCollapse == collapsibleSubviewCollapsed) {
		return;
	}

	collapsibleSubviewCollapsed = shouldCollapse;
	[collapseToggleButton setState:(shouldCollapse?NSOnState:NSOffState)];

	NSView *viewToAnimate = [[self subviews] objectAtIndex:collapsibleSubviewIndex];
	animationStartSize = [self _lengthOfView:viewToAnimate];

	if (shouldCollapse) {

		// If collapsing, ensure the original view is wrapped in a helper view to avoid
		// animation resizes of the contained view.  (Uncollapses will already be wrapped.)
		if (![viewToAnimate isMemberOfClass:[SPSplitViewHelperView class]]) { 
			[[[SPSplitViewHelperView alloc] initReplacingView:viewToAnimate inVerticalSplitView:[self isVertical]] autorelease];
			viewToAnimate = [[self subviews] objectAtIndex:collapsibleSubviewIndex];
		}

		animationTargetSize = 0;
	} else {
		animationTargetSize = [self _lengthOfView:[[viewToAnimate subviews] objectAtIndex:0]];
	}

	// If not animating, update the view at once
	if (!shouldAnimate) {
		[self adjustSubviews];

	// Otherwise, start an animation.
	} else {
		if (animationTimer) [animationTimer invalidate], SPClear(animationTimer);
		if (animationRetainCycleBypassObject) SPClear(animationRetainCycleBypassObject);
		animationStartTime = [NSDate monotonicTimeInterval];

		// Determine the animation length, in seconds, starting with a quarter of a second
		animationDuration = 0.25f;

		// Make it a slow animation if appropriate
		if ([[NSApp currentEvent] type] == NSLeftMouseUp && [[NSApp currentEvent] modifierFlags] & NSEventModifierFlagShift) {
			animationDuration *= 10;
		}

		// Modify the duration by the proportion of any interrupted animation
		CGFloat fullViewSize = [self _lengthOfView:[[viewToAnimate subviews] objectAtIndex:0]];
		if (shouldCollapse) {
			animationDuration *= animationStartSize / fullViewSize;
		} else {
			animationDuration *= (animationTargetSize - animationStartSize) / fullViewSize;
		}

		// Create an object to avoid NSTimer retain cycles
		animationRetainCycleBypassObject = [[SPSplitViewAnimationRetainCycleBypass alloc] initWithParent:self];

		// Start an animation at 30fps
		animationTimer = [[NSTimer timerWithTimeInterval:(1.f/30.f) target:animationRetainCycleBypassObject selector:@selector(_animationStep:) userInfo:nil repeats:YES] retain];
		[[NSRunLoop currentRunLoop] addTimer:animationTimer forMode:NSRunLoopCommonModes];
	}
}

#pragma mark -
#pragma mark Additional drag handle view

/**
 * Set an additional view, the frame rect of which will be used to provide an additional
 * drag handle to reposition the *first* divider.
 * This can also be set using the IBOutlet.
 */
- (void)setAdditionalDragHandleView:(NSView *)aView
{
	if ([aView window] != [self window]) {
		[NSException raise:NSInternalInconsistencyException format:@"Additional drag handle must be in the same window as the split view"];
	}

	additionalDragHandleView = aView;
}

#pragma mark -
#pragma mark Constraint management

/**
 * Set the minimum size of a view at the specified index.  Note that indexes cannot be kept
 * in sync with subsequent view deletions/additions, so these will continue to apply to the
 * specified index and not the view originally at that index.
 */
- (void)setMinSize:(CGFloat)newMinSize ofSubviewAtIndex:(NSUInteger)subviewIndex
{
	[self _ensureDefaultSubviewSizesToIndex:subviewIndex];

	// Verify against the max size
	if (newMinSize > [[viewMaximumSizes objectAtIndex:subviewIndex] floatValue]) {
		[NSException raise:NSInternalInconsistencyException format:@"Minimum size for a subview specified as larger than the maximum size"];
	}

	[viewMinimumSizes replaceObjectAtIndex:subviewIndex withObject:[NSNumber numberWithFloat:newMinSize]];
}

/**
 * Set the minimum size of a view at the specified index.  Note that indexes cannot be kept
 * in sync with subsequent view deletions/additions, so these will continue to apply to the
 * specified index and not the view originally at that index.
 */
- (void)setMaxSize:(CGFloat)newMaxSize ofSubviewAtIndex:(NSUInteger)subviewIndex
{
	[self _ensureDefaultSubviewSizesToIndex:subviewIndex];

	// Verify against the max size
	if (newMaxSize < [[viewMinimumSizes objectAtIndex:subviewIndex] floatValue]) {
		[NSException raise:NSInternalInconsistencyException format:@"Maximum size for a subview specified as smaller than the minimum size"];
	}

	[viewMaximumSizes replaceObjectAtIndex:subviewIndex withObject:[NSNumber numberWithFloat:newMaxSize]];
}

#pragma mark -
#pragma mark Sizing

/**
 * adjustSubviews adjusts the sizes of the subviews so they fill up the splitview fully.
 * With no constraints and no collapsible subviews, all the subviews are resized
 * proportionally; however this override method handles constraints and collapsible subviews,
 * as well as animating collapses when driven by a timer.
 *
 * When resizing starts, non-resizable subviews are first left at their default sizes,
 * and other views are resized proportionally.  If those views hit constraints set on the
 * object via setMinSize: or setMaxSize:, the constraints are respected, and other views 
 * continue to be resized.
 *
 * If that resize process cannot cope with the size change, non-resizable subviews are
 * resized, respecting constraints set via setMinSize: or setMaxSize:.
 *
 * If all constraints are hit, then resizing will start to exceed the constraints.
 */
- (void)adjustSubviews
{
	CGFloat totalAvailableSize = [self _lengthOfView:self];
	NSUInteger i, j, viewCount = [[self subviews] count];
	CGFloat dividerThickness = [self dividerThickness];

	// Amend the total length by non-hidden dividers
	for (i = 0; i < viewCount - 1; i++) {
		if (![self splitView:self shouldHideDividerAtIndex:i]) {
			totalAvailableSize -= dividerThickness;
		}
	}

	// Start by checking for valid sizes complying with all constraints
	NSArray *viewSizes = [self _suggestedSizesForTargetSize:totalAvailableSize respectingSpringsAndStruts:YES respectingConstraints:YES];

	// If that didn't produce a valid result, allow resizing of non-resizable views
	if (!viewSizes) {
		viewSizes = [self _suggestedSizesForTargetSize:totalAvailableSize respectingSpringsAndStruts:NO respectingConstraints:YES];
	}

	// If that still didn't produce a valid result, resort to resizing all views
	if (!viewSizes) {
		viewSizes = [self _suggestedSizesForTargetSize:totalAvailableSize respectingSpringsAndStruts:NO respectingConstraints:NO];
	}

	// Safety check
	if ([viewSizes count] < viewCount) {
		[super adjustSubviews];
		return;
	}

	BOOL isVertical = [self isVertical];

	CGFloat splitViewBreadth = isVertical ? [self frame].size.height : [self frame].size.width;

	NSRect *viewFramesAdjusted = calloc(sizeof(NSRect), viewCount);
	NSAlignmentOptions opts = ( [self isFlipped] ? NSAlignRectFlipped : (NSAlignmentOptions)0 ) | NSAlignAllEdgesNearest;
	CGFloat spaceRemaining = totalAvailableSize;
	CGFloat originPosition = 0;
	for (i = 0; i < viewCount; i++) {
		NSView *subview = [[self subviews] objectAtIndex:i];
		NSRect viewFrame = [subview frame];
		// modify the split axis with the calculated size (likely invalid for the given screen)
		if(isVertical) {
			viewFrame.size.width = [[viewSizes objectAtIndex:i] floatValue];
			viewFrame.origin.x = originPosition; // the post-10.7 method may take the origin into account
		}
		else {
			viewFrame.size.height = [[viewSizes objectAtIndex:i] floatValue];
			viewFrame.origin.y = originPosition;
		}

		// let the OS adjust the sizes to be valid (but possibly still not matching totalAvailableSize in sum)
		if(isOSAtLeast10_7) {
			viewFrame = [self backingAlignedRect:viewFrame options:opts];
		}
		else {
			// This code is taken from Apple's "BlurryView" example code.
			viewFrame = [self convertRectToBase:viewFrame];
			if(isVertical) {
				viewFrame.size.width = round(viewFrame.size.width);
			}
			else {
				viewFrame.size.height = round(viewFrame.size.height);
			}
			viewFrame = [self convertRectFromBase:viewFrame];
		}

		CGFloat viewSize = (isVertical ? viewFrame.size.width : viewFrame.size.height);

		if (isVertical) {
			originPosition = viewFrame.origin.x;
			viewFrame.size.height = splitViewBreadth;
		}
		else {
			originPosition = viewFrame.origin.y;
			viewFrame.size.width = splitViewBreadth;
		}

		originPosition += viewSize;

		if ((i + 1) < viewCount && ![self splitView:self shouldHideDividerAtIndex:(i + 1)]) {
			originPosition += dividerThickness;
		}

		spaceRemaining -= viewSize;
		viewFramesAdjusted[i] = viewFrame;
	}
	
	// The calculation above can have a remainder which we still need to put somewhere, otherwise Coco will complain.
	// Note: The remainder can be negative, too.
	// TODO: After the pre-10.7 method is dropped, evaluate alternating between NSAlignAllEdgesOutwards and NSAlignAllEdgesInwards instead, since this should not cause the remainder issue
	if (spaceRemaining != 0) {
		// We will just give it to the last non-zero (!) view and adjust the origin of all successors
		for (i = viewCount - 1; i >= 0; i--) {
			CGFloat len = isVertical ? viewFramesAdjusted[i].size.width : viewFramesAdjusted[i].size.height;
			if(len != 0) {
				//adjust self size
				if (isVertical) {
					viewFramesAdjusted[i].size.width += spaceRemaining;
				}
				else {
					viewFramesAdjusted[i].size.height += spaceRemaining;
				}
				// and shift all successors
				for (j = i + 1; j < viewCount; j++) {
					if (isVertical) {
						viewFramesAdjusted[j].origin.x += spaceRemaining;
					}
					else {
						viewFramesAdjusted[j].origin.y += spaceRemaining;
					}
				}
				break;
			}
		}
	}
	
	// Apply the size changes to the views.
	for (i = 0; i < viewCount; i++) {
		NSView *subview = [[self subviews] objectAtIndex:i];
		NSRect viewFrame = viewFramesAdjusted[i];
		[subview setFrame:viewFrame];
	}
	
	free(viewFramesAdjusted);

	// Invalidate the cursor rects
	[[self window] invalidateCursorRectsForView:self];
}

#pragma mark -
#pragma mark Delegate method overrides

/**
 * Handle requests to collapse a particular subview.  If a subview is collapsible,
 * by default this will return YES for that subview and NO for all others.
 * The delegate can override this if necessary.
 */
- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview
{
	if ([delegate respondsToSelector:@selector(splitView:canCollapseSubview:)]) {
		return [delegate splitView:splitView canCollapseSubview:subview];
	}

	if (collapsibleSubviewIndex != NSNotFound && [[self subviews] objectAtIndex:collapsibleSubviewIndex] == subview) {
		return YES;
	}

	return NO;
}

/**
 * Handle requests as to whether a subview should be collapsed as a result of
 * a double-click on a divider.  If a subview is collapsible, by default this
 * will return NO, but an animated collapse/expand will be triggered instead to
 * perform the same action with animation.
 * The delegate can override this if necessary.
 */
- (BOOL)splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex
{
	if ([delegate respondsToSelector:@selector(splitView:shouldCollapseSubview:forDoubleClickOnDividerAtIndex:)]) {
		return [delegate splitView:splitView shouldCollapseSubview:subview forDoubleClickOnDividerAtIndex:dividerIndex];
	}

	// If there's no collapsible subview, don't allow collapse
	if (collapsibleSubviewIndex == NSNotFound) {
		return NO;
	}

	// Ensure the divider is adjacent to the collapsible view
	if ((NSUInteger)dividerIndex != collapsibleSubviewIndex && (NSUInteger)dividerIndex != (collapsibleSubviewIndex - 1)) {
		return NO;
	}

	// Trigger an animated collapse and prevent the original collapse
	[self setCollapsibleSubviewCollapsed:YES animate:YES];
	return NO;
}

/**
 * While the collapsible subview is collapsed, hide the adjacent divider.
 *
 * Forwards requests on to the original delegate to allow overrides.
 */
- (BOOL)splitView:(NSSplitView *)splitView shouldHideDividerAtIndex:(NSInteger)dividerIndex
{
	if ([delegate respondsToSelector:@selector(splitView:shouldHideDividerAtIndex:)]) {
		return [delegate splitView:splitView shouldHideDividerAtIndex:dividerIndex];
	}

	// If there's no collapsible subview, or it's not hidden, don't hide any dividers
	if (!collapsibleSubviewCollapsed || collapsibleSubviewIndex == NSNotFound) {
		return NO;
	}

	// Only hide one divider adjacent to the collapsible view
	if ((collapsibleSubviewIndex == 0 && dividerIndex > 0) || (collapsibleSubviewIndex > 0 && (NSUInteger)(dividerIndex + 1) != collapsibleSubviewIndex)) {
		return NO;
	}

	// If the collapsible subview is fully collapsed, hide the divider
	if (!animationTimer) {
		return YES;
	}

	return NO;
}

/**
 * Handle delegate requests for a minimum size for the splitview above or to the left of
 * the supplied divider index, using the minimum constraints supplied via setMinSize: if
 * present.
 *
 * Only the two views adjacent to the supplied divider index are currently considered.
 *
 * Forwards requests on to the original delegate to allow overrides.
 */
- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	if ([delegate respondsToSelector:@selector(splitView:constrainMinCoordinate:ofSubviewAt:)]) {
		return [delegate splitView:splitView constrainMinCoordinate:proposedMinimumPosition ofSubviewAt:dividerIndex];
	}

	NSView *aView;
	CGFloat preMinPosition = 0, postMaxPosition = 0;

	[self _ensureDefaultSubviewSizesToIndex:(dividerIndex + 1)];

	// Check the minimum size of the preceeding view
	CGFloat preMinSize = [[viewMinimumSizes objectAtIndex:dividerIndex] floatValue];
	if (preMinSize) {
		aView = [[self subviews] objectAtIndex:dividerIndex];
		preMinPosition = [self _startPositionOfView:aView] + preMinSize;
	}

	// Check the maximum size of the following view
	CGFloat postMaxSize = [[viewMaximumSizes objectAtIndex:(dividerIndex + 1)] floatValue];
	if (postMaxSize != FLT_MAX) {
		aView = [[self subviews] objectAtIndex:(dividerIndex + 1)];
		postMaxPosition = [self _startPositionOfView:aView] + [self _lengthOfView:aView] - postMaxSize - [self dividerThickness];
	}

	CGFloat suggestedMinimum = fmaxf(preMinPosition, postMaxPosition);
	if (suggestedMinimum > proposedMinimumPosition) {
		return suggestedMinimum;
	}

	return proposedMinimumPosition;
}

/**
 * Handle delegate requests for a maximum size for the splitview above or to the left of
 * the supplied divider index, using the maximum constraints supplied via setMaxSize: if
 * present.
 *
 * Only the two views adjacent to the supplied divider index are currently considered.
 *
 * Forwards requests on to the original delegate to allow overrides.
 */
- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	if ([delegate respondsToSelector:@selector(splitView:constrainMaxCoordinate:ofSubviewAt:)]) {
		return [delegate splitView:splitView constrainMaxCoordinate:proposedMaximumPosition ofSubviewAt:dividerIndex];
	}

	NSView *aView;
	CGFloat preMaxPosition = FLT_MAX, postMinPosition = FLT_MAX;

	[self _ensureDefaultSubviewSizesToIndex:(dividerIndex + 1)];

	// Check the maximum size of the preceeding view
	CGFloat preMaxSize = [[viewMaximumSizes objectAtIndex:dividerIndex] floatValue];
	if (preMaxSize != FLT_MAX) {
		aView = [[self subviews] objectAtIndex:dividerIndex];
		preMaxPosition = [self _startPositionOfView:aView] + preMaxSize;
	}

	// Check the minimum size of the following view
	CGFloat postMinSize = [[viewMinimumSizes objectAtIndex:(dividerIndex + 1)] floatValue];
	if (postMinSize) {
		aView = [[self subviews] objectAtIndex:(dividerIndex + 1)];
		postMinPosition = [self _startPositionOfView:aView] + [self _lengthOfView:aView] - postMinSize - [self dividerThickness];
	}

	CGFloat suggestedMaximum = fminf(preMaxPosition, postMinPosition);
	if (suggestedMaximum < proposedMaximumPosition) {
		return suggestedMaximum;
	}

	return proposedMaximumPosition;
}

/**
 * If an additional drag handle is set - in the nib or in code - return its rect as an
 * additional effective rect.
 *
 * Forwards requests on to the original delegate to allow overrides.
 */
- (NSRect)splitView:(NSSplitView *)splitView additionalEffectiveRectOfDividerAtIndex:(NSInteger)dividerIndex
{
	if ([delegate respondsToSelector:@selector(splitView:additionalEffectiveRectOfDividerAtIndex:)]) {
		return [delegate splitView:splitView additionalEffectiveRectOfDividerAtIndex:dividerIndex];
	}

	// If a view is set, return its frame in the splitview coordinate system
	if (additionalDragHandleView) {
		NSRect dragRect = [additionalDragHandleView frame];
		dragRect.origin = [self convertPoint:dragRect.origin fromView:[additionalDragHandleView superview]];
		if ([additionalDragHandleView isFlipped] != [self isFlipped]) {
			dragRect.origin.y -= dragRect.size.height;
		}
		return dragRect;
	}

	return NSZeroRect;
}

/**
 * Listen to view resize delegate notifications, to track collapses triggered by dragging
 * a view to zero size.
 *
 * Also forwards the event on to the delegate for further handling.
 */
- (void)splitViewDidResizeSubviews:(NSNotification *)notification
{

	// If the collapsible subview was collapsed using (for example) a drag,
	// track the collapse correctly.
	if (collapsibleSubviewIndex != NSNotFound && !collapsibleSubviewCollapsed) {
		if ([[[self subviews] objectAtIndex:collapsibleSubviewIndex] isHidden]) {
			[[[self subviews] objectAtIndex:collapsibleSubviewIndex] setHidden:NO];
			[self setCollapsibleSubviewCollapsed:YES animate:NO];
		}
	}

	[self _saveAutoSaveSizes];

	// Do the same for expansions
	if (collapsibleSubviewIndex != NSNotFound && collapsibleSubviewCollapsed) {
		if (!animationTimer && [self _lengthOfView:[[self subviews] objectAtIndex:collapsibleSubviewIndex]]) {
			[self setCollapsibleSubviewCollapsed:NO animate:NO];
		}
	}

	if ([delegate respondsToSelector:@selector(splitViewDidResizeSubviews:)]) {
		[delegate splitViewDidResizeSubviews:notification];
	}
}

#pragma mark -
#pragma mark Delegate method forwarding

- (CGFloat)splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)dividerIndex
{
	if ([delegate respondsToSelector:@selector(splitView:constrainSplitPosition:ofSubviewAt:)]) {
		return [delegate splitView:splitView constrainSplitPosition:proposedPosition ofSubviewAt:dividerIndex];
	}

	return proposedPosition;
}

- (NSRect)splitView:(NSSplitView *)splitView effectiveRect:(NSRect)proposedEffectiveRect forDrawnRect:(NSRect)drawnRect ofDividerAtIndex:(NSInteger)dividerIndex
{
	if ([delegate respondsToSelector:@selector(splitView:effectiveRect:forDrawnRect:ofDividerAtIndex:)]) {
		return [delegate splitView:splitView effectiveRect:proposedEffectiveRect forDrawnRect:drawnRect ofDividerAtIndex:dividerIndex];
	}

	return proposedEffectiveRect;
}

- (BOOL)splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)view
{
	if ([delegate respondsToSelector:@selector(splitView:shouldAdjustSizeOfSubview:)]) {
		return [(id)delegate splitView:splitView shouldAdjustSizeOfSubview:view];
	}

	return YES;
}

- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize
{
	if ([delegate respondsToSelector:@selector(splitView:resizeSubviewsWithOldSize:)]) {
		return [delegate splitView:splitView resizeSubviewsWithOldSize:oldSize];
	}

	return [self adjustSubviews];
}

- (void)splitViewWillResizeSubviews:(NSNotification *)notification
{
	if ([delegate respondsToSelector:@selector(splitViewWillResizeSubviews:)]) {
		[delegate splitViewWillResizeSubviews:notification];
	}
}

#pragma mark -
#pragma mark Private API

- (void)_initCustomProperties
{
	collapseToggleButton = nil;
	additionalDragHandleView = nil;

	collapsibleSubviewIndex = NSNotFound;
	collapsibleSubviewCollapsed = NO;

	animationStartTime = 0;
	animationTimer = nil;
	animationRetainCycleBypassObject = nil;

	// Set up the maximum and minimum length arrays.  Note that because there are no
	// notifications for subviews being removed, these cannot be kept in sync with the
	// actual view count - so these are only set via index, not view, and length-checked
	// on every use for safety.
	NSUInteger l = [[self subviews] count];
	viewMinimumSizes = [[NSMutableArray alloc] initWithCapacity:l];
	viewMaximumSizes = [[NSMutableArray alloc] initWithCapacity:l];
	[self _ensureDefaultSubviewSizesToIndex:l-1];

	delegate = [super delegate];
	
	[super setDelegate:self];
}

/**
 * Add default sizing information for a new subview up to at least a specified index;
 * no maximum or minimum sizes for the subviews, but ensuring the arrays are set up.
 */
- (void)_ensureDefaultSubviewSizesToIndex:(NSUInteger)anIndex
{
	if ([viewMinimumSizes count] > anIndex) {
		return;
	}

	for (NSUInteger i = [viewMinimumSizes count]; i <= anIndex; i++) {
		[viewMinimumSizes addObject:[NSNumber numberWithFloat:0]];
		[viewMaximumSizes addObject:[NSNumber numberWithFloat:FLT_MAX]];
	}
}

#pragma mark -

/**
 * Save the current dimensions of each subview if there is an autosaveName set on
 * the splitview.  This seems to be required on Lion (or when certain versions of
 * Xcode build?) where the normal autosave behaviour overwrites itself with the
 * original startup position, possibly due to a race condition.
 */
- (void)_saveAutoSaveSizes
{
	if (![self autosaveName]) {
		return;
	}

	NSMutableArray *viewDetails = [NSMutableArray arrayWithCapacity:[[self subviews] count]];
	for (NSView *eachView in [self subviews]) {
		[viewDetails addObject:[NSNumber numberWithFloat:[self _lengthOfView:eachView]]];
	}
	[[NSUserDefaults standardUserDefaults] setObject:viewDetails forKey:[NSString stringWithFormat:@"SPSplitView Lengths %@", [self autosaveName]]];
}

/**
 * Restore the current dimensions of each subview if there is an autosaveName and
 * if there is a saved position; see _saveAutoSaveSizes.
 */
- (void)_restoreAutoSaveSizes
{
	if (![self autosaveName]) {
		return;
	}

	NSArray *viewDetails = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"SPSplitView Lengths %@", [self autosaveName]]];
	if (!viewDetails) {
		return;
	}

	for (NSUInteger i = 0; i < [[self subviews] count] - 1; i++) {
		[self setPosition:[[viewDetails objectAtIndex:i] floatValue] ofDividerAtIndex:i];
	}
}

#pragma mark -

/**
 * Generate an array of suggested view lengths along the split view lengthwise axis,
 * respecting spring/strut or min/max size constraints as appropriate.
 * If the supplied constraints cannot be respected, returns nil.
 */
- (NSArray *)_suggestedSizesForTargetSize:(CGFloat)targetSize respectingSpringsAndStruts:(BOOL)respectStruts respectingConstraints:(BOOL)respectConstraints
{
	NSUInteger i;
	NSUInteger subviewCount = [[self subviews] count];
	NSView *eachSubview;
	BOOL viewIsAnimating;
	float viewLength, sizeDifference, totalGive, changedLength;
	float totalCurrentSize = 0;
	float resizeProportionTotal = 1.f;
	float *originalSizes = calloc(subviewCount, sizeof(float));
	float *minSizes = calloc(subviewCount, sizeof(float));
	float *maxSizes = calloc(subviewCount, sizeof(float));
	BOOL *sizesCalculated;
	float *resizeProportions;
	NSMutableArray *outputSizes = [NSMutableArray arrayWithCapacity:subviewCount];

	[self _ensureDefaultSubviewSizesToIndex:(subviewCount + 1)];

	// Step through all the views, first getting a list of their initial sizes, as well as
	// performing any animation-related cleanup
	for (i = 0; i < subviewCount; i++) {
		eachSubview = [[self subviews] objectAtIndex:i];
		viewLength = [self _lengthOfView:eachSubview];
		viewIsAnimating = (i == collapsibleSubviewIndex && animationTimer);

		// Determine the min and max sizes for this view.
		if (i == collapsibleSubviewIndex && collapsibleSubviewCollapsed && !viewIsAnimating) {
			minSizes[i] = 0.f;
			maxSizes[i] = 0.f;
		} else if (i == collapsibleSubviewIndex && !viewLength && animationTargetSize && !viewIsAnimating && [eachSubview isKindOfClass:[SPSplitViewHelperView class]]) {
			minSizes[i] = animationTargetSize;
			maxSizes[i] = animationTargetSize;
		} else if (respectStruts && ![self _isViewResizable:eachSubview]) {
			minSizes[i] = viewLength;
			maxSizes[i] = viewLength;
		} else if (respectConstraints) {
			minSizes[i] = [[viewMinimumSizes objectAtIndex:i] floatValue];
			maxSizes[i] = [[viewMaximumSizes objectAtIndex:i] floatValue];
		} else {
			minSizes[i] = 0.f;
			maxSizes[i] = FLT_MAX;
		}

		// If this isn't the collapsible subview, or if there's no collapse animation, measure
		// the view and continue.
		if (!viewIsAnimating) {

			// Restore the original view if necessary
			if ([eachSubview isKindOfClass:[SPSplitViewHelperView class]] && !collapsibleSubviewCollapsed && (viewLength || animationTargetSize)) {
				[(SPSplitViewHelperView *)eachSubview restoreOriginalView];
			}

			originalSizes[i] = viewLength;
			totalCurrentSize += viewLength;
			[outputSizes addObject:[NSNumber numberWithFloat:viewLength]];
			continue;
		}

		// The collapsible subview is collapsing or uncollapsing.  Prepare to update the sizes...
		double currentTime = [NSDate monotonicTimeInterval];
		float animationProgress = (float)((currentTime - animationStartTime) / animationDuration);
		if (animationProgress > 1) animationProgress = 1;

		// If the animation has reached the end, ensure completion tasks are run
		if (animationProgress == 1) {
			if (animationTimer) [animationTimer invalidate], SPClear(animationTimer);
			if (animationRetainCycleBypassObject) SPClear(animationRetainCycleBypassObject);

			// If uncollapsing, restore the original view and remove the helper
			if (!collapsibleSubviewCollapsed) {
				[(SPSplitViewHelperView *)eachSubview restoreOriginalView];
			}
		}

		// Calculate the size for this point in the animation
		if (collapsibleSubviewCollapsed) {
			viewLength = animationStartSize * (1 - animationProgress);
		} else {
			viewLength = animationStartSize + ((animationTargetSize - animationStartSize) * animationProgress);
		}
		viewLength = roundf(viewLength);

		// Max and min should always be clamped to the animated view size
		minSizes[i] = viewLength;
		maxSizes[i] = viewLength;

		// Insert the modified view size
		totalCurrentSize += viewLength;
		originalSizes[i] = viewLength;
		[outputSizes addObject:[NSNumber numberWithFloat:viewLength]];
	}

	sizeDifference = targetSize - totalCurrentSize;

	// Compare the min/max lengths to the target length and see if there's sufficient give
	// as well as working out the resize proportions
	totalGive = 0;
	for (i = 0; i < subviewCount; i++) {
		if (sizeDifference > 0) {
			if (maxSizes[i] == FLT_MAX) {
				totalGive = FLT_MAX;
				break;
			}
			totalGive += maxSizes[i] - originalSizes[i];
		} else {
			totalGive += originalSizes[i] - minSizes[i];
		}
	}

	// If there isn't sufficient give, return nil to allow a retry with fewer constraints
	if (totalGive < fabsf(sizeDifference)) {
		free(originalSizes);
		free(minSizes);
		free(maxSizes);
		return nil;
	}

	// Set up some arrays for fast lookups
	sizesCalculated = calloc(subviewCount, sizeof(BOOL));
	resizeProportions = calloc(subviewCount, sizeof(float));

	// Prepopulate them
	for (i = 0; i < subviewCount; i++) {
		sizesCalculated[i] = NO;
		if (!totalCurrentSize) {
			resizeProportions[i] = 0.f;
		} else {
			resizeProportions[i] = originalSizes[i] / totalCurrentSize;
		}
	}

	// In a loop, determine whether any constraints would be hit, and if so, match them
	// and update remaining proportions.
	BOOL iteratingConstraints = YES;
	while (iteratingConstraints) {
		iteratingConstraints = NO;
		for (i = 0; i < subviewCount; i++) {
			if (sizesCalculated[i]) continue;

			// Check whether the size constraints are reached for this view.  If so, record the
			// limited view size, and break the loop.
			viewLength = originalSizes[i] + (sizeDifference * resizeProportions[i]/resizeProportionTotal);
			if (viewLength > maxSizes[i] || viewLength < minSizes[i]) {

				// Track the change in size, if any
				if (viewLength > maxSizes[i]) {
					changedLength = maxSizes[i];
				} else {
					changedLength = minSizes[i];
				}
				sizeDifference = sizeDifference + originalSizes[i] - changedLength;

				// Alter the overall proportion total modifier
				resizeProportionTotal -= resizeProportions[i];

				// Amend the output size and prepare to re-loop from the start
				[outputSizes replaceObjectAtIndex:i withObject:[NSNumber numberWithFloat:changedLength]];
				sizesCalculated[i] = YES;
				iteratingConstraints = YES;
				break;
			}
		}

		// If, after any changes, all the remaining subview proportions are 0, resize
		// them equally.
		BOOL allSubviewsZeroSized = YES;
		for (i = 0; i < subviewCount; i++) {
			if (sizesCalculated[i]) continue;

			if (resizeProportions[i] > 0.f) {
				allSubviewsZeroSized = NO;
				break;
			}
		}
		if (allSubviewsZeroSized) {
			resizeProportionTotal = 1.f;
			for (i = 0; i < subviewCount; i++) {
				if (sizesCalculated[i]) continue;
				resizeProportions[i] = 1.f / subviewCount;
			}
		}
	}

	// All constraints have now been dealt with; populate all other output sizes proportionally.
	for (i = 0; i < subviewCount; i++) {
		if (sizesCalculated[i]) continue;

		viewLength = originalSizes[i] + (sizeDifference * resizeProportions[i]/resizeProportionTotal);
		[outputSizes replaceObjectAtIndex:i withObject:[NSNumber numberWithFloat:viewLength]];
	}

	// Clean up and return
	free(originalSizes);
	free(minSizes);
	free(maxSizes);
	free(sizesCalculated);
	free(resizeProportions);

	return outputSizes;
}

#pragma mark -

/**
 * Retrieve the start position of a view, using the lengthwise axis of the splitview.
 */
- (CGFloat)_startPositionOfView:(NSView *)aView
{
	if ([self isVertical]) {
		return [aView frame].origin.x;
	}
	return [aView frame].origin.y;
}

/**
 * Retrieve the length of a view, along the lengthwise axis of the splitview.
 */
- (CGFloat)_lengthOfView:(NSView *)aView
{
	if ([self isVertical]) {
		return [aView frame].size.width;
	}
	return [aView frame].size.height;
}

/**
 * Update the start position of a view, using the lengthwise axis of the splitview.
 */
- (void)_setStartPosition:(CGFloat)newOrigin ofView:(NSView *)aView
{
	if ([self isVertical]) {
		return [aView setFrameOrigin:NSMakePoint(newOrigin, [aView frame].origin.y)];
	}
	return [aView setFrameOrigin:NSMakePoint([aView frame].origin.x, newOrigin)];
}

/**
 * Update the length of a view, along the lengthwise axis of the splitview.
 */
- (void)_setLength:(CGFloat)newLength ofView:(NSView *)aView
{
	if ([self isVertical]) {
		return [aView setFrameSize:NSMakeSize(newLength, [aView frame].size.height)];
	}
	return [aView setFrameSize:NSMakeSize([aView frame].size.width, newLength)];
}

#pragma mark -

/**
 * Determine whether the supplied view is defined as resizable along the split view's
 * lengthwise axis in the xib files - whether springs/struts constrain resizing.
 */
- (BOOL)_isViewResizable:(NSView *)aView
{
	if ([self isVertical]) {
		return ([aView autoresizingMask] & NSViewWidthSizable);
	}
	return ([aView autoresizingMask] & NSViewHeightSizable);
}

@end

#pragma mark -
#pragma mark Animation transition view class

@implementation SPSplitViewHelperView

/**
 * Initialise the helper view with a specified view; the helper view replaces the
 * specified view, adding it as a subview to maintain the same appearance, and then
 * can be animated without affecting the contained view.
 */
- (instancetype)initReplacingView:(NSView *)aView inVerticalSplitView:(BOOL)verticalSplitView
{
	self = [super initWithFrame:[aView frame]];
	if (!self) return nil;

	NSAutoresizingMaskOptions wrappedResizeMask = [wrappedView autoresizingMask];

	// Retain the wrapped view while this view exists
	wrappedView = [aView retain];

	// Copy over the autoresizing mask from the wrapped view to this view, to keep the same
	// draw appearance during the resize.
	[self setAutoresizingMask:wrappedResizeMask];

	// Amend the wrapped view's autoresize mask.  Keep the autosizing across the breadth of
	// the split view, but amend the autosizing along the lengthwise axis of the split view
	// so that no sizing occurs, only a flexible margin to allow resizing
	if (verticalSplitView) {
		wrappedResizeMask &= ~NSViewMinXMargin;
		wrappedResizeMask &= ~NSViewWidthSizable;
		wrappedResizeMask |= NSViewMaxXMargin;
	} else {
		wrappedResizeMask &= ~NSViewMaxYMargin;
		wrappedResizeMask &= ~NSViewHeightSizable;
		wrappedResizeMask |= NSViewMinYMargin;
	
	}
	[wrappedView setAutoresizingMask:wrappedResizeMask];

	// Swap the views
	[[wrappedView superview] replaceSubview:wrappedView with:self];
	[wrappedView setFrameOrigin:NSMakePoint(0, 0)];
	[self addSubview:wrappedView];

	return self;
}

/**
 * Restore the original view once the animation is complete.  This should only
 * be called when the view height has been restored.
 */
- (void)restoreOriginalView
{

	// Safety checks
	if (!wrappedView || ![self frame].size.height || ![self frame].size.width) {
		return;
	}

	// Check for a first responder to restore, using the "true" first responder for field editors
	NSResponder *firstResponderToRestore = [[self window] firstResponder];
	
	if ([firstResponderToRestore respondsToSelector:@selector(isFieldEditor)] && [(NSText *)firstResponderToRestore isFieldEditor]) {
		firstResponderToRestore = (NSResponder *)[(NSText *)firstResponderToRestore delegate];
	}
	if (![firstResponderToRestore isKindOfClass:[NSView class]] || ![(NSView *)firstResponderToRestore isDescendantOf:wrappedView]) {
		firstResponderToRestore = nil;
	}
	
	// Restore the view's original resize mark now that the size changes are complete
	[wrappedView setAutoresizingMask:[self autoresizingMask]];

	// Replace this view with the original wrapped view
	[wrappedView removeFromSuperview];
	[[self superview] replaceSubview:self with:wrappedView];

	// Restore the first responder if appropriate
	if (firstResponderToRestore) {
		[[wrappedView window] makeFirstResponder:firstResponderToRestore];
	}
	
	// see #3271 - This is a quick workaround for 10.14 not properly redrawing the view
	[wrappedView setNeedsDisplay:YES];

	SPClear(wrappedView);
}

- (void)dealloc
{
	if (wrappedView) SPClear(wrappedView);

	[super dealloc];
}

@end

#pragma mark -
#pragma mark Retain cycle avoidance class

@implementation SPSplitViewAnimationRetainCycleBypass

- (instancetype)initWithParent:(SPSplitView *)aSplitView
{
	self = [super init];
	if (!self) return nil;

	// Keep a weak link to the parent
	parentSplitView = aSplitView;

	return self;
}

- (void)_animationStep:(NSTimer *)aTimer
{
	[parentSplitView adjustSubviews];

	// this is required on 10.14 in order to have the dividers move properly, because that OS version forces a layer-backed
	// view and at the same time calls -layout much less often than previous OS X versions, resulting in outdated dividers.
	// That is not an issue on older OS X versions where -drawRect: was used.
	if(isOSAtLeast10_7) {
		[parentSplitView setNeedsLayout:YES]; // 10.7+
	}
}

@end

