//
//  SPMutableArrayAdditionsTests.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on February 2, 2011.
//  Copyright (c) 2011 Stuart Connolly. All rights reserved.
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

#import "SPMutableArrayAdditions.h"

#import <XCTest/XCTest.h>

/**
 * @class SPMutableArrayAdditionsTest SPMutableArrayAdditionsTest.h
 *
 * @author Stuart Connolly http://stuconnolly.com/
 *
 * SPMutableArrayAdditions tests class.
 */
@interface SPMutableArrayAdditionsTests : XCTestCase

@end

@implementation SPMutableArrayAdditionsTests

/**
 * reverse test case.
 */
- (void)testReverse
{
	NSMutableArray *testArray = [NSMutableArray arrayWithObjects:@"1", @"2", @"3", @"4", @"5", nil];
	NSMutableArray *expectedArray = [NSMutableArray arrayWithObjects:@"5", @"4", @"3", @"2", @"1", nil];
	
	[testArray reverse];
	
	XCTAssertEqualObjects(testArray, expectedArray, @"The reversed array should look like: %@, but actually looks like: %@", expectedArray, testArray);
}

@end
