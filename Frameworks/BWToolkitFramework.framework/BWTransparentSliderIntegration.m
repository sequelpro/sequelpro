//
//  BWTransparentSliderIntegration.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "BWTransparentSlider.h"


@implementation BWTransparentSlider ( BWTransparentSliderIntegration )

- (IBInset)ibLayoutInset
{
	IBInset inset;

	inset.left = 2;
	inset.top = 2;
	inset.bottom = 3;
	
	if ([self numberOfTickMarks] == 0)
	{
		inset.right = 3;
	}		
	else
	{
		inset.right = 2;
	}
		
	return inset;
}

@end
