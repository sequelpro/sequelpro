//
//  SPDataAdditionsTests.m
//  sequel-pro
//
//  Created by Max Lohrmann on 13.09.15.
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
#import "SPDataAdditions.h"
#import <errno.h>

@interface SPDataAdditionsTests : XCTestCase

- (void)testSha1Hash;
- (void)testDataEncryptedWithPassword;
- (void)testDataEncryptedWithKeyIV;
- (void)testDataDecryptedWithPassword;
- (void)testDataDecryptedWithKey;
- (void)testEnumerateLinesBreakingAt_withBlock;
- (void)testDataWithHexString;
- (void)testDataWithHexStringMySQL;

@end

@implementation SPDataAdditionsTests

- (void)testSha1Hash
{
	//simple straight forward case
	{
		NSString *input  = @"Hello World!";
		unsigned char bytes[] = {0x2e,0xf7,0xbd,0xe6,0x08,0xce,0x54,0x04,0xe9,0x7d,0x5f,0x04,0x2f,0x95,0xf8,0x9f,0x1c,0x23,0x28,0x71};
		
		XCTAssertTrue(memcmp([[[input dataUsingEncoding:NSUTF8StringEncoding] sha1Hash] bytes], bytes, 20) == 0, @"SHA1 simple hash from ASCII text");
	}
	// 16MB of all 8bit values
	{
		int bufSz = 16*1024*1024;
		unsigned char *buf = malloc(bufSz);
		for (int i = 0; i < bufSz; i++) {
			buf[i] = (i % 0xff);
		}
		NSData *input = [NSData dataWithBytesNoCopy:buf length:bufSz];
		NSString *result = @"25E05EB8E9E2B06036DF4026630FE01A19BF0F16";
		
		XCTAssertEqualObjects([[input sha1Hash] dataToHexString], result, @"SHA1 hash from full ASCII range");
	}
	// empty hash
	{
		NSData *input = [NSData data];
		NSString *result = @"DA39A3EE5E6B4B0D3255BFEF95601890AFD80709";
		
		XCTAssertEqualObjects([[input sha1Hash] dataToHexString], result, @"SHA1 hash from empty data");
	}
	// test with > 4GB data (other code path)
	// HFS+ does not support sparse files, so enable this one only if you have enough disk space.
	{/*
		// not everyone has 4GB RAM to spare and even then we probably won't be able to get
		// them en-block, so we'll just use a file and mmap() to simulate that.
		NSString *fileNameTpl = [NSTemporaryDirectory() stringByAppendingPathComponent:@"sha1test.XXXXXX"];
		STAssertNotNil(fileNameTpl, @"No temporary directory available!?");
		const char *cFileNameTpl = [fileNameTpl fileSystemRepresentation];
		char *cFileName = malloc(strlen(cFileNameTpl)+1);
		strcpy(cFileName, cFileNameTpl);
		if(mkstemp(cFileName) == -1)
			STFail(@"could not create temporary filename. errno=%d",errno);
		
		FILE *fp = fopen(cFileName, "w+");
		fputc(1, fp);
		fseek(fp, UINT32_MAX, SEEK_CUR);
		fputc(2, fp);
		fflush(fp);
		fclose(fp);
		
		NSString *fileName = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:cFileName length:strlen(cFileName)];
		
		NSData *input = [NSData dataWithContentsOfFile:fileName];
		NSString *result = @"A31A151AFC12B0D66A4DBE917CB55CEAA0AD639E";
		
		STAssertEqualObjects([[input sha1Hash] dataToHexString], result, @"SHA1 hash > 4gb data");
		
		unlink(cFileName);
		free(cFileName);
	*/}
	//utf8 string input
	{
		NSData *input = [@"føöbärbãz" dataUsingEncoding:NSUTF8StringEncoding];
		NSString *result = @"8A8B6142281950CBB9B01C9DF0DADB0BDAE2D0E1";
		
		XCTAssertEqualObjects([[input sha1Hash] dataToHexString], result, @"SHA1 hash of UTF-8 string");
	}
	
}

- (void)testDataEncryptedWithPassword
{
	//this method generates random data, so we can only test it by doing a full round-trip
	NSData *raw = [@"foo bar baz!" dataUsingEncoding:NSASCIIStringEncoding];
	NSString *password = @"123456";
	
	NSData *encrypted = [raw dataEncryptedWithPassword:password];
	//check that our encrypted data is not the plaintext data
	NSData *encCore = [encrypted subdataWithRange:NSMakeRange(16, [raw length])];
	XCTAssertFalse([encCore isEqualToData:raw], @"encrypted equal to plain text!");
	
	//decrypt again and verify
	NSData *decrypted = [encrypted dataDecryptedWithPassword:password];
	XCTAssertEqualObjects(decrypted, raw, @"decrypted data not equal to plaintext data!");
}

- (void)testDataEncryptedWithKeyIV
{
	NSData *iv  = [@"0123456789ABCDEF" dataUsingEncoding:NSASCIIStringEncoding];
	NSData *raw = [@"                " dataUsingEncoding:NSASCIIStringEncoding];
	//               ^^^^^^^^^^^^^^^^ spaces because their pattern is easily recognizable in hexdumps
	
	unsigned char keyRaw[] = {0xda,0x39,0xa3,0xee,0x5e,0x6b,0x4b,0x0d,0x32,0x55,0xbf,0xef,0x95,0x60,0x18,0x90,0xaf,0xd8,0x07,0x09}; // sha1("")
	NSData *key = [NSData dataWithBytes:keyRaw length:16];
	
	//argument tests:
	//key too short
	{
		@try {
			[raw dataEncryptedWithKey:[@"password" dataUsingEncoding:NSASCIIStringEncoding] IV:iv];
			XCTFail(@"Password should not be a valid key!");
		}
		@catch (NSException *exception) {
			//expected
		}
	}
	//iv too short
	{
		@try {
			[raw dataEncryptedWithKey:key IV:[NSData data]];
			XCTFail(@"Empty IV should throw exception!");
		}
		@catch (NSException *exception) {
			// expected
		}
	}
	//simple test: encrypting empty
	{
		NSData *enc = [[NSData data] dataEncryptedWithKey:key IV:iv];
		unsigned char expect[] = {
			0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41,
			0x42, 0x43, 0x44, 0x45, 0x46, 0x50, 0xc9, 0xca, 0x75, 0x14, 0xd3,
			0x6e, 0xec, 0x9e, 0xc6, 0x4c, 0x25, 0x02, 0x33, 0xdd, 0x86, 0x00,
			0x02, 0x5c, 0x2c, 0xf9, 0xa5, 0x22, 0x79, 0xa4, 0x14, 0x61, 0x90,
			0x1d, 0x9f, 0x0c, 0x7a
		}; // reference data generated with OpenSSL
		NSData *expData = [NSData dataWithBytesNoCopy:expect length:sizeof(expect) freeWhenDone:NO];
		XCTAssertEqualObjects(enc, expData, @"Encryption of empty data");
	}
	//simple encryption test
	{
		NSData *enc = [raw dataEncryptedWithKey:key IV:iv];
		unsigned char expect[] = {
			0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41,
			0x42, 0x43, 0x44, 0x45, 0x46, 0xd3, 0x58, 0x30, 0x95, 0x6d, 0x7f,
			0xf5, 0x1e, 0x18, 0xb0, 0xbc, 0x1f, 0xb3, 0xe4, 0x52, 0xb1, 0x75,
			0x4c, 0xc3, 0x52, 0xd0, 0x93, 0xad, 0xff, 0x36, 0x4a, 0xae, 0xbe,
			0x60, 0x32, 0xdd, 0x71, 0xef, 0xce, 0x2e, 0x8b, 0x09, 0xcb, 0x9a,
			0x44, 0x32, 0xb3, 0xda, 0x42, 0x58, 0x29, 0x78, 0xc3
		}; // reference data generated with OpenSSL
		NSData *expData = [NSData dataWithBytesNoCopy:expect length:sizeof(expect) freeWhenDone:NO];
		XCTAssertEqualObjects(enc, expData, @"Simple encryption test");
	}
}

- (void)testDataDecryptedWithPassword
{
	//see test above
	NSData *raw = [@"                " dataUsingEncoding:NSASCIIStringEncoding];
	unsigned char encrypted[] = {
		0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41,
		0x42, 0x43, 0x44, 0x45, 0x46, 0xd3, 0x58, 0x30, 0x95, 0x6d, 0x7f,
		0xf5, 0x1e, 0x18, 0xb0, 0xbc, 0x1f, 0xb3, 0xe4, 0x52, 0xb1, 0x75,
		0x4c, 0xc3, 0x52, 0xd0, 0x93, 0xad, 0xff, 0x36, 0x4a, 0xae, 0xbe,
		0x60, 0x32, 0xdd, 0x71, 0xef, 0xce, 0x2e, 0x8b, 0x09, 0xcb, 0x9a,
		0x44, 0x32, 0xb3, 0xda, 0x42, 0x58, 0x29, 0x78, 0xc3
	};
	NSData *encData = [NSData dataWithBytesNoCopy:encrypted length:sizeof(encrypted) freeWhenDone:NO];
	
	NSData *decrypted = [encData dataDecryptedWithPassword:@""];
	
	XCTAssertEqualObjects(decrypted, raw, @"Decrypt simple data encrypted with empty password");
}

- (void)testDataDecryptedWithKey
{
	NSData *raw = [@"                " dataUsingEncoding:NSASCIIStringEncoding];
	
	unsigned char keyRaw[] = {0xda,0x39,0xa3,0xee,0x5e,0x6b,0x4b,0x0d,0x32,0x55,0xbf,0xef,0x95,0x60,0x18,0x90,0xaf,0xd8,0x07,0x09}; // sha1("")
	NSData *key = [NSData dataWithBytes:keyRaw length:16];
	
	unsigned char encrypted[] = {
		0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41,
		0x42, 0x43, 0x44, 0x45, 0x46, 0xd3, 0x58, 0x30, 0x95, 0x6d, 0x7f,
		0xf5, 0x1e, 0x18, 0xb0, 0xbc, 0x1f, 0xb3, 0xe4, 0x52, 0xb1, 0x75,
		0x4c, 0xc3, 0x52, 0xd0, 0x93, 0xad, 0xff, 0x36, 0x4a, 0xae, 0xbe,
		0x60, 0x32, 0xdd, 0x71, 0xef, 0xce, 0x2e, 0x8b, 0x09, 0xcb, 0x9a,
		0x44, 0x32, 0xb3, 0xda, 0x42, 0x58, 0x29, 0x78, 0xc3
	};
	NSData *encData = [NSData dataWithBytesNoCopy:encrypted length:sizeof(encrypted) freeWhenDone:NO];
	
	// invalid key length
	{
		@try {
			[encData dataDecryptedWithKey:[NSData data]];
			XCTFail(@"Invalid key length!");
		}
		@catch (NSException *exception) {
			//expected
		}
	}
	// data too short for encryption
	{
		@try {
			[[@"Hello World!" dataUsingEncoding:NSASCIIStringEncoding] dataDecryptedWithKey:key];
			XCTFail(@"Invalid data length!");
		}
		@catch (NSException *exception) {
			//expected
		}
	}
	// wrong data with valid length
	{
		NSData *inp = [@"12345678901234567890123456789012" dataUsingEncoding:NSASCIIStringEncoding];
		XCTAssertNil([inp dataDecryptedWithKey:key], @"Trying to decrypt invalid data.");
	}
	// wrong data with invalid length
	{
		NSData *inp = [@"12345678901234567890123456789012345678901234567" dataUsingEncoding:NSASCIIStringEncoding];
		XCTAssertNil([inp dataDecryptedWithKey:key], @"Trying to decrypt data with invalid length.");
	}
	// simple decryption test
	{
		NSData *decrypted = [encData dataDecryptedWithKey:key];
		XCTAssertEqualObjects(decrypted, raw, @"Simple Decryption test");
	}
	// malicious message test
	{
		//this is an empty message with a length field set to UINT32_MAX
		unsigned char _encrypted[] = {
			0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41,
			0x42, 0x43, 0x44, 0x45, 0x46, 0x50, 0xc9, 0xca, 0x75, 0x14, 0xd3,
			0x6e, 0xec, 0x9e, 0xc6, 0x4c, 0x25, 0x02, 0x33, 0xdd, 0x86, 0x54,
			0xea, 0x1a, 0x0d, 0xe9, 0x88, 0xe3, 0xeb, 0xcb, 0xb7, 0x01, 0x52,
			0x42, 0x1c, 0xd8, 0xd5
		};
		NSData *_encData = [NSData dataWithBytesNoCopy:_encrypted length:sizeof(_encrypted) freeWhenDone:NO];
		
		@try {
			[_encData dataDecryptedWithKey:key];
			XCTFail(@"Malicious message with invalid data length");
		}
		@catch (NSException *exception) {
			//expected
		}
	}
}

- (void)testEnumerateLinesBreakingAt_withBlock
{
	//simple empty data
	{
		__block NSUInteger invocations = 0;
		NSData *data = [NSData data];
		[data enumerateLinesBreakingAt:SPLineTerminatorAny withBlock:^(NSRange line, BOOL *stop) {
			invocations++;
		}];
		XCTAssertTrue(invocations==0, @"Empty data never invokes block");
	}
	//simple unix file
	{
		const char inp[] = "Two\nLines\n";
		__block NSUInteger invocations = 0;
		NSData *data = [NSData dataWithBytes:inp length:strlen(inp)];
		[data enumerateLinesBreakingAt:SPLineTerminatorAny withBlock:^(NSRange line, BOOL *stop) {
			switch (invocations) {
				case 0:
					XCTAssertTrue(NSEqualRanges(line, NSMakeRange(0, 3)), @"range of first line");
					break;
				case 1:
					XCTAssertTrue(NSEqualRanges(line, NSMakeRange(4, 5)), @"range of second line");
					break;
			}
			invocations++;
		}];
		XCTAssertTrue(invocations==2, @"File with two lines, terminated with empty line");
	}
	//simple windows file without ending empty line
	{
		const char inp[] = "A\r\nWindows\r\nfile";
		__block NSUInteger invocations = 0;
		NSData *data = [NSData dataWithBytes:inp length:strlen(inp)];
		[data enumerateLinesBreakingAt:SPLineTerminatorAny withBlock:^(NSRange line, BOOL *stop) {
			switch (invocations) {
				case 0:
					XCTAssertTrue(NSEqualRanges(line, NSMakeRange(0, 1)), @"range of first line");
					break;
				case 1:
					XCTAssertTrue(NSEqualRanges(line, NSMakeRange(3, 7)), @"range of second line");
					break;
				case 2:
					XCTAssertTrue(NSEqualRanges(line, NSMakeRange(12, 4)), @"range of third line");
					break;
			}
			invocations++;
		}];
		XCTAssertTrue(invocations==3, @"File with three lines, CRLF, terminated with empty line");
	}
	//empty lines with all 3 endings
	{
		const char inp[] = "\n\r\n\r";
		__block NSUInteger invocations = 0;
		NSData *data = [NSData dataWithBytes:inp length:strlen(inp)];
		[data enumerateLinesBreakingAt:SPLineTerminatorAny withBlock:^(NSRange line, BOOL *stop) {
			switch (invocations) {
				case 0:
					XCTAssertTrue(NSEqualRanges(line, NSMakeRange(0, 0)), @"range of first line");
					break;
				case 1:
					XCTAssertTrue(NSEqualRanges(line, NSMakeRange(1, 0)), @"range of second line");
					break;
				case 2:
					XCTAssertTrue(NSEqualRanges(line, NSMakeRange(3, 0)), @"range of third line");
					break;
			}
			invocations++;
		}];
		XCTAssertTrue(invocations==3, @"LF, CRLF and CR mixed");
	}
	//looking for specific line breaks only
	{
		const char inp[] = "foo\nbar\r\nbaz\r";
		__block NSUInteger invocations = 0;
		NSData *data = [NSData dataWithBytes:inp length:strlen(inp)];
		[data enumerateLinesBreakingAt:SPLineTerminatorCRLF withBlock:^(NSRange line, BOOL *stop) {
			switch (invocations) {
				case 0:
					XCTAssertTrue(NSEqualRanges(line, NSMakeRange(0, 7)), @"range of first line");
					break;
				case 1:
					XCTAssertTrue(NSEqualRanges(line, NSMakeRange(9, 4)), @"range of second line");
					break;
			}
			invocations++;
		}];
		XCTAssertTrue(invocations==2, @"other line breaks when only CRLF is expected");
	}
	//stopping early
	{
		const char inp[] = "Two\nLines\n";
		__block NSUInteger invocations = 0;
		NSData *data = [NSData dataWithBytes:inp length:strlen(inp)];
		[data enumerateLinesBreakingAt:SPLineTerminatorAny withBlock:^(NSRange line, BOOL *stop) {
			invocations++;
			*stop = YES;
		}];
		XCTAssertTrue(invocations==1, @"File with two lines, stopped after first");
	}
}

- (void)testDataWithHexString
{
	//nil
	{
		XCTAssertNil([NSData dataWithHexString:nil], @"nil input");
	}
	//empty
	{
		XCTAssertTrue([[NSData dataWithHexString:@""] length] == 0, @"empty input");
	}
	//single byte 0
	{
		const char single[] = {0};
		XCTAssertEqualObjects([NSData dataWithHexString:@"0"], [NSData dataWithBytes:single length:1], @"single '0'" );
	}
	//empty, with 0x
	{
		XCTAssertEqualObjects([NSData dataWithHexString:@" 0x  "], [NSData data], @"empty input after trimming");
	}
	//one lower nibble
	{
		const char single[] = { 0xf };
		XCTAssertEqualObjects([NSData dataWithHexString:@"0xf"], [NSData dataWithBytes:single length:1], @"0x0F");
	}
	//full char, uppercase
	{
		const char single[] = { 0xcf };
		XCTAssertEqualObjects([NSData dataWithHexString:@"CF"], [NSData dataWithBytes:single length:1], @"0xCF");
	}
	//regular input
	{
		NSString *inp = @"0x de AD Be eF\t0102 0304";
		const char exp[] = {0xde,0xad,0xbe,0xef,0x01,0x02,0x03,0x04};
		XCTAssertEqualObjects([NSData dataWithHexString:inp], [NSData dataWithBytes:exp length:sizeof(exp)], @"regular input");
	}
	//invalid input
	{
		XCTAssertNil([NSData dataWithHexString:@"0xaG"], @"invalid char in input");
	}
}

- (void)testDataWithHexStringMySQL
{
	//empty
	{
		XCTAssertEqualObjects([NSData dataWithHexString:@"x''"], [NSData data], @"empty mysql hex literal");
	}
	//empty, whitespace around, capital x
	{
		XCTAssertEqualObjects([NSData dataWithHexString:@"  X''\t  "], [NSData data], @"empty mysql hex literal (2)");
	}
	//nonempty valid, case-insensitive
	{
		const char exp[] = {0xde,0xad,0xbe,0xef};
		XCTAssertEqualObjects([NSData dataWithHexString:@"X'deADBeeF'"], [NSData dataWithBytes:exp length:sizeof(exp)], @"regular input");
	}
	//bad: uneven
	{
		XCTAssertNil([NSData dataWithHexString:@"X'aFF'"],@"uneven length in mysql hex literal");
	}
	//bad: whitespace inside literal
	{
		XCTAssertNil([NSData dataWithHexString:@"x'0A ff'"], @"whitespace inside mysql hex literal");
	}
	//bad: non-whitespace after literal
	{
		XCTAssertNil([NSData dataWithHexString:@"X'1234'   ."], @"garbage at end");
	}
	//bad: non hex char in literal
	{
		XCTAssertNil([NSData dataWithHexString:@"x'01äß'"], @"non-hex char in literal");
	}
}

@end
