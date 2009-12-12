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

@interface SPUserManager (PrivateAPI)

- (void)_initializeTree:(NSArray *)items;
- (void)_initializeUsers;
- (void)_selectParentFromSelection;
- (NSArray *)_fetchUserWithUserName:(NSString *)username;
- (NSManagedObject *)_createNewSPUser;
- (BOOL)checkAndDisplayMySqlError;
- (void)_clearData;
- (void)initializeChild:(NSManagedObject *)child withItem:(NSDictionary *)item;

@end

@implementation SPUserManager

@synthesize mySqlConnection;
@synthesize privsSupportedByServer;
@synthesize managedObjectContext;
@synthesize managedObjectModel;
@synthesize persistentStoreCoordinator;

-(id)init
{
	if ((self = [super initWithWindowNibName:@"UserManagerView"])) {
		
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
	}
	
	return self;
}

/**
 * Dealloc. Get rid of everything.
 */
- (void)dealloc
{	
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:NSManagedObjectContextDidSaveNotification 
												  object:nil];
	[managedObjectContext release];
    [persistentStoreCoordinator release];
    [managedObjectModel release];
	[privColumnToGrantMap release];
	[mySqlConnection release];
	[privsSupportedByServer release];
	
	[super dealloc];
}

/** 
 * UI specific items to set up when the window loads. This is different than awakeFromNib 
 * as it's only called once.
 */
-(void)windowDidLoad
{
	[tabView selectTabViewItemAtIndex:0];
	
	NSTableColumn *tableColumn = [outlineView tableColumnWithIdentifier:COLUMNIDNAME];
	ImageAndTextCell *imageAndTextCell = [[[ImageAndTextCell alloc] init] autorelease];
	
	[imageAndTextCell setEditable:NO];
	[tableColumn setDataCell:imageAndTextCell];
	
	[self _initializeUsers];
	[super windowDidLoad];
}

/**
 * This method reads in the users from the mysql.user table of the current
 * connection. Then uses this information to initialize the NSOutlineView.
 */
- (void)_initializeUsers
{
	isInitializing = TRUE; // Don't want to do some of the notifications if initializing
	NSMutableString *privKey;
	NSArray *privRow;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSMutableArray *resultAsArray = [NSMutableArray array];
	NSMutableArray *usersResultArray = [NSMutableArray array];
	
	// Select users from the mysql.user table
	MCPResult *result = [self.mySqlConnection queryString:@"SELECT * FROM `mysql`.`user` ORDER BY `user`"];
	int rows = [result numOfRows];
	
	if (rows > 0) {
		// Go to the beginning
		[result dataSeek:0];
	}
	
	for (int i = 0; i < rows; i++)
	{
		[resultAsArray addObject:[result fetchRowAsDictionary]];
	}
	
	[usersResultArray addObjectsFromArray:resultAsArray];

	[self _initializeTree:usersResultArray];

	// Set up the array of privs supported by this server.
	[self.privsSupportedByServer removeAllObjects];

	// Attempt to use SHOW PRIVILEGES syntax - supported since 4.1.0
	result = [self.mySqlConnection queryString:@"SHOW PRIVILEGES"];
	if ([result numOfRows]) {
		while (privRow = [result fetchRowAsArray]) {
			privKey = [NSMutableString stringWithString:[[privRow objectAtIndex:0] lowercaseString]];
			[privKey replaceOccurrencesOfString:@" " withString:@"_" options:NSLiteralSearch range:NSMakeRange(0, [privKey length])];
			[privKey appendString:@"_priv"];
			[self.privsSupportedByServer setValue:[NSNumber numberWithBool:YES] forKey:privKey];
		}
	
	// If that fails, base privilege support on the mysql.users columns
	} else {
		result = [self.mySqlConnection queryString:@"SHOW COLUMNS FROM `mysql`.`user`"];
		while (privRow = [result fetchRowAsArray]) {
			privKey = [NSMutableString stringWithString:[privRow objectAtIndex:0]];
			if (![privKey hasSuffix:@"_priv"]) continue;
			if ([privColumnToGrantMap objectForKey:privKey]) privKey = [privColumnToGrantMap objectForKey:privKey];
			[self.privsSupportedByServer setValue:[NSNumber numberWithBool:YES] forKey:[privKey lowercaseString]];
		}
	}

	[pool release];
	isInitializing = FALSE;
}

- (void)_initializeTree:(NSArray *)items
{
	// The NSOutlineView gets it's data from a NSTreeController which gets
	// it's data from the SPUser Entity objects in the current managedObjectContext.
	
	// Go through each item that contains a dictionary of key-value pairs
	// for each user currently in the database.
	for(int i = 0; i < [items count]; i++)
	{
		NSString *username = [[items objectAtIndex:i] objectForKey:@"User"];
		NSArray *parentResults = [[self _fetchUserWithUserName:username] retain];
		NSDictionary *item = [items objectAtIndex:i];
		
		// Check to make sure if we already have added the parent.
		if (parentResults != nil && [parentResults count] > 0)
		{
			// Add Children
			NSManagedObject *parent = [parentResults objectAtIndex:0];
			NSManagedObject *child = [self _createNewSPUser];
			[child setParent:parent];
			[parent addChildrenObject:child];
			
			// Setup the NSManagedObject with values from the dictionary
			[self initializeChild:child withItem:item];
			
		} else {
			// Add Parent
			NSManagedObject *parent = [self _createNewSPUser];
			NSManagedObject *child = [self _createNewSPUser];
			
			// We only care about setting the user and password keys on the parent
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
		[parentResults release];
	}
	// Reload data of the outline view with the changes.
	[outlineView reloadData];
	[treeController rearrangeObjects];
}

/**
 * Set NSManagedObject with values from the passed in dictionary.
 */
- (void)initializeChild:(NSManagedObject *)child withItem:(NSDictionary *)item
{
	for (NSString *key in item)
	{
		// In order to keep the priviledges a little more dynamic, just
		// go through the keys that have the _priv suffix.  If a priviledge is
		// currently not supported in the model, then an exception is thrown.
		// We catch that exception and print to the console for future enhancement.
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
		else if ([key hasPrefix:@"max"]) // Resource Management restrictions
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
 * Creates, retains, and returns the managed object model for the application 
 * by merging all of the models found in the application bundle.
 */
- (NSManagedObjectModel *)managedObjectModel 
{	
    if (managedObjectModel != nil) return managedObjectModel;
	
    managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];    
	
    return managedObjectModel;
}

/**
 * Returns the persistent store coordinator for the application.  This 
 * implementation will create and return a coordinator, having added the 
 * store for the application to it.  (The folder for the store is created, 
 * if necessary.)
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator 
{	
    if (persistentStoreCoordinator != nil) return persistentStoreCoordinator;
	
    NSError *error;
    
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
	
    if (![persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }    
	
    return persistentStoreCoordinator;
}

/**
 * Returns the managed object context for the application (which is already
 * bound to the persistent store coordinator for the application.) 
 */
- (NSManagedObjectContext *)managedObjectContext 
{	
    if (managedObjectContext != nil) return managedObjectContext;
	
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        managedObjectContext = [[NSManagedObjectContext alloc] init];
        [managedObjectContext setPersistentStoreCoordinator: coordinator];
    }
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(contextDidSave:) 
												 name:NSManagedObjectContextDidSaveNotification 
											   object:nil];	
    
    return managedObjectContext;
}

#pragma mark -
#pragma mark OutlineView Delegate Methods

- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell*)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if ([cell isKindOfClass:[ImageAndTextCell class]])
	{
		// Determines which Image to display depending on parent or child object
		if ([(NSManagedObject *)[item  representedObject] parent] != nil)
		{
			NSImage *image1 = [[NSImage imageNamed:NSImageNameNetwork] retain];
			[image1 setScalesWhenResized:YES];
			[image1 setSize:(NSSize){16,16}];
			[(ImageAndTextCell*)cell setImage:image1];
			[image1 release];
			
		} 
		else {
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
	
	if ([selectedObject parent] == nil && !([[[tabView selectedTabViewItem] identifier] isEqualToString:@"General"])) {
		[tabView selectTabViewItemWithIdentifier:@"General"];
	}
	else {
		if ([selectedObject parent] != nil && [[[tabView selectedTabViewItem] identifier] isEqualToString:@"General"]) {
			[tabView selectTabViewItemWithIdentifier:@"Global Privileges"];
		}
	}
}

- (NSArray *)treeSortDescriptors
{
	NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES];
	return [NSArray arrayWithObject:descriptor];
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
		[self.mySqlConnection queryString:@"FLUSH PRIVILEGES"];
		[NSApp endSheet:[self window] returnCode:0];
		[[self window] orderOut:self];
	}
}

/**
 * Enables all privileges.
 */
- (IBAction)checkAllPrivileges:(id)sender
{
	id selectedUser = [[treeController selectedObjects] objectAtIndex:0];

	// Iterate through the supported privs, setting the value of each to true
	for (NSString *key in self.privsSupportedByServer) {
		if (![key hasSuffix:@"_priv"]) continue;

		// Perform the change in a try/catch check to avoid exceptions for unhandled privs
		@try {
			[selectedUser setValue:[NSNumber numberWithBool:TRUE] forKey:key];
		}
		@catch (NSException * e) {
		}
	}
}

/**
 * Disables all privileges.
 */
- (IBAction)uncheckAllPrivileges:(id)sender
{
	id selectedUser = [[treeController selectedObjects] objectAtIndex:0];

	// Iterate through the supported privs, setting the value of each to false
	for (NSString *key in self.privsSupportedByServer) {
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
	// Adds a new SPUser objects to the managedObjectContext and sets default values
	if ([[treeController selectedObjects] count] > 0) {
		if ([[[treeController selectedObjects] objectAtIndex:0] parent] != nil) {
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
	// Only allow removing hosts of a host node is selected.
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

- (void)_selectFirstChildOfParentNode
{
	if ([[treeController selectedObjects] count] > 0)
	{
		[outlineView expandItem:[outlineView itemAtRow:[outlineView selectedRow]]];
		
		id selectedObject = [[treeController selectedObjects] objectAtIndex:0];
		NSTreeNode *firstSelectedNode = [[treeController selectedNodes] objectAtIndex:0];
		id parent = [selectedObject parent];
		// If this is already a parent, then parentNode should be null.
		// If a child is already selected, then we want to not change the selection
		if (!parent)
		{
			NSIndexPath *childIndex = [[[firstSelectedNode childNodes] objectAtIndex:0] indexPath];
			[treeController setSelectionIndexPath:childIndex];
		}

	}
}

#pragma mark -
#pragma mark Notifications

/** 
 * This notification is called when the managedObjectContext save happens.
 * This takes the inserted, updated, and deleted arrays and applys them to 
 * the database.
 */
- (void)contextDidSave:(NSNotification *)notification
{	
	NSManagedObjectContext *notificationContext = (NSManagedObjectContext *)[notification object];
	// If there are multiple user manager windows open, it's possible to get this
	// notification from foreign windows.  Ignore those notifications.
	if (notificationContext != self.managedObjectContext) return;
	
	if (!isInitializing)
	{		
		NSArray *updated = [[notification userInfo] valueForKey:NSUpdatedObjectsKey];
		NSArray *inserted = [[notification userInfo] valueForKey:NSInsertedObjectsKey];
		NSArray *deleted = [[notification userInfo] valueForKey:NSDeletedObjectsKey];
		
		NSLog(@"%d", [inserted count]);
		
		if ([inserted count] > 0) {
			[self insertUsers:inserted];
		}
		
		if ([updated count] > 0) {
			[self updateUsers:updated];
		}
		
		if ([deleted count] > 0) {
			[self deleteUsers:deleted];
		}	
	}
}

- (void)contextDidChange:(NSNotification *)notification
{	
	if (!isInitializing) [outlineView reloadData];
}

- (BOOL)updateUsers:(NSArray *)updatedUsers
{
	for (NSManagedObject *user in updatedUsers) {
		if (![user host])
		{
			// Just the user password was changed.
			// Change password to be the same on all hosts.
			NSArray *hosts = [user valueForKey:@"children"];
			for(NSManagedObject *child in hosts)
			{
				NSString *changePasswordStatement = [NSString stringWithFormat:
													 @"SET PASSWORD FOR %@@%@ = PASSWORD('%@')",
													 [[user valueForKey:@"user"] tickQuotedString],
													 [[child host] tickQuotedString],
													 [user valueForKey:@"password"]];
				[self.mySqlConnection queryString:changePasswordStatement];	
				[self checkAndDisplayMySqlError];
			}
		} else {
			[self grantPrivilegesToUser:user];			
		}

	}
	
	return YES;
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
	[droppedUsers release];
	return TRUE;
}

/**
 * Inserts (creates) the supplied users in the database.
 */
- (BOOL)insertUsers:(NSArray *)insertedUsers
{	
	for (NSManagedObject *user in insertedUsers)
	{
		NSString *createStatement;

		if ([user parent] && [[user parent] valueForKey:@"user"] && [[user parent] valueForKey:@"password"]) {
			
			createStatement = [NSString stringWithFormat:@"CREATE USER %@@%@ IDENTIFIED BY %@;", 
										 [[[user parent] valueForKey:@"user"] tickQuotedString], 
										 [[user valueForKey:@"host"] tickQuotedString],
										 [[[user parent] valueForKey:@"password"] tickQuotedString]];
			
			// Create user in database
			[self.mySqlConnection queryString:[NSString stringWithFormat:createStatement]];
			
			if ([self checkAndDisplayMySqlError]) {
				[self grantPrivilegesToUser:user];
			}	
		}
		
	}
	return YES;
}

/**
 * Grant or revoke privileges to the given user
 */
- (BOOL)grantPrivilegesToUser:(NSManagedObject *)user
{
	if ([user valueForKey:@"parent"] != nil)
	{
		NSMutableArray *grantPrivileges = [NSMutableArray array];
		NSMutableArray *revokePrivileges = [NSMutableArray array];
		
		for(NSString *key in self.privsSupportedByServer)
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

// Gets any NSManagedObject (SPUser) from the managedObjectContext that may
// already exist with the given username.
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

// Creates a new NSManagedObject and inserts it into the managedObjectContext.
- (NSManagedObject *)_createNewSPUser
{
	NSManagedObject *user = [NSEntityDescription insertNewObjectForEntityForName:@"SPUser" 
														  inManagedObjectContext:[self managedObjectContext]];	
	
	return user;
}

// Displays alert panel if there is an error condition currently on the mySqlConnection
- (BOOL)checkAndDisplayMySqlError
{
	if (![[self.mySqlConnection getLastErrorMessage] isEqualToString:@""]) {
		NSAlert *alert = [NSAlert alertWithMessageText:@"MySQL Error" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:[self.mySqlConnection getLastErrorMessage]];
		[alert runModal];
		
		return NO;
	}
	
	return YES;
}

#pragma mark -
#pragma mark Tab View Delegate methods

-(void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if ([[treeController selectedObjects] count] == 0) return;
	
	id selectedObject = [[treeController selectedObjects] objectAtIndex:0];
	
	// If the selected tab is General and a child is selected, select the
	// parent (user info)
	if ([[tabViewItem identifier] isEqualToString:@"General"]) {
		if ([selectedObject parent] != nil)
		{
			[self _selectParentFromSelection];
		}
	} else if ([[tabViewItem identifier] isEqualToString:@"Global Privileges"] 
			   || [[tabViewItem identifier] isEqualToString:@"Resources"]) {
		// if the tab is either Global Privs or Resources and we have a user 
		// selected, then open tree and select first child node.
		[self _selectFirstChildOfParentNode];
	}
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
