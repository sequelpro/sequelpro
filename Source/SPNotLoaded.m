//
//  SPNotLoaded.m
//  sequel-pro
//
//  Created by Rowan Beentje on October 7, 2009.
//  Copyright (c) 2009 Rowan Beentje. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <https://github.com/sequelpro/sequelpro>

#import "SPNotLoaded.h"

static SPNotLoaded *notLoaded = nil;

@implementation SPNotLoaded

// Return the singleton object
+ (SPNotLoaded *)notLoaded
{
	@synchronized(self) {
		if (notLoaded == nil) {
			notLoaded = [[super allocWithZone:NULL] init];
		}
	}
	
	return notLoaded;
}

+ (id)allocWithZone:(NSZone *)zone
{
	@synchronized(self) {
		return [[self notLoaded] retain];
	}
	
	return nil;
}

- (id)init
{
	Class notLoadedClass = [self class];
	
	@synchronized(notLoadedClass) {
		if (notLoaded == nil) {
			if ((self = [super init])) {
				notLoaded = self;
			}
		}
	}
	
	return notLoaded;
}

- (id)copyWithZone:(NSZone *)zone { return self; }

- (id)retain { return self; }

- (NSUInteger)retainCount { return NSUIntegerMax; }

- (oneway void)release {}

- (id)autorelease { return self; }

@end


/**
 * This Category is intended to allow easy testing of all objects for SPNotLoaded.
 */
@implementation NSObject (SPNotLoadedTest)

- (BOOL)isSPNotLoaded
{
	static id SPNotLoadedForComparison;
	
	if (!SPNotLoadedForComparison) SPNotLoadedForComparison = [SPNotLoaded notLoaded];
    
	return (self == SPNotLoadedForComparison);
}

@end
