//
//  BWSplitViewInspectorAutosizingView.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <Cocoa/Cocoa.h>
#import "BWSplitView.h"

@interface BWSplitViewInspectorAutosizingView : NSView
{
	NSMutableArray *buttons;
	BWSplitView *splitView;
}

@property (retain) BWSplitView *splitView;

- (void)layoutButtons;
- (BOOL)isVertical;

@end
