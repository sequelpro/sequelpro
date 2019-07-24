//
//  SPMySQLConnection.h
//  SPMySQLFramework
//
//  Created by Rowan Beentje (rowan.beent.je) on January 8, 2012
//  Copyright (c) 2012 Rowan Beentje. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <https://github.com/sequelpro/sequelpro>

@class SPMySQLKeepAliveTimer;

@interface SPMySQLConnection : NSObject {

	// Delegate
	NSObject <SPMySQLConnectionDelegate> *delegate;
	BOOL delegateSupportsWillQueryString;
	BOOL delegateSupportsConnectionLost;
	BOOL delegateQueryLogging; // Defaults to YES if protocol implemented

	// Basic connection details
	NSString *host;
	NSString *username;
	NSString *password;
	NSUInteger port;
	BOOL useSocket;
	NSString *socketPath;

	// SSL connection details
	BOOL useSSL;
	NSString *sslKeyFilePath;
	NSString *sslCertificatePath;
	NSString *sslCACertificatePath;
	NSString *sslCipherList;

	// MySQL connection details and state
	struct st_mysql *mySQLConnection;
	SPMySQLConnectionState state;
	BOOL connectedWithSSL;
	BOOL userTriggeredDisconnect;
	pthread_t reconnectingThread;
	uint64_t initialConnectTime;
	unsigned long mysqlConnectionThreadId;

	// Connection proxy
	NSObject <SPMySQLConnectionProxy> *proxy;
	SPMySQLConnectionProxyState previousProxyState;
	BOOL proxyStateChangeNotificationsIgnored;

	// Connection lock to prevent non-thread-safe query misuse
	NSConditionLock *connectionLock;

	// Currently selected database
	NSString *database, *databaseToRestore;

	// Delegate connection lost decisions
	NSUInteger reconnectionRetryAttempts;
	SPMySQLConnectionLostDecision lastDelegateDecisionForLostConnection;
	NSLock *delegateDecisionLock;

	// Timeout and keep-alive
	NSUInteger timeout;
	BOOL useKeepAlive;
	SPMySQLKeepAliveTimer *keepAliveTimer;
	CGFloat keepAliveInterval;
	uint64_t lastKeepAliveTime;
	NSUInteger keepAlivePingFailures;
	volatile NSThread *keepAliveThread;
	volatile BOOL keepAlivePingThreadActive;
	BOOL keepAliveLastPingBlocked;

	// Encoding details - and also a record of any previous encoding to allow
	// switching back and forth
	NSString *encoding, *encodingToRestore;
	NSStringEncoding stringEncoding;
	BOOL encodingUsesLatin1Transport, encodingUsesLatin1TransportToRestore;
	NSString *previousEncoding;
	BOOL previousEncodingUsesLatin1Transport;

	// Server details
	NSString *serverVariableVersion;
	unsigned long serverVersionNumber;

	// Error state for the last query or connection state
	NSUInteger queryErrorID;
	NSString *queryErrorMessage;
	NSString *querySqlstate;

	// Query details
	unsigned long long lastQueryAffectedRowCount;
	unsigned long long lastQueryInsertID;

	// Query cancellation details
	BOOL lastQueryWasCancelled;
	BOOL lastQueryWasCancelledUsingReconnect;

	// Timing details
	uint64_t lastConnectionUsedTime;
	double lastQueryExecutionTime;

	// Maximum query size
	NSUInteger maxQuerySize;
	BOOL maxQuerySizeIsEditable;
	BOOL maxQuerySizeEditabilityChecked;
	NSUInteger queryActionShouldRestoreMaxQuerySize;

	// Queries
	BOOL retryQueriesOnConnectionFailure;
	
	SPMySQLClientFlags clientFlags;
	
	NSString *_debugLastConnectedEvent;
}

#pragma mark -
#pragma mark Synthesized properties

@property (readwrite, retain) NSString *host;
@property (readwrite, retain) NSString *username;
@property (readwrite, retain) NSString *password;
@property (readwrite, assign) NSUInteger port;
@property (readwrite, assign) BOOL useSocket;
@property (readwrite, retain) NSString *socketPath;

@property (readwrite, assign) BOOL useSSL;
@property (readwrite, retain) NSString *sslKeyFilePath;
@property (readwrite, retain) NSString *sslCertificatePath;
@property (readwrite, retain) NSString *sslCACertificatePath;

/**
 * List of supported ciphers for SSL/TLS connections.
 * This is a colon-separated string of names as used by
 * `openssl ciphers`. The order of entries specifies
 * their preference (earlier = better).
 * A value of nil (default) means SPMySQL will use its built-in cipher list.
 */
@property (readwrite, retain) NSString *sslCipherList;

@property (readwrite, assign) NSUInteger timeout;
@property (readwrite, assign) BOOL useKeepAlive;
@property (readwrite, assign) CGFloat keepAliveInterval;

@property (readonly) unsigned long mysqlConnectionThreadId;
@property (readwrite, assign) BOOL retryQueriesOnConnectionFailure;

@property (readwrite, assign) BOOL delegateQueryLogging;

@property (readwrite, assign) BOOL lastQueryWasCancelled;

/**
 * The mysql client capability flags to set when connecting.
 * See CLIENT_* in mysql.h
 */
@property (readwrite, assign, nonatomic) SPMySQLClientFlags clientFlags;
- (void)addClientFlags:(SPMySQLClientFlags)opts;
- (void)removeClientFlags:(SPMySQLClientFlags)opts;

#pragma mark -
#pragma mark Connection and disconnection

- (BOOL)connect;
- (BOOL)reconnect;
- (void)disconnect;

#pragma mark -
#pragma mark Connection state

- (BOOL)isConnected;
- (BOOL)isConnectedViaSSL;
- (BOOL)checkConnection;
- (BOOL)checkConnectionIfNecessary;
- (double)timeConnected;
- (BOOL)userTriggeredDisconnect;
- (BOOL)isNotMariadb103;

#pragma mark -
#pragma mark Connection utility

+ (NSString *)findSocketPath;

@end
