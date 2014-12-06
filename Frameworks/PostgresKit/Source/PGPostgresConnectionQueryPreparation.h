//
//  $Id: PGPostgresConnectionQueryPreparation.h 3806 2012-09-07 09:57:31Z stuart02 $
//
//  PGPostgresConnectionQueryPreparation.h
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

@interface PGPostgresConnection (PGPostgresConnectionQueryPreparation)

- (PGPostgresStatement *)prepare:(NSString *)query;
- (PGPostgresStatement *)prepareWithFormat:(NSString *)query, ...;

@end
