//
//  $Id$
//
//  SPGrowlController.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Nov 28, 2008
//  Copyright (c) 2008 Stuart Connolly. All rights reserved.
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
#import <Growl/Growl.h>

#define SP_LONGRUNNING_NOTIFICATION_TIME 3.0

@interface SPGrowlController : NSObject <GrowlApplicationBridgeDelegate>
{
	NSString *timingNotificationName;
	double timingNotificationStart;
}

// Singleton controller
+ (SPGrowlController *)sharedGrowlController;

// Post notification
- (void)notifyWithTitle:(NSString *)title 
			description:(NSString *)description
				 window:(NSWindow *)window
	   notificationName:(NSString *)name;

- (void)notifyWithObject:(NSDictionary *)notificationDictionary;

- (void)notifyWithTitle:(NSString *)title 
			description:(NSString *)description 
				 window:(NSWindow *)window
	   notificationName:(NSString *)name 
			   iconData:(NSData *)data 
			   priority:(int)priority 
			   isSticky:(BOOL)sticky 
		   clickContext:(id)clickContext;

// Receive notification click
- (void) growlNotificationWasClicked:(NSDictionary *)clickContext;

// Timing functions
- (void) setVisibilityForNotificationName:(NSString *)name;
- (double) milliTime;

@end
