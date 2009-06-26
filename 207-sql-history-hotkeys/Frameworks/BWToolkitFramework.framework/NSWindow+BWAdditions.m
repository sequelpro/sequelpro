//
//  NSWindow+BWAdditions.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "NSWindow+BWAdditions.h"

@implementation NSWindow (BWAdditions)

- (void)resizeToSize:(NSSize)newSize animate:(BOOL)animateFlag
{
	NSRect windowFrame;
	windowFrame.origin.x = [self frame].origin.x;

	if ([self isSheet])
	{
		float oldWidth = [self frame].size.width;
		float newWidth = newSize.width;
		
		float difference = oldWidth - newWidth;
		
		windowFrame.origin.x += difference / 2;
	}

	windowFrame.origin.y = [self frame].origin.y + [self frame].size.height - newSize.height;
	windowFrame.size.width = newSize.width;
	windowFrame.size.height = newSize.height;
	
	if (!NSIsEmptyRect(windowFrame))
		[self setFrame:windowFrame display:YES animate:animateFlag];
}

- (BOOL)isTextured
{
	return (([self styleMask] & NSTexturedBackgroundWindowMask) != 0);
}

@end
