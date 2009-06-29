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
#import "KeyChain.h"
#import "SPSSHTunnel.h"

@interface NSObject (CMMCPConnectionDelegate)

- (void)willQueryString:(NSString *)query;
- (void)queryGaveError:(NSString *)error;
- (void)setStatusIconToImageWithName:(NSString *)imagePath;
- (void)setTitlebarStatus:(NSString *)status;
- (BOOL)connectionEncodingViaLatin1;

@end

@interface CMMCPConnection : MCPConnection {
	IBOutlet NSWindow *connectionErrorDialog;
	NSWindow *parentWindow;
	id	delegate;

	BOOL nibLoaded;
	SPSSHTunnel *connectionTunnel;
	NSString *connectionLogin;
	NSString *connectionKeychainName;
	NSString *connectionKeychainAccount;
	NSString *connectionPassword;
	NSString *connectionHost;
	int connectionPort;
	NSString *connectionSocket;
	int maxAllowedPacketSize;
	unsigned long connectionThreadId;
	int connectionTimeout;
	int currentSSHTunnelState;
	BOOL useKeepAlive;
	float keepAliveInterval;
	
	double lastQueryExecutionTime;
	NSString *lastQueryErrorMessage;
	unsigned int lastQueryErrorId;
	my_ulonglong lastQueryAffectedRows;

	BOOL isMaxAllowedPacketEditable;
	
	NSString *serverVersionString;
	
	NSTimer *keepAliveTimer;
	NSDate *lastKeepAliveSuccess;
	
	BOOL retryAllowed;
	
	BOOL delegateResponseToWillQueryString;
	BOOL consoleLoggingEnabled;
	
	IMP cStringPtr;
	IMP willQueryStringPtr;
	IMP stopKeepAliveTimerPtr;
	IMP startKeepAliveTimerResettingStatePtr;
	
	SEL cStringSEL;
	SEL willQueryStringSEL;
	SEL stopKeepAliveTimerSEL;
	SEL startKeepAliveTimerResettingStateSEL;
}

- (id) init;
- (id) initToHost:(NSString *) host withLogin:(NSString *) login usingPort:(int) port;
- (id) initToSocket:(NSString *) socket withLogin:(NSString *) login;
- (void) initSPExtensions;
- (BOOL) setPort:(int) thePort;
- (BOOL) setPassword:(NSString *)thePassword;
- (BOOL) setPasswordKeychainName:(NSString *)theName account:(NSString *)theAccount;
- (BOOL) setSSHTunnel:(SPSSHTunnel *)theTunnel;
- (BOOL) connect;
- (void) disconnect;
- (BOOL) reconnect;
- (void) setParentWindow:(NSWindow *)theWindow;
- (IBAction) closeSheet:(id)sender;
+ (BOOL) isErrorNumberConnectionError:(int)theErrorNumber;
+ (NSStringEncoding) encodingForMySQLEncoding:(const char *) mysqlEncoding;
- (BOOL) selectDB:(NSString *) dbName;
- (CMMCPResult *) queryString:(NSString *) query;
- (CMMCPResult *) queryString:(NSString *) query usingEncoding:(NSStringEncoding) encoding;
- (double) lastQueryExecutionTime;
- (MCPResult *) listDBsLike:(NSString *) dbsName;
- (BOOL) checkConnection;
- (void) restoreConnectionDetails;
- (void) setDelegate:(id)object;
- (NSTimeZone *) timeZone;
- (BOOL) pingConnection;
- (void) startKeepAliveTimerResettingState:(BOOL)resetState;
- (void) stopKeepAliveTimer;
- (void) keepAlive:(NSTimer *)theTimer;
- (void) threadedKeepAlive;
- (const char *) cStringFromString:(NSString *) theString usingEncoding:(NSStringEncoding) encoding;
- (void) setLastErrorMessage:(NSString *)theErrorMessage;
- (BOOL) fetchMaxAllowedPacket;
- (int) getMaxAllowedPacket;
- (BOOL) isMaxAllowedPacketEditable;
- (int) setMaxAllowedPacketTo:(int)newSize resetSize:(BOOL)reset;

- (void)willPerformQuery:(NSNotification *)notification;

/* return server major version number or -1 on fail */
- (int)serverMajorVersion;
/* return server minor version number or -1 on fail */
- (int)serverMinorVersion;
/* return server release version number or -1 on fail */
- (int)serverReleaseVersion;

@end
