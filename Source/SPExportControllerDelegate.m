//
//  $Id$
//
//  SPExportControllerDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on October 23, 2010
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

#import "SPExportControllerDelegate.h"

@implementation SPExportController (SPExportControllerDelegate)

#pragma mark -
#pragma mark Table view datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
{
	return [tables count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{		
	return NSArrayObjectAtIndex([tables objectAtIndex:rowIndex], [exportTableList columnWithIdentifier:[tableColumn identifier]]);
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{	
	[[tables objectAtIndex:rowIndex] replaceObjectAtIndex:[exportTableList columnWithIdentifier:[tableColumn identifier]] withObject:anObject];
	
	[self _toggleExportButtonOnBackgroundThread];
}

#pragma mark -
#pragma mark Table view delegate methods

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)rowIndex
{
	return (tableView != exportTableList);
}

- (BOOL)tableView:(NSTableView *)tableView shouldTrackCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	return (tableView == exportTableList);
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	[aCell setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
}

#pragma mark -
#pragma mark Tabview delegate methods

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	[tabViewItem setView:exporterView];
	
	[self _switchTab];
}

#pragma mark -
#pragma mark Combo box delegate methods

- (void)comboBoxSelectionDidChange:(NSNotification *)notification
{
	if ([notification object] == exportCSVFieldsTerminatedField) {
		[self updateDisplayedExportFilename];
	}
}

@end
