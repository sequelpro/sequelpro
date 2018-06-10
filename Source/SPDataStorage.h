//
//  SPDataStorage.h
//  sequel-pro
//
//  Created by Rowan Beentje on January 1, 2009.
//  Copyright (c) 2009 Rowan Beentje. All rights reserved.
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

#import <SPMySQL/SPMySQLStreamingResultStoreDelegate.h>

@class SPMySQLStreamingResultStore;

/**
 * This class wraps a SPMySQLStreamingResultStore, providing an editable
 * data store; on a fresh load all data will be proxied from the underlying
 * result store, but if cells or rows are edited, mutable rows are stored
 * directly.
 */

@interface SPDataStorage : NSObject <SPMySQLStreamingResultStoreDelegate>
{
	SPMySQLStreamingResultStore *dataStorage;
	NSPointerArray *editedRows;
	BOOL *unloadedColumns;
	NSCondition *dataDownloadedLock;

	NSUInteger numberOfColumns;
	NSUInteger editedRowCount;
}

/* Setting result store */
- (void) setDataStorage:(SPMySQLStreamingResultStore *) newDataStorage updatingExisting:(BOOL)updateExistingStore;

/* Retrieving rows and cells */
- (NSMutableArray *) rowContentsAtIndex:(NSUInteger)anIndex;
- (id) cellDataAtRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex;
- (id) cellPreviewAtRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex previewLength:(NSUInteger)previewLength;
- (BOOL) cellIsNullOrUnloadedAtRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex;

/* Adding and amending rows and cells */
- (void) addRowWithContents:(NSMutableArray *)aRow;
- (void) insertRowContents:(NSMutableArray *)aRow atIndex:(NSUInteger)anIndex;
- (void) replaceRowAtIndex:(NSUInteger)anIndex withRowContents:(NSMutableArray *)aRow;
- (void) replaceObjectInRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex withObject:(id)anObject;
- (void) removeRowAtIndex:(NSUInteger)anIndex;
- (void) removeRowsInRange:(NSRange)rangeToRemove;
- (void) removeAllRows;

/* Unloaded columns */
- (void) setColumnAsUnloaded:(NSUInteger)columnIndex;

/* Basic information */
- (NSUInteger) count;
- (NSUInteger) columnCount;
- (BOOL) dataDownloaded;

/**
 * This method will block the caller until -dataDownloaded returns YES.
 * Multiple parallel calls from different threads are possible.
 */
- (void) awaitDataDownloaded;

/* Delegate callback methods */
- (void)resultStoreDidFinishLoadingData:(SPMySQLStreamingResultStore *)resultStore;

@end

#pragma mark -
#pragma mark Cached method calls to remove obj-c messaging overhead in tight loops

static inline void SPDataStorageAddRow(SPDataStorage* self, NSArray* row) 
{
	typedef void (*SPDSAddRowMethodPtr)(SPDataStorage*, SEL, NSArray*);
	static SPDSAddRowMethodPtr SPDSAddRow;
	if (!SPDSAddRow) SPDSAddRow = (SPDSAddRowMethodPtr)[self methodForSelector:@selector(addRowWithContents:)];
	SPDSAddRow(self, @selector(addRowWithContents:), row);
}

static inline void SPDataStorageReplaceRow(SPDataStorage* self, NSUInteger rowIndex, NSArray* row) 
{
	typedef void (*SPDSReplaceRowMethodPtr)(SPDataStorage*, SEL, NSUInteger, NSArray*);
	static SPDSReplaceRowMethodPtr SPDSReplaceRow;
	if (!SPDSReplaceRow) SPDSReplaceRow = (SPDSReplaceRowMethodPtr)[self methodForSelector:@selector(replaceRowAtIndex:withRowContents:)];
	SPDSReplaceRow(self, @selector(replaceRowAtIndex:withRowContents:), rowIndex, row);
}

static inline id SPDataStorageObjectAtRowAndColumn(SPDataStorage* self, NSUInteger rowIndex, NSUInteger colIndex) 
{
	typedef id (*SPDSObjectFetchMethodPtr)(SPDataStorage*, SEL, NSUInteger, NSUInteger);
	static SPDSObjectFetchMethodPtr SPDSObjectFetch;
	if (!SPDSObjectFetch) SPDSObjectFetch = (SPDSObjectFetchMethodPtr)[self methodForSelector:@selector(cellDataAtRow:column:)];
	return SPDSObjectFetch(self, @selector(cellDataAtRow:column:), rowIndex, colIndex);
}

static inline id SPDataStoragePreviewAtRowAndColumn(SPDataStorage* self, NSUInteger rowIndex, NSUInteger colIndex, NSUInteger previewLength)
{
	typedef id (*SPDSPreviewFetchMethodPtr)(SPDataStorage*, SEL, NSUInteger, NSUInteger, NSUInteger);
	static SPDSPreviewFetchMethodPtr SPDSPreviewFetch;
	if (!SPDSPreviewFetch) SPDSPreviewFetch = (SPDSPreviewFetchMethodPtr)[self methodForSelector:@selector(cellPreviewAtRow:column:previewLength:)];
	return SPDSPreviewFetch(self, @selector(cellPreviewAtRow:column:previewLength:), rowIndex, colIndex, previewLength);
}

