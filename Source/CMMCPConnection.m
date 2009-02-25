//
//  CMMCPConnection.m
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

#import "CMMCPConnection.h"
#include <unistd.h>
#include <setjmp.h>

static jmp_buf pingTimeoutJumpLocation;
static void forcePingTimeout(int signalNumber);

@implementation CMMCPConnection


/*
 * Override the normal init methods, extending them to also init additional details.
 */
- (id) init
{
	[self initSPExtensions];
	self = [super init];
	return self;
}
- (id) initToHost:(NSString *) host withLogin:(NSString *) login password:(NSString *) pass usingPort:(int) port
{
	[self initSPExtensions];
	self = [super initToHost:host withLogin:login password:pass usingPort:port];
	return self;
}
- (id) initToSocket:(NSString *) socket withLogin:(NSString *) login password:(NSString *) pass
{
	[self initSPExtensions];
	self = [super initToSocket:socket withLogin:login password:pass];
	return self;
}


/*
 * Instantiate extra variables and load the connection error dialog for potential use.
 */
- (void) initSPExtensions
{
	parentWindow = nil;
	connectionLogin = nil;
	connectionPassword = nil;
	connectionHost = nil;
	connectionPort = 0;
	connectionSocket = nil;
	keepAliveTimer = nil;
	lastKeepAliveSuccess = nil;
	[NSBundle loadNibNamed:@"ConnectionErrorDialog" owner:self];
}


/*
 * Override the normal connection method, extending it to also store details of the
 * current connection to allow reconnection as necessary.  This also sets the connection timeout
 * - used for pings, not for long-running commands.
 */
- (BOOL) connectWithLogin:(NSString *) login password:(NSString *) pass host:(NSString *) host port:(int) port socket:(NSString *) socket
{
	if (connectionLogin) [connectionLogin release];
	if (login) connectionLogin = [[NSString alloc] initWithString:login];
	if (connectionPassword) [connectionPassword release];
	if (pass) connectionPassword = [[NSString alloc] initWithString:pass];
	if (connectionHost) [connectionHost release];
	if (host) connectionHost = [[NSString alloc] initWithString:host];
	connectionPort = port;
	if (connectionSocket) [connectionSocket release];
	if (socket) connectionSocket = [[NSString alloc] initWithString:socket];

	if (mConnection != NULL) {
		unsigned int connectionTimeout = SP_CONNECTION_TIMEOUT;
		mysql_options(mConnection, MYSQL_OPT_CONNECT_TIMEOUT, (const void *)&connectionTimeout);
	}

	[self startKeepAliveTimerResettingState:YES];
	return [super connectWithLogin:login password:pass host:host port:port socket:socket];
}


/*
 * Override the stored disconnection method to ensure that disconnecting clears stored details.
 */
- (void) disconnect
{
	[super disconnect];

	if (connectionLogin) [connectionLogin release];
	connectionLogin = nil;
	if (connectionPassword) [connectionPassword release];
	connectionPassword = nil;
	if (connectionHost) [connectionHost release];
	connectionHost = nil;
	connectionPort = 0;
	if (connectionSocket) [connectionSocket release];
	connectionSocket = nil;
	
	[self stopKeepAliveTimer];
}


/*
 * Reconnect to the currently "active" - but possibly disconnected - connection, using the
 * stored details.
 * Error checks extensively - if this method fails, it will ask how to proceed and loop depending
 * on the status, not returning control until either a connection has been established or
 * the connection and document have been closed.
 */
- (BOOL) reconnect
{
	NSString *currentEncoding = nil;
	NSString *currentDatabase = nil;

	// Store the current database and encoding so they can be re-set if reconnection was successful
	if (delegate && [delegate valueForKey:@"selectedDatabase"]) {
		currentDatabase = [NSString stringWithString:[delegate valueForKey:@"selectedDatabase"]];
	}
	if (delegate && [delegate valueForKey:@"_encoding"]) {
		currentEncoding = [NSString stringWithString:[delegate valueForKey:@"_encoding"]];
	}

	// Close the connection if it exists.
	if (mConnected) {
		mysql_close(mConnection);
		mConnection = NULL;
	}
	mConnected = NO;

	// Attempt to reinitialise the connection - if this fails, it will still be set to NULL.
	if (mConnection == NULL) {
		mConnection = mysql_init(NULL);
	}

	if (mConnection != NULL) {

		// Set a connection timeout for the new connection
		unsigned int connectionTimeout = SP_CONNECTION_TIMEOUT;
		mysql_options(mConnection, MYSQL_OPT_CONNECT_TIMEOUT, (const void *)&connectionTimeout);

		// Attempt to reestablish the connection - using own method so everything gets set up as standard.
		// Will store the supplied details again, which isn't a problem.
		[self connectWithLogin:connectionLogin password:connectionPassword host:connectionHost port:connectionPort socket:connectionSocket];
	}

	// If the connection was successfully established, reselect the old database and encoding if appropriate.
	if (mConnected) {
		if (currentDatabase) {
			[self selectDB:currentDatabase];
		}
		if (currentEncoding) {
			[self queryString:[NSString stringWithFormat:@"SET NAMES '%@'", currentEncoding]];
			[self setEncoding:[CMMCPConnection encodingForMySQLEncoding:[currentEncoding UTF8String]]];
		}
	} else if (parentWindow) {

		// If the connection was not successfully established, ask how to proceed.
		[NSApp beginSheet:connectionErrorDialog modalForWindow:parentWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
		int connectionErrorCode = [NSApp runModalForWindow:connectionErrorDialog];
		[NSApp endSheet:connectionErrorDialog];
		[connectionErrorDialog orderOut:nil];

		switch (connectionErrorCode) {

				// Should disconnect
				case 2:
					[parentWindow close];
					return NO;

				// Should retry
				default:
					return [self reconnect];
		}
	}

	return mConnected;
}


/*
 * Set the parent window of the connection for use with dialogs.
 */
- (void)setParentWindow:(NSWindow *)theWindow {
	parentWindow = theWindow;
}


/*
 * Ends and existing modal session
 */
- (IBAction) closeSheet:(id)sender
{
	[NSApp stopModalWithCode:[sender tag]];
}

/*
Gets a proper NSStringEncoding according to the given MySQL charset.

MySQL 4.0 offers this charsets:
big5 cp1251 cp1257 croat czech danish dec8 dos estonia euc_kr gb2312 gbk german1 greek hebrew hp8 hungarian koi8_ru koi8_ukr latin1 latin1_de latin2 latin5 sjis swe7 tis620 ujis usa7 win1250 win1251ukr

WARNING : incomplete implementation. Please, send your fixes.

+ (NSStringEncoding) encodingForMySQLEncoding:(const char *) mysqlEncoding
{
	// unicode
	if (!strncmp(mysqlEncoding, "utf8", 4)) {
		return NSUTF8StringEncoding;
	}
	if (!strncmp(mysqlEncoding, "ucs2", 4)) {
		return NSUnicodeStringEncoding;
	}
	// west european
	if (!strncmp(mysqlEncoding, "ascii", 5)) {
		return NSASCIIStringEncoding;
	}
	if (!strncmp(mysqlEncoding, "latin1", 6)) {
		return NSISOLatin1StringEncoding;
	}
	if (!strncmp(mysqlEncoding, "macroman", 8)) {
		return NSMacOSRomanStringEncoding;
	}
	// central european
	if (!strncmp(mysqlEncoding, "cp1250", 6)) {
		return NSWindowsCP1250StringEncoding;
	}
	if (!strncmp(mysqlEncoding, "latin2", 6)) {
		return NSISOLatin2StringEncoding;
	}
	// south european and middle east
	if (!strncmp(mysqlEncoding, "cp1256", 6)) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsArabic);
	}
	if (!strncmp(mysqlEncoding, "greek", 5)) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinGreek);
	}
	if (!strncmp(mysqlEncoding, "hebrew", 6)) {
		CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatinHebrew);
	}
	if (!strncmp(mysqlEncoding, "latin5", 6)) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatin5);
	}
	// baltic
	if (!strncmp(mysqlEncoding, "cp1257", 6)) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsBalticRim);
	}
	// cyrillic
	if (!strncmp(mysqlEncoding, "cp1251", 6)) {
		return NSWindowsCP1251StringEncoding;
	}
	// asian
	if (!strncmp(mysqlEncoding, "big5", 4)) {
		return CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingBig5);
	}
	if (!strncmp(mysqlEncoding, "ujis", 4)) {
		return NSJapaneseEUCStringEncoding;
	}
	if (!strncmp(mysqlEncoding, "sjis", 4)) {
		return  NSShiftJISStringEncoding;
	}

	// default to iso latin 1, even if it is not exact (throw an exception?)
	NSLog(@"warning: unknown encoding %s! falling back to latin1.", mysqlEncoding);
	return NSISOLatin1StringEncoding;
}
*/


/*
 * Modified version of queryString to be used in Sequel Pro.
 * Error checks extensively - if this method fails, it will ask how to proceed and loop depending
 * on the status, not returning control until either the query has been executed and the result can
 * be returned or the connection and document have been closed.
 */
- (CMMCPResult *)queryString:(NSString *) query
{
	CMMCPResult	*theResult;
	const char	*theCQuery = [self cStringFromString:query];
	int			theQueryCode;

	// If no connection is present, return nil.
	if (!mConnected) return nil;

	[self stopKeepAliveTimer];

	// Check the connection.  This triggers reconnects as necessary, and should only return false if a disconnection
	// has been requested - in which case return nil
	if (![self checkConnection]) return nil;

	// Inform the delegate about the query
	if (delegate && [delegate respondsToSelector:@selector(willQueryString:)]) {
		[delegate willQueryString:query];
	}

	if (0 == (theQueryCode = mysql_query(mConnection, theCQuery))) {
		if (mysql_field_count(mConnection) != 0) {

			// Use CMMCPResult instad of MCPResult
			theResult = [[CMMCPResult alloc] initWithMySQLPtr:mConnection encoding:mEncoding timeZone:mTimeZone];
		} else {
			return nil;
		}
	} else {

		// Inform the delegate about errors
		if (delegate && [delegate respondsToSelector:@selector(queryGaveError:)]) {
			[delegate queryGaveError:[self getLastErrorMessage]];
		}

		return nil;
	}

	[self startKeepAliveTimerResettingState:YES];

	return [theResult autorelease];
}


/*
 * Checks whether the connection to the server is still active.  If not, prompts for what approach to take,
 * offering to retry, reconnect or disconnect the connection.
 */
- (BOOL)checkConnection
{
	if (!mConnected) return NO;

	BOOL connectionVerified = FALSE;

	// Check whether the connection is still operational via a wrapped version of MySQL ping.
	connectionVerified = [self pingConnection];

	// If the connection doesn't appear to be responding, show a dialog asking how to proceed
	if (!connectionVerified) {
		[NSApp beginSheet:connectionErrorDialog modalForWindow:parentWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
		int responseCode = [NSApp runModalForWindow:connectionErrorDialog];
		[NSApp endSheet:connectionErrorDialog];
		[connectionErrorDialog orderOut:nil];

		switch (responseCode) {

			// "Reconnect" has been selected.  Request a reconnect, and retry.
			case 1:
				[self reconnect];
				return [self checkConnection];

			// "Disconnect" has been selected.  Close the parent window, which will handle disconnections, and return false.
			case 2:
				[parentWindow close];
				return FALSE;

			// "Retry" has been selected - return a recursive call.
			default:
				return [self checkConnection];
		}
	}

	return connectionVerified;
}

- (void)setDelegate:(id)object
{
	delegate = object;
}

/* Getting the currently used time zone (in communication with the DB server). */
/* fixes mysql 4.1.14 problem, can be deleted as soon as fixed in the framework */
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


/*
 * The current versions of MCPKit (and up to and including 3.0.1) use MySQL 4.1.12; this has an issue with
 * mysql_ping where a connection which is terminated will cause mysql_ping never to respond, even when
 * connection timeouts are set.  Full details of this issue are available at http://bugs.mysql.com/bug.php?id=9678 ;
 * this bug was fixed in 4.1.22 and later versions.
 * This issue can be replicated by connecting to a remote host, and then configuring a firewall on that host
 * to drop all packets on the connected port - mysql_ping and so Sequel Pro will hang.
 * Until the client libraries are updated, this provides a drop-in wrapper for mysql_ping, which calls mysql_ping
 * while running a SIGALRM to enforce the specified connection time.  This is low-level but effective.
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
	alarm(SP_CONNECTION_TIMEOUT+1);

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

	// Reset and clear the SIGALRM used to check connection timeouts.
	alarm(0);
	timeoutAction.sa_handler = SIG_IGN;
	sigemptyset(&timeoutAction.sa_mask);
	timeoutAction.sa_flags = 0;
	sigaction(SIGALRM, &timeoutAction, NULL);
	
	[startDate release];
	
	return pingSuccess;
}

/*
 * This function is paired with pingConnection, and provides a method of enforcing the connection
 * timeout when mysql_ping does not respect the specified limits.
 */
static void forcePingTimeout(int signalNumber)
{
	longjmp(pingTimeoutJumpLocation, 1);
}

/*
 * Restarts a keepalive to fire in the future.
 */
- (void) startKeepAliveTimerResettingState:(BOOL)resetState
{
	if (keepAliveTimer) [self stopKeepAliveTimer];
	if (!mConnected) return;

	if (resetState && lastKeepAliveSuccess) {
		[lastKeepAliveSuccess release];
		lastKeepAliveSuccess = nil;
	}
	
	keepAliveTimer = [NSTimer
						scheduledTimerWithTimeInterval:[[[NSUserDefaults standardUserDefaults] objectForKey:@"keepAliveInterval"] doubleValue]
						target:self
						selector:@selector(keepAlive:)
						userInfo:nil
						repeats:NO];
	[keepAliveTimer retain];
}

/*
 * Stops a keepalive if one is set for the future.
 */
- (void) stopKeepAliveTimer
{
	if (!keepAliveTimer) return;
	[keepAliveTimer invalidate];
	[keepAliveTimer release];
	keepAliveTimer = nil;
}

/*
 * Keeps a connection alive by running a ping.
 */
- (void) keepAlive:(NSTimer *)theTimer
{
	if (!mConnected) return;

	// If there a successful keepalive record exists, and it was more than 5*keepaliveinterval ago,
	// abort.  This prevents endless spawning of threads in a state where the connection has been
	// cut but mysql doesn't pick up on the fact - see comment for pingConnection above.  The same
	// forced-timeout approach cannot be used here on a background thread.
	// When the connection is disconnected in code, these 5 "hanging" threads are automatically cleaned.
	if (lastKeepAliveSuccess && [lastKeepAliveSuccess timeIntervalSinceNow] < -5 * [[[NSUserDefaults standardUserDefaults] objectForKey:@"keepAliveInterval"] doubleValue]) return;

	[NSThread detachNewThreadSelector:@selector(threadedKeepAlive) toTarget:self withObject:nil];
	[self startKeepAliveTimerResettingState:NO];
}

/*
 * A threaded keepalive to avoid blocking the interface
 */
- (void) threadedKeepAlive
{
	if (!mConnected) return;
	mysql_ping(mConnection);
	if (lastKeepAliveSuccess) {
		[lastKeepAliveSuccess release];
		lastKeepAliveSuccess = nil;
	}
	lastKeepAliveSuccess = [[NSDate alloc] initWithTimeIntervalSinceNow:0];
}
@end