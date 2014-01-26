//
//  SPSplitView.h
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

@class SPSplitViewAnimationRetainCycleBypass;

@interface SPSplitView : NSSplitView <NSSplitViewDelegate>
{
	id<NSSplitViewDelegate> delegate;

	IBOutlet NSButton *collapseToggleButton;
	IBOutlet NSView *additionalDragHandleView;

	NSUInteger collapsibleSubviewIndex;
	BOOL collapsibleSubviewCollapsed;

	double animationStartTime;
	double animationDuration;
	NSTimer *animationTimer;
	SPSplitViewAnimationRetainCycleBypass *animationRetainCycleBypassObject;
	float animationStartSize;
	float animationTargetSize;

	NSMutableArray *viewMinimumSizes;
	NSMutableArray *viewMaximumSizes;
}

// Collapsing/expanding
- (void)setCollapsibleSubviewIndex:(NSUInteger)subviewIndex;
- (void)setToggleCollapseButton:(NSButton *)aButton;
- (BOOL)isCollapsibleSubviewCollapsed;
- (IBAction)toggleCollapse:(id)sender;
- (void)setCollapsibleSubviewCollapsed:(BOOL)shouldCollapse animate:(BOOL)shouldAnimate;

// Additional drag handle
- (void)setAdditionalDragHandleView:(NSView *)aView;

// Constraints
- (void)setMinSize:(CGFloat)newMinSize ofSubviewAtIndex:(NSUInteger)subviewIndex;
- (void)setMaxSize:(CGFloat)newMaxSize ofSubviewAtIndex:(NSUInteger)subviewIndex;

@end
