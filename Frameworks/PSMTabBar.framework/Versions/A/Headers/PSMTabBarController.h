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
- (NSRect)cellTrackingRectAtIndex:(NSInteger)index;
- (NSRect)closeButtonTrackingRectAtIndex:(NSInteger)index;
- (NSRect)cellFrameAtIndex:(NSInteger)index;

- (void)setSelectedCell:(PSMTabBarCell *)cell;

- (void)layoutCells;

@end
