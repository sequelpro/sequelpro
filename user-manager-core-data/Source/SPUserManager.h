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
	
	BOOL isInitializing;
	
	CMMCPConnection* mySqlConnection;
	
	IBOutlet NSOutlineView* outlineView;
	IBOutlet NSTabView *tabView;
	IBOutlet NSTreeController *treeController;
	IBOutlet NSWindow *window;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
- (NSManagedObjectModel *)managedObjectModel;
- (NSManagedObjectContext *)managedObjectContext;

- (id)initWithConnection:(CMMCPConnection *)connection;
- (void)setConnection:(CMMCPConnection *)connection;
- (CMMCPConnection *)connection;
- (void)show;
- (void)initializeChild:(NSManagedObject *)child withItem:(NSDictionary *)item;

// Add/Remove Users
- (IBAction)addUser:(id)sender;
- (IBAction)removeUser:(id)sender;
- (IBAction)addHost:(id)sender;
- (IBAction)removeHost:(id)sender;

// General
- (IBAction)doCancel:(id)sender;
- (IBAction)doApply:(id)sender;

// Core Data Notifications
- (void)contextDidSave:(NSNotification *)notification;
@end
