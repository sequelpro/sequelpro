//
//  $Id$
//
//  SPGrowlController.m
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

#import "SPGrowlController.h"

static SPGrowlController *sharedGrowlController = nil;

@implementation SPGrowlController

/*
 * Returns the shared Growl controller.
 */
+ (SPGrowlController *)sharedGrowlController
{
    @synchronized(self) {
        if (sharedGrowlController == nil) {
            [[self alloc] init];
        }
    }
    
    return sharedGrowlController;
}

+ (id)allocWithZone:(NSZone *)zone
{    
    @synchronized(self) {
        if (sharedGrowlController == nil) {
            sharedGrowlController = [super allocWithZone:zone];
            
            return sharedGrowlController;
        }
    }
    
    return nil; // On subsequent allocation attempts return nil
}

- (id)init
{
    if (self = [super init]) {
        [GrowlApplicationBridge setGrowlDelegate:self];
    }
    
    return self;
}

/*
 * The following base protocol methods are implemented to ensure the singleton status of this class.
 */

- (id)copyWithZone:(NSZone *)zone { return self; }

- (id)retain { return self; }

- (unsigned)retainCount { return UINT_MAX; }

- (id)autorelease { return self; }

- (void)release { }

/*
 * Posts a Growl notification using the supplied details and default values.
 */
- (void)notifyWithTitle:(NSString *)title description:(NSString *)description notificationName:(NSString *)name
{
	[self notifyWithTitle:title
			  description:description
		notificationName:name
				iconData:nil
				priority:0
				isSticky:NO
			clickContext:nil];
}
     
/*
 * Posts a Growl notification using the supplied details and effectively ignoring the default values.
 */
- (void)notifyWithTitle:(NSString *)title description:(NSString *)description notificationName:(NSString *)name iconData:(NSData *)data priority:(int)priority isSticky:(BOOL)sticky clickContext:(id)clickContext
{
    // Post notification only if preference is set
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"GrowlEnabled"]) {
		[GrowlApplicationBridge notifyWithTitle:title
									description:description
							   notificationName:name
									   iconData:data
									   priority:priority
									   isSticky:sticky
								   clickContext:clickContext];
	}
}

@end
