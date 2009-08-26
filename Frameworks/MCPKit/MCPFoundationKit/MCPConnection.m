//
//  $Id$
//
//  MCPConnection.m
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

#import "MCPConnection.h"
#import "MCPResult.h"
#import "MCPStreamingResult.h"
#import "MCPNumber.h"
#import "MCPNull.h"
#import "MCPConnectionProxy.h"

#include <unistd.h>
#include <setjmp.h>
#include <mach/mach_time.h>

static jmp_buf pingTimeoutJumpLocation;
static void forcePingTimeout(int signalNumber);

const unsigned int kMCPConnectionDefaultOption = CLIENT_COMPRESS | CLIENT_REMEMBER_OPTIONS ;
const char         *kMCPConnectionDefaultSocket = MYSQL_UNIX_ADDR;
const unsigned int kMCPConnection_Not_Inited = 1000;
const unsigned int kLengthOfTruncationForLog = 100;

static BOOL	sTruncateLongFieldInLogs = YES;

/**
 * Privte API
 */
@interface MCPConnection (PrivateAPI)

- (void)_getServerVersionString;

@end

@implementation MCPConnection

// Synthesize ivars
@synthesize useKeepAlive;
@synthesize delegateQueryLogging;
@synthesize connectionTimeout;
@synthesize keepAliveInterval;

#pragma mark -
#pragma mark Initialisation

/**
 * Initialise a MySQLConnection without making a connection, most likely useless, except with !{setConnectionOption:withArgument:}.
 *
 * Because this method is not making a connection to any MySQL server, it can not know already what the DB server encoding will be,
 * hence the encoding is set to some default (at present this is NSISOLatin1StringEncoding). Obviously this is reset to a proper
 * value as soon as a DB connection is performed.
 */
- (id)init
{
	if ((self = [super init])) {
		mConnection = mysql_init(NULL);
		mConnected = NO;
		
		if (mConnection == NULL) {
			[self autorelease];
			
			return nil;
		}
		
		mEncoding = NSISOLatin1StringEncoding;
		mConnectionFlags = kMCPConnectionDefaultOption;
		
		queryLock = [[NSLock alloc] init];
		
		connectionHost = nil;
		connectionLogin = nil;
		connectionSocket = nil;
		connectionPassword = nil;
		keepAliveTimer = nil;
		connectionProxy = nil;
		lastKeepAliveSuccess = nil;
		connectionStartTime = -1;
		lastQueryExecutedAtTime = INT_MAX;
		
		// Initialize ivar defaults
		connectionTimeout = 10;
		useKeepAlive      = YES; 
		keepAliveInterval = 60;  
		
		connectionThreadId     = 0;
		maxAllowedPacketSize   = -1;
		lastQueryExecutionTime = 0;
		lastQueryErrorId       = 0;
		lastQueryErrorMessage  = nil;
		lastQueryAffectedRows  = 0;
		
		// Enable delegate query logging by default
		delegateQueryLogging = YES;

		// Default to allowing queries to be reattempted if they fail due to connection issues
		retryAllowed = YES;
		
		// Obtain SEL references
		willQueryStringSEL = @selector(willQueryString:connection:);
		stopKeepAliveTimerSEL = @selector(stopKeepAliveTimer);
		startKeepAliveTimerResettingStateSEL = @selector(startKeepAliveTimerResettingState:);
		cStringSEL = @selector(cStringFromString:);
		
		// Obtain pointers
		cStringPtr = [self methodForSelector:cStringSEL];
		stopKeepAliveTimerPtr = [self methodForSelector:stopKeepAliveTimerSEL];
		startKeepAliveTimerResettingStatePtr = [self methodForSelector:startKeepAliveTimerResettingStateSEL];
	}
	
	return self;
}

/**
 * Inialize connection using the supplied host details.
 */
- (id)initToHost:(NSString *)host withLogin:(NSString *)login usingPort:(int)port
{
	if ((self = [self init])) {
		if (!host) host = @"";
		if (!login) login = @"";
		
		connectionHost = [[NSString alloc] initWithString:host];
		connectionLogin = [[NSString alloc] initWithString:login];
		connectionPort = port;
		connectionSocket = nil;
	}
	
	return self;
}

/**
 * Inialize connection using the supplied socket details.
 */
- (id)initToSocket:(NSString *)socket withLogin:(NSString *)login
{
	if ((self = [self init])) {
		if (!socket || ![socket length]) {
			socket = [self findSocketPath];
			if (!socket) socket = @"";
		}
		
		if (!login) login = @"";
		
		connectionHost = nil;
		connectionLogin = [[NSString alloc] initWithString:login];
		connectionSocket = [[NSString alloc] initWithString:socket];
		connectionPort = 0;
	}
	
	return self;
}

#pragma mark -
#pragma mark Delegate

/**
 * Get the connection's current delegate.
 */
- (id)delegate
{
	return delegate;
}

/**
 * Set the connection's delegate to the supplied object.
 */
- (void)setDelegate:(id)connectionDelegate
{
	delegate = connectionDelegate;
	
	// Check that the delegate implements willQueryString:connection: and cache the result as its used
	// vert frequently.
	delegateResponseToWillQueryString = [delegate respondsToSelector:@selector(willQueryString:connection:)];
}

#pragma mark -
#pragma mark Connection details

/**
 * Sets or updates the connection port - for use with tunnels.
 */
- (BOOL)setPort:(int)thePort
{
	connectionPort = thePort;
	
	return YES;
}

/**
 * Sets the password to be stored locally.
 * Providing a keychain name is much more secure.
 */
- (BOOL)setPassword:(NSString *)thePassword
{
	if (connectionPassword) [connectionPassword release], connectionPassword = nil;
	
	if (!thePassword) thePassword = @"";
	
	connectionPassword = [[NSString alloc] initWithString:thePassword];
	
	return YES;
}

#pragma mark -
#pragma mark Connection proxy

/*
 * Set a connection proxy object to connect through.  This object will be retained locally,
 * and will be automatically connected/connection checked/reconnected/disconnected
 * together with the main connection.
 */
- (BOOL)setConnectionProxy:(id <MCPConnectionProxy>)proxy
{
	connectionProxy = proxy;
	[connectionProxy retain];
	
	currentProxyState = [connectionProxy state];
	[connectionProxy setConnectionStateChangeSelector:@selector(connectionProxyStateChange:) delegate:self];
	
	return YES;
}

/**
 * Handle any state changes in the associated connection proxy.
 */
- (void)connectionProxyStateChange:(id <MCPConnectionProxy>)proxy
{
	int newState = [proxy state];
	
	// Restart the tunnel if it dies
	if (mConnected && newState == PROXY_STATE_IDLE && currentProxyState == PROXY_STATE_CONNECTED) {
		currentProxyState = newState;
		[connectionProxy setConnectionStateChangeSelector:nil delegate:nil];
		[self reconnect];
		
		return;
	}
	
	currentProxyState = newState;
}

#pragma mark -
#pragma mark Connection

/**
 * Add a new connection method, intended for use with the init methods above.
 * Uses the stored details to instantiate a connection to the specified server,
 * including custom timeouts - used for pings, not for long-running commands.
 */
- (BOOL)connect
{
	const char	*theLogin = [self cStringFromString:connectionLogin];
	const char	*theHost;
	const char	*thePass;
	const char	*theSocket;
	void		*theRet;
	
	// Disconnect if a connection is already active
	if (mConnected) {
		[self disconnect];
		mConnection = mysql_init(NULL);
		if (mConnection == NULL) return NO;
	}

	if (mConnection != NULL) {

		// Ensure the custom timeout option is set
		mysql_options(mConnection, MYSQL_OPT_CONNECT_TIMEOUT, (const void *)&connectionTimeout);

		// Set automatic reconnection for use with mysql_ping
		// TODO: Automatic reconnection is currently used by MCPConnection, using thread IDs to
		// detect when this has occurred.  Custom reconnection may be preferable.
		my_bool trueBool = TRUE;
		mysql_options(mConnection, MYSQL_OPT_RECONNECT, &trueBool);
	}
	
	// Set the host as appropriate
	if (!connectionHost || ![connectionHost length]) {
		theHost = NULL;
		
		
	} else {
		theHost = [self cStringFromString:connectionHost];
	}
	
	// Use the default socket if none is set, or set appropriately
	if (connectionSocket == nil || ![connectionSocket length]) {
		theSocket = kMCPConnectionDefaultSocket;
	} else {
		theSocket = [self cStringFromString:connectionSocket];
	}
	
	// Select the password from the provided method
	if (!connectionPassword) {
		if (delegate && [delegate respondsToSelector:@selector(keychainPasswordForConnection:)]) {
			thePass = [self cStringFromString:[delegate keychainPasswordForConnection:self]];
		}
	} else {		
		thePass = [self cStringFromString:connectionPassword];
	}

	// Connect
	theRet = mysql_real_connect(mConnection, theHost, theLogin, thePass, NULL, connectionPort, theSocket, mConnectionFlags);
	thePass = NULL;
	
	if (theRet != mConnection) {
		[self setLastErrorMessage:nil];
		
		lastQueryErrorId = mysql_errno(mConnection);
		
		return mConnected = NO;
	}
	
	mConnected = YES;
	connectionStartTime = mach_absolute_time();
	mEncoding = [MCPConnection encodingForMySQLEncoding:mysql_character_set_name(mConnection)];
	connectionThreadId = mConnection->thread_id;
	[self timeZone]; // Getting the timezone used by the server.
	
	isMaxAllowedPacketEditable = [self isMaxAllowedPacketEditable];
	
	if (![self fetchMaxAllowedPacket]) {
		[self setLastErrorMessage:nil];
		
		lastQueryErrorId = mysql_errno(mConnection);
		
		return mConnected = NO;
	}

	// Start the keepalive timer
	[self startKeepAliveTimerResettingState:YES];
	
	return mConnected;
}

/**
 * Disconnect the current connection.
 */
- (void)disconnect
{
	if (mConnected) {
		mysql_close(mConnection);
		mConnection = NULL;
	}
	
	mConnected = NO;
	
	if (connectionProxy) {
		[connectionProxy disconnect];
	}
	
	if (serverVersionString != nil) {
		[serverVersionString release];
		serverVersionString = nil;
	}
	
	[self stopKeepAliveTimer];
}

/**
 * Reconnect to the currently "active" - but possibly disconnected - connection, using the
 * stored details.
 * Error checks extensively - if this method fails, it will ask how to proceed and loop depending
 * on the status, not returning control until either a connection has been established or
 * the connection and document have been closed.
 */
- (BOOL)reconnect
{
	NSString *currentEncoding = nil;
	BOOL currentEncodingUsesLatin1Transport = NO;
	NSString *currentDatabase = nil;
	
	// Store the currently selected database and encoding so they can be re-set if reconnection was successful
	if (delegate && [delegate respondsToSelector:@selector(onReconnectShouldSelectDatabase:)]) {
		currentDatabase = [NSString stringWithString:[delegate onReconnectShouldSelectDatabase:self]];
	}
	
	if (delegate && [delegate respondsToSelector:@selector(onReconnectShouldUseEncoding:)]) {
		currentEncoding = [NSString stringWithString:[delegate onReconnectShouldUseEncoding:self]];
	}
	
	if (delegate && [delegate respondsToSelector:@selector(connectionEncodingViaLatin1:)]) {
		currentEncodingUsesLatin1Transport = [delegate connectionEncodingViaLatin1:self];
	}
	
	// Close the connection if it exists.
	if (mConnected) {
		mysql_close(mConnection);
		mConnection = NULL;
	}
	
	mConnected = NO;
	
	// If there is a tunnel, ensure it's disconnected and attempt to reconnect it in blocking fashion
	if (connectionProxy) {
		[connectionProxy setConnectionStateChangeSelector:nil delegate:nil];
		if ([connectionProxy state] != PROXY_STATE_IDLE) [connectionProxy disconnect];
		[connectionProxy connect];
		NSDate *tunnelStartDate = [NSDate date], *interfaceInteractionTimer;
		
		// Allow the tunnel to attempt to connect in a loop
		while (1) {
			if ([connectionProxy state] == PROXY_STATE_CONNECTED) {
				connectionPort = [connectionProxy localPort];
				break;
			}
			if ([[NSDate date] timeIntervalSinceDate:tunnelStartDate] > (connectionTimeout + 1)) {
				[connectionProxy disconnect];
				break;
			}
			
			// Process events for a short time, allowing dialogs to be shown but waiting for the tunnel
			interfaceInteractionTimer = [NSDate date];
			[[NSRunLoop currentRunLoop] runMode:NSModalPanelRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
			tunnelStartDate = [tunnelStartDate addTimeInterval:([[NSDate date] timeIntervalSinceDate:interfaceInteractionTimer] - 0.25)];
		}
		
		currentProxyState = [connectionProxy state];
		[connectionProxy setConnectionStateChangeSelector:@selector(connectionProxyStateChange:) delegate:self];
	}
	
	if (!connectionProxy || [connectionProxy state] == PROXY_STATE_CONNECTED) {
		
		// Attempt to reinitialise the connection - if this fails, it will still be set to NULL.
		if (mConnection == NULL) {
			mConnection = mysql_init(NULL);
		}
		
		if (mConnection != NULL) {
			
			// Attempt to reestablish the connection
			[self connect];
		}
	}
	
	// If the connection was successfully established, reselect the old database and encoding if appropriate.
	if (mConnected) {
		if (currentDatabase) {
			[self selectDB:currentDatabase];
		}
		
		if (currentEncoding) {
			[self queryString:[NSString stringWithFormat:@"/*!40101 SET NAMES '%@' */", currentEncoding]];
			[self setEncoding:[MCPConnection encodingForMySQLEncoding:[currentEncoding UTF8String]]];
			if (currentEncodingUsesLatin1Transport) {
				[self queryString:@"/*!40101 SET CHARACTER_SET_RESULTS=latin1 */"];
			}
		}
	}
	else {
		[self setLastErrorMessage:nil];
		
		// Default to retry
		MCPConnectionCheck failureDecision = MCPConnectionCheckReconnect;
		
		// Ask delegate what to do
		if ([delegate respondsToSelector:@selector(connectionLost:)]) {
			failureDecision = [delegate connectionLost:self];
		}
		
		switch (failureDecision) {				
			case MCPConnectionCheckDisconnect:
				return NO;				
			default:
				return [self reconnect];
		}
	}
	
	return mConnected;
}

/**
 * Returns YES if the MCPConnection is connected to a DB, NO otherwise.
 */
- (BOOL)isConnected
{
	return mConnected;
}

/**
 * Checks if the connection to the server is still on.
 * If not, tries to reconnect (changing no parameters from the MYSQL pointer).
 * This method just uses mysql_ping().
 */
- (BOOL)checkConnection
{
	if (!mConnected) return NO;
	
	BOOL connectionVerified = FALSE;
	
	// Check whether the connection is still operational via a wrapped version of MySQL ping.
	connectionVerified = [self pingConnection];
	
	// If the connection doesn't appear to be responding, show a dialog asking how to proceed
	if (!connectionVerified) {
		
		// Default to retry
		MCPConnectionCheck failureDecision = MCPConnectionCheckRetry;
		
		// Ask delegate what to do
		if (delegate && [delegate respondsToSelector:@selector(connectionLost:)]) {
			failureDecision = [delegate connectionLost:self];
		} else {
			failureDecision = MCPConnectionCheckDisconnect;
		}
		
		switch (failureDecision) {
			// 'Reconnect' has been selected. Request a reconnect, and retry.
			case MCPConnectionCheckReconnect:
				[self reconnect];
				
				return [self checkConnection];
				
			// 'Disconnect' has been selected. Close the parent window, which will handle disconnections, and return false.
			case MCPConnectionCheckDisconnect:
				return NO;
				
			// 'Retry' has been selected - return a recursive call.
			case MCPConnectionCheckRetry:
				return [self checkConnection];
		}
		
		// If a connection exists, check whether the thread id differs; if so, the connection has
		// probably been reestablished and we need to reset the connection encoding
	} else if (connectionThreadId != mConnection->thread_id) [self restoreConnectionDetails];
	
	return connectionVerified;
}

/**
 * This function provides a method of pinging the remote server while running a SIGALRM
 * to enforce the specified connection time.  This is low-level but effective, and required
 * because low-level net reads can block indefintely if the remote server disappears or on
 * network issues - setting the MYSQL_OPT_READ_TIMEOUT (and the WRITE equivalent) would "fix"
 * ping, but cause long queries to be terminated.
 * Unlike mysql_ping, this function returns FALSE on failure and TRUE on success.
 */
- (BOOL) pingConnection
{
	struct sigaction timeoutAction;
	NSDate *startDate = [[NSDate alloc] initWithTimeIntervalSinceNow:0];
	BOOL pingSuccess = FALSE;
	
	// Construct the SIGALRM to fire after the connection timeout if it isn't cleared, calling the forcePingTimeout function.
	timeoutAction.sa_handler = forcePingTimeout;
	sigemptyset(&timeoutAction.sa_mask);
	timeoutAction.sa_flags = 0;
	sigaction(SIGALRM, &timeoutAction, NULL);
	alarm(connectionTimeout+1);

	[queryLock lock];
	
	// Set up a "restore point", returning 0; if longjmp is used later with this reference, execution
	// jumps back to this point and returns a nonzero value, so this function evaluates to false when initially
	// set and true if it's called again.
	if (setjmp(pingTimeoutJumpLocation)) {
		
		// The connection timed out - we want to return false.
		pingSuccess = FALSE;
		
		// On direct execution:
	} else {
		
		// Run mysql_ping, which returns 0 on success, and otherwise an error.
		pingSuccess = (BOOL)(! mysql_ping(mConnection));

		// If the ping failed within a second, try another one; this is because a terminated-but-then
		// restored connection is at times restored or functional after a ping, but the ping still returns
		// an error.  This additional check ensures the returned status is correct with minimal other effect.
		if (!pingSuccess && ([startDate timeIntervalSinceNow] > -1)) {
			pingSuccess = (BOOL)(! mysql_ping(mConnection));
		}
	}
	
	[queryLock unlock];

	// Reset and clear the SIGALRM used to check connection timeouts.
	alarm(0);
	timeoutAction.sa_handler = SIG_IGN;
	sigemptyset(&timeoutAction.sa_mask);
	timeoutAction.sa_flags = 0;
	sigaction(SIGALRM, &timeoutAction, NULL);
	
	[startDate release];
	
	return pingSuccess;
}

/**
 * This function is paired with pingConnection, and provides a method of enforcing the connection
 * timeout when mysql_ping does not respect the specified limits.
 */
static void forcePingTimeout(int signalNumber)
{
	longjmp(pingTimeoutJumpLocation, 1);
}

/**
 * Restarts a keepalive to fire in the future.
 */
- (void)startKeepAliveTimerResettingState:(BOOL)resetState
{
	if (keepAliveTimer) [self stopKeepAliveTimer];
	if (!mConnected) return;
	
	if (resetState && lastKeepAliveSuccess) {
		[lastKeepAliveSuccess release];
		lastKeepAliveSuccess = nil;
	}
	
	if (useKeepAlive && keepAliveInterval) {
		keepAliveTimer = [NSTimer
						  scheduledTimerWithTimeInterval:keepAliveInterval
						  target:self
						  selector:@selector(keepAlive:)
						  userInfo:nil
						  repeats:NO];
		[keepAliveTimer retain];
	}
}

/**
 * Stops a keepalive if one is set for the future.
 */
- (void)stopKeepAliveTimer
{
	if (!keepAliveTimer) return;
	[keepAliveTimer invalidate];
	[keepAliveTimer release];
	keepAliveTimer = nil;
}

/**
 * Keeps a connection alive by running a ping.
 */
- (void)keepAlive:(NSTimer *)theTimer
{
	if (!mConnected) return;
	
	// If there a successful keepalive record exists, and it was more than 5*keepaliveinterval ago,
	// abort.  This prevents endless spawning of threads in a state where the connection has been
	// cut but mysql doesn't pick up on the fact - see comment for pingConnection above.  The same
	// forced-timeout approach cannot be used here on a background thread.
	// When the connection is disconnected in code, these 5 "hanging" threads are automatically cleaned.
	if (lastKeepAliveSuccess && [lastKeepAliveSuccess timeIntervalSinceNow] < -5 * keepAliveInterval) return;
	
	[NSThread detachNewThreadSelector:@selector(threadedKeepAlive) toTarget:self withObject:nil];
	[self startKeepAliveTimerResettingState:NO];
}

/**
 * A threaded keepalive to avoid blocking the interface
 */
- (void)threadedKeepAlive
{
	if (!mConnected) return;

	if (![queryLock tryLock]) return;
	[queryLock unlock];

	// Don't wrap this ping in a lock - will block main thread on read issues, and can't use
	// the setjmp/lngjmp safety net in a thread.
	mysql_ping(mConnection);
	
	if (lastKeepAliveSuccess) {
		[lastKeepAliveSuccess release];
		lastKeepAliveSuccess = nil;
	}
	
	lastKeepAliveSuccess = [[NSDate alloc] initWithTimeIntervalSinceNow:0];
}

/**
 * Restore the connection encoding details as necessary based on the delegate-provided
 * details.
 */
- (void)restoreConnectionDetails
{
	connectionThreadId = mConnection->thread_id;
	connectionStartTime = mach_absolute_time();
	[self fetchMaxAllowedPacket];
	
	if (delegate && [delegate respondsToSelector:@selector(onReconnectShouldUseEncoding:)]) {
		[self queryString:[NSString stringWithFormat:@"/*!40101 SET NAMES '%@' */", [NSString stringWithString:[delegate onReconnectShouldUseEncoding:self]]]];
		if (delegate && [delegate respondsToSelector:@selector(connectionEncodingViaLatin1:)]) {
			if ([delegate connectionEncodingViaLatin1:self]) [self queryString:@"/*!40101 SET CHARACTER_SET_RESULTS=latin1 */"];
		}
	}
}

/**
 * Allow controlling over whether queries are allowed to retry after a connection failure.
 * This defaults to YES on init, and is intended to allow temporary disabling in situations
 * where the query result is checked and displayed to the user without any repurcussions on
 * failure.
 */
- (void)setAllowQueryRetries:(BOOL)allow
{
	retryAllowed = allow;
}

/**
 * Retrieve the time elapsed since the connection was established, in seconds.
 * This time is retrieved in a monotonically increasing fashion and is high
 * precision; it is used internally for query timing, and is reset on reconnections.
 */
- (double)timeConnected
{
	if (connectionStartTime == -1) return -1;

	uint64_t currentTime_t = mach_absolute_time() - connectionStartTime;
	Nanoseconds elapsedTime = AbsoluteToNanoseconds(*(AbsoluteTime *)&(currentTime_t));

	return (((double)UnsignedWideToUInt64(elapsedTime)) * 1e-9);
}

#pragma mark -
#pragma mark Server versions

/**
 * rReturn the server major version or -1 on fail
 */
- (int)serverMajorVersion
{
	
	if (mConnected) {
		if (serverVersionString == nil) {
			[self _getServerVersionString];
		}

		if (serverVersionString != nil) {
			return [[[serverVersionString componentsSeparatedByString:@"."] objectAtIndex:0] intValue];
		} 
	} 
	
	return -1;
}

/**
 * Return the server minor version or -1 on fail
 */
- (int)serverMinorVersion
{
	
	if (mConnected) {
		if (serverVersionString == nil) {
			[self _getServerVersionString];
		}
		
		if(serverVersionString != nil) {
			return [[[serverVersionString componentsSeparatedByString:@"."] objectAtIndex:1] intValue];
		}
	}
	
	return -1;
}

/**
 * Return the server release version or -1 on fail
 */
- (int)serverReleaseVersion
{
	if (mConnected) {
		if (serverVersionString == nil) {
			[self _getServerVersionString];
		}
		
		if (serverVersionString != nil) {
			NSString *s = [[serverVersionString componentsSeparatedByString:@"."] objectAtIndex:2];
			return [[[s componentsSeparatedByString:@"-"] objectAtIndex:0] intValue];
		}
	}
	
	return -1;
}

#pragma mark -
#pragma mark MySQL defaults

/**
 * This class is used to keep a connection with a MySQL server, it correspond to the MYSQL structure of the C API, or the database handle of the PERL DBI/DBD interface.
 *
 * You have to start any work on a MySQL server by getting a working MCPConnection object.
 *
 * Most likely you will use this kind of code:
 * 
 *
 *   MCPConnection	*theConnec = [MCPConnection alloc];
 *   MCPResult	*theRes;
 *   
 *   theConnec = [theConnec initToHost:@"albert.com" withLogin:@"toto" password:@"albert" usingPort:0];
 *   [theConnec selectDB:@"db1"];
 *   theRes = [theConnec queryString:@"select * from table1"];
 *   ...
 *
 * Failing to properly release your MCPConnection(s) object might cause a MySQL crash!!! (recovered if the server was started using mysqld_safe).
 *
 * Gets a proper Locale dictionary to use formater to parse strings from MySQL.
 * For example strings representing dates should give a proper Locales for use with methods such as NSDate::dateWithNaturalLanguageString: locales:
 */
+ (NSDictionary *)getMySQLLocales
{
	NSMutableDictionary	*theLocalDict = [NSMutableDictionary dictionaryWithCapacity:12];
	
	[theLocalDict setObject:@"." forKey:@"NSDecimalSeparator"];
	
	return [NSDictionary dictionaryWithDictionary:theLocalDict];
}

/**
 * Gets a proper NSStringEncoding according to the given MySQL charset.
 */
+ (NSStringEncoding) encodingForMySQLEncoding:(const char *)mysqlEncoding
{
	// Unicode encodings:
	if (!strncmp(mysqlEncoding, "utf8", 4)) {
		return NSUTF8StringEncoding;
	}
	if (!strncmp(mysqlEncoding, "ucs2", 4)) {
		return NSUnicodeStringEncoding;
	}	
	
	// Roman alphabet encodings:
	if (!strncmp(mysqlEncoding, "ascii", 5)) {
		return NSASCIIStringEncoding;
	}
	if (!strncmp(mysqlEncoding, "latin1", 6)) {
		return NSISOLatin1StringEncoding;
	}
	if (!strncmp(mysqlEncoding, "macroman", 8)) {
		return NSMacOSRomanStringEncoding;
	}
	
	// Roman alphabet with central/east european additions:
	if (!strncmp(mysqlEncoding, "latin2", 6)) {
		return NSISOLatin2StringEncoding;
	}
	if (!strncmp(mysqlEncoding, "cp1250", 6)) {
		return NSWindowsCP1250StringEncoding;
	}
	if (!strncmp(mysqlEncoding, "win1250", 7)) {
		return NSWindowsCP1250StringEncoding;
	}
	if (!strncmp(mysqlEncoding, "cp1257", 6)) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsBalticRim);
	}
	
	// Additions for Turkish:
	if (!strncmp(mysqlEncoding, "latin5", 6)) {
		return NSWindowsCP1254StringEncoding;
	}
	
	// Greek:
	if (!strncmp(mysqlEncoding, "greek", 5)) {
		return NSWindowsCP1253StringEncoding;
	}
	
	// Cyrillic:	
	if (!strncmp(mysqlEncoding, "win1251ukr", 6)) {
		return NSWindowsCP1251StringEncoding;
	}
	if (!strncmp(mysqlEncoding, "cp1251", 6)) {
		return NSWindowsCP1251StringEncoding;
	}
	if (!strncmp(mysqlEncoding, "koi8_ru", 6)) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingKOI8_R);
	}
	if (!strncmp(mysqlEncoding, "koi8_ukr", 6)) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingKOI8_R);
	}
	 
	// Arabic:
	if (!strncmp(mysqlEncoding, "cp1256", 6)) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsArabic);
	}
	
	// Hebrew:
	if (!strncmp(mysqlEncoding, "hebrew", 6)) {
		CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinHebrew);
	}
	
	// Asian:
	if (!strncmp(mysqlEncoding, "ujis", 4)) {
		return NSJapaneseEUCStringEncoding;
	}
	if (!strncmp(mysqlEncoding, "sjis", 4)) {
		return  NSShiftJISStringEncoding;
	}
	if (!strncmp(mysqlEncoding, "big5", 4)) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5);
	}
	if (!strncmp(mysqlEncoding, "euc_kr", 6)) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_KR);
	}
	if (!strncmp(mysqlEncoding, "euckr", 5)) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_KR);
	}
	
	// Default to iso latin 1, even if it is not exact (throw an exception?)    
	NSLog(@"WARNING: unknown name for MySQL encoding '%s'!\n\t\tFalling back to iso-latin1.", mysqlEncoding);
	
	return NSISOLatin1StringEncoding;
}

/**
 * Returns the default charset of the library mysqlclient used.
 */
+ (NSStringEncoding)defaultMySQLEncoding
{
	return [MCPConnection encodingForMySQLEncoding:"utf8_general_ci"];
}

#pragma mark -
#pragma mark Class maintenance

/**
  *
  */
+ (void)setTruncateLongFieldInLogs:(BOOL)iTruncFlag
{
	sTruncateLongFieldInLogs = iTruncFlag;
}

/**
 *
 */
+ (BOOL)truncateLongField
{
	return sTruncateLongFieldInLogs;
}

/**
 * This method is to be used for getting special option for a connection, in which case the MCPConnection 
 * has to be inited with the init method, then option are selected, finally connection is done using one 
 * of the connect methods:
 *
 * MCPConnection	*theConnect = [[MCPConnection alloc] init];
 *
 * [theConnect setConnectionOption: option toValue: value];
 * [theConnect connectToHost:albert.com withLogin:@"toto" password:@"albert" port:0];
 *
 */
- (BOOL)setConnectionOption:(int)option toValue:(BOOL)value
{
	// So far do nothing except for testing if it's proper time for setting option 
	// What about if some option where setted and a connection is made again with connectTo...
	if ((mConnected)  || (! mConnection)) {
		return FALSE;
	}
	
	if (value) { //Set this option to true
		mConnectionFlags |= option;
	}
	else { //Set this option to false
		mConnectionFlags &= (! option);
	}
	
	return YES;
}

/**
 * The method used by !{initToHost:withLogin:password:usingPort:} and !{initToSocket:withLogin:password:}. Same information and use of the parameters:
 *
 * - login is the user name
 * - pass is the password corresponding to the user name
 * - host is the hostname or IP adress
 * - port is the TCP port to use to connect. If port = 0, uses the default port from mysql.h
 * - socket is the path to the socket (for the localhost)
 *
 * The socket is used if the host is set to !{@"localhost"}, to an empty or a !{nil} string
 * For the moment the implementation might not be safe if you have a nil pointer to one of the NSString* variables (underestand: I don't know what the result will be).
 */
- (BOOL)connectWithLogin:(NSString *)login password:(NSString *)pass host:(NSString *)host port:(int)port socket:(NSString *)socket
{
	const char *theLogin  = [self cStringFromString:login];
	const char *theHost	  = [self cStringFromString:host];
	const char *thePass	  = [self cStringFromString:pass];
	const char *theSocket = [self cStringFromString:socket];
	void	   *theRet;
	
	if (mConnected) {
		// Disconnect if it was already connected
		mysql_close(mConnection);
		mConnection = NULL;
		mConnected = NO;
		[self init];
	}
	
	if ([host isEqualToString:@""]) {
		theHost = NULL;
	}
	
	if (theSocket == NULL) {
		theSocket = kMCPConnectionDefaultSocket;
	}
	
	theRet = mysql_real_connect(mConnection, theHost, theLogin, thePass, NULL, port, theSocket, mConnectionFlags);
	if (theRet != mConnection) {
		return mConnected = NO;
	}
	
	mConnected = YES;
	mEncoding = [MCPConnection encodingForMySQLEncoding:mysql_character_set_name(mConnection)];
	
	// Getting the timezone used by the server.
	[self timeZone]; 
	
	return mConnected;
}

/**
 * Selects a database to work with.
 *
 * The MCPConnection object needs to be properly inited and connected to a server.
 * If a connection is not yet set or the selection of the database didn't work, returns NO. Returns YES in normal cases where the database is properly selected.
 *
 * So far, if dbName is a nil pointer it will return NO (as if it cannot connect), most likely this will throw an exception in the future.
 */
- (BOOL)selectDB:(NSString *) dbName
{
	if (!mConnected) return NO;
	
	[self stopKeepAliveTimer];
	
	if (![self checkConnection]) {
		return NO;
	}
	
	if (dbName == nil) {
		// Here we should throw an exception, impossible to select a databse if the string is indeed a nil pointer
		return NO;
	}
	
	if (mConnected) {
		const char	 *theDBName = [self cStringFromString:dbName];
		[queryLock lock];
		if (0 == mysql_select_db(mConnection, theDBName)) {
			[queryLock unlock];
			[self startKeepAliveTimerResettingState:YES];
			
			return YES;
		}
		[queryLock unlock];
	}
	
	[self setLastErrorMessage:nil];
	
	lastQueryErrorId = mysql_errno(mConnection);
	
	if (connectionProxy) {
		[connectionProxy disconnect];
	}
	
	return NO;
}

#pragma mark -
#pragma mark Error information

/**
 * Returns a string with the last MySQL error message on the connection.
 */
- (NSString *)getLastErrorMessage
{
	return lastQueryErrorMessage;
}

/**
 * Sets the string for the last MySQL error message on the connection,
 * managing memory as appropriate.  Supply a nil string to store the
 * last error on the connection.
 */
- (void)setLastErrorMessage:(NSString *)theErrorMessage
{
	if (!theErrorMessage) theErrorMessage = [self stringWithCString:mysql_error(mConnection)];
	
	if (lastQueryErrorMessage) [lastQueryErrorMessage release], lastQueryErrorMessage = nil;
	lastQueryErrorMessage = [[NSString alloc] initWithString:theErrorMessage];
}

/**
 * Returns the ErrorID of the last MySQL error on the connection.
 */
- (unsigned int)getLastErrorID
{
	return lastQueryErrorId;
}

/**
 * Determines whether a supplied error number can be classed as a connection error.
 */
+ (BOOL)isErrorNumberConnectionError:(int)theErrorNumber
{
	
	switch (theErrorNumber) {
		case 2001: // CR_SOCKET_CREATE_ERROR
		case 2002: // CR_CONNECTION_ERROR
		case 2003: // CR_CONN_HOST_ERROR
		case 2004: // CR_IPSOCK_ERROR
		case 2005: // CR_UNKNOWN_HOST
		case 2006: // CR_SERVER_GONE_ERROR
		case 2007: // CR_VERSION_ERROR
		case 2009: // CR_WRONG_HOST_INFO
		case 2012: // CR_SERVER_HANDSHAKE_ERR
		case 2013: // CR_SERVER_LOST
		case 2027: // CR_MALFORMED_PACKET
		case 2032: // CR_DATA_TRUNCATED
		case 2047: // CR_CONN_UNKNOW_PROTOCOL
		case 2048: // CR_INVALID_CONN_HANDLE
		case 2050: // CR_FETCH_CANCELED
		case 2055: // CR_SERVER_LOST_EXTENDED
			return YES;
	}
	
	return NO;
}

#pragma mark -
#pragma mark Queries

/**
 * Takes a NSData object and transform it in a proper string for sending to the server in between quotes.
 */
- (NSString *)prepareBinaryData:(NSData *)theData
{
	const char			*theCDataBuffer = [theData bytes];
	unsigned long		theLength = [theData length];
	char					*theCEscBuffer = (char *)calloc(sizeof(char),(theLength*2) + 1);
	NSString				*theReturn;
//	unsigned long		theEscapedLength;

// Using the mysql_hex_string function : (NO other solution found to be able to support blobs while using UTF-8 charset).
//	theEscapedLength = mysql_hex_string(theCEscBuffer, theCDataBuffer, theLength);
	mysql_hex_string(theCEscBuffer, theCDataBuffer, theLength);
	theReturn = [NSString stringWithFormat:@"%s", theCEscBuffer];
	free (theCEscBuffer);
	return theReturn;
}

/**
 * Takes a string and escape any special character (like single quote : ') so that the string can be used directly in a query.
 */
- (NSString *)prepareString:(NSString *)theString
{
	NSData				*theCData = [theString dataUsingEncoding:mEncoding allowLossyConversion:YES];
	unsigned long		theLength = [theCData length];
	// const char			*theCStringBuffer = [self cStringFromString:theString];
	// unsigned long		theLength = [theString length];
	char					*theCEscBuffer;
	NSString				*theReturn;
	unsigned long		theEscapedLength;
	
	if (theString == nil) {
		// In the mean time, no one should call this method on a nil string, the test should be done before by the user of this method.
		return @"";
	}
	
	// theLength = strlen(theCStringBuffer);
	theCEscBuffer = (char *)calloc(sizeof(char),(theLength * 2) + 1);
	theEscapedLength = mysql_real_escape_string(mConnection, theCEscBuffer, [theCData bytes], theLength);
	theReturn = [[NSString alloc] initWithData:[NSData dataWithBytes:theCEscBuffer length:theEscapedLength] encoding:mEncoding];
	// theReturn = [self stringWithCString:theCEscBuffer];
	free(theCEscBuffer);
	
	return [theReturn autorelease];    
}

/** 
 * Use the class of the theObject to know how it should be prepared for usage with the database.
 * If theObject is a string, this method will put single quotes to both its side and escape any necessary
 * character using prepareString: method. If theObject is NSData, the prepareBinaryData: method will be
 * used instead.
 *
 * For NSNumber object, the number is just quoted, for calendar dates, the calendar date is formatted in
 * the preferred format for the database.
 */
- (NSString *)quoteObject:(id)theObject
{
	if ((! theObject) || ([theObject isNSNull])) {
		return @"NULL";
	}
	
	if ([theObject isKindOfClass:[NSData class]]) {
		return [NSString stringWithFormat:@"X'%@'", [self prepareBinaryData:(NSData *) theObject]];
	}
	
	if ([theObject isKindOfClass:[NSString class]]) {
		return [NSString stringWithFormat:@"'%@'", [self prepareString:(NSString *) theObject]];
	}
	
	if ([theObject isKindOfClass:[NSNumber class]]) {
		return [NSString stringWithFormat:@"%@", theObject];
	}
	
	if ([theObject isKindOfClass:[NSCalendarDate class]]) {
		return [NSString stringWithFormat:@"'%@'", [(NSCalendarDate *)theObject descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S"]];
	}

	return [NSString stringWithFormat:@"'%@'", [self prepareString:[theObject description]]];
}

/**
 * Takes a query string and return an MCPResult object holding the result of the query.
 * The returned MCPResult is not retained, the client is responsible for that (it's autoreleased before being returned). If no field are present in the result (like in an insert query), will return nil (#{difference from previous version implementation}). Though, if their is at least one field the result will be non nil (even if no row are selected).
 *
 * Note that if you want to use this method with binary data (in the query), you should use !{prepareBinaryData:} to include the binary data in the query string. Also if you want to include in your query a string containing any special character (\, ', " ...) then you should use !{prepareString}.
 */
- (MCPResult *)queryString:(NSString *)query
{
	return [self queryString:query usingEncoding:mEncoding streamingResult:MCP_NO_STREAMING];
}

/**
 * Takes a query string and returns an MCPStreamingResult representing the result of the query.
 * The returned MCPStreamingResult is retained and the client is responsible for releasing it.
 * If no fields are present in the result, nil will be returned.
 * Uses safe/fast mode, which may use more memory as results are downloaded.
 */
- (MCPStreamingResult *)streamingQueryString:(NSString *)query
{
	return [self queryString:query usingEncoding:mEncoding streamingResult:MCP_FAST_STREAMING];
}

/**
 * Takes a query string and returns an MCPStreamingResult representing the result of the query.
 * The returned MCPStreamingResult is retained and the client is responsible for releasing it.
 * If no fields are present in the result, nil will be returned.
 * Can be used in either fast/safe mode, where data is downloaded as fast as possible to avoid
 * blocking the server, or in full streaming mode for lowest memory usage but potentially blocking
 * the table.
 */
- (MCPStreamingResult *)streamingQueryString:(NSString *)query useLowMemoryBlockingStreaming:(BOOL)fullStream
{
	return [self queryString:query usingEncoding:mEncoding streamingResult:(fullStream?MCP_LOWMEM_STREAMING:MCP_FAST_STREAMING)];
}

/**
 * Error checks connection extensively - if this method fails due to a connection error, it will ask how to
 * proceed and loop depending on the status, not returning control until either the query has been executed
 * and the result can be returned or the connection and document have been closed.
 * If using streamingResult, the caller is responsible for releasing the result set.
 */
- (id)queryString:(NSString *) query usingEncoding:(NSStringEncoding) encoding streamingResult:(int) streamResultType
{
	MCPResult		*theResult = nil;
	double			queryStartTime, queryExecutionTime;
	const char		*theCQuery;
	unsigned long	theCQueryLength;
	int				queryResultCode;
	int				queryErrorId = 0;
	my_ulonglong	queryAffectedRows = 0;
	int				currentMaxAllowedPacket = -1;
	BOOL			isQueryRetry = NO;
	NSString		*queryErrorMessage = nil;
	
	// If no connection is present, return nil.
	if (!mConnected) {
		// Write a log entry
		if ([delegate respondsToSelector:@selector(queryGaveError:connection:)]) [delegate queryGaveError:@"No connection available!" connection:self];
		// Notify that the query has been performed
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
		// Show an error alert while resetting
		NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), @"No connection available!", 
						  nil, nil, [delegate valueForKeyPath:@"tableWindow"], self, nil, nil, nil, @"No connection available!");
		return nil;
	}
	
	(void)(*stopKeepAliveTimerPtr)(self, stopKeepAliveTimerSEL);
	
	// Inform the delegate about the query if logging is enabled and delegate responds to willQueryString:connection:
	if (delegateQueryLogging && delegateResponseToWillQueryString) {
		[delegate willQueryString:query connection:self];
	}
		
	
	// If thirty seconds have elapsed since the last query, check the connection.  This provides
	// a balance between keeping high read/write timeouts for long queries, network issues, and
	// minimising the impact of performing lots of additional checks.
	if ([self timeConnected] - lastQueryExecutedAtTime > 30
		&& ![self checkConnection]) return nil;

	// Derive the query string in the correct encoding
	NSData *d = NSStringDataUsingLossyEncoding(query, encoding, 1);
	theCQuery = [d bytes];
	// Set the length of the current query
	theCQueryLength = [d length];
	
	// Check query length against max_allowed_packet; if it is larger, the
	// query would error, so if max_allowed_packet is editable for the user
	// increase it for the current session and reconnect.
	if (maxAllowedPacketSize < theCQueryLength) {
		
		if (isMaxAllowedPacketEditable) {
			
			currentMaxAllowedPacket = maxAllowedPacketSize;
			[self setMaxAllowedPacketTo:strlen(theCQuery)+1024 resetSize:NO];
			[self reconnect];
			
		} else {
			
			NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"The query length of %d bytes is larger than max_allowed_packet size (%d).", 
																				  @"error message if max_allowed_packet < query size"),
									  theCQueryLength, maxAllowedPacketSize];
			
			// Write a log entry and update the connection error messages for those uses that check it
			if ([delegate respondsToSelector:@selector(queryGaveError:connection:)]) [delegate queryGaveError:errorMessage connection:self];
			[self setLastErrorMessage:errorMessage];
			
			// Notify that the query has been performed
			[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
			// Show an error alert while resetting
			NSBeginAlertSheet(NSLocalizedString(@"Error", @"error"), NSLocalizedString(@"OK", @"OK button"), 
							  nil, nil, [delegate valueForKeyPath:@"tableWindow"], self, nil, nil, nil, errorMessage);
			
			return nil;
		}
	}
	
	// In a loop to allow one reattempt, perform the query.
	while (1) {
		
		// If this query has failed once already, check the connection
		if (isQueryRetry) {
			if (![self checkConnection]) {

				// Notify that the query has been performed
				[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
				return nil;
			}
		}
		
		[queryLock lock];

		// Run (or re-run) the query, timing the execution time of the query - note
		// that this time will include network lag.
		queryStartTime = [self timeConnected];
		queryResultCode = mysql_real_query(mConnection, theCQuery, theCQueryLength);
		lastQueryExecutedAtTime = [self timeConnected];
		queryExecutionTime = lastQueryExecutedAtTime - queryStartTime;
		
		// On success, capture the results
		if (0 == queryResultCode) {
			
			queryAffectedRows = mysql_affected_rows(mConnection);

			if (mysql_field_count(mConnection) != 0) {
				
				// For normal result sets, fetch the results and unlock the connection
				if (streamResultType == MCP_NO_STREAMING) {
					theResult = [[MCPResult alloc] initWithMySQLPtr:mConnection encoding:mEncoding timeZone:mTimeZone];
					[queryLock unlock];
				
				// For streaming result sets, fetch the result pointer and leave the connection locked
				} else if (streamResultType == MCP_FAST_STREAMING) {
					theResult = [[MCPStreamingResult alloc] initWithMySQLPtr:mConnection encoding:mEncoding timeZone:mTimeZone connection:self withFullStreaming:NO];
				} else if (streamResultType == MCP_LOWMEM_STREAMING) {
					theResult = [[MCPStreamingResult alloc] initWithMySQLPtr:mConnection encoding:mEncoding timeZone:mTimeZone connection:self withFullStreaming:YES];
				}
				
				// Ensure no problem occurred during the result fetch
				if (mysql_errno(mConnection) != 0) {
					queryErrorMessage = [[NSString alloc] initWithString:[self stringWithCString:mysql_error(mConnection)]];
					queryErrorId = mysql_errno(mConnection);
					break;
				}
			} else {
				[queryLock unlock];
			}
			
			queryErrorMessage = [[NSString alloc] initWithString:@""];
			queryErrorId = 0;
			if (streamResultType == MCP_NO_STREAMING && queryAffectedRows == -1) {
				queryAffectedRows = mysql_affected_rows(mConnection);
			}
			
		// On failure, set the error messages and IDs
		} else {
			[queryLock unlock];
			
			queryErrorMessage = [[NSString alloc] initWithString:[self stringWithCString:mysql_error(mConnection)]];
			queryErrorId = mysql_errno(mConnection);

			// If the error was a connection error, retry once
			if (!isQueryRetry && retryAllowed && [MCPConnection isErrorNumberConnectionError:queryErrorId]) {
				isQueryRetry = YES;
				continue;
			}
		}
		
		break;
	}
	
	if (streamResultType == MCP_NO_STREAMING) {
		
		// If the mysql thread id has changed as a result of a connection error,
		// ensure connection details are still correct
		if (connectionThreadId != mConnection->thread_id) [self restoreConnectionDetails];
		
		// If max_allowed_packet was changed, reset it to default
		if(currentMaxAllowedPacket > -1)
			[self setMaxAllowedPacketTo:currentMaxAllowedPacket resetSize:YES];
	}
	
	// Update error strings and IDs
	lastQueryErrorId = queryErrorId;
	[self setLastErrorMessage:queryErrorMessage?queryErrorMessage:@""];
	if (queryErrorMessage) [queryErrorMessage release]; 
	lastQueryAffectedRows = queryAffectedRows;
	lastQueryExecutionTime = queryExecutionTime;
	
	// If an error occurred, inform the delegate
	if (queryResultCode & delegateResponseToWillQueryString)
		[delegate queryGaveError:lastQueryErrorMessage connection:self];
	
	(void)(*startKeepAliveTimerResettingStatePtr)(self, startKeepAliveTimerResettingStateSEL, YES);
	
	if (!theResult) return nil;
	if (streamResultType != MCP_NO_STREAMING) return theResult;
	return [theResult autorelease];
}

/**
 * Return the time taken to execute the last query.  This should be close to the time it took
 * the server to run the query, but will include network lag and some client library overhead.
 */
- (double)lastQueryExecutionTime
{
	return lastQueryExecutionTime;
}

/**
 * Returns the number of affected rows by the last query.
 */
- (my_ulonglong)affectedRows
{
	if (mConnected) {
		return mysql_affected_rows(mConnection);
	}
	
	return 0;
}

/**
 * If the last query was an insert in a table having a autoindex column, returns the ID 
 * (autoindexed field) of the last row inserted.
 */
- (my_ulonglong)insertId
{
	if (mConnected) {
		return mysql_insert_id(mConnection);
	}
	
	return 0;
}

#pragma mark -
#pragma mark Connection locking

/**
 * Unlock the connection
 */
- (void)unlockConnection
{
	[queryLock performSelectorOnMainThread:@selector(unlock) withObject:nil waitUntilDone:YES];
}

#pragma mark -
#pragma mark Database structure

/**
 * Just a fast wrapper for the more complex !{listDBsWithPattern:} method.
 */
- (MCPResult *)listDBs
{
	return [self listDBsLike:nil];
}

/**
 * Returns a list of database which name correspond to the SQL regular expression in 'pattern'.
 * The comparison is done with wild card extension : % and _.
 * The result should correspond to the queryString:@"SHOW databases [LIKE wild]"; but implemented with mysql_list_dbs.
 * If an empty string or nil is passed as pattern, all databases will be shown.
 */
- (MCPResult *)listDBsLike:(NSString *)dbsName
{
	if (!mConnected) return NO;
	
	MCPResult *theResult = [MCPResult alloc];
	MYSQL_RES *theResPtr;
	
	[self stopKeepAliveTimer];
	
	if (![self checkConnection]) return [[[MCPResult alloc] init] autorelease];
	
	[self startKeepAliveTimerResettingState:YES];
	
	[queryLock lock];
	if ((dbsName == nil) || ([dbsName isEqualToString:@""])) {
		if (theResPtr = mysql_list_dbs(mConnection, NULL)) {
			[theResult initWithResPtr: theResPtr encoding: mEncoding timeZone:mTimeZone];
		}
		else {
			[theResult init];
		}
	}
	else {
		const char *theCDBsName = (const char *)[self cStringFromString:dbsName];
		
		if (theResPtr = mysql_list_dbs(mConnection, theCDBsName)) {
			[theResult initWithResPtr: theResPtr encoding: mEncoding timeZone:mTimeZone];
		}
		else {
			[theResult init];
		}        
	}
	[queryLock unlock];
	
	if (theResult) {
		[theResult autorelease];
	}
	
	return theResult;    
}

/**
 * Make sure a DB is selected (with !{selectDB:} method) first.
 */
- (MCPResult *)listTables
{
	return [self listTablesLike:nil];
}

/**
 * From within a database, give back the list of table which name correspond to tablesName 
 * (with wild card %, _ extension). Correspond to queryString:@"SHOW tables [LIKE wild]"; uses mysql_list_tables function.
 *
 * If an empty string or nil is passed as tablesName, all tables will be shown.
 *
 * WARNING: #{produce an error if no databases are selected} (with !{selectDB:} for example).
 */
- (MCPResult *)listTablesLike:(NSString *)tablesName
{
	if (!mConnected) return NO;
	
	MCPResult *theResult = [MCPResult alloc];
	MYSQL_RES *theResPtr;
	
	[self stopKeepAliveTimer];
	
	if (![self checkConnection]) return [[[MCPResult alloc] init] autorelease];
	
	[self startKeepAliveTimerResettingState:YES];

	[queryLock lock];
	if ((tablesName == nil) || ([tablesName isEqualToString:@""])) {
		if (theResPtr = mysql_list_tables(mConnection, NULL)) {
			[theResult initWithResPtr: theResPtr encoding: mEncoding timeZone:mTimeZone];
		}
		else {
			[theResult init];
		}
	}
	else {
		const char	*theCTablesName = (const char *)[self cStringFromString:tablesName];
		if (theResPtr = mysql_list_tables(mConnection, theCTablesName)) {
			[theResult initWithResPtr: theResPtr encoding: mEncoding timeZone:mTimeZone];
		}
		else {
			[theResult init];
		}
	}
	[queryLock unlock];

	if (theResult) {
		[theResult autorelease];
	}
	return theResult;
}

/**
 * List tables in DB specified by dbName and corresponding to pattern.
 * This method indeed issues a !{SHOW TABLES FROM dbName LIKE ...} query to the server.
 * This is done this way to make sure the selected DB is not changed by this method.
 */
- (MCPResult *)listTablesFromDB:(NSString *)dbName like:(NSString *)tablesName
{
	MCPResult *theResult;
	
	if ((tablesName == nil) || ([tablesName isEqualToString:@""])) {
		NSString	*theQuery = [NSString stringWithFormat:@"SHOW TABLES FROM %@", dbName];
		theResult = [self queryString:theQuery];
	}
	else {
		NSString	*theQuery = [NSString stringWithFormat:@"SHOW TABLES FROM %@ LIKE '%@'", dbName, tablesName];
		theResult = [self queryString:theQuery];
	}
	
	return theResult;
}

/**
 * Just a fast wrapper for the more complex list !{listFieldsWithPattern:forTable:} method.
 */
- (MCPResult *)listFieldsFromTable:(NSString *)tableName
{
	return [self listFieldsFromTable:tableName like:nil];
}

/**
 * Show all the fields of the table tableName which name correspond to pattern (with wild card expansion : %,_).
 * Indeed, and as recommanded from mysql reference, this method is NOT using mysql_list_fields but the !{queryString:} method.
 * If an empty string or nil is passed as fieldsName, all fields (of tableName) will be returned.
 */
- (MCPResult *)listFieldsFromTable:(NSString *)tableName like:(NSString *)fieldsName
{
	MCPResult *theResult;
	
	if ((fieldsName == nil) || ([fieldsName isEqualToString:@""])) {
		NSString	*theQuery = [NSString stringWithFormat:@"SHOW COLUMNS FROM %@", tableName];
		theResult = [self queryString:theQuery];
	}
	else {
		NSString	*theQuery = [NSString stringWithFormat:@"SHOW COLUMNS FROM %@ LIKE '%@'", tableName, fieldsName];
		theResult = [self queryString:theQuery];
	}
	
	return theResult;
}

#pragma mark -
#pragma mark Server information

/**
 * Returns a string giving the client library version.
 */
- (NSString *)clientInfo
{
	return [self stringWithCString:mysql_get_client_info()];
}

/**
 * Returns a string giving information on the host of the DB server.
 */
- (NSString *)hostInfo
{
	return [self stringWithCString:mysql_get_host_info(mConnection)];
}

/**
 * Returns a string giving the server version.
 */
- (NSString *)serverInfo
{
	if (mConnected) {
		return [self stringWithCString: mysql_get_server_info(mConnection)];
	}
	
	return @"";
}

/**
 * Returns the number of the protocole used to transfer info from server to client
 */
- (NSNumber *)protoInfo
{
	return [MCPNumber numberWithUnsignedInt:mysql_get_proto_info(mConnection)];
}

/**
 * Lists active process
 */
- (MCPResult *)listProcesses
{
	MCPResult *theResult = [MCPResult alloc];
	MYSQL_RES *theResPtr;
	
	[queryLock lock];
	if (theResPtr = mysql_list_processes(mConnection)) {
		[theResult initWithResPtr:theResPtr encoding:mEncoding timeZone:mTimeZone];
	} 
	else {
		[theResult init];
	}
	[queryLock unlock];
	
	if (theResult) {
		[theResult autorelease];
	}
	
	return theResult;
}

/**
 * Kills the process with the given pid.
 * The users needs the !{Process_priv} privilege.
 */
- (BOOL)killProcess:(unsigned long)pid
{	
	int theErrorCode = mysql_kill(mConnection, pid);

	return (theErrorCode) ? NO : YES;
}

/*
 * Check some common locations for the presence of a MySQL socket file, returning
 * it if successful.
 */
- (NSString *)findSocketPath
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	NSArray *possibleSocketLocations = [NSArray arrayWithObjects:
										@"/tmp/mysql.sock",							// Default
										@"/var/run/mysqld/mysqld.sock",				// As used on Debian/Gentoo
										@"/var/tmp/mysql.sock",						// As used on FreeBSD
										@"/var/lib/mysql/mysql.sock",				// As used by Fedora
										@"/opt/local/lib/mysql/mysql.sock",			// Alternate fedora
										@"/opt/local/var/run/mysqld/mysqld.sock",	// Darwinports MySQL
										@"/opt/local/var/run/mysql4/mysqld.sock",	// Darwinports MySQL 4
										@"/opt/local/var/run/mysql5/mysqld.sock",	// Darwinports MySQL 5
										@"/Applications/MAMP/tmp/mysql/mysql.sock",	// MAMP default location
										nil];
	
	for (int i = 0; i < [possibleSocketLocations count]; i++) 
	{
		if ([fileManager fileExistsAtPath:[possibleSocketLocations objectAtIndex:i]])
			return [possibleSocketLocations objectAtIndex:i];
	}
	
	return nil;
}

#pragma mark -
#pragma mark Encoding

/**
 * Sets the encoding used by the server for data transfer.
 * Used to make sure the output of the query result is ok even for non-ascii characters
 * The character set (encoding) used by the db is passed to the MCPConnection object upon connection,
 * so most likely the encoding (from -encoding) method is already the proper one.
 * That is to say : It's unlikely you will need to call this method directly, and #{if ever you use it, do it at your own risks}.
 */
- (void)setEncoding:(NSStringEncoding)theEncoding
{
	mEncoding = theEncoding;
}

/**
 * Gets the encoding for the connection
 */
- (NSStringEncoding)encoding
{
	return mEncoding;
}

#pragma mark -
#pragma mark Time Zone

/**
 * Setting the time zone to be used with the server. 
 */
- (void)setTimeZone:(NSTimeZone *)iTimeZone
{
	if (iTimeZone != mTimeZone) {
		[mTimeZone release];
		mTimeZone = [iTimeZone retain];
	}
	
	if ([self checkConnection]) {
		if (mTimeZone) {
			[self queryString:[NSString stringWithFormat:@"SET time_zone = '%@'", [mTimeZone name]]];
		}
		else {
			[self queryString:@"SET time_zone = 'SYSTEM'"];
		}
	}
}

/**
 * Getting the currently used time zone (in communication with the DB server).
 */
- (NSTimeZone *)timeZone
{
	if ([self checkConnection]) {
		MCPResult	*theSessionTZ = [self queryString:@"SHOW VARIABLES LIKE '%time_zone'"];
		NSArray		*theRow;
		id			theTZName;
		NSTimeZone	*theTZ;
		
		[theSessionTZ dataSeek:1ULL];
		theRow = [theSessionTZ fetchRowAsArray];
		theTZName = [theRow objectAtIndex:1];
		
		if ( [theTZName isKindOfClass:[NSData class]] ) {
			// MySQL 4.1.14 returns the mysql variables as NSData
			theTZName = [self stringWithText:theTZName];
		}
		
		if ([theTZName isEqualToString:@"SYSTEM"]) {
			[theSessionTZ dataSeek:0ULL];
			theRow = [theSessionTZ fetchRowAsArray];
			theTZName = [theRow objectAtIndex:1];
			
			if ( [theTZName isKindOfClass:[NSData class]] ) {
				// MySQL 4.1.14 returns the mysql variables as NSData
				theTZName = [self stringWithText:theTZName];
			}
		}
		
		if (theTZName) { // Old versions of the server does not support there own time zone ?
			theTZ = [NSTimeZone timeZoneWithName:theTZName];
		} else {
			// By default set the time zone to the local one..
			// Try to get the name using the previously available variable:
			theSessionTZ = [self queryString:@"SHOW VARIABLES LIKE 'timezone'"];
			[theSessionTZ dataSeek:0ULL];
			theRow = [theSessionTZ fetchRowAsArray];
			theTZName = [theRow objectAtIndex:1];
			if (theTZName) {
				// Finally we found one ...
				theTZ = [NSTimeZone timeZoneWithName:theTZName];
			} else {
				theTZ = [NSTimeZone defaultTimeZone];
				//theTZ = [NSTimeZone systemTimeZone];
				NSLog(@"The time zone is not defined on the server, set it to the default one : %@", theTZ);
			}
		}
		
		if (theTZ != mTimeZone) {
			[mTimeZone release];
			mTimeZone = [theTZ retain];
		}
	}
	
	return mTimeZone;
}

#pragma mark -
#pragma mark Packet size

/**
 * Retrieve the max_allowed_packet size from the server; returns
 * false if the query fails.
 */
- (BOOL)fetchMaxAllowedPacket
{
	char *queryString;

	if ([self serverMajorVersion] == 3) queryString = "SHOW VARIABLES LIKE 'max_allowed_packet'";
	else queryString = "SELECT @@global.max_allowed_packet";
	
	[queryLock lock];
	if (0 == mysql_query(mConnection, queryString)) {
		if (mysql_field_count(mConnection) != 0) {
			MCPResult *r = [[MCPResult alloc] initWithMySQLPtr:mConnection encoding:mEncoding timeZone:mTimeZone];
			NSArray *a = [r fetchRowAsArray];
			[r autorelease];
			if([a count]) {
				[queryLock unlock];
				maxAllowedPacketSize = [[a objectAtIndex:([self serverMajorVersion] == 3)?1:0] intValue];
				return true;
			}
		}
	}
	[queryLock unlock];
	
	return false;
}

/**
 * Retrieves max_allowed_packet size set as global variable.
 * It returns -1 if it fails.
 */
- (int)getMaxAllowedPacket
{
	MCPResult *r;
	r = [self queryString:@"SELECT @@global.max_allowed_packet" usingEncoding:mEncoding streamingResult:NO];
	if (![[self getLastErrorMessage] isEqualToString:@""]) {
		if ([self isConnected])
			NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"An error occured while retrieving max_allowed_packet size:\n\n%@", [self getLastErrorMessage]], @"OK", nil, nil);
		return -1;
	}
	NSArray *a = [r fetchRowAsArray];
	if([a count])
		return [[a objectAtIndex:0] intValue];
	
	return -1;
}

/*
 * It sets max_allowed_packet size to newSize and it returns
 * max_allowed_packet after setting it to newSize for cross-checking 
 * if the maximal size was reached (e.g. set it to 4GB it'll return 1GB up to now).
 * If something failed it return -1;
 */
- (int)setMaxAllowedPacketTo:(int)newSize resetSize:(BOOL)reset
{
	if(![self isMaxAllowedPacketEditable] || newSize < 1024) return maxAllowedPacketSize;
	
	[queryLock lock];
	mysql_query(mConnection, [[NSString stringWithFormat:@"SET GLOBAL max_allowed_packet = %d", newSize] UTF8String]);
	[queryLock unlock];

	// Inform the user via a log entry about that change according to reset value
	if(delegate && [delegate respondsToSelector:@selector(queryGaveError:connection:)])
		if(reset)
			[delegate queryGaveError:[NSString stringWithFormat:@"max_allowed_packet was reset to %d for new session", newSize] connection:self];
		else
			[delegate queryGaveError:[NSString stringWithFormat:@"Query too large; max_allowed_packet temporarily set to %d for the current session to allow query to succeed", newSize] connection:self];
	
	return maxAllowedPacketSize;
}

/**
 * It returns whether max_allowed_packet is setable for the user.
 */
- (BOOL)isMaxAllowedPacketEditable
{
	BOOL isEditable;

	[queryLock lock];
	isEditable = !mysql_query(mConnection, "SET GLOBAL max_allowed_packet = @@global.max_allowed_packet");
	[queryLock unlock];

	return isEditable;
}

#pragma mark -
#pragma mark Data conversion

/**
 * For internal use only. Transforms a NSString to a C type string (ending with \0) using the character set from the MCPConnection.
 * Lossy conversions are enabled.
 */
- (const char *)cStringFromString:(NSString *)theString
{
	NSMutableData *theData;
	
	if (! theString) {
		return (const char *)NULL;
	}
	
	theData = [NSMutableData dataWithData:[theString dataUsingEncoding:mEncoding allowLossyConversion:YES]];
	[theData increaseLengthBy:1];
	
	return (const char *)[theData bytes];
}

/**
 * Modified version of the original to support a supplied encoding.
 * For internal use only. Transforms a NSString to a C type string (ending with \0).
 * Lossy conversions are enabled.
 */
- (const char *)cStringFromString:(NSString *)theString usingEncoding:(NSStringEncoding)encoding
{
	NSMutableData *theData;
	
	if (! theString) {
		return (const char *)NULL;
	}
	
	theData = [NSMutableData dataWithData:[theString dataUsingEncoding:encoding allowLossyConversion:YES]];
	[theData increaseLengthBy:1];
	
	return (const char *)[theData bytes];
}

/**
 * Returns a NSString from a C style string encoded with the character set of theMCPConnection.
 */
- (NSString *)stringWithCString:(const char *)theCString
{
	NSData	 *theData;
	NSString *theString;
	
	if (theCString == NULL) {
		return @"";
	}
	
	theData = [NSData dataWithBytes:theCString length:(strlen(theCString))];
	theString = [[NSString alloc] initWithData:theData encoding:mEncoding];
	
	if (theString) {
		[theString autorelease];
	}
	
	return theString;
}

/**
 * Use the string encoding to convert the returned NSData to a string (for a Text field).
 */
- (NSString *)stringWithText:(NSData *)theTextData
{
	NSString *theString;
	
	if (theTextData == nil) {
		return nil;
	}
	
	theString = [[NSString alloc] initWithData:theTextData encoding:mEncoding];
	
	if (theString) {
		[theString autorelease];
	}
	
	return theString;
}

#pragma mark -

/**
 * Object deallocation.
 */
- (void) dealloc
{
	delegate = nil;

	if (lastQueryErrorMessage) [lastQueryErrorMessage release];
	if (connectionHost) [connectionHost release];
	if (connectionLogin) [connectionLogin release];
	if (connectionSocket) [connectionSocket release];
	if (connectionPassword) [connectionPassword release];
	if (lastKeepAliveSuccess) [lastKeepAliveSuccess release];
	[queryLock release];
	
	[super dealloc];
}

@end

@implementation MCPConnection (PrivateAPI)

/**
 * Get the server's version string
 */
- (void)_getServerVersionString
{
	if (mConnected) {
		MCPResult *theResult = [self queryString:@"SHOW VARIABLES LIKE 'version'"];
		
		if ([theResult numOfRows]) {
			[theResult dataSeek:0];
			serverVersionString = [[NSString stringWithString:[[theResult fetchRowAsArray] objectAtIndex:1]] retain];
		}
	}
}

@end
