//
//  MCPFastQueries.m
//  SMySQL
//
//  Created by Serge Cohen (serge.cohen@m4x.org) on Mon Jun 03 2002.
//  Copyright (c) 2001 Serge Cohen.
//
//  This code is free software; you can redistribute it and/or modify it under
//  the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or any later version.
//
//  This code is distributed in the hope that it will be useful, but WITHOUT ANY
//  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
//  details.
//
//  For a copy of the GNU General Public License, visit <http://www.gnu.org/> or
//  write to the Free Software Foundation, Inc., 59 Temple Place--Suite 330,
//  Boston, MA 02111-1307, USA.
//
//  More info at <http://mysql-cocoa.sourceforge.net/>
//
// $Id: MCPFastQueries.m 334 2006-01-08 20:32:38Z serge $
// $Author: serge $

#import "MCPResultPlus.h"

#import "MCPFastQueries.h"


@implementation MCPConnection (MCPFastQueries)
/*"
!{ $Id: MCPFastQueries.m 334 2006-01-08 20:32:38Z serge $ }
 
This actegory is made up to keep the extra methods out or the core of the framework.

Basicly this is the place to add methods which are useful, but are just wrappers to the methods of the core (MCPConnection, MCPResult). The purpous being to have a single line call available for current tasks which otherwise would need a couple of lines and object defined.
"*/

- (my_ulonglong) insertQuery:(NSString *) aQuery
/*"
Send the query aQuery to the server and retrieve the row id if the table have a autoincrement column.
Returns 0 if nothing have been inserted.
"*/
{
    [self queryString:aQuery];
    return [self insertId];
}


- (my_ulonglong) updateQuery:(NSString *) aQuery
/*"
Send the query aQuery to the server and retrieve the number of affected rows (should work with !{update}, !{delete}, !{insert} and !{select} type of queries).

NB: This can also be used with a !{select} query if you are only interested in the number of row complying with the query; you'll get no chance to get the result from the query, except by sending the query again (with !{queryString:})
"*/
{
    [self queryString:aQuery];
    return [self affectedRows];
}


- (id) getFirstFieldFromQuery:(NSString *) aQuery
/*"
Get the first field of the first row of the result from the query (aQuery). Should return nil if no object at all are selected.
"*/
{
    MCPResult		*theResult = [self queryString:aQuery];
    return [[theResult fetchRowAsType:MCPTypeArray] objectAtIndex:0];
}


- (id) getFirstRowFromQuery:(NSString *) aQuery asType:(MCPReturnType) aType
/*"
Get the firdst row of the result from the query aQuery, in a collection of type determined by aType (MCPTypeArray or MCPTypeDictionary)
"*/
{
    MCPResult		*theResult = [self queryString:aQuery];
    return [theResult fetchRowAsType:aType];
}


- (id) getAllRowsFromQuery:(NSString *) aQuery asType:(MCPReturnType) aType
/*"
Get a bidimensional table of the whole rows of the result from the query aQuery. The type of the result is choosen by aType, it can be (MCPTypeArray, MCPTypeDictionary, MCPTypeFlippedArray & MCPTypeFlippedDictionary). Description of the types can be found in method !{fetch2DResultAsType:}.
"*/
{
    MCPResult		*theResult = [self queryString:aQuery];
    return [theResult fetch2DResultAsType:aType];
}


- (NSArray *) getQuery:(NSString *) aQuery colWithIndex:(unsigned int) aCol
/*"
Get a column (as an NSArray) of the result from the query aQuery. The column is choosen from it's index, starting from 0.
"*/
{
    MCPResult		*theResult = [self queryString:aQuery];
    return [theResult fetchColAtIndex:aCol];
}


- (NSArray *) getQuery:(NSString *) aQuery colWithName:(NSString *) aColName
/*"
Get a column (as an NSArray) of the result from the query aQuery. The column is choosen from it's name.
"*/
{
    MCPResult		*theResult = [self queryString:aQuery];
    return [theResult fetchColWithName:aColName];
}

@end
