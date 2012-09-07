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

#import "FLXPostgresTypes.h"

@class FLXPostgresConnection;

/**
 * @protocol FLXPostgresTypeHandlerProtocol
 */
@protocol FLXPostgresTypeHandlerProtocol

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
 * Return a transmittable data representation from the supplied object,
 * and set the remote type for the data.
 *
 * @param object The object to produce the data for.
 * @param type   The type of object we're supplying.
 *
 * @return The data represenation as an NSData instance.
 */
- (NSData *)remoteDataFromObject:(id)object type:(FLXPostgresOid *)type;

/**
 * Convert the supplied remote data into an object.
 *
 * @param bytes  The remote data to convert.
 * @param length The length of the data.
 * @param type   The type of data.
 *
 * @return An object represenation of the data.
 */
- (id)objectFromRemoteData:(const void *)bytes length:(NSUInteger)length type:(FLXPostgresOid)type;

@end
