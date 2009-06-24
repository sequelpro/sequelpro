//
//  BWAnchoredButtonIntegration.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "BWAnchoredButton.h"

@implementation BWAnchoredButton ( BWAnchoredButtonIntegration )

- (NSSize)ibMinimumSize
{
	return NSMakeSize(0,24);
}

- (NSSize)ibMaximumSize
{
	return NSMakeSize(100000,24);
}

- (IBInset)ibLayoutInset
{
	IBInset inset;
	inset.bottom = 0;
	inset.right = 0;
	inset.top = topAndLeftInset.x;
	inset.left = topAndLeftInset.y;
	
	return inset;
}

- (NSInteger)ibBaselineCount
{
	return 1;
}

- (CGFloat)ibBaselineAtIndex:(NSInteger)index
{
	return 16;
}

@end
