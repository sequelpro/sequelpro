//
//  $Id$
//
//  SPTableCopy.m
//  sequel-pro
//
//  Created by David Rekowski on Apr 13, 2010
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPDBActionCommons.h"
#import "SPTableCopy.h"

@implementation SPTableCopy

- (NSString *)getCreateTableStatementFor:(NSString *)tableName inDB:(NSString *)sourceDB 
{
	NSString *showCreateTableStatment = [NSString stringWithFormat:@"SHOW CREATE TABLE %@.%@", [sourceDB backtickQuotedString], [tableName backtickQuotedString]];
	
	MCPResult *theResult = [connection queryString:showCreateTableStatment];
	
	if ([theResult numOfRows] != 0) {
		return [[theResult fetchRowAsArray] objectAtIndex:1];
	}
	
	return @"";
}

- (BOOL)copyTable:(NSString *)tableName from:(NSString *)sourceDB to:(NSString *)targetDB 
{
	NSString *createTableResult = [self getCreateTableStatementFor:tableName inDB:sourceDB];
	NSMutableString *createTableStatement = [[NSMutableString alloc] initWithString:createTableResult];
	
	if ([[createTableStatement substringToIndex:12] isEqualToString:@"CREATE TABLE"]) {
		
		// Add the target DB name and the separator dot after "CREATE TABLE ".
		[createTableStatement insertString:@"." atIndex:13];
		[createTableStatement insertString:[targetDB backtickQuotedString] atIndex:13];

		[connection queryString:createTableStatement];		
	
		if ([connection queryErrored]) return NO;
		
		return YES;
	}
	
	[createTableStatement release];
	
	return NO;
}

- (BOOL)copyTable:(NSString *)tableName from:(NSString *)sourceDB to:(NSString *)targetDB withContent:(BOOL)copyWithContent
{
	// Copy the table structure
	BOOL structureCopyResult = [self copyTable:tableName from:sourceDB to:targetDB];
	
	// Optionally copy the table data using an insert select
	if (structureCopyResult && structureCopyResult && copyWithContent) {
		
		NSString *copyDataStatement = [NSString stringWithFormat:@"INSERT INTO %@.%@ SELECT * FROM %@.%@", 
									   [targetDB backtickQuotedString],
									   [tableName backtickQuotedString],
									   [sourceDB backtickQuotedString],
									   [tableName backtickQuotedString]
									   ];
		
		[connection queryString:copyDataStatement];		

		if ([connection queryErrored]) return NO;
		
		return YES;
	}
	
	return structureCopyResult;
}

- (BOOL)moveTable:(NSString *)tableName from:(NSString *)sourceDB to:(NSString *)targetDB 
{	
	NSString *moveStatement = [NSString stringWithFormat:@"RENAME TABLE %@.%@ TO %@.%@", 
							   [sourceDB backtickQuotedString],
							   [tableName backtickQuotedString],
							   [targetDB backtickQuotedString],
							   [tableName backtickQuotedString]
							   ];
	// Move the table
	[connection queryString:moveStatement];
	
	if ([connection queryErrored]) return NO;
	
	return YES;
}

@end
