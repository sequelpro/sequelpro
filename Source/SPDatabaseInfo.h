//
//  $Id: $
//
//  SPDatabaseInfo.h
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
