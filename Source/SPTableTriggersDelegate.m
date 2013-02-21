//
//  $Id$
//
//  SPTableTriggersDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on February 21, 2013.
//  Copyright (c) 2013 Stuart Connolly. All rights reserved.
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

#import "SPTableTriggersDelegate.h"
#import "SPDatabaseDocument.h"

@interface SPTableTriggers ()

- (void)_editTriggerAtIndex:(NSInteger)index;
- (void)_toggleConfirmAddTriggerButtonEnabled;

@end

@implementation SPTableTriggers (SPTableTriggersDelegate)

#pragma mark -
#pragma mark Tableview delegate methods

/**
 * Called whenever the triggers table view selection changes.
 */
- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	[removeTriggerButton setEnabled:([triggersTableView numberOfSelectedRows] > 0)];
}

/**
 * Alter the colour of cells displaying NULL values
 */
- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if (![cell respondsToSelector:@selector(setTextColor:)]) {
		return;
	}
	
	id value = [[triggerData objectAtIndex:rowIndex] objectForKey:[tableColumn identifier]];
	
	[cell setTextColor:[value isNSNull] ? [NSColor lightGrayColor] : [NSColor blackColor]];
}

/**
 * Double-click action on table cells - for the time being, return NO to disable editing.
 */
- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if ([tableDocumentInstance isWorking]) return NO;
	
	// Start Edit panel
	if (((NSInteger)[triggerData count] > rowIndex) && [triggerData objectAtIndex:rowIndex]) {
		[self _editTriggerAtIndex:rowIndex];
	}
	
	return NO;
}

/**
 * Disable row selection while the document is working.
 */
- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)rowIndex
{
	return (![tableDocumentInstance isWorking]);
}

#pragma mark -
#pragma mark Textfield delegate methods

/**
 * Toggles the enabled state of confirm add trigger button based on the editing of the trigger's name.
 */
- (void)controlTextDidChange:(NSNotification *)notification
{
	[self _toggleConfirmAddTriggerButtonEnabled];
}

@end
