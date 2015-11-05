//
//  SPGrowlController.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on Nov 28, 2008.
//  Copyright (c) 2008 Stuart Connolly. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <https://github.com/sequelpro/sequelpro>

#import "SPGrowlController.h"
#import "SPDatabaseDocument.h"
#import "SPWindowController.h"
#import "SPAppController.h"

#include <mach/mach_time.h>

static SPGrowlController *sharedGrowlController = nil;

@class SPWindowController;

@implementation SPGrowlController

/**
 * Returns the shared Growl controller.
 */
+ (SPGrowlController *)sharedGrowlController
{
    @synchronized(self) {
        if (sharedGrowlController == nil) {
            sharedGrowlController = [[super allocWithZone:NULL] init];
        }
    }
    
    return sharedGrowlController;
}

+ (id)allocWithZone:(NSZone *)zone
{    
    @synchronized(self) {
		return [[self sharedGrowlController] retain]; 
    } 
	
	return nil;
}

- (id)init
{
    if ((self = [super init])) {
        [GrowlApplicationBridge setGrowlDelegate:self];
		
		timingNotificationName = nil;
		timingNotificationStart = 0;
		
		longRunningQueryNotificationTime = [[NSUserDefaults standardUserDefaults] floatForKey:SPLongRunningQueryNotificationTime];
    }
    
    return self;
}

#pragma mark -

/**
 * Posts a Growl notification using the supplied details and default values.
 * Calls the notification after a tiny delay to allow isKeyWindow to have updated
 * after tasks.
 */
- (void)notifyWithTitle:(NSString *)title description:(NSString *)description document:(SPDatabaseDocument *)document notificationName:(NSString *)name
{
	// Ensure that the delayed notification call is made on the main thread
	if (![NSThread isMainThread]) {
		[[self onMainThread] notifyWithTitle:title description:description document:document notificationName:name];
		return;
	}

	NSMutableDictionary *notificationDictionary = [NSMutableDictionary dictionary];
	
	[notificationDictionary setObject:title forKey:@"title"];
	[notificationDictionary setObject:description forKey:@"description"];
	[notificationDictionary setObject:document forKey:@"document"];
	[notificationDictionary setObject:name forKey:@"name"];
	[notificationDictionary setObject:@{@"notificationDocumentHash" : @([document hash])} forKey:@"clickContext"];

	[self performSelector:@selector(notifyWithObject:) withObject:notificationDictionary afterDelay:0.1];
}

/**
 * Posts a Growl notification, using a NSDictionary to contain all arguments.
 * Allows calling either with an NSThread or afterDelay as it only accepts a
 * single argument.
 */
- (void)notifyWithObject:(NSDictionary *)notificationDictionary
{
	[self notifyWithTitle:[notificationDictionary objectForKey:@"title"]
			  description:[notificationDictionary objectForKey:@"description"]
				 document:[notificationDictionary objectForKey:@"document"]
		 notificationName:[notificationDictionary objectForKey:@"name"]
				 iconData:nil
				 priority:0
				 isSticky:NO
			 clickContext:[notificationDictionary objectForKey:@"clickContext"]];
}

/**
 * Posts a Growl notification using the supplied details and effectively ignoring the default values.
 */
- (void)notifyWithTitle:(NSString *)title description:(NSString *)description document:(SPDatabaseDocument *)document notificationName:(NSString *)name iconData:(NSData *)data priority:(NSInteger)priority isSticky:(BOOL)sticky clickContext:(id)clickContext
{
	BOOL postNotification = YES;

	// Don't post the notification if the notification document is frontmost
	// as that suggests the user is already viewing the notification result.
	if ([[document parentWindow] isKeyWindow] && 
		[[[document parentTabViewItem] tabView] selectedTabViewItem] == [document parentTabViewItem])
	{
		postNotification = NO;
	}

	// If a timing notification name exists, check to see if it matches the notification name;
	// if it does, and the time exceeds the threshold, display the notification even for
	// frontmost windows to provide feedback for long-running tasks.
	if (timingNotificationName && [timingNotificationName isEqualToString:name]) {
		if ([NSDate monotonicTimeInterval] > (longRunningQueryNotificationTime * 1000) + timingNotificationStart) {
			postNotification = YES;
		}
		
		SPClear(timingNotificationName);
	}

    // Post notification only if preference is set and visibility has been confirmed
	if (postNotification && [[NSUserDefaults standardUserDefaults] boolForKey:SPGrowlEnabled]) {
		[GrowlApplicationBridge notifyWithTitle:title
									description:description
							   notificationName:name
									   iconData:data
									   priority:(int)priority
									   isSticky:sticky
								   clickContext:clickContext];
	}
}

/**
 * React to a click on the notification.
 */
- (void)growlNotificationWasClicked:(NSDictionary *)clickContext
{
	if (clickContext && [clickContext objectForKey:@"notificationDocumentHash"]) {
		NSUInteger documentHash = [[clickContext objectForKey:@"notificationDocumentHash"] unsignedIntegerValue];

		// Loop through the windows, looking for the document
		for (NSWindow *eachWindow in [SPAppDelegate orderedDatabaseConnectionWindows])
		{
			for (SPDatabaseDocument *eachDocument in [[eachWindow windowController] documents])
			{
				if ([eachDocument hash] == documentHash) {
					[NSApp activateIgnoringOtherApps:YES];
					[eachDocument makeKeyDocument];
					return;
				}
			}
		}
	}
}

/**
 * Start the notification timer for a specific notification name.  Only one notification
 * timer can run at once, and tracks the time between this start and the notification
 * being posted; if the notification is posted after the header-defined boundary, the
 * notification will then be shown even if the app is frontmost.
 */
- (void)setVisibilityForNotificationName:(NSString *)name
{
	if (timingNotificationName) {
		SPClear(timingNotificationName);
	}
	
	timingNotificationName = [[NSString alloc] initWithString:name];
	timingNotificationStart = [NSDate monotonicTimeInterval];
}

@end
