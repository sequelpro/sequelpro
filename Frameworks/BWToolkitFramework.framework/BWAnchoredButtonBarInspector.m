//
//  BWAnchoredButtonBarViewInspector.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWAnchoredButtonBarInspector.h"

@implementation BWAnchoredButtonBarInspector

- (NSString *)viewNibName 
{
    return @"BWAnchoredButtonBarInspector";
}

- (void)refresh 
{
	[super refresh];
}

- (IBAction)selectMode1:(id)sender
{
	float xOrigin = matrix.frame.origin.x-1;
	float deltaX = fabsf(xOrigin - selectionView.frame.origin.x);
	float doubleSpaceMultiplier = 1;
	
	if (deltaX > 65)
		doubleSpaceMultiplier = 1.5;
	
	float duration = 0.1*doubleSpaceMultiplier;
	
	[NSAnimationContext beginGrouping];
	[[NSAnimationContext currentContext] setDuration:(duration)];
	[[selectionView animator] setFrameOrigin:NSMakePoint(xOrigin,selectionView.frame.origin.y)];
	[NSAnimationContext endGrouping];
}

- (IBAction)selectMode2:(id)sender
{
	float xOrigin = matrix.frame.origin.x + NSWidth(matrix.frame) / matrix.numberOfColumns;
	float deltaX = fabsf(xOrigin - selectionView.frame.origin.x);
	float doubleSpaceMultiplier = 1;
	
	if (deltaX > 65)
		doubleSpaceMultiplier = 1.5;
	
	float duration = 0.1*doubleSpaceMultiplier;
	
	[NSAnimationContext beginGrouping];
	[[NSAnimationContext currentContext] setDuration:(duration)];
	[[selectionView animator] setFrameOrigin:NSMakePoint(xOrigin,selectionView.frame.origin.y)];
	[NSAnimationContext endGrouping];
}

- (IBAction)selectMode3:(id)sender
{
	float xOrigin = NSMaxX(matrix.frame) - NSWidth(matrix.frame) / matrix.numberOfColumns + matrix.numberOfColumns - 1;
	float deltaX = fabsf(xOrigin - selectionView.frame.origin.x);
	float doubleSpaceMultiplier = 1;
	
	if (deltaX > 65)
		doubleSpaceMultiplier = 1.5;
	
	float duration = 0.1*doubleSpaceMultiplier;
	
	[NSAnimationContext beginGrouping];
	[[NSAnimationContext currentContext] setDuration:(duration)];
	[[selectionView animator] setFrameOrigin:NSMakePoint(xOrigin,selectionView.frame.origin.y)];
	[NSAnimationContext endGrouping];
}

@end
