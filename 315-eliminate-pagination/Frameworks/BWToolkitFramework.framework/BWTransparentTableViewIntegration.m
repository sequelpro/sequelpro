//
//  BWTransparentTableViewIntegration.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "BWTransparentTableView.h"

@implementation BWTransparentTableView ( BWTransparentTableViewIntegration )

- (void)addObject:(id)object toParent:(id)parent
{
	IBDocument *document = [IBDocument documentForObject:parent];
	
	[document addObject:object toParent:parent];
}

- (void)removeObject:(id)object
{
	IBDocument *document = [IBDocument documentForObject:object];
	
	[document removeObject:object];
}

- (void)ibTester
{
}

@end
