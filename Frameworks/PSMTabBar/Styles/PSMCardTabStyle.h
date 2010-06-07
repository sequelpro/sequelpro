//
//  PSMCardTabStyle.h
//  Fichiers
//
//  Created by Michael Monscheuer on 05.11.09.
//  Copyright 2009 WriteFlow KG, Wien. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PSMTabStyle.h"

@interface PSMCardTabStyle : NSObject <PSMTabStyle>
{
    NSImage *unifiedCloseButton;
    NSImage *unifiedCloseButtonDown;
    NSImage *unifiedCloseButtonOver;
    NSImage *unifiedCloseDirtyButton;
    NSImage *unifiedCloseDirtyButtonDown;
    NSImage *unifiedCloseDirtyButtonOver;
    NSImage *_addTabButtonImage;
    NSImage *_addTabButtonPressedImage;
    NSImage *_addTabButtonRolloverImage;
	
    NSDictionary *_objectCountStringAttributes;
    
    CGFloat leftMargin;
	PSMTabBarControl *tabBar;
}

- (void)setLeftMarginForTabBarControl:(CGFloat)margin;

@end
