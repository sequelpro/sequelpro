//
//  $Id$
//
//  FLXPostgresResult.h
//  PostgresKit
//
//  Copyright (c) 2008-2009 David Thorpe, djt@mutablelogic.com
//
//  Forked by the Sequel Pro Team on July 22, 2012.
// 
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not 
//  use this file except in compliance with the License. You may obtain a copy of 
//  the License at
// 
//  http://www.apache.org/licenses/LICENSE-2.0
// 
//  Unless required by applicable law or agreed to in writing, software 
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT 
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the 
//  License for the specific language governing permissions and limitations under
//  the License.

#import "libpq-fe.h"
#import "FLXConstants.h"

@class FLXPostgresConnection;

@interface FLXPostgresResult : NSObject 
{
	void *_result;
	void **_typeHandlers;
	
	unsigned long long _row;
	unsigned int _numberOfFields;
	unsigned long long _numberOfRows;
	
	NSString **_fields;
	
	NSStringEncoding _stringEncoding;
		
	FLXPostgresConnection *_connection;
}

/**
 * @property numberOfFields The number of fields this result has.
 */
@property (readonly) unsigned int numberOfFields;

/**
 * @property numberOfRows The number or rows this result has.
 */
@property (readonly) unsigned long long numberOfRows;

/**
 * @property stringEncoding The ecoding that was in use when this result was created.
 */
@property (readonly) NSStringEncoding stringEncoding;

- (id)initWithResult:(PGresult *)result connection:(FLXPostgresConnection *)connection;

- (unsigned int)numberOfFields;

- (void)seekToRow:(unsigned long long)row;

- (NSArray *)fields;

- (NSArray *)rowAsArray;
- (NSDictionary *)rowAsDictionary;
- (id)rowAsType:(FLXPostgresResultRowType)type;

@end
