//
//  $Id: SPDataAdditions.m 891 2009-06-19 10:01:14Z bibiko $
//
//  SPDataAdditions.m
//  sequel-pro
//
//  dataEncryptedWithPassword and dataDecryptedWithPassword:
//   License: FREEWARE http://aquaticmac.com/cocoa.php
//    Copyright (c) 2005, Lucas Newman
//    All rights reserved.
//
//  Created by Hans-Jörg Bibiko on June 19, 2009
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPDataAdditions.h"
#include <zlib.h>
#include <openssl/aes.h>
#include <openssl/sha.h>

static char base64encodingTable[64] = {
'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/' };

@implementation NSData (SPDataAdditions)

/*
 * Derived from http://colloquy.info/project/browser/trunk/NSDataAdditions.m?rev=1576
 *  Created by khammond on Mon Oct 29 2001.
 *  Formatted by Timothy Hatcher on Sun Jul 4 2004.
 *  Copyright (c) 2001 Kyle Hammond. All rights reserved.
 *  Original development by Dave Winer.
 *
 * Convert self to a base64 encoded NSString
 */
- (NSString *) base64EncodingWithLineLength:(NSUInteger)lineLength {

	const unsigned char *bytes = [self bytes];
	NSUInteger ixtext = 0;
	NSUInteger lentext = [self length];
	NSInteger ctremaining = 0;
	unsigned char inbuf[3], outbuf[4];
	short i = 0;
	short charsonline = 0, ctcopy = 0;
	NSUInteger ix = 0;

	NSMutableString *base64 = [NSMutableString stringWithCapacity:lentext];

	while(1) {
		ctremaining = lentext - ixtext;
		if( ctremaining <= 0 ) break;

		for( i = 0; i < 3; i++ ) {
			ix = ixtext + i;
			if( ix < lentext ) inbuf[i] = bytes[ix];
			else inbuf [i] = 0;
		}

		outbuf [0] = (inbuf [0] & 0xFC) >> 2;
		outbuf [1] = ((inbuf [0] & 0x03) << 4) | ((inbuf [1] & 0xF0) >> 4);
		outbuf [2] = ((inbuf [1] & 0x0F) << 2) | ((inbuf [2] & 0xC0) >> 6);
		outbuf [3] = inbuf [2] & 0x3F;
		ctcopy = 4;

		switch( ctremaining ) {
			case 1: 
			ctcopy = 2; 
			break;
			case 2: 
			ctcopy = 3; 
			break;
		}

		for( i = 0; i < ctcopy; i++ )
			[base64 appendFormat:@"%c", base64encodingTable[outbuf[i]]];

		for( i = ctcopy; i < 4; i++ )
			[base64 appendFormat:@"%c",'='];

		ixtext += 3;
		charsonline += 4;

		if( lineLength > 0 ) {
			if (charsonline >= lineLength) {
				charsonline = 0;
				[base64 appendString:@"\n"];
			}
		}
	}

	return base64;
}

- (NSData*)dataEncryptedWithPassword:(NSString*)password
{
	// Create a random 128-bit initialization vector
	srand(time(NULL));
	NSInteger ivIndex;
	unsigned char iv[16];
	for (ivIndex = 0; ivIndex < 16; ivIndex++)
		iv[ivIndex] = rand() & 0xff;
		
	// Calculate the 16-byte AES block padding
	NSInteger dataLength = [self length];
	NSInteger paddedLength = dataLength + (32 - (dataLength % 16));
	NSInteger totalLength = paddedLength + 16; // Data plus IV
	
	// Allocate enough space for the IV + ciphertext
	unsigned char *encryptedBytes = calloc(1, totalLength);
	// The first block of the ciphertext buffer is the IV
	memcpy(encryptedBytes, iv, 16);
	
	unsigned char *paddedBytes = calloc(1, paddedLength);
	memcpy(paddedBytes, [self bytes], dataLength);
	
	// The last 32-bit chunk is the size of the plaintext, which is encrypted with the plaintext
	NSInteger bigIntDataLength = NSSwapHostIntToBig(dataLength);
	memcpy(paddedBytes + (paddedLength - 4), &bigIntDataLength, 4);
	
	// Create the key from first 128-bits of the 160-bit password hash
	unsigned char passwordDigest[20];
	SHA1((const unsigned char *)[password UTF8String], strlen([password UTF8String]), passwordDigest);
	AES_KEY aesKey;
	AES_set_encrypt_key(passwordDigest, 128, &aesKey);
	
	// AES-128-cbc encrypt the data, filling in the buffer after the IV
	AES_cbc_encrypt(paddedBytes, encryptedBytes + 16, paddedLength, &aesKey, iv, AES_ENCRYPT);
	free(paddedBytes);
    
	return [NSData dataWithBytesNoCopy:encryptedBytes length:totalLength];
}

- (NSData*)dataDecryptedWithPassword:(NSString*)password
{
	// Create the key from the password hash
	unsigned char passwordDigest[20];
	SHA1((const unsigned char *)[password UTF8String], strlen([password UTF8String]), passwordDigest);
	
	// AES-128-cbc decrypt the data
	AES_KEY aesKey;
	AES_set_decrypt_key(passwordDigest, 128, &aesKey);
	
	// Total length = encrypted length + IV
	NSInteger totalLength = [self length];
	NSInteger encryptedLength = totalLength - 16;
	
	// Take the IV from the first 128-bit block
	unsigned char iv[16];
	memcpy(iv, [self bytes], 16);
	
	// Decrypt the data
	unsigned char *decryptedBytes = (unsigned char*)malloc(encryptedLength);
	AES_cbc_encrypt([self bytes] + 16, decryptedBytes, encryptedLength, &aesKey, iv, AES_DECRYPT);
	
	// If decryption was successful, these blocks will be zeroed
	if ( *((NSUInteger*)decryptedBytes + ((encryptedLength / 4) - 4)) ||
		 *((NSUInteger*)decryptedBytes + ((encryptedLength / 4) - 3)) ||
		 *((NSUInteger*)decryptedBytes + ((encryptedLength / 4) - 2)) )
	{
		return nil;
	}
	
	// Get the size of the data from the last 32-bit chunk
	NSInteger bigIntDataLength = *((NSUInteger*)decryptedBytes + ((encryptedLength / 4) - 1));
	NSInteger dataLength = NSSwapBigIntToHost(bigIntDataLength);
	
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
	zlibStream.avail_in = [self length];
	zlibStream.total_out = 0;
	zlibStream.zalloc = Z_NULL;
	zlibStream.zfree = Z_NULL;

	if(inflateInit(&zlibStream) != Z_OK) return nil;

	while(!done)
	{
		if (zlibStream.total_out >= [unzipData length])
			[unzipData increaseLengthBy: half_length];
		zlibStream.next_out = [unzipData mutableBytes] + zlibStream.total_out;
		zlibStream.avail_out = [unzipData length] - zlibStream.total_out;

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
	zlibStream.avail_in = [self length];

	if (deflateInit(&zlibStream, Z_DEFAULT_COMPRESSION) != Z_OK) return nil;


	NSMutableData *zipData = [NSMutableData dataWithLength:16384];

	do{

		if (zlibStream.total_out >= [zipData length])
			[zipData increaseLengthBy: 16384];

		zlibStream.next_out = [zipData mutableBytes] + zlibStream.total_out;
		zlibStream.avail_out = [zipData length] - zlibStream.total_out;

		deflate(&zlibStream, Z_FINISH);  

	} while(zlibStream.avail_out == 0);

	deflateEnd(&zlibStream);

	[zipData setLength: zlibStream.total_out];
	return [NSData dataWithData: zipData];
}

- (NSString *)dataToFormattedHexString
/*
 returns the hex representation of the given data
 */
{
	NSUInteger i, j;
	NSUInteger totalLength = [self length];
	NSUInteger bytesPerLine = 16;
	NSMutableString *retVal = [NSMutableString string];

	// get the length of the longest location
	NSUInteger longest = [(NSString *)[NSString stringWithFormat:@"%X", totalLength - ( totalLength % bytesPerLine )] length];

	for ( i = 0; i < totalLength; i += bytesPerLine ) {

		NSMutableString *hex = [[NSMutableString alloc] initWithCapacity:(3 * bytesPerLine - 1)];
		NSMutableString *location = [[NSMutableString alloc] initWithCapacity:(longest + 2)];

		unsigned char *buffer;
		NSUInteger buffLength = bytesPerLine;

		// add hex value of location
		[location appendString:[NSString stringWithFormat:@"%X", i]];
		
		// pad it
		while( longest > [location length] ) {
			[location insertString:@"0" atIndex:0];
		}
		
		// get the chars from the NSData obj
		if ( i + buffLength >= totalLength ) {
			buffLength = totalLength - i;
		}

		buffer = (unsigned char*) malloc( sizeof(unsigned char) * buffLength + 1);

		[self getBytes:buffer range:NSMakeRange(i, buffLength)];
		
		// build the hex string
		for ( j = 0; j < buffLength; j++ ) {

			[hex appendString:[NSString stringWithFormat:@"%02X ", *(buffer + j)]];

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
		[retVal appendFormat:@"%@  %@ %@\n", location, hex, [NSString stringWithFormat:@"%s", buffer]];
		
		// clean up
		[hex release];
		[location release];
		free( buffer );
	}

	return retVal;
}

/*
 * Convert data objects to their string representation (max 255 chars) 
 * in the current encoding, falling back to ascii. (Mainly used for displaying
 * large blob data in a tableView)
 */
- (NSString *) shortStringRepresentationUsingEncoding:(NSStringEncoding)encoding
{
	NSString *tmp = [[NSString alloc] initWithData:self encoding:encoding];
	NSString *shortString;
	if (tmp == nil)
		tmp = [[NSString alloc] initWithData:self encoding:NSASCIIStringEncoding];
	if (tmp == nil)
		return @"- cannot be displayed -";
	else {
		if([tmp length]>255)
			shortString = [[NSString stringWithString:tmp] substringToIndex:255];
		else
			shortString = [NSString stringWithString:tmp];
	}
	[tmp release];
	return shortString;
}

@end
