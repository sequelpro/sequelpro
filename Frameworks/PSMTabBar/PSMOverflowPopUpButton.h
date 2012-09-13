//
//  PSMOverflowPopUpButton.h
//  PSMTabBarControl
//
//  Created by John Pannell on 11/4/05.
//  Copyright 2005 Positive Spin Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PSMOverflowPopUpButton : NSPopUpButton {
    NSImage         *_PSMTabBarOverflowPopUpImage;
    NSImage         *_PSMTabBarOverflowDownPopUpImage;
    BOOL            _down;
	BOOL			_animatingAlternateImage;
	NSTimer			*_animationTimer;
	CGFloat			_animationValue;
}

//alternate image display
- (BOOL)animatingAlternateImage;
- (void)setAnimatingAlternateImage:(BOOL)flag;

// Notifications
- (void)notificationReceived:(NSNotification *)notification;

// Animations
- (void)setAnimatingAlternateImage:(BOOL)flag;
- (BOOL)animatingAlternateImage;
- (void)animateStep:(NSTimer *)timer;

// archiving
- (void)encodeWithCoder:(NSCoder *)aCoder;
- (id)initWithCoder:(NSCoder *)aDecoder;
@end
