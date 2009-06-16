#import "SPUserMO.h"

@implementation NSManagedObject (CoreDataGeneratedAccessors)

- (NSString *)displayName
{
	if ([self parent] == nil) {
		return [self user];
	} else {
		return [self host];
	}
}

- (void)setDisplayName:(NSString *)value
{
	[self setHost:value];
}
/*
- (NSNumber *)alter_priv 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey:@"alter_priv"];
    tmpValue = [self primitiveValueForKey:@"alter_priv"];
    [self didAccessValueForKey:@"alter_priv"];
    
    return tmpValue;
}

- (void)setAlter_priv:(NSNumber *)value 
{
    [self willChangeValueForKey:@"alter_priv"];
    [self setPrimitiveValue:value forKey:@"alter_priv"];
    [self didChangeValueForKey:@"alter_priv"];
}

- (BOOL)validateAlter_priv:(id *)valueRef error:(NSError **)outError 
{
    // Insert custom validation logic here.
    return YES;
}

- (NSNumber *)alter_routine_priv 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey:@"alter_routine_priv"];
    tmpValue = [self primitiveValueForKey:@"alter_routine_priv"];
    [self didAccessValueForKey:@"alter_routine_priv"];
    
    return tmpValue;
}

- (void)setAlter_routine_priv:(NSNumber *)value 
{
    [self willChangeValueForKey:@"alter_routine_priv"];
    [self setPrimitiveValue:value forKey:@"alter_routine_priv"];
    [self didChangeValueForKey:@"alter_routine_priv"];
}

- (BOOL)validateAlter_routine_priv:(id *)valueRef error:(NSError **)outError 
{
    // Insert custom validation logic here.
    return YES;
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

- (NSNumber *)create_routine_priv 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey:@"create_routine_priv"];
    tmpValue = [self primitiveValueForKey:@"create_routine_priv"];
    [self didAccessValueForKey:@"create_routine_priv"];
    
    return tmpValue;
}

- (void)setCreate_routine_priv:(NSNumber *)value 
{
    [self willChangeValueForKey:@"create_routine_priv"];
    [self setPrimitiveValue:value forKey:@"create_routine_priv"];
    [self didChangeValueForKey:@"create_routine_priv"];
}

- (BOOL)validateCreate_routine_priv:(id *)valueRef error:(NSError **)outError 
{
    // Insert custom validation logic here.
    return YES;
}

- (NSNumber *)create_tmp_table_priv 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey:@"create_tmp_table_priv"];
    tmpValue = [self primitiveValueForKey:@"create_tmp_table_priv"];
    [self didAccessValueForKey:@"create_tmp_table_priv"];
    
    return tmpValue;
}

- (void)setCreate_tmp_table_priv:(NSNumber *)value 
{
    [self willChangeValueForKey:@"create_tmp_table_priv"];
    [self setPrimitiveValue:value forKey:@"create_tmp_table_priv"];
    [self didChangeValueForKey:@"create_tmp_table_priv"];
}

- (BOOL)validateCreate_tmp_table_priv:(id *)valueRef error:(NSError **)outError 
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

- (NSNumber *)max_connections 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey:@"max_connections"];
    tmpValue = [self primitiveValueForKey:@"max_connections"];
    [self didAccessValueForKey:@"max_connections"];
    
    return tmpValue;
}

- (void)setMax_connections:(NSNumber *)value 
{
    [self willChangeValueForKey:@"max_connections"];
    [self setPrimitiveValue:value forKey:@"max_connections"];
    [self didChangeValueForKey:@"max_connections"];
}

- (BOOL)validateMax_connections:(id *)valueRef error:(NSError **)outError 
{
    // Insert custom validation logic here.
    return YES;
}

- (NSNumber *)max_questions 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey:@"max_questions"];
    tmpValue = [self primitiveValueForKey:@"max_questions"];
    [self didAccessValueForKey:@"max_questions"];
    
    return tmpValue;
}

- (void)setMax_questions:(NSNumber *)value 
{
    [self willChangeValueForKey:@"max_questions"];
    [self setPrimitiveValue:value forKey:@"max_questions"];
    [self didChangeValueForKey:@"max_questions"];
}

- (BOOL)validateMax_questions:(id *)valueRef error:(NSError **)outError 
{
    // Insert custom validation logic here.
    return YES;
}

- (NSNumber *)max_user_connections 
{
    NSNumber * tmpValue;
    
    [self willAccessValueForKey:@"max_user_connections"];
    tmpValue = [self primitiveValueForKey:@"max_user_connections"];
    [self didAccessValueForKey:@"max_user_connections"];
    
    return tmpValue;
}

- (void)setMax_user_connections:(NSNumber *)value 
{
    [self willChangeValueForKey:@"max_user_connections"];
    [self setPrimitiveValue:value forKey:@"max_user_connections"];
    [self didChangeValueForKey:@"max_user_connections"];
}

- (BOOL)validateMax_user_connections:(id *)valueRef error:(NSError **)outError 
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

- (NSString *)user 
{
    NSString * tmpValue;
    
    [self willAccessValueForKey:@"user"];
    tmpValue = [self primitiveValueForKey:@"user"];
    [self didAccessValueForKey:@"user"];
    
    return tmpValue;
}

- (void)setUser:(NSString *)value 
{
    [self willChangeValueForKey:@"user"];
    [self setPrimitiveValue:value forKey:@"user"];
    [self didChangeValueForKey:@"user"];
}

- (BOOL)validateUser:(id *)valueRef error:(NSError **)outError 
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

*/

@end



