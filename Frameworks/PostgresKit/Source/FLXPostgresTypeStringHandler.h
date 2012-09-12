//
//  $Id$
//
//  FLXPostgresTypeStringHandler.h
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

#import "FLXPostgresTypeHandler.h"

@interface FLXPostgresTypeStringHandler : FLXPostgresTypeHandler <FLXPostgresTypeHandlerProtocol>
{
	NSUInteger _row;
	NSUInteger _column;
	
	const PGresult *_result;
	
	FLXPostgresOid _type;
}

@property (readwrite, assign) NSUInteger row;

@property (readwrite, assign) NSUInteger column;

@property (readwrite, assign) FLXPostgresOid type;

@property (readwrite, assign) const PGresult *result;

@end

