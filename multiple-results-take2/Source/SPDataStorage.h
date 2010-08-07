//
//  $Id$
//
//  SPDataStorage.h
//  sequel-pro
//
//  Created by Rowan Beentje on 10/01/2009.
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

#import <Cocoa/Cocoa.h>

/*
 * This class provides a storage mechanism intended to represent tabular
 * data, in a 2D array.  Data can be added and retrieved either directly
 * or via NSArrays; internally, C arrays are used to provide speed and
 * memory improvements.
 * This class is essentially mutable.
 */

#pragma mark -
#pragma mark Class definition

@interface SPDataStorage : NSObject {
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

static inline void SPDataStorageAddRow(SPDataStorage* self, NSArray* row) {
	typedef void (*SPDSAddRowMethodPtr)(SPDataStorage*, SEL, NSArray*);
	static SPDSAddRowMethodPtr SPDSAddRow;
	if (!SPDSAddRow) SPDSAddRow = (SPDSAddRowMethodPtr)[self methodForSelector:@selector(addRowWithContents:)];
	SPDSAddRow(self, @selector(addRowWithContents:), row);
}

static inline void SPDataStorageReplaceRow(SPDataStorage* self, NSUInteger rowIndex, NSArray* row) {
	typedef void (*SPDSReplaceRowMethodPtr)(SPDataStorage*, SEL, NSUInteger, NSArray*);
	static SPDSReplaceRowMethodPtr SPDSReplaceRow;
	if (!SPDSReplaceRow) SPDSReplaceRow = (SPDSReplaceRowMethodPtr)[self methodForSelector:@selector(replaceRowAtIndex:withRowContents:)];
	SPDSReplaceRow(self, @selector(replaceRowAtIndex:withRowContents:), rowIndex, row);
}

static inline void SPDataStorageReplaceObjectAtRowAndColumn(SPDataStorage* self, NSUInteger rowIndex, NSUInteger colIndex, id newObject) {
	typedef void (*SPDSObjectReplaceMethodPtr)(SPDataStorage*, SEL, NSUInteger, NSUInteger, id);
	static SPDSObjectReplaceMethodPtr SPDSObjectReplace;
	if (!SPDSObjectReplace) SPDSObjectReplace = (SPDSObjectReplaceMethodPtr)[self methodForSelector:@selector(replaceObjectInRow:column:withObject:)];
	SPDSObjectReplace(self, @selector(replaceObjectInRow:column:withObject:), rowIndex, colIndex, newObject);
}

static inline id SPDataStorageObjectAtRowAndColumn(SPDataStorage* self, NSUInteger rowIndex, NSUInteger colIndex) {
	typedef id (*SPDSObjectFetchMethodPtr)(SPDataStorage*, SEL, NSUInteger, NSUInteger);
	static SPDSObjectFetchMethodPtr SPDSObjectFetch;
	if (!SPDSObjectFetch) SPDSObjectFetch = (SPDSObjectFetchMethodPtr)[self methodForSelector:@selector(cellDataAtRow:column:)];
	return SPDSObjectFetch(self, @selector(cellDataAtRow:column:), rowIndex, colIndex);
}
