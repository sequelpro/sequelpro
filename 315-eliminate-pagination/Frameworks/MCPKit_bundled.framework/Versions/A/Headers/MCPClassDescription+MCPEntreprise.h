//
//  MCPClassDescription+MCPEntreprise.h
//  MCPModeler
//
//  Created by Serge Cohen (serge.cohen@m4x.org) on 01/11/04.
//  Copyright 2004 Serge Cohen. All rights reserved.
//
//  This code is free software; you can redistribute it and/or modify it under
//  the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or any later version.
//
//  This code is distributed in the hope that it will be useful, but WITHOUT ANY
//  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
//  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
//  details.
//
//  For a copy of the GNU General Public License, visit <http://www.gnu.org/> or
//  write to the Free Software Foundation, Inc., 59 Temple Place--Suite 330,
//  Boston, MA 02111-1307, USA.
//
//  More info at <http://mysql-cocoa.sourceforge.net/>
//

#import <Foundation/Foundation.h>
#import "MCPClassDescription.h"

@interface MCPClassDescription (MCPEntreprise)

#pragma mark Pseudo getters (for NSClassDescription overload)
- (NSArray *) attributeKeys;
- (NSString *) inverseRelationshipKey:(NSString *) relationshipKey;
- (NSArray *) toManyRelationshipKeys;
- (NSArray *) toOneRelationshipKeys;

#pragma mark Specifics for MCPObject
- (NSArray *) primaryKeyAttributes;
- (NSArray *) identityAttributes;
- (MCPAttribute *) attributeWithName: (NSString *) iName;
- (MCPRelation *) relationWithName:(NSString *) iRelationName;
- (BOOL) singleIntAutoGenKey;

@end
