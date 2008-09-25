//
//  CMMCPResult.m
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed Sept 21 2005.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
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
//  Or mail to <lorenz@textor.ch>

#import "CMMCPResult.h"


@implementation CMMCPResult

- (id) fetchRowAsType:(MCPReturnType) aType
/*"
modified version for use with sequel-pro
"*/
{
    MYSQL_ROW			theRow;
    unsigned long		*theLengths;
    MYSQL_FIELD			*theField;
    int				i;
    id				theReturn;

    if (mResult == NULL) {
// If there is no results, returns nil, as after the last row...
        return nil;
    }

    theRow = mysql_fetch_row(mResult);
    if (theRow == NULL) {
        return nil;
    }

    switch (aType) {
        case MCPTypeArray:
            theReturn = [NSMutableArray arrayWithCapacity:mNumOfFields];
            break;
        case MCPTypeDictionary:
            if (mNames == nil) {
                [self fetchFieldNames];
            }
            theReturn = [NSMutableDictionary dictionaryWithCapacity:mNumOfFields];
            break;
        default :
            NSLog (@"Unknown type : %d, will return an Array!\n", aType);
            theReturn = [NSMutableArray arrayWithCapacity:mNumOfFields];
            break;
    }

    theLengths = mysql_fetch_lengths(mResult);
    theField = mysql_fetch_fields(mResult);
    for (i=0; i<mNumOfFields; i++) {
        id	theCurrentObj;

        if (theRow[i] == NULL) {
            theCurrentObj = [NSNull null];
        }
        else {
            char	*theData = calloc(sizeof(char),theLengths[i]+1);
//			   char  *theUselLess;
            memcpy(theData, theRow[i],theLengths[i]);
            theData[theLengths[i]] = '\0';

            switch (theField[i].type) {
                case FIELD_TYPE_TINY:
                case FIELD_TYPE_SHORT:
                case FIELD_TYPE_INT24:
                case FIELD_TYPE_LONG:
                case FIELD_TYPE_LONGLONG:
                case FIELD_TYPE_DECIMAL:
                case FIELD_TYPE_FLOAT:
                case FIELD_TYPE_DOUBLE:
                case FIELD_TYPE_NEW_DECIMAL:					
                    theCurrentObj = [self stringWithCString:theData];
                    break;
                case FIELD_TYPE_TIMESTAMP:
                case FIELD_TYPE_DATE:
                case FIELD_TYPE_TIME:
                case FIELD_TYPE_DATETIME:
                case FIELD_TYPE_YEAR:
                    theCurrentObj = [self stringWithCString:theData];
                    break;
                case FIELD_TYPE_VAR_STRING:
                case FIELD_TYPE_STRING:
                    theCurrentObj = [self stringWithCString:theData];
                    break;
                case FIELD_TYPE_TINY_BLOB:
                case FIELD_TYPE_BLOB:
                case FIELD_TYPE_MEDIUM_BLOB:
                case FIELD_TYPE_LONG_BLOB:
                    theCurrentObj = [NSData dataWithBytes:theData length:theLengths[i]];
                   if (!(theField[i].flags & BINARY_FLAG)) { // It is TEXT and NOT BLOB...
                      theCurrentObj = [self stringWithText:theCurrentObj];
                   }
//#warning Should check for TEXT (using theField[i].flag BINARY_FLAG)
                    break;
                case FIELD_TYPE_SET:
                    theCurrentObj = [self stringWithCString:theData];
                    break;
                case FIELD_TYPE_ENUM:
                    theCurrentObj = [self stringWithCString:theData];
                    break;
                case FIELD_TYPE_NULL:
				   theCurrentObj = [NSNull null];
                    break;
                case FIELD_TYPE_NEWDATE:
// Don't know what the format for this type is...
                    theCurrentObj = [self stringWithCString:theData];
                    break;
                default:
                    NSLog (@"in fetchRowAsDictionary : Unknown type : %d for column %d, send back a NSData object", (int)theField[i].type, (int)i);
                    theCurrentObj = [NSData dataWithBytes:theData length:theLengths[i]];
                    break;
            }
            free(theData);
// Some of the creators return nil object...
            if (theCurrentObj == nil) {
                theCurrentObj = [NSNull null];
            }
        }
        switch (aType) {
            case MCPTypeArray :
                [theReturn addObject:theCurrentObj];
                break;
            case MCPTypeDictionary :
                [theReturn setObject:theCurrentObj forKey:[mNames objectAtIndex:i]];
                break;
            default :
                [theReturn addObject:theCurrentObj];
                break;
        }
    }

    return theReturn;
}

@end
