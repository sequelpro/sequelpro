//
//  Databases & Tables.m
//  SPMySQLFramework
//
//  Created by Rowan Beentje (rowan.beent.je) on February 11, 2012
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

#import "Databases & Tables.h"
#import "SPMySQL Private APIs.h"
#import "SPMySQLStringAdditions.h"

@implementation SPMySQLConnection (Databases_and_Tables)

#pragma mark -
#pragma mark Database selection

/**
 * Selects the database the connection should work with.  Typically, a database should be
 * set on a connection before any database-specific queries are run.
 * Returns whether the database was correctly set or not.
 * As MySQL does not support deselecting databases, a nil databaseName will return NO.
 */
- (BOOL)selectDatabase:(NSString *)aDatabase
{

	// If no database was supplied, can't deselected - return NO.
	if (!aDatabase) return NO;

	// Database selection should be made in UTF8 to avoid name encoding issues
	BOOL encodingChangeRequired = [self _storeAndAlterEncodingToUTF8IfRequired];

	// Attempt to select the supplied database
	[self queryString:[NSString stringWithFormat:@"USE %@", [aDatabase mySQLBacktickQuotedString]]];

	// If selecting the database failed, return failure.
	if ([self queryErrored]) {

		// If the encoding needs to be restored, the error message and ID have to be stored so the
		// actual error is still available to inspect on the class...
		if (encodingChangeRequired) {
			NSString *theErrorString = [self lastErrorMessage];
			NSUInteger theErrorID = [self lastErrorID];
			NSString *theSqlstate = [self lastSqlstate];

			[self restoreStoredEncoding];

			[self _updateLastErrorMessage:theErrorString];
			[self _updateLastErrorID:theErrorID];
			[self _updateLastSqlstate:theSqlstate];
		}

		return NO;
	}

	// Restore the connection encoding if necessary
	if (encodingChangeRequired) [self restoreStoredEncoding];

	// Store new database name and return success
	if (database) [database release];
	database = [[NSString alloc] initWithString:aDatabase];

	return YES;
}

#pragma mark -
#pragma mark Database lists

/**
 * Retrieve an array of databases available to the current user, ordered as MySQL
 * returns them.
 * If an error occurred while retrieving the list of databases, nil will be returned;
 * if no databases are available, an empty array will be returned.
 */
- (NSArray *)databases
{

	// Wrap the related databasesLike: function to avoid code duplication
	return [self databasesLike:nil];
}

/**
 * Retrieve an array of databases whose names are matched against the supplied name
 * using MySQL LIKE syntax (with wildcard support for % and _).  If no name is supplied,
 * all databases will be returned, in the order that MySQL returns them.
 * If an error occurred while retrieving the list of databases, nil will be returned;
 * if no matching databases are available, an empty array will be returned.
 */
- (NSArray *)databasesLike:(NSString *)nameLikeString
{
	NSMutableArray *databaseList = nil;

	// Database display should be made in UTF8 to avoid name encoding issues
	BOOL encodingChangeRequired = [self _storeAndAlterEncodingToUTF8IfRequired];

	// Build the query as appropriate
	NSMutableString *databaseQuery = [NSMutableString stringWithString:@"SHOW DATABASES"];
	if ([nameLikeString length]) {
		[databaseQuery appendFormat:@" LIKE %@", [nameLikeString mySQLTickQuotedString]];
	}

	// Perform the query and record state
	SPMySQLResult *databaseResult = [self queryString:databaseQuery];
	[databaseResult setDefaultRowReturnType:SPMySQLResultRowAsArray];
	[databaseResult setReturnDataAsStrings:YES]; //see #2699

	// Retrieve the result into an array if the query was successful
	if (![self queryErrored]) {
		databaseList = [NSMutableArray arrayWithCapacity:(NSUInteger)[databaseResult numberOfRows]];
		for (NSArray *dbRow in databaseResult) {
			[databaseList addObject:[dbRow objectAtIndex:0]];
		}
	}

	// Restore the connection encoding if necessary
	if (encodingChangeRequired) [self restoreStoredEncoding];

	return databaseList;
}

#pragma mark -
#pragma mark Table lists

/**
 * Retrieve an array of tables in the currently selected database, ordered as MySQL
 * returns them.
 * If an error occurred while retrieving the list of tables, nil will be returned;
 * if no tables are present, an empty array will be returned.
 */
- (NSArray *)tables
{

	// Wrap the related tablesLike:fromDatabase: function to avoid code duplication
	return [self tablesLike:nil fromDatabase:nil];
}

/**
 * Retrieve an array of tables in the currently selected database whose names are
 * matched against the supplied name using MySQL LIKE syntax (with wildcard
 * support for % and _).  If no name is supplied, all tables in the selected
 * database will be returned, in the order that MySQL returns them.
 * If an error occurred while retrieving the list of tables, nil will be returned;
 * if no matching tables are present, an empty array will be returned.
 */
- (NSArray *)tablesLike:(NSString *)nameLikeString
{

	// Wrap the related tablesLike:fromDatabase: function to avoid code duplication
	return [self tablesLike:nameLikeString fromDatabase:nil];

}

/**
 * Retrieve an array of tables in the specified database, ordered as MySQL returns them.
 * If no database is specified, the current database will be used.
 * If an error occurred while retrieving the list of tables, nil will be returned;
 * if no tables are present in the specified database, an empty array will be returned.
 */
- (NSArray *)tablesFromDatabase:(NSString *)aDatabase
{

	// Wrap the related tablesLike:fromDatabase: function to avoid code duplication
	return [self tablesLike:nil fromDatabase:aDatabase];

}

/**
 * Retrieve an array of tables in the specified database whose names are matched
 * against the supplied name using MySQL LIKE syntax (with wildcard support
 * for % and _).  If no name is supplied, all tables in the specified database
 * will be returned, in the order that MySQL returns them.
 * If no database is specified, the current database will be used.
 * If an error occurred while retrieving the list of tables, nil will be returned;
 * if no matching tables are present in the specified database, an empty array
 * will be returned.
 */
- (NSArray *)tablesLike:(NSString *)nameLikeString fromDatabase:(NSString *)aDatabase
{
	NSMutableArray *tableList = nil;

	// Table display should be made in UTF8 to avoid name encoding issues
	BOOL encodingChangeRequired = [self _storeAndAlterEncodingToUTF8IfRequired];

	// Build up the table lookup query
	NSMutableString *tableQuery = [NSMutableString stringWithString:@"SHOW TABLES"];
	if ([aDatabase length]) {
		[tableQuery appendFormat:@" FROM %@", [aDatabase mySQLBacktickQuotedString]];
	}
	if ([nameLikeString length]) {
		[tableQuery appendFormat:@" LIKE %@", [nameLikeString mySQLTickQuotedString]];
	}

	// Perform the query and record state
	SPMySQLResult *tableResult = [self queryString:tableQuery];
	[tableResult setDefaultRowReturnType:SPMySQLResultRowAsArray];

	// Retrieve the result into an array if the query was successful
	if (![self queryErrored]) {
		tableList = [NSMutableArray arrayWithCapacity:(NSUInteger)[tableResult numberOfRows]];
		for (NSArray *tableRow in tableResult) {
			[tableList addObject:[tableRow objectAtIndex:0]];
		}
	}

	// Restore the connection encoding if necessary
	if (encodingChangeRequired) [self restoreStoredEncoding];

	return tableList;
}

@end

#pragma mark -
#pragma mark Private API

@implementation SPMySQLConnection (Databases_and_Tables_Private_API)

/**
 * A number of queries regarding database or table information have to be made in UTF8, not
 * in the connection encoding, so that names can be fully displayed and used even if they
 * use a different encoding.  This provides a convenience method to check whether a change
 * is required; if so, the current encoding is stored, the encoding is changed, and YES is
 * returned so the process can be reversed afterwards.
 */
- (BOOL)_storeAndAlterEncodingToUTF8IfRequired
{

	// If the encoding is already UTF8, no change is required.
	if ([encoding isEqualToString:@"utf8"] && !encodingUsesLatin1Transport) return NO;

	// Store the current encoding for restoration afterwards, and update encoding
	[self storeEncodingForRestoration];
	[self setEncoding:@"utf8"];

	return YES;
}

@end
