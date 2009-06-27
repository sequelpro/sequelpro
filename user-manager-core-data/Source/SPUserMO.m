#import "SPUserMO.h"

@implementation NSManagedObject (CoreDataGeneratedAccessors)

@dynamic user, host;
@dynamic parent;

- (NSString *)displayName
{
	if ([self valueForKey:@"parent"] == nil) {
		return [self valueForKey:@"user"];
	} else {
		return [self valueForKey:@"host"];
	}
}

- (void)setDisplayName:(NSString *)value
{
	[self setValue:value forKey:@"host"];
}

- (void)addChildrenObject:(NSManagedObject *)value 
{    
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:@"children" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    [[self primitiveValueForKey:@"children"] addObject:value];
    [self didChangeValueForKey:@"children" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    
    [changedObjects release];
}

- (void)removeChildrenObject:(NSManagedObject *)value 
{
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    
    [self willChangeValueForKey:@"children" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    [[self primitiveValueForKey:@"children"] removeObject:value];
    [self didChangeValueForKey:@"children" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    
    [changedObjects release];
}


@end



