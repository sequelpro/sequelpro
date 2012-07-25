//
//  $Id$
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
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPTableCopy.h"

#import <SPMySQL/SPMySQL.h>

@interface SPTableCopy ()

- (NSString *)_createTableStatementFor:(NSString *)tableName inDatabase:(NSString *)sourceDatabase; 

@end


@implementation SPTableCopy

- (BOOL)copyTable:(NSString *)tableName from:(NSString *)sourceDB to:(NSString *)targetDB 
{
	NSString *createTableResult = [self _createTableStatementFor:tableName inDatabase:sourceDB];
	NSMutableString *createTableStatement = [[NSMutableString alloc] initWithString:createTableResult];
	
	if ([[createTableStatement substringToIndex:12] isEqualToString:@"CREATE TABLE"]) {
		
		// Add the target DB name and the separator dot after "CREATE TABLE ".
		[createTableStatement insertString:@"." atIndex:13];
		[createTableStatement insertString:[targetDB backtickQuotedString] atIndex:13];

		[connection queryString:createTableStatement];		
	
		[createTableStatement release];
		
		return ![connection queryErrored];
	}
	
	[createTableStatement release];
	
	return NO;
}

- (BOOL)copyTable:(NSString *)tableName from:(NSString *)sourceDB to:(NSString *)targetDB withContent:(BOOL)copyWithContent
{
	// Copy the table structure
	BOOL structureCopySuccess = [self copyTable:tableName from:sourceDB to:targetDB];
	
	// Optionally copy the table data using an insert select
	if (structureCopySuccess && copyWithContent) {
		
		NSString *copyDataStatement = [NSString stringWithFormat:@"INSERT INTO %@.%@ SELECT * FROM %@.%@", 
									   [targetDB backtickQuotedString],
									   [tableName backtickQuotedString],
									   [sourceDB backtickQuotedString],
									   [tableName backtickQuotedString]
									   ];
		
		[connection queryString:copyDataStatement];		

		return ![connection queryErrored];
	}
	
	return structureCopySuccess;
}

- (BOOL)copyTables:(NSArray *)tablesArray from:(NSString *)sourceDB to:(NSString *)targetDB withContent:(BOOL)copyWithContent
{
	BOOL success = YES;
	
	// Disable foreign key checks
	[connection queryString:@"/*!32352 SET foreign_key_checks=0 */"];
	
	if ([connection queryErrored]) {
		success = NO;
	}
	
	for (NSString *tableName in tablesArray) 
	{
		if (![self copyTable:tableName from:sourceDB to:targetDB withContent:copyWithContent]) {
			success = NO;
		}
	}
	
	// Enable foreign key checks
	[connection queryString:@"/*!32352 SET foreign_key_checks=1 */"];
	
	if ([connection queryErrored]) {
		success = NO;
	}
	
	return success;
}

- (BOOL)moveTable:(NSString *)tableName from:(NSString *)sourceDB to:(NSString *)targetDB
{	
	NSString *moveStatement = [NSString stringWithFormat:@"RENAME TABLE %@.%@ TO %@.%@", 
							   [sourceDB backtickQuotedString],
							   [tableName backtickQuotedString],
							   [targetDB backtickQuotedString],
							   [tableName backtickQuotedString]];

	[connection queryString:moveStatement];
	
	return ![connection queryErrored];
}

#pragma mark -
#pragma mark Private API

- (NSString *)_createTableStatementFor:(NSString *)tableName inDatabase:(NSString *)sourceDatabase 
{
	NSString *showCreateTableStatment = [NSString stringWithFormat:@"SHOW CREATE TABLE %@.%@", [sourceDatabase backtickQuotedString], [tableName backtickQuotedString]];
	
	SPMySQLResult *theResult = [connection queryString:showCreateTableStatment];
	
	return [theResult numberOfRows] > 0 ? [[theResult getRowAsArray] objectAtIndex:1] : @"";
}

@end
