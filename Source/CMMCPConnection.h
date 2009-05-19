//
//  $Id$
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

#import <Cocoa/Cocoa.h>
#import <MCPKit_bundled/MCPKit_bundled.h>
#import "CMMCPResult.h"

@interface NSObject (CMMCPConnectionDelegate)

- (void)willQueryString:(NSString *)query;
- (void)queryGaveError:(NSString *)error;
- (BOOL)connectionEncodingViaLatin1;

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
	float lastQueryExecutionTime;
	int connectionTimeout;
	BOOL useKeepAlive;
	float keepAliveInterval;
	
	NSString *serverVersionString;
	
	NSTimer *keepAliveTimer;
	NSDate *lastKeepAliveSuccess;
}

- (id) init;
- (id) initToHost:(NSString *) host withLogin:(NSString *) login password:(NSString *) pass usingPort:(int) port;
- (id) initToSocket:(NSString *) socket withLogin:(NSString *) login password:(NSString *) pass;
- (void) initSPExtensions;
- (BOOL) connectWithLogin:(NSString *) login password:(NSString *) pass host:(NSString *) host port:(int) port socket:(NSString *) socket;
- (void) disconnect;
- (BOOL) reconnect;
- (IBAction) closeSheet:(id)sender;
+ (NSStringEncoding) encodingForMySQLEncoding:(const char *) mysqlEncoding;
- (void) setParentWindow:(NSWindow *)theWindow;
- (BOOL) selectDB:(NSString *) dbName;
- (CMMCPResult *) queryString:(NSString *) query;
- (CMMCPResult *) queryString:(NSString *) query usingEncoding:(NSStringEncoding) encoding;
- (float) lastQueryExecutionTime;
- (MCPResult *) listDBsLike:(NSString *) dbsName;
- (BOOL) checkConnection;
- (void) setDelegate:(id)object;
- (NSTimeZone *) timeZone;
- (BOOL) pingConnection;
- (void) startKeepAliveTimerResettingState:(BOOL)resetState;
- (void) stopKeepAliveTimer;
- (void) keepAlive:(NSTimer *)theTimer;
- (void) threadedKeepAlive;
- (const char *) cStringFromString:(NSString *) theString usingEncoding:(NSStringEncoding) encoding;

/* return server major version number or -1 on fail */
- (int)serverMajorVersion;
/* return server minor version number or -1 on fail */
- (int)serverMinorVersion;
/* return server release version number or -1 on fail */
- (int)serverReleaseVersion;

@end
