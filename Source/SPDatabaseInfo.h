//
//  SPDatabaseInfo.h
//  sequel-pro
//
//  Created by David Rekowski on 19.04.10.
//  Copyright 2010 Papaya Software GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MCPConnection.h"
#import "MCPResult.h"

/*
 * The SPDatabaseInfo class provides means of retrieving a list of database names
 */
@interface SPDatabaseInfo : NSObject {
	MCPConnection *connection;
	NSObject *parent;
}

/**
 * @property MCPConnection references the MCPKit connection to MySQL; it has to be set.
 */
@property (retain) MCPConnection *connection;

/**
 * @property the parent object that issues the action, needs to provide stuff like tableWindow for messages
 */
@property (retain) NSObject *parent;

/**
 * This method checks, whether a database exists.
 *
 * @param databaseName the name of the database to check
 * @result TRUE if it exists, otherwise FALSE
 */
-(BOOL)databaseExists:(NSString *)databaseName;

/**
 * This method retrieves a list of all databases.
 *
 * @result NSArray databaseNames
 */
- (NSArray *)listDBs;

/**
 * This method retrieves a list of databases like the given string
 *
 * @param NSString dbsName name of the database substring to match
 * @result NSArray databaseNames
 */
- (NSArray *)listDBsLike:(NSString *)dbsName;

@end
