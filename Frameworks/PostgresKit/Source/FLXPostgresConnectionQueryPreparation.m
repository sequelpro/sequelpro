//
//  $Id$
//
//  FLXPostgresConnectionQueryPreparation.m
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

#import "FLXPostgresConnectionQueryPreparation.h"
#import "FLXPostgresConnectionTypeHandling.h"
#import "FLXPostgresKitPrivateAPI.h"
#import "FLXPostgresStatement.h"
#import "FLXPostgresException.h"

@implementation FLXPostgresConnection (FLXPostgresConnectionQueryPreparation)

/**
 * Creates a prepared statment from the supplied query.
 *
 * @param query The query to create the statement from.
 *
 * @return The prepared statement instance.
 */
- (FLXPostgresStatement *)prepare:(NSString *)query 
{
	if (!query || ![query length]) return nil;
	
	return [[[FLXPostgresStatement alloc] initWithStatement:query] autorelease];
}

/**
 * Creates a prepared statment from the supplied query format and values.
 *
 * @param query The query to create the statement from.
 * @param ...   Any values to insert into the query (optional).
 *
 * @return The prepared statement instance.
 */
- (FLXPostgresStatement *)prepareWithFormat:(NSString *)query, ... 
{
	if (!query || ![query length]) return nil;
	
	va_list args;
	va_start(args, query);
	
	NSMutableString *string = [[NSMutableString alloc] initWithFormat:query arguments:args];
		
	va_end(args);   
	
	FLXPostgresStatement *statement = [self prepare:string];
	
	[string release];
	
	return statement;
}

#pragma mark -
#pragma mark Private API

/**
 * Actually prepares the supplied statement against the database.
 *
 * @param statement  The statement to prepare.
 * @param paranNum   The number of parameters the statement contains.
 * @param paramTypes Any of Postgres parameter types.
 *
 * @return A BOOL indicating succes. Returns NO if there's no statement, statement name or current connection.
 */
- (BOOL)_prepare:(FLXPostgresStatement *)statement num:(NSInteger)paramNum types:(FLXPostgresOid *)paramTypes 
{
	if (!statement || ![statement name] || ![self isConnected]) return NO;
	
	NSString *name = [[NSProcessInfo processInfo] globallyUniqueString];
	
	PGresult *result = PQprepare(_connection, [name UTF8String], [statement UTF8Statement], (int)paramNum, paramTypes);
	
	if (!result) return NO;
	
	ExecStatusType resultStatus = PQresultStatus(result);
	
	if (resultStatus == PGRES_BAD_RESPONSE || resultStatus == PGRES_FATAL_ERROR) {
		PQclear(result);
		
		return NO;
	}
	
	PQclear(result);
	
	[statement setName:name];
	
	return YES;
}

@end
