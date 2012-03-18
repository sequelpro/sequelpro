//
//  $Id$
//
//  Server Info.m
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


#import "Server Info.h"
#import "SPMySQL Private APIs.h"

@implementation SPMySQLConnection (Server_Info)

#pragma mark -
#pragma mark Server version information

/**
 * Return the server version string, or nil on failure.
 */
- (NSString *)serverVersionString
{
	if (serverVersionString) {
		return [NSString stringWithString:serverVersionString];
	}

	return nil;
}

/**
 * Return the server major version or NSNotFound on failure
 */
- (NSUInteger)serverMajorVersion
{
	
	if (serverVersionString != nil) {
		NSString *s = [[serverVersionString componentsSeparatedByString:@"."] objectAtIndex:0];
		return (NSUInteger)[s integerValue];
	} 
	
	return NSNotFound;
}

/**
 * Return the server minor version or NSNotFound on failure
 */
- (NSUInteger)serverMinorVersion
{
	if (serverVersionString != nil) {
		NSString *s = [[serverVersionString componentsSeparatedByString:@"."] objectAtIndex:1];
		return (NSUInteger)[s integerValue];
	}
	
	return NSNotFound;
}

/**
 * Return the server release version or NSNotFound on failure
 */
- (NSUInteger)serverReleaseVersion
{
	if (serverVersionString != nil) {
		NSString *s = [[serverVersionString componentsSeparatedByString:@"."] objectAtIndex:2];
		return (NSUInteger)[[[s componentsSeparatedByString:@"-"] objectAtIndex:0] integerValue];
	}
	
	return NSNotFound;
}

#pragma mark -
#pragma mark Server version comparisons

/**
 * Returns whether the connected server version is greater than or equal to the
 * supplied version number.  Returns NO if no connection is active.
 */
- (BOOL)serverVersionIsGreaterThanOrEqualTo:(NSUInteger)aMajorVersion minorVersion:(NSUInteger)aMinorVersion releaseVersion:(NSUInteger)aReleaseVersion
{
	if (!serverVersionString) return NO;

	NSArray *serverVersionParts = [serverVersionString componentsSeparatedByString:@"."];

	NSUInteger serverMajorVersion = (NSUInteger)[[serverVersionParts objectAtIndex:0] integerValue];
	if (serverMajorVersion < aMajorVersion) return NO;
	if (serverMajorVersion > aMajorVersion) return YES;

	NSUInteger serverMinorVersion = (NSUInteger)[[serverVersionParts objectAtIndex:1] integerValue];
	if (serverMinorVersion < aMinorVersion) return NO;
	if (serverMinorVersion > aMinorVersion) return YES;

	NSString *serverReleasePart = [serverVersionParts objectAtIndex:2];
	NSUInteger serverReleaseVersion = (NSUInteger)[[[serverReleasePart componentsSeparatedByString:@"-"] objectAtIndex:0] integerValue];
	if (serverReleaseVersion < aReleaseVersion) return NO;
	return YES;
}

#pragma mark -
#pragma mark Server tasks & processes

/**
 * Returns a result set describing the current server threads and their tasks.  Note that
 * the resulting process list defaults to the short form; run a manual SHOW FULL PROCESSLIST
 * to retrieve tasks in non-truncated form.
 * Returns nil on error.
 */
- (SPMySQLResult *)listProcesses
{
	if (state != SPMySQLConnected) return nil;

	// Check the connection if appropriate
	if (![self _checkConnectionIfNecessary]) return nil;

	// Lock the connection before using it
	[self _lockConnection];

	// Get the process list
	MYSQL_RES *mysqlResult = mysql_list_processes(mySQLConnection);

	// Convert to SPMySQLResult
	SPMySQLResult *theResult = [[SPMySQLResult alloc] initWithMySQLResult:mysqlResult stringEncoding:stringEncoding];

	// Unlock and return
	[self _unlockConnection];
	return [theResult autorelease];
}

/**
 * Kill the process with the supplied thread ID.  On MySQL version 5 or later, this kills
 * the query; on older servers this kills the entire connection.  Note that the SUPER
 * privilege is required to kill queries and processes not belonging to the currently
 * connected user, while only PROCESS is required to see other user's processes.
 * Returns a boolean indicating success or failure.
 */
- (BOOL)killQueryOnThreadID:(unsigned long)theThreadID
{

	// Note that mysql_kill has been deprecated, so use a query to perform this task.
	NSMutableString *killQuery = [NSMutableString stringWithString:@"KILL"];
	if ([self serverVersionIsGreaterThanOrEqualTo:5 minorVersion:0 releaseVersion:0]) {
		[killQuery appendString:@" QUERY"];
	}
	[killQuery appendFormat:@" %lu", theThreadID];

	// Run the query
	[self queryString:killQuery];

	// Return a value based on whether the query errored or not
	return ![self queryErrored];
}

@end