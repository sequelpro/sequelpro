//
//  $Id$
//
//  SPDatabaseCopy.h
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
#import "SPDatabaseInfo.h"

/**
 * The SPDatabaseCopy class povides functionality to create a copy of a database.
 */
@interface SPDatabaseCopy : SPDBActionCommons 
{
	SPDatabaseInfo *dbInfo;
}

/**
 * @property SPDatabaseInfo an instance of the database info class
 */
@property (retain) SPDatabaseInfo *dbInfo;

/**
 * This method retrieves the dbInfo object if it exists; otherwise it is generated and the
 * connection is passed to it.
 *
 * @result SPDatabaseInfo dbInfo object
 */
- (SPDatabaseInfo *)getDBInfoObject;

/**
 * This method clones an existing database.
 *
 * @param NSString sourceDatabaseName the name of the source database
 * @param NSString targetDatabaseName the name of the target database
 * @result BOOL success
 */
- (BOOL)copyDatabaseFrom:(NSString *)sourceDatabaseName to:(NSString *)targetDatabaseName withContent:(BOOL)copyWithContent;

/**
 * This method creates a new database.
 *
 * @param NSString newDatabaseName name of the new database to be created
 * @return BOOL YES on success, otherwise NO
 */
- (BOOL)createDatabase:(NSString *)newDatabaseName;

@end
