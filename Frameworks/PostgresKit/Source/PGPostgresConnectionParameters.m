//
//  $Id: PGPostgresConnectionParameters.m 3848 2012-09-12 12:19:31Z stuart02 $
//
//  PGPostgresConnectionParameters.m
//  PostgresKit
//
//  Created by Stuart Connolly (stuconnolly.com) on August 29, 2012.
//  Copyright (c) 2012 Stuart Connolly. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.

#import "PGPostgresConnectionParameters.h"
#import "PGPostgresKitPrivateAPI.h"
#import "PGPostgresConnection.h"

@interface PGPostgresConnectionParameters ()

- (void)_loadParameters:(id)object;
- (BOOL)_isBooleanParameterValue:(NSString *)value;
- (BOOL)_booleanForParameterValue:(NSString *)value;

@end

@implementation PGPostgresConnectionParameters

@synthesize connection = _connection;

#pragma mark -

- (id)init
{
	return [self initWithConnection:nil];
}

/**
 * Initialise a parameters instance with the supplied connection.
 *
 * @param connection The connection to use.
 *
 * @return The initialised instance.
 */
- (id)initWithConnection:(PGPostgresConnection *)connection
{
	if ((self = [super init])) {
		_connection = connection;
		
		pthread_mutex_init(&_readLock, NULL);
	}
	
	return self;
}

#pragma mark -
#pragma mark Public API

/**
 * Loads the database parameters.
 *
 * @return A BOOL indicating the success of the load.
 */
- (BOOL)loadParameters
{
	pthread_mutex_lock(&_readLock);
	
	if (!_connection || ![_connection isConnected]) {
		pthread_mutex_unlock(&_readLock);
		
		return NO;
	}
	
	if (!_parameterNames) {
		_parameterNames = [[NSMutableArray alloc] init];
		
		[_parameterNames addObject:PGPostgresParameterServerEncoding];
		[_parameterNames addObject:PGPostgresParameterClientEncoding];
		[_parameterNames addObject:PGPostgresParameterSuperUser];
		[_parameterNames addObject:PGPostgresParameterTimeZone];
		[_parameterNames addObject:PGPostgresParameterIntegerDateTimes];
	}
	
	pthread_mutex_unlock(&_readLock);
	
	[self performSelectorInBackground:@selector(_loadParameters:) withObject:_parameterNames];
	
	return YES;
}

/**
 * Gets the object for the supplied parameter.
 *
 * @param parameter The name of the parameter to lookup.
 *
 * @return The parameter value or nil if parameters haven't been loaded or it can't be found.
 */
- (id)valueForParameter:(NSString *)parameter
{
	pthread_mutex_lock(&_readLock);
	
	if (!_parameters || ![_parameters count]) {
		pthread_mutex_unlock(&_readLock);
		
		return nil;
	}
	
	id value = [_parameters objectForKey:parameter];
	
	pthread_mutex_unlock(&_readLock);
	
	return value;
}

#pragma mark -
#pragma mark Private API

/**
 * Loads the values of the supplied array of parameters by query the current connection.
 *
 * @param object The parameters to load.
 */
- (void)_loadParameters:(id)object
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	pthread_mutex_lock(&_readLock);
	
	NSArray *parameters = (NSArray *)object;
	
	if (!_parameters) {
		_parameters = [[NSMutableDictionary alloc] initWithCapacity:[parameters count]];
	}
	
	for (NSString *parameter in parameters) 
	{
		const char *value = PQparameterStatus([_connection postgresConnection], [parameter UTF8String]);
		
		if (!value) continue;
		
		NSString *stringValue = [NSString stringWithUTF8String:value];

		id paramObject = [self _isBooleanParameterValue:stringValue] ? (id)[NSNumber numberWithBool:[self _booleanForParameterValue:stringValue]] : stringValue;
		
		[_parameters setObject:paramObject forKey:parameter];
	}
	
	pthread_mutex_unlock(&_readLock);
	
	[pool release];
}

/**
 * Determines whether or not the supplied value is a boolean value.
 *
 * @param value The value to look at.
 *
 * @return A BOOL indicating if the value is a boolean type.
 */
- (BOOL)_isBooleanParameterValue:(NSString *)value
{
	value = [value uppercaseString]; 
	
	return 
	[value isEqualToString:@"ON"]   || 
	[value isEqualToString:@"YES"]  ||
	[value isEqualToString:@"TRUE"] ||
	[value isEqualToString:@"OFF"]  ||
	[value isEqualToString:@"NO"]   ||
	[value isEqualToString:@"FALSE"];
}

/**
 * Determines the boolean value for the supplied boolean string representation.
 *
 * @param value The value to look at.
 *
 * @return A BOOL indicating the value of the string representation.
 */
- (BOOL)_booleanForParameterValue:(NSString *)value
{
	value = [value uppercaseString]; 
	
	return 
	[value isEqualToString:@"ON"]   || 
	[value isEqualToString:@"YES"]  ||
	[value isEqualToString:@"TRUE"];
}

#pragma mark -

- (void)dealloc
{
	_connection = nil;
	
	pthread_mutex_destroy(&_readLock);
	
	if (_parameters) [_parameters release], _parameters = nil;
	if (_parameterNames) [_parameterNames release], _parameterNames = nil;
	
	[super dealloc];
}

@end
