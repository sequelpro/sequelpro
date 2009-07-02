//
//  BWControlsView.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "BWTexturedSlider.h"
#import "BWTexturedSliderInspector.h"


@implementation BWTexturedSlider ( BWTexturedSliderIntegration )

- (void)ibPopulateKeyPaths:(NSMutableDictionary *)keyPaths {
    [super ibPopulateKeyPaths:keyPaths];
    [[keyPaths objectForKey:IBAttributeKeyPaths] addObjectsFromArray:[NSArray arrayWithObjects:@"trackHeight",@"indicatorIndex",nil]];
}

- (void)ibPopulateAttributeInspectorClasses:(NSMutableArray *)classes {
    [super ibPopulateAttributeInspectorClasses:classes];
    [classes addObject:[BWTexturedSliderInspector class]];
}

- (IBInset)ibLayoutInset
{
	IBInset inset;
	
	if ([self trackHeight] == 0)
	{
		inset.top = 4;
		inset.bottom = 5;
	}
	else
	{
		inset.top = 5;
		inset.bottom = 4;
	}
	
	if ([self indicatorIndex] == 0)
	{
		inset.right = 4;
		inset.left = 5;
	}
	else if ([self indicatorIndex] == 2)
	{
		inset.bottom = 3;
		inset.right = 5;
		inset.left = 13;
	}
	else if ([self indicatorIndex] == 3)
	{
		inset.right = 12;
		inset.left = 18;
	}
	else
	{
		inset.right = 0;
		inset.left = 0;
	}
	
	return inset;
}

@end
