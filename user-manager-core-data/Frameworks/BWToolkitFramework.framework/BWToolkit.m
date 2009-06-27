//
//  BWToolkit.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWToolkit.h"

@implementation BWToolkit
- (NSArray *)libraryNibNames {
    return [NSArray arrayWithObjects:@"BWSplitViewLibrary",@"BWControllersLibrary",@"BWToolbarItemsLibrary",@"BWBottomBarLibrary",@"BWToolkitLibrary",@"BWTransparentControlsLibrary",@"BWButtonBarLibrary",nil];
}

- (NSArray *)requiredFrameworks {
    return [NSArray arrayWithObjects:[NSBundle bundleWithIdentifier:@"com.brandonwalkin.BWToolkitFramework"], nil];
}

- (NSString *)label
{
	return @"BWToolkit";
}

@end
