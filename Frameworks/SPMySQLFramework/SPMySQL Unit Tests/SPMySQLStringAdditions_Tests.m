//
//  SPMySQLStringAdditions_Tests.m
//  SPMySQLFramework
//
//  Created by Max Lohrmann on 04.10.15.
//
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <SPMySQL/SPMySQL.h>

@interface SPMySQLStringAdditions_Tests : XCTestCase

- (void)test_mySQLBacktickQuotedString;
- (void)test_mySQLTickQuotedString;
- (void)test_stringForDataBytesLengthEncoding;

@end

@implementation SPMySQLStringAdditions_Tests

- (void)test_mySQLBacktickQuotedString
{
	XCTAssertEqualObjects([@"" mySQLBacktickQuotedString], @"``",@"empty string");
	
	XCTAssertEqualObjects([@"tbl1" mySQLBacktickQuotedString], @"`tbl1`", @"regular string");
	
	XCTAssertEqualObjects([@"tbl`1" mySQLBacktickQuotedString], @"`tbl``1`",@"string with control character");
	
	XCTAssertEqualObjects([@"tbl``" mySQLBacktickQuotedString], @"`tbl`````",@"string with escaped control character at end");
}

- (void)test_mySQLTickQuotedString
{
	XCTAssertEqualObjects([@"" mySQLTickQuotedString], @"''",@"empty string");
	
	XCTAssertEqualObjects([@"tbl1" mySQLTickQuotedString], @"'tbl1'", @"regular string");
	
	XCTAssertEqualObjects([@"tbl'1" mySQLTickQuotedString], @"'tbl''1'",@"string with control character");
	
	XCTAssertEqualObjects([@"tbl''" mySQLTickQuotedString], @"'tbl'''''",@"string with escaped control character at end");
}

- (void)test_stringForDataBytesLengthEncoding
{
	{
		const char chr = '\0';
		NSString *conv = [NSString stringForDataBytes:&chr length:0 encoding:NSISOLatin1StringEncoding];
		XCTAssertEqualObjects(conv, @"",@"empty string test");
	}
	{
		const char *cstr = "an ASCII C string";
		NSString *conv = [NSString stringForDataBytes:cstr length:strlen(cstr) encoding:NSASCIIStringEncoding];
		XCTAssertEqualObjects(conv, @"an ASCII C string", @"simple ASCII string test");
	}
	{
		// the euro sign is the tricky part
		// ISO-8859-1 (aka Latin1):              not supported, codepoint 0x80 is not in use
		// ISO-8859-1 + ISO/IEC 6429:            not supported, codepoint 0x80 is PAD control character
		// ISO-8859-15 (aka Latin9):             € is at 0xA4, codepoint 0x80 is PAD control character
		// Windows cp1252 (aka latin1 in mysql): € is at 0x80, codepoint 0xA4 is "¤"
		const char cstr[] = {'\xE4','-','\xDF','-','\x80','\0'};
		NSString *conv = [NSString stringForDataBytes:cstr length:strlen(cstr) encoding:NSWindowsCP1252StringEncoding];
		XCTAssertEqualObjects(conv, @"ä-ß-€",@"handling of cp1252 special characters");
		
		unsigned char latin9 = 0xA4;
		NSString *conv2 = [NSString stringForDataBytes:&latin9 length:1 encoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatin9)];
		XCTAssertEqualObjects(conv2, @"€",@"handling of iso-8859-15 special characters");
	}
	{
		const char *cstr = "エスキューエル";
		NSString *conv = [NSString stringForDataBytes:cstr length:strlen(cstr) encoding:NSUTF8StringEncoding];
		XCTAssertEqualObjects(conv, @"エスキューエル",@"handling of valid utf-8 string");
	}
	{
		// this is a test for a certain mysql issue:
		// mysql limits field names to 255 characters and will even cut multibyte chars in the middle,
		// if neccesary. This will create invalid characters which cause NSString
		// to fail and return nil on the whole string. Since we know that, we can
		// at least try to return something.
		char cstr[] = {'\xE3','\x82','\xA8','\xE3','\x82','\xB9','\xE3','\x82','\xAD','\xE3','\x83','\xA5','\xE3','\x83','\xBC','\xE3','\x82','\xA8','\xE3','\x83','\xAB','\0'}; // エスキューエル
		cstr[strlen(cstr)-2] = '\0'; //simulate cutting off the string
		NSString *conv = [NSString stringForDataBytes:cstr length:strlen(cstr) encoding:NSUTF8StringEncoding];
		XCTAssertNotNil(conv, @"handling of invalid utf8 sequences");
	}
}

@end
