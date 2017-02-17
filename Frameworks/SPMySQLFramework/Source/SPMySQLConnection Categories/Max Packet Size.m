//
//  Max Packet Size.m
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
//  More info at <https://github.com/sequelpro/sequelpro>


#import "Max Packet Size.h"
#import "SPMySQL Private APIs.h"

@implementation SPMySQLConnection (Max_Packet_Size)

/**
 * Retrieve the current maximum query size (MySQL's max_allowed_packet), as cached
 * by the class.  If the connection has been unable to retrieve this value, the
 * default of 1MB will be returned.
 */
- (NSUInteger)maxQuerySize
{
	return maxQuerySize;
}

/**
 * Retrieve whether the server's maximum query size (MySQL's max_allowed_packet) is
 * editable by the current user.
 */
- (BOOL)isMaxQuerySizeEditable
{
	if (!maxQuerySizeEditabilityChecked) {
		[self _updateMaxQuerySizeEditability];
	}

	return maxQuerySizeIsEditable;
}

/**
 * Set the servers's global maximum query size - MySQL's max_allowed_packed - to the
 * supplied size.  Note that this *does not* affect the current connection; a reconnection
 * is required to pick up the new size setting.  As a result it may be important to restore
 * the connection size after use.
 * Validates the supplied size (eg 1GB limit) and applies it if appropriate, returning
 * the set query size or NSNotFound on error.
 */
- (NSUInteger)setGlobalMaxQuerySize:(NSUInteger)newMaxSize
{

	// Perform basic validation.  First, ensure the max query size is editable
	if (![self isMaxQuerySizeEditable]) return NSNotFound;

	// Validate sizes
	if (newMaxSize < 1024) return NSNotFound;
	if (newMaxSize > (1024 * 1024 * 1024)) newMaxSize = 1024 * 1024 * 1024;

	// Perform a standard query to set the new size
	[self queryString:[NSString stringWithFormat:@"SET GLOBAL max_allowed_packet = %lu", (unsigned long)newMaxSize]];

	// On failure, return NSNotFound - error state will have automatically been set
	if ([self queryErrored]) return NSNotFound;

	// Otherwise, set the local instance variable and return success
	maxQuerySize = newMaxSize;
	return maxQuerySize;
}

@end

#pragma mark -

@implementation SPMySQLConnection (Max_Packet_Size_Private_API)

/**
 * Executes a passed query for max_allowed_packet and returns the resulting number in bytes
 *
 * @return -1 => if the query failed
 *          0 => if the query did not fail, but also did not contain a (valid) result
 *          * => if the query succeeded and the value is a valid integer (NOTE: this may also include -1 and 0)
 */
- (NSInteger)_queryMaxAllowedPacketWithSQL:(NSString *)query resultInColumn:(NSUInteger)colIdx
{
	// Make a standard query to the server to retrieve the information
	SPMySQLResult *result = [self queryString:query];
	if(!result) {
		NSLog(@"Query (%@) for max_allowed_packet failed: %@ (%lu) (on %@)", query, [self lastErrorMessage], [self lastErrorID], [self serverVersionString]);
		return -1;
	}
	[result setReturnDataAsStrings:YES];

	// Get the maximum size string
	NSString *maxQuerySizeString = [[result getRowAsArray] objectAtIndex:colIdx];

	NSInteger _maxQuerySize = maxQuerySizeString ? [maxQuerySizeString integerValue] : 0;

	if(_maxQuerySize == 0)
		NSLog(@"Query (%@) for max_allowed_packet returned invalid value: %ld (raw value: %@) (on %@)", query, _maxQuerySize, maxQuerySizeString, [self serverVersionString]);

	return _maxQuerySize;
}

/**
 * Update the max_allowed_packet size - the largest supported query size - from the server.
 */
- (void)_updateMaxQuerySize
{
	struct {
		NSString *sql;
		NSUInteger col;
	} queryVariants[] = {
		{ .sql = @"SELECT @@global.max_allowed_packet",       .col = 0 }, //works on mysql 4+
		{ .sql = @"SHOW VARIABLES LIKE 'max_allowed_packet'", .col = 1 }, //works on mysql 3, sphinx
		{ .sql = nil,                                         .col = 0 }, //terminator element
	};
	
	int i = 0;
	while(queryVariants[i].sql) {
		NSInteger _maxQuerySize = [self _queryMaxAllowedPacketWithSQL:queryVariants[i].sql resultInColumn:queryVariants[i].col];
		//see #2653
		if(_maxQuerySize >= 34) { // the max_allowed_packet query above has at least 34 bytes, so any value less than that would be nonsense
			// If a valid size was returned, update the instance variable
			maxQuerySize = (NSUInteger)_maxQuerySize;
			return;
		}
		i++;
	}
}

/**
 * Perform a query to determine whether the current user has permission to edit the
 * max_allowed_packet setting for their connection.
 */
- (void)_updateMaxQuerySizeEditability
{
	[self queryString:@"SET GLOBAL max_allowed_packet = @@global.max_allowed_packet"];
	maxQuerySizeIsEditable = ![self queryErrored];
	maxQuerySizeEditabilityChecked = YES;
}

/**
 * Attempts to change the maximum query size in order to allow a query to be performed.
 * Returns whether the change was successfully made.
 */
- (BOOL)_attemptMaxQuerySizeIncreaseTo:(NSUInteger)targetSize
{

	// If the query size is editable, attempt to increase the size
	if ([self isMaxQuerySizeEditable]) {
		NSUInteger newSize = [self setGlobalMaxQuerySize:targetSize];
		if (newSize != NSNotFound) {

			// Successfully increased the global size - reconnect to use it, and return success
			[self _reconnectAllowingRetries:YES];
			return YES;
		}
	}

	// Can not, or failed to, increase the max query size.  Record an error message.
	NSString *errorMessage = [NSString stringWithFormat:NSLocalizedString(@"The query length of %lu bytes is larger than max_allowed_packet size (%lu).", @"error message if max_allowed_packet < query size"), targetSize, maxQuerySize];
	[self _updateLastErrorMessage:errorMessage];

	// Update delegate error if it supports the protocol
	if ([delegate respondsToSelector:@selector(queryGaveError:connection:)]) {
		[delegate queryGaveError:errorMessage connection:self];
	}

	// Display an alert as this is a special failure
	if ([delegate respondsToSelector:@selector(showErrorWithTitle:message:)]) {
		[delegate showErrorWithTitle:NSLocalizedString(@"Error", @"error") message:errorMessage];
	} else {
		NSRunAlertPanel(NSLocalizedString(@"Error", @"error"), @"%@", @"OK", nil, nil, errorMessage);
	}

	return NO;
}

/**
 * Restore a maximum query size after temporarily increasing it for a query.  This action
 * may be called directly after a query, or may be before the next query if a streaming result
 * had to be used.
 */
- (void)_restoreMaximumQuerySizeAfterQuery
{

	// Return if no action needs to be performed
	if (queryActionShouldRestoreMaxQuerySize == NSNotFound) return;

	// Move the target size to a local variable to prevent looping
	NSUInteger targetMaxQuerySize = queryActionShouldRestoreMaxQuerySize;
	queryActionShouldRestoreMaxQuerySize = NSNotFound;

	// Enact the change
	[self setGlobalMaxQuerySize:targetMaxQuerySize];
}

@end
