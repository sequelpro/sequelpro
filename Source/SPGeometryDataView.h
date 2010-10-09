//
//  $Id$
//
//  SPGeometryDataView.m
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

#import <Cocoa/Cocoa.h>


@interface SPGeometryDataView : NSView
{
	
	NSWindow *geometryDataWindow;
	
	NSString *type;
	NSArray *coordinates;
	CGFloat x_min;
	CGFloat x_max;
	CGFloat y_min;
	CGFloat y_max;
	CGFloat width;
	CGFloat height;
	CGFloat zoom_factor;
	CGFloat margin_offset;
	CGFloat lineWidth;

	NSColor *lineColor;
	NSColor *borderLineColor;
	NSColor *backgroundColor;
	NSColor *pointFillColor;
	NSColor *pointStrokeColor;
	NSColor *polygonFillColor1;
	NSColor *polygonFillColor2;
	NSColor *polygonFillColor3;

}

- (id)initWithCoordinates:(NSDictionary*)coord targetDimension:(CGFloat)targetDimension;
- (id)initWithCoordinates:(NSDictionary*)coord;
- (void)setMax:(NSArray*)bbox;
- (NSPoint)normalizePoint:(NSPoint)aPoint;
- (NSImage*)thumbnailImage;
- (NSData*)pdfData;

@end
