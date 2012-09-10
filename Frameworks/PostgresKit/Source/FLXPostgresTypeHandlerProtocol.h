//
//  $Id$
//
//  FLXPostgresTypeHandlerProtocol.h
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

@class FLXPostgresConnection;

/**
 * @protocol FLXPostgresTypeHandlerProtocol
 */
@protocol FLXPostgresTypeHandlerProtocol

@property (readwrite, assign) NSUInteger row;

@property (readwrite, assign) NSUInteger column;

@property (readwrite, assign) FLXPostgresOid type;

@property (readwrite, assign) const PGresult *result;

/**
 * The remote type values handled by this class (terminated by 0).
 *
 * @return The remote types as an array of FLXPostgresOid's.
 */
- (FLXPostgresOid *)remoteTypes;

/**
 * What is the native class this class handles.
 *
 * @return The native class.
 */
- (Class)nativeClass;

/**
 * Any aliases that the native class is known by.
 *
 * @return An of aliases as strings or nil if none.
 */
- (NSArray *)classAliases;

/**
 * Convert the value at the specified row and column in the supplied result to a native object.
 *
 * @return An object represenation of the data.
 */
- (id)objectFromResult;

@end
