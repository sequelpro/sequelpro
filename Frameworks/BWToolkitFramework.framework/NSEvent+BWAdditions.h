//
//  NSEvent+BWAdditions.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <Cocoa/Cocoa.h>

@interface NSEvent (BWAdditions)

+ (BOOL)shiftKeyIsDown;
+ (BOOL)commandKeyIsDown;
+ (BOOL)optionKeyIsDown;
+ (BOOL)controlKeyIsDown;
+ (BOOL)capsLockKeyIsDown;

@end
