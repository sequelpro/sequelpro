//
//  $Id$
//
//  MCPClassDescription+Private.h
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

@interface MCPClassDescription (Private)

#pragma mark Setters
- (void) setAttributes:(NSArray *) iAttributes;
- (void) setRelations:(NSArray *) iRelations;
- (void) insertObject:(MCPRelation *) iRelation inIncomingsAtIndex:(NSUInteger) index;
- (void) removeObjectFromIncomingsAtIndex:(NSUInteger) index;

#pragma mark Getters
- (NSArray *) incomings;
- (NSUInteger) countOfIncomings;
- (MCPRelation *) objectInIncomingsAtIndex:(NSUInteger) index;
- (NSUInteger) indexOfIncoming:(id) iRelation;

@end
