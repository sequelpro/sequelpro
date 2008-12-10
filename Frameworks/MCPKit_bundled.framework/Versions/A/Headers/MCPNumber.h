//
//  MCPNumber.h
//  NumberTest
//
//  Created by serge cohen (serge.cohen@m4x.org) on Sat Dec 08 2001.
//  Copyright (c) 2001 Serge Cohen.
//
//  This code is free software; you can redistribute it and/or modify it under
//  the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or any later version.
//
//  This code is distributed in the hope that it will be useful, but WITHOUT ANY
//  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
//  details.
//
//  For a copy of the GNU General Public License, visit <http://www.gnu.org/> or
//  write to the Free Software Foundation, Inc., 59 Temple Place--Suite 330,
//  Boston, MA 02111-1307, USA.
//
//  More info at <http://mysql-cocoa.sourceforge.net/>
//
// $Id: MCPNumber.h 334 2006-01-08 20:32:38Z serge $
// $Author: serge $

#import <Foundation/Foundation.h>


@interface MCPNumber : NSNumber {
   const char     *typeCode;
   NSNumber       *number;
}

- (id) initWithChar:(char) value;
- (id) initWithUnsignedChar:(unsigned char) value;
- (id) initWithShort:(short) value;
- (id) initWithUnsignedShort:(unsigned short) value;
- (id) initWithInt:(int) value;
- (id) initWithUnsignedInt:(unsigned int) value;
- (id) initWithLong:(long) value;
- (id) initWithUnsignedLong:(unsigned long) value;
- (id) initWithLongLong:(long long) value;
- (id) initWithUnsignedLongLong:(unsigned long long) value;
- (id) initWithFloat:(float) value;
- (id) initWithDouble:(double) value;
- (id) initWithBool:(BOOL) value;

+ (MCPNumber *) numberWithChar:(char) value;
+ (MCPNumber *) numberWithUnsignedChar:(unsigned char) value;
+ (MCPNumber *) numberWithShort:(short) value;
+ (MCPNumber *) numberWithUnsignedShort:(unsigned short) value;
+ (MCPNumber *) numberWithInt:(int) value;
+ (MCPNumber *) numberWithUnsignedInt:(unsigned int) value;
+ (MCPNumber *) numberWithLong:(long) value;
+ (MCPNumber *) numberWithUnsignedLong:(unsigned long) value;
+ (MCPNumber *) numberWithLongLong:(long long) value;
+ (MCPNumber *) numberWithUnsignedLongLong:(unsigned long long) value;
+ (MCPNumber *) numberWithFloat:(float) value;
+ (MCPNumber *) numberWithDouble:(double) value;
+ (MCPNumber *) numberWithBool:(BOOL) value;

- (void) dealloc;

/*" Most important : NSNumber primitive methods: "*/
- (const char *) objCType;
- (void) getValue:(void *) buffer;

//- (NSString *) descriptionWithLocale:(NSDictionary *) aLocale; // Not Primitive, but buggy...

- (char) charValue;
- (unsigned char) unsignedCharValue;
- (short) shortValue;
- (unsigned short) unsignedShortValue;
- (int) intValue;
- (unsigned int) unsignedIntValue;
- (long) longValue;
- (unsigned long) unsignedLongValue;
- (long long) longLongValue;
- (unsigned long long) unsignedLongLongValue;
- (float) floatValue;
- (double) doubleValue;
- (BOOL) boolValue;

@end
