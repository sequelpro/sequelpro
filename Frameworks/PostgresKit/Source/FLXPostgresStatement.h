//
//  $Id$
//
//  FLXPostgresStatement.h
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

@interface FLXPostgresStatement : NSObject 
{
	NSString *_statement;
	NSString *_name;
}

/**
 * @property statement The query statement.
 */
@property (readwrite, retain) NSString *statement;

/**
 * @property name The name of this statement.
 */
@property (readwrite, retain) NSString *name;

- (id)initWithStatement:(NSString *)queryStatement;

- (const char *)UTF8Name;
- (const char *)UTF8Statement;

@end
