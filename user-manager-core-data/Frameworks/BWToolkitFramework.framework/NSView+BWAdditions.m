//
//  NSView+BWAdditions.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "NSView+BWAdditions.h"

NSComparisonResult compareViews(id firstView, id secondView, id context);
NSComparisonResult compareViews(id firstView, id secondView, id context)
{
	if (firstView != context && secondView != context) {return NSOrderedSame;}
	else
	{
		if (firstView == context) {return NSOrderedDescending;}
		else {return NSOrderedAscending;}
	}
}

@implementation NSView (BWAdditions)

- (void)bringToFront
{
	[[self superview] sortSubviewsUsingFunction:(NSComparisonResult (*)(id, id, void *))compareViews context:self];
}

@end


