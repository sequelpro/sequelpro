//
//  SPMySQLConnection.m
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

#import "SPMySQL Private APIs.h"
#import "SPMySQLKeepAliveTimer.h"
#include <mach/mach_time.h>
#include <pthread.h>
#include <SystemConfiguration/SCNetworkReachability.h>
#import "SPMySQLUtilities.h"

// Thread flag constant
static pthread_key_t mySQLThreadInitFlagKey;
static void *mySQLThreadFlag;

#pragma mark Class constants

// The default connection options for MySQL connections
const SPMySQLClientFlags SPMySQLConnectionOptions =
					SPMySQLClientFlagCompression |  // Enable protocol compression - almost always a win
					SPMySQLClientFlagInteractive |  // Mark ourselves as an interactive client
					SPMySQLClientFlagMultiResults;  // Multiple result support (very basic, but present)

// List of permissible ciphers to use for SSL connections
const char *SPMySQLSSLPermissibleCiphers = "DHE-RSA-AES256-SHA:AES256-SHA:DHE-RSA-AES128-SHA:AES128-SHA:AES256-RMD:AES128-RMD:DES-CBC3-RMD:DHE-RSA-AES256-RMD:DHE-RSA-AES128-RMD:DHE-RSA-DES-CBC3-RMD:RC4-SHA:RC4-MD5:DES-CBC3-SHA:DES-CBC-SHA:EDH-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC-SHA";


@implementation SPMySQLConnection

#pragma mark -
#pragma mark Synthesized properties

@synthesize host;
@synthesize username;
@synthesize password;
@synthesize port;
@synthesize useSocket;
@synthesize socketPath;
@synthesize useSSL;
@synthesize sslKeyFilePath;
@synthesize sslCertificatePath;
@synthesize sslCACertificatePath;
@synthesize sslCipherList;
@synthesize timeout;
@synthesize useKeepAlive;
@synthesize keepAliveInterval;
@synthesize mysqlConnectionThreadId;
@synthesize retryQueriesOnConnectionFailure;
@synthesize delegateQueryLogging;
@synthesize lastQueryWasCancelled;
@synthesize clientFlags = clientFlags;

#pragma mark -
#pragma mark Getters and Setters

- (void)addClientFlags:(SPMySQLClientFlags)opts
{
	[self setClientFlags:([self clientFlags] | opts)];
}

- (void)removeClientFlags:(SPMySQLClientFlags)opts
{
	[self setClientFlags:([self clientFlags] & ~opts)];
}

#pragma mark -
#pragma mark Initialisation and teardown

/**
 * In the one-off class initialisation, set up MySQL as necessary
 */
+ (void)initialize
{
	// Set up a pthread thread-specific data key to be used across all classes and threads
	pthread_key_create(&mySQLThreadInitFlagKey, NULL);
	mySQLThreadFlag = malloc(1);

	// MySQL requires mysql_library_init() to be called before any other MySQL
	// functions are used; although mysql_init() will call it automatically, it
	// won't do so in a thread-safe manner, so setting it up first is safer.
	// No arguments are required.
	// Note that this will install MySQL's SIGPIPE handler.
	mysql_library_init(0, NULL, NULL);
}

/**
 * Initialise the SPMySQLConnection object, setting up class defaults.
 *
 * Typically initialisation would be followed by setting the connection details
 * and then calling -connect.
 */
- (id)init
{
	if ((self = [super init])) {
		mySQLConnection = NULL;
		state = SPMySQLDisconnected;
		userTriggeredDisconnect = NO;
		reconnectingThread = NULL;
		mysqlConnectionThreadId = 0;
		initialConnectTime = 0;

		port = 3306;

		// Default to socket connections if no other details have been provided
		useSocket = YES;

		// Start with no proxy
		proxy = nil;
		proxyStateChangeNotificationsIgnored = NO;

		// Start with no selected database
		database = nil;
		databaseToRestore = nil;

		// Set a timeout of 30 seconds, with keepalive on and acting every sixty seconds
		timeout = 30;
		useKeepAlive = YES;
		keepAliveInterval = 60;
		keepAlivePingFailures = 0;
		lastKeepAliveTime = 0;
		keepAliveThread = nil;
		keepAlivePingThreadActive = NO;
		keepAliveLastPingBlocked = NO;

		// Set up default encoding variables
		encoding = [[NSString alloc] initWithString:@"utf8"];
		stringEncoding = NSUTF8StringEncoding;
		encodingUsesLatin1Transport = NO;
		encodingToRestore = nil;
		encodingUsesLatin1TransportToRestore = NO;
		previousEncoding = nil;
		previousEncodingUsesLatin1Transport = NO;

		// Initialise default delegate settings
		delegate = nil;
		delegateSupportsWillQueryString = NO;
		delegateSupportsConnectionLost = NO;
		delegateQueryLogging = YES;

		// Delegate disconnection decisions
		reconnectionRetryAttempts = 0;
		lastDelegateDecisionForLostConnection = SPMySQLConnectionLostDisconnect;
		delegateDecisionLock = [[NSLock alloc] init];

		// Set up the connection lock
		connectionLock = [[NSConditionLock alloc] initWithCondition:SPMySQLConnectionIdle];
		[connectionLock setName:@"SPMySQLConnection query lock"];

		// Ensure the server detail records are initialised
		serverVariableVersion = nil;
		serverVersionNumber = 0;

		// Start with a blank error state
		queryErrorID = 0;
		queryErrorMessage = nil;
		querySqlstate = nil;

		// Start with empty cancellation details
		lastQueryWasCancelled = NO;
		lastQueryWasCancelledUsingReconnect = NO;

		// Empty or reset the timing variables
		lastConnectionUsedTime = 0;
		lastQueryExecutionTime = 0;

		// Default to editable query size of 1MB
		maxQuerySize = 1048576;
		maxQuerySizeIsEditable = YES;
		maxQuerySizeEditabilityChecked = NO;
		queryActionShouldRestoreMaxQuerySize = NSNotFound;

		// Default to allowing queries to be automatically retried if the connection drops
		// while running them
		retryQueriesOnConnectionFailure = YES;

		_debugLastConnectedEvent = nil;

		// Start the ping keepalive timer
		keepAliveTimer = [[SPMySQLKeepAliveTimer alloc] initWithInterval:10 target:self selector:@selector(_keepAlive)];
		
		[self setClientFlags:SPMySQLConnectionOptions];
	}

	return self;
}

/**
 * Object deallocation.
 */
- (void) dealloc
{
	userTriggeredDisconnect = YES;

	// Unset the delegate
	[self setDelegate:nil];

	// Clear the keepalive timer
	[keepAliveTimer invalidate];
	[keepAliveTimer release];

	// If a keepalive thread is active, cancel it
	[self _cancelKeepAlives];

	// Disconnect if appropriate (which should also disconnect any proxy)
	[self _disconnect];

	// Clean up the connection proxy, if any
	if (proxy) {
		[proxy setConnectionStateChangeSelector:NULL delegate:nil];
		[proxy release];
	}
	
	[self setSslCipherList:nil];

	// Ensure the query lock is unlocked, thereafter setting to nil in case of pending calls
	if ([connectionLock condition] != SPMySQLConnectionIdle) {
		[self _unlockConnection];
	}
	[connectionLock release], connectionLock = nil;

	[encoding release];
	if (encodingToRestore) [encodingToRestore release], encodingToRestore = nil;
	if (previousEncoding) [previousEncoding release], previousEncoding = nil;

	if (database) [database release], database = nil;
	if (databaseToRestore) [databaseToRestore release], databaseToRestore = nil;
	if (serverVariableVersion) [serverVariableVersion release], serverVariableVersion = nil;
	if (queryErrorMessage) [queryErrorMessage release], queryErrorMessage = nil;
	if (querySqlstate) [querySqlstate release], querySqlstate = nil;
	[delegateDecisionLock release];

	[_debugLastConnectedEvent release];

	[NSObject cancelPreviousPerformRequestsWithTarget:self];

	[super dealloc];
}

#pragma mark -
#pragma mark Connection and disconnection

/**
 * Trigger a connection to the specified host, if any, using any connection details
 * that have been set.
 * Returns whether the connection was successful.
 */
- (BOOL)connect
{
	userTriggeredDisconnect = NO;
	return [self _connect];
}

/**
 * Reconnect to the currently "active" - but possibly disconnected - connection, using the
 * stored details.  Calls the private _reconnectAllowingRetries to do this.
 * Error checks extensively - if this method fails, it will ask how to proceed and loop depending
 * on the status, not returning control until either a connection has been established or
 * the connection and document have been closed.
 *
 * WARNING: This method may exit early returning NO if the current thread is cancelled!
 *          You MUST check the isCancelled flag before using the result!
 */
- (BOOL)reconnect
{
	userTriggeredDisconnect = NO;
	return [self _reconnectAllowingRetries:YES];
}

/**
 * Trigger a disconnection if the connection is currently active.
 */
- (void)disconnect
{
	userTriggeredDisconnect = YES;
	[self _disconnect];
}

#pragma mark -
#pragma mark Connection state

/**
 * Retrieve whether the connection instance is connected to the remote host.
 * Returns NO if the connection is still in process, YES if a disconnection is
 * being actively performed.
 */
- (BOOL)isConnected
{
	// If the connection has been allowed to drop in the background, restore it if posslbe
	if (state == SPMySQLConnectionLostInBackground) {
		[self _reconnectAllowingRetries:YES];
	}

	return (state == SPMySQLConnected || state == SPMySQLDisconnecting);
}

/**
 * Returns YES if the SPMySQLConnection is connected to a server via SSL, NO otherwise.
 */
- (BOOL)isConnectedViaSSL
{
	return ([self isConnected] && connectedWithSSL);
}

/**
 * Checks whether the connection to the server is still active.  This verifies
 * the connection using a ping, and if the connection is found to be down attempts
 * to quickly restore it, including the previous state.
 *
 * WARNING: This method may return NO if the current thread is cancelled!
 *          You MUST check the isCancelled flag before using the result!
 *
 * NOTE: In general -checkConnectionIfNecessary should be used instead!
 */
- (BOOL)checkConnection
{
	// If the connection is not seen as active, don't proceed
	if (state != SPMySQLConnected) return NO;

	// Similarly, if the connection is currently locked, that indicates it's in use.  This
	// could be because queries are actively being run, or that a ping is running.
	if ([connectionLock condition] == SPMySQLConnectionBusy) {

		// If a ping thread is not active queries are being performed - return success.
		if (!keepAlivePingThreadActive) return YES;

		// If a ping thread is active, wait for it to complete before checking the connection
		while (keepAlivePingThreadActive) {
			usleep(10000);
		}
	}

	// Confirm whether the connection is still responding by using a ping
	BOOL connectionVerified = [self _pingConnectionUsingLoopDelay:400];

	// If the connection didn't respond, trigger a reconnect.  This will automatically
	// attempt to reconnect once, and if that fails will ask the user how to proceed - whether
	// to keep reconnecting, or whether to disconnect.
	if (!connectionVerified) {
		connectionVerified = [self _reconnectAllowingRetries:YES];
	}

	// Update the connection tracking use variable if the connection was confirmed,
	// as at least a mysql_ping will have been used.
	if (connectionVerified) {
		lastConnectionUsedTime = mach_absolute_time();
	}

	return connectionVerified;
}

/**
 * If thirty seconds have passed since the last time the connection was
 * used, check the connection.
 * This minimises the impact of continuous additional connection checks -
 * each of which requires a round trip to the server - but handles most
 * network issues.
 * Returns whether the connection is considered still valid.
 *
 * WARNING: This method may return NO if the current thread is cancelled!
 *          You MUST check the isCancelled flag before using the result!
 */
- (BOOL)checkConnectionIfNecessary
{
	// If the connection has been dropped in the background, trigger a
	// reconnect and return the success state here
	if (state == SPMySQLConnectionLostInBackground) {
		return [self _reconnectAllowingRetries:YES];
	}
	
	// If the connection was recently used, return success
	if (_elapsedSecondsSinceAbsoluteTime(lastConnectionUsedTime) < 30) {
		return YES;
	}
	
	// Otherwise check the connection
	return [self checkConnection];
}

/**
 * Retrieve the time elapsed since the connection was established, in seconds.
 * This time is retrieved in a monotonically increasing fashion and is high
 * precision; it is used internally for query timing, and is reset on reconnections.
 * If no connection is currently active, returns -1.
 */
- (double)timeConnected
{
	if (initialConnectTime == 0) return -1;

	return _elapsedSecondsSinceAbsoluteTime(initialConnectTime);
}

/**
 * Returns YES if the user chose to disconnect at the last "connection failure"
 * prompt, NO otherwise.  This can be used to alter behaviour in response to state
 * changes.
 */
- (BOOL)userTriggeredDisconnect
{
	return userTriggeredDisconnect;
}

/**
 * Returns true if the connected server runs MariaDB > 10.2, false Otherwise
 */
- (BOOL)isNotMariadb103
{
    serverVariableVersion = [[NSString alloc] initWithCString:mysql_get_server_info(mySQLConnection) encoding:NSISOLatin1StringEncoding];
    NSLog(@"%@", [serverVariableVersion lowercaseString]);
    NSString *someRegexp = @"(.*)10(\.[3-9]+[0-9]*(\.[0-9]*))*-(mariadb)(.*)";
    NSPredicate *myTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", someRegexp];
    
    if ([myTest evaluateWithObject: [serverVariableVersion lowercaseString]]){
        return false;
    }
    return true;
}

#pragma mark -
#pragma mark General connection utilities

+ (NSString *)findSocketPath
{
	NSFileManager *fileManager = [NSFileManager defaultManager];

	NSArray *possibleSocketLocations = @[
		@"/tmp/mysql.sock",                                     // Default
		@"/Applications/MAMP/tmp/mysql/mysql.sock",             // MAMP default location
		@"/Applications/xampp/xamppfiles/var/mysql/mysql.sock", // XAMPP default location
		@"/var/mysql/mysql.sock",                               // Mac OS X Server default
		@"/opt/local/var/run/mysqld/mysqld.sock",               // MacPorts MySQL
		@"/opt/local/var/run/mysql4/mysqld.sock",               // MacPorts MySQL 4
		@"/opt/local/var/run/mysql5/mysqld.sock",               // MacPorts MySQL 5
		@"/opt/local/var/run/mariadb-10.0/mysqld.sock",         // MacPorts MariaDB 10.0
		@"/opt/local/var/run/mariadb-10.1/mysqld.sock",         // MacPorts MariaDB 11.0
		@"/usr/local/zend/mysql/tmp/mysql.sock",                // Zend Server CE (see Issue #1251)
		@"/var/run/mysqld/mysqld.sock",                         // As used on Debian/Gentoo
		@"/var/tmp/mysql.sock",                                 // As used on FreeBSD
		@"/var/lib/mysql/mysql.sock",                           // As used by Fedora
		@"/opt/local/lib/mysql/mysql.sock"
	];

	for(NSString *path in possibleSocketLocations) {
		if([fileManager fileExistsAtPath:path]) return path;
	}

	return nil;
}

@end

#pragma mark -
#pragma mark Private API

//http://alastairs-place.net/blog/2013/01/10/interesting-os-x-crash-report-tidbits/
/* CrashReporter info */
const char *__crashreporter_info__ = NULL;
asm(".desc ___crashreporter_info__, 0x10");

@implementation SPMySQLConnection (PrivateAPI)

/**
 * Handle a connection using previously set parameters, returning success or failure.
 */
- (BOOL)_connect
{
	// If a connection is already active in some form, throw an exception
	if (state != SPMySQLDisconnected && state != SPMySQLConnectionLostInBackground) {
		@synchronized (self) {
			double diff = _elapsedSecondsSinceAbsoluteTime(initialConnectTime);
			asprintf(&__crashreporter_info__, "Attempted to connect a connection that is not disconnected (SPMySQLConnectionState=%d).\nIf state==2: Previous connection made %lfs ago from: %s", state, diff, [_debugLastConnectedEvent cStringUsingEncoding:NSUTF8StringEncoding]);
			__builtin_trap();
		}
		[NSException raise:NSInternalInconsistencyException format:@"Attempted to connect a connection that is not disconnected (SPMySQLConnectionState=%d).", state];
		return NO;
	}
	state = SPMySQLConnecting;

	if (userTriggeredDisconnect) {
		return NO;
	}

	// Lock the connection for safety
	[self _lockConnection];

	// Attempt the connection
	mySQLConnection = [self _makeRawMySQLConnectionWithEncoding:encoding isMasterConnection:YES];

	// If the connection failed, reset state and return
	if (!mySQLConnection) {
		[self _unlockConnection];
		state = SPMySQLDisconnected;
		return NO;
	}

	// If the connection was cancelled, clean up and don't continue
	if (userTriggeredDisconnect) {
		mysql_close(mySQLConnection);
		mySQLConnection = NULL;
		[self _unlockConnection];
		return NO;
	}

	// Successfully connected - record connected state and reset tracking variables
	state = SPMySQLConnected;

	@synchronized (self) {
		initialConnectTime = mach_absolute_time();
		[_debugLastConnectedEvent release];
		_debugLastConnectedEvent = [[NSString alloc] initWithFormat:@"thread=%@ stack=%@",[NSThread currentThread],[NSThread callStackSymbols]];
	}

	mysqlConnectionThreadId = mySQLConnection->thread_id;
	lastConnectionUsedTime = initialConnectTime;

	// Copy the server version string to the instance variable
	if (serverVariableVersion) [serverVariableVersion release], serverVariableVersion = nil;
	// the mysql_get_server_info() function
	//   * returns the version name that is part of the initial connection handshake.
	//   * Unless the connection failed, it will always return a non-null buffer containing at least a '\0'.
	//   * It will never affect the error variables (since it only returns a struct member)
	//
	// At that point (handshake) there is no charset and it's highly unlikely this will ever contain something other than ASCII,
	// but to be safe, we'll use the Latin1 encoding which won't bail on invalid chars.
	serverVariableVersion = [[NSString alloc] initWithCString:mysql_get_server_info(mySQLConnection) encoding:NSISOLatin1StringEncoding];
	// this one can actually change the error state, but only if the server version string is not set (ie. no connection)
	serverVersionNumber = mysql_get_server_version(mySQLConnection);

	// Update SSL state
	connectedWithSSL = NO;
	if (useSSL) connectedWithSSL = (mysql_get_ssl_cipher(mySQLConnection))?YES:NO;
	if (useSSL && !connectedWithSSL) {
		if ([delegate respondsToSelector:@selector(connectionFellBackToNonSSL:)]) {
			[delegate connectionFellBackToNonSSL:self];
		}
	}

	// Reset keepalive variables
	lastKeepAliveTime = 0;
	keepAlivePingFailures = 0;

	// Clear the connection error record
	[self _updateLastErrorInfos];

	// Unlock the connection
	[self _unlockConnection];

	// Update connection variables to be in sync with the server state.  As this performs
	// a query, ensure the connection is still up afterwards (!)
	[self _updateConnectionVariables];
	if (state != SPMySQLConnected) return NO;

	// Now connection is established and verified, reset the counter
	reconnectionRetryAttempts = 0;

	// Update the maximum query size
	[self _updateMaxQuerySize];

	return YES;
}

/**
 * Make a connection using the class connection settings, returning a MySQL
 * connection object on success.
 */
- (MYSQL *)_makeRawMySQLConnectionWithEncoding:(NSString *)encodingName isMasterConnection:(BOOL)isMaster
{
	if ([[NSThread currentThread] isCancelled]) return NULL;

	// Set up the MySQL connection object
	MYSQL *theConnection = mysql_init(NULL);
	if (!theConnection) return NULL;

	// Calling mysql_init will have automatically installed per-thread variables if necessary,
	// so track their installation for removal and to avoid recreating again.
	[self _validateThreadSetup];

	// Disable automatic reconnection, as it's handled in-framework to preserve
	// options, encodings and connection state.
	my_bool falseMyBool = FALSE;
	mysql_options(theConnection, MYSQL_OPT_RECONNECT, &falseMyBool);

	// Set the connection timeout
	mysql_options(theConnection, MYSQL_OPT_CONNECT_TIMEOUT, (const void *)&timeout);

	// Set the connection encoding
	NSStringEncoding connectEncodingNS = [SPMySQLConnection stringEncodingForMySQLCharset:[encodingName UTF8String]];
	mysql_options(theConnection, MYSQL_SET_CHARSET_NAME, [encodingName UTF8String]);

	// Set up the connection variables in the format MySQL needs, from the class-wide variables
	const char *theHost = NULL;
	const char *theUsername = "";
	const char *thePassword = NULL;
	const char *theSocket = NULL;

	if (host) theHost = [host UTF8String]; //mysql calls getaddrinfo on the hostname. Apples code uses -UTF8String in that situation.
	if (username) theUsername = _cStringForStringWithEncoding(username, connectEncodingNS, NULL); //during connect this is in MYSQL_SET_CHARSET_NAME encoding

	// If a password was supplied, use it; otherwise ask the delegate if appropriate.
	//
	// Note that password has no charset in mysql: If a user password is set to 'ü' on a latin1 connection
	// and you later try to connect on an UTF-8 terminal (or vice versa) it will fail. The MySQL (5.5) manual wrongly states that
	// MYSQL_SET_CHARSET_NAME has influence over that, but it does not and could not, since the password is hashed by the client
	// before transmitting it to the server and the (5.5) client has no charset support, effectively treating password as
	// a NUL-terminated byte array.
	// There is one exception, though: The "mysql_clear_password" auth plugin sends the password in plaintext and the server side
	// MAY choose to do a charset conversion as appropriate before handing it to whatever backend is used.
	// Since we don't know which auth plugin server and client will agree upon, we'll do as the manual says...
	if (password) {
		thePassword = _cStringForStringWithEncoding(password, connectEncodingNS, NULL);
	} else if ([delegate respondsToSelector:@selector(keychainPasswordForConnection:)]) {
		thePassword = _cStringForStringWithEncoding([delegate keychainPasswordForConnection:self], connectEncodingNS, NULL);
	}

	// If set to use a socket and a socket was supplied, use it; otherwise, search for a socket to use
	if (useSocket) {
		//default to user supplied path
		NSString *mySocketPath = socketPath;
		//if none was given, search in the default locations instead
		if (![mySocketPath length]) {
			mySocketPath = [SPMySQLConnection findSocketPath];
		}
		//get C string if we have a path (danger: method will throw on empty/nil string!)
		if([mySocketPath length]) {
			theSocket = [mySocketPath fileSystemRepresentation];
		}
	}

	// Apply SSL if appropriate
	if (useSSL) {
		const char *theSSLKeyFilePath = NULL;
		const char *theSSLCertificatePath = NULL;
		const char *theCACertificatePath = NULL;
		const char *theSSLCiphers = SPMySQLSSLPermissibleCiphers;

		if ([sslKeyFilePath length]) {
			theSSLKeyFilePath = [[sslKeyFilePath stringByExpandingTildeInPath] fileSystemRepresentation];
		}
		if ([sslCertificatePath length]) {
			theSSLCertificatePath = [[sslCertificatePath stringByExpandingTildeInPath] fileSystemRepresentation];
		}
		if ([sslCACertificatePath length]) {
			theCACertificatePath = [[sslCACertificatePath stringByExpandingTildeInPath] fileSystemRepresentation];
		}
		if(sslCipherList) {
			theSSLCiphers = [sslCipherList UTF8String];
		}

		// Calling mysql_ssl_set() to libmysqlclient only means that connecting with SSL would be nice.
		// If the server doesn't support SSL though, it will *silently* fall back to plaintext and in the worst case even transmit
		// the password in cleartext.
		//
		// Setting MYSQL_OPT_SSL_MODE is required, to actually make it abort the connection if the server doesn't signal SSL support.
		//
		//   mysql 5.5.55+
		//   mysql 5.6.36+
		//   mysql 5.7.11+ (5.7.3 - 5.7.10 with a different name)
		//   mysql 8.0+
		mysql_ssl_set(theConnection, theSSLKeyFilePath, theSSLCertificatePath, theCACertificatePath, NULL, theSSLCiphers);
		enum mysql_ssl_mode opt_ssl_mode = SSL_MODE_REQUIRED;
		if(mysql_options(theConnection, MYSQL_OPT_SSL_MODE, (void *)&opt_ssl_mode)) {
			if(isMaster) {
				[self _updateLastErrorMessage:@"libmysqlclient is missing support for MYSQL_OPT_SSL_MODE"];
				[self _updateLastSqlstate:@"HY000"];
				[self _updateLastErrorID:2026];
			}
			return NULL;
		}
	}

	MYSQL *connectionStatus = mysql_real_connect(theConnection, theHost, theUsername, thePassword, NULL, (unsigned int)port, theSocket, [self clientFlags]);

	// If the connection failed, return NULL
	if (theConnection != connectionStatus) {
		// If the connection is the master connection, record the error state
		if (isMaster) {
			// <TODO>
			// this is tricky: mysql_error() is supposed to return data encoded in character_set_results (in mysql 5.5+),
			// yet the whole API treats it as if it were a plain C string.
			// So if the charset is e.g. utf16 the mysql server will itself fall over that and return an empty error message
			// (5.5, 5.7: the message is really missing at the network layer).
			//   (Side Note: There is a workaround for server generated error messages: "show warnings" will also include errors
			//               and because it uses a regular results table it can contain the actual error message)
			//
			// Before 5.5 things are much worse, because the charset of the message depends on the language of the error messages
			// (which can be changed at runtime per session (or at launch time in 4.1)) plus all arguments in the template string
			// will retain their original encoding.
			// So if you connect with utf8 to a server with russian locale the error message will be in koi8r and contain the name of
			// an erroneus value in utf8...
			//
			// On the other hand mysql_error() may also return errors generated by the client locally.
			// The client has no charset support and simply assumes the local charset is ASCII-compatible.
			// The english messages are compiled into the client (see libmysql/errmsg.c and include/errmsg.h).
			// We could use a little trick, though: client errors are in the exclusive range 2000 to 2999 (CR_MIN_ERROR/CR_MAX_ERROR)
			// and all their string arguments are either hostnames or file system paths, which on OS X use UTF-8.
			[self _updateLastErrorMessage:[self _stringForCString:mysql_error(theConnection)]];
			// </TODO>
			[self _updateLastErrorID:mysql_errno(theConnection)];
			// sqlstate is always an ASCII string, regardless of charset (but use latin1 anyway as that is less picky about invalid bytes)
			[self _updateLastSqlstate:_stringForCStringWithEncoding(mysql_sqlstate(theConnection),NSISOLatin1StringEncoding)];
		}

		return NULL;
	}

	// Ensure automatic reconnection is disabled for older versions
	theConnection->reconnect = 0;

	// Successful connection - return the handle
	return theConnection;
}

/**
 * Perform a reconnection task, either once-only or looping as requested.  If looping is
 * permitted and this method fails, it will ask how to proceed and loop depending on
 * the status, not returning control until either a connection has been established or
 * the connection and document have been closed.
 * Runs its own autorelease pool as sometimes called in a thread following proxy changes
 * (where the return code doesn't matter).
 *
 * WARNING: This method may exit early returning NO if the current thread is cancelled!
 *          You MUST check the isCancelled flag before using the result!
 */
- (BOOL)_reconnectAllowingRetries:(BOOL)canRetry
{
	if (userTriggeredDisconnect) return NO;
	BOOL reconnectSucceeded = NO;

	@autoreleasepool {
		// Check whether a reconnection attempt is already being made - if so, wait
		// and return the status of that reconnection attempt.  This improves threaded
		// use of the connection by preventing reconnect races.
		if (reconnectingThread && !pthread_equal(reconnectingThread, pthread_self())) {

			// Loop in a panel runloop mode until the reconnection has processed; if an iteration
			// takes less than the requested 0.1s, sleep instead.
			while (reconnectingThread) {
				uint64_t loopIterationStart_t = mach_absolute_time();

				[[NSRunLoop currentRunLoop] runMode:NSModalPanelRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
				if (_elapsedSecondsSinceAbsoluteTime(loopIterationStart_t) < 0.1) {
					usleep(100000 - (useconds_t)(1000000 * _elapsedSecondsSinceAbsoluteTime(loopIterationStart_t)));
				}
			}

			// Continue only if the reconnection being waited on was a background attempt
			if (!(state == SPMySQLConnectionLostInBackground && canRetry)) {
				return (state == SPMySQLConnected);
			}
		}

		if ([[NSThread currentThread] isCancelled]) {
			return NO;
		}

		reconnectingThread = pthread_self();

		// Store certain details about the connection, so that if the reconnection is successful
		// they can be restored.  This has to be treated separately from _restoreConnectionDetails
		// as a full connection reinitialises certain values from the server.
		if (!encodingToRestore) {
			encodingToRestore = [encoding copy];
			encodingUsesLatin1TransportToRestore = encodingUsesLatin1Transport;
			databaseToRestore = [database copy];
		}

		// If there is a connection proxy, temporarily disassociate the state change action
		if (proxy) proxyStateChangeNotificationsIgnored = YES;

		// Close the connection if it's active
		[self _disconnect];

		// Lock the connection while waiting for network and proxy
		[self _lockConnection];

		// If no network is present, wait for a short time for one to become available
		[self _waitForNetworkConnectionWithTimeout:10];

		if ([[NSThread currentThread] isCancelled]) {
			[self _unlockConnection];
			reconnectingThread = NULL;
			return NO;
		}

		// If there is a proxy, attempt to reconnect it in blocking fashion
		if (proxy) {
			uint64_t loopIterationStart_t, proxyWaitStart_t;

			// If the proxy is not yet idle after requesting a disconnect, wait for a short time
			// to allow it to disconnect.
			if ([proxy state] != SPMySQLProxyIdle) {

				proxyWaitStart_t = mach_absolute_time();
				while ([proxy state] != SPMySQLProxyIdle) {
					loopIterationStart_t = mach_absolute_time();

					// If the connection timeout has passed, break out of the loop
					if (_elapsedSecondsSinceAbsoluteTime(proxyWaitStart_t) > timeout) break;

					// Allow events to process for 0.25s, sleeping to completion on early return
					[[NSRunLoop currentRunLoop] runMode:NSModalPanelRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
					if (_elapsedSecondsSinceAbsoluteTime(loopIterationStart_t) < 0.25) {
						usleep(250000 - (useconds_t)(1000000 * _elapsedSecondsSinceAbsoluteTime(loopIterationStart_t)));
					}
				}
			}

			// Request that the proxy re-establishes its connection
			[proxy connect];

			// Wait while the proxy connects
			proxyWaitStart_t = mach_absolute_time();
			while (1) {
				loopIterationStart_t = mach_absolute_time();

				// If the proxy has connected, record the new local port and break out of the loop
				if ([proxy state] == SPMySQLProxyConnected) {
					port = [proxy localPort];
					break;
				}

				// If the proxy connection attempt time has exceeded the timeout, break of of the loop.
				if (_elapsedSecondsSinceAbsoluteTime(proxyWaitStart_t) > (timeout + 1)) {
					[proxy disconnect];
					break;
				}

				// Process events for a short time, allowing dialogs to be shown but waiting for
				// the proxy. Capture how long this interface action took, standardising the
				// overall time.
				[[NSRunLoop currentRunLoop] runMode:NSModalPanelRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
				if (_elapsedSecondsSinceAbsoluteTime(loopIterationStart_t) < 0.25) {
					usleep((useconds_t)(250000 - (1000000 * _elapsedSecondsSinceAbsoluteTime(loopIterationStart_t))));
				}

				// Extend the connection timeout by any interface time
				if ([proxy state] == SPMySQLProxyWaitingForAuth) {
					proxyWaitStart_t += mach_absolute_time() - loopIterationStart_t;
				}
			}

			// Having in theory performed the proxy connect, update state
			previousProxyState = [proxy state];
			proxyStateChangeNotificationsIgnored = NO;
		}

		// Unlock the connection
		[self _unlockConnection];

		// If not using a proxy, or if the proxy successfully connected, trigger a connection
		if (!proxy || [proxy state] == SPMySQLProxyConnected) {
			[self _connect];
		}

		// If the reconnection succeeded, restore the connection state as appropriate
		if (state == SPMySQLConnected && ![[NSThread currentThread] isCancelled]) {
			reconnectSucceeded = YES;
			if (databaseToRestore) {
				[self selectDatabase:databaseToRestore];
				[databaseToRestore release], databaseToRestore = nil;
			}
			if (encodingToRestore) {
				[self setEncoding:encodingToRestore];
				[self setEncodingUsesLatin1Transport:encodingUsesLatin1TransportToRestore];
				[encodingToRestore release], encodingToRestore = nil;
			}
		}
			// If the connection failed and the connection is permitted to retry,
			// then retry the reconnection.
		else if (canRetry && ![[NSThread currentThread] isCancelled]) {

			// Default to attempting another reconnect
			SPMySQLConnectionLostDecision connectionLostDecision = SPMySQLConnectionLostReconnect;

			// If the delegate supports the decision process, ask it how to proceed
			if (delegateSupportsConnectionLost) {
				connectionLostDecision = [self _delegateDecisionForLostConnection];
			}
				// Otherwise default to reconnect, but only a set number of times to prevent a runaway loop
			else {
				if (reconnectionRetryAttempts < 5) {
					connectionLostDecision = SPMySQLConnectionLostReconnect;
				} else {
					connectionLostDecision = SPMySQLConnectionLostDisconnect;
				}
				reconnectionRetryAttempts++;
			}

			switch (connectionLostDecision) {
				case SPMySQLConnectionLostDisconnect:
					[self _updateLastErrorMessage:NSLocalizedString(@"User triggered disconnection", @"User triggered disconnection")];
					userTriggeredDisconnect = YES;
					break;

					// By default attempt a reconnect
				default:
					reconnectingThread = NULL;
					reconnectSucceeded = [self _reconnectAllowingRetries:YES];
			}
		}
	}

	reconnectingThread = NULL;
	return reconnectSucceeded;
}

/**
 * Trigger a single reconnection attempt after losing network in the background,
 * setting the state appropriately for connection on next use if this fails.
 */
- (BOOL)_reconnectAfterBackgroundConnectionLoss
{
	if (![self _reconnectAllowingRetries:NO]) {
		state = SPMySQLConnectionLostInBackground;
	}

	return (state == SPMySQLConnected);
}


/**
 * Loop while a connection isn't available; allows blocking while the network is disconnected
 * or still connecting (eg Airport still coming up after sleep).
 */
- (BOOL)_waitForNetworkConnectionWithTimeout:(double)timeoutSeconds
{
	// Set up the reachability target - the host is not important, and is not connected to.
	SCNetworkReachabilityRef reachabilityTarget = SCNetworkReachabilityCreateWithName(NULL, "dev.mysql.com");

	BOOL hostReachable;
	// In a loop until success or the timeout, test reachability
	uint64_t loopStart_t = mach_absolute_time();
	while (1) {
		SCNetworkReachabilityFlags reachabilityStatus;

		// Check reachability
		Boolean flagsValid = SCNetworkReachabilityGetFlags(reachabilityTarget, &reachabilityStatus);

		hostReachable = flagsValid ? YES : NO;

		// Ensure that the network is reachable
		if (hostReachable && !(reachabilityStatus & kSCNetworkReachabilityFlagsReachable)) hostReachable = NO;

		// Ensure that Airport is up/connected if present
		if (hostReachable && (reachabilityStatus & kSCNetworkReachabilityFlagsConnectionRequired)) hostReachable = NO;

		// If the host *is* reachable, return success
		if (hostReachable) break;

		// If the timeout has been exceeded, break out of the loop
		if (_elapsedSecondsSinceAbsoluteTime(loopStart_t) >= timeoutSeconds) break;

		// Sleep before the next loop iteration
		usleep(250000);
	}

	CFRelease(reachabilityTarget);
	return hostReachable;
}

/**
 * Perform a disconnect of any active connections, cleaning up state to match.
 */
- (void)_disconnect
{
	// If state is connection lost, set state directly to disconnected.
	if (state == SPMySQLConnectionLostInBackground) {
		state = SPMySQLDisconnected;
	}

	// Only continue if a connection is active
	if (state != SPMySQLConnected && state != SPMySQLConnecting) {
		return;
	}

	// If a query is active, cancel it
	[self cancelCurrentQuery];

	state = SPMySQLDisconnecting;

	// Allow any pings or cancelled queries  to complete, inside a time limit of ten seconds
	uint64_t disconnectStartTime_t = mach_absolute_time();
	while (![self _tryLockConnection]) {
		usleep(100000);
		if (_elapsedSecondsSinceAbsoluteTime(disconnectStartTime_t) > 10) {
			NSLog(@"%s: Could not acquire connection lock within time limit (10s). Forcing unlock!",__PRETTY_FUNCTION__);
			break;
		}
	}
	[self _unlockConnection];
	[self _cancelKeepAlives];

	[self _lockConnection];
	// Close the underlying MySQL connection if it still appears to be active, and not reading
	// or writing.  While this may result in a leak of the MySQL object, it prevents crashes
	// due to attempts to close a blocked/stuck connection.
	if (mySQLConnection && !mySQLConnection->net.reading_or_writing && mySQLConnection->net.vio && mySQLConnection->net.buff) {
		mysql_close(mySQLConnection);
	}
	mySQLConnection = NULL;
	if (serverVariableVersion) [serverVariableVersion release], serverVariableVersion = nil;
	serverVersionNumber = 0;
	if (database) [database release], database = nil;
	state = SPMySQLDisconnected;
	[self _unlockConnection];

	// If using a connection proxy, disconnect that too
	if (proxy) {
		[proxy performSelectorOnMainThread:@selector(disconnect) withObject:nil waitUntilDone:YES];
	}
}

/**
 * Update connection variables from the server, collecting state and ensuring
 * settings like encoding are in sync.
 */
- (void)_updateConnectionVariables
{
	if (state != SPMySQLConnected && state != SPMySQLConnecting) return;

	// Retrieve all variables from the server in a single query
	SPMySQLResult *theResult = [self queryString:@"SHOW VARIABLES"];
	if (![theResult numberOfRows]) return;

	// SHOW VARIABLES can return binary results on certain MySQL 4 versions; ensure string output
	[theResult setReturnDataAsStrings:YES];

	// Convert the result set into a variables dictionary
	[theResult setDefaultRowReturnType:SPMySQLResultRowAsArray];
	NSMutableDictionary *variables = [NSMutableDictionary new];
	for (NSArray *variableRow in theResult) {
		[variables setObject:[variableRow objectAtIndex:1] forKey:[variableRow objectAtIndex:0]];
	}

	// Get the connection encoding.  Although a specific encoding may have been requested on
	// connection, it may be overridden by init_connect commands or connection state changes.
	// Default to latin1 for older server versions.
	NSString *retrievedEncoding = @"latin1";
	// character_set_results is the charset the strings received from the server will be in
	if ([variables objectForKey:@"character_set_results"]) {
		retrievedEncoding = [variables objectForKey:@"character_set_results"];
	}
	// not used in 4.1+ (?)
	else if ([variables objectForKey:@"character_set"]) {
		retrievedEncoding = [variables objectForKey:@"character_set"];
	}
	// character_set_client is the charset the server expects strings transmitted by us to be in
	else if ([variables objectForKey:@"character_set_client"]) {
		retrievedEncoding = [variables objectForKey:@"character_set_client"]; // fallback for sphinxql
	}
	// character_set_connection is used internally by the server for comparisons.
	// String literals (without a cast) will always be converted from character_set_client to character_set_connection first.
	// As an example:
	//   * Use a client with "SET NAMES utf8"
	//   * Do a "set @@session.character_set_connection = 'latin1';"
	//   * Finally try a "SELECT '犬';" (also try "select _utf8'犬';" for completeness)
	//   * The result will just show a "?"
	// So even though we told the server that the client uses utf8 and the results
	// should be encoded in utf8, too, the character got lost.
	// This happened because the server did a roundtrip of utf8 -> latin1 -> utf8.

	// Update instance variables
	if (encoding) [encoding release];
	encoding = [[NSString alloc] initWithString:retrievedEncoding];
	stringEncoding = [SPMySQLConnection stringEncodingForMySQLCharset:[self _cStringForString:encoding]];
	encodingUsesLatin1Transport = NO;

	// Check the interactive timeout - if it's below five minutes, increase it to ten
	// to improve timeout/keepalive behaviour.  Note that wait_timeout also has be
	// increased; current versions effectively populate the wait timeout from the
	// interactive_timeout for interactive clients, but don't pick up changes.
	if ([variables objectForKey:@"interactive_timeout"]) {
		if ([[variables objectForKey:@"interactive_timeout"] integerValue] < 300) {
			[self queryString:@"SET interactive_timeout=600"];
			[self queryString:@"SET wait_timeout=600"];
		}
	}

	[variables release];
}

/**
 * Restore the connection encoding details as necessary based on previously set
 * details.
 */
- (void)_restoreConnectionVariables
{
	mysqlConnectionThreadId = mySQLConnection->thread_id;
	initialConnectTime = mach_absolute_time();

	[self selectDatabase:database];

	[self setEncoding:encoding];
	[self setEncodingUsesLatin1Transport:encodingUsesLatin1Transport];
}

/**
 * Ensure that the thread this method is called on has been registered for
 * use with MySQL.  MySQL requires thread-specific variables for safe
 * execution.
 *
 * Calling this multiple times per thread is OK.
 */
- (void)_validateThreadSetup
{
	// Check to see whether the handler has already been installed
	if (pthread_getspecific(mySQLThreadInitFlagKey)) return;

	// If not, install it
	mysql_thread_init(); // multiple calls per thread OK.

	// Mark the thread to avoid multiple installs
	pthread_setspecific(mySQLThreadInitFlagKey, &mySQLThreadFlag);

	// Set up the notification handler to deregister it
	[[NSNotificationCenter defaultCenter] addObserver:[self class]
	                                         selector:@selector(_removeThreadVariables:)
	                                             name:NSThreadWillExitNotification
	                                           object:[NSThread currentThread]];
}

/**
 * Remove the MySQL variables and handlers from each closing thread which
 * has had them installed to avoid memory leaks.
 * This is a class method for easy global tracking; it will be called on the appropriate
 * thread automatically.
 */
+ (void)_removeThreadVariables:(NSNotification *)aNotification
{
	mysql_thread_end();
}

@end
