//
//  $Id$
//
//  SPMySQLFastStreamingResult.m
//  SPMySQLFramework
//
//  Created by Rowan Beentje (rowan.beent.je) on February 2, 2012
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

#import "SPMySQLFastStreamingResult.h"
#import "SPMySQL Private APIs.h"
#import "SPMySQLArrayAdditions.h"
#include <pthread.h>

static id NSNullPointer;

/**
 * This type of streaming result operates in a multithreaded fashion - a worker
 * thread is set up to download the results as fast as possible in the background,
 * while the results are made available via blocking (and so single-thread-compatible)
 * calls.  This provides the benefit of allowing a progress bar to be shown during
 * downloads, and threaded processing, but still has reasonable memory usage for the
 * downloaded result - and won't block the server.
 */

typedef struct st_spmysqlstreamingrowdata {
	char *data;
	unsigned long *dataLengths;
	struct st_spmysqlstreamingrowdata *nextRow;
} SPMySQLStreamingRowData;

@interface SPMySQLFastStreamingResult (Private_API)

- (void) _downloadAllData;

@end

#pragma mark -

@implementation SPMySQLFastStreamingResult

#pragma mark -

/**
 * In the one-off class initialisation, cache static variables
 */
+ (void)initialize
{

	// Cached NSNull singleton reference
	if (!NSNullPointer) NSNullPointer = [NSNull null];
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

	if ((self = [super initWithMySQLResult:theResult stringEncoding:theStringEncoding connection:theConnection])) {

		// Initialise the extra streaming result counts and tracking
		processedRowCount = 0;

		// Initialise the linked list pointers
		currentDataStoreEntry = NULL;
		lastDataStoreEntry = NULL;

		// Set up the linked list lock
		pthread_mutex_init(&dataLock, NULL);

		// Start the data download thread
		[NSThread detachNewThreadSelector:@selector(_downloadAllData) toTarget:self withObject:nil];
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

	// Destroy the linked list lock
	pthread_mutex_destroy(&dataLock);

	// Call dealloc on super to clean up everything else, and to throw an exception if
	// the parent connection hasn't been cleaned up correctly.
	[super dealloc];
}

#pragma mark -
#pragma mark Data retrieval

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
	NSUInteger copiedDataLength = 0;
	char *theRowData;
	unsigned long *fieldLengths;
	id theReturnData;

	// If the target type was unspecified, use the instance default
	if (theType == SPMySQLResultRowAsDefault) theType = defaultRowReturnType;

	// Set up the return data as appropriate
	if (theType == SPMySQLResultRowAsArray) {
		theReturnData = [NSMutableArray arrayWithCapacity:numberOfFields];
	} else {
		theReturnData = [NSMutableDictionary dictionaryWithCapacity:numberOfFields];
	}

	// Lock the data mutex for safe access of variables and counters
	pthread_mutex_lock(&dataLock);

	// Determine whether any data is available; if not, wait 1ms before trying again
	while (!dataDownloaded && processedRowCount == downloadedRowCount) {
		pthread_mutex_unlock(&dataLock);
		usleep(1000);
		pthread_mutex_lock(&dataLock);
	}

	// If all rows have been processed, the end of the result set has been reached; return nil.
	if (processedRowCount == downloadedRowCount) {
		pthread_mutex_unlock(&dataLock);
		return nil;
	}

	// Unlock the data mutex now checks are complete
	pthread_mutex_unlock(&dataLock);

	// Get a reference to the data for the current row; this is safe to do outside the lock
	// as the pointer won't change until markers are changed at the end of this process
	theRowData = currentDataStoreEntry->data;
	fieldLengths = currentDataStoreEntry->dataLengths;

	// Convert each of the cells in the row in turn
	unsigned long fieldLength;
	id cellData;
	char *rawCellData;
	for (NSUInteger i = 0; i < numberOfFields; i++) {
		fieldLength = fieldLengths[i];

		// If the length of this cell is NSNotFound, it's a null reference
		if (fieldLength == NSNotFound) {
			cellData = nil;

		// Otherwise grab a reference to that data using pointer arithmetic
		} else {
			rawCellData = theRowData + copiedDataLength;
			copiedDataLength += fieldLength;

			// Convert to the correct object type
			cellData = SPMySQLResultGetObject(self, rawCellData, fieldLength, fieldTypes[i], i);
		}

		// If object creation failed, display a null
		if (!cellData) cellData = NSNullPointer;

		// Add to the result array/dictionary
		if (theType == SPMySQLResultRowAsArray) {
			SPMySQLMutableArrayInsertObject(theReturnData, cellData, i);
		} else {
			[(NSMutableDictionary *)theReturnData setObject:cellData forKey:fieldNames[i]];
		}
	}

	// Get a reference to the current item
	SPMySQLStreamingRowData *previousDataStoreEntry = currentDataStoreEntry;

	// Lock the mutex before updating counters and linked lists
	pthread_mutex_lock(&dataLock);

	// Update the active-data pointer to the next item in the list (which may be NULL)
	currentDataStoreEntry = currentDataStoreEntry->nextRow;
	if (!currentDataStoreEntry) lastDataStoreEntry = NULL;

	// Increment the processed counter and row index
	processedRowCount++;
	currentRowIndex++;
	if (dataDownloaded && processedRowCount == downloadedRowCount) currentRowIndex = NSNotFound;

	// Unlock the mutex
	pthread_mutex_unlock(&dataLock);

	// Free the memory for the processed row
	free(previousDataStoreEntry->dataLengths);
	if (previousDataStoreEntry->data != NULL) free(previousDataStoreEntry->data);
	free(previousDataStoreEntry);

	return theReturnData;
}

/*
 * Ensure the result set is fully processed and freed without any processing
 * This method ensures that the connection is unlocked.
 */
- (void)cancelResultLoad
{

	// If data has already been downloaded successfully, no further action is required
	if (dataDownloaded && processedRowCount == downloadedRowCount) return;

	// Loop until all data is fetched and freed
	while (1) {

		// Check to see whether we need to wait for the data to be available
		// - if so, wait 1ms before checking again
		while (!dataDownloaded && processedRowCount == downloadedRowCount) usleep(1000);

		// If all rows have been processed, we're at the end of the result set - return
		if (processedRowCount == downloadedRowCount) {

			// We don't need to unlock the connection because the data loading thread
			// has already taken care of that
			return;
		}

		// Mark the row entry as processed without performing any actions
		pthread_mutex_lock(&dataLock);
		SPMySQLStreamingRowData *previousDataStoreEntry = currentDataStoreEntry;

		// Update the active-data pointer to the next item in the list (which may be NULL)
		currentDataStoreEntry = currentDataStoreEntry->nextRow;
		if (!currentDataStoreEntry) lastDataStoreEntry = NULL;

		processedRowCount++;
		currentRowIndex++;
		if (dataDownloaded && processedRowCount == downloadedRowCount) currentRowIndex = NSNotFound;

		// Unlock the mutex
		pthread_mutex_unlock(&dataLock);

		// Free the memory for the processed row
		free(previousDataStoreEntry->dataLengths);
		if (previousDataStoreEntry->data != NULL) free(previousDataStoreEntry->data);
		free(previousDataStoreEntry);
	}
}

#pragma mark -
#pragma mark Data retrieval for fast enumeration

/**
 * Implement the fast enumeration endpoint.  Rows for fast enumeration are retrieved in
 * the instance default, as specified in setDefaultRowReturnType: or defaulting to
 * NSDictionary.
 */
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len
{

	// To avoid lock issues, return one row at a time.
	id nextRow = SPMySQLResultGetRow(self, SPMySQLResultRowAsDefault);

	// If no row was available, return 0 to stop iteration.
	if (!nextRow) return 0;

	// Otherwise, add the item to the buffer and return the appropriate state.
	stackbuf[0] = nextRow;

	state->state += 1;
	state->itemsPtr = stackbuf;
	state->mutationsPtr = (unsigned long *)self;

	return 1;
}

@end

#pragma mark -
#pragma mark Result set internals

@implementation SPMySQLFastStreamingResult (Private_API)

/**
 * Used internally to download results in a background thread
 */
- (void)_downloadAllData
{
	NSAutoreleasePool *downloadPool = [[NSAutoreleasePool alloc] init];
	MYSQL_ROW theRow;
	unsigned long *fieldLengths;
	NSUInteger i, dataCopiedLength, rowDataLength;
	SPMySQLStreamingRowData *newRowStore;

	size_t sizeOfStreamingRowData = sizeof(SPMySQLStreamingRowData);
	size_t sizeOfDataLengths = (size_t)(sizeof(unsigned long) * numberOfFields);
	size_t sizeOfChar = sizeof(char);

	// Loop through the rows until the end of the data is reached - indicated via a NULL
	while (
		(*isConnectedPtr)(parentConnection, isConnectedSelector)
		&& (theRow = mysql_fetch_row(resultSet))
	)
	{

		// Retrieve the lengths of the returned data
		fieldLengths = mysql_fetch_lengths(resultSet);
		rowDataLength = 0;
		dataCopiedLength = 0;
		for (i = 0; i < numberOfFields; i++) {
			rowDataLength += fieldLengths[i];
		}

		// Initialise memory for the row and set a NULL pointer for the next item
		newRowStore = malloc(sizeOfStreamingRowData);
		newRowStore->nextRow = NULL;

		// Set up the row data store - a char* - and copy in the data if there is any.
		newRowStore->data = malloc(sizeOfChar * rowDataLength);
		for (i = 0; i < numberOfFields; i++) {
			if (theRow[i] != NULL) {
				memcpy(newRowStore->data+dataCopiedLength, theRow[i], fieldLengths[i]);
				dataCopiedLength += fieldLengths[i];
			} else {
				fieldLengths[i] = NSNotFound;
			}
		}

		// Set up the memory for, and copy in, the field lengths
		newRowStore->dataLengths = memcpy(malloc(sizeOfDataLengths), fieldLengths, sizeOfDataLengths);

		// Lock the data mutex
		pthread_mutex_lock(&dataLock);

		// Add the newly allocated row to end of the storage linked list
		if (lastDataStoreEntry) {
			lastDataStoreEntry->nextRow = newRowStore;
		}
		lastDataStoreEntry = newRowStore;
		if (!currentDataStoreEntry) currentDataStoreEntry = newRowStore;

		// Update the downloaded row count
		downloadedRowCount++;

		// Unlock the mutex
		pthread_mutex_unlock(&dataLock);
	}

	// Update the connection's error statuses to reflect any errors during the content download
	[parentConnection _updateLastErrorID:NSNotFound];
	[parentConnection _updateLastErrorMessage:nil];	

	// Unlock the parent connection now all data has been retrieved
    [parentConnection _unlockConnection];
    connectionUnlocked = YES;

	dataDownloaded = YES;
	[downloadPool drain];
}

@end
