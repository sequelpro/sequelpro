//
//  $Id$
//
//  MCPJoin.h
//  MCPKit
//
//  Created by Serge Cohen (serge.cohen@m4x.org) on 18/08/04.
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
@class MCPRelation;
@class MCPRelation;

@interface MCPJoin : NSObject <NSCoding> 
{
@protected
	// Note that NONE of these attributes are retained!!!
	// Instead all these objects are notified of the existence of the join
	// and are responsible to invalidate/delete it if necessary.
	MCPRelation  *relation;
	MCPAttribute *origin;
	MCPAttribute *destination;
}

#pragma mark Class methods
+ (void) initialize;

#pragma mark Life cycle
- (id) initForRelation:(MCPRelation *) iRelation from:(MCPAttribute *) iOrigin to:(MCPAttribute *) iDestination;
- (void) invalidate;
- (void) dealloc;

#pragma mark NSCoding protocol
- (id) initWithCoder:(NSCoder *) decoder;
- (void) encodeWithCoder:(NSCoder *) encoder;

#pragma mark Setters
// No setter for relation : should be set at init time!
- (void) setOrigin:(MCPAttribute *) iOrigin;
- (void) setDestination:(MCPAttribute *) iDestination;

#pragma mark Getters
- (MCPRelation *) relation;
- (MCPAttribute *) origin;
- (MCPAttribute *) destination;
- (unsigned int) index;

#pragma mark Some general methods:
- (BOOL) isEqual:(id) iObject;

@end
