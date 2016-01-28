//
//  Server Info.h
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
//  More info at <https://github.com/sequelpro/sequelpro>

@class SPMySQLResult;

@interface SPMySQLConnection (Server_Info)

// Server version information
- (NSString *)serverVersionString;
- (NSUInteger)serverMajorVersion;
- (NSUInteger)serverMinorVersion;
- (NSUInteger)serverReleaseVersion;

// Server version comparisons
- (BOOL)serverVersionIsGreaterThanOrEqualTo:(NSUInteger)aMajorVersion minorVersion:(NSUInteger)aMinorVersion releaseVersion:(NSUInteger)aReleaseVersion;

// Server tasks & processes
- (SPMySQLResult *)listProcesses;
- (BOOL)killQueryOnThreadID:(unsigned long)theThreadID;

/**
 * mysql_shutdown() - If the user has the permission, will shutdown the (remote) server
 * @return Whether the command was executed successfully
 *         Note: this can also be NO if the user denied a reconnect attempt.
 *
 * WARNING: This method may return NO if the current thread is cancelled!
 *          You MUST check the isCancelled flag before using the result!
 */
- (BOOL)serverShutdown;

@end
