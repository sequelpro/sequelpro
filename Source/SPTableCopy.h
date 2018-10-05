//
//  SPTableCopy.h
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

#import "SPDatabaseAction.h"

/**
 * The SPTableCopy class povides functionality to copy tables between databases.
 */
@interface SPTableCopy : SPDatabaseAction

/**
 * This method copies a table structure from one db to another.
 *
 * @param name name of the table in the source database
 * @param sourceDatabase name of the source database
 * @param targetDatabase name of the target database
 *
 * @return YES on success, NO on any kind of error (unspecified)
 */
- (BOOL)copyTable:(NSString *)name from:(NSString *)sourceDatabase to:(NSString *)targetDatabase;

/**
 * This method moves a table from one db to another.
 *
 * @param name name of the table in the source database
 * @param sourceDatabase name of the source database
 * @param targetDatabase name of the target database
 */
- (BOOL)moveTable:(NSString *)name from:(NSString *)sourceDatabase to:(NSString *)targetDatabase;

/**
 * This method copies a table including its data from one db to another.
 *
 * @param name name of the table in the source database
 * @param sourceDatabase name of the source database
 * @param targetDatabase name of the target database
 * @param copyWithContent whether to copy the content too, otherwise only structure
 *
 * @return YES on success, NO on any kind of error (unspecified)
 */
- (BOOL)copyTable:(NSString *)tableName from:(NSString *)sourceDatabase to:(NSString *)targetDatabase withContent:(BOOL)copyWithContent;

/**
 * This method copies a bunch of tables including their data from one db to another.
 *
 * @param tableArray array of NSStrings with the table names in the sourceDB
 * @param sourceDatabase name of the source database
 * @param targetDatabase name of the target database
 * @param copyWithContent whether to copy the content too, otherwise only structure
 *
 * @return YES on success, NO on any kind of error (unspecified)
 *
 * This method is able to copy InnoDB tables with foreign key constraints.
 */
- (BOOL)copyTables:(NSArray *)tablesArray from:(NSString *)sourceDatabase to:(NSString *)targetDatabase withContent:(BOOL)copyWithContent;

@end
