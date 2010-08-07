//
//  $Id$
//
//  SPAlertSheets.m
//  sequel-pro
//
//  Created by Rowan Beentje on January 20, 2010
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

#import "SPMainThreadTrampoline.h"

/**
 * Provide a simple alias of NSBeginAlertSheet, with a few differences:
 *  - printf-type format strings are no longer supported within the "msg"
 *    message text argument, preventing access of random stack areas for
 *    error text which contains inadvertant printf formatting.
 *  - The didDismissSelector is no longer supported
 *  - The sheet no longer needs to be orderOut:ed after use
 *  - The alert is alays shown on the main thread.
 */
void SPBeginAlertSheet(
	NSString *title,
	NSString *defaultButton,
	NSString *alternateButton,
	NSString *otherButton,
	NSWindow *docWindow,
		  id modalDelegate,
		 SEL didEndSelector,
		void *contextInfo,
	NSString *msg
) {
	NSButton *aButton;

	// Set up an NSAlert with the supplied details
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert setMessageText:title];
	aButton = [alert addButtonWithTitle:defaultButton];
	[aButton setTag:NSAlertDefaultReturn];

	// Add 'alternate' and 'other' buttons as appropriate
	if (alternateButton) {
		aButton = [alert addButtonWithTitle:alternateButton];
		[aButton setTag:NSAlertAlternateReturn];
	}
	if (otherButton) {
		aButton = [alert addButtonWithTitle:otherButton];
		[aButton setTag:NSAlertOtherReturn];
	}

	// Set the informative message if supplied
	if (msg) [alert setInformativeText:msg];

	// Run the alert on the main thread
	[[alert onMainThread] beginSheetModalForWindow:docWindow modalDelegate:modalDelegate didEndSelector:didEndSelector contextInfo:contextInfo];

	// Ensure the alerting window is frontmost
	[[docWindow onMainThread] makeKeyWindow];
}
