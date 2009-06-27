//
//  BWAnchoredButtonBar.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <Cocoa/Cocoa.h>

@interface BWAnchoredButtonBar : NSView 
{
	BOOL isResizable, isAtBottom, handleIsRightAligned;
	int selectedIndex;
	id splitViewDelegate;
}

@property BOOL isResizable, isAtBottom, handleIsRightAligned;
@property int selectedIndex;

// The mode of this bar with a resize handle makes use of some NSSplitView delegate methods. Use the splitViewDelegate for any custom delegate implementations
// you'd like to provide.
@property (assign) id splitViewDelegate;

+ (BOOL)wasBorderedBar;

@end
