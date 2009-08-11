//
//  $Id$
//
//  MCPClassDescription.h
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

#import <Foundation/Foundation.h>

@class MCPModel;
@class MCPAttribute;
@class MCPRelation;
@class MCPRelation;

@interface MCPClassDescription : NSClassDescription <NSCoding> 
{
@protected
	MCPModel	   *model;			  // The model where we stand
	NSString	   *name;             // Name of the class (can not use className, as it is already used by NSObject).
	NSString       *externalName;     // Name of the table for storage
	NSMutableArray *attributes;       // array of the attributes of the class description
	NSMutableArray *relations;        // array of the relations of the class description (both origin and destination)
	NSMutableArray *incomings;		  // array if the INCOMMING relation (just to be sure we are able to invalidate those if necessary)
	Class			representedClass; // the class object that the description represents.
}

// This correspond to the method singleIntAutoGenKey in the category MCPEntreprise... which name should I change...

#pragma mark Class methods
+ (void) initialize;

#pragma mark Life cycle
- (id) initInModel:(MCPModel *) iModel withName:(NSString *) iName;
- (void) dealloc;

#pragma mark NSCoding protocol
- (id) initWithCoder:(NSCoder *) decoder;
- (void) encodeWithCoder:(NSCoder *) encoder;

#pragma mark Making new attributes and relations
- (MCPAttribute *) addNewAttributeWithName:(NSString *) iName inPosition:(int) index;
- (MCPRelation *) addNewRelationTo:(MCPClassDescription *) iTo name:(NSString *) iName inPostion:(int) index;

#pragma mark Setters
- (void) setName:(NSString *) iName;
- (void) setExternalName:(NSString *) iExternalName;
- (void) insertObject:(MCPAttribute *) iAttribute inAttributesAtIndex:(unsigned int) index;
- (void) removeObjectFromAttributesAtIndex:(unsigned int) index;
- (void) insertObject:(MCPRelation *) iRelation inRelationsAtIndex:(unsigned int) index;
- (void) removeObjectFromRelationsAtIndex:(unsigned int) index;

#pragma mark Getters
- (MCPModel *) model;
- (NSString *) name;
- (NSString *) externalName;
- (NSArray *) attributes;
- (unsigned int) countOfAttributes;
- (MCPAttribute *) objectInAttributesAtIndex:(unsigned int) index;
- (unsigned int) indexOfAttribute:(id) iAttribute;
- (NSArray *) relations;
- (unsigned int) countOfRelations;
- (MCPRelation *) objectInRelationsAtIndex:(unsigned int) index;
- (unsigned int) indexOfRelation:(id) iRelation;
- (Class) representedClass;

#pragma mark Some general methods:
- (BOOL) isEqual:(id) iObject;

#pragma mark Output for logging
- (NSString *) descriptionWithLocale:(NSDictionary *) locale;

@end
