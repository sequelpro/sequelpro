//
//  $Id$
//
//  FLXPostgresConnectionKitAPI.h
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

#import "FLXPostgresConnection.h"
#import "FLXPostgresTimeInterval.h"

@interface FLXPostgresConnection ()

- (PGconn *)postgresConnection;

@end

@interface FLXPostgresConnection (FLXPostgresConnectionQueryPreparationPrivateAPI)

- (BOOL)_prepare:(FLXPostgresStatement *)statement num:(NSInteger)paramNum types:(FLXPostgresOid *)paramTypes;

@end

@interface FLXPostgresTimeInterval ()

+ (id)intervalWithPGInterval:(PGinterval *)interval;
- (id)initWithInterval:(PGinterval *)interval;

@end



