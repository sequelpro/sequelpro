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
	CMMCPConnection* mySqlConnection;
	
	IBOutlet NSOutlineView* outlineView;
	IBOutlet NSTabView *tabView;
	IBOutlet NSTreeController *treeController;
	IBOutlet NSArrayController *databaseList;
	IBOutlet NSWindow *window;
	
	NSMutableArray *users;
	NSArray *dbList;
	NSMutableArray *availablePrivs;
	NSMutableArray *selectedPrivs;
	NSMutableArray *allPrivs;
	
}

- (id)initWithConnection:(CMMCPConnection *)connection;
- (void)setConnection:(CMMCPConnection *)connection;
- (CMMCPConnection *)connection;
- (void)show;

@end
