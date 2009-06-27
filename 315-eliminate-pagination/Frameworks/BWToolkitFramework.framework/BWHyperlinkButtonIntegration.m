//
//  BWHyperlinkButtonIntegration.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "BWHyperlinkButton.h"
#import "BWHyperlinkButtonInspector.h"

@implementation BWHyperlinkButton (BWHyperlinkButtonIntegration)

- (void)ibPopulateKeyPaths:(NSMutableDictionary *)keyPaths 
{
    [super ibPopulateKeyPaths:keyPaths];

    [[keyPaths objectForKey:IBAttributeKeyPaths] addObjectsFromArray:[NSArray arrayWithObjects:@"urlString", nil]];
}

- (void)ibPopulateAttributeInspectorClasses:(NSMutableArray *)classes 
{
    [super ibPopulateAttributeInspectorClasses:classes];

    [classes addObject:[BWHyperlinkButtonInspector class]];
}

@end