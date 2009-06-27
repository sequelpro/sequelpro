//
//  BWStyledTextFieldCell.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWStyledTextFieldCell.h"

@interface NSCell (BWPrivate)
- (NSDictionary *)_textAttributes;
@end

@interface BWStyledTextFieldCell (BWPrivate)
- (void)applyGradient;
@end

@interface BWStyledTextFieldCell ()
@property (retain) NSMutableDictionary *previousAttributes;
@end

@implementation BWStyledTextFieldCell

@synthesize shadowIsBelow, shadowColor, hasShadow, previousAttributes, startingColor, endingColor, hasGradient, solidColor;

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder]) != nil)
	{
		[self setShadowIsBelow:[decoder decodeBoolForKey:@"BWSTFCShadowIsBelow"]];
		[self setHasShadow:[decoder decodeBoolForKey:@"BWSTFCHasShadow"]];
		[self setHasGradient:[decoder decodeBoolForKey:@"BWSTFCHasGradient"]];
		[self setShadowColor:[decoder decodeObjectForKey:@"BWSTFCShadowColor"]];
		[self setPreviousAttributes:[decoder decodeObjectForKey:@"BWSTFCPreviousAttributes"]];
		[self setStartingColor:[decoder decodeObjectForKey:@"BWSTFCStartingColor"]];
		[self setEndingColor:[decoder decodeObjectForKey:@"BWSTFCEndingColor"]];
		[self setSolidColor:[decoder decodeObjectForKey:@"BWSTFCSolidColor"]];
		
		if (self.shadowColor == nil)
			self.shadowColor = [NSColor blackColor];
		
		if (self.startingColor == nil)
			self.startingColor = [NSColor whiteColor];
		
		if (self.endingColor == nil)
			self.endingColor = [NSColor blackColor];
		
		if (self.solidColor == nil)
			self.solidColor = [NSColor greenColor];
		
		if (self.hasGradient)
			[self performSelector:@selector(applyGradient) withObject:nil afterDelay:0];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
	
	[coder encodeBool:[self shadowIsBelow] forKey:@"BWSTFCShadowIsBelow"];
	[coder encodeBool:[self hasShadow] forKey:@"BWSTFCHasShadow"];
	[coder encodeBool:[self hasGradient] forKey:@"BWSTFCHasGradient"];
	[coder encodeObject:[self shadowColor] forKey:@"BWSTFCShadowColor"];
	[coder encodeObject:[self previousAttributes] forKey:@"BWSTFCPreviousAttributes"];
	[coder encodeObject:[self startingColor] forKey:@"BWSTFCStartingColor"];
	[coder encodeObject:[self endingColor] forKey:@"BWSTFCEndingColor"];
	[coder encodeObject:[self solidColor] forKey:@"BWSTFCSolidColor"];
} 

- (NSDictionary *)_textAttributes
{
	NSMutableDictionary *attributes = [[[NSMutableDictionary alloc] init] autorelease];
	[attributes addEntriesFromDictionary:[super _textAttributes]];
	
	// Shadow code
	if (hasShadow)
	{
		NSShadow *shadow = [[NSShadow alloc] init];
		[shadow setShadowColor:shadowColor];
		
		if (shadowIsBelow)
			[shadow setShadowOffset:NSMakeSize(0,-1)];
		else
			[shadow setShadowOffset:NSMakeSize(0,1)];
		
		[attributes setObject:shadow forKey:NSShadowAttributeName];
		
		//[shadow release]; //This causes a sometimes reproducible crash at design-time. Patches welcome.
	}
	
	// Gradient code
	if ([previousAttributes objectForKey:@"NSFont"] != nil && [[previousAttributes objectForKey:@"NSFont"] isEqualTo:[attributes objectForKey:@"NSFont"]] == NO)
	{
		[self performSelector:@selector(applyGradient) withObject:nil afterDelay:0];
		[self setPreviousAttributes:attributes];
	}
	
	return attributes;
}

- (void)dealloc
{
	[shadowColor release];
	[super dealloc];
}

#pragma mark Gradient-specific Code

- (void)awakeFromNib
{
	NSMutableDictionary *attributes = [[[NSMutableDictionary alloc] init] autorelease];
	[attributes addEntriesFromDictionary:[super _textAttributes]];
	self.previousAttributes = attributes;
	
	[self applyGradient];
}

- (void)applyGradient
{	
	if ([[self controlView] window] == nil)
		return;
	
	if (self.hasGradient)
	{	
		float textHeight = [[self font] ascender] - [[self font] descender];
		
		NSSize boundSizeWithFullWidth = NSMakeSize([self controlView].frame.size.width,ceilf(textHeight));
		
		NSImage *image = [[[NSImage alloc] initWithSize:boundSizeWithFullWidth] autorelease];
		
		NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor:self.startingColor endingColor:self.endingColor] autorelease];
		
		[image lockFocus];
		[gradient drawInRect:NSMakeRect(0,0,boundSizeWithFullWidth.width,boundSizeWithFullWidth.height) angle:270];
		[image unlockFocus];
		
		NSColor *color = [NSColor colorWithPatternImage:image];
		
		[self setTextColor:color];
	}
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
	float textHeight = [[self font] ascender] - [[self font] descender];
	
	float deltaHeight = cellFrame.size.height - textHeight;
	float halfDeltaHeight = deltaHeight / 2;
	
	float yOrigin = [[controlView superview] convertRect:[controlView frame] toView:nil].origin.y;
	[[NSGraphicsContext currentContext] setPatternPhase:NSMakePoint(0, yOrigin + halfDeltaHeight)];
	
	[super drawInteriorWithFrame:cellFrame inView:controlView];
	
	[[NSGraphicsContext currentContext] restoreGraphicsState];
}

- (void)setStartingColor:(NSColor *)color
{
	if (startingColor != color) 
	{
        [startingColor release];
        startingColor = [color retain];
		
		[self applyGradient];
    }
}

- (void)setEndingColor:(NSColor *)color
{	
	if (endingColor != color) 
	{
        [endingColor release];
        endingColor = [color retain];
		
		[self applyGradient];
    }
}

- (void)setSolidColor:(NSColor *)color
{
	if (solidColor != color) 
	{
        [solidColor release];
        solidColor = [color retain];
		
		[self setTextColor:solidColor];
    }
}

- (void)setHasGradient:(BOOL)flag
{
	hasGradient = flag;
	
	if (flag)
		[self applyGradient];
	else
		[self setTextColor:self.solidColor];
}

@end
