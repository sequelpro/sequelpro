//
//  $Id: PGPostgresConnection.h 3845 2012-09-11 09:35:40Z stuart02 $
//
//  PGPostgresConnection.h
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

#import "PGPostgresConnectionDelegate.h"

@class PGPostgresError;
@class PGPostgresResult;
@class PGPostgresStatement;
@class PGPostgresConnectionParameters;

@interface PGPostgresConnection : NSObject 
{
	void *_connection;
	
	NSString *_host;
	NSString *_user;
	NSString *_database;
	NSString *_password;
	NSString *_socketPath;
	NSString *_encoding;
	NSString *_connectionError;
	NSString *_applicationName;
	
	const char **_connectionParamNames;
	const char **_connectionParamValues;
	
	NSStringEncoding _stringEncoding;
	
	NSUInteger _port;
	NSUInteger _timeout;
	NSUInteger _keepAliveInterval;
	
	BOOL _useSocket;
	BOOL _useKeepAlive;
	BOOL _lastQueryWasCancelled;
	BOOL _delegateSupportsWillExecute;
	
	NSMutableDictionary *_typeMap;
	
	PGPostgresError *_lastError;
	PGPostgresConnectionParameters *_parameters;
	
	NSObject <PGPostgresConnectionDelegate> *_delegate;
}

@property (readwrite, assign) NSObject <PGPostgresConnectionDelegate> *delegate;

@property (readwrite, retain) NSString *host;
@property (readwrite, retain) NSString *user;
@property (readwrite, retain) NSString *database;
@property (readwrite, retain) NSString *password;
@property (readwrite, retain) NSString *socketPath;
@property (readwrite, retain) NSString *applicationName;

@property (readonly) NSString *encoding;
@property (readonly) NSString *connectionError;
@property (readonly) PGPostgresError *lastError;
@property (readonly) NSStringEncoding stringEncoding;
@property (readonly) PGPostgresConnectionParameters *parameters;

@property (readwrite, assign) BOOL useSocket;
@property (readwrite, assign) BOOL useKeepAlive;
@property (readwrite, assign) BOOL lastQueryWasCancelled;

@property (readwrite, assign) NSUInteger timeout;
@property (readwrite, assign) NSUInteger port;
@property (readwrite, assign) NSUInteger keepAliveInterval;

- (id)initWithDelegate:(NSObject <PGPostgresConnectionDelegate> *)delegate;

- (BOOL)connect;
- (void)disconnect;
- (BOOL)isConnected;
- (BOOL)reset;

- (NSUInteger)clientVersion;
- (NSUInteger)serverVersion;
- (NSUInteger)serverProcessId;

- (BOOL)cancelCurrentQuery:(NSError **)error;

@end
