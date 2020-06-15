//
//  SPUserManager.h
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

@class SPServerSupport;
@class SPMySQLConnection;
@class SPSplitView;
@class SPDatabaseDocument;
@class SPUserMO;
@class SPPrivilegesMO;

@interface SPUserManager : NSWindowController
{	
	NSPersistentStoreCoordinator *persistentStoreCoordinator;
    NSManagedObjectModel *managedObjectModel;
    NSManagedObjectContext *managedObjectContext;
	NSDictionary *privColumnToGrantMap;
	
	SPMySQLConnection *connection;
	SPDatabaseDocument *databaseDocument;
	SPServerSupport *serverSupport;

	IBOutlet SPSplitView *splitView;
	IBOutlet NSOutlineView *outlineView;
	IBOutlet NSTabView *tabView;
	IBOutlet NSTreeController *treeController;
	IBOutlet NSMutableDictionary *privsSupportedByServer;
	
	IBOutlet NSArrayController *grantedController;
	IBOutlet NSArrayController *availableController;
	
	IBOutlet NSTableView *schemasTableView;
	IBOutlet NSTableView *grantedTableView;
	IBOutlet NSTableView *availableTableView;
	IBOutlet NSButton *addSchemaPrivButton;
	IBOutlet NSButton *removeSchemaPrivButton;
	
	IBOutlet NSTextField *maxUpdatesTextField;
	IBOutlet NSTextField *maxConnectionsTextField;
	IBOutlet NSTextField *maxQuestionsTextField;
	
    IBOutlet NSTextField *userNameTextField;

	IBOutlet NSWindow *errorsSheet;
	IBOutlet NSTextView *errorsTextView;

	NSMutableArray *schemas;
	NSMutableArray *grantedSchemaPrivs;
	NSMutableArray *availablePrivs;
	
	NSArray *treeSortDescriptors;
	NSSortDescriptor *treeSortDescriptor;

	BOOL isSaving;
	BOOL isInitializing;
	NSMutableString *errorsString;
	
	// MySQL 5.7.6 removes the "Password" columns and only uses the "plugin" + "authentication_string" columns
	BOOL requiresPost576PasswordHandling;
}

@property (nonatomic, retain) SPMySQLConnection *connection;
@property (nonatomic, assign) SPDatabaseDocument *databaseDocument;
@property (nonatomic, retain) SPServerSupport *serverSupport;
@property (nonatomic, retain) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, retain, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain) NSMutableDictionary *privsSupportedByServer;

@property (nonatomic, retain) NSArray *treeSortDescriptors;
@property (nonatomic, retain) NSMutableArray *schemas;
@property (nonatomic, retain) NSMutableArray *grantedSchemaPrivs;
@property (nonatomic, retain) NSMutableArray *availablePrivs;
@property (nonatomic, readonly) BOOL isInitializing;

// Add/Remove users
- (IBAction)addUser:(id)sender;
- (IBAction)removeUser:(id)sender;
- (IBAction)addHost:(id)sender;
- (void)editNewHost;
- (IBAction)removeHost:(id)sender;

// General
- (IBAction)doCancel:(id)sender;
- (IBAction)doApply:(id)sender;
- (IBAction)checkAllPrivileges:(id)sender;
- (IBAction)uncheckAllPrivileges:(id)sender;
- (IBAction)closeErrorsSheet:(id)sender;
- (IBAction)doubleClickSchemaPriv:(id)sender;

// Schema privieges
- (IBAction)addSchemaPriv:(id)sender;
- (IBAction)removeSchemaPriv:(id)sender;

// Refresh
- (IBAction)refresh:(id)sender;

// Core data notifications
- (BOOL)insertUser:(SPUserMO *)user;
- (BOOL)deleteUser:(SPUserMO *)user;
- (BOOL)updateUser:(SPUserMO *)user;
- (BOOL)updateResourcesForUser:(SPUserMO *)user;
- (BOOL)grantPrivilegesToUser:(SPUserMO *)user;
- (BOOL)grantPrivilegesToUser:(SPUserMO *)user skippingRevoke:(BOOL)skipRevoke;
- (BOOL)grantDbPrivilegesWithPrivilege:(SPPrivilegesMO *)user;
- (BOOL)grantDbPrivilegesWithPrivilege:(SPPrivilegesMO *)user skippingRevoke:(BOOL)skipRevoke;

// External
/**
 * Display the user manager as a sheet attached to a chosen window
 * @param docWindow The parent window.
 * @param callback  A callback that will be called once the window is closed again. Can be NULL.
 */
- (void)beginSheetModalForWindow:(NSWindow *)docWindow completionHandler:(void (^)(void))callback;

@end
