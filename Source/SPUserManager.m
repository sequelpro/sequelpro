//
//  $Id: SPUserManager.m 856 2009-06-12 05:31:39Z mltownsend $
//
//  SPUserManager.m
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

#import "SPUserManager.h"
#import "MCPConnection.h"
#import "SPUserMO.h"
#import "MCPResult.h"
#import "ImageAndTextCell.h"
#import "SPArrayAdditions.h"
#import "SPStringAdditions.h"

#define COLUMNIDNAME @"NameColumn"

@interface SPUserManager (PrivateMethods)
- (void)_initializeTree:(NSArray *)items;
- (void)_initializeUsers;
- (void)_selectParentFromSelection;
- (NSArray *)_fetchUserWithUserName:(NSString *)username;
- (NSManagedObject *)_createNewSPUser;
- (BOOL)checkAndDisplayMySqlError;
- (void)_clearData;
@end

@implementation SPUserManager

- (id)init 
{
	[self dealloc];
	@throw [NSException exceptionWithName:@"BadInitCall" reason:@"Can't call init here" userInfo:nil];
	return nil;
}

- (id)initWithConnection:(MCPConnection*) connection
{
	if (![super init]) {
		return nil;
	}
	
	[self setConnection:connection];
	
	privColumnsMODict = [[[NSDictionary alloc] initWithObjectsAndKeys:
						  @"grant_option_priv",@"Grant_priv",
						  @"show_databases_priv",@"Show_db_priv",
						  @"create_temporary_tables_priv",@"Create_tmp_tables_priv",
						  @"Replication_slave_priv",@"Repl_slave_priv", 
						  @"Replication_client_priv",@"Repl_client_priv",nil] retain];
	
	return self;
}

- (void)dealloc
{	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[managedObjectContext release], managedObjectContext = nil;
    [persistentStoreCoordinator release], persistentStoreCoordinator = nil;
    [managedObjectModel release], managedObjectModel = nil;
	[privColumnsMODict release], privColumnsMODict = nil;
	
	[mySqlConnection release];
	[super dealloc];
}

- (void)awakeFromNib
{	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(contextDidSave:) 
												 name:NSManagedObjectContextDidSaveNotification 
											   object:nil];
	//[[NSNotificationCenter defaultCenter] addObserver:self
//											 selector:@selector(contextDidChange:)
//												 name:NSManagedObjectContextObjectsDidChangeNotification 
//											   object:nil];
	[tabView selectTabViewItemAtIndex:0];
	
	NSTableColumn *tableColumn = [outlineView tableColumnWithIdentifier:COLUMNIDNAME];
	ImageAndTextCell *imageAndTextCell = [[[ImageAndTextCell alloc] init] autorelease];
	
	[imageAndTextCell setEditable:NO];
	[tableColumn setDataCell:imageAndTextCell];

	[self _initializeUsers];
//	[NSThread detachNewThreadSelector:@selector(_initializeUsers) toTarget:self withObject:nil];
	[[self window] makeKeyAndOrderFront:nil];
}

- (void)_initializeUsers
{
	isInitializing = TRUE;
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSMutableArray *resultAsArray = [NSMutableArray array];
	NSMutableArray *usersResultArray = [NSMutableArray array];
	
	MCPResult *result = [[[self connection] queryString:@"SELECT * FROM `mysql`.`user` ORDER BY `user`"] retain];
	int rows = [result numOfRows];
	if (rows > 0)
	{
		// Go to the beginning
		[result dataSeek:0];
	}
	
	for(int i = 0; i < rows; i++)
	{
		[resultAsArray addObject:[result fetchRowAsDictionary]];
	}
	
	[usersResultArray addObjectsFromArray:resultAsArray];
	
	[self _initializeTree:usersResultArray];
	
	[result release];
	[pool release];
	isInitializing = FALSE;
}

- (void)_initializeTree:(NSArray *)items
{
	
	for(int i = 0; i < [items count]; i++)
	{
		NSString *username = [[items objectAtIndex:i] objectForKey:@"User"];
		NSArray *array = [[self _fetchUserWithUserName:username] retain];
		NSDictionary *item = [items objectAtIndex:i];
		
		if (array != nil && [array count] > 0)
		{
			// Add Children
			NSManagedObject *parent = [array objectAtIndex:0];
			NSManagedObject *child = [self _createNewSPUser];
			[child setParent:parent];
			[parent addChildrenObject:child];
			
			[self initializeChild:child withItem:item];
			
		} else {
			// Add Parent
			NSManagedObject *parent = [self _createNewSPUser];
			NSManagedObject *child = [self _createNewSPUser];
			
			[parent setValue:username forKey:@"user"];
			[parent setValue:[item objectForKey:@"Password"] forKey:@"password"];
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
		[array release];
	}
	[outlineView reloadData];
}

- (void)initializeChild:(NSManagedObject *)child withItem:(NSDictionary *)item
{
	for (NSString *key in item)
	{
		NS_DURING		
		if ([key hasSuffix:@"_priv"])
		{
			// Special case keys
			if ([privColumnsMODict objectForKey:key] != nil)
			{
				key = [privColumnsMODict objectForKey:key];
			}
			
			BOOL value = [[item objectForKey:key] boolValue];
			[child setValue:[NSNumber numberWithBool:value] forKey:key];
		} 
		else if ([key hasPrefix:@"max"])
		{
			NSNumber *value = [NSNumber numberWithInt:[[item objectForKey:key] intValue]];
			[child setValue:value forKey:key];
		}
		else if (![key isEqualToString:@"User"] && ![key isEqualToString:@"Password"])
		{
			NSString *value = [item objectForKey:key];
			[child setValue:value forKey:key];
		}
		NS_HANDLER
		NSLog(@"%@ not implemented yet.", key);
		NS_ENDHANDLER
	}
	
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
	
    NSError *error;
    
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
    if (![persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:&error])
	{
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

- (void)setConnection:(MCPConnection *)connection
{
	[connection retain];
	[mySqlConnection release];
	mySqlConnection = connection;
}

- (MCPConnection* )connection
{
	return mySqlConnection;
}

- (void)show
{
//	[NSThread detachNewThreadSelector:@selector(_initializeUsers) toTarget:self withObject:nil];
	if (!outlineView) {
		[NSBundle loadNibNamed:@"UserManagerView" owner:self];
	}
	[[self window] makeKeyAndOrderFront:nil];
}

#pragma mark -
#pragma mark OutlineView Delegate Methods
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

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	id selectedObject = [[treeController selectedObjects] objectAtIndex:0];
	if ([selectedObject parent] == nil && !([[[tabView selectedTabViewItem] identifier] isEqualToString:@"General"]))
	{
		[tabView selectTabViewItemWithIdentifier:@"General"];
	}
	else
	{
		if ([[[tabView selectedTabViewItem] identifier] isEqualToString:@"General"])
		{
			[tabView selectTabViewItemWithIdentifier:@"Global Privileges"];
		}
	}
}

// General Action Methods 
- (IBAction)doCancel:(id)sender
{
	[[self managedObjectContext] rollback];
	[[self window] close];
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
		[[self window] close];
	}
//	[self _clearData];
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
	NSManagedObject *newItem = [self _createNewSPUser];
	NSManagedObject *newChild = [self _createNewSPUser];
	[newChild setValue:@"localhost" forKey:@"host"];
	[newItem addChildrenObject:newChild];
		
	[treeController addObject:newItem];
	[outlineView expandItem:[outlineView itemAtRow:[outlineView selectedRow]]];
}

- (IBAction)removeUser:(id)sender
{
	[treeController remove:sender];
}

- (IBAction)addHost:(id)sender
{
	if ([[treeController selectedObjects] count] > 0)
	{
		if ([[[treeController selectedObjects] objectAtIndex:0] parent] != nil)
		{
			[self _selectParentFromSelection];
		}
	}
	[treeController addChild:sender];
	// Need to figure out how to do this right.  I want to be able to have the newly
	// added item be in edit mode to change the host name.
//	[outlineView editColumn:0 row:[outlineView selectedRow]	withEvent:nil select:TRUE];		
}

- (IBAction)removeHost:(id)sender
{
	[treeController remove:sender];
}


- (void)_clearData
{
	[managedObjectContext reset];
	[managedObjectContext release];
	managedObjectContext = nil;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(addHost:) ||
		[menuItem action] == @selector(removeHost:))
	{
		return (([[treeController selectedObjects] count] > 0) && 
				[[[treeController selectedObjects] objectAtIndex:0] parent] != nil);
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

#pragma mark -
#pragma mark Notifications
- (void)contextDidSave:(NSNotification *)notification
{
	if (!isInitializing)
	{
		NSArray *updated = [[notification userInfo] valueForKey:NSUpdatedObjectsKey];
		NSArray *inserted = [[notification userInfo] valueForKey:NSInsertedObjectsKey];
		NSArray *deleted = [[notification userInfo] valueForKey:NSDeletedObjectsKey];
		
		if ([inserted count] > 0)
		{
			[self insertUsers:inserted];			
		}
		
		if ([updated count] > 0)
		{
			[self updateUsers:updated];
		}
		
		if ([deleted count] > 0)
		{
			[self deleteUsers:deleted];
		}		
	}
}

- (void)contextDidChange:(NSNotification *)notification
{
	NSLog(@"contextDidChange:");
	
	if (!isInitializing)
	{
		[outlineView reloadData];
	}
}

- (BOOL)updateUsers:(NSArray *)updatedUsers
{
	for (NSManagedObject *user in updatedUsers) {
		[self grantPrivilegesToUser:user];
	}
	return TRUE;
}

- (BOOL)deleteUsers:(NSArray *)deletedUsers
{
	NSMutableString *droppedUsers = [NSMutableString string];
	for (NSManagedObject *user in deletedUsers)
	{
		if ([user host] != nil)
		{
			[droppedUsers appendString:[NSString stringWithFormat:@"%@@%@, ", 
										[[user valueForKey:@"user"] backtickQuotedString], 
										[[user valueForKey:@"host"] backtickQuotedString]]];
		}
		
	}
	droppedUsers = [[droppedUsers substringToIndex:[droppedUsers length]-2] mutableCopy];
	[[self connection] queryString:[NSString stringWithFormat:@"DROP USER %@", droppedUsers]];
	
	return TRUE;
}

- (BOOL)insertUsers:(NSArray *)insertedUsers
{
	for(NSManagedObject *user in insertedUsers)
	{
		if ([user parent] != nil) {
			NSString *createStatement = [NSString stringWithFormat:@"CREATE USER %@@%@ IDENTIFIED BY %@;", 
										 [[[user parent] valueForKey:@"user"] tickQuotedString], 
										 [[user valueForKey:@"host"] tickQuotedString],
										 [[[user parent] valueForKey:@"password"] tickQuotedString]];
			// Create user in database
			[[self connection] queryString:[NSString stringWithFormat:createStatement]];
			
			if ([self checkAndDisplayMySqlError])
			{
				[self grantPrivilegesToUser:user];
			}			
		}
	}
	
	return TRUE;
	
}

// Grant or Revoke privileges to the given user
- (BOOL)grantPrivilegesToUser:(NSManagedObject *)user
{
	if ([user valueForKey:@"parent"] != nil)
	{
		NSDictionary *attributesDict = [[user entity] attributesByName];
		NSMutableArray *grantPrivileges = [NSMutableArray array];
		NSMutableArray *revokePrivileges = [NSMutableArray array];
		
		for(NSString *key in [attributesDict allKeys])
		{
			if ([key hasSuffix:@"_priv"])
			{
				NSString *privilege = [key stringByReplacingOccurrencesOfString:@"_priv" withString:@""];
				
				if ([[user valueForKey:key] boolValue] == TRUE)
				{
					[grantPrivileges addObject:[NSString stringWithFormat:@"%@", [privilege replaceUnderscoreWithSpace]]];
				}
				else
				{
					[revokePrivileges addObject:[NSString stringWithFormat:@"%@", [privilege replaceUnderscoreWithSpace]]];
				}
			}
		}
		// Grant privileges
		if ([grantPrivileges count] > 0)
		{
			NSString *grantStatement = [NSString stringWithFormat:@"GRANT %@ ON *.* TO %@@%@;",
										[grantPrivileges componentsJoinedByCommas],
										[[[user parent] valueForKey:@"user"] tickQuotedString],
										[[user valueForKey:@"host"] tickQuotedString]];
			NSLog(@"%@", grantStatement);
			[[self connection] queryString:[NSString stringWithFormat:grantStatement]];
			[self checkAndDisplayMySqlError];
		}
		
		// Revoke privileges
		if ([revokePrivileges count] > 0)
		{
			NSString *revokeStatement = [NSString stringWithFormat:@"REVOKE %@ ON *.* FROM %@@%@;",
										 [revokePrivileges componentsJoinedByCommas],
										 [[[user parent] valueForKey:@"user"] tickQuotedString],
										 [[user valueForKey:@"host"] tickQuotedString]];
			NSLog(@"%@", revokeStatement);
			[[self connection] queryString:[NSString stringWithFormat:revokeStatement]];
			[self checkAndDisplayMySqlError];
		}		
	}
	return TRUE;
}
- (NSArray *)_fetchUserWithUserName:(NSString *)username
{
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"user == %@ AND parent == nil", username];
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

- (NSManagedObject *)_createNewSPUser
{
	NSManagedObject *user = [[NSEntityDescription insertNewObjectForEntityForName:@"SPUser" 
														  inManagedObjectContext:[self managedObjectContext]] autorelease];	
	
	return user;
}

- (BOOL)checkAndDisplayMySqlError
{
	if (![[[self connection] getLastErrorMessage] isEqualToString:@""])
	{
		NSBeginAlertSheet(@"MySQL Error", 
						  nil, 
						  nil, 
						  nil, 
						  [self window], 
						  self, 
						  NULL, 
						  NULL, 
						  nil, 
						  [[self connection] getLastErrorMessage]);
		return FALSE;
	} else {
		return TRUE;
	}
}

#pragma mark -
#pragma mark Tab View Delegate methods
- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if ([[treeController selectedObjects] count] == 0)
		return FALSE;
	
	id selectedObject = [[treeController selectedObjects] objectAtIndex:0];
	if ([[tabViewItem identifier] isEqualToString:@"General"])
	{
		if ([selectedObject parent] == nil) {
			return TRUE;
		} else {
			return FALSE;
		}
	} 
	else if ([[tabViewItem identifier] isEqualToString:@"Global Privileges"] ||
		[[tabViewItem identifier] isEqualToString:@"Resources"])
	{
		if ([selectedObject parent] != nil) 
		{
			return TRUE;
		} 
		else 
		{
			return FALSE;
		}
	}
	
	return TRUE;
}
@end
