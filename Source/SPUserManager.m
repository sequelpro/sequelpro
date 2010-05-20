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
#import "SPUserMO.h"
#import "ImageAndTextCell.h"
#import "SPArrayAdditions.h"
#import "SPStringAdditions.h"
#import "SPGrowlController.h"
#import "SPConnectionController.h"

#define COLUMNIDNAME @"NameColumn"

@interface SPUserManager (PrivateAPI)

- (void)_initializeTree:(NSArray *)items;
- (void)_initializeUsers;
- (void)_selectParentFromSelection;
- (NSArray *)_fetchUserWithUserName:(NSString *)username;
- (NSManagedObject *)_createNewSPUser;
- (BOOL)checkAndDisplayMySqlError;
- (void)_clearData;
- (void)_initializeChild:(NSManagedObject *)child withItem:(NSDictionary *)item;
- (void)_initializeSchemaPrivsForChild:(NSManagedObject *)child;
- (void)_initializeSchemaPrivs;
- (NSArray *)_fetchPrivsWithUser:(NSString *)username schema:(NSString *)selectedSchema host:(NSString *)host;
- (void)_setSchemaPrivValues:(NSArray *)objects enabled:(BOOL)enabled;
- (void) _initializeAvailablePrivs;

@end

@implementation SPUserManager

@synthesize mySqlConnection;
@synthesize privsSupportedByServer;
@synthesize managedObjectContext;
@synthesize managedObjectModel;
@synthesize persistentStoreCoordinator;
@synthesize schemas;
@synthesize grantedSchemaPrivs;
@synthesize availablePrivs;
@synthesize treeSortDescriptors;

- (id)init
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
	
	schemas = [[NSMutableArray alloc] init];
	availablePrivs = [[NSMutableArray alloc] init];
	grantedSchemaPrivs = [[NSMutableArray alloc] init]; 
	
	return self;
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
	
	// Set the button delegate 
	[splitViewButtonBar setSplitViewDelegate:self];
	
	[self _initializeUsers];
	[self _initializeSchemaPrivs];

	treeSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES];
	
	[self setTreeSortDescriptors:[NSArray arrayWithObject:treeSortDescriptor]];
	
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
	NSInteger rows = [result numOfRows];
	
	if (rows > 0) {
		// Go to the beginning
		[result dataSeek:0];
	}
	
	for (NSInteger i = 0; i < rows; i++)
	{
		[resultAsArray addObject:[result fetchRowAsDictionary]];
	}
	
	[usersResultArray addObjectsFromArray:resultAsArray];

	[self _initializeTree:usersResultArray];

	// Set up the array of privs supported by this server.
	[self.privsSupportedByServer removeAllObjects];

	// Attempt to use SHOW PRIVILEGES syntax - supported since 4.1.0
	result = [self.mySqlConnection queryString:@"SHOW PRIVILEGES"];
	[result setReturnDataAsStrings:YES];
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
		[result setReturnDataAsStrings:YES];
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

/**
 * Initialize the outline view tree. The NSOutlineView gets it's data from a NSTreeController which gets
 * it's data from the SPUser Entity objects in the current managedObjectContext.
 */
- (void)_initializeTree:(NSArray *)items
{
	// Go through each item that contains a dictionary of key-value pairs
	// for each user currently in the database.
	for(NSInteger i = 0; i < [items count]; i++)
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
			
			// Setup the NSManagedObject with values from the dictionary
			[self _initializeChild:child withItem:item];
			
			NSMutableSet *children = [parent mutableSetValueForKey:@"children"];
			[children addObject:child];
			[self _initializeSchemaPrivsForChild:child];
		} else {
			// Add Parent
			NSManagedObject *parent = [self _createNewSPUser];
			NSManagedObject *child = [self _createNewSPUser];
			
			// We only care about setting the user and password keys on the parent, together with their
			// original values for comparison purposes
			[parent setPrimitiveValue:username forKey:@"user"];
			[parent setPrimitiveValue:username forKey:@"originaluser"];
			[parent setPrimitiveValue:[item objectForKey:@"Password"] forKey:@"password"];
			[parent setPrimitiveValue:[item objectForKey:@"Password"] forKey:@"originalpassword"];

			[self _initializeChild:child withItem:item];
			
			NSMutableSet *children = [parent mutableSetValueForKey:@"children"];
			[children addObject:child];
			[self _initializeSchemaPrivsForChild:child];
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
 * Initialize the available user privileges.
 */
- (void)_initializeAvailablePrivs 
{
	// Initialize available privileges
	NSManagedObjectContext *moc = self.managedObjectContext;
	NSEntityDescription *privEntityDescription = [NSEntityDescription entityForName:@"Privileges"
															 inManagedObjectContext:moc];
	NSArray *props = [privEntityDescription attributeKeys];
	[availablePrivs removeAllObjects];
	
	for (NSString *prop in props)
	{
		if ([prop hasSuffix:@"_priv"] && [[self.privsSupportedByServer objectForKey:prop] boolValue])
		{
			NSString *displayName = [[prop stringByReplacingOccurrencesOfString:@"_priv"
																	 withString:@""] replaceUnderscoreWithSpace];
			[availablePrivs addObject:[NSDictionary dictionaryWithObjectsAndKeys:displayName, @"displayName", prop, @"name", nil]];				
		}

	}
	
	[availableController rearrangeObjects];
}

/**
 * Initialize the available schema privileges.
 */
- (void)_initializeSchemaPrivs
{
	// Initialize Databases
	[schemas removeAllObjects];
	
	MCPResult *results = [self.mySqlConnection listDBs];
	
	if ([results numOfRows]) {
		[results dataSeek:0];
	}
	
	for (NSInteger i = 0; i < [results numOfRows]; i++) {
		[schemas addObject:[results fetchRowAsDictionary]];
	}
	
	[schemaController rearrangeObjects];
	
	[self _initializeAvailablePrivs];	
}

/**
 * Set NSManagedObject with values from the passed in dictionary.
 */
- (void)_initializeChild:(NSManagedObject *)child withItem:(NSDictionary *)item
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
			NSNumber *value = [NSNumber numberWithInteger:[[item objectForKey:key] integerValue]];
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
 * Initialize the schema privileges for the supplied child object.
 */
- (void)_initializeSchemaPrivsForChild:(NSManagedObject *)child
{
	// Assumes that the child has already been initialized with values from the
	// global user table.
	// Select rows from the db table that contains schema privs for each user/host
	NSString *queryString = [NSString stringWithFormat:@"SELECT * from `mysql`.`db` d WHERE d.user = %@ and d.host = %@", 
							 [[[child parent] valueForKey:@"user"] tickQuotedString], [[child valueForKey:@"host"] tickQuotedString]];
	MCPResult *queryResults = [self.mySqlConnection queryString:queryString];
	if ([queryResults numOfRows] > 0)
	{
		// Go to the beginning
		[queryResults dataSeek:0];
	}
	
	for (NSInteger i = 0; i < [queryResults numOfRows]; i++) {
		NSDictionary *rowDict = [queryResults fetchRowAsDictionary];
		NSManagedObject *dbPriv = [NSEntityDescription insertNewObjectForEntityForName:@"Privileges"
																inManagedObjectContext:[self managedObjectContext]];
		for (NSString *key in rowDict)
		{
			if ([key hasSuffix:@"_priv"])
			{
				BOOL boolValue = [[rowDict objectForKey:key] boolValue];
				// Special case keys
				if ([privColumnToGrantMap objectForKey:key])
				{
					key = [privColumnToGrantMap objectForKey:key];
				}
				[dbPriv setValue:[NSNumber numberWithBool:boolValue] forKey:key];
			} else if (![key isEqualToString:@"Host"] && ![key isEqualToString:@"User"]) {
				[dbPriv setValue:[rowDict objectForKey:key] forKey:key];
			}
		}
		NSMutableSet *privs = [child mutableSetValueForKey:@"schema_privileges"];
		[privs addObject:dbPriv];
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
	if ([[treeController selectedObjects] count] == 0) return;
	
	id selectedObject = [[treeController selectedObjects] objectAtIndex:0];
	
	if ([selectedObject parent] == nil && !([[[tabView selectedTabViewItem] identifier] isEqualToString:@"General"])) {
		[tabView selectTabViewItemWithIdentifier:@"General"];
	}
	else {
		if ([selectedObject parent] != nil && [[[tabView selectedTabViewItem] identifier] isEqualToString:@"General"]) {
			[tabView selectTabViewItemWithIdentifier:@"Global Privileges"];
		}
	}
	
	if ([selectedObject parent] != nil && [selectedObject host] == nil)
	{
		[selectedObject setValue:@"%" forKey:@"host"];
		[outlineView reloadItem:selectedObject];
	}
	[schemasTableView deselectAll:nil];
	[grantedTableView deselectAll:nil];
	[availableTableView deselectAll:nil];
}

-(BOOL)selectionShouldChangeInOutlineView:(NSOutlineView *)outlineView
{
	if ([[treeController selectedObjects] count] > 0)
	{
		id selectedObject = [[treeController selectedObjects] objectAtIndex:0];
		// Check parents
		if ([selectedObject valueForKey:@"parent"] == nil)
		{
			NSString *name = [selectedObject valueForKey:@"user"];
			NSArray *results = [self _fetchUserWithUserName:name];
			if ([results count] > 1)
			{
				NSAlert *alert = [NSAlert alertWithMessageText:@"Duplicate User"
												 defaultButton:NSLocalizedString(@"OK", @"OK button")
											   alternateButton:nil
												   otherButton:nil
									 informativeTextWithFormat:@"A user with that name already exists"];
				[alert runModal];
				return NO;
			}
		}
		else
		{
			NSArray *children = [selectedObject valueForKeyPath:@"parent.children"];
			NSString *host = [selectedObject valueForKey:@"host"];
			for (NSManagedObject *child in children)
			{
				if (![selectedObject isEqual:child] && [[child valueForKey:@"host"] isEqualToString:host])
				{
					NSAlert *alert = [NSAlert alertWithMessageText:@"Duplicate Host"
													 defaultButton:NSLocalizedString(@"OK", @"OK button")
												   alternateButton:nil
													   otherButton:nil
										 informativeTextWithFormat:@"A user with that host already exists"];
					[alert runModal];
					return NO;
				}
			}
		}
		
	}
	
	return YES;
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
    
    //Change the first responder to end editing in any field
    [[self window] makeFirstResponder:self];
    
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

/**
 * Adds a new user to the current database.
 */
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
    [[self window] makeFirstResponder:userNameTextField];
}

/**
 * Removes the currently selected user from the current database.
 */
- (IBAction)removeUser:(id)sender
{
    NSString *username = [[[treeController selectedObjects] objectAtIndex:0]
                          valueForKey:@"originaluser"];
    NSArray *children = [[[treeController selectedObjects] objectAtIndex:0] 
                         valueForKey:@"children"];

	// On all the children - host entries - set the username to be deleted,
	// for later query contruction.
    for(NSManagedObject *child in children)
    {
        [child setPrimitiveValue:username forKey:@"user"];
    }
	
	// Unset the host on the user, so that only the host entries are dropped
	[[[treeController selectedObjects] objectAtIndex:0] setPrimitiveValue:nil forKey:@"host"];

	[treeController remove:sender];
}

/**
 * Adds a new host to the currently selected user.
 */
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

/**
 * Perform a deferred edit of the currently selected row.
 */ 
- (void)editNewHost
{
	[outlineView editColumn:0 row:[outlineView selectedRow]	withEvent:nil select:TRUE];		
}

/**
 * Removes the currently selected host from it's parent user.
 */
- (IBAction)removeHost:(id)sender
{
    // Set the username on the child so that it's accessabile when building
    // the drop sql command
    NSManagedObject *child = [[treeController selectedObjects] objectAtIndex:0];
    NSManagedObject *parent = [child valueForKey:@"parent"];
    [child setPrimitiveValue:[[child valueForKey:@"parent"] valueForKey:@"user"] forKey:@"user"];
	[treeController remove:sender];
	
    if ([[parent valueForKey:@"children"] count] == 0)
    {
        NSAlert *alert = [NSAlert alertWithMessageText:@"User doesn't have any hosts."
                                         defaultButton:NSLocalizedString(@"OK", @"OK button")
                                       alternateButton:nil
                                           otherButton:nil
                             informativeTextWithFormat:@"This user doesn't have any hosts associated with it. User will be deleted unless one is added"];
        [alert runModal];
    }
}

/**
 * Adds a new schema privilege.
 */
- (IBAction)addSchemaPriv:(id)sender
{
	NSArray *selectedObjects = [availableController selectedObjects];
	[grantedController addObjects:selectedObjects];
	[grantedTableView reloadData];
	[availableController removeObjects:selectedObjects];
	[availableTableView reloadData];
	[self _setSchemaPrivValues:selectedObjects enabled:YES];
}

/**
 * Removes a schema privilege.
 */
- (IBAction)removeSchemaPriv:(id)sender
{
	NSArray *selectedObjects = [grantedController selectedObjects];
	[availableController addObjects:selectedObjects];
	[availableTableView reloadData];
	[grantedController removeObjects:selectedObjects];
	[grantedTableView reloadData];
	[self _setSchemaPrivValues:selectedObjects enabled:NO];
}

/**
 * Refreshes the current list of users.
 */
- (IBAction)refresh:(id)sender
{
	if ([self.managedObjectContext hasChanges])
	{
		NSAlert *alert = [NSAlert alertWithMessageText:@"Warning!"
										 defaultButton:NSLocalizedString(@"Continue", @"continue button")
									   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
										   otherButton:nil
							 informativeTextWithFormat:@"Window has changes.  All changes will be lost!"];
		
		[alert setAlertStyle:NSWarningAlertStyle];
		
		if ([alert runModal] == NSAlertAlternateReturn) // cancel
		{
			return;			
		}
	}
	
	[self.managedObjectContext reset];
	[grantedSchemaPrivs removeAllObjects];
	[grantedTableView reloadData];
	[self _initializeAvailablePrivs];	
	[treeController fetch:nil];

	// After the reset, ensure all original password and user values are up-to-date.
	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"SPUser"
														 inManagedObjectContext:self.managedObjectContext];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:entityDescription];
	NSArray *userArray = [self.managedObjectContext executeFetchRequest:request error:nil];
	for (NSManagedObject *user in userArray) {
		if (![user parent]) {
			[user setValue:[user valueForKey:@"user"] forKey:@"originaluser"];
			[user setValue:[user valueForKey:@"password"] forKey:@"originalpassword"];
		}
	}
}

- (void)_setSchemaPrivValues:(NSArray *)objects enabled:(BOOL)enabled
{
	// The passed in objects should be an array of NSDictionaries with a key
	// of "name".
	NSManagedObject *selectedHost = [[treeController selectedObjects] objectAtIndex:0];
	NSString *selectedDb = [[[schemaController selectedObjects] objectAtIndex:0] valueForKey:@"Database"];
	NSArray *selectedPrivs = [self _fetchPrivsWithUser:[selectedHost valueForKeyPath:@"parent.user"] 
												schema:selectedDb 
												  host:[selectedHost valueForKey:@"host"]];
	NSManagedObject *priv = nil;
	BOOL isNew = FALSE;
	
	if ([selectedPrivs count] > 0)
	{
		priv = [selectedPrivs objectAtIndex:0];
	} 
	else 
	{
		priv = [NSEntityDescription insertNewObjectForEntityForName:@"Privileges"
											 inManagedObjectContext:[self managedObjectContext]];
		[priv setValue:selectedDb forKey:@"db"];
		isNew = TRUE;
	}

	// Now setup all the items that are selected to true
	for (NSDictionary *obj in objects)
	{
		[priv setValue:[NSNumber numberWithBool:enabled] forKey:[obj valueForKey:@"name"]];
	}
	
	if (isNew)
	{
		// Set up relationship
		NSMutableSet *privs = [selectedHost mutableSetValueForKey:@"schema_privileges"];
		[privs addObject:priv];		
	}
}

- (void)_clearData
{
	[managedObjectContext reset];
	[managedObjectContext release];
	managedObjectContext = nil;
}

/**
 * Menu item validation.
 */
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
	
	return YES;
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

- (void)userManagerSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void*)context
{
	[self refresh:nil];
}

- (BOOL)updateUsers:(NSArray *)updatedUsers
{
	for (NSManagedObject *user in updatedUsers) 
	{
		if ([[[user entity] name] isEqualToString:@"Privileges"])
		{
			[self grantDbPrivilegesWithPrivilege:user];


		// If the parent user has changed, either the username or password have been edited.
		}
		else if (![user parent])
		{
			NSArray *hosts = [user valueForKey:@"children"];

			// If the user has been changed, update the username on all hosts.  Don't check for errors, as some
			// hosts may be new.
			if (![[user valueForKey:@"user"] isEqualToString:[user valueForKey:@"originaluser"]]) {
				for (NSManagedObject *child in hosts) {
					NSString *renameUserStatement = [NSString stringWithFormat:
														@"RENAME USER %@@%@ TO %@@%@",
														 [[user valueForKey:@"originaluser"] tickQuotedString],
														 [[child host] tickQuotedString],
														 [[user valueForKey:@"user"] tickQuotedString],
														 [[child host] tickQuotedString]];
					[self.mySqlConnection queryString:renameUserStatement];	
				}
			}

			// If the password has been changed, use the same password on all hosts
			if (![[user valueForKey:@"password"] isEqualToString:[user valueForKey:@"originalpassword"]]) {
				for (NSManagedObject *child in hosts) {
					NSString *changePasswordStatement = [NSString stringWithFormat:
														 @"SET PASSWORD FOR %@@%@ = PASSWORD(%@)",
														 [[user valueForKey:@"user"] tickQuotedString],
														 [[child host] tickQuotedString],
														 [[user valueForKey:@"password"] tickQuotedString]];
					[self.mySqlConnection queryString:changePasswordStatement];	
					[self checkAndDisplayMySqlError];
				}
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
        if (![[[user entity] name] isEqualToString:@"Privileges"] && [user valueForKey:@"host"] != nil)
		{
			[droppedUsers appendString:[NSString stringWithFormat:@"%@@%@, ", 
										[[user valueForKey:@"user"] tickQuotedString], 
										[[user valueForKey:@"host"] tickQuotedString]]];
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
		if ([[[user entity] name] isEqualToString:@"Privileges"]) continue;
		
		NSString *createStatement = nil;

		if ([user parent] && [[user parent] valueForKey:@"user"] && [[user parent] valueForKey:@"password"]) 
        {
            createStatement = [NSString stringWithFormat:@"CREATE USER %@@%@ IDENTIFIED BY %@", 
                               [[[user parent] valueForKey:@"user"] tickQuotedString], 
                               [[user valueForKey:@"host"] tickQuotedString],
                               [[[user parent] valueForKey:@"password"] tickQuotedString]];
		}
        else
        {
            if ([user parent] && [[user parent] valueForKey:@"user"])
            {
                createStatement = [NSString stringWithFormat:@"CREATE USER %@@%@",
                                   [[[user parent] valueForKey:@"user"] tickQuotedString],
                                   [[user valueForKey:@"host"] tickQuotedString]];
            }
        }
        
        if (createStatement)
        {
            // Create user in database
            [self.mySqlConnection queryString:createStatement];
            
            if ([self checkAndDisplayMySqlError]) 
                [self grantPrivilegesToUser:user];
        }	
	}
	
	return YES;
}

/**
 * Grant or revoke DB privileges for the supplied user.
 */
- (BOOL)grantDbPrivilegesWithPrivilege:(NSManagedObject *)schemaPriv
{
	NSMutableArray *grantPrivileges = [NSMutableArray array];
	NSMutableArray *revokePrivileges = [NSMutableArray array];
	
	NSString *dbName = [schemaPriv valueForKey:@"db"];
	
	NSString *statement = [NSString stringWithFormat:@"SELECT USER,HOST FROM `mysql`.`db` WHERE USER=%@ AND HOST=%@ AND DB=%@",
									  [[schemaPriv valueForKeyPath:@"user.parent.user"] tickQuotedString],
									  [[schemaPriv valueForKeyPath:@"user.host"] tickQuotedString],
									  [dbName tickQuotedString]];
	MCPResult *result = [self.mySqlConnection queryString:statement];
	NSUInteger rows = [result numOfRows];
	BOOL userExists = YES;
	if (rows == 0)
	{
		userExists = NO;
	}
	
	for (NSString *key in self.privsSupportedByServer)
	{
		if (![key hasSuffix:@"_priv"]) continue;
		NSString *privilege = [key stringByReplacingOccurrencesOfString:@"_priv" withString:@""];
		@try {
			if ([[schemaPriv valueForKey:key] boolValue] == TRUE)
			{
				[grantPrivileges addObject:[privilege replaceUnderscoreWithSpace]];
			}
			else {
				if (userExists || [grantPrivileges count] > 0) {
					[revokePrivileges addObject:[privilege replaceUnderscoreWithSpace]];
				}
				
			}
		}
		@catch (NSException * e) {
		}
	}
	
	// Grant privileges
	if ([grantPrivileges count] > 0)
	{
		NSString *grantStatement = [NSString stringWithFormat:@"GRANT %@ ON %@.* TO %@@%@",
									[[grantPrivileges componentsJoinedByCommas] uppercaseString],
									[dbName backtickQuotedString],
									[[schemaPriv valueForKeyPath:@"user.parent.user"] tickQuotedString],
									[[schemaPriv valueForKeyPath:@"user.host"] tickQuotedString]];
		DLog(@"%@", grantStatement);
		[self.mySqlConnection queryString:grantStatement];
		[self checkAndDisplayMySqlError];
	}
	
	// Revoke privileges
	if ([revokePrivileges count] > 0)
	{
		NSString *revokeStatement = [NSString stringWithFormat:@"REVOKE %@ ON %@.* FROM %@@%@",
									 [[revokePrivileges componentsJoinedByCommas] uppercaseString],
									 [dbName backtickQuotedString],
									 [[schemaPriv valueForKeyPath:@"user.parent.user"] tickQuotedString],
									 [[schemaPriv valueForKeyPath:@"user.host"] tickQuotedString]];
		DLog(@"%@", revokeStatement);
		[self.mySqlConnection queryString:revokeStatement];
		[self checkAndDisplayMySqlError];
	}
	
	return TRUE;
}

/**
 * Grant or revoke privileges for the supplied user.
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
					[grantPrivileges addObject:[privilege replaceUnderscoreWithSpace]];
				} else {
					[revokePrivileges addObject:[privilege replaceUnderscoreWithSpace]];
				}
			}
			@catch (NSException * e) {
			}
		}
		
		// Grant privileges
		if ([grantPrivileges count] > 0)
		{
			NSString *grantStatement = [NSString stringWithFormat:@"GRANT %@ ON *.* TO %@@%@",
										[[grantPrivileges componentsJoinedByCommas] uppercaseString],
										[[[user parent] valueForKey:@"user"] tickQuotedString],
										[[user valueForKey:@"host"] tickQuotedString]];
			DLog(@"%@", grantStatement);
			[self.mySqlConnection queryString:grantStatement];
			[self checkAndDisplayMySqlError];
		}
		
		// Revoke privileges
		if ([revokePrivileges count] > 0)
		{
			NSString *revokeStatement = [NSString stringWithFormat:@"REVOKE %@ ON *.* FROM %@@%@",
										 [[revokePrivileges componentsJoinedByCommas] uppercaseString],
										 [[[user parent] valueForKey:@"user"] tickQuotedString],
										 [[user valueForKey:@"host"] tickQuotedString]];
			DLog(@"%@", revokeStatement);
			[self.mySqlConnection queryString:revokeStatement];
			[self checkAndDisplayMySqlError];
		}		
	}
	
	for (NSManagedObject *priv in [user valueForKey:@"schema_privileges"])
	{
		[self grantDbPrivilegesWithPrivilege:priv];
	}
	
	return TRUE;
}

/** 
 * Gets any NSManagedObject (SPUser) from the managedObjectContext that may
 * already exist with the given username.
 */
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

- (NSArray *)_fetchPrivsWithUser:(NSString *)username schema:(NSString *)selectedSchema host:(NSString *)host
{
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(user.parent.user like[cd] %@) AND (user.host like[cd] %@) AND (db like[cd] %@)", username, host, selectedSchema];
	NSEntityDescription *privEntity = [NSEntityDescription entityForName:@"Privileges"
														 inManagedObjectContext:moc];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	[request setEntity:privEntity];
	[request setPredicate:predicate];
	
	NSError *error = nil;
	NSArray *array = [moc executeFetchRequest:request error:&error];
	
	if (error != nil)
	{
		[[NSApplication sharedApplication] presentError:error];
	}
	
	return array;
}

/**
 * Creates a new NSManagedObject and inserts it into the managedObjectContext.
 */
- (NSManagedObject *)_createNewSPUser
{
	NSManagedObject *user = [NSEntityDescription insertNewObjectForEntityForName:@"SPUser" 
														  inManagedObjectContext:[self managedObjectContext]];	
	
	return user;
}

/**
 * Displays an alert panel if there was an error condition on the MySQL connection.
 */
- (BOOL)checkAndDisplayMySqlError
{
	if ([self.mySqlConnection queryErrored]) {
		NSAlert *alert = [NSAlert alertWithMessageText:@"MySQL Error" 
                                         defaultButton:NSLocalizedString(@"OK", @"OK button")
                                       alternateButton:nil 
                                           otherButton:nil 
                             informativeTextWithFormat:[self.mySqlConnection getLastErrorMessage]];
		[alert runModal];
		
		return NO;
	}
	
	return YES;
}

#pragma mark -
#pragma mark Tab View Delegate methods
- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    BOOL retVal = YES;
    // If there aren't any selected objects, then can't change tab view item
    if ([[treeController selectedObjects] count] == 0) return NO;
    
    // Currently selected object in tree
    id selectedObject = [[treeController selectedObjects] objectAtIndex:0];
    
    // If we are selecting a tab view that requires there be a child,
    // make sure there is a child to select.  If not, don't allow it.
    if ([[tabViewItem identifier] isEqualToString:@"Global Privileges"] 
        || [[tabViewItem identifier] isEqualToString:@"Resources"]
        || [[tabViewItem identifier] isEqualToString:@"Schema Privileges"]) {
        id parent = [selectedObject parent];
        if (parent) {
            retVal = ([[parent children] count] > 0);
        } else {
            retVal = ([[selectedObject children] count] > 0);
        }
        if (retVal == NO) {
            NSAlert *alert = [NSAlert alertWithMessageText:@"User doesn't have any hosts."
                                             defaultButton:NSLocalizedString(@"Add Host", @"Add Host")
                                           alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
                                               otherButton:nil
                                 informativeTextWithFormat:@"This user doesn't have any hosts associated with it. User will be deleted unless one is added"];
            NSInteger ret = [alert runModal];
            if (ret == NSAlertDefaultReturn) {
                [self addHost:nil];
            }
        }

    }
    return retVal;
}
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
			   || [[tabViewItem identifier] isEqualToString:@"Resources"]
			   || [[tabViewItem identifier] isEqualToString:@"Schema Privileges"]) {
		// if the tab is either Global Privs or Resources and we have a user 
		// selected, then open tree and select first child node.
		[self _selectFirstChildOfParentNode];
	}
}

- (void)tabView:(NSTabView *)usersTabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if ([[tabViewItem identifier] isEqualToString:@"Schema Privileges"]) {
		[self _initializeSchemaPrivs];
	}
}

#pragma mark -
#pragma mark SplitView delegate methods

/**
 * Return the maximum possible size of the splitview.
 */
- (CGFloat)splitView:(NSSplitView *)sender constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
	return (proposedMax - 555);
}

/**
 * Return the minimum possible size of the splitview.
 */
- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)offset
{
	return (proposedMin + 120);
}

#pragma mark -
#pragma mark TableView Delegate Methods

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	if ([notification object] == schemasTableView)
	{
		[grantedSchemaPrivs removeAllObjects];
		[grantedTableView reloadData];
		[self _initializeAvailablePrivs];
		
		if ([[treeController selectedObjects] count] > 0 && [[schemaController selectedObjects] count] > 0) {
			NSManagedObject *user = [[treeController selectedObjects] objectAtIndex:0];
			
			// Check to see if the user host node was selected
			if ([user valueForKey:@"host"]) {
				NSString *selectedSchema = [[[schemaController selectedObjects] objectAtIndex:0] valueForKey:@"Database"];
				NSArray *results = [self _fetchPrivsWithUser:[[user parent] valueForKey:@"user"] schema:selectedSchema host:[user valueForKey:@"host"]];
				
				if ([results count] > 0) {
					NSManagedObject *priv = [results objectAtIndex:0];
					
					for (NSPropertyDescription *property in [priv entity])
					{
						if ([[property name] hasSuffix:@"_priv"] && [[priv valueForKey:[property name]] boolValue])
						{
							NSString *displayName = [[[property name] stringByReplacingOccurrencesOfString:@"_priv"
																							   withString:@""] replaceUnderscoreWithSpace];
							NSDictionary *newDict = [NSDictionary dictionaryWithObjectsAndKeys:displayName, @"displayName", [property name], @"name", nil];
							[grantedController addObject:newDict];
							
							// Remove items from available so they can't be added twice.
							NSPredicate *predicate = [NSPredicate predicateWithFormat:@"displayName like[cd] %@", displayName];
							NSArray *previousObjects = [[availableController arrangedObjects] filteredArrayUsingPredicate:predicate];
							for (NSDictionary *dict in previousObjects)
							{
								[availableController removeObject:dict];
							}
						}
					}
				}
                [availableTableView setEnabled:YES];
			}
		} else {
            [availableTableView setEnabled:NO];
        }

	}
	else if ([notification object] == grantedTableView)
	{
		if ([[grantedController selectedObjects] count] > 0)
		{
			[removeSchemaPrivButton setEnabled:YES];
			
		} else {
			[removeSchemaPrivButton setEnabled:NO];
		}

	
	}
	else if ([notification object] == availableTableView)
	{
		if ([[availableController selectedObjects] count] > 0)
		{
			[addSchemaPrivButton setEnabled:YES];			
		} else {
			[addSchemaPrivButton setEnabled:NO];
		}

	}		
}

#pragma mark -

/**
 * Dealloc. Get rid of everything.
 */
- (void)dealloc
{	
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [managedObjectContext release];
    [persistentStoreCoordinator release];
    [managedObjectModel release];
	[privColumnToGrantMap release];
	[mySqlConnection release];
	[privsSupportedByServer release];
	[schemas release];
	[availablePrivs release];
	[grantedSchemaPrivs release];
	[treeSortDescriptor release];
	
	[super dealloc];
}

@end
