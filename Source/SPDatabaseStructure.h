//
//  SPDatabaseStructure.h
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

@class SPMySQLConnection;
@class SPDatabaseDocument;

#import <SPMySQL/SPMySQL.h>

@interface SPDatabaseStructure : NSObject <SPMySQLConnectionDelegate> 
{
	SPDatabaseDocument *delegate;
	SPMySQLConnection *mySQLConnection;

	NSMutableDictionary *structure;
	NSMutableArray *allKeysofDbStructure;

	NSMutableArray *structureRetrievalThreads;

	pthread_mutex_t threadManagementLock;
	pthread_mutex_t dataLock;
	pthread_mutex_t connectionCheckLock;
}

// Setup and teardown
- (id)initWithDelegate:(SPDatabaseDocument *)theDelegate;
- (void)setConnectionToClone:(SPMySQLConnection *)aConnection;

// Information
- (SPMySQLConnection *)connection;
- (SPDatabaseDocument *)delegate;

// Structure retrieval from the server
- (void)queryDbStructureInBackgroundWithUserInfo:(NSDictionary *)userInfo;
- (void)queryDbStructureWithUserInfo:(NSDictionary*)userInfo;
- (BOOL)isQueryingDatabaseStructure;

// Structure information
- (NSDictionary *)structure;
- (NSArray *)allStructureKeys;

@end
