//
//  SPDatabaseStructure.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on March 25, 2010.
//  Copyright (c) 2010 Hans-Jörg Bibiko. All rights reserved.
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

#import "SPDatabaseStructure.h"
#import "SPDatabaseDocument.h"
#import "SPTablesList.h"
#import "RegexKitLite.h"
#import "SPThreadAdditions.h"

#import <pthread.h>

@interface SPDatabaseStructure ()

- (void)_destroy:(NSNotification *)notification;

- (void)_updateGlobalVariablesWithStructure:(NSDictionary *)aStructure keys:(NSArray *)theKeys;
- (void)_cloneConnectionFromConnection:(SPMySQLConnection *)aConnection;
- (BOOL)_ensureConnectionUnsafe; // Use _checkConnection instead, where possible

- (void)_addToListAndWaitForFrontCancellingOtherThreads:(BOOL)killOthers;
- (void)_removeThreadFromList;
- (void)_cancelAllThreadsAndWait;
- (BOOL)_checkConnection;

@end

#pragma mark -

@implementation SPDatabaseStructure

#pragma mark -
#pragma mark Setup and teardown

/**
 * Prevent SPDatabaseStructure from being init'd normally.
 */
- (id)init
{
	[NSException raise:NSInternalInconsistencyException format:@"SPDatabaseStructures should not be init'd directly; use initWithDelegate: instead."];
	return nil;
}

/**
 * Standard init method, constructing the SPDatabaseStructure around a SPMySQL
 * connection pointer and a delegate.
 */
- (id)initWithDelegate:(SPDatabaseDocument *)theDelegate
{
	if ((self = [super init])) {

		// Keep a weak reference to the delegate
		delegate = theDelegate;

		// Start with no root connection
		mySQLConnection = nil;

		// Set up empty structure and keys storage
		structureRetrievalThreads = [[NSMutableArray alloc] init];
		structure = [[NSMutableDictionary alloc] initWithCapacity:1];
		allKeysofDbStructure = [[NSMutableArray alloc] initWithCapacity:20];

		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(_destroy:)
		                                             name:SPDocumentWillCloseNotification
		                                           object:delegate];

		// Set up the connection, thread management and data locks
		pthread_mutex_init(&threadManagementLock, NULL);
		pthread_mutex_init(&dataLock, NULL);
		pthread_mutex_init(&connectionCheckLock, NULL);
	}

	return self;
}

/**
 * Rather than supplying a connection to SPDatabaseStructure, the class instead
 * will set up its own connection to allow background querying.  The supplied
 * connection will be used to look up details for the clone process.
 */
- (void)setConnectionToClone:(SPMySQLConnection *)aConnection
{
	// Perform the task in a background thread to avoid blocking the UI
	[NSThread detachNewThreadWithName:SPCtxt(@"SPDatabaseStructure clone connection task",delegate)
							   target:self 
							 selector:@selector(_cloneConnectionFromConnection:) 
							   object:aConnection];
}

#pragma mark -
#pragma mark Information

- (SPMySQLConnection *)connection
{
	// this much is needed to make the accessor atomic and thread-safe
	pthread_mutex_lock(&connectionCheckLock);
	SPMySQLConnection *c = [mySQLConnection retain];
	pthread_mutex_unlock(&connectionCheckLock);
	return [c autorelease];
}

- (SPDatabaseDocument *)delegate
{
	return delegate;
}

#pragma mark -
#pragma mark Structure retrieval from the server

- (void)queryDbStructureInBackgroundWithUserInfo:(NSDictionary *)userInfo
{
	[NSThread detachNewThreadWithName:SPCtxt(@"SPNavigatorController database structure querier", delegate)
							   target:self
							 selector:@selector(queryDbStructureWithUserInfo:)
							   object:userInfo];
}

/**
 * Updates the dict containing the structure of all available databases (mainly for completion/navigator)
 * executed on the helper connection.
 * Should always be executed on a background thread.
 */
- (void)queryDbStructureWithUserInfo:(NSDictionary *)userInfo
{
	@autoreleasepool {
		BOOL structureWasUpdated = NO;

		[self _addToListAndWaitForFrontCancellingOtherThreads:[[userInfo objectForKey:@"cancelQuerying"] boolValue]];
		if([[NSThread currentThread] isCancelled]) goto cleanup_thread_and_pool;

		// This thread is now first on the stack, and about to process the structure.
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SPDBStructureIsUpdating" object:self];

		NSString *connectionID = ([delegate respondsToSelector:@selector(connectionID)])? [NSString stringWithString:[delegate connectionID]] : @"_";

		// Re-init with already cached data from navigator controller
		NSMutableDictionary *queriedStructure = [NSMutableDictionary dictionary];
		NSDictionary *dbstructure = [delegate getDbStructure];
		if (dbstructure) [queriedStructure setDictionary:[NSMutableDictionary dictionaryWithDictionary:dbstructure]];

		NSMutableArray *queriedStructureKeys = [NSMutableArray array];
		NSArray *dbStructureKeys = [delegate allSchemaKeys];
		if (dbStructureKeys) [queriedStructureKeys setArray:dbStructureKeys];

		// Retrieve all the databases known of by the delegate
		NSMutableArray *connectionDatabases = [NSMutableArray array];
		[connectionDatabases addObjectsFromArray:[delegate allSystemDatabaseNames]];
		[connectionDatabases addObjectsFromArray:[delegate allDatabaseNames]];

		// Add all known databases coming from connection if they aren't parsed yet
		for (id db in connectionDatabases) {
			NSString *dbid = [NSString stringWithFormat:@"%@%@%@", connectionID, SPUniqueSchemaDelimiter, db];
			if(![queriedStructure objectForKey:dbid]) {
				structureWasUpdated = YES;
				[queriedStructure setObject:db forKey:dbid];
				[queriedStructureKeys addObject:dbid];
			}
		}

		// Check the existing databases in the 'structure' and 'allKeysOfDbStructure' stores,
		// and remove any that are no longer found in the connectionDatabases list (indicating deletion).
		// Iterate through extracted keys to avoid <NSCFDictionary> mutation while being enumerated.
		NSArray *keys = [queriedStructure allKeys];
		for(id key in keys) {
			NSString *db = [[key componentsSeparatedByString:SPUniqueSchemaDelimiter] objectAtIndex:1];
			if(![connectionDatabases containsObject:db]) {
				structureWasUpdated = YES;
				[queriedStructure removeObjectForKey:key];
				NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT SELF BEGINSWITH %@", [NSString stringWithFormat:@"%@%@", key, SPUniqueSchemaDelimiter]];
				[queriedStructureKeys filterUsingPredicate:predicate];
				[queriedStructureKeys removeObject:key];
			}
		}

		NSString *currentDatabase = ([delegate respondsToSelector:@selector(database)])? [delegate database] : nil;

		// Determine whether the database details need to be queried.
		BOOL shouldQueryStructure = YES;
		NSString *db_id = nil;

		// If no database is selected, no need to check further
		if(![currentDatabase length]) {
			shouldQueryStructure = NO;
		}
		// Otherwise, build up the schema key for the database to be retrieved.
		else {
			db_id = [NSString stringWithFormat:@"%@%@%@", connectionID, SPUniqueSchemaDelimiter, currentDatabase];

			// Check to see if a cache already exists for the database.
			if ([[queriedStructure objectForKey:db_id] isKindOfClass:[NSDictionary class]]) {

				// The cache is available. If the `mysql` or `information_schema` databases are being queried,
				// never requery as their structure will never change.
				// 5.5.3+ also has performance_schema meta database
				if ([currentDatabase isInArray:@[@"mysql",@"information_schema",@"performance_schema"]]) {
					shouldQueryStructure = NO;
				}
				// Otherwise, if the forceUpdate flag wasn't supplied or evaluates to false, also don't update.
				else if (![[userInfo objectForKey:@"forceUpdate"] boolValue]) {
					shouldQueryStructure = NO;
				}
			}
		}

		// If it has been determined that no new structure needs to be retrieved, clean up and return.
		if (!shouldQueryStructure) {
			goto update_globals_and_cleanup;
		}

		// Retrieve the tables and views for this database from SPTablesList
		NSMutableArray *tablesAndViews = [NSMutableArray array];
		for (id aTable in [[delegate valueForKeyPath:@"tablesListInstance"] allTableNames]) {
			NSDictionary *aTableDict = [NSDictionary dictionaryWithObjectsAndKeys:
				aTable, @"name",
				@(SPTableTypeTable), @"type",
					nil];
			[tablesAndViews addObject:aTableDict];
		}
		for (id aView in [[delegate valueForKeyPath:@"tablesListInstance"] allViewNames]) {
			NSDictionary *aViewDict = [NSDictionary dictionaryWithObjectsAndKeys:
				aView, @"name",
				@(SPTableTypeView), @"type",
					nil];
			[tablesAndViews addObject:aViewDict];
		}

		// Do not parse more than 2000 tables/views per db
		if ([tablesAndViews count] > 2000) {
			NSLog(@"%lu items in database %@. Only 2000 items can be parsed. Stopped parsing.", (unsigned long)[tablesAndViews count], currentDatabase);

			goto cleanup_thread_and_pool;
		}

#if 0
		// For future usage - currently unused
		// If the affected item name and type - for example, table type and table name - were supplied, extract it.
		NSString *affectedItem = nil;
		NSInteger affectedItemType = -1;
		if([userInfo objectForKey:@"affectedItem"]) {
			affectedItem = [userInfo objectForKey:@"affectedItem"];
			if([userInfo objectForKey:@"affectedItemType"])
				affectedItemType = [[userInfo objectForKey:@"affectedItemType"] intValue];
			else
				affectedItem = nil;
		}
#endif

		// Delete all stored data for the database to be updated, leaving the structure key
		[queriedStructure removeObjectForKey:db_id];
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT SELF BEGINSWITH %@", [NSString stringWithFormat:@"%@%@", db_id, SPUniqueSchemaDelimiter]];
		[queriedStructureKeys filterUsingPredicate:predicate];

		// Set up the database as an empty mutable dictionary ready for tables, and store a reference
		[queriedStructure setObject:[NSMutableDictionary dictionary] forKey:db_id];
		NSMutableDictionary *databaseStructure = [queriedStructure objectForKey:db_id];
		structureWasUpdated = YES;

		NSUInteger uniqueCounter = 0; // used to make field data unique
		SPMySQLResult *theResult;

		// Loop through the known tables and views, retrieving details for each
		for (NSDictionary *aTableDict in tablesAndViews) {

			// Extract the name
			NSString *aTableName = [aTableDict objectForKey:@"name"];

			if(![aTableName isKindOfClass:[NSString class]] || ![aTableName length]) continue;

			// check the connection.
			// also NO if thread is cancelled which is fine, too (same consequence).
			if(![self _checkConnection]) {
				goto cleanup_thread_and_pool;
			}

			// Retrieve the column details
			theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW FULL COLUMNS FROM %@ FROM %@", [aTableName backtickQuotedString], [currentDatabase backtickQuotedString]]];
			if (!theResult) {
				continue;
			}
			[theResult setDefaultRowReturnType:SPMySQLResultRowAsArray];
			[theResult setReturnDataAsStrings:YES];

			// Add a structure key for this table
			NSString *table_id = [NSString stringWithFormat:@"%@%@%@", db_id, SPUniqueSchemaDelimiter, aTableName];
			[queriedStructureKeys addObject:table_id];

			// Add a mutable dictionary to the structure and store a reference
			NSMutableDictionary *tableStructure = [NSMutableDictionary dictionary];
			[databaseStructure setObject:tableStructure forKey:table_id];

			// Loop through the fields, extracting details for each
			for (NSArray *row in theResult) {
				NSString *field = [row objectAtIndex:0];
				NSString *type = [row objectAtIndex:1];
				NSString *type_display = [type stringByReplacingOccurrencesOfRegex:@"\\(.*?,.*?\\)" withString:@"(…)"];
				NSString *collation = [row objectAtIndex:2];
				NSString *isnull = [row objectAtIndex:3];
				NSString *key = [row objectAtIndex:4];
				NSString *def = [row objectAtIndex:5];
				NSString *extra = [row objectAtIndex:6];
				NSString *priv = @"";
				NSString *comment = @"";
				if ([row count] > 7) priv = [row objectAtIndex:7];
				if ([row count] > 8) comment = [row objectAtIndex:8];

				NSString *charset = @"";
				if (![collation isNSNull]) {
					NSArray *a = [collation componentsSeparatedByString:@"_"];
					charset = [a objectAtIndex:0];
				}

				// Add a structure key for this field
				NSString *field_id = [NSString stringWithFormat:@"%@%@%@", table_id, SPUniqueSchemaDelimiter, field];
				[queriedStructureKeys addObject:field_id];

				[tableStructure setObject:[NSArray arrayWithObjects:type, def, isnull, charset, collation, key, extra, priv, comment, type_display, [NSNumber numberWithUnsignedLongLong:uniqueCounter], nil] forKey:field_id];
				[tableStructure setObject:[aTableDict objectForKey:@"type"] forKey:@"  struct_type  "];
				uniqueCounter++;
			}

			// Allow a tiny pause between iterations
			usleep(10);
		}

		// If the MySQL version is higher than 5, also retrieve function/procedure details via the information_schema table
		if ([mySQLConnection serverMajorVersion] >= 5) {
			// check the connection.
			// also NO if thread is cancelled which is fine, too (same consequence).
			if(![self _checkConnection]) {
				goto cleanup_thread_and_pool;
			}

			// Retrieve the column details (only those we need so we don't fetch the whole function body which might be huge)
			theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SELECT SPECIFIC_NAME, ROUTINE_TYPE, DTD_IDENTIFIER, IS_DETERMINISTIC, SQL_DATA_ACCESS, SECURITY_TYPE, DEFINER FROM `information_schema`.`ROUTINES` WHERE `ROUTINE_SCHEMA` = %@", [currentDatabase tickQuotedString]]];
			[theResult setReturnDataAsStrings:YES]; //TODO workaround for #2700 with mysql 8.0 (see #2699)
			[theResult setDefaultRowReturnType:SPMySQLResultRowAsArray];

			// Loop through the rows and extract the function details
			for (NSArray *row in theResult) {
				NSString *fname         =   [row objectAtIndex:0];
				NSNumber *type          = ([[row objectAtIndex:1] isEqualToString:@"FUNCTION"]) ? @(SPTableTypeFunc) : @(SPTableTypeProc);
				NSString *dtd           =   [row objectAtIndex:2];
				NSString *det           =   [row objectAtIndex:3];
				NSString *dataaccess    =   [row objectAtIndex:4];
				NSString *security_type =   [row objectAtIndex:5];
				NSString *definer       =   [row objectAtIndex:6];

				// Generate "table" and "field" names and add to structure key store
				NSString *table_id = [NSString stringWithFormat:@"%@%@%@", db_id, SPUniqueSchemaDelimiter, fname];
				NSString *field_id = [NSString stringWithFormat:@"%@%@%@", table_id, SPUniqueSchemaDelimiter, fname];
				[queriedStructureKeys addObject:table_id];
				[queriedStructureKeys addObject:field_id];

				// Ensure that a dictionary exists for this "table" name
				if(![[queriedStructure valueForKey:db_id] valueForKey:table_id]) {
					[[queriedStructure valueForKey:db_id] setObject:[NSMutableDictionary dictionary] forKey:table_id];
				}

				// Add the "field" details
				[[[queriedStructure valueForKey:db_id] valueForKey:table_id] setObject:
					[NSArray arrayWithObjects:dtd, dataaccess, det, security_type, definer, [NSNumber numberWithUnsignedLongLong:uniqueCounter], nil] forKey:field_id];
				[[[queriedStructure valueForKey:db_id] valueForKey:table_id] setObject:type forKey:@"  struct_type  "];
				uniqueCounter++;
			}
		}

update_globals_and_cleanup:
		// Update the global variables
		[self _updateGlobalVariablesWithStructure:queriedStructure keys:queriedStructureKeys];

		if(structureWasUpdated) {
			// Notify that the structure querying has been performed
			[[NSNotificationCenter defaultCenter] postNotificationName:@"SPDBStructureWasUpdated" object:self];
		}

cleanup_thread_and_pool:
		// Remove this thread from the processing stack
		[self _removeThreadFromList];
	}
}

- (BOOL)isQueryingDatabaseStructure
{
	pthread_mutex_lock(&threadManagementLock);
	BOOL returnValue = ([structureRetrievalThreads count] > 0);
	pthread_mutex_unlock(&threadManagementLock);

	return returnValue;
}

#pragma mark -
#pragma mark Structure information

/**
 * Returns a dict containing the structure of all available databases
 */
- (NSDictionary *)structure
{
	pthread_mutex_lock(&dataLock);
	NSDictionary *d = [NSDictionary dictionaryWithDictionary:structure];
	pthread_mutex_unlock(&dataLock);

	return d;
}

/**
 * Returns all keys of the db structure
 */
- (NSArray *)allStructureKeys
{
	pthread_mutex_lock(&dataLock);
	NSArray *r = [NSArray arrayWithArray:allKeysofDbStructure];
	pthread_mutex_unlock(&dataLock);

	return r;
}

#pragma mark -
#pragma mark SPMySQLConnection delegate methods

/**
 * Forward keychain password requests to the database object.
 */
- (NSString *)keychainPasswordForConnection:(id)connection
{
	return [delegate keychainPasswordForConnection:connection];
}

#pragma mark -

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[self _destroy:nil];
	SPClear(structureRetrievalThreads);
	
	pthread_mutex_destroy(&threadManagementLock);
	pthread_mutex_destroy(&dataLock);
	pthread_mutex_destroy(&connectionCheckLock);
	
	if (mySQLConnection) SPClear(mySQLConnection);
	if (structure) SPClear(structure);
	if (allKeysofDbStructure) SPClear(allKeysofDbStructure);
	
	[super dealloc];
}

#pragma mark -
#pragma mark Private API

/**
 * Ensure that processing is completed.
 */
- (void)_destroy:(NSNotification *)notification
{
	delegate = nil;
	
	// Ensure all the retrieval threads have ended
	[self _cancelAllThreadsAndWait];
}

/**
 * Update the global variables, using the data lock for multithreading safety.
 */
- (void)_updateGlobalVariablesWithStructure:(NSDictionary *)aStructure keys:(NSArray *)theKeys
{

	NSString *connectionID = [delegate connectionID];

	// Return if the delegate indicates disconnection
	if([connectionID length] < 2) return;

	pthread_mutex_lock(&dataLock);

	[structure setObject:aStructure forKey:connectionID];
	[allKeysofDbStructure setArray:theKeys];

	pthread_mutex_unlock(&dataLock);
}

/**
 * Set up a new connection in a background thread
 */
- (void)_cloneConnectionFromConnection:(SPMySQLConnection *)aConnection
{
	@autoreleasepool {
		pthread_mutex_lock(&connectionCheckLock);

		// If a connection is already set, ensure it's idle before releasing it
		if (mySQLConnection) {
			[self _cancelAllThreadsAndWait];

			[mySQLConnection autorelease], mySQLConnection = nil; // note: aConnection could be == mySQLConnection
		}

		// Create a copy of the supplied connection
		mySQLConnection = [aConnection copy];

		// Set the delegate to this instance
		[mySQLConnection setDelegate:self];

		// Trigger the connection
		[self _ensureConnectionUnsafe];

		pthread_mutex_unlock(&connectionCheckLock);
	}
}

/**
 * Check if the MySQL connection is still available (reconnecting if possible)
 *
 * **Unsafe** means this function holds no lock on connectionCheckLock.
 * You MUST obtain that lock before calling this method!
 *
 * WARNING: This method may return NO if the current thread is cancelled!
 *          You MUST check the isCancelled flag before using the result!
 */
- (BOOL)_ensureConnectionUnsafe
{
	if (!mySQLConnection || !delegate) return NO;

	// Check the connection state
	if ([mySQLConnection isConnected] && [mySQLConnection checkConnectionIfNecessary]) return YES;
	
	// the result of checkConnection may be meaningless if the thread was cancelled during execution. (issue #2353)
	if([[NSThread currentThread] isCancelled]) return NO;

	// The connection isn't connected.  Check the parent connection state, and if that
	// also isn't connected, return.
	if (![[delegate getConnection] isConnected]) return NO;

	// Copy the local port from the parent connection, in case a proxy has changed
	[mySQLConnection setPort:[[delegate getConnection] port]];

	// Attempt a connection
	if (![mySQLConnection connect]) return NO;

	// Ensure the encoding is set to UTF8
	[mySQLConnection setEncoding:@"utf8"];

	// Return success
	return YES;
}

/**
 * Wait until either
 *   * there are no other threads of this object doing structure retrievals
 *   * or the current thread was cancelled
 *
 * @param killOthers Whether to cancel all other running threads first
 */
- (void)_addToListAndWaitForFrontCancellingOtherThreads:(BOOL)killOthers
{
	// Lock the management lock
	pthread_mutex_lock(&threadManagementLock);
	
	// If 'cancelQuerying' is set try to interrupt any current querying
	if (killOthers) {
		for (NSThread *eachThread in structureRetrievalThreads) {
			[eachThread cancel];
		}
	}
	
	// Add this thread to the group
	[structureRetrievalThreads addObject:[NSThread currentThread]];
	
	// Only allow one request to be running against the server at any one time, to prevent
	// escessive server i/o or slowdown.  Loop until this is the first thread in the array
	while ([structureRetrievalThreads objectAtIndex:0] != [NSThread currentThread]) {
		pthread_mutex_unlock(&threadManagementLock);
		
		if ([[NSThread currentThread] isCancelled]) return;
		
		usleep(1000000);
		
		pthread_mutex_lock(&threadManagementLock);
	}
	pthread_mutex_unlock(&threadManagementLock);
}

/**
 * Remove the current thread from the list of running threads
 */
- (void)_removeThreadFromList
{
	pthread_mutex_lock(&threadManagementLock);
	[structureRetrievalThreads removeObject:[NSThread currentThread]];
	pthread_mutex_unlock(&threadManagementLock);
}

/**
 * Cancel all running threads and wait until they have exited
 */
- (void)_cancelAllThreadsAndWait
{
	pthread_mutex_lock(&threadManagementLock);
	
	for (NSThread *eachThread in structureRetrievalThreads) {
		[eachThread cancel];
	}
	
	while ([structureRetrievalThreads count]) {
		pthread_mutex_unlock(&threadManagementLock);
		usleep(100000);
		pthread_mutex_lock(&threadManagementLock);
	}
	
	pthread_mutex_unlock(&threadManagementLock);
}

/**
 * @return YES if the connection is available
 *         NO  if either the connection failed, or this thread was cancelled
 *
 * You MUST check the thread's isCancelled flag before doing other stuff on negative return!
 */
- (BOOL)_checkConnection
{
	while (1) {
		// we can fail to get the lock for two reasons
		//   1. another thread is running this code
		//        => a regular pthread_mutex_lock() would be fine, it would succeed once the other thread is done
		//   2. another thread is running _cloneConnectionFromConnection
		//        => that method will not let go of the lock until all other threads have exited.
		//           Since we are an "other thread", calling pthread_mutex_lock() would result in a deadlock!
		// That is why we try to get the lock and if that fails check if we are cancelled (indicating the 2. case).
		if(pthread_mutex_trylock(&connectionCheckLock) == ESUCCESS) {
			break;
		}
		
		// If this thread has been cancelled, abort
		if([[NSThread currentThread] isCancelled]) {
			return NO;
		}
		
		usleep(100000);
	}
	// we now hold the connectionCheckLock!
	
	BOOL cancelThread = ([[NSThread currentThread] isCancelled]);
	BOOL connected = NO;
	
	if (!cancelThread) {
		// Check connection state before use
		connected = [self _ensureConnectionUnsafe]; // also does a thread canellation check
	}
	
	pthread_mutex_unlock(&connectionCheckLock);
	
	return connected; // cancelThread → ¬connected
}

@end
