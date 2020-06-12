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
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		dispatch_queue_set_specific(dispatch_get_main_queue(), &onceToken, &onceToken, NULL);
	});
	
	if (dispatch_get_specific(&onceToken) == &onceToken) {
		block();
	}
	else {
		dispatch_sync(dispatch_get_main_queue(), block);
	}
}

void SPMainLoopAsync(void (^block)(void))
{
	NSArray *modes = @[NSDefaultRunLoopMode];
	CFRunLoopPerformBlock(CFRunLoopGetMain(), modes, block);
}

int SPBetterRandomBytes(uint8_t *buf, size_t count)
{
	return SecRandomCopyBytes(kSecRandomDefault, count, buf);
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
