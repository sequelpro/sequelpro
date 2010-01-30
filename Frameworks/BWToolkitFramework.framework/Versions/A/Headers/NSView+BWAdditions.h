//
//  NSView+BWAdditions.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <Cocoa/Cocoa.h>

@interface NSView (BWAdditions)

- (void)bwBringToFront;

// Returns animator proxy and calls setWantsLayer:NO on the view when the animation completes 
- (id)bwAnimator;

@end
