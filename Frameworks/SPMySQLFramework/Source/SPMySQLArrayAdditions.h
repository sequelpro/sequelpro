//
//  $Id$
//
//  SPMySQLArrayAdditions.h
//  SPMySQLFramework
//
//  Created by Rowan Beentje (rowan.beent.je) on February 23, 2012
//  Copyright (c) 2012 Rowan Beentje. All rights reserved.
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
//  More info at <http://code.google.com/p/sequel-pro/>

/**
 * Set up a static function to allow fast mutable array insertion using
 * cached selectors.
 * At least in 10.7, inserting items into an array at a known point
 * using NSMutableArray methods appears to be the fastest way of adding
 * items to a CF/NSMutableArray.
 */
static inline void SPMySQLMutableArrayInsertObject(NSMutableArray *self, id anObject, NSUInteger anIndex)
{
	typedef id (*SPMySQLMutableArrayInsertObjectPtr)(NSMutableArray*, SEL, id, NSUInteger);
	static SPMySQLMutableArrayInsertObjectPtr cachedMethodPointer;
	static SEL cachedSelector;

	if (!cachedSelector) cachedSelector = @selector(insertObject:atIndex:);
	if (!cachedMethodPointer) cachedMethodPointer = (SPMySQLMutableArrayInsertObjectPtr)[self methodForSelector:cachedSelector];

	cachedMethodPointer(self, cachedSelector, anObject, anIndex);
}
