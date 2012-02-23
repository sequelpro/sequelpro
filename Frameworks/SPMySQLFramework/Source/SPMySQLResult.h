//
//  $Id$
//
//  SPMySQLResult.h
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


typedef enum {
	SPMySQLResultFieldAsUnhandled    = 0,
	SPMySQLResultFieldAsString       = 1,
	SPMySQLResultFieldAsStringOrBlob = 2,
	SPMySQLResultFieldAsBlob         = 3,
	SPMySQLResultFieldAsBit          = 4,
	SPMySQLResultFieldAsGeometry     = 5,
	SPMySQLResultFieldAsNull         = 6
} SPMySQLResultFieldProcessor;

@interface SPMySQLResult : NSObject <NSFastEnumeration> {

	// Wrapped MySQL result set and its encoding
	struct st_mysql_res *resultSet;
	NSStringEncoding stringEncoding;

	// Number of fields in the result set, and the field names and information
	NSUInteger numberOfFields;
	struct st_mysql_field *fieldDefinitions;
	unsigned int *fieldTypes;
	NSString **fieldNames;
	
	// Number of rows in the result set and an internal data position counter
	unsigned long long numberOfRows;
	unsigned long long currentRowIndex;

	// How long it took to execute the query that produced this result
	double queryExecutionTime;

	// The target result set type for fast enumeration and unspecified row retrieval
	SPMySQLResultRowType defaultRowReturnType;

	// Whether all data should be returned as strings - useful for working with some older server types
	BOOL returnDataAsStrings;
}

// Master init method
- (id)initWithMySQLResult:(void *)theResult stringEncoding:(NSStringEncoding)theStringEncoding;

// Result set information
- (NSUInteger)numberOfFields;
- (unsigned long long)numberOfRows;
- (double)queryExecutionTime;

// Column information
- (NSArray *)fieldNames;

// Data retrieval (note that fast enumeration is also supported, using instance-default format)
- (void)seekToRow:(unsigned long long)targetRow;
- (id)getRow;
- (NSArray *)getRowAsArray;
- (NSDictionary *)getRowAsDictionary;
- (id)getRowAsType:(SPMySQLResultRowType)theType;

// Data conversion
+ (NSString *)bitStringWithBytes:(const char *)bytes length:(NSUInteger)length padToLength:(NSUInteger)padLength;

#pragma mark -
#pragma mark Synthesized properties

/**
 * Set whether the result should return data types as strings.  This may be useful
 * for queries where the result may be returned in either string or data form, but
 * will be converted to string for display and use anyway.
 * Note that certain MySQL versions also return data types for strings - eg SHOW
 * commands like SHOW CREATE TABLE or SHOW VARIABLES, and this conversion can be
 * necessary there.
 */
@property (readwrite, assign) BOOL returnDataAsStrings;

@property (readwrite, assign) SPMySQLResultRowType defaultRowReturnType;

@end

/**
 * Set up a static function to allow fast calling with cached selectors
 */
static inline id SPMySQLResultGetRow(SPMySQLResult* self, SPMySQLResultRowType rowType) 
{
	typedef id (*SPMySQLResultGetRowMethodPtr)(SPMySQLResult*, SEL, SPMySQLResultRowType);
	static SPMySQLResultGetRowMethodPtr cachedMethodPointer;
	static SEL cachedSelector;

	if (!cachedSelector) cachedSelector = @selector(getRowAsType:);
	if (!cachedMethodPointer) cachedMethodPointer = (SPMySQLResultGetRowMethodPtr)[self methodForSelector:cachedSelector];

	return cachedMethodPointer(self, cachedSelector, rowType);
}
