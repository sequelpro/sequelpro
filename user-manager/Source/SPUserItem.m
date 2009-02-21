//
//  SPUserItem.m
//  sequel-pro
//
//  Created by Mark Townsend on 1/24/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "SPUserItem.h"
@interface SPUserItem (PrivateMethods)
- (void)_initializeGlobalPrivileges;
@end


@implementation SPUserItem

+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObject:@"username"] triggerChangeNotificationsForDependentKey:@"itemTitle"];
}

- (id)init
{
	NSLog(@"SPUserItem init");
	[super init];
	
	children = [[NSMutableArray alloc] init];
	[self _initializeGlobalPrivileges];
	[self setLeaf:NO];
	
	return self;
}

- (void)dealloc
{
	[globalPrivileges release];
	globalPrivileges = nil;
	[children release];
	children = nil;
	[username release];
	[password release];
	[host release];
	[super dealloc];
}

- (void)_initializeGlobalPrivileges
{
	globalPrivileges = [[NSMutableDictionary alloc] init];
	[globalPrivileges setValue:FALSE forKey:@"Select_priv"];
	[globalPrivileges setValue:FALSE forKey:@"Insert_priv"];
	
}
- (NSString *)itemTitle
{
	if ([self isLeaf]){
		return [self host];
	} else {
		return [self username];
	}
}
- (void)setHost:(NSString *)newHost
{
	[host release];
	host = [newHost retain];
}

- (void)setLeaf:(BOOL)value
{
	leaf = value;
}

- (BOOL)isLeaf
{
	return leaf;
}
- (NSString *)host
{
	return host;
}
- (void)setUsername:(NSString *)newUsername
{
	[username release];
	username = [newUsername retain];
	for (int i = 0; i < [children count]; i++)
	{
		SPUserItem *child = [children objectAtIndex:i];
		[child setUsername:username];
	}
}

- (NSString *)username
{
	return username;
}

- (void)setPassword:(NSString *)newPassword
{
	[password release];
	password = [newPassword retain];
}

- (NSString *)password
{
	return password;
}

- (void)setGlobalPrivileges:(NSMutableDictionary *)newGlobalPrivileges
{
	[globalPrivileges release];
	globalPrivileges = [newGlobalPrivileges retain];
}

- (NSMutableDictionary *)globalPrivileges
{
	return globalPrivileges;
}

- (int)numberOfChildren
{
	return [children count];
}

- (SPUserItem *)childAtIndex:(int)index
{
	return [children objectAtIndex:index];
}


- (NSMutableArray *)children
{
	return children;
}
- (void)setChildren:(NSMutableArray *)theChildren
{
	[children release];
	children = nil;
	children = [theChildren retain];
}

- (void)addChild:(SPUserItem *)item 
{
	
	[children addObject:item];
}
- (void)removeChild:(SPUserItem *)item
{
	[children removeObject:item];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@\nHosts: %@",[self username], [self children]];
}
@end
