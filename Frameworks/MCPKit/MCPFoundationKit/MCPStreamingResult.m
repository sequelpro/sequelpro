//
//  $Id$
//
//  MCPStreamingResult.m
//  sequel-pro
//
//  Created by Rowan Beentje on Aug 16, 2009
//  Copyright 2009 Rowan Beentje. All rights reserved.
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

#import "MCPStreamingResult.h"
#import "MCPConnection.h"
#import "MCPNull.h"
#import "MCPNumber.h"

/**
 * IMPORTANT NOTE
 *
 * MCPStreamingResult can operate in two modes.  The default mode is a safe implementation,
 * which operates in a multithreaded fashion - a worker thread is set up to download the results as
 * fast as possible in the background, while the results are made available via a blocking (and so
 * single-thread-compatible) fetchNextRowAsArray call.  This provides the benefit of allowing a progress
 * bar to be shown during downloads, and threaded processing, but still has reasonable memory usage for
 * the downloaded result - and won't block the server.
 * Alternatively, withFullStreaming: can be set to YES, in which case each row will be accessed on-demand;
 * this can be dangerous as it means a SELECT will tie up the server for longer, as for MyISAM tables
 * updates (and subsequent reads) must block while a SELECT is still running.  However this can be useful
 * for certain processes such as working with very large tables to keep memory usage low.
 */


@interface MCPStreamingResult (PrivateAPI)
- (void) _downloadAllData;
- (void) _freeAllDataWhenDone;
@end

@implementation MCPStreamingResult : MCPResult

#pragma mark -
#pragma mark Setup and teardown

/**
 * Initialise a MCPStreamingResult in the same way as MCPResult - as used
 * internally by the MCPConnection !{queryString:} method.
 */
- (id)initWithMySQLPtr:(MYSQL *)mySQLPtr encoding:(NSStringEncoding)theEncoding timeZone:(NSTimeZone *)theTimeZone connection:(MCPConnection *)theConnection
{
	return [self initWithMySQLPtr:mySQLPtr encoding:theEncoding timeZone:theTimeZone connection:theConnection withFullStreaming:NO];
}

/**
 * Master initialisation method, allowing selection of either full streaming or safe streaming
 * (see "important note" above)
 */
- (id)initWithMySQLPtr:(MYSQL *)mySQLPtr encoding:(NSStringEncoding)theEncoding timeZone:(NSTimeZone *)theTimeZone connection:(MCPConnection *)theConnection withFullStreaming:(BOOL)useFullStreaming
{
	if ((self = [super init])) {
		mEncoding = theEncoding;
		mTimeZone = [theTimeZone retain];
		parentConnection = theConnection;
		fullyStreaming = useFullStreaming;
		connectionUnlocked = NO;

		if (mResult) {
			mysql_free_result(mResult);
			mResult = NULL;
		}

		if (mNames) {
			[mNames release];
			mNames = nil;
		}

		mResult = mysql_use_result(mySQLPtr);

		if (mResult) {
			mNumOfFields = mysql_num_fields(mResult);
			fieldDefinitions = mysql_fetch_fields(mResult);
		} else {
			mNumOfFields = 0;
		}

		// Obtain SEL references and pointer
		isConnectedSEL = @selector(isConnected);
		isConnectedPtr = [parentConnection methodForSelector:isConnectedSEL];

		// If the result is opened in download-data-fast safe mode, set up the additional variables
		// and threads required.
		if (!fullyStreaming) {
			dataDownloaded = NO;
			dataFreed = NO;
			localDataStore = NULL;
			currentDataStoreEntry = NULL;
			localDataStoreLastEntry = NULL;
			localDataRows = 0;
			localDataAllocated = 0;
			downloadedRowCount = 0;
			processedRowCount = 0;
			freedRowCount = 0;
			pthread_mutex_init(&dataCreationLock, NULL);
			pthread_mutex_init(&dataFreeLock, NULL);

			// Start the data download thread
			[NSThread detachNewThreadSelector:@selector(_downloadAllData) toTarget:self withObject:nil];

			// Start the data freeing thread
			[NSThread detachNewThreadSelector:@selector(_freeAllDataWhenDone) toTarget:self withObject:nil];
		}
	}

	return self;
}

/**
 * Deallocate the result and unlock the parent connection for further use
 */
- (void) dealloc
{
	[self cancelResultLoad];
	if (!connectionUnlocked) [parentConnection unlockConnection];

	if (!fullyStreaming) {
		pthread_mutex_destroy(&dataFreeLock);
		pthread_mutex_destroy(&dataCreationLock);
	}

	[super dealloc];
}

#pragma mark -
#pragma mark Results fetching

/**
 * Retrieve the next row of the result as an array.  Should be called in a loop
 * until nil is returned to ensure all the results have been retrieved.
 */
- (NSArray *)fetchNextRowAsArray
{
	MYSQL_ROW theRow;
	char *theRowData;
	unsigned long *fieldLengths;
	NSInteger i, copiedDataLength;
	NSMutableArray *returnArray;

	// Retrieve the next row according to the mode this result set is in.
	// If fully streaming, retrieve the MYSQL_ROW
	if (fullyStreaming) {
		theRow = mysql_fetch_row(mResult);

		// If no data was returned, we're at the end of the result set - return nil.
		if (theRow == NULL) return nil;

		// Retrieve the lengths of the returned data
		fieldLengths = mysql_fetch_lengths(mResult);

	// If in cached-streaming/fast download mode, get a reference to the data for the current row
	} else {
		copiedDataLength = 0;

		// Lock the data mutex
		pthread_mutex_lock(&dataCreationLock);

		// Check to see whether we need to wait for the data to be availabe
		// - if so, wait 1ms before checking again.
		while (!dataDownloaded && processedRowCount == downloadedRowCount) {
			pthread_mutex_unlock(&dataCreationLock);
			usleep(1000);
			pthread_mutex_lock(&dataCreationLock);
		}

		// If all rows have been processed, we're at the end of the result set - return nil
		// once all memory has been freed
		if (processedRowCount == downloadedRowCount) {
			pthread_mutex_unlock(&dataCreationLock);

			while (!dataFreed) usleep(1000);

			// Update the connection's error statuses in case of error during content download
			[parentConnection updateErrorStatuses];

			// Unlock the connection and return
			[parentConnection unlockConnection];
			connectionUnlocked = YES;
			return nil;
		}

		// Retrieve a reference to the data and the associated lengths
		theRowData = currentDataStoreEntry->data;
		fieldLengths = currentDataStoreEntry->dataLengths;

		// Unlock the data mutex
		pthread_mutex_unlock(&dataCreationLock);
	}

	// Initialise the array to return
	returnArray = [NSMutableArray arrayWithCapacity:mNumOfFields];
	for (i = 0; i < mNumOfFields; i++) {
		id cellData = nil;
		char *theData;

		// In fully streaming mode, copy across the data for the MYSQL_ROW
		if (fullyStreaming) {
			if (theRow[i] == NULL) {
				cellData = [NSNull null];
			} else {
				theData = calloc(sizeof(char), fieldLengths[i]+1);
				memcpy(theData, theRow[i], fieldLengths[i]);
				theData[fieldLengths[i]] = '\0';
			}

		// In cached-streaming mode, use a reference to the downloaded data
		} else {
			if (fieldLengths[i] == NSNotFound) {
				cellData = [NSNull null];
			} else {
				theData = theRowData+copiedDataLength;
				copiedDataLength += fieldLengths[i] + 1;
			}
		}

		// If the data hasn't already been detected as NULL - in which case it will have been
		// set to NSNull - process the data by type
		if (cellData == nil) {
			switch (fieldDefinitions[i].type) {
				case FIELD_TYPE_TINY:
				case FIELD_TYPE_SHORT:
				case FIELD_TYPE_INT24:
				case FIELD_TYPE_LONG:
				case FIELD_TYPE_LONGLONG:
				case FIELD_TYPE_DECIMAL:
				case FIELD_TYPE_NEWDECIMAL:
				case FIELD_TYPE_FLOAT:
				case FIELD_TYPE_DOUBLE:
				case FIELD_TYPE_TIMESTAMP:
				case FIELD_TYPE_DATE:
				case FIELD_TYPE_TIME:
				case FIELD_TYPE_DATETIME:
				case FIELD_TYPE_YEAR:
				case FIELD_TYPE_VAR_STRING:
				case FIELD_TYPE_STRING:
				case FIELD_TYPE_SET:
				case FIELD_TYPE_ENUM:
				case FIELD_TYPE_NEWDATE: // Don't know what the format for this type is...
					
					// For fields of type BINARY/VARBINARY, return the data. Also add an extra check to make 
					// sure it's binary data (seems that it's returned as type STRING) to get around a MySQL 
					// bug (#28214) returning DATE fields with the binary flag set.
					if ((fieldDefinitions[i].flags & BINARY_FLAG) && 
						(fieldDefinitions[i].type == FIELD_TYPE_STRING)) 
					{						
						cellData = [NSData dataWithBytes:theData length:fieldLengths[i]];
					}
					// For string data, convert to text
					else {
						cellData = [NSString stringWithCString:theData encoding:mEncoding];
					}
					
					break;

				case FIELD_TYPE_BIT:
					cellData = [NSString stringWithFormat:@"%u", theData[0]];
					break;

				case FIELD_TYPE_TINY_BLOB:
				case FIELD_TYPE_BLOB:
				case FIELD_TYPE_MEDIUM_BLOB:
				case FIELD_TYPE_LONG_BLOB:
					
					// For binary data, return the data if force-return-as-string is not enabled
					if ((fieldDefinitions[i].flags & BINARY_FLAG) && !mReturnDataAsStrings) {
						cellData = [NSData dataWithBytes:theData length:fieldLengths[i]];
					}
					else {
						cellData = [[NSString alloc] initWithBytes:theData length:fieldLengths[i] encoding:mEncoding];
					
						if (cellData) [cellData autorelease];
					}		

					break;

				case FIELD_TYPE_NULL:
					cellData = [NSNull null];
					break;

				default:
					NSLog(@"in fetchNextRowAsArray : Unknown type : %ld for column %ld, sending back a NSData object", (NSInteger)fieldDefinitions[i].type, (NSInteger)i);
					cellData = [NSData dataWithBytes:theData length:fieldLengths[i]];
				break;
			}

			// Free the data if it was originally allocated
			if (fullyStreaming) free(theData);

			// If a creator returned a nil object, replace with NSNull
			if (cellData == nil) cellData = [NSNull null];
		}

		[returnArray insertObject:cellData atIndex:i];
	}

	// If in cached-streaming mode, update the current entry processed count
	if (!fullyStreaming) {

		// Lock both mutexes
		pthread_mutex_lock(&dataCreationLock);
		pthread_mutex_lock(&dataFreeLock);

		// Update the active-data pointer to the next item in the list, or set to NULL if no more items
		currentDataStoreEntry = currentDataStoreEntry->nextRow;

		// Increment counter
		processedRowCount++;

		// Unlock both mutexes
		pthread_mutex_unlock(&dataCreationLock);
		pthread_mutex_unlock(&dataFreeLock);
	}

	return returnArray;
}

/*
 * Ensure the result set is fully processed and freed without any processing
 */
- (void) cancelResultLoad
{
	MYSQL_ROW theRow;

	// Loop through all the rows and ensure the rows are fetched.
	// If fully streaming, loop through the rows directly
	if (fullyStreaming) {
		while (1) {
			theRow = mysql_fetch_row(mResult);

			// If no data was returned, we're at the end of the result set - return.
			if (theRow == NULL) return;
		}

	// If in cached-streaming/fast download mode, loop until all data is fetched and freed
	} else {

		while (1) {
		
			// Check to see whether we need to wait for the data to be available
			// - if so, wait 1ms before checking again
			while (!dataDownloaded && processedRowCount == downloadedRowCount) usleep(1000);

			// If all rows have been processed, we're at the end of the result set - return
			// once all memory has been freed
			if (processedRowCount == downloadedRowCount) {
				while (!dataFreed) usleep(1000);
				[parentConnection unlockConnection];
				connectionUnlocked = YES;
				return;
			}
			processedRowCount++;
		}
	}
}

#pragma mark -
#pragma mark Overrides for safety

/**
 * If numOfRows is used before the data is fully downloaded, -1 will be returned;
 * otherwise the number of rows is returned.
 */
- (my_ulonglong)numOfRows
{
	if (!dataDownloaded) return -1;

	return downloadedRowCount;
}

- (void)dataSeek:(my_ulonglong) row
{
	NSLog(@"dataSeek cannot be used with streaming results");
}

@end

@implementation MCPStreamingResult (PrivateAPI)

/**
 * Used internally to download results in a background thread
 */
- (void)_downloadAllData
{
	NSAutoreleasePool *downloadPool = [[NSAutoreleasePool alloc] init];
	MYSQL_ROW theRow;
	unsigned long *fieldLengths;
	NSInteger i, dataCopiedLength, rowDataLength;
	LOCAL_ROW_DATA *newRowStore;

	size_t sizeOfLocalRowData = sizeof(LOCAL_ROW_DATA);
	size_t sizeOfDataLengths = (size_t)(sizeof(unsigned long) * mNumOfFields);

	// Loop through the rows until the end of the data is reached - indicated via a NULL
	while (	(BOOL)(*isConnectedPtr)(parentConnection, isConnectedSEL) && (theRow = mysql_fetch_row(mResult))) {

		// Retrieve the lengths of the returned data
		fieldLengths = mysql_fetch_lengths(mResult);
		rowDataLength = 0;
		dataCopiedLength = 0;
		for (i = 0; i < mNumOfFields; i++)
			rowDataLength += fieldLengths[i];

		// Initialise memory for the row and set a NULL pointer for the next item
		newRowStore = malloc(sizeOfLocalRowData);
		newRowStore->nextRow = NULL;

		// Set up the row data store - a char* - and copy in the data if there is any,
		// using a null terminator for each field boundary for easier data processing later
		newRowStore->data = malloc(sizeof(char) * (rowDataLength + mNumOfFields));
		for (i = 0; i < mNumOfFields; i++) {
			if (theRow[i] != NULL) {
				memcpy(newRowStore->data+dataCopiedLength, theRow[i], fieldLengths[i]);
				newRowStore->data[dataCopiedLength+fieldLengths[i]] = '\0';
				dataCopiedLength += fieldLengths[i] + 1;
			} else {
				fieldLengths[i] = NSNotFound;
			}
		}

		// Set up and copy in the field lengths
		newRowStore->dataLengths = memcpy(malloc(sizeOfDataLengths), fieldLengths, sizeOfDataLengths);
		
		// Lock both mutexes
		pthread_mutex_lock(&dataCreationLock);
		pthread_mutex_lock(&dataFreeLock);

		// Add the newly allocated row to end of the storage linked list
		if (localDataStore) {
			localDataStoreLastEntry->nextRow = newRowStore;
		} else {
			localDataStore = newRowStore;
		}
		localDataStoreLastEntry = newRowStore;
		if (!currentDataStoreEntry) currentDataStoreEntry = newRowStore;

		// Update the downloaded row count
		downloadedRowCount++;
		
		// Unlock both mutexes
		pthread_mutex_unlock(&dataCreationLock);
		pthread_mutex_unlock(&dataFreeLock);
	}

	dataDownloaded = YES;
	[downloadPool drain];
}

/**
 * Used internally to free data which has been fully processed; done in a thread to allow
 * fetchNextRowAsArray to be faster.
 */
- (void) _freeAllDataWhenDone
{
	NSAutoreleasePool *dataFreeingPool = [[NSAutoreleasePool alloc] init];

	while (!dataDownloaded || freedRowCount != downloadedRowCount) {

		// Lock the data free mutex
		pthread_mutex_lock(&dataFreeLock);

		// If the freed row count matches the processed row count, wait before retrying
		if (freedRowCount == processedRowCount) {
			pthread_mutex_unlock(&dataFreeLock);
			usleep(1000);
			continue;
		}

		// Free a single item off the bottom of the list
		// Update the data pointer to the next item in the list, or set to NULL if no more items
		LOCAL_ROW_DATA *rowToRemove = localDataStore;
		localDataStore = localDataStore->nextRow;

		// Free memory for the first row
		rowToRemove->nextRow = NULL;
		free(rowToRemove->dataLengths);
		if (rowToRemove->data != NULL) free(rowToRemove->data);
		free(rowToRemove);

		// Increment the counter
		freedRowCount++;

		// Unlock the data free mutex
		pthread_mutex_unlock(&dataFreeLock);
	}

	dataFreed = YES;
	[dataFreeingPool drain];
}

@end