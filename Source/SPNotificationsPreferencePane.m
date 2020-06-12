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

static NSString *_runningApplicationsKeyPath = @"runningApplications";

@implementation SPNotificationsPreferencePane

- (instancetype)init
{
	self = [super init];
	if (self) {
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
	NSString *text = NSLocalizedString(@"Notification Center will be used for sending notifications. ",@"Preferences : Notifications : status text : using Apple Notification Center, Apple's Notificiation Center is used instead. (KEEP the SPACE at the end)");
		
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
