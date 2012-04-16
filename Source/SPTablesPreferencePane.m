//
//  $Id$
//
//  SPTablesPreferencePane.m
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
	[(SPPreferenceController *)[[[self view] window] delegate] setFontChangeTarget:1];
	
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
	NSFont *font = [NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPGlobalResultTableFont]];
	
	[globalResultTableFontName setFont:font];
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

@end
