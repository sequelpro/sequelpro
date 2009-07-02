//
//  BWGradientBox.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWGradientBox.h"
#import "NSColor+BWAdditions.h"

@implementation BWGradientBox

@synthesize fillStartingColor, fillEndingColor, fillColor, topBorderColor, bottomBorderColor;
@synthesize topInsetAlpha, bottomInsetAlpha;
@synthesize hasTopBorder, hasBottomBorder, hasGradient;

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder]) != nil)
	{
		[self setFillStartingColor:[decoder decodeObjectForKey:@"BWGBFillStartingColor"]];
		[self setFillEndingColor:[decoder decodeObjectForKey:@"BWGBFillEndingColor"]];
		[self setFillColor:[decoder decodeObjectForKey:@"BWGBFillColor"]];
		[self setTopBorderColor:[decoder decodeObjectForKey:@"BWGBTopBorderColor"]];
		[self setBottomBorderColor:[decoder decodeObjectForKey:@"BWGBBottomBorderColor"]];
		
		[self setHasTopBorder:[decoder decodeBoolForKey:@"BWGBHasTopBorder"]];
		[self setHasBottomBorder:[decoder decodeBoolForKey:@"BWGBHasBottomBorder"]];
		[self setHasGradient:[decoder decodeBoolForKey:@"BWGBHasGradient"]];
		
		[self setTopInsetAlpha:[decoder decodeFloatForKey:@"BWGBTopInsetAlpha"]];
		[self setBottomInsetAlpha:[decoder decodeFloatForKey:@"BWGBBottomInsetAlpha"]];
		
		if (self.fillStartingColor == nil)
			self.fillStartingColor = [NSColor whiteColor];
		
		if (self.fillEndingColor == nil)
			self.fillEndingColor = [NSColor grayColor];
		
		if (self.fillColor == nil)
			self.fillColor = [NSColor grayColor];
		
		if (self.topBorderColor == nil)
			self.topBorderColor = [NSColor blackColor];
		
		if (self.bottomBorderColor == nil)
			self.bottomBorderColor = [NSColor blackColor];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
	
	[coder encodeObject:[self fillStartingColor] forKey:@"BWGBFillStartingColor"];
	[coder encodeObject:[self fillEndingColor] forKey:@"BWGBFillEndingColor"];
	[coder encodeObject:[self fillColor] forKey:@"BWGBFillColor"];
	[coder encodeObject:[self topBorderColor] forKey:@"BWGBTopBorderColor"];
	[coder encodeObject:[self bottomBorderColor] forKey:@"BWGBBottomBorderColor"];
	
	[coder encodeBool:[self hasTopBorder] forKey:@"BWGBHasTopBorder"];
	[coder encodeBool:[self hasBottomBorder] forKey:@"BWGBHasBottomBorder"];
	[coder encodeBool:[self hasGradient] forKey:@"BWGBHasGradient"];

	[coder encodeFloat:[self topInsetAlpha] forKey:@"BWGBTopInsetAlpha"];
	[coder encodeFloat:[self bottomInsetAlpha] forKey:@"BWGBBottomInsetAlpha"];
} 

- (void)drawRect:(NSRect)rect 
{
	if (hasGradient)
	{
		NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:fillStartingColor endingColor:fillEndingColor];
		[gradient drawInRect:self.bounds angle:90];
		[gradient release];
	}
	else
	{
		[fillColor set];
		NSRectFillUsingOperation(self.bounds, NSCompositeSourceOver);
	}
	
	if (hasTopBorder)
	{
		[topBorderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:self.bounds inView:self horizontal:YES flip:NO];
		[[[NSColor whiteColor] colorWithAlphaComponent:topInsetAlpha] drawPixelThickLineAtPosition:1 withInset:0 inRect:self.bounds inView:self horizontal:YES flip:NO];
	}
	else
	{
		[[[NSColor whiteColor] colorWithAlphaComponent:topInsetAlpha] drawPixelThickLineAtPosition:0 withInset:0 inRect:self.bounds inView:self horizontal:YES flip:NO];
	}
		
	
	if (hasBottomBorder)
	{
		[bottomBorderColor drawPixelThickLineAtPosition:0 withInset:0 inRect:self.bounds inView:self horizontal:YES flip:YES];
		[[[NSColor whiteColor] colorWithAlphaComponent:bottomInsetAlpha] drawPixelThickLineAtPosition:1 withInset:0 inRect:self.bounds inView:self horizontal:YES flip:YES];
	}
	else
	{
		[[[NSColor whiteColor] colorWithAlphaComponent:bottomInsetAlpha] drawPixelThickLineAtPosition:0 withInset:0 inRect:self.bounds inView:self horizontal:YES flip:YES];
	}
		
}

- (BOOL)isFlipped
{
	return YES;
}

- (void)setFillColor:(NSColor *)color
{
	if (fillColor != color) 
	{
        [fillColor release];
        fillColor = [color retain];
		
		[self setNeedsDisplay:YES];
    }
}

- (void)setFillStartingColor:(NSColor *)color
{
	if (fillStartingColor != color) 
	{
        [fillStartingColor release];
        fillStartingColor = [color retain];
		
		[self setNeedsDisplay:YES];
    }
}

- (void)setFillEndingColor:(NSColor *)color
{
	if (fillEndingColor != color) 
	{
        [fillEndingColor release];
        fillEndingColor = [color retain];
		
		[self setNeedsDisplay:YES];
    }
}

- (void)setTopBorderColor:(NSColor *)color
{
	if (topBorderColor != color) 
	{
        [topBorderColor release];
        topBorderColor = [color retain];
		
		[self setNeedsDisplay:YES];
    }
}

- (void)setBottomBorderColor:(NSColor *)color
{
	if (bottomBorderColor != color) 
	{
        [bottomBorderColor release];
        bottomBorderColor = [color retain];
		
		[self setNeedsDisplay:YES];
    }
}

- (void)dealloc
{
	[fillColor release];
	[fillStartingColor release];
	[fillEndingColor release];
	[topBorderColor release];
	[bottomBorderColor release];
	
	[super dealloc];
}

@end
