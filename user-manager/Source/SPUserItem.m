//
//  SPUserItem.m
//  sequel-pro
//
//  Created by Mark Townsend on 1/24/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "SPUserItem.h"


@implementation SPUserItem

- (id)init
{
	[super init];
	
	children = [[NSMutableArray alloc] init];
	
	return self;
}

- (void)dealloc
{
	[children release];
	children = nil;
	[username release];
	[password release];
	[host release];
	[itemTitle release];
	[super dealloc];
}

- (void)setItemTitle:(NSString *)title
{
	[itemTitle release];
	itemTitle = [title retain];
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
