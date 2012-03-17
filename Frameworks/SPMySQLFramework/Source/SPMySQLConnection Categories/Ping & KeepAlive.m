//
//  $Id$
//
//  Ping & KeepAlive.m
//  SPMySQLFramework
//
//  Created by Rowan Beentje (rowan.beent.je) on January 14, 2012
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
//  More info at <http://code.google.com/p/sequel-pro/>


#import "Ping & KeepAlive.h"
#import "Locking.h"
#import <pthread.h>

@implementation SPMySQLConnection (Ping_and_KeepAlive)

#pragma mark -
#pragma mark Keepalive ping initialisation

/**
 * Keeps the connection alive by running a ping.
 * This method is called every ten seconds and spawns a thread which determines
 * whether or not it should perform a ping.
 */
- (void)_keepAlive
{

	// Do nothing if not connected or if keepalive is disabled
	if (state != SPMySQLConnected || !useKeepAlive) return;

	// Check to see whether a ping is required.  First, compare the last query
	// and keepalive times against the keepalive interval.
	// Compare against interval-1 to allow default keepalive intervals to repeat
	// at the correct intervals (eg no timer interval delay).
	uint64_t currentTime = mach_absolute_time();
	if (_elapsedSecondsSinceAbsoluteTime(lastConnectionUsedTime) < keepAliveInterval - 1
		|| _elapsedSecondsSinceAbsoluteTime(lastKeepAliveTime) < keepAliveInterval - 1)
	{
		return;
	}

	// Attempt to lock the connection. If the connection is currently busy,
    // we don't need a ping.
	if (![self _tryLockConnection]) return;
	[self _unlockConnection];

	// Store the ping time
	lastKeepAliveTime = currentTime;

	[NSThread detachNewThreadSelector:@selector(_threadedKeepAlive) toTarget:self withObject:nil];
}

/**
 * A threaded keepalive to avoid blocking the interface.  Performs safety
 * checks, and then creates a child pthread to actually ping the connection,
 * forcing the thread to close after the timeout if it hasn't closed already.
 */
- (void)_threadedKeepAlive
{

	// If the maximum number of ping failures has been reached, trigger a reconnect
	if (keepAliveLastPingBlocked || keepAlivePingFailures >= 3) {
		[self reconnect];
		return;
	}

	// Otherwise, perform a background ping.
	BOOL pingResult = [self _pingConnectionUsingLoopDelay:10000];
	if (pingResult) {
		keepAlivePingFailures = 0;
	} else {
		keepAlivePingFailures++;
	}
}

#pragma mark -
#pragma mark Master ping method

/**
 * This function provides a method of pinging the remote server while also enforcing
 * the specified connection time.  This is required because low-level net reads can
 * block indefinitely if the remote server disappears or on network issues - setting
 * the MYSQL_OPT_READ_TIMEOUT (and the WRITE equivalent) would "fix" ping, but cause
 * long queries to be terminated.
 * The supplied loop delay number controls how tight the thread checking loop is, in
 * microseconds, to allow differentiating foreground and background pings.
 * Unlike mysql_ping, this function returns FALSE on failure and TRUE on success.
 */
- (BOOL)_pingConnectionUsingLoopDelay:(NSUInteger)loopDelay
{
	if (state != SPMySQLConnected) return NO;

	uint64_t pingStartTime_t;
	double pingElapsedTime;
	BOOL threadCancelled = NO;

	// Set up a query lock
	[self _lockConnection];

	keepAliveLastPingSuccess = NO;
	keepAliveLastPingBlocked = NO;
	keepAlivePingThreadActive = YES;

	// Use a ping timeout defaulting to thirty seconds, but using the connection timeout if set
	NSUInteger pingTimeout = 30;
	if (timeout > 0) pingTimeout = timeout;

	// Set up a struct containing details the ping task will need
	SPMySQLConnectionPingDetails pingDetails;
	pingDetails.mySQLConnection = mySQLConnection;
	pingDetails.keepAliveLastPingSuccessPointer = &keepAliveLastPingSuccess;
	pingDetails.keepAlivePingActivePointer = &keepAlivePingThreadActive;

	// Create a pthread for the ping
	pthread_attr_t attr;
	pthread_attr_init(&attr);
	pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
	pthread_create(&keepAlivePingThread, &attr, (void *)&_backgroundPingTask, &pingDetails);

	// Record the ping start time
	pingStartTime_t = mach_absolute_time();

	// Loop until the ping completes
	do {
		usleep((useconds_t)loopDelay);
		pingElapsedTime = _elapsedSecondsSinceAbsoluteTime(pingStartTime_t);

		// If the ping timeout has been exceeded, force a timeout; double-check that the
		// thread is still active.
		if (pingElapsedTime > pingTimeout && keepAlivePingThreadActive && !threadCancelled) {
			pthread_cancel(keepAlivePingThread);
			threadCancelled = YES;

		// If the timeout has been exceeded by an additional two seconds, and the thread is
		// still active, kill the thread.  This can occur in certain network conditions causing
		// a blocking read.
		} else if (pingElapsedTime > (pingTimeout + 2) && keepAlivePingThreadActive) {
			pthread_kill(keepAlivePingThread, SIGUSR1);	
			keepAlivePingThreadActive = NO;
			keepAliveLastPingBlocked = YES;
		}
	} while (keepAlivePingThreadActive);

	// Clean up
	keepAlivePingThread = NULL;
	pthread_attr_destroy(&attr);

    // Unlock the connection
	[self _unlockConnection];

	return keepAliveLastPingSuccess;
}

#pragma mark -
#pragma mark Ping thread internals

/**
 * Actually perform a keepalive ping - intended for use within a pthread.
 */
void _backgroundPingTask(void *ptr)
{
	SPMySQLConnectionPingDetails *pingDetails = (SPMySQLConnectionPingDetails *)ptr;

	// Set up a cleanup routine
	pthread_cleanup_push(_pingThreadCleanup, pingDetails);

	// Set up a signal handler for SIGUSR1, to handle forced timeouts.
	signal(SIGUSR1, _forceThreadExit);

	// Perform a ping
	*(pingDetails->keepAliveLastPingSuccessPointer) = (BOOL)(!mysql_ping(pingDetails->mySQLConnection));

	// Call the cleanup routine
	pthread_cleanup_pop(1);
}

/**
 * Support forcing a thread to exit as a result of a signal.
 */
void _forceThreadExit(int signalNumber)
{
	pthread_exit(NULL);
}

void _pingThreadCleanup(void *pingDetails)
{
	SPMySQLConnectionPingDetails *pingDetailsStruct = pingDetails;
	*(pingDetailsStruct->keepAlivePingActivePointer) = NO;
}

@end
