//
//  SPFunctions.h
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

/**
 * Synchronously execute a block on the main thread.
 * This function can be called from a background thread as well as from
 * the main thread.
 */
void SPMainQSync(void (^block)(void));

/**
 * Asynchronously execute a block on the main run loop.
 * This function is equivalent to calling -[[NSRunLoop mainRunLoop] performBlock:] on 10.12+
 */
void SPMainLoopAsync(void (^block)(void));

/**
 * Copies count bytes into buf provided by caller
 * @param buf Base address to copy to
 * @param count Number of bytes to copy
 * @return 0 on success or -1 if something went wrong, check errno
 */
int SPBetterRandomBytes(uint8_t *buf, size_t count);

/**
 * Convert a signed integer into an unsigned integer or throw an exception if the values don't fit.
 * @param i a signed integer
 * @return the same value, casted to unsigned integer
 */
NSUInteger SPIntS2U(NSInteger i);

/**
 * Converts nil to NSNull for passing into arrays
 * @return The object that was passed in or [NSNull null] if object == nil
 * @see -[SPObjectAdditions unboxNull]
 */
id SPBoxNil(id object);
