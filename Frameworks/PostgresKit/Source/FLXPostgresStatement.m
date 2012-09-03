//
//  $Id$
//
//  FLXPostgresStatement.m
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

#import "FLXPostgresStatement.h"

@implementation FLXPostgresStatement

@synthesize name = _name;
@synthesize statement = _statement;

#pragma mark -
#pragma mark Initialisation

- (id)initWithStatement:(NSString *)queryStatement 
{
	if ((self = [super init])) {
		[self setStatement:queryStatement];
		[self setName:nil];
	}
	
	return self;
}

#pragma mark -
#pragma mark Public API

/**
 * Returns a null terminated C string of the statement's name.
 *
 * @return The statement name.
 */
- (const char *)UTF8Name 
{
	return [[self name] UTF8String];
}

/**
 * Returns a null terminated C string of the statement.
 *
 * @return The prepared statement.
 */
- (const char *)UTF8Statement 
{
	return [[self statement] UTF8String];	
}

- (NSString *)description 
{
	return [self name] ? [NSString stringWithFormat:@"<%@ %@>", [self className], [self name]] : [NSString stringWithFormat:@"<%@>", [self className]];
}

#pragma mark -

- (void)dealloc 
{
	if (_name) [_name release], _name = nil;
	if (_statement) [_statement release], _statement = nil;
	
	[super dealloc];
}

@end
