//
//  $Id$
//
//  SPProcessListControllerDataSource.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on April 3, 2013.
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

#import "SPProcessListControllerDataSource.h"

@implementation SPProcessListController (SPProcessListControllerDataSource)

#pragma mark -
#pragma mark Tableview delegate methods

/**
 * Table view delegate method. Returns the number of rows in the table veiw.
 */
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [processesFiltered count];
}

/**
 * Table view delegate method. Returns the specific object for the request column and row.
 */
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{	
	id object = ((NSUInteger)row < [processesFiltered count]) ? [[processesFiltered objectAtIndex:row] valueForKey:[tableColumn identifier]] : @"";
	
	if ([object isNSNull]) {
		return [prefs stringForKey:SPNullValue];
	}
	
	// If the string is exactly 100 characters long, and FULL process lists are not enabled, it's a safe
	// bet that the string is truncated
	if (!showFullProcessList && [object isKindOfClass:[NSString class]] && [(NSString *)object length] == 100) {
		return [object stringByAppendingString:@"…"];
	}
	
	return object;
}

/**
 * Table view delegate method. Called when the user changes the sort by column.
 */
- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
    [processesFiltered sortUsingDescriptors:[tableView sortDescriptors]];
    
	[tableView reloadData];
}

/**
 * Table view delegate method. Called whenever the user changes a column width.
 */
- (void)tableViewColumnDidResize:(NSNotification *)notification
{
	NSTableColumn *column = [[notification userInfo] objectForKey:@"NSTableColumn"];
	
	// Get the existing table column widths dictionary if it exists
	NSMutableDictionary *tableColumnWidths = ([prefs objectForKey:SPProcessListTableColumnWidths]) ?
	[NSMutableDictionary dictionaryWithDictionary:[prefs objectForKey:SPProcessListTableColumnWidths]] :
	[NSMutableDictionary dictionary];
	
	// Save column size
	NSString *columnName = [[column headerCell] stringValue];
	
	if (columnName) {
		[tableColumnWidths setObject:[NSNumber numberWithDouble:[column width]] forKey:columnName];
		
		[prefs setObject:tableColumnWidths forKey:SPProcessListTableColumnWidths];
	}
}

@end
