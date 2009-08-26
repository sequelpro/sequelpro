//
//  $Id$
//
//  MCPFastQueries.m
//  MCPKit
//
//  Created by Serge Cohen (serge.cohen@m4x.org) on 03/06/2002.
//  Copyright (c) 2001 Serge Cohen. All rights reserved.
//
//  Forked by the Sequel Pro team (sequelpro.com), April 2009
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
//  More info at <http://mysql-cocoa.sourceforge.net/>
//  More info at <http://code.google.com/p/sequel-pro/>

#import "MCPFastQueries.h"
#import "MCPResultPlus.h"

/**
 * This actegory is made up to keep the extra methods out or the core of the framework.
 *
 * Basicly this is the place to add methods which are useful, but are just wrappers to the methods of the 
 * core (MCPConnection, MCPResult). The purpous being to have a single line call available for current tasks 
 * which otherwise would need a couple of lines and object defined.
 */
@implementation MCPConnection (MCPFastQueries)

/**
 * Send the query aQuery to the server and retrieve the row id if the table have a autoincrement column.
 * Returns 0 if nothing have been inserted.
 */
- (my_ulonglong)insertQuery:(NSString *)query
{	
	[self queryString:query];
	
    return [self insertId];
}

/**
 * Send the query aQuery to the server and retrieve the number of affected rows (should work with !{update}, 
 * !{delete}, !{insert} and !{select} type of queries).
 *
 * NB: This can also be used with a !{select} query if you are only interested in the number of row complying 
 * with the query; you'll get no chance to get the result from the query, except by sending the query 
 * again (with !{queryString:})
 */
- (my_ulonglong)updateQuery:(NSString *)query
{	
	[self queryString:query];
	
    return [self affectedRows];
}

/**
 * Get the first field of the first row of the result from the query (aQuery). Should return nil if no object 
 * at all are selected.
 */
- (id)getFirstFieldFromQuery:(NSString *)query
{	
    return [[[self queryString:query] fetchRowAsType:MCPTypeArray] objectAtIndex:0];
}

/**
 * Get the firdst row of the result from the query aQuery, in a collection of type determined by aType 
 * (MCPTypeArray or MCPTypeDictionary)
 */
- (id) getFirstRowFromQuery:(NSString *)query asType:(MCPReturnType)type
{	
    return [[self queryString:query] fetchRowAsType:type];
}

/**
 * Get a bidimensional table of the whole rows of the result from the query aQuery. The type of the result is 
 * choosen by aType, it can be (MCPTypeArray, MCPTypeDictionary, MCPTypeFlippedArray & MCPTypeFlippedDictionary). 
 * Description of the types can be found in method !{fetch2DResultAsType:}.
 */
- (id)getAllRowsFromQuery:(NSString *)query asType:(MCPReturnType)type

{   
	return [[self queryString:query] fetch2DResultAsType:type];
}

/**
 * Get a column (as an NSArray) of the result from the query aQuery. The column is choosen from it's index, 
 * starting from 0.
 */
- (NSArray *)getQuery:(NSString *)query colWithIndex:(NSUInteger)col
{    
	return [[self queryString:query] fetchColAtIndex:col];
}

/**
 * Get a column (as an NSArray) of the result from the query aQuery. The column is choosen from it's name.
 */
- (NSArray *)getQuery:(NSString *)query colWithName:(NSString *)colName
{    
	return [[self queryString:query] fetchColWithName:colName];
}

@end
