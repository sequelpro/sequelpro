//
//  SPFavoriteNode.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 8, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPTreeNode.h"
#import "SPFavoriteNode.h"

// Constants
static NSString *SPFavoriteNodeKey = @"SPFavoriteNode";

@implementation SPFavoriteNode

@synthesize nodeFavorite;

#pragma mark -
#pragma mark Initialisation

- (id)init
{
	if ((self = [super init])) {
		[self setNodeFavorite:nil];
	}
	
	return self;
}

- (id)initWithDictionary:(NSMutableDictionary *)dictionary
{
	if ((self = [self init])) {
		[self setNodeFavorite:dictionary];
	}
	
	return self;
}

+ (SPFavoriteNode *)favoriteNodeWithDictionary:(NSMutableDictionary *)dictionary
{
	return [[[self alloc] initWithDictionary:dictionary] autorelease];
}

#pragma mark -
#pragma mark Copying protocol methods

- (id)copyWithZone:(NSZone *)zone
{
	SPFavoriteNode *node = [[[self class] allocWithZone:zone] init];
	
	[node setNodeFavorite:[[self nodeFavorite] copyWithZone:zone]];
	
	return [node autorelease];
}

#pragma mark -
#pragma mark Coding protocol methods

- (id)initWithCoder:(NSCoder *)coder
{
	if (!(self = [super init])) {
		return nil;
	}
	
	[self setNodeFavorite:[coder decodeObjectForKey:SPFavoriteNodeKey]];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{	
	[coder encodeObject:[self nodeFavorite] forKey:SPFavoriteNodeKey];
}

#pragma mark -
#pragma mark Other

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@: %p ('%@')>", [self className], self, [self nodeName]];
}

- (NSString *)nodeName
{
	return [[self nodeFavorite] objectForKey:SPFavoriteNameKey];
}

#pragma mark -

- (void)dealloc
{
	if (nodeFavorite) SPClear(nodeFavorite);
	
	[super dealloc];
}

@end
