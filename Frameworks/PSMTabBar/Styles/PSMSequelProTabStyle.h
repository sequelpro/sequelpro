//
//  $Id: PSMSequelProTabStyle.h 2317 2010-06-15 10:19:41Z avenjamin $
//
//  PSMSequelProTabStyle.h
//  sequel-pro
//
//  Created by Ben Perry on June 15, 2010
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import <Cocoa/Cocoa.h>
#import "PSMTabStyle.h"

@interface PSMSequelProTabStyle : NSObject <PSMTabStyle> {
    NSImage *metalCloseButton;
    NSImage *metalCloseButtonDown;
    NSImage *metalCloseButtonOver;
    NSImage *metalCloseDirtyButton;
    NSImage *metalCloseDirtyButtonDown;
    NSImage *metalCloseDirtyButtonOver;
    NSImage *_addTabButtonImage;
    NSImage *_addTabButtonPressedImage;
    NSImage *_addTabButtonRolloverImage;
	
	NSDictionary *_objectCountStringAttributes;
	
	PSMTabBarOrientation orientation;
	PSMTabBarControl *tabBar;
	
	BOOL _tabIsRightOfSelectedTab;
}

- (void)drawInteriorWithTabCell:(PSMTabBarCell *)cell inView:(NSView*)controlView;

- (void)encodeWithCoder:(NSCoder *)aCoder;
- (id)initWithCoder:(NSCoder *)aDecoder;

@end
