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
#define BUFFER_START 0

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
	UInt32 geoType, srid, numberOfItems, numberOfSubItems, numberOfSubSubItems, numberOfCollectionItems;
	st_point_2d aPoint;

	NSUInteger i, j, k, n;          // Loop counter for numberOf...Items
	NSUInteger ptr = BUFFER_START;  // pointer to geoBuffer while parsing

	NSMutableString *wkt = [NSMutableString string];

	if (bufferLength < WKB_HEADER_SIZE)
		return @"";

	memcpy(&srid, &geoBuffer[0], SIZEOF_STORED_UINT32);
	ptr += SIZEOF_STORED_UINT32;

	byteOrder = geoBuffer[ptr];

	if(byteOrder != 0x1)
		return @"Byte order not yet supported";

	ptr++;
	geoType = geoBuffer[ptr];
	ptr += SIZEOF_STORED_UINT32;

	switch(geoType) {

		case wkb_point:
		memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
		return [NSString stringWithFormat:@"POINT(%.16g %.16g)%@", aPoint.x, aPoint.y, (srid) ? [NSString stringWithFormat:@",%u",srid]: @""];
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
		[wkt appendFormat:@")%@", (srid) ? [NSString stringWithFormat:@",%u",srid]: @""];
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
		[wkt appendFormat:@")%@", (srid) ? [NSString stringWithFormat:@",%u",srid]: @""];
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
		[wkt appendFormat:@")%@", (srid) ? [NSString stringWithFormat:@",%u",srid]: @""];
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
		[wkt appendFormat:@")%@", (srid) ? [NSString stringWithFormat:@",%u",srid]: @""];
		return wkt;
		break;

		case wkb_multipolygon:
		[wkt setString:@"MULTIPOLYGON("];
		numberOfItems = geoBuffer[ptr];
		ptr += SIZEOF_STORED_UINT32+WKB_HEADER_SIZE;
		for(i=0; i < numberOfItems; i++) {
			numberOfSubItems = geoBuffer[ptr];
			ptr += SIZEOF_STORED_UINT32;
			[wkt appendString:@"("];
			for(j=0; j < numberOfSubItems; j++) {
				numberOfSubSubItems = geoBuffer[ptr];
				ptr += SIZEOF_STORED_UINT32;
				[wkt appendString:@"("];
				for(k=0; k < numberOfSubSubItems; k++) {
					memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
					[wkt appendFormat:@"%.16g %.16g%@", aPoint.x, aPoint.y, (k < numberOfSubSubItems-1) ? @"," : @""];
					ptr += POINT_DATA_SIZE;
				}
				[wkt appendFormat:@")%@", (j < numberOfSubItems-1) ? @"," : @""];
			}
			ptr += WKB_HEADER_SIZE;
			[wkt appendFormat:@")%@", (i < numberOfItems-1) ? @"," : @""];
		}
		[wkt appendFormat:@")%@", (srid) ? [NSString stringWithFormat:@",%u",srid]: @""];
		return wkt;
		break;

		case wkb_geometrycollection:
		[wkt setString:@"GEOMETRYCOLLECTION("];
		numberOfCollectionItems = geoBuffer[ptr];
		ptr += SIZEOF_STORED_UINT32;

		for(n=0; n < numberOfCollectionItems; n++) {

			byteOrder = geoBuffer[ptr];

			if(byteOrder != 0x1)
				return @"Byte order not yet supported";

			ptr++;
			geoType = geoBuffer[ptr];
			ptr += SIZEOF_STORED_UINT32;

			switch(geoType) {

				case wkb_point:
				memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
				[wkt appendFormat:@"POINT(%.16g %.16g)", aPoint.x, aPoint.y];
				ptr += POINT_DATA_SIZE;
				break;

				case wkb_linestring:
				[wkt appendString:@"LINESTRING("];
				numberOfItems = geoBuffer[ptr];
				ptr += SIZEOF_STORED_UINT32;
				for(i=0; i < numberOfItems; i++) {
					memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
					[wkt appendFormat:@"%.16g %.16g%@", aPoint.x, aPoint.y, (i < numberOfItems-1) ? @"," : @""];
					ptr += POINT_DATA_SIZE;
				}
				[wkt appendString:@")"];
				break;

				case wkb_polygon:
				[wkt appendString:@"POLYGON("];
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
				break;

				case wkb_multipoint:
				[wkt appendString:@"MULTIPOINT("];
				numberOfItems = geoBuffer[ptr];
				ptr += SIZEOF_STORED_UINT32+WKB_HEADER_SIZE;
				for(i=0; i < numberOfItems; i++) {
					memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
					[wkt appendFormat:@"%.16g %.16g%@", aPoint.x, aPoint.y, (i < numberOfItems-1) ? @"," : @""];
					ptr += POINT_DATA_SIZE+WKB_HEADER_SIZE;
				}
				ptr -= WKB_HEADER_SIZE;
				[wkt appendString:@")"];
				break;

				case wkb_multilinestring:
				[wkt appendString:@"MULTILINESTRING("];
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
				ptr -= WKB_HEADER_SIZE;
				[wkt appendString:@")"];
				break;

				case wkb_multipolygon:
				[wkt appendString:@"MULTIPOLYGON("];
				numberOfItems = geoBuffer[ptr];
				ptr += SIZEOF_STORED_UINT32+WKB_HEADER_SIZE;
				for(i=0; i < numberOfItems; i++) {
					numberOfSubItems = geoBuffer[ptr];
					ptr += SIZEOF_STORED_UINT32;
					[wkt appendString:@"("];
					for(j=0; j < numberOfSubItems; j++) {
						numberOfSubSubItems = geoBuffer[ptr];
						ptr += SIZEOF_STORED_UINT32;
						[wkt appendString:@"("];
						for(k=0; k < numberOfSubSubItems; k++) {
							memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
							[wkt appendFormat:@"%.16g %.16g%@", aPoint.x, aPoint.y, (k < numberOfSubSubItems-1) ? @"," : @""];
							ptr += POINT_DATA_SIZE;
						}
						[wkt appendFormat:@")%@", (j < numberOfSubItems-1) ? @"," : @""];
					}
					ptr += WKB_HEADER_SIZE;
					[wkt appendFormat:@")%@", (i < numberOfItems-1) ? @"," : @""];
				}
				ptr -= WKB_HEADER_SIZE;
				[wkt appendString:@")"];
				break;

				default:
				return @"Error geometrycollection type parsing";
			}
			[wkt appendString:(n < numberOfCollectionItems-1) ? @"," : @""];
		}
		[wkt appendFormat:@")%@", (srid) ? [NSString stringWithFormat:@",%u",srid]: @""];
		return wkt;
		break;

		default:
		return @"Error geometry type parsing";
	}
	return @"Error while parsing";
}

/**
 * Return a dictionary of coordinates, bbox, etc. to be able to draw the given geometry.
 *
 * @return A dictionary having the following keys: "bbox" as NSArray of NSNumbers of x_min x_max y_min y_max, "coordinates" as NSArray containing the 
 * the to be drawn points as NSPoint strings, "type" as NSString
 */
- (NSDictionary*)coordinates
{

	char byteOrder;
	UInt32 geoType, srid, numberOfItems, numberOfSubItems, numberOfSubSubItems, numberOfCollectionItems;
	st_point_2d aPoint;

	NSUInteger i, j, k, n;          // Loop counter for numberOf...Items
	NSUInteger ptr = BUFFER_START;  // pointer to geoBuffer while parsing

	double x_min = 1e999;
	double x_max = -1e999;
	double y_min = 1e999;
	double y_max = -1e999;

	NSMutableArray *coordinates = [NSMutableArray array];
	NSMutableArray *subcoordinates = [NSMutableArray array];
	NSMutableArray *pointcoordinates = [NSMutableArray array];
	NSMutableArray *linecoordinates = [NSMutableArray array];
	NSMutableArray *linesubcoordinates = [NSMutableArray array];
	NSMutableArray *polygoncoordinates = [NSMutableArray array];
	NSMutableArray *polygonsubcoordinates = [NSMutableArray array];

	if (bufferLength < WKB_HEADER_SIZE)
		return nil;

	memcpy(&srid, &geoBuffer[0], SIZEOF_STORED_UINT32);
	ptr += SIZEOF_STORED_UINT32;

	byteOrder = geoBuffer[ptr];

	if(byteOrder != 0x1)
		return nil;

	ptr++;
	geoType = geoBuffer[ptr];
	ptr += SIZEOF_STORED_UINT32;

	switch(geoType) {

		case wkb_point:
		memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
		x_min = aPoint.x;
		x_max = aPoint.x;
		y_min = aPoint.y;
		y_max = aPoint.y;
		[coordinates addObject:NSStringFromPoint(NSMakePoint(aPoint.x, aPoint.y))];
		return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSArray arrayWithObjects:
				[NSNumber numberWithDouble:x_min],
				[NSNumber numberWithDouble:x_max],
				[NSNumber numberWithDouble:y_min],
				[NSNumber numberWithDouble:y_max],
				nil], @"bbox",
			coordinates, @"coordinates",
			[NSNumber numberWithUnsignedInt:srid], @"srid",
			@"POINT", @"type",
			nil];
		break;

		case wkb_linestring:
		numberOfItems = geoBuffer[ptr];
		ptr += SIZEOF_STORED_UINT32;
		for(i=0; i < numberOfItems; i++) {
			memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
			x_min = (aPoint.x < x_min) ? aPoint.x : x_min;
			x_max = (aPoint.x > x_max) ? aPoint.x : x_max;
			y_min = (aPoint.y < y_min) ? aPoint.y : y_min;
			y_max = (aPoint.y > y_max) ? aPoint.y : y_max;
			[coordinates addObject:NSStringFromPoint(NSMakePoint(aPoint.x, aPoint.y))];
			ptr += POINT_DATA_SIZE;
		}
		return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSArray arrayWithObjects:
				[NSNumber numberWithDouble:x_min],
				[NSNumber numberWithDouble:x_max],
				[NSNumber numberWithDouble:y_min],
				[NSNumber numberWithDouble:y_max],
				nil], @"bbox",
			[NSArray arrayWithObjects:coordinates,nil], @"coordinates",
			@"LINESTRING", @"type",
			nil];
		break;

		case wkb_polygon:
		numberOfItems = geoBuffer[ptr];
		ptr += SIZEOF_STORED_UINT32;
		for(i=0; i < numberOfItems; i++) {
			numberOfSubItems = geoBuffer[ptr];
			ptr += SIZEOF_STORED_UINT32;
			for(j=0; j < numberOfSubItems; j++) {
				memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
				x_min = (aPoint.x < x_min) ? aPoint.x : x_min;
				x_max = (aPoint.x > x_max) ? aPoint.x : x_max;
				y_min = (aPoint.y < y_min) ? aPoint.y : y_min;
				y_max = (aPoint.y > y_max) ? aPoint.y : y_max;
				[subcoordinates addObject:NSStringFromPoint(NSMakePoint(aPoint.x, aPoint.y))];
				ptr += POINT_DATA_SIZE;
			}
			[coordinates addObject:[[subcoordinates copy] autorelease]];
			[subcoordinates removeAllObjects];
		}
		return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSArray arrayWithObjects:
				[NSNumber numberWithDouble:x_min],
				[NSNumber numberWithDouble:x_max],
				[NSNumber numberWithDouble:y_min],
				[NSNumber numberWithDouble:y_max],
				nil], @"bbox",
			coordinates, @"coordinates",
			[NSNumber numberWithUnsignedInt:srid], @"srid",
			@"POLYGON", @"type",
			nil];
		break;

		case wkb_multipoint:
		numberOfItems = geoBuffer[ptr];
		ptr += SIZEOF_STORED_UINT32+WKB_HEADER_SIZE;
		for(i=0; i < numberOfItems; i++) {
			memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
			x_min = (aPoint.x < x_min) ? aPoint.x : x_min;
			x_max = (aPoint.x > x_max) ? aPoint.x : x_max;
			y_min = (aPoint.y < y_min) ? aPoint.y : y_min;
			y_max = (aPoint.y > y_max) ? aPoint.y : y_max;
			[coordinates addObject:NSStringFromPoint(NSMakePoint(aPoint.x, aPoint.y))];
			ptr += POINT_DATA_SIZE+WKB_HEADER_SIZE;
		}
		return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSArray arrayWithObjects:
				[NSNumber numberWithDouble:x_min],
				[NSNumber numberWithDouble:x_max],
				[NSNumber numberWithDouble:y_min],
				[NSNumber numberWithDouble:y_max],
				nil], @"bbox",
			coordinates, @"coordinates",
			[NSNumber numberWithUnsignedInt:srid], @"srid",
			@"MULTIPOINT", @"type",
			nil];
		break;
		
		case wkb_multilinestring:
		numberOfItems = geoBuffer[ptr];
		ptr += SIZEOF_STORED_UINT32+WKB_HEADER_SIZE;
		for(i=0; i < numberOfItems; i++) {
			numberOfSubItems = geoBuffer[ptr];
			ptr += SIZEOF_STORED_UINT32;
			for(j=0; j < numberOfSubItems; j++) {
				memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
				x_min = (aPoint.x < x_min) ? aPoint.x : x_min;
				x_max = (aPoint.x > x_max) ? aPoint.x : x_max;
				y_min = (aPoint.y < y_min) ? aPoint.y : y_min;
				y_max = (aPoint.y > y_max) ? aPoint.y : y_max;
				[subcoordinates addObject:NSStringFromPoint(NSMakePoint(aPoint.x, aPoint.y))];
				ptr += POINT_DATA_SIZE;
			}
			ptr += WKB_HEADER_SIZE;
			[coordinates addObject:[[subcoordinates copy] autorelease]];
			[subcoordinates removeAllObjects];
		}
		return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSArray arrayWithObjects:
				[NSNumber numberWithDouble:x_min],
				[NSNumber numberWithDouble:x_max],
				[NSNumber numberWithDouble:y_min],
				[NSNumber numberWithDouble:y_max],
				nil], @"bbox",
			coordinates, @"coordinates",
			[NSNumber numberWithUnsignedInt:srid], @"srid",
			@"MULTILINESTRING", @"type",
			nil];
		break;
		
		case wkb_multipolygon:
		numberOfItems = geoBuffer[ptr];
		ptr += SIZEOF_STORED_UINT32+WKB_HEADER_SIZE;
		for(i=0; i < numberOfItems; i++) {
			numberOfSubItems = geoBuffer[ptr];
			ptr += SIZEOF_STORED_UINT32;
			for(j=0; j < numberOfSubItems; j++) {
				numberOfSubSubItems = geoBuffer[ptr];
				ptr += SIZEOF_STORED_UINT32;
				for(k=0; k < numberOfSubSubItems; k++) {
					memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
					x_min = (aPoint.x < x_min) ? aPoint.x : x_min;
					x_max = (aPoint.x > x_max) ? aPoint.x : x_max;
					y_min = (aPoint.y < y_min) ? aPoint.y : y_min;
					y_max = (aPoint.y > y_max) ? aPoint.y : y_max;
					[subcoordinates addObject:NSStringFromPoint(NSMakePoint(aPoint.x, aPoint.y))];
					ptr += POINT_DATA_SIZE;
				}
				[coordinates addObject:[[subcoordinates copy] autorelease]];
				[subcoordinates removeAllObjects];
			}
			ptr += WKB_HEADER_SIZE;
		}
		return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSArray arrayWithObjects:
				[NSNumber numberWithDouble:x_min],
				[NSNumber numberWithDouble:x_max],
				[NSNumber numberWithDouble:y_min],
				[NSNumber numberWithDouble:y_max],
				nil], @"bbox",
			coordinates, @"coordinates",
			[NSNumber numberWithUnsignedInt:srid], @"srid",
			@"MULTIPOLYGON", @"type",
			nil];
		break;
		
		case wkb_geometrycollection:
		numberOfCollectionItems = geoBuffer[ptr];
		ptr += SIZEOF_STORED_UINT32;
		
		for(n=0; n < numberOfCollectionItems; n++) {
		
			byteOrder = geoBuffer[ptr];
		
			if(byteOrder != 0x1)
				return nil;
		
			ptr++;
			geoType = geoBuffer[ptr];
			ptr += SIZEOF_STORED_UINT32;
		
			switch(geoType) {
		
				case wkb_point:
				memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
				x_min = (aPoint.x < x_min) ? aPoint.x : x_min;
				x_max = (aPoint.x > x_max) ? aPoint.x : x_max;
				y_min = (aPoint.y < y_min) ? aPoint.y : y_min;
				y_max = (aPoint.y > y_max) ? aPoint.y : y_max;
				[pointcoordinates addObject:NSStringFromPoint(NSMakePoint(aPoint.x, aPoint.y))];
				ptr += POINT_DATA_SIZE;
				break;
		
				case wkb_linestring:
				numberOfItems = geoBuffer[ptr];
				ptr += SIZEOF_STORED_UINT32;
				for(i=0; i < numberOfItems; i++) {
					memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
					x_min = (aPoint.x < x_min) ? aPoint.x : x_min;
					x_max = (aPoint.x > x_max) ? aPoint.x : x_max;
					y_min = (aPoint.y < y_min) ? aPoint.y : y_min;
					y_max = (aPoint.y > y_max) ? aPoint.y : y_max;
					[linesubcoordinates addObject:NSStringFromPoint(NSMakePoint(aPoint.x, aPoint.y))];
					ptr += POINT_DATA_SIZE;
				}
				[linecoordinates addObject:[[linesubcoordinates copy] autorelease]];
				[linesubcoordinates removeAllObjects];
				break;
		
				case wkb_polygon:
				numberOfItems = geoBuffer[ptr];
				ptr += SIZEOF_STORED_UINT32;
				for(i=0; i < numberOfItems; i++) {
					numberOfSubItems = geoBuffer[ptr];
					ptr += SIZEOF_STORED_UINT32;
					for(j=0; j < numberOfSubItems; j++) {
						memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
						x_min = (aPoint.x < x_min) ? aPoint.x : x_min;
						x_max = (aPoint.x > x_max) ? aPoint.x : x_max;
						y_min = (aPoint.y < y_min) ? aPoint.y : y_min;
						y_max = (aPoint.y > y_max) ? aPoint.y : y_max;
						[polygonsubcoordinates addObject:NSStringFromPoint(NSMakePoint(aPoint.x, aPoint.y))];
						ptr += POINT_DATA_SIZE;
					}
					[polygoncoordinates addObject:[[polygonsubcoordinates copy] autorelease]];
					[polygonsubcoordinates removeAllObjects];
				}
				break;
		
				case wkb_multipoint:
				numberOfItems = geoBuffer[ptr];
				ptr += SIZEOF_STORED_UINT32+WKB_HEADER_SIZE;
				for(i=0; i < numberOfItems; i++) {
					memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
					x_min = (aPoint.x < x_min) ? aPoint.x : x_min;
					x_max = (aPoint.x > x_max) ? aPoint.x : x_max;
					y_min = (aPoint.y < y_min) ? aPoint.y : y_min;
					y_max = (aPoint.y > y_max) ? aPoint.y : y_max;
					[pointcoordinates addObject:NSStringFromPoint(NSMakePoint(aPoint.x, aPoint.y))];
					ptr += POINT_DATA_SIZE+WKB_HEADER_SIZE;
				}
				ptr -= WKB_HEADER_SIZE;
				break;
		
				case wkb_multilinestring:
				numberOfItems = geoBuffer[ptr];
				ptr += SIZEOF_STORED_UINT32+WKB_HEADER_SIZE;
				for(i=0; i < numberOfItems; i++) {
					numberOfSubItems = geoBuffer[ptr];
					ptr += SIZEOF_STORED_UINT32;
					for(j=0; j < numberOfSubItems; j++) {
						memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
						x_min = (aPoint.x < x_min) ? aPoint.x : x_min;
						x_max = (aPoint.x > x_max) ? aPoint.x : x_max;
						y_min = (aPoint.y < y_min) ? aPoint.y : y_min;
						y_max = (aPoint.y > y_max) ? aPoint.y : y_max;
						[linesubcoordinates addObject:NSStringFromPoint(NSMakePoint(aPoint.x, aPoint.y))];
						ptr += POINT_DATA_SIZE;
					}
					[linecoordinates addObject:[[linesubcoordinates copy] autorelease]];
					[linesubcoordinates removeAllObjects];
					ptr += WKB_HEADER_SIZE;
				}
				ptr -= WKB_HEADER_SIZE;
				break;
		
				case wkb_multipolygon:
				numberOfItems = geoBuffer[ptr];
				ptr += SIZEOF_STORED_UINT32+WKB_HEADER_SIZE;
				for(i=0; i < numberOfItems; i++) {
					numberOfSubItems = geoBuffer[ptr];
					ptr += SIZEOF_STORED_UINT32;
					for(j=0; j < numberOfSubItems; j++) {
						numberOfSubSubItems = geoBuffer[ptr];
						ptr += SIZEOF_STORED_UINT32;
						for(k=0; k < numberOfSubSubItems; k++) {
							memcpy(&aPoint, &geoBuffer[ptr], POINT_DATA_SIZE);
							x_min = (aPoint.x < x_min) ? aPoint.x : x_min;
							x_max = (aPoint.x > x_max) ? aPoint.x : x_max;
							y_min = (aPoint.y < y_min) ? aPoint.y : y_min;
							y_max = (aPoint.y > y_max) ? aPoint.y : y_max;
							[polygonsubcoordinates addObject:NSStringFromPoint(NSMakePoint(aPoint.x, aPoint.y))];
							ptr += POINT_DATA_SIZE;
						}
						[polygoncoordinates addObject:[[polygonsubcoordinates copy] autorelease]];
						[polygonsubcoordinates removeAllObjects];
					}
					ptr += WKB_HEADER_SIZE;
				}
				ptr -= WKB_HEADER_SIZE;
				break;
		
				default:
				return nil;
			}
		}
		return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSArray arrayWithObjects:
				[NSNumber numberWithDouble:x_min],
				[NSNumber numberWithDouble:x_max],
				[NSNumber numberWithDouble:y_min],
				[NSNumber numberWithDouble:y_max],
				nil], @"bbox",
			[NSArray arrayWithObjects:pointcoordinates, linecoordinates, polygoncoordinates, nil], @"coordinates",
			@"GEOMETRYCOLLECTION", @"type",
			nil];
		break;

		default:
		return nil;
	}
	return nil;
}

/**
 * Return the WKB type of the geoBuffer ie if buffer represents a POINT, LINESTRING, etc.
 * according to stored wkbType in header file. It returns -1 if an error occurred.
 */
- (NSInteger)wkbType
{
	char byteOrder;
	UInt32 geoType;

	NSUInteger ptr = BUFFER_START;  // pointer to geoBuffer while parsing

	if (bufferLength < WKB_HEADER_SIZE)
		return @"-1";

	byteOrder = geoBuffer[ptr];

	if(byteOrder != 0x1)
		return -1;

	ptr++;
	geoType = geoBuffer[ptr];
	
	if(geoType > 0 && geoType < 8)
		return geoType;
	else
		return -1;
	
}

/**
 * Return the WKT type of the geoBuffer ie if buffer represents a POINT, LINESTRING, etc.
 * according to stored wkbType in header file. It returns nil if an error occurred.
 */
- (NSString*)wktType
{
	switch([self wkbType])
	{
		case wkb_point:
		return @"POINT";
		case wkb_linestring:
		return @"LINESTRING";
		case wkb_polygon:
		return @"POLYGON";
		case wkb_multipoint:
		return @"MULTIPOINT";
		case wkb_multilinestring:
		return @"MULTILINESTRING";
		case wkb_multipolygon:
		return @"MULTIPOLYGON";
		case wkb_geometrycollection:
		return @"GEOMETRYCOLLECTION";
		default:
		return nil;
	}
	return nil;
}

/**
 * dealloc
 */
- (void)dealloc
{
	if(geoBuffer && bufferLength) free(geoBuffer);
	[super dealloc];
}

@end
