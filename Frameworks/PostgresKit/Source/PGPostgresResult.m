//
//  $Id: PGPostgresResult.m 3862 2012-09-24 12:58:47Z stuart02 $
//
//  PGPostgresResult.m
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

#import "PGPostgresResult.h"
#import "PGPostgresException.h"
#import "PGPostgresConnection.h"
#import "PGPostgresConnectionTypeHandling.h"

@interface PGPostgresResult ()

- (void)_populateFields;
- (id)_objectForRow:(NSUInteger)row column:(NSUInteger)column; 
- (id <PGPostgresTypeHandlerProtocol>)_typeHandlerForColumn:(NSUInteger)column withType:(PGPostgresOid)type;

@end

@implementation PGPostgresResult

@synthesize numberOfRows = _numberOfRows;
@synthesize numberOfFields = _numberOfFields;
@synthesize stringEncoding = _stringEncoding;
@synthesize defaultRowType = _defaultRowType;

#pragma mark -
#pragma mark Initialisation

/**
 * Prevent normal initialisation.
 *
 * @return nil
 */
- (id)init
{
	[PGPostgresException raise:NSInternalInconsistencyException reason:@"%@ shouldn't be init'd directly; use initWithResult:connection: instead.", [self className]];
	
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
- (id)initWithResult:(void *)result connection:(PGPostgresConnection *)connection 
{		
	if ((self = [super init])) {
		
		_row = 0;
		_result = result;
		_numberOfRows = PQntuples(_result);
		_numberOfFields = PQnfields(_result);
		_connection = [connection retain];
		
		_stringEncoding = [_connection stringEncoding];
		_defaultRowType = PGPostgresResultRowAsDictionary;
		
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
 * Return the current row in the type of the currently set default (defaults to dictionary).
 *
 * @return The row of data.
 */
- (id)row
{
	return [self rowAsType:_defaultRowType];
}

/**
 * Return the current row as an array.
 *
 * @return The array of data.
 */
- (NSArray *)rowAsArray 
{
	return [self rowAsType:PGPostgresResultRowAsArray];
}

/**
 * Return the current row as dictionary with keys as field names and values as the data.
 *
 * @return The row as a dictionary.
 */
- (NSDictionary *)rowAsDictionary
{
	return [self rowAsType:PGPostgresResultRowAsDictionary];
}

/**
 * Return the current row in the format specified by the supplied type.
 *
 * @return The data row as either an array or dictionary.
 */
- (id)rowAsType:(PGPostgresResultRowType)type
{
	if (_row >= _numberOfRows) return nil;
	
	id data = (type == PGPostgresResultRowAsArray) ? [NSMutableArray arrayWithCapacity:_numberOfFields] : [NSMutableDictionary dictionaryWithCapacity:_numberOfFields];
	
	for (NSUInteger i = 0; i < _numberOfFields; i++) 
	{
		id object = [self _objectForRow:(int)_row column:i];
		
		if (type == PGPostgresResultRowAsArray) {
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
#pragma mark Fast enumeration implementation

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len
{
	if (state->state >= _numberOfRows) return 0;
	
	if (state->state != _row) [self seekToRow:state->state];
	
	// Determine how many objects to return - 128, len, or all items remaining
	NSUInteger itemsToReturn = 128;
	
	if (len < 128) itemsToReturn = len;
	
	if (_numberOfRows - state->state < itemsToReturn) {
		itemsToReturn = (unsigned long)_numberOfRows - state->state;
	}
	
	for (NSUInteger i = 0; i < itemsToReturn; i++) 
	{
		stackbuf[i] = [self rowAsType:_defaultRowType];
	}
	
	state->state += itemsToReturn;
	state->itemsPtr = stackbuf;
	state->mutationsPtr = (unsigned long *)self;
	
	return itemsToReturn;
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
		const char *bytes = PQfname(_result, (int)i);
		
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
	if (row >= _numberOfRows || column >= _numberOfFields) return [NSNull null];
	
	// Check for null
	if (PQgetisnull(_result, (int)row, (int)column)) return [NSNull null];
	
	PGPostgresOid type = PQftype(_result, (int)column);
	
	// Get handler for this type
	id <PGPostgresTypeHandlerProtocol> handler = [self _typeHandlerForColumn:column withType:type];
	
	if (!handler) {
		NSLog(@"PostgresKit: Warning: No type handler found for type %d, returning NSData.", type);
		
		const void *bytes = PQgetvalue(_result, (int)row, (int)column);
		NSUInteger length = PQgetlength(_result, (int)row, (int)column);
	
		if (!bytes || !length) return nil;
		
		return [NSData dataWithBytes:bytes length:length];
	}
	
	[handler setRow:row];
	[handler setType:type];
	[handler setColumn:column];
	[handler setResult:_result];
	
	id object = [handler objectFromResult];
	
	[handler setResult:nil];
	
	return object;
}

/**
 * Get the data type handler for the supplied column index.
 *
 * @param column The column index to get the handler for.
 *
 * @return The type handler or nil if out of this result's range.
 */
- (id <PGPostgresTypeHandlerProtocol>)_typeHandlerForColumn:(NSUInteger)column withType:(PGPostgresOid)type
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
