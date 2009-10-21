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
#import "SPGrowlController.h"

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

@synthesize mySqlConnection;

- (id)initWithConnection:(MCPConnection*) connection
{
	if ((self = [super initWithWindowNibName:@"UserManagerView"])) {
	
		self.mySqlConnection = connection;

		// When reading privileges from the database, they are converted automatically to a
		// lowercase key used in the user privileges stores, from which a GRANT syntax
		// is derived automatically.  While most keys can be automatically converted without
		// any difficulty, some keys differ slightly in mysql column storage to GRANT syntax;
		// this dictionary provides mappings for those values to ensure consistency.
		privColumnToGrantMap = [[NSDictionary alloc] initWithObjectsAndKeys:
									@"Grant_option_priv", @"Grant_priv",
									@"Show_databases_priv", @"Show_db_priv",
									@"Create_temporary_tables_priv", @"Create_tmp_table_priv",
									@"Replication_slave_priv", @"Repl_slave_priv", 
									@"Replication_client_priv", @"Repl_client_priv",
								  nil];

		privsSupportedByServer = [[NSMutableDictionary alloc] init];
	}

	return self;
}

- (void)dealloc
{	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[managedObjectContext release], managedObjectContext = nil;
    [persistentStoreCoordinator release], persistentStoreCoordinator = nil;
    [managedObjectModel release], managedObjectModel = nil;
	[privColumnToGrantMap release], privColumnToGrantMap = nil;
	[privsSupportedByServer release], privsSupportedByServer = nil;
	
	[mySqlConnection release];
	[super dealloc];
}

- (void)awakeFromNib
{	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(contextDidSave:) 
												 name:NSManagedObjectContextDidSaveNotification 
											   object:nil];
	[tabView selectTabViewItemAtIndex:0];
	
	NSTableColumn *tableColumn = [outlineView tableColumnWithIdentifier:COLUMNIDNAME];
	ImageAndTextCell *imageAndTextCell = [[[ImageAndTextCell alloc] init] autorelease];
	
	[imageAndTextCell setEditable:NO];
	[tableColumn setDataCell:imageAndTextCell];

	[self _initializeUsers];
}

- (void)_initializeUsers
{
	isInitializing = TRUE;
	NSMutableString *privKey;
	NSArray *privRow;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSMutableArray *resultAsArray = [NSMutableArray array];
	NSMutableArray *usersResultArray = [NSMutableArray array];
	
	MCPResult *result = [[self.mySqlConnection queryString:@"SELECT * FROM `mysql`.`user` ORDER BY `user`"] retain];
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

	// Set up the array of privs supported by this server.
	[privsSupportedByServer removeAllObjects];

	// Attempt to use SHOW PRIVILEGES syntax - supported since 4.1.0
	result = [self.mySqlConnection queryString:@"SHOW PRIVILEGES"];
	if ([result numOfRows]) {
		while (privRow = [result fetchRowAsArray]) {
			privKey = [NSMutableString stringWithString:[[privRow objectAtIndex:0] lowercaseString]];
			[privKey replaceOccurrencesOfString:@" " withString:@"_" options:NSLiteralSearch range:NSMakeRange(0, [privKey length])];
			[privKey appendString:@"_priv"];
			[privsSupportedByServer setValue:[NSNumber numberWithBool:YES] forKey:privKey];
		}
	
	// If that fails, base privilege support on the mysql.users columns
	} else {
		result = [self.mySqlConnection queryString:@"SHOW COLUMNS FROM `mysql`.`user`"];
		while (privRow = [result fetchRowAsArray]) {
			privKey = [NSMutableString stringWithString:[privRow objectAtIndex:0]];
			if (![privKey hasSuffix:@"_priv"]) continue;
			if ([privColumnToGrantMap objectForKey:privKey]) privKey = [privColumnToGrantMap objectForKey:privKey];
			[privsSupportedByServer setValue:[NSNumber numberWithBool:YES] forKey:[privKey lowercaseString]];
		}
	}

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
			BOOL value = [[item objectForKey:key] boolValue];

			// Special case keys
			if ([privColumnToGrantMap objectForKey:key])
			{
				key = [privColumnToGrantMap objectForKey:key];
			}
			
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
		DLog(@"%@ not implemented yet.", key);
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

/*- (void)show
{
//	[NSThread detachNewThreadSelector:@selector(_initializeUsers) toTarget:self withObject:nil];
	if (!outlineView) {
		[NSBundle loadNibNamed:@"UserManagerView" owner:self];
	}
	[[self window] makeKeyAndOrderFront:nil];
}*/

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
	return ([[[item representedObject] children] count] == 0);
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

#pragma mark -
#pragma mark General IBAction methods

/**
 * Closes the user manager and reverts any changes made.
 */
- (IBAction)doCancel:(id)sender
{
	[[self managedObjectContext] rollback];
	
	// Close sheet
	[NSApp endSheet:[self window] returnCode:0];
	[[self window] orderOut:self];
}

/**
 * Closes the user manager and applies any changes made.
 */
- (IBAction)doApply:(id)sender
{
	NSError *error = nil;
	[[self managedObjectContext] save:&error];
	
	if (error != nil) {
		[[NSApplication sharedApplication] presentError:error];
	}
	else {
		// Close sheet
		[NSApp endSheet:[self window] returnCode:0];
		[[self window] orderOut:self];
	}
}

- (IBAction)checkAllPrivileges:(id)sender
{
	id selectedUser = [[treeController selectedObjects] objectAtIndex:0];

	// Iterate through the supported privs, setting the value of each to true
	for (NSString *key in privsSupportedByServer) {
		if (![key hasSuffix:@"_priv"]) continue;

		// Perform the change in a try/catch check to avoid exceptions for unhandled privs
		@try {
			[selectedUser setValue:[NSNumber numberWithBool:TRUE] forKey:key];
		}
		@catch (NSException * e) {
		}
	}
}

- (IBAction)uncheckAllPrivileges:(id)sender
{
	id selectedUser = [[treeController selectedObjects] objectAtIndex:0];

	// Iterate through the supported privs, setting the value of each to false
	for (NSString *key in privsSupportedByServer) {
		if (![key hasSuffix:@"_priv"]) continue;

		// Perform the change in a try/catch check to avoid exceptions for unhandled privs
		@try {
			[selectedUser setValue:[NSNumber numberWithBool:FALSE] forKey:key];
		}
		@catch (NSException * e) {
		}
	}

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

	// The newly added item will be selected as it is added, but only after the next iteration of the
	// run loop - edit it after a tiny delay.
	[self performSelector:@selector(editNewHost) withObject:nil afterDelay:0.1];
}

// Perform a deferred edit of the currently selected row.
- (void)editNewHost
{
	[outlineView editColumn:0 row:[outlineView selectedRow]	withEvent:nil select:TRUE];		
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
	if ([menuItem action] == @selector(removeHost:))
	{
		return (([[treeController selectedObjects] count] > 0) && 
				[[[treeController selectedObjects] objectAtIndex:0] parent] != nil);
	} 
	else if ([menuItem action] == @selector(addHost:))
	{
		return ([[treeController selectedObjects] count] > 0);
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
	DLog(@"contextDidChange:");
	
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
	[self.mySqlConnection queryString:[NSString stringWithFormat:@"DROP USER %@", droppedUsers]];
	
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
			[self.mySqlConnection queryString:[NSString stringWithFormat:createStatement]];
			
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
		NSMutableArray *grantPrivileges = [NSMutableArray array];
		NSMutableArray *revokePrivileges = [NSMutableArray array];
		
		for(NSString *key in privsSupportedByServer)
		{
			if (![key hasSuffix:@"_priv"]) continue;
			NSString *privilege = [key stringByReplacingOccurrencesOfString:@"_priv" withString:@""];
			
			
			// Check the value of the priv and assign to grant or revoke query as appropriate; do this
			// in a try/catch check to avoid exceptions for unhandled privs
			@try {
				if ([[user valueForKey:key] boolValue] == TRUE) {
					[grantPrivileges addObject:[NSString stringWithFormat:@"%@", [privilege replaceUnderscoreWithSpace]]];
				} else {
					[revokePrivileges addObject:[NSString stringWithFormat:@"%@", [privilege replaceUnderscoreWithSpace]]];
				}
			}
			@catch (NSException * e) {
			}
		}
		// Grant privileges
		if ([grantPrivileges count] > 0)
		{
			NSString *grantStatement = [NSString stringWithFormat:@"GRANT %@ ON *.* TO %@@%@;",
										[grantPrivileges componentsJoinedByCommas],
										[[[user parent] valueForKey:@"user"] tickQuotedString],
										[[user valueForKey:@"host"] tickQuotedString]];
			DLog(@"%@", grantStatement);
			[self.mySqlConnection queryString:[NSString stringWithFormat:grantStatement]];
			[self checkAndDisplayMySqlError];
		}
		
		// Revoke privileges
		if ([revokePrivileges count] > 0)
		{
			NSString *revokeStatement = [NSString stringWithFormat:@"REVOKE %@ ON *.* FROM %@@%@;",
										 [revokePrivileges componentsJoinedByCommas],
										 [[[user parent] valueForKey:@"user"] tickQuotedString],
										 [[user valueForKey:@"host"] tickQuotedString]];
			DLog(@"%@", revokeStatement);
			[self.mySqlConnection queryString:[NSString stringWithFormat:revokeStatement]];
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
	if (![[self.mySqlConnection getLastErrorMessage] isEqualToString:@""])
	{
		NSAlert *alert = [NSAlert alertWithMessageText:@"MySQL Error" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:[self.mySqlConnection getLastErrorMessage]];
		[alert runModal];
		
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
	if ([[tabViewItem identifier] isEqualToString:@"General"]) {
		return ([selectedObject parent] == nil);
	} else if ([[tabViewItem identifier] isEqualToString:@"Global Privileges"] || [[tabViewItem identifier] isEqualToString:@"Resources"]) {
		return ([selectedObject parent] != nil);
	}
	
	return TRUE;
}

#pragma mark -
#pragma mark SplitView delegate methods

/**
 * Return the maximum possible size of the splitview.
 */
- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset
{
	return (proposedMax - 220);
}

/**
 * Return the minimum possible size of the splitview.
 */
- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset
{
	return (proposedMin + 120);
}

@end
