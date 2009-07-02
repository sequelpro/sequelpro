//
//  NSWindow+BWAdditions.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <Cocoa/Cocoa.h>

@interface NSWindow (BWAdditions)

- (void)resizeToSize:(NSSize)newSize animate:(BOOL)animateFlag;
- (BOOL)isTextured;

@end
