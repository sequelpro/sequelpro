//
//  SPMySQLStreamingResultStore.m
//  SPMySQLFramework
//
//  Created by Rowan Beentje (rowan.beent.je) on May 26, 2013
//  Copyright (c) 2013 Rowan Beentje. All rights reserved.
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

#import "SPMySQLStreamingResultStore.h"
#import "SPMySQL Private APIs.h"
#import "SPMySQLArrayAdditions.h"
#include <pthread.h>

static id NSNullPointer;

typedef enum {
	SPMySQLStoreMetadataAsChar  = sizeof(unsigned char),
	SPMySQLStoreMetadataAsShort = sizeof(unsigned short),
	SPMySQLStoreMetadataAsLong  = sizeof(unsigned long)
} SPMySQLResultStoreRowMetadataType;

/**
 * This type of result provides its own storage for the MySQL result set, converting
 * rows or cells on-demand to Objective-C types as they are requested.  The results
 * are fetched in streaming fashion after the result store object is returned, with
 * a background thread set up to download the results as fast as possible.  Delegate
 * methods can be used to display a progress bar during downloads as rows are retrieved.
 */

@interface SPMySQLStreamingResultStore (PrivateAPI)

- (void) _downloadAllData;
- (void) _ensureCapacityForAdditionalRowCount:(NSUInteger)numExtraRows;
- (void) _increaseCapacity;
- (NSUInteger) _rowCapacity;
- (SPMySQLStreamingResultStoreRowData **) _transferResultStoreData;

@end

#pragma mark -

@implementation SPMySQLStreamingResultStore

@synthesize delegate;

static inline void SPMySQLStreamingResultStoreEnsureCapacityForAdditionalRowCount(SPMySQLStreamingResultStore* self, NSUInteger numExtraRows)
{
	typedef void (*SPMSRSEnsureCapacityMethodPtr)(SPMySQLStreamingResultStore*, SEL, NSUInteger);
	static SPMSRSEnsureCapacityMethodPtr SPMSRSEnsureCapacity;
	if (!SPMSRSEnsureCapacity) {
		SPMSRSEnsureCapacity = (SPMSRSEnsureCapacityMethodPtr)[self methodForSelector:@selector(_ensureCapacityForAdditionalRowCount:)];
	}
	SPMSRSEnsureCapacity(self, @selector(_ensureCapacityForAdditionalRowCount:), numExtraRows);
}

static inline void SPMySQLStreamingResultStoreFreeRowData(SPMySQLStreamingResultStoreRowData* aRow)
{
	if (aRow == NULL) {
		return;
	}

	free(aRow);
}


#pragma mark - Setup and teardown

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
 * The download of results is not started at once - instead, it must be triggered manually
 * via -startDownload, which allows assignment of a result set to replace before use.
 */
- (id)initWithMySQLResult:(void *)theResult stringEncoding:(NSStringEncoding)theStringEncoding connection:(SPMySQLConnection *)theConnection
{

	// If no result set was passed in, return nil.
	if (!theResult) return nil;

	if ((self = [super initWithMySQLResult:theResult stringEncoding:theStringEncoding connection:theConnection])) {

		// Initialise the streaming result counts and tracking
		numberOfRows = 0;
		rowDownloadIterator = 0;
		loadStarted = NO;
		loadCancelled = NO;
		rowCapacity = 0;
		dataStorage = NULL;
		storageMallocZone = NULL;
		delegate = nil;

		// Set up the storage lock
		pthread_mutex_init(&dataLock, NULL);
	}

	return self;
}

/**
 * Prime the result set with an existing result store.  This is typically used when reloading a
 * result set; re-using the existing data store allows the data to be updated without blanking
 * the visual display first, providing a more consistent experience.
 */
- (void)replaceExistingResultStore:(SPMySQLStreamingResultStore *)previousResultStore
{
	if (dataStorage != NULL) {
		[NSException raise:NSInternalInconsistencyException format:@"Data storage has already been assigned or created"];
	}

	pthread_mutex_lock(&dataLock);

	// Talk to the previous result store, claiming its malloc zone and data
	numberOfRows = [previousResultStore numberOfRows];
	rowCapacity = [previousResultStore _rowCapacity];
	dataStorage = [previousResultStore _transferResultStoreData];
	storageMallocZone = malloc_zone_from_ptr(dataStorage);

	// If the new column count is higher than the old column count, the old data needs
	// to have null data added to the end of it to prevent problems while loading.
	NSUInteger previousNumberOfFields = [previousResultStore numberOfFields];
	if (numberOfFields > previousNumberOfFields) {
		unsigned long long i;
		NSUInteger j;
		SPMySQLStreamingResultStoreRowData *oldRow, *newRow;

		size_t sizeOfMetadata, newMetadataLength, newDataOffset, oldMetadataLength, oldDataOffset;
		unsigned long dataLength;

		for (i = 0; i < numberOfRows; i++) {
			oldRow = dataStorage[i];
			if (oldRow != NULL) {

				// Get the metadata size for this row
				sizeOfMetadata = oldRow[0];

				// Derive some base sizes
				newMetadataLength = (size_t)(sizeOfMetadata * numberOfFields);
				newDataOffset = (size_t)(1 + (sizeOfMetadata + sizeof(BOOL)) * numberOfFields);
				oldMetadataLength = (size_t)(sizeOfMetadata * previousNumberOfFields);
				oldDataOffset = (size_t)(1 + (sizeOfMetadata + sizeof(BOOL)) * previousNumberOfFields);

				// Manually unroll the logic for the different cases.  This is messy, but
				// the large memory savings for small rows make this extra work worth it.
				switch (sizeOfMetadata) {
					case SPMySQLStoreMetadataAsChar:

						// The length of the data is stored in the last end-position slot
						dataLength = ((unsigned char *)(oldRow + 1))[previousNumberOfFields - 1];
						break;

					case SPMySQLStoreMetadataAsShort:
						dataLength = ((unsigned short *)(oldRow + 1))[previousNumberOfFields - 1];
						break;
					case SPMySQLStoreMetadataAsLong:
					default:
						dataLength = ((unsigned long *)(oldRow + 1))[previousNumberOfFields - 1];
						break;
				}

				// The overall new size for the row is the new size of the metadata
				// (positions and null indicators), plus the old size of the data.
				dataStorage[i] = malloc_zone_malloc(storageMallocZone, newDataOffset + dataLength);
				newRow = dataStorage[i];

				// Copy the old row's metadata
				memcpy(newRow, oldRow, 1 + oldMetadataLength);

				// Copy the null status data
				memcpy(newRow + 1 + newMetadataLength, oldRow + 1 + oldMetadataLength, (size_t)(sizeof(BOOL) * previousNumberOfFields));

				// Copy the cell data to the new end of the memory area
				memcpy(newRow + newDataOffset, oldRow + oldDataOffset, dataLength);

				// Change the row pointers to point to the start of the metadata
				oldRow = oldRow + 1;
				newRow = newRow + 1;

				switch (sizeOfMetadata) {
					case SPMySQLStoreMetadataAsLong:

						// Add the new metadata and null statuses
						for (j = previousNumberOfFields; j < numberOfFields; j++) {
							((unsigned long *)newRow)[j] = ((unsigned long *)oldRow)[j - 1];
							((BOOL *)(newRow + newMetadataLength))[j] = YES;
						}
						break;
					case SPMySQLStoreMetadataAsShort:;
						for (j = previousNumberOfFields; j < numberOfFields; j++) {
							((unsigned short *)newRow)[j] = ((unsigned short *)oldRow)[j - 1];
							((BOOL *)(newRow + newMetadataLength))[j] = YES;
						}
						break;
					case SPMySQLStoreMetadataAsChar:;
						for (j = previousNumberOfFields; j < numberOfFields; j++) {
							((unsigned char *)newRow)[j] = ((unsigned char *)oldRow)[j - 1];
							((BOOL *)(newRow + newMetadataLength))[j] = YES;
						}
						break;
				}

				// Free the entire old row, correcting the row pointer tweak
				free(oldRow - 1);
			}
		}
	}

	pthread_mutex_unlock(&dataLock);
}

/**
 * Start downloading the result data.
 */
- (void)startDownload
{
	if (loadStarted) {
		[NSException raise:NSInternalInconsistencyException format:@"Data download has already been started"];
	}

	// If not already assigned, initialise the data storage, initially with space for 100 rows
	if (dataStorage == NULL) {

		// Set up the malloc zone
		storageMallocZone = malloc_create_zone(64 * 1024, 0);
		malloc_set_zone_name(storageMallocZone, "SPMySQLStreamingResultStore_Heap");

		rowCapacity = 100;
		dataStorage = malloc_zone_malloc(storageMallocZone, rowCapacity * sizeof(SPMySQLStreamingResultStoreRowData *));
	}

	loadStarted = YES;
	[NSThread detachNewThreadSelector:@selector(_downloadAllData) toTarget:self withObject:nil];
}

/**
 * Deallocate the result and ensure the parent connection is unlocked for further use.
 */
- (void)dealloc
{

	// Ensure all data is processed and the parent connection is unlocked
	[self cancelResultLoad];

	// Free all the data, by destroying the parent zone
	if (storageMallocZone) {
		malloc_destroy_zone(storageMallocZone);
	}

	// Destroy the linked list lock
	pthread_mutex_destroy(&dataLock);

	// Call dealloc on super to clean up everything else, and to throw an exception if
	// the parent connection hasn't been cleaned up correctly.
	[super dealloc];
}

#pragma mark - Result set information

/**
 * Override the return of the number of rows in the data set.  If this is used before the
 * data is fully downloaded, the number of results is still unknown (the server may still
 * be seeking/matching), but the rows downloaded to date is returned; otherwise the number
 * of rows is returned.
 */
- (unsigned long long)numberOfRows
{
	if (!dataDownloaded) {
		return rowDownloadIterator;
	}

	return numberOfRows;
}

#pragma mark - Data retrieval

/**
 * Return a mutable array containing the data for a specified row.
 */
- (NSMutableArray *)rowContentsAtIndex:(NSUInteger)rowIndex
{

	// Throw an exception if the index is out of bounds
	if (rowIndex >= numberOfRows) {
		[NSException raise:NSRangeException format:@"Requested storage index (%llu) beyond bounds (%llu)", (unsigned long long)rowIndex, (unsigned long long)numberOfRows];
	}

	// If the row store is a null pointer, the row is a dummy row.
	if (dataStorage[rowIndex] == NULL) {
		return nil;
	}

	// Construct a mutable array and add all the cells in the row
	NSMutableArray *rowArray = [NSMutableArray arrayWithCapacity:numberOfFields];
	for (NSUInteger columnIndex = 0; columnIndex < numberOfFields; columnIndex++) {
		CFArrayAppendValue((CFMutableArrayRef)rowArray, SPMySQLResultStoreObjectAtRowAndColumn(self, rowIndex, columnIndex));
	}

	return rowArray;
}

/**
 * Return the data at a specified row and column index.
 */
- (id)cellDataAtRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex
{

	// Wrap the preview method, passing in a length limit of NSNotFound
	return SPMySQLResultStorePreviewAtRowAndColumn(self, rowIndex, columnIndex, NSNotFound);
}

/**
 * Return the data at a specified row and column index.  If a preview length is supplied,
 * the cell data will be checked, and if longer, will be shortened to around that length,
 * although multibyte encodings will show some variation.
 */
- (id)cellPreviewAtRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex previewLength:(NSUInteger)previewLength
{
	// Throw an exception if the row or column index is out of bounds
	if (rowIndex >= numberOfRows || columnIndex >= numberOfFields) {
		[NSException raise:NSRangeException format:@"Requested storage index (row %llu, col %llu) beyond bounds (%llu, %llu)", (unsigned long long)rowIndex, (unsigned long long)columnIndex, (unsigned long long)numberOfRows, (unsigned long long)numberOfFields];
	}

	id cellData = nil;
	char *rawCellDataStart;
	SPMySQLStreamingResultStoreRowData *rowData = dataStorage[rowIndex];

	// A null pointer for the row indicates a dummy entry
	if (rowData == NULL) {
		return nil;
	}

	unsigned long dataStart, dataLength;
	size_t sizeOfMetadata;

	// Get the metadata size for this row and adjust the data pointer past the indicator
	sizeOfMetadata = rowData[0];
	rowData = rowData + 1;

	static size_t sizeOfNullRecord = sizeof(BOOL);

	// Retrieve the data positions within the stored data.  Manually unroll the logic for
	// the different data size cases; again, this is messy, but the large memory savings for
	// small rows make this extra work worth it.
	if (columnIndex == 0) {
		dataStart = 0;
		switch (sizeOfMetadata) {
			case SPMySQLStoreMetadataAsChar:
				dataLength = ((unsigned char *)rowData)[columnIndex];
				break;
			case SPMySQLStoreMetadataAsShort:
				dataLength = ((unsigned short *)rowData)[columnIndex];
				break;
			case SPMySQLStoreMetadataAsLong:
			default:
				dataLength = ((unsigned long *)rowData)[columnIndex];
				break;
		}
	} else {
		switch (sizeOfMetadata) {
			case SPMySQLStoreMetadataAsChar:
				dataStart = ((unsigned char *)rowData)[columnIndex - 1];
				dataLength = ((unsigned char *)rowData)[columnIndex] - dataStart;
				break;
			case SPMySQLStoreMetadataAsShort:
				dataStart = ((unsigned short *)rowData)[columnIndex - 1];
				dataLength = ((unsigned short *)rowData)[columnIndex] - dataStart;
				break;
			case SPMySQLStoreMetadataAsLong:
			default:
				dataStart = ((unsigned long *)rowData)[columnIndex - 1];
				dataLength = ((unsigned long *)rowData)[columnIndex] - dataStart;
				break;
		}

	}

	// If the data length is empty, check whether the cell is null and return null if so
	if (((BOOL *)(rowData + (sizeOfMetadata * numberOfFields)))[columnIndex]) {
		return NSNullPointer;
	}

	// Get a reference to the start of the cell data
	rawCellDataStart = rowData + ((sizeOfMetadata + sizeOfNullRecord) * numberOfFields) + dataStart;

	// Attempt to convert to the correct native object type, which will result in nil on error/invalidity
	cellData = SPMySQLResultGetObject(self, rawCellDataStart, dataLength, columnIndex, previewLength);

	// If object creation failed, use a null
	if (!cellData) {
		cellData = NSNullPointer;
	}

	return cellData;
}

/**
 * Returns whether the data at a specified row and column index is NULL.
 */
- (BOOL)cellIsNullAtRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex
{
	// Throw an exception if the row or column index is out of bounds
	if (rowIndex >= numberOfRows || columnIndex >= numberOfFields) {
		[NSException raise:NSRangeException format:@"Requested storage index (row %llu, col %llu) beyond bounds (%llu, %llu)", (unsigned long long)rowIndex, (unsigned long long)columnIndex, (unsigned long long)numberOfRows, (unsigned long long)numberOfFields];
	}

	SPMySQLStreamingResultStoreRowData *rowData = dataStorage[rowIndex];

	// A null pointer for the row indicates a dummy entry
	if (rowData == NULL) {
		return NO;
	}

	size_t sizeOfMetadata;

	// Get the metadata size for this row and adjust the data pointer past the indicator
	sizeOfMetadata = rowData[0];
	rowData = rowData + 1;

	// Check whether the cell is null
	return (((BOOL *)(rowData + (sizeOfMetadata * numberOfFields)))[columnIndex]);

}

#pragma mark - Data retrieval overrides

/**
 * Override the standard fetch and convenience selectors to indicate the difference in use
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
- (id)getRowAsType:(SPMySQLResultRowType)theType
{
	[NSException raise:NSInternalInconsistencyException format:@"Streaming SPMySQL result store sets should be used directly as result stores."];
	return nil;
}

/*
 * Ensure the result set is fully processed and freed without any processing
 * This method ensures that the connection is unlocked.
 */
- (void)cancelResultLoad
{

	// Track that loading has been cancelled, allowing faster result download without processing
	loadCancelled = YES;

	if (!loadStarted) {
		[self startDownload];
	}

	// Loop until all data is processed, using a usleep (migrate to pthread condition variable?).
	// This waits on the data download thread (see _downloadAllData) to fetch all rows from the
	// server result set to avoid MySQL issues.
	while (!dataDownloaded) {
		usleep(1000);
	}
}

#pragma mark - Data retrieval for fast enumeration

/**
 * Implement the fast enumeration endpoint.  Rows for fast enumeration are retrieved in
 * as NSArrays.
 * Note that rows are currently retrieved individually to avoid mutation and locking issues,
 * although this could be improved on.
 */
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len
{
	NSMutableArray *theRow = SPMySQLResultStoreGetRow(self, state->state);

	// If no row was available, return 0 to stop iteration.
	if (!theRow) return 0;

	// Otherwise, add the item to the buffer and return the appropriate state.
	stackbuf[0] = theRow;

	state->state += 1;
	state->itemsPtr = stackbuf;
	state->mutationsPtr = (unsigned long *)self;

	return 1;
}

#pragma mark - Addition of placeholder rows and deletion of rows

/**
 * Add a placeholder row to the end of the result set, comprising of a pointer
 * to NULL.  This is to allow classes wrapping the result store to provide
 * editing capabilities before saving rows directly back to MySQL.
 */
- (void) addDummyRow
{

	// Currently only support editing after loading is finished; thi could be addressed by checking rowDownloadIterator vs numberOfRows etc
	if (!dataDownloaded) {
		[NSException raise:NSInternalInconsistencyException format:@"Streaming SPMySQL result editing is currently only supported once loading is complete."];
	}

	// Lock the data mutex
	pthread_mutex_lock(&dataLock);

	// Ensure that sufficient capacity is available
	SPMySQLStreamingResultStoreEnsureCapacityForAdditionalRowCount(self, 1);

	// Add a dummy entry to the data store
	dataStorage[numberOfRows] = NULL;
	numberOfRows++;

	// Unlock the mutex
	pthread_mutex_unlock(&dataLock);
}

/**
 * Insert a placeholder row into the result set at the specified index, comprising
 * of a pointer to NULL.  This is to allow classes wrapping the result store to
 * provide editing capabilities before saving rows directly back to MySQL.
 */
- (void) insertDummyRowAtIndex:(NSUInteger)anIndex
{
	// Throw an exception if the index is out of bounds
	if (anIndex > numberOfRows) {
		[NSException raise:NSRangeException format:@"Requested storage index (%llu) beyond bounds (%llu)", (unsigned long long)anIndex, (unsigned long long)numberOfRows];
	}

	// Currently only support editing after loading is finished; this could be addressed by checking rowDownloadIterator vs numberOfRows etc
	if (!dataDownloaded) {
		[NSException raise:NSInternalInconsistencyException format:@"Streaming SPMySQL result editing is currently only supported once loading is complete."];
	}

	// If "inserting" at the end of the array just add a row
	if (anIndex == numberOfRows) {
		return [self addDummyRow];
	}

	// Lock the data mutex
	pthread_mutex_lock(&dataLock);

	// Ensure that sufficient capacity is available to hold all the rows
	SPMySQLStreamingResultStoreEnsureCapacityForAdditionalRowCount(self, 1);

	// Reindex the specified index, and all subsequent indices, to create a gap
	size_t pointerSize = sizeof(SPMySQLStreamingResultStoreRowData *);
	memmove(dataStorage + anIndex + 1, dataStorage + anIndex, (numberOfRows - anIndex) * pointerSize);

	// Add a null pointer at the specified location
	dataStorage[anIndex] = NULL;
	numberOfRows++;

	// Unlock the mutex
	pthread_mutex_unlock(&dataLock);
}

/**
 * Delete a row at the specified index from the result set.  This allows the program
 * to remove or reorder rows without having to reload the entire result set from the
 * server.
 */
- (void) removeRowAtIndex:(NSUInteger)anIndex
{

	// Throw an exception if the index is out of bounds
	if (anIndex > numberOfRows) {
		[NSException raise:NSRangeException format:@"Requested storage index (%llu) beyond bounds (%llu)", (unsigned long long)anIndex, (unsigned long long)numberOfRows];
	}

	// Lock the data mutex
	pthread_mutex_lock(&dataLock);

	// Free the row data
	SPMySQLStreamingResultStoreFreeRowData(dataStorage[anIndex]);
	numberOfRows--;

	// Renumber all subsequent indices to fill the gap
	size_t pointerSize = sizeof(SPMySQLStreamingResultStoreRowData *);
	memmove(dataStorage + anIndex, dataStorage + anIndex + 1, (numberOfRows - anIndex) * pointerSize);

	// Unlock the mutex
	pthread_mutex_unlock(&dataLock);
}

/**
 * Delete a set of rows at the specified result index range from the result set.  This
 * allows the program to remove or reorder rows without having to reload the entire result
 * set from the server.
 */
- (void) removeRowsInRange:(NSRange)rangeToRemove
{

	// Throw an exception if the range is out of bounds
	if (NSMaxRange(rangeToRemove) > numberOfRows) {
		[NSException raise:NSRangeException format:@"Requested storage index (%llu) beyond bounds (%llu)", (unsigned long long)(NSMaxRange(rangeToRemove)), (unsigned long long)numberOfRows];
	}

	// Lock the data mutex
	pthread_mutex_lock(&dataLock);

	// Free rows in the range
	NSUInteger i;
	for (i = rangeToRemove.location; i < NSMaxRange(rangeToRemove); i++) {
		SPMySQLStreamingResultStoreFreeRowData(dataStorage[i]);
	}
	numberOfRows -= rangeToRemove.length;

	// Renumber all subsequent indices to fill the gap
	size_t pointerSize = sizeof(SPMySQLStreamingResultStoreRowData *);
	memmove(dataStorage + rangeToRemove.location, dataStorage + NSMaxRange(rangeToRemove), (numberOfRows - rangeToRemove.location) * pointerSize);

	// Unlock the mutex
	pthread_mutex_unlock(&dataLock);
}

/**
 * Clear the result set, allowing truncation of the result set without needing an extra query
 * to return an empty set from the server.
 */
- (void) removeAllRows
{

	// Lock the data mutex
	pthread_mutex_lock(&dataLock);

	// Free all the data
	while (numberOfRows > 0) {
		SPMySQLStreamingResultStoreFreeRowData(dataStorage[--numberOfRows]);
	}

	// Unlock the mutex
	pthread_mutex_unlock(&dataLock);
}

@end

#pragma mark - Result set internals

@implementation SPMySQLStreamingResultStore (PrivateAPI)

/**
 * Used internally to download results in a background thread, downloading
 * the entire result set as MySQL data (and data lengths) to the internal
 * storage.
 */
- (void)_downloadAllData
{
	NSAutoreleasePool *downloadPool = [[NSAutoreleasePool alloc] init];
	MYSQL_ROW theRow;
	unsigned long *fieldLengths;
	NSUInteger i, dataCopiedLength, rowDataLength;
	SPMySQLStreamingResultStoreRowData *newRowStore;

	[[NSThread currentThread] setName:@"SPMySQLStreamingResultStore data download thread"];

	size_t sizeOfMetadata, lengthOfMetadata;
	size_t lengthOfNullRecords = (size_t)(sizeof(BOOL) * numberOfFields);
	size_t sizeOfChar = sizeof(char);

	// Loop through the rows until the end of the data is reached - indicated via a NULL
	while (
		   (*isConnectedPtr)(parentConnection, isConnectedSelector)
		   && (theRow = mysql_fetch_row(resultSet))
		   )
	{

		// If the load has been cancelled, skip any processing - we're only interested
		// in ensuring that mysql_fetch_row is called for all rows.
		if (loadCancelled) {
			continue;
		}

		// The row store is a single block of memory.  It's made up of four blocks of data:
		// Firstly, a single char containing the type of data used to store positions.
		// Secondly, a series of those types recording the *end position* of each field
		// Thirdly, a series of BOOLs recording whether the fields are NULLS - which can't just be from length
		// Finally, a char sequence comprising the actual cell data, which can be looked up by position/length.

		// Retrieve the lengths of the returned data, and calculate the overall length of data
		fieldLengths = mysql_fetch_lengths(resultSet);
		rowDataLength = 0;
		for (i = 0; i < numberOfFields; i++) {
			rowDataLength += fieldLengths[i];
		}

		// Depending on the length of the row, vary the metadata size appropriately.  This
		// makes defining the data processing much lengthier, but is worth it to reduce the
		// overhead for small rows.
		if (rowDataLength <= UCHAR_MAX) {
			sizeOfMetadata = SPMySQLStoreMetadataAsChar;
		} else if (rowDataLength <= USHRT_MAX) {
			sizeOfMetadata = SPMySQLStoreMetadataAsShort;
		} else {
			sizeOfMetadata = SPMySQLStoreMetadataAsLong;
		}
		lengthOfMetadata = sizeOfMetadata * numberOfFields;

		// Allocate the memory for the row and set the type marker
		newRowStore = malloc_zone_malloc(storageMallocZone, 1 + lengthOfMetadata + lengthOfNullRecords + (rowDataLength * sizeOfChar));
		newRowStore[0] = sizeOfMetadata;

		// Set the data end positions.  Manually unroll the logic for the different cases; messy
		// but again worth the large memory savings for smaller rows
		rowDataLength = 0;
		switch (sizeOfMetadata) {
			case SPMySQLStoreMetadataAsLong:
				for (i = 0; i < numberOfFields; i++) {
					rowDataLength += fieldLengths[i];
					((unsigned long *)(newRowStore + 1))[i] = rowDataLength;
					((BOOL *)(newRowStore + 1 + lengthOfMetadata))[i] = (theRow[i] == NULL);
				}
				break;
			case SPMySQLStoreMetadataAsShort:
				for (i = 0; i < numberOfFields; i++) {
					rowDataLength += fieldLengths[i];
					((unsigned short *)(newRowStore + 1))[i] = rowDataLength;
					((BOOL *)(newRowStore + 1 + lengthOfMetadata))[i] = (theRow[i] == NULL);
				}
				break;
			case SPMySQLStoreMetadataAsChar:
				for (i = 0; i < numberOfFields; i++) {
					rowDataLength += fieldLengths[i];
					((unsigned char *)(newRowStore + 1))[i] = rowDataLength;
					((BOOL *)(newRowStore + 1 + lengthOfMetadata))[i] = (theRow[i] == NULL);
				}
				break;
		}

		// If the row has content, copy it in
		if (rowDataLength) {
			dataCopiedLength = 1 + lengthOfMetadata + lengthOfNullRecords;
			for (i = 0; i < numberOfFields; i++) {
				if (theRow[i] != NULL) {
					memcpy(newRowStore + dataCopiedLength, theRow[i], fieldLengths[i]);
					dataCopiedLength += fieldLengths[i];
				}
			}
		}

		// Lock the data mutex
		pthread_mutex_lock(&dataLock);

		// Ensure that sufficient capacity is available
		SPMySQLStreamingResultStoreEnsureCapacityForAdditionalRowCount(self, 1);

		// Add the newly allocated row to the storage
		if (rowDownloadIterator < numberOfRows) {
			SPMySQLStreamingResultStoreFreeRowData(dataStorage[rowDownloadIterator]);
		}
		dataStorage[rowDownloadIterator] = newRowStore;
		rowDownloadIterator++;

		// Update the total row count if exceeded
		if (rowDownloadIterator > numberOfRows) {
			numberOfRows++;
		}

		// Unlock the mutex
		pthread_mutex_unlock(&dataLock);
	}

	// Update the total number of rows in the result set now download
	// is complete, freeing extra rows from a previous result set
	if (numberOfRows > rowDownloadIterator) {
		pthread_mutex_lock(&dataLock);
		while (numberOfRows > rowDownloadIterator) {
			SPMySQLStreamingResultStoreFreeRowData(dataStorage[--numberOfRows]);
		}
		pthread_mutex_unlock(&dataLock);
	}

	// Update the connection's error statuses to reflect any errors during the content download
	[parentConnection _updateLastErrorInfos];

	// Unlock the parent connection now all data has been retrieved
	[parentConnection _unlockConnection];
	connectionUnlocked = YES;

	// If the connection query may have been cancelled with a query kill, double-check connection
	if ([parentConnection lastQueryWasCancelled] && [parentConnection serverMajorVersion] < 5) {
		[parentConnection checkConnection];
	}

	dataDownloaded = YES;

	// Inform the delegate the download was completed
	if ([delegate respondsToSelector:@selector(resultStoreDidFinishLoadingData:)]) {
		[delegate resultStoreDidFinishLoadingData:self];
	}

	[downloadPool drain];
}

/**
 * Private method to ensure the storage array always has sufficient capacity
 * to store any additional rows required.
 */
- (void) _ensureCapacityForAdditionalRowCount:(NSUInteger)numExtraRows
{
	while (numberOfRows + numExtraRows > rowCapacity) {
		[self _increaseCapacity];
	}
}

/**
 * Private method to increase the storage available for the array;
 * currently doubles the capacity as boundaries are reached.
 */
- (void) _increaseCapacity
{
	rowCapacity *= 2;
	dataStorage = malloc_zone_realloc(storageMallocZone, dataStorage, rowCapacity * sizeof(SPMySQLStreamingResultStoreRowData *));
}

/**
 * Private method to return the internal result store capacity.
 */
- (NSUInteger) _rowCapacity
{
	return rowCapacity;
}

/**
 * Private method to return the internal result store, relinquishing
 * ownership to allow transfer of data.  Note that the returned result
 * store will be allocated memory which will need freeing.
 */
- (SPMySQLStreamingResultStoreRowData **) _transferResultStoreData
{
	if (!dataDownloaded) {
		[NSException raise:NSInternalInconsistencyException format:@"Attempted to transfer result store data before loading completed"];
	}

	SPMySQLStreamingResultStoreRowData **previousData = dataStorage;

	pthread_mutex_lock(&dataLock);
	dataStorage = NULL;
	storageMallocZone = NULL;
	rowCapacity = 0;
	numberOfRows = 0;
	pthread_mutex_unlock(&dataLock);

	return previousData;
}

@end
