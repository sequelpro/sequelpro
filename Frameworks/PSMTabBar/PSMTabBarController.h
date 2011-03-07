//
//  PSMTabBarController.h
//  PSMTabBarControl
//
//  Created by Kent Sutherland on 11/24/06.
//  Copyright 2006 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PSMTabBarControl, PSMTabBarCell;

@interface PSMTabBarController : NSObject {
    PSMTabBarControl *_control;
    NSMutableArray *_cellTrackingRects, *_closeButtonTrackingRects;
    NSMutableArray *_cellFrames;
    NSRect _addButtonRect;
    NSMenu *_overflowMenu;
}

- (id)initWithTabBarControl:(PSMTabBarControl *)control;

- (NSRect)addButtonRect;
- (NSMenu *)overflowMenu;
- (NSRect)cellTrackingRectAtIndex:(NSUInteger)anIndex;
- (NSRect)closeButtonTrackingRectAtIndex:(NSUInteger)anIndex;
- (NSRect)cellFrameAtIndex:(NSUInteger)anIndex;

- (void)setSelectedCell:(PSMTabBarCell *)cell;

- (void)layoutCells;

@end

@interface NSObject (TabRepresentedObjectIdentifierMethods)

// Method for generating a tooltip for a tab
- (NSString *)tabTitleForTooltip;

// Retrieving whether a tab is working
- (BOOL)isProcessing;

@end
