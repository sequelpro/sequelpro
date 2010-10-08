//
//  $Id$
//
//  SPGeometryDataView.h
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on October 08, 2010
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

#import "SPGeometryDataView.h"


@implementation SPGeometryDataView

/**
 * Initialize SPGeometryDataView object
 */
- (id)initWithCoordinates:(NSDictionary*)coord
{

	margin_offset = 10.0;

	type = [coord objectForKey:@"type"];
	coordinates = [coord objectForKey:@"coordinates"];
	x_min = (CGFloat)[[[coord objectForKey:@"bbox"] objectAtIndex:0] doubleValue];
	x_max = (CGFloat)[[[coord objectForKey:@"bbox"] objectAtIndex:1] doubleValue];
	y_min = (CGFloat)[[[coord objectForKey:@"bbox"] objectAtIndex:2] doubleValue];
	y_max = (CGFloat)[[[coord objectForKey:@"bbox"] objectAtIndex:3] doubleValue];
	zoom_factor = 1.0;

	width = x_max - x_min;
	height = y_max - y_min;

	// make it a square due to aspect ratio
	if(width>height)
		height = width;
	else
		width = height;

	if ( self = [super initWithFrame:NSMakeRect(0,0,width+margin_offset*2,height+margin_offset*2)] )
	{
		;
	}
	return self;
}

- (NSPoint)normalizePoint:(NSPoint)aPoint
{

	aPoint.x-=x_min;
	aPoint.y-=y_min;
	aPoint.x+=margin_offset;
	aPoint.y+=margin_offset;

	return aPoint;
}

- (void)drawPoint:(NSPoint)aPoint
{
	NSBezierPath *circlePath = [NSBezierPath bezierPath];
	[circlePath appendBezierPathWithOvalInRect:NSMakeRect(aPoint.x-2,aPoint.y-2,4,4)];
	[[NSColor grayColor] setStroke];
	[[NSColor redColor] setFill];
	[circlePath stroke];
	[circlePath fill];
}

- (void)drawRect:(NSRect)dirtyRect
{

	if(!type || ![type length] || !coordinates || ![coordinates count]) return;

	NSBezierPath *path;
	NSColor *polyFillColor = [NSColor colorWithCalibratedRed:.5 green:.5 blue:0.5 alpha:0.05];
	BOOL isFirst = YES;

	NSPoint aPoint;

	path = [NSBezierPath bezierPathWithRect:[self bounds]];
	[path setLineWidth:0.1];
	[[NSColor whiteColor] set];
	[path fill];
	[[NSColor grayColor] set];
	[path stroke];

	path = [NSBezierPath bezierPath];
	[[NSColor blackColor] set];
	[path setLineWidth:1];

	if ([type hasSuffix:@"POINT"]) {
		for(NSString* coord in coordinates)
			[self drawPoint:[self normalizePoint:NSPointFromString(coord)]];
	}
	else if([type hasSuffix:@"LINESTRING"]) {

		for(NSArray* lines in coordinates) {
			path = [NSBezierPath bezierPath];
			isFirst = YES;
			for(NSString* coord in lines) {
				aPoint = [self normalizePoint:NSPointFromString(coord)];
				if(isFirst) {
					[path moveToPoint:aPoint];
					isFirst = NO;
				} else {
					[path lineToPoint:aPoint];
				}
				[self drawPoint:aPoint];
			}
			[[NSColor blackColor] setStroke];
			[path stroke];
		}
	}
	else if([type hasSuffix:@"POLYGON"]) {
		for(NSArray* polygons in coordinates) {
			isFirst = YES;
			for(NSString* coord in polygons) {
				aPoint = [self normalizePoint:NSPointFromString(coord)];
				if(isFirst) {
					[path moveToPoint:aPoint];
					isFirst = NO;
				} else {
					[path lineToPoint:aPoint];
				}
				[self drawPoint:aPoint];
			}
			[[NSColor blackColor] setStroke];
			[polyFillColor setFill];
			[path fill];
			[path stroke];
		}

	}
}

- (NSImage*)image
{

	[self drawRect:[self bounds]];

	NSImage *image = [[[NSImage alloc] initWithSize:[self bounds].size] autorelease];
	NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:[self bounds]] autorelease];
	[image addRepresentation:bitmap];
	return image;

}

/**
 * dealloc
 */
- (void)dealloc
{
	[super dealloc];
}

@end
