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
#include <pthread.h>

enum
{
	MCP_NO_STREAMING = 0,
	MCP_FAST_STREAMING = 1,
	MCP_LOWMEM_STREAMING = 2
};
typedef NSUInteger mcp_query_streaming_types;

@class MCPResult, MCPStreamingResult;
@protocol MCPConnectionProxy;

/**
 * NSStringDataUsingLossyEncoding(aStr, enc, lossy) := [aStr dataUsingEncoding:enc allowLossyConversion:lossy]
 */
static inline NSData* NSStringDataUsingLossyEncoding(NSString* self, NSInteger encoding, NSInteger lossy) 
{
	typedef NSData* (*SPStringDataUsingLossyEncodingMethodPtr)(NSString*, SEL, NSInteger, NSInteger);
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
- (NSString *)onReconnectShouldSelectDatabase:(id)connection;
- (NSString *)onReconnectShouldUseEncoding:(id)connection;
- (void)noConnectionAvailable:(id)connection;
- (MCPConnectionCheck)connectionLost:(id)connection;

@end

@interface MCPConnection : NSObject 
{
	MYSQL			 *mConnection;     /* The inited MySQL connection. */
	BOOL			 mConnected;       /* Reflect the fact that the connection is already in place or not. */
	NSStringEncoding mEncoding;        /* The encoding used by MySQL server, to ISO-1 default. */
	NSTimeZone		 *mTimeZone;       /* The time zone of the session. */
	NSUInteger       mConnectionFlags; /* The flags to be used for the connection to the database. */
	id				 delegate;         /* Connection delegate */
	
	NSLock			 *queryLock;	   /* Anything that performs a mysql_net_read is not thread-safe: mysql queries, pings */

	BOOL useKeepAlive;
	NSInteger connectionTimeout;
	CGFloat keepAliveInterval;
	
	id <MCPConnectionProxy> connectionProxy;
	NSString *connectionLogin;
	NSString *connectionPassword;
	NSString *connectionHost;
	NSInteger connectionPort;
	NSString *connectionSocket;
	NSInteger maxAllowedPacketSize;
	unsigned long connectionThreadId;
	
	NSInteger currentProxyState;
	
	double lastQueryExecutionTime;
	double lastQueryExecutedAtTime;
	NSString *lastQueryErrorMessage;
	NSUInteger lastQueryErrorId;
	my_ulonglong lastQueryAffectedRows;
	
	BOOL isMaxAllowedPacketEditable;
	
	NSString *serverVersionString;
	
	NSTimer *keepAliveTimer;
	pthread_t keepAliveThread;
	uint64_t connectionStartTime;
	
	BOOL retryAllowed;
	BOOL queryCancelled;
	BOOL queryCancelUsedReconnect;
	BOOL delegateQueryLogging;
	BOOL delegateResponseToWillQueryString;
	
	// Pointers
	IMP cStringPtr;
	IMP willQueryStringPtr;
	IMP stopKeepAliveTimerPtr;
	IMP startKeepAliveTimerPtr;
	IMP timeConnectedPtr;
	
	// Selectors
	SEL cStringSEL;
	SEL willQueryStringSEL;
	SEL stopKeepAliveTimerSEL;
	SEL startKeepAliveTimerSEL;
	SEL timeConnectedSEL;
}

// Readonly properties
@property (readonly) double lastQueryExecutionTime;

// Read/write properties
@property (readwrite, assign) BOOL useKeepAlive;
@property (readwrite, assign) BOOL delegateQueryLogging;
@property (readwrite, assign) NSInteger connectionTimeout;
@property (readwrite, assign) CGFloat keepAliveInterval;

// Initialisation
- (id)initToHost:(NSString *)host withLogin:(NSString *)login usingPort:(NSInteger)port;
- (id)initToSocket:(NSString *)socket withLogin:(NSString *)login;

// Delegate
- (id)delegate;
- (void)setDelegate:(id)connectionDelegate;

// Connection details
- (BOOL)setPort:(NSInteger)thePort;
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
- (void)startKeepAliveTimer;
- (void)stopKeepAliveTimer;
- (void)keepAlive:(NSTimer *)theTimer;
- (void)threadedKeepAlive;
void performThreadedKeepAlive(void *ptr);
- (void)restoreConnectionDetails;
- (void)setAllowQueryRetries:(BOOL)allow;
- (double)timeConnected;

// Server versions
- (NSString *)serverVersionString;
- (NSInteger)serverMajorVersion;
- (NSInteger)serverMinorVersion;
- (NSInteger)serverReleaseVersion;

// MySQL defaults
+ (NSDictionary *)getMySQLLocales;
+ (NSStringEncoding)encodingForMySQLEncoding:(const char *)mysqlEncoding;
+ (NSStringEncoding)defaultMySQLEncoding;
+ (BOOL)isErrorNumberConnectionError:(NSInteger)theErrorNumber;

// Class maintenance
+ (void)setTruncateLongFieldInLogs:(BOOL)iTruncFlag;
+ (BOOL)truncateLongField;
- (BOOL)setConnectionOption:(NSInteger)option toValue:(BOOL)value;
- (BOOL)connectWithLogin:(NSString *)login password:(NSString *)pass host:(NSString *)host port:(NSInteger)port socket:(NSString *)socket;

- (BOOL)selectDB:(NSString *)dbName;

// Error information
- (NSString *)getLastErrorMessage;
- (void)setLastErrorMessage:(NSString *)theErrorMessage;
- (NSUInteger)getLastErrorID;
+ (BOOL)isErrorNumberConnectionError:(NSInteger)theErrorNumber;
- (void)updateErrorStatuses;

// Queries
- (NSString *)prepareBinaryData:(NSData *)theData;
- (NSString *)prepareString:(NSString *)theString;
- (NSString *)quoteObject:(id)theObject;
- (MCPResult *)queryString:(NSString *)query;
- (MCPStreamingResult *)streamingQueryString:(NSString *)query;
- (MCPStreamingResult *)streamingQueryString:(NSString *)query useLowMemoryBlockingStreaming:(BOOL)fullStream;
- (id)queryString:(NSString *) query usingEncoding:(NSStringEncoding) encoding streamingResult:(NSInteger) streamResult;
- (my_ulonglong)affectedRows;
- (my_ulonglong)insertId;
- (void)cancelCurrentQuery;
- (BOOL)queryCancelled;
- (BOOL)queryCancellationUsedReconnect;

// Locking
- (void)lockConnection;
- (void)unlockConnection;

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
- (NSInteger)getMaxAllowedPacket;
- (BOOL)isMaxAllowedPacketEditable;
- (NSInteger)setMaxAllowedPacketTo:(NSInteger)newSize resetSize:(BOOL)reset;

// Data conversion
- (const char *)cStringFromString:(NSString *)theString;
- (const char *)cStringFromString:(NSString *)theString usingEncoding:(NSStringEncoding)encoding;
- (NSString *)stringWithCString:(const char *)theCString;
- (NSString *)stringWithText:(NSData *)theTextData;

@end
