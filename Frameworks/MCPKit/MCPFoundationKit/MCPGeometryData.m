//
//  $Id$
//
//  MCPGeometryData.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on October 07, 2010
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

#import "MCPGeometryData.h"


#define SIZEOF_STORED_UINT32 4
#define SIZEOF_STORED_DOUBLE 8
#define POINT_DATA_SIZE (SIZEOF_STORED_DOUBLE*2)
#define WKB_HEADER_SIZE (1+SIZEOF_STORED_UINT32)

@implementation MCPGeometryData

/**
 * Initialize the MCPGeometryData object
 */
- (id)init
{
	if ((self = [super init])) {
		geoBuffer = nil;
		bufferLength = 0;
	}
	return self;
}

/**
 * Initialize the MCPGeometryData object with the WKB data
 */
- (id)initWithBytes:(Byte*)geoData length:(NSUInteger)length
{
	if ((self = [self init])) {
		bufferLength = length;
		geoBuffer = malloc(bufferLength);
		memcpy(geoBuffer, geoData, bufferLength);
	}
	return self;
}

/**
 * Return an autorelease MCPGeometryData object
 */
+ (id)dataWithBytes:(Byte*)geoData length:(NSUInteger)length
{
	return [[[MCPGeometryData alloc] initWithBytes:geoData length:length] autorelease];
}

/**
 * copyWithZone
 */
- (id)copyWithZone:(NSZone *)zone
{
	return [self retain];
}

/**
 * Return the hex representation of the WKB buffer (only for convenience)
 */
- (NSString*)description
{
	return [[NSData dataWithBytes:geoBuffer length:bufferLength] description];
}

/**
 * Return the length of the WKB buffer
 */
- (NSUInteger)length
{
	return bufferLength;
}

/**
 * Return NSData pointer of the WKB buffer
 */
- (NSData*)data
{
	return [NSData dataWithBytes:geoBuffer length:bufferLength];
}

/**
 * Return a human readable WKT string of the internal format (it imitate the SQL function AsText()).
 */
- (NSString*)wktString
{

	char byteOrder;
	UInt32 geoType, numberOfItems, numberOfSubItems;
	st_point_2d aPoint;

	NSUInteger ptr, i, j;

	NSMutableString *wkt = [NSMutableString string];

	BOOL raw = NO; // is needed later
	
	if (bufferLength < WKB_HEADER_SIZE)
		return @"Header Error";

	ptr = (raw) ? 0 : 4;

	byteOrder = geoBuffer[ptr];

	if(byteOrder != 0x1)
		return @"Byte order not yet supported";

	ptr++;
	geoType = geoBuffer[ptr];
	ptr += SIZEOF_STORED_UINT32;

	switch(geoType) {

		case wkb_point:
		memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
		return [NSString stringWithFormat:@"POINT(%.16g %.16g)", aPoint.x, aPoint.y];
		break;

		case wkb_linestring:
		[wkt setString:@"LINESTRING("];
		numberOfItems = geoBuffer[ptr];
		ptr += SIZEOF_STORED_UINT32;
		for(i=0; i < numberOfItems; i++) {
			memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
			[wkt appendFormat:@"%.16g %.16g%@", aPoint.x, aPoint.y, (i < numberOfItems-1) ? @"," : @""];
			ptr += POINT_DATA_SIZE;
		}
		[wkt appendString:@")"];
		return wkt;
		break;

		case wkb_polygon:
		[wkt setString:@"POLYGON("];
		numberOfItems = geoBuffer[ptr];
		ptr += SIZEOF_STORED_UINT32;
		for(i=0; i < numberOfItems; i++) {
			numberOfSubItems = geoBuffer[ptr];
			ptr += SIZEOF_STORED_UINT32;
			[wkt appendString:@"("];
			for(j=0; j < numberOfSubItems; j++) {
				memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
				[wkt appendFormat:@"%.16g %.16g%@", aPoint.x, aPoint.y, (j < numberOfSubItems-1) ? @"," : @""];
				ptr += POINT_DATA_SIZE;
			}
			[wkt appendFormat:@")%@", (i < numberOfItems-1) ? @"," : @""];
		}
		[wkt appendString:@")"];
		return wkt;
		break;

		case wkb_multipoint:
		[wkt setString:@"MULTIPOINT("];
		numberOfItems = geoBuffer[ptr];
		ptr += SIZEOF_STORED_UINT32+WKB_HEADER_SIZE;
		for(i=0; i < numberOfItems; i++) {
			memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
			[wkt appendFormat:@"%.16g %.16g%@", aPoint.x, aPoint.y, (i < numberOfItems-1) ? @"," : @""];
			ptr += POINT_DATA_SIZE+WKB_HEADER_SIZE;
		}
		[wkt appendString:@")"];
		return wkt;
		break;

		case wkb_multilinestring:
		[wkt setString:@"MULTILINESTRING("];
		numberOfItems = geoBuffer[ptr];
		ptr += SIZEOF_STORED_UINT32+WKB_HEADER_SIZE;
		for(i=0; i < numberOfItems; i++) {
			numberOfSubItems = geoBuffer[ptr];
			ptr += SIZEOF_STORED_UINT32;
			[wkt appendString:@"("];
			for(j=0; j < numberOfSubItems; j++) {
				memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
				[wkt appendFormat:@"%.16g %.16g%@", aPoint.x, aPoint.y, (j < numberOfSubItems-1) ? @"," : @""];
				ptr += POINT_DATA_SIZE;
			}
			ptr += WKB_HEADER_SIZE;
			[wkt appendFormat:@")%@", (i < numberOfItems-1) ? @"," : @""];
		}
		[wkt appendString:@")"];
		return wkt;
		break;

		case wkb_multipolygon:
		// NSLog(@"ml %@", geoData);
		
		[wkt setString:@"MULTIPOLYGON be patient"];
		break;

		case wkb_geometrycollection:
		[wkt setString:@"GEOMETRYCOLLECTION be patient"];
		break;

		default:
		return @"Error geometry type parsing";
	}
	return wkt;
}

- (void)dealloc
{
	if(geoBuffer && bufferLength) free(geoBuffer);
	[super dealloc];
}

@end
