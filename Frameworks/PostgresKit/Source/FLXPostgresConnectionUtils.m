//
//  $Id$
//
//  FLXPostgresConnectionUtils.m
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
#import "FLXPostgresConnectionQueryExecution.h"
#import "FLXPostgresResult.h"

@interface FLXPostgresConnection ()

- (NSArray *)_executeAndReturnResult:(NSString *)query;

@end

@implementation FLXPostgresConnection (FLXPostgresConnectionUtils)

/**
 * Returns an array of all databases.
 *
 * @return An array of strings or nil if no connection is present.
 */
- (NSArray *)databases 
{
	return [self isConnected] ? [self _executeAndReturnResult:@"SELECT DISTINCT \"catalog_name\" FROM \"information_schema\".\"schemata\""] : nil;
}

/**
 * Returns an array of all schemas.
 *
 * @return An array of strings or nil if no connection is present.
 */
- (NSArray *)schemas 
{					
	return [self isConnected] ? [self _executeAndReturnResult:[NSString stringWithFormat:@"SELECT \"schema_name\" FROM \"information_schema\".\"schemata\" WHERE \"catalog_name\" = '%@'", [self database]]] : nil;
}

/**
 * Returns an array of tables in the supplied schema.
 *
 * @param schem The schema to get tables for.
 *
 * @return An array of strings or nil if not connected or parameters are not valid.
 */
- (NSArray * )tablesInSchema:(NSString *)schema 
{	
	if (![self isConnected] || !schema || ![schema length]) return nil;
		
	return [self _executeAndReturnResult:[NSString stringWithFormat:@"SELECT \"table_name\" FROM \"information_schema\".\"tables\" WHERE \"table_catalog\" = '%@' AND \"table_schema\" = '%@' AND \"table_type\" = 'BASE TABLE'",[self database], schema]];
}

/**
 * Get the primary key column name on the supplied table in the supplied schema.
 * 
 * @param table  The table to get the primary key for.
 * @param schema The schem the table belongs to.
 *
 * @return The column name as a string or nil not connected or parameters are not valid.  
 */
- (NSString *)primaryKeyForTable:(NSString *)table inSchema:(NSString *)schema 
{
	if (![self isConnected] || !table || ![table length] || !schema || ![schema length]) return nil;
	
	NSString *join = @"\"information_schema\".\"table_constraints\" t INNER JOIN \"information_schema\".\"key_column_usage\" k ON t.\"constraint_name\" = k.\"constraint_name\"";
	NSString *where = [NSString stringWithFormat:@"t.\"constraint_type\" = 'PRIMARY KEY' AND t.\"table_catalog\" = '%@' AND t.\"table_schema\" = '%@' AND t.\"table_name\" = '%@'", [self database], schema, table];
	
	FLXPostgresResult *result = [self executeWithFormat:@"SELECT k.\"column_name\" FROM %@ WHERE %@", join, where];

	return [result numberOfRows] == 0 ? nil : [[result rowAsArray] objectAtIndex:0];
}

/**
 * Returns an array of column names for the supplied table and schema.
 *
 * @param table  The table to get column names from.
 * @param schema The schem the table belongs to.
 *
 * @return An array of strings or nil if not connected or parameters are not valid.
 */
- (NSArray *)columnNamesForTable:(NSString *)table inSchema:(NSString *)schema 
{
	if (![self isConnected] || !table || ![table length] || !schema || ![schema length]) return nil;
			
	return [self _executeAndReturnResult:[NSString stringWithFormat:@"SELECT \"column_name\" FROM \"information_schema\".\"columns\" WHERE \"table_catalog\" = '%@' AND \"table_schema\" = '%@' AND \"table_name\" = '%@'", [self database], schema, table]];
}

#pragma mark -
#pragma mark Private API

/**
 * Executes the supplied query and returns the result.
 * 
 * @param query The query to execute.
 *
 * @return The result as an array.
 */
- (NSArray *)_executeAndReturnResult:(NSString *)query
{
	FLXPostgresResult *result = [self execute:query];
	
	if (!result || ![result numberOfRows]) return nil;
	
	NSArray *row = nil;
	NSMutableArray *data = [NSMutableArray arrayWithCapacity:(NSUInteger)[result numberOfRows]];
	
	while ((row = [result rowAsArray])) 
	{
		if (![row count]) continue;
		
		[data addObject:[row objectAtIndex:0]];
	}
	
	return data;
}
	
@end
