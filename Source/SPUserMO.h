//
//  $Id: SPUserMO.h 856 2009-06-12 05:31:39Z mltownsend $
//
//  SPUserMO.h
//  sequel-pro
//
//  Created by Mark Townsend on Jan 01, 2009
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

#import <CoreData/CoreData.h>

@interface NSManagedObject (CoreDataGeneratedAccessors)

@property (nonatomic, retain) NSString *user;
@property (nonatomic, retain) NSString *host;
@property (nonatomic, retain) NSManagedObject *parent;
@property (nonatomic, retain) NSSet *children;

- (NSString *)displayName;
- (void)setDisplayName:(NSString *)value;

// Access to-many relationship via -[NSObject mutableSetValueForKey:]
- (void)addChildrenObject:(NSManagedObject *)value;
- (void)removeChildrenObject:(NSManagedObject *)value;

@end