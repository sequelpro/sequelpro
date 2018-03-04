//
//  SPTreeNode.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 23, 2010.
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
#import "SPGroupNode.h"

// Constants
static NSString *SPTreeNodeIsGroupKey = @"SPTreeNodeIsGroup";

@implementation SPTreeNode

@dynamic childNodes;
@synthesize isGroup;

#pragma mark -
#pragma mark Initialisation

+ (id)treeNodeWithRepresentedObject:(id)object
{
	return [[[SPTreeNode alloc] initWithRepresentedObject:object] autorelease];
}

- (id)initWithRepresentedObject:(id)object
{
	if ((self = [super initWithRepresentedObject:object])) {
		[self setIsGroup:[object isKindOfClass:[SPGroupNode class]]];
	}
	
	return self;
}

#pragma mark -
#pragma mark Public API

/**
 * Recursive method which searches children and children of all sub-nodes
 * to remove the supplied object.
 *
 * @param object The object to remove
 */
- (void)removeObjectFromChildren:(id)object
{	
	for (SPTreeNode *node in [self childNodes])
	{
		if (node == object) {
			[[self mutableChildNodes] removeObjectIdenticalTo:object];
			return;
		}
		
		if ([node isGroup]) {
			[node removeObjectFromChildren:object];
		}
	}
}

/**
 * Generates an array of all descendants.
 *
 * @return The array of decendant nodes.
 */
- (NSMutableArray *)descendants
{
	NSMutableArray *descendants = [NSMutableArray array];
	
	for (SPTreeNode *node in [self childNodes])
	{
		[descendants addObject:node];
		
		if ([node isGroup]) {
			[descendants addObjectsFromArray:[node descendants]];
		}
	}
	
	return descendants;
}

/**
 * Generates an array of this node's child leafs nodes.
 *
 * @return The array of child nodes.
 */
- (NSMutableArray *)childLeafs
{
	NSMutableArray *childLeafs = [NSMutableArray array];
	
	for (SPTreeNode *node in [self childNodes])
	{
		if (![node isGroup]) {
			[childLeafs addObject:node];
		}
	}
	
	return childLeafs;
}

/**
 * Generates an array of all leafs in children and children of all sub-nodes (effectively all leaf nodes below
 * this node.
 *
 * @return The array of child nodes.
 */
- (NSMutableArray *)allChildLeafs
{
	NSMutableArray *childLeafs = [NSMutableArray array];
	
	for (SPTreeNode *node in [self childNodes])
	{
		if (![node isGroup]) {
			[childLeafs addObject:node];
		}
		else {
			[childLeafs addObjectsFromArray:[node allChildLeafs]];
		}
	}
	
	return childLeafs;
}

/**
 * Returns only the children that are group nodes.
 *
 * @return The array of child group nodes.
 */
- (NSMutableArray *)groupChildren
{
	NSMutableArray *groupChildren = [NSMutableArray array];
	
	for (SPTreeNode *node in [self childNodes])
	{
		if ([node isGroup]) {
			[groupChildren addObject:node];	
		}
	}
	
	return groupChildren;
}

/**
 * Finds the receiver's parent from the supplied array of nodes.
 *
 * @param array The array of nodes
 *
 * @return The parent of this instance of nil if not found
 */
- (SPTreeNode *)parentFromArray:(NSArray *)array
{
	SPTreeNode *result = nil;
	
	for (SPTreeNode *node in array)
	{
		if (node == self) break;
		
		if ([[node childNodes] indexOfObjectIdenticalTo:self] != NSNotFound) {
			result = node;
			break;
		}
		
		if ([node isGroup]) {
			SPTreeNode *innerNode = [self parentFromArray:[node childNodes]];
			
			if (innerNode) {
				result = innerNode;
				break;
			}
		}
	}
	
	return result;
}

/**
 * Returns YES if self is contained anywhere inside the children or children of
 * sub-nodes of the nodes contained inside the supplied array or is itself a 
 * member of the array.
 *
 * @param nodes The array of nodes to search
 * 
 * @return A BOOL indicating whether or not it's a descendent or array member
 */
- (BOOL)isDescendantOfOrOneOfNodes:(NSArray *)nodes
{	
    for (SPTreeNode *node in nodes)
	{
		if (node == self) return YES;
		
		// Check all the sub-nodes
		if ([node isGroup]) {
			if ([self isDescendantOfOrOneOfNodes:[node childNodes]]) {
				return YES;
			}
		}
    }
	
    return NO;
}

/**
 * Returns YES if self is contained anywhere inside the children or children of
 * sub-nodes of the nodes contained inside the supplied array, but NOT the given
 * array itself. 
 * This means, if self is a member of nodes but not a child of any
 * other node in nodes it will still return NO.
 *
 * @param nodes The array of nodes to search
 *
 * @return A BOOL indicating whether or not it's a descendent
 */
- (BOOL)isDescendantOfNodes:(NSArray *)nodes
{
	for (SPTreeNode *node in nodes)
	{
		if (node == self) continue;
		
		// Check all the sub-nodes
		if ([node isGroup]) {
			if ([self isDescendantOfOrOneOfNodes:[node childNodes]]) {
				return YES;
			}
		}
	}
	
	return NO;
}

/**
 * Constructs a dictionary representation of the favorite.
 *
 * @return The dictionary representation.
 */
- (NSDictionary *)dictionaryRepresentation
{
	NSMutableDictionary *dictionary = nil;
	
	id object = [self representedObject];
	
	if ([object isKindOfClass:[SPFavoriteNode class]]) {
		
		dictionary = [NSMutableDictionary dictionaryWithDictionary:[object nodeFavorite]];
	}
	else if ([object isKindOfClass:[SPGroupNode class]]) {
		
		NSMutableArray *children = [NSMutableArray array];
		
		for (SPTreeNode *node in [self childNodes])
		{
			NSDictionary *representation = [node dictionaryRepresentation];
			
			if (representation) {
				[children addObject:representation];
			}
		}
		
		dictionary = [NSMutableDictionary dictionary];
		
		NSString *name = (![self parentNode]) ? NSLocalizedString(@"Favorites", @"favorites label") : [object nodeName];
		
		[dictionary setObject:name ? name : @"" forKey:SPFavoritesGroupNameKey];
		[dictionary setObject:[NSNumber numberWithBool:[object nodeIsExpanded]] forKey:SPFavoritesGroupIsExpandedKey];
		[dictionary setObject:children forKey:SPFavoriteChildrenKey];
	}
	
	return dictionary;
}

#pragma mark -
#pragma mark Coding protocol methods

- (id)initWithCoder:(NSCoder *)coder
{
	if (!(self = [super init])) {
		return nil;
	}
	
	[self setIsGroup:[[coder decodeObjectForKey:SPTreeNodeIsGroupKey] boolValue]];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:[NSNumber numberWithBool:[self isGroup]] forKey:SPTreeNodeIsGroupKey];
}

#pragma mark -
#pragma mark Other

- (NSString *)description
{
	NSMutableString *description = [NSMutableString string];
	
	[description appendString:[[self representedObject] description]];
	[description appendString:@"\n"];
	
	NSArray *nodes = [self childNodes];
	
	for (NSUInteger i = 0; i < [nodes count]; i++)
	{
		SPTreeNode *node = [nodes objectAtIndex:i];
		
		[description appendString:([node isGroup]) ? [node description] : [[node representedObject] description]];
		
		if (i < ([nodes count] - 1)) [description appendString:@"\n"];
	}
	
	return description;
}

@end
