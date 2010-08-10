//
//  MCPMultiResult.m
//  sequel-pro
//
//  Created by Jakob on 01.07.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MCPMultiResult.h"
#import "MCPStreamingResult.h"
#import "MCPConstants.h"


/**
 * MCMultiResult is used by [MCPConnection streamingMultiQueryString:] to support queries that
 * allow multiple results. This is only relevant when using stored procedures -- otherwise a query can
 * never have more than one result.
 *
 * MCPMultiResult works by creating MCPStreamingResults for every result of the query. It always
 * uses cached streaming mode, so it can immediately continue with the next result as soon as the
 * first is ready.
 *
 * MCMultiResult uses a nice trick when creating the MCPStreamingResults: it sends itself instead of the
 * MCPConnnection object. Therefore it can intercept the "unlockConnection" message sent by the
 * MCPStreamingResult. This message tells the MCPMultiResult that the MCPStreamingResult has finished
 * downloading, and the next result can be downloaded!
 *
 * If a second result is requested before the first has finished downloading, execution is blocked
 * until the download is finished. We have to wait, because otherwise we don't know if there are
 * further results or not.
 *
 * Usage: just use [MCPConnection streamingMultiQueryString:] and then call [MCPMultiResult nextResultSet]
 * until nil is returned, signalling that there are no more results. The result of nextResultSet is
 * an NSDictionary with the following keys: affected_rows, field_count, errno, error, result. The result
 * key is an MCPStreamingResult. It only exists if field_count>0. Please note that all error messages
 * and affected_rows count etc. should be acquired from this dictionary. The values returned when 
 * querying the MCPConnection object can change as the different results are downloaded.
 */
@implementation MCPMultiResult


/**
 * Initialise a MCPMultiResult in the same way as MCPResult - as used
 * internally by the MCPConnection !{queryString:} method.
 */
- (id)initWithMySQLPtr:(MYSQL *)aConnection encoding:(NSStringEncoding)theEncoding timeZone:(NSTimeZone *)theTimeZone connection:(MCPConnection *)theConnection
{
	if (!(self = [super init])) return nil;
    mEncoding = theEncoding;
    mTimeZone = [theTimeZone retain];
    mConnection = aConnection;
    
    parentConnection = theConnection;
    
    results = [[NSMutableArray alloc] initWithCapacity:10];
    pseudoConnectionLock = [[NSConditionLock alloc] initWithCondition:MCPConnectionBusy];
    
    [NSThread detachNewThreadSelector:@selector(resultFetcherTask) toTarget:self withObject:nil];
        
    return self;
}

/**
 * This selector runs in a background thread. It creates a cached streaming result, waits until that
 * result has finished downloading, then checks if there are more results. If there are more results
 * it creates another cached streaming result, waits until that has finished and so on.
 * As soon as all results have been downloaded, the parent connection is unlocked.
 */
- (void) resultFetcherTask
{
    [[NSThread currentThread] setName:@"MCPMultiResult Result Fetcher Thread"];

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    do
    {
        NSMutableDictionary *nextResult = [NSMutableDictionary dictionaryWithCapacity:10];
        MCPStreamingResult *result = [[[MCPStreamingResult alloc] initWithMySQLPtr:mConnection encoding:mEncoding timeZone:mTimeZone connection:self] autorelease]; 
        [nextResult setObject:[NSNumber numberWithInt:mysql_affected_rows(mConnection)] forKey:@"affected_rows"];
        [nextResult setObject:[NSNumber numberWithInt:[result numOfFields]] forKey:@"field_count"];
        [nextResult setObject:[NSNumber numberWithInt:mysql_errno(mConnection)] forKey:@"errno"];
        [nextResult setObject:[parentConnection stringWithCString:mysql_error(mConnection)] forKey:@"error"];
        if ([result numOfFields]>0) {
            [nextResult setObject:result forKey:@"result"];
        }
        @synchronized(results){
            [results addObject:nextResult];
        }
        [pseudoConnectionLock lockWhenCondition:MCPConnectionIdle];
        [pseudoConnectionLock unlockWithCondition:MCPConnectionBusy];
    } while(!mysql_next_result(mConnection));
    [parentConnection unlockConnection];
    finishedCreatingResults = YES;
    [pool release];
}

- (void) unlockConnection
{
    [pseudoConnectionLock lock];
    [pseudoConnectionLock unlockWithCondition:MCPConnectionIdle];
}

- (BOOL) isConnected
{
    return [parentConnection isConnected];
}

- (void) updateErrorStatuses
{
    [parentConnection updateErrorStatuses];
}

- (void) dealloc
{
    // remove all results
    [results release];
    
    [pseudoConnectionLock release];
    [mTimeZone release];
}

- (NSDictionary*) nextResultSet
{
    // if there are currently no results available, wait until
    //  1) more results are available or
    //  2) we know there are no more results available
    NSInteger resultCount;
    @synchronized(results){
        resultCount = [results count];
    }
    while (!resultCount && !finishedCreatingResults) {
        usleep(1000);
        @synchronized(results){
            resultCount = [results count];
        }
    }
    
    // if there are no more results available, just return nil
    if (!resultCount) return nil;
        
    // return the next result and remove it from the stack
    MCPStreamingResult *nextResult;
    @synchronized(results){
        nextResult = [[results objectAtIndex:0] retain];
        [results removeObjectAtIndex:0];
    }
    return [nextResult autorelease];
}
@end
