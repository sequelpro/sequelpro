//
//  NSDictionary_DeepMutableCopy.m
//
//  Created by Matt Gemmell on 02/05/2008.
//  Copyright 2008 Instinctive Code. All rights reserved.
//

#import "NSDictionary_DeepMutableCopy.h"


@implementation NSDictionary (DeepMutableCopy)


- (NSMutableDictionary *)deepMutableCopy;
{
    NSMutableDictionary *newDictionary;
    NSEnumerator *keyEnumerator;
    id anObject;
    id aKey;
	
    newDictionary = [self mutableCopy];
    // Run through the new dictionary and replace any objects that respond to -deepMutableCopy or -mutableCopy with copies.
    keyEnumerator = [[newDictionary allKeys] objectEnumerator];
    while ((aKey = [keyEnumerator nextObject])) {
        anObject = [newDictionary objectForKey:aKey];
        if ([anObject respondsToSelector:@selector(deepMutableCopy)]) {
            anObject = [anObject deepMutableCopy];
            [newDictionary setObject:anObject forKey:aKey];
            [anObject release];
        } else if ([anObject respondsToSelector:@selector(mutableCopyWithZone:)]) {
            anObject = [anObject mutableCopyWithZone:nil];
            [newDictionary setObject:anObject forKey:aKey];
            [anObject release];
        } else {
			[newDictionary setObject:anObject forKey:aKey];
		}
    }
	
    return newDictionary;
}


@end
