//
//  $Id$
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
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPMySQLResult.h"
#import "SPMySQL Private APIs.h"
#import "SPMySQLArrayAdditions.h"

static SPMySQLResultFieldProcessor fieldProcessingMap[256];
static id NSNullPointer;

@implementation SPMySQLResult

#pragma mark -
#pragma mark Synthesized properties

@synthesize returnDataAsStrings;
@synthesize defaultRowReturnType;

#pragma mark -
#pragma mark Setup and teardown

/**
 * In the one-off class initialisation, set up the result processing map
 */
+ (void)initialize
{

	// Cached NSNull singleton reference
	if (!NSNullPointer) NSNullPointer = [NSNull null];

	// Go through the list of enum_field_types in mysql_com.h, mapping each to the method for
	// processing that result set.
	fieldProcessingMap[MYSQL_TYPE_DECIMAL] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_TINY] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_SHORT] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_LONG] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_FLOAT] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_DOUBLE] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_NULL] = SPMySQLResultFieldAsNull;
	fieldProcessingMap[MYSQL_TYPE_TIMESTAMP] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_LONGLONG] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_INT24] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_DATE] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_TIME] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_DATETIME] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_YEAR] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_NEWDATE] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_VARCHAR] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_BIT] = SPMySQLResultFieldAsBit;
	fieldProcessingMap[MYSQL_TYPE_NEWDECIMAL] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_ENUM] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_SET] = SPMySQLResultFieldAsString;
	fieldProcessingMap[MYSQL_TYPE_TINY_BLOB] = SPMySQLResultFieldAsBlob;
	fieldProcessingMap[MYSQL_TYPE_MEDIUM_BLOB] = SPMySQLResultFieldAsBlob;
	fieldProcessingMap[MYSQL_TYPE_LONG_BLOB] = SPMySQLResultFieldAsBlob;
	fieldProcessingMap[MYSQL_TYPE_BLOB] = SPMySQLResultFieldAsBlob;
	fieldProcessingMap[MYSQL_TYPE_VAR_STRING] = SPMySQLResultFieldAsStringOrBlob;
	fieldProcessingMap[MYSQL_TYPE_STRING] = SPMySQLResultFieldAsStringOrBlob;
	fieldProcessingMap[MYSQL_TYPE_GEOMETRY] = SPMySQLResultFieldAsGeometry;
	fieldProcessingMap[MYSQL_TYPE_DECIMAL] = SPMySQLResultFieldAsString;
}

/**
 * Prevent SPMySQLResults from being init'd normally.
 */
- (id)init
{
	[NSException raise:NSInternalInconsistencyException format:@"SPMySQLResults should not be init'd directly; use initWithMySQLResult:stringEncoding: instead."];
	return nil;
}

/**
 * Standard init method, constructing the SPMySQLResult around a MySQL
 * result pointer and the encoding to use when working with the data.
 */
- (id)initWithMySQLResult:(void *)theResult stringEncoding:(NSStringEncoding)theStringEncoding
{

	// If no result set was passed in, return nil.
	if (!theResult) return nil;

	if ((self = [super init])) {
		stringEncoding = theStringEncoding;
		queryExecutionTime = -1;

		// Get the result set and cache the number of fields and number of rows
		resultSet = theResult;
		numberOfFields = mysql_num_fields(resultSet);
		numberOfRows = mysql_num_rows(resultSet);
		currentRowIndex = 0;

		// Cache the field definitions and build up an array of cached field names and types
		fieldDefinitions = mysql_fetch_fields(resultSet);
		fieldNames = malloc(sizeof(NSString *) * numberOfFields);
		fieldTypes = malloc(sizeof(unsigned int) * numberOfFields);
		for (NSUInteger i = 0; i < numberOfFields; i++) {
			MYSQL_FIELD aField = fieldDefinitions[i];
			fieldNames[i] = [[self _stringWithBytes:aField.name length:aField.name_length] retain];
			fieldTypes[i] = aField.type;
		}

		defaultRowReturnType = SPMySQLResultRowAsDictionary;
	}

	return self;
}

- (void)dealloc
{
	mysql_free_result(resultSet);

	for (NSUInteger i = 0; i < numberOfFields; i++) {
		[fieldNames[i] release];
	}
	free(fieldNames);
	free(fieldTypes);

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
		id cellData = SPMySQLResultGetObject(self, theRow[i], theRowDataLengths[i], fieldTypes[i], i);

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

#pragma mark -
#pragma mark Data conversion

/**
 * Provides a binary representation of the supplied bytes as a returned NSString.
 * The resulting binary representation will be zero-padded according to the supplied
 * field length.
 */
+ (NSString *)bitStringWithBytes:(const char *)bytes length:(NSUInteger)length padToLength:(NSUInteger)padLength
{
	if (bytes == NULL) return nil;

	NSUInteger i = 0;
	length--;
	padLength--;

	// Generate a C string representation of the binary data
	char *cStringBuffer = malloc(length + 1);
	while (i <= padLength) {
		cStringBuffer[padLength - i++] = ( (bytes[length - (i >> 3)] >> (i & 0x7)) & 1 ) ? '1' : '0';
	}
	cStringBuffer[padLength+1] = '\0';

	// Convert to a string
	NSString *returnString = [NSString stringWithUTF8String:cStringBuffer];

	// Free up memory and return
	free(cStringBuffer);
	return returnString;
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

/**
 * Allow setting the execution time for the original query (including connection lag)
 * so it can be requested later without relying on connection state.
 */
- (void)_setQueryExecutionTime:(double)theExecutionTime
{
	queryExecutionTime = theExecutionTime;
}

/**
 * Core data conversion function, taking C data provided by MySQL and converting
 * to an appropriate return type.
 * Note that the data passed in currently is *not* nul-terminated for fast
 * streaming results, which is safe for the current implementation but should be
 * kept in mind for future changes.
 */
- (id)_getObjectFromBytes:(char *)bytes ofLength:(NSUInteger)length fieldType:(unsigned int)fieldType fieldDefinitionIndex:(NSUInteger)fieldIndex
{

	// A NULL pointer for the data indicates a null value; return a NSNull object.
	if (bytes == NULL) return NSNullPointer;

	// Determine the field processor to use
	SPMySQLResultFieldProcessor dataProcessor = fieldProcessingMap[fieldType];

	// Switch the method to process the cell data based on the field type mapping.
	// Do this in two passes: the first as logic may cause a change in processor required.
	switch (dataProcessor) {

		// STRING and VAR_STRING types may be strings or binary types; check the binary flag
		case SPMySQLResultFieldAsStringOrBlob:
			if (fieldDefinitions[fieldIndex].flags & BINARY_FLAG) {
				dataProcessor = SPMySQLResultFieldAsBlob;
			}
			break;

		// Blob types may be automatically be converted to strings, or may be non-binary
		case SPMySQLResultFieldAsBlob:
			if (!(fieldDefinitions[fieldIndex].flags & BINARY_FLAG)) {
				dataProcessor = SPMySQLResultFieldAsString;
			}
			break;

		// In most cases, use the original data processor.
		default:
			break;
	}

	// If this instance is set to convert all data as strings, alter the processor.
	if (returnDataAsStrings && dataProcessor == SPMySQLResultFieldAsBlob) {
		dataProcessor = SPMySQLResultFieldAsString;
	}

	// Now switch the processing method again to actually process the data.
	switch (dataProcessor) {

		// Convert string types using a method that will preserve any nul characters
		// within the string
		case SPMySQLResultFieldAsString:
		case SPMySQLResultFieldAsStringOrBlob:
			return [[[NSString alloc] initWithBytes:bytes length:length encoding:stringEncoding] autorelease];

		// Convert BLOB types to NSData
		case SPMySQLResultFieldAsBlob:
			return [NSData dataWithBytes:bytes length:length];
		
		// For Geometry types, use a special Geometry object to handle their complexity
		case SPMySQLResultFieldAsGeometry:
			return [SPMySQLGeometryData dataWithBytes:bytes length:length];

		// For bit fields, get a zero-padded representation of the data
		case SPMySQLResultFieldAsBit:
			return [SPMySQLResult bitStringWithBytes:bytes length:length padToLength:fieldDefinitions[fieldIndex].length];

		// Convert null types to NSNulls
		case SPMySQLResultFieldAsNull:
			return NSNullPointer;

		case SPMySQLResultFieldAsUnhandled:
			NSLog(@"SPMySQLResult processing encountered an unknown field type (%d), falling back to NSData handling", fieldType);
			return [NSData dataWithBytes:bytes length:length];
	}

	[NSException raise:NSInternalInconsistencyException format:@"Unhandled field type when processing SPMySQLResults"];
	return nil;
}

@end
