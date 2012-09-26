//
//  $Id: PGPostgresConnectionParameters.h 3793 2012-09-03 10:22:17Z stuart02 $
//
//  PGPostgresConnectionParameters.h
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

#import <pthread.h>

@class PGPostgresConnection;

@interface PGPostgresConnectionParameters : NSObject 
{
	PGPostgresConnection *_connection;
	
	NSMutableArray *_parameterNames;
	NSMutableDictionary *_parameters;
	
	pthread_mutex_t _readLock;
}

/**
 * @property connection The database connection to use.
 */
@property (readwrite, assign) PGPostgresConnection *connection;

- (id)initWithConnection:(PGPostgresConnection *)connection;

- (BOOL)loadParameters;

- (id)valueForParameter:(NSString *)parameter;

@end
