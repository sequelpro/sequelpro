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

@interface SPGeometryDataView (PrivateAPI)

- (NSPoint)_normalizePoint:(NSPoint)aPoint;
- (void)_drawPoint:(NSPoint)aPoint;

@end

#pragma mark -

@implementation SPGeometryDataView

/**
 * Initialize SPGeometryDataView object with default targetDimension
 *
 * @param coord Contains all necessary data to draw the geometry image
 *
 */
- (id)initWithCoordinates:(NSDictionary*)coord
{
	return [self initWithCoordinates:coord targetDimension:400.0];
}

/**
 * Initialize SPGeometryDataView object
 *
 * @param coord Contains all necessary data to draw the geometry image
 *
 * @param targetDimension Sets the maximum size (height or width) of the image
 */
- (id)initWithCoordinates:(NSDictionary*)coord targetDimension:(CGFloat)targetDimension
{

	margin_offset = 10.0;
	type = [coord objectForKey:@"type"];
	coordinates = [coord objectForKey:@"coordinates"];

	x_min = (CGFloat)[[[coord objectForKey:@"bbox"] objectAtIndex:0] doubleValue];
	x_max = (CGFloat)[[[coord objectForKey:@"bbox"] objectAtIndex:1] doubleValue];
	y_min = (CGFloat)[[[coord objectForKey:@"bbox"] objectAtIndex:2] doubleValue];
	y_max = (CGFloat)[[[coord objectForKey:@"bbox"] objectAtIndex:3] doubleValue];

	width = x_max - x_min;
	height = y_max - y_min;

	CGFloat maxDim = (width > height) ? width : height;
	if(maxDim != 0)
		zoom_factor = targetDimension/maxDim;
	else
		zoom_factor = 1.0;

	width*=zoom_factor;
	height*=zoom_factor;
	x_min*=zoom_factor;
	y_min*=zoom_factor;

	if ( self = [super initWithFrame:NSMakeRect(0,0,width+margin_offset*2,height+margin_offset*2)] )
	{
		;
	}

	lineColor         = [NSColor blackColor];
	borderLineColor   = [NSColor grayColor];
	backgroundColor   = [NSColor colorWithCalibratedRed:1 green:1 blue:1 alpha:0.96];
	pointFillColor    = [NSColor redColor];
	pointStrokeColor  = [NSColor grayColor];
	polygonFillColor1 = [NSColor colorWithCalibratedRed:0.0 green:1.0 blue:0.0 alpha:0.1];
	polygonFillColor2 = [NSColor colorWithCalibratedRed:0.0 green:1.0 blue:1.0 alpha:0.1];
	polygonFillColor3 = [NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:0.1];

	lineWidth = 1.0;

	return self;
}

- (void)drawRect:(NSRect)dirtyRect
{

	if(!type || ![type length] || !coordinates || ![coordinates count]) return;

	NSBezierPath *path;
	BOOL isFirst = YES;

	NSPoint aPoint;

	// Draw a rect as border
	path = [NSBezierPath bezierPathWithRect:[self bounds]];
	[path setLineWidth:0.1];
	[backgroundColor set];
	[path fill];
	[borderLineColor set];
	[path stroke];

	path = [NSBezierPath bezierPath];
	[lineColor set];
	[path setLineWidth:lineWidth];

	if ([type hasSuffix:@"POINT"]) {
		for(NSString* coord in coordinates)
			[self _drawPoint:[self _normalizePoint:NSPointFromString(coord)]];
	}
	else if([type hasSuffix:@"LINESTRING"]) {

		for(NSArray* lines in coordinates) {
			isFirst = YES;
			path = [NSBezierPath bezierPath];
			[path setLineWidth:lineWidth];
			for(NSString* coord in lines) {
				aPoint = [self _normalizePoint:NSPointFromString(coord)];
				if(isFirst) {
					[path moveToPoint:aPoint];
					isFirst = NO;
				} else {
					[path lineToPoint:aPoint];
				}
				[self _drawPoint:aPoint];
			}
			[lineColor setStroke];
			[path stroke];
		}
	}
	else if([type hasSuffix:@"POLYGON"]) {
		NSUInteger i = 0; // polygon fill color alternating
		for(NSArray* polygons in coordinates) {
			isFirst = YES;
			path = [NSBezierPath bezierPath];
			[path setLineWidth:lineWidth];
			for(NSString* coord in polygons) {
				aPoint = [self _normalizePoint:NSPointFromString(coord)];
				if(isFirst) {
					[path moveToPoint:aPoint];
					isFirst = NO;
				} else {
					[path lineToPoint:aPoint];
				}
				[self _drawPoint:aPoint];
			}
			[lineColor setStroke];
			switch(i) {
				case 0: [polygonFillColor1 setFill];
				break;
				case 1: [polygonFillColor2 setFill];
				break;
				case 2: [polygonFillColor3 setFill];
				break;
			}
			[path fill];
			[path stroke];
			i++;
			if(i>2) i=0;
		}
	}
	else if([type isEqualToString:@"GEOMETRYCOLLECTION"]) {

		// First array contains all points
		for(NSString* coord in [coordinates objectAtIndex:0]) {
			[self _drawPoint:[self _normalizePoint:NSPointFromString(coord)]];
		}

		// Second array contains all linestrings
		for(NSArray* lines in [coordinates objectAtIndex:1]) {
			isFirst = YES;
			path = [NSBezierPath bezierPath];
			[path setLineWidth:lineWidth];
			for(NSString* coord in lines) {
				aPoint = [self _normalizePoint:NSPointFromString(coord)];
				if(isFirst) {
					[path moveToPoint:aPoint];
					isFirst = NO;
				} else {
					[path lineToPoint:aPoint];
				}
				[self _drawPoint:aPoint];
			}
			[lineColor setStroke];
			[path stroke];
		}

		// Third array contains all polygons
		NSUInteger i = 0; // polygon fill color alternating
		for(NSArray* polygons in [coordinates objectAtIndex:2]) {
			isFirst = YES;
			path = [NSBezierPath bezierPath];
			[path setLineWidth:lineWidth];
			for(NSString* coord in polygons) {
				aPoint = [self _normalizePoint:NSPointFromString(coord)];
				if(isFirst) {
					[path moveToPoint:aPoint];
					isFirst = NO;
				} else {
					[path lineToPoint:aPoint];
				}
				[self _drawPoint:aPoint];
			}
			[lineColor setStroke];
			switch(i) {
				case 0: [polygonFillColor1 setFill];
				break;
				case 1: [polygonFillColor2 setFill];
				break;
				case 2: [polygonFillColor3 setFill];
				break;
			}
			[path fill];
			[path stroke];
			i++;
			if(i>2) i=0;
		}
	}
}

/**
 * Return the geometry as NSImage by using targetDimension
 */
- (NSImage*)thumbnailImage
{

	if(!type || ![type length] || !coordinates || ![coordinates count]) return nil;

	NSSize mySize = self.bounds.size;
	NSSize imgSize = NSMakeSize( mySize.width, mySize.height );
	NSRect myBounds = [self bounds];

	NSBitmapImageRep *bitmap = [self bitmapImageRepForCachingDisplayInRect:myBounds];
	[bitmap setSize:imgSize];
	[self cacheDisplayInRect:myBounds toBitmapImageRep:bitmap];

	NSImage* image = [[[NSImage alloc]initWithSize:imgSize] autorelease];
	[image addRepresentation:bitmap];
	return image;

}

/**
 * Return PDF data of the geometry image
 */
- (NSData*)pdfData
{
	if(!type || ![type length] || !coordinates || ![coordinates count]) return nil;

	NSSize mySize = self.bounds.size;
	NSRect myBounds = [self bounds];

	return [self dataWithPDFInsideRect:myBounds];

}

/**
 * dealloc
 */
- (void)dealloc
{
	[super dealloc];
}

@end

#pragma mark -
#pragma mark PrivateAPI

@implementation  SPGeometryDataView (PrivateAPI)

/**
 * Converts original NSPoint to target coordinates
 */
- (NSPoint)_normalizePoint:(NSPoint)aPoint
{
	aPoint.x*=zoom_factor;
	aPoint.y*=zoom_factor;
	aPoint.x-=x_min;
	aPoint.y-=y_min;
	aPoint.x+=margin_offset;
	aPoint.y+=margin_offset;
	return aPoint;
}

/**
 * Draw a point at aPoint representing the original coordinate
 */
- (void)_drawPoint:(NSPoint)aPoint
{
	NSBezierPath *circlePath = [NSBezierPath bezierPath];
	[circlePath appendBezierPathWithOvalInRect:NSMakeRect(aPoint.x-5,aPoint.y-5,10,10)];
	[pointStrokeColor setStroke];
	[pointFillColor setFill];
	[circlePath stroke];
	[circlePath fill];
}

@end
