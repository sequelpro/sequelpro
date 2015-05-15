//
//  SPNotificationsPreferencePane.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 31, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPNotificationsPreferencePane.h"
#import <Growl/Growl.h>
#import "SPGrowlController.h"

static NSString *_runningApplicationsKeyPath = @"runningApplications";

@implementation SPNotificationsPreferencePane

- (instancetype)init
{
	self = [super init];
	if (self) {
		// this notification is posted by the GrowlApplicationBridge right after
		// it would have called -[delegate growlIsReady], so we'll just use this
		// as a shortcut.
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(growlLaunchedNotifcation:)
													 name:GROWL_IS_READY
												   object:nil];
		// we need to initialize the GrowlApplicationBridge for the notification to actually work
		[SPGrowlController sharedGrowlController];
		// Growl doesn't tell use when it exits (even though they DO monitor it).
		// This code replicates what it does internally.
		[[NSWorkspace sharedWorkspace] addObserver:self
										forKeyPath:_runningApplicationsKeyPath
										   options:NSKeyValueObservingOptionNew
										   context:nil];
		// TODO: we are only really interested in this notification while we are visible.
	}
	return self;
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	//check if growl has exited
	if(object == [NSWorkspace sharedWorkspace] && [keyPath isEqualToString:_runningApplicationsKeyPath]){
		[self updateGrowlStatusLabel];
	}
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[NSWorkspace sharedWorkspace] removeObserver:self forKeyPath:_runningApplicationsKeyPath];
	[super dealloc];
}

- (void)growlLaunchedNotifcation:(NSNotification *)notification
{
	[self updateGrowlStatusLabel];
}

- (void)preferencePaneWillBeShown
{
	[self updateGrowlStatusLabel];
}

#pragma mark -
#pragma mark Bindings

- (void)setGrowlEnabled:(BOOL)value
{
	[prefs setBool:value forKey:SPGrowlEnabled];
}

/**
 * Returns the user's Growl notifications preference.
 */
- (BOOL)growlEnabled
{
	return [prefs boolForKey:SPGrowlEnabled];
}

- (void)updateGrowlStatusLabel
{
	NSString *text;
	if([GrowlApplicationBridge isGrowlRunning]) {
		text = NSLocalizedString(@"Growl will be used for sending notifications.\nAdvanced settings can be configured via Growl.",@"Preferences : Notifications : growl status text : growl installed and running");
	}
	else {
		text = @"";
		
		if(NSClassFromString(@"NSUserNotificationCenter")) { //this is what growl does
			//10.8+
			text = NSLocalizedString(@"Notification Center will be used for sending notifications. ",@"Preferences : Notifications : growl status text : growl not installed, Apple's Notificiation Center is used instead. (KEEP the SPACE at the end)");
		}
		//else case would be embedded growl ("Mist", 10.6 - 10.7), but telling that would IMHO be more confusing for the user.
		
		text = [text stringByAppendingString:NSLocalizedString(@"Install Growl for advanced control over notifications.",@"Preferences : Notifications : growl status text : additional hint when embedded Growl ('Mist') or Notification Center is used.")];
	}
	[growlStatusLabel setStringValue:text];
}

#pragma mark -
#pragma mark Preference pane protocol methods

- (NSView *)preferencePaneView
{
	return [self view];
}

- (NSImage *)preferencePaneIcon
{
	return [NSImage imageNamed:@"toolbar-preferences-notifications"];
}

- (NSString *)preferencePaneName
{
	return NSLocalizedString(@"Alerts & Logs", @"notifications preference pane name");
}

- (NSString *)preferencePaneIdentifier
{
	return SPPreferenceToolbarNotifications;
}

- (NSString *)preferencePaneToolTip
{
	return NSLocalizedString(@"Alerts & Logs Preferences", @"notifications preference pane tooltip");
}

- (BOOL)preferencePaneAllowsResizing
{
	return NO;
}

@end
