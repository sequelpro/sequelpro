//
//  $Id$
//
//  Convenience Methods.h
//  SPMySQLFramework
//
//  Created by Rowan Beentje (rowan.beent.je) on February 20, 2012
//  Copyright (c) 2012 Rowan Beentje. All rights reserved.
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
//  More info at <http://code.google.com/p/sequel-pro/>

#import "Convenience Methods.h"

@implementation SPMySQLResult (Convenience_Methods)

/**
 * Iterates over the result set, retrieving all the rows, and returns them
 * as an array.
 * The rows are in the default format for this instance, as controlled via
 * -setDefaultRowReturnType:.
 * Returns nil if there are no rows to return.
 */
- (NSArray *)getAllRows
{
	unsigned long long previousSeekPosition = currentRowIndex;

	NSMutableArray *rowsToReturn;

	// If the number of rows is known, pre-set the size; otherwise just create an array
	if (numberOfRows != NSNotFound) {
		rowsToReturn = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)numberOfRows];
	} else {
		rowsToReturn = [[NSMutableArray alloc] init];
	}

	// Loop through the rows in the instance-specified return format
	for (id eachRow in self) {
		[rowsToReturn addObject:eachRow];
	}

	// Seek to the previous position if appropriate
	if (previousSeekPosition) [self seekToRow:previousSeekPosition];

	// Instead of empty arrays, return nil if there are no rows.
	if (![rowsToReturn count]) return nil;

	return rowsToReturn;
}

@end
