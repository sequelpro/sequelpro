//
//  $Id$
//
//  SPDatabaseRename.m
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


#import <MCPKit/MCPConnection.h>
#import <MCPKit/MCPResult.h>
#import "SPAlertSheets.h"
#import "SPStringAdditions.h"
#import "SPDatabaseRename.h"
#import "SPDatabaseInfo.h"
#import "SPTableCopy.h"
#import "Sequel-Pro.pch"

@implementation SPDatabaseRename

@synthesize connection;
@synthesize dbInfo;
@synthesize parent;

- (SPDatabaseInfo *)getDBInfoObject {
	if (dbInfo != nil) {
		return dbInfo;
	} else {
		dbInfo = [[SPDatabaseInfo alloc] init];
		[dbInfo setConnection:[self connection]];
		[dbInfo setParent:[self parent]];
	}
	return dbInfo;
}

- (NSObject *)getTableWindow {
	return [NSApp mainWindow];
}

- (BOOL)renameDatabaseFrom: (NSString *)sourceDatabaseName to: (NSString *)targetDatabaseName {
	SPDatabaseInfo *databaseInfo = [self getDBInfoObject];

	// check, whether the source database exists and the target database doesn't.
	NSArray *tables = [NSArray array]; 
	BOOL sourceExists = [databaseInfo databaseExists:sourceDatabaseName];
	BOOL targetExists = [databaseInfo databaseExists:targetDatabaseName];
	if (sourceExists && !targetExists) {
		// retrieve the list of tables/views/funcs/triggers from the source database
		
		tables = [connection listTablesFromDB:sourceDatabaseName];
	} else {
		SPBeginAlertSheet(NSLocalizedString(@"Cannot create existing database", @"create database exists error message"), 
						  NSLocalizedString(@"OK", @"OK button"), nil, nil, [self getTableWindow], self, nil, nil, nil, 
						  [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to create the target database.\n\nDatabase %@ already exists.", 
																	   @"create database error informative message"), 
						   targetDatabaseName]);
		return NO;
	}
	DLog(@"list of found tables of source db: %@", tables);
	
	[self createDatabase:targetDatabaseName];
	SPTableCopy *dbActionTableCopy = [[SPTableCopy alloc] init];
	[dbActionTableCopy setConnection:connection];
	
	for (NSString *currentTable in tables) {
		if ([dbActionTableCopy moveTable:currentTable 						
									from:sourceDatabaseName
									  to:targetDatabaseName]) {
		}
	}
	tables = [connection listTablesFromDB:sourceDatabaseName];
	if ([tables count] == 0) {
		[self dropDatabase:sourceDatabaseName];
	} else {
		SPBeginAlertSheet(NSLocalizedString(@"Failed to delete database", @"delete database error message"), 
						  NSLocalizedString(@"OK", @"OK button"), nil, nil, [self getTableWindow], self, nil, nil, nil, 
						  [NSString stringWithFormat:NSLocalizedString(@"Database %@ not empty, skipping drop database.", 
																	   @"delete database not empty error informative message"), 
						   sourceDatabaseName]);
	}
}

- (BOOL) createDatabase: (NSString *)newDatabaseName {
	NSString *createStatement = [NSString stringWithFormat:@"CREATE DATABASE %@", 
								 [newDatabaseName backtickQuotedString]];
	[connection queryString:createStatement];	
	if ([connection queryErrored]) {
		SPBeginAlertSheet(NSLocalizedString(@"Failed to create database", @"create database error message"), 
						  NSLocalizedString(@"OK", @"OK button"), nil, nil, [self getTableWindow], self, nil, nil, nil, 
						  [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to create a database.\n\nMySQL said: %@", 
																	   @"create database error informative message"), 
						   [connection getLastErrorMessage]]);
		return NO;
	}
	return YES;
	
}

- (BOOL) dropDatabase: (NSString *)databaseName {
	NSString *dropStatement = [NSString stringWithFormat:@"DROP DATABASE %@", 
								 [databaseName backtickQuotedString]];
	[connection queryString:dropStatement];	
	if ([connection queryErrored]) {
		SPBeginAlertSheet(NSLocalizedString(@"Failed to drop database", @"drop database error message"), 
						  NSLocalizedString(@"OK", @"OK button"), nil, nil, [self getTableWindow], self, nil, nil, nil, 
						  [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to drop a database.\n\nMySQL said: %@", 
																	   @"drop database error informative message"), 
						   [connection getLastErrorMessage]]);
		return NO;
	}
	return YES;
	
}

- (void)dealloc {
	[dbInfo dealloc];
}

@end