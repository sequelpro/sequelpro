//
//  $Id: PGPostgresConnectionQueryExecution.m 3841 2012-09-10 08:52:00Z stuart02 $
//
//  PGPostgresConnectionQueryExecution.h
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

#import "PGPostgresConnectionQueryExecution.h"
#import "PGPostgresKitPrivateAPI.h"
#import "PGPostgresConnectionTypeHandling.h"
#import "PGPostgresConnectionDelegate.h"
#import "PGPostgresTypeHandlerProtocol.h"
#import "PGPostgresConnection.h"
#import "PGPostgresException.h"
#import "PGPostgresResult.h"
#import "PGPostgresStatement.h"
#import "PGPostgresError.h"

// Constants
static int PGPostgresResultsAsBinary = 1;

// Internal query structure
typedef struct 
{
	int paramNum;
	const void **paramValues;
	PGPostgresOid* paramTypes;
	int *paramLengths;
	int *paramFormats;
} 
PGQueryParamData;

@interface PGPostgresConnection ()

- (PGPostgresResult *)_execute:(NSObject *)query values:(NSArray *)values;
- (BOOL)_queryDidError:(PGresult *)result;
- (PGQueryParamData *)_createParameterDataStructureWithCount:(int)paramNum;
- (void)_destroyParamDataStructure:(PGQueryParamData *)paramData;

@end

@implementation PGPostgresConnection (PGPostgresConnectionQueryExecution)

#pragma mark -
#pragma mark Synchronous Interface

- (PGPostgresResult *)execute:(NSString *)query 
{
	return [self _execute:query values:nil];
}

- (PGPostgresResult *)execute:(NSString *)query value:(NSObject *)value 
{
	return [self _execute:query values:[NSArray arrayWithObject:value]];
}

- (PGPostgresResult *)executePrepared:(PGPostgresStatement *)statement value:(NSObject *)value 
{
	return [self _execute:statement values:[NSArray arrayWithObject:value]];
}

- (PGPostgresResult *)executePrepared:(PGPostgresStatement *)statement 
{
	return [self _execute:statement values:nil];
}

- (PGPostgresResult *)executePrepared:(PGPostgresStatement *)statement values:(NSArray *)values 
{
	return [self _execute:statement values:values];
}

- (PGPostgresResult *)execute:(NSString *)query values:(NSArray *)values 
{
	return [self _execute:query values:values];
}

- (PGPostgresResult *)executeWithFormat:(NSString *)query, ... 
{
	va_list argumentList;
	va_start(argumentList, query);
	
	NSMutableString *string = [[NSMutableString alloc] init];
	
	CFStringAppendFormatAndArguments((CFMutableStringRef)string, (CFDictionaryRef)nil, (CFStringRef)query, argumentList);
	
	va_end(argumentList);
	
	PGPostgresResult *result = [self _execute:string values:nil];
	
	[string release];
	
	return result;
}

#pragma mark -
#pragma mark Asynchronous Interface

#pragma mark -
#pragma mark Private API

- (PGPostgresResult *)_execute:(NSObject *)query values:(NSArray *)values 
{
	_lastQueryWasCancelled = NO;
	
	if (![self isConnected] || !query || ![query isKindOfClass:[NSString class]] || [query isKindOfClass:[PGPostgresStatement class]]) return nil;
	
	// Notify the delegate
	if (_delegate && _delegateSupportsWillExecute) {
		[_delegate connection:self willExecute:query withValues:values];
	}

	PGQueryParamData *paramData = [self _createParameterDataStructureWithCount:values ? (int)[values count] : 0];
	
	if (!paramData) return nil;
	
	// Fill the data structures
	for (int i = 0; i < paramData->paramNum; i++) 
	{
		id nativeObject = [values objectAtIndex:i];
				
		// Deterime if bound value is an NSNull
		if ([nativeObject isKindOfClass:[NSNull class]]) {
			paramData->paramValues[i] = NULL;
			paramData->paramTypes[i] = 0;
			paramData->paramLengths[i] = 0;			
			paramData->paramFormats[i] = 0;
			
			continue;
		}
		
		// Obtain correct handler for this class
		id <PGPostgresTypeHandlerProtocol> typeHandler = [self typeHandlerForClass:[nativeObject class]];
		
		if (!typeHandler) {
			[self _destroyParamDataStructure:paramData];			
			
			// TODO: get rid of exceptions
			[PGPostgresException raise:PGPostgresConnectionErrorDomain reason:[NSString stringWithFormat:@"Parameter $%u unsupported class %@", (i + 1), NSStringFromClass([nativeObject class])]];
			return nil;
		}

		NSData *data = nil; // Sending parameters as binary is not implemented yet
		PGPostgresOid type = 0;
		
		if (!data) {
			[self _destroyParamDataStructure:paramData];
			
			// TODO: get rid of exceptions
			[PGPostgresException raise:PGPostgresConnectionErrorDomain reason:[NSString stringWithFormat:@"Parameter $%u cannot be converted into a bound value", (i + 1)]];
			return nil;
		}			
		
		// Check length of data
		if ([data length] > INT_MAX) {
			[self _destroyParamDataStructure:paramData];
			
			// TODO: get rid of exceptions
			[PGPostgresException raise:PGPostgresConnectionErrorDomain reason:[NSString stringWithFormat:@"Bound value $%u exceeds maximum size", (i + 1)]];			
			return nil;
		}
		
		// Assign data
		paramData->paramTypes[i] = type;
		
		// NOTE: if data length is zero, we encode as text instead, as NSData returns 0 for
		// empty data, and it gets encoded as a NULL.
		if ([data length] == 0) {
			paramData->paramValues[i] = "";
			paramData->paramFormats[i] = 0;
			paramData->paramLengths[i] = 0;						
		} 
		else {
			// Send as binary data
			paramData->paramValues[i] = [data bytes];
			paramData->paramLengths[i] = (int)[data length];			
			paramData->paramFormats[i] = 1;
		}
	}	
	
	// Execute the command - return data in binary
	PGresult *result = nil;
	
	if ([query isKindOfClass:[NSString class]]) {
		
		result = PQexecParams(_connection, 
							  [(NSString *)query UTF8String], 
							  paramData->paramNum, 
							  paramData->paramTypes, 
							  (const char **)paramData->paramValues, 
							  (const int *)paramData->paramLengths, 
							  (const int *)paramData->paramFormats, 
							  PGPostgresResultsAsBinary);
	} 
	else if ([query isKindOfClass:[PGPostgresStatement class]]) {
		PGPostgresStatement *statement = (PGPostgresStatement *)query;
		
		// Statement has not been prepared yet, so prepare it with the given parameter types
		if (![statement name]) {
			BOOL prepareResult = [self _prepare:statement num:paramData->paramNum types:paramData->paramTypes];
			
			if (!prepareResult || ![statement name]) return nil;
		}
		
		result = PQexecPrepared(_connection, 
								[statement UTF8Name], 
								paramData->paramNum, 
								(const char **)paramData->paramValues, 
								(const int *)paramData->paramLengths, 
								(const int *)paramData->paramFormats, 
								PGPostgresResultsAsBinary);		
	}
	
	[self _destroyParamDataStructure:paramData];
	
	if (!result || [self _queryDidError:result]) return nil;
	
	return [[[PGPostgresResult alloc] initWithResult:result connection:self] autorelease];
}

/**
 * Determines whether or not the supplied result indicates an error occurred.
 *
 * @param result The result to examine.
 *
 * @return A BOOL indicating if an error occurred.
 */
- (BOOL)_queryDidError:(PGresult *)result
{
	ExecStatusType status = PQresultStatus(result);
	
	if (status == PGRES_BAD_RESPONSE || status == PGRES_FATAL_ERROR) {		
		if (_lastError) [_lastError release], _lastError = nil;
		
		_lastError = [[PGPostgresError alloc] initWithResult:result];
		
		PQclear(result);
		
		return YES;
	}
	
	return NO;
}

/**
 * Creates the internal query parameter data structure.
 *
 * @note This method will throw an exception if it can't allocated the required memory.
 *
 * @param paramNum The number of parameters the structure should accommodate.
 *
 * @return The data structure or nil if an exception occurred.
 */
- (PGQueryParamData *)_createParameterDataStructureWithCount:(int)paramNum
{
	PGQueryParamData *paramData = malloc(sizeof(PGQueryParamData));
	
	paramData->paramNum = paramNum;
	paramData->paramValues = NULL;
	paramData->paramTypes = NULL;
	paramData->paramLengths = NULL;
	paramData->paramFormats = NULL;
	
	if (paramData->paramNum) {
		paramData->paramValues = malloc(sizeof(void *) * paramData->paramNum);
		paramData->paramTypes = malloc(sizeof(PGPostgresOid) * paramData->paramNum);
		paramData->paramLengths = malloc(sizeof(int) * paramData->paramNum);
		paramData->paramFormats = malloc(sizeof(int) * paramData->paramNum);
		
		if (!paramData->paramValues || !paramData->paramLengths || !paramData->paramFormats) {
			[self _destroyParamDataStructure:paramData];
			
			// Probably justifies throwing an exception if we can't allocate any memory!
			[PGPostgresException raise:PGPostgresConnectionErrorDomain reason:@"Memory allocation error"];
			
			return nil;
		}
	}
	
	return paramData;
}

/**
 * Frees the memory associated with the supplied parameter data structure.
 *
 * @param paramData The parameter data to destroy.
 */
- (void)_destroyParamDataStructure:(PGQueryParamData *)paramData
{
	if (!paramData) return;
	
	if (paramData->paramValues) free(paramData->paramValues);
	if (paramData->paramTypes) free(paramData->paramTypes);
	if (paramData->paramLengths) free(paramData->paramLengths);
	if (paramData->paramFormats) free(paramData->paramFormats);
	
	free(paramData);
}

@end
