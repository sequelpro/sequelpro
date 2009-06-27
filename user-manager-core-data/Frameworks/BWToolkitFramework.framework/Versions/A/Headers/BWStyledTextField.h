//
//  BWStyledTextField.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <Cocoa/Cocoa.h>

@interface BWStyledTextField : NSTextField
{
	
}

- (BOOL)hasGradient;
- (void)setHasGradient:(BOOL)flag;
- (NSColor *)startingColor;
- (void)setStartingColor:(NSColor *)color;
- (NSColor *)endingColor;
- (void)setEndingColor:(NSColor *)color;

- (NSColor *)solidColor;
- (void)setSolidColor:(NSColor *)color;

- (BOOL)hasShadow;
- (void)setHasShadow:(BOOL)flag;
- (BOOL)shadowIsBelow;
- (void)setShadowIsBelow:(BOOL)flag;
- (NSColor *)shadowColor;
- (void)setShadowColor:(NSColor *)color;

@end
