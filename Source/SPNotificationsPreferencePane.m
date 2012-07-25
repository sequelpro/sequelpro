//
//  $Id$
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
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPNotificationsPreferencePane.h"

@implementation SPNotificationsPreferencePane

#pragma mark -
#pragma mark Bindings

/**
 * Displays an informational message regarding Growl notifications if enabled.
 */
- (void)setGrowlEnabled:(BOOL)value
{
	if (value) {
		NSBeginInformationalAlertSheet(NSLocalizedString(@"Growl notification preferences", "Growl notification preferences alert title"),
									   nil, nil, nil, [[self view] window], self, nil, nil, nil,
									   NSLocalizedString(@"All Growl notifications are enabled by default. To change which notifications are displayed, go to the Growl Preference Pane in the System Preferences and choose what notifications Growl should display from Sequel Pro.", @"Growl notification preferences alert message"));
	}
	
	[prefs setBool:value forKey:SPGrowlEnabled];
}

/**
 * Returns the user's Growl notifications preference.
 */
- (BOOL)growlEnabled
{
	return [prefs boolForKey:SPGrowlEnabled];
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
