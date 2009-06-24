//
//  BWAnchoredPopUpButton.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <Cocoa/Cocoa.h>

@interface BWAnchoredPopUpButton : NSPopUpButton 
{
	BOOL isAtLeftEdgeOfBar;
	BOOL isAtRightEdgeOfBar;
	NSPoint topAndLeftInset;
}

@property BOOL isAtLeftEdgeOfBar;
@property BOOL isAtRightEdgeOfBar;

@end
