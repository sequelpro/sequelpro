//
//  $Id$
//
//  FLXPostgresException.m
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

#import "FLXPostgresException.h"

@implementation FLXPostgresException

/**
 * Raise a new exception with the supplied details.
 *
 * @param name       The name of the exception to raise.
 * @param connection The connection associated with the exception being raised.
 */
+ (void)raise:(NSString *)name connection:(void *)connection 
{
	const char *errorMessage = "Unknown error";
	
	if (connection) errorMessage = PQerrorMessage(connection);
	
	errorMessage = strlen(errorMessage) ? errorMessage : "Unknown error";
	
	[[[[FLXPostgresException alloc] initWithName:name reason:[NSString stringWithUTF8String:errorMessage] userInfo:nil] autorelease] raise];
}

/**
 * Raise a new exception with the supplied details.
 *
 * @param name   The name of the exception to raise.
 * @param reason The reason for the exception being raised.
 */
+ (void)raise:(NSString *)name reason:(NSString *)reason, ...
{
	va_list args;
	va_start(args, reason);
	
	NSString *reasonMessage = [[NSString alloc] initWithFormat:reason arguments:args];
	
	va_end(args);
	
	[[[[FLXPostgresException alloc] initWithName:name reason:reasonMessage userInfo:nil] autorelease] raise];
	
	[reasonMessage release];
}

@end
