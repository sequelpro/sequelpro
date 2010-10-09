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

	CGFloat maxDim;
	CGFloat targetDim = 400.0;

	margin_offset = 10.0;

	type = [coord objectForKey:@"type"];
	coordinates = [coord objectForKey:@"coordinates"];

	x_min = (CGFloat)[[[coord objectForKey:@"bbox"] objectAtIndex:0] doubleValue];
	x_max = (CGFloat)[[[coord objectForKey:@"bbox"] objectAtIndex:1] doubleValue];
	y_min = (CGFloat)[[[coord objectForKey:@"bbox"] objectAtIndex:2] doubleValue];
	y_max = (CGFloat)[[[coord objectForKey:@"bbox"] objectAtIndex:3] doubleValue];

	width = x_max - x_min;
	height = y_max - y_min;

	maxDim = (width > height) ? width : height;
	if(maxDim != 0)
		zoom_factor = targetDim/maxDim;
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

	return self;
}

- (NSPoint)normalizePoint:(NSPoint)aPoint
{

	aPoint.x*=zoom_factor;
	aPoint.y*=zoom_factor;
	aPoint.x-=x_min;
	aPoint.y-=y_min;
	aPoint.x+=margin_offset;
	aPoint.y+=margin_offset;
	return aPoint;
}

- (void)drawPoint:(NSPoint)aPoint
{

	NSBezierPath *circlePath = [NSBezierPath bezierPath];
	[circlePath appendBezierPathWithOvalInRect:NSMakeRect(aPoint.x-5,aPoint.y-5,10,10)];
	[[NSColor grayColor] setStroke];
	[[NSColor redColor] setFill];
	[circlePath stroke];
	[circlePath fill];

}

- (void)drawRect:(NSRect)dirtyRect
{

	if(!type || ![type length] || !coordinates || ![coordinates count]) return;

	NSBezierPath *path;
	NSColor *polyFillColor1 = [NSColor colorWithCalibratedRed:0.0 green:1.0 blue:0.0 alpha:0.1];
	NSColor *polyFillColor2 = [NSColor colorWithCalibratedRed:0.0 green:1.0 blue:1.0 alpha:0.1];
	NSColor *polyFillColor3 = [NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:0.1];
	BOOL isFirst = YES;

	NSPoint aPoint;

	// Draw a rect as border
	path = [NSBezierPath bezierPathWithRect:[self bounds]];
	[path setLineWidth:0.1];
	[[NSColor colorWithCalibratedRed:1 green:1 blue:1 alpha:0.96] set];
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
		NSUInteger i = 0;
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
			switch(i) {
				case 0: [polyFillColor1 setFill];
				break;
				case 1: [polyFillColor2 setFill];
				break;
				case 2: [polyFillColor3 setFill];
				break;
			}
			[path fill];
			[path stroke];
			i++;
			if(i>2) i=0;
		}

	}
}

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
 * dealloc
 */
- (void)dealloc
{
	[super dealloc];
}

@end
