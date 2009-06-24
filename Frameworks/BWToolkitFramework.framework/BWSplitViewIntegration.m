//
//  BWSplitViewIntegration.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "BWSplitView.h"
#import "BWSplitViewInspector.h"

@implementation BWSplitView ( BWSplitViewIntegration )

- (void)ibPopulateKeyPaths:(NSMutableDictionary *)keyPaths {
    [super ibPopulateKeyPaths:keyPaths];

    [[keyPaths objectForKey:IBAttributeKeyPaths] addObjectsFromArray:[NSArray arrayWithObjects:@"color",@"colorIsEnabled",@"dividerCanCollapse",nil]];
}

- (void)ibPopulateAttributeInspectorClasses:(NSMutableArray *)classes {
    [super ibPopulateAttributeInspectorClasses:classes];
	
    [classes addObject:[BWSplitViewInspector class]];
}

- (void)ibDidAddToDesignableDocument:(IBDocument *)document
{
	[super ibDidAddToDesignableDocument:document];
}

@end
