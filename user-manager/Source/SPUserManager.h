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
	
}

- (id)initWithConnection:(CMMCPConnection *)connection;
- (void)setConnection:(CMMCPConnection *)connection;
- (CMMCPConnection *)connection;


@end
