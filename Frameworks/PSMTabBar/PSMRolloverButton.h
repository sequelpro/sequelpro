//
//  PSMOverflowPopUpButton.h
//  NetScrape
//
//  Created by John Pannell on 8/4/04.
//  Copyright 2004 Positive Spin Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PSMRolloverButton : NSButton
{
    NSImage             *_rolloverImage;
    NSImage             *_usualImage;
    NSTrackingRectTag   _myTrackingRectTag;
}

// the regular image
- (void)setUsualImage:(nullable NSImage *)newImage;
- (nullable NSImage *)usualImage;

// the rollover image
- (void)setRolloverImage:(nullable NSImage *)newImage;
- (nullable NSImage *)rolloverImage;

// tracking rect for mouse events
- (void)rolloverFrameDidChange:(nonnull NSNotification *)inNotification;
- (void)addTrackingRect;
- (void)removeTrackingRect;

- (void)mouseEntered:(nullable NSEvent *)theEvent;
- (void)mouseExited:(nullable NSEvent *)theEvent;

@end
