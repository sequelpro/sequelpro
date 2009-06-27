//
//  BWTransparentCheckBoxIntegration.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "BWTransparentCheckbox.h"

@implementation BWTransparentCheckbox ( BWTransparentCheckboxIntegration )

- (NSSize)ibMinimumSize
{
	return NSMakeSize(0,18);
}

- (NSSize)ibMaximumSize
{
	return NSMakeSize(100000,18);
}

- (IBInset)ibLayoutInset
{
	IBInset inset;
	inset.top = 3;
	inset.bottom = 3;
	inset.left = 2;
	inset.right = 0;
	
	return inset;
}

@end
