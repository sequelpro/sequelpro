//
//  $Id: PGPostgresConnectionTypeHandling.h 3817 2012-09-08 08:57:46Z stuart02 $
//
//  PGPostgresConnectionTypeHandling.h
//  PostgresKit
//
//  Created by Stuart Connolly (stuconnolly.com) on July 29, 2012.
//  Copyright (c) 2012 Stuart Connolly. All rights reserved.
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
#import "PGPostgresTypeHandlerProtocol.h"

@interface PGPostgresConnection (PGPostgresConnectionTypeHandling)

- (void)registerTypeHandlers;

- (id <PGPostgresTypeHandlerProtocol>)typeHandlerForClass:(Class)class;
- (id <PGPostgresTypeHandlerProtocol>)typeHandlerForRemoteType:(PGPostgresOid)type;

- (void)registerTypeHandler:(Class)handlerClass;

@end
