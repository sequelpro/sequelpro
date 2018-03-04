//
//  SPMySQLConnection_PrivateAPI.h
//  SPMySQLFramework
//
//  Created by Rowan Beentje (rowan.beent.je) on February 12, 2012
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

/**
 * A collection of Private APIs from the various categories, to simplify
 * inclusion across the categories.
 */

#import "Ping & KeepAlive.h"
#import "Locking.h"
#import "Conversion.h"

@interface SPMySQLConnection (PrivateAPI)

- (BOOL)_connect;
- (MYSQL *)_makeRawMySQLConnectionWithEncoding:(NSString *)encodingName isMasterConnection:(BOOL)isMaster;
- (BOOL)_reconnectAllowingRetries:(BOOL)canRetry;
- (BOOL)_reconnectAfterBackgroundConnectionLoss;
- (BOOL)_waitForNetworkConnectionWithTimeout:(double)timeoutSeconds;
- (void)_disconnect;
- (void)_updateConnectionVariables;
- (void)_restoreConnectionVariables;
- (void)_validateThreadSetup;
+ (void)_removeThreadVariables:(NSNotification *)aNotification;

@end


@interface SPMySQLConnection (Delegate_and_Proxy_Private_API)

- (void)_proxyStateChange:(NSObject <SPMySQLConnectionProxy> *)aProxy;
- (SPMySQLConnectionLostDecision)_delegateDecisionForLostConnection;

@end


@interface SPMySQLConnection (Databases_and_Tables_Private_API)

- (BOOL)_storeAndAlterEncodingToUTF8IfRequired;

@end


@interface SPMySQLConnection (Max_Packet_Size_Private_API)

- (NSInteger)_queryMaxAllowedPacketWithSQL:(NSString *)query resultInColumn:(NSUInteger)colIdx;
- (void)_updateMaxQuerySize;
- (void)_updateMaxQuerySizeEditability;
- (BOOL)_attemptMaxQuerySizeIncreaseTo:(NSUInteger)targetSize;
- (void)_restoreMaximumQuerySizeAfterQuery;

@end


@interface SPMySQLConnection (Querying_and_Preparation_Private_API)

- (void)_flushMultipleResultSets;
- (void)_updateLastErrorInfos;
- (void)_updateLastErrorMessage:(NSString *)theErrorMessage;
- (void)_updateLastErrorID:(NSUInteger)theErrorID;
- (void)_updateLastSqlstate:(NSString *)theSqlstate;

@end


// SPMySQLResult Private API
@interface SPMySQLResult (Private_API)

- (NSString *)_stringWithBytes:(const void *)bytes length:(NSUInteger)length;
- (NSString *)_lossyStringWithBytes:(const void *)bytes length:(NSUInteger)length wasLossy:(BOOL *)outLossy;
- (void)_setQueryExecutionTime:(double)theExecutionTime;

@end

// SPMySQLResult Data Conversion Private API
#import "Data Conversion.h"

/**
 * Set up a static function to allow fast calling of SPMySQLResult data conversion with cached selectors
 */
static inline id SPMySQLResultGetObject(SPMySQLResult* self, char* bytes, NSUInteger length, NSUInteger fieldIndex, NSUInteger previewLength)
{
	typedef id (*SPMySQLResultGetObjectMethodPtr)(SPMySQLResult*, SEL, char*, NSUInteger, NSUInteger, NSUInteger);
	static SPMySQLResultGetObjectMethodPtr cachedMethodPointer;
	static SEL cachedSelector;

	if (!cachedSelector) cachedSelector = @selector(_getObjectFromBytes:ofLength:fieldDefinitionIndex:previewLength:);
	if (!cachedMethodPointer) cachedMethodPointer = (SPMySQLResultGetObjectMethodPtr)[self methodForSelector:cachedSelector];

	return cachedMethodPointer(self, cachedSelector, bytes, length, fieldIndex, previewLength);
}
