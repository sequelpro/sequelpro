//
//  SPUserItem.h
//  sequel-pro
//
//  Created by Mark Townsend on 1/24/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SPUserItem : NSObject {
	SPUserItem *parent;
	NSMutableArray *children;
	NSString *username;
	NSString *password;
	NSString *host;
	NSMutableDictionary *globalPrivileges;
	NSString *itemTitle;
	BOOL leaf;
	
}

- (id)init;
- (void)dealloc;

- (int)numberOfChildren;
- (SPUserItem *)childAtIndex:(int)index;

// Properties
- (NSString *)itemTitle;
- (void)setHost:(NSString *)neHost;
- (NSString *)host;
- (void)setUsername:(NSString *)newUsername;
- (NSString *)username;
- (void)setPassword:(NSString *)newPassword;
- (NSString *)password;
- (void)setGlobalPrivileges:(NSMutableDictionary *)newGlobalPrivileges;
- (NSMutableDictionary *)globalPrivileges;

- (NSMutableArray *)children;
- (void)setChildren:(NSMutableArray *)theChildren;
- (void)addChild:(SPUserItem *)item;
- (void)removeChild:(SPUserItem *)item;
- (void)setLeaf:(BOOL)value;
- (BOOL)isLeaf;

@end
