#import <CoreData/CoreData.h>

@interface NSManagedObject (CoreDataGeneratedAccessors)

@property(nonatomic, retain) NSString *user;
@property(nonatomic, retain) NSString *host;
@property(nonatomic, retain) NSManagedObject *parent;

- (NSString *)displayName;
- (void)setDisplayName:(NSString *)value;

// Access to-many relationship via -[NSObject mutableSetValueForKey:]
- (void)addChildrenObject:(NSManagedObject *)value;
- (void)removeChildrenObject:(NSManagedObject *)value;

@end