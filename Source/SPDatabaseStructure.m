//
//  $Id$
//
//  SPDatabaseStructure.m
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on March 25, 2010
//  Copyright (c) 2010 Hans-Jörg Bibiko. All rights reserved.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import "SPDatabaseStructure.h"
#import "SPDatabaseDocument.h"
#import "SPConnectionDelegate.h"
#import "SPTablesList.h"
#import "RegexKitLite.h"
#import <SPMySQL/SPMySQL.h>
#import <pthread.h>

@interface SPDatabaseStructure (Private_API)

- (void)_updateGlobalVariablesWithStructure:(NSDictionary *)aStructure keys:(NSArray *)theKeys;
- (void)_cloneConnectionFromConnection:(SPMySQLConnection *)aConnection;
- (BOOL)_ensureConnection;

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
	[NSThread detachNewThreadSelector:@selector(_cloneConnectionFromConnection:) toTarget:self withObject:aConnection];
}

/**
 * Ensure that processing is completed.
 */
- (void)destroy
{
	delegate = nil;

	// Ensure all the retrieval threads have ended
	pthread_mutex_lock(&threadManagementLock);
	if ([structureRetrievalThreads count]) {
		for (NSThread *eachThread in structureRetrievalThreads) {
			[eachThread cancel];
		}
		while ([structureRetrievalThreads count]) {
			pthread_mutex_unlock(&threadManagementLock);
			usleep(100000);
			pthread_mutex_lock(&threadManagementLock);
		}
	}
	pthread_mutex_unlock(&threadManagementLock);

}

- (void)dealloc
{
	[self destroy];
	[structureRetrievalThreads release];

	pthread_mutex_destroy(&threadManagementLock);
	pthread_mutex_destroy(&dataLock);
	pthread_mutex_destroy(&connectionCheckLock);

	if (mySQLConnection) [mySQLConnection release], mySQLConnection = nil;
	if (structure) [structure release], structure = nil;
	if (allKeysofDbStructure) [allKeysofDbStructure release], allKeysofDbStructure = nil;

	[super dealloc];
}

#pragma mark -
#pragma mark Information

- (SPMySQLConnection *)connection
{
	return mySQLConnection;
}

#pragma mark -
#pragma mark Structure retrieval from the server

/**
 * Updates the dict containing the structure of all available databases (mainly for completion/navigator)
 * executed on the helper connection.
 * Should always be executed on a background thread.
 */
- (void)queryDbStructureWithUserInfo:(NSDictionary*)userInfo
{
	NSAutoreleasePool *queryPool = [[NSAutoreleasePool alloc] init];
	BOOL structureWasUpdated = NO;

	// Lock the management lock
	pthread_mutex_lock(&threadManagementLock);

	// If 'cancelQuerying' is set try to interrupt any current querying
	if (userInfo && [userInfo objectForKey:@"cancelQuerying"]) {
		for (NSThread *eachThread in structureRetrievalThreads) {
			[eachThread cancel];
		}
	}

	// Add this thread to the group
	[structureRetrievalThreads addObject:[NSThread currentThread]];

	// Only allow one request to be running against the server at any one time, to prevent
	// escessive server i/o or slowdown.  Loop until this is the first thread in the array
	while ([structureRetrievalThreads objectAtIndex:0] != [NSThread currentThread]) {
		if ([[NSThread currentThread] isCancelled]) {
			[structureRetrievalThreads removeObject:[NSThread currentThread]];
			pthread_mutex_unlock(&threadManagementLock);
			[queryPool release];
			return;
		}
			
		pthread_mutex_unlock(&threadManagementLock);
		usleep(1000000);
		pthread_mutex_lock(&threadManagementLock);
	}
	pthread_mutex_unlock(&threadManagementLock);

	// This thread is now first on the stack, and about to process the structure.
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SPDBStructureIsUpdating" object:delegate];

	NSString *connectionID;
	if([delegate respondsToSelector:@selector(connectionID)])
		connectionID = [NSString stringWithString:[delegate connectionID]];
	else
		connectionID = @"_";

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

	NSString *currentDatabase = nil;
	if ([delegate respondsToSelector:@selector(database)])
		currentDatabase = [delegate database];

	// Determine whether the database details need to be queried.
	BOOL shouldQueryStructure = YES;
	NSString *db_id = nil;

	// If no database is selected, no need to check further
	if(!currentDatabase || (currentDatabase && ![currentDatabase length])) {
		shouldQueryStructure = NO;

	// Otherwise, build up the schema key for the database to be retrieved.
	} else {
		db_id = [NSString stringWithFormat:@"%@%@%@", connectionID, SPUniqueSchemaDelimiter, currentDatabase];

		// Check to see if a cache already exists for the database.
		if ([queriedStructure objectForKey:db_id] && [[queriedStructure objectForKey:db_id] isKindOfClass:[NSDictionary class]]) {

			// The cache is available. If the `mysql` or `information_schema` databases are being queried,
			// never requery as their structure will never change.
			// 5.5.3+ also has performance_schema meta database
			if ([currentDatabase isEqualToString:@"mysql"] || [currentDatabase isEqualToString:@"information_schema"] || [currentDatabase isEqualToString:@"performance_schema"]) {
				shouldQueryStructure = NO;

			// Otherwise, if the forceUpdate flag wasn't supplied or evaluates to false, also don't update.
			} else if (userInfo == nil || ![userInfo objectForKey:@"forceUpdate"] || ![[userInfo objectForKey:@"forceUpdate"] boolValue]) {
				shouldQueryStructure = NO;
			}
		}
	}

	// If it has been determined that no new structure needs to be retrieved, clean up and return.
	if (!shouldQueryStructure) {

		// Update the global variables
		[self _updateGlobalVariablesWithStructure:queriedStructure keys:queriedStructureKeys];

		if (structureWasUpdated) {
			[[NSNotificationCenter defaultCenter] postNotificationName:@"SPDBStructureWasUpdated" object:delegate];
		}

		pthread_mutex_lock(&threadManagementLock);
		[structureRetrievalThreads removeObject:[NSThread currentThread]];
		pthread_mutex_unlock(&threadManagementLock);

		[queryPool release];
		return;
	}

	// Retrieve the tables and views for this database from SPTablesList
	NSMutableArray *tablesAndViews = [NSMutableArray array];
	for (id aTable in [[delegate valueForKeyPath:@"tablesListInstance"] allTableNames]) {
		NSDictionary *aTableDict = [NSDictionary dictionaryWithObjectsAndKeys:
										aTable, @"name",
										@"0", @"type",
										nil];
		[tablesAndViews addObject:aTableDict];
	}
	for (id aView in [[delegate valueForKeyPath:@"tablesListInstance"] allViewNames]) {
		NSDictionary *aViewDict = [NSDictionary dictionaryWithObjectsAndKeys:
										aView, @"name",
										@"1", @"type",
										nil];
		[tablesAndViews addObject:aViewDict];
	}

	// Do not parse more than 2000 tables/views per db
	if ([tablesAndViews count] > 2000) {
		NSLog(@"%lu items in database %@. Only 2000 items can be parsed. Stopped parsing.", (unsigned long)[tablesAndViews count], currentDatabase);

		pthread_mutex_lock(&threadManagementLock);
		[structureRetrievalThreads removeObject:[NSThread currentThread]];
		pthread_mutex_unlock(&threadManagementLock);

		[queryPool release];
		return;
	}

	// For future usage - currently unused
	// If the affected item name and type - for example, table type and table name - were supplied, extract it.
	NSString *affectedItem = nil;
	NSInteger affectedItemType = -1;
	if(userInfo && [userInfo objectForKey:@"affectedItem"]) {
		affectedItem = [userInfo objectForKey:@"affectedItem"];
		if([userInfo objectForKey:@"affectedItemType"])
			affectedItemType = [[userInfo objectForKey:@"affectedItemType"] intValue];
		else
			affectedItem = nil;
	}

	// Delete all stored data for the database to be updated, leaving the structure key
	[queriedStructure removeObjectForKey:db_id];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT SELF BEGINSWITH %@", [NSString stringWithFormat:@"%@%@", db_id, SPUniqueSchemaDelimiter]];
	[queriedStructureKeys filterUsingPredicate:predicate];

	// Set up the database as an empty mutable dictionary ready for tables, and store a reference
	[queriedStructure setObject:[NSMutableDictionary dictionary] forKey:db_id];
	NSMutableDictionary *databaseStructure = [queriedStructure objectForKey:db_id];

	NSString *currentDatabaseEscaped = [currentDatabase stringByReplacingOccurrencesOfString:@"`" withString:@"``"];

	NSUInteger uniqueCounter = 0; // used to make field data unique
	SPMySQLResult *theResult;

	// Loop through the known tables and views, retrieving details for each
	for (NSDictionary *aTableDict in tablesAndViews) {

		// Extract the name
		NSString *aTableName = [aTableDict objectForKey:@"name"];

		if(!aTableName) continue;
		if(![aTableName isKindOfClass:[NSString class]]) continue;
		if(![aTableName length]) continue;

		BOOL cancelThread = NO;

		// If the thread has been cancelled, abort without saving
		if ([[NSThread currentThread] isCancelled]) cancelThread = YES;

		// Check connection state before use
		while (!cancelThread && pthread_mutex_trylock(&connectionCheckLock)) {
			usleep(100000);
			if ([[NSThread currentThread] isCancelled]) {
				cancelThread = YES;
				break;
			}
		}

		if (cancelThread) {
			pthread_mutex_trylock(&connectionCheckLock);
			pthread_mutex_unlock(&connectionCheckLock);
			pthread_mutex_lock(&threadManagementLock);
			[structureRetrievalThreads removeObject:[NSThread currentThread]];
			pthread_mutex_unlock(&threadManagementLock);

			[queryPool release];
			return;
		}

		if (![self _ensureConnection]) {
			pthread_mutex_unlock(&connectionCheckLock);
			pthread_mutex_lock(&threadManagementLock);
			[structureRetrievalThreads removeObject:[NSThread currentThread]];
			pthread_mutex_unlock(&threadManagementLock);

			[queryPool release];
			return;
		}
		pthread_mutex_unlock(&connectionCheckLock);

		// Retrieve the column details
		theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW FULL COLUMNS FROM `%@` FROM `%@`", [aTableName stringByReplacingOccurrencesOfString:@"`" withString:@"``"], currentDatabaseEscaped]];
		if (!theResult) {
			continue;
		}
		[theResult setDefaultRowReturnType:SPMySQLResultRowAsArray];
		[theResult setReturnDataAsStrings:YES];

		// Add a structure key for this table
		NSString *table_id = [NSString stringWithFormat:@"%@%@%@", db_id, SPUniqueSchemaDelimiter, aTableName];
		[queriedStructureKeys addObject:table_id];

		// Add a mutable dictionary to the structure and store a reference
		[databaseStructure setObject:[NSMutableDictionary dictionary] forKey:table_id];
		NSMutableDictionary *tableStructure = [databaseStructure objectForKey:table_id];

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
		BOOL cancelThread = NO;

		if ([[NSThread currentThread] isCancelled]) cancelThread = YES;

		// Check connection state before use
		while (!cancelThread && pthread_mutex_trylock(&connectionCheckLock)) {
			usleep(100000);
			if ([[NSThread currentThread] isCancelled]) {
				cancelThread = YES;
				break;
			}
		}

		if (!cancelThread) {
			if (![self _ensureConnection]) cancelThread = YES;
			pthread_mutex_unlock(&connectionCheckLock);
		};

		// Return if the thread is due to be cancelled
		if (cancelThread) {
			pthread_mutex_trylock(&connectionCheckLock);
			pthread_mutex_unlock(&connectionCheckLock);
			pthread_mutex_lock(&threadManagementLock);
			[structureRetrievalThreads removeObject:[NSThread currentThread]];
			pthread_mutex_unlock(&threadManagementLock);

			[queryPool release];
			return;
		}

		// Retrieve the column details
		theResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SELECT * FROM `information_schema`.`ROUTINES` WHERE `information_schema`.`ROUTINES`.`ROUTINE_SCHEMA` = '%@'", [currentDatabase stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"]]];
		[theResult setDefaultRowReturnType:SPMySQLResultRowAsArray];

		// Loop through the rows and extract the function details
		for (NSArray *row in theResult) {
			NSString *fname = [row objectAtIndex:0];
			NSString *type = ([[row objectAtIndex:4] isEqualToString:@"FUNCTION"]) ? @"3" : @"2";
			NSString *dtd = [row objectAtIndex:5];
			NSString *det = [row objectAtIndex:11];
			NSString *dataaccess = [row objectAtIndex:12];
			NSString *security_type = [row objectAtIndex:14];
			NSString *definer = [row objectAtIndex:19];

			// Generate "table" and "field" names and add to structure key store
			NSString *table_id = [NSString stringWithFormat:@"%@%@%@", db_id, SPUniqueSchemaDelimiter, fname];
			NSString *field_id = [NSString stringWithFormat:@"%@%@%@", table_id, SPUniqueSchemaDelimiter, fname];
			[queriedStructureKeys addObject:table_id];
			[queriedStructureKeys addObject:field_id];

			// Ensure that a dictionary exists for this "table" name
			if(![[queriedStructure valueForKey:db_id] valueForKey:table_id])
				[[queriedStructure valueForKey:db_id] setObject:[NSMutableDictionary dictionary] forKey:table_id];

			// Add the "field" details
			[[[queriedStructure valueForKey:db_id] valueForKey:table_id] setObject:
				[NSArray arrayWithObjects:dtd, dataaccess, det, security_type, definer, [NSNumber numberWithUnsignedLongLong:uniqueCounter], nil] forKey:field_id];
			[[[queriedStructure valueForKey:db_id] valueForKey:table_id] setObject:type forKey:@"  struct_type  "];
			uniqueCounter++;
		}
	}

	// Update the global variables
	[self _updateGlobalVariablesWithStructure:queriedStructure keys:queriedStructureKeys];

	// Notify that the structure querying has been performed
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SPDBStructureWasUpdated" object:delegate];

	// Remove this thread from the processing stack
	pthread_mutex_lock(&threadManagementLock);
	[structureRetrievalThreads removeObject:[NSThread currentThread]];
	pthread_mutex_unlock(&threadManagementLock);
	
	[queryPool release];
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

@end

#pragma mark -
#pragma mark Private API

@implementation SPDatabaseStructure (Private_API)

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
	NSAutoreleasePool *connectionPool = [[NSAutoreleasePool alloc] init];

	pthread_mutex_lock(&connectionCheckLock);

	// If a connection is already set, ensure it's idle before releasing it
	if (mySQLConnection) {
		pthread_mutex_lock(&threadManagementLock);
		if ([structureRetrievalThreads count]) {
			for (NSThread *eachThread in structureRetrievalThreads) {
				[eachThread cancel];
			}
			while ([structureRetrievalThreads count]) {
				pthread_mutex_unlock(&threadManagementLock);
				usleep(100000);
				pthread_mutex_lock(&threadManagementLock);
			}
		}
		pthread_mutex_unlock(&threadManagementLock);

		[mySQLConnection release];
		mySQLConnection = nil;
	}

	// Create a copy of the supplied connection
	mySQLConnection = [aConnection copy];

	// Set the delegate to this instance
	[mySQLConnection setDelegate:self];

	// Trigger the connection
	[self _ensureConnection];

	pthread_mutex_unlock(&connectionCheckLock);

	[connectionPool drain];
}

- (BOOL)_ensureConnection
{
	if (!mySQLConnection || !delegate) return NO;

	// Check the connection state
	if ([mySQLConnection isConnected] && [mySQLConnection checkConnection]) return YES;

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

@end