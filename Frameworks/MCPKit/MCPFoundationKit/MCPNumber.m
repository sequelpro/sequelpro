//
//  $Id$
//
//  MCPNumber.m
//  MCPKit
//
//  Created by Serge Cohen (serge.cohen@m4x.org) on 08/12/2002.
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

#import "MCPNumber.h"

@implementation MCPNumber

#pragma mark -
#pragma mark 'Creator' class methods

+ (MCPNumber *)numberWithChar:(char)value
{
	return [[[MCPNumber alloc] initWithChar:value] autorelease];
}

+ (MCPNumber *)numberWithUnsignedChar:(unsigned char)value
{
	return [[[MCPNumber alloc] initWithUnsignedChar:value] autorelease];
}

+ (MCPNumber *)numberWithShort:(short)value
{
	return [[[MCPNumber alloc] initWithShort:value] autorelease];
}

+ (MCPNumber *)numberWithUnsignedShort:(unsigned short)value
{
	return [[[MCPNumber alloc] initWithUnsignedShort:value] autorelease];
}

+ (MCPNumber *)numberWithInt:(int)value
{
	return [[[MCPNumber alloc] initWithInt:value] autorelease];
}

+ (MCPNumber *)numberWithUnsignedInt:(unsigned int)value
{
	return [[[MCPNumber alloc] initWithUnsignedInt:value] autorelease];
}

+ (MCPNumber *)numberWithLong:(long)value
{
	return [[[MCPNumber alloc] initWithLong:value] autorelease];
}

+ (MCPNumber *)numberWithUnsignedLong:(unsigned long)value
{
	return [[[MCPNumber alloc] initWithUnsignedLong:value] autorelease];
}

+ (MCPNumber *)numberWithLongLong:(long long)value
{
	return [[[MCPNumber alloc] initWithLongLong:value] autorelease];
}

+ (MCPNumber *)numberWithUnsignedLongLong:(unsigned long long)value
{
	return [[[MCPNumber alloc] initWithUnsignedLongLong:value] autorelease];
}

+ (MCPNumber *)numberWithFloat:(float)value
{
	return [[[MCPNumber alloc] initWithFloat:value] autorelease];
}

+ (MCPNumber *)numberWithDouble:(double)value
{
	return [[[MCPNumber alloc] initWithDouble:value] autorelease];
}

+ (MCPNumber *)numberWithBool:(BOOL)value
{
	return [[[MCPNumber alloc] initWithBool:value] autorelease];
}

#pragma mark -
#pragma mark Initialilzers

- (id)initWithChar:(char)value
{
   typeCode = @encode(char);
   number = [[NSNumber alloc] initWithChar:value];
	
   return self;
}

- (id)initWithUnsignedChar:(unsigned char)value
{
   typeCode = @encode(unsigned char);
   number = [[NSNumber alloc] initWithUnsignedChar:value];
	
   return self;
}

- (id)initWithShort:(short)value
{
   typeCode = @encode(short);
   number = [[NSNumber alloc] initWithShort:value];
	
   return self;
}

- (id)initWithUnsignedShort:(unsigned short)value
{
   typeCode = @encode(unsigned short);
   number = [[NSNumber alloc] initWithUnsignedShort:value];
	
   return self;
}

- (id)initWithInt:(int)value
{
   typeCode = @encode(int);
   number = [[NSNumber alloc] initWithInt:value];
	
   return self;
}

- (id)initWithUnsignedInt:(unsigned int)value
{
   typeCode = @encode(unsigned int);
   number = [[NSNumber alloc] initWithUnsignedInt:value];
	
   return self;
}

- (id)initWithLong:(long) value
{
   typeCode = @encode(long);
   number = [[NSNumber alloc] initWithLong:value];
	
   return self;
}

- (id)initWithUnsignedLong:(unsigned long)value
{
   typeCode = @encode(unsigned long);
   number = [[NSNumber alloc] initWithUnsignedLong:value];
	
   return self;
}

- (id)initWithLongLong:(long long)value
{
   typeCode = @encode(long long);
   number = [[NSNumber alloc] initWithLongLong:value];
	
   return self;
}

- (id)initWithUnsignedLongLong:(unsigned long long)value
{
   typeCode = @encode(unsigned long long);
   number = [[NSNumber alloc] initWithUnsignedLongLong:value];
	
   return self;
}

- (id)initWithFloat:(float)value
{
   typeCode = @encode(float);
   number = [[NSNumber alloc] initWithFloat:value];
	
   return self;
}

- (id)initWithDouble:(double)value
{
   typeCode = @encode(double);
   number = [[NSNumber alloc] initWithDouble:value];
	
   return self;
}

- (id)initWithBool:(BOOL)value
{
   typeCode = @encode(BOOL);
   number = [[NSNumber alloc] initWithBool:value];
	
   return self;
}

#pragma mark -
#pragma mark NSValue primitive methods

- (const char *)objCType
{
   return typeCode;
}

- (void)getValue:(void *)buffer
{
   [number getValue:buffer];
}

#pragma mark -
#pragma mark NSNumber primitive methods

/** 
 * Reparing the absence of primitive methodes in NSNumber
 */
- (char)charValue
{
   return [number charValue];
}

- (unsigned char)unsignedCharValue
{
   return [number unsignedCharValue];
}

- (short)shortValue
{
   return [number shortValue];
}

- (unsigned short)unsignedShortValue
{
   return [number unsignedShortValue];
}

- (int)intValue
{
   return [number intValue];
}

- (unsigned int)unsignedIntValue
{
   return [number unsignedIntValue];
}

- (long)longValue
{
   return [number longValue];
}

- (unsigned long)unsignedLongValue
{
   return [number unsignedLongValue];
}

- (long long)longLongValue
{
   return [number longLongValue];
}

- (unsigned long long)unsignedLongLongValue
{
   return [number unsignedLongLongValue];
}

- (float)floatValue
{
   return [number floatValue];
}

- (double)doubleValue
{
   return [number doubleValue];
}

- (BOOL)boolValue
{
   return [number boolValue];
}

#pragma mark -

- (void)dealloc
{
	[number release];
	
	[super dealloc];
}

@end
