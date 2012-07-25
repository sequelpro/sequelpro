//
//  $Id$
//
//  SPAlertSheets.m
//  sequel-pro
//
//  Created by Rowan Beentje on January 20, 2010.
//  Copyright (c) 2010 Rowan Beentje. All rights reserved.
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

#import "SPAlertSheets.h"

/**
 * Provide a simple alias of NSBeginAlertSheet, with a few differences:
 *  - printf-type format strings are no longer supported within the "msg"
 *    message text argument, preventing access of random stack areas for
 *    error text which contains inadvertant printf formatting.
 *  - The didDismissSelector is no longer supported
 *  - The sheet no longer needs to be orderOut:ed after use
 *  - The alert is always shown on the main thread.
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
	NSString *msg) 
{
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

/**
 * Provide a simple alias of a NSApp-wide modal NSBeginAlertSheet which waits 
 * for a in calling class globally declared returnCode by reference which must 
 * be changed in the didEndSelector of the calling class, with a few differences:
 *  - printf-type format strings are no longer supported within the "msg"
 *    message text argument, preventing access of random stack areas for
 *    error text which contains inadvertant printf formatting.
 *  - The didDismissSelector is no longer supported
 *  - The sheet no longer needs to be orderOut:ed after use
 *  - The alert is always shown on the main thread.
 */
void SPBeginWaitingAlertSheet(
		NSString *title,
		NSString *defaultButton,
		NSString *alternateButton,
		NSString *otherButton,
	NSAlertStyle alertStyle,
		NSWindow *docWindow,
			  id modalDelegate,
			 SEL didEndSelector,
			void *contextInfo,
		NSString *msg,
		NSString *infoText,
	   NSInteger *returnCode) 
{

	NSButton *aButton;

	// Initialize returnCode with a value which can't be returned as
	// returnCode in the didEndSelector method
	NSInteger initialReturnCode = -5;
	returnCode = &initialReturnCode;

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

	// Set alert  style
	[alert setAlertStyle:NSWarningAlertStyle];
	if(alertStyle)
		[alert setAlertStyle:alertStyle];

	// Set the informative message if supplied
	if (infoText) [alert setInformativeText:infoText];

	// Set the informative message if supplied
	if (msg) [alert setMessageText:msg];

	// Run the alert on the main thread
	[[alert onMainThread] beginSheetModalForWindow:docWindow modalDelegate:modalDelegate didEndSelector:didEndSelector contextInfo:contextInfo];

	// wait for the sheet
	NSModalSession session = [[NSApp onMainThread] beginModalSessionForWindow:[alert window]];
	for (;;) {

		// Since the returnCode can only be -1, 0, or 1
		// run the session until returnCode was changed in 
		// the didEndSelector method of the calling class
		if(returnCode != &initialReturnCode)
			break;

		// Execute code on DefaultRunLoop
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode 
								 beforeDate:[NSDate distantFuture]];

		// Break the run loop if sheet was closed
		if ([NSApp runModalSession:session] != NSRunContinuesResponse 
			|| ![[alert window] isVisible]) 
			break;

		// Execute code on DefaultRunLoop
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode 
								 beforeDate:[NSDate distantFuture]];

	}
	
	[[NSApp onMainThread] endModalSession:session];
	[[NSApp onMainThread] endSheet:[alert window]];
}
