//
//  BWGradientBoxInspector.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWGradientBoxInspector.h"

@implementation BWGradientBoxInspector

@synthesize fillPopupSelection;

- (NSString *)viewNibName 
{
    return @"BWGradientBoxInspector";
}

- (void)refresh 
{
	[super refresh];
	
	box = [[self inspectedObjects] objectAtIndex:0];
	
	// Update the popup selections in case of an undo operation
	if ([box hasGradient])
		[self setFillPopupSelection:1];
	else
		[self setFillPopupSelection:0];
}

+ (BOOL)supportsMultipleObjectInspection
{
	return NO;
}

- (void)setFillPopupSelection:(int)anInt
{
	fillPopupSelection = anInt;
	
	if (fillPopupSelection == 0)
		[box setHasGradient:NO];
	else
		[box setHasGradient:YES];
}

@end
