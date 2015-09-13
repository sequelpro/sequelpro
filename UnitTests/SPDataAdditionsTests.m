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
#import <SenTestingKit/SenTestingKit.h>
#import "SPDataAdditions.h"
#import <errno.h>

@interface SPDataAdditionsTests : SenTestCase

- (void)testSha1Hash;

@end

@implementation SPDataAdditionsTests

- (void)testSha1Hash
{
	//simple straight forward case
	{
		NSString *input  = @"Hello World!";
		unsigned char bytes[] = {0x2e,0xf7,0xbd,0xe6,0x08,0xce,0x54,0x04,0xe9,0x7d,0x5f,0x04,0x2f,0x95,0xf8,0x9f,0x1c,0x23,0x28,0x71};
		
		STAssertTrue(memcmp([[[input dataUsingEncoding:NSUTF8StringEncoding] sha1Hash] bytes], bytes, 20) == 0, @"SHA1 simple hash from ASCII text");
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
		
		STAssertEqualObjects([[input sha1Hash] dataToHexString], result, @"SHA1 hash from full ASCII range");
	}
	// empty hash
	{
		NSData *input = [NSData data];
		NSString *result = @"DA39A3EE5E6B4B0D3255BFEF95601890AFD80709";
		
		STAssertEqualObjects([[input sha1Hash] dataToHexString], result, @"SHA1 hash from empty data");
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
		
		STAssertEqualObjects([[input sha1Hash] dataToHexString], result, @"SHA1 hash of UTF-8 string");
	}
	
}

@end
