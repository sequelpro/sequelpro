//
//  SPMySQLStreamingResultStore.h
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


#import <SPMySQL/SPMySQL.h>
#import "SPMySQLStreamingResultStoreDelegate.h"
#include <malloc/malloc.h>

typedef char SPMySQLStreamingResultStoreRowData;

@interface SPMySQLStreamingResultStore : SPMySQLStreamingResult {
	BOOL loadStarted;
	BOOL loadCancelled;
	id <SPMySQLStreamingResultStoreDelegate> delegate;

    // Data storage and allocation
    NSUInteger rowCapacity;
	NSUInteger rowDownloadIterator;
	malloc_zone_t *storageMallocZone;
    SPMySQLStreamingResultStoreRowData **dataStorage;

    // Thread safety
    pthread_mutex_t dataLock;

}

@property (readwrite, assign) id <SPMySQLStreamingResultStoreDelegate> delegate;

/* Setup and teardown */
- (void)replaceExistingResultStore:(SPMySQLStreamingResultStore *)previousResultStore;
- (void)startDownload;

/* Data retrieval */
- (NSMutableArray *)rowContentsAtIndex:(NSUInteger)rowIndex;
- (id)cellDataAtRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex;
- (id)cellPreviewAtRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex previewLength:(NSUInteger)previewLength;
- (BOOL)cellIsNullAtRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex;

/* Deleting rows and addition of placeholder rows */
- (void) addDummyRow;
- (void) insertDummyRowAtIndex:(NSUInteger)anIndex;
- (void) removeRowAtIndex:(NSUInteger)anIndex;
- (void) removeRowsInRange:(NSRange)rangeToRemove;
- (void) removeAllRows;

@end

#pragma mark -
#pragma mark Cached method calls to remove obj-c messaging overhead in tight loops

static inline unsigned long long SPMySQLResultStoreGetRowCount(SPMySQLStreamingResultStore* self)
{
	typedef unsigned long long (*SPMSRSRowCountMethodPtr)(SPMySQLStreamingResultStore*, SEL);
	static SPMSRSRowCountMethodPtr SPMSRSRowCount;
	if (!SPMSRSRowCount) SPMSRSRowCount = (SPMSRSRowCountMethodPtr)[SPMySQLStreamingResultStore instanceMethodForSelector:@selector(numberOfRows)];
	return SPMSRSRowCount(self, @selector(numberOfRows));
}

static inline id SPMySQLResultStoreGetRow(SPMySQLStreamingResultStore* self, NSUInteger rowIndex)
{
	typedef id (*SPMSRSRowFetchMethodPtr)(SPMySQLStreamingResultStore*, SEL, NSUInteger);
	static SPMSRSRowFetchMethodPtr SPMSRSRowFetch;
	if (!SPMSRSRowFetch) SPMSRSRowFetch = (SPMSRSRowFetchMethodPtr)[SPMySQLStreamingResultStore instanceMethodForSelector:@selector(rowContentsAtIndex:)];
	return SPMSRSRowFetch(self, @selector(rowContentsAtIndex:), rowIndex);
}

static inline id SPMySQLResultStoreObjectAtRowAndColumn(SPMySQLStreamingResultStore* self, NSUInteger rowIndex, NSUInteger colIndex)
{
	typedef id (*SPMSRSObjectFetchMethodPtr)(SPMySQLStreamingResultStore*, SEL, NSUInteger, NSUInteger);
	static SPMSRSObjectFetchMethodPtr SPMSRSObjectFetch;
	if (!SPMSRSObjectFetch) SPMSRSObjectFetch = (SPMSRSObjectFetchMethodPtr)[SPMySQLStreamingResultStore instanceMethodForSelector:@selector(cellDataAtRow:column:)];
	return SPMSRSObjectFetch(self, @selector(cellDataAtRow:column:), rowIndex, colIndex);
}

static inline id SPMySQLResultStorePreviewAtRowAndColumn(SPMySQLStreamingResultStore* self, NSUInteger rowIndex, NSUInteger colIndex, NSUInteger previewLength)
{
	typedef id (*SPMSRSObjectPreviewMethodPtr)(SPMySQLStreamingResultStore*, SEL, NSUInteger, NSUInteger, NSUInteger);
	static SPMSRSObjectPreviewMethodPtr SPMSRSObjectPreview;
	if (!SPMSRSObjectPreview) SPMSRSObjectPreview = (SPMSRSObjectPreviewMethodPtr)[SPMySQLStreamingResultStore instanceMethodForSelector:@selector(cellPreviewAtRow:column:previewLength:)];
	return SPMSRSObjectPreview(self, @selector(cellPreviewAtRow:column:previewLength:), rowIndex, colIndex, previewLength);
}
