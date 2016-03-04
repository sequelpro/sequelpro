//
//  SPHoverButton.h
//  sequel-pro
//
//  Created by Rocco Galli
//  Copyright (c) 2016 Rocco Galli. All rights reserved.
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


#import "SPHoverButton.h"

@interface SPHoverButton ()
- (void) timerDidElapsed:(id)sender;
- (void) reset;
@property (strong, nonatomic) NSTimer *timer;
@end

@implementation SPHoverButton

- (void)awakeFromNib
{
	if (self.image != nil) {
		self.normaleStateImageName = self.image.name;
	}
	self.hover = NO;
	self.hoverInterval = 2;
	self.normaleStateToolTip = self.toolTip;
	[self removeAllToolTips];
	[self addToolTipRect:self.bounds owner:self userData:NULL];
}

- (void) timerDidElapsed:(id)sender
{
	if (!self.hover) {
		self.hover = YES;
		[self setImage:[NSImage imageNamed:self.hoverStateImageName]];
	}
	
	[self.timer invalidate];
	
	self.timer = [NSTimer scheduledTimerWithTimeInterval:self.hoverInterval
												  target:self
												selector:@selector(timerDidElapsed:)
												userInfo:nil
												 repeats:NO];
	
	[self listSubviewsOfView: [[[self superview] superview] superview]];
	
	

}

- (void)updateTrackingAreas
{
	[super updateTrackingAreas];
	
	if (trackingArea) {
		[self removeTrackingArea:trackingArea];
		[trackingArea release];
	}

	NSTrackingAreaOptions options = NSTrackingInVisibleRect | NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow;
	trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:options owner:self userInfo:nil];
	[self addTrackingArea:trackingArea];
}

- (void)mouseEntered:(NSEvent *)event
{
	if (!self.enabled) {
		return;
	}
	
	if (self.hover) {
		return;
	}
	
	if (self.hoverInterval > 0 && self.hoverStateImageName != nil && self.timer == nil) {
		self.timer = [NSTimer scheduledTimerWithTimeInterval:self.hoverInterval
													  target:self
						   							selector:@selector(timerDidElapsed:)
							 						userInfo:nil
													 repeats:NO];
	}
	
}

- (void)mouseDown:(NSEvent *)event
{
	[super mouseDown:event];
	[self reset];
	if (self.hoverInterval > 0 && self.hoverStateImageName != nil) {
		self.timer = [NSTimer scheduledTimerWithTimeInterval:self.hoverInterval
													  target:self
													selector:@selector(timerDidElapsed:)
													userInfo:nil
													 repeats:NO];
	}
}

- (void)mouseExited:(NSEvent *)event
{
	[self reset];
}

- (void) reset
{
	if (self.timer) {
		[self.timer invalidate];
		self.timer = nil;
	}
	[self setImage:[NSImage imageNamed:self.normaleStateImageName]];
	self.hover = NO;
	
}

- (NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)data
{
	if (self.hover) {
		return self.hoverStateToolTip;
	} else {
		return self.normaleStateToolTip;
	}
}



@end
