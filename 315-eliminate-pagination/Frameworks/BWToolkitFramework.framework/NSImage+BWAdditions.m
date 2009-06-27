//
//  NSImage+BWAdditions.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "NSImage+BWAdditions.h"

@implementation NSImage (BWAdditions)

// Draw a solid color over an image - taking into account alpha. Useful for coloring template images.

- (NSImage *)tintedImageWithColor:(NSColor *)tint 
{
	NSSize size = [self size];
	NSRect imageBounds = NSMakeRect(0, 0, size.width, size.height);    
	
	NSImage *copiedImage = [self copy];
	
	[copiedImage lockFocus];
	
	[tint set];
	NSRectFillUsingOperation(imageBounds, NSCompositeSourceAtop);
	
	[copiedImage unlockFocus];  
	
	return [copiedImage autorelease];
}

// Rotate an image 90 degrees clockwise or counterclockwise
// Code from http://swik.net/User:marc/Chipmunk+Ninja+Technical+Articles/Rotating+an+NSImage+object+in+Cocoa/zgha

- (NSImage *)rotateImage90DegreesClockwise:(BOOL)clockwise
{
    NSImage *existingImage = self;
    NSSize existingSize;
	
    /**
     * Get the size of the original image in its raw bitmap format.
     * The bestRepresentationForDevice: nil tells the NSImage to just
     * give us the raw image instead of it's wacky DPI-translated version.
     */
    existingSize.width = [[existingImage bestRepresentationForDevice:nil] pixelsWide];
    existingSize.height = [[existingImage bestRepresentationForDevice:nil] pixelsHigh];
	
    NSSize newSize = NSMakeSize(existingSize.height, existingSize.width);
    NSImage *rotatedImage = [[[NSImage alloc] initWithSize:newSize] autorelease];
	
    [rotatedImage lockFocus];
	
    /**
     * Apply the following transformations:
     *
     * - bring the rotation point to the centre of the image instead of
     *   the default lower, left corner (0,0).
     * - rotate it by 90 degrees, either clock or counter clockwise.
     * - re-translate the rotated image back down to the lower left corner
     *   so that it appears in the right place.
     */
    NSAffineTransform *rotateTF = [NSAffineTransform transform];
    NSPoint centerPoint = NSMakePoint(newSize.width / 2, newSize.height / 2);
	
    [rotateTF translateXBy: centerPoint.x yBy: centerPoint.y];
    [rotateTF rotateByDegrees: (clockwise) ? - 90 : 90];
    [rotateTF translateXBy: -centerPoint.y yBy: -centerPoint.x];
    [rotateTF concat];
	
    /**
     * We have to get the image representation to do its drawing directly,
     * because otherwise the stupid NSImage DPI thingie bites us in the butt
     * again.
     */
    NSRect r1 = NSMakeRect(0, 0, newSize.height, newSize.width);
    [[existingImage bestRepresentationForDevice:nil] drawInRect:r1];
	
    [rotatedImage unlockFocus];
	
    return rotatedImage;
}

@end
