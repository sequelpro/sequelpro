//
//  Querying & Preparation.m
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


#import "SPMySQLConnection.h"
#import "SPMySQL Private APIs.h"

@implementation SPMySQLConnection (Querying_and_Preparation)

#pragma mark -
#pragma mark Data preparation

/**
 * See also the NSString methods mySQLTickQuotedString and mySQLBacktickQuotedString,
 * added via an NSString category; however these methods are safer and more complete
 * as they use the current connection encoding to quote characters.
 */


/**
 * Take a string, escapes any special character, and surrounds it with single quotes
 * for safe use within a query; correctly escapes any characters within the string
 * using the current connection encoding.
 */
- (NSString *)escapeAndQuoteString:(NSString *)theString
{
	return SPMySQLConnectionEscapeString(self, theString, YES);
}

/**
 * Take a string and escapes any special character for safe use within a query; correctly
 * escapes any characters within the string using the current connection encoding.
 * Allows control over whether to also wrap the string in single quotes.
 *
 * WARNING: This method may return nil if the current thread is cancelled!
 *          You MUST check the isCancelled flag before using the result!
 */
- (NSString *)escapeString:(NSString *)theString includingQuotes:(BOOL)includeQuotes
{

	// Return nil strings untouched
	if (!theString) return theString;

	// To correctly escape the string, an active connection is required, so verify.
	if (state == SPMySQLDisconnected || state == SPMySQLConnecting) {
		if ([delegate respondsToSelector:@selector(noConnectionAvailable:)]) {
			[delegate noConnectionAvailable:self];
		}
		return nil;
	}

	// Ensure per-thread variables are set up
	[self _validateThreadSetup];

	if (![self checkConnectionIfNecessary]) return nil;

	// Perform a lossy conversion to bytes, using NSData to do the hard work.  Preserves
	// nul characters correctly.
	NSData *cData = [theString dataUsingEncoding:stringEncoding allowLossyConversion:YES];
	NSUInteger cDataLength = [cData length];

	// Create a buffer for mysql_real_escape_string to place the converted string into;
	// the max length is 2*length (if every character was quoted) + 2 (quotes/terminator).
	// Adding quotes in this way makes the logic below *slightly* harder to follow but
	// makes the addition of the quotes almost free, which is much nicer when building
	// lots of strings.
	char *escBuffer = (char *)malloc((cDataLength * 2) + 2);

	// Use mysql_real_escape_string to perform the escape, starting one character in
	NSUInteger escapedLength = mysql_real_escape_string(mySQLConnection, escBuffer+1, [cData bytes], cDataLength);

	// Set up an NSData object to allow conversion back to NSString while preserving
	// any nul characters contained in the string.
	NSData *escapedData;
	if (includeQuotes) {

		// Add quotes if requested
		escBuffer[0] = '\'';
		escBuffer[escapedLength+1] = '\'';

		escapedData = [NSData dataWithBytesNoCopy:escBuffer length:escapedLength+2 freeWhenDone:NO];
	} else {
		escapedData = [NSData dataWithBytesNoCopy:escBuffer+1 length:escapedLength freeWhenDone:NO];
	}

	// Convert to the string to return
	NSString *escapedString = [[NSString alloc] initWithData:escapedData encoding:stringEncoding];

	// Free up any memory and return
	free(escBuffer);
	return [escapedString autorelease];
}

/**
 * Take NSData and hex-encodes the contents for safe transmission to a server,
 * preserving all bytes whatever the encoding. Surrounds the hex-encoded resulting
 * string with single quotes and precedes it with the hex-marker X for safe inclusion
 * in a query.
 */
- (NSString *)escapeAndQuoteData:(NSData *)theData
{
	return SPMySQLConnectionEscapeData(self, theData, YES);
}

/**
 * Takes NSData and hex-encodes the contents for safe transmission to a server,
 * preserving all bytes whatever the encoding.
 * Allows control over whether to also wrap the string in single quotes and a
 * preceding X (X'...') for safe use in queries.
 */
- (NSString *)escapeData:(NSData *)theData includingQuotes:(BOOL)includeQuotes
{

	// Return nil datas as nil strings
	if (!theData) return nil;

	NSUInteger dataLength = [theData length];

	// Create a buffer for mysql_real_escape_string to place the converted string into;
	// the max length is 2*length (if every character was quoted) + 3 (quotes/terminator).
	// Adding quotes in this way makes the logic below *slightly* harder to follow but
	// makes the addition of the quotes almost free, which is much nicer when building
	// lots of strings.
	char *hexBuffer = (char *)malloc((dataLength * 2) + 3);

	// Use mysql_hex_string to perform the escape, starting two characters in
	NSUInteger hexLength = mysql_hex_string(hexBuffer+2, [theData bytes], dataLength);

	// Set up the return NSString
	NSString *hexString;
	if (includeQuotes) {

		// Add quotes if requested
		hexBuffer[0] = 'X';
		hexBuffer[1] = '\'';
		hexBuffer[hexLength+2] = '\'';

		hexString = [[NSString alloc] initWithBytes:hexBuffer length:hexLength+3 encoding:NSASCIIStringEncoding];
	} else {
		hexString = [[NSString alloc] initWithBytes:hexBuffer+2 length:hexLength encoding:NSASCIIStringEncoding];
	}

	// Free up any memory and return
	free(hexBuffer);
	return [hexString autorelease];
}

#pragma mark -
#pragma mark Queries

/**
 * Run a query, provided as a string, on the active connection in the current connection
 * encoding.  Stores all the results before returning the complete result set.
 */
- (SPMySQLResult *)queryString:(NSString *)theQueryString
{
	return SPMySQLConnectionQueryString(self, theQueryString, stringEncoding, SPMySQLResultAsResult);
}

/**
 * Run a query, provided as a string, on the active connection in the current connection
 * encoding.  Returns the result as a fast streaming query set, where not all the results
 * may be available at time of return.
 */
- (SPMySQLFastStreamingResult *)streamingQueryString:(NSString *)theQueryString
{
	return SPMySQLConnectionQueryString(self, theQueryString, stringEncoding, SPMySQLResultAsFastStreamingResult);
}

/**
 * Run a query, provided as a string, on the active connection in the current connection
 * encoding.  Returns the result as a result set which also handles data storage.  Note
 * that the donwloading of results will not occur until -[resultSet startDownload] is called.
 */
- (SPMySQLStreamingResultStore *)resultStoreFromQueryString:(NSString *)theQueryString
{
	return SPMySQLConnectionQueryString(self, theQueryString, stringEncoding, SPMySQLResultAsStreamingResultStore);
}

/**
 * Run a query, provided as a string, on the active connection in the current connection
 * encoding.  Returns the result as a streaming query set, where not all the results may
 * be available at time of return.
 * Supports a flag specifying whether streaming should be low-memory blocking (results are
 * read from the server as the code retrives them, possibly blocking other queries on the
 * server) or fast streaming (results are cached in the result object as fast as possible,
 * freeing up the server even in the local rows are still being read from the result object).
 * Will return a SPMySQLStreamingResult or SPMySQLFastStreamingResult as appropriate.
 */
- (id)streamingQueryString:(NSString *)theQueryString useLowMemoryBlockingStreaming:(BOOL)fullStreaming
{
	return SPMySQLConnectionQueryString(self, theQueryString, stringEncoding, fullStreaming?SPMySQLResultAsLowMemStreamingResult:SPMySQLResultAsFastStreamingResult);
}

/**
 * Run a query, provided as a string, on the active connection.  The query and its result
 * set are interpreted according to the supplied encoding, which should usually match
 * the connection encoding.
 * The result type desired can be specified, supporting either standard or streaming
 * result sets.
 *
 * WARNING: This method may return nil if the current thread is cancelled!
 *          You MUST check the isCancelled flag before using the result!
 */
- (id)queryString:(NSString *)theQueryString usingEncoding:(NSStringEncoding)theEncoding withResultType:(SPMySQLResultType)theReturnType
{
	double queryExecutionTime;
	NSString *theErrorMessage;
	NSUInteger theErrorID;
	NSString *theSqlstate;
	lastQueryWasCancelled = NO;
	lastQueryWasCancelledUsingReconnect = NO;

	// If a disconnect was requested, cancel the action
	if (userTriggeredDisconnect) {
		return nil;
	}

	// Check the connection state - if no connection is available, log an
	// error and return.
	if (state == SPMySQLDisconnected || state == SPMySQLConnecting) {
		if ([delegate respondsToSelector:@selector(queryGaveError:connection:)]) {
			[delegate queryGaveError:@"No connection available!" connection:self];
		}
		if ([delegate respondsToSelector:@selector(noConnectionAvailable:)]) {
			[delegate noConnectionAvailable:self];
		}
		return nil;
	}

	// Ensure per-thread variables are set up
	[self _validateThreadSetup];

	// Check the connection if necessary, returning nil if the state couldn't be validated
	if (![self checkConnectionIfNecessary]) return nil;

	// Determine whether a maximum query size needs to be restored from a previous query
	if (queryActionShouldRestoreMaxQuerySize != NSNotFound) {
		[self _restoreMaximumQuerySizeAfterQuery];
	}

	// If delegate logging is enabled, and the protocol is implemented, inform the delegate
	if (delegateQueryLogging && delegateSupportsWillQueryString) {
		[delegate willQueryString:theQueryString connection:self];
	}

	// Retrieve a byte buffer from the supplied NSString
	NSData *queryData = [theQueryString dataUsingEncoding:theEncoding allowLossyConversion:YES];
	NSUInteger queryBytesLength = [queryData length];
	const char *queryBytes = [queryData bytes];

	// Check the query length against the current maximum query length.  If it is
	// larger, the query would error (and probably cause a disconnect), so if
	// the maximum size is editable, increase it and reconnect.
	if (queryBytesLength > maxQuerySize) {
		queryActionShouldRestoreMaxQuerySize = maxQuerySize;
		if (![self _attemptMaxQuerySizeIncreaseTo:(queryBytesLength + 1024)]) {
			queryActionShouldRestoreMaxQuerySize = NSNotFound;
			return nil;
		}
	}

	// Prepare to enter a loop to run the query, allowing reattempts if appropriate
	NSUInteger queryAttemptsAllowed = 1;
	if (retryQueriesOnConnectionFailure) queryAttemptsAllowed++;
	int queryStatus;

	// Lock the connection while it's actively in use
	[self _lockConnection];

	unsigned long long theAffectedRowCount;
	do {

		// While recording the overall execution time (including network lag!), run
		// the raw query
		uint64_t queryStartTime = mach_absolute_time();
		queryStatus = mysql_real_query(mySQLConnection, queryBytes, queryBytesLength);
		queryExecutionTime = _elapsedSecondsSinceAbsoluteTime(queryStartTime);
		lastConnectionUsedTime = mach_absolute_time();
		
		// "An integer greater than zero indicates the number of rows affected or retrieved.
		//  Zero indicates that no records were updated for an UPDATE statement, no rows matched the WHERE clause in the query or that no query has yet been executed.
		//  -1 indicates that the query returned an error or that, for a SELECT query, mysql_affected_rows() was called prior to calling mysql_store_result()."
		theAffectedRowCount = mysql_affected_rows(mySQLConnection);

		// If the query succeeded, no need to re-attempt.
		if (!queryStatus) {
			theErrorMessage = nil;
			theErrorID = 0;
			theSqlstate = nil;
			break;

		// If the query failed, determine whether to reattempt the query
		} else {

			// Store the error state
			theErrorMessage = [self _stringForCString:mysql_error(mySQLConnection)];
			theErrorID = mysql_errno(mySQLConnection);
			// sqlstate is always an ASCII string, regardless of charset (but use latin1 anyway as that is less picky about invalid bytes)
			theSqlstate = _stringForCStringWithEncoding(mysql_sqlstate(mySQLConnection), NSISOLatin1StringEncoding);

			// Prevent retries if the query was cancelled or not a connection error
			if (lastQueryWasCancelled || ![SPMySQLConnection isErrorIDConnectionError:theErrorID]) {
				break;
			}
		}

		// Query has failed - check the connection
		[self _unlockConnection];
		if (![self checkConnection]) {
			[self _updateLastErrorMessage:theErrorMessage];
			[self _updateLastErrorID:theErrorID];
			[self _updateLastSqlstate:theSqlstate];
			return nil;
		}
		[self _lockConnection];
		NSAssert(mySQLConnection != NULL, @"mySQLConnection has disappeared while checking it!");

	} while (--queryAttemptsAllowed > 0);

	id theResult = nil;

	// On success, if there is a query result, retrieve the result data type
	if (!queryStatus) {
		if (mysql_field_count(mySQLConnection)) {
			MYSQL_RES *mysqlResult;

			switch (theReturnType) {

				// For standard result sets, retrieve all the results now, and afterwards
				// update the affected row count.
				case SPMySQLResultAsResult:
					mysqlResult = mysql_store_result(mySQLConnection);
					theResult = [[SPMySQLResult alloc] initWithMySQLResult:mysqlResult stringEncoding:theEncoding];
					theAffectedRowCount = mysql_affected_rows(mySQLConnection);
					break;

				// For fast streaming and low memory streaming result sets, set up the result
				case SPMySQLResultAsLowMemStreamingResult:
					mysqlResult = mysql_use_result(mySQLConnection);
					theResult = [[SPMySQLStreamingResult alloc] initWithMySQLResult:mysqlResult stringEncoding:theEncoding connection:self];
					break;

				case SPMySQLResultAsFastStreamingResult:
					mysqlResult = mysql_use_result(mySQLConnection);
					theResult = [[SPMySQLFastStreamingResult alloc] initWithMySQLResult:mysqlResult stringEncoding:theEncoding connection:self];
					break;

				// Also set up the result for streaming result data stores, but note the data download does not start yet
				case SPMySQLResultAsStreamingResultStore:
					mysqlResult = mysql_use_result(mySQLConnection);
					theResult = [[SPMySQLStreamingResultStore alloc] initWithMySQLResult:mysqlResult stringEncoding:theEncoding connection:self];
					break;
			}

			// Update the error message, if appropriate, to reflect result store errors or overall success
			theErrorMessage = [self _stringForCString:mysql_error(mySQLConnection)];
			theErrorID = mysql_errno(mySQLConnection);
			// sqlstate is always an ASCII string, regardless of charset (but use latin1 anyway as that is less picky about invalid bytes)
			theSqlstate = _stringForCStringWithEncoding(mysql_sqlstate(mySQLConnection), NSISOLatin1StringEncoding);
		} else {
			theResult = [[SPMySQLEmptyResult alloc] init];
		}
	}

	// Update the connection's stored insert ID if available
	if (mySQLConnection->insert_id) {
		lastQueryInsertID = mySQLConnection->insert_id;
	}

	// If the query was cancelled, override the error state
	if (lastQueryWasCancelled) {
		theErrorMessage = NSLocalizedString(@"Query cancelled.", @"Query cancelled error");
		theErrorID = 1317;
		theSqlstate = @"70100";

		// If the query was cancelled on a MySQL <5 server, check the connection to allow reconnects
		// after query kills.  This is also handled within the class for internal cancellations, but
		// as other external classes may also cancel the query.
		if (![self serverVersionIsGreaterThanOrEqualTo:5 minorVersion:0 releaseVersion:0]) {
			[self _unlockConnection];
			[self checkConnection];
		}
	}

	// Unlock the connection if appropriate - if not a streaming result type.
	if (![theResult isKindOfClass:[SPMySQLStreamingResult class]]) {
		[self _tryLockConnection];
		[self _unlockConnection];

		// Also perform restore if appropriate
		if (queryActionShouldRestoreMaxQuerySize != NSNotFound) {
			[self _restoreMaximumQuerySizeAfterQuery];
		}
	}

	// Update error string and ID, and the rows affected
	[self _updateLastErrorMessage:theErrorMessage];
	[self _updateLastErrorID:theErrorID];
	[self _updateLastSqlstate:theSqlstate];
	lastQueryAffectedRowCount = theAffectedRowCount;

	// Store the result time on the response object
	[theResult _setQueryExecutionTime:queryExecutionTime];

	return [theResult autorelease];
}

#pragma mark -
#pragma mark Query convenience functions

/**
 * Run a query and retrieve the entire result set as an array of dictionaries.
 * Returns nil if there was a problem running the query or retrieving any results.
 */
- (NSArray *)getAllRowsFromQuery:(NSString *)theQueryString
{
	return [[self queryString:theQueryString] getAllRows];
}

/**
 * Run a query and retrieve the first field of any response.  Returns nil if there
 * was a problem running the query or retrieving any results.
 */
- (id)getFirstFieldFromQuery:(NSString *)theQueryString
{
	return [[[self queryString:theQueryString] getRowAsArray] objectAtIndex:0];
}

#pragma mark -
#pragma mark Query information

/**
 * Returns the number of rows changed, deleted, inserted, or selected by
 * the last query.
 */
- (unsigned long long)rowsAffectedByLastQuery
{
	return lastQueryAffectedRowCount;
}

/**
 * Returns the insert ID for the previous query which inserted a row.  Note that
 * this value persists through other SELECT/UPDATE etc queries.
 */
- (unsigned long long)lastInsertID
{
	return lastQueryInsertID;
}

#pragma mark -
#pragma mark Retrieving connection and query error state

/**
 * Return whether the last query errored or not.
 */
- (BOOL)queryErrored
{
	return (queryErrorMessage)?YES:NO;
}

/**
 * If the last query (or connection) triggered an error, returns the error
 * message as a string; if the last query did not error, nil is returned.
 */
- (NSString *)lastErrorMessage
{
	if (!queryErrorMessage) return nil;
	return [NSString stringWithString:queryErrorMessage];
}

- (NSString *)lastSqlstate
{
	if(!querySqlstate) return nil;
	return [NSString stringWithString:querySqlstate];
}

/**
 * If the last query (or connection) triggered an error, returns the error
 * ID; if the last query did not error, 0 is returned.
 */
- (NSUInteger)lastErrorID
{
	return queryErrorID;
}

/**
 * Determines whether a supplied error ID can be classed as a connection error.
 */
+ (BOOL)isErrorIDConnectionError:(NSUInteger)theErrorID
{
	switch (theErrorID) {
		case 2001: // CR_SOCKET_CREATE_ERROR
		case 2002: // CR_CONNECTION_ERROR
		case 2003: // CR_CONN_HOST_ERROR
		case 2004: // CR_IPSOCK_ERROR
		case 2005: // CR_UNKNOWN_HOST
		case 2006: // CR_SERVER_GONE_ERROR
		case 2007: // CR_VERSION_ERROR
		case 2009: // CR_WRONG_HOST_INFO
		case 2012: // CR_SERVER_HANDSHAKE_ERR
		case 2013: // CR_SERVER_LOST
		case 2027: // CR_MALFORMED_PACKET
		case 2032: // CR_DATA_TRUNCATED
		case 2047: // CR_CONN_UNKNOW_PROTOCOL
		case 2048: // CR_INVALID_CONN_HANDLE
		case 2050: // CR_FETCH_CANCELED
		case 2055: // CR_SERVER_LOST_EXTENDED
			return YES;
	}

	return NO;
}	

#pragma mark -
#pragma mark Query cancellation

/**
 * Cancel the currently running query.  This tries to kill the current query,
 * and if that isn't possible - for example, on MySQL < 5 or if the current user
 * does not have the relevant permissions - resets the connection.
 */
- (void)cancelCurrentQuery
{

	// If not connected, no action is required
	if (state != SPMySQLConnected && state != SPMySQLDisconnecting) return;

	// Check whether a query is actually being performed - if not, return
	if ([self _tryLockConnection]) {
		[self _unlockConnection];
		return;
	}

	// Mark that the last query was cancelled to prevent query retries from occurring
	lastQueryWasCancelled = YES;

	// The query cancellation cannot occur on the connection actively running a query
	// so set up a new connection to run the KILL command.
	MYSQL *killerConnection = [self _makeRawMySQLConnectionWithEncoding:@"utf8" isMasterConnection:NO];

	// If the new connection was successfully set up, use it to run a KILL command.
	if (killerConnection) {
		NSStringEncoding aStringEncoding = [SPMySQLConnection stringEncodingForMySQLCharset:mysql_character_set_name(killerConnection)];
		BOOL killQuerySupported = [self serverVersionIsGreaterThanOrEqualTo:5 minorVersion:0 releaseVersion:0];

		// Build the kill query
		NSMutableString *killQuery = [NSMutableString stringWithString:@"KILL"];
		if (killQuerySupported) [killQuery appendString:@" QUERY"];
		[killQuery appendFormat:@" %lu", mySQLConnection->thread_id];

		// Convert to a C string
		NSUInteger killQueryCStringLength;
		const char *killQueryCString = [SPMySQLConnection _cStringForString:killQuery usingEncoding:aStringEncoding returningLengthAs:&killQueryCStringLength];

		// Run the query
		int killQueryStatus = mysql_real_query(killerConnection, killQueryCString, killQueryCStringLength);

		// Close the temporary connection
		mysql_close(killerConnection);

		// If the kill query succeeded, the active query was cancelled.
		if (killQueryStatus == 0) {

			// On MySQL < 5, the entire connection will have been reset.  Ensure it's
			// restored.
			if (!killQuerySupported) {
				[self checkConnection];
				lastQueryWasCancelledUsingReconnect = YES;
			} else {
				lastQueryWasCancelledUsingReconnect = NO;
			}

			// Ensure the tracking bool is re-set to cover encompassed queries and return
			lastQueryWasCancelled = YES;
			return;
		} else {
			NSLog(@"SPMySQL Framework: query cancellation failed due to cancellation query error (status %d)", killQueryStatus);
		}
	} else if (!userTriggeredDisconnect) {
		NSLog(@"SPMySQL Framework: query cancellation failed because connection failed");
	}

	// A full reconnect is required at this point to force a cancellation.  As the
	// connection may have finished processing the query at this point (depending how
	// long the connection attempt took), check whether we can skip the reconnect.
	if ([self _tryLockConnection]) {
		[self _unlockConnection];
		return;
	}

	if (state == SPMySQLDisconnecting || state == SPMySQLDisconnected) return;

	// Reset the connection with a reconnect.  Unlock the connection beforehand,
	// to allow the reconnect, but lock it again afterwards to restore the expected
	// state (query execution process should unlock as appropriate).
	[self _unlockConnection];
	[self _reconnectAllowingRetries:YES];
	[self _lockConnection];

	// Reset tracking bools to cover encompassed queries
	lastQueryWasCancelled = YES;
	lastQueryWasCancelledUsingReconnect = YES;
}

/**
 * If the last query was cancelled, returns whether that query cancellation
 * required the connection to be reset or whether the query was successfully
 * cancelled leaving the connection intact.
 * If the last query was not cancelled, this will return NO.
 */
- (BOOL)lastQueryWasCancelledUsingReconnect
{
	return lastQueryWasCancelledUsingReconnect;
}

@end

#pragma mark -
#pragma mark Private API

@implementation SPMySQLConnection (Querying_and_Preparation_Private_API)

/**
 * Retrieves all remaining results and discards them.
 * This is necessary to correctly process multiple result sets on the connection - as
 * we currently don't fully support multiple result, this at least allows the connection
 * to function after running statements with multiple result sets.
 */
- (void)_flushMultipleResultSets
{

	// Repeat as long as there are results
	while (!mysql_next_result(mySQLConnection)) {
		MYSQL_RES *eachResult = mysql_use_result(mySQLConnection);

		// Ensure the result is really a result
		if (eachResult) {

			// Retrieve and discard all rows
			while (mysql_fetch_row(eachResult));

			// Free the result set
			mysql_free_result(eachResult);
		}
	}
}

/**
 * Update lastErrorID, lastErrorMessage and lastSqlstate from connection
 */
- (void)_updateLastErrorInfos
{
	[self _updateLastErrorID:NSNotFound];
	[self _updateLastErrorMessage:nil];
	[self _updateLastSqlstate:nil];
}

/**
 * Update the MySQL error message for this connection.  If an error is supplied
 * it will be stored and returned to anything asking the instance for the last
 * error; if no error is supplied, the connection will be used to derive (or clear)
 * the error string.
 */
- (void)_updateLastErrorMessage:(NSString *)theErrorMessage
{

	// If an error message wasn't supplied, select one from the connection
	if (!theErrorMessage) {
		theErrorMessage = [self _stringForCString:mysql_error(mySQLConnection)];
	}

	// Clear the last error message stored on the instance
	if (queryErrorMessage) [queryErrorMessage release], queryErrorMessage = nil;

	// If we have an error message *with a length*, update the instance error message
	if (theErrorMessage && [theErrorMessage length]) {
		queryErrorMessage = [[NSString alloc] initWithString:theErrorMessage];
	}
}

/**
 * Update the MySQL error ID for this connection.  If an error ID is supplied,
 * it will be stored and returned to anything asking the instance for the last
 * error; if an NSNotFound error ID is supplied, the connection will be used to
 * set the error ID.  Note that an error ID of 0 corresponds to no error.
 */
- (void)_updateLastErrorID:(NSUInteger)theErrorID
{

	// If NSNotFound was supplied as the ID, ask the connection for the last error
	if (theErrorID == NSNotFound) {
		queryErrorID = mysql_errno(mySQLConnection);

	// Otherwise, update the error ID with the supplied ID
	} else {
		queryErrorID = theErrorID;
	}
}

/**
 * Update the MySQL SQLSTATE for this connection.
 * @param thSqlstate If a SQLSTATE is supplied it will be stored and returned to 
 *                   anything asking the instance for the last SQLSTATE; 
 *                   if nil is supplied, the connection will be used to derive
 *                   (or clear) the SQLSTATE string; 
 *                   if @"" is supplied the SQLSTATE will only be cleared.
 */
- (void)_updateLastSqlstate:(NSString *)theSqlstate
{
	// If a SQLSTATE wasn't supplied, select one from the connection
	if(!theSqlstate) {
		// sqlstate is always an ASCII string, regardless of charset (but use latin1 anyway as that is less picky about invalid bytes)
		theSqlstate = _stringForCStringWithEncoding(mysql_sqlstate(mySQLConnection), NSISOLatin1StringEncoding);
	}

	// Clear the last SQLSTATE stored on the instance
	if(querySqlstate) [querySqlstate release], querySqlstate = nil;

	// If we have a SQLSTATE *with a length*, update the instance SQLSTATE
	if(theSqlstate && [theSqlstate length]) {
		querySqlstate = [[NSString alloc] initWithString:theSqlstate];
	}
}

@end
