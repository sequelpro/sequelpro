//
//  BWUnanchoredButton.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWUnanchoredButton.h"
#import "BWAnchoredButtonBar.h"
#import "NSView+BWAdditions.h"

@implementation BWUnanchoredButton

- (id)initWithCoder:(NSCoder *)decoder;
{
    if ((self = [super initWithCoder:decoder]) != nil)
	{
		if ([BWAnchoredButtonBar wasBorderedBar])
			topAndLeftInset = NSMakePoint(0, 0);
		else
			topAndLeftInset = NSMakePoint(1, 1);
	}
	return self;
}

- (void)mouseDown:(NSEvent *)theEvent
{
	[self bringToFront];
	[super mouseDown:theEvent];
}

- (NSRect)frame
{
	NSRect frame = [super frame];
	frame.size.height = 22;
	return frame;
}

@end
