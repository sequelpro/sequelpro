//
//  $Id$
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
//  More info at <http://code.google.com/p/sequel-pro/>

/**
 * This class provides a storage mechanism intended to represent tabular
 * data, in a 2D array.  Data can be added and retrieved either directly
 * or via NSArrays; internally, C arrays are used to provide speed and
 * memory improvements.
 * This class is essentially mutable.
 */

@interface SPDataStorage : NSObject 
{
	NSUInteger numColumns;
	NSUInteger columnPointerByteSize;
	NSUInteger numRows, numRowsCapacity;

	id **dataStorage;
}

/* Retrieving rows and cells */
- (NSMutableArray *) rowContentsAtIndex:(NSUInteger)index;
- (id) cellDataAtRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex;

/* Adding and amending rows and cells */
- (void) addRowWithContents:(NSArray *)row;
- (void) insertRowContents:(NSArray *)row atIndex:(NSUInteger)index;
- (void) replaceRowAtIndex:(NSUInteger)index withRowContents:(NSArray *)row;
- (void) replaceObjectInRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex withObject:(id)object;
- (void) removeRowAtIndex:(NSUInteger)index;
- (void) removeRowsInRange:(NSRange)rangeToRemove;
- (void) removeAllRows;

/* Basic information */
- (NSUInteger) count;
- (void) setColumnCount:(NSUInteger)columnCount;
- (NSUInteger) columnCount;

/* Initialisation and teardown */
#pragma mark -
- (id) init;
- (void) dealloc;

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

static inline void SPDataStorageReplaceObjectAtRowAndColumn(SPDataStorage* self, NSUInteger rowIndex, NSUInteger colIndex, id newObject) 
{
	typedef void (*SPDSObjectReplaceMethodPtr)(SPDataStorage*, SEL, NSUInteger, NSUInteger, id);
	static SPDSObjectReplaceMethodPtr SPDSObjectReplace;
	if (!SPDSObjectReplace) SPDSObjectReplace = (SPDSObjectReplaceMethodPtr)[self methodForSelector:@selector(replaceObjectInRow:column:withObject:)];
	SPDSObjectReplace(self, @selector(replaceObjectInRow:column:withObject:), rowIndex, colIndex, newObject);
}

static inline id SPDataStorageObjectAtRowAndColumn(SPDataStorage* self, NSUInteger rowIndex, NSUInteger colIndex) 
{
	typedef id (*SPDSObjectFetchMethodPtr)(SPDataStorage*, SEL, NSUInteger, NSUInteger);
	static SPDSObjectFetchMethodPtr SPDSObjectFetch;
	if (!SPDSObjectFetch) SPDSObjectFetch = (SPDSObjectFetchMethodPtr)[self methodForSelector:@selector(cellDataAtRow:column:)];
	return SPDSObjectFetch(self, @selector(cellDataAtRow:column:), rowIndex, colIndex);
}
