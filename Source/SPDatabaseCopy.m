//
//  SPDatabaseCopy.m
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

#import "SPDatabaseCopy.h"
#import "SPTableCopy.h"
#import "SPCreateDatabaseInfo.h"

#import <SPMySQL/SPMySQL.h>

@implementation SPDatabaseCopy

- (BOOL)copyDatabaseFrom:(SPCreateDatabaseInfo *)sourceDatabase to:(NSString *)targetDatabaseName withContent:(BOOL)copyWithContent
{
	NSArray *tables = nil;
	NSArray *databases = [connection databases];

	// Check whether the source database exists and the target database doesn't
	BOOL sourceExists = [databases containsObject:[sourceDatabase databaseName]];
	BOOL targetExists = [databases containsObject:targetDatabaseName];
	
	if (!sourceExists || targetExists)
		return NO;
	
	// Retrieve the list of tables/views/funcs/triggers from the source database
	tables = [connection tablesFromDatabase:[sourceDatabase databaseName]];
	
	// Abort if database creation failed
	if (![self createDatabase:targetDatabaseName
				 withEncoding:[sourceDatabase defaultEncoding]
					collation:[sourceDatabase defaultCollation]]) return NO;
	
	SPTableCopy *dbActionTableCopy = [[SPTableCopy alloc] init];
	
	[dbActionTableCopy setConnection:connection];
	
	BOOL success = [dbActionTableCopy copyTables:tables from:[sourceDatabase databaseName] to:targetDatabaseName withContent:copyWithContent];
	
	[dbActionTableCopy release];
	
	return success;
}

@end
