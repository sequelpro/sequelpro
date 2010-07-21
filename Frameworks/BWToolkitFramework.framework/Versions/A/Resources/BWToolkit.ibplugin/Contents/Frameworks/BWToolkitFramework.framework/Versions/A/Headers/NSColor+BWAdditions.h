//
//  NSColor+BWAdditions.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <Cocoa/Cocoa.h>

@interface NSColor (BWAdditions)

//  Use this method to draw 1 px wide lines independent of scale factor. Handy for resolution independent drawing. Still needs some work - there are issues with drawing at the edges of views.
- (void)bwDrawPixelThickLineAtPosition:(int)posInPixels withInset:(int)insetInPixels inRect:(NSRect)aRect inView:(NSView *)view horizontal:(BOOL)isHorizontal flip:(BOOL)shouldFlip;

@end
