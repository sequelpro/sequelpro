//
//  $Id$
//
//  Copying.m
//  SPMySQLFramework
//
//  Created by Rowan Beentje (rowan.beent.je) on March 8, 2012
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

#import "Copying.h"

@implementation SPMySQLConnection (Copying)

/**
 * Provide a copy of the SPMySQLConnection instance.
 * The copy should inherit the full setup, but will not inherit
 * the connection state - it will not be connected, and any connection
 * details such as the selected database/encoding will not be inherited.
 * Note that any proxy will not be referenced in the new connection, and
 * should also be set if desired.
 */
- (id)copyWithZone:(NSZone *)zone
{
	SPMySQLConnection *copy = [[[self class] allocWithZone:zone] init];

	// Synthesized details
	[copy setDelegate:delegate];
	[copy setHost:host];
	[copy setUsername:username];
	[copy setPassword:password];
	[copy setPort:port];
	[copy setUseSocket:useSocket];
	[copy setSocketPath:socketPath];
	[copy setUseSSL:useSSL];
	[copy setSslKeyFilePath:sslKeyFilePath];
	[copy setSslCertificatePath:sslCertificatePath];
	[copy setSslCACertificatePath:sslCACertificatePath];
	[copy setTimeout:timeout];
	[copy setUseKeepAlive:useKeepAlive];
	[copy setRetryQueriesOnConnectionFailure:retryQueriesOnConnectionFailure];
	[copy setDelegateQueryLogging:delegateQueryLogging];

	// Active connection state details, like selected database and encoding, are *not* copied.

	return copy;
}

@end
