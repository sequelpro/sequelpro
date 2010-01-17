//
//  $Id$
//
//  SPDataStorage.m
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

#import "SPDataStorage.h"

@interface SPDataStorage (PrivateAPI)

- (void) _ensureCapacityForAdditionalRowCount:(NSUInteger)numExtraRows;
- (void) _increaseCapacity;

@end


@implementation SPDataStorage

static inline void SPDataStorageEnsureCapacityForAdditionalRowCount(SPDataStorage* self, NSUInteger numExtraRows) {
	typedef void (*SPDSEnsureCapacityMethodPtr)(SPDataStorage*, SEL, NSUInteger);
	static SPDSEnsureCapacityMethodPtr SPDSEnsureCapacity;
	if (!SPDSEnsureCapacity) SPDSEnsureCapacity = (SPDSEnsureCapacityMethodPtr)[self methodForSelector:@selector(_ensureCapacityForAdditionalRowCount:)];
	SPDSEnsureCapacity(self, @selector(_ensureCapacityForAdditionalRowCount:), numExtraRows);
}

#pragma mark -
#pragma mark Retrieving rows and cells

/**
 * Return a mutable array containing the data for a specified row.
 */
- (NSMutableArray *) rowContentsAtIndex:(NSUInteger)index
{

	// Throw an exception if the index is out of bounds
	if (index >= numRows) [NSException raise:NSRangeException format:@"Requested storage index beyond bounds"];

	// Construct the NSMutableArray
	NSMutableArray *rowArray = [NSMutableArray arrayWithCapacity:numColumns];
	id *row = dataStorage[index];
	NSUInteger i;
	for (i = 0; i < numColumns; i++) {
		CFArrayAppendValue((CFMutableArrayRef)rowArray, row[i]);
	}

	return rowArray;
}

/**
 * Return the data at a specified row and column index.
 */
- (id) cellDataAtRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex
{

	// Throw an exception if the row or column index is out of bounds
	if (rowIndex >= numRows || columnIndex >= numColumns) [NSException raise:NSRangeException format:@"Requested storage index beyond bounds"];

	// Return the content
	return dataStorage[rowIndex][columnIndex];
}

#pragma mark -
#pragma mark Retrieving rows via NSFastEnumeration

/**
 * Implementation of the NSFastEnumeration protocol.
 * Note that this currently doesn't implement mutation guards.
 */
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len
{

	// If the start index is out of bounds, return 0 to indicate end of results
	if (state->state >= numRows) return 0;

	// Determine how many objects to return - 128, len, or all items remaining
	NSUInteger itemsToReturn = 128;
	if (len < 128) itemsToReturn = len;
	if (numRows - state->state < itemsToReturn) {
		itemsToReturn = numRows - state->state;
	}

	// Construct the arrays to return
	NSUInteger i, j;
	NSMutableArray *rowArray;
	id *row;
	for (i = 0; i < itemsToReturn; i++) {
		row = dataStorage[state->state + i];
		rowArray = [NSMutableArray arrayWithCapacity:numColumns];
		for (j = 0; j < numColumns; j++) {
			CFArrayAppendValue((CFMutableArrayRef)rowArray, row[j]);
		}
		stackbuf[i] = rowArray;
	}

	state->state += itemsToReturn;
	state->itemsPtr = stackbuf;
	state->mutationsPtr = (unsigned long *)&numRows;
	return itemsToReturn;
}

#pragma mark -
#pragma mark Adding and amending rows and cells

/**
 * Add a new row to the end of the storage array, supplying an NSArray
 * of objects.  Note that the supplied objects are retained as a reference
 * rather than copied.
 */
- (void) addRowWithContents:(NSArray *)row
{
	
	// Ensure that sufficient capacity is available
	SPDataStorageEnsureCapacityForAdditionalRowCount(self, 1);

	// Add an empty row array to the data store
	id *newRow = (id *)malloc(columnPointerByteSize);
	dataStorage[numRows] = newRow;
	numRows++;

	// Copy over references to the array contents, and retain the objects
	NSUInteger cellsCopied = 0;
	for (id cellData in row) {
		if (cellData) newRow[cellsCopied] = (id)CFRetain(cellData);
		else newRow[cellsCopied] = nil;
		if (++cellsCopied == numColumns) break;
	}

	// If an array shorter than the row width was added, pad with nils
	if (cellsCopied < numColumns) {
		for ( ; cellsCopied <= numColumns; cellsCopied++) newRow[cellsCopied] = nil;
	}
}

/**
 * Insert a new row into the storage array at a specified point, pushing
 * all later rows the next index.  Note that the supplied objects within the
 * array are retained as a reference rather than copied.
 */
- (void) insertRowContents:(NSArray *)row atIndex:(NSUInteger)index
{

	// Throw an exception if the index is out of bounds
	if (index > numRows) [NSException raise:NSRangeException format:@"Requested storage index beyond bounds"];

	// If "inserting" at the end of the array just add a row
	if (index == numRows) return SPDataStorageAddRow(self, row);

	// Ensure that sufficient capacity is available to hold all the rows
	SPDataStorageEnsureCapacityForAdditionalRowCount(self, 1);

	// Renumber the specified index, and all subsequent indices, to create a gap
	for (NSUInteger j = numRows - 1; j >= index; j--) {
		dataStorage[j + 1] = dataStorage[j];
	}

	// Add a new instantiated row array to the data store at the specified point
	id *newRow = (id *)malloc(columnPointerByteSize);
	dataStorage[index] = newRow;
	numRows++;

	// Copy over references to the array contents, and retain the objects
	NSUInteger cellsCopied = 0;
	for (id cellData in row) {
		if (cellData) newRow[cellsCopied] = (id)CFRetain(cellData);
		else newRow[cellsCopied] = nil;
		if (++cellsCopied == numColumns) break;
	}

	// If an array shorter than the row width was inserted, pad with nils
	if (cellsCopied < numColumns) {
		for ( ; cellsCopied <= numColumns; cellsCopied++) newRow[cellsCopied] = nil;
	}
}

/**
 * Replace a row with contents of the supplied NSArray.
 */
- (void) replaceRowAtIndex:(NSUInteger)index withRowContents:(NSArray *)row
{
	NSUInteger cellsProcessed = 0;

	// Throw an exception if the index is out of bounds
	if (index >= numRows) [NSException raise:NSRangeException format:@"Requested storage index beyond bounds"];

	id *storageRow = dataStorage[index];

	// Iterate through the row replacing the objects
	for (id cellData in row) {
		if (storageRow[cellsProcessed]) CFRelease(storageRow[cellsProcessed]);
		if (cellData) storageRow[cellsProcessed] = (id)CFRetain(cellData);
		else storageRow[cellsProcessed] = nil;
		if (++cellsProcessed == numColumns) break;
	}

	// Ensure all cells are correctly updated if an array shorter than the row width was supplied
	if (cellsProcessed < numColumns) {
		for ( ; cellsProcessed <= numColumns; cellsProcessed++) {
			if (storageRow[cellsProcessed]) CFRelease(storageRow[cellsProcessed]);
			storageRow[cellsProcessed] = nil;
		}
	}
}

/**
 * Replace the contents of a single cell with a supplied object.
 */
- (void) replaceObjectInRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex withObject:(id)object
{

	// Throw an exception of either index is out of bounds
	if (rowIndex >= numRows || columnIndex >= numColumns) [NSException raise:NSRangeException format:@"Requested storage index beyond bounds"];

	// Release the old object and retain the new one
	if (dataStorage[rowIndex][columnIndex]) CFRelease(dataStorage[rowIndex][columnIndex]);
	if (object) dataStorage[rowIndex][columnIndex] = (id)CFRetain(object);
	else dataStorage[rowIndex][columnIndex] = nil;
}

/**
 * Remove a row, renumbering all elements beyond index.
 */
- (void) removeRowAtIndex:(NSUInteger)index
{

	// Throw an exception if the index is out of bounds
	if (index >= numRows) [NSException raise:NSRangeException format:@"Requested storage index beyond bounds"];

	// Free the row
	NSUInteger j = numColumns;
	id *row = dataStorage[index];
	while (j > 0) {
		if (row[--j]) CFRelease(row[j]);
	}
	free(row);
	numRows--;

	// Renumber all subsequent indices to fill the gap
	for (j = index; j < numRows; j++) {
		dataStorage[j] = dataStorage[j + 1];
	}
	dataStorage[numRows] = NULL;
}

/**
 * Remove all rows in the specified range, renumbering all elements
 * beyond the end of the range.
 */
- (void) removeRowsInRange:(NSRange)rangeToRemove
{

	// Throw an exception if the range is out of bounds
	if (rangeToRemove.location + rangeToRemove.length >= numRows) [NSException raise:NSRangeException format:@"Requested storage index beyond bounds"];

	// Free rows in the range
	NSUInteger i, j = numColumns;
	id *row;
	for (i = rangeToRemove.location; i < rangeToRemove.location + rangeToRemove.length; i++) {
		row = dataStorage[i];
		while (j > 0) {
			if (row[--j]) CFRelease(row[j]);
		}
		free(row);	
	}
	numRows -= rangeToRemove.length;

	// Renumber all subsequent indices to fill the gap
	for (i = rangeToRemove.location + rangeToRemove.length - 1; i < numRows; i++) {
		dataStorage[i] = dataStorage[i + rangeToRemove.length];
	}
	for (i = numRows; i < numRows + rangeToRemove.length; i++) {
		dataStorage[i] = NULL;
	}
}

/**
 * Remove all rows from the array, and free their associated memory.
 */
- (void) removeAllRows
{
	NSUInteger j;
	id *row;

	// Free all the data
	while (numRows > 0) {
		row = dataStorage[--numRows];
		j = numColumns;
		while (j > 0) {
			if (row[--j]) CFRelease(row[j]);
		}
		free(row);
	}

	numRows = 0;
}

#pragma mark -
#pragma mark Basic information

/**
 * Returns the number of rows currently held in data storage.
 */
- (NSUInteger) count
{
	return numRows;
}

/**
 * Set the number of columns represented by the data storage.
 */
- (void) setColumnCount:(NSUInteger)columnCount
{
	columnPointerByteSize = columnCount * sizeof(id);

	// If there are rows present in the storage, and the number of
	// columns has changed, amend the existing rows to match.
	if (columnCount != numColumns && numRows) {
		NSUInteger i = numRows, j;
		id *row;

		// If the new column count is higher than the old count, iterate through the existing rows
		// and pad with nils
		if (columnCount > numColumns) {
			while (i > 0) {
				row = dataStorage[--i];
				row = (id *)realloc(row, columnPointerByteSize);
				j = numColumns;
				while (j < columnCount) {
					row[j++] = nil;
				}
			}

		// If the new column count is lower than the old count, iterate through the existing rows
		// freeing any extra objects
		} else {
			while (i > 0) {
				row = dataStorage[--i];
				j = numColumns;
				while (j > columnCount) {
					if (row[--j]) CFRelease(row[j]);
				}
				row = (id *)realloc(row, columnPointerByteSize);
			}
		}
	}

	// Update the column count
	numColumns = columnCount;
}

/**
 * Return the number of columns represented by the data storage.
 */
- (NSUInteger) columnCount
{
	return numColumns;
}

/**
 * Setup and teardown
 */
#pragma mark -

- (id) init {
	if (self = [super init]) {
		numColumns = 0;
		columnPointerByteSize = 0;
		numRows = 0;

		// Initialise the array, initially with space for 100 rows
		numRowsCapacity = 100;
		dataStorage = (id **)malloc(numRowsCapacity * sizeof(id *));
	}
	return self;
}

- (void) dealloc {
	[self removeAllRows];
	free(dataStorage);
	[super dealloc];
}

@end

@implementation SPDataStorage (PrivateAPI)

/**
 * Private method to ensure the array always has sufficient capacity
 * to store any additional rows required.
 */
- (void) _ensureCapacityForAdditionalRowCount:(NSUInteger)numExtraRows
{
	while (numRows + numExtraRows > numRowsCapacity) [self _increaseCapacity];
}

/**
 * Private method to increase the storage available for the array;
 * currently doubles the capacity as boundaries are reached.
 */
- (void) _increaseCapacity
{
	numRowsCapacity *= 2;
	dataStorage = (id **)realloc(dataStorage, numRowsCapacity * sizeof(id *));
}

@end
