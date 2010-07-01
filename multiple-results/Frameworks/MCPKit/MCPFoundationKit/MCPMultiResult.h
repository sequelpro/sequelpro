//
//  MCPMultiResult.h
//  sequel-pro
//
//  Created by Jakob on 01.07.10.
//

#import <Foundation/Foundation.h>

#import "mysql.h"

@class MCPConnection;
@class MCPStreamingResult;

@interface MCPMultiResult : NSObject {
	NSStringEncoding *mEncoding;
    NSTimeZone *mTimeZone;
    MYSQL *mConnection;
    MCPConnection *parentConnection;
    
    
    NSMutableArray *results;
    BOOL finishedCreatingResults;
    NSConditionLock *pseudoConnectionLock;
}
- (id)initWithMySQLPtr:(MYSQL *)aConnection encoding:(NSStringEncoding)theEncoding timeZone:(NSTimeZone *)theTimeZone connection:(MCPConnection *)theConnection;
- (void) resultFetcherTask;
- (void) unlockConnection;
- (BOOL) isConnected;
- (void) updateErrorStatuses;
- (void) dealloc;
- (NSDictionary*) nextResultSet;

@end
