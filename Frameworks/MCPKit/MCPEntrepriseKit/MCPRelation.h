//
//  $Id: MCPRelation.h 545 2009-04-10 14:49:45Z stuart02 $
//
//  MCPRelation.h
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

#import <Foundation/Foundation.h>

@class MCPModel;
@class MCPClassDescription;
@class MCPAttribute;
@class MCPJoin;

typedef enum {
	OnDeleteNullify = 1,
	OnDeleteDeny = 2,
	OnDeleteCascade = 3,
	OnDeleteDefault = 4,
	OnDeleteNoAction = 5
} MCPRelationDeleteRule;

@interface MCPRelation : NSObject <NSCoding> 
{
@protected
	NSString			  *name;            // Name of the relation
	MCPRelationDeleteRule deleteRule;       // Delete rule : what to do of the destination when origin is deleted
	MCPRelation			  *inverseRelation; // The inverse relation (or nil if no inverse present)
	MCPClassDescription	  *origin;          // The class description from which the relation originate
	MCPClassDescription	  *destination;     // The class description to which the relation arrives
	NSMutableArray		  *joins;			// Joining attributes (array of MCPJoin)
	BOOL				  isToMany;         // Is the relation to many (or to one)
	BOOL				  isMandatory;      // Is the relation mandatory for the class description (origin)
	BOOL				  ownsDestination;  // The origin class description owns the destination class description(ies)
}

#pragma mark Class methods
+ (void) initialize;

+ (NSArray *) existingDeleteRules;
- (NSArray *) existingDeleteRules;

#pragma mark Life cycle
- (id) initWithName:(NSString *) iName from:(MCPClassDescription *) iFrom to:(MCPClassDescription *) iTo;
- (void) invalidateRelation;
- (void) dealloc;

#pragma mark NSCoding protocol
- (id) initWithCoder:(NSCoder *) decoder;
- (void) encodeWithCoder:(NSCoder *) encoder;

#pragma mark Managing joins
//- (MCPJoin *) addNewJoin;
- (MCPJoin *) addJoinFrom:(MCPAttribute *) iFrom to:(MCPAttribute *) iTo;
- (void) removeJoinFrom:(MCPAttribute *) iFrom to:(MCPAttribute *) iTo;
//- (void) unjoinAttribute:(MCPAttribute *) iAttribute;

#pragma mark Setters
- (void) setDestination:(MCPClassDescription *) iDestination;
- (void) setName:(NSString *) iName;
- (void) setDeleteRule:(MCPRelationDeleteRule) iDeleteRule;
- (void) setInverseRelation:(MCPRelation *) iInverseRelation;
- (void) insertObject:(MCPJoin *) iJoin inJoinsAtIndex:(unsigned int) index;
- (void) removeObjectFromJoinsAtIndex:(unsigned int) index;
- (void) setIsToMany:(BOOL) iIsToMany;
- (void) setIsMandatory:(BOOL) iIsMandatory;
- (void) setOwnsDestintation:(BOOL) iOwnsDestination;

#pragma mark Getters
- (NSString *) name;
- (MCPRelationDeleteRule) deleteRule;
- (MCPRelation *) inverseRelation;
- (MCPClassDescription *) origin;
- (MCPClassDescription *) destination;
- (NSArray *) joins;
- (unsigned int) countOfJoins;
- (MCPJoin *) objectInJoinsAtIndex:(unsigned int) index;
- (unsigned int) indexOfJoinIdenticalTo:(id) iJoin;
- (BOOL) isToMany;
- (BOOL) isMandatory;
- (BOOL) ownsDestination;

#pragma mark Some Usefull methods
- (MCPAttribute *) destinationAttributeForOrigin:(MCPAttribute *) iFrom;
- (MCPAttribute *) originAttributeForDestination:(MCPAttribute *) iTo;

#pragma mark Some general methods:
- (BOOL) isEqual:(id) iObject;
- (NSString *) descriptionWithLocale:(NSDictionary *) locale;

@end
