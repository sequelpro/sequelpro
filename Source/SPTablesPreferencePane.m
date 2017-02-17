//
//  SPTablesPreferencePane.m
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

#import "SPTablesPreferencePane.h"
#import "SPPreferenceController.h"

@implementation SPTablesPreferencePane

#pragma mark -
#pragma mark IB action methods

/**
 * Opens the font panel for selecting the global result table font.
 */
- (IBAction)showGlobalResultTableFontPanel:(id)sender
{	
	[(SPPreferenceController *)[[[self view] window] delegate] setFontChangeTarget:SPPrefFontChangeTargetTable];
	
	[[NSFontPanel sharedFontPanel] setPanelFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPGlobalResultTableFont]] isMultiple:NO];
	[[NSFontPanel sharedFontPanel] makeKeyAndOrderFront:self];
}

#pragma mark -
#pragma mark Public API

/**
 * Updates the displayed font according to the user's preferences.
 */
- (void)updateDisplayedTableFontName
{	
	[globalResultTableFontName setFont:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPGlobalResultTableFont]]];
}

#pragma mark -
#pragma mark Preference pane protocol methods

- (NSView *)preferencePaneView
{
	return [self view];
}

- (NSImage *)preferencePaneIcon
{
	return [NSImage imageNamed:@"toolbar-preferences-tables"];
}

- (NSString *)preferencePaneName
{
	return NSLocalizedString(@"Tables", @"tables preference pane name");
}

- (NSString *)preferencePaneIdentifier
{
	return SPPreferenceToolbarTables;
}

- (NSString *)preferencePaneToolTip
{
	return NSLocalizedString(@"Table Preferences", @"general preference pane tooltip");
}

- (BOOL)preferencePaneAllowsResizing
{
	return NO;
}

- (void)preferencePaneWillBeShown
{
	[self updateDisplayedTableFontName];
}

@end
