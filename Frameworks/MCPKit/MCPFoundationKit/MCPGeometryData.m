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


@implementation MCPGeometryData

- (id)copyWithZone:(NSZone *)zone { return [self retain]; }

- (id)init
{
	if ((self = [super init])) {
		geoBuffer = nil;
		bufferLength = 0;
	}
	return self;
}

- (id)initWithData:(NSData*)geoData
{
	if ((self = [self init])) {
		bufferLength = [geoData length];
		geoBuffer = malloc(bufferLength);
		memcpy(geoBuffer, [geoData bytes], bufferLength);
	}
	return self;
}


+ (id)dataWithData:(NSData*)geoData
{
	return [[[MCPGeometryData alloc] initWithData:geoData] autorelease];
}

- (NSString*)description
{
	return [[NSData dataWithBytes:geoBuffer length:bufferLength] description];
}

- (NSUInteger)length
{
	return bufferLength;
}

- (void)dealloc
{
	if(geoBuffer && bufferLength) free(geoBuffer);
	[super dealloc];
}

@end
