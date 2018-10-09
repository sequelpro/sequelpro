//
//  SPTableCopy.m
//  sequel-pro
//
//  Created by David Rekowski on April 13, 2010.
//  Copyright (c) 2010 David Rekowski. All rights reserved.
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

#import "SPTableCopy.h"

#import <SPMySQL/SPMySQL.h>

@interface SPTableCopy ()

- (NSString *)_createTableStatementFor:(NSString *)tableName inDatabase:(NSString *)sourceDatabase;

@end


@implementation SPTableCopy

- (BOOL)copyTable:(NSString *)tableName from:(NSString *)sourceDatabase to:(NSString *)targetDatabase
{
	NSString *createTableResult = [self _createTableStatementFor:tableName inDatabase:sourceDatabase];
	
	if ([createTableResult hasPrefix:@"CREATE TABLE"]) {
		NSMutableString *createTableStatement = [[NSMutableString alloc] initWithString:createTableResult];
		
		// Add the target DB name and the separator dot after "CREATE TABLE ".
		[createTableStatement insertString:@"." atIndex:13];
		[createTableStatement insertString:[targetDatabase backtickQuotedString] atIndex:13];

		[connection queryString:createTableStatement];		
	
		[createTableStatement release];
		
		return ![connection queryErrored];
	}
	
	return NO;
}

- (BOOL)copyTable:(NSString *)tableName from:(NSString *)sourceDatabase to:(NSString *)targetDatabase withContent:(BOOL)copyWithContent
{
	// Copy the table structure
	BOOL structureCopySuccess = [self copyTable:tableName from:sourceDatabase to:targetDatabase];
	
	// Optionally copy the table data using an insert select
	if (structureCopySuccess && copyWithContent) {
		
		NSString *copyDataStatement = [NSString stringWithFormat:@"INSERT INTO %@.%@ SELECT * FROM %@.%@", 
									   [targetDatabase backtickQuotedString],
									   [tableName backtickQuotedString],
									   [sourceDatabase backtickQuotedString],
									   [tableName backtickQuotedString]
									   ];
		
		[connection queryString:copyDataStatement];		

		return ![connection queryErrored];
	}
	
	return structureCopySuccess;
}

- (BOOL)copyTables:(NSArray *)tablesArray from:(NSString *)sourceDatabase to:(NSString *)targetDatabase withContent:(BOOL)copyWithContent
{
	BOOL success = YES;
	
	// Disable foreign key checks
	[connection queryString:@"/*!32352 SET foreign_key_checks=0 */"];
	
	if ([connection queryErrored]) {
		success = NO;
	}
	
	// Disable auto-id creation for '0' values
	[connection queryString:@"/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */"];
	
	if([connection queryErrored]) {
		success = NO;
	}
	
	for (NSString *tableName in tablesArray) 
	{
		if (![self copyTable:tableName from:sourceDatabase to:targetDatabase withContent:copyWithContent]) {
			success = NO;
		}
	}
	
	// Enable foreign key checks
	[connection queryString:@"/*!32352 SET foreign_key_checks=1 */"];
	
	if ([connection queryErrored]) {
		success = NO;
	}
	
	// Re-enable id creation
	[connection queryString:@"/*!40101 SET SQL_MODE=@OLD_SQL_MODE */"];
	
	if ([connection queryErrored]) {
		success = NO;
	}
	
	return success;
}

- (BOOL)moveTable:(NSString *)tableName from:(NSString *)sourceDatabase to:(NSString *)targetDatabase
{	
	NSString *moveStatement = [NSString stringWithFormat:@"RENAME TABLE %@.%@ TO %@.%@", 
							   [sourceDatabase backtickQuotedString],
							   [tableName backtickQuotedString],
							   [targetDatabase backtickQuotedString],
							   [tableName backtickQuotedString]];

	[connection queryString:moveStatement];
	
	return ![connection queryErrored];
}

#pragma mark -
#pragma mark Private API

- (NSString *)_createTableStatementFor:(NSString *)tableName inDatabase:(NSString *)sourceDatabase
{
	NSString *showCreateTableStatment = [NSString stringWithFormat:@"SHOW CREATE TABLE %@.%@", [sourceDatabase backtickQuotedString], [tableName backtickQuotedString]];
	
	SPMySQLResult *result = [connection queryString:showCreateTableStatment];
	
	if ([result numberOfRows] > 0) return [[result getRowAsArray] objectAtIndex:1];
	
	SPLog(@"query <%@> failed to return the expected result.\n  Error state: %@ (%lu)", showCreateTableStatment, [connection lastErrorMessage], [connection lastErrorID]);

	return nil;
}

@end
