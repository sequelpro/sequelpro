//
//  $Id$
//
//  SPArrayAdditions.h
//  sequel-pro
//
//  Created by Jakob Egger on March 24, 2009
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

@end
