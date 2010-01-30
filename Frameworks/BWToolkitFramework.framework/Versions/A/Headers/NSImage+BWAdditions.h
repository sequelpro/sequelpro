//
//  NSImage+BWAdditions.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <Cocoa/Cocoa.h>

@interface NSImage (BWAdditions)

// Draw a solid color over an image - taking into account alpha. Useful for coloring template images.
- (NSImage *)bwTintedImageWithColor:(NSColor *)tint;

// Rotate an image 90 degrees clockwise or counterclockwise
- (NSImage *)bwRotateImage90DegreesClockwise:(BOOL)clockwise;

@end
