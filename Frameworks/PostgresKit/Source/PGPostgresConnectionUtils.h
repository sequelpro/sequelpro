//
//  $Id: PGPostgresConnectionUtils.h 3793 2012-09-03 10:22:17Z stuart02 $
//
//  PGPostgresConnectionUtils.h
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

#import "PGPostgresConnection.h"

@interface PGPostgresConnection (PGPostgresConnectionUtils)

- (NSArray *)schemas;
- (NSArray *)databases;
- (NSArray *)tablesInSchema:(NSString *)schema;
- (NSArray *)columnNamesForTable:(NSString *)table inSchema:(NSString *)schema;
- (NSString *)primaryKeyForTable:(NSString *)table inSchema:(NSString *)schema;

@end
