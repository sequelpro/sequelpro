//
//  $Id: SPTableView.m 866 2009-06-15 16:05:54Z bibiko $
//
//  SPTableView.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on July 15, 2009
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

#import "SPTableView.h"
#import "SPQueryFavoriteManager.h"
#import "SPArrayAdditions.h"
#import "SPDatabaseDocument.h"
#import "SPConstants.h"

@implementation SPTableView

/*
 * Right-click at row will select that row before ordering out the contextual menu
 * if not more than one row is selected
 */
- (NSMenu *)menuForEvent:(NSEvent *)event
{

	// Try to retrieve a reference to the table document (assuming this is frontmost tab)
	SPDatabaseDocument *parentTableDocument = nil;
	if ([[[[[self window] delegate] class] description] isEqualToString:@"SPWindowController"]) {
		parentTableDocument = [[[self window] delegate] selectedTableDocument];
	}

	// If SPDatabaseDocument is performing a task suppress any context menu
	if (parentTableDocument && [parentTableDocument isWorking])
		return nil;

	// Check to see whether any edits-in-progress need to be saved before changing selections
	if (parentTableDocument && ![parentTableDocument couldCommitCurrentViewActions])
		return nil;

	// If more than one row is selected only returns the default contextual menu
	if([self numberOfSelectedRows] > 1)
		return [self menu];
	
	// Right-click at a row will select that row before ordering out the context menu
	NSInteger row = [self rowAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]];
	if(row >= 0 && row < [self numberOfRows]) {
		
		// Check for SPTablesList if right-click on header, then suppress context menu
		if([[[[self delegate] class] description] isEqualToString:@"SPTablesList"]) {
			if([NSArrayObjectAtIndex([[self delegate] valueForKeyPath:@"tableTypes"], row) integerValue] == -1)
				return nil;
		}
		if([[[[self delegate] class] description] isEqualToString:@"SPQueryFavoriteManager"]) {
			if([NSArrayObjectAtIndex([[self delegate] valueForKeyPath:SPFavorites], row)  objectForKey:@"headerOfFileURL"])
				return nil;
		}
		if([[[[self delegate] class] description] isEqualToString:@"SPContentFilterManager"]) {
			if([NSArrayObjectAtIndex([[self delegate] valueForKeyPath:@"contentFilters"], row)  objectForKey:@"headerOfFileURL"])
				return nil;
		}
		
		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
		[[self window] makeFirstResponder:self];
	}
	
	return [self menu];
}

-(BOOL)acceptsFirstResponder
{
	return YES;
}

- (void)keyDown:(NSEvent *)theEvent
{

	// Check if ENTER or RETURN is hit and edit the column.
	if([self numberOfSelectedRows] == 1 && ([theEvent keyCode] == 36 || [theEvent keyCode] == 76))
	{

		// ENTER or RETURN closes the SPFieldMapperController sheet by sending an object with the tag 1
		if([[[[self delegate] class] description] isEqualToString:@"SPFieldMapperController"]) {
			if([[self delegate] canBeClosed]) {
				NSButton *b = [[[NSButton alloc] init] autorelease];
				[b setTag:1];
				[[self delegate] closeSheet:b];
				return;
			} else {
				[super keyDown:theEvent];
				return;
			}

		}

		if (![[[[self delegate] class] description] isEqualToString:@"SPCustomQuery"] &&
			![[[[self delegate] class] description] isEqualToString:@"SPQueryFavoriteManager"]){
			
			// Ensure that editing is permitted
			if (![[self delegate] tableView:self shouldEditTableColumn:[[self tableColumns] objectAtIndex:0] row:[self selectedRow]])
				return;

			// Trigger a cell edit
			[self editColumn:0 row:[self selectedRow] withEvent:nil select:YES];
			return;
		}
	}
	
	[super keyDown:theEvent];

}

- (void)setFont:(NSFont *)font;
{
	NSArray *tableColumns;
	NSUInteger columnIndex;

	tableColumns = [self tableColumns];
	columnIndex = [tableColumns count];
	while (columnIndex--)
		[[(NSTableColumn *)[tableColumns objectAtIndex:columnIndex] dataCell] setFont:font];
}

@end
