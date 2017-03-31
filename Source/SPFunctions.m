//
//  SPFunctions.m
//  sequel-pro
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

#import "SPFunctions.h"
#import <Security/SecRandom.h>
#import "SPOSInfo.h"

void SPMainQSync(void (^block)(void))
{
	if(dispatch_get_current_queue() == dispatch_get_main_queue()) {
		block();
	}
	else {
		dispatch_sync(dispatch_get_main_queue(), block);
	}
}

int SPBetterRandomBytes(uint8_t *buf, size_t count)
{
	if([SPOSInfo isOSVersionAtLeastMajor:10 minor:7 patch:0]) {
		return SecRandomCopyBytes(kSecRandomDefault, count, buf);
	}

	// Version for 10.6
	// https://developer.apple.com/library/prerelease/mac/documentation/Security/Conceptual/cryptoservices/RandomNumberGenerationAPIs/RandomNumberGenerationAPIs.html#//apple_ref/doc/uid/TP40011172-CH12-SW1
	FILE *fp = fopen("/dev/random", "r");
 
	if (!fp) return -1;
 
	size_t i;
	for (i=0; i<count; i++) {
		int c = fgetc(fp);
		if(c == EOF) { // /dev/random should never EOF
			errno = ferror(fp);
			return -1;
		}
		buf[i] = c;
	}
 
	fclose(fp);
	
	return 0;
}

NSUInteger SPIntS2U(NSInteger i)
{
	if(i < 0) [NSException raise:NSRangeException format:@"NSInteger %ld does not fit in NSUInteger",i];
	
	return (NSUInteger)i;
}

id SPBoxNil(id object)
{
	if(object == nil) return [NSNull null];
	
	return object;
}
