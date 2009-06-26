//
//  BWStyledTextFieldInspector.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWStyledTextFieldInspector.h"

@implementation BWStyledTextFieldInspector

@synthesize shadowPositionPopupSelection, fillPopupSelection;

- (NSString *)viewNibName 
{
    return @"BWStyledTextFieldInspector";
}

- (void)refresh 
{
	[super refresh];
	
	textField = [[self inspectedObjects] objectAtIndex:0];
	
	// Update the popup selections in case of an undo operation
	if (![textField hasShadow])
	{
		[self setShadowPositionPopupSelection:0];
	}
	else
	{
		if ([textField shadowIsBelow])
			[self setShadowPositionPopupSelection:3];
		else
			[self setShadowPositionPopupSelection:2];
	}
	
	if ([textField hasGradient])
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
		[textField setHasGradient:NO];
	else
		[textField setHasGradient:YES];
}

- (void)setShadowPositionPopupSelection:(int)anInt
{	
	shadowPositionPopupSelection = anInt;
	
	if (shadowPositionPopupSelection == 2)
	{
		[textField setHasShadow:YES];
		[textField setShadowIsBelow:NO];
	}
	else if (shadowPositionPopupSelection == 3)
	{
		[textField setHasShadow:YES];
		[textField setShadowIsBelow:YES];
	}
	else
	{
		[textField setHasShadow:NO];
	}
}

@end
