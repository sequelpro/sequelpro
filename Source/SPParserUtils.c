//
//  SPParserUtils.c
//  sequel-pro
//
//  Created by Max Lohrmann on 27.01.15.
//  Relocated from existing files. Previous copyright applies.
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

#include "SPParserUtils.h"
#include <stdint.h>

#define ONEMASK ((size_t)(-1) / 0xFF)

// adapted from http://www.daemonology.net/blog/2008-06-05-faster-utf8-strlen.html
size_t utf8strlen(const char * _s)
{
	const char * s;
	size_t count = 0;
	size_t u;
	unsigned char b;
	
	/* Handle any initial misaligned bytes. */
	for (s = _s; (uintptr_t)(s) & (sizeof(size_t) - 1); s++) {
		b = *s;
		
		/* Exit if we hit a zero byte. */
		if (b == '\0')
			goto done;
		
		/* Is this byte NOT the first byte of a character? */
		count += (b >> 7) & ((~b) >> 6);
	}
	
	/* Handle complete blocks. */
	for (; ; s += sizeof(size_t)) {
		/* Prefetch 256 bytes ahead. */
		__builtin_prefetch(&s[256], 0, 0);
		
		/* Grab 4 or 8 bytes of UTF-8 data. */
		u = *(size_t *)(s);
		
		/* Exit the loop if there are any zero bytes. */
		if ((u - ONEMASK) & (~u) & (ONEMASK * 0x80))
			break;
		
		/* Count bytes which are NOT the first byte of a character. */
		u = ((u & (ONEMASK * 0x80)) >> 7) & ((~u) >> 6);
		count += (u * ONEMASK) >> ((sizeof(size_t) - 1) * 8);
	}
	
	/* Take care of any left-over bytes. */
	for (; ; s++) {
		b = *s;
		
		/* Exit if we hit a zero byte. */
		if (b == '\0')
			break;
		
		/* Is this byte NOT the first byte of a character? */
		count += (b >> 7) & ((~b) >> 6);
	}
	
done:
	return ((s - _s) - count);
}
