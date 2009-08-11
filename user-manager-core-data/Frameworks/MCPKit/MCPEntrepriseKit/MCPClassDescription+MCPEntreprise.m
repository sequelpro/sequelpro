//
//  $Id$
//
//  MCPClassDescription+MCPEntreprise.m
//  MCPKit
//
//  Created by Serge Cohen (serge.cohen@m4x.org) on 01/11/04.
//  Copyright (c) 2004 Serge Cohen. All rights reserved.
//
//  Forked by the Sequel Pro team (sequelpro.com), April 2009
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
//  More info at <http://mysql-cocoa.sourceforge.net/>
//  More info at <http://code.google.com/p/sequel-pro/>

#import "MCPClassDescription+MCPEntreprise.h"

#import "MCPAttribute.h"
#import "MCPRelation.h"

@implementation MCPClassDescription (MCPEntreprise)

#pragma mark Pseudo getters (for NSClassDescription overload)
- (NSArray *) attributeKeys
{
	NSArray				*theRet;
   NSMutableArray		*theKeys =[[NSMutableArray alloc] init];
   unsigned int		i;

	for (i=0; i != [self countOfAttributes]; ++i) {
		[theKeys insertObject:[(MCPAttribute *)[self objectInAttributesAtIndex:i] name] atIndex:i];
	}
	theRet = [NSArray arrayWithArray:theKeys];
	[theKeys release];
	return theRet;	
}

- (NSString *) inverseRelationshipKey:(NSString *) relationshipKey
{
	unsigned int		index = [self indexOfRelation:relationshipKey];

	if (NSNotFound != index) {
		MCPRelation			*theRelation;

		theRelation = (MCPRelation *)[self objectInRelationsAtIndex:index];
		return [[theRelation inverseRelation] name];
	}
	return nil;
}

- (NSArray *) toManyRelationshipKeys
{
	NSArray				*theRet;
	NSMutableArray		*theToManyRel = [[NSMutableArray alloc] init];
	unsigned int		i, j;

	j=0;
	for (i=0; i != [self countOfRelations]; ++i) {
		MCPRelation		*theRelation = (MCPRelation *)[self objectInRelationsAtIndex:i];

		if ([theRelation isToMany]) {
			[theToManyRel insertObject:[theRelation name] atIndex:j];
			++j;
		}
	}
	theRet = [NSArray arrayWithArray:theToManyRel];
	[theToManyRel release];
	return theRet;
}

- (NSArray *) toOneRelationshipKeys;
{
	NSArray				*theRet;
	NSMutableArray		*theToOneRel = [[NSMutableArray alloc] init];
	unsigned int		i, j;
	
	j=0;
	for (i=0; i != [self countOfRelations]; ++i) {
		MCPRelation		*theRelation = (MCPRelation *)[self objectInRelationsAtIndex:i];
		
		if (! [theRelation isToMany]) {
			[theToOneRel insertObject:[theRelation name] atIndex:j];
			++j;
		}
	}
	theRet = [NSArray arrayWithArray:theToOneRel];
	[theToOneRel release];
	return theRet;
}

#pragma mark Specifics for MCPObject
- (NSArray *) primaryKeyAttributes
{
	NSMutableArray		*theRet = [NSMutableArray array];
	unsigned int		i, j;

	j = 0;
	for (i=0; i != [self countOfAttributes]; ++i) {
		MCPAttribute	*theAttribute = (MCPAttribute *)[self objectInAttributesAtIndex:i];

		if ([theAttribute isPartOfKey]) {
			[theRet insertObject:theAttribute atIndex:j];
			++j;
		}
	}
	return (NSArray *)theRet;
}

- (NSArray *) identityAttributes
{
	NSMutableArray		*theRet = [NSMutableArray array];
	unsigned int		i, j;
	
	j = 0;
	for (i=0; i != [self countOfAttributes]; ++i) {
		MCPAttribute	*theAttribute = (MCPAttribute *)[self objectInAttributesAtIndex:i];
		
		if ([theAttribute isPartOfIdentity]) {
			[theRet insertObject:theAttribute atIndex:j];
			++j;
		}
	}
	return (NSArray *)theRet;
}

- (MCPAttribute *) attributeWithName: (NSString *) iName
{
// This type of implementation is NOT working : most likely the isEqual method is called on iName rather than on the objects of the array
/*
	unsigned int		index = [self indexOfAttribute:iName];

	return (NSNotFound != index) ? (MCPAttribute *)[self objectInAttributesAtIndex:index] : nil ;
*/
	unsigned int		i;
	
	for (i = 0; [attributes count] != i; ++i) {
		if ([[(MCPAttribute *)[attributes objectAtIndex:i] name] isEqualToString:iName]) {
			return (MCPAttribute *)[attributes objectAtIndex:i];
		}
	}
	return nil;
}

- (MCPRelation *) relationWithName:(NSString *) iRelationName
{
// This type of implementation is NOT working : most likely the isEqual method is called on iName rather than on the objects of the array
/*	unsigned int		index = [relations indexOfObject:iRelationName];
	
	return (NSNotFound != index) ? (MCPRelation *)[relations objectAtIndex:index] : nil;
*/
	unsigned int		i;

	for (i = 0; [relations count] != i; ++i) {
		if ([[(MCPRelation *)[relations objectAtIndex:i] name] isEqualToString:iRelationName]) {
			return (MCPRelation *)[relations objectAtIndex:i];
		}
	}
	return nil;
}

- (BOOL) singleIntAutoGenKey
{
	NSArray		*theKeys = [self primaryKeyAttributes];

	if (1 == [theKeys count]) {
		MCPAttribute		*theSingleKey = (MCPAttribute *)[theKeys objectAtIndex:0];

		return [theSingleKey autoGenerated] && [[theSingleKey externalType] isEqualToString:@"INT"];
	}
	return NO;
}

@end
