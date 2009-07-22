//
//  $Id: MCPResultPlus.m 1056 2009-07-18 10:42:29Z stuart02 $
//
//  MCPResultPlus.m
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

#import "MCPResultPlus.h"

/**
 * This Category is provided to get shortcuts reformat the table obtained by a MCPResult 
 * (fetching a column, a 2D array...).
 */
@implementation MCPResult (MCPResultPlus)

/**
 * Getting a complete column into a NSArray (1D). The index starts from 0 (first column).
 *
 * The index 0 of the returned array always correspond to the first row (ie: returned NSArray is indexed 
 * by row number), the read position is restored after to it's initial position after the read. 
 */
- (NSArray *)fetchColAtIndex:(unsigned int)col
{
    NSMutableArray   *theCol = [NSMutableArray arrayWithCapacity:[self numOfRows]];
    MYSQL_ROW_OFFSET thePosition;
    NSArray			 *theRow;

    if ((mResult == NULL) || ([self numOfRows] == 0)) {
		// If there is no results, returns nil.
        return nil;
    }
    if (col >= mNumOfFields) {
		// Bad column number
        NSLog (@"The index : %d is not within the range 0 - %d\n", (long)col, (long)mNumOfFields);
        return nil;
    }

    thePosition = mysql_row_tell(mResult);
	
    [self dataSeek:0];

	// One might want to have optimized code here. Maybe in later versions
    while (theRow = [self fetchRowAsType:MCPTypeArray]) 
	{
        [theCol addObject:[theRow objectAtIndex:col]];
    }

	// Returning to the proper row
    mysql_row_seek(mResult, thePosition);
	
    return [NSArray arrayWithArray:theCol];
}

/**
 * The same as !{fetchColAtIndex:}, but the choice of the column is done by it's field name. Indeed it is just 
 * a wrapper to !{fetchColAtIndex}.
 */
- (NSArray *)fetchColWithName:(NSString *)colName
{
    unsigned int theCol;
    
    if (mResult == NULL) {
		// If there is no results, returns nil.
        return nil;
    }
	
    if (mNames == nil) {
        [self fetchFieldNames];
    }
    
	if ([mNames indexOfObject:colName] == NSNotFound) {
        NSLog(@"No column have been found with name : %@\n", colName);
        return nil;
    }
	
	theCol = [mNames indexOfObject:colName];
	
    return [self fetchColAtIndex:theCol];
}

/**
 * Returns the complete result table in a 2D object, which type depends on aType:
 *
 * - !{MCPTypeArray} : a NSArray of rows as NSArray,
 *
 * - !{MCPTypeDictionary} : a NSArray of rows as NSDictionary,
 *
 * - !{MCPTypeFlippedArray} : a NSArray of columns (as NSArray),
 * 
 * - !{MCPTypeFlippedDictionary} : a NSDictionary of columns (as NSArray)
 * 
 * In any case the read position is restored at the end of the call (hence a fetchRow will get the same row 
 * wether this method is called before it or not).
 */
- (id) fetch2DResultAsType:(MCPReturnType)type;
{
    id				 theTable, theVect;
    MYSQL_ROW_OFFSET thePosition;
    unsigned int	 i;

    if (mResult == NULL) {
		// If there is no results, returns nil.
        return nil;
    }
	
    thePosition = mysql_row_tell(mResult);
	
    [self dataSeek:0];
    
    switch (type) 
	{
        case MCPTypeArray :
            theTable = [NSMutableArray arrayWithCapacity:[self numOfRows]];
			
            while (theVect = [self fetchRowAsArray]) 
			{
                [theTable addObject:theVect];
            }
			
            theTable = [NSArray arrayWithArray:theTable];
            break;
        case MCPTypeDictionary :
            theTable = [NSMutableArray arrayWithCapacity:[self numOfRows]];
            
			while (theVect = [self fetchRowAsDictionary]) 
			{
                [theTable addObject:theVect];
            }
			
            theTable = [NSArray arrayWithArray:theTable];
            break;
        case MCPTypeFlippedArray :
            theTable = [NSMutableArray arrayWithCapacity:mNumOfFields];
            
			for (i=0; i<mNumOfFields; i++) 
			{
                [theTable addObject:[self fetchColAtIndex:i]];
            }
			
            theTable = [NSArray arrayWithArray:theTable];
            break;
        case MCPTypeFlippedDictionary :
            theTable = [NSMutableDictionary dictionaryWithCapacity:mNumOfFields];
            
			if (mNames == nil) {
                [self fetchFieldNames];
            }
            
			for (i=0; i<mNumOfFields; i++) 
			{
                [theTable setObject:[self fetchColAtIndex:i] forKey:[mNames objectAtIndex:i]];
            }
			
            theTable = [NSDictionary dictionaryWithDictionary:theTable];
            break;
        default :
            NSLog (@"Unknown MCPReturnType : %d; return nil\n", (int)type);
            theTable = nil;
            break;
    }

    mysql_row_seek(mResult, thePosition);
	
    return theTable;
}

@end
