//
//  $Id: MCPModel.h 545 2009-04-10 14:49:45Z stuart02 $
//
//  MCPModel.h
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

@class MCPClassDescription;
@class MCPAttribute;
@class MCPRelation;

@interface MCPModel : NSObject <NSCoding> 
{
@protected
	NSString	   *name;			   // Name of the model ... useless.
	NSMutableArray *classDescriptions; // Order of the class descriptions in the model.
	BOOL			usesInnoDBTables;  // The database should use InnoDB tables.
	// Might add a string holding définition of tables.
	// Might also add some sort of template for generated files (at least the header).
}

#pragma mark Class methods
+ (void) initialize;

#pragma mark Life cycle
- (id) initWithName:(NSString *) iName;
- (void) dealloc;

#pragma mark NSCoding protocol
- (id) initWithCoder:(NSCoder *) decoder;
- (void) encodeWithCoder:(NSCoder *) encoder;

#pragma mark Making new class description
- (MCPClassDescription *) addNewClassDescriptionWithName:(NSString *) iName inPosition:(int) index;

#pragma mark Setters
- (void) setName:(NSString *) iName;
- (void) setClassDescriptions:(NSArray *) iClassDescriptions;
- (void) insertObject:(MCPClassDescription *) iClassDescription inClassDescriptionsAtIndex:(unsigned int) index;
- (void) removeObjectFromClassDescriptionsAtIndex:(unsigned int) index;
- (void) setUsesInnoDBTables:(BOOL) iUsesInnoDB;

// Deprecated : non KVC
//- (void) removeClassDescription:(MCPClassDescription *) iClassDescription;
//- (void) addClassDescription:(MCPClassDescription *) iClassDescription;

#pragma mark Getters
- (NSString *) name;
- (NSArray *) classDescriptions;
- (unsigned int) countOfClassDescriptions;
- (MCPClassDescription *) objectInClassDescriptionsAtIndex:(unsigned int) index;
- (unsigned int) indexOfClassDescription:(id) iClassDescription;
- (BOOL) usesInnoDBTables;

// Deprecated : non KVC
//- (MCPClassDescription *) classDescriptionWithClassName:(NSString *) iClassDescriptionClassName;

#pragma mark Output for logging
- (NSString *) descriptionWithLocale:(NSDictionary *) locale;

@end
