//
//  $Id$
//
//  Querying & Preparation.h
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


@interface SPMySQLConnection (Querying_and_Preparation)

// Data preparation
- (NSString *)escapeAndQuoteString:(NSString *)theString;
- (NSString *)escapeString:(NSString *)theString includingQuotes:(BOOL)includeQuotes;
- (NSString *)escapeAndQuoteData:(NSData *)theData;
- (NSString *)escapeData:(NSData *)theData includingQuotes:(BOOL)includeQuotes;

// Queries
- (SPMySQLResult *)queryString:(NSString *)theQueryString;
- (SPMySQLFastStreamingResult *)streamingQueryString:(NSString *)theQueryString;
- (id)streamingQueryString:(NSString *)theQueryString useLowMemoryBlockingStreaming:(BOOL)fullStreaming;
- (id)queryString:(NSString *)theQueryString usingEncoding:(NSStringEncoding)theEncoding withResultType:(SPMySQLResultType)theReturnType;

// Query convenience functions
- (NSArray *)getAllRowsFromQuery:(NSString *)theQueryString;
- (id)getFirstFieldFromQuery:(NSString *)theQueryString;

// Query information
- (unsigned long long)rowsAffectedByLastQuery;
- (unsigned long long)lastInsertID;

// Connection and query error state
- (BOOL)queryErrored;
- (NSString *)lastErrorMessage;
- (NSUInteger)lastErrorID;
+ (BOOL)isErrorIDConnectionError:(NSUInteger)theErrorID;

// Query cancellation
- (void)cancelCurrentQuery;
- (BOOL)lastQueryWasCancelledUsingReconnect;

@end

/**
 * Set up static functions to allow fast calling with cached selectors
 */

static inline id SPMySQLConnectionEscapeString(SPMySQLConnection* self, NSString *theString, BOOL encloseInQuotes) 
{
	typedef id (*SPMySQLConnectionEscapeStringMethodPtr)(SPMySQLConnection*, SEL, NSString *, BOOL);
	static SPMySQLConnectionEscapeStringMethodPtr cachedMethodPointer;
	static SEL cachedSelector;

	if (!cachedSelector) cachedSelector = @selector(escapeString:includingQuotes:);
	if (!cachedMethodPointer) cachedMethodPointer = (SPMySQLConnectionEscapeStringMethodPtr)[self methodForSelector:cachedSelector];

	return cachedMethodPointer(self, cachedSelector, theString, encloseInQuotes);
}

static inline id SPMySQLConnectionEscapeData(SPMySQLConnection* self, NSData *theData, BOOL encloseInQuotes) 
{
	typedef id (*SPMySQLConnectionEscapeDataMethodPtr)(SPMySQLConnection*, SEL, NSData *, BOOL);
	static SPMySQLConnectionEscapeDataMethodPtr cachedMethodPointer;
	static SEL cachedSelector;

	if (!cachedSelector) cachedSelector = @selector(escapeData:includingQuotes:);
	if (!cachedMethodPointer) cachedMethodPointer = (SPMySQLConnectionEscapeDataMethodPtr)[self methodForSelector:cachedSelector];

	return cachedMethodPointer(self, cachedSelector, theData, encloseInQuotes);
}

static inline id SPMySQLConnectionQueryString(SPMySQLConnection* self, NSString *theQueryString, NSStringEncoding theEncoding, SPMySQLResultType theReturnType) 
{
	typedef id (*SPMySQLConnectionQueryStringMethodPtr)(SPMySQLConnection*, SEL, NSString *, NSStringEncoding, SPMySQLResultType);
	static SPMySQLConnectionQueryStringMethodPtr cachedMethodPointer;
	static SEL cachedSelector;

	if (!cachedSelector) cachedSelector = @selector(queryString:usingEncoding:withResultType:);
	if (!cachedMethodPointer) cachedMethodPointer = (SPMySQLConnectionQueryStringMethodPtr)[self methodForSelector:cachedSelector];

	return cachedMethodPointer(self, cachedSelector, theQueryString, theEncoding, theReturnType);
}
