//
//  $Id$
//
//  SPQueryConsoleDataSource.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on August 30, 2011
//  Copyright (c) 2011 Stuart Connolly. All rights reserved.
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

#import "SPQueryConsoleDataSource.h"
#import "SPConsoleMessage.h"

static NSUInteger SPMessageTruncateCharacterLength = 256;

@implementation SPQueryController (SPQueryConsoleDataSource)

/**
 * Table view delegate method. Returns the number of rows in the table veiw.
 */
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
#ifndef SP_REFACTOR
	return [messagesVisibleSet count];
#else
	return 0;
#endif
}

/**
 * Table view delegate method. Returns the specific object for the request column and row.
 */
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
#ifndef SP_REFACTOR
	NSString *returnValue = nil;
	
	id object = [[messagesVisibleSet objectAtIndex:row] valueForKey:[tableColumn identifier]];
	
	if ([[tableColumn identifier] isEqualToString:SPTableViewDateColumnID]) {
		
		returnValue = [dateFormatter stringFromDate:(NSDate *)object];
	}
	else {
		if ([(NSString *)object length] > SPMessageTruncateCharacterLength) {
			object = [NSString stringWithFormat:@"%@...", [object substringToIndex:SPMessageTruncateCharacterLength]];
		}
		
		returnValue = object;
	}
	
	NSMutableDictionary *stringAtributes = nil;
	
	if (consoleFont) {
		stringAtributes = [NSMutableDictionary dictionaryWithObject:consoleFont forKey:NSFontAttributeName];
	}
	
	// If this is an error message give it a red colour
	if ([(SPConsoleMessage *)[messagesVisibleSet objectAtIndex:row] isError]) {
		if (stringAtributes) {
			[stringAtributes setObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
		}
		else {
			stringAtributes = [NSMutableDictionary dictionaryWithObject:[NSColor redColor] forKey:NSForegroundColorAttributeName];
		}
	}
	
	return [[[NSAttributedString alloc] initWithString:returnValue attributes:stringAtributes] autorelease];
#else
	return nil;
#endif
}

@end
