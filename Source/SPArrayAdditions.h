//
//  SPArrayAdditions.h
//  sequel-pro
//
//  Created by Jakob Egger on March 24, 2009.
//  Copyright (c) 2009 Jakob Egger. All rights reserved.
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

static inline id NSArrayObjectAtIndex(NSArray *self, NSUInteger i) 
{
	return (id)CFArrayGetValueAtIndex((CFArrayRef)self, (long)i);
}

/**
 * Set up a static function to allow fast mutable array insertion using
 * cached selectors.
 * At least in 10.7, inserting items into an array at a known point
 * using NSMutableArray methods appears to be the fastest way of adding
 * items to a CF/NSMutableArray.
 */
static inline void NSMutableArrayInsertObject(NSMutableArray *self, id anObject, NSUInteger anIndex)
{
	typedef id (*NSMutableArrayInsertObjectPtr)(NSMutableArray*, SEL, id, NSUInteger);
	static NSMutableArrayInsertObjectPtr cachedMethodPointer;
	static SEL cachedSelector;

	if (!cachedSelector) cachedSelector = @selector(insertObject:atIndex:);
	if (!cachedMethodPointer) cachedMethodPointer = (NSMutableArrayInsertObjectPtr)[self methodForSelector:cachedSelector];

	cachedMethodPointer(self, cachedSelector, anObject, anIndex);
}
/**
 * Set up a static function to allow fast mutable array insertion using
 * cached selectors.
 * At least in 10.7, adding items to an array using NSMutableArray methods
 * appears to be the fastest approach to adding items to a CF/NSMutableArray;
 * only NSMutableArrayInsertObject is faster if the position is known.
 */
static inline void NSMutableArrayAddObject(NSMutableArray *self, id anObject)
{
	typedef id (*NSMutableArrayAddObjectPtr)(NSMutableArray*, SEL, id);
	static NSMutableArrayAddObjectPtr cachedMethodPointer;
	static SEL cachedSelector;

	if (!cachedSelector) cachedSelector = @selector(addObject:);
	if (!cachedMethodPointer) cachedMethodPointer = (NSMutableArrayAddObjectPtr)[self methodForSelector:cachedSelector];

	cachedMethodPointer(self, cachedSelector, anObject);
}

static inline void NSMutableArrayReplaceObject(NSArray *self, CFIndex idx, id anObject) 
{
	CFArraySetValueAtIndex((CFMutableArrayRef)self, idx, anObject);
}

@interface NSArray (SPArrayAdditions)

- (NSString *)componentsJoinedAndBacktickQuoted;
- (NSString *)componentsJoinedByCommas;
- (NSString *)componentsJoinedBySpacesAndQuoted;
- (NSString *)componentsJoinedByPeriodAndBacktickQuoted;
- (NSString *)componentsJoinedByPeriodAndBacktickQuotedAndIgnoreFirst;
- (NSString *)componentsJoinedAsCSV;

- (NSArray *)subarrayWithIndexes:(NSIndexSet *)indexes;

/**
 * Variant of objectAtIndex: that avoids the "index out of bounds" exception by
 * just returning nil instead.
 *
 * @warning This method is NOT thread-safe.
 * @param index  An index
 * @return The object located at index or nil.
 */
- (id)objectOrNilAtIndex:(NSUInteger)index;

@end
