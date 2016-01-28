//
//  DataConversion_Tests.m
//  SPMySQLFramework
//
//  Created by Max Lohrmann on 01.10.15.
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

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

// this function is inaccessible outside of unit tests
extern NSString * _bitStringWithBytes(const char *bytes, NSUInteger length, NSUInteger padLength);

@interface DataConversion_Tests : XCTestCase

- (void)test_bitStringWithBytes;

@end

@implementation DataConversion_Tests

- (void)test_bitStringWithBytes
{
	// BIT(1)
	{
		const char y = '\1';
		const char n = '\0';
		XCTAssertEqualObjects(_bitStringWithBytes(&y,sizeof(y),1), @"1");
		XCTAssertEqualObjects(_bitStringWithBytes(&n,sizeof(n),1), @"0");
	}
	// BIT(3)
	{
		const char input[] = {5};
		NSUInteger bitSize = 3;
		NSString *res = _bitStringWithBytes(input,sizeof(input),bitSize);
		XCTAssertEqualObjects(res, @"101");
	}
	// BIT(16)
	{
		const char input[] = {0xcc,0xf0};
		NSUInteger bitSize = 16;
		NSString *res = _bitStringWithBytes(input,sizeof(input),bitSize);
		XCTAssertEqualObjects(res, @"1100110011110000");
	}
	// BIT(20)
	{
		const char input[] = {0x0f,0xcc,0xf0};
		NSUInteger bitSize = 20;
		NSString *res = _bitStringWithBytes(input,sizeof(input),bitSize);
		XCTAssertEqualObjects(res, @"11111100110011110000");
	}
}

@end
