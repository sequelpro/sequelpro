//
//  BWUnanchoredButtonIntegration.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "BWUnanchoredButton.h"

@implementation BWUnanchoredButton ( BWUnanchoredButtonIntegration )

- (NSSize)ibMinimumSize
{
	return NSMakeSize(0,22);
}

- (NSSize)ibMaximumSize
{
	return NSMakeSize(100000,22);
}

- (IBInset)ibLayoutInset
{
	IBInset inset;
	inset.bottom = 1;
	inset.right = 0;
	inset.top = 1;
	inset.left = 0;
	
	return inset;
}

- (NSInteger)ibBaselineCount
{
	return 1;
}

- (CGFloat)ibBaselineAtIndex:(NSInteger)index
{
	return 15;
}

@end
