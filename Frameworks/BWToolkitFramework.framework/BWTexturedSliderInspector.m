//
//  BWControlsInspector.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWTexturedSliderInspector.h"

@implementation BWTexturedSliderInspector

- (NSString *)viewNibName {
	return @"BWTexturedSliderInspector";
}

- (void)refresh {
	// Synchronize your inspector's content view with the currently selected objects.
	[super refresh];
}

@end
