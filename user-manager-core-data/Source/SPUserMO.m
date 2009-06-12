#import "SPUserMO.h"

@implementation NSManagedObject (CoreDataGeneratedAccessors)

- (NSString *)displayName
{
	if ([self parent] == nil) {
		return [self username];
	} else {
		return [self host];
	}
}

- (void)setDisplayName:(NSString *)value
{
	[self setHost:value];
}

- (NSNumber *)create_priv 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey:@"create_priv"];
    tmpValue = [self primitiveValueForKey:@"create_priv"];
    [self didAccessValueForKey:@"create_priv"];
    
    return tmpValue;
}

- (void)setCreate_priv:(NSNumber *)value 
{
    [self willChangeValueForKey:@"create_priv"];
    [self setPrimitiveValue:value forKey:@"create_priv"];
    [self didChangeValueForKey:@"create_priv"];
}

- (BOOL)validateCreate_priv:(id *)valueRef error:(NSError **)outError 
{
    // Insert custom validation logic here.
    return YES;
}

- (NSNumber *)delete_priv 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey:@"delete_priv"];
    tmpValue = [self primitiveValueForKey:@"delete_priv"];
    [self didAccessValueForKey:@"delete_priv"];
    
    return tmpValue;
}

- (void)setDelete_priv:(NSNumber *)value 
{
    [self willChangeValueForKey:@"delete_priv"];
    [self setPrimitiveValue:value forKey:@"delete_priv"];
    [self didChangeValueForKey:@"delete_priv"];
}

- (BOOL)validateDelete_priv:(id *)valueRef error:(NSError **)outError 
{
    // Insert custom validation logic here.
    return YES;
}

- (NSNumber *)drop_priv 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey:@"drop_priv"];
    tmpValue = [self primitiveValueForKey:@"drop_priv"];
    [self didAccessValueForKey:@"drop_priv"];
    
    return tmpValue;
}

- (void)setDrop_priv:(NSNumber *)value 
{
    [self willChangeValueForKey:@"drop_priv"];
    [self setPrimitiveValue:value forKey:@"drop_priv"];
    [self didChangeValueForKey:@"drop_priv"];
}

- (BOOL)validateDrop_priv:(id *)valueRef error:(NSError **)outError 
{
    // Insert custom validation logic here.
    return YES;
}

- (NSString *)host 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey:@"host"];
    tmpValue = [self primitiveValueForKey:@"host"];
    [self didAccessValueForKey:@"host"];
    
    return tmpValue;
}

- (void)setHost:(NSString *)value 
{
    [self willChangeValueForKey:@"host"];
    [self setPrimitiveValue:value forKey:@"host"];
    [self didChangeValueForKey:@"host"];
}

- (BOOL)validateHost:(id *)valueRef error:(NSError **)outError 
{
    // Insert custom validation logic here.
    return YES;
}

- (NSNumber *)insert_priv 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey:@"insert_priv"];
    tmpValue = [self primitiveValueForKey:@"insert_priv"];
    [self didAccessValueForKey:@"insert_priv"];
    
    return tmpValue;
}

- (void)setInsert_priv:(NSNumber *)value 
{
    [self willChangeValueForKey:@"insert_priv"];
    [self setPrimitiveValue:value forKey:@"insert_priv"];
    [self didChangeValueForKey:@"insert_priv"];
}

- (BOOL)validateInsert_priv:(id *)valueRef error:(NSError **)outError 
{
    // Insert custom validation logic here.
    return YES;
}

- (NSNumber *)maxConnections 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey:@"maxConnections"];
    tmpValue = [self primitiveValueForKey:@"maxConnections"];
    [self didAccessValueForKey:@"maxConnections"];
    
    return tmpValue;
}

- (void)setMaxConnections:(NSNumber *)value 
{
    [self willChangeValueForKey:@"maxConnections"];
    [self setPrimitiveValue:value forKey:@"maxConnections"];
    [self didChangeValueForKey:@"maxConnections"];
}

- (BOOL)validateMaxConnections:(id *)valueRef error:(NSError **)outError 
{
    // Insert custom validation logic here.
    return YES;
}

- (NSNumber *)maxQuestions 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey:@"maxQuestions"];
    tmpValue = [self primitiveValueForKey:@"maxQuestions"];
    [self didAccessValueForKey:@"maxQuestions"];
    
    return tmpValue;
}

- (void)setMaxQuestions:(NSNumber *)value 
{
    [self willChangeValueForKey:@"maxQuestions"];
    [self setPrimitiveValue:value forKey:@"maxQuestions"];
    [self didChangeValueForKey:@"maxQuestions"];
}

- (BOOL)validateMaxQuestions:(id *)valueRef error:(NSError **)outError 
{
    // Insert custom validation logic here.
    return YES;
}

- (NSNumber *)maxUserConnections 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey:@"maxUserConnections"];
    tmpValue = [self primitiveValueForKey:@"maxUserConnections"];
    [self didAccessValueForKey:@"maxUserConnections"];
    
    return tmpValue;
}

- (void)setMaxUserConnections:(NSNumber *)value 
{
    [self willChangeValueForKey:@"maxUserConnections"];
    [self setPrimitiveValue:value forKey:@"maxUserConnections"];
    [self didChangeValueForKey:@"maxUserConnections"];
}

- (BOOL)validateMaxUserConnections:(id *)valueRef error:(NSError **)outError 
{
    // Insert custom validation logic here.
    return YES;
}

- (NSString *)password 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey:@"password"];
    tmpValue = [self primitiveValueForKey:@"password"];
    [self didAccessValueForKey:@"password"];
    
    return tmpValue;
}

- (void)setPassword:(NSString *)value 
{
    [self willChangeValueForKey:@"password"];
    [self setPrimitiveValue:value forKey:@"password"];
    [self didChangeValueForKey:@"password"];
}

- (BOOL)validatePassword:(id *)valueRef error:(NSError **)outError 
{
    // Insert custom validation logic here.
    return YES;
}

- (NSNumber *)reload_priv 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey:@"reload_priv"];
    tmpValue = [self primitiveValueForKey:@"reload_priv"];
    [self didAccessValueForKey:@"reload_priv"];
    
    return tmpValue;
}

- (void)setReload_priv:(NSNumber *)value 
{
    [self willChangeValueForKey:@"reload_priv"];
    [self setPrimitiveValue:value forKey:@"reload_priv"];
    [self didChangeValueForKey:@"reload_priv"];
}

- (BOOL)validateReload_priv:(id *)valueRef error:(NSError **)outError 
{
    // Insert custom validation logic here.
    return YES;
}

- (NSNumber *)select_priv 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey:@"select_priv"];
    tmpValue = [self primitiveValueForKey:@"select_priv"];
    [self didAccessValueForKey:@"select_priv"];
    
    return tmpValue;
}

- (void)setSelect_priv:(NSNumber *)value 
{
    [self willChangeValueForKey:@"select_priv"];
    [self setPrimitiveValue:value forKey:@"select_priv"];
    [self didChangeValueForKey:@"select_priv"];
}

- (BOOL)validateSelect_priv:(id *)valueRef error:(NSError **)outError 
{
    // Insert custom validation logic here.
    return YES;
}

- (NSNumber *)update_priv 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey:@"update_priv"];
    tmpValue = [self primitiveValueForKey:@"update_priv"];
    [self didAccessValueForKey:@"update_priv"];
    
    return tmpValue;
}

- (void)setUpdate_priv:(NSNumber *)value 
{
    [self willChangeValueForKey:@"update_priv"];
    [self setPrimitiveValue:value forKey:@"update_priv"];
    [self didChangeValueForKey:@"update_priv"];
}

- (BOOL)validateUpdate_priv:(id *)valueRef error:(NSError **)outError 
{
    // Insert custom validation logic here.
    return YES;
}

- (NSString *)username 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey:@"username"];
    tmpValue = [self primitiveValueForKey:@"username"];
    [self didAccessValueForKey:@"username"];
    
    return tmpValue;
}

- (void)setUsername:(NSString *)value 
{
    [self willChangeValueForKey:@"username"];
    [self setPrimitiveValue:value forKey:@"username"];
    [self didChangeValueForKey:@"username"];
}

- (BOOL)validateUsername:(id *)valueRef error:(NSError **)outError 
{
    // Insert custom validation logic here.
    return YES;
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


- (NSManagedObject *)parent 
{
    id tmpObject;
    
    [self willAccessValueForKey:@"parent"];
    tmpObject = [self primitiveValueForKey:@"parent"];
    [self didAccessValueForKey:@"parent"];
    
    return tmpObject;
}

- (void)setParent:(NSManagedObject *)value 
{
    [self willChangeValueForKey:@"parent"];
    [self setPrimitiveValue:value forKey:@"parent"];
    [self didChangeValueForKey:@"parent"];
}


- (BOOL)validateParent:(id *)valueRef error:(NSError **)outError 
{
    // Insert custom validation logic here.
    return YES;
}


@end



