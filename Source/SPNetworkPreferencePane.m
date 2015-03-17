//
//  SPNetworkPreferencePane.m
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

#import "SPNetworkPreferencePane.h"

@interface SPNetworkPreferencePane (Private)
- (void)updateHiddenFiles;
@end

@implementation SPNetworkPreferencePane

#pragma mark -
#pragma mark Preference pane protocol methods

- (NSView *)preferencePaneView
{
	return [self view];
}

- (NSImage *)preferencePaneIcon
{
	return [NSImage imageNamed:@"toolbar-preferences-network"];
}

- (NSString *)preferencePaneName
{
	return NSLocalizedString(@"Network", @"network preference pane name");
}

- (NSString *)preferencePaneIdentifier
{
	return SPPreferenceToolbarNetwork;
}

- (NSString *)preferencePaneToolTip
{
	return NSLocalizedString(@"Network Preferences", @"network preference pane tooltip");
}

- (BOOL)preferencePaneAllowsResizing
{
	return NO;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if([SPHiddenKeyFileVisibilityKey isEqualTo:keyPath]) {
		[self updateHiddenFiles];
	}
}

- (void)updateHiddenFiles
{
	[_currentFilePanel setShowsHiddenFiles:[prefs boolForKey:SPHiddenKeyFileVisibilityKey]];
}

- (IBAction)pickSSHClientViaFileBrowser:(id)sender
{
	_currentFilePanel = [NSOpenPanel openPanel];
	[_currentFilePanel setCanChooseFiles:YES];
	[_currentFilePanel setCanChooseDirectories:NO];
	[_currentFilePanel setAllowsMultipleSelection:NO];
	[_currentFilePanel setAccessoryView:hiddenFileView];
	[self updateHiddenFiles];
	
	[prefs addObserver:self
			forKeyPath:SPHiddenKeyFileVisibilityKey
	           options:NSKeyValueObservingOptionNew
			   context:NULL];
	
	[_currentFilePanel beginSheetModalForWindow:[_currentAlert window] completionHandler:^(NSInteger result) {
		if(result == NSFileHandlingPanelOKButton) [sshClientPath setStringValue:[[_currentFilePanel URL] path]];
		
		[prefs removeObserver:self forKeyPath:SPHiddenKeyFileVisibilityKey];
		
		_currentFilePanel = nil;
	}];
}

- (IBAction)pickSSHClient:(id)sender
{
	//take value from user defaults
	NSString *oldPath = [prefs stringForKey:SPSSHClientPath];
	if([oldPath length]) [sshClientPath setStringValue:oldPath];
	
	// set up dialog
	_currentAlert = [[NSAlert alloc] init]; //needs to be ivar so we can attach the OpenPanel later
	[_currentAlert setAccessoryView:sshClientPickerView];
	[_currentAlert setAlertStyle:NSWarningAlertStyle];
	[_currentAlert setMessageText:NSLocalizedString(@"Unsupported configuration!",@"Preferences : Network : Custom SSH client : warning dialog title")];
	[_currentAlert setInformativeText:NSLocalizedString(@"Sequel Pro only supports and is tested with the default OpenSSH client versions included with Mac OS X. Using different clients might cause connection issues, security risks or not work at all.\n\nPlease be aware, that we cannot provide support for such configurations.",@"Preferences : Network : Custom SSH client : warning dialog message")];
	[_currentAlert addButtonWithTitle:NSLocalizedString(@"OK",@"Preferences : Network : Custom SSH client : warning dialog : accept button")];
	[_currentAlert addButtonWithTitle:NSLocalizedString(@"Cancel",@"Preferences : Network : Custom SSH client : warning dialog : cancel button")];
	
	if([_currentAlert runModal] == NSAlertFirstButtonReturn) {
		//store new value to user defaults
		NSString *newPath = [sshClientPath stringValue];
		if(![newPath length])
			[prefs removeObjectForKey:SPSSHClientPath];
		else
			[prefs setObject:newPath forKey:SPSSHClientPath];
	}
	
	SPClear(_currentAlert);
}

@end
