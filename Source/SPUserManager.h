//
//  $Id: SPUserManager.h 856 2009-06-12 05:31:39Z mltownsend $
//
//  SPUserManager.h
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

#import <Cocoa/Cocoa.h>

@class MCPConnection;

@interface SPUserManager : NSWindowController 
{	
	NSPersistentStoreCoordinator *persistentStoreCoordinator;
    NSManagedObjectModel *managedObjectModel;
    NSManagedObjectContext *managedObjectContext;
	NSDictionary *privColumnToGrantMap;
	
	BOOL isInitializing;
	
	MCPConnection* mySqlConnection;
	
	IBOutlet NSOutlineView* outlineView;
	IBOutlet NSTabView *tabView;
	IBOutlet NSTreeController *treeController;
	IBOutlet NSMutableDictionary *privsSupportedByServer;
}

@property (nonatomic, retain) MCPConnection *mySqlConnection;
@property (nonatomic, retain, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, retain, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, retain, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain) NSMutableDictionary *privsSupportedByServer;

// Add/Remove Users
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

// Core Data Notifications
- (void)contextDidSave:(NSNotification *)notification;
- (BOOL)insertUsers:(NSArray *)insertedUsers;
- (BOOL)deleteUsers:(NSArray *)deletedUsers;
- (BOOL)updateUsers:(NSArray *)updatedUsers;
- (BOOL)grantPrivilegesToUser:(NSManagedObject *)user;

@end
