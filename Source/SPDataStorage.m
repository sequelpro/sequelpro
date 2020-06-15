//
//  SPDataStorage.m
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

#import "SPDataStorage.h"
#import "SPObjectAdditions.h"
#import <SPMySQL/SPMySQLStreamingResultStore.h>
#include <stdlib.h>
#include <mach/mach_time.h>

@interface SPDataStorage ()

- (void) _checkNewRow:(NSMutableArray *)aRow;
- (void) _addRowUnsafeUnchecked:(NSMutableArray *)aRow;

@end

@implementation SPDataStorage

static inline NSMutableArray* SPDataStorageGetEditedRow(NSPointerArray* rowStore, NSUInteger rowIndex)
{
	typedef NSMutableArray* (*SPDSGetEditedRowMethodPtr)(NSPointerArray*, SEL, NSUInteger);
	static SPDSGetEditedRowMethodPtr SPDSGetEditedRow;
	if (!SPDSGetEditedRow) SPDSGetEditedRow = (SPDSGetEditedRowMethodPtr)[rowStore methodForSelector:@selector(pointerAtIndex:)];
	return SPDSGetEditedRow(rowStore, @selector(pointerAtIndex:), rowIndex);
}

#pragma mark - Setting result store

/**
 * Set the underlying MySQL data storage.
 * This will clear all edited rows and unloaded column tracking.
 */
- (void) setDataStorage:(SPMySQLStreamingResultStore *)newDataStorage updatingExisting:(BOOL)updateExistingStore
{
	BOOL *oldUnloadedColumns;
	NSPointerArray *oldEditedRows;
	SPMySQLStreamingResultStore *oldDataStorage;
	
	@synchronized(self) {
		oldDataStorage = dataStorage;

		if (oldDataStorage) {
			// If the table is reloading data, link to the current data store for smoother loads
			if (updateExistingStore) {
				[newDataStorage replaceExistingResultStore:oldDataStorage];
			}
		}

		[newDataStorage retain];

		NSPointerArray *newEditedRows = [[NSPointerArray alloc] init];
		NSUInteger newNumberOfColumns = [newDataStorage numberOfFields];
		BOOL *newUnloadedColumns = calloc(newNumberOfColumns, sizeof(BOOL));
		for (NSUInteger i = 0; i < newNumberOfColumns; i++) {
			newUnloadedColumns[i] = NO;
		}

		oldUnloadedColumns = unloadedColumns;
		oldEditedRows = editedRows;
		dataStorage = newDataStorage;
		numberOfColumns = newNumberOfColumns;
		unloadedColumns = newUnloadedColumns;
		editedRowCount = 0;
		editedRows = newEditedRows;
	}
	
	free(oldUnloadedColumns);
	[oldEditedRows release];
	[oldDataStorage release];
	
	// the only delegate callback is resultStoreDidFinishLoadingData:.
	// We can't set the delegate before exchanging the dataStorage ivar since then
	// the message would come from an unknown object.
	// But if we set it afterwards, we risk losing the callback event (since it could've
	// happened in the meantime) - this is what the following if() is for.
	[newDataStorage setDelegate:self];
	
	if ([newDataStorage dataDownloaded]) {
		[self resultStoreDidFinishLoadingData:newDataStorage];
	}
}


#pragma mark -
#pragma mark Retrieving rows and cells

/**
 * Return a mutable array containing the data for a specified row.
 * The returned array will be a shallow copy of the internal row object.
 */
- (NSMutableArray *) rowContentsAtIndex:(NSUInteger)anIndex
{
	SPNotLoaded *notLoaded = [SPNotLoaded notLoaded];
	@synchronized(self) {
		// If an edited row exists for the supplied index, return it
		if (anIndex < editedRowCount) {
			NSMutableArray *editedRow = SPDataStorageGetEditedRow(editedRows, anIndex);
			
			if (editedRow != NULL) {
				return [NSMutableArray arrayWithArray:editedRow]; //make a copy to not give away control of our internal state
			}
		}
		
		// Otherwise, prepare to return the underlying storage row
		NSMutableArray *dataArray = SPMySQLResultStoreGetRow(dataStorage, anIndex); //returned array is already a copy
		
		// Modify unloaded cells as appropriate
		for (NSUInteger i = 0; i < numberOfColumns; i++) {
			if (unloadedColumns[i]) {
				CFArraySetValueAtIndex((CFMutableArrayRef)dataArray, i, notLoaded);
			}
		}
		
		return dataArray;
	}
}

/**
 * Return the data at a specified row and column index.
 */
- (id) cellDataAtRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex
{
	SPNotLoaded *notLoaded = [SPNotLoaded notLoaded];
	@synchronized(self) {
		// If an edited row exists at the supplied index, return it
		if (rowIndex < editedRowCount) {
			NSMutableArray *editedRow = SPDataStorageGetEditedRow(editedRows, rowIndex);

			if (editedRow != NULL) {
				return CFArrayGetValueAtIndex((CFArrayRef)editedRow, columnIndex);
			}
		}

		// Throw an exception if the column index is out of bounds
		if (columnIndex >= numberOfColumns) {
			[NSException raise:NSRangeException format:@"Requested storage column (col %llu) beyond bounds (%llu)", (unsigned long long)columnIndex, (unsigned long long)numberOfColumns];
		}

		// If the specified column is not loaded, return a SPNotLoaded reference
		if (unloadedColumns[columnIndex]) {
			return notLoaded;
		}

		// Return the content
		return SPMySQLResultStoreObjectAtRowAndColumn(dataStorage, rowIndex, columnIndex);
	}
}

/**
 * Return a preview of the data at a specified row and column index, limited
 * to approximately the supplied length.
 */
- (id) cellPreviewAtRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex previewLength:(NSUInteger)previewLength
{
	SPNotLoaded *notLoaded = [SPNotLoaded notLoaded];
	@synchronized(self) {
		// If an edited row exists at the supplied index, return it
		if (rowIndex < editedRowCount) {
			NSMutableArray *editedRow = SPDataStorageGetEditedRow(editedRows, rowIndex);

			if (editedRow != NULL) {
				id anObject = CFArrayGetValueAtIndex((CFArrayRef)editedRow, columnIndex);
				if ([anObject isKindOfClass:[NSString class]] && [(NSString *)anObject length] > 150) {
					return ([NSString stringWithFormat:@"%@...", [anObject substringToIndex:147]]);
				}
				return anObject;
			}
		}

		// Throw an exception if the column index is out of bounds
		if (columnIndex >= numberOfColumns) {
			[NSException raise:NSRangeException format:@"Requested storage column (col %llu) beyond bounds (%llu)", (unsigned long long)columnIndex, (unsigned long long)numberOfColumns];
		}

		// If the specified column is not loaded, return a SPNotLoaded reference
		if (unloadedColumns[columnIndex]) {
			return notLoaded;
		}

		// Return the content
		return SPMySQLResultStorePreviewAtRowAndColumn(dataStorage, rowIndex, columnIndex, previewLength);
	}
}

/**
 * Returns whether the data at a specified row and column index is NULL or unloaded
 */
- (BOOL) cellIsNullOrUnloadedAtRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex
{
	@synchronized(self) {
		// If an edited row exists at the supplied index, check it for a NULL.
		if (rowIndex < editedRowCount) {
			NSMutableArray *editedRow = SPDataStorageGetEditedRow(editedRows, rowIndex);

			if (editedRow != NULL) {
				return [(id)CFArrayGetValueAtIndex((CFArrayRef)editedRow, columnIndex) isNSNull];
			}
		}

		// Throw an exception if the column index is out of bounds
		if (columnIndex >= numberOfColumns) {
			[NSException raise:NSRangeException format:@"Requested storage column (col %llu) beyond bounds (%llu)", (unsigned long long)columnIndex, (unsigned long long)numberOfColumns];
		}

		if (unloadedColumns[columnIndex]) {
			return YES;
		}

		return [dataStorage cellIsNullAtRow:rowIndex column:columnIndex];
	}
}

#pragma mark -
#pragma mark Retrieving rows via NSFastEnumeration

/**
 * Implementation of the NSFastEnumeration protocol.
 * Note that rows are currently retrieved individually to avoid mutation and locking issues,
 * although this could be improved on.
 */
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len
{
	NSMutableArray *targetRow = nil;
	size_t srcObject;
	
	SPNotLoaded *notLoaded = [SPNotLoaded notLoaded];
	@synchronized(self) {
		srcObject = (size_t)dataStorage ^ (size_t)editedRows ^ editedRowCount;
		// If the start index is out of bounds, return 0 to indicate end of results
		if (state->state >= SPMySQLResultStoreGetRowCount(dataStorage)) return 0;

		// If an edited row exists for the supplied index, use that; otherwise use the underlying
		// storage row
		if (state->state < editedRowCount) {
			NSMutableArray *internalRow = SPDataStorageGetEditedRow(editedRows, state->state);
			if(internalRow != NULL) {
				targetRow = [NSMutableArray arrayWithArray:internalRow]; //make a copy to not give away control of our internal state
			}
		}

		if (targetRow == nil) {
			targetRow = SPMySQLResultStoreGetRow(dataStorage, state->state); //returned array is already a copy

			// Modify unloaded cells as appropriate
			for (NSUInteger i = 0; i < numberOfColumns; i++) {
				if (unloadedColumns[i]) {
					CFArraySetValueAtIndex((CFMutableArrayRef)targetRow, i, notLoaded);
				}
			}
		}
	}

	// Add the item to the buffer and return the appropriate state
	stackbuf[0] = targetRow;

	state->state += 1;
	state->itemsPtr = stackbuf;
	state->mutationsPtr = (unsigned long *)srcObject;

	return 1;
}

#pragma mark -
#pragma mark Adding and amending rows and cells

/**
 * Add a new row to the end of the storage array, supplying an NSArray
 * of objects.  Note that the supplied objects are retained as a reference
 * rather than copied.
 */
- (void) addRowWithContents:(NSMutableArray *)aRow
{
	// we can't just store the passed in array as that would give an outsider too much control of our internal state
	// (e.g. they could change the bounds after adding it, defeating the check below), so let's make a shallow copy.
	NSMutableArray *newArray = [[NSMutableArray alloc] initWithArray:aRow];
	@try {
		@synchronized(self) {
			// Verify the row is of the correct length
			[self _checkNewRow:newArray];
			[self _addRowUnsafeUnchecked:newArray];
		}
	}
	@finally {
		[newArray release];
	}
}

/**
 * Insert a new row into the storage array at a specified point, pushing
 * all later rows the next index.  Note that the supplied objects within the
 * array are retained as a reference rather than copied.
 */
- (void) insertRowContents:(NSMutableArray *)aRow atIndex:(NSUInteger)anIndex
{
	// we can't just store the passed in array as that would give an outsider too much control of our internal state
	// (e.g. they could change the bounds after adding it, defeating the check below), so let's make a shallow copy.
	NSMutableArray *newArray = [[NSMutableArray alloc] initWithArray:aRow];
	@try {
		@synchronized(self) {
			unsigned long long numberOfRows = SPMySQLResultStoreGetRowCount(dataStorage);
			
			// Verify the row is of the correct length
			[self _checkNewRow:newArray];
			
			// Throw an exception if the index is out of bounds
			if (anIndex > numberOfRows) {
				[NSException raise:NSRangeException format:@"Requested storage index (%llu) beyond bounds (%llu)", (unsigned long long)anIndex, numberOfRows];
			}
			
			// If "inserting" at the end of the array just add a row
			if (anIndex == numberOfRows) {
				[self _addRowUnsafeUnchecked:newArray];
				return;
			}
			
			// Add the new row to the editable store
			[editedRows insertPointer:newArray atIndex:anIndex];
			editedRowCount++;
			
			// Update the underlying store to keep counts and indices correct
			[dataStorage insertDummyRowAtIndex:anIndex];
		}
	}
	@finally {
		[newArray release];
	}
}

/**
 * Replace a row with contents of the supplied NSArray.
 *
 * Note that the supplied objects within the array are retained as a reference rather than copied.
 */
- (void) replaceRowAtIndex:(NSUInteger)anIndex withRowContents:(NSMutableArray *)aRow
{
	// we can't just store the passed in array as that would give an outsider too much control of our internal state
	// (e.g. they could change the bounds after adding it, defeating the check below), so let's make a shallow copy.
	NSMutableArray *newArray = [[NSMutableArray alloc] initWithArray:aRow];
	@try {
		@synchronized(self) {
			[self _checkNewRow:newArray];
			[editedRows replacePointerAtIndex:anIndex withPointer:newArray];
		}
	}
	@finally {
		[newArray release];
	}
}

/**
 * Replace the contents of a single cell with a supplied object.
 */
- (void) replaceObjectInRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex withObject:(id)anObject
{
	NSMutableArray *editableRow = nil;

	@synchronized(self) {
		if (rowIndex < editedRowCount) {
			editableRow = SPDataStorageGetEditedRow(editedRows, rowIndex);
		}

		// Make sure that the row in question is editable
		if (editableRow == nil) {
			editableRow = [self rowContentsAtIndex:rowIndex]; //already returns a copy, so we don't have to go via -replaceRowAtIndex:withRowContents:
			[editedRows replacePointerAtIndex:rowIndex withPointer:editableRow];
		}
	}

	// Modify the cell
	[editableRow replaceObjectAtIndex:columnIndex withObject:anObject];
}

/**
 * Remove a row, renumbering all elements beyond index.
 */
- (void) removeRowAtIndex:(NSUInteger)anIndex
{
	@synchronized(self) {
		// Throw an exception if the index is out of bounds
		if (anIndex >= SPMySQLResultStoreGetRowCount(dataStorage)) {
			[NSException raise:NSRangeException format:@"Requested storage index (%llu) beyond bounds (%llu)", (unsigned long long)anIndex, SPMySQLResultStoreGetRowCount(dataStorage)];
		}

		// Remove the row from the edited list and underlying storage
		if (anIndex < editedRowCount) {
			editedRowCount--;
			[editedRows removePointerAtIndex:anIndex];
		}
		[dataStorage removeRowAtIndex:anIndex];
	}
}

/**
 * Remove all rows in the specified range, renumbering all elements
 * beyond the end of the range.
 */
- (void) removeRowsInRange:(NSRange)rangeToRemove
{
	@synchronized(self) {
		// Throw an exception if the range is out of bounds
		if (NSMaxRange(rangeToRemove) > SPMySQLResultStoreGetRowCount(dataStorage)) {
			[NSException raise:NSRangeException format:@"Requested storage index (%llu) beyond bounds (%llu)", (unsigned long long)(NSMaxRange(rangeToRemove)), SPMySQLResultStoreGetRowCount(dataStorage)];
		}

		// Remove the rows from the edited list and underlying storage
		NSUInteger i = MIN(editedRowCount, NSMaxRange(rangeToRemove));
		while (--i >= rangeToRemove.location) {
			editedRowCount--;
			[editedRows removePointerAtIndex:i];
		}
		[dataStorage removeRowsInRange:rangeToRemove];
	}
}

/**
 * Remove all rows from the array, and free their associated memory.
 */
- (void) removeAllRows
{
	@synchronized(self) {
		editedRowCount = 0;
		[editedRows setCount:0];
		[dataStorage removeAllRows];
	}
}

#pragma mark - Unloaded columns

/**
 * Mark a column as unloaded; SPNotLoaded placeholders will be returned for cells requested
 * from this store which haven't had their value updated from elsewhere.
 */
- (void) setColumnAsUnloaded:(NSUInteger)columnIndex
{
	@synchronized(self) {
		if (columnIndex >= numberOfColumns) {
			[NSException raise:NSRangeException format:@"Invalid column set as unloaded; requested column index (%llu) beyond bounds (%llu)", (unsigned long long)columnIndex, (unsigned long long)numberOfColumns];
		}
		unloadedColumns[columnIndex] = YES;
	}
}

#pragma mark - Basic information

/**
 * Returns the number of rows currently held in data storage.
 */
- (NSUInteger) count
{
	@synchronized(self) {
		return (NSUInteger)[dataStorage numberOfRows];
	}
}

/**
 * Return the number of columns represented by the data storage.
 */
- (NSUInteger) columnCount
{
	@synchronized(self) {
		return numberOfColumns;
	}
}

/**
 * Return whether all the data has been downloaded into the underlying result store.
 */
- (BOOL) dataDownloaded
{
	@synchronized(self) {
		return !dataStorage || [dataStorage dataDownloaded];
	}
}

- (void) awaitDataDownloaded
{
	[dataDownloadedLock lock];
	while(![self dataDownloaded]) [dataDownloadedLock wait];
	[dataDownloadedLock unlock];
}

#pragma mark - Delegate callback methods

/**
 * When the underlying result store finishes downloading, update the row store to match
 */
- (void)resultStoreDidFinishLoadingData:(SPMySQLStreamingResultStore *)resultStore
{
	@synchronized(self) {
		if(resultStore != dataStorage) {
			NSLog(@"%s: received delegate callback from an unknown result store %p (expected: %p). Ignored!", __PRETTY_FUNCTION__, resultStore, dataStorage);
			return;
		}
		[editedRows setCount:(NSUInteger)[resultStore numberOfRows]];
		editedRowCount = [editedRows count];
	}
	[dataDownloadedLock lock];
	[dataDownloadedLock broadcast];
	[dataDownloadedLock unlock];
}

/**
 * Setup and teardown
 */
#pragma mark -

- (id) init
{
	if ((self = [super init])) {
		dataStorage = nil;
		editedRows = nil;
		unloadedColumns = NULL;
		dataDownloadedLock = [NSCondition new];

		numberOfColumns = 0;
		editedRowCount = 0;
	}
	return self;
}

- (void) dealloc
{
	@synchronized(self) {
		SPClear(dataStorage);
		SPClear(editedRows);
		SPClear(dataDownloadedLock);
		if (unloadedColumns) {
			(void)(free(unloadedColumns)), unloadedColumns = NULL;
		}
	}
	
	[super dealloc];
}

#pragma mark - Private API

// DO NOT CALL THIS METHOD UNLESS YOU CURRENTLY HAVE A LOCK ON SELF!!!
- (void) _checkNewRow:(NSMutableArray *)aRow
{
	if ([aRow count] != numberOfColumns) {
		[NSException raise:NSInternalInconsistencyException format:@"New row length (%llu) does not match store column	count (%llu)", (unsigned long long)[aRow count], (unsigned long long)numberOfColumns];
	}
}

// DO NOT CALL THIS METHOD UNLESS YOU CURRENTLY HAVE A LOCK ON SELF!!!
// DO NOT CALL THIS METHOD UNLESS YOU HAVE CALLED _checkNewRow: FIRST!
- (void)_addRowUnsafeUnchecked:(NSMutableArray *)aRow
{
	// Add the new row to the editable store
	[editedRows addPointer:aRow];
	editedRowCount++;
	
	// Update the underlying store as well to keep counts correct
	[dataStorage addDummyRow];
}

@end
