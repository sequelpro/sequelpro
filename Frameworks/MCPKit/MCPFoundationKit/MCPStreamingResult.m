//
//	$Id$
//
//  MCPStreamingResult.m
//  sequel-pro
//
//  Created by Rowan Beentje on Aug 16, 2009
//  Copyright 2009 Rowan Beentje. All rights reserved.
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

#import "MCPStreamingResult.h"
#import "MCPConnection.h"
#import "MCPNull.h"
#import "MCPNumber.h"

/**
 * IMPORTANT NOTE
 *
 * MCPStreamingResult can produce fast and low-memory result reads, but should not
 * be widely used for reads as it can result in MySQL thread or table blocking.
 */


@implementation MCPStreamingResult : MCPResult

#pragma mark -
#pragma mark Setup and teardown

/**
 * Initialise a MCPStreamingResult in the same way as MCPResult - as used
 * internally by the MCPConnection !{queryString:} method.
 */
- (id)initWithMySQLPtr:(MYSQL *)mySQLPtr encoding:(NSStringEncoding)theEncoding timeZone:(NSTimeZone *)theTimeZone connection:(MCPConnection *)theConnection
{
	if ((self = [super init])) {
		mEncoding = theEncoding;
		mTimeZone = [theTimeZone retain];
		parentConnection = theConnection;
		
		if (mResult) {
			mysql_free_result(mResult);
			mResult = NULL;
		}
		
		if (mNames) {
			[mNames release];
			mNames = NULL;
		}
		
		mResult = mysql_use_result(mySQLPtr);
		
		if (mResult) {
			mNumOfFields = mysql_num_fields(mResult);
			fieldDefinitions = mysql_fetch_fields(mResult);
		} else {
			mNumOfFields = 0;
		}
		
		if (mMySQLLocales == NULL) {
			mMySQLLocales = [[MCPConnection getMySQLLocales] retain];
		}
	}
	
	return self;
}

/**
 * Deallocate the result and unlock the parent connection for further use
 */
- (void) dealloc
{
	[parentConnection unlockConnection];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Results fetching

/**
 * Retrieve the next row of the result as an array.  Should be called in a loop
 * until nil is returned to ensure all the results have been retrieved.
 */
- (NSArray *)fetchNextRowAsArray
{
	MYSQL_ROW theRow;
	unsigned long *fieldLengths;
	int i;
	NSMutableArray *returnArray;

	// Retrieve the next row
	theRow = mysql_fetch_row(mResult);

	// If no data was returned, we're at the end of the result set - return nil.
	if (theRow == NULL) return nil;

	// Retrieve the lengths of the returned data
	fieldLengths = mysql_fetch_lengths(mResult);

	// Initialise the array to return
	returnArray = [NSMutableArray arrayWithCapacity:mNumOfFields];
	for (i = 0; i < mNumOfFields; i++) {
		id cellData;

		// Use NSNulls for the NULL data type
		if (theRow[i] == NULL) {
			cellData = [NSNull null];

		// Otherwise, switch by data type
		} else {

			// Create a null-terminated data string for processing
			char *theData = calloc(sizeof(char), fieldLengths[i]+1);
			memcpy(theData, theRow[i], fieldLengths[i]);
			theData[fieldLengths[i]] = '\0';

			switch (fieldDefinitions[i].type) {
				case FIELD_TYPE_TINY:
				case FIELD_TYPE_SHORT:
				case FIELD_TYPE_INT24:
				case FIELD_TYPE_LONG:
				case FIELD_TYPE_LONGLONG:
				case FIELD_TYPE_DECIMAL:
				case FIELD_TYPE_NEWDECIMAL:
				case FIELD_TYPE_FLOAT:
				case FIELD_TYPE_DOUBLE:
				case FIELD_TYPE_TIMESTAMP:
				case FIELD_TYPE_DATE:
				case FIELD_TYPE_TIME:
				case FIELD_TYPE_DATETIME:
				case FIELD_TYPE_YEAR:
				case FIELD_TYPE_VAR_STRING:
				case FIELD_TYPE_STRING:
				case FIELD_TYPE_SET:
				case FIELD_TYPE_ENUM:
				case FIELD_TYPE_NEWDATE: // Don't know what the format for this type is...
					cellData = [NSString stringWithCString:theData encoding:mEncoding];
					break;
					
				case FIELD_TYPE_BIT:
					cellData = [NSString stringWithFormat:@"%u", theData[0]];
					break;
					
				case FIELD_TYPE_TINY_BLOB:
				case FIELD_TYPE_BLOB:
				case FIELD_TYPE_MEDIUM_BLOB:
				case FIELD_TYPE_LONG_BLOB:
					
					// For binary data, return the data
					if (fieldDefinitions[i].flags & BINARY_FLAG) {
						cellData = [NSData dataWithBytes:theData length:fieldLengths[i]];

					// For string data, convert to text
					} else {
						cellData = [[NSString alloc] initWithBytes:theData length:fieldLengths[i] encoding:mEncoding];
						if (cellData) [cellData autorelease];
					}
					break;
					
				case FIELD_TYPE_NULL:
					cellData = [NSNull null];
					break;
					
				default:
					NSLog(@"in fetchNextRowAsArray : Unknown type : %d for column %d, sending back a NSData object", (int)fieldDefinitions[i].type, (int)i);
					cellData = [NSData dataWithBytes:theData length:fieldLengths[i]];
					break;
			}

			free(theData);

			// If a creator returned a nil object, replace with NSNull
			if (cellData == nil) cellData = [NSNull null];
		}

		[returnArray insertObject:cellData atIndex:i];
	}

	return returnArray;
}

#pragma mark -
#pragma mark Overrides for safety

- (my_ulonglong) numOfRows
{
	NSLog(@"numOfRows cannot be used with streaming results");
	return 0;
}

- (void) dataSeek:(my_ulonglong) row
{
	NSLog(@"dataSeek cannot be used with streaming results");
}

@end