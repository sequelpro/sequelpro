//
//  SPDataAdditions.h
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on June 19, 2009.
//  Copyright (c) 2009 Hans-Jörg Bibiko. All rights reserved.
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

typedef NS_OPTIONS(NSUInteger, SPLineTerminator) {
	SPLineTerminatorAny = 0,
	SPLineTerminatorCR = 1,
	SPLineTerminatorLF = 2,
	SPLineTerminatorCRLF = 4,
};

@interface NSData (SPDataAdditions)

- (NSData *)sha1Hash;

- (NSData *)dataEncryptedWithPassword:(NSString *)password;
- (NSData *)dataEncryptedWithKey:(NSData *)aesKey IV:(NSData *)iv;
- (NSData *)dataDecryptedWithPassword:(NSString *)password;
- (NSData *)dataDecryptedWithKey:(NSData *)key;
+ (NSData *)dataWithHexString:(NSString *)hex;

- (NSData *)compress;
- (NSData *)decompress;

- (NSString *)dataToHexString;
- (NSString *)dataToFormattedHexString;

- (NSString *)stringRepresentationUsingEncoding:(NSStringEncoding)encoding;
- (NSString *)shortStringRepresentationUsingEncoding:(NSStringEncoding)encoding;

- (void)enumerateLinesBreakingAt:(SPLineTerminator)lbChars withBlock:(void (^)(NSRange line,BOOL *stop))block;

@end
