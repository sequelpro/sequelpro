//
//  MCPDocument.h
//  Vacations
//
//  Created by Serge Cohen on Sat May 24 2003.
//  Copyright (c) 2003 ARP/wARP. All rights reserved.
//


#import <Cocoa/Cocoa.h>

// External classes, forward reference.
@class MCPConnection;
@class MCPResult;


@interface MCPDocument : NSDocument
{
	BOOL						MCPConInfoNeeded, MCPPassNeeded;
	NSString					*MCPHost, *MCPLogin, *MCPDatabase;
	unsigned int			MCPPort;
	MCPConnection			*MCPConnect;

// Handling of windows.
	NSWindowController	*MCPMainWinCont;
	Class						MCPConnectedWinCont;	/*" Window controller used once the connection is established (As a class). "*/
// Handling the DB creation state.
   NSString             *MCPModelName;
   BOOL                 MCPWillCreateNewDB;
}

/*" Class Maintenance "*/
+ (void) initialize;

// Standards
/*" Initialisation and deallocation "*/
- (id) init;
- (void) dealloc;

/*" Connection to the databse related "*/
- (MCPResult *) MCPqueryString:(NSString *) query;
- (unsigned int) MCPinsertRow:(NSString *) insert;
- (MCPConnection *) MCPgetConnection;

// Accessors
/*" Accessors to the parameters of the connection "*/
- (void) setMCPHost:(NSString *) theHost;
- (void) setMCPLogin:(NSString *) theLogin;
- (void) setMCPDatabase:(NSString *) theDatabase;
- (void) setMCPPort:(unsigned int) thePort;
- (void) setMCPConInfoNeeded:(BOOL) theConInfoNeeded;

- (NSString *) MCPHost;
- (NSString *) MCPLogin;
- (NSString *) MCPDatabase;
- (unsigned int) MCPPort;
- (BOOL) MCPConInfoNeeded;
- (BOOL) MCPPassNeeded;

- (BOOL) MCPisConnected;
- (MCPConnection *) MCPConnect;

/*" Accessor to the window generated once the connection is established "*/
- (void) setMCPConnectedWinCont:(Class) theConnectedWinCont;

- (Class) MCPConnectedWinCont;

/*" Accessors to the main window (connection or connected window), through their window controller. "*/
- (NSWindowController *) MCPMainWinCont;

/*" Accessors to the DB creation instances. "*/
- (void) setMCPModelName:(NSString *) theModelName;
- (void) setMCPWillCreateNewDB:(BOOL) theWillCreateNewDB;

- (NSString *) MCPModelName;
- (BOOL) MCPWillCreateNewDB;

/*" Practical creation of the database, from a model file. "*/
- (BOOL) createModelDB;

/*" Overrides of NSDocument methods. "*/
// Managing the document in file format
- (NSData *) dataRepresentationOfType:(NSString *) aType;
- (BOOL)loadDataRepresentation:(NSData *) data ofType:(NSString *)aType;

// Managing NSWindowController(s)
- (NSArray *) makeWindowControllers;
- (void) windowControllerDidLoadNib:(NSWindowController *) aController;

/*" Method to take care of the password sheet. "*/
// Callback from sheet
- (void) MCPPasswordSheetDidEnd:(NSWindow *) sheet returnCode:(int) returnCode contextInfo:(void *) contextInfo;


@end
