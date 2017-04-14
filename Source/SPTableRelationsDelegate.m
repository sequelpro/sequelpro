//
//  SPTableRelationsDelegate.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on March 28, 2017.
//  Copyright (c) 2017 Stuart Connolly. All rights reserved.
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

#import "SPTableRelationsDelegate.h"
#import "SPDatabaseDocument.h"

@implementation SPTableRelations (SPTableRelationsDelegate)

#pragma mark -
#pragma mark TextField delegate methods

- (void)controlTextDidChange:(NSNotification *)notification
{
	// Make sure the user does not enter a taken name, using the quickly-generated incomplete list
	if ([notification object] == constraintName) {
		NSString *userValue = [[constraintName stringValue] lowercaseString];

		// Make field red and disable add button
		if ([takenConstraintNames containsObject:userValue]) {
			[constraintName setTextColor:[NSColor redColor]];
			[confirmAddRelationButton setEnabled:NO];
		}
		else {
			[constraintName setTextColor:[NSColor controlTextColor]];
			[confirmAddRelationButton setEnabled:YES];
		}
	}
}

#pragma mark -
#pragma mark Tableview delegate methods

/**
 * Called whenever the relations table view selection changes.
 */
- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	[removeRelationButton setEnabled:([relationsTableView numberOfSelectedRows] > 0)];
}

/*
 * Double-click action on table cells - for the time being, return
 * NO to disable editing.
 */
- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if ([tableDocumentInstance isWorking]) return NO;

	return NO;
}

/**
 * Disable row selection while the document is working.
 */
- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)rowIndex
{
	return ![tableDocumentInstance isWorking];
}

@end
