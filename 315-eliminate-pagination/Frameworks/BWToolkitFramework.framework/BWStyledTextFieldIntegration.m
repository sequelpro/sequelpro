//
//  BWStyledTextFieldIntegration.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "BWStyledTextField.h"
#import "BWStyledTextFieldInspector.h"

@implementation BWStyledTextField (BWStyledTextFieldIntegration)

- (void)ibPopulateKeyPaths:(NSMutableDictionary *)keyPaths 
{
    [super ibPopulateKeyPaths:keyPaths];

    [[keyPaths objectForKey:IBAttributeKeyPaths] addObjectsFromArray:[NSArray arrayWithObjects:@"shadowIsBelow", @"hasShadow", @"shadowColor", @"startingColor", @"endingColor", @"hasGradient", @"solidColor", nil]];
}

- (void)ibPopulateAttributeInspectorClasses:(NSMutableArray *)classes 
{
    [super ibPopulateAttributeInspectorClasses:classes];

    [classes addObject:[BWStyledTextFieldInspector class]];
}

@end
