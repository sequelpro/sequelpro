//
//  $Id$
//
//  SPMySQLStreamingResult.m
//  SPMySQLFramework
//
//  Created by Rowan Beentje (rowan.beent.je) on February 18, 2012
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

#import "SPMySQLStreamingResult.h"
#import "SPMySQL Private APIs.h"


/**
 * This type of streaming result allows each row to be accessed on-demand; this can
 * be dangerous as it means a SELECT will tie up the server for longer, as for MyISAM
 * tables updates (and subsequent reads) must block while a SELECT is still running.
 * However this can be useful for certain processes such as working with very large
 * tables to keep memory usage low.
 */

@implementation SPMySQLStreamingResult

#pragma mark -

/**
 * Prevent SPMySQLStreamingResults from being init'd as SPMySQLResults.
 */
- (id)initWithMySQLResult:(void *)theResult stringEncoding:(NSStringEncoding)theStringEncoding
{
	[NSException raise:NSInternalInconsistencyException format:@"SPMySQLFullStreamingResults should not be init'd as SPMySQLResults; use initWithMySQLResult:stringEncoding:connection:withFullStreaming: instead."];
	return nil;
}

/**
 * Standard init method, constructing the SPMySQLStreamingResult around a MySQL
 * result pointer and the encoding to use when working with the data.
 * As opposed to SPMySQLResult, defaults to returning rows as arrays, as the result
 * sets are likely to be larger and processed in loops.
 */
- (id)initWithMySQLResult:(void *)theResult stringEncoding:(NSStringEncoding)theStringEncoding connection:(SPMySQLConnection *)theConnection
{

	// If no result set was passed in, return nil.
	if (!theResult) return nil;

	if ((self = [super initWithMySQLResult:theResult stringEncoding:theStringEncoding])) {
		parentConnection = theConnection;
		numberOfRows = NSNotFound;

		// Start with no rows downloaded
		downloadedRowCount = 0;
		dataDownloaded = NO;
		connectionUnlocked = NO;

		// Cache the isConnected selector and pointer for fast connection checks
		isConnectedSelector = @selector(isConnected);
		isConnectedPtr = [parentConnection methodForSelector:isConnectedSelector];

		// Default to returning rows as arrays
		defaultRowReturnType = SPMySQLResultRowAsArray;
	}

	return self;
}

/**
 * Deallocate the result and ensure the parent connection is unlocked for further use.
 */
- (void)dealloc
{

	// Ensure all data is processed and the parent connection is unlocked
	[self cancelResultLoad];

	// Throw an exception if in invalid state
	if (!connectionUnlocked) {
		[parentConnection _unlockConnection];
		[NSException raise:NSInternalInconsistencyException format:@"Parent connection remains locked after SPMySQLStreamingResult use"];
	}

	[super dealloc];
}

#pragma mark -
#pragma mark Result set information

/**
 * Override the return of the number of rows in the data set.  If this is used before the
 * data is fully downloaded, the number of results is still unknown (the server may still
 * be seeking/matching), so return NSNotFound; otherwise the number of rows is returned.
 */
- (unsigned long long)numberOfRows
{
	if (!dataDownloaded) return NSNotFound;

	return downloadedRowCount;
}

#pragma mark -
#pragma mark Data retrieval

/**
 * Override seeking behaviour: seeking cannot be used in streaming result sets.
 */
- (void)seekToRow:(unsigned long long)targetRow
{
	[NSException raise:NSInternalInconsistencyException format:@"Seeking is not supported in streaming SPMySQL result sets."];
}

/**
 * Override the convenience selectors so that forwarding works correctly.
 */
- (id)getRow
{
	return SPMySQLResultGetRow(self, SPMySQLResultRowAsDefault);
}
- (NSArray *)getRowAsArray
{
	return SPMySQLResultGetRow(self, SPMySQLResultRowAsArray);
}
- (NSDictionary *)getRowAsDictionary
{
	return SPMySQLResultGetRow(self, SPMySQLResultRowAsDictionary);
}

/**
 * Retrieve the next row in the result set, using the internal pointer, in the specified
 * return format.
 * If there are no rows remaining in the current iteration, returns nil.
 */
- (id)getRowAsType:(SPMySQLResultRowType)theType
{
	id theRow = nil;

	// Ensure that the connection is still up before performing a row fetch
	if ((*isConnectedPtr)(parentConnection, isConnectedSelector)) {

		// The core of result fetching in streaming mode is still based around mysql_fetch_row,
		// so use the super to perform normal processing.
		theRow = [super getRowAsType:theType];
	}

	// If no row was returned, the end of the result set has been reached.  Clear markers,
	// unlock the parent connection, and return nil.
	if (!theRow) {
		dataDownloaded = YES;
		[parentConnection _unlockConnection];
		connectionUnlocked = YES;
		return nil;
	}

	// Otherwise increment the data downloaded counter and return the row
	downloadedRowCount++;

	return theRow;
}

/*
 * Ensure the result set is fully processed and freed without any processing
 * This method ensures that the connection is unlocked.
 */
- (void)cancelResultLoad
{

	// If data has already been downloaded successfully, no further action is required
	if (dataDownloaded) return;

	MYSQL_ROW theRow;

	// Loop through all the rows and ensure the rows are fetched.
	while (1) {
		theRow = mysql_fetch_row(resultSet);

		// If no data was returned, we're at the end of the result set - return.
		if (theRow == NULL) {
			dataDownloaded = YES;
			if (!connectionUnlocked) {
				[parentConnection _unlockConnection];
				connectionUnlocked = YES;
			}
			return;
		}

		downloadedRowCount++;
	}
}

#pragma mark -
#pragma mark Data retrieval for fast enumeration

/**
 * Implement the fast enumeration endpoint.  Rows for fast enumeration are retrieved in
 * the instance default, as specified in setDefaultRowReturnType: or defaulting to
 * NSDictionary.  Full streaming mode - return one row at a time.
 */
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len
{

	// If all rows have been retrieved, return 0 to stop iteration.
	if (dataDownloaded) return 0;

	// If the MySQL row pointer does not match the requested state, throw an exception
	if (state->state != currentRowIndex) {
		[NSException raise:NSRangeException format:@"SPMySQLStreamingResult results can only be accessed linearly"];
	}

	// In full streaming mode return one row at a time.  Retrieve the row.
	id theRow = SPMySQLResultGetRow(self, SPMySQLResultRowAsDefault);

	// If nil was returned the end of the result resource has been reached
	if (!theRow) return 0;

	// Add the row to the result stack and update state
	stackbuf[0] = theRow;
	state->state += 1;
	state->itemsPtr = stackbuf;
	state->mutationsPtr = (unsigned long *)self;

	return 1;
}

@end
