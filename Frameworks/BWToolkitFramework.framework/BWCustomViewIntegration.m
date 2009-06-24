//
//  BWGradientSplitViewSubviewIntegration.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "BWCustomView.h"
#import "IBColor.h"

@implementation BWCustomView ( BWCustomViewIntegration )

- (NSView *)ibDesignableContentView
{
	return self;
}

- (NSColor *)containerCustomViewBackgroundColor
{
	return [IBColor containerCustomViewBackgroundColor];
}

- (NSColor *)childlessCustomViewBackgroundColor
{
	return [IBColor childlessCustomViewBackgroundColor];
}

- (NSColor *)customViewDarkTexturedBorderColor
{
	return [IBColor customViewDarkTexturedBorderColor];
}

- (NSColor *)customViewDarkBorderColor
{
	return [IBColor customViewDarkBorderColor];
}

- (NSColor *)customViewLightBorderColor
{
	return [IBColor customViewLightBorderColor];
}

@end
