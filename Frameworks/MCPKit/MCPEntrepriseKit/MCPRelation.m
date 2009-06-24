//
//  $Id$
//
//  MCPRelation.m
//  MCPKit
//
//  Created by Serge Cohen (serge.cohen@m4x.org) on 11/08/04.
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

#import "MCPRelation.h"
#import "MCPRelation+Private.h"

#import "MCPEntrepriseNotifications.h"

#import "MCPModel.h"
#import "MCPClassDescription.h"
#import "MCPClassDescription+Private.h"
#import "MCPAttribute.h"

#import "MCPJoin.h"

static NSArray *MCPexistingDeleteRules;

@implementation MCPRelation

#pragma mark Class methods
+ (void) initialize
{
	if (self = [MCPRelation class]) {
		NSMutableArray		*theExistingDeleteRules = [[NSMutableArray alloc] init];

		[self setVersion:010101]; // Ma.Mi.Re -> MaMiRe

		[theExistingDeleteRules addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:OnDeleteNullify], @"tag", @"Nullify", @"name", nil]];
		[theExistingDeleteRules addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:OnDeleteDeny], @"tag", @"Deny", @"name", nil]];
		[theExistingDeleteRules addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:OnDeleteCascade], @"tag", @"Cascade", @"name", nil]];
		[theExistingDeleteRules addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:OnDeleteDefault], @"tag", @"Default", @"name", nil]];
		[theExistingDeleteRules addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:OnDeleteNoAction], @"tag", @"No Action", @"name", nil]];
		MCPexistingDeleteRules = [[NSArray alloc] initWithArray:theExistingDeleteRules];
		[theExistingDeleteRules release];
	}
	return;
}

+ (NSArray *) existingDeleteRules
{
	return MCPexistingDeleteRules;
}

- (NSArray *) existingDeleteRules
{
	return [MCPRelation existingDeleteRules];	
}


#pragma mark Life cycle
- (id) initWithName:(NSString *) iName from:(MCPClassDescription *) iFrom to:(MCPClassDescription *) iTo
{
	self = [super init];
	if (self) {
		[self setName:iName];
		[self setOrigin:iFrom];
		[self setDestination:iTo];
		joins = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void) invalidateRelation
{
	[self retain]; // To be sure not to be released before the end of the method
	[self invalidateJoins]; // Remove each of the joins (so that attributes get notified)
/*
	[origin removeObjectFromRelationsAtIndex:[[origin relations] indexOfObjectIdenticalTo:self]];
	origin = nil;
	[destination removeObjectFromIncomingsAtIndex:[[destination incomings] indexOfObjectIdenticalTo:self]];
	destination = nil;
*/
	[self setOrigin:nil];
	[self setDestination:nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:MCPRelationChangedNotification object:self];			
	[self release];
}

- (void) dealloc
{
	[joins release]; // Should be empty by now...
	[name release];
// The inverse relation don't have an inverse relation any more...
//	[inverseRelation setInverseRelation:nil];
	[self setInverseRelation:nil];
// Other are weak references.
	[super dealloc];
}

#pragma mark NSCoding protocol
- (id) initWithCoder:(NSCoder *) decoder
{
	self = [super init];
	if ((self) && ([decoder allowsKeyedCoding])) {
		[self setName:[decoder decodeObjectForKey:@"MCPname"]];
		[self setDeleteRule:(MCPRelationDeleteRule)[decoder decodeInt32ForKey:@"MCPdeleteRule"]];
		if ([decoder containsValueForKey:@"MCPinverseRelation"]) {
			[self setInverseRelation:[decoder decodeObjectForKey:@"MCPinverseRelation"]];
		}
		else {
			[self setInverseRelation:nil];
		}
		[self setOrigin:[decoder decodeObjectForKey:@"MCPorigin"]];
		[self setDestination:[decoder decodeObjectForKey:@"MCPdestination"]];
//		[self setJoins:[decoder decodeObjectForKey:@"MCPjoins"]];
		joins = [[NSMutableArray alloc] initWithArray:[decoder decodeObjectForKey:@"MCPjoins"]];
		[self setIsToMany:[decoder decodeBoolForKey:@"MCPisToMany"]];
		[self setIsMandatory:[decoder decodeBoolForKey:@"MCPisMandatory"]];
		[self setOwnsDestintation:[decoder decodeBoolForKey:@"MCPownsDestination"]];
	}

	return self;
}

- (void) encodeWithCoder:(NSCoder *) encoder
{
	if (! [encoder allowsKeyedCoding]) {
		NSLog(@"In MCPRelation -encodeWithCoder : Unable to encode to a non-keyed encoder!!, will not perform encoding!!");
		return;
	}
	[encoder encodeObject:[self name] forKey:@"MCPname"];
	[encoder encodeInt32:(int32_t)[self deleteRule] forKey:@"MCPdeleteRule"];
	if ([self inverseRelation]) {
		[encoder encodeObject:[self inverseRelation] forKey:@"MCPinverseRelation"];
	}
	[encoder encodeObject:[self origin] forKey:@"MCPorigin"];
	[encoder encodeObject:[self destination] forKey:@"MCPdestination"];
	[encoder encodeObject:[self joins] forKey:@"MCPjoins"];
	[encoder encodeBool:[self isToMany] forKey:@"MCPisToMany"];
	[encoder encodeBool:[self isMandatory] forKey:@"MCPisMandatory"];
	[encoder encodeBool:[self ownsDestination] forKey:@"MCPownsDestination"];
}

#pragma mark Making new joins
/*
- (MCPJoin *) addNewJoin // Usefull for the interface, to be able to create a new join by just using a binding.
{
	[self addJoinFrom:[origin objectInAttributesAtIndex:0] to:[destination objectInAttributesAtIndex:0]];
}
*/

- (MCPJoin *) addJoinFrom:(MCPAttribute *) iFrom to:(MCPAttribute *) iTo
{
	MCPJoin      *theJoin;
	
	if ([iFrom classDescription] != [self origin]) {
		NSLog(@"Tried to make a join starting from an attribute (%@) that does NOT belong to the origin class description (%@)! Will not perform the link", iFrom, [self origin]);
		return nil;
	}
	if ([iTo classDescription] != [self destination]) {
		NSLog(@"Tried to make a join arriving to an attribute (%@) that does NOT belong to the destination class description (%@)! Will not perform the link", iTo, [self destination]);
		return nil;
	}
	theJoin = [[MCPJoin alloc] initForRelation:self from:iFrom to:iTo];
//	theJoin = [[MCPJoin alloc] initFrom:iFrom to:iTo];
//	[joins addObject:theJoin];
	[joins insertObject:theJoin atIndex:[joins count]];
	[theJoin release];
	[[NSNotificationCenter defaultCenter] postNotificationName:MCPRelationChangedNotification object:self];
	return theJoin;
}

- (void) removeJoinFrom:(MCPAttribute *) iFrom to:(MCPAttribute *) iTo
{
	NSDictionary		*theJoinDict = [[NSDictionary alloc] initWithObjectsAndKeys:self, @"relation", iFrom, @"origin", iTo, @"destination", nil];
	unsigned int      i = [joins indexOfObject:theJoinDict];
	
	if (NSNotFound != i) {
		[[self objectInJoinsAtIndex:i] invalidate];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPRelationChangedNotification object:self];
	}
	[theJoinDict release];
}

/*
- (void) unjoinAttribute:(MCPAttribute *) iAttribute
{
	unsigned int        i = 0;

#warning HAVE to rewrite this code!!!
	if ([[iAttribute classDescription] isEqual:origin]) {
		for (i=0; ([joins count] != i) && ([iAttribute isEqual:[(MCPJoin *)[joins objectAtIndex:i] origin]]); ++i) {
		}
	}
	if ([[iAttribute classDescription] isEqual:destination]) {
		for (i=0; ([joins count] != i) && ([iAttribute isEqual:[(MCPJoin *)[joins objectAtIndex:i] destination]]); ++i) {
		}
	}
	if ((0 == i) || ([joins count] == i)) { // No joins found using this attribute.
		return;
	}
	[self removeJoinFrom:[(MCPJoin *)[joins objectAtIndex:i] origin] to:[(MCPJoin *)[joins objectAtIndex:i] destination]];
}
*/

#pragma mark Setters
- (void) setDestination:(MCPClassDescription *) iDestination
{
	if (iDestination != destination) {
		[destination removeObjectFromIncomingsAtIndex:[[destination incomings] indexOfObjectIdenticalTo:self]];
		destination = iDestination;
		[destination insertObject:self inIncomingsAtIndex:0];
		[self invalidateJoins];
	}
}


- (void) setName:(NSString *) iName
{
	if (iName !=  name) {
		[name release];
		name = [iName retain];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPModelChangedNotification object:[origin model]];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPClassDescriptionChangedNotification object:origin];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPRelationChangedNotification object:self];
	}
}

- (void) setDeleteRule:(MCPRelationDeleteRule) iDeleteRule
{
	if (iDeleteRule != deleteRule) { // Don't do the notification for nothing!!!
		deleteRule = iDeleteRule;
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPModelChangedNotification object:[origin model]];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPClassDescriptionChangedNotification object:origin];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPRelationChangedNotification object:self];
	}
}

- (void) setInverseRelation:(MCPRelation *) iInverseRelation
{
	if (iInverseRelation != inverseRelation) {
		[inverseRelation release];
		inverseRelation = [iInverseRelation retain];
		[inverseRelation setInverseRelation:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPModelChangedNotification object:[origin model]];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPClassDescriptionChangedNotification object:origin];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPRelationChangedNotification object:self];
	}
}

- (void) insertObject:(MCPJoin *) iJoin inJoinsAtIndex:(unsigned int) index
{
	[joins insertObject:iJoin atIndex:index];
}

- (void) removeObjectFromJoinsAtIndex:(unsigned int) index
{
	[joins removeObjectAtIndex:index];
}

- (void) setIsToMany:(BOOL) iIsToMany
{
	if (iIsToMany != isToMany) { // Don't do the notification for nothing!!!
		isToMany = iIsToMany;
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPModelChangedNotification object:[origin model]];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPClassDescriptionChangedNotification object:origin];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPRelationChangedNotification object:self];
	}
}

- (void) setIsMandatory:(BOOL) iIsMandatory
{
	if (iIsMandatory != isMandatory) { // Don't do the notification for nothing!!!
		isMandatory = iIsMandatory;
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPModelChangedNotification object:[origin model]];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPClassDescriptionChangedNotification object:origin];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPRelationChangedNotification object:self];
	}
}

- (void) setOwnsDestintation:(BOOL) iOwnsDestination
{
	if (iOwnsDestination != ownsDestination) { // Don't do the notification for nothing!!!
		ownsDestination = iOwnsDestination;
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPModelChangedNotification object:[origin model]];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPClassDescriptionChangedNotification object:origin];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPRelationChangedNotification object:self];
	}
}

#pragma mark Getters
- (NSString *) name
{
	return name;
}

- (MCPRelationDeleteRule) deleteRule
{
	return deleteRule;
}

- (MCPRelation *) inverseRelation
{
	return inverseRelation;
}

- (MCPClassDescription *) origin
{
	return origin;
}

- (MCPClassDescription *) destination
{
	return destination;
}

- (NSArray *) joins
{
	return [NSArray arrayWithArray:joins];
}

- (unsigned int) countOfJoins
{
	return [joins count];
}

- (MCPJoin *) objectInJoinsAtIndex:(unsigned int) index
{
	return (MCPJoin *)((NSNotFound != index) ? [joins objectAtIndex:index] : nil);
}

- (unsigned int) indexOfJoinIdenticalTo:(id) iJoin
{
	return [joins indexOfObjectIdenticalTo:iJoin];
}

- (BOOL) isToMany
{
	return isToMany;
}

- (BOOL) isMandatory
{
	return isMandatory;
}

- (BOOL) ownsDestination
{
	return ownsDestination;
}

#pragma mark Some Usefull methods

- (MCPAttribute *) destinationAttributeForOrigin:(MCPAttribute *) iFrom
{
	unsigned int      i;
	
	for (i=0; ([joins count] != i) && ([[(MCPJoin *)[joins objectAtIndex:i] origin] isEqual:iFrom]); ++i) {
	}
	return ([joins count] == i) ? nil : [(MCPJoin *)[joins objectAtIndex:i] destination];
}

- (MCPAttribute *) originAttributeForDestination:(MCPAttribute *) iTo
{
	unsigned int      i;
	
	for (i=0; ([joins count] != i) && ([[(MCPJoin *)[joins objectAtIndex:i] destination] isEqual:iTo]); ++i) {
	}
	return ([joins count] == i) ? nil : [(MCPJoin *)[joins objectAtIndex:i] origin];
}


#pragma mark Some general methods:
- (BOOL) isEqual:(id) iObject
// Equal to another relation, if they have the same name and same origin and destination class descriptions (they have the same names).
// Equal to a string (NSString), if the name of the relation is equal to the string.
{
	if ([iObject isKindOfClass:[MCPRelation class]]) {
		MCPRelation     *theRelation = (MCPRelation *) iObject;
		
		return ([name isEqualToString:[theRelation name]]) && ([[self origin] isEqual:[theRelation origin]]) && ([[self destination] isEqual:[theRelation destination]]);
	}
	if ([iObject isKindOfClass:[NSString class]]) {
		return [name isEqualToString:(NSString *)iObject];
	}
	return NO;
}

- (NSString *) descriptionWithLocale:(NSDictionary *) locale
{
	NSMutableString		*theRet = [NSMutableString stringWithFormat:@"MCPRelation named %@, going from %@ to %@. Joins :\n", name, [origin name], [destination name]];
	unsigned int			i;

	for (i = 0; [joins count] != i; ++i) {
		MCPJoin			*tmpJoin = (MCPJoin *)[joins objectAtIndex:i];
		[theRet appendFormat:@"\t\t%@ == %@\n", [[tmpJoin origin] name], [[tmpJoin destination] name]];
	}
	return theRet;
}


#pragma mark For debugging the retain counting
- (id) retain
{
	[super retain];
	return self;
}

- (void) release
{
	[super release];
	return;
}

@end

@implementation MCPRelation (Private)

#pragma mark Making some work
- (void) invalidateJoins
{
	while ([joins count]) {
		[[self objectInJoinsAtIndex:0] invalidate];
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:MCPRelationChangedNotification object:self];
}

#pragma mark Setters
- (void) setOrigin:(MCPClassDescription *) iOrigin
{
	if (iOrigin != origin) {
		[origin removeObjectFromRelationsAtIndex:[[origin relations] indexOfObjectIdenticalTo:self]];
		origin = iOrigin;
		[origin insertObject:self inRelationsAtIndex:[origin countOfRelations]];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPRelationChangedNotification object:self];
		[self invalidateJoins];
	}
}

/*
- (void) setJoins:(NSArray *) iJoins
{
	if (iJoins != joins) {
		unsigned int      i;
		if (joins) {
			[self invalidateJoins];
		}
		else {
			joins = [[NSMutableArray alloc] init];
		}
		for (i=0; [iJoins count] != i; ++i) {
			[self addJoinFrom:[(MCPJoin *)[iJoins objectAtIndex:i] origin] to:[(MCPJoin *)[iJoins objectAtIndex:i] destination]];
		}
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPRelationChangedNotification object:self];
	}
}
*/

#pragma mark Getters
- (MCPModel *) model
{
	return [origin model];
}

#pragma mark Fro the controller layer and the UI
- (void) addNewDefaultJoin   // Usefull for the interface, to be able to create a new join by just using a binding.
{
	[self addJoinFrom:[origin objectInAttributesAtIndex:0] to:[destination objectInAttributesAtIndex:0]];
}

@end
