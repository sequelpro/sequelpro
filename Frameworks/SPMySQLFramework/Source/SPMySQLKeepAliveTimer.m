//
//  $Id$
//
//  SPMySQLKeepAliveTimer.m
//  SPMySQLFramework
//
//  Created by Rowan Beentje (rowan.beent.je) on March 5, 2012
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


#import "SPMySQLKeepAliveTimer.h"
#import "SPMySQL Private APIs.h"

@interface SPMySQLKeepAliveTimer (Private_API)

- (void)_initKeepAliveTimer;
- (void)_forwardPing;

@end

#pragma mark -

@implementation SPMySQLKeepAliveTimer

/**
 * Prevent SPMySQLKeepAliveTimer from being init'd normally.
 */
- (id)init
{
	[NSException raise:NSInternalInconsistencyException format:@"SPMySQLKeepAliveTimers should not be init'd directly; use initWithInterval:target:selector: instead."];
	return nil;
}

/**
 * Initialise the SPMySQLKeepAliveTimer.  This also sets up the contained timer,
 * which has to be wrapped in this class to prevent retain cycles preventing the
 * parent connection from being released.
 *
 * After initialisation, the delegate should be set to ensure that the timer events
 * are received.
 */
- (id)initWithInterval:(NSTimeInterval)anInterval target:(id)aTarget selector:(SEL)aSelector
{
	if ((self = [super init])) {
		wrappedTimer = nil;

		// Keep a weak reference to the target
		timerTarget = aTarget;
		timerSelector = aSelector;
		timerRepeatInterval = anInterval;

		// Ensure the timer is set up on the main thread
		if ([NSThread isMainThread]) {
			[self _initKeepAliveTimer];
		} else {
			[self performSelectorOnMainThread:@selector(_initKeepAliveTimer) withObject:nil waitUntilDone:YES];
		}
	}

	return self;
}

/**
 * Invalidate the wrapped timer, which also releases the reference to the timer
 * target (this object), breaking retain loops.
 */
- (void)invalidate
{
	if ([NSThread isMainThread]) {
		[wrappedTimer invalidate];
	} else {
		[wrappedTimer performSelectorOnMainThread:@selector(invalidate) withObject:nil waitUntilDone:YES];
	}
}

- (void)dealloc
{
	[wrappedTimer dealloc];
	[super dealloc];
}

@end

@implementation SPMySQLKeepAliveTimer (Private_API)

/**
 * Set up the timer to tickle the target.  This must be set up on the main thread
 * to ensure the timer events keep firing.
 */
- (void)_initKeepAliveTimer
{
	wrappedTimer = [[NSTimer scheduledTimerWithTimeInterval:timerRepeatInterval target:self	selector:@selector(_forwardPing) userInfo:nil repeats:YES] retain];
}

/**
 * Forward the NSTimer-fired ping to the target object.  Performing this forwarding
 * breaks the retain cycle.
 */
- (void)_forwardPing
{
	[timerTarget performSelector:timerSelector];
}

@end
