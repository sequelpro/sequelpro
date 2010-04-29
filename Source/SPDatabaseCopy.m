//
//  $Id$
//
//  SPDatabaseCopy.m
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
#import "SPDatabaseCopy.h"
#import "SPTableCopy.h"

@implementation SPDatabaseCopy

@synthesize dbInfo;

- (SPDatabaseInfo *)getDBInfoObject {
	if (dbInfo != nil) {
		return dbInfo;
	} else {
		dbInfo = [[SPDatabaseInfo alloc] init];
		[dbInfo setConnection:[self connection]];
		[dbInfo setMessageWindow:messageWindow];
	}
	return dbInfo;
}

- (NSObject *)getTableWindow {
	return messageWindow;
}

- (BOOL)copyDatabaseFrom: (NSString *)sourceDatabaseName to: (NSString *)targetDatabaseName withContent:(BOOL)copyWithContent {

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
		if ([dbActionTableCopy copyTable:currentTable 						
									from:sourceDatabaseName
									  to:targetDatabaseName
							 withContent:copyWithContent]) {
		}
	}
}

- (BOOL) createDatabase: (NSString *)newDatabaseName {
	NSString *createStatement = [NSString stringWithFormat:@"CREATE DATABASE %@", 
								 [newDatabaseName backtickQuotedString]];
	[connection queryString:createStatement];	

	if ([connection queryErrored]) {
		SPBeginAlertSheet(NSLocalizedString(@"Failed to create database", @"create database error message"), 
						  NSLocalizedString(@"OK", @"OK button"), nil, nil, [self getTableWindow], self, nil, nil, nil, 
						  [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to create the target database.\n\nMySQL said: %@", 
																	   @"create database error informative message"), 
						   [connection getLastErrorMessage]]);
		return NO;
	}
	return YES;
	
	
}

- (void)dealloc {
	[dbInfo dealloc];
}


@end