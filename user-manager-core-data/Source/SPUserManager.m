//
//  SPUserManager.m
//  sequel-pro
//
//  Created by Mark on 1/20/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "SPUserManager.h"
#import "CMMCPConnection.h"
#import "SPUserItem.h"
#import "SPUserMO.h"
#import "CMMCPResult.h"
#import "ImageAndTextCell.h"
#import "SPArrayAdditions.h"

#define COLUMNIDNAME @"NameColumn"

@interface SPUserManager (PrivateMethods)
- (void)_initializeTree:(NSArray *)items;
- (void)_initializeUsers;
- (void)_initializeDatabaseList;
- (void)_initializeGlobalPrivilegesWithItem:(NSDictionary *)item intoChildItem:(SPUserItem *)childItem;
- (void)_initializeSchemaPrivilegesWithItems:(NSArray *)items;
- (void)_selectParentFromSelection;
- (NSArray *)_fetchUserWithUserName:(NSString *)username;
- (BOOL)insertUsers:(NSArray *)newUsers;
@end

@implementation SPUserManager

- (id)init 
{
	[self dealloc];
	@throw [NSException exceptionWithName:@"BadInitCall" reason:@"Can't call init here" userInfo:nil];
	return nil;
}

- (id)initWithConnection:(CMMCPConnection*) connection
{
	if (![super init]) {
		return nil;
	}
	
	[self setConnection:connection];
	if (!outlineView) {
		[NSBundle loadNibNamed:@"UserManagerView" owner:self];
	}
	return self;
}

- (void)awakeFromNib
{	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(contextDidSave:) 
												 name:NSManagedObjectContextDidSaveNotification 
											   object:nil];
	// Set up the sorting for the NSArrayControllers
	NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
	[selectedPrivsController setSortDescriptors:[NSArray arrayWithObject:sd]];
	[availablePrivsController setSortDescriptors:[NSArray arrayWithObject:sd]];
	[sd release];
	
	[tabView selectTabViewItemAtIndex:0];
	
	NSTableColumn *tableColumn = [outlineView tableColumnWithIdentifier:COLUMNIDNAME];
	ImageAndTextCell *imageAndTextCell = [[[ImageAndTextCell alloc] init] autorelease];
	
	[imageAndTextCell setEditable:NO];
	[tableColumn setDataCell:imageAndTextCell];
	
	[self _initializeDatabaseList];
	
	availablePrivs = [[NSMutableArray alloc] init];
	selectedPrivs = [[NSMutableArray alloc] init];
	
	// Initializing could take a while so run in a separate thread
	[NSThread detachNewThreadSelector:@selector(_initializeUsers) toTarget:self withObject:nil];	
}

- (void)_initializeDatabaseList
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	MCPResult *result = [[self connection] listDBs];
	
	if ([result numOfRows])
	{
		[result dataSeek:0];
	}
	for (int i = 0; i < [result numOfRows]; i++)
	{
		[databaseList addObject:[result fetchRowAsDictionary]];
	}
	[pool release];
}

- (void)_initializeUsers
{
	isInitializing = TRUE;
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSMutableArray *resultAsArray = [NSMutableArray array];
	NSMutableArray *usersResultArray = [NSMutableArray array];
	
	[[self connection] selectDB:@"mysql"];
	CMMCPResult *result = [[[self connection] queryString:@"select * from user order by user"] retain];
	int rows = [result numOfRows];
	if (rows > 0)
	{
		// Go to the beginning
		[result dataSeek:0];
	}
	[users release], users = nil;
	users = [[NSMutableArray alloc] init];
	for(int i = 0; i < rows; i++)
	{
		[resultAsArray addObject:[result fetchRowAsDictionary]];
	}
	[usersResultArray addObjectsFromArray:resultAsArray];
	
	[self performSelectorOnMainThread:@selector(_initializeTree:) withObject:usersResultArray waitUntilDone:TRUE];
	[self _initializeSchemaPrivilegesWithItems:usersResultArray];
	[result release];
	[pool release];
	isInitializing = FALSE;
}

- (void)_initializeTree:(NSArray *)items
{
	
	for(int i = 0; i < [items count]; i++)
	{
		NSString *username = [[items objectAtIndex:i] valueForKey:@"User"];
		NSArray *array = [self _fetchUserWithUserName:username];
		NSDictionary *item = [items objectAtIndex:i];
		
		if (array != nil && [array count] > 0)
		{
			// Add Children
			NSManagedObject *parent = [array objectAtIndex:0];
			NSManagedObject *child = [NSEntityDescription insertNewObjectForEntityForName:@"SPUser" 
																	 inManagedObjectContext:[self managedObjectContext]];
			[child setParent:parent];
			[parent addChildrenObject:child];
			
			[self initializeChild:child withItem:item];
			
		} else {
			// Add Parent
			NSManagedObject *parent = [NSEntityDescription insertNewObjectForEntityForName:@"SPUser" 
																	 inManagedObjectContext:[self managedObjectContext]];
			NSManagedObject *child = [NSEntityDescription insertNewObjectForEntityForName:@"SPUser" 
																   inManagedObjectContext:[self managedObjectContext]];
			[parent setValue:username forKey:@"user"];
			[parent setValue:[item valueForKey:@"Password"] forKey:@"password"];
			[parent addChildrenObject:child];
			[child setParent:parent];

			[self initializeChild:child withItem:item];
		}
		// Save the initialized objects so that any new changes will be tracked.
		NSError *error = nil;
		[[self managedObjectContext] save:&error];
		if (error != nil)
		{
			[[NSApplication sharedApplication] presentError:error];
		}
	}
}

- (void)initializeChild:(NSManagedObject *)child withItem:(NSDictionary *)item
{
	for (NSString *key in item)
	{
		NSLog(@"Key: %@", key);
		NS_DURING
		if ([key hasSuffix:@"_priv"])
		{
			BOOL value = [[item valueForKey:key] boolValue];
			[child setValue:[NSNumber numberWithBool:value] forKey:key];
		} 
		else if ([key hasPrefix:@"max"])
		{
			NSNumber *value = [NSNumber numberWithInt:[[item valueForKey:key] intValue]];
			[child setValue:value forKey:key];
		}
		else if (![key isEqualToString:@"User"] && ![key isEqualToString:@"Password"])
		{
			NSString *value = [item valueForKey:key];
			[child setValue:value forKey:key];
		}
		NS_HANDLER
		NSLog(@"%@", [localException reason]);
		NSLog(@"%@ not implemented yet.", key);
		NS_ENDHANDLER
	}
	
}
- (void)_initializeGlobalPrivilegesWithItem:(NSDictionary *)item intoChildItem:(SPUserItem *)childItem
{
	NSArray *itemKeys = [item allKeys];
	NSMutableDictionary *globalPrivs = [NSMutableDictionary dictionary];
	
	for (int index = 0; index < [itemKeys count]; index++)
	{
		NSString *key = [itemKeys objectAtIndex:index];
		if ([key hasSuffix:@"_priv"])
		{
			[globalPrivs setValue:[item valueForKey:key] forKey:key];
		}
	}
	[childItem setGlobalPrivileges:globalPrivs];
}

- (void)_initializeSchemaPrivilegesWithItems:(NSArray *)items
{
	NSDictionary *firstItem = [items objectAtIndex:0];
	NSArray *keys = [firstItem allKeys];
	for(int index = 0; index < [keys count]; index++)
	{
		NSString *key = [keys objectAtIndex:index];
		if ([key hasSuffix:@"_priv"])
		{
			NSString *newKey = [key substringToIndex:[key rangeOfString:@"_priv"].location];
			[availablePrivsController addObject:[NSDictionary dictionaryWithObject:newKey forKey:@"name"]];			
		}
		
	}
}


/**
 Returns the support folder for the application, used to store the Core Data
 store file.  This code uses a folder named "CoreDataTutorial" for
 the content, either in the NSApplicationSupportDirectory location or (if the
 former cannot be found), the system's temporary directory.
 */

- (NSString *)applicationSupportFolder {
	
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    return [basePath stringByAppendingPathComponent:@"SequelPro"];
}

/**
 Creates, retains, and returns the managed object model for the application 
 by merging all of the models found in the application bundle.
 */

- (NSManagedObjectModel *)managedObjectModel {
	
    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
	
    managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];    
    return managedObjectModel;
}

/**
 Returns the persistent store coordinator for the application.  This 
 implementation will create and return a coordinator, having added the 
 store for the application to it.  (The folder for the store is created, 
 if necessary.)
 */

- (NSPersistentStoreCoordinator *) persistentStoreCoordinator {
	
    if (persistentStoreCoordinator != nil) {
        return persistentStoreCoordinator;
    }
	
    NSFileManager *fileManager;
    NSString *applicationSupportFolder = nil;
//    NSURL *url;
    NSError *error;
    
    fileManager = [NSFileManager defaultManager];
    applicationSupportFolder = [self applicationSupportFolder];
    if ( ![fileManager fileExistsAtPath:applicationSupportFolder isDirectory:NULL] ) {
        [fileManager createDirectoryAtPath:applicationSupportFolder attributes:nil];
    }
    
//    url = [NSURL fileURLWithPath: [applicationSupportFolder stringByAppendingPathComponent: @"SequelProUserData.xml"]];
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
    if (![persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:&error]){
        [[NSApplication sharedApplication] presentError:error];
    }    
	
    return persistentStoreCoordinator;
}

/**
 Returns the managed object context for the application (which is already
 bound to the persistent store coordinator for the application.) 
 */

- (NSManagedObjectContext *) managedObjectContext {
	
    if (managedObjectContext != nil) {
        return managedObjectContext;
    }
	
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        managedObjectContext = [[NSManagedObjectContext alloc] init];
        [managedObjectContext setPersistentStoreCoordinator: coordinator];
    }
    
    return managedObjectContext;
}

- (void)setConnection:(CMMCPConnection *)connection
{
	[connection retain];
	[mySqlConnection release];
	mySqlConnection = connection;
}

- (CMMCPConnection* )connection
{
	return mySqlConnection;
}

- (void)show
{
	[window makeKeyAndOrderFront:nil];
}

- (void)dealloc
{
	NSLog(@"SPUserManager dealloc.");
	
	[managedObjectContext release], managedObjectContext = nil;
    [persistentStoreCoordinator release], persistentStoreCoordinator = nil;
    [managedObjectModel release], managedObjectModel = nil;
	
	[modifiedUsers release], modifiedUsers = nil;
	[addedUsers release],addedUsers = nil;
	[removedUsers release],removedUsers = nil;
	[dbList release],dbList = nil;
	[availablePrivs release],availablePrivs = nil;
	[selectedPrivs release],selectedPrivs = nil;
	[allPrivs release],allPrivs = nil;
	[users release],users = nil;
	[mySqlConnection release];
	[super dealloc];
}

// OutlineView Delegate Methods
- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell*)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if ([cell isKindOfClass:[ImageAndTextCell class]])
	{
		if ([(NSManagedObject *)[item  representedObject] parent] != nil)
		{
			NSImage *image1 = [[NSImage imageNamed:NSImageNameNetwork] retain];
			[image1 setScalesWhenResized:YES];
			[image1 setSize:(NSSize){16,16}];
			[(ImageAndTextCell*)cell setImage:image1];
			[image1 release];
			
		} 
		else 
		{
			NSImage *image1 = [[NSImage imageNamed:NSImageNameUser] retain];
			[image1 setScalesWhenResized:YES];
			[image1 setSize:(NSSize){16,16}];
			[(ImageAndTextCell*)cell setImage:image1];
			[image1 release];
		}
	}
}

- (BOOL)outlineView:(NSOutlineView *)olv isGroupItem:(id)item
{
	return FALSE;
}

- (BOOL)outlineView:(NSOutlineView *)olv shouldSelectItem:(id)item
{
	return TRUE;
}

- (BOOL)outlineView:(NSOutlineView *)olv shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if ([[[item representedObject] children] count] == 0)
	{
		return TRUE;
	}
	return FALSE;
	
}
// TableView Delegate Methods


// Observer methods


// General Action Methods 
- (IBAction)doCancel:(id)sender
{
	[window close];
}

- (IBAction)doApply:(id)sender
{
	NSError *error = nil;
	[[self managedObjectContext] save:&error];
	if (error != nil)
	{
		[[NSApplication sharedApplication] presentError:error];
	}
	else
	{
		[window close];
	}
}

// Schema Privileges Actions
- (IBAction)addToSelected:(id)sender
{
	[selectedPrivsController addObjects:[availablePrivsController selectedObjects]];
	[availablePrivsController removeObjects:[availablePrivsController selectedObjects]];
}

- (IBAction)addToAvailable:(id)sender
{
	[availablePrivsController addObjects:[selectedPrivsController selectedObjects]];
	[selectedPrivsController removeObjects:[selectedPrivsController selectedObjects]];
}

- (IBAction)addUser:(id)sender
{
	if ([[treeController selectedObjects] count] > 0)
	{
		if ([[[treeController selectedObjects] objectAtIndex:0] parent] != nil)
		{
			[self _selectParentFromSelection];
		}
	}	
	NSIndexPath *indexPath = [NSIndexPath indexPathWithIndex:[[[self managedObjectContext] registeredObjects] count]];
	NSManagedObject *newItem = [NSEntityDescription insertNewObjectForEntityForName:@"SPUser" 
															 inManagedObjectContext:[self managedObjectContext]];
	NSManagedObject *newChild = [NSEntityDescription insertNewObjectForEntityForName:@"SPUser"
															  inManagedObjectContext:[self managedObjectContext]];
	[newChild setValue:@"localhost" forKey:@"host"];
	[newItem addChildrenObject:newChild];
	[treeController insertObject:newItem atArrangedObjectIndexPath:indexPath];
}

- (IBAction)removeUser:(id)sender
{
	
	if ([[treeController selectedObjects] count] > 0)
	{
		if ([[[treeController selectedObjects] objectAtIndex:0] parent] != nil)
		{
			[self _selectParentFromSelection];
		}
		[treeController removeObject:[[treeController selectedObjects] objectAtIndex:0]];
	}	
}

- (IBAction)addHost:(id)sender
{
	[treeController addChild:sender];
}

- (IBAction)removeHost:(id)sender
{
	[treeController remove:sender];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(addHost:) ||
		[menuItem action] == @selector(removeHost:))
	{
		return (([[treeController selectedObjects] count] > 0) && 
				[[[treeController selectedObjects] objectAtIndex:0] parent] == nil);
	}
	return TRUE;
}

- (void)_selectParentFromSelection
{
	if ([[treeController selectedObjects] count] > 0)
	{
		NSTreeNode *firstSelectedNode = [[treeController selectedNodes] objectAtIndex:0];
		NSTreeNode *parentNode = [firstSelectedNode parentNode];
		if (parentNode)
		{
			NSIndexPath *parentIndex = [parentNode indexPath];
			[treeController setSelectionIndexPath:parentIndex];
		}
		else
		{
			NSArray *selectedIndexPaths = [treeController selectionIndexPaths];
			[treeController removeSelectionIndexPaths:selectedIndexPaths];
		}
	}
}

// Notifications
- (void)contextDidSave:(NSNotification *)notification
{
	if (isInitializing)
	{
		NSLog(@"ContextDidSave during initializing");
	} 
	else
	{
		NSLog(@"ContextDidSave: %@", [notification userInfo]);
		NSArray *updated = [[notification userInfo] valueForKey:NSUpdatedObjectsKey];
		NSArray *inserted = [[notification userInfo] valueForKey:NSInsertedObjectsKey];
		NSArray *deleted = [[notification userInfo] valueForKey:NSDeletedObjectsKey];
		
		NSLog(@"updated: %@", updated);
		NSLog(@"inserted: %@", inserted);
		NSLog(@"deleted: %@", deleted);
		
		[self insertUsers:inserted];
	}
}

- (BOOL)insertUsers:(NSArray *)insertedUsers
{
	[[self connection] selectDB:@"mysql"];
	for(NSManagedObject *user in insertedUsers)
	{
		if ([user valueForKey:@"parent"] != nil)
		{
			NSMutableString *insertStatement = nil;
			NSDictionary *attributesDict = [[user entity] attributesByName];
			NSMutableArray *values = [NSMutableArray array];
			NSString *valuesString = nil;
			NSMutableString *columns = [NSMutableString stringWithCapacity:10];
			for(NSString *key in [attributesDict allKeys])
			{
				if (key == @"user")
				{
					[values addObject:[NSString stringWithFormat:@"%@",[[user parent] valueForKey:key]]];
				}
				else if (key == @"password")
				{
					[values addObject:[NSString stringWithFormat:@"%@",[[user parent] valueForKey:key]]];
				}
				else
				{
					[values addObject:[user valueForKey:key]];
				}
				[columns appendString:[NSString stringWithFormat:@"%@,", key]];
			}
			valuesString = [values componentsJoinedAndBacktickQuoted];
			columns = [[columns substringToIndex:[columns length] -1] mutableCopy];
			insertStatement = [NSMutableString stringWithFormat:@"insert into user(%@) values(%@)",columns,valuesString];
			NSLog(@"columns = %@, values = %@", columns, values);
			NSLog(@"insert statement = %@", insertStatement);		
		}
		
		
//		CMMCPResult *result = [[[self connection] queryString:[NSString stringWithFormat:insertStatement,[[user attributes retain];
		
	}

	return FALSE;
		
}
- (NSArray *)_fetchUserWithUserName:(NSString *)username
{
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"user == %@", username];
	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"SPUser"
														 inManagedObjectContext:moc];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	
	[request setEntity:entityDescription];
	[request setPredicate:predicate];
	
	NSError *error = nil;
	NSArray *array = [moc executeFetchRequest:request error:&error];
	if (error != nil)
	{
		[[NSApplication sharedApplication] presentError:error];
	}
	
	return array;
}
@end
