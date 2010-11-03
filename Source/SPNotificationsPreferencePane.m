//
//  $Id$
//
//  SPNotificationsPreferencePane.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 31, 2010
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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
