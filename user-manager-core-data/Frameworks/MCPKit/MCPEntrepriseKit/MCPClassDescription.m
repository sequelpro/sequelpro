//
//  $Id$
//
//  MCPClassDescription.m
//  MCPKit
//
//  Created by Serge Cohen (serge.cohen@m4x.org) on 09/08/04.
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

#import "MCPClassDescription.h"
#import "MCPClassDescription+Private.h"

#import "MCPEntrepriseNotifications.h"

#import "MCPModel.h"
#import "MCPAttribute.h"
#import "MCPRelation.h"

@implementation MCPClassDescription

#pragma mark Class methods
+ (void) initialize
{
	if (self = [MCPClassDescription class]) {
		[self setVersion:010101]; // Major.Minor.Revision -> MaMiRe
	}
	return;
}

#pragma mark Life cycle
- (id) initInModel:(MCPModel *) iModel withName:(NSString *) iName
{
	self = [super init];
	if (self) {
		model = iModel;
		[self setName:iName];
		attributes = [[NSMutableArray alloc] init];
		relations = [[NSMutableArray alloc] init];
		incomings = [[NSMutableArray alloc] init];
		representedClass = nil;
	//	NSLog(@"MAKING a new object : %@", self);
	}
	return self;
}

- (void) dealloc
{
//   NSArray        *theRelations;
//   unsigned int   i;
	
	[name release];
	[externalName release];
	[attributes release];
	while ([relations count]) {
		[(MCPRelation *)[relations objectAtIndex:0] invalidateRelation];
	}
	[relations  release];
	while ([incomings count]) {
		[(MCPRelation *)[incomings objectAtIndex:0] invalidateRelation];
	}
	[incomings release];
	[super dealloc];
}

#pragma mark NSCoding protocol
- (id) initWithCoder:(NSCoder *) decoder
{
	self = [super init];
	if ((self) && ([decoder allowsKeyedCoding])) {
		model = [decoder decodeObjectForKey:@"MCPmodel"];
//      NSLog(@"in MCPClassDescription initWithCoder, model = %@ (pointer = %p)", model, model);
		[self setName:[decoder decodeObjectForKey:@"MCPname"]];
		[self setExternalName:[decoder decodeObjectForKey:@"MCPexternalName"]];
		[self setAttributes:[decoder decodeObjectForKey:@"MCPattributes"]];
//		[self setRelations:[decoder decodeObjectForKey:@"MCPrelations"]];
		relations = [[NSMutableArray alloc] init];
		incomings = [[NSMutableArray alloc] init];
		representedClass = nil;
		[decoder decodeObjectForKey:@"MCPrelations"]; // The relation get linked properly while initted.
	}
	else {
		NSLog(@"For some reason, unable to decode MCPClassDescription from the coder!!!");
	}

	return self;
}

- (void) encodeWithCoder:(NSCoder *) encoder
{ 
	if (! [encoder allowsKeyedCoding]) {
		NSLog(@"In MCPClassDescription -encodeWithCoder : Unable to encode to a non-keyed encoder!!, will not perform encoding!!");
		return;
	}
//	[encoder encodeObject:[self model] forKey:@"MCPmodel"];
	[encoder encodeConditionalObject:[self model] forKey:@"MCPmodel"];
	[encoder encodeObject:[self name] forKey:@"MCPname"];
	[encoder encodeObject:[self externalName] forKey:@"MCPexternalName"];
	[encoder encodeObject:[self attributes] forKey:@"MCPattributes"];
	[encoder encodeObject:[self relations] forKey:@"MCPrelations"];
	[encoder encodeObject:@"1.1.1" forKey:@"MCPversion"];
	return;
}

#pragma mark Making new attributes and relations
- (MCPAttribute *) addNewAttributeWithName:(NSString *) iName inPosition:(int) index
{
	MCPAttribute			*theAttribute = [[MCPAttribute alloc] initForClassDescription:self withName:iName];
	
//	[self addAttribute:theAttribute];
	[self insertObject:theAttribute inAttributesAtIndex:(index < 0) ? ([self countOfAttributes] + index + 1) : index];
	[theAttribute release];
	return theAttribute;
}

- (MCPRelation *) addNewRelationTo:(MCPClassDescription *) iTo name:(NSString *) iName inPostion:(int) index
{
	MCPRelation	*theRelation = [[MCPRelation alloc] initWithName:iName from:self to:iTo];
	
	[theRelation release];
	return theRelation;
}

#pragma mark Setters
- (void) setName:(NSString *) iName
{
	if (iName != name) {
		[name release];
		name = [iName retain];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPModelChangedNotification object:model];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPClassDescriptionChangedNotification object:self];
		representedClass = nil;
	}
}

- (void) setExternalName:(NSString *) iExternalName
{
	if (iExternalName != externalName) {
		[externalName release];
		externalName = [iExternalName retain];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPModelChangedNotification object:model];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPClassDescriptionChangedNotification object:self];
	}
}

- (void) insertObject:(MCPAttribute *) iAttribute inAttributesAtIndex:(unsigned int) index
{
	[attributes insertObject:iAttribute atIndex:index];
	[[NSNotificationCenter defaultCenter] postNotificationName:MCPModelChangedNotification object:model];
	[[NSNotificationCenter defaultCenter] postNotificationName:MCPClassDescriptionChangedNotification object:self];
}

- (void) removeObjectFromAttributesAtIndex:(unsigned int) index
{
	[attributes removeObjectAtIndex:index];
	[[NSNotificationCenter defaultCenter] postNotificationName:MCPModelChangedNotification object:model];
	[[NSNotificationCenter defaultCenter] postNotificationName:MCPClassDescriptionChangedNotification object:self];
}

- (void) insertObject:(MCPRelation *) iRelation inRelationsAtIndex:(unsigned int) index
{
	[relations insertObject:iRelation atIndex:index];
	[[NSNotificationCenter defaultCenter] postNotificationName:MCPModelChangedNotification object:model];
	[[NSNotificationCenter defaultCenter] postNotificationName:MCPClassDescriptionChangedNotification object:self];
}

- (void) removeObjectFromRelationsAtIndex:(unsigned int) index
{
	[relations removeObjectAtIndex:index];
	[[NSNotificationCenter defaultCenter] postNotificationName:MCPModelChangedNotification object:model];
	[[NSNotificationCenter defaultCenter] postNotificationName:MCPClassDescriptionChangedNotification object:self];
}

#pragma mark Getters
- (MCPModel *) model
{
	return model;
}

- (NSString *) name
{
	return name;
}

- (NSString *) externalName
{
	return externalName;
}

- (NSArray *) attributes
{
	return [NSArray arrayWithArray:attributes];
}

- (unsigned int) countOfAttributes
{
	return [attributes count];
}

- (MCPAttribute *) objectInAttributesAtIndex:(unsigned int) index
{
	return (MCPAttribute *)((NSNotFound != index) ? [attributes objectAtIndex:index] : nil);
}

- (unsigned int) indexOfAttribute:(id) iAttribute
{
	return [attributes indexOfObject:iAttribute];
}

- (NSArray *) relations
{
	return [NSArray arrayWithArray:relations];
}

- (unsigned int) countOfRelations
{
	return [relations count];
}

- (MCPRelation *) objectInRelationsAtIndex:(unsigned int) index
{
	return (MCPRelation *)((NSNotFound != index) ? [relations objectAtIndex:index] : nil);
}

- (unsigned int) indexOfRelation:(id) iRelation
{
	return [relations indexOfObject:iRelation];
}

- (Class) representedClass
{
	if (representedClass) {
		return representedClass;
	}
	representedClass = NSClassFromString(name);
	return representedClass;
}

#pragma mark Some general methods:
- (BOOL) isEqual:(id) iObject
// Equal to another class description if they have the same name.
// Equal to a string if the string is equal to the className of the class description.
{
	if ([iObject isKindOfClass:[MCPClassDescription class]]) {
		return [name isEqualToString:[(MCPClassDescription *)iObject name]];
	}
	if ([iObject isKindOfClass:[NSString class]]) {
		return [name isEqualToString:(NSString *)iObject];
	}
	return NO;
}

/*
- (NSString *) description
{
	return [NSString stringWithFormat:@"<MCPClassDescription for class named %@ : %p>", [self name], self];
}

- (NSString *) descriptionWithLocale:(NSDictionary *) locale
{
	return [self description];
}
*/

#pragma mark Output for logging
- (NSString *) descriptionWithLocale:(NSDictionary *) locale
{
   NSMutableString         *theOutput = [NSMutableString string];
   unsigned                i;

   [theOutput appendFormat:@"MCPClassDescription for class : %@ (table : %@)\n", [self name], [self externalName]];
   for (i=0; [attributes count] != i; ++i) {
      MCPAttribute      *theAttribute = (MCPAttribute *) [attributes objectAtIndex:i];
		
      [theOutput appendFormat:@"attribute %u, name = %@, column = %@. Allows null : %c\n", i, [theAttribute name], [theAttribute externalName], ([theAttribute allowsNull] ? 'Y' : 'N')];
   }
   return theOutput;	
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

@implementation MCPClassDescription (Private)

#pragma mark Setters
- (void) setAttributes:(NSArray *) iAttributes
{
	if (iAttributes != attributes) {
		[attributes release];
		attributes = [[NSMutableArray alloc] initWithArray:iAttributes];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPModelChangedNotification object:model];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPClassDescriptionChangedNotification object:self];
	}
}

- (void) setRelations:(NSArray *) iRelations
{
	if (iRelations != relations) {
		[relations release];
		relations = [[NSMutableArray alloc] initWithArray:iRelations];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPModelChangedNotification object:model];
		[[NSNotificationCenter defaultCenter] postNotificationName:MCPClassDescriptionChangedNotification object:self];
	}
}

- (void) insertObject:(MCPRelation *) iRelation inIncomingsAtIndex:(unsigned int) index
{
	if ([iRelation destination] == self) {
		[incomings insertObject:iRelation atIndex:index];
	}
	else {
		NSLog(@"in -[MCPClassDescription+Private insertObject:inIncomingsAtIndex:]. ERRROR : self is NOT the destination of the relation");
	}
}

- (void) removeObjectFromIncomingsAtIndex:(unsigned int) index
{
	[incomings removeObjectAtIndex:index];
}

#pragma mark Getters
- (NSArray *) incomings
{
	return [NSArray arrayWithArray:incomings];
}

- (unsigned int) countOfIncomings
{
	return [incomings count];
}

- (MCPRelation *) objectInIncomingsAtIndex:(unsigned int) index
{
	return (MCPRelation *)[incomings objectAtIndex:index];
}

- (unsigned int) indexOfIncoming:(id) iRelation
{
	return [incomings indexOfObject:iRelation];
}

@end
