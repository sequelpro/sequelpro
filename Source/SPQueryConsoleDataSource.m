//
//  SPQueryConsoleDataSource.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on August 30, 2011.
//  Copyright (c) 2011 Stuart Connolly. All rights reserved.
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

#import "SPQueryConsoleDataSource.h"
#import "SPConsoleMessage.h"

static NSUInteger SPMessageTruncateCharacterLength = 256;

@implementation SPQueryController (SPQueryConsoleDataSource)

/**
 * Table view delegate method. Returns the number of rows in the table veiw.
 */
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
#ifndef SP_CODA
	return [messagesVisibleSet count];
#else
	return 0;
#endif
}

/**
 * Table view delegate method. Returns the specific object for the requested column and row.
 */
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
#ifndef SP_CODA
	NSString *returnValue = nil;

	NSString *identifier = [tableColumn identifier];

	if (!identifier) return returnValue;
	
	id object = [[messagesVisibleSet objectAtIndex:row] valueForKey:identifier];
	
	if ([[tableColumn identifier] isEqualToString:SPTableViewDateColumnID]) {
		
		returnValue = [dateFormatter stringFromDate:(NSDate *)object];
	}
	else {
		if ([(NSString *)object length] > SPMessageTruncateCharacterLength) {
			object = [NSString stringWithFormat:@"%@...", [object substringToIndex:SPMessageTruncateCharacterLength]];
		}
		
		returnValue = object;
	}

	if (!returnValue) return returnValue;

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

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
	NSString *string = [self sqlStringForRowIndexes:rowIndexes];
	if([string length]) {
		[pboard declareTypes:@[NSStringPboardType] owner:self];
		return [pboard setString:string forType:NSStringPboardType];
	}
	
	return NO;
}

@end
