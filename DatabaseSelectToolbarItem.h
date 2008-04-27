//
//  DatabaseSelectToolbarItem.h
//  sequel-pro
//
//  Created by Abhi Beckert on 27/04/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <MCPKit_bundled/MCPKit_bundled.h>
#import "CMMCPConnection.h"
#import "CMMCPResult.h"

@interface DatabaseSelectToolbarItem : NSToolbarItem {
	IBOutlet NSView *toolbarItemView;
  IBOutlet NSPopUpButton *dbSelectPopupButton;
}

- (NSPopUpButton *)databaseSelectPopupButton;

@end

extern NSString *DatabaseSelectToolbarItemIdentifier;