//
//  $Id$
//
//  SPTableCopy.h
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

/**
 * The SPTableCopy class povides functionality to copy tables between databases.
 */
@interface SPTableCopy : SPDBActionCommons {
}

/**
 * This method copies a table structure from one db to another.
 *
 * @param name name of the table in the source database
 * @param sourceDB name of the source database
 * @param targetDB name of the target database
 */
- (BOOL)copyTable:(NSString *)name from: (NSString *)sourceDB to: (NSString *)targetDB;

/**
 * This method moves a table from one db to another.
 *
 * @param name name of the table in the source database
 * @param sourceDB name of the source database
 * @param targetDB name of the target database
 */
- (BOOL)moveTable:(NSString *)name from: (NSString *)sourceDB to: (NSString *)targetDB;

/**
 * This method copies a table including its data from one db to another.
 *
 * @param name name of the table in the source database
 * @param sourceDB name of the source database
 * @param targetDB name of the target database
 * @param copyWithContent whether to copy the content too, otherwise only structure
 */
- (BOOL)copyTable:(NSString *)tableName from: (NSString *)sourceDB to: (NSString *)targetDB withContent:(BOOL)copyWithContent;

@end
