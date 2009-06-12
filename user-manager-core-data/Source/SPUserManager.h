//
//  SPUserManager.h
//  sequel-pro
//
//  Created by Mark on 1/20/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CMMCPConnection;

@interface SPUserManager : NSObject {
	
	NSPersistentStoreCoordinator *persistentStoreCoordinator;
    NSManagedObjectModel *managedObjectModel;
    NSManagedObjectContext *managedObjectContext;
	
	NSArray *dbList;
	NSMutableArray *users;
	NSMutableArray *availablePrivs;
	NSMutableArray *selectedPrivs;
	NSMutableArray *allPrivs;
	
	NSMutableArray *addedUsers;
	NSMutableArray *removedUsers;
	
	NSMutableArray *modifiedUsers;
	
	BOOL isInitializing;
	
	CMMCPConnection* mySqlConnection;
	
	IBOutlet NSOutlineView* outlineView;
	IBOutlet NSTabView *tabView;
	IBOutlet NSTreeController *treeController;
	IBOutlet NSArrayController *databaseList;
	IBOutlet NSArrayController *availablePrivsController;
	IBOutlet NSArrayController *selectedPrivsController;
	IBOutlet NSWindow *window;
	
	// Global Privileges Checkboxes
	IBOutlet NSButton *selectCB;
	IBOutlet NSButton *insertCB;
	IBOutlet NSButton *updateCB;
	IBOutlet NSButton *deleteCB;
	IBOutlet NSButton *createCB;
	IBOutlet NSButton *dropCB;
	IBOutlet NSButton *reloadCB;
	IBOutlet NSButton *shutdownCB;
	IBOutlet NSButton *processCB;
	IBOutlet NSButton *fileCB;
	IBOutlet NSButton *grantCB;
	IBOutlet NSButton *referencesCB;
	IBOutlet NSButton *indexesCB;
	IBOutlet NSButton *alterCB;
	IBOutlet NSButton *showDatabasesCB;
	IBOutlet NSButton *superCB;
	IBOutlet NSButton *createTmpTableCB;
	IBOutlet NSButton *lockTablesCB;
	IBOutlet NSButton *executeCB;
	IBOutlet NSButton *replSlaveCB;
	IBOutlet NSButton *replClientCB;
	IBOutlet NSButton *createViewCB;
	IBOutlet NSButton *showViewCB;
	IBOutlet NSButton *createRoutineCB;
	IBOutlet NSButton *alterRoutineCB;
	IBOutlet NSButton *createUserCB;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
- (NSManagedObjectModel *)managedObjectModel;
- (NSManagedObjectContext *)managedObjectContext;

- (id)initWithConnection:(CMMCPConnection *)connection;
- (void)setConnection:(CMMCPConnection *)connection;
- (CMMCPConnection *)connection;
- (void)show;

// Add/Remove Users
- (IBAction)addUser:(id)sender;
- (IBAction)removeUser:(id)sender;
- (IBAction)addHost:(id)sender;
- (IBAction)removeHost:(id)sender;

// Schema Privileges Actions
- (IBAction)addToSelected:(id)sender;
- (IBAction)addToAvailable:(id)sender;

// General
- (IBAction)doCancel:(id)sender;
- (IBAction)doApply:(id)sender;

// Core Data Notifications
- (void)contextDidSave:(NSNotification *)notification;
@end
