//
//  $Id$
//
//  SPColorSelectorView.m
//  sequel-pro
//
//  Created by Max Lohrmann on 2013-10-20
//  Copyright (c) 2013 Max Lohrmann. All rights reserved.
//
//  Adapted from:
//    CCTColorLabelMenuItemView.m
//    LabelPickerMenu
//
//    Copyright (c) 2010 Dan Messing. All Rights Reserved.
//
//  Based on:
//    TrackView.m
//    MenuItemView example code
//
//    Copyright (C) Apple Inc. All Rights Reserved.
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
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPColorSelectorView.h"

@interface SPColorSelectorView (Private)

- (void)setupTrackingAreas;

@end

@implementation SPColorSelectorView

@synthesize selectedTag;
@synthesize colorList;

// key for dictionary in NSTrackingAreas's userInfo
NSString* kTrackerKey = @"whichTracker";

// key values for dictionary in NSTrackingAreas's userInfo,
// which tracking area is being tracked
enum trackingAreaIDs
{
	kTrackingAreaNone = -1,
	kTrackingArea0,
	kTrackingArea1,
	kTrackingArea2,
	kTrackingArea3,
	kTrackingArea4,
	kTrackingArea5,
	kTrackingArea6
};

// -------------------------------------------------------------------------------
//	initWithFrame:
//
//	Setup the tracking areas for each colored dot.
// -------------------------------------------------------------------------------
- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect])) {
		
		selectedTag = kTrackingAreaNone; //we start out with no selection
		observer = nil;
		colorList = nil;
		[self setupTrackingAreas];
		
		//set ourselves as observer of selectedTag (need to mark view dirty)
		[self addObserver:self forKeyPath:@"selectedTag" options:0 context:nil];
	}
	
	return self;
}

- (void)bind:(NSString *)binding toObject:(id)observableObject withKeyPath:(NSString *)keyPath options:(NSDictionary *)options
{
	if ([binding isEqualToString:@"selectedTag"]) {
		[observableObject addObserver:self forKeyPath:keyPath options:0 context:nil];
		observer = [observableObject retain];
		observerKeyPath = [keyPath copy];
	}
	else {
		[super bind:binding toObject:observableObject withKeyPath:keyPath options:options];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == self) {
		[self setNeedsDisplay:YES];
	}
	else if (object == observer) {
		// You passed the binding identifier as the context when registering
		// as an observer--use that to decide what to update...

        id newValue = [observer valueForKeyPath:observerKeyPath];
	
		NSNumber *num = (NSNumber *)newValue;

		[self setSelectedTag:[num integerValue]];
	}
}

// -------------------------------------------------------------------------------
//	Returns the rectangle corresponding to the tracking area.
// -------------------------------------------------------------------------------
- (NSRect)rectForColorViewAtIndex:(NSInteger)index
{
	CGFloat baseY = 2.0;
	CGFloat baseX = 2.0;
	
	CGFloat marginR = 5.0;
	
	CGFloat width = 16.0;
	CGFloat height = 16.0;
	
	NSRect returnRect = NSZeroRect;
	
	switch (index)
	{
		case kTrackingAreaNone:
			returnRect = NSMakeRect(baseX, baseY, width, height);
			break;
			
		case kTrackingArea0:
			returnRect = NSMakeRect(baseX + 1 * (width + marginR), baseY, width, height);
			break;
			
		case kTrackingArea1:
			returnRect = NSMakeRect(baseX + 2 * (width + marginR), baseY, width, height);
			break;
			
		case kTrackingArea2:
			returnRect = NSMakeRect(baseX + 3 * (width + marginR), baseY, width, height);
			break;
			
		case kTrackingArea3:
			returnRect = NSMakeRect(baseX + 4 * (width + marginR), baseY, width, height);
			break;
			
		case kTrackingArea4:
			returnRect = NSMakeRect(baseX + 5 * (width + marginR), baseY, width, height);
			break;
			
		case kTrackingArea5:
			returnRect = NSMakeRect(baseX + 6 * (width + marginR), baseY, width, height);
			break;
			
		case kTrackingArea6:
			returnRect = NSMakeRect(baseX + 7 * (width + marginR), baseY, width, height);
			break;
	}
	
	return returnRect;
}

// -------------------------------------------------------------------------------
//	Returns the color gradient corresponding to the tag. These colours were
//  chosen to appear similar to those in Aperture 3.
// -------------------------------------------------------------------------------

- (NSGradient *)gradientForTag:(NSInteger)colorTag
{
	NSGradient *gradient = nil;
	
	//find base color item
	NSColor *baseColor = (NSColor *)[colorList objectAtIndex:colorTag];
	
	if (!baseColor) return nil;
	
	//create hightlight and shadow variants of color
	NSColor *shadowColor = [baseColor shadowWithLevel:0.22];
	NSColor *highlightColor = [baseColor highlightWithLevel:0.22];
	
	//build gradient
	gradient = [[NSGradient alloc] initWithColorsAndLocations:
				highlightColor, 0.0,
				baseColor, 0.5,
				shadowColor, 1.0, nil];
	
	return [gradient autorelease];
}

// -------------------------------------------------------------------------------
//	setupTrackingAreas:
// -------------------------------------------------------------------------------
- (void)setupTrackingAreas
{
	if (trackingAreas == nil)
	{
		trackingAreas = [NSMutableArray array];	// keep all tracking areas in an array
		
		// determine the tracking options
		NSTrackingAreaOptions trackingOptions = NSTrackingEnabledDuringMouseDrag |
		NSTrackingMouseEnteredAndExited |
		NSTrackingActiveInActiveApp |
		NSTrackingActiveAlways;
		
		NSInteger index;
		
		for (index = kTrackingAreaNone; index <= kTrackingArea6; index++)
		{
			// make tracking data (to be stored in NSTrackingArea's userInfo) so we can later determine which tracking area is focused on
			//
			NSDictionary* trackerData = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithInteger:index], kTrackerKey, nil];
			NSTrackingArea* trackingArea = [[NSTrackingArea alloc] initWithRect:[self rectForColorViewAtIndex:index]
																		options:trackingOptions
																		  owner:self
																	   userInfo:trackerData];
			
			[trackingAreas addObject:trackingArea];	// keep track of this tracking area for later disposal
			[self addTrackingArea: trackingArea];	// add the tracking area to the view/window
		}
	}
}

#pragma mark -
#pragma mark Custom Drawing

// -------------------------------------------------------------------------------
//	drawRect:rect
//
//	Examine all the sub-view colored dots and color them with their appropriate colors.
// -------------------------------------------------------------------------------
- (void)drawRect:(NSRect)rect
{
	// see if we should be drawing any of the tags as already selected
	NSInteger currentlySelectedTag = [self selectedTag];
	
	NSInteger index;
	
	for (index = kTrackingAreaNone; index <= kTrackingArea6; index++)
	{
		NSRect colorSquareRect = [self rectForColorViewAtIndex:index];
		
		//make sure the color at index is actually defined
		if(index >= 0 && [colorList objectAtIndex:index] == nil)
			continue;
		
		//do not draw a selection around the X item
		if (index > kTrackingAreaNone && index == currentlySelectedTag)
		{
			NSBezierPath *highlightPath = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(colorSquareRect, -1.5, -1.5)];
			[[NSColor colorWithCalibratedRed:0.76 green:0.78 blue:0.82 alpha:1.0] set];
			[highlightPath fill];
			
			[[NSColor colorWithCalibratedWhite:0.6 alpha:1.0] set];
			[highlightPath setLineWidth:1.0];
			[highlightPath stroke];
			
		}
		else if (index == hoverTag && trackEntered)
		{
			// if we are tracking inside any tag, we want outline the color choice
			NSBezierPath *highlightPath = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(colorSquareRect, -1.5, -1.5)];
			[[NSColor colorWithCalibratedWhite:0.94 alpha:1.0] set];
			[highlightPath fill];
			
			[[NSColor colorWithCalibratedWhite:0.6 alpha:1.0] set];
			[highlightPath setLineWidth:1.0];
			[highlightPath stroke];
		}
		
		if (index == kTrackingAreaNone) {
			
			[[NSColor disabledControlTextColor] set];
			
			// Draw an X
			NSBezierPath *left = [NSBezierPath bezierPath];
			
			[left setLineWidth:3.0];
			[left setLineCapStyle:NSButtLineCapStyle];
			[left moveToPoint:NSMakePoint(colorSquareRect.origin.x + 4.0, colorSquareRect.origin.y + 4.0)];
			[left lineToPoint:NSMakePoint(colorSquareRect.origin.x + 12.0, colorSquareRect.origin.y + 12.0)];
			[left moveToPoint:NSMakePoint(colorSquareRect.origin.x + 12.0, colorSquareRect.origin.y + 4.0)];
			[left lineToPoint:NSMakePoint(colorSquareRect.origin.x + 4.0, colorSquareRect.origin.y + 12.0)];
			[left stroke];
		}
		else {
			// draw the gradient dot
			NSGradient *gradient = [self gradientForTag:index];
			NSRect dotRect = NSInsetRect(colorSquareRect, 2.0, 2.0);
			NSBezierPath *circlePath = [NSBezierPath bezierPathWithOvalInRect:dotRect];
			[gradient drawInBezierPath:circlePath angle:-90.0];
			
			// draw a highlight
			
			// top edge outline
			gradient = [[NSGradient alloc] initWithColorsAndLocations:
						[NSColor colorWithCalibratedWhite:1.0 alpha:0.18], 0.0,
						[NSColor colorWithCalibratedWhite:1.0 alpha:0.0], 0.6, nil];
			circlePath = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(dotRect, 1.0, 1.0)];
			[circlePath appendBezierPath:[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(dotRect.origin.x+1.0, dotRect.origin.y-2.0, dotRect.size.width-2.0, dotRect.size.height)]];
			[circlePath setWindingRule:NSEvenOddWindingRule];
			[gradient drawInBezierPath:circlePath angle:-90.0];
			[gradient release];
			
			// top center gloss
			gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.18]
													 endingColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.0]];
			[gradient drawFromCenter:NSMakePoint(NSMidX(dotRect), NSMaxY(dotRect) - 2.0)
							  radius:0.0
							toCenter:NSMakePoint(NSMidX(dotRect), NSMaxY(dotRect) - 2.0)
							  radius:4.0
							 options:0];
			[gradient release];
			
			// draw a dark outline
			circlePath = [NSBezierPath bezierPathWithOvalInRect:dotRect];
			gradient = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.12]
													 endingColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.46]];
			[circlePath appendBezierPath:[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(dotRect, 1.0, 1.0)]];
			[circlePath setWindingRule:NSEvenOddWindingRule];
			[gradient drawInBezierPath:circlePath angle:-90.0];
			[gradient release];
		}
	}
}


#pragma mark -
#pragma mark Mouse Handling

// -------------------------------------------------------------------------------
//	getTrackerIDFromDict:dict
//
//	Used in obtaining dictionary entry info from the 'userData', used by each
//	mouse event method.  It helps determine which tracking area is being tracked.
// -------------------------------------------------------------------------------
- (int)getTrackerIDFromDict:(NSDictionary*)dict
{
	return [[dict objectForKey: kTrackerKey] intValue];
}

// -------------------------------------------------------------------------------
//	mouseEntered:event
//
//	Because we installed NSTrackingArea to our NSImageView, this method will be called.
// -------------------------------------------------------------------------------
- (void)mouseEntered:(NSEvent*)event
{
	// which tracking area is being tracked?
	hoverTag = [self getTrackerIDFromDict:[event userData]];
	trackEntered = YES;
	
	[self setNeedsDisplay:YES];	// force update the currently tracked tag back to its original color
}

// -------------------------------------------------------------------------------
//	mouseExited:event
//
//	Because we installed NSTrackingArea to our NSImageView, this method will be called.
// -------------------------------------------------------------------------------
- (void)mouseExited:(NSEvent*)event
{
	// which tracking area is being tracked?
	hoverTag = NSNotFound;
	trackEntered = NO;
	
	[self setNeedsDisplay:YES];	// force update the currently tracked tag to a lighter color
}

- (void)rightMouseUp:(NSEvent *)theEvent
{
	[self mouseUp:theEvent];
}

// -------------------------------------------------------------------------------
//	mouseDown:event
// -------------------------------------------------------------------------------
- (void)mouseUp:(NSEvent*)event
{
	NSPoint mousePoint = [self convertPoint:[[self window] mouseLocationOutsideOfEventStream] fromView:nil];
	
	// figure out which tag color was clicked on at mouseUp time
	NSInteger index;
	
	for (index = kTrackingAreaNone; index <= kTrackingArea6; index++)
	{
		NSRect tagRect = [self rectForColorViewAtIndex:index];
		if (NSPointInRect(mousePoint, tagRect))
		{
			// Ignore non-changes
			if (index == selectedTag) return;
			
			[self setSelectedTag:index];
			
			if (observer != nil) {
				[observer setValue:[NSNumber numberWithInteger:index] forKeyPath:observerKeyPath];
			}
			
			if (delegate != nil && [delegate respondsToSelector:@selector(colorSelectorDidChange:)]) {
				[delegate colorSelectorDidChange:self];
			}
			
			[self setNeedsDisplay:YES];
			
			return;
		}
	}
}

// -------------------------------------------------------------------------------
//	dealloc:
// -------------------------------------------------------------------------------
- (void)dealloc
{
	[trackingAreas release];
	
	[super dealloc];
}

@end
