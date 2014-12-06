//
//  $Id: PGPostgresConnectionTypeHandling.m 3803 2012-09-06 11:00:21Z stuart02 $
//
//  PGPostgresConnectionTypeHandling.m
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

#import "PGPostgresConnectionTypeHandling.h"
#import "PGPostgresTypeStringHandler.h"
#import "PGPostgresTypeNumberHandler.h"
#import "PGPostgresTypeDateTimeHandler.h"
#import "PGPostgresTypeBinaryHandler.h"
#import "PGPostgresException.h"

@implementation PGPostgresConnection (PGPostgresConnectionTypeHandling)

/**
 * Register all of our data type handlers for this connection.
 */
- (void)registerTypeHandlers 
{
	if (_typeMap) {
		[_typeMap release];
		
		_typeMap = [[NSMutableDictionary alloc] init];
	}
	
	[self registerTypeHandler:[PGPostgresTypeStringHandler class]];
	[self registerTypeHandler:[PGPostgresTypeNumberHandler class]];
	[self registerTypeHandler:[PGPostgresTypeDateTimeHandler class]];
	[self registerTypeHandler:[PGPostgresTypeBinaryHandler class]];
}

/**
 * Get the data type handler for the supplied class.
 *
 * @param class The class to get the handler for.
 *
 * @return The handler or nil if there's none associated with the class.
 */
- (id <PGPostgresTypeHandlerProtocol>)typeHandlerForClass:(Class)class 
{
	return [_typeMap objectForKey:NSStringFromClass(class)];
}

/**
 * Get the data type handler for the supplied PostgreSQL type.
 *
 * @param type The PostgreSQL type to get the handler for.
 *
 * @return The handler or nil if there's none associated with the type.
 */
- (id <PGPostgresTypeHandlerProtocol>)typeHandlerForRemoteType:(PGPostgresOid)type 
{		
	return [_typeMap objectForKey:[NSNumber numberWithUnsignedInteger:type]];
}

/**
 * Register the supplied type handler class.
 *
 * @param handlerClass The handler class to register.
 */
- (void)registerTypeHandler:(Class)handlerClass 
{		
	if (![handlerClass conformsToProtocol:@protocol(PGPostgresTypeHandlerProtocol)]) {
		[PGPostgresException raise:PGPostgresConnectionErrorDomain 
							 reason:@"Class '%@' does not conform to protocol '%@'", NSStringFromClass(handlerClass), NSStringFromProtocol(@protocol(PGPostgresTypeHandlerProtocol))];
	}
	
	// Create an instance of this class
	id <PGPostgresTypeHandlerProtocol> handler = [[[handlerClass alloc] initWithConnection:self] autorelease];
	
	// Add to the type map - for native class
	[_typeMap setObject:handler forKey:NSStringFromClass([handler nativeClass])];
	
	NSArray *aliases = [handler classAliases];
	
	if (aliases) {
		for (NSString *alias in aliases)
		{
			[_typeMap setObject:handler forKey:alias];
		}
	}
	
	PGPostgresOid *remoteTypes = [handler remoteTypes];
	
	for (NSUInteger i = 0; remoteTypes[i]; i++) 
	{		
		NSNumber *key = [NSNumber numberWithUnsignedInteger:remoteTypes[i]];
		
		[_typeMap setObject:handler forKey:key];
	}
}

@end
