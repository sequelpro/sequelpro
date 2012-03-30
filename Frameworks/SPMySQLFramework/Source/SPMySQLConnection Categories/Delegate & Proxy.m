//
//  $Id$
//
//  Delegate & Proxy.m
//  SPMySQLFramework
//
//  Created by Rowan Beentje (rowan.beent.je) on February 9, 2012
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

#import "Delegate & Proxy.h"
#import "SPMySQL Private APIs.h"

@implementation SPMySQLConnection (Delegate_and_Proxy)

#pragma mark -
#pragma mark Connection delegate

/**
 * Set the delegate of the connection object, precaching availability of
 * oft-called methods to allow optimisation.
 */
- (void)setDelegate:(NSObject <SPMySQLConnectionDelegate> *)aDelegate
{
	delegate = aDelegate;

	// Cache whether the delegate implements certain delegate methods
	delegateSupportsWillQueryString = [delegate respondsToSelector:@selector(willQueryString:connection:)];
	delegateSupportsConnectionLost = [delegate respondsToSelector:@selector(connectionLost:)];
}

/**
 * Return the current instance delegate.
 */
- (NSObject <SPMySQLConnectionDelegate> *)delegate
{
	return delegate;
}

#pragma mark -
#pragma mark Connection proxy

/**
 * Set the connection proxy, used by the class to set up a connection pre-requisite, and
 * monitored for state changes.  This allows the MySQL connection to be routed over
 * another helper class providing a port or socket.  This method also records the initial
 * state and sets the state change selector.
 */
- (void)setProxy:(NSObject <SPMySQLConnectionProxy> *)aProxy
{
	proxy = [aProxy retain];
	previousProxyState = [aProxy state];

	[proxy setConnectionStateChangeSelector:@selector(_proxyStateChange:) delegate:self];
}

/**
 * Return the current instance proxy.
 */
- (NSObject <SPMySQLConnectionProxy> *)proxy
{
	return proxy;
}

@end

#pragma mark -

@implementation SPMySQLConnection (Delegate_and_Proxy_Private_API)

/**
 * Handle any state changes in the associated connection proxy.
 */
- (void)_proxyStateChange:(NSObject <SPMySQLConnectionProxy> *)aProxy
{

	// Perform no actions if this isn't the current connection proxy, or if notifications
	// are currently set to be ignored
	if (aProxy != proxy || proxyStateChangeNotificationsIgnored) return;

	SPMySQLConnectionProxyState newState = [aProxy state];
	
	// If the connection proxy disconnects, trigger a reconnect; use a new thread to allow the
	// main thread to process events as required.
	if (state == SPMySQLConnected && newState == SPMySQLProxyIdle && previousProxyState == SPMySQLProxyConnected) {

		// Clear the state change selector on the proxy until a connection is re-established
		proxyStateChangeNotificationsIgnored = YES;

		// Trigger a reconnect
		[NSThread detachNewThreadSelector:@selector(reconnect) toTarget:self withObject:nil];
	}

	// Update the state record
	previousProxyState = newState;
}

/**
 * Ask the delegate for the connection lost decision.  This can be called from
 * any thread, and will call itself on the main thread if necessary, updating a global
 * variable which is then returned on the child thread.
 */
- (SPMySQLConnectionLostDecision)_delegateDecisionForLostConnection
{
	SPMySQLConnectionLostDecision theDecision = SPMySQLConnectionLostDisconnect;

	// If on the main thread, ask the delegate directly.
	if ([NSThread isMainThread]) {
		[delegateDecisionLock lock];
		lastDelegateDecisionForLostConnection = [delegate connectionLost:self];
		theDecision = lastDelegateDecisionForLostConnection;
		[delegateDecisionLock unlock];

	// Otherwise call ourself on the main thread, waiting until the reply is received.
	} else {

		// First check whether the application is in a modal state; if so, wait
		while ([NSApp modalWindow]) usleep(100000);

		[self performSelectorOnMainThread:@selector(_delegateDecisionForLostConnection) withObject:nil waitUntilDone:YES];
		[delegateDecisionLock lock];
		theDecision = lastDelegateDecisionForLostConnection;
		[delegateDecisionLock unlock];
	}

	return theDecision;
}

@end
