//
//  BWTransparentScrollView.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWTransparentScrollView.h"
#import "BWTransparentScroller.h"

@implementation BWTransparentScrollView

- (id)initWithCoder:(NSCoder *)decoder;
{
    if ((self = [super initWithCoder:decoder]) != nil)
	{
		if ([self respondsToSelector:@selector(ibTester)] == NO)
			[self setDrawsBackground:NO];
	}
	return self;
}

+ (Class)_verticalScrollerClass 
{
	return [BWTransparentScroller class];
}

@end
