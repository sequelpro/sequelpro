//
//  BWTransparentButtonIntegration.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "BWTransparentButton.h"

@implementation BWTransparentButton ( BWTransparentButtonIntegration )

- (IBInset)ibLayoutInset
{
	IBInset inset;
	inset.top = 10;
	inset.bottom = 0;
	inset.left = 1;
	inset.right = 1;
	
	return inset;
}

- (NSInteger)ibBaselineCount
{
	return 1;
}

- (CGFloat)ibBaselineAtIndex:(NSInteger)index
{
	return 13;
}

@end
