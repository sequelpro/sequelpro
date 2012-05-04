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

#import "SPDatabaseRename.h"
#import "SPTableCopy.h"
#import "SPViewCopy.h"
#import "SPTablesList.h"

#import <SPMySQL/SPMySQL.h>

@interface SPDatabaseRename ()

- (BOOL)_createDatabase:(NSString *)database;
- (BOOL)_dropDatabase:(NSString *)database;

- (void)_moveTables:(NSArray *)tables fromDatabase:(NSString *)sourceDatabase toDatabase:(NSString *)targetDatabase;
- (void)_moveViews:(NSArray *)views fromDatabase:(NSString *)sourceDatabase toDatabase:(NSString *)targetDatabase;

@end

@implementation SPDatabaseRename

- (BOOL)renameDatabaseFrom:(NSString *)sourceDatabase to:(NSString *)targetDatabase
{
	NSArray *tables = nil;
	NSArray *views = nil;
	
	// Check, whether the source database exists and the target database doesn't
	BOOL sourceExists = [[connection databases] containsObject:sourceDatabase];
	BOOL targetExists = [[connection databases] containsObject:targetDatabase];
	
	if (sourceExists && !targetExists) {
		tables = [tablesList allTableNames];
		views = [tablesList allViewNames];
	}
	else {
		return NO;
	}
		
	BOOL success = [self _createDatabase:targetDatabase];
	
	[self _moveTables:tables fromDatabase:sourceDatabase toDatabase:targetDatabase];
	
	tables = [connection tablesFromDatabase:sourceDatabase];
		
	if ([tables count] == 0) {
		[self _dropDatabase:sourceDatabase];
	} 
		
	return success;
}

#pragma mark -
#pragma mark Private API

/**
 * This method creates a new database.
 *
 * @param NSString newDatabaseName name of the new database to be created
 * @return BOOL YES on success, otherwise NO
 */
- (BOOL)_createDatabase:(NSString *)database 
{	
	[connection queryString:[NSString stringWithFormat:@"CREATE DATABASE %@", [database backtickQuotedString]]];	
	
	return ![connection queryErrored];
}

/**
 * This method drops a database.
 *
 * @param NSString databaseName name of the database to drop
 * @return BOOL YES on success, otherwise NO
 */
- (BOOL)_dropDatabase:(NSString *)database 
{	
	[connection queryString:[NSString stringWithFormat:@"DROP DATABASE %@", [database backtickQuotedString]]];	
	
	return ![connection queryErrored];
}

- (void)_moveTables:(NSArray *)tables fromDatabase:(NSString *)sourceDatabase toDatabase:(NSString *)targetDatabase
{
	SPTableCopy *dbActionTableCopy = [[SPTableCopy alloc] init];
	
	[dbActionTableCopy setConnection:connection];
	
	for (NSString *table in tables) 
	{
		[dbActionTableCopy moveTable:table from:sourceDatabase to:targetDatabase];
	}
	
	[dbActionTableCopy release];
}

- (void)_moveViews:(NSArray *)views fromDatabase:(NSString *)sourceDatabase toDatabase:(NSString *)targetDatabase
{
	SPViewCopy *dbActionViewCopy = [[SPViewCopy alloc] init];
	
	[dbActionViewCopy setConnection:connection];
	
	for (NSString *view in views) 
	{
		[dbActionViewCopy moveView:view from:sourceDatabase to:targetDatabase];
	}
	
	[dbActionViewCopy release];
}

@end
