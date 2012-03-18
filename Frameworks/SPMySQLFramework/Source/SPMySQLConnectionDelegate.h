//
//  $Id$
//
//  SPMySQLConnectionDelegate.h
//  SPMySQLFramework
//
//  Created by Stuart Connolly (stuconnolly.com) on October 20, 2010.
//  Copyright (c) 2010 Stuart Connolly. All rights reserved.
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

#import "SPMySQLConstants.h"

@protocol SPMySQLConnectionDelegate <NSObject>
@optional

/**
 * Notifies the delegate that a query will be performed.
 *
 * @param query The query string that will be sent to the MySQL server
 * @param connection The connection instance performing the query
 */
- (void)willQueryString:(NSString *)query connection:(id)connection;

/**
 * Notifies the delegate that a query that was just performed gave
 * an error.
 *
 * @param error The query error, as a string
 * @param connection The connection instance which received the error
 */
- (void)queryGaveError:(NSString *)error connection:(id)connection;

/**
 * Notifies the delegate that it should display the supplied error.
 * The connection may sometimes want to notify the user directly
 * about certain issues, and will use this method to allow the
 * delegate to do so.
 *
 * @param title The title of the message to display to the user
 * @param message The main text of the message to display to the user
 */
- (void)showErrorWithTitle:(NSString *)title message:(NSString *)message;

/**
 * Requests the keychain password for the connection.
 * When a connection is being made to a server, it is best not to
 * set the password on the class; instead, it should be kept within
 * the secure store, and the other connection details (user, host)
 * can be used to look it up and supplied on demand.
 *
 * @param connection The connection instance to supply the password for
 */
- (NSString *)keychainPasswordForConnection:(id)connection;

/**
 * Notifies the delegate that no underlying connection is available,
 * typically when the connection has been asked to perform a query
 * or some other action for which a connection must be present.
 * Those actions will still return false or error states as appropriate,
 * but the delegate may wish to perform actions as a result of a total
 * loss of connection.
 *
 * @param connection The connection instance which has lost the connection to the host
 */
- (void)noConnectionAvailable:(id)connection;

/**
 * Notifies the delegate that although a SSL connection was requested,
 * MySQL made the connection without using SSL.  This can happen because
 * the server connected to doesn't support SSL or had it disabled, or
 * that insufficient details were provided to make the connection over
 * SSL.
 */
- (void)connectionFellBackToNonSSL:(id)connection;

/**
 * Notifies the delegate that the connection has been temporarily lost,
 * and asks the delegate for guidance on how to proceed.  If the delegate
 * does not implement this method, reconnections will automatically be
 * attempted - up to a small limit of attempts.
 *
 * @param connection The connection instance that requires a decision on how to proceed
 */
- (SPMySQLConnectionLostDecision)connectionLost:(id)connection;

@end
