//
//  SPDataAdditions.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on June 19, 2009.
//  Copyright (c) 2009 Hans-Jörg Bibiko. All rights reserved.
//
//  dataEncryptedWithPassword and dataDecryptedWithPassword:
//  License: FREEWARE http://aquaticmac.com/cocoa.php
//  Copyright (c) 2005 Lucas Newman. All rights reserved.
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

#import "SPDataAdditions.h"

#include <zlib.h>
#include <CommonCrypto/CommonCrypto.h>
#include <stdlib.h>
#import "SPFunctions.h"

/** Limit an NSUInteger to unsigned 32 bit max.
 * @return Whatever is smaller: UINT32_MAX or i
 *
 * This is pretty much a NOOP on 32 bit platforms.
 */
uint32_t LimitUInt32(NSUInteger i);

#pragma mark -

@implementation NSData (SPDataAdditions)

- (NSData *)sha1Hash
{
	unsigned char digest[CC_SHA1_DIGEST_LENGTH];
	
	//let's do it as a one step operation, if it fits
	if([self length] <= UINT32_MAX) {
		CC_SHA1([self bytes], (uint32_t)[self length], digest);
	}
	// or multi-step if length > 32 bit
	else {
		CC_SHA1_CTX ctx;
		CC_SHA1_Init(&ctx);
		
		NSUInteger offset = 0;
		uint32_t len;
		while((len = LimitUInt32([self length]-offset)) > 0) {
			CC_SHA1_Update(&ctx, ([self bytes]+offset), len);
			offset += len;
		}
		
		CC_SHA1_Final(digest, &ctx);
	}
	
	return [NSData dataWithBytes:digest length:CC_SHA1_DIGEST_LENGTH];
}

- (NSData *)dataEncryptedWithPassword:(NSString *)password
{
	// Create a random 128-bit initialization vector
	// IV is block "-1" of plaintext data, therefore it is blockSize long
	unsigned char iv[kCCBlockSizeAES128];
	if(SPBetterRandomBytes(iv,sizeof(iv)) != 0)
		@throw [NSException exceptionWithName:NSInternalInconsistencyException
									   reason:@"Getting random data bytes failed!"
									 userInfo:@{@"errno":@(errno)}];

	NSData *ivData = [NSData dataWithBytes:iv length:sizeof(iv)];
	
	// Create the key from first 128-bits of the 160-bit password hash
	NSData *passwordDigest = [[[password dataUsingEncoding:NSUTF8StringEncoding] sha1Hash] subdataWithRange:NSMakeRange(0, kCCKeySizeAES128)];
	
	return [self dataEncryptedWithKey:passwordDigest IV:ivData];
}

/*
 * ABNF for the returned data:
 *   OCTET     = <any 8-bit sequence of data>
 *   ENCRYPTED = IV AES
 *   IV        = 16OCTET                  ; 16 random bytes
 *   AES       = <AES_128_CBC(PADDED)>
 *   PADDED    = PLAINTEXT 12*28OCTET LEN ; 13-28 bytes padding (value irrelevant)
 *   PLAINTEXT = *OCTET                   ; the raw data
 *   LEN       = 4OCTET                   ; big endian length of plaintext
 *
 * Examples for padding:
 *   Data len  padding  len   = total
 *   --------- -------- ----- --------
 *   0         28       4     32
 *   1         27       4     32
 *   ...
 *   15        13       4     32
 *   16        28       4     48
 *   17        27       4     48
 *   ...
 *
 *   Note that total has to be a multiple of 16 for AES 128.
 *   Our padding scheme also requires 4 bytes of storage for len.
 *   This is were the 32 comes from: Without that 15 data bytes would produce
 *   only 1 padding byte, which is not enough to store the 4 byte len.
 */
- (NSData *)dataEncryptedWithKey:(NSData *)aesKey IV:(NSData *)iv
{
	if([self length] > UINT32_MAX)
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Length of NSData exceeds 32 Bit, not supported!" userInfo:nil];
	
	if([iv length] != kCCBlockSizeAES128)
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Length of ivData must be == kCCBlockSizeAES128!" userInfo:nil];

	if([aesKey length] != kCCKeySizeAES128)
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Key length invalid. Must be kCCKeySizeAES128 bytes!" userInfo:nil];
		
	// Calculate the 16-byte AES block padding
	uint32_t dataLength = (uint32_t)[self length];
	NSInteger paddedLength = dataLength + (2*kCCBlockSizeAES128 - (dataLength % kCCBlockSizeAES128));
	NSInteger totalLength = paddedLength + kCCBlockSizeAES128; // Data plus IV
	
	// Allocate enough space for the IV + ciphertext
	unsigned char *encryptedBytes = calloc(1, totalLength);
	// The first block of the ciphertext buffer is the IV
	memcpy(encryptedBytes, [iv bytes], kCCBlockSizeAES128);

	unsigned char *paddedBytes = encryptedBytes + kCCBlockSizeAES128;
	memcpy(paddedBytes, [self bytes], dataLength);

	// The last 32-bit chunk is the size of the plaintext, which is encrypted with the plaintext
	uint32_t bigIntDataLength = NSSwapHostIntToBig(dataLength);
	unsigned char *lenPtr = paddedBytes + (paddedLength - 4);
	memcpy(lenPtr, &bigIntDataLength, 4);

	size_t bytesWritten;
	CCCryptorStatus res = CCCrypt(
			kCCEncrypt,         // operation mode
			kCCAlgorithmAES128, // algorithm
			0,                  // options. We use our own padding algorithm and CBC is the default
			[aesKey bytes],     // key bytes
			kCCKeySizeAES128,   // key length
			[iv bytes],         // iv bytes (length == block size)
			paddedBytes,        // raw data
			paddedLength,       // length of raw data
			paddedBytes,        // output buffer. overwriting input is OK
			paddedLength,       // output buffer size
			&bytesWritten       // number of bytes written. not relevant here, but 10.6 fails if omitted
	);
	
	if(res != kCCSuccess)
		@throw [NSException exceptionWithName:SPCommonCryptoExceptionName
									   reason:[NSString stringWithFormat:@"CCCrypt() failed! (CCCryptorStatus=%d)",res]
									 userInfo:@{@"cryptorStatus":@(res)}];
	
	// CVE-2016-4711: the return code of CCCrypt() is not always reliable, better check it again
	if(memcmp(lenPtr, &bigIntDataLength, 4) == 0)
		@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Encrypted data is same as plaintext data!" userInfo:nil];
	
	return [NSData dataWithBytesNoCopy:encryptedBytes length:totalLength];
}

- (NSData *)dataDecryptedWithPassword:(NSString *)password
{
	// Create the key from the password hash
	NSData *passwordDigest = [[[password dataUsingEncoding:NSUTF8StringEncoding] sha1Hash] subdataWithRange:NSMakeRange(0, kCCKeySizeAES128)];
	
	return [self dataDecryptedWithKey:passwordDigest];

}

- (NSData *)dataDecryptedWithKey:(NSData *)aesKey
{
	if([aesKey length] != kCCKeySizeAES128)
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Key length invalid. Must be kCCKeySizeAES128 bytes!" userInfo:nil];
	
	if([self length] < (2*kCCBlockSizeAES128) || [self length] > UINT32_MAX)
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Length of encrypted NSData must be in range 32 to 2^32!" userInfo:nil];

	// Total length = encrypted length + IV
	NSUInteger totalLength = [self length];
	NSUInteger encryptedLength = totalLength - kCCBlockSizeAES128; // >=0 ensured above

	// Take the IV from the first 128-bit block
	unsigned char iv[kCCBlockSizeAES128];
	memcpy(iv, [self bytes], kCCBlockSizeAES128);

	// Decrypt the data
	unsigned char *decryptedBytes = calloc(1,encryptedLength);
	
	size_t bytesRead;
	CCCryptorStatus res = CCCrypt(
			kCCDecrypt,                          // operation mode
			kCCAlgorithmAES128,                  // algorithm
			0,                                   // options. We use our own padding algorithm and CBC is the default
			[aesKey bytes],                      // key bytes
			kCCKeySizeAES128,                    // key length
			iv,                                  // iv bytes (length == block size)
			([self bytes] + kCCBlockSizeAES128), // raw data
			encryptedLength,                     // length of raw data
			decryptedBytes,                      // output buffer. overwriting input is OK
			encryptedLength,                     // output buffer size
			&bytesRead                           // number of bytes decrypted. not relevant here, but 10.6 fails if omitted
	);
	
	if(res != kCCSuccess) {
		@throw [NSException exceptionWithName:SPCommonCryptoExceptionName
									   reason:[NSString stringWithFormat:@"CCCrypt() failed! (CCCryptorStatus=%d)",res]
									 userInfo:@{@"cryptorStatus":@(res)}];
	}

	// If decryption was successful, these blocks will be zeroed
	if ( *((UInt32*)decryptedBytes + ((encryptedLength / 4) - 4)) ||
		 *((UInt32*)decryptedBytes + ((encryptedLength / 4) - 3)) ||
		 *((UInt32*)decryptedBytes + ((encryptedLength / 4) - 2)) )
	{
		free(decryptedBytes);
		return nil;
	}

	// Get the size of the data from the last 32-bit chunk
	uint32_t bigIntDataLength = *((UInt32*)decryptedBytes + ((encryptedLength / sizeof(UInt32)) - 1));
	uint32_t dataLength = NSSwapBigIntToHost(bigIntDataLength);
	
	if(dataLength >= (encryptedLength-sizeof(UInt32))) { //this way dataLength can still reach into padding, but we own that memory anyway.
		@throw [NSException exceptionWithName:NSInternalInconsistencyException
									   reason:[NSString stringWithFormat:@"dataLength=%u exceeds encryptedLength=%lu! Either the message is incomplete, decrypting resulted in invalid data, or this is a malicious message!",dataLength,encryptedLength]
									 userInfo:nil];
	}

	return [NSData dataWithBytesNoCopy:decryptedBytes length:dataLength];
}

- (NSData *)decompress
{
	if ([self length] == 0) return self;

	NSUInteger full_length = [self length];
	NSUInteger half_length = [self length] / 2;

	NSMutableData *unzipData = [NSMutableData dataWithLength: full_length + half_length];
	BOOL done = NO;
	NSInteger status;

	z_stream zlibStream;
	zlibStream.next_in = (Bytef *)[self bytes];
	zlibStream.avail_in = (uInt)[self length];
	zlibStream.total_out = 0;
	zlibStream.zalloc = Z_NULL;
	zlibStream.zfree = Z_NULL;

	if(inflateInit(&zlibStream) != Z_OK) return nil;

	while(!done)
	{
		if (zlibStream.total_out >= [unzipData length])
			[unzipData increaseLengthBy: half_length];
		zlibStream.next_out = [unzipData mutableBytes] + zlibStream.total_out;
		zlibStream.avail_out = (uInt)([unzipData length] - zlibStream.total_out);

		status = inflate (&zlibStream, Z_SYNC_FLUSH);
		if (status == Z_STREAM_END) done = YES;
		else if (status != Z_OK) break;
	}
	if(inflateEnd (&zlibStream) != Z_OK)
		return nil;

	if(done) {
		[unzipData setLength: zlibStream.total_out];
		return [NSData dataWithData: unzipData];
	}
	else
		return nil;
}

- (NSData *)compress
{
	if ([self length] == 0) return self;

	z_stream zlibStream;

	zlibStream.zalloc = Z_NULL;
	zlibStream.zfree = Z_NULL;
	zlibStream.opaque = Z_NULL;
	zlibStream.total_out = 0;
	zlibStream.next_in=(Bytef *)[self bytes];
	zlibStream.avail_in = (uInt)[self length];

	if (deflateInit(&zlibStream, Z_DEFAULT_COMPRESSION) != Z_OK) return nil;

	NSMutableData *zipData = [NSMutableData dataWithLength:16384];

	do {
		if (zlibStream.total_out >= [zipData length])
			[zipData increaseLengthBy: 16384];

		zlibStream.next_out = [zipData mutableBytes] + zlibStream.total_out;
		zlibStream.avail_out = (uInt)([zipData length] - zlibStream.total_out);

		deflate(&zlibStream, Z_FINISH);

	}
	while(zlibStream.avail_out == 0);

	deflateEnd(&zlibStream);

	[zipData setLength: zlibStream.total_out];

	return [NSData dataWithData: zipData];
}

/**
 * Returns the hex representation of the given data.
 */
- (NSString *)dataToHexString
{
	NSUInteger i;
	const unsigned char *bytes = (const unsigned char *)[self bytes];
	NSUInteger dataLength = [self length];
	NSMutableString *hexString = [NSMutableString string];

	for (i = 0; i < dataLength; i++)
	{
		[hexString appendFormat:@"%02X", bytes[i]];
	}

	return hexString;
}

/**
 * Returns the integer value for a single hex-encoded nibble or -1 for invalid values.
 * Supported characters: 0-9,a-f,A-F
 * 
 * Note: You usually would call this method like ((hexchar2nibble(highByte) << 4) + hexchar2nibble(lowByte)) to decode a single hex-encoded byte.
 */
static int hexchar2nibble(char c)
{
	if (c >= '0' && c <= '9') return c - '0';
	if (c >= 'a' && c <= 'f') return c - 'a' + 10;
	if (c >= 'A' && c <= 'F') return c - 'A' + 10;
	return -1;
}

/**
 * Decodes a sequence of hex digits to raw byte values.
 * This function is very strict about the allowed inputs and must only be used for validated inputs!
 *
 * - If numRawBytes != 0 and inBuffer == NULL or outBuffer == NULL, this will crash
 * - The hex sequence must ONLY contain chars 0-9,a-f,A-F or the result will be undefined
 * - The sequence must be padded to have an even length. numRawBytes is the number of bytes AFTER decoding, so inBuffer must be exactly 2x as large
 * - inBuffer and outBuffer may be the same pointer
 */
static void decodeValidHexSequence(const char *inBuffer,uint8_t *outBuffer, NSUInteger numRawBytes)
{
	NSUInteger outIndex = 0;
	NSUInteger srcIndex = 0;
	while (outIndex < numRawBytes) {
		uint8_t v = (hexchar2nibble(inBuffer[srcIndex]) << 4) + hexchar2nibble(inBuffer[srcIndex+1]);
		outBuffer[outIndex++] = v;
		srcIndex += 2;
	}
}

/**
 * Interpret a string of hex digits in 'hex' as hex data, and return
 * an NSData representation of the data.  Spaces are permitted within
 * the string and an initial '0x' will be ignored. If bad input
 * is detected, nil is returned.
 *
 * Alternatively the MySQL-style X'val' syntax is also supported, 
 * with the same restrictions as in MySQL:
 * - val must always be an even number of characters
 * - val cannot contain whitespace (whitespace before/after is ok)
 * - The leading x is case-INsensitive
 */
+ (NSData *)dataWithHexString:(NSString *)hex
{
	if(!hex) return nil; // no string
	const char *sourceBytes = [hex UTF8String];
	
	size_t length = strlen(sourceBytes); // keep in mind that [hex length] is the number of Unicode characters, not the number of bytes
	if (length < 1) return [NSData data];	// empty string

	NSUInteger srcIndex = 0;
	NSData *data = nil;
	NSUInteger nbytes;
	
	//skip leading whitespace (in order to properly check for leading "0x")
	while(srcIndex < length && (sourceBytes[srcIndex] == ' ' || sourceBytes[srcIndex] == '\t')) srcIndex++;

	// bypass initial 0x
	if(srcIndex+1 < length && sourceBytes[srcIndex] == '0' && sourceBytes[srcIndex+1] == 'x' ) {
		srcIndex += 2;
	}
	//check for mysql syntax
	else if(srcIndex+2 < length && (sourceBytes[srcIndex] == 'x' || sourceBytes[srcIndex] == 'X') && sourceBytes[srcIndex+1] == '\'') {
		srcIndex += 2;
		//look for the terminating quote
		NSUInteger startIndex = srcIndex;
		NSUInteger endIndex = startIndex; //startIndex points to the first character inside the quotes, which may already be the terminating quote
		while(endIndex < length) {
			char c = sourceBytes[endIndex];
			//if we've hit the terminator, verify that only whitespace follows and stop reading
			if(c == '\'') {
				NSUInteger afterIndex = endIndex+1;
				while (afterIndex < length) {
					c = sourceBytes[afterIndex++];
					if(c != ' ' && c != '\t') return nil;
				}
				break;
			}
			endIndex++;
			// Check for non-hex characters
			if (hexchar2nibble(c) < 0) return nil;
		}
		// Check for unterminated sequence and uneven number of bytes
		NSUInteger n = endIndex - startIndex;
		if(endIndex == length || ((n % 2) != 0)) return nil;
		// shortcut
		if(n == 0) return [NSData data];
		//looks good, create the output buffer and decode
		nbytes = n / 2;
		unsigned char *outBuf = malloc(nbytes);
		decodeValidHexSequence(&sourceBytes[startIndex], outBuf, nbytes);
		return [NSData dataWithBytesNoCopy:outBuf length:nbytes freeWhenDone:YES];
	}
	
	// Copy input while removing spaces and tabs.
	char *trimmedFull = (char *)malloc(length + 1);
	char *trimmed = (trimmedFull + 1); //we'll use the first byte in case we have to fill in a leading '0'
	NSUInteger trimIndex = 0;
	NSUInteger n = 0; // n = # of hex digits
	while(srcIndex < length) {
		char c = sourceBytes[srcIndex++];
		if(c == ' ' || c == '\t') continue;
		trimmed[trimIndex++] = c;
		if(!c) break;
		n++;
		// Check for non-hex characters
		if (hexchar2nibble(c) < 0) goto fail_cleanup;
	}
	//shortcut
	if(n == 0) {
		data = [NSData data];
		goto fail_cleanup;
	}

	BOOL isEven = ((n % 2) == 0);
	nbytes = !isEven ? (n + 1) / 2 : n / 2; //adjust for cases where "0aff" is written as "aff" (e.g.)
	if(!isEven) {
		trimmed--;
		trimmed[0] = '0';
	}
	
	//we'll just decode the data in-place since the raw values have to be shorter by definition, anyway
	decodeValidHexSequence(trimmed, (uint8_t *)trimmedFull, nbytes);
	return [NSData dataWithBytesNoCopy:trimmedFull length:nbytes freeWhenDone:YES];
	
fail_cleanup:
	free(trimmedFull);
	return data;
}

/**
 * Returns the hex representation of the given data.
 */
- (NSString *)dataToFormattedHexString
{
	NSUInteger i, j;
	NSUInteger totalLength = [self length];
	NSUInteger bytesPerLine = 16;
	NSMutableString *retVal = [NSMutableString string];

	// get the length of the longest location
	NSUInteger longest = [(NSString *)[NSString stringWithFormat:@"%lX", (unsigned long)(totalLength - ( totalLength % bytesPerLine ))] length];

	for ( i = 0; i < totalLength; i += bytesPerLine ) {

		NSMutableString *hex = [[NSMutableString alloc] initWithCapacity:(3 * bytesPerLine - 1)];
		NSMutableString *location = [[NSMutableString alloc] initWithCapacity:(longest + 2)];

		unsigned char *buffer;
		NSUInteger buffLength = bytesPerLine;

		// add hex value of location
		[location appendFormat:@"%llX", (unsigned long long)i];

		// pad it
		while( longest > [location length] ) {
			[location insertString:@"0" atIndex:0];
		}

		// get the chars from the NSData obj
		if ( i + buffLength >= totalLength ) {
			buffLength = totalLength - i;
		}

		buffer = (unsigned char*) calloc(buffLength + 1, sizeof(unsigned char));

		[self getBytes:buffer range:NSMakeRange(i, buffLength)];

		// build the hex string
		for ( j = 0; j < buffLength; j++ ) {

			[hex appendFormat:@"%02X ", *(buffer + j)];

			// Replace non-displayed bytes by '.'
			// non-displayed bytes are all bytes whose hex code is less than 0x20
			if(*(buffer + j) < ' ') *(buffer + j) = '.';

		}
		// Create a NULL-terminated buffer for [NSString stringWithFormat:@"%s"]
		*(buffer + j) = '\0';

		// add padding to missing hex values.
		for ( j = 0; j < bytesPerLine - buffLength; j++ ) {
			[hex appendString:@"   "];
		}

		// build line
		[retVal appendFormat:@"%@  %@ %s\n", location, hex, buffer];

		// clean up
		[hex release];
		[location release];
		free( buffer );
	}

	return retVal;
}

/**
 * Converts data instances to their string representation.
 */
- (NSString *)stringRepresentationUsingEncoding:(NSStringEncoding)encoding
{	
	NSString *string = [[[NSString alloc] initWithData:self encoding:encoding] autorelease];
	
	return !string ? [[[NSString alloc] initWithData:self encoding:NSASCIIStringEncoding] autorelease] : string;
}

/*
 * Convert data objects to their string representation (max 255 chars)
 * in the current encoding, falling back to ascii. (Mainly used for displaying
 * large blob data in a tableView)
 */
- (NSString *)shortStringRepresentationUsingEncoding:(NSStringEncoding)encoding
{
	NSString *string = [self stringRepresentationUsingEncoding:encoding];

	if (!string) {
		string = @"-- cannot display --";
	}
	else if ([string length] > 255) {
		string = [[string substringToIndex:254] stringByAppendingString:@"…"];
	}
	
	return string;
}

- (void)enumerateLinesBreakingAt:(SPLineTerminator)lbChars withBlock:(void (^)(NSRange line,BOOL *stop))block
{
	if(lbChars == SPLineTerminatorAny) lbChars = SPLineTerminatorCR|SPLineTerminatorLF|SPLineTerminatorCRLF;
	
	const uint8_t *bytes = [self bytes];
	NSUInteger length = [self length];
	
	NSUInteger curStart = 0;
	SPLineTerminator terminatorFound = 0;
	NSUInteger i;
	for (i = 0; i < length; i++) {
		uint8_t chr = bytes[i];
		// if looking for cr and/or crlf we look for cr otherwise for lf
		if(((lbChars & SPLineTerminatorCRLF) || (lbChars & SPLineTerminatorCR)) && chr == '\r') {
			//if we are looking for CRLF check for the following LF
			if((lbChars & SPLineTerminatorCRLF) && ((i+1) < length) && bytes[i+1] == '\n') {
				terminatorFound = SPLineTerminatorCRLF;
			}
			//if we were looking for CR we've found one
			else if((lbChars & SPLineTerminatorCR)) {
				terminatorFound = SPLineTerminatorCR;
			}
		}
		else if((lbChars & SPLineTerminatorLF) && chr == '\n') {
			terminatorFound = SPLineTerminatorLF;
		}
		// no linebreak yet ?
		if(!terminatorFound) continue;
		
		// found one. call the block.
		BOOL stop = NO;
		NSRange lineRange = NSMakeRange(curStart, (i-curStart));
		block(lineRange,&stop);
		if(stop) return;
		
		// reset vars for next line
		if(terminatorFound == SPLineTerminatorCRLF) i++; //skip the \n in CRLF
		curStart = (i+1);
		terminatorFound = 0;
	}
	// there could we one unterminated line left in buffer
	if(curStart < i) {
		NSRange lineRange = NSMakeRange(curStart, (i-curStart));
		BOOL iDontCare = NO;
		block(lineRange,&iDontCare);
	}
}

@end

#pragma mark -

uint32_t LimitUInt32(NSUInteger i) {
#if NSUIntegerMax > UINT32_MAX
	return (i > UINT32_MAX)? UINT32_MAX : (uint32_t)i;
#else
	return i;
#endif
}
