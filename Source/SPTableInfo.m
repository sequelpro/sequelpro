//
//  SPTableInfo.m
//  sequel-pro
//
//  Created by Ben Perry on Jun 6, 2008.
//  Copyright (c) 2008 Ben Perry. All rights reserved.
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

#import "SPTableInfo.h"
#import "ImageAndTextCell.h"
#import "SPDatabaseDocument.h"
#import "SPTablesList.h"
#import "SPTableData.h"
#import "SPActivityTextFieldCell.h"
#import "SPTableTextFieldCell.h"
#import "SPAppController.h"

@interface SPTableInfo (PrivateAPI)

- (NSString *)_getUserDefinedDateStringFromMySQLDate:(NSString *)mysqlDate;

@end

@implementation SPTableInfo

#pragma mark -
#pragma mark Initialisation

- (id)init
{
	if ((self = [super init])) {
		info       = [[NSMutableArray alloc] init];
		activities = [[NSMutableArray alloc] init];
		
		_activitiesWillBeUpdated = NO;
	}

	return self;
}

- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(tableChanged:)
												 name:SPTableChangedNotification
											   object:tableDocumentInstance];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(tableChanged:)
												 name:SPTableInfoChangedNotification
											   object:tableDocumentInstance];

	// Register activities update notifications for add/remove BASH commands etc.
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(updateActivities)
												 name:SPActivitiesUpdateNotification
											   object:nil];

	// Add activities header
	[activities addObject:@{@"name" : NSLocalizedString(@"ACTIVITIES", @"header for activities pane")}];
	[activitiesTable reloadData];

	// Add Information header
	[info addObject:NSLocalizedString(@"TABLE INFORMATION", @"header for table info pane")];
	[infoTable reloadData];
}

#pragma mark -

/**
 * Remove an activity directly from the list since an update will be performer in the background
 * to signilize the user that an activity was cancelled at once
 */
- (void)removeActivity:(NSInteger)pid
{
	for (id cmd in activities) 
	{
		if ([[cmd objectForKey:@"pid"] integerValue] == pid) {
			[activities removeObject:cmd];
			break;
		}
	}
	
	[activitiesTable reloadData];
}

- (void)updateActivities
{
	NSMutableArray *acts = [NSMutableArray array];
	
	[acts removeAllObjects];
	[acts addObject:@{@"name" : NSLocalizedString(@"ACTIVITIES", @"header for activities pane")}];
	[acts addObjectsFromArray:[tableDocumentInstance runningActivities]];
	[acts addObjectsFromArray:[SPAppDelegate runningActivities]];
	
	_activitiesWillBeUpdated = YES;
	
	[activities setArray:acts];
	
	_activitiesWillBeUpdated = NO;
	
	[activitiesTable reloadData];
	[infoTable deselectAll:nil];
	[activitiesTable deselectAll:nil];
}

/**
 * Notification to indicate the table has changed and that the table info requires
 * reloading for display.  This is called on table changes, and also (with a nil argument)
 * during certain refresh operations to trigger a data update.
 * This function is not thread-safe.
 */
- (void)tableChanged:(NSNotification *)notification
{
	NSDictionary *tableStatus;
	NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];

	[info removeAllObjects];

	if (![tableListInstance tableName]) {
		[info addObject:NSLocalizedString(@"INFORMATION", @"header for blank info pane")];
		
		if ([[tableListInstance selectedTableItems] count]) {
			[info addObject:NSLocalizedString(@"multiple selection", @"multiple selection")];
		}
		
		[infoTable reloadData];
		
		return;
	}

	// Get TABLE information
	if ([tableListInstance tableType] == SPTableTypeTable) {

		[info addObject:NSLocalizedString(@"TABLE INFORMATION", @"header for table info pane")];

		if ([tableListInstance tableName]) {

			// Retrieve the table status information via the data cache
			tableStatus = [tableDataInstance statusValues];

			// Check for errors
			if (![tableStatus count]) {
				[info addObject:NSLocalizedString(@"error occurred", @"error occurred")];
				return;
			}

			// Check for 'Create_time' == NULL
			if (![[tableStatus objectForKey:@"Create_time"] isNSNull]) {

				// Add the creation date to the infoTable
				[info addObject:[NSString stringWithFormat:NSLocalizedString(@"created: %@", @"Table Info Section : time+date table was created at"), [self _getUserDefinedDateStringFromMySQLDate:[tableStatus objectForKey:@"Create_time"]]]];
			}

			// Check for 'Update_time' == NULL - InnoDB tables don't have an update time
			if (![[tableStatus objectForKey:@"Update_time"] isNSNull]) {

				// Add the update date to the infoTable
				[info addObject:[NSString stringWithFormat:NSLocalizedString(@"updated: %@", @"updated: %@"), [self _getUserDefinedDateStringFromMySQLDate:[tableStatus objectForKey:@"Update_time"]]]];
			}
			
			// Check for 'Engine' == NULL - should not happen (at least not with MySQL)
			if (![[tableStatus objectForKey:@"Engine"] isNSNull]) {
				[info addObject:[NSString stringWithFormat:NSLocalizedString(@"engine: %@", @"Table Info Section : Table Engine"), [tableStatus objectForKey:@"Engine"]]];
			}

			// Check for 'Rows' == NULL - information_schema database doesn't report row count for it's tables
			if (![[tableStatus objectForKey:@"Rows"] isNSNull]) {
				[info addObject:[NSString stringWithFormat:[[tableStatus objectForKey:@"RowsCountAccurate"] boolValue] ? NSLocalizedString(@"rows: %@", @"Table Info Section : number of rows (exact value)") : NSLocalizedString(@"rows: ~%@", @"Table Info Section : number of rows (estimated value)"),
					[numberFormatter stringFromNumber:[NSNumber numberWithLongLong:[[tableStatus objectForKey:@"Rows"] longLongValue]]]]];
			}
			
			// Check for 'Data_Length' == NULL (see PR #2606)
			if([[tableStatus objectForKey:@"Data_length"] unboxNull]) {
				[info addObject:[NSString stringWithFormat:NSLocalizedString(@"size: %@", @"Table Info Section : table size on disk"), [NSString stringForByteSize:[[tableStatus objectForKey:@"Data_length"] longLongValue]]]];
			}

			NSString *tableEnc = [tableDataInstance tableEncoding];
			NSString *tableColl = [tableStatus objectForKey:@"Collation"];

			if([tableColl length]) {
				// instead of @"latin1 (latin1_german_ci)" we can just show @"latin1 (german_ci)"
				if([tableColl hasPrefix:[NSString stringWithFormat:@"%@_",tableEnc]]) tableColl = [tableColl substringFromIndex:([tableEnc length]+1)];
				[info addObject:[NSString stringWithFormat:NSLocalizedString(@"encoding: %1$@ (%2$@)", @"Table Info Section : $1 = table charset, $2 = table collation"), tableEnc, tableColl]];
			}
			else {
				[info addObject:[NSString stringWithFormat:NSLocalizedString(@"encoding: %1$@", @"Table Info Section : $1 = table charset"), tableEnc]];
			}
			
			if (![[tableStatus objectForKey:@"Auto_increment"] isNSNull]) {
				[info addObject:[NSString stringWithFormat:NSLocalizedString(@"auto_increment: %@", @"Table Info Section : current value of auto_increment"),
					[numberFormatter stringFromNumber:[NSNumber numberWithLongLong:[[tableStatus objectForKey:@"Auto_increment"] longLongValue]]]]];
			}

		}
	}
	// Get PROC/FUNC information
	else if ([tableListInstance tableType] == SPTableTypeProc || [tableListInstance tableType] == SPTableTypeFunc) {

		if ([tableListInstance tableType] == SPTableTypeProc)
			[info addObject:NSLocalizedString(@"PROCEDURE INFORMATION", @"header for procedure info pane")];
		else
			[info addObject:NSLocalizedString(@"FUNCTION INFORMATION", @"header for function info pane")];

		if ([tableListInstance tableName]) {

			// Retrieve the table status information via the data cache
			tableStatus = [tableDataInstance statusValues];

			// Check for errors
			if (![tableStatus count]) {
				[info addObject:NSLocalizedString(@"error occurred", @"error occurred")];
				return;
			}

			// Check for 'CREATED' == NULL
			if (![[tableStatus objectForKey:@"CREATED"] isNSNull]) {

				// Add the creation date to the infoTable
				[info addObject:[NSString stringWithFormat:NSLocalizedString(@"created: %@", @"created: %@"), [self _getUserDefinedDateStringFromMySQLDate:[tableStatus objectForKey:@"CREATED"]]]];
			}

			// Check for 'LAST_ALTERED'
			if (![[tableStatus objectForKey:@"LAST_ALTERED"] isNSNull]) {

				// Add the update date to the infoTable
				[info addObject:[NSString stringWithFormat:NSLocalizedString(@"updated: %@", @"updated: %@"), [self _getUserDefinedDateStringFromMySQLDate:[tableStatus objectForKey:@"LAST_ALTERED"]]]];
			}

			// Check for 'SQL ACCESS' and deterministic
			if (![[tableStatus objectForKey:@"SQL_DATA_ACCESS"] isNSNull] && ![[tableStatus objectForKey:@"IS_DETERMINISTIC"] isNSNull]) {
				[info addObject:[NSString stringWithFormat:NSLocalizedString(@"data access: %@ (%@)", @"data access: %@ (%@)"), [tableStatus objectForKey:@"SQL_DATA_ACCESS"], ([[tableStatus objectForKey:@"IS_DETERMINISTIC"] isEqualToString:@"YES"]) ? @"deterministic" : @"non-deterministic"]];
			}

			// Check for 'DTD_IDENTIFIER' for FUNCTIONS only
			if ([tableListInstance tableType] == SPTableTypeFunc) {
				if (![[tableStatus objectForKey:@"DTD_IDENTIFIER"] isNSNull]) {
					[info addObject:[NSString stringWithFormat:NSLocalizedString(@"return type: %@", @"return type: %@"), [tableStatus objectForKey:@"DTD_IDENTIFIER"]]];
				}
			}

			// Check for 'SECURITY_TYPE'
			if (![[tableStatus objectForKey:@"SECURITY_TYPE"] isNSNull]) {
				[info addObject:[NSString stringWithFormat:NSLocalizedString(@"execution privilege: %@", @"execution privilege: %@"), [tableStatus objectForKey:@"SECURITY_TYPE"]]];
			}

			// Check for 'DEFINER'
			if (![[tableStatus objectForKey:@"DEFINER"] isNSNull]) {
				[info addObject:[NSString stringWithFormat:NSLocalizedString(@"definer: %@", @"definer: %@"), [tableStatus objectForKey:@"DEFINER"]]];
			}

		}
	}
	// Get VIEW information
	else if ([tableListInstance tableType] == SPTableTypeView) {

		[info addObject:NSLocalizedString(@"VIEW INFORMATION", @"header for view info pane")];

		if ([tableListInstance tableName]) {

			// Retrieve the table status information via the data cache
			tableStatus = [tableDataInstance statusValues];

			// Check for errors
			if (![tableStatus count]) {
				[info addObject:NSLocalizedString(@"error occurred", @"error occurred")];
				return;
			}

			// Check for 'CREATED' == NULL
			if (![[tableStatus objectForKey:@"DEFINER"] isNSNull]) {

				// Add the creation date to the infoTable
				[info addObject:[NSString stringWithFormat:NSLocalizedString(@"definer: %@", @"definer: %@"), [tableStatus objectForKey:@"DEFINER"]]];

				// Check for 'SECURITY_TYPE'
				if (![[tableStatus objectForKey:@"SECURITY_TYPE"] isNSNull]) {
					[info addObject:[NSString stringWithFormat:NSLocalizedString(@"execution privilege: %@", @"execution privilege: %@"), [tableStatus objectForKey:@"SECURITY_TYPE"]]];
				}

				// Check for 'IS_UPDATABLE'
				if (![[tableStatus objectForKey:@"IS_UPDATABLE"] isNSNull]) {
					[info addObject:[NSString stringWithFormat:NSLocalizedString(@"is updatable: %@", @"is updatable: %@"), [tableStatus objectForKey:@"IS_UPDATABLE"]]];
				}

				// Check for 'CHECK_OPTION'
				if (![[tableStatus objectForKey:@"CHECK_OPTION"] isNSNull]) {
					[info addObject:[NSString stringWithFormat:NSLocalizedString(@"check option: %@", @"check option: %@"), [tableStatus objectForKey:@"CHECK_OPTION"]]];
				}

				// Check for 'CHARACTER_SET_CLIENT'
				if (![[tableStatus objectForKey:@"CHARACTER_SET_CLIENT"] isNSNull]) {
					[info addObject:[NSString stringWithFormat:NSLocalizedString(@"character set client: %@", @"character set client: %@"), [tableStatus objectForKey:@"CHARACTER_SET_CLIENT"]]];
				}

				// Check for 'COLLATION_CONNECTION'
				if (![[tableStatus objectForKey:@"COLLATION_CONNECTION"] isNSNull]) {
					[info addObject:[NSString stringWithFormat:NSLocalizedString(@"collation connection: %@", @"collation connection: %@"), [tableStatus objectForKey:@"COLLATION_CONNECTION"]]];
				}
			}
		}

	}

	[infoTable reloadData];
}

#pragma mark -
#pragma mark TableView datasource methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return (tableView == infoTable) ? [info count] : [activities count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if (tableView == infoTable) {
		return [info objectAtIndex:rowIndex];
	} 
	else {
		if (rowIndex == 0) {
			SPTableTextFieldCell *c = [[[SPTableTextFieldCell alloc] initTextCell:NSLocalizedString(@"ACTIVITIES", @"header for activities pane")] autorelease];
			
			[tableColumn setDataCell:c];
			
			return NSLocalizedString(@"ACTIVITIES", @"header for activities pane");
		}
		else if (!_activitiesWillBeUpdated && rowIndex > 0 && rowIndex < (NSInteger)[activities count]) {
			NSDictionary *dict = NSArrayObjectAtIndex(activities,rowIndex);
			SPActivityTextFieldCell *c = [[[SPActivityTextFieldCell alloc] init] autorelease];
			
			[c setActivityName:[[dict objectForKey:@"contextInfo"] objectForKey:@"name"]];
			
			if ([dict objectForKey:@"type"] && [[dict objectForKey:@"type"] isEqualToString:@"bashcommand"]) {
				[c setContextInfo:[NSDictionary dictionaryWithObjectsAndKeys:[dict objectForKey:@"type"], @"type", [dict objectForKey:@"pid"], @"pid", nil]];
				[c setActivityInfo:[NSString stringWithFormat:@"[%@] %@: %@", [[dict objectForKey:@"contextInfo"] objectForKey:@"scope"], NSLocalizedString(@"started", @"started"), [dict objectForKey:@"starttime"]]];
			} 
			else {
				[c setActivityInfo:@"..."];
			}
			
			[tableColumn setDataCell:c];
			
			return [dict objectForKey:@"name"];
		} 
		else {
			SPActivityTextFieldCell *c = [[[SPActivityTextFieldCell alloc] init] autorelease];
			
			[c setActivityName:@"..."];
			[c setActivityInfo:@""];
			[tableColumn setDataCell:c];
			
			return @"...";
		}
		
		return @"";
	}
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
	return (row == 0 ? 25 : [tableView rowHeight]);
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)rowIndex
{
	if (rowIndex == 0) return YES;
	
	if (tableView == infoTable) {
		return NO;
	} 
	else {
		return YES;
	}
	
	return NO;
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if (rowIndex > 0) return NO;

	if (![tableInfoScrollView isHidden]) {
		[tableDocumentInstance setActivityPaneHidden:@0];
		[[activitiesTable window] makeFirstResponder:activitiesTable];
	} 
	else {
		[tableDocumentInstance setActivityPaneHidden:@1];
		[[infoTable window] makeFirstResponder:infoTable];
	}

	[infoTable deselectAll:nil];
	[activitiesTable deselectAll:nil];

	[self updateActivities];
	
	return NO;
}

- (NSString *)tableView:(NSTableView *)tableView toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex mouseLocation:(NSPoint)mouseLocation
{
	if (tableView == activitiesTable) {
		if (rowIndex == 0) return @"";
		
		if (mouseLocation.x > rect->origin.x + rect->size.width - 30) {
			return NSLocalizedString(@"Cancel", @"cancel");
		}

		NSDictionary *dict = NSArrayObjectAtIndex(activities,rowIndex);
		
		if ([[dict objectForKey:@"contextInfo"] objectForKey:@"name"]) {
			return [[dict objectForKey:@"contextInfo"] objectForKey:@"name"];
		}
		
		return @"";
	}
	
	return nil;
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row
{
	// This makes the top row (TABLE INFORMATION/ACTIVITIES) have the diff styling
	return row == 0;
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if (tableView == infoTable) {
		if (rowIndex > 0 && [[tableColumn identifier] isEqualToString:@"info"]) {
			[(ImageAndTextCell*)cell setImage:[NSImage imageNamed:@"table-property"]];
			[(ImageAndTextCell*)cell setIndentationLevel:1];
			[(ImageAndTextCell*)cell setDrawsBackground:NO];
		} 
		else {
			[(ImageAndTextCell*)cell setImage:nil];
			[(ImageAndTextCell*)cell setIndentationLevel:0];
		}
	}
}

#pragma mark -
#pragma mark Private API

- (NSString *)_getUserDefinedDateStringFromMySQLDate:(NSString *)mysqlDate
{
	NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];

	[dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];

	[dateFormatter setDateStyle:NSDateFormatterShortStyle];
	[dateFormatter setTimeStyle:NSDateFormatterNoStyle];

	// Convert our string date from the result to an NSDate
	NSDate *updateDate = [NSDate dateWithNaturalLanguageString:mysqlDate];

	return [dateFormatter stringFromDate:updateDate];
}

#pragma mark -

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	SPClear(info);
	SPClear(activities);
	
	[super dealloc];
}

@end
