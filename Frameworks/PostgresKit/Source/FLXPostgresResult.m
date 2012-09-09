//
//  $Id$
//
//  FLXPostgresResult.m
//  PostgresKit
//
//  Copyright (c) 2008-2009 David Thorpe, djt@mutablelogic.com
//
//  Forked by the Sequel Pro Team on July 22, 2012.
// 
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not 
//  use this file except in compliance with the License. You may obtain a copy of 
//  the License at
// 
//  http://www.apache.org/licenses/LICENSE-2.0
// 
//  Unless required by applicable law or agreed to in writing, software 
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT 
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the 
//  License for the specific language governing permissions and limitations under
//  the License.

#import "FLXPostgresResult.h"
#import "FLXPostgresException.h"
#import "FLXPostgresConnection.h"
#import "FLXPostgresConnectionTypeHandling.h"

static NSString *FLXPostgresResultError = @"FLXPostgresResultError";

@interface FLXPostgresResult ()

- (void)_populateFields;
- (id)_objectForRow:(NSUInteger)row column:(NSUInteger)column; 
- (id <FLXPostgresTypeHandlerProtocol>)_typeHandlerForColumn:(NSUInteger)column withType:(FLXPostgresOid)type;

@end

@implementation FLXPostgresResult

@synthesize numberOfRows = _numberOfRows;
@synthesize numberOfFields = _numberOfFields;
@synthesize stringEncoding = _stringEncoding;

#pragma mark -
#pragma mark Initialisation

/**
 * Prevent normal initialisation.
 *
 * @return nil
 */
- (id)init
{
	[FLXPostgresException raise:NSInternalInconsistencyException reason:@"%@ shouldn't be init'd directly; use initWithResult:connection: instead.", [self className]];
	
	return nil;
}

/**
 * Initialises a result with the supplied details.
 *
 * @param result     The underlying PostgreSQL result this wrapper represents.
 * @param connection The connection the result came from.
 *
 * @return The result wrapper.
 */
- (id)initWithResult:(void *)result connection:(FLXPostgresConnection *)connection 
{		
	if ((self = [super init])) {
		
		_row = 0;
		_result = result;
		_numberOfRows = PQntuples(_result);
		_numberOfFields = PQnfields(_result);
		_connection = [connection retain];
		
		_stringEncoding = [_connection stringEncoding];
		
		_typeHandlers = (void **)calloc(sizeof(void *), _numberOfFields);
		
		unsigned long long affectedRows = (unsigned long long)[[NSString stringWithUTF8String:PQcmdTuples(_result)] longLongValue];
		
		_numberOfRows = PQresultStatus(_result) == PGRES_TUPLES_OK ? _numberOfRows : affectedRows;

		[self _populateFields];
	}
	
	return self;
}

#pragma mark -
#pragma mark Public API

/**
 * This result's fields as an array.
 *
 * @return The array of fields.
 */
- (NSArray *)fields
{
	return [NSArray arrayWithObjects:_fields count:_numberOfFields];
}

/**
 * Sets the current row marker to the supplied row.
 *
 * @param row The row to seek to.
 */
- (void)seekToRow:(unsigned long long)row 
{
	if (row >= _numberOfRows) row = _numberOfRows - 1;
	
	_row = row;
}

#pragma mark -
#pragma mark Data Retrieval

/**
 * Return the current row as an array.
 *
 * @return The array of data.
 */
- (NSArray *)rowAsArray 
{
	return [self rowAsType:FLXPostgresResultRowAsArray];
}

/**
 * Return the current row as dictionary with keys as field names and values as the data.
 *
 * @return The row as a dictionary.
 */
- (NSDictionary *)rowAsDictionary
{
	return [self rowAsType:FLXPostgresResultRowAsDictionary];
}

/**
 * Return the current row in the format specified by the supplied type.
 *
 * @return The data row as either an array or dictionary.
 */
- (id)rowAsType:(FLXPostgresResultRowType)type
{
	if (_row >= _numberOfRows) return nil;
	
	id data;
	
	data = (type == FLXPostgresResultRowAsArray) ? [NSMutableArray arrayWithCapacity:_numberOfFields] : [NSMutableDictionary dictionaryWithCapacity:_numberOfFields];
	
	for (NSUInteger i = 0; i < _numberOfFields; i++) 
	{
		id object = [self _objectForRow:(int)_row column:i];
		
		if (type == FLXPostgresResultRowAsArray) {
			[(NSMutableArray *)data addObject:object];
		}
		else {
			[(NSMutableDictionary *)data setObject:object forKey:_fields[i]];
		}
	}
	
	_row++;
	
	return data;
}

#pragma mark -
#pragma mark Private API

/**
 * Populates the internal field names array.
 */
- (void)_populateFields
{	
	_fields = malloc(sizeof(NSString *) * _numberOfFields);
	
	for (NSUInteger i = 0; i < _numberOfFields; i++) 
	{
		const char *bytes = PQfname(_result, i);
		
		if (!bytes) continue;
		
		_fields[i] = [[NSString alloc] initWithBytes:bytes length:strlen(bytes) encoding:_stringEncoding];
	}	
}

/**
 * Get the native object at the supplied row and column.
 *
 * @param row    The row index to get the data from.
 * @param column The column index to get the data from.
 *
 * @return The native object or nil if out of this result's range.
 */
- (id)_objectForRow:(NSUInteger)row column:(NSUInteger)column 
{	
	if (row >= _numberOfRows || column >= _numberOfFields) return nil;
	
	// Check for null
	if (PQgetisnull(_result, row, column)) return [NSNull null];
	
	FLXPostgresOid type = PQftype(_result, column);
	
	// Get handler for this type
	id <FLXPostgresTypeHandlerProtocol> handler = [self _typeHandlerForColumn:column withType:type];
	
	if (!handler) {
		NSLog(@"PostgresKit: Warning: No type handler found for type %d, return NSData.", type);
		
		const void *bytes = PQgetvalue(_result, row, column);
		NSUInteger length = PQgetlength(_result, row, column);
	
		if (!bytes || !length) return nil;
		
		return [NSData dataWithBytes:bytes length:length];
	} 
	
	return [handler objectFromResult:_result atRow:row column:column];
}

/**
 * Get the data type handler for the supplied column index.
 *
 * @param column The column index to get the handler for.
 *
 * @return The type handler or nil if out of this result's range.
 */
- (id <FLXPostgresTypeHandlerProtocol>)_typeHandlerForColumn:(NSUInteger)column withType:(FLXPostgresOid)type
{
	if (column >= _numberOfFields) return nil;
	
	id handler = _typeHandlers[column];
		
	if (!handler) {		
		handler = [_connection typeHandlerForRemoteType:type];
		
		_typeHandlers[column] = handler;
	}
	
	return handler;
}

#pragma mark -

-(void)dealloc 
{
	PQclear(_result);
	
	for (NSUInteger i = 0; i < _numberOfFields; i++) [_fields[i] release];
	
	free(_fields);
	free(_typeHandlers);
	
	if (_connection) [_connection release], _connection = nil;
	
	[super dealloc];
}

@end
