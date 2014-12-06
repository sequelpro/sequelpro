//
//  $Id: PGPostgresConnectionDelegate.h 3841 2012-09-10 08:52:00Z stuart02 $
//
//  PGPostgresConnectionDelegate.h
//  PostgresKit
//
//  Copyright (c) 2008-2009 David Thorpe, djt@mutablelogic.com
//
//  Forked by the Sequel Pro Team on July 22, 2012.
// 
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not 
//  use this file except in compliance with the License. You may obtain a copy of 
//  the License at
// 
//  http://www.apache.org/licenses/LICENSE-2.0
// 
//  Unless required by applicable law or agreed to in writing, software 
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT 
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the 
//  License for the specific language governing permissions and limitations under
//  the License.

@class PGPostgresConnection;

@protocol PGPostgresConnectionDelegate <NSObject>

/**
 * Called whenever the supplied connection has been successfully established and is ready to use.
 *
 * @param connection The connection instance.
 */
- (void)connectionEstablished:(PGPostgresConnection *)connection;

/**
 * Called whenever the supplied connection has been successfully reset and is ready to use.
 *
 * @param connection The connection instance.
 */
- (void)connectionReset:(PGPostgresConnection *)connection;

/**
 * Called whenever a connection is disconnected.
 *
 * @param connection The connection instance.
 */
- (void)connectionDisconnected:(PGPostgresConnection *)connection;

/**
 * Called whenever a message is received from the PostgreSQL server.
 *
 * @param connection The connection instance.
 * @param notice     The notice message received.
 */
- (void)connection:(PGPostgresConnection *)connection notice:(NSString *)notice;

/**
 * Called just before a query is about to be executed.
 *
 * @param connection The connection executing the query.
 * @param query      The query about the be executed.
 * @param values     The values of the query.
 */
- (void)connection:(PGPostgresConnection *)connection willExecute:(NSObject *)query withValues:(NSArray *)values;

@end
