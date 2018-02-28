//
//  SPMySQLUtilities.c
//  SPMySQLFramework
//
//  Created by Max Lohrmann on 25.02.2018
//  Copyright (c) 2018 Max Lohrmann. All rights reserved.
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

#include <errno.h>
#define __STDC_WANT_LIB_EXT1__ 1
#include <string.h>
#include <dlfcn.h>
#include <dispatch/dispatch.h>

#include "SPMySQLUtilities.h"

static errno_t LegacyMemsetS(void *ptr, rsize_t ignored, int value, rsize_t count);

errno_t SPMySQLSafeEraseMemory(void *cBuffer, size_t cLength) {
	// memset_s is 10.9+ only - if we added a link time dependency, SP wouldn't launch on older targets
	static errno_t (*memsetPtr)(void *, rsize_t, int, rsize_t);
	static dispatch_once_t findMemsetToken;
	dispatch_once(&findMemsetToken, ^{
		memsetPtr = dlsym(RTLD_DEFAULT, "memset_s");
		if(!memsetPtr) memsetPtr = &LegacyMemsetS;
	});

	return (*memsetPtr)(cBuffer, cLength, '\0', cLength);
}

/**
 * This function tries to emulate the important (to us) parts
 * of memset_s on pre 10.9 systems.
 *
 * The implementation is taken from the original memset_s proposal:
 *   http://www.open-std.org/jtc1/sc22/wg14/www/docs/n1381.pdf
 */
errno_t LegacyMemsetS(void *s, rsize_t smax __attribute__((unused)), int c, rsize_t n)
{
	volatile unsigned char * addr = (volatile unsigned char *)s;
	while(n--) *addr++ = (unsigned char)c;

	return 0;
}
