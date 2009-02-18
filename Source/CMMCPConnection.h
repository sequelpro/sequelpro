//
//  CMMCPConnection.h
//  sequel-pro
//
//  Created by lorenz textor (lorenz@textor.ch) on Wed Sept 21 2005.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
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
//  Or mail to <lorenz@textor.ch>

#import <Cocoa/Cocoa.h>
#import <MCPKit_bundled/MCPKit_bundled.h>
#import "CMMCPResult.h"

// Set the connection timeout to enforce for all connections - used for the initial connection
// timeout and ping timeouts, but not for long queries/reads/writes.
// Probably worth moving this to a preference at some point.
#define SP_CONNECTION_TIMEOUT 10

@interface NSObject (CMMCPConnectionDelegate)

- (void)willQueryString:(NSString *)query;
- (void)queryGaveError:(NSString *)error;

@end

@interface CMMCPConnection : MCPConnection {
	IBOutlet NSWindow *connectionErrorDialog;
	NSWindow *parentWindow;
	id	delegate;

	BOOL nibLoaded;
	NSString *connectionLogin;
	NSString *connectionPassword;
	NSString *connectionHost;
	int connectionPort;
	NSString *connectionSocket;
}

- (id) init;
- (id) initToHost:(NSString *) host withLogin:(NSString *) login password:(NSString *) pass usingPort:(int) port;
- (id) initToSocket:(NSString *) socket withLogin:(NSString *) login password:(NSString *) pass;
- (void) initSPExtensions;
- (BOOL) connectWithLogin:(NSString *) login password:(NSString *) pass host:(NSString *) host port:(int) port socket:(NSString *) socket;
- (void) disconnect;
- (BOOL) reconnect;
- (IBAction) closeSheet:(id)sender;
- (void) setParentWindow:(NSWindow *)theWindow;
- (CMMCPResult *) queryString:(NSString *) query;
- (BOOL) checkConnection;
- (void) setDelegate:(id)object;
- (NSTimeZone *) timeZone;
- (BOOL) pingConnection;

@end
