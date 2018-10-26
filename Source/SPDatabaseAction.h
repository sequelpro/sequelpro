//
//  SPDatabaseAction.h
//  sequel-pro
//
//  Created by David Rekowski on April 29, 2010.
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

@class SPTablesList;
@class SPMySQLConnection;
@class SPCreateDatabaseInfo;

@interface SPDatabaseAction : NSObject 
{
	NSWindow *messageWindow;
	SPTablesList *tablesList;
	SPMySQLConnection *connection;
}

/**
 * @property connection References the SPMySQL.framework MySQL connection; it has to be set.
 */
@property (nonnull, readwrite, assign) SPMySQLConnection *connection;


/**
 * @property tablesList
 */
@property (nonnull, readwrite, assign) SPTablesList *tablesList;

/**
 * This method creates a new database.
 *
 * @param dbInfo database name/charset/collation (charset, collation may be nil)
 *
 * @return success
 *
 * @see createDatabase:withEncoding:collation:
 */
- (BOOL)createDatabase:(SPCreateDatabaseInfo * _Nonnull)databaseInfo;

/**
 * This method creates a new database.
 *
 * @param database  name of the new database to be created
 * @param encoding  charset of the new database (can be nil to skip)
 * @param collation sorting collation of the new database (can be nil)
 *
 * @return YES on success, otherwise NO
 */
- (BOOL)createDatabase:(NSString * _Nonnull)database withEncoding:(NSString * _Nullable)encoding collation:(NSString * _Nullable)collation;

@end
