//
//  SPMySQLResult.m
//  SPMySQLFramework
//
//  Created by Rowan Beentje (rowan.beent.je) on January 26, 2012
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
//  More info at <https://github.com/sequelpro/sequelpro>

#import "SPMySQLResult.h"
#import "SPMySQL Private APIs.h"
#import "SPMySQLArrayAdditions.h"
#include <stdlib.h>

static id NSNullPointer;

@implementation SPMySQLResult

#pragma mark -
#pragma mark Synthesized properties

@synthesize returnDataAsStrings;
@synthesize defaultRowReturnType;

#pragma mark -
#pragma mark Setup and teardown

+ (void)initialize
{

	// Cached NSNull singleton reference
	if (!NSNullPointer) NSNullPointer = [NSNull null];

	// Set up data conversion details
	[self _initializeDataConversion];
}

/**
 * Standard initialisation - not intended for external use.
 */
- (id)init
{
	if ((self = [super init])) {
		stringEncoding = NSASCIIStringEncoding;
		queryExecutionTime = -1;

		resultSet = NULL;
		numberOfFields = 0;
		numberOfRows = 0;
		currentRowIndex = 0;

		fieldDefinitions = NULL;
		fieldNames = NULL;

		defaultRowReturnType = SPMySQLResultRowAsDictionary;
	}

	return self;
}

/**
 * Standard init method, constructing the SPMySQLResult around a MySQL
 * result pointer and the encoding to use when working with the data.
 */
- (id)initWithMySQLResult:(void *)theResult stringEncoding:(NSStringEncoding)theStringEncoding
{

	// If no result set was passed in, return nil.
	if (!theResult) return nil;

	if ((self = [self init])) {
		stringEncoding = theStringEncoding;

		// Get the result set and cache the number of fields and number of rows
		resultSet = theResult;
		numberOfFields = mysql_num_fields(resultSet);
		numberOfRows = mysql_num_rows(resultSet);

		// Cache the field definitions and build up an array of cached field names and types
		fieldDefinitions = mysql_fetch_fields(resultSet);
		fieldNames = calloc(numberOfFields,sizeof(NSString *));
		for (NSUInteger i = 0; i < numberOfFields; i++) {
			MYSQL_FIELD aField = fieldDefinitions[i];
			fieldNames[i] = [[self _stringWithBytes:aField.name length:aField.name_length] retain];
		}
	}

	return self;
}

- (void)dealloc
{
	if (resultSet) {
		mysql_free_result(resultSet);

		for (NSUInteger i = 0; i < numberOfFields; i++) {
			[fieldNames[i] release];
		}
		free(fieldNames);
	}

	[super dealloc];
}

#pragma mark -
#pragma mark Result set information

/**
 * Return the number of fields in the result set.
 */
- (NSUInteger)numberOfFields
{
	return numberOfFields;
}

/**
 * Return the number of data rows in the result set.
 */
- (unsigned long long)numberOfRows
{
	return numberOfRows;
}

/**
 * Return how long the original query took to execute - including connection lag!
 */
- (double)queryExecutionTime
{
	return queryExecutionTime;
}

#pragma mark -
#pragma mark Column information

/**
 * Retrieve the field names for the result set, as an NSArray of NSStrings.
 */
- (NSArray *)fieldNames
{
	return [NSArray arrayWithObjects:fieldNames count:numberOfFields];
}

/**
 * For field definitions, see Result Categories/Field Definitions.h/m
 */

#pragma mark -
#pragma mark Data retrieval

/**
 * Jump to a specified row in the result set; when the result set is initialised,
 * the internal pointer automatically starts at 0.
 */
- (void)seekToRow:(unsigned long long)targetRow
{
	if (targetRow == currentRowIndex) return;

	if (targetRow >= numberOfRows) {
		targetRow = numberOfRows - 1;
	}

	mysql_data_seek(resultSet, targetRow);
	currentRowIndex = targetRow;
}

/**
 * Retrieve the next row in the result set, using the internal pointer, in the
 * instance-specified setDefaultRowReturnType: row format (defaulting to NSDictionary).
 * If there are no rows remaining, returns nil.
 */
- (id)getRow
{
	return SPMySQLResultGetRow(self, SPMySQLResultRowAsDefault);
}

/**
 * Retrieve the next row in the result set, using the internal pointer, in the
 * instance-specified setDefaultRowReturnType: row format (defaulting to NSDictionary).
 * If there are no rows remaining, returns nil.
 */
- (NSArray *)getRowAsArray
{
	return SPMySQLResultGetRow(self, SPMySQLResultRowAsArray);
}

/**
 * Retrieve the next row in the result set, using the internal pointer, in the
 * instance-specified setDefaultRowReturnType: row format (defaulting to NSDictionary).
 * If there are no rows remaining, returns nil.
 */
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
	MYSQL_ROW theRow;
	unsigned long *theRowDataLengths;
	id theReturnData;

	// Retrieve the row in MySQL format, and the length of the data within the row
	theRow = mysql_fetch_row(resultSet);
	theRowDataLengths = mysql_fetch_lengths(resultSet);

	// If no row was returned, likely at the end of the result set - return nil
	if (!theRow) return nil;

	// If the target type was unspecified, use the instance default
	if (theType == SPMySQLResultRowAsDefault) theType = defaultRowReturnType;

	// Set up the return data as appropriate
	if (theType == SPMySQLResultRowAsArray) {
		theReturnData = [NSMutableArray arrayWithCapacity:numberOfFields];
	} else {
		theReturnData = [NSMutableDictionary dictionaryWithCapacity:numberOfFields];
	}

	// Convert each of the cells in the row in turn
	for (NSUInteger i = 0; i < numberOfFields; i++) {
		id cellData = SPMySQLResultGetObject(self, theRow[i], theRowDataLengths[i], i, NSNotFound);

		// If object creation failed, display a null
		if (!cellData) cellData = NSNullPointer;

		// Add to the result array/dictionary
		if (theType == SPMySQLResultRowAsArray) {
			SPMySQLMutableArrayInsertObject(theReturnData, cellData, i);
		} else {
			[(NSMutableDictionary *)theReturnData setObject:cellData forKey:fieldNames[i]];
		}
	}

	// Increment the row pointer index and set to NSNotFound if the end of the result set has
	// been reached
	currentRowIndex++;
	if (currentRowIndex > numberOfRows) currentRowIndex = NSNotFound;

	return theReturnData;
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

	// If the start index is out of bounds, return 0 to indicate end of results
	if (state->state >= numberOfRows) return 0;

	// Sync up the MySQL pointer position with the requested state if necessary
	if (state->state != currentRowIndex) [self seekToRow:state->state];

	// Determine how many objects to return - 128, len, or all items remaining
	NSUInteger itemsToReturn = 128;
	if (len < 128) itemsToReturn = len;
	if (numberOfRows - state->state < itemsToReturn) {
		itemsToReturn = (unsigned long)(numberOfRows - state->state);
	}

	// Loop through the rows and add them to the result stack
	NSUInteger i;
	for (i = 0; i < itemsToReturn; i++) {
		stackbuf[i] = SPMySQLResultGetRow(self, SPMySQLResultRowAsDefault);
	}

	state->state += itemsToReturn;
	state->itemsPtr = stackbuf;
	state->mutationsPtr = (unsigned long *)self;

	return itemsToReturn;
}

@end

#pragma mark -
#pragma mark Result set internals

@implementation SPMySQLResult (Private_API)

/**
 * Support internal string conversions which take a supplied byte sequence and length
 * and convert them to an NSString using the instance encoding.  Will preserve nul
 * characters within the string.
 */
- (id)_stringWithBytes:(const void *)bytes length:(NSUInteger)length
{
	return [[[NSString alloc] initWithBytes:bytes length:length encoding:stringEncoding] autorelease];
}
#warning duplicate code with Data Conversion.m stringForDataBytes:length:encoding: (↑, ↓)
- (NSString *)_lossyStringWithBytes:(const void *)bytes length:(NSUInteger)length wasLossy:(BOOL *)outLossy
{
	if(!bytes || !length) return @""; //to match -[NSString initWithBytes:length:encoding:]
	
	//mysql protocol limits column names to 256 bytes.
	//with inline columns and multibyte charsets this can result in a character
	//being split in half at which the method above will fail.
	//Let's first try removing stuff from the end to create something valid.
	NSUInteger removed = 0;
	do {
		NSString *res = [self _stringWithBytes:bytes length:(length-removed)];
		if(res) {
			if(outLossy) *outLossy = (removed != 0);
			return (removed? [NSString stringWithFormat:@"%@…",res] : res);
		}
		removed++;
	} while(removed <= 10 && removed < length); // 10 is arbitrary
	
	//if that fails, ascii should accept all values from 0-255 as input
	NSString *ascii = [[NSString alloc] initWithBytes:bytes length:length encoding:NSASCIIStringEncoding];
	if(ascii){
		if(outLossy) *outLossy = YES;
		return [ascii autorelease];
	}
	
	//if even that failed we lose.
	NSDictionary *info = @{ @"data": [NSData dataWithBytes:bytes length:length] };
	NSString *reason = [NSString stringWithFormat:@"Failed to convert byte sequence %@ to string (encoding = %lu)",[info objectForKey:@"data"],stringEncoding];
	@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:reason userInfo:info];
}

/**
 * Allow setting the execution time for the original query (including connection lag)
 * so it can be requested later without relying on connection state.
 */
- (void)_setQueryExecutionTime:(double)theExecutionTime
{
	queryExecutionTime = theExecutionTime;
}

@end
