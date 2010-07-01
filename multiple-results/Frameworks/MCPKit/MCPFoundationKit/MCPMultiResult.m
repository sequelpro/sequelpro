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
 * allow multiple results. This is only relevant when using call -- otherwise a query can never
 * have more than one result.
 *
 * MCPMultiResult works by creating MCPStreamingResults for every result of the query. It always
 * uses cached streaming mode, so it can immediately continue with the next result as soon as the
 * first is ready.
 *
 * If a second result is requested before the first has finished downloading, execution is blocked
 * until the download is finished. We have to wait, because otherwise we don't know if there are
 * further results or not.
 *
 * Usage: just use [MCPConnection streamingMultiQueryString:] and then call [MCPMultiResult nextResult]
 * until nil is returned, signalling that there are no more results.
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
    
    //[NSThread detachNewThreadSelector:@selector(resultFetcherTask) toTarget:self withObject:nil];
    
    NSThread *resultFetcherThread = [[NSThread alloc] initWithTarget:self selector:@selector(resultFetcherTask) object:nil];
    [resultFetcherThread setName:@"MCPMultiResult Result Fetcher thread"];
    [resultFetcherThread start];
    
    return self;
}

- (void) resultFetcherTask
{
    [[NSThread currentThread] setName:@"MCPMultiResult Result Fetcher Thread"];
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    do
    {
        NSMutableDictionary *nextResult = [NSMutableDictionary dictionaryWithCapacity:10];
        [nextResult setObject:[NSNumber numberWithInt:mysql_affected_rows(mConnection)] forKey:@"affected_rows"];
        [nextResult setObject:[NSNumber numberWithInt:mysql_field_count(mConnection)] forKey:@"field_count"];
        [nextResult setObject:[NSNumber numberWithInt:mysql_errno(mConnection)] forKey:@"errno"];
        [nextResult setObject:[parentConnection stringWithCString:mysql_error(mConnection)] forKey:@"error"];
        if (mysql_field_count(mConnection)) {
            [nextResult setObject:[[[MCPStreamingResult alloc] initWithMySQLPtr:mConnection encoding:mEncoding timeZone:mTimeZone connection:self] autorelease] forKey:@"result"];
        } else {
            [self unlockConnection];
        }
        @synchronized(results){
            [results addObject:nextResult];
        }
        NSLog(@"Waiting for result to be processed.");
        [pseudoConnectionLock lockWhenCondition:MCPConnectionIdle];
        NSLog(@"Result processed.");
        [pseudoConnectionLock unlockWithCondition:MCPConnectionBusy];
    } while(!mysql_next_result(mConnection));
    [parentConnection unlockConnection];
    finishedCreatingResults = YES;
    NSLog(@"All results processed.");
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
    
    NSLog(@"Delivering a result.");
    
    // return the next result and remove it from the stack
    MCPStreamingResult *nextResult;
    @synchronized(results){
        nextResult = [[results objectAtIndex:0] retain];
        [results removeObjectAtIndex:0];
    }
    return [nextResult autorelease];
}
@end
