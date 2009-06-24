//
//  BWUnanchoredButtonContainerIntegration.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "BWUnanchoredButtonContainer.h"
#import "BWUnanchoredButton.h"

@implementation BWUnanchoredButtonContainer ( BWUnanchoredButtonContainerIntegration )

- (NSSize)ibMinimumSize
{
	return NSMakeSize(45,22);
}

- (NSSize)ibMaximumSize
{
	return NSMakeSize(45,22);
}

- (BOOL)ibIsChildInitiallySelectable:(id)child
{
	return NO;
}

- (NSArray *)ibDefaultChildren
{
	return [self subviews];
}

- (NSView *)ibDesignableContentView
{
	return self;
}

- (IBInset)ibLayoutInset
{
	IBInset inset;
	
	inset.left = 0;
	inset.top = 1;
	inset.bottom = 1;
	inset.right = 0;
	
	return inset;
}

@end
