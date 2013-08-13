//
//  $Id$
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
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPDataStorage.h"
#import "SPObjectAdditions.h"
#import <SPMySQL/SPMySQLStreamingResultStore.h>

@interface SPDataStorage (Private_API)

- (void) _checkNewRow:(NSMutableArray *)aRow;

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
	NSUInteger i;
	[editedRows release], editedRows = nil;
	if (unloadedColumns) free(unloadedColumns), unloadedColumns = NULL;

	if (dataStorage) {

		// If the table is reloading data, link to the current data store for smoother loads
		if (updateExistingStore) {
			[newDataStorage replaceExistingResultStore:dataStorage];
		}

		[dataStorage release], dataStorage = nil;
	}

	dataStorage = [newDataStorage retain];
	[dataStorage setDelegate:self];

	numberOfColumns = [dataStorage numberOfFields];
	editedRows = [NSPointerArray new];
	if ([dataStorage dataDownloaded]) {
		[self resultStoreDidFinishLoadingData:dataStorage];
	}

	unloadedColumns = malloc(numberOfColumns * sizeof(BOOL));
	for (i = 0; i < numberOfColumns; i++) {
		unloadedColumns[i] = NO;
	}
}


#pragma mark -
#pragma mark Retrieving rows and cells

/**
 * Return a mutable array containing the data for a specified row.
 */
- (NSMutableArray *) rowContentsAtIndex:(NSUInteger)anIndex
{

	// If an edited row exists for the supplied index, return it
	NSMutableArray *editedRow = SPDataStorageGetEditedRow(editedRows, anIndex);
	if (editedRow != NULL) {
		return editedRow;
	}

	// Otherwise, prepare to return the underlying storage row
	NSMutableArray *dataArray = SPMySQLResultStoreGetRow(dataStorage, anIndex);

	// Modify unloaded cells as appropriate
	for (NSUInteger i = 0; i < numberOfColumns; i++) {
		if (unloadedColumns[i]) {
			CFArraySetValueAtIndex((CFMutableArrayRef)dataArray, i, [SPNotLoaded notLoaded]);
		}
	}

	return dataArray;
}

/**
 * Return the data at a specified row and column index.
 */
- (id) cellDataAtRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex
{

	// If an edited row exists at the supplied index, return it
	NSMutableArray *editedRow = SPDataStorageGetEditedRow(editedRows, rowIndex);
	if (editedRow != NULL) {
		return CFArrayGetValueAtIndex((CFArrayRef)editedRow, columnIndex);
	}

	// Throw an exception if the column index is out of bounds
	if (columnIndex >= numberOfColumns) {
		[NSException raise:NSRangeException format:@"Requested storage column (col %llu) beyond bounds (%llu)", (unsigned long long)columnIndex, (unsigned long long)numberOfColumns];
	}

	// If the specified column is not loaded, return a SPNotLoaded reference
	if (unloadedColumns[columnIndex]) {
		return [SPNotLoaded notLoaded];
	}

	// Return the content
	return SPMySQLResultStoreObjectAtRowAndColumn(dataStorage, rowIndex, columnIndex);
}

/**
 * Return a preview of the data at a specified row and column index, limited
 * to approximately the supplied length.
 */
- (id) cellPreviewAtRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex previewLength:(NSUInteger)previewLength
{

	// If an edited row exists at the supplied index, return it
	NSMutableArray *editedRow = SPDataStorageGetEditedRow(editedRows, rowIndex);
	if (editedRow != NULL) {
		id anObject = CFArrayGetValueAtIndex((CFArrayRef)editedRow, columnIndex);
		if ([anObject isKindOfClass:[NSString class]] && [(NSString *)anObject length] > 150) {
			return ([NSString stringWithFormat:@"%@...", [anObject substringToIndex:147]]);
		}
		return anObject;
	}

	// Throw an exception if the column index is out of bounds
	if (columnIndex >= numberOfColumns) {
		[NSException raise:NSRangeException format:@"Requested storage column (col %llu) beyond bounds (%llu)", (unsigned long long)columnIndex, (unsigned long long)numberOfColumns];
	}

	// If the specified column is not loaded, return a SPNotLoaded reference
	if (unloadedColumns[columnIndex]) {
		return [SPNotLoaded notLoaded];
	}

	// Return the content
	return SPMySQLResultStorePreviewAtRowAndColumn(dataStorage, rowIndex, columnIndex, previewLength);
}

/**
 * Returns whether the data at a specified row and column index is NULL or unloaded
 */
- (BOOL) cellIsNullOrUnloadedAtRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex
{
	// If an edited row exists at the supplied index, check it for a NULL.
	NSMutableArray *editedRow = SPDataStorageGetEditedRow(editedRows, rowIndex);
	if (editedRow != NULL) {
		return [(id)CFArrayGetValueAtIndex((CFArrayRef)editedRow, columnIndex) isNSNull];
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

#pragma mark -
#pragma mark Retrieving rows via NSFastEnumeration

/**
 * Implementation of the NSFastEnumeration protocol.
 * Note that rows are currently retrieved individually to avoid mutation and locking issues,
 * although this could be improved on.
 */
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len
{

	// If the start index is out of bounds, return 0 to indicate end of results
	if (state->state >= SPMySQLResultStoreGetRowCount(dataStorage)) return 0;

	// If an edited row exists for the supplied index, use that; otherwise use the underlying
	// storage row
	NSMutableArray *targetRow = SPDataStorageGetEditedRow(editedRows, state->state);
	if (targetRow == NULL) {
		targetRow = SPMySQLResultStoreGetRow(dataStorage, state->state);

		// Modify unloaded cells as appropriate
		for (NSUInteger i = 0; i < numberOfColumns; i++) {
			if (unloadedColumns[i]) {
				CFArraySetValueAtIndex((CFMutableArrayRef)targetRow, i, [SPNotLoaded notLoaded]);
			}
		}
	}

	// Add the item to the buffer and return the appropriate state
	stackbuf[0] = targetRow;

	state->state += 1;
	state->itemsPtr = stackbuf;
	state->mutationsPtr = (unsigned long *)self;

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

	// Verify the row is of the correct length
	[self _checkNewRow:aRow];

	// Add the new row to the editable store
	[editedRows addPointer:aRow];

	// Update the underlying store as well to keep counts correct
	[dataStorage addDummyRow];
}

/**
 * Insert a new row into the storage array at a specified point, pushing
 * all later rows the next index.  Note that the supplied objects within the
 * array are retained as a reference rather than copied.
 */
- (void) insertRowContents:(NSMutableArray *)aRow atIndex:(NSUInteger)anIndex
{
	unsigned long long numberOfRows = SPMySQLResultStoreGetRowCount(dataStorage);

	// Verify the row is of the correct length
	[self _checkNewRow:aRow];

	// Throw an exception if the index is out of bounds
	if (anIndex > numberOfRows) {
		[NSException raise:NSRangeException format:@"Requested storage index (%llu) beyond bounds (%llu)", (unsigned long long)anIndex, numberOfRows];
	}

	// If "inserting" at the end of the array just add a row
	if (anIndex == numberOfRows) {
		return [self addRowWithContents:aRow];
	}

	// Add the new row to the editable store
	[editedRows insertPointer:aRow atIndex:anIndex];

	// Update the underlying store to keep counts and indices correct
	[dataStorage insertDummyRowAtIndex:anIndex];
}

/**
 * Replace a row with contents of the supplied NSArray.
 */
- (void) replaceRowAtIndex:(NSUInteger)anIndex withRowContents:(NSMutableArray *)aRow
{
	[self _checkNewRow:aRow];
	[editedRows replacePointerAtIndex:anIndex withPointer:aRow];
}

/**
 * Replace the contents of a single cell with a supplied object.
 */
- (void) replaceObjectInRow:(NSUInteger)rowIndex column:(NSUInteger)columnIndex withObject:(id)anObject
{

	// Make sure that the row in question is editable
	NSMutableArray *editableRow = SPDataStorageGetEditedRow(editedRows, rowIndex);
	if (editableRow == NULL) {
		editableRow = [self rowContentsAtIndex:rowIndex];
		[editedRows replacePointerAtIndex:rowIndex withPointer:editableRow];
	}

	// Modify the cell
	[editableRow replaceObjectAtIndex:columnIndex withObject:anObject];
}

/**
 * Remove a row, renumbering all elements beyond index.
 */
- (void) removeRowAtIndex:(NSUInteger)anIndex
{

	// Throw an exception if the index is out of bounds
	if (anIndex >= SPMySQLResultStoreGetRowCount(dataStorage)) {
		[NSException raise:NSRangeException format:@"Requested storage index (%llu) beyond bounds (%llu)", (unsigned long long)anIndex, SPMySQLResultStoreGetRowCount(dataStorage)];
	}

	// Remove the row from the edited list and underlying storage
	[editedRows removePointerAtIndex:anIndex];
	[dataStorage removeRowAtIndex:anIndex];
}

/**
 * Remove all rows in the specified range, renumbering all elements
 * beyond the end of the range.
 */
- (void) removeRowsInRange:(NSRange)rangeToRemove
{

	// Throw an exception if the range is out of bounds
	if (rangeToRemove.location + rangeToRemove.length > SPMySQLResultStoreGetRowCount(dataStorage)) {
		[NSException raise:NSRangeException format:@"Requested storage index (%llu) beyond bounds (%llu)", (unsigned long long)(rangeToRemove.location + rangeToRemove.length), SPMySQLResultStoreGetRowCount(dataStorage)];
	}

	// Remove the rows from the edited list and underlying storage
	NSUInteger i = rangeToRemove.location + rangeToRemove.length;
	while (--i >= rangeToRemove.location) {
		[editedRows removePointerAtIndex:i];
	}
	[dataStorage removeRowsInRange:rangeToRemove];
}

/**
 * Remove all rows from the array, and free their associated memory.
 */
- (void) removeAllRows
{
	[editedRows setCount:0];
	[dataStorage removeAllRows];
}

#pragma mark - Unloaded columns

/**
 * Mark a column as unloaded; SPNotLoaded placeholders will be returned for cells requested
 * from this store which haven't had their value updated from elsewhere.
 */
- (void) setColumnAsUnloaded:(NSUInteger)columnIndex
{
	if (columnIndex >= numberOfColumns) {
		[NSException raise:NSRangeException format:@"Invalid column set as unloaded; requested column index (%llu) beyond bounds (%llu)", (unsigned long long)columnIndex, (unsigned long long)numberOfColumns];
	}
	unloadedColumns[columnIndex] = true;
}

#pragma mark - Basic information

/**
 * Returns the number of rows currently held in data storage.
 */
- (NSUInteger) count
{
	return (NSUInteger)[dataStorage numberOfRows];
}

/**
 * Return the number of columns represented by the data storage.
 */
- (NSUInteger) columnCount
{
	return numberOfColumns;
}

/**
 * Return whether all the data has been downloaded into the underlying result store.
 */
- (BOOL) dataDownloaded
{
	return [dataStorage dataDownloaded];
}

#pragma mark - Delegate callback methods

/**
 * When the underlying result store finishes downloading, update the row store to match
 */
- (void)resultStoreDidFinishLoadingData:(SPMySQLStreamingResultStore *)resultStore
{
	[editedRows setCount:(NSUInteger)[resultStore numberOfRows]];
}

/**
 * Setup and teardown
 */
#pragma mark -

- (id) init {
	if ((self = [super init])) {
		dataStorage = nil;
		editedRows = nil;
		unloadedColumns = NULL;

		numberOfColumns = 0;
	}
	return self;
}

- (void) dealloc {
	[dataStorage release], dataStorage = nil;
	[editedRows release], editedRows = nil;
	if (unloadedColumns) free(unloadedColumns), unloadedColumns = NULL;

	[super dealloc];
}

@end

@implementation SPDataStorage (PrivateAPI)

- (void) _checkNewRow:(NSMutableArray *)aRow
{
	if ([aRow count] != numberOfColumns) {
		[NSException raise:NSInternalInconsistencyException format:@"New row length (%llu) does not match store column	count (%llu)", (unsigned long long)[aRow count], (unsigned long long)numberOfColumns];
	}
}


@end
