//
//  BWTransparentScrollViewIntegration.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "BWTransparentScrollView.h"

@implementation BWTransparentScrollView ( BWTransparentScrollViewIntegration )

- (IBInset)ibLayoutInset
{
	IBInset inset;
	inset.top = 0;
	inset.bottom = 0;
	inset.left = -1;
	inset.right = -1;
	
	return inset;
}

- (void)ibTester
{
}

@end
