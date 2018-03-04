//
//  SPJSONFormatterTests.m
//  sequel-pro
//
//  Created by Max Lohrmann on 12.02.17.
//  Copyright (c) 2017 Max Lohrmann. All rights reserved.
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

#import "SPJSONFormatter.h"
#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

@interface SPJSONFormatterTests : XCTestCase

- (void)testFormatting;
- (void)testUnformatting;

@end

@implementation SPJSONFormatterTests

- (void)testFormatting
{

	//invalid input
	XCTAssertNil([SPJSONFormatter stringByFormattingString:nil],@"nil output on nil input");
	
	//empty string
	XCTAssertEqualObjects([SPJSONFormatter stringByFormattingString:@""], @"", @"empty string stays empty");
	
	//scalars on their own should not get changed
	{
		NSArray *scalars = @[@"true",@"false",@"null",@"123.45",@"1.4e-5",@"\"string\""];
		for (NSString *scalar in scalars) {
			XCTAssertEqualObjects([SPJSONFormatter stringByFormattingString:scalar], scalar, @"scalar only input stays as is");
		}
	}
	
	//simple test involving all types
	{
		NSString *unf = @"{\"key\": null, \"foo\": [true, false], \"ba\\\"r\": [{},{\"key2\": -1.98}]}";
		NSString *fmt = @"{\n\t\"key\": null,\n\t\"foo\": [\n\t\ttrue,\n\t\tfalse\n\t],\n\t\"ba\\\"r\": [\n\t\t{},\n\t\t{\n\t\t\t\"key2\": -1.98\n\t\t}\n\t]\n}";
		
		XCTAssertEqualObjects([SPJSONFormatter stringByFormattingString:unf], fmt, @"simple formatting test");
	}
	
	//other tests
	{
		NSArray *tests = @[
			@[@"{\"key\": \"v\0al\"}",@"{\n\t\"key\": \"v\0al\"\n}", @"NUL in input (invalid JSON)"],
			@[@"[\"\",\"\"\",\"", @"[\n\t\"\",\n\t\"\"\",\"", @"series of dquotes (invalid JSON)"],
			@[@"{[{\"ab\\u0090c\",",@"{\n\t[\n\t\t{\n\t\t\t\"ab\\u0090c\",\n",@"unterminated elements (invalid JSON)"],
			@[@"[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[null]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]",@"[\n\t[\n\t\t[\n\t\t\t[\n\t\t\t\t[\n\t\t\t\t\t[\n\t\t\t\t\t\t[\n\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tnull\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t]\n\t\t\t\t\t\t]\n\t\t\t\t\t]\n\t\t\t\t]\n\t\t\t]\n\t\t]\n\t]\n]",@"34 levels of indent"],
			@[@"{\"a\":\"bcd}",@"{\n\t\"a\": \"bcd}",@"unterminated string (invalid JSON)"],
			@[@"[1,\"ab\ncd\",3]",@"[\n\t1,\n\t\"ab\ncd\",\n\t3\n]",@"multiline string (invalid JSON)"],
			@[@"{}}},false]",@"{}\n}\n},\nfalse\n]",@"closing something that is not open (invalid JSON)"],
			@[@"[[123e4}}",@"[\n\t[\n\t\t123e4\n\t}\n}",@"unmatched braces (invalid JSON)"],
			@[@"[{]}",@"[\n\t{\n\t]\n}",@"unmatched braces 2 (invalid JSON)"],
			@[@"[  true , \n  false \t ] \t  \n",@"[\n\ttrue,\n\tfalse\n]",@"whitespace reformatting"],
			@[@"[1,2,]",@"[\n\t1,\n\t2,\n]",@"trailing comma (valid for some parsers)"],
			@[@"{}/{|}],-\"}[|[{}\\\"]:{~]\",,}{]\{|::[\\|\"],};]*}]",@"{}/{\n\t|\n}\n],\n-\"}[|[{}\\\"]:{~]\",\n,\n}{\n]{\n\t|: : [\n\t\t\\|\"],};]*}]",@"random garbage"],
		];
		
		for (NSArray *pair in tests) {
			XCTAssertEqualObjects([SPJSONFormatter stringByFormattingString:[pair objectAtIndex:0]], [pair objectAtIndex:1], @"%@", [pair objectAtIndex:2]);
		}
	}
}

- (void)testUnformatting
{
	//invalid input
	XCTAssertNil([SPJSONFormatter stringByUnformattingString:nil],@"nil output on nil input");
	
	//empty string
	XCTAssertEqualObjects([SPJSONFormatter stringByUnformattingString:@""], @"", @"empty string stays empty");
	
	//scalars on their own should not get changed
	{
		NSArray *scalars = @[@"true",@"false",@"null",@"123.45",@"1.4e-5",@"\"string\""];
		for (NSString *scalar in scalars) {
			XCTAssertEqualObjects([SPJSONFormatter stringByUnformattingString:scalar], scalar, @"scalar only input stays as is");
		}
	}
	
	//simple test involving all types
	{
		NSString *unf = @"{\"key\": null, \"foo\": [true, false], \"ba\\\"r\": [{}, {\"key2\": -1.98}]}";
		NSString *fmt = @"{\n\t\"key\": null,\n\t\"foo\": [\n\t\ttrue,\n\t\tfalse\n\t],\n\t\"ba\\\"r\": [\n\t\t{},\n\t\t{\n\t\t\t\"key2\": -1.98\n\t\t}\n\t]\n}";
		
		XCTAssertEqualObjects([SPJSONFormatter stringByUnformattingString:fmt], unf, @"simple unformatting test");
	}
	
	//other tests
	{
		NSArray *tests = @[
		   @[@"{\n\t\"key\": \"v\0al\"\n}", @"{\"key\": \"v\0al\"}", @"NUL in input (invalid JSON)"],
		   @[@"[\n\t\"\",\n\t\"\"\",\"", @"[\"\", \"\"\",\"", @"series of dquotes (invalid JSON)"],
		   @[@"{\n\t[\n\t\t{\n\t\t\t\"ab\\u0090c\",\n",@"{[{\"ab\\u0090c\", ",@"unterminated elements (invalid JSON)"],
		   @[@"[\n\t[\n\t\t[\n\t\t\t[\n\t\t\t\t[\n\t\t\t\t\t[\n\t\t\t\t\t\t[\n\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tnull\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t\t]\n\t\t\t\t\t\t\t]\n\t\t\t\t\t\t]\n\t\t\t\t\t]\n\t\t\t\t]\n\t\t\t]\n\t\t]\n\t]\n]", @"[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[null]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]",@"34 levels of indent"],
		   @[@"{\n\t\"a\": \"bcd}", @"{\"a\": \"bcd}",@"unterminated string (invalid JSON)"],
		   @[@"[\n\t1,\n\t\"ab\ncd\",\n\t3\n]",@"[1, \"ab\ncd\", 3]",@"multiline string (invalid JSON)"],
		   @[@"{}\n}\n},\nfalse\n]", @"{}}}, false]",@"closing something that is not open (invalid JSON)"],
		   @[@"[\n\t[\n\t\t123e4\n\t}\n}", @"[[123e4}}",@"unmatched braces (invalid JSON)"],
		   @[@"[\n\t{\n\t]\n}", @"[{]}",@"unmatched braces 2 (invalid JSON)"],
		   @[@"[  true , \n  false \t ] \t  \n",@"[true, false]",@"whitespace reformatting"],
		   @[@"[\n\t1,\n\t2,\n]", @"[1, 2, ]",@"trailing comma (valid for some parsers)"],
		   @[@"{}/{\n\t|\n}\n],\n-\"}[|[{}\\\"]:{~]\",\n,\n}{\n]{\n\t|: : [\n\t\t\\|\"],};]*}]", @"{}/{|}], -\"}[|[{}\\\"]:{~]\", , }{]\{|: : [\\|\"],};]*}]",@"random garbage"],
		];
		
		for (NSArray *pair in tests) {
			XCTAssertEqualObjects([SPJSONFormatter stringByUnformattingString:[pair objectAtIndex:0]], [pair objectAtIndex:1], @"%@", [pair objectAtIndex:2]);
		}
	}


}

@end
