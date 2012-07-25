//
//  $Id$
//
//  NSNotificationCenterThreadingAdditions.m
//  Enable NSNotification being sent from threads
//
//  Copied from the TCMPortMapper project; original code available on
//  Google Code at <http://code.google.com/p/tcmportmapper/source/browse/TCMPortMapper/framework/NSNotificationCenterThreadingAdditions.m>
//
//  Copyright (c) 2007-2008 TheCodingMonkeys: 
//  Martin Pittenauer, Dominik Wagner, <http://codingmonkeys.de>
//  Some rights reserved: <http://opensource.org/licenses/mit-license.php> 

#import "NSNotificationCenterThreadingAdditions.h"
#import <pthread.h>

@implementation NSNotificationCenter (NSNotificationCenterThreadingAdditions)

+ (void)_postNotification:(NSNotification *)aNotification {
    [[self defaultCenter] postNotification:aNotification];
}

+ (void)_postNotificationViaDictionary:(NSDictionary *)anInfoDictionary {
    NSString *name   = [anInfoDictionary objectForKey:@"name"];
    id        object = [anInfoDictionary objectForKey:@"object"];
    [[self defaultCenter] postNotificationName:name 
                                        object:object 
                                      userInfo:nil];
    [anInfoDictionary release];
}


- (void)postNotificationOnMainThread:(NSNotification *)aNotification {
    if( pthread_main_np() ) return [self postNotification:aNotification];
    [[self class] performSelectorOnMainThread:@selector( _postNotification: ) withObject:aNotification waitUntilDone:NO];
}

- (void) postNotificationOnMainThreadWithName:(NSString *)aName object:(id)anObject {
    if( pthread_main_np() ) return [self postNotificationName:aName object:anObject userInfo:nil];
    NSMutableDictionary *info = [[NSMutableDictionary allocWithZone:nil] initWithCapacity:2];
    if (aName) {
        [info setObject:aName forKey:@"name"];
    }
    if (anObject) {
        [info setObject:anObject forKey:@"object"];
    }
    [[self class] performSelectorOnMainThread:@selector(_postNotificationViaDictionary:)
                                   withObject:info 
                                waitUntilDone:NO];
}
@end
