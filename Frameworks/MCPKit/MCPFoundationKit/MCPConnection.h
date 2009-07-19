//
//  $Id$
//
//  MCPConnection.h
//  MCPKit
//
//  Created by Serge Cohen (serge.cohen@m4x.org) on 08/12/2001.
//  Copyright (c) 2001 Serge Cohen. All rights reserved.
//
//  Forked by the Sequel Pro team (sequelpro.com), April 2009
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
//  More info at <http://mysql-cocoa.sourceforge.net/>
//  More info at <http://code.google.com/p/sequel-pro/>

#import <Foundation/Foundation.h>

#import "MCPConstants.h"

#import "mysql.h"

@class MCPResult;
@protocol MCPConnectionProxy;

/**
 * NSStringDataUsingLossyEncoding(aStr, enc, lossy) := [aStr dataUsingEncoding:enc allowLossyConversion:lossy]
 */
static inline NSData* NSStringDataUsingLossyEncoding(NSString* self, int encoding, int lossy) 
{
	typedef NSData* (*SPStringDataUsingLossyEncodingMethodPtr)(NSString*, SEL, int, int);
	static SPStringDataUsingLossyEncodingMethodPtr SPNSStringDataUsingLossyEncoding;
	if (!SPNSStringDataUsingLossyEncoding) SPNSStringDataUsingLossyEncoding = (SPStringDataUsingLossyEncodingMethodPtr)[self methodForSelector:@selector(dataUsingEncoding:allowLossyConversion:)];
	NSData* to_return = SPNSStringDataUsingLossyEncoding(self, @selector(dataUsingEncoding:allowLossyConversion:), encoding, lossy);
	return to_return;
}

// Connection delegate interface
@interface NSObject (MCPConnectionDelegate)

- (void)willQueryString:(NSString *)query connection:(id)connection;
- (void)queryGaveError:(NSString *)error connection:(id)connection;
- (BOOL)connectionEncodingViaLatin1:(id)connection;
- (NSString *)keychainPasswordForConnection:(id)connection;
- (MCPConnectionCheck)connectionLost:(id)connection;

@end

@interface MCPConnection : NSObject 
{
	MYSQL			 *mConnection;     /* The inited MySQL connection. */
	BOOL			 mConnected;       /* Reflect the fact that the connection is already in place or not. */
	NSStringEncoding mEncoding;        /* The encoding used by MySQL server, to ISO-1 default. */
	NSTimeZone		 *mTimeZone;       /* The time zone of the session. */
	unsigned int	 mConnectionFlags; /* The flags to be used for the connection to the database. */
	id				 delegate;         /* Connection delegate */
	
	NSLock			 *queryLock;	   /* Anything that performs a mysql_net_read is not thread-safe: mysql queries, pings */

	BOOL useKeepAlive;
	int connectionTimeout;
	float keepAliveInterval;
	
	id <MCPConnectionProxy> connectionProxy;
	NSString *connectionLogin;
	NSString *connectionPassword;
	NSString *connectionHost;
	int connectionPort;
	NSString *connectionSocket;
	int maxAllowedPacketSize;
	unsigned long connectionThreadId;
	
	int currentProxyState;
	
	double lastQueryExecutionTime;
	double lastQueryExecutedAtTime;
	NSString *lastQueryErrorMessage;
	unsigned int lastQueryErrorId;
	my_ulonglong lastQueryAffectedRows;
	
	BOOL isMaxAllowedPacketEditable;
	
	NSString *serverVersionString;
	
	NSTimer *keepAliveTimer;
	NSDate *lastKeepAliveSuccess;
	uint64_t connectionStartTime;
	
	BOOL retryAllowed;
	BOOL delegateQueryLogging;
	BOOL delegateResponseToWillQueryString;
	
	// Pointers
	IMP cStringPtr;
	IMP willQueryStringPtr;
	IMP stopKeepAliveTimerPtr;
	IMP startKeepAliveTimerResettingStatePtr;
	IMP timeConnectedPtr;
	
	// Selectors
	SEL cStringSEL;
	SEL willQueryStringSEL;
	SEL stopKeepAliveTimerSEL;
	SEL startKeepAliveTimerResettingStateSEL;
	SEL timeConnectedSEL;
}

@property (readwrite, assign) id delegate;
@property (readwrite, assign) BOOL useKeepAlive;
@property (readwrite, assign) BOOL delegateQueryLogging;
@property (readwrite, assign) int connectionTimeout;
@property (readwrite, assign) float keepAliveInterval;

// Initialisation
- (id)initToHost:(NSString *)host withLogin:(NSString *)login usingPort:(int)port;
- (id)initToSocket:(NSString *)socket withLogin:(NSString *)login;

// Connection details
- (BOOL)setPort:(int)thePort;
- (BOOL)setPassword:(NSString *)thePassword;

// Proxy
- (BOOL)setConnectionProxy:(id <MCPConnectionProxy>)proxy;
- (void)connectionProxyStateChange:(id <MCPConnectionProxy>)proxy;

// Connection
- (BOOL)connect;
- (void)disconnect;
- (BOOL)reconnect;
- (BOOL)isConnected;
- (BOOL)checkConnection;
- (BOOL)pingConnection;
- (void)startKeepAliveTimerResettingState:(BOOL)resetState;
- (void)stopKeepAliveTimer;
- (void)keepAlive:(NSTimer *)theTimer;
- (void)threadedKeepAlive;
- (void)restoreConnectionDetails;
- (void)setAllowQueryRetries:(BOOL)allow;
- (double)timeConnected;

// Server versions
- (int)serverMajorVersion;
- (int)serverMinorVersion;
- (int)serverReleaseVersion;

// MySQL defaults
+ (NSDictionary *)getMySQLLocales;
+ (NSStringEncoding)encodingForMySQLEncoding:(const char *)mysqlEncoding;
+ (NSStringEncoding)defaultMySQLEncoding;
+ (BOOL)isErrorNumberConnectionError:(int)theErrorNumber;

// Class maintenance
+ (void)setTruncateLongFieldInLogs:(BOOL)iTruncFlag;
+ (BOOL)truncateLongField;
- (BOOL)setConnectionOption:(int)option toValue:(BOOL)value;
- (BOOL)connectWithLogin:(NSString *)login password:(NSString *)pass host:(NSString *)host port:(int)port socket:(NSString *)socket;

- (BOOL)selectDB:(NSString *)dbName;

// Error information
- (NSString *)getLastErrorMessage;
- (void)setLastErrorMessage:(NSString *)theErrorMessage;
- (unsigned int)getLastErrorID;
+ (BOOL)isErrorNumberConnectionError:(int)theErrorNumber;

// Queries
- (NSString *)prepareBinaryData:(NSData *)theData;
- (NSString *)prepareString:(NSString *)theString;
- (NSString *)quoteObject:(id)theObject;
- (MCPResult *)queryString:(NSString *)query;
- (MCPResult *)queryString:(NSString *)query usingEncoding:(NSStringEncoding)encoding;
- (double)lastQueryExecutionTime;
- (my_ulonglong)affectedRows;
- (my_ulonglong)insertId;

// Database structure
- (MCPResult *)listDBs;
- (MCPResult *)listDBsLike:(NSString *)dbsName;
- (MCPResult *)listTables;
- (MCPResult *)listTablesLike:(NSString *)tablesName;
- (MCPResult *)listTablesFromDB:(NSString *)dbName like:(NSString *)tablesName;
- (MCPResult *)listFieldsFromTable:(NSString *)tableName;
- (MCPResult *)listFieldsFromTable:(NSString *)tableName like:(NSString *)fieldsName;

// Server information
- (NSString *)clientInfo;
- (NSString *)hostInfo;
- (NSString *)serverInfo;
- (NSNumber *)protoInfo;
- (MCPResult *)listProcesses;
- (BOOL)killProcess:(unsigned long)pid;
- (NSString *)findSocketPath;

// Encoding
- (void)setEncoding:(NSStringEncoding)theEncoding;
- (NSStringEncoding)encoding;

// Time zone
- (void)setTimeZone:(NSTimeZone *)iTimeZone;
- (NSTimeZone *)timeZone;

// Packet size
- (BOOL)fetchMaxAllowedPacket;
- (int)getMaxAllowedPacket;
- (BOOL)isMaxAllowedPacketEditable;
- (int)setMaxAllowedPacketTo:(int)newSize resetSize:(BOOL)reset;

// Data conversion
- (const char *)cStringFromString:(NSString *)theString;
- (const char *)cStringFromString:(NSString *)theString usingEncoding:(NSStringEncoding)encoding;
- (NSString *)stringWithCString:(const char *)theCString;
- (NSString *)stringWithText:(NSData *)theTextData;

@end
