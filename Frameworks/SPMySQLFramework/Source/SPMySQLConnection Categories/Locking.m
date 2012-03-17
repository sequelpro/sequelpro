//
//  $Id$
//
//  Locking.m
//  SPMySQLFramework
//
//  Created by Rowan Beentje (rowan.beent.je) on January 22, 2012
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

// This class is private to the framework.

#import "Locking.h"
#import "SPMySQL Private APIs.h"

@implementation SPMySQLConnection (Locking)


/**
 * Lock the connection. This must be done before performing any operation
 * that is not thread safe, eg. performing queries or pinging.
 */
- (void)_lockConnection
{

    // We can only start a query when the condition is SPMySQLConnectionIdle
	[connectionLock lockWhenCondition:SPMySQLConnectionIdle];
    
    // Set the condition to SPMySQLConnectionBusy
    [connectionLock unlockWithCondition:SPMySQLConnectionBusy];
}

/**
 * Attempt to lock the connection. If the connection is idle (unlocked), this method
 * locks the connection and returns YES for success. The connection must afterward
 * be unlocked using unlockConnection. If the connection is currently busy (locked),
 * this method immediately returns NO and doesn't lock the connection.
 */
- (BOOL)_tryLockConnection
{

	// If the connection is already is use, return failure
	if (![connectionLock tryLockWhenCondition:SPMySQLConnectionIdle]) {
		return NO;
	}

	// We're allowed to use the connection; set it to busy, and return success
	[connectionLock unlockWithCondition:SPMySQLConnectionBusy];
	return YES;
}


/**
 * Unlock the connection.
 */
- (void)_unlockConnection
{

    // Always lock the conditional lock before proceeding
    [connectionLock lock];
    
    // Check if the connection actually was busy. If it wasn't busy,
    // it means the connection may have been unlocked twice. This is
    // potentially dangerous, so we log this to the console
    if ([connectionLock condition] != SPMySQLConnectionBusy) {
        NSLog(@"SPMySQLConnection: Tried to unlock the connection, but it wasn't locked.");
    }
    
    // Since we connected with CLIENT_MULTI_RESULT, we must make sure there are not more results!
    // This is still a bit of a dirty hack
    if (state == SPMySQLConnected
		&& mySQLConnection && mySQLConnection->net.vio && mySQLConnection->net.buff && mysql_more_results(mySQLConnection))
	{
        NSLog(@"SPMySQLConnection: Discarding unretrieved results. This is currently normal when using CALL.");
        [self _flushMultipleResultSets];
    }
    
    // Tell everyone that the connection is available again
    [connectionLock unlockWithCondition:SPMySQLConnectionIdle];
}

@end
