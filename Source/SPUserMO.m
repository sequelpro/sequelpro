//
//  $Id: SPUserMO.m 856 2009-06-12 05:31:39Z mltownsend $
//
//  SPUserMO.m
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

#import "SPUserMO.h"

static NSString *SPUserMOParentKey   = @"parent";
static NSString *SPUserMOUserKey     = @"user";
static NSString *SPUserMOHostKey     = @"host";
static NSString *SPUserMOChildrenKey = @"children";

@implementation NSManagedObject (CoreDataGeneratedAccessors)

@dynamic user;
@dynamic host;
@dynamic parent;
@dynamic children;

- (NSString *)displayName
{
	return ([self valueForKey:SPUserMOParentKey] == nil) ? self.user : self.host;
}

- (void)setDisplayName:(NSString *)value
{
    if ([self valueForKey:SPUserMOParentKey] == nil) {
		[self setValue:value forKey:SPUserMOUserKey];
	}
    else
    {
		[self setValue:(value == nil) ? @"%" : value forKey:SPUserMOHostKey];
    }
}

- (void)addChildrenObject:(NSManagedObject *)value 
{    
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];

    [self willChangeValueForKey:SPUserMOChildrenKey withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    [[self primitiveValueForKey:SPUserMOChildrenKey] addObject:value];
    [self didChangeValueForKey:SPUserMOChildrenKey withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    
    [changedObjects release];
	
	value.user = self.user;
}

- (void)removeChildrenObject:(NSManagedObject *)value 
{
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:SPUserMOChildrenKey withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    [[self primitiveValueForKey:SPUserMOChildrenKey] removeObject:value];
    [self didChangeValueForKey:SPUserMOChildrenKey withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    
    [changedObjects release];
}

@end
