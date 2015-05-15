//
//  SPOSInfo.h
//  sequel-pro
//
//  Created by Max Lohrmann on 14.02.15.
//  Copyright (c) 2015 Max Lohrmann. All rights reserved.
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

#import <Foundation/Foundation.h>

typedef struct {
	NSInteger major;
	NSInteger minor;
	NSInteger patch;
} SPOSVersion;

/**
 * Compare two OS versions similar to strcmp()
 * @param left One operand
 * @param right The other operand
 * @return A negative value if left < right, 0 is both are equal, a postive value if left > right
 */
int SPOSVersionCompare(SPOSVersion left, SPOSVersion right);

@interface SPOSInfo : NSObject
+ (SPOSVersion)osVersion;
+ (BOOL)isOSVersionAtLeastMajor:(NSInteger)major minor:(NSInteger)minor patch:(NSInteger)patch;
@end
