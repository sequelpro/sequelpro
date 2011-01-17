//
//  $Id$
//
//  SPTreeNode.m
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on November 23, 2010
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPTreeNode.h"
#import "SPFavoriteNode.h"
#import "SPGroupNode.h"

@implementation SPTreeNode

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
		[self setIsGroup:NO];
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
			[[self childNodes] removeObjectIdenticalTo:object];
			return;
		}
		
		if (![node isLeaf]) {
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
		
		if (![node isLeaf]) {
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
		if ([node isLeaf]) {
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
		if ([node isLeaf]) {
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
		if (![node isLeaf]) {
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
		
		if (![node isLeaf]) {
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
 * sub-nodes of the nodes contained inside the supplied array.
 *
 * @param nodes The array of nodes to search
 * 
 * @return A BOOL indicating whether or not it's a descendent
 */
- (BOOL)isDescendantOfOrOneOfNodes:(NSArray *)nodes
{	
    for (SPTreeNode *node in nodes)
	{
		if (node == self) return YES;
		
		// Check all the sub-nodes
		if (![node isLeaf]) {
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
		
		dictionary = [NSDictionary dictionaryWithDictionary:[object nodeFavorite]];
	}
	else if ([object isKindOfClass:[SPGroupNode class]]) {
		
		NSMutableArray *children = [NSMutableArray array];
		
		for (SPTreeNode *node in [self childNodes])
		{
			[children addObject:[node dictionaryRepresentation]];
		}
		
		dictionary = [NSMutableDictionary dictionary];
		
		NSString *name = (![self parentNode]) ? NSLocalizedString(@"Favorites", @"favorites label") : [object nodeName];
		
		[dictionary setObject:(name) ? name : @"" forKey:SPFavoritesGroupNameKey];
		[dictionary setObject:children forKey:SPFavoriteChildrenKey];
	}
	
	return dictionary;
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
