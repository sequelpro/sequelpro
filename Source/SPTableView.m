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

@implementation SPTableView

/*
 * Right-click at row will select that row before ordering out the contextual menu
 * if not more than one row is selected
 */
- (NSMenu *)menuForEvent:(NSEvent *)event
{
	// If more than one row is selected only returns the default contextual menu
	if([self numberOfSelectedRows] > 1)
		return [self menu];
	
	// Right-click at a row will select that row before ordering out the context menu
	int row = [self rowAtPoint:[self convertPoint:[event locationInWindow] fromView:nil]];
	if(row >= 0 && row < [self numberOfRows]) {
		
		// Check for TablesList if right-click on header, then suppress context menu
		if([[[[self delegate] class] description] isEqualToString:@"TablesList"]) {
			if([NSArrayObjectAtIndex([[self delegate] valueForKeyPath:@"tableTypes"], row) intValue] == -1)
				return nil;
		}
		if([[[[self delegate] class] description] isEqualToString:@"SPQueryFavoriteManager"]) {
			if([NSArrayObjectAtIndex([[self delegate] valueForKeyPath:@"favoriteProperties"], row) intValue] == SP_FAVORITETYPE_HEADER)
				return nil;
		}
		
		[self selectRow:row byExtendingSelection:NO];
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
		if (![[[[self delegate] class] description] isEqualToString:@"CustomQuery"] &&
			![[[[self delegate] class] description] isEqualToString:@"SPQueryFavoriteManager"]){
			[self editColumn:0 row:[self selectedRow] withEvent:nil select:YES];
			return;
		}
	}
	
	[super keyDown:theEvent];

}

@end
