//
//  $Id$
//
//  SPNotLoaded.m
//  sequel-pro
//
//  Created by Rowan Beentje on 07/10/2009.
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

#import "SPNotLoaded.h"

static SPNotLoaded *notLoaded = nil;

@implementation SPNotLoaded

// Return the singleton object
+ (SPNotLoaded *) notLoaded
{
	@synchronized(self) {
		if (notLoaded == nil) {
			notLoaded = [[super allocWithZone:NULL] init];
		}
	}
	return notLoaded;
}

+ (id) allocWithZone:(NSZone *)zone
{
	@synchronized(self) {
		return [[self notLoaded] retain];
	}
}

- (id) init
{
	Class notLoadedClass = [self class];
	@synchronized(notLoadedClass) {
		if (notLoaded == nil) {
			if (self = [super init]) {
				notLoaded = self;
			}
		}
	}
	return notLoaded;
}

- (id) copyWithZone:(NSZone *)zone { return self; }

- (id) retain { return self; }

- (NSUInteger) retainCount { return NSUIntegerMax; }

- (void) release {}

- (id) autorelease { return self; }

@end


/**
 * This Category is intended to allow easy testing of all objects for SPNotLoaded.
 */
@implementation NSObject (SPNotLoadedTest)

- (BOOL) isSPNotLoaded
{
	static id SPNotLoadedForComparison;
	if (!SPNotLoadedForComparison) SPNotLoadedForComparison = [SPNotLoaded notLoaded];
    return (self == SPNotLoadedForComparison);
}

@end
