//
//  BWStyledTextField.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWStyledTextField.h"

@implementation BWStyledTextField

#pragma mark Shadow

- (BOOL)hasShadow
{
	return [[self cell] hasShadow];
}

- (void)setHasShadow:(BOOL)flag
{
	[[self cell] setHasShadow:flag];
	
	[self setNeedsDisplay:YES];
}

- (BOOL)shadowIsBelow
{
	return [[self cell] shadowIsBelow];
}

- (void)setShadowIsBelow:(BOOL)flag
{
	[[self cell] setShadowIsBelow:flag];
	
	[self setNeedsDisplay:YES];
}

- (NSColor *)shadowColor
{
	return [[self cell] shadowColor];
}

- (void)setShadowColor:(NSColor *)color
{
	[[self cell] setShadowColor:color];
	
	[self setNeedsDisplay:YES];
}

#pragma mark Fill

- (BOOL)hasGradient
{
	return [[self cell] hasGradient];
}

- (void)setHasGradient:(BOOL)flag
{
	[[self cell] setHasGradient:flag];

	[self setNeedsDisplay:YES];
}

- (NSColor *)startingColor
{
	return [[self cell] startingColor];
}

- (void)setStartingColor:(NSColor *)color
{
	[[self cell] setStartingColor:color];
	
	[self setNeedsDisplay:YES];
}

- (NSColor *)endingColor
{
	return [[self cell] endingColor];
}

- (void)setEndingColor:(NSColor *)color
{
	[[self cell] setEndingColor:color];
	
	[self setNeedsDisplay:YES];
}

- (NSColor *)solidColor
{
	return [[self cell] solidColor];
}

- (void)setSolidColor:(NSColor *)color
{
	[[self cell] setSolidColor:color];
	
	[self setNeedsDisplay:YES];
}

@end
