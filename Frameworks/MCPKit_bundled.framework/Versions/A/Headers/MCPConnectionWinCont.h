//
//  MCPConnectionWinCont.h
//  Vacations
//
//  Created by Serge Cohen on Mon May 26 2003.
//  Copyright (c) 2003 ARP/wARP. All rights reserved.
//

#import <AppKit/AppKit.h>

// External classes, forward reference.
@class MCPDocument;


@interface MCPConnectionWinCont : NSWindowController
{
	IBOutlet NSTextField		*mHostField;
	IBOutlet NSTextField		*mLoginField;
	IBOutlet NSTextField		*mDatabaseField;
	IBOutlet NSTextField		*mPortField;

	IBOutlet NSPanel			*mPasswordSheet;
	IBOutlet NSTextField		*mPasswordField;

   IBOutlet NSButton       *mCreateButton;
//	MCPDocument					*mMCPDocument;
}


/*" Actions for Interface Builder "*/
/*" For the clear text information. "*/
- (IBAction) doGo:(id) sender;
- (IBAction) doCancel:(id) sender;
- (IBAction) doCreate:(id) sender;
- (IBAction) modifyInstance:(id) sender;


/*" For the password. "*/
- (IBAction) passwordClick:(id) sender;
- (IBAction) askPassword:(id) sender;
- (NSString *) Password;


/*" Overrides of NSWindowController method, to adapt to this Window Controller. "*/
- (id) init;
- (void) dealloc;
- (void) windowDidLoad;

/*" Getting the button for creating a DB. "*/
- (NSButton*) getCreateButton;

@end
