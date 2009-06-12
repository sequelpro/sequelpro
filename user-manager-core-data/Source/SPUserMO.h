#import <CoreData/CoreData.h>

@interface NSManagedObject (CoreDataGeneratedAccessors)

- (NSString *)displayName;
- (void)setDisplayName:(NSString *)value;

- (NSNumber *)create_priv;
- (void)setCreate_priv:(NSNumber *)value;
- (BOOL)validateCreate_priv:(id *)valueRef error:(NSError **)outError;

- (NSNumber *)delete_priv;
- (void)setDelete_priv:(NSNumber *)value;
- (BOOL)validateDelete_priv:(id *)valueRef error:(NSError **)outError;

- (NSNumber *)drop_priv;
- (void)setDrop_priv:(NSNumber *)value;
- (BOOL)validateDrop_priv:(id *)valueRef error:(NSError **)outError;

- (NSString *)host;
- (void)setHost:(NSString *)value;
- (BOOL)validateHost:(id *)valueRef error:(NSError **)outError;

- (NSNumber *)insert_priv;
- (void)setInsert_priv:(NSNumber *)value;
- (BOOL)validateInsert_priv:(id *)valueRef error:(NSError **)outError;

- (NSNumber *)maxConnections;
- (void)setMaxConnections:(NSNumber *)value;
- (BOOL)validateMaxConnections:(id *)valueRef error:(NSError **)outError;

- (NSNumber *)maxQuestions;
- (void)setMaxQuestions:(NSNumber *)value;
- (BOOL)validateMaxQuestions:(id *)valueRef error:(NSError **)outError;

- (NSNumber *)maxUserConnections;
- (void)setMaxUserConnections:(NSNumber *)value;
- (BOOL)validateMaxUserConnections:(id *)valueRef error:(NSError **)outError;

- (NSString *)password;
- (void)setPassword:(NSString *)value;
- (BOOL)validatePassword:(id *)valueRef error:(NSError **)outError;

- (NSNumber *)reload_priv;
- (void)setReload_priv:(NSNumber *)value;
- (BOOL)validateReload_priv:(id *)valueRef error:(NSError **)outError;

- (NSNumber *)select_priv;
- (void)setSelect_priv:(NSNumber *)value;
- (BOOL)validateSelect_priv:(id *)valueRef error:(NSError **)outError;

- (NSNumber *)update_priv;
- (void)setUpdate_priv:(NSNumber *)value;
- (BOOL)validateUpdate_priv:(id *)valueRef error:(NSError **)outError;

- (NSString *)username;
- (void)setUsername:(NSString *)value;
- (BOOL)validateUsername:(id *)valueRef error:(NSError **)outError;

// Access to-many relationship via -[NSObject mutableSetValueForKey:]
- (void)addChildrenObject:(NSManagedObject *)value;
- (void)removeChildrenObject:(NSManagedObject *)value;

- (NSManagedObject *)parent;
- (void)setParent:(NSManagedObject *)value;
- (BOOL)validateParent:(id *)valueRef error:(NSError **)outError;

@end