//
//  SPUserManager.m
//  sequel-pro
//
//  Created by Mark Townsend on Jan 1, 2009.
//  Copyright (c) 2009 Mark Townsend. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <https://github.com/sequelpro/sequelpro>

#import "SPUserManager.h"
#import "SPUserMO.h"
#import "SPPrivilegesMO.h"
#import "ImageAndTextCell.h"
#import "SPGrowlController.h"
#import "SPConnectionController.h"
#import "SPServerSupport.h"
#import "SPAlertSheets.h"
#import "SPSplitView.h"
#import "SPDatabaseDocument.h"

#import <SPMySQL/SPMySQL.h>
#import <QueryKit/QueryKit.h>

static NSString * const SPTableViewNameColumnID = @"NameColumn";

static NSString *SPGeneralTabIdentifier = @"General";
static NSString *SPGlobalPrivilegesTabIdentifier = @"Global Privileges";
static NSString *SPResourcesTabIdentifier = @"Resources";
static NSString *SPSchemaPrivilegesTabIdentifier = @"Schema Privileges";


@interface SPUserManager ()

- (void)_initializeTree:(NSArray *)items;
- (void)_initializeUsers;
- (void)_selectParentFromSelection;
- (NSArray *)_fetchUserWithUserName:(NSString *)username;
- (SPUserMO *)_createNewSPUser;
- (BOOL)_grantPrivileges:(NSArray *)thePrivileges onDatabase:(NSString *)aDatabase forUser:(NSString *)aUser host:(NSString *)aHost;
- (BOOL)_revokePrivileges:(NSArray *)thePrivileges onDatabase:(NSString *)aDatabase forUser:(NSString *)aUser host:(NSString *)aHost;
- (BOOL)_checkAndDisplayMySqlError;
- (void)_clearData;
- (void)_initializeChild:(NSManagedObject *)child withItem:(NSDictionary *)item;
- (void)_initializeSchemaPrivsForChild:(SPUserMO *)child fromData:(NSArray *)dataForUser;
- (void)_initializeSchemaPrivs;
- (NSArray *)_fetchPrivsWithUser:(NSString *)username schema:(NSString *)selectedSchema host:(NSString *)host;
- (void)_setSchemaPrivValues:(NSArray *)objects enabled:(BOOL)enabled;
- (void)_initializeAvailablePrivs;
- (BOOL)_renameUserFrom:(NSString *)originalUser host:(NSString *)originalHost to:(NSString *)newUser host:(NSString *)newHost;
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void*)context;
- (void)contextWillSave:(NSNotification *)notice;
- (void)_selectFirstChildOfParentNode;

@end

@implementation SPUserManager

@synthesize connection;
@synthesize databaseDocument;
@synthesize privsSupportedByServer;
@synthesize managedObjectContext;
@synthesize managedObjectModel;
@synthesize persistentStoreCoordinator;
@synthesize schemas;
@synthesize grantedSchemaPrivs;
@synthesize availablePrivs;
@synthesize treeSortDescriptors;
@synthesize serverSupport;
@synthesize isInitializing = isInitializing;

#pragma mark -
#pragma mark Initialisation

- (id)init
{
	if ((self = [super initWithWindowNibName:@"UserManagerView"])) {
		
		// When reading privileges from the database, they are converted automatically to a
		// lowercase key used in the user privileges stores, from which a GRANT syntax
		// is derived automatically.  While most keys can be automatically converted without
		// any difficulty, some keys differ slightly in mysql column storage to GRANT syntax;
		// this dictionary provides mappings for those values to ensure consistency.
		
		// key is:   The name of the actual column in the mysql.users / mysql.db table
		// value is: The "Privilege" value from "SHOW PRIVILEGES" with " " replaced by "_" and "_priv" appended
		privColumnToGrantMap = [@{
			@"Grant_priv":               @"Grant_option_priv",
			@"Show_db_priv":             @"Show_databases_priv",
			@"Create_tmp_table_priv":    @"Create_temporary_tables_priv",
			@"Repl_slave_priv":          @"Replication_slave_priv",
			@"Repl_client_priv":         @"Replication_client_priv",
			@"Truncate_versioning_priv": @"Delete_versioning_rows_priv", // MariaDB only, 10.3.4 only
			@"Delete_history_priv":      @"Delete_versioning_rows_priv", // MariaDB only, since 10.3.5
		} retain];
	
		schemas = [[NSMutableArray alloc] init];
		availablePrivs = [[NSMutableArray alloc] init];
		grantedSchemaPrivs = [[NSMutableArray alloc] init];
		isSaving = NO;
	}
	
	return self;
}

/** 
 * UI specific items to set up when the window loads. This is different than awakeFromNib 
 * as it's only called once.
 */
- (void)windowDidLoad
{
	[tabView selectTabViewItemAtIndex:0];

	[splitView setMinSize:120.f ofSubviewAtIndex:0];
	[splitView setMinSize:620.f ofSubviewAtIndex:1];

	NSTableColumn *tableColumn = [outlineView tableColumnWithIdentifier:SPTableViewNameColumnID];
	ImageAndTextCell *imageAndTextCell = [[[ImageAndTextCell alloc] init] autorelease];
	
	[imageAndTextCell setEditable:NO];
	[tableColumn setDataCell:imageAndTextCell];

	// Set schema table double-click actions
	[grantedTableView setDoubleAction:@selector(doubleClickSchemaPriv:)];
	[availableTableView setDoubleAction:@selector(doubleClickSchemaPriv:)];

	[self _initializeSchemaPrivs];
	[self _initializeUsers];
	[self _initializeAvailablePrivs];	

	treeSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"displayName" ascending:YES];
	
	[self setTreeSortDescriptors:@[treeSortDescriptor]];
		
	[super windowDidLoad];
}

/**
 * This method reads in the users from the mysql.user table of the current
 * connection. Then uses this information to initialize the NSOutlineView.
 */
- (void)_initializeUsers
{
	isInitializing = YES; // Don't want to do some of the notifications if initializing
	
	@autoreleasepool {
		NSArray *privRow;
		NSMutableArray *usersResultArray = [NSMutableArray array];

		// Select users from the mysql.user table
		SPMySQLResult *result = [connection queryString:@"SELECT * FROM mysql.user ORDER BY user"];
		[result setReturnDataAsStrings:YES];
		//TODO: improve user feedback
		NSAssert(([[result fieldNames] firstObjectCommonWithArray:@[@"Password",@"authentication_string"]] != nil), @"Resultset from mysql.user contains neither 'Password' nor 'authentication_string' column!?");
		requiresPost576PasswordHandling = ![[result fieldNames] containsObject:@"Password"];
		[usersResultArray addObjectsFromArray:[result getAllRows]];

		[self _initializeTree:usersResultArray];

		// Set up the array of privs supported by this server.
		[[self privsSupportedByServer] removeAllObjects];

		result = nil;

		// Attempt to obtain user privileges if supported
		if ([serverSupport supportsShowPrivileges]) {

			result = [connection queryString:@"SHOW PRIVILEGES"];
			[result setReturnDataAsStrings:YES];
		}

		if (result && [result numberOfRows]) {
			while ((privRow = [result getRowAsArray]))
			{
				NSMutableString *privKey = [NSMutableString stringWithString:[[privRow objectAtIndex:0] lowercaseString]];

				// Skip the special "Usage" key
				if ([privKey isEqualToString:@"usage"]) continue;

				[privKey replaceOccurrencesOfString:@" " withString:@"_" options:NSLiteralSearch range:NSMakeRange(0, [privKey length])];
				[privKey appendString:@"_priv"];

				[[self privsSupportedByServer] setValue:@YES forKey:privKey];
			}
		}
		// If that fails, base privilege support on the mysql.users columns
		else {
			result = [connection queryString:@"SHOW COLUMNS FROM mysql.user"];

			[result setReturnDataAsStrings:YES];

			while ((privRow = [result getRowAsArray]))
			{
				NSMutableString *privKey = [NSMutableString stringWithString:[privRow objectAtIndex:0]];

				if (![privKey hasSuffix:@"_priv"]) continue;

				if ([privColumnToGrantMap objectForKey:privKey]) privKey = [privColumnToGrantMap objectForKey:privKey];

				[[self privsSupportedByServer] setValue:@YES forKey:[privKey lowercaseString]];
			}
		}
	}
	
	isInitializing = NO;
}

/**
 * Initialize the outline view tree. The NSOutlineView gets it's data from a NSTreeController which gets
 * it's data from the SPUser Entity objects in the current managedObjectContext.
 */
- (void)_initializeTree:(NSArray *)items
{
	// Retrieve all the user data in order to be able to initialise the schema privs for each child,
	// copying into a dictionary keyed by user, each with all the host rows.
	NSMutableDictionary *schemaPrivilegeData = [NSMutableDictionary dictionary];
	SPMySQLResult *queryResults = [connection queryString:@"SELECT * FROM mysql.db"];

	[queryResults setReturnDataAsStrings:YES];

	for (NSDictionary *privRow in queryResults)
	{
		if (![schemaPrivilegeData objectForKey:[privRow objectForKey:@"User"]]) {
			[schemaPrivilegeData setObject:[NSMutableArray array] forKey:[privRow objectForKey:@"User"]];
		}

		[[schemaPrivilegeData objectForKey:[privRow objectForKey:@"User"]] addObject:privRow];

		// If "all database" values were found, add them to the schemas list if not already present
		NSString *schemaName = [privRow objectForKey:@"Db"];

		if ([schemaName isEqualToString:@""] || [schemaName isEqualToString:@"%"]) {
			if (![schemas containsObject:schemaName]) {
				[schemas addObject:schemaName];
				[schemasTableView noteNumberOfRowsChanged];
			}
		}
	}

	// Go through each item that contains a dictionary of key-value pairs
	// for each user currently in the database.
	for (NSUInteger i = 0; i < [items count]; i++)
	{
		NSDictionary *item = [items objectAtIndex:i];
		NSString *username = [item objectForKey:@"User"];
		NSArray *parentResults = [[self _fetchUserWithUserName:username] retain];
		SPUserMO *parent;
		SPUserMO *child;
		
		// Check to make sure if we already have added the parent
		if (parentResults != nil && [parentResults count] > 0) {
			
			// Add Children
			parent = [parentResults objectAtIndex:0];
			child = [self _createNewSPUser];
		} 
		else {
			// Add Parent
			parent = [self _createNewSPUser];
			child = [self _createNewSPUser];
			
			// We only care about setting the user and password keys on the parent, together with their
			// original values for comparison purposes
			[parent setPrimitiveValue:username forKey:@"user"];
			[parent setPrimitiveValue:username forKey:@"originaluser"];

			if (requiresPost576PasswordHandling) {
				[parent setPrimitiveValue:[item objectForKey:@"plugin"] forKey:@"plugin"];

				NSString *passwordHash = [item objectForKey:@"authentication_string"];

				if (![passwordHash isNSNull]) {
					[parent setPrimitiveValue:passwordHash forKey:@"authentication_string"];

					// for the UI dialog
					if ([passwordHash length]) {
						[parent setPrimitiveValue:@"sequelpro_dummy_password" forKey:@"password"];
					}
				}
			}
			else {
				[parent setPrimitiveValue:[item objectForKey:@"Password"] forKey:@"password"];
				[parent setPrimitiveValue:[item objectForKey:@"Password"] forKey:@"originalpassword"];
			}
		}

		// Setup the NSManagedObject with values from the dictionary
		[self _initializeChild:child withItem:item];
		
		NSMutableSet *children = [parent mutableSetValueForKey:@"children"];
		[children addObject:child];
		
		[self _initializeSchemaPrivsForChild:child fromData:[schemaPrivilegeData objectForKey:username]];
		
		// Save the initialized objects so that any new changes will be tracked.
		NSError *error = nil;
		
		[[self managedObjectContext] save:&error];
		
		if (error != nil) {
			[NSApp presentError:error];
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
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSEntityDescription *privEntityDescription = [NSEntityDescription entityForName:@"Privileges" inManagedObjectContext:moc];
	NSArray *props = [privEntityDescription attributeKeys];
	
	[availablePrivs removeAllObjects];
	
	for (NSString *prop in props)
	{
		if ([prop hasSuffix:@"_priv"] && [[[self privsSupportedByServer] objectForKey:prop] boolValue]) {
			NSString *displayName = [[prop stringByReplacingOccurrencesOfString:@"_priv" withString:@""] replaceUnderscoreWithSpace];
			
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
	[schemas addObjectsFromArray:[databaseDocument allDatabaseNames]];

	[schemasTableView reloadData];
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
		else if (![key isInArray:@[@"User",@"Password",@"plugin",@"authentication_string"]])
		{
			NSString *value = [item objectForKey:key];
			[child setValue:value forKey:key];
		}
		NS_HANDLER
		NS_ENDHANDLER
	}
}

/**
 * Initialize the schema privileges for the supplied child object.
 *
 * Assumes that the child has already been initialized with values from the
 * global user table.
 */
- (void)_initializeSchemaPrivsForChild:(SPUserMO *)child fromData:(NSArray *)dataForUser
{
	NSMutableSet *privs = [child mutableSetValueForKey:@"schema_privileges"];

	// Set an originalhost key on the child to allow the tracking of edits
	[child setPrimitiveValue:[child valueForKey:@"host"] forKey:@"originalhost"];

	for (NSDictionary *rowDict in dataForUser) 
	{

		// Verify that the host matches, or skip this entry
		if (![[rowDict objectForKey:@"Host"] isEqualToString:[child valueForKey:@"host"]]) {
			continue;
		}

		SPPrivilegesMO *dbPriv = [NSEntityDescription insertNewObjectForEntityForName:@"Privileges" inManagedObjectContext:[self managedObjectContext]];
		
		for (NSString *key in rowDict)
		{
			if ([key hasSuffix:@"_priv"]) {
				
				BOOL boolValue = [[rowDict objectForKey:key] boolValue];
				
				// Special case keys
				if ([privColumnToGrantMap objectForKey:key]) {
					key = [privColumnToGrantMap objectForKey:key];
				}
				
				[dbPriv setValue:[NSNumber numberWithBool:boolValue] forKey:key];
			} 
			else if ([key isEqualToString:@"Db"]) {
				NSString *db = [[rowDict objectForKey:key] stringByReplacingOccurrencesOfString:@"\\_" withString:@"_"];
                [dbPriv setValue:db forKey:key];
            } 
			else if (![key isEqualToString:@"Host"] && ![key isEqualToString:@"User"]) {
				[dbPriv setValue:[rowDict objectForKey:key] forKey:key];
			}
		}
		[privs addObject:dbPriv];
	}
}

/**
 * Creates, retains, and returns the managed object model for the application 
 * by merging all of the models found in the application bundle.
 */
- (NSManagedObjectModel *)managedObjectModel 
{	
	if (!managedObjectModel) {
		managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];
	}
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
	
    NSError *error = nil;
    
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
	
    if (![persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:&error] && error) {
        [NSApp presentError:error];
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
        [managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(contextWillSave:)
												 name:NSManagedObjectContextWillSaveNotification
											   object:managedObjectContext];
    
    return managedObjectContext;
}

- (void)beginSheetModalForWindow:(NSWindow *)docWindow completionHandler:(void (^)())callback
{
	//copy block from stack to heap, otherwise it wouldn't live long enough to be invoked later.
	void *heapCallback = callback? Block_copy(callback) : NULL;
	
	[NSApp beginSheet:[self window]
	   modalForWindow:docWindow
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:heapCallback];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void*)context
{
	//[NSApp endSheet...] does not close the window
	[[self window] orderOut:self];
	//notify delegate
	if(context) {
		void (^callback)() = context;
		//directly invoking callback would risk that we are dealloc'd while still in this run loop iteration.
		dispatch_async(dispatch_get_main_queue(), callback);
		Block_release(callback);
	}
}

#pragma mark -
#pragma mark General IBAction methods

/**
 * Closes the user manager and reverts any changes made.
 */
- (IBAction)doCancel:(id)sender
{
	// Discard any pending changes
	[treeController discardEditing];

	// Change the first responder to end editing in any field
	[[self window] makeFirstResponder:self];

	[[self managedObjectContext] rollback];
	
	// Close sheet
	[NSApp endSheet:[self window] returnCode:0];
}

/**
 * Closes the user manager and applies any changes made.
 */
- (IBAction)doApply:(id)sender
{
	// If editing can't be committed, cancel the apply
	if (![treeController commitEditing]) {
		return;
	}

	errorsString = [[NSMutableString alloc] init];
    
	// Change the first responder to end editing in any field
	[[self window] makeFirstResponder:self];

	isSaving = YES;

	NSError *error = nil;
	
	[[self managedObjectContext] save:&error];
	
	isSaving = NO;
	
	if (error) [errorsString appendString:[error localizedDescription]];

	[connection queryString:@"FLUSH PRIVILEGES"];

	// Display any errors
	if ([errorsString length]) {
		[errorsTextView setString:errorsString];
		
		[NSApp beginSheet:errorsSheet 
		   modalForWindow:[NSApp keyWindow] 
			modalDelegate:nil 
		   didEndSelector:NULL 
			  contextInfo:nil];
		
		SPClear(errorsString);
		
		return;
	}
	
	SPClear(errorsString);

	// Otherwise, close the sheet
	[NSApp endSheet:[self window] returnCode:0];
}

/**
 * Enables all privileges.
 */
- (IBAction)checkAllPrivileges:(id)sender
{
	id selectedUser = [[treeController selectedObjects] objectAtIndex:0];

	// Iterate through the supported privs, setting the value of each to YES
	for (NSString *key in [self privsSupportedByServer]) 
	{
		if (![key hasSuffix:@"_priv"]) continue;

		// Perform the change in a try/catch check to avoid exceptions for unhandled privs
		NS_DURING
			[selectedUser setValue:@YES forKey:key];
		NS_HANDLER
		NS_ENDHANDLER
	}
}

/**
 * Disables all privileges.
 */
- (IBAction)uncheckAllPrivileges:(id)sender
{
	id selectedUser = [[treeController selectedObjects] objectAtIndex:0];

	// Iterate through the supported privs, setting the value of each to NO
	for (NSString *key in [self privsSupportedByServer]) 
	{
		if (![key hasSuffix:@"_priv"]) continue;

		// Perform the change in a try/catch check to avoid exceptions for unhandled privs
		NS_DURING
			[selectedUser setValue:@NO forKey:key];
		NS_HANDLER
		NS_ENDHANDLER
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
	
	SPUserMO *newItem = [self _createNewSPUser];
	SPUserMO *newChild = [self _createNewSPUser];
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
    NSString *username = [[[treeController selectedObjects] objectAtIndex:0] valueForKey:@"originaluser"];
    NSArray *children = [[[treeController selectedObjects] objectAtIndex:0] valueForKey:@"children"];

	// On all the children - host entries - set the username to be deleted,
	// for later query contruction.
    for (NSManagedObject *child in children)
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
	[outlineView editColumn:0 row:[outlineView selectedRow]	withEvent:nil select:YES];		
}

/**
 * Removes the currently selected host from it's parent user.
 */
- (IBAction)removeHost:(id)sender
{
    // Set the username on the child so that it's accessabile when building
    // the drop sql command
    SPUserMO *child = [[treeController selectedObjects] objectAtIndex:0];
    SPUserMO *parent = [child parent];
	
    [child setPrimitiveValue:[[child valueForKey:@"parent"] valueForKey:@"user"] forKey:@"user"];
	
	[treeController remove:sender];
	
    if ([[parent valueForKey:@"children"] count] == 0)
    {
		SPOnewayAlertSheet(
			NSLocalizedString(@"Unable to remove host", @"error removing host message"),
			[self window],
			NSLocalizedString(@"This user doesn't seem to have any associated hosts and will be removed unless a host is added.", @"error removing host informative message")
		);
    }
}

/**
 * Adds a new schema privilege.
 */
- (IBAction)addSchemaPriv:(id)sender
{
	NSArray *selectedObjects = [availableController selectedObjects];
	
	[grantedController addObjects:selectedObjects];
	[grantedTableView noteNumberOfRowsChanged];
	[availableController removeObjects:selectedObjects];
	[availableTableView noteNumberOfRowsChanged];
	[schemasTableView setNeedsDisplay:YES];
	
	[self _setSchemaPrivValues:selectedObjects enabled:YES];
}

/**
 * Removes a schema privilege.
 */
- (IBAction)removeSchemaPriv:(id)sender
{
	NSArray *selectedObjects = [grantedController selectedObjects];
	
	[availableController addObjects:selectedObjects];
	[availableTableView noteNumberOfRowsChanged];
	[grantedController removeObjects:selectedObjects];
	[grantedTableView noteNumberOfRowsChanged];
	[schemasTableView setNeedsDisplay:YES];
	
	[self _setSchemaPrivValues:selectedObjects enabled:NO];
}

/**
 * Move double-clicked rows across to the other table, using the
 * appropriate methods.
 */
- (IBAction)doubleClickSchemaPriv:(id)sender
{
	// Ignore double-clicked header cells
	if ([sender clickedRow] == -1) return;

	if (sender == availableTableView) {
		[self addSchemaPriv:sender];
	} 
	else {
		[self removeSchemaPriv:sender];
	}
}

/**
 * Refreshes the current list of users.
 */
- (IBAction)refresh:(id)sender
{
	if ([[self managedObjectContext] hasChanges]) {
		
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Unsaved changes", @"unsaved changes message")
										 defaultButton:NSLocalizedString(@"Continue", @"continue button")
									   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
										   otherButton:nil
							 informativeTextWithFormat:NSLocalizedString(@"Changes have been made, which will be lost if this window is closed. Are you sure you want to continue", @"unsaved changes informative message")];
		
		[alert setAlertStyle:NSWarningAlertStyle];
		
		// Cancel
		if ([alert runModal] == NSAlertAlternateReturn) return;
	}
    
	[[self managedObjectContext] reset];
	
    [grantedSchemaPrivs removeAllObjects];
	[grantedTableView reloadData];
	
	[self _initializeAvailablePrivs];	
    
	[outlineView reloadData];
	[treeController rearrangeObjects];
    
    // Get all the stores on the current MOC and remove them.
    NSArray *stores = [[[self managedObjectContext] persistentStoreCoordinator] persistentStores];
    
	for (NSPersistentStore* store in stores)
    {
        [[[self managedObjectContext] persistentStoreCoordinator] removePersistentStore:store error:nil];
    }
	
    // Add a new store
    [[[self managedObjectContext] persistentStoreCoordinator] addPersistentStoreWithType:NSInMemoryStoreType configuration:nil URL:nil options:nil error:nil];
    
    // Reinitialize the tree with values from the database.
    [self _initializeUsers];

	// After the reset, ensure all original password and user values are up-to-date.
	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"SPUser" inManagedObjectContext:[self managedObjectContext]];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	
	[request setEntity:entityDescription];
	
	NSArray *userArray = [[self managedObjectContext] executeFetchRequest:request error:nil];
	
	for (SPUserMO *user in userArray)
	{
		if (![user parent]) {
			[user setPrimitiveValue:[user valueForKey:@"user"] forKey:@"originaluser"];
			if(!requiresPost576PasswordHandling) [user setPrimitiveValue:[user valueForKey:@"password"] forKey:@"originalpassword"];
		}
	}
}

- (void)_setSchemaPrivValues:(NSArray *)objects enabled:(BOOL)enabled
{
	// The passed in objects should be an array of NSDictionaries with a key
	// of "name".
	NSManagedObject *selectedHost = [[treeController selectedObjects] objectAtIndex:0];
	NSString *selectedDb = [schemas objectAtIndex:[schemasTableView selectedRow]];
	
	NSArray *selectedPrivs = [self _fetchPrivsWithUser:[selectedHost valueForKeyPath:@"parent.user"] 
												schema:[selectedDb stringByReplacingOccurrencesOfString:@"_" withString:@"\\_"]
												  host:[selectedHost valueForKey:@"host"]];
	
	BOOL isNew = NO;
	NSManagedObject *priv = nil;
    
	if ([selectedPrivs count] > 0){
		priv = [selectedPrivs objectAtIndex:0];
	} 
	else {
		priv = [NSEntityDescription insertNewObjectForEntityForName:@"Privileges" inManagedObjectContext:[self managedObjectContext]];
		
		[priv setValue:selectedDb forKey:@"db"];
		isNew = YES;
	}

	// Now setup all the items that are selected to their enabled value
	for (NSDictionary *obj in objects)
	{
		[priv setValue:[NSNumber numberWithBool:enabled] forKey:[obj valueForKey:@"name"]];
	}

	if (isNew) {
		// Set up relationship
		NSMutableSet *privs = [selectedHost mutableSetValueForKey:@"schema_privileges"];
		[privs addObject:priv];		
	}
}

- (void)_clearData
{
	[managedObjectContext reset];
	SPClear(managedObjectContext);
}

/**
 * Menu item validation.
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// Only allow removing hosts of a host node is selected.
	if ([menuItem action] == @selector(removeHost:)) {
		return (([[treeController selectedObjects] count] > 0) && 
				[[[treeController selectedObjects] objectAtIndex:0] parent] != nil);
	} 
	else if ([menuItem action] == @selector(addHost:)) {
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
	
		if (parentNode) {
			NSIndexPath *parentIndex = [parentNode indexPath];
			[treeController setSelectionIndexPath:parentIndex];
		}
		else {
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
		if (!parent) {
			NSIndexPath *childIndex = [[[firstSelectedNode childNodes] objectAtIndex:0] indexPath];
			[treeController setSelectionIndexPath:childIndex];
		}
	}
}

/**
 * Closes the supplied sheet, before closing the master window.
 */
- (IBAction)closeErrorsSheet:(id)sender
{
	[NSApp endSheet:[sender window] returnCode:[sender tag]];
	[[sender window] orderOut:self];
}

#pragma mark -
#pragma mark Notifications

/** 
 * This notification is called when the managedObjectContext save happens.
 *
 * This will link this class to any newly created objects, so when they do their
 * -validateFor(Insert|Update|Delete): call later, they can forward it to this class.
 */
- (void)contextWillSave:(NSNotification *)notice
{
	//new objects don't yet know about us (this will also be called the first time an object is loaded from the db)
	for (NSManagedObject *o in [managedObjectContext insertedObjects]) {
		if([o isKindOfClass:[SPUserMO class]] || [o isKindOfClass:[SPPrivilegesMO class]]) {
			[o setValue:self forKey:@"userManager"];
		}
	}
}

- (void)contextDidChange:(NSNotification *)notification
{	
	if (!isInitializing) [outlineView reloadData];
}

#pragma mark -
#pragma mark Core data notifications

- (BOOL)updateUser:(SPUserMO *)user
{
	if (![user parent]) {
		NSArray *hosts = [user valueForKey:@"children"];
		
		// If the user has been changed, update the username on all hosts.
		// Don't check for errors, as some hosts may be new.
		if (![[user valueForKey:@"user"] isEqualToString:[user valueForKey:@"originaluser"]]) {
			
			for (SPUserMO *child in hosts)
			{
				[self _renameUserFrom:[user valueForKey:@"originaluser"]
								 host:[child valueForKey:@"originalhost"] ? [child valueForKey:@"originalhost"] : [child host]
								   to:[user valueForKey:@"user"]
								 host:[child host]];
			}
		}
		
		// If the password has been changed, use the same password on all hosts
		if(requiresPost576PasswordHandling) {
			// the UI password field is bound to the password field, so this is still where the new plaintext value comes from
			NSString *newPass = [[user changedValues] objectForKey:@"password"];
			if(newPass) {
				// 5.7.6+ can update all users at once
				NSMutableString *alterStmt = [NSMutableString stringWithString:@"ALTER USER "];
				BOOL first = YES;
				for (SPUserMO *child in hosts)
				{
					if(!first) [alterStmt appendString:@", "];
					[alterStmt appendFormat:@"%@@%@ IDENTIFIED WITH %@ BY %@", //note: "BY" -> plaintext, "AS" -> hash
					                        [[user valueForKey:@"user"] tickQuotedString],
					                        [[child host] tickQuotedString],
					                        [[user valueForKey:@"plugin"] tickQuotedString],
					                        (![newPass isNSNull] && [newPass length]) ? [newPass tickQuotedString] : @"''"];
					first = NO;
				}
				[connection queryString:alterStmt];
				if(![self _checkAndDisplayMySqlError]) return NO;
			}
		}
		else {
			if (![[user valueForKey:@"password"] isEqualToString:[user valueForKey:@"originalpassword"]]) {
				
				for (SPUserMO *child in hosts)
				{
					NSString *changePasswordStatement = [NSString stringWithFormat:
														 @"SET PASSWORD FOR %@@%@ = PASSWORD(%@)",
														 [[user valueForKey:@"user"] tickQuotedString],
														 [[child host] tickQuotedString],
														 ([user valueForKey:@"password"]) ? [[user valueForKey:@"password"] tickQuotedString] : @"''"];
					
					[connection queryString:changePasswordStatement];
					if(![self _checkAndDisplayMySqlError]) return NO;
				}
			}
		}
	}
	else {
		// If the hostname has changed, remane the detail before editing details
		if (![[user valueForKey:@"host"] isEqualToString:[user valueForKey:@"originalhost"]]) {
			
			[self _renameUserFrom:[[user parent] valueForKey:@"originaluser"]
							 host:[user valueForKey:@"originalhost"]
							   to:[[user parent] valueForKey:@"user"]
							 host:[user valueForKey:@"host"]];
		}
		
		if ([serverSupport supportsUserMaxVars]) {
			if(![self updateResourcesForUser:user]) return NO;
		}
		
		if(![self grantPrivilegesToUser:user]) return NO;
	}
	
	return YES;
}

- (BOOL)deleteUser:(SPUserMO *)user
{
	// users without hosts are for display only
	if(isInitializing || ![user valueForKey:@"host"]) return YES;
	
	NSString *droppedUser = [NSString stringWithFormat:@"%@@%@", [[user valueForKey:@"user"] tickQuotedString], [[user valueForKey:@"host"] tickQuotedString]];
	
	// Before MySQL 5.0.2 DROP USER just removed users with no privileges, so revoke
	// all their privileges first. Also, REVOKE ALL PRIVILEGES was added in MySQL 4.1.2, so use the
	// old multiple query approach (damn, I wish there were only one MySQL version!).
	if (![serverSupport supportsFullDropUser]) {
		[connection queryString:[NSString stringWithFormat:@"REVOKE ALL PRIVILEGES ON *.* FROM %@", droppedUser]];
		if(![self _checkAndDisplayMySqlError]) return NO;
		[connection queryString:[NSString stringWithFormat:@"REVOKE GRANT OPTION ON *.* FROM %@", droppedUser]];
		if(![self _checkAndDisplayMySqlError]) return NO;
	}
	
	// DROP USER was added in MySQL 4.1.1
	if ([serverSupport supportsDropUser]) {
		[connection queryString:[NSString stringWithFormat:@"DROP USER %@", droppedUser]];
	}
	// Otherwise manually remove the user rows from the mysql.user table
	else {
		[connection queryString:[NSString stringWithFormat:@"DELETE FROM mysql.user WHERE User = %@ and Host = %@", [[user valueForKey:@"user"] tickQuotedString], [[user valueForKey:@"host"] tickQuotedString]]];
	}
	
	return [self _checkAndDisplayMySqlError];
}

- (BOOL)insertUser:(SPUserMO *)user
{
	//this is also called during the initialize phase. we don't want to write to the db there.
	if(isInitializing) return YES;
	
	NSString *createStatement = nil;
	
	// Note that if the database does not support the use of the CREATE USER statment, then
	// we must resort to using GRANT. Doing so means we must specify the privileges and the database
	// for which these apply, so make them as restrictive as possible, but then revoke them to get the
	// same affect as CREATE USER. That is, a new user with no privleges.
	NSString *host = [[user valueForKey:@"host"] tickQuotedString];
	
	if ([user parent] && [[user parent] valueForKey:@"user"] && ([[user parent] valueForKey:@"password"] || [[user parent] valueForKey:@"authentication_string"])) {
		
		NSString *username = [[[user parent] valueForKey:@"user"] tickQuotedString];
		
		NSString *idString;
		if(requiresPost576PasswordHandling) {
			// there are three situations to cover here:
			//   1) host added, parent user unchanged
			//   2) host added, parent user password changed
			//   3) host added, parent user is new
			if([[user parent] valueForKey:@"originaluser"]) {
				// 1 & 2: If the parent user already exists we always use the old password hash. if the parent password changes at the same time, updateUser: will take care of it afterwards
				NSString *plugin = [[[user parent] valueForKey:@"plugin"] tickQuotedString];
				NSString *hash = [[[user parent] valueForKey:@"authentication_string"] tickQuotedString];
				idString = [NSString stringWithFormat:@"IDENTIFIED WITH %@ AS %@",plugin,hash];
			}
			else {
				// 3: If the user is new, we take the plaintext password value from the UI
				NSString *password = [[[user parent] valueForKey:@"password"] tickQuotedString];
				idString = [NSString stringWithFormat:@"IDENTIFIED BY %@",password];
			}
		}
		else {
			BOOL passwordIsHash;
			NSString *password;
			// there are three situations to cover here:
			//   1) host added, parent user unchanged
			//   2) host added, parent user password changed
			//   3) host added, parent user is new
			if([[user parent] valueForKey:@"originaluser"]) {
				// 1 & 2: If the parent user already exists we always use the old password hash.
				// This works because -updateUser: will be called after -insertUser: and update the password for this host, anyway.
				passwordIsHash = YES;
				password = [[[user parent] valueForKey:@"originalpassword"] tickQuotedString];
			}
			else {
				// 3: If the user is new, we take the plaintext password value from the UI
				passwordIsHash = NO;
				password = [[[user parent] valueForKey:@"password"] tickQuotedString];
			}
			idString = [NSString stringWithFormat:@"IDENTIFIED BY %@%@",(passwordIsHash? @"PASSWORD " : @""), password];
		}
		
		createStatement = ([serverSupport supportsCreateUser]) ?
		[NSString stringWithFormat:@"CREATE USER %@@%@ %@", username, host, idString] :
		[NSString stringWithFormat:@"GRANT SELECT ON mysql.* TO %@@%@ %@", username, host, idString];
	}
	else if ([user parent] && [[user parent] valueForKey:@"user"]) {
		
		NSString *username = [[[user parent] valueForKey:@"user"] tickQuotedString];
		
		createStatement = ([serverSupport supportsCreateUser]) ?
		[NSString stringWithFormat:@"CREATE USER %@@%@", username, host] :
		[NSString stringWithFormat:@"GRANT SELECT ON mysql.* TO %@@%@", username, host];
	}
	
	if (createStatement) {
		
		// Create user in database
		[connection queryString:createStatement];
		
		if ([self _checkAndDisplayMySqlError]) {
			if ([serverSupport supportsUserMaxVars]) {
				if(![self updateResourcesForUser:user]) return NO;
			}
			// If we created the user with the GRANT statment (MySQL < 5), then revoke the
			// privileges we gave the new user.
			if(![serverSupport supportsCreateUser]) {
				[connection queryString:[NSString stringWithFormat:@"REVOKE SELECT ON mysql.* FROM %@@%@", [[[user parent] valueForKey:@"user"] tickQuotedString], host]];
				
				if (![self _checkAndDisplayMySqlError]) return NO;
			}
			
			return [self grantPrivilegesToUser:user skippingRevoke:YES];
		}
	}
	return NO;
}

- (BOOL)grantDbPrivilegesWithPrivilege:(SPPrivilegesMO *)schemaPriv
{
	return [self grantDbPrivilegesWithPrivilege:schemaPriv skippingRevoke:NO];
}

/**
 * Grant or revoke DB privileges for the supplied user.
 */
- (BOOL)grantDbPrivilegesWithPrivilege:(SPPrivilegesMO *)schemaPriv skippingRevoke:(BOOL)skipRevoke
{
	NSMutableArray *grantPrivileges = [NSMutableArray array];
	NSMutableArray *revokePrivileges = [NSMutableArray array];
	
	NSString *dbName = [schemaPriv valueForKey:@"db"];
    dbName = [dbName stringByReplacingOccurrencesOfString:@"_" withString:@"\\_"];
	
	NSArray *changedKeys = [[schemaPriv changedValues] allKeys];
	
	for (NSString *key in [self privsSupportedByServer])
	{
		if (![key hasSuffix:@"_priv"]) continue;
		
		//ignore anything that we didn't change
		if (![changedKeys containsObject:key]) continue;
		
		NSString *privilege = [key stringByReplacingOccurrencesOfString:@"_priv" withString:@""];
		
		NS_DURING
			if ([[schemaPriv valueForKey:key] boolValue] == YES) {
				[grantPrivileges addObject:[privilege replaceUnderscoreWithSpace]];
			}
			else {
				[revokePrivileges addObject:[privilege replaceUnderscoreWithSpace]];
			}
		NS_HANDLER
		NS_ENDHANDLER
	
	}
	
	// Grant privileges
	if(![self _grantPrivileges:grantPrivileges
				onDatabase:dbName 
				   forUser:[schemaPriv valueForKeyPath:@"user.parent.user"] 
					  host:[schemaPriv valueForKeyPath:@"user.host"]]) return NO;
	
	if(!skipRevoke) {
		// Revoke privileges
		if(![self _revokePrivileges:revokePrivileges
					 onDatabase:dbName 
						forUser:[schemaPriv valueForKeyPath:@"user.parent.user"] 
						   host:[schemaPriv valueForKeyPath:@"user.host"]]) return NO;
	}
	
	return YES;
}

/**
 * Update resource limites for given user
 */
- (BOOL)updateResourcesForUser:(SPUserMO *)user
{
    if ([user valueForKey:@"parent"] != nil) {
		if([connection isNotMariadb103]){
			NSString *updateResourcesStatement = [NSString stringWithFormat:
												  @"UPDATE mysql.user SET max_questions = %@, max_updates = %@, max_connections = %@ WHERE User = %@ AND Host = %@",
												  [user valueForKey:@"max_questions"],
												  [user valueForKey:@"max_updates"],
												  [user valueForKey:@"max_connections"],
												  [[[user valueForKey:@"parent"] valueForKey:@"user"] tickQuotedString],
												  [[user valueForKey:@"host"] tickQuotedString]];
			
			[connection queryString:updateResourcesStatement];
			return [self _checkAndDisplayMySqlError];
		}
    }
	
	return YES;
}

- (BOOL)grantPrivilegesToUser:(SPUserMO *)user
{
	return [self grantPrivilegesToUser:user skippingRevoke:NO];
}

/**
 * Grant or revoke privileges for the supplied user.
 */
- (BOOL)grantPrivilegesToUser:(SPUserMO *)user skippingRevoke:(BOOL)skipRevoke
{
	if ([user valueForKey:@"parent"] != nil)
	{
		NSMutableArray *grantPrivileges = [NSMutableArray array];
		NSMutableArray *revokePrivileges = [NSMutableArray array];
		
		NSArray *changedKeys = [[user changedValues] allKeys];
		
		for (NSString *key in [self privsSupportedByServer])
		{
			if (![key hasSuffix:@"_priv"]) continue;
			
			//ignore anything that we didn't change
			if (![changedKeys containsObject:key]) continue;
			
			NSString *privilege = [key stringByReplacingOccurrencesOfString:@"_priv" withString:@""];
			
			// Check the value of the priv and assign to grant or revoke query as appropriate; do this
			// in a try/catch check to avoid exceptions for unhandled privs
			NS_DURING
				if ([[user valueForKey:key] boolValue] == YES) {
					[grantPrivileges addObject:[privilege replaceUnderscoreWithSpace]];
				} 
				else {
					[revokePrivileges addObject:[privilege replaceUnderscoreWithSpace]];
				}
			NS_HANDLER
			NS_ENDHANDLER
		}
		
		// Grant privileges
		if(![self _grantPrivileges:grantPrivileges
					onDatabase:nil 
					   forUser:[[user parent] valueForKey:@"user"] 
						  host:[user valueForKey:@"host"]]) return NO;

		if(!skipRevoke) {
			// Revoke privileges
			if(![self _revokePrivileges:revokePrivileges
						 onDatabase:nil 
							forUser:[[user parent] valueForKey:@"user"] 
							   host:[user valueForKey:@"host"]]) return NO;
		}
	}
	
	for (SPPrivilegesMO *priv in [user valueForKey:@"schema_privileges"])
	{
		if(![self grantDbPrivilegesWithPrivilege:priv skippingRevoke:skipRevoke]) return NO;
	}
	
	return YES;
}

#pragma mark -
#pragma mark Private API

/** 
 * Gets any NSManagedObject (SPUser) from the managedObjectContext that may
 * already exist with the given username.
 */
- (NSArray *)_fetchUserWithUserName:(NSString *)username
{
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"user == %@ AND parent == nil", username];
	NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"SPUser" inManagedObjectContext:moc];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
	
	[request setEntity:entityDescription];
	[request setPredicate:predicate];
	
	NSError *error = nil;
	NSArray *array = [moc executeFetchRequest:request error:&error];
	
	if (error != nil) {
		[NSApp presentError:error];
	}
	
	return array;
}

- (NSArray *)_fetchPrivsWithUser:(NSString *)username schema:(NSString *)selectedSchema host:(NSString *)host
{
	NSManagedObjectContext *moc = [self managedObjectContext];
	NSPredicate *predicate;
	NSEntityDescription *privEntity = [NSEntityDescription entityForName:@"Privileges" inManagedObjectContext:moc];
	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];

	// Construct the predicate depending on whether a user and schema were supplied;
	// blank schemas indicate a default priv value (as per %)
	if ([username length]) {
		if ([selectedSchema length]) {
			predicate = [NSPredicate predicateWithFormat:@"(user.parent.user like[cd] %@) AND (user.host like[cd] %@) AND (db like[cd] %@)", username, host, selectedSchema];
		} else {
			predicate = [NSPredicate predicateWithFormat:@"(user.parent.user like[cd] %@) AND (user.host like[cd] %@) AND (db == '')", username, host];
		}
	} else {
		if ([selectedSchema length]) {
			predicate = [NSPredicate predicateWithFormat:@"(user.parent.user == '') AND (user.host like[cd] %@) AND (db like[cd] %@)", host, selectedSchema];
		} else {
			predicate = [NSPredicate predicateWithFormat:@"(user.parent.user == '') AND (user.host like[cd] %@) AND (db == '')", host];
		}
	}

	[request setEntity:privEntity];
	[request setPredicate:predicate];
	
	NSError *error = nil;
	NSArray *array = [moc executeFetchRequest:request error:&error];
	
	if (error != nil) {
		[NSApp presentError:error];
	}
	
	return array;
}

/**
 * Creates a new NSManagedObject and inserts it into the managedObjectContext.
 */
- (SPUserMO *)_createNewSPUser
{
	return [NSEntityDescription insertNewObjectForEntityForName:@"SPUser" inManagedObjectContext:[self managedObjectContext]];	
}

/**
 * Grant the supplied privileges to the specified user and host
 */
- (BOOL)_grantPrivileges:(NSArray *)thePrivileges onDatabase:(NSString *)aDatabase forUser:(NSString *)aUser host:(NSString *)aHost
{
	if (![thePrivileges count]) return YES;

	NSString *grantStatement;

	// Special case when all items are checked, to allow GRANT OPTION to work
	if ([[self privsSupportedByServer] count] == [thePrivileges count]) {
		grantStatement = [NSString stringWithFormat:@"GRANT ALL ON %@.* TO %@@%@ WITH GRANT OPTION",
							aDatabase?[aDatabase backtickQuotedString]:@"*",
							[aUser tickQuotedString],
							[aHost tickQuotedString]];
	} 
	else {
		grantStatement = [NSString stringWithFormat:@"GRANT %@ ON %@.* TO %@@%@",
							[[thePrivileges componentsJoinedByCommas] uppercaseString],
							aDatabase?[aDatabase backtickQuotedString]:@"*",
							[aUser tickQuotedString],
							[aHost tickQuotedString]];
	}
	
	if(![connection isNotMariadb103]){
		grantStatement = [grantStatement stringByReplacingOccurrencesOfString:@"DELETE VERSIONING ROWS" withString:@"DELETE HISTORY"];
	}

	[connection queryString:grantStatement];
	return [self _checkAndDisplayMySqlError];
}


/**
 * Revoke the supplied privileges from the specified user and host
 */
- (BOOL)_revokePrivileges:(NSArray *)thePrivileges onDatabase:(NSString *)aDatabase forUser:(NSString *)aUser host:(NSString *)aHost
{
	if (![thePrivileges count]) return YES;

	NSString *revokeStatement;

	// Special case when all items are checked, to allow GRANT OPTION to work
	if ([[self privsSupportedByServer] count] == [thePrivileges count]) {
		revokeStatement = [NSString stringWithFormat:@"REVOKE ALL PRIVILEGES ON %@.* FROM %@@%@",
							aDatabase?[aDatabase backtickQuotedString]:@"*",
							[aUser tickQuotedString],
							[aHost tickQuotedString]];

		[connection queryString:revokeStatement];
		if(![self _checkAndDisplayMySqlError]) return NO;

		revokeStatement = [NSString stringWithFormat:@"REVOKE GRANT OPTION ON %@.* FROM %@@%@",
							aDatabase?[aDatabase backtickQuotedString]:@"*",
							[aUser tickQuotedString],
							[aHost tickQuotedString]];
	} 
	else {
		revokeStatement = [NSString stringWithFormat:@"REVOKE %@ ON %@.* FROM %@@%@",
							[[thePrivileges componentsJoinedByCommas] uppercaseString],
							aDatabase?[aDatabase backtickQuotedString]:@"*",
							[aUser tickQuotedString],
							[aHost tickQuotedString]];
	}
	
	if(![connection isNotMariadb103]){
		revokeStatement = [revokeStatement stringByReplacingOccurrencesOfString:@"DELETE VERSIONING ROWS" withString:@"DELETE HISTORY"];
	}

	[connection queryString:revokeStatement];
	return [self _checkAndDisplayMySqlError];
}

/**
 * Displays an alert panel if there was an error condition on the MySQL connection.
 */
- (BOOL)_checkAndDisplayMySqlError
{
	if ([connection queryErrored]) {
		if (isSaving) {
			[errorsString appendFormat:@"%@\n", [connection lastErrorMessage]];
		} 
		else {
			SPOnewayAlertSheet(
				NSLocalizedString(@"An error occurred", @"mysql error occurred message"),
				[self window],
				[NSString stringWithFormat:NSLocalizedString(@"An error occurred whilst trying to perform the operation.\n\nMySQL said: %@", @"mysql error occurred informative message"), [connection lastErrorMessage]]
			);
		}

		return NO;
	}
	
	return YES;
}

/**
 * Renames a user account using the supplied parameters.
 *
 * @param originalUser The user's original user name
 * @param originalHost The user's original host
 * @param newUser      The user's new user name
 * @param newHost      The user's new host
 */
- (BOOL)_renameUserFrom:(NSString *)originalUser host:(NSString *)originalHost to:(NSString *)newUser host:(NSString *)newHost
{
	NSString *renameQuery = nil;
	
	if ([serverSupport supportsRenameUser]) {
		renameQuery = [NSString stringWithFormat:@"RENAME USER %@@%@ TO %@@%@",
					   [originalUser tickQuotedString],
					   [originalHost tickQuotedString],
					   [newUser tickQuotedString],
					   [newHost tickQuotedString]];
	}
	else {
		// mysql.user is keyed on user and host so there should only ever be one result, 
		// but double check before we do the update.
		QKQuery *query = [QKQuery selectQueryFromTable:@"user"];
		
		[query setDatabase:SPMySQLDatabase];
		[query addField:@"COUNT(1)"];
		
		[query addParameter:@"User" operator:QKEqualityOperator value:originalUser];
		[query addParameter:@"Host" operator:QKEqualityOperator value:originalHost];
		
		SPMySQLResult *result = [connection queryString:[query query]];
		
		if ([[[result getRowAsArray] objectAtIndex:0] integerValue] == 1) {
			QKQuery *updateQuery = [QKQuery queryTable:@"user"];
			
			[updateQuery setQueryType:QKUpdateQuery];
			[updateQuery setDatabase:SPMySQLDatabase];
			
			[updateQuery addFieldToUpdate:@"User" toValue:newUser];
			[updateQuery addFieldToUpdate:@"Host" toValue:newHost];
			
			[updateQuery addParameter:@"User" operator:QKEqualityOperator value:originalUser];
			[updateQuery addParameter:@"Host" operator:QKEqualityOperator value:originalHost];
			
			renameQuery = [updateQuery query];
		}
	}
	
	if (renameQuery) {
		[connection queryString:renameQuery];
		return [self _checkAndDisplayMySqlError];
	}
	
	return YES;
}

#pragma mark - SPUserManagerDelegate

#pragma mark TableView Delegate Methods

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	id object = [notification object];

	if (object == schemasTableView) {
		[grantedSchemaPrivs removeAllObjects];
		[grantedTableView reloadData];

		[self _initializeAvailablePrivs];

		if ([[treeController selectedObjects] count] > 0 && [[schemasTableView selectedRowIndexes] count] > 0) {
			SPUserMO *user = [[treeController selectedObjects] objectAtIndex:0];

			// Check to see if the user host node was selected
			if ([user valueForKey:@"host"]) {
				NSString *selectedSchema = [schemas objectAtIndex:[schemasTableView selectedRow]];

				NSArray *results = [self _fetchPrivsWithUser:[[user parent] valueForKey:@"user"]
													  schema:[selectedSchema stringByReplacingOccurrencesOfString:@"_" withString:@"\\_"]
														host:[user valueForKey:@"host"]];

				if ([results count] > 0) {
					NSManagedObject *priv = [results objectAtIndex:0];

					for (NSPropertyDescription *property in [priv entity])
					{
						if ([[property name] hasSuffix:@"_priv"] && [[priv valueForKey:[property name]] boolValue])
						{
							NSString *displayName = [[[property name] stringByReplacingOccurrencesOfString:@"_priv" withString:@""] replaceUnderscoreWithSpace];
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
		}
		else {
			[availableTableView setEnabled:NO];
		}
	}
	else if (object == grantedTableView) {
		[removeSchemaPrivButton setEnabled:[[grantedController selectedObjects] count] > 0];
	}
	else if (object == availableTableView) {
		[addSchemaPrivButton setEnabled:[[availableController selectedObjects] count] > 0];
	}
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if (tableView == schemasTableView) {
		NSString *schemaName = [schemas objectAtIndex:rowIndex];

		// Gray out the "all database" entries
		if ([schemaName isEqualToString:@""] || [schemaName isEqualToString:@"%"]) {
			[cell setTextColor:[NSColor lightGrayColor]];
		} else {
			[cell setTextColor:[NSColor controlTextColor]];
		}

		// If the schema has permissions set, highlight with a yellow background
		BOOL enabledPermissions = NO;
		SPUserMO *user = [[treeController selectedObjects] objectAtIndex:0];
		NSArray *results = [self _fetchPrivsWithUser:[[user parent] valueForKey:@"user"]
											  schema:[schemaName stringByReplacingOccurrencesOfString:@"_" withString:@"\\_"]
												host:[user valueForKey:@"host"]];
		if ([results count]) {
			NSManagedObject *schemaPrivs = [results objectAtIndex:0];
			for (NSString *itemKey in [[[schemaPrivs entity] attributesByName] allKeys]) {
				if ([itemKey hasSuffix:@"_priv"] && [[schemaPrivs valueForKey:itemKey] boolValue]) {
					enabledPermissions = YES;
					break;
				}
			}
		}

		if (enabledPermissions) {
			[cell setDrawsBackground:YES];
			[cell setBackgroundColor:[NSColor colorWithDeviceRed:1.f green:1.f blue:0.f alpha:0.2]];
		} else {
			[cell setDrawsBackground:NO];
		}
	}
}

#pragma mark -
#pragma mark Tab View Delegate methods

- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	BOOL retVal = YES;

	if ([[treeController selectedObjects] count] == 0) return NO;

	if (![treeController commitEditing]) {
		return NO;
	}

	// Currently selected object in tree
	id selectedObject = [[treeController selectedObjects] objectAtIndex:0];

	// If we are selecting a tab view that requires there be a child,
	// make sure there is a child to select.  If not, don't allow it.
	if ([[tabViewItem identifier] isEqualToString:SPGlobalPrivilegesTabIdentifier] ||
		[[tabViewItem identifier] isEqualToString:SPResourcesTabIdentifier] ||
		[[tabViewItem identifier] isEqualToString:SPSchemaPrivilegesTabIdentifier]) {

		id parent = [selectedObject parent];

		retVal = parent ? ([[parent children] count] > 0) : ([[selectedObject children] count] > 0);

		if (!retVal) {
			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"User has no hosts", @"user has no hosts message")
											 defaultButton:NSLocalizedString(@"Add Host", @"Add Host")
										   alternateButton:NSLocalizedString(@"Cancel", @"cancel button")
											   otherButton:nil
								 informativeTextWithFormat:NSLocalizedString(@"This user doesn't have any hosts associated with it. It will be deleted unless one is added", @"user has no hosts informative message")];

			if ([alert runModal] == NSAlertDefaultReturn) {
				[self addHost:nil];
			}
		}

		// If this is the resources tab, enable or disable the controls based on the server's support for them
		if ([[tabViewItem identifier] isEqualToString:SPResourcesTabIdentifier]) {

			BOOL serverSupportsUserMaxVars = [serverSupport supportsUserMaxVars];

			// Disable the fields according to the version
			[maxUpdatesTextField setEnabled:serverSupportsUserMaxVars];
			[maxConnectionsTextField setEnabled:serverSupportsUserMaxVars];
			[maxQuestionsTextField setEnabled:serverSupportsUserMaxVars];
		}
	}

	return retVal;
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if ([[treeController selectedObjects] count] == 0) return;

	id selectedObject = [[treeController selectedObjects] objectAtIndex:0];

	// If the selected tab is General and a child is selected, select the
	// parent (user info).
	if ([[tabViewItem identifier] isEqualToString:SPGeneralTabIdentifier]) {
		if ([selectedObject parent]) {
			[self _selectParentFromSelection];
		}
	}
	else if ([[tabViewItem identifier] isEqualToString:SPGlobalPrivilegesTabIdentifier] ||
			 [[tabViewItem identifier] isEqualToString:SPResourcesTabIdentifier] ||
			 [[tabViewItem identifier] isEqualToString:SPSchemaPrivilegesTabIdentifier]) {
		// If the tab is either Global Privs or Resources and we have a user
		// selected, then open tree and select first child node.
		[self _selectFirstChildOfParentNode];
	}
}

#pragma mark -
#pragma mark Outline view Delegate Methods

- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if ([cell isKindOfClass:[ImageAndTextCell class]])
	{
		// Determines which Image to display depending on parent or child object
		NSImage *image = [[NSImage imageNamed:[(SPUserMO *)[item  representedObject] parent] ? NSImageNameNetwork : NSImageNameUser] retain];

		[image setSize:(NSSize){16, 16}];
		[(ImageAndTextCell *)cell setImage:image];
		[image release];
	}
}

- (BOOL)outlineView:(NSOutlineView *)olv isGroupItem:(id)item
{
	return NO;
}

- (BOOL)outlineView:(NSOutlineView *)olv shouldSelectItem:(id)item
{
	return YES;
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
		[tabView selectTabViewItemWithIdentifier:SPGeneralTabIdentifier];
	}
	else {
		if ([selectedObject parent] != nil && [[[tabView selectedTabViewItem] identifier] isEqualToString:@"General"]) {
			[tabView selectTabViewItemWithIdentifier:SPGlobalPrivilegesTabIdentifier];
		}
	}

	if ([selectedObject parent] != nil && [selectedObject host] == nil)
	{
		[selectedObject setValue:@"%" forKey:@"host"];
		[outlineView reloadItem:selectedObject];
	}

	[schemasTableView deselectAll:nil];
	[schemasTableView setNeedsDisplay:YES];
	[grantedTableView deselectAll:nil];
	[availableTableView deselectAll:nil];
}

- (BOOL)selectionShouldChangeInOutlineView:(NSOutlineView *)olv
{
	if ([[treeController selectedObjects] count] > 0)
	{
		id selectedObject = [[treeController selectedObjects] objectAtIndex:0];

		// Check parents
		if ([selectedObject valueForKey:@"parent"] == nil)
		{
			NSString *name = [selectedObject valueForKey:@"user"];
			NSArray *results = [self _fetchUserWithUserName:name];

			if ([results count] > 1) {
				NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Duplicate User", @"duplicate user message")
												 defaultButton:NSLocalizedString(@"OK", @"OK button")
											   alternateButton:nil
												   otherButton:nil
									 informativeTextWithFormat:NSLocalizedString(@"A user with the name '%@' already exists", @"duplicate user informative message"), name];
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
					NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Duplicate Host", @"duplicate host message")
													 defaultButton:NSLocalizedString(@"OK", @"OK button")
												   alternateButton:nil
													   otherButton:nil
										 informativeTextWithFormat:NSLocalizedString(@"A user with the host '%@' already exists", @"duplicate host informative message"), host];

					[alert runModal];

					return NO;
				}
			}
		}
	}

	return YES;
}

#pragma mark - SPUserManagerDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [schemas count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	NSString *databaseName = [schemas objectAtIndex:rowIndex];
	if ([databaseName isEqualToString:@""]) {
		databaseName = NSLocalizedString(@"All Databases", @"All databases placeholder");
	} else if ([databaseName isEqualToString:@"%"]) {
		databaseName = NSLocalizedString(@"All Databases (%)", @"All databases (%) placeholder");
	}
	return databaseName;
}

#pragma mark -

- (void)dealloc
{	
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    SPClear(managedObjectContext);
    SPClear(persistentStoreCoordinator);
    SPClear(managedObjectModel);
	SPClear(privColumnToGrantMap);
	SPClear(connection);
	SPClear(privsSupportedByServer);
	SPClear(schemas);
	SPClear(availablePrivs);
	SPClear(grantedSchemaPrivs);
	SPClear(treeSortDescriptor);
	SPClear(treeSortDescriptors);
	SPClear(serverSupport);
	
	[super dealloc];
}

@end
